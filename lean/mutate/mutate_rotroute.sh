#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# Mutation harness for Proofs/RotRoute.lean. Same contract as
# mutate_rotgauge.sh: needle asserted present exactly once BEFORE, replacement
# asserted present and needle gone AFTER, stale .olean deleted, exit code read
# directly, DISCARDED never folded into SURVIVED.
#
# This run has a specific question to answer. #print axioms reports FIVE
# theorems in this module depending on no axioms at all -- route_fires,
# route_covers_every_mode, nsil_overrides_tier1, nsil_confirm_is_tier1,
# nsil_boost_preserves_lead. The spec says treat that as suspected vacuity.
# For a decidable finite model it is usually just "proved by computation", but
# "usually" is not evidence. N01-N07 below aim one mutation at each of them.

set -u

# Repo-relative by construction: no machine-local path ships (R2).
# Override with LEAN_ROOT=... to run against a different workspace.
LEAN_ROOT="${LEAN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
F="$LEAN_ROOT/Proofs/RotRoute.lean"
BAK="$F.mutbak"
OLEAN="$LEAN_ROOT/.lake/build/lib/lean/Proofs/RotRoute.olean"
LOG="${TMPDIR:-/tmp}/mutr"
mkdir -p "$LOG"
# --- PREFLIGHT: no green baseline, no attributable kills --------------------
# Added 2026-07-31 after two SIBLING suites were caught scoring 11 kills
# without ever opening a source file: their builds failed because the
# workspace was not there, and every such failure was recorded as KILLED.
# This suite resolved its paths correctly, but it shared the deeper defect --
# it never checked that the UNMUTATED tree builds. A kill measured against a
# red baseline cannot be attributed to the mutation that supposedly caused it.
[ -f "$F" ] || {
  echo "FATAL: $F not found. Refusing to run: every mutant would fail to build"
  echo "and be scored KILLED without a line having been mutated."
  exit 2
}
if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotRoute ) >/tmp/mut_pre_rotroute.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotRoute)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotroute.log
  exit 2
fi
echo "preflight: baseline builds GREEN, $F present -- kills are attributable"

cp "$F" "$BAK"
killed=0; survived=0; discarded=0

run_mut() {
  local id="$1" needle="$2" repl="$3" expect="$4"
  cp "$BAK" "$F"
  local n; n=$(grep -F -c -- "$needle" "$BAK")
  if [ "$n" -ne 1 ]; then
    echo "$id  DISCARDED  needle occurs $n times (expected 1)"; discarded=$((discarded+1)); return
  fi
  awk -v needle="$needle" -v repl="$repl" '{
    p = index($0, needle)
    if (p > 0) { $0 = substr($0,1,p-1) repl substr($0, p+length(needle)) }
    print
  }' "$BAK" > "$F"
  local an ar; an=$(grep -F -c -- "$needle" "$F"); ar=$(grep -F -c -- "$repl" "$F")
  if [ "$an" -ne 0 ] || [ "$ar" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed (needle=$an repl=$ar)"; discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi
  rm -f "$OLEAN"
  ( cd "$LEAN_ROOT" && lake build Proofs.RotRoute ) > "$LOG/$id.log" 2>&1
  local ec=$?
  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   expected to kill: $expect"; survived=$((survived+1))
  else
    local dead
    dead=$(grep -oE "^error: Proofs/RotRoute\.lean:[0-9]+" "$LOG/$id.log" | grep -oE "[0-9]+$" | sort -un | \
      while read -r ln; do
        awk -v L="$ln" '/^(@\[[^]]*\] )?(noncomputable )?(theorem|lemma|def|instance|structure|inductive|example)[ (]/ { if (NR <= L) name=$0 } END { if (name != "") print name }' "$F"
      done | sed -E 's/^@\[[^]]*\] *//; s/^(noncomputable )?(theorem|lemma|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' | sort -u | tr '\n' ' ')
    echo "$id  KILLED     dead: $dead | expected: $expect"; killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

echo "=== RotRoute mutation suite ==="

run_mut N01 \
  '  else if f.executive then .executive' \
  '  else if f.empathic then .empathic' \
  'route_exact (two branches swapped)'

run_mut N02 \
  '  else .convergent' \
  '  else .stealth' \
  'route_exact, route_default_convergent (fallthrough changed)'

run_mut N03 \
  '  else if f.creative then .creative' \
  '  else if f.strategic then .creative' \
  'route_covers_every_mode (creative lane shadowed -> unreachable)'

run_mut N04 \
  '  if f.forge then .forge' \
  '  if f.forge then .clinical' \
  'route_fires, forge_priority, route_exact (branch points at wrong lane)'

run_mut N05 \
  '  | .override m => .single m' \
  '  | .override _ => .single (route f)' \
  'nsil_overrides_tier1 (NSIL ignored -- back to a keyword if-chain)'

run_mut N06 \
  '  | .confirm => .single (route f)' \
  '  | .confirm => .single .convergent' \
  'nsil_confirm_is_tier1 (CONFIRM stops confirming)'

run_mut N07 \
  '  | .boost => .single (route f)' \
  '  | .boost => .ensemble' \
  'nsil_boost_preserves_lead (BOOST moves the lead)'

run_mut N08 \
  'noncomputable def lamH (l₁ l₂ : ℝ) : ℝ := (l₁ + l₂) / 2 + 0.2' \
  'noncomputable def lamH (l₁ l₂ : ℝ) : ℝ := (l₁ + l₂) / 2' \
  'lamH_gt_mean, symbiogenesis_wellformed (+0.2 hybridisation gain dropped)'

run_mut N09 \
  'noncomputable def hH (h₁ h₂ : ℝ) : ℝ := max h₁ h₂ + 0.05' \
  'noncomputable def hH (h₁ h₂ : ℝ) : ℝ := max h₁ h₂' \
  'hH_gt_both, symbiogenesis_wellformed (+0.05 novelty margin dropped)'

run_mut N10 \
  'noncomputable def muH (m₁ m₂ : ℝ) : ℝ := max m₁ m₂' \
  'noncomputable def muH (m₁ m₂ : ℝ) : ℝ := min m₁ m₂' \
  'muH_exact, symbiogenesis_wellformed (max -> min). symbiogenesis_comm should SURVIVE: min is commutative too, so comm alone is a weak property'

run_mut N11 \
  'noncomputable def lamH (l₁ l₂ : ℝ) : ℝ := (l₁ + l₂) / 2 + 0.2' \
  'noncomputable def lamH (l₁ l₂ : ℝ) : ℝ := l₁ + 0.2' \
  'symbiogenesis_comm (fusion made order-DEPENDENT -- this is what comm is for)'

cp "$BAK" "$F"
rm -f "$OLEAN"
( cd "$LEAN_ROOT" && lake build Proofs.RotRoute ) > "$LOG/baseline.log" 2>&1
base=$?
echo "---"
echo "killed=$killed survived=$survived discarded=$discarded"
echo "baseline restored -> lake build exit=$base"
rm -f "$BAK"
