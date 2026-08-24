/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# RotTrapResume -- what a resumed cleanup handler does to a verdict

A POSIX `sh` signal handler that does not itself `exit` RESUMES execution at the
point the signal interrupted. When that handler is a cleanup trap, every arm
below it then runs with its evidence already deleted.

Six sites in `checker/` carried the combined form `trap '<cleanup>' EXIT INT TERM`
and were repaired to a split pair:

  release-longsession.sh:134-135   live-session-smoke.sh:461-462
  hook-footprint.sh:135-136        install-parity.sh:82-83
  mutate-harness.sh:60,153         full-freshness.sh:122

Observing them produced a claim stronger than any one site: the damage is NOT a
property of the trap. It is decided entirely by the polarity of whichever arm
reads the deleted resource first, and all three polarities occur in the tree:

  Shape A  absence scores PASS     hook-footprint.sh:192, full-freshness.sh:124
  Shape B  absence scores FAIL     install-parity.sh:124, release-longsession
  Shape C  absence removes check   install-parity.sh:132, mutate-harness.sh:71

That claim is universal over arms, so measuring it six times does not settle it.
This module settles it.

The `/tmp/trapctl/` fixture measured one further fact that shapes the model: the
combined and the split form BOTH exited 124 under `timeout`. The exit code is
blind to the difference; only the printed marker carries it. `exit_code_blind`
and `log_distinguishes` are that measurement, promoted to a theorem.
-/

namespace RotTrapResume

/-- What a scoring arm can conclude. `nothing` is a real outcome, not an absence
of one: a `for` over an empty word-split prints no line in either direction. -/
inductive Verdict where
  | pass
  | fail
  | nothing
  deriving DecidableEq, Repr

/-- How one arm scores a read of a resource that is NOT there. This is the only
degree of freedom that distinguishes the three observed shapes. -/
inductive Polarity where
  /-- Shape A: the arm concludes cleanliness from absence. -/
  | absenceScoresPass
  /-- Shape B: the arm charges absence to the subject under test. -/
  | absenceScoresFail
  /-- Shape C: the arm never executes; nothing is printed either way. -/
  | absenceRemovesCheck
  deriving DecidableEq, Repr

/-- `combined` is `trap '<cleanup>' EXIT INT TERM`; `split` is the repair pair. -/
inductive TrapForm where
  | combined
  | split
  deriving DecidableEq, Repr

/-- How the run ended: reached its end, or took a signal partway. -/
inductive Arrival where
  | normal
  | signal
  deriving DecidableEq, Repr

/-- The thing being checked. `true` means it really is defective. -/
abbrev Subject := Bool

/-- What a reader of the run's output actually receives. -/
inductive Outcome where
  | verdict (v : Verdict)
  | incomplete
  deriving DecidableEq, Repr

/-- Absence, scored. -/
def readsAs : Polarity → Verdict
  | .absenceScoresPass => .pass
  | .absenceScoresFail => .fail
  | .absenceRemovesCheck => .nothing

/-- What the arm WOULD have concluded had its evidence survived. -/
def honest : Subject → Verdict
  | true => .fail
  | false => .pass

/-- The whole model. Under `normal` arrival the resource is intact and the arm
reads the subject. Under `signal`, the handler has already deleted it: `split`
exits and prints the marker, `combined` resumes into an arm that now scores
absence. Arrival is matched first so the normal case reduces definitionally for
a variable trap form -- the non-vacuity theorem below depends on that. -/
def run : Arrival → TrapForm → Subject → Polarity → Outcome
  | .normal, _, s, _ => .verdict (honest s)
  | .signal, .split, _, _ => .incomplete
  | .signal, .combined, _, p => .verdict (readsAs p)

/-- Measured at `/tmp/trapctl/`: under `timeout`, both forms exit 124. -/
def exitUnderTimeout : TrapForm → Nat := fun _ => 124

/-! ## The model is not vacuous

If a run's verdict did not depend on the subject even on the normal path, every
theorem below would be trivially true of a gate that checks nothing. -/

/-- An intact run distinguishes a defective subject from a clean one. -/
theorem run_normal_sees_subject (t : TrapForm) (p : Polarity) :
    run .normal t true p ≠ run .normal t false p := by
  intro h
  injection h with h'
  exact absurd h' (by decide)

/-! ## The three shapes are distinct and exhaustive -/

/-- No two polarities produce the same damage: the taxonomy has no redundant
entry. -/
theorem shapes_distinct (p q : Polarity) (h : readsAs p = readsAs q) : p = q := by
  cases p <;> cases q <;> first
    | rfl
    | exact absurd h (by decide)

/-- Every verdict is reachable from some polarity: the taxonomy has no missing
entry, so absence really can land as pass, as fail, or as nothing at all. -/
theorem shapes_exhaustive (v : Verdict) : ∃ p : Polarity, readsAs p = v := by
  cases v
  · exact ⟨.absenceScoresPass, rfl⟩
  · exact ⟨.absenceScoresFail, rfl⟩
  · exact ⟨.absenceRemovesCheck, rfl⟩

/-- Severity cannot be read off the trap. One trap form, one arrival, one
subject -- and two different outcomes, decided only by the arm. -/
theorem severity_not_determined_by_trap :
    ∃ p q : Polarity,
      run .signal .combined true p ≠ run .signal .combined true q :=
  ⟨.absenceScoresPass, .absenceScoresFail, by decide⟩

/-! ## What the combined form does -/

/-- A killed combined run reports a verdict that depends only on the arm's
polarity -- the subject is not consulted at all. -/
theorem combined_signal_is_polarity_only (s : Subject) (p : Polarity) :
    run .signal .combined s p = .verdict (readsAs p) := rfl

/-- The same statement in the form that names the defect: two different subjects
receive the same verdict. This is what "fabricated" means precisely. -/
theorem combined_signal_ignores_subject (s₁ s₂ : Subject) (p : Polarity) :
    run .signal .combined s₁ p = run .signal .combined s₂ p := rfl

/-- The lie runs in the pass direction: a genuinely defective subject is cleared. -/
theorem combined_clears_a_defect :
    ∃ (s : Subject) (p : Polarity) (v : Verdict),
      run .signal .combined s p = .verdict v ∧ v ≠ honest s :=
  ⟨true, .absenceScoresPass, .pass, rfl, by decide⟩

/-- And in the fail direction: a clean subject is convicted. Both directions are
required -- a gate that only ever fabricates greens would be a different defect. -/
theorem combined_convicts_the_innocent :
    ∃ (s : Subject) (p : Polarity) (v : Verdict),
      run .signal .combined s p = .verdict v ∧ v ≠ honest s :=
  ⟨false, .absenceScoresFail, .fail, rfl, by decide⟩

/-! ## What the split form does -/

/-- A killed split run yields the incomplete marker, whatever the arm's polarity
would have been. The repair erases the polarity dependence rather than fixing
each arm. -/
theorem split_signal_incomplete (s : Subject) (p : Polarity) :
    run .signal .split s p = .incomplete := rfl

/-- A killed split run never produces a verdict at all. -/
theorem split_signal_never_verdict (s : Subject) (p : Polarity) (v : Verdict) :
    run .signal .split s p ≠ .verdict v := by
  intro h
  exact Outcome.noConfusion h

/-- **The correctness statement for the repair.** If a split run reports a
verdict, that verdict is the honest one. No reachable path produces a verdict
about a subject the run did not actually examine. -/
theorem split_verdict_is_honest (a : Arrival) (s : Subject) (p : Polarity)
    (v : Verdict) (h : run a .split s p = .verdict v) : v = honest s := by
  cases a with
  | normal =>
      injection h with h'
      exact h'.symm
  | signal => exact Outcome.noConfusion h

/-- Every split outcome is one of exactly two things: an honest verdict, or the
marker. There is no third case. -/
theorem split_dichotomy (a : Arrival) (s : Subject) (p : Polarity) :
    run a .split s p = .verdict (honest s) ∨ run a .split s p = .incomplete := by
  cases a
  · exact Or.inl rfl
  · exact Or.inr rfl

/-- The combined form has no such dichotomy -- stated as a refutation so it can
fail if the model is ever weakened into agreement. -/
theorem combined_no_dichotomy :
    ¬ (∀ (a : Arrival) (s : Subject) (p : Polarity),
        run a .combined s p = .verdict (honest s) ∨
        run a .combined s p = .incomplete) := by
  intro h
  rcases h .signal true .absenceScoresPass with h1 | h1
  · exact absurd h1 (by decide)
  · exact absurd h1 (by decide)

/-! ## The exit code is the wrong instrument

Measured, then proved: the two forms are indistinguishable by exit status and
distinguishable only by what they print. A harness that classifies runs by exit
code alone cannot tell a completed run from a killed one. -/

/-- Both forms exit 124 under `timeout`. -/
theorem exit_code_blind : exitUnderTimeout .combined = exitUnderTimeout .split := rfl

/-- Yet the outcomes differ, for every subject and every arm. The marker is the
only channel that carries the difference. -/
theorem log_distinguishes (s : Subject) (p : Polarity) :
    run .signal .combined s p ≠ run .signal .split s p := by
  intro h
  exact Outcome.noConfusion h

/-- Put together: identical exit codes, different outcomes. Classifying by exit
status conflates a fabricated verdict with an admission of incompleteness. -/
theorem exit_code_conflates (s : Subject) (p : Polarity) :
    exitUnderTimeout .combined = exitUnderTimeout .split ∧
    run .signal .combined s p ≠ run .signal .split s p :=
  ⟨rfl, log_distinguishes s p⟩

end RotTrapResume
