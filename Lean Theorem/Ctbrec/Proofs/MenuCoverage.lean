/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — a capability the app has and half its UI cannot reach

Subject: `src/app/ctbrec/ui/menu/ModelMenuContributor.java:95` (`contributeToMenu`, the shared
menu builder), `src/app/ctbrec/ui/tabs/ThumbOverviewTab.java:543,601` (the PiP opener and the
bespoke menu item), and the seven surfaces that list models.

**Measured**: picture-in-picture preview is offered from exactly one place —
`ThumbOverviewTab`, which builds its own `MenuItem` after calling the shared contributor.

```
MyFreeCamsTableTab   pip=0   inlinePreview=0
RecentlyWatchedTab   pip=0   inlinePreview=0
ThumbOverviewTab     pip=6   inlinePreview=0
```

Seven surfaces call `contributeToMenu`; six of them therefore list models with **no way to open a
preview at all**. The capability exists, is proved (`PreviewPipeline`), ships in the jar, and is
unreachable from most of the UI. Same seam as the 60 FPS preset lookup: not a missing feature, a
missing wire.

## Why this module exists rather than a one-line patch

The obvious repair — add the item to the shared contributor — gives `ThumbOverviewTab` the item
**twice**, because it calls the contributor *and* adds its own. That defect is invisible in a
diff and obvious in a model, which is the whole argument for writing the model first.

So two properties are proved here, and they pull against each other: **every model-listing
surface offers the preview**, and **no surface offers it more than once**. Satisfying either one
alone is easy; satisfying both forces the design that was actually implemented — the item moves
into the contributor and the bespoke copy is deleted.
-/

namespace CtbrecSpec

/-- A place in the UI that lists models and can raise a context menu. -/
structure Surface where
  /-- Identifier, for readable counterexamples. -/
  name : String
  /-- Does it list models at all? A surface that lists none needs no preview action. -/
  listsModels : Bool
  /-- Does it build its menu through `ModelMenuContributor.contributeToMenu`? -/
  usesContributor : Bool
  /-- Does it add a picture-in-picture item of its own? -/
  ownPip : Bool
  deriving DecidableEq, Repr

/-- Whether the shared contributor offers the item. This is the single bit the repair flips. -/
abbrev ContributorOffersPip := Bool

/-- A surface offers the preview if it builds one itself, or inherits one from the contributor. -/
def offersPip (c : ContributorOffersPip) (s : Surface) : Bool :=
  s.ownPip || (s.usesContributor && c)

/-- How many times the item appears in the menu. The number the naive repair gets wrong. -/
def pipCount (c : ContributorOffersPip) (s : Surface) : Nat :=
  (if s.ownPip then 1 else 0) + (if s.usesContributor && c then 1 else 0)

/-- The seven surfaces that call `contributeToMenu`, measured from the tree. `ThumbOverviewTab`
is the only one that also builds its own item. -/
def surfacesBefore : List Surface :=
  [ ⟨"SearchPopoverTreeList", true, true, false⟩,
    ⟨"MyFreeCamsTableTab", true, true, false⟩,
    ⟨"RecentlyWatchedTab", true, true, false⟩,
    ⟨"AbstractRecordedModelsTab", true, true, false⟩,
    ⟨"GroupsTab", true, true, false⟩,
    ⟨"RecordingsTab", true, true, false⟩,
    ⟨"ThumbOverviewTab", true, true, true⟩ ]

/-- After the repair: the item lives in the contributor, and the bespoke copy is gone. -/
def surfacesAfter : List Surface :=
  surfacesBefore.map (fun s => { s with ownPip := false })

/-- The naive repair: turn the contributor on and change nothing else. -/
def surfacesNaive : List Surface := surfacesBefore

/-- **The defect.** With the contributor silent, six of the seven surfaces list models and offer
no preview. -/
theorem six_surfaces_could_not_reach_the_preview :
    (surfacesBefore.filter (fun s => s.listsModels && !offersPip false s)).length = 6 := by
  decide

/-- **After the repair every model-listing surface offers it.** Stated over the list, so a surface
added later without the wire fails this rather than slipping through. -/
theorem every_listing_surface_offers_the_preview :
    surfacesAfter.all (fun s => !s.listsModels || offersPip true s) = true := by decide

/-- **And none offers it twice.** This is the theorem the naive repair fails. -/
theorem no_surface_offers_it_twice :
    surfacesAfter.all (fun s => pipCount true s ≤ 1) = true := by decide

/-- **The naive repair is caught**: leaving the bespoke item in place while switching the
contributor on gives `ThumbOverviewTab` two identical entries. Named so the failure is legible
if anyone re-adds the local copy. -/
theorem the_naive_repair_duplicates_the_item :
    (surfacesNaive.filter (fun s => pipCount true s > 1)).length = 1 := by decide

/-- Both properties at once — the pair that forces the design. Neither alone does. -/
theorem coverage_and_uniqueness_hold_together :
    surfacesAfter.all (fun s => (!s.listsModels || offersPip true s) && pipCount true s ≤ 1)
      = true := by decide

/-- **Anti-amputation.** `offersPip` is not constantly true: with the contributor off and no
bespoke item, a surface offers nothing. Without this, `fun _ _ => true` would satisfy the
coverage theorem. -/
theorem the_predicate_is_not_trivially_true :
    offersPip false ⟨"probe", true, true, false⟩ = false := by decide

/-- **The other direction.** It is not constantly false either. -/
theorem the_predicate_is_not_trivially_false :
    offersPip true ⟨"probe", true, true, false⟩ = true := by decide

/-- A surface that lists no models is not required to offer the action — the coverage claim is
about model-listing surfaces, and this pins that it is not a vacuous universal. -/
theorem a_surface_that_lists_nothing_is_exempt :
    (!(⟨"empty", false, false, false⟩ : Surface).listsModels
      || offersPip true ⟨"empty", false, false, false⟩) = true := by decide

/-- The repair changes exactly one thing about each surface: where the item comes from, never
whether the surface lists models. A repair that silently stopped a tab listing models would
satisfy coverage by amputation, and this forbids it. -/
theorem the_repair_does_not_change_what_is_listed :
    (surfacesAfter.map (fun s => s.listsModels)) = (surfacesBefore.map (fun s => s.listsModels)) := by
  decide

/-- The count is preserved: seven surfaces before, seven after. -/
theorem no_surface_was_dropped : surfacesAfter.length = surfacesBefore.length := by decide

#guard (surfacesBefore.filter (fun s => s.listsModels && !offersPip false s)).length == 6
#guard surfacesAfter.all (fun s => offersPip true s) == true
#guard surfacesAfter.all (fun s => pipCount true s ≤ 1) == true
#guard (surfacesNaive.filter (fun s => pipCount true s > 1)).length == 1
#guard offersPip false ⟨"probe", true, true, false⟩ == false
#guard surfacesBefore.length == 7
#guard (surfacesBefore.filter (fun s => s.ownPip)).length == 1
#guard (surfacesAfter.filter (fun s => s.ownPip)).length == 0

end CtbrecSpec
