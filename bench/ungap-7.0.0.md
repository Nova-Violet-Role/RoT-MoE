<!--
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# Un-gap ledger for 7.0.0

Findings surfaced during the 6.0.2 study/fix cycle that are real but out of
6.0.2's scope. Each row: what the gap is, the evidence, and what closing it
would take. Facts only; the decision to close belongs to 7.0.0 planning.

| # | gap | evidence | what closing it takes |
|---|---|---|---|
| U1 | **CLOSED (7.0.0 arc, 2026-08-19).** Single-arm mutations had no killer without PowerShell: the reminder corpus had no per-row expectations, and the ten-profile phase was arm-vs-arm only. | measured: H21/H23 flipped INEXPRESSIBLE→KILLED by `checker/golden-remind.txt` (mutate-checker: killed=11, inexpressible 8→6, survivors honestly machine-bound); a planted CONVERGENT λ 1.6→1.7 died against `checker/golden-gauge-profiles.txt` with the digit named in the diff — the human line alone could NOT see it (ΔR ≈ 0.008 under the 2-decimal print), so the golden also records the gauge record's full-precision lens arrays | two generated goldens, each rewritten only by a deliberate `--make-golden` act with a banner; per-row/per-profile verification runs armless; stale goldens are FAILs |
| U2 | **CLOSED (7.0.0 arc, 2026-08-19).** `portability.sh` sections this machine cannot run vanished from the VERDICT: the phase-3 note and the CRLF skip counted nothing, so a pwsh-less run exited 0 with a third of the instrument missing. | measured: pre-fix exit 0 on this pwsh-less container with phase 3 unrun; post-fix `21 passed, 0 failed, 2 skipped` exit 3 | a SKIP counter with both skip sites counted, the summary naming it, and the F2 exit semantics: fail outranks skip, skip exits 3, never a pass |
| U3 | **CLOSED (7.0.0 arc, 2026-08-19).** A summons written while the gate was armed survived every `ROTMOE_GATE=0` prompt turn — opting out skipped the summons block entirely, clear included — so the first Stop after re-arming was blocked for a turn long dead. | measured 2026-08-19: armed FUSE turn wrote `voice-summons.u3`; a `GATE=0` CONVERGENT turn left it standing; the re-armed gate then blocked with the dead turn's five charters | fixed in both router arms (`GATE=0` still clears) plus a D10 sequence probe in `checker/voice-contract.sh` that replays the exact scenario |
