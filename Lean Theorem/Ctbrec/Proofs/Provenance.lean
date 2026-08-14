/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CP87 -- WHY the launch record is keyed on (PID, StartTime) and not on PID alone.

Suite phase 77 compares the running javaw against ctbrec-launch.json. It was shipped as a shell
comparison with controls, i.e. MEASURED and not PROVED, and this file closes that gap: the rule it
implements is stated here and the reason for the composite key is proved rather than asserted.

The motivating event: on 2026-08-06 at 23:22:16 the app ran its shutdown hook and exited cleanly,
and the cause could not be attributed. Two hypotheses were falsified by experiment (a suite phase
stopping it; `timeout`'s SIGTERM reaping the group). What was missing was not a cause but a
RECORD -- nothing on disk said which process had been launched, so an exit was indistinguishable
from a restart and the following run's live-stream phases skipped in silence.

The design question that record raises is the only one worth proving: is a PID enough? Windows
recycles PIDs, so a later, unrelated process can wear the number of the one that died. Under a
PID-only key that process reports MATCH -- the reassuring answer, and the wrong one. The witness
below exhibits exactly that, which is what makes the extra field load-bearing rather than
decorative.

WHAT IS PROVED: MATCH holds exactly on identity; a recycled PID is reported RECYCLED by the
composite key and MATCH by the PID-only key (witness exhibited); tightening the key can only ever
turn a MATCH into a non-MATCH, never the reverse; and an exit is never a MATCH.

NOT PROVED: that Windows actually recycles PIDs (an OS fact, not a Lean one), or that `javaw` is
the right process to look for. Those are measured elsewhere.
-/

namespace CtbrecSpec.Provenance

/-- A launched process, identified the way phase 77 identifies one. `startTime` is modelled as a
    tick count because only its EQUALITY is ever consulted. -/
structure Launch where
  pid : Nat
  startTime : Nat
deriving DecidableEq, Repr

inductive Verdict
  | ok          -- the running process IS the one launched
  | exited      -- nothing is running, but a launch was recorded
  | restarted   -- something runs, under a different pid
  | recycled    -- same pid, different process
deriving DecidableEq, Repr

/-- The rule phase 77 implements, over the composite key. -/
def verdict (rec : Launch) : Option Launch → Verdict
  | none => Verdict.exited
  | some run =>
      if run.pid ≠ rec.pid then Verdict.restarted
      else if run.startTime ≠ rec.startTime then Verdict.recycled
      else Verdict.ok

/-- The tempting simplification: key on the pid alone. -/
def verdictPidOnly (rec : Launch) : Option Launch → Verdict
  | none => Verdict.exited
  | some run => if run.pid ≠ rec.pid then Verdict.restarted else Verdict.ok

-- the live instance: pid 7228, recorded and running, identical
#guard verdict ⟨7228, 100⟩ (some ⟨7228, 100⟩) == Verdict.ok
-- the CP87 event itself
#guard verdict ⟨7228, 100⟩ none == Verdict.exited
-- restarted outside the launcher
#guard verdict ⟨7228, 100⟩ (some ⟨9999, 500⟩) == Verdict.restarted
-- THE case the composite key exists for: same number, different process
#guard verdict ⟨7228, 100⟩ (some ⟨7228, 500⟩) == Verdict.recycled
#guard verdictPidOnly ⟨7228, 100⟩ (some ⟨7228, 500⟩) == Verdict.ok

/--
**The witness, and the whole reason for the second field.** A recycled pid is reported `ok` by the
pid-only key and `recycled` by the composite one. Without this, phase 77 would report MATCH for a
process that has nothing to do with the app it claims to be watching.
-/
theorem the_pid_only_key_accepts_a_recycled_process :
    ∃ rec run : Launch,
      run.pid = rec.pid ∧ run.startTime ≠ rec.startTime ∧
      verdictPidOnly rec (some run) = Verdict.ok ∧
      verdict rec (some run) = Verdict.recycled := by
  refine ⟨⟨7228, 100⟩, ⟨7228, 500⟩, rfl, by decide, by decide, by decide⟩

/-- `ok` holds exactly on identity -- the check cannot pass for any other process. -/
theorem ok_iff_identical (rec run : Launch) :
    verdict rec (some run) = Verdict.ok ↔ run = rec := by
  constructor
  · intro h
    unfold verdict at h
    by_cases hp : run.pid = rec.pid
    · by_cases hs : run.startTime = rec.startTime
      · cases run; cases rec; simp_all
      · simp [hp, hs] at h
    · simp [hp] at h
  · intro h; subst h; simp [verdict]

/--
**Anti-disarm, quantified.** Tightening the key may only turn an `ok` into something else; it can
never manufacture an `ok`. So adopting the composite key cannot cause phase 77 to start passing
where it used to fail -- the direction that would hide a regression.
-/
theorem tightening_never_creates_an_ok (rec : Launch) (r : Option Launch) :
    verdict rec r = Verdict.ok → verdictPidOnly rec r = Verdict.ok := by
  cases r with
  | none => intro h; simp [verdict] at h
  | some run =>
      intro h
      rw [ok_iff_identical] at h
      subst h
      simp [verdictPidOnly]

/-- An exit is never an `ok`. This is the CP87 event: it must be loud, never silent. -/
theorem an_exit_is_never_ok (rec : Launch) : verdict rec none ≠ Verdict.ok := by
  simp [verdict]

/--
**Durable, not dated.** For EVERY recorded launch there exists a process that the pid-only key
would wrongly accept. The defect is not a property of pid 7228; it is a property of the weaker
key, so no future pid makes this theorem stale.
-/
theorem every_launch_has_a_recycled_impostor (rec : Launch) :
    ∃ run : Launch, verdictPidOnly rec (some run) = Verdict.ok ∧
                    verdict rec (some run) ≠ Verdict.ok := by
  refine ⟨⟨rec.pid, rec.startTime + 1⟩, ?_, ?_⟩
  · simp [verdictPidOnly]
  · rw [Ne, ok_iff_identical]
    intro h
    have : rec.startTime + 1 = rec.startTime := congrArg Launch.startTime h
    omega

/--
**Found by mutation, not by inspection.** Replacing the whole body of `verdictPidOnly` with a
constant `ok` killed NONE of the theorems above -- they only ever assert what it returns on the
impostor, never on a process that genuinely differs. So the "weaker key" was under-constrained:
nothing forced it to be a faithful model of a pid-only check, and a witness against a straw man
proves nothing about the real alternative.

This pins it. `verdictPidOnly` must still report `restarted` whenever the pids differ, which is
what makes it a real competing design rather than a function chosen to lose.
-/
theorem the_pid_only_key_still_detects_a_different_pid (rec run : Launch) (h : run.pid ≠ rec.pid) :
    verdictPidOnly rec (some run) = Verdict.restarted := by
  simp [verdictPidOnly, h]

/--
And the two keys agree everywhere EXCEPT on recycling -- so the composite key is not gratuitously
stricter. Its only additional power is the one case it was introduced for.
-/
theorem the_keys_differ_only_on_recycling (rec run : Launch) (h : run.startTime = rec.startTime) :
    verdict rec (some run) = verdictPidOnly rec (some run) := by
  by_cases hp : run.pid = rec.pid
  · simp [verdict, verdictPidOnly, hp, h]
  · simp [verdict, verdictPidOnly, hp]

end CtbrecSpec.Provenance
