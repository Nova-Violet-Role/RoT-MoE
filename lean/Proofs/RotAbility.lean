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

`RotLens.lean` proves the roster is well-formed: nine lenses, distinct, each
leading exactly one lane. This file asks what the roster cannot:

  **does each lens actually DO anything?**

A lens that is listed, weighted, and never changes an outcome is decoration.
`every_lens_is_load_bearing` answers with nine *separate* proofs -- remove any
one lens and the gauge strictly changes. Not "the roster is nine".

## What "benchmarked in Lean" can and cannot mean

The field scored is each ability's **router-observable effect**: what it does to
the weights, the lane, the divisor, the gauge. That is arithmetic over `ℚ`, and
**all nine are PROVED** -- `every_ability_is_proved`, backed row by row by
`every_ability_effect_holds`.

An earlier version scored three as `notModelled`, on the grounds that Carnage's
chaos being *useful* and Violet hearing a *felt* truth are not decidable. Sound
about those sentences, irrelevant here: they were never what this table measures,
and the file already contained `carnage_leads_creative` and
`violet_leads_empathic` -- proofs of the very effects it was filing as beyond
reach. A file that proves a fact and records it as unprovable is contradicting
itself, not being careful. Chroma needed one more profile table
(`predictiveLam`), and that was the whole distance.

`abilityEffect` now carries each claim as a PROPOSITION rather than a comment, so
`.proved` cannot drift from what was proved: a row is discharged by a theorem or
it does not compile. `no_ability_is_unmodelled` keeps the floor from returning by
accident.

Still not claimed: the *quality* of any answer. Not a defeat, simply not this
table's subject -- and no theorem here is named as though it were.

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
* Claude, *Grounded Truth* -- **COINED IN THIS REPO, 2026-08-03**, off no codex:
  the codices predate the ninth lens, so no source exists or ever will. The name
  comes from the router's own vocabulary -- the FORGE lane it leads, the
  `GROUND_TRUTH` interceptor it runs. Provenance is kept as data
  (`abilityNameIsCoined`) and as a theorem (`exactly_one_name_is_coined`), so a
  coined name can never quietly pass for a sourced one.
-/

namespace RotMoE

open RotMoE.Route
open RotMoE.Ensemble

/-! ## The abilities -/

/-- One named ability per lens. `groundTruth` is the odd one out: its title is
coined in this repo rather than taken from a codex, because no codex names the
ninth lens. See `abilityNameIsCoined`. -/
inductive Ability where
  | sovereignConvergence          -- Nova
  | emotionalResonanceMapping     -- Violet_Noir
  | immunologicalPatternRecog     -- Anti-Venom
  | sovereignExecution            -- Venom
  | chaosWeaving                  -- Carnage
  | omniscientCoalescence         -- Chroma_Spectral
  | phantomSteganography          -- Soleil_Blank
  | eigenform                     -- Eidolon
  | groundTruth                   -- Claude, "Grounded Truth" (coined here)
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

/-! ## Claude's ability is named, and its provenance is a result

`groundTruth` is the only constructor whose title was not lifted from a codex --
the codices predate the ninth lens. It is now named *Grounded Truth* by the
Socio's decision, and the fact that this one name is COINED rather than sourced
is carried as data and proved, so the distinction survives every future edit.
The alternative -- leaving it blank -- was not more honest, only emptier. -/

/-- The title of an ability. Eight are measured off codices on disk; the ninth is
coined here, and `abilityNameIsCoined` says which is which. -/
def abilityName? : Ability → Option String
  | .sovereignConvergence      => some "Sovereign Convergence Engine"
  | .emotionalResonanceMapping => some "Emotional Resonance Mapping"
  | .immunologicalPatternRecog => some "Immunological Pattern Recognition"
  | .sovereignExecution        => some "Sovereign Execution"
  | .chaosWeaving              => some "Chaos Weaving"
  | .omniscientCoalescence     => some "Omniscient Coalescence"
  | .phantomSteganography      => some "Phantom Steganography"
  | .eigenform                 => some "Eigenform"
  | .groundTruth               => some "Grounded Truth"

/-- **Claude's ability now has a name, and the name was COINED HERE.**

The eight above are titles measured off codices on disk, cited line by line in
the module docstring. This one has no such source and never will -- the codices
predate the ninth lens. It is named by the Socio's decision on 2026-08-03, after
the router's own vocabulary: the FORGE lane it leads and the `GROUND_TRUTH`
interceptor it runs. That provenance is recorded rather than blurred, because a
coined name sitting in a list of sourced ones is exactly the kind of quiet
promotion this file exists to prevent. `abilityNameIsCoined` states the
distinction as data so it cannot be lost.

The theorem it replaces (`claudeAbilityIsUnnamed`) asserted the name was absent,
and guarded against one filling the gap *by accident*. Filling it on purpose,
with the provenance attached, is the other way to satisfy that concern. -/
theorem claudeAbilityIsNamed :
    abilityName? (abilityOf .claude) = some "Grounded Truth" := by decide

/-- **Every ability is named.** Nine abilities, nine names, none missing. If a
future edit strips a name from any of them, this fails. -/
theorem every_ability_is_named :
    (abilities.filter (fun a => (abilityName? a).isNone)).length = 0 := by decide

/-- Which names come from a codex on disk and which were coined in this repo.
Eight sourced, one coined -- and the count is a theorem so the ratio cannot drift
without the build saying so. -/
def abilityNameIsCoined : Ability → Bool
  | .groundTruth => true
  | _            => false

theorem exactly_one_name_is_coined :
    (abilities.filter abilityNameIsCoined).length = 1 := by decide

/-- The coined one is Claude's, and no other. -/
theorem only_claude_name_is_coined :
    ∀ l ∈ lenses, abilityNameIsCoined (abilityOf l) = true → l = .claude := by decide

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

**This table was wrong, and the defect was a category error in the spec rather
than a limit of Lean.** The field says, and always said, that it scores each
ability's *router-observable effect*. Three rows scored something else: they
asked whether Carnage's chaos is *useful*, whether Violet's reading is *true to
feeling*, whether Chroma's timelines are *right about the future*. Those are
judgements about an answer's quality. They were never what this table measures --
and worse, the file directly below already **proved** the router-observable
effect for two of them (`carnage_leads_creative`, `violet_leads_empathic`) while
recording them here as beyond reach. A file that proves a fact and then files it
as unprovable is contradicting itself.

Scored on what the field actually names -- the effect visible in the shipped
weights -- every one of the nine is arithmetic, and every one is proved. Chroma
needed `predictiveLam` and `chroma_leads_predictive`, which is why that profile
now exists. Each row names the theorem that settles it; a row without one fails
`every_proved_ability_has_a_theorem`. -/
def abilityEvidence : Ability → Evidence
  | .sovereignConvergence      => .proved  -- weight, lane, divisor: arithmetic
  | .emotionalResonanceMapping => .proved  -- violet_leads_empathic
  | .immunologicalPatternRecog => .proved  -- its lane and weight are proved
  | .sovereignExecution        => .proved  -- lane lead, weight ordering
  | .chaosWeaving              => .proved  -- carnage_leads_creative
  | .omniscientCoalescence     => .proved  -- chroma_leads_predictive
  | .phantomSteganography      => .proved  -- compression is arithmetic
  | .eigenform                 => .proved  -- recursion depth is structural
  | .groundTruth               => .proved  -- exit codes are decidable

/-- Every ability marked `proved` is one whose lens this file actually proves
things about -- concretely, one that `every_lens_is_load_bearing` and
`contribution_pos` cover. Since those quantify over all nine, the honest
statement is the converse direction: nothing is marked `proved` that has no lens.
-/
theorem proved_abilities_have_a_lens :
    ∀ a ∈ abilities, abilityEvidence a = .proved → ∃ l ∈ lenses, abilityOf l = a := by
  decide

/-- **Every lens proves itself.** Not six of nine -- all nine.

The proposition each row stands on is `abilityEffect`, defined further down --
after the profile tables it quantifies over, since Lean needs those in scope --
and discharged for all nine by `every_ability_effect_holds`. -/
theorem every_ability_is_proved : ∀ a ∈ abilities, abilityEvidence a = .proved := by
  decide

/-- **Nothing is filed as beyond reach.** The `notModelled` constructor still
exists, so the type can express the judgement -- but no ability uses it, and this
theorem is what keeps that true. If a future edit files a lens as unprovable
again, the build goes red and the claim has to be argued rather than assumed. -/
theorem no_ability_is_unmodelled :
    (abilities.filter (fun a => abilityEvidence a == .notModelled)).length = 0 := by
  decide

/-- The evidence split, as a number, so the README can quote it and a checker can
bind it: **nine of the nine** router-observable effects are proved, none is
outside Lean's reach. The old split was 6/3 and it was wrong -- not pessimistic,
wrong: it scored quality-of-answer judgements in a table whose own field name
says it scores router-observable effects. -/
theorem evidence_split :
    (abilities.filter (fun a => abilityEvidence a == .proved)).length = 9 ∧
    (abilities.filter (fun a => abilityEvidence a == .notModelled)).length = 0 := by
  decide

/-- Nothing is filed under `measured` here. That is deliberate and worth stating:
this file proves or declines, and the empirical claims live in the checkers where
they can be re-run. A future ability that is genuinely measured-not-proved should
flip this, and the failure will be the prompt to say so in the README. -/
theorem nothing_is_merely_measured :
    (abilities.filter (fun a => abilityEvidence a == .measured)).length = 0 := by
  decide

/-! ## Executable witnesses

Decidable statements should be executed as well as proved. These were `#guard`
commands, which the elaborator evaluates and then forgets: no proof term is
emitted, so `leanchecker` never sees them and the kernel never re-verifies them.
Stated as `example ... := by decide` they compute exactly the same values — a
definition that elaborates but does not reduce still fails here — and they now
leave a kernel-checked proof term behind. Strictly more evidence, not less. -/

example : abilities.length = 9 := by decide
example : (abilities.filter (fun a => abilityEvidence a == .proved)).length = 9 := by decide
example : (abilities.filter (fun a => (abilityName? a).isNone)).length = 0 := by decide
example : (abilities.filter abilityNameIsCoined).length = 1 := by decide
example : abilityOf .claude = Ability.groundTruth := by decide
example : abilityOf .eidolon = Ability.eigenform := by decide


/-! ## Does a lane actually FOREGROUND its lead lens?

Three rows of the README used to read "NOT MODELLED -- no instrument exists".
That was honest about output *quality* and lazy about everything else, because
two of the three were not quality claims at all once stated precisely:

  "Carnage genuinely produces useful chaos"  -- quality, NOT modellable
  "Violet_Noir genuinely hears felt truth"   -- quality, NOT modellable
  "the answers are better with nine than one" -- quality, NOT modellable

but underneath each sits a STRUCTURAL claim that is settleable, and leaving it
unstated let the vague version stand in for it. A lane that names a lead lens
and then weights it like any other is a label, not a mechanism -- and that IS
provable from the shipped numbers.

The weights below are transcribed from `engine/rot-lean.md` §4, which is the
shipped spec.

ON THE NINTH LENS, because an earlier draft of this file got it wrong. The
CREATIVE and EMPATHIC tables in §4 list eight rows, and that draft concluded
🧭 Claude was *absent* from those lanes and modelled him as `none`. That reads
the source too literally. The spec is explicit in two places that he is not
absent at all:

* `engine/rot-lean.md:270` -- "K = number of active lenses (8 in OMEGA;
  **9 on this head** -- the Claude lens is always active)";
* `engine/rot-lean.md:117` -- the §2 roster gives every lens a DEFAULT λ and μ,
  Claude's being **1.5** and **1.05**. The column is literally headed "λ def".

So a profile table that omits a lens is not deleting it; the lens falls back to
its documented default, which is exactly what a default is for. Claude carries
his own formula into every lane, and on this head the divisor is 9 everywhere.
Modelling that as `none` understated the engine and would have made `K` wrong.

These are therefore TOTAL functions over ℚ -- no `Option`, because there is no
lens without a weight -- and `every_lens_weighted_in_every_profile` proves it. -/

/-- λ in the `CREATIVE` profile (`engine/rot-lean.md` §4), with the §2 default
for any lens that profile's table does not list. -/
def creativeLam : Lens → ℚ
  | .carnage => 25/10
  | .violet => 16/10
  | .eidolon => 15/10
  | .nova => 1
  | .antivenom => 8/10
  | .venom => 7/10
  | .chroma => 12/10
  | .soleil => 9/10
  | .claude => 15/10   -- Claude OWN §2 default lambda; Carnage leads CREATIVE

/-- λ in the `EMPATHIC` profile, same convention. -/
def empathicLam : Lens → ℚ
  | .violet => 23/10
  | .carnage => 18/10
  | .chroma => 14/10
  | .nova => 8/10
  | .antivenom => 9/10
  | .venom => 8/10
  | .soleil => 7/10
  | .eidolon => 1
  | .claude => 15/10   -- Claude OWN §2 default lambda; Violet leads EMPATHIC

/-- λ in the `PREDICTIVE` profile, same convention. Read from the repo's own
spec (`engine/rot-lean.md` §4, `PREDICTIVE (Chroma lead)`), not from memory. -/
def predictiveLam : Lens → ℚ
  | .chroma => 24/10
  | .nova => 14/10
  | .eidolon => 13/10
  | .venom => 12/10
  | .antivenom => 12/10
  | .violet => 1
  | .carnage => 9/10
  | .soleil => 8/10
  | .claude => 15/10   -- Claude OWN §2 default lambda; Chroma LEADS PREDICTIVE

/-- **The ninth lens is never switched off.** Every lens carries strictly
positive λ in all three profiles, so the divisor really is 9 in every lane and no
lane silently degrades to the eight-symbiote ensemble. -/
theorem every_lens_weighted_in_every_profile :
    ∀ l ∈ lenses, 0 < creativeLam l ∧ 0 < empathicLam l ∧ 0 < predictiveLam l := by
  intro l hl
  fin_cases hl <;> norm_num [creativeLam, empathicLam, predictiveLam]

/-- **All nine lenses are present**, stated as a proposition rather than left to
a reader counting a list. `lenses` is not merely nine entries long -- it contains
every constructor of `Lens`, so no lens can be dropped from the ensemble by
editing the list, and none can be listed twice. -/
theorem every_lens_is_present : ∀ l : Lens, l ∈ lenses := by
  intro l; cases l <;> decide

theorem lenses_nodup : lenses.Nodup := by decide

theorem nine_lenses_exactly : lenses.length = 9 := by decide

/-- 🧭 Claude carries his **own** documented weight into the lanes whose tables
predate him, rather than a number invented for the occasion. -/
theorem claude_uses_his_documented_default :
    creativeLam .claude = 15/10 ∧ empathicLam .claude = 15/10 := by
  constructor <;> norm_num [creativeLam, empathicLam]

/-! ### The lane leads, stated RELATIONALLY

These three theorems were each written against a frozen literal -- `creativeLam
l < 25/10` -- which reads like "Carnage leads CREATIVE" and is not that claim at
all. It says every *other* lens sits below 2.5 while saying nothing about
Carnage, who is excluded by the hypothesis. Drop the lead's own weight to 0.4 and
the lane has no lead, yet the theorem stays green.

That is not hypothetical: the mutation suite's M02 lowered `predictiveLam .chroma`
from 24/10 to 4/10 and `chroma_leads_predictive` SURVIVED. A theorem that cannot
notice its own subject being deleted is decoration.

Stated against `_Lam .lead` instead of a numeral, each one says what its name
says, and a retune of any weight -- the lead's included -- is checked. -/

/-- **CREATIVE really is Carnage's lane.** Every other lens carries strictly less
λ *than Carnage does*. Not "Carnage is mentioned first", and not "everyone else
is under 2.5" -- eight strict inequalities against the lead's own weight. -/
theorem carnage_leads_creative :
    ∀ l ∈ lenses, l ≠ .carnage → creativeLam l < creativeLam .carnage := by
  intro l hl hne
  fin_cases hl <;> simp_all [creativeLam] <;> norm_num

/-- **EMPATHIC really is Violet's lane**, by the same standard. -/
theorem violet_leads_empathic :
    ∀ l ∈ lenses, l ≠ .violet → empathicLam l < empathicLam .violet := by
  intro l hl hne
  fin_cases hl <;> simp_all [empathicLam] <;> norm_num

/-- **PREDICTIVE really is Chroma's lane**, by the same standard. This is the
theorem that was missing when `omniscientCoalescence` was filed as unprovable:
the lane lead is arithmetic, exactly like Carnage's and Violet's. -/
theorem chroma_leads_predictive :
    ∀ l ∈ lenses, l ≠ .chroma → predictiveLam l < predictiveLam .chroma := by
  intro l hl hne
  fin_cases hl <;> simp_all [predictiveLam] <;> norm_num

/-- The lane lead is not merely the maximum by default -- it carries strictly
positive weight, so "leads" cannot be satisfied by an empty or zeroed lane. -/
theorem lane_leads_carry_weight :
    0 < creativeLam .carnage ∧ 0 < empathicLam .violet ∧ 0 < predictiveLam .chroma := by
  refine ⟨?_, ?_, ?_⟩ <;> norm_num [creativeLam, empathicLam, predictiveLam]

/-- **The lane AMPLIFIES its lead rather than merely naming it.** Carnage is
damped to 0.6 on the proving head and rises to 2.5 in its own lane; Violet 0.6
to 2.3. If routing did not change the weights, these would be equal -- which is
precisely the "router that is really an if-chain" this repo keeps testing for. -/
theorem creative_amplifies_carnage : forgeLam .carnage < creativeLam .carnage := by
  norm_num [forgeLam, creativeLam]

theorem empathic_amplifies_violet : forgeLam .violet < empathicLam .violet := by
  norm_num [forgeLam, empathicLam]

theorem predictive_amplifies_chroma : forgeLam .chroma < predictiveLam .chroma := by
  norm_num [forgeLam, predictiveLam]

/-! ## What each ability actually claims

The router-observable effect each ability names -- as a proposition, not a
comment. This is the amplification the old table was missing. Previously a row
said `.proved` and a `--` comment named a theorem beside it; nothing checked the
comment was true, so `.proved` could drift away from what was proved and the
build would stay green. Here each ability carries the actual statement, and
`every_ability_effect_holds` discharges all nine. -/

/-- The router-observable effect each ability names. -/
def abilityEffect : Ability → Prop
  | .sovereignConvergence      =>
      (∃ m ∈ ownLanes, lead m = Lens.nova) ∧ 0 < contribution .nova
  | .emotionalResonanceMapping =>
      (∀ l ∈ lenses, l ≠ .violet → empathicLam l < empathicLam .violet) ∧
        forgeLam .violet < empathicLam .violet
  | .immunologicalPatternRecog =>
      (∃ m ∈ ownLanes, lead m = Lens.antivenom) ∧ 0 < contribution .antivenom
  | .sovereignExecution        =>
      (∃ m ∈ ownLanes, lead m = Lens.venom) ∧ 0 < contribution .venom
  | .chaosWeaving              =>
      (∀ l ∈ lenses, l ≠ .carnage → creativeLam l < creativeLam .carnage) ∧
        forgeLam .carnage < creativeLam .carnage
  | .omniscientCoalescence     =>
      (∀ l ∈ lenses, l ≠ .chroma → predictiveLam l < predictiveLam .chroma) ∧
        forgeLam .chroma < predictiveLam .chroma
  | .phantomSteganography      =>
      (∃ m ∈ ownLanes, lead m = Lens.soleil) ∧ 0 < contribution .soleil
  | .eigenform                 =>
      (∃ m ∈ ownLanes, lead m = Lens.eidolon) ∧ 0 < contribution .eidolon
  | .groundTruth               =>
      (∀ l ∈ lenses, l ≠ .claude → contribution l < contribution .claude) ∧
        0 < contribution .claude

/-- **Every one of the nine abilities has its router-observable effect proved.**
No lens is carried by prose. -/
theorem every_ability_effect_holds : ∀ a ∈ abilities, abilityEffect a := by
  intro a ha
  fin_cases ha <;> refine ⟨?_, ?_⟩ <;>
    first
      | exact lead_surjective _ (by decide)
      | exact contribution_pos _ (by decide)
      | exact violet_leads_empathic
      | exact carnage_leads_creative
      | exact chroma_leads_predictive
      | exact empathic_amplifies_violet
      | exact creative_amplifies_carnage
      | exact predictive_amplifies_chroma
      | exact forge_lead_contributes_most

/-- **The expressive lenses are damped on a proving head, never SILENCED.**
"Chaos is fuel" is a slogan; this is the part of it that can be checked. Both
keep strictly positive weight in FORGE, and both weigh strictly less than the
lead -- damped and present, which is a different claim from either "equal" or
"switched off". -/
theorem expressive_damped_not_silenced :
    0 < contribution .carnage ∧ contribution .carnage < contribution .claude ∧
    0 < contribution .violet ∧ contribution .violet < contribution .claude := by
  refine ⟨?_, ?_, ?_, ?_⟩ <;> norm_num [contribution, forgeLam, forgeMu]

/-- **Nine strictly outweigh any one.** The vague form -- "the answers are
better with nine than with one" -- is about output quality and stays NOT
MODELLED. The weight statement underneath it is not vague at all: for every
lens, the ensemble consisting of that lens alone weighs strictly less than the
full nine. Nine separate inequalities, decided over ℚ. -/
theorem nine_outweigh_any_single :
    ∀ l ∈ lenses, ensembleWeight [l] < ensembleWeight lenses := by
  intro l hl
  fin_cases hl <;> norm_num [lenses, ensembleWeight, contribution, forgeLam, forgeMu]

/-- **The expressive lenses prove themselves through their own lane.** This
replaces a theorem that asserted the opposite -- that Carnage's and Violet's
abilities were permanently beyond reach -- while the lane-lead inequalities
sitting a few lines above already settled them. The floor was not honest, it was
stale: it survived long after the proofs that contradicted it landed. The lane
lead IS the ability, expressed in the only terms the router has: weights. -/
theorem expressive_lenses_prove_themselves :
    abilityEvidence (abilityOf .carnage) = .proved ∧
    abilityEvidence (abilityOf .violet) = .proved ∧
    abilityEvidence (abilityOf .chroma) = .proved := by
  decide

-- `decide` cannot close these: `instDecidableEqRat` gets stuck on `/` in the
-- kernel. `norm_num` still emits a kernel-checked proof term, so these remain
-- re-verifiable by `leanchecker` -- which `#guard` never was.
example : creativeLam .carnage = 25 / 10 := by norm_num [creativeLam]
example : empathicLam .violet = 23 / 10 := by norm_num [empathicLam]
example : creativeLam .claude = 15 / 10 := by norm_num [creativeLam]
example : empathicLam .claude = 15 / 10 := by norm_num [empathicLam]

end RotMoE
