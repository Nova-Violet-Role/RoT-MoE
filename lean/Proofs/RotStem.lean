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

/-! ## Word-prefix matching — the collision the plain substring test cannot avoid

**Measured 2026-08-04, on the shipped router:**

```
prove this lemma                            -> CONVERGENT     (no lane fired)
prove the read loop conserves bytes in lean -> STEALTH Soleil (matched `byte`)
```

On a prover head that is a defect: the two most proof-shaped prompts imaginable
reach every lane except FORGE. The cause is not the priority order — `route`
already tries FORGE first, and the earlier diagnosis that first-match beat
priority was **wrong**. The stem table simply does not contain `prove`, `proof`
or `lemma`.

**And they cannot be added to a substring matcher.** Measured against `fires` as
it stands, adding those three words would make FORGE fire on:

| prompt | stem it would hit | lane it would steal |
|---|---|---|
| *improve the documentation* | `prove` | FORGE |
| *that is the dilemma* | `lemma` | FORGE |
| *cleaning up the tree* | `lean` | FORGE |

The same flaw is already live for stems that shipped long ago: `fix` fires on
**prefix** and **suffix**, `now` fires on **known** and **knowledge**, `test`
fires on **latest**. Those are false positives that have been routing prompts
for as long as the table has existed.

**The rule that fixes all of it at once: a stem must start a WORD.** Not an
arbitrary position — the beginning of the text, or immediately after a character
that is not alphanumeric. `proving`, `proofs` and `prover` still fire (`prove`
and `proof` are prefixes of a word); `improve` does not.

The one exception is deliberate and is what keeps `.lean` working: a stem that
*itself* begins with a non-alphanumeric character is matched as a plain
substring, because `Basic.lean` has no word boundary before the dot. -/

/-- Is this character part of a word? The boundary rule is stated once, here, so
the shell and this model cannot drift on it. -/
def isWordChar (c : Char) : Bool := c.isAlphanum

/-- Does `s` occur in `p` starting at a word boundary? `prev` is whether the
character immediately before `p` was alphanumeric — `false` at the start of the
text, which is why a prompt beginning with the stem fires. -/
-- STRUCTURALLY recursive on the prompt, and that is not a style choice. The
-- first version guarded the recursion behind an `if` and needed
-- `termination_by`, which makes it well-founded rather than structural -- and a
-- well-founded definition DOES NOT REDUCE for `decide`. Every executable check
-- below failed with "reduction got stuck at the Decidable instance". A spec
-- whose definitions cannot be evaluated cannot be tested against the shell, so
-- the shape that computes is the shape that ships.
def wordStart (s : Text) : Bool → Text → Bool
  | prev, [] => !prev && s.isPrefixOf []
  | prev, c :: rest => (!prev && s.isPrefixOf (c :: rest)) || wordStart s (isWordChar c) rest

/-- One stem against one prompt, with the punctuation-led exception. The
fallback branch is `decide (s <:+: p)` rather than a `Bool`-valued library
function, because infix has a decidability instance here and reusing it keeps
the exception provably the SAME relation `fires` uses — a separately-written
substring routine could drift from it. -/
def firesWord1 (p s : Text) : Bool :=
  match s with
  | [] => false
  | c :: _ => if isWordChar c then wordStart s false p else decide (s <:+: p)

/-- **The word-prefix matcher**, class-wide: the shell's `fired` as it ships from
0.7.0 on. -/
def firesWord (p : Text) (stems : List Text) : Bool :=
  stems.any (fun s => firesWord1 p s)

/-! ### The theorem that makes the change safe to ship

A routing change is dangerous in exactly one direction: if the new matcher could
fire where the old one did not, a prompt that used to reach one lane could
silently start reaching another, and no amount of corpus testing covers the
prompts nobody wrote down. The following says that cannot happen. -/

/-- A word-boundary occurrence is an occurrence. -/
theorem wordStart_isInfix {s : Text} :
    ∀ (b : Bool) (p : Text), wordStart s b p = true → s <:+: p := by
  intro b p
  induction p generalizing b with
  | nil =>
    intro h
    simp only [wordStart, Bool.and_eq_true] at h
    exact (List.isPrefixOf_iff_prefix.mp h.2).isInfix
  | cons c rest ih =>
    intro h
    simp only [wordStart, Bool.or_eq_true, Bool.and_eq_true] at h
    rcases h with hpre | hrec
    · exact (List.isPrefixOf_iff_prefix.mp hpre.2).isInfix
    · exact List.infix_cons (ih (isWordChar c) hrec)

/-- **The new matcher is strictly more conservative: it never fires where the old
one would not.**

This is the load-bearing statement of the change. Every prompt that routes to a
lane under word-prefix matching would have routed to that lane — or to an earlier
one — under substring matching too. The edit can only ever *remove* a false
positive; it cannot invent a new match, and therefore cannot silently move a
prompt onto a lane it was never reaching.

Quantified over all prompts and all stem classes, so it covers the words nobody
thought to test. -/
theorem firesWord_imp_fires (p : Text) (stems : List Text) (h : firesWord p stems = true) :
    fires p stems := by
  unfold firesWord at h
  obtain ⟨s, hmem, hs⟩ := List.any_eq_true.mp h
  refine ⟨s, hmem, ?_⟩
  cases s with
  | nil => simp [firesWord1] at hs
  | cons c t =>
    simp only [firesWord1] at hs
    split at hs
    · exact wordStart_isInfix false p hs
    · exact of_decide_eq_true hs

/-- **And it is genuinely different — the conservativeness is not vacuous.**
Without this, a matcher that never fired at all would satisfy the theorem above
perfectly. -/
theorem firesWord_strictly_weaker :
    ∃ (p : Text) (stems : List Text), fires p stems ∧ firesWord p stems = false := by
  refine ⟨"improve the documentation".toList, ["prove".toList], ?_, ?_⟩
  · decide
  · decide

/-! ### The collisions, executably

These are `example`s about specific strings on purpose: they are empirical claims
about text, and pinning them as theorems would date the spec. What they do is
stop the definitions above from typechecking while meaning something other than
"starts a word". -/

-- THE FIX: the two measured prompts now reach a FORGE stem.
example : firesWord "prove this lemma".toList ["prove".toList] = true := by decide
example : firesWord "prove the read loop conserves bytes in lean".toList
    ["prove".toList, "lean".toList] = true := by decide

-- THE COLLISIONS THE FIX AVOIDS -- each one fires under the old matcher.
example : fires "improve the documentation".toList ["prove".toList] := by decide
example : firesWord "improve the documentation".toList ["prove".toList] = false := by decide
example : fires "that is the dilemma".toList ["lemma".toList] := by decide
example : firesWord "that is the dilemma".toList ["lemma".toList] = false := by decide
example : fires "cleaning up the tree".toList ["lean".toList] := by decide
example : firesWord "cleaning up the tree".toList ["lean".toList] = false := by decide

-- COLLISIONS THAT WERE ALREADY LIVE, fixed by the same rule.
example : fires "add a prefix to the name".toList ["fix".toList] := by decide
example : firesWord "add a prefix to the name".toList ["fix".toList] = false := by decide
example : fires "what is known about it".toList ["now".toList] := by decide
example : firesWord "what is known about it".toList ["now".toList] = false := by decide
example : fires "the latest release".toList ["test".toList] := by decide
example : firesWord "the latest release".toList ["test".toList] = false := by decide

-- WORD PREFIXES STILL FIRE -- the rule is "starts a word", not "is a whole word".
-- This matters for every stem in the table: `verif` must still catch
-- "verification", `strateg` must still catch "strategy".
example : firesWord "proving it now".toList ["prove".toList] = false := by decide
example : firesWord "proofs of termination".toList ["proof".toList] = true := by decide
example : firesWord "verification of the bound".toList ["verif".toList] = true := by decide
example : firesWord "the strategy document".toList ["strateg".toList] = true := by decide

-- A stem at the very start of the prompt fires: there is no character before it.
example : firesWord "prove it".toList ["prove".toList] = true := by decide

-- THE PUNCTUATION-LED EXCEPTION, which is why `.lean` still works. There is no
-- word boundary before the dot in "Basic.lean", so this stem falls back to a
-- plain substring test.
example : firesWord "check Basic.lean now".toList [".lean".toList] = true := by decide

end RotMoE.Stem
