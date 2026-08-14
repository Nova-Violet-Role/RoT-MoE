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

## [5.0.0] · [5.0.1] · [5.0.2] — 2026-08-14

**Major, and the reason is narrow and precise: the gauge's verdict changed
meaning.** Anything parsing the band string gets a different answer than it did
in `4.0.x`. Nothing else in the observable surface moved — the `R/s+` values
themselves are byte-identical.

### Fixed — one band was applied to ten lanes

The gauge computed `R/s+` correctly and then read it against a hardcoded
`0.9–1.8` on every turn. Those are **one lane's numbers**, and the specification
gives each lens its own optimal range — stated twice, in two independent tables
that were extracted and compared before anything was edited. They agree on all
ten lanes.

The number was never wrong. The **meaning** was:

| lane | its own band | at `R/s+ 1.40` | what `4.0.x` printed |
|---|---|---|---|
| CREATIVE | 1.5 – 3.5 | **BELOW** → *add entropy* | `IN RANGE` → do nothing |
| STEALTH | 0.5 – 1.2 | **ABOVE** → *compress more* | `IN RANGE` → do nothing |
| FORGE | 0.9 – 1.8 | `IN RANGE` | `IN RANGE` ✓ |

The self-correction signal is the entire purpose of the score, so a verdict
reading `IN RANGE` when the lead lens says otherwise does not merely mislabel —
it **silences the one instruction the gauge exists to produce**.

This is the same defect fixed on 2026-08-13 in the weight tables, where nine of
the ten profiles were documentation and every lane was scored with one profile's
weights. Route correctly, then judge as if you had not.

**Why it survived review, proved rather than asserted:** the old band agrees
with the correct verdict on *exactly one* lane. This is a prover repo where that
lane is the common one, so every test written on an ordinary turn passed.

* `lean/Proofs/RotBandPerLane.lean` — **12 theorems**, 10/10 mutants killed.
  * `no_single_band_suffices` — exhibits a score two lanes classify differently,
    so **no single range can reproduce the per-lane law**. This is the theorem
    that makes the change load-bearing rather than cosmetic.
  * `global_band_wrong_for_nine_of_ten_lanes` — the count was **guessed as eight
    and `decide` said nine**. The docstring records the miss, because that gap is
    the argument for pinning a constant with a proof instead of a comment.
  * `the_only_agreeing_lane_is_forge` — names the one lane that masked it.
* **No second table.** Both arms already had a correct per-lane band table, used
  by the flag and not by the gauge. The first draft transcribed the ten pairs a
  third and fourth time; both were reverted. There is now one table and one
  lookup per arm.

### Changed — the verdict names its bounds

`BELOW RANGE (1.5-3.5)` rather than a bare `BELOW RANGE`. With ten bands live,
the old string could not say **which** band judged the score. All 12 pinned rows
in `checker/corpus-gauge.txt` moved in the same commit as the code, never after
it. Cross-arm diff: **97 passed, 0 failed**, both arms agreeing on all ten lanes.

### Fixed — the router spent a tenth of its per-turn budget re-reading one file

| what | before | after |
|---|---|---|
| convener config read (202 197 B `settings.json`) | 48 ms | **17 ms** |
| debug-log rotation, per 300 turns | 200 full rewrites | **10** |

The rotation bug is the instructive one. The log *was* capped, at exactly 5000
lines — and trimming **to** the cap means every subsequent turn appends line
5001, trips the check, and rewrites the whole 4.4 MB file to drop a single line,
forever. Hysteresis (trim to 80 %) ends it. Measured per-turn cost fell
**521.5 ms → 474.6 ms** against a **deliberately unchanged** 500 ms bound.

### Fixed — a staleness exemption that would have excused every workflow

`git ls-tree` without `-r` returns the *directory entry*, not the files beneath
it. The lookup matched nothing, every workflow was classified NEW, and NEW files
are exempt from every staleness rule. It stayed masked because established
workflows pass on run history before reaching that branch.

The **sixteenth** time in this repo that an instrument unable to distinguish
*"I could not check"* from *"the check passed"* has failed **toward the
exempting direction**. The lookup now asserts it found something before an
exemption may be granted, and that assertion was verified by breaking it on
purpose.

Also fixed: `actions/upload-artifact@v4` silently skips dotted paths, so
`.release/*.zip` uploaded nothing. Visible only because `if-no-files-found` was
set to `error` rather than `warn`.

### Corrected

* The releases page claimed **154 theorems**. The tree has **1632**. Stale, not
  approximately right, and fixed here rather than left to age.
* Counts moved with the tree everywhere they are claimed: **87 modules, 1632
  theorems, 77 mutation suites** in `README.md`, `plugin.json`,
  `marketplace.json` and `CITATION.cff`.

### Verification

| instrument | result |
|---|---|
| `lake build` | exit 0, **zero `sorry`**, exit code read directly |
| `#print axioms` | no `sorryAx` |
| `lake env leanchecker` | exit 0, zero bytes — absent-module control exits 1 |
| mutation, new module | **10 killed, 0 survived, 0 discarded** |
| cross-arm diff | **97 passed, 0 failed** |
| gates | **65 / 65 green** |
| per-turn cost | **475 ms** against the 500 ms bound |

