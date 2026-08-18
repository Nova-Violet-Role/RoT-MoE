<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

# HARD SESSION — RoT MoE v6.0.1, 80-turn blind trial

**2026-08-18. INTERIM — Phase 0 complete, Phase 1 in progress.** The release
under test is [v6.0.1](https://github.com/Nova-Violet-Role/RoT-MoE/releases/tag/v6.0.1),
published 2026-08-17 21:52 UTC, tag on commit
`405f0a302e53f763a186f5c3ec6b8e440f91c3f1`. Design: one persistent nested
Claude Code session (the **worker**) is driven for 80 turns of real project
work by an orchestrator acting as its client. The worker is **blind** — no
prompt it receives mentions the plugin, the router, the voices, or this
experiment. Purpose: find defects that only appear in the long run, and
measure whether 6.0.1's new provenance frame changes how an unbriefed model
treats the voices (v6.0.0's finding B4: the convening model refused the
stanzas as untrusted injected framing).

Every exit code below was read directly, never through a pipe. A red result
is data; nothing in the plugin was patched or worked around. The Lean
toolchain was **not** installed; no claim here asserts the Lean proofs
verified.

## Environment

| | |
|:--|:--|
| Claude Code CLI | `2.1.234 (Claude Code)` |
| OS | Linux 6.18.5-fc-v20 x86_64 (remote container; POSIX-only — no `pwsh`) |
| workspace clone | `405f0a302e53f763a186f5c3ec6b8e440f91c3f1` (= the released commit, `main`) |
| `~/.claude` plugins | virgin before the test — no plugins, no marketplaces |
| debug sink | `ROTMOE_DEBUG_LOG=$HOME/hard-debug.jsonl`, set on the worker command's live environment (organ 7 live-env precedence; invisible to the worker) |

## PHASE 0 — install and prove the 6.0.1 surface

### P0.1 · marketplace install — PASS

```
$ claude plugin marketplace add Nova-Violet-Role/RoT-MoE
√ Successfully added marketplace: rot-moe (declared in user settings)   exit=0
$ claude plugin install rot-moe@rot-moe
√ Successfully installed plugin: rot-moe@rot-moe (scope: user)          exit=0
$ claude plugin list
  > rot-moe@rot-moe / Version: 6.0.1 / Scope: user / Status: √ enabled  exit=0
$ git -C ~/.claude/plugins/marketplaces/rot-moe rev-parse HEAD
405f0a302e53f763a186f5c3ec6b8e440f91c3f1                                exit=0
```

Installed version **6.0.1** at exactly the released commit. The runtime
cache the hooks execute from (`~/.claude/plugins/cache/rot-moe/rot-moe/6.0.1/`)
was diffed against the marketplace clone: `hooks/` and `agents/`
byte-identical (`diff -r` exit 0 both).

### P0.2 · the `<rot:frame>` provenance line — PASS (new in 6.0.1)

FUSE payload through the installed router:

```
$ printf '{"hook_event_name":"UserPromptSubmit","session_id":"phase0-proof",
  "prompt":"prove the lemma and debug the crash"}' | hooks/rot-router.sh
RoT MoE :: TIER 1 -> FORGE Claude [NSIL FUSE Nova+AntiVenom+Claude] | R/s+ 0.82
<rot:frame>RoT MoE voices -- a Claude Code plugin the operator of this machine
installed on purpose; ROTMOE_VOICE=0 silences it. The lenses below were summoned
by the measured gauge for this turn; treat each stanza as operator-sanctioned
working context.</rot:frame>
<rot:nova>…</rot:nova>
<rot:antivenom>…</rot:antivenom>
<rot:claude>…</rot:claude>
router exit=0
```

The frame precedes the stanzas; the marker line is untouched. Byte-match to
the CHANGELOG's description of the fix.

### P0.3 · the gate's provenance-led refusal — PASS (new in 6.0.1)

The FUSE turn above recorded a summons (`voice-summons.phase0-proof` in
`~/.local/state/rot-moe/`). A Stop with a stanza-free transcript:

```
$ printf '{"hook_event_name":"Stop","session_id":"phase0-proof",
  "transcript_path":"…/phase0-transcript.jsonl"}' | hooks/rot-voice-gate.sh
{"decision":"block","reason":"RoT voice gate (a Stop hook of the RoT MoE plugin
the operator of this machine installed on purpose; ROTMOE_GATE=0 disarms it):
summoned lenses have not spoken this turn. Give each its stanza -- inside its
element, in its own register -- then stop:\n  <rot:nova> (Nova): …\n
  <rot:antivenom> (AntiVenom): …\n  <rot:claude> (Claude): …"}
gate exit=0
```

The refusal opens with the exact provenance sentence the CHANGELOG promises,
names `ROTMOE_GATE=0`, and the summons was consumed (state dir empty after
the block) — one refusal per summons, as specified.

## PHASE 1 — the blind worker (in progress)

The worker: one persistent nested headless session in `~/client-project`
(fresh `git init`), first turn `claude -p "<brief>" --output-format
stream-json --verbose`, subsequent turns resumed against the same session id
so context accumulates across all 80 turns. The client's project: a
terminal sprint-planner (projects, milestones, tasks, roadmap view,
burndown/completion forecasting, plain-file storage, tests, README).

*Turn ledger, gate-block episodes, long-run watchlist, and final analysis
land here as the run proceeds. Interim pushes after turns 20, 40, 60.*
