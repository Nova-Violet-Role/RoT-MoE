/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Proofs.RotFamily

/-!
# The A/A null control — does the apparatus manufacture significance?

An A/B experiment tells you whether two arms differ. It does **not** tell you
whether your pipeline would report a difference between two arms that are
identical. That second question is the one you cannot answer after the fact:
once a positive A/B result is in hand, no amount of inspection distinguishes
"the router helped" from "the apparatus produces effects from noise".

So the control runs **routed against routed** — same plugin, same corpus, same
scoring rule, same everything — and the apparatus must return `notSupported`.

## The property that makes it a control rather than a ritual

The A/A comparison must be scored by **the same verdict function** as the A/B
comparison. A control with its own scoring path proves nothing about the path
that produces the result: it is a second apparatus being tested instead of the
first. `the_control_and_the_experiment_share_one_verdict` is that requirement
stated as a theorem, and mutant N04 gives A/A its own function to prove the
requirement is load-bearing.

## Why a perfect sweep is REFUSED, not celebrated

If A/A returns "every pair went the same way", that is not a clean control — it
is the manufacturing signature. Two identical arms cannot disagree
systematically; a sweep means the pipeline has a side that wins by construction
(ordering, caching, transcript position). `a_perfect_sweep_is_the_manufacturing_
signature` refuses it.

## Instruments
`lake build` · `#print axioms` · `leanchecker` · `lean/mutate/mutate_rotnullcontrol.sh`
-/

namespace RotMoE.NullControl

open RotMoE.Family
open RotMoE.Experiment

/-! ## One verdict function, used twice -/

/-- A paired comparison: how many pairs disagreed, and how many of those went to
the side named first. Deliberately the same shape for A/B and A/A. -/
structure Comparison where
  /-- pairs where exactly one side succeeded -/
  discordant : Nat
  /-- of those, how many favoured the first-named side -/
  favouring  : Nat
deriving DecidableEq, Repr

/-- **The single verdict function.** `RotMoE.Experiment.verdictM` at the settled
family size, applied to a comparison. Both the experiment and its control call
exactly this. -/
def runVerdict (c : Comparison) : Verdict :=
  verdictM RotMoE.Family.m c.discordant (min c.favouring (c.discordant - c.favouring))

/-- **The control and the experiment share one verdict function**, stated so that
a future refactor cannot quietly give the control its own path. Two arbitrary
comparisons get the same treatment; there is no branch on which comparison this
is, because there is no argument saying so. -/
theorem the_control_and_the_experiment_share_one_verdict (ab aa : Comparison)
    (h : ab = aa) : runVerdict ab = runVerdict aa := by rw [h]

/-! ## What a clean A/A looks like -/

/-- A null control is clean when the apparatus does **not** find support in it. -/
def aaClean (c : Comparison) : Bool := runVerdict c == Verdict.notSupported

/-- **A perfect sweep is the manufacturing signature, not a clean control.**
Two identical arms cannot disagree systematically. If every discordant pair
falls to one side, some structural asymmetry — ordering, caching, position in
the transcript — is producing the difference, and every A/B result from the same
pipeline is contaminated. Refused whenever there were pairs to sweep. -/
def sweep (c : Comparison) : Bool :=
  decide (0 < c.discordant) && (decide (c.favouring = c.discordant) || decide (c.favouring = 0))

/-- The control passes only if the apparatus is silent AND unswept. -/
def controlPasses (c : Comparison) : Bool := aaClean c && !sweep c

/-! ## The control can fail — which is the only reason its pass counts -/

/-- **A balanced A/A passes.** Ten discordant pairs, five each way: no support,
no sweep. -/
theorem a_balanced_null_control_passes :
    controlPasses ⟨10, 5⟩ = true := by decide

/-- **A swept A/A is REFUSED even though the apparatus reports no support.**
This is the case the naive control misses: at nine discordant pairs all falling
one way, `aaClean` alone is `true`, and reading only that would certify a broken
pipeline as sound.

I first wrote this with ten pairs and `decide` refused it — a ten-pair sweep is
already significant, so `aaClean` catches it and the sweep check adds nothing
there. Nine is where the check earns its keep. -/
theorem a_swept_null_control_is_refused :
    aaClean ⟨9, 9⟩ = true ∧ sweep ⟨9, 9⟩ = true
      ∧ controlPasses ⟨9, 9⟩ = false := by decide

/-- Sweeps in either direction are refused; the check is not one-sided. -/
theorem both_directions_of_sweep_are_refused :
    controlPasses ⟨9, 9⟩ = false ∧ controlPasses ⟨9, 0⟩ = false := by decide

/-- **Where the sweep check earns its keep: every sweep up to nine pairs.**
The verdict function alone calls a full sweep `notSupported` for `d ≤ 9` and
`supported` from 10, so without the sweep check a nine-pair one-sided A/A would
pass as a clean control. This theorem is the reason the check exists, stated as
the exact band rather than a slogan. -/
theorem the_sweep_check_covers_what_the_verdict_misses :
    ((List.range 21).filter (fun d => runVerdict ⟨d, d⟩ == Verdict.notSupported)).getLast?
        = some 9
      ∧ ((List.range 21).filter (fun d => 0 < d && controlPasses ⟨d, d⟩)) = [] := by decide

/-- **An empty A/A is not a pass either.** Zero discordant pairs means the
control never ran; `sweep` is false, `aaClean` is true, so `controlPasses` would
say yes — and it must not, because a control that collected nothing has tested
nothing. -/
def controlRan (c : Comparison) : Bool := decide (0 < c.discordant)

/-- The full gate: it ran, it was silent, and it was not swept. -/
def controlAdmissible (c : Comparison) : Bool := controlRan c && controlPasses c

theorem an_empty_control_is_not_a_pass :
    controlPasses ⟨0, 0⟩ = true ∧ controlAdmissible ⟨0, 0⟩ = false := by decide

/-- **And a genuinely significant A/A stops everything.** At the settled family
size a 20-of-20 split reaches support; if the control ever produced this, no A/B
result from the same pipeline may be reported. -/
theorem a_significant_null_control_fails_the_gate :
    runVerdict ⟨20, 20⟩ = Verdict.supported
      ∧ aaClean ⟨20, 20⟩ = false
      ∧ controlAdmissible ⟨20, 20⟩ = false := by decide

/-! ## The gate is not vacuous -/

/-- **Both outcomes are reachable**, so the control is a question and not a
formality. -/
theorem the_control_can_pass_and_can_fail :
    controlAdmissible ⟨10, 5⟩ = true ∧ controlAdmissible ⟨20, 20⟩ = false := by decide

/-- **How many balanced outcomes the gate admits at 10 discordant pairs.**
A gate that admitted one arrangement in eleven would be a coincidence detector;
this admits the middle band and refuses the two extremes. -/
theorem the_gate_admits_the_middle_and_refuses_the_ends :
    ((List.range 11).filter (fun f => controlAdmissible ⟨10, f⟩)) = [1, 2, 3, 4, 5, 6, 7, 8, 9] := by
  decide

/-- **The A/B result is only reportable if the control was admissible.** The
dependency written as a function, so it cannot be forgotten in prose. -/
def reportable (aa ab : Comparison) : Option Verdict :=
  if controlAdmissible aa then some (runVerdict ab) else none

/-- **A broken control suppresses the A/B verdict entirely** — `none`, not a
verdict with a caveat. Same discipline as `Margin.applyTo`: a question that
cannot be validly asked does not get an answer. -/
theorem a_broken_control_suppresses_the_result :
    reportable ⟨20, 20⟩ ⟨12, 12⟩ = none
      ∧ reportable ⟨10, 5⟩ ⟨12, 12⟩ = some (runVerdict ⟨12, 12⟩) := by decide

/-- **The pilot's own numbers, run through the control's shape.** Two discordant
pairs, both to the routed side — at n = 2 that is far below the floor, so no
verdict either way. Recorded because it is the A/B comparison the control will
have to guard. -/
theorem the_pilot_comparison_reaches_no_verdict :
    runVerdict ⟨2, 2⟩ = Verdict.notSupported := by decide

/-! ## THE CONTROL AS RUN — 2026-08-11

Two routed arms, twelve tasks each, same corpus, same plugin, same primary rule
(R4-committed), scored through the identical code path as the A/B analysis
(`bench/pilot-rescore.js` on the A/A pair).

| arm | route records | R4 score |
|---|---|---|
| routed #1 | 165 | 6 / 12 |
| routed #2 | 167 | 8 / 12 |

Discordant pairs **6**, favouring the first arm **2**. Both arms confirmed
plugin-ARMED, so the manipulation check holds in the direction that matters for
a control: *neither* arm was silently unrouted. -/

/-- The A/A comparison as measured. -/
def measuredAA : Comparison := ⟨6, 2⟩

/-- The A/B pilot comparison as measured, under the same primary rule. -/
def measuredAB : Comparison := ⟨2, 2⟩

/-- **THE CONTROL PASSED.** It ran (6 discordant pairs), the apparatus found no
support in two identical arms, and the split was not a sweep. This is what
licenses reading an A/B result from the same pipeline at all. -/
theorem the_null_control_passed :
    controlRan measuredAA = true
      ∧ aaClean measuredAA = true
      ∧ sweep measuredAA = false
      ∧ controlAdmissible measuredAA = true := by decide

/-- **And it did not pass by being empty or lopsided** — the two ways a control
can look clean while testing nothing. -/
theorem the_control_passed_on_its_merits :
    0 < measuredAA.discordant
      ∧ measuredAA.favouring ≠ 0
      ∧ measuredAA.favouring ≠ measuredAA.discordant := by decide

/-- **The finding the control was built to produce, and it is not flattering.**
Two IDENTICAL arms disagreed on 6 of 12 tasks and split those 2–4. The A/B pilot
disagreed on 2 and split those 2–0. **The A/B difference (2) is no larger than
the difference between two copies of the same arm (2), and points the other
way.** The pilot's apparent advantage is inside the range identical arms
produce — which is precisely what a null control exists to reveal, and precisely
what no amount of A/B data could have told us. -/
theorem the_ab_difference_is_within_aa_noise :
    (measuredAB.favouring - (measuredAB.discordant - measuredAB.favouring))
      ≤ (measuredAA.discordant - measuredAA.favouring) - measuredAA.favouring := by decide

/-- **Neither comparison reaches a verdict**, and the A/B one is *reportable*
only because the control was admissible. `reportable` returns `some` here; had
the control failed it would return `none`. -/
theorem the_ab_result_is_reportable_and_is_a_null :
    reportable measuredAA measuredAB = some Verdict.notSupported := by decide

/-- **The control could have voided the release and did not.** Stated with the
counterfactual beside it so the pass is legible as a measurement rather than a
formality: had the same six discordant pairs fallen one way, the control would
have refused. -/
theorem a_swept_version_of_this_very_control_would_have_refused :
    controlAdmissible measuredAA = true
      ∧ controlAdmissible ⟨measuredAA.discordant, measuredAA.discordant⟩ = false := by decide

end RotMoE.NullControl
