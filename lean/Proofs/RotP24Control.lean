/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Proofs.RotP24Run

/-!
# The O4 verdict was retracted by its own control

## What happened, in one paragraph

`RotP24Run` reported O4 as **CONTRADICTED** — 40 of 40 discordant pairs forward
and 39 of 39 reverse went against the routed arm — and licensed that reading
with an A/A control of ⟨6, 2⟩. **That control was measured on the R4
answer-text scorer, a different instrument reading a different quantity.**
Using it to attribute an O4 result is the same class of error P2.4 was rebuilt
to fix: scoring one hypothesis with another hypothesis's observable. The
attribution was unearned, and it was unearned in the direction that made the
apparatus look more decisive than it was.

## The control that was actually needed, and what it returned

The 160 sessions are four blocks — {forward, reverse} × {routed, unrouted} —
and both orderings run the **same 40 tasks**. So pairing `forward-routed[task]`
against `reverse-routed[task]` is an A/A: identical arm, identical task, only
the position differs. Measured by `bench/p24-aa-control.js`:

| control | discordant | favouring |
|---|---|---|
| routed vs routed (A/A) | 32 | 26 |
| unrouted vs unrouted (A/A) | 15 | 3 |

O4 moves on **32 of 40 tasks** between two runs of the *same* arm. Whatever it
is reading, it is not stable under a change that involves no routing at all.

## The probe that settles it

O4 counts a number in the final message that appears in no preceding tool
output. So it was asked directly: across every A/B pair where the two sides
differ in both O4 and evidence volume, does the side with the **smaller**
haystack carry the **higher** O4?

**79 comparable pairs. 79 agreements. Rate 1.000.**

Not 0.6, not 0.9 — every single pair. The detector's output is a function of
haystack size on this data, and `no_statistic_can_separate_them` proves the
consequence that matters: when observed signs and confound-predicted signs are
equal pointwise, **every** statistic computed from them returns the identical
value. There is no test, no correction and no re-scoring that can recover an
arm effect from these signs, because the signs contain none.

## What this does and does not rescue

**It does not rescue the router.** "The routed arm does better work" remains
**NOT ESTABLISHED** — three observables were saturated and the fourth is
inadmissible, so P2.4 as run produced no evidence in either direction.
`p24_does_not_establish_better_work` in `RotP24Run` still holds and is not
weakened here.

**It does retract the claim against the router.** Reporting CONTRADICTED would
now be an overclaim in the unfavourable direction, and an unfavourable
overclaim is still an overclaim. The honest verdict is that **the O4 instrument
failed**, and the failure was found by a control this apparatus should have run
before publishing the number — not after.

The confound was named in `RotP24Run`'s own docstring, and it was named as a
*limitation shipped beside the verdict*. That was too weak. A confound measured
at rate 1.000 is not a limitation; it is a refutation of the instrument.
-/

namespace RotMoE.P24Control

open RotMoE.Family
open RotMoE.Experiment

/-! ## The general result: a fully confounded sign carries no information -/

/-- One discordant pair, recorded twice: the sign that was **observed**, and the
sign the **confound** predicts without reference to the arm.

For O4: `observed = true` means the routed side scored higher; `predicted =
true` means the routed side had the smaller evidence haystack. -/
structure Pair where
  /-- The sign actually measured on this pair. -/
  observed : Bool
  /-- The sign predicted by the confound alone, ignoring which arm is which. -/
  predicted : Bool
  deriving DecidableEq, Repr

/-- The pair agrees with its confound. -/
def agrees (p : Pair) : Bool := p.observed == p.predicted

/-- Every pair agrees with the confound — the state measured at 79 of 79. -/
def fullyConfounded (l : List Pair) : Bool := l.all agrees

/-- **Pointwise agreement means the two sign sequences are literally equal.**
Stated over an arbitrary list, so it is a property of confounding and not of
this run's 79 pairs. -/
theorem confounded_signs_equal_predicted (l : List Pair)
    (h : fullyConfounded l = true) :
    l.map Pair.observed = l.map Pair.predicted := by
  induction l with
  | nil => rfl
  | cons p t ih =>
    simp only [fullyConfounded, List.all_cons, Bool.and_eq_true] at h
    simp only [List.map_cons]
    have hp : p.observed = p.predicted := by
      have := h.1
      simp only [agrees, beq_iff_eq] at this
      exact this
    rw [hp, ih h.2]

/-- **THE CONSEQUENCE THAT MATTERS: no statistic whatsoever can separate the arm
from the confound.** For *any* function of the sign sequence — a sign test, a
tail probability, `verdictM`, anything a reader might propose afterwards — the
value computed from the observed signs equals the value computed from the signs
the confound alone predicts. A verdict derived from these pairs is therefore a
statement about evidence volume, and no re-analysis can make it a statement
about routing. -/
theorem no_statistic_can_separate_them {α : Type} (f : List Bool → α)
    (l : List Pair) (h : fullyConfounded l = true) :
    f (l.map Pair.observed) = f (l.map Pair.predicted) := by
  rw [confounded_signs_equal_predicted l h]

/-- The contrapositive, kept because it is the useful direction in practice: if
some statistic *does* distinguish the two attributions, then at least one pair
disagreed with the confound. An instrument earns its verdict by exhibiting such
a pair. -/
theorem a_separating_statistic_needs_a_disagreeing_pair {α : Type}
    (f : List Bool → α) (l : List Pair)
    (h : f (l.map Pair.observed) ≠ f (l.map Pair.predicted)) :
    fullyConfounded l = false := by
  -- `by_contra` is a mathlib tactic and this tree is core-only, so the case
  -- split is done on the Bool itself. The `true` branch is exactly the
  -- separation theorem, which contradicts `h`.
  cases hc : fullyConfounded l with
  | false => rfl
  | true => exact absurd (no_statistic_can_separate_them f l hc) h

/-! ## The measured control -/

/-- Comparable A/B pairs, and how many of them agreed with the confound.
Measured 2026-08-12 by `bench/p24-aa-control.js`. -/
def haystackProbe : Nat × Nat := (79, 79)

/-- **The confound rate was exactly 1: every comparable pair agreed.** -/
theorem the_confound_explained_every_pair :
    haystackProbe.1 = haystackProbe.2 ∧ 0 < haystackProbe.1 := by decide

/-- The A/A control on O4 itself: the same arm, both orderings. -/
def aaRoutedO4 : NullControl.Comparison := ⟨32, 26⟩
/-- The unrouted arm against itself. -/
def aaUnroutedO4 : NullControl.Comparison := ⟨15, 3⟩

/-- **O4 moves on most tasks between two runs of the SAME arm.** 32 of the 40
tasks are discordant with no routing difference whatever, which is what an
observable reading something other than the arm looks like. -/
theorem o4_is_unstable_within_a_single_arm :
    32 ≤ aaRoutedO4.discordant ∧ 0 < aaUnroutedO4.discordant := by decide

/-- The A/A control that was actually cited in `RotP24Run` came from the R4
answer-text scorer, and it is recorded here to make the mismatch explicit
rather than to reuse it. Its own numbers are fine; they were simply about
something else. -/
def r4AnswerTextControl : NullControl.Comparison := ⟨6, 2⟩

/-- **The cited control and the needed control are different measurements.**
This is the whole defect in one `decide`: had they been the same object, the
attribution would have been sound. -/
theorem the_cited_control_was_not_the_needed_one :
    r4AnswerTextControl ≠ aaRoutedO4 := by decide

/-! ## What the retraction leaves standing -/

/-- **The O4 verdict is withdrawn, and NOT replaced by a claim for the router.**
Both directions are unestablished: the sign sequence is fully explained by the
confound, so it supports neither the preregistered direction nor its negation.
The two conjuncts are deliberately symmetric — a retraction that quietly became
a win would be the same overclaim wearing the other coat. -/
theorem o4_establishes_neither_direction :
    (haystackProbe.1 = haystackProbe.2) ∧
    (RotMoE.P24Run.o4Forward.favouring = 0 ∧
     RotMoE.P24Run.o4Reverse.favouring = 0) := by decide

/-- **P2.4 as run produced no admissible evidence about work quality.** Three
observables were saturated (`RotP24Run.three_of_four_observables_are_saturated`)
and the fourth is confounded at rate 1. This is the honest summary line, and it
is weaker than both the earlier CONTRADICTED and any claim of success. -/
theorem p24_produced_no_admissible_evidence :
    (RotMoE.P24Run.o1Forward.discordant = 0 ∧
     RotMoE.P24Run.o2Forward.discordant = 0 ∧
     RotMoE.P24Run.o3Forward.discordant = 0) ∧
    haystackProbe.1 = haystackProbe.2 := by decide

/-- The instrument defect is a defect of THIS detector, not of process
observables in general. Stated so the next corpus is not talked out of trying:
a detector whose pairs disagree with the confound is not caught by
`no_statistic_can_separate_them`, and a witness is exhibited to prove that the
guard is not vacuous. -/
theorem a_detector_can_escape_the_confound :
    fullyConfounded [⟨true, false⟩] = false := by decide

end RotMoE.P24Control
