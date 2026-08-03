/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# THE STEP BEFORE THE ROUTER: PROMPT TEXT -> WHICH CLASS FIRED.

`RotRoute.lean` formalises the `if/elseif` chain over a `Flags` record and says,
correctly, that the *contents* of each stem class are deliberately outside the
model: a theorem naming today's words would expire the first time a stem is
added, which is the dated-theorem trap this repository refuses elsewhere.

That reasoning is right and it stops one step short. Between a user's prompt and
those `Flags` there is a real function -- "does any stem of this class occur in
the prompt" -- and it was covered by no theorem at all. `checker/cross-diff.sh`
SAMPLES it on a corpus and the live marketplace gate SAMPLES it on ten prompts.
Neither settles it.

What is proven here is quantified over an ARBITRARY stem list, so no word is
pinned and nothing below expires when the router's vocabulary changes:

* matching is sound and complete w.r.t. "some stem occurs" (`fires_iff`);
* a class with no stems never fires -- the empty list is not a wildcard;
* ADDING a stem never un-fires a class that already fired (monotonicity), which
  is the property that makes extending the vocabulary safe;
* the ORDER of words inside a class is irrelevant, so the shell may keep its
  list in any order it likes;
* a prompt in which nothing occurs routes to `convergent`, and
* extending any lower-priority class cannot steal a prompt that already routed
  FORGE -- the durable form of "FORGE first".

The last two are the ones with teeth: they are exactly the invariants a future
edit to the stem lists could break, and they hold for every possible edit.
-/
import Mathlib.Data.List.Infix
import Mathlib.Data.List.Perm.Basic

namespace RotMoE.Stem

/-- A prompt and a stem are both just character sequences here. Working on
`List Char` rather than `String` keeps `<:+:` (list infix) available with its
decidability instance, and `String.toList` is the bridge the shell's substring
test corresponds to. -/
abbrev Text := List Char

/-- **Did any stem of this class occur in the prompt?**

This is the shell's `fired` predicate: a case-insensitive substring test against
each word of the class, OR-ed together. The case folding is deliberately not
modelled -- it is applied to both sides before this point, so it cannot change
which of the statements below hold. -/
def fires (p : Text) (stems : List Text) : Prop :=
  ∃ s ∈ stems, s <:+: p

instance (p : Text) (stems : List Text) : Decidable (fires p stems) := by
  unfold fires; infer_instance

/-- Soundness and completeness in one: firing is exactly occurrence. Stated as
an `iff` so neither direction can be quietly lost. -/
theorem fires_iff (p : Text) (stems : List Text) :
    fires p stems ↔ ∃ s ∈ stems, s <:+: p := Iff.rfl

/-- **A class with no stems never fires.** The empty list is not a wildcard.

This is the one that would catch an `any`-over-empty implemented as `true`, a
classic off-by-default bug: a class whose word list was accidentally emptied
would then swallow every prompt. -/
theorem not_fires_nil (p : Text) : ¬ fires p [] := by
  rintro ⟨s, hs, -⟩
  simp at hs

-- **Adding a stem never un-fires a class.** Vocabulary growth is safe.
theorem fires_mono {p : Text} {a b : List Text} (hsub : a ⊆ b) (h : fires p a) :
    fires p b := by
  obtain ⟨s, hs, hinf⟩ := h
  exact ⟨s, hsub hs, hinf⟩

-- Appending words to a class is the union of the two searches.
theorem fires_append (p : Text) (a b : List Text) :
    fires p (a ++ b) ↔ fires p a ∨ fires p b := by
  constructor
  · rintro ⟨s, hs, hinf⟩
    rcases List.mem_append.mp hs with h | h
    · exact Or.inl ⟨s, h, hinf⟩
    · exact Or.inr ⟨s, h, hinf⟩
  · rintro (⟨s, hs, hinf⟩ | ⟨s, hs, hinf⟩)
    · exact ⟨s, List.mem_append.mpr (Or.inl hs), hinf⟩
    · exact ⟨s, List.mem_append.mpr (Or.inr hs), hinf⟩

/-- **The order of words inside a class is irrelevant.** The shell is free to
keep its lists sorted, grouped, or in the order they were thought of. -/
theorem fires_perm {p : Text} {a b : List Text} (hp : a.Perm b) :
    fires p a ↔ fires p b := by
  constructor
  · rintro ⟨s, hs, hinf⟩; exact ⟨s, hp.mem_iff.mp hs, hinf⟩
  · rintro ⟨s, hs, hinf⟩; exact ⟨s, hp.mem_iff.mpr hs, hinf⟩

/-- Every stem actually present in the prompt makes its class fire. The
introduction rule, kept separate because it is what the corpus rows use. -/
theorem fires_of_mem {p s : Text} {stems : List Text}
    (hs : s ∈ stems) (hinf : s <:+: p) : fires p stems := ⟨s, hs, hinf⟩

/-! ## From stem classes to a lane

The chain itself is `RotRoute.route`; mirrored here over the *predicate* form so
the two ends can be joined without importing a `Flags` record that this file
would then have to keep in step. `Mode` is re-declared minimally for that reason
and its ORDER is the contract, exactly as in `RotRoute`. -/

-- The lanes, in the router's priority order.
inductive Mode where
  | forge | clinical | executive | empathic | strategic
  | creative | predictive | stealth | recursive | convergent
deriving DecidableEq, Repr

-- The nine stem classes a prompt is tested against, in priority order.
structure Vocab where
  forge : List Text
  clinical : List Text
  executive : List Text
  empathic : List Text
  strategic : List Text
  creative : List Text
  predictive : List Text
  stealth : List Text
  recursive : List Text

-- The router, as a function of the prompt TEXT and the vocabulary.
noncomputable def routeText (v : Vocab) (p : Text) : Mode :=
  open Classical in
  if fires p v.forge then .forge
  else if fires p v.clinical then .clinical
  else if fires p v.executive then .executive
  else if fires p v.empathic then .empathic
  else if fires p v.strategic then .strategic
  else if fires p v.creative then .creative
  else if fires p v.predictive then .predictive
  else if fires p v.stealth then .stealth
  else if fires p v.recursive then .recursive
  else .convergent

/-- **A prompt containing no stem of any class routes to `convergent`.**

The default lane is reached only by exhaustion -- it is never a fallback the
router takes early. -/
theorem routeText_convergent_of_none {v : Vocab} {p : Text}
    (h : ¬ fires p v.forge ∧ ¬ fires p v.clinical ∧ ¬ fires p v.executive ∧
         ¬ fires p v.empathic ∧ ¬ fires p v.strategic ∧ ¬ fires p v.creative ∧
         ¬ fires p v.predictive ∧ ¬ fires p v.stealth ∧ ¬ fires p v.recursive) :
    routeText v p = .convergent := by
  obtain ⟨h1, h2, h3, h4, h5, h6, h7, h8, h9⟩ := h
  unfold routeText
  simp [h1, h2, h3, h4, h5, h6, h7, h8, h9]

/-- **FORGE first, in its durable form.** If the FORGE class fires, the lane is
FORGE whatever every other class does. -/
theorem routeText_forge {v : Vocab} {p : Text} (h : fires p v.forge) :
    routeText v p = .forge := by
  unfold routeText; simp [h]

/-- **Extending a lower-priority class cannot steal a FORGE prompt.**

This is the invariant a future vocabulary edit is most likely to violate, and it
is stated over an ARBITRARY replacement of the other eight classes -- so it
holds for every such edit, not merely for today's word lists. -/
theorem routeText_forge_stable {v w : Vocab} {p : Text}
    (hv : v.forge = w.forge)
    (hfire : fires p v.forge) : routeText w p = .forge := by
  exact routeText_forge (hv ▸ hfire)

/-- **The lane always corresponds to a class that fired** (or is the default).

The totality statement with content: a router returning a lane whose class never
fired would break this, while the vacuous "every prompt yields a lane" is true of
a constant function. -/
theorem routeText_sound (v : Vocab) (p : Text) :
    routeText v p = .convergent ∨
      (routeText v p = .forge ∧ fires p v.forge) ∨
      (routeText v p = .clinical ∧ fires p v.clinical) ∨
      (routeText v p = .executive ∧ fires p v.executive) ∨
      (routeText v p = .empathic ∧ fires p v.empathic) ∨
      (routeText v p = .strategic ∧ fires p v.strategic) ∨
      (routeText v p = .creative ∧ fires p v.creative) ∨
      (routeText v p = .predictive ∧ fires p v.predictive) ∨
      (routeText v p = .stealth ∧ fires p v.stealth) ∨
      (routeText v p = .recursive ∧ fires p v.recursive) := by
  unfold routeText
  by_cases h1 : fires p v.forge
  · simp [h1]
  by_cases h2 : fires p v.clinical
  · simp [h1, h2]
  by_cases h3 : fires p v.executive
  · simp [h1, h2, h3]
  by_cases h4 : fires p v.empathic
  · simp [h1, h2, h3, h4]
  by_cases h5 : fires p v.strategic
  · simp [h1, h2, h3, h4, h5]
  by_cases h6 : fires p v.creative
  · simp [h1, h2, h3, h4, h5, h6]
  by_cases h7 : fires p v.predictive
  · simp [h1, h2, h3, h4, h5, h6, h7]
  by_cases h8 : fires p v.stealth
  · simp [h1, h2, h3, h4, h5, h6, h7, h8]
  by_cases h9 : fires p v.recursive
  · simp [h1, h2, h3, h4, h5, h6, h7, h8, h9]
  · simp [h1, h2, h3, h4, h5, h6, h7, h8, h9]

/-! ## Executable checks

The statements above are about arbitrary vocabularies. These `#guard`s pin the
MATCHING ITSELF to concrete text, so a definition that typechecks but does not
mean "substring" cannot hide behind them. They are deliberately `example`/
`#guard` and not theorems: they are about specific strings and would be dated if
any of them were load-bearing. -/

-- "lake" occurs in "lake build the theorem".
example : fires "lake build the theorem".toList ["lake".toList, "mathlib".toList] := by decide

-- The same prompt does not contain a compression stem.
example : ¬ fires "lake build the theorem".toList ["compress".toList, "token".toList] := by decide

-- Matching is on substrings, not whole words: "build" occurs inside "rebuild".
example : fires "rebuild it".toList ["build".toList] := by decide

-- The empty class swallows nothing, executably.
example : ¬ fires "anything at all".toList [] := by decide

end RotMoE.Stem
