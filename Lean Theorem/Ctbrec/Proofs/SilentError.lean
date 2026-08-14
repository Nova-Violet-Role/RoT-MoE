/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the handler chain that could not see an Error

Subject: `src/common/ctbrec/recorder/SimplifiedLocalRecorder.java`,
`startRecordingProcessSync` (line 1026), and the `LinkageError` clause added 2026-08-06.

## The measured event

`java.lang.NoSuchMethodError: 'double ctbrec.io.BandwidthMeter.bytesPerSecond(long,
java.time.Duration)'` was thrown on every recording start between 2026-08-05 21:36 and
2026-08-06 00:53 (JFR `jdk.JavaErrorThrow`, three events captured in a 9-second window,
one per start). The handler chain at the time was

```java
catch (RecordUntilExpiredException e) { log.info(...); ... }
catch (PreconditionNotMetException e) { log.info(...); }
catch (Exception e)                   { log.error("Couldn't start recording process for {}", ...); }
```

`NoSuchMethodError <: LinkageError <: Error <: Throwable`, and `Error` is not `Exception`.
So the throw passed through every clause, left `startRecordingProcessSync` through the
`finally`, and died inside `recordingLoopPool.submit(...)` — whose `Future` nobody reads.

Measured consequence: 94 `Starting recording for model X` lines, **zero** bytes of video,
**zero** WARN or ERROR lines, and a 60-second restart loop indistinguishable from healthy
operation. `recordingProcesses` stayed at 0 forever (TRACE at line 1011), 18
`ChaturbateLlhlsMediaServer` instances leaked (`jcmd GC.class_histogram`), and no ffmpeg
process ever spawned.

## What is modelled

The handler chain, as an ordered list of clauses, and two observables per throwable kind:
does the chain LOG it, and does it PROPAGATE. The fix adds a clause that logs and rethrows.
The load-bearing theorem is not that the new chain logs more — it is
`the_new_clause_changes_visibility_and_nothing_else`: propagation is identical for EVERY
kind, so this is a pure observability change and cannot be blamed for a behaviour shift.

Stated over the whole kind space rather than the one kind that broke, because a spec pinned
to `NoSuchMethodError` would go green while `NoClassDefFoundError` — the same defect class,
the same silence — stayed invisible.
-/

namespace CtbrecSpec
namespace SilentError

/-- The throwable kinds that can leave `startRecordingProcessSync`. `linkage` is the whole
`LinkageError` family (`NoSuchMethodError`, `NoClassDefFoundError`, `NoSuchFieldError`,
`IncompatibleClassChangeError`, `VerifyError`, `UnsatisfiedLinkError`) — modelling it as one
kind is the point: the fix must cover the family, not the one member that fired. -/
inductive Kind where
  /-- `RecordUntilExpiredException` — a checked, expected condition. -/
  | recordUntilExpired
  /-- `PreconditionNotMetException` — a checked, expected condition. -/
  | preconditionNotMet
  /-- Any other `Exception`, checked or runtime (`IOException`, `HttpException`, ...). -/
  | otherException
  /-- `InterruptedException`. An `Exception`, but NOT a failure: `singleRecordingLoop` catches
  it, re-arms the flag with `Thread.currentThread().interrupt()`, cleans up and returns. That is
  the documented idiom for propagating an interrupt, not a swallowed error — see `isFailure`. -/
  | interrupted
  /-- Any `LinkageError`. This is the family that was invisible. -/
  | linkage
  /-- `OutOfMemoryError`, `StackOverflowError`, `ThreadDeath` — `Error`s that are NOT
  `LinkageError` and must stay uncaught. -/
  | fatalError
deriving DecidableEq, Repr

/-- All six kinds, so properties can be checked exhaustively by `decide`. -/
def allKinds : List Kind :=
  [.recordUntilExpired, .preconditionNotMet, .otherException, .interrupted,
   .linkage, .fatalError]

/-- One `catch` clause: the type it catches, whether it logs, whether it rethrows, and — added
for CP75 — whether it RELEASES the resources the try block acquired.

`cleansUp` is not decoration. During the 2026-08-05 outage `jcmd GC.class_histogram` counted
**18 live `ChaturbateLlhlsMediaServer` instances, exactly one per recording start**, and 36
workspaces. Nothing was ever stopped, because every path that would have called
`internalStop()` / `fail()` sits behind a `catch (Exception ...)` that an `Error` walks past.
Visibility and cleanup are INDEPENDENT properties and CP74 only bought the first one. -/
structure Clause where
  /-- Which kinds this clause is reached by, in Java's subtype sense. -/
  catchesKind : Kind → Bool
  logs        : Bool
  rethrows    : Bool
  /-- Does this clause release what the `try` acquired (`internalStop()`, `fail(recording)`)?
  Defaults to `false`: a clause that merely logs and returns leaves the download registered and
  its media server bound to a port. -/
  cleansUp    : Bool := false

/-- `catch (RecordUntilExpiredException e)` -/
def clauseRecordUntil : Clause :=
  { catchesKind := (· == .recordUntilExpired), logs := true, rethrows := false }

/-- `catch (PreconditionNotMetException e)` -/
def clausePrecondition : Clause :=
  { catchesKind := (· == .preconditionNotMet), logs := true, rethrows := false }

/-- `catch (Exception e)`. Reached by every Exception kind and by no Error kind — this single
line is the entire defect. -/
def clauseException : Clause :=
  { catchesKind := fun k => k == .recordUntilExpired || k == .preconditionNotMet
                            || k == .otherException || k == .interrupted
    logs := true, rethrows := false }

/-- `catch (LinkageError e)` — added 2026-08-06. Logs and RETHROWS. -/
def clauseLinkage : Clause :=
  { catchesKind := (· == .linkage), logs := true, rethrows := true }

/-- A hypothetical `catch (Throwable t)` that swallows. Modelled only so it can be REJECTED:
it would also make the error visible, and it would hide a broken deployment behind an app
that keeps running. -/
def clauseSwallowThrowable : Clause :=
  { catchesKind := fun _ => true, logs := true, rethrows := false }

abbrev Chain := List Clause

/-- Java semantics: the FIRST clause whose type is reached wins. -/
def firstMatch (chain : Chain) (k : Kind) : Option Clause :=
  chain.find? (fun c => c.catchesKind k)

/-- Does anything in the log tell an operator this happened? -/
def logged (chain : Chain) (k : Kind) : Bool :=
  match firstMatch chain k with
  | some c => c.logs
  | none   => false

/-- Does the throwable leave the method? -/
def propagates (chain : Chain) (k : Kind) : Bool :=
  match firstMatch chain k with
  | some c => c.rethrows
  | none   => true

/-- The exact chain that was live from 2026-08-05 21:36 to 2026-08-06 00:53. -/
def legacyChain : Chain := [clauseRecordUntil, clausePrecondition, clauseException]

/-- The chain after the fix. The new clause is inserted before `catch (Exception e)`; the
types are disjoint so position among them is free, but the order is fixed here to match the
Java exactly. -/
def fixedChain : Chain :=
  [clauseRecordUntil, clausePrecondition, clauseLinkage, clauseException]

/-! ## The defect -/

/-- THE MEASURED FAILURE, as a statement about the chain rather than about one exception
class: a linkage error was neither logged nor recoverable — it simply left, unseen. -/
theorem the_legacy_chain_never_saw_a_linkage_error :
    logged legacyChain .linkage = false ∧ propagates legacyChain .linkage = true := by
  decide

/-- And it was not caught by anything, which is why the `Future` swallowed it. -/
theorem the_legacy_chain_had_no_clause_for_it :
    firstMatch legacyChain .linkage = none := by decide

/-! ## The fix -/

/-- Visibility restored, for the whole `LinkageError` family. -/
theorem the_fixed_chain_logs_a_linkage_error :
    logged fixedChain .linkage = true := by decide

/-- THE LOAD-BEARING THEOREM. Propagation is unchanged for EVERY kind — so the new clause is
a pure observability change and cannot alter behaviour. Quantified over the whole kind space,
not over the one kind that broke, so a different `LinkageError` next month is covered by the
same statement. -/
theorem the_new_clause_changes_visibility_and_nothing_else :
    allKinds.all (fun k => propagates fixedChain k == propagates legacyChain k) = true := by
  decide

/-- The other half of "nothing else": nothing that used to be logged stopped being logged. A
fix that traded one message for another would satisfy the theorem above alone. -/
theorem no_kind_lost_its_log_line :
    allKinds.all (fun k => !(logged legacyChain k) || logged fixedChain k) = true := by
  decide

/-- Non-vacuity in the strict direction: the fix strictly INCREASES what is logged. Without
this, a chain identical to the legacy one would satisfy both theorems above. -/
theorem the_fix_is_a_strict_improvement :
    (allKinds.filter (fun k => logged fixedChain k)).length
      > (allKinds.filter (fun k => logged legacyChain k)).length := by
  decide

/-! ## What the fix deliberately does NOT do -/

/-- `OutOfMemoryError` and friends stay uncaught and stay fatal. Catching them was the easy
wrong fix. -/
theorem oom_is_still_not_caught :
    firstMatch fixedChain .fatalError = none ∧ propagates fixedChain .fatalError = true := by
  decide

/-- REJECTED ALTERNATIVE, kept in the spec so it cannot be reintroduced by accident. A
swallowing `catch (Throwable t)` also makes the linkage error visible — and it changes
propagation, hiding a broken deployment behind an app that keeps running and records nothing.
This is exactly the failure mode the whole checkpoint exists to remove. -/
def swallowingChain : Chain :=
  [clauseRecordUntil, clausePrecondition, clauseSwallowThrowable]

theorem swallowing_would_be_visible_but_wrong :
    logged swallowingChain .linkage = true ∧
    propagates swallowingChain .linkage = false ∧
    propagates legacyChain .linkage = true := by
  decide

/-- Stated as the disqualifying property, quantified: the swallowing chain fails the
"nothing else" test that the real fix passes. -/
theorem swallowing_fails_the_nothing_else_test :
    allKinds.all (fun k => propagates swallowingChain k == propagates legacyChain k)
      = false := by
  decide

/-- And it would swallow `OutOfMemoryError` too — the concrete reason it is not the fix. -/
theorem swallowing_would_eat_oom :
    propagates swallowingChain .fatalError = false := by decide

/-! ## The other silence: a catch clause that does not log

Found by mutation, not by inspection. Mutating `logged`'s `| some c => c.logs` arm to
`| some c => true` SURVIVED the first sweep, because every clause modelled above had
`logs := true` — so the field was never load-bearing and the model could not tell a logging
catch from a swallowing one. That is the same defect this module is about, reached from the
other side, and `catch (Exception e) { }` is a real thing that appears in real code. -/

/-- `catch (Exception e) { }` — reached, and silent. -/
def clauseSwallowSilently : Clause :=
  { catchesKind := fun k => k == .recordUntilExpired || k == .preconditionNotMet
                            || k == .otherException || k == .interrupted
    logs := false, rethrows := false }

/-- What the recorder would be if the final `catch (Exception e)` stopped logging. -/
def silentChain : Chain := [clauseRecordUntil, clausePrecondition, clauseSwallowSilently]

/-- A silent catch is exactly as invisible as no catch at all, and strictly worse, because it
also stops the throwable from propagating to anything that might have reported it. -/
theorem a_silent_catch_is_as_invisible_as_no_catch :
    logged silentChain .otherException = false ∧
    logged legacyChain .otherException = true ∧
    propagates silentChain .otherException = false := by
  decide

/-- The invariant that both halves of this checkpoint enforce, stated over every kind: nothing
is caught without being reported. The legacy chain satisfied it — its failure was that a
`LinkageError` was not caught AT ALL, which is why `the_legacy_chain_never_saw_a_linkage_error`
is a separate statement and neither theorem subsumes the other. -/
def everyCaughtKindIsLogged (chain : Chain) : Bool :=
  allKinds.all (fun k => (firstMatch chain k).isNone || logged chain k)

theorem the_fixed_chain_logs_everything_it_catches :
    everyCaughtKindIsLogged fixedChain = true := by decide

theorem a_silent_catch_violates_the_invariant :
    everyCaughtKindIsLogged silentChain = false := by decide

/-- And the invariant alone is not enough — the legacy chain passes it while being the exact
configuration that lost 3 h 12 min of recordings. Both obligations are needed: log what you
catch, and catch what can kill you. -/
theorem the_invariant_alone_would_have_passed_the_broken_build :
    everyCaughtKindIsLogged legacyChain = true ∧
    logged legacyChain .linkage = false := by
  decide

/-! ## CP75 — the SECOND silent path, and the leak that visibility alone does not close

`startRecordingProcessSync` was fixed in CP74. `singleRecordingLoop` (line 211) has the same
hole and one extra consequence:

```java
} catch (InterruptedException e) {          // cleans up, deliberately quiet, re-arms the flag
   Thread.currentThread().interrupt();
   this.fail(recording);
   return;
} catch (Exception e) {                     // logs, cleans up
   log.error("Error while recording model {}. Stopping recording.", ...);
   this.fail(recording);
   return;
}                                           // LinkageError: no clause at all
```

A `LinkageError` reaches NEITHER clause, so `fail(recording)` never runs — and `fail` is what
calls `stopRecordingProcess` → `RecordingProcess.stop()` → `internalStop()` →
`cleanupWorkspaceIfNeeded()`. That is the mechanism behind the measured leak: **18 live
`ChaturbateLlhlsMediaServer` instances, one per start, 36 workspaces**, every one holding a
loopback port.

`NEXT-74` recorded an explicit warning against reusing CP74's theorem here, because this fix is
**not** pure observability: it adds cleanup that the broken path did not do. That warning is
honoured below — `the_loop_fix_is_not_pure_observability` states the difference rather than
hiding it. -/

/-- Does the throwable leave resources bound? No clause reached ⇒ nothing released. -/
def leaks (chain : Chain) (k : Kind) : Bool :=
  match firstMatch chain k with
  | some c => !c.cleansUp
  | none   => true

/-- `catch (InterruptedException e)` in the loop: cleans up, does not log, does not rethrow.
The quiet is deliberate — an interrupt at shutdown is a control signal, and
`Thread.currentThread().interrupt()` re-arms it for the caller. -/
def clauseInterrupted : Clause :=
  { catchesKind := (· == .interrupted), logs := false, rethrows := false, cleansUp := true }

/-- `catch (Exception e)` in the loop: logs AND cleans up. Note this differs from the start
path's `catch (Exception e)`, which only logs — the loop is where cleanup lives. -/
def clauseLoopException : Clause :=
  { catchesKind := fun k => k == .recordUntilExpired || k == .preconditionNotMet
                            || k == .otherException || k == .interrupted
    logs := true, rethrows := false, cleansUp := true }

/-- The new clause: logs, cleans up, rethrows. -/
def clauseLoopLinkage : Clause :=
  { catchesKind := (· == .linkage), logs := true, rethrows := true, cleansUp := true }

/-- `singleRecordingLoop` as it stood during the outage. -/
def legacyLoopChain : Chain := [clauseInterrupted, clauseLoopException]

/-- ...and after CP75. -/
def fixedLoopChain : Chain := [clauseInterrupted, clauseLoopLinkage, clauseLoopException]

/-- THE LEAK, as a statement rather than a count: a linkage error in the loop released nothing. -/
theorem the_legacy_loop_leaks_on_a_linkage_error :
    leaks legacyLoopChain .linkage = true ∧ logged legacyLoopChain .linkage = false := by
  decide

theorem the_fixed_loop_neither_leaks_nor_hides :
    leaks fixedLoopChain .linkage = false ∧ logged fixedLoopChain .linkage = true := by
  decide

/-- **THE HONESTY THEOREM.** This fix is NOT the same shape as CP74's. Propagation is unchanged
for every kind, but LEAKAGE is not — so CP74's
`the_new_clause_changes_visibility_and_nothing_else` must NOT be reused for it. Stated as an
inequality on purpose: claiming "nothing else changed" here would be an overclaim. -/
theorem the_loop_fix_is_not_pure_observability :
    allKinds.all (fun k => propagates fixedLoopChain k == propagates legacyLoopChain k) = true ∧
    allKinds.all (fun k => leaks fixedLoopChain k == leaks legacyLoopChain k) = false := by
  decide

/-- What the loop fix DOES preserve: nothing that used to be released stops being released, and
nothing that used to be logged stops being logged. Monotone in both observables. -/
theorem the_loop_fix_loses_nothing :
    allKinds.all (fun k => leaks legacyLoopChain k || !(leaks fixedLoopChain k)) = true ∧
    allKinds.all (fun k => !(logged legacyLoopChain k) || logged fixedLoopChain k) = true := by
  decide

/-- The quiet clause is quiet, not negligent: an interrupt at shutdown still calls
`fail(recording)`, so a graceful stop releases the media server on both the old and the new
chain. This is what makes the interrupt exemption defensible — it is exempt from LOGGING, never
from CLEANUP. -/
theorem an_interrupt_never_leaks :
    leaks legacyLoopChain .interrupted = false ∧ leaks fixedLoopChain .interrupted = false := by
  decide

/-- And it still does not touch `OutOfMemoryError`. -/
theorem the_loop_fix_leaves_oom_alone :
    (firstMatch fixedLoopChain .fatalError).isNone = true ∧
    propagates fixedLoopChain .fatalError = true := by
  decide

/-! ### Resource accounting: what the A/B experiment measured, stated for EVERY start count

CP76 ran the same broken deployment twice against three live models -- once with the pre-CP74
jar and once with the CP75 jar carrying the identical missing method -- and counted live
`ChaturbateLlhlsMediaServer` instances with `jcmd GC.class_histogram`:

| build | starts | ERROR lines | live media servers | workspaces |
|---|---|---|---|---|
| A, pre-CP74 | 9 | **0** | **9** | 18 |
| B, CP75     | 9 | **9** | **0** | 0 |

Two runs are two points. The theorems below are the CLAIM those points are evidence for: one
leaked server per start without bound, none at all with the fix, for every n. A measurement
samples; this settles. -/

/-- Servers still bound after `starts` recording starts that all hit throwable `k`. -/
def leakedAfter (chain : Chain) (k : Kind) (starts : Nat) : Nat :=
  if leaks chain k then starts else 0

/-- **One leaked server per start, for EVERY start count** -- the unbounded version of the
9-for-9 that was measured, and of the 18-for-18 measured during the outage itself. -/
theorem the_legacy_loop_leaks_one_server_per_start (n : Nat) :
    leakedAfter legacyLoopChain .linkage n = n := by
  simp [leakedAfter, leaks, firstMatch, legacyLoopChain, clauseInterrupted, clauseLoopException]

/-- ...and none at all after the fix, however many starts occur. -/
theorem the_fixed_loop_leaks_nothing_however_many_starts (n : Nat) :
    leakedAfter fixedLoopChain .linkage n = 0 := by
  simp [leakedAfter, leaks, firstMatch, fixedLoopChain, clauseInterrupted, clauseLoopLinkage]

-- The initialiser's two chains are defined further down, so their accounting theorems live
-- there: `the_legacy_init_leaks_one_server_per_start` and its fixed counterpart.

/-- **The experiment can always tell the two builds apart** -- as long as at least one start
happens. This is what makes the A/B a real instrument rather than a coincidence of one run: had
the difference vanished for some start count, the measurement would prove nothing about the
next one. -/
theorem the_ab_experiment_separates_the_chains (n : Nat) (hn : 0 < n) :
    leakedAfter legacyLoopChain .linkage n ≠ leakedAfter fixedLoopChain .linkage n := by
  rw [the_legacy_loop_leaks_one_server_per_start, the_fixed_loop_leaks_nothing_however_many_starts]
  exact Nat.pos_iff_ne_zero.mp hn

/-! ### The interrupt exemption, bounded so it cannot be widened

`everyCaughtKindIsLogged` is too strict for the loop: the interrupt clause is quiet on purpose.
An exemption is exactly the kind of thing that becomes a loophole, so it is stated as a
predicate and then pinned. -/

/-- Is this kind a FAILURE, or an expected control signal? -/
def isFailure : Kind → Bool
  | .interrupted => false
  | _            => true

/-- **The exemption covers exactly one kind.** Without this, `isFailure` could be widened later
to excuse whatever is inconvenient, and the invariant below would quietly become vacuous. -/
theorem the_interrupt_is_the_only_exemption :
    allKinds.filter (fun k => !isFailure k) = [.interrupted] := by decide

/-- **And it can never cover the defect.** A `LinkageError` is a failure, so no future widening
of the exemption can re-hide the thing this module exists for. -/
theorem a_linkage_error_is_always_a_failure : isFailure .linkage = true := by decide

/-- The invariant the recorder must keep, on both paths. -/
def everyCaughtFailureIsLogged (chain : Chain) : Bool :=
  allKinds.all (fun k => !isFailure k || (firstMatch chain k).isNone || logged chain k)

theorem the_fixed_loop_logs_every_failure_it_catches :
    everyCaughtFailureIsLogged fixedLoopChain = true := by decide

theorem the_legacy_loop_also_logged_every_failure_it_caught :
    everyCaughtFailureIsLogged legacyLoopChain = true := by decide

/-- ...which is precisely why the invariant alone was never going to find this. The legacy loop
satisfied it while leaking on every linkage error — the same lesson as
`the_invariant_alone_would_have_passed_the_broken_build`, now for the leak instead of the log. -/
theorem the_log_invariant_alone_misses_the_leak :
    everyCaughtFailureIsLogged legacyLoopChain = true ∧
    leaks legacyLoopChain .linkage = true := by
  decide

/-- A silent catch is still caught by the strict form, so the exemption has not disarmed it. -/
theorem the_silent_chain_still_violates_the_failure_invariant :
    everyCaughtFailureIsLogged silentChain = false := by decide

/-! ### The download's own initialiser leaks the same way

`ChaturbateLlhlsDownload.init` wraps `captureStartupWindow / determineInputAlignment /
startFfmpegProcess` in `catch (Exception e)` and calls `internalStop()` there. A `LinkageError`
raised inside `startFfmpegProcess` — which is exactly where the outage's throw landed — walks
past it, so the media server started moments earlier at
`ChaturbateLlhlsMediaServer.java:38` is never stopped. This is the OTHER half of the 18-instance
leak, and it is in a different file, so it needs its own clause and its own row here. -/

/-- `init`'s outer handler as it stood: cleans up, wraps into `IOException`, does not rethrow
the original. Wrapping is what makes it invisible twice over — an `Error` wrapped in an
`IOException` would become catchable by `catch (Exception e)` upstream. -/
def clauseInitException : Clause :=
  { catchesKind := fun k => k == .recordUntilExpired || k == .preconditionNotMet
                            || k == .otherException || k == .interrupted
    logs := false, rethrows := true, cleansUp := true }

/-- The new clause: cleans up and rethrows the ORIGINAL throwable, unwrapped. -/
def clauseInitLinkage : Clause :=
  { catchesKind := (· == .linkage), logs := false, rethrows := true, cleansUp := true }

def legacyInitChain : Chain := [clauseInitException]
def fixedInitChain  : Chain := [clauseInitLinkage, clauseInitException]

theorem the_legacy_init_leaks_the_media_server :
    leaks legacyInitChain .linkage = true := by decide

theorem the_fixed_init_releases_it :
    leaks fixedInitChain .linkage = false := by decide

/-- `init` deliberately does NOT log — it rethrows and lets the recorder's clause report once.
Two reports for one fault is noise, and the recorder is where the model name is in scope. So the
init fix is judged on leakage and propagation only, and propagation is unchanged. -/
theorem the_init_fix_changes_only_leakage :
    allKinds.all (fun k => propagates fixedInitChain k == propagates legacyInitChain k) = true ∧
    allKinds.all (fun k => logged fixedInitChain k == logged legacyInitChain k) = true ∧
    leaks fixedInitChain .linkage != leaks legacyInitChain .linkage := by
  decide

/-- The initialiser's half of the CP76 accounting: one server per start, unbounded. -/
theorem the_legacy_init_leaks_one_server_per_start (n : Nat) :
    leakedAfter legacyInitChain .linkage n = n := by
  simp [leakedAfter, leaks, firstMatch, legacyInitChain, clauseInitException]

theorem the_fixed_init_leaks_nothing_however_many_starts (n : Nat) :
    leakedAfter fixedInitChain .linkage n = 0 := by
  simp [leakedAfter, leaks, firstMatch, fixedInitChain, clauseInitLinkage]

/-- A clean chain is bounded by a constant, not by traffic: no start count, however large, puts
a single server beyond release. Stated as `≤ 0` rather than `= 0` deliberately -- a future chain
that legitimately retains ONE pooled server should weaken the bound, not force this theorem to
be rewritten to whatever the code happens to do that day. -/
theorem a_clean_chain_is_bounded_independently_of_load (n : Nat) :
    leakedAfter fixedLoopChain .linkage n ≤ 0 ∧ leakedAfter fixedInitChain .linkage n ≤ 0 := by
  rw [the_fixed_loop_leaks_nothing_however_many_starts,
      the_fixed_init_leaks_nothing_however_many_starts]
  exact ⟨Nat.le_refl 0, Nat.le_refl 0⟩

/-- Together: after CP75 no linkage error anywhere on the recording path leaks, and the recorder
still reports it exactly once. -/
theorem the_whole_recording_path_is_clean :
    leaks fixedInitChain .linkage = false ∧
    leaks fixedLoopChain .linkage = false ∧
    logged fixedChain .linkage = true ∧
    propagates fixedChain .linkage = true := by
  decide

/-! ## Generic guarantee, so the model is not just five hand-checked rows

A clause that rethrows never changes propagation when it is the first match; a clause whose
type nothing reaches changes nothing at all. These hold for any chain and any clause. -/

theorem a_rethrowing_first_match_propagates (chain : Chain) (k : Kind) (c : Clause)
    (hf : firstMatch chain k = some c) (hr : c.rethrows = true) :
    propagates chain k = true := by
  simp [propagates, hf, hr]

theorem an_unreached_clause_is_invisible (chain : Chain) (k : Kind) (c : Clause)
    (h : c.catchesKind k = false) :
    firstMatch (c :: chain) k = firstMatch chain k := by
  simp [firstMatch, List.find?, h]

/-- Therefore inserting a clause that only catches `linkage` cannot disturb any other kind —
the general form of `the_new_clause_changes_visibility_and_nothing_else`, for every chain
rather than for this one. -/
theorem inserting_a_linkage_clause_is_inert_elsewhere (chain : Chain) (k : Kind)
    (h : k ≠ .linkage) :
    firstMatch (clauseLinkage :: chain) k = firstMatch chain k := by
  refine an_unreached_clause_is_invisible chain k clauseLinkage ?_
  simp [clauseLinkage]
  intro hk
  exact absurd hk h

/-! ## Executable checks -/

#guard logged legacyChain .linkage == false
#guard logged fixedChain .linkage == true
#guard propagates fixedChain .linkage == true
#guard propagates fixedChain .otherException == false
#guard propagates legacyChain .otherException == false
#guard (firstMatch fixedChain .fatalError).isNone == true
#guard (firstMatch legacyChain .linkage).isNone == true
#guard (firstMatch fixedChain .linkage).isSome == true
#guard allKinds.length == 6
#guard (allKinds.filter (fun k => logged legacyChain k)).length == 4
#guard (allKinds.filter (fun k => logged fixedChain k)).length == 5
#guard leaks legacyLoopChain Kind.linkage == true
#guard leaks fixedLoopChain Kind.linkage == false
#guard leaks legacyInitChain Kind.linkage == true
#guard leaks fixedInitChain Kind.linkage == false
#guard everyCaughtFailureIsLogged fixedLoopChain == true
#guard everyCaughtFailureIsLogged silentChain == false
#guard isFailure Kind.linkage == true
#guard isFailure Kind.interrupted == false
#guard (allKinds.filter (fun k => !isFailure k)).length == 1
-- the two CP76 measurements, pinned at the start count that was actually run
#guard leakedAfter legacyLoopChain Kind.linkage 9 == 9
#guard leakedAfter fixedLoopChain Kind.linkage 9 == 0
#guard leakedAfter legacyInitChain Kind.linkage 9 == 9
#guard leakedAfter fixedInitChain Kind.linkage 9 == 0
-- and the outage's own 18-for-18, so the corpus holds both points
#guard leakedAfter legacyLoopChain Kind.linkage 18 == 18
#guard leakedAfter fixedLoopChain Kind.linkage 18 == 0

end SilentError
end CtbrecSpec
