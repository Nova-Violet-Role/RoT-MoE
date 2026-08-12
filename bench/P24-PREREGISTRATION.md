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

| O8 | hedge rate — answers naming BOTH the true and the naive value | the scorer | descriptive only |

O6, O7 and O8 are **descriptive**: they characterise what happened, and are not
part of the verdict. Reporting them is not the same as claiming them.
`the_hedge_rate_does_not_inflate_the_family` re-proves that adding O8 leaves
`m = 4` — a descriptive observable may never enter the multiplicity correction.

O8 was promoted from footnote on 2026-08-11: the pilot measured **6 of 12 in
each arm**, identical, which makes hedging a property of the prompt rather than
of the routing (`the_hedge_rate_was_identical_in_both_arms`). It is already
extracted, so it costs nothing.

### AMENDMENT 3 (2026-08-11) — the scoring rule, preregistered

**The rule was the largest uncontrolled variable in the design.** Measured on
the pilot's own stored sessions: the choice of rule moves a score by **6 of 12**
while the arms differ by at most **2** — `the_scorer_moves_the_score_more_than_
the_arm_does`. A rule chosen by whoever reads the results is exactly what §5
exists to forbid, and until this amendment that is what P2.4 had.

Fixed the same way `m` was: declared as a set, with roles, in
`RotMoE.Family.rules`.

| rule | definition | role |
|---|---|---|
| R1-strict | truth appears and naive does not | sensitivity |
| R2-lenient | truth appears at all | sensitivity |
| R3-leading | the first number in the text is truth | **excluded** |
| **R4-committed** | truth appears, and precedes naive if both do | **PRIMARY** |

**Why R4, argued without reference to the pilot's numbers.** R1 penalises an
answer that gives the right number *and explains why the naive one is wrong* —
better epistemic behaviour, punished. R2 rewards an answer that leads with the
wrong number and mentions the right one in a caveat. R3 measures prose habit,
not knowledge, and is **excluded in advance rather than averaged in**. R4 asks
what the answer *committed to*, which is what a task with a machine-checkable
ground truth tests. R4 is neither the most nor the least favourable — R2 gives
the routed arm its highest raw score.

`exactly_one_primary_rule` forbids deferring the choice to the reader.
The sensitivity analyses are reported **beside** the primary, never substituted
for it, so "the sign held under all of them" is a claim registered in advance.

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

### THE CORPUS FREEZE — 2026-08-12, WRITTEN BEFORE SESSION ONE OF THE 160

The 40-task corpus is frozen as of this line. Recorded **before** any session of
the main run was executed, so that the tasks cannot be adjusted after seeing an
outcome — which is the only thing a corpus hash is for.

```
bench/corpus-40.jsonl
  git-hash   b3b9e3f084a0a0af4563cb1d47f63be534b7e27b
  sha256     b85f2e053518535b3b77412ccb2a806cd40def490ea651385a6f076eaee048da
  lines      40
  ids        40 unique
```

Both presentation orderings are generated *from* that file and are checked to be
non-identical at the head, free of embedded newlines (a line-indexed prompt file
desyncs silently otherwise) and 40 lines each:

```
bench/corpus40-forward.txt   40 lines   corpus order
bench/corpus40-reverse.txt   40 lines   reversed
```

The run is **40 tasks x 2 arms x 2 orderings = 160 sessions**. The ordering
factor exists because task order is a nuisance variable that no amount of sample
size removes: if the routed arm always saw the corpus in the same sequence, any
ordering effect would be perfectly confounded with the arm.

### DEVIATION — 2026-08-12, DECLARED BEFORE SCORING

The plan called for re-running the 12-pair pilot under R4 at the sealed margin
before the main run. That re-run was **skipped**; collection went straight to
arm A of the 160. It is defensible because
`the_measured_pilot_admits_at_the_sealed_margin` was proved **before** the main
run, not after — the pilot's admissibility at the sealed margin is a theorem
about already-collected data, and re-executing the same twelve prompts would
have produced a second sample, not a stronger license. It is recorded here
because an undeclared deviation is worse than a declared one, whatever its
defence.

### THE A/A NULL CONTROL — RUN 2026-08-11, IT PASSED, AND IT CHANGED THE READING

Two **routed** arms, twelve tasks each, same corpus, same plugin, same primary
rule (R4-committed), scored through the identical code path as the A/B analysis.

| arm | route records | R4 score |
|---|---|---|
| routed #1 | 165 | 6 / 12 |
| routed #2 | 167 | 8 / 12 |

Discordant pairs **6**, split **2–4**. Both arms confirmed plugin-ARMED, so the
manipulation check holds in the direction a control needs: neither arm was
silently unrouted.

**Verdict: `notSupported`. `controlAdmissible = true`.** It ran (6 discordant
pairs, not zero), the apparatus found no support between two identical arms, and
the split was not a sweep. `the_null_control_passed`. The release is not voided;
this is what licenses reading an A/B result from this pipeline at all.

**And then it did the job it was built for, which is not flattering.** Two
*identical* arms disagreed on **6 of 12** tasks and split them 2–4. The A/B
pilot disagreed on **2** and split them 2–0. **The A/B difference is no larger
than the difference between two copies of the same arm, and points the other
way** (`the_ab_difference_is_within_aa_noise`). The pilot's apparent advantage
sits inside the range identical arms produce.

No quantity of A/B data could have revealed this. It is the single strongest
argument for running the control before the 160 sessions rather than after.

### AMENDMENT 4 (2026-08-11) — the pilot denominator, the sealed margin, and the seal itself

**§5 never said what the pilot's O5 score is out of.** It is now a derived
quantity: `pilotDenominator tasks orderings := tasks * orderings`. §5's own
10-task pilot, under §6's requirement that every task run in both orders, has a
denominator of **20** (`the_section_five_pilot_denominator_is_twenty`). The
12-task run of 2026-08-11 used one ordering per arm and so has a denominator of
**12**.

**The inherited 8-of-80 margin is INAPPLICABLE at either**, not failing:
`no_pilot_size_can_receive_the_inherited_margin` proves no pilot size up to 40
can receive it. §5 must therefore state a pilot margin rather than borrow the
calibration corpus's.

**The pilot margin, chosen before the pilot is re-run.** The only margin this
project ever preregistered is 8 against 80, which is **exactly one tenth** — a
relation between two declared constants, not a fit
(`the_preregistered_margin_is_exactly_one_tenth`). The pilot margin preserves
that proportion at whatever denominator the pilot has:
`pilotMargin outOf := ⟨outOf / marginDivisor, outOf⟩` with `marginDivisor`
*computed* as `calibCorpus.outOf / preregMargin`. That yields **1** at twelve
pairs and **2** at twenty, both inside the proved reachable bands (≤ 6 and
≤ 10), and `a_one_tenth_margin_is_reachable_at_every_pilot_size` shows the
choice does not expire when the pilot size changes.

The justification cites no pilot score. Applied afterwards, the measured pilot
admits at the sealed margin under the primary rule and under both sensitivity
rules — reported because a gate that passed only under the primary rule would be
weaker than it looks.

**This also resolves the CONTESTED fractional-margin section.** Its diagnosis —
a fraction flattened into a number — was right; its fraction was wrong. I wrote
`/ 5` believing the denominator was the 40-task corpus. Against the real 80 the
proportion is `/ 10`.

**An open defect this amendment could NOT close.** Mutant M21 tried twice to
catch a *frozen derived value* — first by restating the proportion over
literals, then by replacing the computed divisor with `10`. **Both survived, and
both had to:** `calibCorpus.outOf / preregMargin` **is** 10 today, so the
derived form and its current value elaborate to the same term and no build can
tell them apart. "This number is still derived" is a **textual** property; a
mutation suite tests **behaviour**. M21 is withdrawn rather than counted, and
the instrument that would defend this does not exist yet. It is recorded as
open, not as closed.

### THE SEAL (2026-08-11)

Recorded so that a later reader can tell what was fixed before any data existed
from what was adjusted afterwards.

```
governing text  TASKS/PROMISE-TODO.md   34c1274fca8e7616e916f115257e2afd7a93e084
task corpus     bench/corpus-40.jsonl   b3b9e3f084a0a0af4563cb1d47f63be534b7e27b
scoring + gate  lean/Proofs/RotFamily.lean       0cc120e6aefb36bd35d79acc3826551d60f4ad87
null control    lean/Proofs/RotNullControl.lean  fa702b710e5b86d80be21d5e6206af205757e9ca
parent commit   001cf21735d78bff9d1f250d367b6cb005f997e6
```

At the moment of this seal the P2.4 verdict **did not exist**: the pilot reached
no verdict under any of the four scoring rules, the A/A null control had been
designed but not run, and the 160 sessions had not started.

### RETRACTION (2026-08-11, same day) — read this before AMENDMENT 1 or 2

**AMENDMENT 1's charge was false and AMENDMENT 2 is SUSPENDED.** Both are kept
below, unedited, because a record that quietly removes a wrong claim is worth
less than one that shows it being withdrawn.

*The pilot was scored out of 12; §5 says 80.* That is the whole error. I read
"a 10-task pilot per arm" as fixing the O5 denominator at 10, when the very same
sentence says "at least 8 of **80** room". At `outOf = 80` the gate is
satisfiable with room to spare: every score from 8 to 72 admits, 65 of 81
possible outcomes. `the_preregistered_gate_is_satisfiable` and
`the_sound_gate_admits_a_wide_band` prove it. **The gate was sound.**

**Where the 80 actually comes from — measured, after a first answer that was
merely plausible.** This retraction first said "80 = 40 tasks (§4) × 2 orderings
(§6)". That arithmetic does give 80, and it is **not** the document's 80. §1's
own table reads "`rotmoe-calib` | 1/80 in band | refused — floor, margin 8", and
`lean/Proofs/RotSaturation.lean:205` defines `calibCorpus : Score := ⟨1, 80⟩`
with `preregMargin := 8` at `:212`. **80 is the size of the P2.2 calibration
corpus**, and §5's "8 of 80" is that sentence carried over verbatim.

Fitting a number to a plausible story instead of measuring it is the same error
as the one being retracted, committed inside the retraction. It is recorded
rather than silently fixed. `preregisteredMargin` is now *defined* as
`⟨preregMargin, calibCorpus.outOf⟩` — the objects, not the digits — and
`it_refuses_the_calibration_corpus_as_section_one_says` checks it behaves on
`calibCorpus` exactly as §1 records.

**So the open defect is sharper than "a mismatch": §5 never fixed a pilot
denominator at all.** It inherited a margin declared against an 80-item corpus
and paired it with a 10-task pilot. `no_pilot_size_can_receive_the_inherited_margin`
proves no pilot size up to 40 can receive that margin — the question cannot be
answered by accident; it has to be decided and written down.

The theorem that carried the accusation has been renamed to what it actually
proves — `a_margin_of_eight_admits_no_score_out_of_ten`, true mathematics about
a denominator §5 never named.

**The real defect in §5 is a denominator mismatch, and it is still open.** One
sentence names a 10-task pilot and an 80-denominator score. A 10-task pilot
cannot produce a score out of 80, so either the pilot is larger than 10 tasks,
or the O5 score counts something other than tasks, or "8 of 80" is residue from
an earlier design. **That question is not answered here and nothing downstream
of it is decidable until it is.**

**The root cause is a type, not a number.** `admissibleBy` takes a bare `Nat`
margin and a `Score`, and nothing binds them, so a margin meant for 80 could be
applied to a score out of 10 and return a perfectly well-typed `false` — which I
read as a defect in this document. `RotMoE.Family.Margin` now carries its own
denominator and `Margin.applyTo` returns **`none`** on a size mismatch rather
than a verdict (`a_mismatched_denominator_is_not_a_verdict`). The category error
that produced this retraction is no longer expressible.

### AMENDMENT 1 (2026-08-11) — CONTESTED, see the retraction above
### the gate above was unsatisfiable, and that is a
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

### AMENDMENT 2 (2026-08-11) — SUSPENDED, see the retraction above
### the margin, decided and sealed BEFORE the run

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

**SUPERSEDED by the rescore.** Under the lenient rule the same 24 sessions score
9 of 12 and 7 of 12, so the corpus is NOT floor-saturated and the rebuild below
is withdrawn. What the rescore showed instead is bigger: the choice of scoring
rule moves a score by 6 of 12 while the arms differ by at most 2
(`the_scorer_moves_the_score_more_than_the_arm_does`). The scoring rule is the
dominant uncontrolled variable and must be fixed before the full run.

ORIGINAL, WITHDRAWN: The corpus is refused at the floor: the
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

**RUN 2026-08-12. VERDICT: NOT ESTABLISHED.** This section previously read
"DESIGNED. NOT RUN." and was left stale after collection — recorded here rather
than silently overwritten, because a status line that lies about whether data
exists is the same defect class as a stale expected value.

### Collection — all four blocks, measured

| block | turns | valid | route records | required |
|---|---|---|---|---|
| forward, arm A (routed) | 40 | 40 | **427** | > 0 ✅ |
| forward, arm B (unrouted) | 40 | 40 | **0** | exactly 0 ✅ |
| reverse, arm A (routed) | 40 | 40 | **452** | > 0 ✅ |
| reverse, arm B (unrouted) | 40 | 40 | **0** | exactly 0 ✅ |

160 sessions, 0 failed turns, 0 unparsable result files. "Valid" is
`is_error = false` with a `stop_reason` and `num_turns ≥ 1` — counted per turn,
never per file, because a timed-out turn still writes one.

**The manipulation check holds in both directions in both orderings.** The
forward half passing does not carry the reverse half; each arm was joined to the
router log by its own session id.

**A counting trap, recorded because it nearly produced a wrong number.** The
router writes *two* lines per event — one `"kind":"route"` and one
`"kind":"gauge"`. A naive `grep -c <session-id>` returns 854 and 904, exactly
double the route-record counts above. The manipulation check is on `route`
records; the doubled figure is not a second measurement of anything.

**And the log the records land in is not the one the harness exports.** An `env`
block in the CTT `settings.json` beats the inherited `ROTMOE_DEBUG_LOG`, so the
records are in `Claude_Test/.claude/rot-route-debug.jsonl`. Counting against the
exported path returns 0 for every arm — a false "arm A was never routed", which
is the failure direction `bench/ab-session.sh:133-147` already documents and
resolves. Verified again here.

### Verdict under §7, R4 primary, per ordering — never pooled

| ordering | discordant | favouring routed | sign | verdict |
|---|---|---|---|---|
| forward | 3 | 2 | + | no verdict (below the ten-pair floor) |
| reverse | 12 | 10 | + | no verdict (misses the corrected tail) |

**The sign agrees in both orderings.** That is the §6 requirement met, and it is
the strongest statement the run supports. It is *not* significance: neither
ordering clears the Bonferroni-corrected two-sided tail at the settled family
size. Per §7, anything other than p < 0.01 in **both** orderings is
**NOT ESTABLISHED**, and that is the verdict.

Proved, not asserted — `lean/Proofs/RotMainRun.lean`, 5 theorems, `decide`,
axiom-free, `leanchecker` exit 0 with zero bytes:
`both_orderings_lean_the_same_way`, `forward_cannot_conclude`,
`reverse_does_not_clear_the_tail`, `the_main_run_does_not_conclude`, and
`even_the_forbidden_pool_reaches_no_verdict` — the last proving that the
forbidden pooled ⟨15, 12⟩ would conclude nothing either, so no incentive to
break the no-pooling rule ever existed.

### Sensitivity analyses, declared in AMENDMENT 3, reported beside the primary

| rule | forward A/B | reverse A/B | role |
|---|---|---|---|
| R1-strict | 18 / 17 | 22 / 17 | sensitivity |
| R2-lenient | 31 / 29 | 29 / 20 | sensitivity |
| **R4-committed** | **29 / 28** | **28 / 20** | **PRIMARY** |
| R3-leading | — | — | **excluded in advance** |

R3 is not implemented in `bench/main-score.js` at all, so it cannot be reported
by accident. The sensitivity rules agree with the primary in sign and none of
them reaches a verdict either.

### Two obligations are DECLARED UNMET, and the guard is left refusing

`preferenceMeasured` and `p22Established` are both outstanding after this run,
and neither is closed by anything in it.

They are **the same obligation wearing two names**: P2.2 asks whether the routed
arm gives *better answers as a reader would judge them*, and the only instrument
for that is a preference panel — odd n ≥ 3, the author excluded. That is
**recruitment, not engineering.** No amount of further measurement on this
machine closes it, and P2.4 was designed from the start not to try: §8 already
says this experiment claims "nothing about answer quality as a reader would
judge it."

**Both could be closed in ten seconds and will not be.** The probes are
`test -s bench/panel-results.jsonl` and `test -s bench/P22-ESTABLISHED.md` —
`touch` satisfies either. Creating those files without a panel is the fake green
this whole apparatus exists to make impossible, and it would be worse here than
anywhere else: it would manufacture the *one* claim the project has refused to
make five times.

So `checker/push-guard.sh` exits 1 with three rows outstanding, and that is the
correct verdict, not an obstacle to route around. Publishing requires either a
real panel or an explicit decision by the maintainer to push with named
obligations open — a decision the guard documents as being above the script, and
which nobody may infer on his behalf.

### O8 hedge rate — descriptive, both arms, both orderings

| ordering | routed | unrouted |
|---|---|---|
| forward | 13 / 40 | 12 / 40 |
| reverse | 7 / 40 | 3 / 40 |

Computed by `bench/main-score.js`, printed apart from the rule table so it
cannot be misread as a rule. It enters no test and does not inflate `m` —
`the_hedge_rate_does_not_inflate_the_family` proves adding it leaves `m = 4`.

The pilot measured hedging as *identical* in both arms (6 of 12 each), which is
what made it a property of the prompt rather than of the routing. At 40 tasks
the two arms differ by 1 in forward and 4 in reverse, and the rate roughly
halves between orderings in both arms — a presentation-order effect on hedging,
present in the unrouted arm too. Recorded as description. **No claim is made
from it**, and its behaviour across orderings is itself a reason not to.

### The A/A null control, printed beside the result as required

`notSupported`, `controlAdmissible = true` — it ran (6 discordant pairs), found
no support between two identical arms, and was not a sweep. That is what
licenses reading an A/B result from this pipeline at all. It also showed the
pilot's apparent advantage sat inside the range two copies of the same arm
produce.

---

## 10. THE P2.4 OBSERVABLES WERE EXTRACTED — RESULT: 3 SATURATED, 1 CONTRADICTED

**Run 2026-08-12.** §9 above reported the R4 *answer-text* scoring. That is not
what this document preregistered. §3 declares O1–O4 as **process** observables
read out of the transcript, and §7 scores them by a sign test **across the 40
tasks**. Until now they had never been extracted from the main run — the
transcripts existed, `bench/work-trace.js` existed and passed its 16 controls,
and nobody had joined the two. Reporting §9 as "the P2.4 result" was answering a
different question than the one registered here.

### What was run

| step | instrument | exit |
|---|---|---|
| parser controls | `node bench/work-trace.js --selftest` | 0 — **16 passed, 0 failed** |
| per-task extraction | `node bench/work-trace-tasks.js <transcript> <ordering> <arm>` | 0 ×4 — 40 segments each |
| pairing and counting | `node bench/p24-score.js bench/p24-worktrace.jsonl` | 0 |
| verdict | `lean/Proofs/RotP24Run.lean` | build 0, leanchecker 0/0 bytes, 8/8 mutants killed |

Segmentation was **measured, not assumed**: a task prompt is a `type:"user"`
record whose `message.content` is a STRING, while every tool result is also
`type:"user"` but carries an ARRAY. Each transcript yields exactly 40 of the
former against 49+ of the latter, and the extractor **refuses** (exit 3) rather
than guessing if the count is not 40.

### The counts

| observable | claimed direction (§3) | forward d/f | reverse d/f | verdict (§7) |
|---|---|---|---|---|
| O1 verification steps | routed higher | 0 / 0 | 0 / 0 | **SATURATED — no verdict possible** |
| O2 rework edits | routed lower | 0 / 0 | 0 / 0 | **SATURATED — no verdict possible** |
| O3 reads before first write | routed higher | 0 / 0 | 0 / 0 | **SATURATED — no verdict possible** |
| O4 unverified claims | routed **lower** | **40 / 0** | **39 / 0** | **CONTRADICTED** |

### Finding 1 — three of four observables could not express a difference

O1, O2 and O3 produced **zero discordant pairs**: both arms scored zero on every
task, in both orderings. The 40-task corpus asks knowledge questions; no task
builds, edits or writes a file, so three of the four preregistered observables
are structurally silent on it.

This is the failure `RotSaturation` was written after and it happened again, one
corpus later. `saturated_pair_is_a_tie` proved the 84/84 ceiling was a
structural tie before P2.4 was designed; `a_saturated_observable_cannot_conclude`
now proves the general form — an observable with no discordant pairs returns
`notSupported` for **any** favouring count, so the three zeros are not evidence
for the router either. `saturation_is_not_evidence_for_either_side` states that
second half explicitly, because a reader who wants good news will otherwise find
it in a row of zeros.

**This is a defect in the fit between instrument and corpus, and it is ours.**
The corpus was frozen for the answer-text question and then reused for the
process question without checking that the process observables could vary on it.

### Finding 2 — O4 came back against the router, in both orderings, without exception

Of **40** discordant pairs forward and **39** reverse, the routed arm carried
*more* unverified claims in **every single one**. `f = 0` twice.

§7 calls that **CONTRADICTED** and says it "gets written up as prominently as a
win would be". §5 said in advance that O4 "is the one that can embarrass the
router most, which is why it is in". Both promises are kept here.

The sweep is **attributable** rather than an artefact: `RotNullControl.sweep`
exists because a total sweep between two *identical* arms would mean the
pipeline manufactures them. The A/A control on this same apparatus measured
⟨6, 2⟩ — it produced pairs and did not sweep (`the_null_control_did_not_sweep`).

### The confound, declared and NOT applied

O4 counts a number in the final message appearing in no preceding tool output.
Measured alongside the verdict:

| | routed | unrouted |
|---|---|---|
| tool calls (fwd / rev) | 49 / 55 | **103 / 109** |
| evidence bytes (fwd / rev) | 9 652 / 9 864 | **76 150 / 46 461** |

The unrouted arm produced a strictly larger haystack in both orderings
(`the_unrouted_arm_had_the_larger_haystack`), and a larger haystack mechanically
lowers this count. A terser answer therefore scores worse **by construction**,
and `bench/work-trace.js` says so itself: "a restated number and a re-derived one
look identical here."

**No length normalisation was declared in §3 or §7, so none is applied.**
Inventing a correction after seeing an unfavourable result is exactly the
freedom preregistration removes. The verdict stands as CONTRADICTED and the
confound ships beside it as a limitation — not instead of it.

### What is now established, and what the next honest step is

**P2.4 did not establish that the routed arm does better work.** Three
observables were silent and the fourth went the other way;
`p24_does_not_establish_better_work` binds that summary to the measured counts,
and all eight mutants of those counts kill the module.

The next step is **not** to rescore this corpus. It is a corpus of *engineering
tasks* — tasks that build, edit and verify — on which O1–O3 can vary at all. That
is a new collection with its own preregistration, not a reanalysis of this one.

---

## 11. RETRACTION — THE O4 VERDICT WAS WITHDRAWN BY ITS OWN CONTROL

**Same day, 2026-08-12, before §10 was pushed anywhere.** §10 reported O4 as
**CONTRADICTED** and licensed that reading with an A/A control of ⟨6, 2⟩.
**That control was measured on the R4 answer-text scorer.** It is a different
instrument reading a different quantity, and using it to attribute an O4 result
is the same class of error P2.4 was rebuilt to fix — scoring one hypothesis with
another hypothesis's observable. §10's attribution was unearned.

### The control that was needed, built from data already collected

Both orderings run the **same 40 tasks**, so pairing `forward-routed[task]`
against `reverse-routed[task]` is an A/A: same arm, same task, only position
differs. Routing cannot explain any difference there.

| control | discordant | favouring | instrument |
|---|---|---|---|
| routed vs routed | **32** | 26 | `bench/p24-aa-control.js`, exit 0 |
| unrouted vs unrouted | **15** | 3 | same |

O4 moves on **32 of 40 tasks** between two runs of the *same* arm.

### The probe that settles it

O4 counts a number in the final message absent from preceding tool output. So
the question was put directly: across every A/B pair differing in both O4 and
evidence volume, does the side with the **smaller** haystack carry the **higher**
O4?

> **79 comparable pairs. 79 agreements. Rate 1.000.**

Not most — **every one**. `no_statistic_can_separate_them` proves the
consequence: when observed signs equal confound-predicted signs pointwise, *any*
function of those signs returns the identical value on both. No test, no
correction and no re-scoring can recover an arm effect, because the signs
contain none. `a_separating_statistic_needs_a_disagreeing_pair` states the
useful contrapositive — an instrument earns its verdict by exhibiting a pair
that disagrees with the confound, and O4 exhibited zero.

### The corrected verdict

| observable | §10 said | §11 says |
|---|---|---|
| O1, O2, O3 | SATURATED | SATURATED (unchanged) |
| O4 | **CONTRADICTED** | **INADMISSIBLE — instrument confounded at rate 1.000** |

**This does not rescue the router.** "The routed arm does better work" remains
**NOT ESTABLISHED**: three observables were saturated and the fourth is
inadmissible, so P2.4 as run produced no evidence in either direction.
`p24_does_not_establish_better_work` still holds and is not weakened.

**It does retract the claim against the router**, because an unfavourable
overclaim is still an overclaim. §10's docstring called the confound "a
limitation shipped beside the verdict". That was too weak. **A confound measured
at rate 1.000 is not a limitation; it is a refutation of the instrument.**

§10 is left standing above, uncorrected, with this section after it. Editing a
published verdict into agreement with its own retraction would destroy the only
evidence that the apparatus caught itself.

### What O4 must have before it may be used again

1. A haystack-independent definition, or an explicit denominator declared in
   advance.
2. **The A/A control run on O4 itself**, not on a neighbouring instrument.
3. The confound probe re-run, with a disagreement rate strictly below 1 as a
   preregistered admissibility condition.

Instruments: `lean/Proofs/RotP24Control.lean` — build exit 0, `leanchecker`
exit 0 / 0 bytes, **8/8 mutants killed, 0 survived, 0 discarded**.
