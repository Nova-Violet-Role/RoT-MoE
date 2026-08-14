/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
The error-diagnostics router: three hooks, one classifier, and the two properties that make
"not redundant" a THEOREM rather than a promise.

The Socio wired three commands -- /smart-debug, /error-analysis, /error-trace -- as three
separate hooks on the universal "*" matcher, and asked that they be powerful and NOT
redundant with each other. Three independent scripts each deciding for itself would overlap
the day their conditions drift apart, and drift is certain because they get edited on
different days. So all three share ONE classifier and each owns exactly one class.

What is proved here:

  * `at_most_one_hook_speaks`  -- EXCLUSIVITY. No input makes two hooks emit. This is the
    non-redundancy the Socio asked for, as a theorem over ALL inputs rather than a claim
    checked on a few examples.
  * `every_signal_is_routed`   -- TOTALITY. Any input carrying a real signal reaches some
    hook. Exclusivity alone is satisfiable by a router that says nothing, so without this
    the first theorem would be vacuous cover for a dead instrument.

Together they say: exactly one hook fires on a signal, none fires without one.

NOT PROVED, and not to be implied: that the PowerShell regexes recognise every real stack
trace, or that the plugin's advice is good. Those are measurements and a matter of judgement.
What is proved is that GIVEN a classification, the routing cannot double-fire, cannot drop a
signal, and cannot fire on a deliberate control.
-/

namespace CtbrecSpec.ErrorDiagRouting

/-- What the classifier can observe about a turn. Mirrors `Get-ErrDiagVerdict`. -/
structure Signals where
  /-- a non-zero exit that is not the 124 timeout cap -/
  hardExit : Bool
  /-- an exception class name or a stack frame in the output -/
  trace : Bool
  /-- this signature was already seen this session -/
  seen : Bool
  /-- an empty catch, `|| true`, 2>/dev/null, Redirect.DISCARD, `except: pass` -/
  swallow : Bool
  /-- the output is a DELIBERATE negative control: "control fired", "must FAIL", ... -/
  control : Bool
deriving DecidableEq, Repr

/-- The three commands, plus silence. -/
inductive Route where
  | smartDebug     -- FRESH   : first sighting, fast triage -> fix
  | errorAnalysis  -- REPEAT  : recurring, escalate to systemic root cause
  | errorTrace     -- SWALLOW : nothing failed, but nothing COULD report failure
  | silent
deriving DecidableEq, Repr

/-- A concrete failure is visible. -/
def failing (s : Signals) : Bool := s.hardExit || s.trace

/--
The classifier, transcribed from `errdiag-common.ps1`.

The `control` guard comes FIRST and is the reason the trio is usable in this repo at all:
the spec-check suite deliberately runs negative controls that print failure words and exit
non-zero. A router without this guard would fire on every suite run and be muted within a
day -- an alarm that cries wolf gets disabled, which is how a real alarm gets lost.
-/
def route (s : Signals) : Route :=
  if s.control then Route.silent
  else if failing s then
    (if s.seen then Route.errorAnalysis else Route.smartDebug)
  else if s.swallow then Route.errorTrace
  else Route.silent

/-- Does hook `r` emit on input `s`? Each hook returns early unless it owns the class. -/
def emits (r : Route) (s : Signals) : Bool := route s == r

-- concrete corpus: one input per class, and the control that must stay quiet
def freshFail   : Signals := ⟨true,  false, false, false, false⟩
def repeatFail  : Signals := ⟨true,  false, true,  false, false⟩
def traceOnly   : Signals := ⟨false, true,  false, false, false⟩
def swallowOnly : Signals := ⟨false, false, false, true,  false⟩
def controlRun  : Signals := ⟨true,  true,  true,  true,  true⟩
def quiet       : Signals := ⟨false, false, false, false, false⟩

#guard route freshFail   == Route.smartDebug
#guard route repeatFail  == Route.errorAnalysis
#guard route traceOnly   == Route.smartDebug
#guard route swallowOnly == Route.errorTrace
#guard route controlRun  == Route.silent
#guard route quiet       == Route.silent
-- a swallowed pattern in the SAME turn as a real failure must not split the verdict
#guard route ⟨true, false, false, true, false⟩ == Route.smartDebug
-- a repeat outranks a first-sighting fix attempt
#guard route ⟨false, true, true, false, false⟩ == Route.errorAnalysis

/--
**NON-REDUNDANCY, as a theorem.** No input makes two different hooks emit. This is what the
Socio asked for: the three are not merely *intended* to be disjoint, they cannot overlap for
any observation whatsoever.
-/
theorem at_most_one_hook_speaks (s : Signals) (a b : Route)
    (ha : emits a s = true) (hb : emits b s = true) : a = b := by
  simp [emits] at ha hb
  exact ha ▸ hb ▸ rfl

/--
**TOTALITY -- the theorem that stops the one above being vacuous.** A router that never
speaks satisfies exclusivity perfectly and is useless. So: any turn carrying a real signal,
and not a deliberate control, reaches one of the three.
-/
theorem every_signal_is_routed (s : Signals)
    (hc : s.control = false) (hs : failing s || s.swallow = true) :
    route s ≠ Route.silent := by
  -- Signals is five Bools: an exhaustive split is a complete case analysis, not a sample.
  cases s with
  | mk he ht hse hsw hcl =>
    cases he <;> cases ht <;> cases hse <;> cases hsw <;> cases hcl <;>
      simp_all [route, failing]

/-- A deliberate negative control NEVER triggers a diagnostic, whatever else it looks like.
    `controlRun` has every other flag set and still routes to silence. -/
theorem a_firing_control_is_never_an_incident (s : Signals) (h : s.control = true) :
    route s = Route.silent := by simp [route, h]

/-- Escalation is monotone: the same failure, once seen, moves from the fast path to the
    systemic one and never back. Prevents the loop where triage keeps re-running. -/
theorem a_repeat_never_goes_back_to_triage (s : Signals)
    (hc : s.control = false) (hf : failing s = true) (hs : s.seen = true) :
    route s = Route.errorAnalysis := by simp [route, hc, hf, hs]

/-- A first sighting is never escalated -- a taxonomy is the wrong response to one failure. -/
theorem a_first_sighting_gets_the_fast_path (s : Signals)
    (hc : s.control = false) (hf : failing s = true) (hs : s.seen = false) :
    route s = Route.smartDebug := by simp [route, hc, hf, hs]

/--
**The instrumentation hook only fires when the other two are BLIND.** error-trace is
reserved for the case where nothing failed: if a real failure is visible, the diagnostics
that read it take precedence. Without this, every `2>/dev/null` in a failing command would
drown the actual error.
-/
theorem instrumentation_yields_to_a_live_failure (s : Signals)
    (hc : s.control = false) (hf : failing s = true) : route s ≠ Route.errorTrace := by
  cases hs : s.seen <;> simp [route, hc, hf, hs]

/-- Silence is only for a control, or for a turn with no signal at all. The router cannot
    swallow a signal by accident -- the contrapositive of totality, stated directly. -/
theorem silence_means_no_signal (s : Signals) (h : route s = Route.silent) :
    s.control = true ∨ (failing s = false ∧ s.swallow = false) := by
  cases s with
  | mk he ht hse hsw hcl =>
    cases he <;> cases ht <;> cases hse <;> cases hsw <;> cases hcl <;>
      simp_all [route, failing]

/-! ## Lean's GREEN failures, and why a generic error hook cannot see them

A coding error is a non-zero exit. Lean's most dangerous failures are **exit 0**: the build is
green, the compiler is content, and the theorem is worthless. Measured on this machine before
these signals existed: a killed mutant routed to /error-analysis (nine false alarms per sweep,
on the healthiest possible result), while `sorryAx` routed to silence.

Four green shapes, in descending certainty:

  `sorryAx`        proof admitted. Never legitimate.
  `survived > 0`   no mutation kills the theorem -- vacuous.
  `discarded > 0`  the patch never applied. A claim about the HARNESS, not the theorem;
                   folding it into "survived" is how a mutation suite lies reassuringly.
  `axioms = []`    rests on nothing. USUALLY vacuous, but `theorem t : 2+2=4 := rfl` is
                   axiom-free and sound, so this one fires to ASK, never to assert.

`a_healthy_sweep_is_never_an_incident` is the anti-cry-wolf property, and
`a_survivor_is_never_muted_by_a_healthy_word` is the one that matters most: the same output
line carries both "killed=8" and "survived=1". Suppressing it on the healthy word would trade
a false alarm for a FALSE SILENCE, which is strictly worse. Found by a control, not by reading.
-/

/-- The green-failure signals, all observable while the build exits 0. -/
structure Green where
  sorryAx : Bool
  survivors : Nat
  discarded : Nat
  axiomFree : Bool
  /-- healthy mutation vocabulary: "killed", "applied=", "restore_identical" -/
  healthyWords : Bool
deriving DecidableEq, Repr

/-- A green turn needs attention iff at least one real green signal is present. The healthy
    words are NOT a signal -- they are the noise this must see through. -/
def greenAlarm (g : Green) : Bool :=
  g.sorryAx || (g.survivors > 0) || (g.discarded > 0) || g.axiomFree

def healthySweep : Green := ⟨false, 0, 0, false, true⟩
def sweepSurvivor : Green := ⟨false, 1, 0, false, true⟩
def sweepDiscard  : Green := ⟨false, 0, 1, false, true⟩
def admittedProof : Green := ⟨true,  0, 0, false, false⟩
def restsOnNothing : Green := ⟨false, 0, 0, true, false⟩

#guard greenAlarm healthySweep   == false
#guard greenAlarm sweepSurvivor  == true
#guard greenAlarm sweepDiscard   == true
#guard greenAlarm admittedProof  == true
#guard greenAlarm restsOnNothing == true

/--
**ANTI-CRY-WOLF.** A sweep that kills every mutant is the healthiest result obtainable, and
must never raise an alarm. Nine false alarms per sweep is how an alarm gets muted, and a muted
alarm is worse than none.
-/
theorem a_healthy_sweep_is_never_an_incident (g : Green)
    (hs : g.sorryAx = false) (hv : g.survivors = 0) (hd : g.discarded = 0)
    (ha : g.axiomFree = false) : greenAlarm g = false := by
  simp [greenAlarm, hs, hv, hd, ha]

/--
**NO FALSE SILENCE -- the theorem that cost a regression to learn.** The healthy words and a
real survivor arrive on the SAME line ("applied=9 killed=8 survived=1"). Suppressing the line
because it looks healthy mutes a vacuous theorem. Whatever the healthy vocabulary says, a
survivor still alarms.
-/
theorem a_survivor_is_never_muted_by_a_healthy_word (g : Green) (h : g.survivors > 0) :
    greenAlarm g = true := by simp [greenAlarm, h]

/-- Same guarantee for a discarded mutation: a harness that could not apply its patch has told
    you nothing, and must not be reported as a theorem that survived. -/
theorem a_discard_is_never_muted (g : Green) (h : g.discarded > 0) :
    greenAlarm g = true := by
  simp [greenAlarm]; omega

/-- An admitted proof always alarms, whatever else is true of the turn. -/
theorem an_admitted_proof_always_alarms (g : Green) (h : g.sorryAx = true) :
    greenAlarm g = true := by simp [greenAlarm, h]

/-- `axioms = []` alarms too -- weakly, but it is never silently dropped. -/
theorem an_axiom_free_theorem_is_surfaced (g : Green) (h : g.axiomFree = true) :
    greenAlarm g = true := by simp [greenAlarm, h]

/-- Silence on a green turn means every signal was genuinely absent. The router cannot lose one. -/
theorem green_silence_means_all_clear (g : Green) (h : greenAlarm g = false) :
    g.sorryAx = false ∧ g.survivors = 0 ∧ g.discarded = 0 ∧ g.axiomFree = false := by
  simp_all [greenAlarm]

/-! ## NON-CONTAMINATION -- the hooks must not change what they observe

The Socio's third requirement, and the one that would be easiest to get wrong silently. A hook
runs on EVERY tool call. If it could alter a tool's exit code, its stdout, or any file under the
work tree, then every measurement taken afterwards would be measuring the observer.

Modelled as: a hook's effect on the world is a `HookEffect`, and the only writes it may perform
are to its own cache. `observation_is_unchanged` is the theorem; the empirical counterpart is
that the three scripts `exit 0` unconditionally and write only under `~/.claude/cache`.
-/

/-- What a hook could touch. `writesWorkTree` is the contamination we must exclude. -/
structure HookEffect where
  /-- the exit code the hook itself returns -/
  exit : Nat
  /-- does it write anywhere under the project / proof tree? -/
  writesWorkTree : Bool
  /-- does it write its own cache under ~/.claude/cache? -/
  writesOwnCache : Bool
deriving DecidableEq, Repr

/-- The measured effect of all three hooks. Verified empirically alongside this proof. -/
def actualEffect : HookEffect := ⟨0, false, true⟩

/-- A hook is non-contaminating when it cannot fail and cannot write the work tree. -/
def nonContaminating (e : HookEffect) : Bool := (e.exit == 0) && !e.writesWorkTree

#guard nonContaminating actualEffect == true
-- a hook that wrote the work tree, or could fail, would NOT qualify:
#guard nonContaminating ⟨0, true, true⟩ == false
#guard nonContaminating ⟨1, false, true⟩ == false

/--
**NON-CONTAMINATION.** The hooks leave every observation intact: a tool's exit code and the work
tree are exactly what they would have been unobserved. Their own cache is excluded deliberately
-- state kept OUTSIDE the measured tree is what makes the memo possible without touching it.
-/
theorem observation_is_unchanged : nonContaminating actualEffect = true := by decide

/-- Stated generally, so it stays true if the effect is ever remeasured: writing the work tree
    is sufficient to disqualify a hook, whatever else it does right. -/
theorem writing_the_work_tree_is_always_contamination (e : HookEffect)
    (h : e.writesWorkTree = true) : nonContaminating e = false := by
  simp [nonContaminating, h]

/-- And a hook that can FAIL is contamination too: a non-zero hook exit can block or alter the
    tool call it was only supposed to watch. An observer must not be able to veto. -/
theorem a_hook_that_can_fail_is_contamination (e : HookEffect) (h : e.exit ≠ 0) :
    nonContaminating e = false := by
  simp [nonContaminating]; omega

end CtbrecSpec.ErrorDiagRouting
