/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# Calibrating a corpus, and the two ways calibration cheats

Three efficacy metrics have now been measured, and each failed a DIFFERENT
control:

| metric | outcome | why it settles nothing |
|---|---|---|
| compliance | routed 29-4, p = 1.09e-5 | 27/29 wins were merely shorter answers |
| grounding | routed 8-0, p = 0.0078 | volume-matched: 18 pairs, 0-0, all tied |
| facts | 84-84, p = 1.0 | ceiling: zero discordant pairs, NO POWER |

`RotCeiling` proves the third is not a null. This module is about the repair:
choose items whose BASELINE accuracy sits strictly between floor and ceiling,
so the instrument has somewhere to move.

That repair is where a measurement becomes easy to fake, and the two ways are
opposite:

1. **Select on the routed arm.** Keep only items the routed arm answered
   correctly and the routed arm cannot lose a single pair -- the win is
   manufactured by the filter, not measured. Proven below:
   `circular_selection_cannot_lose`.
2. **Select on the test reps themselves.** Even selecting on the BASELINE arm
   is circular if the run being graded is the run that chose the items.
   Selection must read CALIBRATION reps and the graded run must be FRESH.
   Proven below: `selecting_on_the_test_result_also_biases`.

## What calibration does NOT buy

It does not buy power. An item can sit in the band on its calibration reps and
still be answered correctly by both arms on the fresh rep, and a calibrated run
that returns zero discordant pairs is STILL `noPower` -- not a null. That is
`calibration_does_not_guarantee_power`, and it exists so this module cannot be
read as promising a result it cannot deliver. Calibration removes a known
reason for no power; it does not create power.

## Why two reps is a hard floor

With one rep an item scores 0 or 1 -- floor or ceiling, never between. So a
one-rep calibration selects the EMPTY corpus, and a harness that then reports
"no difference" would be reporting the absence of its own input.
`one_rep_pool_calibrates_to_nothing` makes that a theorem so the harness must
abort loudly instead.
-/
import Proofs.RotCeiling

namespace RotMoE.Calibration

open RotMoE.Ceiling

/-- One candidate prompt, carrying the BASELINE (unrouted) arm's calibration
record only. The routed arm deliberately does not appear here: if it could
influence selection, the selection would decide the result. -/
structure Item where
  /-- How many calibration reps the UNROUTED arm answered correctly. -/
  calibCorrect : Nat
  /-- How many calibration reps were run. -/
  calibReps : Nat
deriving DecidableEq, Repr

/-- In band: strictly between floor and ceiling on the baseline arm. -/
def inBand (i : Item) : Bool :=
  0 < i.calibCorrect && i.calibCorrect < i.calibReps

/-- The corpus that survives calibration. -/
def calibrated (pool : List Item) : List Item := pool.filter inBand

section TheBand

theorem band_excludes_the_floor (n : Nat) : inBand ⟨0, n⟩ = false := by
  simp [inBand]

theorem band_excludes_the_ceiling (n : Nat) : inBand ⟨n, n⟩ = false := by
  simp [inBand]

/-- An item nobody ever got right and an item nobody ever got wrong are both
excluded -- that is the whole point, stated as one fact. -/
theorem band_excludes_both_saturations (n : Nat) :
    inBand ⟨0, n⟩ = false ∧ inBand ⟨n, n⟩ = false :=
  ⟨band_excludes_the_floor n, band_excludes_the_ceiling n⟩

/-- Reachable, so the band is not vacuously empty. -/
theorem band_is_inhabited : inBand ⟨1, 3⟩ = true ∧ inBand ⟨2, 3⟩ = true := by
  decide

/-- TWO REPS IS A HARD FLOOR. Anything in the band needed at least two. -/
theorem band_needs_two_reps (i : Item) (h : inBand i = true) : 2 ≤ i.calibReps := by
  simp [inBand] at h
  omega

/-- Therefore a one-rep calibration selects NOTHING. A harness that runs one rep
and then reports "no difference between the arms" is reporting the absence of
its own input, which is the `RotCeiling` mistake wearing a different hat. -/
theorem one_rep_pool_calibrates_to_nothing (pool : List Item)
    (h : ∀ i ∈ pool, i.calibReps ≤ 1) : calibrated pool = [] := by
  induction pool with
  | nil => rfl
  | cons p t ih =>
    have hp : p.calibReps ≤ 1 := h p (List.mem_cons_self ..)
    have ht : ∀ i ∈ t, i.calibReps ≤ 1 := fun i hi => h i (List.mem_cons_of_mem _ hi)
    have hf : inBand p = false := by
      simp [inBand]; omega
    simp [calibrated, hf] at *
    exact ih ht

end TheBand

/-- One graded pair from the FRESH run: was each arm right. -/
structure Pair where
  routedRight : Bool
  baselineRight : Bool
deriving DecidableEq, Repr

/-- Fold a list of graded pairs into the `RotCeiling` comparison, so the verdict
machinery already proven there applies unchanged. -/
def tally (ps : List Pair) : Comparison :=
  ⟨(ps.filter (fun p => p.routedRight && !p.baselineRight)).length,
   (ps.filter (fun p => !p.routedRight && p.baselineRight)).length,
   (ps.filter (fun p => p.routedRight && p.baselineRight)).length,
   (ps.filter (fun p => !p.routedRight && !p.baselineRight)).length⟩

section CircularSelection

/-- THE FIRST WAY TO CHEAT. Keep only the pairs the ROUTED arm got right and the
routed arm cannot lose a single pair: `unroutedOnly` is zero BY CONSTRUCTION,
for every input whatsoever. The filter decided the outcome, not the router. -/
theorem circular_selection_cannot_lose (ps : List Pair) :
    (tally (ps.filter (fun p => p.routedRight))).unroutedOnly = 0 := by
  simp only [tally, List.filter_filter, List.length_eq_zero_iff,
    List.filter_eq_nil_iff]
  intro a _
  simp
  exact fun h _ => h

/-- THE SECOND WAY, and it is subtler because it looks fair: select on the
BASELINE arm's own graded result. Keep only the pairs the baseline got wrong and
`bothRight` is zero by construction -- the baseline is denied every concordant
win it earned. Selection must therefore read CALIBRATION reps, never the reps
being graded, whichever arm they come from. -/
theorem selecting_on_the_test_result_also_biases (ps : List Pair) :
    (tally (ps.filter (fun p => !p.baselineRight))).bothRight = 0 := by
  simp only [tally, List.filter_filter, List.length_eq_zero_iff,
    List.filter_eq_nil_iff]
  intro a _
  simp

/-- Neither theorem above is vacuous: on an UNFILTERED list the routed arm can
and does lose, and concordant wins do exist. Without this the two theorems could
be true merely because nothing ever populates those fields. -/
theorem unfiltered_tally_can_show_a_routed_loss :
    (tally [⟨false, true⟩, ⟨true, true⟩]).unroutedOnly = 1 ∧
    (tally [⟨false, true⟩, ⟨true, true⟩]).bothRight = 1 := by
  decide

end CircularSelection

/-- The design record of a paired run. -/
structure Design where
  /-- Reps used to ESTIMATE each item's baseline difficulty. -/
  calibReps : Nat
  /-- Is the graded run distinct from the reps that chose the items. -/
  testRepsAreFresh : Bool
  /-- Did the routed arm influence which items were kept. -/
  selectionUsedRoutedArm : Bool
deriving DecidableEq, Repr

def sound (d : Design) : Bool :=
  2 ≤ d.calibReps && d.testRepsAreFresh && !d.selectionUsedRoutedArm

/-- The design this repository will actually run: three baseline reps per
candidate, a fresh graded run, routed arm blind to selection. -/
def planned : Design := ⟨3, true, false⟩

section SoundnessOfTheDesign

theorem the_planned_design_is_sound : sound planned = true := by decide

theorem one_rep_calibration_is_unsound (f b : Bool) : sound ⟨1, f, b⟩ = false := by
  cases f <;> cases b <;> decide

theorem zero_rep_calibration_is_unsound (f b : Bool) : sound ⟨0, f, b⟩ = false := by
  cases f <;> cases b <;> decide

theorem reusing_the_calibration_reps_is_unsound (r : Nat) (b : Bool) :
    sound ⟨r, false, b⟩ = false := by
  cases b <;> simp [sound]

theorem selecting_on_the_routed_arm_is_unsound (r : Nat) (f : Bool) :
    sound ⟨r, f, true⟩ = false := by
  cases f <;> simp [sound]

/-- Every clause of `sound` is load-bearing: drop any ONE of the three and a
design that should be rejected is accepted. Stated as three witnesses that
differ from `planned` in exactly one field. -/
theorem all_three_clauses_are_load_bearing :
    sound ⟨1, true, false⟩ = false ∧
    sound ⟨3, false, false⟩ = false ∧
    sound ⟨3, true, true⟩ = false := by
  decide

end SoundnessOfTheDesign

section WhatCalibrationCannotBuy

/-- THE ANTI-OVERCLAIM. Calibration does not manufacture power. An item can sit
in the band on its calibration reps and still be answered correctly by both arms
on the fresh rep; a calibrated run returning zero discordant pairs is `noPower`,
exactly as before, and must be reported as such rather than as a null. -/
theorem calibration_does_not_guarantee_power :
    inBand ⟨1, 3⟩ = true ∧ verdict (tally [⟨true, true⟩]) = Verdict.noPower := by
  decide

/-- An EMPTY calibrated corpus reproduces the `RotCeiling` failure exactly. So
"the calibration kept nothing" and "the arms are equal" are the same shape on
the wire and must not be reported the same way. -/
theorem empty_corpus_reproduces_the_ceiling_failure :
    verdict (tally []) = Verdict.noPower ∧ verdict (tally []) ≠ Verdict.null := by
  decide

/-- And the point of doing it anyway: a calibrated run CAN reach a verdict that
the fact corpus could not. Without this the whole exercise would be pointless,
so it is stated rather than assumed. -/
theorem a_calibrated_run_can_reach_a_verdict :
    verdict (tally [⟨true, false⟩, ⟨true, false⟩, ⟨false, true⟩]) = Verdict.advantage ∧
    verdict (tally [⟨false, true⟩, ⟨false, true⟩, ⟨true, false⟩]) = Verdict.null := by
  decide

end WhatCalibrationCannotBuy

section Measured

#guard inBand ⟨1, 3⟩ = true
#guard inBand ⟨2, 3⟩ = true
#guard inBand ⟨0, 3⟩ = false
#guard inBand ⟨3, 3⟩ = false
#guard inBand ⟨0, 1⟩ = false
#guard inBand ⟨1, 1⟩ = false
#guard calibrated [⟨0, 3⟩, ⟨1, 3⟩, ⟨3, 3⟩, ⟨2, 3⟩] = [⟨1, 3⟩, ⟨2, 3⟩]
#guard calibrated [⟨0, 1⟩, ⟨1, 1⟩] = []
#guard sound planned = true
#guard sound ⟨1, true, false⟩ = false
#guard sound ⟨3, false, false⟩ = false
#guard sound ⟨3, true, true⟩ = false
#guard (tally [⟨true, false⟩, ⟨false, true⟩, ⟨true, true⟩, ⟨false, false⟩]) = ⟨1, 1, 1, 1⟩
#guard (tally (([⟨false, true⟩, ⟨true, false⟩] : List Pair).filter
          (fun p => p.routedRight))).unroutedOnly = 0
#guard verdict (tally []) = Verdict.noPower

end Measured

end RotMoE.Calibration
