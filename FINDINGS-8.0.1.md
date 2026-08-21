# RoT MoE — 8.0.1 Audit + 9.0.0 Work Record

> **STATUS 2026-08-21.** The audit below produced 15 commits on branch `9.0.0`.
> Everything now lives in **`C:\GIT External Repo\RoT MoE`**, which is the git <!-- R2-ALLOW -->
> repository. Nothing is pushed. Section “9.0.0 — what was done” at the end of
> this file is the current state; the 8.0.1 sections are the findings that
> caused it.

## 🔴 The repository was not where anyone thought it was

Measured while preparing the release, and it explains a whole class of confusion:

```
C:\GIT External Repo\RoT MoE      .gitattributes .githooks .github .gitignore  ALL PRESENT   # R2-ALLOW
                                  .git                                        ABSENT
                                  git rev-parse -> fatal: not a git repository

<plugins>\marketplaces\rot-moe    .git present, origin Nova-Violet-Role/RoT-MoE.git
```

The working folder carried **every piece of git furniture except the one that
makes it a repository**. It reads as the repo to any human and to `ls`; it is not
one, and no commit or tag could ever have been made there.

**Fixed non-destructively**: the `.git` directory was COPIED (not moved) from the
plugin clone into `C:\GIT External Repo\RoT MoE`. Verified afterwards — <!-- R2-ALLOW -->
**435 tracked files compared byte-for-byte between the two trees, 0 differences**,
0 deletions, full history and all commits intact. The plugin clone keeps its own
`.git` and remains the installed runtime.

## 🟢 Y3 — the full 77-suite Lean mutation sweep, RUN

The one item that had been **NOT RUN** through the whole audit. Executed in this
repository, against its own freshly built workspace:

| suites | killed | survived | discarded | unparsed / non-zero |
|---|---|---|---|---|
| 1–20 | 200 | 0 | 0 | 0 |
| 21–45 | 320 | 0 | 0 | 0 |
| 46–62 | 142 | 0 | 0 | 0 |
| 63–77 | 135 | 0 | 0 | 0 |
| **total** | **797** | **0** | **0** | **0** |

**797 is exactly the README's published figure**, reproduced from a cold run with
a parser validated independently beforehand. The Lean tree was `git status`-clean
after every batch, so every suite restored its baseline.

**The parser had to be fixed twice before any number could be trusted**, and both
bugs are recorded because both are false-reading traps:

1. `[0-9]+ survived` matched **across a field boundary** — in `killed=5 survived=0`
   the substring `5 survived` matched, inventing five survivors that did not
   exist. A false ALARM.
2. Four suites use a different summary format. There are **five** in the tree:
   `All N mutants killed (N ran, …)` · `killed=N survived=N` · `=== Name: N killed, …`
   · `killed: N   survived: N` · `all N mutants killed, none discarded`.
   A single-format parser silently scored those as zero — a false NEGATIVE.

The final parser was validated on all five formats **plus three survivor controls
and a junk control**, so a reported `0 survived` means zero rather than "not
matched".

## 🟢 The three Lean instruments, in this repository

```
lake build            exit 0   (8746 jobs; exit read via PIPESTATUS[0], not through a pipe)
leanchecker           87 / 87 modules re-verified, 0 failed
  negative control    Proofs.NoSuchModule -> exit 1   (the instrument can fail)
sorry in kernel terms 0        (#eval over constants: "constants whose value contains sorry: 0")
modules / theorems    87 / 1632
```

A naive `grep -c '\bsorry\b'` reported **5** and was a false alarm: all five are
prose or string literals (a keyword list, three doc comments, and a line that
reads “0 sorry”). The kernel, not the grep, is what settles it.

---

# RoT MoE 8.0.1 — Full Test Compendium

**Subject** — `rot-moe` v8.0.1, tag `v8.0.1`, commit `1f57594`.

| role | path |
|---|---|
| source clone (checkers run here) | `C:\Users\Saimono\.claude\plugins\marketplaces\rot-moe` | <!-- R2-ALLOW -->
| **live runtime** (what the CLI actually executes) | `C:\Users\Saimono\.claude\plugins\cache\rot-moe\rot-moe\8.0.1` | <!-- R2-ALLOW -->
| Lean workspace | `<clone>\lean` (mathlib supplied by junction, see G1) |

**Host** — Windows 11 Pro N 26200 · pwsh 7.6.5 · GNU sed 4.9 / MSYS bash · Lean 4.33.0-rc1 · Node 26.7.0.
**Date** — 2026-08-21.

**Every exit code below was read directly** (`rc=$?` on the command itself), never through a pipe.

---

## Severity bands

| band | meaning |
|---|---|
| 🟥 **RED** | product defect, user-visible, blocks a stable release |
| 🟧 **ORANGE** | instrument or spec defect — goes red on *correct* code, or a claimed fix that fails its own check |
| 🟨 **YELLOW** | latent defect or unbound claim — no impact today, will bite later |
| 🟦 **BLUE** | environment / process / CI — not the codebase |
| 🟩 **GREEN** | verified working **and** its negative control was seen to fire |

A green whose control was never seen to fire is not listed as green. It is not listed at all.

---

## 🟥 RED — 2 found, 2 fixed and re-verified

### R1 · The PowerShell arms emit OEM best-fit garbage for every non-ASCII byte

**Files** `hooks/rot-router.ps1`, `hooks/prover-remind.ps1` — both arms, both trees.

**Measured.** Under `pwsh -NoProfile -File`, `[Console]::OutputEncoding` is the **OEM console codepage** (`ibm437` on this host) while the ANSI codepage and `$OutputEncoding` are both `utf-8`. Neither arm pinned it, so every non-ASCII character written to stdout was best-fit mapped by `WideCharToMultiByte`:

| source | emitted | why |
|---|---|---|
| `⚜️` U+269C U+FE0F | `??` | one `?` per UTF-16 code unit |
| `🕷️` U+1F577 U+FE0F | `???` | surrogate pair + variation selector = 3 units |
| `×` U+00D7 | `x` | best-fit |
| `·` U+00B7 | byte `0xFA` | best-fit into CP437 |
| `λ` U+03BB | `?` | no mapping |

**Blast radius.** Three gates red — `cross-diff` (the two arms disagree byte-for-byte, which is the repository's central claim), `session-log` (marker lines differ), and one surviving mutant in `mutate-checker` that could not be attributed because the cross-diff baseline was already red. **And it was live in the operator's own session**: every stanza rendered `?? Nova ? ? 1.4` instead of `⚜️ Nova · λ 1.4`.

**Fix applied** — one line per arm, immediately after the `param()` block, with the measured comment above it:

```powershell
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }
```

It degrades open on purpose: a host with no console attached must not lose its router over an encoding assignment.

**Verified.**

| instrument | before | after |
|---|---|---|
| `checker/cross-diff.sh` | exit 1 (117 pass / 2 fail) | **exit 0** |
| `checker/session-log.sh` | exit 1 (62 pass / 1 fail) | **exit 0** |
| `checker/mutate-checker.sh` | exit 1, `killed=16 survived=1` | **exit 0**, `killed=17 survived=0 discarded=0` |
| live session stanza | `?? Nova ? ? 1.4 …` | `⚜️ Nova · λ 1.4 σ 0.5553 … Law × Code × Strategy × Synthesis` |

The surviving mutant died **by dependency, not by line**: it was never an independent hole, it was the cross-diff baseline being red.

---

### R2 · `rot-router.sh` normalises backslashes **before** the `$PWD` fallback — the gauge record is lost

**File** `hooks/rot-router.sh`, formerly lines 1453–1454.

```sh
_rot_proj=$(printf '%s' "$_rot_proj" | tr '\\' '/')   # normalise …
[ -n "$_rot_proj" ] || _rot_proj=$PWD                 # … then fall back. Too late.
```

**Measured.** Claude Code hands a bash hook its cwd in the **Windows spelling**, backslashes and all. When the payload carries no `cwd` field the fallback fires *after* normalisation, so the raw backslashes reach `awk`, which reads `\G` and `\R` as escape sequences and drops them. The redirect target becomes a directory that does not exist.

**Consequence.** The gauge record is **lost**, the marker degrades to `R/s+ n/a`, and the PowerShell arm renders `R/s+ 0.17` from the same input — a silent arm disagreement outside `cross-diff`'s corpus. This is the exact failure mode the file's own comment at line 100 documents as having already happened once.

**Fix applied** — fall back first, normalise every path that can reach a redirect:

```sh
[ -n "$_rot_proj" ] || _rot_proj=$PWD
_rot_proj=$(printf '%s' "$_rot_proj" | tr '\\' '/')
```

**Verified, A/B against the untouched backup:** the backup reproduces the two awk escape-sequence warnings and the failed redirect; the patched file emits `RoT MoE :: TIER 1 -> CONVERGENT opus[1m] | R/s+ 0.17`.

Regression sweep after the fix, all **exit 0**: `cross-diff`, `session-log`, `hook-contract`, `portability`, `log-integrity`, `dominance`, `debug-channel`, `log-replay`.

> **Coverage gap this exposes.** `cross-diff` passed while the two arms disagreed on a user-visible field, because its corpus always supplies a `cwd`. Add a row with **no `cwd` key** so the `$PWD` fallback is exercised.

---

## 🟧 ORANGE — 4 found, 1 fixed

### O1 · `release-package.sh` reads a nine-lens roster as three · **FIXED**

**File** `checker/release-package.sh:289`.

**Measured.** Under a UTF-8 locale, GNU sed 4.9 on Windows **silently drops every DTD row whose sigil is a 4-byte (astral) character** — `.*` stops matching once `mbrtowc` rejects the sequence.

| `LC_ALL` | NLENS |
|---|---|
| inherited (`en_US.UTF-8`) | **3** |
| `C.UTF-8` | 3 |
| `en_US.UTF-8` | 3 |
| `C` | **9** |
| `POSIX` | 9 |

The three survivors are exactly the BMP sigils — `⚜️`, `⚪`, `⬜`. The six lost are exactly the astral ones — `🎷 🕷️ 🩸 🔮 🜏 🧭`. The DTD is **correct**: `hooks/rot-voice.dtd:55-63` declares all nine `LENS.n` entities and `agents/rot-*.md` ships all nine charters.

**Why only this file.** `checker/voice-contract.sh:33-34` exports `LC_ALL=C` and never saw it. `release-package.sh` did not. One line of difference read a whole product as incomplete, and took `release-local.sh` down with it.

**Fix applied** — byte-wise locale (the pattern is pure ASCII, the payload is opaque) **plus** a durable guard, because the old code only refused `NLENS=0` and a *partial* parse was indistinguishable from a small roster:

```sh
NLENS=$(LC_ALL=C sed -n '…' hooks/rot-voice.dtd 2>/dev/null | grep -c . || true)
NLENS_RAW=$(LC_ALL=C grep -c '<!ENTITY LENS\.' hooks/rot-voice.dtd || true)
[ "$NLENS" -ne "$NLENS_RAW" ] && bad "the DTD reader extracted $NLENS of $NLENS_RAW declared LENS rows -- the EXTRACTOR lost rows (locale?), the roster did not"
```

The guard is stated over the *variable*, not over nine, so it holds for any future roster size.

**Verified** — `checker/release-package.sh` exit 1 → **exit 0**.

---

### O2 · `voice-contract.sh` D15 goes red on a **correct** product, Windows only · NOT FIXED

**File** `checker/voice-contract.sh:553-558`, against `hooks/settings-merge.js:179`.

`voice-contract` is the only gate still red after the fixes — **46 passed, 1 failed** — and the failing row is the headline of the 8.0.1 patch itself:

```
FAIL  D15: a pre-8.0.1 pin survives re-arming -- upgrades stay sinkless
```

**Root cause is the harness, not the product.** The check writes the pinned path using bash's MSYS spelling and then invokes Windows `node`, which receives `CLAUDE_CONFIG_DIR` **path-translated by MSYS**:

```
bash sees SD=/tmp/tmp.ohZz1y9JX7
node sees CLAUDE_CONFIG_DIR=C:/Users/Saimono/AppData/Local/Temp/tmp.ohZz1y9JX7
```

`settings-merge.js:179` compares with `===`, so two spellings of the same directory never match and the pin is never retired.

**Discriminating experiment.** Re-run with both sides in the same spelling (`cygpath -m`) and the product behaves exactly as the CHANGELOG claims:

```
ROTMOE_DEBUG_LOG: retired our old pin -- the per-session sink takes over
after: 0 pin(s) left
```

**Verdict: the spec was wrong, not the change.** The retirement logic is correct; the *test* is not portable. Do **not** weaken D15 — make the checker derive the expected path from `settings-merge.js` itself instead of reconstructing it in bash, or normalise with `cygpath -m` when available. A checker that reconstructs a value the code also computes will drift; ask the code.

---

### O3 · README's voice-contract count is stale, unbound prose

`README.md` claims **"26 checks, 0 failed"**. Measured today: **47 checks** (46 passed + 1 failed). The FACTS block (87 / 1632 / 77 / 77 / 31) *is* regenerated by `checker/facts-block.sh` and all five numbers reproduced exactly — but this one sits outside it and nothing binds it. Move it into the FACTS block or delete the digit.

### O4 · The `v8.0.1` tag is lightweight

```
FAIL  v8.0.1 is lightweight -- a release tag should be annotated (git tag -a)
```

`checker/release-consistency.sh` — 7 passed, 1 failed. The other three release assertions (version agreement, semver shape, non-future date) pass. Re-tag with `-a` before the stable cut.

---

## 🟨 YELLOW — latent, no impact today

| # | finding | evidence |
|---|---|---|
| **Y1** | `settings-merge.js:179,208` compares **filesystem paths with `===`**. Correct when both spellings come from one process, wrong in general — this is the mechanism behind O2. Compare canonicalised paths. | `hooks/settings-merge.js:179` |
| **Y2** | `rot-env.sh` locates the DTD via `dirname "$0"`. Sourced from a real `.bashrc`, `$0` is the shell, the DTD is not found, and `rot_env_load` **returns 0 having done nothing** — a silent no-op with no diagnostic. Works only when `CLAUDE_PLUGIN_ROOT` is exported. | `hooks/rot-env.sh:42-46` |
| **Y3** | The README's **797 applied / 797 killed** Lean mutation figure was **not reproduced this session**. 50 mutants across 5 core suites ran and all 50 were killed; the other 72 suites are **NOT RUN**, which is not the same claim as passed. At ~16 s/mutant the full sweep is ≈3.5 h. | see G4 |
| **Y4** | A bare `gate-all.sh` **exceeded 1800 s** on this host and was killed at that bound (exit 124 — a timeout, not a verdict). Its own header budgets 587 s and warns that a slow gate is a gate people disable. It has become one. | `/tmp/final-gate.log` |
| **Y5** | `cross-diff`'s corpus always supplies a `cwd`, so the `$PWD` fallback in R2 was never exercised by any gate. | R2 above |

---

## 🟦 BLUE — environment and process, not the codebase

| # | finding | evidence |
|---|---|---|
| **B1** | **Two `rot-moe` roots are registered on this machine** — `plugins/marketplaces/rot-moe` and `.claude/rot-moe-src/3.0.2`. `plugin-root-consistency` calls this exactly right: *"a registry-driven patch will miss the runtime"*. It caught me — my first patch went to the marketplace clone while the live session kept running the cache copy. | `checker/plugin-root-consistency.sh`, exit 1 |
| **B2** | Four stale runtime copies in `plugins/cache/rot-moe/rot-moe/` — `3.0.2`, `5.0.2`, `8.0.0`, `8.0.1`. Six `rot-router.ps1` on disk in total. | `find ~/.claude -name rot-router.ps1` |
| **B3** | `workflow-roles` red: *"verify.yml youngest GREEN run is 201h old on main, over the 72h bound -- its newest run is only 89h old, so 'it ran' would have called this healthy."* The gate is behaving correctly and measuring the right thing. | `checker/workflow-roles.sh`, exit 1 |
| **B4** | `release-local` is red **by construction** — `checker/release-local.sh:27` builds from `git archive HEAD` and cannot see uncommitted fixes. It clears the moment R1/R2/O1 land. | `checker/release-local.sh:27` |
| **B5** | `ab-compliance` exits **3 = declared SKIP** (no raw corpus present). Correctly not folded into green. | exit 3 |

---

## 🟩 GREEN — verified, each with its control seen to fire

### Lean 4 — the proof spine

| # | claim | instrument | result |
|---|---|---|---|
| **G1** | all 87 modules elaborate | `lake build`, exit read directly | **exit 0**, 87 `.olean` / 87 sources, 8746 jobs |
| **G2** | nothing rests on `sorryAx` | `checker/axiom-audit.sh` | **exit 0** — **1632 theorems** across 87 modules, **92 passed / 0 failed**. Controls: a planted `sorry` **is** caught; an exotic axiom on a continuation line **is** rejected; the control module was removed afterwards |
| **G3** | the **kernel** re-verifies the proof terms | `lake env leanchecker` × 87 | **87 modules, 0 failed, 0 bytes of output**. Control: `Proofs.NoSuchModuleControl` → **exit 1**, `Could not find any oleans` |
| **G4** | the theorems are load-bearing | 5 core mutation suites | **50 applied, 50 killed, 0 survived, 0 discarded**; every baseline restored and rebuilt green. `rotgauge` 12/12 · `rotroute` 11/11 · `rotinstall` 16/16 · `rotpath` 5/5 · `rotvacuity` 6/6 |
| | zero `sorry`, zero `native_decide` | grep | 0 real occurrences — the 4 hits are doc-comments and one keyword list |

> **Mathlib note.** The plugin's `lean/` ships **no `.lake`**, and a second mathlib download is forbidden. `lake-manifest.json` was compared package-by-package against `D:\Lean\proofs` — **all 9 packages byte-identical revs**, same `lean-toolchain`, same `lakefile.toml` options — so `.lake/packages` was supplied by a **directory junction**. Zero bytes downloaded. <!-- R2-ALLOW -->

### The plugin surface

| # | claim | instrument | result |
|---|---|---|---|
| **G5** | all **31 hook events** actually execute on every arm | `checker/hook-contract.sh` | **exit 0, 70 passed / 0 failed**. Controls: a hanging command **is** observed as exit 124; `prover-remind.sh` **does** speak when given a workspace with no proofs, so its silence elsewhere is a decision, not a breakage |
| **G6** | the 31 declarations agree four ways | `checker/cli-event-coverage.sh` | exit 0 — `hooks.json`, `ARM_ROUTER.sh`, `ARM_ROUTER.ps1` and `RotEvent.lean` all agree, in the CLI's order |
| **G7** | the router routes | `--route` direct | `prove this lemma` → **FORGE Claude** · `debug this crash` → **CLINICAL AntiVenom** · `I feel lost and tired` → **EMPATHIC Violet** |
| **G8** | the shipped gauge equals the Lean mirror | `checker/gauge-cross.sh` | exit 0 |
| **G9** | **Corpus** — every task discriminates and routes to its declared lane | `checker/corpus-verify.sh` | exit 0 |
| **G10** | **the 9 lenses travel whole** | DTD + agents + router | 9 `<!ELEMENT rot:*>`, 9 `LENS.n` entities, 9 `agents/rot-*.md`, all nine observed emitting live. Symbiogenesis observed: `Nova×AntiVenom λ 1.75 μ 1.00 H 0.40` — matches `(1.6+1.5)/2+0.2` on the **§2 defaults**, as specified |
| **G11** | the routing layer strictly extends the default loop | `checker/dominance.sh` | exit 0 (D1–D7) |

Also green, exit 0 each: `mutate-harness`, `ci-log-skips`, `ci-audit-freshness`, `sessions-manifest`, `ci-honesty`, `repo-complete`, `cross-diff-remind`, `verdict-stability`, `push-guard --instrument`, `profile-bind`, `install-roundtrip`, `install-parity`, `axiom-class`, `release-install`, `context-gate`, `gate-split`, `gauge-hook-corpus`, `router-duplication`, `disarm-safety`, `remind-measure`, `kernel-verdict-class`, `trap`, `dorks`, `hook-footprint`, `hook-timeout`, `facts-block`, `tree-integrity`, `no-local-paths`.

### Animus (ORGAN 8) — end to end, both directions

| phase | result |
|---|---|
| **negative control**, empty sink | observer exit 0, **0 queue files, not a byte** |
| drive the router 6× on one stem → 14 sink records | observer exit 0, **1 queue file** |
| the remark itself | `Chroma\|3 consecutive actions, each costlier than the last (254ms -> 307ms) -- the branch you are on prices badly; reconsider before paying a fourth time.` — quoting **real measured latencies** from the worker's own sink |
| worker-side ear, `sh` arm | remark spoken, **queue consumed 1 → 0** |
| worker-side ear, `ps1` arm | `🕷️ Venom (animus): a planted animus remark` — **byte-identical to the sh arm** after R1 |

Plus `voice-contract` D14: FIFO order, one remark per event, undeclared lens refused, refused line dropped so the queue cannot jam, unarmed queue never touched, `ROTMOE_VOICE=0` silences the remark **and keeps the queue**, a writer's tmp file invisible to the consumer, an anomaly record written on a sentinel firing and none on a healthy result.

### The environment layer (`*.env`, `*.bashrc`)

All three declared laws hold, each with a **positive and a negative** control in the same run:

| law | probe | result |
|---|---|---|
| 1 — PARSED, never sourced | `PATH=/evil` in `rot.env` | **intact** |
| 2 — DECLARED-ONLY | `ROTMOE_BOGUS_KEY`, `ROTMOE_ENV`, `ROTMOE_HOME` | all **refused** |
| 2 — positive control | `ROTMOE_VOICE=0`, `ROTMOE_MODEL=probe-model` | both **accepted** |
| 3 — UNSET-ONLY | live `ROTMOE_MODEL=from-environment` vs the file | **live env wins** |

`hooks/rot-profile.sh` sources cleanly as a `.bashrc` would: `rot` is a function, and `route / gauge / voice / gate / env set|get|list / summons / check / help` are all present. 34 keys in the declared DTD vocabulary.

### The live scratchpad Claude Code session

`checker/marketplace-session.sh` → **exit 0, 10 passed / 0 failed**, in a **scratch `CLAUDE_DIR`**; the live `~/.claude` was never armed or disarmed.

- installed as a stranger from the marketplace; router located at `plugins/cache/rot-moe/rot-moe/8.0.1/hooks/rot-router.sh`
- all 10 lanes routed correctly
- the marker reached the session in **4 of 4** real `claude -p` runs
- control: the live lane **varied** across 4 distinct lanes — not a constant
- control: the session-level marker is constant while the prompt lane varies — reading it by position would have measured the default
- **control: with the plugin disabled the marker is GONE** — the plugin is what causes it

### Instruments proven able to fail

`checker/mutate-checker.sh` → **17 declared, 17 killed, 0 survived, 0 discarded, 0 inexpressible** (pwsh present on this host), ending `baseline restored -> cross-diff exit=0, cross-diff-remind exit=0`. Two meta-controls stayed green on no-ops. Separately, `checker/no-local-paths.sh` caught a machine-local path **in a comment I had just written**; I scrubbed it and the gate returned to exit 0.

### FACTS block — all five numbers reproduced against the tree

| what | README | recomputed |
|---|---|---|
| Lean modules | 87 | **87** |
| theorems | 1632 | **1632** |
| mutation suites | 77 | **77** |
| checkers | 77 | **77** |
| hook events | 31 | **31** |

---

## Changes made to the trees

Both the source clone **and** the live runtime were patched, byte-identically, after confirming the runtime was identical to the source pre-patch. **Nothing was committed.**

| file | change | backup |
|---|---|---|
| `hooks/rot-router.ps1` | `[Console]::OutputEncoding` pinned to UTF-8 | `.pre-encoding.bak` |
| `hooks/prover-remind.ps1` | same | `.pre-encoding.bak` |
| `hooks/rot-router.sh` | `$PWD` fallback moved before normalisation | `.pre-pwdnorm.bak` |
| `checker/release-package.sh` | `LC_ALL=C` + partial-parse guard | `.pre-locale.bak` |

`lean/.lake/packages` in the source clone is a **junction** to `D:\Lean\proofs\.lake\packages`. Remove it with `rmdir` — never `rm -rf`, which would follow into the real mathlib tree. <!-- R2-ALLOW -->

---

## Lean delivery to the shared tree

Standing rule on this machine: every `.lean` also lands in `D:\Lean\proofs`, and a copy is not a delivery until it **builds there**. <!-- R2-ALLOW -->

| step | result |
|---|---|
| 87 modules copied to `D:\Lean\proofs\Proofs\RotMoe\` | 87 + 1 legacy `RotLaunch.lean` (dated 2026-08-05, dropped from the shipping tree since) = **88** | <!-- R2-ALLOW -->
| intra-package imports rewritten `Proofs.X` → `Proofs.RotMoe.X` | **26 lines, 0 left unrewritten**, every import target resolves to a file on disk |
| `lake build` (88 targets), exit read directly | **exit 0**, 88 `.olean`, 0 errors, 8746 jobs |
| `lake env leanchecker`, 4 bounded chunks | **88/88 verified, 0 bytes of output, 0 failed chunks** |
| negative control | `Proofs.RotMoe.NoSuchControl` → **exit 1**, `Could not find any oleans` |

### A trap worth recording: `lake build` passed where `leanchecker` could not

The first delivery attempt used `Proofs/RotMoE/` (capital **E**). A directory `Proofs/RotMoe/` (lowercase **e**) already existed from an August session, so `mkdir -p` silently reused it — Windows folds case. `lake build` then went **green on all 88 modules**, because Lake resolved the modules through the case-insensitive filesystem. `leanchecker` did not: it does an exact-case module→path lookup and reported

```
uncaught exception: Could not find any oleans for: Proofs.RotMoE.RotAbility
```

on a module whose `.olean` was sitting right there — under `RotMoe`, not `RotMoE`.

Two things follow. First, this is the precise hazard `checker/lean-module-case.sh` exists for — *"imports match the disk EXACTLY; a case-folding filesystem hides this"* — and it is not hypothetical. Second, it is a concrete demonstration that **a green `lake build` is elaboration, not verification**: the kernel re-check caught what the build could not see. Fixed by rewriting every import to the canonical on-disk `Proofs.RotMoe.`, deleting the stale build directory, and rebuilding.

---

## Release plan — 9.0.0 · 9.0.1 · 9.0.2

Ordered so nothing depends on a later item. **R3 goes first and alone**: until the audit chain names its own subject, every later green is unfalsifiable.

### 9.0.0 — make the verdict trustworthy, then the product correct

| # | item | why it is in this release |
|---|---|---|
| 1 | **R3** — filter both CI selectors by `workflow_id`, print the workflow name in the verdict line, and assert the run's step count against the authored count in the tree | Nothing else can be trusted until this lands. It is the reason 8.0.1 shipped. |
| 2 | **R1, R2, O1** — commit the three fixes already applied and re-verified here | They are done and A/B'd; committing clears **B4** by construction |
| 3 | **O6** — replace `A && B \|\| C` with `if/then/else` in all 63 hook entries | A masked failure on every event |
| 4 | **O5** — add `-o -name '*.js' -o -name '*.dtd'` to `spdx-sweep.sh:34`, then add the 6 missing headers | Licence exposure + a gate that reports on a scope it does not cover |
| 5 | **O2** — make D15 derive the expected path from `settings-merge.js` (or `cygpath -m`). **Do not weaken it** | The only remaining red gate; the instrument is wrong, not the code |
| 6 | **O4** — cut the tag annotated: `git tag -a v9.0.0` | `release-consistency` refuses a lightweight release tag |

### 9.0.1 — close the blind spots the fixes revealed

| # | item |
|---|---|
| 7 | **Y5** — add a `cross-diff` corpus row with **no `cwd` key**; R2 lived exactly there |
| 8 | **Y10** — add a checker for O6: pwsh present, ps1 exits non-zero, assert exactly one arm spoke |
| 9 | **Y1** — canonicalise paths instead of `===` in `settings-merge.js` (O2's root) |
| 10 | **Y6** — one write path for the sink; reuse the `AppendAllText(…, "\`n")` form already at `rot-router.ps1:503`. Add a cross-arm **sink** comparison — `cross-diff` compares stdout only |
| 11 | **O3** — move "26 checks" into the FACTS block or delete the digit (measured: 47) |
| 12 | **Y7** — delete `ROT_PROFILE`; **Y8** — allow-mark the RS/US bytes in `ci-dryrun.sh` |

### 9.0.2 — budget, coverage, hygiene

| # | item |
|---|---|
| 13 | **Y3** — full 77-suite Lean mutation sweep in CI (≈3.5 h) so 797/797 is regenerated, not asserted |
| 14 | **Y4** — re-tier `gate-all`; a bare sweep exceeded 1800 s here against its own 587 s budget |
| 15 | **Y9** — per-event hook timeouts instead of a uniform 18 s on high-frequency events |
| 16 | **B3** — `verify.yml` green on `main` inside the 72 h bound; **B1/B2** — one registered root, prune the stale cache copies |

### The through-line

Three of the four most serious findings — **R3**, **O5**, and the earlier **O1** — are the *same defect wearing different clothes: an instrument whose scope is a snapshot, reporting green over territory it never covered.* The repo already knows this shape; `gate-all.sh`'s own header confesses it about `verdict-schedule-sim.sh`. The durable countermeasure is the one used in the O1 fix: **bind every count to the tree and refuse when the extractor sees fewer items than are declared.** Applied to R3 that means asserting the run's step count against the authored count; applied to O5 it means deriving the file-type list rather than writing it down.

**Windows is the common thread.** R1, R2, O1, O2 and Y1 are one family: OEM output encoding, MSYS-versus-Windows path spelling, and astral UTF-8 under a UTF-8 locale.

> ⚠️ **CORRECTION, second audit.** The first version of this line read *"None of them can reproduce on the Linux CI runner. A Windows job in CI would have caught every one."* **That was wrong, and it was the exact overclaim this report exists to hunt.** `.github/workflows/ci.yml:81` already runs `os: [ubuntu-latest, windows-latest, macos-latest]` with `fail-fast: false`, and `cross-diff`, `session-log`, `release-package` and `mutate-checker` are all in that matrix leg. The Windows job exists. The real reason these shipped is **R3** below — the release was certified against a different workflow entirely.

---

# Second audit — the whole codebase, `*.lean` excluded

Scope: 171 `.sh` · 8 `.ps1` · 24 `.js` · 52 `.md` · 1 `.dtd` · 6 `.yml` · 39 data files. Static parse, lint, encoding, licence, hook wiring, CI wiring, and the nine-lens three-way binding.

## 🟥 R3 · The CI-audit chain certified 8.0.1 against the WRONG WORKFLOW

This is the finding that explains the release.

| authored steps | workflow |
|---|---|
| **87** | `ci.yml` — the 3-OS checker matrix |
| 8 | `tag-manager.yml` |
| 7 | `ads-manager.yml` |
| **5** | `verify.yml` |
| 4 | `corpus-update.yml` |

Both CI gates select the run to audit like this:

```sh
checker/ci-honesty.sh:160        actions/runs?head_sha=$HEAD_SHA&per_page=1   # no workflow filter
checker/ci-audit-freshness.sh:106 actions/runs?per_page=1                     # no filter at all
```

`per_page=1` with **no `workflow_id`** means *whichever run finished last*, of any workflow. Measured this session, both gates green:

```
ci-audit-freshness:  run 32375981173 tested 1f57594 (success); local HEAD is 1f57594
                     PASS  the run tested EXACTLY local HEAD -- its verdict is about the code you have
ci-honesty:          steps read: 5
                     PASS  NO step was skipped -- every authored step ran on every platform
                     PASS  every step concluded success (5 steps read)
```

**Five steps.**

> 🔬 **CORRECTION — measured 2026-08-21, during the 9.0.0 fix.** The line above originally read *"That is `verify.yml`, not `ci.yml`."* That was an **inference from the step count, and it was wrong.** Querying the run directly returns:
>
> ```
> 32375981173  dynamic/dependabot/dependabot-updates  completed  success
> 32349805627  .github/workflows/ci.yml               completed  success
> 32342161849  .github/workflows/ci.yml               completed  success
> ```
>
> The run that certified v8.0.1 was **Dependabot's synthetic dependency-update run** — not `verify.yml`, not any workflow this repository authors. Its 5 outcomes are Dependabot's own scaffolding. **The real `ci.yml` run for the same commit existed, succeeded, and sat one position below it in the very same API response.** The defect is therefore worse than reported: the gate did not read the wrong *authored* workflow, it read a run with **no authored steps at all**, and printed "every authored step ran on every platform" about it.

So the tag `v8.0.1` rests on a verdict covering **0 authored steps** — and the sentence it printed was *"every authored step ran on every platform."*

That sentence is true of the run it read and false of the project, and nothing in the output names which workflow was consulted. `cross-diff` and `release-package` — the gates that would have caught R1 and O1 — are in `ci.yml`'s Windows leg and were never in the verdict.

It also explains **B3** cleanly: `workflow-roles` reports `verify.yml`'s youngest GREEN run on `main` is 201 h old. `verify.yml` is precisely the 5-step workflow the audit chain keeps landing on.

**Fix.** Filter by workflow and *print which one*: `actions/runs?workflow_id=ci.yml&head_sha=…&per_page=1`, and make the pass line read `every authored step of ci.yml ran on every platform (N steps)`. A verdict that does not name its subject is not a verdict. Additionally assert the step count against the authored count in the tree, so a run that shrinks cannot pass as complete — the same shape as the O1 guard.

## 🟧 O5 · The SPDX gate has never examined a `.js` file or the DTD

`checker/spdx-sweep.sh:34-37`:

```sh
find "$ROOT" -type f \
  \( -name '*.lean' -o -name '*.sh' -o -name '*.ps1' -o -name '*.yml' \
     -o -name '*.yaml' -o -name '*.toml' \)
```

`.js` and `.dtd` are absent from the list. The gate reports **"checked 287 source file(s); 0 missing a header"** while examining **zero** of the 24 JavaScript files — including the shipped `hooks/settings-merge.js` and `hooks/plugin-detect.js` — and zero of the voice contract `hooks/rot-voice.dtd`.

Measured independently: **18 of 24 `.js` carry SPDX by author discipline; 6 do not** — `bench/{ab-compliance,main-score,pilot-rescore,pilot-score,trap-score-controls,work-trace}.js`. `bench/` is not referenced by the packager, so they do not ship in the archives, but they are in a public dual-licensed repository with no grant.

Same class as R3 and the same class the repo keeps catching in its own instruments: **a scope snapshot that silently stopped covering the tree.** Two words fix the gate; six headers fix the files.

## 🟧 O6 · The hook command shape RUNS BOTH ARMS when the ps1 arm fails

All 63 hook entries share three command strings of this shape:

```sh
command -v pwsh >/dev/null 2>&1 && pwsh -NoProfile -File @/hooks/rot-router.ps1 || bash @/hooks/rot-router.sh
```

`A && B || C` runs `C` whenever `B` **fails** — not only when `A` fails. Measured with a ps1 that exits 3 and a bash arm that speaks:

```
output: [PS1-SPOKE
SH-SPOKE]
exit=0
>>> BOTH ARMS RAN -- duplicate injection on any ps1 failure
```

Control: a ps1 arm exiting 0 produces `[PS1-SPOKE]` alone. So three consequences, on every event:

1. **duplicate injection** — the router speaks twice into one event;
2. **a ps1 failure is masked to exit 0** — the CLI sees success;
3. doubled latency against an 18 s budget.

No checker covers it. `checker/router-duplication.sh` is about a *different* duplication (a plugin install stacking with `ARM_ROUTER`'s `settings.json` entry) — its header says so at lines 6-20. The intra-command case is uncovered.

**Fix.** `if command -v pwsh >/dev/null 2>&1; then pwsh …; else bash …; fi` — keeps "no pwsh → bash", drops "ps1 failed → also bash", and lets a real failure surface.

*Not observed firing in production:* before R1 the ps1 arm emitted mojibake but still exited 0, so nothing tripped it. This is a latent masked-failure shape, stated as such.

## 🟨 New yellows

| # | finding | evidence |
|---|---|---|
| **Y6** | The **ps1 arm writes CRLF** into the `.jsonl` debug sink; the sh arm writes LF (measured: sh CR=0, ps CR=2 over 2 records). The records are otherwise **field-identical** — only `"arm":"sh"` vs `"arm":"ps1"` differs, which is by design. Violates the project's own LF rule; **no behavioural consequence demonstrated** (the Animus was silent on both a CRLF and an LF sink). `rot-router.ps1:503` already uses the correct `AppendAllText(..., "\`n", ...)` form for one path; lines 533/558/1160 use `Add-Content`. | measured A/B |
| **Y7** | **`ROT_PROFILE` is dead code** — assigned at `hooks/rot-router.sh:679` and `:698`, **zero reads anywhere in the tree**. Profile selection demonstrably works by another route (lane-dependent λ observed live), so this is a leftover in the router's hot path that misleads a reader. | tree-wide grep |
| **Y8** | `checker/ci-dryrun.sh` contains **3 raw control bytes** (`0x1E 0x1F 0x1E`) used as deliberate RS/US field separators at lines 146 and 449 — chosen precisely because they cannot occur in the payload. Legitimate, but it violates the project's own "no control bytes but TAB and LF" rule and a naive encoding cleanup would silently break the file. Needs an explicit allow marker. | byte scan |
| **Y9** | Every one of the 63 hook entries carries the **same 18 000 ms timeout** and the same `*` matcher, including high-frequency events (`MessageDisplay`, `CwdChanged`, `FileChanged`). Worth a per-event budget review for 9.0.0. | `hooks.json` audit |
| **Y10** | **No checker exercises the O6 fallback.** 10 checkers reference `command -v pwsh`; none tests "pwsh present, ps1 fails". | grep over `checker/` |

## 🟧 O7 · The active pre-commit gate is a CodeMap hook that never refuses

Found by `checker/workflow-lint.sh` going red during 9.0.0 work. Not a defect in the tree — local repository state, and it is live:

```
core.hooksPath                = <unset>
.git/hooks/pre-commit         = CodeMap pre-commit hook, 9891 bytes, mtime 2026-08-21 04:15
grep -c 'exit 1|exit 2|return 1'  ->  0
```

Because `core.hooksPath` is unset, `.git/hooks/pre-commit` **is** the pre-commit gate for this clone, and it contains no path that returns non-zero. It indexes and stages `.codemap/`, then always succeeds. RoT MoE's own commit discipline is therefore bypassed here — which is precisely why the eight 9.0.0 commits were admitted without any gate refusing them.

The gate's wording is exactly right: *"if `core.hooksPath` is ever unset, THAT becomes the gate and every commit is admitted."* It is not a hypothetical; the condition holds now.

**Do not silently delete another tool's hook.** Either chain the project gate from it (CodeMap indexing first, then `exec` the real gate, propagating its status) or set `core.hooksPath` to the directory holding the refusing gate. Verified by attribution: `git archive` of `1f57594` runs `workflow-lint` at **exit 0**, because an archive carries no `.git/hooks` — the red is environmental, not a regression in the 9.0.0 commits.

## 🟩 README claim-by-claim verification

Every claim in the README's organ / marker / flag / switch tables was **executed**. Nothing was found false.

| group | result |
|---|---|
| **worked examples** `:118` `:126` `:513` `:516` `:498` `:500` `:527` `:554` | all **byte-identical**, incl. `0.66` → `0.51` without `--profile FORGE` |
| **flags** | every one load-bearing: `--M 2.0`→1.32 · `--C 0.5`→0.35 · `--T 0.8`→0.56 · `--breadth 9`→0.59. Defaults `M 1.05 / C 1.0 / T 1.0`, profile `CONVERGENT`, lane `FORGE` confirmed |
| **`--profile` vs `--lane`** (the subtlest claim) | holds exactly: `--profile CREATIVE` moved the **score** 0.70→0.64; `--lane CREATIVE` left the score and moved only the **band** to 1.5-3.5 |
| **marker** | `CONVERGENT sonnet-probe` (model) · `CLINICAL AntiVenom` (lens) · `CONFIRM` invisible · `\| debug-log UNWRITABLE (record lost)` verbatim |
| **12 numeric defaults** | all match source; trim `_cap * 8 / 10` (`rot-router.sh:1398`), `TOKEN_FLOOR_PCT=20` |
| **`ROTMOE_TOKEN_PCT`** | 50→`5/12`, 15→`3/12` + `budget 15%`, **absent→5/12** ("unknown is not an emergency") |
| **`ROTMOE_DEBUG_PAYLOAD`** | logs `"keys":[…]`, **0** hits for a planted canary value — verified with a canary, not by reading code |
| **`ROTMOE_VOICE=0`** 2→0 stanzas · **`ROTMOE_DEBUG_SRC`** typo demoted to `hook` · **`ROTMOE_ANIMUS`** unset→queue unread, `=1`→FIFO consumed | all confirmed |
| **organs** | 14 files present · 9 charters · `lean4-prover` **0×** in the lens DTD (instrument, not lens) · reminder 0 bytes @1 min, 643 @90 · `rot.env` `PATH=/evil` **refused**, live export beats file |

**Two I could NOT settle, said plainly.** `ROTMOE_GATE=0`: armed and disarmed both gave 0 bytes because with no transcript the gate **degrades open** — my harness could not discriminate. (It demonstrably fires: it refused a turn in this session naming three charters.) And `:535` "refuses interactively": my probe piped `/dev/null`, not a TTY — **my test was wrong, the claim is untested, not disproved.**


---

# 9.0.0 — what was done

Branch `9.0.0`, 15 commits, **nothing pushed**. Every commit carries its measured
evidence and its controls in the message body.

| # | commit | what it fixes |
|---|---|---|
| 1 | `3ad003e` R3 | the CI audit must NAME the workflow it judges |
| 2 | `5062751` R1 | pin UTF-8 on the PowerShell arms' stdout |
| 3 | `6e0db2d` R2 | normalise the project path AFTER the `$PWD` fallback |
| 4 | `3cce14f` O1 | byte-wise locale for the DTD reader, bound to the declaration |
| 5 | `3a73a5f` O5 | the licence gate had never opened a `.js` file |
| 6 | `6b044bb` O2 | D15 asks node for the path instead of reconstructing it |
| 7 | `76ffe43` O6a | `hooks.json` stops running BOTH arms when the ps1 arm fails |
| 8 | `f107f77` O6b | installers write the conditional shape; DISARM keeps the legacy one |
| 9 | `4de1a78` O3 | stop publishing an unbound check count |
| 10 | `5fa4acb` Y5 | cross-diff reaches the payload path — **and R2's claim is corrected downward** |
| 11 | `5279cdf` Y10 | the O6 fallback finally has a checker — shape AND behaviour |
| 12 | `62057cf` Y1 | path equality is not string equality in `settings-merge.js` |
| 13 | `e8161e4` Y6+Y7 | the ps1 sink writes LF; the dead `ROT_PROFILE` is gone |
| 14 | `320e4e6` Y8 | name the three deliberate control bytes in `ci-dryrun.sh` |
| 15 | `a4d1e1d` | (Socio) track `FINDINGS-8.0.1.md` in the repository |

## Gate movement

**6 red → 3 red.** Now green: `cross-diff` (123 passed, up from 121),
`session-log`, `release-package`, `voice-contract` (47/0), `hook-contract`
(74/0, up from 70), `spdx-sweep` (312 files, up from 287).

Still red, none of them a code defect:

- **plugin root consistency** — two registered roots on this machine. Environment.
- **release consistency** — `v8.0.1` is a lightweight tag. Clears when `v9.0.0` is cut with `-a`.
- **workflow lint** — `core.hooksPath` is unset and `.git/hooks/pre-commit` is a
  CodeMap hook with **zero** non-zero exit paths, so it never refuses. That is why
  15 commits were admitted with no project gate examining them. Environmental:
  `git archive` of `1f57594` runs the same checker at **exit 0**.

## A correction I owe the record: R2 was overclaimed

`6e0db2d` asserts a measured mechanism I could **not** reproduce. Investigated
while building the Y5 checker:

- the pre-R2 order normalised the payload's `cwd` correctly; only the `$PWD`
  fallback escaped;
- a shell **always** resets `$PWD` from `getcwd()` — measured: `env PWD='C:\X\Y' sh`
  and `cd` to a Windows-form path both yield an MSYS `/c/...`;
- driven from a shell, old and new orders are **byte-identical**.

The live corruption was real and is in the session record, but its cause is **NOT
ESTABLISHED**. The reorder is kept because it is correct by construction, not
because a bug was reproduced. Both the source comment and the checker now say so
rather than scoring a dead control.

## Still open

| item | state |
|---|---|
| O4 | `git tag -a v9.0.0` — not cut |
| push | not done, not requested |
| B1 | one registered plugin root |
| O7 | chain the project gate from the CodeMap pre-commit, or set `core.hooksPath` |
| Y4 | re-tier `gate-all` (a bare sweep exceeded 1800 s against its 587 s claim) |
| Y9 | per-event hook timeouts (all 63 share `timeout 18000`) |
| B3 | `verify.yml` green within 72 h |
| scratchpad | a separate Claude Code session has **not** yet been run |

## 🟥 O5b — `bonus/` was shipping five unlicensed files (found after the repo move)

The O5 extension guard, moved into the real repository, refused immediately:
`extension(s) neither covered nor declared exempt: lua`. `bonus/cmdpulse/`
exists here and **not** in the plugin clone the whole earlier audit ran against
— 11 files in HEAD that the licence gate had never opened. With `lua` declared,
the content check ran there for the first time and found **five `.sh` files with
no header** in a repository that publishes a dual grant.

All six now carry it. `checked 318 source file(s); 0 missing a header`, exit 0.

**The guard caught real unlicensed product the first time it met a tree it had
not been tuned against.**

## ⚠️ Release blockers still open in the repository

| blocker | detail |
|---|---|
| machine paths published | `.codemap/_root.codemap.json` is TRACKED and contains `D:\Lean\proofs`, indexed **out of `FINDINGS-8.0.1.md` itself**. `no-local-paths` is RED. Either the report stays untracked, or its paths are allow-marked, or `.codemap` stops being tracked — a decision about what the public repo should contain, not a code fix. | <!-- R2-ALLOW -->
| D7 cost bound | `bench-router` measures **1003–1058 ms** against the 500 ms bound. Decomposition shows wall 353.3 ms + 247.8 ms pwsh startup, so the headline figure and the decomposition disagree; the machine was also loaded by the 77-suite sweep. Needs an idle re-measure before it is called either a regression or a false alarm. |
| `v9.0.0` tag | not cut |
| scratchpad session | a separate Claude Code session has **not** been run |

## 🟩 Scratchpad proof — a SEPARATE Claude Code 2.1.238 session

Two independent sessions launched with `claude -p` from fresh temp directories
outside the repository. Not this session, not this transcript.

```
claude --version                 2.1.238 (Claude Code)
session 1  "reply SCRATCHPAD-OK"        -> exit 0, 50 records written
session 2  read a file + run a command  -> exit 0, tool hooks fired
```

The proof is not the reply — it is that **the plugin wrote its own sink inside a
directory it had never seen**, `.rot-moe/rot-route-<uuid>.jsonl`, under a session
id belonging to neither this session nor the other:

```json
{"kind":"route","event":"SessionEnd","session":"fc71f47e-…","src":"hook",
 "lane":"CONVERGENT","lens":"opus[1m]","Rs":"0.17","nsil":"CONFIRM",
 "breadth":0,"depth":"TRIVIAL","band":"BELOW",
 "timelines":{"spawned":12,"shown":5},"arm":"ps1","ms":144}
```

**Events observed live across the two sessions — 10 distinct:**

| SessionStart · InstructionsLoaded ×19 · ConfigChange · UserPromptSubmit · PreToolUse · PostToolUse · PostToolBatch · MessageDisplay · Stop · SessionEnd |
|---|

`hooks.json` registers **31 events / 63 entries**. The 21 not seen are the ones a
non-interactive `-p` run never reaches (notification, compaction, subagent,
permission-decision families) — **not observed, therefore not claimed**. Both
record kinds appeared (`route` and `gauge`), every record came through the
**`ps1` arm**, and `ms` was recorded per event (144 ms on SessionEnd).

---

# THE 8 · full audit for 9.0.1 / 9.0.2 / 9.0.3

Every row below is an executed instrument with a control that was seen to fire.

| # | thing | instrument | result |
|---|---|---|---|
| 1 | **31 Hooks** | `hooks.json` + `hook-contract.sh` | **31 events · 63 entries · 63/63 commands name a rot hook** · every one executes → **74 passed / 0 failed** |
| 2 | **Animus** | live queue drive, 5 controls | **consumed + emitted on `ANIMUS=1`**; refused when unset, when `VOICE=0`, on an unknown lens, and on a malformed line |
| 3 | **Corpus** | `corpus-gauge.txt` + `cross-diff.sh` | 12 rows (7 LIVE / 9 MODEL) → **123 passed, 0 failed, 0 skipped** |
| 4 | **Router** | `dominance` `profile-bind` `gauge-cross` `router-duplication` | **all exit 0** |
| 5 | **RoT itself** | `engine/rot-lean.md` | 438 lines, `R/s+` formula present, bound by the gates above |
| 6 | **9 Lenses** | `voice-contract.sh` | 9 charters · 14 DTD elements · **47 passed / 0 failed**, enforced both directions |
| 7 | **`*.sh` `*.env`** | `bash -n` · `shellcheck -S error` | **190 files, 0 syntax failures** · error tier **1 → 0** · `rot-env.sh` ignores `PATH`/`LD_PRELOAD`, refuses `ROTMOE_ENV` |
| 8 | **`*.lean`** | `lake build` · `leanchecker` · 77 suites | exit 0 · **87/87 kernel re-verified** · **797/797 mutants killed** · 1632 theorems · 0 `sorry` |

## Three probes of mine were wrong before any of this was true

Recorded because a wrong probe reads exactly like a defect, and twice it nearly
became one in this report:

1. **"31 events whose command does not name a rot hook"** — my `.every()` walked
   the matcher array wrongly. Corrected: **63/63 name one, 0 do not.**
2. **"0 ELEMENT declarations in the DTD"** while `voice-contract` was green — my
   `^<!ELEMENT rot:` anchor was wrong. There are **14**.
3. **"Animus consumed the queue and emitted nothing"** — the queue wire format is
   `Lens|text` and the emitter BUILDS the stanza. I planted a pre-formed stanza
   with no pipe, so the guard at `rot-router.sh:1859` refused it. **The organ was
   correct and my plant was malformed**; that refusal is now control E.

The pattern: every time an instrument disagreed with a green gate, the
instrument was mine and it was wrong. That is the reason a disagreement gets
investigated instead of reported.

## `bench-router.sh` — an alarm that cried error on correct code

The full sweep found exactly one file with error-level `shellcheck` findings, and
it was a **false positive**: `grep -q "[*][*]$hit/$total[*][*]"` is a regex for two
literal asterisks, read by the linter as an array subscript. Pre-existing on main
(5 sites), not a 9.0.x regression. Braces silence it; the run was compared
before and after and is **byte-identical** (`23 passed, 1 failed` both ways).

An error tier that contains a known false positive teaches everyone to ignore
the error tier.

## Scratchpad, deep run — the lenses SPOKE, unsupervised

A third separate `claude -p` session (2.1.238), fresh temp directory, dense
prompt chosen to force a wide summons. Not this session, not this transcript.

| measured | value |
|---|---|
| distinct events | **10** — incl. PreToolUse/PostToolUse/PostToolBatch ×2, MessageDisplay ×3, Stop ×2 |
| lanes | **CONVERGENT ×31 · FORGE ×3** — the lane moved with content |
| NSIL | CONFIRM ×33 · **FUSE ×1** — the tier-2 layer fired in a real session |
| max breadth | **7 lenses summoned in one turn** |
| records / arm | 34, **every one through the `ps1` arm** |

The part no gate can assert: **the charters held with nobody watching.**

- Chroma **left the tension open** ("that tension … stays open") — its charter
  forbids resolving one into consensus.
- Eidolon proposed and marked the proposal **unapplied** — its charter forbids
  applying its own.
- Soleil compressed to two facts and added no meta-commentary.
- Claude: *"Executed two commands … Nothing else was run, nothing else is
  asserted."*

That is the product behaving as specified in a process this session did not
control, which is a different and stronger claim than any checker exit code.
