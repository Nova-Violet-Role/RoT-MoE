#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# kernel-verdict-class.sh -- IS A NON-ANSWER TOLD APART FROM A REJECTION?
#
# WHY THIS EXISTS, stated plainly because the gap it fills was invisible.
#
# The prover hook turns the watchdog's status file into one of three verdicts:
#
#     KERNEL REJECTED          the kernel refused a proof -- stop everything
#     DID NOT FINISH           the check never completed -- not a pass, not a fail
#     (nothing)                clean
#
# The second state was added on 2026-08-08 after a timeout was reported as a
# rejection and "sent a session to repair proofs that were fine". The fix was
# written, commented at length, believed -- and NEVER ONCE FIRED.
#
# It tested the WHOLE reason string for equality against "TIMEOUT":
#     const UNFINISHED=["TIMEOUT","NOT_FOUND"];  UNFINISHED.indexOf(r) >= 0
# while the producer, ~/.claude/reminders/lean4-prover-reminder.ps1, writes
#     reason = "TIMEOUT after ${perModuleTimeoutSec}s"
#     reason = "LAUNCH_FAILED: $($_.Exception.Message)"
#     reason = "exit=$code $first"
# Uppercased, "TIMEOUT AFTER 90S" is not equal to "TIMEOUT". Every timeout kept
# the full rejection alarm -- the precise failure the comment claimed to have
# repaired.
#
# WHY NOTHING CAUGHT IT, which is the more useful lesson:
#
#   1. `--decide` receives the CSV ALREADY MARKED. Every existing test therefore
#      exercised the WORDING of the verdict, never the CLASSIFICATION producing
#      it. The broken half had no CLI and so no instrument -- hence --kernel.
#   2. cross-diff-remind.sh compares the two arms. BOTH were wrong in the same
#      way. A PARITY CHECK IS STRUCTURALLY BLIND TO A SHARED BUG: it can only
#      report that the arms agree, and they agreed on being wrong.
#
# Measured 2026-08-14: Proofs.RotVacuity and Proofs.RotRoute were reported
# KERNEL REJECTED while both re-verify at exit 0 with ZERO bytes, under memory
# pressure that made leanchecker emit std::bad_alloc and "failed to read file
# '<...>.olean.private'" -- a DIFFERENT mathlib file each attempt, which is how
# exhaustion is told from corruption.
#
# EXITS  0 pass | 1 a verdict was misclassified | 2 usage/tooling
# =============================================================================
set -u

pass=0; fail=0
ok ()  { pass=$((pass+1)); printf '  PASS  %s\n' "$1"; }
bad () { fail=$((fail+1)); printf '  FAIL  %s\n' "$1"; }
note() { printf '  ----  %s\n' "$1"; }

here="$(cd "$(dirname "$0")" && pwd)"
SH="$here/../hooks/prover-remind.sh"
PS1F="$here/../hooks/prover-remind.ps1"
[ -f "$SH" ] || { echo "missing $SH" >&2; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/rot-kvc.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# The fixture uses the PRODUCER'S REAL REASON SHAPES, verbatim. A fixture that
# invents tidy tokens like "TIMEOUT" would pass against the broken code and
# prove nothing -- that is exactly how the original defect hid.
# ---------------------------------------------------------------------------
mk_state () {  # <dir> <json>
  mkdir -p "$1"
  printf '%s' "$2" > "$1/lean-verify-status.json"
}

STATE="$TMP/state"
mk_state "$STATE" '{"red":[
 {"module":"Proofs.Timeout","reason":"TIMEOUT after 90s"},
 {"module":"Proofs.Oom","reason":"exit=1 libc++abi: terminating due to uncaught exception of type std::bad_alloc: std::bad_alloc"},
 {"module":"Proofs.Unreadable","reason":"exit=1 uncaught exception: failed to read file '\''X.olean.private'\''"},
 {"module":"Proofs.Launch","reason":"LAUNCH_FAILED: The system cannot find the file specified."},
 {"module":"Proofs.RealReject","reason":"exit=1 leanchecker found a problem in Proofs.RealReject"}
],"sorryFiles":[]}'

echo "== the classification, POSIX arm =="
sh_out="$(ROTMOE_STATE_DIR="$STATE" sh "$SH" --kernel 2>/dev/null)"
note "sh  --kernel -> $sh_out"

check_arm () {  # <label> <output>
  local L="$1" O="$2"
  case "$O" in
    *"Proofs.Timeout?"*)    ok  "$L: a TIMEOUT is a non-answer, not a rejection" ;;
    *) bad "$L: TIMEOUT was NOT demoted -- this is the 2026-08-08 defect, alive" ;;
  esac
  case "$O" in
    *"Proofs.Oom?"*)        ok  "$L: std::bad_alloc is host RAM, not a bad proof" ;;
    *) bad "$L: an out-of-memory failure was reported as a kernel rejection" ;;
  esac
  case "$O" in
    *"Proofs.Unreadable?"*) ok  "$L: a failed olean read is I/O, not a rejection" ;;
    *) bad "$L: a transient file-read failure was reported as a kernel rejection" ;;
  esac
  case "$O" in
    *"Proofs.Launch?"*)     ok  "$L: LAUNCH_FAILED means the checker never ran" ;;
    *) bad "$L: a checker that never started was reported as a rejection" ;;
  esac
  # THE OTHER DIRECTION, and the one that keeps this checker honest. Demoting
  # everything would pass all four rows above and destroy the alarm entirely.
  case "$O" in
    *"Proofs.RealReject?"*) bad "$L: A REAL REJECTION WAS DEMOTED -- the alarm is now deaf" ;;
    *"Proofs.RealReject"*)  ok  "$L: a genuine rejection still SHOUTS (not demoted)" ;;
    *) bad "$L: the real rejection vanished from the verdict entirely" ;;
  esac
}
check_arm "sh" "$sh_out"

# ---------------------------------------------------------------------------
# BOTH ARMS, and they must agree BYTE FOR BYTE. Parity alone cannot catch a
# shared bug -- that is why the assertions above run against each arm
# independently FIRST, and agreement is checked only afterwards.
# ---------------------------------------------------------------------------
if command -v pwsh >/dev/null 2>&1; then
  echo
  echo "== the classification, PowerShell arm =="
  ps_out="$(ROTMOE_STATE_DIR="$STATE" pwsh -NoProfile -File "$PS1F" -Kernel 2>/dev/null | tr -d '\r')"
  note "ps1 -Kernel -> $ps_out"
  check_arm "ps1" "$ps_out"
  if [ "$sh_out" = "$ps_out" ]; then
    ok "the two arms agree byte for byte"
  else
    bad "arms disagree: sh='$sh_out' ps1='$ps_out'"
  fi
else
  note "pwsh absent -- the ps1 arm was NOT measured here (this is not a pass for it)"
fi

# ---------------------------------------------------------------------------
# CONTROLS. An alarm nobody has tripped on purpose is an untested alarm.
# ---------------------------------------------------------------------------
echo
echo "== controls =="
EMPTY="$TMP/empty"; mkdir -p "$EMPTY"
e_out="$(ROTMOE_STATE_DIR="$EMPTY" sh "$SH" --kernel 2>/dev/null)"
case "$e_out" in
  "|") ok "CONTROL: no status file yields an empty verdict, not a fabricated one" ;;
  *)   bad "CONTROL: absent status file produced '$e_out', expected '|'" ;;
esac

# The exact pre-fix logic, run over the SAME fixture. If this does NOT
# misclassify, the fixture is too kind and every PASS above is worthless.
if command -v node >/dev/null 2>&1; then
  old="$(node -e '
    const fs=require("fs");
    const v=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
    const UNFINISHED=["TIMEOUT","NOT_FOUND"];
    process.stdout.write((v.red||[]).map(x=>{const m=x.module||x;
      const r=(x&&x.reason)?String(x.reason).toUpperCase():"";
      return UNFINISHED.indexOf(r)>=0?m+"?":m;}).join(","));
  ' "$STATE/lean-verify-status.json" 2>/dev/null)"
  case "$old" in
    *"Proofs.Timeout?"*) bad "CONTROL: the pre-fix logic PASSED the fixture -- the fixture cannot detect the bug" ;;
    *) ok "CONTROL: the pre-fix logic DOES misclassify this fixture (so the test has teeth)" ;;
  esac
else
  note "node absent -- the pre-fix control was not run"
fi

echo
echo "  $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then echo "  kernel-verdict-class: FAIL"; exit 1; fi
echo "  kernel-verdict-class: PASS"
exit 0
