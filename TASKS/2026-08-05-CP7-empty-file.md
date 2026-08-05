<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# CP7 — the shipped router was emptied, and 22 gates called it green

Checkpoint Resumee, 2026-08-05. Every claim names its instrument.

## The headline

**All four CI jobs green on `84e07cd`** — `checkers` on ubuntu, macOS and
windows, and `lean -- build, axioms, kernel re-check`. macOS had never been green
before. `v0.7.0`, `v0.7.1`, `v0.7.2` now resolve to that commit on the remote,
verified by `git ls-remote`.

Then a bounded sweep emptied three shipped hooks and the fast tier did not
notice.

## The worst failure this repo has produced

A bare `gate-all` run was wrapped in an external `timeout`. **`timeout` signals
its direct child** — gate-all — and `checker/mutate-checker.sh`, which gate-all
had already started, was **orphaned rather than signalled**. Its `EXIT INT TERM`
trap never fired. The process was later killed outright.

```
hooks/rot-router.sh       0 bytes
hooks/prover-remind.sh    0 bytes
hooks/prover-remind.ps1   0 bytes
.mutbak files             NONE
```

Emptying a file **is one of that harness's mutants**. So the tree carried a live
mutant with the evidence deleted — and gate-all's existing refusal keys on a
*surviving* `.mutbak`, which is exactly what was missing.

**Two fast sweeps then returned ALL 22 GATES GREEN.** Every fast gate reads
source *text*, and an empty file contains no offending text. A deep gate that
*executes* the router caught it, with a message that was honest and unhelpful:

```
NO row produces output -- an arm that never speaks would pass this suite
```

Restored from `84e07cd` and verified **functional**, not merely present:

```
$ sh hooks/rot-router.sh --vector 0,1,0,0,0,0,0,0,0 --breadth 1
R/s+ = 0.31 [BELOW RANGE] mean=0.111 breadth=1 K=9 lenses=Violet
```

## Two guards

| guard | what it refuses | control |
|---|---|---|
| `gate-all` PREFLIGHT 1b | any **tracked file that is empty**, in every mode, before any gate runs | planted empty file → **exit 2**, read directly; clean → exit 0, 22 green |
| `mutate-checker` restore verification | reporting a result unless all four touched files are non-empty **and** byte-identical to git | both halves fire on a planted empty file; real run: killed=16, hooks 0 modified |

A trap cannot be made to fire for `SIGKILL`. What can be done is refuse to
*report success* without checking. `mutate-checker` deliberately does **not**
repair the tree itself — that would hide the interruption that caused it.

The first reading of control 1 came through `| head` and said `0`. **The pipe
hazard, in the middle of the commit that exists because of hidden failures.**
Re-measured directly: exit 2.

## Eidolon-gating the ninth lens does not fix it

The open defect was `actClaude = actAntiVenom || actSoleil` — the vector carries
**eight** bits and calls itself nine. Two repairs were on the table; section 3h
of `RotEnsemble.lean` decides between them by proof, and the answer is not the
one that was expected.

The property is stated over an **arbitrary** ninth function, not today's formula:

```lean
NinthIsIndependent f := ∃ s t, eightAgree s t ∧ f s ≠ f t
```

| theorem | says |
|---|---|
| `current_ninth_is_not_independent` | the shipped formula **fails** it |
| `gated_differs_from_current` | Eidolon-gating **is** a real behaviour change |
| `gated_is_still_not_independent` | **and it changes nothing that matters** |
| `own_signal_restores_independence` | a **tenth** measured bit does fix it |
| `own_signal_differs_from_current` | and is not the old one wearing a hat |

Gating a disjunction of two dependent activities on a **third dependent
activity** yields a third dependent activity. Eidolon's licence changes *when*
the fusion fires, never whether the ninth reading carries information the other
eight lack.

The other candidate is not a re-wiring either: `Signals` has nine fields and
every one is claimed, so an own signal means a **tenth measured bit**. That is a
change to the injector and it is **not made here** — the spec now says which
repair would work and why the cheaper one would not.

## Measurements

| instrument | result |
|---|---|
| CI all four jobs on `84e07cd` | **success** |
| tags on remote | all three → `84e07cd` |
| `gate-all --fast` | ALL 22 GREEN |
| all 12 deep gates, by hand | exit 0 |
| `generalization-probe` | 10 passed |
| `deferred-closure` | 16 passed — **closes** now, no longer SKIP |
| `mutate-checker` | killed=16, survived=0, discarded=0 |
| `mutate_rotensemble.sh` | **11 killed**, 0 survived, 0 discarded |
| `lake build Proofs.RotEnsemble` | exit 0, read directly |
| `#print axioms` × 5 new | `propext`, or **no axioms** (3 by `decide`) |
| `leanchecker` (local + delivered) | exit 0, zero bytes |
| negative control | exit 1, read directly |
| `#eval` | `(true, false, true)` — the three candidates on two turns |

Counts resynced from source: **281 theorems / 18 modules / 14 suites / 46
checkers**; **116 mutants applied, 116 killed**.

## One honest loose end

`ci-dryrun --from 28 --to 54` exited **1 once** and **0 on three subsequent
runs** with nothing changed in between. Not reproduced, not attributed, and
**not called fixed**. The annotation emitter is present in that checker, so a
recurrence in CI will name the step rather than printing an exit code.

## CTT, before every push

Reinstalled from the local marketplace each time; every probed file matched the
tree, including a byte-size check on the router after the emptying incident
(20797 bytes). Lanes routed to their pinned `R/s+` on every run — Eidolon 0.45,
Claude 0.66, AntiVenom 0.57, Nova 0.47, Soleil 0.39. One firing per prompt. Live
CTT `settings.json` byte-identical to its backup throughout.

## NEXT

1. Confirm CI on `95c4f6d`; if green, move the three tags onto it.
2. **Never wrap `gate-all` in an external `timeout` again** — run the fast tier
   and then the deep gates individually. The kill does not reach the child, and
   the child is the thing holding a mutated tree.
3. Re-run `ci-dryrun --from 28 --to 54` a few more times when there is budget,
   to either reproduce the single failure or retire it as noise.
4. The ninth-lens repair now needs a **decision, not a proof**: a tenth measured
   bit for Claude in `rot-lean-inject.ps1`. The spec already says gating will not
   do.
