<!--
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# RoT MoE — foreground live test ledger

The session itself is the subject: one Claude Code remote session, plugin
installed at user scope, every turn done in foreground with the session's own
tools. No sub-agents, no nested `claude`, no backgrounded work. Each entry
below is one real work turn, recorded as it happened.

Hard laws in force: never elevate; never download the Lean toolchain (no
`SETUP_LEAN` in any form); read every exit code directly, never through a
pipe; a red result is data, recorded verbatim.

## Phase 0 — setup log

Date (UTC): 2026-08-18T14:13:00Z

| step | command | exit | result |
|---|---|---|---|
| marketplace add | `claude plugin marketplace add Nova-Violet-Role/RoT-MoE` | 0 | `√ Successfully added marketplace: rot-moe (declared in user settings)` |
| plugin install | `claude plugin install rot-moe@rot-moe` | 0 | `√ Successfully installed plugin: rot-moe@rot-moe (scope: user)` |
| plugin list | `claude plugin list` | 0 | `rot-moe@rot-moe / Version: 6.0.1 / Scope: user / Status: √ enabled` |
| marketplace HEAD | `git -C ~/.claude/plugins/marketplaces/rot-moe rev-parse HEAD` | 0 | `bf6495e285f3cf42a8473274666d79611bbcdf5a` |

Workspace clone: `/home/user/RoT-MoE`, was detached at the same commit
`bf6495e2`; checked out `claude/rot-moe-usage-agents-qp8hzu` tracking origin
(exit 0).

Anomaly noted at setup: the marketplace HEAD commit's subject line reads
"6.0.2 row A (shell half): the audit pairing learns concurrency", but
`.claude-plugin/plugin.json` at that same commit declares `"version": "6.0.1"`
and `claude plugin list` reports 6.0.1. The manifest version appears to lag
the commit series by one row. Recorded verbatim, not worked around.

Arming status at end of Phase 0: hooks load at session start, so this
session's own turns are NOT yet wrapped — no `RoT MoE :: TIER 1 ->` marker,
no `<rot:frame>` line, no lens stanzas have appeared on any turn so far. The
router arms when the container is next recycled and a new message starts a
fresh session with the plugin loaded.

## Turn ledger

(one compact entry per work turn: turn number, the ask, the marker verbatim,
stanzas spoken, gate events, latency feel, anomalies verbatim)

*No work turns yet. Phase 0 only.*
