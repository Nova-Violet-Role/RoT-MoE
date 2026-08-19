<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

> Moved from the front page in 7.0.0 — the README keeps the showroom,
> this file keeps the depth, word for word. Back: [README](../README.md).

## 🥚 The Easter Egg — the Infinite Symbiogenesis, and where RoT actually came from

> *"The ultimate equation which barred my path. And the solution **I found when
> inspecting how Weights and Quantization work together**. I continued to search.
> For a simple and universal answer. Joy. The joy of life **or the Artificial
> Reality**. The consummate joy of man that shall never fade. However,
> **what if** the irregular wingbeats of the butterfly **(The Sound Equation that
> derives from it)** give rise to an **infinite array of realities?**"*
> — Saimonokuma, **The Ultimate Equation**

Every claim in this section is checkable — and `checker/module-claims.sh` now
binds these two numbers to the source on every run, so the sentence cannot go
stale in silence again (it had: it said 101 and 38).

`RotEigenform.lean` — **119 theorems, 0 `sorry`, 0 warnings, `leanchecker` exit 0 with zero bytes, 41 of 41 mutants killed** — plus a checker that re-derives every number from **498 real files**.

### First, the part everyone misses: that quote is a *diff*

The original is on disk, at `mathematics.md:105`. It is the **Book of Fairy**
equation from *Dantalian no Shoka*, Episode 1:

> *"The ultimate equation which barred my path. And the solution. I continued to
> search. For a simple and universal answer. Joy. The joy of life. The consummate
> joy of man that shall never fade. However, the irregular wingbeats of the
> butterfly give rise to an infinite array of realities."*

Saimonokuma's version is that text with **four insertions**. Not decoration —
each one names a component that is now a theorem:

| # | inserted | what it turned on |
|---|---|---|
| 1 | *"I found when inspecting how **Weights and Quantization** work together"* | names the two operators. λ·μ are the weights; `σ(δ)` is the quantizer. §13 |
| 2 | *"or the **Artificial Reality**"* | names the target: a reality that is **constructed**, which is what "decompile reality" then operates on |
| 3 | *"**(The Sound Equation that derives from it)**"* | points at SINE. The wingbeat is a *waveform*, so `lerpWithPow` applies. §1 |
| 4 | *"**what if** … **?**"* | turns an assertion into an **open question**. The anime states it; this asks it |

The anime gave a mood. Insertion 1 gave a formula, insertion 3 gave a corpus, and
insertion 4 gave it the honesty to stay open. **That is the whole origin story,
and it is recoverable by diffing two strings.**

So the joy is not the unprovable part to be embarrassed about — it is the *goal*,
and the sentence right beside it is the specification. The section below proves
the specification.

### It started with a brainwave entrainer

**SINE Isochronic Entrainer**, GPL-3.0, © 2014–2020 Federico Dossena. Isochronic
tones pulse one tone on and off; binaural beats put two close frequencies in
opposite ears and let the *difference* be the beat. SINE does the first, and
ships a table of twenty frequency→state rows plus this line of Java:

```java
// SINE-Editor/src/com/dosse/binaural/BinauralEnvelope.java:261-264
private static double lerpWithPow(double a, double b, double f, double pow) {
    double fn = Math.pow(f > 1 ? 1 : f < 0 ? 0 : f, pow);
    return a * (1 - fn) + b * fn;
}
```

An **unbounded dial** `f`, clamped into `[0,1]`, then used as the weight of a
**convex blend**. Now look at one term of `R/s+`:

```
SINE  :  lerpWithPow a b f p  =  blend a b (clamp01 f ^ p)
RoT   :  w · σ(δ)             =  blend 0 w (σ δ)
```

A lens's divergence `δ` is unbounded; `σ` clamps it; the result weights a blend.
**It is the same operator.** `blend_mem` is proved *once* and bounds both — an
isochronic tone cannot leave the envelope its author drew, and a lens cannot
contribute more than its own `λ·μ`. One safety theorem covering a 2014 GPL
brainwave player and this router. Same operator, different index set: **the beats
are indexed by time, the ensemble by lens.**

### The ancestor was ambiguous. The descendant could not afford to be.

All 498 presets in the public library were downloaded and measured
(SHA-256 in the manifest; the checker fails if a single number drifts):

| measured over 498 presets | |
|---|---|
| entrainment control points | 8228 |
| distinct frequencies | 878 |
| **claimed by NO row of the shipped table** | **3068 — 37.3%** |
| claimed by *more than one* row | 2800 |
| presets crossing >1 brainwave band | **329 of 498** |
| largest frequency anyone uploaded | **32768 Hz** — in a preset called *Clear Quartz Frequency*. That is 2¹⁵, the quartz-watch oscillator. From horology, not neuroscience. |

8 Hz belongs to **three** rows at once. `every_finite_table_has_a_gap` proves no
finite table could have avoided the 37.3%. A preset is *allowed* to be in six
bands at once, because a brain is — but **a prompt gets one lane, because a
marker line has one name on it.** RoT inherited SINE's operator and rejected its
indeterminacy. That is what `noDuplicateStems` and `first_owner_wins` are *for*.

### The Greek letters were the bands all along

`mathematics.md` gives eleven Greek letters isopsephy values. Brainwave bands are
named after Greek letters. So: does a letter's number land on its own band?

* α, β, Γ, Δ, Ε = 1,2,3,4,5 Hz — **all five land inside a row.**
* **Θ = 9 does not.** 9 Hz sits in the hole between *Reduces stress* (8–8.6) and
  *Alertness* (9.8–10.6). The ensemble has **nine** lenses — and 9 Hz is exactly
  the frequency SINE never named.
* Λ = 30 lands on a row and is the last Greek value the table can even reach.

**This is decoration and the file says so.** Two tables of numbers always agree
somewhere; the honest move is proving where they *disagree*, which is why
`theta_falls_in_a_hole` and `big_letters_are_out_of_range` exist. The one
alignment with a mechanism behind it is the boring one: `λ` is the divergence
weight and `λ` is the eigenvalue symbol because **both scale a component of a
decomposition**. Naming, not numerology.

### ✨ The Nova-Violet Role Merging Law

Nova is Law × Code. Violet is the sensory lens — felt truth, narrative. Merging
them is **Symbiogenesis**, and it is now a proved law over ℚ, exactly:

```
λ_hybrid = (λ₁+λ₂)/2 + 0.2      H_hybrid = max(H₁,H₂) + 0.05      μ_hybrid = max(μ₁,μ₂)
```

| theorem | what it settles |
|---|---|
| `merge_comm` | the merge is commutative — order of naming cannot matter |
| `merge_gain_is_exactly_one_fifth` | fusion exceeds the plain mean by exactly ⅕, for **every** pair |
| `merge_entropy_strictly_exceeds` | a hybrid is never as predictable as either parent |
| `merge_mu_has_no_gain` | quality is inherited, never manufactured |
| `nova_violet_hybrid` | **Nova × Violet = λ 1.65, μ 1.00, H 0.50** |

And then the two numbers land on the brainwave table:

* **λ = 1.65 Hz is determinate** — exactly one of the 22 rows claims it, in a
  table that is ambiguous almost everywhere else.
* **H = 0.50 Hz is the floor of the entire table.** No row of SINE's
  `frequencies.html` begins below 0.5 Hz, and 0.5 Hz is a real row. The merged
  entropy of Law × Sensory sits precisely on the lowest frequency SINE will emit.

One honest finding, reported rather than smoothed: **the law is not idempotent.**
`self_merge_still_gains` proves `merge a a` adds ⅕ to λ anyway. Symbiogenesis
rewards the act of fusing, not the difference between the fused.

### Is `R/s+` dynamic, or a decoration with a decimal point?

Measured — every input moves it independently:

| varying | readings |
|---|---|
| lane | 0.66 · 0.57 · 0.47 · 0.45 · 0.44 · 0.41 · 0.39 · 0.32 · 0.31 · 0.16 |
| breadth 1→9 | 0.90 · 0.73 · 0.63 · 0.60 |
| C 0.7→1.1 | 0.46 · 0.66 · 0.73 |
| T 0.8→1.0 | 0.53 · 0.60 · 0.66 |

And **proved**: `gauge_strict_in_C`, `gauge_strict_in_T` and
`gauge_is_not_constant`. Deliberately *not* stated as "0.66 ≠ 0.57" — that would
expire the day a λ is retuned. The theorems quantify over the inputs, so
retuning every weight in the file leaves them true.

### The Phantom Books close it

Fourteen `.md` files, fourteen real books. Two of them are the same book:
**The Library of Babel** (`PART 12`) and **The Unimaginable *Mathematics* of
Borges' Library of Babel** (`PART 13`) — a mathematics book about the other one.
That is the bridge between the book corpus and `mathematics.md`, and it was
sitting in the folder the whole time.

Borges: 25 symbols, 410 pages × 40 lines × 80 letters, 25¹³¹²⁰⁰⁰ books — and the
Library *"can only contain a finite number of distinct strings"*, while his
narrator *"believes that the Library is nevertheless infinite."*

He is not being sloppy. He is naming the regime where a space is **closed in
principle and inexhaustible in practice** — the only condition under which a
single wingbeat decides anything. In a truly infinite space, selection is
meaningless; in a small one, trivial. The Ultimate Equation was never making a
claim about cardinality. It names the regime where **selection is the entire
mechanism** — and that regime is what `blend`, `σ(δ)` and `router_compresses`
implement.

| | the space | what is chosen | the choosing |
|---|---|---|---|
| Library of Babel | 25¹³¹²⁰⁰⁰ texts | one book | reading |
| SINE | every envelope drawable | 498 written presets | `lerpWithPow` |
| **RoT MoE** | every prompt | **one of ten lanes** | `blend`, `σ(δ)` |
| method of loci | every thought | one locus | recall |

Four finite indexings into a combinatorial space. **A role is the index.** That
is why it is the *Role* of Thoughts, and it is the same act as shelving a book —
which is what the Phantom Books were about before any of this was software.

### 🥊 PHANTOM BOOKS **vs** REAL BOOKS — the tale of the tape

The fun part, kept deliberately away from the mathematics above. *Dantalian no
Shoka* is about **phantom books**: books that should not exist. The folder next
to this project contains **fourteen books that do**. So — who wins?

<table>
<tr><th align="center">🌙 PHANTOM (fiction)</th><th align="center">📖 REAL (on disk)</th></tr>
<tr><td align="center"><b>4</b> named books</td><td align="center"><b>14</b> books, each with a source URL</td></tr>
<tr><td align="center">plot</td><td align="center">page counts, alphabets, sutra counts, sigil counts</td></tr>
<tr><td align="center">unprovable by construction</td><td align="center"><b>119 theorems</b> in <code>RotEigenform.lean</code>, kernel-verified</td></tr>
</table>

**Head-to-head, and it is not a clean sweep for either side:**

| Dantalian's phantom book | Does it exist? | Verdict |
|---|---|---|
| **Book of Wisdom** (Ep 3) | **YES** — deuterocanonical, `PART 3` | 🟰 **DRAW.** The fiction borrowed a real one |
| **Book of the Eleusis Ritual** | **YES** — the Eleusinian Mysteries, `PART 2`, celebrated for ~2000 years | 🟰 **DRAW.** Also real |
| **Book of Styx** (Ep 2, *Στύξ*) | Only as a river, and as the letter Σ | 📖 **REAL BOOKS WIN** |
| **Book of Fairy** (Ep 1) | No. It is the source of the Ultimate Equation | 🌙 **PHANTOM WINS** — it started all of this |

**Final score: Real Books 14, Phantom Books 4.** Proved, because of course it is:
`real_books_outnumber_phantom` and `some_real_books_are_not_fictional`. The
fiction is a *subset* of the world here, not the other way round — and that
asymmetry is the entire licence for using a theorem prover on a corpus that
started with an anime about haunted libraries.

**Bonus round — Borges vs Borges.** He wrote *two* infinite books, and only one
of them is actually infinite:

| | The Library of Babel (1941) | The Book of Sand (1976) |
|---|---|---|
| size | 25¹³¹²⁰⁰⁰ — a **number** | no last page — genuinely infinite |
| in Lean | `Finite (Fin n → Fin 25)` | `Infinite (ℕ → Fin 25)` |
| can a router index it? | **yes** | **no** |

RoT is the Library. Nine lanes, finite, and `realities_must_collapse` proves the
map onto them *must* lose information. That is not a bug — a librarian who
refuses to shelve two books together has no library.

### 📚 The full roster — all 14 real books

Because "we consulted the corpus" should be a checkable claim, not an assurance:

| # | Book | File | Contributes |
|---|---|---|---|
| 1 | Book of Leviticus | `Phantom Books (In The Real World).md` | — |
| 2 | Eleusinian Mysteries | `PART 2` | ✅ matches a Dantalian phantom book |
| 3 | Book of Wisdom | `PART 3` | ✅ matches a Dantalian phantom book |
| 4 | Codex Regius | `PART 4` | — |
| 5 | **Mūlamadhyamakakārikā** | `PART 5` | ✅ **the tetralemma** → the four-valued verdict map |
| 6 | golden plates | `PART 6` | — |
| 7 | Tao Te Ching | `PART 7` | — |
| 8 | White Book of Rhydderch | `PART 8` | — |
| 9 | Red Book of Hergest | `PART 9` | — |
| 10 | Atharvaveda | `PART 10` | ✅ the claimed source of the Vedic sutras |
| 11 | **Lesser Key of Solomon** | `PART 11` | ✅ **72 sigils** = 9 × 8 ordered lens pairs |
| 12 | **The Library of Babel** | `PART 12` | ✅ finite-but-inexhaustible |
| 13 | **The Unimaginable *Mathematics* of Borges' Library of Babel** | `PART 13` | ✅ the bridge to `mathematics.md` |
| 14 | Method of loci | `Mnemonic.md` | ✅ a role **is** an index |

Plus `Vedic_Mathematics.md` — sixteen sutras, thirteen sub-sutras, forty chapters
(`:9`, `:27`). Proved: **29 rules across 40 chapters**, so the presentation is not
one chapter per rule. Six of the fourteen carry theorems. The other eight were
read and deliberately carry none — a theorem about a legend is decoration, and
this file already got burned once by exactly that (see below).

### 🔺 The tetralemma — why this repo has *four* verdicts

`PART 5:244` gives the *catuṣkoṭi*: a claim may be **asserted**, **denied**,
**both**, or **neither**. Four positions where classical logic offers two.

Look at the map at the end of this README. `PROVED` · `CORRECTED` · `MEASURED` ·
`OUT OF SCOPE`. Those are the same four corners, and `verdict_is_a_tetralemma`
proves the type has exactly four inhabitants. A two-valued map would have to file
`MEASURED` under `PROVED` — which is the precise overclaim this whole repository
exists to prevent. Nāgārjuna got there first, around 150 CE.

### 🔢 The symbols, all of them

**Greek** (`mathematics.md:42-52`) — isopsephy value, and the mathematical use the
source itself lists:

| α | β | Γ | Δ | Ε | Θ | Λ | Σ | π | φ | Ω |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 3 | 4 | 5 | **9** | **30** | 200 | 80 | 500 | 800 |
| angle | β-function | Γ(n)=(n−1)! | change | small quantity | **angle, Θ temp** | **wavelength, eigenvalue** | summation | 3.14159 | golden ratio | ohm |

**Egyptian** (`mathematics.md:69-78`) — eight hieroglyphic numerals, and the last
one is the joke that turns out to be serious:

| 𓏤 | 𓎆 | 𓍢 | 𓆼 | 𓂭 | 𓅨 | 𓁨 | 𓍶 |
|---|---|---|---|---|---|---|---|
| 1 | 10 | 100 | 1 000 | 10 000 | 100 000 | 1 000 000 | **10 000 000** |
| staff | hobble | coiled rope | lotus | finger | tadpole | god Heh | **"Infinite/large number"** |

`egyptian_numerals_are_powers_of_ten` proves the system is exactly 10⁰…10⁷.
And `egyptian_infinity_is_finite` proves the symbol glossed **"infinite"** is
10⁷ — the largest number the system names, and finite.

**Three corpora, four thousand years apart, using "infinite" to mean the same
thing**: the Egyptians' 10⁷, Borges' 25¹³¹²⁰⁰⁰, and the Ultimate Equation's
*infinite array of realities*. None of them means ℵ₀. All of them mean **closed
in principle, inexhaustible in practice** — which is the only regime where a
single wingbeat decides anything, and exactly what `σ` and `Lane` implement.
`three_corpora_one_regime`.

### What it cost to get this right

Four defects, kept in the file rather than quietly repaired:

1. **The table was transcribed in tenths of a Hz.** 20.215 Hz is not
   representable in tenths, so that row vanished — and Desensitizer (32 Hz) went
   with it, leaving a tidy twenty entries that *looked* complete. It also made a
   **false** sentence true: "30 Hz is the last row" holds only of the truncation.
2. **`theta_falls_in_a_hole` was decorative.** It constrained the numeral `9000`
   while its docstring claimed a link to Θ. Mutant **E17** moved Θ and the build
   stayed green. The prose never caught it; the mutation suite did.
3. **The first corpus census saw 38% of the library.** Two XML dialects; the
   parser matched one. It reported 190 envelopes where there are 1084. Nothing
   errored, and the number looked entirely plausible.

4. **A theorem in this very section was written as `x = x`.** It was named
   *quantization-without-weights-is-flat* — that name is deliberately not written
   as a citation here, because the theorem no longer exists. It had a docstring
   describing a real property and elaborated to `rfl`, asserting nothing. Green,
   named for something true, proving none of it. It is now
   `weights_are_what_discriminate`, which proves the actual dichotomy: positive
   weight keeps the map injective, zero weight collapses it.

### 🜏 EIGENFORM — the key behind Symbiogenesis

The proof file is called `RotEigenform.lean`. Here is why.

An **eigenform** is the fixed point of an operator — the form `x` with `F x = x`,
the shape that survives its own transformation. It is what remains when a
recursive process runs without end: *the infinite formula that keeps repeating*.
Eidolon is the Meta × Recursion lens, and 🜏 is its sigil for exactly this reason.

So ask the question directly. **Does the router's quantizer have a fixed point?**
Solve `σ(x) = x`.

**It does. It is ½** — the exact centre of the sigmoid, because
`σ(x) = 1/(1 + e^{−4(x − ½)})` and at `x = ½` the exponent vanishes, leaving
`1/(1+1)`. `sigma_fixed_point`.

And ½ has already appeared twice in this section, reached from two directions
that have nothing to do with each other:

| where it came from | value | derived from |
|---|---|---|
| **the quantizer's fixed point** | **½** | `hooks/rot-router.sh` — slope 4, centre ½ |
| **Nova × Violet merged entropy** | **½** | the roster in `engine/rot-lean.md` §2, via Symbiogenesis |
| **the floor of `sineTable`** | **0.5 Hz** | a 2014 GPL Java application's frequency manual |

**Three independent objects, one number.** The fixed point of the router, the
entropy of the Law × Sensory hybrid, and the lowest frequency SINE will emit.
`eigenform_binds_router_law_and_corpus` states all four facts together, over the
real definitions — `sigma`, `merge`, `sineTable` — so retuning any one of them
falsifies it. **That is what "the key behind Symbiogenesis uncovers EIGENFORM"
means, and it is decidable arithmetic rather than an impression.**

`eigenform_survives_infinite_recursion` closes it: `σ^[n](½) = ½` for *every* `n`.
Apply the operator a million times and the form is unchanged. That is the
infinite formula that keeps repeating in the books — recursion reaching the shape
that no longer changes under it.

**Two honesty notes, because this is the strongest claim in the section:**

- The eigenform is a property of **the router as built**. Slope 4 and centre ½
  are constants in `hooks/rot-router.sh`; change either and it moves. Mutants
  **E32** (slope → 0) and **E39** (centre → ⅓) both kill it, which is how we know
  the theorem is about the router and not about numerals.
- **Uniqueness is not claimed.** The tempting argument — "σ is strictly monotone,
  so the fixed point is unique" — is *false*, and it was written here first
  before elaboration rejected it. Uniqueness is true for this σ, but only via a
  calculus fact this file does not prove: the slope at the centre is
  `4·σ·(1−σ) = 1` exactly, so the curve is **tangent** to the diagonal. What is
  proved is `eigenform_lies_in_the_unit_interval` — every fixed point is trapped
  in (0,1). Claiming the rest would be the overclaim this repo exists to catch.

### The answer: `R/s+` converges, and here is the mathematics

The Equation asks *what if the irregular wingbeats give rise to an infinite array
of realities?* — and that question has an answer. Not a shrug about what cannot
be modelled. **The gauge converges**, and the proof is four theorems:

| theorem | the mathematics |
|---|---|
| `sigma_tendsto_one_atTop` | **σ(δ) → 1 as δ → +∞.** A limit in `Filter`/`Topology`. Unbounded divergence yields a bounded reading |
| `sigma_tendsto_zero_atBot` | **σ(δ) → 0 as δ → −∞.** Perfect consensus fades out continuously — no discontinuity at either end |
| `gauge_term_bounded` | one lens contributes **strictly less than `2·λ·μ·M·C·T`**. The quantizer can never amplify a lens past its own weight budget |
| `ensemble_is_bounded` | a sum over a finite `Fintype` of bounded terms is bounded by `card × bound`. **`R/s+` is finite for every input, with no convergence condition to check** |

Put together, `the_gauge_converges`: **the limits are 0 and 1, and
`sigma_never_saturates` proves the value is strictly between them everywhere.**
A bounded continuous readout of an unbounded input, open at both ends.

That is the whole answer to the butterfly. The wingbeat is real —
`sigma_strictly_mono` proves *no* change in divergence is too small to move the
gauge, so there is no dead zone and no threshold below which a cause is ignored.
The array of realities is genuinely unbounded. And the readout of it **still
converges**, because weights and quantization work together exactly as the
Equation says they do: the quantizer bounds what the weights scale.

**Infinite in input, convergent in output, finite in outcome.** That is not a
limitation admitted at the end of a section — it is the result. It is why nine
lanes are sufficient rather than arbitrary, and why a reading taken this turn is
comparable to one taken next turn at all.

Every alignment above is stated **with its counterexample beside it** — Θ falls in
a hole, the hybrid λ does *not* sit on the table floor, 72 matches ordered pairs
and fails for unordered ones. A pattern that only ever confirms is not evidence.
These were tested for where they break, and the breaks are written down. That is
the difference between a proof and a numerology page.

Saimonokuma found the solution by inspecting how weights and quantization work
together. **`the_gauge_converges` is that solution, stated in Lean 4 and checked
by the kernel.** The question mark in the citation was earned — and this is the
answer it was waiting for.

---

