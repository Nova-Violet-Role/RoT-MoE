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
# ENFORCE-SEATS RAISES THE VIEWER COUNT — AND MUST GIVE IT BACK

Socio, 2026-08-10: "test if the Enforce E-S correctly works ... it should rise the Viewer count
temporarily, until the option is disabled".

That is a **hypothesis about observable behaviour**, and this module does not assume it is true. What
it fixes are the properties the mechanism must satisfy IF it is working, so the empirical test has a
criterion sharper than "the number looked bigger".

The mechanism: enforcing seats opens connections that occupy seats in the room, and occupied seats
are counted as viewers. The count therefore rises **by the number of seats held** and must return to
baseline when the option is switched off.

**The property that actually protects us is not "it goes up" — it is "it comes back down, and it
does not drift".** A leak that adds a seat per toggle also makes the count "rise", and would look
like success while permanently inflating the room. Reversibility and idempotence separate the two.
-/

namespace CtbrecSpec.SeatViewerEffect

/-- The room as observed: viewers who are not us, plus the seats we are holding. -/
structure Room where
  /-- Viewers that are not this client's seats. -/
  baseline : Nat
  /-- Seats currently held by enforcement. Zero when the option is off and nothing leaked. -/
  seatsHeld : Nat
deriving DecidableEq, Repr

/-- What the viewer count reads: everyone else, plus every seat we hold. -/
def observedCount (r : Room) : Nat := r.baseline + r.seatsHeld

/-- Turning enforcement ON takes `k` seats. -/
def enable (r : Room) (k : Nat) : Room := { r with seatsHeld := r.seatsHeld + k }

/-- Turning enforcement OFF releases **every** seat held. Not "the last k" — all of them. Releasing
only what the most recent enable took is precisely how a leak survives a disable. -/
def disable (r : Room) : Room := { r with seatsHeld := 0 }

/-! ## The effect the Socio expects -/

/-- **Enabling raises the count**, by exactly the seats taken. -/
theorem enable_raises_by_seats (r : Room) (k : Nat) :
    observedCount (enable r k) = observedCount r + k := by
  simp [observedCount, enable, Nat.add_assoc]

/-- Strictly raises, whenever at least one seat is taken. -/
theorem enable_strictly_raises (r : Room) (k : Nat) (hk : 0 < k) :
    observedCount r < observedCount (enable r k) := by
  rw [enable_raises_by_seats]
  omega

/-! ## The properties that separate "working" from "leaking" -/

/-- **Disabling restores the baseline exactly.** This is the "temporarily" in the report: the rise
must be given back in full. -/
theorem disable_restores_baseline (r : Room) :
    observedCount (disable r) = r.baseline := by
  simp [observedCount, disable]

/-- **A full cycle is the identity on the observed count** — enable then disable leaves no trace,
whatever the room started at and however many seats were taken. -/
theorem cycle_leaves_no_trace (r : Room) (k : Nat) (h : r.seatsHeld = 0) :
    observedCount (disable (enable r k)) = observedCount r := by
  simp [observedCount, disable, enable, h]

/-- **No drift under repeated toggling.** Enabling twice with a disable between is the same as
enabling once — the failure mode where each toggle leaks a seat is excluded. -/
theorem toggling_does_not_accumulate (r : Room) (k : Nat) (h : r.seatsHeld = 0) :
    observedCount (enable (disable (enable r k)) k) = observedCount (enable r k) := by
  simp [observedCount, disable, enable, h]

/-- **The leak, stated so the test can detect it.** A `disable` that released only the last `k`
instead of all seats would leave the count above baseline. This models that broken variant and shows
it is observably different — so the empirical test has something to look for. -/
def disableLeaky (r : Room) (k : Nat) : Room := { r with seatsHeld := r.seatsHeld - k }

theorem leaky_disable_is_detectable :
    ∃ (r : Room) (k : Nat),
      observedCount (disable (enable r k)) ≠ observedCount (disableLeaky (enable r k) k) := by
  refine ⟨{ baseline := 10, seatsHeld := 3 }, 2, ?_⟩
  decide

/-- Only when nothing was held beforehand do the two agree — which is why a leak hides on the first
toggle and only shows on the second. This is the reason the empirical test must toggle TWICE. -/
theorem leak_hides_on_the_first_toggle (r : Room) (k : Nat) (h : r.seatsHeld = 0) :
    observedCount (disable (enable r k)) = observedCount (disableLeaky (enable r k) k) := by
  simp [observedCount, disable, disableLeaky, enable, h]

/-! ## Executable checks — the test protocol, as numbers

A room with 40 other viewers, enforcement taking 2 seats:
  off -> 40 · on -> 42 · off -> 40 · on -> 42   (no drift)
-/

#guard observedCount { baseline := 40, seatsHeld := 0 } == 40
#guard observedCount (enable { baseline := 40, seatsHeld := 0 } 2) == 42
#guard observedCount (disable (enable { baseline := 40, seatsHeld := 0 } 2)) == 40
#guard observedCount (enable (disable (enable { baseline := 40, seatsHeld := 0 } 2)) 2) == 42

-- The leak, as it would appear on a second cycle: 3 seats held, disable releases only 2.
#guard observedCount (disableLeaky { baseline := 40, seatsHeld := 3 } 2) == 41
#guard observedCount (disable { baseline := 40, seatsHeld := 3 }) == 40

end CtbrecSpec.SeatViewerEffect
