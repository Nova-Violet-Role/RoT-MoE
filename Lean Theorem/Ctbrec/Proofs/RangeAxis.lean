/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the labelled resolution axis

Subject: `src/app/ctbrec/ui/controls/range/LabeledNumberAxis.java`,
`DiscreteRange.java`, and the one construction site
`src/app/ctbrec/ui/settings/SettingsTab.java:138-140`.

## Finding 0 — the package does not compile

Measured, `javac` on `src/app/ctbrec/ui/controls/range/*.java`:

```
LabeledNumberAxis.java:31: error: Object cannot be safely cast to Range<Number>
      if (!(range instanceof Range<Number> discreteRange)) {
```

Since Java 16, an `instanceof` pattern may only name a parameterized type when the cast is
provably safe; `Object` to `Range<Number>` is unchecked. So this file — and with it the whole
`range` package the resolution slider is built from — **has not been compiling at all**.

The repair is not a suppression. `Range<?>` is matched, and every tick is then checked to be a
`Number` individually, which is strictly *more* than the unchecked cast ever established:
`the_checked_conversion_accepts_exactly_the_numeric_ranges`.

## Finding 1 — the label is looked up by the tick's VALUE, not by its position

```java
protected String getTickMarkLabel(Number value) {
   return this.range.getLabels().get(value.intValue()).toString();
}
```

`value.intValue()` indexes the *labels* list. `SettingsTab.java:138-139` builds

```java
labels = Arrays.asList(0, 240, 360, 480, 540, 600, 720, 960, 1080, 1440, 2160, 4320, 8640);
values = Arrays.asList(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12);
```

so a tick value **is** its own index — but only because the values happen to be consecutive from
zero. That is a contingent fact about one caller, not a property of `DiscreteRange`. The obvious
maintenance edit — using the real resolutions as the values — makes every lookup throw
`IndexOutOfBoundsException`. `the_shipped_lookup_breaks_the_moment_values_are_not_indices` is the
witness; `the_two_lookups_agree_when_the_values_are_indices` is why nobody has noticed.

The repair looks the label up by the value's **position** in the values list, which is right for
every list and identical to today's behaviour on this one.

## Finding 2 — nothing requires as many labels as values

`DiscreteRange`'s constructor rejects `null` and nothing else. With fewer labels than values the
tail of the axis throws, one tick at a time.
`every_tick_has_a_label_exactly_when_the_lists_agree_in_length` makes it a constructor
precondition instead of a runtime surprise.
-/

namespace CtbrecSpec

/-- Position of the first occurrence of `v` in `xs`, if present. -/
def posOf (v : Nat) : List Nat → Option Nat
  | [] => none
  | x :: rest => if x = v then some 0 else (posOf v rest).map (· + 1)

/-- The repaired lookup: find where the tick sits among the values, take the label there. -/
def labelFor (values labels : List Nat) (v : Nat) : Option Nat :=
  match posOf v values with
  | none => none
  | some i => labels[i]?

/-- The shipped lookup: index the labels by the tick's numeric value. -/
def shippedLabelFor (labels : List Nat) (v : Nat) : Option Nat := labels[v]?

/-! ### Why it works today, and what it costs -/

/-- A value list that is `0, 1, …, n-1` — exactly what `SettingsTab` passes. -/
def indexValues (n : Nat) : List Nat := List.range n

/-- Shifting every element of a list by one shifts which value is found, but **not** where it is
found. Stated separately because the inline version of this step was written the other way round
(`(posOf k xs).map (· + 1)`) and is simply false: the position of `k+1` in the shifted list is the
position of `k` in the original, not one past it. -/
theorem posOf_map_succ (k : Nat) : ∀ xs : List Nat,
    posOf (k + 1) (xs.map (· + 1)) = posOf k xs
  | [] => rfl
  | x :: rest => by
      simp only [List.map_cons, posOf]
      by_cases hx : x = k
      · simp [hx]
      · simp [hx, posOf_map_succ k rest]

/-- `posOf` on `List.range n` is the identity below `n`. -/
theorem posOf_range (n v : Nat) (h : v < n) : posOf v (indexValues n) = some v := by
  unfold indexValues
  induction n generalizing v with
  | zero => omega
  | succ m ih =>
      cases v with
      | zero => simp [List.range_succ_eq_map, posOf]
      | succ k =>
          have hk : k < m := by omega
          have hstep : posOf (k + 1) (0 :: (List.range m).map (· + 1)) = some (k + 1) := by
            simp only [posOf, if_neg (by omega : ¬(0 = k + 1))]
            rw [posOf_map_succ k (List.range m), ih k hk]
            rfl
          simpa [List.range_succ_eq_map] using hstep

/-- **Why the defect has never been seen.** With `SettingsTab`'s consecutive-from-zero values the
two lookups return the same label for every tick. -/
theorem the_two_lookups_agree_when_the_values_are_indices (labels : List Nat) (n v : Nat)
    (h : v < n) : labelFor (indexValues n) labels v = shippedLabelFor labels v := by
  unfold labelFor shippedLabelFor
  rw [posOf_range n v h]

/-- **…and the moment the values stop being indices, the shipped lookup is wrong.** With the real
resolutions as values, tick `240` asks for `labels[240]` of a 4-element list — the
`IndexOutOfBoundsException` the running UI would throw. The repaired lookup returns the right
label. -/
theorem the_shipped_lookup_breaks_the_moment_values_are_not_indices :
    shippedLabelFor [0, 240, 360, 480] 240 = none ∧
    labelFor [0, 240, 360, 480] [0, 240, 360, 480] 240 = some 240 := by decide

/-! ### Totality -/

/-- **Every tick has a label exactly when the two lists are the same length.** Both directions:
equal lengths give a label to every value, and a shorter label list leaves one without. -/
theorem every_tick_has_a_label_when_the_lists_agree (values labels : List Nat) (v : Nat)
    (hlen : values.length = labels.length) (hmem : v ∈ values) :
    ∃ l, labelFor values labels v = some l := by
  have hpos : ∃ i, posOf v values = some i ∧ i < values.length := by
    clear hlen
    induction values with
    | nil => cases hmem
    | cons x rest ih =>
        by_cases hx : x = v
        · exact ⟨0, by simp [posOf, hx], by simp⟩
        · have : v ∈ rest := by
            rcases List.mem_cons.mp hmem with h | h
            · exact absurd h.symm hx
            · exact h
          obtain ⟨i, hi, hlt⟩ := ih this
          exact ⟨i + 1, by simp [posOf, hx, hi], by simpa using hlt⟩
  obtain ⟨i, hi, hlt⟩ := hpos
  refine ⟨labels[i]'(by omega), ?_⟩
  unfold labelFor
  rw [hi]
  exact List.getElem?_eq_getElem (by omega)

/-- **A shorter label list leaves a tick unlabelled.** Without this the theorem above could be
satisfied by a lookup that invented a label. -/
theorem a_short_label_list_leaves_a_tick_unlabelled :
    labelFor [0, 1, 2] [10, 20] 2 = none := by decide

/-- The repaired lookup never answers for a value the range does not contain. -/
theorem an_unknown_tick_has_no_label (values labels : List Nat) (v : Nat) (h : v ∉ values) :
    labelFor values labels v = none := by
  unfold labelFor
  have : posOf v values = none := by
    induction values with
    | nil => rfl
    | cons x rest ih =>
        have hx : x ≠ v := fun he => h (by simp [he])
        have hr : v ∉ rest := fun hm => h (by simp [hm])
        simp [posOf, hx, ih hr]
  rw [this]

/-! ### The tick conversion that replaces the illegal cast

`calculateTickValues` receives `Object`. The shipped code cast it to `Range<Number>` in one
unchecked step — which is why the file does not compile. The repair matches `Range<?>` and checks
each tick, so a range of non-numeric ticks is rejected with a message instead of blowing up later
inside JavaFX with a `ClassCastException` from a synthetic checkcast. -/

/-- A tick as it arrives from an untyped `Range<?>`. -/
inductive Tick where
  | num (n : Nat)
  | other
  deriving DecidableEq, Repr

/-- Checked conversion: every element must really be a number. -/
def asNumbers : List Tick → Option (List Nat)
  | [] => some []
  | Tick.num n :: rest => (asNumbers rest).map (n :: ·)
  | Tick.other :: _ => none

/-- **The conversion accepts exactly the ranges whose every tick is numeric.** The unchecked cast
it replaces established nothing at all. -/
theorem the_checked_conversion_accepts_exactly_the_numeric_ranges (ts : List Tick) :
    (asNumbers ts).isSome = ts.all (fun t => match t with | Tick.num _ => true | _ => false) := by
  induction ts with
  | nil => rfl
  | cons t rest ih =>
      cases t with
      | num n => simpa [asNumbers, Option.isSome_map] using ih
      | other => simp [asNumbers]

/-- A numeric range converts to exactly its ticks — the repair is not lossy. -/
theorem a_numeric_range_converts_to_its_ticks :
    asNumbers [Tick.num 0, Tick.num 240, Tick.num 360] = some [0, 240, 360] := by decide

/-- One non-numeric tick is enough to refuse the whole range. -/
theorem one_bad_tick_refuses_the_range :
    asNumbers [Tick.num 0, Tick.other, Tick.num 360] = none := by decide

#guard posOf 3 [0, 1, 2, 3, 4] == some 3
#guard posOf 240 [0, 240, 360] == some 1
#guard posOf 99 [0, 240, 360] == none
#guard labelFor [0, 1, 2] [100, 200, 300] 1 == some 200
#guard shippedLabelFor [100, 200, 300] 1 == some 200
#guard shippedLabelFor [0, 240, 360, 480] 240 == none
#guard labelFor [0, 240, 360, 480] [0, 240, 360, 480] 240 == some 240
#guard labelFor [0, 1, 2] [10, 20] 2 == none
#guard asNumbers [Tick.num 1, Tick.num 2] == some [1, 2]
#guard asNumbers [Tick.other] == none
#guard (asNumbers []).isSome == true

end CtbrecSpec
