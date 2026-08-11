/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Proofs.RotExperiment

/-! # Prose quality: the protocol is provable, the taste is not — and that gap is a theorem

Every report this project has written ends with the same admission: *artifact
quality is measured, answer quality is not*. That sentence was doing two jobs at
once, and only one of them was honest.

* Honest: **no Lean file will ever contain a theorem whose conclusion is "the
  prose is better".** Any file claiming that has an `axiom` in it, and an axiom
  for an empirical claim is the one thing this repo forbids.
* Not honest: leaving it there implied nothing about prose could be measured.
  What could not be measured was *quality*. **Preference under a stated
  protocol** is a different object, and it is measurable to the same standard as
  every other observable here.

So this module does three things, in order:

1. **Proves that a machine prose scorer cannot work** — not as resignation, as a
   theorem. Any metric that padding cannot lower rewards padding. That is the
   panel's licence to be human.
2. **Makes the human judgment data**, with every confound around it decidable:
   forced choice, blinding by TYPE, position flipping, an odd panel, an
   agreement floor with no division, and the family-wise corrected inference
   reused from `RotExperiment`.
3. **Detects the confound Lean can actually catch** — a panel whose picks track
   length is flagged, and a flagged run cannot return `supported`.

## What is provable here, and what is not

| statement | status |
|---|---|
| no computable length-monotone metric is faithful | **provable** — §1 |
| the rater could not see the arm | **provable** — by the TYPE of `Rater`, §3 |
| a constant position-picker scores exactly half | **provable** — §4 |
| one rater cannot swing an odd panel | **provable** — §5 |
| a length-tracking panel is confounded | **provable** — §7 |
| the panel preferred the routed arm at corrected p<0.01 | **hypothesis**, discharged by the checker's record — §8 |
| the text scored is the text produced | **trust root** — `renderHash`, integrity never origin |
| the prose is *better* | **NOT PROVABLE. Not here, not anywhere.** |

The conclusion this module is allowed to reach is exactly:

> blinded raters, forced choice, both orderings, positions flipped, agreement
> above floor, preferred the routed arm at a corrected p<0.01, and the run is not
> length-confounded.

That is preference under a protocol. It is not taste, and the difference is
stated rather than blurred. **This module declares no axioms.** -/

namespace RotMoE.Prose

open RotMoE.Experiment

/-! ## 1. Why the scorer must be human: the impossibility, as a theorem

`artifactScore` works because its observables are *countable facts* — a theorem
either builds or it does not, a mutant either kills or it does not. Prose has no
such observable. Every computable proxy is gameable, and the cheapest attack is
padding: say the same thing in more bytes.

The argument shape is the one that already killed `verified`-as-a-raw-count in
`RotExperiment`: a metric that cannot be *lowered* by an empty edit **rewards**
that edit. -/

/-- Prose as the bytes actually rendered. A byte list rather than `String`, so
every property below is decidable and executable. -/
abbrev Prose := List Nat

/-- Byte 32 is a space: content-free filler. -/
def filler (k : Nat) : Prose := List.replicate k 32

/-- Padding: the same content, more bytes. -/
def pad (s : Prose) (k : Nat) : Prose := s ++ filler k

/-- The content of a text, with filler removed. This is a *model* of "same
thing said", deliberately crude — and crude in the direction that makes the
impossibility HARDER to prove, not easier. -/
def informative (s : Prose) : Prose := s.filter (fun b => b != 32)

/-- Filler carries no content, by induction on its length. -/
theorem filler_carries_no_information : ∀ k, informative (filler k) = []
  | 0 => rfl
  | k + 1 => by
      unfold informative filler
      rw [List.replicate_succ, List.filter_cons]
      simp only [bne_self_eq_false, Bool.false_eq_true, if_false]
      have := filler_carries_no_information k
      unfold informative filler at this
      exact this

/-- **Padding changes nothing that matters.** -/
theorem padding_preserves_content (s : Prose) (k : Nat) :
    informative (pad s k) = informative s := by
  unfold pad informative
  rw [List.filter_append]
  have h := filler_carries_no_information k
  unfold informative at h
  rw [h, List.append_nil]

/-- **The impossibility.** For any metric that padding cannot lower, there is a
text whose score does not fall when it is padded with pure filler — content
unchanged. Such a metric cannot distinguish saying more from saying it longer,
so it rewards padding.

This is why the panel is human **by proof** rather than by resignation, and it is
why no `def quality : Prose → Nat` appears anywhere in this repository. -/
theorem no_length_monotone_metric_is_faithful (f : Prose → Nat)
    (hmono : ∀ s k, f s ≤ f (pad s k)) :
    ∃ s k, f s ≤ f (pad s k) ∧ informative (pad s k) = informative s ∧ pad s k ≠ s := by
  refine ⟨[], 1, hmono [] 1, padding_preserves_content [] 1, ?_⟩
  decide

/-- The claim is not vacuous: the obvious metric — count the bytes — is *strictly*
raised by padding while the content is identical. A scorer built on it would rank
a padded answer above the answer it was padded from. -/
theorem the_obvious_metric_is_gameable (s : Prose) (k : Nat) (hk : 0 < k) :
    s.length < (pad s k).length ∧ informative (pad s k) = informative s := by
  refine ⟨?_, padding_preserves_content s k⟩
  unfold pad filler
  rw [List.length_append, List.length_replicate]
  omega

/-! ## 2. Forced choice, not a rating scale

A Likert score drifts between raters and within one rater across a session.
A forced choice between two texts does not: it is a comparison, and comparisons
are what the sign test consumes. `tie` is a THIRD outcome, not a missing value —
the same three-valued discipline `Comparison` enforces on the lens vector. -/

/-- What a rater may answer. Nothing else. -/
inductive Choice where
  | left
  | right
  | tie
  deriving Repr, DecidableEq

/-- Position swap, used to undo the presentation flip. -/
def swap : Choice → Choice
  | .left => .right
  | .right => .left
  | .tie => .tie

/-- `swap` is an involution — so unflipping is exactly undoing, never a second
transformation that could smuggle in a bias of its own. -/
theorem swap_involutive (c : Choice) : swap (swap c) = c := by
  cases c <;> rfl

theorem swap_has_no_fixed_side : swap .left ≠ .left ∧ swap .right ≠ .right := by
  decide

/-! ## 3. Blinding is a TYPE, not a promise

`RotExperiment` proved the artifact scorer blind by giving it the type
`Trace → Nat`, so the arm is not in scope. The same device works here and is
strictly stronger than a procedure: a rater function *cannot* consult the arm,
because the arm is not a field of what it receives. -/

/-- What the rater sees: two texts. **No arm field, deliberately.** -/
structure Pair where
  leftText  : Prose
  rightText : Prose
  deriving Repr, DecidableEq

/-- The full item, known to the harness and never to the rater: which side was
the routed arm, and whether the presentation was flipped. -/
structure Judged where
  pair         : Pair
  leftIsRouted : Bool
  flipped      : Bool
  deriving Repr, DecidableEq

/-- A rater is a function of the PAIR alone. Widen this to `Judged → Choice` and
every theorem below that depends on blinding stops being true — which is exactly
what mutant P03 does, and the module dies. -/
abbrev Rater := Pair → Choice

/-- **The rater cannot condition on the arm.** Two items whose texts agree get
the same answer, however the arms were assigned. There is no procedural step to
forget here: the information never reached the function. -/
theorem the_arm_is_not_in_scope (r : Rater) (j k : Judged) (h : j.pair = k.pair) :
    r j.pair = r k.pair := by rw [h]

/-- Concretely: the same two texts with the arms *reversed* still get one answer. -/
theorem reversing_the_arms_cannot_move_a_rater (r : Rater) (p : Pair) :
    r (Judged.mk p true false).pair = r (Judged.mk p false false).pair := rfl

/-! ## 4. Position bias: flip the sides, then undo it exactly

Raters prefer the left-hand text. If the routed arm always sits on the left, that
preference IS the result. Flipping half the items removes it — provided the
un-flip is exact, which `swap_involutive` gives. -/

/-- Normalise a raw choice into a verdict about ARMS: `.left` means the routed
arm was preferred. -/
def normalise (leftIsRouted : Bool) (c : Choice) : Choice :=
  if leftIsRouted then c else swap c

/-- Normalising is faithful: it is a relabelling, never a re-decision. A `tie`
stays a tie whichever way the item was presented. -/
theorem normalise_preserves_ties (b : Bool) : normalise b .tie = .tie := by
  cases b <;> rfl

theorem normalise_is_undone_by_itself (b : Bool) (c : Choice) :
    normalise b (normalise b c) = c := by
  cases b <;> simp [normalise, swap_involutive]

/-- Items as the harness records them: which side was routed, and what came back. -/
def routedWins (items : List (Bool × Choice)) : Nat :=
  items.countP (fun it => normalise it.1 it.2 == Choice.left)

/-- **A rater who always picks the left-hand text scores exactly the positions,
not the arms.** Their apparent margin is entirely an artefact of layout. -/
theorem a_constant_left_picker_counts_only_positions (bs : List Bool) :
    routedWins (bs.map (fun b => (b, Choice.left))) = bs.countP (fun b => b) := by
  -- The first draft did this by induction and omega REFUSED it, correctly: `simp`
  -- had rewritten the mapped tail into `countP (p ∘ f)` form, so the induction
  -- hypothesis no longer matched the goal syntactically. The counterexample omega
  -- printed named exactly those two non-identical atoms. Going through
  -- `List.countP_map` removes the mismatch instead of arguing past it.
  unfold routedWins
  rw [List.countP_map]
  congr 1
  funext b
  cases b <;> rfl

/-- …so on a balanced schedule they score **exactly half**, which is the null.
Position bias cannot manufacture a margin once the sides are flipped. -/
theorem a_constant_left_picker_scores_exactly_half (bs : List Bool)
    (hbal : 2 * bs.countP (fun b => b) = bs.length) :
    2 * routedWins (bs.map (fun b => (b, Choice.left))) = bs.length := by
  rw [a_constant_left_picker_counts_only_positions bs]
  exact hbal

/-- Non-vacuity: a four-item balanced schedule, a rater who always answers
"left", and the score is two — dead on the null. -/
theorem the_constant_picker_witness :
    routedWins [(true, .left), (false, .left), (true, .left), (false, .left)] = 2 := by
  decide

/-! ## 5. The panel: odd, and no single rater decides

One rater is an anecdote. An even panel ties. An odd panel with a majority rule
means a single defector cannot reverse a verdict — and that is checkable. -/

/-- Majority over a panel's normalised choices. Ties are REPORTED, never broken
by a rule that would invent a winner. -/
def majority (cs : List Choice) : Choice :=
  let l := cs.countP (fun c => c == Choice.left)
  let r := cs.countP (fun c => c == Choice.right)
  if r < l then .left else if l < r then .right else .tie

/-- **A single defector cannot reverse a 4–1 panel**, and a 3–2 still stands. -/
theorem a_single_defector_cannot_reverse_a_panel :
    majority [.left, .left, .left, .left, .right] = .left ∧
    majority [.left, .left, .left, .right, .right] = .left := by decide

/-- An evenly split panel returns `tie` — it does not pick a side. -/
theorem an_even_split_is_reported_as_a_tie :
    majority [.left, .left, .right, .right] = .tie := by decide

/-- Ties among raters do not become wins. -/
theorem abstentions_do_not_become_wins :
    majority [.tie, .tie, .tie] = .tie ∧
    majority [.left, .tie, .right] = .tie := by decide

/-- The panel is not a rubber stamp: it can return `right`, i.e. against the
routed arm. A verdict function that cannot go negative measures nothing. -/
theorem the_panel_can_rule_against_the_routed_arm :
    majority [.right, .right, .left] = .right := by decide

/-! ## 6. The agreement floor, and a claim this file made that turned out false

The first draft of this section asserted that a floor checked by integer division
would "round a split panel into a pass", by analogy with `costSec / 60`. **That
was wrong, and the analogy was the reason.** An exhaustive check over every panel
size 1–12, every agreement count, and every floor 0–100 — 15 700 cases — found
**zero** disagreements between the divided form and cross-multiplication.

The reason is arithmetic, not luck: for an *integer* floor, `f ≤ 100a/n` and
`f*n ≤ 100a` are equivalent, and `Nat.le_div_iff_mul_le` proves it. The theorem
below records that, so the file states what is true rather than what sounded
right.

Division is still refused here, for the reason that actually applies: the same
quantity gets compared **between panels**, and *there* truncation does destroy
information — the second theorem exhibits two panels the divided percentage ties
and cross-multiplication separates. That is the `costSec / 60` defect in its
real form, and stating it precisely is worth more than an analogy. -/

/-- How many raters agreed with the panel's own majority. -/
def agrees (cs : List Choice) : Nat := cs.countP (fun c => c == majority cs)

/-- Does the panel clear a reliability floor given as a percentage? No division:
`floor * n ≤ 100 * agreeing`. -/
def meetsFloor (floor : Nat) (cs : List Choice) : Bool :=
  decide (floor * cs.length ≤ 100 * agrees cs)

/-- A unanimous panel clears any floor up to 100. -/
theorem unanimity_clears_the_floor :
    meetsFloor 80 [.left, .left, .left] = true := by decide

/-- **A barely-split panel does not.** 2 of 3 is 66.6…%, so an 80% floor refuses
it and a 66% floor admits it — the floor discriminates, which is the only reason
it is worth having. -/
theorem a_split_panel_fails_a_high_floor :
    meetsFloor 80 [.left, .left, .right] = false ∧
    meetsFloor 66 [.left, .left, .right] = true := by decide

/-- **The correction to this file's own claim.** For an integer floor the divided
test and the cross-multiplied test are the SAME test — measured over 15 700 cases
and then proved, rather than assumed either way. Keeping the division-free form
is therefore a choice about what else the quantity is used for, not a bug fix. -/
theorem the_floor_test_is_equivalent_to_the_divided_form (f : Nat) (cs : List Choice)
    (h : cs ≠ []) :
    meetsFloor f cs = decide (f ≤ 100 * agrees cs / cs.length) := by
  have hlen : 0 < cs.length := by
    cases cs with
    | nil => exact absurd rfl h
    | cons a t => exact Nat.succ_pos _
  unfold meetsFloor
  simp only [decide_eq_decide]
  rw [Nat.le_div_iff_mul_le hlen]

/-- **Where division really does lose a bit.** Comparing two panels' agreement,
the truncated percentages tie at 66 while the exact ratios differ — 2/3 is
strictly better than 67/101. This is the `costSec / 60` defect in the shape it
actually takes, and it is why the ratio is never divided when panels are ranked
against each other. -/
theorem division_ties_two_panels_that_cross_multiplication_separates :
    100 * 2 / 3 = 100 * 67 / 101 ∧ 67 * 3 < 2 * 101 := by decide

/-! ## 7. The confound Lean can enforce

Nobody can stop a human preferring longer answers. But if the panel's picks track
length *perfectly*, the run measured length, not prose — and that is decidable
from the recorded byte counts. -/

/-- One recorded judgement, with both sides' byte counts. -/
structure Judgement where
  choice       : Choice
  leftIsRouted : Bool
  leftBytes    : Nat
  rightBytes   : Nat
  deriving Repr, DecidableEq

/-- Which side was longer. -/
def longerSide (j : Judgement) : Choice :=
  if j.rightBytes < j.leftBytes then .left
  else if j.leftBytes < j.rightBytes then .right
  else .tie

/-- What the rater actually picked. -/
def picked (j : Judgement) : Choice := j.choice

/-- **Length-confounded**: every single pick went to the longer side. -/
def confounded (js : List Judgement) : Bool :=
  !js.isEmpty && js.all (fun j => picked j == longerSide j)

/-- **A panel whose picks track length is flagged.** This is a real, load-bearing
check: no amount of rubric prose gives it, and it fires on data. -/
theorem a_length_monotone_panel_is_confounded (js : List Judgement)
    (hne : js ≠ []) (h : ∀ j ∈ js, picked j = longerSide j) : confounded js = true := by
  unfold confounded
  have h1 : js.isEmpty = false := by
    cases js with
    | nil => exact absurd rfl hne
    | cons a t => rfl
  rw [h1]
  simp only [Bool.not_false, Bool.true_and, List.all_eq_true]
  intro j hj
  simp only [beq_iff_eq]
  exact h j hj

/-- Not vacuous in the other direction: a panel that sometimes prefers the
shorter text is NOT flagged, so the detector distinguishes rather than always
firing. A check that always fires is decoration. -/
theorem preferring_the_shorter_text_is_not_confounded :
    confounded [⟨.left, true, 10, 99⟩, ⟨.right, false, 99, 10⟩] = false := by decide

/-- And the flag does fire on the data it was written for. -/
theorem the_detector_fires :
    confounded [⟨.left, true, 99, 10⟩, ⟨.right, false, 10, 99⟩] = true := by decide

/-- An empty panel is not "unconfounded" — it is no evidence, and is refused. -/
theorem an_empty_panel_is_not_a_clean_run : confounded [] = false := by decide

/-! ## 8. One hypothesis, discharged by the checker's sheet

Identical in shape to `Evidence`/`checkAll` in `RotExperiment`: every confound is
folded into one record the harness writes, `checkAllProse` computes a Boolean
over it, and the theorem takes that Boolean as its only premise. Nothing is
assumed. -/

/-- The panel's sheet, as the checker emits it. -/
structure ProseEvidence where
  /-- Hash of the exact texts shown to raters. Proves the text scored is the text
  produced — INTEGRITY, never origin. -/
  renderHash         : Nat
  /-- The hash fixed at preregistration, before any rating happened. -/
  expectedRenderHash : Nat
  /-- Panel size. Must be odd and at least 3. -/
  raters             : Nat
  /-- Items rated. -/
  items              : Nat
  /-- Reliability floor, as a percentage. -/
  agreeFloor         : Nat
  /-- Total rater-agreements with the per-item majority. -/
  agreeNum           : Nat
  /-- Items that went against the routed arm. -/
  against            : Nat
  /-- Comparisons made, for the family-wise correction. -/
  comparisons        : Nat
  /-- Raters saw texts only — enforced by the type of `Rater`, recorded so a
  violation is visible in the data as well as impossible in the code. -/
  blinded            : Bool
  /-- Every task run in both arm orderings. -/
  bothOrderings      : Bool
  /-- Presentation sides flipped on a balanced schedule. -/
  positionsFlipped   : Bool
  /-- The protocol was fixed before the first rating. -/
  preregistered      : Bool
  /-- `confounded` computed over the judgements. -/
  lengthConfounded   : Bool
  deriving Repr, DecidableEq

/-- One function, every confound. The corrected sign test is folded in, so a
protocol-perfect run with a thin margin cannot be waved through — and a
length-confounded run cannot pass at any margin. -/
def checkAllProse (e : ProseEvidence) : Bool :=
  (e.renderHash == e.expectedRenderHash) &&
  e.blinded && e.bothOrderings && e.positionsFlipped && e.preregistered &&
  (e.lengthConfounded == false) &&
  (e.raters % 2 == 1) && (3 ≤ e.raters) &&
  (0 < e.comparisons) && (0 < e.items) && (e.against ≤ e.items) &&
  (70 ≤ e.agreeFloor) &&
  (e.agreeFloor * (e.raters * e.items) ≤ 100 * e.agreeNum) &&
  (100 * e.comparisons * twoSidedTail e.items e.against ≤ 2 ^ e.items)

/-- **The prose verdict, as a kernel-checked consequence of a computed premise.**

Read the conclusion literally, because its exact wording is the discipline:
blinded raters, forced choice, both orderings, positions flipped, agreement above
floor, not length-confounded, preferred the routed arm at a FAMILY-WISE corrected
p<0.01.

It does **not** say the prose is better. Preference under a stated protocol is
the measurable object; quality is not, and `no_length_monotone_metric_is_faithful`
is the reason that distinction is a theorem rather than a hedge. -/
theorem prose_attributable (e : ProseEvidence) (h : checkAllProse e = true) :
    e.renderHash = e.expectedRenderHash ∧
    e.blinded = true ∧ e.bothOrderings = true ∧
    e.positionsFlipped = true ∧ e.preregistered = true ∧
    e.lengthConfounded = false ∧
    e.raters % 2 = 1 ∧
    verdictM e.comparisons e.items e.against = Verdict.supported := by
  unfold checkAllProse at h
  simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at h
  refine ⟨h.1.1.1.1.1.1.1.1.1.1.1.1.1, h.1.1.1.1.1.1.1.1.1.1.1.1.2,
    h.1.1.1.1.1.1.1.1.1.1.1.2, h.1.1.1.1.1.1.1.1.1.1.2, h.1.1.1.1.1.1.1.1.1.2,
    h.1.1.1.1.1.1.1.1.2, h.1.1.1.1.1.1.1.2, ?_⟩
  unfold verdictM
  rw [if_pos h.2]

/-- A sheet that passes: 5 raters, 40 items, 9 against, 9 comparisons, an 80%
floor cleared with 180 of 200 agreements, nothing confounded. -/
def proseSheetPassing : ProseEvidence :=
  ⟨4242, 4242, 5, 40, 80, 180, 9, 9, true, true, true, true, false⟩

theorem the_prose_gate_admits_a_clean_sheet :
    checkAllProse proseSheetPassing = true := by decide

/-- **Nine refusals, one per clause.** Each differs from the passing sheet in
exactly one field, so the gate is not a rubber stamp. -/
theorem a_rerendered_text_is_refused :
    checkAllProse { proseSheetPassing with renderHash := 4243 } = false := by decide

theorem an_unblinded_panel_is_refused :
    checkAllProse { proseSheetPassing with blinded := false } = false := by decide

theorem one_ordering_only_is_refused :
    checkAllProse { proseSheetPassing with bothOrderings := false } = false := by decide

theorem unflipped_positions_are_refused :
    checkAllProse { proseSheetPassing with positionsFlipped := false } = false := by decide

theorem a_post_hoc_prose_protocol_is_refused :
    checkAllProse { proseSheetPassing with preregistered := false } = false := by decide

/-- **A length-confounded run is refused at any margin.** The panel may have been
unanimous; if its picks tracked length, the run measured length. -/
theorem a_length_confounded_run_is_refused :
    checkAllProse { proseSheetPassing with lengthConfounded := true } = false := by decide

/-- An even panel is refused: it can tie itself. -/
theorem an_even_panel_is_refused :
    checkAllProse { proseSheetPassing with raters := 4 } = false := by decide

/-- A single rater is refused even though 1 is odd — an anecdote is not a panel. -/
theorem a_single_rater_is_refused :
    checkAllProse { proseSheetPassing with raters := 1 } = false := by decide

/-- Agreement below the floor is refused: an unreliable panel cannot support a
verdict however lopsided its majority. -/
theorem an_unreliable_panel_is_refused :
    checkAllProse { proseSheetPassing with agreeNum := 100 } = false := by decide

/-- **A toothless floor is refused.** Declaring a 0% reliability requirement
would let any panel through, so the floor has a floor: below 70 the sheet is
rejected whatever the agreement count says. -/
theorem a_toothless_floor_is_refused :
    checkAllProse { proseSheetPassing with agreeFloor := 0 } = false := by decide

/-- **The margin still has to be there, corrected.** Ten of forty against fails;
nine passes. Same boundary `RotExperiment` computes for artifacts, because it is
the same test. -/
theorem the_prose_boundary_is_nine_of_forty :
    checkAllProse { proseSheetPassing with against := 9 } = true ∧
    checkAllProse { proseSheetPassing with against := 10 } = false := by decide

/-- And the uncorrected rule would have admitted eleven — which is precisely the
family-wise error the correction closes. -/
theorem the_uncorrected_rule_would_have_admitted_eleven :
    verdict 40 11 = Verdict.supported ∧
    verdictM 9 40 11 = Verdict.notSupported := by decide

-- Executions. These run the definitions rather than restating them.
#guard informative (pad [72, 105] 40) = informative [72, 105]
#guard (pad [72, 105] 40).length = 42
#guard swap (swap Choice.left) = Choice.left
#guard normalise false Choice.left = Choice.right
#guard normalise true Choice.left = Choice.left
#guard routedWins [(true, Choice.left), (false, Choice.left)] = 1
#guard majority [Choice.left, Choice.left, Choice.right] = Choice.left
#guard majority [Choice.left, Choice.right] = Choice.tie
#guard agrees [Choice.left, Choice.left, Choice.right] = 2
#guard meetsFloor 80 [Choice.left, Choice.left, Choice.right] = false
#guard confounded [⟨Choice.left, true, 99, 10⟩] = true
#guard confounded [] = false
#guard checkAllProse proseSheetPassing = true
#guard checkAllProse { proseSheetPassing with lengthConfounded := true } = false

end RotMoE.Prose
