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

## [10.0.0] — 2026-08-27

**Major: the observer is driven by the measured gauge, not by seven fixed
integers.** `10.0.0` core · `10.0.1` lean · `10.0.2` unsealed, published
separately, cut from this one commit and differing by archive content only.

The router was already writing a `"kind":"gauge"` record beside every route
line — K, mean, breadth, M/C/T, sum, R/s+, active, and each of the nine lenses
with lambda, mu, a, delta, sigma, H and term. The observer read none of it and
decided when a lens should speak from lens names painted on if-statements:
out-of-band and behavioural, but not RoT MoE. This release closes that gap,
which is a behavioural change to the speaking condition — hence the major.

### Changed — the seven integers became bases

- `hooks/animus-observe.sh` decided when a lens should speak from seven
  hardcoded integers (`AN_N=2` `COST_N=3` `DITHER_N=3` `BLOAT_N=3` `LOOP_N=4`
  `TEXT_N=6` `STALL_S=120`). Each is now a BASE, divided by the electing lens's
  measured share of its gauge line: a starved lens earns one remark, a lens
  carrying the session earns up to six.
- `STALL_S` is scaled the same way but **floored at 45 s**, because a false
  stall is a lie told in a lens's own voice.
- On Stop, and only on Stop, the turn is read backwards: nine candidate
  findings, each scored by the weight the gauge actually gave the lens that
  would speak it, at most two spoken and the remainder written to the
  distillate.

### Added — the Nushell lane ships, first in dispatch

- Five hooks in Nushell (`prover-remind.nu`, `rot-env.nu`, `rot-profile.nu`,
  `rot-router.nu`, `rot-voice-gate.nu`, +2431 lines) are now tracked and
  SPDX-covered. `hooks/hooks.json` dispatch order is now `nu` → `pwsh` → `bash`;
  hosts without the `nu` binary fall through unchanged.
- `lean/Proofs/RotCostBudget.lean` grew `wallBoundMs` and its separation
  theorems. Theorem count 1809 → 1813, measured by `checker/count-theorems.sh`;
  `plugin.json` and `marketplace.json` restate the measured number.

### Fixed — fused lenses were credited with zero elections

- `active` is a comma-joined set during NSIL FUSE. Membership was tested
  against single names only, so every fused lens was credited with zero
  elections and then accused of starving. Split on commas, credit each name.
- `checker/bench-router.sh` phase 2 gated wall clock against `msBound`, the
  router's spawn budget. Wall contains the host's interpreter startup: measured
  2026-08-28, 509–528 ms wall against 117–146 ms in-script with an unmoved
  spawn count. Wall now gates against `wallBoundMs`; the code claim is printed,
  not enforced; the spawn check judges the code. Proved in RotCostBudget
  (`the_wall_ceiling_cannot_replace_the_spawn_check` and three siblings).
- `checker/ci-dryrun.sh` split `git ls-files -s` output on whitespace, so four
  executable paths containing a space were truncated and the mode assertion
  went red by exactly four. The path is now taken from the TAB-delimited field.

### Measured — a 4781-record replay of a live session sink

- 2390 gauge records parsed; 170 remarks over 52 turns, never 3 in one turn.
- 189 verdicts written; 8 of 9 lenses fired unforced. Carnage's condition (one
  lens elected on ≥80% of ≥5 readings) was forced on a fixture and observed
  firing, so all 9 are reachable.
- Starved-lens claims re-derived by an independent JSON parser: 93 of 93 true.
- A gauge-blinded mutation control differs from this build by 237 remark lines,
  which is what makes the wiring load-bearing rather than asserted.

### Notes

- `hooks/rot-voice.dtd` ENV.26-32 now describe the bases as scaled by measured
  share rather than as constants, and `engine/rot.env.example` was regenerated
  from the DTD through `checker/env-wiring.sh --emit` — no env var added or
  removed.
- The `.nu` files require the `nu` binary; PowerShell 7 cannot parse them.
  Dispatch probes for `nu` and falls back, so no host that could run 9.0.1 is
  worse off.

---

## [9.0.1] — 2026-08-21

**The tier is the patch digit again — and the audit that earned the release.**
`9.0.0` core · **`9.0.1` lean** · `9.0.2` unsealed, published separately. `9.0.1`
is what `/plugin install` serves: the verification surface is the point of this
project, so the default carries it.

### Fixed — two RED, found by audit and each proven load-bearing by mutation

- **R1** both PowerShell arms emitted OEM best-fit garbage for every non-ASCII
  byte (`⚜️`→`??`, `λ`→`?`, `·`→`0xFA`). One pinned encoding per arm. Reverting
  the pin turns `cross-diff` red — mutation-proven, not asserted.
- **R2** the project path was normalised BEFORE the `$PWD` fallback. Reordered.
  **Stated honestly: the live corruption was real, its mechanism was NOT
  reproducible from any shell, and the reorder is kept as a safety property
  rather than a reproduced fix.**

### Fixed — instrument and latent defects

- **R3** the CI audit judged whatever run came back; it now NAMES its workflow
  and refuses (exit 2) if that workflow is absent. Steps read: 5 → **221**.
- **O1** byte-wise locale for the DTD reader, bound to the declaration.
- **O2** the sink-retirement check asked node for its own path. `voice-contract`
  46/1 → **47/0**.
- **O3** an unbound "26 checks" claim removed from three README spots — **and a
  guard added**, because replanting it was previously undetected.
- **O5 / O5b** the licence gate had never opened a `.js`, and `bonus/` shipped
  **six unlicensed files**. 287 → **318** source files, 0 missing a header.
- **O6** every hook command ran BOTH arms when the ps1 arm failed
  (`A && B || C`). All 63 rewritten to the conditional form; installers carry
  legacy strings so an old arm still disarms.
- **Y1** path equality is not string equality — a pin this installer wrote
  survived `arm` under a different true spelling of the same directory.
- **Y5** cross-diff never reached the payload path. **Y6** the ps1 sink wrote
  CRLF into `.jsonl`. **Y7** dead `ROT_PROFILE` removed from both arms.
  **Y8** three deliberate control bytes documented. **Y10** the arm fallback
  finally has a checker — shape AND behaviour.

### Verified

87/87 modules kernel re-verified · **797/797 mutants killed, 0 survived** ·
1632 theorems · **0 sorry** · 31 hook events / 63 entries all execute ·
Animus consume-and-emit proven with five controls · 190 `.sh` files,
0 syntax failures, error tier cleared · two separate Claude Code 2.1.238
scratchpad sessions wrote their own sinks and fired 10 distinct hook events.

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
