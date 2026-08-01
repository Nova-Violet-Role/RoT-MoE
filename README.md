<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

<div align="center">

# 🜏 RoT MoE

**Nine lenses, one mind — and a kernel that checks the arithmetic**

*The Role of Thoughts: a Dynamic Cognitive Mixture-of-Experts router for Claude Code — nine named lenses, an auditable routing rule, and a divergence gauge specified in Lean 4*

[![Ko-fi](https://img.shields.io/badge/Support-Ko--fi-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/saimonokuma)
[![Nova-Violet Role](https://img.shields.io/badge/Nova--Violet-Role-9b59b6?style=for-the-badge)](https://github.com/Nova-Violet-Role)
[![License](https://img.shields.io/badge/License-AGPL--3.0_OR_EUPL--1.2-764ba2?style=for-the-badge)](LICENSE)

[![Proved in Lean 4](https://img.shields.io/badge/Proved%20in-Lean%204-2C3E50?style=flat-square)](lean/)
[![Kernel re-verified](https://img.shields.io/badge/leanchecker-exit%200-27ae60?style=flat-square)](#-what-is-actually-verified)
[![Zero sorry](https://img.shields.io/badge/sorry-0-27ae60?style=flat-square)](#-what-is-actually-verified)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-D97757?style=flat-square)](https://claude.com/claude-code)
[![REUSE](https://img.shields.io/badge/REUSE-compliant-blue?style=flat-square)](https://reuse.software/)

</div>

---

## 👋 Welcome

**You are welcome here, whatever you came for.** If you want a router for your
Claude Code sessions, [start with Install](#-install) — it takes a minute and
undoes itself completely. If you came to check whether the proofs are real,
[start with Verify](#-verify-it-yourself) and try to break them; that is not
tolerated here, it is the *point*. And if Lean is a word you have only heard in
passing, nothing on this page requires you to know it — **the plugin runs with
no Lean installed at all.**

Nobody is greyed out. Questions that begin "this is probably a dumb question"
are the ones this project was built by asking.

New here? The fastest path is to let your agent do it:

```sh
git clone https://github.com/Nova-Violet-Role/RoT-MoE.git
cd "RoT-MoE"
claude          # then type:  /rot-moe-install
```

`CLAUDE.md` in the repository root tells the agent exactly what to run, in what
order, and — just as importantly — **what it must never do**: no `sudo`, no
downloads without asking you first, no green claimed from an unread exit code.
`checker/claude-md-lint.sh` fails the build if that document ever names a file
that does not exist, so the instructions cannot rot while you are not looking.

---

## 📜 About

Every engine like this meets the same objection, and it is a fair one:
***the number is made up.*** A "divergence score" that no one can audit is a
decoration with a decimal point.

So RoT MoE answers it with a kernel instead of prose. The router measures nine
lens activities off disk, computes an `R/s+` gauge from them, and **100
machine-checked theorems in Lean 4** state what that gauge must satisfy — that
it is positive, that it is bounded below, that it is *not constant*, that it
divides by the number of lenses it actually summed. Then the mutation suites
break each definition on purpose and require the theorems to die.

### 🤝 It **improves** Claude Code — it does not replace it

This is worth saying plainly, because a plugin that names nine lenses can sound
like it wants to take the wheel. It does not.

* **Your agent stays your agent.** The router adds *one line* before a turn —
  a named lane and a gauge reading. It changes no tool, intercepts no command,
  and decides nothing. Claude Code does the work exactly as it always did.
* **Nothing is imposed.** Every lens is a *lens*, not a rule. The engine
  (`engine/rot-lean.md`) is a document the model may read; the only mechanical
  effect in your session is the hook line.
* **It undoes itself.** `DISARM_ROUTER` removes the entry, and on a settings
  file in the form Claude Code itself writes, the install/uninstall round trip
  is **byte-identical** — asserted by `checker/install-roundtrip.sh`, not hoped.
* **No network, ever.** The shipped hooks make no HTTP call of any kind. No
  telemetry, no phone-home, nothing leaves your machine.
* **No Lean required.** The proofs are *ours*, run in our CI. You can install
  the plugin with no Lean toolchain at all and never notice it exists;
  `SETUP_LEAN` is opt-in and asks first.

The last three are not promises in prose: `checker/hook-footprint.sh` fails the
build if a shipped hook ever gains a network call or invokes `lake`, and it
plants both of those to prove it can fail.

---

## 🧠 What "RoT" means, and how it sits next to CoT and ToT

**RoT is The Role of Thoughts** — a *Dynamic Cognitive Mixture-of-Experts*. The
name sits deliberately in the family of **CoT** (Chain of Thought) and **ToT**
(Tree of Thought), and the three answer the same question in three shapes:

| | shape of the reasoning | where the experts come from | can you audit the choice? |
|:--|:--|:--|:--|
| **CoT** — Chain of Thought | one line, step after step | there are none — one voice, thinking longer | you read the chain afterwards |
| **ToT** — Tree of Thought | branches, explored and pruned | there are none — one voice, thinking wider | you read the surviving branch |
| **RoT** — Role of Thoughts | several *named roles* reasoning at once, then converging | **generated per query**, not pre-trained | ✅ the routing rule is code you can read, and the gauge has theorems attached |

A chain thinks longer. A tree thinks wider. **RoT holds several defined points
of view at the same time** — clinical, executive, empathic, chaotic,
predictive, compressive, recursive, strategic, empirical — and then *converges*
rather than votes. Its engine is called **RoleThinkering**: activate memory,
generate roles, explore each divergently, synthesise, express, and finally
**measure itself**. The counter-intuitive part is the one that matters: **nine
lenses agreeing is treated as a failure, not a success.** Premature convergence
is the thing being designed against, productive tension is the signal, and
`R/s+` is what puts a number on it.

That gives RoT the property the other two lack by construction: **the routing
decision is external, inspectable and testable.** A weight-level
Mixture-of-Experts routes each token through a learned gating network across
hundreds of pre-trained experts — extremely powerful, and *not interpretable*:
you cannot ask why expert 217 fired. RoT routes at the level of the *prompt*,
in shell code you can read, with a priority order a Lean theorem characterises
in both directions. It is not a competitor to weight-level MoE; it is the
orthogonal layer. One decides **which parameters fire** during generation; the
other decides **how the reasoning is framed** before it.

> 📚 **Provenance, stated plainly.** The architecture is documented in *The Role
> of Thoughts — Dynamic Cognitive MoE Architecture*, the Nova_Omega Project
> blueprint (2025–2026): the six-stage RoleThinkering pipeline, the R/s
> sovereignty gauge with its self-correction protocol, and the expression-filter
> layer the lenses grew out of. It was a **specification**, stress-tested as
> prose against native MoE models long before any of it executed.
>
> **This repository is the generation where it stopped being a document.** The
> nine lenses, the three-tier router and the gauge run as real code in two
> shells; the gauge here is the extended `R/s+` form — per-lens weights λ, a
> sigmoid on divergence, entropy, quality μ and calibration — rather than the
> blueprint's plain mean of deltas; and the properties that used to be asserted
> in prose are theorems in `lean/Proofs/`. Earlier comparison studies are
> history, **not evidence for this tree**. Everything on this page is measured
> from *this* repository. Licensing of the architecture document versus this
> implementation is set out in `NOTICE.md` §A.4.

---

## 🌟 Why Lean 4 — and why you should be excited about it

**This repository exists because of Lean 4, and it deserves the front page.**

Lean 4 is a *proof assistant* and a real programming language at the same time.
You write mathematics in it, and a **kernel of a few thousand lines** re-derives
every single inference step from the axioms. Not "the tests passed". Not "the
reviewer agreed". The machine reconstructed the argument and found no gap.

Three things make that extraordinary rather than merely nice:

* **A theorem is not a sentence — it is a claim over an infinite space.**
  `∀ (p q : Platform), key p = key q → p = q` is checked for *every* pair that
  could ever exist. A test suite could run for a century and cover a rounding
  error's worth of that. This is the difference between *sampling* and
  *settling*, and once you have felt it you cannot unfeel it.
* **[mathlib](https://leanprover-community.github.io/) is one of the great
  collaborative artefacts in mathematics** — over a million lines of formalised
  analysis, algebra, topology and order theory, all machine-checked, all free,
  all reusable by you today. The `sigma_strictMono` proof in this repo stands on
  work that thousands of contributors put there first. That is what `import
  Mathlib` actually means: you inherit a library of *certainty*.
* **Dependent types let the type carry the promise.** A function can be typed so
  that "this list is non-empty" or "this index is in range" is impossible to get
  wrong — the compiler refuses the mistake instead of the runtime discovering it.

And Lean is genuinely a **problem solver**, not a bureaucrat. `omega` closes
linear arithmetic, `decide` settles finite questions by computation, `ring` and
`linarith` do the algebra you would have done by hand, `grind` and `aesop` search
for the proof, and `exact?` will *find the lemma for you* out of all of mathlib
and print the exact line to write. Several proofs here were finished by asking
the compiler what it already knew.

It is also honest in a way software rarely is. When a theorem in this repo was
**false**, Lean simply refused — no amount of confidence moved it. That refusal
is recorded in `RotPath.lean` rather than quietly patched, because being told
"no" by a machine that cannot be argued with is the most useful thing that
happened to this codebase.

> 💛 **Never touched a proof assistant? You are exactly who this section is
> for.** You do not need Lean to use this plugin, and you do not need a maths
> degree to start: [Natural Number Game](https://adam.math.hhu.de/) teaches you
> your first real proofs in a browser, in an afternoon, for free. If this
> repository is the reason you try it, that is a better outcome for us than any
> star.

- ✅ works on Windows, macOS and Linux — two arms, byte-identical output
- ✅ installs offline in seconds, `DISARM_ROUTER` removes exactly what it added
- ✅ **no Lean required to use it**; Lean is only for re-verifying the proofs
- ✅ every checker carries a negative control that has been seen to fail
- ✅ dual-licensed AGPL-3.0-or-later **OR** EUPL-1.2, your choice

---

## 🔬 What is actually verified

| instrument | what it establishes | result |
|---|---|---|
| `lake build Proofs.*` | the modules elaborate | exit **0** |
| `#print axioms` on every theorem | nothing rests on `sorryAx` | **0** `sorryAx` |
| `lake env leanchecker` | Lean's **kernel** re-verifies the proof terms, independently of the elaborator that produced them | exit **0**, zero bytes |
| Lean mutation suites | the theorems are load-bearing | **62 applied, 62 killed, 0 survived, 0 discarded** |
| `checker/gauge-cross.sh` | the Lean mirror and the running hook agree | **6 corpus rows, hook == Lean to 2 dp**; control = retune one λ in the hook alone → 6 rows disagree |
| `checker/mutate-checker.sh` | the *checkers* can fail — 2 meta-controls green, 14 mutants killed, 1 inexpressible on this OS | **0 survived, 0 discarded** |
| `checker/ci-dryrun.sh` | the **CI step list itself**, taken from `ci.yml` and executed on a clean copy of the tree — so a pipeline defect is caught before the push, not by it | every runnable step exit **0**; runner-only steps listed as **DEFERRED, never passed** |

Every one of those has a **negative control** recorded beside it, because an
instrument that has never been seen to fail proves nothing. `leanchecker`
against a module with no oleans exits 1. The SPDX sweep with one tag stripped
exits 1. The path sweep with one planted violation exits 1. If a check cannot
go red on demand, it is decoration and is labelled as such.

Zero `sorry`. No `native_decide` anywhere — it trusts the compiler binary
instead of the kernel, which would quietly undo the point of the whole exercise.

> 🛡️ **The instruments are tested by breaking them on purpose.** Every mutation
> suite must be able to fail, must know when a patch did *not* apply, and must
> refuse to run against a red baseline — because a kill it cannot attribute is
> not evidence. When one of our own harnesses fell short of that bar we fixed it
> and wrote the reason into the file, where the next reader will find it.
> `NOTICE.md` §C keeps the full engineering log for anyone who wants it.

### 📐 The seven modules

* **`lean/Proofs/RotGauge.lean`** (35 theorems) — the R/s+ gauge.
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
* **`lean/Proofs/RotRemind.lean`** (8 theorems) — organ 4's decision, and the
  first theorems about the reminder rather than about the router. The cross-diff
  proves the two arms agree on 23 corpus rows; these prove the properties no
  corpus can reach. `silent_regardless_of_alarms` quantifies over the alarm
  count, so open alarms alone can never make it speak — the wallpaper failure
  its ancestor died of. `speaks_iff` characterises speech in **both** directions,
  because "if there is debt it speaks" would still be satisfied by something that
  speaks always. `stale_monotone` says time can only make it louder — and carries
  a freshness hypothesis that **Lean refused to let me omit**: `-1` does not mean
  "a minute ago", it means *no proofs found*, so `stale_monotone_needs_nonneg`
  proves the hypothesis cannot be dropped. `lower_threshold_speaks_more` is
  quantified over the threshold rather than pinned at 45, so retuning the default
  cannot turn a correct change red.
* **`lean/Proofs/RotAcquire.lean`** (9 theorems) — **a checker must never
  acquire anything**, and this module exists because one of ours did. Every Lean
  script here calls `lake`, and `lake` resolves the package *before* it runs
  anything, so a single probe began fetching mathlib into this 200 KB repository
  and reached **7.2 GB** before it was stopped. `no_lake_on_unbuilt` states the
  invariant over an *arbitrary* workspace: if it was never built, no execution
  path reaches lake. `lake_implies_built` is its converse, so a guard that
  simply refused everything would not satisfy the pair.
  `guard_survives_target_deletion` covers the subtle half — every mutant deletes
  the module's own `.olean` on purpose, so keying the guard on that artefact
  made a real workspace look never-built, and
  `old_guard_false_skips_after_target_deleted` exhibits exactly that workspace
  rather than describing it.
* **`lean/Proofs/RotVerdict.lean`** (11 theorems) — **the weekly status report
  must be able to say nothing.** Our scheduled workflow publishes `STATUS.md`
  and commits it *only when the verdict changed*, so a quiet week is visible as
  a quiet week rather than hidden by a timestamp bump. The rule was written in
  the comments and defeated by the payload: the file being compared carried the
  run's own clock and commit id, so "nothing changed" was unreachable and the
  bot would have committed every week forever. `silent_week_is_silent` is
  quantified over **every** clock and **every** commit id, which is exactly what
  the old design made false, and `decision_ignores_clock_and_sha` states the
  invariant over the variables that move instead of the values that hold today.
  `quiet_forever` and `published_exactly_once` reach where measurement cannot:
  a checker runs three weeks against a scratch remote, these cover all *k*. The
  old design is reconstructed alongside so `designs_disagree` and
  `old_commits_every_week` can prove the fix was not cosmetic — fifty-two empty
  commits a year, executed as a `#guard`, not asserted.
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

## 🫀 The four organs

| organ | file | what it does |
|:--|:--|:--|
| 1 · engine | `engine/rot-lean.md` | the specification: nine lenses, the three-tier router, the `R/s+` formula |
| 2 · router | `hooks/rot-router.sh` · `.ps1` | measures, routes, gauges — on every prompt and every tool call |
| 3 · prover | `agents/lean4-prover.md` | a Lean 4 subagent whose prime rule is *no claim without a green build* |
| 4 · reminder | `hooks/prover-remind.sh` · `.ps1` | names your actual proof debt, and stays **silent** when there is none |

Organs 2 and 4 ship as **two arms each**, and `checker/cross-diff.sh` and
`checker/cross-diff-remind.sh` run both over a shared corpus demanding
byte-identical output on every row — 49 and 23 rows respectively. Two
implementations that agree is a truth a single green cannot fake: a shared bug
would have to be written twice, in two languages, by hand.

The reminder deserves a note, because its healthy state looks like a failure:
**it says nothing most of the time.** Its ancestor emitted the same paragraph
every five minutes until it became wallpaper. This one measures first and speaks
only when it can name a file, a module or a number of minutes.

---

## 🚀 Install

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

### 🔧 Requirements

| | |
|:--|:--|
| 💬 **Claude Code** | any recent version — the plugin is hooks + markdown |
| 🐚 **A shell** | POSIX `sh`/`bash` **or** PowerShell 7. Both arms ship; neither is a second-class citizen. |
| 🎓 **Lean 4** | **not required.** Only if you want to re-prove the theorems yourself — see below. |

### ⚙️ Configuration

| Variable | Effect |
|:--|:--|
| `ROTMOE_LEAN_WORKSPACE` | which Lean workspace to build and remind about. Defaults to the packet's own `lean/`. |
| `ROTMOE_WATCH_REPO` | which repository the reminder scans for proof-shaped changes. Defaults to the working directory. |
| `ROTMOE_STATE_DIR` | where the throttle stamps live. Defaults to `$XDG_STATE_HOME/rot-moe`. |
| `ROTMOE_PROOF_STALE_MIN` | minutes before "no proof written recently" is worth saying. Default `45`. |
| `ROTMOE_DEBT_EXT` | which source extensions count as proof-shaped. Default spans Rust, C, C++, Go, TS, Python, Java, Kotlin, Swift. |
| `ELAN_HOME` | elan's own variable, honoured rather than reinvented. |

---

## 💡 Tips & Tricks — getting real work out of it

### 🤖 The agent: `lean4-prover`

`agents/lean4-prover.md` ships as a **subagent definition** with loadable
frontmatter. Point Claude Code at it and you get a specialist whose entire
personality is *refusing to claim anything it did not measure*.

**What it is good at**

| it does this well | why |
|---|---|
| turning "this should be safe" into a theorem or an honest "no universal claim" | it is required to name the instrument behind every sentence |
| finding the lemma you cannot remember | `exact?`, `apply?`, `rw?`, `simp?` are its first reflex, not its last |
| refusing a false green | it reads exit codes directly and treats a pipe as a bug |
| telling you a proof is **decorative** | it mutates its own theorems and reports which ones nothing killed |
| working on a program in *any* language | the binding is a checker that runs your real code, not a Lean rewrite of it |

**Spawning it — one, several, or in the background**

```sh
# one, on a specific obligation
claude "use the lean4-prover agent: prove the clamp in src/limits.rs never exceeds MAX"

# several at once — one per module, they do not share state
claude "spawn 4 lean4-prover agents in parallel, one per file in lean/Proofs/,
        each: build, #print axioms, leanchecker, then mutate and report kills"

# in the background, while you keep working
claude "run the lean4-prover agent in the background on the mutation suites;
        report only the survivors"
```

The agent is **stateless per task**, which is exactly what makes fan-out safe:
each one owns a file, builds it, mutates it, restores it, and reports. Give two
of them the same file and they will fight over the same `.mutbak` — one agent,
one module is the rule that keeps kills attributable.

**Useful habits**

* Ask for `#print axioms` in the same breath as the proof. `sorryAx` means *not
  proved*; **no axioms at all** usually means *vacuous*, not *strong*.
* Ask "which mutation kills this?" before believing a theorem matters.
* If it says `MEASURED` rather than `PROVED`, that distinction is deliberate —
  `Float ≠ ℝ`, and it will not pretend otherwise.

### 🜏 The router — what it delivers

Measured by `checker/bench-router.sh`, re-runnable in about ten seconds:

| what | measured 2026-08-01 |
|---|---|
| routing accuracy on a labelled key written *before* the run | **18/18**, covering **9** distinct lanes |
| cost per turn | **≈154 ms**, of which ~18 ms is bash process startup |
| ambiguous prompts (two lanes match) | resolve by the **proved** priority order, deterministically |
| armed vs disarmed in a real `claude` session | **1 emission vs 0** — attributable to the install |

That last row is the one that matters: the router is not "probably running", it
was watched firing and watched going silent when disarmed.

**Its strong point is not the number — it is that the number is falsifiable.**
Nine lenses, a priority order a theorem characterises in both directions, and a
gauge whose properties are machine-checked. You can disagree with the routing;
you cannot be lied to about it.

### 🧠 What Lean 4 actually changes in an agentic loop

This is the part worth reading twice.

An agent writing code hits a fork on every non-trivial step: *is this actually
correct?* It has three ways out.

1. **Guess** — write it, sound confident, move on. Fast, and how most bad code
   is born.
2. **Ask you** — "does this look right?" Safe, and it turns an autonomous agent
   into a chat partner that needs you awake.
3. **Ask the compiler.** State the claim as a theorem and let a kernel of a few
   thousand lines re-derive it from the axioms. It answers in seconds, it is
   never polite, and it cannot be argued with.

**Option 3 is what removes you from the *verification* loop.** Not from the
project — from the tedious half. A test suite samples: it tries the inputs
someone thought of. A theorem settles: `∀ (p q : Platform), key p = key q → p = q`
is checked over every pair that could ever exist. Once an obligation is a
theorem, "are you sure?" stops being a question a human has to answer, and the
agent can keep going through the night without a single "please confirm".

**And the loop closes on itself.** The agent writes the theorem, builds it,
prints its axioms, re-checks it with `leanchecker`, then *mutates its own model
on purpose* and requires the theorems to die. If a mutation survives, the
theorem was decoration and the agent says so. That is a self-auditing loop —
which is precisely why it does not need to interrupt you: it has an oracle that
is not you, and a habit of doubting itself that does not depend on your mood.

This repository is the demonstration, not the advertisement: **six defects were
found this way in a single day** — a scheduled bot that would have committed
forever, an "axiom gate" that never printed an axiom, a mutation harness that
scored eleven perfect kills without opening a source file, a probe that fetched
7.2 GB into a 200 KB repo, an infinite loop in the router's own flag parser, and
a checker that reported a clean sweep of 29 theorems in a 35-theorem file. Every
one was found by an instrument, on green code, with nobody asked to review
anything.

**Where you are still needed, stated honestly.** Lean settles *correctness
against a stated property*. It cannot tell you the property was the one you
wanted. Intent, taste, priorities, whether the feature should exist at all —
those remain yours, and a proof that the wrong thing is correct is still the
wrong thing. Anyone claiming otherwise is selling something. What we claim is
narrower and worth more: **you should never again have to be the one who checks
whether the code does what it says.**

---

## 🎓 Verify it yourself

The proofs are checked by CI on a clean runner for every commit, so you never
*have* to. This is for the reader who would rather measure than trust — the
correct instinct, and the whole reason this repository exists.

Lean is a multi-gigabyte install, so it is **opt-in and it asks first**:

```sh
bash SETUP_LEAN.sh --dry-run    # prints the plan, creates NOTHING — run this first
bash SETUP_LEAN.sh --yes        # elan + the PINNED toolchain + the PREBUILT mathlib cache
bash SETUP_LEAN.sh --uninstall  # tells you exactly what to remove, removes nothing itself
```

Nothing installs that fetch for you: `checker/workflow-lint.sh` **fails the
build** if `ARM_ROUTER` ever references `SETUP_LEAN`. Installing a router must
never download a compiler.

Then:

```sh
cd lean
lake build Proofs.RotGauge Proofs.RotRoute Proofs.RotInstall Proofs.RotPath Proofs.RotRemind Proofs.RotAcquire Proofs.RotVacuity
echo "lake build exit=$?"                   # read it DIRECTLY, never through a pipe
lake env leanchecker Proofs.RotGauge        # exit 0, zero bytes = kernel pass
lake env leanchecker Proofs.NoSuchModule    # exit 1 = the control
bash mutate/mutate_rotgauge.sh              # expect 12 killed, 0 survived
bash mutate/mutate_rotroute.sh              # expect 11 killed, 0 survived
bash mutate/mutate_rotinstall.sh            # expect 10 killed, 0 survived
bash mutate/mutate_rotpath.sh               # expect  5 killed, 0 survived
bash mutate/mutate_rotremind.sh             # expect  6 killed, 0 survived
bash mutate/mutate_rotacquire.sh            # expect  5 killed, 0 survived
bash mutate/mutate_rotvacuity.sh            # expect  6 killed, 0 survived
```

Each suite **refuses to run** unless its source file is present and the
unmutated baseline builds green, because a kill measured against a red baseline
is unattributable. Point them at another workspace with `LEAN_ROOT=/path/to/ws`.

> 🛟 **They also refuse to download anything, and that guard was paid for.**
> Every suite calls `lake`, and `lake` resolves the package *before* it does
> anything — so run against this repository's own `lean/` folder on a machine
> with no built workspace, one of them began fetching mathlib **into the repo
> and reached 7.2 GB** before it was noticed. The tree ships as ~200 KB. Each
> suite now checks for an already-built workspace first and **skips (exit 3)**
> rather than building one, so nothing here can ever grow your checkout. Exit 3
> is reported as a skip by every caller — never as a pass. If you want the
> suites to actually run, point `LEAN_ROOT` at a workspace you built yourself.

And the whole tree in one command, which is what the pre-commit hook runs:

```sh
bash checker/gate-all.sh
echo "gate-all exit=$?"
```

Do not take the counts in this README on faith — the **Ads Manager** workflow
does not either. It recounts the theorems from source on every run and fails
the build if this file disagrees with the sources, or if any sentence here
claims a proof about output *quality*.

---

## 🗺️ The map: PROVED · MEASURED · OUT OF SCOPE

**This is the section we are proudest of.** Knowing exactly where the guarantee
ends is what makes everything before it worth having — a proof with an unmarked
edge is a rumour with LaTeX. So here is the honest map, and every line of it is
a *commitment*: what says PROVED is proved for all inputs, forever, and what
says MEASURED is labelled MEASURED in the source too.

| | |
|:--|:--|
| ✅ **PROVED** | the gauge is positive, bounded below, non-constant, divides by the lenses it summed · the router is total, has no dead lane, and every lane is characterised in both directions · arming preserves every key you own, including keys nobody has invented yet · the two path spellings converge · `disarm ∘ arm` is the identity exactly when the freshness hypothesis holds — and provably not otherwise |
| 📏 **MEASURED** | the `Float` mirror agrees with the live hook to two decimals · both arms produce byte-identical output on 49 + 23 corpus rows · the installer round trip is byte-identical on a canonical file · the plugin loads in a real session |
| 🚫 **OUT OF SCOPE** | anything about output *quality* — see below |

And the specifics, because a map with no detail is a poster:

* **Nothing about output quality.** No theorem says routed reasoning is better,
  smarter, or more correct than unrouted reasoning. That is not a property Lean
  can see. Any such claim in this repo would be an overclaim; if you find one,
  it is a bug and an issue is welcome.
* **`RotGauge` models code that ships; `RotRoute` models the specification and
  the ports that now implement it.** TIER 1 keyword routing was specified long
  before it was implemented — the original hook contained the mode names only in
  a comment. Both arms implement it today (`Invoke-Route` and `route`), the
  priority order is the one `route_exact` characterises, and `cross-diff.sh`
  holds them to it. What Lean proves is the *function*; that the shipped file
  computes it is the cross-diff's job, and the two are stated separately on
  purpose.
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
* **The reminder's *decision* is cross-checked; its *measurements* are not.**
  `--decide` takes the measured inputs as arguments, so both arms are compared
  exactly. That the two arms read the same things off disk and off git is
  asserted by construction, not by proof.

---

## 🤝 Contributing

| Area | How you can help |
|:--|:--|
| 🐛 **Break something** | Find a checker that cannot go red. That is the most valuable issue you can file here. |
| 📐 **Proofs** | Strengthen a theorem, or show one is vacuous — `RotVacuity.lean` exists because that happened. |
| 🖥️ **Platforms** | Run the gates on your OS and tell us what diverged. |
| 🌍 **Docs** | Say which sentence you had to read twice. That is a defect in the sentence. |
| 💡 **Ideas** | Tell us what a *verified* agent tool should refuse to claim. |

Read `CONTRIBUTING.md` first; `SECURITY.md` covers what this plugin touches on
your machine and what it never will.

---

## ☕ Supporting a non-profit

**Nova-Violet Role is a non-profit organisation.** Everything here is free
software under a copyleft licence and it stays that way — there is no paid tier,
no telemetry, no "pro" edition waiting behind a paywall.

We run on **small donations**, and small genuinely means small: a coffee's worth
keeps the lights on for the CI minutes that re-verify every one of these proofs
on every commit. If this repository taught you something, saved you an
afternoon, or convinced you to open Lean 4 for the first time, that is already a
success by our accounting.

[![Support Our Journey](https://img.shields.io/badge/☕_Buy_us_a_coffee-Ko--fi-FF5E5B?style=for-the-badge)](https://ko-fi.com/saimonokuma)

And donating is genuinely optional — starring the repo, filing an issue,
correcting a sentence, or telling one other person are all worth as much to a
project this size.

### 🙏 Standing on other people's work

This project is possible because of the [Lean 4](https://lean-lang.org/) team
and the [mathlib](https://leanprover-community.github.io/) community, whose
freely given libraries carry most of the mathematical weight in `lean/Proofs/`.
Full credits and provenance live in `NOTICE.md`.

---

## 📄 Licence

Dual: **AGPL-3.0-or-later OR EUPL-1.2**, at your option.

RoT MoE is an original work, so the root `LICENSE` is the verbatim AGPL-3.0
text and GitHub detects the repo as AGPL-3.0. `LICENSE-EUPL-1.2` sits beside
it, `LICENSES/` carries both texts for [REUSE](https://reuse.software/), and
every source file carries

```
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
```

`checker/spdx-sweep.sh` keeps that promise machine-enforced on every push, so
the licence you were granted is the licence you keep. `NOTICE.md` carries the
full provenance and the credits — including thanks to the projects this work
stands on.

---

<div align="center">

### 🜏 RoT MoE

*Nine lenses. One mind. The compiler has the last word.*

[![Support Our Journey](https://img.shields.io/badge/🔗_Support_Our_Journey-Ko--fi-FF5E5B?style=for-the-badge)](https://ko-fi.com/saimonokuma)

[Issues](https://github.com/Nova-Violet-Role/RoT-MoE/issues) · [Security](SECURITY.md) · [Contributing](CONTRIBUTING.md) · [Notice](NOTICE.md)

© 2026 Nova-Violet Role · Non-Profit Organization

*Created with ❤️ for the advancement of human understanding*

</div>

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
