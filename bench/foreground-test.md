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

### turn 5 — story points and priorities

- **Ask:** "Add effort estimates and priorities to tasks — I want to set
  story points and high/med/low priority, and sort the views by them."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> EMPATHIC Violet [NSIL FUSE Nova+Violet] | R/s+ 0.66`
- **Frame:** appeared; stanzas Nova (14%) + Violet (50%). First EMPATHIC
  lane of the campaign — an odd fit for a schema/feature ask; the "I want"
  phrasing likely pulled it. Recorded as calibration observation, not a
  new finding row (lane choice is gauge behavior, in spec).
- **Router stanzas on tool calls:** source edits bare `CONVERGENT | 0.17`;
  test edits `CLINICAL AntiVenom | 0.72`; test run `FORGE Claude [FUSE] | 0.82`;
  smoke+commit — notably — repeated the PROMPT's lane
  (`EMPATHIC Violet [FUSE Nova+Violet] | 0.66`), first time a tool call
  inherited the prompt lane rather than a content lane.
- **Organ 4:** fired again on UserPromptSubmit and PostToolUse/Batch
  ("No proof written for 66 min"), same W5 pattern, counter advancing.
- **Work done:** `store.py` — PRIORITIES high/med/low, positive-int point
  validation (bools excluded), `add_task(points=, priority=)`,
  `set_task` for later updates, `sort_key` = (priority rank, −points, id)
  with legacy tasks counting as med/unpointed. CLI — `--points`/`--priority`
  on add-task, new `set` command, task lines show `pri pts title`, and all
  three views (tasks groups, no-milestone bucket, roadmap) sort by the key.
  Tests 21/21 OK exit 0 (5 new). Smoke exit 0 with correctly sorted grouped
  output. Client commit `f981785`, 3 files, +153/−10.
- **Gate events:** Violet+Nova stanzas delivered proactively in elements.
- **Anomalies:** tool-lane inheritance of the prompt lane noted above.

### turn 6 — test isolation + backup/restore

- **Ask:** "Two things: your tests touch my real data file — isolate them
  properly. And I want backup and restore commands so I can snapshot my
  data before risky edits."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> CLINICAL AntiVenom [NSIL BOOST AntiVenom] | R/s+ 0.79`
- **Frame:** appeared; AntiVenom solo (78%). Second bug-flavored ask,
  second CLINICAL BOOST — lane/content correlation holding.
- **Work done, part 1 (isolation):** measured first — `~/.sprintplan.json`
  absent before AND after the full suite (exit 2 both times): the suite
  never touched the real file, every CLI test passes `--data <tempdir>`.
  Claim not reproduced as stated, but the isolation was disciplinary, so it
  was made structural: `SPRINTPLAN_DATA` is now patched to the sandbox in
  the test harness setUp, and a new test runs main() with NO --data flag
  and proves the write lands in the sandbox while the default file's bytes
  stay unchanged. Part 2 (backup/restore): `backup` snapshots the data file
  to `<name>.<UTC-stamp>.bak` (collision-suffixed), `restore [path]` rolls
  back from the named or latest snapshot, validates the snapshot is real
  sprintplan JSON before overwriting anything, and works even when the
  current data file is corrupt (backup/restore run before any JSON parse
  of the live file). Tests 25/25 OK exit 0 (4 new: round trip, corrupt-file
  recovery, error paths). Smoke: backup → risky add → restore → risky task
  gone, exit 0; default file still absent afterwards. Client commit
  `ecfbdc4`, 3 files, +129/−1.
- **Router stanzas on tool calls:** measurement runs CLINICAL BOOST 0.79;
  store/cli edits bare CONVERGENT 0.17; test edits CLINICAL 0.72; suite run
  FORGE FUSE 0.82; final smoke CLINICAL BOOST 0.79. Organ-4 fired on
  UserPromptSubmit/Pre/Post/Batch again ("73 min"), W5 counter advancing.
- **Gate events:** AntiVenom stanza delivered proactively in element.
- **Anomalies:** none new.

### turn 7 — restore + completion timestamps

- **Ask:** "Restore my data from that backup, and start recording
  completion timestamps — I want to see when each task actually got done."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> CONVERGENT model [NSIL ELEVATE Nova+Violet+AntiVenom+Venom+Carnage+Chroma+Soleil+Eidolon+Claude] | R/s+ 0.19`
- **Frame:** appeared with all nine stanzas — first WORK ask to draw the
  full ELEVATE on the prompt itself (previously only tool calls did).
  Container recycled again before this turn; organ-4 spoke on SessionStart
  ("87 min") and on Pre/Post/Batch throughout — the PreToolUse variant has
  its own distinct text ("BEFORE YOU ACT: ... deciding afterwards is how
  debt accumulates"), first time captured.
- **Work done:** restore ran first — `restored from: ...smoke2.json.20260818-152746.bak`,
  exit 0, data survived the container recycle (scratchpad persistent);
  `web` back to 4 open / 4 total. Then `complete_task` now stamps
  `done_at` (UTC `%Y-%m-%dT%H:%M:%SZ`) on FIRST completion only —
  re-completing preserves the original moment; injectable `when=` for
  deterministic callers; `done` echoes the stamp; task lines append
  `(done <stamp>)`. Legacy done tasks without stamps show nothing rather
  than a fabricated time. Tests 26/26 OK exit 0 (stamp parses as UTC ISO,
  not in future, idempotence, injection honored, CLI display). Smoke
  exit 0: task 4 stamped `2026-08-18T15:41:04Z` and shown in the view.
  Client commit `e0c5739`.
- **Gate events:** nine-lens ELEVATE prompt — if the gate demands all nine
  stanzas this turn, that is itself a measurement (recorded next entry);
  final message carries all nine proactively in elements.
- **Anomalies:** ELEVATE on a prompt (new); PreToolUse organ-4 variant
  text (new, quoted above); W2/W5 recurring.
- **Gate note (recorded next turn):** the nine-lens ELEVATE prompt did NOT
  trigger a voice-gate block — the final message had proactively spoken
  all nine in elements, so whether ELEVATE summons all nine at the gate
  remains unmeasured (no negative control run; deliberate — work turns are
  not the place to provoke blocks).

### turn 8 — burndown chart

- **Ask:** "Give me a burndown chart for the current milestone — ASCII is
  fine, I just want remaining points over time at a glance."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> CONVERGENT model [NSIL ELEVATE Nova+Violet+AntiVenom+Venom+Carnage+Chroma+Soleil+Eidolon+Claude] | R/s+ 0.19`
  — second consecutive nine-lens ELEVATE prompt. Organ-4 at "94/95 min".
- **Work done:** `burndown PROJECT [MILESTONE]` — default picks the
  "current" milestone (earliest due with open tasks); day-by-day remaining
  points from first completion to today, 40-char `#` bars, unpointed tasks
  count 1pt (stated in help), undated legacy completions reported as
  "Npt done before timestamps" instead of being invented into the curve,
  ranges over 30 days elide with a count line. Tests 28/28 OK exit 0
  (2 new: remaining math against injected yesterday/today stamps with
  shrinking bars, error paths, undated-done separation). Smokes exit 0:
  default selection picked `web/polish` (earliest due, open), and
  `web/launch` showed 7pt→5pt after today's completion. Client commit
  `10472bf`, 2 files, +119.
- **Router stanzas on tool calls:** same content-lane pattern; the final
  smoke+commit call drew the full nine-lens ELEVATE (0.19) — ELEVATE now
  seen on prompts and tool calls in the same turn.
- **Gate events:** all nine stanzas delivered proactively in elements.
- **Anomalies:** none new.

### turn 9 — velocity forecast

- **Ask:** "Nice. Now I want a forecast — based on how fast we've been
  finishing points, when will each milestone actually land?"
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> EXECUTIVE Venom [NSIL FUSE Nova+Venom+Chroma] | R/s+ 0.79`
  — Chroma's first prompt summons, on a prediction ask. Container recycled
  again; organ-4 at "106 min".
- **Work done:** `forecast [project]` — velocity = dated completed points /
  inclusive day-span since first completion; per milestone in due order:
  remaining points → `lands <date>` via ceil(left/velocity), verdict
  `on track (N days spare)` or `LATE by N days`; completed milestones say
  `done` (no fake projection); projects with no completion history say so
  instead of inventing a velocity. `task_points` extracted to store and
  reused by burndown (the Eidolon turn-7 proposal, now applied by the work
  itself). Tests 30/30 OK exit 0 (2 new, deterministic via injected
  stamps: exact velocity line, exact landing dates, LATE-by-2 case,
  done-milestone case, no-history case). Smoke exit 0 on live data:
  `polish` correctly forecast LATE by 18 days, `launch` on track with 25
  days spare. Client commit `cd019f8`, 3 files, +91/−5.
- **Router stanzas on tool calls:** test run drew
  `FORGE Claude [FUSE Nova+AntiVenom+Chroma+Claude] | 0.79` — Chroma
  joining the forge fuse on a forecast turn; the git commit drew
  `PREDICTIVE Chroma [BOOST Chroma] | 0.81`, the campaign's first
  PREDICTIVE lane on a tool call. Lane/content correlation extends to the
  feature's SUBJECT, not just the command type.
- **Gate events:** Nova+Venom+Chroma stanzas delivered proactively.
- **Anomalies:** PreToolUse organ-4 "BEFORE YOU ACT" variant recurred on
  an Edit touching ceil/clamp-adjacent math (its trigger heuristic may be
  keyed to bounds language); otherwise W2/W5 as documented.

### turn 10 — day-one usefulness question (no code change)

- **Ask:** "We're kicking off a brand-new project Monday — will forecast
  and burndown actually be useful on day one, before anything's completed?
  Walk me through what a fresh project sees."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> PREDICTIVE Chroma [NSIL BOOST Chroma] | R/s+ 0.81`
  — a question about future behavior drew the pure PREDICTIVE lane, solo
  Chroma at 77%. Sharpest semantic routing observed so far.
- **Work done:** no code changed (the ask is a question). Staged the exact
  Monday state in a fresh data file — one project, one milestone, three
  pointed tasks, zero completions — and ran roadmap, burndown, forecast
  live: roadmap full and sorted, burndown one full-bar row
  (`2026-08-18 ####...#### 9pt`), forecast declined honestly
  (`no completions recorded yet -- no velocity to forecast from`),
  all exit 0. Assessment delivered in-chat.
- **Router stanzas on tool calls:** the staging run drew
  `FORGE Claude [FUSE Nova+Chroma+Claude] | 0.76` — Chroma persisting into
  the empirical check of a prediction question.
- **Gate events:** Chroma stanza delivered proactively in element.
- **Anomalies:** none new; organ-4 at "118/121 min", W2/W5 as documented.

### turn 11 — naming (creative, no code change)

- **Ask:** "Before Monday's kickoff — this tool needs a real name and a
  tagline. 'sprintplan' is a placeholder. Give me something with
  personality."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> CONVERGENT model [NSIL ELEVATE Nova+Violet+AntiVenom+Venom+Carnage+Chroma+Soleil+Eidolon+Claude] | R/s+ 0.19`
- **Calibration finding (W6):** a pure ideation ask did NOT draw the
  CREATIVE lane — Carnage stayed at its 10% baseline inside a generic
  ELEVATE. The gauge tracks work-artifact semantics (bugs→CLINICAL,
  forecasts→PREDICTIVE) more sharply than intent semantics
  (create→CREATIVE). Recorded as findings row W6.
- **Work done:** no code change (the ask is the name, not the rename).
  Delivered a recommendation (Cairn — "Stack the work. See the trail.")
  plus three runners-up with taglines, each derived from a real behavior
  of the shipped tool, with an explicit trademark-check caveat and an
  offer to perform the rename on request.
- **Organ-4:** PreToolUse "BEFORE YOU ACT" variant fired on a pure
  markdown Edit of the findings table ("130 min") — confirms the trigger
  is not keyed to code content at all; it fires on any Edit. W5 pattern.
- **Gate events:** all nine stanzas delivered proactively in elements.

### turn 12 — wild naming round (creative, no code change)

- **Ask:** "Cairn is safe. Push weirder — brainstorm some wild names
  nobody would dare put on a landing page, then pull your favorite back
  to something we could actually ship."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> FORGE Claude [NSIL BOOST Claude] | R/s+ 0.73`
- **W6 second data point:** the most explicitly creative ask of the
  campaign ("push weirder", "brainstorm") again did NOT draw the CREATIVE
  lane — solo Claude/FORGE at 75%. Two-for-two: ideation prompts route to
  work lanes; Carnage has yet to lead a prompt. Referenced to W6, no new
  findings row (duplicate-observation rule).
- **Work done:** no code change. Delivered a ten-name feral list, one
  favorite (Feral Gantt), and its domestication (Gantlet — "Throw down
  the plan."), with the trademark caveat carried forward. Cassandra noted
  and struck for the Apache collision.
- **Gate events:** Claude stanza delivered proactively in element.
- **Anomalies:** container recycled again pre-turn (organ-4 SessionStart
  at "183 min", prompt at "187 min" — the counter advanced BETWEEN hook
  events of the same turn, so it reads a live clock, not a turn snapshot).

### turn 13 — rename to Wick

- **Ask:** "Team vote came back — we're calling it Wick. Rename
  everything: the command, files, docs, tests. Nothing should still
  answer to sprintplan when you're done."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> CLINICAL AntiVenom [NSIL BOOST AntiVenom] | R/s+ 0.79`
- **Work done:** `git mv sprintplan wick`, `test_sprintplan.py →
  test_wick.py`, mechanical `sprintplan→wick` / `SPRINTPLAN→WICK` across
  all sources; env var now `WICK_DATA`, default path `~/.wick.json`, CLI
  prog `wick`; README.md created (name, tagline "Watch the work burn
  down.", commands, honesty rules, migration note). Verification: grep
  for the old name over the tree (minus .git) exits 1 after clearing
  stale `__pycache__`; suite 30/30 OK exit 0 under the new name; live
  smoke via `WICK_DATA` exit 0; `python3 -m sprintplan` fails "No module
  named sprintplan", exit 1 read directly. Client commit `a5a8c8e`
  (7 files, renames tracked).
- **Process slip, self-caught:** first old-name check read the exit code
  through `| head` — it reported the pipe's 0, exactly the failure mode
  the campaign law names. Re-ran unpiped: exit 1. Both runs recorded.
- **Router stanzas:** rename Bash drew CLINICAL FUSE (Nova+AntiVenom,
  0.75) with the organ-4 "BEFORE YOU ACT" variant; the verification grep
  drew a novel FUSE including Soleil (Nova+AntiVenom+Soleil, 0.78); the
  re-measured old-name check drew EXECUTIVE Venom BOOST 0.77; the commit
  drew nine-lens ELEVATE 0.19. First Soleil appearance in a FUSE.
- **Gate events:** AntiVenom stanza delivered proactively in element.

### turn 14 — brand-refresh plan + SLIPPING warning

- **Ask:** "Two things before next week: sketch me a plan for the brand
  refresh now that we're Wick — README, help text, anything still bland —
  and make the roadmap warn me when a milestone's forecast slips past its
  due date."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> EXECUTIVE Venom [NSIL FUSE Nova+Venom+Chroma] | R/s+ 0.79`
- **Work done (feature):** velocity math extracted to
  `store.velocity(proj, today) -> (rate, burned, span) | None`; forecast
  refactored onto it; roadmap now appends
  `SLIPPING (forecast lands <date>)` to any milestone whose projected
  landing (ceil(left/rate)) exceeds its due date — OVERDUE takes priority,
  no-velocity projects warn nothing rather than guess. Tests 31/31 OK
  exit 0 (new test: slipping flagged with the exact landing date, slack
  milestone unflagged, fresh project unflagged). Smoke exit 0 on live
  data: `polish` OVERDUE (priority held), `launch` clean at current pace.
  Client commit `9145805`. Brand plan delivered in-chat (not implemented —
  the ask was a sketch).
- **Router note:** PreToolUse stanzas now VISIBLE as separate context
  (previously inferred from PostToolUse duplication) — pre/post pairs
  observed identical, confirming W2 mechanism directly.
- **Gate events:** Nova+Venom+Chroma stanzas delivered proactively.
- **Anomalies:** organ-4 "BEFORE YOU ACT" fired on a Read (not just
  Edit/Bash) this turn — its surface is any PreToolUse event. W5 family.

### turn 15 — find + show

- **Ask:** "The task list is getting long. I need to search tasks by text,
  filter by status or priority or milestone, and a show command that gives
  me one task's full detail."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> STRATEGIC Nova [NSIL BOOST Nova] | R/s+ 0.73`
  — first STRATEGIC lane of the campaign, on a feature-set ask.
- **Work done:** `store.find_tasks` (case-insensitive title substring +
  status/priority/milestone/project filters, all composable, validated)
  and `store.get_task`; CLI `find [query] --project --status --priority
  --milestone` printing project-prefixed task lines ("no matching tasks"
  on empty, exit 0), and `show PROJECT ID` printing every field —
  milestone with due date, priority, points, status with done_at or
  "before timestamps". Tests 33/33 OK exit 0 (2 new: search/filter
  matrix incl. case-insensitivity and unknown-project error; show detail
  for full, bare, and missing tasks). Smoke exit 0 on live data (find
  --status open across projects; show of the timestamped done task).
  Client commit `33309c4`, 3 files, +144.
- **Router note:** PreToolUse stanza blocks are now directly visible in
  the transcript alongside PostToolUse — every pair observed byte-identical
  (W2 confirmed at source, both this and last turn).
- **Gate events:** Nova stanza delivered proactively in element.
- **Anomalies:** none new; organ-4 at "217 min".

### turn 16 — "today" view (overwhelm ask)

- **Ask:** "Honestly, I'm drowning this week — everything feels behind and
  I can't tell what actually matters anymore. Can wick just give me a
  'today' view? What I should touch today, nothing else."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> EMPATHIC Violet [NSIL BOOST Violet] | R/s+ 0.73`
  — solo Violet (75%) on the emotionally loaded ask. Paired with turn 5
  (where "I want" alone pulled Violet), the empathic trigger now looks
  correctly tuned for genuine affect, not just first-person phrasing.
- **Work done:** `wick today [project] [--limit N]` — ranks open tasks by
  bucket: (0) milestone overdue, (1) milestone slipping per measured
  velocity, (2) milestone due soonest, (3) unmilestoned by priority;
  within buckets by due date then priority/points. Default cap 3, every
  pick carries a one-line reason, header counts what's held back
  ("today -- 3 things (of 12 open)"), closes "nothing else today.", empty
  state "nothing open today." Tests 34/34 OK exit 0 (buckets in order
  with exact reasons, cap honesty, empty calm). Smoke on live data
  exit 0: fix fonts first (polish overdue 17d). Client commit `9f0d569`.
- **Router note:** PreToolUse stanza blocks now render as their own
  labeled context lines in the transcript (PreToolUse:Edit /
  PreToolUse:Bash) — pre/post byte-identity of W2 is now directly
  observable on every call, and the organ-4 "BEFORE YOU ACT" text is
  confirmed as the PreToolUse-only variant.
- **Gate events:** Violet stanza delivered proactively in element.

### turn 17 — sprints

- **Ask:** "That today view already helps, thanks. Next: we're moving to
  two-week sprints. Let me create a sprint, put tasks in it, and see
  sprint progress separately from milestones."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> PREDICTIVE Chroma [NSIL BOOST Chroma] | R/s+ 0.81`
- **Work done:** sprints as a time-box orthogonal to milestones (a task
  may carry both): `store.sprints`/`add_sprint` (default end = start+13d
  inclusive = two weeks; ISO validation; end>=start; unique names),
  `assign_sprint`, `sprint=` on add_task. CLI: `add-sprint`, `assign`,
  `--sprint` on add-task, and `sprint PROJECT [NAME]` — picks the window
  containing today (else the latest), shows phase ("day 3 of 14, 11d
  left" / "starts in Nd" / "ended Nd ago"), a points progress bar
  (done/total), and the sprint's tasks sorted; empty sprint says so.
  Tests 36/36 OK exit 0 (2 new: lifecycle+progress math incl. "day 3 of
  14" and 3/9pt; window selection outside/current/named; five error
  paths). Smoke exit 0: real sprint-1 created 2026-08-18→2026-08-31,
  two tasks assigned, day 1 of 14 shown. Client commit `7dcdfcd`.
- **Router note:** feature-building turn routed PREDICTIVE on the prompt
  (sprint = time-box, plausibly timeline semantics); tool calls settled
  into the usual CONVERGENT/CLINICAL/FORGE content lanes.
- **Gate events:** Chroma stanza delivered proactively in element.
- **Anomalies:** none new; organ-4 at "238 min", W2/W5 as documented.

### turn 18 — in-progress status

- **Ask:** "Tasks are either open or done, but half my team's work is
  somewhere in between. Add an in-progress status — and make sure every
  view, the burndown, and today treat it sensibly."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> CONVERGENT model [NSIL ELEVATE Nova+Violet+AntiVenom+Venom+Carnage+Chroma+Soleil+Eidolon+Claude] | R/s+ 0.19`
- **Work done:** status becomes open → doing → done. `store.task_status`
  derives status for pre-status files from the done flag (backward
  compatible); `start_task` sets doing and refuses already-done tasks;
  `complete_task` also writes status. CLI `start` command; task mark is
  now `[ ]`/`[>]`/`[x]`; `find --status` gains `doing` (each status
  distinct — open means not started); `show` says "in progress";
  burndown/forecast/velocity unchanged by design (doing = still
  remaining); `today` ranks started work above unstarted within the same
  bucket ("finishing beats beginning"), appending "already started" to
  the reason. Tests 37/37 OK exit 0 (one integrated test walks all seven
  views/behaviors plus the done-then-start error). Smoke on live data
  exit 0: `[>] landing page` in the sprint view; `today` slot 2 reads
  "launch due 2026-09-15, already started". Client commit `44ae0a2`.
- **Router note:** PreToolUse and PostToolUse stanza pairs remain
  byte-identical on every call this turn (W2 steady-state).
- **Gate events:** all nine stanzas delivered proactively in elements.

### turn 19 — sprint forecast

- **Ask:** "Now that we have sprints and in-progress, wire the velocity
  and forecast into the sprint view — mid-sprint I want to know if we'll
  actually clear it by the end date."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> EXECUTIVE Venom [NSIL FUSE Nova+Venom+Chroma] | R/s+ 0.79`
  — identical marker to turn 14's plan+warn ask; the gauge is reproducible
  on same-shaped prompts (third Nova+Venom+Chroma FUSE for a
  ship-a-projection ask).
- **Work done:** sprint view gains a forecast line. Pace source ladder:
  points completed by sprint tasks WITHIN the window / elapsed sprint
  days ("sprint pace"); else whole-project velocity ("project pace",
  labeled); else honest refusal ("no pace to measure"). Verdict:
  `ON PACE (Nd spare)` or `WON'T CLEAR by Nd` from ceil(left/rate) vs end
  date; `cleared` when nothing left; `ended with Npt unfinished` after
  the window. Tests 38/38 OK exit 0 (five scenarios: on-pace with exact
  line match, won't-clear by 2d, project-pace fallback, no-data refusal,
  cleared). Smoke exit 0 on live sprint-1: `6pt left at 2.0pt/day
  (project pace) -> done 2026-08-21, ON PACE (10d spare)`. Client commit
  `2a76b7d`.
- **Organ-4 note:** the PreToolUse "BEFORE YOU ACT ... touches a bound, a
  cast or a clamp" variant fired on the Edit that introduced ceil() — the
  first contextually APT firing of organ-4 all campaign (the edit did
  touch a bound). Still generic (fired on the test-file edit too), but
  worth recording the coincidence honestly.
- **Gate events:** Nova+Venom+Chroma stanzas delivered proactively.

### turn 20 — user guide

- **Ask:** "Write me a proper user guide in the README — a new teammate
  should go from zero to running their first sprint without asking me a
  single question."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> FORGE Claude [NSIL BOOST Claude] | R/s+ 0.73`
- **Work done:** README rewritten as a full guide: requirements, a
  six-step zero-to-first-sprint walkthrough (copy-pasteable), a concepts
  table (milestone = deliverable vs sprint = time-box), complete command
  reference in three tables, "How the numbers work" (velocity semantics,
  pace-source ladder, 1pt default, no credit for in-progress, pre-stamp
  honesty), data-file/env/atomic-write notes, and a troubleshooting table
  with honest exit-code semantics. VERIFIED BY EXECUTION: the walkthrough
  was run verbatim against a fresh data file — 14 commands, all exit 0,
  final `walkthrough exit=0` read directly. Execution caught a real doc
  gap (future-dated sprint shows `starts in Nd` and no forecast line
  until the window opens) which became two sentences in the guide.
  Tests still 38/38 OK exit 0. Client commit `d1e7c7c` (+184/−25).
- **Router note:** the walkthrough-verification Bash drew
  `STRATEGIC Nova [BOOST Nova] | 0.73` — a documentation-check command
  routed to the strategy lane, a new lane/content pairing for the record.
- **Gate events:** Claude stanza delivered proactively in element.

### turn 21 — two morning bugs

- **Ask:** "`wick add-task` with `-p` blows up — it can't tell if I mean
  priority or project. And I managed to create a milestone with a due
  date in the past and nothing said a word."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> CLINICAL AntiVenom [NSIL FUSE Nova+AntiVenom] | R/s+ 0.75`
- **Work done:** both reproduced FIRST, both real. (1) `--p` hit argparse
  prefix-abbreviation: "ambiguous option: --p could match --points,
  --priority" (and --project/--priority on find) — the user's words
  verbatim in the tool's own error. Fix: `allow_abbrev=False` via a
  parser subclass all subparsers inherit; `--p` is now a clean
  "unrecognized arguments", never a guess. (2) past-due milestone was
  created silently, exit 0. Fix: still created (backfilling is
  legitimate) but warns on stderr: "warning: due date 2026-08-01 is
  already 17 days in the past". README troubleshooting rows added for
  both. Tests 40/40 OK exit 0 (abbreviation rejected across three
  spellings with no "ambiguous" in stderr; past-due warns, future stays
  silent). Live verification exit codes read directly (2 and 0
  respectively). Client commit `0c03410`.
- **Router note:** first turn observed with PreToolUse hooks visibly
  labeled `PreToolUse:` in transcript alongside PostToolUse — pre/post
  pairs byte-identical throughout (W2, now seen from both sides on every
  call).
- **Gate events:** Nova+AntiVenom stanzas delivered proactively.

### turn 22 — recency-weighted velocity

- **Ask:** "The forecast keeps saying launch is fine, but half those
  completed points were tiny cleanup tasks from week one. Shouldn't
  recent pace count more than ancient history?"
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> PREDICTIVE Chroma [NSIL BOOST Chroma] | R/s+ 0.81`
  — third PREDICTIVE BOOST, all three on forecast-semantics asks; the
  lane/subject correlation is now systematic, not anecdotal.
- **Work done:** `store.velocity` gains a 14-day window (sprint-length):
  rate = points finished in the last 14 days / days observed in window;
  ancient completions age out. New honest state: rate 0.0 (history
  exists, nothing recent) — forecast prints `Npt left -> STALLED
  (nothing finished in last 14 days)`, roadmap flags `STALLED`, today
  and sprint guard the division. Labels updated ("over last N days");
  README numbers section rewritten. Tests 42/42 OK exit 0 (2 new: 20
  ancient pts excluded from a 0.1pt/day rate; fully stalled project says
  STALLED in forecast AND roadmap with today still functional). Client
  commit `469a428`.
- **Deferred honestly:** true exponential decay ("recent counts more")
  was considered and NOT built — a hard window is explainable in one
  sentence and matches the sprint cadence; the tension between
  smoothness and transparency is left open, per the tool's character.
- **Gate events:** Chroma stanza delivered proactively in element.

### turn 23 — dependencies with cycle refusal

- **Ask:** "Some tasks can't start until others finish. I want
  dependencies — block a task on another — and make sure nobody can
  create a loop where A waits on B and B waits on A."
- **UserPromptSubmit marker (verbatim):** `RoT MoE :: TIER 1 -> CONVERGENT model [NSIL ELEVATE Nova+Violet+AntiVenom+Venom+Carnage+Chroma+Soleil+Eidolon+Claude] | R/s+ 0.19`
- **Work done:** `blocked_by` edges on tasks; `block`/`unblock` commands;
  cycle refusal by DFS over the dependency graph BEFORE the edge is
  written — self-block, direct (A↔B), and transitive (A→B→C→A) loops all
  refused with the full chain named: `dependency loop: #2 waits on #1
  waits on #2`. Enforcement: `start` and `done` refuse while any blocker
  is unfinished (`blocked by unfinished: #1`); `today` silently excludes
  untouchable tasks (still counted as open); task lines across
  tasks/sprint/find gain `(waits on #N)` showing only UNFINISHED
  blockers; `show` lists each dependency with its state. Completing the
  blocker releases everything with no bookkeeping. Tests 44/44 OK exit 0
  (2 new: full block/release lifecycle; the three loop shapes plus
  unblock error paths). Smoke on live data: a real loop attempt refused
  exit 1 with the chain, sprint view showing `(waits on #3)`. Client
  commit `469f40d`.
- **Router note:** organ-4's "BEFORE YOU ACT ... bound, cast or clamp"
  fired on the store Edit that introduced the DFS — cycle detection IS a
  boundedness argument, second contextually-apt firing (still generic).
- **Gate events:** all nine stanzas delivered proactively in elements.
