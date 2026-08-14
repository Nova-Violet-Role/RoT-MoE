/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — Chaturbate LL-HLS sequence tracking

Subject: `src/common/ctbrec/sites/chaturbate/ChaturbateLlhlsDownload.java`, the
downloader responsible for most of the WARN traffic in `ctbrec.log`.

Two pieces of the state machine are transcribed here.

`captureNewSegments` (`:320-335`)
```java
int updatedSequence = nextSequence;
for (ChaturbateLlhlsSegment segment : playlist.segments()) {
   if (segment.sequence() >= nextSequence) {          // NB: the ORIGINAL nextSequence
      if (!this.downloadSegment(workspace, segment)) return updatedSequence;
      updatedSequence = segment.sequence() + 1;
   }
}
return updatedSequence;
```

`adjustForLiveWindow` (`:377-396`)
```java
if (!playlist.isEmpty() && nextSequence < playlist.mediaSequence()) {
   ... log ...
   return playlist.mediaSequence();
} else {
   return nextSequence;
}
```

A media playlist is a **window of consecutive sequence numbers** starting at
`EXT-X-MEDIA-SEQUENCE`, which is what `Playlist` encodes. The loop's threshold is the
*original* `nextSequence`, never the running accumulator — `foldSeg` preserves that,
because it is the detail that makes the closed form provable.

The defect settled here: `adjustForLiveWindow` corrects only the case where the
tracker has fallen **behind** the live window. If the server renumbers downward — a
new stream session, an encoder restart — the tracker is left **ahead** of every
segment offered, nothing satisfies `>= nextSequence`, and capture makes no progress
until the 30-second `lastTransfer` watchdog at `:176` kills the recording. Nothing in
the log explains why.
-/

namespace CtbrecSpec

/-- A media playlist: `count` consecutive segments starting at `mediaSequence`.
Sequence numbers are `Int` because Java holds them in an `int`. -/
structure Playlist where
  /-- `EXT-X-MEDIA-SEQUENCE`: the sequence number of the first segment in the window. -/
  mediaSequence : Int
  /-- How many segments the live window currently holds. -/
  count : Nat
  deriving DecidableEq, Repr

/-- The segment sequence numbers, in playlist order. -/
def segsFrom (ms : Int) : Nat → List Int
  | 0 => []
  | n + 1 => ms :: segsFrom (ms + 1) n

/-- The segments of a playlist. -/
def Playlist.segs (p : Playlist) : List Int := segsFrom p.mediaSequence p.count

/-- `playlist.isEmpty()` — the Java predicate, kept so the model names match. -/
def Playlist.isEmpty (p : Playlist) : Bool := p.count == 0

/-- The last sequence number in the window. Only meaningful when `count > 0`. -/
def Playlist.last (p : Playlist) : Int := p.mediaSequence + (p.count : Int) - 1

/-- `isEmpty` and `count` agree, so the arithmetic form of the guards below is the
same condition the Java tests. -/
theorem isEmpty_iff (p : Playlist) : p.isEmpty = false ↔ 0 < p.count := by
  simp [Playlist.isEmpty]
  omega

/-! ## The capture loop -/

/-- The body of `captureNewSegments`: `thr` is the *original* `nextSequence`, held
fixed for the whole loop; `acc` is `updatedSequence`. -/
def foldSeg (thr : Int) : Int → List Int → Int
  | acc, [] => acc
  | acc, s :: rest => foldSeg thr (if thr ≤ s then s + 1 else acc) rest

/-- `captureNewSegments(playlist, nextSequence, _)`, assuming every download
succeeds — the early `return` at `:326` is reachable only during shutdown. -/
def capture (next : Int) (p : Playlist) : Int := foldSeg next next p.segs

/-- **Closed form of the loop.** The fold advances to one past the end of the window
exactly when some segment sits at or past the threshold, and otherwise leaves the
accumulator untouched. Every statement below is therefore about the real loop rather
than about a guess at what it does. -/
theorem foldSeg_segsFrom (thr : Int) : ∀ (n : Nat) (ms acc : Int),
    foldSeg thr acc (segsFrom ms n) =
      if 0 < n ∧ thr ≤ ms + (n : Int) - 1 then ms + (n : Int) else acc
  | 0, ms, acc => by simp [segsFrom, foldSeg]
  | n + 1, ms, acc => by
    rw [segsFrom, foldSeg, foldSeg_segsFrom thr n (ms + 1)]
    have hc : ((n + 1 : Nat) : Int) = (n : Int) + 1 := by push_cast; omega
    rw [hc]
    split <;> split <;> (try split) <;> omega

/-- The loop, in closed form, stated over a playlist. -/
theorem capture_eq (next : Int) (p : Playlist) :
    capture next p =
      if 0 < p.count ∧ next ≤ p.last then p.mediaSequence + (p.count : Int) else next := by
  -- v4.33.0-rc1 leaves `X = X` where the two `if`s differ ONLY in their `Decidable`
  -- instance -- one from unfolding `capture`, one from elaborating this statement. `simp` and
  -- `split` both refuse: there is no syntactic `if` to split, and the terms are not
  -- definitionally equal through the instances. Case-splitting on the CONDITION rewrites both
  -- sides with `if_pos`/`if_neg`, which unify the instance away, and works on both toolchains.
  simp only [capture, Playlist.segs, Playlist.last, foldSeg_segsFrom]
  by_cases h : 0 < p.count ∧ next ≤ p.mediaSequence + (p.count : Int) - 1 <;> simp [h]

/-- **No rewind.** The tracker never moves backwards, whatever the playlist says.
Without this, a stale window could make ctbrec re-download and re-append segments it
had already written, corrupting the recording. -/
theorem capture_monotone (next : Int) (p : Playlist) : next ≤ capture next p := by
  rw [capture_eq]
  simp only [Playlist.last]
  by_cases h : 0 < p.count ∧ next ≤ p.mediaSequence + (p.count : Int) - 1 <;>
    simp [h] <;> omega

/-- Capture fetches something exactly when the window still holds a segment the
tracker has not consumed. -/
def progress (next : Int) (p : Playlist) : Prop := 0 < p.count ∧ next ≤ p.last

instance (next : Int) (p : Playlist) : Decidable (progress next p) := by
  unfold progress; infer_instance

/-- Progress is precisely a change in the tracker: it advances iff there was
something left to fetch. -/
theorem progress_iff_advance (next : Int) (p : Playlist) :
    progress next p ↔ next < capture next p := by
  rw [capture_eq]
  simp only [progress, Playlist.last]
  by_cases h : 0 < p.count ∧ next ≤ p.mediaSequence + (p.count : Int) - 1 <;>
    simp [h] <;> omega

/-! ## `adjustForLiveWindow` — the defect and the fortification

`0 < p.count` is `!playlist.isEmpty()` (see `isEmpty_iff`), written arithmetically so
the guards are decidable and `omega` can reason about them. -/

/-- `adjustForLiveWindow` exactly as shipped (`:377-396`). -/
def adjustLegacy (next : Int) (p : Playlist) : Int :=
  if 0 < p.count ∧ next < p.mediaSequence then p.mediaSequence else next

/-- The fortified rule: resync to the live window when the tracker is behind it **or
past its end**. `p.last + 1` is the caught-up position — the tracker reaches it
legitimately after consuming the whole window — so only a tracker *strictly beyond*
`p.last + 1` has lost contact with the stream, which can only happen if the server
renumbered downward. -/
def adjustFortified (next : Int) (p : Playlist) : Int :=
  if 0 < p.count ∧ (next < p.mediaSequence ∨ p.last + 1 < next) then p.mediaSequence else next

/-- The fortification is a **refinement, not a rewrite**: wherever the shipped rule
already resynced, the fortified rule resyncs to the same place. Nothing that worked
stops working. -/
theorem fortified_refines_legacy (next : Int) (p : Playlist)
    (h : adjustLegacy next p ≠ next) : adjustFortified next p = adjustLegacy next p := by
  simp only [adjustLegacy, adjustFortified] at h ⊢
  split at h
  · next hc =>
    rw [if_pos ⟨hc.1, Or.inl hc.2⟩, if_pos hc]
  · exact absurd rfl h

/-- **The stall, exhibited.** A server that renumbers downward leaves the shipped
rule with a tracker beyond the whole window: it resyncs nothing, and the closed form
says capture returns the tracker unchanged — not one segment is fetched. -/
theorem legacy_stalls :
    ∃ (next : Int) (p : Playlist),
      0 < p.count ∧ adjustLegacy next p = next ∧ capture (adjustLegacy next p) p = next := by
  refine ⟨100, ⟨0, 3⟩, by decide, by decide, ?_⟩
  rw [show adjustLegacy 100 ⟨0, 3⟩ = 100 by decide, capture_eq]
  decide

/-- **The fortification, stated so it cannot expire.** For any non-empty window the
fortified rule leaves the tracker at most one past the end: either there is work to
do, or ctbrec is exactly caught up. It never strands the tracker beyond the stream,
for any playlist and any prior position. -/
theorem fortified_never_strands (next : Int) (p : Playlist) (h : 0 < p.count) :
    adjustFortified next p ≤ p.last + 1 := by
  -- Same v4.33 `Decidable`-instance obstruction as `capture_eq`: there is no syntactic `if`
  -- for `split` to take hold of. Splitting on the condition works on both toolchains, and
  -- `0 < p.count` is already in scope as `h`, so the guard reduces to the disjunction.
  by_cases hc : next < p.mediaSequence ∨ p.last + 1 < next <;>
    simp [adjustFortified, Playlist.last, h] <;> omega

/-- The consequence that matters: after the fortified adjust, capture either makes
progress or the tracker is exactly caught up. A silent stall is impossible. -/
theorem fortified_progress_or_caught_up (next : Int) (p : Playlist) (h : 0 < p.count) :
    progress (adjustFortified next p) p ∨ adjustFortified next p = p.last + 1 := by
  have hb := fortified_never_strands next p h
  by_cases heq : adjustFortified next p = p.last + 1
  · exact Or.inr heq
  · exact Or.inl ⟨h, by omega⟩

/-- The shipped rule carries no such guarantee — the same statement is false for it. -/
theorem legacy_can_strand :
    ∃ (next : Int) (p : Playlist), 0 < p.count ∧ p.last + 1 < adjustLegacy next p :=
  ⟨100, ⟨0, 3⟩, by decide, by decide⟩

/-! ## Executable checks

`#guard`s, not theorems: they document concrete windows of the shape seen in
`ctbrec.log`. -/

#guard capture 5 ⟨5, 3⟩ == 8           -- fresh window, consume all three
#guard capture 8 ⟨5, 3⟩ == 8           -- exactly caught up, nothing new
#guard capture 100 ⟨0, 3⟩ == 100       -- the stall: tracker beyond the window
#guard adjustLegacy 100 ⟨0, 3⟩ == 100  -- shipped rule does not notice
#guard adjustFortified 100 ⟨0, 3⟩ == 0 -- fortified rule resyncs to the window start
#guard adjustLegacy 2 ⟨5, 3⟩ == 5      -- both agree when the tracker is behind
#guard adjustFortified 2 ⟨5, 3⟩ == 5
#guard adjustFortified 8 ⟨5, 3⟩ == 8   -- caught up is left alone
#guard capture (adjustFortified 100 ⟨0, 3⟩) ⟨0, 3⟩ == 3  -- and then capture progresses

/-! ## 4. Two tracks resync INDEPENDENTLY — a latent A/V hazard

`adjustForLiveWindow` (`ChaturbateLlhlsDownload.java:376`) takes a `trackName` and is called once
per track. Audio and video each jump to **their own** `playlist.mediaSequence()`, with no
cross-track coordination, while `-itsoffset` is computed once at start by
`ChaturbateLlhlsInputAlignment`. A mid-stream resync therefore happens *after* the only alignment
the muxer ever performs.

**Measured in the log** (`ctbrec.log`, 136 gap events): 44 same-second audio+video gap pairs, of
which **33 skipped the same number of segments and 11 did not**; worst mismatch 1 segment. One
concrete pair, both tracks expecting seq 2953: video resynced to 2961 (skip 8), audio to 2962
(skip 9).

**What this section does NOT claim.** Nine recordings measured over 08-03/08-04 contain **zero**
gap events and still drift up to 1.433 s, so gaps are *not* the cause of the residual drift.
That is a MEASURED negative result, and it is why this stays a modelled hazard rather than a
drift fix. The gap warnings have also been dormant since 2026-08-02 06:46 (46 h).

Everything below is parametric in the segment duration: no duration constant is invented, and the
statements hold for whatever the real value is. -/

/-- One track's view of a resync: where it expected to be, and where the live window starts. -/
structure TrackResync where
  expected : Int
  windowStart : Int
deriving DecidableEq, Repr

/-- Segments skipped by a track, never negative: a track at or ahead of the window skips none.
Mirrors the `nextSequence < playlist.mediaSequence()` guard at `:400`. -/
def skipped (t : TrackResync) : Int := max 0 (t.windowStart - t.expected)

/-- Media time discarded by a track, in milliseconds, for a segment duration `segMs`. -/
def skippedMs (segMs : Int) (t : TrackResync) : Int := skipped t * segMs

/-- The uncompensated offset the resync introduces between the two tracks. -/
def resyncDivergenceMs (segMs : Int) (v a : TrackResync) : Int :=
  skippedMs segMs v - skippedMs segMs a

/-- Decidable detector: did this resync pull the tracks apart? -/
def resyncDiverged (v a : TrackResync) : Bool := skipped v != skipped a

/-- **Equal skips stay aligned, for every segment duration.** The safe case is safe for the right
reason, not by accident of one duration. -/
theorem equal_skips_stay_aligned (segMs : Int) (v a : TrackResync)
    (h : skipped v = skipped a) : resyncDivergenceMs segMs v a = 0 := by
  simp [resyncDivergenceMs, skippedMs, h]

/-- **The hazard is real**: the measured pair (video skip 8, audio skip 9 from expected 2953)
leaves the tracks one segment apart. Not a hypothetical — these numbers are from the log. -/
theorem the_measured_pair_diverges :
    resyncDiverged ⟨2953, 2961⟩ ⟨2953, 2962⟩ = true := by decide

/-! ### The shipped report

`ResyncDivergenceTracker` (`src/common/ctbrec/sites/chaturbate/ResyncDivergenceTracker.java`) is
now wired into `adjustForLiveWindow`, **observation only**: it never changes the returned sequence
and cannot affect capture. The coordination fix remains unshipped — gap events have been dormant
since 2026-08-02, so a behavioural change could not be verified against a live trigger.

The segment duration is read from the playlist's last segment. It can be missing, and that makes
the report three-valued for the same reason `PacingVerdict`, `AlignmentOutcome` and
`CohortVerdict` are: **an unmeasured duration must never be replaced by a guessed constant.**
The divergence in segments is still exact and still worth reporting. -/

inductive DivergenceReport where
  | aligned
  | diverged (segments : Int) (ms : Int)
  | divergedDurationUnknown (segments : Int)
  deriving DecidableEq, Repr

/-- `segMs ≤ 0` means the duration could not be read. Mirrors `ResyncDivergenceTracker.record`. -/
def divergenceReport (segMs : Int) (v a : TrackResync) : DivergenceReport :=
  if skipped v == skipped a then .aligned
  else if 0 < segMs then .diverged (skipped v - skipped a) (resyncDivergenceMs segMs v a)
  else .divergedDurationUnknown (skipped v - skipped a)

/-- **Silence is the normal case.** An agreeing pair reports nothing, so a report means something.
Durable: quantified over the duration and over any pair with equal skips. -/
theorem an_agreeing_pair_reports_aligned (segMs : Int) (v a : TrackResync)
    (h : skipped v = skipped a) : divergenceReport segMs v a = .aligned := by
  unfold divergenceReport
  simp [h]

/-- **The measured pair, as the app will now log it**: one segment, −1664 ms at the measured
1.664 s segment. -/
theorem the_measured_pair_reports_one_segment :
    divergenceReport 1664 ⟨2953, 2961⟩ ⟨2953, 2962⟩ = .diverged (-1) (-1664) := by decide

/-- **An unknown duration never fabricates a millisecond figure.** The segment count survives; the
ms value is absent rather than invented. This is the constructor that makes the difference
visible in the log instead of silently reporting a plausible wrong number. -/
theorem an_unknown_duration_reports_segments_only :
    divergenceReport 0 ⟨2953, 2961⟩ ⟨2953, 2962⟩ = .divergedDurationUnknown (-1) := by decide

theorem unknown_duration_is_not_aligned :
    divergenceReport 0 ⟨2953, 2961⟩ ⟨2953, 2962⟩ ≠ .aligned := by decide

/-- A negative duration is as unreadable as a missing one — no accidental third behaviour. -/
theorem a_negative_duration_is_also_unknown :
    divergenceReport (-5) ⟨2953, 2961⟩ ⟨2953, 2962⟩ = .divergedDurationUnknown (-1) := by decide

#guard divergenceReport 1664 ⟨2953, 2961⟩ ⟨2953, 2962⟩ == .diverged (-1) (-1664)
#guard divergenceReport 1664 ⟨2953, 2961⟩ ⟨2953, 2961⟩ == .aligned
#guard divergenceReport 0 ⟨2953, 2961⟩ ⟨2953, 2962⟩ == .divergedDurationUnknown (-1)
#guard divergenceReport 2000 ⟨2953, 2962⟩ ⟨2953, 2961⟩ == .diverged 1 2000

/-- And the offset it leaves is exactly one segment of media time, whatever a segment is worth. -/
theorem the_measured_pair_is_one_segment_off (segMs : Int) :
    resyncDivergenceMs segMs ⟨2953, 2961⟩ ⟨2953, 2962⟩ = -segMs := by
  have hv : skipped ⟨2953, 2961⟩ = 8 := by decide
  have ha : skipped ⟨2953, 2962⟩ = 9 := by decide
  simp [resyncDivergenceMs, skippedMs, hv, ha]
  omega

/-- **The detector agrees with the quantity.** A detector that could fire while the offset is
zero, or stay silent while it is not, would be an alarm wired to nothing. Stated for a positive
segment duration, since a zero-length segment makes every skip cost nothing. -/
theorem detector_fires_exactly_when_offset_is_nonzero (segMs : Int) (hpos : 0 < segMs)
    (v a : TrackResync) :
    resyncDiverged v a = true ↔ resyncDivergenceMs segMs v a ≠ 0 := by
  have hs : resyncDivergenceMs segMs v a = (skipped v - skipped a) * segMs := by
    simp [resyncDivergenceMs, skippedMs, Int.sub_mul]
  rw [hs]
  simp only [resyncDiverged, bne_iff_ne, ne_eq]
  constructor
  · intro h
    exact Int.mul_ne_zero (fun hz => h (Int.eq_of_sub_eq_zero hz)) (by omega)
  · intro h he
    exact h (by rw [he]; simp)

/-- **Anti-amputation: the detector must be silent when nothing is wrong.** Without this a
"fix" that reports divergence unconditionally would look like vigilance. -/
theorem detector_silent_when_aligned (v a : TrackResync) (h : skipped v = skipped a) :
    resyncDiverged v a = false := by
  simp [resyncDiverged, h]

/-- A track already at or beyond the live window skips nothing — the `else` branch at `:415`
returns `nextSequence` untouched, so no resync means no divergence. -/
theorem no_gap_means_no_skip (t : TrackResync) (h : t.windowStart ≤ t.expected) :
    skipped t = 0 := by
  simp [skipped]; omega

#guard skipped ⟨2953, 2961⟩ == 8
#guard skipped ⟨2953, 2962⟩ == 9
#guard resyncDiverged ⟨2953, 2961⟩ ⟨2953, 2962⟩ == true
#guard resyncDiverged ⟨2953, 2961⟩ ⟨1885, 1893⟩ == false   -- equal skips, different numbering
#guard resyncDivergenceMs 2000 ⟨2953, 2961⟩ ⟨2953, 2962⟩ == -2000
#guard skipped ⟨2961, 2953⟩ == 0                            -- ahead of the window: no skip

end CtbrecSpec
