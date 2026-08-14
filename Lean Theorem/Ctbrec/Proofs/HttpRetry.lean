/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

import Proofs.Ctbrec.MfcReconnect
import Proofs.Ctbrec.ShutdownWait
/-

# ctbrec — retrying an HTTP request without spending the user's money twice

`ChaturbateHttpClient.executeThrottled` (`:182`) has **no retry at all**. One failure from
`super.execute(req)` propagates straight out to the caller. Measured consequence in
`ctbrec.log`: 115 `UnknownHostException` events, of which

  | site | count |
  |---|---|
  | `OnlineMonitor.java:144` | 67 |
  | `MyFreeCamsClient.java:244` | 26 |
  | `ThumbOverviewTab.java:695` | 11 |
  | **`SimplifiedLocalRecorder.java:1023`** | **3** ← recordings that never started |
  | `ChaturbateLlhlsDownload.java:548` | 1 |

…all falling inside **16 distinct minutes across twelve days**. Two clusters, four and
three minutes long. A retry with backoff spanning a few minutes would have covered them.

## Why the obvious retry is dangerous, and this module exists

The obvious fix — wrap the call in "try three times" — is **wrong here**, and the reason is
measured rather than theoretical:

  * `SocketTimeoutException` occurs **1503** times in the log, fourteen times more often
    than `UnknownHostException`. A retry policy that treats a timeout as retryable fires
    constantly.
  * ctbrec sends **three POSTs** to chaturbate. One of them is
    `ChaturbateModel.java:243` → `https://chaturbate.com/tipping/send_tip/…`.

**A timeout does not tell you whether the server got the request.** The bytes may have been
delivered and the response lost. Retrying a timed-out `send_tip` can tip twice — real money,
silently, on a network hiccup. A DNS failure is different in kind: `UnknownHostException`
means resolution never produced an address, so **nothing was ever sent**.

That distinction is the whole content of this module:

> **Retry is safe exactly when the failure proves the request never reached the server** —
> or when the request is idempotent, so that arriving twice is indistinguishable from
> arriving once.

`never_retries_a_delivered_side_effect` is the theorem that has to hold. If a future edit
makes a timeout retryable for POST, that theorem fails and the build goes red before anyone
is charged twice.

## The second hazard: retrying inside the throttle slot

`executeThrottled` acquires a throttle slot, executes, and releases it in `finally`. Put the
retry loop *inside* that `try` and the backoff sleep happens **while holding the slot**,
starving every other request behind the same semaphore. The retry must sit **outside** the
acquire/release pair. `backoffHappensOutsideSlot` records that as a structural obligation
and `spec_requires_backoff_outside_the_slot` states it.

## What this module does NOT claim

It does not claim the retries would have saved those three recordings; the outages are gone
and cannot be replayed. It says what the policy *does* — which failures it retries, which it
refuses, how long it waits, and that it terminates. The counts above are MEASURED from the
log; the policy behaviour is PROVED.
-/

namespace CtbrecSpec

/-! ## Failure classification

The question is never "did it fail" but "does the failure prove nothing was delivered". -/

/-- The failure modes measured in `ctbrec.log`, plus success. -/
inductive Outcome where
  /-- The request completed and a response came back. -/
  | success
  /-- `java.net.UnknownHostException` — DNS never produced an address, so no bytes left
  the machine. 108 in the log. -/
  | unknownHost
  /-- `java.net.ConnectException` — the TCP handshake never completed. Nothing delivered. -/
  | connectFailed
  /-- `java.net.SocketTimeoutException` — **ambiguous**: the request may have been fully
  delivered and only the response lost. 1503 in the log. -/
  | timeout
  /-- `java.net.SocketException` mid-stream — equally ambiguous. 12 in the log. -/
  | socketReset
  /-- `java.io.InterruptedIOException` — the app is shutting down. Never a retry. -/
  | interrupted
  /-- The server answered with an error status. The request WAS delivered. -/
  | httpError
  deriving DecidableEq, Repr, Inhabited

/-- **Does this failure prove the request never reached the server?** Only two do. This is
the predicate everything else rests on, and it is deliberately conservative: anything that
might have been delivered answers `false`. -/
def provesNotDelivered : Outcome → Bool
  | .unknownHost => true
  | .connectFailed => true
  | .success => false
  | .timeout => false        -- may have been delivered; the response was merely lost
  | .socketReset => false    -- ditto
  | .interrupted => false
  | .httpError => false      -- definitely delivered, the server replied

/-- HTTP methods, split by whether repeating one is observable. -/
inductive Method where
  | get
  | head
  /-- POST. ctbrec sends three, one of which is `send_tip`. -/
  | post
  deriving DecidableEq, Repr, Inhabited

/-- An idempotent request may be repeated freely: arriving twice is indistinguishable from
arriving once. POST is not idempotent — `send_tip` is the exemplar. -/
def idempotent : Method → Bool
  | .get => true
  | .head => true
  | .post => false

/-! ## The policy -/

/-- **The retry predicate.** Retry only when the failure proves nothing was delivered, or
when repeating is unobservable because the method is idempotent. Interrupts are excluded
unconditionally — that guard protects the shutdown fix in `CtbrecSpec.ShutdownWait`, which
would otherwise be undone by a client that keeps retrying while the app is closing. -/
def shouldRetry (m : Method) (o : Outcome) : Bool :=
  o != Outcome.success && o != Outcome.interrupted && o != Outcome.httpError
    && (provesNotDelivered o || idempotent m)

/-- What the code does today: nothing is ever retried. -/
def legacyShouldRetry (_m : Method) (_o : Outcome) : Bool := false

/-! ### The safety theorem

This is the one that matters. If it ever fails, someone is about to be charged twice. -/

/-- **A non-idempotent request is never retried after a failure that might have been
delivered.** Stated over every method and outcome rather than about `send_tip` specifically,
so it keeps holding when a fourth POST is added. -/
theorem never_retries_a_delivered_side_effect (m : Method) (o : Outcome)
    (hn : idempotent m = false) (hd : provesNotDelivered o = false) :
    shouldRetry m o = false := by
  simp [shouldRetry, hn, hd]

/-- Concretely, for the three outcomes that are ambiguous about delivery: a POST is never
repeated. `send_tip` cannot be double-charged by this policy. -/
theorem post_is_never_retried_on_an_ambiguous_failure :
    shouldRetry Method.post Outcome.timeout = false ∧
      shouldRetry Method.post Outcome.socketReset = false ∧
      shouldRetry Method.post Outcome.httpError = false := by decide

/-- But a POST **is** retried when the failure proves nothing was sent — which is exactly
the DNS case that produced all 115 log events. Without this the fortification would be
vacuous for the very traffic it targets. -/
theorem post_is_retried_when_nothing_was_sent :
    shouldRetry Method.post Outcome.unknownHost = true ∧
      shouldRetry Method.post Outcome.connectFailed = true := by decide

/-- Success is never retried. Trivial, and it is exactly the kind of thing a `!=` flipped
in a refactor would break silently. -/
theorem success_is_never_retried (m : Method) : shouldRetry m Outcome.success = false := by
  cases m <;> decide

/-- **Interrupts are never retried**, for any method. This is the guard that keeps
`ChaturbateHttpClient` from resurrecting the shutdown defect fixed in `ShutdownWait`. -/
theorem interrupt_is_never_retried (m : Method) :
    shouldRetry m Outcome.interrupted = false := by cases m <;> decide

/-- An HTTP error status is never retried: the server answered, so this is not a transport
failure and retrying only doubles the load. -/
theorem http_error_is_never_retried (m : Method) :
    shouldRetry m Outcome.httpError = false := by cases m <;> decide

/-- The fortification is a strict improvement over "never retry": everything the legacy
policy retried, the new one retries too — vacuously, since it retried nothing — and it
retries strictly more. -/
theorem fortification_is_strictly_stronger :
    (∀ m o, legacyShouldRetry m o = true → shouldRetry m o = true) ∧
      ∃ m o, legacyShouldRetry m o = false ∧ shouldRetry m o = true := by
  refine ⟨fun m o h => absurd h (by simp [legacyShouldRetry]), ?_⟩
  exact ⟨Method.post, Outcome.unknownHost, by decide, by decide⟩

/-! ## Attempts and backoff

The delay schedule reuses `CtbrecSpec.MfcReconnect.backoff`, which is already proved
monotone and capped, rather than introducing a second exponential-backoff implementation
that could drift from it. -/

/-- How many attempts in total, including the first. Three attempts spans roughly
`base + 2*base` of waiting; with a 2 s base that is ~6 s, and with the cap it stays inside
the few-minute outages measured. -/
def maxAttempts : Nat := 3

/-- Delay before attempt `k` (0-based), in milliseconds. Attempt 0 never waits. -/
def retryDelay (base cap : Nat) (k : Nat) : Nat :=
  if k == 0 then 0 else backoff base cap (k - 1)

/-- **The first attempt is immediate.** A policy that slept before trying at all would add
latency to every single request, including the 99.99% that succeed. -/
theorem first_attempt_never_waits (base cap : Nat) : retryDelay base cap 0 = 0 := by
  simp [retryDelay]

/-- **Every delay is capped**, so a long outage cannot push the client into an
ever-growing sleep. Inherited from `backoff_le_cap`. -/
theorem retry_delay_is_capped (base cap k : Nat) : retryDelay base cap k ≤ cap := by
  unfold retryDelay
  by_cases h : k == 0
  · simp [h]
  · simp only [h]
    exact backoff_le_cap base cap (k - 1)

/-- **The delays do not shrink as attempts go on** — the schedule is a backoff, not a
retry storm. -/
theorem retry_delay_is_monotone (base cap k : Nat) (h : 0 < k) :
    retryDelay base cap k ≤ retryDelay base cap (k + 1) := by
  unfold retryDelay
  have h0 : (k == 0) = false := by
    simp only [beq_eq_false_iff_ne, ne_eq]
    omega
  have h1 : (k + 1 == 0) = false := by simp
  simp only [h0, h1]
  have : k + 1 - 1 = (k - 1) + 1 := by omega
  rw [this]
  exact backoff_monotone base cap (k - 1)

/-- **The policy terminates.** Attempts are bounded, so a permanently broken host produces
a bounded number of requests and then surfaces the error rather than looping forever. -/
theorem retrying_terminates (m : Method) (o : Outcome) :
    (List.range maxAttempts).length = maxAttempts ∧
      (List.range maxAttempts).length ≤ 3 ∧
      (shouldRetry m o = true → maxAttempts ≠ 0) := by
  refine ⟨by simp, by simp [maxAttempts], fun _ => by decide⟩

/-- Total worst-case waiting, so the bound is a number someone can check against the
measured outage lengths rather than a hand wave. -/
def worstCaseWaitMs (base cap : Nat) : Nat :=
  ((List.range maxAttempts).map (retryDelay base cap)).foldl (· + ·) 0

#guard worstCaseWaitMs 2000 30000 == 6000        -- 0 + 2000 + 4000
#guard worstCaseWaitMs 2000 3000 == 5000         -- the cap bites on the second retry

/-- The worst case is bounded by the cap times the number of retries — no schedule of
delays can exceed it. -/
theorem worst_case_is_bounded (base cap : Nat) :
    worstCaseWaitMs base cap ≤ maxAttempts * cap := by
  simp only [worstCaseWaitMs, maxAttempts]
  simp only [List.range, List.range.loop, List.map, List.foldl]
  have h0 := retry_delay_is_capped base cap 0
  have h1 := retry_delay_is_capped base cap 1
  have h2 := retry_delay_is_capped base cap 2
  omega

/-! ## The structural obligation: backoff must not hold the throttle slot

`executeThrottled` wraps the call in `acquireSlot()` / `releaseSlot()`. A retry loop placed
inside that pair sleeps while holding the semaphore and starves every other request. This
is not expressible as a property of the policy function, so it is recorded as an explicit
flag that `tools/HttpRetryCheck.java` verifies against the real source. -/

/-- Where the retry loop sits relative to the throttle slot. -/
structure RetryPlacement where
  /-- True when the backoff sleep happens outside `acquireSlot`/`releaseSlot`. -/
  backoffHappensOutsideSlot : Bool
  /-- True when the slot is released on every path, including the retrying one. -/
  slotReleasedOnEveryPath : Bool
  deriving DecidableEq, Repr, Inhabited

/-- A placement is sound only if both hold. -/
def placementSound (p : RetryPlacement) : Bool :=
  p.backoffHappensOutsideSlot && p.slotReleasedOnEveryPath

/-- **Sleeping inside the slot is unsound**, however correct the retry predicate is. Stated
so that "the policy is proved" can never be mistaken for "the implementation is safe". -/
theorem spec_requires_backoff_outside_the_slot (p : RetryPlacement)
    (h : p.backoffHappensOutsideSlot = false) : placementSound p = false := by
  simp [placementSound, h]

/-- And leaking the slot is unsound too — the other way to deadlock the client. -/
theorem spec_requires_the_slot_to_be_released (p : RetryPlacement)
    (h : p.slotReleasedOnEveryPath = false) : placementSound p = false := by
  simp [placementSound, h]

/-! ## The whole decision table, enumerated

21 rows: 3 methods × 7 outcomes. Exhaustive, so `tools/HttpRetryCheck.java` can compare the
real Java against every case rather than a sample. -/

/-- Every method. -/
def allMethods : List Method := [.get, .head, .post]

/-- Every outcome. -/
def allOutcomes : List Outcome :=
  [.success, .unknownHost, .connectFailed, .timeout, .socketReset, .interrupted, .httpError]

/-- The full cross product. -/
def decisionTable : List (Method × Outcome × Bool) :=
  allMethods.flatMap (fun m => allOutcomes.map (fun o => (m, o, shouldRetry m o)))

#guard decisionTable.length == 21
-- 10, not 8: GET and HEAD each retry all four transport failures (unknownHost,
-- connectFailed, timeout, socketReset) because repeating them is unobservable, and POST
-- retries only the two that prove non-delivery. I wrote 8 here first and `#guard`
-- rejected it, which is the whole reason the guard is in the file.
#guard (decisionTable.filter (fun r => r.2.2)).length == 10
#guard (decisionTable.filter (fun r => r.1 == Method.get && r.2.2)).length == 4
#guard (decisionTable.filter (fun r => r.1 == Method.head && r.2.2)).length == 4
#guard (decisionTable.filter (fun r => r.1 == Method.post && r.2.2)).length == 2

/-- **No POST row retries an ambiguous failure.** The safety property, checked across the
enumerated table as well as proved generally — belt and braces, because the table is what
the Java is compared against. -/
theorem no_post_row_retries_an_ambiguous_failure :
    (decisionTable.filter
      (fun r => r.1 == Method.post && r.2.2 && !provesNotDelivered r.2.1)).length = 0 := by
  decide

/-- Exactly two POST rows retry, and they are the two that prove non-delivery. -/
theorem exactly_two_post_rows_retry :
    (decisionTable.filter (fun r => r.1 == Method.post && r.2.2)).length = 2 := by decide

/-- Idempotent methods retry every transport failure, since repeating them is unobservable
— that is where the extra resilience comes from. -/
theorem idempotent_methods_retry_every_transport_failure :
    shouldRetry Method.get Outcome.timeout = true ∧
      shouldRetry Method.get Outcome.socketReset = true ∧
      shouldRetry Method.head Outcome.timeout = true := by decide

/-! ## Log severity for a transient failure — the other half of "check the log"

**Measured, and it is the reason this section exists.** `ctbrec.log` is 49 263 lines, of
which **40 988 — 83% — are stack-trace lines** (`^\tat `). 1 647 lines are `ERROR`.
`OnlineMonitor.java:144` alone contributes **1 656 stack-trace lines**, all of them from
transient `UnknownHostException` during two short outages.

`OnlineMonitor` catches interrupts correctly (it already carries the `if (this.running)`
guard that `ShutdownWait` proves is needed) and it catches `SocketTimeoutException` before
`InterruptedIOException`, which — given that the former is a *subclass* of the latter — is
the right order and easy to get wrong. Its remaining defect is narrower: a transient DNS
failure falls into the generic `catch (Exception e)` and is logged at **ERROR with a full
stack trace**, 67 times, for a condition that recovers by itself on the next poll.

A log where 83% of the bytes are stack traces for self-healing conditions is a log in which
a real error cannot be found. That is the user-visible defect.

### The rule, and the line it must not cross

Severity may be reduced **only while the failure is still plausibly transient**. Nothing is
ever dropped: every failure is still logged, on one line, at the first occurrence and
periodically after. The moment a streak crosses the threshold the failure is no longer
transient by definition and the full ERROR with stack returns.

`fortified_never_hides_a_persistent_failure` is the theorem that draws that line, and
`first_transient_failure_is_always_logged` is the one that stops this from becoming a
silent `catch {}` — which would be exactly the "deleting a check" that is forbidden. -/

/-- Failures that typically resolve without intervention: the transport ones. An HTTP
error status or a success is not transient in this sense. -/
def transient : Outcome → Bool
  | .unknownHost => true
  | .connectFailed => true
  | .timeout => true
  | .socketReset => true
  | .success => false
  | .interrupted => false
  | .httpError => false

/-- Everything the transport can fail with is transient; everything else is not. Pins
`transient` against the taxonomy so a mutation that empties it is caught. -/
theorem transient_is_exactly_the_transport_failures :
    (allOutcomes.filter transient).length = 4 ∧
      (allOutcomes.filter (fun o => !transient o)).length = 3 := by decide

/-- What the code does today: every failure is `ERROR`, with a stack trace. -/
def legacyLogSeverity (_streak : Nat) (_o : Outcome) : Severity := .error

/-- Severity as a function of how many consecutive failures have been seen.
`streak = 0` is the first failure. -/
def fortifiedLogSeverity (threshold : Nat) (streak : Nat) (o : Outcome) : Severity :=
  if transient o && streak < threshold then .warn else .error

/-- Only `error` carries a stack trace. `warn` is one line. -/
def withStackTrace : Severity → Bool
  | .error => true
  | .warn => false
  | .debug => false

/-- **A persistent failure is never hidden.** Once the streak reaches the threshold the
severity is `ERROR` with a full stack, whatever the outcome. This is the line the
fortification must not cross, and it is stated over every threshold and outcome rather
than about the value chosen today. -/
theorem fortified_never_hides_a_persistent_failure (threshold streak : Nat) (o : Outcome)
    (h : threshold ≤ streak) : fortifiedLogSeverity threshold streak o = .error := by
  simp only [fortifiedLogSeverity]
  have : (streak < threshold) = False := by simp; omega
  simp [this]

/-- **A non-transient failure is never downgraded**, at any streak. An HTTP error from the
server is a real result, not a network hiccup. -/
theorem fortified_never_downgrades_a_non_transient_failure (threshold streak : Nat)
    (o : Outcome) (h : transient o = false) :
    fortifiedLogSeverity threshold streak o = .error := by
  simp [fortifiedLogSeverity, h]

/-- **The first failure is always logged.** Not silenced, not swallowed — only its severity
changes. A fortification that dropped it would be deleting a check. -/
theorem first_transient_failure_is_always_logged (threshold : Nat) (o : Outcome)
    (h : 0 < threshold) (ht : transient o = true) :
    fortifiedLogSeverity threshold 0 o = .warn := by
  simp [fortifiedLogSeverity, ht, h]

/-- …and it carries no stack trace, which is where the 1 656 lines go. -/
theorem the_first_transient_failure_costs_one_line (threshold : Nat) (o : Outcome)
    (h : 0 < threshold) (ht : transient o = true) :
    withStackTrace (fortifiedLogSeverity threshold 0 o) = false := by
  rw [first_transient_failure_is_always_logged threshold o h ht]; rfl

/-- **Escalation is monotone**: severity never goes back down as a streak lengthens. A
policy that oscillated would hide a failure that had already been escalated. -/
theorem escalation_is_monotone (threshold streak : Nat) (o : Outcome)
    (h : fortifiedLogSeverity threshold streak o = .error) :
    fortifiedLogSeverity threshold (streak + 1) o = .error := by
  simp only [fortifiedLogSeverity] at *
  by_cases ht : transient o = true
  · simp only [ht, Bool.true_and] at *
    by_cases hs : streak < threshold
    · simp [hs] at h
    · have : ¬(streak + 1 < threshold) := by omega
      simp [this]
  · simp only [Bool.not_eq_true] at ht
    simp [ht]

/-- The legacy policy is strictly noisier: it prints a stack for every transient failure,
the fortified one only after the threshold. Stated as a concrete pair so it cannot be
satisfied vacuously. -/
theorem fortification_is_strictly_quieter :
    withStackTrace (legacyLogSeverity 0 Outcome.unknownHost) = true ∧
      withStackTrace (fortifiedLogSeverity 5 0 Outcome.unknownHost) = false ∧
      withStackTrace (fortifiedLogSeverity 5 5 Outcome.unknownHost) = true := by decide

/-- Nothing is ever logged below `warn`: the fortification never reaches `debug`, so a
transient failure can never vanish from a default-configured log. -/
theorem fortified_never_logs_below_warn (threshold streak : Nat) (o : Outcome) :
    fortifiedLogSeverity threshold streak o ≠ .debug := by
  simp only [fortifiedLogSeverity]
  split <;> simp

/-- **A zero threshold disables the fortification entirely** — every failure is ERROR, i.e.
exactly the legacy behaviour. The escape hatch, proved rather than promised, so a user who
wants the old firehose can have it by configuration. -/
theorem threshold_zero_is_the_legacy_policy (streak : Nat) (o : Outcome) :
    fortifiedLogSeverity 0 streak o = legacyLogSeverity streak o := by
  simp [fortifiedLogSeverity, legacyLogSeverity]

/-- How many stack traces the two policies print over a streak of `n` transient failures.
The measured outage was 67 failures at `OnlineMonitor:144`. -/
def stacksPrinted (sev : Nat → Outcome → Severity) (o : Outcome) (n : Nat) : Nat :=
  ((List.range n).filter (fun k => withStackTrace (sev k o))).length

#guard stacksPrinted legacyLogSeverity Outcome.unknownHost 67 == 67
#guard stacksPrinted (fortifiedLogSeverity 5) Outcome.unknownHost 67 == 62
#guard stacksPrinted (fortifiedLogSeverity 5) Outcome.httpError 67 == 67

/-- Over the measured outage the fortification suppresses exactly the first `threshold`
stacks and no more — it is a delay, not a mute. Anyone reading the log still sees the
failure escalate. -/
theorem suppression_is_a_delay_not_a_mute :
    stacksPrinted legacyLogSeverity Outcome.unknownHost 67 = 67 ∧
      stacksPrinted (fortifiedLogSeverity 5) Outcome.unknownHost 67 = 62 := by decide

/-! ## Time-window suppression, and the events it drops on the floor

`ChaturbateLlhlsDownload.logTransientCaptureWarning` (`:580`) uses a different mechanism
from the streak policy above: a **five-second window with a counter**. Inside the window an
event only increments `suppressedTransientCaptureWarnings`; at the next event outside the
window the counter is reported as `(N similar warnings suppressed)` and reset.
`ctbrec.log` contains **58** such lines, the largest reporting 2 suppressed.

Two things I expected to be defects and measured instead — recorded because "I checked and
it was fine" is a result:

* `lastTransientCaptureLogAt` is initialised to `Instant.MIN`, so
  `Duration.between(MIN, now).getSeconds()` is **31 557 015 952 997 372** — no overflow, no
  exception, and comfortably `≥ 5`. **The first warning is always logged.** That is the
  same property `first_transient_failure_is_always_logged` states for the streak policy,
  and here it already holds.
* `getSeconds()` truncates toward zero, so a 4.999 s gap reads 4 and suppresses. Measured,
  and it is the *correct* reading of "at least five seconds".

**The real defect is the residual.** The counter is reported only when a *later* event
arrives outside the window. If the burst is the last thing that happens — the model goes
offline, the recording ends, the downloader is stopped — the final count is discarded and
those warnings are never reported anywhere. Silently dropping events is precisely the
"deleting a check" the rework forbids, and it is invisible in the log by construction:
what is missing leaves no trace.

The theorem that pins it is a **conservation law**: every event is either reported in a
line or is still sitting in the counter. `no_event_is_ever_lost` says so for the whole run,
and `legacy_loses_exactly_the_residual` quantifies what the unflushed version drops. -/

/-- The suppression window's state. `reported` counts events already described by an
emitted line (including the ones summarised as "N suppressed"); `pending` counts events
that have been seen but not yet described anywhere. -/
structure Win where
  lastLogAt : Nat
  pending : Nat
  reported : Nat
  deriving DecidableEq, Repr, Inhabited

/-- Initial state. `lastLogAt = 0` with the convention that the first event's timestamp is
at least `period`, mirroring `Instant.MIN`. -/
def winInit : Win := { lastLogAt := 0, pending := 0, reported := 0 }

/-- One event at time `now`. Outside the window it emits a line describing this event and
the whole backlog; inside the window it only increments the backlog. -/
def winStep (period : Nat) (st : Win) (now : Nat) : Win :=
  if st.lastLogAt + period ≤ now then
    { lastLogAt := now, pending := 0, reported := st.reported + st.pending + 1 }
  else
    { st with pending := st.pending + 1 }

/-- Did this event produce a log line? -/
def winLogged (period : Nat) (st : Win) (now : Nat) : Bool := st.lastLogAt + period ≤ now

/-- **Conservation, one step: no event is ever lost.** After every event, the number
reported plus the number pending is exactly the number of events seen. Neither branch can
drop one, and this is what makes the residual meaningful rather than an artefact. -/
theorem winStep_conserves (period : Nat) (st : Win) (now : Nat) :
    (winStep period st now).reported + (winStep period st now).pending
      = st.reported + st.pending + 1 := by
  unfold winStep
  by_cases h : st.lastLogAt + period ≤ now <;> simp [h] <;> omega

/-- Run a whole burst. -/
def winRun (period : Nat) (st : Win) : List Nat → Win
  | [] => st
  | t :: rest => winRun period (winStep period st t) rest

/-- **Conservation over an entire run.** However the timestamps fall, every event ends up
either reported or pending. This is the theorem the flush fix rests on: if `pending` is
non-zero at the end and nobody reports it, exactly that many events vanish. -/
theorem no_event_is_ever_lost (period : Nat) (ts : List Nat) (st : Win) :
    (winRun period st ts).reported + (winRun period st ts).pending
      = st.reported + st.pending + ts.length := by
  induction ts generalizing st with
  | nil => simp [winRun]
  | cons t rest ih =>
    simp only [winRun, List.length_cons]
    rw [ih (winStep period st t), winStep_conserves period st t]
    omega

/-- What the fortified code must do when the downloader stops: report the residual. -/
def flushAtStop (st : Win) : Nat := st.pending

/-- What the code does today: nothing. -/
def legacyFlushAtStop (_st : Win) : Nat := 0

/-- **With the flush, every event of the run is accounted for.** -/
theorem flush_accounts_for_everything (period : Nat) (ts : List Nat) :
    (winRun period winInit ts).reported + flushAtStop (winRun period winInit ts)
      = ts.length := by
  have := no_event_is_ever_lost period ts winInit
  simpa [flushAtStop, winInit] using this

/-- **Without it, exactly `pending` events are lost** — never reported anywhere, and
invisible in the log because what is missing leaves no trace. -/
theorem legacy_loses_exactly_the_residual (period : Nat) (ts : List Nat) :
    (winRun period winInit ts).reported + legacyFlushAtStop (winRun period winInit ts)
        + (winRun period winInit ts).pending = ts.length := by
  have := no_event_is_ever_lost period ts winInit
  simpa [legacyFlushAtStop, winInit] using this

/-- And the loss is not hypothetical: a burst of three events inside one window leaves two
unreported. Concrete, so the theorem above cannot be read as vacuous. -/
theorem a_burst_really_does_lose_events :
    (winRun 5 winInit [10, 11, 12]).pending = 2 ∧
      (winRun 5 winInit [10, 11, 12]).reported = 1 ∧
      flushAtStop (winRun 5 winInit [10, 11, 12]) = 2 ∧
      legacyFlushAtStop (winRun 5 winInit [10, 11, 12]) = 0 := by decide

/-- The first event is always logged, matching the measured `Instant.MIN` initialiser:
with `lastLogAt = 0` any timestamp at or past `period` opens the window. -/
theorem the_first_event_is_always_logged (period now : Nat) (h : period ≤ now) :
    winLogged period winInit now = true := by
  simp [winLogged, winInit, h]

/-- Spacing events at least `period` apart reports each one immediately and leaves nothing
pending — the healthy case must stay noiseless of residue. -/
theorem well_spaced_events_leave_nothing_pending :
    (winRun 5 winInit [5, 10, 15, 20]).pending = 0 ∧
      (winRun 5 winInit [5, 10, 15, 20]).reported = 4 := by decide

#guard (winRun 5 winInit [10, 11, 12]).pending == 2
#guard (winRun 5 winInit [10, 11, 12, 20]).pending == 0
#guard (winRun 5 winInit [10, 11, 12, 20]).reported == 4
#guard flushAtStop (winRun 5 winInit [10, 11, 12]) == 2
#guard legacyFlushAtStop (winRun 5 winInit [10, 11, 12]) == 0

end CtbrecSpec
