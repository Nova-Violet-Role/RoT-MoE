/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

import Proofs.RotTrap

/-!
# Why one ordering cannot attribute a speedup, and two can

`bench/trap-latency.js` measured the routed arm 44.7% faster and then REFUSED to
say the router caused it, because the arms run sequentially against the same
files and whichever runs second reads from a warm page cache. That refusal was a
convention in a script. This file makes it a theorem.

The model is deliberately small, because the claim is about **identifiability**,
not about milliseconds. Each turn's duration is a base cost plus two additive
effects:

* `armEffect` — what the ROUTER changes (negative means faster)
* `posEffect` — what running SECOND changes (negative means faster: warm cache)

Under a single ordering the two effects appear only in a **sum**, so infinitely
many pairs produce identical observations: the measurement is real and the
attribution is not. Run both orderings and the same two unknowns appear in two
independent combinations, which determines them.

That is the whole argument for the control, and `attribution_needs_both_orderings`
is the reason the script must not emit a verdict from half the data.

The concrete numbers that motivated this are in `bench/trap-latency-controlled.json`:
routed faster 55/60 a-first and 56/60 b-first, so `posEffect` cannot be carrying
the result. Nothing here proves that; it proves what such a pair of runs is
CAPABLE of establishing.
-/

namespace RotOrdering

/-- The two arms. -/
inductive Arm where
  | unrouted
  | routed
  deriving DecidableEq, Repr

/-- Which position in the sequence a turn ran at. -/
inductive Pos where
  | first
  | second
  deriving DecidableEq, Repr

/-- A causal model: a base cost, the router's effect, and the effect of running
second. Integers, because an effect may be negative (faster). -/
structure Model where
  base      : Int
  armEffect : Int
  posEffect : Int
  deriving DecidableEq, Repr

/-- Predicted duration of one turn. The routed arm pays `armEffect`; a turn in
second position pays `posEffect`. Additive by construction — that is the
assumption, and it is the assumption that makes the sum non-identifiable. -/
def duration (m : Model) (a : Arm) (p : Pos) : Int :=
  m.base
    + (match a with | .unrouted => 0 | .routed => m.armEffect)
    + (match p with | .first => 0 | .second => m.posEffect)

/-- What an a-first run observes: the gap `routed − unrouted`, where unrouted ran
first and routed ran second. -/
def gapAFirst (m : Model) : Int :=
  duration m .routed .second - duration m .unrouted .first

/-- What a b-first run observes: the same gap, with the positions swapped. -/
def gapBFirst (m : Model) : Int :=
  duration m .routed .first - duration m .unrouted .second

theorem gapAFirst_eq (m : Model) : gapAFirst m = m.armEffect + m.posEffect := by
  simp [gapAFirst, duration]; omega

theorem gapBFirst_eq (m : Model) : gapBFirst m = m.armEffect - m.posEffect := by
  simp [gapBFirst, duration]; omega

/-! ## One ordering cannot attribute -/

/-- **The refusal, as a theorem.** Two models that disagree completely about the
cause — one where the router does everything and position does nothing, one
where position does everything and the router does nothing — produce the SAME
a-first observation. A single ordering therefore cannot distinguish them, and a
verdict drawn from it is not supported by the data. -/
theorem one_ordering_cannot_attribute :
    ∃ m₁ m₂ : Model,
      gapAFirst m₁ = gapAFirst m₂ ∧
      m₁.armEffect ≠ m₂.armEffect ∧
      m₁.posEffect ≠ m₂.posEffect := by
  refine ⟨⟨0, -100, 0⟩, ⟨0, 0, -100⟩, ?_, ?_, ?_⟩ <;> decide

/-- Sharper: for ANY observed a-first gap there is a model attributing it
entirely to the router and another attributing it entirely to position. The
ambiguity is not a quirk of one witness; it is total. -/
theorem every_gap_has_a_pure_router_and_a_pure_position_explanation (g : Int) :
    ∃ mRouter mPos : Model,
      gapAFirst mRouter = g ∧ mRouter.posEffect = 0 ∧
      gapAFirst mPos = g ∧ mPos.armEffect = 0 := by
  refine ⟨⟨0, g, 0⟩, ⟨0, 0, g⟩, ?_, rfl, ?_, rfl⟩ <;> simp [gapAFirst_eq]

/-! ## Two orderings do attribute -/

/-- With both orderings the two unknowns are determined: their sum and their
difference are both observed. This is why the control is worth running rather
than merely worth mentioning. -/
theorem two_orderings_determine_both_effects (m₁ m₂ : Model)
    (hA : gapAFirst m₁ = gapAFirst m₂) (hB : gapBFirst m₁ = gapBFirst m₂) :
    m₁.armEffect = m₂.armEffect ∧ m₁.posEffect = m₂.posEffect := by
  rw [gapAFirst_eq, gapAFirst_eq] at hA
  rw [gapBFirst_eq, gapBFirst_eq] at hB
  constructor <;> omega

/-- And the effects are recoverable by arithmetic, not merely pinned down:
`2·armEffect` is the sum of the two gaps, `2·posEffect` their difference. -/
theorem effects_are_recoverable (m : Model) :
    gapAFirst m + gapBFirst m = 2 * m.armEffect ∧
    gapAFirst m - gapBFirst m = 2 * m.posEffect := by
  rw [gapAFirst_eq, gapBFirst_eq]; constructor <;> omega

/-! ## The specific alternative the control had to exclude -/

/-- A pure page-cache world: the router costs nothing, running second is what
saves time. In that world the arm that runs SECOND is faster — so in a b-first
run the UNROUTED arm would come out ahead. -/
def pureCacheWorld : Model := ⟨1000, 0, -400⟩

/-- A pure router world: position is free, the router is what saves time. Here
the routed arm is faster in BOTH orderings. -/
def pureRouterWorld : Model := ⟨1000, -400, 0⟩

/-- The two worlds are indistinguishable a-first — this is exactly why the
measurement was reported UNATTRIBUTED. -/
theorem the_two_worlds_agree_a_first :
    gapAFirst pureCacheWorld = gapAFirst pureRouterWorld := by decide

/-- And they disagree b-first, which is what makes the control decisive: under
the cache explanation the routed arm is SLOWER when it runs first. -/
theorem the_two_worlds_disagree_b_first :
    gapBFirst pureCacheWorld ≠ gapBFirst pureRouterWorld := by decide

/-- In the cache world the b-first gap is positive: routed running first would
be measurably WORSE. The observed run had it faster, so this world is excluded
by the data rather than by assumption. -/
theorem cache_world_predicts_routed_is_slower_when_it_runs_first :
    0 < gapBFirst pureCacheWorld := by decide

/-- In the router world the b-first gap stays negative: routed is faster whether
it runs first or second. That is the pattern actually observed. -/
theorem router_world_predicts_routed_is_faster_in_both_orderings :
    gapAFirst pureRouterWorld < 0 ∧ gapBFirst pureRouterWorld < 0 := by decide

/-! ## Executable witnesses -/

#guard gapAFirst pureCacheWorld = -400
#guard gapAFirst pureRouterWorld = -400
#guard gapBFirst pureCacheWorld = 400
#guard gapBFirst pureRouterWorld = -400
#guard duration pureRouterWorld .routed .first = 600
#guard duration pureRouterWorld .unrouted .first = 1000
#guard duration pureCacheWorld .routed .first = 1000
#guard duration pureCacheWorld .unrouted .second = 600

/-- A mixed world: the router helps AND the cache helps. Both orderings still
recover both numbers, which is the general case rather than the two extremes. -/
def mixedWorld : Model := ⟨1000, -300, -100⟩

#guard gapAFirst mixedWorld = -400
#guard gapBFirst mixedWorld = -200
#guard gapAFirst mixedWorld + gapBFirst mixedWorld = 2 * (-300)
#guard gapAFirst mixedWorld - gapBFirst mixedWorld = 2 * (-100)

/-- The mixed world is a-first-indistinguishable from BOTH pure worlds: all
three predict a gap of −400. Three incompatible causal stories, one number. -/
theorem three_worlds_one_a_first_observation :
    gapAFirst mixedWorld = gapAFirst pureRouterWorld ∧
    gapAFirst mixedWorld = gapAFirst pureCacheWorld := by decide

/-- Yet all three are separated b-first. -/
theorem three_worlds_separate_b_first :
    gapBFirst mixedWorld ≠ gapBFirst pureRouterWorld ∧
    gapBFirst mixedWorld ≠ gapBFirst pureCacheWorld := by decide

end RotOrdering
