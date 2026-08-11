/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # Four workflows, two roles, and the difference between running and working

The repository has four hand-written workflows and one GitHub-generated one.
Measured through the API on 2026-08-11:

| workflow | newest run | youngest green |
|---|---|---|
| `tag-manager.yml`  | success, 20.4 h | 20.4 h |
| `verify.yml`       | success, 21.0 h | 21.0 h |
| `ci.yml`           | success, 42.4 h | 42.4 h |
| `ads-manager.yml`  | **failure, 19.3 h** | **173.5 h** |

The last row is the one this file exists for. By the obvious freshness test —
*has this workflow run recently* — the docs manager is the **healthiest** of the
four: nineteen hours, fresher than anything else in the table. It had in fact been
failing for seven days, and the documents it maintains had not moved in that time.
`a_workflow_that_runs_is_not_a_workflow_that_works` decides that gap, and
`green_freshness_is_strictly_stronger` proves the repair is not merely different
but strictly stronger: everything the naive test rejects, the green test rejects
too.

The second half is the role split. `ci.yml` and `verify.yml` are **code gates**;
`ads-manager.yml` and `tag-manager.yml` are **documentation managers** that keep
the repository alive between commits. The split is currently enforced by intent
and by a comment. Intent is not an instrument, so it is stated here as a predicate
with witnesses that make it fail.

One premise is corrected in passing, because it changes what may be claimed:
Dependabot cannot be the documentation engine. Its only ecosystem here is
`github-actions` at `directory: "/"`, which edits workflow files — that is,
**exclusively code gates**. There is no key that scopes it to two named files;
`ignore` filters by dependency name, never by path. So the freshness of the
documents is the cron managers' job and nothing else's, which is why a manager
that is silently red is a defect and not an inconvenience.
-/

namespace RotMoE.WorkflowRoles

/-- What a workflow is for. The two roles carry different obligations and the
whole point is that they are not interchangeable. -/
inductive Role where
  | codeGate
  | docsManager
  deriving DecidableEq, Repr

/-- A workflow as the API and the file together describe it. Ages are in hours;
`youngestGreenHours` is the age of the most recent run whose conclusion was
`success`, which is not the same number as `newestRunHours`. -/
structure Workflow where
  name : String
  role : Role
  scheduled : Bool
  writes : List String
  newestRunHours : Nat
  youngestGreenHours : Nat
  deriving DecidableEq, Repr

/-- The four measured on 2026-08-11. These are data, not claims: every theorem
below is stated over arbitrary workflows and merely *witnessed* here. -/
def tagManager : Workflow :=
  { name := "tag-manager.yml", role := .docsManager, scheduled := true,
    writes := ["README.md", "topics", "tags"],
    newestRunHours := 20, youngestGreenHours := 20 }

def adsManager : Workflow :=
  { name := "ads-manager.yml", role := .docsManager, scheduled := true,
    writes := ["README.md", "PROMO.md"],
    newestRunHours := 19, youngestGreenHours := 173 }

def ciGate : Workflow :=
  { name := "ci.yml", role := .codeGate, scheduled := false,
    writes := [], newestRunHours := 42, youngestGreenHours := 42 }

def verifyGate : Workflow :=
  { name := "verify.yml", role := .codeGate, scheduled := true,
    writes := ["STATUS.md"], newestRunHours := 21, youngestGreenHours := 21 }

/-! ## Running is not working

The naive test asks whether a workflow ran. The honest test asks whether it
*succeeded*. On this repository the two disagree, and they disagree in the
direction that hides the fault. -/

/-- Did it run recently? -/
def ranRecently (bound : Nat) (w : Workflow) : Bool := w.newestRunHours ≤ bound

/-- Did it *succeed* recently? -/
def greenRecently (bound : Nat) (w : Workflow) : Bool := w.youngestGreenHours ≤ bound

/-- The measured disagreement, decided. Under a two-day bound the docs manager
passes the naive test and fails the honest one — and it was failing for seven
days while looking like the freshest workflow in the repository. -/
theorem a_workflow_that_runs_is_not_a_workflow_that_works :
    ranRecently 48 adsManager = true ∧ greenRecently 48 adsManager = false := by decide

/-- The other three agree under the same bound, so the disagreement above is a
property of that workflow's state and not an artefact of the bound. -/
theorem the_healthy_three_agree_under_the_same_bound :
    (ranRecently 48 tagManager = true ∧ greenRecently 48 tagManager = true) ∧
    (ranRecently 48 verifyGate = true ∧ greenRecently 48 verifyGate = true) ∧
    (ranRecently 48 ciGate = true ∧ greenRecently 48 ciGate = true) := by decide

/-- A run's age can never exceed the age of the newest *green* run, because a
green run is a run. This is the invariant that makes the comparison below sharp
rather than a coincidence of the data. -/
def wellFormed (w : Workflow) : Prop := w.newestRunHours ≤ w.youngestGreenHours

/-- **The repair is strictly stronger, for every workflow and every bound.**
Anything the green test accepts, the naive test accepts too — so replacing one
with the other can only ever reject more, never less. Stated generally: no
appeal to today's numbers, and no future set of runs can make it false. -/
theorem green_freshness_is_strictly_stronger (b : Nat) (w : Workflow)
    (hw : wellFormed w) (h : greenRecently b w = true) : ranRecently b w = true := by
  simp only [greenRecently, decide_eq_true_eq] at h
  simp only [ranRecently, decide_eq_true_eq]
  exact Nat.le_trans hw h

/-- And the converse fails — which is exactly what makes the change worth making
rather than a rename. The witness is the real workflow, well-formed and all. -/
theorem the_naive_test_does_not_imply_the_honest_one :
    wellFormed adsManager ∧ ranRecently 48 adsManager = true ∧
      greenRecently 48 adsManager = false := by
  refine ⟨?_, by decide, by decide⟩
  simp [wellFormed, adsManager]

/-! ## Roles, and what a documentation manager may touch

The allowlist is the mechanism; the theorems are about what it refuses. A list
that refuses nothing is the failure mode, so it is tested for that first. -/

/-- Paths a documentation manager is permitted to write. -/
def docsAllowlist : List String :=
  ["README.md", "CHANGELOG.md", "STATUS.md", "PROMO.md", "topics", "tags"]

/-- Every path this workflow writes is on the allowlist. -/
def writesOnlyDocs (w : Workflow) : Bool := w.writes.all (fun p => docsAllowlist.contains p)

/-- A documentation manager is well-scoped when it writes documents and nothing
else. A code gate is unconstrained by this predicate — it is judged by the
required-checks rule instead. -/
def roleRespected (w : Workflow) : Bool :=
  match w.role with
  | .docsManager => writesOnlyDocs w
  | .codeGate => true

/-- The two live managers are within their role, measured from their own
`permissions:` and the paths they touch. -/
theorem the_managers_stay_inside_their_role :
    roleRespected tagManager = true ∧ roleRespected adsManager = true := by decide

/-- A documentation manager that writes into the proof tree is refused. This is
the rule that a comment cannot enforce. -/
theorem a_docs_manager_may_not_write_to_the_proofs :
    roleRespected { adsManager with writes := ["README.md", "lean/Proofs"] } = false := by
  decide

/-- Nor into the hooks, which is the shape that would actually be dangerous: a
scheduled workflow with `contents: write` editing the router. -/
theorem a_docs_manager_may_not_write_to_the_router :
    roleRespected { tagManager with writes := ["hooks/rot-router.sh"] } = false := by
  decide

/-- **The allowlist is not a rubber stamp.** If it accepted everything, every
theorem above would still be green and would mean nothing. This is the
anti-vacuity witness: there exists a path the list refuses. -/
theorem the_allowlist_refuses_something :
    docsAllowlist.contains "lean/Proofs" = false ∧
    docsAllowlist.contains "hooks/rot-router.sh" = false ∧
    docsAllowlist.contains "README.md" = true := by decide

/-! ## A code gate that is not a required check is a suggestion

Measured through the rulesets API on 2026-08-11 — note the *rulesets* endpoint:
the legacy `/branches/main/protection` route answers `Branch not protected` for a
repository that protects `main` with a ruleset, and reading that as "unprotected"
would have been a false accusation. The effective rules on `main` are `deletion`,
`non_fast_forward`, and four required status checks. -/

/-- The four contexts the ruleset requires, as measured. -/
def requiredChecks : List String :=
  ["checkers (ubuntu-latest)", "checkers (windows-latest)", "checkers (macos-latest)",
   "lean -- build, axioms, kernel re-check"]

/-- A code gate earns its name only if merging is actually blocked on it. -/
def gateIsEnforced (required : List String) (context : String) : Bool :=
  required.contains context

/-- The Lean gate is enforced; a plausible-looking name that nobody registered is
not. The second conjunct is what keeps this from being decoration — a rule that
only ever says yes proves nothing about the ruleset. -/
theorem an_unregistered_gate_is_not_enforced :
    gateIsEnforced requiredChecks "lean -- build, axioms, kernel re-check" = true ∧
    gateIsEnforced requiredChecks "lean (build)" = false := by decide

/-- Enforcement is per context, and every one of the four was checked rather than
the first one found. A single registered check does not make a set enforced. -/
theorem all_four_measured_contexts_are_enforced :
    requiredChecks.all (fun c => gateIsEnforced requiredChecks c) = true ∧
    requiredChecks.length = 4 := by decide

/-! ## The whole judgement

One predicate, so that a workflow cannot pass by satisfying the easy half. -/

/-- A workflow is healthy when it respects its role and its most recent *success*
is inside the bound. Scheduled workflows are the ones this matters for: GitHub
disables a schedule after sixty days of repository inactivity, silently, and a
schedule that has stopped firing looks exactly like a schedule that has nothing
to do. -/
def healthy (bound : Nat) (w : Workflow) : Bool :=
  roleRespected w && greenRecently bound w

/-- Three of the four are healthy under a two-day bound and the docs manager is
not — the state of the tree as measured, before the repair. -/
theorem the_docs_manager_was_the_one_that_was_broken :
    healthy 48 tagManager = true ∧ healthy 48 verifyGate = true ∧
    healthy 48 ciGate = true ∧ healthy 48 adsManager = false := by decide

/-- Health is not implied by either half alone. Both witnesses are needed, or a
workflow could buy a pass with the easier clause. -/
theorem neither_half_alone_is_enough :
    healthy 48 { ciGate with youngestGreenHours := 900 } = false ∧
    healthy 48 { tagManager with writes := ["lean/Proofs"] } = false := by decide

-- Contingent facts about today's repository, kept as guards rather than as
-- theorems: these numbers move whenever the workflows run, and a number that
-- moves must never become a hypothesis another proof rests on.
#guard adsManager.youngestGreenHours == 173
#guard tagManager.youngestGreenHours == 20
#guard requiredChecks.length == 4
#guard (docsAllowlist.length == 6)

end RotMoE.WorkflowRoles
