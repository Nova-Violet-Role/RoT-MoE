/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — MyFreeCams websocket reconnection

Subject: `src/common/ctbrec/sites/mfc/MyFreeCamsClient.java:89-132`, which produced
**1536** `ERROR ... MFC websocket failure` entries with full stack traces in
`ctbrec.log` between 2026-07-22 and 2026-07-30 — the largest single block in the file.
Every one of them is `java.net.SocketTimeoutException: Connect timed out`.

As shipped:

```java
String server = websocketServers.get(this.rng.nextInt(websocketServers.size() - 1));  // :101
String wsUrl = "wss://" + server + ".myfreecams.com/fcsl";                            // :102
Thread watchDog = new Thread(() -> {
   while (this.running) {
      if (this.ws == null && !this.connecting) {
         Request req = new Builder().url(wsUrl)...build();     // :109-113  same wsUrl forever
         this.ws = this.createWebSocket(req);
      }
      Thread.sleep(10000L);                                     // :118  fixed, uncapped, forever
   }
});
```

Three defects, each modelled and proved below.

**1. The last server can never be chosen.** `Random.nextInt(bound)` returns a value in
`[0, bound)`, so `nextInt(size - 1)` draws from `[0, size-1)` and index `size-1` is
unreachable. With exactly one configured server `nextInt(0)` throws
`IllegalArgumentException: bound must be positive` — the client cannot start at all.

**2. The server is chosen once, outside the loop.** `wsUrl` is computed at `:102` and
every retry for the lifetime of the process targets that same host. If it is the
unreachable one, the client retries a dead address every 10 seconds forever. The log
bears this out: 8 days of failures against `wchat19`, then `wchat40`.

**3. Fixed 10-second retry, logged at ERROR with a stack trace each time.** No backoff,
no cap, no suppression — 1536 stack traces, one every 10 s, drowning every other
diagnostic in the file.

The fortifications are proved to be **fortifications and not amputations**: the client
must keep retrying forever (`backoff_le_cap` bounds every wait, so retries never stop),
must still be able to reach every server (`fortified_reaches_every_server`), and must
never go completely silent (`first_failure_always_logged`).
-/

namespace CtbrecSpec

/-! ## 1. Server selection -/

/-- The exclusive bound the shipped code passes to `Random.nextInt`, for a list of
`n` servers: `websocketServers.size() - 1`. -/
def legacyBound (n : Nat) : Nat := n - 1

/-- The fortified bound: the whole list. -/
def fortifiedBound (n : Nat) : Nat := n

/-- The indices `Random.nextInt(bound)` can actually produce. -/
def reachable (bound : Nat) : List Nat := List.range bound

/-- **The last server is unreachable under the shipped bound.** Stated for every `n`,
not for the particular server count of the day.

Written first with a `0 < n` hypothesis; the unused-variable linter showed the proof
never used it, so it was removed. The statement is true for `n = 0` as well, where the
reachable set is empty. Reported rather than left in: a hypothesis a proof does not
need is an over-assumption, and carrying it would have understated the defect. -/
theorem legacy_misses_last_server (n : Nat) :
    (n - 1) ∉ reachable (legacyBound n) := by
  simp [reachable, legacyBound]

/-- **The fortified bound reaches every server**, including the last. -/
theorem fortified_reaches_every_server (n i : Nat) (h : i < n) :
    i ∈ reachable (fortifiedBound n) := by
  simp [reachable, fortifiedBound, h]

/-- `Random.nextInt` requires a strictly positive bound. -/
def validBound (b : Nat) : Prop := 0 < b

instance (b : Nat) : Decidable (validBound b) := by unfold validBound; infer_instance

/-- **With a single configured server the shipped code throws.** `nextInt(0)` is
`IllegalArgumentException: bound must be positive`, so the client never starts. -/
theorem legacy_bound_invalid_for_single_server : ¬ validBound (legacyBound 1) := by decide

/-- The fortified bound is valid whenever there is at least one server — which is the
only precondition a caller can reasonably be asked for. -/
theorem fortified_bound_valid (n : Nat) (h : 0 < n) : validBound (fortifiedBound n) := h

/-- And the shipped bound is short by exactly one, for every non-empty list. -/
theorem legacy_bound_is_short (n : Nat) (h : 0 < n) :
    legacyBound n + 1 = fortifiedBound n := by
  simp [legacyBound, fortifiedBound]; omega

/-! ## 2. Retry backoff

`base` and `cap` are milliseconds. The shipped behaviour is the special case
`cap = base`, which collapses to the constant 10 000 ms. -/

/-- Exponential backoff, capped. `k` is the number of consecutive failures so far. -/
def backoff (base cap : Nat) (k : Nat) : Nat := min cap (base * 2 ^ k)

/-- **Retries never stop.** Every wait is bounded by `cap`, so the client keeps trying
indefinitely instead of drifting into an unbounded sleep. This is the theorem that
prevents the "fortification" from becoming a quiet give-up. -/
theorem backoff_le_cap (base cap k : Nat) : backoff base cap k ≤ cap :=
  Nat.min_le_left _ _

/-- **No retry is faster than the shipped one.** Given a cap at least as large as the
base, every wait is at least `base` — so the fortified client never hammers the server
harder than the shipped client did. -/
theorem backoff_ge_base (base cap k : Nat) (h : base ≤ cap) : base ≤ backoff base cap k :=
  Nat.le_min.mpr ⟨h, Nat.le_mul_of_pos_right base (Nat.two_pow_pos k)⟩

/-- The wait grows with consecutive failures. -/
theorem backoff_monotone (base cap k : Nat) : backoff base cap k ≤ backoff base cap (k + 1) := by
  simp only [backoff]
  refine Nat.le_min.mpr ⟨Nat.min_le_left _ _, ?_⟩
  refine Nat.le_trans (Nat.min_le_right _ _) ?_
  exact Nat.mul_le_mul_left base (Nat.pow_le_pow_right (by decide) (Nat.le_succ k))

/-- The shipped policy is exactly `cap = base`: a constant. Recorded as a theorem so
the model is pinned to the real code rather than to a description of it. -/
theorem legacy_is_constant (base k : Nat) : backoff base base k = base :=
  Nat.min_eq_left (Nat.le_mul_of_pos_right base (Nat.two_pow_pos k))

/-- Total time elapsed after `k` retries under the shipped fixed-period policy. -/
def elapsedLegacy (period k : Nat) : Nat := period * k

/-- Total time elapsed after `k` retries under capped exponential backoff. -/
def elapsedFortified (base cap : Nat) : Nat → Nat
  | 0 => 0
  | k + 1 => elapsedFortified base cap k + backoff base cap k

/-- **The load claim, proved.** After the same number of attempts the fortified client
has always waited at least as long — so in any fixed window it makes no more attempts,
and therefore writes no more error lines, than the shipped client. -/
theorem fortified_makes_no_more_attempts (base cap : Nat) (h : base ≤ cap) :
    ∀ k, elapsedLegacy base k ≤ elapsedFortified base cap k
  | 0 => by simp [elapsedLegacy, elapsedFortified]
  | k + 1 => by
    have ih := fortified_makes_no_more_attempts base cap h k
    have hb := backoff_ge_base base cap k h
    have hs : base * (k + 1) = base * k + base := Nat.mul_succ base k
    simp only [elapsedLegacy, elapsedFortified] at ih ⊢
    rw [hs]
    omega

/-! ## 3. Failure logging

A stack trace per failure gave 1536 of them. Suppression must not become silence: the
first failure is always reported, and one in every `every` after that. -/

/-- Whether failure number `k` (zero-based, consecutive) is written to the log. -/
def shouldLog (every : Nat) (k : Nat) : Bool := k == 0 || (every != 0 && k % every == 0)

/-- **Never silent.** The very first failure of a run is always logged, whatever the
suppression interval — including a misconfigured interval of zero. -/
theorem first_failure_always_logged (every : Nat) : shouldLog every 0 = true := by
  simp [shouldLog]

/-- A suppression interval of zero degrades to "log only the first", never to a crash
or to logging nothing. -/
theorem zero_interval_logs_only_first (k : Nat) (h : 0 < k) : shouldLog 0 k = false := by
  simp [shouldLog]
  omega

/-- Every `every`-th failure is still reported, so a persistent outage keeps producing
evidence at a predictable rate rather than disappearing from the log. -/
theorem periodic_failures_still_logged (every m : Nat) (h : 0 < every) :
    shouldLog every (every * m) = true := by
  simp [shouldLog, Nat.mul_mod_right]
  omega

/-- The shipped behaviour is `every = 1`: log everything. Pinned so the comparison is
against the real code. -/
theorem legacy_logs_every_failure (k : Nat) : shouldLog 1 k = true := by
  simp [shouldLog, Nat.mod_one]

/-! ## Executable checks — the concrete policy this ships with

base 10 s (the shipped period, so no retry is ever faster), cap 5 min, log 1 in 30. -/

def policyBase : Nat := 10000
def policyCap : Nat := 300000
def policyLogEvery : Nat := 30

#guard backoff policyBase policyCap 0 == 10000
#guard backoff policyBase policyCap 1 == 20000
#guard backoff policyBase policyCap 4 == 160000
#guard backoff policyBase policyCap 5 == 300000   -- capped from here on
#guard backoff policyBase policyCap 50 == 300000  -- still capped, still retrying
#guard shouldLog policyLogEvery 0 == true
#guard shouldLog policyLogEvery 1 == false
#guard shouldLog policyLogEvery 30 == true
#guard legacyBound 1 == 0        -- the crash
#guard legacyBound 5 == 4        -- index 4 unreachable out of 0..4
#guard fortifiedBound 5 == 5

/-- Over the 8-day window in `ctbrec.log` the shipped policy attempted a reconnect
every 10 s. Under the fortified policy the wait saturates at 5 minutes, so a
persistent outage costs 30× fewer attempts and 30× fewer log lines once saturated —
while still retrying forever. -/
theorem saturated_wait_is_thirty_times_the_period :
    backoff policyBase policyCap 5 = 30 * policyBase := by decide

end CtbrecSpec
