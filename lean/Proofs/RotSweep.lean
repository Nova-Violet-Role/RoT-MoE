/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A verdict printed before the work finishes is not a verdict

**Measured 2026-08-10, during the first full 57-suite mutation sweep.** Three
suites were repaired; this module is why those repairs are correct rather than
merely green.

`mutate_rotlog.sh` printed its summary at line 262 while four of its own mutants
(`L11`–`L14`) were declared *below* that line. It therefore announced
`killed=10` on a run in which **14** mutants ran and were killed. Its exit code
was never wrong — the survivor and discard guards sit at the foot of the file and
read the live counters — but every consumer that *parsed the text* under-counted
by four.

`mutate_rotinject.sh` and `mutate_rotsessionlog.sh` had the dual defect: `_total`
was used and never assigned, so under `set -u` the suite printed a complete,
correct verdict and then **died on the summary line, exit 1**. A human reading the
output saw a clean sweep; a script reading the exit code saw a failure.

The two shapes are opposite and they share one root, which is what is modelled
here: **the printed report and the exit verdict are two different observations of
one run, and nothing forced them to agree.**

## What is modelled

A run of `n` declared mutants. `reportedAt k` is the summary a suite prints after
`k` of them have executed. `verdict` is the exit classification computed from the
*final* counters.

## What is NOT modelled

Whether a given mutant is correctly scored killed — that is the job of the suite's
own build step and of `RotMutant.lean`. Here every mutant that runs is assumed to
be scored correctly, which is the *favourable* assumption: the defects below
survive even when the scoring is perfect.
-/

namespace RotMoE.Sweep

/-- One suite run. `declared` mutants exist in the file; `ran` of them executed;
of those, `killed + survived + discarded = ran`. -/
structure Run where
  declared  : Nat
  ran       : Nat
  killed    : Nat
  survived  : Nat
  discarded : Nat
  deriving Repr, DecidableEq

/-- A run is *coherent* when its parts add up and it did not run more mutants
than exist. This is a well-formedness condition on the observation, not a claim
that the run was good. -/
def coherent (r : Run) : Bool :=
  (r.killed + r.survived + r.discarded == r.ran) && (r.ran ≤ r.declared)

/-- The summary a suite prints after `k` mutants have executed. A suite whose
`echo` sits above some of its own `run_mut` calls is printing `reportedAt k` for
some `k < declared`. -/
def reportedAt (r : Run) (k : Nat) : Nat := min r.killed k

/-- The exit classification, computed from the FINAL counters. This is what the
guards at the foot of a suite compute, and it is the half that was never wrong.
`0` = clean, `1` = a survivor or a discard, `2` = incoherent. -/
def verdict (r : Run) : Nat :=
  match coherent r, (r.survived != 0 || r.discarded != 0), (r.ran != r.declared) with
  | false, _,    _     => 2
  | true,  true, _     => 1
  | true,  false, true => 1
  | true,  false, false => 0

/-- The full 57-suite sweep as measured after the repairs. -/
def sweep : Run := ⟨634, 634, 634, 0, 0⟩

/-- `mutate_rotlog.sh` as it behaved BEFORE the repair: 14 declared, 14 ran, 14
killed — and a printed summary of 10, because the echo sat above four mutants. -/
def rotlogBefore : Run := ⟨14, 14, 14, 0, 0⟩

/-- A run that genuinely stopped after 10 mutants. Its true killed count is 10. -/
def truncatedRun : Run := ⟨14, 10, 10, 0, 0⟩

/-! ## The defect: an early summary is indistinguishable from a truncated run -/

/-- **The rotlog defect, stated exactly.** A summary printed after `k` mutants
reports `k`, not the truth, whenever `k` is below the number actually killed. -/
theorem early_summary_under_reports (r : Run) (k : Nat) (h : k < r.killed) :
    reportedAt r k < r.killed := by
  unfold reportedAt
  omega

/-- **Why nobody noticed for so long.** The complete run with an early echo and
the genuinely truncated run print the SAME number. A reader comparing printed
output cannot tell a reporting bug from a harness that stopped early. -/
theorem early_echo_is_indistinguishable_from_truncation :
    reportedAt rotlogBefore 10 = reportedAt truncatedRun 10 := by decide

/-- …while the two runs are not the same run at all. The information destroyed is
recoverable only from the exit path, never from the text. -/
theorem the_two_runs_differ : rotlogBefore ≠ truncatedRun := by decide

/-- **The half that was never wrong.** rotlog's guards read the final counters,
so the complete run is classified clean regardless of what was printed. -/
theorem exit_path_was_correct_all_along : verdict rotlogBefore = 0 := by decide

/-- …and the genuinely truncated run is refused by that same path. A suite that
does not run every declared mutant is not a pass, which is the property that
makes the exit code trustworthy while the text is not. -/
theorem truncation_is_refused : verdict truncatedRun = 1 := by decide

/-! ## The dual defect: text and exit disagreeing -/

/-- The `_total` shape: the run itself is clean, so the verdict is `0`, and the
suite nevertheless exited `1` because the summary line raised an unbound
variable. Modelled as the disagreement it is — a reported exit that contradicts
the verdict its own counters justify. -/
def injectBefore : Run := ⟨9, 9, 9, 0, 0⟩

/-- The run was clean. -/
theorem inject_run_was_clean : verdict injectBefore = 0 := by decide

/-- **The observation that matters.** `verdict` disagreeing with a reported exit
of `1` means one of the two observations is not about the run. A consumer given
only the exit code concludes failure; a consumer given only the text concludes
success; both are reading the same clean run. -/
theorem a_reported_exit_may_contradict_the_verdict :
    verdict injectBefore = 0 ∧ (1 : Nat) ≠ verdict injectBefore := by decide

/-! ## The durable statements

The two above name specific runs, so they are dated by construction: they
document what was measured on 2026-08-10 and would stop being interesting once
those files change. The three below name no constant and do not expire.
-/

/-- **A report is only a report of the whole run when every declared mutant
ran.** Quantified over every run — this is the rule the repairs enforce, not a
fact about today's 634. -/
theorem a_verdict_requires_every_declared_mutant (r : Run) (h : verdict r = 0) :
    r.ran = r.declared := by
  unfold verdict at h
  cases hc : coherent r <;>
    cases hs : (r.survived != 0 || r.discarded != 0) <;>
      cases hr : (r.ran != r.declared) <;>
        simp only [hc, hs, hr] at h ⊢
  all_goals first
    | omega
    | exact Nat.eq_of_beq_eq_true (by simpa using hr)

/-- **A clean verdict admits no survivor and no discard.** The two are reported
apart everywhere in this repository because they mean different things — a
survivor is a claim about a theorem, a discard is a claim about the harness — and
neither is a pass. -/
theorem a_clean_verdict_has_no_survivor_and_no_discard (r : Run)
    (h : verdict r = 0) : r.survived = 0 ∧ r.discarded = 0 := by
  unfold verdict at h
  cases hc : coherent r <;>
    cases hs : (r.survived != 0 || r.discarded != 0) <;>
      cases hr : (r.ran != r.declared) <;>
        simp only [hc, hs, hr] at h ⊢
  all_goals first
    | omega
    | (simp only [Bool.or_eq_false_iff, bne_eq_false_iff_eq] at hs; exact hs)

/-- **The printed summary can never exceed the truth.** It under-reports or it is
exact; it cannot invent kills. This is why the defect was safe-but-wrong rather
than a fake green — and it is the reason the published figure stayed
self-consistent instead of being caught. -/
theorem a_summary_never_over_reports (r : Run) (k : Nat) :
    reportedAt r k ≤ r.killed := by
  unfold reportedAt
  omega

/-- **The summary is exact exactly when it is printed after the last mutant.** -/
theorem a_late_summary_is_exact (r : Run) (k : Nat) (h : r.killed ≤ k) :
    reportedAt r k = r.killed := by
  unfold reportedAt
  omega

/-! ## The measured sweep -/

/-- The whole tree, after the repairs. -/
theorem the_sweep_is_clean : verdict sweep = 0 := by decide

/-- …and it is a complete run, not a prefix. -/
theorem the_sweep_ran_everything : sweep.ran = sweep.declared := by decide

-- Concrete checks. Each one executes the definitions above rather than
-- restating them, so a definition that stops meaning what it says fails here.
#guard verdict sweep = 0
#guard verdict rotlogBefore = 0
#guard verdict truncatedRun = 1
#guard verdict injectBefore = 0
#guard reportedAt rotlogBefore 10 = 10
#guard reportedAt rotlogBefore 14 = 14
#guard reportedAt truncatedRun 10 = 10
#guard verdict ⟨634, 634, 633, 1, 0⟩ = 1   -- one survivor is never a pass
#guard verdict ⟨634, 634, 633, 0, 1⟩ = 1   -- one discard is never a pass
#guard verdict ⟨634, 633, 633, 0, 0⟩ = 1   -- one mutant short is never a pass
#guard verdict ⟨634, 634, 999, 0, 0⟩ = 2   -- incoherent counters are refused

end RotMoE.Sweep
