/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: P3 -- the PiP geometry laws, QUANTIFIED, never a frozen constant.

The item's own instruction: "Each a quantified geometry law, never a frozen constant." That is the
whole design constraint of this file, and it is the rule that keeps a spec from expiring: a theorem
about today's 20-window cap or today's 0.5625 aspect ratio goes RED the day the Socio legitimately
changes either, and the obvious repair -- weakening the theorem -- destroys the coverage. So every
theorem below is stated over the variable that moves, and the present values live only in `#guard`s.

MEASURED from the source, cited:
  PipPreviewLauncher.java:31   DEFAULT_ASPECT_RATIO = 0.5625   (= 9/16, height/width)
  PipPreviewLauncher.java:57   w = max(480, thumbWidth * 2)
  PipPreviewLauncher.java:58   h = round(w * aspectRatio)
  PreviewPipeline.evenize      both dimensions forced even (yuv/bgra alignment)

Rationals are avoided: aspect ratio is modelled as a pair of naturals (num/den), which is how a
"16:9 preset" is actually specified and which keeps every proof decidable. 0.5625 = 9/16 exactly, so
nothing is lost -- and `the_default_ratio_is_exactly_nine_sixteenths` pins that as a `#guard`, not as
a hypothesis anything rests on.

NOT PROVED: that a window is visible, that a snap looks right, or that click-through feels correct.
Those are the Socio's eyes. What is proved is that the arithmetic cannot produce a degenerate window,
that the cap cannot be exceeded, that snapping is idempotent and cannot move a window off-screen, and
that opacity stays inside its legal range.
-/

namespace Proofs.Ctbrec.PipGeometry

/-! ## Aspect lock -/

/-- An aspect ratio as it is really specified: a pair of naturals, height/width. -/
structure Ratio where
  num : Nat   -- height
  den : Nat   -- width
  deriving Repr, DecidableEq

/-- Force even, as `PreviewPipeline.evenize` does: bgra/yuv want aligned dimensions. -/
def evenize (n : Nat) : Nat := n - n % 2

/-- Height locked to width by the ratio, then evenized. -/
def lockHeight (r : Ratio) (width : Nat) : Nat := evenize (width * r.num / r.den)

/-- A window: width and the height the lock produced. -/
structure Window where
  w : Nat
  h : Nat
  deriving Repr, DecidableEq

def lock (r : Ratio) (minW width : Nat) : Window :=
  let w := evenize (max minW width)
  { w := w, h := lockHeight r w }

theorem evenize_is_even (n : Nat) : (evenize n) % 2 = 0 := by
  simp only [evenize]
  omega

theorem evenize_never_grows (n : Nat) : evenize n ≤ n := by
  simp only [evenize]
  omega

/-- QUANTIFIED, over every ratio and every requested width: the floor is never violated.
A frozen `w = 480` theorem would have expired the first time `thumbWidth` changed. -/
theorem the_width_floor_is_never_violated (r : Ratio) (minW width : Nat) (hm : minW % 2 = 0) :
    minW ≤ (lock r minW width).w := by
  simp only [lock, evenize]
  omega

/-- A locked window is never degenerate in width, for any positive floor. -/
theorem a_locked_window_has_positive_width (r : Ratio) (minW width : Nat)
    (hm : minW % 2 = 0) (hp : 0 < minW) : 0 < (lock r minW width).w := by
  have := the_width_floor_is_never_violated r minW width hm
  omega

/-- Both dimensions come out even, whatever the ratio and the request. -/
theorem a_locked_window_is_even (r : Ratio) (minW width : Nat) :
    (lock r minW width).w % 2 = 0 ∧ (lock r minW width).h % 2 = 0 := by
  refine ⟨evenize_is_even _, ?_⟩
  simp only [lock, lockHeight]
  exact evenize_is_even _

/-- A wider window is never shorter: the lock is monotone. This is the law that makes a resize
predictable, and it holds for EVERY ratio rather than for 16:9. -/
theorem the_lock_is_monotone_in_width (r : Ratio) (w1 w2 : Nat) (h : w1 ≤ w2) :
    lockHeight r w1 ≤ lockHeight r w2 := by
  simp only [lockHeight, evenize]
  have : w1 * r.num / r.den ≤ w2 * r.num / r.den :=
    Nat.div_le_div_right (Nat.mul_le_mul_right _ h)
  omega

/-! ## The window cap -/

/-- Admit a new window only under the cap. `cap` is a parameter, never a literal. -/
def admitWindow (cap : Nat) (open_ : Nat) : Bool := open_ < cap

theorem the_cap_is_never_exceeded (cap open_ : Nat) (h : admitWindow cap open_ = true) :
    open_ + 1 ≤ cap := by
  simp only [admitWindow, decide_eq_true_eq] at h
  omega

/-- At the cap, nothing more is admitted — for any cap, including a future one. -/
theorem at_the_cap_nothing_is_admitted (cap : Nat) : admitWindow cap cap = false := by
  simp [admitWindow]

/-- A cap of zero admits nothing: the degenerate configuration is safe, not a crash. -/
theorem a_zero_cap_admits_nothing (open_ : Nat) : admitWindow 0 open_ = false := by
  simp [admitWindow]

/-- Closing a window always makes room again — no leak of cap slots. -/
theorem closing_frees_a_slot (cap open_ : Nat) (hc : 0 < cap) (h : open_ ≤ cap) :
    admitWindow cap (open_ - 1) = true ∨ open_ = 0 := by
  rcases Nat.eq_zero_or_pos open_ with h0 | hp
  · exact Or.inr h0
  · left
    simp only [admitWindow, decide_eq_true_eq]
    omega

/-! ## Snap -/

/-- Snap a coordinate to the nearer edge of a screen span, within a threshold. -/
def snap (threshold span pos : Nat) : Nat :=
  if pos ≤ threshold then 0
  else if span ≤ pos + threshold then span
  else pos

/--
Snapping is IDEMPOTENT: snapping a snapped window does not drift.

THE SIDE CONDITION IS REAL AND WAS FOUND BY THE PROOF FAILING, not assumed for convenience. Without
`threshold < span` the statement is FALSE: if the snap zone covers the whole screen, a window snapped
to the far edge `span` is then within `threshold` of the near edge, so the next snap moves it to 0 and
it oscillates. Lean's leftover goal was literally `0 = span`. `threshold < span` — the snap zone cannot
cover the entire screen — is the condition any sane configuration satisfies, and it is now stated
instead of silently required.
-/
theorem snapping_is_idempotent (threshold span pos : Nat) (ht : threshold < span) :
    snap threshold span (snap threshold span pos) = snap threshold span pos := by
  simp only [snap]
  by_cases h1 : pos ≤ threshold
  · simp [h1]
  · by_cases h2 : span ≤ pos + threshold
    · have h3 : ¬ span ≤ threshold := by omega
      simp [h1, h2, h3]
    · simp [h1, h2]

/--
THE HYPOTHESIS ABOVE IS NECESSARY, and here is the counterexample rather than my word for it. With
`threshold = 100` on a `span = 50` screen, a window at 200 snaps to the far edge 50, and snapping THAT
lands on 0 — the window oscillates between the two edges forever. So `snapping_is_idempotent` is not a
weakened convenience; the unconditional statement is simply false, and this is what refutes it.
-/
theorem idempotence_genuinely_fails_when_the_zone_covers_the_screen :
    snap 100 50 200 = 50 ∧ snap 100 50 (snap 100 50 200) = 0 := by
  decide

/-- Snap never pushes a window past the screen. -/
theorem snap_stays_on_screen (threshold span pos : Nat) (h : pos ≤ span) :
    snap threshold span pos ≤ span := by
  simp only [snap]
  split
  · omega
  · split <;> omega

/-- With a zero threshold, snap is the identity — the feature can be turned off without a
special case, and that is a property, not a coincidence. -/
theorem a_zero_threshold_snaps_nothing (span pos : Nat) (hp : 0 < pos) (hs : pos < span) :
    snap 0 span pos = pos := by
  simp only [snap]
  split
  · omega
  · split <;> omega

/-! ## Opacity -/

/-- Opacity in percent, clamped. Both bounds are parameters. -/
def clampOpacity (lo hi v : Nat) : Nat := max lo (min hi v)

theorem opacity_stays_in_range (lo hi v : Nat) (h : lo ≤ hi) :
    lo ≤ clampOpacity lo hi v ∧ clampOpacity lo hi v ≤ hi := by
  simp only [clampOpacity]
  omega

/-- A window can never be made fully invisible when the floor forbids it: the clamp is the only
gate, and it holds for every requested value including 0. -/
theorem a_window_cannot_be_made_invisible (lo hi : Nat) (h : lo ≤ hi) (hp : 0 < lo) :
    0 < clampOpacity lo hi 0 := by
  have := (opacity_stays_in_range lo hi 0 h).1
  omega

theorem clamping_is_idempotent (lo hi v : Nat) (h : lo ≤ hi) :
    clampOpacity lo hi (clampOpacity lo hi v) = clampOpacity lo hi v := by
  simp only [clampOpacity]
  omega

/-! ## The present values — as `#guard`s ONLY, never as hypotheses

Each of these is a contingent fact of today's build. If the Socio changes the cap to 30 or the default
ratio to 4:3, these guards change in the same edit and NOT ONE THEOREM ABOVE MOVES. That is the point
of the item's "never a frozen constant".
-/

-- DEFAULT_ASPECT_RATIO = 0.5625 at PipPreviewLauncher.java:31, i.e. exactly 9/16.
#guard 9 * 10000 / 16 == 5625
-- w = max(480, thumbWidth * 2) at PipPreviewLauncher.java:57, with thumbWidth 180 -> 480 floor wins.
#guard (lock { num := 9, den := 16 } 480 360).w == 480
#guard (lock { num := 9, den := 16 } 480 360).h == 270
-- A 960-wide window at 9:16 -> 540, both even.
#guard (lock { num := 9, den := 16 } 480 960).w == 960
#guard (lock { num := 9, den := 16 } 480 960).h == 540
-- An odd request is evenized down, never up.
#guard (lock { num := 9, den := 16 } 480 961).w == 960
-- A 4:3 preset would work identically -- the laws do not know about 16:9.
#guard (lock { num := 3, den := 4 } 480 800).h == 600
-- The cap the item names today.
#guard admitWindow 20 19 == true
#guard admitWindow 20 20 == false
-- Snap with a 12 px threshold on a 1920 span.
#guard snap 12 1920 5 == 0
#guard snap 12 1920 1910 == 1920
#guard snap 12 1920 900 == 900
-- Opacity 20..100.
#guard clampOpacity 20 100 0 == 20
#guard clampOpacity 20 100 150 == 100
#guard clampOpacity 20 100 55 == 55

end Proofs.Ctbrec.PipGeometry
