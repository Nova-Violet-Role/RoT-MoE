/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

import Proofs.RotCeiling

/-!
# What "surpasses the standard agentic loop" MEANS, stated so it can be killed

## Why this file exists

The project's central claim is that nine-lens routing *overhauls the default
Claude Code loop*. For a long time that was attacked with the weakest possible
reading — "does the routed arm win a trivia A/B" — and three corpora answered
NO for three different reasons (brevity confound, selectivity confound, and a
ceiling at 84-84 then 78/80).

Those results stand and are not walked back. But they were aimed at the wrong
proposition. Standard Claude Code has **no routing layer at all**: no lane
selection, no lens weighting, no divergence gauge, no per-turn record of why a
turn was handled the way it was. The claim worth testing is therefore
STRUCTURAL, and this file states it precisely enough to be falsified.

## The definition

A routing layer **strictly extends** the default loop when all seven hold:

| | conjunct | what it rules out |
|---|---|---|
| D1 | TOTALITY | a router that silently drops events |
| D2 | CONSERVATION | a router that adds a feature by breaking one |
| D3 | ADDITION | a router that changes nothing observable |
| D4 | DISCRIMINATION | a router that emits a CONSTANT — a log, not a decision |
| D5 | DETERMINISM | a router whose output cannot be reproduced or audited |
| D6 | RECOMPUTABILITY | a gauge whose number cannot be re-derived from its own record |
| D7 | BOUNDED COST | a layer that buys observability with unbounded latency |

Each is proved LOAD-BEARING below: for every conjunct there is a router that
satisfies the other six and is still not an extension. A definition where one
clause is redundant is a definition with a clause that was chosen to be passed.

## What this file deliberately does NOT claim

`dominance_says_nothing_about_answer_quality` is a theorem, not a caveat. Two
routers with identical structure can produce answers of any relative quality,
so `extends` must never be read as "better answers". That question was measured
separately, three times, and the honest answers are recorded in `RotAbVerdict`,
`RotGrounding` and `RotCeiling`.

The binding to the real router is `checker/dominance.sh`, which measures all
seven conjuncts against the shipped hooks and the live log.
-/

namespace RotMoE.Dominance

/-- An observation of a routing layer, every field of which is measurable from
outside the model. -/
structure Layer where
  /-- Events the host emits that this layer is asked to handle. -/
  eventsOffered : Nat
  /-- Events it handled without failing. -/
  eventsHandled : Nat
  /-- Default capabilities present before the layer was installed. -/
  baselineCaps : Nat
  /-- Default capabilities still present after installation. -/
  survivingCaps : Nat
  /-- Router-observable records produced over the corpus. -/
  records : Nat
  /-- Distinct routing outcomes actually observed (lanes reached). -/
  distinctOutcomes : Nat
  /-- Replays of the same input that produced the same outcome. -/
  reproducibleReplays : Nat
  /-- Replays attempted. -/
  replaysAttempted : Nat
  /-- Gauge records whose value was recomputed from the record's own fields. -/
  recomputed : Nat
  /-- Gauge records present. -/
  gaugeRecords : Nat
  /-- Worst per-turn cost observed, in milliseconds. -/
  worstMs : Nat
  deriving DecidableEq, Repr

/-- The default Claude Code loop: it handles its own events and keeps its own
capabilities, and produces NOTHING router-observable. Not a strawman — the
absence of a routing layer is the actual baseline. -/
def defaultLoop (events caps : Nat) : Layer :=
  { eventsOffered := events, eventsHandled := events
    baselineCaps := caps, survivingCaps := caps
    records := 0, distinctOutcomes := 0
    reproducibleReplays := 0, replaysAttempted := 0
    recomputed := 0, gaugeRecords := 0, worstMs := 0 }

/-- The latency ceiling the shipped gate enforces, in milliseconds. -/
def msBound : Nat := 500

/-- The number of lanes the router declares. -/
def lanes : Nat := 9

def D1_total (l : Layer) : Bool := l.eventsHandled == l.eventsOffered
def D2_conserves (l : Layer) : Bool := l.survivingCaps == l.baselineCaps
def D3_adds (l : Layer) : Bool := 0 < l.records
def D4_discriminates (l : Layer) : Bool := lanes ≤ l.distinctOutcomes
def D5_deterministic (l : Layer) : Bool :=
  0 < l.replaysAttempted && l.reproducibleReplays == l.replaysAttempted
def D6_recomputable (l : Layer) : Bool :=
  0 < l.gaugeRecords && l.recomputed == l.gaugeRecords
def D7_bounded (l : Layer) : Bool := l.worstMs ≤ msBound

/-- **The definition.** A layer strictly extends the default loop exactly when
all seven conjuncts hold. -/
def extends' (l : Layer) : Bool :=
  D1_total l && D2_conserves l && D3_adds l && D4_discriminates l &&
  D5_deterministic l && D6_recomputable l && D7_bounded l

/-! ### The baseline does not extend itself -/

/-- **The default loop is not an extension of itself.** It fails D3 and D4: no
records, no outcomes. This is what stops `extends'` from being a tautology that
anything satisfies — including doing nothing. -/
theorem the_default_loop_does_not_extend_itself (events caps : Nat) :
    extends' (defaultLoop events caps) = false := by
  simp [extends', defaultLoop, D3_adds, D4_discriminates, D1_total, D2_conserves,
        D5_deterministic, D6_recomputable, D7_bounded, lanes]

/-- Even a default loop handling every event and losing nothing still fails,
and it fails on ADDITION specifically. Naming which conjunct rejects the
baseline matters: it is the one the whole claim rests on. -/
theorem the_baseline_fails_on_addition (events caps : Nat) :
    D1_total (defaultLoop events caps) = true ∧
    D2_conserves (defaultLoop events caps) = true ∧
    D3_adds (defaultLoop events caps) = false := by
  simp [defaultLoop, D1_total, D2_conserves, D3_adds]

/-! ### Every conjunct is LOAD-BEARING -/

/-- A layer that satisfies everything. The measured shape, used as the base for
each near-miss below. -/
def full : Layer :=
  { eventsOffered := 31, eventsHandled := 31
    baselineCaps := 10, survivingCaps := 10
    records := 62, distinctOutcomes := 9
    reproducibleReplays := 20, replaysAttempted := 20
    recomputed := 15, gaugeRecords := 15, worstMs := 258 }

theorem full_extends : extends' full = true := by decide

/-- Drops two events. -/
def missD1 : Layer := { full with eventsHandled := 29 }
/-- Breaks a default capability. -/
def missD2 : Layer := { full with survivingCaps := 9 }
/-- Emits nothing. -/
def missD3 : Layer := { full with records := 0 }
/-- Emits a CONSTANT: every turn routed to the same lane. -/
def missD4 : Layer := { full with distinctOutcomes := 1 }
/-- Same input, different outcome. -/
def missD5 : Layer := { full with reproducibleReplays := 18 }
/-- A gauge number that cannot be re-derived from its own record. -/
def missD6 : Layer := { full with recomputed := 12 }
/-- Buys observability with latency. -/
def missD7 : Layer := { full with worstMs := 900 }

/-- **All seven are load-bearing.** For each conjunct there is a layer failing
only that one, and it is not an extension. Delete any clause from `extends'` and
the corresponding router below starts passing. -/
theorem every_conjunct_is_load_bearing :
    extends' missD1 = false ∧ extends' missD2 = false ∧
    extends' missD3 = false ∧ extends' missD4 = false ∧
    extends' missD5 = false ∧ extends' missD6 = false ∧
    extends' missD7 = false := by decide

/-- Never replayed anything. -/
def missD5vac : Layer := { full with reproducibleReplays := 0, replaysAttempted := 0 }
/-- Never recomputed anything, because there was nothing to recompute. -/
def missD6vac : Layer := { full with recomputed := 0, gaugeRecords := 0 }

/-- **Vacuous determinism is not determinism.** A layer that attempted no
replays trivially has "all replays agreeing", and without the `0 <` guard it
would pass D5 by never having been tested. Same for a gauge that emitted no
records to recompute.

These are the conjuncts' silent-pass holes, identified before writing the
mutation suite precisely so that deleting either guard has something to kill. -/
theorem an_untested_layer_is_not_deterministic :
    D5_deterministic missD5vac = false ∧ extends' missD5vac = false ∧
    D6_recomputable missD6vac = false ∧ extends' missD6vac = false := by decide

/-- **The objection, formalised and answered.** "Adding a log is not
surpassing." Correct — and `missD4` is exactly that router: it produces 62
records and routes every single turn to the same lane. It satisfies ADDITION and
fails DISCRIMINATION, so it is not an extension.

D3 without D4 is a logger. D3 with D4 is a decision. -/
theorem a_logger_is_not_a_router :
    D3_adds missD4 = true ∧ D4_discriminates missD4 = false ∧
    extends' missD4 = false := by decide

/-- **Conservation is the conjunct that can regress.** A layer can add a real
decision layer and still not be an extension, by costing a default capability.
This is the one that a "more features" story hides, and the only one whose
failure makes the installed router genuinely WORSE than no router. -/
theorem addition_does_not_excuse_regression :
    D3_adds missD2 = true ∧ D4_discriminates missD2 = true ∧
    D2_conserves missD2 = false ∧ extends' missD2 = false := by decide

/-! ### The anti-overclaim -/

/-- Answer quality, as an opaque score attached to a layer. Nothing in `Layer`
constrains it, which is the point. -/
structure Run where
  /-- The structural observation. -/
  layer : Layer
  /-- Items answered correctly. Deliberately unconstrained by `layer`. -/
  correct : Nat
  deriving DecidableEq, Repr

/-- **Dominance says NOTHING about answer quality**, and this is a theorem
rather than a footnote. Two runs whose layers both extend the default loop can
have any relative accuracy, including the extending one being worse.

So `extends' = true` may never be reported as "better answers". That question
was measured separately — `RotAbVerdict.headline_can_be_huge_while_verdict_fails`,
`RotGrounding`, and `RotCeiling.ceiling_is_not_a_null` hold those answers. -/
theorem dominance_says_nothing_about_answer_quality :
    ∃ a b : Run, extends' a.layer = true ∧ extends' b.layer = true ∧
      a.correct < b.correct := by
  exact ⟨⟨full, 1⟩, ⟨full, 2⟩, by decide, by decide, by decide⟩

/-- And the other direction: a run can score better while its layer is NOT an
extension. Quality and structure are independent, measured independently. -/
theorem quality_can_be_high_without_extending :
    ∃ a b : Run, extends' a.layer = false ∧ extends' b.layer = true ∧
      b.correct < a.correct := by
  exact ⟨⟨missD3, 99⟩, ⟨full, 1⟩, by decide, by decide, by decide⟩

/-! ### Monotonicity: the claim cannot be won by shrinking the test -/

/-- Handling fewer events cannot turn a non-total layer total. Stated because
the cheapest way to fake D1 is to offer the router less. -/
theorem totality_is_not_bought_by_offering_less (l : Layer)
    (h : l.eventsHandled < l.eventsOffered) : D1_total l = false := by
  simp only [D1_total, beq_eq_false_iff_ne]
  omega

/-- Nor can DISCRIMINATION be bought by declaring fewer lanes: the bound is
`lanes ≤ distinctOutcomes` against the shipped constant, not against whatever
the run happened to reach. -/
theorem discrimination_is_measured_against_the_declared_lane_count (l : Layer)
    (h : l.distinctOutcomes < lanes) : D4_discriminates l = false := by
  simp only [D4_discriminates, decide_eq_false_iff_not, Nat.not_le]
  exact h

/-- A layer reaching MORE outcomes than declared still discriminates — the
criterion is a floor, not an equality, so adding a lane later cannot make a
correct router fail. (The dated-spec hazard, avoided deliberately.) -/
theorem more_lanes_than_declared_still_discriminates (l : Layer)
    (h : lanes ≤ l.distinctOutcomes) : D4_discriminates l = true := by
  simp [D4_discriminates, h]

/-! ### Why the DETERMINISM test was wrong, and why more samples was not the fix

Found by a mutant router, not by inspection. `checker/dominance.sh` replayed one
payload five times and called the layer deterministic if all five agreed. A
router branching on `$$ % 2` — genuinely nondeterministic, verified to produce
two distinct lanes over twelve hand probes — passed that test.

The cause is ALIASING. Each replay spawned a fixed number of subprocesses, so
the PID advanced by a constant stride `s`. A router with hidden period `p`
dividing `s` is sampled at the same phase every time, and returns one value
however many samples are taken. -/

/-- Sampling a hidden state of period `p` at a CONSTANT stride `s`. -/
def constStride (n s p : Nat) : List Nat :=
  (List.range n).map (fun i => (i * s) % p)

/-- Sampling where the i-th probe is preceded by `i` extra steps, so the
cumulative offset is triangular rather than linear — the repair applied to
`checker/dominance.sh`. -/
def varStride (n p : Nat) : List Nat :=
  (List.range n).map (fun i => (i * (i + 1) / 2) % p)

/-- **The aliasing lemma.** When the period divides the stride, every sample
lands on phase 0. The router can be arbitrarily nondeterministic and the test
sees a single value. -/
theorem aliased_sample_is_always_phase_zero (p s i : Nat) (h : p ∣ s) :
    (i * s) % p = 0 := by
  obtain ⟨k, hk⟩ := h
  subst hk
  rw [Nat.mul_left_comm, Nat.mul_mod_right]

/-- **More samples was never the fix.** For ANY sample count `n`, constant-stride
sampling of an aliased period yields nothing but zeros — so raising `n` from 5 to
500 would have left the nondeterministic router passing. This is why the repair
had to change the stride, not the count. -/
theorem more_samples_do_not_break_the_alias (n s p : Nat) (h : p ∣ s) :
    ∀ x ∈ constStride n s p, x = 0 := by
  intro x hx
  simp only [constStride, List.mem_map] at hx
  obtain ⟨i, _, hi⟩ := hx
  rw [← hi]
  exact aliased_sample_is_always_phase_zero p s i h

/-- The measured case exactly: PID stride 2, hidden period 2, twelve replays.
Every sample identical — a nondeterministic router reported as deterministic. -/
theorem the_measured_alias_is_blind : constStride 12 2 2 = List.replicate 12 0 := by
  decide

/-- **The repair works.** A varying stride sees both phases of a period-2 router
within three samples. -/
theorem varying_stride_breaks_the_alias :
    0 ∈ varStride 3 2 ∧ 1 ∈ varStride 3 2 := by
  decide

/-- And it is not a fluke of period 2: a varying stride separates phases of a
period-3 router too. Stated because a repair verified on exactly the case that
broke is a repair fitted to its own test. -/
theorem varying_stride_separates_period_three :
    0 ∈ varStride 5 3 ∧ 1 ∈ varStride 5 3 := by
  decide

/-! ### Executable checks against the MEASURED shape -/

-- The defect, executable: 12 constant-stride samples of a period-2 router.
#guard (constStride 12 2 2).eraseDups.length = 1
-- The repair, executable: the same 12 samples at a varying stride.
#guard 1 < (varStride 12 2).eraseDups.length
#guard 1 < (varStride 12 3).eraseDups.length

-- 31 hook events, all handled, 62 records: measured 2026-08-09 by hooksweep.sh.
#guard D1_total full = true
#guard D3_adds full = true
-- Nine lanes reached: measured by lensscore.js over 3825 gauge records.
#guard D4_discriminates full = true
-- 258 ms worst case: from the live route record of 2026-08-09T19:26:20.
#guard D7_bounded full = true
#guard extends' full = true

-- The baseline, at the same event and capability count, is NOT an extension.
#guard extends' (defaultLoop 31 10) = false
#guard D3_adds (defaultLoop 31 10) = false
#guard D1_total (defaultLoop 31 10) = true

-- Each near-miss fails, and only on its own conjunct.
#guard extends' missD1 = false
#guard extends' missD2 = false
#guard extends' missD3 = false
#guard extends' missD4 = false
#guard extends' missD5 = false
#guard extends' missD6 = false
#guard extends' missD7 = false
#guard D3_adds missD4 = true
#guard D2_conserves missD2 = false

-- A layer at exactly the latency bound passes; one millisecond over fails.
#guard D7_bounded { full with worstMs := 500 } = true
#guard D7_bounded { full with worstMs := 501 } = false

end RotMoE.Dominance
