/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# The wiring verdict, and why a mention is not a wiring

`checker/workflow-lint.sh` answers one question about every checker in the tree:
does CI actually run it, or is the repository merely *claiming* to be verified?

Until 2026-08-19 it answered by asking whether the checker's basename occurred
anywhere in the comment-stripped workflow text. MEASURED that day: the string
`gate-all.sh` occurs at `.github/workflows/ci.yml:1329` inside a log message --

    3) echo "::notice::workflow-roles SKIPPED its API half (exit 3) -- not a
       pass, measured from gate-all.sh instead" ;;

-- and the gate printed `PASS  wired into a workflow: gate-all.sh` about the one
checker whose own exemption argues at length that CI must NOT run it. A sentence
blessed a checker. The exemption, and the reachability assertion guarding it,
were dead code nothing ever reached.

The file had already learned half of this in 2026-08-08 (a name inside a YAML
comment is not a wiring, so comments are stripped). It had not learned the
general form. This module states the general form, and it is not a claim about
one repository: it is a claim about the two predicates.

Two halves.

**The string half.** `Infix n h` is the mention relation. Requiring an invocation
prefix (`bash checker/` and friends) yields a strictly stronger predicate:
`an_invocation_is_always_a_mention` says tightening loses nothing, and
`a_mention_is_not_an_invocation` exhibits a haystack that mentions without
invoking. Strict containment is the whole content of the fix -- the extra
acceptances of the loose rule are exactly the false greens.

`a_name_inherits_another_name_wiring` is the second, latent defect: under a
bare-basename test, any checker whose name sits inside another checker's name
rides that one's wiring for free. MEASURED 2026-08-19: 0 such collisions among
the 82 checkers, so nothing was wrong that day -- but the rule *depended* on
that luck, and no contributor was told to preserve it.
`the_prefix_blocks_the_inheritance` shows the prefixed rule does not.

**The verdict half.** The exemption table carried prose reasons, and prose cannot
be tested. Eight of the ten reasons say the checker does not run in CI; two say
it runs in CI as a step. One field, two questions. So `Kind` states the
classification as a fact, and `verdict` is the total function from the two facts
to one of six outcomes.

`verdict_states_are_distinct` pins the table: no two inputs may collapse onto one
outcome. `contradiction_iff` characterises exactly when the two sources disagree.

And `a_missing_kind_hides_a_contradiction` is the reason the two-table sync check
exists at all: `Kind.unexempt` -- what a checker gets when its name is dropped
from the kind table but keeps its reason -- can never produce a contradiction
verdict. Losing the classification does not raise an alarm, it *silences* one.
Paired with `the_hidden_contradiction_was_real`, that is a proof that the missing
entry destroys information rather than merely lacking it.

MUTATION (2026-08-19), each mutant rebuilt from a deleted olean, each restored
byte-identical afterwards:

  M1  `verdict true notInCi` returns `okWired` -- the shipped false green, in the
      model -> KILLED 4: verdict_states_are_distinct, contradiction_iff,
      the_hidden_contradiction_was_real, the_measured_tree. Left alive, correctly:
      a_missing_kind_hides_a_contradiction, which governs a different row.

  M2  `invokePrefix` emptied -- the old substring rule, exactly -> KILLED 1:
      the_prose_does_not_invoke_it. With no prefix to demand, prose IS invocation
      and the witness evaporates. That single death is the defect restated.

  M3  `verdict false unexempt` returns a contradiction -> KILLED 3:
      verdict_states_are_distinct, contradiction_iff,
      a_missing_kind_hides_a_contradiction.

A note on the two theorems that report no axioms at all: both are `decide` over a
finite enumeration, so they are computation rather than vacuity -- and M1 and M3
kill them, which is the evidence that they are load-bearing. An axiom-free
theorem nothing can kill would be the vacuous kind.
-/

namespace RotMoE.Wiring

/-! ## The string half: mention versus invocation -/

/-- `Infix n h` -- the needle occurs somewhere inside the haystack. This is the
relation the old rule tested, and the only thing a substring search can see. -/
def Infix (n h : List Char) : Prop := ∃ p s, h = p ++ n ++ s

theorem infix_refl (n : List Char) : Infix n n :=
  ⟨[], [], by simp⟩

/-- A mention cannot be longer than the text mentioning it. This is the whole
engine behind every negative witness below: proving that something is *not* an
infix is otherwise real work, and a length bound settles it in one step. -/
theorem length_le_of_infix {n h : List Char} : Infix n h → n.length ≤ h.length := by
  intro hi
  cases hi with
  | intro p hp =>
    cases hp with
    | intro s hEq =>
      subst hEq
      simp only [List.length_append]
      omega

/-- Infix is transitive. Stated on its own because the collision hazard below is
exactly this lemma read as a warning rather than as a convenience. -/
theorem Infix.trans {a b c : List Char} : Infix a b → Infix b c → Infix a c := by
  intro hab hbc
  cases hab with
  | intro p1 hp1 => cases hp1 with
    | intro s1 h1 => cases hbc with
      | intro p2 hp2 => cases hp2 with
        | intro s2 h2 =>
          refine ⟨p2 ++ p1, s1 ++ s2, ?_⟩
          subst h1; subst h2
          simp [List.append_assoc]

/-- **Tightening loses nothing.** Every invocation is also a mention, whatever
prefix the invocation requires. So moving from "the name appears" to "the file is
invoked" can never drop a checker that CI genuinely runs -- the direction that
would have this gate invent failures and get itself switched off.

MEASURED the same day: 74 of the 75 loosely-accepted checkers survived the
tightening. The one that did not is the defect. -/
theorem an_invocation_is_always_a_mention (pre b t : List Char) :
    Infix (pre ++ b) t → Infix b t := by
  intro h
  cases h with
  | intro p hp => cases hp with
    | intro s hEq =>
      refine ⟨p ++ pre, s, ?_⟩
      subst hEq
      simp [List.append_assoc]

/-- The measured witness, shortened to its bones: a haystack that MENTIONS the
checker and never invokes it. `ci.yml:1329` is this sentence with more words. -/
def proseHay : List Char := "see gate-all.sh".toList
def bareName : List Char := "gate-all.sh".toList
def invokePrefix : List Char := "bash checker/".toList

theorem the_prose_mentions_it : Infix bareName proseHay :=
  ⟨"see ".toList, [], by decide⟩

theorem the_prose_does_not_invoke_it : ¬ Infix (invokePrefix ++ bareName) proseHay := by
  intro h
  exact absurd (length_le_of_infix h) (by decide)

/-- **The defect, stated as a strict containment.** There is text the loose rule
accepts and the tight rule rejects. Every such text is a checker blessed by prose
-- a green tick standing for work nobody runs. -/
theorem a_mention_is_not_an_invocation :
    ∃ hay b pre, Infix b hay ∧ ¬ Infix (pre ++ b) hay :=
  ⟨proseHay, bareName, invokePrefix, the_prose_mentions_it, the_prose_does_not_invoke_it⟩

/-! ### The latent second defect: name collision -/

/-- **A bare name inherits another name's wiring.** If one checker's basename sits
inside another's, and the second is wired, the substring rule reports the first as
wired too -- on evidence that belongs entirely to the second file.

This is `Infix.trans` with the names of real things substituted in, which is
precisely why it is dangerous: nothing is broken, the rule is simply answering a
question about the wrong file. -/
theorem a_name_inherits_another_name_wiring (b1 b2 t : List Char) :
    Infix b1 b2 → Infix b2 t → Infix b1 t :=
  fun h1 h2 => Infix.trans h1 h2

def collisionOuter : List Char := "ab.sh".toList
def collisionInner : List Char := "b.sh".toList
def collisionText : List Char := "sh checker/ab.sh".toList

theorem the_inner_name_hides_in_the_outer : Infix collisionInner collisionOuter :=
  ⟨"a".toList, [], by decide⟩

theorem the_outer_name_is_wired : Infix collisionOuter collisionText :=
  ⟨"sh checker/".toList, [], by decide⟩

/-- The free ride, instantiated: the inner name reads as wired although the text
never names it on its own account. -/
theorem the_inner_name_rides_for_free : Infix collisionInner collisionText :=
  a_name_inherits_another_name_wiring _ _ _ the_inner_name_hides_in_the_outer
    the_outer_name_is_wired

/-- **And the prefix blocks it.** Demanding `sh checker/<name>` refuses the
inherited wiring: the inner name has no invocation of its own anywhere in the
text. The rule no longer depends on the measured fact that today's 82 basenames
happen not to collide. -/
theorem the_prefix_blocks_the_inheritance :
    ¬ Infix ("bash checker/".toList ++ collisionInner) collisionText := by
  intro h
  exact absurd (length_le_of_infix h) (by decide)

/-! ## The verdict half: two facts, six outcomes -/

/-- What an exemption actually claims. Eight entries say `notInCi`, two say
`ciStep`. Before this was a fact it was a sentence, and a sentence cannot be
checked. -/
inductive Kind where
  | unexempt
  | ciStep
  | notInCi
deriving DecidableEq, Repr

inductive Verdict where
  | okWired
  | okDocumentedCiStep
  | okExempt
  | contradictionInvokedButExempt
  | contradictionClaimsCiStepButAbsent
  | notRunAnywhere
deriving DecidableEq, Repr

/-- The shipped dispatch, transcribed. Total by construction: there is no input
for which the gate has nothing to say. -/
def verdict : Bool → Kind → Verdict
  | true,  Kind.unexempt => Verdict.okWired
  | true,  Kind.ciStep   => Verdict.okDocumentedCiStep
  | true,  Kind.notInCi  => Verdict.contradictionInvokedButExempt
  | false, Kind.unexempt => Verdict.notRunAnywhere
  | false, Kind.ciStep   => Verdict.contradictionClaimsCiStepButAbsent
  | false, Kind.notInCi  => Verdict.okExempt

def isContradiction : Verdict → Bool
  | Verdict.contradictionInvokedButExempt => true
  | Verdict.contradictionClaimsCiStepButAbsent => true
  | _ => false

/-- **No two states collapse.** Six inputs, six distinct outcomes. A dispatch that
returns the same token for two different situations has silently merged them, and
the merged pair is always a real case reported as a benign one. -/
theorem verdict_states_are_distinct :
    verdict true Kind.unexempt ≠ verdict true Kind.ciStep ∧
    verdict true Kind.ciStep ≠ verdict true Kind.notInCi ∧
    verdict true Kind.notInCi ≠ verdict false Kind.unexempt ∧
    verdict false Kind.unexempt ≠ verdict false Kind.ciStep ∧
    verdict false Kind.ciStep ≠ verdict false Kind.notInCi ∧
    verdict false Kind.notInCi ≠ verdict true Kind.unexempt ∧
    verdict true Kind.unexempt ≠ verdict true Kind.notInCi ∧
    verdict true Kind.ciStep ≠ verdict false Kind.ciStep := by
  decide

/-- **Exactly when the two sources disagree.** A contradiction is reported if and
only if a workflow invokes something the table excuses, or the table claims a CI
step no workflow runs. Nothing else is a contradiction, and neither of these is
anything else. -/
theorem contradiction_iff (inv : Bool) (k : Kind) :
    isContradiction (verdict inv k) = true ↔
      ((inv = true ∧ k = Kind.notInCi) ∨ (inv = false ∧ k = Kind.ciStep)) := by
  cases inv <;> cases k <;> simp [verdict, isContradiction]

/-- **A missing kind hides a contradiction.** This is why the two tables must name
one set. Drop a checker from the kind table while its written reason stays, and it
is classified `unexempt` -- and no `unexempt` input can ever yield a contradiction
verdict. The alarm is not weakened, it is removed. -/
theorem a_missing_kind_hides_a_contradiction (inv : Bool) :
    isContradiction (verdict inv Kind.unexempt) = false := by
  cases inv <;> simp [verdict, isContradiction]

/-- ...and the contradiction it hides was a real one, for both classifications.
Without this the theorem above would be compatible with there being nothing to
hide. -/
theorem the_hidden_contradiction_was_real :
    isContradiction (verdict true Kind.notInCi) = true ∧
    isContradiction (verdict false Kind.ciStep) = true := by
  decide

/-- The measured state of the tree on 2026-08-19, after the fix: the defect site
lands on `okExempt`, and the two checkers CI genuinely runs land on the documented
step. Before the fix, `gate-all.sh` landed on `okWired` -- the false green. -/
theorem the_measured_tree :
    verdict false Kind.notInCi = Verdict.okExempt ∧
    verdict true Kind.ciStep = Verdict.okDocumentedCiStep ∧
    verdict true Kind.notInCi = Verdict.contradictionInvokedButExempt := by
  decide

end RotMoE.Wiring
