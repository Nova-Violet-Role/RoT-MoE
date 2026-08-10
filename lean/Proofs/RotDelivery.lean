/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A hook firing into a void writes the same bytes as a hook that was heard

**Measured 2026-08-10**, the first time `checker/live-session-smoke.sh` phase 3
was ever executed end to end. It had shipped for weeks and it was wrong in three
independent ways at once, all of them attribution defects:

1. **No isolation.** It dropped `CLAUDE_CONFIG_DIR` "for credentials", which also
   inherits the live plugin root. The debug log recorded
   `Registered 68 hooks from 7 plugins`, and a second installed copy of *this
   very router* was among them. Two copies emit byte-identical lines, so every
   marker hit was unattributable. After the repair: `0 hooks from 0 plugins`.
2. **It could not complete.** The prompt started a full agentic session: exit
   **124** at 180 s, **124** again at 360 s, with the model's stdout at **0
   bytes** and the debug log at 496 KB.
3. **The verdict read the wrong channel.** The marker was counted in the hook's
   own debug log — the hook's echo of its own output. A hook whose output is
   discarded before it reaches the model writes exactly the same bytes there.

The third is the one this file is about, because the old source *said so in a
comment* while the code went on counting it:

> "the marker is written by the hook when the prompt is submitted, BEFORE the
> session can die, so it is present in the failure path and cannot testify to
> anything about the outcome."

`oldVerdict` below is what shipped. `verdict` is the repair: the pass condition
is the marker appearing in the **model's own answer stream**, in reply to a
prompt asking it to quote the line back — a channel no hook can write — with a
disarmed control at that same channel.

**`verdict_is_strictly_stronger` is the load-bearing theorem here.** A repair
that narrows a check is indistinguishable from a repair that *weakens* it unless
someone proves the new condition still implies the old one. It does, so no
coverage was traded for the green.

The second half of the file is about the phase selector added the same day, and
about a smaller defect found while reading the output of the repaired run: the
line printed as evidence under a PASS was **not** the line that earned it.
-/

namespace RotDelivery

/-! ## Part 1 — the two channels

`armedOut`/`disOut` count the marker in the **model's** stdout; `armedDbg`/
`disDbg` count it in the **hook's** debug log. The whole defect lives in the
difference between those two columns. -/

/-- One phase-3 observation: both channels for both sessions, and the exit code
of each session. -/
structure Phase3 where
  /-- Exit code of the armed session. -/
  armedRc : Nat
  /-- Marker count in the armed session's *model output*. -/
  armedOut : Nat
  /-- Marker count in the armed session's *hook debug log*. -/
  armedDbg : Nat
  /-- Exit code of the disarmed control session. -/
  disRc : Nat
  /-- Marker count in the control's *model output*. -/
  disOut : Nat
  /-- Marker count in the control's *hook debug log*. -/
  disDbg : Nat
  deriving DecidableEq, Repr

/-- **What shipped.** `CTX_HIT` summed both channels; the pass condition was
`CTX_RC == 0 && CTX_HIT > 0`. There was no control session at all. -/
def oldVerdict (p : Phase3) : Bool :=
  p.armedRc == 0 && 0 < p.armedOut + p.armedDbg

/-- **The repair.** Both sessions must complete; the marker must reach the
model's own output; and with the router disarmed it must be absent from *both*
channels — absent from the model's output or the model invented it, absent from
the hook log or a second installed copy is firing and the armed run attributes
nothing. -/
def verdict (p : Phase3) : Bool :=
  p.armedRc == 0 && p.disRc == 0 &&
  0 < p.armedOut && p.disOut == 0 && p.disDbg == 0

/-- The run measured on 2026-08-10 after the repair: model output 1, hook log 4,
control 0/0, both sessions exit 0. -/
def theMeasuredRun : Phase3 := ⟨0, 1, 4, 0, 0, 0⟩

/-- A hook that fires into a void: it completes, it logs itself four times, and
the model receives nothing. This is the run the old verdict could not exclude. -/
def voidHook : Phase3 := ⟨0, 0, 4, 0, 0, 0⟩

/-- The contamination actually observed before isolation: a second installed
copy of the router fires, so the marker is in the log even with the scratch
settings disarmed. -/
def contaminated : Phase3 := ⟨0, 1, 4, 0, 0, 3⟩

/-- The model inventing the line rather than receiving it: it appears in the
model's output in *both* arms. -/
def fabricated : Phase3 := ⟨0, 1, 0, 0, 1, 0⟩

/-- The measured pre-repair incident: the agentic prompt timed out, twice, with
137 marker hits in the log and an empty stdout. -/
def theTimeout : Phase3 := ⟨124, 0, 137, 0, 0, 0⟩

/-! ### The blindness, and that the repair does not pay for it -/

/-- **The hole, as a theorem.** A hook whose output never reaches the model
passes the shipped verdict. -/
theorem void_hook_passes_the_old_verdict : oldVerdict voidHook = true := by decide

/-- The repair refuses exactly that run. -/
theorem void_hook_is_refused : verdict voidHook = false := by decide

/-- **Why no amount of care with the hook log could have caught it.** A delivered
run and a void run are *the same value* to the old verdict, though the runs
differ. -/
theorem old_verdict_cannot_separate_delivery_from_a_void :
    oldVerdict theMeasuredRun = oldVerdict voidHook ∧ theMeasuredRun ≠ voidHook := by
  constructor
  · decide
  · decide

/-- **The hook's own log cannot decide delivery, for any pair of runs.** Two
observations agreeing on `armedDbg` — byte-identical debug logs — can still
disagree under the repaired verdict. The evidence is in the other column. -/
theorem hook_log_is_not_evidence_of_delivery :
    ∃ p q : Phase3, p.armedDbg = q.armedDbg ∧ verdict p ≠ verdict q :=
  ⟨theMeasuredRun, voidHook, by decide, by decide⟩

/-- **No weakening.** Everything the shipped verdict demanded is still demanded.
This is what separates a repair from a quiet loosening of the gate. -/
theorem verdict_is_strictly_stronger (p : Phase3) :
    verdict p = true → oldVerdict p = true := by
  simp only [verdict, oldVerdict, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq]
  intro h
  exact ⟨h.1.1.1.1, by omega⟩

/-- …and *strictly* so: the implication does not run backwards. -/
theorem old_verdict_does_not_imply_the_new_one :
    ∃ p : Phase3, oldVerdict p = true ∧ verdict p = false :=
  ⟨voidHook, by decide, by decide⟩

/-! ### The three ways a phase-3 pass can be forged, each refused -/

/-- Contamination by a second installed copy is refused. -/
theorem contamination_is_refused : verdict contaminated = false := by decide

/-- …and it *passed* before, which is why isolation is a fix and not a polish. -/
theorem contamination_passed_the_old_verdict : oldVerdict contaminated = true := by
  decide

/-- A model that invents the line is refused, because the control session sees
it too. -/
theorem fabrication_is_refused : verdict fabricated = false := by decide

/-- The real timeout is refused by both verdicts — the old one did get this
case right, and saying so is part of reporting the repair honestly. -/
theorem the_timeout_is_refused_by_both :
    verdict theTimeout = false ∧ oldVerdict theTimeout = false := by
  constructor
  · decide
  · decide

/-! ### What a pass entails -/

/-- A pass requires the marker in the model's output. The hook log alone can
never carry it, whatever its count. -/
theorem silent_model_output_never_passes (p : Phase3) :
    p.armedOut = 0 → verdict p = false := by
  intro h
  simp [verdict, h]

/-- A pass requires a measured GAP between the arms at the model's channel —
this is the attribution, and it is a consequence, not a separate convention. -/
theorem verdict_requires_a_gap (p : Phase3) :
    verdict p = true → p.disOut < p.armedOut := by
  simp only [verdict, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq]
  intro h
  omega

/-- Neither session may fail. A control that did not run is not a control. -/
theorem a_failed_control_never_passes (p : Phase3) :
    p.disRc ≠ 0 → verdict p = false := by
  intro h
  simp [verdict, h]

/-- The armed session must complete. -/
theorem a_failed_armed_session_never_passes (p : Phase3) :
    p.armedRc ≠ 0 → verdict p = false := by
  intro h
  simp [verdict, h]

/-- **Not vacuous.** The verdict is satisfiable, and the witness is the run that
was actually measured. -/
theorem the_measured_run_passes : verdict theMeasuredRun = true := by decide

#guard verdict theMeasuredRun = true
#guard verdict voidHook = false
#guard oldVerdict voidHook = true
#guard verdict contaminated = false
#guard verdict fabricated = false
#guard verdict theTimeout = false

/-! ## Part 2 — the phase selector

Phase 3 runs a session per arm and retries once at double the budget, so a full
invocation is 180+180+180+360 s worst case in one process. Every caller with a
shorter bound was reduced to killing it, which is why phase 3 had never been
measured. The selector lets a caller run one phase — and a partial run is
**never** a pass. -/

/-- The phases the checker declares. -/
def declaredPhases : List Nat := [1, 2, 3]

/-- A selected run: which phases were asked for, and how many checks failed. -/
structure PhaseRun where
  /-- Phases named by `ROTMOE_SMOKE_PHASES`. -/
  selected : List Nat
  /-- Failed checks among the phases that did run. -/
  failed : Nat
  deriving Repr

/-- Declared phases that were not selected. -/
def notrun (r : PhaseRun) : Nat :=
  (declaredPhases.filter (fun p => !(r.selected.contains p))).length

/-- Exit code: 3 for a partial run, 1 for a failure, 0 only for a complete
clean run. Order matters — a partial run cannot be redeemed by having no
failures, which is exactly the shape that made `ci-dryrun.sh` exit 0 on zero
executed steps. -/
def phaseExit (r : PhaseRun) : Nat :=
  if 0 < notrun r then 3 else if 0 < r.failed then 1 else 0

/-- **A partial run is never a pass**, for any selection and any failure count. -/
theorem partial_run_is_never_a_pass (r : PhaseRun) :
    0 < notrun r → phaseExit r ≠ 0 := by
  intro h
  simp [phaseExit, h]

/-- A pass entails that every declared phase ran. The contrapositive of the
above, stated in the direction a reader of a green run cares about. -/
theorem a_pass_entails_every_phase_ran (r : PhaseRun) :
    phaseExit r = 0 → notrun r = 0 := by
  intro h
  by_cases hn : 0 < notrun r
  · simp [phaseExit, hn] at h
  · omega

/-- The measured control: `ROTMOE_SMOKE_PHASES=3` leaves two phases unrun and
exits 3. -/
theorem phase3_alone_exits_three : phaseExit ⟨[3], 0⟩ = 3 := by decide

/-- The measured control: `ROTMOE_SMOKE_PHASES=9` selects nothing at all, and
that is not a clean sweep of zero phases. -/
theorem selecting_nothing_exits_three : phaseExit ⟨[], 0⟩ = 3 := by decide

/-- **Not vacuous**: the default selection with no failures passes. This is the
run measured at 19 passed, 0 failed, exit 0. -/
theorem the_full_run_can_pass : phaseExit ⟨[1, 2, 3], 0⟩ = 0 := by decide

/-- A failure in a complete run is still a failure. -/
theorem a_complete_run_with_a_failure_fails : phaseExit ⟨[1, 2, 3], 1⟩ = 1 := by
  decide

/-- `declaredPhases` is the concrete list `[1,2,3]`, so `notrun` is just a sum of
three indicators. Stated separately because the monotonicity proof below is a
case split and this is what it splits on. -/
theorem notrun_eq (r : PhaseRun) :
    notrun r =
      (if 1 ∈ r.selected then 0 else 1) +
      (if 2 ∈ r.selected then 0 else 1) +
      (if 3 ∈ r.selected then 0 else 1) := by
  simp only [notrun, declaredPhases]
  by_cases h1 : 1 ∈ r.selected <;> by_cases h2 : 2 ∈ r.selected <;>
    by_cases h3 : 3 ∈ r.selected <;> simp [h1, h2, h3]

/-- **Selecting more phases can never redden the run.** The same guarantee
`fewer_deferrals_never_reddens` gives in `RotPartialRun`: a convenience flag
must not be able to punish an improvement. -/
theorem selecting_a_superset_never_increases_notrun (r s : PhaseRun) :
    (∀ p, p ∈ r.selected → p ∈ s.selected) →
    notrun s ≤ notrun r := by
  intro h
  have h1 := h 1
  have h2 := h 2
  have h3 := h 3
  rw [notrun_eq, notrun_eq]
  by_cases hr1 : 1 ∈ r.selected <;> by_cases hs1 : 1 ∈ s.selected <;>
    by_cases hr2 : 2 ∈ r.selected <;> by_cases hs2 : 2 ∈ s.selected <;>
      by_cases hr3 : 3 ∈ r.selected <;> by_cases hs3 : 3 ∈ s.selected <;>
        simp_all

/-! ### Phase 2 cannot stand alone

Phase 2's entire content is the comparison `armed=N vs disarmed=M`, and `N` is
produced by phase 1. Selecting 2 without 1 would compare against a value that
was never measured and report an attribution out of thin air — a fake green
built out of a convenience flag. The checker refuses with exit 2. -/

/-- A selection is admissible only if choosing the control also chooses the
measurement it is a control *for*. -/
def admissible (sel : List Nat) : Bool :=
  !(sel.contains 2) || sel.contains 1

/-- The refusal, on the selection that motivated it. -/
theorem phase2_alone_is_inadmissible : admissible [2] = false := by decide

/-- The pair is fine. -/
theorem phase1_and_2_is_admissible : admissible [1, 2] = true := by decide

/-- Dropping the control entirely is admissible — phase 1 stands on its own,
phase 2 does not. The asymmetry is the point. -/
theorem phase1_alone_is_admissible : admissible [1] = true := by decide

/-- The default is admissible, so the ban cannot fire on a normal run. -/
theorem the_default_selection_is_admissible : admissible [1, 2, 3] = true := by
  decide

#guard notrun ⟨[3], 0⟩ = 2
#guard notrun ⟨[], 0⟩ = 3
#guard notrun ⟨[1, 2, 3], 0⟩ = 0
#guard phaseExit ⟨[3], 0⟩ = 3
#guard phaseExit ⟨[1, 2, 3], 0⟩ = 0
#guard admissible [2] = false
#guard admissible [1, 2] = true

/-! ## Part 3 — the line printed as evidence must be the line that was checked

Found by reading the repaired run's own output. Phase 1 asserted
`routed CORRECTLY -- 'lake build the theorem' -> FORGE Claude` and printed,
directly underneath, `RoT MoE :: TIER 1 -> CONVERGENT model | R/s+ 0.16`.

The verdict was right: the session emits several marker lines — one at
`SessionStart`, before any prompt exists, and one at `UserPromptSubmit` — and
the FORGE line was among them. The *evidence* was `head -1` over all of them, so
it printed the earliest line rather than the matching one. A reader checking the
work sees a PASS contradicted by the line under it, and the honest reading of
that is that the check is broken. -/

/-- The lanes that appear in a session log. -/
inductive Lane
  /-- Emitted at `SessionStart`, before a prompt exists. -/
  | convergent
  /-- Emitted at `UserPromptSubmit` for a prompt with FORGE stems. -/
  | forge
  deriving DecidableEq, Repr

/-- The marker lines a single armed session actually produced, in order. -/
def sessionLog : List Lane := [Lane.convergent, Lane.forge]

/-- What the check looks for. -/
def isForge (l : Lane) : Bool := l == Lane.forge

/-- **The bug**: the first line of the log. -/
def printedEvidence (log : List Lane) : Option Lane := log.head?

/-- **The fix**: the first line that satisfies the predicate. -/
def matchingEvidence (log : List Lane) : Option Lane := log.find? isForge

/-- The check itself, which was never wrong. -/
def routedCorrectly (log : List Lane) : Bool := (log.find? isForge).isSome

/-- **The defect, as a theorem**: on the log that was actually produced, the
check passes and the evidence printed is not the line that satisfied it. -/
theorem printed_evidence_was_not_the_matching_line :
    routedCorrectly sessionLog = true ∧
    printedEvidence sessionLog ≠ matchingEvidence sessionLog := by
  constructor
  · decide
  · decide

/-- The repaired evidence is, by construction, a line that satisfies the check —
whatever the log contains. -/
theorem matching_evidence_always_satisfies_the_check (log : List Lane) (l : Lane) :
    matchingEvidence log = some l → isForge l = true := by
  intro h
  exact List.find?_some h

/-- …which `head?` does not: it can hand back a line the check rejects. -/
theorem printed_evidence_need_not_satisfy_the_check :
    ∃ (log : List Lane) (l : Lane),
      printedEvidence log = some l ∧ isForge l = false ∧ routedCorrectly log = true :=
  ⟨sessionLog, Lane.convergent, by decide, by decide, by decide⟩

/-- When the log has exactly one line the two agree, which is why this survived
review for so long: on the small logs a reader imagines, the bug is invisible. -/
theorem the_two_agree_on_a_single_matching_line :
    printedEvidence [Lane.forge] = matchingEvidence [Lane.forge] := by decide

#guard routedCorrectly sessionLog = true
#guard printedEvidence sessionLog = some Lane.convergent
#guard matchingEvidence sessionLog = some Lane.forge

/-! ## Part 4 — a frozen expectation expires; a derived one does not

The same check compared the emitted lane against the literal `FORGE Claude`.
That is a snapshot of today's router, not the property that matters. The day the
FORGE lead is renamed — a change the project may legitimately make — a correct
router fails a green checker, and the obvious repair is to delete the check.

The property that matters is *this prompt reaches the FORGE lane*; the lead's
spelling belongs to `hooks/rot-router.sh`, so the checker now reads it from
there. The second theorem is the one that makes this a fix rather than a
loosening: the derived check still refuses a genuine misroute. -/

/-- The router, reduced to the one field this check reads. -/
structure Router where
  /-- The lead named beside `FORGE` in `hooks/rot-router.sh`. -/
  forgeLead : String

/-- What the router emits for the FORGE lane. -/
def emittedLane (r : Router) : String := "FORGE " ++ r.forgeLead

/-- **What shipped**: today's value, frozen into the checker. -/
def frozenCheck (emitted : String) : Bool := emitted == "FORGE Claude"

/-- **The repair**: the expectation is read from the router. -/
def derivedCheck (r : Router) (emitted : String) : Bool := emitted == emittedLane r

/-- The router as it stands today. -/
def today : Router := ⟨"Claude"⟩

/-- A legitimate future rename. -/
def renamed : Router := ⟨"Forge"⟩

/-- Both checks agree on today's router — the repair changes nothing that is
currently true. -/
theorem the_repair_is_a_no_op_today :
    frozenCheck (emittedLane today) = true ∧
    derivedCheck today (emittedLane today) = true := by
  constructor
  · decide
  · decide

/-- **The frozen check fails a correct router.** Not a hypothetical shape: it is
the same defect class as a spec that pins a contingent constant. -/
theorem frozen_check_reddens_a_correct_rename :
    frozenCheck (emittedLane renamed) = false ∧
    derivedCheck renamed (emittedLane renamed) = true := by
  constructor
  · decide
  · decide

/-- **And the repair is not a loosening**: for every router, anything other than
what that router emits is still refused. -/
theorem derived_check_still_refuses_a_misroute (r : Router) (e : String) :
    e ≠ emittedLane r → derivedCheck r e = false := by
  intro h
  simp [derivedCheck, h]

/-- Concretely: today's router still rejects the CONVERGENT line, which is the
misroute the check exists to catch. -/
theorem today_still_refuses_convergent :
    derivedCheck today "CONVERGENT model" = false := by decide

#guard frozenCheck (emittedLane today) = true
#guard frozenCheck (emittedLane renamed) = false
#guard derivedCheck renamed (emittedLane renamed) = true
#guard derivedCheck today "CONVERGENT model" = false

end RotDelivery
