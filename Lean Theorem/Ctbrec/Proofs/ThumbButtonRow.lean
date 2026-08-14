/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Authors: ctbrec-rework
-/

/-!
# The thumbnail overlay button row — placeable for ANY number of buttons

CP83 needs a THIRD button (speaker/volume) in the bottom-right row of `ThumbCell`, beside the
existing PiP and Play buttons. The existing spec fixed the two-button case; a two-button theorem
cannot license a third button, and hard-coding `52` for the speaker would be the same
contingent-constant defect all over again.

So the row is modelled as a FUNCTION of the button index. Measured from
`src/app/ctbrec/ui/tabs/ThumbCell.java`:

```
PIP_BUTTON_MARGIN      = 4.0    (:143)
PIP_BUTTON_SIZE        = 20.0   (:142)
PLAY_BUTTON_GAP        = 4.0    (:150)
PLAY_BUTTON_RIGHT_INSET = PIP_BUTTON_MARGIN + PIP_BUTTON_SIZE + PLAY_BUTTON_GAP  (:151-152)
PIP_BUTTON_BOTTOM_INSET = 29.0  (:144)
```

All five are whole numbers, so `Nat` models them exactly -- no float reasoning, and `decide`
works. Buttons are laid out right-to-left from the BOTTOM_RIGHT corner: button `k` sits at
right-inset `inset k`, and occupies the horizontal band `[inset k, inset k + size)`.

The durable statements are `insets_strictly_increase`, `clearance_is_exactly_the_gap` and
`buttons_never_overlap` -- each quantified over the button INDEX, so adding the speaker (or a
fourth button later) is licensed by the same theorems rather than needing new ones.
-/

namespace CtbrecSpec.ThumbButtonRow

/-- Right inset of the first (rightmost) button. `ThumbCell.java:143`. -/
def margin : Nat := 4

/-- Edge length of a square overlay button. `ThumbCell.java:142`. -/
def size : Nat := 20

/-- Clear space between adjacent buttons. `ThumbCell.java:150`. -/
def gap : Nat := 4

/-- Distance from one button's right edge to the next one's. -/
def pitch : Nat := size + gap

/-- Right inset of button `k`, counting from the right edge: 0 = PiP, 1 = Play, 2 = speaker. -/
def inset (k : Nat) : Nat := margin + k * pitch

/-- Right edge of the band occupied by button `k` (exclusive upper bound). -/
def rightEdge (k : Nat) : Nat := inset k + size

-- The two deployed buttons must come out at exactly the values in the running app.
#guard inset 0 = 4
#guard inset 1 = 28   -- PLAY_BUTTON_RIGHT_INSET, ThumbCell.java:151
#guard inset 2 = 52   -- the speaker button CP83 will add
#guard pitch = 24

/-- Insets grow strictly with the index: no two buttons share a position. -/
theorem insets_strictly_increase (k : Nat) : inset k < inset (k + 1) := by
  unfold inset pitch size gap margin
  omega

/-- The clearance between button `k` and button `k+1` is EXACTLY the gap, at every index.
This is the property the two-button spec asserted only for the one pair that existed. -/
theorem clearance_is_exactly_the_gap (k : Nat) :
    inset (k + 1) - rightEdge k = gap := by
  simp only [rightEdge, inset, pitch, size, gap, margin]
  omega

/-- Distinct buttons never overlap: the band of `k` ends strictly before the band of `k+1`
begins. Stated via `rightEdge` so it is about the OCCUPIED SPACE, not merely the anchors. -/
theorem buttons_never_overlap (k : Nat) : rightEdge k < inset (k + 1) := by
  simp only [rightEdge, inset, pitch, size, gap, margin]
  omega

/-- The general non-overlap: any two distinct buttons occupy disjoint bands. -/
theorem distinct_buttons_are_disjoint {j k : Nat} (h : j < k) : rightEdge j < inset k := by
  simp only [rightEdge, inset, pitch, size, gap, margin]
  have : j + 1 ≤ k := h
  have : j * 24 + 24 ≤ k * 24 := by
    have := Nat.mul_le_mul_right 24 this
    omega
  omega

/-- `n` buttons fit within a cell of width `w` exactly when the leftmost band ends inside it. -/
def fits (n w : Nat) : Prop := n = 0 ∨ rightEdge (n - 1) ≤ w

instance (n w : Nat) : Decidable (fits n w) := by unfold fits; infer_instance

/-- The smallest thumbnail rung in the app is 140 px wide. -/
def smallestRung : Nat := 140

-- Two buttons fit today; THREE fit too, which is what licenses CP83.
#guard decide (fits 2 smallestRung)
#guard decide (fits 3 smallestRung)
#guard decide (fits 5 smallestRung)

/-- Three buttons fit on the smallest rung -- the speaker button is placeable. -/
theorem three_buttons_fit_the_smallest_rung : fits 3 smallestRung := by decide

/-- NEGATIVE CONTROL. The bound is real: a row of 6 buttons does NOT fit the smallest rung,
so `fits` is not vacuously true and the theorem above carries information. -/
theorem six_buttons_do_not_fit : ¬ fits 6 smallestRung := by decide

/-- Anti-amputation: the row is an ORDERING RULE, not a hard-coded set of three positions.
A fourth button lands at 76 by the same formula, with the same clearance. -/
theorem a_fourth_button_is_licensed_too :
    inset 3 = 76 ∧ inset 3 - rightEdge 2 = gap := by
  constructor
  · decide
  · exact clearance_is_exactly_the_gap 2

/-- Every button in a fitting row lies entirely inside the cell. The durable safety property:
it quantifies over the index rather than naming the three that exist today. -/
theorem a_fitting_row_keeps_every_button_inside
    {n w k : Nat} (hfit : fits n w) (hk : k < n) : rightEdge k ≤ w := by
  cases hfit with
  | inl h => omega
  | inr h =>
    have hle : k ≤ n - 1 := by omega
    have : rightEdge k ≤ rightEdge (n - 1) := by
      simp only [rightEdge, inset, pitch, size, gap, margin]
      have := Nat.mul_le_mul_right 24 hle
      omega
    omega

end CtbrecSpec.ThumbButtonRow
