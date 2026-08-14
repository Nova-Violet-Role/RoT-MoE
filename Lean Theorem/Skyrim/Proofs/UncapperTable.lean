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
# The Skill Uncapper level-0 experience trap

A real defect, measured in the Skyrim SE AutoCombat build on 2026-08-12: the character was
pinned at level 0 and could gain no experience at all, permanently.

`SkyrimUncapper.dll` (Kassent v1.1.0) documents its own table lookup in its embedded help
text:

> "If a specific level is not specified then the closest lower level setting is used."

and it documents that BOTH experience paths run through such a table:

> "The skill experience you gained actually = ... * SkillExpGainMult * Corresponding
>  Sub-SkillExpGainMult listed below."
> "When you level up a skill, the PC experience you gained actually = Current base skill
>  level * LevelSkillExpMults * Corresponding Sub-LevelSkillExpMults listed below."

Every one of the 72 sub-tables in the generated `SkyrimUncapper.ini` had exactly one row,
keyed at level **1**:

    [SkillExpGainMults\CharacterLevel\OneHanded]
    1 = 1.00

At character level 0 there is no key at or below 0, so "closest lower" finds nothing and no
multiplier resolves. No multiplier means no experience, and no experience means the level
never leaves 0. The state sustains itself, which is why it presented as *permanent* rather
than as slow progress.

This file models the lookup and proves three things about it:

* `trapped_at_zero` / `stuck_forever` - the defect. A table whose keys all start at 1 is
  undefined at level 0, and a character at level 0 stays there for **every** number of
  steps. This is the theorem that matches the reported symptom.
* `zero_row_makes_total` / `zero_row_escapes` - the repair. A row keyed at 0 makes the
  lookup defined at *every* level, and a positive multiplier there lets the level move.
* `zero_row_preserves` - why the repair is safe. Adding the 0 row changes **no** existing
  answer, at any level, whenever the old table already answered with a key of at least 1.

That last one is the load-bearing one. Editing a config that governs all experience gain is
only defensible if the edit provably cannot alter behaviour that already worked, and the
theorem is stated for an arbitrary table and an arbitrary level rather than for the 72 rows
that happen to be on disk today - a table that gains a `2 = ...` row next week is still
covered.

The `#guard`s at the end pin the two tables that were actually measured, before and after
the repair (`scripts/48-uncapper-level0-guard.ps1`).

Multipliers are modelled as `Nat` hundredths, so `1.00` is `100`; only the zero / non-zero
distinction is load-bearing here.
-/

namespace UncapperTable

/-- A sub-table: rows of (level key, multiplier in hundredths). -/
abbrev Table := List (Nat × Nat)

/-- "Closest lower level setting": among rows whose key is at most `lvl`, take the one with
the greatest key. Later rows win ties, matching a left-to-right scan that keeps replacing
on `≤`. `none` means the lookup is undefined - there is no row at or below `lvl`. -/
def bestRow (t : Table) (lvl : Nat) : Option (Nat × Nat) :=
  match t with
  | [] => none
  | e :: rest =>
      if e.1 ≤ lvl then
        match bestRow rest lvl with
        | none => some e
        | some b => if b.1 ≤ e.1 then some e else some b
      else
        bestRow rest lvl

/-- The multiplier the DLL would use at `lvl`, or `none` if the table does not define it. -/
def lookup (t : Table) (lvl : Nat) : Option Nat :=
  (bestRow t lvl).map Prod.snd

/-- One increment of progression. An undefined or zero multiplier yields no experience, so
the level cannot move; any positive multiplier lets it advance. -/
def step (t : Table) (lvl : Nat) : Nat :=
  match lookup t lvl with
  | none => lvl
  | some 0 => lvl
  | some (_ + 1) => lvl + 1

/-- `n` increments of progression starting from `lvl`. -/
def levelAfter (t : Table) : Nat → Nat → Nat
  | 0, lvl => lvl
  | n + 1, lvl => levelAfter t n (step t lvl)

/-! ### The defect -/

/-- A table whose every key is at least 1 is undefined at level 0: "closest lower" has
nothing to find. -/
theorem bestRow_zero_none : ∀ (t : Table), (∀ e ∈ t, 1 ≤ e.1) → bestRow t 0 = none := by
  intro t
  induction t with
  | nil => intro _; rfl
  | cons a l ih =>
      intro h
      have ha : ¬ (a.1 ≤ 0) := by
        have := h a (by simp)
        omega
      have hl : ∀ e ∈ l, 1 ≤ e.1 := fun e he => h e (by simp [he])
      simp [bestRow, ha, ih hl]

/-- The measured defect: no multiplier resolves at character level 0. -/
theorem trapped_at_zero (t : Table) (h : ∀ e ∈ t, 1 ≤ e.1) : lookup t 0 = none := by
  simp [lookup, bestRow_zero_none t h]

/-- Hence no experience, hence no level: a character at 0 does not move. -/
theorem step_zero_stays (t : Table) (h : ∀ e ∈ t, 1 ≤ e.1) : step t 0 = 0 := by
  simp [step, trapped_at_zero t h]

/-- **The symptom, in full**: with every key starting at 1, the character is at level 0
after *any* number of progression steps. Not slow - impossible. -/
theorem stuck_forever (t : Table) (h : ∀ e ∈ t, 1 ≤ e.1) (n : Nat) :
    levelAfter t n 0 = 0 := by
  induction n with
  | zero => rfl
  | succ k ih => simp [levelAfter, step_zero_stays t h, ih]

/-! ### The repair -/

/-- A row keyed at 0 makes the table defined at **every** level, because `0 ≤ lvl` always.
The character can no longer be trapped, whatever level anything writes onto him. -/
theorem zero_row_makes_total (t : Table) (v lvl : Nat) :
    (lookup ((0, v) :: t) lvl).isSome := by
  cases hb : bestRow t lvl with
  | none => simp [lookup, bestRow, hb]
  | some b =>
      by_cases hc : b.1 ≤ 0 <;> simp [lookup, bestRow, hb, hc]

/-- With a positive multiplier at key 0, a character at level 0 advances. -/
theorem zero_row_escapes (t : Table) (v : Nat) (hv : 0 < v) (h : ∀ e ∈ t, 1 ≤ e.1) :
    step ((0, v) :: t) 0 = 1 := by
  have hb : bestRow t 0 = none := bestRow_zero_none t h
  cases v with
  | zero => omega
  | succ k => simp [step, lookup, bestRow, hb]

/-- **Why the repair is safe.** If the table already answered at `lvl` with a row whose key
is at least 1, prepending a row keyed at 0 returns the *same* row. The edit cannot change
any behaviour that already worked - at any level, for any table. -/
theorem zero_row_preserves (t : Table) (v lvl : Nat) (b : Nat × Nat)
    (h : bestRow t lvl = some b) (hb : 1 ≤ b.1) :
    bestRow ((0, v) :: t) lvl = some b := by
  have hc : ¬ (b.1 ≤ 0) := by omega
  simp [bestRow, h, hc]

/-- The same statement at the level of the multiplier actually used. -/
theorem zero_row_preserves_lookup (t : Table) (v lvl : Nat) (b : Nat × Nat)
    (h : bestRow t lvl = some b) (hb : 1 ≤ b.1) :
    lookup ((0, v) :: t) lvl = lookup t lvl := by
  simp [lookup, zero_row_preserves t v lvl b h hb, h]

/-! ### The tables that were on disk

Measured in `MO2\overwrite\SKSE\Plugins\SkyrimUncapper.ini`: all 72 sub-tables held the
single row `1 = 1.00` before the repair, and `0 = 1.00` was inserted above each one. -/

/-- The table as shipped, for one sub-table; `1.00` is `100` hundredths. -/
def measuredBefore : Table := [(1, 100)]

/-- The same sub-table after `scripts/48-uncapper-level0-guard.ps1`. -/
def measuredAfter : Table := [(0, 100), (1, 100)]

-- before: undefined at level 0, and the character never moves
#guard lookup measuredBefore 0 == none
#guard step measuredBefore 0 == 0
#guard levelAfter measuredBefore 50 0 == 0

-- after: defined at level 0, and the character moves
#guard lookup measuredAfter 0 == some 100
#guard step measuredAfter 0 == 1

-- after: unchanged everywhere it already worked
#guard lookup measuredAfter 1 == lookup measuredBefore 1
#guard lookup measuredAfter 5 == lookup measuredBefore 5
#guard lookup measuredAfter 81 == lookup measuredBefore 81

end UncapperTable
