/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# The A/B's disarm check counts the wrong thing

`bench/ab-session.sh:307` decides whether arm B was genuinely disarmed by
comparing the route-record count before and after the run:

    arm B produced $_new route record(s) -- the plugin was still armed

`_new` is a **global delta** over the whole central log. Measured today, every
one of the 176 records in `bench/ab-metrics.jsonl` carries `arm`, `turn`, `dur`,
`cost_micro`, `len`, `outTok`, `model`, `q`, `hedge`, `narr`, `leak` -- and
**zero** carry `session` or `src`. The join that would make the check sound was
not available when it was written. It is now: every record has carried `session`
and `src` since the observability subsystem landed.

## Why a global delta is unsound in BOTH directions

**False alarm.** The central log is append-shared. Nine checkers write to it with
`src=test`, and any concurrent session writes to it too. If a foreign writer adds
records during arm B, the delta is positive and the harness reports "the plugin
was still armed" about an arm that emitted nothing. That is a red build caused by
unrelated traffic -- the worst kind, because the obvious repair is to weaken the
check.

**False pass, and this one is worse.** The log ROTATES at
`ROTMOE_DEBUG_LOG_MAX`. If rotation drops as many old records as arm B wrote, the
delta is zero and the harness reports a clean disarm for an arm that was fully
armed. A check that can report success when the thing it guards has failed is
not a check.

Both are the same defect: a count-delta measures *the file*, while the question
is about *this run*. `session` answers the question directly, and
`sessionRouteCount` cannot be moved by traffic it does not name.

## What is proved here, and what is not

Proved: the global delta admits both failure modes and the session join admits
neither. NOT proved -- and not claimed anywhere -- that the routed arm produces
BETTER answers. That is the A/B's own open question and no theorem in this file
speaks to it.
-/

namespace RotMoE.AbJoin

/-- One record in the central log. `session` is the field the old check ignored. -/
structure Rec where
  session : String
  isRoute : Bool
deriving DecidableEq, Repr

/-- The sound check: count only what this run's session wrote. -/
def sessionRouteCount (recs : List Rec) (s : String) : Nat :=
  (recs.filter (fun r => r.session == s && r.isRoute)).length

/-- The check as written: a delta over the whole file. `dropped` models rotation. -/
def globalDelta (before written dropped : Nat) : Int :=
  (before + written - dropped : Int) - before

/-- A disarm verdict from the global delta: "clean" iff the file did not grow. -/
def disarmedByDelta (before written dropped : Nat) : Bool :=
  globalDelta before written dropped == 0

/-- A disarm verdict from the join: "clean" iff THIS session wrote no route record. -/
def disarmedByJoin (recs : List Rec) (s : String) : Bool :=
  sessionRouteCount recs s == 0

section GlobalDeltaIsUnsound

/-- FALSE ALARM. Foreign traffic alone makes the delta positive, so the harness
condemns an arm that wrote nothing. -/
theorem delta_false_alarms_on_foreign_traffic :
    disarmedByDelta 100 3 0 = false := by decide

/-- FALSE PASS, the serious one. Rotation drops exactly what the arm wrote, the
delta is zero, and a fully armed run is reported clean. -/
theorem delta_false_passes_under_rotation :
    disarmedByDelta 100 3 3 = true := by decide

/-- Stated as indistinguishability: a silent arm and an armed-but-rotated arm
produce the identical verdict, so the check cannot separate them. -/
theorem delta_cannot_separate_silence_from_rotation :
    disarmedByDelta 100 0 0 = disarmedByDelta 100 3 3 := by decide

end GlobalDeltaIsUnsound

section TheJoinIsSound

/-- Foreign records cannot move the join, whatever their number or content --
quantified over every possible foreign session, not a chosen example. -/
theorem join_ignores_foreign_traffic (recs : List Rec) (s t : String)
    (hne : ¬ (t = s)) (b : Bool) :
    sessionRouteCount (⟨t, b⟩ :: recs) s = sessionRouteCount recs s := by
  have h : (t == s) = false := by simpa using hne
  simp [sessionRouteCount, List.filter, h]

/-- And the arm's own route record always counts -- the join cannot be silenced
by rotation of records belonging to somebody else. -/
theorem join_counts_the_arms_own_record (recs : List Rec) (s : String) :
    sessionRouteCount (⟨s, true⟩ :: recs) s = sessionRouteCount recs s + 1 := by
  simp [sessionRouteCount, List.filter]

/-- So an armed arm is never reported clean by the join. This is exactly the
false pass that rotation buys against the delta. -/
theorem join_never_false_passes (recs : List Rec) (s : String) :
    disarmedByJoin (⟨s, true⟩ :: recs) s = false := by
  simp [disarmedByJoin, sessionRouteCount, List.filter]

/-- A non-route record from the same session does not trip the check either:
gauge lines are not evidence of routing. -/
theorem join_ignores_non_route_records (recs : List Rec) (s : String) :
    sessionRouteCount (⟨s, false⟩ :: recs) s = sessionRouteCount recs s := by
  simp [sessionRouteCount, List.filter]

end TheJoinIsSound

section Measured

/-! The concrete shapes, executable. -/

def foreignOnly : List Rec := [⟨"other-1", true⟩, ⟨"other-2", true⟩]
def mixed : List Rec := [⟨"other-1", true⟩, ⟨"armB", true⟩, ⟨"armB", false⟩]

#guard sessionRouteCount foreignOnly "armB" = 0
#guard disarmedByJoin foreignOnly "armB" = true
-- the delta, on the same world, condemns the innocent arm
#guard disarmedByDelta 100 0 0 = true
#guard disarmedByDelta 100 2 0 = false
#guard sessionRouteCount mixed "armB" = 1
#guard disarmedByJoin mixed "armB" = false
-- rotation: the delta says clean, the join says armed. They disagree, and the
-- join is the one that is right.
#guard disarmedByDelta 100 3 3 = true
#guard disarmedByJoin [⟨"armB", true⟩, ⟨"armB", true⟩, ⟨"armB", true⟩] "armB" = false

end Measured

end RotMoE.AbJoin
