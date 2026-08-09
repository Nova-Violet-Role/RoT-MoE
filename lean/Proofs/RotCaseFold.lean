/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A green build on a case-insensitive filesystem proves less than it looks

MEASURED 2026-08-09 in the shared proof tree `D:/Lean/proofs`.

`lake env leanchecker Proofs.RotMoE.<X>` had been failing for EVERY delivered
module -- 45 of them -- with

    uncaught exception: Could not find any oleans for: Proofs.RotMoE.<X>

while `lake build Proofs.RotMoE.<X>` exited **0** and wrote the olean. Both
statements were true at the same time, and the reason is the filesystem:

    directory on disk   Proofs/RotMoe/     <- lowercase 'e'
    module referenced   Proofs.RotMoE.X    <- uppercase 'E'

Windows resolves paths case-INSENSITIVELY, so the compiler opened the file and
compiled it. `leanchecker` resolves a module name by EXACT match and could not
find it. The build could not see the error, and the kernel could not see the
proof.

## Two wrong turns, both recorded here because they are the instructive part

1. **The first diagnosis was wrong.** It blamed a missing aggregator
   (`Proofs/RotMoE.lean`). Writing the aggregator changed nothing --
   `the_aggregator_cannot_fix_a_case_mismatch` says why it could not have.
2. **The first repair made it worse.** Seven imports reading
   `import Proofs.RotMoe.X` were "fixed" to `Proofs.RotMoE.X`. They had been
   RIGHT. The repair moved them away from the directory's real name, and the
   build stayed green throughout because the filesystem kept absorbing it.

The alternative hypothesis -- that `leanchecker` cannot resolve nested module
paths -- was ruled out by CONTROL, not by argument: a freshly built
`Proofs.ZZDepth.Leaf` re-checks at exit 0. Depth was never the problem.

## Why this is not a Windows curiosity

The exact-match resolvers are the ones that matter for publication: a Linux CI
runner, a case-sensitive checkout, `git` itself. A tree that only builds because
the developer's filesystem folds case is a tree that fails on the machine that
is supposed to verify it. `same_tree_is_red_on_a_case_sensitive_host` is the
theorem; the repair is to make declared and on-disk names IDENTICAL, which
`canonical_names_resolve_on_every_host` proves is sufficient for both.

After canonicalising every reference to `RotMoe`: 34 of the 35 modules that have
an olean re-check at exit 0. Before, the number was ZERO -- and no session had
noticed, because the failure looked like a missing file rather than a wrong name.
-/

namespace RotMoE.CaseFold

/-- A module name, as characters, so case folding actually computes. -/
abbrev Name := List Char

/-- What a case-insensitive filesystem does before comparing. -/
def fold (n : Name) : Name := n.map Char.toLower

/-- Windows and macOS default: the resolver folds case, so a wrong name still
opens the right file. -/
def resolvesCaseInsensitive (declared onDisk : Name) : Bool :=
  fold declared == fold onDisk

/-- `leanchecker`, a Linux filesystem, and git: EXACT match, no folding. -/
def resolvesExact (declared onDisk : Name) : Bool := declared == onDisk

/-- A host, modelled by the only property that matters here. -/
def resolvesOn (caseSensitive : Bool) (declared onDisk : Name) : Bool :=
  if caseSensitive then resolvesExact declared onDisk
  else resolvesCaseInsensitive declared onDisk

/-- What the repository said. -/
def declaredName : Name := "Proofs.RotMoE.RotCeiling".toList

/-- What the disk said. -/
def onDiskName : Name := "Proofs.RotMoe.RotCeiling".toList

section TheMeasuredMismatch

theorem the_build_was_green : resolvesCaseInsensitive declaredName onDiskName = true := by
  decide

theorem the_kernel_could_not_resolve_it : resolvesExact declaredName onDiskName = false := by
  decide

/-- THE POINT, as one statement: the two instruments disagreed about the same
pair of names, and the weaker one is the one that was exiting 0. -/
theorem a_green_build_does_not_imply_the_kernel_can_find_it :
    resolvesCaseInsensitive declaredName onDiskName = true ∧
    resolvesExact declaredName onDiskName = false := by
  decide

/-- The same tree, on the host that publishes it. -/
theorem same_tree_is_red_on_a_case_sensitive_host :
    resolvesOn false declaredName onDiskName = true ∧
    resolvesOn true declaredName onDiskName = false := by
  decide

end TheMeasuredMismatch

section TheOrdering

/-- Exact resolution is STRICTLY stronger: whatever the kernel can find, the
filesystem can find too. So `leanchecker` failing while `lake build` passes is
the only possible direction of disagreement -- the reverse cannot happen. -/
theorem exact_implies_insensitive (a b : Name) (h : resolvesExact a b = true) :
    resolvesCaseInsensitive a b = true := by
  simp [resolvesExact] at h
  subst h
  simp [resolvesCaseInsensitive]

/-- And the containment is strict, witnessed by the measured pair. Without this
the theorem above would be compatible with the two resolvers being equal. -/
theorem the_containment_is_strict :
    resolvesCaseInsensitive declaredName onDiskName = true ∧
    resolvesExact declaredName onDiskName = false := by
  decide

/-- Neither resolver is trivially true: folding still distinguishes names that
differ by more than case, so `resolvesCaseInsensitive` is not the constant
`true` and the theorems above are not vacuous. -/
theorem folding_still_distinguishes_real_differences :
    resolvesCaseInsensitive "Proofs.RotMoe.RotCeiling".toList
      "Proofs.RotMoe.RotGrounding".toList = false := by
  decide

end TheOrdering

section TheRepair

/-- Identical names resolve on EVERY host, case-sensitive or not. This is the
whole repair, and it is why the fix was to canonicalise rather than to pick the
prettier spelling. -/
theorem canonical_names_resolve_on_every_host (n : Name) (cs : Bool) :
    resolvesOn cs n n = true := by
  cases cs <;> simp [resolvesOn, resolvesExact, resolvesCaseInsensitive]

/-- Canonicalisation is what was actually done: after the rename, the declared
name IS the on-disk name. -/
theorem the_repaired_reference_resolves_exactly :
    resolvesExact onDiskName onDiskName = true := by decide

end TheRepair

section TheWrongTurns

/-- A delivery, carrying the thing the first diagnosis blamed. -/
structure Delivery where
  declared : Name
  onDisk : Name
  aggregatorExists : Bool

def kernelRechecks (d : Delivery) : Bool := resolvesExact d.declared d.onDisk

/-- WRONG TURN 1. Whether the aggregator exists cannot change the outcome --
the two sides are equal for every value of the flag, so writing it could never
have fixed anything. Stated over arbitrary names so it is a property of the
model, not of one witness. -/
theorem the_aggregator_cannot_fix_a_case_mismatch (dec dsk : Name) (a b : Bool) :
    kernelRechecks ⟨dec, dsk, a⟩ = kernelRechecks ⟨dec, dsk, b⟩ := rfl

/-- And concretely: with the aggregator present, the measured delivery still
does not re-check. -/
theorem writing_the_aggregator_left_it_unresolved :
    kernelRechecks ⟨declaredName, onDiskName, true⟩ = false := by decide

/-- WRONG TURN 2. The seven imports that were "corrected" from `RotMoe` to
`RotMoE` had been resolvable by the exact-match instrument; after the edit they
were not. The edit moved the tree from green to red on every case-sensitive
host while the local build never changed. -/
theorem the_repair_broke_what_it_touched :
    resolvesExact onDiskName onDiskName = true ∧
    resolvesExact declaredName onDiskName = false := by
  decide

/-- Number of dots in a module path. -/
def depth (n : Name) : Nat := (n.filter (· == '.')).length

/-- THE CONTROL that ruled out the depth hypothesis, kept as a theorem so the
alternative explanation stays refuted rather than merely forgotten: a nested
name of the same depth resolves exactly when its case is right. -/
theorem depth_was_not_the_problem :
    depth "Proofs.ZZDepth.Leaf".toList = 2 ∧
    resolvesExact "Proofs.ZZDepth.Leaf".toList "Proofs.ZZDepth.Leaf".toList = true := by
  decide

/-- The failing name has the SAME depth as the control that succeeded, so depth
cannot separate them. This is what makes the control a control. -/
theorem the_failing_name_has_the_same_depth :
    depth declaredName = depth "Proofs.ZZDepth.Leaf".toList := by decide

end TheWrongTurns

section Measured

#guard resolvesCaseInsensitive declaredName onDiskName = true
#guard resolvesExact declaredName onDiskName = false
#guard resolvesOn false declaredName onDiskName = true
#guard resolvesOn true declaredName onDiskName = false
#guard resolvesExact onDiskName onDiskName = true
#guard resolvesCaseInsensitive onDiskName onDiskName = true
#guard resolvesCaseInsensitive "Proofs.RotMoe.RotCeiling".toList
         "Proofs.RotMoe.RotGrounding".toList = false
#guard kernelRechecks ⟨declaredName, onDiskName, true⟩ = false
#guard kernelRechecks ⟨declaredName, onDiskName, false⟩ = false
#guard kernelRechecks ⟨onDiskName, onDiskName, false⟩ = true
#guard depth declaredName = 2
#guard depth "Proofs.ZZDepth.Leaf".toList = 2
#guard fold declaredName = fold onDiskName

end Measured

end RotMoE.CaseFold
