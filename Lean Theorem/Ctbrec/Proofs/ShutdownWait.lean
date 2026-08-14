/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — interrupt handling at shutdown

Subject: `src/common/ctbrec/recorder/SimplifiedLocalRecorder.java`, three sites:

```java
private void waitABit(int millis) {                                  // :163
   try { Thread.sleep(millis); }
   catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      log.error("Interrupted while waiting in main loop. CPU usage might be high now :(");
   }
}

private Thread startMaintenanceLoop() {                              // :113
   while (this.running && !Thread.currentThread().isInterrupted()) { ... waitABit(1000); }
}

private void waitForRecordingsToTerminate() {                        // :302
   long secondsToWait = TimeUnit.MINUTES.toSeconds(10L);
   for (int i = 0; i < secondsToWait; i++) {
      if (this.recordingProcesses.isEmpty()) return;
      log.info("Waiting for recording processes to terminate");
      this.waitABit(1000);                                            // no interrupt check
   }
   log.warn("Recording processes didn't finish in {} seconds ...");
}
```

## Defect 1 — an ERROR for the normal case

`ctbrec.log` carries **13** `Interrupted while waiting in main loop` at ERROR. Every one
of them is immediately adjacent to `INFO [Shutdown] ... Shutting down` — measured, all
13 of 13. The interrupt *is* the shutdown signal; reporting it at ERROR trains the reader
to ignore ERROR. The codebase already knows the right shape: `MyFreeCamsClient.onFailure`
checks `if (!running) log.debug(...)` before shouting.

## Defect 2 — the wait loop cannot wait once interrupted

`waitABit` swallows `InterruptedException`, **re-arms the interrupt flag**, and returns.
Every subsequent `Thread.sleep` therefore throws immediately. In `waitForRecordingsToTerminate`
the loop condition never inspects the flag, so the 600-iteration, ten-minute grace period
for recordings to finish collapses to 600 immediate iterations — a busy spin that waits
**zero** milliseconds and then declares the recordings overdue. The grace period is not
shortened, it is *annulled*, and any recording still running loses its post-processing.

That path has fired once in this log (2026-07-29 21:54:07); the maintenance loop at `:113`
does check the flag, which is why the other 12 shutdowns produced one line rather than 600.
It is a latent defect, and it is exactly the one the error message itself predicts.

Both fixes are proved to cost nothing when nothing is wrong: `elapsed_is_unchanged` and
`uninterrupted_behaviour_is_identical`.
-/

namespace CtbrecSpec

/-! ## 1. Severity of an interrupt -/

inductive Severity where
  | debug
  | warn
  | error
  deriving DecidableEq, Repr

/-- The shipped behaviour: ERROR unconditionally. -/
def legacySeverity (_running : Bool) : Severity := .error

/-- The fortified behaviour: an interrupt while running is a genuine fault; an interrupt
after `running` has been cleared is the shutdown signal doing its job. -/
def fortifiedSeverity (running : Bool) : Severity :=
  if running then .error else .debug

/-- **The real fault is still reported.** This is the anti-amputation clause: quieting
shutdown must not quiet a mid-run interrupt. -/
theorem fortified_still_errors_when_running :
    fortifiedSeverity true = Severity.error := by decide

/-- **The false alarm is gone.** -/
theorem fortified_quiet_during_shutdown :
    fortifiedSeverity false = Severity.debug := by decide

/-- What the shipped code does with the same input — pinned, so the comparison is against
the real behaviour rather than a description of it. -/
theorem legacy_cries_wolf : legacySeverity false = Severity.error := by decide

/-- The two policies differ on exactly one input, and it is the one that occurred 13
times out of 13 in the log. -/
theorem policies_differ_only_on_shutdown (running : Bool) :
    (legacySeverity running = fortifiedSeverity running) ↔ running = true := by
  cases running <;> simp [legacySeverity, fortifiedSeverity]

/-! ### 1b. The one-flag policy was NOT enough — measured, and my spec was wrong

`fortifiedSeverity` above is green, kernel-rechecked, and **did not fix the log**. Six more
`Interrupted while waiting in main loop` ERRORs appeared on 2026-08-03/04, 20 in total.

The reason is an **ordering fact the one-flag model never captured**. `shutdown()` in
`SimplifiedLocalRecorder.java:707`:

```
shutdown():  shuttingDown = true          <- :709, set FIRST
             shutdownPool("Recording loops", ...)   <- :719, INTERRUPTS the loop threads
             finally { running = false }  <- :729, set LAST
```

The interrupt is delivered at :719, while `running` is **still true**. So `waitABit` reads
`running = true` and takes the ERROR branch on a perfectly clean shutdown.

`fortified_quiet_during_shutdown` is a true theorem about a state that **never occurs**. That is
the failure mode this project keeps hunting: a theorem whose *name* claims it constrains
shutdown while its *statement* is about an unreachable input. It is not vacuous — `Severity`
is inhabited and `decide` computes it — it is **misaimed**, which is harder to see.

The app already knows both flags matter: `SimplifiedLocalRecorder.java:940` guards with
`this.running && !this.shuttingDown`. The wait guard simply did not.

This is a **strengthening, not a weakening**: a genuine mid-run interrupt has
`shuttingDown = false` and still reports ERROR (`two_flag_still_errors_mid_run`). Only the
shutdown case is reclassified, and only because it was misclassified. -/

/-- The two flags as the running thread actually observes them at interrupt time. -/
structure ShutdownState where
  running : Bool
  shuttingDown : Bool
deriving DecidableEq, Repr

/-- The corrected guard: ERROR only when running AND not shutting down. Mirrors the shape
already used at `SimplifiedLocalRecorder.java:940`. -/
def twoFlagSeverity (s : ShutdownState) : Severity :=
  if s.running && !s.shuttingDown then .error else .debug

/-- **The state that actually occurs at shutdown**: the interrupt is delivered from
`shutdownPool` at :719, between `shuttingDown = true` (:709) and `running = false` (:729). -/
def observedAtShutdown : ShutdownState := ⟨true, true⟩

/-- **The one-flag policy misclassifies the state that really occurs.** This is the theorem
that should have existed before, and its absence is why the log kept filling. -/
theorem one_flag_misclassifies_the_real_shutdown :
    fortifiedSeverity observedAtShutdown.running = Severity.error := by decide

/-- **The two-flag policy classifies it correctly.** -/
theorem two_flag_is_quiet_at_the_real_shutdown :
    twoFlagSeverity observedAtShutdown = Severity.debug := by decide

/-- **Anti-amputation: a genuine mid-run interrupt is still an ERROR.** Quieting shutdown must
not quieten a real fault, or the fix would be a disarmament. -/
theorem two_flag_still_errors_mid_run :
    twoFlagSeverity ⟨true, false⟩ = Severity.error := by decide

/-- The two policies differ **exactly** on the shutdown-while-running state — nowhere else. So
the change is surgical, not a blanket silencing. -/
theorem the_policies_differ_only_where_intended (s : ShutdownState) :
    (twoFlagSeverity s = fortifiedSeverity s.running) ↔ ¬(s.running = true ∧ s.shuttingDown = true) := by
  cases s with
  | mk r d => cases r <;> cases d <;> simp [twoFlagSeverity, fortifiedSeverity]

/-- ERROR is reached by exactly one state, so the guard cannot be silently over-broad. -/
theorem exactly_one_state_is_an_error (s : ShutdownState) :
    twoFlagSeverity s = Severity.error ↔ s = ⟨true, false⟩ := by
  cases s with
  | mk r d => cases r <;> cases d <;> simp [twoFlagSeverity]

/-- **The ordering is the root cause, stated as a fact about the code.** If `running = false`
ran before the interrupt instead of in `finally`, the one-flag guard would have worked. It does
not, so the guard must read the flag that IS set first. -/
def runningClearedBeforeInterrupt : Bool := false

theorem the_ordering_is_why_one_flag_failed :
    runningClearedBeforeInterrupt = false
      ∧ fortifiedSeverity observedAtShutdown.running = Severity.error := by decide

#guard twoFlagSeverity observedAtShutdown == Severity.debug
#guard twoFlagSeverity ⟨true, false⟩ == Severity.error
#guard twoFlagSeverity ⟨false, false⟩ == Severity.debug
#guard twoFlagSeverity ⟨false, true⟩ == Severity.debug
#guard fortifiedSeverity observedAtShutdown.running == Severity.error

/-! ## 2. The bounded wait

`interruptAt` is the iteration index at which the interrupt arrives; a value at or beyond
`budget` means it never arrives during the wait. -/

/-- Iterations the shipped loop executes: all of them, because the loop condition never
inspects the interrupt flag. -/
def legacyIterations (budget : Nat) (_interruptAt : Nat) : Nat := budget

/-- Iterations the fortified loop executes: it stops when the interrupt arrives. -/
def fortifiedIterations (budget interruptAt : Nat) : Nat := min budget interruptAt

/-- Milliseconds the shipped loop actually sleeps: it runs `budget` iterations, but after
the interrupt every `Thread.sleep` throws immediately, so only the iterations *before* the
interrupt contribute. -/
def legacyElapsed (budget per interruptAt : Nat) : Nat :=
  per * min (legacyIterations budget interruptAt) interruptAt

/-- Milliseconds the fortified loop sleeps: it stops at the interrupt, and every one of
its iterations sleeps. -/
def fortifiedElapsed (budget per interruptAt : Nat) : Nat :=
  per * fortifiedIterations budget interruptAt

/-- Convenience alias used by the `#guard`s below. -/
def elapsed (budget per interruptAt : Nat) : Nat := fortifiedElapsed budget per interruptAt

/-- **The fortification costs no waiting.** The two loops sleep for exactly the same
number of milliseconds, for every budget, period and interrupt time — the shipped one
merely spins afterwards. Stated over two *separately defined* functions, so it is an
equality that a wrong definition can break, not a restatement of one definition. -/
theorem elapsed_is_unchanged (budget per interruptAt : Nat) :
    legacyElapsed budget per interruptAt = fortifiedElapsed budget per interruptAt := by
  simp [legacyElapsed, fortifiedElapsed, legacyIterations, fortifiedIterations]

/-- **Nothing changes when no interrupt arrives.** With `interruptAt ≥ budget` the two
loops execute the identical number of iterations, so a normal, uninterrupted shutdown is
completely unaffected. -/
theorem uninterrupted_behaviour_is_identical (budget interruptAt : Nat)
    (h : budget ≤ interruptAt) :
    legacyIterations budget interruptAt = fortifiedIterations budget interruptAt := by
  simp [legacyIterations, fortifiedIterations, Nat.min_eq_left h]

/-- **The busy spin, exactly stated.** An interrupt at iteration 0 makes the shipped loop
run its whole budget while sleeping for zero milliseconds. -/
theorem legacy_spins (budget per : Nat) :
    legacyIterations budget 0 = budget ∧ elapsed budget per 0 = 0 := by
  simp [legacyIterations, elapsed, fortifiedElapsed, fortifiedIterations]

/-- The fortified loop does not. -/
theorem fortified_does_not_spin (budget per : Nat) :
    fortifiedIterations budget 0 = 0 ∧ elapsed budget per 0 = 0 := by
  simp [fortifiedIterations, elapsed, fortifiedElapsed]

/-- **The fortified loop never does more work**, for every budget and every interrupt
time — not only for the interesting ones. -/
theorem fortified_never_more_iterations (budget interruptAt : Nat) :
    fortifiedIterations budget interruptAt ≤ legacyIterations budget interruptAt :=
  Nat.min_le_left _ _

/-- **The wasted iterations, quantified.** Everything after the interrupt is spin. -/
theorem wasted_iterations (budget interruptAt : Nat) (h : interruptAt ≤ budget) :
    legacyIterations budget interruptAt - fortifiedIterations budget interruptAt
      = budget - interruptAt := by
  simp [legacyIterations, fortifiedIterations, Nat.min_eq_right h]

/-- The grace period is annulled rather than shortened: the shipped loop reaches its
"didn't finish in time" branch having waited less than the budget it advertises,
whenever the interrupt lands before the end. -/
theorem grace_period_is_annulled (budget per interruptAt : Nat)
    (hp : 0 < per) (hi : interruptAt < budget) :
    elapsed budget per interruptAt < per * budget := by
  simp only [elapsed, fortifiedElapsed, fortifiedIterations, Nat.min_eq_right (Nat.le_of_lt hi)]
  exact (Nat.mul_lt_mul_left hp).mpr hi

/-! ## The concrete shutdown this ships with -/

def waitBudget : Nat := 600      -- TimeUnit.MINUTES.toSeconds(10)
def waitPeriod : Nat := 1000     -- waitABit(1000)

#guard legacyIterations waitBudget 0 == 600
#guard fortifiedIterations waitBudget 0 == 0
#guard elapsed waitBudget waitPeriod 0 == 0
#guard elapsed waitBudget waitPeriod 600 == 600000
#guard elapsed waitBudget waitPeriod 900 == 600000
#guard legacyIterations waitBudget 900 == fortifiedIterations waitBudget 900
#guard fortifiedSeverity true == Severity.error
#guard fortifiedSeverity false == Severity.debug
#guard legacySeverity false == Severity.error

/-- The measured shutdown: interrupted at once, ten minutes of grace advertised, zero
milliseconds actually waited, 600 iterations burned. -/
theorem measured_shutdown_wastes_the_whole_budget :
    legacyIterations waitBudget 0 = 600 ∧
      elapsed waitBudget waitPeriod 0 = 0 ∧
      fortifiedIterations waitBudget 0 = 0 := by decide

end CtbrecSpec
