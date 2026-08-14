/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — soundness of the configured ffmpeg argument set

The live `config/26.7.11/settings.json` on this machine carries

```
"ffmpegMergedDownloadArgs" : "-c:v hevc_amf -rc cqp -qp_i 22 -qp_p 22 -preset quality
    -vbaq true -preencode true -high_motion_quality_boost_enable true -tag:v hvc1
    -movflags frag_keyframe+empty_moov+default_base_moof+separate_moof -c:a copy -y"
"ffmpegFileSuffix" : "mp4"
```

## The correction that produced this version

The first version of this module claimed that **any** AAC stream copy from an
MPEG-TS source into an MP4 sink fails without `-bsf:a aac_adtstoasc`. Phase 6c of
`tools/spec-check.sh` — which re-measures the claim against the real binary — went
**red**: plain `-c copy -f mp4` succeeds, because ffmpeg's automatic bitstream
filtering inserts `aac_adtstoasc` on its own.

The spec was wrong, not the code. The measured matrix (ffmpeg 7.1.3-Jellyfin,
`-i s.ts` where `s.ts` carries H.264 + ADTS AAC):

  | video       | audio | `-movflags frag_*` | `-bsf:a aac_adtstoasc` | exit | output   |
  |-------------|-------|--------------------|------------------------|------|----------|
  | copy        | copy  | absent             | absent                 | 0    | 26348 B  |
  | copy        | copy  | **present**        | absent                 | FAIL | 4456 B   |
  | copy        | copy  | **present**        | present                | 0    | 26093 B  |
  | libx264     | copy  | absent             | absent                 | 0    | 27136 B  |
  | libx264     | copy  | **present**        | absent                 | FAIL | 4205 B   |

## SECOND correction — `fragmented` was still too coarse

The version above blamed a **fragmented** MP4 sink. That was measured only against the
full live flag set, which is why nothing contradicted it. A negative control added later
for `CtbrecSpec.Presets` — requiring the shipped `MP4` preset to fail — **passed the
encode instead of failing it**, and forced a per-token matrix (ffmpeg 8.0.1, ADTS-in-TS
source, `-c:v copy -c:a copy -f mp4`):

  | `-movflags` | exit | output |
  |---|---|---|
  | *(none)* | 0 | 329 986 B |
  | `frag_keyframe` | 0 | 330 002 B |
  | `separate_moof` | 0 | 329 986 B |
  | `default_base_moof` | 0 | 329 978 B |
  | `faststart` | 0 | 329 986 B |
  | `frag_keyframe+separate_moof` | 0 | 330 002 B |
  | `frag_keyframe+separate_moof+faststart` | 0 | 330 002 B |
  | `isml+frag_keyframe+separate_moof` | 0 | 331 545 B |
  | **`empty_moov`** | **127** | 37 404 B |
  | **`frag_keyframe+empty_moov`** | **127** | 37 404 B |
  | **`empty_moov+separate_moof`** | **127** | 37 404 B |
  | **`frag_keyframe+empty_moov+default_base_moof+separate_moof`** | **127** | 37 388 B |

**`empty_moov` is necessary and sufficient**: 4 of 4 combinations containing it fail,
8 of 8 without it succeed. The mechanism is now obvious — `empty_moov` writes the `moov`
box up front, before the muxer has seen an AAC frame from which to build the sample
entry, so there is nothing to retrofit. `frag_keyframe` alone writes `moov` late and is
perfectly safe. Adding `-bsf:a aac_adtstoasc` repairs it (measured: 328 711 B, exit 0).

So `Encode.fragmented` is now `Encode.emptyMoov`. The predicate got sharper a second
time, and **the live configuration's verdict is unchanged** — its `-movflags` string
contains `empty_moov`, so it is still unsound on any TS-delivering site. What changed is
that the shipped `MP4` and `MOV` presets are **not** unsound after all: they use
`frag_keyframe+separate_moof+faststart`, with no `empty_moov`. A theorem claiming
otherwise was deleted, not weakened — it was false of reality.

This is the second time a control caught the spec rather than the code, and both times
the control was one that had to be able to fail. `unsoundV1` and `unsoundV2` below keep
both superseded predicates so the refinement is a proof and not a memory.

## Why this matters twice over

1. Any site delivering **MPEG-TS** HLS segments, recorded with the live settings,
   produces a ~4 KiB stub instead of a recording. Chaturbate LL-HLS ships fMP4 and is
   unaffected, which is why the failure is intermittent and was never traced.
2. Before the fix in `CtbrecSpec.FFmpegExit`, that failure exited non-zero, was scored
   clean by `exitCode != 1`, and the ffmpeg log explaining it was deleted. Silent.

## On expiry

This states a fact about ADTS and ASC framing under a fragmented muxer, not about a
version number. `tools/spec-check.sh` phase 6c re-measures all three rows that matter
against the real binary on every run; if a future ffmpeg learns to insert the filter
for fragmented output too, that phase goes red and says the spec is stale. Fix the
spec then — do not weaken the theorems to silence it. That is precisely how this
version came to exist.

An unrelated fact measured while isolating the above, recorded so it is not
rediscovered the hard way: `hevc_amf` **fails at 160x90 and succeeds from 320x180
upward**. It is a property of the AMF encoder, has nothing to do with AAC framing,
and is deliberately not modelled here.
-/

namespace CtbrecSpec

/-- The five bits of an ffmpeg invocation that decide whether an AAC stream copy can
succeed. Everything else in the argument string is irrelevant to this question. -/
structure Encode where
  /-- `-c:a copy` or a bare `-c copy`: the audio is remuxed, not re-encoded. -/
  audioCopy : Bool
  /-- The input carries ADTS-framed AAC — true for MPEG-TS HLS segments. -/
  adtsSource : Bool
  /-- The output muxer is mp4/mov, which requires ASC-framed AAC. -/
  mp4Sink : Bool
  /-- `-movflags` contains **`empty_moov`**, or the muxer implies it (`-f dash`,
  `-f ismv`). Measured necessary and sufficient: the `moov` box is written before the
  muxer has seen an AAC frame, so there is no sample entry to retrofit and automatic
  bitstream filtering cannot rescue it. `frag_keyframe`, `separate_moof`,
  `default_base_moof`, `faststart` and `isml` are all safe on their own and in every
  combination that omits `empty_moov` — 8 of 8 measured. -/
  emptyMoov : Bool
  /-- `-bsf:a aac_adtstoasc` is present in the argument string. -/
  adtsToAsc : Bool
  deriving DecidableEq, Repr

/-- The unsound combination: copying ADTS AAC into a **fragmented** MP4 sink without
converting the framing. This is the preflight predicate the Java implements. -/
def unsound (e : Encode) : Bool :=
  e.audioCopy && e.adtsSource && e.mp4Sink && e.emptyMoov && !e.adtsToAsc

/-! ## Measured rows

`#guard`s, not theorems: they pin the five invocations actually executed against the
real binary. Row 2 is the failure; every other row is a control that must stay green,
because a predicate that flags everything is worthless. -/

#guard unsound ⟨true, true, true, false, false⟩ == false  -- plain mp4: auto-bsf saves it
#guard unsound ⟨true, true, true, true,  false⟩ == true   -- fragmented, no bsf: FAILS
#guard unsound ⟨true, true, true, true,  true⟩  == false  -- fragmented + bsf: ok
#guard unsound ⟨true, true, false, true, false⟩ == false  -- TS sink: ok
#guard unsound ⟨true, false, true, true, false⟩ == false  -- fMP4 source: ok

/-! ## The general statements -/

/-- Exactly which configurations are rejected. Stated as an iff so the predicate
cannot quietly grow or shrink under later edits. -/
theorem unsound_iff (e : Encode) :
    unsound e = true ↔
      (e.audioCopy = true ∧ e.adtsSource = true ∧ e.mp4Sink = true ∧
       e.emptyMoov = true ∧ e.adtsToAsc = false) := by
  simp [unsound, and_assoc]

/-- **The repair always works.** Adding the bitstream filter makes any configuration
sound, whatever else it contains. The preflight message tells the user to do exactly
this, so it had better be true — and it is measured in phase 6c as well. -/
theorem adtsToAsc_repairs (e : Encode) : unsound { e with adtsToAsc := true } = false := by
  simp [unsound]

/-- **A non-fragmented sink is always safe**, which is what the first version of this
module got wrong. ffmpeg's automatic bitstream filtering covers it. -/
theorem unfragmented_is_safe (e : Encode) (h : e.emptyMoov = false) : unsound e = false := by
  simp [unsound, h]

/-- An output that is not an mp4 sink cannot trip the rule — why users on the TS
preset never saw this. -/
theorem ts_sink_is_safe (e : Encode) (h : e.mp4Sink = false) : unsound e = false := by
  simp [unsound, h]

/-- Re-encoding the audio instead of copying it is always sound. -/
theorem transcoding_is_safe (e : Encode) (h : e.audioCopy = false) : unsound e = false := by
  simp [unsound, h]

/-- An fMP4 source — what Chaturbate LL-HLS delivers — is always sound. This is the
theorem that explains why the defect is intermittent rather than constant. -/
theorem fmp4_source_is_safe (e : Encode) (h : e.adtsSource = false) : unsound e = false := by
  simp [unsound, h]

/-- **The preflight is conservative in the right direction**: it flags only
configurations that genuinely cannot work, so it can never block a working setup.
Any one of the five escape routes suffices. -/
theorem preflight_never_blocks_a_working_config (e : Encode)
    (h : e.adtsToAsc = true ∨ e.emptyMoov = false ∨ e.mp4Sink = false ∨
         e.adtsSource = false ∨ e.audioCopy = false) :
    unsound e = false := by
  rcases h with h | h | h | h | h <;> simp [unsound, h]

/-- The strictly-sharper claim, stated because it is the correction itself: the
current predicate rejects **fewer** configurations than the first version, and every
configuration it still rejects was rejected before. No user who worked before gets
flagged now. -/
def unsoundV1 (e : Encode) : Bool :=
  e.audioCopy && e.adtsSource && e.mp4Sink && !e.adtsToAsc

/-- The superseded predicate pinned exactly, so that it is a faithful record of what
the first version claimed rather than a definition drifting free. Mutation testing
found this missing: without it, dropping the `mp4Sink` conjunct from `unsoundV1`
changed nothing that any theorem could see. -/
theorem unsoundV1_iff (e : Encode) :
    unsoundV1 e = true ↔
      (e.audioCopy = true ∧ e.adtsSource = true ∧ e.mp4Sink = true ∧ e.adtsToAsc = false) := by
  simp [unsoundV1, and_assoc]

theorem correction_is_strictly_weaker (e : Encode) :
    unsound e = true → unsoundV1 e = true := by
  simp +contextual [unsound, unsoundV1]

theorem correction_is_strict : ∃ e : Encode, unsoundV1 e = true ∧ unsound e = false :=
  ⟨⟨true, true, true, false, false⟩, by decide, by decide⟩

/-! ## The second correction, as a refinement chain

`unsoundV2` is what this module claimed between the two corrections: any **fragmented**
layout was blamed. The per-token matrix in the header shows that was still an
over-approximation — it would have flagged `frag_keyframe+separate_moof`, measured to
work. `unsound` (V3) blames `empty_moov` alone.

The chain is proved, not remembered: V3 ⟹ V2 ⟹ V1, each inclusion strict. -/

/-- The superseded second predicate. `fragOnly` stands for a fragmenting `-movflags`
token that is **not** `empty_moov` — exactly the configurations V2 got wrong. -/
def unsoundV2 (e : Encode) (fragOnly : Bool) : Bool :=
  e.audioCopy && e.adtsSource && e.mp4Sink && (e.emptyMoov || fragOnly) && !e.adtsToAsc

/-- Pinned as an iff so a mutation to `unsoundV2` cannot pass unnoticed — the lesson
`unsoundV1_iff` taught. -/
theorem unsoundV2_iff (e : Encode) (fragOnly : Bool) :
    unsoundV2 e fragOnly = true ↔
      (e.audioCopy = true ∧ e.adtsSource = true ∧ e.mp4Sink = true ∧
        (e.emptyMoov = true ∨ fragOnly = true) ∧ e.adtsToAsc = false) := by
  simp [unsoundV2, and_assoc]

/-- **The second correction only ever removes false alarms.** Everything the current
predicate rejects, the previous one rejected too. -/
theorem second_correction_is_weaker (e : Encode) (fragOnly : Bool) :
    unsound e = true → unsoundV2 e fragOnly = true := by
  simp +contextual [unsound, unsoundV2]

/-- And it is a real removal: `frag_keyframe+separate_moof` with no `empty_moov` was
flagged by V2 and is measured to work. -/
theorem second_correction_is_strict :
    ∃ e : Encode, unsoundV2 e true = true ∧ unsound e = false :=
  ⟨⟨true, true, true, false, false⟩, by decide, by decide⟩

/-- The whole chain in one statement: each version rejects a subset of the last. -/
theorem refinement_chain (e : Encode) (fragOnly : Bool) :
    (unsound e = true → unsoundV2 e fragOnly = true) ∧
      (unsoundV2 e fragOnly = true → unsoundV1 e = true) := by
  constructor <;> simp +contextual [unsound, unsoundV1, unsoundV2]

/-- **The live configuration's verdict survived both corrections.** This is the point:
sharpening the predicate twice did not excuse the setting that is actually in
`settings.json`, which contains `empty_moov`. -/
theorem live_verdict_unchanged_by_both_corrections :
    unsound ⟨true, true, true, true, false⟩ = true ∧
      unsoundV2 ⟨true, true, true, true, false⟩ true = true ∧
      unsoundV1 ⟨true, true, true, true, false⟩ = true := by decide

/-- The shipped `MP4`/`MOV` presets, by contrast, were exonerated by the second
correction: `frag_keyframe+separate_moof+faststart` carries no `empty_moov`. Recorded
because a theorem asserting they were broken had to be **deleted** — it was false. -/
theorem shipped_ui_presets_are_sound_after_all :
    unsound ⟨true, true, true, false, false⟩ = false ∧
      unsoundV2 ⟨true, true, true, false, false⟩ true = true := by decide

/-! ## The live configuration, named rather than inlined

Named so that when `settings.json` changes these statements change with it, instead of
silently going stale. -/

/-- The live args recording a site that delivers MPEG-TS segments. -/
def liveConfigOnTsSite : Encode :=
  { audioCopy := true, adtsSource := true, mp4Sink := true, emptyMoov := true, adtsToAsc := false }

theorem live_config_is_unsound_on_ts : unsound liveConfigOnTsSite = true := by decide

/-- The same configuration recording Chaturbate LL-HLS, which delivers fMP4. -/
def liveConfigOnFmp4Site : Encode := { liveConfigOnTsSite with adtsSource := false }

theorem live_config_is_sound_on_fmp4 : unsound liveConfigOnFmp4Site = false := by decide

/-- And the one-token repair for the live configuration. -/
def liveConfigRepaired : Encode := { liveConfigOnTsSite with adtsToAsc := true }

theorem live_config_repaired_is_sound : unsound liveConfigRepaired = false := by decide

/-! ## The classifier: deciding `adtsSource` from a URL

**A live false positive, measured 2026-08-03, and the reason this section exists.**

`unsound` above is correct and always was. What was wrong is the *classifier* that produces
its `adtsSource` input from the ffmpeg command line. It read:

```java
return s.endsWith(".ts") || s.endsWith(".aac") || s.endsWith(".m3u8");
```

An HLS playlist is not evidence of ADTS framing. `.m3u8` can serve **MPEG-TS segments**
(ADTS AAC, needs `aac_adtstoasc`) or **fMP4/CMAF segments** (ASC AAC, must not have it).
The URL alone cannot tell them apart.

MEASURED: the running app previewed `-i http://127.0.0.1:11324/video/playlist.m3u8` —
ctbrec's own LL-HLS fMP4 muxer — with `-c:a copy` into a fragmented MP4 and **no**
`aac_adtstoasc`. The preflight logged *"ffmpeg arguments cannot work for this input"*. The
recording that came out was 27 MB, 40.0 s of hevc + aac, and the audio decoded with **zero
errors at exit 0**. Had the source really been ADTS, ffmpeg would have aborted; it did not,
so the source was ASC and the alarm was false.

The fix is NOT to delete the check or to weaken `unsound` — the definite cases are real and
stay exactly as they were. It is to stop claiming certainty the URL cannot support. -/

/-- What a URL can tell us about the framing of its audio. -/
inductive AdtsEvidence where
  /-- `.ts` / `.aac` — raw ADTS framing, certain. -/
  | definite
  /-- `.m3u8` — a playlist. Could be TS segments or fMP4 segments; the URL does not say. -/
  | unknown
  /-- Anything else — no reason to think ADTS. -/
  | none
  deriving DecidableEq, Repr, Inhabited

/-- All three, for exhaustive checks. -/
def allEvidence : List AdtsEvidence := [.definite, .unknown, .none]

/-- **Only definite evidence may drive a "cannot work" claim.** `unknown` must not, which is
the whole correction. -/
def certainlyAdts : AdtsEvidence → Bool
  | .definite => true
  | .unknown => false
  | .none => false

/-- Whether the preflight should say anything at all. `unknown` still deserves a conditional
note — silence would be the opposite error, and would lose the genuine TS-HLS case. -/
def worthMentioning : AdtsEvidence → Bool
  | .definite => true
  | .unknown => true
  | .none => false

/-- **The playlist case is exactly the one that must not be asserted.** -/
theorem playlist_url_cannot_decide_the_framing :
    certainlyAdts AdtsEvidence.unknown = false ∧
      worthMentioning AdtsEvidence.unknown = true := by decide

/-- **The definite cases are untouched.** This is the anti-weakening clause: the correction
removes a false claim without disarming the real detection. -/
theorem definite_evidence_still_fires :
    certainlyAdts AdtsEvidence.definite = true ∧
      worthMentioning AdtsEvidence.definite = true := by decide

/-- A source with no ADTS evidence is never mentioned at all. -/
theorem clean_source_is_silent :
    certainlyAdts AdtsEvidence.none = false ∧
      worthMentioning AdtsEvidence.none = false := by decide

/-- Certainty implies mention: nothing can be certain yet unreported. -/
theorem certain_implies_mentioned (e : AdtsEvidence) :
    certainlyAdts e = true → worthMentioning e = true := by
  cases e <;> decide

/-- **Exactly one of the three kinds licenses a certain diagnosis.** Pins the correction to a
number, so a mutation that re-admits `unknown` — the original bug — is caught. -/
theorem exactly_one_kind_is_certain :
    (allEvidence.filter certainlyAdts).length = 1 ∧
      (allEvidence.filter worthMentioning).length = 2 := by decide

/-- The old classifier, kept so the change is visible and testable rather than asserted. -/
def certainlyAdtsV1 : AdtsEvidence → Bool
  | .definite => true
  | .unknown => true      -- the bug: a playlist was treated as proof of ADTS framing
  | .none => false

/-- **The correction is a real change, and it changes exactly one case.** If a future edit
made the two agree again, this goes red. -/
theorem classifier_fix_changes_exactly_the_playlist_case :
    (allEvidence.filter (fun e => certainlyAdtsV1 e != certainlyAdts e)) =
      [AdtsEvidence.unknown] := by decide

/-- And it only ever removes certainty — it never starts claiming a source is ADTS that the
old classifier considered clean. A correction that added false positives elsewhere would be
no better than the bug. -/
theorem classifier_fix_only_removes_certainty (e : AdtsEvidence) :
    certainlyAdts e = true → certainlyAdtsV1 e = true := by
  cases e <;> decide

/-- Tying it back: with the corrected classifier, the live configuration that produced a
valid 27 MB recording is NOT diagnosed as unsound. -/
def liveConfigOnPlaylist : Encode :=
  { audioCopy := true, adtsSource := certainlyAdts AdtsEvidence.unknown,
    mp4Sink := true, emptyMoov := true, adtsToAsc := false }

/-- **The false positive is gone.** -/
theorem live_playlist_config_is_not_flagged : unsound liveConfigOnPlaylist = false := by decide

/-- While a genuine `.ts` source with the same arguments still is. Detection power intact. -/
def liveConfigOnDefiniteTs : Encode :=
  { liveConfigOnPlaylist with adtsSource := certainlyAdts AdtsEvidence.definite }

theorem definite_ts_config_is_still_flagged : unsound liveConfigOnDefiniteTs = true := by decide

#guard certainlyAdts AdtsEvidence.unknown == false
#guard certainlyAdtsV1 AdtsEvidence.unknown == true
#guard unsound liveConfigOnPlaylist == false
#guard unsound liveConfigOnDefiniteTs == true

end CtbrecSpec
