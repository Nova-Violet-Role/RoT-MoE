# Changelog

All notable changes to **RoT MoE** are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) —
with one deliberate twist documented below.

---

## The three numbers are not a roadmap

`0.2.0`, `0.2.1` and `0.2.2` are **released together, on the same commit**. The
version *is* the variant. Nothing in `0.2.1` supersedes `0.2.0`; it adds a
Lean 4 workshop on top of it. Nothing in `0.2.2` fixes `0.2.1`; it unseals a
tactic that `0.2.1` withholds **by policy**, and ships the instrument that keeps
that honest.

| pick | if you want |
|---|---|
| `0.2.0` Pure Router | the nine-lane router and nothing else. No Lean, no toolchain, no network. |
| `0.2.1` Router + Lean 4 | the same router **plus the machine that makes the theorems** — bounded installer, official hosts, your own proved repos. |
| `0.2.2` Router + Lean + Extra | all of the above with `native_decide` unsealed, and `checker/axiom-class.sh` to tell KERNEL from COMPILER trust. |

---

## [0.4.0] · [0.4.1] · [0.4.2] — 2026-08-03

Three archives, one tree. The patch digit is the tier: `0` core, `1` lean,
`2` unsealed.

### Fixed

- **The `sorry` alarm cried wolf on clean proofs.** The reminder hook counted
  `\bsorry\b` in a file's *text*, so a doc comment reading "no sorry, no
  native_decide" — the sentence this project's own discipline puts in files —
  was scored as an admission. An armed 50-turn session wrote a correct module,
  was told twice it "contains 1 sorry", and had to argue with its own tool.
  Both arms now ask the **elaborator** instead, counting the compiler's
  `declaration uses \`sorry\`` warning, which is per-declaration and cannot be
  fooled by a comment. Measured both directions on Lean 4.33.0-rc1: a real
  `by sorry` produces the warning, `sorry` in comments produces none, where the
  old text scan counted two. An alarm that fires on correct work teaches people
  to ignore alarms, which costs more than the false positive itself.

- **A green local sweep could contradict CI.** The check that asks whether the
  committed `STATUS.md` verdict is *true of this tree* lived inside the 3-week
  schedule simulation, which is gated behind `gate-all --full`. CI runs FULL; a
  developer running plain `gate-all.sh` does not. So the tree could report ALL
  26 GATES GREEN and publish a verdict claiming 154 theorems against 162 in the
  sources — and it did, failing three CI legs at once. The comparison now lives
  in `checker/verdict-fresh.sh`, runs in the **default** gate set and in
  `ci.yml`, and the simulation *delegates* to it rather than keeping a copy.
  Rule enforced from here: every check CI can fail, the default local sweep must
  be able to fail too.

- **README documented 12 of 13 Lean modules.** `RotStem.lean` had no row, so the
  published-claims audit summed the per-module counts to 152 against 162 and
  failed. Row added, describing the theorems that are actually in the file.

### Added

- `checker/verdict-fresh.sh` — anti-vacuity first (both sides must carry a real
  verdict before they are compared, because two empty strings compare equal
  forever), then a whitespace-insensitive comparison, then a control that
  perturbs the committed text **in memory** and requires the difference to be
  seen. A checker that edits the tree it is judging is a hazard.

### Notes

- 183 machine-checked theorems across 13 modules, 0 `sorry`, 0 `native_decide`.
- 27 default gates green; all five GitHub workflows green with zero errors and
  zero warnings across 254 log files.

### Added — the gauge stops being a recipe and becomes a law

- **`gauge_separates`.** `R/s+(M,C,T) = M·C·T·R/s+(1,1,1)` — the three per-turn
  modifiers factor out of the entire sum, exactly, for every lens family, every
  activity vector, every breadth. With it: `gauge_scales_in_C` (confidence is
  linear, not saturating), `gauge_zero_of_C_zero` (divergence cannot manufacture
  confidence), `gauge_modifiers_commute` (pre-multiplying `M·C·T` outside the
  loop is provably the same engine as applying it inside — so the two shipped
  arms may differ there without disagreeing).

- **"Useful chaos" is now proved, not asserted.** The spec always said the
  sigmoid *"rewards median divergence and damps both conformism and pure
  chaos"*. That is a claim about a shipped function, and the README used to
  answer it with "no instrument exists". Since σ′ = 4·σ·(1−σ), the quantity
  `σ(1−σ)` **is** the marginal return on divergence: `marginal_gain_le_quarter`
  bounds it, `marginal_gain_max_iff_center` shows the bound is reached **only**
  at the median, and `pure_chaos_pays_less` / `conformism_pays_less` fall out as
  the same theorem applied at δ=1 and δ=0. One mechanism penalising both failure
  modes, with `sigma_symm_about_center` (σ(x)+σ(1−x)=1) proving the symmetry.

- **Lane weights.** `carnage_leads_creative` and `violet_leads_empathic` — eight
  strict inequalities each — plus `creative_amplifies_carnage` /
  `empathic_amplifies_violet`: a lane *amplifies* its lead (0.6 → 2.5, 0.6 →
  2.3) rather than merely naming it.

- **The ninth lens, corrected.** A first draft read the eight-row CREATIVE and
  EMPATHIC tables literally and modelled 🧭 Claude as *absent* from those lanes.
  That was wrong: `engine/rot-lean.md:270` states K=9 on this head and the lens
  is always active, and `:117` gives it a documented default λ 1.5 / μ 1.05. A
  profile table that omits a lens is not deleting it — the lens falls back to
  its default. Now total functions over ℚ with no `Option`, and
  `every_lens_weighted_in_every_profile` proves no lane degrades to eight.

- **`ROTMOE_DEBUG_LOG` — a real debugger for the router.** Set it and both arms
  append one JSON line per gauge evaluation carrying every factor: per lens its
  λ, μ, activity, δ, σ, H and term. `bench-router.sh` phase 5 recomputes `R/s+`
  from those terms, requires it to match what the router reported, and then
  **corrupts a term to prove the check can fail**. Measured in a live 56-turn
  CTT session: 14/14 records recomputed exactly, K=9 and nine lens terms in
  every one, 93–133 ms per turn on the PowerShell arm. The log records prompt
  *length*, never prompt text.

### Changed

- Benchmark figures refreshed from three fresh runs (194–256 ms bash arm, ~20 ms
  of it process start). The previous 170–179 ms and ~130 ms figures were true
  when taken and are now stale; the range is kept rather than a single number,
  because a 32% run-to-run spread is itself the honest finding.

## [0.3.0] · [0.3.1] · [0.3.2] — 2026-08-03

The three numbers are not a roadmap. The patch digit is the **tier**: `0.3.0` is
the router alone, `0.3.1` adds the Lean 4 proof corpus, `0.3.2` adds the
unsealed checkers. They ship together, from one commit.

The minor moved because the **content** moved. Publishing changed files under an
unchanged version string is the same staleness defect this repository refuses
everywhere else — an installed `0.2.1` and a rebuilt `0.2.1` would be
indistinguishable to anyone holding the archive.

### Proved

- `RotPath.lean` 8 to 12 theorems, and the corpus 154 to **158**. The reminder
  hook's module derivation — workspace root plus edited file, out comes the Lean
  module to build — had shipped with **three silent defects**. It returned no
  verdict at all, which reads as "nothing to check" rather than "I could not
  work out what to build".
  - `moduleOf_spelling_invariant` — the Windows and POSIX spellings of one edit
    give the same module.
  - `moduleOf_root_agnostic` — the module never depends on how the workspace
    directory is named or capitalised. Quantified over **arbitrary** roots, so
    it does not expire the day someone renames `Lean` to `Formal`.
  - `moduleOf_no_slash` — a derived module name never contains a separator.
  - `moduleOf_none_of_outside` — a file outside the workspace derives nothing,
    which is the theorem that separates *correct* silence from the two bugs.
  - Three mutations of the definitions each killed the build; `#print axioms`
    shows `propext, Classical.choice, Quot.sound` and no `sorryAx`; and
    `leanchecker` re-verified the module at exit 0 with zero bytes.

### Changed

- **`--root` now moves your PROOFS, not the toolchain.** A toolchain is a
  bounded one-time cost elan manages in the home directory; the proof workspace
  is what grows as you work, so it is the one that belongs on the disk you pick.
  `--elan-root` keeps the old capability for a tight system drive — one flag had
  been doing two jobs and answering the commoner question wrongly.
- Both installers now **scaffold** the workspace: a `lakefile.toml` and a
  `lean-toolchain` pinned to the version this corpus is verified against. A
  directory alone was not a workspace — the user's first theorem could not build
  at all, and the hook reported `LEAN REFUSED`, which reads as "your proof is
  wrong" when the truth was "there was nothing to build it with". Core-only, no
  mathlib: your proofs start at zero and grow from your own work.

### Fixed

- `elan toolchain install` **exits 1 when the toolchain is already present**
  (measured on elan 4.2.3). Both arms treated that as fatal, so the installer
  aborted on every machine that already had it — the common case for a re-run —
  and never reached the step that records the workspace.
- `SETUP_LEAN.ps1` never created or recorded a workspace at all, so a
  Windows-native user silently got the plugin's read-only bundled corpus, a
  directory that can never accumulate their proof debt.
- The recorder ran only at the end of the pwsh script, making it dead code on
  the two paths users actually take: `-DryRun` and "nothing to do".
- **The cross-arm handoff was broken.** PowerShell wrote a backslash path; the
  shell hook's `-d` test is false for those in Git Bash, so it rejected a
  correct workspace and fell back to the bundled corpus without a word. Both
  arms now agree on the format, and the reader still accepts what an older
  install wrote.
- The stale-verdict alarm now rings **before** the push. `verify.yml` had failed
  twice while all 26 local gates were green: a module count went 12 to 13 and
  the only instrument that could see it ran in CI. A check that can only fail
  after a push will keep failing after a push.

### Measured

- Router cost re-measured: **170-179 ms** across three runs of twenty
  invocations, ~17 ms of which is bash process startup. The README had said
  ~154 ms, which predated the `R/s+` gauge the router now computes on every
  invocation. Recorded as a range plus the bound the gate enforces (under
  500 ms), because a single figure is a snapshot pretending to be a constant.

## [0.2.0] · [0.2.1] · [0.2.2] — 2026-08-03

Released together from one commit, as always: the version **is** the variant.

### The router line now carries what the README always promised

`README.md` said the hook adds *"a named lane and a gauge reading"*. For three
releases it added the lane alone. The premise behind that was sound — one
stateless hook call has not measured nine lens activities, and a fabricated
vector is worse than none — but the conclusion was wrong, and it left a promise
unkept.

By the time the line is printed the router **has** measured something: which
lane fired. Written in the gauge's own units that is a one-hot activity vector,
and the reading is computed per invocation, not appended as a constant:

```
FORGE 0.66  CLINICAL 0.57  STRATEGIC 0.47  RECURSIVE 0.45  EXECUTIVE 0.44
PREDICTIVE 0.41  STEALTH 0.39  CREATIVE 0.32  EMPATHIC 0.31  CONVERGENT 0.16
```

Byte-identical on both the POSIX and PowerShell arms. `M`, `C` and `T` are the
neutral `1.0` because memory residue, confidence and recency are genuinely
unavailable to one stateless call — stated in the code and the README rather
than hidden. The reading is a function of the lane: it varies across lanes, not
across turns.

### Half the router was inert and looked healthy

The hook registers on `UserPromptSubmit` **and** `PreToolUse`. The `PreToolUse`
half read only `tool_name`, so every tool call in every session routed to
`CONVERGENT none` — a healthy-looking stream of classifications carrying no
signal at all. It now reads the tool's intent (`command`, `file_path`, `path`,
`pattern`, `description`). Measured: a Bash running the Lean build tool routes
to FORGE, a Bash searching a log for the word error routes to CLINICAL, an Edit
of a proof module routes to FORGE.

### CLINICAL vocabulary widened

`segfault crash panic leak regress traceback` join the stem list on all three
surfaces — both router arms and the engine document — after a live session
misrouted *"there is a segfault when I free a pointer twice"* to `CONVERGENT`.
Router accuracy on the labelled bench is unchanged at **18/18**.

### Verification

- Every one of the **12 modules** is now under a mutation instrument. Four
  (`RotAbility`, `RotDorks`, `RotLens`, `RotMutant` — 44 of 144 theorems) had
  never been attacked before this release.
- **59 mutants, 59 killed, 0 survived, 0 discarded** across all eight suites.
- The lens **roster** is now bound across four surfaces in name *and* order;
  renaming a lens in the engine document is caught at exit 1.
- An overclaim was repaired: `lead_does_not_shrink` proved an independence
  property its name did not describe.
- Mutation attribution no longer reports a per-line list as an inventory. When a
  mutant produces no `.olean`, **every** theorem in the module is dead, and the
  report now says so instead of implying survivors.

---

## [0.1.2] — 2026-08-01 — Router + Lean + Extra

### Added
- `UNSEALED.md` — the only document that distinguishes this variant. Records the
  measurement that corrected the original premise, the four-tactic axiom table,
  and the two design defects the tool found in itself.
- `checker/axiom-class.sh` — classifies every theorem **KERNEL / COMPILER /
  BROKEN** from `#print axioms`. `ROTMOE_ALLOW_COMPILER=1` permits-and-reports.
  Rule enforced: a COMPILER theorem may never be counted in a headline number.

### Measured, not assumed
The premise for this variant was that `native_decide` could be reached through
`leantar` and `leanir` without `clang`/`lld`/`llvm-ar`. That was **disproved by
measurement**, and the corrected facts are shipped rather than the guess:

| tactic | axioms it introduces |
|---|---|
| `decide` | none |
| `rfl` | none |
| `bv_decide` (CaDiCaL) | `propext` |
| `native_decide` | `…native_decide.ax_1_1` — a fresh axiom per theorem |

`leantar` is the `.ltar` cache compressor; `leanir` dumps IR and generated C;
`clang`/`lld` **are** what `leanc` wraps. `native_decide` was already reachable
in `0.1.1` — it was withheld by policy, not by capability.

**The decisive finding:** `lake build` exit 0, then
`lake env leanchecker Proofs.NativeProbe` **also exit 0** (control: exit 1).
The kernel re-check does **not** catch `native_decide` — a declared axiom is
trusted by definition. `#print axioms` is the only witness.

---

## [0.1.1] — 2026-08-01 — Router + Lean 4

### Added
- The full Lean 4 shelf: bounded installer against official hosts only, the
  proof corpus, and the discipline as runnable scripts.
- `lean/Proofs/RotAbility.lean` — 16 theorems binding each of the nine lenses to
  what it *does*, including `every_lens_is_load_bearing` (erasing any lens
  strictly lowers the ensemble weight) and `no_ability_overclaims`.

### Note on what this variant is for
It is not "the same product with proofs attached". `0.1.0` is the product;
`0.1.1` is the product **plus the workshop it was built in** — reshape the
router and prove the reshape, start your own proved repositories, and get the
verification discipline as scripts you can run.

---

## [0.1.0] — 2026-08-01 — Pure Router

### Added
- The nine-lane router as a `UserPromptSubmit` hook, both arms (`sh` and
  PowerShell), cross-diffed byte for byte.
- `ARM_ROUTER` / `DISARM_ROUTER` installers with a byte-identical round trip.
- The checker suite and CI across Linux, Windows and macOS.

### Fixed
- **The installer armed the wrong directory.** All four installer arms honoured
  `CLAUDE_DIR` but ignored `CLAUDE_CONFIG_DIR`, which is what Claude Code itself
  reads. Precedence is now `CLAUDE_CONFIG_DIR` → `CLAUDE_DIR` → `$HOME/.claude`.
  Found by installing the *artifact* rather than testing the repository.
- **Disarm left an empty `hooks` container.** `hooks/settings-merge.js` now
  removes `"hooks": {}` when the last entry is gone, so the round trip is byte
  identical.

---

## Verification shipped with these releases

Every claim below has a named instrument. Nothing here is asserted from reading.

| claim | instrument | result |
|---|---|---|
| the Lean corpus elaborates | `lake build` (exit code read directly) | exit 0, **zero `sorry`** |
| the proof terms are valid | `lake env leanchecker <Module>` | exit 0; control exit 1 |
| nothing rests on the compiler | `checker/axiom-class.sh` | 144 KERNEL, 0 COMPILER, 0 BROKEN |
| the archives are well-formed | `checker/release-package.sh` | each tier a strict superset of the one below |
| the artifact installs | `checker/release-install.sh` | unpacked, armed, round trip byte-identical |
| the router **routes** from each archive | `checker/release-session.sh` | 27 lane-sessions, 3 archives × 9 lanes |
| the router **works in a real conversation** | `checker/release-longsession.sh` | 181 turns, 181 real model answers, 181 firings |

The last row is the one that took three attempts. The first two "local proofs"
passed while no model turn had ever happened: an empty scratch config is not
logged in, and `UserPromptSubmit` fires *before* the model call, so the router
printed and every assertion went green on a session that never spoke. The
sustained test clones a real credential, installs the plugin the way a user does
(`claude --plugin-dir <artifact.zip>`), and holds a resumed conversation for a
wall-clock budget — with an auth gate that refuses to score any turn unless the
session answered for real.

[0.1.2]: https://github.com/Nova-Violet-Role/RoT-MoE/releases/tag/v0.1.2
[0.1.1]: https://github.com/Nova-Violet-Role/RoT-MoE/releases/tag/v0.1.1
[0.1.0]: https://github.com/Nova-Violet-Role/RoT-MoE/releases/tag/v0.1.0
