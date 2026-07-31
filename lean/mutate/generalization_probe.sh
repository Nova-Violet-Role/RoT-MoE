#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE GENERALIZATION PROBE -- does the theorem actually constrain the function?
#
# The sharpest test for a decorative theorem: take the statement, replace the
# SPECIFIC function with an ARBITRARY one of the same type, and ask whether the
# statement is still true. If it is, the theorem never said anything about the
# function -- the name and the doc comment were carrying the meaning.
#
# That is how `classify_total` was caught in this repo:
#
#   classify_total : exists-unique b, classify lo hi R = b
#
# holds with `classify` replaced by any f whatsoever. Green, clean axioms,
# survived leanchecker, said nothing.
#
# -----------------------------------------------------------------------------
# A DEFECT IN THE FIRST VERSION OF THIS FILE, kept in the record because it is
# the more instructive half:
#
# The first design wrote each generalized statement and required it to FAIL to
# compile. Every probe duly failed and every theorem was reported LOAD-BEARING.
# But the failures were `failed to synthesize Decidable (forall f : Flags, ...)`
# -- the TACTIC could not run. A tactic that cannot execute is not evidence that
# a statement is false, and the probe was manufacturing exactly the reassuring
# verdict it existed to challenge. Its own positive control caught it.
#
# So the probes below REFUTE instead: each exhibits a concrete function for
# which the generalized statement is FALSE, and must COMPILE. A refutation that
# elaborates is proof; a tactic that fails to fire is nothing.
# -----------------------------------------------------------------------------
#
# WHY NOT THE AXIOM SWEEP: because it was measured and it failed here. "Depends
# on no axioms" is often cited as a vacuity smell. On this packet it flagged SIX
# theorems -- route_fires, route_covers_every_mode, nsil_overrides_tier1,
# nsil_confirm_is_tier1, nsil_boost_preserves_lead, disarm_preserves_all_scalars
# -- all load-bearing (decidable statements closed by `decide`, which
# legitimately needs no axioms). And it MISSED classify_total, which depends on
# [propext, Classical.choice, Quot.sound] because it is stated over the reals.
# Six false positives and one false negative on the only case where the answer
# was known. It is not used as a gate here, and that is a measurement, not a
# preference.
# =============================================================================

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LEAN_DIR="${LEAN_DIR:-$(cd "$HERE/.." && pwd)}"
cd "$LEAN_DIR"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/genprobe.XXXXXX")"
pass=0; fail=0

probe () {   # probe <name> <expect: OK|NOCOMPILE> <description> <lean source>
  local name="$1" expect="$2" desc="$3" src="$4"
  printf '%s\n' "$src" > "$TMP/$name.lean"
  lake env lean "$TMP/$name.lean" > "$TMP/$name.log" 2>&1
  local rc=$?
  if [ "$expect" = "OK" ]; then
    if [ "$rc" -eq 0 ]; then
      echo "  PASS  $name -- $desc"
      pass=$((pass+1))
    else
      echo "  FAIL  $name -- expected this to compile: $desc"
      sed 's/^/          /' "$TMP/$name.log" | head -6
      fail=$((fail+1))
    fi
  else
    if [ "$rc" -ne 0 ]; then
      echo "  PASS  $name -- $desc (refused, exit $rc)"
      pass=$((pass+1))
    else
      echo "  FAIL  $name -- IT COMPILED, and it must not: $desc"
      fail=$((fail+1))
    fi
  fi
}

echo "== generalization probe =="

# --- the decorative shape, both directions ---------------------------------
probe decorative_holds OK \
  "classify_total's shape holds for an ARBITRARY function: DECORATIVE" '
import Proofs.RotGauge
example (f : ℝ → ℝ → ℝ → RotMoE.Band) (lo hi R : ℝ) : ∃! b, f lo hi R = b :=
  ⟨f lo hi R, rfl, fun _ h => h.symm⟩
'

probe decorative_irrefutable NOCOMPILE \
  "and it cannot be refuted -- confirming it constrains nothing" '
import Proofs.RotGauge
example : ¬ (∀ (f : ℝ → ℝ → ℝ → RotMoE.Band) (lo hi R : ℝ), ∃! b, f lo hi R = b) := by
  intro h
  exact absurd (h (fun _ _ _ => RotMoE.Band.below) 0 0 0) (by simp)
'

# --- the load-bearing theorems: each generalization is REFUTED -------------
probe route_fires OK \
  "route_fires generalized is FALSE (a constant router does not fire)" '
import Proofs.RotRoute
open RotMoE.Route
example : ¬ (∀ (g : Flags → Mode) (f : Flags), fired f (g f) = true) := by
  intro h
  have := h (fun _ => Mode.forge) ⟨false, false, false, false, false, false, false, false, false⟩
  simp [fired] at this
'

probe disarm_preserves_all_scalars OK \
  "disarm_preserves_all_scalars generalized is FALSE (a function may clobber)" '
import Proofs.RotInstall
open RotMoE.Install
example : ¬ (∀ (d : String → Settings → Settings) (cmd : String) (s : Settings) (k : String),
    (d cmd s).scalar k = s.scalar k) := by
  intro h
  have := h (fun _ _ => ⟨fun _ => some (Val.num 1), fun _ => []⟩) "x"
              ⟨fun _ => none, fun _ => []⟩ "k"
  simp at this
'

probe classify_surjective OK \
  "classify_surjective generalized is FALSE (a constant classifier misses bands)" '
import Proofs.RotGauge
example : ¬ (∀ (f : ℝ → ℝ → ℝ → RotMoE.Band) (lo hi : ℝ), lo ≤ hi →
    ∀ b, ∃ R, f lo hi R = b) := by
  intro h
  obtain ⟨R, hR⟩ := h (fun _ _ _ => RotMoE.Band.below) 0 0 le_rfl RotMoE.Band.above
  exact RotMoE.Band.noConfusion hR
'

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
rm -rf "$TMP"
[ "$fail" -eq 0 ] && exit 0 || exit 1
