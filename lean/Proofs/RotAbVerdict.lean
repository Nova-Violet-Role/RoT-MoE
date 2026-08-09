/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# The A/B verdict rule, and why the headline number must not be quoted alone

Measured 2026-08-09, 88 paired prompts, both arms 88/88 valid turns, arm A
session-joined as ROUTED (576 route records on the final slice) and arm B
verified UNROUTED (zero records carrying its session id):

    turns 88
    violations   routed 15   unrouted 40
    headline     routed wins 29, unrouted wins 4, ties 55,  p = 1.09e-5
    deconfounded explained-by-brevity 27, unexplained 2, losses 4, p = 0.6875
    survivesDeconfounding = FALSE

**The headline is real and the headline is not the result.** Routing cut
instruction violations from 40 to 15 on the same 88 prompts, and on a sign test
that is overwhelming. But the compliance metric is "answer in one or two
sentences", and 27 of the 29 routed wins occurred on turns where the routed
answer was simply SHORTER. Shorter text trivially contains fewer sentences. Once
those are removed, the routed arm holds 2 unexplained wins against 4 losses --
n = 6, p = 0.69, which is no evidence in either direction.

So the honest statement, and the one this module makes load-bearing:

> On this corpus and this metric, routing measurably improves instruction
> compliance, and that improvement is NOT distinguishable from an effect of
> producing shorter answers.

This module exists so that conclusion survives contact with a future reader who
wants to quote `29 wins, p = 0.00001`. `headline_can_be_huge_while_verdict_fails`
proves those two facts are compatible, so the headline alone can never carry the
claim.

## What is NOT measured here

Answer quality, correctness, or usefulness. The corpus scores sentence-count
compliance. A model that answers "no" to everything would score perfectly. That
limitation is the metric's, is stated in the pre-registration, and is not
repaired by any theorem below.
-/

namespace RotMoE.AbVerdict

/-- One paired turn: did each arm violate the length instruction, and how long
were the two answers. -/
structure Turn where
  routedViolates   : Bool
  unroutedViolates : Bool
  routedLen        : Nat
  unroutedLen      : Nat
deriving DecidableEq, Repr

def routedWin  (t : Turn) : Bool := !t.routedViolates && t.unroutedViolates
def routedLoss (t : Turn) : Bool := t.routedViolates && !t.unroutedViolates

/-- A win is EXPLAINED when the routed answer was shorter: fewer sentences then
follows from less text, so the win is not evidence about reasoning. -/
def explainedByBrevity (t : Turn) : Bool := routedWin t && t.routedLen < t.unroutedLen

/-- A win counts as evidence only when the routed answer was NOT shorter. -/
def unexplainedWin (t : Turn) : Bool := routedWin t && t.unroutedLen ≤ t.routedLen

/-- The verdict rule, exactly as `bench/ab-compliance.js:99` computes it. -/
def survives (unexplained losses : Nat) : Bool := losses < unexplained

/-- The measured corpus, as three counts. -/
def measuredUnexplained : Nat := 2
def measuredLosses      : Nat := 4
def measuredHeadlineWins : Nat := 29

section TheMeasuredVerdict

/-- THE result: the routed advantage does not survive deconfounding. -/
theorem measured_does_not_survive :
    survives measuredUnexplained measuredLosses = false := by decide

/-- The headline is large at the same time. Both facts hold together, which is
exactly why quoting the first without the second misleads. -/
theorem headline_can_be_huge_while_verdict_fails :
    29 ≤ measuredHeadlineWins ∧ survives measuredUnexplained measuredLosses = false := by
  decide

end TheMeasuredVerdict

section TheRuleIsNotVacuous

/-- The rule CAN pass -- otherwise "it failed" would carry no information. -/
theorem verdict_can_pass : survives 5 2 = true := by decide

/-- Equality is not enough: ties do not establish an advantage. -/
theorem ties_do_not_survive (n : Nat) : survives n n = false := by
  simp [survives]

/-- A corpus in which every win is explained by brevity can never survive,
whatever the headline count -- there is no unexplained evidence to beat the
losses. -/
theorem all_brevity_never_survives (losses : Nat) :
    survives 0 losses = false := by
  simp [survives]

/-- Zero losses and at least one unexplained win DOES survive: the rule is not
rigged to always fail. -/
theorem clean_evidence_survives (u : Nat) (h : 0 < u) : survives u 0 = true := by
  simp [survives, h]

end TheRuleIsNotVacuous

section WinAndLossAreExclusive

/-- A turn cannot be both a win and a loss. Without this the counts could
double-count and the verdict would be arithmetic on nonsense. -/
theorem win_and_loss_exclusive (t : Turn) :
    ¬ (routedWin t = true ∧ routedLoss t = true) := by
  intro h
  obtain ⟨hw, hl⟩ := h
  simp [routedWin] at hw
  simp [routedLoss, hw.1] at hl

/-- Every win is either explained by brevity or unexplained -- the partition is
total, so no win is silently discarded. -/
theorem win_partition (t : Turn) (h : routedWin t = true) :
    explainedByBrevity t = true ∨ unexplainedWin t = true := by
  by_cases hlen : t.routedLen < t.unroutedLen
  · exact Or.inl (by simp [explainedByBrevity, h, hlen])
  · exact Or.inr (by simp [unexplainedWin, h]; omega)

/-- ...and no win is counted twice. -/
theorem win_partition_disjoint (t : Turn) :
    ¬ (explainedByBrevity t = true ∧ unexplainedWin t = true) := by
  intro h
  obtain ⟨he, hu⟩ := h
  simp [explainedByBrevity] at he
  simp [unexplainedWin] at hu
  omega

end WinAndLossAreExclusive

section Measured

#guard survives measuredUnexplained measuredLosses = false
#guard survives 5 2 = true
#guard survives 0 99 = false
#guard survives 3 3 = false
#guard routedWin  ⟨false, true, 100, 200⟩ = true
#guard routedLoss ⟨true, false, 100, 200⟩ = true
#guard explainedByBrevity ⟨false, true, 100, 200⟩ = true
#guard unexplainedWin     ⟨false, true, 200, 100⟩ = true
-- the measured split: 27 explained + 2 unexplained = 29 headline wins
#guard 27 + measuredUnexplained = measuredHeadlineWins

end Measured

end RotMoE.AbVerdict
