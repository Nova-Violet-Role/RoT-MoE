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

## The three numbers are not a roadmap

`0.8.0`, `0.8.1` and `0.8.2` are **released together, on the same commit**. The
version *is* the variant. Nothing in `0.8.1` supersedes `0.8.0`; it adds a
Lean 4 workshop on top of it. Nothing in `0.8.2` fixes `0.8.1`; it unseals a
tactic that `0.8.1` withholds **by policy**, and ships the instrument that keeps
that honest.

| pick | if you want |
|---|---|
| `0.8.0` Pure Router | the nine-lane router and nothing else. No Lean, no toolchain, no network. |
| `0.8.1` Router + Lean 4 | the same router **plus the machine that makes the theorems** — bounded installer, official hosts, your own proved repos. |
| `0.8.2` Router + Lean + Extra | all of the above with `native_decide` unsealed, and `checker/axiom-class.sh` to tell KERNEL from COMPILER trust. |

The patch digit **is** the tier, and it has been for every release in
[`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md): `0` core, `1` lean, `2` unsealed.
`.claude-plugin/plugin.json` carries the `.2` by convention, so a **directory- or
git-sourced** marketplace install reports `0.8.2` — it is installing the tree,
and the tree is the unsealed superset. The `.0` and `.1` tiers are what the three
`.release/` archives carve out of it, which is why
`checker/release-package.sh` builds all three from one commit and now derives
their versions from that manifest instead of a hardcoded triple.

---

## PRIOR → AFTER, at a glance

Every row was **measured on the shipped code**, before and after. This table is
the whole release in one screen; the sections beneath it give each row its
evidence.

| # | what | PRIOR (0.6.2, measured) | AFTER (0.8.x, measured) |
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
| 14 | theorems / modules | 205 / 14 | **473 / 22** |
| 15 | gates | 29 | **35** (23 fast, 12 deep) |
| 16 | mutation suites | 10 suites | **19 suites — 206 applied, 206 killed**, 0 survived, 0 discarded |
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

## [0.8.0] · [0.8.1] · [0.8.2] — 2026-08-06

Three archives, one tree. The patch digit is the tier: `0` core, `1` lean,
`2` unsealed.

**Every defect fixed in this release had already reached a live machine while
twenty-nine gates were green.** That is the only sentence of this entry that
matters, and it is the reason four of the additions below are gates rather than
features.

### Added — `Proofs/RotObserve.lean`: four readings that report less than the truth

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

**18 theorems, 8 mutants, 8 killed, 0 survived, 0 discarded.** The module states
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

`blind_reading_cannot_decide` is labelled in-file as a **repackaging, not a
discovery** — `#print axioms` reports it depends on nothing, the signature of a
near-tautology, and its worth is entirely in the instances.

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

Before this release was tagged, the packaged `0.8.1` Lean variant was installed
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
473 theorems.

### Fixed — a green CI leg that asserted nothing, from one missing `else`

The repair to the Windows `tty guard` shipped with a defect **in the repair
itself**, and run `31052104913` caught it: 145 success, **0 skipped**, 2 failure.

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

Mutants M09/M10 (**206 applied, 206 killed**). M10 exists because the two
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

Mutants M11–M13 (**206 applied, 206 killed**, was 190). M13 exists specifically
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

Three mutants added to `lean/mutate/mutate_rotgates.sh` (**206 applied, 206
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
built `rot-moe-0.8.1-lean.zip`. Three links, all wrong, **for two minor
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
`awk '{print $2}'`, which yields `*rot-moe-0.8.0-core.zip` **with** the star, so
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

- **473** machine-checked theorems across 22 modules (was 205 across 14),
  0 `sorry`, 0 `native_decide`, 0 build warnings.
- **35** gates (was 29); 23 fast, 12 deep. The 0.8.0 line said "33 (22 fast, 11
  deep)" and the deep tier already held 12 -- a prose figure nothing recounted.
- Every new theorem `#print axioms`-audited and `leanchecker`-re-verified.

---

