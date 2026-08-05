<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# Scrutiny — 0.7.0 / 0.7.1 / 0.7.2

**What this document is.** An adversarial reading of the 0.7 release by the
person who wrote it. Not a summary — a list of the places where this packet
could still be wrong, what was done about each, and which claims rest on a
measurement versus which rest on an argument.

Every number here was produced by running something. Where a claim is
**MEASURED** but not **PROVED**, it says so, because the two are not the same and
a document that blurs them is worse than one that omits the claim.

---

## 0. The finding that should shape how you read the rest

Twenty-nine gates were green. Every one of the eight defects in the table below
was **already live on a real machine**.

That is not an argument against gates. It is the argument for the specific kind
added in this release: each of the four new checkers exists because a defect got
past everything else, and each was mutation-tested by deliberately re-creating
the defect and confirming the gate goes red.

A gate nobody has broken on purpose is an untested alarm.

| # | defect | how long it was live | what now catches it |
|---|---|---|---|
| 1 | router fired twice per prompt | since the plugin gained `hooks.json` | `checker/router-duplication.sh` |
| 2 | `DISARM --dry-run` deleted for real | since `--dry-run` was documented | `checker/disarm-safety.sh` |
| 3 | plugin-path entries were unremovable | since the marketplace install existed | `checker/disarm-safety.sh` |
| 4 | unknown installer flags ignored | always | both gates above |
| 5 | proof scan one level deep | always | `checker/remind-measure.sh` |
| 6 | staleness overstated 55× | since proofs were foldered | `checker/remind-measure.sh` |
| 7 | `recorded` step nothing ever wrote | always | `checker/remind-measure.sh` |
| 8 | POSIX path unreadable by PowerShell | since `SETUP_LEAN.sh` recorded paths | `checker/remind-measure.sh` |

---

## 1. Where the specification was WRONG, not the code

Two cases. Both are recorded because a spec quietly edited to match the code is
worthless, and a spec that survives only because nobody tested it is decoration.

### 1.1 The route record's `Rs` was never meant to equal the gauge's

`checker/log-replay.sh` first asserted `route.Rs == gauge.Rs`. It failed on
**every** line, including the untouched positive control — the tell that the
checker, not the log, was wrong. The route record carries the **two-decimal
displayed** reading that matches the marker a user sees; the gauge record carries
full precision. `0.66427` and `0.66` are the same measurement at two precisions.

The repair was not a tolerance. `RotLog.lean` now models the relationship
(`WellPaired ε`, `displayEps = 1/200` — half an ulp of a two-decimal display),
and the checker requires `parseFloat(route.Rs) === Number(gauge.Rs.toFixed(dec))`
with `dec` derived from the route string itself. **That is stricter than the
tolerance it replaced**: a control that changes `"0.66"` to `"0.70"` — a wrong
number wearing the right number of digits — is rejected.

### 1.2 A theorem that held without its hypothesis

`old_chain_falls_to_bundled` built green with a `Variable name 'h' is not
explicitly referenced` warning. The hypothesis was doing nothing: the *labels*
differ for free, so the theorem was weaker than its own doc comment claimed.

Split into two: `old_chain_measures_the_wrong_tree` (stated on the path, where
the hypothesis is load-bearing) and `old_chain_reports_a_different_source`
(stated on the label, and honestly unconditional). **A Lean warning was the only
thing standing between this repo and an overclaimed theorem.**

---

## 2. Where the INSTRUMENT was wrong

Three, and they are the most instructive entries here because in each case the
thing that was broken was the thing meant to detect breakage.

### 2.1 The mutation suite left the tree unbuildable

`lean/mutate/mutate_rotduplicate.sh` restored every source file and stopped
there. Each mutant deletes the `.olean` to defeat Lake's incremental build, so
the run ended with three modules compiled *out* of the tree. `git status` was
clean and the sources were perfect — and then `checker/axiom-audit.sh` failed
with *"the axiom probe did not elaborate"* and `axiom-class.sh` reported *"36
theorems unaccounted for"*. Both were true statements about damage the harness
had done and not undone.

The suite now restores, **rebuilds**, asserts the `.olean` exists, and refuses to
report success otherwise.

### 2.2 The plugin detector counted stale cache directories as live registrations

Measured on the CTT instance: `claude plugin update` leaves every previous
version in the cache. Seven directories, `0.1.2` through `0.7.2`, each with a
`hooks.json` binding the router, under one enabled plugin id. The detector walked
the cache and reported **seven live registrations** — which reads as a sevenfold
duplication and is false.

`plugins/installed_plugins.json` is the authority: one entry per plugin with an
explicit `installPath`, and that is the only version whose hooks load. The
detector now reads the manifest first and keeps the cache walk as a fallback for
configs written by a CLI old enough not to have one. Both paths are covered by
fixtures, and reverting to the cache-only walk turns the gate red.

### 2.3 The new anchor check was a seven-line false alarm before it was a gate

`sed`'s bracket class is byte-wise in this locale, so stripping non-alphanumerics
from a heading that begins with an emoji removes *some* of its UTF-8 bytes and
leaves the rest. Every emoji heading slugged to `\xa6-v070--pure-router` and was
reported dead. Dropping non-ASCII whole (`tr -d '\200-\377'`, which is also what
GitHub does) fixed it.

It then found a **real** defect it was written for: `RELEASE.md`'s three variant
badges — the first thing a reader clicks — pointed at `#-v010-…`, `#-v011-…`,
`#-v012-…`, headings that stopped existing after `0.1.x`. Dead through six
releases, in the document whose only job is telling a stranger which archive to
download. Nothing could have caught it: a version bump seds the *headings*, and
the anchors carry a squashed spelling no version-shaped pattern matches.

---

## 3. Where a check FORBADE a correct future

`checker/release-package.sh` hardcoded
`VARIANTS="core:0.6.0 lean:0.6.1 unsealed:0.6.2"`.

It was correct on the day it was written and went red the moment `plugin.json`
moved to `0.7.2` — on a tree where nothing was wrong. Worse, the failure reads
like a real defect (*"the tree declares 0.7.2 but the highest variant is
0.6.2"*), and the obvious repair is to retype the numbers, which teaches nobody
anything and expires again next release.

**The spec was wrong, not the change.** The convention is the durable thing:
three variants share one `MAJOR.MINOR` and differ only in the patch digit, which
*is* the tier — `0` core, `1` Router + Lean 4, `2` Router + Lean + Extra. The map
is now derived from the manifest. A release bump is one edit to `plugin.json`.

A second consumer broke on that fix, and the way it broke is worth recording:
`checker/release-install.sh` obtained the map by **grepping the packager's source
text** for `^VARIANTS="…"`. That works only while the value is a literal, and the
sed returned `core:$_MM.0` verbatim, sending the gate hunting for an archive
named `rot-moe-$_MM.0-core.zip`. Parsing another script's source is the fragile
half of "single source of truth"; **asking** it is the robust half. The packager
now answers `--print-variants`, and a control confirms the map follows the
manifest (`plugin.json` → `0.9.2` yields `core:0.9.0 lean:0.9.1 unsealed:0.9.2`).

---

## 4. What is PROVED, what is MEASURED, what is neither

**PROVED** — a theorem closed, axioms audited, kernel re-verified by
`leanchecker`:

| claim | theorem |
|---|---|
| the guard removes the duplicate and still arms when it should | `guard_keeps_one`, `guard_still_arms`, `guard_can_decline` |
| exact-mode disarm cannot reach a foreign spelling; `--all` can | `exact_misses_foreign_spelling`, `any_removes_all` |
| `--all` does not touch a user's own hooks or the plugin | `any_preserves_foreign`, `any_preserves_plugin` |
| a one-level scan never *over*-reports freshness | `flat_never_underreports` |
| the gap is real, not hypothetical | `flat_gap_is_real` (witness: 53 vs 2946) |
| the resolution chain is total and ordered | `resolve_total`, `resolve_env_first`, `resolve_recorded_beats_discovered` |
| a gauge record's own fields determine its `Rs` | `consistent_Rs_eq_gauge`, `consistent_Rs_unique` |
| an orphan or mismatched route record is detectable | `wellPaired_discriminates` |
| **word-prefix firing implies substring firing** | `firesWord_imp_fires` |
| …and is strictly weaker, so the change is not cosmetic | `firesWord_strictly_weaker` |

**MEASURED** — exhaustively tested, no theorem:

- Both router arms agree on **73** corpus rows including all 12 word-boundary
  cases (`checker/cross-diff.sh`).
- **89 mutants across 12 suites: 89 killed, 0 survived, 0 discarded** — every
  suite run by hand, not inherited from a prior report.
- The debug log's every factor recomputed from its own fields for both arms,
  with 7 corruption controls rejected (`checker/log-replay.sh`).
- On the CTT instance: plugin updated `0.6.1` → `0.7.2`, `ARM_ROUTER` refuses,
  `settings.json` byte-identical, **0** router entries, one firing path.

**NEITHER — say it plainly:**

- *That the router improves any answer.* Nothing here measures output quality.
  The gauge is a divergence statistic over lens activity; it is not a quality
  score and no theorem claims it is.
- *That the word-prefix matcher routes every prompt correctly.* It is proved to
  fire on a strict subset of what the old one fired on, and measured on 24 rows.
  A stem list is a heuristic; the proof bounds the change, not the taste.
- *That the CTT verification covers a live session.* The install, the refusal and
  the settings state were measured. Two hooks firing inside a running session was
  measured earlier in the transcript that started this work, and the *fix* is
  verified by gate and by config state — not by re-observing a live double fire.

---

## 5. Open, and honestly so

1. **Six superseded plugin versions sit in the CTT cache.** They are inert —
   `installed_plugins.json` names one `installPath` — but they are also a
   growing pile nothing prunes. `claude plugin prune` addresses dependencies,
   not old versions of a still-installed plugin.
2. **`fired` is still substring-based for punctuation-led stems.** Only `.lean`
   uses that path today. If a future stem begins with punctuation *and* is a
   common substring, the exception becomes a hole. `firesWord1`'s fallback branch
   is where a future proof obligation lives.
3. **Locale invariance is measured on a formatter that does not exercise it.**
   `checker/cross-diff.sh` says so in its own comments: awk in this Git Bash
   build formats `%.2f` in the C locale regardless of `LC_ALL`, so that phase is
   trivially green here and only becomes a real test on a glibc runner. CI runs
   it on `ubuntu-latest`, which is where it counts.
