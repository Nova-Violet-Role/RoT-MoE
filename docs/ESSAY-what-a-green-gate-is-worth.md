<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# What a green gate is worth

> A gate that cannot fail is not a gate. It is a decoration with an exit code.

## I. The banner

Every commit on this branch ends the same way. The pre-commit hook runs the
suite, the suite prints a line, and the line says something like `ALL 47 GATES
GREEN`. It is a satisfying thing to read. It is also, on its own, almost
entirely without content, and the twenty-five findings on this branch are
twenty-five different ways of discovering that.

The banner reports a property of the suite. The thing anyone actually wants to
know is a property of the repository. Those two coincide only under a condition
that nobody was checking, and for most of this branch's history the condition
was false somewhere in the tree at all times.

## II. Twenty-five findings, one shape

`COMPENDIUM-instrument-defects.md` sorts the findings into seven families:
a gate registered in one place and executed in none; a skip or a missing tool
read as a pass; agreement asserted between two things that had no way to
disagree; prose standing in for an assertion; a claim with a checker but no
author; an instrument that damages the thing it measures; and evidence pointing
at the wrong object.

Seven families is a useful filing system and a poor explanation. The families
are not seven mechanisms. They are seven places where the same question was
never asked:

> What would this instrument do if the thing it checks were absent?

In all seven, the answer is green. The gate registered in no workflow is green
because it never ran. The skipped gate is green because a skip and a pass left
the same trace. The comparison between two arms is green because both arms came
from the same source. The prose bound is green because prose does not execute.
None of these is a bug in the sense of a wrong branch or an off-by-one. Each is
a function that ignores its argument.

That is a small enough idea to state exactly, so this branch now states it
exactly. `lean/Proofs/RotVacuousGate.lean` models a gate as the only thing that
matters about it: a function from a world — the evidence it checks is `present`
or `absent` — to a `green` or `red` verdict. Everything else about a real
checker, the shell, the exit codes, the temporary files, is scenery.

## III. Breaking it on purpose is half a test

The received wisdom is right as far as it goes: to trust an alarm, make it fire.
Plant a bad file, watch the gate go red, remove it, commit. This branch has done
that dozens of times and it is the reason the good gates are good.

It is also, exactly, half of a test, and the missing half is the more
embarrassing one to omit. A gate that answers red to everything passes the
break-it-and-watch test perfectly. It rejects the planted file. It also rejects
the clean tree, which nobody noticed because nobody ran it on a clean tree
*after* trusting it. `sound_does_not_imply_live` exhibits that gate and proves
it is still vacuous; `live_does_not_imply_sound` exhibits the mirror image, the
gate that passes everything, and proves the two halves are independent. Neither
half implies the other, so a control that exercises one of them establishes
nothing about the other.

This is not hypothetical bookkeeping. `checker/repo-complete.sh` prints, on
every run, a control line reading *a TRUE mutant count is accepted — the check
does not simply reject everything*. That line exists because the second half was
once missing. The theorem is what that control line means.

The general form is `distinguishes_iff_not_vacuous`: a gate carries information
exactly when it answers differently in the two worlds. "Can this alarm fire?"
and "does this alarm mean anything?" are not two questions with two answers.
They are one question, and a control that only proves the alarm *can* fire has
answered it halfway.

## IV. Why forty-seven of them is not better than one

The instinct when a suite is untrustworthy is to add gates. It feels like
insurance: any one of them might be blind, but surely not all of them, and the
count itself starts to read as evidence. Forty-seven green gates sounds
overwhelmingly more convincing than one.

It is not more convincing. It is exactly as convincing, and
`suite_of_vacuous_is_vacuous` is the proof. Gates compose the way the real suite
composes — run in order, first red wins, the empty suite green — and the theorem
says that a suite assembled entirely from vacuous gates is itself vacuous, at
any length. Composition manufactures no information. There is no number of
meaningless checks that becomes a meaningful one by being adjacent.

`green_gates_prove_nothing` states the same fact in the form it is actually
encountered. If every gate is vacuous and the suite is green on the tree you
have, then it is green on no tree at all — on an empty repository, on a deleted
checkout, on nothing. The verdict was never about the tree. Under that
hypothesis the banner is a fact about the suite and a fact about nothing else.

The escape is single and narrow: `one_honest_gate_is_not_vacuous`. One gate that
answers differently in the two worlds is not in the set the theorem quantifies
over, and its presence is the entire difference between a suite that means
something and a suite that means nothing. Not the count. The controls.

Which inverts the instinct completely. Adding a forty-eighth gate is worth
nothing. Tripping a control on one of the forty-seven is worth everything, and
this is why every gate on this branch is now required to carry a control that
has been deliberately tripped and observed to go red — and, since section III, to
have been observed to go green afterwards on the untouched tree.

## V. What it cost to learn

The uncomfortable part of the record is how the findings were actually made.

The workflow-lint defect was found because a checker's basename happened to
appear inside an `echo` in a log message at `.github/workflows/ci.yml:1329`. The
gate declared that checker wired into CI. The checker in question was the one
whose own exemption argues at length that CI must never run it. A sentence
blessed a checker, and the exemption logic guarding it had been dead code
nothing had ever reached.

The SPDX defect was found because a scheduler wrote a lock file ninety seconds
before a commit, which reddened the suite, which forced a third attempt, which
was the first run to exercise a path two prior commits had skipped. Nobody
designed that. A background process on an unrelated schedule did the auditing.

The point is not that luck helped. The point is that in both cases the gate had
been green for months over territory it did not cover, and the thing that
finally moved was an accident. An instrument that is only falsified by accident
has no falsification schedule at all, which is the same as having none.

## VI. The question, in practice

The audit checklist in the compendium is nine questions long, and every one of
them descends from a defect that shipped. But they compress to a single habit,
applied before writing any assertion:

Delete the thing being checked, in your head, and ask what the instrument
prints. If the answer is green — or if the answer is *I would have to run it to
know* — the instrument is not finished. It needs the world where its evidence is
absent, and it needs that world to have been visited on purpose, with the red
observed by a human, and the green observed afterwards on the clean tree.

Everything else in the checklist is that question wearing different clothes for
different families.

## VII. What is still prose

This essay would be a poor citizen of its own argument if it did not answer its
own question. It failed that test once already, during its own drafting.

When the first draft was staged, the theorem names cited in section III and
section IV resolved to nothing. Not because the theorems were absent — they were
built and kernel-rechecked — but because the checker that validates cited
theorem names, `checker/repo-complete.sh`, took its file list from a
hand-written string of six paths written long before this document existed. The
count of validated citations did not move when the essay was added. The essay
was exempt by default, and nothing anywhere said so.

That is the first family in the compendium, arriving in the validator of the
essay about it, in the same hour. The surface is now every `docs/*.md` minus
history, so a document is covered the moment it exists; two controls assert it,
one proving a new file is inside the surface and one proving a `SCRUTINY-*` log
stays outside, and both have been tripped on purpose and observed to fail.
Widening the scope also forced the extractor's imprecision into the open: it
matches any backticked snake_case word, so shell function names and JSON keys
had to be named as non-theorems rather than hidden behind a narrow scope.

With that fixed, what remains unasserted:

The claim that all seven families reduce to the vacuity question is an argument,
not a theorem — the model proves what follows *if* a gate is vacuous, and proves
that composition preserves it, but the mapping from each real defect onto that
model was done by hand and is checked by nobody. The measured statement that
zero gates in this repository are currently vacuous is measured, not proved, and
it was measured by the controls, which is to say by the very instruments under
suspicion. The wall-clock series that shows every commit breaching the 240-second
pre-commit ceiling is recorded in prose in two documents and generated by
nothing.

These are named here rather than omitted, on the same principle that put the
compendium's self-classification in the compendium: an argument about instruments
that exempts itself from its own question is one more instrument that returns
green when its evidence is absent.

## Citations

Every theorem named above lives in `lean/Proofs/RotVacuousGate.lean`, built under
`leanprover/lean4:v4.33.0-rc1`, kernel-rechecked with `leanchecker`, and mutated:
trivialising the definition of `Vacuous` kills six of them, flipping the
conclusion of `green_gates_prove_nothing` kills it, and letting the honest gate
accept absent evidence kills `honest_informative`. Zero `sorry`. No
`native_decide`. The axioms are `propext` or none.
