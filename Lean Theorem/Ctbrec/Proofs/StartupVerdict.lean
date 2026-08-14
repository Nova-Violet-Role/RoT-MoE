/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CP86 -- when is a failed recording start a TRANSIENT, and when is it a FAULT?

WHAT WAS MEASURED (ctbrec.log, 2026-08-06)
------------------------------------------
    22:38:31  No LL-HLS media for 30 s -> stopping        (kellytesh ended the broadcast)
    22:38:32  ffmpeg shutdown rung=naturalDrain exit=0     (clean teardown)
    22:38:32  DeleteTooShort: PT3.02S < PT15M -> deleted   (3 s fragment discarded)
    22:38:32  Restarting -> Starting recording
    22:38:35  ERROR Couldn't start ... Caused by: HttpException: 410
    22:38:59  Precondition not met: kellytesh's room is <offline>

The edge withdraws the LL-HLS playlist the instant a broadcast ends, so a start attempt that
races the end of a stream gets 410 and there is nothing the client could have done. That single
ERROR is CORRECT behaviour and its log line must NOT be demoted -- it is the only way a genuine
410 storm would ever surface.

But "one 410 is fine" cannot be the whole rule, or a site-side outage that 410s every attempt
forever would also read as fine. The boundary needs stating, and the temptation is to invent a
number. This file states it as a RELATION instead: what makes a 410 excusable is that the room is
independently reported OFFLINE. A 410 while the room still reports ONLINE is unexplained, and
enough consecutive unexplained ones is a fault.

WHAT IS PROVED, AND WHAT IS NOT
-------------------------------
Proved: the verdict function's branch structure, that an offline-explained 410 can never reach
`fault` at any positive threshold, that the threshold is monotone, that `fault` always has
evidence behind it, and that the measured kellytesh sequence is `transient`.

NOT proved: that 410 means what Chaturbate's edge intends by it, or that a fault verdict implies
any particular remedy. Those are remote-side facts, not observable from here.
-/

namespace CtbrecSpec.StartupVerdict

/-- One start attempt: did it fail with 410, and did the site independently say the room was up? -/
structure Attempt where
  got410     : Bool
  roomOnline : Bool
deriving Repr, DecidableEq

inductive Verdict
  | healthy
  | transient
  | fault
deriving Repr, DecidableEq

/--
A 410 is SUSPICIOUS only when the room was still reported online. That is the relation the whole
spec turns on: an offline room explains a 410 completely, so it is never evidence of a fault.
-/
def suspicious (a : Attempt) : Bool := a.got410 && a.roomOnline

/-- Longest run of consecutive suspicious attempts, carried as (current run, best so far). -/
def runs : List Attempt → Nat × Nat
  | [] => (0, 0)
  | a :: rest =>
      let (cur, best) := runs rest
      if suspicious a then
        let cur' := cur + 1
        (cur', max cur' best)
      else
        (0, best)

def longestSuspiciousRun (as : List Attempt) : Nat := (runs as).2

/--
The verdict. `fault` needs `threshold` consecutive UNEXPLAINED failures; any 410 at all is at
least `transient`; only a clean sequence is `healthy`.
-/
def verdict (threshold : Nat) (as : List Attempt) : Verdict :=
  if threshold ≤ longestSuspiciousRun as then Verdict.fault
  else if as.any (·.got410) then Verdict.transient
  else Verdict.healthy

/-- Three consecutive unexplained 410s. Chosen as the smallest run that cannot be a single race. -/
def faultAfter3 : Nat := 3

/-! ## The measured sequence -/

/-- kellytesh: one 410, and the room was independently reported offline moments later. -/
def kellytesh : List Attempt :=
  [ { got410 := false, roomOnline := true  }   -- 22:37:58 recording ran, then the stream ended
  , { got410 := true,  roomOnline := false }   -- 22:38:35 the 410, room offline at 22:38:59
  , { got410 := false, roomOnline := false }   -- 22:49:05 precondition not met, no attempt
  ]

#guard verdict faultAfter3 kellytesh == Verdict.transient
#guard longestSuspiciousRun kellytesh == 0

/-- A site-side outage: three unexplained 410s in a row while the room stays online. -/
def outage : List Attempt :=
  List.replicate 3 { got410 := true, roomOnline := true }

#guard verdict faultAfter3 outage == Verdict.fault
#guard longestSuspiciousRun outage == 3

-- Two unexplained failures are not yet a fault -- the boundary is where it is claimed to be.
#guard verdict faultAfter3 (List.replicate 2 { got410 := true, roomOnline := true })
         == Verdict.transient

-- A quiet run with no 410 at all.
#guard verdict faultAfter3 [{ got410 := false, roomOnline := true }] == Verdict.healthy
#guard verdict faultAfter3 [] == Verdict.healthy

-- Interleaving breaks the run: three 410s that are not CONSECUTIVE are not a fault.
#guard verdict faultAfter3
         [ { got410 := true,  roomOnline := true }
         , { got410 := false, roomOnline := true }
         , { got410 := true,  roomOnline := true }
         , { got410 := false, roomOnline := true }
         , { got410 := true,  roomOnline := true } ] == Verdict.transient

-- Many offline-explained 410s never become a fault, however many there are.
#guard verdict faultAfter3 (List.replicate 50 { got410 := true, roomOnline := false })
         == Verdict.transient

/-! ## The invariants -/

/-- An attempt whose room was offline is never suspicious, whatever else is true of it. -/
theorem an_offline_room_explains_every_410 (a : Attempt) (h : a.roomOnline = false) :
    suspicious a = false := by
  simp [suspicious, h]

/--
**The durable invariant.** If no attempt in the sequence is suspicious, the run is 0 -- so with
any positive threshold the verdict can never be `fault`. Stated over an arbitrary list and an
arbitrary positive threshold, not over the corpus.
-/
theorem a_sequence_of_explained_failures_is_never_a_fault
    (threshold : Nat) (as : List Attempt)
    (hpos : 0 < threshold) (hexp : ∀ a ∈ as, a.roomOnline = false) :
    verdict threshold as ≠ Verdict.fault := by
  have hrun : longestSuspiciousRun as = 0 := by
    unfold longestSuspiciousRun
    induction as with
    | nil => simp [runs]
    | cons a rest ih =>
      have ha : suspicious a = false :=
        an_offline_room_explains_every_410 a (hexp a (List.mem_cons_self))
      have hrest : ∀ b ∈ rest, b.roomOnline = false :=
        fun b hb => hexp b (List.mem_cons_of_mem a hb)
      simp [runs, ha, ih hrest]
  unfold verdict
  rw [hrun]
  simp only [Nat.le_zero_eq]
  intro hc
  split at hc
  · omega
  · split at hc <;> simp_all

/-- **Fault always has evidence**: it is reported only when the run really reaches the threshold. -/
theorem fault_requires_the_full_run (threshold : Nat) (as : List Attempt)
    (h : verdict threshold as = Verdict.fault) :
    threshold ≤ longestSuspiciousRun as := by
  unfold verdict at h
  by_cases hb : threshold ≤ longestSuspiciousRun as
  · exact hb
  · rw [if_neg hb] at h
    split at h <;> simp at h

/-- **Healthy means no 410 at all** -- it is never awarded to a sequence that had a failure. -/
theorem healthy_means_nothing_failed (threshold : Nat) (as : List Attempt)
    (h : verdict threshold as = Verdict.healthy) :
    as.any (·.got410) = false := by
  unfold verdict at h
  split at h
  · simp at h
  · by_cases hany : as.any (·.got410)
    · rw [if_pos hany] at h; simp at h
    · simpa using hany

/-- **Monotone in the threshold**: demanding more evidence can only make `fault` rarer. -/
theorem raising_the_threshold_cannot_create_a_fault
    (t u : Nat) (as : List Attempt) (h : t ≤ u)
    (hu : verdict u as = Verdict.fault) :
    verdict t as = Verdict.fault := by
  have := fault_requires_the_full_run u as hu
  unfold verdict
  rw [if_pos (Nat.le_trans h this)]

/--
**Anti-disarm.** At threshold 0 every sequence is a fault, so the check cannot be quietly turned
off by pushing the threshold down -- the disabling value is loud, not silent.
-/
theorem the_threshold_cannot_be_silently_disabled (as : List Attempt) :
    verdict 0 as = Verdict.fault := by
  unfold verdict
  simp

/-- The run never exceeds the number of attempts: the metric cannot invent evidence. -/
theorem the_run_is_bounded_by_the_attempts : ∀ as : List Attempt,
    (runs as).1 ≤ as.length ∧ (runs as).2 ≤ as.length
  | [] => by simp [runs]
  | a :: rest => by
      have ih := the_run_is_bounded_by_the_attempts rest
      simp only [runs, List.length_cons]
      split <;> simp_all <;> omega

end CtbrecSpec.StartupVerdict
