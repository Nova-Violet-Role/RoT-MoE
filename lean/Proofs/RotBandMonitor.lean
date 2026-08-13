/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # Nova's band flag and Soleil's monitor

Two §2 interceptors that were documentation until 2026-08-13: Nova's *"R/s+ below
minimum → flag for self-correction"*, measured against §5's per-lens ranges, and
Soleil's *"budget < 20% → STEALTH"*, coupled to Chroma's *"12 timelines spawned;
5 shown, 3 under TOKEN_EMERGENCY"*.

## Why the band is per lane, and why that is the load-bearing claim

§5 gives each lens a different optimal range — Soleil 0.5–1.2, Carnage 1.5–3.5.
A single global range would flag one of them permanently through no fault of its
own, which is the same category of error as scoring every lane with one profile.

`same_score_can_flag_differently` is the theorem that makes this real rather than
stylistic: **one score, two lanes, two verdicts.** Measured live at the same time
— `R/s+ 0.69` is `IN` for STEALTH and `BELOW` for EMPATHIC. If per-lane bands
were decorative that theorem would be unprovable.

## Why an unknown budget is not an emergency

`unknown_budget_is_not_an_emergency` is a safety property, not a convenience.
The UserPromptSubmit payload was measured to carry **no token budget**, so the
router accepts a reading and never guesses one. A monitor that fired when it had
no sensor attached would be an alarm reporting on nothing — and because it would
fire *often*, it would train its reader to ignore it.

## What is NOT claimed

That the flag changes routing. It does not, deliberately: §5 says out-of-range is
a correction signal and never a veto, so the flag is recorded and nothing
branches on it. `flag_is_not_a_veto` states exactly that, over every input.
-/

namespace RotMoE.BandMonitor

/-! ## Scores and bands in integer hundredths

Same representation as the shell, for the same reason: modelling in ℚ would prove
a theorem about arithmetic the implementation does not perform. -/

/-- A score in hundredths. `69` is R/s+ = 0.69. -/
abbrev Score := Nat

/-- §5's verdict for one turn. -/
inductive Flag where
  | below | inBand | above
deriving DecidableEq, Repr

/-- A lane's optimal range, transcribed from §5. -/
structure Band where
  lo : Score
  hi : Score
deriving DecidableEq, Repr

/-- The flag. Total by construction — every score lands in exactly one case. -/
def flagOf (b : Band) (s : Score) : Flag :=
  if s < b.lo then Flag.below
  else if b.hi < s then Flag.above
  else Flag.inBand

/-! ### §5's ranges, transcribed -/

def stealth   : Band := ⟨50, 120⟩
def empathic  : Band := ⟨120, 250⟩
def clinical  : Band := ⟨80, 150⟩
def creative  : Band := ⟨150, 350⟩
def forge     : Band := ⟨90, 180⟩
def convergent : Band := ⟨100, 200⟩

/-! ## Totality and exclusivity -/

/-- **Every score gets a verdict.** The column is never blank, for any band. -/
theorem every_score_has_a_flag (b : Band) (s : Score) :
    flagOf b s = Flag.below ∨ flagOf b s = Flag.inBand ∨ flagOf b s = Flag.above := by
  unfold flagOf
  by_cases h1 : s < b.lo
  · simp [h1]
  · by_cases h2 : b.hi < s <;> simp [h1, h2]

/-- The three verdicts are genuinely distinct — a flag that collapsed two of
them would report less than it appears to. -/
theorem the_three_flags_are_distinct :
    Flag.below ≠ Flag.inBand ∧ Flag.inBand ≠ Flag.above ∧ Flag.below ≠ Flag.above := by
  refine ⟨?_, ?_, ?_⟩ <;> decide

/-- `below` means exactly "under the floor", in both directions. -/
theorem below_iff_under_floor (b : Band) (s : Score) :
    flagOf b s = Flag.below ↔ s < b.lo := by
  unfold flagOf
  by_cases h1 : s < b.lo
  · simp [h1]
  · by_cases h2 : b.hi < s <;> simp [h1, h2]

/-- **THE ONE THAT MATTERS: one score, two lanes, two verdicts.** This is why
the band is per lane and not global. Measured live: `0.69` is `IN` for STEALTH
and `BELOW` for EMPATHIC, on the same turn of the same router. -/
theorem same_score_can_flag_differently :
    flagOf stealth 69 = Flag.inBand ∧ flagOf empathic 69 = Flag.below := by
  constructor <;> decide

/-- Stated generally, so it does not expire when a range moves: whenever one
lane's floor sits above another's ceiling is not required — it is enough that a
score falls inside one band and under the other. -/
theorem per_lane_bands_are_not_decorative (a b : Band) (s : Score)
    (hin : a.lo ≤ s ∧ s ≤ a.hi) (hbelow : s < b.lo) :
    flagOf a s ≠ flagOf b s := by
  have h1 : flagOf a s = Flag.inBand := by
    unfold flagOf
    simp [Nat.not_lt.mpr hin.1, Nat.not_lt.mpr hin.2]
  have h2 : flagOf b s = Flag.below := by
    unfold flagOf; simp [hbelow]
  rw [h1, h2]; decide

/-! ## The flag is a signal, not a veto -/

/-- What the router does with a lane, modelled as "nothing". -/
def laneAfterFlag (lane : String) (_f : Flag) : String := lane

/-- **The flag never re-routes.** §5: out-of-range is a correction signal, not a
refusal. A router that silently re-routed on a flag would be doing something the
specification explicitly forbids. -/
theorem flag_is_not_a_veto (lane : String) (f : Flag) :
    laneAfterFlag lane f = lane := rfl

/-! ## Soleil's monitor and Chroma's timelines -/

/-- §2's figures, quoted. -/
def spawned : Nat := 12
def shownNormal : Nat := 5
def shownEmergency : Nat := 3
def floorPct : Nat := 20

/-- A budget reading. `none` is the honest representation of "no sensor". -/
abbrev Reading := Option Nat

/-- Soleil's monitor. Absent reading → not an emergency. -/
def emergency : Reading → Bool
  | none     => false
  | some pct => decide (pct < floorPct)

/-- How many of Chroma's twelve timelines are shown. -/
def shown (r : Reading) : Nat :=
  if emergency r then shownEmergency else shownNormal

/-- **An alarm with no sensor stays quiet.** The payload carries no token
budget, so the router accepts a reading and never guesses one; a monitor that
fired on absence would fire constantly and train its reader to ignore it. -/
theorem unknown_budget_is_not_an_emergency : emergency none = false := rfl

/-- The monitor fires exactly below the floor, in both directions — so it is a
threshold, not a mood. -/
theorem emergency_iff_below_floor (p : Nat) :
    emergency (some p) = true ↔ p < floorPct := by
  unfold emergency floorPct
  exact decide_eq_true_iff

/-- A healthy budget is not an emergency either — the negative control, proved. -/
theorem healthy_budget_is_not_an_emergency (p : Nat) (h : floorPct ≤ p) :
    emergency (some p) = false := by
  unfold emergency
  -- `floorPct` must be unfolded in the HYPOTHESIS as well as the goal: omega
  -- treats an unreduced definition as an opaque unknown and reports a
  -- counterexample that only exists because it cannot see the constant.
  unfold floorPct at h ⊢
  exact decide_eq_false (by omega)

/-- **The emergency actually costs something.** Fewer timelines are shown under
emergency than normally; if these were equal the monitor would be decorative. -/
theorem emergency_shows_fewer (p : Nat) (h : p < floorPct) :
    shown (some p) < shown none := by
  have he : emergency (some p) = true := by
    unfold emergency
    unfold floorPct at h ⊢
    exact decide_eq_true (by omega)
  -- `unknown_budget_is_not_an_emergency` is what reduces the right-hand side:
  -- without it the goal keeps `if emergency none = true then 3 else 5` intact.
  -- The comparison is therefore between the emergency count and the count under
  -- a genuinely absent reading, which is the claim being made.
  simp [shown, he, unknown_budget_is_not_an_emergency, shownEmergency, shownNormal]

/-- Nothing is ever shown that was not spawned — the counts stay coherent. -/
theorem shown_never_exceeds_spawned (r : Reading) : shown r ≤ spawned := by
  unfold shown spawned shownEmergency shownNormal
  by_cases h : emergency r <;> simp [h]

/-! ## Executable checks -/

#guard flagOf stealth 69 == Flag.inBand
#guard flagOf empathic 69 == Flag.below
#guard flagOf clinical 72 == Flag.below
#guard flagOf creative 81 == Flag.below
#guard flagOf forge 66 == Flag.below
#guard flagOf convergent 17 == Flag.below
#guard emergency none == false
#guard emergency (some 8) == true
#guard emergency (some 80) == false
#guard shown (some 8) == 3
#guard shown none == 5

end RotMoE.BandMonitor
