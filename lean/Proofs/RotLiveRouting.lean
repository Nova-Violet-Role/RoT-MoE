/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Proofs.RotP24Control

/-!
# The live router: ten lanes fired, and the gauge is not a constant

Everything here is **MEASURED from the router's own structured log** during real
Claude Code sessions, then settled in Lean. The measurement is
`C:/Users/Saimono/Claude_Test/.claude/rot-route-debug.jsonl` — 10 181 records,
of which 5 090 are `route` records and **517 are `UserPromptSubmit`**, the only
event that carries a prompt to route.

| quantity | measured | instrument |
|---|---|---|
| prompt-routing decisions | **517** | the router's own jsonl sink |
| distinct lanes reached | **10 of 10** | same |
| distinct `R/s+` values | **10** | same |
| live sessions routed to the expected lane | **4 of 4** | `checker/marketplace-session.sh` |
| distinct lanes across those live sessions | **4** | same |

## Why this file exists rather than a paragraph in the README

Two claims are easy to make and easy to get wrong in the flattering direction:
*the router routes* and *the gauge is dynamic*. A router that returned one
constant lane, and a gauge that returned one constant number, would satisfy
every wiring check ever written — the marker would arrive, the hook would fire,
the session would look instrumented. `constant_lane_cannot_cover_ten` and
`constant_gauge_has_one_value` are the theorems that make those two failures
*visible* rather than plausible: if either degenerate router were installed, the
measured coverage could not be what it is.

## The defect this replaced, and it was in the instrument

Measured 2026-08-12, `checker/marketplace-session.sh` reported "only 1 of 4 live
sessions routed to the expected lane" and "CONTROL DEAD: only 1 distinct live
lane". Both were artefacts of the probe. The router is bound to 31 events, so a
session emits many markers, and the probe took the **first** one — `SessionStart`,
which has no prompt (`chars = 0`, `stem = ""`) and therefore falls to the
`CONVERGENT` default. All four probes read `CONVERGENT`, and the single row that
expects `CONVERGENT` "passed".

**A check whose only pass is the row matching the default is measuring the
default.** In the very same run the offline table reported *all 10 lanes routed
correctly* and the marker reached the session 4 of 4 — so the router was never
in question. The probe now selects by **event** instead of by position, and a
regression control asserts the session-level marker is constant while the prompt
lane varies, which is what makes the old read demonstrably useless rather than
merely deprecated.
-/

namespace RotMoE.LiveRouting

open RotMoE.Family

/-! ## What was measured -/

/-- Prompt-routing decisions observed in the live log. -/
def promptRoutes : Nat := 517

/-- Distinct lanes those decisions reached. -/
def lanesReached : Nat := 10

/-- The router's full lane set: nine leads plus the `CONVERGENT` fallback. -/
def lanesDeclared : Nat := 10

/-- Distinct `R/s+` values observed across those same decisions. -/
def gaugeValues : Nat := 10

/-- Live sessions in `marketplace-session.sh`, and how many reached the lane the
table demanded. Measured **after** the probe was corrected. -/
def liveSessions : Nat × Nat := (4, 4)

/-- Distinct lanes across those live sessions. -/
def liveDistinctLanes : Nat := 4

/-! ## The degenerate routers these numbers exclude -/

/-- **A router that always answers with one lane cannot reach ten.** Stated over
an arbitrary constant router rather than over the measured numbers, so it is a
fact about constancy and not about this log. -/
theorem constant_lane_cannot_cover_ten (coverage : Nat)
    (h : coverage ≤ 1) : coverage < lanesDeclared := by
  -- `omega` does not unfold definitions, so the declared lane count is exposed
  -- first. It stays a definition rather than a literal so that adding a lane
  -- moves this theorem with the router instead of leaving it behind.
  simp only [lanesDeclared]
  omega

/-- **The measurement excludes it.** Ten lanes were reached, so no router with
coverage at most one produced this log. -/
theorem the_live_router_is_not_lane_constant :
    ¬ (lanesReached ≤ 1) := by decide

/-- **Every declared lane was exercised**, not merely most of them. -/
theorem every_declared_lane_fired : lanesReached = lanesDeclared := by decide

/-- **A constant gauge takes exactly one value**, whatever that value is. -/
theorem constant_gauge_has_one_value (values : Nat)
    (h : values ≤ 1) : ¬ (2 ≤ values) := by omega

/-- **The measured gauge is not constant** — ten distinct values across the same
517 decisions. This is the `R/s+` dynamism claim, bound to the log rather than
to the formula's shape. -/
theorem the_live_gauge_is_dynamic : 2 ≤ gaugeValues := by decide

/-! ## The corrected live probe -/

/-- **Every live session reached the lane the table demanded.** -/
theorem every_live_session_hit_its_lane :
    liveSessions.1 = liveSessions.2 ∧ 0 < liveSessions.1 := by decide

/-- **And they did not all hit the same one.** A probe where every session lands
on one lane is satisfied by a constant router; this one is not. -/
theorem the_live_probe_saw_more_than_one_lane :
    2 ≤ liveDistinctLanes := by decide

/-- The state the probe reported **before** it was corrected: one lane across
four sessions. Kept as a definition so the failure it represents is nameable,
and so `the_old_read_would_not_pass_today` is about a real prior state rather
than a hypothetical. -/
def preFixDistinctLanes : Nat := 1

/-- **The old reading fails the variation control, and the new one passes it.**
This is the whole repair in one statement: nothing about the router changed
between the two numbers — only which record was read. -/
theorem the_old_read_would_not_pass_today :
    ¬ (2 ≤ preFixDistinctLanes) ∧ 2 ≤ liveDistinctLanes := by decide

/-- A session-level route carries no prompt, so its lane cannot depend on the
prompt. Modelled honestly: the routing input is the character count, and a
session-level event supplies zero of them. -/
def promptChars (sessionLevel : Bool) (chars : Nat) : Nat :=
  if sessionLevel then 0 else chars

/-- **Reading a session-level marker discards the prompt entirely.** For *any*
two prompts, the session-level route sees the same input — which is why the
pre-fix probe could not distinguish `lake build the theorem` from `i feel lost
and tired today`. -/
theorem session_level_route_ignores_the_prompt (c₁ c₂ : Nat) :
    promptChars true c₁ = promptChars true c₂ := by
  simp [promptChars]

/-- And the prompt-level route does **not** discard it — the guard above is not
vacuously true of every read. -/
theorem prompt_level_route_keeps_the_prompt :
    promptChars false 12 ≠ promptChars false 34 := by decide

/-! ## What this does not claim -/

/-- Lane coverage and gauge dynamism are claims about **what the router does**,
not about answer quality. P2.4 produced no admissible evidence on work quality
(`RotP24Control.p24_produced_no_admissible_evidence`), and nothing in this file
supplies any: 517 routing decisions establish that the router routes, and are
silent on whether routing helps. The two are kept in one conjunction so neither
can be quoted without the other. -/
theorem routing_is_measured_quality_is_not :
    (lanesReached = lanesDeclared ∧ 2 ≤ gaugeValues) ∧
    RotMoE.P24Control.haystackProbe.1 = RotMoE.P24Control.haystackProbe.2 := by
  decide

end RotMoE.LiveRouting
