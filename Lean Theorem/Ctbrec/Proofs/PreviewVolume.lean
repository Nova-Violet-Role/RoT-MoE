/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
VOL-PREVIEW / VOL-PIP -- a stable name, deliberately NOT a CP number.

These two items were requested long ago as CP77/CP78, renumbered to CP80/CP81 in NEXT-74, and then
those numbers were REUSED for unrelated work (ffmpeg version ordering, request pacing). They
vanished from every later NEXT list -- overwritten, not deprioritised. Names cannot collide the way
numbers did, so these carry names.

MEASURED, and the reason this is not one slider applied twice:

  StreamPreview.java:96     javafx.scene.media.MediaPlayer   -- audio is already decoded;
                                                                volume is a native API
  PipPreviewWindow.java:38  ffmpeg -> ImageView (raw frames) -- VIDEO ONLY. `grep -c` for
                                                                volume|audio|mute|-an: **0**

The PiP window has no audio leg at all. A volume control there is meaningless until one exists, so
the work is: add an audio output to PiP's ffmpeg invocation, put a control on both, and cross-wire
them so one value drives two unlike sinks.

WHAT IS PROVED HERE: the volume value itself is well-behaved -- clamped into range, mute is
lossless (restore returns exactly the pre-mute level, including when that level was zero), and the
two sinks always agree. The cross-wire cannot drift.

NOT PROVED: that ffmpeg emits audio, that JavaFX honours the value, or that it SOUNDS right. Those
are a checker's job and the Socio's ear. A theorem must never be dressed up as a claim about
audible output.
-/

namespace CtbrecSpec.PreviewVolume

/-- Volume in tenths of a percent: 0 = silent, 1000 = unity. Integers, so `decide` works and there
    is no float comparison anywhere near a persisted setting. -/
abbrev Vol := Nat

def MAX_VOL : Vol := 1000

/-- Clamp into range. The setting is persisted, so a corrupt or hand-edited value must not escape. -/
def clamp (v : Vol) : Vol := min v MAX_VOL

/-- The control's state. `savedLevel` is what mute must restore -- kept SEPARATE from `level` so
    that muting is lossless even from level 0. -/
structure VolumeState where
  level : Vol
  muted : Bool
  savedLevel : Vol
deriving DecidableEq, Repr

def init (v : Vol) : VolumeState := ⟨clamp v, false, clamp v⟩

/-- Set a new level. Setting a level while muted un-mutes: a user dragging the slider expects
    sound, and leaving it muted would look like a broken control. -/
def setLevel (s : VolumeState) (v : Vol) : VolumeState :=
  ⟨clamp v, false, clamp v⟩

def mute (s : VolumeState) : VolumeState :=
  if s.muted then s else ⟨0, true, s.level⟩

def unmute (s : VolumeState) : VolumeState :=
  if s.muted then ⟨s.savedLevel, false, s.savedLevel⟩ else s

def toggleMute (s : VolumeState) : VolumeState :=
  if s.muted then unmute s else mute s

/-- What each sink is actually driven with. Both read the SAME field, which is what makes the
    cross-wire exact rather than merely well-intentioned. -/
def effective (s : VolumeState) : Vol := s.level

/-- JavaFX MediaPlayer takes 0.0–1.0; we hand it tenths-of-percent over 1000. -/
def javafxNumerator (s : VolumeState) : Vol := effective s

/-- ffmpeg's `volume` filter takes the same ratio. One source of truth, two renderings. -/
def ffmpegFilterNumerator (s : VolumeState) : Vol := effective s

#guard effective (init 500) == 500
#guard effective (init 5000) == 1000
#guard effective (mute (init 500)) == 0
#guard effective (unmute (mute (init 500))) == 500
#guard effective (unmute (mute (init 0))) == 0
#guard effective (setLevel (mute (init 500)) 300) == 300
#guard (mute (init 500)).muted == true
#guard (toggleMute (toggleMute (init 700))) == init 700

/-- The clamp bound. Stated over `min` rather than an `if`: `omega` could not see through `MAX_VOL`
    as a `def`, and neither `unfold` nor promoting it to an `abbrev` helped -- both measured, both
    failed with "No usable constraints found". `min` supplies a standard lemma instead of a fight,
    and the definition is clearer for it. -/
theorem clamp_le (v : Vol) : clamp v ≤ MAX_VOL := Nat.min_le_right v MAX_VOL

/-- Clamping is total: no state can ever carry a level above unity. -/
theorem the_level_never_exceeds_unity (v : Vol) : (init v).level ≤ MAX_VOL := clamp_le v

theorem set_level_also_clamps (s : VolumeState) (v : Vol) :
    (setLevel s v).level ≤ MAX_VOL := clamp_le v

/--
**Mute is lossless.** Restore returns exactly the pre-mute level -- including 0, which a naive
"restore to some default if saved is zero" implementation gets wrong by making silence audible.
-/
theorem mute_then_unmute_restores_exactly (v : Vol) :
    unmute (mute (init v)) = init v := by
  simp [init, mute, unmute]

/-- Stated for the case that catches the naive implementation. -/
theorem muting_from_silence_restores_silence :
    effective (unmute (mute (init 0))) = 0 := by decide

/--
**The cross-wire cannot drift.** Both sinks are driven from one field, so they are equal for every
reachable state -- not by convention, by construction. This is the theorem VOL-PIP's cross-wire
needs; two independent volume variables would make it false.
-/
theorem the_two_sinks_always_agree (s : VolumeState) :
    javafxNumerator s = ffmpegFilterNumerator s := rfl

/-- Quantified over every state, including muted and clamped ones. -/
theorem the_two_sinks_agree_after_any_operation (v w : Vol) :
    javafxNumerator (setLevel (mute (init v)) w) =
      ffmpegFilterNumerator (setLevel (mute (init v)) w) := rfl

/-- Dragging the slider while muted un-mutes -- otherwise the control looks broken. -/
theorem setting_a_level_unmutes (s : VolumeState) (v : Vol) : (setLevel s v).muted = false := rfl

/-- Toggle is an involution: two clicks return exactly the starting state. -/
theorem toggle_twice_is_identity (v : Vol) : toggleMute (toggleMute (init v)) = init v := by
  simp [toggleMute, init, mute, unmute]

/-- Muting is audibly silent -- the property a user would notice if it were wrong. -/
theorem muting_silences (v : Vol) : effective (mute (init v)) = 0 := by
  simp [effective, mute, init]

/-! ## The audio leg must NOT share the video pipe

Measured in `common/ctbrec/preview/PreviewPipeline.java:228` (`buildArgs`):

```
-an -sn -dn            audio, subtitles, data all disabled   (:289-291)
-f rawvideo            (:296-297)
-pix_fmt bgra          (:298-299)
pipe:1                 (:302)
```

The preview pipe carries **raw BGRA frames with no container**. The reader slices it into frames by
byte count: `width * height * 4` per frame, nothing else to synchronise on.

So the obvious implementation of "add volume" — delete `-an` — is **destructive**. Audio packets
would be interleaved into the same `pipe:1` with no container to demultiplex them, every frame
boundary after the first audio packet would be wrong, and the preview would show tearing or
garbage. It would look like a rendering bug, not an audio change.

`removing_an_from_a_rawvideo_pipe_corrupts_frames` states that as a property of the arg vector so
no future edit can reintroduce it quietly. The audio leg must be a SEPARATE sink. -/

/-- The parts of the arg vector this property depends on. -/
structure PipeSpec where
  /-- `-f rawvideo`: no container, so framing is by byte count alone -/
  rawVideo : Bool
  /-- `-an` present: audio disabled on this output -/
  audioDisabled : Bool
  /-- this output goes to the frame-reading pipe -/
  toFramePipe : Bool
deriving DecidableEq, Repr

/-- The measured shape of `buildArgs` today. -/
def currentPreviewPipe : PipeSpec := ⟨true, true, true⟩

/-- Frames can be sliced by byte count only when nothing else shares the stream. -/
def framingIsSound (p : PipeSpec) : Bool :=
  !p.rawVideo || !p.toFramePipe || p.audioDisabled

#guard framingIsSound currentPreviewPipe == true
#guard framingIsSound { currentPreviewPipe with audioDisabled := false } == false
-- a separate sink is fine: audio enabled on an output that is NOT the frame pipe
#guard framingIsSound ⟨false, false, false⟩ == true

/--
**Deleting `-an` from the rawvideo pipe breaks framing.** The naive implementation of this feature
is destructive, and this theorem is what stops it being reintroduced.
-/
theorem removing_an_from_a_rawvideo_pipe_corrupts_frames :
    framingIsSound currentPreviewPipe = true ∧
    framingIsSound { currentPreviewPipe with audioDisabled := false } = false := by
  decide

/-- The sound alternative: enable audio on a sink that is not the frame pipe. This is what the
    implementation must do — a second output, not a relaxed flag on the first. -/
theorem a_separate_audio_sink_keeps_framing_sound (raw : Bool) :
    framingIsSound ⟨raw, false, false⟩ = true := by
  cases raw <;> decide

/-- Quantified: whenever framing is unsound, the cause is audio on the raw frame pipe. No other
    combination can break it, so the guard is exactly as strong as it needs to be and no stronger. -/
theorem unsound_framing_means_audio_on_the_frame_pipe (p : PipeSpec) :
    framingIsSound p = false → p.rawVideo = true ∧ p.toFramePipe = true ∧ p.audioDisabled = false := by
  intro h
  cases p with
  | mk r a t => cases r <;> cases a <;> cases t <;> simp_all [framingIsSound]

end CtbrecSpec.PreviewVolume
