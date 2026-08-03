<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

<div align="center">

# 🜏 RoT MoE — Releases

**Nine lenses, one mind — and a kernel that checks the arithmetic**

*Three variants, shipped together. The version number **is** the variant.*

[![Ko-fi](https://img.shields.io/badge/Support-Ko--fi-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/saimonokuma)
[![Nova-Violet Role](https://img.shields.io/badge/Nova--Violet-Role-9b59b6?style=for-the-badge)](https://github.com/Nova-Violet-Role)
[![License](https://img.shields.io/badge/License-AGPL--3.0_OR_EUPL--1.2-764ba2?style=for-the-badge)](LICENSE)

[![Pure Router](https://img.shields.io/badge/v0.4.0-Pure%20Router-0969da?style=flat-square)](#-v010--pure-router)
[![Router + Lean](https://img.shields.io/badge/v0.4.1-Router%20%2B%20Lean%204-1a7f37?style=flat-square)](#-v011--router--lean-4)
[![Unsealed](https://img.shields.io/badge/v0.4.2-Router%20%2B%20Lean%20%2B%20Extra-8250df?style=flat-square)](#-v012--router--lean--extra)
[![Zero sorry](https://img.shields.io/badge/sorry-0-27ae60?style=flat-square)](#)
[![Theorems](https://img.shields.io/badge/theorems-154-2C3E50?style=flat-square)](#)

</div>

---

## 🎯 Which one do I want?

**The three numbers are not a roadmap.** Nothing here is "coming later" — all
three are built from one tree, in one run, by `checker/release-package.sh`, and
released together. The version you pick is the variant you want:

| version | variant | you get |
|---|---|---|
| **`v0.4.0`** | **Pure Router** | the plugin, alone. No Lean, no fetcher, **no network at all** |
| **`v0.4.1`** | **Router + Lean 4** | the above **plus the full Lean 4 toolchain** — the workshop these proofs were built in |
| **`v0.4.2`** | **Router + Lean + Extra** | the above **plus `native_decide` unsealed**, and the instrument that keeps that honest |

Each is a strict superset of the one before it, and that is **asserted against
the archives** — a file that vanished from a larger tier fails the build.

**Take `v0.4.0` — Pure Router.** It is the plugin. It routes, it gauges, it
reminds, and it never touches the network. If you are here to *use* RoT MoE,
that is the whole product and you are done in a minute.

**Take `v0.4.1` — Router + Lean 4** if you want **the machine that makes the
theorems**, not just the theorems.

Re-checking our 154 proofs is the *smallest* thing it does — it is the demo, not
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

**Take `v0.4.2` — Router + Lean + Extra** if you want the discipline in *your*
hands rather than enforced on you. It unseals `native_decide` for your own
proofs and ships `checker/axiom-class.sh`, which sorts every theorem into
**KERNEL** (the kernel checked it), **COMPILER** (it was *executed*, not proved)
or **BROKEN** (`sorryAx`). Full detail in `UNSEALED.md`, which ships only in
this variant.

> All three contain the identical router, the identical gauge, the identical
> hooks. `v0.4.0` is the product. **`v0.4.1` is the product plus the workshop it
> was built in. `v0.4.2` hands you the keys to the workshop's locked drawer, and
> a torch to check what you took out of it.**

---

## 📦 `v0.4.0` — Pure Router

**`rot-moe-0.4.0-core.zip`**

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

## 🔬 `v0.4.1` — Router + Lean 4

**`rot-moe-0.4.1-lean.zip`**

> Every asset carries **its own variant's version**, inside the manifest as well
> as in the file name — asserted, so an archive can never contradict its own
> name. `checker/release-package.sh` also asserts that this page names every
> asset it actually produced.

| | |
|---|---|
| ✅ **Pro** | **The full Lean 4 shelf, not a viewer.** `elan` · `lean` · `lake` · `leanchecker` · mathlib · `cadical` (the solver behind `bv_decide`) · `leanir` · a bundled `clang`/`lld`. Everything these proofs were written with |
| ✅ **Pro** | **Rewrite the router and prove your rewrite.** The λ weights, the lanes, the lead of each mode are a Lean *specification*. Change the router, make the theorems agree, and the build tells you when your change means something other than you intended |
| ✅ **Pro** | **A mathlib workspace of your own.** The costly setup for *any* formal project, done, on a drive you picked. Nothing in it is RoT-specific once it is there |
| ✅ **Pro** | **You can falsify us.** 183 theorems, 13 modules, `lake build` → `#print axioms` → `leanchecker`, on your hardware — the demo, not the point |
| ✅ **Pro** | Ships the mutation suites: break a definition on purpose and watch the theorems die. A theorem no mutation kills is decoration — and the same harnesses point at *your* code |
| ✅ **Pro** | **You choose the drive.** The installer asks for a root — `C:/`, `D:/`, `/` — because a toolchain plus a mathlib cache is measured in gigabytes and the default lands on your system drive whether it has room or not |
| ✅ **Pro** | Downloads from the **official** hosts only, pinned: `elan.lean-lang.org`, `github.com/leanprover/elan`, and mathlib's own prebuilt cache. Never a source build |
| ⚠️ **Con** | **Needs the network**, and a real amount of it: ~500 MB toolchain, several GB of mathlib cache |
| ⚠️ **Con** | Disk. `.lake` measured **7.2 GB** on the machine this was written on |
| ⚠️ **Con** | Slower first run. The plugin itself is instant; the *verification* is not |

**Contains:** everything in Core **plus** `SETUP_LEAN.sh` · `SETUP_LEAN.ps1` ·
`lean/` (12 proof modules, lakefile, pinned toolchain) · `checker/`

---

## ⚗️ `v0.4.2` — Router + Lean + Extra

**`rot-moe-0.4.2-unsealed.zip`**

First, a correction, because the shape of this tier was proposed on a premise
that measurement did not support:

> **`leantar` and `leanir` are not how `native_decide` runs.** `leantar` is the
> `.ltar` (de)compressor mathlib's cache ships in; `leanir` dumps Lean's
> intermediate representation and generated C. Neither is involved in evaluating
> a `native_decide` goal. And `clang`/`lld`/`llvm-ar` are not optional extras
> that can be declined — they are what `leanc` *is*, the C backend Lean compiles
> through. All of them arrive together, in every toolchain `elan` installs.

So `native_decide` is **already available in `v0.4.1`**. It is not withheld by
leaving a tool out; it is withheld by **policy**. Here is the measurement behind
that policy, run on the pinned toolchain, same statement for each tactic:

| tactic | closed it? | axioms afterwards | kernel rechecks it? |
|---|---|---|---|
| `rfl` | yes | **none** | yes |
| `decide` | yes | **none** | yes |
| `bv_decide` (CaDiCaL) | yes | **`propext`** | **yes** — the SAT certificate is rechecked |
| `native_decide` | yes | **`…native_decide.ax_1_1`** — a fresh axiom per theorem | **no** |

And the finding that actually matters, because it is the one that surprises
people:

> **`leanchecker` exits 0 on a `native_decide` module.** Measured. The kernel
> re-check does not catch it and never could — a declared axiom is trusted *by
> definition*, so the second opinion agrees with the first. `#print axioms` is
> the only instrument that sees it.

| | |
|---|---|
| ✅ **Pro** | **`native_decide` unlocked** for *your* proofs — goals too large for `decide` close in seconds instead of blowing `maxRecDepth` |
| ✅ **Pro** | An axiom-classification gate that **separates** kernel-checked theorems from compiler-trusted ones, and refuses to let the second kind be counted in the headline number |
| ✅ **Pro** | `bv_decide` documented as the honest heavy hammer: same power on bitvector goals, at `propext`, with a certificate the kernel rechecks |
| ✅ **Pro** | Everything in `v0.4.1` — the toolchain, the corpus, the mutation suites |
| ⚠️ **Con** | **A `native_decide` theorem is not proved, it is executed.** You are trusting the compiler, the runtime and your own CPU, none of which the kernel inspects |
| ⚠️ **Con** | `leanchecker` gives you a **false sense of coverage** here: exit 0 means the proof terms are valid, not that a computation was checked |
| ⚠️ **Con** | The 183 theorems in this repository **stay `native_decide`-free**. Unsealing applies to your work, not ours — the headline count would otherwise stop meaning what it says |
| ⚠️ **Con** | Nothing new is downloaded. `v0.4.1` already has the binaries; `v0.4.2` changes what the gates *permit* and hands you the instrument — it does not add a compiler |

**Contains:** everything in `v0.4.1` **plus** `UNSEALED.md` — the page that names
the trade in full, and the only file that distinguishes this variant.

Measured on this corpus by the tool itself: **154 KERNEL, 0 COMPILER, 0 BROKEN.**

**Why we prevented it in the first place, in one line:** a theorem's worth is
what a reader must trust to believe it, and `native_decide` silently moves that
from *a kernel anyone can re-run* to *a binary that happened to be on the machine
that day*. `bv_decide` proves you can have the automation without the trade.

---

## 🛡️ What neither version does

Stated as a list because it is easier to check than a paragraph:

* **No telemetry.** No phone-home, no analytics, no identifier.
* **No `sudo`, ever.** If it ever asks for root, it is wrong and you should stop it.
* **No system directory.** Nothing outside the plugin folder and — for `v0.4.1`,
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
unzip rot-moe-0.4.0-core.zip -d rot-moe

# 2. arm it (writes ONE hook entry into your Claude Code settings)
cd rot-moe && ./ARM_ROUTER.sh          # Windows: .\ARM_ROUTER.ps1

# 3. undo it, at any time, byte-identically
./DISARM_ROUTER.sh                     # Windows: .\DISARM_ROUTER.ps1
```

**`v0.4.1` only — the optional toolchain, after you have read what it does:**

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
