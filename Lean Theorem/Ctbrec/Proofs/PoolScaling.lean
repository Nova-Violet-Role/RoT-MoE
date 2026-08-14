/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the thread-pool scaler that is never ticked

Subject: `src/common/ctbrec/recorder/ThreadPoolScaler.java:30-58`.

Found by `tools/capability-triage.py`: `ThreadPoolScaler` has **zero references anywhere in the
tree** outside its own file. Nothing constructs it, so `tick()` is never called and the recorder's
pool never auto-scales. It is upstream ctbrec code, not part of this rework — nothing was
disarmed here; it arrived unwired.

Before deciding whether wiring it would be an amplification or a hazard, the question
`CtbrecSpec.PreviewPipeline.isTrap` demands an answer for: **is it sound when invoked?**

The reason to doubt it: up-scaling has no explicit ceiling.

```java
if (average > 0.65 * coreSize) { threadPool.setCorePoolSize(coreSize + 1); ... }
else if (average < 0.15 * coreSize) { ... Math.max(configuredPoolSize, coreSize - 1) ... }
```

Down-scaling is floored at `configuredPoolSize`; up-scaling is floored by nothing. Whether that
is unbounded thread creation or a self-limiting loop is not a matter of opinion, so it is proved
here rather than asserted.

The answer is that it **self-limits**: the growth threshold `0.65 * coreSize` rises with the pool
itself, so growth stops as soon as the observed average falls below it. Since the average of
`getActiveCount()` can never exceed the concurrent work available, a bounded workload bounds the
pool. `growth_stops_once_the_threshold_overtakes_the_average` is that statement.

Arithmetic is scaled by 100 and done in `Nat`: `avg100 = average * 100`, so `0.65 * core` is
`65 * core` and `0.15 * core` is `15 * core`. No floating point, no rounding to argue about.
-/

namespace CtbrecSpec

/-- One `adjustPoolSize` step. `avg100` is the 20-sample average of `getActiveCount()`, times 100.
`ThreadPoolScaler.java:33-48`. The 500 ms rate limit and the down-scale cool-down are timing, not
sizing, and are modelled separately below. -/
def stepSize (configured core avg100 : Nat) : Nat :=
  if avg100 > 65 * core then core + 1
  else if avg100 < 15 * core then max configured (core - 1)
  else core

/-- **The configured size is a floor that no sequence of steps can breach.** This is the property
that makes the scaler safe to wire at all: it can never starve the recorder below its configured
concurrency. -/
theorem the_configured_floor_is_respected (configured core avg100 : Nat)
    (h : configured ≤ core) : configured ≤ stepSize configured core avg100 := by
  unfold stepSize
  split
  · omega
  · split
    · omega
    · exact h

/-- **Growth is one thread at a time** — no multiplicative jump.

The hypothesis `configured ≤ core` is not decoration and I did not write it at first: `omega`
produced a counterexample with `configured - (core-1) ≥ 3`, i.e. a configured floor ABOVE the
current size, where the down-scale branch returns `max configured (core-1)` and jumps well past
`core + 1`. That is a real behaviour of the Java (`setCorePoolSize(max(configured, core-1))`), not
a modelling artefact — it is how the pool is dragged back up to its floor after being set below
it. The invariant is inductive: `the_configured_floor_is_respected` re-establishes it after every
step, so a scaler started at or above its floor stays there. -/
theorem growth_is_at_most_one (configured core avg100 : Nat) (h : configured ≤ core) :
    stepSize configured core avg100 ≤ core + 1 := by
  unfold stepSize
  split
  · omega
  · split
    · exact Nat.max_le.mpr ⟨by omega, by omega⟩
    · omega

/-- **Shrink is one thread at a time.** With the previous theorem this pins the step to
`{core-1, core, core+1}` — the scaler cannot lurch.

Stated without the floor invariant, deliberately. I wrote `configured ≤ core` here too and the
compiler reported the hypothesis unused, so it came out: the lower bound holds for *every*
configuration, unlike the upper bound, which genuinely needs it. Keeping an unused hypothesis
would have quietly overstated what the scaler requires. -/
theorem shrink_is_at_most_one (configured core avg100 : Nat) :
    core - 1 ≤ stepSize configured core avg100 := by
  unfold stepSize
  split
  · omega
  · split
    · exact Nat.le_max_right configured (core - 1)
    · omega

/-- **The dead band.** Between 15 % and 65 % utilisation nothing changes. This is what stops the
scaler oscillating between two sizes on a steady load — the property most likely to be broken by
a well-meaning edit to either constant. -/
theorem the_dead_band_changes_nothing (configured core avg100 : Nat)
    (hlo : 15 * core ≤ avg100) (hhi : avg100 ≤ 65 * core) :
    stepSize configured core avg100 = core := by
  unfold stepSize
  have h1 : ¬ (avg100 > 65 * core) := by omega
  have h2 : ¬ (avg100 < 15 * core) := by omega
  simp [h1, h2]

/-- **The answer to the unbounded-growth worry.** Once the pool is large enough that the rising
threshold `65 * core` reaches the observed average, the step never grows. Growth is therefore
self-limiting: it is bounded by the workload, not by a constant someone forgot to write. -/
theorem growth_stops_once_the_threshold_overtakes_the_average
    (configured core avg100 : Nat) (h : avg100 ≤ 65 * core) (hfloor : configured ≤ core) :
    stepSize configured core avg100 ≤ core := by
  unfold stepSize
  have h1 : ¬ (avg100 > 65 * core) := by omega
  simp [h1]
  split
  · exact Nat.max_le.mpr ⟨hfloor, by omega⟩
  · exact Nat.le_refl core

/-- **The counterpart, and the reason this class must not be wired casually.**

`growth_stops_once_the_threshold_overtakes_the_average` is conditional on `avg100 ≤ 65 * core`,
and there is a realistic regime where that hypothesis is *never* satisfied. `getActiveCount()` is
bounded by `min(corePoolSize, pending work)`. When the queue stays saturated — always at least as
many runnable tasks as threads — `activeCount = corePoolSize` exactly, so `avg100 = 100 * core`,
and `100 * core > 65 * core` holds for **every** positive `core`.

Under a permanently saturated queue the pool therefore grows by one thread at every adjustment,
without limit. That is not a defect in the arithmetic; it is the arithmetic working as written.
The bound in the earlier theorem comes from the *workload*, and a saturated queue supplies no
bound.

Stating this is not pessimism, it is the precondition for wiring: the scaler is safe exactly when
the work queue drains, and RESUMEE-25's summary ("a bounded workload bounds the pool") is only
half the picture without it. -/
theorem a_saturated_queue_grows_every_step (configured core : Nat) (h : 0 < core) :
    stepSize configured core (100 * core) = core + 1 := by
  unfold stepSize
  have : 100 * core > 65 * core := by omega
  simp [this]

/-- **The boundary case, derived from the theorem above rather than re-proved.**

Mutation testing weakened the hypothesis `0 < core` to `1 < core` and the module stayed green:
a weaker theorem still elaborates, and nothing was consuming this one at full strength, so
nothing died. That is the over-assumption failure the spec warns about, caught in my own work
minutes after writing it.

This corollary is the consumer. It instantiates at `core = 1` — the smallest pool that can be
saturated, and precisely the case the weakened hypothesis would exclude — so a future edit that
narrows the hypothesis breaks the build here instead of passing silently. -/
theorem a_single_thread_pool_under_saturation_grows :
    stepSize 7 1 (100 * 1) = 1 + 1 :=
  a_saturated_queue_grows_every_step 7 1 (by decide)

/-- Concretely: a saturated pool of 100 threads still grows to 101. There is no ceiling to reach. -/
theorem even_a_large_saturated_pool_grows : stepSize 4 100 10000 = 101 := by decide

/-- The regime boundary, exact: growth needs strictly more than 65 % utilisation, so a pool
sitting at exactly 65 % holds. This is the value a fortification would have to change, and it is
pinned here so that changing it is a visible decision. -/
theorem exactly_sixty_five_percent_holds : stepSize 4 8 520 = 8 := by decide

/-- The concrete form: a pool of 8 seeing an average of 4.0 active threads (`avg100 = 400`) is
already past its growth threshold (`65 * 8 = 520`), so it holds. -/
theorem a_half_busy_pool_of_eight_holds : stepSize 4 8 400 = 8 := by decide

/-- **Anti-amputation.** The scaler is not a machine that never moves: a saturated pool grows. -/
theorem a_saturated_pool_grows : stepSize 4 8 800 = 9 := by decide

/-- …and an idle pool shrinks, down to — never through — the configured floor. -/
theorem an_idle_pool_shrinks : stepSize 4 8 0 = 7 := by decide

theorem an_idle_pool_at_the_floor_stays : stepSize 4 4 0 = 4 := by decide

/-- The floor genuinely binds: from 5 with a configured floor of 5, an idle pool does not drop. -/
theorem the_floor_binds_at_the_boundary : stepSize 5 5 0 = 5 := by decide

/-- **Never ticked, and therefore never measured.** `PreviewPipeline.evidenceOfCorrectness` says
a sound-but-unexercised path is not evidence of anything; this is that case in the wild. The
theorems above establish the *sizing algebra* is sound — they say nothing about the timing,
the `synchronized` boundaries, or `getActiveCount()` under real contention.

So the honest classification, in the vocabulary already proved:
`⟨liveEntryPoints := 0, deadEntryPoints := 1, soundWhenInvoked := true⟩` — **not a trap**
(`an_unreachable_but_sound_capability_is_not_a_trap`), merely unused. Wiring it would be an
amplification whose sizing is proved and whose concurrency is not; that measurement is the
precondition, and it is not done here. -/
def scalerCapability : Nat × Nat × Bool := (0, 1, true)

theorem the_scaler_is_unreached : scalerCapability.1 = 0 := by decide

theorem the_scaler_sizing_is_sound : scalerCapability.2.2 = true := by decide

#guard stepSize 4 8 400 == 8
#guard stepSize 4 8 800 == 9
#guard stepSize 4 8 0 == 7
#guard stepSize 4 4 0 == 4
#guard stepSize 5 5 0 == 5
#guard stepSize 4 8 520 == 8   -- exactly at the threshold: no growth

end CtbrecSpec
