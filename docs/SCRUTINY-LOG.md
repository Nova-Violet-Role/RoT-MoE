<!-- This file is part of RoT MoE. SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2. Copyright 2026 Saimonokami. -->

# Scrutiny — the observability subsystem (two-log debug channel)

An adversarial reading of the router's logging subsystem, written by the person
who built it, in the same spirit as SCRUTINY-0.7.md: every claim here is either
measured or marked OPEN. If you are auditing this repo, start from the attack
surfaces at the bottom, not from the feature list at the top.

## What the subsystem is

Two independent sinks, written by both router arms (`hooks/rot-router.sh`,
`hooks/rot-router.ps1`):

| sink | path | scope |
|---|---|---|
| central | `$ROTMOE_DEBUG_LOG` (installer default: `~/.claude/rot-moe/`) | every session, rotates at 5000 records |
| per-session | `<project>/.rot-moe/rot-route-<session>.jsonl` | one file per session, beside the code it describes |

Every record carries `session` and `src`. `src` is the provenance field: live
traffic is distinguishable from harness traffic because eight checkers declare
`ROTMOE_DEBUG_SRC=test` before feeding the router synthetic payloads.

## Why it exists — the defect that motivated it

The log could not name its own traffic. 738 of 955 `sh` route records in the
pre-subsystem log were synthetic corpus replays from eight different checkers,
and nothing in the record said so. Every "router health" figure computed from
that log was contaminated, and the maintainer (me) misdiagnosed the
contamination twice as a router bug, confidently, in writing. An instrument
that contaminates its own measurement and cannot report it is the exact failure
class this project hunts. Full account: `TASKS/2026-08-09-CP32-*.md`.

## What is proven (Lean, `lean/Proofs/RotSessionLog.lean`)

28 theorems, 31 `#guard`s, 16/16 mutants killed. The load-bearing ones:

- `no_forward_slash`, `no_backslash`, `no_dot` — quantified over **every**
  string. Path traversal by `session_id` is not *rejected*, it is
  **inexpressible**: the sanitiser's output alphabet cannot spell `..` or a
  separator. Blacklisting the `..` spelling is how traversal filters die;
  deleting the characters is not.
- `test_is_never_hook` — the honesty theorem. A record a harness has declared
  (`src=test`) can never classify as live traffic, for every payload,
  including one carrying a real `hook_event_name`. `hook-contract.sh` records
  used to be indistinguishable from the real thing; this makes that state
  unrepresentable.
- The sanitiser alphabet is pinned from the *outside* (a literal character
  set), not by its own predicate — because mutant S03 proved a predicate
  cannot be tested by its own definition: it widened the alphabet and every
  theorem moved with it.

`#print axioms` on the module: `propext, Classical.choice, Quot.sound` — and
nothing is `private`, because `#print axioms` cannot resolve private names
from an importing module. `checker/axiom-audit.sh` fails the repo if any
module contains `private theorem`; that check has been tripped on purpose
(37/1) and restored (38/0).

## What is measured, not proven

- `checker/session-log.sh` — 49 assertions across 6 phases, including
  deliberate breakage: forged `!` sentinel, missing env, subshell flag loss,
  concurrent interleave. Every alarm in the subsystem has been tripped on
  purpose at least once.
- Rotation at 5000 is asserted by writing past the cap and counting.
- `ms` emits `-1` where the platform has no sub-second clock. A `0` would
  read as *instantaneous* — a false measurement, not a missing one.

## Defect ledger (all found by breaking things, all mine)

1. No installer wrote `ROTMOE_DEBUG_LOG`; a new user got no logs at all.
2. No session identity; concurrent sessions interleaved inseparably.
3. Harness traffic indistinguishable from live (the motivating defect).
4. Local sink alarm was set and never read — in **both** arms.
5. First POSIX repair put the flag in another subshell; alarm still dead.
6. `!` sentinel was forgeable via `cwd="!rel"` — record written to `rel/`,
   false alarm, `awk` death, gauge lost. Now a fixed-width positional status
   char, proven injective.
7. Local sink sat behind the central sink's early return; user without
   `ROTMOE_DEBUG_LOG` could never get a per-session log.
8. `private theorem` hid two theorems from the sorryAx audit entirely.

## OPEN — attack surfaces that remain

- **Single-writer assumption.** Two concurrent sessions in the *same* project
  write distinct per-session files, but the central sink is append-shared.
  Append atomicity is assumed at the OS level for records under PIPE_BUF;
  records above it could interleave mid-line. Not proven, not measured.
- **Rotation race.** Two writers rotating simultaneously can drop up to one
  rotation window. Considered acceptable for a debug channel; a reader must
  not treat the central log as lossless.
- **No fsync.** A hard kill can truncate the last record. Readers must treat
  a non-parsing final line as absent, not as evidence.
- **The log measures the router, not the model.** No claim about routing
  *quality* can come from this subsystem alone; that is what the A/B corpus
  run is for, and it does not exist yet. The Promise remains UNEARNED until
  that number exists.
