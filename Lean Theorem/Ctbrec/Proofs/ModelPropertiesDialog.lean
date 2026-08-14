/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the edit dialog must refresh every backing it reads (delegate AND property)

Subject: `ModelPropertiesDialog` (`src/app/ctbrec/ui/tabs/recorded/ModelPropertiesDialog.java`)
and the accessors it drives on `JavaFxModel` (`.../JavaFxModel.java`).

## Why this file exists

CP64/CP66 found the divergence bug in `JavaFxModel`: a value read from the *delegate* but written to
a JavaFX *property* (or vice versa) leaves the two backings inconsistent, so the UI shows a stale
value. `ModelPropertiesDialog` is the third class that touches both backings, and it was unaudited.

## What was MEASURED in the code (not assumed)

Every getter the dialog uses reads the delegate:
```
JavaFxModel.getPriority()            -> delegate.getPriority()           (:354)
JavaFxModel.getPreferredResolution() -> delegate.getPreferredResolution()(:308)
JavaFxModel.getDowntimeStart()       -> delegate.getDowntimeStart()      (:449)
JavaFxModel.isPreferHigherBitrate()  -> delegate.isPreferHigherBitrate() (:316)
```
So `this.model.getX()` and `this.delegateModel.getX()` return the SAME value — the dialog's
change-detection (`if (newX != this.delegateModel.getX())`) cannot diverge from what the spinner
displayed. That half is trivially sound.

The subtle part is the WRITE. Exactly one field has a second, observable backing:
```
JavaFxModel.setPriority(p)            -> delegate.setPriority(p); priorityProperty.set(p);  (:349)
JavaFxModel.setPreferredResolution(r) -> delegate.setPreferredResolution(r);               (:312)
JavaFxModel.setDowntimeStart(t)       -> delegate.setDowntimeStart(t);                      (:453)
JavaFxModel.setPreferHigherBitrate(b) -> delegate.setPreferHigherBitrate(b);               (:320)
```
`getPriority` reads only the delegate, but `priorityProperty` is a **write-only mirror** that a
JavaFX cell binding observes for reactive refresh. The dialog's save path therefore writes BOTH:
```
if (newPriority != this.delegateModel.getPriority()) {
    this.delegateModel.setPriority(newPriority);   // updates the delegate (change-detection source)
    this.model.setPriority(newPriority);           // updates priorityProperty (the bound UI)
}
```
Dropping `this.model.setPriority(newPriority)` would keep `getPriority()` correct (it reads the
delegate) yet leave `priorityProperty` — and every cell bound to it — showing the old priority. That
is the CP64 divergence, merely deferred to the property observer. The dialog avoids it by the dual
write, and this file proves that avoidance is load-bearing, not decorative.

## The model

A field carries the set of backings the UI *reads* it from and the set the dialog's save *writes*.
Coherence = every read backing is refreshed by the save. The theorems are about that containment,
so they keep their force for any edit dialog over a mirrored model, not just this one.
-/

import Proofs.Ctbrec.ModelViews

namespace CtbrecSpec

/-- Where a model field can live. `delegate` is the plain model; `property` is a JavaFX property a
binding observes for reactive UI refresh. -/
inductive Backing where
  | delegate
  | property
  deriving DecidableEq, BEq, Repr

/-- A field the dialog edits. `readBackings` = every backing some part of the UI reads this value
from (change-detection + display live on the delegate; a bound cell reads a property).
`dialogWrites` = every backing the dialog's OK handler writes. -/
structure DialogField where
  name : String
  readBackings : List Backing
  dialogWrites : List Backing
  deriving Repr

/-- **Coherence.** The save must refresh every backing anything reads, or a reader goes stale. -/
def dialogCoherent (f : DialogField) : Bool :=
  f.readBackings.all (fun b => f.dialogWrites.contains b)

/-! ### The four mirror-relevant fields, from the measured code above -/

/-- Priority: read from the delegate (getPriority / change-detection) AND from `priorityProperty`
(a bound cell). The dialog writes BOTH. -/
def priority : DialogField :=
  { name := "priority", readBackings := [.delegate, .property],
    dialogWrites := [.delegate, .property] }

/-- Resolution: delegate only, both read and written. -/
def resolution : DialogField :=
  { name := "resolution", readBackings := [.delegate], dialogWrites := [.delegate] }

/-- Downtime: delegate only. -/
def downtime : DialogField :=
  { name := "downtime", readBackings := [.delegate], dialogWrites := [.delegate] }

/-- Higher-bitrate preference: delegate only. -/
def bitrate : DialogField :=
  { name := "bitrate", readBackings := [.delegate], dialogWrites := [.delegate] }

def dialogFields : List DialogField := [priority, resolution, downtime, bitrate]

/-! ### The proof -/

/-- **Every field the dialog edits is coherent** — the save refreshes every backing that is read,
so no reader is left stale after an edit. -/
theorem every_field_is_coherent : dialogFields.all dialogCoherent = true := by decide

/-- **Priority genuinely has a property backing** — so the coherence above is not vacuous: there is
a second reader (the bound cell) that the save must keep in sync. -/
theorem priority_has_a_property_backing : priority.readBackings.contains .property = true := by decide

/-- **Dropping the property write breaks coherence.** This is the exact regression the dual write
prevents: if the dialog wrote only `delegateModel.setPriority` and not `model.setPriority`, the
`priorityProperty` reader would go stale. The instrument can SEE that. -/
theorem dropping_the_property_write_breaks_coherence :
    dialogCoherent { priority with dialogWrites := [.delegate] } = false := by decide

/-- **The CP64 bug shape is incoherent by construction.** A value read from a property but written
only to the delegate — `setOnlineStateProperty` writing the property while `getOnlineState` read the
delegate, but mirrored — is exactly what `dialogCoherent` rejects. The model can express the historical
bug, so a green result on `dialogFields` means something. -/
theorem the_cp64_bug_shape_is_incoherent :
    dialogCoherent { name := "onlineState", readBackings := [.property], dialogWrites := [.delegate] }
      = false := by decide

/-- **Anti-amputation: coherence is not trivially satisfiable.** A field with no readers passes
`dialogCoherent` for free; the invariant only means something on a field that is actually read, and
`priority` is one — read from two backings and still coherent. -/
theorem coherence_is_not_vacuous :
    ∃ f : DialogField, f.readBackings ≠ [] ∧ dialogCoherent f = true :=
  ⟨priority, by decide, by decide⟩

/-- **The change-detection source equals the display source for every field.** The spinner is
initialised from `this.model.getX()` and the save compares against `this.delegateModel.getX()`; both
resolve to the delegate, so the comparison is against exactly the value shown. Modelled as: the
delegate is a read backing of every field (both readers live there). -/
theorem change_detection_reads_what_was_displayed :
    dialogFields.all (fun f => f.readBackings.contains .delegate) = true := by decide

#guard dialogCoherent priority
#guard dialogCoherent resolution
#guard !dialogCoherent { priority with dialogWrites := [.delegate] }
#guard !dialogCoherent { name := "x", readBackings := [.property], dialogWrites := [.delegate] }
#guard dialogFields.all dialogCoherent
#guard dialogFields.length == 4
#guard priority.readBackings.contains .property
#guard priority.dialogWrites.contains .property

end CtbrecSpec
