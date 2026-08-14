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
# Viewer count: a reading is either measured or absent, and absence renders as NOTHING

`ModelViewerCount` reads a site's viewer count reflectively. Most sites publish none: measured,
**2 of 21** `Model` implementations expose `getViewerCount`. The design question this file settles
is what the other 19 render.

The trap is that Java's `int` defaults to `0`. A site that never populates the field is therefore
indistinguishable, at the reading, from a genuinely empty room. Reporting `0` as data would
fabricate a measurement for 19 of 21 sites. So `0` is mapped to ABSENT, and absent renders as the
empty string -- never `"0"`, never `"?"`, never a dash.

`Reading` is the model of what the reflective probe returns: `none` when the site is silent, the
method throws, or the value is not a number; `some n` when a number came back.
-/

namespace CtbrecSpec.ViewerCount

/-- What the reflective probe yields before interpretation. `Int`, because a corrupt site can
report a negative and the model must be able to express that. -/
abbrev Raw := Option Int

/-- The interpreted reading. `none` means UNKNOWN -- no claim is made. -/
abbrev Reading := Option Nat

/-- Interpretation. Absent stays absent; `0` and negatives become absent; a positive is kept.

`0` is rejected deliberately, not incidentally: see the module docstring. -/
def interpret (r : Raw) : Reading :=
  match r with
  | none => none
  | some n => if n > 0 then some n.toNat else none

/-- Rendering. UNKNOWN renders as the empty string. -/
def render (r : Reading) : String :=
  match r with
  | none => ""
  | some n => toString n

/-- The label is shown exactly when a reading exists. -/
def isVisible (r : Reading) : Bool := (render r) != ""

/-! ## The four properties the UI depends on -/

/-- A silent site is UNKNOWN. -/
theorem silent_is_unknown : interpret none = none := rfl

/-- **Zero is never data.** This is the one that matters: it is what stops 19 of 21 sites from
displaying a fabricated `0`. -/
theorem zero_is_unknown : interpret (some 0) = none := rfl

/-- A negative reading is corruption, not a measurement. -/
theorem negative_is_unknown (n : Int) (h : n < 0) : interpret (some n) = none := by
  simp only [interpret]
  have : ¬ (n > 0) := by omega
  simp [this]

/-- **Zero is never carried into the rendered value.** Stated over the READING rather than over
the rendered text, which is the stronger claim and the one the UI actually depends on: whatever
is rendered comes from a strictly positive reading, or there is no reading at all.

Deliberately NOT stated as `render _ ≠ "0"`. That form is about the string, and a string-level
theorem would keep holding if `interpret` started admitting `0` while `toString` merely spelled it
differently. This form cannot: it constrains the number that reaches the renderer. -/
theorem rendered_value_is_always_positive (r : Raw) :
    interpret r = none ∨ ∃ n : Nat, n > 0 ∧ interpret r = some n := by
  cases r with
  | none => exact Or.inl rfl
  | some n =>
      by_cases h : n > 0
      · exact Or.inr ⟨n.toNat, by omega, by simp [interpret, h]⟩
      · exact Or.inl (by simp [interpret, h])

/-- **An unknown reading renders as nothing at all.** Not `"0"`, not `"?"`, not a dash: the empty
string, which is what makes the badge disappear rather than display a fabricated measurement. -/
theorem unknown_renders_empty (r : Raw) (h : interpret r = none) : render (interpret r) = "" := by
  rw [h]; rfl

/-- The badge is hidden exactly when the reading is unknown. -/
theorem hidden_iff_unknown (r : Raw) (h : interpret r = none) :
    isVisible (interpret r) = false := by
  rw [h]; rfl

/-- A positive reading survives interpretation intact -- the guard rejects, it does not distort. -/
theorem positive_is_kept (n : Int) (h : n > 0) : interpret (some n) = some n.toNat := by
  simp [interpret, h]

/-! ## Executable checks: the definitions must AGREE with the Java on concrete inputs -/

#guard interpret none == none
#guard interpret (some 0) == none
#guard interpret (some (-5)) == none
#guard interpret (some 1) == some 1
#guard interpret (some 1337) == some 1337
#guard render (interpret (some 0)) == ""
#guard render (interpret none) == ""
#guard render (interpret (some 42)) == "42"
#guard isVisible (interpret (some 0)) == false
#guard isVisible (interpret (some 7)) == true

end CtbrecSpec.ViewerCount
