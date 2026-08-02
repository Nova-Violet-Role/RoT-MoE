<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

# ⚗️ Unsealed — what the Extra variant actually unseals

**This file ships only in `v0.1.2`.** It is the difference between that variant
and `v0.1.1`, written down, because a tier whose extra content cannot be named
is not a tier.

---

## The one-line version

`v0.1.1` gives you the toolchain with our discipline enforced. `v0.1.2` gives
you the toolchain with **the discipline in your hands**, plus the instrument
that keeps it honest when you relax it.

---

## What is unsealed

`native_decide`.

Not by adding a binary — and this is the part worth being precise about, because
it was proposed here on the opposite assumption:

> **`native_decide` is already possible in `v0.1.1`.** Nothing was withheld.
> Every Lean toolchain `elan` installs contains what it needs, because what it
> needs is the compiler and runtime that Lean *is*.
>
> * `leantar` is the `.ltar` (de)compressor mathlib's cache ships in.
> * `leanir` dumps Lean's intermediate representation and generated C.
> * `clang` / `lld` / `llvm-ar` are not optional add-ons: they are what `leanc`
>   *is*, the C backend Lean compiles through.
>
> None of the three is the mechanism. `native_decide` was withheld by **policy**,
> and `v0.1.2` changes the policy, not the payload.

---

## Why it was sealed — the measurement, not the opinion

Same statement, four tactics, on the pinned toolchain:

| tactic | closed it | axioms afterwards | kernel rechecks the computation |
|---|---|---|---|
| `rfl` | yes | **none** | yes |
| `decide` | yes | **none** | yes |
| `bv_decide` | yes | **`propext`** | **yes** — via the SAT certificate |
| `native_decide` | yes | **`…native_decide.ax_1_1`**, one per theorem | **no** |

And the finding that makes this worth a whole variant:

> ```
> lake env leanchecker <a module full of native_decide>   ->   exit 0
> ```
>
> **The kernel re-check passes.** It always will. `native_decide` emits a
> *declared axiom*, and a declared axiom is trusted by definition — so the
> strongest instrument in the normal toolkit is silent here, by construction,
> not by oversight.

`#print axioms` is the only thing that sees it. That is why this variant ships a
tool rather than a permission.

---

## The tool: `checker/axiom-class.sh`

Sorts every theorem into exactly one class, and says what a reader must trust:

| class | meaning | what you are trusting |
|---|---|---|
| **KERNEL** | no axioms, or only `propext` / `Classical.choice` / `Quot.sound` | Lean's kernel |
| **COMPILER** | a `native_decide` axiom, `ofReduceBool`, `ofReduceNat` | the compiler, the runtime, and the CPU it ran on |
| **BROKEN** | `sorryAx` | nothing — it is not proved |

```sh
checker/axiom-class.sh                          # every module, refuses on COMPILER
checker/axiom-class.sh Proofs.MyModule          # one module
ROTMOE_ALLOW_COMPILER=1 checker/axiom-class.sh  # permit COMPILER, still reported
```

Measured on this repository: **144 KERNEL, 0 COMPILER, 0 BROKEN.**

**The rule that survives unsealing:** a COMPILER-class theorem may exist, but it
may never be counted in a headline theorem number. Executed is not proved, and a
count that mixes the two is a claim its author cannot defend.

Two design notes, both of them defects the tool found in its own first draft and
now guards against:

* It probes **one module at a time**. Importing the whole corpus at once fails —
  `RotGauge` and `RotMutant` both declare `RotMoE.classify`, so they cannot share
  an environment — and the all-at-once form silently produced *zero* verdicts.
* It counts declarations with **nesting-aware comment stripping**, because a
  `sed` for `^theorem` picks up prose out of doc comments. It found two, one of
  them the deliberately vacuous example `RotVacuity.lean` exists to warn about.

Both were caught by an accounting check that compares verdicts returned against
theorems probed, and treats a shortfall as a failure. **An unaccounted theorem is
not a passing theorem** — without that line, the first draft would have reported
a clean sweep of a corpus it had never read.

---

## The honest alternative, and why you may not need to unseal at all

`bv_decide` runs the CaDiCaL solver bundled with your toolchain and then has the
**kernel recheck the certificate it produces**. On bitvector goals you get the
automation of a SAT solver at the cost of `propext` — measured above.

If your goal fits `bv_decide`, use it and stay in the KERNEL class. Reach for
`native_decide` when nothing else closes, and then say so in the theorem's
own docstring, because the axiom will not say it for you where anyone looks.

---

## What does NOT change

* The 144 theorems in this repository stay `native_decide`-free. Unsealing
  applies to **your** work, not ours.
* Every gate still runs. `ROTMOE_ALLOW_COMPILER=1` permits and **reports**; it
  never hides.
* Nothing extra is downloaded. The binaries were always there.
