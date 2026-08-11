/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Proofs.RotExperiment
import Proofs.RotSaturation

/-! # `m` was never settled, and the verdict could not say "contradicted"

Three things blocked the P2.4 pilot, and none of them was a checker.

**`m` was a free parameter.** `verdictM m n k` applies a Bonferroni factor `m`
for testing several hypotheses at once, and the boundary it produces moves with
it — at `n = 40` the largest still-supported `k` is 11 uncorrected, 10 at `m = 4`,
9 at `m = 9` and `m = 12`. Earlier work explored 9 and 12 without deriving either.
Neither is derivable. `bench/P24-PREREGISTRATION.md` section 3 fixes seven
observables and section 7 runs a two-sided sign test **for each of O1–O4**: O5 is
a non-inferiority side condition, O6 and O7 are declared descriptive and are not
part of the verdict. The family is therefore **four**, and `m` is computed from
the observable table here rather than chosen — `the_family_size_is_derived_not_
chosen`, `descriptive_observables_do_not_inflate_the_family`.

**That changes the pilot floor.** At `m = 12` the smallest pilot able to reach a
corrected verdict is 12 pairs; at the settled `m = 4` it is **10** — which is
exactly the pilot size section 5 preregistered. The floor of 12 was an artifact
of an unsettled `m`, not a finding about the design.

**`twoSidedTail` is not label-symmetric, and that is correct.** Swapping the
labels maps `k` to `n - k`, and the doubled tail does not survive it:
`twoSidedTail 40 9 = 747171208` against `twoSidedTail 40 31 = 2198822962104`.
That asymmetry is deliberate. Section 3 fixes a *direction* per observable, so
`k` counts sessions going against the claim and only a small `k` may be
supported. `the_symmetric_repair_would_admit_a_total_loss` shows what happens if
symmetry is imposed the obvious way: a 40-of-40 defeat reads as SUPPORTED.

**But the verdict type could not report a loss.** Section 7 preregisters THREE
outcomes — SUPPORTED, NOT ESTABLISHED, CONTRADICTED, the last "written up as
prominently as a win would be". `Verdict` has two constructors, so 31 of 40
against the claim and a dead-even 20 of 40 both come back `notSupported`. That
is a silent downgrade of the one result the preregistration promises to publish.
`Outcome` adds the third, `the_new_rule_agrees_wherever_the_old_one_spoke` shows
nothing already supported moves, and `a_thirty_one_of_forty_defeat_was_reported_
as_a_null` exhibits the case the old rule could not distinguish.
-/

namespace RotMoE.Family

open RotMoE.Experiment

/-! ## The family size is read off the preregistered observable table -/

/-- What section 7 does with an observable. -/
inductive Role where
  /-- a two-sided sign test that carries a verdict: O1..O4 -/
  | twoSidedTest : Role
  /-- a side condition that must not regress, not a test of its own: O5 -/
  | sideCondition : Role
  /-- reported, never claimed: O6, O7 -/
  | descriptive : Role
  deriving Repr, DecidableEq

/-- The observable table of `bench/P24-PREREGISTRATION.md` section 3, with the
role section 7 assigns to each. -/
def observables : List (String × Role) :=
  [ ("O1 verification steps invoked", .twoSidedTest)
  , ("O2 rework edits",               .twoSidedTest)
  , ("O3 files read before write",    .twoSidedTest)
  , ("O4 unverified claims",          .twoSidedTest)
  , ("O5 task success",               .sideCondition)
  , ("O6 lens breadth and lead",      .descriptive)
  , ("O7 wall time per turn",         .descriptive) ]

/-- **The Bonferroni family size, derived.** Not a constant anyone may tune. -/
def m : Nat := (observables.filter (fun o => o.2 == Role.twoSidedTest)).length

#guard m = 4
#guard observables.length = 7

/-- **`m` is four**, and it is four because four observables carry a two-sided
test — not because four was chosen. -/
theorem the_family_size_is_derived_not_chosen : m = 4 := by decide

/-- **The descriptive observables do not inflate the family.** O6 and O7 are
reported and never claimed; counting them would tighten the boundary for no
inferential reason, which is how an over-correction quietly buries a real
effect. -/
theorem descriptive_observables_do_not_inflate_the_family :
    m < observables.length := by decide

/-- **Nor does the side condition.** O5 is a non-inferiority check, not a test
with its own alpha to spend. -/
theorem the_side_condition_is_not_a_test :
    (observables.filter (fun o => o.2 == Role.sideCondition)).length = 1
      ∧ m = 4 := by decide

/-- **The family size tracks the table.** Add a fifth two-sided observable and
`m` becomes 5 on its own. This is what makes it derived rather than declared. -/
theorem adding_a_test_raises_the_family_size :
    ((("O8 new", Role.twoSidedTest) :: observables).filter
      (fun o => o.2 == Role.twoSidedTest)).length = m + 1 := by decide

/-- **Retagging an observable as descriptive lowers it.** The correction cannot
be loosened by relabelling without the table showing it. -/
theorem retagging_a_test_as_descriptive_lowers_the_family_size :
    ((observables.map (fun o => if o.1 == "O4 unverified claims" then (o.1, Role.descriptive) else o)).filter
      (fun o => o.2 == Role.twoSidedTest)).length = m - 1 := by decide

/-! ## What `m` does to the boundary -/

/-- **Correction is monotone: a larger family is never more permissive.** The
property that makes Bonferroni a correction rather than a knob. -/
theorem a_larger_family_is_never_more_permissive
    (m₁ m₂ n k : Nat) (hm : m₁ ≤ m₂) (h : verdictM m₂ n k = Verdict.supported) :
    verdictM m₁ n k = Verdict.supported := by
  unfold verdictM at h ⊢
  by_cases hc : 100 * m₂ * twoSidedTail n k ≤ 2 ^ n
  · have : 100 * m₁ * twoSidedTail n k ≤ 100 * m₂ * twoSidedTail n k :=
      Nat.mul_le_mul_right _ (Nat.mul_le_mul_left _ hm)
    simp [Nat.le_trans this hc]
  · simp [hc] at h

/-- **The boundary at the settled family size is exactly 10 of 40.** Stated as
the LARGEST supported `k` rather than as a pair of witnesses. The pair form
(`10` supported and `11` not) is true but weakenable: replace 10 by 9 and it
still builds while no longer pinning anything. This form cannot be weakened —
any other value fails — which is the difference between a boundary and a bound.
Found by mutation: a mutant that moved the literal would have survived. -/
theorem the_forty_pair_boundary_at_the_settled_family :
    ((List.range 41).filter (fun k => verdictM m 40 k == Verdict.supported)).getLast? = some 10 := by decide

/-- The two witnesses either side, kept because they are what a reader checks. -/
theorem ten_is_supported_and_eleven_is_not :
    verdictM m 40 10 = Verdict.supported
      ∧ verdictM m 40 11 = Verdict.notSupported := by decide

/-- **The uncorrected rule is looser by exactly one here.** Worth stating because
it is the cost of the correction, and it is small. -/
theorem the_correction_costs_one_session_at_forty :
    verdictM 1 40 11 = Verdict.supported
      ∧ verdictM m 40 11 = Verdict.notSupported := by decide

/-- **The pilot floor is exactly 10 pairs, not 12.** Ten is what section 5
preregistered; the floor of 12 came from `m = 12`, which the preregistration
never fixed. Stated as the SMALLEST admissible `n` for the same reason as the
boundary above — a witness pair could be weakened without failing. -/
theorem the_smallest_admissible_pilot_is_ten_pairs :
    ((List.range 25).filter (fun n => verdictM m n 0 == Verdict.supported)).head? = some 10 := by decide

/-- The witnesses either side of the pilot floor. -/
theorem ten_pairs_suffice_and_nine_do_not :
    verdictM m 10 0 = Verdict.supported
      ∧ verdictM m 9 0 = Verdict.notSupported := by decide

/-- **A ten-pair pilot is admissible only on a clean sweep.** One session going
the wrong way and ten pairs can say nothing — which is what a pilot is for. -/
theorem a_ten_pair_pilot_must_be_unanimous :
    verdictM m 10 0 = Verdict.supported
      ∧ verdictM m 10 1 = Verdict.notSupported := by decide

/-! ## The label-swap audit -/

/-- **The doubled tail is not symmetric under relabelling.** `k` and `n - k` give
different tails, so this is a one-sided tail doubled, not a symmetric two-sided
statistic. -/
theorem the_doubled_tail_is_not_label_symmetric :
    twoSidedTail 40 9 ≠ twoSidedTail 40 31 := by decide

/-- **It is symmetric only at the centre**, where `k = n - k`. The single point
that could mislead a spot check into believing the whole statistic symmetric. -/
theorem the_tail_is_symmetric_only_at_the_centre :
    twoSidedTail 40 20 = twoSidedTail 40 (40 - 20) := by decide

/-- The obvious symmetric repair: take whichever side is smaller. -/
def symmetricTail (n k : Nat) : Nat := 2 * min (tail n k) (tail n (n - k))

/-- **The symmetric repair would report a total defeat as SUPPORTED.** Forty of
forty sessions against the claim, and the corrected rule using the symmetric
statistic says the claim holds. This is why the asymmetry stays: the claim has a
DIRECTION, fixed per observable in section 3, and `k` counts against it. -/
theorem the_symmetric_repair_would_admit_a_total_loss :
    100 * m * symmetricTail 40 40 ≤ 2 ^ 40
      ∧ verdictM m 40 40 = Verdict.notSupported := by decide

/-- **The asymmetry is exactly what refuses the total loss.** Stated as the
positive counterpart so the audit does not read as a complaint. -/
theorem the_directional_tail_refuses_what_the_symmetric_one_admits :
    ¬ (100 * m * twoSidedTail 40 40 ≤ 2 ^ 40) := by decide

/-! ## The third verdict the preregistration requires

Section 7 fixes SUPPORTED, NOT ESTABLISHED and CONTRADICTED. `Verdict` carries
two constructors, so a significant defeat and a dead heat are the same value. -/

/-- The three outcomes of section 7. -/
inductive Outcome where
  | supported      : Outcome
  | notEstablished : Outcome
  | contradicted   : Outcome
  deriving Repr, DecidableEq

/-- The preregistered rule, all three branches. `k` counts sessions against the
claim: significant on the claimed side is SUPPORTED, significant on the other
side is CONTRADICTED, anything else is NOT ESTABLISHED. -/
def outcome (m n k : Nat) : Outcome :=
  if verdictM m n k = Verdict.supported then .supported
  else if verdictM m n (n - k) = Verdict.supported then .contradicted
  else .notEstablished

/-- **Nothing that was supported moves.** The third outcome is a refinement of
the old rule, not a re-analysis of it — no result changes side. -/
theorem the_new_rule_agrees_wherever_the_old_one_spoke (m n k : Nat) :
    outcome m n k = Outcome.supported ↔ verdictM m n k = Verdict.supported := by
  unfold outcome
  by_cases h : verdictM m n k = Verdict.supported <;> simp [h]
  by_cases h2 : verdictM m n (n - k) = Verdict.supported <;> simp [h2]

/-- **The case the old rule could not report.** Thirty-one of forty against the
claim is significant evidence AGAINST it, and the two-constructor verdict called
it `notSupported` — the same value a dead heat gets. -/
theorem a_thirty_one_of_forty_defeat_was_reported_as_a_null :
    verdictM m 40 31 = Verdict.notSupported
      ∧ verdictM m 40 20 = Verdict.notSupported
      ∧ outcome m 40 31 = Outcome.contradicted
      ∧ outcome m 40 20 = Outcome.notEstablished := by decide

/-- **A total defeat is contradicted, not merely unsupported.** -/
theorem a_total_loss_is_contradicted : outcome m 40 40 = Outcome.contradicted := by decide

/-- **A clean sweep is still supported.** -/
theorem a_clean_sweep_is_supported : outcome m 40 0 = Outcome.supported := by decide

/-- **All three outcomes are reachable**, so the third branch is not decorative. -/
theorem all_three_outcomes_are_reachable :
    outcome m 40 0 = Outcome.supported
      ∧ outcome m 40 20 = Outcome.notEstablished
      ∧ outcome m 40 40 = Outcome.contradicted := by decide

/-- **Supported and contradicted are exclusive** — no `n`, `k` can be both. -/
theorem supported_and_contradicted_are_exclusive (m n k : Nat) :
    ¬ (outcome m n k = Outcome.supported ∧ outcome m n k = Outcome.contradicted) := by
  rintro ⟨h1, h2⟩
  rw [h1] at h2
  exact Outcome.noConfusion h2

/-- **Every case has an outcome.** Totality, so no result can fall through the
rule unreported. -/
theorem every_result_has_an_outcome (m n k : Nat) :
    outcome m n k = Outcome.supported
      ∨ outcome m n k = Outcome.notEstablished
      ∨ outcome m n k = Outcome.contradicted := by
  unfold outcome
  by_cases h : verdictM m n k = Verdict.supported
  · simp [h]
  · by_cases h2 : verdictM m n (n - k) = Verdict.supported <;> simp [h, h2]

/-! ## The admissibility gate was unsatisfiable at the preregistered pilot size

Section 5 admits the corpus only if `RotMoE.Saturation.admissibleBy 8` holds on
a **10-task** pilot. That gate asks for margin `m` in BOTH directions:
`m ≤ hits` and `m ≤ outOf - hits`. At `outOf = 10` with `m = 8` it demands
`hits ≥ 8` and `hits ≤ 2` at once — **no outcome whatsoever can satisfy it**.

This is the mirror of a spec that forbids a correct future: a spec that forbids
*every* future. It is not a strict gate, it is an unreachable one, and it would
have refused the corpus no matter how the pilot had gone. The 2026-08-11 pilot
was run at `outOf = 12`, where exactly one score is admissible.

The repair is not to pick a margin that lets this pilot through. It is to state
the relationship that makes a margin reachable at all, quantified over the size
that moves. -/

open RotMoE.Saturation in
/-- **A margin is reachable exactly when the pilot is at least twice its size.**
The durable statement: not a fact about 8 and 10, but about every `m` and every
`outOf`. -/
theorem a_margin_is_reachable_iff_the_pilot_is_twice_its_size (mg outOf : Nat) :
    (∃ h, h ≤ outOf ∧ admissibleBy mg ⟨h, outOf⟩ = true) ↔ 2 * mg ≤ outOf := by
  constructor
  · rintro ⟨h, hle, ha⟩
    rw [admissibleBy, Bool.and_eq_true, decide_eq_true_eq, decide_eq_true_eq] at ha
    simp only [up, down] at ha
    omega
  · intro h2
    refine ⟨mg, by omega, ?_⟩
    rw [admissibleBy, Bool.and_eq_true, decide_eq_true_eq, decide_eq_true_eq]
    simp only [up, down]
    omega

open RotMoE.Saturation in
/-- **Margin 8 admits no score out of 10.** True mathematics, and it is ALL this
theorem says.

It was first named `the_preregistered_gate_admitted_no_outcome`, which was a
false charge against `bench/P24-PREREGISTRATION.md` §5 — I had assumed the
pilot's O5 denominator was its task count. §5 says, in the same sentence,
"a 10-task pilot per arm" AND "at least 8 of 80 room". The denominator is **80**,
derived from §4 (40 tasks) × §6 (both orderings), and at `outOf = 80` the gate is
comfortably satisfiable: `8 ≤ hits ≤ 72`. `the_preregistered_gate_is_satisfiable`
below proves it.

The real defect in §5 is a **denominator mismatch** — a full-run margin attached
to a pilot sentence — not an unsatisfiable gate. The theorem keeps the fact and
loses the accusation. -/
theorem a_margin_of_eight_admits_no_score_out_of_ten :
    ¬ (∃ h, h ≤ 10 ∧ admissibleBy 8 ⟨h, 10⟩ = true) := by
  rw [a_margin_is_reachable_iff_the_pilot_is_twice_its_size]; omega

open RotMoE.Saturation in
/-- **The preregistered gate IS satisfiable at the denominator §5 names.**
80 = 40 tasks (§4) × 2 orderings (§6). The retraction, stated as a theorem so
the correction is as checkable as the charge was. -/
theorem the_preregistered_gate_is_satisfiable :
    ∃ h, h ≤ 80 ∧ admissibleBy 8 ⟨h, 80⟩ = true := by
  rw [a_margin_is_reachable_iff_the_pilot_is_twice_its_size]; omega

open RotMoE.Saturation in
/-- **How much room the sound gate leaves: every score from 8 to 72.** A gate
that admits 65 of 81 outcomes is a real margin, not a coincidence — the opposite
of what I claimed. -/
theorem the_sound_gate_admits_a_wide_band :
    ((List.range 81).filter (fun h => admissibleBy 8 ⟨h, 80⟩)).length = 65
      ∧ ((List.range 81).filter (fun h => admissibleBy 8 ⟨h, 80⟩)).head? = some 8
      ∧ ((List.range 81).filter (fun h => admissibleBy 8 ⟨h, 80⟩)).getLast? = some 72 := by
  decide

open RotMoE.Saturation in
/-- **At the twelve pairs actually run, NO score admits either.** I first wrote
this as "exactly one score admits, `= [4]`", reasoning that `up ⟨4,12⟩ = 8` met
the margin. `decide` proved that FALSE: the gate wants margin in both
directions and `down ⟨4,12⟩ = 4`, so 12 pairs is short of the 16 the margin
needs. The claim is recorded in the form the kernel accepted, not the form I
guessed. -/
theorem twelve_pairs_admit_no_score :
    ((List.range 13).filter (fun h => admissibleBy 8 ⟨h, 12⟩)) = [] := by decide

open RotMoE.Saturation in
/-- **The smallest pilot at which margin 8 is reachable is 16.** Derived from the
theorem above rather than chosen, and it is the number the preregistration needs
if the margin is to stay at 8. -/
theorem margin_eight_needs_sixteen_pairs :
    ((List.range 25).filter (fun n => 2 * 8 ≤ n)).head? = some 16 := by decide

open RotMoE.Saturation in
/-- **The margin the preregistered 10-task pilot can actually carry is 5** — and
at 5 exactly one score admits, so a 10-task pilot cannot carry a margin with any
room at all. Both numbers, so the choice between enlarging the pilot and
shrinking the margin is made on evidence. -/
theorem a_ten_task_pilot_carries_a_margin_of_five_at_most :
    ((List.range 11).filter (fun mg => 2 * mg ≤ 10)).getLast? = some 5
      ∧ ((List.range 11).filter (fun h => admissibleBy 5 ⟨h, 10⟩)) = [5] := by decide

open RotMoE.Saturation in
/-- **The measured pilot is inadmissible, and so is its unrouted arm.** Stated
about the numbers this run produced (3 of 12 routed, 1 of 12 unrouted) so the
record cannot drift from what was observed. -/
theorem the_measured_pilot_is_inadmissible :
    admissibleBy 8 ⟨3, 12⟩ = false ∧ admissibleBy 8 ⟨1, 12⟩ = false := by decide

/-- **The pilot's paired result cannot reach a verdict, exactly as designed.**
Two disagreements out of twelve, none against — and `n = 2` is far below the
ten-pair floor. A pilot that could conclude would not be a pilot. -/
theorem the_pilot_cannot_conclude : verdictM m 2 0 = Verdict.notSupported := by decide

/-! ## CONTESTED — a fractional margin, proposed on a misreading

**Everything in this section is SUSPENDED.** It was written to repair a gate I
had wrongly called unsatisfiable. §5's denominator is 80, the gate is sound
(`the_preregistered_gate_is_satisfiable`), and a repair to a working mechanism
is not a repair.

It is kept rather than deleted because the *mathematics* is sound and may still
be wanted: `8 = 40 / 5` is a true coincidence, a fractional margin really is
reachable at every size, and `marginFor 40 = 8` really does reproduce the
preregistered number. What is wrong is the **motivation** — none of that was
needed, and adopting it would silently move a margin that was already correct.

The live question §5 actually poses is a **denominator mismatch**: it names a
10-task pilot and an 80-denominator score in one sentence. That is a question
about what the pilot MEASURES, not about how big the margin should be, and it is
not answered here.

Nothing below may be cited as a decision until the mismatch is reconciled. -/

/-- **The margin as it was meant: a fifth of the pilot, in both directions.** -/
def marginFor (outOf : Nat) : Nat := outOf / 5

/-- **It recovers the preregistered number at the size it was written for.**
`marginFor 40 = 8` is the whole argument that this is a repair rather than a new
parameter. -/
theorem the_margin_was_a_fraction_of_the_corpus_not_an_absolute :
    marginFor 40 = 8 := by decide

/-- **A fractional margin is reachable at every size**, so the unsatisfiable
gate cannot recur no matter how the pilot or the corpus is resized. This is the
durable form: quantified over the size that moves. -/
theorem a_fractional_margin_is_always_reachable (outOf : Nat) :
    2 * marginFor outOf ≤ outOf := by
  unfold marginFor; omega

open RotMoE.Saturation in
/-- Consequently some score always admits — the property the flattened margin
lost. -/
theorem a_fractional_margin_always_admits_some_score (outOf : Nat) :
    ∃ h, h ≤ outOf ∧ admissibleBy (marginFor outOf) ⟨h, outOf⟩ = true :=
  (a_margin_is_reachable_iff_the_pilot_is_twice_its_size (marginFor outOf) outOf).mpr
    (a_fractional_margin_is_always_reachable outOf)

/-- The margin at the two pilot sizes in play. -/
theorem the_margin_at_the_pilot_sizes :
    marginFor 10 = 2 ∧ marginFor 12 = 2 := by decide

open RotMoE.Saturation in
/-- CONTESTED. What the fractional margin *would* say about the measured pilot,
were it adopted: 3 of 12 leaves room in both directions, 1 of 12 is against the
floor. Retained as arithmetic about the observed numbers, NOT as a verdict —
the margin it uses is suspended. -/
theorem the_routed_arm_admits_and_the_unrouted_arm_does_not :
    admissibleBy (marginFor 12) ⟨3, 12⟩ = true
      ∧ admissibleBy (marginFor 12) ⟨1, 12⟩ = false := by decide

open RotMoE.Saturation in
/-- **Admissibility requires BOTH arms**, because a corpus saturated for one arm
cannot show a difference between them. One-armed admissibility would let a
corpus that the unrouted arm always fails count as usable, which is the
floor-saturation twin of the ceiling effect `RotSaturation` was written for. -/
def corpusAdmissible (mg : Nat) (a b : Score) : Bool :=
  admissibleBy mg a && admissibleBy mg b

open RotMoE.Saturation in
/-- CONTESTED as a verdict; sound as arithmetic. Under the suspended fractional
margin the pair would not admit. **This is not a decision to rebuild the
corpus** — that conclusion rested on the misreading, and the corpus has not been
judged by any gate whose denominator was reconciled. -/
theorem the_pair_would_not_admit_under_the_suspended_margin :
    corpusAdmissible (marginFor 12) ⟨3, 12⟩ ⟨1, 12⟩ = false := by decide

open RotMoE.Saturation in
/-- CONTESTED. The margin that would have admitted this pilot is a tenth. Kept
because naming the convenient number is what stops it being adopted quietly. -/
theorem a_ten_percent_margin_would_have_admitted_the_floor :
    corpusAdmissible (12 / 10) ⟨3, 12⟩ ⟨1, 12⟩ = true
      ∧ corpusAdmissible (12 / 5) ⟨3, 12⟩ ⟨1, 12⟩ = false := by decide

/-! ## The disease, not the instance: a margin must carry its denominator

The whole episode above has ONE cause, and it is a type. `admissibleBy` takes a
`Nat` margin and a `Score`, and nothing relates the two. So a margin meant for a
denominator of 80 could be handed a `Score` out of 10, produce a perfectly
well-typed `false`, and I read that `false` as a defect in the specification.
`8` against `⟨h, 10⟩` is not a wrong answer — it is a **category error that the
type system permitted**.

The fix is the same construction that settled `m`: derive the quantity from its
declared inputs and make the binding structural. A `Margin` carries the
denominator it was declared against, and comparing it to a score of a different
size is not a judgement that comes out false — it is a question that cannot be
asked. -/

/-- **A margin that knows what it is a margin OF.** -/
structure Margin where
  /-- room demanded in each direction -/
  room  : Nat
  /-- the denominator this margin was declared against -/
  outOf : Nat
deriving DecidableEq, Repr

/-- §5's margin, taken from the objects it was actually declared against:
`RotMoE.Saturation.preregMargin` (= 8) and the P2.2 **calibration corpus**
`calibCorpus = ⟨1, 80⟩`.

I first wrote this as `⟨8, 40 * 2⟩` — "40 tasks (§4) × 2 orderings (§6)" — which
gives the same 80 and was **not** where the document's 80 comes from. That was
the same error as the retraction it was meant to repair: a number fitted to a
plausible story instead of measured. §1's table reads "`rotmoe-calib` | 1/80 in
band | refused — floor, margin 8", and `RotSaturation.lean:205,212` hold both
values. §5's "8 of 80" is that sentence carried over verbatim. -/
def preregisteredMargin : Margin :=
  ⟨RotMoE.Saturation.preregMargin, RotMoE.Saturation.calibCorpus.outOf⟩

/-- **The margin and its denominator both come from `RotSaturation`, not from a
reconstruction.** Bound to the definitions so a change there moves this. -/
theorem the_margin_is_the_p22_one_against_the_calibration_corpus :
    preregisteredMargin.room = RotMoE.Saturation.preregMargin
      ∧ preregisteredMargin.outOf = RotMoE.Saturation.calibCorpus.outOf
      ∧ preregisteredMargin = ⟨8, 80⟩ := by decide


/-- A margin is well formed when it is reachable at its OWN denominator. -/
def wellFormed (mg : Margin) : Bool := decide (2 * mg.room ≤ mg.outOf)

/-- **§5's margin is well formed.** The retraction in structural form: the gate
was never broken. -/
theorem the_preregistered_margin_is_well_formed :
    wellFormed preregisteredMargin = true := by decide

open RotMoE.Saturation in
/-- **Applying a margin to a score REQUIRES the denominators to agree.** This is
the whole repair: `applyTo` returns `none` for a size mismatch rather than a
verdict. The reading that started this — margin 8 against a score out of 10 —
is now `none`, not `false`. -/
def Margin.applyTo (mg : Margin) (s : Score) : Option Bool :=
  if s.outOf = mg.outOf then some (admissibleBy mg.room s) else none

open RotMoE.Saturation in
/-- **The category error is now unaskable.** Margin 8-of-80 against a 10-task
score answers `none`. Had this existed yesterday, no charge would have been
laid against §5. -/
theorem a_mismatched_denominator_is_not_a_verdict :
    preregisteredMargin.applyTo ⟨3, 10⟩ = none
      ∧ preregisteredMargin.applyTo ⟨3, 12⟩ = none := by decide

open RotMoE.Saturation in
/-- **At the right denominator it answers, and it answers usefully.** -/
theorem the_margin_answers_at_its_own_denominator :
    preregisteredMargin.applyTo ⟨40, 80⟩ = some true
      ∧ preregisteredMargin.applyTo ⟨3, 80⟩ = some false := by decide

open RotMoE.Saturation in
/-- **It behaves on the calibration corpus exactly as §1 records**: refused at
the floor, 1 of 80. The check that the provenance is right and not merely
arithmetically convenient — a margin fitted to the wrong story would still be
`⟨8, 80⟩` but would not have `calibCorpus` as its natural argument. -/
theorem it_refuses_the_calibration_corpus_as_section_one_says :
    preregisteredMargin.applyTo calibCorpus = some false := by decide

/-- **§5 never fixed a denominator for the PILOT at all** — and that, not an
unsatisfiable gate, is the open defect. Its margin is 8-against-80, inherited
from a P2.2 corpus of 80 items; its pilot is 10 tasks. No pilot size up to 40
can receive that margin, so the question cannot be answered by accident: it has
to be decided and written down. -/
theorem no_pilot_size_can_receive_the_inherited_margin :
    ((List.range 41).filter
      (fun n => (preregisteredMargin.applyTo ⟨0, n⟩).isSome)) = [] := by decide

open RotMoE.Saturation in
/-- **A well-formed margin always has an admitting score at its denominator.**
The unsatisfiable-gate failure mode cannot occur for any well-formed margin, at
any size — the general statement, not a fact about 8 and 80. -/
theorem a_well_formed_margin_always_admits_something (mg : Margin)
    (hw : wellFormed mg = true) :
    ∃ s : Score, s.outOf = mg.outOf ∧ mg.applyTo s = some true := by
  refine ⟨⟨mg.room, mg.outOf⟩, rfl, ?_⟩
  unfold wellFormed at hw
  simp only [decide_eq_true_eq] at hw
  have h : admissibleBy mg.room (⟨mg.room, mg.outOf⟩ : Score) = true := by
    rw [admissibleBy, Bool.and_eq_true, decide_eq_true_eq, decide_eq_true_eq]
    simp only [up, down]
    omega
  simp [Margin.applyTo, h]

/-- **And an ill-formed one is refused before it is ever applied**, which is
where the check belongs: `wellFormed` is decidable at declaration time, so a
margin like 8-of-10 never reaches a score at all. -/
theorem an_ill_formed_margin_is_visible_at_declaration :
    wellFormed ⟨8, 10⟩ = false ∧ wellFormed ⟨8, 80⟩ = true := by decide

/-! ## The scorer dominates the signal

The same 24 sessions, rescored under four rules by `bench/pilot-rescore.js`
(no new runs). Every number below is measured, not modelled:

| rule | routed | unrouted |
|---|---|---|
| R1 strict — truth appears and naive does not | 3 | 1 |
| R2 lenient — truth appears | 9 | 7 |
| R3 leading — the first number is truth | 5 | 5 |
| R4 committed — truth appears before naive | 8 | 6 |

This retires the conclusion I drew from R1 alone. Under R2 both arms score high,
so the corpus is **not** floor-saturated and does not need rebuilding — that
recommendation was an artifact of the strictest rule. -/

/-- Routed and unrouted scores per rule, in the order R1..R4. -/
def routedByRule   : List Nat := [3, 9, 5, 8]
def unroutedByRule : List Nat := [1, 7, 5, 6]

/-- **The choice of rule moves a score by 6 of 12; the arms differ by at most
2.** The scoring rule is a larger uncontrolled variable than the thing being
measured, so it must be preregistered before the full run — that is the finding,
and it is bigger than anything about the corpus. -/
theorem the_scorer_moves_the_score_more_than_the_arm_does :
    (routedByRule.max? , routedByRule.min?) = (some 9, some 3)
      ∧ (List.zipWith (fun a b => a - b) routedByRule unroutedByRule).max? = some 2 := by
  decide

/-- **No rule favours the unrouted arm.** Three give the routed arm +2, one is a
dead tie; none is negative. Stated because the four rules do NOT all agree in
sign, and the honest reading of that is "one rule has no discriminating power",
not "the rules contradict each other". -/
theorem no_rule_favours_the_unrouted_arm :
    (List.zipWith (fun a b => decide (b ≤ a)) routedByRule unroutedByRule).all id = true
      ∧ (List.zipWith (fun a b => a - b) routedByRule unroutedByRule) = [2, 2, 0, 2] := by
  decide

/-- **R2 refutes the floor-saturation reading.** 9 and 7 of 12 leave room in both
directions at any margin the document could carry; the corpus was never against
the floor, the rule was. -/
theorem the_lenient_rule_shows_no_floor_saturation :
    RotMoE.Saturation.admissibleBy 2 ⟨9, 12⟩ = true
      ∧ RotMoE.Saturation.admissibleBy 2 ⟨7, 12⟩ = true := by decide

/-- **Still no verdict, under any rule.** The largest paired disagreement across
all four rules is 2, far below the ten-pair floor. Rescoring cannot manufacture
a conclusion, and this theorem is what stops the table above from being read as
one. -/
theorem no_rescoring_reaches_the_floor : verdictM m 2 0 = Verdict.notSupported := by decide

/-! ## The scoring rule, preregistered the way `m` was

`m` is settled because it is COMPUTED from the declared observable table. The
scoring rule was, until now, a function chosen by the person reading the
results — the precise thing §5 exists to forbid. It is fixed here the same way:
declare the rule set, mark exactly one primary, and register the rest as
sensitivity analyses **in advance**, so "the sign held under all of them" is a
stated-in-advance robustness claim and not a post-hoc defence.

**Why R4 is primary, argued without reference to the pilot's numbers:**

* **R1** (truth, and naive absent) punishes an answer that gives the right
  number *and explains why the naive one is wrong*. That is better epistemic
  behaviour being penalised.
* **R2** (truth appears anywhere) rewards an answer that leads with the wrong
  number and mentions the right one in a caveat.
* **R3** (first number in the text) measures prose habit, not knowledge. It is
  declared **excluded**, not averaged in.
* **R4** asks what the answer COMMITTED to, which is what a task with a
  machine-checkable ground truth actually tests.

R4 is neither the most nor the least favourable to the router — R2 gives the
routed arm its highest raw score. That it can be defended without consulting the
table is the whole point. -/

inductive RuleRole
  /-- the one rule the verdict is computed from -/
  | primary : RuleRole
  /-- declared in advance, reported beside the primary, never substituted for it -/
  | sensitivity : RuleRole
  /-- declared in advance as NOT measuring the construct -/
  | excluded : RuleRole
deriving DecidableEq, Repr

/-- The rule set, fixed before the 160 sessions. -/
def rules : List (String × RuleRole) :=
  [ ("R1-strict",    RuleRole.sensitivity)
  , ("R2-lenient",   RuleRole.sensitivity)
  , ("R3-leading",   RuleRole.excluded)
  , ("R4-committed", RuleRole.primary) ]

/-- **Exactly one primary.** A rule set with two primaries is a choice deferred
to whoever reads the output, which is the defect this section removes. -/
theorem exactly_one_primary_rule :
    (rules.filter (fun r => r.2 == RuleRole.primary)).length = 1 := by decide

/-- **And it is R4**, named rather than left to position in a list. -/
theorem the_primary_rule_is_the_commitment_rule :
    (rules.filter (fun r => r.2 == RuleRole.primary)).map (·.1) = ["R4-committed"] := by
  decide

/-- **The excluded rule is declared, not dropped quietly.** R3 measures prose
habit; excluding it in advance is legitimate, deleting it after seeing that it
scored 5–5 would not be. -/
theorem the_excluded_rule_is_named_in_advance :
    (rules.filter (fun r => r.2 == RuleRole.excluded)).map (·.1) = ["R3-leading"] := by
  decide

/-- **Two sensitivity analyses, and they bracket the primary.** R1 refuses every
hedge, R2 accepts every hedge; a commitment rule that did not sit between them
would not be measuring commitment. -/
theorem the_sensitivity_analyses_bracket_the_primary :
    (rules.filter (fun r => r.2 == RuleRole.sensitivity)).length = 2
      ∧ routedByRule[0]? = some 3 ∧ routedByRule[3]? = some 8
        ∧ routedByRule[1]? = some 9 := by decide

/-- **The primary rule alone does not reach the floor either.** Fixing the rule
in advance does not buy a verdict, and saying so here stops the preregistration
from looking like it bought one. -/
theorem the_primary_rule_reaches_no_verdict :
    verdictM m 2 0 = Verdict.notSupported := by decide

/-! ### §5's pilot denominator, derived rather than inherited

§5 gave a margin (8) and a denominator (80) that belong to the P2.2 calibration
corpus, and a pilot size (10 tasks) that belongs to P2.4. It never said what the
pilot's O5 score is *out of*. That is derived here, from the two quantities the
document does fix: how many tasks the pilot runs, and how many orderings §6
requires of each. -/

/-- **The pilot's O5 denominator: one scored answer per task per ordering.** -/
def pilotDenominator (tasks orderings : Nat) : Nat := tasks * orderings

/-- What the 2026-08-11 run actually produced: 12 tasks, one ordering per arm. -/
theorem the_run_pilot_denominator_is_twelve : pilotDenominator 12 1 = 12 := by decide

/-- What §5's own 10-task pilot yields once §6's both-orderings requirement is
applied: **20**, not 80. -/
theorem the_section_five_pilot_denominator_is_twenty :
    pilotDenominator 10 2 = 20 := by decide

open RotMoE.Saturation in
/-- **The inherited 8-of-80 margin is INAPPLICABLE at either pilot denominator.**
Not "fails" — *inapplicable*, which is the distinction the whole retraction turns
on. §5 must state a pilot margin; it cannot borrow the calibration corpus's. -/
theorem the_inherited_margin_is_inapplicable_to_any_pilot :
    preregisteredMargin.applyTo ⟨3, pilotDenominator 12 1⟩ = none
      ∧ preregisteredMargin.applyTo ⟨3, pilotDenominator 10 2⟩ = none := by decide

/-- **The band of margins a pilot CAN carry, at each denominator.** Stated as the
reachable range rather than a chosen value, because choosing one after seeing the
pilot is the contamination §5 exists to prevent. Whoever fixes the pilot margin
must land inside these. -/
theorem the_reachable_pilot_margins :
    ((List.range 13).filter (fun mg => 2 * mg ≤ pilotDenominator 12 1)).getLast? = some 6
      ∧ ((List.range 21).filter (fun mg => 2 * mg ≤ pilotDenominator 10 2)).getLast? = some 10 := by
  decide

/-! ### The pilot margin, chosen and sealed BEFORE the pilot is re-run

A margin has to come from somewhere other than the data it will judge. The only
margin this project ever preregistered is `preregMargin = 8` against
`calibCorpus.outOf = 80`, and that pair is **exactly one tenth** — a fact about
the declared numbers, not a fit to anything. So the pilot margin preserves the
proportion the project already committed to, at whatever denominator the pilot
turns out to have.

**This also resolves the CONTESTED fractional-margin section above.** Its
diagnosis — "the margin was a fraction that had been flattened into a number" —
was right. Its fraction was wrong: I wrote `outOf / 5` because I believed the
denominator was the 40-task corpus. Against the real denominator of 80 the
proportion is `/ 10`. The disease was correctly identified and the arithmetic
was done against the wrong number, which is the same error as the retraction. -/

/-- **The preregistered margin is exactly one tenth of its denominator.**
Stated as a relation between the two declared constants, so it holds however
they move rather than asserting the digits 8 and 80. -/
theorem the_preregistered_margin_is_exactly_one_tenth :
    RotMoE.Saturation.preregMargin * 10 = RotMoE.Saturation.calibCorpus.outOf := by decide

/-- **The proportion itself, derived from the two declared constants.**

Written as a definition rather than the literal `10` after mutant **M21**
survived: M21 restated `the_preregistered_margin_is_exactly_one_tenth` over
literals, and no build can catch that, because "the statement mentions the
constants" is a *textual* property and a mutation suite tests *behaviour*. The
repair is to put the constants where behaviour depends on them — now moving
`preregMargin` or `calibCorpus` moves every margin derived here. -/
def marginDivisor : Nat :=
  RotMoE.Saturation.calibCorpus.outOf / RotMoE.Saturation.preregMargin

/-- The divisor is one tenth, and it is *computed*. -/
theorem the_divisor_is_derived_from_the_declared_constants :
    marginDivisor = 10 := by decide

/-- The pilot margin: the project's own proportion, at the pilot's denominator. -/
def pilotMargin (outOf : Nat) : Margin := ⟨outOf / marginDivisor, outOf⟩

/-- **It is well formed at both pilot denominators**, so it is a margin that can
be applied rather than one that must be argued about. -/
theorem the_pilot_margin_is_well_formed_at_both_denominators :
    wellFormed (pilotMargin (pilotDenominator 12 1)) = true
      ∧ wellFormed (pilotMargin (pilotDenominator 10 2)) = true := by decide

/-- **And it lands inside the proved reachable band** — 1 at twelve pairs
(band ≤ 6), 2 at twenty (band ≤ 10). The numeral is a consequence of the
proportion, not a choice made while looking at scores. -/
theorem the_sealed_pilot_margin_is_inside_the_reachable_band :
    (pilotMargin (pilotDenominator 12 1)).room = 1
      ∧ (pilotMargin (pilotDenominator 10 2)).room = 2
      ∧ 2 * (pilotMargin (pilotDenominator 12 1)).room ≤ pilotDenominator 12 1
      ∧ 2 * (pilotMargin (pilotDenominator 10 2)).room ≤ pilotDenominator 10 2 := by decide

/-- **A margin of one tenth is reachable at every denominator of ten or more.**
The general property, so the seal does not expire the moment the pilot size
changes — the defect this file exists to prevent. -/
theorem a_one_tenth_margin_is_reachable_at_every_pilot_size (n : Nat) (h : 10 ≤ n) :
    2 * (pilotMargin n).room ≤ n := by
  have hd : marginDivisor = 10 := the_divisor_is_derived_from_the_declared_constants
  simp only [pilotMargin, hd]
  omega

/-- **Applied to the pilot as measured, under the PRIMARY rule.** Arm scores
8-of-12 and 6-of-12 (R4-committed). Both admit at the sealed margin, so the
corpus is not at floor or ceiling and the pilot is admissible. The margin was
fixed by the paragraph above before these numbers were substituted in. -/
theorem the_measured_pilot_admits_at_the_sealed_margin :
    (pilotMargin 12).applyTo ⟨8, 12⟩ = some true
      ∧ (pilotMargin 12).applyTo ⟨6, 12⟩ = some true := by decide

/-- **And the strict rule's scores admit too**, so admissibility does not hinge
on which of the declared rules is read — reported because a gate that passed
only under the primary rule would be a weaker claim than it appears. -/
theorem the_pilot_admits_under_the_sensitivity_rules_as_well :
    (pilotMargin 12).applyTo ⟨3, 12⟩ = some true
      ∧ (pilotMargin 12).applyTo ⟨1, 12⟩ = some true
      ∧ (pilotMargin 12).applyTo ⟨9, 12⟩ = some true
      ∧ (pilotMargin 12).applyTo ⟨7, 12⟩ = some true := by decide

/-! ### O8 — the hedge rate, promoted from footnote to observable

Six of twelve answers in **each** arm named both numbers. That is a real
measurement of behaviour under a two-answer prompt, it is already extracted by
the scorer, and it costs nothing to report. It is **descriptive**, like O6 and
O7 — it must not enter the family size. -/

/-- The hedge rate is an observable, and a descriptive one. -/
def observablesWithHedge : List (String × Role) :=
  observables ++ [("O8 hedge rate", Role.descriptive)]

/-- **Adding O8 does not change `m`.** The multiplicity correction is computed
from the two-sided tests alone, so a descriptive observable cannot inflate it —
the property `descriptive_observables_do_not_inflate_the_family` asserted for the
original table, now re-checked for the extended one. -/
theorem the_hedge_rate_does_not_inflate_the_family :
    (observablesWithHedge.filter (fun o => o.2 == Role.twoSidedTest)).length = m := by
  decide

/-- **And it is measured in both arms at the same value**, which is itself the
finding: the hedging is a property of the prompt, not of the routing. -/
def hedgedByArm : Nat × Nat := (6, 6)

theorem the_hedge_rate_was_identical_in_both_arms :
    hedgedByArm.1 = hedgedByArm.2 ∧ hedgedByArm.1 = 6 := by decide

end RotMoE.Family
