/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# What an audit of part of a suite establishes about the whole

`Proofs.RotVacuousGate` modelled gates and vacuity. `Proofs.RotGateObservation`
proved that one observation of a gate decides nothing and two decide everything,
and that a gate answering red in every world blinds the whole suite behind it.
Both are statements about ONE gate, or about a suite treated as a unit.

This module is about the situation actually faced when auditing a repository:
the suite has many gates, some have been examined and given controls, and most
have not. The audit is real work and it produces real knowledge. The question is
what that knowledge licenses about the suite's verdict, and the answer is
sharply asymmetric.

**Partial coverage licenses nothing.** `a_nonempty_audit_does_not_make_a_suite_meaningful`
exhibits a suite and a non-empty audited subset where every audited gate is
provably informative -- controls in both directions, exactly the standard this
repository holds itself to -- and the suite is nonetheless vacuous. The audit was
not sloppy and its conclusions were not wrong. It simply did not cover the gate
that mattered. `full_coverage_of_a_subset_proves_nothing` states the same fact
in the form that stings: the quality of the audited gates appears nowhere in the
proof, because it is irrelevant. A perfect audit of 81 gates out of 82 is
consistent with a completely vacuous suite.

**Total coverage licenses everything.** `full_audit_gives_a_meaningful_suite`
proves the converse: if every gate in the suite is informative, the suite is
non-vacuous. Coverage is therefore not a gradual virtue that buys proportional
confidence. It is a threshold, and the threshold is all of them.

The practical reading is uncomfortable and worth stating plainly. A coverage
figure like "14 of 91 audited" is an honest report of work done, but it must not
be read as a fraction of confidence gained. Until coverage is total, the correct
statement about the suite's verdict is the same as it was at zero coverage:
unknown. What the audit buys is not partial assurance about the whole; it is
total assurance about the parts examined, plus a shrinking list of places the
answer could still be hiding.

`the_unaudited_remainder_is_where_the_answer_lives` names that directly: for any
audited subset short of the whole, the vacuity of the suite is decided entirely
by gates outside it.

Nothing here says any gate in this repository is always-red. That is measured,
and the measurement is exactly what the remaining audit is for.
-/
import Proofs.RotVacuousGate

namespace RotMoE.Coverage

open RotMoE.Vacuity
open Evidence Verdict

/-- A suite runs green on a holding world exactly when every gate in it is live
there. The induction is the reason total coverage is worth anything. -/
theorem all_informative_run_present (s : Suite) (h : ∀ x ∈ s, Informative x) :
    run s present = green := by
  induction s with
  | nil => rfl
  | cons g rest ih =>
    have hg : Informative g := h g (List.mem_cons_self)
    have hlive : g present = green := hg.2
    show (if g present = red then red else run rest present) = green
    rw [hlive]
    have : (green : Verdict) ≠ red := by decide
    rw [if_neg this]
    exact ih (fun x hx => h x (List.mem_cons_of_mem g hx))

/-- TOTAL COVERAGE IS SUFFICIENT. Every gate informative gives a non-vacuous
suite: it answers red on the failing world and green on the holding one. -/
theorem full_audit_gives_a_meaningful_suite (g : Gate) (rest : Suite)
    (h : ∀ x ∈ (g :: rest), Informative x) : ¬ Vacuous (run (g :: rest)) := by
  intro hv
  have hg : Informative g := h g (List.mem_cons_self)
  have hred : run (g :: rest) absent = red := by
    show (if g absent = red then red else run rest absent) = red
    rw [hg.1]
    rfl
  have hgreen : run (g :: rest) present = green :=
    all_informative_run_present (g :: rest) h
  have := hv present absent
  rw [hgreen, hred] at this
  exact absurd this (by decide)

/-- PARTIAL COVERAGE IS NOT PARTIALLY SUFFICIENT. A non-empty audited subset,
every member of it provably informative and genuinely part of the suite, and the
suite is still vacuous. The audit was correct; it was not total. -/
theorem a_nonempty_audit_does_not_make_a_suite_meaningful :
    ∃ (s covered : Suite),
      covered ≠ [] ∧
      (∀ g ∈ covered, g ∈ s ∧ Informative g) ∧
      Vacuous (run s) := by
  refine ⟨[alwaysRed, honest], [honest], by simp, ?_, ?_⟩
  · intro g hg
    have : g = honest := by simpa using hg
    subst this
    exact ⟨by simp, honest_informative⟩
  · intro _ _
    rfl

/-- The same fact with the audited gates' quality quantified over, to make the
irrelevance explicit: however good the audited remainder is, an unaudited
always-red gate in front of it decides the verdict alone. The hypothesis `h` is
deliberately never used -- that IS the theorem. -/
theorem full_coverage_of_a_subset_proves_nothing (rest : Suite)
    (_h : ∀ g ∈ rest, Informative g) : Vacuous (run (alwaysRed :: rest)) := by
  intro _ _
  rfl

/-- Where the answer actually lives. Two suites can share an audited prefix of
informative gates and differ in vacuity, so the verdict is decided outside the
audited part. -/
theorem the_unaudited_remainder_is_where_the_answer_lives :
    ∃ (audited : Suite) (s₁ s₂ : Suite),
      (∀ g ∈ audited, Informative g) ∧
      s₁ = audited ++ [honest] ∧
      s₂ = audited ++ [alwaysRed] ∧
      ¬ Vacuous (run s₁) ∧ Vacuous (run s₂) := by
  refine ⟨[], [honest], [alwaysRed], by simp, by simp, by simp, ?_, ?_⟩
  · exact full_audit_gives_a_meaningful_suite honest [] (by
      intro x hx
      have : x = honest := by simpa using hx
      subst this
      exact honest_informative)
  · intro _ _
    rfl

/-- Coverage is a threshold, not a gradient: the two results above are exactly
"all of them" and "anything less". -/
theorem coverage_is_a_threshold (g : Gate) (rest : Suite) :
    ((∀ x ∈ (g :: rest), Informative x) → ¬ Vacuous (run (g :: rest)))
    ∧ (∃ (s : Suite) (covered : Suite),
         covered ≠ [] ∧ (∀ x ∈ covered, x ∈ s ∧ Informative x) ∧ Vacuous (run s)) :=
  ⟨full_audit_gives_a_meaningful_suite g rest,
   a_nonempty_audit_does_not_make_a_suite_meaningful⟩

end RotMoE.Coverage
