/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: `ctbrec.preview.PcmAudioSink` — the half of preview audio that was missing.

MEASURED 2026-08-13, from the Socio's report "the volume button is there, but it doesn't work (in
the preview) same thing for the picture-in-picture".

`PreviewPipeline.buildAudioArgs` ends in `-f s16le -ar 48000 -ac 2 pipe:1`, so the audio leg writes
raw PCM to its stdout. Both `InlinePreview.applyVolume` and `PipPreviewWindow.applyVolume` started
that process and then NEVER read the pipe and NEVER opened an audio device. Two consequences, and
this file proves the second one is not hand-waving:

  1. nothing could ever be audible — there was no sink outside `StreamPreview`'s MediaPlayer;
  2. the producer STALLS: with no consumer it can emit at most one pipe buffer. At 192000 B/s a
     65536-byte buffer is 341 ms of audio, then ffmpeg blocks on write forever.

So the control was never broken. The sink did not exist. `an_undrained_pipe_bounds_the_audio`
is that fact, quantified.

THE SECOND DEFECT THIS FILE PREVENTS. `SourceDataLine.write` throws `IllegalArgumentException`
unless the length is a whole number of sample frames, while a pipe read returns whatever is
available — routinely not a multiple of 4. The obvious drain loop therefore dies on the first odd
read. The carry buffer is the repair, and `nothing_is_lost_or_duplicated` is why it is correct
rather than merely tested: every byte read is either written or still in the carry.

NOT PROVED, AND NOT TO BE IMPLIED: that anything is AUDIBLE. A mixer line accepting frames is what
the code can measure (`getFramesWritten`); the Socio's ear is the only judge of the rest. Muted OS
mixer, wrong default device, dead speakers — all outside Lean's reach, and named here so no reader
mistakes this file for a guarantee of sound.
-/

namespace CtbrecSpec.PreviewAudioSink

/-! ## Format constants — these MUST agree with `buildAudioArgs`, and a `#guard` below pins that -/

/-- `-ac 2` × `-f s16le` ⇒ 4 bytes per sample frame. -/
def FRAME_BYTES : Nat := 4

/-- `-ar 48000`. -/
def SAMPLE_RATE : Nat := 48000

/-- Throughput of the negotiated format. -/
def BYTES_PER_SECOND : Nat := SAMPLE_RATE * FRAME_BYTES

/-- A typical OS pipe buffer on Windows. Contingent — it appears in no theorem, only in a `#guard`. -/
def TYPICAL_PIPE_BYTES : Nat := 65536

/-! ## Part 1 — frame alignment

`alignedLength n` is the largest prefix of `n` bytes that `SourceDataLine.write` will accept.
-/

def alignedLength (n : Nat) : Nat := n - (n % FRAME_BYTES)

/-- Every write handed to the line is a whole number of frames — the crash this prevents. -/
theorem every_write_is_frame_aligned (n : Nat) : alignedLength n % FRAME_BYTES = 0 := by
  unfold alignedLength FRAME_BYTES
  omega

/-- Alignment never invents bytes. -/
theorem alignment_never_exceeds_the_input (n : Nat) : alignedLength n ≤ n := by
  unfold alignedLength
  omega

/-- What is held back is always less than one frame, so the carry buffer needs only 3 bytes. -/
theorem carry_is_always_smaller_than_one_frame (n : Nat) :
    n - alignedLength n < FRAME_BYTES := by
  unfold alignedLength FRAME_BYTES
  omega

/-- An already-aligned read passes through whole: the common case costs nothing. -/
theorem an_aligned_read_is_written_entirely (n : Nat) (h : n % FRAME_BYTES = 0) :
    alignedLength n = n := by
  unfold alignedLength
  omega

/-! ## Part 2 — the drain loop, as a fold

`carry` is the partial frame kept for the next read; `written` counts bytes handed to the line.
-/

structure Pump where
  carry : Nat
  written : Nat
  deriving DecidableEq, Repr

/-- One iteration: prepend the carry, write the aligned prefix, keep the remainder. -/
def step (p : Pump) (n : Nat) : Pump :=
  let total := p.carry + n
  let w := alignedLength total
  { carry := total - w, written := p.written + w }

def run (chunks : List Nat) : Pump := chunks.foldl step ⟨0, 0⟩

theorem step_conserves (p : Pump) (n : Nat) :
    (step p n).written + (step p n).carry = p.written + p.carry + n := by
  unfold step alignedLength FRAME_BYTES
  simp only
  omega

theorem step_keeps_carry_small (p : Pump) (n : Nat) : (step p n).carry < FRAME_BYTES := by
  unfold step alignedLength FRAME_BYTES
  simp only
  omega

theorem step_keeps_written_aligned (p : Pump) (n : Nat) (h : p.written % FRAME_BYTES = 0) :
    (step p n).written % FRAME_BYTES = 0 := by
  unfold step alignedLength FRAME_BYTES at *
  simp only
  omega

theorem fold_conserves (chunks : List Nat) (p : Pump) :
    (chunks.foldl step p).written + (chunks.foldl step p).carry
      = p.written + p.carry + chunks.sum := by
  induction chunks generalizing p with
  | nil => simp
  | cons c cs ih =>
      simp only [List.foldl_cons, List.sum_cons]
      rw [ih (step p c), step_conserves p c]
      omega

/--
NOTHING IS LOST AND NOTHING IS DUPLICATED: every byte read from the pipe is either already written
to the line or still sitting in the carry. This is the property that makes the carry buffer a
correct fix rather than a plausible one.
-/
theorem nothing_is_lost_or_duplicated (chunks : List Nat) :
    (run chunks).written + (run chunks).carry = chunks.sum := by
  unfold run
  rw [fold_conserves chunks ⟨0, 0⟩]
  simp

theorem the_carry_never_grows_past_a_frame (chunks : List Nat) :
    (run chunks).carry < FRAME_BYTES := by
  unfold run
  cases chunks with
  | nil => simp [FRAME_BYTES]
  | cons c cs =>
      -- after at least one step the invariant holds, and folding preserves it
      have h : ∀ (l : List Nat) (p : Pump), p.carry < FRAME_BYTES →
          (l.foldl step p).carry < FRAME_BYTES := by
        intro l
        induction l with
        | nil => intro p hp; simpa using hp
        | cons a as ih => intro p _; exact ih (step p a) (step_keeps_carry_small p a)
      simp only [List.foldl_cons]
      exact h cs (step ⟨0, 0⟩ c) (step_keeps_carry_small ⟨0, 0⟩ c)

theorem every_byte_written_is_frame_aligned (chunks : List Nat) :
    (run chunks).written % FRAME_BYTES = 0 := by
  unfold run
  have h : ∀ (l : List Nat) (p : Pump), p.written % FRAME_BYTES = 0 →
      (l.foldl step p).written % FRAME_BYTES = 0 := by
    intro l
    induction l with
    | nil => intro p hp; simpa using hp
    | cons a as ih => intro p hp; exact ih (step p a) (step_keeps_written_aligned p a hp)
  exact h chunks ⟨0, 0⟩ (by simp [FRAME_BYTES])

/-! ## Part 3 — why the OLD code was silent, quantified

A pipe lets the producer run at most `capacity` bytes ahead of the consumer.
-/

/-- Total bytes a producer can emit given a capacity and what the consumer has taken. -/
def producible (capacity consumed : Nat) : Nat := capacity + consumed

/--
THE OLD DEFECT. With no consumer the audio leg can emit exactly one buffer and then blocks — so
"there is no sink" is not merely "no sound", it is "at most `capacity` bytes ever leave ffmpeg".
-/
theorem an_undrained_pipe_bounds_the_audio (capacity : Nat) :
    producible capacity 0 = capacity := by
  simp [producible]

/-- With a consumer that keeps reading, no bound remains: draining is what makes audio unbounded. -/
theorem a_drained_pipe_has_no_bound (capacity target : Nat) :
    ∃ consumed, target ≤ producible capacity consumed := by
  exact ⟨target, by simp [producible]⟩

/-- Milliseconds of audio a capacity holds, in whole ms. Used only by the `#guard`s below. -/
def millisFor (bytes : Nat) : Nat := bytes * 1000 / BYTES_PER_SECOND

/-! ### Mutation targets -/

/-- The naive loop: write everything, aligned or not. This is the `IllegalArgumentException`. -/
def unalignedLength (n : Nat) : Nat := n

theorem the_naive_loop_writes_partial_frames :
    ∃ n, unalignedLength n % FRAME_BYTES ≠ 0 := by
  exact ⟨1, by simp [unalignedLength, FRAME_BYTES]⟩

/-- Dropping the remainder instead of carrying it: aligned, and it LOSES bytes — a click per read. -/
def dropRemainder (p : Pump) (n : Nat) : Pump :=
  { carry := 0, written := p.written + alignedLength (p.carry + n) }

theorem dropping_the_remainder_loses_bytes :
    ∃ (p : Pump) (n : Nat),
      (dropRemainder p n).written + (dropRemainder p n).carry < p.written + p.carry + n := by
  refine ⟨⟨0, 0⟩, 1, ?_⟩
  simp [dropRemainder, alignedLength, FRAME_BYTES]

/-! ## Today's measured numbers — `#guard` only, nothing depends on them -/

#guard FRAME_BYTES == 4
#guard BYTES_PER_SECOND == 192000
#guard millisFor TYPICAL_PIPE_BYTES == 341          -- the old code's entire audio budget
#guard alignedLength 0 == 0
#guard alignedLength 1 == 0
#guard alignedLength 3 == 0
#guard alignedLength 4 == 4
#guard alignedLength 7 == 4
#guard alignedLength 8193 == 8192
-- the ragged-chunk stream the Java probe feeds: 1,2,3,4,5,6,7 bytes
#guard (run [1, 2, 3, 4, 5, 6, 7]).written == 28
#guard (run [1, 2, 3, 4, 5, 6, 7]).carry == 0
#guard (run [1, 1, 1]).written == 0                 -- three bytes cannot make a frame
#guard (run [1, 1, 1]).carry == 3
#guard (run [1, 1, 1, 1]).written == 4
#guard producible 65536 0 == 65536

end CtbrecSpec.PreviewAudioSink
