# Changelog

All notable changes to **RoT MoE** are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) —
with one deliberate twist documented below.

**History lives in [`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md)** — every
release before the current one, unchanged. This file carries the current
release only, so *prior* and *after* stay one screen apart instead of eight
releases apart. `checker/repo-complete.sh` re-measures the counts in the newest
section against the source on every run, which is the reason that section must
not be buried.

---

## [Bonus] — CmdPulse — 2026-08-21

Not a version of the router. A standalone tool shipped alongside it, in
[`bonus/cmdpulse/`](bonus/cmdpulse/README.md), under the same licence.

### Added

- **CmdPulse** — a live progress bar for every Claude Code tool call, drawn in Claude Code's
  own status line. ETA against the learned median for each command signature; `over` in red
  past that median; a sweeping bar and `ETA ?` when fewer than two runs are recorded, because
  an estimate that does not exist should not be invented.
- Phase rows for the intervals that are not tool calls — compaction, a pending permission
  prompt, a subagent between calls. All 31 hook events wired; every row names what it is.
- Rolling history of the last N completed calls (`CMDPULSE_ROWS`, default 3, max 12).
- Opt-in live stdout streaming through `PreToolUse` `updatedInput`, with exit codes preserved
  by `exit ${PIPESTATUS[0]}` — verified against a command exiting 101, where the naive
  `| tee` form returns 0 and silently turns a failed build green.
- Split-pane dashboard and WezTerm status-bar renderer, both at 100 ms on their own clocks,
  plus an HTML inspector carrying the full input and output of every call.

### Notes

- Ships `refreshInterval: 3`. The status line floors at 1 s (`Math.max(1,t)*1000`) and a
  render slower than the interval is aborted by the next one, blanking the line entirely.
- Everything is local. No network, no telemetry. Requires `bash` and `jq`.

---

## [8.0.1] — 2026-08-20

**Patch: the gate learns to show its seals and to ask without demanding
theatre — and the armed sink comes back from the dead.** The Socio ran
the voice gate in a live session on the newest CLI (2.1.237) and reported
two defects: the seals never showed in the summoned stanzas, and after
the second Stop the gate "stopped working". Both were reproduced in real
three-turn sessions before a line changed, and both trace to the refusal
the gate speaks when it blocks a Stop. The ten-turn blind acceptance run
the Socio then ordered surfaced a third, older defect nobody had measured
— and it is the biggest of the three.

### Fixed — the seals ride the summons now

The router recorded a summons as `Name|element|charter|bound`; the DTD's
sigil never left the router, so the gate's refusal could not show it, and
a blind convening model — never once shown a seal — spoke correct but
sigil-less stanzas on every CLI version tested. Structural, not a
regression. Both router arms now write a fifth field,
`Name|element|charter|bound|sigil`, and the gate prints each missing
lens's seal beside its element (`<rot:nova> ⚜️ (Nova): …`). A four-field
row from a pre-8.0.1 router still parses; the seal simply goes unshown —
the gate never breaks on the old shape.

### Fixed — the refusal no longer reads as an order to fabricate

B4's pattern returned, one CLI generation later. Blocked over a trivial
turn, the 2.1.237-era convening model refused the old demand — *"I won't
manufacture three persona stanzas over nothing just executed or read"* —
on every turn of the live repro, and since the gate consumes its summons
on the block either way, the observable symptom was a gate that held the
door once and then went quiet: "stopped working after the second Stop."
The model was right, which is the point. W4 (in the gate's own header)
already ruled that the TAG is the measurable commitment and the words
inside it are the model's honour; the refusal now says so out loud — a
lens with nothing real to report satisfies the contract with one plain
line inside its element saying exactly that, and the closing format adds
to the user's request, never overrides it. Re-run live on 2.1.237 after
the patch: stanzas with seals on every turn, honest-empty where nothing
ran, and a fourth turn with a real tool call attributed truthfully — the
gate satisfied without a single fabricated claim.

### Fixed — every armed session ran sinkless; the fossil pin is retired

Found by the blind run: its Animus observer saw nothing for ten turns.
Six hypotheses died by controlled reproduction before the instrumented
rerun caught the router writing the summons and skipping the sink in the
same invocation — and the armed hook environment held the answer.
`hooks/settings-merge.js` had injected `ROTMOE_DEBUG_LOG=<config>/
rot-moe/rot-route-debug.jsonl` into the armed settings since 2026-08-09,
written when the sink was opt-in-only. 7.0.0 later gave the router its
per-session state-dir sink — the very file the Animus observer (organ 8)
pairs on — but SET wins over the default by design, the pinned directory
was never created, and the writability probe degraded the sink to OFF.
Every armed session since the pin existed ran with no sink at all; every
checker and the 8.0.0 paired probe invoked hooks directly, so none could
see it. Arm now retires exactly the pin it used to write (a user-chosen
value is kept byte-for-byte; the merge validator learned the one
sanctioned mutation, deletion-safe on both images), and the per-session
sink takes over. Re-run live: the sink grew every turn (188 lines, 94
route records), the observer queued remarks from measured triggers, the
queue file was consumed FIFO on camera, and the worker-side ear spoke
`(animus)` remarks into the envelope on three of five turns — the whole
of organ 8 alive in a blind session for the first time under ARM.

### Held — the contract grew six rows, each falsified first

`checker/voice-contract.sh` D10 now also holds: every summons row carries
five fields with a non-empty seal; the blocking refusal shows the seals
beside their elements; and the refusal carries the honest-empty sanction.
A new D15 holds the pin's retirement in both directions: a fresh arm
writes no sink pin, a re-arm retires the pre-8.0.1 pin, and a user-chosen
`ROTMOE_DEBUG_LOG` survives untouched. All six were made to fail before
being trusted — a four-field summons file fails the row check, the
pre-patch gate fails both wording checks, and the pre-patch merger,
run against D15's own probe, injects the pin and goes red.
