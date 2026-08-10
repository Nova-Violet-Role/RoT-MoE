#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE DEBUG LOG -- is it still readable, and does the writer still protect it?
#
# The CLEAR CONDITION named the debug channel as unchecked, and it was right:
# 409 of 5000 lines in the live log were unparseable (8.2%), 27 of them
# carrying two `"kind"` keys. Every statistic ever drawn from that file was
# quietly short by that much, and nothing in the repo could have noticed.
#
# ROOT CAUSE, reproduced deterministically (L3 below re-runs it every time):
# a writer killed mid-record leaves a line with NO trailing newline. The next
# append lands ON those bytes and fuses two records into one unreadable line.
# The 1200 ms hook budget did this routinely before it was raised.
#
# THE METRIC IS THE POINT. This gate counts RECOVERED RECORDS, never corrupt
# lines. `RotLogAtomicity.corrupt_line_count_cannot_tell_them_apart` proves the
# two writers produce the SAME number of corrupt lines -- so a line-counting
# gate scores the repair as worthless and would have passed the broken writer
# forever. Measured, not argued:
#
#     naive append   -> 2 lines, 1 recovered, 1 corrupt
#     repaired writer-> 3 lines, 2 recovered, 1 corrupt      <- +1 record
#
# L3 asserts BOTH halves of that table, including the corrupt-line tie. If a
# future edit makes the corrupt counts differ, the tie assertion fails and
# somebody has to re-read the theorem before changing the metric.
#
#   L1  the sh writer still terminates a partial line before appending
#   L2  the ps1 writer does too -- it was the LARGER contributor (61%)
#   L3  differential self-test: naive loses the record, the router keeps it
#   L4  the line-count blindness control -- the two are indistinguishable by
#       corrupt lines, which is why L3 measures records
#   L5  the live router emits only parseable records, over a real run
#   L6  every log on disk is audited; the RECENT window must be clean
#   L7  rotation leaves the file newline-terminated, so the next append is safe
#
# Every check below can fail. That is the only reason a pass counts.
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

passed=0; failed=0
ok()   { echo "  PASS  $1"; passed=$((passed+1)); }
bad()  { echo "  FAIL  $1"; failed=$((failed+1)); }
note() { echo "  ....  $1"; }

SH="hooks/rot-router.sh"
PS="hooks/rot-router.ps1"
SCAN="checker/log-scan.js"
TMP="${TMPDIR:-/tmp}/rot-logint.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

echo "== debug-log integrity gate"

# ---- L1 the sh writer terminates a partial line ----------------------------
# Presence of the helper is not enough -- it has to be CALLED, and called on
# the path that reaches every append. Both sinks are checked by name.
if [ ! -f "$SH" ]; then
  bad "$SH is missing"
else
  # Both spellings: the house style is `name () {` (see _rot_scrub) but `name()`
  # is equally valid sh. A pattern that admits only one of them fails on a
  # cosmetic edit and teaches the next reader to distrust the gate.
  if grep -qE '^_rot_terminate ?\(\)' "$SH"; then
    ok "sh: the partial-line guard is defined"
  else
    bad "sh: _rot_terminate is GONE -- the fusion defect is back"
  fi
  _calls=$(grep -c '_rot_terminate "' "$SH")
  if [ "$_calls" -ge 2 ]; then
    ok "sh: guard invoked on both sinks ($_calls call sites)"
  else
    bad "sh: guard invoked $_calls time(s), expected >= 2 (local sink + central sink)"
  fi
  if grep -q 'RotLogAtomicity' "$SH"; then
    ok "sh: the guard cites the theorem it implements"
  else
    bad "sh: guard no longer cites RotLogAtomicity -- the binding to the proof is lost"
  fi
fi

# ---- L2 the ps1 writer does too --------------------------------------------
# This arm produced 248 of the 409 corrupt lines (61%), identified by the
# fractional-second `ts` only it writes. Leaving it unguarded would have left
# the majority of the defect in place while the repo claimed a repair.
if [ ! -f "$PS" ]; then
  bad "$PS is missing"
else
  if grep -q 'function Complete-RotPartialLine' "$PS"; then
    ok "ps1: the partial-line guard is defined"
  else
    bad "ps1: Complete-RotPartialLine is GONE -- 61% of the defect is unguarded"
  fi
  _pcalls=$(grep -c 'Complete-RotPartialLine \$' "$PS")
  if [ "$_pcalls" -ge 2 ]; then
    ok "ps1: guard invoked on both sinks ($_pcalls call sites)"
  else
    bad "ps1: guard invoked $_pcalls time(s), expected >= 2"
  fi
fi

# ---- L2b the ps1 arm, BEHAVIOURALLY ----------------------------------------
# Grepping for the call is a structural check; it cannot tell whether the guard
# actually closes the line. This arm wrote 61% of the corruption, so it earns a
# real run. The interpreter is environment-dependent -- on a Linux CI runner
# there may be neither `powershell` nor `pwsh`. In that case this is reported
# as NOT RUN and counted as neither pass nor fail: claiming a pass for a check
# that never executed is precisely the fake green the CLEAR CONDITION forbids,
# and claiming a failure would make the gate unrunnable off Windows. The
# structural checks in L2 still apply everywhere.
PSEXE=""
for cand in powershell pwsh; do
  command -v "$cand" >/dev/null 2>&1 && { PSEXE="$cand"; break; }
done
if [ -z "$PSEXE" ]; then
  note "ps1 behavioural check NOT RUN -- no powershell/pwsh on PATH (L2 structural checks still applied)"
else
  PFIX="$TMP/ps1.jsonl"
  printf '{"kind":"a","n":1}\n' > "$PFIX"
  printf '{"kind":"b","n":2'    >> "$PFIX"
  printf '{"hook_event_name":"UserPromptSubmit","prompt":"prove a theorem in lean","session_id":"logintegrity"}' > "$TMP/ps1in.json"
  ROTMOE_DEBUG_LOG="$PFIX" ROTMOE_DEBUG_LOCAL=0 ROTMOE_DEBUG_SRC=test \
    "$PSEXE" -NoProfile -File "$(pwd)/$PS" < "$TMP/ps1in.json" >/dev/null 2>&1
  _prc=$?
  read -r _pl _prec _pbad <<EOF
$(node "$SCAN" "$PFIX")
EOF
  note "ps1 ($PSEXE): lines=$_pl recovered=$_prec corrupt=$_pbad exit=$_prc"
  if [ "$_prc" -ne 0 ]; then
    bad "ps1 arm exited $_prc on a truncated log -- it must never fail a turn"
  else
    ok "ps1 arm survives a truncated log (exit 0)"
  fi
  # Same expectation as the sh arm: the pre-existing record plus everything
  # this turn wrote. The two arms MUST agree -- the field order is shared so
  # that one reader can treat both logs as a single stream.
  if [ "$_prec" -ge 2 ]; then
    ok "ps1 arm recovered $_prec records past the fragment -- the guard closed the line"
  else
    bad "ps1 arm recovered $_prec -- the fragment swallowed its record, guard not working"
  fi
fi

# ---- the fixture both L3 and L4 read ---------------------------------------
# One complete record, then a record whose writer died mid-flight. This is the
# exact live shape: `{"kind":"gauge",...,"mu":1.05{"kind":"route","n":3}`.
FIX="$TMP/fixture.jsonl"
printf '{"kind":"a","n":1}\n' > "$FIX"
printf '{"kind":"b","n":2'    >> "$FIX"

NAIVE="$TMP/naive.jsonl"; cp "$FIX" "$NAIVE"
printf '%s\n' '{"kind":"c","n":3}' >> "$NAIVE"          # what the old writer did

# CALIBRATION -- how many records does one turn write? This is MEASURED, never
# assumed, and the reason is a false green this gate caught in its own first
# run: the expectation was hard-coded to 2, the router writes TWO records per
# turn, and the SECOND one landed on a fresh line by accident. The broken
# writer passed while the first record was still being destroyed. An expected
# value derived from the implementation's real shape cannot be satisfied that
# way -- with N records per turn, only a working guard reaches 1 + N.
CAL="$TMP/cal.jsonl"; : > "$CAL"
printf '{"hook_event_name":"UserPromptSubmit","prompt":"prove a theorem in lean","session_id":"logintegrity"}' \
  | ROTMOE_DEBUG_LOG="$CAL" ROTMOE_DEBUG_LOCAL=0 ROTMOE_DEBUG_SRC=test sh "$SH" >/dev/null 2>&1
read -r _cl _crec _cbad <<EOF
$(node "$SCAN" "$CAL")
EOF
if [ "$_crec" -ge 1 ] && [ "$_cbad" = "0" ]; then
  ok "calibration: one turn writes $_crec record(s), 0 corrupt"
else
  bad "calibration: one turn wrote $_crec record(s) with $_cbad corrupt -- cannot calibrate"
fi
_expect=$((1 + _crec))

ROUTED="$TMP/routed.jsonl"; cp "$FIX" "$ROUTED"
printf '{"hook_event_name":"UserPromptSubmit","prompt":"prove a theorem in lean","session_id":"logintegrity"}' \
  | ROTMOE_DEBUG_LOG="$ROUTED" ROTMOE_DEBUG_LOCAL=0 ROTMOE_DEBUG_SRC=test sh "$SH" >/dev/null 2>&1
_rrc=$?

if [ "$_rrc" -ne 0 ]; then
  bad "router exited $_rrc on the truncated fixture -- it must never fail a turn"
else
  ok "router survives a truncated log (exit 0)"
fi

read -r _nl _nrec _nbad <<EOF
$(node "$SCAN" "$NAIVE")
EOF
read -r _rl _rrec _rbad <<EOF
$(node "$SCAN" "$ROUTED")
EOF

# ---- L3 the differential -- RECORDS, not lines -----------------------------
note "naive:    lines=$_nl recovered=$_nrec corrupt=$_nbad"
note "repaired: lines=$_rl recovered=$_rrec corrupt=$_rbad"

if [ "$_nrec" = "1" ]; then
  ok "naive append recovers 1 record -- the fusion destroyed BOTH (naive_loses_the_next_record)"
else
  bad "naive append recovered $_nrec, expected 1 -- the control no longer reproduces the defect"
fi

if [ "$_rrec" = "$_expect" ]; then
  ok "repaired writer recovers $_rrec = 1 + $_crec -- every record of the turn survived (safe_keeps_the_next_record)"
else
  bad "repaired writer recovered $_rrec, expected $_expect (1 pre-existing + $_crec this turn) -- THE GUARD IS NOT WORKING"
fi

if [ "$_rrec" -gt "$_nrec" ]; then
  ok "the repair is load-bearing: +$((_rrec - _nrec)) record over the naive writer"
else
  bad "repaired writer is no better than naive ($_rrec vs $_nrec) -- the fix does nothing"
fi

# ---- L4 the line-count blindness control -----------------------------------
# This is the check that keeps the METRIC honest rather than the writer. If
# these two ever differ, `corrupt_line_count_cannot_tell_them_apart` has been
# falsified by an implementation change and the gate's design must be revisited
# before anyone "simplifies" L3 into a corrupt-line count.
if [ "$_nbad" = "$_rbad" ]; then
  ok "corrupt-line counts are IDENTICAL ($_nbad = $_rbad) -- a line-counting gate would see no repair at all"
else
  bad "corrupt-line counts differ ($_nbad vs $_rbad) -- re-read corrupt_line_count_cannot_tell_them_apart"
fi

# ---- L5 the live router emits only parseable records -----------------------
# A fresh log, several real payloads, every line must parse. This is the check
# that catches a record whose own JSON is malformed -- a different failure from
# fusion, and one the fixture cannot expose.
FRESH="$TMP/fresh.jsonl"; : > "$FRESH"
_runs=0
for p in "debug this error" "plan the roadmap" "prove it in lean 4" "compress this" "how do i feel about it"; do
  printf '{"hook_event_name":"UserPromptSubmit","prompt":"%s","session_id":"logintegrity"}' "$p" \
    | ROTMOE_DEBUG_LOG="$FRESH" ROTMOE_DEBUG_LOCAL=0 ROTMOE_DEBUG_SRC=test sh "$SH" >/dev/null 2>&1
  _runs=$((_runs+1))
done
read -r _fl _frec _fbad <<EOF
$(node "$SCAN" "$FRESH")
EOF
if [ "$_fbad" = "0" ] && [ "$_frec" -ge "$_runs" ]; then
  ok "$_runs live turns wrote $_frec records, 0 unparseable"
else
  bad "$_runs live turns wrote $_frec records with $_fbad unparseable -- the writer emits bad JSON"
fi

# ---- L6 audit every log on disk, recent window must be clean ---------------
# The corpus is DISCOVERED, never listed: a hard-coded path stops covering
# whatever is added later. The generated log above is always in it, so the
# corpus is never empty and this check can never pass by having nothing to do.
#
# The window matters. The whole-file rate is HISTORY -- it includes records
# written by the old writer and cannot be repaired retroactively, only rotated
# out. The recent window is the CURRENT writer's behaviour, and that is the
# invariant worth gating on.
WINDOW=200
LOGS="$FRESH"
for cand in "${ROTMOE_DEBUG_LOG:-}" "$HOME/.claude/rot-moe/rot-route-debug.jsonl"; do
  [ -n "$cand" ] && [ -f "$cand" ] && LOGS="$LOGS $cand"
done
for cand in .rot-moe/rot-route-*.jsonl; do
  [ -f "$cand" ] && LOGS="$LOGS $cand"
done

_audited=0
for lg in $LOGS; do
  _audited=$((_audited+1))
  read -r _wl _wrec _wbad <<EOF
$(node "$SCAN" "$lg" "$WINDOW")
EOF
  read -r _al _arec _abad <<EOF
$(node "$SCAN" "$lg")
EOF
  _name=$(basename "$lg")
  if [ "$_al" -gt 0 ]; then
    _pct=$(( _abad * 1000 / _al ))
  else
    _pct=0
  fi
  note "$_name: whole=$_al lines, $_arec recovered, $_abad corrupt (${_pct}/1000) | last $WINDOW: $_wbad corrupt"
  if [ "$_wbad" = "0" ]; then
    ok "$_name: the recent window is clean -- the current writer is not corrupting"
  else
    bad "$_name: $_wbad corrupt lines in the last $WINDOW -- the writer is STILL fusing records"
  fi
done
if [ "$_audited" -gt 0 ]; then
  ok "$_audited log(s) audited -- the corpus was discovered, not assumed"
else
  bad "no logs audited at all -- this gate cannot pass by having nothing to check"
fi

# ---- L7 rotation leaves the file newline-terminated ------------------------
# Rotation is `tail -n <cap> > tmp; mv -f tmp log`. If the last line is a
# fragment, `tail` PRESERVES it and `mv` makes it permanent -- that is how the
# splice survived rotation in the live file. The guard runs before the next
# append, so what matters here is that rotation itself never leaves a file the
# guard would have to rescue twice in a row.
ROT="$TMP/rot.jsonl"
i=0; : > "$ROT"
while [ "$i" -lt 12 ]; do printf '{"kind":"r","n":%d}\n' "$i" >> "$ROT"; i=$((i+1)); done
printf '{"kind":"r","n":12'  >> "$ROT"     # dangling fragment at the tail
printf '{"hook_event_name":"UserPromptSubmit","prompt":"rotate me","session_id":"logintegrity"}' \
  | ROTMOE_DEBUG_LOG="$ROT" ROTMOE_DEBUG_LOCAL=0 ROTMOE_DEBUG_SRC=test ROTMOE_DEBUG_LOG_MAX=5 sh "$SH" >/dev/null 2>&1
if [ -n "$(tail -c 1 "$ROT" 2>/dev/null)" ]; then
  bad "after rotation the file does NOT end in a newline -- the next append will fuse"
else
  ok "after rotation the file ends in a newline -- the next append lands on a fresh line"
fi
read -r _tl _trec _tbad <<EOF
$(node "$SCAN" "$ROT")
EOF
if [ "$_trec" -ge 1 ]; then
  ok "rotation kept $_trec readable records under a cap of 5"
else
  bad "rotation left $_trec readable records -- it destroyed the file"
fi

echo
echo "== log-integrity: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
