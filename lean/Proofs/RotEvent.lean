/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# Eleven events, and a log that can name which one fired

Two defects measured on 2026-08-08, both about the same thing: the router could
not account for itself.

## One: the router was bound to three of eleven lifecycle events

RoT MoE is a router, and it shipped registered on `UserPromptSubmit`,
`PreToolUse` and `PostToolUse` only. Eight events -- `SessionStart`, `Stop`,
`SessionEnd`, `Notification`, `SubagentStop`, `PreCompact`,
`UserPromptExpansion`, `PostCompact` -- had no binding at all. A router that
observes three of eleven events is sampling a session, not routing one, and
every A/B measurement taken against that build was measuring a partially
installed product.

## Two: the debug log did not record WHICH event produced a record

Six records from a live session -- three gauges, three routes -- were
indistinguishable from each other. Nothing in the record said whether it came
from `SessionStart`, a tool call, or `Stop`. So the claim "the router now
observes eleven events" was **unfalsifiable from the log**, which is the same
defect this project hunts everywhere else: an instrument that cannot disagree
with you.

The repair adds an `event` field to every route record in both arms. Because
that value is interpolated into JSON, it is sanitised: anything that is not
plain letters becomes `"-"`. This module is the specification of that sanitiser
and of the coverage claim.

`checker/debug-channel.sh` is the executable half -- it runs the SHIPPED hooks
and diffs the observable. A theorem about `sanitise` constrains
`hooks/rot-router.sh` through nothing unless a checker binds the two.
-/

namespace RotMoE.Event

/-! ## The declared events -/

/-- The eleven lifecycle events RoT MoE binds, in the order the manifest lists
them. Counted from every `hooks.json` and `settings.json` on the measuring
machine -- not recalled. -/
def declared : List String :=
  ["UserPromptSubmit", "UserPromptExpansion", "PreToolUse", "PostToolUse",
   "SessionStart", "SessionEnd", "Stop", "SubagentStop", "Notification",
   "PreCompact", "PostCompact"]

/-- What the router was bound to before 2026-08-08. -/
def boundBefore : List String :=
  ["UserPromptSubmit", "PreToolUse", "PostToolUse"]

/-! ## The sanitiser

The shipped guard, in both arms, is "every character is an ASCII letter, else
`-`". `hooks/rot-router.sh` spells it `case "$_ev" in (*[!A-Za-z]*|'') _ev='-'`
and `hooks/rot-router.ps1` spells it `$cand -match '^[A-Za-z]+$'`. -/

/-- An ASCII letter. -/
def isLetter (c : Char) : Bool :=
  ('A' ≤ c && c ≤ 'Z') || ('a' ≤ c && c ≤ 'z')

/-- The sanitiser: a name of one-or-more letters passes through; anything else
-- empty, or containing any non-letter -- becomes `"-"`. -/
def sanitise (s : String) : String :=
  if !s.toList.isEmpty && s.toList.all isLetter then s else "-"

/-! ## What the sanitiser guarantees -/

/-- THE SAFETY PROPERTY. The output is either the literal `"-"` or a string of
letters only. Nothing else can ever reach the JSON record, which is what stops a
hostile `hook_event_name` from closing the string and injecting fields. -/
theorem sanitise_is_safe (s : String) :
    sanitise s = "-" ∨ (sanitise s).toList.all isLetter := by
  unfold sanitise
  split
  · rename_i h
    exact Or.inr (Bool.and_eq_true .. |>.mp h).2
  · exact Or.inl rfl

/-- THE GENERAL REFUSAL. Any name containing a non-letter is replaced, whatever
the non-letter is. Stated over an arbitrary string with the property as a
hypothesis, so it does not expire when a new hostile shape is discovered. -/
theorem non_letter_is_refused (s : String) (h : s.toList.all isLetter = false) :
    sanitise s = "-" := by
  unfold sanitise
  simp [h]

/-- The concrete injection that was actually fired at the running hooks:
`Evil","lane":"PWNED`. Both arms recorded `-`, no malformed line was written and
no `lane` was overridden. This is the measured case, pinned as a theorem so the
general statement above is anchored to a real attack rather than to my
imagination of one. -/
theorem quote_payload_is_refused :
    (sanitise "Evil\",\"lane\":\"PWNED" == "-") = true := by
  rfl

/-- THE UNIVERSAL INJECTION REFUSAL. A quote ANYWHERE in the event name is
refused, whatever surrounds it -- not merely the one payload that was fired at
the running hooks.

This is the theorem the first version of this module failed to prove and
recorded as a disclosed weakening: the general form was replaced by
`non_letter_is_refused` plus the single decided instance below. That was honest
but it was not the claim, and a weakened claim left standing is exactly what the
governing rules forbid. The gap was a missing lemma name, not a missing fact --
`String.toList_append` and `List.all_append` close it. -/
theorem quote_is_refused (pre post : String) :
    sanitise (pre ++ "\"" ++ post) = "-" := by
  apply non_letter_is_refused
  rw [String.toList_append, String.toList_append, List.all_append, List.all_append]
  have hq : "\"".toList.all isLetter = false := by decide
  rw [hq]
  simp

/-- NON-VACUITY. The sanitiser is not the constant function `"-"`; a real event
name survives it unchanged. Without this, `sanitise_is_safe` would be satisfied
by a sanitiser that destroys everything. -/
theorem sanitise_is_not_constant :
    (sanitise "SessionStart" == "SessionStart") = true := by
  rfl

/-- Every declared event survives the sanitiser unchanged. If this failed, the
guard would be silently erasing the identity of a real event -- the log would
say `-` for an event that genuinely fired, which is a false negative in the
exact instrument added to prevent them. -/
theorem every_declared_event_survives :
    declared.all (fun e => sanitise e == e) = true := by
  rfl

/-! ## What the coverage claim says -/

/-- Eleven, and this is the number the manifest, `ARM_ROUTER.sh` and
`ARM_ROUTER.ps1` are asserted to agree on. -/
theorem declared_count : declared.length = 11 := by rfl

/-- Deduplication, written out rather than imported, so this module depends on
no library name that could move under it. -/
def dedup (l : List String) : List String :=
  l.foldl (fun acc x => if acc.contains x then acc else acc ++ [x]) []

/-- No event is registered twice. A duplicate would double-fire the router on
that event -- the exact defect `checker/router-duplication.sh` exists to catch,
arriving through the manifest instead of through a stacked install. -/
theorem declared_has_no_duplicates : (dedup declared).length = 11 := by
  rfl

/-- THE DEFECT, stated as a theorem: what the router used to bind is a strict
subset of what it binds now. -/
theorem old_binding_was_a_subset :
    boundBefore.all (fun e => declared.contains e) = true := by rfl

/-- Eight events had no binding at all. This is the size of the blind spot, and
it is the reason every prior A/B measured a partially installed router. -/
theorem eight_events_were_unbound :
    (declared.filter (fun e => !boundBefore.contains e)).length = 8 := by rfl

/-! ## The property that must survive a growing list

`checker/install-roundtrip.sh` and `checker/router-duplication.sh` both used to
name a CONTINGENT FACT -- "SessionStart is untouched", "the count is 2" -- and
both went red on a correct change. The durable statement is quantified over the
declared list instead of naming its current members. -/

/-- An event outside the declared list is not bound, whatever the list contains.
Stated over an arbitrary list and an arbitrary event, so it cannot expire the
way the two checkers did. -/
theorem undeclared_is_not_bound (evs : List String) (e : String)
    (h : evs.contains e = false) : ¬ (evs.contains e = true) := by
  intro hc; rw [h] at hc; exact Bool.noConfusion hc

/-- One registration per declared event, and the expected entry count is the
length of the list -- not a literal. This is the shape `router-duplication.sh`
now reads from `ARM_ROUTER.sh` at run time. -/
theorem entries_equal_declared_count (evs : List String) :
    (evs.map (fun _ => 1)).length = evs.length := by
  simp

/-! ## Executable agreement with the shipped hooks -/

#guard sanitise "Stop" == "Stop"
#guard sanitise "" == "-"
#guard sanitise "Stop-1" == "-"
#guard sanitise "Evil\",\"lane\":\"PWNED" == "-"
#guard declared.length == 11
#guard (declared.filter (fun e => !boundBefore.contains e)).length == 8

end RotMoE.Event
