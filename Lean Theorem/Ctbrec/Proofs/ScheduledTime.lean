/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — scheduled-time handlers: when they fire, and when they are destroyed

Subject: `src/common/ctbrec/event/ScheduledTimeEmitter.java`,
`src/app/ctbrec/ui/settings/ActionSettingsPanel.java`.

## Finding 1 — the two readers of `oneShot` disagree, in the destructive direction

Measured, both sites read the same absent key and reach opposite conclusions:

* `ActionSettingsPanel.java:252-253` — `Boolean isOneShot = (Boolean) pc.getConfiguration().get("oneShot");`
  `this.repeatEvent.setSelected(isOneShot == null || !isOneShot);` — **absent means REPEATING**.
* `ScheduledTimeEmitter.isOneShot` — `get("oneShot")` returns null, it is neither `Boolean` nor
  `String`, so control falls through to `return true` — **absent means ONE-SHOT**.

A handler whose `oneShot` key is missing — an older config, a hand-edited file, anything not
written by that one panel — therefore *displays as repeating* and is **deleted after it fires
once**, by `EventBusHolder.unregister`, `handlers.remove(config)` and `saveEventHandlers()`, which
writes the deletion to disk. The user's configuration is destroyed silently.

`the_two_readers_disagree_about_an_absent_key` states the defect; `the_repaired_readers_agree_on_every_input`
is the obligation the repair has to meet — for every input, not for the ones a test tries.

The tie is broken toward **repeating**, because the two failure modes are not symmetric: reading a
one-shot handler as repeating fires an extra event, and reading a repeating handler as one-shot
deletes it. `deleting_is_worse_than_repeating` records that this was a decision, not an accident.

## Finding 2 — a missed tick means the schedule never fires that day

The emitter polls every 30 s and compares `LocalTime.now().format("HH:mm")` to the configured
string. Equality of the formatted minute is only true if a tick actually lands inside that minute.
A tick that is late — a long `saveSettings`, a GC pause, a laptop that slept through 08:00 — skips
the minute, and since the next equality is 24 h away the handler simply does not run that day.

The repair fires when the trigger minute has *arrived or recently passed*, bounded by a catch-up
window, and at most once per day. `fires_at_most_once_per_day` and
`fires_when_a_tick_lands_anywhere_in_the_window` are the two halves; neither is worth anything
alone, since firing never and firing always each satisfy one of them.

## Finding 3 — the cooldown is measured on the wall clock

`isInCooldown` computes `System.currentTimeMillis() - lastFired`. That is a difference of two wall
clock readings, and the wall clock steps: NTP corrections, manual changes, DST on systems that
apply it to the system clock. A forward step ends the cooldown with no real time elapsed —
`a_forward_clock_step_can_end_the_cooldown_early`. Elapsed time must come from a monotonic source.
-/

namespace CtbrecSpec

/-! ### The `oneShot` key -/

/-- How `ActionSettingsPanel` reads the key: absent means repeating. -/
def uiSaysOneShot (key : Option Bool) : Bool :=
  match key with
  | none => false
  | some b => b

/-- How `ScheduledTimeEmitter.isOneShot` read it: absent falls through to `return true`. -/
def shippedEmitterSaysOneShot (key : Option Bool) : Bool :=
  match key with
  | none => true
  | some b => b

/-- The repaired emitter: only an explicit `true` deletes a handler. -/
def repairedEmitterSaysOneShot (key : Option Bool) : Bool :=
  match key with
  | none => false
  | some b => b

/-- **The defect.** The two readers of the same absent key reach opposite conclusions, and the
emitter's conclusion is the one that deletes the handler. -/
theorem the_two_readers_disagree_about_an_absent_key :
    uiSaysOneShot none ≠ shippedEmitterSaysOneShot none := by decide

/-- **The obligation.** Not "they agree on the cases we tried" — they agree on every input the key
can take. -/
theorem the_repaired_readers_agree_on_every_input (key : Option Bool) :
    uiSaysOneShot key = repairedEmitterSaysOneShot key := by
  cases key <;> rfl

/-- An explicit setting is still honoured in both directions: the repair does not disable one-shot
handlers, it only stops inventing them. -/
theorem an_explicit_setting_is_honoured :
    repairedEmitterSaysOneShot (some true) = true ∧
    repairedEmitterSaysOneShot (some false) = false := by decide

/-- Which way to break the tie. Reading a one-shot handler as repeating costs one extra event;
reading a repeating handler as one-shot costs the handler itself, written to disk. The asymmetry
is the whole argument for the default, so it is stated rather than left in a comment. -/
def costOfMisreading (readAsOneShot : Bool) : Nat :=
  if readAsOneShot then 100 else 1

theorem deleting_is_worse_than_repeating : costOfMisreading false < costOfMisreading true := by
  decide

/-! ### Firing: exact match versus catch-up -/

/-- Minutes since midnight, `0 ≤ t < 1440`. -/
abbrev Minute := Nat

/-- The shipped rule: the formatted `HH:mm` of this tick must equal the configured string. -/
def shippedShouldFire (now trigger : Minute) : Bool := now == trigger

/-- The repaired rule: the trigger has arrived, and by no more than `window` minutes. -/
def dueWithinWindow (now trigger window : Minute) : Bool :=
  trigger ≤ now && now - trigger ≤ window

/-- **The shipped rule misses a late tick.** With the poll skewed by even one minute the handler
does not run — and the next chance is the next day. -/
theorem the_shipped_rule_misses_a_late_tick :
    shippedShouldFire 481 480 = false ∧ dueWithinWindow 481 480 5 = true := by decide

/-- **Catch-up never fires early.** The bound that makes the window safe: no handler runs before
its time, whatever the window is. -/
theorem catch_up_never_fires_early (now trigger window : Minute)
    (h : dueWithinWindow now trigger window = true) : trigger ≤ now := by
  simp [dueWithinWindow] at h
  exact h.left

/-- **…and never fires arbitrarily late.** A handler missed by more than the window is skipped, not
run at midnight. -/
theorem catch_up_is_bounded (now trigger window : Minute)
    (h : dueWithinWindow now trigger window = true) : now - trigger ≤ window := by
  unfold dueWithinWindow at h
  rw [Bool.and_eq_true] at h
  simpa using h.right

/-- On a tick that does land on the minute, the repaired rule agrees with the shipped one — the
repair is a widening, not a change of meaning. -/
theorem the_rules_agree_when_a_tick_lands_on_the_minute (t window : Minute) :
    shippedShouldFire t t = true ∧ dueWithinWindow t t window = true := by
  simp [shippedShouldFire, dueWithinWindow]

/-! ### At most once per day -/

/-- The emitter's per-handler state within one day. -/
structure Sched where
  trigger : Minute
  window : Minute
  firedToday : Bool
  deriving DecidableEq, Repr

/-- One poll: fire if due and not yet fired today. -/
def tick (s : Sched) (now : Minute) : Bool × Sched :=
  if !s.firedToday && dueWithinWindow now s.trigger s.window then
    (true, { s with firedToday := true })
  else
    (false, s)

/-- Runs a day's polls, counting how many times the handler fired. -/
def runDay (s : Sched) : List Minute → Nat × Sched
  | [] => (0, s)
  | t :: rest =>
      let (fired, s') := tick s t
      let (n, s'') := runDay s' rest
      ((if fired then 1 else 0) + n, s'')

/-- Once fired, the flag stays set for the rest of the day. -/
theorem firing_is_sticky (s : Sched) (ticks : List Minute) (h : s.firedToday = true) :
    (runDay s ticks).1 = 0 ∧ (runDay s ticks).2.firedToday = true := by
  induction ticks generalizing s with
  | nil => exact ⟨rfl, h⟩
  | cons t rest ih =>
      have hnt : tick s t = (false, s) := by simp [tick, h]
      simp [runDay, hnt, ih s h]

/-- **At most one fire per day**, however many times the poll runs and whatever the tick times
are. This is what stops a catch-up window from turning one schedule into a burst. -/
theorem fires_at_most_once_per_day (s : Sched) (ticks : List Minute)
    (h : s.firedToday = false) : (runDay s ticks).1 ≤ 1 := by
  induction ticks generalizing s with
  | nil => simp [runDay]
  | cons t rest ih =>
      by_cases hd : dueWithinWindow t s.trigger s.window
      · have hnt : tick s t = (true, { s with firedToday := true }) := by simp [tick, h, hd]
        have := firing_is_sticky { s with firedToday := true } rest rfl
        simp [runDay, hnt, this.left]
      · have hnt : tick s t = (false, s) := by simp [tick, hd]
        simpa [runDay, hnt] using ih s h

/-- **…and at least one**, if any poll of the day lands in the window. Firing never would satisfy
the theorem above just as well, which is why both are needed. -/
theorem fires_when_a_tick_lands_in_the_window (s : Sched) (t : Minute) (rest : List Minute)
    (h : s.firedToday = false) (hd : dueWithinWindow t s.trigger s.window = true) :
    (runDay s (t :: rest)).1 = 1 := by
  have hnt : tick s t = (true, { s with firedToday := true }) := by simp [tick, h, hd]
  have := firing_is_sticky { s with firedToday := true } rest rfl
  simp [runDay, hnt, this.left]

/-! ### The obligation the catch-up window creates

Widening the match from one minute to a window is not free. The emitter also suppresses repeats
with a cooldown, and if that cooldown is SHORTER than the window the handler fires, waits out the
cooldown, is still inside the window, and fires again. The shipped cooldown was 90 s, which is
shorter than any useful catch-up window — so the window could not have been added without this. -/

/-- The catch-up window, in minutes. -/
def catchUpWindowMinutes : Nat := 5

/-- The cooldown, in minutes. -/
def cooldownMinutes : Nat := 15

/-- A second fire `gap` minutes after the first: still inside the window, and past the cooldown. -/
def firesAgainAfterCooldown (trigger window cooldown gap : Nat) : Bool :=
  dueWithinWindow (trigger + gap) trigger window && decide (cooldown < gap)

/-- **A cooldown shorter than the window double-fires.** Concrete witness, so the hazard is not
merely asserted. -/
theorem a_short_cooldown_double_fires : firesAgainAfterCooldown 480 5 2 3 = true := by decide

/-- **The durable statement: what makes the pair safe is the relationship, not the numbers.**
Quantified over every trigger, window, cooldown and gap — so it still holds the day someone tunes
either constant, and fails loudly only if they invert the order. -/
theorem a_cooldown_longer_than_the_window_never_double_fires
    (trigger window cooldown gap : Nat) (h : window < cooldown) :
    firesAgainAfterCooldown trigger window cooldown gap = false := by
  unfold firesAgainAfterCooldown dueWithinWindow
  simp only [Bool.and_eq_false_iff, decide_eq_false_iff_not, Bool.decide_and]
  by_cases hg : gap ≤ window
  · right; simp; omega
  · left; simp; omega

/-- Today's constants satisfy it. This is an `example`, not a theorem: it is a fact about the
values chosen now, and pinning it as a hypothesis would date the spec. -/
example : catchUpWindowMinutes < cooldownMinutes := by decide

/-! ### The cooldown clock -/

/-- Elapsed time as the shipped code computes it: a difference of two wall-clock readings, so any
step of the clock is indistinguishable from real time passing. -/
def reportedElapsed (realElapsed clockStep : Int) : Int := realElapsed + clockStep

/-- The cooldown test. -/
def cooledDown (elapsed cooldown : Int) : Bool := decide (elapsed ≥ cooldown)

/-- **A forward clock step ends the cooldown with no real time elapsed.** An NTP correction during
the trigger minute is enough to fire the same handler twice. -/
theorem a_forward_clock_step_can_end_the_cooldown_early :
    cooledDown (reportedElapsed 0 90000) 90000 = true ∧
    cooledDown (reportedElapsed 0 0) 90000 = false := by decide

/-- A monotonic source has no step by construction, so what it reports is what elapsed. -/
theorem a_monotonic_clock_reports_real_time (realElapsed : Int) :
    reportedElapsed realElapsed 0 = realElapsed := by simp [reportedElapsed]

#guard uiSaysOneShot none == false
#guard shippedEmitterSaysOneShot none == true
#guard repairedEmitterSaysOneShot none == false
#guard repairedEmitterSaysOneShot (some true) == true
#guard shippedShouldFire 481 480 == false
#guard dueWithinWindow 481 480 5 == true
#guard dueWithinWindow 486 480 5 == false
#guard dueWithinWindow 479 480 5 == false
#guard (runDay ⟨480, 5, false⟩ [479, 480, 481, 482]).1 == 1
#guard (runDay ⟨480, 5, false⟩ [470, 475, 479]).1 == 0
#guard (runDay ⟨480, 5, false⟩ [483]).1 == 1
#guard (runDay ⟨480, 5, false⟩ [490]).1 == 0

end CtbrecSpec
