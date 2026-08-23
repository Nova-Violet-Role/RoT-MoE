<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# The Cost of a Verdict

*How many times an instrument must be watched before its answer means anything, and what a
short circuit destroys.*

---

## Abstract

A test suite reports a colour. This paper asks what that colour is worth, and answers it as a
counting problem rather than a matter of engineering taste. Model a gate as a function from the
state of the world to a verdict, and call it vacuous when it returns the same verdict in every
state. A vacuous gate is not a weak check; it is not a check. The central result is that a
single observation of a gate — one control run, one deliberate break, one clean-tree
confirmation — can never establish that the gate is non-vacuous, and this holds for **every**
choice of world observed and **every** verdict observed. It is not a defect in a particular
control that a better-chosen control would fix. Two observations, at the two distinct states,
always suffice and in fact determine the gate completely, so the bound is tight at two. The
second half of the paper concerns composition, and reverses the usual intuition: because a real
hook chain stops at its first failure, a gate that answers red in every state renders the entire
suite behind it vacuous, however informative its members are in isolation. Adding a check cannot
create information; adding a broken check destroys it. Both halves are proved in Lean 4 in
`lean/Proofs/RotGateObservation.lean`, 15 theorems, no `sorry`, no `native_decide`, kernel-rechecked,
and three mutations confirm the statements are load-bearing. The repository holds 1710 theorems
across 93 modules and 82 checkers at the time of writing; this paper claims nothing about how
many of those gates are vacuous, because that is a measurement, and measuring it is what the
controls are for.

---

## 1. The question, stated so it has an answer

The predecessor essay, `docs/ESSAY-what-a-green-gate-is-worth.md`, argued that a green banner
reports a property of the suite and not of the repository. It made the argument well enough to
be convincing and left the interesting part unproved. Its strongest formal move was
`sound_does_not_imply_live`: a gate that goes red when you break the thing it checks may still be
worthless, because the always-red gate does that too. Read carelessly, that is a fact about one
badly-written gate. The real question hides underneath it and is much sharper:

> Given that I have run a control and seen a verdict, what have I learned?

This is answerable because the space is small enough to count. The world has two states — the
checked property holds, or it does not. The instrument returns one of two verdicts. A gate is
then a function between two-element sets, and there are exactly four of them: constantly green,
constantly red, honest, and inverted. Vacuity is the property of being one of the two constants.

The counting question is now precise. An observation is a pair: a state you put the world into,
and the verdict that came back. How many observations separate the two constant gates from the
two non-constant ones?

## 2. The lower bound: one observation is worth nothing

Fix any state `e` and any verdict `v`. Consider two gates. The first answers `v` no matter what;
call it flat. The second answers `v` in state `e` and the opposite verdict in the other state;
call it pinned. Both reproduce the observation exactly. One is vacuous, the other provably is
not. So the observation is consistent with both and has not narrowed the space at all.

The quantifier order is the whole content. It would be a mild result to say *there exists* an
observation that fails to decide. The theorem says: for **all** states and **all** verdicts, a
counterexample pair exists. No cleverness in choosing which world to plant, and no luck in which
colour comes back, escapes it — because the construction is parameterised by exactly those two
choices and defeats each one.

This is why the discipline that this repository arrived at painfully is not a style preference.
Breaking the checked thing and watching the gate go red feels like verification. It is one
observation. Considered alone, its information content about vacuity is zero, and that is now a
theorem rather than a caution.

## 3. The upper bound: two observations are worth everything

The complementary result is that the two endpoint observations settle the matter completely. A
gate is vacuous exactly when its verdict in the holding state equals its verdict in the failing
state, which is decidable from those two readings and nothing else.

The sharper form goes further than vacuity: two agreeing observations pin down the function
itself, not merely its constancy. Two gates that agree on both states are equal. There is
therefore nothing a third observation could learn — the experiment is not merely sufficient, it
is exhaustive, and the bound is tight from both sides at two.

The pair of results has a clean operational reading. Trip the control, then confirm the clean
tree. That is the minimal sufficient experiment, minimal because one is provably not enough, and
sufficient because two provably are. The repository's own controls follow this shape, and the
recently-added citation-surface controls follow it deliberately: each plants a document that
must be seen, and one that must not be, and both were mutated to confirm each can fail
independently of the other.

## 4. Composition, and the surprise

The predecessor established that a suite of vacuous gates is vacuous — that stacking useless
checks produces a useless suite, and that a green banner over 47 of them is worth what the worst
of them is worth. That is a statement about the *absence* of a good gate.

This paper adds the statement about the *presence* of a bad one, and it is stronger than
expected. A suite in this model stops at the first red, which is what a hook chain does under
shell error-exit semantics and what a pre-commit chain does in practice. That operational detail
has a consequence that is easy to miss: a gate answering red in every state makes the entire
remaining suite vacuous. Not degraded — vacuous, in the full sense, returning an identical
verdict in every state of the world.

The minimum-size witness is worth stating because it removes any suspicion of a technicality.
The honest gate is provably non-vacuous. The two-element suite consisting of the always-red gate
followed by the honest gate is provably vacuous. The honest gate was not weakened, rewritten, or
misconfigured. It was never reached.

The contrapositive is the version to hold in the hand: if a suite's verdict means anything at
all, then no member answers red in every state. So discovering one always-red gate is not a
local bug report affecting one line of the summary. It invalidates the verdict of everything
downstream of it, and in a chain that short-circuits, "downstream" is most of the suite.

There is a final corollary that closes the door on the comforting version of this. One might
hope that a suite containing at least one real check retains at least some information. It does
not: there exists a suite containing a provably non-vacuous gate that is nonetheless vacuous.
"At least one of our checks is real" is not a property of the suite.

## 5. The theorem

The central result, stated formally as it appears in the source:

```lean
theorem one_observation_is_never_enough (e : Evidence) (v : Verdict) :
    ∃ g₁ g₂ : Gate, g₁ e = v ∧ g₂ e = v ∧ Vacuous g₁ ∧ ¬ Vacuous g₂
```

*For every state of the world and every verdict, there are two gates that both produce that
verdict in that state, of which one is vacuous and one is not.*

Its companion, which makes the bound tight:

```lean
theorem two_observations_are_always_enough (g : Gate) :
    Vacuous g ↔ g present = g absent
```

And the composition result:

```lean
theorem a_red_prefix_blinds_everything_after_it
    (g : Gate) (hred : ∀ e : Evidence, g e = red) (rest : Suite) :
    Vacuous (run (g :: rest))
```

Supporting and dependent results in the same module: `observations_determine_the_gate`,
`both_observations_give_informative`, `a_meaningful_suite_has_no_red_prefix`,
`containing_an_informative_gate_does_not_save_a_suite`, `pin_not_vacuous`, `flat_vacuous`,
`otherWorld_ne`, `otherVerdict_ne`, `pin_at`, `pin_off`, `flat_at`.

The model itself, and the prior results this one builds on — `suite_of_vacuous_is_vacuous`,
`green_gates_prove_nothing`, `one_honest_gate_is_not_vacuous`, `informative_not_vacuous`,
`sound_does_not_imply_live`, `live_does_not_imply_sound`, `distinguishes_iff_not_vacuous`,
`vacuous_iff_constant` — live in `lean/Proofs/RotVacuousGate.lean`.

## 6. Thesis

> **A verdict is worth exactly the number of distinct world-states in which its instrument was
> actually observed. That number is one less than people believe, it cannot be raised by adding
> gates, and a single always-red member drives it to zero for every gate behind it.**

Three commitments follow from this, and they are the reason the paper exists rather than the
theorems alone.

**First, a control is an experiment, not a ritual.** Its value is the pair of readings, not the
act of having one. A control that only ever runs in the broken direction has performed half an
experiment and licenses no conclusion about vacuity. Every control this repository ships is
therefore required to be tripped in both directions, and the requirement is not politeness about
rigour — it is the minimum at which the reading becomes information.

**Second, a suite's verdict is not a summary of its members.** It is a function of the first
failing one. Reporting "56 gates green" describes the members; it does not describe what was
observed, because the short-circuit means most members may have contributed nothing to the
colour. The banner and the roster are different objects and this paper proves they can come
apart completely.

**Third, the dangerous failure is silent by construction.** A vacuous gate is indistinguishable
from a working one at any single observation — that is precisely the lower bound. It follows
that vacuity cannot be noticed by watching the suite behave normally, no matter how long you
watch. It can only be found by an experiment designed to find it. This is why an alarm nobody
has deliberately tripped is not an alarm, and why the eight-family taxonomy in
`docs/COMPENDIUM-instrument-defects.md` keeps producing the same shape of finding: each family
is a place where one direction of one experiment was never run.

## 7. What this paper does not establish

Stated plainly, because the alternative is to write a paper about vacuity that is itself an
unfalsified claim.

The model has two world-states. Real gates read a repository with an enormous state space, and
the reduction to two is a modelling decision made by hand. It is defensible — the relevant
distinction really is "the checked property holds" versus "it does not" — but it is a decision,
not a derivation, and nothing checks that a given real gate respects it.

The mapping from any specific checker in `checker/` onto a gate in this model is hand-done and
verified by nobody. The theorems say what follows *if* the mapping holds. No instrument asserts
that it does for any particular file.

Nothing here measures how many gates in this repository are currently vacuous. The claim that
the number is zero would be a measurement, and it has not been made in this form. What exists
instead is a growing set of controls, each of which establishes the two-observation bound for
one gate. That is the correct instrument for the question and it is incomplete by construction:
it covers exactly the gates that have controls, and the coverage is what should be reported,
not the conclusion.

The composition result assumes the suite short-circuits. The repository's own aggregate runner
does not — it runs every gate and counts — so the blinding result applies to the pre-commit
chain and to shell error-exit paths rather than to that runner. Which real chains short-circuit
is, again, measured by reading them, and no gate asserts the answer.

---

## Citations

**Toolchain.** `lean/lean-toolchain` pins `leanprover/lean4:v4.33.0-rc1`; the shared proof tree
on the authoring machine pins the same version. Both built the module.

**Instruments, three, in order.** Elaboration: `lake build Proofs.RotGateObservation` exit 0,
455 ms, built first attempt. Axioms: eight results printed; `one_observation_is_never_enough`
and `two_observations_are_always_enough` depend on `propext`;
`observations_determine_the_gate` depends on `Quot.sound`, inherited from function
extensionality; the remaining five depend on no axioms at all. Kernel re-verification:
`lake env leanchecker Proofs.RotGateObservation` exit 0, zero bytes of output.

**Mutations, three, each killed.** Collapsing the pinned gate to a constant kills
`pin_not_vacuous` at line 93 — the non-vacuous witness is load-bearing. Claiming a *green*
prefix blinds the suite produces six errors starting at line 151 and cascading into three
dependent theorems, confirming that redness specifically, not merely constancy, is what
short-circuits. Comparing the holding state against itself in the upper bound kills it at line
121. All three restored byte-identical; final build exit 0.

**Delivery.** Copied into the shared proof tree's RotMoe subtree, cross-module import rewritten,
rebuilt there at exit 0 and kernel-rechecked at exit 0. That tree now holds 95 modules from this
project.

**A gate caught this paper.** The first commit attempt was refused. The machine-local path
checker found two absolute paths in the citations above, where earlier drafts named the delivery
target literally. The document was rewritten rather than allowlisted, on the principle that
exempting must be a visible act with a reason and there was no reason here — a published paper
has no business carrying the author's drive letters. Recorded because it is the paper's own
thesis arriving unannounced: that gate was observed in both directions today, red on the planted
fault and green on the clean tree, which is exactly the two-observation experiment section 3
argues is the minimum.

**And a second instance, sharper than the first.** In the same refused run, the path gate's
archive sweep reported the shipped archives clean. It runs third of fifty-five. The local-only
packager runs near the end, was triggered by the same commit's staged paths, and rebuilt those
archives from the tree as it stood — which still contained the two absolute paths. So the sweep's
green was true when it was made and false by the time the run printed its summary, and a
standalone re-run afterwards found three archives red that the suite had just declared clean.
Nothing here is a defect in either gate: each answered correctly about the state it observed.
The lesson is the one this paper is about, in its least comfortable form — a suite verdict is a
statement about the moment of observation, and a suite that mutates its own inputs mid-run can
be internally consistent and still describe a tree that no longer exists. Regenerating the
archives from the corrected tree returned the gate to exit 0. The ordering itself is left as
measured, not fixed: changing gate order is a separate change and would need its own control.

**Repository state at the time of writing.** 1710 theorems across 93 Lean modules; 82 checkers;
68 commits on branch 9.0.0. The 15 new theorems account exactly for the movement from 1695.

**Predecessors.** `docs/ESSAY-what-a-green-gate-is-worth.md` for the argument this paper
formalises; `docs/COMPENDIUM-instrument-defects.md` for the eight-family taxonomy of real
findings; `lean/Proofs/RotVacuousGate.lean` for the model and the composition result this one
extends.
