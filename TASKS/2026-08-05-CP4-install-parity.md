<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# CP4 — the two install paths were delivering different products

Checkpoint Resumee, 2026-08-05. Every claim below names the instrument that
produced it. Nothing here is inferred from a green build alone.

## The defect, stated first

RoT MoE has two documented installs. They had silently diverged:

| path | events | bindings |
|---|---|---|
| marketplace / plugin (`hooks/hooks.json`) | 3 | 5 — `rot-router` ×2, `prover-remind` ×3 |
| `ARM_ROUTER.sh` / `.ps1` | 2 | 2 — `rot-router` only |

A grep for `prover-remind` across both installer arms, both Lean setup scripts
and `hooks/settings-merge.js` returned **nothing**. No installer had ever wired
it. A user installing by hand therefore received a product with **no proof
reminder at all** and **no `PostToolUse` binding of any kind** — including the
staleness fix this very release shipped.

Why no check caught it: every installer test in the repository asserted things
about the *router*, which was present the whole time. Nothing compared the two
paths **to each other**.

## What changed

| file | change |
|---|---|
| `hooks/settings-merge.js` | event list is now a **parameter** (4th arg, default unchanged); `disarm-any` predicate widened to `(rot-router\|prover-remind)` |
| `ARM_ROUTER.sh` / `.ps1` | wire `prover-remind` on three events; a reminder failure rolls the whole install back |
| `DISARM_ROUTER.sh` / `.ps1` | exact mode now removes **every** string the installer writes, not one |
| `checker/install-parity.sh` | **new gate** — the (event, script) set of the plugin must equal the installer's |
| `checker/install-roundtrip.sh` | one assertion **restated**, see below |
| `lean/Proofs/RotInstall.lean` | install **plans**: 8 new theorems, 11 `#guard`s |
| `lean/mutate/mutate_rotinstall.sh` | 6 new mutants; two stale needle counts repaired |
| `lean/Proofs/RotGates.lean` | 34 gates / 12 deep |

## A spec that was wrong, and was not deleted

`install-roundtrip.sh` asserted *"the user's empty group was not tidied"* by
comparing the whole `PostToolUse` key against pre-install. That encoded a
**contingent fact** — "the installer never touches `PostToolUse`" — as if it were
the invariant it was named for. Wiring the reminder there, a correct change, made
it fail; the tempting repair was to delete the check.

It was **restated**, not removed: the user's group must survive verbatim and
every group we add must invoke only RoT MoE hooks. That holds however many
events the installer grows into. 27 passed / 2 failed → **29 passed / 0 failed**.

## Measurements

| instrument | result |
|---|---|
| `bash checker/install-parity.sh` | **exit 0** — 8 passed, 0 failed |
| same, with `REMIND_EVENTS_CSV` mutated to drop `PostToolUse` | **exit 1** — the gate catches the original defect |
| `bash checker/install-roundtrip.sh` | **exit 0** — 29 checks |
| `ARM_ROUTER.sh` on a clean config | 5 bindings / 3 events |
| `ARM_ROUTER.ps1` on a clean config | 5 bindings / 3 events, **byte-identical** to the POSIX arm |
| `DISARM_ROUTER.sh` (default, exact) | 5 entries → **0**, valid JSON |
| `lake build Proofs.RotInstall` | **exit 0**, read directly |
| `lake env leanchecker Proofs.RotInstall` | **exit 0** — kernel re-verified |
| `#print axioms` on all 5 new theorems | `propext`, `Classical.choice`, `Quot.sound` — **no `sorryAx`** |
| `mutate_rotinstall.sh` | **16 killed, 0 survived, 0 discarded** |
| all 13 mutation suites, by hand | **101 applied, 101 killed, 0 survived, 0 discarded** |
| `gate-all.sh --fast` | **ALL 22 GATES GREEN** |

Two mutants had gone **DISCARDED** (needle `scalar := s.scalar` went from 2
occurrences to 4 when the plan definitions landed). That is the harness saying
*"I tested nothing"*, not *"the code is fine"*. Both readings were repaired: the
counts, **and** the two missing theorems — `armPlan_preserves_all_scalars` and
`disarmPlan_preserves_all_scalars`. A new definition inherits none of the old
theorems' coverage.

## Counts synced from source

`269` theorems across `18` modules (was 249/18); `13` suites, `46` checkers.
Updated in `README.md`, `CITATION.cff`, both plugin manifests, `CHANGELOG.md`
and the `STATUS.md` verdict block. `repo-complete.sh` → **exit 0**.

## NEXT

1. `gate-all.sh` bare (all 34 gates, deep tier included) — the fast sweep is
   green but 12 deep gates have not run against these edits.
2. Deliver `RotInstall.lean` + `RotEnsemble.lean` to `D:\Lean\proofs\Proofs\RotMoE\`
   and build there (that tree pins the same toolchain; a red module in the shared
   tree breaks every other session).
3. **CTT test phase, before any push** — clean reinstall into
   `C:\Users\Saimono\Claude_Test`, confirm the installed plugin now registers all
   five bindings, and that `ARM_ROUTER` still refuses when the plugin is live.
4. Commit, then re-tag `v0.7.0/1/2` onto the new commit.
5. Push to `Nova-Violet-Role/RoT-MoE` only after 3 succeeds.
6. Still open: the `Claude = AntiVenom ∨ Soleil` weld in the activity table —
   repair needs a behaviour decision, not a proof.
7. Still unverified: GitHub CI conclusion for `b36da63` (API rate-limited, `gh`
   absent).
