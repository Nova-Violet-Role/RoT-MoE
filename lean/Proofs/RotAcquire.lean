/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

/-!
# The acquisition guard, as a theorem rather than a habit

A checker in this repository fetched **7.2 GB** into a 200 KB repository. Twice,
in the same class: once at 41 MB (`gauge-cross.sh`), once at 7.2 GB
(`generalization_probe.sh`). Every one of those scripts calls `lake`, and lake
RESOLVES THE PACKAGE before it does anything at all — so "the script only reads"
is not a property of the script, it is a hope about lake.

The shell fix is a guard: refuse to invoke lake unless the workspace is ALREADY
built. This module states what that guard must satisfy, and proves it — because
"the guard looks right" is exactly the sentence that preceded both incidents.

What is modelled: the guard's PREDICATE over a workspace's observable state
(`.lake/packages` present, which modules have `.olean` files). What is NOT
modelled, and is said here rather than implied: lake's actual behaviour, the
filesystem, and the shell's exit codes. Those are the checker's job
(`checker/workflow-lint.sh` requires the guard structurally in every suite) and
a measurement, never a theorem.

The load-bearing result is `no_lake_on_unbuilt`: on a workspace that was never
built, NO execution path reaches lake. That is the invariant the 7.2 GB
violated, and it is stated over an arbitrary workspace rather than over the one
that happened to break.

The second result is the one that cost a false skip: the first guard keyed on
THE TARGET MODULE's own `.olean` — the very artefact every mutant deletes on
purpose. `old_guard_false_skips_after_target_deleted` exhibits a workspace where
that guard refuses a perfectly good workspace, and `guard_survives_target_deletion`
proves the shipped guard does not.
-/

namespace RotMoE

/-- What a checker can observe about a Lean workspace before it decides to run.
`packagesDir` is `.lake/packages`; `oleans` are the modules already built. -/
structure Workspace where
  packagesDir : Bool
  oleans : List String
  deriving DecidableEq, Repr

/-- A workspace is BUILT when its dependencies are resolved and something has
actually been compiled. Both halves matter: `.lake/packages` alone is a tree
mid-download, which is the state the 7.2 GB incident passed through. -/
def built (w : Workspace) : Bool :=
  w.packagesDir && !w.oleans.isEmpty

/-- The SHIPPED guard. Deliberately not keyed on any particular module. -/
def guardAdmits (w : Workspace) : Bool :=
  w.packagesDir && !w.oleans.isEmpty

/-- The FIRST guard, kept so the defect it caused can be stated as a theorem:
it demanded the target module's own `.olean`. -/
def oldGuardAdmits (target : String) (w : Workspace) : Bool :=
  w.packagesDir && w.oleans.contains target

/-- Lake is invoked exactly when the guard admits. This is the modelling
assumption the shell must honour, and `workflow-lint.sh` is what holds it to
it — there is no other path to lake in a guarded script. -/
def invokesLake (w : Workspace) : Bool := guardAdmits w

/-- Deleting one module's `.olean`, which every mutant does on purpose before
rebuilding. -/
def dropOlean (target : String) (w : Workspace) : Workspace :=
  { w with oleans := w.oleans.erase target }

/-! ## The invariant that the 7.2 GB violated -/

/-- **A workspace that was never built is never handed to lake.**
Stated over an arbitrary workspace: this is the property that makes the fetch
impossible rather than unlikely. -/
theorem no_lake_on_unbuilt (w : Workspace) (h : built w = false) :
    invokesLake w = false := by
  unfold invokesLake guardAdmits
  unfold built at h
  exact h

/-- The converse direction, which is what makes the guard non-vacuous: if lake
IS invoked, the workspace really was built. A guard that refused everything
would satisfy the theorem above and be useless. -/
theorem lake_implies_built (w : Workspace) (h : invokesLake w = true) :
    built w = true := by
  unfold invokesLake guardAdmits at h
  unfold built
  exact h

/-- No `.lake/packages`, no lake — the half that stops a fresh clone. -/
theorem no_lake_without_packages (w : Workspace) (h : w.packagesDir = false) :
    invokesLake w = false := by
  unfold invokesLake guardAdmits
  simp [h]

/-- Nothing compiled, no lake — the half that stops a tree mid-download. -/
theorem no_lake_without_oleans (w : Workspace) (h : w.oleans = []) :
    invokesLake w = false := by
  unfold invokesLake guardAdmits
  simp [h]

/-! ## The false skip, and why the shipped guard does not have it -/

/-- **The shipped guard survives its own suite.** Delete the target module's
`.olean` — as every mutant does — and as long as some other module remains
built, the workspace is still admitted. -/
theorem guard_survives_target_deletion (t : String) (w : Workspace)
    (hp : w.packagesDir = true) (hne : (w.oleans.erase t) ≠ []) :
    guardAdmits (dropOlean t w) = true := by
  unfold guardAdmits dropOlean
  simp [hp, hne]

/-- **The first guard did NOT.** A real, fully built workspace is REFUSED once
the mutant deletes the module under test. This is the measured false skip on
`Proofs.RotVacuity`, as an existence statement rather than an anecdote. -/
theorem old_guard_false_skips_after_target_deleted :
    ∃ (t : String) (w : Workspace),
      built w = true ∧
      guardAdmits (dropOlean t w) = true ∧
      oldGuardAdmits t (dropOlean t w) = false := by
  refine ⟨"RotVacuity", ⟨true, ["RotVacuity", "RotGauge"]⟩, ?_, ?_, ?_⟩ <;> decide

/-- And the two guards are NOT interchangeable in general: there is a workspace
the shipped guard admits and the old one refuses. Without this, the pair above
could both be artefacts of one witness. -/
theorem guards_differ :
    ∃ (t : String) (w : Workspace),
      guardAdmits w = true ∧ oldGuardAdmits t w = false := by
  refine ⟨"RotRemind", ⟨true, ["RotGauge"]⟩, ?_, ?_⟩ <;> decide

/-! ## Monotonicity — building more never locks you out -/

/-- Building an additional module never turns an admitted workspace into a
refused one. A guard that could regress under progress would be a trap. -/
theorem guard_monotone_in_oleans (m : String) (w : Workspace)
    (h : guardAdmits w = true) :
    guardAdmits { w with oleans := m :: w.oleans } = true := by
  unfold guardAdmits at h ⊢
  simp at h ⊢
  exact h.1

/-- Admission is exactly "built" — the guard adds nothing and hides nothing. -/
theorem guard_iff_built (w : Workspace) : guardAdmits w = built w := rfl

/-! ## Executable checks: the definitions must MEAN this on concrete states -/

-- a fresh clone: nothing resolved, nothing built
#guard invokesLake ⟨false, []⟩ = false
-- mid-download: packages appearing, nothing compiled yet (the 7.2 GB state)
#guard invokesLake ⟨true, []⟩ = false
-- a real workspace
#guard invokesLake ⟨true, ["RotGauge", "RotRemind"]⟩ = true
-- the mutant has just deleted its target, five modules remain
#guard guardAdmits (dropOlean "RotVacuity" ⟨true, ["RotVacuity", "RotGauge"]⟩) = true
-- the old guard refuses that same workspace: the false skip, executed
#guard oldGuardAdmits "RotVacuity" (dropOlean "RotVacuity" ⟨true, ["RotVacuity", "RotGauge"]⟩) = false
-- a vendored tree with a stray packages dir and no build is still refused
#guard built ⟨true, []⟩ = false

/-- Non-vacuity witness for `no_lake_on_unbuilt`: the hypothesis is satisfiable,
so the theorem says something about a state that really occurs. -/
example : invokesLake ⟨true, []⟩ = false := no_lake_on_unbuilt _ (by decide)

/-- Non-vacuity witness for `lake_implies_built`. -/
example : built ⟨true, ["RotGauge"]⟩ = true := lake_implies_built _ (by decide)

/-- Non-vacuity witness for `guard_survives_target_deletion`. -/
example : guardAdmits (dropOlean "RotVacuity" ⟨true, ["RotVacuity", "RotGauge"]⟩) = true :=
  guard_survives_target_deletion _ _ (by decide) (by decide)

end RotMoE
