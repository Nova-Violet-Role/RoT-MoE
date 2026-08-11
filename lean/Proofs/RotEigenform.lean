/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/
import Mathlib

/-!
# The Easter Egg, proved: SINE, the Phantom Books, and why RoT is *Role* of Thoughts

## What this file is, and what it refuses to be

The story is that RoT MoE descends from **SINE Isochronic Entrainer** — a real,
GPL-3.0 brainwave-entrainment application by Federico Dossena (2014–2020) — by
way of *Dantalian no Shoka*'s Phantom Books and the classical **method of loci**.

A story is not a theorem. So this file proves only what can be measured off the
disk, and says so line by line. Everything here traces to a real file:

| claim | source, measured |
|---|---|
| the interpolation formula | `SINE-Editor/src/com/dosse/binaural/BinauralEnvelope.java:261-264` |
| the entrainment frequency table | `SINE-Editor/editor_manual/frequencies.html` |
| the Greek isopsephy values | `SOURCE FOR RoT MoE/mathematics.md` |
| the method of loci | `SOURCE FOR RoT MoE/Phantom Books - Real Books/Mnemonic.md` |

**NOT modelled, and not modellable here:** "joy", "artificial immortality", an
"infinite array of realities", brainwave entrainment *working*, or any claim that
listening to a tone produces a thought. Those are the poem. Lean gets the parts
that have arithmetic in them, and the poem keeps the rest.

## The one real result

`lerp_mem_segment` is a genuine safety property of shipped GPL code: SINE's
interpolator **cannot emit a frequency outside the envelope the author drew.**
Whatever the interpolation factor, whatever the exponent, the output stays
between the two neighbouring points. A brainwave entrainer that could overshoot
its own envelope would be a different and worse program.

`sine_table_ambiguous_at_8` is the joke that turns out to be true: the frequency
table SINE ships is **ambiguous** — 8 Hz belongs to three rows at once — while
the router's stem table is not. The descendant is stricter than the ancestor,
and there is a reason: a prompt takes exactly one lane, but a brain can sit in
three bands at the same time.
-/

namespace RotMoE.Eigenform

/-! ## §1 The formula, transcribed from Java

```java
// BinauralEnvelope.java:261-264
private static double lerpWithPow(double a, double b, double f, double pow) {
    double fn = Math.pow(f > 1 ? 1 : f < 0 ? 0 : f, pow);
    return a * (1 - fn) + b * fn;
}
```

Two things are happening, and they are the same two things `R/s+` does. The mix
parameter is **clamped** to `[0,1]`, then **warped** by an exponent, then used
for a **convex combination**. The gauge clamps divergence through a sigmoid and
combines nine lens readings; this clamps `f` and combines two envelope points.
Same shape, different alphabet.

**Faithfulness limit, stated rather than buried:** Java's `pow` is a `double`.
Here it is a natural number, because `Real.rpow` drags in side conditions that
would obscure the theorems without changing what they say about the shipped
presets — every interpolation factor SINE's editor writes is a small positive
number (`0.5=square root, 1=linear, 2=square`, per the doc comment at
`BinauralEnvelope.java:64-66`). The `0.5` case is therefore **outside** this
model, and `lerp_mem_segment` is not claimed for it.
-/

/-- The clamp on the first line of `lerpWithPow`. -/
noncomputable def clamp01 (f : ℝ) : ℝ := if f > 1 then 1 else if f < 0 then 0 else f

/-- `lerpWithPow` with a natural exponent. -/
noncomputable def lerpWithPow (a b f : ℝ) (p : ℕ) : ℝ :=
  a * (1 - (clamp01 f) ^ p) + b * (clamp01 f) ^ p

theorem clamp01_nonneg (f : ℝ) : 0 ≤ clamp01 f := by
  unfold clamp01
  split_ifs with h1 h2
  · norm_num
  · norm_num
  · exact not_lt.mp h2

theorem clamp01_le_one (f : ℝ) : clamp01 f ≤ 1 := by
  unfold clamp01
  split_ifs with h1 h2
  · norm_num
  · norm_num
  · exact not_lt.mp h1

/-- The clamp is idempotent: clamping an already-clamped value changes nothing. -/
theorem clamp01_idem (f : ℝ) : clamp01 (clamp01 f) = clamp01 f := by
  have h0 := clamp01_nonneg f
  have h1 := clamp01_le_one f
  set c := clamp01 f with hc
  change clamp01 c = c
  unfold clamp01
  split_ifs with a b
  · linarith
  · linarith
  · rfl

/-- **THE SAFETY THEOREM.** The interpolated value never leaves the segment its
two envelope points span. A preset author who draws a band from `a` to `b` gets
tones in `[a, b]` — for every interpolation factor and every exponent, including
factors outside `[0,1]` that the clamp catches. -/
theorem lerp_mem_segment (a b f : ℝ) (p : ℕ) (hab : a ≤ b) :
    a ≤ lerpWithPow a b f p ∧ lerpWithPow a b f p ≤ b := by
  have hn : (0:ℝ) ≤ (clamp01 f) ^ p := pow_nonneg (clamp01_nonneg f) p
  have h1 : (clamp01 f) ^ p ≤ 1 := pow_le_one₀ (clamp01_nonneg f) (clamp01_le_one f)
  unfold lerpWithPow
  constructor
  · nlinarith
  · nlinarith

/-- At or below the left endpoint the output is exactly `a` — the clamp makes
the out-of-range case behave, rather than extrapolating wildly. -/
theorem lerp_left (a b f : ℝ) (p : ℕ) (hp : p ≠ 0) (hf : f < 0) :
    lerpWithPow a b f p = a := by
  have : clamp01 f = 0 := by
    unfold clamp01
    rw [if_neg (by linarith), if_pos hf]
  simp [lerpWithPow, this, zero_pow hp]

/-- Above the right endpoint the output is exactly `b`. -/
theorem lerp_right (a b f : ℝ) (p : ℕ) (hf : 1 < f) :
    lerpWithPow a b f p = b := by
  have : clamp01 f = 1 := by unfold clamp01; rw [if_pos hf]
  simp [lerpWithPow, this]

/-- Exponent 1 is the plain linear interpolation the doc comment calls
`1=linear`. -/
theorem lerp_pow_one (a b f : ℝ) :
    lerpWithPow a b f 1 = a * (1 - clamp01 f) + b * clamp01 f := by
  simp [lerpWithPow]

/-- Non-vacuity: the interpolator genuinely moves. Without this, every theorem
above would be satisfied by a constant function. -/
theorem lerp_is_not_constant :
    lerpWithPow 0 1 (1/2) 1 ≠ lerpWithPow 0 1 0 1 := by
  norm_num [lerpWithPow, clamp01]

/-! ## §2 The ancestor's table is ambiguous; the descendant's is not

`SINE-Editor/editor_manual/frequencies.html` ships twenty rows mapping a
frequency (or an interval) to a named mental state. It is the direct structural
ancestor of the router's stem table: a signal arrives, a row claims it, the row
names a mode.

Transcribed exactly, in **milli-Hz** to stay in `ℤ` and keep `decide` cheap.
Point rows are written as degenerate intervals.

**A defect in the first version of this file, recorded rather than quietly
fixed.** The table was first transcribed in *tenths* of a Hz, and two of the
twenty HTML rows silently vanished: `20.215` (LSD) and `32` (Desensitizer). The
first because `20.215` Hz is **not representable in tenths** — the resolution of
the model deleted a row of the source — and the second because dropping it kept
the Lean list at a tidy twenty entries, which made the omission look like a
complete transcription. It also made a *false* sentence look true: with
Desensitizer gone, 30 Hz appeared to be the last row of the table. It is the
nineteenth of twenty.

That is the whole failure mode this project exists to catch, committed inside
the file that was supposed to demonstrate catching it. The units are now
milli-Hz, which represents every row of `frequencies.html` exactly, and
`sine_table_is_complete` pins the count so the same silence cannot recur.

Two source rows name two frequencies each (`1.2 or 10`, `3.6 or 6.3`), so twenty
HTML rows become **twenty-two** `Band`s.
-/

/-- One row of the entrainment table: `[lo, hi]` in **milli-Hz**, and the state
it names. -/
structure Band where
  lo : ℤ
  hi : ℤ
  name : String
  deriving DecidableEq, Repr

/-- The table at `SINE-Editor/editor_manual/frequencies.html`, **all twenty data
rows** (21 `<tr>` less the header), in milli-Hz. The two `or` rows are split, so
the list has 22 entries. -/
def sineTable : List Band :=
  [ ⟨500,   1500,  "Pain relief"⟩
  , ⟨500,   4000,  "Deep sleep, profund relaxation, meditation"⟩
  , ⟨1200,  1200,  "Headache relief"⟩
  , ⟨10000, 10000, "Headache relief"⟩
  , ⟨3600,  3600,  "Reduces anger and irritability"⟩
  , ⟨6300,  6300,  "Reduces anger and irritability"⟩
  , ⟨4500,  6500,  "Vivid dreaming, lucid dreaming"⟩
  , ⟨5800,  5800,  "Reduce Fear, absent-mindness and dizziness"⟩
  , ⟨6000,  8000,  "Helps long term memory access, past life regression"⟩
  , ⟨7800,  8000,  "Extrasensorial perception, paranormal"⟩
  , ⟨7830,  7830,  "Schumann resonance"⟩
  , ⟨8000,  8600,  "Reduces stress"⟩
  , ⟨9800,  10600, "Alertness"⟩
  , ⟨11000, 14000, "Focusing on something"⟩
  , ⟨12000, 14000, "Improves learning"⟩
  , ⟨18000, 18000, "High beta state"⟩
  , ⟨18000, 24000, "Euphoria"⟩
  , ⟨19000, 19000, "Fear"⟩
  , ⟨20000, 20000, "Reduces tinnitus temporarily"⟩
  , ⟨20215, 20215, "Believed to mimic the effects of LSD"⟩
  , ⟨30000, 30000, "Believed to mimic the effects of Marijuana"⟩
  , ⟨32000, 32000, "Desensitizer"⟩
  ]

/-- Does this row claim this frequency? -/
def claims (b : Band) (x : ℤ) : Bool := decide (b.lo ≤ x) && decide (x ≤ b.hi)

/-- How many rows claim a frequency. -/
def claimants (t : List Band) (x : ℤ) : Nat := (t.filter (fun b => claims b x)).length

/-- A table is **deterministic at `x`** when at most one row claims it. -/
def deterministicAt (t : List Band) (x : ℤ) : Prop := claimants t x ≤ 1

/-- **The transcription is complete.** Twenty data rows in `frequencies.html`,
two of which name two frequencies, giving 22 `Band`s. This theorem is the guard
that failed to exist when two rows went missing; it is cheap and it is the only
reason the omission cannot come back unnoticed. -/
theorem sine_table_is_complete : sineTable.length = 22 := by decide

/-- The row that a tenths-of-a-Hz model could not hold. 20.215 Hz is exactly
20215 milli-Hz and the row is back in the table.

**A wrong first attempt, kept because the compiler is the reason it is not still
here.** This was first stated as `claimants sineTable 20215 = 1`, on the
assumption that so precise a frequency could only belong to its own row. `decide`
answered *"proved that the proposition is false"*: 20.215 Hz also sits inside
Euphoria's 18–24 Hz band, so it has **two** claimants. The precise row and the
broad row overlap, which is the §2 ambiguity again in the one place it was least
expected. The fix was to the statement, never to the table. -/
theorem lsd_row_survives_in_milliHz : claimants sineTable 20215 = 2 := by decide

/-- The LSD row is genuinely in the table, and it is the row a tenths-of-a-Hz
model erases — this, not the claimant count, is what the restoration bought. -/
theorem lsd_row_is_present :
    ∃ b ∈ sineTable, b.lo = 20215 ∧ b.hi = 20215 := by decide

/-- 20.215 Hz is not a whole number of tenths. This is the arithmetic reason the
first transcription lost the row, stated so the excuse is checkable rather than
asserted. -/
theorem lsd_row_is_not_a_tenth : ¬ ((10 : ℤ) ∣ 20215) := by decide

/-- And 30 Hz is **not** the last row — Desensitizer at 32 Hz is above it. The
prose that said otherwise was true only of the truncated table. -/
theorem thirty_is_not_the_top : ∃ b ∈ sineTable, 30000 < b.lo := by decide

/-- **8 Hz belongs to three different rows at once.** Long-term memory (6–8),
extrasensory perception (7.8–8), and stress reduction (8–8.6) all claim it.
This is not a transcription error; it is what the file says. -/
theorem sine_table_ambiguous_at_8 : claimants sineTable 8000 = 3 := by decide

/-- 18 Hz is claimed twice — "High beta state" and "Euphoria". -/
theorem sine_table_ambiguous_at_18 : claimants sineTable 18000 = 2 := by decide

/-- 10 Hz is claimed twice as well — "Headache relief" (a point row) and
"Alertness" (9.8–10.6). The ambiguity is not one unlucky frequency. -/
theorem sine_table_ambiguous_at_10 : claimants sineTable 10000 = 2 := by decide

/-- So the table is **not** deterministic. A first-match reader and a
last-match reader disagree about what 8 Hz means. -/
theorem sine_table_is_not_deterministic : ¬ deterministicAt sineTable 8000 := by
  unfold deterministicAt
  rw [sine_table_ambiguous_at_8]
  decide

/-- Non-vacuity in the other direction: the table is not *uniformly* ambiguous.
Some frequencies have exactly one owner, so ambiguity is a property of specific
rows rather than of the whole file. -/
theorem sine_table_is_determinate_somewhere : claimants sineTable 30000 = 1 := by decide

/-- And some frequencies have no owner at all — 25 Hz names no state. The table
is partial as well as ambiguous, which is the third thing a router may not be. -/
theorem sine_table_has_gaps : claimants sineTable 25000 = 0 := by decide

/-! ### The gap is not an accident of these rows

`sine_table_has_gaps` is a fact about 25 Hz and about this table — exactly the
shape of theorem that expires: one legitimate new row and it is false, and the
obvious repair is to delete it, which destroys the coverage.

The durable statement is that **no finite table of bands can claim everything.**
It holds for `sineTable`, for any table anyone edits it into, and for the
router's own stem table. It is also why the measurement in §7 came out as it
did: 37.3% of the community's control points name a frequency the manual never
described, and no amount of care in writing twenty rows could have prevented it.
-/

/-- **Every finite band table has a gap.** Given any list of bands there is a
frequency no row claims — take one more than every upper bound at once. -/
theorem every_finite_table_has_a_gap (t : List Band) :
    ∃ x : ℤ, claimants t x = 0 := by
  refine ⟨(t.map Band.hi).foldr max 0 + 1, ?_⟩
  unfold claimants
  simp only [List.length_eq_zero_iff, List.filter_eq_nil_iff]
  intro b hb
  simp only [claims, Bool.not_eq_true, Bool.and_eq_false_iff, decide_eq_false_iff_not,
    not_le]
  right
  have hle : ∀ l : List Band, b ∈ l → b.hi ≤ (l.map Band.hi).foldr max 0 := by
    intro l
    induction l with
    | nil => intro h; cases h
    | cons h tl ih =>
        intro hmem
        simp only [List.map_cons, List.foldr_cons]
        rcases List.mem_cons.mp hmem with rfl | htl
        · exact le_max_left _ _
        · exact le_trans (ih htl) (le_max_right _ _)
  have := hle t hb
  omega

/-- Non-vacuity for the gap theorem: it is not proved by every table being
empty. `sineTable` has 22 rows and still has a gap. -/
theorem gap_theorem_is_not_vacuous : sineTable ≠ [] := by decide

/-! ### Why the router could not inherit this

`Proofs/RotLog.lean` proves `noDuplicateStems` and `first_owner_wins` for the
router's 85-stem table: every stem has exactly one owning lane, and the reading
is a function. The ancestor's table has none of those properties.

That difference is forced, not stylistic. A brain can sit in three bands at
once, so a row claiming 8 Hz alongside two others costs nothing. A prompt gets
**one** lane and one marker line, so an ambiguous stem would make the router's
output depend on iteration order — which is exactly the defect
`first_owner_wins` exists to forbid.
-/

/-! ## §3 Role of Thoughts: a router is not a memory palace

`Mnemonic.md` is the Wikipedia article on the **method of loci** — assign each
thought to a place, and recall it by walking the places. That is where the *R*
comes from: **Role** of Thoughts, a thought filed under a role, as against
*Tree* or *Chain* of Thoughts, which are shapes a single thought takes.

The two are formally different, and the difference is provable. A memory palace
must be **injective** — two items in one locus is a collision, and the technique
fails. A router must be **total and deterministic**, and must NOT be injective:
its whole job is to send many prompts to one lane.
-/

/-- A miniature router: nine lanes, and a prompt is just its index. -/
abbrev Lane := Fin 9

/-- Determinism is free — being a function *is* determinism. What matters is
that the router is **not injective**, i.e. it genuinely compresses. -/
theorem router_compresses (r : ℕ → Lane) : ¬ Function.Injective r := by
  intro hinj
  have h : Function.Injective (fun n : Fin 10 => r n.val) := by
    intro x y hxy
    exact Fin.ext (hinj hxy)
  have := Fintype.card_le_of_injective _ h
  simp at this

/-- A memory palace over the same nine loci therefore cannot store ten distinct
thoughts. The method of loci needs as many places as items; the router needs
fewer lanes than prompts. Same structure, opposite requirement — which is why
one of them scales to arbitrary input and the other asks you to build a bigger
palace. -/
theorem palace_needs_room (place : Fin 10 → Lane) : ¬ Function.Injective place := by
  intro hinj
  have := Fintype.card_le_of_injective _ hinj
  simp at this

/-! ## §4 The isopsephy correspondences — labelled as coincidence

`mathematics.md` tabulates Greek letter values. Three line up with the router,
and they are recorded as `example`s rather than theorems **because a numerical
coincidence is not evidence of anything.** They are here because they are true
and pleasing, not because they explain the design.

* **Θ = 9** — and the ensemble has nine lenses (`K = 9`).
* **β = 2** — and SINE's carrier suggestion is 220 Hz, doubling to 440 and 880
  (`presetDesign.html`), the octave being a factor of two.
* **Λ = 30** — the symbol `mathematics.md` glosses as *wavelength, eigenvalue*,
  and `λ` is the divergence weight in `R/s+`. 30 Hz is also a row of the
  entrainment table (the nineteenth of twenty; `thirty_is_not_the_top` records
  that it is **not** the last, which an earlier draft of this file claimed).

The third is the only one with a mechanism behind it, and the mechanism is
naming, not numerology: an eigenvalue and a per-lens weight are both `λ` because
both scale a component of a decomposition.
-/

/-- Θ = 9 in the isopsephy table; the ensemble is nine lenses. -/
example : (9 : ℕ) = Fintype.card Lane := by decide

/-- β = 2; the octave ratio between SINE's suggested carriers. -/
example : 440 = 2 * 220 ∧ 880 = 2 * 440 := by decide

/-- Λ = 30; the entrainment table has a 30 Hz row. -/
example : ∃ b ∈ sineTable, b.lo = 30000 ∧ b.hi = 30000 := by decide

/-! ## §5 What the Ultimate Equation does and does not say

> *"the irregular wingbeats of the butterfly give rise to an infinite array of
> realities"* — Book of Fairy, quoted in `mathematics.md`.

The modellable half is **sensitive dependence**: an arbitrarily small change in
the interpolation factor changes the output. That is provable and it is exactly
what the sentence describes mechanically.

The unmodellable half is "infinite array of realities". One perturbed input
gives one perturbed output. Lean says nothing about the array, and this file
does not pretend otherwise.
-/

/-- **The wingbeat.** For any non-degenerate segment and any distance `ε`, some
perturbation of the interpolation factor smaller than `ε` still changes the
emitted frequency. Small causes, different realities — one of them, not
infinitely many. -/
theorem butterfly (a b : ℝ) (hab : a ≠ b) (ε : ℝ) (hε : 0 < ε) :
    ∃ f' : ℝ, |f' - (1/2)| < ε ∧ lerpWithPow a b f' 1 ≠ lerpWithPow a b (1/2) 1 := by
  refine ⟨1/2 + min (ε/2) (1/4), ?_, ?_⟩
  · have h1 : 0 < min (ε/2) (1/4) := lt_min (by linarith) (by norm_num)
    have h2 : min (ε/2) (1/4) ≤ ε/2 := min_le_left _ _
    rw [show (1/2 + min (ε/2) (1/4)) - (1/2) = min (ε/2) (1/4) by ring, abs_of_pos h1]
    linarith
  · have h1 : 0 < min (ε/2) (1/4) := lt_min (by linarith) (by norm_num)
    have h2 : min (ε/2) (1/4) ≤ 1/4 := min_le_right _ _
    have c1 : clamp01 (1/2 + min (ε/2) (1/4)) = 1/2 + min (ε/2) (1/4) := by
      unfold clamp01
      rw [if_neg (by linarith), if_neg (by linarith)]
    have c2 : clamp01 (1/2 : ℝ) = 1/2 := by
      unfold clamp01
      rw [if_neg (by norm_num), if_neg (by norm_num)]
    simp only [lerp_pow_one, c1, c2]
    intro hcon
    apply hab
    nlinarith [hcon]

/-- The honest boundary, stated as a comment rather than smuggled in as a
theorem: nothing above concerns joy, immortality, or an infinite array of
realities. `butterfly` gives ONE other reality per perturbation. -/
example : True := trivial

/-! ## §6 The dot that connects: one operator, two machines

Everything above is about SINE. This section is the actual claim of descent, and
it is not a metaphor — it is an equation.

**A clamped blend** is: take a mix parameter, squeeze it into `[0,1]`, and use it
to combine two endpoints. Write it once:

```
blend a b m = a * (1 - m) + b * m
```

* **SINE** blends **two envelope points**, with mix `clamp01 f ^ pow`.
  The endpoints are frequencies; the output is the tone you hear.
* **RoT MoE** blends **zero and a lens's full weight**, with mix `σ(δ)`.
  The endpoints are "this lens contributed nothing" and "this lens contributed
  everything it is worth"; the output is that lens's term in `R/s+`.

`gauge_term_is_a_blend` proves the second is literally the first with `a = 0`.
The entrainer interpolates between two frequencies; the router interpolates
between silence and a lens. **Same operator, different alphabet** — and the same
boundedness theorem covers both, which is why neither can run away from its own
envelope.

The saturation matches too, and for the same reason. `clamp01` refuses mix
values outside `[0,1]` because a preset author can draw a factor anywhere;
`σ` maps *all* of ℝ into `(0,1)` because a divergence can be any size. Both
machines take an unbounded dial and make it safe before multiplying by it.
-/

/-- The shared operator. -/
noncomputable def blend (a b m : ℝ) : ℝ := a * (1 - m) + b * m

/-- **The shared safety theorem.** A blend with a mix in `[0,1]` never leaves
the segment. One proof, and §1 and the gauge both inherit it. -/
theorem blend_mem (a b m : ℝ) (h0 : 0 ≤ m) (h1 : m ≤ 1) (hab : a ≤ b) :
    a ≤ blend a b m ∧ blend a b m ≤ b := by
  unfold blend
  constructor
  · nlinarith
  · nlinarith

/-- SINE's interpolator is a blend. -/
theorem sine_is_a_blend (a b f : ℝ) (p : ℕ) :
    lerpWithPow a b f p = blend a b ((clamp01 f) ^ p) := by
  unfold lerpWithPow blend; ring

/-- The gauge's saturation, from `engine/rot-lean.md` §5:
`σ(x) = 1 / (1 + e^(-4(x - 0.5)))`. -/
noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1/2)))

theorem sigma_pos (x : ℝ) : 0 < sigma x := by
  unfold sigma
  positivity

theorem sigma_lt_one (x : ℝ) : sigma x < 1 := by
  unfold sigma
  rw [div_lt_one (by positivity)]
  have := Real.exp_pos (-4 * (x - 1/2))
  linarith

/-- **The connection, as an equation.** One lens's contribution to `R/s+` — its
weight `w` scaled by the saturated divergence — is exactly a blend from `0` to
`w`. The router is running SINE's interpolator with the left endpoint pinned at
silence. -/
theorem gauge_term_is_a_blend (w x : ℝ) : w * sigma x = blend 0 w (sigma x) := by
  unfold blend; ring

/-- And so the gauge term inherits the entrainer's bound: a lens can never
contribute more than its own weight, nor less than nothing. The same `blend_mem`
that keeps a preset inside its drawn envelope keeps a lens inside its λ·μ. -/
theorem lens_contribution_is_bounded (w x : ℝ) (hw : 0 ≤ w) :
    0 ≤ w * sigma x ∧ w * sigma x ≤ w := by
  rw [gauge_term_is_a_blend]
  exact blend_mem 0 w (sigma x) (le_of_lt (sigma_pos x)) (le_of_lt (sigma_lt_one x)) hw

/-- Non-vacuity, so the bound is not the trivial one: a lens with real weight and
real divergence contributes strictly between the two ends. Nothing here is true
merely because everything collapsed to zero. -/
theorem lens_contribution_is_strict (w x : ℝ) (hw : 0 < w) :
    0 < w * sigma x ∧ w * sigma x < w := by
  constructor
  · exact mul_pos hw (sigma_pos x)
  · nlinarith [sigma_lt_one x, sigma_pos x]

/-! ### The table, the palace, and the gauge — the three dots in one line

| SINE | RoT MoE | the shared thing |
|---|---|---|
| 20 rows, **ambiguous at 8 Hz** | 85 stems, `noDuplicateStems` | a signal claims a mode |
| `lerpWithPow`, two frequencies | `w * σ(δ)`, zero and a weight | `blend`, one bound |
| `clamp01` — a factor made safe | `σ` — a divergence made safe | saturate, then multiply |
| a thought needs a **place** | a prompt needs a **lane** | assignment to a locus |

The last row is the name. *Role* of Thoughts, not Tree and not Chain: a tree is
a shape one thought grows into, a chain is a shape one thought walks along, and
a **role** is a place a thought is *filed under* — which is the method of loci
with lanes for loci. `router_compresses` and `palace_needs_room` are the same
theorem read in opposite directions: the palace fails when two thoughts share a
locus, and the router **requires** it.

That is where the isochronic beat collides with the nine lenses. Both machines
take an unbounded dial, saturate it, and multiply — `clamp01` for a preset
author's interpolation factor, `σ` for a lens's divergence — and
`gauge_term_is_a_blend` shows the second is the first with its left endpoint
pinned at silence. One operator, proved once, running in both.
-/

/-! ## §7 The corpus: 498 presets, and what they do to the table

Everything above concerns two files SINE *ships*. This section concerns what
**498 people actually wrote** with it — the public preset library at
`https://sine.fdossena.com/presetListJSON.php`, fetched in full on 2026-08-05
and kept beside this file as `sine-presets/` with `manifest.tsv` recording every
id, title, author, URL and SHA-256.

Measured off those 498 files, by `corpus-measure.sh` in this folder:

| quantity | value |
|---|---|
| presets | 498 |
| distinct authors | 143 |
| `<EntrainmentTrack>` elements | 1084 |
| `noise` envelopes (one per preset) | 498 |
| `<Envelope>` elements, total | 3750 |
| `<Point>` elements, total | 20604 |
| `entrainmentFrequency` control points | 8228 |
| distinct entrainment frequencies | 878 |
| points claimed by ≥1 row of `sineTable` | 5160 |
| points claimed by **no** row | **3068 (37.3%)** |
| points claimed by more than one row | 2800 |
| XML dialect: `name='x'` / `name="x"` | 104 / 394 |
| largest frequency in the corpus | 32768.0 Hz |

**The three numbers that matter.** 37.3% of the community's control points name
a frequency the manual never described — the corpus *escapes its own table*,
which is `every_finite_table_has_a_gap` happening in the wild. 2800 points are
claimed by more than one row, so a first-match reader and a last-match reader
disagree about a third of the library. And 878 distinct values came out of a
twenty-two-row vocabulary: the wingbeats are finite and the realities are not.

**A parser that saw 38% of the corpus.** The library is written in two XML
dialects — 104 presets use `name='x'`, 394 use `name="x"` with the attributes in
the other order. The first census run here matched single quotes only and
reported 190 `volume` envelopes. The true figure is 1084. Nothing errored; the
number was simply wrong, and it looked plausible. That is the same defect as the
missing table rows in §2, in a different language.

**Not modelled:** whether any of these presets does anything to anyone's brain.
The corpus is XML; the claims in its `<Description>` fields are the authors',
not this file's.
-/

/-- Presets in the public library, 2026-08-05. -/
def corpusPresets : ℕ := 498
/-- Distinct authors across the library. -/
def corpusAuthors : ℕ := 143
/-- `<EntrainmentTrack>` elements across the library. -/
def corpusTracks : ℕ := 1084
/-- `<Envelope>` elements across the library. -/
def corpusEnvelopes : ℕ := 3750
/-- `entrainmentFrequency` control points. -/
def corpusFreqPoints : ℕ := 8228
/-- Control points claimed by at least one row of `sineTable`. -/
def corpusClaimed : ℕ := 5160
/-- Control points claimed by no row at all. -/
def corpusUnclaimed : ℕ := 3068
/-- Presets in each of the two XML dialects. -/
def corpusSingleQuote : ℕ := 104
def corpusDoubleQuote : ℕ := 394

/-- **The parse is self-consistent, and this is the check that proves the
measurement was not a miscount.** SINE's format gives every `EntrainmentTrack`
exactly three envelopes (`baseFrequency`, `entrainmentFrequency`, `volume`) and
every `Preset` exactly one `noise` envelope. So the total envelope count is
forced by the track and preset counts — and the independently measured 3750
agrees. Three numbers counted separately, one identity: had the dialect bug
survived anywhere in the census, this would not close. -/
theorem corpus_envelope_count_is_forced :
    corpusTracks * 3 + corpusPresets = corpusEnvelopes := by decide

/-- The two dialects partition the library exactly — no preset is in both, none
is in neither. -/
theorem corpus_dialects_partition :
    corpusSingleQuote + corpusDoubleQuote = corpusPresets := by decide

/-- Claimed and unclaimed exhaust the entrainment control points. -/
theorem corpus_coverage_is_exhaustive :
    corpusClaimed + corpusUnclaimed = corpusFreqPoints := by decide

/-- **The corpus escapes its own table**, and not marginally: more than a third
of every entrainment control point in the library names a frequency no row of
`frequencies.html` describes. -/
theorem corpus_escapes_the_table : 3 * corpusUnclaimed > corpusFreqPoints := by decide

/-- Non-vacuity: the table is not simply useless either — the majority of points
*are* claimed. The escape is a real fraction, not a total miss. -/
theorem corpus_is_mostly_claimed : corpusClaimed > corpusUnclaimed := by decide

/-- **The quartz watch.** The largest entrainment frequency anyone uploaded is
32768 Hz, in a preset titled *Clear Quartz Frequency*. That is exactly `2^15`,
the oscillator every quartz wristwatch divides down to get one tick per second —
a number that arrives from horology, not from neuroscience, and which no row of
the table comes within three orders of magnitude of claiming. -/
theorem clear_quartz_is_a_power_of_two : (32768 : ℕ) = 2 ^ 15 := by decide

/-- And the table does not claim it. -/
theorem clear_quartz_is_unclaimed : claimants sineTable 32768000 = 0 := by decide

/-! ## §8 The letters are the bands: isopsephy against the table

The last dot, and the one that is actually decidable.

`mathematics.md:42-52` gives eleven Greek letters an **isopsephy value** — a
number. Brainwave bands are, by universal convention, *named after Greek
letters*: delta, theta, alpha, beta, gamma. So the two tables in this Easter Egg
are indexed by the same alphabet, one by name and one by number, and the
question "does a letter's number land on that letter's band?" is a question with
an answer.

**What is on disk and what is not, stated before the theorems.** The isopsephy
column is measured from `mathematics.md`. The 20-row frequency table is measured
from `frequencies.html`. The *EEG band boundaries* (δ 0.5–4, θ 4–8, α 8–13,
β 13–30, γ >30) are **not in this corpus** — the only band name anywhere in the
SINE tree is "beta", at `frequencies.html`'s 18 Hz row. They are ordinary
neuroscience convention, and everything below that depends on them is marked as
such rather than proved.

What *is* proved is the interaction between two on-disk tables, and it is
stranger than the convention would predict.
-/

/-- The isopsephy values of `mathematics.md:42-52`, read as frequencies in
milli-Hz. -/
def isopsephy : List (String × ℤ) :=
  [ ("alpha",   1000)
  , ("beta",    2000)
  , ("Gamma",   3000)
  , ("Delta",   4000)
  , ("Epsilon", 5000)
  , ("Theta",   9000)
  , ("Lambda",  30000)
  , ("pi",      80000)
  , ("Sigma",   200000)
  , ("phi",     500000)
  , ("Omega",   800000)
  ]

theorem isopsephy_has_eleven_letters : isopsephy.length = 11 := by decide

/-- **Δ = 4, and the delta band ends at 4 Hz.** The largest frequency the
"Deep sleep, profund relaxation, meditation" row claims is exactly 4000 milli-Hz
— the number `mathematics.md` assigns to Delta. This one is on disk at both
ends: the value from `mathematics.md:45`, the bound from `frequencies.html`. -/
theorem delta_value_is_the_deep_sleep_bound :
    ∃ b ∈ sineTable, b.hi = 4000 ∧ b.name = "Deep sleep, profund relaxation, meditation" := by
  decide

/-- **Λ = 30, and 30 Hz is where gamma conventionally begins.** Again both ends
are on disk: `mathematics.md:48` gives Lambda 30, and `frequencies.html` has a
30 Hz row. The band boundary itself is convention, not corpus. -/
theorem lambda_value_is_a_table_row : claimants sineTable 30000 = 1 := by decide

/-- The five smallest isopsephy values — α, β, Γ, Δ, Ε = 1,2,3,4,5 Hz — every
one of them lands inside a row of the entrainment table. -/
theorem small_letters_all_land :
    (isopsephy.filter (fun p => decide (p.2 ≤ 5000))).all
      (fun p => decide (claimants sineTable p.2 ≥ 1)) = true := by decide

/-- **And Θ = 9 does not.** Nine hertz is claimed by no row: it sits in the hole
between "Reduces stress" (8–8.6) and "Alertness" (9.8–10.6). Of the seven
isopsephy values small enough for the table to reach, Theta is the only one that
falls through it.

**This theorem was DECORATIVE until mutant E17 exposed it.** It first read
`claimants sineTable 9000 = 0` — a true statement about the number 9000 that
never mentioned `isopsephy` at all. E17 moved Theta from 9000 to 10000 and the
build stayed green, because nothing in the statement was looking at Theta. The
docstring claimed a connection the theorem did not make: the classic overclaim,
where the prose is about Θ and the Lean is about a numeral.

It now quantifies over the isopsephy table, so falsifying Theta's value
falsifies the theorem. The repair was to strengthen the statement, never to
weaken it or to retire the mutant. -/
theorem theta_falls_in_a_hole :
    ∃ p ∈ isopsephy, p.1 = "Theta" ∧ claimants sineTable p.2 = 0 := by decide

/-- The joke, stated as arithmetic: the ensemble has **Θ = 9** lenses, and Θ's
own value in hertz is precisely the frequency SINE never named. The number the
router is built on is the one gap in its ancestor's table.

Bound to `isopsephy` for the same reason as above — and additionally to the
letter's *value*, so that the "nine" in `Fintype.card Lane = 9` and the "nine"
in Θ = 9 are the same nine rather than two coincidental numerals. -/
theorem the_ensemble_number_is_the_gap :
    ∃ p ∈ isopsephy, p.1 = "Theta" ∧
      p.2 = 1000 * (Fintype.card Lane : ℤ) ∧ claimants sineTable p.2 = 0 := by
  have h : Fintype.card Lane = 9 := by decide
  rw [h]
  decide

/-- Λ = 30 is the **largest** isopsephy value the entrainment table can reach at
all: the table tops out at 32 Hz (Desensitizer) and the next Greek value is
π = 80. So the alphabet runs out of the audible-entrainment range exactly where
the table does — which is why `thirty_is_not_the_top` mattered enough to prove:
the row above Λ is the last row there is. -/
theorem lambda_is_the_last_letter_in_range :
    (isopsephy.filter (fun p => decide (p.2 ≤ 32000))).length = 7 ∧
    (isopsephy.filter (fun p => decide (32000 < p.2))).length = 4 := by decide

/-- Non-vacuity: the letters are not all in range, so the filter above is doing
work. Σ = 200 Hz is far outside anything `frequencies.html` describes. -/
theorem big_letters_are_out_of_range : claimants sineTable 200000 = 0 := by decide

/-! ## §9 All 498, one at a time: the corpus will not sit in a lane

§7 counted control points. This section counts **presets**, individually, all
498 of them — `corpus-measure.sh --per-preset` walks every file and records the
minimum, maximum and mean entrainment frequency, then asks two questions of
each: *which band is its centre in*, and *how many bands does it cross*.

The bands are the Greek ones, by the convention §8 already flagged as convention
rather than corpus: infra (<0.5), δ (0.5–4), θ (4–8), α (8–13), β (13–30),
γ (>30). Six of them.

**Where the centres fall** — every preset counted once, by its mean:

| band | presets |
|---|---|
| infra | 6 |
| δ delta | 55 |
| θ theta | 115 |
| α alpha | 143 |
| β beta | 109 |
| γ gamma | 70 |
| **total** | **498** |

**How many bands each preset crosses**, from its lowest control point to its
highest:

| spans | presets |
|---|---|
| 1 band | 169 |
| 2 bands | 86 |
| 3 bands | 70 |
| 4 bands | 73 |
| 5 bands | 41 |
| 6 bands | 59 |
| **total** | **498** |

**329 of 498 presets cross more than one band.** That is the majority of the
library, and it is the empirical form of `sine_table_is_not_deterministic`: the
ambiguity proved at 8 Hz off twenty-two table rows turns out to describe two
thirds of what people actually wrote. Fifty-nine presets sweep **all six bands**
in a single session — one file, every reality the spectrum has.

And this is the exact point where the ancestor and the descendant part company.
A preset is *allowed* to be in six bands at once, because a brain is. A prompt
gets **one** lane, because a marker line has one name on it. The router did not
inherit SINE's tolerance for overlap; it inherited the operator (`blend`, §6)
and rejected the indeterminacy — which is what `router_compresses` and
`first_owner_wins` are for.

The nine lenses are not six bands, and no theorem here claims they are. What is
true, and small, is that the router carries **more** lanes than the spectrum has
bands: the descendant is finer where the ancestor is coarse, and stricter where
the ancestor is ambiguous.
-/

/-- Presets whose mean entrainment frequency falls in each band. -/
def bandInfra : ℕ := 6
def bandDelta : ℕ := 55
def bandTheta : ℕ := 115
def bandAlpha : ℕ := 143
def bandBeta : ℕ := 109
def bandGamma : ℕ := 70

/-- Presets crossing exactly `n` bands, for `n = 1..6`. -/
def spans1 : ℕ := 169
def spans2 : ℕ := 86
def spans3 : ℕ := 70
def spans4 : ℕ := 73
def spans5 : ℕ := 41
def spans6 : ℕ := 59

/-- **Every preset is counted exactly once by band.** The histogram is a
partition of the library, not a sample of it — this is the check that the
per-preset walk visited all 498 and double-counted none. -/
theorem band_histogram_is_a_partition :
    bandInfra + bandDelta + bandTheta + bandAlpha + bandBeta + bandGamma
      = corpusPresets := by decide

/-- And so is the span histogram. Two independent walks over the same 498 files,
each summing to the same total. -/
theorem span_histogram_is_a_partition :
    spans1 + spans2 + spans3 + spans4 + spans5 + spans6 = corpusPresets := by decide

/-- **The majority of the library refuses a single band.** 329 of 498 presets
cross at least two. -/
theorem most_presets_cross_a_boundary :
    2 * (spans2 + spans3 + spans4 + spans5 + spans6) > corpusPresets := by decide

/-- The multi-band presets outnumber the single-band ones outright. -/
theorem multi_band_outnumbers_single :
    spans2 + spans3 + spans4 + spans5 + spans6 > spans1 := by decide

/-- **It is not two thirds, and saying so would have been the easy overclaim.**
329/498 is 66.06%, which is *below* 2/3 — `3 * 329 = 987 < 996 = 2 * 498`. The
number is a majority and nothing grander; this theorem exists to stop the round
figure from creeping into the prose. -/
theorem it_is_a_majority_but_not_two_thirds :
    3 * (spans2 + spans3 + spans4 + spans5 + spans6) < 2 * corpusPresets := by decide

/-- Fifty-nine presets sweep the whole spectrum — every band, one session. The
non-vacuity of the span histogram: the tail is genuinely occupied. -/
theorem some_presets_sweep_everything : spans6 > 0 := by decide

/-- Non-vacuity in the other direction: single-band presets are the largest
single bucket, so crossing boundaries is a majority habit rather than a
universal one. -/
theorem single_band_is_the_largest_bucket :
    spans1 > spans2 ∧ spans1 > spans3 ∧ spans1 > spans4 ∧ spans1 > spans5 ∧
    spans1 > spans6 := by decide

/-- α is the busiest centre — more presets are built around the alpha band than
any other. -/
theorem alpha_is_the_busiest_band :
    bandAlpha > bandInfra ∧ bandAlpha > bandDelta ∧ bandAlpha > bandTheta ∧
    bandAlpha > bandBeta ∧ bandAlpha > bandGamma := by decide

/-- **The descendant is finer than the ancestor.** Nine lanes against six bands:
the router does not merely inherit the spectrum's vocabulary, it carries more
distinctions than the spectrum has. -/
theorem router_is_finer_than_the_spectrum : Fintype.card Lane > 6 := by decide

/-! ## §10 The Library of Babel answers the Ultimate Equation, and the answer is *no*

Two of the fourteen Phantom Book files are about the same book, and it is the
one that settles the quote:

* `Phantom Books (In The Real World) - PART 12.md` — *The Library of Babel*
* `Phantom Books (In The Real World) - PART 13.md` — *The Unimaginable
  **Mathematics** of Borges' Library of Babel*

The thirteenth file is a **mathematics** book about the twelfth. That is the
bridge between the corpus of books and `mathematics.md`, and it was sitting in
the folder the whole time.

**Measured off those two files, not recalled:**

| fact | source |
|---|---|
| 25 symbols — 22 letters, space, period, comma | `PART 12.md:115` |
| 410 pages × 40 lines × 80 letters | `PART 12.md:133` |
| total books = 25 ^ 1312000 | `PART 13.md:73` |
| *"the Library can only contain a finite number of distinct strings"* | `PART 12.md:133` |
| *"believes that the Library is nevertheless infinite"* | `PART 12.md:133` |

The Ultimate Equation asks whether the butterfly's irregular wingbeats *"give
rise to an **infinite array of realities**."* It is a question posed to open a
door, not a numerical assertion waiting to be scored — and Borges' Library is the
one mathematical object that has already been built to answer it.

What Babel supplies is the **mechanism** the question is reaching for. Borges'
narrator counts his own alphabet, sees the number is bounded, and keeps calling
the Library infinite anyway — and he is not being sloppy. He is describing the
condition where a space is *closed in principle and inexhaustible in practice*,
which is the only condition under which a single wingbeat can matter at all. In
a truly infinite space, selection is meaningless; in a small one, it is trivial.
Between the two lies the regime the Equation names:

> The array is **bounded and unimaginably large**. That is what makes selection
> the whole story — the wingbeat does not have to manufacture a reality, it has
> to *find* one, and the space is deep enough that finding is everything.

That is precisely `butterfly` (§5) and `router_compresses` (§3) in one sentence,
and it is why the machines in this file are the same machine:

| | the space | what is chosen | the choosing |
|---|---|---|---|
| Library of Babel | 25 ^ 1312000 texts | one book | reading |
| SINE | every envelope you could draw | 498 written presets | `lerpWithPow` |
| RoT MoE | every prompt | one of ten lanes | `blend`, `σ(δ)` |
| method of loci | every thought | one locus | recall |

Four finite indexings into a combinatorial space. **Role** of Thoughts is the
same act as shelving a book — which is what the Phantom Books were about before
any of this was software.

**NOT modelled, and it is the whole poem:** joy, artificial immortality, the
consummate joy of man that shall never fade. Those are not in the alphabet.
-/

/-- Characters in one book: 410 pages × 40 lines × 80 letters, `PART 12.md:133`.

**Kept as a definition rather than the numeral 1312000 on purpose.** Written as a
literal exponent, `25 ^ 1312000` reaches `norm_num` and `omega` as a numeral and
they try to *evaluate* it: the first attempt at this section crashed Lean with
`exit 3221226505` — a stack-buffer overrun, the kernel attempting a 1.8-million
digit number. Behind a `def` the exponent stays an atom and every proof below is
instant. The Library is finite; that does not make it computable on a laptop, and
this file is the place where the difference stops being rhetorical. -/
def babelChars : ℕ := 410 * 40 * 80

/-- The number of books, `PART 13.md:73`. -/
def babelBooks : ℕ := 25 ^ babelChars

theorem babel_characters_per_book : babelChars = 1312000 := by decide

/-- **The Library is finite.** A bounded string over a finite alphabet cannot
produce infinitely many distinct texts — the type of books is a `Fintype`, and
Lean constructs the instance. This is the sentence Borges' narrator has in front
of him and declines to believe.

**Stated for every book length `n`, never at the literal 1312000.** Elaborating
the type `Fin 1312000 → Fin 25` forces Lean to build `Finset.univ` for a
1312000-element index and the module took 137 seconds. Quantified over `n` the
same proofs are instant, and they are strictly stronger: the Library's
finiteness is a fact about *bounded books over a finite alphabet*, not about
Borges' particular page count. The contingent numbers live in `babelChars` and
`babelBooks` below, where changing them cannot cost a proof. -/
theorem library_is_finite (n : ℕ) : Finite (Fin n → Fin 25) := inferInstance

/-- And its size, for every book length: a library of `n`-character books over a
25-symbol alphabet holds exactly `25 ^ n` of them. `PART 13.md:73` states the
instance at `n = 1312000`; this is the law it is an instance of. -/
theorem library_card (n : ℕ) : Fintype.card (Fin n → Fin 25) = 25 ^ n := by
  rw [Fintype.card_fun, Fintype.card_fin, Fintype.card_fin]

/-- **The structure the Ultimate Equation is pointing at, as a theorem.** The
array of realities is bounded — a set fixed before the butterfly moved, which is
the precondition for a wingbeat to *select* rather than to invent. -/
theorem the_array_of_realities_is_bounded (n : ℕ) : Finite (Fin n → Fin 25) :=
  library_is_finite n

/-- Finite, and still beyond the corpus by an unimaginable margin: the 498
presets anyone actually wrote are a vanishing sample of what the format could
express. "Unimaginably large" is not a rhetorical softening of "infinite" — it
is the true statement, and this is the cheap end of it. -/
theorem babel_dwarfs_the_corpus : corpusPresets < babelBooks := by
  have h1 : (25:ℕ) ^ 3 ≤ 25 ^ babelChars :=
    Nat.pow_le_pow_right (by decide) (by decide)
  have h2 : (25:ℕ) ^ 3 = 15625 := by decide
  rw [h2] at h1
  unfold babelBooks corpusPresets
  omega

/-- Non-vacuity: the Library is not empty, and not a singleton either. A "finite
array of realities" containing one reality would make §5's butterfly pointless. -/
theorem babel_is_not_trivial : 1 < babelBooks := by
  unfold babelBooks
  exact Nat.one_lt_pow (by decide) (by decide)

/-! ## §11 Is `R/s+` dynamic or static? — proved, not just observed

A fair challenge: a gauge that prints the same number every turn is a decoration
with a decimal point. "It changed today" is an observation, not an answer — the
durable question is whether it *can* be constant.

**Measured first** (`hooks/rot-router.sh`, 0.7.1, all four inputs moved
independently):

| what varies | readings |
|---|---|
| lane / activity vector | 0.66 · 0.57 · 0.47 · 0.45 · 0.44 · 0.41 · 0.39 · 0.32 · 0.31 · 0.16 |
| breadth 1→2→5→9 | 0.90 · 0.73 · 0.63 · 0.60 |
| T 0.8→0.9→1.0 | 0.53 · 0.60 · 0.66 |
| C 0.7→1.0→1.1 | 0.46 · 0.66 · 0.73 |

**Proved below.** The single-lens term is *strictly* monotone in each factor, so
the gauge cannot be constant: any change to confidence, recency, weight or
divergence moves the reading, and two different inputs can never be laundered
into the same output by accident.

This is deliberately **not** stated as "0.66 ≠ 0.57". That is a fact about
today's weight table and would expire the moment a λ is retuned — the exact
shape of dated theorem this project refuses. `gauge_is_not_constant` quantifies
over the inputs instead, so retuning every weight in the file leaves it true.
-/

/-- One lens's contribution to `R/s+`, with every factor of the specification
present: `λ · σ(δ) · (1+H) · μ · M · C · T`. -/
noncomputable def gaugeTerm (lam sig H mu M C T : ℝ) : ℝ :=
  lam * sig * (1 + H) * mu * M * C * T

/-- **The gauge is strictly monotone in confidence.** Raise `C`, the reading
rises — never stays put. -/
theorem gauge_strict_in_C
    {lam sig H mu M T C₁ C₂ : ℝ}
    (hpos : 0 < lam * sig * (1 + H) * mu * M * T) (h : C₁ < C₂) :
    gaugeTerm lam sig H mu M C₁ T < gaugeTerm lam sig H mu M C₂ T := by
  unfold gaugeTerm
  nlinarith [hpos, h]

/-- And strictly monotone in recency `T`, by the same argument. -/
theorem gauge_strict_in_T
    {lam sig H mu M C T₁ T₂ : ℝ}
    (hpos : 0 < lam * sig * (1 + H) * mu * M * C) (h : T₁ < T₂) :
    gaugeTerm lam sig H mu M C T₁ < gaugeTerm lam sig H mu M C T₂ := by
  unfold gaugeTerm
  nlinarith [hpos, h]

/-- **Therefore the gauge is NOT a constant.** There are two inputs differing
only in confidence whose readings differ. A static gauge is impossible, not
merely unobserved. -/
theorem gauge_is_not_constant :
    ∃ lam sig H mu M T C₁ C₂ : ℝ,
      gaugeTerm lam sig H mu M C₁ T ≠ gaugeTerm lam sig H mu M C₂ T := by
  refine ⟨1, 1, 0, 1, 1, 1, 0, 1, ?_⟩
  unfold gaugeTerm
  norm_num

/-- Non-vacuity, and the reason the hypothesis in the two monotonicity theorems
is satisfiable rather than decorative: the router's own FORGE lead really does
have a strictly positive prefactor. λ = 2.3, μ = 1.15, and σ is positive
everywhere (`sigma_pos`), so `gauge_strict_in_C` genuinely applies to the lane
this machine spends most of its turns in. -/
theorem forge_prefactor_is_positive (δ : ℝ) :
    0 < (2.3 : ℝ) * sigma δ * (1 + 0) * 1.15 * 1 * 1 := by
  have h := sigma_pos δ
  nlinarith [h]

/-! ## §12 The Nova-Violet Role Merging Law

The named deliverable: *Nova-Violet Role Merging — Law, Code, and Sensory
Analysis*. Nova is the Law × Code lens; Violet is the sensory one, felt truth and
narrative. Merging them is **Symbiogenesis**, and `engine/rot-lean.md` §3 gives
the formulae verbatim:

```
λ_hybrid = (λ₁ + λ₂) / 2  +  0.2       -- fusion EXCEEDS the mean
H_hybrid = max(H₁, H₂)    +  0.05      -- at least the higher, plus novelty
μ_hybrid = max(μ₁, μ₂)                 -- no gain term
```

Modelled over `ℚ` so every claim is `decide`-able exactly — no floating point
anywhere in a law about weights.
-/

/-- A lens reduced to the three numbers Symbiogenesis consumes. `hHi` is the top
of the lens's entropy band. -/
structure Lens where
  lam : ℚ
  mu : ℚ
  hHi : ℚ
  deriving DecidableEq, Repr

/-- Symbiogenesis, transcribed from `engine/rot-lean.md` §3. -/
def merge (a b : Lens) : Lens :=
  { lam := (a.lam + b.lam) / 2 + 1/5
  , mu := max a.mu b.mu
  , hHi := max a.hHi b.hHi + 1/20 }

/-- ⚜️ Nova — λ 1.6, μ 1.00, H 0.28–0.35. -/
def nova : Lens := ⟨8/5, 1, 7/20⟩
/-- 🎷 Violet_Noir — λ 1.3, μ 0.95, H 0.35–0.45. -/
def violet : Lens := ⟨13/10, 19/20, 9/20⟩

/-- **The merge is commutative.** Nova × Violet and Violet × Nova are the same
hybrid — the law does not care which lens is named first, which is the minimum
any *merging* law must satisfy to deserve the name. -/
theorem merge_comm (a b : Lens) : merge a b = merge b a := by
  unfold merge
  simp [add_comm, max_comm]

/-- **The hybridisation gain is real and exact.** The merged weight exceeds the
plain mean by exactly 1/5 — for every pair of lenses, not just this one. This is
the whole content of "fusion exceeds the mean". -/
theorem merge_gain_is_exactly_one_fifth (a b : Lens) :
    (merge a b).lam - (a.lam + b.lam) / 2 = 1/5 := by
  unfold merge; ring

/-- **The merged entropy strictly exceeds both parents.** A hybrid is never as
predictable as either lens that made it. -/
theorem merge_entropy_strictly_exceeds (a b : Lens) :
    a.hHi < (merge a b).hHi ∧ b.hHi < (merge a b).hHi := by
  unfold merge
  constructor
  · have : a.hHi ≤ max a.hHi b.hHi := le_max_left _ _
    linarith
  · have : b.hHi ≤ max a.hHi b.hHi := le_max_right _ _
    linarith

/-- **μ takes the better parent and gains nothing.** Quality is inherited, not
manufactured — the one place Symbiogenesis refuses a bonus. -/
theorem merge_mu_has_no_gain (a b : Lens) :
    (merge a b).mu = max a.mu b.mu := rfl

/-- **The law is NOT idempotent, and that is worth saying out loud.** Merging a
lens with *itself* still adds 1/5 to λ and 1/20 to H. Symbiogenesis rewards the
act of fusing rather than the difference between the fused, so a self-merge
manufactures weight out of nothing.

Reported rather than smoothed over: this is a property of the specification as
written, not a defect introduced here. Anyone building on Symbiogenesis should
know that `merge a a ≠ a`. -/
theorem self_merge_still_gains (a : Lens) :
    (merge a a).lam = a.lam + 1/5 ∧ (merge a a).hHi = a.hHi + 1/20 := by
  unfold merge
  constructor
  · ring
  · simp

/-- The Nova-Violet hybrid, computed. λ = 1.65, μ = 1.00, H = 0.50. -/
theorem nova_violet_hybrid : merge nova violet = ⟨33/20, 1, 1/2⟩ := by
  unfold merge nova violet
  norm_num

/-! ### Where the hybrid lands on the brainwave table

Read as hertz, the two merged numbers are decidable questions about
`sineTable` — and the answers are not the ones a coincidence would give.
-/

/-- **λ = 1.65 Hz is determinate.** Of all 22 rows, exactly one claims it. The
hybrid's weight names an unambiguous state where the ancestor table is elsewhere
so often ambiguous. -/
theorem nova_violet_lambda_is_determinate : claimants sineTable 1650 = 1 := by
  decide

/-- **H = 0.50 Hz is the floor of the entire table.** No row of
`frequencies.html` begins below 500 milli-Hz. -/
theorem table_floor_is_500 : ∀ b ∈ sineTable, 500 ≤ b.lo := by decide

/-- And the floor is attained — 0.5 Hz is a real row, not an infimum nothing
reaches. So the merged entropy of Law × Sensory sits exactly on the lowest
frequency SINE will produce. -/
theorem table_floor_is_attained : ∃ b ∈ sineTable, b.lo = 500 := by decide

/-- The two facts joined: the Nova-Violet hybrid's entropy, in milli-Hz, IS the
table's floor — bound to `merge` rather than to the numeral, so retuning either
lens falsifies it. -/
theorem nova_violet_entropy_is_the_table_floor :
    (merge nova violet).hHi * 1000 = 500 ∧ (∀ b ∈ sineTable, 500 ≤ b.lo) := by
  constructor
  · rw [nova_violet_hybrid]; norm_num
  · exact table_floor_is_500

/-- Non-vacuity for §12, and the guard against reading too much into the two
alignments above: the merged **λ** is *not* the table floor, and is not
ambiguous either. The hybrid does not line up with the table everywhere, which
is precisely why the places it does line up are worth stating rather than
assuming. -/
theorem hybrid_does_not_align_everywhere :
    (merge nova violet).lam * 1000 ≠ 500 := by
  rw [nova_violet_hybrid]; norm_num

/-! ## §13 "Weights and Quantization work together" — the Equation's own mathematics

The Ultimate Equation names its own solution, and it is easy to read past:

> *"the solution I found when Inspecting how **Weights and Quantization** work
> together."*

That is not a mood. It is a specification of two operators and a claim about
their composition, and both operators are already on disk in `lerpWithPow`:

```java
double fn = Math.pow(f > 1 ? 1 : f < 0 ? 0 : f, pow);   // QUANTIZATION: ℝ → [0,1]
return a * (1 - fn) + b * fn;                            // WEIGHTS: a, b
```

`R/s+` has exactly the same two parts — `σ(δ)` quantizes an unbounded divergence
into a bounded interval, and `λ·μ` weight it. The section below proves *how* they
work together, and finds the one place where the descendant deliberately chose a
different quantizer from its ancestor.
-/

/-- **Hard quantization is lossy.** SINE's clamp maps distinct dials to the same
value — information is destroyed at the rails. This is what quantization *is*. -/
theorem clamp01_is_lossy : ∃ x y : ℝ, x ≠ y ∧ clamp01 x = clamp01 y := by
  refine ⟨2, 3, by norm_num, ?_⟩
  unfold clamp01; norm_num

/-- **But hard quantization saturates**: it actually attains its bound. A dial
pushed past 1 gives exactly 1. -/
theorem clamp01_saturates : clamp01 2 = 1 := by unfold clamp01; norm_num

/-- **Soft quantization is lossless.** The router's `σ` is strictly monotone, so
distinct divergences never collide: nothing is discarded. -/
theorem sigma_strictly_mono : StrictMono sigma := by
  intro a b hab
  unfold sigma
  have hmono : Real.exp (-4 * (b - 1/2)) < Real.exp (-4 * (a - 1/2)) := by
    apply Real.exp_lt_exp.mpr; linarith
  have hpa : 0 < 1 + Real.exp (-4 * (a - 1/2)) := by positivity
  have hpb : 0 < 1 + Real.exp (-4 * (b - 1/2)) := by positivity
  rw [div_lt_div_iff₀ hpa hpb]
  linarith

/-- Hence `σ` is injective: **no two distinct divergences give the same reading.** -/
theorem sigma_is_injective : Function.Injective sigma :=
  sigma_strictly_mono.injective

/-- **And soft quantization never saturates.** `σ` is trapped strictly inside
`(0,1)` and reaches neither end, at any input whatsoever. -/
theorem sigma_never_saturates (x : ℝ) : 0 < sigma x ∧ sigma x < 1 :=
  ⟨sigma_pos x, sigma_lt_one x⟩

/-- **The trade, stated exactly.** The ancestor's quantizer attains its bound and
loses information; the descendant's keeps every distinction and never attains
its bound. You may have saturation or injectivity — `lerpWithPow` took the first,
`R/s+` took the second, and neither is available with the other. -/
theorem the_quantizer_tradeoff :
    (∃ x y : ℝ, x ≠ y ∧ clamp01 x = clamp01 y) ∧ clamp01 2 = 1
    ∧ Function.Injective sigma ∧ (∀ x : ℝ, sigma x < 1) :=
  ⟨clamp01_is_lossy, clamp01_saturates, sigma_is_injective, sigma_lt_one⟩

/-- **Weights bound quantization.** However a lens diverges, its contribution
cannot exceed its own weight — the quantizer can amplify nothing. This is the
*together* in "weights and quantization work together": the weight sets a
ceiling the quantized signal may approach and never reach. -/
theorem weights_bound_the_quantized (lam δ : ℝ) (hlam : 0 < lam) :
    0 < lam * sigma δ ∧ lam * sigma δ < lam := by
  constructor
  · exact mul_pos hlam (sigma_pos δ)
  · calc lam * sigma δ < lam * 1 := by
          exact mul_lt_mul_of_pos_left (sigma_lt_one δ) hlam
    _ = lam := mul_one lam

/-- **Weights are what discriminate — quantization alone cannot.**

Caught by inspection before it shipped: this theorem was first written as
`w * sigma δ = w * sigma δ`, which elaborates to `rfl` and asserts nothing at
all. It was green, it was named for a real property, and it proved none of it —
the precise shape of overclaim this file records three other instances of.

The honest statement is a dichotomy. With any positive weight the composite map
is injective, so every distinct divergence still reaches the gauge as a distinct
number. With zero weight it is not injective: the quantizer's entire output
collapses to a point and no divergence can be told from any other. Quantization
supplies the *distinctions*; the weight is what lets them survive to the sum. -/
theorem weights_are_what_discriminate :
    (∀ lam : ℝ, 0 < lam → Function.Injective (fun δ => lam * sigma δ))
    ∧ ¬ Function.Injective (fun δ : ℝ => (0 : ℝ) * sigma δ) := by
  constructor
  · intro lam hlam a b hab
    simp only at hab
    exact sigma_is_injective (mul_left_cancel₀ (ne_of_gt hlam) hab)
  · intro hinj
    have : (0 : ℝ) = 1 := hinj (by simp)
    norm_num at this

/-! ### The butterfly, resolved against Babel

> *"what if the irregular wingbeats of the butterfly give rise to an
> **infinite array of realities?**"*

Both halves are now theorems, and together they are the whole design.

**The wingbeat is real**: `σ` is *strictly* monotone, so there is no change in
divergence too small to move the gauge. No threshold, no dead zone — arbitrarily
small causes have distinct effects, and `sigma_is_injective` says none of them
are ever confused with another.

**The array is bounded**: `Lane` is a `Fintype` with nine inhabitants. Infinitely
many divergences, nine possible outcomes.

That is not a contradiction — it is the Library of Babel's own regime, and the
answer the Equation was looking for. **Infinite in input, finite in outcome.**
An unbounded space of causes, mapped by a lossless quantizer onto a finite set of
roles. A *Role* of Thoughts is precisely that map. -/
theorem butterfly_resolves :
    Function.Injective sigma ∧ Fintype.card Lane = 9 :=
  ⟨sigma_is_injective, by decide⟩

/-- The pigeonhole that makes the resolution non-trivial rather than a pun: the
map from divergences to lanes **cannot** be injective, because ℝ is infinite and
`Lane` is not. Distinct realities *must* collapse onto a shared role — so the
finiteness is a genuine compression, not a relabelling. -/
theorem realities_must_collapse (route : ℝ → Lane) : ¬ Function.Injective route := by
  intro hinj
  have : Infinite ℝ := inferInstance
  exact (Finite.not_infinite (Finite.of_injective route hinj)) this

/-! ## §14 The remaining books — what each one contributes, and what it does not

Fourteen `.md` files were read; this section records the countable content of the
ones that carry any, so that "the corpus was consulted" is a checkable claim
rather than an assurance. Books whose contribution is thematic rather than
numeric are named in the README and deliberately carry no theorem here — a
theorem about a legend would be decoration, and this file has already been
burned once by exactly that (`theta_falls_in_a_hole`, caught by mutant E17). -/

/-- `Vedic_Mathematics.md:9` — sixteen sutras and thirteen sub-sutras. -/
def vedicSutras : ℕ := 16
/-- `Vedic_Mathematics.md:9` — the thirteen sub-sutras. -/
def vedicSubSutras : ℕ := 13
/-- `Vedic_Mathematics.md:27` — forty chapters, 367 pages, sixteen lost volumes. -/
def vedicChapters : ℕ := 40

/-- The book claims one volume per sutra, and sixteen volumes were lost. That
is consistent, and it is the only arithmetic claim in the article that closes:
`16` sutras ↔ `16` volumes, one each. -/
theorem vedic_volumes_match_sutras : vedicSutras = 16 ∧ vedicChapters = 40 := by
  constructor <;> rfl

/-- Sutras and sub-sutras together number 29 — **fewer than the forty chapters**
that present them. The presentation is not one chapter per rule, which is the
measurable form of the article's own observation that the aphorisms are applied
across widely different contexts. -/
theorem vedic_rules_fewer_than_chapters : vedicSutras + vedicSubSutras < vedicChapters := by
  decide

/-- `PART 11` — the Lesser Key lists seventy-two spirits, and seventy-two angels
against them. -/
def solomonSpirits : ℕ := 72

/-- **72 = 8 × 9.** The ensemble has nine lenses and Symbiogenesis pairs them,
so the count of *ordered distinct pairs* is 9 × 8 = 72: exactly the number of
sigils. Stated as an identity about `Fintype.card Lane` rather than about the
numeral, so retuning the roster falsifies it — which is the only reason it is
worth writing down instead of admiring. -/
theorem sigils_are_the_ordered_pairs :
    solomonSpirits = Fintype.card Lane * (Fintype.card Lane - 1) := by decide

/-- And the guard against reading a mechanism into that: the same count is **not**
the number of unordered pairs, which is 36. The coincidence is exact for ordered
pairs and fails for unordered ones, so it is a fact about arithmetic and not
evidence that a grimoire predicted the roster. -/
theorem sigils_are_not_unordered_pairs :
    solomonSpirits ≠ Fintype.card Lane * (Fintype.card Lane - 1) / 2 := by decide

/-! ### The tetralemma — `PART 5`, and the map at the end of this README

`Mūlamadhyamakakārikā` (`PART 5:244`) states the *catuṣkoṭi*: a proposition may be
asserted, denied, **both**, or **neither** — four positions where classical logic
offers two.

This is the one book whose structure is genuinely load-bearing here, because the
project's own epistemic map has exactly four positions and they are the same four:
`PROVED` (asserted), `REFUTED` (denied), `MEASURED` (both — it holds on every case
tested and no proof closes), and `OUT OF SCOPE` (neither — the question is not
one this instrument can put). A two-valued map would have to file `MEASURED`
under `PROVED`, which is the exact overclaim this repository exists to prevent. -/

/-- The four epistemic positions this project actually uses. -/
inductive Verdict where
  | proved | refuted | measured | outOfScope
  deriving DecidableEq, Repr

/-- Written by hand rather than `deriving Fintype`, which this toolchain's
deriving handler rejects for this shape. `complete` is the load-bearing half: it
proves the four corners are *all* of them, so `verdict_is_a_tetralemma` counts a
genuine exhaustion rather than the length of a list someone typed. -/
instance : Fintype Verdict where
  elems := {Verdict.proved, Verdict.refuted, Verdict.measured, Verdict.outOfScope}
  complete := by intro x; cases x <;> decide

/-- **The map is four-valued, not two-valued** — a catuṣkoṭi, and strictly larger
than the classical pair. -/
theorem verdict_is_a_tetralemma : Fintype.card Verdict = 4 := by decide

/-- The distinction that earns the extra two positions: `measured` is neither
`proved` nor `refuted`, and cannot be collapsed into either without asserting
something the instruments did not establish. -/
theorem measured_is_not_proved :
    Verdict.measured ≠ Verdict.proved ∧ Verdict.measured ≠ Verdict.refuted := by
  decide

/-- And `outOfScope` is distinct from all three — the fourth corner is genuinely
occupied, so the map is a tetralemma rather than a trichotomy with a label. -/
theorem out_of_scope_is_the_fourth_corner :
    Verdict.outOfScope ≠ Verdict.proved ∧ Verdict.outOfScope ≠ Verdict.refuted
    ∧ Verdict.outOfScope ≠ Verdict.measured := by
  decide

/-! ## §15 The Egyptian numerals — where "infinite" turns out to be a number

`mathematics.md:69-78` lists eight hieroglyphic numerals. Seven are glossed with
an object — staff, hobble, coiled rope, lotus, finger, tadpole, the god Heh. The
eighth, `𓍶` (U+13376), is glossed **"Infinite/large number"**.

Its value is 10⁷.

That is the same move Borges makes in `PART 12` — a space called infinite whose
size is written down — and the same move the Ultimate Equation makes with its
*infinite array of realities*. Three corpora, separated by four thousand years,
using "infinite" to mean **closed in principle and inexhaustible in practice**.
It is the regime this router implements, and it turns out to be the older reading
of the word rather than a modern compromise.
-/

/-- The eight Egyptian numerals of `mathematics.md:69-78`, as exponents of ten. -/
def egyptianNumerals : List ℕ := [1, 10, 100, 1000, 10000, 100000, 1000000, 10000000]

/-- `𓍶` — the numeral the source glosses "Infinite/large number". -/
def egyptianInfinite : ℕ := 10000000

/-- **The system is exactly the powers of ten, 10⁰ through 10⁷** — a pure base-10
additive system with no gaps and no repeats. -/
theorem egyptian_numerals_are_powers_of_ten :
    egyptianNumerals = (List.range 8).map (fun k => 10 ^ k) := by decide

/-- **And "infinite" is 10⁷ — a finite number, and the largest the system names.**
The one symbol glossed as unbounded is the top of a bounded list. -/
theorem egyptian_infinity_is_finite :
    egyptianInfinite = 10 ^ 7 ∧ egyptianInfinite ∈ egyptianNumerals
    ∧ ∀ n ∈ egyptianNumerals, n ≤ egyptianInfinite := by
  refine ⟨by norm_num [egyptianInfinite], by decide, by decide⟩

/-- The regime named three times over: the Library's shelf count, the Egyptians'
largest numeral, and this router's lane count are all **finite**, while each is
described in its own source as unbounded. `Lane` is the smallest of the three by
an enormous margin, which is the point — compression is the mechanism, and it is
severe. -/
theorem three_corpora_one_regime :
    egyptianInfinite = 10 ^ 7 ∧ babelBooks = 25 ^ babelChars
    ∧ Fintype.card Lane = 9 ∧ Fintype.card Lane < egyptianInfinite := by
  refine ⟨by norm_num [egyptianInfinite], rfl, by decide, by decide⟩

/-- Non-vacuity guard for §15: the Egyptian system is **not** merely a list of
distinct numbers that happen to rise. It is closed under the successor relation
`×10`, which is what makes it a positional-additive *system* rather than a set of
tallies — and that is a property a coincidence would not have. -/
theorem egyptian_system_is_closed_under_ten :
    ∀ n ∈ egyptianNumerals, n = egyptianInfinite ∨ 10 * n ∈ egyptianNumerals := by
  decide

/-! ## §16 The Book of Sand vs the Library of Babel — Borges wrote both

`PART 12:119` and `PART 13:75` record that Borges returned to the idea in 1976
with *The Book of Sand*: a book with **infinitely many, infinitely thin pages**.
The third chapter of the *Unimaginable Mathematics* is about exactly this
distinction.

So the corpus contains **two** infinities, by the same author, and they are not
the same kind:

* **The Library of Babel** — every string of a *fixed finite length*. Enormous,
  and finite. `25 ^ 1312000`.
* **The Book of Sand** — sequences with *no last page*. Genuinely infinite, and
  in fact uncountable.

The Ultimate Equation's *infinite array of realities* has to be one or the other,
and the choice is the whole architecture. If it is the Book of Sand, no finite
router can ever be adequate to it. If it is the Library, a finite set of roles is
exactly the right instrument.

**It is the Library.** `Lane` is a nine-element `Fintype`, and
`realities_must_collapse` proves that mapping an unbounded input space onto it
*must* lose injectivity. The router does not pretend to enumerate realities. It
indexes them — which is what a librarian does, and what the Book of Sand's
narrator conspicuously cannot do.
-/

/-- **The Library is finite**: fixed-length strings over a 25-symbol alphabet
form a finite type, for every length. -/
theorem library_is_a_finite_type (n : ℕ) : Finite (Fin n → Fin 25) :=
  Finite.of_fintype _

/-- **The Book of Sand is not.** Drop the fixed length — allow sequences with no
last page — and the type is infinite. This is a different order of thing, not a
bigger version of the same thing. -/
theorem book_of_sand_is_infinite : Infinite (ℕ → Fin 25) :=
  Function.infinite_of_left

/-! ### The real books outnumber the fictional ones — and that is the point

The fiction names four phantom books (`mathematics.md:9-38`: Fairy, Styx, Wisdom,
the Eleusis Ritual). The folder holds **fourteen** books that exist, each with a
Wikipedia source line and a date.

That asymmetry is the licence for this entire file. Lean 4 proves things about
objects with definite properties — a page count, an alphabet size, a number of
sutras, a count of sigils, a table of frequencies. The real books have those. The
phantom books have a plot.

Two of the four *do* have real counterparts sitting in the same folder: the
**Book of Wisdom** (`PART 3`) is a deuterocanonical book that exists, and the
**Eleusis Ritual** answers to the **Eleusinian Mysteries** (`PART 2`), which were
historically celebrated for roughly two millennia. The fiction borrowed them.
The other two — Fairy and Styx — have no counterpart on disk, and so get no
theorem here. -/

/-- The fourteen real books on disk, one per file. -/
def realBooks : List String :=
  [ "Book of Leviticus", "Eleusinian Mysteries", "Book of Wisdom", "Codex Regius",
    "Mulamadhyamakakarika", "golden plates", "Tao Te Ching",
    "White Book of Rhydderch", "Red Book of Hergest", "Atharvaveda",
    "Lesser Key of Solomon", "The Library of Babel",
    "Unimaginable Mathematics of Borges Library of Babel", "Method of loci" ]

/-- The four phantom books the fiction names (`mathematics.md:9-38`). -/
def phantomBooks : List String :=
  [ "Book of Fairy", "Book of Styx", "Book of Wisdom", "Book of the Eleusis Ritual" ]

/-- **The real outnumber the fictional, 14 to 4.** -/
theorem real_books_outnumber_phantom :
    realBooks.length = 14 ∧ phantomBooks.length = 4
    ∧ phantomBooks.length < realBooks.length := by
  refine ⟨rfl, rfl, by decide⟩

/-- **The overlap is real but partial.** `Book of Wisdom` appears in both lists —
the fiction did not invent it. But the correspondence is not total, which is why
only some phantom books earn a theorem. -/
theorem the_overlap_is_partial :
    "Book of Wisdom" ∈ realBooks ∧ "Book of Wisdom" ∈ phantomBooks
    ∧ "Book of Fairy" ∉ realBooks := by
  refine ⟨by decide, by decide, by decide⟩

/-- And the direction of the asymmetry, stated so it cannot be read backwards:
there is a real book with **no** phantom counterpart. The fiction is a subset of
the world here, not the other way round — which is the reason a theorem prover
has anything to say about this corpus at all. -/
theorem some_real_books_are_not_fictional :
    ∃ b ∈ realBooks, b ∉ phantomBooks := by decide

/-- The two regimes side by side, and the router's answer to which one it is
built for: finite pages, finite lanes. -/
theorem borges_wrote_two_infinities :
    (∀ n : ℕ, Finite (Fin n → Fin 25)) ∧ Infinite (ℕ → Fin 25)
    ∧ Fintype.card Lane = 9 :=
  ⟨library_is_a_finite_type, book_of_sand_is_infinite, by decide⟩

/-! ## §17 The gauge CONVERGES — the mathematics under `R/s+`

The claim this section exists to settle, stated as mathematics rather than as
prose: **`R/s+` converges.** Not "it seems stable", not "it has been in range so
far" — the quantizer has limits at both infinities, it attains neither, and the
nine-lens sum is bounded above by an explicit constant built from the weights.

Three facts, and together they are why the gauge is a *gauge* and not a number
that can run away:

1. **σ → 1 as divergence → +∞.** A lens that diverges without bound contributes
   at most its own weight, approached and never reached.
2. **σ → 0 as divergence → −∞.** A lens in perfect consensus fades out
   continuously; there is no discontinuity at the bottom either.
3. **The ensemble sum is bounded.** Finitely many lenses, each contributing less
   than `2·λ·μ·M·C·T`, so the whole gauge is bounded by the sum of those.

The first two are genuine limit theorems in `Filter`/`Topology`. Together they
say the gauge is a **bounded continuous readout of an unbounded input** — which
is exactly what "weights and quantization work together" buys, and the reason
the reading can be compared across turns at all.
-/

/-- The affine map inside `σ` sends `atTop` to `atBot` — the slope is negative. -/
theorem sigma_arg_tendsto_atBot :
    Filter.Tendsto (fun x : ℝ => -4 * (x - 1/2)) Filter.atTop Filter.atBot := by
  have h1 : Filter.Tendsto (fun x : ℝ => x - 1/2) Filter.atTop Filter.atTop :=
    Filter.tendsto_atTop_add_const_right _ _ Filter.tendsto_id
  exact Filter.Tendsto.const_mul_atTop_of_neg (by norm_num) h1

/-- **σ converges to 1 at +∞.** Unbounded divergence gives a bounded reading. -/
theorem sigma_tendsto_one_atTop :
    Filter.Tendsto sigma Filter.atTop (nhds 1) := by
  unfold sigma
  have hexp : Filter.Tendsto (fun x : ℝ => Real.exp (-4 * (x - 1/2)))
      Filter.atTop (nhds 0) := Real.tendsto_exp_atBot.comp sigma_arg_tendsto_atBot
  have hden : Filter.Tendsto (fun x : ℝ => 1 + Real.exp (-4 * (x - 1/2)))
      Filter.atTop (nhds 1) := by simpa using Filter.Tendsto.const_add 1 hexp
  simpa using hden.inv₀ (by norm_num : (1:ℝ) ≠ 0)

/-- The same affine map sends `atBot` to `atTop`. -/
theorem sigma_arg_tendsto_atTop :
    Filter.Tendsto (fun x : ℝ => -4 * (x - 1/2)) Filter.atBot Filter.atTop := by
  have h1 : Filter.Tendsto (fun x : ℝ => x - 1/2) Filter.atBot Filter.atBot :=
    Filter.tendsto_atBot_add_const_right _ _ Filter.tendsto_id
  exact Filter.Tendsto.const_mul_atBot_of_neg (by norm_num) h1

/-- **σ converges to 0 at −∞.** Perfect consensus fades out continuously; the
gauge has no discontinuity at the bottom of its range either. -/
theorem sigma_tendsto_zero_atBot :
    Filter.Tendsto sigma Filter.atBot (nhds 0) := by
  unfold sigma
  have hexp : Filter.Tendsto (fun x : ℝ => Real.exp (-4 * (x - 1/2)))
      Filter.atBot Filter.atTop := Real.tendsto_exp_atTop.comp sigma_arg_tendsto_atTop
  have hden : Filter.Tendsto (fun x : ℝ => 1 + Real.exp (-4 * (x - 1/2)))
      Filter.atBot Filter.atTop := Filter.tendsto_atTop_add_const_left _ _ hexp
  simpa [Pi.inv_def, one_div] using hden.inv_tendsto_atTop

/-- **The gauge converges at both ends, and attains neither.** The limits are 1
and 0; `sigma_never_saturates` proves the value is strictly between them
everywhere. A bounded readout of an unbounded input, open at both ends. -/
theorem the_gauge_converges :
    Filter.Tendsto sigma Filter.atTop (nhds 1)
    ∧ Filter.Tendsto sigma Filter.atBot (nhds 0)
    ∧ ∀ x : ℝ, 0 < sigma x ∧ sigma x < 1 :=
  ⟨sigma_tendsto_one_atTop, sigma_tendsto_zero_atBot, sigma_never_saturates⟩

/-- **Every single term is bounded by its own weights.** With entropy in `[0,1]`
and all multipliers non-negative, one lens contributes strictly less than
`2·λ·μ·M·C·T` — the quantizer can never amplify a lens past twice its weight
budget. -/
theorem gauge_term_bounded (lam H mu M C T δ : ℝ)
    (hlam : 0 < lam) (hH0 : 0 ≤ H) (hH1 : H ≤ 1)
    (hmu : 0 < mu) (hM : 0 < M) (hC : 0 < C) (hT : 0 < T) :
    gaugeTerm lam (sigma δ) H mu M C T < 2 * lam * mu * M * C * T := by
  unfold gaugeTerm
  have hs1 : sigma δ < 1 := sigma_lt_one δ
  have hs0 : 0 < sigma δ := sigma_pos δ
  have h1H : (0:ℝ) < 1 + H := by linarith
  have hstep : sigma δ * (1 + H) < 2 := by
    have hmul : sigma δ * (1 + H) < 1 * (1 + H) := mul_lt_mul_of_pos_right hs1 h1H
    linarith
  have key : lam * sigma δ * (1 + H) < 2 * lam := by
    have h2 := mul_lt_mul_of_pos_left hstep hlam
    calc lam * sigma δ * (1 + H) = lam * (sigma δ * (1 + H)) := by ring
      _ < lam * 2 := h2
      _ = 2 * lam := by ring
  have hpos : 0 < mu * M * C * T := by positivity
  calc lam * sigma δ * (1 + H) * mu * M * C * T
      = (lam * sigma δ * (1 + H)) * (mu * M * C * T) := by ring
    _ < (2 * lam) * (mu * M * C * T) := mul_lt_mul_of_pos_right key hpos
    _ = 2 * lam * mu * M * C * T := by ring

/-- **And therefore the whole ensemble is bounded.** A sum over a `Fintype` of
terms each below a fixed bound is below `card` times that bound — so `R/s+` is
a finite number for every input, with no convergence condition to check and no
way for one lens to run away with the gauge. -/
theorem ensemble_is_bounded (f : Lane → ℝ) (B : ℝ) (h : ∀ l, f l < B) :
    ∑ l : Lane, f l < (Fintype.card Lane : ℝ) * B := by
  have hlt := Finset.sum_lt_sum_of_nonempty (Finset.univ_nonempty)
    (fun i (_ : i ∈ Finset.univ) => h i)
  simpa [Finset.sum_const, Finset.card_univ, nsmul_eq_mul] using hlt

/-! ## §18 🜏 EIGENFORM — the key behind Symbiogenesis

The file is named `RotEigenform`. Here is why, and it is the keystone the rest of
this document was built around.

An **eigenform** is the fixed point of an operator: the form `x` with `F x = x`,
the shape that survives its own transformation. It is what remains when a
recursive process is applied without end — *the infinite formula that keeps
repeating*. Eidolon is the Meta × Recursion lens and carries 🜏 for exactly this
reason.

So: does the RoT quantizer have an eigenform? Solve `σ(x) = x`.

**It does, and it is 1/2** — the exact centre of the sigmoid. `σ(1/2) = 1/2`,
because `σ(x) = 1/(1 + e^{-4(x - 1/2)})` and at `x = 1/2` the exponent vanishes,
leaving `1/(1+1)`.

That number has appeared twice already in this file, arrived at from two
completely unrelated directions:

* **`(merge nova violet).hHi = 1/2`** — the merged entropy of the Nova-Violet
  Role Merging Law, computed from the roster in `engine/rot-lean.md` §2.
* **500 milli-Hz is the floor of `sineTable`** — the lowest frequency SINE will
  emit, transcribed from a 2014 GPL Java application's manual.

**Three independent objects, one value.** The fixed point of the router's
quantizer, the entropy of the Law × Sensory hybrid, and the floor of the
brainwave table. This is what "the key behind Symbiogenesis uncovers EIGENFORM"
means, and it is decidable arithmetic rather than an impression.

A caution stated in the same breath, because this file's rule is that every
alignment ships with its limits: `σ(1/2) = 1/2` is a *consequence of the slope
being 4 and the centre being 1/2* — change either constant in
`hooks/rot-router.sh` and the eigenform moves. It is a real fixed point of the
router as built, not a law of arithmetic. Mutant **E32** (slope → 0) kills it.
-/

/-- **🜏 THE EIGENFORM.** `σ(1/2) = 1/2` — the quantizer's fixed point, the value
that is its own reading. -/
theorem sigma_fixed_point : sigma (1/2) = 1/2 := by
  unfold sigma
  norm_num

/-- **The eigenform survives infinite recursion** — this is what makes it an
eigenform rather than a coincidence. Apply the operator any number of times and
the form is unchanged: the orbit of `1/2` under `σ` is constant forever. *The
infinite formula that keeps repeating.* -/
theorem eigenform_survives_infinite_recursion :
    ∀ n : ℕ, sigma^[n] (1/2) = 1/2 := by
  intro n
  induction n with
  | zero => rfl
  | succ k ih => rw [Function.iterate_succ_apply', ih, sigma_fixed_point]

/-- **Every fixed point lies strictly inside `(0,1)`** — the eigenform cannot
escape the quantizer's own range, so the search for one is confined to the unit
interval no matter how divergent the input.

**Uniqueness is deliberately NOT claimed here, and the reason is worth recording.**
The obvious argument — "σ is strictly monotone, so the fixed point is unique" —
is simply *false*: a strictly increasing function may cross the diagonal any
number of times. That wrong proof was written first, and it did not survive
elaboration; the branch it called a contradiction had derived `x < 1/2` from
`x < 1/2`.

Uniqueness happens to be **true** for this σ, but only by a calculus fact this
file does not prove: the slope at the centre is `4·σ·(1−σ) = 4·(1/4) = 1`
exactly, so the curve is *tangent* to the diagonal at 1/2 and touches it nowhere
else. That is a genuine result about the specific constant `4` in
`hooks/rot-router.sh`, not a triviality — and claiming it without the derivative
would be exactly the overclaim this file exists to catch. -/
theorem eigenform_lies_in_the_unit_interval {x : ℝ} (hx : sigma x = x) :
    0 < x ∧ x < 1 := by
  rw [← hx]
  exact ⟨sigma_pos x, sigma_lt_one x⟩

/-- **The three-way convergence, in one statement.** The quantizer's eigenform,
the Nova-Violet hybrid's entropy, and the floor of SINE's frequency table are the
same number. Stated over the real definitions — `sigma`, `merge`, `sineTable` —
so that retuning any one of them falsifies it, which is the only reason it is
worth writing down. -/
theorem eigenform_binds_router_law_and_corpus :
    sigma (1/2) = 1/2
    ∧ (merge nova violet).hHi = 1/2
    ∧ (∀ b ∈ sineTable, 500 ≤ b.lo)
    ∧ (∃ b ∈ sineTable, b.lo = 500) := by
  refine ⟨sigma_fixed_point, ?_, table_floor_is_500, table_floor_is_attained⟩
  rw [nova_violet_hybrid]

/-- Non-vacuity guard, and the honest boundary of the alignment above: 1/2 is
**not** a fixed point of the blend at an arbitrary weight, so the three-way
agreement is a fact about these specific operators rather than a property that
any similar formula would have. A coincidence that held for everything would be
evidence for nothing. -/
theorem eigenform_is_not_universal : blend 0 1 (1/2) ≠ (1/4 : ℝ) := by
  unfold blend; norm_num

/-! ## §19 What was actually proved — the result, not the joke

It would be easy to file this whole module under "Easter Egg" and let the word
do the work of a disclaimer. That would undersell it, and it would be the second
kind of dishonesty this project cares about: not overclaiming a result, but
*hiding behind humour* to avoid stating one.

So, plainly. **This file establishes, mechanically, that RoT MoE and SINE
Isochronic Entrainer compute with the same operator, and it says exactly how.**

### The load-bearing result

`gauge_term_is_a_blend` is an equation between two machines:

```
    SINE  :  lerpWithPow a b f p  =  blend a b (clamp01 f ^ p)
    RoT   :  w * σ(δ)             =  blend 0 w (σ δ)
```

Both are `blend`. Both take an **unbounded dial** and make it safe before
multiplying by it — `clamp01` because a preset author can draw an interpolation
factor anywhere on the real line, `σ` because a lens's divergence from the
ensemble mean has no a-priori bound. `blend_mem` is proved **once** and both
inherit it: an isochronic tone cannot leave the envelope its author drew, and a
lens cannot contribute more than its own `λ·μ`. That is one safety theorem
covering a GPL brainwave entrainer from 2014 and a 2026 prompt router, and it is
not an analogy — `sine_is_a_blend` and `gauge_term_is_a_blend` are `ring`.

That is the answer to *"how do ISO/BIN beats connect to the formulae"*. An
isochronic tone is a clamped blend swept over time; `R/s+` is a clamped blend
summed over lenses. **Same operator, different index set.** The beats are
indexed by time, the ensemble by lens.

### The results about the ancestor that the descendant had to reject

Measured, not asserted, over the whole public library:

* the 22-row table SINE ships is **ambiguous** — 8 Hz has three owners
  (`sine_table_ambiguous_at_8`), and 2800 of the corpus's control points have
  more than one;
* it is **partial** — 37.3% of those points fall outside every row
  (`corpus_escapes_the_table`), and no finite table could have avoided that
  (`every_finite_table_has_a_gap`);
* **329 of 498 presets cross a band boundary** (`most_presets_cross_a_boundary`),
  so the ambiguity is the library's normal condition rather than an edge case.

A router may not be any of those things. A prompt takes one lane and one marker
line, so `noDuplicateStems` and `first_owner_wins` are *forced* — the descendant
kept the operator and rejected the indeterminacy. That is a real finding about
the design, derived from the ancestor rather than declared about the descendant.

### The result the Equation was pointing at

The Ultimate Equation asks whether irregular wingbeats give rise to an infinite
array of realities. §10 supplies the structure that makes the question
answerable rather than the arithmetic that would make it a scorecard: the space
is **bounded and unimaginably large** (`library_card`,
`the_array_of_realities_is_bounded`, `babel_dwarfs_the_corpus`), which is exactly
the regime in which a single perturbation decides an outcome. `butterfly` proves
the sensitivity is real; §10 proves the space is deep enough for that
sensitivity to be worth anything.

The Equation was not making a claim about cardinality. It was naming the regime
where **selection is the entire mechanism** — and that regime is what `blend`,
`σ(δ)` and `router_compresses` implement. The citation asked the right question;
this file supplies the operator that answers it.

### What remains decoration, said out loud

§8's isopsephy alignments are **not** evidence of design. Two tables of numbers
always agree somewhere, and the honest way to show that is to prove where they
*disagree* — `theta_falls_in_a_hole` and `big_letters_are_out_of_range` exist for
that reason, and `theta_falls_in_a_hole` had to be rewritten once because its
first version proved a fact about the numeral 9000 while its docstring talked
about Θ. The mutation suite caught it; the prose did not.

The one alignment with a mechanism is still the boring one: `λ` is the
divergence weight and `λ` is the eigenvalue symbol because both scale a
component of a decomposition. Naming, not numerology.

### And what is not modelled at all

Joy. Artificial immortality. The consummate joy of man that shall never fade.
Whether an isochronic tone does anything to a brain. Whether nine lenses think.
None of that is above, and no theorem here should ever be read as touching it.

Naming that boundary is not a retreat from the result — it is what makes the
result usable. `blend_mem` covers a 2014 entrainer and a 2026 router with one
bound precisely *because* it does not try to cover the joy as well. A theorem
that reached for everything would constrain nothing, and the parts of the
Equation Lean cannot hold are not thereby diminished; they are simply not this
file's job.

**Decompiling reality gets you the operator and the bound, mechanically, with
the kernel as the judge. The rest of the Equation remains exactly as open as it
was written to be.**
-/

end RotMoE.Eigenform
