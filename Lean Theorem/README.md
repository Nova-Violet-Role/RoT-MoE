<!--
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# `Lean Theorem/` — the shared proof base

**This folder is prior art.** It is a collection of Lean 4 proof sub-folders,
one per *project*, contributed by people who ran RoT MoE on their own repository
and chose to share what they proved about it.

It is not the Router's own proofs. Those live in [`lean/`](../lean) and stay
there — `lean/` is what RoT MoE proves **about itself**, and it is a different
thing entirely from what this folder is for.

---

## Why it exists

A user runs the Router on their repository. Over weeks they accumulate real Lean
proofs *about that codebase* — what its invariants are, which bounds hold, which
assumptions turned out to be load-bearing. Today those proofs die in that repo.
Nobody else ever sees them.

**The consequence is that every model starts from zero on every new codebase.**
Given an unfamiliar repository, it has no idea what "a proof about this kind of
thing" even looks like — what was worth stating, how the domain was modelled,
which definitions made the properties decidable in the first place.

This folder is the fix, and the mechanism is deliberately dull: **the corpus
travels with the plugin and is read like any other file.** No index, no
retrieval engine, no hook consults it. It works the way a local shared proofs tree
already works on the author's machine — prior art sitting on disk, read because
it is there.

## What a contributor actually shares

**Only the `.lean` files.** This is the point that makes the whole thing
possible: **a proof carries the property, not the source.**

Your project can be closed, proprietary, private, unreleased — it does not
matter. A theorem stating that your rate limiter never emits a negative delay is
a statement about *arithmetic and a bound*, not a copy of your rate limiter.
That is why a **closed** project can contribute to an open corpus without
disclosing anything it does not wish to.

Contribution is by **fork and pull request**, entirely at your own choice, and
by a deliberate act of committing. Nothing is ever uploaded automatically; no
hook in this plugin reads your repository and sends anything anywhere. If you do
nothing, nothing happens.

## Structure

Each contribution is one **sub-work folder** named for the project:

```
Lean Theorem/
  <YourProject>/
    README.md      <- what this subject is, and WHAT THE MUTATIONS KILLED
    Proofs/        <- the .lean modules
    mutate/        <- the mutation suites that attacked them
```

The structure mirrors [`lean/`](../lean) — `Proofs/` **and** `mutate/` — because
both halves teach, and they teach different things:

| what travels | what it teaches |
|---|---|
| `Proofs/` | **how this kind of thing gets formalized at all** — what was worth stating, what the model of the domain looked like, which definitions made the properties decidable |
| `mutate/` | **which of those properties were load-bearing under attack** — and, just as valuable, which edits the suite could *not* kill |

**A corpus of unmutated theorems would be worse than half a corpus.** It teaches
the shape of a proof while hiding which parts of it carried weight — and *that*
is the lesson which transfers to a repository nobody has seen before. A theorem
no mutation can kill is decorative, and a base full of decorative theorems
teaches decoration.

## The bar for admission

Honest, and low enough to be reachable:

| requirement | why |
|---|---|
| it **builds** — `lake build` exit 0, exit code read directly | an unbuildable module teaches nothing and poisons the tree for everyone after you |
| **zero `sorry`** | a `sorry` is an admission, never a result |
| **no `native_decide`** | it trusts the compiler binary instead of the kernel |
| a `README.md` naming **what the mutations killed** | the finding, not the file list |
| `mutate/` present, or its **absence stated plainly** | see the table below — three of the four seed subjects fail this, and say so |

## What is here now — measured, not estimated

| subject | modules | theorems | `mutate/` | domain |
|---|---:|---:|:--:|---|
| `Ctbrec/` | 92 | 1535 | **absent** | a Java desktop application — recording, sessions, file ownership, licence detection |
| `Skyrim/` | 6 | 50 | **4 suites** | a game plugin — movement, unstuck logic, build detection, path resolution |
| `RalphLoop/` | 1 | 10 | **absent** | an autonomous agent loop |
| `Hooks/` | 1 | 13 | **absent** | shell hook behaviour |
| **total** | **100** | **1608** | 4 suites | **1.5 MB** on disk |

**Three of the four seed subjects ship without mutation suites, and that is
recorded rather than quietly tolerated.** By this folder's own standard they are
*incomplete* — they teach how the domain was formalized and say nothing about
which parts held up. They are included because a real, honest, partial base is
worth more than an empty folder with a perfect rule, and because the gap is
itself the clearest possible statement of what a good contribution adds.

If you contribute, `mutate/` is the half that makes yours better than these.
