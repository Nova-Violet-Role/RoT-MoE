/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — an event dispatch that cannot call itself forever

Subject: `src/app/ctbrec/ui/controls/range/CustomInputMap.java` and the tick arithmetic in
`RangeSliderBehavior.getNewPosition`.

## The measurement

`tools/InputMapDispatchCheck.java` runs the real class against the real JavaFX classes. Against
the version that shipped:

| probe | result |
|---|---|
| one `handleMouseClicked` | **StackOverflowError** |
| ten in a row | **StackOverflowError** |
| a caller-registered re-entrant binding | **StackOverflowError** |
| a registered binding still fires | ok (2 of 2) |
| a key binding fires for its own code only | ok |

The constructor registers `MOUSE_CLICKED → handleMouseClicked(null)`
(`CustomInputMap.java:20`), and `handleMouseClicked` looks up `MOUSE_CLICKED` and runs whatever
it finds (`:39`). The action re-enters the dispatcher that invoked it, unconditionally.

Every `RangeSlider` skin builds one of these: `RangeSlider.createDefaultSkin` →
`new RangeSliderBehavior<>(this)` → `new CustomInputMap<>(rangeSlider)`, and `RangeSlider` is
live — `CtbrecPreferencesStorage:153` uses it. So the recursion is armed on a real UI path.

## Why no user has hit it

Measured: `getInputMap()` has **zero** callers, and `handleKeyPressed`, `handleMouseDragged`,
`handleMouseReleased` have zero callers outside the class. Nothing dispatches to the map, so the
armed call never fires. `RangeSliderBehavior` handles clicks through its own
`addEventFilter(MOUSE_CLICKED, this::sliderClicked)` instead.

That is a **contingent** fact of today's wiring, exactly like the XML parser at checkpoint 49, and
it is not asserted anywhere here. Wiring the input map up is the obvious next change — it is what
the class is for — and a spec that went red on it would be a spec that punishes the repair.

## The general fix, not the specific one

Deleting the one bad default binding would make the measured probe pass while leaving the next
re-entrant binding to blow the stack — and a caller-registered one is measured to do exactly that
(probe C). So the repair is a re-entrancy guard on the dispatcher itself, and the theorem is
quantified over **every** binding table, including hostile ones:
`guarded_dispatch_terminates_for_every_table`.

The dual obligation is that a guard which dispatches nothing would satisfy termination trivially,
so `a_bound_action_still_fires_exactly_once` and probe D exist to forbid that.
-/

namespace CtbrecSpec

/-- The event kinds this map dispatches. Names match the strings in the Java. -/
inductive InputEvent where
  | mouseClicked
  | mouseDragged
  | mouseReleased
  | keyPressed
  deriving DecidableEq, Repr

def allInputEvents : List InputEvent :=
  [.mouseClicked, .mouseDragged, .mouseReleased, .keyPressed]

/-- A registered action, modelled by the only property that matters for termination: which event
it re-dispatches, if any. `none` is an ordinary action that just runs. -/
structure Action where
  reenters : Option InputEvent
  deriving DecidableEq, Repr

/-- The binding table. `lookup` mirrors `HashMap.get` returning null when absent. -/
structure InputMap where
  bindings : List (InputEvent × Action)
  deriving DecidableEq, Repr

def lookup (m : InputMap) (e : InputEvent) : Option Action :=
  (m.bindings.find? (fun b => b.1 == e)).map Prod.snd

/-- **The table the shipped constructor builds**: `MOUSE_CLICKED` bound to an action that
re-dispatches `MOUSE_CLICKED`. -/
def shippedMap : InputMap := ⟨[(.mouseClicked, ⟨some .mouseClicked⟩)]⟩

/-- The repaired constructor registers no default binding at all — there was never a useful
action to run, only the re-entry. -/
def repairedMap : InputMap := ⟨[]⟩

/-- How many actions an UNGUARDED dispatcher runs, given `fuel` to bound the model itself.
`fuel` is an artefact of writing a possibly-nonterminating function in Lean; the real JVM has the
stack in that role, and it runs out. -/
def unguardedRuns (m : InputMap) (e : InputEvent) : Nat → Nat
  | 0 => 0
  | fuel + 1 =>
      match lookup m e with
      | none => 0
      | some a =>
          match a.reenters with
          | none => 1
          | some e' => 1 + unguardedRuns m e' fuel

/-- **The shipped table consumes every unit of fuel it is given.** For any bound, the dispatcher
runs that many actions and is still not finished — which on the JVM is the measured
`StackOverflowError`. Quantified over all fuel, so it is divergence rather than "it was slow in
the one case that was tried". -/
theorem the_shipped_table_never_finishes (fuel : Nat) :
    unguardedRuns shippedMap .mouseClicked fuel = fuel := by
  induction fuel with
  | zero => rfl
  | succ n ih =>
      show 1 + unguardedRuns shippedMap .mouseClicked n = n + 1
      rw [ih]; omega

/-- **The old dispatcher was correct for ordinary bindings.** It ran a non-re-entrant action
exactly once — probe D passed against the shipped class as well as the repaired one. Recording
this matters: the defect was re-entrancy specifically, not dispatch in general, so the repair had
to keep firing rather than start refusing. Without this theorem a mutation that made the old model
run nothing survived the whole suite. -/
theorem the_unguarded_dispatcher_was_correct_for_ordinary_bindings
    (e : InputEvent) (fuel : Nat) (h : 0 < fuel) :
    unguardedRuns ⟨[(e, ⟨none⟩)]⟩ e fuel = 1 := by
  cases fuel with
  | zero => omega
  | succ n => simp [unguardedRuns, lookup]

/-- The dispatch depth the repair allows. A **boolean** in-flight flag was the first design and it
is rejected here: it would refuse every nested dispatch, including a legitimate one where a
handler for one event fires another. That is disarming the class to fix a bug in it. A depth bound
cuts runaway recursion while leaving real chains alone, which
`a_legitimate_chain_is_unaffected` measures. -/
def maxDispatchDepth : Nat := 8

/-- How many actions the GUARDED dispatcher runs, at nesting depth `depth`. -/
def guardedRuns (m : InputMap) (e : InputEvent) (depth : Nat) : Nat → Nat
  | 0 => 0
  | fuel + 1 =>
      if maxDispatchDepth ≤ depth then 0
      else
        match lookup m e with
        | none => 0
        | some a =>
            match a.reenters with
            | none => 1
            | some e' => 1 + guardedRuns m e' (depth + 1) fuel

/-- The bound, stated at an arbitrary starting depth so the induction goes through. -/
theorem guarded_runs_bounded_from_depth (fuel : Nat) :
    ∀ (m : InputMap) (e : InputEvent) (depth : Nat),
      guardedRuns m e depth fuel ≤ maxDispatchDepth - depth := by
  induction fuel with
  | zero => intro m e d; simp [guardedRuns]
  | succ n ih =>
      intro m e d
      rw [guardedRuns]
      by_cases hd : maxDispatchDepth ≤ d
      · simp [hd]
      · simp only [hd, if_false]
        simp only [maxDispatchDepth, Nat.not_le] at hd ⊢
        cases hl : lookup m e with
        | none => simp
        | some a =>
            cases hr : a.reenters with
            | none => simp only [hr]; omega
            | some e' =>
                have h1 := ih m e' (d + 1)
                simp only [maxDispatchDepth] at h1
                simp only [hr]
                omega

/-- **The guard bounds every table, not just the shipped one.** No dispatch runs more than
`maxDispatchDepth` actions, whatever the caller registered — so a future re-entrant binding
cannot reintroduce the `StackOverflowError`. -/
theorem guarded_dispatch_terminates_for_every_table
    (m : InputMap) (e : InputEvent) (fuel : Nat) :
    guardedRuns m e 0 fuel ≤ maxDispatchDepth := by
  have := guarded_runs_bounded_from_depth fuel m e 0
  omega

/-- **The table that used to hang now stops.** Measured probe A, as a theorem: the shipped
self-binding runs the bound and halts, instead of consuming the JVM stack. -/
theorem the_shipped_table_is_bounded_once_guarded :
    guardedRuns shippedMap .mouseClicked 0 50 = maxDispatchDepth := by decide

/-- **Anti-amputation, part 1: an ordinary binding still runs.** A dispatcher that runs nothing
would satisfy every bound above. Quantified over all non-re-entrant actions and all events. -/
theorem a_bound_action_still_fires_exactly_once
    (e : InputEvent) (fuel : Nat) (h : 0 < fuel) :
    guardedRuns ⟨[(e, ⟨none⟩)]⟩ e 0 fuel = 1 := by
  cases fuel with
  | zero => omega
  | succ n => simp [guardedRuns, lookup, maxDispatchDepth]

/-- **Anti-amputation, part 2: a legitimate chain is untouched.** Four handlers firing one
another in turn — the longest chain the four event kinds allow without repeating — runs all four
actions, because the depth bound is `8`. This is the theorem a boolean in-flight flag would have
failed, and the reason the design changed. -/
theorem a_legitimate_chain_is_unaffected :
    guardedRuns ⟨[(.mouseClicked, ⟨some .mouseDragged⟩), (.mouseDragged, ⟨some .mouseReleased⟩),
                  (.mouseReleased, ⟨some .keyPressed⟩), (.keyPressed, ⟨none⟩)]⟩
      .mouseClicked 0 50 = 4 := by decide

/-- …and an event with no binding runs nothing, as `HashMap.get` returning null must. -/
theorem an_unbound_event_runs_nothing (e : InputEvent) (fuel : Nat) :
    guardedRuns repairedMap e 0 fuel = 0 := by
  cases fuel <;> simp [guardedRuns, lookup, repairedMap]

/-- **Deleting only the shipped binding would not have been a fix.** The empty table cannot
diverge, so a repair that stopped there would pass every probe — while a caller-registered
re-entrant binding still hangs, which probe C measured. Both facts, side by side. -/
theorem removing_the_default_binding_is_not_enough (fuel : Nat) :
    unguardedRuns repairedMap .mouseClicked fuel = 0 ∧
    unguardedRuns ⟨[(.mouseDragged, ⟨some .mouseDragged⟩)]⟩ .mouseDragged fuel = fuel := by
  constructor
  · cases fuel <;> simp [unguardedRuns, lookup, repairedMap]
  · induction fuel with
    | zero => rfl
    | succ n ih => simp [unguardedRuns, lookup, ih]; omega

/-! ## The tick clamp

`RangeSliderBehavior.getNewPosition` computes an index into the tick list and clamps it with
`Math.min(ticks.size() - 1, Math.max(0, index))`. A clamp is a proof obligation. -/

/-- The Java clamp, on `Int` because `Math.round` can return a negative index before clamping. -/
def clampIndex (ticks : Nat) (raw : Int) : Int := min (ticks - 1 : Int) (max 0 raw)

/-- **The clamp lands inside the list whenever the list is non-empty** — for every raw index,
including the negative ones a percentage below zero produces. -/
theorem the_clamp_is_always_a_valid_index (ticks : Nat) (raw : Int) (h : 0 < ticks) :
    0 ≤ clampIndex ticks raw ∧ clampIndex ticks raw < (ticks : Int) := by
  have h' : (1 : Int) ≤ (ticks : Int) := by exact_mod_cast h
  constructor <;> simp [clampIndex] <;> omega

/-- **…and it is exactly the empty list that escapes.** With no ticks the clamp returns `0`, and
`ticks.get(0)` throws. Stated rather than silently assumed away: `DiscreteRange` is the only
implementation, `CtbrecPreferencesStorage:153` is the only caller, and neither is proved here to
supply a non-empty list — so the Java carries the check. -/
theorem an_empty_tick_list_escapes_the_clamp (raw : Int) (h : raw ≤ 0) :
    clampIndex 0 raw = -1 := by
  simp [clampIndex]
  omega

/-- The clamp is monotone: a larger position never selects an earlier tick. This is what makes
dragging feel right, and it is the property a "fix" that swapped `min` and `max` would break. -/
theorem the_clamp_is_monotone (ticks : Nat) (a b : Int) (h : a ≤ b) :
    clampIndex ticks a ≤ clampIndex ticks b := by
  simp [clampIndex]
  omega

#guard unguardedRuns shippedMap InputEvent.mouseClicked 50 == 50
#guard guardedRuns shippedMap InputEvent.mouseClicked 0 50 == maxDispatchDepth
#guard guardedRuns repairedMap InputEvent.mouseClicked 0 50 == 0
#guard guardedRuns ⟨[(InputEvent.keyPressed, ⟨none⟩)]⟩ InputEvent.keyPressed 0 50 == 1
#guard guardedRuns ⟨[(InputEvent.keyPressed, ⟨none⟩)]⟩ InputEvent.mouseClicked 0 50 == 0
#guard clampIndex 5 99 == 4
#guard clampIndex 5 (-3) == 0
#guard clampIndex 1 7 == 0
#guard clampIndex 0 0 == -1

end CtbrecSpec
