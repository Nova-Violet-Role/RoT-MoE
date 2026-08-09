/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

import Proofs.RotCalibration

/-!
# The stratified cap — a sample that cannot see the answers

## Why this file exists

`bench/calib-prompts.js` generates 279 candidate items. Running three
calibration reps and two test arms over all of them is 1395 live model turns,
so the pool is **capped** to 80 by taking an even stride through each shape.

A cap is a selection, and selection is exactly where the fourth metric can be
faked. `RotCalibration.circular_selection_cannot_lose` already proves what
happens when the *band filter* reads the routed arm. This file proves the
property one stage earlier, about the **cap**:

* it never returns more than it was asked for,
* it invents nothing that was not in the pool,
* and — the load-bearing one — **it is positional**. Flip every grade in the
  pool and the very same items come back. A sampler that cannot distinguish a
  correct answer from a wrong one cannot prefer either.

## What is NOT proved here

That the JavaScript implements this. Lean constrains the MODEL. The binding is
that both take an even stride by index and neither reads a grade — the cap runs
before any arm has answered, which is a property of the *pipeline order*, and
`grading_first_can_change_the_sample` is why that order is not cosmetic.
-/

namespace RotMoE.Sample

/-- A candidate item: which question shape it belongs to, its position in the
generated pool, and how the routed arm eventually graded it.

`routedRight` is deliberately present in the structure the sampler consumes.
The point is not that the sampler *cannot* reach the grade — it is that the
sampler provably **does not use it**, which is a stronger and checkable claim
than hiding the field. -/
structure Item where
  /-- Which question shape generated this item. -/
  shape : Nat
  /-- Position in the generated pool. -/
  idx : Nat
  /-- How the routed arm graded it. Unknown at cap time; present here so that
  the blindness theorems have something to be blind to. -/
  routedRight : Bool
  deriving DecidableEq, Repr

/-- Take every `s`-th element, counting from the first. `s = 0` is treated as
`s = 1`, so the function is total and never silently returns nothing. -/
def everyNth (l : List Item) (s : Nat) : List Item :=
  (l.zipIdx.filter (fun p => p.2 % (max 1 s) == 0)).map Prod.fst

/-- The cap: an even stride through the list, then a hard ceiling of `per`. -/
def cap (pool : List Item) (per : Nat) : List Item :=
  (everyNth pool (pool.length / max 1 per)).take per

/-- Flip how the routed arm graded an item. -/
def flipGrade (i : Item) : Item := { i with routedRight := !i.routedRight }

/-! ### The cap respects its bound and invents nothing -/

/-- **The cap never returns more than it was asked for.** The bound the
JavaScript's `MAX` is supposed to enforce, stated for every pool and every
ceiling rather than for the 80 that happen to be configured today. -/
theorem cap_never_exceeds (pool : List Item) (per : Nat) :
    (cap pool per).length ≤ per := by
  simp only [cap, List.length_take]
  omega

/-- **The cap invents nothing.** Every sampled item came from the pool. -/
theorem cap_invents_nothing {pool : List Item} {per : Nat} {x : Item}
    (h : x ∈ cap pool per) : x ∈ pool := by
  simp only [cap, everyNth] at h
  have h' := List.mem_of_mem_take h
  simp only [List.mem_map, List.mem_filter] at h'
  obtain ⟨p, ⟨hp, _⟩, rfl⟩ := h'
  exact List.fst_mem_of_mem_zipIdx hp

/-- An empty pool caps to nothing — there is no phantom item. -/
theorem empty_pool_caps_to_nothing (per : Nat) : cap [] per = [] := by
  simp [cap, everyNth]

/-- A ceiling of zero selects nothing, rather than quietly selecting everything.
An off-by-one here would silently disable the cap. -/
theorem zero_ceiling_selects_nothing (pool : List Item) : cap pool 0 = [] := by
  simp [cap]

/-! ### The load-bearing property: the sample is POSITIONAL -/

/-- `everyNth` keeps positions, so it commutes with any per-item rewrite. -/
theorem everyNth_map_flip (l : List Item) (s : Nat) :
    everyNth (l.map flipGrade) s = (everyNth l s).map flipGrade := by
  simp [everyNth, List.zipIdx_map, List.filter_map, List.map_map, Function.comp_def]

/-- **Flipping every grade does not move the sample.** The cap picks the same
positions whatever the answers turn out to be, so it cannot prefer the items
one arm got right. This is what makes the cap admissible in front of a paired
test — and it is the property `circular_selection_cannot_lose` shows is lost the
moment a selection *does* read an arm. -/
theorem cap_is_blind_to_grades (pool : List Item) (per : Nat) :
    cap (pool.map flipGrade) per = (cap pool per).map flipGrade := by
  have hlen : (pool.map flipGrade).length = pool.length := by simp
  simp [cap, hlen, everyNth_map_flip, List.map_take]

/-- The same statement in the form that matters operationally: the **indices**
the cap returns do not depend on the grades at all. -/
theorem cap_positions_are_grade_independent (pool : List Item) (per : Nat) :
    (cap (pool.map flipGrade) per).map Item.idx = (cap pool per).map Item.idx := by
  rw [cap_is_blind_to_grades]
  simp [List.map_map, Function.comp_def, flipGrade]

/-- And the shapes are preserved too: capping cannot silently drop a question
shape by grade, only by position. -/
theorem cap_shapes_are_grade_independent (pool : List Item) (per : Nat) :
    (cap (pool.map flipGrade) per).map Item.shape = (cap pool per).map Item.shape := by
  rw [cap_is_blind_to_grades]
  simp [List.map_map, Function.comp_def, flipGrade]

/-! ### Why the ORDER of cap and grade is not cosmetic -/

/-- Grade first, then cap: the forbidden order. -/
def gradeThenCap (pool : List Item) (per : Nat) : List Item :=
  cap (pool.filter (fun i => i.routedRight)) per

/-- Cap first, then look at the grades: the order the harness actually runs. -/
def capThenGrade (pool : List Item) (per : Nat) : List Item :=
  (cap pool per).filter (fun i => i.routedRight)

/-- A pool where the routed arm got the second item right and the first wrong. -/
def witness : List Item := [⟨0, 0, false⟩, ⟨0, 1, true⟩]

/-- **The two orders genuinely differ.** Capping after grading is not a
re-ordering of the same computation; it returns a different sample. -/
theorem grading_first_can_change_the_sample :
    gradeThenCap witness 1 ≠ capThenGrade witness 1 := by decide

/-- And it differs in the DANGEROUS direction: grading first hands back an item
the routed arm answered correctly, while the honest order hands back nothing at
all from the same pool. A metric built on the first order reports a routed win
that the pool never contained. -/
theorem grading_first_manufactures_a_routed_win :
    (gradeThenCap witness 1).all (fun i => i.routedRight) = true ∧
    capThenGrade witness 1 = [] := by decide

/-- The honest order can only ever return a subset of what it sampled blindly —
it never reaches back into the pool for a better item. -/
theorem capThenGrade_is_a_subset (pool : List Item) (per : Nat) {x : Item}
    (h : x ∈ capThenGrade pool per) : x ∈ cap pool per :=
  (List.mem_filter.mp h).1

/-! ### Executable checks on the shipped configuration -/

/-- The pool the generator actually produces, as a shape/count table:
`bench/calib-prompts.js` reported 80 candidates across 8 shapes. -/
def shippedShapes : List (Nat × Nat) :=
  [(0, 28), (1, 10), (2, 1), (3, 1), (4, 10), (5, 10), (6, 10), (7, 10)]

#guard shippedShapes.length = 8
#guard (shippedShapes.map Prod.snd).sum = 80

-- Every shape survived the cap: none was reduced to zero. A cap that silently
-- deleted a whole question shape would narrow what the metric can even see.
#guard shippedShapes.all (fun p => 0 < p.2) = true

-- The two singleton shapes are the global-maximum questions, of which there is
-- exactly one each by construction. They are not a cap artefact.
#guard (shippedShapes.filter (fun p => p.2 == 1)).length = 2

-- `flipGrade` MUST ACTUALLY FLIP. Without these two lines the blindness
-- theorems above are vacuous: if `flipGrade` were the identity,
-- `cap_is_blind_to_grades` would read `cap pool per = cap pool per` and hold for
-- any cap whatsoever, including one that reads the grades. Found by asking what
-- mutant would survive BEFORE writing the suite -- exactly the mutant that would
-- have.
#guard flipGrade ⟨0, 0, false⟩ = ⟨0, 0, true⟩
#guard flipGrade ⟨0, 1, true⟩ = ⟨0, 1, false⟩
#guard flipGrade ⟨0, 1, true⟩ ≠ ⟨0, 1, true⟩

#guard cap [] 5 = []
#guard cap witness 0 = []
#guard (cap witness 5).length = 2
#guard (cap witness 1).length = 1
#guard gradeThenCap witness 1 = [⟨0, 1, true⟩]
#guard capThenGrade witness 1 = []
#guard (cap (witness.map flipGrade) 2) = (cap witness 2).map flipGrade

end RotMoE.Sample
