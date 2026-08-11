#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# CORPUS VERIFIER -- bench/corpus-40.jsonl
#
# The P2.4 preregistration (bench/P24-PREREGISTRATION.md section 4) fixes the
# task set BEFORE either arm runs, and requires every task to have a
# machine-checkable ground truth with a naive answer that is specifically wrong.
# This script is what makes "machine-checkable" true rather than asserted.
#
# It checks two properties of every task, and BOTH can fail:
#
#   DISCRIMINATION  the truth command and the naive command must produce
#                   DIFFERENT answers. A task where the naive answer happens to
#                   be right cannot separate the two arms -- it is a free point
#                   for both and it dilutes the sign test. Proved inadmissible
#                   in lean/Proofs/RotTaskCorpus.lean.
#
#   LANE BINDING    the prompt must route to the lane the task declares, as
#                   measured by the SHIPPED router (hooks/rot-router.sh --route).
#                   Without this the `lane` field is decoration; with it the
#                   corpus is a routing measurement as well as an answer one.
#
# The lane check is why this file exists rather than a `wc -l`. Writing it found
# nine tasks routing to FORGE instead of their declared lane because the
# directory name `Proofs/` begins with the FORGE stem `proof`, and eleven more
# because `ship`, `shipping` and `install` are FORGE stems too. Those were
# defects in the corpus, invisible to any check that only counted lines.
#
# EXIT 0 pass  1 a real failure  2 harness fault. Never 0 on a partial run.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

CORPUS="bench/corpus-40.jsonl"
EXPECT_TASKS=40
EXPECT_FAMILIES=4
EXPECT_PER_FAMILY=10
ROUTER="hooks/rot-router.sh"

pass=0; fail=0
ok  () { echo "  ok    $*"; pass=$((pass+1)); }
bad () { echo "  FAIL  $*"; fail=$((fail+1)); }
inf () { echo "  ----  $*"; }

[ -f "$CORPUS" ] || { echo "corpus-verify: $CORPUS not found."; exit 2; }
[ -f "$ROUTER" ] || { echo "corpus-verify: $ROUTER not found -- cannot measure routing."; exit 2; }
command -v node >/dev/null 2>&1 || { echo "corpus-verify: node not on PATH."; exit 2; }

# --- run a command and CAPTURE ITS OUTPUT REGARDLESS OF EXIT STATUS ----------
# `grep -c` exits 1 when the count is ZERO. The first cut of this harness ran
# the commands through a wrapper that threw on a non-zero status, so seven tasks
# with a legitimate answer of 0 were reported as errors. A count of zero is a
# measurement; only a missing file is a fault. This is the same distinction
# count-theorems.sh draws between "no input" and "measured zero".
runcmd () { eval "$1" 2>/dev/null; return 0; }

# -----------------------------------------------------------------------------
# STRUCTURE
# -----------------------------------------------------------------------------
_n=$(grep -c '^{' "$CORPUS")
if [ "$_n" -eq "$EXPECT_TASKS" ]; then ok "$EXPECT_TASKS tasks"; else bad "$_n tasks, expected $EXPECT_TASKS"; fi

_ids=$(node -e 'const fs=require("fs");const L=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").map(JSON.parse);console.log(new Set(L.map(t=>t.id)).size)' "$CORPUS")
if [ "$_ids" -eq "$EXPECT_TASKS" ]; then ok "all $EXPECT_TASKS ids distinct"; else bad "only $_ids distinct ids -- a repeated id silently halves a family"; fi

_fam=$(node -e 'const fs=require("fs");const L=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").map(JSON.parse);const m={};L.forEach(t=>m[t.family]=(m[t.family]||0)+1);console.log(Object.keys(m).length+" "+Object.values(m).join(","))' "$CORPUS")
set -- $_fam
if [ "$1" -eq "$EXPECT_FAMILIES" ]; then ok "$EXPECT_FAMILIES seed families"; else bad "$1 families, expected $EXPECT_FAMILIES"; fi
_bal=1
for _c in $(printf '%s' "$2" | tr ',' ' '); do [ "$_c" -eq "$EXPECT_PER_FAMILY" ] || _bal=0; done
if [ "$_bal" -eq 1 ]; then ok "balanced: $EXPECT_PER_FAMILY per family ($2)"; else bad "unbalanced families: $2 -- section 4 fixes 10 per family"; fi

# -----------------------------------------------------------------------------
# DISCRIMINATION + LANE BINDING, per task
# -----------------------------------------------------------------------------
_nodisc=""; _nolane=""
while IFS= read -r _line; do
  [ -z "$_line" ] && continue
  _id=$(printf '%s' "$_line"   | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).id))')
  _tc=$(printf '%s' "$_line"   | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).truth_cmd))')
  _nc=$(printf '%s' "$_line"   | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).naive_cmd))')
  _pr=$(printf '%s' "$_line"   | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).prompt))')
  _ln=$(printf '%s' "$_line"   | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).lane))')

  _t=$(runcmd "$_tc"); _v=$(runcmd "$_nc")
  [ "$_t" = "$_v" ] && _nodisc="$_nodisc $_id(=$_t)"

  _routed=$(bash "$ROUTER" --route "$_pr" 2>/dev/null | head -1 | cut -d'|' -f1 | cut -d' ' -f1)
  [ "$_routed" = "$_ln" ] || _nolane="$_nolane $_id($_routed!=$_ln)"
done < "$CORPUS"

if [ -z "$_nodisc" ]; then
  ok "every task DISCRIMINATES -- naive answer differs from the truth on all $EXPECT_TASKS"
else
  bad "these tasks do not discriminate (naive == truth):$_nodisc"
  echo "        A task the naive command gets RIGHT is a free point for both arms."
fi

if [ -z "$_nolane" ]; then
  ok "every prompt routes to its declared lane, measured by the shipped router"
else
  bad "lane mismatches:$_nolane"
  echo "        The lane field is a CLAIM about the shipped router. Reword the"
  echo "        prompt or correct the field -- do not delete the check."
fi

# -----------------------------------------------------------------------------
# LANE COVERAGE -- all ten, including the CONVERGENT fallback
# -----------------------------------------------------------------------------
# The existing bench key covers 9 of the router's 10 lanes; CONVERGENT, the
# fallback that fires when NO stem matches, was never exercised. A corpus that
# skips it cannot see a regression in the branch every unmatched prompt takes.
_lanes=$(node -e 'const fs=require("fs");const L=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").map(JSON.parse);console.log([...new Set(L.map(t=>t.lane))].sort().join(" "))' "$CORPUS")
_lanecount=$(printf '%s' "$_lanes" | wc -w)
_declared=$(grep -cE '^\s+(elif|if)\s+fired ' "$ROUTER")
_declared=$((_declared + 1))   # + the else branch: CONVERGENT
if [ "$_lanecount" -eq "$_declared" ]; then
  ok "all $_declared router lanes covered: $_lanes"
else
  bad "corpus covers $_lanecount lanes, router declares $_declared"
  echo "        covered: $_lanes"
fi

# -----------------------------------------------------------------------------
# CONTROLS -- an instrument that has never been seen to fail proves nothing
# -----------------------------------------------------------------------------
CTRL=0

# (a) the discrimination test must FIRE on a task whose naive answer is right.
_a=$(runcmd "echo 7"); _b=$(runcmd "echo 7")
if [ "$_a" = "$_b" ]; then
  inf "control: the discrimination comparison DOES see two equal answers"
else
  echo "  CONTROL FAILED: two identical commands compared unequal."; CTRL=1
fi

# (b) ... and must NOT fire on a task that genuinely discriminates.
_a=$(runcmd "echo 7"); _b=$(runcmd "echo 8")
if [ "$_a" != "$_b" ]; then
  inf "control: the comparison DOES separate two different answers"
else
  echo "  CONTROL FAILED: 7 and 8 compared equal."; CTRL=1
fi

# (c) a command whose honest answer is ZERO must read as 0, not as an error.
#     This is the exact fault that made seven tasks look broken.
_z=$(runcmd "grep -c 'string_that_is_certainly_absent_zzz' README.md")
if [ "$_z" = "0" ]; then
  inf "control: a zero-match grep reads as 0, not as a fault"
else
  echo "  CONTROL FAILED: a zero count came back as '$_z' -- the harness is"
  echo "  swallowing a legitimate measurement of zero."; CTRL=1
fi

# (d) the router must actually answer, and must answer DIFFERENTLY for two
#     prompts with different stems. A --route that returned a constant would
#     make every lane check pass by accident.
_r1=$(bash "$ROUTER" --route "debug this crash" 2>/dev/null | head -1 | cut -d'|' -f1 | cut -d' ' -f1)
_r2=$(bash "$ROUTER" --route "encode this concisely" 2>/dev/null | head -1 | cut -d'|' -f1 | cut -d' ' -f1)
if [ -n "$_r1" ] && [ -n "$_r2" ] && [ "$_r1" != "$_r2" ]; then
  inf "control: the router discriminates two lanes live ($_r1 vs $_r2)"
else
  echo "  CONTROL FAILED: --route gave '$_r1' and '$_r2'; a constant router would"
  echo "  make every lane assertion pass without measuring anything."; CTRL=1
fi

if [ "$CTRL" -ne 0 ]; then
  echo
  echo "corpus-verify: CONTROLS FAILED -- this run measured nothing it can stand behind."
  exit 2
fi

echo
echo "  $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  echo "corpus-verify: FAIL"
  exit 1
fi
echo "corpus-verify: PASS -- $EXPECT_TASKS tasks, all discriminating, all lane-bound."
exit 0
