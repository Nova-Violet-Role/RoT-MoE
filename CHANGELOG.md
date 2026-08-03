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
