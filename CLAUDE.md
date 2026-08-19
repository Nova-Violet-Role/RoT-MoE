<!--
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# RoT MoE — instructions for the agent installing this

You are reading this because someone cloned this repository and asked you to set
it up. Everything you need is here; you should not have to guess, and you should
not have to search the web.

**Read this whole file before running anything.** It contains two hard limits
and they are not negotiable.

---

## THE TWO LIMITS

1. **Never elevate.** No `sudo`, no admin shell, no system directory, no package
   manager. Nothing in this project needs it. If a step seems to, you have
   misread the step — stop and say so.
2. **Never download without the user saying yes, in this conversation.** The
   plugin itself is a few hundred kilobytes and installs offline. The *optional*
   Lean toolchain is **several gigabytes** (a mathlib build tree measured 7.2 GB
   on the author's machine). Ask, show the number, and wait. `SETUP_LEAN.sh`
   refuses by default precisely so that an over-eager agent cannot skip this.

A third, softer one: **read a script before you run it.** These are short and
commented. If you would not read it, do not run it on someone else's machine.

---

## WHAT THIS IS, IN ONE PARAGRAPH

A Claude Code plugin: a nine-lens Mixture-of-Experts router with a measured
divergence gauge (`R/s+`), specified in Lean 4 and bound to the shipped hooks by
executable checkers. The router and the reminder are plain shell and PowerShell.
**Lean is not required to use it** — only to re-verify the proofs yourself.

Eight organs ship. Organs 1–4 are checked to exist by
`checker/repo-complete.sh`; organs 5–8 are held, in both directions, by
`checker/voice-contract.sh`:

| organ | file | what it does |
|---|---|---|
| 1 | `engine/rot-lean.md` | the engine specification the router implements |
| 2 | `hooks/rot-router.sh` / `.ps1` | the router: TIER 1 routing, the R/s+ gauge, and the voice block |
| 3 | `agents/lean4-prover.md` | the Lean 4 prover head (a subagent — an instrument, not a lens) |
| 4 | `hooks/prover-remind.sh` / `.ps1` | the proof-debt reminder |
| 5 | `hooks/rot-voice.dtd` + nine lens agents, `agents/rot-nova.md` through `agents/rot-claude.md` | the voice contract and the roster it declares |
| 6 | `hooks/rot-voice-gate.sh` / `.ps1` | the voice gate: one refusal per unspoken summons on Stop, degrades open |
| 7 | `hooks/rot-env.sh` / `.ps1` + `hooks/rot-profile.sh` | the environment layer: rot.env parsed under the DTD's declared vocabulary, and the sourceable `rot` command family |
| 8 | `hooks/animus-observe.sh` + `commands/animus.md` | the Animus: a paired observer process that watches a worker session's measured event stream and injects lens remarks mid-run through the router arms' worker-side ear (`ROTMOE_ANIMUS=1`); deterministic, thresholds declared in the DTD |

---

## INSTALL — the whole thing, in order

Run these from the repository root. **Read each exit code directly.** Never
through a pipe: `cmd | tail` reports `tail`'s status, and that has produced a
false green in this very repo.

### Step 0 — verify the tree before trusting it

```sh
bash checker/gate-all.sh
echo "gate-all exit=$?"
```

Exit 0 means every gate is green: completeness, licence headers, no
machine-local paths, both router arms agreeing byte for byte, both reminder arms
agreeing, the mutation suite that breaks the checker on purpose, and the
installer round trip. **If this is not 0, do not install.** Report which gate
failed and stop; a red tree is a finding, not an obstacle to work around.

### Step 1 — install the plugin (offline, seconds, reversible)

POSIX:

```sh
bash ARM_ROUTER.sh
echo "arm exit=$?"
```

Windows:

```powershell
pwsh -NoProfile -File .\ARM_ROUTER.ps1
"arm exit=$LASTEXITCODE"
```

This registers the hooks with Claude Code. It touches the plugin's own
directory and the Claude configuration, and nothing else. To undo it completely:
`bash DISARM_ROUTER.sh` (or `DISARM_ROUTER.ps1`).

### Step 2 — confirm it is actually running

Installed is not running. Ask the user to start a new Claude Code session and
send any message; the router fires on `UserPromptSubmit`. You can also exercise
the hooks directly, which reads nothing from the network:

```sh
bash hooks/rot-router.sh --route "prove this lemma"        # -> FORGE Claude
bash hooks/rot-router.sh --vector 1,0,0,0,0,0,0,0,1 --breadth 2
bash hooks/prover-remind.sh --decide PostToolUse 90 RotGauge - - - 0
```

If `--route` prints a lane and `--decide` prints a reminder, the shipped code
works on this machine.

### Step 3 (OPTIONAL) — Lean, only if the user wants to re-verify the proofs

**Ask first. Show the size. Wait for an answer.**

```sh
bash SETUP_LEAN.sh --dry-run     # prints the plan, creates NOTHING
bash SETUP_LEAN.sh --yes         # only after the user agrees
```

Windows: `pwsh -NoProfile -File .\SETUP_LEAN.ps1 -DryRun` then `-Yes`.

It installs elan into `$ELAN_HOME` (default `~/.elan`), the **pinned** toolchain
from `lean/lean-toolchain`, and the **prebuilt** mathlib cache — never a source
build, which costs hours. `SETUP_LEAN.sh --uninstall` prints exactly what to
remove.

Then, and only then:

```sh
cd lean
lake build Proofs.RotGauge Proofs.RotRoute Proofs.RotInstall Proofs.RotPath Proofs.RotVacuity
echo "lake build exit=$?"
lake env leanchecker Proofs.RotGauge     # the KERNEL's own second opinion
```

CI already does all of this on a clean runner for every commit. Step 3 exists
for the reader who would rather measure than trust — the correct instinct.

---

## IF SOMETHING FAILS

Report the real error text and the real exit code. Do not summarise it as
"there was an issue", and do not work around a red gate by disabling it.

| symptom | what it means |
|---|---|
| `gate-all` red | a real defect in the tree. Name the gate; the logs directory is printed. |
| `cross-diff` red | the two arms disagree — a genuine portability bug, not a flake. |
| `pwsh: not found` | POSIX-only machine. The `.sh` arms are complete; nothing is lost. |
| `lake: not found` | Lean is not installed. Expected — see step 3. Nothing else is affected. |
| a hook prints nothing | for the reminder that is the **healthy** state. It speaks only when there is measured proof debt. |

---

## WHAT YOU MUST NOT DO WHILE INSTALLING THIS

* Do not `git commit` anything on the user's behalf unless asked.
* Do not modify `~/.claude` beyond what `ARM_ROUTER` does.
* Do not run `lake exe cache get` outside the workspace in step 3 — a second
  mathlib is gigabytes on a disk nobody measured.
* Do not report success from a command whose exit code you read through a pipe.
* Do not claim the proofs are verified unless you ran step 3 and read exit 0.
  CI verifying them is a fact about CI; say that instead, it is still true.
