<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

> Moved from the front page in 7.0.0 — the README keeps the showroom,
> this file keeps the depth, word for word. Back: [README](../README.md).

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

### 🎭 The nine as agents — `/rot-agent` and `/rot-swarm`

The lenses are not only stanzas: each is a full agent
(`agents/rot-nova.md` … `agents/rot-claude.md`), transcribed from the
codices, running on **the model you selected** (no lens pins one), with full
tools and a bound the contract holds verbatim. Dispatch one, or all nine at
once:

```
/rot-agent venom decide: ship the migration now or split it in two
/rot-swarm the error-handling strategy in src/net — every lens, one subject
```

The swarm fans out in a single message — nine agents in parallel, each
prompted in its own register (Carnage is asked to detonate, Anti-Venom to
diagnose, Chroma to map the futures) — and the synthesis **keeps the
disagreements**: a tension between lenses is a finding, not noise. Two rules
travel with every dispatch: the roster is read from the contract, never from
memory, and an unknown lens name refuses the whole call with the roster
printed — a swarm that silently drops a voice looks complete and is not.

### 🜏 The router — what it delivers

Measured by `checker/bench-router.sh`, re-runnable in about ten seconds:

| what | measured 2026-08-04 |
|---|---|
| routing accuracy on a labelled key written *before* the run | **18/18**, covering **9** distinct lanes — and **all 10** lanes reached in a live 80-turn session |
| cost per turn | **the bound is the claim** — see the row below. A per-turn figure quoted here would be a snapshot of one router version on one machine, and the two that used to sit in this table (`194–256 ms` in-gate, `median 116 ms`) had drifted 3× before anything noticed. `checker/dominance.sh` D7 re-measures the shipped router on every deep run and prints the worst observed turn; that printed number is the live one, and it is the only one this page will quote |
| the bound the gate actually enforces | **under 500 ms of router**, proved load-bearing as `RotDominance.msBound` and re-measured by `checker/dominance.sh` D7 — **it fails the build above that**. `D7b` additionally fails the build if this page ever re-acquires a fixed-millisecond claim, because a snapshot expires and a bound does not |
| why the wall-clock number you see is bigger | wall clock includes the interpreter's startup — what your HOST charges to reach the router's first line, before a line of this code runs. Git-Bash, PowerShell and a Linux `pwsh` charge startup costs that differ by more than an order of magnitude for the *same* router, so any figure quoted here would be a snapshot of one box — the gate prints the live one. `bench-router.sh` §2 therefore holds the wall reading to a separate, deliberately generous `wallBoundMs = 1000` user-felt-latency ceiling, and judges the CODE by spawn count instead — a check that is deterministic and does not move with the machine |
| ambiguous prompts (two lanes match) | resolve by the **proved** priority order, deterministically |
| armed vs disarmed in a real `claude` session | **1 emission vs 0** — attributable to the install |

**No figure, not even a range**, and the reason is worth a sentence. Three
consecutive runs of twenty invocations on an *unchanged* tree have differed by a
factor of two here — enough that the gate reports `unmeasurable` rather than
pretend a verdict. Any number written on this page would be a snapshot
pretending to be a constant, and the next run on another machine would make the
README look wrong when nothing had regressed. The durable claim is the row
beneath — the **bound**, which is a property rather than a measurement.

This paragraph has been rewritten three times, each time to correct a figure
that had gone stale: ≈154 ms, then a range, then a different range. That history
is the argument for quoting none of them.

The last row is the one that matters most: the router is not "probably running",
it was watched firing and watched going silent when disarmed.

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

