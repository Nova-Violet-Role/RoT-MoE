/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# The second metric, its own confound, and what the A/B is actually allowed to say

`RotAbVerdict` records that the compliance metric's advantage was a BREVITY
effect. `bench/ab-grounding.js` was written to answer it with a metric brevity
cannot fake -- citation precision, a RATIO:

    precision = citations that exist on disk / citations the answer makes

Measured 2026-08-09 on the same 88 paired turns, against 1349 declared names:

    precision      routed 0.947 (71/75)     unrouted 0.837 (149/178)
    hallucinating  routed 4 turns           unrouted 23 turns
    silent         routed 35 turns          unrouted 16 turns
    per turn       routed 1.42 citations    unrouted 2.47
    paired (48)    routed 8, unrouted 0, ties 40,  p = 0.0078

That looks like a win, and it was nearly reported as one. It is not.

## The selectivity confound

A ratio is immune to raw length. It is NOT immune to CLAIM VOLUME: an arm that
asserts less has fewer chances to be wrong. The routed arm asserts 1.42 items
per turn against 2.47, and says nothing checkable on 35 turns against 16.

So hold volume constant -- compare only turns where both arms cited the SAME
NUMBER of items:

    volume-matched pairs 18:  routed better 0, unrouted better 0, ties 18
    p = 1.0,  survivesSelectivity = FALSE

**All eighteen tied.** With claim volume fixed, the two arms are
indistinguishable. The precision advantage is selectivity, not accuracy.

## What IS established, stated at its real strength and no higher

Absolute false statements reaching the user: **4 routed against 29 unrouted**,
a sevenfold reduction, achieved by saying less and choosing better when to
speak. Per-claim reliability: indistinguishable (18/18 ties).

That is a real property and a modest one. It is NOT "the lenses overhaul how the
model thinks". Two independent metrics have now each produced an advantage that
dissolved under its own control -- brevity for compliance, selectivity for
grounding -- and this module exists so the third reader does not rediscover the
headline and quote it.
-/

namespace RotMoE.Grounding

/-- One paired turn under the grounding metric. -/
structure Pair where
  routedCited   : Nat
  routedValid   : Nat
  unroutedCited : Nat
  unroutedValid : Nat
deriving DecidableEq, Repr

/-- Volume is matched when both arms asserted the same number of checkable
claims. Only then is a comparison free of the selectivity confound. -/
def volumeMatched (p : Pair) : Bool := p.routedCited == p.unroutedCited

/-- On a volume-matched pair, "better" means strictly more TRUE claims. -/
def routedBetter (p : Pair) : Bool := volumeMatched p && p.unroutedValid < p.routedValid

/-- The measured volume-matched outcome: 18 pairs, 0 wins either way. -/
def vmPairs : Nat := 18
def vmRoutedBetter : Nat := 0
def vmUnroutedBetter : Nat := 0

/-- A comparison establishes an advantage only if it is volume-matched AND the
matched comparison is decisive. `p = 1.0` on 0 vs 0 is not decisive. -/
def establishesAdvantage (better worse : Nat) : Bool := 0 < better && worse < better

section TheMeasuredVerdict

/-- THE result of the second metric: no advantage survives volume matching. -/
theorem grounding_establishes_no_advantage :
    establishesAdvantage vmRoutedBetter vmUnroutedBetter = false := by decide

/-- All eighteen matched pairs tied, so neither arm can claim them. -/
theorem all_matched_pairs_tied :
    vmRoutedBetter + vmUnroutedBetter = 0 ∧ vmPairs = 18 := by decide

/-- The unmatched headline (8-0, p = 0.0078) coexists with the matched null.
Quoting the first without the second is the overclaim this file prevents. -/
theorem unmatched_win_coexists_with_matched_null :
    8 > 0 ∧ establishesAdvantage vmRoutedBetter vmUnroutedBetter = false := by decide

end TheMeasuredVerdict

section TheRuleIsNotVacuous

/-- The rule CAN establish an advantage, so its refusal carries information. -/
theorem advantage_is_reachable : establishesAdvantage 7 2 = true := by decide

/-- Zero wins never establishes anything, however few the losses. -/
theorem zero_wins_never_establishes (worse : Nat) :
    establishesAdvantage 0 worse = false := by
  simp [establishesAdvantage]

/-- A tie never establishes an advantage. -/
theorem ties_establish_nothing (n : Nat) : establishesAdvantage n n = false := by
  simp [establishesAdvantage]

/-- An unmatched pair can NEVER count as a routed win, whatever the valid
counts. This is the selectivity control expressed as a theorem: comparing arms
that made different numbers of claims is not evidence. -/
theorem unmatched_pairs_are_not_evidence (p : Pair) (h : volumeMatched p = false) :
    routedBetter p = false := by
  simp [routedBetter, h]

/-- And matching alone is not sufficient -- equal valid counts still lose. -/
theorem matched_but_equal_is_not_better (p : Pair)
    (hm : volumeMatched p = true) (he : p.routedValid = p.unroutedValid) :
    routedBetter p = false := by
  simp [routedBetter, hm, he]

end TheRuleIsNotVacuous

section Measured

#guard establishesAdvantage vmRoutedBetter vmUnroutedBetter = false
#guard establishesAdvantage 7 2 = true
#guard establishesAdvantage 3 3 = false
#guard volumeMatched ⟨2, 2, 2, 1⟩ = true
#guard volumeMatched ⟨1, 1, 3, 2⟩ = false
#guard routedBetter ⟨2, 2, 2, 1⟩ = true
-- the selectivity trap: routed cites less and is perfect, unrouted cites more
-- and is mostly right. NOT a routed win, because volume differs.
#guard routedBetter ⟨1, 1, 5, 4⟩ = false
-- absolute false statements, the one thing that IS established: 4 vs 29
#guard 75 - 71 = 4
#guard 178 - 149 = 29

end Measured

end RotMoE.Grounding
