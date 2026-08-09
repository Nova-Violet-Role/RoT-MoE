/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A ceiling is not a null result

Third metric, measured 2026-08-09 on 84 paired prompts with mechanical ground
truth (`bench/fact-prompts.js`, `bench/fact-score.js`), tools enabled, silence
scored as WRONG:

    routed   84/84 correct      unrouted 84/84 correct
    discordant pairs: 0         p = 1.0
    mean answer length: 15 chars routed, 16 unrouted
    silent turns: 0 and 0

Both arms were perfect. The obvious sentence to write is "no difference between
the arms", and it would be **wrong**.

`p = 1.0` here carries NO information. The sign test operates on DISCORDANT
pairs -- turns where exactly one arm is right -- and there were zero. A test
with no discordant pairs cannot distinguish "the arms are equal" from "this
corpus is too easy to tell them apart". The instrument saturated.

That is a ceiling effect, and it is a defect of the CORPUS, not a finding about
the router. A metric only informs when baseline accuracy sits strictly between
floor and ceiling; at 100% for both arms, the only honest report is "no power".

This module makes the distinction machine-checked, because "p = 1, therefore
equal" is exactly the kind of sentence that survives review by sounding
rigorous.

## Status of the three metrics, all measured, none establishing the claim

| metric | outcome | why it does not settle the question |
|---|---|---|
| compliance | routed 29-4, p = 1.09e-5 | 27/29 wins explained by shorter answers |
| grounding  | routed 8-0, p = 0.0078   | 18/18 tie once claim volume is matched |
| facts      | 84-84, p = 1.0           | ceiling: zero discordant pairs, no power |
-/

namespace RotMoE.Ceiling

/-- A paired comparison, summarised by its discordant counts. -/
structure Comparison where
  routedOnly   : Nat
  unroutedOnly : Nat
  bothRight    : Nat
  bothWrong    : Nat
deriving DecidableEq, Repr

/-- The sign test sees ONLY the discordant pairs. -/
def discordant (c : Comparison) : Nat := c.routedOnly + c.unroutedOnly

/-- A comparison has power only if something disagreed. -/
def hasPower (c : Comparison) : Bool := 0 < discordant c

/-- Saturated: every pair was correct in both arms. -/
def atCeiling (c : Comparison) : Bool :=
  c.routedOnly == 0 && c.unroutedOnly == 0 && c.bothWrong == 0

/-- An advantage requires power AND a majority. Without power, neither. -/
def establishesAdvantage (c : Comparison) : Bool :=
  hasPower c && c.unroutedOnly < c.routedOnly

/-- What a comparison licenses: either an advantage, or a null, or NOTHING.
Three outcomes, not two -- collapsing the third into "null" is the error. -/
inductive Verdict where
  | advantage
  | null
  | noPower
deriving DecidableEq, Repr

def verdict (c : Comparison) : Verdict :=
  if !hasPower c then .noPower
  else if c.unroutedOnly < c.routedOnly then .advantage
  else .null

/-- The measured fact corpus. -/
def measured : Comparison := ⟨0, 0, 84, 0⟩

section TheMeasuredCeiling

theorem fact_corpus_is_at_ceiling : atCeiling measured = true := by decide

/-- THE point: the fact corpus establishes nothing, and specifically does NOT
establish a null. Its verdict is `noPower`. -/
theorem fact_corpus_has_no_power : verdict measured = Verdict.noPower := by decide

theorem fact_corpus_establishes_no_advantage :
    establishesAdvantage measured = false := by decide

/-- A ceiling is NOT a null, stated as an inequality between verdicts so the two
can never be conflated by a reader or by a later edit. -/
theorem ceiling_is_not_null : verdict measured ≠ Verdict.null := by decide

end TheMeasuredCeiling

section TheRuleIsNotVacuous

/-- Every arm of the verdict is reachable, so the classification carries
information rather than always returning the same answer. -/
theorem all_three_verdicts_reachable :
    verdict ⟨3, 1, 0, 0⟩ = Verdict.advantage ∧
    verdict ⟨1, 3, 0, 0⟩ = Verdict.null ∧
    verdict ⟨0, 0, 5, 5⟩ = Verdict.noPower := by decide

/-- No discordant pairs means no power, whatever the concordant counts -- a
million agreeing pairs still prove nothing about a difference. -/
theorem concordance_never_creates_power (r w : Nat) :
    hasPower ⟨0, 0, r, w⟩ = false := by
  simp [hasPower, discordant]

/-- Power alone is not an advantage: a losing arm has power too. -/
theorem power_without_majority_is_null :
    verdict ⟨1, 4, 0, 0⟩ = Verdict.null := by decide

/-- A TIE that HAS power is still a null.
This theorem exists because mutant C05 -- weakening `<` to `<=` in `verdict` --
SURVIVED the first mutation run. Nothing in the module covered a tie among
discordant pairs, so a 2-2 split could have been classified as a routed
advantage and no proof would have objected. The mutation found a real hole; the
hole is closed here rather than by retiring the mutant. -/
theorem tie_with_power_is_null :
    verdict ⟨2, 2, 0, 0⟩ = Verdict.null := by decide

/-- The same fact stated for every tie, not just the witness above, so the
guarantee does not depend on one lucky pair of numbers. -/
theorem every_tie_with_power_is_null (n : Nat) (h : 0 < n) :
    verdict ⟨n, n, 0, 0⟩ = Verdict.null := by
  have h1 : hasPower ⟨n, n, 0, 0⟩ = true := by
    unfold hasPower discordant; simp; omega
  unfold verdict
  rw [h1]
  simp [Nat.lt_irrefl]

/-- And an advantage always implies power -- the two cannot come apart. -/
theorem advantage_implies_power (c : Comparison)
    (h : establishesAdvantage c = true) : hasPower c = true := by
  simp [establishesAdvantage] at h
  exact h.1

end TheRuleIsNotVacuous

section Measured

#guard atCeiling measured = true
#guard verdict measured = Verdict.noPower
#guard verdict measured ≠ Verdict.null
#guard discordant measured = 0
#guard establishesAdvantage measured = false
#guard hasPower ⟨0, 0, 84, 0⟩ = false
#guard verdict ⟨3, 1, 0, 0⟩ = Verdict.advantage
#guard verdict ⟨1, 3, 0, 0⟩ = Verdict.null
#guard verdict ⟨2, 2, 0, 0⟩ = Verdict.null
#guard verdict ⟨0, 0, 0, 0⟩ = Verdict.noPower
-- the compliance and grounding corpora DID have power; only this one lacked it
#guard hasPower ⟨29, 4, 0, 0⟩ = true
#guard hasPower ⟨8, 0, 40, 0⟩ = true

end Measured

end RotMoE.Ceiling
