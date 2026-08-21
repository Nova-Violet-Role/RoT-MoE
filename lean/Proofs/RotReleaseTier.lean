/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-!
# The release tier map

`checker/release-package.sh` stamps a different patch digit into each of the
three archives, and `checker/release-notes.sh` composes one release note per
tier from the digit it reads back. Both files ASSERT that the three tiers land
on three distinct versions, and both assert it by running: build the zips, read
the versions out, compare. That is a sample. Three tiers happened not to
collide today.

This module SETTLES it. The map below is the same one both shell files
implement -- core to 0, lean to 1, unsealed to 2 -- and the theorems say the
properties the packager depends on hold for every tier, not for the three it
was run on:

* `patch_injective`   two tiers that produce the same digit ARE the same tier,
                      so `v9.0.0`, `v9.0.1`, `v9.0.2` can never be one tag.
* `ofPatch_patch`     the digit recovers the tier it came from, which is what
                      `release-notes.sh` relies on when it refuses an archive
                      whose stamped version disagrees with its tier.
* `ofPatch_none`      no digit at or above 3 names a tier -- the theorem behind
                      `REFUSE: ... declares 9.0.5, which no tier digit produces`.
* `patch_surjective`  every digit below 3 IS some tier, so the refusal above
                      rejects exactly the versions it should and no others.
* `version_distinct`  and therefore the three published tags differ, for any
                      base version whatsoever.

No `sorry`, no `native_decide`.
-/

-- This module imports NOTHING on purpose: the tier map is arithmetic on three
-- constructors and needs no library. That also means Mathlib's `hashCommand`
-- linter is not in scope here, so unlike `RotGaugeZero` this file carries no
-- `set_option` to silence it -- the option does not exist without Mathlib, and
-- setting an unknown option is itself a build error.

namespace RotReleaseTier

/-- The three release tiers, named as `checker/release-package.sh` names them. -/
inductive Tier where
  | core
  | lean
  | unsealed
deriving DecidableEq, Repr

/-- The patch digit each tier publishes under. `BASEVER.0`, `.1`, `.2`. -/
def patch : Tier → Nat
  | .core     => 0
  | .lean     => 1
  | .unsealed => 2

/-- Reading a tier back out of a patch digit. `none` is the packager's refusal. -/
def ofPatch : Nat → Option Tier
  | 0 => some .core
  | 1 => some .lean
  | 2 => some .unsealed
  | _ => none

/-- A full version: the base `major.minor` carried by the manifest, plus the
tier's own patch digit. This is exactly what `tier_version()` builds. -/
def version (maj min : Nat) (t : Tier) : Nat × Nat × Nat := (maj, min, patch t)

/-- Two tiers with the same patch digit are the same tier. This is the property
that makes three tags from one commit safe: distinct tiers cannot collide onto
one tag ref. -/
theorem patch_injective : ∀ a b : Tier, patch a = patch b → a = b := by
  intro a b h
  cases a <;> cases b <;> simp_all [patch]

/-- The digit round-trips back to its tier. -/
theorem ofPatch_patch : ∀ t : Tier, ofPatch (patch t) = some t := by
  intro t
  cases t <;> rfl

/-- Every tier publishes a digit below 3. -/
theorem patch_lt_three : ∀ t : Tier, patch t < 3 := by
  intro t
  cases t <;> decide

/-- No digit at or above 3 names a tier. This is the theorem behind the
packager's refusal when the manifest declares a version no tier produces --
`9.0.5` in the control that was run against it. -/
theorem ofPatch_none : ∀ n : Nat, 3 ≤ n → ofPatch n = none := by
  intro n h
  match n with
  | 0 => omega
  | 1 => omega
  | 2 => omega
  | (_ + 3) => rfl

/-- Every digit below 3 IS some tier: the refusal above rejects exactly the
versions it should, and never a legitimate one. Without this, `ofPatch_none`
would be consistent with a map that refuses everything. -/
theorem patch_surjective : ∀ n : Nat, n < 3 → ∃ t : Tier, patch t = n := by
  intro n h
  match n with
  | 0 => exact ⟨.core, rfl⟩
  | 1 => exact ⟨.lean, rfl⟩
  | 2 => exact ⟨.unsealed, rfl⟩
  | (_ + 3) => omega

/-- Distinct tiers publish distinct versions, for ANY base version. The shell
checks this for one base by reading three zips; here it holds for all of them. -/
theorem version_distinct (maj min : Nat) :
    ∀ a b : Tier, a ≠ b → version maj min a ≠ version maj min b := by
  intro a b hab h
  exact hab (patch_injective a b (congrArg (fun p => p.2.2) h))

-- The three tags this release actually cuts, for the recorded base `9.0`.
-- A `#guard` that goes false is an ERROR, not a warning.
#guard version 9 0 .core     == (9, 0, 0)
#guard version 9 0 .lean     == (9, 0, 1)
#guard version 9 0 .unsealed == (9, 0, 2)
#guard ofPatch 5 == none

end RotReleaseTier
