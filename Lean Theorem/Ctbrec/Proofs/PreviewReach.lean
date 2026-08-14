/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CP161 -- A CONTROL WITHOUT A SINK IS WORSE THAN A MISSING CONTROL.

Measured 2026-08-10, from the Socio: volume "wasn't also added" to the preview near the thumbnails.
What the tree actually contained:

  * `ThumbCell.createVolumeButton` EXISTED in source (CP83) and wrote `PreviewVolumeBus` -- but
    `unzip -l ctbrec-26.7.11.jar` + `javap -c` on the shipped `ThumbCell.class` (37 217 bytes,
    2026-08-10 00:36) measured `createVolumeButton` refs = 0 and `PreviewVolumeBus` refs = 0. The
    class in the artifact was 15 hours older than its source; `pre-speaker.bak` is byte-identical,
    so the CP83 deploy never wrote it. PROVED + WRITTEN != DEPLOYED, again (see `Deployment`).
  * `InlinePreview` -- the surface that button sits on -- had NO audio leg at all:
    `grep -c buildAudioArgs InlinePreview.java` = 0. So even deployed, the button would have
    controlled nothing.

The second point is the one worth a law. A visible control over a capability that does not exist is
not a partial feature; it is a false claim the user can click. This module says that, quantified
over an arbitrary surface, so it also covers the next surface someone adds.

It also fixes the wheel step as a FUNCTION of the range instead of the literal 100, for the same
reason the ffmpeg parser had to stop matching a hardcoded semver shape: a constant that happens to
be right today is a defect waiting for the day the range changes.
-/

namespace CtbrecSpec.PreviewReach

/-! ## 1. Reach: a control must have a sink

`hasControl` = there is a UI affordance for volume on this surface.
`hasSink`    = there is something that actually renders audio (a real ffmpeg PCM leg). -/

structure Surface where
  name       : String
  hasControl : Bool
  hasSink    : Bool
  deriving DecidableEq, Repr

/-- What the user hears: only a surface with a sink can be audible, and only above zero. -/
def audible (s : Surface) (level : Nat) : Bool := s.hasSink && 0 < level

/-- A surface is HONEST when every control it shows is backed by a sink. -/
def honest (s : Surface) : Bool := !s.hasControl || s.hasSink

/-- THE LAW. On a surface with no sink, the volume control cannot change the outcome for ANY two
settings -- so the widget is inert by construction, not merely untested. -/
theorem a_control_without_a_sink_changes_nothing
    (s : Surface) (h : s.hasSink = false) (v w : Nat) : audible s v = audible s w := by
  simp [audible, h]

/-- ...and the outcome it cannot change is silence. -/
theorem a_sinkless_surface_is_always_silent (s : Surface) (h : s.hasSink = false) (v : Nat) :
    audible s v = false := by simp [audible, h]

/-- Conversely, a surface WITH a sink is genuinely controllable: two settings differ. This is what
keeps `honest` from being satisfiable by making everything silent. -/
theorem a_surface_with_a_sink_is_controllable (s : Surface) (h : s.hasSink = true) :
    audible s 0 = false ∧ audible s 1 = true := by simp [audible, h]

/-! ## 2. The two surfaces, before and after

`shippedInline` is the measured state of the thumbnail preview on 2026-08-10: a control in source,
no audio sink anywhere. `shippedPip` had both. -/

def shippedInline : Surface := ⟨"InlinePreview", true, false⟩
def shippedPip : Surface := ⟨"PipPreviewWindow", true, true⟩

def fixedInline : Surface := ⟨"InlinePreview", true, true⟩
def fixedPip : Surface := ⟨"PipPreviewWindow", true, true⟩

/-- The defect, exhibited rather than asserted. -/
theorem the_shipped_thumbnail_surface_was_dishonest : honest shippedInline = false := by decide

/-- The PiP surface was already honest -- so the repair is not a rewrite of what worked. -/
theorem the_pip_surface_was_already_honest : honest shippedPip = true := by decide

/-- BOTH surfaces are honest after CP161. This is the Socio's request stated as a check. -/
theorem both_surfaces_are_honest_now :
    ([fixedInline, fixedPip].all honest) = true := by decide

/-- And the mute button on the thumbnail now controls something real. -/
theorem the_thumbnail_control_now_reaches_audio :
    audible fixedInline 500 = true ∧ audible shippedInline 500 = false := by decide

/-- Anti-amputation: honesty must not be reachable by DELETING the control. Both repairs keep the
control -- the sink is what changed. A future "fix" that removes the button would satisfy `honest`
and fail this. -/
theorem the_repair_kept_the_control :
    fixedInline.hasControl = true ∧ fixedPip.hasControl = true := by decide

/-- The dishonest state is exactly "control without sink", for every surface -- so the criterion
cannot be met by accident. -/
theorem dishonest_iff_control_without_sink (s : Surface) :
    honest s = false ↔ (s.hasControl = true ∧ s.hasSink = false) := by
  cases s with
  | mk name c k => cases c <;> cases k <;> simp [honest]

/-! ## 3. The wheel: a step defined FROM the range, never frozen

`ThumbCell.VOLUME_WHEEL_STEP = PreviewVolumeState.MAX_VOL / 10`. The literal 100 would be true of
today's MAX_VOL = 1000 and silently wrong the day it moves -- the same shape of defect as the
semver ffmpeg parser that discarded the newest binary. -/

def step (maxVol : Nat) : Nat := maxVol / 10

/-- Clamped scroll, mirroring `PreviewVolumeState.clamp (before.effective() + step)`. -/
def wheel (maxVol level : Nat) (up : Bool) : Nat :=
  if up then min maxVol (level + step maxVol) else level - step maxVol

theorem the_wheel_never_leaves_the_range (maxVol level : Nat) (up : Bool) (h : level ≤ maxVol) :
    wheel maxVol level up ≤ maxVol := by
  cases up <;> simp [wheel] <;> omega

/-- `n` notches up from `level`. Written out rather than as `Function.iterate`, which lives in
Mathlib and this spec deliberately does not import. -/
def wheelUp (maxVol : Nat) : Nat → Nat → Nat
  | level, 0 => level
  | level, (n + 1) => wheelUp maxVol (wheel maxVol level true) n

/-- Ten notches of a range divisible by ten cover it exactly -- the granularity claim, stated over
an arbitrary `k` rather than measured at 1000. -/
theorem ten_notches_span_a_divisible_range (k : Nat) : 10 * step (10 * k) = 10 * k := by
  have hstep : step (10 * k) = k := by
    simp only [step]
    omega
  simp [hstep]

/-- HONEST LIMIT, stated because the pretty version is false: with floor division a range that is
NOT a multiple of ten is not covered by ten notches, and 1005 is the witness. Ten notches of 100
leave 5 behind. The clamp in `wheel` is what keeps that from mattering (the top is still reachable),
but the arithmetic claim must not be overstated. -/
theorem ten_notches_undershoot_an_indivisible_range :
    10 * step 1005 ≠ 1005 := by decide

/-- The top IS still reachable on such a range, because the step is clamped -- so the limitation
above is about arithmetic, not about the user being unable to reach full volume. -/
theorem the_clamp_still_reaches_the_top : wheel 1005 1000 true = 1005 := by decide

/-- THE DURABILITY CLAUSE. The step follows the maximum: it is not the literal 100. Stated for an
arbitrary range, which is what makes the next change to MAX_VOL safe. -/
theorem the_step_follows_the_maximum (m : Nat) : step m = m / 10 := rfl

/-- Negative control -- a frozen step does NOT follow the range, and the witness is a range someone
could plausibly choose. -/
def frozenStep (_maxVol : Nat) : Nat := 100

theorem a_frozen_step_stops_matching_the_range :
    frozenStep 200 ≠ step 200 := by decide

/-- Scrolling down from silence cannot underflow -- Nat subtraction saturates, and the clamp in the
Java agrees. -/
theorem the_wheel_cannot_go_below_zero (maxVol : Nat) : wheel maxVol 0 false = 0 := by
  simp [wheel]

/-! ## 4. Executable checks -- the constants of the running app, pinned -/

-- PreviewVolumeState.MAX_VOL = 1000 (src/common/ctbrec/preview/PreviewVolumeState.java:22)
#guard step 1000 = 100
#guard wheelUp 1000 0 10 = 1000
#guard wheelUp 1000 0 3 = 300
#guard wheelUp 1000 0 15 = 1000
#guard wheel 1000 0 true = 100
#guard wheel 1000 950 true = 1000
#guard wheel 1000 50 false = 0
#guard honest shippedInline = false
#guard honest fixedInline = true
#guard ([fixedInline, fixedPip].all honest) = true
#guard audible shippedInline 1000 = false
#guard audible fixedInline 1 = true

end CtbrecSpec.PreviewReach
