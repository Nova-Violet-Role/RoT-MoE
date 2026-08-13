/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A zero gauge is always a zero input, never the arithmetic

`R/s+ = 0.0` is defined as a **violation**: a gauge that was never really computed.
That rule is only enforceable if a zero can be attributed. This module settles the
attribution.

## What the live run measured

100 gauge computations from a real Claude-Test session on the freshly installed
packet: 16 distinct `Rs` values spanning `0.157 … 0.664`, `K = 9` on every record,
and **`Rs = 0` never once**. It also measured `breadth ∈ {0, 1}` — that corpus
never activated two lenses on the same turn.

`breadth = 0` is not an anomaly: it is every turn on which no lens fires. The
router divides by it, at `hooks/rot-router.sh:437`:

    H  = (breadth > 0 ? act / breadth : 0.0);    # share of the turn breadth

Measured in both directions on this machine, and the guard is load-bearing:

    awk 'BEGIN{ H = 0/0 }'                            -> fatal: division by zero, exit 2
    awk 'BEGIN{ H = (0>0 ? 0/0 : 0.0); print H }'     -> H=0,   exit 0
    awk 'BEGIN{ H = (2>0 ? 1/2 : 0.0); print H }'     -> H=0.5, exit 0

## What Lean can and cannot settle here, stated before the theorems

**Lean cannot reproduce that crash.** `Nat` division is *total* — `n / 0 = 0` is a
theorem of core Lean, not an error — so a Lean model of the unguarded expression
would be perfectly well behaved and would prove nothing about awk. The crash is
MEASURED above and stays measured; no theorem below is offered as evidence for it.

What Lean settles instead is the part that a measurement cannot: that the guard
changes nothing wherever the division was already defined, and that a zero gauge is
always attributable to a zero factor rather than to accumulated arithmetic.

Values are fixed-point naturals (the router formats to five decimals); the
positivity structure being proved is invariant to the scale.
-/

namespace RotMoE.GaugePositivity

/-! ## The division guard -/

/-- The shipped guard from `hooks/rot-router.sh:437`, in Lean. -/
def guardedH (act breadth : Nat) : Nat :=
  if breadth > 0 then act / breadth else 0

/-- **The guard costs nothing.** Wherever the unguarded division was defined, the
guarded form agrees with it exactly — stated over every activity and every positive
breadth, so no future corpus can make it false. -/
theorem the_guard_agrees_wherever_division_was_defined
    (act breadth : Nat) (h : 0 < breadth) :
    guardedH act breadth = act / breadth := by
  simp [guardedH, h]

/-- And it is total at the value that actually occurs in production: a turn on
which no lens fires. -/
theorem the_guard_is_total_at_zero_breadth (act : Nat) : guardedH act 0 = 0 := rfl

/-! ## One lens's contribution -/

/-- The factors of a single lens's term. `sig` is the sigmoid-saturated divergence
already scaled; the engine's `M`, `C` and `T` are global and are carried separately
below. -/
structure Term where
  lam : Nat
  sig : Nat
  mu  : Nat
  deriving DecidableEq, Repr

/-- λ_i · σ(δ_i) · μ_i. -/
def termValue (t : Term) : Nat := t.lam * t.sig * t.mu

/-- **A lens contributes nothing exactly when one of its factors is nothing.**
There is no third way for a term to vanish, which is what makes a zero
attributable. -/
theorem a_term_vanishes_only_when_a_factor_does (t : Term) :
    termValue t = 0 ↔ (t.lam = 0 ∨ t.sig = 0 ∨ t.mu = 0) := by
  simp [termValue, Nat.mul_eq_zero, or_assoc]

/-- The contrapositive, in the form the router needs: every factor present means
the lens really did contribute. -/
theorem a_lens_with_no_zero_factor_contributes (t : Term)
    (hl : 0 < t.lam) (hs : 0 < t.sig) (hm : 0 < t.mu) : 0 < termValue t :=
  Nat.mul_pos (Nat.mul_pos hl hs) hm

/-! ## The ensemble -/

/-- The unnormalised sum over the active lenses. `K` divides it afterwards and
cannot introduce a zero that the sum did not already have. -/
def gaugeSum : List Term → Nat
  | [] => 0
  | t :: ts => termValue t + gaugeSum ts

/-- **The attribution theorem.** The whole gauge vanishes exactly when every single
lens vanished — so a zero `R/s+` is never the sum's doing. Somebody handed it nine
zeroed terms, or the computation never ran. Stated over every possible ensemble. -/
theorem the_gauge_vanishes_only_if_every_lens_did (ts : List Term) :
    gaugeSum ts = 0 ↔ ∀ t ∈ ts, termValue t = 0 := by
  induction ts with
  | nil => simp [gaugeSum]
  | cons t ts ih =>
    simp only [gaugeSum, List.mem_cons, Nat.add_eq_zero_iff, ih]
    constructor
    · rintro ⟨h1, h2⟩ x (rfl | hx)
      · exact h1
      · exact h2 x hx
    · intro h
      exact ⟨h t (Or.inl rfl), fun x hx => h x (Or.inr hx)⟩

/-- **The positive form, which is the one the engine's law needs.** One lens with
all three factors present is enough to make the gauge non-zero, no matter what the
other eight did. `R/s+ = 0.0` therefore cannot arise from a live ensemble in which
any lens fired at all. -/
theorem one_live_lens_is_enough (ts : List Term) (t : Term) (hmem : t ∈ ts)
    (hl : 0 < t.lam) (hs : 0 < t.sig) (hm : 0 < t.mu) : 0 < gaugeSum ts := by
  have hpos : 0 < termValue t := a_lens_with_no_zero_factor_contributes t hl hs hm
  have hne : gaugeSum ts ≠ 0 := by
    intro hzero
    have := (the_gauge_vanishes_only_if_every_lens_did ts).mp hzero t hmem
    omega
  omega

/-- The nine-lens ensemble as the router measured it: `K = 9` on every record. -/
def K : Nat := 9

/-- A witness ensemble at the FORGE profile's shipped weights, scaled by 100 so the
tenths survive as naturals. λ from the profile, μ likewise, σ set to a uniform
non-zero saturation — the point is the positivity structure, not these particular
divergences. -/
def forgeWitness : List Term :=
  [ { lam := 230, sig := 50, mu := 115 }   -- Claude
  , { lam := 190, sig := 50, mu := 110 }   -- Anti-Venom
  , { lam := 140, sig := 50, mu := 105 }   -- Nova
  , { lam := 120, sig := 50, mu := 110 }   -- Eidolon
  , { lam := 120, sig := 50, mu := 105 }   -- Venom
  , { lam := 100, sig := 50, mu := 110 }   -- Chroma
  , { lam :=  60, sig := 50, mu :=  90 }   -- Carnage
  , { lam :=  60, sig := 50, mu :=  85 }   -- Violet
  , { lam := 100, sig := 50, mu :=  95 } ] -- Soleil

/-- The witness has exactly `K` lenses — the ensemble is the full nine, not a
subset that happened to be convenient. -/
theorem the_witness_is_the_full_ensemble : forgeWitness.length = K := by decide

/-- And it computes to something strictly positive, which is the anti-vacuity
check on every theorem above: the machinery is not proving things about an empty
list. -/
theorem the_witness_gauge_is_positive : 0 < gaugeSum forgeWitness := by decide

/-- **The failure the law is about**, exhibited so it is not hypothetical: zero out
one factor across the ensemble and the gauge really does collapse to the forbidden
value. This is what `R/s+ = 0.0` looks like, and it takes every lens dying to
produce it. -/
theorem the_forbidden_zero_needs_every_lens_dead :
    gaugeSum (forgeWitness.map (fun t => { t with sig := 0 })) = 0 := by decide

/-- Killing only *one* lens does not do it — the ensemble survives, which is the
robustness the nine-lens design is for. -/
theorem killing_a_single_lens_does_not_zero_the_gauge :
    0 < gaugeSum ({ lam := 230, sig := 0, mu := 115 } :: forgeWitness.tail) := by decide

-- Contingent facts about the run of 2026-08-11, kept as guards and never as
-- hypotheses: these are what the corpus happened to produce, and every one of
-- them can legitimately change.
#guard K == 9                          -- nine lenses on every record
#guard guardedH 0 0 == 0               -- the production case: no lens fired
#guard guardedH 1 2 == 0               -- Nat floor division, as the model states
#guard forgeWitness.length == 9

end RotMoE.GaugePositivity
