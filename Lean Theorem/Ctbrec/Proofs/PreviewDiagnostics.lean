/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CP161 -- A PREVIEW THAT CANNOT REPORT ITS OWN FAILURE.

Measured 2026-08-10. The Socio: picture-in-picture "currently not working". The entire evidence in
a 13 452-line log was ONE line:

  16:35:38,647 INFO c.u.c.PipPreviewLauncher [PipPreviewLauncher.java:51]
               PiP preview requested for CB:angels_kiss (aspectRatio=0.5625)

and then nothing -- no error, no exit code, no stack. Three independent silencers, all measured in
the shipped source:

  1. `pb.redirectError(ProcessBuilder.Redirect.DISCARD)` in BOTH preview paths
     (PipPreviewWindow.java:361, InlinePreview.java:141) threw away ffmpeg's own diagnosis.
  2. Neither path ever called `waitFor`, so the exit code was never observed.
  3. `PipPreviewLauncher` caught `Exception`, so a `NoClassDefFoundError` / `NoSuchMethodError`
     -- the failure a stale artifact produces, and this session MEASURED a stale artifact
     (`ThumbCell.class` 15 h older than its source, `createVolumeButton` refs 0) -- flew straight
     past into a stderr no launch4j build captures.

What is NOT the defect, so the fix is not aimed at the wrong thing: the argument vector works.
Run live against a real stream with the deployed vector at 960x540@60 -- 1016 frames, 2.1 GB in
20 s, stderr carrying only benign LL-HLS partial-segment NAL warnings.

This module states the laws the repair has to satisfy, and it states them over ARBITRARY exit
codes, frame counts and clocks rather than over the one case observed -- a theorem about
`exit = 8` would expire the next time ffmpeg picks a different code.
-/

namespace CtbrecSpec.PreviewDiagnostics

/-! ## 1. Bounded stderr retention

The tail is kept, not the head: ffmpeg prints the reason it is giving up LAST. And it is bounded,
because a stream that warns once per frame at 60 fps would otherwise be a memory leak that shows up
as "the app got slow" hours later. -/

/-- `retain xs n` keeps at most the last `n` entries of `xs`.

This is the Java verbatim, not a paraphrase of it: `ProcessDiagnostics.retain` computes
`lines.subList(max(0, size - max), size)`, i.e. a DROP of the front, and the running
`while (tail.size() > MAX_LINES) tail.removeFirst()` loop reaches the same fixed point. Modelling
it as one `drop` rather than as a recursion is deliberate -- a recursive model made `simp` unfold
forever, and a definition the checker cannot evaluate is not worth having. -/
def retain (xs : List String) (n : Nat) : List String :=
  xs.drop (xs.length - n)

theorem the_tail_is_bounded (xs : List String) (n : Nat) : (retain xs n).length ≤ n := by
  simp only [retain, List.length_drop]
  omega

/-- Nothing is retained when the bound is zero -- the degenerate case a bound must survive. -/
theorem a_zero_bound_keeps_nothing (xs : List String) : retain xs 0 = [] := by
  simp [retain]

/-- Short inputs are kept whole: the bound truncates, it never discards what fits. -/
theorem a_short_tail_is_kept_whole (xs : List String) (n : Nat) (h : xs.length ≤ n) :
    retain xs n = xs := by
  have : xs.length - n = 0 := by omega
  simp [retain, this]

/-- The retained lines really are a suffix -- i.e. the NEWEST, which is the whole point of keeping
a tail rather than a head. ffmpeg prints the reason it is giving up last. -/
theorem the_retained_lines_are_the_newest (xs : List String) (n : Nat) :
    ∃ k, retain xs n = xs.drop k := ⟨xs.length - n, rfl⟩

/-! ## 2. The alarm: when must a preview declare itself broken?

`shouldReport exit frames` is the exact predicate `ProcessDiagnostics.shouldReport` computes. The
second disjunct is the one that matters and the one an obvious implementation omits. -/

def shouldReport (exitCode : Int) (frames : Nat) : Bool :=
  exitCode ≠ 0 || frames = 0

/-- The alarm fires on a non-zero exit, whatever the code and however many frames arrived. -/
theorem a_nonzero_exit_always_reports (e : Int) (frames : Nat) (h : e ≠ 0) :
    shouldReport e frames = true := by
  simp [shouldReport, h]

/-- THE CASE AN EXIT-CODE-ONLY ALARM MISSES, and it is not hypothetical: `PreviewPipeline` records
ffmpeg 8.0.1 producing ZERO bytes and still exiting 0 with `-fflags nobuffer`. A silent black
preview is exactly what the Socio saw. -/
theorem a_clean_exit_with_no_frames_still_reports : shouldReport 0 0 = true := by decide

/-- ...and the exit-code-only alarm is provably weaker: it stays quiet on that very case. -/
def exitCodeOnly (exitCode : Int) (_frames : Nat) : Bool := exitCode ≠ 0

theorem the_exit_code_alone_misses_the_silent_black_preview :
    exitCodeOnly 0 0 = false ∧ shouldReport 0 0 = true := by decide

/-- Quiet on a healthy teardown, so this is an alarm and not noise. -/
theorem a_healthy_stop_is_quiet (frames : Nat) (h : 0 < frames) :
    shouldReport 0 frames = false := by
  simp [shouldReport, Nat.pos_iff_ne_zero.mp h]

/-- NEGATIVE CONTROL -- the shipped path. `Redirect.DISCARD` plus no `waitFor` is a reporter that
cannot fire for ANY exit code and ANY frame count. It is not "less verbose"; it is unfalsifiable. -/
def discardingReporter (_exitCode : Int) (_frames : Nat) : Bool := false

theorem the_shipped_path_reports_nothing (e : Int) (frames : Nat) :
    discardingReporter e frames = false := rfl

/-- And it disagrees with the repair on a case that actually happened. -/
theorem the_repair_is_strictly_stronger :
    ∃ e frames, discardingReporter e frames = false ∧ shouldReport e frames = true :=
  ⟨0, 0, by decide⟩

/-! ## 3. The no-frame watchdog

The reader thread blocks in `readFully` forever when ffmpeg never emits a whole frame, so without a
clock NOTHING observes the failure. The watchdog is stated over an arbitrary elapsed time and an
arbitrary deadline; `NO_FRAME_DEADLINE_MILLIS = 8000` is a #guard at the bottom, not a hypothesis. -/

structure WatchState where
  elapsed : Nat
  frames  : Nat
  open_   : Bool
  deriving DecidableEq, Repr

def watchdogFires (s : WatchState) (deadline : Nat) : Bool :=
  s.open_ && s.frames = 0 && deadline ≤ s.elapsed

theorem the_watchdog_is_silent_while_frames_arrive (s : WatchState) (d : Nat) (h : 0 < s.frames) :
    watchdogFires s d = false := by
  simp [watchdogFires, Nat.pos_iff_ne_zero.mp h]

theorem the_watchdog_fires_on_a_black_preview (e d : Nat) (h : d ≤ e) :
    watchdogFires ⟨e, 0, true⟩ d = true := by
  simp [watchdogFires, h]

/-- Closing the window silences it: a report about a preview the user already dismissed is noise,
and firing after close would train the reader to ignore the alarm. -/
theorem closing_the_window_silences_it (e f d : Nat) :
    watchdogFires ⟨e, f, false⟩ d = false := by
  simp [watchdogFires]

/-- Before the deadline it says nothing, so a slow HLS handshake is not called a failure. -/
theorem the_watchdog_waits_for_the_deadline (e d : Nat) (h : e < d) (f : Nat) :
    watchdogFires ⟨e, f, true⟩ d = false := by
  simp [watchdogFires]
  omega

/-! ## 4. Catch breadth: `Exception` is not `Throwable`

The launcher's `catch (Exception)` is why a stale-artifact failure produced no log line at all.
Modelled as the two kinds the JVM actually distinguishes. -/

inductive Thrown
  | exception
  | error
  deriving DecidableEq, Repr

def caughtByException : Thrown → Bool
  | .exception => true
  | .error => false

def caughtByThrowable : Thrown → Bool := fun _ => true

theorem catching_exception_misses_an_error : caughtByException .error = false := by decide

theorem catching_throwable_reports_both (t : Thrown) : caughtByThrowable t = true := rfl

/-- The repair is strictly wider -- everything the old catch saw, the new one still sees. So this
is a widening, never a behaviour swap. -/
theorem the_wider_catch_loses_nothing (t : Thrown) (_h : caughtByException t = true) :
    caughtByThrowable t = true := rfl

/-- ...and it is strictly wider, witnessed. -/
theorem the_wider_catch_gains_the_error_case :
    caughtByException .error = false ∧ caughtByThrowable .error = true := by decide

/-! ## 5. Executable checks -- these run, they do not merely elaborate -/

#guard retain ["a", "b", "c", "d"] 2 = ["c", "d"]
#guard (retain (List.replicate 500 "warn") 40).length = 40
#guard shouldReport 0 0 = true
#guard shouldReport 0 1 = false
#guard shouldReport 8 5 = true
#guard exitCodeOnly 0 0 = false
#guard discardingReporter 8 0 = false
-- 8000 ms is PipPreviewWindow.NO_FRAME_DEADLINE_MILLIS. Pinned here as a #guard, deliberately not
-- baked into any theorem: the laws above hold for every deadline, so changing this number cannot
-- invalidate a proof -- only this line has to move with it.
#guard watchdogFires ⟨8000, 0, true⟩ 8000 = true
#guard watchdogFires ⟨7999, 0, true⟩ 8000 = false
#guard watchdogFires ⟨20000, 1016, true⟩ 8000 = false
#guard caughtByException .error = false

end CtbrecSpec.PreviewDiagnostics
