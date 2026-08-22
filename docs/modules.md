<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

> Moved from the front page in 7.0.0 — the README keeps the showroom,
> this file keeps the depth, word for word. Back: [README](../README.md).

### 📐 The modules that carry an argument

Fifteen are described below, out of 79 in the tree. This heading read *"the ten
modules"* while listing fifteen — a count frozen when the section was written and
never recounted as modules joined it. The section is **not** an inventory and
does not try to be: it walks the modules where the *proof* is the interesting
part, and each one states the defect it was written after. The full count is
machine-generated, and lives in the release table and `STATUS.md` rather than in
a heading that has to be edited by hand every time the tree grows.

* **`lean/Proofs/RotGates.lean`** (50 theorems) — **what may be deferred at a
  commit, and what may never be skipped in CI.** Two regimes, and the module
  states both because they have opposite answers.

  **In CI: nothing may be skipped.** Measured on run `31036272155` — which
  concluded `success` — **eight steps were skipped**, and one of them was
  `tty guard`, a real check that had therefore never run on Windows or macOS.
  `any_authored_skip_is_dishonest` makes one skip sink a run for any step name;
  `skipping_somewhere_is_still_dishonest` refuses the tempting excuse that
  running on another platform redeems it; `success_is_the_only_green` proves
  exactly one of the five GitHub outcomes is a pass, so `cancelled` and
  `neutral` — both of which render as "not red" — are failures.
  `no_authored_skip_is_implied` derives the no-skip rule rather than assuming
  it, which is why there is no clause an edit could relax. An earlier draft of
  this section classified steps into `provision` and `verify` and *proved
  provisioning may skip*; that was the law being weakened to fit the CI, and the
  `kind` field is gone so there is nowhere left to put "this one does not
  count". The workflow was fixed instead: all four `if: runner.os` steps now run
  everywhere and branch inside. **Run `31045719329` measured the result: zero
  skipped steps.**

  **The one exemption, and why it cannot spread.** GitHub injects its own
  scaffolding (`Set up job`, `Post <action>`), and it decides whether that
  scaffolding runs. Those steps are exempt from the skip rule — and from
  *nothing else*. `stepIsAcceptable` consults the scaffolding predicate in the
  `skipped` arm only, and `scaffolding_failure_is_still_dishonest` proves a
  `Post ` step that FAILS sinks the run for every possible name. The asymmetry
  is load-bearing, not decorative: mutating the failure arm to consult the same
  predicate kills nine theorems, and widening the predicate to match every name
  kills the run witnesses.

  `checker/ci-honesty.sh` is the executable half — it reads the run for `HEAD`
  over the API and fails on any skip or any failure, with five negative
  controls, two of which assert exactly this asymmetry.

  **At a commit: the split is deferral, not skipping.** The gate set had grown
  to **587 s**, so it is now split: cheap gates
  run on every commit, expensive ones run when the commit *touches what they
  check*. That is a mechanism which already produced one false green here — a
  gate behind `FULL=1` was red while the sweep printed `26/26 GREEN` — so the
  split is proved rather than trusted: `fast_always_runs` (an unconditional gate
  runs whatever is staged), `triggered_gate_runs`, `stagedRun_mono` (staging
  *more* never runs *less*, so no commit can dodge a gate by growing), and
  `no_trigger_never_escalates` — a deep gate with no triggers is invisible to
  every possible commit, which is the silent hole stated as a theorem.
  Quantified over an arbitrary gate table, so adding a gate cannot date them;
  `checker/gate-split.sh` binds the witness to the real runner.
* **`lean/Proofs/RotGauge.lean`** (49 theorems) — the R/s+ gauge.
  `sigma_strictMono`, `gauge_pos`, `gauge_ge_floor`, `gauge_not_constant`,
  `gauge_divisor_eq_card`. The last one is the theorem that would have caught a
  real bug in the shipped hook, where one lens's activity was pinned at zero
  while still dividing the sum by K.
* **`lean/Proofs/RotKernelVerdict.lean`** (9 theorems) — the kernel re-check is a
  verdict, not a formality. A module that elaborates is not the same as a proof
  term the kernel re-accepted, and these separate the two so a green `lake build`
  can never stand in for `leanchecker`.
* **`lean/Proofs/RotBandPerLane.lean`** (12 theorems) — one band for ten lanes is
  a coincidence, not a bound. The gauge read every score against `0.9–1.8`, which
  is one lane's range applied to all of them, so a CREATIVE turn at 1.4 printed
  IN RANGE while its own band starts at 1.5 and the correct signal was *add
  entropy*. The load-bearing theorem is not that the table is correct but that
  **no single band can reproduce the per-lane law** — proved by exhibiting a
  score two lanes classify differently. The old band disagreed on nine of the ten
  lanes; it agreed only with FORGE, which is exactly why it survived review.
* **`lean/Proofs/RotBandMonitor.lean`** (11 theorems) — the gauge's own band. An
  out-of-range R/s+ is a *correction signal*, never a veto, and these pin that
  distinction: below range demands more divergence, above range demands
  convergence, and neither is permitted to refuse an answer.
* **`lean/Proofs/RotNsilBoost.lean`** (9 theorems) — NSIL's BOOST decision. A
  boost raises one lens surgically without letting it take the lead, which is the
  property that keeps this a mixture rather than a single expert wearing eight
  hats.
* **`lean/Proofs/RotHostScaledBound.lean`** (6 theorems) — the latency bound
  scaled to the measuring host. A wall-clock number is meaningless without the
  machine's spawn tax; these prove the scaling is monotone and never flatters a
  slow host into passing.
* **`lean/Proofs/RotRoute.lean`** (18 theorems) — the router as a function.
  `route_fires`, `route_covers_every_mode` (no dead lane), `route_exact` (all
  ten lanes characterised in both directions), and the headline
  `nsil_overrides_tier1` — which proves both that the override lands *and* that
  it genuinely differs from the keyword result, the difference between a router
  and an `if`-chain.
* **`lean/Proofs/RotStem.lean`** (13 theorems) — stem matching proved over an
  **arbitrary vocabulary**, so the theorems do not expire the next time a stem is
  added. `fires_iff` pins firing to genuine infix containment; `not_fires_nil`
  proves an empty stem list is not a wildcard; `fires_mono` and `fires_perm` say
  growing the list can only add matches and that the *order* of stems never
  changes the outcome — the property that makes the word list safe to edit.
  `routeText_sound` is the headline: every routing result is either CONVERGENT or
  a lane whose own stems actually fired, so no lane can be reached by accident.
  Since 0.8.0 it also specifies **the matcher itself**, which had never been
  modelled: a stem must start a word. `firesWord_imp_fires` is what made that
  change safe to ship — word-prefix firing implies substring firing for *every*
  prompt and *every* class, so the new rule can only remove a false positive and
  can never move a prompt onto a lane it was not already reaching.
  `firesWord_strictly_weaker` proves the guarantee is not vacuous by exhibiting
  a prompt the old matcher accepts and the new one rejects: **improve** does not
  contain the stem `prove` at a word boundary.
* **`lean/Proofs/RotPath.lean`** (12 theorems) — path canonicalisation, written
  *after* a real stranding bug: the two installer arms wrote different command
  strings for one install, and removal matches by exact string, so installing
  from one shell and uninstalling from the other left a dead hook entry forever.
  `both_spellings_agree` proves the Windows and POSIX spellings converge to one
  string, quantified over an arbitrary drive so it does not expire when the repo
  moves. `normalize_idem`, `normalize_posix_id` (a Linux path is never
  rewritten), and `normalize_not_alpha_drive` — which replaced a **false**
  theorem the compiler refused, recorded in the source rather than quietly fixed.
* **`lean/Proofs/RotInstall.lean`** (23 theorems) — arming never disarms you.
  `arm_preserves_all_scalars` and `arm_preserves_unrelated_events`, quantified
  over **all keys**, so your `permissions`, your `env`, and every key not yet
  invented survive. `arm_idempotent`, `arm_appends` (your hooks keep their
  order), `disarm_removes`, `disarm_preserves_others`.
* **`lean/Proofs/RotRemind.lean`** (8 theorems) — organ 4's decision, and the
  first theorems about the reminder rather than about the router. The cross-diff
  proves the two arms agree on 23 corpus rows; these prove the properties no
  corpus can reach. `silent_regardless_of_alarms` quantifies over the alarm
  count, so open alarms alone can never make it speak — the wallpaper failure
  its ancestor died of. `speaks_iff` characterises speech in **both** directions,
  because "if there is debt it speaks" would still be satisfied by something that
  speaks always. `stale_monotone` says time can only make it louder — and carries
  a freshness hypothesis that **cannot be dropped**: `-1` does not mean
  "a minute ago", it means *no proofs found*, so `stale_monotone_needs_nonneg`
  proves the hypothesis cannot be dropped. `lower_threshold_speaks_more` is
  quantified over the threshold rather than pinned at 45, so retuning the default
  cannot turn a correct change red.
* **`lean/Proofs/RotAcquire.lean`** (9 theorems) — **a checker must never
  acquire anything**, and this module exists because one of ours did. Every Lean
  script here calls `lake`, and `lake` resolves the package *before* it runs
  anything, so a single probe began fetching mathlib into this 200 KB repository
  and reached **7.2 GB** before it was stopped. `no_lake_on_unbuilt` states the
  invariant over an *arbitrary* workspace: if it was never built, no execution
  path reaches lake. `lake_implies_built` is its converse, so a guard that
  simply refused everything would not satisfy the pair.
  `guard_survives_target_deletion` covers the subtle half — every mutant deletes
  the module's own `.olean` on purpose, so keying the guard on that artefact
  made a real workspace look never-built, and
  `old_guard_false_skips_after_target_deleted` exhibits exactly that workspace
  rather than describing it.
* **`lean/Proofs/RotVerdict.lean`** (11 theorems) — **the weekly status report
  must be able to say nothing.** Our scheduled workflow publishes `STATUS.md`
  and commits it *only when the verdict changed*, so a quiet week is visible as
  a quiet week rather than hidden by a timestamp bump. The rule was written in
  the comments and defeated by the payload: the file being compared carried the
  run's own clock and commit id, so "nothing changed" was unreachable and the
  bot would have committed every week forever. `silent_week_is_silent` is
  quantified over **every** clock and **every** commit id, which is exactly what
  the old design made false, and `decision_ignores_clock_and_sha` states the
  invariant over the variables that move instead of the values that hold today.
  `quiet_forever` and `published_exactly_once` reach where measurement cannot:
  a checker runs three weeks against a scratch remote, these cover all *k*. The
  old design is reconstructed alongside so `designs_disagree` and
  `old_commits_every_week` can prove the fix was not cosmetic — fifty-two empty
  commits a year, executed as a `#guard`, not asserted.
* **`lean/Proofs/RotDorks.lean`** (5 theorems) — the tag rotation that keeps
  the published hashtag block fresh. It proves the rotation is a **bijection**:
  `i -> (i*stride + offset) mod n` is injective whenever `gcd(stride, n) = 1`,
  so the set of tags in `README.md` is preserved for **every** seed rather than
  for the thirteen `checker/dorks.sh` samples. `stride_must_be_coprime` exhibits
  a stride that collapses distinct tags, which is why the hypothesis is real and
  why the script computes a coprime stride instead of hard-coding one that
  happens to suit 42 tags today.
* **`lean/Proofs/RotVacuity.lean`** (0 theorems — deliberately; the content is `example`s)
  — the audit that catches what every other gate certifies. A theorem with
  contradictory hypotheses is *true*, builds green, has clean axioms and passes
  `leanchecker`, while saying nothing at all. This module instantiates every
  hypothesis-carrying theorem in the packet at a **concrete witness**, so a
  green build is a positive statement: each guarded theorem has at least one
  real case it applies to. The gauge witnesses use the **shipping** FORGE
  weights rather than convenient toy values — and `checker/lean-binds-shell.sh`
  fails the build if those numbers ever drift from `hooks/rot-router.sh`.
* **`lean/Proofs/RotMutant.lean`** (33 theorems) — **the harness that judges the
  other harnesses.** Every mutation suite here reports `killed / survived /
  discarded`, and the dangerous confusion is between the last two: a patch that
  silently *failed to apply* leaves the build green, and a naive harness records
  that as `survived` — which reads as "the theorem is robust" when it means
  "nothing was tested". This module makes the distinction a function.

  It also settles a defect one step further down the pipeline, found in this
  repository's own CI: a kill is only evidence if the **verifier ran**. When a
  build's log cannot be written, `bash` never starts the command and returns 1 —
  and a harness that trusts that status records a kill against a build that
  never happened. `unattributable_is_never_killed` forbids it in general,
  `killed_carries_its_evidence` keeps the rule from degenerating into a blanket
  refusal, and `rules_differ_exactly_on_missing_evidence` is checked
  exhaustively by the kernel. It also **corrected the first version of itself**,
  which is the kernel earning its keep: a zero status with no evidence is an
  unfounded **survivor**, not a harmless one.
  `landed` is `toolExit = 0 ∧ ¬empty ∧ changed`, and `not_landed_discarded`,
  `tool_failed_never_killed`, `empty_never_killed`, `unchanged_never_killed`
  and `discarded_never_counts` prove a run that did not land can never be
  counted as evidence — in either direction. All three conjuncts are
  load-bearing: dropping any one of them from `landed` kills theorems, measured.
  `checker/mutant-discipline.sh` then binds it to the shell, and it is the
  reason the empty-file false green found in our own suite cannot recur.

  The module also carries the **restore** law, added after this repository's own
  recovery advice destroyed two shipped hooks. `gate-all.sh` refuses to run when
  a `.mutbak` is left behind, and it used to say *"restore each file from its
  backup (`cp <f>.mutbak <f>`)"*. Followed literally after a wall-clock kill,
  that left `hooks/prover-remind.sh` and `.ps1` at **zero bytes** — because a
  suite killed between *creating* a backup and *filling* it leaves a file that
  exists and cannot restore. `existence_is_not_restorability` separates the two
  predicates, `empty_backup_restore_is_destructive` shows `cp` from an empty
  source erases a non-empty file while reporting success, and
  `git_strictly_safer_on_the_measured_state` exhibits the state where
  `git checkout` is safe and `cp` is not. The advice now leads with git and
  prints each backup's size.
* **`lean/Proofs/RotLog.lean`** (23 theorems) — **the debug log, and whether it
  can be trusted.** The gauge half recomputes a record from its own fields:
  `consistent_Rs_eq_gauge` derives `Rs` rather than believing it, and
  `orphan_route_detected` refuses a truncated log that presents an unverifiable
  number. The routing half is newer and closes a hole that was easy to miss —
  the route record carried `lane`, `lens`, `Rs`, `chars` and `arm`, **every one
  of them checkable and none of them an explanation.** A user could hand over a
  complete, fully replayable log in which the disputed fact — *why that lane* —
  simply was not present. The record now carries the **matched stem**, and
  `Auditable` says the stem must be owned by the lane that fired.
  The theorem worth reading is `auditable_imp_vocabSafe`: **passing the audit
  entails the stem came from the router's closed table**, so "this log is safe
  to paste into a public issue" is not a second promise that could quietly be
  dropped — it is a consequence of the check that certifies the routing. Its
  converse is proved false (`vocabSafe_not_imp_auditable`), which is what makes
  the audit the stronger of the two. The shipped stem table appears here only as
  `example`s, deliberately: the word lists are a routing choice the project
  changes on purpose, so the theorems quantify over an arbitrary table and only
  the executable rows pin today's values.

* **`lean/Proofs/RotVariants.lean`** (7 theorems) — **the download links name
  the archives that exist.** A published document is *sound* when the set of
  archive names it carries is exactly the set the packager builds — both
  directions, which is what `sound_iff_setEq` states. Neither half alone is the
  property: `covers_does_not_imply_clean` shows a document can name every
  archive that exists and still carry a dead one, and
  `clean_does_not_imply_covers` shows it can be free of dead links while leaving
  a tier with no download at all. `version_drift_breaks_soundness` and
  `new_tier_needs_a_link` are quantified over an arbitrary release map, so they
  hold for a tier this project has not invented yet; concrete name sets appear
  only as `example`s. The binding to the real files is
  `checker/readme-variants.sh`, which reads the packager's own
  `--print-variants` and scans `README.md`, `RELEASE.md` and `docs/*.md`.

* **`lean/Proofs/RotTag.lean`** (9 theorems) — **a tag may move until a Release
  is published on it, and never after.** `released_tag_never_moves` quantifies
  over an entire history of move attempts; `unreleased_tag_can_move` keeps it
  from being vacuous. Not proved: that git enforces it — the binding is
  procedural, `docs/GIT-WORKFLOW.md` §4.3–§4.4.

* **`lean/Proofs/RotReleaseTier.lean`** (6 theorems) — **the patch digit IS the
  tier, and the map is a bijection.** `patch_injective` and `patch_surjective`
  together forbid two tiers sharing a digit or a digit naming no tier;
  `patch_lt_three` bounds the family at three; `ofPatch_none` keeps the map
  total by refusing anything outside it. The binding to the real files is
  `checker/release-package.sh`'s `tier_version()`, which derives `.0/.1/.2`
  from the manifest rather than hard-coding three version strings.

* **`lean/Proofs/RotEnvWiring.lean`** (10 theorems) — **the three laws the
  config loader obeys, stated over an arbitrary environment.**
  `load_declared_only` (a key the DTD never declared is never set),
  `load_unset_only` (an already-set key is never overwritten) and
  `load_locator_refused` (the two locator variables can never be assigned from
  inside a file they would have to be read to find). `load_inert` keeps them
  from being vacuous by proving a file of comments changes nothing, and
  `load_reload_stable` proves a second load is a no-op. The binding is
  `checker/env-wiring.sh`, which generates `engine/rot.env.example` from the
  DTD and asserts both activations load the same surface.

---


<details>
<summary><strong>Every module, recounted — the complete list</strong></summary>

The bullets above narrate the modules that carry an argument. This list is
the whole of `lean/Proofs/`, so that coverage is a fact about a set of names
rather than a coincidence between two integers. `RotReadmeTable.lean` proves
why that distinction is not pedantry: the arithmetic check is blind to an
omitted module that happens to contain no theorems, and `RotVacuity.lean` is
exactly such a module.

* `lean/Proofs/RotAbility.lean` (35 theorems)
* `lean/Proofs/RotAbJoin.lean` (7 theorems)
* `lean/Proofs/RotAbVerdict.lean` (9 theorems)
* `lean/Proofs/RotAcquire.lean` (9 theorems)
* `lean/Proofs/RotAttribute.lean` (19 theorems)
* `lean/Proofs/RotCalibration.lean` (18 theorems)
* `lean/Proofs/RotCaseFold.lean` (14 theorems)
* `lean/Proofs/RotCeiling.lean` (10 theorems)
* `lean/Proofs/RotCiSkip.lean` (10 theorems)
* `lean/Proofs/RotCite.lean` (10 theorems)
* `lean/Proofs/RotCorpus.lean` (11 theorems)
* `lean/Proofs/RotCostBudget.lean` (31 theorems)
* `lean/Proofs/RotCounter.lean` (9 theorems)
* `lean/Proofs/RotDebugLog.lean` (18 theorems)
* `lean/Proofs/RotDelivery.lean` (35 theorems)
* `lean/Proofs/RotDeployment.lean` (12 theorems)
* `lean/Proofs/RotDominance.lean` (21 theorems)
* `lean/Proofs/RotDorks.lean` (5 theorems)
* `lean/Proofs/RotDuplicate.lean` (10 theorems)
* `lean/Proofs/RotEffectiveLog.lean` (11 theorems)
* `lean/Proofs/RotEigenform.lean` (119 theorems)
* `lean/Proofs/RotEndpoint.lean` (18 theorems)
* `lean/Proofs/RotEnsemble.lean` (24 theorems)
* `lean/Proofs/RotEnvWiring.lean` (10 theorems)
* `lean/Proofs/RotEvent.lean` (16 theorems)
* `lean/Proofs/RotExperiment.lean` (66 theorems)
* `lean/Proofs/RotFamily.lean` (69 theorems)
* `lean/Proofs/RotGates.lean` (50 theorems)
* `lean/Proofs/RotGauge.lean` (49 theorems)
* `lean/Proofs/RotGaugePositivity.lean` (10 theorems)
* `lean/Proofs/RotGaugeZero.lean` (24 theorems)
* `lean/Proofs/RotGoalCap.lean` (7 theorems)
* `lean/Proofs/RotGrounding.lean` (8 theorems)
* `lean/Proofs/RotGuard.lean` (25 theorems)
* `lean/Proofs/RotInject.lean` (8 theorems)
* `lean/Proofs/RotInstall.lean` (23 theorems)
* `lean/Proofs/RotLens.lean` (13 theorems)
* `lean/Proofs/RotLensAbility.lean` (11 theorems)
* `lean/Proofs/RotLensActivation.lean` (33 theorems)
* `lean/Proofs/RotLiveRouting.lean` (11 theorems)
* `lean/Proofs/RotLocalRelease.lean` (8 theorems)
* `lean/Proofs/RotLog.lean` (23 theorems)
* `lean/Proofs/RotLogAtomicity.lean` (26 theorems)
* `lean/Proofs/RotLogLock.lean` (10 theorems)
* `lean/Proofs/RotMainRun.lean` (5 theorems)
* `lean/Proofs/RotMutant.lean` (33 theorems)
* `lean/Proofs/RotNullControl.lean` (16 theorems)
* `lean/Proofs/RotObserve.lean` (91 theorems)
* `lean/Proofs/RotOrdering.lean` (12 theorems)
* `lean/Proofs/RotP24Control.lean` (9 theorems)
* `lean/Proofs/RotP24Run.lean` (15 theorems)
* `lean/Proofs/RotPartialRun.lean` (15 theorems)
* `lean/Proofs/RotPath.lean` (12 theorems)
* `lean/Proofs/RotPluginRoot.lean` (6 theorems)
* `lean/Proofs/RotProbeStrength.lean` (15 theorems)
* `lean/Proofs/RotProse.lean` (39 theorems)
* `lean/Proofs/RotPushGuard.lean` (12 theorems)
* `lean/Proofs/RotReadmeTable.lean` (10 theorems)
* `lean/Proofs/RotRelease.lean` (15 theorems)
* `lean/Proofs/RotReleaseTier.lean` (6 theorems)
* `lean/Proofs/RotRemind.lean` (8 theorems)
* `lean/Proofs/RotRootDecl.lean` (9 theorems)
* `lean/Proofs/RotRotationCost.lean` (17 theorems)
* `lean/Proofs/RotRoute.lean` (18 theorems)
* `lean/Proofs/RotSample.lean` (11 theorems)
* `lean/Proofs/RotSaturation.lean` (12 theorems)
* `lean/Proofs/RotScan.lean` (14 theorems)
* `lean/Proofs/RotSeal.lean` (13 theorems)
* `lean/Proofs/RotSessionLog.lean` (38 theorems)
* `lean/Proofs/RotStem.lean` (13 theorems)
* `lean/Proofs/RotSuiteVerdict.lean` (21 theorems)
* `lean/Proofs/RotSweep.lean` (13 theorems)
* `lean/Proofs/RotSymbiogenesis.lean` (21 theorems)
* `lean/Proofs/RotTag.lean` (9 theorems)
* `lean/Proofs/RotTaskCorpus.lean` (16 theorems)
* `lean/Proofs/RotTrap.lean` (11 theorems)
* `lean/Proofs/RotTreeIntegrity.lean` (10 theorems)
* `lean/Proofs/RotUpgrade.lean` (12 theorems)
* `lean/Proofs/RotVacuity.lean` (0 theorems)
* `lean/Proofs/RotVariants.lean` (7 theorems)
* `lean/Proofs/RotVerdict.lean` (11 theorems)
* `lean/Proofs/RotVerdictDecision.lean` (11 theorems)
* `lean/Proofs/RotWorkflowRoles.lean` (12 theorems)
* `lean/Proofs/RotWorkTrace.lean` (18 theorems)

</details>
