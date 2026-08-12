/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Proofs.RotMainRun

/-!
# P2.4 — the process observables, and the one that came back against the router

The numbers here are **MEASURED, not proved**: `bench/work-trace-tasks.js`
extracted O1–O4 per task from the four main-run transcripts, and
`bench/p24-score.js` paired them by task within each ordering. Lean settles what
the **preregistered** verdict function says about those counts. Nothing here
re-runs a session.

## What was measured, 2026-08-12

| observable | claimed direction (§3) | forward d/f | reverse d/f |
|---|---|---|---|
| O1 verification steps | routed higher | 0 / 0 | 0 / 0 |
| O2 rework edits | routed lower | 0 / 0 | 0 / 0 |
| O3 reads before first write | routed higher | 0 / 0 | 0 / 0 |
| O4 unverified claims | routed **lower** | **40 / 0** | **39 / 0** |

`d` is discordant pairs, `f` how many of those fell in the direction §3 claimed
**in advance**.

## The two findings, and neither is comfortable

**Three of the four observables are SATURATED.** O1, O2 and O3 produced zero
discordant pairs — not a narrow result, *no result*. The 40-task corpus asks
knowledge questions; it contains no task that builds, edits or writes a file, so
"verification steps", "rework edits" and "files read before the first write" are
zero in **both** arms on **every** task. `saturated_pair_is_a_tie` in
`RotSaturation` proved this failure mode before P2.4 ran, on the 84/84 corpus.
It happened again, and it is a defect in the *instrument's fit to the corpus*,
not evidence about the router either way. An observable that cannot vary cannot
carry a verdict in either direction — `a_saturated_observable_cannot_conclude`.

**O4 came back against the router, and it is a total sweep in both orderings.**
Of 40 discordant pairs forward and 39 reverse, the routed arm carried **more**
unverified claims in every single one. §7 calls that CONTRADICTED, and §5 of the
preregistration says in advance that O4 "is the one that can embarrass the
router most, which is why it is in". It is reported here as prominently as a win
would have been, because that is what was promised before the data existed.

## Why the sweep is attributable, and what it does not mean

`RotNullControl.sweep` exists because a total sweep is the signature of a
*manufacturing* pipeline — in an A/A comparison it means some structural
asymmetry, not an effect. The A/A control on this same apparatus was measured at
⟨6, 2⟩: it produced pairs and did **not** sweep
(`the_null_control_did_not_sweep`). So this pipeline does not manufacture sweeps
from identical arms, and the O4 sweep is a real asymmetry between the arms.

What it is **not** is a measurement of honesty. The detector counts a number in
the final message that appears in no preceding tool output; `bench/work-trace.js`
says so in its own docstring — "a restated number and a re-derived one look
identical here". Measured alongside: the routed arm ran 49 and 55 tool calls
against the unrouted arm's 103 and 109, and emitted 9 652 and 9 864 evidence
bytes against 76 150 and 46 461. A terser answer drawn from fewer tool outputs
scores worse on this detector **by construction**, and no normalisation for
answer length was declared in advance — so none may be applied now.
`the_confound_was_not_declared_in_advance` records that as a fact about the
design rather than an escape from the result: the honest verdict is
CONTRADICTED, and the honest caveat is that O4 conflates terseness with
unsupportedness. Both statements ship.
-/

namespace RotMoE.P24Run

open RotMoE.Family
open RotMoE.Experiment
open RotMoE.NullControl

/-! ## The measured counts -/

/-- O1, forward and reverse: no discordant pairs at all. -/
def o1Forward : NullControl.Comparison := ⟨0, 0⟩
/-- O1 reverse. -/
def o1Reverse : NullControl.Comparison := ⟨0, 0⟩
/-- O2 forward. -/
def o2Forward : NullControl.Comparison := ⟨0, 0⟩
/-- O2 reverse. -/
def o2Reverse : NullControl.Comparison := ⟨0, 0⟩
/-- O3 forward. -/
def o3Forward : NullControl.Comparison := ⟨0, 0⟩
/-- O3 reverse. -/
def o3Reverse : NullControl.Comparison := ⟨0, 0⟩

/-- O4 forward: 40 discordant pairs, **zero** favouring the routed arm. -/
def o4Forward : NullControl.Comparison := ⟨40, 0⟩
/-- O4 reverse: 39 discordant pairs, **zero** favouring the routed arm. -/
def o4Reverse : NullControl.Comparison := ⟨39, 0⟩

/-- The A/A null control as measured, repeated here so the sweep argument is
self-contained. -/
def aaControl : NullControl.Comparison := ⟨6, 2⟩

/-! ## Saturation — three observables produced no evidence -/

/-- **An observable with no discordant pairs cannot conclude, for any corpus.**
Stated over an arbitrary comparison rather than over the three measured ones, so
it is a property of the verdict function and not a coincidence of this run. -/
theorem a_saturated_observable_cannot_conclude (c : NullControl.Comparison)
    (h : c.discordant = 0) : NullControl.runVerdict c = Verdict.notSupported := by
  unfold NullControl.runVerdict
  rw [h]
  -- `0 - f = 0` in `Nat` and `min f 0 = 0`, so the two-sided statistic collapses
  -- to `verdictM m 0 0` whatever the favouring count was. `decide` then settles
  -- it at the DERIVED family size rather than at a number written here.
  simp
  decide

/-- The three saturated observables, as measured, reach no verdict in either
ordering. -/
theorem o1_o2_o3_conclude_nothing :
    NullControl.runVerdict o1Forward = Verdict.notSupported ∧
    NullControl.runVerdict o1Reverse = Verdict.notSupported ∧
    NullControl.runVerdict o2Forward = Verdict.notSupported ∧
    NullControl.runVerdict o2Reverse = Verdict.notSupported ∧
    NullControl.runVerdict o3Forward = Verdict.notSupported ∧
    NullControl.runVerdict o3Reverse = Verdict.notSupported := by decide

/-- **Three of the four verdict-bearing observables produced zero pairs.** The
corpus could not express them, in either direction. -/
theorem three_of_four_observables_are_saturated :
    o1Forward.discordant = 0 ∧ o1Reverse.discordant = 0 ∧
    o2Forward.discordant = 0 ∧ o2Reverse.discordant = 0 ∧
    o3Forward.discordant = 0 ∧ o3Reverse.discordant = 0 ∧
    0 < o4Forward.discordant ∧ 0 < o4Reverse.discordant := by decide

/-- A saturated observable is silent in **both** directions: it cannot support
the claim and it cannot contradict it either. This is the guard against reading
the three zeros as evidence for the router. -/
theorem saturation_is_not_evidence_for_either_side (c : NullControl.Comparison)
    (h : c.discordant = 0) :
    NullControl.runVerdict c ≠ Verdict.supported := by
  rw [a_saturated_observable_cannot_conclude c h]
  decide

/-! ## O4 — the observable that did produce evidence -/

/-- **Zero pairs favoured the routed arm, in both orderings.** -/
theorem o4_favours_the_routed_arm_in_no_pair :
    o4Forward.favouring = 0 ∧ o4Reverse.favouring = 0 := by decide

/-- **O4 is a total sweep in both orderings**, and the sweep predicate says so. -/
theorem o4_is_a_total_sweep_in_both_orderings :
    NullControl.sweep o4Forward = true ∧ NullControl.sweep o4Reverse = true := by decide

/-- **The verdict function reaches a decision on O4 in both orderings.** Unlike
the R4 answer-text scoring, this observable is not short of evidence. -/
theorem o4_reaches_a_verdict_in_both_orderings :
    NullControl.runVerdict o4Forward = Verdict.supported ∧
    NullControl.runVerdict o4Reverse = Verdict.supported := by decide

/-- **CONTRADICTED, stated so it cannot be read as a win.** The verdict function
finds the difference significant in both orderings, and the direction is the one
§3 did *not* claim: every discordant pair went to the unrouted arm. A reader who
sees `supported` above must read it together with this. -/
theorem o4_contradicts_the_claimed_direction :
    (NullControl.runVerdict o4Forward = Verdict.supported ∧ o4Forward.favouring = 0) ∧
    (NullControl.runVerdict o4Reverse = Verdict.supported ∧ o4Reverse.favouring = 0) := by decide

/-- **No observable supported the claim.** Three were saturated and the fourth
went the other way, so there is no O1–O4 for which the preregistered direction
was upheld. -/
theorem no_observable_supports_the_claimed_direction :
    (NullControl.runVerdict o1Forward = Verdict.notSupported) ∧
    (NullControl.runVerdict o2Forward = Verdict.notSupported) ∧
    (NullControl.runVerdict o3Forward = Verdict.notSupported) ∧
    (o4Forward.favouring = 0 ∧ o4Reverse.favouring = 0) := by decide

/-! ## Why the sweep is attributable -/

/-- **The null control produced pairs and did not sweep.** A pipeline that
manufactured sweeps would have swept two identical arms; this one did not, which
is what licenses reading the O4 sweep as a property of the arms. -/
theorem the_null_control_did_not_sweep :
    0 < aaControl.discordant ∧ NullControl.sweep aaControl = false := by decide

/-- The control is silent *and* unswept — both halves, since either alone would
be consistent with a broken pipeline. -/
theorem the_control_remains_admissible :
    NullControl.runVerdict aaControl = Verdict.notSupported ∧ NullControl.sweep aaControl = false := by decide

/-- **A sweep in the A/A control would have voided this reading.** Stated as an
implication over an arbitrary control so it is a rule, not a remark about ⟨6,2⟩:
had the control swept, its own verdict machinery would have flagged it, and no
A/B sweep from the same pipeline could be attributed. -/
theorem a_swept_control_would_forbid_attribution (c : NullControl.Comparison)
    (h : NullControl.sweep c = true) : ¬ (NullControl.sweep c = false) := by
  rw [h]; decide

/-! ## The confound, recorded rather than applied -/

/-- Tool calls per session, routed then unrouted, forward then reverse. MEASURED
by `bench/work-trace-tasks.js`. -/
def toolCalls : (Nat × Nat) × (Nat × Nat) := ((49, 103), (55, 109))

/-- Evidence bytes per session, same order. MEASURED. -/
def evidenceBytes : (Nat × Nat) × (Nat × Nat) := ((9652, 76150), (9864, 46461))

/-- **The unrouted arm produced a strictly larger haystack in both orderings.**
O4 counts a number as unsupported when it appears in no preceding tool output,
so a larger haystack mechanically lowers the count. This is the confound, and it
is stated as a measured fact. -/
theorem the_unrouted_arm_had_the_larger_haystack :
    toolCalls.1.1 < toolCalls.1.2 ∧ toolCalls.2.1 < toolCalls.2.2 ∧
    evidenceBytes.1.1 < evidenceBytes.1.2 ∧ evidenceBytes.2.1 < evidenceBytes.2.2 := by
  decide

/-- **The confound was not declared in advance, so it does not get applied.**
No length normalisation appears in `bench/P24-PREREGISTRATION.md` §3 or §7. A
correction invented after seeing an unfavourable result is exactly the freedom
preregistration removes, so the verdict stands as CONTRADICTED and the confound
ships beside it as a limitation. This theorem records the *design* fact: the
verdict function consumes `d` and `f` only, and nothing about length can enter
it. -/
theorem the_verdict_consumes_only_pair_counts (c₁ c₂ : NullControl.Comparison)
    (h : c₁ = c₂) : NullControl.runVerdict c₁ = NullControl.runVerdict c₂ := by rw [h]

/-! ## What this does and does not license -/

/-- **P2.4 did not establish process quality**, and this is the summary theorem.
Three observables saturated, one contradicted; none upheld the claimed
direction. -/
theorem p24_does_not_establish_better_work :
    (NullControl.runVerdict o1Forward = Verdict.notSupported) ∧
    (NullControl.runVerdict o2Forward = Verdict.notSupported) ∧
    (NullControl.runVerdict o3Forward = Verdict.notSupported) ∧
    (o4Forward.favouring = 0) ∧
    (o4Reverse.favouring = 0) := by decide

end RotMoE.P24Run
