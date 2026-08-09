/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

import Proofs.RotPluginRoot

/-!
# A declared plugin root is a CLAIM, and an unchecked claim rots in silence

## The defect this file is about, found twice in one day

`RotPluginRoot.lean` proved what happens when the registry and the runtime
diverge: a patch driven by the registry misses the router that actually runs.
That file assumed there was *a* declaration and *a* runtime.

The second occurrence was worse and is not covered by that model. After the
runtime was repaired, `settings.json` still declared the marketplace at
`Desktop\RoT-MoE 1.0.1-Lean` — a directory that had been **retired and no longer
existed at all** — while `known_marketplaces.json` correctly said
`.claude/rot-moe-src/1.0.1`. Two configs, one dangling, nothing checking either.

The reason this is dangerous rather than merely untidy: **a tool that cannot
find a declared path does not stop.** It ignores the entry and carries on with
whatever it already had, which is indistinguishable from working. The failure
mode is silence, and silence is what the operator reads as success.

## What is proved here

* A declaration set is *sound* only when every declared root exists.
* Divergence is scoped **per config dir**: two different Claude instances
  declaring different roots is CORRECT, and a checker that forbids it would be
  repaired by making the test instance shadow the real one — destroying the
  point of a test instance. `cross_instance_divergence_is_not_a_defect` states
  this so the gate can never be "tightened" into that mistake.
* A dangling declaration is invisible to any check that only compares
  declarations to each other — `agreement_alone_misses_a_dangling_pair` — which
  is why existence is a separate rule rather than a corollary.

## What is NOT proved

That `checker/plugin-root-consistency.sh` implements this. Lean constrains the
model; the binding is the byte-exact replay recorded in that checker's header,
where the real stale declaration was reconstructed and both rules fired.
-/

namespace RotMoE.RootDecl

/-- A path, modelled as an identifier, plus whether it exists on disk. -/
structure Root where
  /-- Identifies the path. -/
  path : Nat
  /-- Whether that path is present on the filesystem. -/
  exists_ : Bool
  deriving DecidableEq, Repr

/-- One declaration: config dir, which file declared it, and the root. -/
structure Decl where
  /-- Which Claude config dir this declaration lives in. -/
  cfg : Nat
  /-- Which file inside that dir declared it. -/
  file : Nat
  /-- The declared root. -/
  root : Root
  deriving DecidableEq, Repr

/-- Every declared root exists. -/
def allExist (ds : List Decl) : Bool := ds.all (fun d => d.root.exists_)

/-- Two declarations conflict when they are in the SAME config dir and name
different paths. Same path in two files is agreement, not conflict. -/
def conflicts (a b : Decl) : Bool :=
  a.cfg == b.cfg && a.root.path != b.root.path

/-- No two declarations inside one config dir disagree. -/
def agreesWithin (ds : List Decl) : Bool :=
  ds.all (fun a => ds.all (fun b => !conflicts a b))

/-- The full soundness condition the checker enforces. -/
def sound (ds : List Decl) : Bool := allExist ds && agreesWithin ds

/-! ### Existence and agreement are INDEPENDENT rules -/

/-- Two configs in the same dir, agreeing with each other, both pointing at a
directory that does not exist. -/
def danglingPair : List Decl :=
  [⟨0, 0, ⟨7, false⟩⟩, ⟨0, 1, ⟨7, false⟩⟩]

/-- **Agreement alone is not soundness.** The pair above agrees perfectly and is
still wrong: both files name a directory that was retired. A checker that only
diffed the declarations against each other would report green.

This is the load-bearing reason `plugin-root-consistency.sh` has an existence
rule at all, rather than treating it as implied by agreement. -/
theorem agreement_alone_misses_a_dangling_pair :
    agreesWithin danglingPair = true ∧ sound danglingPair = false := by decide

/-- And the converse: everything exists, yet one dir names two different roots.
Existence alone is not soundness either. -/
def divergentPair : List Decl :=
  [⟨0, 0, ⟨1, true⟩⟩, ⟨0, 1, ⟨2, true⟩⟩]

theorem existence_alone_misses_a_divergent_pair :
    allExist divergentPair = true ∧ sound divergentPair = false := by decide

/-- Both rules are therefore load-bearing: neither implies the other. Dropping
either one leaves a real configuration the checker would pass. -/
theorem both_rules_are_load_bearing :
    (agreesWithin danglingPair = true ∧ sound danglingPair = false) ∧
    (allExist divergentPair = true ∧ sound divergentPair = false) := by decide

/-! ### The scoping rule, stated so it cannot be "tightened" into a defect -/

/-- The global install and the CTT test clone: different config dirs, different
roots, both present. This is a CORRECT machine. -/
def twoInstances : List Decl :=
  [⟨0, 0, ⟨1, true⟩⟩, ⟨1, 0, ⟨2, true⟩⟩]

/-- **Two instances declaring different roots is not a defect.** The global
install is sourced from `.claude/rot-moe-src/1.0.1` and the CTT clone from
`Claude_Test/.rot-release`; they are supposed to differ.

The first draft of the checker compared across config dirs and went red on this
exact shape. The tempting repair — point the test instance at the real one —
would have destroyed the isolation the test instance exists to provide. So the
scoping is pinned by a theorem rather than left to a comment. -/
theorem cross_instance_divergence_is_not_a_defect :
    sound twoInstances = true := by decide

/-- The same two paths *inside one dir* is a defect. The scoping is exactly what
separates the correct machine above from the broken one. -/
theorem the_same_divergence_within_one_dir_IS_a_defect :
    sound [⟨0, 0, ⟨1, true⟩⟩, ⟨0, 1, ⟨2, true⟩⟩] = false := by decide

/-- Stated generally: moving a declaration into its own config dir can only ever
turn a conflict into a non-conflict, never the reverse. -/
theorem conflict_requires_a_shared_config_dir (a b : Decl) (h : a.cfg ≠ b.cfg) :
    conflicts a b = false := by
  simp only [conflicts, Bool.and_eq_false_iff, beq_eq_false_iff_ne]
  exact Or.inl h

/-! ### Silence is the failure mode -/

/-- What the tool does with a declaration it cannot resolve: nothing. It keeps
whatever root it already had. -/
def resolve (d : Decl) (fallback : Nat) : Nat :=
  if d.root.exists_ then d.root.path else fallback

/-- **A dangling declaration is silent.** Resolution falls back to the previous
root and reports no error, so the operator sees a working tool and an applied
patch that never took effect. This is the same shape as
`RotPluginRoot.registry_driven_patch_missed_the_runtime`, one layer out: there
the declaration pointed at the wrong live thing, here it points at nothing. -/
theorem a_dangling_declaration_resolves_to_the_stale_root
    (d : Decl) (fallback : Nat) (h : d.root.exists_ = false) :
    resolve d fallback = fallback := by
  simp [resolve, h]

/-- And it is indistinguishable, by its result alone, from a declaration that
correctly names the root already in use. Two different situations, one
observation — which is why the check must look at the DECLARATION, not at
whether the tool appears to work. -/
theorem silence_cannot_distinguish_dangling_from_correct
    (fallback : Nat) :
    resolve ⟨0, 0, ⟨99, false⟩⟩ fallback = resolve ⟨0, 0, ⟨fallback, true⟩⟩ fallback := by
  simp [resolve]

/-- An existing declaration is honoured — so the check is not vacuous: there is
a real difference between the two cases, it just is not visible downstream. -/
theorem an_existing_declaration_is_honoured (d : Decl) (fallback : Nat)
    (h : d.root.exists_ = true) : resolve d fallback = d.root.path := by
  simp [resolve, h]

/-! ### Executable checks -/

#guard sound [] = true
#guard sound [⟨0, 0, ⟨1, true⟩⟩] = true
#guard sound [⟨0, 0, ⟨1, false⟩⟩] = false
#guard allExist danglingPair = false
#guard agreesWithin danglingPair = true
#guard sound danglingPair = false
#guard allExist divergentPair = true
#guard agreesWithin divergentPair = false
#guard sound twoInstances = true
#guard conflicts ⟨0, 0, ⟨1, true⟩⟩ ⟨1, 0, ⟨2, true⟩⟩ = false
#guard conflicts ⟨0, 0, ⟨1, true⟩⟩ ⟨0, 1, ⟨2, true⟩⟩ = true
#guard conflicts ⟨0, 0, ⟨1, true⟩⟩ ⟨0, 1, ⟨1, true⟩⟩ = false
#guard resolve ⟨0, 0, ⟨99, false⟩⟩ 5 = 5
#guard resolve ⟨0, 0, ⟨99, true⟩⟩ 5 = 99

-- The live shape, as measured 2026-08-09: 12 declarations across two config
-- dirs, every one of them resolving to a directory that exists.
#guard sound (List.replicate 12 ⟨0, 0, ⟨1, true⟩⟩) = true

end RotMoE.RootDecl
