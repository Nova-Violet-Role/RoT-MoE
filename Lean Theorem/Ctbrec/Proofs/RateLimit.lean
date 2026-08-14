/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CP81 -- the request pacing is PER-PERMIT, and the repair is stated before it is written.

WHAT WAS MEASURED
-----------------
`tools/ThrottleRate.java` drives the deployed `ChaturbateHttpClient.acquireSlot()` and
`releaseSlot()` reflectively -- the real methods, not a re-implementation, because a
re-implementation would measure my reading of the code instead of the code. Against the
operator's own settings (`chaturbateMsBetweenRequests = 1000`, `chaturbateMaxConcurrentRequests
= 2`):

    emitted 12 requests in 5339 ms
    first inter-emission gaps (ms): 0 1051 0 1063 0 1059 0 1055 0 1062 0
    worst burst: 2 requests inside one 1000 ms window
    sustained rate: 2.25 req/s   (the setting names 1.00)

Requests leave in simultaneous PAIRS. `ChaturbateHttpClient.java:293-301` computes the gap AFTER
the permit is taken, from one shared `lastRequest`, so every permit holder clears the same check
against the same timestamp and they all wake together.

THE CORRECTION THIS FILE ALSO RECORDS
-------------------------------------
`NEXT-76` asserted the semaphore "bounds how many requests are in flight, never how many per
second", and that ctbrec therefore had no rate limiter. That was wrong: `chaturbateMsBetweenRequests`
IS a rate mechanism. The defect is narrower and more interesting -- the mechanism exists and is
applied per permit rather than globally, so the emitted rate is `permits` times the configured
one. Reading the source before writing the fix is what caught it.

WHAT IS PROVED HERE, AND WHAT IS NOT
------------------------------------
Proved: the arithmetic of the two schemes, that the repaired bound does not depend on the permit
count, that it cannot deadlock, and that at one permit the two schemes coincide (so the fix is a
refinement, not a behaviour change for the default configuration).

NOT proved, and not claimed: that any particular rate avoids an HTTP 429. That is the remote
server's policy, it is not observable from here, and no theorem in this file pretends otherwise.
-/

namespace CtbrecSpec.RateLimit

/--
How many pacing instants fall inside a half-open window of `window` ms when one instant occurs
every `pause` ms -- that is `⌈window / pause⌉`, written so it is decidable on `Nat`.
-/
def instants (pause window : Nat) : Nat :=
  if pause = 0 then window else (window + pause - 1) / pause

/--
The deployed scheme. Every one of the `permits` holders passes the same gap check against the
same `lastRequest`, so a whole permit-count leaves at each pacing instant.
-/
def legacyEmissions (permits pause window : Nat) : Nat :=
  permits * instants pause window

/--
The repaired scheme: the pacing instant is claimed once, globally, before anyone sleeps. The
permit count is deliberately an argument that the body ignores -- that independence is the whole
point of the repair, and `the_fixed_bound_ignores_the_permit_count` is what pins it.
-/
def fixedEmissions (_permits pause window : Nat) : Nat :=
  instants pause window

/-!
## The theorems are stated over INTERVAL COUNTS, not milliseconds

`instants` divides by a variable, and that is exactly where `omega` stops. Rather than lean on a
division lemma whose name changes between toolchains, the invariants below quantify over `n`, the
number of pacing instants inside the window -- which is the quantity the schemes actually differ
on. The millisecond arithmetic is pinned separately by `#guard`, where the literals make every
division decidable. Nothing is weakened by the split: `emissions … = perInstant … (instants …)`
is definitional, and `the_ms_model_is_the_interval_model` proves it.
-/

/-- The legacy scheme emits a whole permit-count at each of `n` pacing instants. -/
def legacyPerInstant (permits n : Nat) : Nat := permits * n

/-- The repaired scheme emits one request per instant, whatever the permit count. -/
def fixedPerInstant (_permits n : Nat) : Nat := n

/-- The two models are the same object; the ms form is the interval form applied to `instants`. -/
theorem the_ms_model_is_the_interval_model (permits pause window : Nat) :
    legacyEmissions permits pause window
      = legacyPerInstant permits (instants pause window) ∧
    fixedEmissions permits pause window
      = fixedPerInstant permits (instants pause window) := by
  exact ⟨rfl, rfl⟩

/-! ## The defect, stated exactly -/

/-- The emitted rate is the permit count times the configured one. -/
theorem the_legacy_rate_is_the_permit_count_times_the_intended_one (permits n : Nat) :
    legacyPerInstant permits n = permits * fixedPerInstant permits n := by
  rfl

/-- More concurrency means more emissions under the legacy scheme. -/
theorem the_legacy_bound_grows_with_the_permit_count (p q n : Nat) (h : p ≤ q) :
    legacyPerInstant p n ≤ legacyPerInstant q n := by
  unfold legacyPerInstant
  exact Nat.mul_le_mul_right _ h

/--
The honest danger, on the record: the legacy bound is unbounded in the permit count. For any
target `m` there is a configuration emitting at least `m` requests inside a SINGLE pacing
instant, so raising `chaturbateMaxConcurrentRequests` silently raises the emitted RATE.
-/
theorem the_legacy_bound_is_unbounded_in_the_permit_count (m : Nat) :
    ∃ permits, m ≤ legacyPerInstant permits 1 := by
  refine ⟨m, ?_⟩
  unfold legacyPerInstant
  omega

/-! ## The repair -/

/--
**The durable invariant.** The repaired bound does not depend on the permit count at all, so an
operator who raises concurrency for throughput cannot thereby raise the request RATE. Stated over
two arbitrary permit counts, never over the 2 that happens to be configured today.
-/
theorem the_fixed_bound_ignores_the_permit_count (p q n : Nat) :
    fixedPerInstant p n = fixedPerInstant q n := by
  rfl

/-- Raising concurrency can never raise the repaired bound. -/
theorem raising_concurrency_cannot_raise_the_fixed_bound (p q n : Nat) (_h : p ≤ q) :
    fixedPerInstant q n ≤ fixedPerInstant p n := by
  exact Nat.le_of_eq (the_fixed_bound_ignores_the_permit_count q p n)

/-- Inside one pacing interval the repaired scheme emits at most one request. -/
theorem the_fixed_scheme_emits_at_most_one_per_interval (permits : Nat) :
    fixedPerInstant permits 1 ≤ 1 := by
  unfold fixedPerInstant
  omega

/--
**Anti-disarm.** At a single permit the two schemes are identical, so the repair changes nothing
for the default configuration -- it is a refinement, not a behaviour change.
-/
theorem with_a_single_permit_the_two_schemes_agree (n : Nat) :
    legacyPerInstant 1 n = fixedPerInstant 1 n := by
  unfold legacyPerInstant fixedPerInstant
  omega

/--
**No deadlock.** Some emission is always allowed in a non-empty span. A limiter that could reach
zero would stop the application dead -- the same shape as `permits_is_always_positive` on the
semaphore.
-/
theorem at_least_one_emission_is_always_allowed (permits n : Nat) (hn : 0 < n) :
    1 ≤ fixedPerInstant permits n := by
  unfold fixedPerInstant
  omega

/-- The repair never emits more than today: it cannot make the 429 pressure worse. -/
theorem the_repair_never_emits_more_than_today (permits n : Nat) (hperm : 0 < permits) :
    fixedPerInstant permits n ≤ legacyPerInstant permits n := by
  unfold fixedPerInstant legacyPerInstant
  exact Nat.le_mul_of_pos_left _ hperm

/-! ## The measured run, replayed -/

-- 12 emissions were counted in 5339 ms at 2 permits and 1000 ms pacing.
#guard legacyEmissions 2 1000 5339 == 12
-- The repaired scheme would have emitted 6 in that span: the configured 1 per second.
#guard fixedEmissions 2 1000 5339 == 6
-- The measured worst burst: 2 inside a single 1000 ms window.
#guard legacyEmissions 2 1000 1000 == 2
#guard fixedEmissions 2 1000 1000 == 1
-- The shipped default pacing of 3000 ms, at which the first measurement was taken.
#guard legacyEmissions 2 3000 3000 == 2
#guard fixedEmissions 2 3000 3000 == 1
-- At one permit the two agree.
#guard legacyEmissions 1 1000 5339 == fixedEmissions 1 1000 5339
#guard legacyEmissions 1 3000 100 == fixedEmissions 1 3000 100
-- Raising concurrency to 8 emits 8 per window under the legacy scheme, 1 under the repair.
#guard legacyEmissions 8 1000 1000 == 8
#guard fixedEmissions 8 1000 1000 == 1
-- A zero-length window emits nothing, and nothing divides by zero.
#guard fixedEmissions 2 1000 0 == 0
#guard fixedEmissions 2 0 250 == 250
-- One pacing interval is exactly one instant, at both configured pauses.
#guard instants 1000 1000 == 1
#guard instants 3000 3000 == 1

end CtbrecSpec.RateLimit
