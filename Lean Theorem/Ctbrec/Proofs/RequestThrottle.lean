/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the request throttle is operator-configurable, floored at 1, NEVER capped above

Subject: `ChaturbateHttpClient.requestThrottle` (`.../sites/chaturbate/ChaturbateHttpClient.java`)
and the new setting `Settings.chaturbateMaxConcurrentRequests`.

## Why

The throttle was `new Semaphore(2, true)` — a hard-coded 2 concurrent requests to chaturbate.com,
`static`, so shared JVM-wide across every user of a self-hosted server instance. That was added to
stop retry-storm hammering, but for multi-user localhost hosting it caps total throughput at 2, which
dilutes the performance the app had before the throttle existed.

The fix makes the permit count come from a setting:
```java
int configured = Config.getInstance().getSettings().chaturbateMaxConcurrentRequests; // default 2
int permits    = configured < 1 ? 1 : configured;   // lower bound only; NO upper cap
new Semaphore(permits, true);
```

Two properties the operator needs and this file proves:
1. **Default 2 preserves today's behaviour** — nobody who never touches the setting sees a change.
2. **No artificial ceiling** — whatever the operator sets (≥1) is the permit count *exactly*, so
   raising it genuinely raises throughput and never re-introduces the dilution.
The only clamp is a **floor of 1**: a `Semaphore(0)` would wedge every request forever, so a `0` or
negative setting is treated as 1 rather than deadlocking the client. That floor is a safety bound,
not a cap — it never *reduces* a value the operator chose.
-/

namespace CtbrecSpec

/-- The permit count actually handed to the `Semaphore`, from the configured setting. The only
adjustment is the floor of 1; there is deliberately no upper clamp. -/
def permits (configured : Nat) : Nat :=
  if configured = 0 then 1 else configured

/-! ### The setting is honoured -/

/-- **Default 2 reproduces the shipped behaviour.** Anyone who never edits the setting keeps the old
two-permit throttle. -/
theorem permits_default : permits 2 = 2 := by decide

/-- **No artificial ceiling: any operator value ≥ 1 is honoured exactly.** This is the "don't cap it"
property — the permit count equals the chosen value, so raising the setting raises throughput with no
hidden maximum. -/
theorem permits_honours_the_operator (n : Nat) (h : 1 ≤ n) : permits n = n := by
  unfold permits; split <;> omega

/-- Stated as an unbounded fact: there is no `N` past which `permits` stops growing — for arbitrarily
large inputs the output is the input. -/
theorem permits_is_uncapped (n : Nat) : permits (n + 1) = n + 1 := by
  unfold permits; split <;> omega

/-! ### The safety floor -/

/-- **A zero setting is floored to 1, never 0.** A `Semaphore(0, true)` would block every request
forever; the floor turns a misconfiguration into "serialised", not "deadlocked". -/
theorem permits_floors_zero : permits 0 = 1 := by decide

/-- **The permit count is always at least 1** — the throttle can never deadlock the client, whatever
the setting. -/
theorem permits_is_always_positive (configured : Nat) : 1 ≤ permits configured := by
  unfold permits; split <;> omega

/-! ### Anti-dilution — raising the setting never lowers capacity -/

/-- **Monotone: a larger setting never yields fewer permits.** This is the guarantee that turning the
knob up cannot dilute throughput — the exact failure the hard-coded 2 caused. -/
theorem permits_is_monotone (a b : Nat) (h : a ≤ b) : permits a ≤ permits b := by
  unfold permits; split <;> split <;> omega

/-- **Anti-amputation: the knob actually moves.** `permits` is not a constant dressed up as a
setting — a higher configured value gives strictly more permits. A rule that always returned 2 would
satisfy `permits_default` and prove nothing about configurability. -/
theorem the_knob_is_not_constant : ∃ a b, permits a < permits b :=
  ⟨1, 5, by decide⟩

/-! ### The bound the semaphore enforces

A fair `Semaphore(permits)` admits a request only when a slot is free, so the number in flight never
exceeds `permits`. This models that: acquisition is allowed only when `inFlight < permits`, and then
the bound `inFlight + 1 ≤ permits` still holds. -/

/-- Whether a new request may take a slot right now. -/
def canAcquire (inFlight permits : Nat) : Bool := inFlight < permits

/-- **Acquiring only when a slot is free keeps in-flight ≤ permits.** The concurrency bound the
throttle exists to enforce is preserved for any permit count, including a raised one. -/
theorem acquire_preserves_the_bound (inFlight permitCount : Nat)
    (h : canAcquire inFlight permitCount = true) : inFlight + 1 ≤ permitCount := by
  unfold canAcquire at h
  simp at h
  omega

/-- **At the default of 2, at most 2 requests are ever in flight** — the concrete instance of the
bound, matching the shipped throttle. -/
theorem default_admits_at_most_two (inFlight : Nat)
    (h : canAcquire inFlight (permits 2) = true) : inFlight + 1 ≤ 2 := by
  rw [permits_default] at h
  exact acquire_preserves_the_bound inFlight 2 h

#guard permits 2 == 2
#guard permits 0 == 1
#guard permits 1 == 1
#guard permits 100 == 100
#guard permits 10000 == 10000
#guard decide (1 ≤ permits 0)
#guard canAcquire 1 2
#guard !canAcquire 2 2
#guard !canAcquire 5 (permits 0)

end CtbrecSpec
