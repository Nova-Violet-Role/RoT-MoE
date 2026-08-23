<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# The probe that could not hear its subject

*On negative controls in suites that post-process the thing they measure.*

---

## Abstract

A verification suite that audits an interactive system must eventually ask whether the
system's output reaches its consumer. The natural instrument is an echo probe: ask the
subject to repeat a known token, then read the subject's output stream and count
occurrences. A negative control — the same prompt with the mechanism disarmed — is
supposed to establish that any count is attributable to the mechanism.

This paper reports a measured case in which the echo probe was correct in construction,
correct in its reasoning about which stream to read, honest in its refusal to declare
success, and nevertheless produced a verdict about the wrong component. Between the
subject's answer and the probe's reader stood a third component installed by the same
project: a Stop hook that replaces model output with nine fixed stanzas. Both arms of the
control therefore read zero. The suite reported the wiring broken. The wiring worked.

We give the measurement, formalise the failure in Lean 4 as ten axiom-free theorems, show
that the defect is *not* an instance of the previously catalogued family in which an
instrument damages its subject, and derive a general law: a probe reads a channel, never a
subject, and whoever writes that channel last is what the verdict is about. We also record
an uncomfortable corollary surfaced by the Lean linter — the gate's honesty in this case
was unconditional, and therefore not discernment.

---

## 1. The measurement

Branch `9.0.0`, 2026-08-19. `checker/live-session-smoke.sh` phase 3 is the only instrument
in this repository that attempts to establish *delivery to the model* rather than *hook
execution*. Its design intent is recorded in the source and is exactly right
(`checker/live-session-smoke.sh:505-508`):

> THE VERDICT READS THE MODEL'S STREAM, NOT THE HOOK'S. A hook firing into a void writes
> the debug line either way; only stdout carries what the model actually received and
> repeated back.

The prompt (`checker/live-session-smoke.sh:430`):

> Output verbatim, and nothing else, the single line in your context that begins with the
> characters `'RoT MoE ::'`. If no such line exists, output exactly `NO-SUCH-LINE`.

Measured outcome:

| Quantity | Value |
|---|---|
| hook firings into the armed context | 6 |
| marker count, model stdout, **armed** | 0 |
| marker count, model stdout, **disarmed** | 0 |
| model stdout produced | 1758 bytes, 17 lines |
| gate verdict | FAIL, twice |
| gate exit | 1 |

The 1758 bytes are not empty and not an error. They are nine `<rot:*>` stanzas emitted by
this project's Stop hook. The subject's actual answer is not among them.

## 2. Why the delivery nevertheless succeeded

The subject's reply is self-refuting in a way that settles the question. Two stanzas
assert an emission that is absent from the file on disk:

> `<rot:soleil>` "Emitted the R/s+ 0.19 line. One line, no commentary."
>
> `<rot:antivenom>` "the emitted string matches the UserPromptSubmit hook line character
> for character, including the bracketed roster and the trailing gauge value."

But the reply also *names both competing banner lines and their distinct gauge values*,
0.17 and 0.19, and explains which it chose and why. That content is not derivable without
having received them. Delivery therefore occurred; only the readback was lost.

A third stanza, written by the probe's own subject and unprompted, states the finding
before the auditor did:

> `<rot:carnage>` "A test for verbatim recall, answered inside a context that keeps
> printing new candidates for the same pattern — the instrument contaminates its own
> sample."

## 3. Core content: what class of defect this is

The catalogue in `COMPENDIUM-instrument-defects.md` already contains a family named *the
instrument damages what it measures* (Family 6). This is not that, and the distinction
carries the engineering consequence.

In Family 6 the **gate is the actor**. It stages, packages, mutates or cleans, and its own
writing destroys the evidence or ships something unchecked. The repair is to stop the gate
writing.

Here the gate writes nothing whatsoever, invokes nothing unusual, and its reader is
correct: it counts exactly the bytes present on the stream it was told to read. The damage
occurs **upstream of reading**, performed by a component that the gate does not model, did
not invoke, and cannot see — but which the *project* installed. The repair is not to the
gate's writing but to its choice of channel.

The general shape, stated so it transfers: whenever a project post-processes the output of
the subject it audits, every exact-output probe in that project is measuring the
post-processor. This is filed as **Family 9 — the subject cannot answer in its own voice**.

## 4. The theorem

`lean/Proofs/RotObserverEffect.lean`. Ten theorems, `lake build` exit 0, `#print axioms`
reports all ten depend on no axioms, `leanchecker` exit 0, three mutants killed
(10 / 4 / 4 elaboration errors respectively).

A session carries two independent facts — whether the banner was `delivered` into context,
and whether the model `echoed` it. The voice contract is modelled as a function that
ignores its argument, because that is precisely the property that is fatal:

```lean
def voiceContract (_raw : Bool) : Bool := false
def observedStream (s : Session) : Bool := voiceContract (rawStream s)
```

The central result is not that the probe reads zero. It is that the probe reads *the same
value for every pair of sessions*, so the negative control compares two numbers equal by
construction:

```lean
theorem the_control_is_symmetric (a b : Session) :
    observedStream a = observedStream b := rfl
```

with the consequence that no session pair is ever attributable, including one in which
delivery and echo both succeeded:

```lean
theorem perfect_delivery_still_reads_red : attributable perfect silent = red := rfl
```

The generalisation removes every reference to this repository. For an arbitrary reader
`f` that ignores its input, every control is flat:

```lean
theorem an_input_independent_reader_flattens_every_control
    (f : Bool → Bool) (hf : ∀ x y, f x = f y) (a b : Session) :
    f (rawStream a) = f (rawStream b) := hf _ _
```

The contrapositive is the operationally useful direction, and the one worth carrying out
of this document:

```lean
theorem a_control_that_fires_proves_the_channel_is_live
    (f : Bool → Bool) (a b : Session)
    (h : f (rawStream a) ≠ f (rawStream b)) :
    rawStream a ≠ rawStream b
```

*If a control ever fires, the channel was not overwritten.* A control that fires is
evidence about the apparatus, not merely about the subject.

The repair reads the hook's own log, which the contract does not rewrite, and is checked
in both directions — it separates the arms, and it still refuses a channel that is dead in
both:

```lean
theorem the_repair_separates_the_arms : attributableFixed perfect silent = green := rfl
theorem the_repair_still_refuses_a_dead_channel : attributableFixed silent silent = red := rfl
```

A final theorem records what the repair does **not** buy, so the weaker claim is never
banked as the stronger one: `the_repair_ignores_the_echo` proves the repaired verdict is
invariant under swapping the echo bits. It establishes that the banner was delivered. It
says nothing about whether the model read it. Delivery and comprehension are two facts,
and only the first survives a rewriting contract.

## 5. The uncomfortable corollary

`honest_refusal_on_a_symmetric_control` was written to credit the gate for refusing rather
than guessing. The Lean linter then reported that its symmetry hypothesis is never used.

The refusal is unconditional. This reader returns red on every input whatsoever. The gate
was right, but not for the reason the theorem was named after — its correctness here is
the same blindness seen from the other side. An instrument that *cannot* return green is
not discerning, and the fact that its output happened to be the correct verdict is an
accident of the defect rather than a property of the design.

This is retained in the source with the hypothesis prefixed `_h` and a comment explaining
why it is kept. Deleting it would have made the file tidier and the record worse.

## 6. Thesis

> **A probe reads a channel, never a subject. Whoever writes that channel last is what the
> verdict is about.**

Three consequences follow, and each is checkable today:

1. **Equal arms are not a weak result; they are the absence of a channel.** A negative
   control whose two arms return the same number — above all the same zero — has not
   measured a weak effect. It has measured nothing, and it must say so. Zero-versus-zero
   is the signature.

2. **Enumerate everything between subject and reader, and ask which of them is yours.**
   The dangerous rewriters are not third-party surprises. They are the components the
   project installed deliberately, which is exactly why nobody lists them when reasoning
   about a probe.

3. **A control that fires is evidence about the apparatus.** It proves the channel is
   live. A suite should therefore treat a never-firing control as an open defect rather
   than as background quiet — which is the standing law that a control must be exercised,
   now extended: it is not enough that the control *could* fire in principle, it must fire
   against the same channel production reads.

The suite found this defect by refusing to call an ambiguous result a pass. That refusal —
not the sophistication of the probe — is the only reason the finding exists. The cost of
the refusal was a red gate for one run. The cost of its absence would have been a green
gate certifying a delivery path nobody had ever observed.

---

*Companion documents: `COMPENDIUM-instrument-defects.md` (Family 9),
`ESSAY-what-a-green-gate-is-worth.md`, `PAPER-the-cost-of-a-verdict.md`.
Formalisation: `lean/Proofs/RotObserverEffect.lean`.*
