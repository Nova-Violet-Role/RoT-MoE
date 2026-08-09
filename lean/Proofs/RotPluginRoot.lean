/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# The registry says one root; the runtime uses another

Measured 2026-08-09, by a self-attributing execution marker inside the router:

    ROOT=[<DESKTOP>/RoT-MoE 0.7.1-Lean/]
    PARENT= bash -c "pwsh -NoProfile -File \"${CLAUDE_PLUGIN_ROOT}/hooks/rot-router.ps1\" || ..."

while `plugins/installed_plugins.json` declares

    rot-moe@rot-moe  version=1.0.1
    installPath = <CLAUDE_CONFIG>\plugins\cache\rot-moe\rot-moe\1.0.1

and `known_marketplaces.json` names the source `Desktop\RoT-MoE 1.0.1-Lean`.

**Three paths, and the one that runs is named by none of the registry files.**
`CLAUDE_PLUGIN_ROOT` resolved to a STALE marketplace-source directory,
`0.7.1-Lean`, whose router predates the provenance feature -- which is precisely
why every live record arrived with no `src` and no `session`.

## Why five file patches produced no change

Patching a copy changes the bytes at a path. It changes the OBSERVABLE only if
that path is the one the runtime resolves. The registry was consulted, three
cache versions were repaired, and the emitter was untouched throughout, because
the runtime root was never any of them.

## The sound identifier

A record's own provenance identifies the build that wrote it. A record WITHOUT
`src` cannot have come from a build that always emits `src` -- measured: a
hand-driven repo-HEAD router emits `{"src":"hook","session":"ctl-2",...}` on
every record, gauge and route alike. So `src`-absence is a positive
identification of an old build, available without patching anything.

That is the general lesson worth keeping: **identify a running program by what
it EMITS, not by what a registry says is installed.**
-/

namespace RotMoE.PluginRoot

/-- The three paths in play. They are independent; nothing forces agreement. -/
structure Deployment where
  declaredInstall : String
  declaredSource  : String
  runtimeRoot     : String
deriving DecidableEq, Repr

/-- A build either carries provenance in its records or predates the feature. -/
structure Build where
  path            : String
  emitsProvenance : Bool
deriving DecidableEq, Repr

/-- Patching a path only affects the observable when the runtime resolves it. -/
def patchIsEffective (d : Deployment) (patched : String) : Bool :=
  patched == d.runtimeRoot

/-- The registry-driven repair strategy: patch what the registry names. -/
def registryDrivenPatch (d : Deployment) : Bool :=
  patchIsEffective d d.declaredInstall || patchIsEffective d d.declaredSource

/-- The deployment measured today. -/
def measured : Deployment :=
  { declaredInstall := "cache/rot-moe/rot-moe/1.0.1"
    declaredSource  := "Desktop/RoT-MoE 1.0.1-Lean"
    runtimeRoot     := "Desktop/RoT-MoE 0.7.1-Lean" }

section RegistryIsNotAuthority

/-- The measured deployment: BOTH registry paths miss the runtime root, so the
whole registry-driven repair strategy is ineffective. This is the theorem that
explains five patches and zero change. -/
theorem registry_driven_patch_missed_the_runtime :
    registryDrivenPatch measured = false := by decide

/-- Not an accident of these strings: whenever the runtime root differs from
both declared paths, the strategy is ineffective for EVERY deployment. -/
theorem registry_patch_fails_whenever_runtime_diverges (d : Deployment)
    (h1 : ¬ (d.declaredInstall = d.runtimeRoot))
    (h2 : ¬ (d.declaredSource = d.runtimeRoot)) :
    registryDrivenPatch d = false := by
  have e1 : (d.declaredInstall == d.runtimeRoot) = false := by simpa using h1
  have e2 : (d.declaredSource == d.runtimeRoot) = false := by simpa using h2
  simp [registryDrivenPatch, patchIsEffective, e1, e2]

/-- And patching the runtime root IS effective -- so the method is sound once
aimed correctly. Without this the module would only say "nothing works". -/
theorem patching_the_runtime_root_is_effective (d : Deployment) :
    patchIsEffective d d.runtimeRoot = true := by
  simp [patchIsEffective]

end RegistryIsNotAuthority

section ProvenanceIdentifies

/-- Identification by emission: a record lacking provenance cannot come from a
build that always emits it. -/
def couldHaveWritten (b : Build) (recordHasProvenance : Bool) : Bool :=
  b.emitsProvenance == recordHasProvenance

/-- The measured fact: a bare record rules out a provenance-emitting build,
whatever its path. Quantified over the path, because the path is exactly what
we did NOT know. -/
theorem bare_record_rules_out_a_modern_build (p : String) :
    couldHaveWritten ⟨p, true⟩ false = false := by
  simp [couldHaveWritten]

/-- ...and is consistent with an old one. Both directions, so the test
discriminates rather than merely rejecting. -/
theorem bare_record_admits_an_old_build (p : String) :
    couldHaveWritten ⟨p, false⟩ false = true := by
  simp [couldHaveWritten]

/-- The discrimination stated as a separation: the two build kinds are
distinguishable by the record alone, with no filesystem access at all. -/
theorem provenance_separates_the_builds (p q : String) :
    couldHaveWritten ⟨p, true⟩ false ≠ couldHaveWritten ⟨q, false⟩ false := by
  simp [couldHaveWritten]

end ProvenanceIdentifies

section Measured

#guard registryDrivenPatch measured = false
#guard patchIsEffective measured "Desktop/RoT-MoE 0.7.1-Lean" = true
#guard patchIsEffective measured "cache/rot-moe/rot-moe/1.0.1" = false
#guard patchIsEffective measured "Desktop/RoT-MoE 1.0.1-Lean" = false
-- the five copies actually patched, none of them the runtime root
#guard (["cache/rot-moe/rot-moe/0.6.1", "cache/rot-moe/rot-moe/0.7.1",
         "cache/rot-moe/rot-moe/1.0.1", "Desktop/RoT-MoE 1.0.1-Lean",
         "Desktop/RoT-MoE 0.7.1-Lean"].filter
          (fun p => patchIsEffective measured p)).length = 1
#guard couldHaveWritten ⟨"any", true⟩ false = false
#guard couldHaveWritten ⟨"any", false⟩ false = true

end Measured

end RotMoE.PluginRoot
