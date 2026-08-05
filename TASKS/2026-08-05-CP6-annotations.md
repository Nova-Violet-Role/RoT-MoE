<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# CP6 — three platform bugs, one incomplete repair of my own, and the instrument that found them all

Checkpoint Resumee, 2026-08-05. Every claim names its instrument.

## The result

`checkers (ubuntu-latest)`, `checkers (macos-latest)` and `checkers
(windows-latest)` all **success** on `4d48813`. macOS had never been green
before. The lean job builds mathlib and was still running at the time of
writing — **not claimed as green.**

## What was wrong, in the order it was found

| # | defect | why it never reproduced here |
|---|---|---|
| 1 | `pipefail` + `grep -q` → SIGPIPE 141 on a **successful match** | a race; the producer wins on this machine |
| 2 | `sed -i "$expr" f` — BSD sed takes the expr as a **backup suffix** | GNU sed everywhere but macOS |
| 3 | `portability`'s trigger listed four path prefixes, not `lean/` | a new `.sh` under `lean/mutate/` could not escalate the gate that checks it |
| 4 | my own repair of #1 covered the **assertions** and left the **counters** | two sites in the file I was repairing |

Defect 1 is worth stating precisely because it inverts a checker's purpose:
`grep -q` exits at the first match, the producer writes into a closed pipe and
dies with 141, and `pipefail` reports 141 — **so a match is scored as a miss.**
CI announced `hooks/prover-remind.ps1 builds with no ROTMOE_LEAN_VERIFY opt-out`
for a file containing that string three times, and later `the shipping reminder
carries only 0 of 3 guards` for a file carrying all three.

## The instrument

`actions/runs/<id>/logs` → **403, "Must have admin rights"**, on a repo whose
`visibility` is `public`. The only readable evidence was the check-run
annotation, which said:

```
Process completed with exit code 1.
```

`::error::` lines become annotations, and annotations are public. Three checkers
got an emitter; then workflow-lint failed and was one of the 36 that did not
have one, so the same blindness recurred. **Now all 39 emit
`::error title=<checker>::<message>`**, guarded on `GITHUB_ACTIONS`.

| control | result |
|---|---|
| green run (`gate-split`) | **0** annotations |
| planted failure (`STATUS.md` 276 → 999) | `::error title=verdict-fresh::STALE VERDICT: …` |
| restore | `STATUS.md` byte-identical, exit 0 |

## The rule, because a habit is not a repair

`workflow-lint` rule 7 refuses any checker that pipes into `grep -q` under
`pipefail`. It immediately found **five more sites** the mechanical sweep never
matched — their arguments carried nested quotes or command substitutions.

It had to be taught three things, each measured as a **false positive**:

- **`||` is not a pipe** — `grep -qE "$A" "$F" || grep -qE "$B" "$F"` greps two files.
- **A fixture is not code** — `portability.sh` *writes* a script containing the hazard to prove its own rule can see one.
- **A message is not a pipeline** — `ok "CONTROL: a planted printf|grep -q IS detected"`.

That is the third, fourth and fifth time a rule in this file punished the control
written to keep it honest. Each carve-out is stated, never widened.

**And the rule had the bug it hunts.** `_n=$(… | grep -c -E '…' || printf 0)`:
`grep -c` *prints* `0` **and exits 1**, so the fallback appended a second zero,
`_n` became two lines, and the numeric test errored. The control requiring the
**correct** form not to be flagged is what caught it — the whole argument for two
controls per rule.

## A gate that could not pass, in three copies

`release-session.sh` recovered the release map by `sed`-ing the packager's
*source text*. The packager now derives versions from `plugin.json`, so it hunted
`rot-moe-$_MM.0-core.zip` while the three real archives sat in `.release/`. The
same defect had already been fixed in `release-install.sh` — one sibling, not the
other. `release-longsession.sh` was a **third** copy, found by the new rule 6.
Now **48 passed, 0 failed**.

## A classifier repair, proved rather than asserted

`mutant-discipline.sh` classified any file that patches **and mentions
`CONTROL`** as a mutation harness — and every good checker has controls. Dropping
`CONTROL` *looks* like weakening a check, so it is a theorem: 7 of them in
`RotMutant.lean`, including `repair_only_narrows` (the new selection is a subset
— nothing escaped) and `repair_is_not_vacuous` (a **strict** subset — not a
no-op). Plus a `#guard` exhaustive over all **32** evidence shapes.

Measured: 17 files selected before, 15 after, the two dropped are exactly the two
misclassified.

## RotMutant had never been mutated

The module that *defines* mutation discipline had no suite. Now 10 mutants →
**10 killed, 0 survived, 0 discarded.** Three needles came back DISCARDED on the
first run and were **fixed**, never folded into survived.

## Two things that bit twice

**The exec bit.** `chmod +x` does nothing here — `core.filemode` is false — so
`git update-index --chmod=+x` is required. Two new `.sh` files reached CI at mode
100644. Root cause beyond my carelessness: `portability`'s trigger did not list
`lean/`. Widened in the runner table **and** in `RotGates.lean`, which moved a
guard 26 → 27 — the count follows the trigger table, and the reason is written
beside it.

**CodeMap overwrote `.githooks/pre-commit`.** Twice this session; the second time
my own `git add -A` carried it into `c211f98`, so HEAD shipped a hook with zero
`gate-all` calls and the real gate had to be recovered from `85ea551`.
`workflow-lint` caught it both times. Commits now verify the hook is present
**immediately before** committing rather than trusting a sweep run minutes
earlier.

## Escaping, measured three ways

Adding the emitter with `awk` turned the `\n` of a printf **format** into a real
newline, splitting every `bad()` across two lines. Repairing that, three tools
**silently did nothing**: `perl -0pi` (the known hazard here), `sed N;s` (matched
the address, proved separately, and still did not join), and `awk printf "%s\\n"`
(reproduced the original defect). What worked was taking the backslash out of the
escape — `BEGIN{bs="\\"}` and concatenating. Verified by line count (180 → 179)
and byte inspection, **not** by the tool reporting success. All 36 joins were
gated on needle-gone + replacement-present + `bash -n`, or the temp file was
discarded.

## Measurements

| instrument | result |
|---|---|
| CI ubuntu / macOS / windows on `4d48813` | **success** (macOS first time) |
| CI lean job | still running — **not claimed** |
| `gate-all.sh --fast` | ALL 22 GREEN |
| `workflow-lint` | 135 passed, 0 failed |
| `release-session` | 48 passed |
| `mutant-discipline` | 24 passed |
| `install-parity` | 9 passed |
| `log-replay` | 13 passed, zero controls discarded |
| `mutate_rotmutant.sh` | 10 killed / 0 / 0 |
| `mutate_rotgates.sh` | 5 killed / 0 / 0 |
| `lake build Proofs.RotMutant`, `Proofs.RotGates` | exit 0, read directly |
| `#print axioms` × 7 new | `propext`, or none — no `sorryAx` |
| `leanchecker` (both, local + delivered) | exit 0, zero bytes |
| negative control (absent module) | exit 1, read directly |

Counts from source: **276 theorems / 18 modules / 14 suites / 46 checkers**;
**111 mutants applied, 111 killed**.

## CTT, before every push

Five reinstall cycles this checkpoint. All nine lanes driven through the
installed router → nine distinct lanes, nine distinct `R/s+`, each equal to the
value pinned in `RotEnsemble.lean` (Claude 0.66 · AntiVenom 0.57 · Nova 0.47 ·
Eidolon 0.45 · Venom 0.44 · Chroma 0.41 · Soleil 0.39 · Carnage 0.32 · Violet
0.31). One firing per prompt every time. Live CTT `settings.json` byte-identical
to its backup throughout.

## NEXT

1. Confirm the lean job on `4d48813`; it is the only job not yet green.
2. Once all four are green, **re-tag** `v0.7.0/1/2` onto that commit and re-run
   `checker/tags-consistency.sh`.
3. Run `gate-all.sh` **bare** (all 34) — `deferred-closure` can then stop
   SKIPping, since it refuses to close deferred steps from a red run by design.
4. Still open, and it needs a decision rather than a proof: the
   `Claude = AntiVenom ∨ Soleil` weld. `RotEnsemble.lean:315` proves the ninth
   activity is not independent — the vector carries **eight** bits, not nine.
   Repair options: give Claude its own signal, or make the fusion explicit and
   Eidolon-gated at λ 1.65 / μ 1.10.
