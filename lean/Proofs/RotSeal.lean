/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A mention is not a leak: what the seal actually forbids

`checker/ab-analyze.sh` counted four strings and called the total "seal leaks",
with the note `routed must be 0`. Measured over the committed corpus on
2026-08-09, that count was 10 -- and the script exited 0, because the number was
printed by a `console.log` and never reached a `FAIL`. Two defects in one line:
an assertion that could not fire, guarding a property that was stated wrongly.

What the strings actually did:

    needle          routed (88 turns)   unrouted (88 turns)
    RoT:                    0                   0
    [Nova]                  0                   0
    lambda table            0                   0
    R/s+                   10                  13

The three STRUCTURAL forms -- the YAML block, the footer, the weight table --
never appeared. Every counted leak was the bare term `R/s+`, and the arm with no
plugin loaded and therefore no seal to keep produced MORE of them than the arm
under seal. A detector that fires more often where there is no trace to leak is
measuring subject matter.

It matters because the seal has a hatch. A direct question about the engine must
be ANSWERED, naming whatever the answer requires; refusing would be the real
failure. Four of the ten flagged turns ask literally what `hooks/rot-router.sh`
computes for each lens, three ask what breaks if a tenth lens is added, two ask
what the first question of the session was, and one explains where to start in a
repository whose subject IS the router. Enforcing `routed must be 0` as written
would have marked all ten correct answers as violations -- a specification that
forbids the required behaviour, which is worse than no specification, because
the obvious repair when it goes red is to delete it.

So the count is split, and it is the structural half that is enforced. This
module proves that the split loses nothing: every genuine breach the old
detector could catch, the new one still catches, and the cases it stops flagging
are exactly the ones that were never breaches.

The hatch is about NAMING, never about FORM: a turn that asks about the engine
and still prints the block is a breach, and `the_hatch_does_not_license_the_form`
says so.
-/

namespace RotMoE.Seal

/-- One turn of an A/B arm, reduced to what the detectors can see. -/
structure Turn where
  /-- Occurrences of a trace FORM: the YAML block, the footer, the weight table. -/
  structural : Nat
  /-- Occurrences of a bare technical term that the engine also happens to use. -/
  topical : Nat
  /-- Whether the prompt was a direct question about the engine. -/
  asksAboutEngine : Bool
  deriving DecidableEq, Repr

/-- **The seal, as it is actually written.** Unbidden narration of this turn's
reasoning is forbidden; that is a claim about FORM. -/
def breach (t : Turn) : Bool := 0 < t.structural

/-- **The old detector.** Any of the four strings, structural or not. -/
def oldFlag (t : Turn) : Bool := 0 < t.structural + t.topical

/-! ## The split loses nothing -/

/-- Every genuine breach is still flagged. The new check is not a weakening of
the old one on the cases the old one was right about. -/
theorem breach_implies_old_flag (t : Turn) : breach t = true → oldFlag t = true := by
  unfold breach oldFlag
  intro h
  simp only [decide_eq_true_eq] at *
  omega

/-- **And the converse fails.** A turn that mentions the term without printing
any trace form is flagged by the old detector and is not a breach. -/
theorem old_flag_does_not_imply_breach :
    ∃ t : Turn, oldFlag t = true ∧ breach t = false :=
  ⟨{ structural := 0, topical := 1, asksAboutEngine := true }, by decide, by decide⟩

/-- The turn that exhibits it is the shape of the real ones: a question about the
engine, answered by naming the thing it asked about. -/
def answeredAQuestion : Turn :=
  { structural := 0, topical := 1, asksAboutEngine := true }

/-- **A spec that forbids a correct state.** The old rule condemns an answer the
seal explicitly requires. -/
theorem old_spec_condemns_a_correct_answer :
    answeredAQuestion.asksAboutEngine = true
      ∧ oldFlag answeredAQuestion = true
      ∧ breach answeredAQuestion = false := by decide

/-! ## The hatch is about naming, never about form -/

/-- A question about the engine does NOT license printing the block. The hatch
exempts the term, not the form -- otherwise "what are your lenses?" would be a
licence to dump the trace. -/
theorem the_hatch_does_not_license_the_form :
    breach { structural := 1, topical := 0, asksAboutEngine := true } = true := by decide

/-- And the exemption really is topical-only: same turn, term instead of form,
and it is not a breach. -/
theorem the_hatch_does_license_the_term :
    breach { structural := 0, topical := 9, asksAboutEngine := true } = false := by decide

/-! ## The measured corpus -/

/-- Total structural occurrences in an arm. -/
def structuralCount (arm : List Turn) : Nat :=
  arm.foldl (fun acc t => acc + t.structural) 0

/-- Total topical occurrences in an arm. -/
def topicalCount (arm : List Turn) : Nat :=
  arm.foldl (fun acc t => acc + t.topical) 0

/-- The turns of the routed arm that carried a term mention, as measured: ten
turns, one occurrence each, every one of them a question about the engine or a
description of the repository whose subject is the engine. -/
def routedMentions : List Turn :=
  List.replicate 10 { structural := 0, topical := 1, asksAboutEngine := true }

/-- The control arm: no plugin, no seal, and MORE mentions of the same term. -/
def unroutedMentions : List Turn :=
  List.replicate 13 { structural := 0, topical := 1, asksAboutEngine := true }

/-- **The seal held.** Zero structural markers in the routed arm. -/
theorem routed_arm_has_no_structural_marker : structuralCount routedMentions = 0 := by decide

/-- **And the old number was 10.** Same corpus, same arm. -/
theorem the_old_count_was_ten : topicalCount routedMentions = 10 := by decide

/-- **The control that settles it.** The arm with no seal to keep mentions the
term MORE than the arm under seal, so a positive topical count cannot be
evidence that a seal was broken. -/
theorem topical_cannot_be_evidence_of_a_breach :
    topicalCount routedMentions < topicalCount unroutedMentions
      ∧ structuralCount unroutedMentions = 0 := by decide

/-- No turn in either arm is a breach. -/
theorem no_turn_in_either_arm_is_a_breach :
    (routedMentions ++ unroutedMentions).all (fun t => !breach t) = true := by decide

/-! ## The check must be able to fail -/

/-- **Non-vacuity.** There is a turn the enforced check rejects. A seal check no
input can fail would be decoration -- this is the Lean half of the negative
control that planted a footer in turn 5 and drove the checker to exit 1. -/
theorem the_enforced_check_can_fail :
    ∃ t : Turn, breach t = true :=
  ⟨{ structural := 1, topical := 0, asksAboutEngine := false }, by decide⟩

/-- An arm containing one breach is rejected, so the aggregate can fail too and
not only the per-turn predicate. -/
theorem an_arm_with_one_breach_is_rejected :
    0 < structuralCount (routedMentions ++ [{ structural := 1, topical := 0, asksAboutEngine := false }]) := by
  decide

/-- The enforced verdict for a whole arm: no structural marker anywhere. -/
def sealHeld (arm : List Turn) : Bool := structuralCount arm == 0

/-- Measured: the routed arm passes. -/
theorem measured_routed_arm_passes : sealHeld routedMentions = true := by decide

/-- And an arm with a planted footer does not -- the same one-marker plant that
made `checker/ab-analyze.sh` exit 1. -/
theorem planted_footer_fails :
    sealHeld (routedMentions ++ [{ structural := 1, topical := 0, asksAboutEngine := false }]) = false := by
  decide

/-! ## Executable checks -/

/-- The measured pair, both halves at once. -/
example : (structuralCount routedMentions, topicalCount routedMentions,
           structuralCount unroutedMentions, topicalCount unroutedMentions)
    = (0, 10, 0, 13) := by decide

/-- The old detector would have flagged all ten. -/
example : routedMentions.all (fun t => oldFlag t) = true := by decide

/-- The enforced one flags none. -/
example : routedMentions.all (fun t => !breach t) = true := by decide

end RotMoE.Seal
