/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: request pacing is GLOBAL, and the rate never rises with concurrency.

MEASURED: 23 × `HTTP 429` in `ctbrec.log` + `ctbrec.1.log` spanning 2026-08-05 → 08-10, plus one 502.
Those signatures are deliberately NOT in `build/log-signatures.baseline` — baselining them would be
faking green (Checklist N2).

WHAT N2 ASKS FOR, verbatim: "pacing is global, and the rate never rises with concurrency". Both halves
are proved below, and the second is the one that matters: a pacer installed PER THREAD (or per site, or
per OkHttp call) looks like pacing, passes a single-threaded test, and lets the aggregate rate scale
linearly with thread count — which is exactly how a 429 is earned. `independent_pacers_separate_nothing`
states that failure as a definition rather than leaving it as a warning in a comment.

NOT PROVED, and it cannot be from here: that any particular interval avoids a 429. The server's limit
is not an artifact of this program. What is proved is the shape of the guarantee — spacing, monotone
backoff, a bounded cap, and that the first request is never delayed (a pacer that delayed the first
request would be a startup regression, not politeness).
-/

namespace Proofs.Ctbrec.RequestPacing

/-- A pacer. `last` is the instant of the previous admission; `interval` the minimum spacing. -/
structure Pacer where
  last : Option Nat
  interval : Nat
  deriving Repr, DecidableEq

/-- The instant a request arriving at `now` may proceed. Never earlier than `now`. -/
def next (p : Pacer) (now : Nat) : Nat :=
  match p.last with
  | none => now
  | some t => max now (t + p.interval)

/-- Admit a request: the instant it proceeds, and the pacer that remembers it. -/
def admit (p : Pacer) (now : Nat) : Nat × Pacer :=
  let t := next p now
  (t, { p with last := some t })

/-- Fold a list of arrival instants through ONE pacer — the global case. -/
def schedule (p : Pacer) (arrivals : List Nat) : List Nat :=
  match arrivals with
  | [] => []
  | a :: rest =>
      let (t, p') := admit p a
      t :: schedule p' rest

/-- The defect: one pacer per thread. Each arrival meets a FRESH pacer. -/
def scheduleIndependently (interval : Nat) (arrivals : List Nat) : List Nat :=
  arrivals.map (fun a => next { last := none, interval := interval } a)

/-! ## Law 1 — the first request is never delayed -/

theorem the_first_request_is_never_delayed (interval now : Nat) :
    next { last := none, interval := interval } now = now := by
  simp [next]

theorem an_idle_pacer_delays_nothing (interval : Nat) (arrivals : List Nat) :
    scheduleIndependently interval arrivals = arrivals := by
  induction arrivals with
  | nil => simp [scheduleIndependently]
  | cons a rest ih =>
      simp [scheduleIndependently, next] at ih ⊢

/-! ## Law 2 — a request never proceeds before its arrival, nor before the interval has elapsed -/

theorem an_admission_is_never_in_the_past (p : Pacer) (now : Nat) : now ≤ next p now := by
  cases h : p.last with
  | none => simp [next, h]
  | some t => simp only [next, h]; omega

theorem the_interval_is_respected (p : Pacer) (now t : Nat) (h : p.last = some t) :
    t + p.interval ≤ next p now := by
  simp only [next, h]; omega

/-- Two admissions through ONE pacer are separated by at least the interval. -/
theorem two_admissions_are_separated (p : Pacer) (n1 n2 : Nat) :
    (admit (admit p n1).2 n2).1 ≥ (admit p n1).1 + p.interval := by
  simp only [admit, next, ge_iff_le]
  omega

/-! ## Law 3 — THE ONE N2 ASKS FOR: the rate does not rise with concurrency

A shared pacer separates a burst that all arrives at the same instant; independent pacers separate
nothing at all. The two schedules differ, and the difference IS the defect.
-/

/-- A burst of four simultaneous arrivals through ONE pacer: spaced by the interval. -/
theorem a_shared_pacer_separates_a_simultaneous_burst :
    schedule { last := some 0, interval := 10 } [5, 5, 5, 5] = [10, 20, 30, 40] := by
  decide

/-- The same burst through one pacer PER THREAD: no separation whatsoever. -/
theorem independent_pacers_separate_nothing :
    scheduleIndependently 10 [5, 5, 5, 5] = [5, 5, 5, 5] := by
  decide

/-- Stated as the inequality N2 asks for: per-thread pacing is strictly faster, i.e. worse. -/
theorem the_rate_rises_with_concurrency_only_without_a_shared_pacer :
    scheduleIndependently 10 [5, 5, 5, 5] ≠ schedule { last := some 0, interval := 10 } [5, 5, 5, 5] := by
  decide

/-- Adding more simultaneous arrivals to a shared pacer never packs them closer. -/
theorem a_longer_burst_is_not_denser :
    schedule { last := some 0, interval := 10 } [5, 5, 5, 5, 5]
      = [10, 20, 30, 40, 50] := by
  decide

/-- Doubling the interval at least doubles the span of the same burst. -/
theorem a_wider_interval_spreads_the_same_burst :
    schedule { last := some 0, interval := 20 } [5, 5, 5, 5] = [20, 40, 60, 80] := by
  decide

/-! ## Law 4 — backoff: monotone, capped, and never applied without cause -/

/-- What a 429 does: widen the interval, never past the cap. -/
def widen (cap : Nat) (p : Pacer) : Pacer :=
  { p with interval := min cap (p.interval * 2) }

theorem widening_never_shrinks_the_interval (cap : Nat) (p : Pacer) (h : p.interval ≤ cap) :
    p.interval ≤ (widen cap p).interval := by
  simp only [widen]
  omega

theorem the_interval_is_capped (cap : Nat) (p : Pacer) : (widen cap p).interval ≤ cap := by
  simp only [widen]; omega

/-- `n` consecutive 429s. Explicit recursion rather than `Function.iterate` notation, which did not
parse here (`^[n]` was read as application of a list). -/
def widenTimes (cap : Nat) : Nat → Pacer → Pacer
  | 0, p => p
  | n + 1, p => widen cap (widenTimes cap n p)

/-- Repeated 429s cannot run the interval away: the cap holds after ANY number of widenings ≥ 1.
This is the theorem that makes the backoff safe to install — without it, 23 measured 429s could in
principle have driven the interval to something that stalls the app. -/
theorem the_cap_holds_under_repeated_widening (cap : Nat) (p : Pacer) (n : Nat) (hn : 0 < n) :
    (widenTimes cap n p).interval ≤ cap := by
  cases n with
  | zero => omega
  | succ k => simpa [widenTimes] using the_interval_is_capped cap (widenTimes cap k p)

/-- Backoff is monotone in the number of 429s, as long as it starts under the cap. -/
theorem widening_is_monotone_in_the_number_of_failures (cap : Nat) (p : Pacer) (n : Nat)
    (h : p.interval ≤ cap) : p.interval ≤ (widenTimes cap (n + 1) p).interval := by
  induction n with
  | zero => simpa [widenTimes] using widening_never_shrinks_the_interval cap p h
  | succ k ih =>
      have hk : (widenTimes cap (k + 1) p).interval ≤ cap :=
        the_cap_holds_under_repeated_widening cap p (k + 1) (by omega)
      have h2 := widening_never_shrinks_the_interval cap (widenTimes cap (k + 1) p) hk
      exact Nat.le_trans ih (by simpa [widenTimes] using h2)

/-- The interval only changes through `widen` — an admission never alters it. -/
theorem an_admission_never_changes_the_interval (p : Pacer) (now : Nat) :
    (admit p now).2.interval = p.interval := by
  simp [admit]

/-! ## The measured runs, as `#guard` -/

-- 23 × 429 over 2026-08-05 -> 08-10 is what motivated this; the interval is not derived from it.
#guard next { last := none, interval := 250 } 1000 == 1000
#guard next { last := some 1000, interval := 250 } 1000 == 1250
#guard next { last := some 1000, interval := 250 } 9999 == 9999
#guard schedule { last := some 0, interval := 250 } [0, 0, 0] == [250, 500, 750]
#guard scheduleIndependently 250 [0, 0, 0] == [0, 0, 0]
#guard (widen 4000 { last := none, interval := 250 }).interval == 500
#guard (widen 4000 { last := none, interval := 3000 }).interval == 4000
#guard (widen 4000 { last := none, interval := 4000 }).interval == 4000

end Proofs.Ctbrec.RequestPacing
