/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Proofs.RotGauge

-- Mathlib's `hashCommand` linter forbids `#guard` in files destined for Mathlib.
-- This file is not one, and the `#guard` block below is load-bearing: a false
-- guard is an ERROR, not a warning, so silencing the style linter disarms
-- nothing. Same reasoning, same one-liner, as `RotDorks` and `RotEnsemble`.
-- The linter is only *present* when the import chain pulls full Mathlib, which
-- is why `RotOrdering` and `RotTrap` carry `#guard`s without it.
set_option linter.hashCommand false

/-! # `R/s+ = 0` is unreachable for a real turn — and why D6 could not see that

`engine/rot-lean.md:316` states one of the two absolute laws:

> `R/s+ = 0.0` is a **violation** — a placeholder never computed; the gauge must
> be real or it is not.

Until this module, **nothing enforced it**, and the live log held 96 records
reading `"Rs":0` out of 1755. Every one had `"mu":0` on all nine lenses, so
every `term` was zero by construction. They are historical — the newest is
`2026-08-09T21:56:32`, and the shipped router sets `MUS` unconditionally at
`hooks/rot-router.sh:274`, so it cannot produce one today (probed live:
`Rs = 0.66427`, every `mu` in `{0.85,0.9,0.95,1.05,1.1,1.15}`).

The reason to prove it anyway is the second finding, which is the real one.
`checker/dominance.sh:218-220` implements D6 RECOMPUTABILITY as

```javascript
const sum = r.lenses.reduce((a,x) => a + x.term, 0);
if (Math.abs(rs - r.Rs) < 0.01) okc++;
```

On an all-zero record that is `|0 - 0| < 0.01` — a **pass**. The gauge could
break completely, emit nothing but zeros, and D6 would stay green. A check that
cannot distinguish "the arithmetic is right" from "there is no arithmetic" is
not evidence of the first. `recomputes_does_not_imply_informative` is that hole,
stated as a theorem with a witness.

The distinction this module is careful to preserve: **a turn on which no lens
fired is legitimate and must NOT be flagged.** With every activity zero the
sigmoid still contributes `σ(0) ≈ 0.1192`, so an idle turn reads *positive*, not
zero — `idle_is_not_a_violation`. Only a zero *factor* can drive the gauge to
zero, and no factor is ever legitimately zero. A gate that flagged idle turns
would be a spec forbidding a correct future; this one flags a broken instrument.

## Why scaled integers

Every quantity the router logs is a terminating decimal, so the model carries
each as an exact integer in fixed units: λ and μ in hundredths, σ in
ten-thousandths, `H` in thousandths, `M`/`C`/`T` in hundredths. This is not a
convenience — `decide` cannot evaluate ℚ arithmetic here, because `Rat`
multiplication normalises through `Nat.gcd`, which is well-founded recursion the
kernel will not reduce. On ℤ every concrete claim below is kernel-decidable, so
the `#guard` block is a real execution rather than decoration. `Rs` itself is
still defined over ℚ, and `Rs_eq_zero_iff_reading_zero` ties the two together.
-/

namespace RotGaugeZero

/-- Fixed-point units, one place each so a reader can check the scaling. -/
def lamScale : ℤ := 100
def sigScale : ℤ := 10000
def hScale : ℤ := 1000
def mctScale : ℤ := 100

/-- The product of every scale factor in one `term`: λ·σ·(1+H)·μ·M·C·T. -/
def termScale : ℤ := lamScale * sigScale * hScale * lamScale * mctScale * mctScale * mctScale

/-- One lens's contribution as the router logs it: `hooks/rot-router.sh:325`,
    `term = lam[i] * s * (1.0 + H) * mu[i] * M * C * T`. -/
structure LensTerm where
  lambda : ℤ
  sigma  : ℤ
  H      : ℤ
  mu     : ℤ
deriving DecidableEq, Repr

/-- The record-level factors, shared by all nine lenses. -/
structure GaugeRecord where
  lenses : List LensTerm
  M : ℤ
  C : ℤ
  T : ℤ
deriving DecidableEq, Repr

/-- `term`, in units of `termScale`. -/
def LensTerm.term (M C T : ℤ) (l : LensTerm) : ℤ :=
  l.lambda * l.sigma * (hScale + l.H) * l.mu * M * C * T

def GaugeRecord.terms (r : GaugeRecord) : List ℤ :=
  r.lenses.map (LensTerm.term r.M r.C r.T)

/-- The summed numerator — what the gauge actually *reads* before averaging. -/
def GaugeRecord.reading (r : GaugeRecord) : ℤ := r.terms.sum

/-- `K` is the lens count, not a constant: adding a lens moves it. -/
def GaugeRecord.K (r : GaugeRecord) : ℕ := r.lenses.length

/-- `R/s+ = (1/K) * SUM(...)`, in real units. -/
noncomputable def GaugeRecord.Rs (r : GaugeRecord) : ℚ :=
  if r.K = 0 then 0 else (r.reading : ℚ) / ((r.K : ℚ) * (termScale : ℚ))

/-- What a record looks like when it is not broken. Note what is *absent*: no
    requirement that any lens be active. Activity lives in `H` and in `sigma`,
    and both are allowed their idle values. -/
structure Wellformed (r : GaugeRecord) : Prop where
  nonempty   : r.lenses ≠ []
  lambda_pos : ∀ l ∈ r.lenses, 0 < l.lambda
  sigma_pos  : ∀ l ∈ r.lenses, 0 < l.sigma
  H_nonneg   : ∀ l ∈ r.lenses, 0 ≤ l.H
  mu_pos     : ∀ l ∈ r.lenses, 0 < l.mu
  M_pos      : 0 < r.M
  C_pos      : 0 < r.C
  T_pos      : 0 < r.T

/-- A positive-length list of strictly positive integers sums to something
    strictly positive. Deliberately **not** `private`: `checker/axiom-audit.sh`
    resolves every theorem name from an importing module, and a `private` name
    is invisible there — which would let a `sorry` hide behind it. -/
theorem sum_pos_of_all_pos (l : List ℤ) (hne : l ≠ [])
    (hx : ∀ x ∈ l, 0 < x) : 0 < l.sum := by
  induction l with
  | nil => exact absurd rfl hne
  | cons a t ih =>
    rcases eq_or_ne t [] with rfl | ht
    · simpa using hx a (by simp)
    · have h2 := ih ht (fun z hz => hx z (by simp [hz]))
      have h1 := hx a (by simp)
      simpa using add_pos h1 h2

/-- Every lens of a well-formed record contributes strictly positively. -/
theorem term_pos {r : GaugeRecord} (w : Wellformed r) {l : LensTerm}
    (hl : l ∈ r.lenses) : 0 < l.term r.M r.C r.T := by
  have h1 := w.lambda_pos l hl
  have h2 := w.sigma_pos l hl
  have h3 := w.H_nonneg l hl
  have h4 := w.mu_pos l hl
  have hH : (0:ℤ) < hScale + l.H := by unfold hScale; omega
  unfold LensTerm.term
  exact mul_pos (mul_pos (mul_pos (mul_pos (mul_pos (mul_pos h1 h2) hH) h4)
    w.M_pos) w.C_pos) w.T_pos

theorem all_terms_pos {r : GaugeRecord} (w : Wellformed r) :
    ∀ x ∈ r.terms, 0 < x := by
  intro x hx
  rcases List.mem_map.1 hx with ⟨l, hl, rfl⟩
  exact term_pos w hl

theorem K_pos {r : GaugeRecord} (w : Wellformed r) : 0 < r.K := by
  cases hl : r.lenses with
  | nil => exact absurd hl w.nonempty
  | cons a t => simp [GaugeRecord.K, hl]

theorem terms_ne_nil {r : GaugeRecord} (w : Wellformed r) : r.terms ≠ [] := by
  cases hl : r.lenses with
  | nil => exact absurd hl w.nonempty
  | cons a t => simp [GaugeRecord.terms, hl]

/-- **P4.4, in the units the log carries.** -/
theorem reading_pos {r : GaugeRecord} (w : Wellformed r) : 0 < r.reading :=
  sum_pos_of_all_pos _ (terms_ne_nil w) (all_terms_pos w)

theorem termScale_pos : 0 < termScale := by decide

/-- Zero-ness transfers exactly between the integer reading and the rational
    `R/s+`, so nothing is lost by gating on the former. -/
theorem Rs_eq_zero_iff_reading_zero {r : GaugeRecord} (hK : r.K ≠ 0) :
    r.Rs = 0 ↔ r.reading = 0 := by
  have hKQ : ((r.K : ℚ)) ≠ 0 := Nat.cast_ne_zero.2 hK
  have hS : ((termScale : ℚ)) ≠ 0 := by
    have := termScale_pos; positivity
  unfold GaugeRecord.Rs
  rw [if_neg hK, div_eq_zero_iff]
  constructor
  · rintro (h | h)
    · exact_mod_cast h
    · exact absurd h (by simp [hKQ, hS])
  · intro h; left; exact_mod_cast h

/-- **P4.4.** A well-formed gauge record cannot read zero. The spec called this
    an absolute law; this is the law. -/
theorem Rs_pos {r : GaugeRecord} (w : Wellformed r) : 0 < r.Rs := by
  have hK : r.K ≠ 0 := Nat.pos_iff_ne_zero.1 (K_pos w)
  have hKQ : (0:ℚ) < (r.K : ℚ) := by exact_mod_cast K_pos w
  have hS : (0:ℚ) < (termScale : ℚ) := by exact_mod_cast termScale_pos
  have hR : (0:ℚ) < (r.reading : ℚ) := by exact_mod_cast reading_pos w
  unfold GaugeRecord.Rs
  rw [if_neg hK]
  exact div_pos hR (by positivity)

/-- Contrapositive, and the form a checker can act on: a zero reading proves a
    zero *factor* — never a quiet turn. -/
theorem Rs_zero_means_a_broken_factor {r : GaugeRecord} (h : r.Rs = 0) :
    ¬ Wellformed r := fun w => absurd h (ne_of_gt (Rs_pos w))

theorem reading_zero_means_a_broken_factor {r : GaugeRecord}
    (h : r.reading = 0) : ¬ Wellformed r :=
  fun w => absurd h (ne_of_gt (reading_pos w))

/-! ## The nine lenses as shipped

`hooks/rot-router.sh:273-275`. `sigma = 0.1192` is the idle value: every
activity zero, so every `delta` is zero and `σ(0) = 1/(1+e^2) ≈ 0.1192`. -/

/-- λ and μ in hundredths, exactly as `hooks/rot-router.sh:273-274` sets them:
    `1.4 0.6 1.9 1.2 0.6 1.0 1.0 1.2 2.3` and
    `1.05 0.85 1.10 1.05 0.90 1.10 0.95 1.10 1.15`. -/
def shippedPairs : List (ℤ × ℤ) :=
  [(140, 105), (60, 85), (190, 110),
   (120, 105), (60, 90), (100, 110),
   (100, 95), (120, 110), (230, 115)]

/-- `σ(0) ≈ 0.1192` in ten-thousandths. -/
def idleSigma : ℤ := 1192

/-- The record produced by a turn on which **no lens fired at all**. -/
def idleRecord : GaugeRecord :=
  { lenses := shippedPairs.map (fun p => ⟨p.1, idleSigma, 0, p.2⟩)
    M := 100, C := 70, T := 80 }

/-- The 96 records actually found in the live log: identical, except μ = 0. -/
def brokenRecord : GaugeRecord :=
  { lenses := shippedPairs.map (fun p => ⟨p.1, idleSigma, 0, 0⟩)
    M := 100, C := 70, T := 80 }

theorem idle_lens_count : idleRecord.K = 9 := by decide
theorem broken_lens_count : brokenRecord.K = 9 := by decide

/-- **An idle turn is not a violation.** Nine lenses, none active, and the gauge
    still reads positive. A checker that flagged this would be forbidding a
    correct future. -/
theorem idle_is_not_a_violation : 0 < idleRecord.reading := by decide

/-- The historical bug, reproduced: μ = 0 on every lens drives the reading to
    exactly zero regardless of everything else in the record. -/
theorem all_mu_zero_forces_zero : brokenRecord.reading = 0 := by decide

/-- And it is genuinely the μ that did it — the two records differ in nothing
    else. -/
theorem broken_differs_from_idle_only_in_mu :
    brokenRecord.M = idleRecord.M ∧ brokenRecord.C = idleRecord.C ∧
    brokenRecord.T = idleRecord.T ∧
    brokenRecord.lenses.map (·.lambda) = idleRecord.lenses.map (·.lambda) ∧
    brokenRecord.lenses.map (·.sigma) = idleRecord.lenses.map (·.sigma) ∧
    brokenRecord.lenses.map (·.mu) ≠ idleRecord.lenses.map (·.mu) := by
  refine ⟨rfl, rfl, rfl, by decide, by decide, by decide⟩

theorem broken_is_not_wellformed : ¬ Wellformed brokenRecord :=
  reading_zero_means_a_broken_factor all_mu_zero_forces_zero

/-! ## The D6 hole

`checker/dominance.sh:218-220` sums the logged `term` fields and compares the
result to the logged aggregate. That is a real check — it catches a lens
multiplied by the wrong μ, or an aggregate written by a different code path.
What it cannot catch is a record with no arithmetic in it at all. -/

/-- A record as it appears *in the log*, where the per-lens terms and the
    aggregate are two independently written fields that D6 cross-checks. -/
structure LoggedRecord where
  loggedTerms : List ℤ
  loggedAgg   : ℤ
  loggedK     : ℕ
deriving DecidableEq, Repr

/-- D6, transcribed. -/
def LoggedRecord.recomputes (x : LoggedRecord) : Bool :=
  x.loggedK != 0 && x.loggedTerms.sum == x.loggedAgg

/-- The property D6 is *believed* to establish. -/
def LoggedRecord.informative (x : LoggedRecord) : Bool := x.loggedAgg != 0

def log (r : GaugeRecord) : LoggedRecord :=
  { loggedTerms := r.terms, loggedAgg := r.reading, loggedK := r.K }

theorem honest_log_recomputes {r : GaugeRecord} (w : Wellformed r) :
    (log r).recomputes = true := by
  have hK : r.K ≠ 0 := Nat.pos_iff_ne_zero.1 (K_pos w)
  simp [log, LoggedRecord.recomputes, GaugeRecord.reading, hK]

/-- **The hole.** The broken record passes D6: zeros sum to zero and the logged
    aggregate is zero, so the comparison succeeds on a record that measured
    nothing. -/
theorem broken_record_passes_d6 : (log brokenRecord).recomputes = true := by decide

theorem broken_record_is_not_informative :
    (log brokenRecord).informative = false := by decide

/-- Stated as the implication that fails: passing D6 does **not** establish that
    the gauge ran. This is why D6 needed a companion, not a replacement. -/
theorem recomputes_does_not_imply_informative :
    ∃ x : LoggedRecord, x.recomputes = true ∧ x.informative = false :=
  ⟨log brokenRecord, broken_record_passes_d6, broken_record_is_not_informative⟩

/-- The conjunction is strictly stronger than D6 alone — there is a record the
    pair rejects and D6 accepts. -/
theorem d6_with_informative_is_strictly_stronger :
    ∃ x : LoggedRecord, x.recomputes = true ∧
      ¬ (x.recomputes = true ∧ x.informative = true) := by
  refine ⟨log brokenRecord, broken_record_passes_d6, ?_⟩
  simp [broken_record_is_not_informative]

/-- And the strengthened check still accepts the idle turn — the pair is not
    merely stricter, it is stricter *in the right place*. -/
theorem idle_passes_the_strengthened_check :
    (log idleRecord).recomputes = true ∧ (log idleRecord).informative = true := by
  refine ⟨by decide, by decide⟩

/-- A well-formed record always passes both, so the new gate can never fail a
    healthy gauge. -/
theorem wellformed_passes_both {r : GaugeRecord} (w : Wellformed r) :
    (log r).recomputes = true ∧ (log r).informative = true := by
  refine ⟨honest_log_recomputes w, ?_⟩
  have h := reading_pos w
  simp only [log, LoggedRecord.informative, bne_iff_ne, ne_eq]
  exact ne_of_gt h

/-! ## Executable agreement -/

#guard idleRecord.K = 9
#guard brokenRecord.K = 9
#guard brokenRecord.reading == 0
#guard idleRecord.reading != 0
#guard decide (0 < idleRecord.reading)
#guard (log brokenRecord).recomputes
#guard !(log brokenRecord).informative
#guard (log idleRecord).recomputes
#guard (log idleRecord).informative
#guard shippedPairs.length = 9
#guard shippedPairs.all (fun p => p.1 > 0 && p.2 > 0)
#guard brokenRecord.terms.all (fun t => t == 0)
#guard idleRecord.terms.all (fun t => t != 0)
#guard termScale > 0

end RotGaugeZero
