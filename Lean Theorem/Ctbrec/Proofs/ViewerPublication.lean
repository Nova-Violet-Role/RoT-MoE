/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: PUBLISHING a viewer count, as opposed to harvesting one.

MEASURED 2026-08-13, on the Socio's report "everything stay at 0":

    grep -c "viewer" ctbrec.log                                        -> 10276
    "getViewerCount on ChaturbateModel returned non-numeric null -- treating as unknown"   (x thousands)

`ViewerCountProbe.KEYS` was fixed days earlier and is correct; the harvest was never the problem.
`ChaturbateModel.viewerCount` was only ever assigned inside `requestStreamInfo()`, a call the TAB
path never makes — so every freshly listed model reported UNKNOWN, while the room-list response the
tab had just parsed carried `num_users` for each room. The number was measured, received, and thrown
away one method from where the UI needed it.

This file fixes the PUBLICATION rule, which is where the race lives: tab refreshes and stream-info
calls both write the field, and a refresh whose payload happens to omit the field must not blank a
count already on screen.

NOT PROVED: that any particular payload contains a count (that is `ViewerCountProbe`'s job and
`ViewerHarvest.lean`'s), nor that the UI draws it. What IS proved: no measurement is ever lost, and
unknown never overwrites known.
-/

namespace Proofs.Ctbrec.ViewerPublication

/-- A count, or `none` for UNKNOWN. `some 0` is a measurement of zero, NOT absence. -/
abbrev Count := Option Nat

/-- Mirror of `ChaturbateModel.setViewerCount`: a null incoming value leaves the field alone. -/
def publish (current incoming : Count) : Count :=
  match incoming with
  | some n => some n
  | none => current

/-! ## Part 1 — the laws that make the race safe -/

/--
THE DEFECT'S OPPOSITE. A count already known is never downgraded to unknown by a later payload that
omits the field — which is what a naive `viewerCount = probe(...)` assignment would do on every
refresh, making the number flicker in and out.
-/
theorem a_known_count_is_never_overwritten_by_unknown (n : Nat) :
    publish (some n) none = some n := by
  rfl

/-- A fresh measurement always wins: the count follows the newest number, not the first. -/
theorem a_new_measurement_replaces_the_old (old new : Nat) :
    publish (some old) (some new) = some new := by
  rfl

/-- Publication is what turns UNKNOWN into a number. This is the row that was missing. -/
theorem a_measurement_resolves_unknown (n : Nat) : publish none (some n) = some n := by
  rfl

/-- A MEASURED zero is published like any other number — 0 viewers is a fact, not an absence. -/
theorem a_measured_zero_is_published : publish none (some 0) = some 0 := by
  rfl

/-- With no measurement at all, unknown stays unknown; nothing is invented. -/
theorem unknown_without_a_measurement_stays_unknown : publish none none = none := by
  rfl

/-- Publication never fabricates: whatever comes out was either already there or just measured. -/
theorem publication_invents_nothing (c i : Count) : publish c i = c ∨ publish c i = i := by
  cases i with
  | none => exact Or.inl rfl
  | some n => exact Or.inr rfl

/-- Once known, always known: no sequence of publications can return the field to unknown. -/
theorem knownness_is_monotone (c i : Count) (h : c.isSome) : (publish c i).isSome := by
  cases i with
  | none => simpa [publish] using h
  | some n => simp [publish]

/-- Folding a whole stream of refreshes: knownness survives every one of them. -/
theorem knownness_survives_a_stream (start : Count) (updates : List Count) (h : start.isSome) :
    (updates.foldl publish start).isSome := by
  induction updates generalizing start with
  | nil => simpa using h
  | cons u us ih => exact ih (publish start u) (knownness_is_monotone start u h)

/-! ## Part 2 — the two wrong implementations, as executable mutants -/

/-- What a naive refresh does: assign the probe result unconditionally. Loses known counts. -/
def publishNaive (_current incoming : Count) : Count := incoming

theorem the_naive_assignment_loses_a_known_count :
    ∃ n : Nat, publishNaive (some n) none ≠ some n := by
  exact ⟨7, by simp [publishNaive]⟩

/-- The other error: never update, so a count is frozen at its first value. -/
def publishFrozen (current _incoming : Count) : Count := current

theorem freezing_ignores_a_new_measurement :
    ∃ (old new : Nat), publishFrozen (some old) (some new) ≠ some new := by
  refine ⟨1, 2, ?_⟩
  simp [publishFrozen]

/-! ## Part 3 — where the count comes from, structurally

Modelled as a payload that either carries a count or does not; the KEY names live in
`ViewerHarvest.lean` and deliberately not here.
-/

structure Payload where
  hasCount : Bool
  count : Nat
  deriving DecidableEq, Repr

def harvest (p : Payload) : Count := if p.hasCount then some p.count else none

/-- The room-list payload the tab already parsed is sufficient: no extra request is needed. -/
theorem a_payload_with_a_count_publishes_it (p : Payload) (h : p.hasCount = true) :
    publish none (harvest p) = some p.count := by
  simp [harvest, publish, h]

/-- And a payload without one leaves an existing count untouched rather than blanking the cell. -/
theorem a_payload_without_a_count_preserves_the_old (p : Payload) (n : Nat)
    (h : p.hasCount = false) : publish (some n) (harvest p) = some n := by
  simp [harvest, publish, h]

/-! ## Today's measured payloads — `#guard` only -/

-- The room object the tab receives, as measured: `num_users` present.
#guard publish none (harvest ⟨true, 1720⟩) == some 1720
#guard publish (some 1720) (harvest ⟨false, 0⟩) == some 1720   -- a refresh that omits it
#guard publish (some 1720) (harvest ⟨true, 1735⟩) == some 1735 -- a refresh that updates it
#guard publish none (harvest ⟨true, 0⟩) == some 0              -- measured zero renders
#guard publish none (harvest ⟨false, 99⟩) == none              -- absent stays unknown
#guard ([some 3, none, none].foldl publish none) == some 3
#guard ([none, none].foldl publish none) == none

end Proofs.Ctbrec.ViewerPublication
