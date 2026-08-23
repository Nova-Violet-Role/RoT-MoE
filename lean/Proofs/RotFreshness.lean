/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A verdict is about the tree it was computed on, and about no other

`Proofs.RotCoverage` proved that auditing part of a suite licenses nothing about
the whole. This module is about the other axis of the same mistake: a verdict
that was true when it was computed, read later as though it were true now.

The repository has already met this twice, both measured, neither hypothetical.
An archive sweep passed at gate 3 of 55 and the packager rewrote the archives it
had blessed at gate 47 of the same run -- the summary was internally consistent
and described a tree that no longer existed. And ten gates live behind a full
mode that no commit triggers, so the newest statement about them may be
arbitrarily old while the banner beside it is current.

The model is deliberately small. A `Snapshot` is whatever identifies a state of
the tree; `Nat` stands in because only equality and difference matter. A
`Receipt` is a verdict together with the snapshot it was computed on. `truth` is
the verdict a full run WOULD produce at a given snapshot -- not something any
checker can read, which is the entire difficulty.

Three results carry the weight.

`a_stale_receipt_can_describe_a_tree_that_no_longer_exists` exhibits a receipt
that was honestly computed, was correct when made, and disagrees with the truth
at the current snapshot. Nothing was faked and no instrument malfunctioned.

`staleness_is_invisible_in_the_verdict` is why this cannot be handled by reading
results harder: two receipts carrying the SAME verdict, one fresh and one stale.
The verdict field contains no information about its own age, so a reader looking
only at green-or-red cannot distinguish a current answer from an expired one.

`absence_and_green_must_not_agree` is the case the repository keeps rediscovering
under other names: if a checker treats "no receipt" the way it treats a good
one, then a gate that has never run in its life is indistinguishable from a gate
that just passed. `check` is therefore defined to answer red on `none`, and
`check_sound` proves that every green it ever emits came from a receipt that is
both fresh and truthful.

`ignoring_freshness_is_unsound` is the negative control in Lean: the obvious
simpler checker, the one that just believes the receipt, emits green where the
truth is red.

None of this says how stale is too stale. That is a policy number, it lives in
the shell gate, and it is not a theorem.
-/
import Proofs.RotVacuousGate

namespace RotMoE.Freshness

open RotMoE.Vacuity
open Verdict

/-- A verdict together with the tree-state it was computed on. -/
structure Receipt where
  snapshot : Nat
  verdict  : Verdict
deriving DecidableEq

/-- The receipt was computed on the state we are asking about. -/
def Fresh (r : Receipt) (now : Nat) : Prop := r.snapshot = now

/-- The receipt told the truth about the state it was computed on. An honest
instrument gives this; it is NOT the same as being about the present. -/
def Honest (r : Receipt) (truth : Nat → Verdict) : Prop := r.verdict = truth r.snapshot

/-- The checker. `none` -- no run has ever been recorded -- answers red, and
that choice is the subject of `absence_and_green_must_not_agree`. -/
def check (ro : Option Receipt) (now : Nat) : Verdict :=
  match ro with
  | none   => red
  | some r => if r.snapshot = now then r.verdict else red

/-- A receipt computed on the current state, and honest, IS the present truth. -/
theorem fresh_and_honest_is_the_present (r : Receipt) (truth : Nat → Verdict)
    (now : Nat) (hh : Honest r truth) (hf : Fresh r now) : r.verdict = truth now := by
  unfold Fresh at hf
  unfold Honest at hh
  rw [hh, hf]

/-- THE STALENESS RESULT. An honest receipt, correct when computed, disagreeing
with the truth at the current snapshot. No instrument misbehaved. -/
theorem a_stale_receipt_can_describe_a_tree_that_no_longer_exists :
    ∃ (r : Receipt) (truth : Nat → Verdict) (now : Nat),
      Honest r truth ∧ ¬ Fresh r now ∧ r.verdict ≠ truth now := by
  refine ⟨⟨0, green⟩, (fun n => if n = 0 then green else red), 1, rfl, ?_, ?_⟩
  · intro h
    exact Nat.noConfusion h
  · decide

/-- WHY READING HARDER DOES NOT HELP. Two receipts carrying the same verdict,
one fresh and one stale: the verdict field says nothing about its own age. -/
theorem staleness_is_invisible_in_the_verdict :
    ∃ (r₁ r₂ : Receipt) (now : Nat),
      r₁.verdict = r₂.verdict ∧ Fresh r₁ now ∧ ¬ Fresh r₂ now :=
  ⟨⟨1, green⟩, ⟨0, green⟩, 1, rfl, rfl, by intro h; exact Nat.noConfusion h⟩

/-- Absence must not read as success: with no recorded run at all, the checker
answers red, so a gate that never ran is distinguishable from one that passed. -/
theorem absence_and_green_must_not_agree (now : Nat) :
    check none now = red ∧ check (some ⟨now, green⟩) now = green := by
  constructor
  · rfl
  · show (if now = now then green else red) = green
    rw [if_pos (rfl : now = now)]

/-- A stale receipt cannot produce a green, whatever it says. -/
theorem stale_never_passes (r : Receipt) (now : Nat) (hs : ¬ Fresh r now) :
    check (some r) now = red := by
  unfold Fresh at hs
  show (if r.snapshot = now then r.verdict else red) = red
  rw [if_neg hs]

/-- SOUNDNESS. Every green this checker emits came from a receipt that was both
fresh and, if the instrument was honest, true of the present tree. -/
theorem check_sound (ro : Option Receipt) (now : Nat) (truth : Nat → Verdict)
    (hg : check ro now = green) :
    ∃ r, ro = some r ∧ Fresh r now ∧ (Honest r truth → r.verdict = truth now) := by
  cases ro with
  | none => exact Verdict.noConfusion hg
  | some r =>
    refine ⟨r, rfl, ?_, ?_⟩
    · by_cases h : r.snapshot = now
      · exact h
      · exfalso
        rw [show check (some r) now = red from stale_never_passes r now h] at hg
        exact Verdict.noConfusion hg
    · intro hh
      have hf : Fresh r now := by
        by_cases h : r.snapshot = now
        · exact h
        · exfalso
          rw [show check (some r) now = red from stale_never_passes r now h] at hg
          exact Verdict.noConfusion hg
      exact fresh_and_honest_is_the_present r truth now hh hf

/-- The naive checker: believe the receipt, ignore its age. -/
def believe (ro : Option Receipt) : Verdict :=
  match ro with
  | none   => green
  | some r => r.verdict

/-- THE NEGATIVE CONTROL, IN LEAN. The naive checker emits green where the
present truth is red -- twice over: on a stale receipt, and on no receipt. -/
theorem ignoring_freshness_is_unsound :
    ∃ (ro : Option Receipt) (truth : Nat → Verdict) (now : Nat),
      believe ro = green ∧ truth now = red := by
  refine ⟨some ⟨0, green⟩, (fun n => if n = 0 then green else red), 1, rfl, by decide⟩

theorem believing_nothing_is_also_unsound :
    ∃ (truth : Nat → Verdict) (now : Nat), believe none = green ∧ truth now = red :=
  ⟨(fun _ => red), 0, rfl, rfl⟩

end RotMoE.Freshness
