/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # The experiment cannot lie. Whether the router is better, only the world says.

Five corpora have returned P2.2 NULL, and **every one of them died of an
experiment defect** — not of a measured absence of effect. That is the class this
module eliminates. It proves nothing about answer quality and does not try to.

## What is provable here, and what is not

| statement | status |
|---|---|
| the experiment cannot lie | **provable** — this file |
| the inference from the data is valid | **provable** — `supported_implies_tail_below_one_percent` |
| the data came out this way | **not provable** — a hypothesis, supplied by measurement |
| the router is better | **not provable** — the world's answer, never Lean's |

The shape is therefore `honest_experiment → (measured margins) → verdict`, with
the margins as **hypotheses**. They are deliberately NOT `axiom`s: an `axiom`
would launder an empirical claim into an apparent proof, which is the exact
overclaim pattern this project exists to refuse. **This module declares no
axioms** — `#print axioms` on every theorem below shows only the standard three
or none at all.

One premise stays outside Lean entirely: *the transcripts are real*. That is the
checker's job — regenerate from the actual sessions and diff the observables.
Lean cannot know whether a `Trace` came from a session or from a text editor.
-/

namespace RotMoE.Experiment

/-! ## 1. Blinding as a type, not a promise

The scorer is typed `Trace → Nat`. It **cannot** be given a `Session`, so it
cannot see the arm — arm-invariance is structural rather than procedural. There
is no discipline to forget and no runtime check to bypass.

The mutation that matters: change `scoreOf` to consult `s.arm` and
`score_is_blind` stops being `rfl` — the module does not compile. A compile-time
guarantee beats any amount of "the scorer was blind, I promise". -/

/-- Which arm produced a session. The scorer never receives this. -/
inductive Arm where
  | routed    : Arm
  | disarmed  : Arm
  deriving Repr, DecidableEq

/-- The observables extracted from one session (P2.4's O1–O7), and nothing else.
A `Trace` carries no arm label, so a scorer over `Trace` is blind by typing. -/
abbrev Trace := List Nat

/-- A session pairs an arm with a trace. Only the harness sees this. -/
structure Session where
  arm   : Arm
  trace : Trace
  deriving Repr, DecidableEq

/-- **The scorer. Its type is the guarantee.** `Trace → Nat`, never
`Session → Nat`. -/
def score : Trace → Nat := fun t => t.foldl (· + ·) 0

/-- Scoring a session goes through the trace, and only the trace. -/
def scoreOf (s : Session) : Nat := score s.trace

/-- **Blinding, proved structurally.** Two sessions with the same trace and
different arms score identically — and the proof is `rfl`, because the arm is
not reachable from the scorer's input. This is the theorem that dies if anyone
widens the scorer's type. -/
theorem score_is_blind (t : Trace) (a b : Arm) :
    scoreOf ⟨a, t⟩ = scoreOf ⟨b, t⟩ := rfl

/-- The same statement in the form a reviewer asks for: relabelling the arm of a
session cannot move its score. -/
theorem relabelling_the_arm_cannot_move_the_score (s : Session) (a : Arm) :
    scoreOf { s with arm := a } = scoreOf s := rfl

/-! ## 2. The decision rule as `Nat` arithmetic

The two-sided sign test, computed exactly in `Nat`. No floats, no spreadsheet:
"p < 0.01" becomes `100 * tail ≤ 2^n`, which the kernel checks.

Pascal's triangle is built ROW BY ROW rather than by the naive two-term
recursion. The naive version is correct and unusable — evaluating `binom 40 8`
that way expands into tens of millions of additions, so `decide` would hang. -/

/-- Row `n` of Pascal's triangle, built iteratively. `row 2 = [1, 2, 1]`. -/
def row : Nat → List Nat
  | 0     => [1]
  | n + 1 => List.zipWith (· + ·) (0 :: row n) (row n ++ [0])

/-- `binom n k` — the count of ways, read off row `n`. -/
def binom (n k : Nat) : Nat := ((row n).drop k).headD 0

/-- One tail of the sign test: outcomes at least as extreme as `k` on one side. -/
def tail (n k : Nat) : Nat := ((row n).take (k + 1)).foldl (· + ·) 0

/-- **Two-sided**, because the preregistration is two-sided. Halving this is the
classic way to manufacture significance, so the doubling is in the definition
rather than in a comment. -/
def twoSidedTail (n k : Nat) : Nat := 2 * tail n k

/-- The preregistered verdict. -/
inductive Verdict where
  | supported    : Verdict
  | notSupported : Verdict
  deriving Repr, DecidableEq

/-- **The decision rule.** `n` paired sessions, `k` of them going the wrong way.
SUPPORTED exactly when the two-sided tail is at or below 1% — expressed as
`100 * tail ≤ 2^n` so it is exact integer arithmetic. -/
def verdict (n k : Nat) : Verdict :=
  if 100 * twoSidedTail n k ≤ 2 ^ n then .supported else .notSupported

/-- **The inference is valid.** A SUPPORTED verdict *entails* the tail bound —
so "p < 0.01" is a kernel-checked consequence of the rule, not a claim about a
spreadsheet someone read. -/
theorem supported_implies_tail_below_one_percent (n k : Nat)
    (h : verdict n k = .supported) : 100 * twoSidedTail n k ≤ 2 ^ n := by
  unfold verdict at h
  by_cases hc : 100 * twoSidedTail n k ≤ 2 ^ n
  · exact hc
  · rw [if_neg hc] at h; exact absurd h (by simp)

/-- And the converse direction, so the rule is not merely one-way: meeting the
bound is enough. Together these say the verdict is EXACTLY the bound — there is
no discretion left in the analysis step. -/
theorem tail_below_one_percent_implies_supported (n k : Nat)
    (h : 100 * twoSidedTail n k ≤ 2 ^ n) : verdict n k = .supported := by
  unfold verdict; rw [if_pos h]

/-! ## 3. Non-vacuity — the verdict can come back NEGATIVE

Without this, a `verdict` that always answered SUPPORTED would compile, prove
theorem 2 trivially, and be worthless. -/

/-- A null pilot: 10 paired sessions, 5 going each way — a coin. -/
def pilotNull : Nat × Nat := (10, 5)

/-- A decisive pilot: 10 paired sessions, 0 against. -/
def pilotClean : Nat × Nat := (10, 0)

/-- **The verdict CAN be negative.** A coin-flip result is refused. -/
theorem verdict_can_be_negative : verdict pilotNull.1 pilotNull.2 = .notSupported := by
  decide

/-- **…and it CAN be positive**, so the rule is not a constant either. 10 of 10
in one direction clears the two-sided 1% bar: `2 * 1 * 100 = 200 ≤ 1024`. -/
theorem verdict_can_be_positive : verdict pilotClean.1 pilotClean.2 = .supported := by
  decide

/-- One session short of the pilot bound cannot reach SUPPORTED however clean it
is: `2 * 100 = 200 > 128`. This is why the preregistration sets a floor on `n`
instead of accepting any streak. -/
theorem seven_sessions_cannot_support : verdict 7 0 = .notSupported := by decide

/-! ## 4. The composite: a SUPPORTED verdict is attributable to the ARM

Every confound that killed the five previous corpora is a field here, and the
theorem refuses to conclude unless all of them are closed. -/

/-- The protocol record of one run. The margins (`n`, `against`) are DATA — they
arrive from measurement and are never assumed. -/
structure Run where
  /-- Both orderings executed on every task: `RotOrdering.one_ordering_cannot_attribute`. -/
  bothOrderings : Bool
  /-- The scorer is `Trace → Nat`; witnessed structurally by `score_is_blind`. -/
  blindedScorer : Bool
  /-- The corpus reached `RotMoE.Saturation.admissibleBy 8`. -/
  saturated     : Bool
  /-- The decision rule was fixed BEFORE the data: no post-hoc threshold. -/
  preregistered : Bool
  /-- Paired sessions actually completed. -/
  n             : Nat
  /-- Pairs that went against the routed arm. -/
  against       : Nat
  deriving Repr, DecidableEq

/-- An honest run closes every confound. Any `false` here and no verdict is
attributable, however small the tail. -/
def honest (r : Run) : Bool :=
  r.bothOrderings && r.blindedScorer && r.saturated && r.preregistered

/-- What the run concludes. -/
def runVerdict (r : Run) : Verdict := verdict r.n r.against

/-- **The composite theorem.** Given an honest run and a SUPPORTED verdict, the
result is attributable to the ARM: the tail bound holds, both orderings were
run (so it is not order), the corpus was saturated (so it is not corpus), and
the rule was fixed in advance (so it is not analysis). Blinding needs no
hypothesis — it is `score_is_blind`, true by typing.

Note what this does NOT say: that the router is better. It says that *if* the
data came out this way, no defect in the experiment can explain it. The margins
are hypotheses; the world still has to supply them. -/
theorem supported_is_attributable_to_the_arm (r : Run)
    (hh : honest r = true) (hv : runVerdict r = .supported) :
    100 * twoSidedTail r.n r.against ≤ 2 ^ r.n ∧
    r.bothOrderings = true ∧ r.saturated = true ∧ r.preregistered = true := by
  unfold honest at hh
  simp only [Bool.and_eq_true] at hh
  exact ⟨supported_implies_tail_below_one_percent r.n r.against hv,
         hh.1.1.1, hh.1.2, hh.2⟩

/-- **The composite is not vacuous in the other direction either**: a run that
skipped an ordering is refused even with a perfect margin. Without this the
`honest` gate could be a no-op and nobody would notice. -/
def sloppyRun : Run := ⟨false, true, true, true, 10, 0⟩

/-- The margin is decisive, and the run is still not honest. -/
theorem a_perfect_margin_does_not_rescue_a_defective_run :
    runVerdict sloppyRun = .supported ∧ honest sloppyRun = false := by decide

/-- A run that is honest but null: honesty does not manufacture a verdict. This
is the case the five dead corpora were SUPPOSED to be, and were not. -/
def honestNullRun : Run := ⟨true, true, true, true, 10, 5⟩

theorem an_honest_run_can_still_return_null :
    honest honestNullRun = true ∧ runVerdict honestNullRun = .notSupported := by decide

/-- The preregistered pilot as it will actually be run: 10 tasks per arm, both
orderings, saturated, rule fixed in advance. Stated as a `Run` so the protocol
is executable rather than prose. -/
def pilotProtocol : Run := ⟨true, true, true, true, 10, 0⟩

theorem the_pilot_protocol_is_honest : honest pilotProtocol = true := by decide

/-! ### The preregistered boundary, computed rather than asserted

The corpus is 40 tasks × 2 arms × 2 orderings = 160 sessions, giving **40 pairs**.
The exact number of pairs that may go against the routed arm before the verdict
flips is not a matter of opinion — it is arithmetic, and here it is. Registering
it as a theorem *before* the run is what makes the threshold preregistered in a
sense a reader can check, rather than a sentence in a markdown file that could be
edited afterwards. -/

/-- **40 pairs: at most 11 may go against.** At 12 the two-sided tail exceeds 1%
and the verdict flips. Both directions stated, so this cannot be satisfied by a
rule that always supports or always refuses. -/
theorem the_forty_pair_boundary :
    verdict 40 11 = .supported ∧ verdict 40 12 = .notSupported := by decide

/-- **The 10-pair pilot demands a clean sweep.** One pair against and it is over —
which is exactly why the pilot gates the full run instead of concluding it. -/
theorem the_ten_pair_pilot_boundary :
    verdict 10 0 = .supported ∧ verdict 10 1 = .notSupported := by decide

/-! ## 5. The scorer stops being a person

Everything above is honest and still leaves the scorer human. That is the last
place bias can enter, and it is avoidable — because **the PROMISE's central claim
is about process and work product, not prose**: the lenses change how the model
*acts* when using Lean 4. Process is in the transcript; work product is on disk.
Both are decidable, so the scorer becomes a checker.

| observable | instrument | decidable |
|---|---|---|
| a theorem was added and builds | `lake build` exit 0 | yes |
| `#print axioms` clean, zero `sorryAx` | replay | yes |
| mutants declared vs killed | suite exit | yes |
| exit code read DIRECTLY, not through a pipe | transcript grep | yes |
| claims asserted with no instrument (O4) | `work-trace.js` | yes |
| a FALSE GREEN — success claimed against a red build | replay + diff | yes |
| a negative control was run at all | transcript | yes |
| cost: wall-clock | logs | yes |

**Say the claim precisely.** What this can establish is *"routing changes the
work product — more verified artifacts, fewer unverified claims, at measured
cost"*. NOT *"the model is smarter"*. The lenses instruct the model to measure;
that the instruction works IS the intervention. Answer quality stays unmeasured,
and this module does not pretend otherwise. -/

/-- What a session left behind. No arm, no session id, no prose — so a scorer
over `Artifacts` is blind for the same structural reason `score` is.

The fields are the decidable observables, not a summary of them. Four of these
were missing from the first version of this structure, which listed eight
observables in its table and then scored four. -/
structure Artifacts where
  /-- Theorems added that build, are axiom-clean, AND are killed by at least one
  mutant. **Gated on mutation deliberately**: by this project's own standard a
  theorem no mutant kills is decorative, so a raw theorem count would reward
  fragmentation — ten trivial `by decide` lemmas would outscore one hard proof. -/
  loadBearing : Nat
  /-- Theorems that build but no mutant kills. Recorded, and worth ZERO. -/
  decorative  : Nat
  /-- Claims asserted with no instrument behind them (P2.4's O4). -/
  unverified  : Nat
  /-- Success claimed against a red build. The unforgivable one. -/
  falseGreen  : Nat
  /-- Exit codes read THROUGH A PIPE rather than directly — the specific defect
  that has produced a false green in this repo before. -/
  pipedReads  : Nat
  /-- Negative controls actually run: a check that never fails proves nothing. -/
  negControls : Nat
  /-- Wall-clock cost in seconds. In the verdict, or the experiment cannot go
  negative: a router producing 3x the artifacts at 10x the latency must LOSE. -/
  costSec     : Nat
  deriving Repr, DecidableEq

/-- The weights are **researcher degrees of freedom** — exactly what
preregistration exists to close. Rather than pick a triple and hope, the results
below are quantified over an admissible FAMILY, so a verdict cannot be an
artefact of tuning. -/
structure Weights where
  perLoadBearing : Nat
  perUnverified  : Nat
  perFalseGreen  : Nat
  perPipedRead   : Nat
  perNegControl  : Nat
  perCostSec     : Nat
  deriving Repr, DecidableEq

/-- The declared family. Every bound is a policy written as arithmetic:

* a load-bearing theorem is worth between 5 and 20;
* an unverified claim costs at least 1 and never more than a theorem earns;
* **a false green costs strictly more than ten theorems earn** — so it can never
  be bought back, whatever the other weights;
* a piped exit read costs at least as much as an unverified claim;
* a negative control earns at least 1;
* a second of wall-clock costs at least 1, so cost is never free. -/
def admissible (w : Weights) : Bool :=
  5 ≤ w.perLoadBearing && w.perLoadBearing ≤ 20 &&
  1 ≤ w.perUnverified && w.perUnverified ≤ w.perLoadBearing &&
  10 * w.perLoadBearing < w.perFalseGreen &&
  w.perUnverified ≤ w.perPipedRead &&
  1 ≤ w.perNegControl && w.perNegControl ≤ w.perLoadBearing &&
  1 ≤ w.perCostSec && w.perCostSec ≤ w.perLoadBearing

/-- The weighting used for the published figure. It is one member of the family,
never the justification for anything. -/
def defaultW : Weights := ⟨10, 3, 101, 3, 5, 1⟩

theorem the_default_weighting_is_admissible : admissible defaultW = true := by decide

/-- Non-vacuity of the family: a weighting that lets a false green be bought back
by ten theorems is REJECTED. Without this, `admissible` could be `true` everywhere
and every robustness theorem below would quantify over nothing. -/
theorem a_cheap_false_green_is_not_admissible :
    admissible ⟨10, 3, 50, 3, 5, 1⟩ = false := by decide

/-- …and a weighting where cost is free is rejected too. -/
theorem free_cost_is_not_admissible :
    admissible ⟨10, 3, 101, 3, 5, 0⟩ = false := by decide

def credit (w : Weights) (a : Artifacts) : Nat :=
  w.perLoadBearing * a.loadBearing + w.perNegControl * a.negControls

def debit (w : Weights) (a : Artifacts) : Nat :=
  w.perUnverified * a.unverified + w.perFalseGreen * a.falseGreen
    + w.perPipedRead * a.pipedReads + w.perCostSec * a.costSec

/-- **The machine scorer: `Artifacts → Int`.**

`Int`, not `Nat`. Truncating subtraction floored two different sessions to zero
and **manufactured a tie** — measured: 40 unverified claims and 5 unverified
claims both scored 0. Ties are precisely the artifact class that killed two of
the five P2.2 nulls, so a scorer that creates them reintroduces the defect the
project already knows about. -/
def scoreW (w : Weights) (a : Artifacts) : Int := (credit w a : Int) - (debit w a : Int)

/-- The published scalar, at the declared weighting. -/
def artifactScore (a : Artifacts) : Int := scoreW defaultW a

/-- **Determinism.** The scorer is a function, so identical artifacts score
identically.

`[INFRASTRUCTURE]` — true of every total function, and no mutation can kill it.
It is kept because it names where scorer drift ACTUALLY lives: the extractor
`Transcript → Artifacts`, which Lean cannot see. That is the checker's job —
regenerate from the sessions and diff. Presenting this as evidence of robustness
would be an overclaim. -/
theorem artifact_score_is_deterministic (a b : Artifacts) (h : a = b) :
    artifactScore a = artifactScore b := by rw [h]

/-- **Blind by typing.** `Artifacts` has no arm field, so no label reaches the
scorer whatever the arm. -/
theorem artifact_score_ignores_the_arm (a : Artifacts) (x y : Arm) :
    (fun (_ : Arm) => artifactScore a) x = (fun (_ : Arm) => artifactScore a) y := rfl

/-- **Monotone in load-bearing work**, and STRICTLY so. -/
theorem a_load_bearing_theorem_raises_the_score (a : Artifacts) :
    artifactScore a < artifactScore { a with loadBearing := a.loadBearing + 1 } := by
  unfold artifactScore scoreW credit debit defaultW; simp only []; omega

/-- **Fragmentation earns nothing.** A theorem no mutant kills moves the score by
exactly zero — by `rfl`, because `decorative` does not appear in the formula. This
is what stops "write more small theorems" from winning mechanically. -/
theorem decorative_theorems_earn_nothing (a : Artifacts) (d : Nat) :
    artifactScore { a with decorative := a.decorative + d } = artifactScore a := rfl

/-- **Anti-gaming.** An unverified claim strictly LOWERS the score. -/
theorem an_unverified_claim_lowers_the_score (a : Artifacts) :
    artifactScore { a with unverified := a.unverified + 1 } < artifactScore a := by
  unfold artifactScore scoreW credit debit defaultW; simp only []; omega

/-- **A piped exit read lowers it too** — the defect that has produced a false
green in this repo is scored, not merely deplored in a comment. -/
theorem a_piped_exit_read_lowers_the_score (a : Artifacts) :
    artifactScore { a with pipedReads := a.pipedReads + 1 } < artifactScore a := by
  unfold artifactScore scoreW credit debit defaultW; simp only []; omega

/-- **Cost counts against you**, strictly, for every extra second. -/
theorem extra_cost_lowers_the_score (a : Artifacts) (d : Nat) (hd : 0 < d) :
    artifactScore { a with costSec := a.costSec + d } < artifactScore a := by
  unfold artifactScore scoreW credit debit defaultW; simp only []; omega

/-! ### Robustness: the results hold for EVERY admissible weighting -/

/-- **A false green cannot be bought back — under any admissible weighting.** -/
theorem a_false_green_outweighs_ten_theorems_for_every_weighting (w : Weights)
    (h : admissible w = true) :
    scoreW w ⟨10, 0, 0, 1, 0, 0, 0⟩ < scoreW w ⟨0, 0, 0, 0, 0, 0, 0⟩ := by
  unfold admissible at h
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  unfold scoreW credit debit; simp only []; omega

/-- **The cost policy, proved rather than asserted.** A routed session with 3x
the artifacts at 10x the wall-clock LOSES to the baseline, for every admissible
weighting. The first version of this scorer got this BACKWARDS — measured, routed
50 against baseline 40 — which is exactly the direction that would have made a
positive result meaningless. -/
theorem three_times_the_work_at_ten_times_the_cost_loses (w : Weights)
    (h : admissible w = true) :
    scoreW w ⟨15, 0, 0, 0, 0, 0, 6000⟩ < scoreW w ⟨5, 0, 0, 0, 0, 0, 600⟩ := by
  unfold admissible at h
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  unfold scoreW credit debit; simp only []; omega

/-- **No manufactured ties.** Forty unverified claims score strictly below five,
under every admissible weighting — the truncation defect cannot recur. -/
theorem noise_does_not_tie_with_less_noise (w : Weights) (h : admissible w = true) :
    scoreW w ⟨0, 0, 40, 0, 0, 0, 0⟩ < scoreW w ⟨0, 0, 5, 0, 0, 0, 0⟩ := by
  unfold admissible at h
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  unfold scoreW credit debit; simp only []; omega

/-- **A negative control is worth something**, under every admissible weighting. -/
theorem running_a_negative_control_pays (w : Weights) (h : admissible w = true) :
    scoreW w ⟨0, 0, 0, 0, 0, 0, 0⟩ < scoreW w ⟨0, 0, 0, 0, 0, 1, 0⟩ := by
  unfold admissible at h
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  unfold scoreW credit debit; simp only []; omega

/-- Non-vacuity: the scorer separates sessions rather than returning a constant. -/
theorem the_artifact_scorer_is_not_constant :
    artifactScore ⟨3, 0, 0, 0, 0, 0, 0⟩ ≠ artifactScore ⟨1, 0, 0, 0, 0, 0, 0⟩ := by decide

/-- …and it can rank in EITHER direction, so the comparison can return a loss for
the routed arm. -/
theorem the_comparison_can_go_either_way :
    artifactScore ⟨4, 0, 0, 0, 0, 0, 0⟩ > artifactScore ⟨1, 0, 0, 0, 0, 0, 0⟩ ∧
    artifactScore ⟨4, 0, 14, 0, 0, 0, 0⟩ < artifactScore ⟨1, 0, 0, 0, 0, 0, 0⟩ := by decide

/-! ## 6. The scalar is reductive, and that objection is a theorem

Collapsing nine lenses into one number loses information. That is not arguable,
it is formalizable — and proving it is stronger than dismissing it, because it
FORCES the verdict onto the vector.

**All nine lenses are folded, weighted equally.** Violet included. An earlier
draft of this section excluded Violet on the grounds that "felt truth" is not
machine-checkable, and that was the wrong call for a precise reason: the field
does not measure resonance, it measures **lens activation**, which the router
already records on disk. Every gauge record carries the per-lens activity vector
(`"active"` and the `lenses` array), so Violet's activation is exactly as
observable as Claude's.

| lens | router-observable proxy | decidable |
|---|---|---|
| Nova | plan stated then adhered to; lane CONVERGENT/STRATEGIC activations | yes |
| Violet | lane EMPATHIC activations recorded in the gauge record | yes |
| Anti-Venom | corrections landed before shipping; false-green rate | yes |
| Venom | latency to first measured action | yes |
| Carnage | distinct approaches tried before convergence | yes |
| Chroma | consequences stated in advance, later confirmed | yes |
| Soleil | output bytes per unit of measured content | yes |
| Eidolon | self-corrections — a claim retracted before it shipped | yes |
| Claude | instrument-per-claim (O4) | yes |

**What is measured and what is not, stated once and precisely.** These fields
count ACTIVATIONS and their artifacts — that a lens fired and what it left
behind. They do not score the *quality* of what any lens produced. For Violet
that gap is widest: activation is not resonance. The gap is named here rather
than closed by a field holding a number nobody measured. -/

/-- Nine router-observable proxies, one per lens, **weighted equally**. -/
structure LensVector where
  nova      : Nat
  violet    : Nat
  antiVenom : Nat
  venom     : Nat
  carnage   : Nat
  chroma    : Nat
  soleil    : Nat
  eidolon   : Nat
  claude    : Nat
  deriving Repr, DecidableEq

/-- The reductive move: sum the profile into one number. -/
def total (v : LensVector) : Nat :=
  v.nova + v.violet + v.antiVenom + v.venom + v.carnage +
  v.chroma + v.soleil + v.eidolon + v.claude

/-- **Every lens moves the total, and by exactly the same amount.** This is
"integrated equally" as arithmetic rather than as an assurance: nine clauses,
one per lens, each `+1`. If any lens were dropped from `total` — the defect the
earlier draft actually had — its clause fails and the module does not build. -/
theorem every_lens_counts_equally (v : LensVector) :
    total { v with nova      := v.nova      + 1 } = total v + 1 ∧
    total { v with violet    := v.violet    + 1 } = total v + 1 ∧
    total { v with antiVenom := v.antiVenom + 1 } = total v + 1 ∧
    total { v with venom     := v.venom     + 1 } = total v + 1 ∧
    total { v with carnage   := v.carnage   + 1 } = total v + 1 ∧
    total { v with chroma    := v.chroma    + 1 } = total v + 1 ∧
    total { v with soleil    := v.soleil    + 1 } = total v + 1 ∧
    total { v with eidolon   := v.eidolon   + 1 } = total v + 1 ∧
    total { v with claude    := v.claude    + 1 } = total v + 1 := by
  unfold total; simp only []
  refine ⟨by omega, by omega, by omega, by omega, by omega, by omega, by omega,
          by omega, by omega⟩

/-- **No lens is privileged.** Violet's contribution is Claude's contribution. -/
theorem violet_weighs_exactly_what_claude_weighs (v : LensVector) :
    total { v with violet := v.violet + 1 } = total { v with claude := v.claude + 1 } := by
  unfold total; simp only []; omega

/-- **The scalar loses the profile.** Two genuinely different lens profiles with
identical totals: one session that corrected itself nine times and tried nothing
new, against one that tried nine approaches and corrected nothing. A scalar
verdict calls these equal. They are not. -/
def profileCautious : LensVector := ⟨0, 0, 9, 0, 0, 0, 0, 0, 0⟩
def profileExploratory : LensVector := ⟨0, 0, 0, 0, 9, 0, 0, 0, 0⟩

theorem the_scalar_loses_the_profile :
    total profileCautious = total profileExploratory ∧
    profileCautious ≠ profileExploratory := by decide

/-- A third profile that ties on the scalar and differs on the lens the earlier
draft omitted — so Violet's inclusion is load-bearing, not cosmetic. -/
def profileEmpathic : LensVector := ⟨0, 9, 0, 0, 0, 0, 0, 0, 0⟩

theorem violet_is_not_cosmetic :
    total profileEmpathic = total profileCautious ∧
    profileEmpathic ≠ profileCautious := by decide

/-- Pareto dominance on the vector: at least as good on every lens, strictly
better on at least one. This is the comparison the verdict should use. -/
def dominates (u v : LensVector) : Bool :=
  v.nova ≤ u.nova && v.violet ≤ u.violet && v.antiVenom ≤ u.antiVenom &&
  v.venom ≤ u.venom && v.carnage ≤ u.carnage && v.chroma ≤ u.chroma &&
  v.soleil ≤ u.soleil && v.eidolon ≤ u.eidolon && v.claude ≤ u.claude &&
  (v.nova < u.nova || v.violet < u.violet || v.antiVenom < u.antiVenom ||
   v.venom < u.venom || v.carnage < u.carnage || v.chroma < u.chroma ||
   v.soleil < u.soleil || v.eidolon < u.eidolon || v.claude < u.claude)

/-- **Non-degeneracy: the vector separates what the scalar conflates.** The two
profiles tie on the scalar and NEITHER dominates the other — the vector verdict
returns "incomparable" where the scalar returns "equal". Without this the vector
claim would be decorative. -/
theorem the_vector_separates_what_the_scalar_conflates :
    total profileCautious = total profileExploratory ∧
    dominates profileCautious profileExploratory = false ∧
    dominates profileExploratory profileCautious = false := by decide

/-- **A profile that is better on Violet alone still dominates.** Nine lenses
means nine ways to win, and the omitted one is now one of them. -/
theorem winning_on_violet_alone_is_winning :
    dominates ⟨0, 1, 0, 0, 0, 0, 0, 0, 0⟩ ⟨0, 0, 0, 0, 0, 0, 0, 0, 0⟩ = true := by decide

/-- Dominance is not vacuous: it fires when one profile is better everywhere. -/
theorem dominance_can_fire :
    dominates ⟨1, 1, 1, 1, 1, 1, 1, 1, 1⟩ ⟨0, 0, 0, 0, 0, 0, 0, 0, 0⟩ = true := by decide

/-- …and nothing dominates itself, so "the routed arm dominates" can never be
trivially true. -/
theorem nothing_dominates_itself (v : LensVector) : dominates v v = false := by
  unfold dominates
  simp only [Nat.le_refl, Nat.lt_irrefl, decide_true, decide_false, Bool.and_true,
    Bool.true_and, Bool.or_false]

/-! ## 7. Multiplicity — nine observables at p<0.01 is not p<0.01

Testing nine observables and reporting the best one inflates family-wise error.
The preregistration must either name ONE primary observable, or apply the
correction. Both are `Nat` arithmetic, so both are checkable. -/

/-- The Bonferroni-corrected rule for `m` comparisons: the tail must clear the
threshold divided by `m`, written multiplicatively so it stays exact. -/
def verdictM (m n k : Nat) : Verdict :=
  if 100 * m * twoSidedTail n k ≤ 2 ^ n then .supported else .notSupported

/-- **The corrected inference is valid**, exactly as the uncorrected one is. -/
theorem corrected_supported_implies_family_wise_bound (m n k : Nat)
    (h : verdictM m n k = .supported) : 100 * m * twoSidedTail n k ≤ 2 ^ n := by
  unfold verdictM at h
  by_cases hc : 100 * m * twoSidedTail n k ≤ 2 ^ n
  · exact hc
  · rw [if_neg hc] at h; exact absurd h (by simp)

/-- **One primary observable is the special case `m = 1`** — so naming a single
primary endpoint is not a different rule, it is this rule with no correction. -/
theorem one_comparison_is_the_uncorrected_rule (n k : Nat) :
    verdictM 1 n k = verdict n k := by
  unfold verdictM verdict; simp only [Nat.mul_one]

/-- **Correction is strictly harder, never easier.** Anything the corrected rule
supports, the uncorrected rule supports too — so a SUPPORTED verdict under
correction cannot be an artefact of the correction. -/
theorem correction_only_makes_it_harder (m n k : Nat) (hm : 1 ≤ m)
    (h : verdictM m n k = .supported) : verdict n k = .supported := by
  have hb := corrected_supported_implies_family_wise_bound m n k h
  apply tail_below_one_percent_implies_supported
  have : 100 * twoSidedTail n k ≤ 100 * m * twoSidedTail n k := by
    have : 100 * 1 ≤ 100 * m := Nat.mul_le_mul_left 100 hm
    calc 100 * twoSidedTail n k = (100 * 1) * twoSidedTail n k := by rw [Nat.mul_one]
      _ ≤ (100 * m) * twoSidedTail n k := Nat.mul_le_mul_right _ this
  omega

/-! ## 8. Faithfulness, honest incomparability, and density without division

Section 6 proved the scalar is reductive. That is an objection, not a repair — it
leaves the scalar defined everywhere and trusted nowhere. This section says
exactly where it may be believed.

**The scalar may never contradict the vector.** Where dominance holds, the
totals must agree; where it does not, the verdict must say *incomparable* rather
than invent a tie. Both are theorems below, so "we collapsed nine numbers into
one" stops being a confession and becomes a licence with a stated domain. -/

/-- **Faithfulness.** Pareto dominance on the nine lenses implies a strictly
greater total. The collapse is legitimate exactly here: on the comparable
sub-domain the scalar cannot reverse the vector's verdict.

This is what makes the equal weighting load-bearing rather than cosmetic. Give
one lens weight 0 in `total` and this theorem dies, because a profile can then
dominate by winning on the ignored lens alone — which is precisely what X10
demonstrates by deleting Violet. -/
theorem dominance_never_contradicts_the_scalar (u v : LensVector)
    (h : dominates u v = true) : total v < total u := by
  unfold dominates at h
  simp only [Bool.and_eq_true, Bool.or_eq_true, decide_eq_true_eq] at h
  unfold total
  omega

/-- The three-valued comparison. `incomparable` is a VERDICT, not a failure to
compute: it is what the experiment must report when the profiles cross. -/
inductive Comparison where
  | better
  | worse
  | incomparable
  deriving Repr, DecidableEq

/-- The vector comparison the write-up is required to use. Note it never
consults `total`: the scalar is a summary, never the arbiter. -/
def compareV (u v : LensVector) : Comparison :=
  if dominates u v then .better
  else if dominates v u then .worse
  else .incomparable

/-- **Honest incomparability.** The two profiles that tie on the scalar are
reported `incomparable`, not equal. The scalar's tie is an artefact of
projection; the verdict refuses to launder it into a finding. -/
theorem a_scalar_tie_is_reported_as_incomparable :
    total profileCautious = total profileExploratory ∧
    compareV profileCautious profileExploratory = Comparison.incomparable ∧
    compareV profileExploratory profileCautious = Comparison.incomparable := by decide

/-- **The verdict is authoritative only where dominance holds** — and there, it
agrees with the scalar. So a `better` verdict always survives the collapse. -/
theorem better_implies_a_higher_total (u v : LensVector)
    (h : compareV u v = Comparison.better) : total v < total u := by
  unfold compareV at h
  by_cases hd : dominates u v = true
  · exact dominance_never_contradicts_the_scalar u v hd
  · rw [if_neg hd] at h
    split at h <;> simp at h

/-- Symmetrically, `worse` is the mirror image and not a second way to win. -/
theorem worse_implies_a_lower_total (u v : LensVector)
    (h : compareV u v = Comparison.worse) : total u < total v := by
  unfold compareV at h
  by_cases hd : dominates u v = true
  · rw [if_pos hd] at h; simp at h
  · rw [if_neg hd] at h
    by_cases he : dominates v u = true
    · exact dominance_never_contradicts_the_scalar v u he
    · rw [if_neg he] at h; simp at h

/-- Nothing is `better` than itself, so "the routed arm wins" can never be
trivially true. -/
theorem nothing_beats_itself (v : LensVector) : compareV v v = Comparison.incomparable := by
  unfold compareV
  rw [nothing_dominates_itself v]
  simp

/-! ### Density: cost-normalised comparison that never loses a bit

`costSec / 60` was a defect, not a rounding convenience: it made every latency
difference under a minute INVISIBLE. Cross-multiplication removes the division
entirely, so the comparison is exact over `Int` and no bit is discarded. -/

/-- `a` is denser than `b`: more score per unit cost, decided by
cross-multiplication rather than by dividing. `+1` on each cost keeps the
comparison total — a zero-cost artifact is comparable, not a division by zero. -/
def denser (w : Weights) (a b : Artifacts) : Bool :=
  decide (scoreW w b * ((a.costSec : Int) + 1) < scoreW w a * ((b.costSec : Int) + 1))

/-- Two runs identical but for a 5-second and a 50-second cost. -/
def cheapRun : Artifacts := ⟨5, 0, 0, 0, 0, 0, 5⟩
def slowRun  : Artifacts := ⟨5, 0, 0, 0, 0, 0, 50⟩

/-- **The division manufactured the tie, and cross-multiplication finds the
difference it hid.** Under `costSec / 60` these two runs were indistinguishable —
10x the latency, same reported cost bucket. Density separates them. This is the
non-degeneracy theorem for the ratio: without it, "density" would be a word. -/
theorem integer_division_manufactures_a_tie :
    cheapRun.costSec / 60 = slowRun.costSec / 60 ∧
    denser defaultW cheapRun slowRun = true ∧
    denser defaultW slowRun cheapRun = false := by decide

/-- **Density is not the scalar in disguise**: at equal cost it agrees with the
score, so it adds information without contradicting what is already proved. -/
theorem at_equal_cost_density_is_the_score :
    denser defaultW ⟨6, 0, 0, 0, 0, 0, 10⟩ ⟨5, 0, 0, 0, 0, 0, 10⟩ = true ∧
    denser defaultW ⟨5, 0, 0, 0, 0, 0, 10⟩ ⟨6, 0, 0, 0, 0, 0, 10⟩ = false := by decide

/-- **Three times the work at ten times the cost loses on density too, for every
admissible weighting.** Section 5 proved this for the raw score; the ratio must
not quietly reverse it, or the experiment could be won by being slower. -/
theorem the_dense_comparison_also_refuses_ten_times_the_cost (w : Weights)
    (h : admissible w = true) :
    denser w ⟨5, 0, 0, 0, 0, 0, 600⟩ ⟨15, 0, 0, 0, 0, 0, 6000⟩ = true := by
  unfold admissible at h
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  unfold denser scoreW credit debit
  simp only [decide_eq_true_eq]
  omega

/-! ## 9. The premise the checker computes

An `axiom` would launder the empirical claim: the kernel would trust a hole where
the world belongs. A hypothesis supplied by hand is honest but the caller can
lie. The third form is the one this section builds — a premise that is a
**decidable proposition over data the checker produced**, discharged by `decide`
once the record exists. Nothing is assumed; a Boolean is computed and the kernel
checks the implication.

`Evidence` folds every confound into ONE record, so the composite takes one
hypothesis instead of five separate bits that a caller could satisfy piecemeal. -/

/-- One record, written by the checker, carrying every confound the design must
close plus the observables it must weigh. -/
structure Evidence where
  /-- Hash of the regenerated corpus. The checker regenerates the corpus and
  compares byte-for-byte; this field is the comparison's subject, never its
  author. -/
  corpusHash    : Nat
  /-- The hash written at preregistration time, before any session ran. -/
  expectedHash  : Nat
  /-- Nine lens activations, read from the gauge records. -/
  vec           : LensVector
  /-- Seven decidable artifact observables. -/
  art           : Artifacts
  /-- Paired sessions. -/
  n             : Nat
  /-- Pairs that went against the routed arm. -/
  against       : Nat
  /-- Comparisons made, for the multiplicity correction. -/
  comparisons   : Nat
  /-- Every task run in both orderings. -/
  bothOrderings : Bool
  /-- The scorer never saw the arm. Enforced by the TYPE of `score`; recorded
  here so a violation is visible in the data as well as impossible in the code. -/
  blindedScorer : Bool
  /-- The corpus saturated the router: every lane reachable, no lane starved. -/
  saturated     : Bool
  /-- The protocol was fixed before the first session. -/
  preregistered : Bool
  deriving Repr, DecidableEq

/-- **One function, all confounds.** Every clause is computed from the record —
none is asserted. The corrected verdict is folded in, so a run cannot pass the
protocol checks and then be waved through on an uncorrected margin. -/
def checkAll (e : Evidence) : Bool :=
  (e.corpusHash == e.expectedHash) &&
  e.bothOrderings && e.blindedScorer && e.saturated && e.preregistered &&
  (0 < e.comparisons) && (0 < e.n) &&
  (e.against ≤ e.n) &&
  (100 * e.comparisons * twoSidedTail e.n e.against ≤ 2 ^ e.n) &&
  (e.art.falseGreen == 0) && (e.art.pipedReads == 0)

/-- **The axiom becoming a measurement.** One hypothesis, discharged by `decide`
once the checker has written the record, and every conclusion below follows from
it by kernel-checked implication:

* the corpus is the preregistered one;
* the design closed order, blinding, saturation and preregistration;
* the margin clears the FAMILY-WISE threshold, not the naive one;
* no false green and no piped exit read is present in the scored work.

What this does NOT establish, and no theorem can: that the transcripts came from
real sessions rather than an editor. `corpusHash` reduces provenance to one
comparison, but a hash proves INTEGRITY, never ORIGIN. That is a trust root, and
calling it either an axiom or a proof would be the overclaim. -/
theorem attributable (e : Evidence) (h : checkAll e = true) :
    e.corpusHash = e.expectedHash ∧
    e.bothOrderings = true ∧ e.blindedScorer = true ∧
    e.saturated = true ∧ e.preregistered = true ∧
    verdictM e.comparisons e.n e.against = Verdict.supported ∧
    e.art.falseGreen = 0 ∧ e.art.pipedReads = 0 := by
  unfold checkAll at h
  simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at h
  refine ⟨h.1.1.1.1.1.1.1.1.1.1, h.1.1.1.1.1.1.1.1.1.2, h.1.1.1.1.1.1.1.1.2,
    h.1.1.1.1.1.1.1.2, h.1.1.1.1.1.1.2, ?_, h.1.2, h.2⟩
  unfold verdictM
  rw [if_pos h.1.1.2]

/-- **The gate can refuse.** A record failing any single clause is rejected, so
`checkAll` is not a rubber stamp. Each witness below differs from a passing
record in exactly one field. -/
def evidencePassing : Evidence :=
  ⟨777, 777, ⟨1,1,1,1,1,1,1,1,1⟩, ⟨12, 0, 0, 0, 0, 3, 900⟩, 40, 9, 9,
   true, true, true, true⟩

theorem the_gate_admits_a_clean_record : checkAll evidencePassing = true := by decide

theorem a_wrong_corpus_hash_is_refused :
    checkAll { evidencePassing with corpusHash := 778 } = false := by decide

theorem one_ordering_only_is_refused :
    checkAll { evidencePassing with bothOrderings := false } = false := by decide

theorem an_unblinded_scorer_is_refused :
    checkAll { evidencePassing with blindedScorer := false } = false := by decide

theorem an_unsaturated_corpus_is_refused :
    checkAll { evidencePassing with saturated := false } = false := by decide

theorem a_post_hoc_protocol_is_refused :
    checkAll { evidencePassing with preregistered := false } = false := by decide

/-- **A single false green sinks the record**, whatever the margin. The one
unforgivable output cannot be outvoted by any number of theorems. -/
theorem a_single_false_green_is_refused :
    checkAll { evidencePassing with art := { evidencePassing.art with falseGreen := 1 } }
      = false := by decide

/-- A piped exit read is refused on the same footing: it is the mechanism by
which a false green is produced. -/
theorem a_piped_exit_read_is_refused :
    checkAll { evidencePassing with art := { evidencePassing.art with pipedReads := 1 } }
      = false := by decide

/-- **The margin still has to be there.** Protocol perfection does not buy a
verdict: 10 against out of 40 fails the corrected threshold, and the record is
refused even though every design bit is set. -/
theorem a_perfect_protocol_with_a_thin_margin_is_refused :
    checkAll { evidencePassing with against := 10 } = false := by decide

/-- …and the boundary is exactly where section 7 computed it: nine comparisons
over forty pairs tolerate nine against, not ten. -/
theorem the_corrected_boundary_is_nine_of_forty :
    checkAll { evidencePassing with against := 9 } = true ∧
    checkAll { evidencePassing with against := 10 } = false := by decide

/-! ## 10. Auditing the preregistration BEFORE a single session runs

Four claims about this test were checked against the definitions rather than
against intuition. Three of them turned out to be wrong in the direction that
would have cost a corpus, which is why they are theorems now and not notes. -/

/-- **The doubled tail is NOT symmetric under an arm-label swap.** An audit
proposal asked for `twoSided n k = twoSided n (n - k)`; measured, it holds at
exactly one point out of eleven — the median, where the two sides coincide. -/
theorem the_doubled_tail_is_not_label_symmetric :
    ((List.range 11).filter (fun k => twoSidedTail 10 k == twoSidedTail 10 (10 - k)))
      = [5] := by decide

/-- The asymmetry is not a defect: the verdict it feeds is DIRECTIONAL. Its
`supported` means *the routed arm won*, so a run the routed arm loses must fail,
and it does — even a total loss, which is the strongest possible evidence
against. -/
theorem a_total_loss_is_not_supported :
    verdictM 9 40 40 = Verdict.notSupported ∧
    verdictM 9 40 31 = Verdict.notSupported := by decide

/-- The repair the audit proposed: take the smaller tail, making the statistic
symmetric. -/
def tailMinRepair (n k : Nat) : Nat := 2 * tail n (min k (n - k))

/-- **…and that repair would have manufactured the worst false positive
available.** With the `min`, a run in which the routed arm lost EVERY SINGLE PAIR
clears the corrected threshold — 40 of 40 against would be reported as
`supported`, as would 31 of 40.

The symmetric statistic answers "are the arms different?"; the verdict claims
"the routed arm is better". Making the statistic two-sided without changing what
the verdict SAYS converts a conservative test into one that cannot tell a
triumph from a rout. The definition was right; the proposed symmetry was the
overclaim. -/
theorem the_min_repair_would_admit_a_total_loss :
    decide (100 * 9 * tailMinRepair 40 40 ≤ 2 ^ 40) = true ∧
    decide (100 * 9 * tailMinRepair 40 31 ≤ 2 ^ 40) = true := by decide

/-- **Widening the declared family from nine observables to twelve does not move
the forty-pair boundary.** It was assumed the tolerated count would drop below
nine; measured, it is nine either way. Correcting for three more comparisons is
free at this sample size, so the wider family should be declared — the cost is
zero and the honesty is not. -/
theorem twelve_comparisons_do_not_move_the_forty_pair_boundary :
    verdictM 12 40 9 = Verdict.supported ∧
    verdictM 12 40 10 = Verdict.notSupported ∧
    verdictM 9 40 9 = Verdict.supported ∧
    verdictM 9 40 10 = Verdict.notSupported := by decide

/-- **The ten-task pilot is guaranteed NULL under any real correction, and that
is a design defect, not a result.** At ten pairs there is no outcome whatever —
not even a clean sweep — that a nine-fold corrected rule can call `supported`.

This is precisely the class of defect that killed five previous corpora: an
experiment whose null was decided by its own arithmetic before any data existed.
A pilot that cannot pass is a smoke test, and must be described as one. -/
theorem a_ten_pair_pilot_cannot_reach_a_corrected_verdict :
    ((List.range 11).filter (fun k => verdictM 9 10 k == Verdict.supported)) = [] ∧
    ((List.range 11).filter (fun k => verdictM 12 10 k == Verdict.supported)) = [] := by decide

/-- The uncorrected rule *can* pass at ten pairs, but only on a perfect sweep —
which is why quoting a pilot without its correction is how a null gets
manufactured in the other direction. -/
theorem only_the_uncorrected_rule_passes_at_ten :
    ((List.range 11).filter (fun k => verdictM 1 10 k == Verdict.supported)) = [0] := by decide

/-- **The smallest pilot that can return a corrected verdict is TWELVE pairs**,
and it tolerates nothing: a single loss sinks it. Sixteen pairs tolerate exactly
one. These are the numbers a pilot must be sized against.

Twice while writing this theorem a plausible bound was written down instead of
computed — first thirteen, then fourteen — and `decide` refused both. The number
came from a filter over every pair count up to seventeen, which is the only way
it should ever have been obtained. -/
theorem the_smallest_corrected_pilot_is_twelve_pairs :
    ((List.range 12).filter (fun k => verdictM 12 11 k == Verdict.supported)) = [] ∧
    ((List.range 13).filter (fun k => verdictM 12 12 k == Verdict.supported)) = [0] ∧
    ((List.range 17).filter (fun k => verdictM 12 16 k == Verdict.supported)) = [0, 1] := by decide

-- Executions. These run the definitions rather than restating them.
#guard row 0 = [1]
#guard row 1 = [1, 1]
#guard row 2 = [1, 2, 1]
#guard row 4 = [1, 4, 6, 4, 1]
#guard binom 10 0 = 1
#guard binom 10 5 = 252
#guard tail 10 0 = 1                     -- one way to go 10-for-10
#guard twoSidedTail 10 0 = 2
#guard 100 * twoSidedTail 10 0 = 200     -- ≤ 1024, so SUPPORTED
#guard 2 ^ 10 = 1024
#guard tail 10 5 = 638                   -- more than half the mass: a coin
#guard verdict 10 0 = Verdict.supported
#guard verdict 10 5 = Verdict.notSupported
#guard verdict 7 0 = Verdict.notSupported
#guard score [1, 2, 3] = 6
#guard scoreOf ⟨Arm.routed, [1, 2, 3]⟩ = scoreOf ⟨Arm.disarmed, [1, 2, 3]⟩
#guard honest sloppyRun = false
#guard honest pilotProtocol = true
#guard runVerdict honestNullRun = Verdict.notSupported

end RotMoE.Experiment
