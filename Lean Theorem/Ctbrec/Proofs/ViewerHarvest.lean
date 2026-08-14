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
# HARVESTING THE VIEWER COUNT FROM A RESPONSE WE ALREADY FETCH

Reported 2026-08-10: the thumbnail viewer count never appears on Chaturbate. Measured cause, and it
is not a wiring fault:

```
deployed ChaturbateModel.getViewerCount   = 0     the method DOES NOT EXIST
ChaturbateModel.java  grep -ci viewer     = 0     across 859 lines
Chaturbate.java:186-195  online.getString(i)      the room list returns BARE NAMES
```

`ModelViewerCount` and `ThumbCell` are both correct and correctly deployed. They read a source that
was never built, so `render` returns empty and the label hides itself — exactly as designed.

**The opportunity**: `ChaturbateModel.requestStreamInfo()` (`:497-518`) ALREADY fetches
`/api/livecampreviewcontext/<name>/` and parses `room_status` and `hls_source` out of `content`.
Harvesting the count from that same body costs **no additional request**. `ViewerCountProbe.KEYS`
already lists `spectators` alongside `num_users`, `viewer_count`, `viewers`, `watchers` — the Socio's
"Spectator" vocabulary is covered.

This module fixes the properties the Java change must satisfy, BEFORE the Java is written.
-/

namespace CtbrecSpec.ViewerHarvest

/-- A stream-info payload as returned by `/api/livecampreviewcontext/`. `carriesCount` is true when
any of `ViewerCountProbe.KEYS` is present with a numeric value. -/
structure Payload where
  carriesCount : Bool
  count : Nat
deriving DecidableEq, Repr

/-- What the model knows after a stream-info request. `none` means UNKNOWN, and unknown is a
different fact from a measured zero — conflating them is the defect this type exists to prevent. -/
abbrev Known := Option Nat

/-- The harvest: read the count out of the payload we already have in hand. -/
def harvest (p : Payload) : Known := if p.carriesCount then some p.count else none

/-- The old behaviour: no getter at all, so nothing is ever known whatever the payload said. -/
def harvestBefore (_ : Payload) : Known := none

/-- The label renders exactly when the count is known. Mirrors `ThumbCell.updateViewerCount()`:
`boolean known = !text.isEmpty(); label.setVisible(known)`. -/
def renders (k : Known) : Bool := k.isSome

/-! ## What was broken -/

/-- **The reported defect**: with no getter, a payload that DOES carry a count still renders nothing. -/
theorem before_never_renders (p : Payload) : renders (harvestBefore p) = false := by
  rfl

/-- And that holds even when the count is present and large — the payload was never consulted. -/
theorem before_ignores_a_real_count :
    renders (harvestBefore { carriesCount := true, count := 4213 }) = false := by
  decide

/-! ## What the repair must guarantee -/

/-- **The core property**: a payload carrying a count MUST render. This is the theorem the Java
change has to satisfy; `exists_reachable`-style, it is quantified over every count. -/
theorem payload_with_count_renders (n : Nat) :
    renders (harvest { carriesCount := true, count := n }) = true := by
  rfl

/-- The harvested value is the payload's value — no truncation, no substitution. -/
theorem harvest_is_faithful (n : Nat) :
    harvest { carriesCount := true, count := n } = some n := by
  rfl

/-- **Unknown is NOT zero.** A payload without a count key yields `none`, never `some 0`. Rendering
"0" for an absent count would assert a measurement nobody made. -/
theorem absent_is_unknown_not_zero :
    harvest { carriesCount := false, count := 0 } = none
    ∧ harvest { carriesCount := false, count := 0 } ≠ some 0 := by
  exact ⟨rfl, by decide⟩

/-- A genuine zero stays distinguishable from unknown: a room with 0 viewers that REPORTS 0 renders. -/
theorem measured_zero_still_renders :
    harvest { carriesCount := true, count := 0 } = some 0
    ∧ renders (harvest { carriesCount := true, count := 0 }) = true := by
  exact ⟨rfl, rfl⟩

/-- **The repair strictly dominates the old behaviour**: everything that rendered before still
renders, and something new does. It cannot regress the UI. -/
theorem repair_never_regresses (p : Payload) :
    renders (harvestBefore p) = true → renders (harvest p) = true := by
  intro h
  exact absurd h (by simp [renders, harvestBefore])

/-- Strictly better, witnessed: a payload that the old path missed and the new path renders. -/
theorem repair_is_strictly_better :
    ∃ p : Payload, renders (harvestBefore p) = false ∧ renders (harvest p) = true := by
  exact ⟨{ carriesCount := true, count := 7 }, rfl, rfl⟩

/-- Rendering happens **iff** the payload carried a count — no other condition may gate it. This is
what stops a future edit from hiding the label for an unrelated reason. -/
theorem renders_iff_payload_carries (p : Payload) :
    renders (harvest p) = p.carriesCount := by
  cases hc : p.carriesCount <;> simp [renders, harvest, hc]

/-! ## Executable checks -/

#guard renders (harvestBefore { carriesCount := true, count := 4213 }) == false
#guard renders (harvest { carriesCount := true, count := 4213 }) == true
#guard harvest { carriesCount := true, count := 4213 } == some 4213
#guard harvest { carriesCount := false, count := 0 } == none
#guard harvest { carriesCount := true, count := 0 } == some 0
#guard renders (harvest { carriesCount := true, count := 0 }) == true
#guard renders (harvest { carriesCount := false, count := 99 }) == false

end CtbrecSpec.ViewerHarvest
