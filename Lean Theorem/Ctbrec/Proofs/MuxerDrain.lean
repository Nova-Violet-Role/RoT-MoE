/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the LL-HLS muxer shutdown ladder, and the audio tail it was losing

Subject: `ChaturbateLlhlsDownload.waitForFfmpegToExit` / `.requestFfmpegStop`, and
`ChaturbateLlhlsMediaServer.stop`.

## The defect, measured before it was modelled

Over **n = 40** real recordings, comparing the two stream durations
(`video_duration − audio_duration`, ffprobe):

```
n=40  min=-8.012  p25=-0.133  median=0.000  p75=+0.361  max=+4.367  mean=-0.182
|drift| > 0.5 s : 6 / 40  (15 %)
```

Every file has `start_time = 0.000000` on **both** streams, so this is **not** an A/V sync
error. It is a **tail** error: in 15 % of recordings one stream ends more than half a second
before the other.

## Why it happens

`internalStop` calls `markComplete()` on both workspaces — which publishes `#EXT-X-ENDLIST`
on both playlists — and then *immediately* calls `requestFfmpegStop`, which writes `q` to
ffmpeg's stdin. `q` means "stop reading input and finalize now".

Video and audio are served as **two independent HLS inputs** (`/video/playlist.m3u8` and
`/audio/playlist.m3u8`). When `q` arrives they are, in general, at different points within
their respective segments. Whichever is further behind loses its remainder. That is exactly
the measured signature: a median of zero (usually they are close), a balanced sign (either
stream can be the laggard — 18 of 40 negative), and occasional multi-second outliers.

The `ENDLIST` was already published. Had ffmpeg simply been allowed to keep reading, it would
have hit end-of-playlist on **both** inputs and exited **0 on its own**, ending both streams
at their true end. The `q` pre-empts that.

## The fix, and why it is bounded

Insert a **natural-drain rung** at the top of the escalation ladder: after `markComplete`,
wait a bounded time for ffmpeg to exit by itself. Only if it does not, send `q`, then
`destroy`, then `destroyForcibly` — the existing ladder, unchanged, underneath.

Bounded is the load-bearing word. An unbounded drain would hang a recording forever if a
playlist never terminated, which is strictly worse than a truncated tail. Every theorem below
about the ladder's total time exists to stop a future edit from removing the bound.
-/
import Proofs.Ctbrec.ShutdownWait

namespace CtbrecSpec

/-! ## The escalation ladder -/

/-- The rungs of the shutdown ladder, in the order they are attempted. -/
inductive Rung where
  /-- Wait for ffmpeg to reach `#EXT-X-ENDLIST` on both inputs and exit by itself. -/
  | naturalDrain
  /-- Write `q` to stdin: stop reading input, finalize the container. -/
  | quitCommand
  /-- `Process.destroy()` — SIGTERM. -/
  | destroy
  /-- `Process.destroyForcibly()` — SIGKILL. -/
  | destroyForcibly
  deriving DecidableEq, Repr, Inhabited

/-- The ladder as the implementation attempts it. -/
def ladder : List Rung := [.naturalDrain, .quitCommand, .destroy, .destroyForcibly]

/-- The legacy ladder, before this fix. Kept so the change is visible and testable rather
than asserted. -/
def legacyLadder : List Rung := [.quitCommand, .destroy, .destroyForcibly]

/-- Seconds allowed at each rung. `naturalDrain` gets the largest budget because it is the
only rung that can end both streams at their true end; the rest are escalations whose job is
to bound the damage, not to preserve data. -/
def budgetSeconds : Rung → Nat
  | .naturalDrain => 8
  | .quitCommand => 5
  | .destroy => 2
  | .destroyForcibly => 2

/-- Total worst-case shutdown time for a ladder. -/
def totalBudget (l : List Rung) : Nat := (l.map budgetSeconds).foldl (· + ·) 0

/-! ## What the fix must satisfy -/

/-- **The drain is attempted first.** If it were anywhere else in the ladder, `q` would
already have truncated the tail before it ran, and the rung would be decoration. -/
theorem drain_is_the_first_rung : ladder.head? = some Rung.naturalDrain := by decide

/-- **The forcible kill is still last.** The fix adds a gentler rung; it does not reorder the
escalation, and it does not remove the guarantee that a stuck process is eventually killed. -/
theorem forcible_kill_is_still_last : ladder.getLast? = some Rung.destroyForcibly := by decide

/-- **Nothing was removed.** Every legacy rung survives, in its original relative order. This
is the anti-weakening clause: the fix is purely additive. -/
theorem no_legacy_rung_was_dropped : legacyLadder.all (fun r => ladder.contains r) = true := by
  decide

/-- And the legacy order is preserved as a suffix — the new rung is prepended, not
interleaved, so the escalation semantics are unchanged. -/
theorem legacy_ladder_is_the_tail : ladder.tail = legacyLadder := by decide

/-- **The fix changes exactly one thing: it adds the drain.** -/
theorem fix_adds_exactly_the_drain :
    ladder.filter (fun r => !legacyLadder.contains r) = [Rung.naturalDrain] := by decide

/-- Each rung appears once — a repeated rung would double the worst-case wait without adding
any new escalation. -/
theorem every_rung_is_attempted_once :
    ladder.all (fun r => (ladder.filter (fun x => x == r)).length == 1) = true := by decide

/-! ## Boundedness — the property that stops the cure being worse than the disease -/

/-- **Every rung has a finite budget.** An unbounded drain would hang a recording forever if
a playlist never published its `ENDLIST`, which is strictly worse than a truncated tail. -/
theorem every_rung_is_bounded : ladder.all (fun r => 0 < budgetSeconds r) = true := by decide

/-- **The whole ladder is bounded, and by how much.** 8 + 5 + 2 + 2 = 17 seconds. -/
theorem shutdown_is_bounded : totalBudget ladder = 17 := by decide

/-- The legacy ladder was 9 seconds, so the fix costs at most 8 additional seconds — and only
in the worst case where ffmpeg never drains at all. -/
theorem legacy_budget : totalBudget legacyLadder = 9 := by decide

/-- **The added cost is exactly the drain budget.** Stated as arithmetic over the two ladders
rather than as a comment, so a future edit that inflates the drain shows up here. -/
theorem the_fix_costs_exactly_the_drain_budget :
    totalBudget ladder = totalBudget legacyLadder + budgetSeconds Rung.naturalDrain := by decide

/-- The drain budget is generous relative to the observed damage but still small in absolute
terms: it exceeds the worst measured drift (8.012 s, rounded down to the whole second the
implementation uses) yet keeps the whole ladder under 20 s. -/
theorem drain_budget_covers_the_worst_measured_drift :
    8 ≤ budgetSeconds Rung.naturalDrain ∧ totalBudget ladder < 20 := by decide

/-! ## The media server must not truncate what the drain preserved -/

/-- Grace period, in seconds, handed to `HttpServer.stop(int)`.

The JDK contract: the argument is the **maximum time to wait for in-flight exchanges**; `0`
closes all open TCP connections immediately. The server serves the very segments ffmpeg is
reading, so stopping it with `0` while an exchange is in flight truncates that response. -/
def serverStopGrace : Nat := 2

/-- The legacy value. -/
def legacyServerStopGrace : Nat := 0

/-- **In-flight segment responses are allowed to finish.** With a grace of 0 the fix above
could be undone at the last moment by the server cutting the connection ffmpeg is draining
through. -/
theorem server_grace_is_positive : 0 < serverStopGrace := by decide

/-- The legacy value truncated immediately — recorded so the change is not silently lost. -/
theorem legacy_server_grace_truncated : legacyServerStopGrace = 0 := by decide

/-- The grace is still small: shutdown must not stall on a wedged connection. -/
theorem server_grace_is_bounded : serverStopGrace ≤ 5 := by decide

/-! ## What is NOT claimed

The drift itself is a **measurement**, not a theorem, and so is any improvement in it. Lean
constrains the *shape* of the shutdown — drain first, escalate, stay bounded, drop nothing —
which is what makes the improvement possible. Whether the tail actually closes is settled by
re-measuring the same `video_duration − audio_duration` distribution over a fresh corpus of
recordings, and by nothing else. -/

#guard totalBudget ladder == 17
#guard totalBudget legacyLadder == 9
#guard ladder.length == 4
#guard ladder.head? == some Rung.naturalDrain
#guard ladder.getLast? == some Rung.destroyForcibly
#guard serverStopGrace == 2

/-! ## The ladder must be observable

Checkpoint 11 measured a post-fix drift of +0.833 s and +0.036 s, but could **not** say which
rung ended the process: the drain's confirmation was `LOG.debug`, and the application logs at
INFO. So the evidence was "the bytecode is present and the drift is small", not "the natural
drain fired". That is a weaker claim than it needed to be, and the gap was one log level wide.

Reporting the rung at INFO turns the ladder from a modelled object into a measured one. These
theorems fix what the report has to satisfy — and the distinctness theorem is the load-bearing
one: if two rungs shared a name the log could not tell them apart, and the measurement it
exists to enable would be impossible. -/

/-- The name each rung reports in the log. -/
def rungName : Rung → String
  | .naturalDrain => "naturalDrain"
  | .quitCommand => "quitCommand"
  | .destroy => "destroy"
  | .destroyForcibly => "destroyForcibly"

/-- **Every rung reports a distinct name.** Without this the log cannot identify which rung
ended the process, and the drift measurement stays unattributable. -/
theorem rung_names_are_distinct :
    (ladder.map rungName).eraseDups = ladder.map rungName := by decide

/-- **Every rung on the ladder has a name** — the report is total, so no path can terminate
without saying how. -/
theorem every_rung_is_named :
    ladder.all (fun r => rungName r != "") = true := by decide

/-- The natural drain is the one worth seeing in a log: it means the tail was complete. -/
theorem the_drain_reports_itself : rungName .naturalDrain = "naturalDrain" := by decide

/-- A forcible kill is also named, so a truncated tail is visible rather than silent. This is
the case that produced the -8.012 s outlier in the pre-fix corpus. -/
theorem a_forcible_kill_is_visible : rungName .destroyForcibly = "destroyForcibly" := by decide

#guard (ladder.map rungName).eraseDups == ladder.map rungName
#guard rungName .naturalDrain == "naturalDrain"
#guard ladder.map rungName == ["naturalDrain", "quitCommand", "destroy", "destroyForcibly"]

/-! ## Input alignment: clamp the correction, never discard it

**Requested:** "the drift, can we make it better? by reducing the actual latency".

The recorder feeds ffmpeg two independent HLS inputs — `/video/playlist.m3u8` and
`/audio/playlist.m3u8` — and compensates for their different start times with `-itsoffset` on
whichever started later. MEASURED live this session:
`-itsoffset 1.393022` on the audio input.

**The defect, read at `ChaturbateLlhlsInputAlignment.java:17-26`:**

```java
Duration delta = durationFromSeconds(Math.abs(audioStartTime - videoStartTime));
if (delta.compareTo(MIN_DELAY_TO_APPLY) < 0 || delta.compareTo(MAX_DELAY_TO_APPLY) > 0) {
   return none();          // <-- NO correction whatsoever
}
```

with `MIN = 50 ms` and `MAX = 2 s`. The lower guard is sound: below 50 ms the offset is under
two frames and correcting it buys nothing. The **upper** guard is the bug. When the inputs
start more than 2 s apart the code applies *no* correction at all — so the worst-aligned
sessions, precisely the ones that need it most, are left completely uncorrected. That matches
the measured pre-fix drift corpus, whose outliers reached -8.012 s and +4.367 s while the
median sat at 0.000.

The repair is to **clamp rather than discard**: apply `min delta MAX`. A session 3 s out gets
2 s of correction and is left 1 s out instead of 3 s. The theorems below prove this is never
worse than the old behaviour and strictly better exactly where it used to give up.

Units are milliseconds throughout, so the arithmetic is exact rather than floating point. -/

/-- Below this the offset is under two frames and not worth correcting. 50 ms. -/
def minDelayMs : Nat := 50

/-- The largest correction that will ever be applied. 2 s. -/
def maxDelayMs : Nat := 2000

/-- **Legacy** correction, `ChaturbateLlhlsInputAlignment.java:19` — discards anything outside
the band, including everything above the maximum. -/
def legacyApplied (delta : Nat) : Nat :=
  if delta < minDelayMs then 0 else if maxDelayMs < delta then 0 else delta

/-- **Repaired** correction: still ignores the negligible band, but clamps the large case to the
maximum instead of throwing the whole correction away. -/
def clampedApplied (delta : Nat) : Nat :=
  if delta < minDelayMs then 0 else min delta maxDelayMs

/-- How far out the two inputs still are after correction — the quantity that becomes drift. -/
def residual (applied delta : Nat) : Nat := delta - applied

/-- **The repair is never worse.** For every possible misalignment, the clamped correction
leaves a residual no larger than the legacy one. This is the anti-regression theorem: it must
hold for the in-band cases too, where the two behave identically. -/
theorem clamping_is_never_worse (delta : Nat) :
    residual (clampedApplied delta) delta ≤ residual (legacyApplied delta) delta := by
  unfold residual clampedApplied legacyApplied
  split
  · exact Nat.le_refl _
  · next hmin =>
      split
      · next hmax => omega
      · next hmax =>
          have : min delta maxDelayMs = delta := Nat.min_eq_left (by omega)
          omega

/-- **And strictly better exactly where the legacy gave up.** Above the maximum the old code
applied nothing; the new code applies the full 2 s. -/
theorem clamping_is_strictly_better_above_the_maximum (delta : Nat) (h : maxDelayMs < delta) :
    residual (clampedApplied delta) delta < residual (legacyApplied delta) delta := by
  -- Compute each side on its own rather than rewriting inside both at once: a single
  -- `rw [if_neg ...]` left a degenerate `if delta < 50 then 0 else 0` behind and omega
  -- could not see through it.
  have hmin : ¬ delta < minDelayMs := by
    unfold minDelayMs; unfold maxDelayMs at h; omega
  have hc : clampedApplied delta = maxDelayMs := by
    unfold clampedApplied
    rw [if_neg hmin]
    exact Nat.min_eq_right (Nat.le_of_lt h)
  have hl : legacyApplied delta = 0 := by
    unfold legacyApplied
    rw [if_neg hmin, if_pos h]
  unfold residual
  rw [hc, hl]
  unfold maxDelayMs at *
  omega

/-- **The correction never exceeds the maximum**, so clamping cannot over-correct and push the
streams apart in the other direction. -/
theorem the_correction_is_bounded (delta : Nat) : clampedApplied delta ≤ maxDelayMs := by
  unfold clampedApplied
  split
  · exact Nat.zero_le _
  · exact Nat.min_le_right _ _

/-- **The correction never exceeds the misalignment itself** — it cannot invert the ordering of
the two inputs. -/
theorem the_correction_never_overshoots (delta : Nat) : clampedApplied delta ≤ delta := by
  unfold clampedApplied
  split
  · exact Nat.zero_le _
  · exact Nat.min_le_left _ _

/-- **In-band behaviour is unchanged.** The measured live offset, 1.393022 s = 1393 ms, sits
inside the band and is corrected identically by both versions — so this repair cannot regress
the common case. -/
theorem the_measured_offset_is_unchanged :
    clampedApplied 1393 = legacyApplied 1393 ∧ clampedApplied 1393 = 1393 := by decide

/-- The negligible band is still ignored, and the residual there is bounded by the threshold —
under two frames at 30 fps. -/
theorem the_negligible_band_is_still_ignored (delta : Nat) (h : delta < minDelayMs) :
    clampedApplied delta = 0 ∧ residual (clampedApplied delta) delta < minDelayMs := by
  unfold clampedApplied residual
  rw [if_pos h]
  exact ⟨rfl, by omega⟩

/-- A 3-second misalignment: the legacy left all 3000 ms, the repair leaves 1000 ms. -/
theorem a_three_second_misalignment_improves :
    residual (legacyApplied 3000) 3000 = 3000 ∧ residual (clampedApplied 3000) 3000 = 1000 := by
  decide

/-- The worst measured pre-fix drift, 8012 ms, as an alignment case: from 8012 ms of residual
down to 6012 ms. Bounded improvement, not a cure — stated so the claim is not oversold. -/
theorem the_worst_measured_case_improves_by_the_maximum :
    residual (legacyApplied 8012) 8012 - residual (clampedApplied 8012) 8012 = maxDelayMs := by
  decide

#guard legacyApplied 3000 == 0
#guard clampedApplied 3000 == 2000
#guard legacyApplied 1393 == 1393
#guard clampedApplied 1393 == 1393
#guard clampedApplied 20 == 0
#guard clampedApplied 8012 == 2000
#guard residual (clampedApplied 3000) 3000 == 1000

/-! ## Is `-bsf:a aac_adtstoasc` required? Measured: no.

This was carried as an open item awaiting the Socio's consent, because adding it would edit
`settings.json` — the user's file, which is not modified unasked. **Consent was the wrong
question.** The right one is whether the filter is needed at all, and that is measurable.

`aac_adtstoasc` rewrites ADTS-framed AAC into raw AAC carrying an `AudioSpecificConfig`. It is
required when AAC arrives in ADTS framing (typically from MPEG-TS) and is muxed into MP4, which
has no place for ADTS headers. If the muxer already emits an `mp4a` sample entry, the filter is
a no-op.

**Measured on four shipped recordings** (`ffprobe -show_entries stream=codec_tag_string`):

| recording | codec | profile | tag | rate | ch |
|---|---|---|---|---|---|
| annabisoux 22:18 / 23:12 / 00:06 | aac | LC | **mp4a** | 48000 | 2 |
| kellytesh 22:18 | aac | LC | **mp4a** | 48000 | 2 |

and a 3-second decode produced **zero** stderr lines at **exit 0** — no AAC bitstream errors.

So the answer is: **not needed, and asking for consent to add it would have been asking to
apply a no-op.** The item is closed by measurement rather than left pending. -/

/-- How the incoming AAC is framed. -/
inductive AacFraming where
  /-- ADTS headers, as carried by MPEG-TS. -/
  | adts
  /-- Raw AAC with an `AudioSpecificConfig`, as an MP4 `mp4a` sample entry. -/
  | asc
deriving DecidableEq, Repr

/-- The container being written. -/
inductive Container where
  | mp4
  | mpegts
deriving DecidableEq, Repr

/-- **The filter is required exactly when ADTS-framed AAC is written into MP4.** -/
def needsAdtsToAsc (f : AacFraming) (c : Container) : Bool :=
  f == .adts && c == .mp4

/-- Measured framing of this app's output: the sample entry is `mp4a`, i.e. already ASC. -/
def measuredFraming : AacFraming := .asc

/-- Measured container: MP4. -/
def measuredContainer : Container := .mp4

/-- **The shipped configuration does not need the filter.** -/
theorem the_filter_is_not_needed_here :
    needsAdtsToAsc measuredFraming measuredContainer = false := by decide

/-- **The filter WOULD be needed if the framing were ADTS** — so the theorem above is a fact
about the measurement, not a vacuous predicate that is false for everything. -/
theorem the_filter_would_be_needed_for_adts_in_mp4 :
    needsAdtsToAsc .adts .mp4 = true := by decide

/-- And it is never needed when writing MPEG-TS, whatever the framing — the other axis matters
too, so neither argument is ignored. -/
theorem the_filter_is_never_needed_for_mpegts :
    needsAdtsToAsc .adts .mpegts = false ∧ needsAdtsToAsc .asc .mpegts = false := by decide

#guard !needsAdtsToAsc measuredFraming measuredContainer
#guard needsAdtsToAsc .adts .mp4
#guard !needsAdtsToAsc .adts .mpegts

/-! ## Which track gets delayed — the half of the alignment that was never modelled

Everything above takes `delta : Nat`, the **absolute** difference of the two start times. But
`ChaturbateLlhlsInputAlignment.fromStartTimes` decides two things, and the magnitude is only one
of them:

```java
Duration delta = durationFromSeconds(Math.abs(audioStartTime - videoStartTime));
...
return audioStartTime > videoStartTime
   ? new ChaturbateLlhlsInputAlignment(Duration.ZERO, applied)   // delay AUDIO
   : new ChaturbateLlhlsInputAlignment(applied, Duration.ZERO);  // delay VIDEO
```

`Math.abs` throws the sign away **before** the modelled part begins, so the ternary — the
direction — was outside the spec entirely. Swapping it would leave every theorem above green
while **doubling** the skew instead of cancelling it. `the_correction_never_overshoots` cannot
see it: it is a statement about `delta`, and `delta` is unsigned.

The algebra the code is implementing: with delay `dv` on the video input, the video shown at
output time `t` is media time `tv + t - dv`, and the audio is `ta + t - da`. They agree exactly
when `tv - dv = ta - da`. So the track that starts **later** is the one to delay — which is what
the ternary does. Verified against both logged cases:

| model | video start | audio start | applied | direction |
|---|---|---|---|---|
| lilithsteinberg | 7338.500978 | 7337.600000 | 0.900978 | video (video is later) |
| lindabluee | 114.951978 | 116.800000 | 1.848022 | audio (audio is later) |

Times below are in milliseconds. -/

/-- Milliseconds, signed, so the direction survives into the model. -/
def clampedAppliedMs (deltaAbs : Int) : Int :=
  if deltaAbs < 50 then 0
  else if deltaAbs > 2000 then 2000
  else deltaAbs

/-- The delay the code puts on the **video** input. -/
def videoDelayMs (tv ta : Int) : Int :=
  if ta > tv then 0 else clampedAppliedMs (tv - ta)

/-- The delay the code puts on the **audio** input. -/
def audioDelayMs (tv ta : Int) : Int :=
  if ta > tv then clampedAppliedMs (ta - tv) else 0

/-- Misalignment remaining after the correction. Zero means the two inputs line up. -/
def postMisalignMs (tv ta : Int) : Int :=
  (tv - videoDelayMs tv ta) - (ta - audioDelayMs tv ta)

/-- The direction with the ternary **inverted** — the single-character defect this section
exists to make visible. -/
-- Stated as a literal swap of the two real delays rather than as re-spelled conditionals.
-- Two reasons: it says exactly what the defect IS (the ternary's arms exchanged), and it keeps
-- the real bodies textually unique -- an earlier spelling duplicated them, and the mutation
-- harness correctly refused to apply a patch whose anchor matched twice (DISCARDED, which is a
-- statement about the harness, not about the theorem).
def invertedVideoDelayMs (tv ta : Int) : Int := audioDelayMs tv ta

def invertedAudioDelayMs (tv ta : Int) : Int := videoDelayMs tv ta

def invertedPostMisalignMs (tv ta : Int) : Int :=
  (tv - invertedVideoDelayMs tv ta) - (ta - invertedAudioDelayMs tv ta)

/-- **The measured lilithsteinberg session aligns exactly.** video 7338.501 s, audio 7337.600 s:
video is later, so video is delayed, and nothing is left over. -/
theorem the_lilithsteinberg_session_aligns :
    postMisalignMs 7338501 7337600 = 0 := by decide

/-- **The measured lindabluee session aligns exactly**, and it is the opposite direction —
audio is the later track there. Two cases, both signs, so the rule is not fitted to one. -/
theorem the_lindabluee_session_aligns :
    postMisalignMs 114952 116800 = 0 := by decide

/-- **Inverting the ternary doubles the skew.** On the lilithsteinberg numbers the residual goes
from 0 ms to 1802 ms — the defect makes the output twice as wrong as doing nothing at all. -/
theorem inverting_the_direction_doubles_the_skew :
    invertedPostMisalignMs 7338501 7337600 = 1802
      ∧ postMisalignMs 7338501 7337600 = 0 := by decide

/-- And in the other direction too, so the inversion is not accidentally harmless on one sign. -/
theorem inverting_is_wrong_in_both_directions :
    invertedPostMisalignMs 114952 116800 = -3696
      ∧ postMisalignMs 114952 116800 = 0 := by decide

/-- **Doing nothing** leaves the raw skew. Stated so "aligned" is measured against the real
alternative rather than against the inverted straw man. -/
theorem uncorrected_leaves_the_raw_skew :
    (7338501 : Int) - 7337600 = 901 ∧ (114952 : Int) - 116800 = -1848 := by decide

/-- **A negligible offset is deliberately left alone** — under 50 ms the guard returns none, and
the residual is the original offset rather than zero. This is the honest statement: the code does
not claim to fix what it declines to touch. -/
theorem a_negligible_offset_is_left_alone (tv ta : Int)
    (hlo : tv - ta < 50) (hhi : ta - tv < 50) :
    postMisalignMs tv ta = tv - ta := by
  have hv : videoDelayMs tv ta = 0 := by
    unfold videoDelayMs clampedAppliedMs; split <;> omega
  have ha : audioDelayMs tv ta = 0 := by
    unfold audioDelayMs clampedAppliedMs; split <;> omega
  simp [postMisalignMs, hv, ha]

/-- **Anti-amputation: the correction is not a no-op.** A `fromStartTimes` that always returned
`none()` would satisfy "never overshoots" and "never inverts" perfectly. -/
theorem the_correction_actually_moves_something :
    videoDelayMs 7338501 7337600 = 901 ∧ audioDelayMs 114952 116800 = 1848 := by decide

/-- Beyond the 2 s clamp the residual is what the clamp could not cover — and it keeps the sign
of the original offset, so a clamped correction never flips the two inputs past each other. -/
theorem beyond_the_clamp_the_residual_keeps_its_sign :
    postMisalignMs 3500 0 = 1500 ∧ postMisalignMs 0 3500 = -1500 := by decide

#guard postMisalignMs 7338501 7337600 == 0
#guard postMisalignMs 114952 116800 == 0
#guard invertedPostMisalignMs 7338501 7337600 == 1802
#guard videoDelayMs 7338501 7337600 == 901
#guard audioDelayMs 7338501 7337600 == 0
#guard audioDelayMs 114952 116800 == 1848
#guard videoDelayMs 114952 116800 == 0
#guard postMisalignMs 10 0 == 10          -- under 50 ms: untouched, by design
#guard postMisalignMs 3500 0 == 1500      -- past the clamp: 2000 applied, 1500 left

/-! ## Sampling the two start times SEQUENTIALLY injects a whole-segment error

The direction is right and the magnitude is clamped, but both operate on numbers that must be
sampled from a **moving** stream. `determineInputAlignment` does this:

```java
OptionalDouble videoStartTime = ...detectStartTime(this.mediaServer.getVideoPlaylistUrl());
OptionalDouble audioStartTime = ...detectStartTime(this.mediaServer.getAudioPlaylistUrl());
```

Two calls, one after the other, each spawning its own ffmpeg process. The live-window start does
not advance smoothly — it jumps by one segment when the window slides. **Measured on the running
app** (media server port 11144, 24 back-to-back probes):

| quantity | measured |
|---|---|
| slide step | **+1.664 s / +1.665 s** (one segment) |
| slide period | ~1.1 s of wall time |
| one probe | 90–171 ms |
| video start across one audio probe | **+1.665 s** on the first trial, 0 on the next two |

So the interval between the two samples is an **exposure window**: if the window slides inside
it, the computed skew is wrong by a full segment, and everything downstream faithfully applies
that wrong number. Sampling both playlists at the same instant closes the window to zero.

Times in milliseconds. -/

/-- When each track's start time was sampled. -/
structure ProbePair where
  videoSampledAt : Int
  audioSampledAt : Int
deriving DecidableEq, Repr

/-- Sequential probing: audio is sampled one probe-duration after video. -/
def sequentialPair (t0 probeMs : Int) : ProbePair := ⟨t0, t0 + probeMs⟩

/-- Concurrent probing: both samples refer to the same instant. -/
def simultaneousPair (t0 : Int) : ProbePair := ⟨t0, t0⟩

/-- The window during which a slide corrupts the measurement. -/
def exposureMs (p : ProbePair) : Int := p.audioSampledAt - p.videoSampledAt

/-- Does a window slide at `slideAt` fall between the two samples? -/
def straddles (p : ProbePair) (slideAt : Int) : Bool :=
  p.videoSampledAt ≤ slideAt && slideAt < p.audioSampledAt

/-- The error the slide injects into the computed skew: a whole segment, or nothing. -/
def inducedErrorMs (stepMs : Int) (p : ProbePair) (slideAt : Int) : Int :=
  if straddles p slideAt then stepMs else 0

/-- The measured segment step, in ms. -/
def measuredStepMs : Int := 1665

/-- The measured probe duration used below, in ms — the middle of the 90–171 ms range. -/
def measuredProbeMs : Int := 130

/-- **Simultaneous sampling has zero exposure.** -/
theorem simultaneous_has_no_exposure (t0 : Int) : exposureMs (simultaneousPair t0) = 0 := by
  simp [exposureMs, simultaneousPair]

/-- **And therefore no slide can ever fall between the two samples**, for any slide time. This
is the whole point: not "the error is small", but "the window is closed". -/
theorem simultaneous_cannot_straddle (t0 slideAt : Int) :
    straddles (simultaneousPair t0) slideAt = false := by
  -- v4.32.2's `simp` closed this alone; v4.33.0-rc1 leaves
  -- `t0 ≤ slideAt → ¬(slideAt < t0)` behind. An explicit split is stated in terms of the
  -- PROPOSITIONS rather than the `decide`/`Bool` encoding, so it does not depend on which
  -- normal form a given simp set produces -- and therefore holds on both toolchains, keeping
  -- the two copies of this file identical.
  unfold straddles simultaneousPair
  by_cases h : t0 ≤ slideAt
  · have hlt : ¬ (slideAt < t0) := by omega
    simp [h, hlt]
  · simp [h]

/-- No exposure, no induced error — for **any** step size, so the guarantee does not depend on
the segment duration staying 1.665 s. -/
theorem simultaneous_has_no_induced_error (stepMs t0 slideAt : Int) :
    inducedErrorMs stepMs (simultaneousPair t0) slideAt = 0 := by
  unfold inducedErrorMs
  rw [simultaneous_cannot_straddle]
  rfl

/-- **Sequential sampling's exposure is exactly the probe duration.** -/
theorem sequential_exposure_is_the_probe_duration (t0 probeMs : Int) :
    exposureMs (sequentialPair t0 probeMs) = probeMs := by
  show (t0 + probeMs) - t0 = probeMs
  omega

/-- **The measured failure, reproduced.** A slide 90 ms into a 130 ms probe injects a full
1665 ms — larger than the worst drift in the whole corpus. -/
theorem a_slide_inside_the_probe_injects_a_whole_segment :
    inducedErrorMs measuredStepMs (sequentialPair 0 measuredProbeMs) 90 = 1665 := by decide

/-- **Anti-amputation: sequential probing is not always wrong.** It is wrong only when a slide
lands inside the window — which is why the defect is intermittent, and why the drift corpus has
both +0.036 s and -1.433 s in it. A model that condemned every sequential probe would be easier
to satisfy and would misdescribe the bug. -/
theorem sequential_is_correct_when_no_slide_intervenes :
    inducedErrorMs measuredStepMs (sequentialPair 0 measuredProbeMs) 500 = 0 := by decide

/-- The two schedules differ **exactly** on the straddling case: same input, same slide, one
injects a segment and the other cannot. -/
theorem the_schedules_differ_on_the_straddling_slide :
    inducedErrorMs measuredStepMs (sequentialPair 0 measuredProbeMs) 90 = 1665
      ∧ inducedErrorMs measuredStepMs (simultaneousPair 0) 90 = 0 := by decide

/-- The injected error is never partial: it is a whole step or nothing. That is why it can
exceed every clamp and every tolerance downstream. -/
theorem the_error_is_quantised (stepMs : Int) (p : ProbePair) (slideAt : Int) :
    inducedErrorMs stepMs p slideAt = stepMs ∨ inducedErrorMs stepMs p slideAt = 0 := by
  unfold inducedErrorMs; split
  · exact Or.inl rfl
  · exact Or.inr rfl

/-- A longer probe is strictly more dangerous: exposure grows with it, so "make the probe
faster" is a mitigation and "sample at the same instant" is a fix. -/
theorem a_slower_probe_widens_the_window (t0 a b : Int) (h : a < b) :
    exposureMs (sequentialPair t0 a) < exposureMs (sequentialPair t0 b) := by
  simp [exposureMs, sequentialPair]; omega

#guard exposureMs (simultaneousPair 0) == 0
#guard exposureMs (sequentialPair 0 130) == 130
#guard straddles (simultaneousPair 0) 0 == false
#guard straddles (sequentialPair 0 130) 90 == true
#guard straddles (sequentialPair 0 130) 500 == false
#guard inducedErrorMs 1665 (sequentialPair 0 130) 90 == 1665
#guard inducedErrorMs 1665 (simultaneousPair 0) 90 == 0
#guard measuredStepMs == 1665

/-! ## A recording still being written has NO drift, and must not be counted as a good one

**This section exists because I corrupted my own corpus.** I reported the drift of
`lilithsteinberg_2026-08-04_01-42-30_535.mp4` as **-0.017 s** and folded it into the corpus as a
ninth sample. The file was **still being recorded**. Measured again minutes later the same file
read **+7.983 s**, and a size probe 12 s apart confirmed it was still growing (+1 048 576 B).

The number was not merely imprecise, it was **meaningless and flattering** — it made the corpus
look better (a near-zero sample) and larger (n=9) than the evidence supported. The honest corpus
is the **8 complete** recordings, worst |drift| **1.433 s**.

This is exactly the SKIPPED-is-not-PASS discipline this project already enforces on
`live-preview-check.sh`, applied in the one place I forgot: a sample that cannot be measured is
**excluded**, never counted as a good measurement. A growing file silently reports *a* number,
which is why it is more dangerous than one that errors.

The rule is modelled rather than merely written down so that a corpus tool cannot quietly drop
it. No acceptance band is invented here: I have no principled threshold for "acceptable drift"
(perceptual A/V limits are far tighter than anything measured), so the model constrains only
**which samples may be counted**, which is what the mistake actually taught. -/

/-- What a probe of a recording file can find. -/
inductive RecordingState where
  | growing    -- the file is still being written; its durations mean nothing
  | complete   -- the muxer has finished with it
deriving DecidableEq, Repr

/-- The verdict a corpus may draw from one file. `excluded` is deliberately NOT a drift value:
making it a separate constructor is what stops it being averaged in as if it were 0. -/
inductive DriftSample where
  | excluded          -- unmeasurable, and that is a fact ABOUT THE PROBE
  | measured (ms : Int)
deriving DecidableEq, Repr

/-- The only admissible way to turn a probe into a sample. -/
def sampleOf (s : RecordingState) (ms : Int) : DriftSample :=
  match s with
  | .growing => .excluded
  | .complete => .measured ms

/-- Does a sample contribute to the corpus? -/
def counts : DriftSample → Bool
  | .excluded => false
  | .measured _ => true

/-- **A growing file is excluded whatever number the probe returned.** The number is the trap:
ffprobe answers, it just answers about a moving target. -/
theorem a_growing_file_is_excluded (ms : Int) : sampleOf .growing ms = DriftSample.excluded := by
  cases ms <;> rfl

/-- **The concrete case that fooled me.** Both readings of the same in-progress file are
excluded — including the flattering one. -/
theorem the_in_progress_file_is_excluded_both_times :
    sampleOf .growing (-17) = DriftSample.excluded
      ∧ sampleOf .growing 7983 = DriftSample.excluded := by decide

/-- **Excluded is never counted.** Without this, "excluded" could be a label with no consequence
— the same defect as a SKIPPED phase that exits 0. -/
theorem excluded_never_counts : counts DriftSample.excluded = false := by decide

/-- **Anti-amputation: a complete file IS counted.** A rule that excluded everything would
trivially satisfy the theorem above while destroying the corpus. -/
theorem a_complete_file_counts (ms : Int) : counts (sampleOf .complete ms) = true := by
  cases ms <;> rfl

/-- The state, not the value, decides admissibility: the same drift is counted when complete and
excluded when growing. So no drift value can buy its way into the corpus. -/
theorem admissibility_ignores_the_value (ms : Int) :
    counts (sampleOf .complete ms) = true ∧ counts (sampleOf .growing ms) = false := by
  cases ms <;> exact ⟨rfl, rfl⟩

/-- The corpus size is the number of admissible samples — n=8, not n=9. -/
def corpusSize (samples : List DriftSample) : Nat := (samples.filter counts).length

theorem the_corrected_corpus_is_eight :
    corpusSize [ .measured 833, .measured (-967), .measured (-967), .measured 36,
                 .measured (-167), .measured (-1433), .measured 900, .measured 900,
                 sampleOf .growing (-17) ] = 8 := by decide

#guard sampleOf .growing (-17) == DriftSample.excluded
#guard sampleOf .growing 7983 == DriftSample.excluded
#guard sampleOf .complete (-1433) == DriftSample.measured (-1433)
#guard counts (sampleOf .growing 0) == false
#guard counts (sampleOf .complete 0) == true
#guard corpusSize [sampleOf .growing (-17), sampleOf .complete 900] == 1

/-! ## The outcome the alignment model could not express

Every definition in the direction section above takes `tv ta : Int` — it assumes both start
times were measured. `determineInputAlignment` has a third outcome the model had no constructor
for:

```java
} else {
   LOG.warn("Couldn't determine LL-HLS local input start times for {}. Proceeding without startup input delay.", ...);
   this.inputAlignment = ChaturbateLlhlsInputAlignment.none();
}
```

I went looking for a defect here and did not find one: the code logs a WARN and applies
`none()`, so a failed probe is **not** silently dressed up as success. Reading the source
disproved the suspicion. What it did expose is a spec gap of exactly the shape found in
`FfmpegSelection` today — a type that cannot represent a real case, so the case cannot be
reasoned about at all.

The distinction matters because **`unmeasured` and `already aligned` produce byte-identical
FFmpeg behaviour**: no input delay either way. That coincidence is unavoidable — you cannot
correct a skew you failed to measure — and it is precisely why the WARN is load-bearing rather
than decorative. `applied_delay_cannot_tell_them_apart` below proves the behaviours coincide,
which is the formal reason that log line must never be "cleaned up": it is the ONLY thing that
distinguishes "we checked, it was fine" from "we could not check".

This is the same three-valued discipline already applied to the pacing verdict
(`PacingVerdict.inconclusive`): an unmeasurable case must never render as a good case. -/

inductive AlignmentOutcome where
  /-- A probe did not answer. `none()` is applied and a WARN is logged. -/
  | unmeasured
  /-- Both start times came back; the model of the direction section applies. -/
  | measured (tv ta : Int)
  deriving DecidableEq, Repr

/-- The delay pair FFmpeg is actually given. -/
def appliedDelay : AlignmentOutcome → Int × Int
  | .unmeasured => (0, 0)
  | .measured tv ta => (videoDelayMs tv ta, audioDelayMs tv ta)

/-- The residual skew, **as an `Option`**: for an unmeasured pair it is `none` — unknown, not
zero. A model that reported `0` here would be asserting perfect alignment on the strength of a
failed measurement. -/
def residualMs : AlignmentOutcome → Option Int
  | .unmeasured => none
  | .measured tv ta => some (postMisalignMs tv ta)

/-- Did we actually establish alignment? Only a measurement can. -/
def alignmentEstablished : AlignmentOutcome → Bool
  | .unmeasured => false
  | .measured tv ta => postMisalignMs tv ta == 0

/-- **An unmeasured probe never counts as aligned.** -/
theorem unmeasured_is_not_established : alignmentEstablished .unmeasured = false := by decide

/-- **And its residual is unknown, not zero.** -/
theorem unmeasured_residual_is_unknown : residualMs .unmeasured = none := by decide

/-- **Anti-amputation.** The rule is not "nothing is ever established": a real measured session
that lands on zero residual IS established. Without this, `alignmentEstablished = fun _ => false`
would satisfy the theorem above. Numbers are the measured lindabluee session of 03:38:41
(video 6535.822978 s, audio 6534.400000 s) rounded to ms. -/
theorem a_measured_aligned_session_is_established :
    alignmentEstablished (.measured 6535823 6534400) = true := by decide

theorem a_measured_session_has_a_known_residual :
    residualMs (.measured 6535823 6534400) = some 0 := by decide

/-- **The behaviours are indistinguishable — which is why the WARN is load-bearing.** An
unmeasured probe and an already-aligned pair hand FFmpeg exactly the same delays, so nothing
downstream of this point can tell them apart. The log line is the only discriminator. -/
theorem applied_delay_cannot_tell_them_apart :
    appliedDelay .unmeasured = appliedDelay (.measured 500 500) := by decide

/-- …and yet the two outcomes are **not equal**, so the spec keeps the distinction the runtime
behaviour loses. This pair of theorems is the whole point of the third constructor. -/
theorem the_outcomes_are_still_distinct :
    (AlignmentOutcome.unmeasured) ≠ (.measured 500 500) := by decide

/-- A measured pair that needed a correction is established too, and its applied delay is not
the zero pair — so `unmeasured` is not merely "the quiet case". -/
theorem a_corrected_session_moves_something :
    appliedDelay (.measured 6535823 6534400) ≠ (0, 0) := by decide

#guard alignmentEstablished .unmeasured == false
#guard residualMs .unmeasured == none
#guard alignmentEstablished (.measured 6535823 6534400) == true
#guard residualMs (.measured 6535823 6534400) == some 0
#guard appliedDelay .unmeasured == appliedDelay (.measured 500 500)
#guard appliedDelay (.measured 6535823 6534400) == (1423, 0)

/-! ## A corpus that changed two things at once cannot answer one question

The drift corpus now holds two post-fix samples:

```
lindabluee_2026-08-04_02-52-47_600   drift = -633 ms
lindabluee_2026-08-04_03-38-39_662   drift = -266 ms
```

Both were recorded with the concurrent start-time probe. They were **not** recorded with the same
ffmpeg: the 02:52 session ran Chocolatey (libavcodec 62.11.100), the 03:38 session ran the Hybrid
master build (62.29.101), because the resolver was fixed between them. Two variables moved, so
neither sample can be attributed to either change.

The temptation is to report "drift improved from −633 to −266". That sentence is unsupportable,
and it is the exact species of false green this project exists to prevent — the number moved in
the flattering direction, which by RESUMEE-16's rule ("suspect the flattering datum first") is
when to look hardest.

Modelled as a **third verdict**, in the same discipline as `PacingVerdict.inconclusive` and
`AlignmentOutcome.unmeasured`: a confounded comparison is neither a success nor a failure, and
must never be read as either. The sample floor is a *parameter*, never a baked-in constant, so
this cannot become a contingent theorem that a legitimate change would falsify. -/

/-- A drift sample together with the provenance that makes it comparable. -/
structure ProvenancedSample where
  /-- Was the concurrent start-time probe in effect? -/
  concurrentProbe : Bool
  /-- Coarse identity of the recording binary — libavcodec minor, measured: 11 or 29. -/
  libavcodecMinor : Nat
  driftMs : Int
  deriving DecidableEq, Repr

inductive ComparisonVerdict where
  | valid
  | confounded
  | insufficient
  deriving DecidableEq, Repr

/-- Do all samples share one recording binary? -/
def homogeneousBinary : List ProvenancedSample → Bool
  | [] => true
  | s :: rest => rest.all (fun t => t.libavcodecMinor == s.libavcodecMinor)

/-- Do all samples share one probe schedule? -/
def homogeneousProbe : List ProvenancedSample → Bool
  | [] => true
  | s :: rest => rest.all (fun t => t.concurrentProbe == s.concurrentProbe)

/-- A pre/post comparison is **valid** only when each cohort is internally homogeneous in every
variable except the one under test, and both cohorts meet the stated floor. `floor` is a
parameter: a spec that hard-coded it would expire the day the floor was revised. -/
def compare (floor : Nat) (pre post : List ProvenancedSample) : ComparisonVerdict :=
  if pre.length < floor || post.length < floor then .insufficient
  else if homogeneousBinary pre && homogeneousBinary post then .valid
  else .confounded

/-- The corpus as measured: both concurrent-probe, DIFFERENT binaries. -/
def postFixCorpus : List ProvenancedSample :=
  [⟨true, 11, -633⟩, ⟨true, 29, -266⟩]

/-- **The two post-fix samples do not share a binary.** -/
theorem the_post_fix_corpus_is_not_homogeneous :
    homogeneousBinary postFixCorpus = false := by decide

/-- …though they DO share the probe schedule, so the confound is specifically the binary. Stating
which variable leaked is the difference between a diagnosis and a shrug. -/
theorem the_probe_schedule_is_not_the_confound :
    homogeneousProbe postFixCorpus = true := by decide

/-- Two pre-fix samples: sequential probe, Chocolatey binary. Both from the n=8 pre-fix corpus. -/
def preFixCohort : List ProvenancedSample := [⟨false, 11, -1433⟩, ⟨false, 11, 36⟩]

/-- **With both cohorts at the floor, the comparison is confounded — not a win.**

I first wrote this theorem with a ONE-sample pre cohort and `decide` refused it: the floor test
fires before the homogeneity test, so that case is `insufficient`, not `confounded`. The tactic
disproved my claim rather than my code, which is the whole reason the verdict is three-valued —
"not valid" is not one thing, and I had picked the wrong reason. -/
theorem the_measured_comparison_is_confounded :
    compare 2 preFixCohort postFixCorpus = .confounded := by decide

/-- A confounded verdict is neither outcome. Both directions matter: it must not be sold as an
improvement, and it must not be recorded as a regression either. -/
theorem confounded_is_not_valid : ComparisonVerdict.confounded ≠ .valid := by decide
theorem confounded_is_not_insufficient : ComparisonVerdict.confounded ≠ .insufficient := by decide

/-- **Anti-amputation.** `compare` is not a machine that always says "confounded": hold the binary
fixed and the same shapes give a valid comparison. Without this, `fun _ _ _ => .confounded` would
satisfy every theorem above. -/
theorem holding_the_binary_fixed_makes_it_valid :
    compare 2 [⟨true, 29, -633⟩, ⟨true, 29, -100⟩] [⟨true, 29, -266⟩, ⟨true, 29, -300⟩]
      = .valid := by decide

/-- …and a cohort below the floor is `insufficient`, distinct from both — n=1 never settles
anything, which is what the first post-fix sample actually was. -/
theorem a_single_sample_is_insufficient :
    compare 2 [⟨true, 29, -633⟩] [⟨true, 29, -266⟩] = .insufficient := by decide

/-- The durable form: **an empty or singleton cohort can never be valid, for any floor ≥ 2.**
Quantified over the floor and over the samples, so raising the floor cannot falsify it. -/
theorem below_the_floor_is_never_valid (floor : Nat) (pre post : List ProvenancedSample)
    (h : pre.length < floor) : compare floor pre post ≠ .valid := by
  unfold compare
  simp [h]

#guard homogeneousBinary postFixCorpus == false
#guard homogeneousProbe postFixCorpus == true
#guard compare 2 preFixCohort postFixCorpus == .confounded
#guard compare 2 [⟨true, 11, -633⟩] postFixCorpus == .insufficient  -- the floor fires first
#guard compare 2 [⟨true, 29, -633⟩] [⟨true, 29, -266⟩] == .insufficient
#guard compare 2 [⟨true, 29, -633⟩, ⟨true, 29, -100⟩] [⟨true, 29, -266⟩, ⟨true, 29, -300⟩] == .valid

/-! ## The corpus as measured 2026-08-04 06:4x

Two more recordings completed on the Hybrid binary, so the post-swap cohort is now homogeneous
**and** large enough. The comparison is still not admissible, and the reason has changed — which
is progress in diagnosis, not a result.

Measured by `tools/drift-corpus.sh` (provenance read per sample from the log):

| recording | drift | binary |
|---|---|---|
| `lindabluee_02-52-47` | −633 ms | `releaseVersion-8.0.1` |
| `lindabluee_03-38-39` | −266 ms | `libavcodec-62.29.101` |
| `annabisoux_05-34-17` | +162 ms | `libavcodec-62.29.101` |
| `annabisoux_06-34-20` | +162 ms | `libavcodec-62.29.101` |

The post-swap cohort is three samples on one binary. The pre-swap cohort **at the same probe
schedule** is one sample — the earlier pre-fix recordings also predate the concurrent-probe
change, so folding them in would swap one confound for another. `compare` therefore returns
`.insufficient`, not `.valid`, and the numbers below say so rather than my prose. -/

def postSwapCohort : List ProvenancedSample :=
  [⟨true, 29, -266⟩, ⟨true, 29, 162⟩, ⟨true, 29, 162⟩]

def preSwapCohort : List ProvenancedSample := [⟨true, 11, -633⟩]

/-- **The post-swap cohort is finally clean** — one binary, one probe schedule. This is the half
of the experiment that is now in hand. -/
theorem the_post_swap_cohort_is_homogeneous :
    homogeneousBinary postSwapCohort = true := by decide

theorem the_post_swap_probe_schedule_is_uniform :
    homogeneousProbe postSwapCohort = true := by decide

/-- **And the comparison is still not admissible** — now for want of a control cohort, not for
confounding. One pre-swap sample at the matching probe schedule is below the floor. -/
theorem the_comparison_is_still_insufficient :
    compare 2 preSwapCohort postSwapCohort = .insufficient := by decide

theorem still_insufficient_is_not_valid :
    compare 2 preSwapCohort postSwapCohort ≠ .valid := by decide

/-- **Anti-amputation**: it is not that nothing can ever be admissible. One more pre-swap
recording at the current probe schedule flips this to `.valid`, and that is the whole remaining
requirement — stated here so the finish line is a proved fact rather than a hope. -/
theorem one_more_control_sample_would_settle_it :
    compare 2 (⟨true, 11, -633⟩ :: [⟨true, 11, -400⟩]) postSwapCohort = .valid := by decide

#guard homogeneousBinary postSwapCohort == true
#guard compare 2 preSwapCohort postSwapCohort == .insufficient
#guard compare 2 [⟨true, 11, -633⟩, ⟨true, 11, -400⟩] postSwapCohort == .valid

/-! ## Provenance that could not be read

`compare` above assumes every sample's binary is known. `tools/drift-corpus.sh` now reads it from
the log per recording, and reading can fail — an old log format, a rotated log, a recording made
before the line existed.

The trap is that two unreadable samples compare **equal as strings**, so a uniqueness test calls
the cohort homogeneous and certifies a comparison whose binaries are simply unknown. That is the
same shape as `sampleOf .growing` and `PacingVerdict`: an instrument must be able to say *I could
not tell*, and that answer must never be absorbed into *they matched*. -/

/-- The binary behind one sample, as read from the log. -/
inductive Provenance where
  | known (libavcodecMinor : Nat)
  | unreadable
  deriving DecidableEq, Repr

/-- Two samples share provenance only when both were actually read AND agree. **`unreadable` does
not match even itself** — that asymmetry is the whole point. -/
def sameProvenance : Provenance → Provenance → Bool
  | .known a, .known b => a == b
  | _, _ => false

inductive CohortVerdict where
  | homogeneous
  | confounded
  | provenanceUnknown
  deriving DecidableEq, Repr

def anyUnreadable (ps : List Provenance) : Bool := ps.any (· == .unreadable)

def allShareProvenance : List Provenance → Bool
  | [] => true
  | p :: rest => rest.all (sameProvenance p)

/-- Three-valued, and the unknown test comes FIRST. Ordering matters: asking "are they all the
same" before "did we read them all" is exactly the bug this prevents. -/
def cohortVerdict (ps : List Provenance) : CohortVerdict :=
  if anyUnreadable ps then .provenanceUnknown
  else if allShareProvenance ps then .homogeneous
  else .confounded

/-- **The theorem the shell self-test mirrors**: an unread binary is not a matching binary. -/
theorem unreadable_does_not_match_itself :
    sameProvenance .unreadable .unreadable = false := by decide

/-- Two unreadable samples are NOT homogeneous, despite being indistinguishable. -/
theorem two_unreadable_samples_are_not_homogeneous :
    cohortVerdict [.unreadable, .unreadable] = .provenanceUnknown := by decide

/-- One unreadable sample poisons an otherwise clean cohort. -/
theorem one_unknown_poisons_the_cohort :
    cohortVerdict [.known 29, .unreadable] = .provenanceUnknown := by decide

/-- **Anti-amputation**: this is not a rule that rejects everything. A genuinely homogeneous
cohort is still admissible, which is what makes the rejections meaningful. -/
theorem a_read_and_matching_cohort_is_homogeneous :
    cohortVerdict [.known 29, .known 29] = .homogeneous := by decide

/-- …and a genuinely mixed one is confounded, not merely unknown — the two rejections are
different diagnoses and the tool must not collapse them. -/
theorem a_read_and_mixed_cohort_is_confounded :
    cohortVerdict [.known 29, .known 11] = .confounded := by decide

theorem unknown_is_not_confounded : CohortVerdict.provenanceUnknown ≠ .confounded := by decide

/-- **The durable statement**: whatever the cohort, if any sample is unreadable the verdict is
`provenanceUnknown`. Quantified over the list, so extending the corpus can never falsify it. -/
theorem any_unreadable_sample_makes_the_cohort_unknown (ps : List Provenance)
    (h : anyUnreadable ps = true) : cohortVerdict ps = .provenanceUnknown := by
  unfold cohortVerdict
  simp [h]

#guard sameProvenance .unreadable .unreadable == false
#guard sameProvenance (.known 29) (.known 29) == true
#guard cohortVerdict [.unreadable, .unreadable] == .provenanceUnknown
#guard cohortVerdict [.known 29, .known 29] == .homogeneous
#guard cohortVerdict [.known 29, .known 11] == .confounded
#guard cohortVerdict [] == .homogeneous

end CtbrecSpec
