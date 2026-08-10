/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # An emptied file is a mutant that text-reading gates cannot see

Measured three times in this repository, most recently **2026-08-10**:
`checker/mutate-checker.sh` was interrupted and left `hooks/prover-remind.sh`
(32209 bytes in git) and `hooks/prover-remind.ps1` (28315 bytes) both at **zero
bytes on disk**.

The harness's own header states why nothing catches it: *"two fast sweeps stayed
green afterwards: every fast gate reads source TEXT, and an empty file has no
offending text in it."* Emptying a file is itself one of that harness's mutants,
so the tree carries a **live mutant with the evidence deleted**.

Two separate facts are proved here, because they have different fixes.

**1. The blindness.** A gate that searches file text for an offending pattern
returns the same verdict for a healthy empty file and for a truncated one —
`text_gate_is_blind_to_truncation`. Not "unreliable": blind. No stricter
pattern helps, because the offending text is precisely what was deleted. Only a
check comparing disk against what git holds separates them
(`integrity_separates_them`), which is what `checker/tree-integrity.sh` does.

This is the second instrument in two days with the same shape — see
`RotCiSkip.conclusion_audit_is_blind_to_a_skip`, where a conclusion audit could
not see a step that skipped inside a green run. The recurring lesson is that
**absence of evidence is invisible to any instrument that only reads evidence.**

**2. The restore bug that produced it.** `restore()` and the EXIT trap in
`mutate-checker.sh` both do `cat "$f.mutbak" > "$f.rtmp" && mv -f "$f.rtmp" "$f"`
guarded by `[ -f "$f.mutbak" ]` — **existence, not content**. The 2026-08-07 fix
made that swap atomic, which is real and insufficient: an empty or half-written
backup is restored *atomically over the original*, with a successful exit code.
`empty_payload_restore_truncates` states exactly that, and
`guarded_restore_never_empties` states the one-line repair.
-/

namespace RotTreeIntegrity

/-- A tracked file: how many bytes git holds for it, and the tokens actually on
disk. `disk = []` models an empty file. -/
structure Tracked where
  /-- Identifier standing in for the path. -/
  id : Nat
  /-- Size of the blob git holds. Zero means git considers it legitimately empty. -/
  gitBytes : Nat
  /-- Tokens present on disk; `[]` is an empty file. -/
  disk : List Nat
  deriving DecidableEq, Repr

/-- Git has content for this file, but the disk copy is empty. -/
def truncated (f : Tracked) : Bool :=
  !(f.gitBytes == 0) && f.disk.isEmpty

/-- The integrity gate: no tracked file was emptied. -/
def integrity (fs : List Tracked) : Bool := !(fs.any truncated)

/-- What a text-reading gate does: look for an offending token in the content. -/
def hasBad (bad : Nat) (f : Tracked) : Bool := f.disk.contains bad

/-- A text-reading gate over the whole tree. -/
def textGate (bad : Nat) (fs : List Tracked) : Bool := !(fs.any (hasBad bad))

/-! ## 1. The blindness -/

/-- **An empty file passes every text gate, whatever it is looking for.** The
offending text is exactly what was deleted, so no stricter pattern recovers it. -/
theorem empty_passes_every_text_gate (bad : Nat) (f : Tracked) (h : f.disk = []) :
    hasBad bad f = false := by
  simp only [hasBad, h, List.contains_nil]

/-- **The blindness, as an indistinguishability.** A legitimately empty file and
a truncated one give a text gate the same answer, for every pattern. -/
theorem text_gate_is_blind_to_truncation (bad : Nat) :
    textGate bad [⟨1, 0, []⟩] = textGate bad [⟨1, 100, []⟩] ∧
    ([⟨1, 0, []⟩] : List Tracked) ≠ [⟨1, 100, []⟩] := by
  constructor
  · simp only [textGate, List.any_cons, hasBad, List.contains_nil, List.any_nil,
      Bool.or_false]
  · intro h; exact absurd (List.head_eq_of_cons_eq h) (by decide)

/-- **The payoff.** The integrity check distinguishes exactly the pair that
defeated the text gate — so it is a second instrument, not a restatement. -/
theorem integrity_separates_them :
    integrity [⟨1, 0, []⟩] = true ∧ integrity [⟨1, 100, []⟩] = false := by decide

/-- Any truncated file in the tree is caught, wherever it sits. -/
theorem integrity_detects_any_truncation (fs : List Tracked) (f : Tracked)
    (hmem : f ∈ fs) (hgit : (f.gitBytes == 0) = false) (hdisk : f.disk = []) :
    integrity fs = false := by
  have hf : truncated f = true := by
    simp only [truncated, hgit, hdisk, Bool.not_false, List.isEmpty_nil,
      Bool.and_true]
  have hany : fs.any truncated = true := List.any_eq_true.mpr ⟨f, hmem, hf⟩
  simp only [integrity, hany, Bool.not_true]

/-- **A legitimately empty tracked file is not flagged.** Without this the gate
would be unusable: the repo does track empty files on purpose, and a check that
cannot tell them apart would be deleted within a week. -/
theorem legitimately_empty_is_not_flagged (f : Tracked) (h : f.gitBytes = 0) :
    truncated f = false := by
  simp only [truncated, h, beq_self_eq_true, Bool.not_true, Bool.false_and]

/-- A file with content on disk is never reported as truncated. -/
theorem content_on_disk_is_never_truncated (f : Tracked) (h : f.disk ≠ []) :
    truncated f = false := by
  cases hd : f.disk with
  | nil => exact absurd hd h
  | cons x xs => simp only [truncated, hd, List.isEmpty_cons, Bool.and_false]

/-! ## 2. The restore that caused it -/

/-- Overwrite a file's disk content with a payload — `cat "$f.mutbak" > "$f"`. -/
def restoreFrom (payload : List Nat) (f : Tracked) : Tracked :=
  { f with disk := payload }

/-- **The bug, stated.** Restoring from an EMPTY backup truncates a file git has
content for — atomically, and with a successful exit code. Guarding on the
backup's existence rather than its content is what allows this. -/
theorem empty_payload_restore_truncates (f : Tracked)
    (h : (f.gitBytes == 0) = false) : truncated (restoreFrom [] f) = true := by
  simp only [truncated, restoreFrom, h, Bool.not_false, List.isEmpty_nil,
    Bool.and_true]

/-- A restore from a NON-empty backup is safe. -/
theorem nonempty_payload_restore_is_safe (payload : List Nat) (f : Tracked)
    (hp : payload ≠ []) : truncated (restoreFrom payload f) = false := by
  cases hpl : payload with
  | nil => exact absurd hpl hp
  | cons x xs =>
    simp only [truncated, restoreFrom, List.isEmpty_cons, Bool.and_false]

/-- The one-line repair: refuse to restore an empty payload. -/
def guardedRestore (payload : List Nat) (f : Tracked) : Tracked :=
  cond payload.isEmpty f (restoreFrom payload f)

/-- **The repair works.** A guarded restore can never empty a file that had
content, whatever the backup looks like. -/
theorem guarded_restore_never_empties (payload : List Nat) (f : Tracked)
    (h : f.disk ≠ []) : (guardedRestore payload f).disk ≠ [] := by
  cases hpl : payload with
  | nil => simpa only [guardedRestore, hpl, List.isEmpty_nil, Bool.cond_true] using h
  | cons x xs =>
    simp only [guardedRestore, List.isEmpty_cons, Bool.cond_false, restoreFrom]
    exact List.cons_ne_nil x xs

/-- The guard does not cost anything real: a good backup still restores. -/
theorem guarded_restore_still_restores (x : Nat) (xs : List Nat) (f : Tracked) :
    (guardedRestore (x :: xs) f).disk = x :: xs := by
  simp only [guardedRestore, List.isEmpty_cons, Bool.cond_false, restoreFrom]

/-! ## Executable checks — measurements of the 2026-08-10 incident -/

/-- Bytes git holds for `hooks/prover-remind.sh`. -/
def measuredShBytes : Nat := 32209
/-- Bytes git holds for `hooks/prover-remind.ps1`. -/
def measuredPs1Bytes : Nat := 28315
/-- Both were this size on disk after the interrupted run. -/
def measuredDiskBytes : Nat := 0
/-- Recorded occurrences of this incident: 2026-08-05, 08-07, 08-10. -/
def measuredIncidents : Nat := 3

#guard measuredDiskBytes = 0
#guard measuredShBytes > measuredDiskBytes
#guard measuredPs1Bytes > measuredDiskBytes
#guard measuredIncidents = 3

#guard truncated ⟨1, 32209, []⟩ = true
#guard truncated ⟨1, 0, []⟩ = false
#guard truncated ⟨1, 32209, [7]⟩ = false
#guard integrity [⟨1, 32209, [7]⟩, ⟨2, 28315, [9]⟩] = true
#guard integrity [⟨1, 32209, [7]⟩, ⟨2, 28315, []⟩] = false
#guard integrity [] = true
#guard textGate 7 [⟨1, 32209, []⟩] = true
#guard (restoreFrom [] ⟨1, 32209, [7]⟩).disk = []
#guard (guardedRestore [] ⟨1, 32209, [7]⟩).disk = [7]
#guard (guardedRestore [9] ⟨1, 32209, [7]⟩).disk = [9]

end RotTreeIntegrity
