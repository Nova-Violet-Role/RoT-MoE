<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# Compendium: the eight ways an instrument reports green over nothing

> A gate that cannot fail is not a gate. It is a decoration with an exit code.

This is the catalogue of defects found while auditing this repository's own verification
layer on branch `9.0.0`. Not defects in the code under test — defects in the instruments
that certify it.

**Scope, measured rather than asserted.** The branch carries 66 commits, of which 25 use
the `9.0.x:` prefix that marks an audit finding. Eighteen of those 25 are cited by hash
below. The remaining seven are release mechanics (tag layout, archive splitting, a merge)
or restate a family already illustrated. Nothing here claims to cover the branch entire —
that sentence stood in an earlier draft of this file and was false, which is Family 4
committed inside the document written to name Family 4.

The companion document, `COMPENDIUM-the-unwritten-claim.md`, treats one family in
depth. This one is the map.

---

## The single sentence

Twenty-five commits, one law:

> **Correctness borrowed from a neighbour is correctness with no owner.**

Every defect below is an instrument whose truth was held somewhere else — in a sibling
phase, in a hand-maintained list, in a comment, in today's accidental state of the tree.
Each was *correct at the moment it was written*, and none of them knew why. That is a
different failure from "the check is wrong". It is "the check is right, for now, for a
reason it does not hold."

---

## FAMILY 1 — Registered in one place, executed in none

**Shape.** A gate is listed in a table, a manifest, a README, a shell array — and no
runner ever reaches it. The registry is mistaken for the wiring.

**Instances.**

| Commit | The defect |
|---|---|
| `4a0a552` | Five gates were registered in the shell table and in nothing else. |
| `155f6b9` | Nothing had ever executed the Windows gate, and two comments said otherwise. |
| `8e69d6d` | ORGAN 7 had no verifier at all. |

**The tell.** You can name the gate but cannot name the line that invokes it. A comment
says "run in CI" and no workflow step contains the filename.

**The assertion that closes it.** Derive the runner's list from the same source the
registry uses, then assert set equality in both directions. A gate present in the table
and absent from the runner must be a *failure*, not an omission. `checker/workflow-lint.sh`
now does this with `wired_in()` and `wiring_verdict()`.

---

## FAMILY 2 — A skip, a no-op, or a missing tool read as a pass

**Shape.** The harness cannot run the check, takes the fallback path, and the fallback
path is indistinguishable from success.

**Instances.**

| Commit | The defect |
|---|---|
| `f9eb11b` | The suite counted a skip as a pass — and said so in the same breath. |
| `8111868` | The row titled "one body, three tiers" read exit 0 and nothing else. |
| `8e69d6d` | One tier printed a verdict for a suite it does not ship. |

**The worked example.** A container without `pwsh` made `cross-diff.sh` return a fake
zero. Downstream, `mutate-checker.sh` then judged router mutants H01 and H02 SURVIVED —
against a comparison that had never executed. **A false green does not stay local; it
propagates into every instrument that trusts it.**

**The tell.** The skip path and the pass path converge on the same exit code, and the
only difference is a line of prose in the log.

**The assertion that closes it.** A skip gets its own exit code and its own counter.
`cross-diff.sh` now exits 3 when `skip > 0`. Silence must never be spendable as evidence.

---

## FAMILY 3 — Agreement asserted without the ability to disagree

**Shape.** Two things are compared, they match, the gate passes. Nobody ever proved the
comparison *could* have failed. Two empty strings agree perfectly.

**Instances.**

| Commit | The defect |
|---|---|
| `5b8076a` | Two suites asserted agreement without ever proving they could disagree. |
| `396b7c1` | The arm-vs-arm phase — by its own header "the entire argument for maintaining a second arm at all" — ran 65 comparisons with no negative control and no non-empty assertion. |

**The tell.** A comparison loop with no planted disagreement anywhere in the file. Or:
the emptiness guard lives in a *neighbouring* phase, so reordering the phases silently
disarms it.

**The assertion that closes it.** Every comparison phase carries its own control, feeding
deliberately different inputs and requiring the difference to be *detected*, plus an
explicit both-arms-spoke check. Measured, so the control is known constructible:
one vector reads `R/s+ = 0.47 … lenses=Nova`, another `R/s+ = 0.45 … lenses=Eidolon`.
Mutating either into agreement kills the suite.

---

## FAMILY 4 — Prose standing in for an assertion

**Shape.** A bound, a contract, or a fact is written in a comment, a charter, a log line
or a README. It reads exactly like a rule. Nothing enforces it.

**Instances.**

| Commit | The defect |
|---|---|
| `df99220` | `prover-remind` documented an ASCII contract that no gate asserted. |
| `8b1177c` | A sentence inside a log line was passing for a wiring. |
| `0593a0b` | Two bounds that nothing asserted. |
| `e2f0e23` | Three charters restated the roster's facets, and all three had drifted. |
| `3f678e1` | ORGAN 1 documented one knob out of thirty-four. |

**The worked example.** In `.github/workflows/ci.yml:1329` an `echo` line *mentioned* a
checker by name. The wiring test matched the filename and recorded the gate as wired. A
message about a thing had become indistinguishable from an invocation of it.

**The tell.** Search the repository for the rule's text. If every hit is a comment, a
charter or an echo, the rule has no enforcer.

**The assertion that closes it.** Classify every mention rather than pattern-matching the
name: `mention_class()` returns `invocation`, `path-filter`, `message`, or `UNCLASSIFIED`,
and an unclassified mention stops the build with a `file:line`. A planted
`exec checker/cross-diff.sh` is caught. **Any bound written as prose is an assertion with
no assertor.**

---

## FAMILY 5 — A claim with a checker but no author

**Shape.** A number appears in prose. A checker validates it against the tree. Nothing
*writes* it — so on drift the only recourse is a human editing five files by hand, and the
sixth site nobody remembered stays stale.

**Instances.**

| Commit | The defect |
|---|---|
| `0593a0b` | One claim that nothing wrote. |

**The tell.** A regenerator exists (`--write`) and its blast radius is narrower than the
checker's scan radius. The mismatch *is* the bug.

**The assertion that closes it.** Three derived laws, all measured the hard way:

- **A claim with a checker but no generator is an assertion with no author.**
- **A generator's domain must equal the domain of the checker that validates it.**
- **A generator's blast radius must be exactly the set of live claims** — no wider. The
  `repo-complete.sh --write` path was found rewriting a *quotation* inside this very
  compendium. **A number inside a quotation is evidence, not a claim**, and a writer that
  cannot tell the difference corrupts the record it was built to protect.

---

## FAMILY 6 — The instrument damages what it measures

**Shape.** The gate mutates, stages, packages or cleans — and the act of measuring
destroys the evidence, or ships something that was never checked.

**Instances.**

| Commit | The defect |
|---|---|
| `fdedabc` | The Windows gate destroyed every seal it demanded. |
| `c270945` | The archives shipped untracked files while every assertion was green. |
| `f94dda5` | The packager could ship a short archive and call it green. |
| `dc48d07` | The semantic index is machine-local and must never reach an archive. |

**The tell.** The gate writes anywhere. Ask what happens if it runs twice, and what
happens if it runs and then the real build runs.

**The assertion that closes it.** Assert the *output*, not the exit code: byte counts,
member counts, and an explicit inventory diff of what the archive contains against what
git tracks.

---

## FAMILY 7 — Evidence pointing at the wrong thing

**Shape.** The gate is wired, runs, and fails honestly — at the wrong artefact. It is
right about something nobody asked.

**Instances.**

| Commit | The defect |
|---|---|
| `aa80f63` | Five gates blocked publishing, each pointed at the wrong evidence. |
| `74f4625` | Two of the six roster fields were parsed and asserted by nothing. |
| `396b7c1` | The extension census walked a hand-written directory list, in a file whose own header condemns "an instrument whose scope is written down instead of derived". |

**The worked example, and the most instructive accident on this branch.** A scheduler lock
file — created ninety seconds earlier by an unrelated action — turned the entire suite red.
The gate was correct: an undeclared extension was in the tree. But its scope came from a
hand-maintained prune list, so the exempt list had silently absorbed transient tool
droppings as though they were repository file types. Deriving the scope from
`git check-ignore` instead made the exempt list *shorter*: three of its entries existed only
to excuse files that never ship.

**The tell.** The scope is a literal list in the source. Someone must remember to update it.

**The assertion that closes it.** Derive the scope from a source of truth the repository
already maintains, and plant two controls — one file that **must** be seen, one that
**must not**. Guard the derivation's degenerate case explicitly: an empty pattern set fed
to `grep -Fxv -f` matches everything and silently discards the entire census.

---

## FAMILY 8 — The verdict is computed from the survivors

**Shape.** The suite does not fail. It *shrinks*. Some gates never reach the runner, and
the verdict is a fraction whose denominator was counted from the gates that arrived — so
the missing ones cannot appear as missing. Every earlier family is about a gate that
answers badly. This one is about a gate that is never asked, in a report that looks
complete because it never mentions it.

**Instances.**

| Commit | The defect |
|---|---|
| `2f06b7c` | The freshness gate was its own precondition: red until a full run stamped, and the stamp required a run with no reds. Unsatisfiable from the state it existed to escape. |
| this one | 83 gates registered, 77 executed, and the runner printed `2 of 77 GATES RED`. Six gates vanished with no error. |

**The worked example.** The first full sweep ever run on this branch took 67 minutes and
reported `2 of 77 GATES RED`. The registry holds 83 rows — 73 in the default block, 10
more under `--full`. The six that disappeared were the last six rows of the `--full` block,
cut at a clean row boundary.

The cause is mechanical. The runner walks its gate list with a `while read` loop fed by a
heredoc, and executes each gate as `sh -c "$cmd" > log 2>&1` — stdout redirected, stderr
redirected, **stdin left attached to the gate list**. A gate whose command reads stdin
eats the remaining rows. Four rows, one of them a `cat`, reproduce it exactly: two run,
two vanish, exit 0, nothing printed.

What makes it Family 8 rather than a plain bug is the reporting. `ran` was incremented per
gate reached, and the summary divided by `ran`. The suite computed its own denominator from
its own truncated walk, so a run missing six gates and a run missing none are the same
sentence. The red verdict that day was an accident: two gates happened to fail. Had those
two been green, the sweep would have printed `ALL 77 GATES GREEN` while six gates had never
executed — proved as `the_measured_gap_would_have_reported_green`.

**The tell.** The report's total is a running count rather than a figure derived from the
roster. Anywhere a suite says "N of M" and M was accumulated during the walk, M is evidence
about the walk, not about the registry.

**The assertion that closes it.** Count the registered rows independently of the walk, and
require every one to be accounted for as executed or as declared-skipped — no third bucket.
`< /dev/null` per gate fixes the cause that was measured; the roster assertion fixes the
class, because the next truncation will have a different cause and the same silence.
`lean/Proofs/RotGateRoster.lean:an_unaccounted_run_is_always_red`.

**The distinction that makes it work.** A skipped gate is *declared*: the runner knows it
exists, names it, counts it out. A truncated gate is not a skip. It is absent from the
arithmetic, and absence must read red or it reads green.

---

## The audit checklist

For any gate, in order. Each question comes from a defect that actually shipped.

1. **Who invokes it?** Name the file and line. Not the table — the invocation.
2. **Can it fail?** Break it on purpose. If the suite stays green, it was never a gate.
3. **Can it fail for the *stated* reason?** A mutation that kills via a different control
   proves nothing about the claim. Re-run until the kill matches the sentence.
4. **What does a skip look like?** If it looks like a pass, it is a false green with a
   propagation radius.
5. **Where does its scope come from?** A literal list is a scope that expires.
6. **Is the bound asserted or merely written?** Grep the rule's text. All comments = no rule.
7. **Who writes the numbers it checks?** No generator means no author.
8. **Does it write anything?** Then assert the artefact, not the exit code.
9. **Does its control still fire after the refactor?** Re-trip it. Every time.
10. **Did every registered gate actually run?** Count the roster independently of the walk.
    A total accumulated while walking cannot report what the walk never reached.
11. **Can this gate ever be satisfied?** Trace the rule on the empty state. A gate that is
    its own precondition is red forever, and a twenty-minute sweep will not tell you why.

---

## Instrument errors in the measuring tools themselves

Twenty-three catalogued. The ones that recur:

| # | The error |
|---|---|
| 18 | Running a checker copy from the repo root breaks its `$(dirname "$0")/..` path math — it resolves *outside* the repo and dies early, which reads as a valid low baseline. |
| 21 | `grep … 2>/dev/null` cannot distinguish an absent file from no match. |
| 22 | Native node resolves `/tmp` to `C:\tmp` on this platform. |
| 23 | A grep anchored on one error phrasing undercounts mutation kills. |

Platform-specific traps: `grep -c $'\r'` and `awk index($0,"\r")` are both broken here — count carriage returns with `od -An -tx1 | tr ' ' '\n' | grep -c '^0d$'`. `grep -c` exits 1 on zero matches. `leanchecker --help` hangs forever reading stdin.

**The meta-lesson.** Four of the twenty-three are cases where a *broken instrument
reported success*. The audit tools are subject to their own taxonomy. Nothing exempts them.

---

## Accumulated laws

Stated in the order they were learned, each purchased with a real defect:

1. A harness whose skip path looks like its pass path must shout.
2. A control must exercise the same function production calls — and be re-tripped after
   every refactor.
3. Any bound written as prose is an assertion with no assertor.
4. A claim with a checker but no generator is an assertion with no author.
5. A generator's blast radius must be exactly the set of live claims.
6. A checker's coverage stops exactly where its phrasing does, and a writer's damage
   extends exactly as far.
7. A generator's domain must equal the domain of the checker that validates it.
8. A number inside a quotation is evidence, not a claim.
9. A measurement is not an assertion.
10. A mutation that kills for a reason other than the stated one proves nothing about
    the statement.
11. Correctness borrowed from a neighbour is correctness with no owner.

---

## What is still unasserted

Honesty is the point of the document, so the debts are part of it.

- **The wall-clock ceiling.** Six readings — 533, 965, 970, 971, 1195 and 1215 seconds —
  against a 240-second pre-commit ceiling. `lean/Proofs/RotGateCost.lean` proves the breach
  is structural; nothing records the series, and nothing acts on it. Predicted consequence:
  the first person to hit a twenty-minute commit disables the hook, and the suite dies of
  its own thoroughness.
- **The echo heuristic.** `mention_class()` classifies a line that both echoes *and* invokes
  through an unknown form as a `message`. Documented in source. No assertor. Family 4,
  in the very function written to close Family 4.
- **`list_sources()` in the SPDX sweep** still carries the hand-written prune list. Only
  the *census* was derived. Family 7, half-closed.
- **This document's own numbers.** The commit counts, the six wall-clock readings and the
  family tallies here are prose. `repo-complete.sh` validates theorem, module, checker and
  mutation-suite claims across every tracked text file; it does not know about any of the
  numbers above. They were measured when written and nothing will notice when they rot.
  Family 5, open, in the compendium that defines Family 5. Recorded rather than hidden,
  because a catalogue of unasserted claims that exempts itself is worth nothing.
- **The sweep itself** is roughly one-sixth complete, and the defect rate has not fallen.
  That is information: the remaining files are not safer, and the audit cannot be truncated
  early on the argument that the interesting parts are done.

---

## The generalisation

The eight families collapse into one question, which is the only thing worth carrying
away from this document:

> **What would this instrument do if the thing it checks were absent?**

Family 1 finds nothing to run. Family 2 takes the fallback. Family 3 compares two voids.
Family 4 reads a comment. Family 5 has nobody to write the answer. Family 6 measures its
own leftovers. Family 7 looks somewhere else entirely.

In all eight the answer is the same, and it is always green.
