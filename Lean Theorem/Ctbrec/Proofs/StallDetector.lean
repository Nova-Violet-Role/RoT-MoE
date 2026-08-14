/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the stall detector reads a moving value twice

Subject: `src/app/ctbrec/ui/JavaFxRecording.java`, `valueChanged()`, and the progress label.

```java
public boolean valueChanged() {
   boolean changed = this.getSizeInByte() != this.lastValue;   // read 1
   this.lastValue = this.getSizeInByte();                      // read 2
   return changed;
}
```

`getSizeInByte()` is **not** a plain getter. `src/common/ctbrec/Recording.java:85-91`:

```java
public long getSizeInByte() {
   if (this.sizeInByte == -1L
       || this.getStatus() == Recording.State.RECORDING && this.recordingProcess != null) {
      this.refresh();          // <- goes to the filesystem
   }
   return this.sizeInByte;
}
```

so while a recording is RECORDING each call re-measures the file, and the two calls in
`valueChanged()` can legitimately return **different** values — the file is being written to between
them. This is a read-modify-write over a value another thread is moving.

The one caller is the stall indicator, `src/app/ctbrec/ui/tabs/RecordingsTab.java:207`:

```java
if (!rec.valueChanged() && rec.getStatus() == State.RECORDING) {
   this.setStyle("... -fx-background-color: red");     // "this recording has stalled"
}
```

## Finding 1 — a growing recording is painted as stalled, and the growth is lost forever

Write `L` for `lastValue`, `A` for the first read, `B` for the second. The shipped code answers
`A ≠ L` and then stores `B`.

Take `A = L` and `B ≠ L` — the file had not yet grown when the first read landed, and had grown by
the second. Then:

* the method returns **false**, so the cell is painted red: *stalled*, while the file is growing;
* `lastValue` becomes `B`, so the transition `L → B` is **never reported by any later call** either.
  The next poll compares against `B`. The change is not delayed, it is destroyed.

`the_shipped_reader_loses_every_transition_that_lands_on_last` states exactly that, for **every**
pair of values — it is not an example, and it is not a race that "probably will not happen": it is
the specified behaviour whenever the second read moves.

## Finding 2 — twice the filesystem work per repaint

Each `getSizeInByte()` on a RECORDING file calls `refresh()`. `valueChanged()` is called from
`updateItem` — a JavaFX cell repaint, which runs for every visible row on every table update. The
shipped code performs **two** refreshes where one is needed.

## Finding 3 — the progress label is unbounded, and its input crosses a trust boundary

```java
if (progress >= 0) { this.progressProperty.set(progress + "%"); }
```

Any non-negative `int` renders. `progress` reaches this method from
`RecordingMapperImpl.java:63 recording.setProgress(dto.getProgress())` — a DTO deserialised from the
**remote recorder's JSON**. A server answering `2000000000` puts "2000000000%" in the table.

The repair clamps the *label* to 0–100 and leaves the delegate holding the raw value, so nothing is
lost — the same shape as the status-label repair in checkpoint 63, which touched what is shown and
not what is stored.
-/

namespace CtbrecSpec

/-- One poll of the stall detector: what it answered, and what it stored for next time. -/
structure PollResult where
  /-- what `valueChanged()` returned -/
  changed : Bool
  /-- what `lastValue` holds afterwards -/
  stored : Nat
  deriving DecidableEq, Repr

/-- The shipped `valueChanged()`. `first` and `second` are the two reads of `getSizeInByte()`; they
differ exactly when the file grew between them. -/
def shippedPoll (last first second : Nat) : PollResult :=
  { changed := first != last, stored := second }

/-- The repair: read once, compare and store the same value. -/
def repairedPoll (last current : Nat) : PollResult :=
  { changed := current != last, stored := current }

/-- Number of `getSizeInByte()` calls per poll — each one a `refresh()` while RECORDING. -/
def shippedReads : Nat := 2

def repairedReads : Nat := 1

/-! ### Finding 1 — the lost transition -/

/-- **The shipped detector reports "no change" while storing a changed value.** For every previous
value `last` and every new value `b` different from it, a poll whose first read still saw `last`
answers `false` and yet records `b`: the growth `last → b` is reported by this call as a stall and
can never be reported by a later one, because `lastValue` has already moved past it. -/
theorem the_shipped_reader_loses_every_transition_that_lands_on_last (last b : Nat) :
    (shippedPoll last last b).changed = false ∧ (shippedPoll last last b).stored = b := by
  constructor
  · simp [shippedPoll]
  · rfl

/-- ...and that verdict is *wrong* whenever the value really did move, which is the case the stall
indicator exists to detect. -/
theorem the_lost_transition_is_a_false_stall (last b : Nat) (h : b ≠ last) :
    (shippedPoll last last b).changed = false ∧ b ≠ last := ⟨by simp [shippedPoll], h⟩

/-- **The repair answers about the value it stores.** Its verdict and its memory are the same read,
so no transition can fall between them. -/
theorem the_repaired_reader_reports_exactly_when_the_value_moved (last current : Nat) :
    (repairedPoll last current).changed = (current != last) := rfl

/-- The value the repair reports on is exactly the value it remembers — the property the shipped
code lacked, stated directly. -/
theorem the_repaired_verdict_and_memory_are_the_same_read (last current : Nat) :
    (repairedPoll last current).changed = ((repairedPoll last current).stored != last) := rfl

/-- **The two agree whenever the file did not move between the reads**, so this is a fix for the
racing case only and changes nothing otherwise — an anti-regression statement. -/
theorem the_repair_agrees_when_nothing_moved_between_the_reads (last v : Nat) :
    shippedPoll last v v = repairedPoll last v := rfl

/-- **Anti-amputation.** A detector that always answers "changed" would also never raise a false
stall; the repair must still be able to say `false`, and does so exactly when the value is unmoved. -/
theorem the_repair_still_detects_a_real_stall (last : Nat) :
    (repairedPoll last last).changed = false := by simp [repairedPoll]

/-- ...and still detects real growth. -/
theorem the_repair_still_detects_growth (last current : Nat) (h : current ≠ last) :
    (repairedPoll last current).changed = true := by
  simp [repairedPoll, h]

/-! ### Finding 2 — the doubled refresh -/

theorem the_shipped_poll_reads_twice : shippedReads = 2 := rfl

theorem the_repair_reads_once : repairedReads = 1 := rfl

theorem the_repair_halves_the_filesystem_work : repairedReads < shippedReads := by decide

/-! ### Finding 3 — the unbounded progress label -/

/-- The shipped label: any non-negative value renders verbatim. Negative means "no progress" and
renders empty, which is deliberate and preserved. -/
def shippedProgressLabel (p : Int) : String :=
  if p ≥ 0 then toString p ++ "%" else ""

/-- Clamp for DISPLAY only. The delegate keeps the raw value, exactly as the status-label repair
kept the delegate's state untouched. -/
def clampProgress (p : Int) : Int :=
  if p < 0 then p else if p > 100 then 100 else p

def repairedProgressLabel (p : Int) : String :=
  if p ≥ 0 then toString (clampProgress p) ++ "%" else ""

/-- **Every clamped progress lies in 0–100.** Quantified over every input, including the ones a
hostile or buggy remote recorder can send through `RecordingMapperImpl`. -/
theorem every_clamped_progress_is_at_most_one_hundred (p : Int) (h : p ≥ 0) :
    clampProgress p ≤ 100 := by
  unfold clampProgress
  split
  · omega
  · split
    · omega
    · omega

/-- ...and is never dragged below zero, so the "no progress" case keeps its meaning. -/
theorem clamping_never_invents_progress (p : Int) (h : p ≥ 0) : clampProgress p ≥ 0 := by
  unfold clampProgress
  split
  · omega
  · split
    · omega
    · omega

/-- **Anti-amputation.** Clamping must not flatten the ordinary range: every value that was already
sensible is passed through untouched, so the bar still moves. -/
theorem clamping_changes_nothing_in_range (p : Int) (h0 : p ≥ 0) (h1 : p ≤ 100) :
    clampProgress p = p := by
  unfold clampProgress
  split
  · omega
  · split
    · omega
    · rfl

/-- The negative sentinel still renders empty rather than a clamped number. -/
theorem a_negative_progress_still_renders_empty (p : Int) (h : p < 0) :
    repairedProgressLabel p = "" := by
  unfold repairedProgressLabel
  split
  · omega
  · rfl

/-- The two labels agree on every value that could sensibly occur, so this is a guard against
malformed input and not a change to normal display. -/
theorem the_labels_agree_on_every_sensible_value (p : Int) (h0 : p ≥ 0) (h1 : p ≤ 100) :
    shippedProgressLabel p = repairedProgressLabel p := by
  unfold shippedProgressLabel repairedProgressLabel
  rw [clamping_changes_nothing_in_range p h0 h1]

#guard (shippedPoll 10 10 25).changed == false
#guard (shippedPoll 10 10 25).stored == 25
#guard (repairedPoll 10 25).changed == true
#guard (repairedPoll 10 25).stored == 25
#guard (repairedPoll 10 10).changed == false
#guard shippedReads == 2
#guard repairedReads == 1
#guard shippedProgressLabel 2000000000 == "2000000000%"
#guard repairedProgressLabel 2000000000 == "100%"
#guard repairedProgressLabel 42 == "42%"
#guard repairedProgressLabel (-1) == ""
#guard clampProgress 100 == 100
#guard clampProgress 101 == 100

end CtbrecSpec
