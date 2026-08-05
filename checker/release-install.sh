#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# INSTALL THE RELEASE ARTIFACT THE WAY A STRANGER WOULD -- FROM THE ZIP.
#
# checker/install-roundtrip.sh proves the installer works IN THE REPOSITORY.
# That is not the same claim. A stranger does not clone the repository: they
# download a zip, unzip it somewhere with no git, no checker/, no lean/, and run
# ARM_ROUTER. Every path that resolves relative to the repo root, every file the
# installer assumes is beside it, is untested until someone does exactly that.
#
# So this unpacks the ACTUAL ARTIFACT into a scratch directory and drives it:
#
#   1. unzip the core artifact somewhere with no repository around it
#   2. ARM_ROUTER against a SCRATCH CLAUDE_CONFIG_DIR -- never the live one
#   3. the hook entry must appear, and must point INSIDE the unpacked plugin
#   4. the router must actually run from there and emit its line
#   5. DISARM_ROUTER must restore the settings file BYTE-IDENTICALLY
#   6. the Core artifact must not be able to reach the network -- asserted by
#      absence of the fetcher, in the unpacked tree this time
#
# YOUR LIVE ~/.claude IS NEVER OPENED. Every write goes to a mktemp directory
# that is removed at the end, and the path is printed so you can check.
#
# Exit: 0 the artifact installs and uninstalls cleanly · 1 an assertion FAILED ·
#       2 refuse (no artifact to test) · 3 SKIP (a tool is missing).
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=release-install::%s\n' "$*"; FAIL=$((FAIL+1)); }
note() { printf '  ----  %s\n' "$*"; }
skip() { printf '  SKIP  %s\n' "$*"; }

command -v unzip >/dev/null 2>&1 || { echo "REFUSE: unzip absent"; exit 3; }

REL="${ROTMOE_RELEASE_DIR:-$REPO/.release}"

# THE VERSION IS THE VARIANT, so an asset's name cannot be derived from the
# tree's own version -- that produced `rot-moe-0.5.2-core.zip`, a file that has
# never existed.
#
# THIS MAP USED TO BE A SECOND COPY of the one in checker/release-package.sh,
# with a comment claiming "the two must stay in step, which the assertion below
# enforces rather than trusting". No assertion did. Measured 2026-08-03: the
# packager moved to 0.6.x, this copy stayed at 0.5.x, and the gate REFUSED
# looking for `rot-moe-0.5.0-core.zip` -- an archive the tree no longer builds.
# The failure was loud, but it was a false alarm about the wrong thing, and the
# tempting repair is to hand-edit the copy again.
#
# A duplicated constant with a promise attached is still a duplicated constant.
# This repo has already shipped that exact defect once (a duplicate weight table
# the binding checker was validating instead of the real one). So the map is now
# PARSED from the packager, which is the only place it is defined.
# ASKED FOR, not grepped out. The line above was
#   sed -n 's/^VARIANTS="\(.*\)"$/\1/p' checker/release-package.sh
# which reads the packager's SOURCE TEXT. That survives only while the map is a
# literal string, and it stopped being one when the packager began DERIVING the
# three versions from plugin.json (a hardcoded triple went red on a correct
# release bump). The sed then returned `core:$_MM.0 ...` verbatim and this gate
# refused, hunting an archive named `rot-moe-$_MM.0-core.zip`.
#
# The single-source principle is unchanged and the implementation is now sound:
# the packager is EXECUTED and prints the map it will actually use, so a future
# change to how versions are derived reaches this file automatically.
VARIANTS=$(bash "$REPO/checker/release-package.sh" --print-variants 2>/dev/null | head -1)
case "$VARIANTS" in
  *core:*|*lean:*|*unsealed:*) : ;;
  *) echo "REFUSE: could not parse VARIANTS from checker/release-package.sh (got '$VARIANTS')."
     echo "        Refusing to fall back to a hardcoded map -- that is the drift this"
     echo "        block was rewritten to make impossible."
     exit 2 ;;
esac
version_of () { for vp in $VARIANTS; do [ "${vp%%:*}" = "$1" ] && { printf '%s' "${vp#*:}"; return; }; done; }

# --- a bound that does not assume GNU coreutils ------------------------------
# MEASURED on macos-latest, CI #21: this file died at its own SAFETY INTERLOCK
# with "--dry-run did not report a config dir". The dry run had not misbehaved --
# it never ran. macOS does NOT ship `timeout`; it is GNU coreutils, present on
# Linux and in Git Bash, absent on a stock Mac. The call was literally
# `timeout 60 bash ./ARM_ROUTER.sh --dry-run` -- spelled with the bare binary --
# so it was simply "command not found", the capture came back empty, and the interlock
# correctly refused to arm anything on the strength of nothing.
#
# The interlock behaved exactly right -- it failed CLOSED, which is why no live
# config was ever at risk. What was wrong is that a missing TOOL was reported as
# a missing ANSWER, and the log printed nothing to distinguish them.
#
# Homebrew installs the same binary as `gtimeout`, so try that before giving up.
# If neither exists the run is UNBOUNDED, and that is announced rather than
# hidden: a silently unbounded call inside a checker turns a failing test into a
# hanging one.
if command -v timeout >/dev/null 2>&1; then TMOBIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then TMOBIN=gtimeout
else TMOBIN=""; fi
run_bounded () {   # run_bounded <seconds> <cmd...>; reads stdin like the command it wraps
  _secs="$1"; shift
  if [ -n "$TMOBIN" ]; then "$TMOBIN" "$_secs" "$@"; else
    [ -n "${_unbounded_warned:-}" ] || { printf "  ----  UNBOUNDED: no timeout/gtimeout on PATH; a hang cannot be detected here\n" >&2; _unbounded_warned=1; }
    "$@"
  fi
}

VER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json | head -1)
CORE="$REL/rot-moe-$(version_of core)-core.zip"
LEAN="$REL/rot-moe-$(version_of lean)-lean.zip"
UNSEALED="$REL/rot-moe-$(version_of unsealed)-unsealed.zip"

if [ ! -s "$CORE" ]; then
  echo "REFUSE: $CORE not built. Run checker/release-package.sh first."
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/rotmoe-relinstall.XXXXXX")"
cleanup () { rm -rf "$WORK"; }
trap cleanup EXIT

echo "== release install :: version $VER =="
note "scratch: $WORK   (live ~/.claude is never opened)"
# ALWAYS report the bound, not only when something fails. CI #21 failed here on
# macOS and #22 passed, and the logs could not say WHY: the fallback chain is
# timeout -> gtimeout -> unbounded, and all three are silent when they work.
# Printing the winner turns "it passes now" into a fact about which binary ran.
note "bounded by: ${TMOBIN:-<NONE -- neither timeout nor gtimeout; calls are UNBOUNDED>}"

# --- 1. unpack, with no repository around it ---------------------------------
PLUG="$WORK/plugin"
mkdir -p "$PLUG"
unzip -q "$CORE" -d "$PLUG" 2>/dev/null
urc=$?
if [ "$urc" -ne 0 ] || [ ! -f "$PLUG/ARM_ROUTER.sh" ]; then
  bad "the core artifact did not unpack into a usable tree (unzip exit $urc)"
  printf '\n== release install: %d passed, %d failed\n' "$PASS" "$FAIL"
  exit 1
fi
ok "core artifact unpacked -- no .git, no checker/, no lean/ around it"

# Prove the emptiness rather than assume it: this is the whole point of the file.
for absent in .git checker lean SETUP_LEAN.sh SETUP_LEAN.ps1; do
  if [ -e "$PLUG/$absent" ]; then
    bad "the unpacked CORE tree contains '$absent' -- it is not the core artifact"
  fi
done
ok "the unpacked tree has no repository, no proof corpus and no Lean fetcher"

# --- 2. arm it against a scratch config --------------------------------------
CFG="$WORK/.claude"
mkdir -p "$CFG"
# Start from a settings file in the shape Claude Code itself writes, so the
# round-trip claim is about a realistic file and not a convenient one.
printf '{\n  "model": "sonnet"\n}\n' > "$CFG/settings.json"
cp "$CFG/settings.json" "$WORK/settings.before.json"

# ---- SAFETY INTERLOCK: prove the target BEFORE writing to it ----------------
# This gate wrote to the LIVE ~/.claude on its first run. Not because the
# installer was wrong -- because this harness passed an environment variable the
# installer did not read, and the installer then fell back to $HOME exactly as
# documented. The fallback is correct; ASSUMING it would not be taken was the
# defect. Only a read-only bit on the real settings.json prevented the write.
#
# So: ask the installer where it WOULD write, with --dry-run, and refuse to run
# it for real unless that answer is inside our scratch directory. A test harness
# that can silently reach the live configuration is not a test, it is a hazard,
# and "I set the variable" is not evidence that the variable was read.
dry=$( cd "$PLUG" && CLAUDE_CONFIG_DIR="$CFG" CLAUDE_DIR="$CFG" \
       run_bounded 60 bash ./ARM_ROUTER.sh --dry-run 2>&1 )
target=$(printf '%s' "$dry" | sed -n 's/.*config dir[[:space:]]*:[[:space:]]*//p' | head -1)
if [ -z "$target" ]; then
  bad "INTERLOCK: --dry-run did not report a config dir -- refusing to arm anything"
  # PRINT WHAT WAS ACTUALLY SEEN. The macOS run failed here and the log carried
  # no evidence at all, so a missing `timeout` binary looked identical to an
  # installer that had gone silent. A diagnostic that shows nothing costs a full
  # CI round trip to distinguish two completely different causes.
  note "bounded by: ${TMOBIN:-<NONE -- neither timeout nor gtimeout on this platform>}"
  note "--dry-run produced ${#dry} bytes; first lines:"
  printf '%s\n' "$dry" | head -6 | sed 's/^/        /'
  printf '\n== release install: %d passed, %d failed\n' "$PASS" "$((FAIL))"
  exit 1
fi
case "$target" in
  "$CFG"|"$CFG"/*) ok "INTERLOCK: the installer resolves to the scratch config ($target)" ;;
  *) bad "INTERLOCK: the installer would write to '$target', NOT the scratch dir -- ABORTING before it can"
     printf '\n== release install: %d passed, %d failed\n' "$PASS" "$FAIL"
     exit 1 ;;
esac

# Both variables are passed deliberately. CLAUDE_CONFIG_DIR is what a real user
# sets and what the installer now honours first; CLAUDE_DIR is the older
# test-only override. Passing both means this gate keeps working whichever
# precedence a future edit chooses -- and the interlock above catches it if
# neither is honoured.
( cd "$PLUG" && CLAUDE_CONFIG_DIR="$CFG" CLAUDE_DIR="$CFG" bash ./ARM_ROUTER.sh >"$WORK/arm.log" 2>&1 )
arc=$?
if [ "$arc" -ne 0 ]; then
  bad "ARM_ROUTER.sh from the artifact exited $arc"
  sed 's/^/        /' "$WORK/arm.log" | head -8
else
  ok "ARM_ROUTER.sh ran from the unpacked artifact (exit 0)"
fi

# --- 3. the hook must be registered, and must point inside the artifact -------
if grep -q 'rot-router' "$CFG/settings.json" 2>/dev/null; then
  ok "the settings file gained a rot-router hook entry"
else
  bad "no rot-router entry in the scratch settings -- arming did nothing"
fi

# PARSE the JSON; do not pattern-match it. The registered command contains
# ESCAPED QUOTES -- pwsh -NoProfile -File \"...\" || bash \"...\" -- so a sed
# class like [^"]* stops at the first backslash-quote and matches nothing.
# Measured: the extraction silently returned empty and the gate reported "could
# not read the registered command" against a settings file that was correct.
# node is already a hard dependency of the installer, so using it costs nothing.
hookpath=$(node -e '
  const fs = require("fs");
  const s = JSON.parse(fs.readFileSync(process.argv[1], "utf8").replace(/^\uFEFF/, ""));
  const out = [];
  for (const ev of Object.keys(s.hooks || {}))
    for (const g of s.hooks[ev] || [])
      for (const h of g.hooks || [])
        if (h.command && h.command.indexOf("rot-router") !== -1) out.push(h.command);
  if (out.length) console.log(out[0]);
' "$CFG/settings.json" 2>/dev/null)
if [ -n "$hookpath" ]; then
  note "registered command: $hookpath"
  # The path it registered must resolve to a file that exists. A hook entry
  # pointing at a path that is not there is the failure this whole file exists
  # to catch, and it cannot be seen from inside the repository.
  # The registered command must point INSIDE the tree we just unpacked. A hook
  # entry aimed at a path that does not exist is the failure this whole file
  # exists to catch, and it is invisible from inside the repository -- where the
  # path happens to resolve for a completely different reason.
  # DO NOT COMPARE PATH TEXT. Measured on windows-latest, CI #21: the registered
  # command came back as
  #     bash "/c/Users/RUNNER~1/AppData/Local/Temp/rotmoe-relinstall.hsLoBS/plugin/hooks/rot-router.sh"
  # while $PLUG held the LONG form (/c/Users/runneradmin/...). Windows hands out
  # 8.3 short names, `RUNNER~1` and `runneradmin` are the same directory, and a
  # substring test can never see that. The gate failed on a hook entry that was
  # perfectly correct and pointed exactly where it should.
  #
  # The right question is not "do these strings overlap" but "is this the SAME
  # FILE". `test -ef` compares device and inode, so short names, symlinks, and
  # trailing-slash noise all collapse to the truth. It is POSIX and works on all
  # three runners.
  #
  # The old substring test also could not tell a real path from a plausible one:
  # a command naming a file that does not exist would have passed it.
  reg=$(printf '%s' "$hookpath" | sed -n 's/.*bash[[:space:]]*\\*"\([^"\\]*rot-router\.sh\)\\*".*/\1/p' | head -1)
  [ -n "$reg" ] || reg=$(printf '%s' "$hookpath" | sed -n 's/.*[[:space:]]\([^"[:space:]]*rot-router\.sh\).*/\1/p' | head -1)
  if [ -n "$reg" ] && [ -f "$reg" ] && [ "$reg" -ef "$PLUG/hooks/rot-router.sh" ]; then
    ok "the registered hook IS the file inside the unpacked artifact (same inode)"
  else
    bad "the registered hook does not reference the unpacked plugin dir: $hookpath"
    note "extracted path: '${reg:-<none>}'  exists=$([ -f "$reg" ] && echo yes || echo no)"
    note "expected same file as: $PLUG/hooks/rot-router.sh"
  fi
  if [ -e "$PLUG/hooks/rot-router.sh" ]; then
    ok "the file the hook names is present in the artifact"
  else
    bad "hooks/rot-router.sh is absent from the unpacked artifact"
  fi
else
  bad "could not read the registered command out of the settings file"
fi

# --- 4. the router must RUN from the unpacked tree ----------------------------
# Not "the file is present" -- executed, with a real prompt, from the artifact.
out=$(printf '{"prompt":"lake build the theorem and fix the sorry"}' \
      | run_bounded 60 bash "$PLUG/hooks/rot-router.sh" 2>"$WORK/router.err")
rrc=$?
if [ "$rrc" -ne 0 ]; then
  bad "the router from the artifact exited $rrc"
  head -3 "$WORK/router.err" | sed 's/^/        /'
elif case "$out" in *FORGE*) true ;; *) false ;; esac; then
  ok "the router RAN from the unpacked artifact and routed a FORGE prompt correctly"
else
  bad "the router ran but did not route a FORGE prompt to FORGE"
  printf '%s' "$out" | head -3 | sed 's/^/        /'
fi

# --- 5. disarm must restore the file BYTE-IDENTICALLY ------------------------
( cd "$PLUG" && CLAUDE_CONFIG_DIR="$CFG" CLAUDE_DIR="$CFG" bash ./DISARM_ROUTER.sh >"$WORK/disarm.log" 2>&1 )
drc=$?
if [ "$drc" -ne 0 ]; then
  bad "DISARM_ROUTER.sh from the artifact exited $drc"
  sed 's/^/        /' "$WORK/disarm.log" | head -8
else
  ok "DISARM_ROUTER.sh ran from the unpacked artifact (exit 0)"
fi

if cmp -s "$WORK/settings.before.json" "$CFG/settings.json"; then
  ok "the settings file is BYTE-IDENTICAL to what it was before arming"
else
  bad "the settings file differs after the round trip:"
  diff -u "$WORK/settings.before.json" "$CFG/settings.json" 2>/dev/null | head -12 | sed 's/^/        /'
fi

# --- 6. the LEAN artifact, if built, must carry what Core does not ------------
if [ -s "$LEAN" ]; then
  PLUG2="$WORK/plugin-lean"
  mkdir -p "$PLUG2"
  unzip -q "$LEAN" -d "$PLUG2" 2>/dev/null
  if [ -f "$PLUG2/SETUP_LEAN.sh" ] && [ -f "$PLUG2/lean/lean-toolchain" ]; then
    ok "the LEAN artifact unpacks with the fetcher and the pinned toolchain"
    # It must REFUSE without consent. This is the promise that matters most in
    # an artifact a stranger downloads: nothing large happens by accident.
    ( cd "$PLUG2" && run_bounded 60 bash ./SETUP_LEAN.sh >"$WORK/setup.log" 2>&1 )
    src=$?
    if [ "$src" -eq 2 ]; then
      ok "SETUP_LEAN.sh from the artifact REFUSES without consent (exit 2)"
    else
      bad "SETUP_LEAN.sh exited $src with no consent flag -- it must refuse with 2"
      head -5 "$WORK/setup.log" | sed 's/^/        /'
    fi
    # ...and --dry-run must create nothing.
    before=$(find "$PLUG2" -type f | grep -c . || true)
    ( cd "$PLUG2" && run_bounded 120 bash ./SETUP_LEAN.sh --dry-run >"$WORK/dry.log" 2>&1 )
    after=$(find "$PLUG2" -type f | grep -c . || true)
    if [ "$before" -eq "$after" ]; then
      ok "SETUP_LEAN.sh --dry-run created NOTHING ($before files before and after)"
    else
      bad "--dry-run changed the tree: $before files before, $after after"
    fi
  else
    bad "the LEAN artifact is missing its fetcher or its pinned toolchain"
  fi
else
  skip "no lean artifact at $LEAN -- its half of this gate did not run (never a pass)"
fi

# --- negative controls --------------------------------------------------------
echo
echo "-- negative controls --"

# C1: the byte-identity test must be able to FAIL. Perturb one byte and require
# the same comparison to notice; otherwise assertion 5 proves nothing.
printf '{\n  "model": "opus"\n}\n' > "$WORK/settings.perturbed.json"
if cmp -s "$WORK/settings.before.json" "$WORK/settings.perturbed.json"; then
  bad "CONTROL DEAD: cmp says a perturbed settings file is identical"
else
  ok "CONTROL: cmp DOES detect a one-field difference -- assertion 5 can fail"
fi

# C2: the router assertion must be able to miss. A prompt with no FORGE stem
# must NOT route to FORGE, or "it routed correctly" means nothing.
out2=$(printf '{"prompt":"I feel lost and tired lately"}' \
       | run_bounded 60 bash "$PLUG/hooks/rot-router.sh" 2>/dev/null)
if case "$out2" in *EMPATHIC*) true ;; *) false ;; esac; then
  ok "CONTROL: a non-FORGE prompt routes elsewhere (EMPATHIC) -- the router is not constant"
else
  bad "CONTROL: an EMPATHIC prompt did not route to EMPATHIC -- the router may be constant"
fi

# C0: THE INTERLOCK MUST BE ABLE TO FIRE. Ask the installer where it would go
# with NO override at all; that answer must be outside the scratch dir, or the
# interlock is comparing a value that can never differ and guards nothing.
# ORDER MATTERS: run_bounded FIRST, env second. `env` execs a BINARY, and
# run_bounded is a shell function -- `env -u X run_bounded ...` is "no such file
# or directory", the capture comes back empty, and the control reports DID NOT
# APPLY. Which it did, correctly: discarded is not survived, and that is the
# whole reason the third outcome exists.
unguarded=$( cd "$PLUG" && run_bounded 60 env -u CLAUDE_CONFIG_DIR -u CLAUDE_DIR \
             bash ./ARM_ROUTER.sh --dry-run 2>&1 \
             | sed -n 's/.*config dir[[:space:]]*:[[:space:]]*//p' | head -1 )
case "$unguarded" in
  "$CFG"|"$CFG"/*) bad "CONTROL: with no override the installer STILL reports the scratch dir -- the interlock cannot discriminate" ;;
  "") bad "CONTROL DID NOT APPLY: no config dir reported without overrides -- discarded, NOT survived" ;;
  *) ok "CONTROL: with no override it resolves elsewhere ($unguarded) -- the interlock discriminates" ;;
esac

# C3: the scratch config must really be the one that was written, not the live
# one. If ~/.claude/settings.json were touched, this file would be worthless.
if [ -f "$CFG/settings.json" ]; then
  ok "CONTROL: every write landed in the scratch config at $CFG"
else
  bad "CONTROL: the scratch settings file does not exist -- what was being edited?"
fi

# --- the UNSEALED variant, installed the same way a stranger meets it --------
# 0.5.2's whole claim is that it ships an instrument the tier below does not.
# That is checked HERE, from the unpacked archive, because a file present in the
# repository proves nothing about a file present in the download.
if [ -s "$UNSEALED" ]; then
  UW="$WORK/unsealed"; mkdir -p "$UW"
  if unzip -q "$UNSEALED" -d "$UW" 2>/dev/null; then
    u=0
    [ -f "$UW/UNSEALED.md" ]              || { bad "UNSEALED artifact has no UNSEALED.md"; u=1; }
    [ -f "$UW/checker/axiom-class.sh" ]   || { bad "UNSEALED artifact has no axiom classifier"; u=1; }
    [ "$u" -eq 0 ] && ok "UNSEALED unpacks with both the page and the classifier a stranger was promised"

    # The classifier must RUN from the unpacked artifact, where there is no git
    # and no build tree. Without a toolchain it must SKIP (3) or REFUSE (2) --
    # never exit 0, because a silent pass would be indistinguishable from a
    # clean corpus it never read.
    ( cd "$UW" && run_bounded 600 bash checker/axiom-class.sh >/dev/null 2>&1 )
    arc=$?
    case "$arc" in
      0) ok "the classifier ran from the unpacked artifact and passed (exit 0)" ;;
      2|3) ok "the classifier declined honestly from the artifact (exit $arc = refuse/skip, never a silent pass)" ;;
      *) bad "the classifier exited $arc from the unpacked artifact" ;;
    esac
  else
    bad "the UNSEALED artifact did not unpack"
  fi
else
  note "no unsealed artifact present -- skipping its assertions"
fi

# The three variants must be DISTINCT files. If two ever coincided, the tiers
# would be a naming convention rather than a difference.
if [ -s "$CORE" ] && [ -s "$LEAN" ] && [ -s "$UNSEALED" ]; then
  if cmp -s "$CORE" "$LEAN" || cmp -s "$LEAN" "$UNSEALED" || cmp -s "$CORE" "$UNSEALED"; then
    bad "two variants are byte-identical -- the version numbers promise a difference that is not there"
  else
    ok "all three variants are distinct archives"
  fi
fi

printf '\n== release install: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
