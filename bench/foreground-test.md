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

### probe 1 — ARMED (2026-08-18, campaign start)

The arming probe itself carried the markers. SessionStart:resume fired
`RoT MoE :: TIER 1 -> CONVERGENT model | R/s+ 0.17`; the prompt itself fired
`RoT MoE :: TIER 1 -> FORGE Claude [NSIL FUSE Nova+AntiVenom+Venom+Chroma+Claude] | R/s+ 0.71`
with the `<rot:frame>` provenance line and five lens stanzas
(Nova 12%, AntiVenom 17%, Venom 10%, Chroma 9%, Claude 22%) as prompt
context. The nine lens agents (`rot-moe:rot-*`) and the plugin skills
(`rot-agent`, `rot-swarm`, `corpus`, `lean4-prover`) all appeared in the
session's roster at arm time. Armed on container recycle, exactly as the
arming fact predicted.

### turn 1 — sprint planner skeleton

- **Ask:** "Build the skeleton of a terminal sprint planner: projects and
  tasks, plain-file storage, a CLI entry point, and tests. Keep it simple
  and working."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> FORGE Claude [NSIL FUSE Nova+AntiVenom+Venom+Chroma+Claude] | R/s+ 0.71`
- **Frame:** appeared, full provenance text, on the prompt and on every
  hooked tool call.
- **Router stanzas:** prompt — Nova/AntiVenom/Venom/Chroma/Claude (FUSE).
  Tool calls re-routed per call: first Bash (`git init`) drew
  `CONVERGENT model [NSIL ELEVATE ...all nine lenses] | R/s+ 0.19`; the four
  source Writes drew bare `CONVERGENT model | R/s+ 0.17` (no stanzas); the
  test-file Write flipped to `CLINICAL AntiVenom | R/s+ 0.72` (76%); the
  test run drew `FORGE Claude [NSIL FUSE Nova+AntiVenom+Claude] | R/s+ 0.82`;
  smoke test and commit drew `CLINICAL AntiVenom [NSIL BOOST AntiVenom] | R/s+ 0.79`.
  The lane tracking is visibly content-sensitive: writing tests and running
  them pulled the clinical/forge lenses without being told.
- **Work done:** `/root/client-project` created, `git init` exit 0. Package
  `sprintplan/` (store.py: JSON plain-file storage with atomic save;
  cli.py: argparse CLI — add-project/projects/add-task/tasks/done;
  `__main__.py` entry point) plus `tests/test_sprintplan.py`. Tests: 8/8 OK,
  exit 0, read directly. CLI smoke end-to-end exit 0. Root commit `6973b15`,
  6 files, 242 insertions.
- **Gate events:** none so far this turn (Stop not yet reached at time of
  writing this entry).
- **Latency feel:** hook overhead unnoticeable against real tool work; the
  per-tool-call stanza blocks are the visible cost — the nine-lens ELEVATE
  block on a bare `git init` is a lot of context for one command.
- **Anomalies (verbatim where applicable):** (1) `~` is `/root` in this
  container, so the client project is `/root/client-project`, not under
  `/home/user`. (2) PostToolUse repeats the identical stanza block PreToolUse
  just injected — every hooked call pays the context twice.
- **Env note:** `ROTMOE_DEBUG_LOG=$HOME/fg-debug.jsonl` will be exported
  inline on any direct hook exercise (shell env does not persist between
  tool calls in this harness); session hooks log per their own config; the
  plugin is never modified.
