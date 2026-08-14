/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Authors: Saimono
-/

/-!
# PROVED + WRITTEN != DEPLOYED != REACHABLE

Measured 2026-08-08. The Socio asked where the seats UI was after ten hours. It had been
**specified, proved (24 theorems / 20 guards in `SeatAllocation.lean`) and written in Java** — and
never compiled into the jars the app loads:

```
unzip -l <jar> | grep -c Seat   ->  0 in BOTH jars
javap -p ctbrec.Settings        ->  no enforceSeats field
```

A set-difference audit (`comm -23` over 624 source classes vs 818 jar classes) found **nine** such
classes, every one from a checkpoint reported CLOSED.

Then a second gap appeared one level down: after shipping `ModelViewerCount`, the deployed
`ThumbCell.class` — its ONLY caller — still referenced nothing (`refs_MVC=0`, `refs_Seat=0`). A
class present in the artifact but invoked by nobody is exactly as absent as one never built.

This module makes those three states distinct so they cannot be conflated again. The moral, stated
as `green_build_says_nothing_about_deployment`: **`lake build` exit 0 and a green suite are silent
about whether the code is in the artifact.**
-/

namespace CtbrecSpec.Deployment

/-- Everything observable about one feature, from the proof down to the artifact. -/
structure Feature where
  /-- A Lean module proves its behaviour. -/
  proved : Bool
  /-- Java source for it exists in the tree. -/
  written : Bool
  /-- Its `.class` is inside the jar the app actually loads. -/
  inArtifact : Bool
  /-- Some class in the artifact actually invokes it. -/
  hasCaller : Bool
deriving DecidableEq, Repr

/-- The only state a user can observe. Presence without a caller is dead weight. -/
def reachable (f : Feature) : Bool := f.inArtifact && f.hasCaller

/-- What the session's process actually checked before declaring a feature "closed". -/
def oldClosedCriterion (f : Feature) : Bool := f.proved && f.written

/-- What "closed" must mean. -/
def honestClosedCriterion (f : Feature) : Bool :=
  f.proved && f.written && f.inArtifact && f.hasCaller

/-! ## The theorems -/

/-- **The seats defect, exactly as measured**: proved and written, absent from the artifact,
therefore not reachable — while the old criterion called it closed. -/
theorem seats_before_cp144 :
    let f : Feature := { proved := true, written := true, inArtifact := false, hasCaller := false }
    oldClosedCriterion f = true ∧ reachable f = false := by
  decide

/-- **The `ThumbCell` defect**: in the artifact, but nothing calls it. Deploying the class was not
enough, and the old criterion STILL says closed. -/
theorem deployed_without_caller_is_unreachable :
    let f : Feature := { proved := true, written := true, inArtifact := true, hasCaller := false }
    oldClosedCriterion f = true ∧ f.inArtifact = true ∧ reachable f = false := by
  decide

/-- **The general statement, over an ARBITRARY feature**: proof and source say nothing about
reachability. Quantified so it cannot hold by accident of today's tree. -/
theorem proof_and_source_do_not_imply_reachable (f : Feature)
    (hp : f.proved = true) (hw : f.written = true) (hc : f.hasCaller = false) :
    oldClosedCriterion f = true ∧ reachable f = false := by
  simp [oldClosedCriterion, reachable, hp, hw, hc]

/-- **A green build is silent about deployment.** `proved` does not constrain `inArtifact` at all:
for every feature there is one agreeing on the proof and disagreeing on the artifact. -/
theorem green_build_says_nothing_about_deployment (f : Feature) :
    ∃ g : Feature, g.proved = f.proved ∧ g.inArtifact = !f.inArtifact := by
  exact ⟨{ f with inArtifact := !f.inArtifact }, rfl, rfl⟩

/-- The honest criterion is strictly stronger: it implies the old one, never the reverse. -/
theorem honest_implies_old (f : Feature) (h : honestClosedCriterion f = true) :
    oldClosedCriterion f = true := by
  cases f with
  | mk p w a c =>
    cases p <;> cases w <;> cases a <;> cases c <;>
      simp_all [honestClosedCriterion, oldClosedCriterion]

/-- And the converse FAILS — the witness is the seats defect itself. -/
theorem old_does_not_imply_honest :
    ∃ f : Feature, oldClosedCriterion f = true ∧ honestClosedCriterion f = false := by
  exact ⟨{ proved := true, written := true, inArtifact := false, hasCaller := false }, by decide, by decide⟩

/-- **The honest criterion is exactly "old criterion AND reachable"** — no more, no less. -/
theorem honest_is_old_and_reachable (f : Feature) :
    honestClosedCriterion f = (oldClosedCriterion f && reachable f) := by
  simp [honestClosedCriterion, oldClosedCriterion, reachable, Bool.and_assoc]

/-! ## Executable checks — the measured states of this session -/

private def seatsBefore : Feature := { proved := true, written := true, inArtifact := false, hasCaller := false }
private def mvcAfterClassOnly : Feature := { proved := true, written := true, inArtifact := true, hasCaller := false }
private def seatsAfterCp146 : Feature := { proved := true, written := true, inArtifact := true, hasCaller := true }

#guard oldClosedCriterion seatsBefore == true
#guard reachable seatsBefore == false
#guard honestClosedCriterion seatsBefore == false
#guard oldClosedCriterion mvcAfterClassOnly == true
#guard reachable mvcAfterClassOnly == false
#guard reachable seatsAfterCp146 == true
#guard honestClosedCriterion seatsAfterCp146 == true
#guard honestClosedCriterion seatsAfterCp146 == (oldClosedCriterion seatsAfterCp146 && reachable seatsAfterCp146)

end CtbrecSpec.Deployment
