#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# R21: THE DEBUG CHANNEL DOES WHAT lean/Proofs/RotDebugLog.lean SAYS IT MUST
#
# The Lean module proves three obligations. A theorem about a `World` structure
# constrains `hooks/rot-router.sh` through NOTHING unless a checker regenerates
# the condition, runs the REAL hook, and diffs the observable. That is this
# file, and every phase below executes the shipped hook rather than reading it.
#
#   silent_channel_is_ambiguous        ->  phase 2: a lost record must be marked
#   lost_evidence_is_always_marked     ->  phase 2, both arms
#   marker_is_not_always_set           ->  phase 1: no marker on a good write
#   rotate_keeps_the_newest            ->  phase 3: bounded, newest retained
#   rotate_below_cap_is_identity       ->  phase 3b: under cap, nothing dropped
#   taking_the_front_loses_the_newest  ->  phase 3: the newest line is asserted
#
# Phase 4 is the part that makes the rest worth anything: it PLANTS a hook with
# the marker removed and requires this checker to reject it. An alarm nobody has
# tripped on purpose is an untested alarm.
#
# Exit: 0 pass, 1 fail, 2 refuse.
# =============================================================================
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok  () { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad () { FAIL=$((FAIL+1)); [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=debug-channel::%s\n' "$*"; printf '  FAIL  %s\n' "$1"; }
inf () { printf '  ----  %s\n' "$1"; }

SH="$REPO/hooks/rot-router.sh"
PS="$REPO/hooks/rot-router.ps1"
[ -f "$SH" ] || { echo "REFUSE: $SH missing"; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dbgchan.XXXXXX")"
[ -d "$WORK" ] && [ -w "$WORK" ] || { echo "REFUSE: scratch dir unusable"; exit 2; }
cleanup () { rm -rf "$WORK"; }
trap cleanup EXIT

PAYLOAD='{"prompt":"lake build the theorem"}'
MARKER='debug-log UNWRITABLE'

echo "== R21: the router's debug channel, against RotDebugLog.lean =="

# --- which arms can actually be exercised here -------------------------------
HAVE_PS=0
if command -v pwsh >/dev/null 2>&1 && [ -f "$PS" ]; then HAVE_PS=1; fi

# Runs one arm. $1 = arm name, $2 = log path, $3.. = env assignments handled by
# the caller through the environment. Prints stdout, stderr goes to $WORK/err.
run_arm () {
  _arm="$1"; shift
  if [ "$_arm" = "sh" ]; then
    printf '%s' "$PAYLOAD" | bash "$SH" 2>"$WORK/err.$_arm"
  else
    printf '%s' "$PAYLOAD" | pwsh -NoProfile -File "$PS" 2>"$WORK/err.$_arm"
  fi
}

# --- phase 1: a writable log receives records, and NO marker appears ---------
for arm in sh ps1; do
  [ "$arm" = "ps1" ] && [ "$HAVE_PS" -eq 0 ] && continue
  LOG="$WORK/ok.$arm.jsonl"
  out="$(ROTMOE_DEBUG_LOG="$LOG" run_arm "$arm")"
  if [ -s "$LOG" ]; then
    n=$(grep -c '"kind":"route"' "$LOG" 2>/dev/null || echo 0)
    if [ "$n" -ge 1 ]; then ok "$arm: a writable log receives the route record ($n)"
    else bad "$arm: log written but no route record in it"; fi
  else
    bad "$arm: writable log received NOTHING -- the channel is dead"
  fi
  case "$out" in
    *"$MARKER"*) bad "$arm: marker present on a SUCCESSFUL write (marker_is_not_always_set)" ;;
    *)           ok  "$arm: no marker on a good write -- the bit can stay false" ;;
  esac
done

# --- phase 2: an unwritable log is MARKED, and stays out of the transcript ---
# This is the theorem that matters: without it, zero records means either
# "never fired" or "evidence lost", and nobody can tell which.
for arm in sh ps1; do
  [ "$arm" = "ps1" ] && [ "$HAVE_PS" -eq 0 ] && continue
  LOG="$WORK/nodir.$arm/r.jsonl"     # parent does not exist -> unwritable
  out="$(ROTMOE_DEBUG_LOG="$LOG" run_arm "$arm")"
  case "$out" in
    *"$MARKER"*) ok "$arm: a lost record is MARKED (lost_evidence_is_always_marked)" ;;
    *)           bad "$arm: record lost SILENTLY -- indistinguishable from 'never fired'" ;;
  esac
  # A hook must not spray a fatal into a user's session over a debug file.
  errb=$(wc -c < "$WORK/err.$arm" 2>/dev/null || echo 0)
  if [ "$errb" -eq 0 ]; then ok "$arm: nothing leaked to stderr on the failure path"
  else bad "$arm: $errb bytes leaked to stderr: $(head -c 120 "$WORK/err.$arm")"; fi
  # And routing itself must survive: the gauge is not allowed to degrade
  # because a debug file was missing. This regressed once -- R/s+ printed n/a.
  case "$out" in
    *"R/s+ n/a"*) bad "$arm: R/s+ degraded to n/a when the debug log was unwritable" ;;
    *"R/s+ "*)    ok  "$arm: R/s+ still computed with the debug log unwritable" ;;
    *)            bad "$arm: no R/s+ in the output at all" ;;
  esac
done

# --- phase 3: the file is BOUNDED and keeps the NEWEST records ---------------
CAP=5
ROUNDS=12
for arm in sh ps1; do
  [ "$arm" = "ps1" ] && [ "$HAVE_PS" -eq 0 ] && continue
  LOG="$WORK/rot.$arm.jsonl"
  i=1
  while [ "$i" -le "$ROUNDS" ]; do
    if [ "$arm" = "sh" ]; then
      printf '{"prompt":"lake build %d"}' "$i" | \
        ROTMOE_DEBUG_LOG="$LOG" ROTMOE_DEBUG_LOG_MAX="$CAP" bash "$SH" >/dev/null 2>&1
    else
      printf '{"prompt":"lake build %d"}' "$i" | \
        ROTMOE_DEBUG_LOG="$LOG" ROTMOE_DEBUG_LOG_MAX="$CAP" pwsh -NoProfile -File "$PS" >/dev/null 2>&1
    fi
    i=$((i+1))
  done
  lines=$(wc -l < "$LOG" 2>/dev/null || echo 0)
  if [ "$lines" -le "$CAP" ]; then ok "$arm: log bounded at $lines <= cap $CAP after $ROUNDS turns"
  else bad "$arm: log grew to $lines lines with cap $CAP -- unbounded"; fi
  # rotate_keeps_the_newest: the LAST prompt was 'lake build 12', 13 chars.
  # NOT `tail | grep -q`: under `set -o pipefail`, grep -q exits on the first
  # match and closes the pipe, tail takes SIGPIPE, and the pipeline reports 141
  # -- so a MATCH would be read as a failure. workflow-lint caught this here.
  _last="$(tail -1 "$LOG" 2>/dev/null || true)"
  if case "$_last" in *'"chars":13'*) true ;; *) false ;; esac; then
    ok "$arm: the NEWEST record survived rotation (rotate_keeps_the_newest)"
  else
    bad "$arm: newest record lost -- rotation kept the front, refuted by taking_the_front_loses_the_newest"
  fi
done

# --- phase 3b: under the cap, nothing is discarded ---------------------------
LOG="$WORK/under.jsonl"
i=1
while [ "$i" -le 3 ]; do
  printf '{"prompt":"lake build %d"}' "$i" | \
    ROTMOE_DEBUG_LOG="$LOG" ROTMOE_DEBUG_LOG_MAX=50 bash "$SH" >/dev/null 2>&1
  i=$((i+1))
done
routes=$(grep -c '"kind":"route"' "$LOG" 2>/dev/null || echo 0)
if [ "$routes" -eq 3 ]; then ok "sh: under the cap nothing is discarded (rotate_below_cap_is_identity)"
else bad "sh: expected 3 route records under the cap, found $routes"; fi

# --- phase 4: THE NEGATIVE CONTROL -------------------------------------------
# Plant a hook whose marker has been deleted and require phase 2's logic to
# reject it. Without this the whole file could be passing vacuously.
#
# A PRIORI needle discipline, required by checker/mutant-discipline.sh and
# proved necessary by RotMutant.killed_implies_all_three: a planted mutant is
# evidence ONLY if the patch landed. Counting the needle BEFORE editing is the
# stronger of the two accepted forms -- a patch that cannot apply is refused up
# front, so "changed" holds by construction rather than being checked after.
# A control that silently failed to plant would report SURVIVED, which reads as
# robustness and means nothing was tested.
needle_count () { grep -c -- "$1" "$2" 2>/dev/null || echo 0; }

NEEDLE1=' | debug-log UNWRITABLE (record lost)'
n1=$(needle_count "$NEEDLE1" "$SH")
if [ "$n1" -ne 1 ]; then
  bad "control: needle occurs $n1 time(s) in rot-router.sh, expected 1 -- the plant cannot be trusted, so this is DISCARDED and NOT a pass"
  n1=0
fi

PLANT="$WORK/rot-router-nomarker.sh"
[ "$n1" -eq 1 ] && sed 's/ | debug-log UNWRITABLE (record lost)//' "$SH" > "$PLANT"
if [ "$n1" -ne 1 ]; then
  :
elif grep -q 'debug-log UNWRITABLE' "$PLANT"; then
  bad "control: the marker was NOT removed from the planted copy -- control proves nothing"
else
  out="$(printf '%s' "$PAYLOAD" | ROTMOE_DEBUG_LOG="$WORK/nodir2/r.jsonl" bash "$PLANT" 2>/dev/null)"
  case "$out" in
    *"$MARKER"*) bad "control: the planted hook still printed a marker -- impossible, check the plant" ;;
    *)           ok  "control: a hook without the marker IS rejected by phase 2's test" ;;
  esac
fi

# Second control: a hook with rotation disabled must fail the bound check.
NEEDLE2='_cap="${ROTMOE_DEBUG_LOG_MAX:-5000}"'
n2=$(needle_count "$NEEDLE2" "$SH")
if [ "$n2" -ne 1 ]; then
  bad "control: rotation needle occurs $n2 time(s), expected 1 -- DISCARDED, never counted as a pass"
fi
PLANT2="$WORK/rot-router-nocap.sh"
[ "$n2" -eq 1 ] && sed 's/_cap="${ROTMOE_DEBUG_LOG_MAX:-5000}"/_cap=0/' "$SH" > "$PLANT2"
if [ "$n2" -eq 1 ] && grep -q '_cap=0' "$PLANT2"; then
  LOG2="$WORK/nocap.jsonl"
  i=1
  while [ "$i" -le 8 ]; do
    printf '{"prompt":"lake build %d"}' "$i" | \
      ROTMOE_DEBUG_LOG="$LOG2" ROTMOE_DEBUG_LOG_MAX=2 bash "$PLANT2" >/dev/null 2>&1
    i=$((i+1))
  done
  l2=$(wc -l < "$LOG2" 2>/dev/null || echo 0)
  if [ "$l2" -gt 2 ]; then ok "control: with rotation disabled the log DOES grow past the cap ($l2 > 2)"
  else bad "control: rotation-disabled hook stayed bounded ($l2) -- the bound check cannot fail, so it proves nothing"; fi
else
  bad "control: could not plant the rotation-disabled copy"
fi

[ "$HAVE_PS" -eq 1 ] || inf "pwsh absent: the ps1 arm was NOT exercised here -- that is a SKIP, never a pass"

echo
echo "== debug-channel: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
