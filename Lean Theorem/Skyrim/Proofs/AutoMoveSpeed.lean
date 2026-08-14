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
# Auto Move's speed ladder, and why the workaround is exactly three taps

The Socio's complaint about Auto Move (Nexus mod 99 in the AutoCombat build) was that the
player walks far too slowly once the mod takes over. The cause is in the Papyrus source
shipped with the mod:

* `AutoMove.psc:46`  — `int Property MoveSpeed Auto conditional hidden`, with the comment
  `; 0: walking, 1: fast walking, 2: jogging, 3: running`. An unassigned `int` property is
  **0**, so the mod starts in *walking*.
* `AutoMove.psc:307` — `MoveSpeed = ClampInt(MoveSpeed + 1, 0, 3)`  (increase-speed hotkey)
* `AutoMove.psc:311` — `MoveSpeed = ClampInt(MoveSpeed - 1, 0, 3)`  (decrease-speed hotkey)

Because the speed-increase hotkey defaults to the forward key (`W`), the fix needs no new
code at all: tap `W` three times after Auto Move starts. This file proves that "three" is
the right number and that overshooting is impossible, so the guide handed to the Socio is
not folklore.

## What this does and does not establish

It models the **Papyrus source above**, which is the code that owns `MoveSpeed`. It says
nothing about `AutoMove.dll`, whose behaviour was measured separately (1695 strings, no
config file, no speed symbol). The claim proved here is about the speed ladder, not about
the stuck-detection defect, which genuinely requires recompiling and is still blocked on the
Creation Kit.
-/

namespace Skyrim.AutoMove

/-- Papyrus `ClampInt(v, lo, hi)`, as used at `AutoMove.psc:307` and `:311`. -/
def clampInt (v lo hi : Int) : Int := max lo (min hi v)

/-- The speed-increase hotkey body, `AutoMove.psc:307`. -/
def inc (s : Int) : Int := clampInt (s + 1) 0 3

/-- The speed-decrease hotkey body, `AutoMove.psc:311`. -/
def dec (s : Int) : Int := clampInt (s - 1) 0 3

/-- `MoveSpeed` before the player touches anything: an unassigned Papyrus `int` property. -/
def defaultSpeed : Int := 0

/-- The speed the Socio actually wants: `3` = running, per the comment at `AutoMove.psc:46`. -/
def running : Int := 3

/-- Tapping the increase key `n` times starting from speed `s`. -/
def taps : Nat → Int → Int
  | 0,     s => s
  | n + 1, s => inc (taps n s)

-- Executable agreement with the model, on the concrete values in the guide.
#guard taps 0 defaultSpeed == 0
#guard taps 1 defaultSpeed == 1
#guard taps 2 defaultSpeed == 2
#guard taps 3 defaultSpeed == 3
#guard taps 9 defaultSpeed == 3
#guard dec (inc defaultSpeed) == 0

/-- The root cause, stated as a fact: Auto Move starts in *walking*, not running. -/
theorem default_is_walking : defaultSpeed ≠ running := by decide

/-- The general law of the ladder: from a standing start, `n` taps give `min n 3`.

This is deliberately quantified over `n` rather than asserted at the single value `3`. A
theorem pinned to `3` would be a snapshot of today's advice; this one still says something
true if the mod's cap or the recommended tap count ever changes. -/
theorem taps_from_default (n : Nat) : taps n defaultSpeed = min (n : Int) 3 := by
  induction n with
  | zero => decide
  | succ k ih =>
    simp only [taps, inc, clampInt, ih]
    omega

/-- Three taps reach running. This is the instruction in the guide. -/
theorem three_taps_reach_running : taps 3 defaultSpeed = running := by
  rw [taps_from_default]; decide

/-- Three taps is *minimal* — fewer never reaches running, so the number is not arbitrary. -/
theorem fewer_taps_never_run (k : Nat) (hk : k < 3) : taps k defaultSpeed ≠ running := by
  rw [taps_from_default]
  have : (k : Int) < 3 := by exact_mod_cast hk
  simp only [running]
  omega

/-- Overshooting is harmless: once running, further taps change nothing. So "tap three
times, and a fourth if you lost count" is safe advice rather than a way to break the mod. -/
theorem running_is_absorbing (n : Nat) : taps n running = running := by
  induction n with
  | zero => rfl
  | succ k ih => simp only [taps, inc, clampInt, ih]; decide

/-- The ladder never leaves the legal band, whatever the player does. -/
theorem taps_stay_in_band (n : Nat) (s : Int) (h0 : 0 ≤ s) (h3 : s ≤ 3) :
    0 ≤ taps n s ∧ taps n s ≤ 3 := by
  induction n with
  | zero => exact ⟨h0, h3⟩
  | succ k ih => simp only [taps, inc, clampInt]; omega

/-- The decrease hotkey undoes one tap in the interior of the band, which is what makes the
advice reversible if the Socio overshoots into a speed they dislike. -/
theorem dec_undoes_inc (s : Int) (h0 : 0 ≤ s) (h3 : s < 3) : dec (inc s) = s := by
  simp only [dec, inc, clampInt]; omega

#print axioms three_taps_reach_running
#print axioms fewer_taps_never_run
#print axioms running_is_absorbing
#print axioms taps_stay_in_band

end Skyrim.AutoMove
