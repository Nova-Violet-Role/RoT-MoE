/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Authors: Saimono
-/

/-!
# A skip is not a pass, and a green suite with skips is not a zero-skip green

Measured 2026-08-08. Four authorised app runs, each launched and closed by exact PID:

```
05:03  22 recording attempts, all failed   -> phases had a stream to check, and it was broken
07:53   0 attempts (deploy landed)
08:00   0 attempts, 0 models online
08:2x   0 attempts, 0 models online
```

Every run ended `SUITE_RC=0 / GREEN / fails=0` **while three phases SKIPPED** for want of a live
stream. That pair of facts is the thing this module is about: the suite is honest precisely
because those two verdicts are different, and the temptation it must resist is to let a skip
quietly satisfy a criterion that asked for a pass.

The goal this project runs under says it directly -- *closing by deleting a check or simply
skipping is not allowed*. This file makes that a theorem instead of a habit.

The key definition is `zeroSkipGreen`: it requires no failures **and** no skips. `isGreen` alone
is weaker, and `green_with_skips_is_not_zero_skip_green` proves it is strictly weaker by
exhibiting the exact state four runs produced today.
-/

namespace CtbrecSpec.SkipAlgebra

/-- The outcome of a single phase. Three values, not two -- collapsing `skipped` into either of
the others is the defect this module exists to forbid. -/
inductive Outcome where
  | passed
  | failed
  | skipped
deriving DecidableEq, Repr

/-- A suite run is the list of its phase outcomes. -/
abbrev Run := List Outcome

def failures (r : Run) : Nat := (r.filter (· == Outcome.failed)).length
def skips    (r : Run) : Nat := (r.filter (· == Outcome.skipped)).length
def passes   (r : Run) : Nat := (r.filter (· == Outcome.passed)).length

/-- What `SPEC-CHECK GREEN` means: nothing failed. Note it says nothing about skips. -/
def isGreen (r : Run) : Bool := failures r == 0

/-- What the goal actually asked for: nothing failed AND nothing was skipped. -/
def zeroSkipGreen (r : Run) : Bool := failures r == 0 && skips r == 0

/-! ## The theorems -/

/-- **A zero-skip green is green.** The strong verdict implies the weak one. -/
theorem zero_skip_green_is_green (r : Run) (h : zeroSkipGreen r = true) : isGreen r = true := by
  simp [zeroSkipGreen, isGreen] at *
  exact h.1

/-- **Green does NOT imply zero-skip green.** Exhibited by the exact state measured on every run
today: some phases passed, none failed, three skipped. This is why the goal's criterion was
reported unmet while the suite reported GREEN -- both were true, and they are not the same claim. -/
theorem green_with_skips_is_not_zero_skip_green :
    let today : Run := [Outcome.passed, Outcome.skipped, Outcome.skipped, Outcome.skipped]
    isGreen today = true ∧ zeroSkipGreen today = false := by
  decide

/-- **Turning a skip into a pass is exactly the forbidden move**, and it is detectable: it raises
the pass count without any phase having been checked. Stated over an arbitrary run so it covers
every future instance of the temptation, not today's three. -/
theorem laundering_a_skip_inflates_passes (r : Run) :
    passes (Outcome.skipped :: r) < passes (Outcome.passed :: r) := by
  simp [passes, List.filter_cons]

/-- **Deleting a skipped phase also fakes the criterion.** Dropping the phase makes
`zeroSkipGreen` true without anything being verified -- the other forbidden shortcut. -/
theorem deleting_a_skip_fakes_the_criterion :
    let withSkip : Run := [Outcome.passed, Outcome.skipped]
    let deleted  : Run := [Outcome.passed]
    zeroSkipGreen withSkip = false ∧ zeroSkipGreen deleted = true ∧ passes deleted = passes withSkip := by
  decide

/-- **A skip is never a failure either.** The honest reading is a third state: the check did not
run. Reporting a skip as RED would be its own dishonesty, and would push a future maintainer to
delete the phase to get back to green. -/
theorem a_skip_is_not_a_failure (r : Run) :
    failures (Outcome.skipped :: r) = failures r := by
  simp [failures, List.filter_cons]

/-- **A run with no skips has its criterion decided by failures alone** -- so once a live stream
exists, nothing else stands between this suite and the goal's criterion. -/
theorem without_skips_green_is_the_whole_criterion (r : Run) (h : skips r = 0) :
    zeroSkipGreen r = isGreen r := by
  simp [zeroSkipGreen, isGreen, h]

/-! ## Executable checks -/

private def today : Run := [Outcome.passed, Outcome.skipped, Outcome.skipped, Outcome.skipped]

#guard isGreen today == true
#guard zeroSkipGreen today == false
#guard skips today == 3
#guard failures today == 0
#guard passes today == 1
#guard zeroSkipGreen [Outcome.passed, Outcome.passed] == true
#guard isGreen [Outcome.failed] == false
#guard zeroSkipGreen [] == true

end CtbrecSpec.SkipAlgebra
