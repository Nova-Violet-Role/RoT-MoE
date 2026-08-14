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
# The FOMOD-wrapper trap: a mod that is installed and inert

A real defect, measured in the Skyrim SE AutoCombat build on 2026-08-12 while installing
Spell Perk Item Distributor (Nexus 36869) as a missing requirement of Nether's Follower
Framework.

Mod Organizer 2 maps a mod folder's ROOT onto the game's `Data` directory, and the game
loads an SKSE plugin only from `Data\SKSE\Plugins\*.dll`. SPID ships as a FOMOD, so the
extracted archive looks like

    SE\SKSE\Plugins\po3_SpellPerkItemDistributor.dll
    AE\SKSE\Plugins\po3_SpellPerkItemDistributor.dll
    fomod\ModuleConfig.xml

Copied verbatim into a mod folder, every file is present, the mod is enabled, the mod list
is green - and **nothing loads**, because no file lands at `SKSE\Plugins`. That is the
dangerous shape: not a crash, not an error, just a dependency that silently is not there.
`56-fix-spid-fomod.ps1` flattens the `SE` branch to the mod root.

This file models the mapping and proves:

* `fomod_layout_is_inert` - the defect. The layout as extracted loads **nothing**.
* `flatten_loads` - the repair. After flattening, the DLL loads.
* `flatten_picks_se` - the repair keeps the *SE* binary and discards the AE one. On runtime
  1.5.97 the wrong branch is worse than no branch: it loads and then misbehaves.
* `present_ne_loaded` - the general lesson, for an arbitrary layout: a file being present in
  a mod is strictly weaker than that file being loaded. This is what makes "but all the
  files are there" not a defence.
* `active_iff` - being active is decided by the file paths and by nothing else.

Path components are an inductive type rather than `String`. That is a deliberate modelling
choice with a measured reason: with `String` components the kernel cannot reduce
`String.decEq` inside `flatten`, `decide` gets stuck (`reduction got stuck at the
Decidable instance`), and none of the concrete statements below would be executable. With a
derived `DecidableEq` every theorem here closes by `decide` and every `#guard` really runs.
-/

namespace PluginPath

/-- One component of a path inside a mod folder. Only the components that occur in the
layouts actually measured on disk are modelled; `other` stands for anything else. -/
inductive Comp where
  | SE | AE | fomod | data
  | skse | plugins
  | dllSpidSE | dllSpidAE | dllMfg | dllSrd
  | xmlModuleConfig | txtReadme
  | other
  deriving DecidableEq, Repr

open Comp

/-- A path inside a mod folder, as its components. -/
abbrev Path := List Comp

/-- A mod folder: the list of file paths it contains. -/
abbrev Layout := List Path

/-- Which components name a `.dll`. -/
def isDll : Comp → Bool
  | dllSpidSE => true
  | dllSpidAE => true
  | dllMfg  => true
  | dllSrd  => true
  | _       => false

/-- The game loads an SKSE plugin from exactly `Data\SKSE\Plugins\<name>.dll`, and MO2 maps
a mod's root onto `Data`. So a path loads iff it is `SKSE / Plugins / something.dll`. -/
def loads : Path → Bool
  | [c₁, c₂, f] => c₁ == skse && c₂ == plugins && isDll f
  | _ => false

/-- Everything in a layout that the game will actually load. -/
def loaded (l : Layout) : Layout := l.filter loads

/-- Whether a layout contributes any plugin at all. -/
def active (l : Layout) : Bool := !(loaded l).isEmpty

/-- Drop one leading directory component, keeping only the paths that had it. This is
exactly what "flatten the SE branch to the mod root" does. -/
def flatten (dir : Comp) : Layout → Layout
  | [] => []
  | p :: rest =>
      match p with
      | d :: tl => if d = dir then tl :: flatten dir rest else flatten dir rest
      | [] => flatten dir rest

/-! ### The layouts that were measured on disk -/

/-- SPID as extracted from its FOMOD archive. -/
def fomodLayout : Layout :=
  [ [SE, skse, plugins, dllSpidSE],
    [AE, skse, plugins, dllSpidAE],
    [fomod, xmlModuleConfig] ]

/-- The same mod after `56-fix-spid-fomod.ps1`. -/
def fixedLayout : Layout := [ [skse, plugins, dllSpidSE] ]

/-! ### The defect -/

/-- Nothing in the FOMOD layout is loaded: every path is one component too deep. The mod is
installed, enabled, complete on disk, and contributes nothing. -/
theorem fomod_layout_is_inert : loaded fomodLayout = [] := by decide

/-- Said the way the symptom presents. -/
theorem fomod_layout_inactive : active fomodLayout = false := by decide

/-- The general form: a four-component path never loads, whatever its components are. A
wrapper directory of any name puts every file one level too deep, so this covers the next
FOMOD with different branch names as well as this one. -/
theorem wrapped_never_loads (a b c d : Comp) : loads [a, b, c, d] = false := by
  simp [loads]

/-! ### The repair -/

/-- Flattening the `SE` branch makes the plugin load. -/
theorem flatten_loads : loaded (flatten SE fomodLayout) = fixedLayout := by decide

/-- And the result is active, which `fomodLayout` was not. -/
theorem flatten_activates : active (flatten SE fomodLayout) = true := by decide

/-- The repair keeps the **SE** binary and discards the AE one. On runtime 1.5.97 loading
the AE branch would be worse than loading nothing, so this is the load-bearing half of the
fix rather than a detail of it. -/
theorem flatten_picks_se :
    flatten SE fomodLayout = fixedLayout ∧ flatten AE fomodLayout ≠ flatten SE fomodLayout :=
  ⟨by decide, by decide⟩

/-- Flattening a directory that is not there yields nothing, so the script cannot silently
"succeed" against an archive whose layout changed. -/
theorem flatten_absent_is_empty : flatten data fomodLayout = [] := by decide

/-! ### The lesson, in general form -/

/-- Membership in a layout does not imply being loaded. This is the statement that makes
"but all the files are present" not a defence. -/
theorem present_ne_loaded : ∃ (l : Layout) (p : Path), p ∈ l ∧ p ∉ loaded l := by
  refine ⟨fomodLayout, [fomod, xmlModuleConfig], by decide, ?_⟩
  simp [fomod_layout_is_inert]

/-- Conversely, anything loaded really was present: `loaded` only ever filters. So the
asymmetry above is the only one there is. -/
theorem loaded_subset (l : Layout) (p : Path) (h : p ∈ loaded l) : p ∈ l :=
  (List.mem_filter.mp h).1

/-- A layout is active exactly when it holds at least one path the game will load, so
"is this mod doing anything" is decided by the file paths and by nothing else. -/
theorem active_iff (l : Layout) : active l = true ↔ ∃ p ∈ l, loads p = true := by
  constructor
  · intro h
    have hne : loaded l ≠ [] := by
      simpa [active, List.isEmpty_iff] using h
    match hm : loaded l with
    | [] => exact absurd hm hne
    | q :: qs =>
        have hq : q ∈ loaded l := by simp [hm]
        exact ⟨q, (List.mem_filter.mp hq).1, (List.mem_filter.mp hq).2⟩
  · rintro ⟨p, hp, hl⟩
    have hmem : p ∈ loaded l := List.mem_filter.mpr ⟨hp, hl⟩
    have hne : loaded l ≠ [] := by
      intro hcontra
      simp [hcontra] at hmem
    simpa [active, List.isEmpty_iff] using hne

/-! ### Pinning the real files

Measured in `MO2\mods\13B - Spell Perk Item Distributor` before and after
`scripts\56-fix-spid-fomod.ps1`. -/

-- before: complete on disk, and loading nothing
#guard loaded fomodLayout == []
#guard active fomodLayout == false

-- after: exactly the SE plugin, at the only path the game reads
#guard flatten SE fomodLayout == fixedLayout
#guard active (flatten SE fomodLayout) == true

-- the two branches are not interchangeable
#guard flatten AE fomodLayout != flatten SE fomodLayout

-- the other two new mods of this round were installed flat already
#guard active [[skse, plugins, dllMfg]] == true
#guard active [[skse, plugins, dllSrd]] == true

-- a plugin one level too deep, the shape of the bug, in each direction
#guard active [[data, skse, plugins, dllMfg]] == false
#guard active [[skse, dllMfg]] == false
#guard active [[skse, plugins, txtReadme]] == false

end PluginPath
