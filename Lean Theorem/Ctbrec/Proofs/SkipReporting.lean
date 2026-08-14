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
# A COUNTER THAT CAN READ ZERO ON A NON-ZERO RUN IS NOT A CRITERION

Measured 2026-08-08, 22:5x. With three live LL-HLS streams the suite printed:

```
SUITE_RC=0   SPEC-CHECK GREEN   fails=0 skips=0 lines=2063
```

and `skips=0` was **FALSE**. Line 2062 of the same output read:

```
NOTE: 1 phase(s) SKIPPED for want of a live stream -- rerun while recording
```

The counter is `grep -c '^SKIPPED'`. Anchored `SKIPPED` lines appear in SOME runs — that is where the
earlier `skips=4` came from — but this run reported its skip only as prose in the verdict block. The
counter therefore read **zero on a run that skipped a phase**.

This is the most dangerous instrument failure of the session because **it fails toward SUCCESS**.
Every other one that day failed loudly (`bc` absent -> everything reads 0 and looks alarming;
`strings` on a class file -> a field looks missing; word-splitting -> nonsense class names). This one
would have produced a fabricated zero-skip green, the one output this project treats as unforgivable.

`SkipAlgebra.lean` already proves *green with skips is not zero-skip green*. That is not enough: it
assumes the skip COUNT is known. This module is about the layer beneath — **whether the number you
counted is the number that happened.**

The repair proved here: a report is trustworthy only when the observable forms are **cross-checked**,
and the safe reading of disagreement is the MAXIMUM, never the convenient zero.
-/

namespace CtbrecSpec.SkipReporting

/-- What a suite run actually did, and what each reporting surface showed. -/
structure Run where
  /-- Ground truth: phases that abstained. Not directly observable by the harness. -/
  trueSkips : Nat
  /-- Count of anchored `^SKIPPED` lines. Zero when the run uses prose instead. -/
  anchored : Nat
  /-- Count parsed from the `NOTE: n phase(s) SKIPPED ...` verdict line. -/
  noteLine : Nat
  /-- Whether the suite's own verdict said GREEN. -/
  green : Bool
deriving DecidableEq, Repr

/-- A run is **faithfully reported** when at least one surface shows the true number. -/
def faithful (r : Run) : Prop := r.anchored = r.trueSkips ∨ r.noteLine = r.trueSkips

/-- The old reader: trust the anchored grep alone. -/
def oldReader (r : Run) : Nat := r.anchored

/-- The repaired reader: take the MAXIMUM of the surfaces. Disagreement must never resolve
downward — the convenient reading is the one that fabricates a green. -/
def safeReader (r : Run) : Nat := max r.anchored r.noteLine

/-- The harness may only claim zero-skip when the safe reader says zero AND the verdict is green. -/
def claimsZeroSkipGreen (r : Run) : Bool := r.green && safeReader r == 0

/-! ## The measured run -/

/-- The actual 22:5x run: one phase skipped, anchored counter blind to it, NOTE line correct. -/
def run2263 : Run := { trueSkips := 1, anchored := 0, noteLine := 1, green := true }

/-- **The false zero, exactly as it happened**: the old reader says zero on a run that skipped. -/
theorem old_reader_reported_a_false_zero :
    oldReader run2263 = 0 ∧ run2263.trueSkips = 1 := by
  decide

/-- **The repair catches it**: the safe reader recovers the true count, so no zero-skip is claimed. -/
theorem safe_reader_catches_it :
    safeReader run2263 = 1 ∧ claimsZeroSkipGreen run2263 = false := by
  decide

/-! ## The general theorems — quantified, so they are laws and not facts about one run -/

/-- **The old reader is unsound in the fatal direction**: for ANY run whose skip is reported only in
prose, it reads zero regardless of how many phases actually abstained. -/
theorem old_reader_is_blind_to_prose (n : Nat) (g : Bool) :
    oldReader { trueSkips := n, anchored := 0, noteLine := n, green := g } = 0 := by
  rfl

/-- **The safe reader never under-reports** a faithfully reported run. This is the property that
makes it safe: it can overestimate, never fabricate a zero. -/
theorem safe_reader_never_under_reports (r : Run) (h : faithful r) :
    r.trueSkips ≤ safeReader r := by
  rcases h with h | h
  · exact h ▸ Nat.le_max_left r.anchored r.noteLine
  · exact h ▸ Nat.le_max_right r.anchored r.noteLine

/-- **Therefore a zero-skip claim implies there really were no skips** — the theorem the harness
needs, and the one the old reader could not support. -/
theorem zero_skip_claim_is_sound (r : Run) (h : faithful r)
    (hc : claimsZeroSkipGreen r = true) : r.trueSkips = 0 := by
  have h0 : safeReader r = 0 := by
    simp [claimsZeroSkipGreen] at hc
    exact hc.2
  have := safe_reader_never_under_reports r h
  omega

/-- The old reader does NOT support that conclusion — `run2263` is the counterexample. -/
theorem old_reader_cannot_support_the_claim :
    ∃ r : Run, faithful r ∧ r.green = true ∧ oldReader r = 0 ∧ r.trueSkips ≠ 0 := by
  refine ⟨run2263, ?_, rfl, rfl, by decide⟩
  right; rfl

/-- **Disagreement between surfaces is itself the alarm.** Whenever the two disagree, the safe
reader is strictly greater than the smaller one, so a cross-check can always fire. -/
theorem disagreement_is_detectable (r : Run) (h : r.anchored ≠ r.noteLine) :
    min r.anchored r.noteLine < safeReader r := by
  unfold safeReader
  omega

/-! ## Executable checks -/

#guard oldReader run2263 == 0
#guard safeReader run2263 == 1
#guard claimsZeroSkipGreen run2263 == false
#guard claimsZeroSkipGreen { trueSkips := 0, anchored := 0, noteLine := 0, green := true } == true
#guard claimsZeroSkipGreen { trueSkips := 0, anchored := 0, noteLine := 0, green := false } == false
#guard safeReader { trueSkips := 4, anchored := 4, noteLine := 0, green := true } == 4
#guard safeReader { trueSkips := 4, anchored := 0, noteLine := 4, green := true } == 4
#guard claimsZeroSkipGreen { trueSkips := 4, anchored := 0, noteLine := 4, green := true } == false

end CtbrecSpec.SkipReporting
