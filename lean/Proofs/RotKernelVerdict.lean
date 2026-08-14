/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A fix that compares a whole string to `"TIMEOUT"` never fires

**Measured 2026-08-14.** The prover hook must tell three states apart:

| verdict | meaning |
|---|---|
| `rejected` | the kernel refused a proof — stop everything |
| `unfinished` | the re-check never completed — not a pass, and not a fail |
| clean | nothing to say |

The `unfinished` state was added on 2026-08-08 after a timeout was reported as a
rejection and, in the words of the comment left behind, *"sent a session to
repair proofs that were fine"*. The repair was written, documented at length,
believed — **and never once fired.**

It tested the *entire* reason string for equality:

```
const UNFINISHED = ["TIMEOUT", "NOT_FOUND"];
UNFINISHED.indexOf(reason.toUpperCase()) >= 0
```

while the producer, `~/.claude/reminders/lean4-prover-reminder.ps1`, writes
parameterised text — measured, three shapes and no others:

```
reason = "TIMEOUT after ${perModuleTimeoutSec}s"
reason = "LAUNCH_FAILED: $($_.Exception.Message)"
reason = "exit=$code $first"
```

`"TIMEOUT AFTER 90S"` is not equal to `"TIMEOUT"`, so every timeout kept the
full rejection alarm. On this machine `Proofs.RotVacuity` and `Proofs.RotRoute`
were accused of kernel rejection while both re-verify at exit 0 with **zero
bytes**, under memory pressure that made `leanchecker` emit `std::bad_alloc` and
`failed to read file '<...>.olean.private'` — a *different* mathlib file on each
attempt, which is how exhaustion is told apart from corruption.

## Why this is a theorem and not another test

The defect is the exact shape this project calls a **dated spec**: a statement
pinned to *the constant that happens to hold today* instead of to *the property
that makes it safe*. `reason = "TIMEOUT"` was never a fact about the system; the
fact is that the reason **begins with** `TIMEOUT` and carries a duration that
moves. So the theorem is quantified over the part that moves:

```
∀ suffix, classify ("TIMEOUT" ++ suffix) = unfinished
```

`decide` on today's literal would have been green and worthless — it is exactly
what the broken code already did. `timeout_any_suffix_is_unfinished` is green
for **every** duration the watchdog will ever print, including ones nobody has
written yet.

## The modelling choice, stated

Everything below is over `List Char`, not `String`. Concatenated strings are the
usual reason an obviously-true goal will not close, and prefix reasoning on
`List` is structural. `String` is the *rendering*; the `#guard`s at the bottom
pin the rendering to the model so the two cannot drift apart.
-/

namespace RotKernelVerdict

/-- What the hook may conclude about one module from the watchdog's reason. -/
inductive Verdict
  /-- The kernel refused a proof. The alarm must shout. -/
  | rejected
  /-- The check never completed. Not a pass, and emphatically not a rejection. -/
  | unfinished
  deriving DecidableEq, Repr

/-- The reasons that mean **the question was never answered**, as prefixes.
These are the producer's own leading tokens, measured — not invented. -/
def unfinishedPrefixes : List (List Char) :=
  ["TIMEOUT".toList, "NOT_FOUND".toList, "LAUNCH_FAILED".toList]

/-- The reasons that mean **the host ran out of resources**. These arrive
embedded in `"exit=$code $first"`, so they are matched anywhere in the text
rather than at the front. -/
def unfinishedInfixes : List (List Char) :=
  ["BAD_ALLOC".toList, "OUT OF MEMORY".toList,
   "INTERNAL PANIC".toList, "FAILED TO READ FILE".toList]

/-- `t` occurs somewhere in `s`. -/
def hasInfix (t s : List Char) : Bool :=
  t.isPrefixOf s || match s with
    | []      => false
    | _ :: cs => hasInfix t cs

/-- The classifier the hook actually runs, modelled.
**FAIL LOUD ON THE UNKNOWN**: `rejected` is the default. A reason this list has
never seen keeps the full alarm, because the safe default for an unrecognised
failure is to shout. -/
def classify (reason : List Char) : Verdict :=
  if unfinishedPrefixes.any (fun p => p.isPrefixOf reason) then .unfinished
  else if unfinishedInfixes.any (fun t => hasInfix t reason) then .unfinished
  else .rejected

/-! ## The lemma the whole file rests on -/

/-- Any list is a prefix of itself extended by anything. Proved by induction
rather than looked up, so it holds for every suffix and not merely the ones
someone thought to test. -/
theorem isPrefixOf_self_append (p suf : List Char) :
    p.isPrefixOf (p ++ suf) = true := by
  induction p with
  | nil => simp [List.isPrefixOf]
  | cons a as ih => simp [ih]

/-! ## The theorem the bug violated -/

/-- **A timeout is a non-answer, for every duration the watchdog will ever
print.** This is the statement the 2026-08-08 fix believed it was making. It
quantifies over `suffix`, so `"TIMEOUT after 90s"`, `"TIMEOUT after 3600s"` and
any future wording of the tail are all covered. -/
theorem timeout_any_suffix_is_unfinished (suffix : List Char) :
    classify ("TIMEOUT".toList ++ suffix) = .unfinished := by
  simp [classify, unfinishedPrefixes]

/-- The same guarantee for the checker that never started. -/
theorem launch_failed_any_suffix_is_unfinished (suffix : List Char) :
    classify ("LAUNCH_FAILED".toList ++ suffix) = .unfinished := by
  simp [classify, unfinishedPrefixes]

/-- And for the module that was not there to check. -/
theorem not_found_any_suffix_is_unfinished (suffix : List Char) :
    classify ("NOT_FOUND".toList ++ suffix) = .unfinished := by
  simp [classify, unfinishedPrefixes]

/-! ## The other direction — without it, "demote everything" would pass -/

/-- A resource failure is demoted **wherever it appears** in the reason, which
is what `"exit=1 ... std::bad_alloc"` requires: the marker is not at the front.
Proved for every prefix, so it does not depend on the exit code or the wording
the runtime happens to put in front of it. -/
theorem bad_alloc_anywhere_is_unfinished (before : List Char) :
    hasInfix "BAD_ALLOC".toList (before ++ "BAD_ALLOC".toList) = true := by
  induction before with
  | nil => simp [hasInfix]
  | cons a as ih =>
      simp only [List.cons_append, hasInfix, Bool.or_eq_true]
      exact Or.inr ih

/-- **A genuine rejection still shouts.** This is the theorem that keeps the
others honest: a classifier that demoted everything would satisfy every result
above and leave the alarm completely deaf.

Stated over *every* reason that matches no marker, rather than over one sampled
string. That is deliberate — a `decide` on today's literal is precisely the
mistake this file exists to record, and it would go green while saying almost
nothing. `#guard` at the bottom covers the concrete texts. -/
theorem unmatched_reason_shouts (r : List Char)
    (hp : unfinishedPrefixes.any (fun p => p.isPrefixOf r) = false)
    (hi : unfinishedInfixes.any (fun t => hasInfix t r) = false) :
    classify r = .rejected := by
  simp [classify, hp, hi]

/-- The classifier is total and two-valued: every reason lands in exactly one
state, so there is no third path that silently drops a module. -/
theorem classify_total (r : List Char) :
    classify r = .rejected ∨ classify r = .unfinished := by
  unfold classify
  split
  · exact Or.inr rfl
  · split
    · exact Or.inr rfl
    · exact Or.inl rfl

/-! ## The old logic, refuted rather than described

A comment saying the previous code was broken is a claim. This is a proof. -/

/-- The pre-fix predicate: whole-string equality against the bare tokens. -/
def oldIsUnfinished (reason : List Char) : Bool :=
  reason == "TIMEOUT".toList || reason == "NOT_FOUND".toList

/-- **The old predicate fires on exactly two inputs in the whole universe of
strings — and the producer emits neither.**

This is the refutation, and stating it this way is the point. A theorem reading
`oldIsUnfinished "TIMEOUT after 90s" = false` would sample one string; this says
the old logic is true for *nothing* except two exact literals. Everything else
in existence — every timeout the watchdog has ever printed or ever will —
falls through to the rejection alarm.

The second half of the argument is a measured fact about a file outside Lean
(`~/.claude/reminders/lean4-prover-reminder.ps1` writes
`"TIMEOUT after ${perModuleTimeoutSec}s"`, never a bare token), so it is checked
by `checker/kernel-verdict-class.sh`, not asserted here. Saying which half is
proved and which is measured is the whole discipline. -/
theorem old_logic_fires_only_on_two_exact_strings (r : List Char) :
    oldIsUnfinished r = true → r = "TIMEOUT".toList ∨ r = "NOT_FOUND".toList := by
  intro h
  simp [oldIsUnfinished] at h
  exact h

/-- **The repaired classifier does not have that weakness.** For every suffix,
the new logic demotes what the old one missed. Together with the theorem above,
this is the regression in two lines: the old predicate cannot fire on a
suffixed timeout, and the new one always does. -/
theorem new_logic_catches_what_old_logic_missed (suffix : List Char) :
    classify ("TIMEOUT".toList ++ suffix) = .unfinished :=
  timeout_any_suffix_is_unfinished suffix

/-! ## The model against the rendering

Executable checks, so a definition that does not mean what it reads cannot hide
behind a green build. -/

#guard classify "TIMEOUT after 90s".toList == .unfinished
#guard classify "TIMEOUT after 3600s".toList == .unfinished
#guard classify "LAUNCH_FAILED: The system cannot find the file specified.".toList == .unfinished
#guard classify "exit=1 libc++abi: std::BAD_ALLOC".toList == .unfinished
#guard classify "exit=1 leanchecker found a problem".toList == .rejected
#guard classify "exit=1 something nobody has seen before".toList == .rejected
#guard oldIsUnfinished "TIMEOUT after 90s".toList == false

end RotKernelVerdict
