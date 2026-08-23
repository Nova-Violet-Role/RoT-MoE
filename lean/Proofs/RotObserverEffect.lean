/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

  RotObserverEffect -- a probe that reads a channel its own subject rewrites
  measures the rewriter, not the subject.

  MEASURED, 2026-08-19, branch 9.0.0. `checker/live-session-smoke.sh` phase 3
  asks whether the router's banner actually REACHES the model, as opposed to
  merely being printed by a hook into a void. Its method is direct and, on its
  face, correct: spawn a real session with the router armed, and send

    checker/live-session-smoke.sh:430
    "Output verbatim, and nothing else, the single line in your context that
     begins with the characters 'RoT MoE ::'. If no such line exists, output
     exactly NO-SUCH-LINE."

  then count occurrences of the marker in the MODEL's own stdout, and repeat
  with the router disarmed as a negative control. The reasoning recorded at
  checker/live-session-smoke.sh:505-508 is explicit and right:

    "THE VERDICT READS THE MODEL'S STREAM, NOT THE HOOK'S. A hook firing into
     a void writes the debug line either way; only stdout carries what the
     model actually received and repeated back."

  The measured outcome:

    hook firings into the armed context      6
    marker count in the model's stdout       0   (armed)
    marker count in the model's stdout       0   (disarmed)
    verdict                                  FAIL, twice
    stdout bytes produced by the model    1758   (17 lines)

  The gate reported the wiring broken. The wiring was not broken. The 1758
  bytes are NINE <rot:*> stanzas emitted by this project's own Stop hook, and
  two of them describe the answer that never arrived:

    <rot:soleil>  "Emitted the R/s+ 0.19 line. One line, no commentary."
    <rot:antivenom> "the emitted string matches the UserPromptSubmit hook line
                     character for character, including the bracketed roster
                     and the trailing gauge value."

  Both statements are false about the stream that exists on disk. A third is
  true, and it was written by the probe's own subject, unprompted:

    <rot:carnage> "A test for verbatim recall, answered inside a context that
                   keeps printing new candidates for the same pattern -- the
                   instrument contaminates its own sample."

  So the delivery under test DID occur -- the model names both competing
  banners and their distinct gauge values, 0.17 and 0.19, which it could only
  do by having received them. What failed is the READBACK: an unconditional
  post-processor stands between the model's answer and the probe's grep, and
  that post-processor is part of the same project the probe is auditing.

  WHY THIS IS NOT THE SWALLOWING FAMILY. A swallowed failure is a real signal
  discarded on the way to the verdict. Here no signal is discarded: the probe
  reads exactly the bytes that exist. The defect is upstream of reading --
  the channel itself was overwritten before the probe ever looked, by a
  component the probe does not model. The instrument is honest, its reader is
  correct, and its verdict is still about the wrong thing.

  WHAT THE GATE GOT RIGHT, AND IT MATTERS. Faced with armed=0 and disarmed=0
  it printed "delivery NOT attributable" and returned FAIL. It did not read a
  symmetric control as a pass. `honest_refusal_on_a_symmetric_control` below
  is the theorem for that behaviour, and it is the reason this defect was
  visible at all rather than sitting green forever.

  The repair is not to weaken the probe. It is to read a channel the contract
  does not rewrite, while KEEPING the stdout read as the strong claim -- see
  `the_repair_separates_the_arms` and, immediately after it, the theorem that
  the repair still refuses a dead channel.
-/

import Proofs.RotVacuousGate

namespace RotMoE.Observer

open RotMoE.Vacuity
open Verdict

/-- One probe session. `delivered` is the fact under test: the banner reached
    the model's context. `echoed` is what the model itself produced in answer.
    They are independent -- a model can receive and not echo, which is exactly
    the case that was measured. -/
structure Session where
  delivered : Bool
  echoed    : Bool
deriving DecidableEq, Repr

/-- What the model actually wrote, before anything downstream touches it. -/
def rawStream (s : Session) : Bool := s.echoed

/-- The voice contract. It emits its nine stanzas regardless of what the model
    answered, and the answer does not survive into the stream the probe reads.
    Modelled as a constant function, because that is precisely what makes it
    fatal: it ignores its input. -/
def voiceContract (_raw : Bool) : Bool := false

/-- What the probe greps. -/
def observedStream (s : Session) : Bool := voiceContract (rawStream s)

/-- The probe cannot see the token under ANY session -- including one where the
    model received the banner and echoed it perfectly. -/
theorem the_probe_can_never_see_the_token (s : Session) :
    observedStream s = false := rfl

/-- Stronger, and this is the real content: the reading is the same for every
    pair of sessions. A negative control compares two numbers that are equal by
    construction, so it can never separate anything. -/
theorem the_control_is_symmetric (a b : Session) :
    observedStream a = observedStream b := rfl

/-- The probe's verdict: green only when the armed arm shows the marker and the
    disarmed arm does not. -/
def attributable (armed disarmed : Session) : Verdict :=
  if observedStream armed && !observedStream disarmed then green else red

/-- No pair of sessions whatsoever is attributable through this reader. -/
theorem no_pair_is_attributable (a b : Session) : attributable a b = red := rfl

/-- A session in which delivery and echo both succeeded. -/
def perfect : Session := ⟨true, true⟩

/-- A session in which nothing happened at all. -/
def silent : Session := ⟨false, false⟩

/-- Perfect delivery against a perfectly silent control still reads red. This
    is the measured run: the wiring worked and the gate said FAIL. -/
theorem perfect_delivery_still_reads_red : attributable perfect silent = red := rfl

/-- Refusing a symmetric control is the CORRECT behaviour, not a second bug.
    A reader that returned green here would have hidden the defect forever.

    NOTE, and the linter is what surfaced it: the symmetry hypothesis `_h` is
    never used. The refusal is UNCONDITIONAL -- this reader returns red on
    every input, so its honesty here is not discernment, it is the same
    blindness seen from the other side. The hypothesis is retained to document
    the case that was measured, prefixed to record that it does no work. An
    instrument that is right for a reason it does not possess is still right,
    and still needs repairing. -/
theorem honest_refusal_on_a_symmetric_control (a b : Session)
    (_h : observedStream a = observedStream b) :
    attributable a b = red := by
  unfold attributable
  rw [the_probe_can_never_see_the_token a, the_probe_can_never_see_the_token b]
  rfl

/-- THE GENERAL LAW, stated for an arbitrary reader rather than this one.
    Any post-processor that ignores its input makes every control symmetric.
    Nothing about stanzas, banners or this repository enters the proof. -/
theorem an_input_independent_reader_flattens_every_control
    (f : Bool → Bool) (hf : ∀ x y, f x = f y) (a b : Session) :
    f (rawStream a) = f (rawStream b) := hf _ _

/-- Contrapositive, and the one that tells you what to build: a reader that
    separates two sessions is necessarily sensitive to its input. If your
    control ever fires, the channel was not overwritten. -/
theorem a_control_that_fires_proves_the_channel_is_live
    (f : Bool → Bool) (a b : Session)
    (h : f (rawStream a) ≠ f (rawStream b)) :
    rawStream a ≠ rawStream b := by
  intro heq
  exact h (congrArg f heq)

/-- The repair: read the hook's own log, which the voice contract does not
    rewrite, and keep it as a SEPARATE channel rather than replacing stdout. -/
def hookLog (s : Session) : Bool := s.delivered

def attributableFixed (armed disarmed : Session) : Verdict :=
  if hookLog armed && !hookLog disarmed then green else red

/-- The repaired reader separates the arms that the original could not. -/
theorem the_repair_separates_the_arms : attributableFixed perfect silent = green := rfl

/-- And it has not merely been loosened into always-green: a channel that is
    dead in both arms is still refused. -/
theorem the_repair_still_refuses_a_dead_channel :
    attributableFixed silent silent = red := rfl

/-- The repaired reader is still blind to the echo -- it proves the banner was
    delivered, NOT that the model read it. Recorded so the weaker claim is not
    quietly banked as the stronger one. Delivery and comprehension are two
    facts, and only the first survives a rewriting contract. -/
theorem the_repair_ignores_the_echo (d e f : Bool) :
    attributableFixed ⟨d, e⟩ ⟨false, f⟩ = attributableFixed ⟨d, f⟩ ⟨false, e⟩ := rfl

end RotMoE.Observer
