/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# How many observations a gate costs, and what a short circuit destroys

`Proofs.RotVacuousGate` proved that a vacuous gate carries no information and
that composing vacuous gates carries none either. It left two things as
examples rather than as laws, and an example is a weaker object than it looks:
`sound_does_not_imply_live` exhibits ONE gate -- the always-red one -- that
passes the break-it-and-watch-it-go-red test and is still worthless. Read
carelessly that is a fact about `alwaysRed`. The interesting claim is that
nothing about the test is repairable by choosing a better single check.

This module proves the general form, and it is a statement about OBSERVATIONS,
not about gates. A control run is an observation: it puts the world into one
state, runs the gate, and records the verdict. The question the compendium never
asked precisely is how many such records are needed before the word "verified"
is earned.

**The lower bound.** `one_observation_is_never_enough` says: fix ANY world `e`
and ANY verdict `v` you might have observed there. Two gates both produce `v`
at `e`; one is vacuous and one is not. So a single control -- whichever world it
plants, whatever colour comes back -- is consistent with a gate that means
everything and with a gate that means nothing. It does not narrow the space at
all. This is not a gap in a particular test, it is a counting fact, and no
cleverness in choosing the world escapes it.

**The upper bound.** `two_observations_are_always_enough` says the endpoints
decide it completely: a gate is vacuous exactly when its two verdicts agree.
`observations_determine_the_gate` is the sharper version -- two agreeing
observations pin the function itself, not merely its vacuity. Two is therefore
tight: one never suffices, two always does. The discipline this repository
arrived at by being burned -- trip the control AND confirm the clean tree -- is
exactly the minimal sufficient experiment, and it is minimal for a reason that
has nothing to do with taste.

**What a short circuit destroys.** The second half is about suites, and it is
the part that is genuinely surprising. `run` stops at the first red, which is
what a real hook chain does under `set -e`, and that operational detail has a
consequence: `a_red_prefix_blinds_everything_after_it` proves that a gate which
answers red in every world makes the ENTIRE remaining suite vacuous, however
informative its members are. `alwaysRed_blinds_an_informative_suffix` exhibits
it at minimum size: `honest` is provably non-vacuous, and `[alwaysRed, honest]`
is provably vacuous. Putting a good gate behind a broken one destroys the good
gate's information without touching the good gate.

The direction matters. `RotVacuousGate` warned that adding gates cannot create
information. This adds the sharper warning: adding a gate can DESTROY it. A
suite is not a bag of independent checks whose worst case is that one is
useless -- a single always-red member is not a wasted slot, it is a blindfold
over every check downstream of it.

Nothing here says any gate in this repository is always-red. That is measured,
not proved, and the measurement is what the controls are for.
-/
import Proofs.RotVacuousGate

namespace RotMoE.Observation

open RotMoE.Vacuity
open Evidence Verdict

/-- The other world. -/
def otherWorld : Evidence → Evidence
  | present => absent
  | absent => present

/-- The other verdict. -/
def otherVerdict : Verdict → Verdict
  | green => red
  | red => green

theorem otherWorld_ne (e : Evidence) : otherWorld e ≠ e := by
  cases e <;> decide

theorem otherVerdict_ne (v : Verdict) : otherVerdict v ≠ v := by
  cases v <;> decide

/-- The gate that answers `v` in world `e` and disagrees everywhere else. It
reproduces any single observation you like, and it is never vacuous. -/
def pin (e : Evidence) (v : Verdict) (e' : Evidence) : Verdict :=
  if e' = e then v else otherVerdict v

/-- The constant gate that answers `v` everywhere. It reproduces the same single
observation, and it is always vacuous. -/
def flat (v : Verdict) (_ : Evidence) : Verdict := v

theorem pin_at (e : Evidence) (v : Verdict) : pin e v e = v := by
  simp [pin]

theorem pin_off (e : Evidence) (v : Verdict) : pin e v (otherWorld e) = otherVerdict v := by
  simp only [pin]
  rw [if_neg (otherWorld_ne e)]

theorem flat_at (e : Evidence) (v : Verdict) : flat v e = v := rfl

theorem flat_vacuous (v : Verdict) : Vacuous (flat v) := fun _ _ => rfl

theorem pin_not_vacuous (e : Evidence) (v : Verdict) : ¬ Vacuous (pin e v) := by
  intro hv
  have h := hv e (otherWorld e)
  rw [pin_at, pin_off] at h
  exact otherVerdict_ne v h.symm

/-- THE LOWER BOUND. Whatever world a control plants and whatever verdict comes
back, that single observation is consistent with a vacuous gate and with a
non-vacuous one. One control never narrows the question, for any choice of
world -- so "I broke it and it went red" is not weak evidence, it is evidence
that does not bear on vacuity at all. -/
theorem one_observation_is_never_enough (e : Evidence) (v : Verdict) :
    ∃ g₁ g₂ : Gate, g₁ e = v ∧ g₂ e = v ∧ Vacuous g₁ ∧ ¬ Vacuous g₂ :=
  ⟨flat v, pin e v, flat_at e v, pin_at e v, flat_vacuous v, pin_not_vacuous e v⟩

/-- THE UPPER BOUND. The two endpoint observations decide vacuity outright. -/
theorem two_observations_are_always_enough (g : Gate) :
    Vacuous g ↔ g present = g absent := by
  constructor
  · intro hv
    exact hv present absent
  · intro h e₁ e₂
    cases e₁ <;> cases e₂ <;> simp [h]

/-- Sharper: two observations pin the gate itself, not merely its vacuity. Two
is tight -- one is never enough, two is always enough, and there is nothing
left for a third to learn. -/
theorem observations_determine_the_gate (g₁ g₂ : Gate)
    (hp : g₁ present = g₂ present) (ha : g₁ absent = g₂ absent) : g₁ = g₂ := by
  funext e
  cases e
  · exact hp
  · exact ha

/-- The minimal sufficient experiment, named: trip the control, then confirm the
clean tree. Together they are exactly `Informative`, and `Informative` is
exactly what one observation could not establish. -/
theorem both_observations_give_informative (g : Gate)
    (hred : g absent = red) (hgreen : g present = green) : Informative g :=
  ⟨hred, hgreen⟩

/-- A gate that answers red in every world makes the whole remaining suite
vacuous. The suite stops at the first red, so nothing behind it is ever
observed, and an unobserved check contributes nothing regardless of quality. -/
theorem a_red_prefix_blinds_everything_after_it
    (g : Gate) (hred : ∀ e : Evidence, g e = red) (rest : Suite) :
    Vacuous (run (g :: rest)) := by
  intro e₁ e₂
  show (if g e₁ = red then red else run rest e₁)
     = (if g e₂ = red then red else run rest e₂)
  rw [if_pos (hred e₁), if_pos (hred e₂)]

/-- The same fact at minimum size, with a provably informative victim: `honest`
is not vacuous, and putting it behind `alwaysRed` makes the pair vacuous. The
good gate was not weakened -- it was never reached. -/
theorem alwaysRed_blinds_an_informative_suffix :
    ¬ Vacuous honest ∧ Vacuous (run [alwaysRed, honest]) :=
  ⟨one_honest_gate_is_not_vacuous,
   a_red_prefix_blinds_everything_after_it alwaysRed (fun _ => rfl) [honest]⟩

/-- The contrapositive, which is the operationally useful direction: if a suite
is worth anything, no member answers red everywhere. Finding one always-red gate
is therefore not a local defect report -- it invalidates the suite's verdict. -/
theorem a_meaningful_suite_has_no_red_prefix
    (g : Gate) (rest : Suite) (h : ¬ Vacuous (run (g :: rest))) :
    ¬ (∀ e : Evidence, g e = red) := by
  intro hred
  exact h (a_red_prefix_blinds_everything_after_it g hred rest)

/-- And the reason the two halves belong in one module: destruction dominates.
A suite can contain a non-vacuous gate and still be vacuous, so "at least one of
our checks is real" is not a property of the suite. -/
theorem containing_an_informative_gate_does_not_save_a_suite :
    ∃ (g : Gate) (rest : Suite), ¬ Vacuous g ∧ Vacuous (run (alwaysRed :: rest)) ∧ g ∈ rest :=
  ⟨honest, [honest], one_honest_gate_is_not_vacuous,
   a_red_prefix_blinds_everything_after_it alwaysRed (fun _ => rfl) [honest],
   List.mem_singleton_self honest⟩

end RotMoE.Observation
