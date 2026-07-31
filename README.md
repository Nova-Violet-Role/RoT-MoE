<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

# RoT MoE

A Mixture-of-Experts router for [Claude Code](https://claude.com/claude-code):
nine reasoning lenses, a divergence gauge measured off disk on every turn, and
**71 machine-checked theorems in Lean 4** saying the gauge is not decoration.

The standard objection to any engine like this is *the number is made up*. This
repo exists to answer that objection with a kernel rather than with prose.

---

## What is actually verified

| instrument | what it establishes | result |
|---|---|---|
| `lake build Proofs.*` | the modules elaborate | exit **0** |
| `#print axioms` on every theorem | nothing rests on `sorryAx` | **0** `sorryAx` |
| `lake env leanchecker` | Lean's **kernel** re-verifies the proof terms, independently of the elaborator that produced them | exit **0**, zero bytes |
| mutation suite | the theorems are load-bearing | **43 applied, 43 killed, 0 survived, 0 discarded** |

Every one of those has a **negative control** recorded beside it, because an
instrument that has never been seen to fail proves nothing. `leanchecker`
against a module with no oleans exits 1. The SPDX sweep with one tag stripped
exits 1. The path sweep with one planted violation exits 1. If a check cannot
go red on demand, it is decoration and is labelled as such.

Zero `sorry`. No `native_decide` anywhere — it trusts the compiler binary
instead of the kernel, which would quietly undo the point of the whole exercise.

### The five modules

* **`lean/Proofs/RotGauge.lean`** (34 theorems) — the R/s+ gauge.
  `sigma_strictMono`, `gauge_pos`, `gauge_ge_floor`, `gauge_not_constant`,
  `gauge_divisor_eq_card`. The last one is the theorem that would have caught a
  real bug in the shipped hook, where one lens's activity was pinned at zero
  while still dividing the sum by K.
* **`lean/Proofs/RotRoute.lean`** (14 theorems) — the router as a function.
  `route_fires`, `route_covers_every_mode` (no dead lane), `route_exact` (all
  ten lanes characterised in both directions), and the headline
  `nsil_overrides_tier1` — which proves both that the override lands *and* that
  it genuinely differs from the keyword result, the difference between a router
  and an `if`-chain.
* **`lean/Proofs/RotPath.lean`** (8 theorems) — path canonicalisation, written
  *after* a real stranding bug: the two installer arms wrote different command
  strings for one install, and removal matches by exact string, so installing
  from one shell and uninstalling from the other left a dead hook entry forever.
  `both_spellings_agree` proves the Windows and POSIX spellings converge to one
  string, quantified over an arbitrary drive so it does not expire when the repo
  moves. `normalize_idem`, `normalize_posix_id` (a Linux path is never
  rewritten), and `normalize_not_alpha_drive` — which replaced a **false**
  theorem the compiler refused, recorded in the source rather than quietly fixed.
* **`lean/Proofs/RotInstall.lean`** (15 theorems) — arming never disarms you.
  `arm_preserves_all_scalars` and `arm_preserves_unrelated_events`, quantified
  over **all keys**, so your `permissions`, your `env`, and every key not yet
  invented survive. `arm_idempotent`, `arm_appends` (your hooks keep their
  order), `disarm_removes`, `disarm_preserves_others`.
* **`lean/Proofs/RotVacuity.lean`** (0 theorems — deliberately; the content is `example`s)
  — the audit that catches what every other gate certifies. A theorem with
  contradictory hypotheses is *true*, builds green, has clean axioms and passes
  `leanchecker`, while saying nothing at all. This module instantiates every
  hypothesis-carrying theorem in the packet at a **concrete witness**, so a
  green build is a positive statement: each guarded theorem has at least one
  real case it applies to. The gauge witnesses use the **shipping** FORGE
  weights rather than convenient toy values — and `checker/lean-binds-shell.sh`
  fails the build if those numbers ever drift from `hooks/rot-router.sh`.

---

## What Lean does NOT prove here

This section is not modesty. It is the part that makes the rest credible, and
it is deliberately the most specific section in this README.

* **Nothing about output quality.** No theorem says routed reasoning is better,
  smarter, or more correct than unrouted reasoning. That is not a property Lean
  can see. Any such claim in this repo would be an overclaim; if you find one,
  it is a bug and an issue is welcome.
* **`RotGauge` models code that ships. `RotRoute` models a specification.**
  Grepping the shipped hook for the mode names finds them only in a comment and
  in payload text: **TIER 1 keyword routing is not implemented in the PowerShell
  hook.** What ships today is the gauge. `RotRoute.lean` therefore proves things
  about `rot-lean.md` §3, the spec, and the POSIX port has to implement it
  before this project may claim a verified router for *routing* rather than for
  the gauge. This is stated in the module's own docstring, not just here.
* **`RotInstall` sees a map, not a file.** It cannot see a UTF-8 BOM, `\r\n`
  line endings, key ordering, or indentation. A green build means the *merge is
  sound*, never that the *file was written correctly*. Byte-level behaviour is
  `checker/install-roundtrip.sh`'s job, run against a scratch config dir —
  **21 checks, 5 negative controls, and it never opens your real
  `settings.json`.**
* **The installer normalizes JSON layout, and this is measured, not assumed.**
  Your keys, values, order, UTF-8 BOM state and indent *width* all survive
  exactly. What does **not** survive is intra-line layout: a line written as
  `"env": { "A": "b" }` comes back expanded across three lines, because the
  merge round-trips through a JSON parser rather than editing text. On a
  deliberately hostile fixture that measured **678 → 872 bytes** with every
  value identical. On a file already in canonical form — which is what Claude
  Code itself writes — the install/uninstall round trip is **byte-identical**,
  and the checker asserts exactly that as a separate claim rather than folding
  the two together.
* **`disarm ∘ arm` is not the identity in every case, and that is proved.** If
  you had already registered this exact hook command by hand, installing and
  then uninstalling **removes your entry**. `disarm_arm_id` carries the freshness
  hypothesis explicitly and `disarm_arm_not_id` proves the hypothesis cannot be
  dropped. The mitigation is the backup file, which is a byte-level guarantee
  Lean cannot give.
* **`Float ≠ ℝ`.** The `#eval` corpus in `RotGauge` runs a `Float` mirror of the
  real-valued definitions so the spec EXECUTES on concrete inputs. Those rows
  agree with the live hook to two decimals on four vectors. That is **MEASURED,
  not PROVED**, and it is labelled that way in the source.
* **Cross-platform behaviour is untested until CI says otherwise.** The gauge
  ships as PowerShell today.

---

## Licence

Dual: **AGPL-3.0-or-later OR EUPL-1.2**, at your option.

RoT MoE is an original work, so the root `LICENSE` is the verbatim AGPL-3.0
text and GitHub detects the repo as AGPL-3.0. `LICENSE-EUPL-1.2` sits beside
it, `LICENSES/` carries both texts for [REUSE](https://reuse.software/), and
every source file carries

```
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
```

`checker/spdx-sweep.sh` enforces that on every push and fails if one tag goes
missing. See `NOTICE.md` for the full provenance, including what is *not*
covered by this grant.

---

## Install

**Look before you leap.** This installs a hook that runs on every prompt you
submit and before every tool call, by editing `~/.claude/settings.json`. So the
first command is the one that writes nothing:

```sh
bash ARM_ROUTER.sh --dry-run        # pwsh: ARM_ROUTER.ps1 -DryRun
```

That runs the entire merge against a copy and prints exactly what would change.
When you are satisfied:

```sh
bash ARM_ROUTER.sh                  # backs up first, prints the restore command
bash DISARM_ROUTER.sh               # removes only what it installed
```

Or install it as a plugin, with no `settings.json` edit at all:

```sh
claude --plugin-dir /path/to/RoT-MoE
```

Both paths are exercised by `checker/plugin-install.sh`, including from a config
directory with no `settings.json` — the case every first-time user hits.

---

## Verify it yourself

```sh
cd lean
lake exe cache get          # never build mathlib from source
lake build Proofs.RotGauge Proofs.RotRoute Proofs.RotInstall Proofs.RotPath
lake env leanchecker Proofs.RotGauge        # exit 0, zero bytes = kernel pass
lake env leanchecker Proofs.NoSuchModule    # exit 1 = the control
sh ../checker/spdx-sweep.sh
sh ../checker/no-local-paths.sh
bash mutate/mutate_rotroute.sh              # expect 11 killed, 0 survived
bash mutate/mutate_rotpath.sh               # expect  5 killed, 0 survived
bash mutate/mutate_rotvacuity.sh            # expect  6 killed, 0 survived
```

Do not take the counts in this README on faith — the **Ads Manager** workflow
does not either. It recounts the theorems from source on every run and fails
the build if this file disagrees with the sources, or if any sentence here
claims a proof about output *quality*.

---

<!-- TAGS:BEGIN generated from .github/tags.txt [SIGNATURE] -- do not hand-edit -->
**Topics** ·
#MixtureOfExperts #Moe #Router #Lean4 #FormalVerification #TheoremProving
#Mathlib #MachineChecked #ProofEngineering #ClaudeCode #ClaudeCodePlugin
#AiAgents #AgenticWorkflow #LlmTooling #PromptEngineering #Hooks #Powershell
#Bash #Agpl #Eupl #DependentTypes #ProofAssistant #KernelVerified
#MutationTesting #Leanchecker #Sigmoid #EnsembleMethods #ExpertRouting #Plugin
#CliTool #DeveloperTools #StaticAnalysis #Specification #VerifiedSoftware
#Copyleft #ReuseCompliance #Spdx #DualLicensed #FreeSoftware #OpenSource
#NonProfit #Python #C #Compiler #RollingContext #ContextCompression #Anthropic
<!-- TAGS:END -->
