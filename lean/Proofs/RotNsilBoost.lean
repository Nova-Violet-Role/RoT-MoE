/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # BOOST and OVERRIDE: the two NSIL decisions the shell owed the model

`lean/Proofs/RotRoute.lean:181` has carried a five-constructor `Decision` since
the router was written — `confirm`, `override`, `boost`, `fuse`, `elevate`. Only
three of them were ever *taken* by the shell. This module is about the two that
were finally implemented on 2026-08-13, and specifically about the mistake made
implementing one of them, because that mistake is the interesting part.

## The ordering bug, stated as a theorem

BOOST raises a single λ by `+0.3`. Profile selection *replaces* the whole λ
vector. Both happen on a boosted turn, so there are two possible orders, and the
first draft picked the wrong one:

* boost, then mount the profile → the profile overwrites the boost, which
  **vanishes**;
* mount the profile, then boost → the boost survives.

The live symptom was a route line reading `[NSIL BOOST Soleil]` beside a gauge
record carrying Soleil's *unboosted* `2.5`. The router announced a decision it
had not acted on. That is worse than not implementing BOOST at all: a marker is
evidence, and this one was false.

`boost_does_not_commute_with_select` is the durable statement of why. It is not
a note in a comment that the next refactor deletes — it is a proof that the two
operations genuinely disagree, so any future rearrangement that reintroduces the
old order has a theorem standing in front of it.

## What is deliberately NOT claimed

Nothing here says the shell performs these operations in the proved order. Lean
cannot see a POSIX script. The binding is `checker/cross-diff.sh`, which runs
both arms over a corpus and requires byte-identical output, plus the measured
control in the commit message: boosted `2.8` against an unboosted `2.5` on the
same lens. Those are MEASURED. What is PROVED is that the order *matters* — which
is the fact that makes the measurement worth taking.
-/

namespace RotMoE.NsilBoost

/-! ## λ vectors in integer hundredths

The shell stores λ as integer hundredths precisely so the two arms cannot drift
on a rounding rule, and this model uses the same representation rather than ℚ.
Modelling in ℚ would prove a theorem about arithmetic the implementation does not
perform, which is the standard way a proof ends up true and irrelevant. -/

/-- A lens's weight, in hundredths. `250` is λ = 2.50. -/
abbrev Hund := Nat

/-- §3: *"a single λ rises surgically (+0.3 typical)"*. Quoted, not tuned. -/
def boostStep : Hund := 30

/-- BOOST applied to one weight. -/
def applyBoost (l : Hund) : Hund := l + boostStep

/-- Mounting a profile REPLACES the weight; it does not adjust it. This is the
whole reason the order matters, and it is why `select` takes the incoming value
and ignores it. -/
def applySelect (_old profileValue : Hund) : Hund := profileValue

/-! ## The two orders -/

/-- Boost first, then mount the profile — the first draft's order. -/
def boostThenSelect (start profileValue : Hund) : Hund :=
  applySelect (applyBoost start) profileValue

/-- Mount the profile, then boost — the shipped order. -/
def selectThenBoost (start profileValue : Hund) : Hund :=
  applyBoost (applySelect start profileValue)

/-! ## What the shipped order guarantees -/

/-- The shipped order really does raise the profile's own value by the step.
A boosted STEALTH Soleil rises from her STEALTH 2.5, never from another table's
opinion of Soleil. -/
theorem select_then_boost_raises_profile_value (s p : Hund) :
    selectThenBoost s p = p + boostStep := rfl

/-- **The boost is visible in the shipped order** — strictly greater than the
profile value, for every profile value. Stated as a strict inequality rather
than about one lens, so it cannot expire when a weight changes. -/
theorem select_then_boost_strictly_increases (s p : Hund) :
    p < selectThenBoost s p := by
  simp [selectThenBoost, applySelect, applyBoost, boostStep]

/-- **The bug, exactly.** In the discarded order the boost leaves no trace: the
result is the profile value, indistinguishable from a turn that was never
boosted. This is the theorem that makes the false marker impossible to
reintroduce quietly. -/
theorem boost_then_select_loses_the_boost (s p : Hund) :
    boostThenSelect s p = p := rfl

/-- **The two orders disagree.** Not a comment, a proof — for every starting
value and every profile value, the orders differ, so this is not an edge case
that a lucky weight makes harmless. -/
theorem boost_does_not_commute_with_select (s p : Hund) :
    boostThenSelect s p ≠ selectThenBoost s p := by
  simp [boostThenSelect, selectThenBoost, applySelect, applyBoost, boostStep]

/-- The discarded order is observationally identical to **not boosting at all**.
This is the sharpest way to say what went wrong: the router was not computing a
smaller boost, it was computing no boost while reporting one. -/
theorem boost_then_select_equals_no_boost (s p : Hund) :
    boostThenSelect s p = applySelect s p := rfl

/-! ## OVERRIDE moves the lead; BOOST does not

§3's table gives OVERRIDE *"lead changes; new lead's λ dominates"* and BOOST
*"right mode, one lens underweighted"* — the mode is right, so the lead stays.
Getting these two backwards would be invisible in a route line, so they are
pinned here. -/

/-- A lane, reduced to what these two decisions care about. -/
inductive Lane where
  | empathic | clinical | stealth | forge
deriving DecidableEq, Repr

/-- OVERRIDE replaces the lane outright. -/
def afterOverride (_tier1 : Lane) (newLane : Lane) : Lane := newLane

/-- BOOST leaves the lane exactly as TIER 1 found it. -/
def afterBoost (tier1 : Lane) : Lane := tier1

/-- **BOOST never moves the lead** — for every lane, without exception. -/
theorem boost_preserves_the_lane (l : Lane) : afterBoost l = l := rfl

/-- **OVERRIDE does move the lead** when the new lane differs. Stated with the
difference as a hypothesis rather than over two fixed constants, so it stays
true if the lane set grows. -/
theorem override_changes_the_lane (t n : Lane) (h : t ≠ n) :
    afterOverride t n ≠ t := fun hc => h hc.symm

/-- The spec's own worked example, executable: `fix our relationship` fires a
technical stem and a human one, and OVERRIDE lands on EMPATHIC rather than
blending. -/
theorem the_worked_example_lands_empathic :
    afterOverride Lane.clinical Lane.empathic = Lane.empathic := rfl

/-- The two decisions are genuinely different operations — a router that
implemented one and called it the other would be caught here. -/
theorem override_and_boost_differ :
    afterOverride Lane.clinical Lane.empathic ≠ afterBoost Lane.clinical := by
  decide

/-! ## Executable checks

Decidable statements get executed, not just proved: a definition that does not
mean what its author thinks compiles perfectly. -/

/-- STEALTH Soleil: 2.50 → 2.80 in the shipped order. The exact value measured
live in the route record. -/
example : selectThenBoost 0 250 = 280 := by decide

/-- The same lens in the discarded order: 2.50, the boost gone without trace. -/
example : boostThenSelect 0 250 = 250 := by decide

#guard selectThenBoost 0 250 == 280
#guard boostThenSelect 0 250 == 250
#guard selectThenBoost 60 230 == 260   -- EMPATHIC Violet, boosted from HER 2.3
#guard decide (afterBoost Lane.stealth = Lane.stealth)

end RotMoE.NsilBoost
