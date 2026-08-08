#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# ROUTER DUPLICATION -- arming on top of a plugin install must not double-fire.
#
# THE DEFECT, MEASURED 2026-08-04 on the author's own machine. The packet reaches
# a session by two routes and they are ADDITIVE:
#
#   plugin install  ->  hooks/hooks.json binds rot-router on UserPromptSubmit and
#                       PreToolUse via ${CLAUDE_PLUGIN_ROOT}
#   ARM_ROUTER      ->  writes an absolute-path entry for THE SAME script on THE
#                       SAME two events into settings.json
#
# CLAUDE.md told the installing agent to do both. The router then fires TWICE per
# prompt: two marker lines, two gauge computations, twice the tokens, forever.
# Counted in a live transcript; settings.json and the plugin's own hooks.json
# each accounted for exactly one of the two.
#
# Nothing about that state looks wrong from inside -- the lane is right and the
# gauge is right. It is right twice. That is why it needs a gate and not a
# sentence in a README.
#
# The Lean statement of the same thing is lean/Proofs/RotDuplicate.lean:
# `unguarded_duplicates` (count = 2) and `guard_keeps_one` (count = 1). This file
# is the executable half: it runs the SHIPPED installer against scratch configs.
#
# WHAT MAKES THIS A CHECK AND NOT A CEREMONY -- the controls, in both directions:
#   * with a plugin present, arming must change NOTHING (byte-identical file);
#   * with NO plugin, arming must still arm (or the guard has simply broken the
#     installer for everyone not using the marketplace);
#   * --force must override, or the escape hatch is decorative;
#   * a DISABLED plugin must not trigger the guard -- it registers nothing, so
#     arming is then correct;
#   * both arms must agree, because a guard on one arm is a guard for one OS.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0; skip=0
ok()   { echo "  PASS  $*"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=router-duplication::%s\n' "$*"; fail=$((fail+1)); }
note() { echo "        $*"; }

echo "== router duplication: the plugin and ARM_ROUTER must not stack =="

command -v node >/dev/null 2>&1 || { bad "node not found -- cannot run the installer"; echo "  router-duplication: FAIL"; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/rotdup.XXXXXX")"
cleanup () { rm -rf "$TMP"; }
trap cleanup EXIT

# --- fixtures ----------------------------------------------------------------
# A scratch Claude config. `enabled` decides whether the plugin registration is
# live; a plugin present but disabled registers nothing.
make_cfg () {   # make_cfg <dir> <with-plugin: yes|no> <enabled: true|false>
  d="$1"; withp="$2"; en="$3"
  mkdir -p "$d"
  if [ "$withp" = yes ]; then
    mkdir -p "$d/plugins/cache/somemarket/rot-moe/1.2.3/hooks"
    cp hooks/hooks.json "$d/plugins/cache/somemarket/rot-moe/1.2.3/hooks/hooks.json"
    printf '{\n  "enabledPlugins": {\n    "rot-moe@somemarket": %s\n  }\n}\n' "$en" > "$d/settings.json"
  else
    printf '{}\n' > "$d/settings.json"
  fi
}

count_entries () {   # count_entries <settings.json> -> number of rot-router hook commands
  node -e '
    const fs=require("fs");
    let s; try { s=JSON.parse(fs.readFileSync(process.argv[1],"utf8").replace(/^﻿/,"")); }
    catch(e) { console.log("PARSE-ERROR"); process.exit(0); }
    let n=0;
    for (const ev of Object.keys(s.hooks||{}))
      for (const g of (s.hooks[ev]||[]))
        for (const h of (g.hooks||[])) if (/rot-router/.test(h.command||"")) n++;
    console.log(n);' "$1"
}

hash_of () { md5sum "$1" 2>/dev/null | cut -d' ' -f1 || cksum "$1" | cut -d' ' -f1; }

# HOW MANY ROUTER ENTRIES A SUCCESSFUL ARM PRODUCES -- DERIVED, NOT LITERAL.
#
# This file asserted the number 2, four times over. That was correct while the
# installer bound two events, and it turned RED on a correct change the moment
# the installer legitimately grew to bind eleven. Same shape as the SessionStart
# assertion in install-roundtrip.sh: a CONTINGENT FACT written down as if it
# were an invariant, which fails loudly on good work and invites the repair that
# destroys the coverage -- weaken the number until it passes.
#
# What the checker actually cares about is not "two" but "one router entry per
# event the installer declares, and nothing stacked on top". So the count is
# read from ARM_ROUTER.sh's own declared list at run time. Grow the list and
# this still asserts the right thing; stack a duplicate registration and it
# still fails, which is the defect this file exists to catch.
ARM_EVENTS_CSV="$(sed -n "s/^EVENTS_CSV='\\(.*\\)'$/\\1/p" "$REPO/ARM_ROUTER.sh")"
WANT_ENTRIES="$(printf '%s' "$ARM_EVENTS_CSV" | tr ',' '\n' | grep -c .)"
if [ -z "$ARM_EVENTS_CSV" ] || [ "${WANT_ENTRIES:-0}" -lt 1 ]; then
  echo "REFUSE: could not read EVENTS_CSV from ARM_ROUTER.sh -- every count below would be fabricated"
  exit 2
fi
echo "  (expectation derived from ARM_ROUTER.sh: $WANT_ENTRIES declared event(s))"

# --- ARM 1: POSIX ------------------------------------------------------------
run_case () {   # run_case <label> <arm: sh|ps1> <withplugin> <enabled> <extra-flag> <expect-entries>
  label="$1"; arm="$2"; withp="$3"; en="$4"; flag="$5"; want="$6"
  d="$TMP/$(echo "$label$arm" | tr -cd 'A-Za-z0-9')"
  make_cfg "$d" "$withp" "$en"
  before="$(hash_of "$d/settings.json")"
  if [ "$arm" = sh ]; then
    CLAUDE_CONFIG_DIR="$d" bash ARM_ROUTER.sh $flag >"$d/out.txt" 2>&1
  else
    CLAUDE_CONFIG_DIR="$d" pwsh -NoProfile -File ./ARM_ROUTER.ps1 $flag >"$d/out.txt" 2>&1
  fi
  rc=$?
  after="$(hash_of "$d/settings.json")"
  got="$(count_entries "$d/settings.json")"
  if [ "$rc" -ne 0 ]; then
    bad "$label [$arm]: installer exited $rc"
    note "$(tail -3 "$d/out.txt")"
    return
  fi
  if [ "$got" != "$want" ]; then
    bad "$label [$arm]: expected $want settings.json router entries, measured $got"
    note "$(tail -5 "$d/out.txt")"
    return
  fi
  ok "$label [$arm]: $got settings.json router entries (expected $want)"
  # When the guard fires, refusal must be TOTAL: not a partial write, not a
  # reformat, not a tidy-up. Byte equality is the only honest form of that.
  if [ "$want" = 0 ] && [ "$before" != "$after" ]; then
    bad "$label [$arm]: guard refused but the file CHANGED -- refusal must write nothing"
  fi
}

ARMS="sh"
if command -v pwsh >/dev/null 2>&1; then ARMS="sh ps1"; else
  echo "  SKIP  no pwsh on this runner -- the PowerShell arm was NOT exercised."
  echo "        This is a SKIP, never a PASS: an unrun arm proves nothing."
  skip=1
fi

for arm in $ARMS; do
  # THE DEFECT: plugin live -> arming must add nothing.
  run_case "plugin live, guard must refuse" "$arm" yes true "" 0
  # THE CONTROL that stops the guard from being a way to break the installer.
  run_case "no plugin, must still arm"      "$arm" no  true "" "$WANT_ENTRIES"
  # A disabled plugin registers nothing, so arming is correct.
  run_case "plugin present but DISABLED"    "$arm" yes false "" "$WANT_ENTRIES"
done

# --force / -Force must override, or the escape hatch is decoration.
d="$TMP/force-sh"; make_cfg "$d" yes true
CLAUDE_CONFIG_DIR="$d" bash ARM_ROUTER.sh --force >"$d/out.txt" 2>&1
if [ "$(count_entries "$d/settings.json")" = "$WANT_ENTRIES" ]; then
  ok "--force overrides the guard [sh]"
else
  bad "--force did not arm [sh] -- the documented escape hatch does not work"
fi
if command -v pwsh >/dev/null 2>&1; then
  d="$TMP/force-ps1"; make_cfg "$d" yes true
  CLAUDE_CONFIG_DIR="$d" pwsh -NoProfile -File ./ARM_ROUTER.ps1 -Force >"$d/out.txt" 2>&1
  if [ "$(count_entries "$d/settings.json")" = "$WANT_ENTRIES" ]; then
    ok "-Force overrides the guard [ps1]"
  else
    bad "-Force did not arm [ps1] -- cross-arm parity broken on the escape hatch"
  fi
fi

# An unknown flag must REFUSE, not be swallowed. Swallowing an argument is how
# DISARM's --dry-run once deleted live hook entries.
d="$TMP/badflag"; make_cfg "$d" no true
CLAUDE_CONFIG_DIR="$d" bash ARM_ROUTER.sh --not-a-flag >"$d/out.txt" 2>&1
rc=$?
if [ "$rc" = 2 ] && [ "$(count_entries "$d/settings.json")" = "0" ]; then
  ok "an unknown flag refuses (exit 2) and writes nothing [sh]"
else
  bad "an unknown flag was swallowed [sh]: exit $rc, entries $(count_entries "$d/settings.json")"
fi

# --- THE DETECTOR'S OWN NEGATIVE CONTROL -------------------------------------
# plugin-detect.js is the thing the guard trusts. If it could never say "no",
# the guard would refuse for everyone and the second case above would already
# have failed -- but if it could never say "yes", every case would pass while the
# duplicate came straight back. Both directions, explicitly.
d="$TMP/detect-yes"; make_cfg "$d" yes true
node hooks/plugin-detect.js "$d" >/dev/null 2>&1
[ $? -eq 0 ] && ok "plugin-detect says LIVE when a plugin is enabled" \
             || bad "plugin-detect failed to see an enabled plugin"
d="$TMP/detect-no"; make_cfg "$d" no true
node hooks/plugin-detect.js "$d" >/dev/null 2>&1
[ $? -eq 10 ] && ok "plugin-detect says NONE when there is no plugin" \
              || bad "plugin-detect claimed a registration that does not exist"

# A plugin whose hooks.json does NOT bind the router must not trigger the guard.
# The detector keys on the FACT (a hooks.json binding rot-router), never on the
# directory being called rot-moe -- a marketplace can rename it.
d="$TMP/detect-other"; mkdir -p "$d/plugins/cache/mp/other/1.0.0/hooks"
printf '{"hooks":{"UserPromptSubmit":[{"matcher":"*","hooks":[{"type":"command","command":"echo hi"}]}]}}\n' \
  > "$d/plugins/cache/mp/other/1.0.0/hooks/hooks.json"
printf '{"enabledPlugins":{"other@mp":true}}\n' > "$d/settings.json"
node hooks/plugin-detect.js "$d" >/dev/null 2>&1
[ $? -eq 10 ] && ok "an unrelated plugin does not trigger the guard" \
              || bad "the guard fired on a plugin that does not bind the router"

# --- THE CACHE IS AN ACCUMULATOR ---------------------------------------------
# MEASURED on the CTT instance 2026-08-04, and it corrected the detector rather
# than the code under test. `claude plugin update` leaves EVERY previous version
# in the cache: that machine held seven directories, 0.1.2 through 0.7.2, each
# with a hooks.json binding the router, under ONE enabled plugin id.
#
# The detector walked the cache and reported all seven as live registrations --
# which reads like a sevenfold duplication and is false. `installed_plugins.json`
# records exactly one `installPath` per plugin, and that is the version Claude
# Code loads; the rest are inert.
#
# This fixture reproduces that shape. The assertion is not merely "exit 0" -- an
# over-reporting detector also exits 0 -- it is that EXACTLY ONE registration is
# named, and that it is the one the manifest points at.
d="$TMP/detect-stale-cache"
mkdir -p "$d/plugins/cache/mp/rot/0.1.0/hooks" \
         "$d/plugins/cache/mp/rot/0.2.0/hooks" \
         "$d/plugins/cache/mp/rot/0.3.0/hooks"
for v in 0.1.0 0.2.0 0.3.0; do
  printf '{"hooks":{"UserPromptSubmit":[{"matcher":"*","hooks":[{"type":"command","command":"sh ${CLAUDE_PLUGIN_ROOT}/hooks/rot-router.sh"}]}]}}\n' \
    > "$d/plugins/cache/mp/rot/$v/hooks/hooks.json"
done
printf '{"enabledPlugins":{"rot@mp":true}}\n' > "$d/settings.json"
# THE PATH IN THE MANIFEST MUST BE ONE **NODE** CAN OPEN. Claude Code writes a
# native path there ("C:\\Users\\...\\0.7.2" on Windows, measured). Writing this
# fixture's Git Bash path instead produced a manifest node resolved onto the
# wrong drive, so the read failed, the detector fell back to the cache walk and
# this case reported three registrations -- a fixture defect that looked exactly
# like the detector bug it was written to catch.
canon_np () {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1" 2>/dev/null | sed 's/\\/\\\\/g'
  else printf '%s' "$1"; fi
}
printf '{"version":2,"plugins":{"rot@mp":[{"scope":"user","installPath":"%s","version":"0.3.0"}]}}\n' \
  "$(canon_np "$d/plugins/cache/mp/rot/0.3.0")" > "$d/plugins/installed_plugins.json"

out=$(node hooks/plugin-detect.js "$d" 2>&1); rc=$?
n_paths=$(printf '%s\n' "$out" | grep -c "^  path=")
if [ "$rc" -eq 0 ] && [ "$n_paths" -eq 1 ] && grep -q "0.3.0" <<<"$out"; then
  ok "a cache holding superseded versions yields ONE registration (the installed one)"
else
  bad "stale cache misreported: exit $rc, $n_paths path line(s) -- expected 1, naming 0.3.0"
  printf '%s\n' "$out" | sed 's/^/        /'
fi

# And the FALLBACK must still work: a config written by a CLI old enough to have
# no manifest is not a config with no plugin. Deleting the manifest from the same
# fixture must still detect a live registration.
rm -f "$d/plugins/installed_plugins.json"
node hooks/plugin-detect.js "$d" >/dev/null 2>&1
[ $? -eq 0 ] && ok "with no installed_plugins.json the cache walk still detects the plugin" \
             || bad "removing the manifest blinded the detector -- the fallback is dead"

echo
echo "  $pass passed, $fail failed, $skip skipped"
if [ "$fail" -gt 0 ]; then echo "  router-duplication: FAIL"; exit 1; fi
echo "  router-duplication: PASS"
exit 0
