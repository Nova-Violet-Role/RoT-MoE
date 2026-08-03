/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Mathlib

/-! # The RoT MoE gauge, formalized

A model of the R/s+ computation in
`~/.claude/tools/sanctum/rot-lean-inject.ps1`, the hook that fires on every
`UserPromptSubmit` and `PreToolUse`.

The hook is the router. It reads nine signals off disk, turns each into a lens
*activity* in `{0,1}`, and computes

```powershell
$meanAct = ($acts | Measure-Object -Average).Average          # :381-382
foreach ($name in $lenses.Keys) {
    $di = [Math]::Abs($a - $meanAct)                          # :394
    $si = 1.0 / (1.0 + [Math]::Exp(-4.0 * ($di - 0.5)))       # :395
    $Hi = if ($breadth -gt 0) { $a / [double]$breadth } else { 0.0 }
    if ($Hi -gt 1.0) { $Hi = 1.0 }                            # :398-399
    $sum += $l * $si * (1.0 + $Hi) * $m_ * $M * $C * $T       # :401
}
$R = $sum / $K                                                # :404-405
```

**The claim under attack.** The standard objection to any such engine is that the
number is decoration — an instrument that cannot fail. This file answers it in
the kernel rather than in prose:

* `gauge_pos` — the gauge is never `0`. The spec calls `R/s+ = 0.0` a violation
  ("a placeholder never computed"); here it is impossible, not merely forbidden.
* `gauge_ge_floor` — every input lands at or above the all-quiet value, so the
  all-quiet reading really is the floor and not merely a small number.
* `gauge_allLive_eq_two_mul_allQuiet` — a fully active ensemble at breadth 1
  reads exactly **twice** the floor. An exact identity, not a bound.
* `gauge_not_constant` — the instrument moves. The negative control, written as
  a theorem, so no future edit can replace the gauge with a constant and keep
  this file green.

**Scope, stated before anything else.** This proves the gauge's *arithmetic*:
positivity, bounds, monotonicity, the floor, non-constancy, and the totality of
the band classifier. It proves nothing about whether the reasoning is better for
being routed — that is output quality, outside Lean entirely. It also cannot see
the PowerShell: the correspondence between `gauge` here and `$R` there is
enforced by a checker, not by this file. The `Float` mirror in the last section
is the bridge to that checker and is deliberately **not** the object of any
theorem.

The index type is left general (`ι`) rather than fixed to nine lenses, and every
weight is a variable rather than a literal. A tenth lens and a retuned λ are both
changes this project would make on purpose; a theorem that either one breaks
would be a defect in the spec, not a safeguard.
-/

namespace RotMoE

/-! ## The saturation function

`σ(x) = 1 / (1 + e^{-4(x - 1/2)})` — the spec's sigmoid, centred on `0.5` with
slope `4`, used verbatim rather than approximated (`rot-lean-inject.ps1:395`).
-/

/-- The spec's sigmoid, centred on `1/2` with slope `4`. -/
noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1 / 2)))

theorem sigma_denom_pos (x : ℝ) : (0 : ℝ) < 1 + Real.exp (-4 * (x - 1 / 2)) := by
  have := Real.exp_pos (-4 * (x - 1 / 2))
  linarith

/-- σ has no zero. This is the per-lens half of `gauge_pos`. -/
theorem sigma_pos (x : ℝ) : 0 < sigma x := by
  unfold sigma
  exact div_pos one_pos (sigma_denom_pos x)

/-- σ saturates below 1: pure chaos is damped, never allowed to dominate. -/
theorem sigma_lt_one (x : ℝ) : sigma x < 1 := by
  unfold sigma
  rw [div_lt_one (sigma_denom_pos x)]
  have := Real.exp_pos (-4 * (x - 1 / 2))
  linarith

/-- **Divergence is rewarded monotonically.** A lens further from the ensemble
mean never scores lower than one closer to it. This is what makes `δ` a signal
rather than a decoration, and it is the engine of `gauge_ge_floor`. -/
theorem sigma_strictMono : StrictMono sigma := by
  intro a b hab
  unfold sigma
  have h : Real.exp (-4 * (b - 1 / 2)) < Real.exp (-4 * (a - 1 / 2)) := by
    apply Real.exp_lt_exp.mpr
    linarith
  exact div_lt_div_of_pos_left one_pos (sigma_denom_pos b) (by linarith)

theorem sigma_mono : Monotone sigma := sigma_strictMono.monotone

/-- The centre point. Pins the constants `-4` and `1/2` against a transposition
that no bound above would notice. -/
theorem sigma_half : sigma (1 / 2) = 1 / 2 := by
  unfold sigma
  norm_num

/-! ## The ensemble -/

/-- A lens contributes two constants to the gauge: its divergence weight `λ` and
its quality multiplier `μ` (`rot-lean-inject.ps1:368`, "lens -> [lambda, mu,
activity]"). -/
structure Lens where
  lam : ℝ
  mu : ℝ

variable {ι : Type*} [Fintype ι]

/-- A lens's measured activity as a real number. `a i = true` means *that lens's
own signal moved this turn, observed on disk* — never an opinion, never a number
the reasoning invented. -/
def actR (a : ι → Bool) (i : ι) : ℝ := if a i then 1 else 0

theorem actR_nonneg (a : ι → Bool) (i : ι) : 0 ≤ actR a i := by
  unfold actR; split <;> norm_num

/-- The ensemble mean activity (`:381-382`) — a real arithmetic mean over
measured activities, which is what makes `δᵢ` a genuine divergence. -/
noncomputable def meanAct (a : ι → Bool) : ℝ := (∑ i, actR a i) / (Fintype.card ι)

/-- `δᵢ = |aᵢ − mean|` (`:394`) — lens `i`'s divergence from the ensemble. -/
noncomputable def deltaAt (a : ι → Bool) (i : ι) : ℝ := |actR a i - meanAct a|

theorem deltaAt_nonneg (a : ι → Bool) (i : ι) : 0 ≤ deltaAt a i := abs_nonneg _

/-- `Hᵢ` — this lens's share of the turn's breadth, capped at 1 (`:398-399`).
`breadth` counts distinct signal *categories* that moved, so it is an input
independent of the activity vector and is carried as a separate argument. -/
noncomputable def entropyAt (a : ι → Bool) (breadth : ℕ) (i : ι) : ℝ :=
  if breadth = 0 then 0 else min 1 (actR a i / (breadth : ℝ))

theorem entropyAt_nonneg (a : ι → Bool) (breadth : ℕ) (i : ι) :
    0 ≤ entropyAt a breadth i := by
  unfold entropyAt
  split
  · exact le_refl 0
  · exact le_min zero_le_one (div_nonneg (actR_nonneg a i) (Nat.cast_nonneg _))

theorem entropyAt_le_one (a : ι → Bool) (breadth : ℕ) (i : ι) :
    entropyAt a breadth i ≤ 1 := by
  unfold entropyAt
  split
  · norm_num
  · exact min_le_left _ _

/-- The per-lens weight: every factor that does **not** depend on this turn. -/
def weight (L : ι → Lens) (M C T : ℝ) (i : ι) : ℝ := (L i).lam * (L i).mu * M * C * T

/-- The per-lens shape: every factor that does. -/
noncomputable def shape (a : ι → Bool) (breadth : ℕ) (i : ι) : ℝ :=
  sigma (deltaAt a i) * (1 + entropyAt a breadth i)

/-- One lens's contribution to the sum. -/
noncomputable def term (L : ι → Lens) (a : ι → Bool) (breadth : ℕ) (M C T : ℝ) (i : ι) : ℝ :=
  weight L M C T i * shape a breadth i

/-- **The factor order is the PowerShell's, and this says so.** `:401` multiplies
`$l * $si * (1.0 + $Hi) * $m_ * $M * $C * $T` in that order; `term` groups the
turn-independent factors first so the inequalities below are one rewrite rather
than six. Over `ℝ` the two agree — but leaving that implicit would be a silent
divergence from the modelled code, and silent divergence is how a model stops
describing its subject. -/
theorem term_eq_ps1_order (L : ι → Lens) (a : ι → Bool) (breadth : ℕ) (M C T : ℝ) (i : ι) :
    term L a breadth M C T i =
      (L i).lam * sigma (deltaAt a i) * (1 + entropyAt a breadth i) * (L i).mu * M * C * T := by
  unfold term weight shape
  ring

/-- **The gauge.** `R/s+ = (1/K) · Σᵢ λᵢ · σ(δᵢ) · (1 + Hᵢ) · μᵢ · M · C · T`,
with `K` the number of lenses summed over (`:404-405`).

The divisor is `Fintype.card ι` by construction, never a literal `9`. A lens that
can never fire still divides the sum — the defect fixed at `:362-366`, where
Nova's activity was pinned at `0` because its signal was read before it was
defined. A model that wrote `K` as anything but the cardinality of the index set
would make that class of bug invisible here too. -/
noncomputable def gauge (L : ι → Lens) (a : ι → Bool) (breadth : ℕ) (M C T : ℝ) : ℝ :=
  (∑ i, term L a breadth M C T i) / (Fintype.card ι)

/-- The divisor is the cardinality of the lens set. Stated as an equation so a
future edit that hardcodes the count has to break a theorem, not just a
constant. -/
theorem gauge_divisor_eq_card [Nonempty ι] (L : ι → Lens) (a : ι → Bool) (breadth : ℕ)
    (M C T : ℝ) :
    gauge L a breadth M C T * (Fintype.card ι) = ∑ i, term L a breadth M C T i := by
  have hc : (0 : ℝ) < (Fintype.card ι : ℝ) := by exact_mod_cast Fintype.card_pos
  unfold gauge
  field_simp

/-! ## The quiet ensemble — the floor -/

/-- The all-quiet activity vector: no lens's signal moved this turn. -/
def allQuiet (ι : Type*) : ι → Bool := fun _ => false

/-- The all-active vector: every lens's signal moved. -/
def allLive (ι : Type*) : ι → Bool := fun _ => true

@[simp] theorem actR_allQuiet (i : ι) : actR (allQuiet ι) i = 0 := by
  simp [actR, allQuiet]

@[simp] theorem actR_allLive (i : ι) : actR (allLive ι) i = 1 := by
  simp [actR, allLive]

@[simp] theorem meanAct_allQuiet : meanAct (allQuiet ι) = 0 := by
  simp [meanAct]

@[simp] theorem deltaAt_allQuiet (i : ι) : deltaAt (allQuiet ι) i = 0 := by
  simp [deltaAt]

@[simp] theorem entropyAt_allQuiet (breadth : ℕ) (i : ι) :
    entropyAt (allQuiet ι) breadth i = 0 := by
  unfold entropyAt
  split
  · rfl
  · simp

theorem meanAct_allLive [Nonempty ι] : meanAct (allLive ι) = 1 := by
  have hc : (0 : ℝ) < (Fintype.card ι : ℝ) := by exact_mod_cast Fintype.card_pos
  unfold meanAct
  rw [show (∑ i, actR (allLive ι) i) = (Fintype.card ι : ℝ) by simp]
  exact div_self hc.ne'

@[simp] theorem deltaAt_allLive [Nonempty ι] (i : ι) : deltaAt (allLive ι) i = 0 := by
  simp [deltaAt, meanAct_allLive]

theorem entropyAt_allLive_one (i : ι) : entropyAt (allLive ι) 1 i = 1 := by
  unfold entropyAt
  simp

/-! ## The four theorems that answer "the number is decoration" -/

/-- Positive weights: every `λ`, `μ` and every calibration factor strictly
positive. The shipped FORGE profile satisfies this (`forge_posWeights`), but the
theorems run on the hypothesis rather than on the constants, so retuning a weight
cannot invalidate them. -/
structure PosWeights (L : ι → Lens) (M C T : ℝ) : Prop where
  lam : ∀ i, 0 < (L i).lam
  mu : ∀ i, 0 < (L i).mu
  hM : 0 < M
  hC : 0 < C
  hT : 0 < T

theorem weight_pos {L : ι → Lens} {M C T : ℝ} (h : PosWeights L M C T) (i : ι) :
    0 < weight L M C T i := by
  unfold weight
  exact mul_pos (mul_pos (mul_pos (mul_pos (h.lam i) (h.mu i)) h.hM) h.hC) h.hT

theorem weight_nonneg {L : ι → Lens} {M C T : ℝ} (h : PosWeights L M C T) (i : ι) :
    0 ≤ weight L M C T i := (weight_pos h i).le

theorem shape_pos (a : ι → Bool) (breadth : ℕ) (i : ι) : 0 < shape a breadth i := by
  unfold shape
  have h1 := sigma_pos (deltaAt a i)
  have h2 := entropyAt_nonneg a breadth i
  nlinarith

theorem term_pos {L : ι → Lens} {M C T : ℝ} (h : PosWeights L M C T)
    (a : ι → Bool) (breadth : ℕ) (i : ι) : 0 < term L a breadth M C T i :=
  mul_pos (weight_pos h i) (shape_pos a breadth i)

/-- **`R/s+ = 0.0` is impossible, not merely forbidden.**

The spec calls a zero gauge "a violation — a placeholder never computed". A rule
that a number must not be zero is enforced by whoever remembers it. This says the
arithmetic cannot produce one: every factor is strictly positive and `σ` has no
zero.

The consequence is operational. A gauge reading `0.00` is therefore not a quiet
turn — it is a gauge that did not run. The two states are distinguishable, which
is exactly what an instrument has to be. -/
theorem gauge_pos [Nonempty ι] {L : ι → Lens} {M C T : ℝ} (h : PosWeights L M C T)
    (a : ι → Bool) (breadth : ℕ) : 0 < gauge L a breadth M C T := by
  have hc : (0 : ℝ) < (Fintype.card ι : ℝ) := by exact_mod_cast Fintype.card_pos
  unfold gauge
  apply div_pos _ hc
  apply Finset.sum_pos (fun i _ => term_pos h a breadth i)
  exact Finset.univ_nonempty

/-- **The all-quiet reading is the floor, for every input.**

Not "a small number" — the minimum. Two facts carry it: `δᵢ ≥ 0` with `σ`
monotone, so no lens can score below `σ(0)`; and `Hᵢ ≥ 0`, so no lens can lose
its breadth bonus below zero.

This is the loop-detector as a theorem. The master forbids "repetition without
change"; a turn that moved nothing is exactly `allQuiet`, and this proves such a
turn reads at or below every turn that moved something. The hook's BELOW RANGE
advice is a consequence of the arithmetic, not a heuristic bolted onto it. -/
theorem gauge_ge_floor [Nonempty ι] {L : ι → Lens} {M C T : ℝ}
    (hw : ∀ i, 0 ≤ weight L M C T i) (a : ι → Bool) (breadth : ℕ) :
    gauge L (allQuiet ι) 0 M C T ≤ gauge L a breadth M C T := by
  have hc : (0 : ℝ) < (Fintype.card ι : ℝ) := by exact_mod_cast Fintype.card_pos
  have hsum : ∑ i, term L (allQuiet ι) 0 M C T i ≤ ∑ i, term L a breadth M C T i := by
    refine Finset.sum_le_sum (fun i _ => ?_)
    unfold term
    refine mul_le_mul_of_nonneg_left ?_ (hw i)
    unfold shape
    rw [deltaAt_allQuiet, entropyAt_allQuiet]
    have h1 : sigma 0 ≤ sigma (deltaAt a i) := sigma_mono (deltaAt_nonneg a i)
    have h2 : (0 : ℝ) ≤ entropyAt a breadth i := entropyAt_nonneg a breadth i
    have h3 : (0 : ℝ) < sigma 0 := sigma_pos 0
    nlinarith
  unfold gauge
  rw [div_eq_mul_inv, div_eq_mul_inv]
  exact mul_le_mul_of_nonneg_right hsum (inv_nonneg.mpr hc.le)

/-- **A fully active ensemble at breadth 1 reads exactly twice the floor.**

An exact identity rather than a bound, and the cleanest evidence that the gauge
responds to its inputs.

Read *where* the factor of two comes from, because it is the engine's thesis in
arithmetic form: when every lens fires, every `δᵢ` returns to **zero** — each
lens sits exactly at the ensemble mean, since the mean is 1 — so `σ` contributes
precisely what it contributes in total silence. The entire difference is carried
by `Hᵢ = 1`, the breadth term.

Maximal agreement scores the same σ as maximal silence. The sigmoid rewards
*divergence*, and nine lenses agreeing is not divergence. The spec says this in
prose ("nine voices agreeing is a failure, not a success"); this is the same
statement with a proof attached. -/
theorem gauge_allLive_eq_two_mul_allQuiet [Nonempty ι] (L : ι → Lens) (M C T : ℝ) :
    gauge L (allLive ι) 1 M C T = 2 * gauge L (allQuiet ι) 0 M C T := by
  have h : ∑ i, term L (allLive ι) 1 M C T i = 2 * ∑ i, term L (allQuiet ι) 0 M C T i := by
    rw [Finset.mul_sum]
    refine Finset.sum_congr rfl (fun i _ => ?_)
    simp only [term, shape, deltaAt_allLive, deltaAt_allQuiet, entropyAt_allLive_one,
      entropyAt_allQuiet]
    ring
  unfold gauge
  rw [h, mul_div_assoc]

/-- **The instrument moves — the negative control, as a theorem.**

An instrument that cannot vary is decoration. This exhibits two inputs with
different readings, so no future edit can quietly replace the gauge with a
constant and keep this file green. A corollary of the two theorems above: the
floor is strictly positive, and a live ensemble reads exactly double it. -/
theorem gauge_not_constant [Nonempty ι] {L : ι → Lens} {M C T : ℝ}
    (h : PosWeights L M C T) :
    gauge L (allLive ι) 1 M C T ≠ gauge L (allQuiet ι) 0 M C T := by
  have hpos : 0 < gauge L (allQuiet ι) 0 M C T := gauge_pos h _ _
  rw [gauge_allLive_eq_two_mul_allQuiet]
  linarith

/-! ## The band classifier -/

/-- The hook's three-way verdict (`rot-lean-inject.ps1:418-430`). -/
inductive Band where
  | below
  | inRange
  | above
deriving DecidableEq, Repr

/-- The classifier, over the band bounds as **variables**. The current FORGE
values `0.9` and `1.8` are pinned separately, as an `example`; a theorem that
hardcoded them would go red the day the band is legitimately retuned, and the
obvious repair — weakening the theorem — would destroy real coverage. -/
noncomputable def classify (lo hi R : ℝ) : Band :=
  if R < lo then .below else if hi < R then .above else .inRange

theorem classify_below_iff (lo hi R : ℝ) : classify lo hi R = .below ↔ R < lo := by
  unfold classify
  by_cases h1 : R < lo
  · rw [if_pos h1]; exact iff_of_true rfl h1
  · rw [if_neg h1]
    by_cases h2 : hi < R
    · rw [if_pos h2]; exact iff_of_false (by decide) h1
    · rw [if_neg h2]; exact iff_of_false (by decide) h1

theorem classify_above_iff {lo hi R : ℝ} (h : lo ≤ hi) :
    classify lo hi R = .above ↔ hi < R := by
  unfold classify
  by_cases h1 : R < lo
  · rw [if_pos h1]
    exact iff_of_false (by decide) (by linarith)
  · rw [if_neg h1]
    by_cases h2 : hi < R
    · rw [if_pos h2]; exact iff_of_true rfl h2
    · rw [if_neg h2]; exact iff_of_false (by decide) h2

/-- **In-range is exactly the closed interval.** The statement a reader checks,
and the one that fails if a comparison is ever written `R ≤ lo` instead of
`R < lo` — an off-by-one no bound above would notice. -/
theorem classify_inRange_iff (lo hi R : ℝ) :
    classify lo hi R = .inRange ↔ (lo ≤ R ∧ R ≤ hi) := by
  unfold classify
  by_cases h1 : R < lo
  · rw [if_pos h1]
    exact iff_of_false (by decide) (fun hc => absurd hc.1 (by linarith))
  · rw [if_neg h1]
    by_cases h2 : hi < R
    · rw [if_pos h2]
      exact iff_of_false (by decide) (fun hc => absurd hc.2 (by linarith))
    · rw [if_neg h2]
      exact iff_of_true rfl ⟨not_lt.mp h1, not_lt.mp h2⟩

/-- **[DECORATIVE — kept, relabelled, and this note is the point.]**

This theorem is TRUE OF EVERY FUNCTION. `∃! b, f x = b` holds for any `f`
whatsoever, by virtue of `f` being a function; `classify` is never used in the
proof, and the same statement elaborates with `classify` replaced by an
arbitrary `f : ℝ → ℝ → ℝ → Band`. That was measured, not guessed.

Its previous doc comment claimed the classifier's verdict is "determined by the
reading and by nothing else — no state, no previous turn, no tie-break". Every
word of that is true, and NONE of it is established here: it follows from
`classify` being a total function in Lean at all, which the type already says.
A theorem whose name and comment claim more than the statement proves is exactly
what `SECURITY.md` in this repo calls a defect, so it is labelled rather than
quietly kept — and restated rather than deleted, because deleting it would hide
that the mistake was ever made.

The content it LOOKED like it had is `classify_surjective` below. -/
theorem classify_total (lo hi R : ℝ) : ∃! b : Band, classify lo hi R = b :=
  ⟨classify lo hi R, rfl, fun _ h => h.symm⟩

/-- **The theorem `classify_total` was mistaken for.** Every band is actually
reached: the classifier has no dead verdict.

This one genuinely constrains `classify`. A classifier that never returned
`inRange` — collapsing the band to a point, which is precisely what an
off-by-one in the comparison would do — satisfies `classify_total` and fails
this. It is mutation-tested for exactly that. -/
theorem classify_surjective {lo hi : ℝ} (h : lo ≤ hi) (b : Band) :
    ∃ R : ℝ, classify lo hi R = b := by
  cases b with
  | below =>
    exact ⟨lo - 1, (classify_below_iff lo hi (lo - 1)).mpr (by linarith)⟩
  | inRange =>
    exact ⟨lo, (classify_inRange_iff lo hi lo).mpr ⟨le_refl lo, h⟩⟩
  | above =>
    exact ⟨hi + 1, (classify_above_iff h).mpr (by linarith)⟩

/-! ## The FORGE profile as it stands on disk today

Measured from `rot-lean-inject.ps1:370-378`, cross-checked against the FORGE row
of `rot-lean.md` §4. These are **data**, not law: every theorem above quantifies
over the weights, so retuning any of them is a legal change that breaks nothing
here. What the constants exist for is the checker corpus and the `#eval` rows.
-/

/-- The nine lenses, in the hook's own order. -/
inductive Face where
  | nova | violet | antiVenom | venom | carnage | chroma | soleil | eidolon | claude
deriving DecidableEq, Repr, Inhabited

/-- The nine lenses enumerated. Written by hand rather than `deriving Fintype`,
which fails on this toolchain; `complete` is discharged by `decide`, so the list
cannot silently omit a lens. -/
instance : Fintype Face where
  elems := [Face.nova, Face.violet, Face.antiVenom, Face.venom, Face.carnage,
            Face.chroma, Face.soleil, Face.eidolon, Face.claude].toFinset
  complete := fun x => by cases x <;> decide

/-- The FORGE weights (`rot-lean-inject.ps1:370-378`). -/
def forge : Face → Lens
  | .nova => ⟨1.4, 1.05⟩
  | .violet => ⟨0.6, 0.85⟩
  | .antiVenom => ⟨1.9, 1.10⟩
  | .venom => ⟨1.2, 1.05⟩
  | .carnage => ⟨0.6, 0.90⟩
  | .chroma => ⟨1.0, 1.10⟩
  | .soleil => ⟨1.0, 0.95⟩
  | .eidolon => ⟨1.2, 1.10⟩
  | .claude => ⟨2.3, 1.15⟩

/-- The shipped profile satisfies the positivity hypothesis every theorem above
runs on. Without this, `gauge_pos`, `gauge_not_constant` and the rest would be
true of *some* ensemble and say nothing about ours. -/
theorem forge_posWeights : PosWeights forge 1.05 0.7 0.8 where
  lam := fun i => by cases i <;> norm_num [forge]
  mu := fun i => by cases i <;> norm_num [forge]
  hM := by norm_num
  hC := by norm_num
  hT := by norm_num

/-- There are nine lenses, and `K` is nine because there are nine — not because
`9` was written down anywhere. -/
theorem card_face_eq_nine : Fintype.card Face = 9 := by decide

/-- Today's band, as an `example` rather than a theorem: it documents the present
without becoming a hypothesis anything rests on. -/
example : classify 0.9 1.8 0.09 = Band.below := by
  unfold classify; norm_num

example : classify 0.9 1.8 1.2 = Band.inRange := by
  unfold classify; norm_num

example : classify 0.9 1.8 2.4 = Band.above := by
  unfold classify; norm_num

/-! ## The executable mirror — MEASURED, never PROVED

Everything above is over `ℝ`, where `Real.exp` is not computable: no `#eval` can
run it. The hook computes in IEEE doubles. This section is a `Float` mirror of
the same arithmetic, and its only purpose is to be executed — as the corpus the
checker feeds to the real `.ps1` and `.sh`.

**The boundary, stated so no reader has to guess.** `Float` is not `ℝ`. Nothing
below is the subject of any theorem above, and no theorem above transfers to it.
A disagreement between this mirror and the shipped hook is caught by the checker,
not by `lake build`. Presenting a `#eval` here as a proof would be exactly the
overclaim this project exists to avoid.
-/

/-- The sigmoid in IEEE doubles, as `[Math]::Exp` computes it. -/
def sigmaF (x : Float) : Float := 1.0 / (1.0 + Float.exp (-4.0 * (x - 0.5)))

/-- The FORGE weights as `(λ, μ)` pairs, in the hook's order. -/
def forgeF : List (Float × Float) :=
  [(1.4, 1.05), (0.6, 0.85), (1.9, 1.10), (1.2, 1.05), (0.6, 0.90),
   (1.0, 1.10), (1.0, 0.95), (1.2, 1.10), (2.3, 1.15)]

/-- The gauge in IEEE doubles. `acts` is the measured activity vector, `breadth`
the count of distinct signal categories that moved. -/
def gaugeF (acts : List Float) (breadth : Float) (M C T : Float) : Float :=
  let n := forgeF.length.toFloat
  let mean := acts.foldl (· + ·) 0.0 / n
  let terms := (forgeF.zip acts).map fun ((l, m), a) =>
    let d := Float.abs (a - mean)
    let s := sigmaF d
    let h := if breadth > 0.0 then min 1.0 (a / breadth) else 0.0
    l * s * (1.0 + h) * m * M * C * T
  terms.foldl (· + ·) 0.0 / n

/-- Rounded to two places, the form the hook emits (`:411`). -/
def round2 (x : Float) : Float := (x * 100.0).round / 100.0

/-! The corpus rows, each one a turn this session actually produced. The expected
values are what the running hook reported in its own payload, not what makes this
file agree with itself. -/

#eval round2 (gaugeF [0,0,0,0,0,0,0,0,0] 0 1.05 0.7 0.8)  -- hook reported 0.09
#eval round2 (gaugeF [0,0,0,0,0,0,1,0,1] 1 1.05 0.7 0.8)  -- hook reported 0.49
#eval round2 (gaugeF [0,1,0,0,0,0,0,0,0] 1 1.05 0.7 0.8)  -- hook reported 0.18
#eval round2 (gaugeF [1,1,1,1,1,1,1,1,1] 1 1.05 0.7 0.8)  -- twice the floor
#eval (forgeF.length, (List.replicate 9 (0:Float)).length)


/-! ## What "useful chaos" MEANS in the gauge -- stated as algebra, then proved

The README used to record 🩸 Carnage's chaos as NOT MODELLED, on the grounds
that "useful" is a judgement about an answer. Half of that was right and half
was laziness, and the lazy half was the interesting one.

The spec does not merely say chaos is good. It says something precise:

  "The sigmoid is the heart: it rewards MEDIAN divergence and damps both
   conformism (delta -> 0, sigma ~ 0.12) and pure chaos (delta -> 1, sigma ~ 0.88)."

That is not a slogan, it is a claim about a function -- and the function is
shipped. So it is provable, and leaving it unproved while writing "no instrument
exists" understated what this corpus can actually settle.

`sigma` is the logistic centred on 1/2 with slope 4. Its derivative is
`4 * sigma * (1 - sigma)`, so the quantity `sigma x * (1 - sigma x)` IS the
marginal return on one more unit of divergence, up to the constant 4. The
theorems below pin the shape of that return:

* it is **maximal exactly at the median** (delta = 1/2) -- so divergence pays
  best where the spec says it should;
* it is **strictly smaller anywhere else** -- so both a conformist lens and a
  maximally chaotic one earn strictly less per unit than a productively
  divergent one. That is the whole content of "chaos is fuel, not a goal";
* the gauge is **symmetric about the centre**, so conformism and pure chaos are
  penalised by the same construction rather than by two ad-hoc rules.

None of this says a chaotic sentence is a good sentence. It says the ENGINE
pays for chaos exactly the way the specification claims it does -- which is the
part a reader is entitled to have checked rather than asserted. -/

/-- σ is exactly one half at the centre of the band. The centre is `1/2` by
construction, so this is the sanity anchor everything below leans on. -/
theorem sigma_center : sigma (1/2) = 1/2 := by
  unfold sigma
  norm_num

/-- **The gauge is symmetric about the median.** Conformism at distance `d`
below centre is damped exactly as hard as chaos at distance `d` above it:
`σ(x) + σ(1-x) = 1` for every `x`.

This matters because it means the two failure modes the spec names -- the lens
that repeats the consensus and the lens that has flown off entirely -- are
penalised by ONE mechanism, not by a special case bolted on for each. -/
theorem sigma_symm_about_center (x : ℝ) : sigma x + sigma (1 - x) = 1 := by
  unfold sigma
  have h1 : (1 : ℝ) - x - 1 / 2 = -(x - 1 / 2) := by ring
  rw [h1]
  have h2 : -4 * -(x - 1 / 2) = -(-4 * (x - 1 / 2)) := by ring
  rw [h2, Real.exp_neg]
  have hp : (0 : ℝ) < Real.exp (-4 * (x - 1 / 2)) := Real.exp_pos _
  field_simp
  ring

/-- **The marginal return on divergence is bounded, and the bound is attained
only at the median.** `σ(1-σ)` is the derivative of σ up to the constant 4, so
this says: no lens can earn more than `1/4` per unit of divergence, whatever it
does.

`nlinarith` closes it from `(t - 1/2)^2 ≥ 0`, which is the honest reason it is
true: the quantity is a downward parabola in σ with its apex at `σ = 1/2`. -/
theorem marginal_gain_le_quarter (x : ℝ) : sigma x * (1 - sigma x) ≤ 1/4 := by
  nlinarith [sq_nonneg (sigma x - 1/2)]

/-- **...and strictly less than the maximum away from the median.** This is the
theorem that earns the phrase "useful chaos": a lens sitting at consensus and a
lens in free fall both earn STRICTLY less marginal R/s+ than one diverging
productively. Chaos is fuel; it is not the destination. -/
theorem marginal_gain_lt_quarter_off_center (x : ℝ) (h : sigma x ≠ 1/2) :
    sigma x * (1 - sigma x) < 1/4 := by
  have hne : sigma x - 1/2 ≠ 0 := sub_ne_zero.mpr h
  have hsq : 0 < (sigma x - 1/2)^2 := by positivity
  nlinarith [hsq]

/-- The median is the ONLY place the maximum is reached, stated from the other
side: attaining `1/4` forces `σ = 1/2`, which by `sigma_center` and strict
monotonicity forces `x = 1/2`. Without this the bound above could in principle
be attained everywhere and the "rewards median divergence" claim would be
empty. -/
theorem marginal_gain_max_iff_center (x : ℝ) :
    sigma x * (1 - sigma x) = 1/4 ↔ x = 1/2 := by
  constructor
  · intro h
    have hhalf : sigma x = 1/2 := by nlinarith [sq_nonneg (sigma x - 1/2)]
    have : sigma x = sigma (1/2) := by rw [hhalf, sigma_center]
    exact sigma_strictMono.injective this
  · intro h
    subst h
    rw [sigma_center]
    norm_num

/-- **Pure chaos is strictly worse than productive divergence**, in the gauge's
own units. A lens at maximal divergence earns strictly less marginal return
than one at the median -- the exact statement the spec makes in prose. -/
theorem pure_chaos_pays_less :
    sigma 1 * (1 - sigma 1) < sigma (1/2) * (1 - sigma (1/2)) := by
  rw [sigma_center]
  have h : sigma 1 ≠ 1/2 := by
    intro hc
    have : sigma 1 = sigma (1/2) := by rw [hc, sigma_center]
    have := sigma_strictMono.injective this
    norm_num at this
  have := marginal_gain_lt_quarter_off_center 1 h
  norm_num at this ⊢
  linarith

/-- ...and so is conformism, by the same theorem rather than a second rule.
This is the pair that makes the sigmoid the right shape instead of an arbitrary
squashing function. -/
theorem conformism_pays_less :
    sigma 0 * (1 - sigma 0) < sigma (1/2) * (1 - sigma (1/2)) := by
  rw [sigma_center]
  have h : sigma 0 ≠ 1/2 := by
    intro hc
    have : sigma 0 = sigma (1/2) := by rw [hc, sigma_center]
    have := sigma_strictMono.injective this
    norm_num at this
  have := marginal_gain_lt_quarter_off_center 0 h
  norm_num at this ⊢
  linarith


/-! ## The separation law -- the identity that makes R/s+ a law rather than a recipe

Everything above proves the gauge is well-formed. This section proves it has a
SHAPE, and the shape is the useful part.

`M` (memory resonance), `C` (confidence calibration) and `T` (temporal recency)
are per-TURN modifiers. `λ`, `μ`, `σ(δ)` and `H` describe the ENSEMBLE and the
divergence structure of that turn. Those are different kinds of quantity, and
the formula multiplies them together in one long product -- which invites the
belief that they are entangled and that changing `C` reshapes who contributes.

They are not entangled. `M`, `C` and `T` factor out of the entire sum exactly:

    R/s+(M, C, T) = M · C · T · R/s+(1, 1, 1)

That is `gauge_separates`, and it is the closest thing this engine has to a
Pythagorean identity: an exact equality, quantified over EVERY lens family,
every activity vector, every breadth and every choice of the three modifiers --
not a bound, not an approximation, not a claim about the shipped nine.

Three consequences worth stating separately, because each kills a different
misreading:

* `gauge_scales_in_C` -- doubling confidence doubles the gauge. Linear, not
  saturating, so the band thresholds move proportionally and a "0.9-1.8" range
  keeps meaning the same thing after rescaling.
* `gauge_zero_of_C_zero` -- zero confidence collapses the gauge to zero
  regardless of how the lenses diverged. Divergence cannot manufacture
  confidence, which is exactly the failure mode a divergence-rewarding gauge
  invites.
* `gauge_modifiers_commute` -- the three modifiers can be applied in any order
  or folded into one scalar. So an implementation that pre-multiplies `M*C*T`
  before the loop is provably the same engine as one that applies them inside
  it, and the shipped arms may differ there without disagreeing.

None of this is decoration: the separation is what licenses the debug log to
report a per-lens `term` and still have the reported `R/s+` be reproducible by
hand, because the modifiers are a single scalar on the outside. -/

/-- **The separation law.** The three per-turn modifiers factor out of the gauge
exactly. Quantified over every lens family, activity vector, breadth and every
`M`, `C`, `T` -- so it cannot expire when the roster or the weights change. -/
theorem gauge_separates (L : ι → Lens) (a : ι → Bool) (breadth : ℕ) (M C T : ℝ) :
    gauge L a breadth M C T = M * C * T * gauge L a breadth 1 1 1 := by
  unfold gauge
  rw [← mul_div_assoc, Finset.mul_sum]
  congr 1
  refine Finset.sum_congr rfl (fun i _ => ?_)
  unfold term weight
  ring

/-- Confidence enters linearly: scaling `C` scales the whole gauge by the same
factor. Stated on its own because it is the one people assume saturates. -/
theorem gauge_scales_in_C (L : ι → Lens) (a : ι → Bool) (breadth : ℕ) (M C T k : ℝ) :
    gauge L a breadth M (k * C) T = k * gauge L a breadth M C T := by
  rw [gauge_separates L a breadth M (k * C) T, gauge_separates L a breadth M C T]
  ring

/-- **Divergence cannot manufacture confidence.** With `C = 0` the gauge is zero
however the nine diverged -- the σ-reward has nothing to multiply. -/
theorem gauge_zero_of_C_zero (L : ι → Lens) (a : ι → Bool) (breadth : ℕ) (M T : ℝ) :
    gauge L a breadth M 0 T = 0 := by
  rw [gauge_separates L a breadth M 0 T]
  ring

/-- The modifiers commute and associate: any order, or folded into one scalar,
gives the same gauge. This is what lets one arm pre-multiply them outside the
loop and the other apply them inside without the two disagreeing. -/
theorem gauge_modifiers_commute (L : ι → Lens) (a : ι → Bool) (breadth : ℕ) (M C T : ℝ) :
    gauge L a breadth M C T = gauge L a breadth T M C := by
  rw [gauge_separates L a breadth M C T, gauge_separates L a breadth T M C]
  ring

/-- The neutral turn is the structural core itself: with all three modifiers at
`1` the gauge is exactly the ensemble term. The anchor the law is stated
against. -/
theorem gauge_neutral (L : ι → Lens) (a : ι → Bool) (breadth : ℕ) :
    gauge L a breadth 1 1 1 = (∑ i, (L i).lam * (L i).mu * shape a breadth i) /
      (Fintype.card ι) := by
  unfold gauge term weight
  congr 1
  refine Finset.sum_congr rfl (fun i _ => ?_)
  ring

end RotMoE
