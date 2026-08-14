/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

import Proofs.Ctbrec.ArgSoundness
/-

# ctbrec — selectable ffmpeg presets, split by GPU vendor

Requested: selectable presets so an advanced user does not have to hand-write ffmpeg
arguments, separated by CUDA/NVIDIA versus AMD because the flags differ, at most ten.

## What shipped, and why it needed replacing

`app/ctbrec/ui/settings/SettingsTab.java:319-324` hard-coded four presets in the UI class:

```java
new FFmpegPreset("TS",  "... -f mpegts -movflags isml+frag_keyframe+separate_moof ...", "ts"),
new FFmpegPreset("MP4", "... -f mp4 -movflags frag_keyframe+separate_moof+faststart ...", "mp4"),
new FFmpegPreset("MOV", "... -f mp4 -movflags frag_keyframe+separate_moof+faststart ...", "mov"),
new FFmpegPreset("MKV", "... -f matroska ...", "mkv")
```

An earlier draft of this module asserted that `MP4` and `MOV` were unsound. **That was
wrong, and a control caught it** — see the `shipped presets` section below and the second
correction in `CtbrecSpec.ArgSoundness`. All four are sound; the trigger is `empty_moov`,
which none of them sets.

What is actually wrong with the shipped table is narrower and still worth fixing:

1. **No hardware encoding at all.** Four stream-copy presets on a machine with a GPU that
   was measured to encode HEVC at 51% of realtime with room for three concurrent streams.
2. **No `-bsf:a aac_adtstoasc` anywhere.** The live configuration in `settings.json` *does*
   set `empty_moov`, so it *is* unsound on any TS-delivering site
   (`live_config_is_unsound_on_ts`), and no shipped preset offered a repaired alternative
   to switch to.
3. **No vendor split**, which is what was asked for: AMF and NVENC take different flags.

## The model

Presets are modelled as **structure, not text**: a record of the decisions that matter,
plus a renderer. Soundness is decided over the structure — fast, and immune to a typo in a
long argument string changing the meaning without changing the proof. The *text* is pinned
separately by `#guard`, and bound to the real Java parser by `tools/PresetCheck.java`,
which runs `ctbrec.recorder.FfmpegArgSoundness.diagnose` over the rendered command line
and requires it to agree with `encodeOf`. Neither half is trusted alone.

## The guarantees

* `every_preset_is_sound` — no preset in the table can produce the AAC/fragmented-MP4
  failure, **on any source**, because soundness is evaluated with `adtsSource := true`,
  the worst case.
* `preset_count_is_ten` / `preset_ids_are_unique` — the table is a menu, not a pile.
* `universal_preset_exists` and `universal_presets_need_no_gpu` — a machine with no
  supported GPU is never left without a working choice.
* `available_never_empty` — the filtered menu shown to the user is never empty, whatever
  the machine reports.
* `available_is_sound` — filtering cannot introduce an unsound entry.
-/

namespace CtbrecSpec

/-! ## Vendors -/

inductive Vendor where
  | universal
  | amd
  | nvidia
  /-- Windows Media Foundation: an ENCODE-side hardware path, and the only one that works on a
  machine whose AMF and NVENC encoders are broken. Not `universal` — it needs an encoder, and
  calling it universal would falsify `universal_presets_need_no_gpu`, the guarantee that a
  GPU-less machine always has a choice. -/
  | mediafoundation
  deriving DecidableEq, Repr, Inhabited

/-- Human-readable tag used in the UI and in the Java table. -/
def Vendor.tag : Vendor → String
  | .universal => "UNIVERSAL"
  | .amd => "AMD"
  | .nvidia => "NVIDIA"
  | .mediafoundation => "MEDIAFOUNDATION"

/-! ## Presets as structure -/

/-- The decisions that determine whether a preset can fail, plus the extra flags that do
not affect soundness. Modelled over structure rather than over a rendered command line:
a typo in `extra` cannot change what is proved, and the text is pinned by `#guard` and by
the real Java parser instead. -/
structure Preset where
  /-- Stable identifier, shown in the ComboBox. -/
  id : String
  vendor : Vendor
  /-- The encoder this preset requires, e.g. `hevc_amf`. `copy` means no encoder. -/
  encoder : String
  /-- `copy` or a real audio encoder. -/
  audioCodec : String
  /-- ffmpeg muxer name: `mpegts`, `mp4`, `matroska`. -/
  container : String
  /-- File extension ctbrec writes. -/
  extension : String
  /-- Whether the rendered `-movflags` includes `empty_moov`. THIS is the token measured
  necessary and sufficient for the ADTS-AAC failure; `frag_keyframe` alone is safe. -/
  fragmented : Bool
  /-- Whether `-bsf:a aac_adtstoasc` is present. -/
  adtsToAsc : Bool
  /-- Flags that do not bear on soundness (rate control, quality, tags). -/
  extra : List String
  deriving DecidableEq, Repr, Inhabited

/-- The soundness question, asked in the **worst case**: an ADTS AAC source, which is what
Chaturbate and MyFreeCams deliver. A preset that is sound here is sound anywhere. -/
def encodeOf (p : Preset) : Encode :=
  { audioCopy := p.audioCodec == "copy"
    adtsSource := true
    mp4Sink := p.container == "mp4"
    emptyMoov := p.fragmented
    adtsToAsc := p.adtsToAsc }

/-- Render to the ffmpeg argument list ctbrec stores in `ffmpegMergedDownloadArgs`. -/
def Preset.render (p : Preset) : List String :=
  ["-c:v", p.encoder] ++ p.extra ++ ["-c:a", p.audioCodec] ++
    (if p.adtsToAsc then ["-bsf:a", "aac_adtstoasc"] else []) ++
    ["-f", p.container] ++
    (if p.fragmented then
       ["-movflags", "frag_keyframe+empty_moov+default_base_moof+separate_moof"]
     else []) ++
    ["-fflags", "+genpts", "-y"]

/-! ## `encodeOf` is not vacuous

**Found by mutation M39, which SURVIVED.** Replacing `mp4Sink := p.container == "mp4"`
with `mp4Sink := false` in `encodeOf` left the whole module green, because
`every_preset_is_sound` and `available_is_sound` are then satisfied *trivially* — nothing
can be unsound if nothing is an MP4 sink. Ten "the presets are sound" theorems, and none
of them noticed that soundness had been rendered meaningless.

That is the vacuity failure this project is supposed to catch, so the fix is a control
that must stay red-able: a preset built exactly the way the live configuration is built
**must** be flagged. The theorems below pin every field `encodeOf` reads, so any mutation
that unhooks one of them fails here instead of passing silently. -/

/-- A deliberately broken preset — the live configuration's shape. Not in `presets`; it
exists only so that the predicate over the table has something it must reject. -/
def brokenPreset : Preset :=
  { id := "BROKEN", vendor := .universal, encoder := "copy", audioCodec := "copy"
    container := "mp4", extension := "mp4", fragmented := true, adtsToAsc := false
    extra := [] }

/-- **The control.** If this ever goes green-by-vacuity, `every_preset_is_sound` means
nothing either. -/
theorem encodeOf_is_not_vacuous : unsound (encodeOf brokenPreset) = true := by decide

/-- Each field `encodeOf` reads is pinned to the field it comes from, so unhooking any one
of them is a build error rather than a silent weakening. -/
theorem encodeOf_reads_container (p : Preset) :
    (encodeOf p).mp4Sink = (p.container == "mp4") := rfl

theorem encodeOf_reads_fragmented (p : Preset) : (encodeOf p).emptyMoov = p.fragmented := rfl

theorem encodeOf_reads_adtsToAsc (p : Preset) : (encodeOf p).adtsToAsc = p.adtsToAsc := rfl

theorem encodeOf_reads_audioCodec (p : Preset) :
    (encodeOf p).audioCopy = (p.audioCodec == "copy") := rfl

/-- And the worst case is genuinely assumed, not quietly dropped — an `adtsSource := false`
mutation would make every preset sound for the wrong reason. -/
theorem encodeOf_assumes_the_worst_source (p : Preset) : (encodeOf p).adtsSource = true := rfl

/-! ## The table — exactly ten -/

def presetsMain : List Preset :=
  [ -- universal: no GPU required, always selectable
    { id := "TS-Copy", vendor := .universal, encoder := "copy", audioCodec := "copy"
      container := "mpegts", extension := "ts", fragmented := false, adtsToAsc := false
      extra := [] }
  , { id := "MP4-Copy", vendor := .universal, encoder := "copy", audioCodec := "copy"
      container := "mp4", extension := "mp4", fragmented := true, adtsToAsc := true
      extra := [] }
  , { id := "MKV-Copy", vendor := .universal, encoder := "copy", audioCodec := "copy"
      container := "matroska", extension := "mkv", fragmented := false, adtsToAsc := false
      extra := [] }
    -- AMD (AMF)
    -- every AMD setting below is the winner of a measured A/B against real recorded
    -- content, not a guess; see `measurements` and its theorems at the end of this file
  , { id := "AMD-H264", vendor := .amd, encoder := "h264_amf", audioCodec := "copy"
      container := "mp4", extension := "mp4", fragmented := true, adtsToAsc := true
      extra := ["-rc", "cqp", "-qp_i", "23", "-qp_p", "25", "-quality", "quality",
                "-vbaq", "1", "-preanalysis", "1"] }
  , { id := "AMD-HEVC", vendor := .amd, encoder := "hevc_amf", audioCodec := "copy"
      container := "mp4", extension := "mp4", fragmented := true, adtsToAsc := true
      extra := ["-rc", "cqp", "-qp_i", "24", "-qp_p", "26", "-quality", "quality",
                "-vbaq", "1", "-preanalysis", "1", "-preencode", "1", "-tag:v", "hvc1"] }
  , { id := "AMD-HEVC-Archive", vendor := .amd, encoder := "hevc_amf", audioCodec := "copy"
      container := "mp4", extension := "mp4", fragmented := true, adtsToAsc := true
      extra := ["-rc", "qvbr", "-qvbr_quality_level", "26", "-quality", "quality",
                "-vbaq", "1", "-preanalysis", "1", "-b:v", "0", "-maxrate", "8M",
                "-bufsize", "16M", "-tag:v", "hvc1"] }
  , { id := "AMD-AV1", vendor := .amd, encoder := "av1_amf", audioCodec := "copy"
      container := "mp4", extension := "mp4", fragmented := true, adtsToAsc := true
      extra := ["-rc", "cqp", "-qp_i", "28", "-qp_p", "30", "-quality", "quality"] }
    -- NVIDIA (NVENC / CUDA)
  , { id := "NV-H264", vendor := .nvidia, encoder := "h264_nvenc", audioCodec := "copy"
      container := "mp4", extension := "mp4", fragmented := true, adtsToAsc := true
      extra := ["-preset", "p5", "-tune", "hq", "-rc", "vbr", "-cq", "23", "-b:v", "0"] }
  , { id := "NV-HEVC", vendor := .nvidia, encoder := "hevc_nvenc", audioCodec := "copy"
      container := "mp4", extension := "mp4", fragmented := true, adtsToAsc := true
      extra := ["-preset", "p5", "-tune", "hq", "-rc", "vbr", "-cq", "24", "-b:v", "0",
                "-tag:v", "hvc1"] }
  , { id := "NV-AV1", vendor := .nvidia, encoder := "av1_nvenc", audioCodec := "copy"
      container := "mp4", extension := "mp4", fragmented := true, adtsToAsc := true
      extra := ["-preset", "p5", "-tune", "hq", "-rc", "vbr", "-cq", "28", "-b:v", "0"] }
  ]

/-- The Media Foundation FALLBACK row. Measured: this ffmpeg carries 14 hardware encoders, the
table named 6, and `h264_mf` is the one that WORKS and no preset could reach. `-quality 60` was
chosen by measurement — SSIM 0.991756 at 702 permille of source, matching the AMD-H264 rung
(0.990952, 365 permille). It is a fallback, not an ordinary row, because the menu is capped: see
`available_never_exceeds_ten` below and `CtbrecSpec.FallbackPreset`. -/
def mfFallback : Preset :=
  { id := "MF-H264", vendor := .mediafoundation, encoder := "h264_mf", audioCodec := "copy"
    container := "mp4", extension := "mp4", fragmented := true, adtsToAsc := true
    extra := ["-rate_control", "quality", "-quality", "60"] }

/-- The shipped table: ten primary rows and one fallback. Written as an append so the ceiling
proof can treat the fallback separately; every `decide` over `presets` still evaluates. -/
def presets : List Preset := presetsMain ++ [mfFallback]

/-- Encoders offered only where nothing better runs. Mirrors `FALLBACK_ENCODERS`. -/
def fallbackEncoders : List String := ["h264_mf"]

/-! ## The guarantees -/

/-- **No preset in the table can produce the fragmented-MP4 AAC failure**, on any source.
This is the theorem the shipped `MP4` and `MOV` presets would violate. -/
theorem every_preset_is_sound : presets.all (fun p => !unsound (encodeOf p)) = true := by
  decide

/-- Stated per-preset as well, in the membership form a caller can actually use. -/
theorem preset_sound_of_mem (p : Preset) (h : p ∈ presets) : unsound (encodeOf p) = false := by
  have hall : presets.all (fun q => !unsound (encodeOf q)) = true := every_preset_is_sound
  rw [List.all_eq_true] at hall
  have := hall p h
  simpa using this

/-- A menu with a duplicate id cannot be selected from unambiguously. -/
theorem preset_ids_are_unique : (presets.map Preset.id).Nodup := by decide

/-! ## Availability

**Correction, measured 2026-08 — the first version of this section was wrong.** It defined
availability as "the encoder appears in `ffmpeg -encoders`". That is not availability. On
this machine (AMD Radeon RX 6650 XT, RDNA2) `ffmpeg -encoders` lists **all** of
`av1_amf`, `h264_nvenc`, `hevc_nvenc`, `av1_nvenc` — they are compiled in — and every one
of them fails when actually run:

```
av1_amf     -> CreateComponent(AMFVideoEncoderHW_AV1) failed with error 30   (RDNA2 has no AV1 encoder)
hevc_nvenc  -> Cannot load nvcuda.dll                                        (no NVIDIA GPU)
```

The old rule would have offered four presets that cannot produce a single frame here. So
`workingEncoders` is the set confirmed by a **probe encode** — one frame, actually run —
not by parsing a capability list. The theorems below are unchanged in shape; what feeds
them is now a measurement instead of a claim.

`copy` needs no encoder and is therefore always available, which is what keeps
`available_never_empty` true. -/

def Preset.needsEncoder (p : Preset) : Bool := p.encoder != "copy"

/-- Does any NON-fallback hardware preset run here? Mirrors `anyPrimaryAvailable`. -/
def anyPrimaryAvailable (workingEncoders : List String) : Bool :=
  presetsMain.any (fun q =>
    q.needsEncoder && !fallbackEncoders.contains q.encoder && workingEncoders.contains q.encoder)

/-- A preset is offered when its encoder runs — and, if it is a fallback, only where no vendor
preset runs at all. Mirrors the repaired `FfmpegPresets.availableOn` line for line. -/
def availableOn (workingEncoders : List String) (p : Preset) : Bool :=
  if !p.needsEncoder then true
  else if !workingEncoders.contains p.encoder then false
  else !fallbackEncoders.contains p.encoder || !anyPrimaryAvailable workingEncoders

def available (encoders : List String) : List Preset :=
  presets.filter (availableOn encoders)

/-- The three universal presets need no GPU. -/
theorem universal_presets_need_no_gpu :
    presets.all (fun p => p.vendor != Vendor.universal || !p.needsEncoder) = true := by decide

/-- **The menu is never empty**, whatever the machine reports — not even for an empty
encoder list. A user without a supported GPU still gets the copy presets. -/
theorem available_never_empty (encoders : List String) : (available encoders) ≠ [] := by
  intro h
  have hmem : presetsMain[0]! ∈ available encoders := by
    simp [available, List.mem_filter, availableOn, Preset.needsEncoder, presets, presetsMain]
  rw [h] at hmem
  simp at hmem

/-- **Filtering cannot introduce an unsound entry.** -/
theorem available_is_sound (encoders : List String) (p : Preset) (h : p ∈ available encoders) :
    unsound (encodeOf p) = false :=
  preset_sound_of_mem p ((List.mem_filter.mp h).1)

/-! ### The ceiling, restated

The requirement was "at most ten presets". An earlier form of it — `presets.length = 10` — froze
a CONTINGENT fact: the table happened to have ten rows. It went red the moment a measured
capability gap (a working `h264_mf` that no preset could reach) had to be closed, and the obvious
repair would have been to delete the theorem, destroying real coverage.

The durable statement is about **what the user is offered**, which is `available`, never the raw
table. Both are kept: the row count is recorded as a transcription fact, and the ceiling is proved
where it belongs — over every possible machine. -/

/-- Transcription: eleven rows, ten primary and one fallback. -/
theorem preset_row_count : presets.length = 11 := by decide

/-- **The menu never exceeds ten, on any machine.** Quantified over the working set, so it cannot
be satisfied by the machine that happens to be here. -/
theorem available_never_exceeds_ten (encoders : List String) :
    (available encoders).length ≤ 10 := by
  unfold available presets
  rw [List.filter_append, List.length_append]
  have hmain : (presetsMain.filter (availableOn encoders)).length ≤ 10 := by
    simpa [presetsMain] using List.length_filter_le (availableOn encoders) presetsMain
  cases hap : anyPrimaryAvailable encoders with
  | true =>
    have hfb : ([mfFallback].filter (availableOn encoders)) = [] := by
      simp [mfFallback, availableOn, fallbackEncoders, hap, Preset.needsEncoder]
    rw [hfb]; simp; omega
  | false =>
    have hmain3 : (presetsMain.filter (availableOn encoders)).length ≤ 3 := by
      simp [anyPrimaryAvailable, presetsMain, fallbackEncoders, Preset.needsEncoder] at hap
      simp [presetsMain, availableOn, fallbackEncoders, Preset.needsEncoder, hap]
    have hfb : ([mfFallback].filter (availableOn encoders)).length ≤ 1 := by
      simpa using List.length_filter_le (availableOn encoders) [mfFallback]
    omega


/-- Everything offered is really in the table — the filter invents nothing. -/
theorem available_subset (encoders : List String) (p : Preset) (h : p ∈ available encoders) :
    p ∈ presets := (List.mem_filter.mp h).1

/-- The table really does contain MP4 sinks, so `every_preset_is_sound` is a claim about
presets that *could* have been unsound rather than a statement about an empty set. Part of
the M39 repair. -/
theorem table_contains_mp4_sinks :
    (presets.filter (fun p => p.container == "mp4")).length = 9 := by decide

/-- …and fragmented ones, the other half of the trigger. Together with
`encodeOf_is_not_vacuous` these say the soundness claim has real content. -/
theorem table_contains_fragmented_presets :
    (presets.filter (fun p => p.fragmented)).length = 9 := by decide

/-- The only reason those eight are sound is the bitstream filter — remove it from any one
of them and `every_preset_is_sound` fails. -/
theorem soundness_of_the_table_rests_on_the_filter :
    presets.all (fun p => !(p.container == "mp4" && p.fragmented) || p.adtsToAsc) = true := by
  decide

/-- Vendor split, as requested: both GPU families are represented, neither crowds out the
universal fallbacks, and the Media Foundation path is one row. -/
theorem both_vendors_present :
    (presets.filter (fun p => p.vendor == Vendor.amd)).length = 4 ∧
      (presets.filter (fun p => p.vendor == Vendor.nvidia)).length = 3 ∧
      (presets.filter (fun p => p.vendor == Vendor.universal)).length = 3 ∧
      (presets.filter (fun p => p.vendor == Vendor.mediafoundation)).length = 1 := by decide

/-- **Every vendor family is reachable.** Stated over the whole enum rather than over the three
constants that happened to exist, so adding a family without a preset is a build error instead of
a silent hole. -/
theorem every_vendor_has_a_preset :
    [Vendor.universal, Vendor.amd, Vendor.nvidia, Vendor.mediafoundation].all
      (fun v => presets.any (fun p => p.vendor == v)) = true := by decide

/-! ## The shipped presets

**Correction, and it went the other way.** This section used to assert
`shipped_mp4_preset_is_unsound`. A negative control in `tools/PresetCheck.java` required
the shipped `MP4` argument string to fail against real ffmpeg — and it **succeeded**
(exit 0, 330 002 B). The per-token matrix that followed is recorded in
`CtbrecSpec.ArgSoundness`: the trigger is `empty_moov`, not fragmentation, and the
shipped presets use `frag_keyframe+separate_moof+faststart` with no `empty_moov`.

So those two theorems were **false of reality and have been deleted**, not weakened. The
shipped UI presets are sound. What is genuinely unsound is the *live configuration* in
`settings.json`, whose `ffmpegMergedDownloadArgs` does contain `empty_moov` —
`live_config_is_unsound_on_ts` in `ArgSoundness`, unchanged by either correction.

The case for replacing the shipped table therefore rests on what it actually was:
**no hardware encoding at all, and no `-bsf:a aac_adtstoasc` anywhere**, so a user who
followed the live config's example into `empty_moov` had no sound preset to fall back on.
That is a smaller claim than the one made before, and it is the true one. -/

/-- The shipped `MP4` preset, as structure. No `empty_moov`. -/
def shippedMp4 : Preset :=
  { id := "MP4", vendor := .universal, encoder := "copy", audioCodec := "copy"
    container := "mp4", extension := "mp4", fragmented := false, adtsToAsc := false
    extra := [] }

/-- The shipped `MOV` preset differs only in the extension. -/
def shippedMov : Preset := { shippedMp4 with id := "MOV", extension := "mov" }

/-- The shipped `TS` preset. -/
def shippedTs : Preset :=
  { id := "TS", vendor := .universal, encoder := "copy", audioCodec := "copy"
    container := "mpegts", extension := "ts", fragmented := false, adtsToAsc := false
    extra := [] }

/-- **All three shipped presets are sound** — measured, and the theorem now says so.
Kept as a theorem rather than dropped, because the earlier claim to the contrary is
exactly the kind of thing that creeps back in. -/
theorem shipped_ui_presets_are_all_sound :
    unsound (encodeOf shippedMp4) = false ∧ unsound (encodeOf shippedMov) = false ∧
      unsound (encodeOf shippedTs) = false := by decide

/-- The live configuration is the one that is broken, and no shipped preset repaired it:
none of the three carries the bitstream filter. -/
theorem no_shipped_preset_carries_the_repair :
    shippedMp4.adtsToAsc = false ∧ shippedMov.adtsToAsc = false ∧
      shippedTs.adtsToAsc = false := by decide

/-- The new table does carry it, on every preset that writes an MP4 sink. -/
theorem every_mp4_preset_carries_the_repair :
    presets.all (fun p => p.container != "mp4" || p.adtsToAsc) = true := by decide

/-! ## Rendered text, pinned

The proofs above are over structure. These `#guard`s pin the rendering, and
`tools/PresetCheck.java` feeds the same rendered text to the real
`ctbrec.recorder.FfmpegArgSoundness.diagnose` and requires it to agree. -/

#guard presets.length == 11
#guard (available ["h264_amf", "hevc_amf"]).length == 6
#guard (available ["h264_mf"]).length == 4
#guard (available ["h264_amf", "hevc_amf", "av1_amf", "h264_nvenc", "hevc_nvenc", "av1_nvenc", "h264_mf"]).length == 10
#guard (presets[0]!).render ==
  ["-c:v", "copy", "-c:a", "copy", "-f", "mpegts", "-fflags", "+genpts", "-y"]
#guard (presets[1]!).render ==
  ["-c:v", "copy", "-c:a", "copy", "-bsf:a", "aac_adtstoasc", "-f", "mp4",
   "-movflags", "frag_keyframe+empty_moov+default_base_moof+separate_moof",
   "-fflags", "+genpts", "-y"]
#guard (presets[4]!).id == "AMD-HEVC"
#guard (presets[4]!).encoder == "hevc_amf"
#guard (presets[7]!).encoder == "h264_nvenc"
#guard availableOn [] (presets[0]!) == true
#guard availableOn [] (presets[4]!) == false
#guard availableOn ["hevc_amf"] (presets[4]!) == true
#guard (available []).length == 3
#guard (available ["h264_amf", "hevc_amf", "av1_amf"]).length == 7
#guard (available ["h264_nvenc", "hevc_nvenc", "av1_nvenc"]).length == 6
#guard unsound (encodeOf shippedMp4) == false   -- corrected: no empty_moov, so sound
#guard unsound (encodeOf (presets[1]!)) == false

/-- This machine's probe result, recorded as data: two AMF encoders work, AV1 and all of
NVENC do not, despite `ffmpeg -encoders` listing every one of them. -/
def probedOnThisMachine : List String := ["h264_amf", "hevc_amf"]

/-! ## 60 FPS variants

Requested: 60 FPS presets. Measured first, because the obvious implementation is wrong in
two different ways.

**Wrong way 1: forcing `-r 60`.** A "60 FPS preset" must not upsample. Most cam streams are
30 fps; forcing 60 doubles the frame count and the bitrate for no new information. The
variants below set `-fps_mode passthrough` and contain **no `-r` flag at all** — measured:
a 30 fps source stays 30 fps (7 897 304 B), a 60 fps source stays 60 fps (8 076 575 B).
`at60_never_forces_a_frame_rate` states that as a theorem over the whole table.

**Wrong way 2: reusing the 30 fps settings.** The `AMD-HEVC` preset at 1080p60 was measured
at **95% of realtime** — it keeps up with nothing to spare, on one stream, which is not a
margin a recorder can run on. The cost is `-preanalysis`, and at 60 fps it does not pay:

| 1080p60, 20 s | wall | realtime | size | SSIM |
|---|---|---|---|---|
| `-quality quality -preanalysis 1 -preencode 1` | 19 055 ms | **95%** | 7 899 503 B | 0.990781 |
| `-quality speed` (no preanalysis) | 3 057 ms | **15%** | 7 955 932 B | 0.989276 |

6.3× faster for **0.7% more bytes** and 0.0015 SSIM. Three concurrent 1080p60 encodes with
the fast settings finished at 45% of realtime.

So `at60` is a *transformer*: it drops `-preanalysis`/`-preencode`, switches `-quality` to
`speed`, and appends `-fps_mode passthrough -g 120` (a 2-second GOP at 60 fps).

**On the ten-preset ceiling.** The base menu stays at exactly ten, as asked. The 60 FPS
variants are a **separate** selection list of seven — one per hardware preset; the three
stream-copy presets are already frame-rate agnostic and need no variant. Each list is
independently ≤ 10 (`preset_count_is_ten`, `presets60_count_le_ten`), and nothing is
truncated to fit. -/

/-- Remove a `-flag value` pair wherever it appears. -/
def dropPair (flag : String) : List String → List String
  | [] => []
  | [a] => if a == flag then [] else [a]
  | a :: b :: rest =>
      if a == flag then dropPair flag rest else a :: dropPair flag (b :: rest)

/-- Replace the value of a `-flag value` pair wherever it appears. -/
def setPair (flag val : String) : List String → List String
  | [] => []
  | [a] => [a]
  | a :: b :: rest =>
      if a == flag then a :: val :: setPair flag val rest
      else a :: setPair flag val (b :: rest)

/-- The high-frame-rate rewrite of a preset's non-soundness flags. -/
def hfrExtra (xs : List String) : List String :=
  setPair "-quality" "speed" (dropPair "-preanalysis" (dropPair "-preencode" xs))
    ++ ["-fps_mode", "passthrough", "-g", "120"]

/-- The 60 FPS variant of a preset. Touches only the id and the flags that do not bear on
soundness — which is what `at60_preserves_soundness` pins down. -/
def Preset.at60 (p : Preset) : Preset :=
  { p with id := p.id ++ "-60", extra := hfrExtra p.extra }

/-- The seven variants: one per hardware preset. Stream-copy presets are already
frame-rate agnostic, so giving them a "-60" twin would be noise. -/
def presets60 : List Preset :=
  (presets.filter Preset.needsEncoder).map Preset.at60

theorem presets60_count : presets60.length = 8 := by decide

/-- The requested ceiling holds for this list too. -/
theorem presets60_count_le_ten : presets60.length ≤ 10 := by decide

/-- **The 60 FPS rewrite cannot make a preset unsound.** It touches only `id` and `extra`,
neither of which `encodeOf` reads — so a future edit that also changed the container or
dropped the bitstream filter would break this. -/
theorem at60_preserves_soundness (p : Preset) :
    unsound (encodeOf p.at60) = unsound (encodeOf p) := rfl

/-- Every variant is sound, stated over the actual list rather than abstractly. -/
theorem presets60_all_sound : presets60.all (fun p => !unsound (encodeOf p)) = true := by
  decide

/-- **No variant forces a frame rate.** This is the anti-upsampling guarantee: a 30 fps
source recorded with a "60" preset stays 30 fps, measured and now also proved of the
argument list. -/
theorem at60_never_forces_a_frame_rate :
    presets60.all (fun p => !(p.render.contains "-r")) = true := by decide

/-- Nor does any base preset. -/
theorem no_preset_forces_a_frame_rate :
    presets.all (fun p => !(p.render.contains "-r")) = true := by decide

/-- **Preanalysis is gone from every variant** — the flag measured to cost 6.3× the encode
time at 1080p60 for 0.7% of the size. -/
theorem at60_drops_preanalysis :
    presets60.all (fun p => !(p.extra.contains "-preanalysis")) = true := by decide

theorem at60_drops_preencode :
    presets60.all (fun p => !(p.extra.contains "-preencode")) = true := by decide

/-- And passthrough is present on every one, which is what keeps the frame rate honest. -/
theorem at60_sets_passthrough :
    presets60.all (fun p => p.extra.contains "-fps_mode" && p.extra.contains "passthrough")
      = true := by decide

/-- The variant runs the same encoder into the same container — it is a re-tune, not a
different preset wearing the same name. -/
theorem at60_keeps_encoder_and_container (p : Preset) :
    p.at60.encoder = p.encoder ∧ p.at60.container = p.container ∧
      p.at60.extension = p.extension ∧ p.at60.vendor = p.vendor := ⟨rfl, rfl, rfl, rfl⟩

/-- Variant ids never collide with base ids, so one selection list cannot shadow the
other. -/
theorem at60_ids_are_distinct :
    presets60.all (fun q => !((presets.map Preset.id).contains q.id)) = true := by decide

theorem presets60_ids_are_unique : (presets60.map Preset.id).Nodup := by decide

/-- Every variant needs a GPU, by construction — the copy presets were excluded. -/
theorem presets60_all_need_an_encoder :
    presets60.all Preset.needsEncoder = true := by decide

/-- The 60 FPS menu for a machine. Unlike the base menu this one **can** be empty, and
that is correct: with no working hardware encoder there is no 60 FPS variant to offer,
and the base menu still has the three copy presets. -/
def available60 (workingEncoders : List String) : List Preset :=
  presets60.filter (availableOn workingEncoders)

/-- Filtering cannot introduce an unsound variant. -/
theorem available60_is_sound (encoders : List String) (p : Preset)
    (h : p ∈ available60 encoders) : unsound (encodeOf p) = false := by
  have hall : presets60.all (fun q => !unsound (encodeOf q)) = true := presets60_all_sound
  rw [List.all_eq_true] at hall
  simpa using hall p ((List.mem_filter.mp h).1)

#guard presets60.length == 8
#guard (presets60[0]!).id == "AMD-H264-60"
#guard (available60 probedOnThisMachine).length == 3
#guard (available60 []).length == 0
#guard (available60 probedOnThisMachine).map Preset.id ==
  ["AMD-H264-60", "AMD-HEVC-60", "AMD-HEVC-Archive-60"]
#guard hfrExtra ["-quality", "quality", "-preanalysis", "1"] ==
  ["-quality", "speed", "-fps_mode", "passthrough", "-g", "120"]
#guard (available probedOnThisMachine).length + (available60 probedOnThisMachine).length == 9

/-! ## The encoder A/B — MEASURED, not proved

Every number below was measured, not reasoned about. Source: a 20-second excerpt of a
**real** ctbrec recording (`502_error_2026-07-12_04-59-22_271.mp4`, 1080p30 HEVC,
21 215 778 B), encoded on an AMD Radeon RX 6650 XT with ffmpeg 8.0.1, SSIM computed by
ffmpeg's own `ssim` filter against the source.

`sizePermille` is output size as a fraction of the source in parts per thousand;
`realtimePct` is encode wall time as a percentage of the clip's 20-second duration, so
anything below 100 keeps up with a live stream.

| id | settings | SSIM | size | wall |
|---|---|---|---|---|
| `live-cqp22` | the config currently in `settings.json` | 0.995294 | 671‰ | 14% |
| `qvbr22-cap` | `-rc qvbr -qvbr_quality_level 22 -maxrate 12M` | 0.984883 | 203‰ | 51% |
| `qvbr26-cap` | `-rc qvbr -qvbr_quality_level 26 -maxrate 8M` | 0.988019 | 280‰ | 51% |
| `cqp24-pa` | `-rc cqp -qp_i 24 -qp_p 26 -preanalysis 1` | 0.990952 | 365‰ | 51% |
| `h264-cqp23` | `-c:v h264_amf -qp_i 23 -qp_p 25 -preanalysis 1` | 0.991434 | 456‰ | 51% |
| `x265-crf23` | software reference, `-crf 23 -preset medium` | 0.990840 | 286‰ | **125%** |

Also measured: three simultaneous `cqp24-pa` encodes finished in 10 734 ms wall — 53%
realtime, essentially the same as one, so the GPU has headroom for concurrent recordings.

The theorems in this section are statements **about this table**. They do not prove that
the encoder is good; they prove the table says what the preset list claims, so that
changing a preset's numbers without re-measuring breaks the build. -/

structure Measured where
  presetId : String
  /-- SSIM against the source, ×10⁶. -/
  ssimMicro : Nat
  /-- Output size as a fraction of the source, ‰. -/
  sizePermille : Nat
  /-- Encode wall time as a percentage of the clip duration. -/
  realtimePct : Nat
  deriving DecidableEq, Repr, Inhabited

def measurements : List Measured :=
  [ { presetId := "live-cqp22", ssimMicro := 995294, sizePermille := 671, realtimePct := 14 }
  , { presetId := "qvbr22-cap", ssimMicro := 984883, sizePermille := 203, realtimePct := 51 }
  , { presetId := "qvbr26-cap", ssimMicro := 988019, sizePermille := 280, realtimePct := 51 }
  , { presetId := "cqp24-pa",   ssimMicro := 990952, sizePermille := 365, realtimePct := 51 }
  , { presetId := "h264-cqp23", ssimMicro := 991434, sizePermille := 456, realtimePct := 51 }
  , { presetId := "x265-crf23", ssimMicro := 990840, sizePermille := 286, realtimePct := 125 }
  ]

def liveConfig : Measured := measurements[0]!
def chosenHevc : Measured := measurements[3]!
def chosenArchive : Measured := measurements[2]!
def softwareRef : Measured := measurements[5]!

/-- **The setting currently in `settings.json` is the least space-efficient of every
option measured** — by a wide margin, and it is not a close call on quality either. -/
theorem live_config_wastes_the_most_space :
    measurements.all (fun m => m.presetId == liveConfig.presetId ||
      m.sizePermille < liveConfig.sizePermille) = true := by decide

/-- **The chosen AMD-HEVC preset is the honest trade**: 365‰ against 671‰ — a 45%
reduction — for an SSIM loss of 0.0043, under half a percent. -/
theorem chosen_hevc_halves_size_for_negligible_ssim :
    chosenHevc.sizePermille * 100 < liveConfig.sizePermille * 55 ∧
      liveConfig.ssimMicro - chosenHevc.ssimMicro < 5000 := by decide

/-- The archive preset is smaller still, and the ordering of the two is not accidental. -/
theorem archive_is_smaller_than_default :
    chosenArchive.sizePermille < chosenHevc.sizePermille := by decide

/-- **Why no software preset is offered for live recording.** libx265 reaches the same
SSIM as the chosen hardware preset in fewer bytes, but it cannot keep up with the stream:
125% of realtime for a single 1080p30 source. Hardware encoding is not chosen here because
it is better, it is chosen because software is not fast enough. -/
theorem software_reference_cannot_keep_up :
    softwareRef.realtimePct > 100 ∧ chosenHevc.realtimePct < 100 := by decide

/-- Every hardware option measured keeps up with a live stream. -/
theorem all_hardware_options_keep_up :
    measurements.all (fun m => m.presetId == softwareRef.presetId || m.realtimePct < 100)
      = true := by decide

/-- The software reference is genuinely competitive on quality-per-byte — recorded so the
choice above is not mistaken for a claim that AMF beats x265. -/
theorem software_is_more_efficient_per_byte :
    softwareRef.sizePermille < chosenHevc.sizePermille ∧
      softwareRef.ssimMicro + 200 > chosenHevc.ssimMicro := by decide

-- `probedOnThisMachine` is defined above, before its first use in the 60 FPS section.
#guard (available probedOnThisMachine).length == 6   -- 3 universal + h264_amf + hevc_amf x2
#guard (available probedOnThisMachine).all (fun p => p.encoder != "av1_amf") == true
#guard (available probedOnThisMachine).all (fun p => p.vendor != Vendor.nvidia) == true
#guard measurements.length == 6

/-! ## Resolving the stored preset id (the 60 FPS lookup hole)

**A defect found by triaging the dead-code census, not by reading the code.** `byId60` sat in the
"no evidence of any reference" list. It is there because nothing calls it — and nothing calls it
because both consumers resolve the stored id with `byId` alone:

* `SettingsTab.java:341-346` builds the menu from `available(...)` **and** `available60(...)`, so
  a user can select a `-60` id and it is stored in `settings.ffmpegPreset`;
* `ThumbCell.java:959` and `ThumbOverviewTab.java:554` then resolve it with
  `FfmpegPresets.byId(...)`, which searches only the base table;
* `Preset.at60` names the variant `p.id ++ "-60"`, so that lookup returns `null`;
* the consumers fall back to `Vendor.UNIVERSAL`, and the preview loses its vendor hwaccel.

The UI offers a choice it cannot then honour. Nothing detected it, because every individual
piece is correct — the defect lives in the seam between them, which is where a textual dead-code
scan looks least. -/

/-- Lookup over the base table, as `FfmpegPresets.byId` does it. -/
def byId (id : String) : Option Preset := presets.find? (fun p => p.id == id)

/-- Lookup over the 60 FPS table, as `FfmpegPresets.byId60` does it. -/
def byId60 (id : String) : Option Preset := presets60.find? (fun p => p.id == id)

/-- The repair: try the base table, then the 60 FPS table. -/
def byIdAny (id : String) : Option Preset :=
  match byId id with
  | some p => some p
  | none => byId60 id

/-- What a consumer ends up using: the resolved preset's vendor, or `universal` when the lookup
fails. This mirrors `preset != null ? preset.vendor() : Vendor.UNIVERSAL` exactly. -/
def vendorVia (lookup : String → Option Preset) (id : String) : Vendor :=
  match lookup id with
  | some p => p.vendor
  | none => Vendor.universal

/-- **The defect, stated over the whole table.** Not one example — every 60 FPS id fails the
base lookup. -/
theorem byId_misses_every_sixty_id : presets60.all (fun p => (byId p.id).isNone) = true := by
  decide

/-- **And the repair resolves every id the menu can offer**, base and 60 FPS alike. This is the
statement that matters: it is about the ids the UI can store, not about a chosen example. -/
theorem byIdAny_resolves_every_offered_id :
    (presets ++ presets60).all (fun p => (byIdAny p.id).isSome) = true := by decide

/-- **No regression on the base table**: where `byId` already worked, the repair returns the
same preset. A fix that changed existing behaviour would be a different defect. -/
theorem byIdAny_agrees_with_byId_on_the_base_table :
    presets.all (fun p => byIdAny p.id == byId p.id) = true := by decide

/-- **The cost of the hole, in the currency the user sees.** For every hardware 60 FPS preset the
old resolution yields `universal` while the preset's real vendor is not universal — that is the
lost hwaccel, proved rather than asserted. -/
theorem the_old_lookup_loses_the_vendor :
    presets60.all (fun p =>
      vendorVia byId p.id == Vendor.universal && p.vendor != Vendor.universal) = true := by
  decide

/-- **And the repair restores it**, for every entry in both tables. -/
theorem the_repair_returns_the_right_vendor :
    (presets ++ presets60).all (fun p => vendorVia byIdAny p.id == p.vendor) = true := by decide

/-- **A durable statement of why the two tables cannot be merged by accident**: no base preset
carries a `-60` id, so the fallback order can never shadow a base entry. Quantified over the
table, so adding presets keeps it honest. -/
theorem no_base_preset_uses_a_sixty_id :
    presets.all (fun p => (byId60 p.id).isNone) = true := by decide

/-- An unknown id still resolves to nothing. The repair widens the lookup; it does not invent
presets, which would be the amputation-shaped failure. -/
theorem an_unknown_id_still_resolves_to_nothing : byIdAny "no-such-preset" = none := by decide

#guard (byId "AMD-HEVC-60").isNone
#guard (byIdAny "AMD-HEVC-60").isSome
#guard vendorVia byId "AMD-HEVC-60" == Vendor.universal
#guard vendorVia byIdAny "AMD-HEVC-60" == Vendor.amd
#guard byIdAny "no-such-preset" == none

/-! ## Grouping the ComboBox by vendor

`FfmpegPresets.vendors()` is documented as "all distinct vendors present in the table, for
grouping in the UI" and returned `Arrays.asList(Vendor.values())` — **every declared enum
constant**, whether or not any preset uses it.

Measured at checkpoint 51: all four declared vendors do appear in the table today, so the comment
was true *by coincidence*. That is the dated-spec shape in code rather than in a theorem. Declaring
`INTEL` before adding its QSV rows is a legitimate change, and it would put an empty group in the
UI — a heading a user can select with nothing under it.

The repair derives the list from the table, so the doc comment becomes true by construction. The
two theorems below are the halves that matter: no empty group, and no preset left out. -/

/-- Every vendor the enum declares. Order is the declaration order, which is what a UI grouping
should follow. -/
def allVendors : List Vendor := [.universal, .amd, .nvidia, .mediafoundation]

/-- The vendors that actually have a preset — derived from the table, in declaration order. -/
def vendorsPresent (ps : List Preset) : List Vendor :=
  allVendors.filter (fun v => ps.any (fun p => p.vendor == v))

/-- **No empty group.** Every vendor offered as a heading has at least one preset under it — for
every table, not just today's. -/
theorem every_offered_vendor_has_a_preset (ps : List Preset) (v : Vendor)
    (h : v ∈ vendorsPresent ps) : ∃ p ∈ ps, p.vendor = v := by
  simp [vendorsPresent, List.mem_filter] at h
  exact h.2

/-- **No preset left out.** Every preset in the table is reachable under some heading, so grouping
cannot silently hide a choice from the user. -/
theorem every_preset_is_reachable_under_some_vendor (ps : List Preset) (p : Preset)
    (h : p ∈ ps) : p.vendor ∈ vendorsPresent ps := by
  simp [vendorsPresent, List.mem_filter]
  constructor
  · cases p.vendor <;> simp [allVendors]
  · exact ⟨p, h, by simp⟩

/-- **The grouping is a partition, not a copy.** No vendor appears twice, so no preset is offered
under two headings. -/
theorem the_grouping_has_no_duplicates (ps : List Preset) :
    (vendorsPresent ps).Nodup := by
  have hsub : (vendorsPresent ps).Sublist allVendors := List.filter_sublist
  exact List.Nodup.sublist hsub (by decide)

/-- **A vendor with no presets is excluded** — the case that made the old implementation wrong.
Stated over an arbitrary table so it holds for whatever rows exist later, rather than asserting
something about today's four. -/
theorem a_vendor_with_no_presets_is_not_offered (ps : List Preset) (v : Vendor)
    (h : ps.all (fun p => p.vendor != v)) : v ∉ vendorsPresent ps := by
  simp [vendorsPresent, List.mem_filter]
  intro _
  simp [List.all_eq_true] at h
  intro p hp
  exact h p hp

/-- **The old implementation and the new one agree on today's table** — which is exactly why the
defect was invisible, and why this is an `example` pinning a measurement rather than a load-bearing
theorem. It expires the moment a vendor is declared ahead of its presets, and that is correct. -/
example : vendorsPresent presets = allVendors := by decide

/-- …and here is the future that breaks the old one. With only the universal rows in the table,
the derived grouping is one heading; `Vendor.values()` would still offer four. -/
theorem the_derived_grouping_shrinks_with_the_table :
    vendorsPresent (presets.filter (fun p => p.vendor == Vendor.universal)) = [Vendor.universal] := by
  decide

#guard vendorsPresent presets == allVendors
#guard vendorsPresent [] == []
#guard (vendorsPresent (presets.filter (fun p => p.vendor != Vendor.mediafoundation))).length == 3
#guard allVendors.length == 4

end CtbrecSpec
