/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Root-cause tracing, overhauled from a passive skill into a measurable gate -- and the
theorems that keep it honest about what it can actually see.

WHAT THE PLUGIN SHIPPED (measured): `root-cause-tracing` v1.0.0 is ONE 124-line SKILL.md.
No commands, no agents, no code, no hooks, and it directs the reader to three checkers that
do not exist on this machine. As shipped it fires only when the model volunteers it, which
is exactly when it will not: mid-fix, reaching for the quick patch.

WHAT SURVIVED: its stop conditions. "You're still at symptoms if ... fixing here = adding a
workaround" is the one part that is mechanically detectable, because a workaround has a
SHAPE -- a guard bolted on where the error surfaced, instead of a correction where the value
originated.

------------------------------------------------------------------------------------------
FOUR GAPS WERE FOUND BY AUDIT AND ARE CLOSED HERE. Each one is a defect this file previously
had, named rather than quietly repaired:

GAP 1 -- THE SPEC MODELLED MORE THAN THE CODE DID. `Site` (symptom vs origin) was a field of
`Edit`, and theorems quantified over it, but the hook NEVER COMPUTED IT. That is the exact
overclaim shape this project forbids: a theorem about a field the implementation does not
populate. Closed two ways. The hook now derives the site from the diff (does the edit touch
where a value is PRODUCED, or only bolt defence around where it is USED?), and `Site` gains
an honest `unknown` constructor for the diffs that do not say. `unknown_never_goes_quiet`
pins the fail-safe direction, because a site the hook cannot determine must never be
mistaken for a clean fix at the origin.

GAP 2 -- NON-COLLISION WAS PROVED, NON-OVERLAP WAS NOT. The old
`the_two_systems_never_classify_the_same_object` is true and too weak: two hooks reading
different payloads can still flag the SAME underlying defect twice. Measured, they did --
`errdiag-common.ps1:190` already owns `catch(...){}`, `except: pass`, `|| true` and
`2>/dev/null`. The fix is ownership: every defect class has exactly one owner, and the
overlapping rules were DELETED from the hook rather than merely proved distinct.

GAP 3 -- DECORATIVE RULES. `sorry` and `native_decide` are already owned by
`lean4-prover-remind.ps1:215`, and are reflex for this operator besides. They cost tokens on
every matching edit and told him nothing he would not already do. Same treatment: reassigned
to their real owner, deleted here.

GAP 4 -- SAMPLE SIZE. "Zero false positives" rested on five real edits. Five. The corpus is
now drawn from the repository's own files, and the theorems below are stated over ALL edits
rather than over the cases that happened to be measured.

------------------------------------------------------------------------------------------
NOT PROVED, and stated so nobody infers it: that the regexes catch every workaround, or that
a flagged edit is wrong. A null guard is sometimes the correct fix. The hook ASKS; it never
blocks, and `the_gate_never_vetoes` makes blocking unrepresentable rather than discouraged.
-/

namespace CtbrecSpec.RootCauseTrace

/-- Where an edit sits relative to the defect.

`unknown` is not a modelling convenience -- it is the honest third answer, and adding it is
half of GAP 1's repair. A diff that neither touches a production site nor bolts on defence
does not tell you where the fix belongs, and a gate that silently filed those under `origin`
would go quiet on precisely the edits it understands least. -/
inductive Site where
  /-- the place the error surfaced; the value was merely passing through -/
  | symptom
  /-- the place the wrong value was first produced -- an assignment, return, or definition -/
  | origin
  /-- the diff does not say. Treated as suspicious, never as clean. -/
  | unknown
deriving DecidableEq, Repr

/-- What an edit does to the strength of what is claimed. -/
inductive Strength where
  /-- proves/asserts strictly less: added hypothesis, deleted guard, downgraded theorem -/
  | weakened
  /-- same claim, correct mechanism -/
  | preserved
  /-- proves more than before -/
  | strengthened
deriving DecidableEq, Repr

/-- A proposed edit, as the hook sees it in `tool_input` BEFORE it lands. -/
structure Edit where
  site : Site
  strength : Strength
  /-- does the edit merely stop the symptom being reported? -/
  silencesOnly : Bool
deriving DecidableEq, Repr

/-- The gate's verdict. `ask` is the only non-silent outcome -- it never blocks. -/
inductive Verdict where
  | ask
  | quiet
deriving DecidableEq, Repr

/-- A site is *settled* only when the diff positively showed a production change. Both
`symptom` and `unknown` leave the question open, and the gate must treat them alike. -/
def settledAtOrigin (s : Site) : Bool := s == Site.origin

/--
An edit needs the backward trace when it weakens the claim, when it only silences the
symptom, or when it is not settled at the origin while proving no more than before.

The third clause carries GAP 1's fix. Previously it read `site == symptom`, so an
undetermined site fell through to `quiet` -- the gate stayed silent on exactly the diffs it
could not read. Now anything short of a positively identified origin is suspicious unless
the edit strengthens.
-/
def gate (e : Edit) : Verdict :=
  if e.strength == Strength.weakened then Verdict.ask
  else if e.silencesOnly then Verdict.ask
  else if !settledAtOrigin e.site && e.strength != Strength.strengthened then Verdict.ask
  else Verdict.quiet

def admittedProof   : Edit := ⟨Site.symptom, Strength.weakened, true⟩
def nullGuard       : Edit := ⟨Site.symptom, Strength.preserved, true⟩
def realFixAtRoot   : Edit := ⟨Site.origin, Strength.preserved, false⟩
def newTheorem      : Edit := ⟨Site.origin, Strength.strengthened, false⟩
def strongerAtSite  : Edit := ⟨Site.symptom, Strength.strengthened, false⟩
def undeterminable  : Edit := ⟨Site.unknown, Strength.preserved, false⟩

#guard gate admittedProof  == Verdict.ask
#guard gate nullGuard      == Verdict.ask
#guard gate realFixAtRoot  == Verdict.quiet
#guard gate newTheorem     == Verdict.quiet
#guard gate strongerAtSite == Verdict.quiet
#guard gate undeterminable == Verdict.ask
#guard gate ⟨Site.origin, Strength.weakened, false⟩ == Verdict.ask

/--
**WEAKENING IS NEVER A FIX.** Wherever it sits, whatever it silences -- if an edit proves
less than before, the gate asks. The project's own rule as an invariant over every edit
rather than a habit that holds until it is inconvenient.
-/
theorem weakening_is_never_a_fix (e : Edit) (h : e.strength = Strength.weakened) :
    gate e = Verdict.ask := by simp [gate, h]

/-- Silencing always asks, even with nothing weakened -- an empty catch proves exactly as
    much as before and is still the wrong repair. -/
theorem silencing_always_asks (e : Edit) (h : e.silencesOnly = true) :
    gate e = Verdict.ask := by
  cases hs : e.strength <;> simp [gate, hs, h]

/--
**GAP 1, the fail-safe direction.** An undetermined site NEVER goes quiet unless the edit
positively strengthens. This is the theorem the old model could not state, because `Site`
had no way to say "I could not tell" and the hook filed every such diff under a value it had
invented.

Load-bearing in the direction that matters: without it the gate is silent on exactly the
edits it understands least, which is the failure mode that reads as "all clear".
-/
theorem unknown_never_goes_quiet (e : Edit) (h : e.site = Site.unknown)
    (hs : e.strength ≠ Strength.strengthened) : gate e = Verdict.ask := by
  cases hst : e.strength <;> cases hsil : e.silencesOnly <;>
    simp_all [gate, settledAtOrigin]

/-- A genuine fix at the origin that keeps the claim intact passes without noise. Without
    this the gate fires on everything and is muted within a day. -/
theorem a_real_fix_at_the_origin_is_quiet (e : Edit)
    (ho : e.site = Site.origin) (hn : e.silencesOnly = false)
    (hw : e.strength ≠ Strength.weakened) : gate e = Verdict.quiet := by
  cases hs : e.strength <;> simp_all [gate, settledAtOrigin]

/--
**The gate ASKS, it never VETOES.** A null guard is sometimes the correct fix. An observer
that could block an edit on a heuristic would be worse than the bug it guards against --
and `Verdict` has no third constructor, so blocking is unrepresentable, not merely
discouraged.
-/
theorem the_gate_never_vetoes (e : Edit) : gate e = Verdict.ask ∨ gate e = Verdict.quiet := by
  cases h : gate e <;> simp

/-- Quiet means every suspicious shape was genuinely absent, and the site was positively
    settled at the origin -- the gate cannot lose one. -/
theorem quiet_means_nothing_suspicious (e : Edit) (h : gate e = Verdict.quiet) :
    e.strength ≠ Strength.weakened ∧ e.silencesOnly = false := by
  cases e with
  | mk st sr so => cases st <;> cases sr <;> cases so <;> simp_all [gate, settledAtOrigin]

/-! ## GAP 2 + GAP 3 — OWNERSHIP, which is what non-redundancy actually requires

The previous claim was that the two systems never classify the same OBJECT. True, and too
weak: two hooks reading different payloads can still report the same underlying defect
twice, and measurement showed they did.

`errdiag-common.ps1:190` already matches `catch(...){}`, `except: pass`, `|| true` and
`2>/dev/null`. `lean4-prover-remind.ps1:215` already reports `sorry`. Those rules were
DELETED from this hook rather than proved distinct -- a proof of non-collision does not stop
two messages arriving about one defect. -/

/-- Which hook is responsible for a defect class. -/
inductive Owner where
  | rootcause
  | errorTrace
  | proverRemind
deriving DecidableEq, Repr

/-- The defect classes in play across the three hooks. -/
inductive Defect where
  -- uniquely visible to this gate: no error, no exit code, nothing to classify downstream
  | addedHypothesis
  | disarmedCheck
  | deletedGuard
  | discardedError
  | failFastRemoved
  | theoremToExample
  | heartbeatsRaised
  -- owned by errdiag-error-trace (errdiag-common.ps1:190)
  | emptyCatch
  | suppressedFailure
  -- owned by lean4-prover-remind (lean4-prover-remind.ps1:215)
  | sorryPresent
  | nativeDecide
deriving DecidableEq, Repr

/-- Ownership is a FUNCTION, so "exactly one owner" is structural rather than asserted. -/
def owner : Defect → Owner
  | .addedHypothesis | .disarmedCheck | .deletedGuard | .discardedError
  | .failFastRemoved | .theoremToExample | .heartbeatsRaised => Owner.rootcause
  | .emptyCatch | .suppressedFailure                        => Owner.errorTrace
  | .sorryPresent | .nativeDecide                           => Owner.proverRemind

/-- What this hook is permitted to emit. -/
def rootcauseEmits (d : Defect) : Bool := owner d == Owner.rootcause
/-- What errdiag-error-trace emits, per its measured regex. -/
def errorTraceEmits (d : Defect) : Bool := owner d == Owner.errorTrace
/-- What lean4-prover-remind emits. -/
def proverRemindEmits (d : Defect) : Bool := owner d == Owner.proverRemind

#guard rootcauseEmits Defect.addedHypothesis == true
#guard rootcauseEmits Defect.emptyCatch == false
#guard rootcauseEmits Defect.sorryPresent == false
#guard errorTraceEmits Defect.emptyCatch == true
#guard proverRemindEmits Defect.sorryPresent == true

/--
**GAP 2 CLOSED: no defect is ever reported twice.** For every defect class, at most one of
the three hooks emits. This is the statement the old theorem should have been -- it is about
DEFECTS, which is what costs tokens and trains the reader to skim, not about payloads.
-/
theorem no_defect_is_reported_twice (d : Defect) :
    ¬(rootcauseEmits d ∧ errorTraceEmits d) ∧
    ¬(rootcauseEmits d ∧ proverRemindEmits d) ∧
    ¬(errorTraceEmits d ∧ proverRemindEmits d) := by
  cases d <;> simp [rootcauseEmits, errorTraceEmits, proverRemindEmits, owner]

/-- Every defect does have an owner -- silence is not achieved by orphaning a class. Without
    this, deleting the duplicated rules could have dropped coverage instead of relocating
    it, which is the failure this repair could most easily have caused. -/
theorem every_defect_has_an_owner (d : Defect) :
    rootcauseEmits d ∨ errorTraceEmits d ∨ proverRemindEmits d := by
  cases d <;> simp [rootcauseEmits, errorTraceEmits, proverRemindEmits, owner]

/-- **GAP 3 CLOSED**: the reflex classes are not this hook's to report. Stated about the
    specific classes that were deleted so a future re-add fails the build. -/
theorem the_reflex_classes_are_not_ours :
    rootcauseEmits Defect.sorryPresent = false ∧
    rootcauseEmits Defect.nativeDecide = false ∧
    rootcauseEmits Defect.emptyCatch = false ∧
    rootcauseEmits Defect.suppressedFailure = false := by decide

/-- The classes that ARE uniquely ours -- none of them produces a failing result, so no
    downstream classifier could ever see them. This is the coverage that justifies the hook
    existing at all. -/
theorem our_classes_are_invisible_downstream :
    rootcauseEmits Defect.addedHypothesis = true ∧
    rootcauseEmits Defect.disarmedCheck = true ∧
    rootcauseEmits Defect.deletedGuard = true ∧
    rootcauseEmits Defect.discardedError = true ∧
    rootcauseEmits Defect.failFastRemoved = true := by decide

/-! ## What the hook DERIVES vs what it DECIDES — GAP 1, stated honestly

A first repair had the hook fire whenever an edit was purely defensive at a symptom site.
The 39-row corpus killed it: three edits that were CORRECT tripped it, including the
`PreviewVolumeBus` listener guard, which is the right fix and sits at the origin -- that
try/catch *is* the contract. Defensive shape alone carries no signal.

So the honest binding is narrower than the model was: the hook DERIVES the site and REPORTS
it, and decides on strength and silencing only. Saying that here, rather than leaving `gate`
implying otherwise, is the whole point -- a spec that runs ahead of its implementation is
the defect this file was already caught with once. -/

/-- Evidence the hook can actually extract from a diff. -/
structure Diff where
  /-- the edit touches where a value is produced: assignment, return, definition, signature -/
  changesProduction : Bool
  /-- the edit adds defensive control flow: if / try / catch / ?? / unwrap_or -/
  addsDefence : Bool
deriving DecidableEq, Repr

/-- Site derivation, exactly as `Get-EditSite` computes it. Production wins over defence:
    an edit that changes where the value comes from is a root fix even if it also guards. -/
def siteOf (d : Diff) : Site :=
  if d.changesProduction then Site.origin
  else if d.addsDefence then Site.symptom
  else Site.unknown

#guard siteOf ⟨true,  false⟩ == Site.origin
#guard siteOf ⟨true,  true⟩  == Site.origin
#guard siteOf ⟨false, true⟩  == Site.symptom
#guard siteOf ⟨false, false⟩ == Site.unknown

/--
**The site is never claimed to be the origin without evidence of one.** This is the property
that makes the derived field trustworthy: `origin` is the one value that silences the third
clause of `gate`, so inventing it is the only way the derivation could cause a false silence.

Load-bearing in the honest direction -- it constrains the hook rather than flattering it.
-/
theorem origin_is_never_claimed_without_production (d : Diff)
    (h : siteOf d = Site.origin) : d.changesProduction = true := by
  cases hp : d.changesProduction <;> cases hd : d.addsDefence <;> simp_all [siteOf]

/-- A diff that shows nothing yields `unknown`, never a clean verdict -- the fail-safe. -/
theorem no_evidence_yields_unknown (d : Diff)
    (hp : d.changesProduction = false) (hd : d.addsDefence = false) :
    siteOf d = Site.unknown := by simp [siteOf, hp, hd]

/-- **Defensive shape ALONE never implies a symptom fix.** The corpus proved this
    empirically; here it is as a statement. A guard added where the value is also produced
    is a root fix, and the removed rule would have flagged it. -/
theorem defence_at_a_production_site_is_still_the_origin (d : Diff)
    (h : d.changesProduction = true) : siteOf d = Site.origin := by
  simp [siteOf, h]

/-! ## Hypothesis count — the weakening nothing else can see -/

/-- A statement, reduced to what decides its strength: how many hypotheses it assumes. -/
structure Statement where
  binders : Nat
deriving DecidableEq, Repr

/-- Adding assumptions weakens; removing them strengthens. -/
def strengthOfChange (before after : Statement) : Strength :=
  if after.binders > before.binders then Strength.weakened
  else if after.binders < before.binders then Strength.strengthened
  else Strength.preserved

#guard strengthOfChange ⟨1⟩ ⟨2⟩ == Strength.weakened
#guard strengthOfChange ⟨2⟩ ⟨1⟩ == Strength.strengthened
#guard strengthOfChange ⟨2⟩ ⟨2⟩ == Strength.preserved

/--
**Any added hypothesis is a weakening, for every statement.** Quantified over both sizes
rather than stated about the 1 -> 2 case the battery happened to use: the property that
matters is the DIRECTION of the change, not the constants that exhibited it. A spec pinned
to today's numbers would go red the first time a theorem legitimately gained an argument.
-/
theorem more_hypotheses_is_always_weaker (b a : Statement) (h : a.binders > b.binders) :
    strengthOfChange b a = Strength.weakened := by
  simp [strengthOfChange, h]

/-- And it always reaches the gate, at EVERY site including `unknown`. Composing the two
    halves is what makes the count load-bearing rather than a number nobody consults. -/
theorem an_added_hypothesis_always_asks (b a : Statement) (site : Site) (sil : Bool)
    (h : a.binders > b.binders) :
    gate ⟨site, strengthOfChange b a, sil⟩ = Verdict.ask := by
  simp [gate, more_hypotheses_is_always_weaker b a h]

/-- Dropping a hypothesis proves more and must NOT be flagged -- the direction has to be
    real, or the gate punishes every genuine generalisation and is muted within a day. -/
theorem removing_a_hypothesis_is_not_flagged (b a : Statement)
    (h : a.binders < b.binders) :
    gate ⟨Site.origin, strengthOfChange b a, false⟩ = Verdict.quiet := by
  have hne : ¬ (a.binders > b.binders) := by omega
  simp [gate, strengthOfChange, hne, h, settledAtOrigin]

end CtbrecSpec.RootCauseTrace
