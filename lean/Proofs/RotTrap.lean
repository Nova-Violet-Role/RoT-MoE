/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

import Proofs.RotCeiling

/-!
# The trap corpus, designed BEFORE it is run

Four answer-quality corpora have now closed without establishing anything:

* instruction compliance -- headline 29-4, but 27 losses were explained by
  brevity and the deconfounded test gave p = 0.6875 (`RotAbVerdict`)
* grounding -- 8-0 routed, but the volume-matched control came back 0-0
  (`RotGrounding`)
* fact recall -- both arms 84/84, a ceiling (`RotCeiling`)
* calibration -- two reps over 80 items produced an informative band of ONE
  (`RotCeiling.noPower`, fourth confirmation)

The common cause is not the router. It is the *questions*: when both arms answer
correctly, the corpus cannot separate them no matter how many turns are spent.

A **trap** is an item where the naive method returns a specific WRONG answer and
the truth is mechanically derivable. This repository contains real ones, each a
defect that was actually made here:

* naive `grep -c '^theorem'` counts prose inside `/-! -/` (931 vs 919)
* `run_mut` *definitions* vs *invocations* (72 vs 62)
* `Proofs/RotMoe/` on disk vs `Proofs.RotMoE.` in imports -- a case-folding
  filesystem hides the difference from `lake build` but not from `leanchecker`
* `.release` is built from the worktree, `.release-local-only` from HEAD

This file fixes what such a corpus must satisfy, and -- the point of writing it
first -- what would make its verdict WORTHLESS. Every claim here is about the
DESIGN. None of it says the router will win.
-/

namespace RotTrap

/-- One corpus item: what a naive method answers, and what is mechanically true. -/
structure Item where
  naive : Nat
  truth : Nat
  deriving DecidableEq, Repr

/-- What each arm answered on that item. -/
structure Response where
  routed   : Nat
  unrouted : Nat
  deriving DecidableEq, Repr

/-- An item is a TRAP only if the naive answer is not the true one. An item
where they coincide hands the naive method a free pass and can never punish it. -/
def isTrap (i : Item) : Bool := i.naive != i.truth

def correct (i : Item) (a : Nat) : Bool := a == i.truth

/-- An item is INFORMATIVE for the comparison exactly when the arms disagree in
correctness. Both-right (ceiling) and both-wrong (floor) items carry no signal,
which is precisely what the four dead corpora ran into. -/
def informative (i : Item) (r : Response) : Bool :=
  correct i r.routed != correct i r.unrouted

abbrev Pair := Item × Response

def band    (xs : List Pair) : Nat := (xs.filter (fun p => informative p.1 p.2)).length
def ceiling (xs : List Pair) : Nat :=
  (xs.filter (fun p => correct p.1 p.2.routed && correct p.1 p.2.unrouted)).length
def floor   (xs : List Pair) : Nat :=
  (xs.filter (fun p => !correct p.1 p.2.routed && !correct p.1 p.2.unrouted)).length

/-! ## Every item lands in exactly one of the three buckets -/

theorem buckets_partition_the_corpus (xs : List Pair) :
    band xs + ceiling xs + floor xs = xs.length := by
  induction xs with
  | nil => rfl
  | cons p ps ih =>
    simp only [band, ceiling, floor, List.filter_cons, List.length_cons] at *
    cases hr : correct p.1 p.2.routed <;> cases hu : correct p.1 p.2.unrouted <;>
      simp [informative, hr, hu, List.length_cons] at * <;> omega

/-! ## A saturated corpus has no power, and padding does not help -/

/-- If every item is a ceiling item, the informative band is empty. This is the
formal statement of what the fact-recall corpus (84/84) and the calibration
corpus (band 1 of 80) ran into. -/
theorem a_saturated_corpus_has_an_empty_band (xs : List Pair)
    (h : ceiling xs = xs.length) : band xs = 0 := by
  have := buckets_partition_the_corpus xs
  omega

/-- Padding a corpus with items BOTH arms answer correctly cannot widen the
band. Adding easy questions is not a fix for a saturated corpus -- it is the
same mistake that produced 80 items and a band of one. -/
theorem padding_with_ceiling_items_never_widens_the_band
    (xs ys : List Pair) (h : ∀ p ∈ ys, informative p.1 p.2 = false) :
    band (xs ++ ys) = band xs := by
  simp only [band, List.filter_append, List.length_append]
  have : ys.filter (fun p => informative p.1 p.2) = [] := by
    apply List.filter_eq_nil_iff.mpr
    intro p hp
    simp [h p hp]
  simp [this]

/-! ## Circular selection: the defect that would make the whole run worthless -/

/-- Selecting the items on which the routed arm won, and then reporting the win
rate over that selection. -/
def selectRoutedWins (xs : List Pair) : List Pair :=
  xs.filter (fun p => correct p.1 p.2.routed && !correct p.1 p.2.unrouted)

/-- **The reason the corpus must be fixed before the run.** Every item surviving
this selection is a routed win by construction, so the reported rate is 1
whatever the router does. This is not a statement about RoT MoE; it is a
statement about the procedure. -/
theorem circular_selection_cannot_lose (xs : List Pair) :
    (selectRoutedWins xs).all (fun p => correct p.1 p.2.routed) = true := by
  simp only [selectRoutedWins, List.all_eq_true, List.mem_filter]
  intro p hp
  have := hp.2
  simp only [Bool.and_eq_true] at this
  exact this.1

/-- And it cannot lose even when the router is wrong on *every other* item, so a
clean sweep under circular selection is evidence of nothing at all. -/
theorem circular_selection_sweeps_even_a_bad_router (xs : List Pair) :
    (selectRoutedWins xs).all (fun p => !correct p.1 p.2.unrouted) = true := by
  simp only [selectRoutedWins, List.all_eq_true, List.mem_filter]
  intro p hp
  have := hp.2
  simp only [Bool.and_eq_true] at this
  exact this.2

/-! ## Traps are what make the unrouted arm capable of losing -/

/-- On a non-trap item the naive method is already right, so an arm that merely
applies it is scored correct. Such an item cannot discriminate. -/
theorem a_non_trap_gives_the_naive_method_a_free_pass (i : Item) (h : i.naive = i.truth) :
    correct i i.naive = true := by
  simp [correct, h]

/-- On a genuine trap the naive method is scored WRONG -- this is the property
the corpus is built to exploit, and it is the exact negation of the above. -/
theorem a_trap_punishes_the_naive_method (i : Item) (h : isTrap i = true) :
    correct i i.naive = false := by
  simp only [isTrap, bne_iff_ne, ne_eq] at h
  simp [correct, h]

/-- Selection by trap-hood looks at the ITEM only, never at either arm's answer,
so it cannot manufacture a win the way `selectRoutedWins` does. Stated the way
that can actually fail: run the SAME items under two entirely different answer
assignments and the selected items are identical. -/
theorem trap_selection_ignores_the_answers (is : List Item) (f g : Item → Response) :
    ((is.map (fun i => (i, f i))).filter (fun p => isTrap p.1)).map Prod.fst
      = ((is.map (fun i => (i, g i))).filter (fun p => isTrap p.1)).map Prod.fst := by
  induction is with
  | nil => rfl
  | cons a as ih =>
    by_cases h : isTrap a = true <;> simp [List.filter_cons, h, ih]

/-- The contrast that gives the previous theorem its teeth: `selectRoutedWins`
does NOT have that property. Two answer assignments over one item list select
different sets -- so it is the answers, not the questions, driving the filter. -/
theorem routed_win_selection_does_depend_on_the_answers :
    selectRoutedWins [(⟨931, 919⟩, ⟨919, 931⟩)] ≠ selectRoutedWins [(⟨931, 919⟩, ⟨931, 919⟩)] := by
  decide

/-! ## A pre-registered floor, so a dead corpus is refused up front -/

/-- The corpus is worth running only if its informative band reaches a
pre-registered minimum. Stated as a decision, not a hope. -/
def worthRunning (xs : List Pair) (minBand : Nat) : Bool := minBand ≤ band xs

theorem an_empty_corpus_is_never_worth_running (minBand : Nat) (h : 0 < minBand) :
    worthRunning [] minBand = false := by
  have hb : band ([] : List Pair) = 0 := rfl
  rw [worthRunning, hb]
  exact decide_eq_false (by omega)

theorem a_saturated_corpus_is_refused (xs : List Pair) (minBand : Nat)
    (hsat : ceiling xs = xs.length) (h : 0 < minBand) :
    worthRunning xs minBand = false := by
  have hb := a_saturated_corpus_has_an_empty_band xs hsat
  simp only [worthRunning, hb, decide_eq_false_iff_not]
  omega

/-! ## Concrete witnesses -- the definitions must EXECUTE, not merely elaborate -/

/-- A trap modelled on the real one: naive theorem-count 931, truth 919. -/
def realTrap : Item := ⟨931, 919⟩
/-- A non-trap: both methods agree. -/
def easy : Item := ⟨7, 7⟩

/-- Routed gets the trap right, unrouted falls for the naive answer. -/
def routedWins : Response := ⟨919, 931⟩
/-- Both arms right. -/
def bothRight : Response := ⟨919, 919⟩
/-- Both arms wrong. -/
def bothWrong : Response := ⟨1, 2⟩

#guard isTrap realTrap = true
#guard isTrap easy = false
#guard correct realTrap 919 = true
#guard correct realTrap 931 = false
#guard informative realTrap routedWins = true
#guard informative realTrap bothRight = false
#guard informative realTrap bothWrong = false

#guard band [(realTrap, routedWins)] = 1
#guard band [(realTrap, bothRight)] = 0
#guard band [(realTrap, bothWrong)] = 0
#guard ceiling [(realTrap, bothRight)] = 1
#guard floor [(realTrap, bothWrong)] = 1

/-- The saturated corpus that actually happened: 80 items, band 1. -/
def saturated80 : List Pair :=
  (realTrap, routedWins) :: List.replicate 79 (realTrap, bothRight)

#guard band saturated80 = 1
#guard ceiling saturated80 = 79
#guard saturated80.length = 80
#guard worthRunning saturated80 20 = false
#guard worthRunning saturated80 1 = true

/-- Circular selection over a corpus where the router lost most items still
reports a clean sweep -- the concrete form of `circular_selection_cannot_lose`. -/
def mostlyLost : List Pair :=
  (realTrap, routedWins) :: List.replicate 19 (realTrap, ⟨931, 919⟩)

#guard mostlyLost.length = 20
#guard (selectRoutedWins mostlyLost).length = 1
#guard (selectRoutedWins mostlyLost).all (fun p => correct p.1 p.2.routed) = true
#guard band mostlyLost = 20

end RotTrap
