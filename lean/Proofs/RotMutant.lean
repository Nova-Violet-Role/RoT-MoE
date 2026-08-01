/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

/-!
# A mutation that did not land is EVIDENCE ABOUT THE HARNESS, not about the check

Every mutation harness in this repository answers one question: *is this
assertion load-bearing?* It breaks the thing on purpose, re-runs the assertion,
and records whether the assertion noticed.

There are **three** outcomes, and collapsing them into two is how a mutation
suite lies in the reassuring direction.

    KILLED     the patch applied, and the assertion REJECTED the result
               -> the assertion is load-bearing on this mutation
    SURVIVED   the patch applied, and the assertion ACCEPTED the result
               -> the assertion is blind to this mutation
    DISCARDED  the patch never applied
               -> NOTHING WAS TESTED. This says something about the harness
                  and nothing whatever about the assertion.

`DISCARDED` reads like `KILLED` on a summary line and means the opposite of
both. A harness that cannot tell them apart reports "62 mutants, 62 killed"
while testing 61 of them, or none.

## Measured, twice, on 2026-08-01 — both routes into the same false green

**Route 1 — the patch changes nothing.** `checker/verdict-stability.sh` mutated
a `git commit` line that a redesign had deleted. `sed` matched nothing and wrote
the file back byte-identically. The harness compared mutant to original, saw no
difference and reported *did not apply — discarded, not survived*. That is the
correct behaviour and it turned the gate red, which is how the defect surfaced.

**Route 2 — the patch destroys everything.** The replacement control's `sed`
program was malformed. `sed` exited non-zero and wrote an **empty** file. Empty
is *different* from the original, so the "did it change anything" test passed it
through; the assertion then rejected the empty file for lacking every structure
it requires; and the harness printed **PASS** next to a visible
`sed: unterminated 's' command`. A patch that destroyed the file was scored as
evidence that the check works.

Route 1 was already handled. Route 2 was not, and no amount of re-running found
it — it *looked* green. The difference between the two is one line of shell and
one line of reasoning, and this module is the reasoning.

## What is modelled

A mutant is characterised by three observables the shell harness really has:
the patch tool's exit status, whether the output is empty, and whether the
output differs from the original. `classify` maps those to an outcome, and
`accepts` is the assertion under test. Nothing here models *what* the patch did
— it does not need to. The claim is about **when a result may be counted**, and
that is decidable from the three observables alone.

The theorems are deliberately stated over ALL inputs rather than over the two
cases that were measured: a spec that named today's two bugs would be green
today and useless against the third route.
-/

namespace RotMoE

/-- What a single mutation run is allowed to conclude. -/
inductive Outcome where
  /-- The patch applied and the assertion rejected the result. -/
  | killed : Outcome
  /-- The patch applied and the assertion accepted the result. -/
  | survived : Outcome
  /-- The patch never applied. Nothing about the assertion was tested. -/
  | discarded : Outcome
  deriving DecidableEq, Repr

/-- The three observables a shell harness actually has after running its patch
tool: the tool's exit status, whether the produced file is empty, and whether it
differs from the original. -/
structure Run where
  /-- Exit status of the patch tool (`sed`, `perl`, an AST edit). 0 is success. -/
  toolExit : Nat
  /-- Is the produced mutant empty? An empty file is never a legitimate mutant
  of a non-empty source. -/
  empty : Bool
  /-- Does the produced mutant differ from the original? -/
  changed : Bool
  deriving DecidableEq, Repr

/-- A patch LANDED only if the tool succeeded, the result is non-empty, and it
actually differs from the original. All three are required: dropping any one of
them is precisely a defect that shipped. -/
def landed (r : Run) : Bool :=
  r.toolExit == 0 && !r.empty && r.changed

/-- The classification. `accepts` is the verdict of the assertion under test on
the mutated input — `true` means the assertion was happy with the broken file.

The order matters and is the whole point: whether the patch landed is decided
**before** the assertion's opinion is consulted. An assertion's verdict on a
file that was never validly produced carries no information. -/
def classify (r : Run) (accepts : Bool) : Outcome :=
  if landed r then (if accepts then Outcome.survived else Outcome.killed)
  else Outcome.discarded

/-- A mutation may be counted as evidence about the assertion only when it
landed. -/
def counts (o : Outcome) : Bool :=
  o != Outcome.discarded

/-! ## The theorems -/

/-- **The central claim.** If the patch did not land, the outcome is `discarded`
— whatever the assertion said about the wreckage. This is the statement that
route 1 and route 2 both violate, and it is quantified over every `accepts`, so
it cannot be satisfied by a harness that merely happens to be right today. -/
theorem not_landed_discarded (r : Run) (accepts : Bool) (h : landed r = false) :
    classify r accepts = Outcome.discarded := by
  simp [classify, h]

/-- A failing patch tool can never produce a kill. This is route 2 exactly:
`sed` exited 1, and the harness printed a pass. -/
theorem tool_failed_never_killed (r : Run) (accepts : Bool) (h : r.toolExit ≠ 0) :
    classify r accepts ≠ Outcome.killed := by
  have : landed r = false := by
    simp [landed, beq_iff_eq, h]
  simp [classify, this]

/-- An empty mutant can never produce a kill, even when the tool reported
success. `sed` can exit 0 and still write nothing. -/
theorem empty_never_killed (r : Run) (accepts : Bool) (h : r.empty = true) :
    classify r accepts ≠ Outcome.killed := by
  have : landed r = false := by simp [landed, h]
  simp [classify, this]

/-- An unchanged file can never produce a kill. This is route 1: the `sed`
matched nothing, so the "mutant" is the original and the assertion's verdict on
it is a statement about the ORIGINAL, not about any mutation. -/
theorem unchanged_never_killed (r : Run) (accepts : Bool) (h : r.changed = false) :
    classify r accepts ≠ Outcome.killed := by
  have : landed r = false := by simp [landed, h]
  simp [classify, this]

/-- Nothing that failed to land is ever counted. -/
theorem discarded_never_counts (r : Run) (accepts : Bool) (h : landed r = false) :
    counts (classify r accepts) = false := by
  simp [counts, not_landed_discarded r accepts h]

/-- **The converse, and it is what stops this spec being vacuous.** When the
patch really landed, the outcome follows the assertion and is always counted. A
"safe" harness that discarded everything would satisfy every theorem above and
test nothing; this forbids it. -/
theorem landed_counts (r : Run) (accepts : Bool) (h : landed r = true) :
    counts (classify r accepts) = true := by
  cases accepts <;> simp [counts, classify, h]

/-- A landed patch the assertion REJECTS is a kill — the only way to earn one. -/
theorem landed_rejected_killed (r : Run) (h : landed r = true) :
    classify r false = Outcome.killed := by
  simp [classify, h]

/-- A landed patch the assertion ACCEPTS is a survivor, never silently a kill.
This is the direction that keeps a harness honest about its blind spots. -/
theorem landed_accepted_survived (r : Run) (h : landed r = true) :
    classify r true = Outcome.survived := by
  simp [classify, h]

/-- `killed` requires ALL THREE landing conditions. Stated as one theorem
because a harness that checks two of the three is exactly what shipped: the
original `ctl` tested `changed` alone, which is why an empty file passed. -/
theorem killed_implies_all_three (r : Run) (accepts : Bool)
    (h : classify r accepts = Outcome.killed) :
    r.toolExit = 0 ∧ r.empty = false ∧ r.changed = true := by
  by_cases hl : landed r = true
  · have h3 : (r.toolExit == 0) = true ∧ (!r.empty) = true ∧ r.changed = true := by
      simpa [landed, Bool.and_eq_true, and_assoc] using hl
    exact ⟨by simpa using h3.1, by simpa using h3.2.1, h3.2.2⟩
  · rw [classify, if_neg hl] at h
    exact absurd h (by decide)

/-- The three outcomes are genuinely distinct. Without this the whole
distinction could collapse and every theorem above would still elaborate. -/
theorem outcomes_distinct :
    Outcome.killed ≠ Outcome.survived ∧
    Outcome.killed ≠ Outcome.discarded ∧
    Outcome.survived ≠ Outcome.discarded := by
  refine ⟨?_, ?_, ?_⟩ <;> decide

/-! ## Executable witnesses

The theorems are over all `Run`s; these run the definitions on the two failures
actually measured on 2026-08-01, so the model is pinned to the events rather
than floating free of them. `#guard` fails the build if any disagrees. -/

/-- Route 2, measured: `sed` exited 1 and wrote an empty file. The assertion
rejected that empty file (`accepts = false`), and the old harness called it a
kill. The model says `discarded`. -/
def route2 : Run := { toolExit := 1, empty := true, changed := true }
#guard classify route2 false = Outcome.discarded
#guard counts (classify route2 false) = false

/-- Route 1, measured: `sed` succeeded but matched nothing, so the mutant was
byte-identical to the original. -/
def route1 : Run := { toolExit := 0, empty := false, changed := false }
#guard classify route1 false = Outcome.discarded

/-- A real, landed mutation that the assertion caught — the only shape that may
be reported as a kill. -/
def landedKill : Run := { toolExit := 0, empty := false, changed := true }
#guard classify landedKill false = Outcome.killed
#guard counts (classify landedKill false) = true

-- The same landed mutation when the assertion is blind to it.
#guard classify landedKill true = Outcome.survived

-- EXHAUSTIVE: over every combination of the three observables and both
-- assertion verdicts, `killed` occurs only where all three landing conditions
-- hold. A decidable check over the whole finite space, not a sample.
#guard
  (List.range 2).all fun e =>
    [true, false].all fun em =>
      [true, false].all fun ch =>
        [true, false].all fun acc =>
          let r : Run := { toolExit := e, empty := em, changed := ch }
          (classify r acc == Outcome.killed) == (e == 0 && !em && ch && !acc)

end RotMoE
