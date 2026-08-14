/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CP82 -- the gate on the bulk online-rooms endpoint.

The optimisation: instead of polling each followed model separately, fetch one bulk list of online
rooms and decide from it. That is a large reduction in requests (CP81 measured the pacing at
~1.09 req/s globally, so per-model polling is the dominant cost).

THE RISK, and the reason this endpoint stays gated until this file exists: a bulk list is evidence
of PRESENCE, never of ABSENCE. If a model is missing from the response the honest reading is "this
response does not say", not "the model is offline". Treating absence as OFFLINE produces a FALSE
OFFLINE, and a false offline **stops or never starts a recording** -- the stream is lost and cannot
be recovered afterwards. A 429 costs a retry; a missed recording costs the recording. They are not
comparable, so the asymmetry is built into the model rather than left to a comment.

Concrete ways a genuinely-online model is absent from a bulk response, all of them ordinary:
  * pagination -- the list is truncated and the model is on a page never fetched;
  * a filter (region, tag, gender) the endpoint applies by default;
  * eventual consistency -- the room came online after the snapshot was taken;
  * a partial failure that still returns HTTP 200 with a short list.

WHAT IS PROVED: absence from a bulk response NEVER yields `offline`; only a direct per-model check
is authoritative for offline; a recording is never stopped on bulk evidence alone; and the rule
degrades safely -- a truncated or failed response is worth strictly less than a complete one, never
more.

NOT PROVED: that the endpoint exists at a particular URL, its page size, or its latency. Those are
measurements, and they belong in the checker, not here.
-/

namespace CtbrecSpec.BulkOnline

/-- What one poll told us about one model. -/
inductive Evidence
  /-- the model appeared in a bulk online list -/
  | bulkPresent
  /-- the model did NOT appear in a bulk list that we believe was complete -/
  | bulkAbsentComplete
  /-- the model did not appear, and the list was truncated / partial / filtered -/
  | bulkAbsentPartial
  /-- a direct per-model query said online -/
  | directOnline
  /-- a direct per-model query said offline -- the ONLY authoritative negative -/
  | directOffline
deriving DecidableEq, Repr

inductive Status
  | online
  /-- authoritative: it is safe to stop or not start a recording -/
  | offline
  /-- we do not know; keep polling, keep any running recording alive -/
  | unknown
deriving DecidableEq, Repr

/-- The rule. Note that BOTH absence cases yield `unknown`, never `offline`. -/
def status : Evidence → Status
  | .bulkPresent => Status.online
  | .directOnline => Status.online
  | .directOffline => Status.offline
  | .bulkAbsentComplete => Status.unknown
  | .bulkAbsentPartial => Status.unknown

/-- A recording may be stopped only on an authoritative offline. -/
def mayStopRecording (e : Evidence) : Bool := status e == Status.offline

/-- Whether a direct per-model check is still required before believing a model is offline. -/
def needsDirectCheck (e : Evidence) : Bool := status e == Status.unknown

#guard status Evidence.bulkPresent == Status.online
#guard status Evidence.bulkAbsentComplete == Status.unknown
#guard status Evidence.bulkAbsentPartial == Status.unknown
#guard status Evidence.directOffline == Status.offline
#guard mayStopRecording Evidence.bulkAbsentComplete == false
#guard mayStopRecording Evidence.bulkAbsentPartial == false
#guard mayStopRecording Evidence.directOffline == true
#guard needsDirectCheck Evidence.bulkAbsentComplete == true
#guard needsDirectCheck Evidence.bulkPresent == false

/--
**The gate.** No bulk evidence, of any kind, ever yields `offline`. This is the theorem CP82 was
waiting on: it is what makes a false OFFLINE from the bulk endpoint impossible by construction
rather than by care.
-/
theorem bulk_evidence_never_yields_offline :
    ∀ e : Evidence,
      e = Evidence.bulkPresent ∨ e = Evidence.bulkAbsentComplete ∨ e = Evidence.bulkAbsentPartial →
      status e ≠ Status.offline := by
  intro e h
  rcases h with rfl | rfl | rfl <;> simp [status]

/-- Only a direct per-model check is authoritative for offline. -/
theorem only_a_direct_check_is_authoritative_for_offline :
    ∀ e : Evidence, status e = Status.offline → e = Evidence.directOffline := by
  intro e h
  cases e <;> simp [status] at h ⊢

/-- **A recording is never stopped on bulk evidence.** The consequence that actually costs data. -/
theorem a_recording_is_never_stopped_on_bulk_evidence :
    mayStopRecording Evidence.bulkAbsentComplete = false ∧
    mayStopRecording Evidence.bulkAbsentPartial = false ∧
    mayStopRecording Evidence.bulkPresent = false := by
  decide

/-- Absence always demands a direct check before anything is concluded. -/
theorem absence_always_demands_a_direct_check :
    needsDirectCheck Evidence.bulkAbsentComplete = true ∧
    needsDirectCheck Evidence.bulkAbsentPartial = true := by
  decide

/--
**Anti-disarm, and the reason `bulkAbsentPartial` exists as a separate constructor.** A truncated
or filtered response must never be worth MORE than a complete one. Both yield `unknown`, so no
future refactor can quietly promote a partial response to authoritative.
-/
theorem a_partial_response_is_never_stronger_than_a_complete_one :
    status Evidence.bulkAbsentPartial = status Evidence.bulkAbsentComplete ∧
    mayStopRecording Evidence.bulkAbsentPartial = false := by
  decide

/-- Presence is still useful -- the optimisation is not neutered. A model seen in the bulk list is
    online without spending a per-model request, which is the whole point of CP82. -/
theorem presence_still_saves_a_request :
    status Evidence.bulkPresent = Status.online ∧
    needsDirectCheck Evidence.bulkPresent = false := by
  decide

/-- The three statuses are distinct: `unknown` is a real third value, not `offline` renamed. If it
    collapsed into either, the gate above would be vacuous. -/
theorem unknown_is_a_genuine_third_status :
    Status.unknown ≠ Status.offline ∧ Status.unknown ≠ Status.online := by
  decide

end CtbrecSpec.BulkOnline
