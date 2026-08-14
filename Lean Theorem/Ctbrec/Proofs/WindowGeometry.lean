/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the main window that comes back trimmed

Subject: `CamrecApplication.java:323-327` (restore) and `:388-402` (persist).

## The defect, measured on disk before it was modelled

`ctbrec/config/26.7.11/settings.json`, read live:

```
"windowWidth"  : 0
"windowHeight" : 0
"windowX"      : -7
"windowY"      : -7
```

The persisted size is **literally zero**. `CamrecApplication` reads those two numbers and hands
them straight to `new Scene(mainContainer, windowWidth, windowHeight)`, so the window is
restored collapsed — the "trimmed" window.

`-7` is the giveaway for the mechanism. On Windows a **maximized** window reports its origin at
`(-7, -7)` because the resize border overhangs the work area. So the app was maximized; during
teardown or iconification JavaFX reported a degenerate scene size; and the listeners at
`:388-389` wrote it into the settings unconditionally:

```java
scene.widthProperty().addListener((o, oldV, newV) -> settings.windowWidth = newV.intValue());
```

Every transient value is persisted, including the degenerate ones. There is no floor on write
and no sanity check on read, so one bad frame at shutdown poisons the next launch permanently.

## What is fixed

Two independent guards, because either one alone still leaves a hole:

1. **Write guard** — a degenerate geometry is never persisted. Stops the poison entering.
2. **Read guard** — geometry loaded from disk is sanitised before use. Repairs a settings file
   that is *already* poisoned, which every existing install is.

The write guard alone would leave this user's window broken forever; the read guard alone would
let the bad value keep being rewritten. Both, or the bug survives.

## The anti-weakening clause

The cheap "fix" is to stop persisting geometry at all, or to force a constant size. Both would
make the symptom vanish and destroy the feature — the window must still remember where the user
put it. `good_geometry_is_persisted_unchanged` and `sanitize_leaves_good_geometry_alone` exist
precisely to fail if someone does that.
-/
import Proofs.Ctbrec.MuxerDrain

namespace CtbrecSpec

/-! ## The model -/

/-- A screen's usable area. Measured on this machine: `working={X=0,Y=0,Width=1536,Height=824}`. -/
structure Screen where
  minX : Int
  minY : Int
  width : Int
  height : Int
  deriving DecidableEq, Repr

/-- A window geometry, as persisted in `settings.json`. -/
structure Geom where
  x : Int
  y : Int
  w : Int
  h : Int
  deriving DecidableEq, Repr

/-- Smallest width the main window may be restored at. Below this the tab headers and the
status bar overlap and the window is unusable. -/
def minWindowWidth : Int := 800

/-- Smallest height the main window may be restored at. -/
def minWindowHeight : Int := 600

/-- Clamp `v` into `[lo, hi]`. -/
def clampDim (v lo hi : Int) : Int :=
  if v < lo then lo else if v > hi then hi else v

/-! ### Clamp lemmas

Proved once and reused, rather than re-splitting the same `if` inside every theorem below. -/

theorem clampDim_lower (v lo hi : Int) (h : lo ≤ hi) : lo ≤ clampDim v lo hi := by
  unfold clampDim
  split
  · omega
  · split <;> omega

theorem clampDim_upper (v lo hi : Int) (h : lo ≤ hi) : clampDim v lo hi ≤ hi := by
  unfold clampDim
  split
  · omega
  · split <;> omega

theorem clampDim_id (v lo hi : Int) (h1 : lo ≤ v) (h2 : v ≤ hi) : clampDim v lo hi = v := by
  unfold clampDim
  split
  · omega
  · split <;> omega

theorem clampDim_idem (v lo hi : Int) (h : lo ≤ hi) :
    clampDim (clampDim v lo hi) lo hi = clampDim v lo hi :=
  clampDim_id _ _ _ (clampDim_lower v lo hi h) (clampDim_upper v lo hi h)

/-! ## The read guard -/

/-- Repair a geometry loaded from disk: never smaller than the minimum, never larger than the
screen, never positioned so an edge falls outside the usable area. -/
def sanitize (s : Screen) (g : Geom) : Geom :=
  let w := clampDim g.w minWindowWidth s.width
  let h := clampDim g.h minWindowHeight s.height
  { w := w
    h := h
    x := clampDim g.x s.minX (s.minX + s.width - w)
    y := clampDim g.y s.minY (s.minY + s.height - h) }

/-- A screen big enough to host the minimum window. Every theorem that needs it takes it as a
hypothesis rather than assuming it silently. -/
def RoomyScreen (s : Screen) : Prop :=
  minWindowWidth ≤ s.width ∧ minWindowHeight ≤ s.height

/-- **The restored window is never narrower than the minimum.** This is the theorem that
directly contradicts the observed `windowWidth : 0`. -/
theorem sanitize_width_is_at_least_minimum (s : Screen) (g : Geom) (hs : RoomyScreen s) :
    minWindowWidth ≤ (sanitize s g).w :=
  clampDim_lower _ _ _ hs.1

/-- **The restored window is never shorter than the minimum.** -/
theorem sanitize_height_is_at_least_minimum (s : Screen) (g : Geom) (hs : RoomyScreen s) :
    minWindowHeight ≤ (sanitize s g).h :=
  clampDim_lower _ _ _ hs.2

/-- The window never exceeds the screen either — the opposite failure, equally unusable. -/
theorem sanitize_width_fits_the_screen (s : Screen) (g : Geom) (hs : RoomyScreen s) :
    (sanitize s g).w ≤ s.width :=
  clampDim_upper _ _ _ hs.1

theorem sanitize_height_fits_the_screen (s : Screen) (g : Geom) (hs : RoomyScreen s) :
    (sanitize s g).h ≤ s.height :=
  clampDim_upper _ _ _ hs.2

/-- **The left edge is on screen.** Repairs the measured `windowX : -7`. -/
theorem sanitize_left_edge_is_visible (s : Screen) (g : Geom) (hs : RoomyScreen s) :
    s.minX ≤ (sanitize s g).x := by
  have hw : (sanitize s g).w ≤ s.width := sanitize_width_fits_the_screen s g hs
  exact clampDim_lower _ _ _ (by simp only [sanitize] at hw ⊢; omega)

/-- **The top edge is on screen.** Repairs the measured `windowY : -7`. -/
theorem sanitize_top_edge_is_visible (s : Screen) (g : Geom) (hs : RoomyScreen s) :
    s.minY ≤ (sanitize s g).y := by
  have hh : (sanitize s g).h ≤ s.height := sanitize_height_fits_the_screen s g hs
  exact clampDim_lower _ _ _ (by simp only [sanitize] at hh ⊢; omega)

/-- **The right edge is on screen** — the window cannot be pushed off to the right. -/
theorem sanitize_right_edge_is_visible (s : Screen) (g : Geom) (hs : RoomyScreen s) :
    (sanitize s g).x + (sanitize s g).w ≤ s.minX + s.width := by
  have hw : (sanitize s g).w ≤ s.width := sanitize_width_fits_the_screen s g hs
  have hx : (sanitize s g).x ≤ s.minX + s.width - (sanitize s g).w :=
    clampDim_upper _ _ _ (by simp only [sanitize] at hw ⊢; omega)
  omega

/-- **The bottom edge is on screen.** -/
theorem sanitize_bottom_edge_is_visible (s : Screen) (g : Geom) (hs : RoomyScreen s) :
    (sanitize s g).y + (sanitize s g).h ≤ s.minY + s.height := by
  have hh : (sanitize s g).h ≤ s.height := sanitize_height_fits_the_screen s g hs
  have hy : (sanitize s g).y ≤ s.minY + s.height - (sanitize s g).h :=
    clampDim_upper _ _ _ (by simp only [sanitize] at hh ⊢; omega)
  omega

/-- **Sanitising twice is the same as sanitising once.** A repair that keeps moving the window
on every launch would be its own bug. -/
theorem sanitize_is_idempotent (s : Screen) (g : Geom) (hs : RoomyScreen s) :
    sanitize s (sanitize s g) = sanitize s g := by
  have hw := clampDim_idem g.w minWindowWidth s.width hs.1
  have hh := clampDim_idem g.h minWindowHeight s.height hs.2
  have hxb : s.minX ≤ s.minX + s.width - clampDim g.w minWindowWidth s.width := by
    have := clampDim_upper g.w minWindowWidth s.width hs.1; omega
  have hyb : s.minY ≤ s.minY + s.height - clampDim g.h minWindowHeight s.height := by
    have := clampDim_upper g.h minWindowHeight s.height hs.2; omega
  have hx := clampDim_idem g.x s.minX
    (s.minX + s.width - clampDim g.w minWindowWidth s.width) hxb
  have hy := clampDim_idem g.y s.minY
    (s.minY + s.height - clampDim g.h minWindowHeight s.height) hyb
  simp only [sanitize, hw, hh, hx, hy]

/-- **ANTI-WEAKENING: a geometry that is already fine is returned untouched.** Without this,
"sanitise" could legally be "always return 1024x768 at the origin", which would destroy the
feature the user actually wants — the window remembering where they put it. -/
theorem sanitize_leaves_good_geometry_alone (s : Screen) (g : Geom)
    (hw : minWindowWidth ≤ g.w) (hw2 : g.w ≤ s.width)
    (hh : minWindowHeight ≤ g.h) (hh2 : g.h ≤ s.height)
    (hx : s.minX ≤ g.x) (hx2 : g.x + g.w ≤ s.minX + s.width)
    (hy : s.minY ≤ g.y) (hy2 : g.y + g.h ≤ s.minY + s.height) :
    sanitize s g = g := by
  have ew : clampDim g.w minWindowWidth s.width = g.w := clampDim_id _ _ _ hw hw2
  have eh : clampDim g.h minWindowHeight s.height = g.h := clampDim_id _ _ _ hh hh2
  -- Stated with the bound ALREADY rewritten by `ew`/`eh`: `simp only` rewrites the width
  -- inside the x-bound first, so a helper phrased over `clampDim g.w ...` no longer matches
  -- the goal it was meant to close.
  have ex : clampDim g.x s.minX (s.minX + s.width - g.w) = g.x :=
    clampDim_id _ _ _ hx (by omega)
  have ey : clampDim g.y s.minY (s.minY + s.height - g.h) = g.y :=
    clampDim_id _ _ _ hy (by omega)
  simp only [sanitize, ew, eh, ex, ey]

/-! ## The write guard -/

/-- Is this geometry safe to persist? Degenerate sizes are rejected at the source, so a
transient zero during teardown never reaches `settings.json`. -/
def shouldPersist (g : Geom) : Bool :=
  minWindowWidth ≤ g.w && minWindowHeight ≤ g.h

/-- **The measured poison is rejected.** `windowWidth: 0, windowHeight: 0` — the exact value
found in the live settings file — can no longer be written. -/
theorem the_measured_degenerate_geometry_is_never_persisted :
    shouldPersist { x := -7, y := -7, w := 0, h := 0 } = false := by decide

/-- More generally, nothing collapsed is ever persisted. -/
theorem zero_size_is_never_persisted (x y : Int) :
    shouldPersist { x := x, y := y, w := 0, h := 0 } = false := by
  simp [shouldPersist, minWindowWidth]

/-- **ANTI-WEAKENING: real geometry IS still persisted.** A write guard that rejected
everything would "fix" the bug by disabling the feature. -/
theorem good_geometry_is_persisted_unchanged :
    shouldPersist { x := 100, y := 80, w := 1400, h := 800 } = true := by decide

/-- The guard depends only on the size, never on the position — a window legitimately dragged
to a negative coordinate on a multi-monitor setup must still be saved. -/
theorem persistence_ignores_position (x1 y1 x2 y2 w h : Int) :
    shouldPersist { x := x1, y := y1, w := w, h := h }
      = shouldPersist { x := x2, y := y2, w := w, h := h } := by
  simp [shouldPersist]

/-! ## The two guards must meet

Measured after the first attempt at this fix: the read guard repaired the geometry for the
`Scene`, but nothing wrote the repaired value **back** into the settings. The `Scene` is
constructed before the listeners are attached, so no change event fires, and a graceful
shutdown saved the ORIGINAL poison — verified live, `windowWidth : 118` survived a clean
`Saving config to ... settings.json`.

Two consequences, and the second is the serious one:

* the settings file stays wrong forever, repaired again on every launch;
* "remember my window size" is dead until the user happens to resize by hand, because the
  restored size is always the sanitised minimum.

So the read guard must *persist* what it repaired. These theorems say that is always safe. -/

/-- **Whatever the read guard produces, the write guard accepts.** This is the property that
lets the repair be written back without a second round of checks — and it fails if either
guard's threshold is changed independently of the other. -/
theorem sanitised_geometry_is_always_persistable (s : Screen) (g : Geom) (hs : RoomyScreen s) :
    shouldPersist (sanitize s g) = true := by
  have hw := sanitize_width_is_at_least_minimum s g hs
  have hh := sanitize_height_is_at_least_minimum s g hs
  simp only [shouldPersist, Bool.and_eq_true, decide_eq_true_eq]
  exact ⟨hw, hh⟩

/-- **A repaired settings file loads unchanged.** The repair converges after one launch instead
of moving the window a little further every time. -/
theorem a_repaired_file_loads_unchanged (s : Screen) (g : Geom) (hs : RoomyScreen s) :
    sanitize s (sanitize s g) = sanitize s g :=
  sanitize_is_idempotent s g hs

/-! ## The measured case, end to end -/

/-- This machine's usable area, measured: `working={X=0,Y=0,Width=1536,Height=824}`. -/
def thisScreen : Screen := { minX := 0, minY := 0, width := 1536, height := 824 }

/-- The exact geometry found in the live `settings.json`. -/
def thePoisonedSettings : Geom := { x := -7, y := -7, w := 0, h := 0 }

theorem this_screen_is_roomy : RoomyScreen thisScreen := by
  constructor <;> decide

/-- **The measured broken settings are repaired to a usable window.** This is the theorem that
corresponds to what the user actually sees. -/
theorem the_poisoned_settings_are_repaired :
    sanitize thisScreen thePoisonedSettings = { x := 0, y := 0, w := 800, h := 600 } := by
  decide

/-- The measured poison, repaired, is persistable — the concrete instance of
`sanitised_geometry_is_always_persistable`, and the reason the write-back is safe. -/
theorem the_repaired_poison_can_be_written :
    shouldPersist (sanitize thisScreen thePoisonedSettings) = true := by decide

/-- And the *unrepaired* poison cannot, which is exactly why the write-back must happen after
the sanitiser rather than before it. -/
theorem the_raw_poison_cannot_be_written :
    shouldPersist thePoisonedSettings = false := by decide

/-- The other measured poison, captured live after a teardown with the old code: 118 x 0. -/
theorem the_second_measured_poison_is_repaired :
    sanitize thisScreen { x := 0, y := 0, w := 118, h := 0 }
      = { x := 0, y := 0, w := 800, h := 600 } := by decide

/-- And a window the user deliberately sized survives untouched.

The first version of this example used `w := 1400, h := 800` and Lean rejected it — correctly.
On an 824-tall work area a window 800 tall can start no lower than `y = 24`, so `y := 80` puts
its bottom edge off screen and `sanitize` pulls it up. The example was wrong, not the spec;
`a_tall_window_is_pulled_up_not_shrunk` below pins that behaviour deliberately. -/
theorem a_deliberate_size_survives :
    sanitize thisScreen { x := 100, y := 80, w := 1200, h := 700 }
      = { x := 100, y := 80, w := 1200, h := 700 } := by decide

/-- **A window too low on the screen is MOVED, not shrunk.** Preserving the user's chosen size
matters more than preserving the position, so the repair adjusts the cheaper of the two. -/
theorem a_tall_window_is_pulled_up_not_shrunk :
    sanitize thisScreen { x := 100, y := 80, w := 1400, h := 800 }
      = { x := 100, y := 24, w := 1400, h := 800 } := by decide

/-! ## The second write path

`CamrecApplication.applyWindowReset` is a *separate* writer of the same two settings. It stores
`calculateResetWindowBounds()`, which is 50 % of the visual bounds. On this machine that is
768 x 412 — **below the minimum the restore path enforces**. Two writers disagreeing about the
same field is how an invariant rots, so both are routed through `sanitize`. -/

/-- What `calculateResetWindowBounds` produces on this machine: 50 % of 1536 x 824. -/
def resetBounds : Geom :=
  { x := 384, y := 206, w := 768, h := 412 }

/-- **The reset path alone would violate the minimum.** Stated so the reason the second call
site exists cannot be quietly deleted as redundant. -/
theorem reset_bounds_are_below_the_minimum :
    resetBounds.w < minWindowWidth ∧ resetBounds.h < minWindowHeight := by decide

/-- **Sanitised, the reset path agrees with the restore path.** -/
theorem reset_bounds_are_repaired :
    sanitize thisScreen resetBounds = { x := 384, y := 206, w := 800, h := 600 } := by decide

/-- **Both writers land on a geometry the other would accept.** This is the real invariant:
whatever path wrote the setting, sanitising it again changes nothing. -/
theorem both_write_paths_agree (g : Geom) :
    sanitize thisScreen (sanitize thisScreen g) = sanitize thisScreen g :=
  sanitize_is_idempotent thisScreen g this_screen_is_roomy

/-! ## What is NOT claimed

Lean constrains the geometry arithmetic: the restored window is on screen, at least the minimum
size, and a good geometry is untouched. It says nothing about *when* JavaFX reports a degenerate
size — that is a toolkit behaviour, observed rather than modelled. The write guard is what makes
the timing irrelevant: whatever JavaFX reports, a degenerate value is not written. -/

#guard shouldPersist thePoisonedSettings == false
#guard shouldPersist { x := 100, y := 80, w := 1400, h := 800 } == true
#guard sanitize thisScreen thePoisonedSettings == { x := 0, y := 0, w := 800, h := 600 }
#guard (sanitize thisScreen { x := 5000, y := 5000, w := 99999, h := 99999 })
    == { x := 0, y := 0, w := 1536, h := 824 }
#guard minWindowWidth == 800
#guard minWindowHeight == 600

end CtbrecSpec
