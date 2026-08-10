/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A counter that cannot refuse cannot measure

**Measured 2026-08-10.** `checker/count-theorems.sh` had three paths to `0` with
exit `0`, each indistinguishable from an honest count of zero:

| invocation | why it returned 0 | exit |
|---|---|---|
| no arguments | `for f in "$@"` never iterates | 0 |
| a missing file | awk fatal, `$(...)` empty, `total=$((total + ))` is a syntax error, no `set -e` | 0 |
| an unexpanded glob | same path as a missing file | 0 |

`checker/axiom-audit.sh:291` then swallowed even the stderr with `2>/dev/null`
and `n=${n:-0}`.

This matters because the count is a **ratchet**: the manifests publish it and CI
asserts it never drops. An instrument that reports `0` for *"I was handed
nothing"* lets the ratchet be satisfied by handing it nothing — the count falls to
zero and every check stays green, because zero is not less than zero.

The theorem that names the defect is `zero_is_ambiguous_under_naive`: the naive
reporter maps **two invocations with different meanings** — "no input at all" and
"one real file containing no declarations" — onto the *same* observation. No
consumer downstream can recover the difference, because the information was
destroyed at the instrument. `honest_separates_them` is the repair.

The durable statement is `a_report_requires_every_file_read`, quantified over any
invocation: a report is emitted only when the number of files read equals the
number handed in. It names no constant, so it does not expire when the corpus
grows.

**Not modelled.** Whether the awk counter classifies a given line as a declaration
is a property of Lean's grammar and of that awk program, not of this file. That
is covered empirically by `count-theorems.sh --selftest`, which pins prose
mentioning `theorem` as *not* counted. Here the subject is only the arity and the
refusal behaviour.
-/

namespace RotCounter

/-- One invocation of the counter, reduced to what decides whether its number
means anything. -/
structure Invocation where
  /-- how many paths the counter was handed -/
  files   : Nat
  /-- how many of those existed and were actually read -/
  present : Nat
  /-- declarations found in the files that were read -/
  decls   : Nat
deriving Repr, DecidableEq

/-- The shipped behaviour before the repair: always succeed, report whatever the
loop accumulated. -/
def naiveExit (_ : Invocation) : Nat := 0

/-- What every consumer reads. -/
def report (i : Invocation) : Nat := i.decls

/-- The repair: refuse an empty invocation, and refuse when any handed-in file
was not read. -/
def honestExit (i : Invocation) : Nat :=
  if i.files = 0 then 2
  else if i.present ≠ i.files then 2
  else 0

/-! ## Part 1 — the defect -/

/-- The old instrument **could not fail**, for any input whatsoever. -/
theorem naive_cannot_fail (i : Invocation) : naiveExit i = 0 := rfl

/-- Refusing an empty invocation, for every invocation with no files. -/
theorem honest_refuses_an_empty_invocation (i : Invocation) (h : i.files = 0) :
    honestExit i = 2 := by
  unfold honestExit; rw [if_pos h]

/-- Refusing whenever a handed-in file was not read — a missing path or an
unexpanded glob. -/
theorem honest_refuses_an_unread_file (i : Invocation) (h : i.present < i.files) :
    honestExit i = 2 := by
  unfold honestExit
  split
  · rfl
  · rw [if_pos (Nat.ne_of_lt h)]

/-- **The durable statement.** A number is emitted only when every file handed in
was read. Quantified over all invocations; mentions no constant. -/
theorem a_report_requires_every_file_read (i : Invocation) (h : honestExit i = 0) :
    i.present = i.files ∧ i.files ≠ 0 := by
  unfold honestExit at h
  split at h
  · exact absurd h (by decide)
  · next hf =>
    split at h
    · exact absurd h (by decide)
    · next hp => exact ⟨by omega, hf⟩

/-- The repair only ever refuses more; it never rejects a run the old one
accepted *and* that was complete. -/
theorem honest_accepts_only_complete_runs (i : Invocation)
    (hf : i.files ≠ 0) (hp : i.present = i.files) : honestExit i = 0 := by
  unfold honestExit
  rw [if_neg hf, if_neg (by simp [hp])]

/-! ## Part 2 — the two invocations the old instrument could not tell apart -/

/-- Handed nothing at all. -/
def noInput : Invocation := ⟨0, 0, 0⟩

/-- One real file that genuinely contains no declarations. -/
def honestZero : Invocation := ⟨1, 1, 0⟩

/-- Three files handed in, one missing — the unexpanded-glob shape. -/
def oneMissing : Invocation := ⟨3, 2, 71⟩

/-- The measured corpus at the time of writing. -/
def measuredRun : Invocation := ⟨61, 61, 1163⟩

/-- **The defect, named.** Two invocations that mean different things produce an
identical observation under the old instrument, so the difference is not
recoverable by any consumer. -/
theorem zero_is_ambiguous_under_naive :
    (report noInput, naiveExit noInput) = (report honestZero, naiveExit honestZero) := by
  decide

/-- **The repair.** The honest exit code distinguishes exactly those two. -/
theorem honest_separates_them : honestExit noInput ≠ honestExit honestZero := by
  decide

/-- The ratchet attack the old instrument permitted: a strictly smaller number,
reported successfully, without a single theorem having been lost — obtained by
handing the counter nothing. -/
theorem naive_admits_a_drop_that_lost_no_theorem :
    ∃ before after : Invocation,
      naiveExit before = 0 ∧ naiveExit after = 0 ∧
      report after < report before ∧ after.files = 0 :=
  ⟨measuredRun, noInput, rfl, rfl, by decide, rfl⟩

/-- And the repair refuses that exact move. -/
theorem honest_refuses_the_fake_drop : honestExit noInput ≠ 0 := by decide

-- the four paths that used to return 0 exit 0
#guard honestExit noInput    = 2
#guard honestExit oneMissing = 2
#guard naiveExit  noInput    = 0
-- an honest zero must still be reportable, or the repair broke a real use
#guard honestExit honestZero = 0
#guard report     honestZero = 0
#guard honestExit measuredRun = 0
#guard report     measuredRun = 1163

end RotCounter
