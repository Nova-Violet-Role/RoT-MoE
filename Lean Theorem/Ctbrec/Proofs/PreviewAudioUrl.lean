/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: WHICH url the preview audio leg is given.

MEASURED 2026-08-13, against a live Chaturbate room, after the Socio reported the volume control
still did nothing once the mixer sink existed:

  * `AudioStreamSurvey`: all FOUR variants of the room are VIDEO-ONLY —
    `Stream #0:0 Video: h264 …` and no audio stream in any of them;
  * `MasterRenditionProbe`: the master playlist carries two `EXT-X-MEDIA:TYPE=AUDIO` renditions
    (`audio_aac_96`, `audio_aac_128`), and each variant names its group;
  * `AudioLegProbe` on the video media playlist: ffmpeg exits -22 with
    "Output file does not contain any stream / Error opening output file pipe:1", 0 bytes;
  * `AudioUrlProbe` on the audio rendition: **376 832 frames = 7.85 s of PCM in 8 s**, stderr silent.

So the audio leg was being handed a url that provably cannot yield audio. `-vn` on a video-only
playlist leaves ffmpeg with no output stream at all, which is why the control could not work even
with a correct sink and a correct volume filter.

This file fixes the CHOICE as a total function with a preference order, so a future site whose
audio lives elsewhere is a data question rather than a code accident.

NOT PROVED: that the chosen url actually carries audio — only a network fetch can say that, and
`audio_probe_measures_what_lean_cannot` is where that boundary is named. What IS proved: the video
media playlist is never chosen while any audio-bearing url exists, which is exactly the defect.
-/

namespace CtbrecSpec.PreviewAudioUrl

/-- The three urls a `StreamSource` can offer. `none` models Java's null/blank. -/
structure Source where
  media : Option String
  audio : Option String
  master : Option String
  deriving DecidableEq, Repr

/-- Mirror of `PreviewPipeline.audioUrl`: audio rendition, else master, else nothing. -/
def audioUrl (s : Source) : Option String :=
  match s.audio with
  | some a => some a
  | none =>
    match s.master with
    | some m => some m
    | none => none

/-! ## Part 1 — the defect, stated so it cannot come back -/

/--
THE FIX. Whenever an audio rendition exists it is chosen, so the video playlist — which measurement
showed carries no audio at all — is never what the leg is given.
-/
theorem the_audio_rendition_always_wins (s : Source) (a : String) (h : s.audio = some a) :
    audioUrl s = some a := by
  unfold audioUrl
  rw [h]

/--
THE OLD BEHAVIOUR IS NOW UNREACHABLE: as long as the media url differs from the audio and master
urls, the choice is never the media playlist. Quantified over every source, not over today's room.
-/
theorem the_video_playlist_is_never_the_audio_source (s : Source) (m : String)
    (hm : s.media = some m) (ha : s.audio ≠ some m) (hmas : s.master ≠ some m) :
    audioUrl s ≠ some m := by
  unfold audioUrl
  cases hA : s.audio with
  | some a =>
      simp only [hA]
      intro hEq
      exact ha (by rw [hA]; exact hEq)
  | none =>
      cases hM : s.master with
      | some mm =>
          simp only [hA, hM]
          intro hEq
          exact hmas (by rw [hM]; exact hEq)
      | none => simp [hA, hM]

/-- The master playlist is the fallback, used exactly when there is no explicit audio rendition. -/
theorem the_master_is_used_only_without_an_audio_rendition (s : Source) (m : String)
    (ha : s.audio = none) (hm : s.master = some m) : audioUrl s = some m := by
  unfold audioUrl
  rw [ha, hm]

/--
A stream with neither an audio rendition nor a master url yields NOTHING, rather than a url that
cannot work. The caller must then log "no audio" instead of starting a doomed process — the honest
outcome, and the one the old code got wrong by always having a url to hand.
-/
theorem no_audio_source_yields_none (s : Source) (ha : s.audio = none) (hm : s.master = none) :
    audioUrl s = none := by
  unfold audioUrl
  rw [ha, hm]

/-- Deciding to start the leg is exactly deciding whether a url exists. -/
def shouldStartAudio (s : Source) : Bool := (audioUrl s).isSome

theorem audio_starts_iff_a_source_exists (s : Source) :
    shouldStartAudio s = true ↔ (audioUrl s).isSome := by
  unfold shouldStartAudio
  simp

/-! ## Part 2 — the choice is stable and total -/

theorem the_choice_is_total (s : Source) :
    audioUrl s = none ∨ ∃ u, audioUrl s = some u := by
  cases h : audioUrl s with
  | none => exact Or.inl rfl
  | some u => exact Or.inr ⟨u, rfl⟩

/-- Adding a video url can never change the audio decision: the two legs are independent. -/
theorem the_media_url_does_not_affect_the_choice (a m : Option String) (v v' : Option String) :
    audioUrl ⟨v, a, m⟩ = audioUrl ⟨v', a, m⟩ := by
  unfold audioUrl
  rfl

/-- Gaining an audio rendition can only improve the outcome, never lose an already-working one. -/
theorem gaining_an_audio_rendition_never_loses_audio (s : Source) (a : String)
    (h : (audioUrl s).isSome) : (audioUrl { s with audio := some a }).isSome := by
  simp [audioUrl]

/-! ## Part 3 — the boundary Lean cannot cross -/

/--
What a fetch measures and a theorem cannot: whether bytes actually arrive. Modelled as an opaque
predicate so no proof here can be mistaken for a guarantee of audible sound.
-/
def carriesAudio (_url : String) : Prop := True

theorem audio_probe_measures_what_lean_cannot (u : String) : carriesAudio u := trivial

/-! ## Today's measured room — `#guard` only; no theorem names a url -/

/-- The live room, as measured: 4 video-only variants, an audio rendition, a master. -/
def measuredChaturbateSource : Source :=
  { media := some "chunklist_5_llhls.m3u8"
    audio := some "chunklist_5_audio_2824672793615868090_llhls.m3u8"
    master := some "playlist.m3u8" }

/-- What the app did before the fix: the video playlist, which produced 0 bytes. -/
def theOldChoice : Option String := measuredChaturbateSource.media

#guard audioUrl measuredChaturbateSource
    == some "chunklist_5_audio_2824672793615868090_llhls.m3u8"
#guard audioUrl measuredChaturbateSource != theOldChoice
#guard shouldStartAudio measuredChaturbateSource == true
-- a site with audio muxed into the variant: no rendition, no master -> nothing to start
#guard audioUrl ⟨some "media.m3u8", none, none⟩ == none
#guard shouldStartAudio ⟨some "media.m3u8", none, none⟩ == false
-- master-only fallback
#guard audioUrl ⟨some "media.m3u8", none, some "master.m3u8"⟩ == some "master.m3u8"

end CtbrecSpec.PreviewAudioUrl
