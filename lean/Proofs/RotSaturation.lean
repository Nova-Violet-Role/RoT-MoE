/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A corpus that cannot express a difference has not measured one

Five A/B corpora returned null on answer quality, and at least two of those
nulls say nothing about the router. They say something about the corpus:

| corpus | result | why it could not discriminate |
|---|---|---|
| `rotmoe-fact` | 84/84 both arms | **at the ceiling** — no better score is representable |
| `rotmoe-calib` | 1/80 in band | **against the floor** — almost no room to fall, noise dominates |

This module makes "the corpus could not have shown a difference" a *decidable
predicate you run before spending money*, instead of a post-hoc excuse. The
order matters and is the whole point: an admissibility rule chosen **after**
seeing the result is indistinguishable from discarding an inconvenient one.

Nothing here claims the router is better at anything. It claims only that some
measurements are incapable of answering the question, and says which ones by
arithmetic.

## What is proved

* `saturated_pair_is_a_tie` — two arms both at the ceiling on the same
  denominator record *identical* scores, whatever their true quality is. The
  84/84 null was structurally guaranteed.
* `ceiling_admits_no_improvement` — at the ceiling, no valid score beats you.
* `headroom_admits_improvement` / `headroom_admits_regression` — with room, a
  better and a worse score both *exist*. Both directions, because a corpus that
  can only show a win is not a measurement either.
* `circular_selection_forces_the_ceiling` — selecting the tasks the router
  already won drives the score to 100% by construction.
* `margin_zero_admits_everything` — the admissibility gate with a zero margin
  passes every corpus, i.e. an instrument that cannot fail. Stated as a theorem
  so the parameter can never be quietly set to 0.
-/

namespace RotMoE.Saturation

/-- A score on a bounded scale: `hits` out of `outOf`. -/
structure Score where
  hits  : Nat
  outOf : Nat
deriving DecidableEq, Repr

/-- A score is well formed when it does not exceed its own denominator. -/
def valid (s : Score) : Bool := s.hits ≤ s.outOf

/-- Room to improve. -/
def up (s : Score) : Nat := s.outOf - s.hits

/-- Room to regress. -/
def down (s : Score) : Nat := s.hits

/-- Nothing better is representable. -/
def atCeiling (s : Score) : Bool := s.outOf ≤ s.hits

/-- Nothing worse is representable. -/
def atFloor (s : Score) : Bool := s.hits == 0

/-! ### The ceiling -/

/-- **At the ceiling nothing can beat you.** Any valid score on the same
denominator is at most this one — so an arm that is better in truth cannot
show it. -/
theorem ceiling_admits_no_improvement (s t : Score)
    (hc : atCeiling s = true) (hv : valid t = true) (he : t.outOf = s.outOf) :
    t.hits ≤ s.hits := by
  simp [atCeiling] at hc
  simp [valid] at hv
  omega

/-- **The 84/84 null was guaranteed before the run started.** Two arms both at
the ceiling on the same denominator record *the same number*, whatever their
real quality. This is the theorem that says the `rotmoe-fact` result is not
evidence of equality. -/
theorem saturated_pair_is_a_tie (a b : Score)
    (ha : atCeiling a = true) (hb : atCeiling b = true)
    (hva : valid a = true) (hvb : valid b = true)
    (he : a.outOf = b.outOf) : a.hits = b.hits := by
  simp [atCeiling] at ha hb
  simp [valid] at hva hvb
  omega

/-- The mirror image: at the floor, nothing can be worse. A corpus pinned to
the floor cannot show a regression, so it cannot exonerate either. -/
theorem floor_admits_no_regression (s t : Score)
    (hf : atFloor s = true) : s.hits ≤ t.hits := by
  simp [atFloor] at hf
  omega

/-! ### Headroom, in both directions -/

/-- With room above, a strictly better score exists. -/
theorem headroom_admits_improvement (s : Score) (h : 0 < up s) :
    ∃ t : Score, valid t = true ∧ t.outOf = s.outOf ∧ s.hits < t.hits := by
  have h' : s.hits < s.outOf := by simp [up] at h; omega
  refine ⟨⟨s.hits + 1, s.outOf⟩, ?_, rfl, Nat.lt_succ_self _⟩
  simp [valid]
  omega

/-- With room below, a strictly worse score exists. Both directions are
required: a corpus on which the routed arm can only tie or win is not measuring
quality, it is measuring its own construction. -/
theorem headroom_admits_regression (s : Score) (h : 0 < down s) (hv : valid s = true) :
    ∃ t : Score, valid t = true ∧ t.outOf = s.outOf ∧ t.hits < s.hits := by
  have h' : 0 < s.hits := by simp [down] at h; omega
  simp [valid] at hv
  refine ⟨⟨s.hits - 1, s.outOf⟩, ?_, rfl, by show s.hits - 1 < s.hits; omega⟩
  simp [valid]
  omega

/-! ### The admissibility gate

`m` is a **margin**: how much room the pilot must leave in each direction
before the corpus is allowed to carry a verdict. It is a design parameter and
must be fixed in the pre-registration, never after seeing an outcome. -/

/-- Admissible with margin `m`: at least `m` room in BOTH directions. -/
def admissibleBy (m : Nat) (p : Score) : Bool :=
  decide (m ≤ up p) && decide (m ≤ down p)

/-- **An instrument that cannot fail proves nothing, stated as a theorem.**
With a zero margin every corpus is admissible — including 84/84. The parameter
can therefore never be silently set to 0 and called a check. -/
theorem margin_zero_admits_everything (p : Score) : admissibleBy 0 p = true := by
  simp [admissibleBy]

/-- Raising the margin can only admit fewer corpora — so a margin cannot be
loosened after the fact without the change being visible as a smaller `m`. -/
theorem admissibleBy_antitone {m n : Nat} (h : m ≤ n) (p : Score)
    (hn : admissibleBy n p = true) : admissibleBy m p = true := by
  simp [admissibleBy] at hn ⊢
  omega

/-- An admissible corpus (margin ≥ 1) has room in both directions, hence both a
better and a worse score exist. This is the property the gate is buying. -/
theorem admissible_can_express_both (p : Score) (hv : valid p = true)
    (h : admissibleBy 1 p = true) :
    (∃ t : Score, valid t = true ∧ t.outOf = p.outOf ∧ p.hits < t.hits) ∧
    (∃ t : Score, valid t = true ∧ t.outOf = p.outOf ∧ t.hits < p.hits) := by
  simp [admissibleBy] at h
  exact ⟨headroom_admits_improvement p (by omega), headroom_admits_regression p (by omega) hv⟩

/-- A corpus at the ceiling is refused by the gate at any margin ≥ 1. -/
theorem ceiling_is_inadmissible (p : Score) (hv : valid p = true)
    (hc : atCeiling p = true) : admissibleBy 1 p = false := by
  simp [atCeiling] at hc
  simp [valid] at hv
  have hup : up p = 0 := by simp [up]; omega
  simp [admissibleBy, hup]

/-! ### Circular selection

Choosing the task set by the outcome guarantees the outcome. -/

/-- One A/B trial. -/
structure Trial where
  task       : Nat
  routedWins : Bool
deriving DecidableEq, Repr

/-- Keep only the trials the routed arm already won. -/
def selectWinners (ts : List Trial) : List Trial := ts.filter (fun t => t.routedWins)

/-- Score a task set by how many the routed arm won. -/
def winRate (ts : List Trial) : Score :=
  ⟨(ts.filter (fun t => t.routedWins)).length, ts.length⟩

/-- Everything that survives the selection is a win — trivially, and that is
the problem. -/
theorem circular_selection_cannot_lose (ts : List Trial) :
    ∀ t ∈ selectWinners ts, t.routedWins = true := by
  intro t ht
  simp [selectWinners, List.mem_filter] at ht
  exact ht.2

/-- **Selecting on the outcome forces a perfect score.** The measurement is
then guaranteed before it runs, which is why the task set has to be fixed in
the pre-registration. -/
theorem circular_selection_forces_the_ceiling (ts : List Trial) :
    atCeiling (winRate (selectWinners ts)) = true := by
  simp [atCeiling, winRate, selectWinners, List.filter_filter]

/-- And the gate refuses it, without anyone having to notice the circularity by
eye. -/
theorem circular_selection_is_inadmissible (ts : List Trial) :
    admissibleBy 1 (winRate (selectWinners ts)) = false := by
  simp [admissibleBy, up, winRate, selectWinners, List.filter_filter]

/-! ### The corpora that actually ran

MEASURED values, not illustrations. These `#guard`s execute the predicate on
the real numbers from `bench/`. -/

/-- MEASURED: `rotmoe-fact`, both arms 84 of 84. -/
def factCorpus : Score := ⟨84, 84⟩

/-- MEASURED: `rotmoe-calib`, 1 of 80 inside the band. -/
def calibCorpus : Score := ⟨1, 80⟩

/-- MEASURED: `rotmoe-trap` rep2, 59 of 88. -/
def trapCorpus : Score := ⟨59, 88⟩

/-- The margin P2.4 will pre-register: 10% of the denominator in each
direction, so a corpus must be able to move by at least 8 of 80 either way. -/
def preregMargin : Nat := 8

-- At the ceiling: refused, and refused at every margin including 1.
#guard admissibleBy 1 factCorpus = false
#guard admissibleBy preregMargin factCorpus = false
#guard atCeiling factCorpus = true
#guard up factCorpus = 0

-- Against the floor: passes a margin of 1, refused at the pre-registered one.
-- This is exactly the case a naive "is there any headroom" rule would have
-- waved through, and it returned a null.
#guard admissibleBy 1 calibCorpus = true
#guard admissibleBy preregMargin calibCorpus = false
#guard down calibCorpus = 1

-- The trap corpus had real room in both directions -- so its null is a fact
-- about the router or the corpus content, NOT about saturation. It is not
-- excused by this module, and P2.2 stays open.
#guard admissibleBy preregMargin trapCorpus = true
#guard up trapCorpus = 29
#guard down trapCorpus = 59

end RotMoE.Saturation
