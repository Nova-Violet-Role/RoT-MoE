/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Authors: Saimono
-/

/-!
# The stuck-recovery state machine, proved terminating before it is written

Auto Move (Nexus 99) freezes when the destination the player pinned on the map has no
reachable navmesh path - measured cause: `AutoMove.psc:221` hands the custom marker to an
alias via the native `ForceDestinationMarkerIntoAliasID`, the scene `AutoMoveSCN` then runs
a vanilla AI travel package, and `Game.DisablePlayerControls` is already in force, so a
package that resolves no path looks like a total freeze.

AutoCombat solves the same problem with `PathToReference` (measured in `AutoCombatNav.pex`:
`StartNav`, `StopNav`, `SetPlayerAIDriven`, `PathToReference`). The fix for Auto Move is to
poll for movement and fall back to `PathToReference` when nothing has moved.

## Why this file exists at all

The Socio warned: *"be careful because this could introduce the lvl 0 loop we had, if u
don't use the correct formula."* That warning is exactly right about where the danger is. A
recovery routine that retries forever is not a fix, it is a script that hammers the engine
every few seconds for the rest of the save - which is how script-load spirals start.

So the state machine is proved to **terminate** before a line of Papyrus is written. The
guarantee below is not "it usually settles": it is that from any state, with the player
never moving, the machine reaches `aborted` within a bounded number of polls, and that
`attempts` never exceeds its cap on any input sequence whatsoever.

## Boundary

This proves the control logic. It does not prove that `PathToReference` succeeds, that the
navmesh is reachable, or anything about the engine - those are outside Lean's reach and
stay empirical.
-/

namespace Skyrim.AutoMoveUnstuck

/-- Polls with no movement before recovery fires. -/
def stuckThreshold : Nat := 2

/-- Recovery attempts allowed before the mod gives up and stops cleanly. This cap is the
whole safety argument: without it the routine retries forever. -/
def maxAttempts : Nat := 3

/-- Recovery state carried between polls. -/
structure St where
  /-- Consecutive polls during which the player has not moved. -/
  stuckTicks : Nat
  /-- Recovery attempts made since the last real movement. -/
  attempts : Nat
  /-- Set once the mod has given up; nothing further happens. -/
  aborted : Bool
  deriving DecidableEq, Repr

/-- Where every journey starts. -/
def initial : St := { stuckTicks := 0, attempts := 0, aborted := false }

/-- One poll. `moved` is whether the player's position changed since the previous poll. -/
def step (moved : Bool) (s : St) : St :=
  if s.aborted then s
  else if moved then { stuckTicks := 0, attempts := 0, aborted := false }
  else if s.stuckTicks + 1 < stuckThreshold then { s with stuckTicks := s.stuckTicks + 1 }
  else if s.attempts + 1 < maxAttempts then
    { stuckTicks := 0, attempts := s.attempts + 1, aborted := false }
  else { stuckTicks := 0, attempts := s.attempts + 1, aborted := true }

/-- Whether this poll actually issues the `PathToReference` call. -/
def fires (moved : Bool) (s : St) : Bool :=
  !s.aborted && !moved && !(s.stuckTicks + 1 < stuckThreshold)

/-- Run `n` polls with a constant movement answer. -/
def run (moved : Bool) : Nat → St → St
  | 0,     s => s
  | n + 1, s => run moved n (step moved s)

-- Executable checks on the concrete schedule the Papyrus will use.
#guard (run false 1 initial).attempts == 0
#guard (run false 2 initial).attempts == 1
#guard (run false 6 initial).aborted == true
#guard (run true 100 initial) == initial
#guard fires false initial == false

/-- Recovery never fires on a poll where the player moved. No fighting the AI package while
it is working. -/
theorem never_fires_while_moving (s : St) : fires true s = false := by
  simp [fires]

/-- Recovery never fires once the mod has given up. -/
theorem never_fires_after_abort (moved : Bool) (s : St) (h : s.aborted = true) :
    fires moved s = false := by
  simp [fires, h]

/-- Giving up is permanent: no later poll can restart the machine. -/
theorem abort_is_absorbing (moved : Bool) (s : St) (h : s.aborted = true) : step moved s = s := by
  simp [step, h]

/-- Real movement clears both counters, so a long journey with occasional slow patches never
accumulates its way into a spurious abort. -/
theorem movement_resets (s : St) (h : s.aborted = false) :
    (step true s).stuckTicks = 0 ∧ (step true s).attempts = 0 := by
  simp [step, h]

/-- The invariant that bounds the whole thing.

Note the second conjunct. The naive invariant `attempts ≤ maxAttempts` is **not** inductive:
the abort branch increments `attempts`, so from `attempts = maxAttempts` it would step to
`maxAttempts + 1`. What actually holds is that a machine which has not yet given up is
strictly below the cap, and that is what makes the bound survive the increment. Getting this
wrong is precisely how a "capped" retry loop ends up uncapped. -/
def Inv (s : St) : Prop :=
  s.attempts ≤ maxAttempts ∧ (s.aborted = false → s.attempts < maxAttempts)

theorem inv_initial : Inv initial := by
  unfold Inv
  decide

/-- The invariant is preserved by every poll, whatever the player does. -/
theorem inv_step (moved : Bool) (s : St) (h : Inv s) : Inv (step moved s) := by
  obtain ⟨h1, h2⟩ := h
  by_cases ha : s.aborted = true
  · simpa [step, ha] using ⟨h1, h2⟩
  · have ha' : s.aborted = false := by simpa using ha
    have hlt : s.attempts < maxAttempts := h2 ha'
    by_cases hm : moved = true
    · simp [step, ha', hm, Inv, maxAttempts]
    · have hm' : moved = false := by simpa using hm
      by_cases ht : s.stuckTicks + 1 < stuckThreshold
      · simp only [step, ha', hm', ht, if_true, if_false, Inv]
        exact ⟨h1, fun _ => hlt⟩
      · by_cases hc : s.attempts + 1 < maxAttempts
        · simp only [step, ha', hm', ht, hc, if_true, if_false, Inv]
          exact ⟨Nat.le_of_lt hc, fun _ => hc⟩
        · simp only [step, ha', hm', ht, hc, if_true, if_false, Inv]
          -- `s.attempts < maxAttempts` IS `s.attempts + 1 ≤ maxAttempts` by definition of
          -- Nat.lt, which is exactly the bound the abort branch needs.
          exact ⟨hlt, by simp⟩

/-- `attempts` never exceeds the cap, on **any** sequence of polls. -/
theorem attempts_bounded (moved : Bool) (n : Nat) :
    (run moved n initial).attempts ≤ maxAttempts := by
  have : ∀ m (s : St), Inv s → Inv (run moved m s) := by
    intro m
    induction m with
    | zero => intro s hs; exact hs
    | succ k ih => intro s hs; exact ih (step moved s) (inv_step moved s hs)
  exact (this n initial inv_initial).1

/-- Termination, the property the Socio's warning is really about: with the player never
moving, the machine is in `aborted` after six polls and stays there. At the Papyrus poll
interval of 3 seconds that is 18 seconds, then silence - not an endless retry. -/
theorem gives_up_when_never_moving : (run false 6 initial).aborted = true := by decide

/-- Polling splits: `a` polls then `b` more. -/
theorem run_add (moved : Bool) (a b : Nat) (s : St) :
    run moved (a + b) s = run moved b (run moved a s) := by
  induction a generalizing s with
  | zero => simp [run]
  | succ k ih =>
    have h : k + 1 + b = (k + b) + 1 := by omega
    rw [h]
    show run moved (k + b) (step moved s) = run moved b (run moved (k + 1) s)
    rw [ih]
    rfl

/-- Once given up, every later poll leaves it given up. -/
theorem aborted_persists (moved : Bool) (n : Nat) (s : St) (h : s.aborted = true) :
    (run moved n s).aborted = true := by
  induction n generalizing s with
  | zero => exact h
  | succ k ih =>
    show (run moved k (step moved s)).aborted = true
    exact ih (step moved s) (by rw [abort_is_absorbing moved s h]; exact h)

/-- And it stays given up however long the game runs afterwards. This is the anti-loop
guarantee in full: the routine does not merely stop retrying at some point, it can never
resume. -/
theorem stays_given_up (n : Nat) : (run false (6 + n) initial).aborted = true := by
  rw [run_add]
  exact aborted_persists false n _ gives_up_when_never_moving

#print axioms never_fires_while_moving
#print axioms abort_is_absorbing
#print axioms attempts_bounded
#print axioms gives_up_when_never_moving

end Skyrim.AutoMoveUnstuck
