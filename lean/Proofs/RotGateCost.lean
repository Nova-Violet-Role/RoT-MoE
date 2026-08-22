/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/
import Proofs.RotGates

/-!
# The cost of a commit — why one lucky commit cannot clear the ceiling

## Why this file exists

`checker/gate-all.sh` opens with a bound written as prose:

> a pre-commit hook that takes four minutes is a hook people disable -- which
> would leave the fast checks unenforced too, a net loss.

Nothing asserts it. It was measured by hand on 2026-08-01, recorded in a
comment, and never re-measured. `RotGates.lean` proves which gates run; no file
proved what that costs, so the ceiling drifted in silence and the drift was
invisible to every gate in the suite.

## The trap this file closes

The obvious way to check the hook's cost is to time a commit. That measurement
is worthless on its own, and the reason is structural rather than statistical:
a commit that stages one file escalates few deep gates, so it is CHEAP, and the
next commit that touches `hooks/` is not. Timing the cheap one and concluding
the hook is fine is the mistake this file makes impossible to state.

`RotGates.fast_always_runs` already proves every fast gate runs on every
commit. The consequence nobody had drawn is that the fast tier is therefore a
FLOOR under every commit's cost — `fast_cost_is_a_floor` below. So if the fast
tier alone breaches the ceiling, EVERY commit breaches it, whatever was staged
and however lucky the sample: `every_commit_breaches`. That turns a noisy
wall-clock question into a decidable one about a single number.

## The measurement this file records

Timed per gate on this machine, 2026-08-22, one run each (an ordering that is
stable; individual milliseconds that are not):

* fast tier, 47 gates: **358.9 s**, of which the top 8 own 236 s = 66%
* whole `--fast` run: 364.7 s, so the runner's own loop costs 5.8 s
* ceiling, from the header prose: 240 s

`checker/gate-all.sh` reads `ceilingSec` out of THIS file rather than repeating
the number, the same `lean_const` discipline `checker/bench-router.sh` uses for
`msBound`. A constant written in two places is a constant that will disagree
with itself.

## On the historical figures

The 2026-08-01 numbers below describe the table AS IT THEN STOOD — 28 gates.
Today's table has 71. `impliedFastAfterSplit` is therefore what the split
PROJECTED for the old table, not a claim that the same gates have since slowed
down; most of the regrowth is gates added afterwards. Said here because the
arithmetic is checkable and the interpretation is not.
-/

namespace RotMoE.GateCost

open RotMoE.Gates

/-! ## The cost model -/

/-- What one gate costs, in whatever unit the caller measures. Left abstract on
purpose: every theorem below holds for seconds, milliseconds, spawned
processes, or any other additive cost, so none of them can be dodged by
changing the unit. -/
abbrev Cost := Gate → Nat

/-- The cost of running a set of gates. -/
def totalCost (c : Cost) (gs : List Gate) : Nat := (gs.map c).sum

/-! ## The floor

Both `fastSet` and `stagedRun` are filters of the same table, and everything
`fastSet` keeps, `stagedRun` keeps too. Cost is a sum over what is kept, so the
inequality is really a statement about filters — proved that way, so it holds
for any pair of predicates in that relation, not just these two. -/

/-- A finer filter never costs more. -/
theorem filter_cost_mono (c : Cost) (p q : Gate → Bool)
    (hpq : ∀ g, p g = true → q g = true) (gs : List Gate) :
    totalCost c (gs.filter p) ≤ totalCost c (gs.filter q) := by
  induction gs with
  | nil => simp [totalCost]
  | cons g gs ih =>
    simp only [totalCost] at ih ⊢
    by_cases hp : p g = true
    · have hq : q g = true := hpq g hp
      simp only [List.filter_cons, hp, hq, if_true, List.map_cons, List.sum_cons]
      omega
    · simp only [Bool.not_eq_true] at hp
      by_cases hq : q g = true
      · simp only [List.filter_cons, hp, hq, if_true, if_false, List.map_cons,
          List.sum_cons, Bool.false_eq_true]
        omega
      · simp only [Bool.not_eq_true] at hq
        simp only [List.filter_cons, hp, hq, if_false, Bool.false_eq_true]
        omega

/-- **The fast tier is a floor under every commit.** Whatever the commit staged,
it paid at least the cost of the gates that always run. This is the cost-side
reading of `RotGates.fast_always_runs`. -/
theorem fast_cost_is_a_floor (c : Cost) (gs : List Gate) (staged : List (List Char)) :
    totalCost c (fastSet gs) ≤ totalCost c (stagedRun gs staged) := by
  unfold fastSet stagedRun
  exact filter_cost_mono c _ _ (fun g h => by simp [h]) gs

/-! ## The ceiling -/

/-- The bound the runner's header states, in seconds. `checker/gate-all.sh`
extracts this line; do not restate the number anywhere else. -/
def ceilingSec : Nat := 240

/-- Measured 2026-08-22, summing one timed run of each of the 47 fast gates. -/
def measuredFastSec : Nat := 359

/-- Measured the same day: the whole `--fast` invocation, end to end. -/
def measuredFastRunSec : Nat := 365

/-- **The fast tier alone is over the ceiling.** -/
theorem the_fast_tier_breaches_the_ceiling : ceilingSec < measuredFastSec := by decide

/-- **Therefore every commit is over the ceiling** — no staged file set can
rescue it, because none of them can decline the fast tier. This is the theorem
that makes a single timed commit an inadmissible defence. -/
theorem every_commit_breaches (c : Cost) (gs : List Gate) (staged : List (List Char))
    (h : ceilingSec < totalCost c (fastSet gs)) :
    ceilingSec < totalCost c (stagedRun gs staged) :=
  Nat.lt_of_lt_of_le h (fast_cost_is_a_floor c gs staged)

/-- The runner's own loop overhead: the gap between the end-to-end run and the
sum of its parts. Small, and recorded so that a future gap that is NOT small is
visible as a change rather than absorbed into the gate figures. -/
theorem the_runner_overhead_is_six_seconds :
    measuredFastRunSec - measuredFastSec = 6 := by decide

/-! ## What the 2026-08-01 split actually did -/

/-- The whole suite, timed per gate on 2026-08-01, over the 28-gate table. -/
def measuredTotalAtSplit : Nat := 587

/-- The four gates moved to `deep` by that split: mutate the checker, axiom
audit, axiom class, release install. -/
def movedToDeepSec : Nat := 198 + 94 + 84 + 71

/-- Those four owned 76% of the old suite. -/
theorem the_four_gates_owned_seventy_six_percent :
    movedToDeepSec * 100 / measuredTotalAtSplit = 76 := by decide

/-- What the split left behind, on the table as it then stood. -/
def impliedFastAfterSplit : Nat := measuredTotalAtSplit - movedToDeepSec

/-- **The split worked.** It landed the projected fast tier under the ceiling,
with 100 seconds of headroom. The tier split was not a failed fix. -/
theorem the_split_landed_under_the_ceiling : impliedFastAfterSplit < ceilingSec := by decide

/-- **And it has since drifted back over.** 140 s projected, 359 s measured
today — see the note above on why this is regrowth of the table rather than
proof that any individual gate slowed down. -/
theorem the_fast_tier_has_since_grown : impliedFastAfterSplit < measuredFastSec := by decide

/-- The size of the drift, in seconds. -/
theorem the_drift_since_the_split : measuredFastSec - impliedFastAfterSplit = 219 := by decide

/-- The drift alone is larger than the headroom the split bought. -/
theorem the_drift_exceeds_the_headroom :
    ceilingSec - impliedFastAfterSplit < measuredFastSec - impliedFastAfterSplit := by decide

/-! ## Why timing one commit cannot settle it

The floor theorem says a commit costs AT LEAST the fast tier. It deliberately
says nothing about an upper bound, and this witness shows why: two commits
against the same table can cost different amounts, so a single measurement is a
sample of the cheapest case, never a bound on the expensive one. -/

/-- A two-gate table: one fast and cheap, one deep and expensive. -/
def witnessTable : List Gate :=
  [ { name := "cheap".toList,     tier := Tier.fast, triggers := [] }
  , { name := "expensive".toList, tier := Tier.deep, triggers := ["hooks/".toList] } ]

/-- The cost assignment for that table: the deep gate costs 200, everything
else costs 1. -/
def witnessCost : Cost := fun g => if g.tier = Tier.deep then 200 else 1

/-- A commit touching nothing relevant pays 1. -/
theorem an_untriggered_commit_is_cheap :
    totalCost witnessCost (stagedRun witnessTable ["README.md".toList]) = 1 := by decide

/-- A commit touching `hooks/` pays 201 against the same table. -/
theorem a_triggered_commit_is_expensive :
    totalCost witnessCost (stagedRun witnessTable ["hooks/rot-router.sh".toList]) = 201 := by decide

/-- **So one timed commit understates the next one by any margin you like.**
Measuring the cheap commit and reporting it as the hook's cost is not a noisy
estimate of the right number; it is the wrong number. -/
theorem one_commit_cannot_bound_another :
    totalCost witnessCost (stagedRun witnessTable ["README.md".toList]) <
      totalCost witnessCost (stagedRun witnessTable ["hooks/rot-router.sh".toList]) := by decide

/-- The floor, however, holds for both — which is why the ceiling check is
stated against the fast tier and not against any observed commit. -/
theorem the_floor_holds_for_both :
    totalCost witnessCost (fastSet witnessTable) ≤
        totalCost witnessCost (stagedRun witnessTable ["README.md".toList]) ∧
      totalCost witnessCost (fastSet witnessTable) ≤
        totalCost witnessCost (stagedRun witnessTable ["hooks/rot-router.sh".toList]) := by
  exact ⟨fast_cost_is_a_floor _ _ _, fast_cost_is_a_floor _ _ _⟩

end RotMoE.GateCost
