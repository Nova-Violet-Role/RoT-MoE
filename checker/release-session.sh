#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# EVERY RELEASE VARIANT, IN A REAL CLAUDE CODE SESSION, ACROSS EVERY LANE.
#
# WHAT THE OTHER RELEASE GATES DO NOT PROVE, stated plainly because I claimed
# "proved locally" on the strength of them and the claim was too wide:
#
#   checker/release-install.sh unzips the artifact, arms it, and then executes
#   hooks/rot-router.sh MYSELF with a synthetic {"prompt":"..."} on stdin. That
#   shows the SCRIPT runs from the archive. It does not show that Claude Code
#   ever reads the hook entry, invokes it, hands it the payload shape the router
#   expects, or that the routed line reaches a turn.
#
# checker/live-session-smoke.sh closes that gap for the REPOSITORY packet, with
# one prompt. This file closes it for all three SHIPPED ARCHIVES, across the
# whole lane table -- because a router that answered FORGE to everything would
# pass a single-prompt test perfectly, and because Router, Router-Lean and
# Router-Lean-Extra are three different archives (one version, the tier in the
# name since 6.0.0). A superset assertion says the files are present in each;
# only an executed session says they FIRE.
#
# Method, per variant: unpack the artifact, arm it against a SCRATCH config dir,
# hold a real `claude -p` session per lane, and require the router's OWN output
# line to appear in the hook debug log with the CORRECT lane. Then disarm and
# require it to go silent.
#
# SAFETY, not negotiable:
#   * A SCRATCH CLAUDE_CONFIG_DIR per variant. The live ~/.claude is never
#     opened, never armed, never disarmed. An interlock ASKS the installer where
#     it would write and aborts unless the answer is inside the scratch dir --
#     because "I set the variable" is not evidence that it was READ, and this
#     harness reached the live config once already by assuming it was.
#   * NO process is signalled, by PID or by pattern.
#   * Every session is bounded by `timeout`. An unbounded network call inside a
#     checker turns a failing test into a hanging one, and a hang reports
#     nothing at all.
#
# COST: one API call per lane per variant. Defaults to 3 variants x 9 lanes + 3
# controls = 30 sessions. Narrow with ROTMOE_VARIANTS / ROTMOE_LANES.
#
# Exit: 0 every variant routed every lane and every control held · 1 a failure ·
#       2 refuse (no artifacts) · 3 SKIP (no CLI).
# =============================================================================


# THIS HARNESS DECLARES ITS OWN TRAFFIC.
#
# Measured 2026-08-09: seven checkers feed the router synthetic payloads and
# write into whatever ROTMOE_DEBUG_LOG points at. 738 of 955 sh route records
# in the live log were theirs, and nothing in the schema said so -- so every
# "live router health" figure computed from that log silently mixed real
# lifecycle traffic with replayed corpus traffic. The instrument was
# contaminating its own measurement and could not report that it was.
#
# RotSessionLog.test_is_never_hook proves the consequence: a record declared
# here can never be classified as live traffic, whatever the payload contains.
export ROTMOE_DEBUG_SRC=test

# Never write a per-session log into the repository being tested. A checker
# that leaves files behind is not a read-only observer.
export ROTMOE_DEBUG_LOCAL=0

set -uo pipefail

# --- a bound that does not assume GNU coreutils ------------------------------
# macOS does NOT ship `timeout` (it is GNU coreutils). A bare `timeout N cmd` is
# "command not found" there, which returns an EMPTY capture -- and an empty
# capture reads exactly like a tool that answered nothing. Homebrew installs the
# same binary as `gtimeout`. If neither exists the call runs UNBOUNDED, and that
# is announced rather than hidden. Full story: checker/release-install.sh.
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
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=release-session::%s\n' "$*"; FAIL=$((FAIL+1)); }
note() { printf '  ----  %s\n' "$*"; }

command -v claude >/dev/null 2>&1 || { echo "SKIP: the claude CLI is not on PATH -- no session can be held"; exit 3; }
command -v unzip  >/dev/null 2>&1 || { echo "REFUSE: unzip absent"; exit 2; }

REL="${ROTMOE_RELEASE_DIR:-$REPO/.release}"
# THE MAP IS ASKED FOR, NEVER COPIED OR GREPPED OUT OF SOURCE TEXT. This file
# was once the FOURTH copy of a map defined exactly once, in
# checker/release-package.sh, and the copy had drifted to archives the tree no
# longer built; then it was a sed over the packager's source, which broke the
# day the map stopped being a literal (MEASURED 2026-08-05: a gate that CANNOT
# PASS, counted in the total, because the repair landed in one sibling and not
# the other). Execute the packager and let it print the map it will use.
#
# SINCE 6.0.0 the map is one line per variant, `<archive-basename>:<version>`:
# the names are version-less constants (the tier lives in the name), so the
# names ARE spelled in archive_of below -- but spelled AND verified against the
# packager's answer, so a rename there becomes a loud failure here instead of
# a hunt for a ghost archive.
VARIANT_MAP=$(bash "$REPO/checker/release-package.sh" --print-variants 2>/dev/null)
case "$VARIANT_MAP" in
  *RoT-MoE-*.zip:*) : ;;
  *) echo "REFUSE: could not parse the variant map from checker/release-package.sh (got '$VARIANT_MAP')."
     echo "        Refusing a hardcoded fallback -- that is the drift being removed."
     exit 2 ;;
esac
WANT="${ROTMOE_VARIANTS:-core lean unsealed}"

SESSION_TIMEOUT="${ROTMOE_SESSION_TIMEOUT:-180}"
LANES="${ROTMOE_LANES:-FORGE CLINICAL EMPATHIC STRATEGIC CREATIVE PREDICTIVE STEALTH RECURSIVE EXECUTIVE}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/rotmoe-relsession.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

echo "== release session :: every variant, every lane, real CLI =="
note "claude $(claude --version 2>&1 | head -1)"
note "scratch: $WORK   (live ~/.claude is never opened)"
note "lanes: $LANES"

archive_of () {   # $1 = tier -> the basename the packager declares for it
  case "$1" in
    core)     _b="RoT-MoE-Router.zip" ;;
    lean)     _b="RoT-MoE-Router-Lean.zip" ;;
    unsealed) _b="RoT-MoE-Router-Lean-Extra.zip" ;;
    *)        return 1 ;;
  esac
  for vp in $VARIANT_MAP; do
    [ "${vp%%:*}" = "$_b" ] && { printf '%s' "$_b"; return 0; }
  done
  return 1
}

prompt_for () {
  case "$1" in
    FORGE)      echo "lake build the theorem and fix the sorry in mathlib" ;;
    CLINICAL)   echo "debug this error and audit the security of the fix" ;;
    EMPATHIC)   echo "I feel lonely and tired, this story makes me sad" ;;
    STRATEGIC)  echo "plan the roadmap and prioritize the legal strategy" ;;
    CREATIVE)   echo "invent a surreal paradox, embrace the chaos" ;;
    PREDICTIVE) echo "what is the likely future scenario, forecast the trend" ;;
    STEALTH)    echo "compress this to fewer tokens, distill it concise" ;;
    RECURSIVE)  echo "refactor the meta architecture, evolve the ontology" ;;
    EXECUTIVE)  echo "decide now, declare the urgency, conclude it" ;;
  esac
}

# The observable is the router's OWN OUTPUT. Claude Code's hook debug log does
# not echo the command it ran, so grepping for the command string finds nothing
# even when the hook fired perfectly.
#
# THE MARKER MUST NOT BE A SUBSTRING OF ANYTHING ELSE IN THE LOG, and the first
# draft got this wrong in the direction that MATTERS. It used "RoT", which is a
# substring of this repository's own directory name ("RoT MoE"), and Claude Code
# prints that path in the debug log. The armed assertions still passed for the
# right reason -- they match the full "<LANE> <Lens>" pair -- but the DISARMED
# control reported 8 hits and failed, blaming a router that had already been
# removed from settings.json.
#
# That failure direction is the lucky one: a false alarm is noticed. The same
# bug with a marker too NARROW would have reported the control clean while the
# armed lanes silently found nothing. The real emitted line is:
#     RoT MoE :: TIER 1 -> FORGE Claude
# so the marker is anchored on the "::" separator, which no path can contain.
MARKER="MoE :: TIER"

# WHAT THIS FILE DOES *NOT* PROVE -- measured, and it must be said in the file
# rather than in a report nobody reads beside it.
#
# The scratch config here is EMPTY, so it carries no credential. Every session
# below therefore returns  is_error: true, "Not logged in", exit 1  -- and the
# assertions still pass, because UserPromptSubmit runs BEFORE the model call.
# That makes this an honest test of ROUTING and a WORTHLESS test of
# CONVERSATION, and I first reported it as the latter.
#
# It is kept, deliberately, because routing is what it isolates: no credential,
# no token spend, no model variance, 27 lanes in seven minutes. The sustained
# conversation -- cloned auth, resumed turns, real answers -- is a separate
# instrument in checker/release-longsession.sh. Neither substitutes for the
# other, and this banner exists so the distinction cannot quietly rot.
echo
note "SCOPE: this gate proves the router FIRES and ROUTES from each archive."
note "SCOPE: sessions here are UNAUTHENTICATED by design -- no model turn occurs."
note "SCOPE: real multi-turn conversation is proved by checker/release-longsession.sh."

TOTAL_LANES=0; TOTAL_OK=0

for v in $WANT; do
  zn="$(archive_of "$v")"
  if [ -z "$zn" ]; then
    bad "$v: the packager's map does not declare this tier's archive -- name drift, not a missing build"
    continue
  fi
  ART="$REL/$zn"
  echo
  echo "############ $v ($zn) ############"
  if [ ! -s "$ART" ]; then
    bad "$v: no artifact at $ART -- run checker/release-package.sh first"
    continue
  fi

  VW="$WORK/$v"; PLUG="$VW/plugin"; CFG="$VW/.claude"
  mkdir -p "$PLUG" "$CFG"
  unzip -q "$ART" -d "$PLUG" 2>/dev/null || { bad "$v: the artifact did not unpack"; continue; }
  SETTINGS="$CFG/settings.json"
  printf '{\n  "model": "sonnet"\n}\n' > "$SETTINGS"
  cp "$SETTINGS" "$VW/settings.before.json"

  # The expected lens is read from THIS ARCHIVE's router, not from a copy here.
  # A hard-coded expectation is a second source of truth that silently rots --
  # and reading it per variant also proves the three archives agree.
  # NO LINE NUMBERS. The table sits at lines 70-78 today; a hard-coded range is
  # a snapshot that silently starts reading the wrong thing the first time a
  # comment is added above it -- and it would fail OPEN, returning empty and
  # blaming the router for a defect in this checker.
  #
  # `then _lane="..."`, NOT `then echo "..."`. The router's table moved from
  # echoing the lane to assigning it, and this sed kept matching the OLD shape
  # -- so it failed open exactly as the note above predicts: every lane
  # reported "could not read the expected lens" against three archives whose
  # routers were correct, and zero sessions ran. Measured 2026-08-17, while
  # the archive names were being re-cut for 6.0.0; the drift predates that
  # change and had gone unseen because CI deliberately does not run this gate.
  lens_for () {
    sed -n "s/^[[:space:]]*\(el\)\?if .*then _lane=\"$1 \([A-Za-z]*\)\".*/\2/p" \
      "$PLUG/hooks/rot-router.sh" | head -1
  }

  # --- interlock: prove the target BEFORE writing ----------------------------
  dry=$( cd "$PLUG" && CLAUDE_CONFIG_DIR="$CFG" CLAUDE_DIR="$CFG" \
         run_bounded 60 bash ./ARM_ROUTER.sh --dry-run 2>&1 )
  target=$(printf '%s' "$dry" | sed -n 's/.*config dir[[:space:]]*:[[:space:]]*//p' | head -1)
  case "$target" in
    "$CFG"|"$CFG"/*) ok "$v: INTERLOCK -- the installer resolves to this variant's scratch config" ;;
    *) bad "$v: INTERLOCK -- would write to '$target', NOT the scratch dir. SKIPPING this variant."
       continue ;;
  esac

  ( cd "$PLUG" && CLAUDE_CONFIG_DIR="$CFG" CLAUDE_DIR="$CFG" bash ./ARM_ROUTER.sh >"$VW/arm.log" 2>&1 )
  arc=$?
  [ "$arc" -eq 0 ] && ok "$v: ARM_ROUTER ran from the unpacked artifact" \
                   || bad "$v: ARM_ROUTER exited $arc"
  grep -q 'rot-router' "$SETTINGS" && ok "$v: the scratch settings.json carries a rot-router hook" \
                                   || { bad "$v: no rot-router entry -- nothing can fire"; continue; }

  run_session () {   # $1 = tag, $2 = prompt
    CLAUDE_CONFIG_DIR="$CFG" \
    timeout "$SESSION_TIMEOUT" claude -p "$2" \
      --settings "$SETTINGS" \
      --debug hooks \
      --debug-file "$VW/$1.debug" \
      > "$VW/$1.out" 2> "$VW/$1.err"
    rc=$?
    [ "$rc" -eq 124 ] && note "session[$v/$1] TIMED OUT -- evidence ABSENT, not negative"
    return $rc
  }

  vrun=0; vok=0
  for lane in $LANES; do
    p="$(prompt_for "$lane")"
    [ -n "$p" ] || { note "no prompt defined for lane $lane -- skipped"; continue; }
    expect="$(lens_for "$lane")"
    if [ -z "$expect" ]; then
      bad "$v/$lane: could not read the expected lens out of the shipped router"
      continue
    fi
    vrun=$((vrun+1)); TOTAL_LANES=$((TOTAL_LANES+1))
    run_session "$lane" "$p"; src=$?
    hit=$(grep -hF "$MARKER" "$VW/$lane.debug" "$VW/$lane.out" 2>/dev/null | grep -c . || true)
    if [ "$src" -eq 124 ]; then
      bad "$v/$lane: session timed out at ${SESSION_TIMEOUT}s -- no evidence either way"
    elif [ "$hit" -eq 0 ]; then
      bad "$v/$lane: the router NEVER FIRED in a real session (0 marker lines)"
    elif grep -hF "$MARKER" "$VW/$lane.debug" "$VW/$lane.out" 2>/dev/null | grep -c "$lane $expect" >/dev/null; then
      ok "$v/$lane -> $expect"
      vok=$((vok+1)); TOTAL_OK=$((TOTAL_OK+1))
    else
      bad "$v/$lane: fired but routed elsewhere (expected '$lane $expect')"
      grep -hF "$MARKER" "$VW/$lane.debug" "$VW/$lane.out" 2>/dev/null | head -1 | sed 's/^/        /'
    fi
  done
  [ "$vrun" -gt 0 ] && [ "$vok" -eq "$vrun" ] && ok "$v: ALL $vok of $vrun lanes routed correctly through the real CLI"

  # --- the control: disarm, and the router must go SILENT --------------------
  # Without this, the block above proves only that SOMETHING printed. If the
  # marker still appears after disarming, it was never the hook producing it.
  ( cd "$PLUG" && CLAUDE_CONFIG_DIR="$CFG" CLAUDE_DIR="$CFG" bash ./DISARM_ROUTER.sh >"$VW/disarm.log" 2>&1 )
  grep -q 'rot-router' "$SETTINGS" && bad "$v: router STILL registered after disarm" \
                                   || ok "$v: the hook entry is gone after disarm"

  run_session "disarmed" "$(prompt_for FORGE)"; drc=$?
  dhit=$(grep -hF "$MARKER" "$VW/disarmed.debug" "$VW/disarmed.out" 2>/dev/null | grep -c . || true)
  if [ "$drc" -eq 124 ]; then
    bad "$v: CONTROL INCONCLUSIVE -- the disarmed session timed out, absence proves nothing"
  elif [ "$dhit" -eq 0 ]; then
    ok "$v: CONTROL -- DISARMED, the router is SILENT, so the armed hits were really the hook"
  else
    bad "$v: CONTROL DEAD -- the marker appears $dhit time(s) with the router DISARMED"
    grep -hF "$MARKER" "$VW/disarmed.debug" "$VW/disarmed.out" 2>/dev/null | head -2 | sed 's/^/        /'
  fi

  if cmp -s "$VW/settings.before.json" "$SETTINGS"; then
    ok "$v: settings.json is BYTE-IDENTICAL after arm -> $vrun sessions -> disarm"
  else
    bad "$v: settings.json differs after the round trip:"
    diff -u "$VW/settings.before.json" "$SETTINGS" 2>/dev/null | head -10 | sed 's/^/        /'
  fi
done

echo
printf '  ----  %d of %d lane-sessions routed correctly across all variants\n' "$TOTAL_OK" "$TOTAL_LANES"
if [ "$TOTAL_LANES" -eq 0 ]; then
  bad "NO SESSION RAN AT ALL -- that is a harness failure, not a pass"
fi

printf '\n== release session: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
