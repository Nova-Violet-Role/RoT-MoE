/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A branch push is still a push

On 2026-08-11 a branch was pushed to the remote while the completion promise was
unfulfilled. The reasoning at the time, stated in the session and wrong, was:

> pushing a branch is evidence-gathering, not publishing

It is not a defensible distinction. The branch was visible on the remote, CI ran
against it, and its green was then used as evidence for a claim about `main`. The
branch was deleted at the Socio's instruction and the remote is back to a single
ref — but **fifty-eight gates existed and not one of them was about the push
action**. Every gate judged the *tree*; none judged the *transmission*.

This module is the specification for the missing gate, and it is written to make
the specific rationalisation above unstatable rather than merely discouraged.

## The design constraint that matters most

A guard like this is easy to write in a form that **expires**. Enumerating today's
open obligations as a constant, then proving "the constant is non-empty, so refuse",
gives a theorem that is true today and becomes *false on the day the work is
finished* — at which point the obvious repair is to weaken or delete it, destroying
the coverage. That is the defect this project has already hit once.

So every theorem below is quantified over the obligation, the state, or the push
target. The one contingent fact — which obligations are open right now — is a
`#guard`, never a hypothesis anything rests on.
-/

namespace RotMoE.PushGuard

/-- The obligations the completion promise names. Enumerated so the guard has
something to be total over; which of them are *met* is state, not spec. -/
inductive Obligation where
  | corpus40
  | pilot12Pairs
  | sessions160
  | preferenceMeasured
  | p22Established
  | verifyRunOnMain
  deriving DecidableEq, Repr

/-- Every obligation, in one place. -/
def allObligations : List Obligation :=
  [.corpus40, .pilot12Pairs, .sessions160, .preferenceMeasured, .p22Established,
   .verifyRunOnMain]

/-- Where a push could go. The three are listed precisely because the failed
rationalisation depended on treating them differently. -/
inductive PushTarget where
  | mainBranch
  | sideBranch
  | tag
  deriving DecidableEq, Repr

/-- What has actually been met. -/
structure PromiseState where
  met : List Obligation
  deriving DecidableEq, Repr

/-- The promise is fulfilled when nothing is outstanding. -/
def isFulfilled (s : PromiseState) : Bool :=
  allObligations.all (fun o => s.met.contains o)

/-- **The guard.** Note what it does *not* take into account: the target. -/
def mayPush (s : PromiseState) (_t : PushTarget) : Bool := isFulfilled s

/-! ## The ledger must cover the type

**Found by mutation P04, which survived the first version of this module.** Every
theorem below quantifies over `o ∈ allObligations` — which means an obligation that
is simply *not in the list* is never required by anything. Replacing one entry with
a duplicate of another left the list at six entries, kept `allObligations.length =
6` true, and kept every other theorem green while silently dropping an obligation
from the guard entirely.

Length is not coverage. These two close it. -/

/-- **The ledger lists every obligation there is.** Not "six of them" — all of them,
checked constructor by constructor, so adding a case to `Obligation` without adding
it here fails to compile. -/
theorem the_ledger_lists_every_obligation (o : Obligation) : o ∈ allObligations := by
  cases o <;> decide

/-- And it lists each one once, so a duplicate cannot masquerade as coverage while
displacing something real. -/
theorem the_ledger_repeats_nothing : allObligations.Nodup := by decide

/-! ## The rationalisation, refuted -/

/-- **A branch push is still a push.** For every state and every pair of targets,
the guard returns the same answer — so "it is only a side branch" cannot change the
verdict, and neither can "it is only a tag". This is the theorem that makes the
sentence at the top of this file unstatable. -/
theorem the_target_cannot_change_the_verdict (s : PromiseState) (t₁ t₂ : PushTarget) :
    mayPush s t₁ = mayPush s t₂ := rfl

/-- Spelled out on the exact pair that was argued about, so the general theorem
above is not the only thing a reader has to trust. -/
theorem a_side_branch_is_judged_exactly_like_main (s : PromiseState) :
    mayPush s .sideBranch = mayPush s .mainBranch := rfl

/-! ## The guard refuses for a reason, and the reason is general -/

/-- **One outstanding obligation is enough to refuse**, whatever it is and whatever
else has been done. Quantified over the obligation, so a future obligation added to
the enumeration is covered on the day it is added. -/
theorem one_outstanding_obligation_refuses_every_push
    (s : PromiseState) (t : PushTarget) (o : Obligation)
    (hmem : o ∈ allObligations) (hopen : s.met.contains o = false) :
    mayPush s t = false := by
  cases hb : isFulfilled s with
  | false => simp [mayPush, hb]
  | true =>
    exfalso
    simp only [isFulfilled, List.all_eq_true] at hb
    have hc := hb o hmem
    rw [hopen] at hc
    exact Bool.noConfusion hc

/-- And the converse, so the guard is not simply "always refuse": permission is
exactly the absence of anything outstanding. A gate that can never open is not a
gate, it is a wall, and it would be abandoned within a week. -/
theorem permission_is_exactly_an_empty_outstanding_list
    (s : PromiseState) (t : PushTarget) :
    mayPush s t = true ↔ ∀ o ∈ allObligations, s.met.contains o = true := by
  simp [mayPush, isFulfilled, List.all_eq_true]

/-- **The guard does not forbid a correct future.** A state in which everything has
genuinely been met is permitted — stated over the target too, so finishing the work
opens every route at once rather than one at a time. -/
theorem a_finished_promise_permits_every_push (t : PushTarget) :
    mayPush { met := allObligations } t = true := by
  cases t <;> decide

/-! ## Monotonicity: progress never un-refuses, regress never un-permits -/

/-- Meeting one more obligation can never turn a permitted push into a refused one.
Without this, the guard could punish progress. -/
theorem meeting_more_never_withdraws_permission
    (s : PromiseState) (o : Obligation) (t : PushTarget)
    (h : mayPush s t = true) :
    mayPush { met := o :: s.met } t = true := by
  rw [permission_is_exactly_an_empty_outstanding_list] at h ⊢
  intro x hx
  have := h x hx
  simp at this ⊢
  exact Or.inr this

/-! ## Non-vacuity, and the state as it actually is -/

/-- The instrument can refuse: the state in which nothing has been met is denied on
every target. If this were not provable the whole module would be decoration. -/
theorem the_empty_state_is_refused_on_every_target :
    mayPush { met := [] } .mainBranch = false ∧
    mayPush { met := [] } .sideBranch = false ∧
    mayPush { met := [] } .tag = false := by decide

/-- And it can permit — both directions, which is what separates a guard from a
wall. -/
theorem the_instrument_can_both_refuse_and_permit :
    mayPush { met := [] } .sideBranch = false ∧
    mayPush { met := allObligations } .sideBranch = true := by decide

/-- **The push that actually happened, judged.** The state at the time had none of
the six met; the guard refuses it. This is a statement about a historical state, so
it stays true forever regardless of what is met later. -/
theorem the_push_of_2026_08_11_would_have_been_refused :
    mayPush { met := [] } .sideBranch = false := by decide

/-- Even the most generous reading of that moment — crediting everything that had
in fact been done, with only the promise's research obligations outstanding — still
refuses. The push was not a borderline call. -/
theorem it_was_not_close :
    mayPush { met := [.verifyRunOnMain, .p22Established] } .sideBranch = false := by
  decide

-- CONTINGENT. Which obligations are open today is a fact that must move, so it
-- lives in guards and never in a hypothesis. When these flip, the theorems above
-- are unaffected -- that is the entire point of quantifying them.
#guard allObligations.length == 6
#guard isFulfilled { met := [] } == false
#guard isFulfilled { met := allObligations } == true

end RotMoE.PushGuard
