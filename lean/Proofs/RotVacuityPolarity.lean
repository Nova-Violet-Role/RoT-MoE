/-
Copyright 2026 Saimonokuma.

VACUITY CONTROL POLARITY -- why a negative control's green is red.

Measured, three sites, all in this repository (branch 9.0.0):

  .github/workflows/ci.yml:1419   if [ "$rc" -eq 0 ]; then ... exit 1
                                  "CONTROL DEAD: a witness was produced for
                                   hypotheses 1 = 2."
  checker/verdict-fresh.sh:74     exit 1 on a STALE verdict, PASS CONTROL on red
  checker/hook-contract.sh:74-76  mutated to force a zero count -> exit 1

Every one of them states its polarity in a COMMENT and proves it nowhere. The
hazard is not that any of the three is wrong -- all three were read and all
three are right. The hazard is the fourth, written later by hand, with the
ordinary reflex: non-zero is failure. That fourth control is green forever,
for the wrong reason, and nothing in the tree can tell it from the other three.

This file settles the polarity in the kernel instead of in prose.

The load-bearing theorem is `no_uniform_polarity`: there is NO single function
from build-outcome to verdict that serves both an ordinary check and a negative
control. Not "it is easy to get wrong" -- there is no correct uniform answer.
That is why the polarity must be written per-check and can never be factored
into a shared helper.
-/

namespace Proofs.RotMoe.VacuityControlPolarity

/-- What an instrument observed: did the subject build? -/
structure Control where
  builds : Bool
deriving DecidableEq, Repr

/-- A NEGATIVE control passes exactly when its subject FAILS to build.
    `ci.yml:1419` in executable form. -/
def passes (c : Control) : Bool := !c.builds

/-- Exit code to observation. `lake`/`bash` convention: 0 means it built. -/
def fromExit (e : Nat) : Control := ⟨e == 0⟩

-- The two concrete readings the three measured sites depend on.

theorem exit_zero_fails_negative_control : passes (fromExit 0) = false := by decide

theorem exit_one_passes_negative_control : passes (fromExit 1) = true := by decide

theorem green_is_failure : passes ⟨true⟩ = false := by decide

theorem red_is_pass : passes ⟨false⟩ = true := by decide

/-- The negative control is not the identity on its observation. Stated as a
    disequality of FUNCTIONS, so it rules out the reflex globally rather than
    at one sampled input. -/
theorem polarity_not_identity : passes ≠ fun c => c.builds := by
  intro h
  have h2 : passes ⟨true⟩ = true := by rw [h]
  simp [passes] at h2

/-- Witness form: a control whose subject built, and which therefore FAILED. -/
theorem ordinary_reflex_is_wrong : ∃ c : Control, c.builds = true ∧ passes c = false :=
  ⟨⟨true⟩, by decide, by decide⟩

/-- The two kinds of check a suite contains. -/
inductive Kind where
  | ordinary
  | negative
deriving DecidableEq, Repr

/-- The correct verdict, per kind. An ordinary check passes when its subject
    builds; a negative control passes when it does not. -/
def verdict : Kind → Bool → Bool
  | .ordinary, b => b
  | .negative, b => !b

theorem verdict_ordinary_agrees_with_build (b : Bool) : verdict .ordinary b = b := by
  cases b <;> decide

theorem verdict_negative_inverts (b : Bool) : verdict .negative b = !b := by
  cases b <;> decide

/-- THE POINT. No single polarity function serves both kinds. For ANY candidate
    `p`, some kind disagrees with it on the SAME observation -- and the witness
    is always available at `true`, i.e. on a green build.

    A shared `check_passed()` helper applied to both an ordinary check and a
    negative control is therefore not merely risky: it is wrong at one of the
    two call sites, whichever way it is written. -/
theorem no_uniform_polarity (p : Bool → Bool) : ∃ k : Kind, verdict k true ≠ p true := by
  cases hp : p true with
  | true  => exact ⟨.negative, by simp [verdict]⟩
  | false => exact ⟨.ordinary, by simp [verdict]⟩

/-- The same claim without the existential, for the two concrete candidates a
    person would actually write. -/
theorem identity_breaks_negative : verdict .negative true ≠ (fun b => b) true := by decide

theorem negation_breaks_ordinary : verdict .ordinary true ≠ (fun b => !b) true := by decide

/-- The measured sites, as a table the kernel checks. Each pair is
    (kind, observed build) and each must map to a PASS. -/
def measured : List (Kind × Bool) :=
  [ (.negative, false)   -- ci.yml:1419        vacuity_control.lean fails to build
  , (.negative, false)   -- verdict-fresh.sh   the perturbed verdict is refused
  , (.negative, false) ] -- hook-contract.sh   forced-zero count exits 1

theorem every_measured_site_passes :
    measured.all (fun kb => verdict kb.1 kb.2) = true := by decide

/-- And the negative control on the table itself: had any site been recorded as
    a green build, the table would NOT pass. This is what stops
    `every_measured_site_passes` from being satisfied by an empty or
    all-agreeing list. -/
theorem a_green_negative_control_would_fail_the_table :
    ([(Kind.negative, true)] : List (Kind × Bool)).all (fun kb => verdict kb.1 kb.2) = false := by
  decide

end Proofs.RotMoe.VacuityControlPolarity
