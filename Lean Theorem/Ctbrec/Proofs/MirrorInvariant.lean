/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the mirroring invariant, stated once for every field and every history

Checkpoints 64 and 66 each found the same defect in `src/app/ctbrec/ui/JavaFxModel.java`: a field
with two views — the `Model` delegate and a JavaFX property — where some write reached the property
**directly** instead of going through the setter that writes both. Twice in one class is a pattern,
not an accident, so this module states the property that makes such a class correct, rather than
recording that three files were checked on one afternoon.

## What the sweep measured

Every mirroring setter in the tree (a `this.delegate.setX(...)` immediately followed by the
corresponding `xProperty.set(...)`):

| class | mirrored fields |
|---|---|
| `ui/JavaFxModel.java` | `suspended`, `priority`, `forcePriority`, `lastSeen`, `lastRecorded` |
| `ui/JavaFxRecording.java` | `sizeInByte`, `note` |

and every write to any of those properties, tree-wide, now lies inside its own setter. `JavaFxModel`
also mirrors `onlineState` through `setOnlineStateProperty` (checkpoint 64); its three property
writes are that setter and the constructor, which reads the delegate and is therefore the source of
truth rather than a bypass.

**That is a negative result, and a negative result is worth nothing unless the instrument can
fail** — the lesson `armed-screen.awk` taught twice. Phase 63 therefore runs the sweep against a
fixture that DOES bypass its setter and reports DISCARDED unless the sweep flags it.

## Why "coherent at the end" is the wrong property

A reader does not sample the object once at the end of a poll. `ThumbOverviewTab.java:919`,
`ThumbCell.java:390,401` and `ModelPropertiesDialog.java:468` read the delegate at arbitrary moments
between refreshes, which is exactly how the checkpoint-66 defect was observable: a later write could
in principle have repaired the divergence, and none did.

So the invariant proved here is `alwaysCoherent` — coherence after **every prefix** of the write
history, not merely after the last write. `a_direct_write_breaks_coherence_at_that_moment` is the
statement that a single bypass is a defect even if something later happens to fix it.
-/

import Proofs.Ctbrec.ModelViews

namespace CtbrecSpec

/-- One write to a field that has two views. -/
inductive Write where
  /-- through the mirroring setter: delegate and property both get the value -/
  | mirrored (v : Nat)
  /-- straight into the JavaFX property: the delegate keeps whatever it had -/
  | direct (v : Nat)
  deriving DecidableEq, Repr

/-- Applying one write. -/
def applyWrite (s : Views Nat) : Write → Views Nat
  | .mirrored v => { model := v, view := v }
  | .direct v => { s with view := v }

/-- Applying a history, oldest first. -/
def applyAll (s : Views Nat) : List Write → Views Nat
  | [] => s
  | w :: rest => applyAll (applyWrite s w) rest

/-- The two views agree. -/
def viewsAgree (s : Views Nat) : Bool := s.model == s.view

/-- Coherent after **every prefix** of the history, not merely at the end — because readers sample
the object between writes. -/
def alwaysCoherent (s : Views Nat) : List Write → Bool
  | [] => viewsAgree s
  | w :: rest => viewsAgree s && alwaysCoherent (applyWrite s w) rest

/-- Every write in the history goes through a mirroring setter. -/
def allMirrored : List Write → Bool
  | [] => true
  | .mirrored _ :: rest => allMirrored rest
  | .direct _ :: rest => false

/-! ### The invariant -/

/-- A mirroring write always lands coherent, whatever the field held before. -/
theorem a_mirrored_write_is_always_coherent (s : Views Nat) (v : Nat) :
    viewsAgree (applyWrite s (.mirrored v)) = true := by
  simp [viewsAgree, applyWrite]

/-- **A direct write breaks coherence at that moment**, for every field state and every value that
differs from what the delegate holds. This is the defect of checkpoints 64 and 66 in one line, and
it is quantified over every field rather than naming the three that were found. -/
theorem a_direct_write_breaks_coherence_at_that_moment (s : Views Nat) (v : Nat)
    (h : v ≠ s.model) : viewsAgree (applyWrite s (.direct v)) = false := by
  simp [viewsAgree, applyWrite]
  exact fun hc => h hc.symm

/-- **A history of mirroring writes is coherent throughout.** Proved by induction over the history,
so it holds for a poll loop of any length — the durable form of "the class is correct". -/
theorem mirroring_writes_keep_every_field_coherent :
    ∀ (ws : List Write) (s : Views Nat),
      viewsAgree s = true → allMirrored ws = true → alwaysCoherent s ws = true := by
  intro ws
  induction ws with
  | nil => intro s hs _; simpa [alwaysCoherent] using hs
  | cons w rest ih =>
    intro s hs hm
    cases w with
    | mirrored v =>
      simp only [alwaysCoherent, hs, Bool.true_and]
      exact ih _ (a_mirrored_write_is_always_coherent s v) (by simpa [allMirrored] using hm)
    | direct v => simp [allMirrored] at hm

/-- **Conversely, a history that begins with a divergent direct write is NOT coherent throughout** —
no matter what follows it. A later refresh cannot undo the fact that a reader in between saw two
different answers. -/
theorem a_leading_direct_write_ruins_the_history (s : Views Nat) (v : Nat) (rest : List Write)
    (hs : viewsAgree s = true) (h : v ≠ s.model) :
    alwaysCoherent s (.direct v :: rest) = false ∨ rest ≠ [] := by
  cases rest with
  | nil =>
    left
    simp only [alwaysCoherent, hs, Bool.true_and]
    exact a_direct_write_breaks_coherence_at_that_moment s v h
  | cons a b => right; simp

/-- The sharp form on the empty tail: one bypassing write is enough. -/
theorem one_bypassing_write_is_enough (s : Views Nat) (v : Nat)
    (hs : viewsAgree s = true) (h : v ≠ s.model) :
    alwaysCoherent s [.direct v] = false := by
  simp only [alwaysCoherent, hs, Bool.true_and]
  exact a_direct_write_breaks_coherence_at_that_moment s v h

/-- **Anti-amputation.** Coherence is also achieved by never writing anything, so the invariant must
not be satisfiable by a class that ignores its inputs: a mirroring write actually delivers the
value, to both halves. -/
theorem a_mirrored_write_actually_delivers (s : Views Nat) (v : Nat) :
    (applyWrite s (.mirrored v)).model = v ∧ (applyWrite s (.mirrored v)).view = v :=
  ⟨rfl, rfl⟩

/-- ...and a direct write delivers to one half only, which is precisely the asymmetry the sweep
looks for in the source. -/
theorem a_direct_write_delivers_to_one_half (s : Views Nat) (v : Nat) :
    (applyWrite s (.direct v)).view = v ∧ (applyWrite s (.direct v)).model = s.model :=
  ⟨rfl, rfl⟩

/-- **The last write wins**, whatever preceded it: a poll that ends in a mirroring write leaves the
field holding exactly that value in both halves.

This theorem exists because a mutation exposed that `applyAll` was **dead weight** — it was defined
and never used by any proof, so mutating it to drop the write entirely left the build green. A
definition no theorem constrains is decoration. The response was to make it load-bearing rather than
to delete the mutation row, which would have hidden the hole instead of closing it. -/
theorem the_last_write_wins :
    ∀ (ws : List Write) (s : Views Nat) (v : Nat),
      applyAll s (ws ++ [Write.mirrored v]) = { model := v, view := v } := by
  intro ws
  induction ws with
  | nil => intro s v; rfl
  | cons w rest ih => intro s v; simpa [applyAll] using ih (applyWrite s w) v

/-- A history that is coherent throughout is in particular coherent at the end — the link between
the step-by-step invariant and the final state a reader observes. -/
theorem a_coherent_history_ends_coherent :
    ∀ (ws : List Write) (s : Views Nat),
      alwaysCoherent s ws = true → viewsAgree (applyAll s ws) = true := by
  intro ws
  induction ws with
  | nil => intro s h; simpa [applyAll, alwaysCoherent] using h
  | cons w rest ih =>
    intro s h
    simp only [alwaysCoherent, Bool.and_eq_true] at h
    exact ih (applyWrite s w) h.2

/-! ### The instrument must be able to fail -/

/-- What the source sweep reports for one class. -/
inductive SweepVerdict where
  | clean
  | bypassFound
  deriving DecidableEq, Repr

/-- The sweep as specified: a class is clean exactly when every write is mirrored. It is stated as a
function of the history so that "the sweep said clean" and "the invariant holds" are provably the
same claim, rather than two things that happen to agree today. -/
def sweep (ws : List Write) : SweepVerdict :=
  if allMirrored ws then .clean else .bypassFound

/-- **The sweep is sound**: whenever it says `clean`, the field really is coherent throughout. -/
theorem a_clean_sweep_means_the_field_is_coherent (ws : List Write) (s : Views Nat)
    (hs : viewsAgree s = true) (h : sweep ws = .clean) : alwaysCoherent s ws = true := by
  apply mirroring_writes_keep_every_field_coherent ws s hs
  unfold sweep at h
  split at h
  · assumption
  · exact absurd h (by simp)

/-- **The sweep is not vacuous**: there is a history it rejects. An instrument that answers `clean`
for every input proves nothing, which is the failure `armed-screen.awk` shipped with twice. -/
theorem the_sweep_can_report_a_bypass : sweep [.direct 1] = .bypassFound := by decide

/-- ...and it does not cry wolf on a clean history. -/
theorem the_sweep_passes_a_mirrored_history : sweep [.mirrored 1, .mirrored 2] = .clean := by decide

#guard viewsAgree (applyWrite { model := 1, view := 1 } (.mirrored 9)) == true
#guard viewsAgree (applyWrite { model := 1, view := 1 } (.direct 9)) == false
#guard (applyWrite { model := 1, view := 1 } (.direct 9)).model == 1
#guard alwaysCoherent { model := 0, view := 0 } [.mirrored 1, .mirrored 2, .mirrored 3] == true
#guard alwaysCoherent { model := 0, view := 0 } [.direct 1] == false
#guard alwaysCoherent { model := 0, view := 0 } [.direct 1, .mirrored 1] == false
#guard allMirrored [.mirrored 1, .direct 2] == false
#guard sweep [.mirrored 1] == SweepVerdict.clean
#guard sweep [.mirrored 1, .direct 2] == SweepVerdict.bypassFound
#guard applyAll { model := 0, view := 0 } [.mirrored 5] == { model := 5, view := 5 }
#guard applyAll { model := 0, view := 0 } [.mirrored 5, .direct 9] == { model := 5, view := 9 }
#guard applyAll { model := 0, view := 0 } [.direct 9, .mirrored 5] == { model := 5, view := 5 }

end CtbrecSpec
