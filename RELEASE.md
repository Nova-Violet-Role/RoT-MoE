<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

<div align="center">

# 🜏 RoT MoE — Releases

**Nine lenses, one mind — and a kernel that checks the arithmetic**

*Two downloads. Same plugin. The difference is whether your machine fetches Lean.*

[![Ko-fi](https://img.shields.io/badge/Support-Ko--fi-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/saimonokuma)
[![Nova-Violet Role](https://img.shields.io/badge/Nova--Violet-Role-9b59b6?style=for-the-badge)](https://github.com/Nova-Violet-Role)
[![License](https://img.shields.io/badge/License-AGPL--3.0_OR_EUPL--1.2-764ba2?style=for-the-badge)](LICENSE)

[![Core](https://img.shields.io/badge/v0.1.0-Core-0969da?style=flat-square)](#-v010--core)
[![Core + Lean](https://img.shields.io/badge/v0.1.1-Core%20%2B%20Lean-1a7f37?style=flat-square)](#-v011--core--lean)
[![Zero sorry](https://img.shields.io/badge/sorry-0-27ae60?style=flat-square)](#)
[![Theorems](https://img.shields.io/badge/theorems-123-2C3E50?style=flat-square)](#)

</div>

---

## 🎯 Which one do I want?

**Take `v0.1.0` — Core.** It is the plugin. It routes, it gauges, it reminds, and
it never touches the network. If you are here to *use* RoT MoE, that is the
whole product and you are done in a minute.

**Take `v0.1.1` — Core + Lean** if you want **the machine that makes the
theorems**, not just the theorems.

Re-checking our 123 proofs is the *smallest* thing it does — it is the demo, not
the product. What actually lands on your disk is a complete Lean 4 toolchain:
`elan`, `lean`, `lake`, `leanchecker`, the mathlib cache, the SAT solver behind
`bv_decide`. That is the same engine every one of these proofs was written with,
and once it is yours the router stops being something you *run* and becomes
something you can **argue with**:

* **Reshape the router and prove the reshape is sound.** Retune the nine λ
  weights, add a lane, change the lead of a mode — then make `RotLens.lean` and
  `RotGauge.lean` agree with your version. The proofs are not decoration around
  our numbers; they are a specification you can edit, and the build goes red when
  your edit means something different from what you thought.
* **Start your own proved repositories.** A Lean workspace with mathlib fetched
  is the expensive part of any formal project, and this sets one up for you on a
  drive you chose. Nothing about it is RoT-specific afterwards.
* **Get the discipline, not just the tool.** The whole method the router enforces
  — build → `#print axioms` → `leanchecker`, then mutate it and prove the theorem
  dies — arrives as working, running scripts you can point at your own code.

> Both contain the identical router, the identical gauge, the identical hooks.
> `v0.1.0` is the product. **`v0.1.1` is the product plus the workshop it was
> built in.**

---

## 📦 Core — shipped from **v0.1.0**

**`rot-moe-0.1.0-core.zip`**

| | |
|---|---|
| ✅ **Pro** | **No network. Ever.** The archive contains no fetcher, so it *cannot* download anything — asserted against the zip itself by `checker/release-package.sh`, not promised in prose |
| ✅ **Pro** | Small — **well under a megabyte**, and nothing appears on your disk afterwards but the plugin folder |
| ✅ **Pro** | No toolchain, no compiler, no build step. Works with **no Lean installed at all** |
| ✅ **Pro** | Uninstalls itself. `DISARM_ROUTER` restores your settings **byte-identically** on a file in the form Claude Code writes |
| ⚠️ **Con** | You cannot re-run the proofs. You are trusting our CI, which re-verifies every commit on a clean runner — reasonable, but it *is* trust |
| ⚠️ **Con** | No `lean/` corpus to read locally (it is on GitHub either way) |

**Contains:** `hooks/` · `agents/` · `engine/` · `ARM_ROUTER` · `DISARM_ROUTER` ·
licences · `CLAUDE.md` · `README.md`
**Does NOT contain:** `SETUP_LEAN.*` · `lean/` — *by assertion, not by accident*

---

## 🔬 Core + Lean — shipped from **v0.1.1**

**`rot-moe-0.1.0-lean.zip`**

> The asset always carries the **tree version it was built from**, so a file
> name never disagrees with the manifest inside it. `v0.1.0` publishes the Core
> asset alone; `v0.1.1` publishes both. `checker/release-package.sh` asserts
> this page names every asset it actually produced.

| | |
|---|---|
| ✅ **Pro** | **The full Lean 4 shelf, not a viewer.** `elan` · `lean` · `lake` · `leanchecker` · mathlib · `cadical` (the solver behind `bv_decide`) · `leanir` · a bundled `clang`/`lld`. Everything these proofs were written with |
| ✅ **Pro** | **Rewrite the router and prove your rewrite.** The λ weights, the lanes, the lead of each mode are a Lean *specification*. Change the router, make the theorems agree, and the build tells you when your change means something other than you intended |
| ✅ **Pro** | **A mathlib workspace of your own.** The costly setup for *any* formal project, done, on a drive you picked. Nothing in it is RoT-specific once it is there |
| ✅ **Pro** | **You can falsify us.** 123 theorems, 10 modules, `lake build` → `#print axioms` → `leanchecker`, on your hardware — the demo, not the point |
| ✅ **Pro** | Ships the mutation suites: break a definition on purpose and watch the theorems die. A theorem no mutation kills is decoration — and the same harnesses point at *your* code |
| ✅ **Pro** | **You choose the drive.** The installer asks for a root — `C:/`, `D:/`, `/` — because a toolchain plus a mathlib cache is measured in gigabytes and the default lands on your system drive whether it has room or not |
| ✅ **Pro** | Downloads from the **official** hosts only, pinned: `elan.lean-lang.org`, `github.com/leanprover/elan`, and mathlib's own prebuilt cache. Never a source build |
| ⚠️ **Con** | **Needs the network**, and a real amount of it: ~500 MB toolchain, several GB of mathlib cache |
| ⚠️ **Con** | Disk. `.lake` measured **7.2 GB** on the machine this was written on |
| ⚠️ **Con** | Slower first run. The plugin itself is instant; the *verification* is not |

**Contains:** everything in Core **plus** `SETUP_LEAN.sh` · `SETUP_LEAN.ps1` ·
`lean/` (10 proof modules, lakefile, pinned toolchain) · `checker/`

---

## 🛡️ What neither version does

Stated as a list because it is easier to check than a paragraph:

* **No telemetry.** No phone-home, no analytics, no identifier.
* **No `sudo`, ever.** If it ever asks for root, it is wrong and you should stop it.
* **No system directory.** Nothing outside the plugin folder and — for `v0.1.1`,
  only with your consent — the install root you named.
* **No silent download.** `SETUP_LEAN` **refuses by default**, exit 2. Consent is
  not a default: `--dry-run` prints the plan and creates nothing.
* **No replacing your agent.** The router adds *one line* before a turn. It
  intercepts no tool and decides nothing.

`checker/hook-footprint.sh` fails the build if a shipped hook ever gains a
network call, and it plants one to prove it can fail.

---

## 🚀 Install

<div align="center">

**Either version, from the plugin folder**

</div>

```sh
# 1. unzip wherever you keep plugins
unzip rot-moe-0.1.0-core.zip -d rot-moe

# 2. arm it (writes ONE hook entry into your Claude Code settings)
cd rot-moe && ./ARM_ROUTER.sh          # Windows: .\ARM_ROUTER.ps1

# 3. undo it, at any time, byte-identically
./DISARM_ROUTER.sh                     # Windows: .\DISARM_ROUTER.ps1
```

**`v0.1.1` only — the optional toolchain, after you have read what it does:**

```sh
./SETUP_LEAN.sh                 # REFUSES. exit 2. consent is not a default
./SETUP_LEAN.sh --dry-run       # prints the plan, creates NOTHING
./SETUP_LEAN.sh --ask-root      # asks which drive; C:/ D:/ / are all fine
./SETUP_LEAN.sh --root=D:/ --yes    # non-interactive, toolchain -> D:/.elan
./SETUP_LEAN.sh --uninstall     # tells you exactly what to remove
```

Then check our work — and then go past it:

```sh
cd lean
lake build                              # exit 0, or it is not proved
lake env leanchecker Proofs.RotGauge    # the kernel's own second opinion
```

```sh
# now the part that is actually yours: change the router, and make the
# specification agree with it. Edit the weights in hooks/rot-router.sh,
# then edit lean/Proofs/RotLens.lean to match and rebuild. The gate
# checker/gauge-cross.sh exists precisely to fail when they disagree.
lake env lean scratch.lean       # elaborate anything, with mathlib, no build graph
lake new my-proofs math          # your own project -- the toolchain is yours now
```

The binaries `elan` puts on your machine, measured on the toolchain this repo
pins: `lean` · `lake` · `leanc` · `leanchecker` · `leanmake` · and, inside
`~/.elan/toolchains/<ver>/bin`, `cadical` (the SAT solver `bv_decide` runs on,
which emits a *checkable proof* — unlike `native_decide`, which this project
forbids) · `leantar` · `leanir` · a bundled `clang` / `lld` / `llvm-ar`.

---

## 🔍 Verify the download itself

Every claim on this page is an assertion in a script you can run:

```sh
bash checker/release-package.sh   # rebuilds both zips and asserts their contents
bash checker/gate-all.sh          # every gate; it prints the count itself
```

`release-package.sh` **exits non-zero and uploads nothing** if the Core archive
ever contains a fetcher — the promise at the top of this page is enforced against
the artifact, not against the tree it came from.

---

<div align="center">

**Made by [Nova-Violet Role](https://github.com/Nova-Violet-Role)** — a non-profit
working where law, code and cognition meet.

*If it is not measured, it is not claimed.*

</div>
