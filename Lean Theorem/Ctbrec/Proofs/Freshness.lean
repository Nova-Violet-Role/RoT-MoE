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
# STALE, FROZEN, AND HALF-PROBED — the three defects of 2026-08-10, as laws

Three failures were reported by the Socio on 2026-08-10 ("the E-S mark on the Thumbnail the
right-click event doesnt show anything, same thing for the Count of Viewers"). Two were repaired in
Java and deployed **before** this file existed, which was itself a violation of the standing rule
that every fortification goes through Lean 4 first. This module discharges that debt and generalises
each defect from an incident into a property.

All three share one shape: **an affirmative check that cannot distinguish the good case from the bad
one.** "The class is in the jar" does not mean it is current. "The mark was set once" does not mean
it is right now. "One port answered" does not mean the right one did.
-/

namespace CtbrecSpec.Freshness

/-! ## 1. THE FROZEN MARK — `ThumbCell.updateEnforceSeatsMark()`

Measured defect: the method was called only from the constructor (`ThumbCell.java:218`) and never
from `update()`. The grid is populated before the user marks anything, so every cell froze its mark
at the build-time value and no later toggle could bring it back.

The bitter detail: the comment directly above `updateViewerCount()` in `update()` warns that
constructor-only initialisation would leave a label "hidden forever" — and the seat mark beside it
had exactly that bug. -/

/-- A thumbnail cell: what was true when it was built, what is true now, and whether it re-reads. -/
structure Cell where
  markedAtBuild : Bool
  markedNow : Bool
  refreshesOnUpdate : Bool
deriving DecidableEq, Repr

/-- What the cell actually displays. Without a refresh it can only show the build-time value. -/
def markVisible (c : Cell) : Bool :=
  if c.refreshesOnUpdate then c.markedNow else c.markedAtBuild

/-- **The reported defect, exactly**: built unmarked, marked afterwards, no refresh → stays hidden. -/
theorem constructor_only_freezes_the_mark :
    markVisible { markedAtBuild := false, markedNow := true, refreshesOnUpdate := false } = false := by
  decide

/-- **The fix is correct for EVERY state**, not just the reported one: with the refresh in `update()`
the cell shows the current value whatever it is. -/
theorem refresh_shows_current_state (b n : Bool) :
    markVisible { markedAtBuild := b, markedNow := n, refreshesOnUpdate := true } = n := by
  cases b <;> cases n <;> rfl

/-- **Constructor-only display is unsound in general**: there is always a state where what is shown
disagrees with what is true. -/
theorem no_refresh_can_disagree_with_truth :
    ∃ c : Cell, c.refreshesOnUpdate = false ∧ markVisible c ≠ c.markedNow := by
  refine ⟨{ markedAtBuild := false, markedNow := true, refreshesOnUpdate := false }, rfl, ?_⟩
  decide

/-- With the refresh, disagreement is impossible — the property the repair buys. -/
theorem refresh_never_disagrees (c : Cell) (h : c.refreshesOnUpdate = true) :
    markVisible c = c.markedNow := by
  unfold markVisible
  rw [h]
  rfl

/-! ## 2. PRESENCE IS NOT FRESHNESS — the audit that let a stale class through

Measured defect: `ThumbOverviewTab` builds the right-click menu (`ThumbOverviewTab.java:653`) and was
never recompiled. The shipped class had `seat refs = 0`. My deployment audit compared source
basenames against jar ENTRIES, and the entry existed — so the audit passed a stale class.

This is the CP145-146 defect again (callee fresh, caller stale) and the audit was blind to it *by
construction*: it only ever asked "is the name there?". -/

/-- A deployed class: is it in the jar at all, and does its bytecode carry the new symbol. -/
structure Deployed where
  inJar : Bool
  hasNewSymbol : Bool
deriving DecidableEq, Repr

/-- The old audit: existence only. This is what `unzip -l | grep -c <Class>` implements. -/
def existenceAudit (d : Deployed) : Bool := d.inJar

/-- The repaired audit: existence AND the symbol, i.e. `javap` the extracted class. -/
def freshnessAudit (d : Deployed) : Bool := d.inJar && d.hasNewSymbol

/-- **The theorem the missed defect demanded**: being in the jar does not imply being current.
The witness is `ThumbOverviewTab` as actually shipped. -/
theorem in_jar_does_not_imply_current :
    ∃ d : Deployed, existenceAudit d = true ∧ freshnessAudit d = false := by
  exact ⟨{ inJar := true, hasNewSymbol := false }, rfl, rfl⟩

/-- The freshness audit is strictly stronger — it never passes something existence would reject. -/
theorem freshness_implies_existence (d : Deployed) (h : freshnessAudit d = true) :
    existenceAudit d = true := by
  cases hj : d.inJar
  · simp [freshnessAudit, hj] at h
  · simp [existenceAudit, hj]

/-- And it is strictly stronger: existence does NOT imply freshness. -/
theorem existence_does_not_imply_freshness :
    ¬ (∀ d : Deployed, existenceAudit d = true → freshnessAudit d = true) := by
  intro h
  have := h { inJar := true, hasNewSymbol := false } rfl
  exact absurd this (by decide)

/-- A class that passes the freshness audit really does carry the new code. -/
theorem freshness_audit_is_sound (d : Deployed) (h : freshnessAudit d = true) :
    d.hasNewSymbol = true := by
  cases hs : d.hasNewSymbol
  · simp [freshnessAudit, hs] at h
  · rfl

/-! ## 3. ONE PORT OUT OF N — `spec-check.sh:1171`

Measured defect: each stream binds an ephemeral port (`ChaturbateLlhlsMediaServer.java:28` binds
`InetSocketAddress("127.0.0.1", 0)`). The harness discovers them with `... | sort -u | head -1`,
i.e. it takes the FIRST of the sorted list, then probes only that one. On 2026-08-08 three servers
were live (`10373 10394 10413`) and the phase abstained anyway.

Modelled faithfully: `sort -u | head -1` is "the first element of the sorted list", so `probeOne`
inspects the head and `probeAny` inspects all. The port NUMBERS are deliberately NOT in any theorem —
they are ephemeral and a theorem pinned to them would expire on the next run. They appear only in
`#guard`s below, documenting the measured instance. -/

/-- What the harness does today: probe the head of the (sorted) port list. -/
def probeOne (ports : List Nat) (reachable : Nat → Bool) : Bool :=
  match ports with
  | [] => false
  | p :: _ => reachable p

/-- What it must do: probe every listening port before declaring the phase unrunnable. -/
def probeAny (ports : List Nat) (reachable : Nat → Bool) : Bool := ports.any reachable

/-- **The defect, stated generally**: a reachable server can exist while the single probe misses it. -/
theorem single_probe_can_miss :
    ∃ (ports : List Nat) (reachable : Nat → Bool),
      probeAny ports reachable = true ∧ probeOne ports reachable = false := by
  exact ⟨[1, 2], fun p => p == 2, rfl, rfl⟩

/-- **The property the repair must have**: if ANY listening port serves, the probe succeeds. -/
theorem exists_reachable_implies_probeAny (ports : List Nat) (reachable : Nat → Bool)
    (h : ∃ p, p ∈ ports ∧ reachable p = true) : probeAny ports reachable = true := by
  obtain ⟨p, hmem, hr⟩ := h
  unfold probeAny
  exact List.any_eq_true.mpr ⟨p, hmem, hr⟩

/-- The multi-port probe subsumes the single one: anything the old code found, the new code finds. -/
theorem probeOne_implies_probeAny (ports : List Nat) (reachable : Nat → Bool)
    (h : probeOne ports reachable = true) : probeAny ports reachable = true := by
  cases ports with
  | nil => simp [probeOne] at h
  | cons p rest => simp [probeAny, List.any_cons, probeOne] at h ⊢; exact Or.inl h

/-- So switching to `probeAny` cannot lose a phase that used to run — it can only gain. -/
theorem repair_never_regresses (ports : List Nat) (reachable : Nat → Bool) :
    probeOne ports reachable = true → probeAny ports reachable = true :=
  probeOne_implies_probeAny ports reachable

/-! ## Executable checks — the measured instances, kept OUT of the theorems -/

-- The frozen mark, as reported.
#guard markVisible { markedAtBuild := false, markedNow := true, refreshesOnUpdate := false } == false
#guard markVisible { markedAtBuild := false, markedNow := true, refreshesOnUpdate := true } == true

-- ThumbOverviewTab as actually shipped: in the jar, without the seat code.
#guard existenceAudit { inJar := true, hasNewSymbol := false } == true
#guard freshnessAudit { inJar := true, hasNewSymbol := false } == false
#guard freshnessAudit { inJar := true, hasNewSymbol := true } == true

-- The three ephemeral ports measured on 2026-08-08, with only the highest reachable.
-- A #guard, never a hypothesis: these numbers change every single run.
#guard probeOne [10373, 10394, 10413] (fun p => p == 10413) == false
#guard probeAny [10373, 10394, 10413] (fun p => p == 10413) == true
#guard probeOne [10373, 10394, 10413] (fun p => p == 10373) == true

end CtbrecSpec.Freshness
