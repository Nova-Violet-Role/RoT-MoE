/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A patch applied to a binary nobody executes is indistinguishable from no patch

**Measured 2026-08-10.** `/goal` appeared dead for days. It was not dead — it was
*refusing*. The standing goal condition is **4040 characters**; the binary serving
the session capped it at **4000**, so every attempt produced

```
Goal condition is limited to 4000 characters (got 4040)
```

recovered verbatim from the live transcript. Twelve to forty characters over a
limit, and a refusal that scrolls past reads exactly like a command that does
nothing.

The subtle part is *why* it regressed. The cap had been raised months earlier and
the operator's manual recorded "patched in all four binaries". That was true when
written. A package-manager update then relocated the live install from
`scoop\apps\nodejs-lts\24.14.1\…` to `scoop\persist\nodejs-lts\…`. **The patched
file still existed and was still patched. It was simply no longer the file that
runs.**

That is the theorem worth having, and it is not about `/goal` at all:

* `patching_the_unexecuted_is_invisible` — editing an install that is not executed
  leaves the effective behaviour bit-for-bit unchanged. A patch record is evidence
  about a *file*; behaviour is a property of the file that **runs**.
* `a_gap_admits_a_split` — any two installs with different caps admit a length one
  accepts and the other refuses. This is why a mixed estate (two at 10000, two at
  4000) is a defect in itself and not merely untidy.
* `uniform_estate_agrees_everywhere` — the durable repair. Stated over an arbitrary
  estate and an arbitrary length, so it does not expire the next time the cap moves.

The measured numbers appear only as `#guard`s and `example`s documenting the
present. Freezing 4040 or 9999 into a load-bearing hypothesis would make this file
red on the next legitimate change, which is the failure mode where the obvious
repair is to delete the coverage.

**Not modelled, deliberately.** A running process holds its JavaScript in memory, so
a patched file changes *new* sessions only. That is a runtime fact about process
startup, outside anything stated here, and it is why the fix was verified by
launching a **separate** CLI session rather than by inspecting bytes alone.
-/

namespace RotGoalCap

/-- An installed binary, reduced to what decides `/goal` behaviour: the cap its
check site reads, and whether this is the image actually executed. -/
structure Install where
  name     : String
  cap      : Nat
  executed : Bool
deriving Repr, DecidableEq

/-- The shipped check, verbatim in shape: `if (condition.length > cap) refuse`. -/
def accepts (i : Install) (len : Nat) : Bool := decide (len ≤ i.cap)

/-- What the estate actually does: only executed images can affect anything. -/
def effective (xs : List Install) : List Nat :=
  (xs.filter (fun i => i.executed)).map (·.cap)

/-! ## Part 1 — the regression: a patch that landed on the wrong file -/

/-- **The defect, stated generally.** Changing the cap of an install that is not
executed leaves the effective estate identical. No amount of care in *applying*
the patch substitutes for checking *which image runs*. -/
theorem patching_the_unexecuted_is_invisible
    (a b : Install) (ha : a.executed = false) (newCap : Nat) :
    effective [{a with cap := newCap}, b] = effective [a, b] := by
  simp [effective, ha]

/-- The same statement with the patch on the tail, so the result is not an artefact
of position in the list. -/
theorem patching_the_unexecuted_is_invisible_anywhere
    (a b : Install) (hb : b.executed = false) (newCap : Nat) :
    effective [a, {b with cap := newCap}] = effective [a, b] := by
  cases h : a.executed <;> simp [effective, hb, h]

/-- Contrapositive worth naming: if the effective estate *did* change, the install
that was edited was being executed. -/
theorem a_visible_change_means_it_was_executed
    (a b : Install) (newCap : Nat)
    (h : effective [{a with cap := newCap}, b] ≠ effective [a, b]) :
    a.executed = true := by
  cases h' : a.executed
  · exact absurd (patching_the_unexecuted_is_invisible a b h' newCap) h
  · rfl

/-! ## Part 2 — why a mixed estate is itself the bug -/

/-- **Any** two installs with different caps admit a condition length that one
accepts and the other refuses. Quantified over the caps, so it survives every
future change to their values. -/
theorem a_gap_admits_a_split (a b : Install) (h : a.cap < b.cap) :
    accepts a (a.cap + 1) = false ∧ accepts b (a.cap + 1) = true := by
  constructor
  · simp [accepts]
  · simp [accepts]; omega

/-- A disagreement can only come from differing caps — the split above is the only
mechanism, so equalising the caps is a complete repair rather than a patch over a
symptom. -/
theorem disagreement_implies_different_caps (a b : Install) (len : Nat)
    (h : accepts a len ≠ accepts b len) : a.cap ≠ b.cap := by
  intro hc
  exact h (by simp [accepts, hc])

/-- **The durable repair.** A uniform estate agrees on every length, for every
estate and every length. Nothing here mentions 9999. -/
theorem uniform_estate_agrees_everywhere
    (e : List Install) (h : ∀ a ∈ e, ∀ b ∈ e, a.cap = b.cap) (len : Nat) :
    ∀ a ∈ e, ∀ b ∈ e, accepts a len = accepts b len := by
  intro a ha b hb
  simp [accepts, h a ha b hb]

/-- Raising a cap never turns an accepted condition into a refused one: the repair
cannot break a goal that already worked. -/
theorem raising_never_refuses_more (a b : Install) (h : a.cap ≤ b.cap) (len : Nat) :
    accepts a len = true → accepts b len = true := by
  simp [accepts]; omega

/-! ## Part 3 — the measured estate, as documentation only

These pin what was observed on 2026-08-10. They are `example`/`#guard`, never
hypotheses of the theorems above, precisely so that moving the cap again does not
redden this file. -/

/-- Measured before the second pass: two images raised, two still shipping 4000 —
and the two at 4000 were the ones actually executed. -/
def estateBefore : List Install :=
  [ ⟨"local/bin",   10000, false⟩
  , ⟨"npm/bin",      4000, true⟩
  , ⟨"npm/win32-x64", 4000, true⟩
  , ⟨"vscodium",    10000, false⟩ ]

/-- Measured after: uniform at 9999. -/
def estateAfter : List Install :=
  [ ⟨"local/bin",    9999, false⟩
  , ⟨"npm/bin",      9999, true⟩
  , ⟨"npm/win32-x64", 9999, true⟩
  , ⟨"vscodium",     9999, false⟩ ]

/-- The standing goal condition, measured from the transcript refusal `(got 4040)`. -/
def measuredGoalLength : Nat := 4040

/-- Decidable estate-agreement, so the incident can be executed rather than argued. -/
def agree (e : List Install) (len : Nat) : Bool :=
  e.all (fun a => e.all (fun b => accepts a len == accepts b len))

-- the incident, reproduced: the estate disagreed at exactly the measured length
#guard agree estateBefore measuredGoalLength = false
#guard agree estateAfter  measuredGoalLength = true

-- the A/B that was run against two real binaries
#guard accepts ⟨"control", 4000, true⟩ measuredGoalLength = false
#guard accepts ⟨"patched", 9999, true⟩ measuredGoalLength = true

-- the executed images were the stale ones: effective cap was 4000, not 10000
#guard effective estateBefore = [4000, 4000]
#guard effective estateAfter  = [9999, 9999]

/-- Documentation of the present, not a load-bearing fact: 9999 clears 4040 with
room to spare. -/
example : measuredGoalLength < 9999 := by decide

/-- And the repair is uniform, which by `uniform_estate_agrees_everywhere` is what
actually retires the class of bug. -/
example : ∀ a ∈ estateAfter, ∀ b ∈ estateAfter, a.cap = b.cap := by decide

end RotGoalCap
