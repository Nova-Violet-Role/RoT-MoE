/-
Copyright 2026 Saimonokuma.

VACUITY IS INVISIBLE TO THE INSTRUMENT CHAIN.

`lean/Proofs/RotVacuity.lean:26` exhibits the
specimen in valid Lean:

    theorem impressive_sounding_name (h : 0 = 1) : EverythingIsFine := by omega

and states the consequence at `:29-30`:

    "Every instrument this repo already runs would report that as verified.
     None of them asks the one question that matters: can the hypotheses
     ever hold?"

That is asserted in a docstring. This file proves it.

The claim is not "the instruments are weak". It is stronger and exact: on the
axis that separates a vacuous claim from a real one, every instrument in the
chain is a CONSTANT FUNCTION -- so no reading of any of them, in any
combination, carries one bit about vacuity. `informative_not_in_chain` is the
sharp form: the function that DOES distinguish provably is not one of them.

That is why `RotVacuity.lean`'s method has to be what it is -- instantiate at a
concrete witness (`:34-37`). Not a better instrument. A different question.
-/

namespace Proofs.RotMoe.VacuityInvisible

/-- A theorem as the instruments see it. `hyps` records the ONE fact none of
    them measures: whether the hypotheses can actually be satisfied. -/
structure Claim where
  hyps : Bool
deriving DecidableEq, Repr

/-- `theorem impressive_sounding_name (h : 0 = 1) : ...` -- hypotheses
    unsatisfiable, so the theorem is true and says nothing. -/
def vacuous : Claim := ⟨false⟩

/-- A theorem with at least one case it applies to. -/
def real : Claim := ⟨true⟩

-- The three instruments this project closes every proof with.
-- Each is a constant: it returns the same verdict for BOTH claims above.

/-- `lake build` exit 0. -/
def elaborates (_ : Claim) : Bool := true

/-- `#print axioms` shows no `sorryAx`. -/
def axiomsClean (_ : Claim) : Bool := true

/-- `lake env leanchecker` exit 0, zero bytes. -/
def kernelRechecks (_ : Claim) : Bool := true

/-- The closing ritual, as a list of instruments. -/
def chain : List (Claim → Bool) := [elaborates, axiomsClean, kernelRechecks]

/-- The question none of them asks. -/
def informative (c : Claim) : Bool := c.hyps

-- Each instrument, individually blind.

theorem elaboration_is_constant (c₁ c₂ : Claim) : elaborates c₁ = elaborates c₂ := rfl

theorem axioms_is_constant (c₁ c₂ : Claim) : axiomsClean c₁ = axiomsClean c₂ := rfl

theorem kernel_is_constant (c₁ c₂ : Claim) : kernelRechecks c₁ = kernelRechecks c₂ := rfl

/-- Running all three changes nothing: the whole ritual is blind together. -/
theorem whole_chain_is_blind (c₁ c₂ : Claim) :
    elaborates c₁ = elaborates c₂
    ∧ axiomsClean c₁ = axiomsClean c₂
    ∧ kernelRechecks c₁ = kernelRechecks c₂ :=
  ⟨rfl, rfl, rfl⟩

/-- Quantified over the chain, not enumerated: NO member distinguishes any two
    claims. Adding a fourth instrument of the same kind would not help. -/
theorem no_instrument_in_chain_detects (f : Claim → Bool) (hf : f ∈ chain)
    (c₁ c₂ : Claim) : f c₁ = f c₂ := by
  simp only [chain, List.mem_cons, List.not_mem_nil, or_false] at hf
  rcases hf with h | h | h <;> subst h <;> rfl

-- What a discriminating instrument would have to look like.

theorem informative_distinguishes : informative vacuous ≠ informative real := by decide

theorem witness_instantiation_distinguishes : ∃ f : Claim → Bool, f vacuous ≠ f real :=
  ⟨informative, by decide⟩

/-- THE POINT. The function that separates vacuous from real is not in the
    chain -- and this is proved, not observed. Any `f` in the chain is constant
    by `no_instrument_in_chain_detects`; `informative` is not constant; so
    `informative ∉ chain`. -/
theorem informative_not_in_chain : informative ∉ chain := by
  intro h
  exact informative_distinguishes (no_instrument_in_chain_detects informative h vacuous real)

/-- The vacuous claim passes every instrument and is still worthless. This is
    the specimen at `RotVacuity.lean:26`, stated as a fact about the chain. -/
theorem vacuous_passes_everything :
    elaborates vacuous = true ∧ axiomsClean vacuous = true ∧ kernelRechecks vacuous = true :=
  ⟨rfl, rfl, rfl⟩

theorem vacuous_is_not_informative : informative vacuous = false := by decide

end Proofs.RotMoe.VacuityInvisible
