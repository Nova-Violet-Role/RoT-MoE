#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE BINDING: the Lean witness must carry the SAME weights the shell ships.
#
# lean/Proofs/RotGauge.lean:432 defines `forge`, the nine-lens table the gauge
# theorems are instantiated at -- the SHIPPING numbers, not toy values, so the
# proofs demonstrably apply to the configuration in production.
#
# IT MUST BE THE REAL TABLE. This checker originally read a SECOND copy of the
# same weights that had been written into RotVacuity.lean. Binding the copy
# means `forge` itself could drift from the router with every gate still green
# -- the duplicate was deleted and this now reads the one the theorems use.
#
# That choice creates an obligation this checker discharges. The moment someone
# retunes LAMBDAS or MUS in hooks/rot-router.sh, the Lean witness silently
# becomes a statement about a profile nobody runs. Every gate stays green:
# `lake build` still succeeds, the theorems are still true, the router still
# works -- and the claim "proved for the shipping profile" quietly becomes
# false. Nothing else in this repo can see that.
#
# A NOTE ON WHAT THIS DOES *NOT* SAY, because the distinction is the point:
# this proves the NUMBERS agree. It does not prove the shell computes the same
# FUNCTION as the Lean definition -- that is checker/cross-diff.sh's job, which
# compares both router arms against a corpus of measured live readings. Two
# different claims, two different instruments, neither a substitute.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

SH="hooks/rot-router.sh"
LEAN="lean/Proofs/RotGauge.lean"
pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }

echo "== Lean witness vs shipped weights =="

[ -f "$SH" ]   || { echo "  FAIL  missing $SH";   exit 1; }
[ -f "$LEAN" ] || { echo "  FAIL  missing $LEAN"; exit 1; }

# --- extract from the shell ------------------------------------------------
sh_lam=$(grep -m1 "^LAMBDAS=" "$SH" | sed "s/^LAMBDAS='//; s/'$//")
sh_mu=$(grep  -m1 "^MUS="     "$SH" | sed "s/^MUS='//; s/'$//")

# --- extract from the Lean witness ------------------------------------------
# The forge table is a list of ⟨lam, mu⟩ pairs, one per line, with the
# lens name in a trailing comment. Pull the two numbers from each pair.
# PRECISION MATTERS HERE, and the sloppy version was caught in the act. A first
# attempt started the scan on any line merely CONTAINING "forge" -- which caught
# docstrings mentioning `forge_posWeights` and pulled 11 pairs out of a 9-lens
# table. It failed loudly, but a variant of that mistake that over-matched by
# ZERO rows would have compared two empty lists and passed. Anchor on the
# definition, stop at the first line that is not a match arm.
lean_pairs=$(awk '
  /^def forge / { inside = 1; next }
  inside && $0 !~ /^[ \t]*\|/ { inside = 0 }
  inside {
    if (match($0, /[0-9]+\.[0-9]+, *[0-9]+\.[0-9]+/)) {
      s = substr($0, RSTART, RLENGTH); gsub(/ /, "", s); print s
    }
  }' "$LEAN")

lean_lam=$(printf '%s\n' "$lean_pairs" | cut -d, -f1 | tr '\n' ' ' | sed 's/ $//')
lean_mu=$(printf  '%s\n' "$lean_pairs" | cut -d, -f2 | tr '\n' ' ' | sed 's/ $//')

n_lean=$(printf '%s\n' "$lean_pairs" | grep -c .)
n_sh=$(printf '%s\n' $sh_lam | grep -c .)

echo "  shell LAMBDAS : $sh_lam"
echo "  lean  lambdas : $lean_lam"
echo "  shell MUS     : $sh_mu"
echo "  lean  mus     : $lean_mu"

# The extractor must actually find something, or every comparison below is a
# vacuous pass -- the same failure this repo keeps hunting.
if [ "$n_lean" -eq 0 ]; then
  bad "extracted NOTHING from the Lean witness -- this check would pass vacuously"
elif [ "$n_lean" -ne "$n_sh" ]; then
  bad "lens COUNT differs: shell has $n_sh, Lean witness has $n_lean"
else
  ok "lens count agrees ($n_sh)"
fi

# Numeric comparison, tolerant of 1.1 vs 1.10 -- a formatting difference is not
# a disagreement, and treating it as one would train people to ignore this.
norm () { printf '%s\n' $1 | awk '{printf "%.4f ", $1+0}'; }
if [ "$(norm "$sh_lam")" = "$(norm "$lean_lam")" ]; then
  ok "lambdas agree between the shell and the Lean witness"
else
  bad "LAMBDAS DIFFER -- the Lean witness no longer describes the shipping profile"
fi
if [ "$(norm "$sh_mu")" = "$(norm "$lean_mu")" ]; then
  ok "mus agree between the shell and the Lean witness"
else
  bad "MUS DIFFER -- the Lean witness no longer describes the shipping profile"
fi

# --- negative control -------------------------------------------------------
echo
echo "-- negative control --"
mutated=$(printf '%s\n' $sh_lam | awk 'NR==1{$1=$1+0.5} {printf "%s ", $1}' | sed 's/ $//')
if [ "$(norm "$mutated")" = "$(norm "$lean_lam")" ]; then
  bad "CONTROL DEAD: a retuned first lambda still compared equal"
else
  ok "CONTROL: retuning one lambda (+0.5) WOULD be detected"
fi

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  lean-binds-shell: PASS"; exit 0; } || { echo "  lean-binds-shell: FAIL"; exit 1; }
