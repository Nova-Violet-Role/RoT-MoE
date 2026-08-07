# Changelog

All notable changes to **RoT MoE** are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) —
with one deliberate twist documented below.

**History lives in [`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md)** — every
release up to and including `0.6.2`, unchanged. This file carries the current
release only, so *prior* and *after* stay one screen apart instead of eight
releases apart. `checker/repo-complete.sh` re-measures the counts in the newest
section against the source on every run, which is the reason that section must
not be buried.

---

## [Unreleased]

Work landed after `0.9.2` and not yet cut into a release. The heading is not
decoration: `checker/repo-complete.sh` scans the **newest release section** of
this file for live count claims, and without a bracketed heading here the 0.9.x
section — a record of what that release actually shipped — was being read as a
claim about today's tree. History does not get rewritten to satisfy a counter.

## Twelve fake kills, green in CI for the whole cycle

**Found by reading the full `log.zip` of run `31180174433`, which concluded
`success`.** The lean job's mutation step contained this:

```
mkdir: cannot create directory '/d': Permission denied
mutate/mutate_rotgauge.sh: line 128: /d/tmp/mut/M01.log: No such file or directory
M01  KILLED     exit=1  MODULE DEAD (no olean: every theorem in it is unusable)
```

`mutate_rotgauge.sh:24` read `LOG=/d/tmp/mut` — a Windows drive path, the only
suite of twenty-one not using `mktemp`. On a Linux runner `/d` cannot be
created, so the redirection target does not exist; **when bash cannot open a
redirect it does not run the command and returns 1.** The suite read that 1 as
"the build went red" and recorded a kill. All twelve RotGauge mutants were
scored `KILLED` on a runner where `lake` never ran once, the suite printed
`12 killed, 0 survived, 0 discarded`, and the job passed.

Nothing about the theorems was learned, and the repository published the
opposite.

**Three repairs, because the path was only the proximate cause.**

1. **The path.** `mktemp -d`, as in every sibling suite, plus a start-up check
   that the directory exists and is writable — measured: it now exits 2 on the
   CI condition instead of manufacturing kills.
2. **The class, in all 21 suites.** A non-zero exit is evidence only if a build
   actually ran. Every suite now refuses to score a kill when the build produced
   no log, reporting `DISCARDED` — which cannot exit 0. Verified by planting the
   exact CI condition: **9 DISCARDED, exit 1**, where the old code gave *12
   KILLED, exit 0*. Both suite shapes were then re-run unplanted and still kill
   for real (`RotGauge` 12/0/0, `RotAcquire` 5/0/0, `RotAttribute` 9/0/0).
3. **The rule, enforced.** `checker/mutant-discipline.sh` gained a phase that
   fails any suite with a machine-local `LOG=` path or without the
   attributability guard, with two negative controls proving both predicates can
   fire on the exact form that shipped. **34 → 79 passed.**

**And the rule is now a theorem, not a habit.** `lean/Proofs/RotMutant.lean`
already modelled whether a *patch* landed; this defect is one step later, and
the patch had landed perfectly.

| theorem | what it settles |
|---|---|
| `naive_rule_manufactures_a_kill` | the CI observation, reproduced: shipped rule → `killed`, repaired rule → `discarded` |
| `unattributable_is_never_killed` | **general**: no evidence, no kill — for every run and every status |
| `killed_carries_its_evidence` | the converse, so the guard cannot degenerate into "never kill anything" |
| `a_real_kill_survives_the_new_guard` / `a_survivor_is_still_a_survivor` | non-vacuity: it still kills, and still recognises a survivor |
| `rules_differ_exactly_on_missing_evidence` | exhaustive over every observable combination, kernel-checked |

`rules_differ_exactly_on_missing_evidence` **refuted its own first version.** It
was stated with a third disjunct, `be.val = 0`, on my assumption that a zero
status was harmless; `decide` proved that false. With no evidence, the shipped
rule reports **survived** — a claim of robustness about a build that never ran,
exactly as unfounded as the twelve kills. Only the kills were noticed, because
only the kills looked like work. `naive_rule_also_manufactures_a_survivor` now
records that half explicitly.

Suite `mutate_rotmutant.sh` grows M14–M18: attributability switched off (M14),
the evidence check deleted so the shipped rule returns verbatim (M15), the
recorded CI observation edited to erase the measurement (M16), the guard turned
into a blanket refusal (M17), and **my own refuted disjunct put back** (M18).
All five killed. M17's first needle matched two lines and the suite reported
`DISCARDED (needle x2)` rather than guessing — it was retargeted, not explained
away.

## The A/B was not null — my analysis was blind, and here is the retraction

**I published a null result that the data does not support.** The 80×2 A/B run
was reported as "null on every pre-registered primary". Two defects in the
*analysis*, both mine, both found on 2026-08-07 by re-reading the raw
transcripts that the committed corpus had been derived from:

**1. The configuration was dropped in derivation, not missing from the run.**
`bench/ab-metrics.jsonl` carried `arm, turn, err, dur, cost_micro, len, q,
hedge, narr, leak` — no model, no effort, no thinking level. I described this as
"the experiment never recorded the model". That was wrong. Every raw turn
carries `modelUsage`, and it says the same thing 160 times:

| | measured |
|---|---|
| model, all 80 turns, **both arms** | `claude-opus-5[1m]` |
| incidental other model | one 17-token `claude-haiku-4-5` call, across the whole corpus |

The run was on the strongest available configuration. The corpus simply threw
the field away, and I read the absence as a property of the experiment.

**2. The metrics that were examined were not the metrics that moved.** The three
primaries genuinely tied. Output **tokens** — computable from the very same
transcripts, never extracted — did not:

| endpoint | routed | unrouted | delta | paired sign count | two-sided sign test |
|---|---|---|---|---|---|
| output tokens / turn | **440** | **675** | **−34.8%** | routed fewer on **69 of 88**, 0 ties | **p = 7.8 × 10⁻⁸** |
| cost per turn | $0.1168 | $0.1648 | **-29.1%** | cheaper on **83 of 88** | p < 10⁻¹² |
| duration / turn | 10 230 ms | 13 474 ms | −24.1% | faster on 56 of 88 | p = 0.014 |
| trailing question | 0.000 | 0.000 | — | all ties | — |
| self-narration | 0.000 | 0.000 | — | all ties | — |
| hedging tokens | 0.034 | 0.000 | **worse routed** | worse on 3, better on 0 | — |

Negative control for the test itself: a 45/88 split gives p = 0.915, so the
instrument can return "no effect" and does.

**The corpus is 88 pairs, not 80.** Eight prompts were added — see the per-lane
section below — and the original 80 were re-derived unchanged: **1600
shared-field comparisons, zero differences.** The figures above therefore move
because the corpus grew, never because a number was edited to fit a sentence.

**What this does and does not license.** It licenses: *on `claude-opus-5[1m]`,
across 80 paired prompts, the routed arm produced a third fewer output tokens,
cost a third less and finished a quarter faster, with no measured change in
error rate, trailing questions or self-narration, and slightly more hedging.*
It does not license any statement about answer **quality** — nothing here
measures that, and no proxy was substituted for it, because a proxy scored by
the same model family is not an instrument.

**Fixes, so the defect cannot recur silently:**

* `checker/ab-analyze.sh` now derives `model` per turn (by output tokens, not by
  first key — one incidental 17-token call must not name the experiment) and
  reports `5b output TOKENS` beside the character length it used to trust.
* `bench/ab-metrics.jsonl` regenerated from the raw corpus with `outTok` and
  `model` added. **The 1280 shared-field comparisons against the previous file
  differ in zero places** — every published figure is reproduced exactly; the
  regeneration only adds columns. A corpus edited to be more flattering would
  have shown up right there.

## Every lane scored on its own effect — and one lane goes the other way

A single pooled figure was never the right reading, and `RotAttribute` proves
why: `pooling_reverses_every_stratum` exhibits a checked instance where the
pooled verdict contradicts **every** stratum, and
`balanced_pooling_agrees_with_the_strata` pins that on unequal stratum sizes.
This corpus has lanes of size 4 to 36. That is precisely the shape the theorem
warns about, so the lanes are now scored separately.

**The lane is not new data.** It is a function of the prompt, and the shipped
router computes it — `hooks/rot-router.sh --route`. Both arms can therefore be
labelled offline from two committed files, and CI re-derives the whole table
with no session and no credential.

| lane | n | routed | control | delta | routed fewer | sign p |
|---|---|---|---|---|---|---|
| FORGE | 36 | 525 | 751 | −30.1% | 28/36 | 1.2e-3 |
| CONVERGENT | 16 | 322 | 404 | −20.5% | 11/16 | 0.21 |
| CLINICAL | 8 | 495 | 758 | −34.7% | 7/8 | 0.070 |
| PREDICTIVE | 4 | 680 | 996 | −31.8% | 4/4 | 0.125 |
| CREATIVE | 4 | 248 | 376 | −34.0% | 3/4 | 0.625 |
| EXECUTIVE | 4 | 227 | 513 | −55.7% | 4/4 | 0.125 |
| RECURSIVE | 4 | 248 | 939 | −73.6% | 4/4 | 0.125 |
| STEALTH | 4 | 536 | 852 | −37.1% | 3/4 | 0.625 |
| STRATEGIC | 4 | 485 | 1062 | −54.3% | 4/4 | 0.125 |
| **EMPATHIC** | 4 | **256** | **220** | **+16.1%** | **1/4** | 0.625 |

**Nine of ten lanes favour the routed arm; the lane-level sign test is
p = 2.0 × 10⁻³.** Only FORGE reaches significance on its own — the small lanes
hold four turns and cannot, whatever they show. What they can do is agree, and
that is the weaker claim being made here, labelled as weaker.

**EMPATHIC is the exception and it is the most informative row in the table.**
It is the one lane where the router makes the answer *longer*. That is what the
EMPATHIC profile is for — Violet at λ 2.3, Carnage at 1.8, compression damped —
so a router that shortened everything uniformly would be evidence the profiles
do **not** do what they claim. The effect is directional, not global. Anyone
selling "the router makes Claude terser" is describing nine lanes and ignoring
the tenth.

**Two lanes had no prompts at all, and the checker said so.** The first per-lane
run reported `lanes with NO prompt in the corpus: EMPATHIC, STRATEGIC` and
**failed**. An ability with no sample is an ability that was not scored, and a
claim ranging over it would be an overclaim — so the gap was closed by
measuring, never by narrowing the check: eight prompts were added (four per
lane, each verified against the shipped router *before* being written), and both
arms were collected with their validity controls passing — **9 route records in
the routed arm, 0 in the control**.

`checker/ab-lanes.js` is a real file rather than a `node -e` string because the
inline form died on escaping: the generator, the shell heredoc and the node
argument each consumed one backslash, and `split("\n")` reached node as a
literal newline. That is the second escaping failure of the session — the first
turned mutation needles into literal `\n` and scored nine DISCARDED. The fix is
one less level of nesting, not more backslashes.

## Why a null can belong to the analysis instead of the world — `RotAttribute`

The retraction above is not an anecdote, it is three theorems.
`lean/Proofs/RotAttribute.lean`, 24th module, states the failure modes so the
harness is checked against them rather than against my memory of what went
wrong.

| theorem | what it settles |
|---|---|
| `erased_summary_is_blind` | **every** summary function agrees on two datasets that erase to the same list — a dropped column is not merely hard to recover, the verdict is provably independent of it |
| `erasure_hides_information_a_lane_aware_reading_has` | the load-bearing form: two datasets no erased summary can separate, that a lane-aware reading separates outright |
| `routed_wins_lane1` / `routed_wins_lane2` | the routed arm strictly wins in **both** strata |
| `pooling_reverses_every_stratum` | …and strictly **loses** pooled. Simpson's paradox, as a checked instance, not a citation |
| `stratified_and_pooled_disagree` | the three above as one statement |
| `balanced_pooling_agrees_with_the_strata` | **the control** — same values, equal stratum sizes, and pooling now agrees. This is what pins the reversal on the imbalance |
| `primaries_can_tie_while_the_turn_differs` | two turns identical on every primary and different in output tokens: exactly the shape that produced the false null |
| `measured_routed_emits_fewer_tokens` | 447 < 678, pinned so a later edit cannot quietly reverse the finding |

Executed, not just elaborated: `#eval` gives `(10, 20)` and `(100, 110)` per
stratum, `(91, 29)` pooled — routed worse — and `(55, 65)` once balanced —
routed better. Same numbers throughout; only the group sizes change.

**`balanced_pooling_agrees_with_the_strata` exists because a mutant survived.**
A05 originally rebalanced one arm and expected the paradox to collapse. It
survived, correctly: a one-sided rebalance relocates the imbalance rather than
removing it, so the module had demonstrated an effect without demonstrating its
cause. The repair went into the *module* — the balanced control was added — and
A05 now breaks that control instead. A surviving mutant that changes the
mathematics is the suite working, not the suite failing.

Suite `lean/mutate/mutate_rotattribute.sh`, mutants A01–A09: erasure keeps the
lane (A01); the lane-aware reading is blinded too (A02); routed stops winning
lane 1 (A03) or lane 2 (A04); the balance control is broken (A05); `mean`
becomes a size-blind sum (A06); the projection is widened so the primaries can
no longer tie (A07); the measured direction is flipped (A08); the two measured
means are made equal — the very verdict round 1 published (A09). **All nine
killed, none survived, none discarded.** Its first run scored 9 DISCARDED
because the generator emitted literal `\n` where line continuations belonged;
the harness reported that as a defect in itself rather than as nine robust
theorems, which is the only reason the second run means anything.

Counts move to **24 modules, 578 theorems, 21 mutation suites, 270 mutants**.

## A test that creates its own precondition — green on three platforms

**Measured in CI run 31116857127, and it had been green the whole cycle.**
`checker/live-session-smoke.sh` guarded its authenticated phase like this:

```sh
[ -f "$HOME/.claude/.credentials.json" ] && HAVE_CREDS=1
ls "$HOME/.claude"/*.json >/dev/null 2>&1 && HAVE_CREDS=1     # <- this line
```

The glob matches **`settings.json`** — a file the same script's own `ARM_ROUTER.sh`
call creates a few lines earlier. So a runner holding no credentials at all reported
*credentials present*, ran a session that could not authenticate, and logged, on
ubuntu **and** windows **and** macos:

```
PARTIAL the router line appeared 1 time(s) but the session exited 1.
```

The job was green, because `PARTIAL` incremented neither counter.

Two independent defects met in three lines, and they fail in opposite directions:

- **The precondition detector was satisfied by the test's own output.** Past that
  line it is not a weak check, it is a constant.
- **The verdict rested on a signal present in the failure path.** The router line
  is written by the hook when the prompt is *submitted*, before the session can
  die, so it can testify that the hook ran and to nothing else.

Both repaired. Credentials now mean `.credentials.json` or `ANTHROPIC_API_KEY`,
nothing else. A session that exits non-zero **with** credentials is a failure, and
so is a timeout — with one retry at double the budget first, because a busy machine
is not a defect and an unproven claim is not a pass. The pass condition never moved:
the session must COMPLETE and carry the line. Measured on the first live run after
the change: `exit=124 at 180s -> retry -> exit=0`, `R20: PASS`.

**`checker/ctt-session.sh` was testing an environment nobody ships.** The
maintainer's `CTT` launcher does three things; the harness did one. It now mirrors
the launcher: the credential is re-copied from the live file on every run (it is a
snapshot, and a stale one killed 20 turns), and the proxy environment is cleared —
measured leaking a populated `ANTHROPIC_BASE_URL`, so every "CTT" turn had
been going through the rolling-context proxy instead of the isolated path.

A symlink was tried for the credential and **reverted**. Claude Code rewrites
`.credentials.json` on token refresh, so a link would let a test session write the
live credential — breaking exactly the one-way isolation the design depends on.
There is no such thing as a one-way link; the copy is the one-way link.

`lean/Proofs/RotObserve.lean` §10 and §11 state both shapes generally:

| theorem | what it settles |
|---|---|
| `loose_detector_is_constant_after_setup` | after its own setup the detector is `true` for **every** world — it detects nothing |
| `loose_detector_cannot_see_a_missing_credential` | the measured case: no credential, reported ready |
| `strict_detector_survives_setup` | the repair, and the property that makes something a detector: **invariance under the test's own setup** |
| `strict_detector_is_evidence` | it still separates the two worlds, so it is not a constant in the other direction |
| `a_link_propagates_backwards` | for every value: a write through a link changes the original |
| `a_link_lets_the_test_overwrite_the_live_credential` | the concrete hazard that was avoided |
| `a_copy_never_propagates_backwards` | for every prior state and every write, the original is untouched |
| `a_copy_carries_the_original_forward` | and it is not one-way by being inert |
| `refresh_then_write_preserves_the_live_credential` | both halves — the isolation property CTT depends on |

Build exit 0 with **zero warnings**; axioms `propext` or none beyond it, no
`sorryAx`; `leanchecker` exit 0, zero bytes. Mutants **M24–M28** added — **all
killed**, 0 survived, 0 discarded. M25 was reported `DISCARDED` on its
first run because the replacement contained its own needle, and was rewritten
disjointly rather than counted; a discard is a statement about the harness, never
about the theorem.

Credentials in repository secrets were put to the maintainer and **declined**, so
`marketplace-session.sh` stays `exit 3` off-runner by decision, not by omission —
recorded in `ci.yml` so it is not reopened as a way to make a line green.

Counts move to **504 theorems / 22 modules / 19 suites / 226 mutants**.

---

## Symbiogenesis is generative — and that half is a theorem, not a claim

The engine's strongest assertion is about **reach**: that fusing two lenses
produces a point of view neither parent occupies, that Eidolon can keep doing
it, and that the supply of distinct points of view is therefore not bounded by
the roster of nine.

That is mathematics. It does not need an A/B test, it needs a proof — and
`lean/Proofs/RotSymbiogenesis.lean` is that proof. 21 theorems, 12 mutants, all
killed.

### What is now PROVED

| theorem | claim it settles |
|---|---|
| `forge_matches_the_spec` | the operator reproduces the spec's own worked hybrid (Claude × Anti-Venom → λ 1.7 · H 0.35 · μ 1.05) exactly |
| `fuse_H_gt_left` / `_right` | a hybrid's entropy strictly exceeds **both** parents' |
| `fuse_ne_left` / `_right` | **a hybrid is never one of its parents** |
| `fuse_escapes_any_roster` | for **any** finite roster — nine, or nine hundred, or every hybrid built so far — fusion lands outside it |
| `fuse_lam_gt_mean` | the `+0.2` is a real gain: fusion strictly exceeds the mean |
| `fuse_mu_ge_both` | μ is a maximum, so fusion can never lower quality below a parent |
| `chain_H` / `chain_lam` | iteration is exactly linear: `+1/20` entropy and `+1/5` λ per generation |
| `chain_injective` | **no two generations are the same lens** |
| `symbiogenesis_generates_infinitely_many` | the reachable set is **infinite** — the precise content of "infinitely generated combinations" |
| `lens_space_is_infinite` | there is no finite catalogue of points of view to enumerate |

`#eval` on the chain from the Verified Forge:
λ 1.7 → 1.9 → 2.1 → 2.3 → 2.5, H 0.35 → 0.40 → 0.45 → 0.50 → 0.55.

### And what it deliberately does NOT say

Two boundaries are theorems too, so they cannot be quietly dropped:

- `fuse_may_gain_no_quality` — a new triple is **not** a better lens. μ being a
  maximum means fusion never *loses* quality, not that it gains any.
- `equal_reading_does_not_imply_equal_lens` — **the gauge compresses.** Two
  different lenses can share a reading, so an `R/s+` value is evidence of
  activity, never a fingerprint of the point of view that produced it. The
  honest direction is `distinct_reading_implies_distinct_lens`.

Nothing here concerns output quality. That is a separate question, settled by
measurement and by nothing else, and it is not settled.

### Why ℚ and not `Float`

Float addition is not associative, so the shipped arithmetic can pin a concrete
row and can never support a general statement about iteration. Every constant is
exact (`0.2 = 1/5`, `0.05 = 1/20`), the spec's worked hybrid is pinned against
these definitions, and the general theorems are therefore real rather than
artefacts of rounding. `RotEnsemble` continues to bind the Float arm.

### The mutants

S01–S12: **all twelve killed, none survived, none discarded** (the repo-wide
figure stays the one in `README.md`; a per-suite count must not be written in
the phrasing `repo-complete` reserves for the total, or it shadows it). They
plant the objections
directly: delete the novelty term, delete the λ gain, average μ instead of
maximising, take the minimum entropy, misquote the spec's hybrid by one digit,
collapse iteration so it saturates, weaken strict monotonicity to `≤`, add the
Verified Forge **to** the roster so fusion no longer escapes it, and — S12 —
flip the anti-overclaim boundary to assert the fingerprint property that was
never proved.

S02 was first reported **DISCARDED** (needle whitespace), fixed, and re-run. A
discarded mutant is a claim about the harness, never about a theorem.

Counts: **567 theorems / 23 modules / 20 suites / 261 mutants**.

---

## Atomicity is not enough: the atomic write dropped the exec bit and CI caught it

Run on `6791683`: `mutate the checker` failed on **ubuntu-latest and
macos-latest** with

```
H00  META-CONTROL FAILED: the checker goes red on a NO-OP edit.
```

`checkers (windows-latest)` passed the same commit, and that asymmetry is the
whole diagnosis. Making the mutation writes atomic used `> "$f.mtmp" && mv -f`.
A shell redirect **creates** the temp at `0666 & ~umask` = `0644`, and `mv`
carries the **temp's** mode onto the target — so `hooks/rot-router.sh` arrived
non-executable, `checker/cross-diff.sh:52` runs it directly, the call produced
nothing, and the meta-control asserting that a no-op edit leaves the checker
green went red. Windows has no exec bit, so the platform this was developed on
could not see it.

Every mutant below H00 still reported KILLED. That is exactly what H00 exists to
expose: **with the baseline broken, those kills measured nothing.**

The repair keeps the rename and carries the mode:

```sh
cp -p "$f" "$f.mtmp"      # clone the ORIGINAL's mode into the temp
cat raw > "$f.mtmp"       # truncate in place -- a redirect does NOT change
                          # the mode of a file that already exists
mv -f "$f.mtmp" "$f"      # one rename, correct mode
```

All four write sites use that shape, and the harness now reports a mutant that
loses the exec bit as **DISCARDED — harness bug**, never as a finding about the
hook.

### `RotObserve` §17 — seven theorems on what a rename carries

| theorem | what it settles |
|---|---|
| `fresh_temp_drops_the_exec_bit` | replacing via a fresh temp yields a non-executable file, whatever the contents |
| `naive_atomic_replace_can_break_an_executable` | the bug exists — there is such a file |
| `cloned_temp_preserves_the_exec_bit` | **the repair**, for every file and every content |
| `cloned_temp_still_writes` | and it actually writes — a mode-preserving no-op would be the opposite failure |
| `cloned_temp_changes_only_the_content` | the general form: a clone changes **only** the content, so a future field cannot quietly escape |
| `restore_via_clone_preserves_exec` | the restore path too, not just the mutation |
| `naive_replace_is_harmless_when_nothing_is_executable` | records that "it worked on my machine" was **true** and useless |

The lesson generalises past file modes: **a replacement carries every attribute
of the replacement, not of the thing replaced.** Anything the original had and
the new object was not given is lost at the instant of the swap — so the temp
must be built *from* the original, never from nothing.

`#eval` reproduces the failure: naive → `{ content := 22620, exec := false }`,
cloned → `{ content := 22620, exec := true }`. Build exit 0, zero warnings both
trees, `leanchecker` exit 0, mutants **M49–M51** all killed.

Counts: **546 theorems / 22 modules / 19 suites / 249 mutants**.

---

## A SIGKILL left a mutated router on disk, one `git add -A` from being published

Measured three times in one session on 2026-08-07. A commit whose gate run
exceeded a wall-clock ceiling had its **entire process tree SIGKILLed**. The
mutation checker's `trap ... EXIT INT TERM` is correct and did not help:
**SIGKILL cannot be trapped**. What was left on disk:

```
hooks/rot-router.sh          MUTATED -- STEMS_STEALTH missing 'token compress'
hooks/rot-router.sh.mutbak   the only surviving copy of the original
```

A live mutant in a **shipped** hook. `git add -A` at that moment would have
published a router that no longer routes STEALTH on `token` or `compress`, with
a commit message describing a fix.

### Recovery cannot depend on a signal handler

| where | what changed |
|---|---|
| `checker/mutate-checker.sh` | recovers **at start-up**: a `.mutbak` present before this run made one means the last run died, so the backup is the truth — restore it, say so loudly, continue |
| `checker/repo-complete.sh` | **refuses any commit** while a `.mutbak` exists, and prints the restore command |
| `lean/mutate/mutate_rotobserve.sh` | `MUT_ONLY="M45 M46"` runs a chunk; a filtered run prints **PARTIAL** and exits 3, never 0 |

The restore instruction is deliberate and it is the opposite of a cleanup:
**never delete a stray `.mutbak`.** The backup *is* the original. Deleting it
promotes the mutant to the real file — the one irreversible move available here.

The chunking exists because the suite reached 48 mutants and each rebuilds the
module, so a full pass outgrew the ceiling that caused the kill in the first
place. A chunk that could pass for a suite would be far worse than the timeout,
hence exit 3 and a banner naming how many mutants were **never applied**.

### `RotObserve` §16 — nine theorems on interrupted mutation

| theorem | what it settles |
|---|---|
| `recoverable_before_backup` / `recoverable_after_backup` | interruption before or between the two steps is harmless |
| `backup_then_mutate_is_recoverable` | **backup first** and every interruption point is survivable |
| `mutate_then_backup_can_lose_the_original` | the other order loses it outright — the order is not a style choice |
| `restore_recovers` | restoring returns exactly the original |
| `restore_idem` | recovering twice is safe, so start-up recovery may run on an already-repaired tree |
| `restore_clears_the_backup` | a repaired tree cannot be mistaken for an interrupted one |
| `dropping_the_backup_loses_the_original` | deleting a stray backup destroys the last copy |
| `save_mutate_restore_round_trips` | the whole cycle returns the tree exactly as it was |

`#eval` on the measured bytes: `{live := 22614}` → mutate → `{live := 22620,
backup := some 22614}` → restore → `{live := 22614, backup := none}`; and
`dropBackup` on that middle state leaves `{live := 22620, backup := none}` —
the original gone. Mutants **M45–M48**, all killed, after M48 was first reported
**DISCARDED** by the harness's own did-it-apply check for inserting two
definitions instead of one.

Counts: **539 theorems / 22 modules / 19 suites / 246 mutants**.

---

## `hook 0.09 != corpus 0.09` — the gate was right and its message was useless

CI run 31148233876, `checkers (windows-latest)`, step "gauge hook corpus": six
rows failed, every one of them reporting two values that **render identically**.
Ubuntu and macOS passed the same commit.

The runner checks out with `core.autocrlf=true`. There was no `.gitattributes`,
so `checker/gauge-corpus.tsv` arrived with CRLF, the last tab-separated field
became `0.09\r`, and the comparison against the hook's `0.09` correctly failed.
A carriage return has no glyph, so the diagnostic printed the difference away.

**The gate was not wrong. The instrument could see a difference it could not
show** — and that cost an hour that the bytes would have given away instantly.

### Three layers, because one is not enough

| layer | what it does |
|---|---|
| `.gitattributes` (new) | `* text=auto eol=lf` — the working tree is LF on every platform, so a checker reads the bytes that were committed |
| `checker/gauge-hook-corpus.sh` | strips CR from **every** field, not just the last, and escapes CR/TAB in failure messages so two different values can never print alike |
| `checker/portability.sh` phase 7 | refuses any file carrying CRLF **in the index**, with a control that plants one, plus an assertion that `.gitattributes` still pins `eol=lf` |

`git add --renormalize .` fixed **16 files that were already committed with
CRLF** — 13 `.codemap` JSONs, both EUPL licence texts, and
`checker/corpus-remind.txt`. No attribute can repair those; the bytes are in the
index and every clone gets them.

Phase 7 distinguishes two cases on purpose. CRLF **in the index** is a failure:
it reaches every clone and no setting undoes it. CRLF **in the working tree over
an LF index** is only a NOTE, because git normalises it on `add` and nothing
wrong can reach the index — failing there would turn a legitimate local
generator into a red build and invite deleting the check, which is how real
coverage gets destroyed.

### `RotObserve` §15 — six theorems on the two halves of the repair

| theorem | what it settles |
|---|---|
| `shown_can_hide_a_real_difference` | a terminal CAN render two different fields identically — the defect, as a property |
| `stripCell_ignores_trailing_cr` | normalisation recovers the comparison, for every field |
| `stripCell_ignores_cr_anywhere` | CR mid-record too — why the checker strips every field, not the last |
| `stripCell_faithful` | **normalisation never invents agreement**: CR-free fields that normalise equal WERE equal |
| `stripCell_idem` | stripping twice is stripping once, so defensive normalisation cannot change a verdict |
| `escape_injective` | different fields print differently — the property the repaired message needed |

`stripCell_faithful` is the one that matters. Stripping bytes before a
comparison is one careless step from disarming the gate, and that theorem is
what says the repair is not a weakening.

Build exit 0 with **zero warnings in both trees** — the `simp` sets are squeezed
from `simp?` because mathlib's flexible-simp linter rightly refuses a proof that
rests on whatever `simp` does next release. `leanchecker` exit 0. `#eval`
reproduces the CI defect: `shown` equal while the fields differ, `stripCell`
equal, `escape` different. Mutants **M41–M44**, all killed.

Counts: **530 theorems / 22 modules / 19 suites / 242 mutants**.

---

## The A/B ran: the pre-registered endpoints came back NULL, and cost fell 31.6%

**80 paired turns with the plugin armed against 80 with it disabled**, same 80
prompts in the same order, same config directory, tools off in both arms.
Protocol frozen in advance, with three amendments each recorded before the data
they affect. Arm A verified routed (111 route records); arm B verified unrouted
(**zero**). 80/80 valid turns per arm, zero errors in either.

### The pre-registered primary endpoints did not support the hypothesis

| endpoint | routed | unrouted | 80 paired |
|---|---|---|---|
| trailing question | 0.000 | 0.000 | 80 ties |
| self-narration | 0.000 | 0.000 | 80 ties |
| hedging tokens | 0.037 | 0.000 | routed **worse** on 3, better on 0 |

Written plainly because the protocol required it in advance: **the claim that
routing improves these three voice properties is not what the data shows.**

Two of the three could not have shown anything -- the unrouted arm already
scored zero, so there was no room to improve. That is a defect in the ENDPOINT,
not a result about the router, and `RotObserve` §14 now proves the distinction
rather than leaving it as an excuse.

### A secondary metric moved hard, and it stays secondary

| metric | routed | unrouted | delta | paired sign count |
|---|---|---|---|---|
| cost per turn | $0.1013 | $0.1481 | **-31.6%** | cheaper on **75 of 80** |
| response length | 584 ch | 762 ch | -23.4% | shorter on 67 of 80 |
| duration | 10.1 s | 13.5 s | -24.6% | faster on 51 of 80 |
| is_error | 0 | 0 | -- | 80 ties |

75 of 80 is not noise. It is also not a result this protocol may claim, because
cost was pre-registered as descriptive. Promoting a metric to the headline after
watching it move is the exact laundering the pre-registration exists to stop, so
it is recorded as the hypothesis for a round 2 that names it primary in advance.

**Not measured: whether the answers are as good.** The only rater available is
the model that wrote them. Cheaper and shorter is an improvement only if the
content survived, and nothing here establishes that. Round 2 needs a mechanical
groundedness proxy -- does the answer name the file, lemma or constant it was
asked about -- so brevity cannot be bought with emptiness.

### Three defects the run found, none of which a theorem would have

1. **CTT was running a router killed at 30 s.** Starting an hour earlier would
   have made arm A a second arm B and produced a false null.
2. **The first disarm did nothing.** Emptying `installed_plugins.json` left the
   plugin firing: 16 turns, **39 route records**. Caught only by the harness's
   own "arm B must be zero" control, and those turns were deleted. The real
   switch is `enabledPlugins`; arm B now uses `claude plugin disable`.
3. **A benchmark turn executed `checker/axiom-audit.sh` against this repo.**
   Run 1 of arm A was discarded and archived for it, with the reason recorded
   before any answer text was read.

`checker/ab-session.sh` collects and refuses a pass on an empty collection;
`checker/ab-analyze.sh` computes only the frozen metric list; `bench/ab-prompts.txt`
holds the 80 prompts so neither arm can drift from the other.

### `RotObserve` §14 -- seven theorems about what an endpoint can attribute

| theorem | what it settles |
|---|---|
| `floor_endpoint_cannot_improve` | a control arm at zero admits no improvement -- for every endpoint |
| `improvement_requires_room` | the positive form, checkable BEFORE collecting data |
| `equal_arms_attribute_nothing` | a tie is not weak evidence in either direction |
| `control_at_least_treated_attributes_nothing` | the metric-9 case: 9 routed vs 12 unrouted attributes exactly nothing |
| `attributable_le_difference` | the control count bounds what the mechanism can be blamed for |
| `an_endpoint_can_be_worse_when_treated` | the design must be able to express a loss, or it is not a test |
| `all_ties_leave_no_sign_count` | 80 ties is the same evidence as one tie: none |

Build exit 0, zero warnings; axioms `propext`/`Quot.sound` (`Classical.choice`
for the list theorem), no `sorryAx`; `leanchecker` exit 0. `#eval` reproduces the
measured numbers: attributable 0 for the leak metric, 3 for hedging, `(0,0)`
sign counts on 80 ties. Mutants **M37-M40**, all killed.

Counts: **523 theorems / 22 modules / 19 suites / 238 mutants**.

---

## The router was being killed at 30 seconds, and a killed hook is silent

**Measured 2026-08-07 by the maintainer, found by accident.** Opening the debug
view (CTRL+O) showed the router **timing out** on real prompts. Neither install
path declared a `timeout`, so Claude Code's default of 30 s applied — and a hook
that reaches its limit is killed outright. It contributes nothing: no marker, no
lane, no gauge, not even a partial line.

**The observable is identical to having no hook installed at all.** That is why
this survived every session log and every transcript sweep, and it means earlier
readings of the form "the router did not fire here" cannot be trusted; they are
consistent with a router that fired and was killed. `RotObserve` §13 states it:
`silenced_is_indistinguishable_from_absent` proves the two observations are
*equal*, not merely similar.

The work is proportional to the traffic — nine lens activities computed per turn
over the prompt **and** the reply — so a bound sized for a trivial script is the
wrong shape of bound, not just a small one.

**Both install paths now declare 1200 s**: the five entries in
`hooks/hooks.json` (marketplace) and `HOOK_TIMEOUT_SECONDS` in
`hooks/settings-merge.js` (hand install), which previously appended entries with
no bound at all.

`checker/hook-timeout.sh` is new, and it deliberately **does not pin 1200**:

| phase | what it asserts |
|---|---|
| declared | every shipped hook entry carries a numeric `timeout` |
| single | one bound across all events, not one per event |
| used | the constant is written into the entry, not merely defined |
| agreement | the two install paths are compared **to each other**, never to a literal |
| adequacy | the bound exceeds the 30 s default it exists to replace |
| controls | stripped timeouts detected; a bound equal to the default rejected; two different bounds distinguished |

So the number may legitimately move to 900 or 1800 and the checker still refuses
a missing bound, a disagreeing pair, or a pointless one. 9 passed, 0 failed.

`RotObserve` §13 — six theorems, none of which mention 1200:

| theorem | what it settles |
|---|---|
| `killed_hook_emits_nothing` | a hook past its bound emits nothing, for every bound and every work |
| `silenced_is_indistinguishable_from_absent` | that observation **equals** the no-hook observation |
| `completion_is_monotone` | raising the bound never loses an observation |
| `an_adequate_bound_is_observed` | whenever the bound covers the cost, the marker appears |
| `the_default_silenced_real_work` | the measured instance: 600 s of work is silent at 30 s, observed at 1200 s |
| `different_bounds_are_different_products` | for **any** two distinct bounds there is work they disagree on — the theorem behind the agreement phase |

Build exit 0, zero warnings; axioms `propext` (and `Classical.choice`/`Quot.sound`
for the existence proof), no `sorryAx`; `leanchecker` exit 0. `#eval` confirms
`hookOutput 30 ⟨600⟩ = none` and that it compares **equal** to `absentOutput`.
Mutants **M33–M36**, all killed, 0 survived, 0 discarded. The gate table and `RotGates.lean` both gain the new checker — 38
gates, 25 fast — and `gate-split` confirms shell and Lean still agree, 12/12.

Counts move to **516 theorems / 22 modules / 19 suites / 234 mutants / 50 checkers**.

---

## The commit gate was overwritten again — and the audit for it cannot run

**Second occurrence, measured 2026-08-06 21:41:17.** An unrelated local tool
wrote `.githooks/pre-commit` wholesale, replacing the gate with its own indexing
hook whose header states `Never blocks a commit: every failure path exits 0`.
`core.hooksPath` is `.githooks`, so the commit gate was disarmed from that moment.

Dating it is what kept the record honest: the overwrite is **21:41:17**, the last
commit is **21:32:29**, so every commit actually recorded had run the real gate.
No ungated commit exists. Restored from `HEAD` — 5819 B, 7 `gate-all` references.

`checker/workflow-lint.sh` **does** catch the substitution, measured both ways:
planted hook → exit 1 with `never calls gate-all` / `no refusing path` /
`no delegates`; real hook → exit 0, 156 passed. The detector is not the problem.

**Reachability is.** Locally that detector runs *because the pre-commit gate
invokes it* — so when the gate is what has been replaced, the detector is exactly
what stops running. An audit that reaches itself through the thing it audits is
silent in precisely the state it exists to report.

Two repairs, one of them out of band by construction:

- `.git/hooks/pre-commit` is now checked. It was inert (`core.hooksPath` points
  elsewhere) and it held the same never-blocking hook — one
  `git config --unset core.hooksPath` from a silently ungated repository. Absent
  is the safe state and passes, so a fresh clone and CI are unaffected.
- The local copy was removed; the gate at `.githooks/pre-commit` is the only
  pre-commit hook on this machine again.

`lean/Proofs/RotObserve.lean` §12 states the shape rather than the incident:

| theorem | what it settles |
|---|---|
| `gate_admits_exactly_green` | the real gate admits exactly the green trees |
| `permissive_admits_everything` | the replacement admits every tree, for all trees |
| `swap_makes_admission_uninformative` | so a red tree gets recorded — admission stops carrying information |
| `in_band_detector_is_blind_to_its_own_replacement` | the in-band audit returns the SAME verdict in both worlds; it is indistinguishable from a working audit |
| `out_of_band_detector_sees_the_replacement` | only a verifier independent of the hook separates them |
| `out_of_band_alarm_is_exact` | and it fires on exactly the bad world — no false alarm on the good one |

Build exit 0 with **zero warnings**; `out_of_band_alarm_is_exact` rests on
`propext`, the rest on nothing beyond it, no `sorryAx`; `leanchecker` exit 0, zero
bytes; delivered green to the shared workspace. Mutants **M29–M32** — all killed,
0 survived, 0 discarded.

Counts move to **510 theorems / 22 modules / 19 suites / 230 mutants**.

---

## A checksum that agrees with its archive is not provenance

**Found while publishing 0.9.x, and it was already uploaded.** `release-package.sh`
builds the archives **from the working tree** and computes `SHA256SUMS.txt` **from
those archives**, in one pass. The tree still held two uncommitted files, so the
published `rot-moe-0.9.1-lean.zip` measured **855097 B** against a tag whose tree
builds **854497 B**.

Nothing was red. The published digest matched the published archive perfectly,
because both had been regenerated together — a self-consistent pair describing a
tree that **no tag points at**. Downloading the asset and recomputing its SHA256
re-runs that same pair and cannot see the substitution. It was caught by comparing
the uploaded byte size against the size measured at package time: 598 bytes.

Repaired by stashing the two files, rebuilding on the clean tree, deleting every
published asset and re-uploading. Verified end to end afterwards: the downloaded
`v0.9.1` (854497 B) hashes to `481974a7a2dfec10…`, equal to its published
`SHA256SUMS.txt`.

`lean/Proofs/RotObserve.lean` §6 states the gap rather than the incident, so it
cannot expire when the bytes move:

| theorem | what it settles |
|---|---|
| `packaging_always_passes_integrity` | integrity holds **by construction** for whatever tree was packaged — it is a tautology about packaging, not evidence about the release |
| `integrity_cannot_detect_the_wrong_tree` | for every pair of distinct trees: the digest verifies **and** provenance is false |
| `redownload_re_runs_the_blind_check` | re-downloading and recomputing repeats the same blind check; it distinguishes nothing |
| `rebuilding_from_the_tag_restores_provenance` | the repair that was actually applied |
| `provenance_iff_same_tree` | provenance **is** tree equality — quantified over trees, so no constant can date it |

`digestOf` is only assumed deterministic. Nothing here is a hash weakness: the gap
survives a *perfect* hash, because it is a question about which tree was packaged,
not about collisions.

Build exit 0 with **zero warnings**; axioms `propext, Classical.choice, Quot.sound`
(`provenance_iff_same_tree`: `propext` alone), no `sorryAx`; `leanchecker` exit 0,
zero bytes; delivered green to the shared Lean workspace. Mutants **M12–M14**
added — every mutant then declared killed, 0 survived, 0 discarded.

Counts move to **495 theorems / 22 modules / 19 suites / 221 mutants**.

---

## An audit that silently narrows its own scope — `grep -q` under `pipefail`

CI run 31118671400's predecessor caught something the pre-commit tier could not:
`checker/mutant-discipline.sh` audited **21** harnesses on ubuntu and **23** here,
and reported PASS both times.

The cause is a shell trap this repository had already recorded in another form.
The selector was `sed 's/#.*$//' "$f" | grep -qE 'killed|survived|discard'` inside
a script running `set -o pipefail`. **`grep -q` exits at the first match**, `sed`
is then killed by SIGPIPE, and `pipefail` reports the whole pipeline as failed —
so `|| continue` skipped a file that *matched*. It is a race between `sed`
finishing and `grep` exiting, which is why it is platform-dependent: measured
`rc=0` on Git Bash here, and it dropped two suites on ubuntu.

`grep -c` consumes all of its input, so there is no SIGPIPE and no race. The count
is then tested explicitly, with `: "${_hits:=0}"` because `grep -c` prints `0`
**and** exits 1 when there is no match — the second half of the same trap.

It was caught only because the classifier repair shipped with a CONTROL asserting
every `mutate_*.sh` suite is still selected. Without it this was a green run
auditing two fewer harnesses than it claimed.

The general shape is now proved rather than described, in `RotObserve.lean` §7 —
a gate reports PASS over the items it *selected*, and selection can silently lose
items:

| theorem | what it settles |
|---|---|
| `passing_audit_can_hide_a_failure` | a passing audit does **not** mean every candidate passed |
| `the_verdict_cannot_see_the_drop` | the verdict is identical whether the dropped item would pass or fail — re-reading it can never reveal the gap |
| `control_detects_the_drop` | a control over a known-required set **does** detect it |
| `control_holds_when_nothing_is_dropped` | and that control can pass, so it is a test and not a refusal |

`#eval` reproduces the measured shape exactly: 23 required, a selector that loses
one, `auditPasses = true` over **22** judged items, `controlHolds = false`.

Mutants **M15–M17** — the control neutered to `true`, the audit made to judge
everything, and the control weakened from `all` to `any`, which is the plausible
version someone writes by accident. All three killed: every mutant then declared killed,
0 survived, 0 discarded.

---

## Twenty failed turns, exit 0 — the evidence counter incremented in the failure path

The CTT re-test after the gauge work came back green. It should not have.

```
turn 1..20: claude exit 1 (timeout or error) -- recorded, not hidden
ran 20 turn(s), 20 failed; route records written this run: 20
CTT_EXIT=0
```

**Twenty of twenty turns failed and `checker/ctt-session.sh` exited 0.** Its
refusal asked a reasonable-sounding question — *were any route records written?*
— and twenty had been. The router hook fires when the prompt is **submitted**,
before the turn reaches the API and dies. So the counter the verdict rested on
**increments in the failure path**, and a pass condition built on it is satisfied
by total failure.

This is not the §7 defect repeated. There the verdict was blind to items it never
selected; here every turn *was* selected, and the signal read cannot tell success
from failure. Both end in a green run; only one is fixed by a control over
selection.

**The cause of the failures was sitting in every payload.** The CLI writes its
reason into the JSON even when it exits non-zero, and the per-turn line threw it
away — twenty mute `exit 1`s for a diagnosis the *first* turn already had:

```
turn 1: claude exit 1 -- Failed to authenticate: OAuth session expired
                         and could not be refreshed
```

The CTT credential had gone stale (`expiresAt: 0`, a 281-byte stub against the
live 509). Refreshed by cloning the live credential into the CTT config dir —
the mechanism `marketplace-session.sh` already uses — and backed up first.

Both halves are now fixed: the reason is surfaced per turn, and a run in which
**no turn succeeded** refuses at exit 2 regardless of how many records the hook
wrote on the way down.

Measured after the repair: **20 turns, 0 failed, 32 route records, 0 trace
leaks.** Negative control, run end to end by planting the stale credential back:
exit **2**, *"every one of 1 turn(s) FAILED — 1 route record(s) were still
written"*, then restored to exit 0. The control demonstrates the exact hole: a
record was written for a turn that failed.

`RotObserve.lean` §9 states it over arbitrary runs rather than over twenty:

| theorem | what it settles |
|---|---|
| `total_failure_passes_the_side_effect_verdict` | the measured run exactly — 20 failed, 20 recorded, verdict **true** |
| `side_effect_verdict_is_blind_to_outcomes` | two runs with the same records get the same verdict **whatever** their outcomes — re-reading that log line can never reveal it |
| `success_aware_verdict_detects_total_failure` | reading outcomes does detect it, for any run |
| `success_aware_verdict_still_passes_a_real_run` | and it is a test, not a refusal — the over-correction is excluded |

`#eval` reproduces the incident: `sideEffectVerdict = true` and
`successAwareVerdict = false` on the same 20 failed-but-recorded turns, with
`recordsOf = 20`.

Mutants **M21–M23**: the repair reverted to the blind verdict, the blind verdict
taught to read outcomes, and the over-correction that refuses everything. All
killed — every mutant then declared killed, 0 survived, 0 discarded.

---

## A step that could only SKIP — the last real skip in CI is closed

Three lines in every green run, on ubuntu, macos and windows:

```
SKIPPED: no built Lean workspace -- NOT a pass
```

`gauge-cross.sh` compares the Lean `Float` mirror against the running hook, and
needs a built Lean workspace. The `checkers` job has none. The label was honest,
and the step was still a hole — **it had no reachable PASS**. A step that cannot
pass cannot fail either, so those three lines carried exactly as much information
as a blank line, in a run reported green.

**Not repaired by deleting it, and not by installing a mathlib toolchain on three
platforms.** The two arms differ in what they depend on, and that is the whole
fix:

| arm | depends on | so it runs |
|---|---|---|
| Lean mirror | the same `.olean` on every runner — **platform-independent** | once, in the `lean` job, where a skip is already a hard failure |
| running hook | `awk` in a POSIX shell, and the locale — **not** platform-independent | on all three platforms, against a recorded corpus |

New: `checker/gauge-corpus.tsv` (six rows, chosen for shapes that behave
differently) and `checker/gauge-hook-corpus.sh`, which has **no exit 3 at all**.
Measured on Windows: 9 passed, 0 failed. Negative control: a single corrupted
expectation is caught at exit 1, naming the row. A decimal comma is reported *as*
a decimal comma, because that is a failure mode this repository has already been
bitten by.

**The corpus cannot become a snapshot.** `gauge-cross.sh` now reads the same file
and re-derives every expected value from Lean, failing if they disagree:

```
FAIL  row 5: checker/gauge-corpus.tsv says 0.98 but Lean says 0.97
      -- the corpus has DRIFTED from the model; re-derive it, never hand-edit it
```

Measured in both directions: drift → exit 1, restored → exit 0. So the only way
to change a number in that file is to change the model.

`workflow-lint` then caught the next mistake immediately — *"`gauge-hook-corpus.sh`
is never run by `gate-all` — the local commit gate is WEAKER than CI"* — and it is
now registered in the fast tier. 156 passed, 0 failed.

`RotObserve.lean` §8 proves why the split is sound rather than convenient:

| theorem | what it settles |
|---|---|
| `a_step_that_only_skips_is_not_evidence` | a step whose outcome never varies distinguishes **nothing** — not a weak check, not a check |
| `agreement_with_a_corpus_says_nothing_about_the_model` | hook-matches-corpus can hold while **both** differ from the model |
| `verified_corpus_transfers_to_the_model` | re-deriving the corpus is exactly what makes the platform check transfer |
| `the_corpus_step_is_evidence` | the replacement reaches **both** outcomes, so it can fail as well as pass |

Mutants **M18–M20**: the always-skipping step given a reachable outcome, the
corpus re-derivation neutered to `true`, and the new step made unable to fail.
All killed — every mutant then declared killed, 0 survived, 0 discarded.

**One skip remains in CI, and it is a boundary, not an omission.**
`marketplace-session.sh` needs the maintainer's own Claude credentials for its
live turn. Putting those in repository secrets is a security decision that
belongs to the maintainer, and planting a fake credentials file would make the
step exit 0 while proving nothing — the precise fake green this project refuses.
It exits 3, says so, and is enforced off the runner twice: `gate-all --full`
locally, and the CTT instance before any version ships.

---

## The three numbers are not a roadmap

`0.9.0`, `0.9.1` and `0.9.2` are **released together, on the same commit**. The
version *is* the variant. Nothing in `0.9.1` supersedes `0.9.0`; it adds a
Lean 4 workshop on top of it. Nothing in `0.9.2` fixes `0.9.1`; it unseals a
tactic that `0.9.1` withholds **by policy**, and ships the instrument that keeps
that honest.

| pick | if you want |
|---|---|
| `0.9.0` Pure Router | the nine-lane router and nothing else. No Lean, no toolchain, no network. |
| `0.9.1` Router + Lean 4 | the same router **plus the machine that makes the theorems** — bounded installer, official hosts, your own proved repos. |
| `0.9.2` Router + Lean + Extra | all of the above with `native_decide` unsealed, and `checker/axiom-class.sh` to tell KERNEL from COMPILER trust. |

The patch digit **is** the tier, and it has been for every release in
[`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md): `0` core, `1` lean, `2` unsealed.
`.claude-plugin/plugin.json` carries the `.2` by convention, so a **directory- or
git-sourced** marketplace install reports `0.9.2` — it is installing the tree,
and the tree is the unsealed superset. The `.0` and `.1` tiers are what the three
`.release/` archives carve out of it, which is why
`checker/release-package.sh` builds all three from one commit and now derives
their versions from that manifest instead of a hardcoded triple.

---

## PRIOR → AFTER, at a glance

Every row was **measured on the shipped code**, before and after. This table is
the whole release in one screen; the sections beneath it give each row its
evidence.

| # | what | PRIOR (0.6.2, measured) | AFTER (0.9.x, measured) |
|---|---|---|---|
| 1 | router firings per prompt, documented install | **2** — plugin *and* `settings.json` both bind it | **1** — `ARM_ROUTER` detects the plugin and refuses |
| 2 | `DISARM_ROUTER --dry-run` | flag **ignored**; entries deleted for real | previews against a copy, writes **nothing** |
| 3 | uninstalling a plugin-path entry | **impossible** — exact match, `nothing to remove`, exit 0 | `--all` removes it; exact mode says what it cannot reach |
| 4 | unknown installer argument | silently **ignored** | **exit 2**, refused by name |
| 5 | proof scan depth | **one level** (`*.lean` in the root only) | **recursive**, both arms |
| 6 | staleness on a real subfoldered tree | **2947 min** reported | **54 min** — the truth, a 55× error removed |
| 7 | workspace chain | `env → recorded → bundled`; **nothing wrote `recorded`** | `env → recorded → **discovered** → bundled` |
| 8 | recorded path from the POSIX installer | POSIX form; PowerShell `Test-Path` **rejects it** | drive-letter form, readable by **both** arms |
| 9 | `prove this lemma` | **CONVERGENT** — no lane fired | **FORGE Claude** |
| 10 | `prove … bytes in lean` | **STEALTH** — it matched `byte` | **FORGE Claude** |
| 11 | `improve the documentation` | would hit `prove` if the stem were added | **CONVERGENT** — stems must start a word |
| 12 | `add a prefix to the name` | **CLINICAL** — `fix` fired inside "prefix" | **CONVERGENT** |
| 13 | debug log verification | sum of logged terms only, POSIX arm only | **every factor** re-derived, both arms, pairing checked |
| 14 | theorems / modules | 205 / 14 | **495 / 22** |
| 15 | gates | 29 | **35** (23 fast, 12 deep) |
| 16 | mutation suites | 10 suites | **19 suites — every mutant declared killed**, 0 survived, 0 discarded |
| 17 | why a lane fired | **not recorded** — a log could be fully replayable with the disputed fact absent | the **matched stem**, from a closed 85-word table |
| 18 | auditing someone else's log | impossible — the replayer only read logs it generated | `log-replay.sh --audit <file>` |
| 19 | "the log leaks no prompt text" | an assurance nothing checked | `auditable_imp_vocabSafe` — **entailed** by passing the audit |
| 20 | `files containing sorry` | **1**, and false: the counter matched the WORD in the router's stem table | **0**, string literals excluded, both directions controlled |

Rows 1–8 are defects that **had already reached a live machine** while
twenty-nine gates were green. Rows 9–12 are a routing fix that could not be made
until the matcher itself was specified. Row 13 is the instrument that would have
caught a drift nobody was watching for.

> **Why the PRIOR column never restates an old total.** `checker/repo-complete.sh`
> re-measures every "N applied, M killed" in this file against the suites as they
> exist **today**, and the newest section is scanned in full — a prior-versus-after
> table lives inside it. Writing the previous release's total there would put a
> correct historical number where the checker can only read it as a false present
> claim. The PRIOR cells therefore say what *changed* (ten suites became eighteen);
> the settled totals stay in
> [`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md), which is exempt as history.
> The alternative — loosening the rule so it skips table rows — would have put a
> hole in the one check that stops a mutation claim from drifting.

---

## [0.9.0] · [0.9.1] · [0.9.2] — 2026-08-06

Three archives, one tree. The patch digit is the tier: `0` core, `1` lean,
`2` unsealed.

**Every defect fixed in this release had already reached a live machine while
twenty-nine gates were green.** That is the only sentence of this entry that
matters, and it is the reason four of the additions below are gates rather than
features.

### Added — `Proofs/RotObserve.lean`: five readings that report less than the truth

Written **after** publishing, from the install of the published `0.8.2` into a
real second Claude configuration and a 20-turn session held against it. Four
times in one afternoon an observation reported less than the truth, and three of
the four invited the same wrong inference — *absence of evidence in a lossy
channel read as evidence of absence*:

| measured | the wrong inference it invited | the truth |
|---|---|---|
| `settings.json` byte-identical before and after the plugin install | "the install did nothing" | three hook events bound; the router fired 39 times |
| `validate` piped to `head` reported `rc=0` on a 4-error manifest | "the artifact is valid" | the tool exits **1**; `head` exits 0 |
| `plugin update rot-moe` → `Plugin "rot-moe" not found` | "the plugin is not installed" | installed and enabled; the *query* was unqualified |
| `marker seen in 0 transcript(s)` over 20 turns | "the hook never fired" | 39 route + 39 gauge records logged |
| `plugin update` → `already at the latest version (0.8.2)`, exit 0 | "the install carries the fix" | cache held a stale `ctt-session.sh`, `README.md`, `CHANGELOG.md`, and no `RotObserve.lean` |

**23 theorems, 11 mutants, 11 killed, 0 survived, 0 discarded.** The module states
each silence as a property of the *instrument*, so it is documented rather than
rediscovered as a panic:

- `settings_alone_cannot_decide_armed` — two installs can agree on every byte of
  `settings.json` and disagree on whether the router runs. The durable form: the
  file is not a sufficient observation of armedness.
- `guard_still_leaves_it_armed` — `ARM_ROUTER` refusing to write is not failing
  to work. After the guard runs the router is armed on **every** branch, which is
  why the refusal against an already-plugged host is correct.
- `green_filter_masks_every_failure` — quantified over the exit code, not stated
  about the `1` that was measured: **no** status survives a filter that always
  succeeds. `piped_reading_is_blind` follows — the reading cannot tell success
  from any failure.
- `bare_name_never_resolves` — a length argument over arbitrary names, so it
  holds for every plugin rather than for the one that was typed; and
  `lookup_failure_is_not_absence` closes the inference.
- `any_number_of_firings_can_be_invisible` — for **every** `n` there is a run
  with `n` firings and zero markers. 39-and-0 was not a coincidence; it is the
  only thing the internal-only seal permits. `markers_zero_iff_all_sealed` gives
  the checker's note its actual meaning: it reports the **seal**, not the router.

- `force_update_at_same_version_reaches_no_install` — **this one changes how a
  release is shipped.** Measured after force-updating the tree without moving the
  version: `claude plugin update rot-moe@rot-moe` answered *"already at the
  latest version (0.8.2)"* at **exit 0**, while the installed cache still held
  the old `checker/ctt-session.sh`, an old `README.md`, an old `CHANGELOG.md` and
  no `RotObserve.lean` at all. Nothing was broken — the updater compares the
  version **string**, and the string had not moved. The theorem is quantified
  over every version and every pair of differing contents, so it is a statement
  about the mechanism rather than about the tag that was measured.
  `only_a_moved_version_is_visible` gives the repair; `fresh_install_is_always_current`
  and `reinstall_succeeds_where_update_is_blind` record the path that *does*
  deliver — uninstall + install refreshed every stale file under the same `0.8.2`.

`blind_reading_cannot_decide` is labelled in-file as a **repackaging, not a
discovery** — `#print axioms` reports it depends on nothing, the signature of a
near-tautology, and its worth is entirely in the instances.

> **Operational consequence, stated because it is not obvious.** A force-updated
> tag at an unchanged version reaches **new** installs only. Anyone who already
> has the plugin will be told they are current and will receive nothing. That is
> not a defect in this project and not one in the CLI; it is what version-string
> comparison means. The honest options are a version bump or an explicit
> reinstall, and the theorem now says which is which.

Verified with all three instruments in both trees: `lake build` exit 0 with zero
warnings, 18 × `#print axioms` showing no `sorryAx`, `leanchecker` exit 0 with
zero bytes (control: a module with no oleans exits 1).

### Verified — the published `0.8.1` archive, installed and driven through the real CLI

Not the local `.release/` build: the asset was **downloaded from the release**
and its SHA256 compared against the published `SHA256SUMS.txt` —
`459246a47d3ebebe3254c9f3ab828c8a0d24efa7288286e648919890445662a2`, identical.
The bytes users get are the bytes that were built.

- `claude plugin validate` on the downloaded tree: **exit 0**, zero errors.
  Controls: a mangled manifest key → exit 1 with 4 errors, invalid JSON → exit 1.
  The validator can fail, which is the only reason its pass counts.
- `claude plugin update rot-moe@rot-moe` moved the test configuration
  **0.7.2 → 0.8.2** at exit 0; the installed cache's `rot-router.sh` and
  `hooks.json` are **byte-identical** to the tree.
- A **20-turn session** against the installed plugin: 39 route records and 39
  gauge records, every one `K=9` with nine lens terms, R/s+ recomputed from those
  terms on **all 39** to within 2e-5, and **8 distinct lanes** reached in real
  conversation. `checker/ctt-session.sh --report`: 4 passed, 0 failed.

### Fixed — a `paths:` filter does not restrain a tag push, and the run it wasted concluded `cancelled`

Found **while publishing this release**, by auditing the runs the tag pushes
themselves triggered — which is the audit everyone skips, because the release is
already out by then.

`.github/workflows/tag-manager.yml` declared a push trigger filtered to
`.github/tags.txt` and **no `branches:`**. Pushing `v0.8.0`, `v0.8.1` and
`v0.8.2` in one command fired **three** runs of it, on a commit that does not
touch that file at all:

```
git show --stat --name-only 4a783a9 | grep -c "tags.txt"   ->  0
```

A path filter cannot be evaluated for a tag ref — there is no base to diff
against — so it restrains nothing. Only `branches:` excludes tags.

**The wasted runs were not the damage; the conclusion was.** That workflow holds
a single concurrency group with `cancel-in-progress: false`, and GitHub keeps at
most **one** pending run per group. The first ran, the second pended, and the
third's arrival **cancelled the second**. Tag `v0.8.1` therefore carried a run
concluding `cancelled` with `total_count: 0` — zero jobs ever dispatched.

`cancelled` is exactly what `checker/ci-honesty.sh:186-190` refuses. And tag
`v0.7.0` carries the same scar, which is how one structural defect passed for
bad luck twice.

**Why a cancelled run is uniquely dangerous, stated precisely:** it has *zero
failing steps*. Every step-level rule is **vacuously satisfied** by a run that
never started. Only the run-level check can see it — which is why the run
conclusion is checked separately from the steps, and why that separation is now
a theorem rather than a convention.

| layer | what it does |
|---|---|
| `tag-manager.yml` | `branches: [main]` added, with the measurement recorded in place |
| `checker/workflow-lint.sh` **R23** | every `push:` trigger carrying `paths:` must also constrain `branches:` — with **two** controls: the defective shape is detected, and a correct trigger is *not* flagged |
| `lean/Proofs/RotGates.lean` | six theorems, below |

| theorem | claim |
|---|---|
| `paths_do_not_restrain_a_tag` | a branch-less trigger fires on **every** tag, for **every** path list — quantified, so no path list can save it |
| `branches_exclude_every_tag` | any **non-empty** `branches` excludes every tag — the fix stated generally, not as "`[main]` works" |
| `the_fix_keeps_main` | the repair does not silence the intended trigger — a fix that muted the branch runs too would be a regression wearing a fix's clothes |
| `runConcludedHonestly` + `cancelled_is_not_honest` | only the literal `success` is green |
| `only_success_is_honest` | quantified over **any** string: nothing else passes, including conclusions GitHub has not invented yet |
| `empty_run_is_vacuously_step_clean` | `runIsHonest [] = true` — the vacuity spelled out, so nobody mistakes an all-green step list for evidence |

Three mutants (M11 / M12 / M13) → **13/13 killed** in that suite. M12 is the one
that matters: it widens the whitelist to admit `cancelled`, which is precisely
the "repair" someone reaches for when a cancelled run blocks a release.
`only_success_is_honest` makes that impossible to land quietly.

> **A harness note worth keeping.** All three mutants were `DISCARDED` on their
> first run with `needle=1 repl=1`, because each replacement *extended* its
> needle (`X` → `X || Y`) and the post-check requires the needle to be **absent**
> afterwards. That is the harness being right: an edit whose before-text is still
> in the file is not a clean mutation, and a suite that scored those as
> `SURVIVED` would have reported three robust theorems while testing nothing.

### Verified — the CTT round-trip, and four theorems confirmed against a live install

Before this release was tagged, the packaged `0.9.1` Lean variant was installed
into a **separate Claude Code instance** kept for pre-publish testing — a full
clone with its own `.claude` directory, credentials and plugin cache — and driven
end to end. (The absolute path is deliberately not printed here: `no machine-local
paths` refused this paragraph when it named one, which is the gate behaving
correctly.) Measured, in order:

| step | result |
|---|---|
| `ARM_ROUTER.sh` against the CTT instance | **refused** — the plugin already registers the router; arming again would fire it twice per prompt |
| `ARM_ROUTER.sh` against a clean scratch `HOME` | 124 B → 1515 B; **5 bindings across 3 events** (2 / 2 / 1) |
| every pre-existing scalar (`effortLevel`, `skipDangerousModePermissionPrompt`, `permissions.defaultMode`) | preserved byte for byte |
| second `ARM_ROUTER.sh` | settings hash **identical** — idempotent |
| `DISARM_ROUTER.sh` | `hooks` key gone entirely, **zero residue**, scalars unchanged |

Those four rows are the empirical counterpart of `arm_adds_the_hooks`,
`arm_preserves_all_scalars`, `arm_idempotent`, `disarm_removes` and
`disarm_preserves_all_scalars` in `lean/Proofs/RotInstall.lean` — and the 2 / 2 / 1
counts are exactly the `example`s converted from `#guard` in this release.

The router was then run **from the CTT plugin cache**, under CTT's own `HOME`:

| prompt | lane | `R/s+` | Lean `#guard` |
|---|---|---|---|
| `prove this lemma in lean` | FORGE Claude | 0.66 | `routerReading 8 == 0.66427` |
| `fix the failing test` | CLINICAL AntiVenom | 0.57 | `routerReading 2 == 0.57318` |
| `how do I feel about this` | EMPATHIC Violet | 0.31 | `routerReading 1 == 0.31386` |
| `compress the output` | STEALTH Soleil | 0.39 | `routerReading 6 == 0.38607` |

Every one agrees with the spec at the two decimals the route record carries.
This is the binding that makes `RotEnsemble.lean` a specification of the shipped
router rather than a self-consistent model: the numbers were re-measured through
an actual plugin installation, not recomputed in Lean.

**Stated as a limit:** the CTT plugin cache is a snapshot taken at `bc1272d`.
`hooks/rot-router.sh` and `hooks/hooks.json` in it are **byte-identical** to the
current tree, so the routing evidence above is evidence about today's code; only
`.claude-plugin/plugin.json` differs, and only in the theorem-count metadata.

### Fixed — a warning inside a green log: git CRLF advisory ×4

`checker/verdict-schedule-sim.sh` builds scratch git trees. On a Windows runner
git printed, four times into a fully passing log:

    warning: in the working copy of 'STATUS.md', LF will be replaced by CRLF

Every check in that step passed, so nothing was broken — which is precisely why
it is worth removing. A green log that contains warnings teaches everyone reading
it to skim past warnings. The scratch trees now set `core.autocrlf false`; the
simulator's subject is the scheduling rule, not line endings, and the real
repository is untouched. Re-measured on Windows: **10 passed, 0 failed, 0
warnings**.

### Fixed — 70 build warnings that no gate was reading, and one understated theorem

`lake build` exited 0 on every platform and **printed 70 warnings**, in a job
whose conclusion was `success`. Nothing failed, so nothing looked wrong. Measured
from the run archive and reproduced locally at the identical count — 60 in
`RotEnsemble.lean`, 10 in `RotInstall.lean`.

**One of them was a real weakness in a theorem, not a style complaint.**
`activity_vector_determined_by_eight` took eight hypotheses and its proof used
**two**. The linter said six binders were never referenced; the honest reading is
that the theorem was *understated*, because Claude's activity is fixed by
AntiVenom and Soleil alone. Renaming the binders to `_h1 …` would have silenced
the warning and preserved the weaker claim, so instead:

* `activity_vector_determined_by_two` — the strong statement,
* `activity_vector_determined_by_eight` — kept for anyone searching for it, now
  **derived** from the two-hypothesis version so the file cannot drift back,
* `six_lenses_may_differ_and_claude_still_agrees` — an explicit pair of signal
  states differing on all six free lenses while Claude is forced to agree, so the
  gap is exhibited rather than asserted.

Two further over-assumptions came from the same sweep: `bump_at` and `bump_ne`
were dragging in `[Fintype ι]` they never used (now `omit`ted — they hold for
infinite index types), and `quiet_entropy_is_zero_at_any_breadth` carried a
`[Fintype ι]` that `allQuiet = fun _ => false` never needed.

The remaining 46 were `mathlibStandardSet` objecting to `#`-commands. Handled in
**two different ways, because the right fix differs**:

* `RotInstall.lean` — nine `#guard`s became `example … := by decide`. Strictly
  better: same computation, but each leaves a proof term for `leanchecker`. This
  is the conversion `RotDorks.lean` already made.
* `RotEnsemble.lean` — that conversion is **impossible** there. The values are
  `Float` and the kernel cannot reduce them; `decide` fails with
  `instDecidableEqBool (routerReading 0 == 0.47142) true did not reduce to
  isTrue or isFalse`. `#guard` in the interpreter is the only instrument, so the
  linter is disabled *in that file* with the measurement quoted in place — and
  with a negative control proving the guards still bite: flipping `0.47142` to
  `0.47143` fails the build.

Result: `lake build` **exit 0, zero warnings, zero errors** across all 21
modules; `leanchecker` re-verifies both changed modules at exit 0 / 0 bytes.
495 theorems.

### Fixed — a green CI leg that asserted nothing, from one missing `else`

The repair to the Windows `tty guard` shipped with a defect **in the repair
itself**, and run `31052104953` caught it: 145 success, **0 skipped**, 2 failure.

An edit removed the `else` keyword from the step's `if / elif / else` allocator
chain. The result is still **valid shell**, so `checker/workflow-lint.sh` passed
it 144/144. What actually happened on the runners:

| leg | behaviour | reported |
|---|---|---|
| ubuntu | GNU `script` branch ran, real pty | PASS, honestly |
| windows | **neither branch ran** — `rc` was the exit of the failed `elif` *test* (0), `tty.out` never created | FAIL, `cat: tty.out: No such file or directory` |
| macos | the fallback body had been absorbed into the BSD branch, so it ran **after** the pty probe and **overwrote its result** | **PASS — while asserting nothing about a terminal** |

The Windows failure was loud and cost nothing. **The macOS pass is the serious
one**: a leg reporting success having tested nothing is a fake green, and it is
the same defect as a skipped step wearing a different hat.

Three layers now stop it, because the text layer demonstrably cannot:

1. **`ci.yml`** — each branch sets `ALLOC` and the step refuses when no branch
   named itself (`FAIL: no pty-allocator branch ran -- the dispatch is not
   exhaustive. Nothing was asserted. This is a skipped check, not a pass.`) or
   when the named branch produced no `tty.out`.
2. **`checker/workflow-lint.sh` R22** — asserts those guards exist, with a
   control that removes the refusal from a copy and requires the rule to fire.
3. **`lean/Proofs/RotGates.lean`** — `unselected_asserts_nothing`,
   `selected_without_artifact_asserts_nothing`, `guard_is_exactly_assertion`
   (the guard is *equivalent* to "this dispatch is evidence" — neither stricter
   nor laxer), and `unselected_dispatch_is_as_green_as_a_skip`, which binds the
   new law to the existing one: a leg that selected no branch is worth exactly
   what `isGreen skipped` is worth.

Stated as a limit rather than glossed: the Lean law catches *"no branch ran"*.
It does **not** catch *"the wrong branch ran last"*, which is what happened on
macOS — that is caught by R22 requiring one `ALLOC` per branch, and the module
says so in a comment beside the macOS `#guard`.

Mutants M09/M10 (**221 applied, 221 killed**). M10 exists because the two
conjuncts of `dispatchAsserted` were each violated on a *different* platform in
the same run, so dropping either would let one leg back through.

Also fixed while in the file: two `grep -c … || printf 0` sites in
`workflow-lint.sh` produced **two** zeros on no match (`grep -c` prints `0` *and*
exits 1), making `[ -eq ]` fail with `integer expression expected`. Identical to
a defect already recorded in `checker/ci-honesty.sh`.

### Fixed — our own recovery advice destroyed two shipped hooks

`checker/gate-all.sh` refuses to run when a mutation suite left `.mutbak` files
behind, because the tree may carry a live mutant. That refusal is correct and it
fired exactly as designed after a commit was killed by a wall-clock ceiling
mid-suite. **Its recovery instruction was the defect.** It said:

> Restore each file from its backup (`cp <f>.mutbak <f>`), delete the backups.

Followed literally, that left `hooks/prover-remind.sh` and
`hooks/prover-remind.ps1` at **zero bytes** — `sha256 e3b0c442…` is the empty
string — with the backups deleted in the same breath. Three gates went red with
every measurement returning `''`. Recovered from git (29107 and 23611 bytes).

The mistake is structural, not clumsiness: **"a backup exists" and "a backup can
restore" are different propositions.** `find` answers the first. A suite killed
between *creating* `<f>.mutbak` and *writing content into it* leaves a file that
satisfies the first and fails the second, and `cp` from an empty source
**destroys the target and exits 0** — a destructive operation reporting success,
which is the same shape as a fake green.

The preflight now **sizes every backup**, marks any empty one
`*** EMPTY -- copying THIS would ERASE the file ***`, and leads with
`git checkout HEAD -- <file>` — a recovery path that cannot be truncated by the
kill being recovered from.

Two related **false reds** from the same kill, both cleared by rebuilding rather
than by "fixing" anything: `leanchecker` reported `Proofs.RotMutant` as KERNEL
REJECTED because the suite had deleted its `.olean`, and a missing artifact is
indistinguishable from a kernel failure at the exit code. A red must be
attributed before it is believed.

`lean/Proofs/RotMutant.lean` grows 17 → **23 theorems**:

| theorem | content |
|---|---|
| `existence_is_not_restorability` | the two predicates come apart on the empty backup |
| `empty_backup_restore_is_destructive` | `cp` from a 0-byte source erases any non-empty file |
| `copy_is_safe_iff_backup_nonempty` | the size test is precisely the side condition, not belt-and-braces |
| `git_restore_ignores_the_backup` | the git path does not read the artifact the kill produced |
| `git_restore_is_total` | safe for every file and every backup, given a non-empty commit |
| `git_strictly_safer_on_the_measured_state` | a state exists where git is safe and `cp` is not — so the change is not cosmetic |

Mutants M11–M13 (**221 applied, 221 killed**, was 190). M13 exists specifically
because `git_restore_ignores_the_backup` is proved by `rfl` and depends on **no
axioms** — the vacuity smell — so it had to be shown load-bearing against a
`restoreFromGit` that reads the backup, or labelled decoration. It dies.

Recorded because it cost two DISCARDED results first: **a multi-line `grep -F -c`
needle counts matching lines, not occurrences**, and M13's first form came back
`needle occurs 2 times (expected 1) -- patch not applied`. The harness reported
DISCARDED and refused a verdict rather than scoring it SURVIVED, which is the
`RotMutant` law protecting its own suite.

### Fixed — the CI honesty law was strict in one direction and blind in the other

Run `31045719329` measured the no-skip repair and it **held: zero skipped
steps**, down from the eight that run `31035932155` carried while GitHub called
it `success`. Two defects surfaced in the same audit, and both were ours.

- **The Windows `tty guard` asserted something false.** Git Bash has no
  `script`, so the Windows leg fed the router `/dev/null` and required a
  non-zero exit, calling that "the same contract". It is not: empty stdin is not
  a terminal, and the router correctly exits 0 on it (measured — exit 0, zero
  bytes). The check failed loudly on a correct implementation, which is a defect
  in the check.

  `winpty` ships with Git Bash and was tried first; it needs a real console and
  dies on a runner with
  `ASSERT_CONDITION("wp != nullptr && cols > 0 && rows > 0")`. **A pty on that
  leg is impossible, not merely awkward.** The leg now asserts the property that
  *is* true there — on empty stdin the router must terminate, must not hang, and
  must emit nothing — and the log says on that leg that it is narrower than the
  pty probe. The pty refusal itself is still asserted on the Linux and macOS
  legs of the same matrix. **Nothing skips; the step concludes `success` on all
  three platforms.**

- **`checker/ci-honesty.sh` exempted runner scaffolding from *both* rules.**
  GitHub decides whether to run its own `Post <action>` cleanup, so exempting it
  from the **skip** rule is right. Exempting it from the **failure** rule meant a
  scaffolding step could conclude `failure` and the run would still be scored
  honest — a fake green built into the anti-fake-green checker. The exemption is
  now asymmetric: consulted for `skipped`, never for anything else.

  *Correction on the record:* the first write-up of this defect claimed the run
  actually had two failing `Post Run actions/checkout@v7` steps. It did not.
  That came from parsing the jobs list with `paste - -`, which pairs lines
  offset by one and glued a job-level conclusion onto a step name. Re-measured
  against the API: **zero** Post steps failed. The hole was read out of the
  code, not observed firing, and both `RotGates.lean` and the checker now say so
  rather than carrying the tidier false story.

### Added — the asymmetry, proved

`lean/Proofs/RotGates.lean` grows from 24 to **30 theorems**. `runIsHonest` is
no longer `allGreen`; it is `List.all stepIsAcceptable`, which branches on the
outcome and consults `Step.isScaffolding` in the `skipped` arm **only**.

| theorem | what it forbids |
|---|---|
| `scaffolding_failure_is_still_dishonest` | a `Post <anything>` step that fails, for every name |
| `post_checkout_failure_is_dishonest` | the concrete pair the old checker would have passed |
| `scaffolding_skip_is_tolerated` | the exemption being unreachable, which would collapse the two rules into one |
| `scaffolding_matters_only_for_skips` | the exemption ever affecting a non-skipped outcome — it cannot leak |
| `honest_run_has_no_failure` | any failure anywhere, with no hypothesis |
| `honest_run_authored_step_is_green` | an authored step concluding anything but `success` |

`any_skip_is_dishonest` → `any_authored_skip_is_dishonest` and
`no_skip_is_implied` → `no_authored_skip_is_implied`. **Both gained a
hypothesis, and that is a real narrowing, so it is stated plainly rather than
buried:** the old versions quantified over every name and so declared a skipped
`Post Run actions/checkout` dishonest too. That was stricter than reality —
GitHub skips its own cleanup as normal operation — and a law that calls normal
operation dishonest is a law someone later deletes. The authored case, which is
the case the rule exists for, admits no exemption and is unchanged.

Three mutants added to `lean/mutate/mutate_rotgates.sh` (**221 applied, 221
killed** repo-wide, was 187):

- **M06** re-opens the hole — the failure arm consults `isScaffolding`. Killed
  nine theorems including both new failure theorems.
- **M07** tolerates every skip. Killed the authored-skip theorems and the
  `31035932155` witness.
- **M08** widens the predicate to `"".isPrefixOf`, making every step
  scaffolding. Killed the run witnesses — the narrowness of the predicate is the
  only thing keeping the skip exemption honest.

`ci-honesty.sh` gains two negative controls asserting the asymmetry in both
directions: a failing scaffolding step must be caught, a skipped one must not.

### Added — the Easter Egg section in `README.md`

Documents where the RoT formulae came from, and proves it rather than asserting
it. Backed by `RotEigenform.lean`: **113 theorems, 0 `sorry`, 0 warnings,
`leanchecker` exit 0 with zero bytes, 41 of 41 mutants killed**, plus a corpus
checker that re-derives every stated number from **498 real SINE presets**
(SHA-256 pinned; negative control fails with 7 `FAIL`s when one file is removed).

What it establishes, in one line each:

- **The Ultimate Equation is a diff.** The original is the Book of Fairy quote at
  `mathematics.md:105`; Saimonokuma's version adds four insertions, and each one
  names a component that is now a theorem — the weights/quantization pair, the
  goal, the sound equation, and the question mark.
- **SINE's `lerpWithPow` and one term of `R/s+` are the same operator.**
  `blend_mem` is proved once and bounds both a 2014 GPL entrainer and this
  router. Same operator, different index set — beats indexed by time, the
  ensemble by lens.
- **The ✨ Nova-Violet Role Merging Law**, over ℚ: commutative, gains exactly ⅕
  over the mean, strictly exceeds both parents in entropy, and inherits μ without
  gain. Nova × Violet = λ 1.65, μ 1.00, H 0.50. Reported honestly: the law is
  **not idempotent** — `merge a a` still gains.
- **`R/s+` is dynamic, and cannot be constant.** Stated as monotonicity in the
  inputs rather than as "0.66 ≠ 0.57", so retuning every weight leaves it true.
- **🜏 EIGENFORM — the keystone.** `σ(½) = ½`: the quantizer has a fixed point,
  and `eigenform_survives_infinite_recursion` proves `σ^[n](½) = ½` for every
  `n`. **Three independent objects land on the same number** — the router's
  fixed point, the Nova-Violet merged entropy, and the floor of SINE's frequency
  table. `eigenform_binds_router_law_and_corpus` states it over `sigma`, `merge`
  and `sineTable` so retuning any one falsifies it; mutants **E32** and **E39**
  both kill it. Uniqueness is **not** claimed — the "strictly monotone hence
  unique" argument is false, and it was caught by elaboration after being
  written.
- **The gauge CONVERGES.** `sigma_tendsto_one_atTop` and
  `sigma_tendsto_zero_atBot` are limit theorems in `Filter`/`Topology`;
  `gauge_term_bounded` bounds one lens below `2·λ·μ·M·C·T`; `ensemble_is_bounded`
  bounds the finite sum. Infinite in input, convergent in output, finite in
  outcome — which is the answer to the butterfly, not a caveat about it.
- **Four verdicts, not two** — the `PROVED`/`REFUTED`/`MEASURED`/`OUT OF SCOPE`
  map is the *catuṣkoṭi* of `PART 5:244`, and a two-valued map would have to file
  `MEASURED` under `PROVED`.
- **"Infinite" means finite-but-inexhaustible in all three corpora** — the
  Egyptian numeral glossed *"Infinite/large number"* is 10⁷, Borges' Library is
  25¹³¹²⁰⁰⁰, and `Lane` has nine inhabitants. `realities_must_collapse` proves
  the compression is forced.

Four defects are recorded in the section itself rather than quietly repaired,
including one found *while writing it*: a theorem named
*quantization-without-weights-is-flat* (written here without backticks because
it no longer exists) that elaborated to `rfl` and asserted nothing. It is now
`weights_are_what_discriminate` and proves the real
dichotomy. A green theorem named for a true property is still worth nothing if
it does not state it.

### The router fired TWICE on every prompt, and the install document caused it

Measured on the author's machine: two marker lines, two gauge computations,
twice the tokens, every turn. The packet reaches a session by two routes and
they are **additive** — the plugin's `hooks/hooks.json` binds the router on
`UserPromptSubmit` and `PreToolUse`, and `ARM_ROUTER` writes an absolute-path
entry for **the same script** on **the same two events** into `settings.json`.
`CLAUDE.md` told the installing agent to do both.

Nothing about that state looks wrong from inside. The lane is right and the
gauge is right; they are right twice.

- `hooks/plugin-detect.js` — new. Exits `0` when a live plugin registration of
  the router exists, `10` when none does. It keys on the **fact** (an enabled
  plugin whose `hooks.json` binds `rot-router.*`), never on the directory being
  called `rot-moe`, because a marketplace can rename it.
- `ARM_ROUTER` (both arms) refuses when that detector fires, prints what it
  found, and exits `0` — **refusing is a success**: the user asked for the
  router to be armed and it already is. `--force` / `-Force` overrides.
- Both arms now **refuse an unknown argument** with exit 2 instead of ignoring
  it. An ignored flag is how the next item happened.

### `DISARM_ROUTER --dry-run` was accepted, ignored, and deleted live entries

Counted: `grep -cE '\-\-dry-run|DRY'` gave **15** in `ARM_ROUTER.sh` and **0** in
`DISARM_ROUTER.sh`. The destructive half of the pair was the half with no safety
flag, and an unknown argument was a no-op, so `--dry-run` read as *proceed*.

- `--dry-run` / `-DryRun` in both arms. The preview runs the **real** removal
  against a copy and discards it, so preview and act cannot disagree.
- `--all` / `-All` (`disarm-any` in the merge engine) removes every RoT MoE
  router entry whatever path it names. The old exact matcher could not touch an
  entry pointing at the plugin cache — which is what the documented install
  produces — and reported `nothing to remove`, exit 0, forever.
- Exact mode remains the default and now **says so** when it can see entries it
  cannot match, instead of reporting a false all-clear.

### The proof scan was one level deep — in both arms

`"$PROOFS_DIR"/*.lean` and `Get-ChildItem -Filter '*.lean'` with no `-Recurse`.
File proofs by subject and the newest file either arm can see is whatever last
landed in the root. Measured on a real tree at one instant: **2947 minutes stale
one level deep, 54 minutes recursive** — a 55x error, while eighteen modules
were being written into a subfolder.

### The workspace chain had a step nothing wrote

`env → RECORDED → bundled corpus` reads like three answers. Only `SETUP_LEAN`
ever writes RECORDED, so for a marketplace install the middle step is
permanently empty and every measurement pointed at the plugin's own read-only
corpus, which can never acquire debt.

- A fourth step, `discovered`, walks up from the session's directory for a Lake
  workspace with proofs. Added to **both** arms — the first attempt at this fix
  added it to the POSIX arm only, which would have given Windows and Linux users
  different answers with no gate able to see it.
- `SETUP_LEAN.sh` now records the workspace in the **drive-letter form**, the
  only spelling both arms can test (measured: Git Bash accepts `[ -d "D:/tmp" ]`
  and so does `Test-Path`). The PowerShell reminder gained a fallback for the
  legacy POSIX-form paths already on disk, so an upgrade does not silently break
  the machines that were already set up.

### The measurement half had no instrument, so defects lived there

`cross-diff-remind.sh` compares the two arms' **decision**; its own header says
what it does not cover is "that both arms measure the same things off disk".
Both defects above lived in exactly that gap.

- `prover-remind` (both arms) gained `--measure` (count, minutes, name) and
  `--workspace` (which step of the chain answered, and what it returned).
- The PowerShell arm's scan is now **one function** shared by hook mode and
  `-Measure`, so the thing the gate drives is the thing the hook runs.

### Four new gates, all fast tier

| gate | what it makes impossible |
|---|---|
| `router-duplication.sh` | arming on top of a live plugin registration |
| `disarm-safety.sh` | a dry run that writes; an `--all` that takes a neighbour |
| `remind-measure.sh` | the two arms measuring different trees |
| `log-replay.sh` | a debug record whose numbers do not re-derive |

Fast tier is a decision, not a default: the double-fire was introduced by an
**install document**, which stages no path a deep trigger would have matched.

### The debug log is now re-derived, not merely summed

`bench-router.sh` already summed the logged `term` values and checked
`Σterm / K = Rs`. What it cannot see is everything upstream of `term`: a record
with the wrong `mu`, `sigma`, `H` or `mean` is consistent at the level of sums
and passes. `log-replay.sh` recomputes **every factor** from `lambda`, `mu`, `a`
and `breadth`, checks gauge/route pairing, checks the route line's displayed
value is a faithful rounding of the gauge line's, and replays the **PowerShell**
arm's log as well — then requires the two arms' gauge records to be
byte-identical. Measured: they are.

### A spec that was wrong, said plainly

`RotLog.WellPaired` first asserted that a route record carries the **same** `Rs`
as its gauge record. The shipped router does not do that: the gauge line carries
`0.66427` and the route line carries the displayed `0.66`, matching the marker
the operator sees. Twelve records from each arm recomputed field for field with
zero error, and the only disagreement was a rounding the spec had forbidden.

**The spec was wrong, not the code.** It now carries a tolerance parameter, with
`displayEps = 1/200` — the exact half-ulp of a two-decimal display, so an honest
rounding passes and a stale or edited number still cannot. `RotScan` had the
same class of defect in miniature: a hypothesis that Lean's linter proved was
never used, on a theorem whose doc comment claimed more than it stated. Both
were found by instruments, not by reading.

### `prove this lemma` did not reach FORGE — and could not be made to

Measured on the shipped router before the change:

```
prove this lemma                            -> CONVERGENT     (nothing fired)
prove the read loop conserves bytes in lean -> STEALTH Soleil (it matched `byte`)
```

On a prover head, the two most proof-shaped prompts imaginable reached every
lane except the one for proving. **The earlier diagnosis that first-match beat
priority was wrong** — `route()` has always tried FORGE first. The stem table
simply did not contain `prove`, `proof` or `lemma`.

They could not be added, either. `fired` was a plain substring test, so `prove`
would have fired on **improve**, `lemma` on **dilemma**, `lean` on **cleaning**.
The same flaw was already live and routing prompts wrongly: `fix` fires on
**prefix**, `now` on **known**, `test` on **latest**.

**A stem must now start a word** — the beginning of the text, or straight after a
non-alphanumeric character. `proofs` and `prover` still fire, because a stem is a
word *prefix*; that is what `verif` → "verification" and `strateg` → "strategy"
have always relied on.

Not `proving`, and the first draft of this entry claimed otherwise. `prove` is
not a prefix of "proving" — the two diverge at the fifth character — so it fired
under **neither** matcher. The executable example at `RotStem.lean:386` pins
that, and is how the error was caught: the prose and the spec disagreed, and the
spec was right. A stem that itself begins with punctuation
falls back to a substring test, which is what keeps `.lean` matching
`Basic.lean`.

`RotStem.lean` now specifies the matcher, which had never been modelled — the
existing theorems were about *which class fired*, never about *how a class
decides*. `firesWord_imp_fires` is what made the change safe to ship: word-prefix
firing implies substring firing, for every prompt and every class, so the new
rule can only remove a false positive and can never move a prompt onto a lane it
was not already reaching. `firesWord_strictly_weaker` proves that guarantee is
not vacuous.

FORGE gained `prove proof lemma lean qed`. The cross-diff corpus gained 12 rows
covering both directions — the prompts that must now fire and the near-misses
that must not. Reverting the matcher to a substring test turns **12 of them
red**, measured.

### The install section told three tiers to download archives that do not exist

`README.md` said `rot-moe-0.5.1-lean.zip` while `checker/release-package.sh`
built `rot-moe-0.9.1-lean.zip`. Three links, all wrong, **for two minor
versions, with every gate green** — nothing in the repository had ever compared
the names. The release map moved from a hand-written line to a computed one and
the prose quoting it did not follow.

That is not a wrong number in a table. It is the **first instruction a new
reader follows**, and it fails with a 404 that reads as an abandoned project.

- The install section was rewritten. It had four methods in an order that buried
  the one that works: `ARM_ROUTER --dry-run` first (the path that edits your
  `settings.json`), then `--plugin-dir`, then a heading marked "start here"
  arriving third. Now one ordered page — `/plugin install`, the three tiers,
  `--plugin-dir` from a clone, then `ARM_ROUTER` marked as the advanced path.
- Tiers are named **Router · Router + Lean · Router + Lean + Extra**, and each
  row says what the archive actually contains, read from the packager's own
  `CORE_PATHS` / `LEAN_EXTRA` / `UNSEALED_EXTRA` rather than described from
  memory. Measured: core 37 files with no `lean/` and no `checker/`; lean 137;
  unsealed 138 — lean plus `UNSEALED.md` exactly.
- The three transcript lines were **re-measured**: each archive rebuilt,
  unzipped, and its own `rot-router.sh` run on the same payload.
- `checker/readme-variants.sh` is new and prevents recurrence. It asks the
  packager for its map (`--print-variants`, never by grepping its source) and
  checks **both** directions across `README.md`, `RELEASE.md` and `docs/*.md`.
  Requiring the right names to be present does not remove the wrong ones, and
  this README had correct prose and dead links in the same section. Registered
  **fast tier**: a deep gate would let this ship again on any commit that did
  not touch the release paths, and a README edit is exactly such a commit.

### `SHA256SUMS.txt` was promised by the README and never written by anything

`grep -c sha256 checker/release-package.sh` returned **zero** while `README.md`
said every archive verifies against the sums file published beside it. A
documented verification step with no artifact behind it is worse than none: the
reader who tries it finds nothing and cannot tell an unpublished checksum from a
tampered download.

The packager now emits it, last, after every other assertion has passed — so
sums can never exist for an artifact it refused to bless — and **refuses** if no
`sha256sum`/`shasum` is on PATH rather than shipping archives with no checksums
while the docs claim otherwise. Control: appending one byte to an archive makes
`-c` fail; restoring makes it verify.

Two self-inflicted faults were found writing it, both of the kind that fake a
pass. The well-formedness pattern rejected all three good lines because GNU
`sha256sum` writes `<hash> *<name>` in binary mode — the check was wrong, not
the output. And the tamper control extracted the filename with
`awk '{print $2}'`, which yields `*rot-moe-0.9.0-core.zip` **with** the star, so
every `cp`/`mv` would have addressed a file that does not exist and the control
would have "passed" while touching nothing.

### The tag rule was a blanket where the hazard has a boundary

`docs/GIT-WORKFLOW.md` §4.3 said *"never force-push, never rewrite published
history — tags are consumed by the marketplace."* The first half is right and
unconditional. The second half is not what this project's marketplace does, and
the difference is not pedantic: it decides whether a re-tag is routine or
destructive.

Measured, not recalled. `.claude-plugin/marketplace.json` declares
`"source": "./"`, and a marketplace install resolves the **default branch**; a
directory install records `"source": "directory"` and a path — verified in the
CTT config. **Neither reads a tag.** What *is* pinned to a tag is a published
GitHub Release: its source archive and its assets, `SHA256SUMS.txt` included.

So the rule now has a boundary. A tag with **no Release attached** may move, and
that is the last moment it is free; a tag with a Release published on it **never**
moves, because people have the checksums. A blanket in the wrong place is not
caution — it forbade re-tagging onto a commit whose CI is actually green, which
is precisely the operation this release needed.

§4.4 is new: the dispatch procedure, written from measurement rather than
rediscovered each time. There is **no release-publishing workflow** — the four
are `ads-manager`, `ci`, `tag-manager`, `verify`, and `tag-manager` only
refreshes notes on releases that already exist. Nothing creates a Release,
uploads an asset, or fires on a tag push. The step is manual, and the procedure
now says so, including the part that is easy to skip: **download each published
asset from its URL and run its own router.** The packager proves the *build* was
sound — it refuses to emit sums for an artifact it did not bless, and a tampered
byte fails `-c`. It cannot prove the *upload* was.

Also recorded, because the question keeps being asked: **a plugin install does
not write your `settings.json`.** Measured in CTT — 0 router entries there, 5
hook bindings across 3 events in the plugin's own manifest, and
`checker/install-parity.sh` shows both install paths register the *same*
(event, script) set. Nothing of the user's is edited, which is what makes
`/plugin uninstall` clean. `ARM_ROUTER` is the path that writes `settings.json`,
for people who cannot use plugins.

### New Lean modules

- `RotTag.lean` (9) — the rule above, stated so it can be checked instead of
  remembered. `released_tag_never_moves` is the durable form: a published tag is
  a fixed point of an **entire history** of move attempts, in any order, not
  merely of one — a force-push loop *is* a history, and a rule that survives a
  single step is not an invariant. `unreleased_tag_can_move` is its non-vacuity
  partner and carries real weight: a rule that forbids everything forbids the
  safe operation as firmly as the dangerous one, and the usual repair for that
  is to weaken the rule. `move_preserves_name` says why a moved published tag is
  dangerous rather than untidy — the reference still resolves, so nothing
  anywhere reports an error. **Not proved, and stated plainly because "proved in
  Lean" reads like a technical control:** git does not enforce this. Lean
  constrains the model; the binding is procedural.
  10 mutants, 10 killed — but **three were first written from memory and all
  three were caught as DISCARDED, not survived**. One needle was indented
  differently from the source; one replacement contained its own needle, so it
  could never be seen to land; one appended to a signature, leaving the needle a
  prefix of its replacement. A harness without a landing assertion would have
  reported all three as *"the theorem is robust"* — which is the reassuring
  direction, and the reason that assertion exists.
  The suite's inherited header was wrong too: derived with `head -178` from a
  sibling, it described `RotStem`'s matcher mutants, concepts that do not appear
  in this module. Same defect `mutate_rotlog.sh` carried once before.

- `RotVariants.lean` (7) — a published document is *sound* when the archive
  names it carries are exactly those the packager builds, both directions
  (`sound_iff_setEq`). The obvious one-directional repair would have **missed
  the defect above entirely**, because a half-finished edit adds the new links
  and keeps the old: `covers_does_not_imply_clean` is that argument as a
  theorem. `version_drift_breaks_soundness` and `new_tier_needs_a_link` are
  quantified over an arbitrary release map, so they hold for a tier not yet
  invented. 10 mutants, 10 killed — one of which had to be **retargeted upward**
  after surviving: flipping a single link in the stale list does not make it
  sound, because `covers` still fails on the other two. The theorem was stronger
  than the mutant, which is recorded rather than treated as licence to weaken it.
- `RotDuplicate.lean` (9) — what actually fires is the **concatenation of two
  registries**, so `RotInstall`'s idempotence, which is true, cannot see a
  duplicate that lives across both. `unguarded_duplicates` counts 2;
  `guard_keeps_one` counts 1.
- `RotScan.lean` (14) — a one-level scan can only ever **over**-report staleness
  (`flat_never_underreports`): its failure mode is a false accusation, never a
  false silence. Plus the resolution chain's precedence and totality.
- `RotLog.lean` (12) — a self-consistent record reports exactly the gauge, so
  `Rs` is **derived rather than trusted**; two consistent records over the same
  terms cannot disagree; pairing detects a truncated log.

### Numbers

- **495** machine-checked theorems across 22 modules (was 205 across 14),
  0 `sorry`, 0 `native_decide`, 0 build warnings.
- **35** gates (was 29); 23 fast, 12 deep. The 0.9.0 line said "33 (22 fast, 11
  deep)" and the deep tier already held 12 -- a prose figure nothing recounted.
- Every new theorem `#print axioms`-audited and `leanchecker`-re-verified.

---

