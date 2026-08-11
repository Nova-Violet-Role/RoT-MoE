/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Proofs.RotExperiment

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

end RotMoE.Family
