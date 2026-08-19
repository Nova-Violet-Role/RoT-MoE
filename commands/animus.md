---
name: animus
description: Run a task as a paired session -- a worker solving it while the deterministic observer injects the lens remark the worker forgot, mid-turn, and distils what it measured
---

# `/animus <task>` — self-distillation through hard study

Two agents in parallel. The **worker** solves the task. The **observer**
(`hooks/animus-observe.sh`) watches what the worker actually *does* — its
measured event stream, never its prose — and queues the missing perspective
into the worker's next event, spoken by the lens that owns it and tagged
`(animus)`. Every run appends what fired and what measurably changed to the
distillates, and the next run starts having studied them. Behavioral
learning; no weights touched.

The observer is **deterministic**: the router applied to the event stream.
Eight measured triggers, every threshold declared in `hooks/rot-voice.dtd`
(ENV.26–32), at most one remark per event and three per lens per run.

## How to run it

1. **Load the memory, global first.** Read
   `${XDG_STATE_HOME:-$HOME/.local/state}/rot-moe/animus-distillate.md`
   (if present), then the project's `.rot-moe/animus-distillate.md`
   (if present) — the specific overrides the general. Carry what they
   record into the worker's task context.

2. **Pick a session id** for the worker (any filename-safe token works —
   the hooks scrub it exactly as the router scrubs its own).

3. **Start the observer first**, from the project root, so no early event
   is missed:

   ```sh
   sh hooks/animus-observe.sh <session-id> --task "<the task text>" &
   ```

   Add `--watch` to narrate every record it classifies, not just firings.

4. **Run the worker with the ear armed** — same session id, and
   `ROTMOE_ANIMUS=1` in its environment:

   ```sh
   ROTMOE_ANIMUS=1 claude -p "<the task text>" --session-id <session-id>
   ```

   The router's PostToolUse arm consumes one queued remark per event and
   speaks it inside the owning lens's declared element:

   ```
   <rot:antivenom>⚪ AntiVenom (animus): the blank result has recurred 2x ...</rot:antivenom>
   ```

5. **When the worker finishes, stop the observer** (`kill %1`) and report:
   which remarks fired (the observer printed each one), and the measured
   next-action deltas the distillate now carries — quote them, do not
   paraphrase them.

## What the observer can catch, and on what evidence

| lens | fires on | threshold |
|---|---|---|
| AntiVenom | the same result anomaly recurring (the sentinel's own log line) | ENV.26, default 2 |
| Chroma | consecutive actions each costlier than the last | ENV.27, default 3 |
| Venom | prompt turns with no act between them | ENV.28, default 3 |
| Soleil | actions growing longer every time | ENV.29, default 3 |
| Eidolon | one lane+stem pair looping | ENV.30, default 4 |
| Violet | the task routes EMPATHIC, the stream never goes there | ENV.31, default 6 |
| Chroma | the task routes PREDICTIVE, the stream never goes there | ENV.31, default 6 |
| Claude | a PreToolUse whose Post never lands — the stall, caught on the run | ENV.32, default 120 s |

Silence is the healthy state: an uneventful run queues nothing, and an
empty queue is not a byte in the worker's context.

## Laws

* The observer never blocks the worker and never touches the Stop gate.
* A lens name outside the nine-element roster is refused and dropped.
* `ROTMOE_VOICE=0` silences remarks with the rest of the voice.
* The queue is rename-atomic on both sides; a half-written line cannot be
  read, and a consumed remark cannot resurrect.
* The distillates are the operator's data — read them, prune them, commit
  them nowhere (`.rot-moe/` self-gitignores).
* The contract holds all of it: `checker/voice-contract.sh` D14, both
  directions, negative controls included.
