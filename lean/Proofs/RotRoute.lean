/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Mathlib

/-! # The RoT MoE router, formalized

A model of the three-tier router in `~/.claude/tools/sanctum/rot-lean.md` §3.

**Scope, stated first because it is a finding and not a footnote.** `RotGauge`
models code that ships: the R/s+ arithmetic really is implemented in
`rot-lean-inject.ps1`. This file does **not** have that property. Grepping the
hook for the mode names (`CLINICAL`, `FORGE`, …) finds them only in a comment at
`:47-51` and in payload text at `:471-472` — **TIER 1 keyword routing is not
implemented in the shipped hook today.** What ships is the gauge.

So the subject of this file is the *specification*, §3, and the honest reading is:
these theorems say the specified router is total, ordered and correctly
overridden — they do not say the PowerShell does it, because it does not. That
gap is exactly what the POSIX port (`hooks/rot-router.sh`) has to close before
the packet can claim "a REAL ROUTER" for TIER 1 rather than for the gauge alone.
Writing the proof first is the right order: the port now has a specification with
a kernel behind it instead of a paragraph.

Nothing here is quantified over today's keyword list. The stems change; the
*priority order* is the thing worth proving, and it is what the theorems address.
-/

namespace RotMoE.Route

/-! ## TIER 1 — the keyword scan -/

/-- The ten modes of §3. `convergent` is the default with no trigger. -/
inductive Mode where
  | forge | clinical | executive | empathic | strategic
  | creative | predictive | stealth | recursive | convergent
deriving DecidableEq, Repr, Inhabited

/-- Which stem classes matched this prompt. One `Bool` per non-default mode.

The *contents* of each stem class are deliberately absent from this model: they
are an empirical question about text, they change, and a theorem that pinned
them would expire the first time a stem is added. What is modelled is which
class fired, and what the router does about it. -/
structure Flags where
  forge : Bool
  clinical : Bool
  executive : Bool
  empathic : Bool
  strategic : Bool
  creative : Bool
  predictive : Bool
  stealth : Bool
  recursive : Bool
deriving DecidableEq, Repr

/-- Did this mode's trigger fire? `convergent` always fires — it is the default,
so treating it as permanently triggered is what makes `route_fires` uniform. -/
def fired (f : Flags) : Mode → Bool
  | .forge => f.forge
  | .clinical => f.clinical
  | .executive => f.executive
  | .empathic => f.empathic
  | .strategic => f.strategic
  | .creative => f.creative
  | .predictive => f.predictive
  | .stealth => f.stealth
  | .recursive => f.recursive
  | .convergent => true

/-- **The router.** The `if/elseif` chain of §3 in source order, FORGE first.

On this head the Lean stems route to FORGE and FORGE is the common case, so it
takes the head of the chain. Everything below is stated about this *order*, never
about which words are in which class. -/
def route (f : Flags) : Mode :=
  if f.forge then .forge
  else if f.clinical then .clinical
  else if f.executive then .executive
  else if f.empathic then .empathic
  else if f.strategic then .strategic
  else if f.creative then .creative
  else if f.predictive then .predictive
  else if f.stealth then .stealth
  else if f.recursive then .recursive
  else .convergent

/-- **The router never returns a mode whose trigger did not fire.**

This is the totality statement with content. The vacuous version — "every input
yields a mode" — is true of any function `Flags → Mode` including a constant, and
Router.lean records that trap in its own comments. This one can fail: point any
branch at the wrong constructor and it breaks. -/
theorem route_fires (f : Flags) : fired f (route f) = true := by
  obtain ⟨a, b, c, d, e, g, h, i, j⟩ := f
  cases a <;> cases b <;> cases c <;> cases d <;> cases e <;> cases g <;>
    cases h <;> cases i <;> cases j <;> rfl

/-- **No trigger ⇒ CONVERGENT.** The default is reached, not merely written. -/
theorem route_default_convergent (f : Flags)
    (h : f.forge = false ∧ f.clinical = false ∧ f.executive = false ∧
      f.empathic = false ∧ f.strategic = false ∧ f.creative = false ∧
      f.predictive = false ∧ f.stealth = false ∧ f.recursive = false) :
    route f = .convergent := by
  obtain ⟨h1, h2, h3, h4, h5, h6, h7, h8, h9⟩ := h
  simp [route, h1, h2, h3, h4, h5, h6, h7, h8, h9]

/-- **FORGE priority, stated as the ORDER and not as a fact about the stem list.**

A Lean-shaped prompt reaches the prover lane whatever else it also matched. The
hypothesis is only `f.forge = true`; every other flag is free, which is what makes
this a statement about precedence rather than about today's keywords. -/
theorem forge_priority (f : Flags) (h : f.forge = true) : route f = .forge := by
  simp [route, h]

/-- **Every lane is reachable — no dead branch.**

The theorem a reordering or a copy-paste in the chain actually breaks. Without
it, a branch could be shadowed by an earlier one and every theorem above would
still compile: `route_fires` is satisfied by a chain whose fifth branch can never
be taken. Each witness is a concrete `Flags`, so `decide` evaluates it. -/
theorem route_covers_every_mode (m : Mode) : ∃ f : Flags, route f = m := by
  cases m
  · exact ⟨⟨true, false, false, false, false, false, false, false, false⟩, by decide⟩
  · exact ⟨⟨false, true, false, false, false, false, false, false, false⟩, by decide⟩
  · exact ⟨⟨false, false, true, false, false, false, false, false, false⟩, by decide⟩
  · exact ⟨⟨false, false, false, true, false, false, false, false, false⟩, by decide⟩
  · exact ⟨⟨false, false, false, false, true, false, false, false, false⟩, by decide⟩
  · exact ⟨⟨false, false, false, false, false, true, false, false, false⟩, by decide⟩
  · exact ⟨⟨false, false, false, false, false, false, true, false, false⟩, by decide⟩
  · exact ⟨⟨false, false, false, false, false, false, false, true, false⟩, by decide⟩
  · exact ⟨⟨false, false, false, false, false, false, false, false, true⟩, by decide⟩
  · exact ⟨⟨false, false, false, false, false, false, false, false, false⟩, by decide⟩

/-- **The chain, characterised exactly, in both directions, for every lane.**

This is the `pragmatic_iff` of this file — the theorem that dies under a bad edit
where the softer ones survive. Read the right-hand sides for what they say about
*precedence*: each lane requires its own flag set **and every earlier flag
clear**, and no right-hand side mentions a later flag, so each lane is proved
indifferent to everything downstream of it.

Swap any two adjacent branches and the corresponding `↔` fails; change the final
`else` and the last one fails. `route_fires` survives all of those. -/
theorem route_exact (f : Flags) :
    (route f = .forge ↔ f.forge = true) ∧
    (route f = .clinical ↔ (f.forge = false ∧ f.clinical = true)) ∧
    (route f = .executive ↔ (f.forge = false ∧ f.clinical = false ∧
      f.executive = true)) ∧
    (route f = .empathic ↔ (f.forge = false ∧ f.clinical = false ∧
      f.executive = false ∧ f.empathic = true)) ∧
    (route f = .strategic ↔ (f.forge = false ∧ f.clinical = false ∧
      f.executive = false ∧ f.empathic = false ∧ f.strategic = true)) ∧
    (route f = .creative ↔ (f.forge = false ∧ f.clinical = false ∧
      f.executive = false ∧ f.empathic = false ∧ f.strategic = false ∧
      f.creative = true)) ∧
    (route f = .predictive ↔ (f.forge = false ∧ f.clinical = false ∧
      f.executive = false ∧ f.empathic = false ∧ f.strategic = false ∧
      f.creative = false ∧ f.predictive = true)) ∧
    (route f = .stealth ↔ (f.forge = false ∧ f.clinical = false ∧
      f.executive = false ∧ f.empathic = false ∧ f.strategic = false ∧
      f.creative = false ∧ f.predictive = false ∧ f.stealth = true)) ∧
    (route f = .recursive ↔ (f.forge = false ∧ f.clinical = false ∧
      f.executive = false ∧ f.empathic = false ∧ f.strategic = false ∧
      f.creative = false ∧ f.predictive = false ∧ f.stealth = false ∧
      f.recursive = true)) ∧
    (route f = .convergent ↔ (f.forge = false ∧ f.clinical = false ∧
      f.executive = false ∧ f.empathic = false ∧ f.strategic = false ∧
      f.creative = false ∧ f.predictive = false ∧ f.stealth = false ∧
      f.recursive = false)) := by
  obtain ⟨a, b, c, d, e, g, h, i, j⟩ := f
  cases a <;> cases b <;> cases c <;> cases d <;> cases e <;> cases g <;>
    cases h <;> cases i <;> cases j <;> simp [route]

/-! ## TIER 2 — NSIL, and why this is a router rather than an `if`-chain -/

/-- What NSIL decides, per the §3 table. -/
inductive Decision where
  /-- Keywords match real intent; the TIER 1 lead stands. -/
  | confirm
  /-- The words mislead (`fix our relationship` → EMPATHIC, not CLINICAL). -/
  | override (m : Mode)
  /-- Right mode, one lens underweighted; a single λ rises. The lead is unchanged. -/
  | boost
  /-- Intent spans two domains; two leads fuse. -/
  | fuse (a b : Mode)
  /-- No trigger but the query is dense; all nine at full weight, no single lead. -/
  | elevate
deriving DecidableEq, Repr

/-- The final lead. `ensemble` exists because ELEVATE has no single lead — a
model that forced one would misstate the spec and quietly make `elevate`
indistinguishable from `confirm`. -/
inductive Lead where
  | single (m : Mode)
  | hybrid (a b : Mode)
  | ensemble
deriving DecidableEq, Repr

/-- The two tiers composed: TIER 1 proposes, NSIL disposes. -/
def lead (f : Flags) (d : Decision) : Lead :=
  match d with
  | .confirm => .single (route f)
  | .override m => .single m
  | .boost => .single (route f)
  | .fuse a b => .hybrid a b
  | .elevate => .ensemble

/-- **The headline: TIER 2's decision beats TIER 1.**

Two halves, and both are needed. The first says OVERRIDE lands on the mode NSIL
named, whatever the keywords said. The second says that this is not vacuous —
there really is an input where the override result *differs* from the keyword
result.

Without the second half the theorem would be satisfied by an implementation that
ignores NSIL entirely whenever the two happen to agree. With it, this is the
statement that separates a router from a keyword `if`-chain: the chain is a
*proposal*, and something above it can and does refuse the proposal. -/
theorem nsil_overrides_tier1 :
    (∀ (f : Flags) (m : Mode), lead f (.override m) = .single m) ∧
      (∃ (f : Flags) (m : Mode), lead f (.override m) ≠ lead f .confirm) := by
  constructor
  · intro f m; rfl
  · refine ⟨⟨false, true, false, false, false, false, false, false, false⟩,
      .empathic, ?_⟩
    decide

/-- **CONFIRM changes nothing.** The other side of the headline: NSIL is not
free to move the lead when it has decided the keywords were right. Without this,
`lead` could ignore TIER 1 altogether and `nsil_overrides_tier1` would still
hold. -/
theorem nsil_confirm_is_tier1 (f : Flags) : lead f .confirm = .single (route f) := rfl

/-- **BOOST raises a λ, it does not move the lead.** The §3 table says so in
prose; this is the same claim where a bad edit can break it. -/
theorem nsil_boost_preserves_lead (f : Flags) : lead f .boost = lead f .confirm := rfl

/-- **ELEVATE has no single lead, and FUSE is not a single lead either.**

Stated because the tempting simplification — collapse `Lead` to `Mode` — is
exactly what would erase the distinction between the five decisions. If this
stops compiling, someone has flattened the type and the ELEVATE row of §3 has
silently become CONVERGENT. -/
theorem elevate_and_fuse_are_not_single (f : Flags) (m a b : Mode) :
    lead f .elevate ≠ .single m ∧ lead f (.fuse a b) ≠ .single m := by
  constructor <;> simp [lead]

/-! ## Symbiogenesis — the fusion formulae of §3

Quantified over **lens pairs** as real numbers, never over the three canonical
hybrids. A theorem about today's hybrid table expires the day a lens is added,
and adding a lens is a change this project would make on purpose.
-/

/-- `λ_hybrid = (λ₁ + λ₂) / 2 + 0.2` — the mean plus the hybridisation gain. -/
noncomputable def lamH (l₁ l₂ : ℝ) : ℝ := (l₁ + l₂) / 2 + 0.2

/-- `H_hybrid = max(H₁, H₂) + 0.05` — at least the higher entropy, plus a
novelty margin. -/
noncomputable def hH (h₁ h₂ : ℝ) : ℝ := max h₁ h₂ + 0.05

/-- `μ_hybrid = max(μ₁, μ₂)` — no gain term. Without this a hybrid has no
defined μ at all, and μ is a *factor* in R/s+. -/
noncomputable def muH (m₁ m₂ : ℝ) : ℝ := max m₁ m₂

/-- **Fusion is order-independent.** `A × B` and `B × A` are the same hybrid.
Not decoration: `muH` and `hH` are built on `max`, and an implementation that
reached for "the first lens's μ" would break this while satisfying every bound
below. -/
theorem symbiogenesis_comm (x y : ℝ) :
    lamH x y = lamH y x ∧ hH x y = hH y x ∧ muH x y = muH y x := by
  refine ⟨?_, ?_, ?_⟩
  · unfold lamH; ring
  · unfold hH; rw [max_comm]
  · unfold muH; rw [max_comm]

/-- **Fusion strictly exceeds the mean.** This is what the `+0.2` is *for*, and
the theorem that dies if it is dropped — which is precisely the mutation the
goal document asks for. -/
theorem lamH_gt_mean (l₁ l₂ : ℝ) : lamH l₁ l₂ > (l₁ + l₂) / 2 := by
  unfold lamH; norm_num

/-- **The hybrid's entropy strictly exceeds both parents'.** The `+0.05` novelty
margin, stated where removing it breaks something. -/
theorem hH_gt_both (h₁ h₂ : ℝ) : hH h₁ h₂ > h₁ ∧ hH h₁ h₂ > h₂ := by
  constructor <;> · unfold hH; have := le_max_left h₁ h₂; have := le_max_right h₁ h₂; linarith

/-- **The hybrid's μ is at least both parents' and no more than the larger.**
`max` and nothing else — an implementation that averaged μ, or that added a gain
term to it, breaks this. -/
theorem muH_exact (m₁ m₂ : ℝ) :
    m₁ ≤ muH m₁ m₂ ∧ m₂ ≤ muH m₁ m₂ ∧ (muH m₁ m₂ = m₁ ∨ muH m₁ m₂ = m₂) := by
  refine ⟨le_max_left _ _, le_max_right _ _, ?_⟩
  unfold muH
  rcases le_total m₁ m₂ with h | h
  · right; exact max_eq_right h
  · left; exact max_eq_left h

/-- **Well-formedness, over the range bounds as VARIABLES.**

If both parents' weights lie in `[lo, hi]` then the hybrid's do too, shifted by
exactly the documented gains. Stating it over `lo`/`hi` rather than over today's
numbers is the [!SPEC] rule applied: retuning the weight range is a change this
project would make on purpose, and a theorem that forbade it would be a defect
rather than a safeguard. -/
theorem symbiogenesis_wellformed (lo hi l₁ l₂ m₁ m₂ h₁ h₂ : ℝ)
    (hl₁ : l₁ ∈ Set.Icc lo hi) (hl₂ : l₂ ∈ Set.Icc lo hi)
    (hm₁ : m₁ ∈ Set.Icc lo hi) (hm₂ : m₂ ∈ Set.Icc lo hi)
    (hh₁ : h₁ ∈ Set.Icc lo hi) (hh₂ : h₂ ∈ Set.Icc lo hi) :
    lamH l₁ l₂ ∈ Set.Icc (lo + 0.2) (hi + 0.2) ∧
      muH m₁ m₂ ∈ Set.Icc lo hi ∧
      hH h₁ h₂ ∈ Set.Icc (lo + 0.05) (hi + 0.05) := by
  obtain ⟨a₁, b₁⟩ := hl₁; obtain ⟨a₂, b₂⟩ := hl₂
  obtain ⟨c₁, d₁⟩ := hm₁; obtain ⟨c₂, d₂⟩ := hm₂
  obtain ⟨e₁, f₁⟩ := hh₁; obtain ⟨e₂, f₂⟩ := hh₂
  refine ⟨⟨?_, ?_⟩, ⟨?_, ?_⟩, ⟨?_, ?_⟩⟩
  · unfold lamH; linarith
  · unfold lamH; linarith
  · unfold muH; exact le_max_of_le_left c₁
  · unfold muH; exact max_le d₁ d₂
  · unfold hH; have := le_max_left h₁ h₂; linarith
  · unfold hH; have : max h₁ h₂ ≤ hi := max_le f₁ f₂; linarith

/-- Today's canonical hybrid, as an `example` rather than a theorem: the
Verified Forge, `🧭 Claude × ⚪ Anti-Venom`, from the §2 defaults. It documents
the present without becoming a hypothesis anything rests on — the day a lens is
retuned this line moves and nothing else does.

It also re-checks §3's own corrected arithmetic: μ takes both operands from the
§2 defaults (`1.05`, `1.00`), giving `1.05` — not the `1.20` that came from
mixing in Anti-Venom's CLINICAL-profile μ. -/
example : lamH 1.5 1.5 = 1.7 ∧ muH 1.05 1.00 = 1.05 ∧ hH 0.30 0.30 = 0.35 := by
  refine ⟨?_, ?_, ?_⟩ <;> norm_num [lamH, muH, hH, max_self]

end RotMoE.Route
