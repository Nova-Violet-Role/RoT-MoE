/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A partial run is not a pass, and the exit code has to say so

**Measured 2026-08-10, in shipped code.** `checker/ci-dryrun.sh --from 9999`
windowed out **all 75** extracted CI steps, printed an entirely honest paragraph
— *"This run is NOT a full pass. Windowed is not passed, not deferred, and not
skipped — it is untested."* — and then **exited 0** with `ci-dryrun: PASS`.

The prose was right and the verdict was wrong, which is the worse half to get
wrong: `checker/gate-all.sh` reads the **exit code**, not the paragraph. Zero
steps executed, recorded as green, reachable with a single flag.

The defect is not the windowing feature. Windowing is necessary — the full sweep
exceeds every caller's wall-clock bound, and cutting a run short with a signal is
what emptied two shipped hooks earlier the same day
(`RotTreeIntegrity`). The defect is that the verdict function **read only the
failure count** and never consulted how many steps had run.

`naiveVerdict` below is the shipped bug, `honestVerdict` is the fix, and
`naive_is_blind_to_windowing` is why no amount of care with the failure count
could have caught it: a run of 75 steps with no failures and a run of **zero**
steps with no failures are the same value to it.

The same hole was closed at the same time in `checker/mutate-checker.sh`, whose
new `MUT_ONLY` selector counts held-back mutants in `notrun` and exits 3. The
control that matters there is a *typo*: `MUT_ONLY=NOSUCHID` selects nothing, and
must not report a clean sweep of zero mutants. Measured: `killed=0 notrun=16`,
exit 3.
-/

namespace RotPartialRun

/-- A run of a step list: how many steps exist, how many actually executed, and
how many of those failed. -/
structure Run where
  /-- Steps extracted from the workflow (or mutants in a suite). -/
  total : Nat
  /-- Steps that actually executed. -/
  ran : Nat
  /-- Executed steps that failed. -/
  failed : Nat
  deriving DecidableEq, Repr

/-- Steps that never ran — windowed out, or held back by a selector. -/
def notrun (r : Run) : Nat := r.total - r.ran

/-- **The shipped bug.** A verdict that consults only the failure count. -/
def naiveVerdict (r : Run) : Bool := r.failed == 0

/-- **The fix.** Nothing may be left unrun. -/
def honestVerdict (r : Run) : Bool := r.failed == 0 && notrun r == 0

/-- The measured incident: 75 steps extracted, none executed, none failed. -/
def theIncident : Run := ⟨75, 0, 0⟩

/-- The same step list, fully executed. -/
def fullSweep : Run := ⟨75, 75, 0⟩

/-! ## The blindness -/

/-- **The bug, exactly as it shipped**: a run in which nothing happened passes. -/
theorem naive_passes_a_run_that_did_nothing : naiveVerdict theIncident = true := by
  decide

/-- **The fix refuses it.** -/
theorem honest_refuses_a_run_that_did_nothing :
    honestVerdict theIncident = false := by decide

/-- **Why care with the failure count could never have caught it.** A full sweep
and a run of nothing are the *same value* to the naive verdict, though the runs
differ. -/
theorem naive_is_blind_to_windowing :
    naiveVerdict theIncident = naiveVerdict fullSweep ∧ theIncident ≠ fullSweep := by
  constructor
  · decide
  · decide

/-- The honest verdict distinguishes exactly that pair, so it is a real second
condition and not a restatement. -/
theorem honest_separates_them :
    honestVerdict theIncident = false ∧ honestVerdict fullSweep = true := by decide

/-! ## The fix is sound and costs nothing -/

/-- **No false alarm.** On a run where everything executed, the extra condition
changes nothing — so adding it cannot make a good sweep go red. -/
theorem honest_agrees_when_everything_ran (r : Run) (h : r.total ≤ r.ran) :
    honestVerdict r = naiveVerdict r := by
  have hz : notrun r = 0 := Nat.sub_eq_zero_of_le h
  simp only [honestVerdict, naiveVerdict, hz, beq_self_eq_true, Bool.and_true]

/-- Anything held back forces a refusal, whatever the failure count says. -/
theorem honest_never_passes_with_notrun (r : Run) (h : notrun r ≠ 0) :
    honestVerdict r = false := by
  simp only [honestVerdict, Bool.and_eq_false_iff, beq_eq_false_iff_ne]
  exact Or.inr h

/-- **A pass means everything ran.** The converse direction: the honest verdict
cannot be true unless the whole list executed. -/
theorem pass_implies_everything_ran (r : Run) (h : honestVerdict r = true) :
    r.total ≤ r.ran ∧ r.failed = 0 := by
  simp only [honestVerdict, Bool.and_eq_true, beq_iff_eq] at h
  exact ⟨Nat.le_of_sub_eq_zero h.2, h.1⟩

/-- A failing run is refused by both verdicts — the fix does not mask failures. -/
theorem failures_still_refused (r : Run) (h : r.failed ≠ 0) :
    honestVerdict r = false ∧ naiveVerdict r = false := by
  constructor
  · simp only [honestVerdict, Bool.and_eq_false_iff, beq_eq_false_iff_ne]
    exact Or.inl h
  · simp only [naiveVerdict, beq_eq_false_iff_ne]; exact h

/-! ## Complementary windows -/

/-- Two windows compose: run `a` steps then `b`, with `a + b` covering the list. -/
def compose (r₁ r₂ : Run) : Run :=
  ⟨r₁.total, r₁.ran + r₂.ran, r₁.failed + r₂.failed⟩

/-- **Segmenting is legitimate.** Complementary windows that together cover every
step, with no failures, compose into a run the honest verdict accepts — so the
guard forbids *lying about* a partial run, not splitting one. -/
theorem complementary_windows_compose_to_a_pass (r₁ r₂ : Run)
    (hcov : r₁.total ≤ r₁.ran + r₂.ran) (h₁ : r₁.failed = 0) (h₂ : r₂.failed = 0) :
    honestVerdict (compose r₁ r₂) = true := by
  have hz : notrun (compose r₁ r₂) = 0 := Nat.sub_eq_zero_of_le hcov
  have hf : (compose r₁ r₂).failed = 0 := by
    simp only [compose, h₁, h₂, Nat.add_zero]
  simp only [honestVerdict, hz, hf, beq_self_eq_true, Bool.and_true]

/-- But a *gap* between the windows is still refused. -/
theorem a_gap_between_windows_is_refused (r₁ r₂ : Run)
    (hgap : r₁.ran + r₂.ran < r₁.total) :
    honestVerdict (compose r₁ r₂) = false := by
  have h : notrun (compose r₁ r₂) ≠ 0 := by
    simp only [notrun, compose]
    omega
  exact honest_never_passes_with_notrun _ h

/-! ## Executable checks — the measured run -/

/-- CI steps `ci-dryrun.sh` extracts from the workflows. -/
def measuredSteps : Nat := 75
/-- Steps executed by the first window, `--to 40`. -/
def measuredWindow1 : Nat := 40
/-- Steps left to the complementary window, `--from 41`. -/
def measuredWindow2 : Nat := 35
/-- Mutants in `checker/mutate-checker.sh`, all killed in the first complete run. -/
def measuredMutants : Nat := 16

#guard measuredWindow1 + measuredWindow2 = measuredSteps
#guard naiveVerdict theIncident = true
#guard honestVerdict theIncident = false
#guard honestVerdict fullSweep = true
#guard notrun theIncident = 75
#guard notrun fullSweep = 0
#guard honestVerdict ⟨75, 40, 0⟩ = false
#guard honestVerdict ⟨16, 0, 0⟩ = false
#guard honestVerdict ⟨16, 16, 0⟩ = true
#guard honestVerdict ⟨16, 16, 1⟩ = false
#guard honestVerdict (compose ⟨75, 40, 0⟩ ⟨75, 35, 0⟩) = true
#guard honestVerdict (compose ⟨75, 40, 0⟩ ⟨75, 34, 0⟩) = false

end RotPartialRun
