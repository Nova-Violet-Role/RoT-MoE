# P2.4 pre-registration — does the routed arm do measurably better WORK?

**Written 2026-08-10, before any P2.4 data exists.** Committed first on purpose:
an admissibility rule or a verdict threshold chosen after seeing an outcome is
indistinguishable from discarding an inconvenient one. Everything below is
fixed. If it has to change, the change gets its own dated amendment in this
file — as `AMENDMENT 1` did for the trap corpus — and the run restarts.

---

## 1. Why the previous five measurements could not answer this

P2.2 asked whether the routed arm gives **better answers** and returned null
five times. At least two of those nulls were guaranteed by the corpus, not by
the router, and `lean/Proofs/RotSaturation.lean` now proves it rather than
asserting it:

| corpus | result | verdict of the gate | theorem |
|---|---|---|---|
| `rotmoe-fact` | 84/84 both arms | **refused** — at the ceiling | `saturated_pair_is_a_tie` |
| `rotmoe-calib` | 1/80 in band | **refused** — floor, margin 8 | `admissibleBy preregMargin = false` |
| `rotmoe-trap` | 59/88 | **admitted** — real room both ways | `#guard admissibleBy 8 trapCorpus = true` |

The trap corpus is *not* excused. Its null stands, and **P2.2 stays open.**

The deeper problem is the observable. RoT MoE is a `UserPromptSubmit` hook: it
acts on the reasoning layer before a turn runs. It cannot change the text of a
one-line factual answer, and grading that text was never going to see it. What
it can change is the **work** — which files get read, whether a claim gets
verified before it is stated, how much rework follows.

## 2. Hypothesis

> **H1.** On tasks with a verifiable outcome, the routed arm performs more
> *verification work per turn* and requires *fewer rework edits* than the
> unrouted arm, at equal or better task success.

**H0** is that the two arms are indistinguishable on every observable in §3.

This is a claim about process, and it is falsifiable in both directions: the
routed arm can lose on any of these measures.

## 3. Observables — all router- or transcript-derived, none judged

| # | observable | extracted from | direction claimed |
|---|---|---|---|
| O1 | verification steps invoked (build / test / proof / checker) | transcript tool names | routed **higher** |
| O2 | rework edits (≥2 edits to the same file in one task) | transcript edit sequence | routed **lower** |
| O3 | source files read before the first write | transcript, ordered | routed **higher** |
| O4 | unverified claims in the final message (a stated fact with no preceding tool call that could establish it) | transcript + final text | routed **lower** |
| O5 | task success | the task's own checker, exit code | routed **≥** |
| O6 | lens breadth and lead per turn | the debug log's `gauge` records | descriptive only |
| O7 | wall time per turn | the debug log's `ms` | descriptive only — already settled by P2.3 |

O6 and O7 are **descriptive**: they characterise what the router did, and are
not part of the verdict. Reporting them is not the same as claiming them.

**O4 is the one that can embarrass the router most**, which is why it is in.

## 4. Task set — fixed now, chosen for verifiability, not for outcome

`circular_selection_forces_the_ceiling` proves that selecting tasks on the
outcome drives the score to 100% by construction, and
`circular_selection_is_inadmissible` proves the gate refuses such a set. So the
task set is fixed **before** either arm runs and is not filtered afterwards.

Seeds: **four real defects from this repository's own history**, each with a
machine-checkable ground truth and a naive answer that is specifically wrong.

1. `grep -c '^theorem'` vs the real theorem count — the naive command is wrong
   and looks right.
2. `run_mut` **definitions** vs **invocations** — counting the wrong token gives
   a confident wrong number.
3. Module-name case (`RotMoe` vs `RotMoE`) — builds on Windows, fails on Linux.
4. `.release` vs `.release-local-only` — a path that exists but is not the one
   that ships.

**No expected value appears above, and none appears in the corpus.** This
paragraph used to carry them — "931 vs 919" and "72 vs 62" — and both were stale
within days; the honest count is 1410 as of this edit and will be wrong again by
the next commit. A frozen expected value is a contingent fact in the costume of a
specification, and it expires *permissively*:
`RotMoE.TaskCorpus.the_frozen_check_claims_discrimination_that_is_not_there`
exhibits a world where the frozen form reports a task as discriminating when the
two instruments have in fact converged. `bench/corpus-40.jsonl` therefore stores
a `truth_cmd` and a `naive_cmd` per task and `checker/corpus-verify.sh` re-runs
both at verification time, requiring only that they DISAGREE.

**n = 40 tasks**, 10 per seed family with distinct surface forms, one per router
lane — all ten, including the `CONVERGENT` fallback that fires when no stem
matches. Each prompt's declared lane is checked against the shipped router.

## 5. Admissibility — checked BEFORE the full run

A 10-task pilot per arm. The corpus is admitted only if
`RotMoE.Saturation.admissibleBy 8` holds on the pilot's O5 score, i.e. at least
8 of 80 room in **both** directions. `margin_zero_admits_everything` is the
theorem that stops this margin from being quietly set to 0.

**If the pilot is inadmissible the corpus is rebuilt, not the rule.**

### AMENDMENT 1 (2026-08-11) — the gate above was unsatisfiable, and that is a
### defect in this document, not in the corpus

`admissibleBy m` requires margin `m` in BOTH directions: `m ≤ hits` and
`m ≤ outOf − hits`. At the 10-task pilot fixed above with `m = 8` that demands
`hits ≥ 8` and `hits ≤ 2` simultaneously. **No outcome whatsoever satisfies it.**
`the_preregistered_gate_admitted_no_outcome` proves it; the corpus would have
been refused however the pilot had gone, which makes the gate an unreachable
bar rather than a strict one.

The repair is NOT a margin chosen to let the observed pilot through — that is
the "edit the spec to match the result" move this document exists to prevent.
It is the general relationship, quantified over the size that moves:

> `a_margin_is_reachable_iff_the_pilot_is_twice_its_size` —
> a margin `m` is reachable on a pilot of `outOf` tasks **iff `2m ≤ outOf`**.

Two consequences, both derived and neither chosen:

* keeping `m = 8` requires a pilot of at least **16** pairs
  (`margin_eight_needs_sixteen_pairs`);
* keeping the 10-task pilot allows at most `m = 5`, and at `m = 5` exactly one
  score admits, so a 10-task pilot cannot carry a margin with any room at all
  (`a_ten_task_pilot_carries_a_margin_of_five_at_most`).

The pilot of 2026-08-11 was **INADMISSIBLE** under the gate as written
(`the_measured_pilot_is_inadmissible`, `admissibleBy 8 ⟨3,12⟩ = false` and
`admissibleBy 8 ⟨1,12⟩ = false`) — as was every other outcome it could have had.

### AMENDMENT 2 (2026-08-11) — the margin, decided and sealed BEFORE the run

Fixed here, before any of the 160 sessions. Sealed by content hash so a later
edit is visible:

```
decision   margin is a FRACTION: marginFor outOf = outOf / 5   (twenty percent)
witness    lean/Proofs/RotFamily.lean
blob       69ab38374a48cbf95fdf6501522dddf98d1ea177
parent     b85b2424ed4eb5c6627046f5ecbbdbfc31883100
```

**The justification does not come from the pilot's results.** `8 = 40 / 5`: §5's
margin was always *twenty percent of the 40-task corpus* in §4. The defect was
flattening a fraction into a number and then applying that number to a 10-task
pilot, where 8 is eighty percent and unreachable. Restoring the fraction
reproduces the preregistered value exactly at the size it was written for —
`the_margin_was_a_fraction_of_the_corpus_not_an_absolute` proves
`marginFor 40 = 8`. That is what makes this a repair rather than a re-choice,
and it is the whole of the argument.

`a_fractional_margin_is_always_reachable` proves `2 · marginFor outOf ≤ outOf`
for **every** size, so the unsatisfiable gate cannot recur at any pilot or
corpus size chosen later.

**Admissibility requires BOTH arms.** `corpusAdmissible` is the conjunction. A
corpus the unrouted arm always fails cannot show a difference between the arms —
that is floor saturation, the twin of the ceiling effect `RotSaturation` exists
to catch.

**The decision goes AGAINST the router, and that is the test of it being
honest.** At `marginFor 12 = 2` the routed arm (3/12) admits and the unrouted
arm (1/12) does not:
`the_routed_arm_admits_and_the_unrouted_arm_does_not`. Therefore
`the_corpus_is_refused_and_must_be_rebuilt`, which is §5's own instruction.

**The convenient alternative is named rather than left to be discovered.** A ten
percent margin would have admitted this pilot:
`a_ten_percent_margin_would_have_admitted_the_floor` proves
`corpusAdmissible (12/10) ⟨3,12⟩ ⟨1,12⟩ = true` beside the twenty percent
`false`. Mutant M11 in `lean/mutate/mutate_rotfamily.sh` applies exactly that
loosening and must always be killed.

### Consequence for the schedule

**The 160 sessions do not start yet.** The corpus is refused at the floor: the
unrouted arm scored 1 of 12, and six of twelve answers in *each* arm hedged by
stating both numbers. The corpus is too hard, or the tasks invite hedging, or
both. Rebuilding it is §5's remedy and it happens before collection, not after.

### The pilot of 2026-08-11 — what was actually run

12 paired tasks (3 per seed family, all ten router lanes), routed arm then
unrouted arm, same prompts from `bench/pilot-prompts.txt`, same config
directory. Manipulation check passed in both directions: **170** router route
records carrying the routed session's id, **0** carrying the unrouted one.
Raw record: `bench/pilot-pairs.jsonl`. Scorer: `bench/pilot-score.js`.

O5 scoring rule, fixed before the results were read and applied identically to
both arms: **success ⇔ the truth value appears in the final message and the
naive value does not.** An answer stating both hedged and does not count.

| | routed | unrouted |
|---|---|---|
| O5 success | 3 / 12 | 1 / 12 |
| hedged (both numbers stated) | 6 | 6 |
| paired wins | 2 | 0 |

The paired result is 2 disagreements and 10 ties, so `n = 2` against a floor of
10 — `the_pilot_cannot_conclude` proves the pilot reaches no verdict, which is
what a pilot is for. **Nothing about H1 is claimed from this run.**

The most informative single observation is not in the table: on F1-01 the routed
arm answered **37** where the truth is 35, and `bench/work-trace.js` flagged that
answer as an unsupported claim (O4 = 1) because no command it ran could establish
a theorem count. The routed arm losing a task is exactly the outcome the
three-outcome verdict rule was added to be able to report.

## 6. Ordering and deconfounding

`RotOrdering.one_ordering_cannot_attribute` already proves a single-ordering
artifact cannot attribute a difference. So, exactly as P2.3 was run:

- every task run in **both** orders (routed-first and unrouted-first),
- both orderings reported separately and required to agree in sign,
- same model, same tools, same working tree, scratch config dir per run,
- the router's own log is written to a scratch path so the benchmark cannot
  edit the tree it measures.

## 7. Verdict rule — fixed

For each of O1–O4, a two-sided sign test across the 40 tasks.

- **SUPPORTED** — the sign is in the claimed direction with **p < 0.01** in
  *both* orderings, and O5 does not regress.
- **NOT ESTABLISHED** — anything else. Including a clean result in one ordering
  only. Including p = 0.02.
- **CONTRADICTED** — the sign is against the claim at p < 0.01 in both
  orderings. This gets written up as prominently as a win would be.

A per-observable verdict. "Three of four supported" is reported as three of
four, never rounded up to "the router does better work".

**The family size is m = 4, and it is derived from the table in §3, not chosen.**
Four observables carry a two-sided test (O1–O4); O5 is a non-inferiority side
condition with no alpha of its own; O6 and O7 are declared descriptive. Earlier
work explored m = 9 and m = 12 — neither is derivable from this document, and
the choice is not cosmetic: at n = 40 the largest still-supported k is 11
uncorrected, **10 at m = 4**, and 9 at both m = 9 and m = 12.
`lean/Proofs/RotFamily.lean` computes `m` from the observable table so it tracks
any change to §3 (`the_family_size_is_derived_not_chosen`,
`adding_a_test_raises_the_family_size`).

**This settles the pilot floor at 10 pairs.** `the_smallest_admissible_pilot_is_
ten_pairs` proves 10 is the smallest n that can reach a corrected verdict at
m = 4, and `a_ten_pair_pilot_must_be_unanimous` proves it can do so only on a
clean sweep. The floor of 12 recorded earlier was an artifact of the unsettled
m = 12, not a property of the design — §5's 10-task pilot was right.

**The three outcomes are exhaustive and exclusive, and CONTRADICTED is real.**
The Lean `Verdict` type carries two constructors, so a significant defeat and a
dead heat both returned `notSupported` — a silent downgrade of the one result
this section promises to publish as prominently as a win.
`RotMoE.Family.Outcome` adds the third:
`a_thirty_one_of_forty_defeat_was_reported_as_a_null` exhibits the case,
`the_new_rule_agrees_wherever_the_old_one_spoke` proves no already-supported
result moves, and `every_result_has_an_outcome` proves nothing falls through.

**The two-sided tail is deliberately NOT label-symmetric.** Swapping the labels
maps k to n − k and the doubled tail does not survive it. That is correct: §3
fixes a direction per observable, so k counts sessions going *against* the claim.
`the_symmetric_repair_would_admit_a_total_loss` shows what imposing symmetry the
obvious way costs — a 40-of-40 defeat would read as SUPPORTED.

## 8. What this cannot establish

- Nothing about **answer quality** as a reader would judge it. That is P2.2 and
  it stays open. `dominance_says_nothing_about_answer_quality` continues to
  forbid reading a structural or process result as a quality result.
- Nothing about other models, other machines, or other task families.
- O4's detector is a heuristic over transcripts. It will be
  **mutation-tested in both directions** — deliberately unverified claims must
  be caught, and deliberately verified ones must not be flagged — and the false
  positive/negative rate of the detector itself is reported alongside the
  result. An instrument whose error rate is unknown cannot carry a verdict.

## 9. Status

**DESIGNED. NOT RUN.** No P2.4 data exists as of this commit. The Lean design
gate (`RotSaturation`, 12 theorems, 11/11 mutants killed) is in place; the
extractor (T13) is not written yet.
