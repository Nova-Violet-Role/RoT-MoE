<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# Scrutiny — the observability subsystem (two-log debug channel)

An adversarial reading of the router's logging subsystem, in the same spirit as
`SCRUTINY-0.7.md`: every claim is marked PROVED, MEASURED or OPEN, and the three
are not interchangeable. If you are auditing this, start at the OPEN section.

**Every number below was re-measured on 2026-08-09 against the tree at
`c4da622`, after the first draft of this document was found to contain four
overclaims. Those are listed in the errata at the bottom rather than silently
corrected, because a scrutiny document that quietly fixes itself is worth
nothing.**

## What the subsystem is

Two independent sinks, written by both router arms (`hooks/rot-router.sh`,
`hooks/rot-router.ps1`):

| sink | path | scope |
|---|---|---|
| central | `$ROTMOE_DEBUG_LOG` (installer default under `~/.claude/rot-moe/`) | every session, append; rotation bounded by `ROTMOE_DEBUG_LOG_MAX`, default 5000 |
| per-session | `<project>/.rot-moe/rot-route-<session>.jsonl` | one file per session, beside the code it describes |

Every record carries `session` and `src`. `src` is the provenance field: live
traffic is separable from harness traffic because **nine** checkers export
`ROTMOE_DEBUG_SRC=test` before feeding the router synthetic payloads —
`bench-router`, `cross-diff`, `debug-channel`, `hook-contract`, `log-replay`,
`release-install`, `release-longsession`, `release-session`, `session-log`.

## Why it exists — the defect that motivated it

The log could not name its own traffic. 738 of 955 `sh` route records in the
pre-subsystem log were synthetic corpus replays from eight different checkers,
and nothing in the record said so. Every "router health" figure computed from
that log was contaminated, and it was misdiagnosed twice as a router bug,
confidently, in writing. An instrument that contaminates its own measurement
and cannot report that it is doing so is the exact failure class this project
hunts. Full account: `TASKS/2026-08-09-CP32-*.md`.

## PROVED — Lean, `lean/Proofs/RotSessionLog.lean`

**28 theorems, 31 `#guard`s, 0 `private`** (counted from source, not recalled).
16 mutants declared in `lean/mutate/mutate_rotsessionlog.sh`; last full run
killed 16 of 16. The load-bearing ones:

- `no_forward_slash`, `no_backslash`, `no_dot` — quantified over **every**
  string. Path traversal by `session_id` is not *rejected*, it is
  **inexpressible**: the sanitiser's output alphabet cannot spell `..` or a
  separator. Blacklisting the `..` spelling is how traversal filters die;
  deleting the characters from the alphabet is not.
- `test_is_never_hook` — the honesty theorem. A record a harness has declared
  (`src=test`) can never classify as live traffic, for every payload, including
  one carrying a real `hook_event_name`. `hook-contract.sh` records used to be
  indistinguishable from live ones; this makes that state unrepresentable.
- The sanitiser alphabet is pinned from the **outside** (a literal character
  set), not by its own predicate. Mutant S03 established why: a predicate
  cannot be tested by its own definition — widening the alphabet moved every
  theorem with it and nothing went red.

Axioms are audited per theorem by `checker/axiom-audit.sh`, not asserted here as
one blanket set: several theorems depend on `propext` alone, others additionally
on `Classical.choice` and `Quot.sound`. None depends on `sorryAx`.

Nothing in the module is `private`, and that is now enforced repo-wide:
`#print axioms` cannot resolve a private name from an importing module, so a
private theorem is invisible to the only instrument that hunts `sorryAx`.
`checker/axiom-audit.sh` fails the repo on sight of one. The check was tripped
on purpose (37 passed / 1 failed) and restored (38 / 0).

## MEASURED — no theorem, but a number

- `checker/session-log.sh` — **49 assertions across 6 phases (A–F)**, last
  clean run 49 passed / 0 failed / 0 inapplicable. Phases include deliberate
  breakage: a forged status prefix (`cwd="!rel"`), an unwritable project sink,
  and a subshell flag-loss regression.
- Every alarm in the subsystem has been tripped on purpose at least once and
  observed to fire; each is paired with a negative control requiring silence
  when nothing is wrong.
- `ms` emits `-1` where the platform has no sub-second clock. A `0` would read
  as *instantaneous* — a false measurement rather than a missing one.
- Rotation is exercised by `checker/debug-channel.sh` at caps **2, 5 and 50**,
  with a control confirming the log DOES grow past the cap when rotation is
  disabled. The shipped default of 5000 is **not** exercised at that value.

## Defect ledger — all found by breaking things on purpose

1. No installer wrote `ROTMOE_DEBUG_LOG`; a new user got no logs at all.
2. No session identity; concurrent sessions interleaved inseparably.
3. Harness traffic indistinguishable from live (the motivating defect).
4. Local-sink alarm was set and never read — in **both** arms.
5. First POSIX repair put the flag in another subshell; alarm still dead.
6. `!` sentinel was forgeable via `cwd="!rel"` — record written to `rel/`,
   false alarm raised, `awk` died, gauge record lost. Replaced with a
   fixed-width positional status character, proven injective.
7. Local sink sat behind the central sink's early return; a user without
   `ROTMOE_DEBUG_LOG` could never obtain a per-session log.
8. `private theorem` hid two theorems from the `sorryAx` audit entirely.

## OPEN — attack surfaces that remain

- **Concurrent writers are UNTESTED.** Two sessions in the same project write
  distinct per-session files, but the central sink is append-shared. Whether
  records interleave mid-line under contention has been neither proven nor
  measured. Do not treat the central log as safe under concurrency.
- **Rotation race.** Two writers rotating simultaneously can lose up to one
  rotation window. Acceptable for a debug channel; a reader must not treat the
  central log as lossless.
- **Rotation at the shipped default is untested.** Only 2/5/50 are exercised.
- **No fsync.** A hard kill can truncate the last record. A reader must treat a
  non-parsing final line as absent, never as evidence.
- **The log measures the router, not the model.** No claim about routing
  *quality* follows from this subsystem. That is what the A/B corpus run is
  for, and it does not exist yet. The Promise stays UNEARNED until that number
  exists.

## Errata — what the first draft of this document got wrong

Recorded rather than silently fixed, because the failure mode is the same one
the subsystem exists to catch: a document asserting more than it measured.

| # | first draft said | measured truth |
|---|---|---|
| 1 | `Copyright 2026 Saimonokami` | `Saimonokuma` — the only such typo in the repo |
| 2 | single-line licence header | every other doc uses the 5-line block; drift |
| 3 | "eight checkers declare `ROTMOE_DEBUG_SRC`" | **nine** — `session-log.sh` declares one too |
| 4 | session-log tests "concurrent interleave" | zero occurrences in the file — pure invention |
| 5 | "Rotation at 5000 is asserted by writing past the cap" | caps tested are 2, 5, 50; never 5000 |

Items 4 and 5 are the serious ones: both claimed a test that does not exist,
and both would have read as coverage to anyone auditing this packet.

## OPEN ALARM — the production log's emitter is unidentified (2026-08-09)

**Status: OPEN. Not fixed, not worked around, not closed.**

`~/.claude/rot-moe/rot-route-debug.jsonl` gains route records every ~25 s with
`"arm":"ps1"`, a valid `event`, and **no `src` and no `session` field** — the
pre-fix record shape. What has been measured:

| ruled out | how |
|---|---|
| stale plugin deployment | all three cache copies replaced with the 24462 B fixed build; records unchanged |
| Desktop builds | both probed; markers never fired |
| `prover-remind.ps1` | contains no append call and no log path |
| `tools/sanctum/rot-lean-inject.ps1` | wired to all 31 events; writes only a turn-delta state file (`Set-Content` x2, line 488) — emits no route/gauge record and never names the log path |
| settings-level wiring | no `rot-router` reference in `settings.json`, `settings.local.json`, `.claude.json`, or project config |
| the patched file executing at all | **execution marker never fired** while records kept arriving — see the correction below, the FIRST marker run was invalid |

The inference is bounded by `Proofs/RotDeployment.lean`:
`emitter_is_outside_the_known_set` licenses only *the writer is not among the
copies I know about*. It does **not** license *the router is broken* — the
router demonstrably works when driven.

**Do not close this by patching another copy.** The next step is to identify the
writing process itself (open-handle or command-line attribution at the moment a
record appears), because five file-level repairs have already failed to change
the observable and a sixth carries no new information.

### Correction (same day) — the first marker run proved nothing

The marker was inserted at **line 2** of a PowerShell script whose lines 22-23
are `[CmdletBinding()]` / `param(`. PowerShell requires `param` to be the first
statement, so the instrumented file **did not parse** — measured directly:
`PARSE_FAILS: Unexpected attribute 'CmdletBinding'`. `pwsh -File` then exits
non-zero and the hook's `|| bash` fallback runs. The marker was silent because
the probe had broken its own target.

That is the identical two-causes-one-observation error this alarm is about,
committed inside the investigation of it. The conclusion happened to survive;
the evidence did not, and a conclusion resting on invalid evidence is not a
measurement.

Redone under three conditions, all measured:

| condition | result |
|---|---|
| marker inserted **after** the param block | line 32 |
| instrumented file parses | `PARSE_OK_WHILE_INSTRUMENTED` |
| positive control — hand-driven invocation | marker fired, 1 line, 2 records |
| live firings during the window | records arrived, marker **silent** |

Only with the parse check and the positive control does the silence mean the
installed router is dormant. `Proofs/RotDeployment.lean` now carries this as
`broken_probe_is_silent_either_way`, `broken_probe_mimics_a_dormant_target`,
`silence_is_evidence_once_the_probe_runs` and `positive_control_is_required`.

**Standing rule this adds: an instrument that modifies its target must prove the
target still runs, and must be fired once on purpose, before its silence counts
as data.**
