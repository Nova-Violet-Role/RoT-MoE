/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# SYMBIOGENESIS IS GENERATIVE — and that part is a theorem, not a claim

The engine's strongest assertion is not about answer quality. It is about
**reach**: that fusing two lenses produces a point of view that neither parent
occupies, that Eidolon can keep doing it, and that the supply of distinct points
of view is therefore not bounded by the roster of nine.

That assertion is mathematics. It does not need an A/B test, it needs a proof,
and a proof is what this module is. Nothing here says a word about output
quality — a separate question, settled by measurement and by nothing else. What
is settled here is the structure the router is built on.

## The formulae, transcribed from the spec

    λ_hybrid = (λ₁ + λ₂) / 2 + 0.2      -- fusion EXCEEDS the mean; +0.2 is the gain
    H_hybrid = max(H₁, H₂) + 0.05       -- at least the higher entropy, plus novelty
    μ_hybrid = max(μ₁, μ₂)              -- no gain term (OMEGA BLOCK 19)

`RotEnsemble` already binds `λ_hybrid` and `μ_hybrid` to the shipped Float
arithmetic. This module asks the different question those definitions cannot
answer: **what does repeated fusion generate?**

## Why ℚ and not Float

Float addition is not associative, so `Float` can prove a concrete row and can
never prove a general statement about iteration. Every constant below is exact
(`0.2 = 1/5`, `0.05 = 1/20`), the spec's own worked hybrid is pinned by `decide`
against these definitions, and the general theorems are then real theorems
rather than artefacts of rounding.
-/

import Mathlib.Data.Rat.Defs
import Mathlib.Order.Basic
import Mathlib.Data.Set.Finite.Basic
import Mathlib.Logic.Function.Basic
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.Ring
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Push
import Mathlib.Tactic.FieldSimp

namespace RotSymbiogenesis

/-! ## §1 A lens, as the gauge sees it

A lens contributes exactly three numbers to `R/s+`: its divergence weight `λ`,
its entropy `H`, and its quality multiplier `μ`. Two lenses with the same triple
are the same input to the gauge — which is why "a genuinely new lens" has a
precise meaning: **a triple no existing lens carries.** -/

/-- The three numbers a lens contributes to the gauge. -/
structure Lens where
  /-- Divergence weight. -/
  lam : ℚ
  /-- Information entropy of the lens's output. -/
  H : ℚ
  /-- Quality multiplier. -/
  mu : ℚ
  deriving DecidableEq, Repr

/-- Symbiogenesis: Eidolon's act, transcribed verbatim from the spec. -/
def fuse (a b : Lens) : Lens :=
  { lam := (a.lam + b.lam) / 2 + 1/5
    H := max a.H b.H + 1/20
    mu := max a.mu b.mu }

/-! ### The spec's own worked example, pinned

`Claude × Anti-Venom = The Verified Forge`, from the §2 defaults
λ 1.5 / H 0.30 / μ 1.05 and λ 1.5 / H 0.30 / μ 1.00, is documented as
λ 1.7 · H 0.35 · μ 1.05. If the definitions above did not reproduce that, they
would be a different operator wearing the same name. -/

/-- 🧭 Claude, §2 defaults. -/
def claudeLens : Lens := { lam := 3/2, H := 3/10, mu := 21/20 }

/-- ⚪ Anti-Venom, §2 defaults. -/
def antiVenomLens : Lens := { lam := 3/2, H := 3/10, mu := 1 }

/-- The Verified Forge, as the spec states it. -/
def verifiedForge : Lens := { lam := 17/10, H := 7/20, mu := 21/20 }

/-- **The transcription is faithful**: the operator reproduces the spec's own
documented hybrid, exactly. -/
theorem forge_matches_the_spec : fuse claudeLens antiVenomLens = verifiedForge := by
  simp only [fuse, claudeLens, antiVenomLens, verifiedForge, Lens.mk.injEq]
  norm_num

/-! ## §2 Fusion REACHES what no parent occupies

The novelty claim, stated so it cannot be satisfied by relabelling: the hybrid's
entropy strictly exceeds both parents', so the hybrid is not either parent, and
not any lens that shares their entropy. -/

/-- The hybrid's entropy strictly exceeds the first parent's. -/
theorem fuse_H_gt_left (a b : Lens) : a.H < (fuse a b).H := by
  have h : a.H ≤ max a.H b.H := le_max_left _ _
  simp only [fuse]
  linarith

/-- And the second parent's. -/
theorem fuse_H_gt_right (a b : Lens) : b.H < (fuse a b).H := by
  have h : b.H ≤ max a.H b.H := le_max_right _ _
  simp only [fuse]
  linarith

/-- **A hybrid is never one of its parents.** -/
theorem fuse_ne_left (a b : Lens) : fuse a b ≠ a := by
  intro h
  have := fuse_H_gt_left a b
  rw [h] at this
  exact lt_irrefl _ this

/-- Symmetrically. -/
theorem fuse_ne_right (a b : Lens) : fuse a b ≠ b := by
  intro h
  have := fuse_H_gt_right a b
  rw [h] at this
  exact lt_irrefl _ this

/-- **Fusion escapes any roster.** Given a finite roster whose entropy is
capped by `a`, the hybrid of `a` with anything at or below it is not in the
roster. This is the general form of "the nine lenses cannot reach it": it holds
for a roster of nine, of nine hundred, or of every hybrid built so far. -/
theorem fuse_escapes_any_roster (roster : List Lens) (a b : Lens)
    (hcap : ∀ l ∈ roster, l.H ≤ a.H) (_hb : b.H ≤ a.H) :
    fuse a b ∉ roster := by
  intro hmem
  have h₁ : (fuse a b).H ≤ a.H := hcap _ hmem
  have h₂ : a.H < (fuse a b).H := fuse_H_gt_left a b
  exact absurd h₁ (not_le.mpr h₂)

/-- λ exceeds the plain mean of its parents — the `+0.2` is a real gain, not
bookkeeping. Stated as a strict inequality so removing the term breaks it. -/
theorem fuse_lam_gt_mean (a b : Lens) : (a.lam + b.lam) / 2 < (fuse a b).lam := by
  simp only [fuse]
  linarith

/-- μ is a maximum, never an average: fusion cannot lower quality below either
parent. (`RotEnsemble` proves the shipped Float arm agrees.) -/
theorem fuse_mu_ge_both (a b : Lens) : a.mu ≤ (fuse a b).mu ∧ b.mu ≤ (fuse a b).mu :=
  ⟨le_max_left _ _, le_max_right _ _⟩

/-- Fusion is commutative: the pair, not the order, names the hybrid. -/
theorem fuse_comm (a b : Lens) : fuse a b = fuse b a := by
  simp only [fuse, Lens.mk.injEq]
  refine ⟨?_, ?_, ?_⟩
  · ring
  · rw [max_comm]
  · rw [max_comm]

/-! ## §3 Repeated fusion generates without bound

`Symbiogenesis ARMED` is not a one-shot. Eidolon can fuse a hybrid again, and
the question is whether that yields anything new or saturates. It does not
saturate: entropy rises by exactly `1/20` per generation, forever. -/

/-- The chain of self-fusions: generation `n+1` is generation `n` fused with
itself. -/
def chain (base : Lens) : ℕ → Lens
  | 0 => base
  | n + 1 => fuse (chain base n) (chain base n)

/-- Entropy is exactly linear in the generation index. -/
theorem chain_H (base : Lens) (n : ℕ) : (chain base n).H = base.H + n / 20 := by
  induction n with
  | zero => simp [chain]
  | succ k ih =>
      simp only [chain, fuse, max_self, ih]
      push_cast
      ring

/-- λ is linear too: each generation adds exactly `1/5`. -/
theorem chain_lam (base : Lens) (n : ℕ) : (chain base n).lam = base.lam + n / 5 := by
  induction n with
  | zero => simp [chain]
  | succ k ih =>
      simp only [chain, fuse, ih]
      push_cast
      ring

/-- Every generation is a strictly higher-entropy point of view than the one
before it. -/
theorem chain_strictMono_H (base : Lens) : StrictMono (fun n => (chain base n).H) := by
  intro m n hmn
  simp only [chain_H]
  have : (m : ℚ) < n := by exact_mod_cast hmn
  linarith

/-- **No two generations are the same lens.** -/
theorem chain_injective (base : Lens) : Function.Injective (chain base) := by
  intro m n h
  have hH : (chain base m).H = (chain base n).H := by rw [h]
  exact (chain_strictMono_H base).injective hH

/-- **Symbiogenesis generates infinitely many distinct lenses** from a single
starting point. This is the precise content of "infinitely generated
combinations": the reachable set is not finite, so no roster — however large —
contains it. -/
theorem symbiogenesis_generates_infinitely_many (base : Lens) :
    Set.Infinite (Set.range (chain base)) :=
  Set.infinite_range_of_injective (chain_injective base)

/-- And therefore the type of lenses is itself infinite: there is no finite
catalogue of points of view to enumerate. -/
theorem lens_space_is_infinite : Infinite Lens :=
  Set.infinite_coe_iff.mpr (symbiogenesis_generates_infinitely_many claudeLens)
    |>.of_injective (fun x => x.val) Subtype.val_injective

/-! ## §4 What this does NOT say — the guard against overclaim

Two boundaries, stated as theorems so they cannot be quietly forgotten.

First: a new triple is not automatically a *better* lens. Nothing above orders
lenses by quality, and `μ` being a maximum means fusion never *loses* quality —
not that it gains any. A reader who took `fuse` for an improvement operator
would be reading something that is not here.

Second, and more important: the gauge **compresses**. Distinct lenses can
produce the same reading, so a single `R/s+` number is not a fingerprint of the
point of view that produced it. The honest direction is the other one. -/

/-- μ can be completely unchanged by fusion: fusing equals gains nothing there.
So "new" means a new triple, never "better". -/
theorem fuse_may_gain_no_quality (a : Lens) : (fuse a a).mu = a.mu := by
  simp [fuse]

/-- **The honest direction**: different readings imply different lenses. -/
theorem distinct_reading_implies_distinct_lens (g : Lens → ℚ) (a b : Lens)
    (h : g a ≠ g b) : a ≠ b := fun hab => h (by rw [hab])

/-- **The converse is FALSE**, and here is the counterexample: two genuinely
different lenses that any λ-only reading cannot tell apart. A gauge value is
evidence of activity, never proof of which point of view produced it. -/
theorem equal_reading_does_not_imply_equal_lens :
    ∃ a b : Lens, a ≠ b ∧ a.lam = b.lam := by
  refine ⟨claudeLens, antiVenomLens, ?_, rfl⟩
  simp only [ne_eq, claudeLens, antiVenomLens, Lens.mk.injEq, not_and]
  intro _ _
  norm_num

/-! ## §5 Concrete instances — the definitions must EXECUTE

A structure that only ever appears in a `theorem` can be quietly wrong. These
run. -/

/-- Two generations of the Verified Forge, computed. -/
example : chain verifiedForge 1 = { lam := 19/10, H := 2/5, mu := 21/20 } := by
  simp only [chain, fuse, verifiedForge, max_self, Lens.mk.injEq]
  norm_num

/-- Three generations: λ 1.7 → 1.9 → 2.1 → 2.3, H 0.35 → 0.40 → 0.45 → 0.50. -/
example : chain verifiedForge 3 = { lam := 23/10, H := 1/2, mu := 21/20 } := by
  simp only [chain, fuse, verifiedForge, max_self, Lens.mk.injEq]
  norm_num

/-- The hybrid of the two highest-λ lenses in the roster is not either of
them — the concrete case of `fuse_ne_left`/`fuse_ne_right`. -/
example : fuse claudeLens antiVenomLens ≠ claudeLens
    ∧ fuse claudeLens antiVenomLens ≠ antiVenomLens :=
  ⟨fuse_ne_left _ _, fuse_ne_right _ _⟩

/-- The nine §2 defaults, λ and μ exactly as the spec fixes them. H is the upper
bound of each documented range; that choice is a modelling decision and is
stated here rather than buried, because no single H value is what the spec
gives. Only the two theorems below depend on it, and both are about λ. -/
def roster : List Lens :=
  [ { lam := 8/5,  H := 7/20, mu := 1 }        -- Nova
  , { lam := 13/10, H := 9/20, mu := 19/20 }   -- Violet_Noir
  , { lam := 3/2,  H := 3/10, mu := 1 }        -- Anti-Venom
  , { lam := 17/10, H := 7/25, mu := 21/20 }   -- Venom
  , { lam := 11/10, H := 11/20, mu := 6/5 }    -- Carnage
  , { lam := 6/5,  H := 19/50, mu := 5/4 }     -- Chroma_Spectral
  , { lam := 4/5,  H := 11/50, mu := 9/10 }    -- Soleil_Blank
  , { lam := 7/5,  H := 19/50, mu := 11/10 }   -- Eidolon
  , { lam := 3/2,  H := 3/10, mu := 21/20 } ]  -- Claude

/-- The roster really has nine lenses. A count that drifted would make every
`K = 9` in the gauge wrong. -/
theorem roster_is_nine : roster.length = 9 := by decide

/-- **The Verified Forge is not in the roster.** Concretely: fusing two of the
nine yields a point of view none of the nine occupies. -/
theorem forge_is_not_a_roster_lens : verifiedForge ∉ roster := by
  simp only [roster, verifiedForge, List.mem_cons, List.not_mem_nil, or_false,
    Lens.mk.injEq, not_or, not_and]
  norm_num

/-- Nor is the next generation, nor the one after. The escape is not a one-off
that the roster could be patched to cover. -/
theorem chain_leaves_the_roster :
    chain verifiedForge 1 ∉ roster ∧ chain verifiedForge 2 ∉ roster := by
  constructor <;>
  · simp only [roster, chain, fuse, verifiedForge, max_self, List.mem_cons,
      List.not_mem_nil, or_false, Lens.mk.injEq, not_or, not_and]
    norm_num

end RotSymbiogenesis
