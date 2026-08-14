/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — when a log line cannot tell two events apart

Subject: `src/common/ctbrec/sites/mfc/Message.java:69-71` (`toString`) and
`src/common/ctbrec/sites/mfc/MyFreeCamsClient.java:396`
(`default: log.trace("Unknown message {}", message)`).

## Why this module exists

The census flagged nine `Message` accessors — `getSender`, `getReceiver`, `getArg1`, `getArg2`
and the matching setters — as having no caller. Measured: the class is built by its six-argument
constructor at `MyFreeCamsClient.java:680`, and only `getType()` and `getMessage()` are ever read.
The other four fields are parsed and never touched.

They are not lost, though, and that is the point of the triage: `toString` renders **all six**,
and the unknown-message branch logs the object. So the accessors are unused while the data still
reaches the only place that needs it. That is an honest explanation, not a deletion licence.

It does leave a real hazard, and it is the kind that appears a year later: **a field added to the
class but not to `toString` becomes invisible**, and the only symptom is that two different
protocol messages produce the same log line. Nothing fails, nothing warns; the diagnostic quietly
stops discriminating.

## What is proved

Fidelity is stated as **injectivity of the renderer over the fields**, not as a property of the
rendered string — a string-concatenation model would need cancellation lemmas that are false in
general, and would prove nothing about the data. The theorems say: a complete renderer separates
any two distinct records, and an incomplete one **collides** — two records differing only in the
dropped field render identically.
-/

namespace CtbrecSpec

/-- An MFC protocol message, reduced to the numeric fields the renderer must separate.
`message` is carried as a code so the whole structure stays decidable. -/
structure Msg where
  type : Nat
  sender : Nat
  receiver : Nat
  arg1 : Nat
  arg2 : Nat
  body : Nat
  deriving DecidableEq, Repr

/-- Which fields a renderer emits, by position. -/
inductive Field where
  | type | sender | receiver | arg1 | arg2 | body
  deriving DecidableEq, Repr

def allFields : List Field := [.type, .sender, .receiver, .arg1, .arg2, .body]

/-- The value a field takes in a message. -/
def valueOf (m : Msg) : Field → Nat
  | .type => m.type
  | .sender => m.sender
  | .receiver => m.receiver
  | .arg1 => m.arg1
  | .arg2 => m.arg2
  | .body => m.body

/-- What a log line carries: the values of the covered fields, in order. Modelling the OUTPUT as
a list of values rather than as concatenated text is deliberate — the question is what the reader
can recover, and text concatenation would need cancellation lemmas that are false in general. -/
def render (covered : List Field) (m : Msg) : List Nat :=
  covered.map (valueOf m)

/-- `Message.toString`, transcribed: every field. -/
def fullRenderer : List Field := allFields

/-- The hazard: a renderer written before `arg2` existed. -/
def lossyRenderer : List Field := [.type, .sender, .receiver, .arg1, .body]

/-- **A complete renderer separates any two distinct messages.** Proved by cases on the first
field that differs, so it holds for every pair, not for sampled ones. -/
theorem a_complete_renderer_is_injective (m₁ m₂ : Msg)
    (h : render fullRenderer m₁ = render fullRenderer m₂) : m₁ = m₂ := by
  cases m₁; cases m₂
  simp [render, fullRenderer, allFields, valueOf] at h
  simp [h.1, h.2.1, h.2.2.1, h.2.2.2.1, h.2.2.2.2.1, h.2.2.2.2.2]

/-- **An incomplete renderer collides.** Two messages differing only in the dropped field produce
the identical log line — the reader cannot tell them apart, and nothing anywhere reports a
problem. A concrete witness is stronger than an existential: it names the pair. -/
theorem a_dropped_field_makes_two_messages_indistinguishable :
    render lossyRenderer ⟨1, 2, 3, 4, 5, 6⟩ = render lossyRenderer ⟨1, 2, 3, 4, 99, 6⟩
      ∧ (⟨1, 2, 3, 4, 5, 6⟩ : Msg) ≠ ⟨1, 2, 3, 4, 99, 6⟩ := by
  decide

/-- **And the complete renderer catches exactly that pair.** Without this the theorem above would
only say the lossy renderer is bad, not that the full one is better. -/
theorem the_complete_renderer_separates_that_pair :
    render fullRenderer ⟨1, 2, 3, 4, 5, 6⟩ ≠ render fullRenderer ⟨1, 2, 3, 4, 99, 6⟩ := by
  decide

/-- The general statement of the hazard: **any** field left out of a renderer can be varied
without changing the output. Quantified over the field and over the message, so it is not a
statement about `arg2`. -/
theorem any_omitted_field_can_be_varied_invisibly (f : Field) (covered : List Field)
    (hf : f ∉ covered) (m : Msg) (v : Nat)
    (upd : Msg) (hupd : ∀ g, g ≠ f → valueOf upd g = valueOf m g) (hv : valueOf upd f = v) :
    render covered upd = render covered m := by
  unfold render
  apply List.map_congr_left
  intro g hg
  exact hupd g (fun h => hf (h ▸ hg))

/-- **Anti-amputation.** `render` is not constant: a renderer covering at least one field
distinguishes messages that differ there. Without this, `fun _ _ => []` would satisfy every
collision theorem above. -/
theorem the_renderer_is_not_constant :
    render fullRenderer ⟨0, 0, 0, 0, 0, 0⟩ ≠ render fullRenderer ⟨1, 0, 0, 0, 0, 0⟩ := by decide

/-- …and it is not injective by accident either: the empty renderer collapses everything, which is
the degenerate case the coverage requirement rules out. -/
theorem the_empty_renderer_collapses_everything (m₁ m₂ : Msg) :
    render [] m₁ = render [] m₂ := by rfl

/-- The coverage requirement, stated as the checkable rule: every field appears in the renderer.
This is what the checker executes against the real `toString`. -/
def coversEveryField (covered : List Field) : Bool :=
  allFields.all (fun f => covered.contains f)

theorem the_full_renderer_covers_everything : coversEveryField fullRenderer = true := by decide

theorem the_lossy_renderer_does_not : coversEveryField lossyRenderer = false := by decide

/-- **Coverage is exactly what buys injectivity here** — the bridge between the rule the checker
can test and the property that matters. -/
theorem coverage_implies_the_pair_is_separated (covered : List Field)
    (h : coversEveryField covered = true) :
    render covered ⟨1, 2, 3, 4, 5, 6⟩ ≠ render covered ⟨1, 2, 3, 4, 99, 6⟩ := by
  intro hEq
  have harg2 : covered.contains Field.arg2 = true := by
    have := List.all_eq_true.mp h Field.arg2 (by decide)
    exact this
  have hmem : Field.arg2 ∈ covered := by
    simpa using harg2
  have := List.mem_map_of_mem (f := valueOf (⟨1, 2, 3, 4, 5, 6⟩ : Msg)) hmem
  rw [show (List.map (valueOf (⟨1, 2, 3, 4, 5, 6⟩ : Msg)) covered)
        = render covered ⟨1, 2, 3, 4, 5, 6⟩ from rfl, hEq] at this
  simp [render] at this
  obtain ⟨g, hg, hgv⟩ := this
  cases g <;> simp [valueOf] at hgv

#guard coversEveryField fullRenderer == true
#guard coversEveryField lossyRenderer == false
#guard render fullRenderer ⟨1, 2, 3, 4, 5, 6⟩ == [1, 2, 3, 4, 5, 6]
#guard render lossyRenderer ⟨1, 2, 3, 4, 5, 6⟩ == render lossyRenderer ⟨1, 2, 3, 4, 99, 6⟩
#guard render fullRenderer ⟨1, 2, 3, 4, 5, 6⟩ != render fullRenderer ⟨1, 2, 3, 4, 99, 6⟩
#guard allFields.length == 6

end CtbrecSpec
