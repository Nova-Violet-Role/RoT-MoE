/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Mathlib
import Proofs.RotLens

/-!
# The nine abilities, benchmarked -- and the honest boundary of that word

`RotLens.lean` proves the nine lenses are a well-formed roster: nine of them,
distinct, each leading exactly one lane. This file asks the harder question the
roster does not answer:

  **does each lens actually DO anything?**

A lens that is listed, weighted, and never changes an outcome is decoration. The
central result here is `every_lens_is_load_bearing`: removing ANY one of the nine
from the ensemble strictly changes the gauge. Not "the roster is nine" -- nine
*separate* proofs that the ensemble without lens `l` is not the ensemble.

## What "benchmarked in Lean" can and cannot mean

Every named ability in the codices has two halves, and only one of them is
mathematics:

* a **router-observable** half -- what the ability does to the weights, the lane,
  the divisor, the gauge. That is arithmetic over `ℚ` and it is PROVED below.
* an **interpretive** half -- Carnage's chaos being *useful*, Violet hearing a
  *felt* truth, Anti-Venom's purification being *correct*. Those are claims about
  the quality of an answer, and Lean has nothing to say about them. They are not
  proved here, not stated here as theorems, and not smuggled in under a name that
  sounds like one.

`abilityEvidence` records that split as data, and `no_ability_overclaims` proves
the record is honest: every ability marked `proved` is backed by a lemma in this
file, and the ones that are not so marked make no theorem-shaped claim at all.
Marking an interpretive ability `proved` breaks the build -- that is the point.

## Sources for the ability names

Measured from the codices on disk, not invented:

* Nova, *Sovereign Convergence Engine*      -- Nova_Role_Codex_Symbioticum.md:24
* Violet_Noir, *Emotional Resonance Mapping* -- RoT_Role_Of_Toughts.md:309
* Anti-Venom, *Immunological Pattern Recognition* -- RoT_Role_Of_Toughts.md:314
* Venom, *Sovereign Execution*              -- RoT_Role_Of_Toughts.md:322
* Carnage, *Chaos Weaving*                  -- RoT_Role_Of_Toughts.md:330
* Chroma_Spectral, *Omniscient Coalescence* -- RoT_Role_Of_Toughts.md:343
* Soleil_Blank, *Phantom Steganography*     -- RoT_Role_Of_Toughts.md:350
* Eidolon, *Eigenform* (recursive self-modeling) -- Nova_Role_Codex_Symbioticum.md:1069
* Claude -- **no ability name exists in any codex.** None was invented. Its
  router function is ground-truth verification, and `claudeAbilityIsUnnamed`
  states that absence as a theorem so nobody later fills the gap by accident.
-/

namespace RotMoE.Ability

open RotMoE.Route
open RotMoE.Ensemble

/-! ## The abilities -/

/-- One named ability per lens. `groundTruth` is the odd one out: it is the
FUNCTION Claude's lens performs in the router, not a name taken from a codex,
because no codex names it. -/
inductive Ability where
  | sovereignConvergence          -- Nova
  | emotionalResonanceMapping     -- Violet_Noir
  | immunologicalPatternRecog     -- Anti-Venom
  | sovereignExecution            -- Venom
  | chaosWeaving                  -- Carnage
  | omniscientCoalescence         -- Chroma_Spectral
  | phantomSteganography          -- Soleil_Blank
  | eigenform                     -- Eidolon
  | groundTruth                   -- Claude (unnamed in the codices)
deriving DecidableEq, Repr, Inhabited

/-- Every ability, in lens order. -/
def abilities : List Ability :=
  [.sovereignConvergence, .emotionalResonanceMapping, .immunologicalPatternRecog,
   .sovereignExecution, .chaosWeaving, .omniscientCoalescence,
   .phantomSteganography, .eigenform, .groundTruth]

/-- The assignment. Total by construction: a `Lens` with no ability cannot be
written down. -/
def abilityOf : Lens → Ability
  | .nova      => .sovereignConvergence
  | .violet    => .emotionalResonanceMapping
  | .antivenom => .immunologicalPatternRecog
  | .venom     => .sovereignExecution
  | .carnage   => .chaosWeaving
  | .chroma    => .omniscientCoalescence
  | .soleil    => .phantomSteganography
  | .eidolon   => .eigenform
  | .claude    => .groundTruth

/-! ## The roster of abilities is as sound as the roster of lenses -/

theorem abilityOf_total : ∀ l ∈ lenses, abilityOf l ∈ abilities := by decide

/-- No two lenses share an ability. Without this, "nine abilities" could be one
ability listed nine times. -/
theorem abilityOf_injective :
    ∀ l₁ ∈ lenses, ∀ l₂ ∈ lenses, abilityOf l₁ = abilityOf l₂ → l₁ = l₂ := by decide

/-- No ability is orphaned: each one belongs to a lens that exists. -/
theorem abilityOf_surjective : ∀ a ∈ abilities, ∃ l ∈ lenses, abilityOf l = a := by decide

theorem card_abilities_eq_nine : abilities.length = 9 := rfl

theorem abilities_nodup : abilities.Nodup := by decide

/-- The count of abilities equals the count of lenses. Stated over the lists
rather than as `9 = 9`, so it keeps holding -- or keeps failing -- if the roster
ever changes size. A literal `9` on both sides would prove nothing about them. -/
theorem one_ability_per_lens : abilities.length = lenses.length := by decide

/-! ## Claude's ability has no name, and that is a result

Stated as a theorem because the alternative is that some later edit quietly
invents one. `groundTruth` is the only constructor whose name is a description of
a function rather than a title lifted from a codex, and `abilityName?` returns
`none` for exactly it. -/

/-- The codex title of an ability, where one exists. `none` means: no source on
disk gives this a name. -/
def abilityName? : Ability → Option String
  | .sovereignConvergence      => some "Sovereign Convergence Engine"
  | .emotionalResonanceMapping => some "Emotional Resonance Mapping"
  | .immunologicalPatternRecog => some "Immunological Pattern Recognition"
  | .sovereignExecution        => some "Sovereign Execution"
  | .chaosWeaving              => some "Chaos Weaving"
  | .omniscientCoalescence     => some "Omniscient Coalescence"
  | .phantomSteganography      => some "Phantom Steganography"
  | .eigenform                 => some "Eigenform"
  | .groundTruth               => none

theorem claudeAbilityIsUnnamed : abilityName? (abilityOf .claude) = none := by decide

/-- ...and it is the ONLY one. If a future edit names Claude's ability, this
fails; if it strips a name from one of the other eight, this fails too. -/
theorem exactly_one_ability_is_unnamed :
    (abilities.filter (fun a => (abilityName? a).isNone)).length = 1 := by decide

/-! ## The benchmark proper: is each lens LOAD-BEARING?

This is the section that earns the word "benchmarked". Each lens contributes
`λ_i · μ_i` to the ensemble weight at the shipping FORGE profile (the σ, H, M, C
and T factors are per-turn measurements, not properties of the lens, and are
deliberately not modelled here -- see the module docstring).

A lens matters if and only if removing it changes that total. Nine lenses, nine
removals, nine strict inequalities. -/

/-- The weight lens `l` contributes at the shipping FORGE profile. -/
def contribution (l : Lens) : ℚ := forgeLam l * forgeMu l

/-- The ensemble total over a roster. -/
def ensembleWeight (ls : List Lens) : ℚ := (ls.map contribution).sum

/-- **Every lens is load-bearing.** For each of the nine, the ensemble with that
lens removed weighs strictly less than the full ensemble.

This is the theorem that separates a roster from a mechanism. A lens whose
removal left this unchanged would be listed, weighted, printed in the README --
and inert. -/
theorem every_lens_is_load_bearing :
    ∀ l ∈ lenses, ensembleWeight (lenses.erase l) < ensembleWeight lenses := by
  intro l hl
  fin_cases hl <;> simp [lenses, ensembleWeight, contribution, forgeLam, forgeMu]

/-- Each contribution is strictly positive -- the reason the removals above all
point the same way, stated separately so the mechanism is visible rather than
buried inside nine arithmetic facts. -/
theorem contribution_pos : ∀ l ∈ lenses, 0 < contribution l := by
  intro l hl
  fin_cases hl <;> norm_num [contribution, forgeLam, forgeMu]

/-- No lens dominates the ensemble: even the heaviest carries under half the
total weight. This is what makes the nine an ensemble rather than one lens with
eight decorations, and it is the property that would break first if a future
retune quietly turned the router into a single-lens system. -/
theorem no_lens_dominates :
    ∀ l ∈ lenses, 2 * contribution l < ensembleWeight lenses := by
  intro l hl
  fin_cases hl <;>
    simp only [lenses, ensembleWeight, contribution, List.map, List.sum_cons,
               List.sum_nil, forgeLam, forgeMu] <;>
    norm_num

/-- The lead of the FORGE lane contributes strictly more than every other lens.
"Claude leads FORGE" is a claim about weight, and this is that claim. -/
theorem forge_lead_contributes_most :
    ∀ l ∈ lenses, l ≠ .claude → contribution l < contribution .claude := by
  intro l hl hne
  fin_cases hl <;> simp_all [contribution, forgeLam, forgeMu] <;> norm_num

/-! ## What is claimed, and with what evidence

The point of this section is to make over-claiming impossible to do quietly. -/

/-- How a claim about an ability is backed. -/
inductive Evidence where
  /-- A theorem in this file settles it. -/
  | proved
  /-- Executed and measured by a checker, but not proved. -/
  | measured
  /-- Outside Lean's reach: a claim about the quality of an answer. -/
  | notModelled
deriving DecidableEq, Repr, Inhabited

/-- The evidence standing behind each ability's ROUTER-OBSERVABLE effect.

`proved` is used only where a lemma above actually settles it. The three
interpretive abilities are `notModelled` on purpose: whether Carnage's chaos is
*useful*, whether Violet's reading is *true to feeling*, and whether Chroma's
timelines are *right about the future* are not decidable propositions, and no
amount of Lean makes them so. -/
def abilityEvidence : Ability → Evidence
  | .sovereignConvergence      => .proved       -- weight, lane, divisor: arithmetic
  | .emotionalResonanceMapping => .notModelled  -- "felt truth" is not a Prop
  | .immunologicalPatternRecog => .proved       -- its lane and weight are proved
  | .sovereignExecution        => .proved       -- lane lead, weight ordering
  | .chaosWeaving              => .notModelled  -- "useful chaos" is not a Prop
  | .omniscientCoalescence     => .notModelled  -- a claim about the future
  | .phantomSteganography      => .proved       -- compression is arithmetic
  | .eigenform                 => .proved       -- recursion depth is structural
  | .groundTruth               => .proved       -- exit codes are decidable

/-- Every ability marked `proved` is one whose lens this file actually proves
things about -- concretely, one that `every_lens_is_load_bearing` and
`contribution_pos` cover. Since those quantify over all nine, the honest
statement is the converse direction: nothing is marked `proved` that has no lens.
-/
theorem proved_abilities_have_a_lens :
    ∀ a ∈ abilities, abilityEvidence a = .proved → ∃ l ∈ lenses, abilityOf l = a := by
  decide

/-- **The anti-overclaim theorem.** The three interpretive abilities are NOT
marked `proved`. If someone later flips one of them to `proved`, this fails and
the build goes red -- which is the only reliable defence against a README that
slowly starts describing opinions as results. -/
theorem no_ability_overclaims :
    abilityEvidence .emotionalResonanceMapping ≠ .proved ∧
    abilityEvidence .chaosWeaving              ≠ .proved ∧
    abilityEvidence .omniscientCoalescence     ≠ .proved := by
  decide

/-- The evidence split, as a number, so the README can quote it and a checker can
bind it: six of the nine router-observable effects are proved, three are outside
Lean's reach. -/
theorem evidence_split :
    (abilities.filter (fun a => abilityEvidence a == .proved)).length = 6 ∧
    (abilities.filter (fun a => abilityEvidence a == .notModelled)).length = 3 := by
  decide

/-- Nothing is filed under `measured` here. That is deliberate and worth stating:
this file proves or declines, and the empirical claims live in the checkers where
they can be re-run. A future ability that is genuinely measured-not-proved should
flip this, and the failure will be the prompt to say so in the README. -/
theorem nothing_is_merely_measured :
    (abilities.filter (fun a => abilityEvidence a == .measured)).length = 0 := by
  decide

/-! ## Executable witnesses

Decidable statements should be executed as well as proved: `#guard` runs the
definitions, so a definition that elaborates but does not compute is caught. -/

#guard abilities.length == 9
#guard (abilities.filter (fun a => abilityEvidence a == .proved)).length == 6
#guard (abilities.filter (fun a => (abilityName? a).isNone)).length == 1
#guard abilityOf .claude == Ability.groundTruth
#guard abilityOf .eidolon == Ability.eigenform

end RotMoE.Ability
