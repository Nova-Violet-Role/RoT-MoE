/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A skip inside a green step is invisible to conclusion auditing

`checker/ci-honesty.sh` judges a completed CI run by reading every step's
**conclusion**. Measured on run `31308026819` (commit `cef996e`, the last pushed
one): 171 steps read, `PASS NO step was skipped`, 8/0, five working negative
controls. That is a real result and it is not in question here.

But it answers "did GitHub mark a step skipped", and there is a second question
it structurally cannot answer: **did the step's body actually exercise its
subject, or did it print `SKIP: no credentials` and exit green?** Scanning the
same run's `log.zip` — 721 KB, 4 jobs — found **45 runtime skip lines inside
steps that all concluded `success`**, across seven checkers:

| checker | why its substance did not run on a public runner |
|---|---|
| `preflight.sh` | optional tooling absent |
| `remind-measure.sh` | no credentials |
| `verdict-schedule-sim.sh` | `[week2]` schedule-gated |
| `ab-analyze.sh` | raw A/B transcripts are not committed |
| `portability.sh` | no drive-letter paths on that platform |
| `marketplace-session.sh` | no `claude` CLI / no credentials |
| `bench-router.sh` | credential-gated phase |

Every one of those skips is **honestly labelled** — the logs say "a SKIP is
never a pass", exit 3 or exit 4 — and the run carried zero real `::error` and
zero real `::warning` annotations. So this is not a fake green. It is a
**coverage gap that no instrument counts**, and an uncounted gap is free to grow:
add one more environment-gated skip tomorrow and nothing goes red.

This module proves the two halves of that:

* `conclusion_audit_is_blind_to_a_skip` — two runs, both all-success, differing
  only in whether a step skipped, are **indistinguishable** to conclusion
  auditing. Not noisy: blind. This is why a second instrument is needed rather
  than a stricter reading of the first.
* `ratchet_separates_them` — a declared-budget ratchet distinguishes exactly
  that pair, so the new instrument earns its place.

And it names the way such a ratchet gets quietly defused:
`a_budget_containing_everything_disarms_the_ratchet`. A budget is a list of
skips someone justified in writing; if it grows to cover the whole run the gate
still reports green while checking nothing. That is stated as a theorem so the
danger is visible rather than remembered.
-/

namespace RotCiSkip

/-- One CI step as the two instruments see it. `success` is the conclusion
GitHub records; `skipped` is whether the body printed a runtime skip while still
concluding success. -/
structure Step where
  /-- Identifier of the step, standing in for its name. -/
  id : Nat
  /-- The conclusion GitHub recorded. -/
  success : Bool
  /-- The body reported a runtime SKIP, yet the step still concluded. -/
  skipped : Bool
  deriving DecidableEq, Repr

/-- What `ci-honesty.sh` reads: every step concluded successfully. -/
def allSuccess (r : List Step) : Bool := r.all (fun s => s.success)

/-- A step that both concluded AND exercised its subject. -/
def substantive (s : Step) : Bool := s.success && !s.skipped

/-- Steps that actually tested something. -/
def covered : List Step → Nat
  | [] => 0
  | s :: rest => cond (substantive s) 1 0 + covered rest

/-- A skip nobody declared in the committed budget. -/
def undeclared (decl : List Nat) (s : Step) : Bool :=
  s.skipped && !(decl.contains s.id)

/-- The gate: no step may skip unless its skip was declared and justified. -/
def ratchet (decl : List Nat) (r : List Step) : Bool :=
  !(r.any (undeclared decl))

/-! ## Why conclusion auditing cannot see this -/

/-- **The blindness.** These two runs are both entirely `success`; one exercised
its subject and one printed a skip. Conclusion auditing returns the same answer
for both, so no amount of care reading conclusions recovers the difference. -/
theorem conclusion_audit_is_blind_to_a_skip :
    allSuccess [⟨1, true, false⟩] = allSuccess [⟨1, true, true⟩] ∧
    ([⟨1, true, false⟩] : List Step) ≠ [⟨1, true, true⟩] := by decide

/-- **The payoff.** The ratchet distinguishes exactly the pair that defeated
conclusion auditing, which is what makes it a second instrument rather than a
restatement of the first. -/
theorem ratchet_separates_them :
    ratchet [] [⟨1, true, false⟩] = true ∧
    ratchet [] [⟨1, true, true⟩] = false := by decide

/-- A skipping step contributes nothing to coverage, whatever its conclusion. -/
theorem a_skipping_step_adds_no_coverage (s : Step) (rest : List Step)
    (h : s.skipped = true) : covered (s :: rest) = covered rest := by
  simp only [covered, substantive, h, Bool.not_true, Bool.and_false,
    Bool.cond_false, Nat.zero_add]

/-- Coverage never exceeds the number of steps: it cannot be inflated. -/
theorem covered_le_length (r : List Step) : covered r ≤ r.length := by
  induction r with
  | nil => exact Nat.le_refl 0
  | cons s rest ih =>
    cases h : substantive s with
    | false => simp only [covered, h, Bool.cond_false, Nat.zero_add, List.length_cons]; omega
    | true => simp only [covered, h, Bool.cond_true, List.length_cons]; omega

/-! ## The ratchet -/

/-- **Any undeclared skip is caught**, wherever it sits in the run. -/
theorem ratchet_detects_any_undeclared_skip (decl : List Nat) (r : List Step)
    (s : Step) (hmem : s ∈ r) (hskip : s.skipped = true)
    (hnd : decl.contains s.id = false) : ratchet decl r = false := by
  have hu : undeclared decl s = true := by
    simp only [undeclared, hskip, hnd, Bool.not_false, Bool.true_and]
  have hany : r.any (undeclared decl) = true :=
    List.any_eq_true.mpr ⟨s, hmem, hu⟩
  simp only [ratchet, hany, Bool.not_true]

/-- A skip that was declared is admitted — the budget is what makes the gate
usable on a runner that genuinely cannot host every checker. -/
theorem declared_skip_is_admitted (decl : List Nat) (s : Step)
    (h : decl.contains s.id = true) : undeclared decl s = false := by
  simp only [undeclared, h, Bool.not_true, Bool.and_false]

theorem no_undeclared_when_all_declared (decl : List Nat) :
    ∀ r : List Step, (∀ s ∈ r, decl.contains s.id = true) →
      r.any (undeclared decl) = false := by
  intro r
  induction r with
  | nil => intro _; rfl
  | cons x xs ih =>
    intro h
    have hx : undeclared decl x = false :=
      declared_skip_is_admitted decl x (h x (by simp))
    have hxs : xs.any (undeclared decl) = false := ih (fun s hs => h s (by simp [hs]))
    simp only [List.any_cons, hx, hxs, Bool.or_false]

/-- **The loosening, named.** A budget that covers every step reports green
while checking nothing. The budget is therefore the thing to review, not the
verdict — this is the mechanism by which such a gate is quietly defused. -/
theorem a_budget_containing_everything_disarms_the_ratchet
    (decl : List Nat) (r : List Step)
    (h : ∀ s ∈ r, decl.contains s.id = true) : ratchet decl r = true := by
  simp only [ratchet, no_undeclared_when_all_declared decl r h, Bool.not_false]

/-- An empty budget is the strictest setting: every skip is flagged. -/
theorem empty_budget_flags_every_skip (r : List Step) (s : Step)
    (hmem : s ∈ r) (hskip : s.skipped = true) : ratchet [] r = false :=
  ratchet_detects_any_undeclared_skip [] r s hmem hskip rfl

/-- Growing the budget can only weaken the gate, never strengthen it. Stated so
"we added one entry" is understood as spending coverage, not gaining it. -/
theorem ratchet_weakens_as_the_budget_grows (d₁ d₂ : List Nat) (r : List Step)
    (hsub : ∀ x, d₁.contains x = true → d₂.contains x = true)
    (h : ratchet d₁ r = true) : ratchet d₂ r = true := by
  cases hd : r.any (undeclared d₂) with
  | false => simp only [ratchet, hd, Bool.not_false]
  | true =>
    obtain ⟨s, hmem, hu⟩ := List.any_eq_true.mp hd
    have hskip : s.skipped = true := by
      cases hs : s.skipped with
      | true => rfl
      | false =>
        simp only [undeclared, hs, Bool.false_and] at hu
        exact Bool.noConfusion hu
    have hnd₂ : d₂.contains s.id = false := by
      cases hc : d₂.contains s.id with
      | false => rfl
      | true =>
        simp only [undeclared, hc, Bool.not_true, Bool.and_false] at hu
        exact Bool.noConfusion hu
    have hnd₁ : d₁.contains s.id = false := by
      cases hc : d₁.contains s.id with
      | false => rfl
      | true => rw [hsub s.id hc] at hnd₂; exact Bool.noConfusion hnd₂
    have hany1 : r.any (undeclared d₁) = true :=
      List.any_eq_true.mpr ⟨s, hmem, by
        simp only [undeclared, hskip, hnd₁, Bool.not_false, Bool.true_and]⟩
    simp only [ratchet, hany1, Bool.not_true] at h
    exact Bool.noConfusion h

/-! ## Executable checks

The counts are **measurements of run `31308026819`**, so they are `#guard`s
documenting the present, never theorems anything rests on. -/

/-- Steps read by `ci-honesty.sh` on run 31308026819. -/
def measuredRunSteps : Nat := 171
/-- Distinct checkers observed printing a runtime skip inside a green step. -/
def measuredSkippingCheckers : Nat := 7
/-- Real `::error` annotations in that run. -/
def measuredErrorAnnotations : Nat := 0
/-- Real `::warning` annotations in that run. -/
def measuredWarningAnnotations : Nat := 0

#guard measuredSkippingCheckers < measuredRunSteps
#guard measuredErrorAnnotations = 0
#guard measuredWarningAnnotations = 0

#guard allSuccess [⟨1, true, true⟩] = true
#guard substantive ⟨1, true, true⟩ = false
#guard substantive ⟨1, true, false⟩ = true
#guard covered [⟨1, true, false⟩, ⟨2, true, true⟩] = 1
#guard covered [] = 0
#guard ratchet [2] [⟨1, true, false⟩, ⟨2, true, true⟩] = true
#guard ratchet [] [⟨1, true, false⟩, ⟨2, true, true⟩] = false
#guard ratchet [1, 2] [⟨1, true, true⟩, ⟨2, true, true⟩] = true
#guard undeclared [] ⟨9, true, true⟩ = true
#guard undeclared [9] ⟨9, true, true⟩ = false

end RotCiSkip
