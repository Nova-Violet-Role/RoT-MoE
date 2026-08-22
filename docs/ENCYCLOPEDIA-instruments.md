<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# The instrument encyclopedia

Every gate this repository runs, what tier it sits in, what makes it run, which
script implements it, and whether that script contains a control.

**The table below is generated.** `checker/encyclopedia.sh` derives it from the
registry in `checker/gate-all.sh` and from the scripts on disk. A bare run of
that script compares this document against the tree and exits 1 when they have
drifted apart, so the reference cannot quietly go stale the way a hand-written
inventory does. Regenerate with `sh checker/encyclopedia.sh --write`.

## How to read the control column, and how not to

The column reports **static evidence**: whether the word *control* appears in
the script's executable text, only in its comments, or not at all. That is a
weaker statement than it looks, and the gap is the reason this document exists.

A gate whose source contains a control is not thereby a gate whose control ran.
Text in a file is not an execution. The column answers *does this instrument
contain a control?* and is silent on *did that control fire in the last sweep?*
Only a run answers the second question, and only for the run that answered it.

The column also under-reports in a way worth naming. `checker/count-theorems.sh`
carries its control as a `--selftest` subcommand, invoked by its own registry
row, and that mechanism never uses the word *control* in executable text. The
column therefore classifies it as COMMENT while its control is real and wired.
There are almost certainly others. A classifier built from one vocabulary sees
exactly as far as that vocabulary reaches.

That limitation was measured, not assumed. The column was built three times and
was wrong all three times, each time falsified by a script whose truth was
already known:

1. Matching `printf` or `echo` on the same line as the word missed every control
   announced through a helper function. It classified `checker/cross-diff.sh` as
   having no control, when that file's arm-versus-arm control is live at
   `checker/cross-diff.sh:158`.
2. Matching `CONTROL` case-sensitively missed `checker/spdx-sweep.sh:150`, which
   prints its verdict in lowercase.
3. Matching the character class `[Cc]ontrol` fixed the second case and broke the
   first, because that class matches `Control` and `control` but not `CONTROL`.

Only the fourth definition, case-insensitive across all three casings, passes
both known cases at once. Both are now assertions inside the generator, so the
column cannot regress to any of the three broken definitions without the gate
going red.

## Two tables, not one, and why the first count was wrong

The digest reports the default table and the FULL-only tier separately. The
first version of this generator reported a single figure of 82 gates. The
runner reports 72.

The ten-gate difference is a block appended to the table only when the runner is
in full mode. Those gates run in no bare sweep and no commit ever triggers them.
Folding them into one total describes a suite larger than the one that actually
guards a commit, which is precisely the failure `checker/gate-all.sh`'s own
header records: a gate sat behind a flag, was red, and the default sweep printed
green for weeks.

The over-count was not caught by inspection. It was caught because
`checker/gate-split.sh` parses the same table for a different purpose, reported
72, and disagreed. The extraction here is now copied from that gate rather than
reinvented, and a control asserts that neither extractor can see the other's
rows -- so the two scopes cannot quietly merge again.

The general form is worth stating: when two instruments read the same source and
report different numbers, at most one of them is measuring what it claims. The
disagreement is the finding. Averaging them, or trusting the newer one, discards
the only signal available.

## What a complete table does and does not buy

This document lists every gate. It is tempting to read a full inventory as full
assurance, and that reading is wrong in a way that is provable rather than
merely arguable.

Coverage of a suite is a **threshold, not a gradient**. If every gate in a suite
is informative, the suite is non-vacuous: `full_audit_gives_a_meaningful_suite`.
But an audit of any proper subset licenses nothing about the whole, however good
the audited part is: `a_nonempty_audit_does_not_make_a_suite_meaningful` exhibits
a suite whose audited members are all provably informative and which is vacuous
anyway, and `full_coverage_of_a_subset_proves_nothing` states the same fact with
the audited gates' quality quantified over, so that its irrelevance is explicit.
`the_unaudited_remainder_is_where_the_answer_lives` names the consequence: for
any audit short of the whole, the verdict is decided outside it.

So an inventory is a map of where the answer could be hiding. It is not itself
an answer. The honest reading of a partial audit is the same as the reading of
no audit at all, plus a shorter list of places left to look.

<!-- ENCYCLOPEDIA:BEGIN -- generated by checker/encyclopedia.sh; edits here are overwritten -->

## Digest

Regenerate with `sh checker/encyclopedia.sh --write`. A bare run compares
this section against the tree and exits 1 when they have drifted apart.

| Measure | Value |
|---|---|
| Gates in the DEFAULT table (a bare sweep runs these) | 72 |
| Of those, fast tier | 48 |
| Of those, deep tier | 24 |
| Gates reachable ONLY under --full | 10 |
| Checker scripts on disk | 83 |
| Scripts no registry row runs | 3 |
| Registry rows naming a missing script | 0 |
| Scripts with control text in CODE | 77 |
| Scripts with control text only in COMMENTS | 4 |
| Scripts with no control text at all | 2 |

The last three columns are STATIC EVIDENCE. They report what the source
contains, never what ran. A gate whose control text is present may still
have a control that never executes, and this document cannot tell you so.

### The FULL-only tier

These 10 gates are appended to the table only when the runner is in
full mode. A bare sweep does not run them and no commit ever triggers
them. They are listed separately because a total that folds them in
reports a suite larger than the one that actually guards a commit --
which is the failure `checker/gate-all.sh`'s own header describes, where
a gate sat behind a flag, was red, and the default sweep printed green.

- ci dry run (the CI step list, clean clone)
- generalization probe (does each theorem CONSTRAIN its function)
- scheduled verdict, three weeks with a remote
- plugin + fresh-user install
- marketplace session (install as a stranger, router in the loop)
- live-session smoke
- release session (every variant, every lane, real CLI)
- sustained session (cloned auth, plugin installed, real conversation)
- CTT session report (the 80-turn corpus the README quotes)
- deferred closure (the runner ran what the dry run could not)

### Scripts no registry row runs

- `checker/gate-all.sh`
- `checker/preflight.sh`
- `checker/status-verdict.sh`

### Scripts whose control text is only in comments, or absent

- `checker/ci-audit-freshness.sh` -- no control text
- `checker/count-theorems.sh` -- COMMENT only
- `checker/ctt-session.sh` -- COMMENT only
- `checker/preflight.sh` -- COMMENT only
- `checker/release-notes.sh` -- no control text
- `checker/router-duplication.sh` -- COMMENT only

## A. The gates, in registry order

| # | Gate | Tier | Runs when | Instrument | Control text |
|---|---|---|---|---|---|
| 1 | count-theorems selftest | fast | always | `checker/count-theorems.sh` | COMMENT |
| 2 | SPDX sweep | fast | always | `checker/spdx-sweep.sh` | CODE |
| 3 | no machine-local paths | fast | always | `checker/no-local-paths.sh` | CODE |
| 4 | lean module case (imports match the disk EXACTLY; a case-folding filesystem hides this) | fast | always | `checker/lean-module-case.sh` | CODE |
| 5 | name collision (no two modules declare the same qualified name -- latent until something imports both) | fast | always | `checker/name-collision.sh` | CODE |
| 6 | module claims (a per-module theorem/mutant count in the prose, bound to the source) | fast | always | `checker/module-claims.sh` | CODE |
| 7 | instrument encyclopedia (the gate reference is DERIVED from this registry, and refuses when it has drifted) | fast | always | `checker/encyclopedia.sh` | CODE |
| 8 | plugin root consistency (every declared root exists; declarations agree) -- exit 3 SKIP with no config dir | fast | always | `checker/plugin-root-consistency.sh` | CODE |
| 9 | dominance (does the routing layer STRICTLY EXTEND the default loop? D1-D7, each killable) | deep | hooks/,checker/dominance.sh,lean/Proofs/RotDominance.lean | `checker/dominance.sh` | CODE |
| 10 | trap corpus (all traps? scorer symmetric? latency still ORDER-CONTROLLED?) | fast | always | `checker/trap.sh` | CODE |
| 11 | mutation harness integrity (a filtered suite must exit 3; no suite may name another module) | deep | lean/mutate/,checker/mutate-harness.sh,lean/Proofs/RotSuiteVerdict.lean | `checker/mutate-harness.sh` | CODE |
| 12 | debug-log integrity (RECORDS recovered, never corrupt lines -- both arms run live) | deep | hooks/rot-router.sh,hooks/rot-router.ps1,checker/log-integrity.sh,checker/log-scan.js,lean/Proofs/RotLogAtomicity.lean | `checker/log-integrity.sh` | CODE |
| 13 | work-trace extractor controls (every P2.4 observable fired AND silenced on purpose) | fast | always | `node bench/work-trace.js --selftest` | n/a |
| 14 | CI log skips (a step that printed SKIP but concluded green must be DECLARED) | deep | .github/workflows/,checker/ci-log-skips.sh,lean/Proofs/RotCiSkip.lean | `checker/ci-log-skips.sh` | CODE |
| 15 | install-document lint | fast | always | `checker/claude-md-lint.sh` | CODE |
| 16 | licence bridge | fast | always | `checker/license-bridge.sh` | CODE |
| 17 | release consistency | fast | always | `checker/release-consistency.sh` | CODE |
| 18 | tag consistency | fast | always | `checker/tags-consistency.sh` | CODE |
| 19 | verdict freshness | fast | always | `checker/verdict-fresh.sh` | CODE |
| 20 | README FACTS block matches the tree | fast | always | `checker/facts-block.sh` | CODE |
| 21 | workflow exit reads are reachable under bash -e | fast | always | `checker/workflow-exit-reads.sh` | CODE |
| 22 | tree integrity (no tracked file is EMPTY on disk while git holds content) | fast | always | `checker/tree-integrity.sh` | CODE |
| 23 | mutation discipline | fast | always | `checker/mutant-discipline.sh` | CODE |
| 24 | mutant needles (every needle still exists; no suite all-DISCARDED) | fast | always | `checker/mutant-needles.sh` | CODE |
| 25 | local-only release regenerates from HEAD and cannot be published | deep | .claude-plugin/,CITATION.cff,RELEASE.md,checker/release | `checker/release-local.sh` | CODE |
| 26 | CI audit freshness (the run you read vs the tree you fixed) -- exit 3 SKIP without a credential | deep | .github/workflows/,hooks/,checker/ | `checker/ci-audit-freshness.sh` | NONE |
| 27 | workflow roles (a docs manager may not write code; freshness is measured on the youngest GREEN run, never the newest run) | deep | .github/workflows/,checker/workflow-roles.sh,lean/Proofs/RotWorkflowRoles.lean | `checker/workflow-roles.sh` | CODE |
| 28 | push guard (a branch push is still a push; the verdict may not depend on the destination -- the GATE asks whether the guard is sound, the pre-push HOOK asks the verdict) | deep | checker/push-guard.sh,.githooks/pre-push,lean/Proofs/RotPushGuard.lean | `checker/push-guard.sh` | CODE |
| 29 | P2.4 corpus (every task must DISCRIMINATE and route to its declared lane; a line count sees neither) | deep | bench/corpus-40.jsonl,checker/corpus-verify.sh,hooks/rot-router.sh,lean/Proofs/RotTaskCorpus.lean | `checker/corpus-verify.sh` | CODE |
| 30 | session manifest (the sessions160 obligation was closable by 'seq 160'; four blocks, four ids, 160 distinct digests) | deep | bench/sessions-160.done,checker/sessions-manifest.sh,checker/push-guard.sh | `checker/sessions-manifest.sh` | CODE |
| 31 | dorks | fast | always | `checker/dorks.sh` | CODE |
| 32 | hook footprint | fast | always | `checker/hook-footprint.sh` | CODE |
| 33 | hook timeout | fast | always | `checker/hook-timeout.sh` | CODE |
| 34 | A/B corpus vs published figures | fast | always | `checker/ab-analyze.sh` | CODE |
| 35 | A/B instruction compliance -- exit 3 SKIP without the raw corpus | deep | bench/,CHANGELOG.md,checker/ab-compliance.sh | `checker/ab-compliance.sh` | CODE |
| 36 | Lean witness vs shipped weights | fast | always | `checker/lean-binds-shell.sh` | CODE |
| 37 | release package | fast | always | `checker/release-package.sh` | CODE |
| 38 | release notes -- one body, three tiers | fast | always | `checker/release-notes.sh
checker/release-notes.sh
checker/release-notes.sh` | n/a |
| 39 | release body -- the three tiers ARE one body (the row above only reads exit 0) | fast | always | `checker/release-body.sh` | CODE |
| 40 | hook contract | fast | always | `checker/hook-contract.sh` | CODE |
| 41 | voice contract (the lens roster, held both ways) | fast | always | `checker/voice-contract.sh` | CODE |
| 42 | env layer (ORGAN 7 -- the rot family and the three loader laws) | fast | always | `checker/env-layer.sh` | CODE |
| 43 | env wiring (the DTD generates the config BOTH activations load) | fast | always | `checker/env-wiring.sh` | CODE |
| 44 | bonus archive (the shipped zip IS its tracked sources) | fast | always | `checker/bonus-archive.sh` | CODE |
| 45 | workflow lint + drift | fast | always | `checker/workflow-lint.sh` | CODE |
| 46 | CI honesty (no skip, no fake green) -- exit 3 SKIP without a credential | deep | .github/workflows/,checker/ci-honesty.sh | `checker/ci-honesty.sh` | CODE |
| 47 | README download links vs the packager | fast | always | `checker/readme-variants.sh` | CODE |
| 48 | cross-diff (both router arms) | fast | always | `checker/cross-diff.sh` | CODE |
| 49 | debug channel (marker + rotation, both arms, vs RotDebugLog.lean) | fast | always | `checker/debug-channel.sh` | CODE |
| 50 | router duplication (plugin + ARM must not stack) | fast | always | `checker/router-duplication.sh` | COMMENT |
| 51 | disarm safety (--dry-run writes nothing, --all reaches plugin entries) | fast | always | `checker/disarm-safety.sh` | CODE |
| 52 | remind measure (both arms, one tree, nested proof) | fast | always | `checker/remind-measure.sh` | CODE |
| 53 | kernel verdict class (a non-answer is not a rejection) | fast | always | `checker/kernel-verdict-class.sh` | CODE |
| 54 | log replay (every gauge record recomputed from its own fields) | fast | always | `checker/log-replay.sh` | CODE |
| 55 | benchmark | fast | always | `checker/bench-router.sh` | CODE |
| 56 | gate split | fast | always | `checker/gate-split.sh` | CODE |
| 57 | repo completeness | deep | README.md,CHANGELOG.md,STATUS.md,lean/,checker/repo-complete.sh | `checker/repo-complete.sh` | CODE |
| 58 | cross-diff (both reminder arms) | deep | hooks/prover-remind,checker/cross-diff-remind.sh | `checker/cross-diff-remind.sh` | CODE |
| 59 | verdict stability | deep | STATUS.md,checker/verdict | `checker/verdict-stability.sh` | CODE |
| 60 | gauge cross | deep | hooks/rot-router,lean/Proofs/RotGauge.lean,checker/gauge-cross.sh | `checker/gauge-cross.sh` | CODE |
| 61 | gauge hook corpus | fast | always | `checker/gauge-hook-corpus.sh` | CODE |
| 62 | profile binding | deep | engine/rot-lean.md,lean/Proofs/RotAbility.lean,checker/profile-bind.sh | `checker/profile-bind.sh` | CODE |
| 63 | axiom audit | deep | lean/,checker/axiom-audit.sh | `checker/axiom-audit.sh` | CODE |
| 64 | axiom class | deep | lean/,checker/axiom-class.sh | `checker/axiom-class.sh` | CODE |
| 65 | mutate the checker | deep | hooks/,checker/cross-diff.sh,checker/cross-diff-remind.sh,checker/mutate-checker.sh,checker/corpus-gauge.txt,checker/corpus-remind.txt | `checker/mutate-checker.sh` | CODE |
| 66 | portability | deep | checker/,hooks/,lean/,ARM_ROUTER,DISARM_ROUTER,.githooks/ | `checker/portability.sh` | CODE |
| 67 | installer round trip | deep | ARM_ROUTER,DISARM_ROUTER,checker/install,.claude-plugin/ | `checker/install-roundtrip.sh` | CODE |
| 68 | install parity | deep | ARM_ROUTER,DISARM_ROUTER,hooks/hooks.json,hooks/settings-merge.js,checker/install-parity.sh | `checker/install-parity.sh` | CODE |
| 69 | cli event coverage | fast | always | `checker/cli-event-coverage.sh` | CODE |
| 70 | context gate | fast | always | `checker/context-gate.sh` | CODE |
| 71 | session log | fast | always | `checker/session-log.sh` | CODE |
| 72 | release install | deep | checker/release,.claude-plugin/ | `checker/release-install.sh` | CODE |

<!-- ENCYCLOPEDIA:END -->

## Citations

The theorems named above are in `lean/Proofs/RotCoverage.lean`, built at exit 0,
kernel-rechecked with `leanchecker`, and mutated three times with every mutant
killed. They import the gate and vacuity model from
`lean/Proofs/RotVacuousGate.lean` and rest on the observation results in
`lean/Proofs/RotGateObservation.lean`.

Nothing in those files claims that any gate in this repository is always-red.
That is a question about this tree, and it is exactly what the remaining audit
is for.
