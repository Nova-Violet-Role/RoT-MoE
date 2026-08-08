/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A guard that fails open, and a diagnosis that was invented

Two defects measured in `checker/ci-honesty.sh` on 2026-08-09, both found by
pointing the checker at a CI run that was still `pending`.

## One: the empty-payload guard failed open exactly when the payload was empty

The line read

    TOTAL_STEPS="$(grep -cE '"(conclusion)": ' "$JOBS_JSON" 2>/dev/null || echo 0)"
    if [ "${TOTAL_STEPS:-0}" -lt 5 ]; then ... exit 3 ; fi

`grep -c` PRINTS `0` and ALSO exits 1 when nothing matches. So on an empty
payload the substitution captured grep's `0`, the `|| echo 0` appended a second
`0`, and the variable became the two-token string `0 0`. `[ "0 0" -lt 5 ]` is
not a false comparison -- it is an ERROR. Bash printed
`[: 0: integer expression expected` and returned non-zero, which took the ELSE
branch. The guard against an empty payload waved the empty payload through, and
the checker then reported

    PASS  every step concluded success (0 steps read)

a pass asserted over the empty set, inside the very file whose job is to catch
that shape. Reproduced deliberately before repair: `guard FELL THROUGH`.

The lesson generalises past this one line: **a malformed reading must be a third
outcome, never folded into either verdict.** `some n` compares; `none` refuses.
Defaulting an unparseable value to `0` and comparing it is the same bug in a
politer costume, because `0` is a legitimate reading with an opposite meaning.

## Two: a network failure was reported as "you did not push"

Thirty seconds after a successful push, a DNS blip
(`curl: (6) Could not resolve host: api.github.com`) produced an empty body, and
the checker announced *"This commit has not been pushed, so there is no run to
judge."* The commit had been pushed. The exit code was right -- 3, a skip, never
a pass -- so nothing green was faked. But the DIAGNOSIS was invented, and a
wrong diagnosis costs the next person a pointless push instead of a look at
their network.

Two causes, one message. This module proves that the old mapping is not
injective and the repaired one is: the API being unreachable and the API
answering *no such run* are different facts and must print differently, even
though they agree on the verdict.
-/

namespace RotMoE.Guard

/-! ## Part one: reading a count that may be malformed -/

/-- What the shell substitution captured, as tokens. The real defect produced
two tokens where one was expected. -/
abbrev Reading := List String

/-- A well-formed reading: exactly one token, all digits. Modelled by carrying
the number, since the point is the SHAPE of the reading, not decimal parsing. -/
inductive Parsed where
  /-- A single numeric token was read. -/
  | count (n : Nat)
  /-- Nothing usable: no token, several tokens, or a non-numeric token. -/
  | malformed
  deriving DecidableEq, Repr

/-- The three verdicts a guard may reach. `refuse` is a genuine third outcome,
not a flavour of either other one -- that is the whole repair. -/
inductive Verdict where
  /-- Enough data; carry on and judge. -/
  | proceed
  /-- Too little data to judge; stop and say so. -/
  | refuse
  /-- Payload present but under the minimum. -/
  | tooFew
  deriving DecidableEq, Repr

/-- The measured failure: `grep -c` printed `0` and `|| echo 0` printed another. -/
def theMeasuredReading : Reading := ["0", "0"]

/-- A healthy reading of a real run. -/
def aHealthyReading : Reading := ["158"]

/-- Parsing, modelled on token count. One numeric token parses; anything else
is malformed. -/
def parse (r : Reading) (value : Nat) : Parsed :=
  match r with
  | [_] => Parsed.count value
  | _ => Parsed.malformed

/-- **The old guard.** An unparseable reading made `[` error, and a non-zero
test status takes the else branch -- so malformed became `proceed`. -/
def oldGuard : Parsed → Verdict
  | Parsed.count n => if n < 5 then Verdict.tooFew else Verdict.proceed
  | Parsed.malformed => Verdict.proceed

/-- **The repaired guard.** Malformed is its own answer. -/
def newGuard : Parsed → Verdict
  | Parsed.count n => if n < 5 then Verdict.tooFew else Verdict.proceed
  | Parsed.malformed => Verdict.refuse

/-- **The defect, stated.** On the reading that actually occurred, the old guard
proceeds -- with no data behind it. -/
theorem old_guard_fails_open :
    oldGuard (parse theMeasuredReading 0) = Verdict.proceed := by decide

/-- **The repair.** The same reading now refuses. -/
theorem new_guard_refuses_the_measured_reading :
    newGuard (parse theMeasuredReading 0) = Verdict.refuse := by decide

/-- **And the repair changes nothing else.** On every well-formed reading the
two guards agree, for every count -- so this is a strictly added refusal, not a
loosened or altered threshold. -/
theorem guards_agree_on_wellformed (tok : String) (n : Nat) :
    oldGuard (parse [tok] n) = newGuard (parse [tok] n) := by
  cases Nat.lt_or_ge n 5 with
  | inl h => simp [parse, oldGuard, newGuard, h]
  | inr h => simp [parse, oldGuard, newGuard, Nat.not_lt.mpr h]

/-- A healthy payload still proceeds. -/
theorem healthy_payload_proceeds :
    newGuard (parse aHealthyReading 158) = Verdict.proceed := by decide

/-- A short payload is still distinguished from a malformed one -- three
outcomes, three meanings. -/
theorem short_and_malformed_are_different :
    newGuard (parse ["3"] 3) = Verdict.tooFew
      ∧ newGuard (parse theMeasuredReading 0) = Verdict.refuse
      ∧ Verdict.tooFew ≠ Verdict.refuse := by decide

/-- **Refusal is not a pass.** Stated so the exit-code convention cannot drift:
whatever else changes, `refuse` must never be read as `proceed`. -/
theorem refusal_is_not_proceeding : Verdict.refuse ≠ Verdict.proceed := by decide

/-- **Defaulting to zero would NOT have fixed it.** The tempting one-character
repair -- treat an unreadable count as 0 -- lands on `tooFew`, which is a
*claim about the payload* rather than an admission that nothing was read. -/
theorem defaulting_to_zero_is_not_a_repair :
    oldGuard (Parsed.count 0) = Verdict.tooFew
      ∧ Verdict.tooFew ≠ Verdict.refuse := by decide

/-! ## Part two: two causes must not share one message -/

/-- What actually happened when the run was queried. -/
inductive Outcome where
  /-- curl could not reach the API at all. -/
  | unreachable (curlExit : Nat)
  /-- The API answered, and listed no run for this commit. -/
  | noRunListed
  /-- The API answered with a run. -/
  | run (id : Nat)
  deriving DecidableEq, Repr

/-- What the checker tells the reader. -/
inductive Message where
  /-- "This commit has not been pushed." -/
  | notPushed
  /-- "The API could not be reached." -/
  | apiDown
  /-- A verdict about a real run. -/
  | judged (id : Nat)
  deriving DecidableEq, Repr

/-- **The old mapping.** Both failure causes printed the same sentence. -/
def oldMessage : Outcome → Message
  | Outcome.unreachable _ => Message.notPushed
  | Outcome.noRunListed => Message.notPushed
  | Outcome.run id => Message.judged id

/-- **The repaired mapping.** -/
def newMessage : Outcome → Message
  | Outcome.unreachable _ => Message.apiDown
  | Outcome.noRunListed => Message.notPushed
  | Outcome.run id => Message.judged id

/-- **The defect.** Two different facts, one sentence -- so the reader cannot
recover which happened. The measured case is `curlExit = 6`. -/
theorem old_message_conflates_two_causes :
    oldMessage (Outcome.unreachable 6) = oldMessage Outcome.noRunListed
      ∧ Outcome.unreachable 6 ≠ Outcome.noRunListed := by decide

/-- **The repair distinguishes them.** -/
theorem new_message_separates_them :
    newMessage (Outcome.unreachable 6) ≠ newMessage Outcome.noRunListed := by decide

/-- The honest part: the old code's VERDICT was already correct. Both causes are
a skip, and the repair does not change that -- it changes only what the reader
is told. Overstating this fix as "it stopped faking green" would be false; it
never faked green. -/
def isSkip : Message → Bool
  | Message.notPushed => true
  | Message.apiDown => true
  | Message.judged _ => false

/-- Both mappings skip on both failure causes; the exit code was never wrong. -/
theorem the_verdict_was_always_right :
    isSkip (oldMessage (Outcome.unreachable 6)) = true
      ∧ isSkip (newMessage (Outcome.unreachable 6)) = true
      ∧ isSkip (oldMessage Outcome.noRunListed) = true
      ∧ isSkip (newMessage Outcome.noRunListed) = true := by decide

/-- And a real run is still judged, unchanged, by both. -/
theorem a_real_run_is_still_judged (id : Nat) :
    oldMessage (Outcome.run id) = newMessage (Outcome.run id) := by
  simp [oldMessage, newMessage]

/-! ## Part three: the status you read was not the status of what you ran

Found 2026-08-09 in my OWN gating harness, minutes after proving Part one about
someone else's. The loop was

    for g in ...; do bash "$g" > "log" 2>&1; echo "$(basename $g) EXIT=$? ..."; done

and it reported `EXIT=0` for a gate that had just printed **five FAIL lines**.
The shell expands a word list LEFT TO RIGHT, so `$(basename $g)` runs -- and
succeeds -- BEFORE `$?` is expanded. The status read is `basename`'s, which is
always 0. Every gate in that loop reported green unconditionally.

The repo's standing rule is *read exit codes DIRECTLY, never through a pipe*.
This is the same defect wearing a different costume: not a pipe, a command
substitution sitting earlier in the same line. The rule is really **nothing may
run between the command and the read**, and `$(...)` is something running.

It was caught only because a gate's own log carried an independent verdict line
that contradicted the harness. That redundancy is the reason this is a story
about a caught bug rather than a shipped one -- and the argument for every
checker printing its own verdict rather than relying on its exit code alone.
-/

/-- A command that ran, and what it returned. -/
structure Ran where
  /-- Which command this was. -/
  name : String
  /-- Its exit status. -/
  status : Nat
  deriving DecidableEq, Repr

/-- The gate that was actually under test, and failed. -/
def theGate : Ran := { name := "repo-complete", status := 1 }

/-- The incidental command the shell ran while building the message. -/
def theSubstitution : Ran := { name := "basename", status := 0 }

/-- Reading a status DIRECTLY: nothing runs in between. -/
def readDirect (cmd : Ran) : Nat := cmd.status

/-- Reading a status with something else expanded first: `$?` now belongs to
whatever ran last, which is the interloper. -/
def readAfter (_cmd interloper : Ran) : Nat := interloper.status

/-- A reading is honest when it reports the status of the command it names. -/
def honest (cmd : Ran) (reading : Nat) : Bool := reading == cmd.status

/-- **The false green.** The gate exited 1, and the harness reported 0. -/
theorem the_harness_reported_green_for_a_red_gate :
    readAfter theGate theSubstitution = 0 ∧ theGate.status = 1 := by decide

/-- Stated as the dishonesty it is. -/
theorem the_indirect_reading_was_not_honest :
    honest theGate (readAfter theGate theSubstitution) = false := by decide

/-- **The direct reading is honest for every command**, which is the whole rule:
put the read first and nothing can displace it. -/
theorem direct_reading_is_always_honest (cmd : Ran) :
    honest cmd (readDirect cmd) = true := by
  simp [honest, readDirect]

/-- **Why it is so dangerous: it fails in the reassuring direction.** Whenever
the interloper succeeds, the indirect reading says success -- no matter what the
real command did. A harness built this way cannot report a failure at all. -/
theorem a_succeeding_interloper_hides_every_failure (cmd interloper : Ran)
    (h : interloper.status = 0) : readAfter cmd interloper = 0 := by
  simp [readAfter, h]

/-- And it is not merely unreliable, it is *blind*: the reading does not depend
on the command's status in any way. Two gates with opposite outcomes read the
same. -/
theorem the_reading_ignores_the_command (a b interloper : Ran) :
    readAfter a interloper = readAfter b interloper := by
  simp [readAfter]

/-- The redundancy that caught it: the gate's own log said `5 failed` while the
harness said 0. Two instruments, one disagreement, and the disagreement is the
signal. -/
def logSaysFailed : Nat := 5

/-- **The contradiction, stated.** A harness reading 0 while the log reports
failures is not a green -- it is evidence the reader is broken. -/
theorem log_and_harness_disagreed :
    readAfter theGate theSubstitution = 0 ∧ logSaysFailed ≠ 0 := by decide

/-! ## Executable checks -/

/-- The measured reading, parsed and guarded, both ways. -/
example : (oldGuard (parse theMeasuredReading 0), newGuard (parse theMeasuredReading 0))
    = (Verdict.proceed, Verdict.refuse) := by decide

/-- The measured DNS failure, messaged both ways. -/
example : (oldMessage (Outcome.unreachable 6), newMessage (Outcome.unreachable 6))
    = (Message.notPushed, Message.apiDown) := by decide

end RotMoE.Guard
