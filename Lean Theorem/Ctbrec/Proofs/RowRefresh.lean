/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the row refresh: a second write path that bypassed the mirroring setters

Subject: `src/app/ctbrec/ui/JavaFxModel.java`, `updateFrom(JavaFxModel other)`.

**This checkpoint exists because the previous one was incomplete.** Checkpoint 64 repaired
`setOnlineStateProperty` so that it writes the delegate as well as the JavaFX property. It did not
repair `updateFrom`, which writes the same property **directly** and therefore walks straight past
that repair. A fix applied to one write path is not a fix; the property is what the other paths must
not be able to reach behind.

`updateFrom` is the refresh path for a row that already exists. `RecordedModelsTab.java:285-296`
(and `RecordLaterTab.java:92-102`) keep the displayed object — so table bindings and listeners
survive — and pour the freshly polled model into it:

```java
JavaFxModel oldModel = (JavaFxModel) this.observableModels.get(index);
oldModel.updateFrom(updatedModel);
```

The class offers four setters that mirror **both** views of a field:

```java
public void setPriority(int p)          { this.delegate.setPriority(p);     this.priorityProperty.set(p); }
public void setForcePriority(boolean f) { this.delegate.setForcePriority(f); this.forcePriorityProperty.set(f); }
public void setLastSeen(Instant t)      { this.delegate.setLastSeen(t);     this.lastSeenProperty.set(t); }
public void setLastRecorded(Instant t)  { this.delegate.setLastRecorded(t); this.lastRecordedProperty.set(t); }
```

`updateFrom` used two of them and bypassed the rest:

```java
this.lastRecordedProperty().set((Instant) other.lastRecordedProperty().get());   // property ONLY
this.lastSeenProperty().set((Instant) other.lastSeenProperty().get());           // property ONLY
this.onlineStateProperty().set((State) other.onlineStateProperty().get());       // property ONLY
```

## Finding 1 — after a refresh the delegate is stale for three fields

Every reader that goes through the delegate — `getLastSeen()`, `getLastRecorded()`,
`getOnlineState()` at `ThumbOverviewTab.java:919`, `ThumbCell.java:390,401`,
`ModelPropertiesDialog.java:468` — kept seeing the values from before the poll, indefinitely,
because the next refresh writes the property again and never the delegate.

## Finding 2 — priority was not refreshed at all

`priorityProperty` is bound to an **editable** column (`RecordedModelsTab.java:113-124`) and
`setPriority` mirrors correctly, but `updateFrom` copied neither half. A priority set anywhere other
than that row's own cell editor never reached the row.

The obvious defence of the omission — "it would clobber an edit in progress" — does not hold, and
this was checked rather than assumed: `onUpdateSuccess` is guarded by `if (!this.cellEditing)`
(`RecordedModelsTab.java:265`), so the **entire** refresh is skipped while a cell is being edited.
`updateFrom` cannot run during an edit. The omission was a gap, not a guard.

## The shape of the statement

The durable claim is not "these three fields are copied" — a future field added to `updateFrom`
would slip through that. It is: **after a refresh the row equals the model it was refreshed from**,
on every field the refresh covers, in both views. `Row` below is exactly the set of fields
`updateFrom` copies, so `after_a_repaired_refresh_the_row_equals_the_source` says precisely that,
and the anti-amputation theorem forbids satisfying it by leaving the row alone.
-/

import Proofs.Ctbrec.ModelViews

namespace CtbrecSpec

/-- Both views of one field agreeing — what checkpoint 64's repair guarantees for a model that has
only ever been written through the mirroring setters. -/
def mirror {α : Type} (x : α) : Views α := { model := x, view := x }

/-- A field is coherent when its two views agree. -/
def fieldCoherent {α : Type} [DecidableEq α] (v : Views α) : Bool := v.model == v.view

/-- The fields `updateFrom` copies, each carrying its delegate half and its property half. Modelled
at `Nat` because the defect is about *which half is written*, never about the values. -/
structure Row where
  priority : Views Nat
  lastSeen : Views Nat
  onlineState : Views Nat
  deriving DecidableEq, Repr

/-- `updateFrom` as shipped: priority untouched; the other two written through the property only, so
`dst`'s delegate halves survive the refresh. -/
def shippedUpdateFrom (src dst : Row) : Row :=
  { priority := dst.priority,
    lastSeen := { dst.lastSeen with view := src.lastSeen.view },
    onlineState := { dst.onlineState with view := src.onlineState.view } }

/-- The repair: route every field through a mirroring setter. -/
def repairedUpdateFrom (src _dst : Row) : Row :=
  { priority := mirror src.priority.model,
    lastSeen := mirror src.lastSeen.model,
    onlineState := mirror src.onlineState.view }

/-- Rebuilding a coherent field from its DELEGATE half returns the field unchanged. Extracted as a
named lemma because the inline proof needed structure eta and would not close: the goal
`{ model := v.model, view := v.model } = v` is not `rfl` until `v` is destructured. -/
theorem mirror_of_coherent {α : Type} (v : Views α) (h : v.model = v.view) : mirror v.model = v := by
  cases v with
  | mk m w => cases h; rfl

/-- ...and rebuilding it from its PROPERTY half does the same. `updateFrom` reads the online state
from the property (it is the value the poll delivered) and the other fields from the delegate, so
both directions are needed. -/
theorem mirror_of_coherent_view {α : Type} (v : Views α) (h : v.model = v.view) :
    mirror v.view = v := by
  cases v with
  | mk m w => cases h; rfl

/-! ### Finding 2 — the field that was not copied -/

/-- **The shipped refresh never updates priority**, whatever the source holds. -/
theorem the_shipped_refresh_never_updates_priority (src dst : Row) :
    (shippedUpdateFrom src dst).priority = dst.priority := rfl

/-- ...so a row whose priority differs from the polled model keeps the wrong one after a refresh. -/
theorem a_changed_priority_never_reaches_the_row (src dst : Row)
    (h : src.priority ≠ dst.priority) :
    (shippedUpdateFrom src dst).priority ≠ src.priority := by
  simp only [shippedUpdateFrom]
  exact fun hc => h hc.symm

/-- The repair carries it across. -/
theorem the_repaired_refresh_updates_priority (src dst : Row) :
    (repairedUpdateFrom src dst).priority = mirror src.priority.model := rfl

/-! ### Finding 1 — the delegate half the refresh never wrote -/

/-- **The shipped refresh leaves the delegate stale**, for every source and every field it wrote
through the property. -/
theorem the_shipped_refresh_leaves_last_seen_stale (src dst : Row) :
    (shippedUpdateFrom src dst).lastSeen.model = dst.lastSeen.model := rfl

theorem the_shipped_refresh_leaves_the_online_state_stale (src dst : Row) :
    (shippedUpdateFrom src dst).onlineState.model = dst.onlineState.model := rfl

/-- **So the refresh itself manufactured the very divergence checkpoint 64 repaired.** Writing the
property alone leaves the two views of the refreshed row disagreeing whenever the new value differs
from the old — which is exactly when a refresh matters. -/
theorem the_shipped_refresh_recreates_the_divergence (src dst : Row)
    (h : src.onlineState.view ≠ dst.onlineState.model) :
    (shippedUpdateFrom src dst).onlineState.model ≠ (shippedUpdateFrom src dst).onlineState.view := by
  simp only [shippedUpdateFrom]
  exact fun hc => h hc.symm

/-- Every field of a repaired refresh is coherent — no half can be left behind. -/
theorem every_field_of_a_repaired_refresh_is_coherent (src dst : Row) :
    fieldCoherent (repairedUpdateFrom src dst).priority = true ∧
    fieldCoherent (repairedUpdateFrom src dst).lastSeen = true ∧
    fieldCoherent (repairedUpdateFrom src dst).onlineState = true := by
  refine ⟨?_, ?_, ?_⟩ <;> simp [fieldCoherent, repairedUpdateFrom, mirror]

/-! ### The durable statement -/

/-- A row is coherent when every field is. -/
def rowCoherent (r : Row) : Bool :=
  fieldCoherent r.priority && fieldCoherent r.lastSeen && fieldCoherent r.onlineState

/-- **After a repaired refresh the row EQUALS the model it was refreshed from** — every field, both
views. Stated over the whole `Row` rather than field by field, so a field added to the refresh later
is covered by the same theorem instead of slipping past a list.

The hypothesis is that the *source* is coherent, which is precisely what checkpoint 64's repair to
`setOnlineStateProperty` guarantees: a freshly polled model has only ever been written through the
mirroring setters. The two repairs are load-bearing for each other. -/
theorem after_a_repaired_refresh_the_row_equals_the_source (src dst : Row)
    (h : rowCoherent src = true) : repairedUpdateFrom src dst = src := by
  simp only [rowCoherent, fieldCoherent, Bool.and_eq_true, beq_iff_eq] at h
  obtain ⟨⟨hp, hl⟩, ho⟩ := h
  simp only [repairedUpdateFrom]
  rw [mirror_of_coherent src.priority hp, mirror_of_coherent src.lastSeen hl,
      mirror_of_coherent_view src.onlineState ho]

/-- **Anti-amputation.** "The row agrees with itself afterwards" is also achieved by never copying
anything. The repair must actually move the source's values in, so a refresh that changes every
field must change the row. -/
theorem the_repair_actually_refreshes (src dst : Row) (h : rowCoherent src = true)
    (hne : src ≠ dst) : repairedUpdateFrom src dst ≠ dst := by
  rw [after_a_repaired_refresh_the_row_equals_the_source src dst h]
  exact hne

/-- ...and the shipped refresh did NOT reach the source, which is the defect in one line. -/
theorem the_shipped_refresh_does_not_reach_the_source (src dst : Row)
    (h : src.priority ≠ dst.priority) : shippedUpdateFrom src dst ≠ src := by
  intro hc
  apply h
  have : (shippedUpdateFrom src dst).priority = src.priority := by rw [hc]
  rw [the_shipped_refresh_never_updates_priority] at this
  exact this.symm

/-- Refreshing from a row that is already identical changes nothing — the refresh is idempotent, so
a poll loop cannot make a stable row flicker. -/
theorem refreshing_from_an_identical_row_is_a_no_op (r : Row) (h : rowCoherent r = true) :
    repairedUpdateFrom r r = r :=
  after_a_repaired_refresh_the_row_equals_the_source r r h

#guard (shippedUpdateFrom { priority := mirror 5, lastSeen := mirror 5, onlineState := mirror 5 }
                          { priority := mirror 1, lastSeen := mirror 1, onlineState := mirror 1 }).priority
        == mirror 1
#guard (shippedUpdateFrom { priority := mirror 5, lastSeen := mirror 5, onlineState := mirror 5 }
                          { priority := mirror 1, lastSeen := mirror 1, onlineState := mirror 1 }).lastSeen
        == { model := 1, view := 5 }
#guard (repairedUpdateFrom { priority := mirror 5, lastSeen := mirror 5, onlineState := mirror 5 }
                           { priority := mirror 1, lastSeen := mirror 1, onlineState := mirror 1 })
        == { priority := mirror 5, lastSeen := mirror 5, onlineState := mirror 5 }
#guard fieldCoherent (mirror (7 : Nat)) == true
#guard fieldCoherent ({ model := 1, view := 2 } : Views Nat) == false
#guard rowCoherent { priority := mirror 5, lastSeen := mirror 5, onlineState := mirror 5 } == true
#guard rowCoherent { priority := { model := 1, view := 2 }, lastSeen := mirror 5,
                     onlineState := mirror 5 } == false

end CtbrecSpec
