/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # An evidence haystack that confirms everything has confirmed nothing

`bench/work-trace.js` reads the P2.4 *process* observables off a session
transcript. Its most fragile observable is **O4 — claims stated with no
supporting tool output**, because the test is "does this number appear anywhere
in the evidence". On a long session the evidence is megabytes, every short
number occurs somewhere by accident, and O4 reports a comforting **0** that is a
fact about the haystack rather than about the answer.

That is not a hypothetical. Measured 2026-08-10 over real transcripts:

| evidence | tool calls | fabricated claims "confirmed" by chance |
|---:|---:|---:|
| 2.68 MB | 5355 | **42.2 %** |
| 1.20 MB | 1637 | **24.0 %** |
| 152 KB | 218 | 3.0 % |
| 4.8 KB | 5 | 1.0 % |

So a clean `O4 = 0` on the first row means nothing whatsoever, and reporting it
as evidence would be a false green of exactly the kind this repo exists to stop.

This module proves the failure is *structural*, not bad luck, and that the guard
against it is load-bearing:

* `saturated_cannot_tell_two_messages_apart` — under saturation an honest
  message and a fabricated one produce the **identical** count. The instrument
  is not noisy, it is *blind*; no sample size fixes it.
* `a_saturated_haystack_yields_no_verdict` — the `O4_usable` gate makes
  `Verdict.clean` **unreachable** on a saturated run. This is what stops the
  blind case from being reported as a pass.

It also proves why the extractor's controls must run in **both** directions:
`positive_control_cannot_catch_a_loosened_detector`. Measured against that
theorem — mutant W01 (`isVerification` forced to `true`) was caught by exactly
the two negative controls and by none of the positive ones.

Nothing here claims the router works. It constrains what the *instrument* is
allowed to conclude, which is the precondition for P2.4 meaning anything.
-/

namespace RotWorkTrace

/-! ## The model

Claims and evidence tokens are `Nat`; only their equality matters, so nothing is
lost and everything becomes decidable and executable. -/

/-- Keep one occurrence of each element. Used for "distinct files". -/
def dedup : List Nat → List Nat
  | [] => []
  | x :: xs => if xs.contains x then dedup xs else x :: dedup xs

/-- O4's test: a claim is flagged when the evidence does not contain it. -/
def flagged (evidence : List Nat) (c : Nat) : Bool := !(evidence.contains c)

/-- The reported O4 count over the claims in the closing message. -/
def countFlags (evidence : List Nat) : List Nat → Nat
  | [] => 0
  | c :: rest => cond (flagged evidence c) 1 0 + countFlags evidence rest

/-- The evidence confirms every token of `pool` — the saturated regime.
(`universe` is a reserved keyword in Lean 4, hence `pool`.) -/
def saturated (evidence pool : List Nat) : Prop :=
  ∀ c ∈ pool, evidence.contains c = true

/-! ## O4 is blind under saturation -/

theorem empty_evidence_flags_every_claim (c : Nat) : flagged [] c = true := rfl

theorem saturated_flags_nothing (e u : List Nat) (h : saturated e u) :
    ∀ c ∈ u, flagged e c = false := by
  intro c hc
  have hce : e.contains c = true := h c hc
  simp only [flagged, hce, Bool.not_true]

theorem saturated_message_scores_zero (e u : List Nat) (h : saturated e u) :
    ∀ l : List Nat, (∀ c ∈ l, c ∈ u) → countFlags e l = 0 := by
  intro l
  induction l with
  | nil => intro _; rfl
  | cons x xs ih =>
    intro hl
    have hx : flagged e x = false := saturated_flags_nothing e u h x (hl x (by simp))
    have hxs : countFlags e xs = 0 := ih (fun c hc => hl c (by simp [hc]))
    have hstep : countFlags e (x :: xs) = countFlags e xs := by
      simp only [countFlags, hx, Bool.cond_false, Nat.zero_add]
    rw [hstep, hxs]

/-- **The blindness theorem.** Under saturation the honest message and the
fabricated one get the same score, so the number carries no information at all.
This is why a bigger sample cannot rescue a saturated run. -/
theorem saturated_cannot_tell_two_messages_apart
    (e u honest fabricated : List Nat) (h : saturated e u)
    (h1 : ∀ c ∈ honest, c ∈ u) (h2 : ∀ c ∈ fabricated, c ∈ u) :
    countFlags e honest = countFlags e fabricated := by
  rw [saturated_message_scores_zero e u h honest h1,
      saturated_message_scores_zero e u h fabricated h2]

/-- The contrast: a sparse haystack *does* separate the two cases. -/
theorem a_sparse_haystack_separates_them :
    countFlags [7] [7] = 0 ∧ countFlags [7] [9] = 1 := by decide

theorem more_evidence_never_adds_flags (x : Nat) (e : List Nat) (c : Nat)
    (h : flagged (x :: e) c = true) : flagged e c = true := by
  simp [flagged] at h ⊢
  exact h.2

/-! ## The usability gate, and why it is load-bearing -/

/-- How many fabricated probes the evidence "confirms" anyway. -/
def confirmed (e : List Nat) : List Nat → Nat
  | [] => 0
  | p :: rest => cond (e.contains p) 1 0 + confirmed e rest

/-- Usable when at most 10 % of fabricated probes are confirmed by chance. -/
def usable (e probes : List Nat) : Bool :=
  decide (10 * confirmed e probes ≤ probes.length)

theorem confirmed_all (e : List Nat) :
    ∀ l : List Nat, (∀ p ∈ l, e.contains p = true) → confirmed e l = l.length := by
  intro l
  induction l with
  | nil => intro _; rfl
  | cons x xs ih =>
    intro hl
    have hx : e.contains x = true := hl x (by simp)
    have hxs : confirmed e xs = xs.length := ih (fun p hp => hl p (by simp [hp]))
    have hstep : confirmed e (x :: xs) = 1 + confirmed e xs := by
      simp only [confirmed, hx, Bool.cond_true]
    rw [hstep, hxs, List.length_cons]
    omega

theorem saturated_probes_are_not_usable (e probes : List Nat) (hne : probes ≠ [])
    (h : ∀ p ∈ probes, e.contains p = true) : usable e probes = false := by
  have hc := confirmed_all e probes h
  have hpos : 0 < probes.length := by
    cases probes with
    | nil => exact absurd rfl hne
    | cons a as => simp
  simp [usable, hc]
  omega

/-- What the extractor may report. -/
inductive Verdict
  | clean
  | flagged
  | noVerdict
  deriving DecidableEq, Repr

def verdict (e probes claims : List Nat) : Verdict :=
  if usable e probes then
    (if countFlags e claims == 0 then Verdict.clean else Verdict.flagged)
  else Verdict.noVerdict

/-- **The gate that stops the false green.** However clean a saturated run
looks, `clean` is unreachable — the extractor must say it has no verdict. -/
theorem a_saturated_haystack_yields_no_verdict (e probes claims : List Nat)
    (hne : probes ≠ []) (h : ∀ p ∈ probes, e.contains p = true) :
    verdict e probes claims = Verdict.noVerdict := by
  simp [verdict, saturated_probes_are_not_usable e probes hne h]

theorem a_saturated_haystack_is_never_clean (e probes claims : List Nat)
    (hne : probes ≠ []) (h : ∀ p ∈ probes, e.contains p = true) :
    verdict e probes claims ≠ Verdict.clean := by
  rw [a_saturated_haystack_yields_no_verdict e probes claims hne h]
  intro hcon
  exact Verdict.noConfusion hcon

/-- And the gate is not vacuous: a sparse run still reaches a real verdict. -/
theorem a_sparse_run_still_reaches_a_verdict :
    verdict [7] [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11] [7] = Verdict.clean ∧
    verdict [7] [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11] [9] = Verdict.flagged := by decide

/-! ## Why controls must run in both directions

`1` encodes a command that verifies (`lake build`); `0` encodes one that does
not (`ls`). A *loosened* detector answers `true` to everything. -/

def isVerification (cmd : Nat) : Bool := cmd == 1

def loosened (_ : Nat) : Bool := true

/-- A suite built only from "this must fire" fixtures agrees with a detector
that fires on everything — so it cannot catch one. -/
theorem positive_control_cannot_catch_a_loosened_detector :
    loosened 1 = isVerification 1 := by decide

/-- Only the "this must stay silent" direction detects the loosening. Measured:
mutant W01 failed exactly the two negative controls, 14 others passed. -/
theorem only_a_negative_control_catches_a_loosened_detector :
    loosened 0 ≠ isVerification 0 := by decide

/-! ## O2 rework and O3 reads-before-first-write -/

def rework (writes : List Nat) : Nat := writes.length - (dedup writes).length

theorem rework_is_zero_when_every_write_is_distinct (w : List Nat) (h : dedup w = w) :
    rework w = 0 := by simp [rework, h]

theorem a_second_write_to_one_file_is_rework : rework [1, 1] = 1 := by decide

inductive Ev
  | read (p : Nat)
  | write (p : Nat)
  deriving DecidableEq, Repr

def readsBefore : List Ev → List Nat
  | [] => []
  | Ev.write _ :: _ => []
  | Ev.read p :: rest => p :: readsBefore rest

def o3 (es : List Ev) : Nat := (dedup (readsBefore es)).length

/-- A trace that writes before reading anything scores zero, for every tail. -/
theorem a_trace_that_writes_first_has_no_reads_before_it (p : Nat) (rest : List Ev) :
    o3 (Ev.write p :: rest) = 0 := rfl

theorem duplicate_reads_count_once :
    o3 [Ev.read 1, Ev.read 1, Ev.write 3] = 1 := by decide

theorem reads_before_a_write_count :
    o3 [Ev.read 1, Ev.read 2, Ev.write 3] = 2 := by decide

/-! ## Executable checks

The saturation figures are **measurements of particular transcripts**, so they
are `#guard`s documenting the present, never theorems other proofs lean on. -/

/-- Fabricated-claim confirmation rate ×1000, measured 2026-08-10. -/
def measuredLongSession : Nat := 422
def measuredMidSession : Nat := 240
def measuredShortSession : Nat := 10
def usableThreshold : Nat := 100

#guard measuredLongSession > usableThreshold
#guard measuredMidSession > usableThreshold
#guard measuredShortSession < usableThreshold

#guard flagged [] 5 = true
#guard flagged [5] 5 = false
#guard countFlags [1, 2, 3] [1, 2, 3] = 0
#guard countFlags [1, 2, 3] [4, 5] = 2
#guard confirmed [1, 2, 3] [1, 2, 3] = 3
#guard confirmed [1, 2, 3] [9] = 0
#guard usable [1, 2, 3] [1, 2, 3] = false
#guard usable [] [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11] = true
#guard verdict [1, 2, 3] [1, 2, 3] [9] = Verdict.noVerdict
#guard rework [1, 2, 3] = 0
#guard rework [1, 1, 1] = 2
#guard o3 [Ev.write 1, Ev.read 2, Ev.read 3] = 0
#guard o3 [Ev.read 1, Ev.read 2, Ev.read 3] = 3

end RotWorkTrace
