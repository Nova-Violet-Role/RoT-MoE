/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

/-!
# The weekly verdict must be able to say NOTHING

`.github/workflows/verify.yml` runs on a schedule and publishes `STATUS.md`. The
rule it states in its own comments is the right one: **no change, no commit** —
a bot that commits every week manufactures activity and proves nothing, so
`--allow-empty` is deliberately absent.

The rule was stated in prose and defeated by the payload. Until 2026-08-01 the
file being compared contained

    | verified at | $(date -u '+%Y-%m-%d %H:%M UTC') |
    | commit      | ${GITHUB_SHA} |

so `git diff --staged --quiet` could never be true: the branch that says nothing
was unreachable, and the scheduled job would have committed every week forever.
Nothing caught it, because everything that looked at the workflow read the
comment rather than the control flow.

`checker/verdict-schedule-sim.sh` now runs the publish job's real `run:` blocks
for **three** weeks against a scratch remote and counts the commits that land.
This module proves what three weeks cannot reach: the property for **every** k.

## What is modelled

A `Verdict` is the measurement block `checker/status-verdict.sh` emits — the
numbers and the toolchain, and nothing that changes merely because time passed.
A `ScheduledRun` carries that block, the previous one, and the clock and commit id the
run would stamp. Two decision functions are defined: `commits`, which is the
shipped design, and `commitsOld`, which is the defect, reconstructed so the two
can be compared inside the same theorem rather than across a changelog.

## What is NOT modelled

Whether `status-verdict.sh` measures the right things (that is the checker's
job, with its own controls), whether GitHub schedules the run at all, and
whether a push succeeds. This is about the DECISION, which is where the defect
lived: it committed regardless of what was measured.
-/

namespace RotMoE

/-- The measurement block: exactly what `checker/status-verdict.sh` prints.
No clock, no commit id — that absence is the whole design, so it is visible
here as the absence of a field rather than as a comment. -/
structure Verdict where
  theorems  : Nat
  modules   : Nat
  suites    : Nat
  checkers  : Nat
  toolchain : String
  sorries   : Nat
  natives   : Nat
  deriving DecidableEq, Repr

/-- One scheduled run. `prev` is the block extracted from the committed
`STATUS.md` (`none` on the very first run); `cur` is what was just measured;
`clock` and `sha` are what the run would stamp into the file as provenance. -/
structure ScheduledRun where
  prev      : Option Verdict
  prevClock : Nat
  prevSha   : Nat
  cur       : Verdict
  clock     : Nat
  sha       : Nat
  deriving Repr

/-- **The shipped decision**: compare the verdict block, and only that. -/
def commits (r : ScheduledRun) : Bool :=
  if r.prev = some r.cur then false else true

/-- **The defect**, reconstructed: the compared payload carried the clock and
the commit id, so a run was "changed" whenever time had passed. -/
def commitsOld (r : ScheduledRun) : Bool :=
  match r.prev with
  | none    => true
  | some pv => if pv = r.cur ∧ r.prevClock = r.clock ∧ r.prevSha = r.sha
               then false else true

/-! ## The shipped design -/

/-- A week in which nothing was measured differently commits NOTHING — and the
quantifiers are the point: `pc ps c s` range over every clock and every commit
id, so no passage of time and no new head can make this run speak. This is the
exact statement the old design made false. -/
theorem silent_week_is_silent (v : Verdict) (pc ps c s : Nat) :
    commits ⟨some v, pc, ps, v, c, s⟩ = false := by
  simp [commits]

/-- A verdict that really moved is published. Silence must not be free either:
a checker that never commits would pass the theorem above and be useless. -/
theorem changed_verdict_commits (p q : Verdict) (pc ps c s : Nat) (h : p ≠ q) :
    commits ⟨some p, pc, ps, q, c, s⟩ = true := by
  simp [commits, h]

/-- The first run, with no `STATUS.md` in the tree, publishes. -/
theorem first_run_commits (q : Verdict) (pc ps c s : Nat) :
    commits ⟨none, pc, ps, q, c, s⟩ = true := by
  simp [commits]

/-- The full characterisation: it commits exactly when the verdict differs. -/
theorem commits_iff_changed (r : ScheduledRun) :
    commits r = true ↔ r.prev ≠ some r.cur := by
  simp [commits]

/-- **The decision is a function of the measurements alone.** Two runs that
measured the same thing decide the same way, whatever the clock and whatever
the commit. This is the invariant the fix installs, stated over the variables
that move rather than over the values that happen to hold today. -/
theorem decision_ignores_clock_and_sha (p : Option Verdict) (q : Verdict)
    (pc₁ ps₁ c₁ s₁ pc₂ ps₂ c₂ s₂ : Nat) :
    commits ⟨p, pc₁, ps₁, q, c₁, s₁⟩ = commits ⟨p, pc₂, ps₂, q, c₂, s₂⟩ := by
  simp [commits]

/-! ## The defect, proved to be one -/

/-- Under the old design a week in which NOTHING was measured differently still
commits, purely because the clock moved. Same verdict on both sides; the only
difference is time. -/
theorem old_design_commits_when_only_the_clock_moved
    (v : Verdict) (pc ps c s : Nat) (h : pc ≠ c) :
    commitsOld ⟨some v, pc, ps, v, c, s⟩ = true := by
  simp [commitsOld, h]

/-- And the two designs genuinely disagree on such a week — so the change was
not cosmetic. -/
theorem designs_disagree :
    ∃ r : ScheduledRun, commits r = false ∧ commitsOld r = true := by
  refine ⟨⟨some ⟨1, 1, 1, 1, "t", 0, 0⟩, 0, 0, ⟨1, 1, 1, 1, "t", 0, 0⟩, 1, 0⟩, ?_, ?_⟩
  · simp [commits]
  · simp [commitsOld]

/-! ## Every k, not three

`checker/verdict-schedule-sim.sh` measures weeks 1, 2 and 3 against a real
scratch remote. A green-square generator differs from a correct implementation
only on quiet weeks, so what must be proved is that ALL of them stay quiet. -/

/-- Commits accumulated over `n` consecutive runs of the shipped design on a
tree that never changes, starting from state `st`. -/
def sched : Nat → Option Verdict → Verdict → Nat
  | 0,     _,  _ => 0
  | n + 1, st, v => (if st = some v then 0 else 1) + sched n (some v) v

/-- **Quiet forever.** Once the verdict has been published, an unbounded run of
weeks on an unchanged tree commits NOTHING — for every k, not for the three the
simulator could afford to run. -/
theorem quiet_forever (n : Nat) (v : Verdict) : sched n (some v) v = 0 := by
  induction n with
  | zero => rfl
  | succ k ih => simp [sched, ih]

/-- …and the repository does not go silent instead: starting from nothing, the
verdict is published exactly ONCE, however many weeks follow. -/
theorem published_exactly_once (n : Nat) (v : Verdict) :
    sched (n + 1) none v = 1 := by
  simp [sched, quiet_forever]

/-- Commits accumulated over `n` runs of the OLD design, where week `t` stamps
clock `t` — a fresh clock every week, which is what a schedule is. -/
def schedOld : Nat → Nat → Option (Verdict × Nat) → Verdict → Nat
  | 0,     _, _,  _ => 0
  | n + 1, t, st, v =>
      (match st with
       | none          => 1
       | some (pv, pc) => if pv = v ∧ pc = t then 0 else 1)
      + schedOld n (t + 1) (some (v, t)) v

/-- **The green-square generator, proved.** Under the old design the same
unchanged tree commits once per week, forever: `n` weeks, `n` commits. -/
theorem old_commits_every_week (n t : Nat) (v : Verdict) :
    schedOld n (t + 1) (some (v, t)) v = n := by
  induction n generalizing t with
  | zero => rfl
  | succ k ih => simp [schedOld, ih]; omega

/-- The two side by side on identical input: the shipped design is silent, the
old one commits every single week. The gap is `n`, so it grows without bound —
this is what "manufactured activity" means, measured. -/
theorem the_fix_is_not_cosmetic (n t : Nat) (v : Verdict) (h : 0 < n) :
    sched n (some v) v = 0 ∧ schedOld n (t + 1) (some (v, t)) v = n ∧
      sched n (some v) v ≠ schedOld n (t + 1) (some (v, t)) v := by
  refine ⟨quiet_forever n v, old_commits_every_week n t v, ?_⟩
  rw [quiet_forever, old_commits_every_week]
  omega

/-! ## Concrete instances

The definitions above are executable, so the model is checked against actual
values rather than only reasoned about. A model that cannot be run is a model
nobody has tested. -/

/-- The verdict this repository measured on 2026-08-01. -/
def today : Verdict := ⟨89, 7, 7, 20, "leanprover/lean4:v4.33.0-rc1", 0, 0⟩

/-- The same tree, one theorem later. -/
def tomorrow : Verdict := { today with theorems := 90 }

#guard commits ⟨some today, 0, 0, today, 999, 7⟩ = false
#guard commits ⟨some today, 0, 0, tomorrow, 999, 7⟩ = true
#guard commits ⟨none, 0, 0, today, 0, 0⟩ = true
#guard commitsOld ⟨some today, 0, 0, today, 999, 7⟩ = true   -- the defect, executed
#guard sched 52 (some today) today = 0                        -- a quiet year
#guard schedOld 52 1 (some (today, 0)) today = 52             -- fifty-two empty commits
#guard sched 52 none today = 1                                -- published once, then quiet

end RotMoE
