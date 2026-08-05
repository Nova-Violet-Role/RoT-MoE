<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# CP2 — three Lean modules, four gates, and 82 mutants measured by hand

Date: 2026-08-04 · branch `main` · baseline commit `be55414` · nothing committed yet

Every line names its instrument. Exit codes were read **directly**, never through
a pipe.

---

## Lean — three new modules, all green, all kernel-re-verified

| module | theorems | `lake build` | `#print axioms` | `leanchecker` |
|---|---|---|---|---|
| `RotDuplicate.lean` | 10 | exit 0, 0 warnings | no `sorryAx` | exit 0 |
| `RotScan.lean` | 14 | exit 0, 0 warnings | no `sorryAx` | exit 0 |
| `RotLog.lean` | 12 | exit 0, 0 warnings | no `sorryAx` | exit 0 |

Negative control for the instrument: `lake env leanchecker Proofs.NoSuchModule`
→ **exit 1**, `Could not find any oleans for:` — so a green from it is a result,
not a default.

Tree total: **241 theorems across 17 modules**, 0 `sorry`, 0 `native_decide`,
0 build warnings.

### What the modules actually say

`RotDuplicate` — the finding is one definition: **what fires is the
concatenation of two registries.** `RotInstall.arm_idempotent` is true and was
never the problem; idempotence *within `settings.json`* cannot see a duplicate
that lives across `settings.json` **and** the plugin's `hooks.json`.
`unguarded_duplicates` counts 2, `guard_keeps_one` counts 1.

`RotScan` — a one-level scan can only ever **over**-report staleness
(`flat_never_underreports`), for every tree, not just the measured one. That
names the failure mode precisely: the broken reminder did not go quiet when it
should have spoken, it spoke when it should have been quiet, and an alarm that
fires falsely gets ignored.

`RotLog` — `consistent_Rs_eq_gauge`: a record whose terms are the model's terms
and whose own `sum`/`Rs` relate as stated **reports exactly the gauge**. `Rs` is
derived, not trusted; any other value contradicts the line's own fields.

---

## Two spec defects found by instruments, not by reading

**1. An unused hypothesis.** Lean's unused-variable linter flagged `h : ws ≠
bundled` in `RotScan.old_chain_falls_to_bundled`. It was right: the theorem
compared whole pairs, and the *labels* `bundled` / `discovered` differ for free,
so the hypothesis carried nothing while the doc comment claimed the theorem was
about the 2907-minute false alarm. The measurement that went wrong was the
**path**, so the theorem is now stated on the path component, where the
hypothesis is load-bearing — plus a separate, honestly unconditional theorem for
the label difference.

**2. A spec that forbade correct behaviour.** `RotLog.WellPaired` asserted a
route record carries the **same** `Rs` as its gauge record. The shipped router
does not do that: the gauge line carries `0.66427`, the route line carries the
displayed `0.66`, matching the marker the operator reads. Twelve records per arm
recomputed field for field with **zero** error, and the only disagreement was a
rounding the spec had banned.

**The spec was wrong, not the code.** `WellPaired` now takes a tolerance, and
`displayEps = 1/200` is the exact half-ulp of a two-decimal display — an honest
rounding passes, a stale or edited number still cannot. `measured_rounding_
accepted` pins the accepting direction so nobody tightens it back to equality
after reading `mismatched_pair_detected` alone.

---

## Four new gates — and every one was made to fail on purpose

| gate | result | mutation that proved it load-bearing |
|---|---|---|
| `router-duplication.sh` | 12/12 | disabled the ARM guard → **FAIL**, exactly `expected 0 entries, measured 2` |
| `disarm-safety.sh` | 14/14 | deleted the dry-run branch → **3 FAILs** |
| `remind-measure.sh` | 16/16 | dropped `-Recurse` → **FAIL**; killed the legacy path fallback → **FAIL** |
| `log-replay.sh` | 13/13 | six corruption controls, each REJECTED |

Every mutation was **asserted present in the file before building**, and every
one was restored with the baseline re-verified green afterwards.

### The gate that found a defect on its first run

`remind-measure.sh` immediately failed `[ps1] recorded ignored: got 'discovered'`.
Root cause, measured: `SETUP_LEAN.sh` wrote the workspace path verbatim, which
under Git Bash on Windows is a POSIX drive path, and `Test-Path -LiteralPath`
refuses that spelling — so the PowerShell reminder **silently discarded a
perfectly good recorded workspace** for every user who ran the POSIX installer.
The exact mirror of an asymmetry `prover-remind.sh` already documents in the
other direction.

Fixed on both sides: the installer records the drive-letter form (measured: Git
Bash accepts `[ -d "D:/tmp" ]` and so does `Test-Path`), and the reader keeps a
fallback for the legacy paths already on disk — with its own assertion, because
an upgrade must not break the machines that were already set up.

### A claim of mine that was false, and how it was caught

The first draft of `log-replay.sh` said the debug log was *"read by NOTHING"*.
**False.** `bench-router.sh` §5 already summed the logged `term` values and
checked `Σterm / K = Rs`. The header now states the measured delta instead: that
check cannot see anything *upstream* of `term`, so a record with the wrong `mu`,
`sigma`, `H` or `mean` is consistent at the level of sums and passes. The new
gate recomputes every factor, checks pairing, checks the displayed rounding, and
replays the **PowerShell** arm's log — which `bench-router` runs for timing and
never reads back.

---

## Mutation: 82 applied, 82 killed, 0 survived, 0 discarded — measured, not inherited

`README.md:240` claimed `72 applied, 72 killed`. The count declared by the suites
was 82 after mine joined, so the line was stale. Rather than edit a number I had
not measured, **all eleven suites were run by hand in this session**:

| suite | killed | survived | discarded |
|---|---|---|---|
| rotability | 5 | 0 | 0 |
| rotacquire | 5 | 0 | 0 |
| rotgates | 5 | 0 | 0 |
| rotgauge | 12 | 0 | 0 |
| rotinstall | 10 | 0 | 0 |
| rotpath | 5 | 0 | 0 |
| rotremind | 6 | 0 | 0 |
| rotroute | 11 | 0 | 0 |
| rotvacuity | 6 | 0 | 0 |
| rotverdict | 7 | 0 | 0 |
| **rotduplicate (new)** | **10** | 0 | 0 |
| **total** | **82** | **0** | **0** |

### The new suite found a vacuity in my own theorems

First run: **8 killed, 1 survived, 1 discarded.**

- **M03 SURVIVED.** Replacing `pluginRegisters` with constant `true` — a guard
  that refuses to arm for anyone, forever — did **not** break `guard_still_arms`
  or `armed_fires`, because both are stated *under* the hypothesis
  `pluginRegisters cmd r = false`, and an unsatisfiable hypothesis makes a
  theorem vacuously true. Fixed by `guard_can_decline`, which asserts a registry
  where the guard declines **and** the arming that follows. M03 now dies.
- **M07 DISCARDED**, correctly: the needle `match recorded with` occurs twice
  (`resolve` and `resolveOld`), the harness counted 2 and refused. A suite that
  had patched the first occurrence would have mutated one function and
  attributed the result to the other. Re-aimed at a unique line.

`DISCARDED` is reported apart from `SURVIVED` everywhere, and the suite **exits
non-zero on either**. They mean opposite things: one is a claim about a theorem,
the other a claim about the harness.

---

## Repository state

| gate | exit |
|---|---|
| `workflow-lint` | 0 (123 passed) |
| `gate-split` | 0 (12 passed; the Lean witness moved with the table) |
| `repo-complete` | 0 (48 passed) |
| `verdict-fresh` | 0 (STATUS.md regenerated) |
| `portability` | 0 (21 passed; exec bits set in the index) |
| `mutant-discipline` | 0 (24 passed) |
| `release-consistency` | 0 (8 passed) |
| `no-local-paths` | 0 |
| `cross-diff`, `cross-diff-remind`, `hook-contract`, `hook-footprint`, `claude-md-lint`, `lean-binds-shell`, `count-theorems` | 0 |

`ci-dryrun` was **red** at 5 failures and is now expected green — it is the one
gate not yet re-run since the fixes, because a single run exceeds the 600 s
foreground bound. It is the first item below.

Version bumped to **0.7.0 / 0.7.1 / 0.7.2** (`plugin.json` carries `.2`, per the
release-triple convention). `CHANGELOG.md` entry written. Nothing committed.

---

## NEXT

1. **Re-run `ci-dryrun.sh`** (clean clone, the five previously-red steps) and the
   full `gate-all.sh` sweep, foreground, in chunks that fit the time bound.
2. **CTT install test** in the cloned CLI instance — install the 0.7.1
   Lean variant as a stranger would, then verify with `plugin-detect.js` that
   arming afterwards **refuses**, which is the whole point of this release.
   Confirm the CTT `.claude/settings.json` carries exactly one router entry per
   event, not two.
3. **The router stem gap**, still open and still measured: `prove`, `proof` and
   `lemma` are **not** FORGE stems, so *"prove the read loop conserves bytes in
   lean"* routes to STEALTH on `byte`. The earlier diagnosis that first-match
   beat priority was **wrong** — `route()` already tries FORGE first; the stem
   table is simply missing the words. Fix needs the Lean spec, both arms, the
   corpus and `lean-binds-shell.sh` moving together.
4. **Scrutiny + How-To GIT docs** (`docs/`), then codemap refresh.
5. Commit, tag the release triple, push to `Nova-Violet-Role/RoT-MoE`.
