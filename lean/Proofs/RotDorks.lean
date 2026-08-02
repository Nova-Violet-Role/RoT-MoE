/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# THE TAG ROTATION MUST PERMUTE, NEVER EDIT, THE PUBLISHED SET.

`checker/dorks.sh` rotates the order of the signature tags in README.md so the
page differs from day to day. The whole mechanism is only safe if the map it
applies cannot lose or duplicate a tag: a README silently advertising 41 of 42
tags would be wrong in a way no reader could notice.

The checker SAMPLES that property over 13 seeds. This file SETTLES it: the map

    rot n s o i = (i * s + o) % n

is injective on `Fin n` whenever `gcd s n = 1`, hence -- `Fin n` being finite --
a bijection, hence the multiset of tags is preserved for EVERY seed, not just
the ones anyone thought to test.

The coprimality hypothesis is not decoration. `stride_must_be_coprime` below
exhibits a concrete non-coprime stride that collapses distinct inputs, which is
the same collapse `checker/dorks.sh` plants as its negative control (42 tags
down to 7 distinct under stride 6).
-/

import Mathlib

set_option linter.hashCommand false

namespace RotDorks

/-- The rotation the shell script performs, on indices. -/
def rot (n s o i : Nat) : Nat := (i * s + o) % n

-- Concrete agreement with the shell implementation: 42 tags, stride 5, offset 3.
-- If checker/dorks.sh ever computes something else, these rows notice.
#guard rot 42 5 3 0 = 3
#guard rot 42 5 3 1 = 8
#guard rot 42 5 3 41 = 40

/-- Every index lands inside the range, so no rotation can index past the tag
list. `n > 0` is exactly the guard the script enforces by refusing an empty
`[SIGNATURE]` section. -/
theorem rot_lt (n s o i : Nat) (hn : 0 < n) : rot n s o i < n :=
  Nat.mod_lt _ hn

/-- THE LOAD-BEARING THEOREM. With a stride coprime to `n`, the rotation is
injective on the index range -- therefore no two tags can collide, therefore
none can be dropped. `0 < n` was an OVER-ASSUMPTION and is gone: the proof never
used it, and a hypothesis a proof does not need makes the theorem weaker than
what was actually established. Stated over an arbitrary `n`, `s`, `o`, so adding a tag
(n = 43) does not invalidate it: the spec is about the property, not about
today's 42. -/
theorem rot_injective (n s o : Nat) (h : Nat.gcd s n = 1)
    {i j : Nat} (hi : i < n) (hj : j < n) (hij : rot n s o i = rot n s o j) :
    i = j := by
  unfold rot at hij
  have hmul : (i * s) % n = (j * s) % n := by
    have := Nat.ModEq.add_right_cancel' o hij
    simpa [Nat.ModEq] using this
  have hco : Nat.Coprime s n := h
  have : i % n = j % n := by
    have h1 : i * s ≡ j * s [MOD n] := hmul
    exact Nat.ModEq.cancel_right_of_coprime (by simpa [Nat.Coprime, Nat.gcd_comm] using hco) h1
  rwa [Nat.mod_eq_of_lt hi, Nat.mod_eq_of_lt hj] at this

/-- The rotation is therefore a bijection on `Fin n`: injective on a finite type
of the same size. This is the statement the README depends on -- the published
list is a PERMUTATION of `tags.txt`, so the set is preserved for every seed. -/
theorem rot_bijective (n s o : Nat) (hn : 0 < n) (h : Nat.gcd s n = 1) :
    Function.Bijective (fun i : Fin n => (⟨rot n s o i.val, rot_lt n s o i.val hn⟩ : Fin n)) := by
  apply Finite.injective_iff_bijective.mp
  intro a b hab
  have : rot n s o a.val = rot n s o b.val := congrArg Fin.val hab
  exact Fin.ext (rot_injective n s o h a.isLt b.isLt this)

/-- THE HYPOTHESIS IS NOT DECORATION. Stride 6 shares a factor with 42, and it
maps two distinct indices to the same slot -- one tag would overwrite another
and one would vanish. This is the collapse `checker/dorks.sh` plants as its
negative control, and it is why the script COMPUTES a coprime stride instead of
hard-coding one that happens to work for 42. -/
theorem stride_must_be_coprime :
    Nat.gcd 6 42 ≠ 1 ∧ rot 42 6 0 0 = rot 42 6 0 7 ∧ (0 : Nat) ≠ 7 := by
  refine ⟨by decide, by decide, by decide⟩

-- Coprimality is decidable, so the runtime check and this proof share a predicate.
#guard Nat.gcd 5 42 = 1
#guard Nat.gcd 6 42 = 6

-- A coprime stride hits every slot exactly once, at the shipping size.
#guard (List.range 42 |>.map (rot 42 5 3) |>.eraseDups |>.length) = 42

/-- And the identity that makes the daily refresh visible: with a non-zero
offset the first published tag is not the first tag in the file, so the block
actually changes. A rotation that returned the input would satisfy every
theorem above and refresh nothing. -/
theorem rotation_moves : rot 42 5 3 0 ≠ 0 := by decide

end RotDorks
