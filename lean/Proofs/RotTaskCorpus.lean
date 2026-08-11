/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A benchmark task the naive answer gets right is a free point for both arms

`bench/corpus-40.jsonl` is the P2.4 task set: 40 tasks, 10 per seed family,
fixed before either arm runs (`bench/P24-PREREGISTRATION.md` section 4). Each
task carries a command producing the **truth** and a command producing the
**naive** answer that is specifically wrong.

Two things can silently destroy such a corpus, and neither is visible to a check
that counts lines.

**A task that does not discriminate.** If the naive command happens to agree with
the honest one, both arms answer identically and the task contributes nothing to
the sign test — while still counting toward n. `an_indiscriminate_task_cannot_
separate_the_arms` proves the contribution is literally zero, and
`a_corpus_of_ties_is_vacuous` proves a corpus made entirely of such tasks reports
a tie no matter how good either arm is.

**A frozen expected value.** The tempting design is to write today's answer into
the corpus: `"truth": 35`. That is a *contingent fact*, not a property. The
moment a theorem is added to the module the corpus is wrong, and worse, it is
wrong in the permissive direction — `the_frozen_check_claims_discrimination_that_
is_not_there` exhibits a world where the frozen corpus reports a task as
discriminating when it no longer is. The shipped corpus therefore carries
**commands**, not numbers, and `the_derived_check_is_right_in_every_world` says
why that is the durable form.

The corpus shape is proved too. Its 40 tasks are exactly the 4 families crossed
with the router's 10 lanes, so balance, lane coverage and distinctness are
consequences of the construction rather than facts anyone has to maintain by
hand — including coverage of `CONVERGENT`, the fallback lane the existing bench
key never exercised.
-/

namespace RotMoE.TaskCorpus

/-! ## Worlds, tasks, discrimination -/

/-- A world is the state of the tree the commands read. It moves every commit. -/
abbrev World := Nat

/-- A task, modelled the way the shipped corpus stores it: two COMMANDS, each a
function of the world, never two frozen numbers. -/
structure Task where
  /-- the honest instrument, e.g. `checker/count-theorems.sh` -/
  truthAt : World → Nat
  /-- the specifically-wrong instrument, e.g. `grep -c '^theorem'` -/
  naiveAt : World → Nat

/-- The task tells the two arms apart in world `w` exactly when the naive answer
is wrong there. -/
def discriminates (t : Task) (w : World) : Bool := t.naiveAt w != t.truthAt w

/-- What the careful arm scores on this task: 1 when it answers the truth. It
always does; that is what makes it the careful arm. -/
def carefulScore (_t : Task) (_w : World) : Nat := 1

/-- What the naive arm scores: 1 only when the naive command happens to be right. -/
def naiveScore (t : Task) (w : World) : Nat := if t.naiveAt w = t.truthAt w then 1 else 0

/-- The task's contribution to the difference between the arms. -/
def margin (t : Task) (w : World) : Nat := carefulScore t w - naiveScore t w

/-- **A task the naive command gets right contributes nothing.** It still counts
toward n, so it dilutes the sign test while looking like evidence. -/
theorem an_indiscriminate_task_cannot_separate_the_arms
    (t : Task) (w : World) (h : discriminates t w = false) : margin t w = 0 := by
  simp [discriminates, bne] at h
  simp [margin, carefulScore, naiveScore, h]

/-- **And a discriminating task contributes exactly one.** Both directions, so
the margin is a real measurement rather than a constant. -/
theorem a_discriminating_task_separates_them
    (t : Task) (w : World) (h : discriminates t w = true) : margin t w = 1 := by
  simp [discriminates, bne] at h
  simp [margin, carefulScore, naiveScore, h]

/-- The margin is decided entirely by discrimination — nothing else in the task
can move it. -/
theorem the_margin_is_exactly_discrimination (t : Task) (w : World) :
    margin t w = if discriminates t w then 1 else 0 := by
  by_cases h : discriminates t w
  · simp [h, a_discriminating_task_separates_them t w h]
  · simp at h
    simp [h, an_indiscriminate_task_cannot_separate_the_arms t w h]

/-- Total margin over a corpus. -/
def totalMargin (ts : List Task) (w : World) : Nat :=
  (ts.map (fun t => margin t w)).sum

/-- **A corpus of ties reports a dead heat however good the arms are.** This is
the failure mode a line count cannot see: 40 rows, n = 40, verdict meaningless. -/
theorem a_corpus_of_ties_is_vacuous
    (ts : List Task) (w : World) (h : ∀ t ∈ ts, discriminates t w = false) :
    totalMargin ts w = 0 := by
  induction ts with
  | nil => rfl
  | cons a as ih =>
    have ha : discriminates a w = false := h a (List.mem_cons_self ..)
    have has : ∀ t ∈ as, discriminates t w = false :=
      fun t ht => h t (List.mem_cons_of_mem _ ht)
    simp [totalMargin, an_indiscriminate_task_cannot_separate_the_arms a w ha]
    simpa [totalMargin] using ih has

/-! ## Why the corpus stores commands and not numbers

`sampleTask` is `F1-01`: both instruments grow as the module grows, and at one
particular world the naive grep happens to land on the right answer. -/

def sampleTask : Task where
  truthAt := fun w => 35 + w
  naiveAt := fun w => if w = 3 then 38 else 37 + w

/-- Today (`w = 0`) the task discriminates: 37 against 35. -/
theorem sample_discriminates_today : discriminates sampleTask 0 = true := by decide

/-- At `w = 3` it does not: both instruments say 38. A corpus is not a snapshot;
this is the world in which the task quietly stops being evidence. -/
theorem sample_stops_discriminating_at_world_three :
    discriminates sampleTask 3 = false := by decide

/-- The frozen design: the corpus stores today's truth as a literal and compares
the naive answer against *that*. -/
def frozenDiscriminates (t : Task) (frozen : Nat) (w : World) : Bool :=
  t.naiveAt w != frozen

/-- The derived design, which is what ships: compare against the truth command
re-run in the world you are actually in. -/
def derivedDiscriminates (t : Task) (w : World) : Bool := discriminates t w

/-- **The frozen check reports discrimination that is not there.** With today's
truth (35) frozen in, world 3 is scored as a discriminating task while both
instruments in fact agree. The corpus would carry a task that measures nothing
and would report n = 40 anyway. -/
theorem the_frozen_check_claims_discrimination_that_is_not_there :
    frozenDiscriminates sampleTask 35 3 = true
      ∧ derivedDiscriminates sampleTask 3 = false := by decide

/-- **The derived check is right in every world**, because it re-reads the world
instead of remembering it. Stated over all worlds, which is the whole point. -/
theorem the_derived_check_is_right_in_every_world (t : Task) (w : World) :
    derivedDiscriminates t w = discriminates t w := rfl

/-- The frozen check is not merely different — it is wrong in **both**
directions. Here it denies a task that does discriminate. -/
theorem the_frozen_check_also_denies_real_discrimination :
    frozenDiscriminates sampleTask 37 0 = false
      ∧ derivedDiscriminates sampleTask 0 = true := by decide

/-! ## The shape of the shipped corpus

The 40 tasks are the 4 seed families crossed with the router's 10 lanes. Balance,
lane coverage and distinctness then follow from the construction instead of being
maintained by hand. -/

/-- Number of seed families fixed by the preregistration, section 4. -/
def families : Nat := 4

/-- Lanes the shipped router can emit: nine stem-led plus the `CONVERGENT`
fallback (`hooks/rot-router.sh:340-350`). -/
def lanes : Nat := 10

/-- The corpus plan: every (family, lane) pair exactly once. -/
def plan : List (Nat × Nat) :=
  (List.range families).flatMap (fun f => (List.range lanes).map (fun l => (f, l)))

#guard plan.length = 40
#guard (plan.filter (fun p => p.1 = 0)).length = 10
#guard (plan.filter (fun p => p.2 = 9)).length = 4
#guard plan.eraseDups.length = 40

/-- **The corpus is exactly 40 tasks**, and that is a consequence of 4 x 10 —
not a number anyone has to keep in step by hand. -/
theorem the_plan_holds_forty_tasks : plan.length = 40 := by decide

/-- **Every family carries exactly ten tasks.** Section 4 fixes 10 per family;
an unbalanced corpus weights one defect class above the others. -/
theorem every_family_has_ten :
    ∀ f ∈ List.range families, (plan.filter (fun p => p.1 = f)).length = 10 := by decide

/-- **Every lane is exercised by exactly four tasks** — including `CONVERGENT`,
the fallback the existing bench key never reached. A lane with no task is a
branch of the router no benchmark can see regress. -/
theorem every_lane_has_four :
    ∀ l ∈ List.range lanes, (plan.filter (fun p => p.2 = l)).length = 4 := by decide

/-- **No pair repeats.** A duplicated (family, lane) would leave another lane
uncovered while the length stayed 40 — the same defect that let a duplicated
obligation keep `push-guard`'s ledger at six entries. -/
theorem the_plan_repeats_nothing : plan.eraseDups.length = plan.length := by decide

/-- **All ten lanes are present**, stated as coverage rather than as a count, so
it stays true if the corpus is ever enlarged. -/
theorem the_plan_covers_every_lane :
    ∀ l ∈ List.range lanes, ∃ p ∈ plan, p.2 = l := by decide

/-- **Dropping a lane is visible.** Remove the CONVERGENT column and coverage
fails — the theorem above is load-bearing, not decorative. -/
theorem losing_a_lane_breaks_coverage :
    ¬ (∀ l ∈ List.range lanes, ∃ p ∈ plan.filter (fun p => p.2 ≠ 9), p.2 = l) := by decide

/-- **The count alone would not have caught it.** A corpus that drops the
CONVERGENT column and doubles another lane still has 40 rows: length is not
coverage, which is why `checker/corpus-verify.sh` asserts both. -/
theorem forty_rows_does_not_imply_coverage :
    ((plan.filter (fun p => p.2 ≠ 9)) ++ (plan.filter (fun p => p.2 = 8))).length = 40
      ∧ ¬ (∀ l ∈ List.range lanes,
            ∃ p ∈ (plan.filter (fun p => p.2 ≠ 9)) ++ (plan.filter (fun p => p.2 = 8)),
              p.2 = l) := by decide

end RotMoE.TaskCorpus
