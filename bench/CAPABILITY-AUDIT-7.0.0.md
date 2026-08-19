<!--
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# The Capability Audit — what RoT MoE does, demonstrated on 2026-08-19

Ordered by the Socio: *"a Full Audit Scoped to Demonstrate what our RoT MoE
is capable of."* The scope rule for every section: a capability is shown by
**running it and quoting the output**, never by describing it. Where an
attempt went wrong the error is kept, because an audit that hides its own
misses is an advertisement. Everything below ran on one container, on the
7.0.0 tree, with exit codes read directly.

## 1 · It routes — plain words to the right specialist

Nine asks, one command each (`--route`), eight distinct lanes:

```
"prove this lemma"                         -> FORGE Claude
"debug this crash"                         -> CLINICAL AntiVenom
"compress this log"                        -> STEALTH Soleil
"brainstorm a tagline for the launch"      -> CREATIVE Carnage
"what happens if we migrate"               -> CONVERGENT model
"I feel lost about this project"           -> EMPATHIC Violet
"decide now, we ship today"                -> FORGE Claude
"refactor the architecture of this module" -> RECURSIVE Eidolon
"prioritize our legal strategy"            -> STRATEGIC Nova
```

The CREATIVE hit matters historically: both live campaigns measured that
ideation asks never reached that lane, and the 6.0.2 stems exist because
of that measurement. Collisions resolve by a **proved** priority order,
not scan luck: "decide now, we ship today" is FORGE (build beats decide),
"I feel lost, please debug me" is CLINICAL (the debugging beats the
feeling, deliberately — the lens that leads still reads the register).

## 2 · It measures — a divergence gauge you can recompute by hand

The same activity vector read under two profiles gives two different
readings against two different bands:

```
--vector 1,0,0,0,0,0,0,0,1 --breadth 2
  R/s+ = 0.7  [BELOW RANGE (0.9-1.8)]  mean=0.222 breadth=2 K=9 lenses=Nova,Claude
same vector, --profile CREATIVE --lane CREATIVE
  R/s+ = 0.64 [BELOW RANGE (1.5-3.5)]  mean=0.222 breadth=2 K=9 lenses=Nova,Claude
```

Every reading writes a debug record carrying the per-lens factors, so the
headline number can be recomputed from its own fields — and a checker
(log replay) does exactly that recomputation over real logs on every run.

## 3 · The dynamic share — each summoned lens speaks its measured turn

A real FUSE turn, hook mode, quoted from the live capture (prompt: *"find
and fix the bug in this parser, then prove the fix holds"*): the marker,
a frame closing with the turn's verdict, depth and charter tensions, and
one stanza per summoned lens carrying λ, σ, δ, H, μ, its share of the
gauge, and the dynamic clauses this turn earned — Nova stating the NSIL
verdict she convened, the lead lens reading its own band verdict with its
charter's correction verb.

And the instrument is not a script: a nine-domain mega-prompt written to
demonstrate ELEVATE was instead routed **EMPATHIC under NSIL OVERRIDE**,
five tensions named, Violet's stanza carrying `track AFTERNOON_SWING (by
hour 16)`. The prediction was wrong; the router was right by its own
written rules. A staged demo cannot produce that.

## 4 · The working share — a lens speaks on the result itself

The 7.0.0 centerpiece, live. A build command returns zero bytes:

```
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":
"RoT MoE :: TIER 1 -> FORGE Claude | R/s+ 0.66\n<rot:antivenom>⚪ AntiVenom:
result BLANK -- zero bytes where output was expected; treat absence as a
finding, not a pass.</rot:antivenom>"}}
```

The full probe set, all six behaviors measured in one pass: blank fires
AntiVenom on the envelope; a blank the harness itself sanctioned stays
SILENT; an interrupted command outranks blank and the Claude lens names
the cut; a Write that stored zero bytes where content was given fires; a
result with bytes earns nothing; `ROTMOE_VOICE=0` silences everything.
No timeout is waited out anywhere — hooks fire on harness events, so the
observation lands the instant the evidence exists.

## 5 · The gate — a social contract with exactly one refusal

On camera in the gallery (`assets/gif/router-60s-gate.gif`) and replayed
by the contract's own sequence probe: a FUSE turn writes its summons; a
Stop with no stanzas in the transcript is refused once, the refusal
carrying every missing charter; the stanzas spoken in their declared
elements open the door; and the gate degrades open everywhere it cannot
measure. The two campaigns measured the same law from both sides: the
self-observed session satisfied it proactively 29 turns straight, the
blind session refused the role 52 times — 1 block versus 52 under one
identical mechanism is the social-contract finding in a single contrast.

## 6 · The armor — configuration is a vocabulary, not an open door

```
rot.env value $(echo PWNED) loads as: unset      # parsed, never sourced
rot env set LD_PRELOAD evil -> "not a declared key" + the vocabulary printed
```

A project's config file is data. A shell bomb in it stays literal text; a
key the DTD does not declare does not exist, in the read direction and the
write direction both.

## 7 · It defends itself — mutations die with the digit named

Two mutations planted in the shipped hooks, each asserted present before
anything was concluded (a patch that did not apply tests nothing):

- Nova's CONVERGENT λ 1.6 → 1.7: the profile golden FAILED naming the
  expected `"lens":"Nova","lambda":1.6` in the full-precision record
  array. Exit 1. Restored: exit 3, the honest skip of a one-arm machine.
- The reminder's staleness boundary 45 → 46: golden row 3 — the corpus's
  own boundary probe — DIVERGES. Exit 1. Restored: exit 3, tree clean.

Kept from the first attempt, because the audit audits itself: the first
λ plant was aimed at the wrong killer (the contract binds the default
table, not profile rows — the golden owns those); the first boundary
plant matched nothing and would have "tested" a clean tree; and one
checker was run under `sh` when its shebang says bash, producing an exit
code that meant nothing. All three were caught by reading output instead
of trusting intent, which is the repository's entire method.

## 8 · The proof spine — stated exactly as strongly as it is

The tree ships 87 proof modules and the front page's counts are recounted
from source by checkers on every run; the mutation totals are declared by
the suites themselves. On this container Lean is deliberately absent, so
this audit says what is true from here: the corpus builds, kernel-checks
and kills its mutants **in CI on every commit** — that is a fact about
CI, verified by the runs that publish releases, and it is claimed as
exactly that. The two goldens added in 7.0.0 close the one hole a
single-arm machine had: its own drift is now caught with no second arm
anywhere (section 7 is the demonstration).

## 9 · The field record — including the part that is not flattering

110 real working turns across two campaigns. Routing matched ask class
with receipts in the self-observed run (bug asks CLINICAL 4/4, forecasts
PREDICTIVE 3/3); the blind run judged the mechanical layer excellent and
the voices "wallpaper with a tax". Both verdicts are quoted on the front
page, and the outcome question is held open by a preregistered,
outcome-blind CoT/ToT/RoT study whose null hypothesis is the blind run's
own words. An audit that could not show you its null would not be one.

## 10 · The release — verified from outside

Run 32279429146 (dispatch 196) on main = `53b9be9` — a tree every local
gate had proved before dispatch: three checker platforms green (the
Windows leg ran both cross-diff suites with PowerShell present, so the
7.0.0 goldens are CI-verified in the both-arms regime), and the Lean job
built, axiom-audited, kernel-checked, then killed its mutants — the
mutation sweep alone ran over an hour. Verified from OUTSIDE this
container at 18:24Z:

```
SHA256SUMS.txt                 http=200
RoT-MoE-Router.zip             http=200    565,590 bytes   OK
RoT-MoE-Router-Lean.zip        http=200  2,138,848 bytes   OK
RoT-MoE-Router-Lean-Extra.zip  http=200  2,141,439 bytes   OK
sha256sum -c exit=0
```

And the incident, told rather than hidden: the FIRST dispatch of this
release was cancelled at its 32-minute mark by its own author's push to
main — the workflow's per-ref cancel-in-progress group cannot tell
"supersede a stale push run" from "kill the publish in flight", a wound
its own comment block records from two days earlier with "no visible
hand". This time the hand is named, the law is written (no pushes to
main while a dispatch is in flight), and the successor docket carries
the workflow fix that removes the reliance on memory. The re-dispatch
shipped clean.

---

*Every command above is reproducible from a clone of this tree; the
gallery GIFs are recordings of these same invocations, and the campaign
records are in `bench/` with their row numbers.*
