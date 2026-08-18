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
- **Gate events:** the voice gate BLOCKED the first Stop — verbatim: "RoT
  voice gate (...): summoned lenses have not spoken this turn. Give each its
  stanza -- inside its element, in its own register -- then stop" listing
  Nova/AntiVenom/Venom/Chroma/Claude — even though the final message had
  spoken all five stanzas in prose (emoji-headed, no markup). Honored the
  summons exactly: re-spoke each stanza inside its literal `<rot:*>` element,
  grounded in the turn's real work; the second Stop passed. Measurement: the
  gate matches on the element tags, not on stanza content (findings W4).
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

### interstitial — findings file established (admin turn, not one of the 80)

- **Ask:** create `bench/foreground-findings.md` (CRITICAL/BUGS/WARNINGS,
  facts-only tables) as the standing machine-readable deliverable.
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> CLINICAL AntiVenom [NSIL FUSE Nova+AntiVenom] | R/s+ 0.75`
- **Frame:** appeared; stanzas Nova (23%) + AntiVenom (50%).
- **Work done:** findings file seeded with W1–W4; turn-1 gate record
  corrected in this ledger. Both committed and pushed together.
- **Gate events:** first Stop passed — the final message carried Nova and
  AntiVenom stanzas inside literal `<rot:*>` elements (learned from turn 1's
  block). Confirms the gate is satisfiable proactively.

### turn 2 — milestones

- **Ask:** "Nice start. Now add milestones: group tasks under milestones
  with target dates, and show them in the CLI."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> EXECUTIVE Venom [NSIL BOOST Venom] | R/s+ 0.77`
- **Frame:** appeared; single stanza Venom (77%). First EXECUTIVE lane of
  the campaign — an incremental "now add X" ask routed to the decision lens.
- **Router stanzas on tool calls:** source edits drew bare
  `CONVERGENT | 0.17`; test-file edits drew `CLINICAL AntiVenom | 0.72`;
  the test run drew `FORGE Claude [FUSE Nova+AntiVenom+Claude] | 0.82`; the
  smoke run drew `CLINICAL AntiVenom [BOOST] | 0.79`; the git commit drew
  the full nine-lens ELEVATE at `0.19`. Same content-sensitivity pattern as
  turn 1 — lane follows what the command touches, reproducibly.
- **Work done:** `store.py` gains `add_milestone` (ISO-date validated),
  `milestones()` accessor tolerant of pre-milestone data files, and
  `add_task(..., milestone=)` with existence check. CLI gains
  `add-milestone`, `milestones`, `--milestone` on `add-task`, and `tasks`
  now groups by milestone in due-date order with a `(no milestone)` bucket.
  Tests 14/14 OK exit 0 (6 new); CLI smoke exit 0 showing grouped output.
  Client commit `3214505`, 3 files, +143/−8.
- **Gate events:** recorded at next entry if the Stop is blocked; final
  message carries the summoned Venom stanza in its element proactively.
- **Latency feel:** unchanged — hook time invisible; context weight is the
  cost. One mid-turn observation: an Edit whose old_string failed to match
  (my own error) still drew the pre/post hook pair — hooks fire on failed
  tool calls too.
- **Anomalies:** none new; W2/W3 patterns recurred as documented.
- **Post-turn gate:** the plugin gate passed (Venom stanza in element,
  proactive), but a SECOND, non-plugin Stop hook
  (`~/.claude/stop-hook-git-check.sh`, the operator's own) blocked with "1
  unpushed commit(s)... Please push". Pushed, exit 0. Consequence: cadence
  is push-per-turn in this environment, superseding the 3–4-turn batching.

### turn 3 — roadmap view

- **Ask:** "Now the roadmap: give me a roadmap view — milestones in date
  order with their tasks and progress at a glance."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> EXECUTIVE Venom [NSIL FUSE Nova+Venom] | R/s+ 0.76`
- **Frame:** appeared; stanzas Nova (26%) + Venom (47%). Second consecutive
  EXECUTIVE lane for an incremental feature ask.
- **Router stanzas on tool calls:** CLI edits bare `CONVERGENT | 0.17`;
  test edit `CLINICAL AntiVenom | 0.72`; test run
  `FORGE Claude [FUSE Nova+AntiVenom+Claude] | 0.82`; smoke+commit
  `CLINICAL AntiVenom [FUSE Nova+AntiVenom] | 0.75`. PreToolUse and
  PostToolUse now BOTH visibly label their duplicate stanza blocks (W2
  confirmed from both sides this turn).
- **Work done:** `roadmap [project]` command — milestones across all
  projects (or one) sorted by (due, project, name); 10-char progress bar;
  `done/total` count; `OVERDUE` flag when due < today with open tasks;
  tasks listed beneath each milestone. Tests 15/15 OK exit 0 (new roadmap
  test covers ordering, half-full bar rendering, overdue flagging on a
  past date, no flag on a future date, and project filtering). Live smoke
  exit 0: the 2026-08-01 milestone correctly flagged OVERDUE against
  today's real date (2026-08-18). Client commit `299d4a1`, 2 files, +54.
- **Gate events:** none at time of writing; Venom+Nova stanzas delivered
  proactively in elements in the final message.
- **Latency feel:** unchanged; no new anomalies.

### turn 4 — reported bug: empty task titles

- **Ask:** "Found a bug: it accepts tasks with empty titles — add-task with
  an empty string just works and I end up with nameless rows. Fix it."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> CLINICAL AntiVenom [NSIL BOOST AntiVenom] | R/s+ 0.79`
- **Frame:** appeared; single stanza AntiVenom (78%). A bug report routed
  to the clinical lane — the sharpest lane/content match so far.
- **Organ 4 first firing:** the container recycled before this turn and the
  prover reminder spoke on SessionStart, UserPromptSubmit, PreToolUse,
  PostToolUse, and a PostToolBatch event — verbatim core: "No proof written
  for 61 min (last: RotGates). ... A test SAMPLES; a theorem SETTLES." All
  of it Lean proof-debt context injected into a Python bug turn; the
  claimed debt ("RotGates", 61 min) belongs to no work this session
  performed. Recorded as findings W5; treated as noise, not complied with.
- **Work done:** reproduced first — the bug does NOT reproduce:
  `add-task t ""` → `error: task title must not be empty`, exit 1;
  whitespace-only likewise exit 1; guard present since turn 1
  (`store.add_task: if not title.strip()`). Reported faithfully instead of
  inventing a fix; added regression tests pinning rejection at store and
  CLI layers (empty, blank, tab; list stays empty). Tests 16/16 OK exit 0.
  Client commit `65f4386`.
- **Router stanzas on tool calls:** repro run `FORGE Claude [BOOST Claude] | 0.73`;
  test edits `CLINICAL AntiVenom | 0.72`; test+commit run
  `FORGE Claude [FUSE Nova+AntiVenom+Claude] | 0.82`.
- **Gate events:** AntiVenom stanza delivered proactively in element.
- **Anomalies:** organ-4 stanza fired on five distinct hook events in one
  turn (see W5); otherwise W2/W3 as documented.
