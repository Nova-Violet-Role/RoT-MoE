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
# Mod Organizer 2 file-conflict resolution, and the demotion fix

On 2026-08-12 a real defect was found in the Skyrim SE AutoCombat build: `Total Character
Makeover` sat ABOVE `CBBE` and `HIMBO` in `modlist.txt`, so it won **63 contested files** -
including meshes BodySlide had just built into the body mods' folders. The repair moved TCM
below both body mods, and the repair script measured the effect: `63/63` files won by TCM
before, `0/63` after.

That measurement is a fact about **63 files on one machine on one day**. It is not a reason
to believe the rule. This module states and proves the rule itself, quantified over an
arbitrary priority list and an arbitrary "does this mod provide the file" predicate, so it
stays true for any future mod list rather than freezing today's arrangement.

The model is deliberately small, because the thing worth proving is small:

* MO2 resolves a contested file to the **first** mod in priority order that provides it -
  `modlist.txt` is highest-priority-first (measured: `+62B ...` on line 37 sits above its
  parent `+62 ...` on line 38).
* So the resolver is exactly `List.find?`.

Nothing here claims anything about *textures*, *meshes*, or *why blue renders blue*. It
claims one thing: **a mod placed after some provider of a file cannot win that file.**
-/

namespace Skyrim.ModPriority

/-- A mod, identified by its MO2 folder name. -/
abbrev Mod := String

/--
The winner of a contested file: the first mod in priority order that provides it.

`order` is `modlist.txt` read top to bottom, i.e. highest priority first. `provides m` is
"mod `m` ships this particular file".
-/
def winner (order : List Mod) (provides : Mod → Bool) : Option Mod :=
  order.find? provides

/-- A winner really does provide the file - the resolver never invents a mod. -/
theorem winner_provides {order : List Mod} {p : Mod → Bool} {m : Mod}
    (h : winner order p = some m) : p m = true :=
  List.find?_some h

/-- A winner is one of the mods in the load order. -/
theorem winner_mem {order : List Mod} {p : Mod → Bool} {m : Mod}
    (h : winner order p = some m) : m ∈ order :=
  List.mem_of_find?_eq_some h

/-- If nobody provides the file, there is no winner (it resolves from a BSA instead). -/
theorem winner_none_iff {order : List Mod} {p : Mod → Bool} :
    winner order p = none ↔ ∀ m ∈ order, p m = false := by
  unfold winner
  rw [List.find?_eq_none]
  constructor
  · intro h m hm
    simpa using h m hm
  · intro h m hm
    simp [h m hm]

/--
**The load-bearing theorem.** A mod that sits *after* some provider of a file never wins
that file.

This is the general form of "TCM lost all 63 contested files". It says nothing about TCM,
CBBE, or the number 63: for any priority list split as `pre ++ demoted :: post`, if
anything in `pre` provides the file, the winner is not `demoted`.

The `demoted ∉ pre` hypothesis is not bureaucracy - without it the same mod could also
appear earlier in the list and legitimately win there.
-/
theorem demoted_never_wins {p : Mod → Bool} {pre post : List Mod} {demoted b : Mod}
    (hnot : demoted ∉ pre) (hb : b ∈ pre) (hp : p b = true) :
    winner (pre ++ demoted :: post) p ≠ some demoted := by
  unfold winner
  rw [List.find?_append]
  cases hf : pre.find? p with
  | none =>
      rw [List.find?_eq_none] at hf
      exact absurd hp (by simpa using hf b hb)
  | some x =>
      simp only [Option.some_or]
      intro h
      exact hnot ((Option.some.inj h) ▸ List.mem_of_find?_eq_some hf)

/--
The winner in that situation is in fact drawn from `pre` - the stronger statement, and the
one that says the body mod actually gets the file rather than merely "not TCM".
-/
theorem winner_from_pre {p : Mod → Bool} {pre post : List Mod} {demoted b : Mod}
    (hb : b ∈ pre) (hp : p b = true) :
    ∃ w, winner (pre ++ demoted :: post) p = some w ∧ w ∈ pre := by
  unfold winner
  rw [List.find?_append]
  cases hf : pre.find? p with
  | none =>
      rw [List.find?_eq_none] at hf
      exact absurd hp (by simpa using hf b hb)
  | some x =>
      exact ⟨x, by simp, List.mem_of_find?_eq_some hf⟩

/--
**The fix, stated over every contested file at once.**

`contested f` means: the demoted mod provides `f`, and so does something ahead of it. The
conclusion is that the demoted mod wins none of them - the universal form of the measured
`0/63`.
-/
theorem demotion_clears_all_contested
    (pre post : List Mod) (demoted : Mod) (hnot : demoted ∉ pre)
    (File : Type) (provides : File → Mod → Bool)
    (contested : File → Prop)
    (hcontested : ∀ f, contested f → ∃ b ∈ pre, provides f b = true) :
    ∀ f, contested f → winner (pre ++ demoted :: post) (provides f) ≠ some demoted := by
  intro f hf
  obtain ⟨b, hb, hp⟩ := hcontested f hf
  exact demoted_never_wins hnot hb hp

/-! ### Executing the model on the case that was actually measured

`#guard` runs the definitions. If `winner` did not mean what the prose says it means, these
would fail at build time rather than sitting in a comment being wrong.
-/

/-- The order as it stood BEFORE the fix (modlist.txt lines 53, 54, 56). -/
def orderBefore : List Mod := ["50 - TCM", "49 - HIMBO", "47 - CBBE"]

/-- The order AFTER `41-fix-body-priority.ps1` demoted TCM below both body mods. -/
def orderAfter : List Mod := ["49 - HIMBO", "47 - CBBE", "50 - TCM"]

/-- `femalehands_1.nif`: shipped by both CBBE and TCM - one of the measured 63. -/
def providesFemaleHands : Mod → Bool := fun m => m == "50 - TCM" || m == "47 - CBBE"

/-- `malefeet_1.nif`: shipped by both HIMBO and TCM. -/
def providesMaleFeet : Mod → Bool := fun m => m == "50 - TCM" || m == "49 - HIMBO"

/-- `femalehead_msn.dds` for a race TCM alone covers - TCM should still win this one. -/
def providesRaceNormal : Mod → Bool := fun m => m == "50 - TCM"

-- The defect, reproduced. This is an `example`/`#guard`, never a hypothesis anything rests
-- on: it documents a state the build has already left behind.
#guard winner orderBefore providesFemaleHands = some "50 - TCM"
#guard winner orderBefore providesMaleFeet    = some "50 - TCM"

-- The fix.
#guard winner orderAfter providesFemaleHands = some "47 - CBBE"
#guard winner orderAfter providesMaleFeet    = some "49 - HIMBO"

-- And the part that makes the fix safe rather than merely different: demoting TCM does NOT
-- take away the files it alone provides.
#guard winner orderAfter providesRaceNormal = some "50 - TCM"

/-- The measured 63-file outcome, as an instance of the general theorem. -/
example : winner (["49 - HIMBO", "47 - CBBE"] ++ "50 - TCM" :: []) providesFemaleHands
    ≠ some "50 - TCM" :=
  demoted_never_wins (by decide) (b := "47 - CBBE") (by decide) (by decide)

end Skyrim.ModPriority
