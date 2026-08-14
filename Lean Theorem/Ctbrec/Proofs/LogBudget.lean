/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: BOUNDING a log site without blinding it (checklist item V2).

MEASURED 2026-08-13 in the running app's ctbrec.log:

    grep -c viewer ctbrec.log            -> 10276
    "getViewerCount on ChaturbateModel returned non-numeric null -- treating as unknown"

One WARN per model per tab refresh. 90 models per page, a refresh every few seconds. The lines that
actually mattered that session -- the NoClassDefFoundError block and a single UnknownHostException --
were buried under five figures of noise. A log that repeats ten thousand times is not loud, it is
silent.

The obvious fix (a rate limiter) has an obvious way to be WRONG, and it is the reason this file
exists rather than a two-line `if (counter++ % 100 == 0)`:

  * a limiter that can drop the FIRST event of a kind converts a real defect into no evidence,
  * a limiter that discards silently is the same defect as the empty catch blocks found in
    PreviewVolumeBus and the Redirect.DISCARD on the audio child's stderr.

So the budget must report the first event ALWAYS, and must DISCLOSE what it withheld.

Mirrors src/common/ctbrec/io/LogBudget.java. Executable agreement: tools/probe/LogBudgetProbe.java
(40 exhaustive (permits,window) schedules, conservation checked on every one).

NOT PROVED here: that slf4j writes the line, or that logback's own appender is configured. Those are
outside Lean; the probe and the live log are the instruments for them.
-/

namespace Proofs.Ctbrec.LogBudget

/-- Budget configuration. `permits ≥ 1` is a field invariant, not a hope: see `mkBudget`. -/
structure Config where
  permits : Nat
  window : Nat
  deriving DecidableEq, Repr

/-- Runtime state. `started = false` is the "no window yet" case (`Long.MIN_VALUE` in Java). -/
structure State where
  started : Bool
  windowStart : Nat
  used : Nat
  suppressed : Nat
  deriving DecidableEq, Repr

def initial : State := ⟨false, 0, 0, 0⟩

/-- One offered event at time `now`. Returns the decision and the next state. -/
def offer (c : Config) (s : State) (now : Nat) : Bool × State :=
  if !s.started || now - s.windowStart ≥ c.window then
    (true, ⟨true, now, 1, s.suppressed⟩)
  else if s.used < c.permits then
    (true, { s with used := s.used + 1 })
  else
    (false, { s with suppressed := s.suppressed + 1 })

def decide' (c : Config) (s : State) (now : Nat) : Bool := (offer c s now).1
def next (c : Config) (s : State) (now : Nat) : State := (offer c s now).2

/-! ## Law 1 — the first event is ALWAYS reported

This is the law the naive limiter breaks, and the whole reason a budget is allowed near a defect
report at all. It holds for every configuration and every clock value, including a `permits = 0`
configuration — which is separately rejected in Java, but the state machine must not depend on that.
-/

theorem the_first_event_is_always_reported (c : Config) (now : Nat) :
    decide' c initial now = true := by
  simp [decide', offer, initial]

/-- Stronger: the first event passes whatever the permit count, so no misconfiguration hides it. -/
theorem no_configuration_can_silence_the_first_event (permits window now : Nat) :
    decide' ⟨permits, window⟩ initial now = true :=
  the_first_event_is_always_reported _ _

/-! ## Law 2 — within a window, never more than `permits` -/

/-- A rejection can only happen with the permits already spent. -/
theorem a_rejection_means_the_budget_was_spent (c : Config) (s : State) (now : Nat)
    (h : decide' c s now = false) : c.permits ≤ s.used := by
  unfold decide' offer at h
  by_cases hw : !s.started || now - s.windowStart ≥ c.window
  · simp [hw] at h
  · by_cases hu : s.used < c.permits
    · simp [hw, hu] at h
    · exact Nat.le_of_not_lt hu

/-- `used` never exceeds `permits` once a window is open with permits available. -/
theorem used_never_passes_permits (c : Config) (s : State) (now : Nat)
    (h : s.used ≤ c.permits) (hstart : 1 ≤ c.permits) : (next c s now).used ≤ c.permits := by
  unfold next offer
  by_cases hw : !s.started || now - s.windowStart ≥ c.window
  · simpa [hw] using hstart
  · by_cases hu : s.used < c.permits
    · simp [hw, hu]
      omega
    · simpa [hw, hu] using h

/-! ## Law 3 — conservation: nothing is lost, only deferred into a number -/

/-- A permitted event never inflates the backlog. -/
theorem a_permitted_event_suppresses_nothing (c : Config) (s : State) (now : Nat)
    (h : decide' c s now = true) : (next c s now).suppressed = s.suppressed := by
  unfold decide' next offer at *
  by_cases hw : !s.started || now - s.windowStart ≥ c.window
  · simp [hw]
  · by_cases hu : s.used < c.permits
    · simp [hw, hu]
    · simp [hw, hu] at h

/-- A rejected event is counted, exactly once. -/
theorem a_rejected_event_is_counted_exactly_once (c : Config) (s : State) (now : Nat)
    (h : decide' c s now = false) : (next c s now).suppressed = s.suppressed + 1 := by
  unfold decide' next offer at *
  by_cases hw : !s.started || now - s.windowStart ≥ c.window
  · simp [hw] at h
  · by_cases hu : s.used < c.permits
    · simp [hw, hu] at h
    · simp [hw, hu]

/-- Every offer either reports or counts — there is no third outcome, no silent drop. -/
theorem every_offer_is_reported_or_counted (c : Config) (s : State) (now : Nat) :
    (decide' c s now = true ∧ (next c s now).suppressed = s.suppressed)
      ∨ (decide' c s now = false ∧ (next c s now).suppressed = s.suppressed + 1) := by
  by_cases h : decide' c s now = true
  · exact Or.inl ⟨h, a_permitted_event_suppresses_nothing c s now h⟩
  · have hf : decide' c s now = false := by simpa using h
    exact Or.inr ⟨hf, a_rejected_event_is_counted_exactly_once c s now hf⟩

/-- Run a schedule of offer times, accumulating reported count and final state. -/
def run (c : Config) : List Nat → State → Nat × State
  | [], s => (0, s)
  | t :: ts, s =>
      let (ok, s') := offer c s t
      let (n, s'') := run c ts s'
      (if ok then n + 1 else n, s'')

/-- THE conservation law over a whole schedule: reported + newly suppressed = offered. -/
theorem nothing_is_lost_over_a_schedule (c : Config) (times : List Nat) (s : State) :
    (run c times s).1 + ((run c times s).2.suppressed - s.suppressed) = times.length := by
  induction times generalizing s with
  | nil => simp [run]
  | cons t ts ih =>
      have hmono : ∀ (u : State) (l : List Nat), u.suppressed ≤ (run c l u).2.suppressed := by
        intro u l
        induction l generalizing u with
        | nil => simp [run]
        | cons x xs ih2 =>
            have hstep : u.suppressed ≤ (offer c u x).2.suppressed := by
              unfold offer
              by_cases hw : !u.started || x - u.windowStart ≥ c.window
              · simp [hw]
              · by_cases hu : u.used < c.permits
                · simp [hw, hu]
                · simp [hw, hu]
            exact Nat.le_trans hstep (ih2 (offer c u x).2)
      by_cases hok : (offer c s t).1 = true
      · have hsupp : (offer c s t).2.suppressed = s.suppressed :=
          a_permitted_event_suppresses_nothing c s t hok
        have := ih (offer c s t).2
        have hle := hmono (offer c s t).2 ts
        simp [run, hok, hsupp] at this ⊢
        omega
      · have hf : (offer c s t).1 = false := by simpa using hok
        have hsupp : (offer c s t).2.suppressed = s.suppressed + 1 :=
          a_rejected_event_is_counted_exactly_once c s t hf
        have := ih (offer c s t).2
        have hle := hmono (offer c s t).2 ts
        simp [run, hf, hsupp] at this ⊢
        omega

/-- A non-empty schedule always reports at least one line: the budget can never go fully dark. -/
theorem a_schedule_is_never_fully_silenced (c : Config) (t : Nat) (ts : List Nat) :
    1 ≤ (run c (t :: ts) initial).1 := by
  have h : (offer c initial t).1 = true := the_first_event_is_always_reported c t
  simp [run, h]

/-! ## Law 4 — disclosure empties the backlog (mirrors `suppressionSuffix`) -/

def disclose (s : State) : Nat × State := (s.suppressed, { s with suppressed := 0 })

theorem disclosure_reports_the_whole_backlog (s : State) : (disclose s).1 = s.suppressed := rfl

theorem disclosure_empties_the_backlog (s : State) : (disclose s).2.suppressed = 0 := rfl

/-- Disclosing twice in a row says nothing the second time: a quiet log stays quiet. -/
theorem a_quiet_budget_discloses_nothing (s : State) :
    (disclose (disclose s).2).1 = 0 := rfl

/-! ## The measured flood, as `#guard` -/

-- The real configuration: 3 permits per 60s.
#guard (run ⟨3, 60000⟩ (List.range 90 |>.map (fun i => 1000 + i)) initial).1 == 3
#guard (run ⟨3, 60000⟩ (List.range 90 |>.map (fun i => 1000 + i)) initial).2.suppressed == 87
-- What the un-budgeted site did in one session: every offer became a line.
#guard (run ⟨10276, 60000⟩ (List.range 90 |>.map (fun i => 1000 + i)) initial).1 == 90
-- A new window restores the budget: 3 in the first window, 3 in the next.
#guard (run ⟨3, 100⟩ [0, 1, 2, 3, 4, 100, 101, 102, 103] initial).1 == 6
-- Conservation on that same schedule.
#guard (run ⟨3, 100⟩ [0, 1, 2, 3, 4, 100, 101, 102, 103] initial).2.suppressed == 3
-- The first event passes even at permits = 1.
#guard (run ⟨1, 60000⟩ [5] initial).1 == 1

end Proofs.Ctbrec.LogBudget
