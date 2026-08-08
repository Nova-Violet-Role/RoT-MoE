/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# Being wired to an event is not permission to speak on it

Measured 2026-08-09, minutes after the global config was wired to all 31 CLI hook
events. A live session ended and the CLI answered:

    SessionEnd hook [pwsh -File ...\rot-lean-inject.ps1 -Event *] failed:
    Hook JSON output validation failed - (root): Invalid input

Three hooks emit `hookSpecificOutput.additionalContext` tagged with whatever
event invoked them. Echoing the true event is CORRECT and must not change -- a
hardcoded label is the worse bug, and the hook that failed says so in its own
comments. What was wrong is narrower: the CLI accepts `additionalContext` on only
SOME events, so a hook wired to all 31 emits schema-invalid JSON on the rest.

## What this file proves, and what it deliberately refuses to freeze

The safety property is universal and cannot expire:

    no event outside the accepting set ever emits.

The membership of that set is a MEASURED FACT ABOUT ONE CLI VERSION, and the CLI
will add context-accepting events. So the roster lives in `#guard`s that document
today, never in a load-bearing hypothesis. A theorem saying "the set has exactly
six members" would be green now and would go red on a correct future CLI upgrade,
and the obvious repair -- deleting it -- destroys the coverage. That is the defect
shape this project has been bitten by before; it is not repeated here.

The second property is the one that keeps the fix from being a disarming:

    every accepting event STILL emits.

A gate that silenced everything would also make the error disappear. It would
also be a violation. Both directions are proved, and both were measured live
before they were stated: old code emitted 2223 bytes on SessionEnd, new code
emits 0, and PostToolUse still emits 2224.

## Evidence for the accepting set (two independent instruments)

* claude.exe 2.1.226 schema string table, adjacent to `additionalContext`:
  SessionStart, UserPromptSubmit, UserPromptExpansion.
* Observed accepted in a live transcript: PreToolUse, PostToolUse, PostToolBatch.
* Observed REJECTED live: SessionEnd.
-/

import Proofs.RotEvent

namespace RotMoE.Inject

open RotMoE.Event

/-- The events whose CLI schema accepts `hookSpecificOutput.additionalContext`.
Measured against claude.exe 2.1.226; expected to GROW as the CLI grows, which is
why no theorem below depends on its length. -/
def accepting : List String :=
  ["PreToolUse", "PostToolUse", "PostToolBatch",
   "SessionStart", "UserPromptSubmit", "UserPromptExpansion"]

/-- The gate the three PowerShell hooks now implement:
`if ($Event -notin $ctxEvents) { exit 0 }`. -/
def emits (e : String) : Bool := accepting.contains e

/-- The label the payload carries. Modelled as the identity because the gate must
never rewrite it -- rewriting the label is the older, worse defect this project
already fixed once, and the gate is placed AFTER label resolution precisely so it
cannot reintroduce it. -/
def labelOf (e : String) : String := e

/-! ## The safety property: silence outside the accepting set -/

/-- The gate is exactly membership -- no hidden third behaviour, no event that is
neither emitted nor refused. Everything below is a corollary of this one fact,
which is why the gate cannot acquire a special case without this file going red. -/
theorem emits_iff_accepted (e : String) : emits e = true ↔ e ∈ accepting :=
  List.contains_iff_mem

/-- Emission implies membership: if anything comes out, the CLI accepts it. -/
theorem emission_implies_accepted (e : String) (h : emits e = true) :
    e ∈ accepting :=
  (emits_iff_accepted e).mp h

/-- **The universal claim.** No event outside the accepting set can emit, for any
string whatsoever -- including events that do not exist yet. This is what makes
the invalid-JSON error unreachable rather than merely unobserved. -/
theorem no_emission_outside_accepting (e : String) (h : e ∉ accepting) :
    emits e = false := by
  cases hb : emits e with
  | false => rfl
  | true => exact absurd (emission_implies_accepted e hb) h

/-! ## The anti-disarming property: the working lanes still speak -/

/-- **Every accepting event still emits.** A gate that returned `false`
everywhere would silence the error too, and would be a disarming rather than a
fix. This theorem is what separates the two. -/
theorem accepting_still_emits (e : String) (h : e ∈ accepting) :
    emits e = true :=
  (emits_iff_accepted e).mpr h

/-! ## The label is never rewritten -/

/-- The payload always names the invoking event. Quantified over every string, so
it cannot be satisfied by a lucky constant. -/
theorem label_is_the_invoking_event (e : String) : labelOf e = e := rfl

/-- Stated where it bites: an emitted payload carries the invoking event's own
name AND that name is one the CLI accepts. Together these are exactly the two
conditions the CLI validates. -/
theorem emitted_payload_is_valid (e : String) (h : emits e = true) :
    labelOf e = e ∧ e ∈ accepting :=
  ⟨rfl, emission_implies_accepted e h⟩

/-! ## The set is drawn from real events -/

/-- Every accepting event is one of the 31 events the CLI actually dispatches.
This is the typo catcher: a misspelled name in the PowerShell `$ctxEvents` array
would silently disable injection on a lane that works, and nothing else would
notice. `declared` comes from `Proofs.RotEvent`, so there is one roster, not two. -/
theorem accepting_are_real_events :
    accepting.all (fun e => declared.contains e) = true := by
  decide

/-- The complement is non-empty: there really are events that must stay silent.
Without this the safety theorem could be vacuously satisfied by an accepting set
that swallowed everything. -/
theorem some_events_are_refused :
    (declared.filter (fun e => !emits e)) ≠ [] := by
  decide

/-! ## What is true TODAY (documentation, not hypotheses)

These are `#guard`s on purpose. Each is a fact about claude.exe 2.1.226 that a
correct future CLI may falsify, and none of the theorems above depends on them. -/

-- Six accepting events at the version measured.
#guard accepting.length = 6

-- 25 of the 31 wired events must stay silent -- the ~25 invalid payloads per
-- session that the gate removes.
#guard (declared.filter (fun e => !emits e)).length = 25

-- The live rejection that started this: SessionEnd is refused.
#guard emits "SessionEnd" = false

-- The live acceptances, one per instrument.
#guard emits "PostToolUse" = true
#guard emits "PreToolUse" = true
#guard emits "PostToolBatch" = true
#guard emits "SessionStart" = true
#guard emits "UserPromptSubmit" = true
#guard emits "UserPromptExpansion" = true

-- An event the CLI dispatches but which does not accept context.
#guard emits "ConfigChange" = false
#guard emits "Stop" = false

-- A name that is not an event at all is refused, so a typo fails closed.
#guard emits "PostToolUseX" = false
#guard emits "" = false

-- The accepting set has no duplicates -- a repeated entry would mean the
-- PowerShell array and this model had drifted.
#guard (dedup accepting).length = accepting.length

end RotMoE.Inject
