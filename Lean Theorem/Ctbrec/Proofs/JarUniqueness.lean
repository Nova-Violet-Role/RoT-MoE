/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: a class carried by two deployed jars has NO defined winner.

MEASURED 2026-08-13, and this is a live user-visible defect, not hygiene. `tools/spec-check.sh`
section 70 went RED:

    LINK-CHECK RED: 2 unresolvable reference(s)
      FIELD  ctbrec/preview/PreviewVolumeBus.LOG      <- referenced by PreviewVolumeBus.class
      METHOD ctbrec/preview/PreviewPipeline.audioUrl  <- referenced by PipPreviewWindow.class

A class referencing its OWN field and failing to resolve it is impossible within one class file, so it
could only mean two DIFFERENT copies. Measured: `ctbrec-26.7.11.jar` carried SIX stale
`ctbrec/preview/*` classes (pre-cp164/cp166: no `LOG`, no `audioUrl`) while `lib/common-26.7.11.jar`
carried the current SEVEN. And the app's own log carried the consequence:

    30 x java.lang.NoClassDefFoundError: ctbrec/preview/PreviewVolumeBus
       at ctbrec.ui.tabs.ThumbCell.createVolumeButton(ThumbCell.java:1128)
       at ctbrec.ui.tabs.ThumbCell.<init>(ThumbCell.java:317)
    tab 'Female' / 'Followed' / 'Girls' / 'New Female' / 'Online' / 'Private' FAILED while rendering
      91 model(s)

Six tabs rendering nothing, for the same reason as the 2026-08-05 defect (T0), in the one package T0
missed. `ModulePathVisibility.lean` proves the VISIBILITY rule; it says nothing about UNIQUENESS,
which is why the suite was green with duplicates present. Two different properties need two theorems.

Checker: `build/phase96.sh` (measured 68 deployed jars, 833 ctbrec class entries, 0 duplicates after
the repair; control on the pre-dedupe jar reproduces 10 duplicates, so the alarm can fire).

NOT PROVED: which copy a particular JVM picks. That is the point — it is not determined by the
artifacts, so no theorem may claim it. What IS proved: with duplicates the outcome is not a function
of the class, and uniqueness is exactly the condition that makes resolution deterministic.
-/

namespace Proofs.Ctbrec.JarUniqueness

/-- A deployment: for each jar (by index) the set of class entries it carries. -/
structure Deployment where
  jars : List (List String)
  deriving Repr

/-- Which jars carry a class, by index. -/
def carriers (d : Deployment) (c : String) : List Nat :=
  (d.jars.zipIdx).filterMap (fun (entries, i) => if entries.contains c then some i else none)

def count (d : Deployment) (c : String) : Nat := (carriers d c).length

/-- The checker's condition: no class in more than one jar. -/
def unique (d : Deployment) (classes : List String) : Bool :=
  classes.all (fun c => count d c ≤ 1)

/-- Resolution as the JVM does it once an order is fixed: first carrier wins. -/
def resolveWith (d : Deployment) (order : List Nat) (c : String) : Option Nat :=
  order.find? (fun i => (carriers d c).contains i)

/-! ## Law 1 — with a duplicate, the winner depends on the ORDER, not on the class

This is the whole defect. Two search orders over the same artifacts give different answers, so
"which class is loaded" is not a property of the deployment.
-/

/-- The measured shape: `ctbrec/preview/PreviewVolumeBus` in jar 0 (stale) and jar 1 (current). -/
def measured : Deployment :=
  ⟨[["ctbrec/preview/PreviewVolumeBus", "ctbrec/preview/PreviewPipeline"],
    ["ctbrec/preview/PreviewVolumeBus", "ctbrec/preview/PreviewPipeline",
     "ctbrec/preview/PcmAudioSink"]]⟩

theorem a_duplicate_is_carried_twice :
    count measured "ctbrec/preview/PreviewVolumeBus" = 2 := by
  decide

/-- Two orders, two different winners: the outcome is NOT determined by the artifacts. -/
theorem a_duplicate_has_no_defined_winner :
    resolveWith measured [0, 1] "ctbrec/preview/PreviewVolumeBus"
      ≠ resolveWith measured [1, 0] "ctbrec/preview/PreviewVolumeBus" := by
  decide

/-- Generalised: any class with two distinct carriers resolves differently under the two orders. -/
theorem two_carriers_means_order_decides (d : Deployment) (c : String) (i j : Nat)
    (hne : i ≠ j) (hi : i ∈ carriers d c) (hj : j ∈ carriers d c) :
    resolveWith d [i, j] c ≠ resolveWith d [j, i] c := by
  have ci : (carriers d c).contains i = true := by simpa using hi
  have cj : (carriers d c).contains j = true := by simpa using hj
  simp only [resolveWith, List.find?, ci, cj, if_true]
  simpa using hne

/-! ## Law 2 — uniqueness is exactly what makes resolution order-independent -/

/--
With at most one carrier, ANY two successful resolutions name the SAME jar — whatever the two search
orders were. This is the property the deployment must have for "which class is loaded" to be a fact
about the artifacts rather than about the launcher's command line.

(Stated as "the winners are equal" rather than "the two `Option`s are equal": it is the stronger and
more direct claim, and it avoids reasoning about the `none` case where neither order finds anything —
that case is `an_absent_class_is_not_a_duplicate`, a different question.)
-/
theorem uniqueness_makes_resolution_order_independent
    (d : Deployment) (c : String) (o1 o2 : List Nat) (i j : Nat) (h : count d c ≤ 1)
    (h1 : resolveWith d o1 c = some i) (h2 : resolveWith d o2 c = some j) : i = j := by
  have hi : (carriers d c).contains i = true := by
    simp only [resolveWith] at h1
    exact List.find?_some h1
  have hj : (carriers d c).contains j = true := by
    simp only [resolveWith] at h2
    exact List.find?_some h2
  match hc : carriers d c with
  | [] => rw [hc] at hi; simp at hi
  | [x] =>
      rw [hc] at hi hj
      simp at hi hj
      rw [hi, hj]
  | a :: b :: t =>
      rw [count, hc] at h
      simp at h

/-- The repaired deployment: the stale copies removed from jar 0. -/
def repaired : Deployment :=
  ⟨[["ctbrec/ui/tabs/ThumbCell"],
    ["ctbrec/preview/PreviewVolumeBus", "ctbrec/preview/PreviewPipeline",
     "ctbrec/preview/PcmAudioSink"]]⟩

theorem the_repair_makes_every_class_unique :
    unique repaired ["ctbrec/preview/PreviewVolumeBus", "ctbrec/preview/PreviewPipeline",
                     "ctbrec/preview/PcmAudioSink", "ctbrec/ui/tabs/ThumbCell"] = true := by
  decide

theorem the_pre_repair_deployment_was_not_unique :
    unique measured ["ctbrec/preview/PreviewVolumeBus"] = false := by
  decide

/-- After the repair the winner is the same under either order — the property that was missing. -/
theorem the_repair_makes_the_winner_order_independent :
    resolveWith repaired [0, 1] "ctbrec/preview/PreviewVolumeBus"
      = resolveWith repaired [1, 0] "ctbrec/preview/PreviewVolumeBus" := by
  decide

/-! ## Law 3 — the checker's verdict is exactly the uniqueness condition -/

theorem the_checker_accepts_iff_every_class_is_unique (d : Deployment) (cs : List String) :
    unique d cs = true ↔ ∀ c ∈ cs, count d c ≤ 1 := by
  simp [unique]

/-- A class in NO jar is not a duplicate — phase96 must not confuse absence with duplication. -/
theorem an_absent_class_is_not_a_duplicate :
    count repaired "ctbrec/io/DoesNotExist" = 0 := by
  decide

/-! ## The measured runs, as `#guard` -/

-- The defect: PreviewVolumeBus in two jars.
#guard count measured "ctbrec/preview/PreviewVolumeBus" == 2
-- PcmAudioSink was in the common jar ONLY -- which is why the app-jar copy of PreviewVolumeBus
-- could not resolve it and ThumbCell died with NoClassDefFoundError.
#guard count measured "ctbrec/preview/PcmAudioSink" == 1
-- Order decides, before the repair.
#guard resolveWith measured [0, 1] "ctbrec/preview/PreviewVolumeBus" == some 0
#guard resolveWith measured [1, 0] "ctbrec/preview/PreviewVolumeBus" == some 1
-- After the repair, both orders agree.
#guard resolveWith repaired [0, 1] "ctbrec/preview/PreviewVolumeBus" == some 1
#guard resolveWith repaired [1, 0] "ctbrec/preview/PreviewVolumeBus" == some 1
-- The verdicts.
#guard unique measured ["ctbrec/preview/PreviewVolumeBus"] == false
#guard unique repaired ["ctbrec/preview/PreviewVolumeBus"] == true

end Proofs.Ctbrec.JarUniqueness
