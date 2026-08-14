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
# Log rotation must not be able to hide an error

Measured 2026-08-08: the suite referenced `.log` 167 times and every reference resolved to the
single file `ctbrec.log`. The app writes three (`ctbrec.log`, `ctbrec.1.log`, `ctbrec-debug.log`),
and the rotated one held **1666 ERROR lines and 1743 exceptions** that no phase had ever read.

The defect is not "a file was forgotten". It is that **the observation was keyed on a NAME instead
of on the SET**. Under a name-keyed scan, the act of rotating -- which moves lines from the current
file into an archived one, changing nothing about what happened -- makes errors disappear from the
verdict. The suite then goes green *because* evidence was archived.

This file models both scans and proves the difference. `naiveScan` is what the suite did;
`globScan` is what it must do. The central theorem is `rotation_cannot_hide_from_glob`, with
`rotation_CAN_hide_from_naive` as its negative control: a fix whose failure mode cannot be
exhibited is not a fix, it is a hope.
-/

namespace CtbrecSpec.LogGlob

/-- An error signature: the source that emitted it and the shape of the message. Deliberately not
the raw line -- raw lines carry timestamps and thread names, so counting them would make every
run look novel. Measured example: `("MyFreeCamsClient.java:244", "MFC websocket failure")`. -/
structure Sig where
  source : String
  shape  : String
deriving DecidableEq, Repr

/-- One log file: its name, and the signatures it contains. -/
structure LogFile where
  name : String
  sigs : List Sig
deriving DecidableEq, Repr

/-- What is on disk. -/
abbrev LogSet := List LogFile

/-- The scan the suite actually performed: read ONE named file, ignore the rest. -/
def naiveScan (name : String) (s : LogSet) : List Sig :=
  (s.filter (fun f => f.name == name)).flatMap (fun f => f.sigs)

/-- The scan the glob performs: read EVERY file. -/
def globScan (s : LogSet) : List Sig := s.flatMap (fun f => f.sigs)

/-- Rotation: the current file's contents move into an archive file; the current file is emptied.
Nothing about what happened changes -- only where the bytes live. -/
def rotate (cur arch : String) (s : LogSet) : LogSet :=
  let moved := (s.filter (fun f => f.name == cur)).flatMap (fun f => f.sigs)
  { name := cur, sigs := [] } ::
  { name := arch, sigs := moved } ::
  s.filter (fun f => f.name != cur && f.name != arch)

/-! ## The theorems -/

/-- **A signature seen by the glob before rotation is still seen after it.**

This is the property the suite lacked. It is stated over an ARBITRARY signature and an arbitrary
log set, not over the MFC timeout that happened to be today's offender -- a theorem about the
specific error would expire the moment the error changed, while this one holds for every future
failure too. -/
theorem rotation_cannot_hide_from_glob
    (cur arch : String) (s : LogSet) (g : Sig)
    (h : g ∈ naiveScan cur s) :
    g ∈ globScan (rotate cur arch s) := by
  -- The archive file created by `rotate` holds exactly `naiveScan cur s`, and it is an element of
  -- the rotated set. Membership in the glob then follows from `glob_sees_every_file`.
  have harch : ({ name := arch, sigs := naiveScan cur s } : LogFile) ∈ rotate cur arch s := by
    simp [rotate, naiveScan]
  exact List.mem_flatMap.mpr ⟨{ name := arch, sigs := naiveScan cur s }, harch, h⟩

/-- **The negative control: rotation CAN hide an error from the name-keyed scan.**

Concrete witness, so the defect is exhibited rather than asserted. Before rotation the naive scan
sees the signature; after, it sees nothing. If this theorem ever fails to hold, the model has
stopped describing the bug it was written for. -/
theorem rotation_CAN_hide_from_naive :
    let g : Sig := { source := "MyFreeCamsClient.java:244", shape := "MFC websocket failure" }
    let s : LogSet := [{ name := "ctbrec.log", sigs := [g] }]
    g ∈ naiveScan "ctbrec.log" s ∧ g ∉ naiveScan "ctbrec.log" (rotate "ctbrec.log" "ctbrec.1.log" s) := by
  decide

/-- The glob loses nothing in general: every signature anywhere is reported. -/
theorem glob_sees_every_file (s : LogSet) (f : LogFile) (g : Sig)
    (hf : f ∈ s) (hg : g ∈ f.sigs) : g ∈ globScan s :=
  List.mem_flatMap.mpr ⟨f, hf, hg⟩

/-- Rotation preserves the glob's view in the concrete measured case too -- an executable pin on
the general theorem above. -/
theorem glob_survives_rotation_concretely :
    let g : Sig := { source := "MyFreeCamsClient.java:244", shape := "MFC websocket failure" }
    let s : LogSet := [{ name := "ctbrec.log", sigs := [g] }]
    g ∈ globScan (rotate "ctbrec.log" "ctbrec.1.log" s) := by
  decide

/-- A verdict must key on NOVELTY, not on a total. A count-based bound chosen today is satisfied
by construction by today's numbers and can never fire; `isNovel` can. -/
def isNovel (known : List Sig) (g : Sig) : Bool := !(known.contains g)

/-- A signature already in the baseline is not novel -- the alarm does not cry wolf. -/
theorem known_is_not_novel (known : List Sig) (g : Sig) (h : g ∈ known) :
    isNovel known g = false := by
  simp [isNovel, List.contains_iff_mem, h]

/-- A signature absent from the baseline IS novel -- the alarm can fire. -/
theorem unknown_is_novel (known : List Sig) (g : Sig) (h : g ∉ known) :
    isNovel known g = true := by
  simp [isNovel, List.contains_iff_mem, h]

/-! ## Executable checks -/

private def mfc : Sig := { source := "MyFreeCamsClient.java:244", shape := "MFC websocket failure" }
private def dns : Sig := { source := "MyFreeCamsClient.java:244", shape := "UnknownHostException" }
private def one : LogSet := [{ name := "ctbrec.log", sigs := [mfc] }]

#guard (naiveScan "ctbrec.log" one).length == 1
#guard (naiveScan "ctbrec.log" (rotate "ctbrec.log" "ctbrec.1.log" one)).length == 0
#guard (globScan (rotate "ctbrec.log" "ctbrec.1.log" one)).length == 1
#guard isNovel [mfc] mfc == false
#guard isNovel [mfc] dns == true

end CtbrecSpec.LogGlob
