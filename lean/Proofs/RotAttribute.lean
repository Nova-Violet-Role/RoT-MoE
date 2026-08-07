/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A NULL RESULT CAN BE A PROPERTY OF THE ANALYSIS, NOT OF THE THING MEASURED

This module exists because of a mistake I made and then published.

The 80x2 A/B run was reported NULL on every pre-registered primary. That report
was wrong in two separate, independently sufficient ways, and both were found on
2026-08-07 by re-reading the raw transcripts the analysis had been derived from:

1. **The configuration was never carried through.** `bench/ab-metrics.jsonl`
   held `arm, turn, err, dur, cost_micro, len, q, hedge, narr, leak` and no
   model, no effort, no thinking level — so the verdict could not be attributed
   to any configuration and could not be stratified afterwards. The information
   was not missing from the experiment: the raw turns carried `modelUsage` all
   along. It was dropped by the derivation.

2. **The metrics that were looked at were not the metrics that moved.** With the
   configuration recovered (`claude-opus-5[1m]`, all 160 turns), the paired
   difference in OUTPUT TOKENS is -34.1%, routed fewer on 64 of 80, two-sided
   sign test p = 5.9e-8. The three primaries genuinely tied. The run was not
   null; the analysis was blind.

Neither failure is exotic and neither is specific to A/B testing. Both are
statements about summaries, and both are theorems. They are stated here so the
harness can be checked against them instead of against my memory of what went
wrong.
-/

import Mathlib.Data.Rat.Defs
import Mathlib.Data.List.Basic
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.Ring
import Mathlib.Tactic.NormNum

namespace RotAttribute

/-! ## §1 A summary computed from erased records is blind to what was erased

The trivial-looking direction first, because it is the one that bites: **any**
summary function whatsoever, applied to records that no longer carry a field,
returns the same answer for two datasets that differ only in that field. There
is no cleverness available afterwards — the verdict is not merely hard to
attribute, it is *provably independent* of the dropped column. -/

/-- One measured turn: which lane routed it, which arm it belongs to, and the
number the analysis will look at. -/
structure Sample where
  /-- The routed lane — the field the round-1 corpus dropped. -/
  lane : Nat
  /-- `true` = routed arm, `false` = unrouted control. -/
  routed : Bool
  /-- The measured endpoint. -/
  value : ℚ
  deriving DecidableEq, Repr

/-- What the round-1 corpus kept: the number, and nothing that identifies the
stratum it came from. -/
def erase (s : Sample) : ℚ := s.value

/-- **Erasure is final.** If two datasets erase to the same list, then *every*
summary — mean, median, sign count, an as-yet-unwritten one — agrees on them.
No later analysis can recover the distinction. -/
theorem erased_summary_is_blind (f : List ℚ → ℚ) (d₁ d₂ : List Sample)
    (h : d₁.map erase = d₂.map erase) :
    f (d₁.map erase) = f (d₂.map erase) := by
  rw [h]

/-- The lane column, which a stratified analysis reads and a pooled one cannot. -/
def lanes (d : List Sample) : List Nat := d.map Sample.lane

/-- **The blindness is not hypothetical.** `erased_summary_is_blind` came back
depending on no axioms at all — the honest reading of which is that it is nearly
a tautology, and a tautology is not evidence. This is the load-bearing form:
there exist two datasets that **every** erased summary must score identically
while a lane-aware reading separates them outright. The information is present
in the experiment and unreachable from the corpus. -/
theorem erasure_hides_information_a_lane_aware_reading_has :
    ∃ d₁ d₂ : List Sample,
      d₁.map erase = d₂.map erase ∧ lanes d₁ ≠ lanes d₂ := by
  refine ⟨[{ lane := 1, routed := true, value := 5 }],
          [{ lane := 2, routed := true, value := 5 }], rfl, ?_⟩
  simp only [lanes, List.map_cons, List.map_nil]
  decide

/-- And the hypothesis is satisfiable by datasets that are genuinely different:
same numbers, different lanes. So the theorem above is not vacuous — this is the
exact shape of the round-1 corpus. -/
theorem erasure_loses_a_real_distinction :
    ∃ d₁ d₂ : List Sample, d₁ ≠ d₂ ∧ d₁.map erase = d₂.map erase := by
  refine ⟨[{ lane := 1, routed := true, value := 5 }],
          [{ lane := 2, routed := true, value := 5 }], ?_, rfl⟩
  simp only [ne_eq, List.cons.injEq, and_true, Sample.mk.injEq]
  intro h
  exact absurd h (by decide)

/-! ## §2 Pooling can REVERSE what every stratum says

The second failure is sharper than "we lost a column". Even with the data in
hand, a pooled comparison can report the opposite of what holds in every single
stratum, when the strata are unequally sized. This is Simpson's paradox, and it
is the mechanical reason a nine-lane router must be scored **per lane**: nine
lanes averaged together can show nothing while each lane shows something.

The instance below is concrete and checked, not cited. -/

/-- Arithmetic mean of a list of rationals; `0` for the empty list. -/
def mean (xs : List ℚ) : ℚ := xs.sum / xs.length

/-- Lane 1, routed arm: one cheap turn. -/
def lane1Routed : List ℚ := [10]
/-- Lane 1, control: nine turns, each worse than the routed one. -/
def lane1Control : List ℚ := [20, 20, 20, 20, 20, 20, 20, 20, 20]
/-- Lane 2, routed arm: nine turns. -/
def lane2Routed : List ℚ := [100, 100, 100, 100, 100, 100, 100, 100, 100]
/-- Lane 2, control: one turn, worse than the routed ones. -/
def lane2Control : List ℚ := [110]

/-- Routed wins lane 1 outright. -/
theorem routed_wins_lane1 : mean lane1Routed < mean lane1Control := by
  simp only [mean, lane1Routed, lane1Control]
  norm_num

/-- Routed wins lane 2 outright. -/
theorem routed_wins_lane2 : mean lane2Routed < mean lane2Control := by
  simp only [mean, lane2Routed, lane2Control]
  norm_num

/-- **And pooled, routed LOSES** — the same data, one number, opposite verdict.
A pooled null (or a pooled loss) is therefore not evidence of no effect. It is
evidence that pooling was the wrong operation. -/
theorem pooling_reverses_every_stratum :
    mean (lane2Control ++ lane1Control) < mean (lane1Routed ++ lane2Routed) := by
  simp only [mean, lane1Routed, lane1Control, lane2Routed, lane2Control]
  norm_num

/-! ### The reversal is caused by the IMBALANCE, and here is the control

A paradox instance on its own does not identify a cause. Mutant A05 was written
to check that — it rebalanced one arm and expected the reversal to collapse. It
**survived**, because a one-sided rebalance does not remove the imbalance, it
relocates it. The surviving mutant was the useful one: it showed the module had
demonstrated the effect without demonstrating its cause.

So the control is stated explicitly. Give the two strata equal sizes in **both**
arms, change nothing else, and the pooled verdict now AGREES with the strata.
The reversal above is therefore attributable to unequal stratum sizes, not to
the particular numbers chosen. -/

/-- Lane 1, routed arm, balanced: nine turns instead of one. -/
def lane1RoutedBal : List ℚ := [10, 10, 10, 10, 10, 10, 10, 10, 10]
/-- Lane 2, control, balanced: nine turns instead of one. -/
def lane2ControlBal : List ℚ := [110, 110, 110, 110, 110, 110, 110, 110, 110]

/-- **The control.** Same values, same per-stratum verdicts, equal sizes — and
pooling now reports what every stratum reports. Contrast with
`pooling_reverses_every_stratum`: the only difference between the two is how
many turns each stratum contributed. -/
theorem balanced_pooling_agrees_with_the_strata :
    mean (lane1RoutedBal ++ lane2Routed) < mean (lane1Control ++ lane2ControlBal) := by
  simp only [mean, lane1RoutedBal, lane1Control, lane2Routed, lane2ControlBal]
  norm_num

/-- The three together, as one statement: routed is strictly better in **every**
stratum and strictly worse pooled. -/
theorem stratified_and_pooled_disagree :
    mean lane1Routed < mean lane1Control
    ∧ mean lane2Routed < mean lane2Control
    ∧ mean (lane2Control ++ lane1Control) < mean (lane1Routed ++ lane2Routed) :=
  ⟨routed_wins_lane1, routed_wins_lane2, pooling_reverses_every_stratum⟩

/-! ## §3 A tie on the metrics you chose is not a tie

The third shape, and the one that actually produced the false null: the three
primaries were constant across both arms while a fourth quantity, measurable
from the very same records, differed on 64 of 80 pairs. A verdict that reads
"no difference" from a metric set that happens not to vary is reporting the
metric set, not the world. -/

/-- A turn as round 1 actually summarised it: three primaries plus the output
tokens the analysis never extracted. -/
structure Turn where
  /-- Trailing-question indicator (primary 6). -/
  q : Nat
  /-- Self-narration count (primary 8). -/
  narr : Nat
  /-- Output tokens — present in the raw transcript, absent from the corpus. -/
  outTok : Nat
  deriving DecidableEq, Repr

/-- The projection the round-1 analysis used. -/
def primaries (t : Turn) : Nat × Nat := (t.q, t.narr)

/-- **Two turns can agree on every primary and differ where it counts.** -/
theorem primaries_can_tie_while_the_turn_differs :
    ∃ a b : Turn, primaries a = primaries b ∧ a.outTok ≠ b.outTok := by
  refine ⟨{ q := 0, narr := 0, outTok := 447 },
          { q := 0, narr := 0, outTok := 678 }, rfl, ?_⟩
  decide

/-- The measured pair, kept as an executable record: 447 vs 678 mean output
tokens per turn, routed against control, on `claude-opus-5[1m]`. -/
def measuredRoutedMeanTokens : Nat := 447
/-- Control arm, same 80 prompts. -/
def measuredControlMeanTokens : Nat := 678

/-- The direction of the measured effect, pinned so a later edit that flips it
has to flip this too. This is a record of a MEASUREMENT, not a proof that the
router causes it — the experiment is the instrument for that, and it is named
in the doc comment above. -/
theorem measured_routed_emits_fewer_tokens :
    measuredRoutedMeanTokens < measuredControlMeanTokens := by decide

/-! ## §4 What follows for the harness

Three obligations, each the direct consequence of a theorem above:

* **Carry the configuration.** `erased_summary_is_blind` says no later analysis
  can recover it. `checker/ab-analyze.sh` now records `model` per turn.
* **Score per lane.** `pooling_reverses_every_stratum` says a pooled figure can
  contradict every stratum. Nine lanes pooled into one mean is exactly that
  shape.
* **Justify the metric set, or report it as the limit of the claim.**
  `primaries_can_tie_while_the_turn_differs` says a tie is a statement about the
  projection. `outTok` is now extracted; the claim reaches as far as the metrics
  that were actually computed and no further.

None of this makes the router better. It makes the measurement honest, which is
the only thing that can establish whether the router is better. -/

/-- A dataset that carries its lane can still be pooled — the theorems above are
about what pooling COSTS, not a claim that pooling is unavailable. -/
def poolValues (d : List Sample) : List ℚ := d.map erase

/-- Pooling a stratified dataset is exactly erasure, which is why the cost is
the same. -/
theorem pooling_is_erasure (d : List Sample) : poolValues d = d.map erase := rfl

end RotAttribute
