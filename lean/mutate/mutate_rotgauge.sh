#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# Mutation harness for Proofs/RotGauge.lean
#
# Contract (the part that makes this an instrument rather than decoration):
#   1. assert the needle is present EXACTLY once before mutating; if not -> DISCARDED
#   2. assert the replacement is present and the needle gone AFTER mutating
#   3. delete the stale .olean so Lake cannot skip the rebuild
#   4. build, read the exit code DIRECTLY
#   5. attribute each error line to the enclosing declaration
#   6. restore and rebuild at the end, confirming a clean baseline
#
# DISCARDED != SURVIVED. The first is a defect in this harness, the second is a
# claim about the theorem. They are reported separately and never merged.

set -u

# Repo-relative by construction: no machine-local path ships (R2).
# Override with LEAN_ROOT=... to run against a different workspace.
LEAN_ROOT="${LEAN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
F="$LEAN_ROOT/Proofs/RotGauge.lean"
BAK="$F.mutbak"
OLEAN="$LEAN_ROOT/.lake/build/lib/lean/Proofs/RotGauge.olean"
LOG="${TMPDIR:-/tmp}/mut"

mkdir -p "$LOG"
cp "$F" "$BAK"

killed=0; survived=0; discarded=0

run_mut() {
  local id="$1" needle="$2" repl="$3" expect="$4"
  cp "$BAK" "$F"

  local n
  n=$(grep -F -c -- "$needle" "$BAK")
  if [ "$n" -ne 1 ]; then
    echo "$id  DISCARDED  needle occurs $n times (expected 1) -- patch not applied"
    discarded=$((discarded+1)); return
  fi

  awk -v needle="$needle" -v repl="$repl" '{
    p = index($0, needle)
    if (p > 0) { $0 = substr($0,1,p-1) repl substr($0, p+length(needle)) }
    print
  }' "$BAK" > "$F"

  # assertion 2: the mutation actually landed
  local after_needle after_repl
  after_needle=$(grep -F -c -- "$needle" "$F")
  after_repl=$(grep -F -c -- "$repl" "$F")
  if [ "$after_needle" -ne 0 ] || [ "$after_repl" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed (needle=$after_needle repl=$after_repl)"
    discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi

  rm -f "$OLEAN"
  ( cd "$LEAN_ROOT" && lake build Proofs.RotGauge ) > "$LOG/$id.log" 2>&1
  local ec=$?

  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   (build still exit 0)  expected to kill: $expect"
    survived=$((survived+1))
  else
    local dead
    dead=$(grep -oE "^error: Proofs/RotGauge\.lean:[0-9]+" "$LOG/$id.log" | grep -oE "[0-9]+$" | sort -un | \
      while read -r ln; do
        awk -v L="$ln" '
          /^(theorem|def|noncomputable def|instance|structure|inductive|example)/ {
            if (NR <= L) { name=$0; nline=NR }
          }
          END { if (name != "") print name }
        ' "$F"
      done | sed -E 's/^(noncomputable )?(theorem|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' | sort -u | tr '\n' ',' )
    echo "$id  KILLED     exit=$ec  dead: ${dead%,}  | expected: $expect"
    killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

echo "=== RotGauge mutation suite ==="

run_mut M01 \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1 / 2)))' \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (4 * (x - 1 / 2)))' \
  'sigma_strictMono (slope sign flipped)'

run_mut M02 \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1 / 2)))' \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1 / 3)))' \
  'sigma_half (centre moved)'

run_mut M03 \
  '  (∑ i, term L a breadth M C T i) / (Fintype.card ι)' \
  '  0' \
  'gauge_pos, gauge_not_constant (gauge replaced by a constant)'

run_mut M04 \
  '  if breadth = 0 then 0 else min 1 (actR a i / (breadth : ℝ))' \
  '  if breadth = 0 then 0 else max 1 (actR a i / (breadth : ℝ))' \
  'entropyAt_le_one, entropyAt_allQuiet (cap inverted)'

run_mut M05 \
  'noncomputable def deltaAt (a : ι → Bool) (i : ι) : ℝ := |actR a i - meanAct a|' \
  'noncomputable def deltaAt (a : ι → Bool) (i : ι) : ℝ := actR a i - meanAct a' \
  'deltaAt_nonneg, gauge_ge_floor (absolute value dropped)'

run_mut M06 \
  '  (∑ i, term L a breadth M C T i) / (Fintype.card ι)' \
  '  (∑ i, term L a breadth M C T i) / 9' \
  'gauge_divisor_eq_card (K hardcoded to 9)'

run_mut M07 \
  '  if R < lo then .below else if hi < R then .above else .inRange' \
  '  if R ≤ lo then .below else if hi < R then .above else .inRange' \
  'classify_below_iff, classify_inRange_iff (band off-by-one)'

run_mut M08 \
  '  | .claude => ⟨2.3, 1.15⟩' \
  '  | .claude => ⟨-2.3, 1.15⟩' \
  'forge_posWeights (a shipped weight made negative)'

run_mut M09 \
  '  sigma (deltaAt a i) * (1 + entropyAt a breadth i)' \
  '  sigma (deltaAt a i) * (1 + 0 * entropyAt a breadth i)' \
  'term_eq_ps1_order, gauge_allLive_eq_two_mul_allQuiet (breadth bonus removed)'

run_mut M10 \
  'def actR (a : ι → Bool) (i : ι) : ℝ := if a i then 1 else 0' \
  'def actR (a : ι → Bool) (i : ι) : ℝ := if a i then 0 else 0' \
  'actR_allLive, gauge_not_constant (every lens pinned to 0 -- the :362-366 bug class)'

# restore and confirm a clean baseline
cp "$BAK" "$F"
rm -f "$OLEAN"
( cd "$LEAN_ROOT" && lake build Proofs.RotGauge ) > "$LOG/baseline.log" 2>&1
base=$?
echo "---"
echo "killed=$killed survived=$survived discarded=$discarded"
echo "baseline restored -> lake build exit=$base"
rm -f "$BAK"
