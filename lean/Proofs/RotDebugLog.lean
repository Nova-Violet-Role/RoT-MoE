/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A DEBUG CHANNEL THAT CANNOT REPORT ITS OWN FAILURE IS NOT A DEBUG CHANNEL

The goal for this repo names one thing the router does not yet check: its own
`*.log` debug output. This module is the Lean half of closing that, and it was
written after reading the emit site rather than from memory.

`hooks/rot-router.sh:365-369` appends one JSON record per routed turn:

```sh
if [ -n "${ROTMOE_DEBUG_LOG:-}" ]; then
  printf '{"kind":"route",...}\n' ... >> "$ROTMOE_DEBUG_LOG" 2>/dev/null || true
fi
```

The `|| true` is CORRECT and must stay. A hook that failed a user's turn because
a debug file was unwritable would be a far worse defect than a missing log. The
problem is not that the write is tolerant — it is that the tolerance is
**silent**, and silence makes two different worlds produce identical evidence:

| world | records an observer finds |
|---|---|
| the router never fired | 0 |
| the router fired N times, the path was unwritable | 0 |

That is the same missing-evidence class as the twelve fake RotGauge kills fixed
earlier this cycle. There the harness read "bash returned 1" as "the build
failed" when the build had never run; here a reader takes "no records" as "no
routing" when routing may have happened all along. In both cases the honest
answer is a THIRD state — unattributable — and the fix is to make the failure
leave a mark.

§1 proves the ambiguity exists, §2 proves a one-shot marker removes it, §3
proves the retention rule for a bounded log, and §4 states what the shipped
hook must therefore do.

The second half is not hypothetical either. `~/.claude` on the development
machine holds `rolling-context-debug.log` at **1.4 GB** and
`rolling-context-proxy.log` at **1.1 GB**, both still growing, both written by
the same unbounded append pattern. They belong to the proxy infrastructure
rather than to RoT MoE — which is exactly why they are good evidence: this is
what the pattern does when nobody bounds it.
-/

namespace RotDebugLog

/-! ## §1 The ambiguity, stated and proved -/

/-- The world as it really is: whether the log path could be written, and how
many turns the router actually routed. -/
structure World where
  writable : Bool
  fired : Nat
deriving DecidableEq, Repr

/-- What an observer can count in the file afterwards. With a silent `|| true`,
this is the ONLY thing they get. -/
def recordsSeen (w : World) : Nat := if w.writable then w.fired else 0

/-- Two worlds that differ in the thing anyone cares about — did the router run
— and are nevertheless indistinguishable to a reader of the log. -/
def neverFired : World := { writable := true, fired := 0 }
def firedButUnwritable : World := { writable := false, fired := 7 }

/-- **The defect.** A silent channel cannot separate "the router never fired"
from "the router fired seven times and the log was unwritable". -/
theorem silent_channel_is_ambiguous :
    recordsSeen neverFired = recordsSeen firedButUnwritable ∧
    neverFired.fired ≠ firedButUnwritable.fired := by
  decide

/-- And the ambiguity is not an artefact of the number 7: it holds for every
positive count. Quantified, so it stays true of any future traffic level. -/
theorem silent_channel_is_ambiguous_at_every_volume (n : Nat) :
    recordsSeen { writable := false, fired := n } = recordsSeen neverFired := by
  simp [recordsSeen, neverFired]

/-! ## §2 The marker, and why one bit is enough -/

/-- What the observer gets once the hook records that a write was attempted and
failed. `marker` is a single bit: at least one append did not land. -/
structure Observation where
  records : Nat
  marker : Bool
deriving DecidableEq, Repr

/-- The instrumented channel. The marker fires exactly when the router had
something to write and could not. -/
def observe (w : World) : Observation :=
  { records := recordsSeen w,
    marker := !w.writable && 0 < w.fired }

/-- **The repair.** With the marker, the two worlds of §1 are distinguishable —
so a reader can tell "nothing happened" from "the evidence was lost". -/
theorem marker_resolves_the_ambiguity :
    observe neverFired ≠ observe firedButUnwritable := by decide

/-- Stronger, and the property actually worth shipping: an observation of zero
records with no marker means the router genuinely did not fire. Quantified over
every world, not just the two exhibited above. -/
theorem quiet_and_unmarked_means_it_never_fired (w : World) :
    (observe w).records = 0 → (observe w).marker = false → w.fired = 0 := by
  intro hr hm
  by_cases hw : w.writable
  · simpa [observe, recordsSeen, hw] using hr
  · simp [observe, hw] at hm
    exact hm

/-- The converse direction, which is what makes the marker non-decorative: if
the router DID fire and the log could not be written, the marker is set. No
silent loss remains. -/
theorem lost_evidence_is_always_marked (w : World)
    (hf : 0 < w.fired) (hw : w.writable = false) : (observe w).marker = true := by
  simp [observe, hw, hf]

/-- Negative control: the marker must be capable of staying false, or the two
theorems above would be satisfied by a hook that simply always complains. -/
theorem marker_is_not_always_set :
    (observe { writable := true, fired := 5 }).marker = false := by decide

/-- And a marker that is always true would break the resolution property, which
is what forbids "just print a warning every turn" as a fix. -/
theorem an_always_on_marker_would_not_distinguish :
    (fun _ : World => true) neverFired = (fun _ : World => true) firedButUnwritable := by
  rfl

/-! ## §3 Retention: a bounded log must keep the NEWEST records

Rotation is where a naive implementation quietly does the wrong thing. Truncating
a file keeps the OLDEST lines and discards everything after — which is precisely
backwards for a debug channel, where the interesting turn is the last one. -/

/-- Keep at most `cap` records, discarding from the FRONT. Records are ordered
oldest-first, as they are appended. -/
def rotate (cap : Nat) (records : List Nat) : List Nat :=
  records.drop (records.length - cap)

/-- A rotated log never exceeds the cap. -/
theorem rotate_length_le (cap : Nat) (rs : List Nat) :
    (rotate cap rs).length ≤ cap := by
  simp [rotate]
  omega

/-- **The property that matters.** Rotation keeps the most recent record. Losing
the newest line is the failure mode of a truncate-from-the-end implementation,
and this is the theorem that forbids it. -/
-- NOTE: this was first stated with an extra hypothesis `rs ≠ []`, and the build
-- warned that it went unreferenced. That is a report about the THEOREM, not
-- about the proof script: the retention property holds for the empty log too,
-- so the hypothesis was over-assumption. Dropped rather than silenced with `_`.
-- `0 < cap` is genuinely needed: at cap = 0 the whole log is discarded and the
-- newest record is lost, which is exactly what the bound must not permit.
theorem rotate_keeps_the_newest (cap : Nat) (rs : List Nat) (hcap : 0 < cap) :
    (rotate cap rs).getLast? = rs.getLast? := by
  unfold rotate
  rcases Nat.lt_or_ge rs.length cap with h | h
  · have : rs.length - cap = 0 := by omega
    simp [this]
  · -- `exact?` found nothing for this shape, so it is reduced to indices:
    -- getLast? is the element at length-1, and drop shifts the index.
    simp [List.getLast?_eq_getElem?, List.getElem?_drop, List.length_drop]
    congr 1
    omega

/-- A log under the cap is untouched — rotation is not allowed to discard
anything it does not have to. -/
theorem rotate_below_cap_is_identity (cap : Nat) (rs : List Nat)
    (h : rs.length ≤ cap) : rotate cap rs = rs := by
  have : rs.length - cap = 0 := by omega
  simp [rotate, this]

/-- Negative control for the retention theorem: a "rotation" that kept the FRONT
instead would drop the newest record, so `rotate_keeps_the_newest` is a real
constraint on the implementation rather than a fact about lists. -/
theorem taking_the_front_loses_the_newest :
    (([1, 2, 3] : List Nat).take 2).getLast? ≠ ([1, 2, 3] : List Nat).getLast? := by
  decide

/-! ## §4 What the shipped hook must therefore do

Three obligations, each the direct consequence of a theorem above.

* **Keep `|| true`.** Nothing here asks the hook to fail a turn. `observe` never
  mentions the user's turn at all — the marker is about the LOG, not the run.
* **Set a marker when an append is lost** — `lost_evidence_is_always_marked`.
  One bit, once, not a message per turn: `marker_is_not_always_set` and
  `an_always_on_marker_would_not_distinguish` together rule out the lazy fix of
  warning unconditionally.
* **Bound the file, discarding the OLDEST** — `rotate_keeps_the_newest`. A
  truncation that keeps the front is refuted by
  `taking_the_front_loses_the_newest`.

What this module does NOT prove: that the shell implements any of it. That
binding is `checker/`'s job and is mechanical — regenerate the condition,
execute the real hook, diff the observable. A theorem about `World` constrains
`rot-router.sh` only through a checker that can fail. -/

/-- The three obligations as one executable predicate, so a checker can assert
the same thing the theorems state rather than a paraphrase of it. -/
structure HookContract where
  tolerantWrite : Bool
  marksLostAppend : Bool
  boundedKeepingNewest : Bool
deriving DecidableEq, Repr

/-- The contract the shipped hook must satisfy. -/
def contractHolds (c : HookContract) : Bool :=
  c.tolerantWrite && c.marksLostAppend && c.boundedKeepingNewest

/-- Today's hook, as measured at `hooks/rot-router.sh:365-369` BEFORE the repair:
tolerant, but silent and unbounded. -/
def shippedBeforeRepair : HookContract :=
  { tolerantWrite := true, marksLostAppend := false, boundedKeepingNewest := false }

/-- The pre-repair hook fails the contract — which is the finding, stated so it
cannot be mistaken for a passing state. -/
theorem shipped_hook_failed_the_contract :
    contractHolds shippedBeforeRepair = false := by decide

/-- Tolerance alone is not the contract: this is why "it already has `|| true`"
is not an answer to the finding. -/
theorem tolerance_alone_is_insufficient (c : HookContract)
    (h : c.marksLostAppend = false) : contractHolds c = false := by
  simp [contractHolds, h]

end RotDebugLog
