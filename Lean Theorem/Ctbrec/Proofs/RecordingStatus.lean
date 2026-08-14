/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the recording status label: a second source of truth

Subject: `src/app/ctbrec/ui/JavaFxRecording.java`, `setStatus(State)`.

`Recording.State` **already carries its own display string** (`src/common/ctbrec/Recording.java`):

```java
public enum State {
   RECORDING("recording"), GENERATING_PLAYLIST("generating playlist"),
   POST_PROCESSING("post-processing"), FINISHED("finished"), DOWNLOADING("downloading"),
   DELETING("deleting"), DELETED("deleted"), UNKNOWN("unknown"), WAITING("waiting"),
   FAILED("failed");
   private final String desc;
   @Override public String toString() { return this.desc; }
}
```

and `JavaFxRecording.setStatus` re-implemented that identical mapping as a hand-written ten-arm
switch, duplicating every string literal. **Two independent sources of truth for one label.**

MEASURED (`/tmp/StProbe.java`, Temurin 21, the real `Recording.State`): all ten switch strings
agree with `toString()` **today**, and `State.values().length == 10`. So the switch buys nothing —
it can only drift.

## Finding 1 — a state added tomorrow is silently mislabelled "unknown"

The switch ends `case UNKNOWN: default: set("unknown")`. Add an eleventh constant to
`Recording.State` — an ordinary, correct future change — and the enum carries the right label while
the UI shows **"unknown"**. Nothing fails to compile; nothing goes red; the user sees a wrong word.

This is why the load-bearing theorem here is `every_state_shows_its_own_description`, quantified
over **every** state including ones that do not exist yet, and *not* a theorem listing the ten
constants that happen to be right today. The ten-way agreement is recorded as `#guard`s documenting
the present, exactly where a contingent fact belongs.

`the_switch_mislabels_every_state_added_later` proves the defect universally: for **every** name a
future state could carry, the switch answers "unknown".

## Finding 2 — `switch (null)` throws

MEASURED: `switch (status)` on a null enum throws `NullPointerException`. `setStatus` is called from
`update()` with `updated.getStatus()` and from the constructor with `recording.getStatus()`, neither
of which is guaranteed non-null by any type in this codebase.

## Finding 3 — a pinned recording notifies TWICE, and the first value has no lock

```java
this.statusProperty.set("recording");                                    // notification 1
if (this.isPinned())
   this.statusProperty.set((String) this.statusProperty.get() + " 🔒");  // notification 2
```

The pinned branch reads the property back out and sets it a second time. MEASURED on a real
`SimpleStringProperty`:

```
SHIPPED pinned update:   notify #1 -> "recording"        <- transient, NO lock
                         notify #2 -> "recording <lock>"
  shipped notifications = 2
REPAIRED pinned update:  notify #1 -> "recording <lock>"
  repaired notifications = 1
```

Every listener bound to a pinned recording's status observes the **unpinned** label first. Computing
the string locally and setting once removes both the extra notification and the transient.
-/

namespace CtbrecSpec

/-- `Recording.State`. The ten shipped constants, plus `addedLater` standing for any constant a
future version declares — which is what makes the findings here durable rather than a snapshot of
today's enum. -/
inductive RecState where
  | recording
  | generatingPlaylist
  | postProcessing
  | finished
  | downloading
  | deleting
  | deleted
  | unknown
  | waiting
  | failed
  | addedLater (name : String)
  deriving DecidableEq, Repr

/-- The enum's OWN declared description — `toString()` in `Recording.java`. The single source of
truth. A state added later carries whatever description it was declared with. -/
def desc : RecState → String
  | .recording => "recording"
  | .generatingPlaylist => "generating playlist"
  | .postProcessing => "post-processing"
  | .finished => "finished"
  | .downloading => "downloading"
  | .deleting => "deleting"
  | .deleted => "deleted"
  | .unknown => "unknown"
  | .waiting => "waiting"
  | .failed => "failed"
  | .addedLater n => n

/-- The hand-written switch in `JavaFxRecording.setStatus`, including its `default:` arm. -/
def shippedLabel : RecState → String
  | .recording => "recording"
  | .generatingPlaylist => "generating playlist"
  | .postProcessing => "post-processing"
  | .finished => "finished"
  | .downloading => "downloading"
  | .deleting => "deleting"
  | .deleted => "deleted"
  | .unknown => "unknown"
  | .waiting => "waiting"
  | .failed => "failed"
  | .addedLater _ => "unknown"   -- the `default:` arm

/-- The repair: ask the enum. -/
def derivedLabel (s : RecState) : String := desc s

/-- The label actually shown, with the pin marker. `lock` is left ABSTRACT so every theorem below
holds for whatever marker the UI uses — a stronger statement than fixing today's emoji, and it keeps
the spec from breaking the day someone changes the glyph. -/
def shownLabel (lock : String) (pinned : Bool) (s : RecState) : String :=
  if pinned then derivedLabel s ++ lock else derivedLabel s

/-! ### Finding 1 — the duplicated mapping -/

/-- **The load-bearing theorem: every state shows its own description.** Quantified over every
`RecState`, including states that do not exist yet. This is the durable form; the ten-way agreement
with today's constants is recorded in the `#guard`s below, where a contingent fact belongs. -/
theorem every_state_shows_its_own_description (s : RecState) : derivedLabel s = desc s := rfl

/-- **The switch mislabels every state added later**, for every name such a state could carry. -/
theorem the_switch_mislabels_every_state_added_later (n : String) :
    shippedLabel (.addedLater n) = "unknown" := rfl

/-- ...while the enum would have been right. -/
theorem the_enum_would_have_been_right (n : String) : desc (.addedLater n) = n := rfl

/-- **So the two sources of truth disagree** on every future state whose description is not itself
the word "unknown" — a wrong word on screen, with nothing failing to compile. -/
theorem the_two_sources_disagree_on_every_new_state (n : String) (h : n ≠ "unknown") :
    shippedLabel (.addedLater n) ≠ derivedLabel (.addedLater n) := by
  simp [shippedLabel, derivedLabel, desc]
  exact fun hc => h hc.symm

/-- The repair has no such arm: it agrees with the enum on states added later too. -/
theorem the_repair_is_correct_for_states_that_do_not_exist_yet (n : String) :
    derivedLabel (.addedLater n) = n := rfl

/-- **Anti-regression.** On the ten states shipped today the repair changes nothing at all, so this
is a maintenance fix and not a relabelling of the UI. Stated over the concrete list rather than
claimed, and checked by `decide`. -/
theorem the_repair_changes_nothing_that_ships_today :
    [RecState.recording, .generatingPlaylist, .postProcessing, .finished, .downloading,
     .deleting, .deleted, .unknown, .waiting, .failed].all
      (fun s => derivedLabel s == shippedLabel s) = true := by decide

/-! ### Finding 3 — the pin marker and the double notification -/

/-- An unpinned recording shows exactly its description. -/
theorem unpinned_shows_exactly_the_description (lock : String) (s : RecState) :
    shownLabel lock false s = desc s := rfl

/-- **Anti-amputation.** Pinning APPENDS; it never replaces the label. Stated for every marker and
every state, so no choice of glyph can swallow the description. -/
theorem pinning_appends_and_never_replaces (lock : String) (s : RecState) :
    shownLabel lock true s = desc s ++ lock := rfl

/-- Number of change notifications the shipped code emits for one status update. -/
def shippedNotifications (pinned : Bool) : Nat := if pinned then 2 else 1

/-- The repair computes the string locally and sets the property once. -/
def repairedNotifications (_pinned : Bool) : Nat := 1

/-- **MEASURED: a pinned recording fires two notifications.** -/
theorem a_pinned_update_notifies_twice : shippedNotifications true = 2 := rfl

/-- The repair fires exactly one, for every recording. -/
theorem the_repair_notifies_once_for_every_recording (p : Bool) :
    repairedNotifications p = 1 := rfl

/-- ...and never more than the shipped code did, so no listener sees additional traffic. -/
theorem the_repair_never_notifies_more (p : Bool) :
    repairedNotifications p ≤ shippedNotifications p := by
  cases p <;> decide

/-- The first value a listener observes under the shipped code, when the recording IS pinned. -/
def shippedFirstNotification (s : RecState) : String := shippedLabel s

/-- **The transient is exactly the unpinned label**: every listener bound to a pinned recording sees
it without its lock before seeing it with one. -/
theorem the_first_notification_is_the_unpinned_label (lock : String) (s : RecState)
    (h : shippedLabel s = derivedLabel s) :
    shippedFirstNotification s = shownLabel lock false s := h

/-- The repair emits the pinned label and nothing else — there is no intermediate value at all. -/
theorem the_repair_shows_no_intermediate_value (lock : String) (s : RecState) :
    shownLabel lock true s = derivedLabel s ++ lock := rfl

/-! ### Finding 2 — the null status -/

/-- `setStatus` repaired: a null status reads as `UNKNOWN`, which is the enum's own name for "we do
not know", rather than throwing `NullPointerException` out of a UI update. -/
def statusOrUnknown : Option RecState → RecState
  | none => .unknown
  | some s => s

theorem a_null_status_reads_as_unknown : statusOrUnknown none = .unknown := rfl

theorem a_real_status_is_untouched (s : RecState) : statusOrUnknown (some s) = s := rfl

/-- ...and it therefore always has a label. -/
theorem every_status_including_null_has_a_label (o : Option RecState) :
    derivedLabel (statusOrUnknown o) = desc (statusOrUnknown o) := rfl

-- The ten constants shipped today. These are contingent facts about the present enum, so they are
-- guards and not theorems: adding an eleventh state must NOT break the spec, it must be labelled
-- correctly by `every_state_shows_its_own_description` without any edit here.
#guard derivedLabel RecState.recording == "recording"
#guard derivedLabel RecState.generatingPlaylist == "generating playlist"
#guard derivedLabel RecState.postProcessing == "post-processing"
#guard derivedLabel RecState.finished == "finished"
#guard derivedLabel RecState.downloading == "downloading"
#guard derivedLabel RecState.deleting == "deleting"
#guard derivedLabel RecState.deleted == "deleted"
#guard derivedLabel RecState.unknown == "unknown"
#guard derivedLabel RecState.waiting == "waiting"
#guard derivedLabel RecState.failed == "failed"
#guard shippedLabel (RecState.addedLater "paused") == "unknown"
#guard derivedLabel (RecState.addedLater "paused") == "paused"
#guard shownLabel "*" false RecState.recording == "recording"
#guard shownLabel "*" true RecState.recording == "recording*"
#guard shippedNotifications true == 2
#guard repairedNotifications true == 1
#guard derivedLabel (statusOrUnknown none) == "unknown"

end CtbrecSpec
