<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

> Moved from the front page in 7.0.0 — the README keeps the showroom,
> this file keeps the depth, word for word. Back: [README](../README.md).

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

## 🌍 Share your theorems — a fourth way to populate a coding agent

**An open invitation.** If you run RoT MoE on your own repository, you
accumulate Lean proofs *about that repository*. Right now those proofs die
there. [`Lean Theorem/`](Lean%20Theorem) is a folder in this repo where you can
contribute them — **by fork and pull request, entirely at your own choice**.

### Your project can stay closed

This is what makes it possible at all: **a proof carries the property, not the
source.**

A theorem stating that your scheduler never emits a negative delay is a
statement about *arithmetic and a bound*. It is not a copy of your scheduler.
Proprietary, private, unreleased, commercial — none of that is an obstacle,
because what travels is the **verified claim**, never the implementation. That
is why a closed project can contribute to an open corpus and give up nothing.

Nothing is ever uploaded automatically. No hook in this plugin reads your
repository and sends anything anywhere. If you do nothing, nothing happens.

### Why this is not MCP, not a Plugin, not a Skill, not a Connector

Those four all exist and all work — and every one of them supplies something
*different* from what this does:

| mechanism | what it gives the agent | is it verified? |
|---|---|---|
| **MCP server / Connector** | **access** — a live system, an API, data at runtime | no; the server can return anything |
| **Plugin / Skill** | **procedure** — instructions, a workflow, how to do a thing | no; advice can simply be wrong |
| **Fine-tuning / pre-training** | **disposition** — changed weights, baked in | no; and you cannot inspect what was learned |
| **`Lean Theorem/`** | **settled knowledge** — machine-checked prior art about a domain | **yes — a kernel already checked it** |

That last row is a category the other three do not have a member of. Everything
else in the list hands the model something *unverified* and asks it to be
careful. A theorem that builds at `lake build` exit 0, carries no `sorry`, and
survives `leanchecker` **cannot be wrong about what it states.** It is the only
payload on that list that arrives with its own correctness guarantee attached.

**So this is a new way of populating a coding agent**: not with tools, not with
instructions, not with weights — with *proof*.

### And it needs no training whatsoever

RoT is **generated per query, not pre-trained** — that is the row in the
comparison table [above](../README.md#-what-rot-means-and-how-it-sits-next-to-cot-and-tot),
and it is what makes this almost absurd.

A corpus like this would normally be **training data**. You would need a
pipeline, a fine-tuning run, GPUs, an evaluation harness, and at the end of it a
set of weights nobody can inspect. Here there is no training step at all,
because the thought layer is *separate from the model*. The corpus is **context,
not gradient**. It is read at inference, like any other file on disk.

Which means the entire mechanism is:

> **A fetchable proof corpus, shipped inside a shell-script router.**

No server. No runtime dependency. No network. No weights. **No Lean installation
required to benefit** — the proofs are text, and text is what a model reads.
Every user who contributes makes the next unfamiliar repository slightly less
unfamiliar for everyone, and the cost of carrying that is a rounding error
against a 9.2 MB plugin.

### How the nine lenses profit — concretely

The corpus is not decoration for the router; each lens draws something different
out of it, which is precisely what a single-perspective agent cannot do:

| lens | what a shared proof base gives it |
|---|---|
| 🧭 **Claude** (Forge) | prior art for `GROUND_TRUTH` — a real formalization to measure against instead of reasoning from nothing |
| ⚪ **Anti-Venom** (Clinical) | the `mutate/` half — **which properties survived attack**, the fastest route to what is actually load-bearing |
| ⚜️ **Nova** (Strategic) | how a domain was decomposed — what was worth stating at all, which is a strategy question before it is a proof question |
| 🜏 **Eidolon** (Recursive) | the *shape* of a formalization, reusable across domains that look nothing alike |
| 🔮 **Chroma** (Predictive) | which assumptions later broke — a contributed suite records the edits that killed a theorem |
| 🕷️ **Venom** (Executive) | a decidable model already built, so a decision can be closed rather than deliberated |
| 🩸 **Carnage** (Creative) | cross-domain collision — a bound proved about a game plugin suggesting one about a rate limiter |
| ⬜ **Soleil** (Stealth) | the compressed statement of a property, which is what a theorem already is |
| 🎷 **Violet** (Empathic) | why the property mattered to the person who proved it — the `README.md` beside each subject |

**Honesty about what is measured here.** The corpus itself is measured: **8
modules, 71 theorems, 112 KB** on disk today, counted by `ls` and
`checker/count-theorems.sh` — and `checker/repo-complete.sh` refuses to pass if
that folder is missing, empty, undocumented, or counts zero. The first draft of
this sentence said 1608, from grepping the word `theorem`; the canonical counter
excludes the word where it appears in a doc comment, and it is the authority. The *benefit* to an unfamiliar repository is a
design claim and is **NOT yet measured** — no experiment in this repo has
demonstrated it, and it is not counted among the verified results below. It is
labelled as the open question it is, not sold as a finding.

### Getting the corpus, and keeping it current — `/corpus`

**The corpus is fetched, not shipped, and that is a deliberate design decision.**
It grows by fork and pull request. If it travelled only inside release archives,
every contributed theorem would need a new plugin release — the version number
would be tracking other people's proofs instead of the plugin's own behaviour.

So the archives carry a **seed**, and a fetcher keeps it current:

```sh
./SETUP_CORPUS.sh --check      # report only; writes nothing
./SETUP_CORPUS.sh              # detect, show exactly what changes, ask
./SETUP_CORPUS.sh --yes        # non-interactive refresh
```

```powershell
.\SETUP_CORPUS.ps1 -Check      # both arms, one behaviour, identical exit codes
```

It follows the same contract `SETUP_LEAN` already uses here — **detect what you
have, say what will change, ask before doing it** — and inside a session
`/corpus` dispatches it.

| exit | meaning |
|---:|---|
| `0` | current, or you declined — **nothing was written** |
| `3` | `--check`: an update is available |
| `4` | `--check`: the corpus is absent |
| `2` | refusal — bad argument, no downloader, or the remote is unreachable |
| `1` | the fetch **failed**; your existing corpus is untouched |

**It will not silently overwrite your work.** Files changed since the last fetch
are listed before anything happens, the previous corpus is moved aside as
`Lean Theorem.pre-fetch-<timestamp>.bak` rather than deleted, and a download
arriving with zero `.lean` files is refused outright — that is an erasure, not an
update. All five exit codes above were measured on the POSIX arm against the live
repository; the unreachable-remote path was exercised with a nonexistent repo and
degrades to a message, not a stack trace.

---

