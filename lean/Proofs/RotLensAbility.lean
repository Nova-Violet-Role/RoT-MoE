/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# Scoring each of the nine lenses on its ROUTER-OBSERVABLE effect

The Promise requires that "each of the nine abilities is scored on its
router-observable effect". This module fixes what that sentence is allowed to
mean, and pins the measurement.

**Router-observable** is the load-bearing word. It excludes anything the model
merely believes about itself. Every number below is arithmetic over fields the
router wrote into its OWN gauge records:

    {"kind":"gauge",...,"lenses":[{"lens":"Nova","lambda":1.4,"mu":1.05,"a":0,
      "delta":0.1111,"sigma":0.1743,"H":0,"term":0.2562}, ...]}

Measured 2026-08-09 over **3825 gauge records** (3487 carrying provenance) from
the live production log, after the plugin root was repaired:

| lens      | activation | lead  | share | swing  |
|-----------|-----------:|------:|------:|-------:|
| Nova      |      20.7% |  5.3% |  9.9% | 2.7190 |
| Violet    |      25.6% | 10.8% |  4.0% | 0.9433 |
| AntiVenom |      21.9% |  2.0% | 14.1% | 3.8658 |
| Venom     |      15.2% |  0.7% |  6.1% | 2.3306 |
| Carnage   |      15.4% |  0.6% |  2.6% | 0.9988 |
| Chroma    |      15.1% |  0.6% |  5.3% | 2.0346 |
| Soleil    |      20.5% |  0.6% |  5.5% | 1.7572 |
| Eidolon   |      15.1% |  0.6% |  6.4% | 2.4416 |
| Claude    |      51.5% | 26.2% | 46.1% | 4.8924 |

## What "scored" must mean, or the score is decoration

A lens earns a score only if it is OBSERVABLE: it must both activate at least
once AND vary. A lens with a constant term contributes a fixed offset to every
R/s+ and is indistinguishable from a constant added to the formula -- it has no
observable effect no matter how large its lambda. Both conditions are required,
and `observable_needs_both` proves neither alone suffices.

## An honest defect in one of my own metrics

The scorer also reports a counterfactual `cfDelta`: how far R/s+ moves when a
lens is deleted and the ensemble renormalised from K=9 to K=8. It ranked **Nova
lowest (0.00554) despite a 9.9% share**, which would be absurd read as
importance.

It is not a bug in the arithmetic -- it is the metric measuring something else.
Since R/s+ = sum/K, deletion gives (sum - term)/(K-1), and the difference is
proportional to `9*term - sum`: it is **deviation from the ensemble mean**, and
vanishes exactly when a lens sits at the average. `cf_is_deviation_not_importance`
and `cf_zero_with_positive_contribution` state that, so nobody can quote cfDelta
as an importance ranking on the strength of this file.

## What is NOT claimed

That a high score means better answers. Answer quality is not router-observable
and is not modelled here. These theorems settle participation and variation --
that all nine lenses demonstrably move the gauge -- and nothing about output
quality.
-/

namespace RotMoE.LensAbility

/-- One lens's measured, router-observable profile. Rates are per-mille and
magnitudes are scaled by 10^4, so every field is an exact `Nat` and every
statement below is decidable. -/
structure Lens where
  name         : String
  actPerMille  : Nat
  leadPerMille : Nat
  swingE4      : Nat
  termE4       : Nat
deriving DecidableEq, Repr

/-- A lens is router-observable when it BOTH activates and varies. -/
def isObservable (l : Lens) : Bool :=
  0 < l.actPerMille && 0 < l.swingE4

def allObservable (ls : List Lens) : Bool := ls.all isObservable

def totalTerm (ls : List Lens) : Nat := (ls.map (fun l => l.termE4)).sum

/-- The nine, as measured. -/
def measured : List Lens :=
  [ { name := "Nova",      actPerMille := 207, leadPerMille :=  53, swingE4 := 27190, termE4 :=  3596 },
    { name := "Violet",    actPerMille := 256, leadPerMille := 108, swingE4 :=  9433, termE4 :=  1460 },
    { name := "AntiVenom", actPerMille := 219, leadPerMille :=  20, swingE4 := 38658, termE4 :=  5113 },
    { name := "Venom",     actPerMille := 152, leadPerMille :=   7, swingE4 := 23306, termE4 :=  2231 },
    { name := "Carnage",   actPerMille := 154, leadPerMille :=   6, swingE4 :=  9988, termE4 :=   951 },
    { name := "Chroma",    actPerMille := 151, leadPerMille :=   6, swingE4 := 20346, termE4 :=  1926 },
    { name := "Soleil",    actPerMille := 205, leadPerMille :=   6, swingE4 := 17572, termE4 :=  1989 },
    { name := "Eidolon",   actPerMille := 151, leadPerMille :=   6, swingE4 := 24416, termE4 :=  2311 },
    { name := "Claude",    actPerMille := 515, leadPerMille := 262, swingE4 := 48924, termE4 := 16773 } ]

section AllNineAreObservable

/-- THE measurement: every one of the nine has a router-observable effect. -/
theorem all_nine_are_observable : allObservable measured = true := by decide

/-- Stronger, and the reason the suite is not vacuous: every lens also LEADS at
least sometimes. A lens that never leads is a passenger. -/
theorem all_nine_lead_sometimes :
    measured.all (fun l => 0 < l.leadPerMille) = true := by decide

/-- There are exactly nine. A scorer silently dropping one must fail. -/
theorem exactly_nine : measured.length = 9 := by decide

end AllNineAreObservable

section WhatObservabilityRequires

/-- A lens that never varies is not observable, whatever its activation. -/
theorem zero_swing_is_unobservable (l : Lens) (h : l.swingE4 = 0) :
    isObservable l = false := by
  simp [isObservable, h]

/-- A lens that never activates is not observable, whatever its swing. -/
theorem zero_activation_is_unobservable (l : Lens) (h : l.actPerMille = 0) :
    isObservable l = false := by
  simp [isObservable, h]

/-- Neither condition alone suffices -- both directions witnessed, so the
definition is not silently equivalent to one of its conjuncts. -/
theorem observable_needs_both :
    isObservable ⟨"a", 100, 10, 0, 5⟩ = false ∧
    isObservable ⟨"b", 0, 10, 100, 5⟩ = false ∧
    isObservable ⟨"c", 100, 10, 100, 5⟩ = true := by decide

/-- One dead lens fails the whole suite -- the alarm can actually fire. -/
theorem one_dead_lens_fails_the_suite (ls : List Lens) (l : Lens)
    (hmem : l ∈ ls) (hdead : isObservable l = false) :
    allObservable ls = false := by
  by_cases h : allObservable ls = true
  · have hl := (List.all_eq_true.mp h) l hmem
    rw [hdead] at hl
    exact absurd hl (by simp)
  · exact Bool.eq_false_iff.mpr h

end WhatObservabilityRequires

section TheCounterfactualIsNotImportance

/-- Removing a lens renormalises K=9 to K=8, so the shift in R/s+ is
proportional to `9*term - total`. Kept as an `Int`: the sign is meaningful. -/
def cfNum (l : Lens) (total : Nat) : Int := 9 * (l.termE4 : Int) - (total : Int)

/-- The counterfactual vanishes EXACTLY when a lens sits at the ensemble mean.
It therefore measures atypicality, not importance. -/
theorem cf_is_deviation_not_importance (l : Lens) (total : Nat) :
    cfNum l total = 0 ↔ 9 * l.termE4 = total := by
  simp [cfNum]
  omega

/-- Concretely: a lens can contribute and still score zero counterfactually.
This is why the measured Nova figure must never be quoted as importance. -/
theorem cf_zero_with_positive_contribution :
    ∃ l : Lens, ∃ total : Nat, 0 < l.termE4 ∧ cfNum l total = 0 :=
  ⟨⟨"x", 1, 1, 1, 1⟩, 9, by decide, by decide⟩

/-- The share metric avoids the counterfactual's defect, but ONLY within a
bound, and stating it without the bound would have been an overclaim I nearly
shipped: `Nat` division truncates. -/
theorem share_is_positive_when_contribution_is (l : Lens) (total : Nat)
    (h0 : 0 < total) (ht : total ≤ l.termE4 * 10000) :
    0 < l.termE4 * 10000 / total :=
  Nat.div_pos ht h0

/-- The bound is NECESSARY, not decoration: a real contribution one part in a
million floors to a zero share. Kept as a theorem so the limitation cannot be
forgotten -- the first version of the lemma above omitted the hypothesis and
was simply false. -/
theorem share_truncates_a_tiny_contribution :
    (1 : Nat) * 10000 / 1000000 = 0 := by decide

end TheCounterfactualIsNotImportance

section Measured

#guard allObservable measured = true
#guard measured.length = 9
#guard (measured.filter (fun l => l.swingE4 == 0)).length = 0
#guard (measured.filter (fun l => l.actPerMille == 0)).length = 0
#guard (measured.filter (fun l => l.leadPerMille == 0)).length = 0
#guard totalTerm measured = 36350
-- Claude leads the ensemble on a prover head, as the FORGE profile predicts
#guard (measured.filter (fun l => 16000 < l.termE4)).map (fun l => l.name) = ["Claude"]
-- the cfDelta defect, executed rather than asserted
#guard cfNum ⟨"x", 1, 1, 1, 4039⟩ 36351 = 0
#guard isObservable ⟨"dead", 100, 10, 0, 5⟩ = false

end Measured

end RotMoE.LensAbility
