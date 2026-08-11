/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A change detector that cannot tell "unchanged" from "never measured"

Run 31367304632 of `verify.yml` finished **green** with two steps skipped:

    JOB: publish the verdict -> success
       step 5 | Write STATUS.md (only when the verdict changed) -> skipped
       step 6 | Publish the verdict, and FAIL if the committed one is stale -> skipped

Step 6 is the one that fails the job when the committed verdict is stale. A green
job whose staleness check never ran is exactly the shape the promise forbids, so
it was worth reading rather than assuming.

**The skips are legitimate.** Both carry `if: steps.decide.outputs.changed == 'yes'`
and the verdict genuinely had not changed. The defect is one layer below them, in
how `changed` is computed:

    if diff -q /tmp/verdict.old /tmp/verdict.new >/dev/null 2>&1; then
      echo "changed=no" >> "$GITHUB_OUTPUT"

`/tmp/verdict.old` is `awk`-extracted from between two markers in `STATUS.md`, and
is deliberately empty when the file or the markers are absent. `/tmp/verdict.new`
is the stdout of `checker/status-verdict.sh`. Measured on this machine, five
lines, both directions:

    two empty files      -> diff says IDENTICAL -> changed=no -> both steps SKIP -> job GREEN
    empty vs non-empty   -> differ                                              (correct)

So if the generator ever produces nothing while exiting 0 — a renamed marker, a
`grep` that matches no rows, an early `return` — the comparison succeeds against
an equally empty predecessor, the workflow prints *"verdict UNCHANGED — this is
the correct outcome"*, the staleness check skips, and the job is green. Nothing
was measured and the log says everything is fine.

This is the same defect the repository already fixed once in a different place:
an emptied file is invisible to every check that reads its text. Equality is not
evidence when both sides can vanish together.

The repair is not to distrust equality. It is to notice that the detector has
**three** outcomes and only ever admitted two.
-/

namespace RotMoE.VerdictDecision

/-- The verdict as the workflow handles it: the lines between the two markers. -/
abbrev Verdict := List String

/-- What the current step can say. -/
def changed (old new : Verdict) : Bool := old != new

/-- What it should be able to say. `unmeasured` is not a third kind of change; it
is the admission that the question was never answered. -/
inductive Decision where
  | unchanged
  | changed
  | unmeasured
  deriving DecidableEq, Repr

/-- The repaired decision. The new verdict must exist before its equality with
anything is worth reading. -/
def honest : Verdict → Verdict → Decision
  | _, [] => .unmeasured
  | old, (a :: as) => if old == (a :: as) then .unchanged else .changed

/-! ## The blindness, decided -/

/-- **The two situations the current step cannot separate.** A verdict that
genuinely did not change and a verdict that was never produced both come back as
`changed = false`, and the workflow prints the same reassuring sentence for both. -/
theorem a_vanished_verdict_looks_exactly_like_an_unchanged_one :
    changed ["gates: 58/58", "theorems: 1322"] ["gates: 58/58", "theorems: 1322"] = false ∧
    changed [] [] = false := by decide

/-- The honest decision separates them, on the same two inputs. -/
theorem the_repair_separates_them :
    honest ["gates: 58/58", "theorems: 1322"] ["gates: 58/58", "theorems: 1322"] = .unchanged ∧
    honest [] [] = .unmeasured := by decide

/-- **Stated generally, over every possible previous verdict**: an absent new
verdict is never reported as unchanged. This is the property the workflow needs;
the witness above is only an instance of it. -/
theorem an_absent_verdict_is_never_called_unchanged (old : Verdict) :
    honest old [] = .unmeasured := rfl

/-- And it is never called changed either — `unmeasured` is its own answer rather
than a lean towards either side, so the repair cannot be accused of making the job
noisy in the other direction. -/
theorem an_absent_verdict_is_not_reported_as_a_change (old : Verdict) :
    honest old [] ≠ .changed := by simp [honest]

/-! ## The repair costs nothing on real input

A stricter check is only worth having if it agrees with the old one everywhere the
old one was right. Both directions are stated over arbitrary verdicts, so no
future measurement can invalidate them. -/

/-- Whenever a verdict was actually produced, the honest decision reports a change
exactly when the old one did. -/
theorem the_repair_agrees_wherever_the_old_check_was_meaningful
    (old new : Verdict) (h : new ≠ []) :
    (honest old new = .changed) ↔ (changed old new = true) := by
  cases new with
  | nil => exact absurd rfl h
  | cons a as =>
    by_cases hb : old = a :: as
    · subst hb; simp [honest, changed]
    · simp [honest, changed, hb]

/-- The same on the other side: a real verdict identical to the committed one is
still `unchanged`, so the weekly job still stays quiet when nothing moved. -/
theorem an_unchanged_real_verdict_is_still_unchanged (v : Verdict) (h : v ≠ []) :
    honest v v = .unchanged := by
  cases v with
  | nil => exact absurd rfl h
  | cons a as => simp [honest]

/-! ## What the job may do with each answer

The point of the third outcome is that it changes the action, not just the log. -/

/-- May the job stay green and skip its publishing steps? Only on a measured
`unchanged`. -/
def maySkipQuietly (d : Decision) : Bool :=
  match d with
  | .unchanged => true
  | .changed => false
  | .unmeasured => false

/-- Must the job fail? -/
def mustFail (d : Decision) : Bool :=
  match d with
  | .unchanged => false
  | .changed => false
  | .unmeasured => true

/-- **No decision is both.** The two predicates partition rather than overlap, so
a job cannot be simultaneously entitled to skip and obliged to fail — the
ambiguity that would let an implementer pick whichever is convenient. -/
theorem skipping_and_failing_never_both_apply (d : Decision) :
    ¬(maySkipQuietly d = true ∧ mustFail d = true) := by
  cases d <;> simp [maySkipQuietly, mustFail]

/-- And every decision gets one of the three defined treatments — the partition is
total, so there is no outcome the workflow has no rule for. -/
theorem every_decision_has_a_defined_treatment (d : Decision) :
    maySkipQuietly d = true ∨ mustFail d = true ∨ d = .changed := by
  cases d <;> simp [maySkipQuietly, mustFail]

/-- **The anti-vacuity witness.** Each of the three outcomes is actually
reachable. A `Decision` type whose third constructor no input can produce would
leave every theorem above green and pointless. -/
theorem all_three_outcomes_are_reachable :
    honest ["a"] ["a"] = .unchanged ∧
    honest ["a"] ["b"] = .changed ∧
    honest ["a"] [] = .unmeasured := by decide

/-- Closing the loop on the run that started this: on a measured, unchanged
verdict the job is entitled to skip and not obliged to fail — so run 31367304632
was correct, and it was correct for a reason nobody had checked. -/
theorem the_run_that_prompted_this_was_actually_fine :
    maySkipQuietly (honest ["gates: 58/58"] ["gates: 58/58"]) = true ∧
    mustFail (honest ["gates: 58/58"] ["gates: 58/58"]) = false := by decide

/-- Had the generator gone silent, the same job would have skipped the staleness
check and stayed green. Under the repair it fails instead. -/
theorem the_silent_generator_now_fails_the_job :
    maySkipQuietly (honest ["gates: 58/58"] []) = false ∧
    mustFail (honest ["gates: 58/58"] []) = true := by decide

-- Contingent, and kept as guards rather than theorems: these are facts about
-- today's run and today's file, and a number that moves must never become a
-- hypothesis.
#guard changed [] [] == false          -- the blindness, as shipped
#guard honest [] [] == Decision.unmeasured
#guard (honest ["x"] ["x"] == Decision.unchanged)

end RotMoE.VerdictDecision
