<!--
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# CoT vs ToT vs RoT — preregistered outcome study (design frozen before any run)

This file is written BEFORE the study runs, in the repository's
preregistration convention, so the design cannot drift toward whatever the
data turns out to say. It exists because two prior campaigns disagree and
neither settles the question.

## The question, stated narrowly

Does arming this router measurably change the OUTCOME of real work — not
whether it routes (settled: MEASURED, on every turn), not whether the
model can hear the lenses (settled: MEASURED, envelope and stanzas), but
whether the delivered artifact is any better, worse, or cheaper.

## The prior evidence, both directions, honestly

- The blind Hard Session (80 turns; the worker never knew the router was
  the subject) judged the voices "wallpaper with a tax" and the mechanical
  layer excellent. That verdict is this study's **null hypothesis**.
- The self-observed Foreground campaign (30 turns) claims routing-content
  correlation with receipts (bug asks routed CLINICAL 4/4, forecast asks
  PREDICTIVE 3/3). It is not outcome-blind and cannot carry the claim.
- The earlier A/B study returned NOT ESTABLISHED and was published as
  such. This repository's precedent is that a null gets printed, not
  reframed.

## Design

Three arms, same base model, same harness, fresh session per task-arm:

| arm | scaffold |
|---|---|
| CoT | plain session, no plugin, no scaffold prompt |
| ToT | branching-deliberation prompt scaffold (explore N approaches, pick one), no plugin |
| RoT | this plugin armed, defaults untouched |

- **Task set.** N tasks (N fixed and written here before the first run;
  target 15) drawn from the ask classes the two campaigns actually
  carried: bug diagnosis, small implementation, consequence forecast,
  compression under a byte budget, a message with human weight, a
  prioritisation call. Each task has a preregistered grading key written
  with the task, before any arm runs it.
- **Blindness.** The worker sessions are never told a study is running
  (the Hard Session precedent). The grader sees ONLY the task text and
  the final artifact — never the transcript, never the arm, never this
  repository. Artifacts are stripped of any marker or stanza text before
  grading.
- **Order.** Task-arm order randomized once, recorded in the run ledger
  before execution.

## Metrics

1. **Primary:** per-task outcome score against the preregistered key
   (objective checks preferred: does the fix reproduce, does the forecast
   name the branch that occurred, is the budget respected).
2. **Secondary (the "tax" side):** wall time and token spend per
   task-arm; for RoT, gate blocks and whether stanzas were performed.

## Analysis and what counts as what

Paired per-task comparison across arms; report directions and counts per
task class. No significance theater at N=15 — the report states counts
and effect direction, and calls anything mixed MIXED. Outcomes:

- **RoT ≠ CoT consistently across classes:** the null falls; the report
  says in which direction, including "worse".
- **No consistent direction:** the null stands, and the front page keeps
  saying outcome effects are an open question — with this study cited as
  the measurement that kept it open.

## Out of scope, stated so nobody imports more than was measured

This study binds one implementation, one model configuration, one task
set, at one point in time. It cannot establish "routing helps" as a
general claim, and this repository will not quote it as if it could.
