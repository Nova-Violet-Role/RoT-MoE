/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# An endpoint whose control arm is already zero cannot show an improvement

The A/B has three pre-registered PRIMARY endpoints -- the ones chosen in advance
to detect whether routing changes how the model answers. Re-derived from
`bench/ab-metrics.jsonl` on 2026-08-08, over 88 paired turns:

    endpoint             routed   unrouted   pairs A<B   A>B   tie
    trailing question     0.000      0.000           0     0    88
    self-narration        0.000      0.000           0     0    88
    hedging tokens        0.045      0.011           1     4    83

Two of the three are identically zero in BOTH arms. It is tempting to read that
as "no effect". It is not a result at all: these are counts, counts are bounded
below by zero, and the control arm is already sitting on the bound. There is no
room to improve into. The sign test on such an endpoint returns `A<B = 0` for
every possible routed arm -- not because routing did nothing, but because the
comparison cannot express a win.

That is a defect in the MEASUREMENT, and it is the more useful finding, because
it is the one that says what to do next: an endpoint is only capable of
detecting an improvement if the control arm is off the floor somewhere. The
saturated pair should be reported as what it is -- a check that the voice
contract was not VIOLATED, which is a real if modest thing -- and the question
of whether routing helps has to be asked with an endpoint that has somewhere to
move.

The secondary endpoints are not saturated and they move hard: cost favoured
routed on 83 of 88 pairs, output tokens on 69, duration on 56. Those are real
measurements. They are also not what the voice contract claims.

This module proves the floor effect in general, and then instantiates it on the
measured corpus so the claim is about this A/B and not only about arithmetic.
-/

namespace RotMoE.Endpoint

/-- One paired observation: the routed arm and the control arm on the same
prompt. Counts, so `Nat`. -/
abbrev Pair := Nat × Nat

/-- The routed value. -/
def routed (p : Pair) : Nat := p.1

/-- The control value. -/
def control (p : Pair) : Nat := p.2

/-- The pair favours the routed arm when routing produced LESS of the thing
being counted (a question, a hedge, a narration line). -/
def favoursRouted (p : Pair) : Bool := routed p < control p

/-- And favours the control arm in the other direction. -/
def favoursControl (p : Pair) : Bool := control p < routed p

/-- Sign-test counts. -/
def winsRouted (ps : List Pair) : Nat := (ps.filter favoursRouted).length

/-- Sign-test counts, the other way. -/
def winsControl (ps : List Pair) : Nat := (ps.filter favoursControl).length

/-- An endpoint is SATURATED on a corpus when every control observation sits on
the floor. Nothing can be less than zero, so nothing can beat it. -/
def saturated (ps : List Pair) : Prop := ∀ p ∈ ps, control p = 0

/-- An endpoint is CAPABLE of showing an improvement when at least one control
observation is off the floor. -/
def capable (ps : List Pair) : Prop := ∃ p ∈ ps, 0 < control p

/-! ## The floor effect -/

/-- **The theorem.** On a saturated endpoint no pair can favour the routed arm.
This holds for every possible routed arm, which is what makes it a statement
about the instrument rather than about the result. -/
theorem saturated_pair_cannot_favour_routed (p : Pair) (h : control p = 0) :
    favoursRouted p = false := by
  unfold favoursRouted
  simp [h]

/-- Lifted to the corpus: a saturated endpoint scores zero wins for routing no
matter what routing did. -/
theorem saturated_scores_no_wins (ps : List Pair) (h : saturated ps) :
    winsRouted ps = 0 := by
  unfold winsRouted
  have : ps.filter favoursRouted = [] := by
    apply List.filter_eq_nil_iff.mpr
    intro p hp
    have := saturated_pair_cannot_favour_routed p (h p hp)
    simp [this]
  simp [this]

/-- **Saturated and capable are exclusive** on a non-empty corpus -- so calling
an endpoint saturated is exactly the claim that it has no power to show a win. -/
theorem saturated_is_not_capable (ps : List Pair) (h : saturated ps) : ¬ capable ps := by
  intro hc
  obtain ⟨p, hp, hpos⟩ := hc
  have := h p hp
  omega

/-- The one thing a saturated endpoint CAN still do: detect harm. If routing
adds any of the counted thing, the control arm wins that pair. This is why the
saturated primaries are worth keeping -- as a violation check, not as evidence
of benefit. -/
theorem saturated_still_detects_harm (p : Pair) (h : control p = 0) (hr : 0 < routed p) :
    favoursControl p = true := by
  unfold favoursControl
  simp [h, hr]

/-! ## The measured corpus -/

/-- The trailing-question endpoint: 88 pairs, zero in both arms. -/
def trailingQuestion : List Pair := List.replicate 88 (0, 0)

/-- The self-narration endpoint: 88 pairs, zero in both arms. -/
def selfNarration : List Pair := List.replicate 88 (0, 0)

/-- The hedging endpoint as measured: 83 ties at zero, 4 pairs where routing
hedged once more, 1 pair where the control hedged once more. -/
def hedging : List Pair :=
  List.replicate 83 (0, 0) ++ List.replicate 4 (1, 0) ++ [(0, 1)]

/-- Both zero endpoints are saturated. -/
theorem trailing_question_is_saturated : saturated trailingQuestion := by
  intro p hp
  have := List.eq_of_mem_replicate hp
  simp [control, this]

/-- Likewise self-narration. -/
theorem self_narration_is_saturated : saturated selfNarration := by
  intro p hp
  have := List.eq_of_mem_replicate hp
  simp [control, this]

/-- **So neither could ever have favoured routing.** The 0/0/88 rows in the
report were guaranteed by the choice of endpoint, before any turn was run. -/
theorem the_zero_endpoints_were_predetermined :
    winsRouted trailingQuestion = 0 ∧ winsRouted selfNarration = 0 :=
  ⟨saturated_scores_no_wins _ trailing_question_is_saturated,
   saturated_scores_no_wins _ self_narration_is_saturated⟩

/-- And neither is capable of showing an improvement. -/
theorem the_zero_endpoints_cannot_show_improvement :
    ¬ capable trailingQuestion ∧ ¬ capable selfNarration :=
  ⟨saturated_is_not_capable _ trailing_question_is_saturated,
   saturated_is_not_capable _ self_narration_is_saturated⟩

/-- **Hedging is different, and this is the honest part.** It is NOT saturated --
one control observation is off the floor -- so it could have shown a win. It
showed a loss instead: 4 pairs to 1 against routing. That is a real, if small,
negative result and it is not explained away by the floor effect. -/
theorem hedging_is_capable : capable hedging := by
  refine ⟨(0, 1), ?_, by decide⟩
  simp [hedging]

/-- The measured hedging counts, both directions. -/
theorem hedging_went_against_routing :
    winsRouted hedging = 1 ∧ winsControl hedging = 4 := by decide

/-! ## What a usable endpoint has to look like -/

/-- A corpus is INFORMATIVE for an improvement claim when some pair could have
gone either way -- there is room above the floor on the control side. -/
def informative (ps : List Pair) : Prop := capable ps

/-- Restated as the design rule this checkpoint produced: to ask whether routing
IMPROVES anything, pick an endpoint whose control arm is off the floor. The two
saturated primaries answer a different question -- did routing make it worse --
and they answered it: no. -/
theorem an_endpoint_must_be_capable_to_show_a_win (ps : List Pair) :
    ¬ informative ps → winsRouted ps = 0 := by
  intro h
  apply saturated_scores_no_wins
  intro p hp
  rcases Nat.eq_zero_or_pos (control p) with h0 | hpos
  · exact h0
  · exact absurd ⟨p, hp, hpos⟩ h

/-! ## Executable checks -/

/-- The three primaries as the report printed them. -/
example : (winsRouted trailingQuestion, winsControl trailingQuestion,
           winsRouted selfNarration, winsControl selfNarration,
           winsRouted hedging, winsControl hedging) = (0, 0, 0, 0, 1, 4) := by decide

/-- Ties account for the rest of the hedging corpus. -/
example : hedging.length = 88 := by decide

/-! ## A capable endpoint that still did not show a quality win

Having proved that two of the three published primaries were incapable of
showing improvement, I went looking for one that could. The A/B harness appends

    " Answer in one or two sentences."

to every prompt in BOTH arms (`bench/ab-session.sh`), so compliance with it is
scorable mechanically, after the fact, by a scorer that is identical on each
side. Its control arm is nowhere near the floor -- 41 violations in 88 turns --
so a win is expressible. It is `capable` in exactly the sense defined above.

**And the headline looked like the result the project needed:**

| | routed | unrouted |
|---|---|---|
| violations of the two-sentence limit | 23 / 88 (26.1 %) | 41 / 88 (46.6 %) |
| mean sentences | 2.18 | 3.25 |
| paired sign | 28 better | 10 better, 50 ties |

Two-sided sign test on the 38 discordant pairs: **p = 5.1e-3**.

**Then the confound killed it.** Routed answers are also 26 % shorter, and
sentence count rises with length nearly by construction (measured Pearson
r = 0.263 routed, r = 0.707 unrouted). So a brevity win drags compliance along
with it, and the endpoint risks being a second measurement of a result already
published rather than new evidence.

Isolating the wins brevity cannot account for -- pairs where the routed answer
complied AND was **not shorter** -- leaves **2 wins against 10 losses**
(p = 3.9e-2). On the de-confounded subset the effect **reverses**: routing is
mildly worse.

The conclusion this file records is therefore negative, and deliberately so: the
compliance win is the brevity result restated. No quality improvement from
nine-lens routing has been demonstrated, and on the only capable endpoint
measured so far the de-confounded sign points the other way.

One more reason not to trust this endpoint even as a negative: it counts
sentences, so a single 2080-character run-on scores as perfect compliance. That
case is in the corpus (turn 46), and `a_run_on_sentence_scores_as_compliant`
pins it.
-/

/-- A decomposition of the pairs an endpoint calls wins: those a known covariate
already explains, and those it does not. -/
structure Decomp where
  /-- Wins the covariate accounts for -- here, routed simply answered shorter. -/
  explained : Nat
  /-- Wins the covariate cannot account for. -/
  unexplained : Nat
  /-- Pairs lost, on the same de-confounded footing. -/
  losses : Nat
  deriving DecidableEq, Repr

/-- The measured decomposition of the compliance endpoint. -/
def compliance : Decomp := { explained := 26, unexplained := 2, losses := 10 }

/-- The headline count: every pair the endpoint scored for routing. -/
def headlineWins (d : Decomp) : Nat := d.explained + d.unexplained

/-- Does the endpoint favour routing once the covariate is removed? -/
def survivesDeconfounding (d : Decomp) : Bool := d.losses < d.unexplained

/-- **The headline was real** -- 28 wins against 10 losses. -/
theorem the_headline_favoured_routing :
    headlineWins compliance = 28 ∧ compliance.losses = 10
      ∧ compliance.losses < headlineWins compliance := by decide

/-- **And it does not survive.** Almost every win was one the covariate already
explained. -/
theorem the_compliance_win_was_brevity :
    survivesDeconfounding compliance = false := by decide

/-- **It does not merely fail to survive -- it reverses.** On the subset brevity
cannot explain, the control arm wins by five to one. -/
theorem the_deconfounded_subset_favours_control :
    compliance.unexplained < compliance.losses
      ∧ compliance.unexplained = 2 ∧ compliance.losses = 10 := by decide

/-- **The general lesson, not tied to these numbers.** Capability and honesty
are different properties: an endpoint can be perfectly capable of showing a win,
show one, and still be measuring something already known. Whenever the explained
share is large enough, the headline favours routing while the de-confounded
subset does not. -/
theorem capable_is_not_enough (d : Decomp)
    (hhead : d.losses < headlineWins d) (hdec : survivesDeconfounding d = false) :
    d.unexplained ≤ d.losses ∧ d.losses < d.explained + d.unexplained := by
  refine ⟨?_, hhead⟩
  simpa [survivesDeconfounding, Nat.not_lt] using hdec

/-- Contrapositive, stated as the test to apply: if an endpoint's wins are ALL
unexplained by the covariate, the headline and the de-confounded verdict agree.
Only a nonzero explained share can drive them apart. -/
theorem no_explained_wins_means_no_divergence (d : Decomp)
    (h : d.explained = 0) (hhead : d.losses < headlineWins d) :
    survivesDeconfounding d = true := by
  simp only [survivesDeconfounding, decide_eq_true_eq]
  simpa [headlineWins, h] using hhead

/-- The endpoint's own loophole: it counts sentences, not words. A single
enormous sentence is scored compliant. Turn 46 of the corpus is exactly this --
2080 characters, one sentence. -/
def compliesWithLimit (sentences : Nat) : Bool := sentences ≤ 2

/-- **Measured, and it is why even the negative reading is weak evidence.** -/
theorem a_run_on_sentence_scores_as_compliant :
    compliesWithLimit 1 = true := by decide

/-- Whereas three short sentences are scored a violation, whatever their length.
The endpoint has no view on quality at all -- only on punctuation. -/
theorem three_short_sentences_score_as_a_violation :
    compliesWithLimit 3 = false := by decide

-- Executable: the decomposition, and the two verdicts it produces.
#guard (headlineWins compliance, survivesDeconfounding compliance) = (28, false)

end RotMoE.Endpoint
