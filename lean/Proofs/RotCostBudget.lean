/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-!
# The per-turn cost gate, and why it kept changing its mind

`checker/bench-router.sh` phase 2 timed twenty router invocations, took the mean,
and failed the gate if that mean exceeded `msBound = 500`. On 2026-08-11, three
consecutive runs on an otherwise unchanged tree measured

    478.3 ms   PASS
    809.6 ms   FAIL
    523.7 ms   FAIL

The router had not changed between them. A gate whose verdict is decided by what
else the machine happens to be doing is not measuring the router.

**The first hypothesis was wrong and is recorded because it was wrong.** The
obvious suspect was bash process startup — a well-known Windows tax, and the
script already subtracts it as an "honest denominator". Measured: **20.1 ms**,
about 3.5% of the total. The second suspect was `node`, which the router spawns
once to parse the hook payload. Measured: **43.8 ms** bare startup. Neither
explains half a second.

**What does explain it is the spawn count, and that quantity is deterministic.**
Every external command costs ~12 ms on this machine, and one routing decision
makes 28 of them:

    28 spawns x 12 ms = 336 ms

against a self-reported router time of 327-341 ms. The model predicts the
measurement to within 3%.

So this module fixes two things that were confused with each other:

* **the estimate** — cost is spawns times the per-spawn tax, so a *code* change
  that adds a subprocess is visible as an integer, on any machine, without a
  clock; and
* **the reading** — the wall-clock figure is kept, kept at the same bound, and
  taken as the **median of three batches** so one spike cannot decide it.

Nothing here relaxes `msBound`. It is still 500 and the gate can still fail;
`two_slow_readings_still_fail` is the proof that it can, and it is the theorem
that stops this file being a way to make a red gate green.

**This is also the answer to a documentation defect.** The README quotes four
mutually incompatible latency figures (`170-178`, `~198`, `194-256`,
`380-436 / median 398`). They were read as sloppy bookkeeping. They are not:
they are four honest samples of a high-variance, load-dependent quantity, taken
at different times on different machine states. The figures were never the
defect. Quoting a *single sample* of a noisy measurement as though it were a
constant was.
-/

namespace RotMoE.CostBudget

/-! ## The bound and the measured constants -/

/-- The per-turn bound the gate enforces, in milliseconds. Unchanged: this
module does not touch it. Mirrors `checker/bench-router.sh` phase 2. -/
def msBound : Nat := 500

/-- The measured cost of one external process spawn on the development machine,
in milliseconds. Measured by timing 40 invocations of `/usr/bin/true`. -/
def perSpawnMs : Nat := 12

/-- External processes spawned by one routing decision. Measured from `bash -x`
three times, identical every time — this is the quantity that does *not* move
with machine load. -/
def measuredSpawns : Nat := 28

/-- Estimated per-turn cost from the spawn model. -/
def estimatedMs (spawns : Nat) : Nat := spawns * perSpawnMs

/-- The largest spawn count that still fits inside the bound. **Derived from the
two declared constants**, never written as a literal — the same discipline that
`marginDivisor` enforces in `RotFamily`, and for the same reason: a frozen
literal stops tracking the thing it was derived from. -/
def spawnBudget : Nat := msBound / perSpawnMs

/-- The budget follows from the bound and the spawn tax; it is not asserted. -/
theorem the_budget_is_derived_from_the_bound : spawnBudget = 41 := by decide

/-- The router as measured is inside the budget, with room. -/
theorem the_measured_router_is_within_budget :
    measuredSpawns ≤ spawnBudget := by decide

/-- **The model predicts the measurement.** 28 spawns estimate 336 ms; the
router self-reported 327-341 ms over ten runs. Stated as the interval it landed
in rather than a point, because a point would be a fit. -/
theorem the_estimate_matches_the_self_report :
    327 ≤ estimatedMs measuredSpawns ∧ estimatedMs measuredSpawns ≤ 341 := by decide

/-- The estimate is under the bound. -/
theorem the_estimated_cost_is_under_the_bound :
    estimatedMs measuredSpawns < msBound := by decide

/-- **The budget can be exceeded** — thirteen more subprocesses and the gate
refuses. A budget nothing can violate is decoration. -/
theorem the_budget_can_be_exceeded :
    ¬ (measuredSpawns + 14 ≤ spawnBudget)
      ∧ ¬ (estimatedMs (measuredSpawns + 14) < msBound) := by decide

/-- The headroom, named: thirteen further spawns are affordable, the fourteenth
is not. Anyone adding a subprocess to the hot path can read their allowance. -/
theorem the_headroom_is_thirteen_spawns :
    (∀ k, k ≤ 13 → estimatedMs (measuredSpawns + k) < msBound)
      ∧ ¬ (estimatedMs (measuredSpawns + 14) < msBound) := by
  refine ⟨fun k hk => ?_, by decide⟩
  simp only [estimatedMs, measuredSpawns, perSpawnMs, msBound]
  omega

/-! ## The median of three, and the one property that matters

The reading is taken three times and the middle value decides. The theorems
below say exactly what that buys and — more importantly — what it does not. -/

/-- The middle of three readings. -/
def median3 (a b c : Nat) : Nat :=
  max (min a b) (min (max a b) c)

/-- The median is one of the readings, never a synthetic average. An average
would let one spike drag the verdict; this cannot. -/
theorem median3_is_one_of_the_readings (a b c : Nat) :
    median3 a b c = a ∨ median3 a b c = b ∨ median3 a b c = c := by
  simp only [median3]
  rcases Nat.le_total a b with hab | hab <;>
  rcases Nat.le_total b c with hbc | hbc <;>
  rcases Nat.le_total a c with hac | hac <;>
  simp [Nat.min_def, Nat.max_def, hab, hbc, hac] <;> omega

/-- The median lies between the extremes. -/
theorem median3_is_between (a b c : Nat) :
    min a (min b c) ≤ median3 a b c ∧ median3 a b c ≤ max a (max b c) := by
  simp only [median3]
  rcases Nat.le_total a b with hab | hab <;>
  rcases Nat.le_total b c with hbc | hbc <;>
  rcases Nat.le_total a c with hac | hac <;>
  simp [Nat.min_def, Nat.max_def, hab, hbc, hac] <;> omega

/-- **The property the repair exists for.** If two of the three readings are
under the bound, the median is under the bound — so a single load spike, however
large, cannot fail the gate on its own. -/
theorem a_single_spike_cannot_fail_the_gate (a b c : Nat)
    (ha : a < msBound) (hb : b < msBound) :
    median3 a b c < msBound := by
  have h1 : median3 a b c ≤ max a b := by
    simp only [median3]
    exact Nat.max_le.mpr
      ⟨Nat.le_trans (Nat.min_le_left a b) (Nat.le_max_left a b), Nat.min_le_left _ _⟩
  have h2 : max a b < msBound := Nat.max_lt.mpr ⟨ha, hb⟩
  omega

/-- **And the property that stops this being a way to hide a regression.** If
two of the three readings exceed the bound, the median exceeds it and the gate
still fails. The repair suppresses noise; it does not suppress the alarm. -/
theorem two_slow_readings_still_fail (a b c : Nat)
    (ha : msBound ≤ a) (hb : msBound ≤ b) :
    msBound ≤ median3 a b c := by
  have h1 : min a b ≤ median3 a b c := Nat.le_max_left _ _
  have h2 : msBound ≤ min a b := Nat.le_min.mpr ⟨ha, hb⟩
  omega

/-- The three readings actually measured on 2026-08-11, as integers. -/
def measuredReadings : Nat × Nat × Nat := (478, 810, 524)

/-- **The flaky run, decided.** Under the mean-of-one rule the verdict depended
on which batch was sampled: 478 passes, 810 and 524 fail. Under the median rule
those same three readings give 524 — which is still **over** the bound. The
repair does not rescue that run; it reports it honestly as slow. -/
theorem the_flaky_run_is_still_over_the_bound :
    median3 measuredReadings.1 measuredReadings.2.1 measuredReadings.2.2 = 524
      ∧ ¬ (median3 measuredReadings.1 measuredReadings.2.1 measuredReadings.2.2
            < msBound) := by decide

/-- **The finding that follows, and it is the uncomfortable one.** The router as
measured sits close enough to the bound that ordinary machine load crosses it.
Both facts are true at once: the deterministic model is comfortably inside
budget, and the wall-clock reading under load is not. Recorded rather than
resolved — the wall-clock gate is the one a user feels. -/
theorem the_router_is_inside_budget_but_near_the_wall_clock_bound :
    estimatedMs measuredSpawns < msBound
      ∧ ¬ (median3 measuredReadings.1 measuredReadings.2.1 measuredReadings.2.2
            < msBound) := by decide

/-! ## Normalising the reading, and the theorem that stops it being a loophole

The three flaky readings were taken immediately after 24 live sessions. Measured
at that moment, against the same measurements taken before them:

| quantity | idle | loaded | ratio |
|---|---|---|---|
| spawn tax (`/usr/bin/true`) | 12.0 ms | 20.1 ms | 1.68x |
| bash startup (`bash -c :`) | 20.1 ms | 92.8 ms | 4.62x |
| router spawn count | 28 | 28 | **1.00x** |

Both router *arms* degraded together — the PowerShell arm, historically 93-133
ms in a live session, read 468-703 ms in the same window. A common-mode shift
across two independent implementations of the same logic is the machine.

So the reading is divided by the machine's own tax. This is not a relaxation:
`normalising_at_reference_changes_nothing` proves the gate is bit-for-bit what
it was on an unloaded machine, and `a_slower_router_still_trips_the_alarm`
proves a genuine code regression still fails it. What normalisation removes is
the machine's contribution, which was never the router's to answer for. -/

/-- The spawn tax on the reference (unloaded) machine. -/
def refSpawnMs : Nat := perSpawnMs

/-- A wall-clock reading rescaled to the reference machine's spawn tax. -/
def normalise (per tax : Nat) : Nat := per * refSpawnMs / tax

/-- **The anti-loophole theorem.** On a machine at the reference tax the
normalised reading *is* the raw reading. Normalisation cannot make an honestly
slow router look fast, because where the machine is not slow it does nothing. -/
theorem normalising_at_reference_changes_nothing (per : Nat) :
    normalise per refSpawnMs = per := by
  simp only [normalise, refSpawnMs, perSpawnMs]
  omega

/-- **The alarm still fires.** At the reference tax, any reading at or above the
bound normalises to a value at or above the bound — a code regression is caught
exactly as before. -/
theorem a_slower_router_still_trips_the_alarm (per : Nat) (h : msBound ≤ per) :
    msBound ≤ normalise per refSpawnMs := by
  rw [normalising_at_reference_changes_nothing]; exact h

/-- Normalisation is monotone in the reading at fixed tax: a slower router never
normalises to a faster figure. -/
theorem normalise_is_monotone (p q tax : Nat) (h : p ≤ q) :
    normalise p tax ≤ normalise q tax :=
  Nat.div_le_div_right (Nat.mul_le_mul_right _ h)

/-- **The normalisation is validated against an independent measurement.** The
loaded batch read 533 ms at a tax of 20 ms; normalised it gives 319 ms. The
router's own self-report on the *idle* machine, from its debug log over ten
runs, was 327-341 ms (midpoint 334). The residual is 15 ms — **under 5%** of the
independently measured figure. Stated as a bound on the error rather than as a
match, because a match would be a fit. -/
theorem the_normalisation_reproduces_the_idle_self_report :
    normalise 533 20 = 319 ∧ 20 * (334 - normalise 533 20) ≤ 334 := by decide

/-- The three flaky readings, normalised by the tax measured alongside them.
Their median is comfortably inside the bound — which is the correct verdict, and
the opposite of the raw one. Both are recorded; the raw figures are not
deleted. -/
theorem the_flaky_run_normalises_to_a_pass :
    median3 (normalise 478 20) (normalise 810 20) (normalise 524 20) = 314
      ∧ median3 (normalise 478 20) (normalise 810 20) (normalise 524 20) < msBound := by
  decide

/-- **The two verdicts side by side, neither hidden.** The same three readings
fail on raw wall clock and pass once the machine's tax is divided out. The
disagreement is the finding: the raw gate was reporting the machine. -/
theorem the_raw_and_normalised_verdicts_disagree :
    ¬ (median3 measuredReadings.1 measuredReadings.2.1 measuredReadings.2.2 < msBound)
      ∧ median3 (normalise 478 20) (normalise 810 20) (normalise 524 20) < msBound := by
  decide

/-! ## The third outcome: a reading that measured nothing

Normalisation was not enough, and the failure is worth recording because it was
the *second* wrong hypothesis in a row.

Dividing each batch by a spawn tax sampled beside it should cancel load, since
load inflates numerator and denominator together. Measured, it does not:

    batch 1:  826 ms / 10.85 ms = 76.1 spawn-equivalents
    batch 2:  677 ms / 28.57 ms = 23.7 spawn-equivalents
    batch 3:  999 ms / 12.57 ms = 79.5 spawn-equivalents

A 3.4x spread across three consecutive batches of the same unchanged router.
Load on this machine moves faster than the samples are taken, so the tax beside
a batch is not the tax *during* it.

**A measurement whose own spread exceeds its bound has not measured anything.**
Reporting it as a pass is a fake green; reporting it as a failure blames the
router for the machine. Both are lies. So the cost check gets a third outcome,
exactly as `verify.yml`'s decide step did when two empty files made a `diff`
meaningless (`RotVerdictDecision.lean`): `unmeasurable`.

`unmeasurable` is **not green**. It blocks a release just as `exceeded` does.
The difference is what it tells you to do: re-measure on a quiet machine, rather
than go looking for a regression that is not there. -/

/-- What the cost check can conclude. Three outcomes, not two. -/
inductive CostVerdict where
  | within      : CostVerdict
  | exceeded    : CostVerdict
  | unmeasurable : CostVerdict
  deriving DecidableEq, Repr

/-- Readings are carried in tenths of a spawn-equivalent so the arithmetic stays
in `Nat` and stays decidable. -/
abbrev Reading := Nat

/-- The spread between the largest and smallest of three readings. -/
def spread (a b c : Reading) : Nat :=
  max a (max b c) - min a (min b c)

/-- A reading is trustworthy when its spread is at most a quarter of its median.
Chosen as a fraction of the signal, never as an absolute — an absolute
tolerance would silently tighten as the machine got faster. -/
def trustworthy (a b c : Reading) : Bool :=
  decide (4 * spread a b c ≤ median3 a b c)

/-- The cost verdict: unmeasurable readings never reach a comparison. -/
def costVerdict (a b c budgetTenths : Reading) : CostVerdict :=
  if trustworthy a b c then
    if median3 a b c < budgetTenths then CostVerdict.within else CostVerdict.exceeded
  else CostVerdict.unmeasurable

/-- The budget in tenths of a spawn-equivalent: 41 spawns. -/
def budgetTenths : Nat := spawnBudget * 10

/-- The three ratios measured on 2026-08-12, in tenths. -/
def measuredRatios : Reading × Reading × Reading := (761, 237, 795)

/-- **The tolerance itself is pinned, from both sides.** Mutant C05 tightened
`4 *` to `400 *` and SURVIVED: every theorem above still held, because a spread
of zero stays trustworthy under any multiplier and a spread of three quarters
stays untrustworthy under any multiplier. The extremes said nothing about the
boundary. These two do — a spread of a fifth of the median is admitted, a spread
of a third is refused — and a gate that always answered `unmeasurable` would
fail the first of them. -/
theorem the_tolerance_admits_a_fifth_and_refuses_a_third :
    trustworthy 100 120 125 = true ∧ trustworthy 100 140 130 = false := by decide

/-- **The run measured nothing.** Its spread is 558 tenths against a median of
761 — nearly three quarters of the signal. No verdict about the router can be
read out of it. -/
theorem the_measured_run_was_unmeasurable :
    costVerdict measuredRatios.1 measuredRatios.2.1 measuredRatios.2.2 budgetTenths
      = CostVerdict.unmeasurable := by decide

/-- **`unmeasurable` is not a pass.** The single property that stops the third
outcome being a way to turn a red gate green. -/
theorem an_unmeasurable_reading_is_not_a_pass (a b c t : Reading) :
    costVerdict a b c t = CostVerdict.unmeasurable → costVerdict a b c t ≠ CostVerdict.within := by
  intro h; rw [h]; decide

/-- **A quiet machine still reaches a verdict.** When the readings agree, the
third outcome never fires and the gate decides as it always did. -/
theorem a_quiet_machine_still_decides (a t : Reading) :
    costVerdict a a a t = CostVerdict.within ∨ costVerdict a a a t = CostVerdict.exceeded := by
  simp only [costVerdict, trustworthy, spread, median3]
  rcases Nat.lt_or_ge (max a (max a a)) t with h | h <;>
    simp [Nat.max_self, Nat.min_self, h] <;> omega

/-- **A quiet machine can still FAIL.** Three agreeing readings over budget give
`exceeded`, so a genuine regression is caught and the alarm is intact. -/
theorem a_quiet_slow_router_is_still_caught :
    costVerdict 900 900 900 budgetTenths = CostVerdict.exceeded := by decide

/-- All three outcomes are reachable — the check is not pinned to one answer. -/
theorem all_three_cost_verdicts_are_reachable :
    costVerdict 100 100 100 budgetTenths = CostVerdict.within
      ∧ costVerdict 900 900 900 budgetTenths = CostVerdict.exceeded
      ∧ costVerdict 761 237 795 budgetTenths = CostVerdict.unmeasurable := by decide

/-- **Only `within` releases.** Both other outcomes block, which is what makes
`unmeasurable` an honest report rather than an escape hatch. -/
def costReleases (v : CostVerdict) : Bool := v == CostVerdict.within

/-- Neither failing outcome ships. -/
theorem only_a_measured_pass_releases :
    costReleases CostVerdict.within = true
      ∧ costReleases CostVerdict.exceeded = false
      ∧ costReleases CostVerdict.unmeasurable = false := by decide

/-- And the run as measured does not ship. -/
theorem this_run_does_not_release :
    costReleases (costVerdict measuredRatios.1 measuredRatios.2.1
                    measuredRatios.2.2 budgetTenths) = false := by decide

/-! ## The third wrong turn: rescaling manufactured a failure

Normalisation was adopted to stop a loaded machine failing the gate. Measured on
a machine that had become *faster* than the reference, it did the opposite: a
raw reading of **472 ms — comfortably passing** — was rescaled to **566 ms and
failed**, because the current tax (10 ms) was below the reference (12 ms) and
the rescale multiplied the cost *up*.

An instrument that manufactures a failure is committing the same sin as one that
manufactures a pass. Both report something the machine did not say.

**So the gate is on the raw reading, and the rescale gates nothing.** The bound
exists because a user should not feel the hook, and a user feels the
milliseconds on *their* machine — not on a reference machine they do not own.
The question the rescale was reaching for, *is the code getting heavier*, is
answered deterministically and better by `spawnBudget`. -/

/-- **The counterexample, as measured.** A passing raw reading rescaled into a
failure on a faster-than-reference machine. -/
theorem rescaling_can_manufacture_a_failure :
    472 < msBound ∧ normalise 472 10 = 566 ∧ ¬ (normalise 472 10 < msBound) := by
  decide

/-- **The rule adopted in consequence.** The verdict is a function of the raw
readings; the rescaled figure is a diagnostic and appears in no comparison. This
theorem is what `checker/bench-router.sh` implements: `costVerdict` is applied
to the three raw batch means, never to the rescaled ones. -/
theorem the_verdict_is_taken_on_raw_readings :
    costVerdict 4720 4688 4872 (msBound * 10) = CostVerdict.within
      ∧ costVerdict (normalise 4720 10) (normalise 4688 10) (normalise 4872 10)
          (msBound * 10) = CostVerdict.exceeded := by decide

/-- **And the direction that still must not be laundered.** A raw reading that
genuinely exceeds the bound is `exceeded` on the raw figures too — moving the
gate to raw did not create a way for a slow router to pass. -/
theorem a_genuinely_slow_router_is_exceeded_on_raw :
    costVerdict 9000 9000 9000 (msBound * 10) = CostVerdict.exceeded := by decide

/-! ## What a README may quote

The four incompatible figures are samples of a quantity with this spread. -/

/-- The spread of the three readings. -/
def readingSpread : Nat := measuredReadings.2.1 - measuredReadings.1

/-- **Why one number cannot be quoted as "the" latency.** The spread between the
fastest and slowest reading of the *same unchanged router* is 332 ms — larger
than the gap between any two of the four figures the README quotes. Any single
sample is inside the noise of any other. -/
theorem no_single_sample_characterises_the_cost :
    readingSpread = 332 ∧ 178 - 170 < readingSpread ∧ 436 - 380 < readingSpread := by
  decide

/-- The bound, by contrast, is a constant and may be quoted. This is the one
sentence the README is permitted: the gate enforces 500 ms. -/
theorem the_bound_is_quotable : msBound = 500 := by decide

end RotMoE.CostBudget
