<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# CP3 — the matcher, the changelog split, and the first real CTT install

Continues [CP1](2026-08-04-CP1-duplication-and-installer-safety.md) and
[CP2](2026-08-04-CP2-lean-gates-and-mutation.md).

---

## 1. `prove this lemma` did not reach FORGE — measured, then fixed, then proved

| prompt | before | after |
|---|---|---|
| `prove this lemma` | CONVERGENT (nothing fired) | **FORGE Claude** |
| `prove the read loop conserves bytes in lean` | STEALTH (it matched `byte`) | **FORGE Claude** |
| `improve the documentation` | would hit `prove` if added | CONVERGENT |
| `that is the dilemma` | would hit `lemma` if added | CONVERGENT |
| `cleaning up the tree` | would hit `lean` if added | CONVERGENT |
| `add a prefix to the name` | **CLINICAL** — `fix` fired inside "prefix" | CONVERGENT |
| `what is known about it` | **EXECUTIVE** — `now` fired inside "known" | CONVERGENT |
| `the latest release notes` | **CLINICAL** — `test` fired inside "latest" | CONVERGENT |
| `check Basic.lean now` | FORGE | FORGE (punctuation-led stem still works) |
| `proofs of termination` | CONVERGENT | **FORGE** (a stem is a word *prefix*) |
| `verification of the bound` | CLINICAL | CLINICAL (unchanged — `verif` still fires) |

The last three rows are the reason this is not a whole-word matcher. `verif` →
"verification" and `strateg` → "strategy" have always been prefix matches; a
matcher tightened to whole words would fix every collision and break every stem.

**The earlier diagnosis was wrong and is corrected here.** `Explanation.md` §4
blamed first-match-wins over lane priority. `route()` has always tried FORGE
first. The stem table simply lacked `prove`, `proof`, `lemma` — and they could
not be added while `fired` was a substring test.

### What was proved, not just tested

`lean/Proofs/RotStem.lean` now specifies the matcher itself, which had never been
modelled — the existing theorems were about *which class fired*, never about
*how a class decides*.

| theorem | says |
|---|---|
| `wordStart_isInfix` | a word-boundary occurrence is an occurrence |
| **`firesWord_imp_fires`** | word-prefix firing **implies** substring firing, for every prompt and every stem class |
| `firesWord_strictly_weaker` | …and the converse fails — witness `improve` / `prove` |

`firesWord_imp_fires` is what made the change safe to ship: the new rule can only
ever *remove* a false positive. It cannot invent a match or move a prompt onto a
lane it was not already reaching. `firesWord_strictly_weaker` stops that from
being the vacuous claim it would be if the two matchers were equal.

`lake build Proofs.RotStem` → **EXIT_DIRECT=0, zero warnings**;
`lake env leanchecker Proofs.RotStem` → **0**. 13 theorems in the module (was
10); tree total **244**.

### The Lean detail that cost the most time, and is worth remembering

`wordStart` was first written with the recursion guarded behind an `if`, needing
`termination_by`. That makes it **well-founded rather than structural, and a
well-founded definition does not reduce for `decide`.** All ~18 executable
examples failed with *"reduction got stuck at the Decidable instance"*.
Rewriting it structurally on the prompt fixed every one.

A spec whose definitions cannot be evaluated cannot be tested against the shell.
The shape that computes is the shape that ships.

Also measured: **`List.isInfixOf` does not exist in this toolchain.** Use the
`Prop` form `s <:+: p` (`List.IsInfix`, decidable). `List.isPrefixOf`,
`List.isPrefixOf_iff_prefix` and `List.infix_cons` do exist.

### Load-bearing, demonstrated

Reverting `fired` to a plain substring test (needle counted = 1, presence
asserted before building) turns **12 of the 24 new corpus rows red**. Restored →
`cross-diff` **73 passed, 0 failed**, both arms agreeing on every row.

---

## 2. The changelog was split, on request

`CHANGELOG.md` had reached 770 lines, so a reader comparing *prior* against
*after* scrolled through eight releases of settled history first.

* **`CHANGELOG.md`** — the current release only, opening with a 16-row
  **PRIOR → AFTER** table, every cell measured on the shipped code.
* **`CHANGELOG-ARCHIVE.md`** — `0.6.2` and earlier, byte-for-byte unchanged.

### It immediately exposed a gap in a checker

`checker/repo-complete.sh` re-measures every `N applied, N killed` in the tree
against the suites. The theorem-count rule had already learned in 0.6.x that a
changelog's older entries are **history** and must not be re-measured. The
mutant-count rule on the same file had never learned it, and nothing exposed the
asymmetry until a prior-versus-after table quoted the previous release's total.

Two changes, both mirroring the rule that was already there and justified:

1. the mutant scan is scoped to the newest release section, exactly as the
   theorem scan is;
2. `CHANGELOG-ARCHIVE.md` is exempt **as history**, with the reason written down.

**Neither is a hole, and that was verified in both directions.** A planted false
claim in the live section (`99 applied, 99 killed`) is still caught; a historical
claim added to the archive is correctly ignored; restoring returns exit 0.

The PRIOR cells now state *what changed* ("10 suites → 12 suites") rather than
restating a superseded total, because a correct historical number placed inside
the live section is a number the checker can only read as a false present claim.
Loosening the rule to skip table rows would have put a hole in the one check that
stops a mutation claim from drifting.

---

## 3. The first real CTT install — and what it revealed

Installed through the **actual CLI**, not a simulation:

```
claude plugin marketplace update rot-moe   -> Successfully updated
claude plugin update rot-moe@rot-moe       -> updated from 0.6.1 to 0.7.2
```

| check | result |
|---|---|
| installed manifest version | `0.7.2` |
| `hooks/plugin-detect.js` present in the installed plugin | yes |
| installed router carries the word-prefix matcher | yes |
| installed router: `prove this lemma` | **FORGE Claude** |
| installed router: `improve the documentation` | CONVERGENT |
| `plugin-detect` against the real CTT config | exit **0**, LIVE |
| router entries in CTT `settings.json` | **0** |
| `ARM_ROUTER.sh` against the real CTT config | **refuses**, exit 0 |
| CTT `settings.json` after the attempt | **byte-identical** (md5 unchanged) |

Zero settings entries plus a live plugin is the correct state: **one firing
path**. Backup left at `.claude/settings.json.pre-070.bak`.

Controls, so the guard is not merely "always refuses": with no plugin the
detector returns 10 and `ARM_ROUTER` arms (2 entries); `--force` overrides;
`DISARM --all` removes them again and `enabledPlugins`, `extraKnownMarketplaces`
and every unrelated key survive as valid JSON.

### The detector was over-reporting, and CTT is what showed it

`claude plugin update` **leaves every previous version in the cache**. That
instance held seven directories — `0.1.2` through `0.7.2` — each with a
`hooks.json` binding the router, under one enabled plugin id. The detector walked
the cache and reported **seven live registrations**, which reads like a sevenfold
duplication and is false.

`plugins/installed_plugins.json` is the authority: one entry per plugin with an
explicit `installPath`, and that is the only version whose hooks load. The
detector now reads the manifest first and keeps the cache walk as a **fallback**
for configs written by a CLI old enough not to have one.

New fixtures in `checker/router-duplication.sh` assert **exactly one** path line
naming the installed version — an over-reporting detector also exits 0, so
"exit 0" alone would not have caught this — plus a second fixture proving the
fallback still detects the plugin when the manifest is removed. Reverting to the
cache-only walk turns the gate red (4 path lines instead of 1).

**A fixture defect masqueraded as the bug first**: the manifest was written with
a Git Bash path, which node resolves onto another drive, so the read failed, the
fallback ran, and the case reported three registrations. The fixture now writes
the native form via `cygpath -w`. Same hazard, same repo, third time.

---

## 4. Three instruments were the broken thing

1. **The mutation suite left the tree unbuildable.** It restored sources but
   never rebuilt, and every mutant deletes the `.olean`. `git status` was clean;
   `axiom-audit` then failed with *"the axiom probe did not elaborate"* and
   `axiom-class` reported *"36 theorems unaccounted for"* — both true statements
   about damage the harness had done and not undone. It now restores, rebuilds,
   asserts each `.olean` exists, and refuses to report success otherwise.
   Re-run: **10 killed, 0 survived, 0 discarded**, and the no-download guard
   correctly *skipped* (exit 3) rather than fetching mathlib when it found the
   emptied tree.
2. **The new anchor check was a 7-line false alarm before it was a gate.**
   `sed`'s bracket class is byte-wise here, so stripping non-alphanumerics from
   an emoji heading removes *some* UTF-8 bytes and leaves the rest. Fixed with
   `tr -d '\200-\377'` — which is also what GitHub does.
3. **Three shapes I wrote failed `portability`**: a missing index exec bit on the
   new mutation suite, and `printf | grep -q` in two places (SIGPIPE plus
   `pipefail` is platform-dependent — the gate exists for exactly that). All
   three fixed; portability **21 passed, 0 failed**.

---

## 5. A check that forbade a correct future, and a real dead-link find

`checker/release-package.sh` hardcoded
`VARIANTS="core:0.6.0 lean:0.6.1 unsealed:0.6.2"`. It went red the moment
`plugin.json` moved to `0.7.2` — on a tree where **nothing was wrong** — with a
message that reads like a real defect. The triple is now **derived** from the
manifest, since the patch digit *is* the tier (`0` Pure Router, `1` Router +
Lean 4, `2` Router + Lean + Extra). Control: setting `plugin.json` to `0.9.2`
yields `core:0.9.0 lean:0.9.1 unsealed:0.9.2`.

That broke a second consumer in an instructive way: `release-install.sh` obtained
the map by **grepping the packager's source text**, which works only while the
value is a literal. It now *asks* — `release-package.sh --print-variants`.
Parsing another script's source is the fragile half of "single source of truth".

**The new anchor rule then found a real defect**: `RELEASE.md`'s three variant
badges pointed at `#-v010-…`, `#-v011-…`, `#-v012-…` — headings that stopped
existing after `0.1.x`. **Dead through six releases**, in the document whose only
job is telling a stranger which archive to download. Nothing could have caught
it: a version bump seds the *headings*, and the anchors carry a squashed spelling
no version-shaped pattern matches. Fixed, and now gated with a control that
proves the slug rule can still reject.

---

## 6. Repository state

| item | value |
|---|---|
| theorems | **244** across **17** modules |
| mutation suites | 12 — **89 applied, 89 killed, 0 survived, 0 discarded** |
| checkers | 45 |
| gates | 33 (22 fast, 11 deep) |
| cross-diff corpus | **73** rows, both arms agreeing |
| version | 0.7.0 / 0.7.1 / 0.7.2 |
| new docs | `docs/SCRUTINY-0.7.md`, `docs/GIT-WORKFLOW.md` (both ship in all three archives) |

Green and re-verified this checkpoint: `repo-complete` 50, `portability` 21,
`release-package` 17, `release-install` 20, `cross-diff` 73,
`router-duplication` 14, `axiom-audit`, `axiom-class`, `verdict-fresh`,
`release-consistency`, `tags-consistency`, `no-local-paths`, `spdx-sweep`,
`workflow-lint`, `gate-split`, `codemap validate`.

---

## NEXT

1. **Confirm the full sweep is 33/33** and commit — `gate-all.sh` prints
   *"Do NOT commit on top of this"* when any gate is red, and that instruction is
   binding.
2. **Commit, tag the release triple** (`v0.7.0`, `v0.7.1`, `v0.7.2` on one
   commit), **push to `Nova-Violet-Role/RoT-MoE`**, and confirm the CI matrix
   (`ubuntu-latest`, `windows-latest`, `macos-latest`) is green — the locale
   phase of `cross-diff` is only a real test on the glibc runner.
3. **Re-run `checker/ci-dryrun.sh`** end to end. It was last red on five items,
   every one of which has since been fixed; it needs a clean run to prove it.
4. **Attach the three `.release/` archives** to the GitHub release for the tags,
   and verify a download installs as a stranger (`release-install.sh` covers the
   local path; the published artifact is not yet checked).
5. **Prune the CTT plugin cache** — six superseded versions are inert but
   nothing removes them; decide whether that is the plugin's problem or the
   CLI's, and record the answer rather than leaving it ambiguous.
6. **Close the punctuation-led stem gap in Lean.** `firesWord1`'s fallback branch
   is the only place the old substring behaviour survives. Today only `.lean`
   uses it; a stem that is both punctuation-led and a common substring would
   reopen the hole, and that obligation belongs in `RotStem.lean` before it is
   needed rather than after.
