/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: P2 -- buffer reuse must not tear a frame, and a pool's cost is independent of the
frame count.

THE ITEM SAYS "Reuse the buffer". **That instruction, taken literally, is a defect** -- and this file
exists to say so with a theorem instead of an opinion. Measured in the code:

  src/app/ctbrec/ui/controls/InlinePreview.java:353   byte[] buf = new byte[frameSize]   -- ONCE
  src/app/ctbrec/ui/controls/InlinePreview.java:377   byte[] copy = new byte[frameSize]  -- PER FRAME
  src/app/ctbrec/ui/controls/PipPreviewWindow.java:560 / :588 -- the same pair

The read buffer is ALREADY reused. The per-frame allocation is the *copy* in `publish`, and the copy is
not waste: the reader thread refills `buf` while the FX thread is still blitting it, so handing `buf`
itself across the threads is exactly the rolling diagonal tear that `readFully` (not `read`) was chosen
to avoid -- see the comment at InlinePreview.java:356. **Single-buffer reuse tears. The fix is a POOL of
at least two with an ownership handoff**, and that is what is proved below:

  a_single_buffer_tears                      -- reuse with one buffer: the writer owns what the reader reads
  two_buffers_never_tear / swapping_never_hands_the_writers_buffer  -- the general law, any pool >= 2
  a_pool_allocates_a_constant                -- cost independent of frame count: the actual P2 win

MEASURED GEOMETRY (all from the source, cited): `DEFAULT_FPS = 60` at PreviewPipeline.java:67; PiP size
`w = max(480, thumbWidth * 2)`, `h = round(w * aspectRatio)` at PipPreviewLauncher.java:57-58; 4-byte
BGRA at PreviewPipeline.java:63.

ARITHMETIC, AND A CORRECTION TO THE ITEM'S NUMBER: 960 x 540 x 4 = 2 073 600 B/frame, x 60 fps =
124 416 000 B/s = **118.65 MiB/s (124.4 MB/s decimal)**. The item says "~105 MB/s"; that figure is not
reproducible from 960x540x4x60 under either unit convention. The `#guard`s below pin the arithmetic that
IS reproducible, and no theorem depends on 105.

NOT PROVED: that the pool is faster in wall-clock terms. Allocation count is proved; throughput is a
measurement, and it belongs to a probe.
-/

namespace Proofs.Ctbrec.FrameBufferReuse

/-- A frame-buffer pool. `writeIdx` is the buffer the producer fills; `handed` is the buffer given to
the consumer and not yet released. -/
structure Pool where
  size : Nat
  writeIdx : Nat
  handed : Option Nat
  deriving Repr, DecidableEq

/-- Publish a frame: hand the filled buffer to the consumer and move the writer on. -/
def publish (p : Pool) : Pool :=
  { p with handed := some p.writeIdx, writeIdx := (p.writeIdx + 1) % p.size }

/-- A TEAR is the writer owning the very buffer the consumer is reading. -/
def tears (p : Pool) : Bool :=
  match p.handed with
  | none => false
  | some h => h == p.writeIdx

def fresh (n : Nat) : Pool := { size := n, writeIdx := 0, handed := none }

/-! ## Law 1 — one buffer is NOT enough, whatever the item says -/

/-- Literal "reuse the buffer": a single buffer hands the consumer what the writer is refilling. -/
theorem a_single_buffer_tears : tears (publish (fresh 1)) = true := by
  decide

/-- Two buffers do not. -/
theorem two_buffers_never_tear : tears (publish (fresh 2)) = false := by
  decide

/-- And the difference is observable, so the choice is not a matter of taste. -/
theorem one_buffer_and_two_differ : tears (publish (fresh 1)) ≠ tears (publish (fresh 2)) := by
  decide

/-- Nothing tears before anything has been handed over: a fresh pool is safe. -/
theorem a_fresh_pool_does_not_tear (n : Nat) : tears (fresh n) = false := by
  simp [tears, fresh]

/-! ## Law 2 — the general law: any pool of at least two, at any position, never tears -/

theorem swapping_never_hands_the_writers_buffer (p : Pool)
    (hs : 2 ≤ p.size) (hw : p.writeIdx < p.size) : tears (publish p) = false := by
  simp only [tears, publish, beq_eq_false_iff_ne, ne_eq]
  intro hEq
  rcases Nat.lt_or_ge (p.writeIdx + 1) p.size with h | h
  · rw [Nat.mod_eq_of_lt h] at hEq
    omega
  · have he : p.writeIdx + 1 = p.size := by omega
    rw [he, Nat.mod_self] at hEq
    omega

/-- The writer's index stays inside the pool, so the law above keeps applying frame after frame. -/
theorem the_write_index_stays_in_range (p : Pool) (hs : 0 < p.size) :
    (publish p).writeIdx < p.size := by
  simp only [publish]
  exact Nat.mod_lt _ hs

/-- `n` consecutive publishes — a whole stream, not one frame. -/
def publishTimes : Nat → Pool → Pool
  | 0, q => q
  | n + 1, q => publishTimes n (publish q)

/-- Therefore a pool of ≥ 2 never tears on ANY frame, not just the first. This is the theorem that
makes the fix safe: the invariant `writeIdx < size` is preserved by publishing, so the single-frame law
applies forever. -/
theorem a_pool_of_two_or_more_never_tears (p : Pool) (hs : 2 ≤ p.size) (hw : p.writeIdx < p.size)
    (n : Nat) : tears (publishTimes (n + 1) p) = false := by
  induction n generalizing p with
  | zero => simpa [publishTimes] using swapping_never_hands_the_writers_buffer p hs hw
  | succ k ih =>
      simp only [publishTimes]
      exact ih (publish p) (by simpa [publish] using hs)
        (the_write_index_stays_in_range p (by omega))

/-! ## Law 3 — the actual P2 win: allocation count stops depending on the frame count -/

/-- Today: one `new byte[frameSize]` per frame (InlinePreview.java:377). -/
def allocationsPerFrame (frames : Nat) : Nat := frames

/-- With a pool: allocated once, whatever the frame count. -/
def allocationsWithPool (poolSize : Nat) (_frames : Nat) : Nat := poolSize

theorem a_pool_allocates_a_constant (poolSize f1 f2 : Nat) :
    allocationsWithPool poolSize f1 = allocationsWithPool poolSize f2 := by
  rfl

theorem the_present_scheme_allocates_without_bound (f1 f2 : Nat) (h : f1 < f2) :
    allocationsPerFrame f1 < allocationsPerFrame f2 := h

/-- The pool wins as soon as the stream is longer than the pool -- i.e. immediately. -/
theorem the_pool_is_cheaper_past_its_own_size (poolSize frames : Nat) (h : poolSize < frames) :
    allocationsWithPool poolSize frames < allocationsPerFrame frames := h

/-- A pool of 2 over a minute at 60 fps: 2 allocations instead of 3600. -/
theorem two_buffers_beat_thirty_six_hundred :
    allocationsWithPool 2 3600 < allocationsPerFrame 3600 := by
  decide

/-! ## The measured arithmetic, as `#guard` -/

-- 4-byte BGRA (PreviewPipeline.java:63), 960x540.
#guard 960 * 540 * 4 == 2073600
-- DEFAULT_FPS = 60 (PreviewPipeline.java:67).
#guard 960 * 540 * 4 * 60 == 124416000
-- 118 MiB/s, not the item's "~105 MB/s". Stated, not quietly matched.
#guard (960 * 540 * 4 * 60) / 1048576 == 118
#guard (960 * 540 * 4 * 60) / 1000000 == 124
-- The PiP floor: w = max(480, thumbWidth*2) at PipPreviewLauncher.java:57.
#guard 480 * 270 * 4 == 518400
-- A pool of two costs two allocations for a minute of video; today's scheme costs 3600.
#guard allocationsWithPool 2 3600 == 2
#guard allocationsPerFrame 3600 == 3600
-- One buffer tears, two do not.
#guard tears (publish (fresh 1)) == true
#guard tears (publish (fresh 2)) == false

end Proofs.Ctbrec.FrameBufferReuse
