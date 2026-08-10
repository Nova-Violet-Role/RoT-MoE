/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Proofs.RotDebugLog

/-! # An interrupted write does not corrupt itself — it corrupts the NEXT record

`RotDebugLog` proves three things about the debug channel: the write is tolerant,
a lost append is marked, and the file is bounded. All three hold. The log was
still **8.2% unreadable**.

Measured on the live channel `~/.claude/rot-moe/rot-route-debug.jsonl`
(5000 lines, the rotation cap):

| shape | count |
|---|---|
| lines `JSON.parse` accepts | 4591 |
| lines it rejects | **409** |
| of those, carrying two `"kind"` keys | 27 |
| of those, beginning mid-token | 27 |
| of those, carrying no `"ts"` at all | 47 |

`grep` counts 3090 gauge records where the parser accepts 2750, so every
statistic ever computed from this file has been silently short.

## The mechanism, reproduced before it was modelled

A shell reproduction (three commands, deterministic) produced the live shape
exactly:

```
{"kind":"route","n":1}                                        <- fine
{"kind":"gauge","n":2,"lenses":[{"mu":1.05{"kind":"route","n":3}   <- TWO records
```

An interrupted writer leaves bytes with no newline. The *next* append lands
directly on them. One line, two records, and `JSON.parse` rejects the whole
thing.

## The point this module exists to make

The interrupted write is **not** where the loss happens. A trailing fragment on
its own costs nothing yet — the file simply ends mid-line, and `rotate` is happy
to carry it. The damage is done by the *next* writer, which had nothing wrong
with it, and which loses its own perfectly good record by fusing with a fragment
it never saw.

That is why the repair goes in the appender rather than in the interrupted path:
you cannot fix a process that was killed, but you can make its successor refuse
to inherit its mess. `appendSafe` terminates a pending fragment before writing.
Cost on the healthy path: **nothing** — `identical_on_the_healthy_path` proves
the two agree whenever there is no fragment, so this is not a behaviour change
for the 99.9% case, and `safe_never_loses_a_record` proves it is never worse.

The sharpest theorem here is `corrupt_line_count_cannot_tell_them_apart`: naive
and safe produce the *same number of corrupt lines*. A gate that counts bad
lines would score the repair as worthless. Only counting surviving **records**
separates them — which is what `checker/log-integrity.sh` was built to do.
-/

namespace RotLogAtomicity

/-- A piece of a line: either a whole record, or the fragment an interrupted
writer left behind. The distinction is the whole subject. -/
inductive Piece where
  | whole : String → Piece
  | frag  : String → Piece
  deriving DecidableEq, Repr

/-- A physical line is the list of pieces that ended up on it. A healthy line
holds exactly one `whole`. -/
abbrev Line := List Piece

/-- A log file: the newline-terminated lines, plus any trailing bytes with no
newline. `pending` is what an interrupted writer leaves. -/
structure Log where
  lines   : List Line
  pending : Option String
  deriving DecidableEq, Repr

namespace Log

def empty : Log := ⟨[], none⟩

/-- A line is readable iff it is exactly one whole record. -/
def lineReadable (l : Line) : Bool :=
  match l with
  | [Piece.whole _] => true
  | _               => false

/-- How many records a reader recovers. This is the metric that matters, and it
is NOT the same as counting bad lines. -/
def readable (L : Log) : Nat := (L.lines.filter lineReadable).length

/-- How many lines a naive integrity check would flag. -/
def corrupt (L : Log) : Nat := (L.lines.filter (fun l => !lineReadable l)).length

/-- No corrupt line anywhere. -/
def clean (L : Log) : Bool := L.lines.all lineReadable

end Log

open Log

/-- The SHIPPED writer: `printf '%s\n' "$rec" >> log`. If bytes without a
newline are already at the end, this record fuses with them. -/
def appendNaive (r : String) (L : Log) : Log :=
  match L.pending with
  | none   => ⟨L.lines ++ [[Piece.whole r]], none⟩
  | some p => ⟨L.lines ++ [[Piece.frag p, Piece.whole r]], none⟩

/-- A writer killed mid-record — a hook that hit its timeout, which is what the
1200 ms hook budget was doing before it was raised to 18000 ms. -/
def interrupt (p : String) (L : Log) : Log := ⟨L.lines, some p⟩

/-- THE REPAIR. Terminate a pending fragment before appending, so the fragment
is isolated on its own line and the new record lands intact on the next. -/
def appendSafe (r : String) (L : Log) : Log :=
  match L.pending with
  | none   => ⟨L.lines ++ [[Piece.whole r]], none⟩
  | some p => ⟨L.lines ++ [[Piece.frag p], [Piece.whole r]], none⟩

/-! ## The defect -/

/-- A fused line is not readable. -/
theorem fused_is_unreadable (p r : String) :
    lineReadable [Piece.frag p, Piece.whole r] = false := rfl

/-- A lone fragment is not readable either. -/
theorem lone_fragment_is_unreadable (p : String) :
    lineReadable [Piece.frag p] = false := rfl

/-- A whole record on its own line is readable. -/
theorem whole_is_readable (r : String) :
    lineReadable [Piece.whole r] = true := rfl

/-- The shipped writer fuses onto a fragment. -/
theorem naive_fuses (p r : String) (L : Log) :
    (appendNaive r (interrupt p L)).lines = L.lines ++ [[Piece.frag p, Piece.whole r]] := rfl

/-- **The finding.** Appending after an interruption recovers NO new record: the
writer's own good record is destroyed by a fragment it never saw. -/
theorem naive_loses_the_next_record (p r : String) (L : Log) :
    (appendNaive r (interrupt p L)).readable = L.readable := by
  simp [appendNaive, interrupt, Log.readable, List.filter_append, lineReadable]

/-- A pending fragment on its own has cost nothing yet — the loss is created by
the successor. This is why the repair belongs in the appender. -/
theorem interrupt_alone_loses_nothing (p : String) (L : Log) :
    (interrupt p L).readable = L.readable := rfl

/-! ## The repair -/

/-- The repair keeps the new record. -/
theorem safe_keeps_the_next_record (p r : String) (L : Log) :
    (appendSafe r (interrupt p L)).readable = L.readable + 1 := by
  simp [appendSafe, interrupt, Log.readable, List.filter_append, List.filter_cons,
    lineReadable]

/-- Strictly better, for every fragment, every record, every prior log. Not a
claim about today's values — a claim about the discipline. -/
theorem safe_strictly_better (p r : String) (L : Log) :
    (appendNaive r (interrupt p L)).readable < (appendSafe r (interrupt p L)).readable := by
  rw [naive_loses_the_next_record, safe_keeps_the_next_record]
  omega

/-- **The repair costs nothing on the healthy path.** With no fragment pending
the two writers are literally the same function, so this is not a behaviour
change for a well-formed log — the reason it is safe to ship. -/
theorem identical_on_the_healthy_path (r : String) (L : Log) (h : L.pending = none) :
    appendSafe r L = appendNaive r L := by
  simp [appendSafe, appendNaive, h]

/-! ### A fresh log

These exist because a mutant found the hole. `empty` was defined and then never
constrained: replacing it with `⟨[], some "x"⟩` — a brand-new log that already
carries a dangling fragment — left the whole module green. Every theorem above
is quantified over an arbitrary `L`, so none of them says anything about the
starting state, and the FIRST record written to a fresh log could have been
fused with no theorem objecting.

`empty_has_nothing_pending` is the load-bearing one; the other two would still
hold under that mutant, since `clean` and `readable` read only `lines`. -/

/-- **A fresh log has nothing pending**, so the very first record written to it
can never be fused into a fragment left by someone else. -/
theorem empty_has_nothing_pending : empty.pending = none := rfl

/-- A fresh log is clean. -/
theorem empty_is_clean : empty.clean = true := rfl

/-- A fresh log holds no records — the recovered count starts at zero, so any
later count is entirely attributable to writes. -/
theorem empty_has_no_records : empty.readable = 0 := rfl

/-- **On a fresh log the two writers are literally the same function.** The
repair cannot change the behaviour of a new installation — it only ever acts on
a log some earlier process left broken. -/
theorem writers_agree_on_a_fresh_log (r : String) :
    appendSafe r empty = appendNaive r empty :=
  identical_on_the_healthy_path r empty empty_has_nothing_pending

/-- And never worse, in either case. -/
theorem safe_never_loses_a_record (r : String) (L : Log) :
    (appendNaive r L).readable ≤ (appendSafe r L).readable := by
  cases hp : L.pending with
  | none =>
      rw [identical_on_the_healthy_path r L hp]
      exact Nat.le_refl _
  | some p =>
      simp [appendNaive, appendSafe, hp, Log.readable, List.filter_append,
        List.filter_cons, lineReadable]

/-- Neither writer disturbs a line already written. -/
theorem prior_lines_are_a_prefix_naive (r : String) (L : Log) :
    ∃ t, (appendNaive r L).lines = L.lines ++ t := by
  cases hp : L.pending with
  | none   => exact ⟨[[Piece.whole r]], by simp [appendNaive, hp]⟩
  | some p => exact ⟨[[Piece.frag p, Piece.whole r]], by simp [appendNaive, hp]⟩

theorem prior_lines_are_a_prefix_safe (r : String) (L : Log) :
    ∃ t, (appendSafe r L).lines = L.lines ++ t := by
  cases hp : L.pending with
  | none   => exact ⟨[[Piece.whole r]], by simp [appendSafe, hp]⟩
  | some p => exact ⟨[[Piece.frag p], [Piece.whole r]], by simp [appendSafe, hp]⟩

/-! ## Why a line-counting gate would have scored the repair as useless -/

/-- The naive writer adds exactly one corrupt line. -/
theorem naive_adds_one_corrupt_line (p r : String) (L : Log) :
    (appendNaive r (interrupt p L)).corrupt = L.corrupt + 1 := by
  simp [appendNaive, interrupt, Log.corrupt, List.filter_append, lineReadable]

/-- So does the repair. -/
theorem safe_adds_one_corrupt_line (p r : String) (L : Log) :
    (appendSafe r (interrupt p L)).corrupt = L.corrupt + 1 := by
  simp [appendSafe, interrupt, Log.corrupt, List.filter_append, lineReadable]

/-- **Therefore counting corrupt LINES cannot distinguish the defect from its
repair.** A gate built on that metric would report no improvement after the fix
and no regression before it. `checker/log-integrity.sh` counts recovered
records for exactly this reason. -/
theorem corrupt_line_count_cannot_tell_them_apart (p r : String) (L : Log) :
    (appendNaive r (interrupt p L)).corrupt = (appendSafe r (interrupt p L)).corrupt := by
  rw [naive_adds_one_corrupt_line, safe_adds_one_corrupt_line]

/-- But counting RECORDS does. -/
theorem record_count_does_tell_them_apart (p r : String) (L : Log) :
    (appendNaive r (interrupt p L)).readable ≠ (appendSafe r (interrupt p L)).readable := by
  rw [naive_loses_the_next_record, safe_keeps_the_next_record]
  omega

/-! ## Attribution -/

/-- A fused line has two origins. Attributing it to a single writer — which the
first pass over the live log did, by reading the one `"ts"` it could find — is
unsound: the fragment and the record come from different processes. The
corrected census reported the three buckets separately for this reason. -/
theorem fused_line_has_two_origins (p r : String) (L : Log) :
    (appendNaive r (interrupt p L)).lines.getLast? = some [Piece.frag p, Piece.whole r] := by
  simp [appendNaive, interrupt]

/-- Under the repair each line has exactly one origin, so attribution becomes
sound again. -/
theorem safe_lines_have_one_origin_each (p r : String) (L : Log) :
    (appendSafe r (interrupt p L)).lines.getLast? = some [Piece.whole r] := by
  simp [appendSafe, interrupt]

/-! ## The gate must never fire on a healthy log -/

/-- A clean log has zero corrupt lines — the gate cannot fail a correct file.
This is the counterpart of `RotGaugeZero.idle_is_not_a_violation`: a check that
fires on a legitimate state is a spec forbidding a correct future. -/
theorem clean_log_has_no_corrupt (L : Log) (h : L.clean = true) : L.corrupt = 0 := by
  simp only [Log.clean, List.all_eq_true] at h
  simp only [Log.corrupt, List.length_eq_zero_iff, List.filter_eq_nil_iff]
  intro a ha
  simp [h a ha]

/-- And it does fire when a fusion happens. An alarm that cannot ring is not
coverage. -/
theorem gate_fires_on_fusion (p r : String) (L : Log) :
    (appendNaive r (interrupt p L)).clean = false := by
  simp [appendNaive, interrupt, Log.clean, lineReadable]

/-- One healthy append leaves the log clean and still terminated. -/
theorem healthy_append_stays_clean (r : String) (L : Log)
    (h : L.pending = none) (hc : L.clean = true) :
    (appendNaive r L).clean = true ∧ (appendNaive r L).pending = none := by
  constructor
  · simp only [Log.clean, appendNaive, h, List.all_append]
    simp only [Log.clean] at hc
    simp [hc, lineReadable]
  · simp [appendNaive, h]

/-- A run of healthy appends stays clean, for any number of records. The gate
therefore cannot accumulate a false positive over a long session. -/
theorem healthy_appends_stay_clean (rs : List String) (L : Log)
    (h : L.pending = none) (hc : L.clean = true) :
    (rs.foldl (fun acc r => appendNaive r acc) L).clean = true := by
  induction rs generalizing L with
  | nil => simpa using hc
  | cons r rest ih =>
      simp only [List.foldl_cons]
      obtain ⟨hc', hp'⟩ := healthy_append_stays_clean r L h hc
      exact ih (appendNaive r L) hp' hc'

/-! ## Concrete witnesses — these EXECUTE -/

/-- Two good records. -/
def healthyLog : Log :=
  ⟨[[Piece.whole "{\"kind\":\"route\",\"n\":1}"],
    [Piece.whole "{\"kind\":\"gauge\",\"n\":2}"]], none⟩

/-- The same log with a writer killed mid-record. -/
def interruptedLog : Log := interrupt "{\"kind\":\"gauge\",\"n\":3,\"lenses\":[{\"mu\":1.05" healthyLog

/-- What the shipped writer produces next — the live shape. -/
def fusedLog : Log := appendNaive "{\"kind\":\"route\",\"n\":4}" interruptedLog

/-- What the repair produces instead. -/
def repairedLog : Log := appendSafe "{\"kind\":\"route\",\"n\":4}" interruptedLog

#guard healthyLog.readable = 2
#guard healthyLog.corrupt = 0
#guard healthyLog.clean = true
#guard interruptedLog.readable = 2
#guard fusedLog.readable = 2
#guard repairedLog.readable = 3
#guard fusedLog.corrupt = 1
#guard repairedLog.corrupt = 1
#guard fusedLog.clean = false
#guard repairedLog.clean = false
#guard fusedLog.lines.length = 3
#guard repairedLog.lines.length = 4
#guard fusedLog.readable < repairedLog.readable
#guard (appendNaive "{\"n\":9}" healthyLog).readable = 3
#guard (appendSafe "{\"n\":9}" healthyLog).readable = 3
#guard appendSafe "{\"n\":9}" healthyLog = appendNaive "{\"n\":9}" healthyLog

end RotLogAtomicity
