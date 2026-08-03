#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# verdict-fresh.sh -- is the verdict committed in STATUS.md TRUE of this tree?
#
# WHY THIS FILE EXISTS, and it is not tidiness.
#
# The comparison used to live inside checker/verdict-schedule-sim.sh, which is
# gated behind gate-all's FULL set. CI runs FULL; a developer running the plain
# `gate-all.sh` does not. So the tree could report "ALL 26 GATES GREEN" while
# carrying a verdict claiming 154 theorems against 162 in the sources -- and it
# DID, on 2026-08-03: three CI legs (ubuntu, macos, windows) failed at the same
# step immediately after a push whose local sweep was green.
#
# That is worse than a missing check. A green local sweep that CI contradicts
# teaches you to distrust the local sweep, and the only cure a tired person
# reaches for is to stop running it.
#
# The rule this file enforces: EVERY CHECK CI CAN FAIL, THE DEFAULT LOCAL SWEEP
# MUST BE ABLE TO FAIL TOO. The 3-week schedule simulation is genuinely slow and
# belongs in FULL; this comparison takes under a second and belongs in the
# default set. Splitting them is what makes both affordable.
#
# verdict-schedule-sim.sh DELEGATES here rather than keeping a second copy. A
# duplicated check drifts, and this repo has already been bitten by exactly that
# (a duplicated weight table whose copy was the one being validated).
#
# Exit: 0 fresh, 1 stale or vacuous. Never 3 -- there is nothing to skip.
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
PASS=0; FAIL=0
ok  () { PASS=$((PASS+1)); echo "  PASS  $*"; }
bad () { FAIL=$((FAIL+1)); echo "  FAIL  $*"; }

echo "== is the COMMITTED verdict current? =="

_fresh=$(bash "$REPO/checker/status-verdict.sh" 2>/dev/null)
_committed=$(awk '/<!-- VERDICT-BEGIN -->/{f=1;next} /<!-- VERDICT-END -->/{f=0} f' "$REPO/STATUS.md")

# ANTI-VACUITY FIRST. The marker names were WRONG in an earlier attempt at this
# comparison: both sides came back empty and "IDENTICAL: true" was printed over
# two empty strings. Two blanks compare equal forever. Demand real content
# before believing either side.
if [ "${#_fresh}" -lt 40 ]; then
  bad "the generator produced ${#_fresh} bytes -- too little to be a verdict, so this comparison would be vacuous"
elif [ "${#_committed}" -lt 40 ]; then
  bad "the committed block is ${#_committed} bytes -- the markers did not match, NOT a passing comparison"
else
  ok "both sides carry a real verdict (${#_fresh} fresh / ${#_committed} committed bytes)"
  if [ "$(printf '%s' "$_fresh" | tr -d '[:space:]')" = "$(printf '%s' "$_committed" | tr -d '[:space:]')" ]; then
    ok "the committed verdict MATCHES what this tree measures"
  else
    bad "STALE VERDICT: STATUS.md disagrees with this tree. Regenerate it before pushing:"
    diff <(printf '%s\n' "$_committed") <(printf '%s\n' "$_fresh") | head -8 | sed 's/^/        /'
  fi
fi

# CONTROL: the comparison must be able to SEE a difference, or its green means
# nothing. Perturb the committed text IN MEMORY -- never on disk; a checker that
# edits the tree it is judging is a hazard.
_perturbed=$(printf '%s' "$_committed" | sed 's/| modules | \([0-9]*\) |/| modules | 999 |/')
if [ "$_perturbed" = "$_committed" ]; then
  bad "CONTROL INCONCLUSIVE: could not perturb the committed verdict, so its sensitivity is unproven"
elif [ "$(printf '%s' "$_fresh" | tr -d '[:space:]')" = "$(printf '%s' "$_perturbed" | tr -d '[:space:]')" ]; then
  bad "CONTROL DEAD: a verdict claiming 999 modules still compared equal"
else
  ok "CONTROL: a wrong module count in the committed verdict WOULD be detected"
fi

printf '\n== verdict freshness: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
