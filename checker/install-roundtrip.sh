#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# R4 / R5 / R6 -- the byte-level half that Lean CANNOT give.
#
# lean/Proofs/RotInstall.lean proves the MERGE is sound: preservation over all
# keys, idempotence, append-order, the lossy-uninstall case. It proves none of
# what follows, because Lean sees a finite map and this sees a FILE:
#
#   * a UTF-8 BOM (present on the real settings.json -- measured)
#   * line endings, key order, indentation
#   * whether the backup is actually restorable
#   * whether the writer produced what the merge intended
#
# EVERYTHING RUNS AGAINST A SCRATCH CLAUDE_DIR IN A TEMP DIRECTORY.
# The live ~/.claude/settings.json is never opened by this script. Testing an
# installer against the config the current session is using is how you lose the
# session you are testing from.
#
# Each phase has an explicit negative control. A phase whose control does not go
# red is reported as DECORATIVE rather than counted as a pass.
# =============================================================================

set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rotmoe-roundtrip.XXXXXX")"
export CLAUDE_DIR="$WORK/.claude"
mkdir -p "$CLAUDE_DIR"
S="$CLAUDE_DIR/settings.json"

pass=0; fail=0
ok()   { echo "  PASS  $*"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=install-roundtrip::%s\n' "$*"; fail=$((fail+1)); }
h()    { echo; echo "== $* =="; }

# --- the fixture ------------------------------------------------------------
# Deliberately hostile, and every hostile trait is one measured on the real
# file or named in the spec as a hazard:
#   * a UTF-8 BOM (the real settings.json has one)
#   * a NESTED critical key (permissions.defaultMode), not a top-level one
#   * pre-existing hooks on an event we arm, so append-order can be checked
#   * a pre-existing hook on an event we do NOT touch
#   * an empty matcher group the user owns, which we must not tidy away
#   * a unicode value, so re-encoding damage would show
make_fixture () {
  printf '\xEF\xBB\xBF' > "$S"
  cat >> "$S" <<'JSON'
{
  "env": { "ANTHROPIC_BASE_URL": "http://127.0.0.1:9999" },
  "permissions": {
    "defaultMode": "bypassPermissions",
    "allow": ["Bash(git status)", "Read(//**)"]
  },
  "model": "opus[1m]",
  "effortLevel": "high",
  "skipDangerousModePermissionPrompt": true,
  "theme": "dark-daltonized",
  "note": "unicode: äöü — 日本語",
  "hooks": {
    "UserPromptSubmit": [
      { "matcher": "*", "hooks": [ { "type": "command", "command": "echo user-owned-1" } ] }
    ],
    "SessionStart": [
      { "matcher": "*", "hooks": [ { "type": "command", "command": "echo user-owned-sessionstart" } ] }
    ],
    "ZZ_ForeignEvent": [
      { "matcher": "*", "hooks": [ { "type": "command", "command": "echo untouched-event" } ] }
    ],
    "PostToolUse": [
      { "matcher": "*", "hooks": [] }
    ]
  }
}
JSON
}

jget () { CLAUDE_SETTINGS="$1" node -e '
  const fs=require("fs");
  const r=fs.readFileSync(process.env.CLAUDE_SETTINGS,"utf8");
  const s=JSON.parse(r.charCodeAt(0)===0xFEFF?r.slice(1):r);
  let v=s; if (process.argv[1]) for (const k of process.argv[1].split(".")) v = v===undefined?undefined:v[k];
  console.log(JSON.stringify(v));' "$2"; }

hasbom () { head -c3 "$1" | od -An -tx1 | tr -d ' \n' | grep -ci '^efbbbf' >/dev/null; }

# ============================================================================
h "R4 -- ARM_ROUTER is non-destructive"
# ============================================================================
make_fixture
cp "$S" "$WORK/pre-install.json"
bash "$REPO/ARM_ROUTER.sh" > "$WORK/arm1.log" 2>&1; ARM_RC=$?
echo "  ARM_ROUTER exit=$ARM_RC"
[ "$ARM_RC" -eq 0 ] && ok "installer exited 0" || bad "installer exited $ARM_RC"

# every pre-existing key survives, checked by VALUE not by presence
for probe in "permissions.defaultMode:\"bypassPermissions\"" \
             "permissions.allow:[\"Bash(git status)\",\"Read(//**)\"]" \
             "skipDangerousModePermissionPrompt:true" \
             "effortLevel:\"high\"" \
             "model:\"opus[1m]\"" \
             "env.ANTHROPIC_BASE_URL:\"http://127.0.0.1:9999\"" \
             "theme:\"dark-daltonized\""; do
  key="${probe%%:*}"; want="${probe#*:}"
  got="$(jget "$S" "$key")"
  [ "$got" = "$want" ] && ok "preserved $key" || bad "CHANGED $key: want $want got $got"
done

# the unicode value must survive re-encoding
[ "$(jget "$S" note)" = "$(jget "$WORK/pre-install.json" note)" ] \
  && ok "unicode value preserved" || bad "unicode value damaged"

# the BOM must survive -- the real file has one and we must not silently drop it
hasbom "$S" && ok "BOM state preserved" || bad "BOM was stripped"

# AN EVENT OUTSIDE THE INSTALLER'S DECLARED LIST MUST BE BIT-IDENTICAL.
#
# This assertion used to name SessionStart as "an event we never touch". That
# was true when the installer bound two events, and it went RED the moment the
# installer legitimately grew to bind eleven -- on a correct change. That is the
# worst shape a check can have: it fails loudly on good work, and the obvious
# repair is to delete it, which destroys the coverage.
#
# The defect was in the check, not in the change. What actually matters is not
# "SessionStart specifically is untouched" but "anything the installer does NOT
# declare is untouched", so the property is now quantified over the installer's
# own declared list, read from ARM_ROUTER.sh at run time. Grow the list to fifty
# events and this still asserts the right thing.
#
# The fixture carries ZZ_ForeignEvent precisely so the loop below can never be
# vacuous: if every pre-install event happened to be one the installer binds,
# the loop would compare nothing and pass in silence. The count is asserted.
DECLARED_CSV="$(sed -n "s/^EVENTS_CSV='\\(.*\\)'$/\\1/p" "$REPO/ARM_ROUTER.sh")"
if [ -z "$DECLARED_CSV" ]; then
  bad "could not read EVENTS_CSV from ARM_ROUTER.sh -- the untouched-event check cannot be evaluated"
else
  _checked=0
  for _ev in $(node -e '
    const fs=require("fs");
    const pre=JSON.parse(fs.readFileSync(process.argv[1],"utf8").replace(/^﻿/,""));
    const declared=new Set(process.argv[2].split(",").map(s=>s.trim()));
    for (const k of Object.keys(pre.hooks||{})) if (!declared.has(k)) console.log(k);
  ' "$WORK/pre-install.json" "$DECLARED_CSV"); do
    _checked=$((_checked+1))
    if [ "$(jget "$S" "hooks.$_ev")" = "$(jget "$WORK/pre-install.json" "hooks.$_ev")" ]; then
      ok "undeclared event untouched: $_ev"
    else
      bad "UNDECLARED event changed: $_ev -- the installer edited an event it does not bind"
    fi
  done
  [ "$_checked" -gt 0 ] \
    && ok "the undeclared-event check compared $_checked event(s) -- not vacuous" \
    || bad "the undeclared-event check compared NOTHING; every fixture event is declared, so it proves nothing"
fi

# THE USER'S OWN EMPTY GROUP MUST STILL BE THERE -- not ours to tidy.
#
# This check USED to compare the whole PostToolUse key against pre-install, and
# that was a dated assertion rather than the invariant it was named for: it
# encoded "the installer never touches PostToolUse", which was true only while
# ARM_ROUTER wired the router alone. The moment the installer began registering
# prover-remind on the three events the plugin binds it to -- a correct change,
# closing a real parity gap -- this went red, and the obvious repair (delete the
# check) would have destroyed the coverage of the thing it actually guards.
#
# What matters is that OUR edit is additive: the user's group survives verbatim,
# and everything else under that key is ours. Stated that way it holds however
# many events the installer grows into.
_pre_g=$(node -e '
  const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").replace(/^﻿/,""));
  process.stdout.write(JSON.stringify((s.hooks&&s.hooks.PostToolUse)||[]));' "$WORK/pre-install.json")
_post_ok=$(node -e '
  const fs=require("fs");
  const rd=p=>JSON.parse(fs.readFileSync(p,"utf8").replace(/^﻿/,""));
  const pre=(rd(process.argv[1]).hooks||{}).PostToolUse||[];
  const post=(rd(process.argv[2]).hooks||{}).PostToolUse||[];
  const key=g=>JSON.stringify(g);
  const preKeys=pre.map(key);
  // every pre-existing group survives, byte-for-byte
  const survived=preKeys.every(k=>post.some(g=>key(g)===k));
  // every group we added invokes only RoT MoE hooks
  const extras=post.filter(g=>!preKeys.includes(key(g)));
  const oursOnly=extras.every(g=>(g.hooks||[]).every(h=>
    /(rot-router|prover-remind|rot-voice-gate)\.(ps1|sh)/.test(h.command||"")));
  process.stdout.write(survived&&oursOnly?"yes":"no");' \
  "$WORK/pre-install.json" "$S")
[ "$_post_ok" = "yes" ] \
  && ok "user's empty group left alone (installer edit is additive)" \
  || bad "user's empty group was tidied, or a non-RoT group appeared"

# and the router must actually be there (non-vacuity: an installer that does
# nothing passes every check above)
grep -q 'rot-router' "$S" && ok "router hook present (non-vacuity)" || bad "router NOT installed"

# the user's hook must still fire FIRST -- we append
first="$(CLAUDE_SETTINGS="$S" node -e '
  const fs=require("fs");const r=fs.readFileSync(process.env.CLAUDE_SETTINGS,"utf8");
  const s=JSON.parse(r.charCodeAt(0)===0xFEFF?r.slice(1):r);
  console.log(s.hooks.UserPromptSubmit[0].hooks[0].command);')"
[ "$first" = "echo user-owned-1" ] && ok "user's hook still first (appended, not prepended)" \
  || bad "ORDER CHANGED: first hook is now '$first'"

# ============================================================================
h "R6 -- idempotence: running twice adds the hooks once"
# ============================================================================
cp "$S" "$WORK/after-first.json"
bash "$REPO/ARM_ROUTER.sh" > "$WORK/arm2.log" 2>&1; ARM2_RC=$?
echo "  second ARM_ROUTER exit=$ARM2_RC"
n=$(grep -c 'rot-router' "$S")
n1=$(grep -c 'rot-router' "$WORK/after-first.json")
[ "$n" -eq "$n1" ] && ok "hook count unchanged after second run ($n)" \
  || bad "DOUBLE INSTALL: $n1 -> $n"
cmp -s "$S" "$WORK/after-first.json" && ok "file byte-identical after second run" \
  || bad "second run modified the file"

# ============================================================================
h "R5 -- DISARM restores exactly"
# ============================================================================
bash "$REPO/DISARM_ROUTER.sh" > "$WORK/disarm.log" 2>&1; DIS_RC=$?
echo "  DISARM_ROUTER exit=$DIS_RC"
[ "$DIS_RC" -eq 0 ] && ok "uninstaller exited 0" || bad "uninstaller exited $DIS_RC"
grep -q 'rot-router' "$S" && bad "router STILL present after disarm" || ok "router removed"

# --- R5 IS TWO CLAIMS, NOT ONE, AND THE FIRST RUN PROVED WHY -----------------
#
# The first version demanded byte-identity from the HOSTILE fixture and failed.
# The failure was real and stays visible: the installer round-trips through
# JSON.stringify, which cannot reproduce INTRA-LINE layout. A fixture written
# as `"env": { "A": "b" }` on one line comes back expanded over three. Nothing
# is lost -- keys, values, order, BOM and indent width all survive -- but the
# bytes move.
#
# Weakening the check to "semantically equal" and moving on would have been the
# violation: it would quietly drop the only guard against the measured
# 3674 -> 9564 byte reformat hazard. So R5 is SPLIT and both halves must pass:
#
#   R5a  SEMANTIC round trip on the hostile fixture. Reformatting is REPORTED
#        with its byte delta, never ignored.
#   R5b  BYTE-IDENTICAL round trip on a CANONICAL fixture -- one already in the
#        installer's own output form, which is what a settings.json written by
#        Claude Code looks like. This is the strong claim, and it is what would
#        catch a writer that drops a key or moves the BOM.

sem_a="$(jget "$WORK/pre-install.json" "")"
sem_b="$(jget "$S" "")"
if [ "$sem_a" = "$sem_b" ]; then
  ok "R5a post-uninstall SEMANTICALLY identical to pre-install (deep compare)"
else
  bad "R5a post-uninstall differs in VALUE from pre-install:"
  diff <(printf '%s\n' "$sem_a") <(printf '%s\n' "$sem_b") | head -20 | sed 's/^/        /'
fi
if cmp -s "$S" "$WORK/pre-install.json"; then
  ok "R5a bytes also identical"
else
  pre_b=$(wc -c < "$WORK/pre-install.json"); post_b=$(wc -c < "$S")
  echo "  NOTE  hostile fixture REFORMATTED: $pre_b -> $post_b bytes."
  echo "        Keys/values/order/BOM/indent preserved; intra-line layout not."
  echo "        Stated in README and NOTICE; R5b is the byte-level claim."
fi
hasbom "$S" && ok "BOM survived the round trip" || bad "BOM lost in the round trip"

make_fixture
bash "$REPO/ARM_ROUTER.sh"    >/dev/null 2>&1
bash "$REPO/DISARM_ROUTER.sh" >/dev/null 2>&1   # file is now in canonical form
cp "$S" "$WORK/canonical-pre.json"
bash "$REPO/ARM_ROUTER.sh"    >/dev/null 2>&1
bash "$REPO/DISARM_ROUTER.sh" >/dev/null 2>&1
if cmp -s "$S" "$WORK/canonical-pre.json"; then
  ok "R5b canonical round trip is BYTE-IDENTICAL"
else
  bad "R5b canonical round trip changed bytes -- a real writer defect:"
  diff -u "$WORK/canonical-pre.json" "$S" | head -20 | sed 's/^/        /'
fi

# ============================================================================
h "--dry-run -- consent before the write, not a report after it"
# ============================================================================
# Rule 6 says "show the diff", and the original satisfied it by printing the
# diff AFTER writing. That is a report, not a choice. --dry-run has to be
# guarded by a test or it decays into a flag that lies: the dangerous failure
# is a dry run that writes, and it would look identical in the terminal.
make_fixture
DRY_BEFORE=$(cksum < "$S")
bash "$REPO/ARM_ROUTER.sh" --dry-run > "$WORK/dry.log" 2>&1
DRY_RC=$?
DRY_AFTER=$(cksum < "$S")
[ "$DRY_RC" -eq 0 ] && ok "--dry-run exit 0" || bad "--dry-run exit $DRY_RC"
[ "$DRY_BEFORE" = "$DRY_AFTER" ] \
  && ok "--dry-run left the file BYTE-IDENTICAL" \
  || bad "--dry-run MODIFIED the file -- the flag is lying"
grep -q 'rot-router' "$S" && bad "--dry-run actually installed the router" \
                          || ok "--dry-run installed nothing"
grep -q 'WOULD change' "$WORK/dry.log" \
  && ok "--dry-run showed the prospective diff" \
  || bad "--dry-run wrote nothing and showed nothing -- useless either way"
# It must still be able to ARM afterwards: a dry run that leaves the config in
# a state where the real install fails is worse than no dry run.
bash "$REPO/ARM_ROUTER.sh" >/dev/null 2>&1
grep -q 'rot-router' "$S" && ok "a real arm still works after a dry run" \
                          || bad "arming FAILED after a dry run"
bash "$REPO/DISARM_ROUTER.sh" >/dev/null 2>&1

# ============================================================================
h "BOTH INSTALLER ARMS -- .sh and .ps1 must write BYTE-IDENTICAL settings"
# ============================================================================
# The spec says ARM_ROUTER.ps1 honours "the same contract". Left as prose, that
# decays: two installers maintained side by side drift, and the drift shows up
# in a user's settings.json rather than in a test.
#
# They are byte-identical because both call ONE merge engine. That is a
# deliberate asymmetry with the router, which is duplicated on purpose -- for
# the router, two agreeing implementations ARE the evidence; for the installer
# there is nothing to cross-check against, so a second implementation would be
# a second chance to be wrong on the user's live config.
if [ -z "${PWSH_BIN:-}" ]; then
  PWSH_BIN=""
  for c in pwsh powershell; do command -v "$c" >/dev/null 2>&1 && { PWSH_BIN="$c"; break; }; done
fi
if [ -z "$PWSH_BIN" ]; then
  echo "  SKIP  no PowerShell -- the arms were NOT compared. A SKIP is not a PASS."
else
  # Canonicalise first, for the reason R5b already established: the hostile
  # fixture uses compact inline JSON that no parser round trip can reproduce, so
  # demanding byte-identity against IT would fail for a reason that has nothing
  # to do with the two arms agreeing. Comparing arms is the question here; the
  # reformat is already measured and reported by R5a.
  make_fixture
  bash "$REPO/ARM_ROUTER.sh"    >/dev/null 2>&1
  bash "$REPO/DISARM_ROUTER.sh" >/dev/null 2>&1
  cp "$S" "$WORK/arms-pre.json"
  bash "$REPO/ARM_ROUTER.sh" >/dev/null 2>&1
  cp "$S" "$WORK/armed-by-sh.json"
  cp "$WORK/arms-pre.json" "$S"
  "$PWSH_BIN" -NoProfile -File "$REPO/ARM_ROUTER.ps1" >/dev/null 2>&1
  cp "$S" "$WORK/armed-by-ps1.json"
  if cmp -s "$WORK/armed-by-sh.json" "$WORK/armed-by-ps1.json"; then
    ok "ARM_ROUTER.sh and ARM_ROUTER.ps1 wrote BYTE-IDENTICAL settings.json"
  else
    bad "INSTALLER ARMS DIVERGE -- one arm installs what the other cannot remove:"
    diff -u "$WORK/armed-by-sh.json" "$WORK/armed-by-ps1.json" | head -20 | sed 's/^/        /'
  fi
  # Cross-arm removal: install with one, uninstall with the OTHER. This is the
  # case a user actually hits after switching shells, and it is the one that
  # silently strands them if the command strings differ by a single character.
  "$PWSH_BIN" -NoProfile -File "$REPO/DISARM_ROUTER.ps1" >/dev/null 2>&1
  cmp -s "$S" "$WORK/arms-pre.json" \
    && ok "cross-arm: armed by .ps1, disarmed by .ps1, back to pre-install bytes" \
    || bad "cross-arm round trip did not restore the pre-install bytes"

  cp "$WORK/arms-pre.json" "$S"
  bash "$REPO/ARM_ROUTER.sh" >/dev/null 2>&1
  "$PWSH_BIN" -NoProfile -File "$REPO/DISARM_ROUTER.ps1" >/dev/null 2>&1
  if grep -q 'rot-router' "$S"; then
    bad "CROSS-ARM FAILURE: .ps1 could not remove what .sh installed"
  else
    ok "cross-arm: installed by .sh, REMOVED BY .ps1 (identical command strings)"
  fi
fi

# ============================================================================
h "NEGATIVE CONTROLS -- every check above must be able to go red"
# ============================================================================
ctl_pass=0; ctl_fail=0
ctl () { if [ "$2" -ne 0 ]; then echo "  CONTROL OK   $1 (detected, rc=$2)"; ctl_pass=$((ctl_pass+1));
         else echo "  CONTROL DEAD $1 -- the check is DECORATIVE"; ctl_fail=$((ctl_fail+1)); fi; }

# C1: a destructive installer must be caught. Simulate one directly: blow away
# a preserved key and assert the value probe notices.
make_fixture
# The env assignment must PRECEDE `node`. Written as `node -e '...' S="$S"` it
# becomes an ARGV entry, `process.env.S` is undefined, and node dies with
# ERR_INVALID_ARG_TYPE -- which this harness scored as "CONTROL DEAD". That
# reads as "the check is decorative" when the truth was "the control never
# ran". A control that CRASHES must never be reported as one that failed to
# fire; those are opposite findings and only one of them is about the subject.
SET="$S" node -e '
  const fs=require("fs");const f=process.env.SET;
  const r=fs.readFileSync(f,"utf8");const b=r.charCodeAt(0)===0xFEFF;
  const s=JSON.parse(b?r.slice(1):r);
  delete s.permissions.defaultMode;                 // the destruction
  fs.writeFileSync(f,(b?"﻿":"")+JSON.stringify(s,null,2)+"\n","utf8");' || \
  { echo "  CONTROL C1 CRASHED -- not a result"; ctl_fail=$((ctl_fail+1)); }
# Assert DETECTION, not a particular sentinel. The first version compared
# against "null" and stayed DEAD forever, because `JSON.stringify(undefined)`
# returns the JS value `undefined` -- which `console.log` prints as the text
# `undefined`, never `null`. The control was testing the probe's error
# vocabulary instead of its ability to see a missing key. What matters is only
# that the probe no longer returns the value the fixture put there.
got="$(jget "$S" permissions.defaultMode)"
if [ "$got" != '"bypassPermissions"' ]; then
  ctl "C1 destroyed nested key detected (probe now returns $got)" 1
else
  ctl "C1 destroyed nested key detected" 0
fi

# C2: a BOM-stripping writer must be caught.
make_fixture
tail -c +4 "$S" > "$S.nobom" && mv "$S.nobom" "$S"
if hasbom "$S"; then ctl "C2 BOM-strip detected" 0; else ctl "C2 BOM-strip detected" 1; fi

# C3: a double install must be caught -- append the command twice by hand.
make_fixture
bash "$REPO/ARM_ROUTER.sh" >/dev/null 2>&1
before_n=$(grep -c 'rot-router' "$S")
SET="$S" node -e '
  const fs=require("fs");const f=process.env.SET;
  const r=fs.readFileSync(f,"utf8");const b=r.charCodeAt(0)===0xFEFF;
  const s=JSON.parse(b?r.slice(1):r);
  const g=s.hooks.UserPromptSubmit.find(x=>x.hooks.some(h=>/rot-router/.test(h.command)));
  s.hooks.UserPromptSubmit.push(JSON.parse(JSON.stringify(g)));   // the double
  fs.writeFileSync(f,(b?"﻿":"")+JSON.stringify(s,null,2)+"\n","utf8");' || \
  { echo "  CONTROL C3 CRASHED -- not a result"; ctl_fail=$((ctl_fail+1)); }
after_n=$(grep -c 'rot-router' "$S")
[ "$after_n" -ne "$before_n" ] && ctl "C3 double-install detected" 1 || ctl "C3 double-install detected" 0

# C4: a lossy uninstaller must be caught -- skip the removal entirely.
make_fixture
cp "$S" "$WORK/c4-pre.json"
bash "$REPO/ARM_ROUTER.sh" >/dev/null 2>&1
if cmp -s "$S" "$WORK/c4-pre.json"; then ctl "C4 skipped-removal detected" 0
else ctl "C4 skipped-removal detected" 1; fi

# C5: the installer must REFUSE a settings.json that is already broken, rather
# than "fixing" it -- and must leave it untouched.
make_fixture
printf '\xEF\xBB\xBF{ this is not json' > "$S"
cp "$S" "$WORK/broken-pre.json"
bash "$REPO/ARM_ROUTER.sh" > "$WORK/broken.log" 2>&1; BRC=$?
if [ "$BRC" -ne 0 ] && cmp -s "$S" "$WORK/broken-pre.json"; then
  ctl "C5 invalid input refused and left untouched (rc=$BRC)" 1
else
  ctl "C5 invalid input refused and left untouched" 0
fi

# ============================================================================
h "RESULT"
echo "  checks   : $pass passed, $fail failed"
echo "  controls : $ctl_pass proved able to fail, $ctl_fail DECORATIVE"
echo "  scratch  : $WORK   (live ~/.claude was never opened)"
rc=0
[ "$fail" -ne 0 ] && rc=1
[ "$ctl_fail" -ne 0 ] && rc=1
[ "$rc" -eq 0 ] && echo "  R4/R5/R6: PASS" || echo "  R4/R5/R6: FAIL"
exit "$rc"
