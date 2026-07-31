/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

import Mathlib

/-!
# Isolation: DECORATIVE vs LOAD-BEARING, made checkable

A label like `[DECORATIVE]` in a doc comment is an *opinion* until something can
test it. This file tests it, and it is the reason the label may be trusted.

`classify_total` in `RotGauge.lean` states `∃! b, classify lo hi R = b`. That
shape holds for **any** function — it follows from `classify` being a function
at all — so it cannot tell a correct classifier from a broken one.
`classify_surjective` states that every band is reachable, which a broken one
fails.

Below is a classifier with the band **collapsed** so `inRange` is unreachable —
exactly what an off-by-one in the comparison produces. The first shape still
holds for it. The second is refuted. Building this file at exit 0 is the
evidence for both labels, and it breaks the moment either claim stops being
true.

Why this is not merely a mutation: mutant `M12` in `mutate_rotgauge.sh`
collapses the real `classify` and kills `classify_below_iff`,
`classify_inRange_iff` and `classify_above_iff` **first**, so the build dies
before it can say anything about the two theorems being compared. That cascade
is why attribution alone could not settle the question. Here both shapes are
stated against the *same* broken definition, in isolation, and their fates
differ inside one file.
-/

namespace RotMoE.Isolation

inductive B | below | inRange | above
deriving DecidableEq

/-- A classifier with the band COLLAPSED: `inRange` is unreachable. -/
noncomputable def bad (lo _hi R : ℝ) : B := if R < lo then .below else .above

/-- The `classify_total` shape still holds for it. A decorative theorem cannot
tell this broken classifier from the correct one. -/
example (lo hi R : ℝ) : ∃! b, bad lo hi R = b :=
  ⟨bad lo hi R, rfl, fun _ h => h.symm⟩

/-- The `classify_surjective` shape FAILS for it. This is the isolation: one
statement separates the broken classifier from the good one, the other does
not. -/
example : ¬ (∀ (lo hi : ℝ), lo ≤ hi → ∀ b, ∃ R, bad lo hi R = b) := by
  intro h
  obtain ⟨R, hR⟩ := h 0 0 le_rfl B.inRange
  unfold bad at hR
  split at hR <;> exact B.noConfusion hR

end RotMoE.Isolation
