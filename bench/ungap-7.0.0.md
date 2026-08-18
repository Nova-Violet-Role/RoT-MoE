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
| U1 | The reminder cross-diff cannot kill single-arm mutations without PowerShell: `corpus-remind.txt` has no per-row expected outputs, so a POSIX-arm boundary move (H21) or message byte-drop (H23) changes behaviour nothing compares. 6.0.2 made the suite say so honestly (INEXPRESSIBLE, exit 3); it did not add kill power. | mutate-checker 2026-08-18: H21/H23 INEXPRESSIBLE on a pwsh-less container; H25 killable only because the non-vacuity rows see speak/silence flips | a golden third column in `corpus-remind.txt` (expected bytes per row) plus a single-arm compare phase in `cross-diff-remind.sh`; same for `corpus-gauge.txt`/`cross-diff.sh` CONVERGENT-table rows (H01's blind spot) |
| U2 | `portability.sh` section 3 (PowerShell arms without Windows env vars) silently vanishes without pwsh — wrapped in `if command -v pwsh`, no else, no SKIP line, so the section's absence is invisible in the output. | read 2026-08-18, checker/portability.sh:227 | an else-branch printing a SKIP note, and possibly a skip counter in portability's summary |
