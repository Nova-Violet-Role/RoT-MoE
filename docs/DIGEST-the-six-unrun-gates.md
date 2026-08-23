<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# Digest: the six gates that had never run

*Recap and encyclopedia entry for the first execution of the FULL-only session tier on
branch `9.0.0`.*

---

## 1. Why these six existed unmeasured

The previous turn established, and proved, that `checker/gate-all.sh` executed 77 of 83
registered gates and reported a verdict anyway. The cause was mechanical: the runner feeds
its gate table to a `while` loop from a heredoc, and one gate read standard input,
consuming the remaining rows.

**Attribution, measured this turn rather than inferred.** The previous account named
`checker/plugin-install.sh` as the consumer *by position* — it was the last gate to run.
Position is inference. The direct experiment:

```
printf 'ROW1\nROW2\nROW3\n' | { bash checker/plugin-install.sh >/dev/null 2>&1; cat; }
  -> GATE_EXIT=0
  -> REMAINING_ON_STDIN:[]
```

All three planted rows were consumed and the gate exited 0. The attribution is now
measured. The repair already committed — `sh -c "$cmd" ... < /dev/null` per gate, plus a
roster assertion comparing registered against ran-plus-skipped — is confirmed to address
the actual consumer and not a suspected one.

Six gates had therefore **never executed on this branch**. They were run individually this
turn rather than by re-running the 67-minute sweep, on the reasoning that re-measuring 77
already-measured gates buys nothing and the information is entirely in the six.

## 2. Results

| Gate | Exit | Verdict | Detail |
|---|---|---|---|
| marketplace session | 0 | **GREEN** | 10 passed / 0 failed. Controls confirm the lane varies across 4 distinct lanes, the session marker is constant, and disabling the plugin removes the marker entirely. |
| live-session smoke | 1 | **RED** | 18 passed / 2 failed. Phase 3 delivery unattributable. **This is Family 9** — see below. |
| release session | 0 | **GREEN** | 48 passed / 0 failed. 27 of 27 lane-sessions routed correctly across all variants. |
| sustained session | 124 | **RED, truncated** | 21 passed / 6 failed at 1851 turns, 69 real model answers, 69 router firings. Exit 124 is a **timeout from the 600 s cap this audit imposed**, not from the gate. Its verdict is therefore partial and must not be banked. |
| CTT session | 0 | **GREEN** | 20 turns, 0 failed, 892 route records written (corpus 7141). Trace leaks: 0 — the internal-only seal held on all 20 turns. |
| deferred closure | 3 | **SKIP** | The newest completed CI run (`67d8791`) concluded `failure`; deferred steps cannot be closed from a red run. The gate states explicitly: "SKIP IS NOT A PASS." |

**Three green, two red, one skip.** Two of the six results carry caveats that are part of
the finding rather than footnotes to it.

## 3. The honest caveats

**The sustained-session verdict is void as a measurement.** Exit 124 means *this audit's*
`timeout 600` killed it. The 6 failures are real observations, but the run did not reach
its own conclusion, so "21 passed / 6 failed" is a reading of a truncated run — precisely
the Family 8 error this project committed at suite level last turn and has now committed
again at gate level, this time knowingly and by choice of cap. It is recorded as
**partial**, not as a verdict. Re-running it uncapped is open work.

**`deferred-closure` reveals a fact that contradicts the working assumption.** It read a
completed CI run, `67d8791`, and reported it concluded `failure`. The branch has no
upstream and zero pushes. The run it read is therefore the newest run *in the repository*,
not on this branch — which means CI history exists and is red, a state nobody had looked
at. The gate is correct to skip; the skip is informative.

## 4. The finding: Family 9

`live-session-smoke.sh` phase 3 asks the model to echo the router banner verbatim and
counts occurrences in the model's own stdout, with a disarmed negative control.

Measured: 6 hook firings into the armed context, 0 markers armed, 0 markers disarmed,
1758 bytes of model output across 17 lines. The gate reported the wiring broken.

The wiring was not broken. The 1758 bytes are nine `<rot:*>` stanzas from this project's
own Stop hook, and the model's reply *names both competing banner lines and their distinct
gauge values 0.17 and 0.19* — content unobtainable without having received them. Two of
its stanzas assert an emission absent from the file; a third, unprompted, states the
finding: *"the instrument contaminates its own sample."*

**A probe reads a channel, never a subject. Whoever writes that channel last is what the
verdict is about.**

This is filed as Family 9 and is distinct from Family 6 (*the instrument damages what it
measures*): there, the gate is the actor and the repair is to stop it writing; here the
gate writes nothing, reads correctly, and the repair is to change which channel it reads.
Formalised in `lean/Proofs/RotObserverEffect.lean` — 10 theorems, axiom-free, leanchecker
exit 0, three mutants killed.

## 5. Encyclopedia entries added

**FAMILY 9 — The subject cannot answer in its own voice.**
*Shape:* a third component, installed by the project itself, rewrites the subject's output
channel unconditionally before the probe reads it; every arm of the control reads the same
value.
*Tell:* a negative control whose two arms return the same number, above all the same zero.
*Repair:* read a channel the rewriter does not touch, as a **second** channel rather than
a replacement, so the weaker claim is not banked as the stronger one.
*Not Family 6:* there the gate is the actor; here the gate is passive and correct.

**Checklist item 12.** *Did both arms of the control read the same number?* Equal arms mean
the channel is absent, not that the subject failed. Name every component that touches the
subject's output before your reader sees it, and check whether one of them is yours.

**Law 12.** A probe reads a channel, never a subject. Whoever writes that channel last is
what the verdict is about.

## 6. A gap found in this audit's own assertor

The family-count assertor built last turn fired correctly on real drift for the first
time, catching 8 stale sites across 4 files including a Lean source comment. It did **not**
catch the compendium's own title — *"the eight ways an instrument reports green over
nothing"* — because its pattern deliberately matches only `<n> families` and
`<n>-family`, having been narrowed last turn to avoid a false positive on the prose
"treats one family in depth".

The narrowing was correct and the gap is real: a taxonomy-size claim can be phrased
without the word *family*. This is the same class as instrument error #26 (a pattern
anchored on one phrasing under-reports). Recorded as open debt rather than patched
reflexively, because widening the pattern reintroduces the false positive that motivated
narrowing it, and the right fix — deriving the phrasing set rather than guessing it — is
larger than this turn.

## 7. State after this turn

| Quantity | Value |
|---|---|
| Lean modules (repo) | 97 |
| shared Lean tree (machine-local, not shipped) | 99 |
| defect families | 9 |
| checklist items | 12 |
| accumulated laws | 12 |
| registered gates | 83 (73 default + 10 FULL-only) |
| gates now executed at least once on this branch | 83 |
| pushes | 0 |

**Open, in priority order:** re-run `sustained session` uncapped; investigate CI run
`67d8791`'s failure, which now blocks `deferred-closure` and the three CI-reading gates;
repair `live-session-smoke.sh` phase 3 to read the hook log as a second channel; resume the
`checker/` file sweep, 15 of 92 audited.

---

*Companions: `PAPER-the-observer-effect.md`, `COMPENDIUM-instrument-defects.md`
(Family 9), `ESSAY-what-a-green-gate-is-worth.md`.*
