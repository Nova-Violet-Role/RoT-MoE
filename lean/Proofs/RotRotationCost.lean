/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # Rotating on every append is what made the router miss its own latency bound

**Measured 2026-08-10.** `checker/bench-router.sh` failed the 500 ms bound at
527–649 ms across three runs. Isolating by sink configuration:

| configuration | ms per invocation |
|---|---|
| central log **at the cap** (5000 lines, 3 365 310 bytes) + project sink | **789.1** |
| no central log, project sink only | 333.2 |
| no sinks at all | 304.3 |

So rotation alone costs **~456 ms per call**, and bash process start is only
23.2 ms — the cost is ours.

**The mechanism is structural, not accidental.** `rot-router.sh` rotates when
`_n -gt _cap`. Once the log has reached the cap, appending makes it `cap + 1`,
which is `> cap`, so it rotates back to `cap`. The next append makes it `cap + 1`
again. **At steady state every single invocation runs `wc -l` over the whole file
and then rewrites it with `tail -n cap`.** With 62 hook commands registered per
turn, that is ~62 full rewrites of a multi-megabyte file per turn.

`RotDebugLog` already proved the *retention policy* correct — the newest records
survive (`rotate_keeps_the_newest`) and the file stays bounded
(`rotate_length_le`). Both remain true. Neither says anything about **how often**
the trimming runs, and that is the whole defect: a correct policy applied on
every append.

The repair is hysteresis. Rotate only when the length exceeds `cap + slack`, and
trim back to `cap`. The bound becomes `cap + slack` instead of `cap` — slightly
weaker, and that weakening is stated here rather than hidden — while rotations
drop from *every* append to one per `slack + 1` appends.

## Part 3 covers the second defect found in the same measurement

The project sink is **never rotated at all**. Measured in this repository:
`.rot-moe/rot-route-cc60cda6….jsonl` at **7133 lines / 4 636 705 bytes**, above a
cap that is only applied to the central sink, plus ~12 MB across 30+ per-session
files that are never reclaimed. The unbounded-growth defect `RotDebugLog` was
written to prevent — the 1.4 GB and 1.1 GB logs found in `~/.claude` — is live in
the second sink.
-/

namespace RotRotationCost

/-! ## Part 1 — how often the trimming runs -/

/-- Rotate when the length exceeds `cap + slack`. The shipped router is the
`slack = 0` case. -/
def willRotate (cap slack len : Nat) : Bool := decide (cap + slack < len)

/-- The slack the router ships with today. -/
def shippedSlack : Nat := 0

/-- The length after one append, given the policy trims back to `cap`. -/
def afterAppend (cap slack len : Nat) : Nat :=
  if cap + slack < len + 1 then cap else len + 1

/-- Rotations performed over `k` appends starting from a log of length `len`. -/
def rotations (cap slack : Nat) : Nat → Nat → Nat
  | 0, _ => 0
  | k + 1, len =>
      (if cap + slack < len + 1 then 1 else 0) + rotations cap slack k (afterAppend cap slack len)

/-! ### The defect -/

/-- **At the cap, the shipped policy rotates on every append.** -/
theorem shipped_rotates_at_steady_state (cap : Nat) :
    willRotate cap shippedSlack (cap + 1) = true := by
  simp [willRotate, shippedSlack]

/-- **And it never leaves that state**: trimming returns the log to exactly the
cap, which is the length that rotates again on the next append. -/
theorem shipped_returns_to_the_rotating_length (cap : Nat) :
    afterAppend cap shippedSlack cap = cap := by
  simp [afterAppend, shippedSlack]

/-- **The cost, in general form**: starting at the cap, `k` appends perform `k`
rotations. Every one of them reads and rewrites the entire file. -/
theorem shipped_rotates_once_per_append (cap k : Nat) :
    rotations cap 0 k cap = k := by
  induction k with
  | zero => rfl
  | succ n ih =>
      rw [rotations]
      have h1 : cap + 0 < cap + 1 := by omega
      have h2 : afterAppend cap 0 cap = cap := by simp [afterAppend]
      rw [if_pos h1, h2, ih]
      omega

/-! ### The repair -/

/-- **With slack, the steady state does not rotate.** -/
theorem slack_skips_the_steady_state_rotation (cap slack : Nat) (h : 0 < slack) :
    willRotate cap slack (cap + 1) = false := by
  simp [willRotate]
  omega

/-- The bound is still respected: a log never exceeds `cap + slack`. This is the
weakening, stated explicitly — the file may hold up to `slack` extra records
between trims, and in exchange the trim runs `slack + 1` times less often. -/
theorem length_stays_bounded (cap slack len : Nat) (h : len ≤ cap + slack) :
    afterAppend cap slack len ≤ cap + slack := by
  simp only [afterAppend]
  split
  · omega
  · omega

/-- The repair is not vacuous — it still rotates once the slack is used up. -/
theorem slack_still_rotates (cap slack : Nat) :
    willRotate cap slack (cap + slack + 1) = true := by
  simp [willRotate]

/-- **No rotation happens while the slack lasts**, for every cap, slack and
starting length. This is the general statement of the repair: the trim is
skipped until the log has actually grown past `cap + slack`.

It is proved rather than evaluated on purpose — `decide` at the shipped cap of
5000 exceeds the recursion depth, and a claim that cannot be checked at the size
it is made about is not a claim. -/
theorem no_rotation_below_the_slack (cap slack : Nat) :
    ∀ k len, len + k ≤ cap + slack → rotations cap slack k len = 0 := by
  intro k
  induction k with
  | zero => intro len _; rfl
  | succ n ih =>
      intro len h
      rw [rotations]
      have h1 : ¬ (cap + slack < len + 1) := by omega
      have h2 : afterAppend cap slack len = len + 1 := by simp [afterAppend, h1]
      rw [if_neg h1, h2]
      simpa using ih (len + 1) (by omega)

/-! ### The measured configuration -/

/-- The cap the router ships with. -/
def shippedCap : Nat := 5000

/-- The proposed slack: a quarter of the cap. -/
def proposedSlack : Nat := 1250

/-- **The shipped policy, at the shipped cap**: 5000 appends, 5000 full-file
rewrites. -/
theorem the_shipped_cost_at_the_shipped_cap :
    rotations shippedCap shippedSlack 5000 shippedCap = 5000 :=
  shipped_rotates_once_per_append shippedCap 5000

/-- **The repair, at the same cap**: the first 1250 appends perform NO rewrite at
all. Where the shipped router does 1250 full rewrites, this does zero. -/
theorem the_repair_at_the_shipped_cap :
    rotations shippedCap proposedSlack 1250 shippedCap = 0 :=
  no_rotation_below_the_slack shippedCap proposedSlack 1250 shippedCap (by decide)

/-- Stated side by side, over the same 1250 appends. -/
theorem the_two_policies_over_the_same_run :
    rotations shippedCap shippedSlack 1250 shippedCap = 1250 ∧
      rotations shippedCap proposedSlack 1250 shippedCap = 0 :=
  ⟨shipped_rotates_once_per_append shippedCap 1250, the_repair_at_the_shipped_cap⟩

-- Guards use a small cap so they EVALUATE. At the shipped cap of 5000 the
-- recursion depth defeats the evaluator, which is why the claims above are
-- theorems. The shape is identical: slack 0 rotates on every append; slack 5
-- rotates once per six.
#guard rotations 20 0 6 20 = 6
#guard rotations 20 5 5 20 = 0
#guard rotations 20 5 6 20 = 1
#guard willRotate shippedCap shippedSlack (shippedCap + 1) = true
#guard willRotate shippedCap proposedSlack (shippedCap + 1) = false
#guard willRotate shippedCap proposedSlack (shippedCap + proposedSlack + 1) = true

/-! ## Part 2 — the retention policy is untouched

The point of the repair is that it changes *when* trimming happens and nothing
else. `trim` below is the same drop-from-the-front operation `RotDebugLog`
already proved correct; these theorems confirm that adding slack does not
disturb it. -/

/-- Keep the last `cap` records, discarding from the front. -/
def trim (cap : Nat) (xs : List Nat) : List Nat := xs.drop (xs.length - cap)

/-- Trimming keeps a suffix — the NEWEST records — for any cap and any log. -/
theorem trim_keeps_the_newest (cap : Nat) (xs : List Nat) :
    (trim cap xs).IsSuffix xs :=
  List.drop_suffix _ _

/-- Trimming never lengthens a log. -/
theorem trim_length_le (cap : Nat) (xs : List Nat) :
    (trim cap xs).length ≤ xs.length := by
  simp [trim]

/-- Below the cap, trimming is the identity: no record is lost early. -/
theorem trim_below_cap_is_identity (cap : Nat) (xs : List Nat) (h : xs.length ≤ cap) :
    trim cap xs = xs := by
  simp [trim, Nat.sub_eq_zero_of_le h]

/-- Negative control: keeping the FRONT instead would discard the newest record,
which is what `RotDebugLog.taking_the_front_loses_the_newest` refutes. Restated
here so this module's `trim` cannot silently become the wrong one. -/
theorem taking_the_front_is_not_trim :
    List.take 2 [1, 2, 3] ≠ trim 2 [1, 2, 3] := by decide

#guard trim 2 [1, 2, 3] = [2, 3]
#guard trim 5 [1, 2, 3] = [1, 2, 3]
#guard List.take 2 [1, 2, 3] = [1, 2]

/-! ## Part 3 — a sink with no rotation at all

The router writes two sinks. The cap is applied to one of them. -/

/-- A sink: how many records it holds, and whether any rotation applies to it. -/
structure Sink where
  /-- Records currently held. -/
  records : Nat
  /-- Whether a rotation policy governs this sink. -/
  rotated : Bool
  deriving DecidableEq, Repr

/-- The central sink, measured at its cap. -/
def centralSink : Sink := ⟨5000, true⟩

/-- The project sink, measured in this repository at 7133 records. -/
def projectSink : Sink := ⟨7133, false⟩

/-- A sink is bounded by `cap` only if something actually trims it. -/
def isBounded (cap : Nat) (s : Sink) : Bool := s.rotated && s.records ≤ cap

/-- **The defect**: the project sink is over the cap, because no policy applies
to it. -/
theorem the_project_sink_is_unbounded :
    isBounded shippedCap projectSink = false ∧ shippedCap < projectSink.records := by
  constructor
  · decide
  · decide

/-- The central sink is bounded, so the predicate is not constantly false and the
two sinks are genuinely distinguished. -/
theorem the_central_sink_is_bounded : isBounded shippedCap centralSink = true := by
  decide

/-- **Rotation is what makes the bound hold.** For any sink at or below the cap,
being governed by a policy is exactly what `isBounded` adds — so an unrotated
sink can never be certified, whatever its current size. -/
theorem an_unrotated_sink_is_never_bounded (cap : Nat) (n : Nat) :
    isBounded cap ⟨n, false⟩ = false := by
  simp [isBounded]

#guard isBounded shippedCap projectSink = false
#guard isBounded shippedCap centralSink = true
#guard isBounded shippedCap ⟨0, false⟩ = false

end RotRotationCost
