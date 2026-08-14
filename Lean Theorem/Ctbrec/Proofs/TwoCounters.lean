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
# WHY TWO COUNTERS ARE NECESSARY, NOT MERELY NICE

Socio, 2026-08-10: "we need 2 counters, 1 with the real spectator numbers and 1 with the CTBRecEVO
number, its the only way to see if the E-S activation reflects to both of them."

"The only way" is a strong claim. This module proves it is literally true rather than a preference:
**the combined figure is not injective**, so no observer of the sum alone can attribute a rise to
our seats rather than to real viewers arriving.

Source of the second number: `SeatAllocator.inUse()` (`SeatAllocator.java:111`) returns
`held.size()` — the seats this client holds. The first is the site's own figure, harvested in
`ViewerHarvest.lean`.
-/

namespace CtbrecSpec.TwoCounters

/-- The two independent quantities. `spectators` is the site's report of everyone else;
`evoSeats` is `SeatAllocator.inUse()`. -/
structure Observation where
  spectators : Nat
  evoSeats : Nat
deriving DecidableEq, Repr

/-- The single number a one-counter UI shows. -/
def combined (o : Observation) : Nat := o.spectators + o.evoSeats

/-- The pair a two-counter UI shows. -/
def bothCounters (o : Observation) : Nat × Nat := (o.spectators, o.evoSeats)

/-! ## The combined figure destroys the information the test needs -/

/-- **The sum is NOT injective.** 40 real viewers with 0 seats and 5 real viewers with 35 seats are
the same number on screen. A one-counter UI cannot tell them apart — this is the theorem behind
"it's the only way". -/
theorem combined_is_not_injective :
    ∃ a b : Observation, a ≠ b ∧ combined a = combined b := by
  refine ⟨{ spectators := 40, evoSeats := 0 }, { spectators := 5, evoSeats := 35 }, ?_, ?_⟩
  · decide
  · decide

/-- **A rise in the combined figure does not imply our seats caused it.** The count went up by 35 and
not one seat was taken — real viewers arrived. Any test that reads only the sum can be fooled. -/
theorem a_rise_does_not_prove_seats :
    ∃ before after : Observation,
      combined before < combined after ∧ after.evoSeats = before.evoSeats := by
  refine ⟨{ spectators := 40, evoSeats := 0 }, { spectators := 75, evoSeats := 0 }, ?_, ?_⟩
  · decide
  · rfl

/-- And the converse trap: our seats CAN rise while the combined figure stays flat, because real
viewers left at the same time. Absence of a rise does not prove E-S is broken. -/
theorem a_flat_total_does_not_prove_no_seats :
    ∃ before after : Observation,
      combined before = combined after ∧ before.evoSeats < after.evoSeats := by
  refine ⟨{ spectators := 40, evoSeats := 0 }, { spectators := 5, evoSeats := 35 }, ?_, ?_⟩
  · decide
  · decide

/-! ## Two counters settle it -/

/-- **The pair IS injective** — it determines the observation completely. Nothing is lost. -/
theorem both_counters_is_injective (a b : Observation) (h : bothCounters a = bothCounters b) :
    a = b := by
  obtain ⟨sa, ea⟩ := a
  obtain ⟨sb, eb⟩ := b
  simp [bothCounters] at h
  simp [h.1, h.2]

/-- With both counters, a seat change is read directly off the second one — no inference from the
total, and no confound from viewers arriving or leaving. -/
theorem seat_delta_is_directly_observable (a b : Observation) :
    (bothCounters a).2 = a.evoSeats ∧ (bothCounters b).2 = b.evoSeats := by
  exact ⟨rfl, rfl⟩

/-- The combined figure is recoverable from the pair, so showing both LOSES nothing that the single
counter provided. Strictly more information, never less. -/
theorem pair_recovers_the_total (o : Observation) :
    (bothCounters o).1 + (bothCounters o).2 = combined o := by
  rfl

/-- The k=35 test, stated over the pair: with 35 seats taken the second counter reads exactly 35
whatever the audience does. This is what makes the Socio's test conclusive. -/
theorem evo_counter_reads_the_seats (s k : Nat) :
    (bothCounters { spectators := s, evoSeats := k }).2 = k := by
  rfl

/-! ## Executable checks -/

-- The confound, as numbers: identical on a one-counter UI, distinct on a two-counter one.
#guard combined { spectators := 40, evoSeats := 0 } == 40
#guard combined { spectators := 5, evoSeats := 35 } == 40
#guard bothCounters { spectators := 40, evoSeats := 0 } != bothCounters { spectators := 5, evoSeats := 35 }

-- The k=35 test read off the second counter, regardless of audience.
#guard (bothCounters { spectators := 40, evoSeats := 35 }).2 == 35
#guard (bothCounters { spectators := 999, evoSeats := 35 }).2 == 35
#guard (bothCounters { spectators := 40, evoSeats := 0 }).2 == 0

end CtbrecSpec.TwoCounters
