/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Proofs.RotNullControl

/-!
# The main run — 160 sessions, and what they do not license

The numbers in this file are **MEASURED, not proved**: R4 primary scoring of the
2026-08-12 main run (40 tasks × 2 arms × 2 orderings), produced by
`bench/main-score.js` against the frozen corpus
(`bench/corpus-40.jsonl`, git-hash `b3b9e3f084a0a0af4563cb1d47f63be534b7e27b`,
committed before any session ran). Lean cannot re-run the sessions; what it
settles is what the **preregistered verdict function** says about those numbers
— nothing more. If the literals below are wrong, every theorem here is a
correct statement about the wrong experiment; the defence is the scorer's
refusal paths and the mutation suite, not this prose.

## What was measured

Forward ordering:  3 discordant pairs of 40, 2 favouring the routed arm.
Reverse ordering: 12 discordant pairs of 40, 10 favouring the routed arm.

Both orderings lean the same way — the sign agreement §7 of
`bench/P24-PREREGISTRATION.md` requires. And yet the run does **not** conclude:
forward is far below the ten-pair floor, and reverse, at 10-of-12, does not
clear the Bonferroni-corrected two-sided tail. A direction the apparatus
repeats is not yet a difference the apparatus certifies.

## Why the pooled number is here

Pooling the orderings is forbidden by the preregistration precisely because it
is the one remaining way to manufacture a bigger n after seeing the data.
`even_the_forbidden_pool_reaches_no_verdict` proves the temptation is empty:
⟨15, 12⟩ under the same function is still `notSupported`. The rule is not
protecting a fragile result; there is nothing behind the door.

5 theorems, 0 sorry.

## Instruments
`lake build` · `#print axioms` · `leanchecker` · mutation: edit a literal,
delete the stale `.olean`, rebuild, watch every theorem below die.
-/

namespace RotMoE.MainRun

open RotMoE.Family
open RotMoE.Experiment
open RotMoE.NullControl

/-- MEASURED 2026-08-12, forward ordering, R4 primary: 3 discordant, 2 favouring
the routed arm. Input to theorems, not a theorem. -/
def measuredForward : NullControl.Comparison := ⟨3, 2⟩

/-- MEASURED 2026-08-12, reverse ordering, R4 primary: 12 discordant, 10
favouring the routed arm. Input to theorems, not a theorem. -/
def measuredReverse : NullControl.Comparison := ⟨12, 10⟩

/-- **Both orderings lean toward the routed arm** — the majority of discordant
pairs favours it in each presentation order separately. This is the §7 sign
agreement, and it is the strongest thing the main run gets to say. -/
theorem both_orderings_lean_the_same_way :
    2 * measuredForward.favouring > measuredForward.discordant
      ∧ 2 * measuredReverse.favouring > measuredReverse.discordant := by decide

/-- **Forward cannot conclude.** Three discordant pairs is noise-sized; the
verdict function refuses it exactly as it refused the pilot's two. -/
theorem forward_cannot_conclude :
    runVerdict measuredForward = Verdict.notSupported := by decide

/-- **Reverse does not clear the preregistered tail.** Ten of twelve is a lean,
not a licence: the two-sided tail at ⟨12, 10⟩, Bonferroni-corrected at the
settled family size, misses the threshold fixed before the data existed. -/
theorem reverse_does_not_clear_the_tail :
    runVerdict measuredReverse = Verdict.notSupported := by decide

/-- **The main run does not conclude**, in either ordering, under the rule
declared before the first session ran. -/
theorem the_main_run_does_not_conclude :
    runVerdict measuredForward = Verdict.notSupported
      ∧ runVerdict measuredReverse = Verdict.notSupported := by decide

/-- **Pooling would not have helped.** The preregistration forbids summing the
orderings; this proves the forbidden move is also a worthless one. ⟨15, 12⟩ —
the pooled discordant and favouring counts — still reaches no verdict, so no
incentive to break the rule ever existed. -/
theorem even_the_forbidden_pool_reaches_no_verdict :
    runVerdict ⟨15, 12⟩ = Verdict.notSupported := by decide

end RotMoE.MainRun
