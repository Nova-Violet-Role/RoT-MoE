<!--
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# Un-gap ledger for the release after 7.0.0

Findings surfaced during the 7.0.0 study cycle that are real but out of
7.0.0's scope — almost all of them from the S6 sweep of `lean/Proofs`, the
one front the 7.0.0 arc studied but did not rebuild (no Lean toolchain on
the work container; proofs are never written blind). Facts only; the
decision to close belongs to the next planning pass.

| # | gap | evidence | what closing it takes |
|---|---|---|---|
| N1 | Two proof modules have **no mutation suite at all**: `RotScan.lean` (14 theorems) and `RotBandMonitor.lean` (11 theorems) declare 0 mutants — no kill has ever attributed their load-bearing-ness. RotBandMonitor additionally names **no binding checker**, so it is unbound in both directions: its band constants are transcribed, and a band edit in the shipped router cannot go red anywhere in Lean. | S6 sweep 2026-08-19: `lean/mutate/` has no `mutate_rotscan.sh` or `mutate_rotbandmonitor.sh` among its 85 entries; RotBandMonitor has zero `checker/` references | write the two suites (needs `lake`); either bind RotBandMonitor's bands to the router source the way `gauge-cross.sh` binds the gauge, or state in the module that it is documentation |
| N2 | The 7.0.0 behavior itself is **unmodelled in Lean**: no module mentions the `LENSDATA` stanza pipe format or the per-lens δ/μ emission (V1), the PostToolUse result sentinel (V2), or the GATE=0 summons cleanup (U3) — the router's own comments call U3 a measured bug, and nothing proves the fix's invariant. | S6 sweep: `grep LENSDATA` and `grep ROTMOE_GATE` over `lean/Proofs` return zero hits; `PostToolUse` appears only in RotInject/RotInstall/RotEvent/RotObserve | new theorems (needs `lake`): sentinel precedence + silence-by-default as a decision function; summons-cleared-on-GATE=0 as a state invariant; LENSDATA field count/order pinned the way RotLog pins the JSON line |
| N3 | The two 7.0.0 **goldens are named by no Lean module**: RotLog and RotScan cite the checkers that consume them (`log-replay.sh`, `remind-measure.sh`) as they stood before the goldens existed. | S6 sweep: `golden-` appears in no `.lean` file | a paragraph per module doc comment; optionally a theorem that a stale golden (row count ≠ corpus) is always detected, mirroring the checker's rule |
| N4 | **Line-number rot inside `lean/Proofs`**, concentrated where modules quote `hooks/rot-router.sh` by line: RotEnsemble (6 drifted cites, plus 4 cites of a machine-local `~/.claude/tools/sanctum/rot-lean-inject.ps1` that is not in the repository), RotDominance (3 drifted), RotLog (2 drifted). The router grew to 2,114 lines and the numbers stopped being true. | S6 sweep, each cite checked against the live file | replace line cites with function/comment-anchor cites (comment-only edits); the sanctum path should be named as the historical machine-local source it is |
| N5 | **Version-stamp anachronisms** in module prose: RotEigenform:1002 attributes a measurement to router "0.7.1"; RotLog's header says "before 0.7.0"; RotGates' header narrates "587 seconds" and "twenty-eight gate names" against its own 66-row `#guard`-pinned table. The guards are current; the prose around them is a museum. | S6 sweep | comment-only edits, or an explicit "as of release X" stamp per claim |
| N6 | `RotAbility.lean`: **6 mutants over 37 theorems**, the thinnest ratio in the corpus, and its codex citations point at files outside `lean/` that nothing verifies. | S6 sweep; `mutate_rotability.sh` declares 6 | widen the suite (needs `lake`); decide whether codex cites deserve an existence check the way README theorem cites got one |
| N7 | Charter-side design tension left open by S3: Violet's track table selects by **query mood**, the router's dynamic clause selects by **clock hour** — both are shipped, and the two readings can disagree on the same turn. Not a defect (the charter says the mood reading belongs to the convening model); worth an explicit sentence in both places saying which wins when they differ. | S3 persona sweep 2026-08-19 | one sentence in the charter, one in the DTD comment |
