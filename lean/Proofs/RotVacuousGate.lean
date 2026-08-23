/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# What a green gate is worth, and when the answer is nothing

`docs/COMPENDIUM-instrument-defects.md` catalogues twenty-five audit findings on
this branch as eight families, and argues they collapse into one question:

> What would this instrument do if the thing it checks were absent?

The compendium answers it in prose -- in all eight families, green. Prose is
where this repository keeps finding its defects (Family 4: a bound written as
prose is an assertion with no assertor), so the claim is stated here instead,
about the two predicates rather than about any one gate.

The model is deliberately the smallest one that can carry the argument. A gate
sees the world in one of two states -- the evidence it exists to check is
`present`, or it is `absent` -- and returns `green` or `red`. Nothing about
files, exit codes or shells is needed: the entire content of "a false green" is
a function that ignores its argument.

Four predicates.

* `Vacuous g` -- the verdict does not depend on the evidence at all.
* `Sound g` -- absent evidence yields red. This is "make it fail on purpose".
* `Live g` -- present evidence yields green. This is "and it still passes".
* `Informative g` -- both. This is what a gate must actually be.

The results worth having:

`informative_not_vacuous` is the easy direction and the one everybody assumes.
`distinguishes_iff_not_vacuous` says non-vacuity is exactly the ability to tell
the two worlds apart, so "can this alarm fire?" and "does this alarm mean
anything?" are the same question, not two.

`sound_does_not_imply_live` is the one that costs people a day. A gate that
answers red to everything is perfectly sound -- it fails on absent evidence, as
demanded -- and it is still vacuous, because it fails on present evidence too.
Breaking a check to watch it go red proves only half of what it looks like it
proves. This repository already pays for the other half at runtime: see the
control `a TRUE mutant count is accepted -- the check does not simply reject
everything` in `checker/repo-complete.sh`. That control is this theorem.

`suite_of_vacuous_is_vacuous` is the thesis. Gates compose the way a real suite
composes -- run them in order, first red wins, empty suite is green -- and the
theorem says composition creates nothing. A suite built entirely from vacuous
gates is itself vacuous, for any length.

`green_gates_prove_nothing` is that stated the way it is actually encountered:
if every gate is vacuous and the suite is green on the evidence you have, then
it is green on no evidence whatsoever. The verdict was never about the tree. A
line reading ALL 47 GATES GREEN is, under that hypothesis, a fact about the
suite and not about the repository -- which is precisely why every gate on this
branch is required to carry a control that has been tripped on purpose.

Nothing here is a claim about how many gates in this repository are vacuous.
The measured answer today is zero, and that is measured, not proved. The theorem
is about what would follow if it were not.
-/

namespace RotMoE.Vacuity

/-- The world, as far as one gate is concerned: the thing it checks is either
there or it is not. -/
inductive Evidence where
  | present : Evidence
  | absent : Evidence
  deriving DecidableEq, Repr

/-- What a gate can say. -/
inductive Verdict where
  | green : Verdict
  | red : Verdict
  deriving DecidableEq, Repr

open Evidence Verdict

/-- A gate is exactly a verdict for each state of the world. Every detail a real
checker has -- files, exit codes, logs -- is irrelevant to the argument. -/
abbrev Gate := Evidence → Verdict

/-- The verdict is independent of the evidence. -/
def Vacuous (g : Gate) : Prop := ∀ e₁ e₂ : Evidence, g e₁ = g e₂

/-- Absent evidence is rejected. "Break it and watch it go red." -/
def Sound (g : Gate) : Prop := g absent = red

/-- Present evidence is accepted. "And it still passes when nothing is wrong." -/
def Live (g : Gate) : Prop := g present = green

/-- What a gate has to be: it accepts the true world and rejects the empty one. -/
def Informative (g : Gate) : Prop := Sound g ∧ Live g

/-- The gate can tell the two worlds apart. -/
def Distinguishes (g : Gate) : Prop := g present ≠ g absent

/-- The pure false green: green whatever happens. -/
def alwaysGreen : Gate := fun _ => green

/-- The other useless gate, and the one that disguises itself as rigour. -/
def alwaysRed : Gate := fun _ => red

/-- A gate that actually checks something. -/
def honest : Gate
  | present => green
  | absent => red

theorem alwaysGreen_vacuous : Vacuous alwaysGreen := fun _ _ => rfl

theorem alwaysGreen_live : Live alwaysGreen := rfl

theorem alwaysGreen_not_sound : ¬ Sound alwaysGreen := by
  intro h
  exact Verdict.noConfusion h

theorem alwaysRed_vacuous : Vacuous alwaysRed := fun _ _ => rfl

theorem alwaysRed_sound : Sound alwaysRed := rfl

theorem alwaysRed_not_live : ¬ Live alwaysRed := by
  intro h
  exact Verdict.noConfusion h

theorem honest_informative : Informative honest := ⟨rfl, rfl⟩

/-- An informative gate is not vacuous. The direction everyone assumes, and the
only one that is free. -/
theorem informative_not_vacuous (g : Gate) (h : Informative g) : ¬ Vacuous g := by
  intro hv
  have hb := hv present absent
  rw [h.2, h.1] at hb
  exact Verdict.noConfusion hb

/-- Soundness alone buys nothing: `alwaysRed` fails on absent evidence exactly as
demanded, and is still vacuous. Tripping a control proves half of what it looks
like it proves; the other half is `Live`. -/
theorem sound_does_not_imply_live : ∃ g : Gate, Sound g ∧ ¬ Live g ∧ Vacuous g :=
  ⟨alwaysRed, alwaysRed_sound, alwaysRed_not_live, alwaysRed_vacuous⟩

/-- Nor does liveness alone: `alwaysGreen` passes on present evidence exactly as
demanded, and is still vacuous. The two halves are independent. -/
theorem live_does_not_imply_sound : ∃ g : Gate, Live g ∧ ¬ Sound g ∧ Vacuous g :=
  ⟨alwaysGreen, alwaysGreen_live, alwaysGreen_not_sound, alwaysGreen_vacuous⟩

/-- Non-vacuity IS the ability to distinguish the two worlds. "Can this alarm
fire?" and "does this alarm mean anything?" are one question. -/
theorem distinguishes_iff_not_vacuous (g : Gate) : Distinguishes g ↔ ¬ Vacuous g := by
  constructor
  · intro hd hv
    exact hd (hv present absent)
  · intro hnv heq
    exact hnv (fun e₁ e₂ => by cases e₁ <;> cases e₂ <;> simp [heq])

/-- A suite is an ordered list of gates. -/
abbrev Suite := List Gate

/-- Running a suite the way a real one runs: in order, first red wins, and an
empty suite is green. -/
def run : Suite → Evidence → Verdict
  | [], _ => green
  | g :: rest, e => if g e = red then red else run rest e

theorem run_nil (e : Evidence) : run [] e = green := rfl

/-- THE THESIS. Composition creates no information. A suite assembled entirely
from vacuous gates is itself vacuous, at any length -- there is no number of
meaningless checks that becomes a meaningful one. -/
theorem suite_of_vacuous_is_vacuous :
    ∀ s : Suite, (∀ g ∈ s, Vacuous g) → Vacuous (run s) := by
  intro s
  induction s with
  | nil => intro _ _ _; rfl
  | cons g rest ih =>
    intro h e₁ e₂
    have hg : Vacuous g := h g (by simp)
    have hr : ∀ g' ∈ rest, Vacuous g' := fun g' hg' => h g' (by simp [hg'])
    show (if g e₁ = red then red else run rest e₁)
       = (if g e₂ = red then red else run rest e₂)
    rw [hg e₁ e₂]
    by_cases hc : g e₂ = red
    · rw [if_pos hc, if_pos hc]
    · rw [if_neg hc, if_neg hc]
      exact ih hr e₁ e₂

/-- The thesis as it is actually met. If every gate is vacuous, then a green
suite on the evidence you have is green on no evidence at all: the verdict was
never about the tree. This is what a banner reading ALL GATES GREEN is worth
when its gates have never been tripped on purpose. -/
theorem green_gates_prove_nothing
    (s : Suite) (h : ∀ g ∈ s, Vacuous g) (hg : run s present = green) :
    run s absent = green := by
  rw [suite_of_vacuous_is_vacuous s h absent present]
  exact hg

/-- The escape, and the only one: a single gate that distinguishes the two worlds
is not vacuous, so it cannot be one of the gates the theorem above quantifies
over. One tripped control is the difference between a suite that means something
and a suite that means nothing. -/
theorem one_honest_gate_is_not_vacuous : ¬ Vacuous honest :=
  informative_not_vacuous honest honest_informative

/-- The whole model in one line: a vacuous gate is a constant function, and a
constant function has no argument. -/
theorem vacuous_iff_constant (g : Gate) :
    Vacuous g ↔ ∃ v : Verdict, ∀ e : Evidence, g e = v := by
  constructor
  · intro hv
    exact ⟨g present, fun e => hv e present⟩
  · intro ⟨v, hvv⟩ e₁ e₂
    rw [hvv e₁, hvv e₂]

end RotMoE.Vacuity
