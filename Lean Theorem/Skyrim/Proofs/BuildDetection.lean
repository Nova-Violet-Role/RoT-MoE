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
# Why a location-based build detector cannot work

A real defect, measured in the Skyrim SE AutoCombat build on 2026-08-13.

`scripts/58-verify-bodyslide.ps1` was written to answer "did BodySlide actually run?". Its
first version searched for built body meshes while **excluding** the CBBE and HIMBO mod
folders, reasoning that meshes found there must be the stock ones those mods ship.

The Socio then ran BodySlide correctly - `CBBE Fetish v2` and `HIMBO Hideo`, morphs ticked -
and the script reported `BODYSLIDE-MISSING`. Mod Organizer writes a modified virtual file
back into the mod that **owns** it, so a correct build lands exactly inside the two excluded
folders. The alarm fired at correct behaviour, and the obvious response would have been to
redo work that was already done.

This file proves the defect is not a mis-tuned exclusion list but a property of the
*approach*: **no** location-based detector with a non-empty exclusion can be sound, and the
content-based replacement is exactly right on every input.

## Boundary

This models the detector's decision procedure, not PowerShell and not MO2's virtual file
system. That MO2 writes back into the owning mod is a measured fact
(`...\47 - Caliente's...\meshes\...\femalebody_1.nif`, mtime 2026-08-12 22:12:59, against
stock textures from 2017-09-25), not something proved here.
-/

namespace Skyrim.BuildDetection

/-- Where a mesh can sit. `overwrite` is MO2's overwrite folder; the other two are the mod
folders that own the stock meshes. -/
inductive Loc
  | overwrite
  | cbbeMod
  | himboMod
  deriving DecidableEq, Repr

/-- Whether a mesh is what the mod shipped, or something BodySlide generated. -/
inductive Content
  | stock
  | built
  deriving DecidableEq, Repr

/-- A mesh on disk: somewhere, with some content. -/
structure Mesh where
  loc : Loc
  content : Content
  deriving DecidableEq, Repr

/-- The question actually being asked: did BodySlide generate anything? -/
def built (fs : List Mesh) : Bool := fs.any (fun m => m.content == Content.built)

/-- The broken detector: "a mesh exists somewhere I am willing to look". -/
def detectByLocation (excluded : List Loc) (fs : List Mesh) : Bool :=
  fs.any (fun m => !(excluded.contains m.loc))

/-- The repaired detector: "some mesh differs from what the mod shipped". -/
def detectByContent (fs : List Mesh) : Bool := fs.any (fun m => m.content == Content.built)

-- The exact situation on disk when the false alarm fired: both bodies rebuilt, and both
-- sitting inside the mod folders the old detector refused to look at.
--
-- Contents are factored out so a single edit can flip the WHOLE state to stock. With the
-- two meshes written inline, mutating one of them left the other built and
-- `observed_was_built` survived - the mutation was too weak to test the theorem, which is
-- a defect in the harness rather than evidence about the proof.
def observedContents : List Content := [Content.built, Content.built]

def observedLocs : List Loc := [Loc.cbbeMod, Loc.himboMod]

def observed : List Mesh :=
  (observedLocs.zip observedContents).map (fun p => { loc := p.1, content := p.2 })

#guard built observed == true
#guard detectByLocation [Loc.cbbeMod, Loc.himboMod] observed == false
#guard detectByContent observed == true

/-- The build had happened. -/
theorem observed_was_built : built observed = true := by decide

/-- The old detector said it had not. This is the false red the Socio received. -/
theorem old_detector_missed_it :
    detectByLocation [Loc.cbbeMod, Loc.himboMod] observed = false := by decide

/-- The repaired detector agrees with the truth on **every** input, not just this one.
`built` and `detectByContent` are the same function, which is the point: the check asks the
question directly instead of inferring it from where a file happens to live. -/
theorem content_detector_is_exact (fs : List Mesh) : detectByContent fs = built fs := rfl

/-- The general result. For **any** exclusion list that excludes **any** location, there is
a disk state that was built and that the detector calls missing.

This is deliberately quantified over the exclusion list rather than stated about the two
folders that happened to be excluded on 2026-08-13. A theorem pinned to those two would go
green again the moment someone edited the list, while the defect survived. -/
theorem location_detector_always_unsound (excluded : List Loc) (l : Loc)
    (hl : excluded.contains l = true) :
    ∃ fs, built fs = true ∧ detectByLocation excluded fs = false := by
  refine ⟨[{ loc := l, content := Content.built }], rfl, ?_⟩
  have hmem : l ∈ excluded := by simpa using hl
  simp [detectByLocation, hmem]

/-- The mirror failure, and the more dangerous one: a location-based detector reports a
build for a mesh it merely *found*, even if that mesh is untouched stock content. So the
approach can also hand out a false green. -/
theorem location_detector_can_false_green (excluded : List Loc) (l : Loc)
    (hl : excluded.contains l = false) :
    ∃ fs, built fs = false ∧ detectByLocation excluded fs = true := by
  refine ⟨[{ loc := l, content := Content.stock }], rfl, ?_⟩
  have hmem : l ∉ excluded := by simpa using hl
  simp [detectByLocation, hmem]

/-- Only the empty exclusion list makes the location detector agree with the truth on the
single-built-mesh states, and even then it is agreeing by accident - `content_detector_is_exact`
is the honest instrument. Stated to stop anyone "fixing" the old detector by shrinking its
exclusion list. -/
theorem shrinking_the_exclusion_list_is_not_a_fix (excluded : List Loc)
    (h : ∀ fs, detectByLocation excluded fs = built fs) : False := by
  -- Either `overwrite` is excluded or it is not, and each case is already a proved defect:
  -- excluded gives a false red, not excluded gives a false green. No exclusion list escapes
  -- both.
  by_cases hc : excluded.contains Loc.overwrite = true
  · obtain ⟨fs, hb, hd⟩ := location_detector_always_unsound excluded Loc.overwrite hc
    rw [h fs, hb] at hd
    exact Bool.noConfusion hd
  · have hc' : excluded.contains Loc.overwrite = false := by simpa using hc
    obtain ⟨fs, hb, hd⟩ := location_detector_can_false_green excluded Loc.overwrite hc'
    rw [h fs, hb] at hd
    exact Bool.noConfusion hd

#print axioms observed_was_built
#print axioms old_detector_missed_it
#print axioms content_detector_is_exact
#print axioms location_detector_always_unsound
#print axioms location_detector_can_false_green
#print axioms shrinking_the_exclusion_list_is_not_a_fix

end Skyrim.BuildDetection
