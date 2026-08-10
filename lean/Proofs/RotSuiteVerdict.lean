/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A filtered mutation run is not a pass, in thirty-seven files at once

**Measured 2026-08-10.** `MUT_ONLY=P01 bash mutate/mutate_rotpartialrun.sh` ran
**1 of 13** mutants and exited **0**, printing

```
All 1 mutants killed (13 ran, 0 survived, 0 discarded).
```

Both halves of that line are wrong: 1 ran, 13 were *considered*, and the run was
a twelfth of the suite. The file's own header promises the opposite:

> "A filtered run prints a PARTIAL banner and exits 3, never 0. Nothing that
> consumes this output — the CHANGELOG count, repo-complete's cross-check, CI —
> can mistake four killed mutants for forty-eight."

The `skipped` counter is computed, folded into `_total`, and then **never
consulted by the verdict**. Swept across the directory: **37 of 37** suites that
accept `MUT_ONLY` have no guard. This is the same defect CP51 fixed in
`ci-dryrun.sh` and CP52 fixed in `mutate-checker.sh`; the per-module suites were
never swept, so the fix stopped one layer short.

It is not hypothetical: the measurement above was taken while trying to observe
something else, and the exit code was nearly recorded as a pass.

`naiveExit` is the shipped verdict. `honestExit` is the repair.
`honest_is_never_weaker` is the theorem that makes the repair a repair rather
than a re-shuffle: everything the old verdict rejected, the new one still
rejects.

Parts 2 and 3 cover two copy-paste defects found in the same sweep, both of the
"the evidence printed is not the evidence" family that `RotDelivery` opened.
-/

namespace RotSuiteVerdict

/-! ## Part 1 — the verdict -/

/-- The four counters every suite in `lean/mutate/` maintains. -/
structure Suite where
  /-- Mutants whose build failed: the belief is defended. -/
  killed : Nat
  /-- Mutants that applied and left the build green: a COVERAGE GAP. -/
  survived : Nat
  /-- Mutants whose patch never landed: NOTHING was tested. -/
  discarded : Nat
  /-- Mutants held back by `MUT_ONLY`: not run at all. -/
  skipped : Nat
  deriving DecidableEq, Repr

/-- Every mutant the suite knows about. -/
def total (s : Suite) : Nat := s.killed + s.survived + s.discarded + s.skipped

/-- **What shipped.** Zero-total, survivors and discards each fail; `skipped` is
computed and never read. -/
def naiveExit (s : Suite) : Nat :=
  if total s == 0 then 1
  else if 0 < s.survived then 1
  else if 0 < s.discarded then 1
  else 0

/-- **The repair.** A held-back mutant makes the run PARTIAL — exit 3, which is
this repository's skip code everywhere. Deliberately *after* the survivor and
discard tests, so a real finding is never downgraded to a skip. -/
def honestExit (s : Suite) : Nat :=
  if total s == 0 then 1
  else if 0 < s.survived then 1
  else if 0 < s.discarded then 1
  else if 0 < s.skipped then 3
  else 0

/-- The run measured on 2026-08-10: `MUT_ONLY=P01`, one killed, twelve held back. -/
def theFilteredRun : Suite := ⟨1, 0, 0, 12⟩

/-- The same suite, run whole. -/
def theFullRun : Suite := ⟨13, 0, 0, 0⟩

/-- A suite that ran nothing at all. -/
def theEmptyRun : Suite := ⟨0, 0, 0, 0⟩

/-- **The typo control, measured 2026-08-10.** `MUT_ONLY=NOSUCHID` selects no
mutant at all, so all thirteen are held back and *none* is executed. The shipped
verdict printed `All 0 mutants killed (13 ran, 0 survived, 0 discarded)` and
exited **0**. Both figures in that sentence are false: nothing was killed and
nothing ran. This is the strongest form of the defect, because a reader who
mistypes a mutant id gets a green. -/
def theTypoControl : Suite := ⟨0, 0, 0, 13⟩

/-- A survivor alongside held-back mutants: two different problems at once. -/
def survivorAndSkips : Suite := ⟨5, 1, 0, 7⟩

/-! ### The hole -/

/-- **The defect, as a theorem**: a twelfth of the suite exits 0. -/
theorem naive_passes_a_filtered_run : naiveExit theFilteredRun = 0 := by decide

/-- The repair refuses it, and refuses it as PARTIAL rather than as a failure. -/
theorem honest_calls_a_filtered_run_partial : honestExit theFilteredRun = 3 := by
  decide

/-- **Why no care with the other three counters could have caught it.** A full
clean sweep and a run of one mutant in thirteen are the *same value* to the
shipped verdict, though the runs differ. -/
theorem naive_cannot_separate_a_filtered_run_from_a_full_one :
    naiveExit theFilteredRun = naiveExit theFullRun ∧ theFilteredRun ≠ theFullRun := by
  constructor
  · decide
  · decide

/-! ### What the repaired verdict entails -/

/-- A pass entails that nothing was held back. -/
theorem a_pass_entails_nothing_skipped (s : Suite) :
    honestExit s = 0 → s.skipped = 0 := by
  intro h
  by_cases h0 : total s == 0
  · simp [honestExit, h0] at h
  · by_cases hs : 0 < s.survived
    · simp [honestExit, h0, hs] at h
    · by_cases hd : 0 < s.discarded
      · simp [honestExit, h0, hs, hd] at h
      · by_cases hk : 0 < s.skipped
        · simp [honestExit, h0, hs, hd, hk] at h
        · omega

/-- A pass entails a real, complete, clean sweep: no survivor, no discard,
nothing held back, and **at least one mutant actually killed**. The last
conjunct is what stops an empty run from qualifying. -/
theorem a_pass_is_a_complete_clean_sweep (s : Suite) :
    honestExit s = 0 →
      s.survived = 0 ∧ s.discarded = 0 ∧ s.skipped = 0 ∧ 0 < s.killed := by
  intro h
  by_cases h0 : total s == 0
  · simp [honestExit, h0] at h
  · by_cases hs : 0 < s.survived
    · simp [honestExit, h0, hs] at h
    · by_cases hd : 0 < s.discarded
      · simp [honestExit, h0, hs, hd] at h
      · by_cases hk : 0 < s.skipped
        · simp [honestExit, h0, hs, hd, hk] at h
        · simp only [beq_iff_eq, total] at h0
          refine ⟨by omega, by omega, by omega, by omega⟩

/-- **No weakening.** Every run the shipped verdict rejected is still rejected.
A repair that narrowed a check is indistinguishable from one that loosened it
until this is proved. -/
theorem honest_is_never_weaker (s : Suite) :
    naiveExit s ≠ 0 → honestExit s ≠ 0 := by
  intro h
  by_cases h0 : total s == 0
  · simp [honestExit, h0]
  · by_cases hs : 0 < s.survived
    · simp [honestExit, h0, hs]
    · by_cases hd : 0 < s.discarded
      · simp [honestExit, h0, hs, hd]
      · simp [naiveExit, h0, hs, hd] at h

/-- …and it is *strictly* stronger: the implication does not run backwards. -/
theorem the_repair_rejects_strictly_more :
    naiveExit theFilteredRun = 0 ∧ honestExit theFilteredRun ≠ 0 := by
  constructor
  · decide
  · decide

/-- **A real finding is never downgraded to a skip.** A survivor alongside
held-back mutants exits 1, not 3 — the order of the tests is load-bearing. -/
theorem a_survivor_outranks_a_skip : honestExit survivorAndSkips = 1 := by decide

/-- An empty run is a failure, not a clean sweep — this is the guard the suites
already had, and it survives the repair. -/
theorem an_empty_run_still_fails : honestExit theEmptyRun = 1 := by decide

/-- **The measured typo control passes the shipped verdict.** Nothing ran, and
the exit code is 0. -/
theorem the_typo_control_passes_the_shipped_verdict :
    naiveExit theTypoControl = 0 := by decide

/-- The repair refuses it. -/
theorem the_typo_control_is_refused : honestExit theTypoControl = 3 := by decide

/-- **The zero-total guard the suites already had could never have caught it.**
Thirteen held-back mutants make `total` thirteen, so the "ZERO mutants ran" test
is false — the suite looks populated while having executed nothing. This is why
counting the mutants the suite *knows about* is not counting the mutants it
*ran*. -/
theorem the_zero_total_guard_cannot_see_it :
    total theTypoControl ≠ 0 ∧ theTypoControl.killed = 0 := by
  constructor
  · decide
  · rfl

/-- The two measured runs — one mutant of thirteen, and none of thirteen — are
indistinguishable to the shipped verdict, and both are wrong. -/
theorem neither_measured_run_is_separated_by_the_shipped_verdict :
    naiveExit theTypoControl = naiveExit theFilteredRun ∧
      honestExit theTypoControl = honestExit theFilteredRun ∧
      theTypoControl ≠ theFilteredRun := by
  refine ⟨by decide, by decide, by decide⟩

/-- **Not vacuous**: a full clean sweep still passes, so the repair cannot be
satisfied only by refusing everything. -/
theorem a_full_clean_sweep_still_passes : honestExit theFullRun = 0 := by decide

/-- **Running MORE mutants can never redden the run.** The guarantee that stops
the fix from punishing an improvement: move one mutant from `skipped` to
`killed` and the exit code cannot get worse. -/
theorem unskipping_a_mutant_never_reddens (s : Suite) (h : 0 < s.skipped) :
    honestExit ⟨s.killed + 1, s.survived, s.discarded, s.skipped - 1⟩ ≤ honestExit s := by
  by_cases hs : 0 < s.survived
  · simp [honestExit, total, hs]
  · by_cases hd : 0 < s.discarded
    · simp [honestExit, total, hs, hd]
    · -- With no survivor and no discard but something held back, the original
      -- run is PARTIAL. Pin that first; otherwise the `total == 0` test on the
      -- right-hand side never reduces and the comparison stays opaque.
      have hrhs : honestExit s = 3 := by
        have h1 : ¬ (s.killed + s.survived + s.discarded + s.skipped == 0) := by
          simp only [beq_iff_eq]; omega
        simp [honestExit, total, h1, hs, hd, h]
      have h2 : ¬ (s.killed + 1 + s.survived + s.discarded + (s.skipped - 1) == 0) := by
        simp only [beq_iff_eq]; omega
      rw [hrhs]
      by_cases hk : 0 < s.skipped - 1
      · simp [honestExit, total, h2, hs, hd, hk]
      · simp [honestExit, total, h2, hs, hd, hk]

#guard naiveExit theFilteredRun = 0
#guard honestExit theFilteredRun = 3
#guard naiveExit theTypoControl = 0
#guard honestExit theTypoControl = 3
#guard total theTypoControl = 13
#guard honestExit theFullRun = 0
#guard honestExit theEmptyRun = 1
#guard honestExit survivorAndSkips = 1
#guard total theFilteredRun = 13

/-! ## Part 2 — an extractor pointed at the wrong module reports nothing

The same sweep found **8 suites** whose "which theorems died" extractor greps for
`error: Proofs/RotTrap.lean:` while operating on a different module — copied from
`mutate_rottrap.sh` and never renamed. Measured on `mutate_rotpartialrun.sh`:

```
P01  KILLED     exit=1  MODULE DEAD (no olean: every theorem unusable)
        errors at:   <- LOWER BOUND, not the full set
```

The field is **empty**, and it reads as "no theorem could be named" rather than
"the extractor is looking at another file". The kill count is unaffected — it
comes from the exit code — so this is a reporting defect, the same family as the
`head -1` evidence bug in `RotDelivery` Part 3. -/

/-- The two module names an extractor holds: the one the suite mutates, and the
one its error grep names. -/
structure Extractor where
  /-- The module this suite actually mutates. -/
  suiteModule : String
  /-- The module named in the error-line pattern. -/
  greppedModule : String

/-- The extractor can name a dead theorem only if it is reading its own module's
errors. -/
def canAttribute (e : Extractor) : Bool := e.suiteModule == e.greppedModule

/-- The measured state of `mutate_rotpartialrun.sh`. -/
def theCopyPaste : Extractor := ⟨"RotPartialRun", "RotTrap"⟩

/-- **The repair**: derive the grepped name from the suite's own file variable,
so there is one source of truth instead of two. -/
def derived (m : String) : Extractor := ⟨m, m⟩

/-- The defect: the extractor cannot attribute anything. -/
theorem the_copy_paste_cannot_attribute : canAttribute theCopyPaste = false := by
  decide

/-- **The repair holds for every module name**, not just the eight found. This is
the difference between fixing eight files and fixing the shape. -/
theorem a_derived_extractor_always_attributes (m : String) :
    canAttribute (derived m) = true := by
  simp [canAttribute, derived]

/-- The repair is not vacuous: a hand-written extractor that happens to be right
also attributes, so `canAttribute` is not constantly false. -/
theorem a_correct_hand_written_extractor_also_works :
    canAttribute ⟨"RotTrap", "RotTrap"⟩ = true := by decide

#guard canAttribute theCopyPaste = false
#guard canAttribute (derived "RotPartialRun") = true
#guard canAttribute (derived "RotWorkTrace") = true

/-! ## Part 3 — a rebuild check that measures the wrong module

Seven of the same suites end with `lake build Proofs.RotOrdering` regardless of
which module they mutate, under a comment reading *"a suite must leave the tree
GREEN"*. The exit code of that build is then tested. So the assertion passes when
`RotOrdering` builds — which it does — **whether or not the mutated module was
restored**. The check cannot fail for the reason it exists. -/

/-- A post-suite rebuild check. `green` is the build state **as a function of the
module name**, which is the honest model: being green is a property of a module,
not an independent field the check may set. Writing it as two unrelated booleans
would let a proof assume exactly what is in question. -/
structure RebuildCheck where
  /-- The module the suite mutated and must leave green. -/
  mutated : String
  /-- The module the check actually rebuilds. -/
  probed : String
  /-- Which modules currently build. -/
  green : String → Bool

/-- What the check reports: the build state of whatever it probed. -/
def checkPasses (r : RebuildCheck) : Bool := r.green r.probed

/-- What it is supposed to establish: the build state of what it mutated. -/
def treeIsActuallyGreen (r : RebuildCheck) : Bool := r.green r.mutated

/-- The measured configuration: the suite mutates `RotPartialRun`, the check
rebuilds `RotOrdering`, and only `RotOrdering` is green. -/
def theWrongProbe : RebuildCheck :=
  ⟨"RotPartialRun", "RotOrdering", fun m => m == "RotOrdering"⟩

/-- **The defect, as a theorem**: the check passes over a tree it was written to
declare broken. -/
theorem the_wrong_probe_passes_over_a_red_module :
    checkPasses theWrongProbe = true ∧ treeIsActuallyGreen theWrongProbe = false := by
  constructor
  · decide
  · decide

/-- **The repair**: probe the module the suite mutated. Then the check reports
exactly the property it claims — for every module and every build state, which is
what makes this a fix to the shape rather than to seven files. -/
theorem probing_the_mutated_module_reports_the_truth (r : RebuildCheck)
    (h : r.probed = r.mutated) :
    checkPasses r = treeIsActuallyGreen r := by
  simp [checkPasses, treeIsActuallyGreen, h]

/-- The repaired check can still fail — it is not green by construction. -/
theorem the_repaired_check_can_fail :
    checkPasses ⟨"RotPartialRun", "RotPartialRun", fun _ => false⟩ = false := by
  decide

#guard checkPasses theWrongProbe = true
#guard treeIsActuallyGreen theWrongProbe = false
#guard checkPasses ⟨"RotPartialRun", "RotPartialRun", fun _ => false⟩ = false

end RotSuiteVerdict
