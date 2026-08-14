/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — recording a model who is not in a public room

Subject: `src/common/ctbrec/Model.java:138-145` (the `State` enum),
`src/common/ctbrec/sites/chaturbate/ChaturbateModel.java:79-97` and `:205-231`,
`src/common/ctbrec/recorder/OnlineMonitor.java:117`, and the `isOnline` of every site model.

**Measured across the tree**, one line per site model:

```
Cam4Model        return this.onlineState == Model.State.ONLINE;
CamsodaModel     return this.onlineState == Model.State.ONLINE;
ChaturbateModel  return Objects.equals("public", roomStatus);
ShowupModel      return onlineState != Model.State.OFFLINE;      <- the counter-example
StripchatVRModel return false;
...
```

Twelve of fourteen admit **exactly** `ONLINE`. `OnlineMonitor.java:117` starts a recording only
when `model.isOnline(true)`, so a model in a private or group show is never even attempted. That
is the capability the Socio asked for: recording must work when the *private* flag is out.

`ShowupModel` is the proof that the alternative is workable rather than reckless — one shipped
model already uses `!= OFFLINE`.

There is a second, smaller defect in the same class. `ChaturbateModel` maps the room status
`"Unknown"` to `State.ONLINE` (`:208-210`) while `isOnline` tests `equals("public", roomStatus)`
(`:96`) — **the two functions disagree about the same input**. A model whose status could not be
read is shown as online and refused a recording.

## What this module does NOT claim

Whether a private stream can actually be fetched depends on account access, and no proof settles
that. The claim proved here is narrower and is the one that matters: **the decision to attempt
must not exclude private and group rooms**. If the playlist then 403s, the existing transient
failure path handles it — that is a measurement the recorder makes, not a guess the predicate
should make on its behalf.
-/

namespace CtbrecSpec

/-- `Model.State`, mirrored exactly — seven cases, `Model.java:138-145`. -/
inductive OnlineState where
  | online
  | offline
  | away
  | private_
  | group
  | unknown
  | unchecked
  deriving DecidableEq, Repr

/-- Every state, for statements that must range over all of them. -/
def allStates : List OnlineState :=
  [.online, .offline, .away, .private_, .group, .unknown, .unchecked]

/-- **The shipped predicate**: exactly `ONLINE`, as twelve of the fourteen site models write it. -/
def legacyOnline (s : OnlineState) : Bool := s == OnlineState.online

/-- **The repair**: a room the recorder should attempt. `private_` and `group` are shows a paying
account can watch, so refusing to try is a decision the predicate has no standing to make.

`away` and `unknown` stay out deliberately: `away` is a placeholder screen, and attempting on
`unknown` would turn a failed status read into a recording storm. Naming the exclusions is the
point — a predicate that admitted everything would be as wrong as one that admits only `online`. -/
def recordable (s : OnlineState) : Bool :=
  match s with
  | .online => true
  | .private_ => true
  | .group => true
  | .offline => false
  | .away => false
  | .unknown => false
  | .unchecked => false

/-- **The defect, over the whole state space**: the shipped predicate refuses every non-public
room, including the two that are watchable. -/
theorem the_legacy_predicate_refuses_private_and_group :
    legacyOnline .private_ = false ∧ legacyOnline .group = false := by decide

/-- **The repair admits them.** -/
theorem the_repair_admits_private_and_group :
    recordable .private_ = true ∧ recordable .group = true := by decide

/-- **No regression, stated over every state**: everything the old predicate admitted, the new one
admits. A widening that dropped a case would be a new defect, and this is what forbids it. -/
theorem the_repair_admits_everything_the_legacy_did :
    allStates.all (fun s => !legacyOnline s || recordable s) = true := by decide

/-- **Anti-amputation, the other direction**: it is not `fun _ => true`. Offline stays refused, so
the recorder does not hammer models who are not there. -/
theorem offline_is_still_refused : recordable .offline = false := by decide

/-- Stated over the table rather than as one example: at least one state is refused and at least
one admitted, so the predicate is not constant in either direction. -/
theorem the_predicate_is_not_constant :
    (allStates.any (fun s => recordable s)) = true ∧
    (allStates.any (fun s => !recordable s)) = true := by decide

/-- The exact set that changed. Quantified over all states, so adding a state to the enum without
deciding its recordability makes this fail rather than silently defaulting. -/
theorem exactly_private_and_group_changed :
    allStates.all (fun s => (recordable s != legacyOnline s) == (s == .private_ || s == .group))
      = true := by decide

/-! ### The Chaturbate room-status layer -/

/-- The room statuses Chaturbate returns, `ChaturbateModel.java:205-231`. -/
inductive RoomStatus where
  | public_
  | unknownStatus
  | offline
  | private_
  | hidden
  | passwordProtected
  | away
  | group
  deriving DecidableEq, Repr

def allStatuses : List RoomStatus :=
  [.public_, .unknownStatus, .offline, .private_, .hidden, .passwordProtected, .away, .group]

/-- `setOnlineStateByRoomStatus`, transcribed EXACTLY as shipped -- including the case that is
wrong. `"Unknown"` becomes `ONLINE` at `ChaturbateModel.java:208-210`. -/
def shippedStateOfStatus (r : RoomStatus) : OnlineState :=
  match r with
  | .public_ => .online
  | .unknownStatus => .online
  | .offline => .offline
  | .private_ => .private_
  | .hidden => .private_
  | .passwordProtected => .private_
  | .away => .away
  | .group => .group

/-- `isOnline`, transcribed: `Objects.equals("public", roomStatus)`. -/
def legacyStatusOnline (r : RoomStatus) : Bool := r == RoomStatus.public_

/-- The repaired map. One case differs: a status that could not be read becomes `unknown`, not
`online`.

Without this, deriving recordability from the state map would ALSO start recordings on unreadable
status -- a behaviour change nobody asked for, driven by data the app admits it failed to parse.
Today such a model is displayed as online and never recorded; after the repair it is displayed as
unknown and never recorded. The recording behaviour is preserved exactly, and the display stops
lying. -/
def repairedStateOfStatus (r : RoomStatus) : OnlineState :=
  match r with
  | .unknownStatus => .unknown
  | r => shippedStateOfStatus r

/-- The repaired predicate: decide from the state map instead of re-deciding in a second place. -/
def statusRecordable (r : RoomStatus) : Bool := recordable (repairedStateOfStatus r)

/-- **The two shipped functions disagree about the same input.** `"Unknown"` becomes `ONLINE` in
one and `false` in the other — a model whose status could not be read is displayed as online and
refused a recording. This is the theorem that would have caught it. -/
theorem the_shipped_functions_disagree_on_unknown :
    shippedStateOfStatus .unknownStatus = .online ∧ legacyStatusOnline .unknownStatus = false := by
  decide

/-- **After the repair they agree, for every status.** The predicate is derived from the state map
instead of re-deciding the question in a second place — which is why they cannot drift apart
again. -/
theorem the_repaired_predicate_agrees_with_the_state_map :
    allStatuses.all (fun r => statusRecordable r == recordable (repairedStateOfStatus r)) = true := by
  decide

/-- All three private-flavoured statuses become recordable. `hidden` and `password protected` map
to the same state as `private`, so the Socio's request covers them too — stated explicitly
because it would be easy to fix only the one that was named. -/
theorem every_private_flavoured_status_is_recordable :
    statusRecordable .private_ = true ∧ statusRecordable .hidden = true ∧
    statusRecordable .passwordProtected = true := by decide

/-- Offline and away stay refused at the status layer as well. -/
theorem offline_and_away_stay_refused :
    statusRecordable .offline = false ∧ statusRecordable .away = false := by decide

/-- **The count that changed**, as data: 4 of the 8 statuses were refused and now are not. -/
theorem four_statuses_became_recordable :
    (allStatuses.filter (fun r => statusRecordable r && !legacyStatusOnline r)).length = 4 := by
  decide

#guard legacyOnline .private_ == false
#guard recordable .private_ == true
#guard recordable .offline == false
#guard statusRecordable .hidden == true
#guard statusRecordable .away == false
-- 5, not 6: public plus the four that were newly admitted. `Unknown` is NOT among them, because
-- the repaired map sends an unreadable status to `unknown` rather than inheriting `online`.
#guard (allStatuses.filter (fun r => statusRecordable r)).length == 5
#guard statusRecordable .unknownStatus == false
#guard (allStatuses.filter (fun r => legacyStatusOnline r)).length == 1
#guard allStates.length == 7

end CtbrecSpec
