/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # One band for ten lanes is not a bound, it is a coincidence

**Measured 2026-08-14.** The gauge computed R/s+ correctly and then read it
against a single hardcoded range, `0.9 - 1.8`, on every turn. Those are the
FORGE numbers. Section 5 of the specification gives each lens its OWN optimal
range, and section 4 repeats them independently as a per-profile `R/s+ target`;
both tables were extracted and compared before this file was written and they
agree on all ten lanes.

What the defect cost is not a wrong number -- the number was always right. It is
a wrong MEANING:

| lane | own band | R/s+ 1.4 read correctly | read against FORGE |
|---|---|---|---|
| CREATIVE | 1.5 - 3.5 | BELOW -> add entropy | IN RANGE -> do nothing |
| STEALTH | 0.5 - 1.2 | ABOVE -> compress more | IN RANGE -> do nothing |
| FORGE | 0.9 - 1.8 | IN RANGE | IN RANGE |

The self-correction signal is the entire purpose of the gauge, so a verdict that
says IN RANGE when the lead lens says otherwise does not merely mislabel: it
silences the one instruction the score exists to produce.

This is the same defect that was fixed on 2026-08-13 in the weight tables, where
nine of the ten profiles were documentation and every lane was scored with the
FORGE lambdas. Route correctly, then judge as if you had not.

The theorems below are arranged so that the LAST one is the one that matters.
That a lookup is total, or that its values match a table, is arithmetic. That a
single global band CANNOT reproduce the per-lane law is the claim that makes the
change load-bearing rather than cosmetic -- and it is proved by exhibiting a
score two lanes classify differently, which no single range can do.

Bounds are in HUNDREDTHS, as `Nat`, exactly as the shell carries them
(`BAND_LO_*` / `BAND_HI_*` in `hooks/rot-router.sh`, `$Bands` in the ps1 arm).
Integer arithmetic is deliberate: it is the same comparison the router performs,
so these theorems are about the shipped computation and not about a real-valued
idealisation of it.
-/

namespace RotBandPerLane

/-- The ten lanes. `Lane` is closed, which is what makes `decide` able to settle
every claim below by exhaustion rather than by argument. -/
inductive Lane
  | convergent | strategic | empathic | clinical | executive
  | creative | predictive | stealth | recursive | forge
  deriving DecidableEq, Repr

/-- Every lane, for exhaustive checks. Kept next to `Lane` so that adding a lane
and forgetting to list it here is caught by `all_lanes_listed` below rather than
by silence. -/
def allLanes : List Lane :=
  [.convergent, .strategic, .empathic, .clinical, .executive,
   .creative, .predictive, .stealth, .recursive, .forge]

/-- Band bounds in hundredths: `(lo, hi)`. Transcribed from the specification,
which states them twice -- section 5 per lens, section 4 per profile. -/
def band : Lane → Nat × Nat
  | .convergent => (100, 200)
  | .strategic  => (100, 200)
  | .empathic   => (120, 250)
  | .clinical   => ( 80, 150)
  | .executive  => ( 70, 180)
  | .creative   => (150, 350)
  | .predictive => (100, 220)
  | .stealth    => ( 50, 120)
  | .recursive  => ( 80, 150)
  | .forge      => ( 90, 180)

/-- The three verdicts. `below` and `above` are correction signals, never
refusals -- section 5 is explicit that out-of-range steers, it does not veto. -/
inductive Verdict | below | inRange | above
  deriving DecidableEq, Repr

/-- The router's own comparison: `R < lo` is BELOW, `R > hi` is ABOVE, and
everything else is IN RANGE. Both endpoints are therefore INSIDE the band. -/
def classify (l : Lane) (r : Nat) : Verdict :=
  if r < (band l).1 then .below else if r > (band l).2 then .above else .inRange

/-- The band the gauge used to apply to every lane. -/
def forgeBand : Nat × Nat := (90, 180)

/-- The old behaviour, kept executable so the two can be compared rather than
described. -/
def classifyGlobal (r : Nat) : Verdict :=
  if r < forgeBand.1 then .below else if r > forgeBand.2 then .above else .inRange

/-! ## The lookup is total and the table is the spec -/

/-- `allLanes` really does list every constructor. Without this, an eleventh
lane could be added and every exhaustive theorem below would keep passing while
quietly saying nothing about it. -/
theorem all_lanes_listed (l : Lane) : l ∈ allLanes := by
  cases l <;> decide

/-- No lane has an empty or inverted band. A band with `lo > hi` classifies
every score as BELOW *and* ABOVE depending only on the order of the tests -- it
is a bound that can never be satisfied. -/
theorem every_band_is_nonempty : ∀ l ∈ allLanes, (band l).1 < (band l).2 := by
  decide

/-- The bounds are exactly the specification's. This pins the transcription: if
someone edits a constant in the shell without editing it here, `checker` compares
the two and this theorem is what the comparison is against. -/
theorem bands_match_spec :
    band .convergent = (100, 200) ∧ band .strategic  = (100, 200) ∧
    band .empathic   = (120, 250) ∧ band .clinical   = ( 80, 150) ∧
    band .executive  = ( 70, 180) ∧ band .creative   = (150, 350) ∧
    band .predictive = (100, 220) ∧ band .stealth    = ( 50, 120) ∧
    band .recursive  = ( 80, 150) ∧ band .forge      = ( 90, 180) := by
  decide

/-- CONVERGENT and STRATEGIC share a band because section 5 lists Nova once, for
"Convergent/Strategic". Stated so the coincidence is deliberate and cannot be
mistaken for a copy-paste slip. -/
theorem nova_leads_two_lanes_with_one_band :
    band .convergent = band .strategic := by decide

/-! ## The verdict is a flag, not a veto -/

/-- `classify` is total: every lane and every score produce a verdict. There is
no score the gauge cannot report on, so the band can never be a reason to refuse
a turn. -/
theorem classify_is_total (l : Lane) (r : Nat) :
    classify l r = .below ∨ classify l r = .inRange ∨ classify l r = .above := by
  unfold classify
  split
  · exact Or.inl rfl
  · split
    · exact Or.inr (Or.inr rfl)
    · exact Or.inr (Or.inl rfl)

/-- Both endpoints are inside their own band -- the comparison is strict on both
sides, so a score sitting exactly on `lo` or `hi` is IN RANGE and not flagged. -/
theorem endpoints_are_in_range :
    ∀ l ∈ allLanes, classify l (band l).1 = .inRange ∧ classify l (band l).2 = .inRange := by
  decide

/-! ## The claim that makes this change load-bearing

Everything above is arithmetic over a table. What follows is the reason the
table has to be consulted at all.
-/

/-- **A single global band cannot reproduce the per-lane law.** There is a score
that two lanes classify differently, so no one range -- FORGE's or any other --
agrees with `classify` everywhere.

`140` is the witness, and it is the case measured in the shell: R/s+ 1.40 is
BELOW for CREATIVE (whose band starts at 1.50) and IN RANGE for FORGE. -/
theorem no_single_band_suffices :
    ∃ r : Nat, classify .creative r ≠ classify .forge r := by
  refine ⟨140, ?_⟩; decide

/-- The old code was not merely different, it was WRONG for a specific lane on a
specific score: at 140 it announced IN RANGE while CREATIVE's own band demanded
BELOW, which is the signal `add entropy`. -/
theorem global_band_silenced_creative :
    classifyGlobal 140 = .inRange ∧ classify .creative 140 = .below := by
  decide

/-- And it failed in the other direction too. At 130 the global band said IN
RANGE while STEALTH's band ends at 120, so the instruction `compress more` was
lost. Both directions matter: a bug that only ever under-reports could be argued
to be conservative, and this one cannot. -/
theorem global_band_silenced_stealth :
    classifyGlobal 130 = .inRange ∧ classify .stealth 130 = .above := by
  decide

/-- The global band was correct for exactly one lane, which is why it survived
review: read against FORGE it agrees everywhere, so any test written on a FORGE
turn passes. -/
theorem global_band_agrees_only_by_being_forge (r : Nat) :
    classifyGlobal r = classify .forge r := by
  unfold classifyGlobal classify band forgeBand
  simp

/-- How wide the damage was, and it is as wide as it can be: the global band
disagrees with the correct verdict on NINE of the ten lanes. Only FORGE agrees
everywhere -- which is precisely why the bug survived review for so long. Any
test written on a FORGE turn, and this is a prover repo where FORGE is the
common lane, passes with the wrong band in place.

The witness scores are a fixed probe list, so this counts lanes for which a
disagreeing score EXISTS within the probe; it is a lower bound on the damage,
not an upper one.

I GUESSED EIGHT WHEN WRITING THIS AND THE NUMBER IS NINE. The guess was made by
eye and the count by `decide`; the difference is the whole argument for pinning
constants with a proof rather than a comment. -/
theorem global_band_wrong_for_nine_of_ten_lanes :
    (allLanes.filter (fun l => [50,80,100,130,140,190,210,260,360].any
      (fun r => decide (classify l r ≠ classifyGlobal r)))).length = 9 := by
  decide

/-- And the one lane it agrees with is FORGE, named rather than left implicit. -/
theorem the_only_agreeing_lane_is_forge :
    allLanes.filter (fun l => ! [50,80,100,130,140,190,210,260,360].any
      (fun r => decide (classify l r ≠ classifyGlobal r))) = [.forge] := by
  decide

end RotBandPerLane
