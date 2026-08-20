<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

# 8.0.1 — two defects, live-reproduced, live-accepted (CLI 2.1.237)

The Socio's live report, verbatim symptoms: *"after the 2° stop hook it
stopped working. also the Seals didn't show."* Both reproduced in real
sessions before a line changed. The acceptance campaign the Socio then
ordered — a ten-turn blind run with a real objective — surfaced a third,
older defect nobody had ever measured. All three fixed; the final
five-turn blind run shows every organ live at once. Method throughout:
a scratch `CLAUDE_CONFIG_DIR`, `ARM_ROUTER.sh` from the tree under test,
one real session driven by `claude -p --session-id/--resume`, hooks debug
captured per turn, a private `ROTMOE_STATE_DIR`.

## Defect 1 — the refusal read as an order to fabricate

Three FUSE turns, same prompts, two CLIs, before the patch:

| | CLI 2.1.236 | CLI 2.1.237 |
|---|---|---|
| gate blocks the Stop | yes, every turn | yes, every turn |
| model's answer to the refusal | stanzas, every turn | **refusal, every turn** |

The 2.1.237 model's own words: *"I won't manufacture three persona
stanzas over nothing just executed or read."* B4's pattern (v6.0.0 real
test), one CLI generation later — and the model was right: the old demand
over an empty turn reads as an order to fabricate. The gate consumes its
summons on the block either way, so the live symptom was a gate that held
the door once and then went quiet: "stopped working after the second
Stop." Fix: the refusal now states W4's own ruling out loud — one plain
honest line inside the element satisfies the contract, and the closing
format adds to the user's request, never overrides it.

## Defect 2 — the seals never left the router

Summons rows carried four fields (`Name|element|charter|bound`); the
DTD's sigil never reached the gate, the refusal could not show it, and a
blind model spoke sigil-less stanzas on every CLI tested — it had never
once been shown a seal. Structural, not a regression. Fix: both router
arms write a fifth field, the gate prints each missing lens's seal beside
its element; four-field rows from an older router still parse.

## Defect 3 — every armed session ran sinkless (found by the blind run)

The ten-turn acceptance run's Animus observer saw nothing all run. Six
hypotheses were exonerated by controlled reproduction — env propagation
(a tracer var reached the hook), hook env content (134 keys captured and
replayed), `ROTMOE_ANIMUS=1`, the armed command verbatim, `--session-id`,
repo cwd — every isolated probe wrote the sink. The instrumented rerun
then caught the contradiction in one frame: the router wrote the summons
and skipped the sink in the same invocation. The armed hook env held the
answer: `ROTMOE_DEBUG_LOG=<config>/rot-moe/rot-route-debug.jsonl` — a pin
`settings-merge.js` had injected at arm time since 2026-08-09, written
when the sink was opt-in-only. 7.0.0 later gave the router a per-session
default in the state directory — the file the Animus observer pairs on —
but SET wins over the default by design, the pinned directory was never
created, the writability probe failed, and the sink degraded to OFF.
**Every armed session since the pin existed ran with no sink at all**;
every checker and the 8.0.0 paired probe invoked hooks directly, so none
of them could see it. Fix: arm retires its own pin (a user-chosen value
is kept, byte-for-byte, and the merge validator learned the one
sanctioned mutation); the per-session sink takes over. Held by
`checker/voice-contract.sh` D15, three rows — no pin on fresh arm, old
pin retired on re-arm, user value kept — with the pre-patch merger
measured to fail row one.

## Acceptance — the final five-turn blind run (all on CLI 2.1.237)

Armed by the fixed installer (pin count in settings: 0), observer paired,
repo-context session, real objective, nothing invoked by user or model:

- sink live and growing every turn: 38 → 88 → 148 → 170 → 188 lines,
  94 `route` records across all nine event kinds that fired
- observer queued remarks from measured triggers; the queue file appears
  after turn 2 and is consumed by turn 3 — the rename-atomic FIFO
  lifecycle on camera
- the worker-side ear spoke `(animus)` remarks into the envelope on
  turns 2, 3 and 4 (3 / 12 / 3 occurrences)
- the global distillate grew from a bare header to 13 lines (the
  project-tier copy went unmeasured: the audit deleted the scratch
  `.rot-moe/` before reading it — a measurement loss, not a defect)
- gate blocked turns 1, 2, 4; seal-bearing stanzas followed each block —
  and turn 5 closed with four seals and **no block at all**, the model
  speaking the register unprompted
- objective: 6/6 tests pass; 20/20 hook completions status 0; repository
  untouched

The earlier ten-turn run (same shape, pre-fix installer) already showed
the gate side at scale: 8 blocks on exactly the 8 multi-lens turns,
seal-bearing stanzas on all 8 with rosters tracking turn content, the 2
mono-lens turns correctly unblocked, 64/64 hook completions clean, and
the CLI's own 31-event array matching `checker/cli-hook-events.txt` byte
for byte.

## A measured boundary, stated honestly

In a bare directory with no project context, the 2.1.237-era model
declines the persona format wholesale as suspected injection — even when
a minimal project CLAUDE.md sanctions it — while doing the real work
perfectly (its ten-turn bare-dir session built and passed everything).
The same model, same day, complies on every turn in a repo whose context
documents the plugin. The gate's design already answers this: one refusal
per turn, degrade open, never a cage — the session is never harmed. No
wording will be added to argue with a model's injection defense; the
briefed-project path is the supported one.
