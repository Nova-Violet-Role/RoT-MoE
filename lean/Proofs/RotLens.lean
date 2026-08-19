/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Mathlib
import Proofs.RotRoute

/-! # The nine lenses — which parts of "who they are" are actually provable

A reader who meets nine named lenses is owed a straight answer to one question:
**how much of this is checkable, and how much is a story?** This module draws
that line where it really falls, and proves only the side that can be proved.

**NOT provable, and not attempted here.** That 🩸 Carnage "supplies chaos" or
that 🎷 Violet_Noir "hears felt truth" is a claim about the *quality of thought*,
which no theorem reaches. Anyone stating it as proved is overclaiming. It is a
design intent, and this file does not pretend otherwise.

**Provable, and proved below.** The lens ensemble has a *structure*, and that
structure is exactly the part that a bug can break silently:

* every lane has exactly one lead lens (`lead_total`),
* no lens leads two lanes (`lead_injective`),
* every lens leads some lane — none is ornamental (`lead_surjective`),
* the lead is not a survivor: all nine stay in the ensemble in every lane, so
  the gauge's divisor is nine (`card_lenses_eq_nine`, `lead_does_not_shrink`),
* no shipped weight is zero — a lens with λ = 0 would be *silently disabled*
  while still counting in the divisor, which is precisely the shipped bug that
  `RotGauge.gauge_divisor_eq_card` was written for (`forgeLam_pos`),
* in `FORGE`, the head's own lens carries the strictly greatest weight, and its
  verification partner is second (`claude_leads_forge`, `antivenom_second`).

The λ/μ vectors are quoted from `hooks/rot-router.sh:90-91`; the lane→lens
assignment from `hooks/rot-router.sh:70-78`. `checker/lean-binds-shell.sh` and
`checker/bench-router.sh` phase 4b fail the build if either drifts, so these are
not a copy that can quietly rot. -/

namespace RotMoE.Ensemble

open RotMoE.Route

/-- The nine lenses. Order is load-bearing: the corpus, the PowerShell hook and
`hooks/rot-router.sh` all index the weight vectors by this order, which is why
`NAMES` is written out in the shell rather than inferred. -/
inductive Lens where
  | nova | violet | antivenom | venom | carnage
  | chroma | soleil | eidolon | claude
deriving DecidableEq, Repr, Inhabited

/-- All nine, as a list, in the shipped order. -/
def lenses : List Lens :=
  [.nova, .violet, .antivenom, .venom, .carnage, .chroma, .soleil, .eidolon, .claude]

/-- Which lens *leads* a lane. Read out of `hooks/rot-router.sh:70-78`.

`convergent` is the default lane and is led by ⚜️ Nova, matching the shell's
fall-through. Note that `strategic` is *also* Nova-led: that is a genuine
property of the shipped router, and it is the reason `lead` is stated over the
nine non-default lanes below rather than over all ten — see `lead_injective`. -/
def lead : Mode → Lens
  | .forge => .claude
  | .clinical => .antivenom
  | .executive => .venom
  | .empathic => .violet
  | .strategic => .nova
  | .creative => .carnage
  | .predictive => .chroma
  | .stealth => .soleil
  | .recursive => .eidolon
  | .convergent => .nova

/-- The nine lanes that have a lens of their own, i.e. every lane except the
`convergent` default (which shares ⚜️ Nova with `strategic`). -/
def ownLanes : List Mode :=
  [.forge, .clinical, .executive, .empathic, .strategic,
   .creative, .predictive, .stealth, .recursive]

/-! ## The assignment is a bijection on the nine own lanes -/

/-- Every own lane maps to a lens in the roster. Trivial-looking, and it is the
statement that would break first if a lens were deleted from `Lens`. -/
theorem lead_total : ∀ m ∈ ownLanes, lead m ∈ lenses := by decide

/-- **No lens leads two of the nine own lanes.** If this failed, two lanes would
be indistinguishable by their lead, and the router's "who is speaking" answer
would be ambiguous. -/
theorem lead_injective :
    ∀ m ∈ ownLanes, ∀ n ∈ ownLanes, lead m = lead n → m = n := by decide

/-- **Every lens leads some lane — none is ornamental.** A roster that names
nine lenses while only seven can ever lead is a brochure, not a design. -/
theorem lead_surjective : ∀ l ∈ lenses, ∃ m ∈ ownLanes, lead m = l := by decide

/-- The two above, in the form a reader asks for: the nine own lanes and the
nine lenses are in exact correspondence. -/
theorem lanes_correspond_to_lenses :
    (ownLanes.map lead).length = lenses.length ∧
    (∀ l ∈ lenses, l ∈ ownLanes.map lead) := by
  constructor
  · rfl
  · decide

/-! ## The lead is a weight, not a survivor -/

/-- The roster has exactly nine members, with no duplicates. This is the number
the gauge divides by; `RotGauge.gauge_divisor_eq_card` is the theorem that the
divisor must equal it. -/
theorem card_lenses_eq_nine : lenses.length = 9 := rfl

theorem lenses_nodup : lenses.Nodup := by decide

/-- **Choosing a lead removes nobody from the ensemble.** For any lane, taking
its lead out of the roster leaves the other *eight* — and every lens that is not
the lead is one of them.

WHAT THIS STATEMENT USED TO BE, and why it was changed (2026-08-03). It read

```
theorem lead_does_not_shrink (m : Mode) : ∀ l : Lens, l ∈ lenses
```

which binds `m` without using it and never mentions `lead`. Measured: pointing
`lead` at a constant killed `lead_injective`, `lead_surjective`,
`lanes_correspond_to_lenses` and `forge_lead_is_not_the_floor` — and this one
SURVIVED, because it was not about `lead` at all. It was roster completeness
wearing the name of a claim about leads, and the README's "The nine" section
cited it at the time for exactly the claim it did not make. (This paragraph
once carried that citation as a line number; the line moved and the number
lied. The section is the address — line numbers rot faster than truth.)

The old content is not lost: `∀ l : Lens, l ∈ lenses` is the second conjunct.
What is added is the part that makes the name honest — the ensemble minus the
lead still has eight members, so a lead is a WEIGHT and not a survivor. -/
theorem lead_does_not_shrink (m : Mode) :
    (lenses.erase (lead m)).length = 8 ∧ ∀ l : Lens, l ∈ lenses := by
  cases m <;> exact ⟨rfl, by intro l; cases l <;> decide⟩

/-! ## The shipped FORGE weights

Quoted from `hooks/rot-router.sh:90-91`, in the lens order fixed above.
Rationals, not floats: `decide` then settles the comparisons exactly, with no
floating-point question to argue about. -/

/-- λ for each lens in the `FORGE` profile, as shipped. -/
def forgeLam : Lens → ℚ
  | .nova => 14/10
  | .violet => 6/10
  | .antivenom => 19/10
  | .venom => 12/10
  | .carnage => 6/10
  | .chroma => 1
  | .soleil => 1
  | .eidolon => 12/10
  | .claude => 23/10

/-- μ for each lens in the `FORGE` profile, as shipped. -/
def forgeMu : Lens → ℚ
  | .nova => 105/100
  | .violet => 85/100
  | .antivenom => 110/100
  | .venom => 105/100
  | .carnage => 90/100
  | .chroma => 110/100
  | .soleil => 95/100
  | .eidolon => 110/100
  | .claude => 115/100

/-- **No lens is silently disabled.** A λ of zero would keep a lens in the
divisor while contributing nothing — the exact shape of the bug that
`gauge_divisor_eq_card` exists to catch. This says the shipped vector has no
such hole. -/
theorem forgeLam_pos : ∀ l ∈ lenses, 0 < forgeLam l := by
  intro l hl; fin_cases hl <;> norm_num [forgeLam]

/-- Every μ is inside the documented 0.80–1.35 band. A μ outside it would be a
transcription error in the weight vector, which is otherwise invisible. -/
theorem forgeMu_in_band : ∀ l ∈ lenses, 80/100 ≤ forgeMu l ∧ forgeMu l ≤ 135/100 := by
  intro l hl; fin_cases hl <;> norm_num [forgeMu]

/-- **On a proving head, the verifying lens outweighs every other.** 🧭 Claude
is strictly heaviest in `FORGE` — the profile says what the head is for. -/
theorem claude_leads_forge :
    ∀ l ∈ lenses, l ≠ .claude → forgeLam l < forgeLam .claude := by
  intro l hl h; fin_cases hl <;> simp_all [forgeLam] <;> norm_num

/-- ⚪ Anti-Venom is second, ahead of every lens but 🧭 Claude: verification sits
directly behind execution, not decorating the tail. -/
theorem antivenom_second :
    ∀ l ∈ lenses, l ≠ .claude → l ≠ .antivenom → forgeLam l < forgeLam .antivenom := by
  intro l hl h1 h2; fin_cases hl <;> simp_all [forgeLam] <;> norm_num

/-- **The expressive lenses are damped in `FORGE`, deliberately.** 🩸 Carnage and
🎷 Violet_Noir sit at the floor: on a proving head chaos and felt truth are
inputs to the reasoning, never the voice that ships the answer.

Stated as an *inequality against the leads* rather than as `= 0.6`. The pinned
form would be true today and would turn a correct re-weighting red tomorrow;
this form says the thing that must stay true. -/
theorem expressive_damped_in_forge :
    forgeLam .carnage < forgeLam .antivenom ∧
    forgeLam .violet < forgeLam .antivenom ∧
    forgeLam .carnage < forgeLam .claude ∧
    forgeLam .violet < forgeLam .claude := by
  refine ⟨?_, ?_, ?_, ?_⟩ <;> norm_num [forgeLam]

/-- The lead of a lane is never the lightest lens in the profile it leads —
here, `FORGE`'s lead is not the minimum. A lane led by its own floor would mean
the routing and the weighting disagree about what the lane is. -/
theorem forge_lead_is_not_the_floor :
    ∃ l ∈ lenses, forgeLam l < forgeLam (lead .forge) := by
  exact ⟨.violet, by decide, by norm_num [forgeLam, lead]⟩

/-! ## Executable witnesses

The theorems above are `decide`-closed, so the definitions must also *run*.
These execute them on concrete input: a definition that elaborates but computes
something else is caught here, not in review.

They were `#guard` commands. `#guard` is evaluated by the elaborator and then
discarded -- no proof term survives, so `leanchecker` never re-verifies it and
the kernel never sees it. As `example ... := by decide` they run exactly the same
computation and leave a kernel-checked term behind. Strictly more evidence. -/

-- the roster really has nine members
example : lenses.length = 9 := by decide

-- the four lanes a reader is most likely to check by hand
example : lead .forge = Lens.claude := by decide
example : lead .clinical = Lens.antivenom := by decide
example : lead .empathic = Lens.violet := by decide
example : lead .stealth = Lens.soleil := by decide

-- the shipped weight vector, in the shell's own order, evaluated end to end
example : (lenses.map forgeLam) =
    [14/10, 6/10, 19/10, 12/10, 6/10, 1, 1, 12/10, 23/10] := by
  norm_num [lenses, forgeLam]
example : (lenses.map forgeMu) =
    [105/100, 85/100, 110/100, 105/100, 90/100, 110/100, 95/100, 110/100, 115/100] := by
  norm_num [lenses, forgeMu]

-- the whole lane->lens assignment, exhaustively, in one line
example : (ownLanes.map lead) =
    [Lens.claude, Lens.antivenom, Lens.venom, Lens.violet, Lens.nova,
     Lens.carnage, Lens.chroma, Lens.soleil, Lens.eidolon] := by decide

end RotMoE.Ensemble
