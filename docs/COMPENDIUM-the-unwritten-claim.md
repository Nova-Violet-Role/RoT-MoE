<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# Compendium: the unwritten claim

> A number in prose is a claim. A number from source is a measurement.
> This repository already knew that. What it had not noticed is that **a claim
> needs two things, not one** — something that *checks* it, and something that
> *writes* it. A claim with only a checker is not maintained. It is a chore,
> and a chore is where a human types a number.

## The defect, stated exactly

On 2026-08-22 a single Lean module was added. That moved two measurements:
modules 89 to 90, theorems 1648 to 1662. The commit was refused by three gates,
which is the tree working. Two of the three had a regenerator:

| Gate | Regenerator |
|---|---|
| verdict freshness | `bash checker/status-verdict.sh --write` |
| README FACTS block | `bash checker/facts-block.sh --write` |
| repo completeness | **nothing** |

So four strings were edited **by hand**:

| File:line | What carries the count |
|---|---|
| `.claude-plugin/marketplace.json:4` | the `"description"` string |
| `.claude-plugin/plugin.json:4` | the `"description"` string |
| `CITATION.cff:21` | inside the `abstract:` block |
| `README.md:63` | the opening paragraph |

Those four are the *entire* meaning of the phrase "updated by hand". They are
not a mystery, a legacy, or a limitation of the toolchain. They are four
strings that a checker was willing to enforce and nothing was willing to write.

## Why "a checker exists" was not good enough

The checker did its job perfectly: it went red, it named all four files, and it
refused the commit. That is the whole of what a checker can do. What it cannot
do is *close the loop* — and an open loop always closes through a person.

The failure mode is not that someone forgets. It is worse and quieter: someone
remembers, edits four strings, gets it right, and the repository now contains
four numbers whose provenance is **a person's care on one afternoon**. Nothing
in the tree records which afternoon, or whether the fifth place was missed.
The claim is correct and unfounded at the same time.

A repository that sells machine-checked proof cannot have a hand-typed
headline. Not because the number is likely wrong — it was right — but because
"a human typed it carefully" is precisely the epistemology this project exists
to replace.

## The fifth place, which nothing was watching

While mapping the four, a fifth turned up. `README.md:1353` reads:

    | The corpus is real | **MEASURED** | **90 modules**, **1662 theorems**, ...

The enforced pattern is `<n> machine-checked theorems`. That row omits the
words `machine-checked`, so **no gate had ever looked at it**. The most
quotable inventory line in the repository was free to drift in total silence,
sitting one screen away from four claims that were guarded to the byte.

This is the sharper lesson. The first defect was a missing writer, which is an
omission you can see once you look. The second was a checker whose *pattern*
decided its scope, so the claims it protected were the claims that happened to
be phrased its way. Coverage followed grammar rather than intent.

## The law

**Every number a reader can quote needs an assertor AND a generator.**

Four states, and only one of them is acceptable:

| State | What it means | Verdict |
|---|---|---|
| no checker, no writer | free drift, silent | fails on the first edit |
| **checker, no writer** | **enforced by a chore** | **this defect** |
| writer, no checker | regenerated, unverified | a writer with a bug ships quietly |
| checker AND writer | the number cannot be typed | the only acceptable state |

The third row deserves a note: a generator alone is *not* the answer. A writer
with a bug rewrites every claim to the same wrong value and every file agrees
with every other file. Only the pair is safe, because the checker verifies the
writer's own output — which is why `--write` here runs *before* the checks in
the same invocation and does not exempt itself from them.

## Two traps a writer must respect

Both were live in this tree, and either one would have made the fix worse than
the defect.

**1. The writer must not eat the controls.** `checker/repo-complete.sh` plants
three fixtures inside itself that carry the enforced phrase with a deliberately
wrong count of `99999`. They are its own negative control: a count that is
wrong on purpose, present to prove the comparison can still fail. A writer that
rewrote every textual occurrence of the pattern would set those fixtures to the
true count, and the control would pass forever while testing nothing. This is the
failure already recorded in commit `fdedabc`, where a Windows gate destroyed
every seal it demanded. The writer here calls the *same* `claim_exempt`
function the checker calls; it does not carry a second copy of the list.

**2. The writer must not rewrite history.** `CHANGELOG-ARCHIVE.md` says 0.5.x
shipped 195 theorems, and that is true and must stay true. A changelog whose
old entries track today's tree is not a changelog. The archive is exempt by
construction, `CHANGELOG.md` is skipped by the writer entirely, and only its
newest section is treated as a live claim by the checker.

Stated as one rule: **a generator's blast radius must be exactly the set of
live claims — never the set of textual matches.**

## What was built

`checker/repo-complete.sh` gained `--write`, and the inventory row gained a
guard. Measured, in this order, on a deliberately staled tree:

1. counts staled to 3 in all five places → checker exits **1**, naming five
   failures, including the inventory row that previously had no assertor
2. `bash checker/repo-complete.sh --write` → rewrites 4 files, then its own
   checks run and report **55 passed, 0 failed**, exit **0**
3. plain re-run → exit **0**
4. `99999` fixtures still present: **3 of 3**
5. `CHANGELOG-ARCHIVE.md` claims unchanged: 195, 195, 205, 495
6. all four files byte-identical to their pre-stale originals (`diff -q`)

Step 4 is the one that matters most. A writer that passes steps 1 to 3 and
fails step 4 has not fixed the repository; it has disarmed it.

## The rule for anyone adding a claim

If you write a number into prose that comes from the tree:

1. Add it to a checker, so it can go red.
2. Add it to that checker's `--write`, so nobody types it.
3. Break it on purpose and watch the checker fail. An alarm nobody has
   deliberately tripped is an untested alarm.
4. Then run the writer and confirm it restores the file **byte for byte** —
   not merely to something that passes.

If you cannot do 2, do not do 1 alone and call it maintained. Say plainly, in
the file, that the number is hand-held and why — so the next reader inherits a
known gap instead of a false assurance.

## The generalisation

This is the same shape as the ceiling defect fixed in the same commit, where
`checker/gate-all.sh` stated a four-minute pre-commit bound in a comment that
nothing measured, and the suite had drifted to 359 seconds unseen. Both are one
sentence:

> **A bound written as prose is an assertion with no assertor. A claim with a
> checker but no generator is an assertion with no author.**

Look, in this order, for: every number in a comment that a command could have
measured; every checked claim with no writer; and every claim whose checker
matches a *phrase* rather than a *fact*, because that checker's coverage stops
exactly where the phrasing does.
