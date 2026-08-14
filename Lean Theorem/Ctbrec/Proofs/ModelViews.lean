/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the model's online state: two views, one fact

Subject: `src/app/ctbrec/ui/JavaFxModel.java`, the last row of the unreferenced-code ledger.

`JavaFxModel` wraps a `Model` delegate and mirrors parts of it into JavaFX properties. For two
fields it mirrors **both** ways, and the class states the correct pattern itself:

```java
public void setSuspended(boolean suspended) {
   this.delegate.setSuspended(suspended);     // the model
   this.pausedProperty.set(suspended);        // the view
}
public void setForcePriority(boolean forcePriority) {
   this.delegate.setForcePriority(forcePriority);
   this.forcePriorityProperty.set(forcePriority);
}
```

For online state it does not:

```java
public void setOnlineStateProperty(State state) throws IOException, ExecutionException {
   this.onlineStateProperty.set(state);       // the view ONLY
}
public State getOnlineState(boolean failFast) throws IOException, ExecutionException {
   return this.delegate.getOnlineState(failFast);   // the model ONLY
}
```

## Finding 1 — the view and the model disagree, and different call sites read different ones

`RecordedModelsTab.java:355` polls a freshly fetched model and writes the result into the **property**:

```java
fxm.setOnlineStateProperty(onlineModel.getOnlineState(true));
```

After that write the two views answer the same question differently, and the readers are split:

| reader | reads | sees |
|---|---|---|
| `RecordedModelsTab.java:145` (the Online State column) | the property | the NEW state |
| `ThumbOverviewTab.java:919` (`getOnlineState(true) != ONLINE`) | the delegate | the OLD state |
| `ThumbCell.java:390,401` | the delegate | the OLD state |
| `ModelPropertiesDialog.java:468` | the delegate | the OLD state |

So the table can show a model online while the guard that decides whether to start recording still
sees the previous state. Same shape as `BandwidthMeter.setThroughput` (checkpoint 39) and
`SimpleJoinedStringListProperty` (checkpoint 59): two answers to one question.

`updateFrom` copies property-to-property, never re-reading the delegate, so a divergence persists.

## Finding 2 — a `throws` clause that cannot fire, and the empty catch it caused

`setOnlineStateProperty`'s body is a single `SimpleObjectProperty.set` — it cannot throw
`IOException` or `ExecutionException`. The clause is dead. But it is *declared*, so every caller
must handle it, and the one caller wrote:

```java
try {
   fxm.setOnlineStateProperty(onlineModel.getOnlineState(true));
} catch (Exception var8) {
}
```

An **empty** catch. A failure to refresh a model's online state produces no log line, no counter,
nothing — the row silently keeps a stale value forever. `a_swallowed_failure_leaves_no_record` is
that statement; the goal for this rework names `*.log` explicitly, and this is a hole in it.
-/

namespace CtbrecSpec

/-- The online state, abstract: any value the two views can hold. Left as a type variable so the
theorems are about the mirroring discipline, not about today's seven enum constants. -/
structure Views (α : Type) where
  /-- What `getOnlineState` returns — the delegate. -/
  model : α
  /-- What the table column binds to — the JavaFX property. -/
  view : α
  deriving DecidableEq, Repr

/-- `setOnlineStateProperty` as shipped: writes the view, leaves the model untouched. -/
def shippedSetOnline {α : Type} (s : α) (v : Views α) : Views α := { v with view := s }

/-- What the repair writes to the delegate half. Split out so that "the delegate write vanished"
and "the view write vanished" are two SEPARATE lines a mutation can target — the harness matches
whole lines, so two mutants of one line cannot both be expressed, and the second would be silently
DISCARDED rather than run. These two also map one-to-one onto phase 61's controls A and B. -/
def writeModel {α : Type} (s : α) (_v : Views α) : α := s

/-- What the repair writes to the JavaFX property half. -/
def writeView {α : Type} (s : α) (_v : Views α) : α := s

/-- The repair: write both, matching what `setSuspended` already does in the same class. -/
def repairedSetOnline {α : Type} (s : α) (v : Views α) : Views α :=
  { model := writeModel s v, view := writeView s v }

/-- `setSuspended` — the pattern the class already gets right, kept here so the repair can be
proved to MATCH an existing convention rather than invent one. -/
def mirroredSet {α : Type} (s : α) (_v : Views α) : Views α := { model := s, view := s }

/-! ### Finding 1 — divergence -/

/-- **The shipped update leaves the model stale.** For every state and every pair of views, writing
through `setOnlineStateProperty` does not change what `getOnlineState` returns. -/
theorem the_shipped_update_never_touches_the_model {α : Type} (s : α) (v : Views α) :
    (shippedSetOnline s v).model = v.model := rfl

/-- **…so the two views disagree whenever the new state differs from the old one.** Quantified over
every state, so this is a property of the write, not of a chosen example. -/
theorem the_views_diverge_after_a_shipped_update {α : Type} [DecidableEq α]
    (s : α) (v : Views α) (h : s ≠ v.model) :
    (shippedSetOnline s v).model ≠ (shippedSetOnline s v).view := by
  simp only [shippedSetOnline]
  exact fun hc => h hc.symm

/-- **The repair restores agreement, always.** -/
theorem the_repair_makes_the_views_agree {α : Type} (s : α) (v : Views α) :
    (repairedSetOnline s v).model = (repairedSetOnline s v).view := rfl

/-- **Anti-amputation.** Agreement is also achieved by never updating anything, so the repair must
still deliver the new state to the view. -/
theorem the_repair_still_updates_the_view {α : Type} (s : α) (v : Views α) :
    (repairedSetOnline s v).view = s := rfl

/-- ...and to the model, which is the half the shipped code skipped. -/
theorem the_repair_also_updates_the_model {α : Type} (s : α) (v : Views α) :
    (repairedSetOnline s v).model = s := rfl

/-- **The repair matches the convention the class already follows** for `suspended` and
`forcePriority`, rather than inventing a third behaviour. -/
theorem the_repair_matches_the_existing_mirroring_pattern {α : Type} (s : α) (v : Views α) :
    repairedSetOnline s v = mirroredSet s v := rfl

/-- A reader of the model and a reader of the view can never be given different answers after a
repaired write — stated over both readers explicitly, since the defect was that the codebase has
readers of each. -/
theorem no_two_readers_can_disagree {α : Type} (s : α) (v : Views α)
    (readModel readView : Views α → α)
    (hm : readModel = Views.model) (hv : readView = Views.view) :
    readModel (repairedSetOnline s v) = readView (repairedSetOnline s v) := by
  subst hm; subst hv; rfl

/-- Writing the same state twice changes nothing further — the repair is idempotent, so a poll loop
that re-asserts the current state cannot oscillate the two views. -/
theorem the_repaired_write_is_idempotent {α : Type} (s : α) (v : Views α) :
    repairedSetOnline s (repairedSetOnline s v) = repairedSetOnline s v := rfl

/-! ### Finding 2 — the swallowed failure -/

/-- What a failed refresh left behind. -/
inductive Trace where
  /-- nothing at all: `catch (Exception var8) {}` -/
  | silent
  /-- a line an operator can find in the log -/
  | logged
  deriving DecidableEq, Repr

/-- The shipped handler: an empty catch block. -/
def shippedOnFailure : Trace := .silent

/-- The repair: record it. -/
def repairedOnFailure : Trace := .logged

/-- **A swallowed failure leaves no record.** The row keeps a stale state and nothing in any log
says why. -/
theorem a_swallowed_failure_leaves_no_record : shippedOnFailure = .silent := rfl

theorem the_repair_records_every_failure : repairedOnFailure = .logged := rfl

theorem the_two_handlers_differ : shippedOnFailure ≠ repairedOnFailure := by decide

/-- A `throws` clause a body cannot satisfy. `setOnlineStateProperty`'s body is one property write;
it can raise neither `IOException` nor `ExecutionException`. Modelled as: the set of checked
exceptions the body can actually raise is empty, while the declared set is not. -/
def declaredThrows : List String := ["IOException", "ExecutionException"]

def actuallyThrown : List String := []

/-- **The declared clause is dead** — nothing in it can ever be raised by the body. -/
theorem the_declared_throws_can_never_fire (e : String) (h : e ∈ actuallyThrown) : False := by
  simp [actuallyThrown] at h

/-- ...while the declaration forces every caller to handle two exceptions, which is what produced
the empty catch. -/
theorem the_declaration_burdens_every_caller : declaredThrows ≠ [] := by decide

theorem the_repair_declares_nothing_it_cannot_raise :
    actuallyThrown = ([] : List String) := rfl

#guard (shippedSetOnline (5 : Nat) { model := 1, view := 1 }).model == 1
#guard (shippedSetOnline (5 : Nat) { model := 1, view := 1 }).view == 5
#guard (repairedSetOnline (5 : Nat) { model := 1, view := 1 }).model == 5
#guard (repairedSetOnline (5 : Nat) { model := 1, view := 1 }).view == 5
#guard repairedSetOnline (5 : Nat) { model := 1, view := 1 } == mirroredSet 5 { model := 1, view := 1 }
#guard shippedOnFailure == Trace.silent
#guard repairedOnFailure == Trace.logged
#guard actuallyThrown == ([] : List String)
#guard declaredThrows.length == 2

end CtbrecSpec
