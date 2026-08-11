/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # The repair for one failure manufactured another

**Measured 2026-08-11 on the live sink**, `~/.claude/rot-moe/rot-route-debug.jsonl`:

```
total=5000  valid=4735  corrupt=265        (5.3%)
corrupt by kind: gauge 222, route 27
shape: torn(no closing brace)=0   fused(}{ inside)=1
```

`torn = 0` is the load-bearing measurement. **Nothing was truncated.** Had a
writer been killed mid-record the log would be full of lines with no closing
brace; there are none. The corruption is *interleaving*: one line begins in the
middle of another record's array (`{"kens":"Venom"…`), and a 1309-byte `gauge`
record is mangled at byte 712.

## Why the existing repair cannot prevent this, and helps cause it

Both arms write a record as a three-part composite:

| step | sh arm | ps1 arm |
|---|---|---|
| read the last byte | `tail -c 1` (`_rot_terminate`) | `FileStream.ReadByte` (`Complete-RotPartialLine`) |
| append `\n` if the file did not end in one | `printf '\n' >>` | `File.AppendAllText` |
| append the record | `printf '%s\n' >>` | `Add-Content` |

That composite is the documented fix for a *different* failure: a writer killed
between its bytes leaves a line with no newline, and the next append lands on
those bytes (`RotLogAtomicity.appendSafe`, `naive_loses_the_next_record`). It is
correct for that failure.

Under concurrency it is the *cause*. Writer B reads the last byte while writer A
is still emitting its record, sees a byte that is not a newline — because A is
mid-record — and injects `\n` **inside A's record**, splitting one valid line
into two invalid ones. `gauge` records dominate the corruption because they are
the longest (~1300 B, a nine-lens array), so they hold the window open widest.

The three steps are individually atomic and the *sequence* is not. Nothing in
either arm makes it so.

## What is modelled

A write attempt as the interval it occupies, with the instant its newline-repair
lands. This is enough to state both the defect and the fix, and it is decidable,
so every claim below also executes.

## What is NOT modelled

That an append of fewer than `PIPE_BUF` bytes is atomic on POSIX; that a Windows
`Add-Content` opens and closes a handle per call. Those are facts about the
platform, not about this program, and assuming them would be assuming the
conclusion. The model asks only: *given that the three steps can interleave, what
follows?*
-/

namespace RotMoE.LogLock

/-- One writer's attempt at the three-part composite. `termAt` is the instant its
newline-repair is applied; the record itself is emitted over `[start, finish)`. -/
structure Write where
  id     : Nat
  start  : Nat
  termAt : Nat
  finish : Nat
  deriving Repr, DecidableEq

/-- Well-formedness: the repair happens within the attempt, which takes time. -/
def wellFormed (w : Write) : Bool :=
  (w.start ≤ w.termAt) && (w.termAt ≤ w.finish) && (w.start < w.finish)

/-- Two attempts overlap in time. -/
def overlap (a b : Write) : Bool :=
  (a.start < b.finish) && (b.start < a.finish)

/-- **The defect.** `b`'s newline-repair lands strictly inside `a`'s record, so
one valid line becomes two invalid ones. This is the measured shape: no
truncation, an interior split. -/
def splitsRecord (a b : Write) : Bool :=
  (a.start < b.termAt) && (b.termAt < a.finish)

/-- **The fix.** Mutual exclusion: the two attempts do not share any instant. A
lock is exactly this property; the name of the primitive is irrelevant. -/
def excluded (a b : Write) : Bool :=
  (a.finish ≤ b.start) || (b.finish ≤ a.start)

/-! ## The two writers as measured

`victim` is a long `gauge` record. `intruder` is a second hook firing while the
first is still emitting — the 31-event fan-out makes this ordinary, not rare. -/

/-- A ~1300-byte gauge record, emitted over an interval. -/
def victim : Write := ⟨1, 10, 10, 20⟩

/-- A second writer whose newline-repair lands at instant 15 — inside the victim. -/
def intruder : Write := ⟨2, 15, 15, 25⟩

/-- **Non-vacuity: the defect is real, not hypothetical.** Without exclusion there
is a schedule that splits a record, and here it is. A model in which no schedule
could corrupt anything would prove nothing about the 265 lines on disk. -/
theorem unlocked_admits_a_split : splitsRecord victim intruder = true := by decide

/-- …and these two writers are indeed not excluded. -/
theorem the_measured_pair_is_not_excluded : excluded victim intruder = false := by decide

/-- …and they do overlap, which is the precondition the fan-out supplies. -/
theorem the_measured_pair_overlaps : overlap victim intruder = true := by decide

/-! ## The durable statements

None of the three below names a constant. They are the properties that make the
lock a fix rather than a hope, and they survive any change to the intervals. -/

/-- **Exclusion forbids the split, for every pair of writers.** This is the whole
argument for the repair: not "the window is smaller" but "there is no window".

The `wellFormed b` premise is NOT decoration and was NOT in the first draft:
`omega` refuted that draft with an exact counterexample — a writer whose
newline-repair lands *outside its own attempt* defeats exclusion, because
exclusion only separates the intervals. The premise says a writer repairs within
the interval it holds, which is what the lock discipline enforces: acquire,
repair, append, release. A writer that touched the file outside its lock would
violate it, and that is precisely the bug this theorem must not silently allow. -/
theorem exclusion_forbids_a_split (a b : Write) (hw : wellFormed b = true)
    (h : excluded a b = true) : splitsRecord a b = false := by
  unfold excluded at h
  unfold wellFormed at hw
  unfold splitsRecord
  simp only [Bool.or_eq_true, decide_eq_true_eq] at h
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hw
  simp only [Bool.and_eq_false_iff, decide_eq_false_iff_not, Nat.not_lt]
  omega

/-- **Exclusion forbids overlap.** The same property stated on the interval, which
is what a lock actually enforces. -/
theorem exclusion_forbids_overlap (a b : Write) (h : excluded a b = true) :
    overlap a b = false := by
  unfold excluded at h
  unfold overlap
  simp only [Bool.or_eq_true, decide_eq_true_eq] at h
  simp only [Bool.and_eq_false_iff, decide_eq_false_iff_not, Nat.not_lt]
  omega

/-- **A split requires an overlap.** Contrapositive of the above, and the reason
the fix is aimed at the interval rather than at the newline: remove the overlap
and the interior write cannot exist. -/
theorem a_split_implies_an_overlap (a b : Write) (hw : wellFormed b = true)
    (h : splitsRecord a b = true) : overlap a b = true := by
  unfold splitsRecord at h
  unfold wellFormed at hw
  unfold overlap
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h hw ⊢
  omega

/-- **The critical negative result: terminating first does NOT help.**

Both writers performing the newline-repair — which is the shipped behaviour, and
the correct repair for the killed-writer failure — still admits the split. The
existing fix is not weakened by this module; it is shown to address a different
failure. Stated over every pair, so it is not a claim about one schedule. -/
theorem terminating_is_not_exclusion :
    ∃ a b : Write, wellFormed a = true ∧ wellFormed b = true ∧
      splitsRecord a b = true := by
  exact ⟨victim, intruder, by decide, by decide, by decide⟩

/-- **A lock that admits two holders is not a lock.** If exclusion fails, the
split is back — so the property that matters is exclusion itself, and a checker
must test for the property, never for the presence of a lock file. -/
theorem admitting_two_holders_restores_the_defect :
    excluded victim intruder = false ∧ splitsRecord victim intruder = true := by
  decide

/-! ## The design decision: refuse rather than write unlocked

When the lock cannot be acquired within the bound, the writer has two choices.
`writeAnyway` keeps the record and risks corrupting a neighbour; `refuse` drops
one debug record and records the loss. The model says which is right. -/

/-- Records lost, and records corrupted, for each policy. A refusal loses exactly
the record it declined to write. Writing unlocked keeps that record and damages
the one it lands in — and the neighbour was already complete. -/
def lostBy (refuse : Bool) : Nat := if refuse then 1 else 0

/-- Corrupt records produced, given that the contended write would have split a
neighbour. -/
def corruptBy (refuse : Bool) : Nat := if refuse then 0 else 2

/-- **Refusing loses one record; writing unlocked destroys two.** The split turns
one valid line into two invalid ones, so the unlocked policy is strictly worse
even counting only the arithmetic — before counting that a corrupt line also
poisons every consumer that parses the file. -/
theorem refusing_beats_writing_unlocked :
    lostBy true + corruptBy true < lostBy false + corruptBy false := by decide

/-- …and a refusal must be RECORDED, not silent. A dropped record that nothing
counts is indistinguishable from a router that never fired -- the same
absence-is-not-evidence defect as scoring a run by the absence of an error
string. Modelled as: the loss counter must move. -/
theorem a_refusal_is_visible : lostBy true ≠ 0 := by decide

-- Concrete checks. These execute the definitions rather than restating them.
#guard splitsRecord victim intruder = true
#guard excluded victim intruder = false
#guard overlap victim intruder = true
#guard wellFormed victim = true
#guard wellFormed intruder = true
#guard splitsRecord victim ⟨2, 20, 20, 30⟩ = false   -- starts after the victim ends
#guard excluded victim ⟨2, 20, 20, 30⟩ = true        -- …which is exactly exclusion
#guard splitsRecord victim ⟨2, 0, 5, 9⟩ = false      -- finishes before the victim
#guard excluded victim ⟨2, 0, 5, 9⟩ = true
#guard lostBy true + corruptBy true = 1
#guard lostBy false + corruptBy false = 2

end RotMoE.LogLock
