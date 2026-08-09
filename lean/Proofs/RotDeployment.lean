/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# Patching a copy proves nothing about the program that is running

Measured 2026-08-09 against the live production instance, and it cost an hour.

Production's debug log was still emitting route records with **no `src` and no
`session` field** -- the shape the old router produced. The repair looked
obvious: find the deployed router and replace it with the fixed build. So:

| copy | before | after the patch | records still bare? |
|---|---|---|---|
| `~/.claude/.../rot-moe/1.0.1/hooks/rot-router.ps1` | 18048 B | 24462 B | yes |
| `~/.claude/.../rot-moe/0.7.1/hooks/rot-router.ps1` | 18048 B | 24462 B | yes |
| `~/.claude/.../rot-moe/0.6.1/hooks/rot-router.ps1` | 18048 B | 24462 B | yes |
| `Desktop/RoT-MoE 1.0.1-Lean/hooks/rot-router.ps1`  | 18048 B | (probed) | yes |
| `Desktop/RoT-MoE 0.7.1-Lean/hooks/rot-router.ps1`  | 18048 B | (probed) | yes |

Every known copy on the machine was the fixed build, driving any of them by
hand produced `"src":"hook"` correctly, and the live log kept writing bare
records the whole time.

## The step that ended it

An **execution marker**: one line at the top of the file appending a timestamp
to a side file. The live log gained records at 09:29:56 while the marker file
stayed EMPTY. That single observation settles what five file patches could not
-- the file being edited is not the file being run.

## Why this needed a theorem and not just a note

The reasoning I was doing was invalid, and it is invalid in a way that feels
compelling: "I patched it and the output did not change, so the patch must be
wrong." `absent_field_does_not_identify_the_cause` exhibits two worlds that
produce the SAME observation from opposite causes -- an unpatched running copy
and a patched dormant one. No amount of re-patching separates them; only an
observation of execution does.

`emitter_is_outside_the_known_set` is the conclusion actually licensed by the
measurement, and it is weaker than "the router is broken": every copy I know
about is patched and dormant, therefore whatever writes those records is not
in my set. That is an honest open alarm, not a fix, and it is recorded as one.

The same shape has bitten this repo twice before in different clothes: a
mutation whose patch silently failed to apply, and a checker reading a log the
router never wrote to. All three are one defect -- **acting on an artefact
without confirming the artefact is the one in play**.
-/

namespace RotMoE.Deployment

/-- One copy of a program on disk. `executes` is the fact that is invisible
without an execution marker -- which is the entire lesson. -/
structure Copy where
  path : String
  patched : Bool
  executes : Bool
deriving DecidableEq, Repr

/-- The fixed field appears in the output only if the copy that RUNS carries the
fix. Both conjuncts are needed, and forgetting the second is the defect. -/
def emitsField (c : Copy) : Bool := c.patched && c.executes

def anyEmits (cs : List Copy) : Bool := cs.any emitsField

section TheDefect

/-- Patching a copy that does not run changes nothing observable. -/
theorem patching_a_dormant_copy_changes_nothing (p : String) (b : Bool) :
    emitsField ⟨p, b, false⟩ = false := by
  simp [emitsField]

/-- THE LOAD-BEARING ONE. The observation "the field is absent" is produced by
two OPPOSITE causes, so it cannot distinguish them. Exhibited, not asserted. -/
theorem absent_field_does_not_identify_the_cause :
    ∃ a b : Copy,
      emitsField a = emitsField b ∧
      a.patched ≠ b.patched ∧
      a.executes ≠ b.executes := by
  refine ⟨⟨"running-but-old", false, true⟩, ⟨"patched-but-dormant", true, false⟩,
    by decide, by decide, by decide⟩

/-- So re-patching cannot settle it: a dormant copy stays silent however many
times it is repaired. This is the loop the hour was lost in. -/
theorem repatching_a_dormant_copy_is_a_fixed_point (p : String) :
    emitsField ⟨p, true, false⟩ = emitsField ⟨p, false, false⟩ := by
  simp [emitsField]

end TheDefect

section TheDiscriminator

/-- An execution marker observes `executes` DIRECTLY, independently of whether
the copy is patched. That independence is what makes it a discriminator. -/
def markerFires (c : Copy) : Bool := c.executes

theorem marker_is_blind_to_patching (p : String) (e : Bool) :
    markerFires ⟨p, true, e⟩ = markerFires ⟨p, false, e⟩ := rfl

/-- And it separates exactly the pair that the output could not. -/
theorem marker_separates_the_indistinguishable_pair :
    markerFires ⟨"running-but-old", false, true⟩ ≠
    markerFires ⟨"patched-but-dormant", true, false⟩ := by decide

/-- A silent marker on a patched copy is conclusive: that copy is not running. -/
theorem silent_marker_means_dormant (c : Copy) (h : markerFires c = false) :
    c.executes = false := h

end TheDiscriminator

section TheInstrumentThatCannotRun

/-! ## The correction: the first marker run was INVALID

Added after the fact, because the first version of this file shipped a
conclusion supported by a broken experiment. The marker was inserted at line 2
of a PowerShell script whose lines 22-23 are `[CmdletBinding()]` / `param(`.
PowerShell requires `param` to be the first statement, so the instrumented file
**did not parse** -- measured: `PARSE_FAILS: Unexpected attribute
'CmdletBinding'`. `pwsh -File` then exits non-zero and the hook's `|| bash`
fallback takes over.

So the marker was silent because the program was broken, not because it was
dormant. Two causes, one observation -- the very confusion this module was
written about, committed *inside the module about it*.

Redone properly (marker after the param block, `PARSE_OK` verified **while
instrumented**, positive control fired on a hand-driven invocation) the marker
stayed silent while records kept arriving. The conclusion survived; the
evidence for it had to be rebuilt. -/

/-- A probe over a program: it is only evidence if the instrumented program
still runs. `fires` is what you observe; `instrumentedRuns` is the precondition
almost nobody checks. -/
structure Probe where
  instrumentedRuns : Bool
  targetExecutes : Bool
deriving DecidableEq, Repr

/-- What the probe actually shows: nothing at all unless the instrumented
program can still run. -/
def probeFires (p : Probe) : Bool := p.instrumentedRuns && p.targetExecutes

/-- A probe that broke its target is silent regardless of the truth it was
meant to measure -- so its silence carries zero information. -/
theorem broken_probe_is_silent_either_way (e : Bool) :
    probeFires ⟨false, e⟩ = probeFires ⟨false, !e⟩ := by
  simp [probeFires]

/-- Stated as the indistinguishability that bit: a broken probe on a RUNNING
target looks exactly like a working probe on a DORMANT one. -/
theorem broken_probe_mimics_a_dormant_target :
    probeFires ⟨false, true⟩ = probeFires ⟨true, false⟩ := by decide

/-- The precondition discharged: once the instrumented program is known to run,
silence does mean the target is dormant. This is the theorem that makes the
second run count where the first did not. -/
theorem silence_is_evidence_once_the_probe_runs (p : Probe)
    (hrun : p.instrumentedRuns = true) (hsilent : probeFires p = false) :
    p.targetExecutes = false := by
  simpa [probeFires, hrun] using hsilent

/-- And the positive control is not optional decoration: a probe that cannot
fire even on a live target is indistinguishable from a broken one. -/
theorem positive_control_is_required :
    probeFires ⟨false, true⟩ = false ∧ probeFires ⟨true, true⟩ = true := by
  decide

end TheInstrumentThatCannotRun

section TheConclusion

/-- What the measurement actually licenses. If every copy in the known set is
patched and none of them emits the field, then none of them is executing --
so the writer is outside the set. Note this concludes about the SET, not about
the router being broken; the stronger claim is not available and is not made. -/
theorem emitter_is_outside_the_known_set (cs : List Copy)
    (hpatched : ∀ c ∈ cs, c.patched = true)
    (hnone : anyEmits cs = false) :
    ∀ c ∈ cs, c.executes = false := by
  intro c hc
  have h1 : emitsField c = false := by
    have := hnone
    simp [anyEmits, List.any_eq_false] at this
    exact this c hc
  have hp : c.patched = true := hpatched c hc
  simpa [emitsField, hp] using h1

/-- The honest converse, kept so the conclusion above cannot be over-read:
a dormant known set does NOT prove the records stopped. Something still wrote
them, and this module does not say what. -/
theorem dormant_set_says_nothing_about_the_writer (cs : List Copy)
    (h : ∀ c ∈ cs, c.executes = false) :
    anyEmits cs = false := by
  simp [anyEmits, List.any_eq_false]
  intro c hc
  simp [emitsField, h c hc]

end TheConclusion

section Measured

/-! The five copies as measured after the repair: every one patched, every one
dormant. Contingent -- when the real emitter is found this list grows. -/

def knownCopies : List Copy :=
  [ ⟨"plugins/cache/rot-moe/rot-moe/1.0.1", true, false⟩
  , ⟨"plugins/cache/rot-moe/rot-moe/0.7.1", true, false⟩
  , ⟨"plugins/cache/rot-moe/rot-moe/0.6.1", true, false⟩
  , ⟨"Desktop/RoT-MoE 1.0.1-Lean",          true, false⟩
  , ⟨"Desktop/RoT-MoE 0.7.1-Lean",          true, false⟩ ]

#guard knownCopies.length = 5
#guard knownCopies.all (fun c => c.patched)
#guard anyEmits knownCopies = false
-- Had ANY of them been the live writer, the field would be present.
#guard anyEmits [⟨"x", true, true⟩] = true
-- The pair the output cannot separate, and the marker can.
#guard emitsField ⟨"a", false, true⟩ = emitsField ⟨"b", true, false⟩
#guard markerFires ⟨"a", false, true⟩ ≠ markerFires ⟨"b", true, false⟩

end Measured

end RotMoE.Deployment
