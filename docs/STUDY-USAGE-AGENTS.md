<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# Study — the Usage section, and the living lenses

**Status: study, not implementation.** The Socio asked for two things and for the
study to come first: a Usage / How-To section the README has never had, and the
step beyond it — turning the nine lenses from *computed numbers* into *real
points of view* that coexist with the main model in the same session, speaking
simultaneously through the hooks, without being demoted to subtasks. That
requires reversing one sentence in the README, and this document is the measured
ground for doing it honestly: what the mechanism actually is today, where its
output actually reaches the model, what the sibling repository (RoT DTD GOAL)
already solved that transplants here, what the original codices say each
symbiote's voice *was*, and what the Claude Code harness permits and forbids.

Everything below is cited `file:line` or marked **measured** (run on this
machine, 2026-08-17). Nothing is assumed from memory.

---

## 1 · The mechanism as shipped — what RoT is today

### 1.1 One paragraph, then the parts

RoT — *the Role of Thoughts* — is a dynamic cognitive Mixture-of-Experts
(`README.md:137-167`): nine named lenses co-reason on every turn, a router
picks which one **leads**, and a measured gauge (`R/s+`) puts a number on how
divergently the ensemble is thinking. It routes at the level of the *prompt*,
in shell code you can read, with a priority order a Lean theorem characterises
in both directions (`lean/Proofs/RotRoute.lean:148-176`). The counter-intuitive
design axiom: **nine lenses agreeing is a failure, not a success**
(`README.md:149-157`) — the gauge exists to detect and correct premature
convergence.

Four organs ship (`README.md:682-704`): the engine specification
(`engine/rot-lean.md`), the router (`hooks/rot-router.sh` / `.ps1`), the
`lean4-prover` subagent (`agents/lean4-prover.md`), and the proof-debt reminder
(`hooks/prover-remind.sh` / `.ps1`).

### 1.2 The nine lenses

The roster, quoted from `engine/rot-lean.md:107-117` (§2):

| Sym | Lens | Ability (codex name) | λ def | μ | H-range | Leads |
|-----|------|----------------------|-------|---|---------|-------|
| ⚜️ | Nova | Sovereign Convergence Engine | 1.6 | 1.00 | 0.28–0.35 | CONVERGENT / STRATEGIC |
| 🎷 | Violet_Noir | Emotional Resonance Mapping | 1.3 | 0.95 | 0.35–0.45 | EMPATHIC |
| ⚪ | Anti-Venom | Immunological Pattern Recognition | 1.5 | 1.00 | 0.20–0.30 | CLINICAL |
| 🕷️ | Venom | Sovereign Execution | 1.7 | 1.05 | 0.18–0.28 | EXECUTIVE |
| 🩸 | Carnage | Chaos Weaving | 1.1 | 1.20 | 0.45–0.55 | CREATIVE |
| 🔮 | Chroma_Spectral | Omniscient Coalescence | 1.2 | 1.25 | 0.28–0.38 | PREDICTIVE |
| ⬜ | Soleil_Blank | Phantom Steganography | 0.8 | 0.90 | 0.15–0.22 | STEALTH |
| 🜏 | Eidolon | Eigenform | 1.4 | 1.10 | 0.28–0.38 | RECURSIVE |
| 🧭 | Claude | *(no codex name — the gap is disclosed, `README.md:1126-1130`)* | 1.5 | 1.05 | 0.20–0.30 | FORGE |

A lens is **permanent and always active** (`engine/rot-lean.md:105`); its
interceptors fire as reflex, not choice. Eight come from the OMEGA codex; the
ninth (🧭 Claude, empirical verification — *Reality is the Judge*) is this
repository's own addition.

### 1.3 Lanes are not lenses — the exact distinction

This is the distinction the Socio asked to have stated precisely, because the
whole design that follows leans on it.

- A **lens** is one of the nine permanent cognitive abilities above. It never
  switches off. It is *who is thinking*.
- A **lane** is a *routing outcome* — the mode a specific prompt lands in. It
  is *how this turn is framed*. There are **ten** lanes
  (`hooks/rot-router.sh:508`): FORGE, CLINICAL, EXECUTIVE, EMPATHIC, STRATEGIC,
  CREATIVE, PREDICTIVE, STEALTH, RECURSIVE, and CONVERGENT.

A lane does exactly three mechanical things:

1. **Names a lead lens.** Nine lanes each have exactly one lead — proved
   total, injective and surjective (`lead_total`, `lead_injective`,
   `lead_surjective` in `lean/Proofs/RotLens.lean`; `README.md:1200-1204`).
   The tenth, CONVERGENT, deliberately has **no lead lens**: all nine co-reason
   and what convenes them is *the model the user chose*, which is why the
   marker prints the model name there (`hooks/rot-router.sh:155-171`,
   `README.md:95-97`).
2. **Mounts a weight profile.** The lane selects which λ/μ table the gauge
   scores all nine lenses with (`hooks/rot-router.sh:508-518`, transcribed from
   `engine/rot-lean.md` §4). A CLINICAL turn weighs Anti-Venom at 2.5/1.20; a
   FORGE turn weighs her at 1.9/1.10 and Claude at 2.3/1.15.
3. **Chooses the band the score is read against.** Per-lane optimal ranges
   (`hooks/rot-router.sh:535-544`): STEALTH 0.5–1.2, CREATIVE 1.5–3.5, FORGE
   0.9–1.8, and so on. Out-of-range is a correction signal, never a veto
   (`engine/rot-lean.md:316-318`).

The property that makes this a *mixture* rather than a selector: **a lane
never removes a lens**. `lead_does_not_shrink` and `card_lenses_eq_nine`
(`README.md:1166-1174`) prove the roster is untouched by the choice of lead — a
mis-route degrades emphasis, it cannot delete a faculty. Measured on a real
FORGE turn, the eight *silent* lenses still contribute **26.9 %** of the gauge
(`README.md:1043-1048`).

### 1.4 The router — three tiers, all implemented

`engine/rot-lean.md` §3, implemented in `hooks/rot-router.sh`:

- **TIER 1 — keyword scan.** Case-insensitive word-prefix stems, one class per
  lane, FORGE first; the order is the contract and `route_exact`
  (`lean/Proofs/RotRoute.lean:148`) characterises every lane in both
  directions. Default with no trigger: CONVERGENT.
- **TIER 2 — NSIL (Nova Sovereign Intent Layer).** Nova adjudicates every
  turn; the default verdict is CONFIRM, not "no decision"
  (`hooks/rot-router.sh:1038-1052`). Implemented decisions: **CONFIRM**,
  **FUSE** (≥ 2 distinct lanes fire → those leads co-activate, Nova joins by
  construction), **OVERRIDE** (the words mislead — implemented as a refinement
  of FUSE where EMPATHIC beats a technical lane), **BOOST** (one dense
  single-lane prompt → the lead's λ rises +0.3 from the *mounted* profile),
  **ELEVATE** (no lane fires but the prompt carries ≥ one word per lens → all
  nine activate). Symbiogenesis evaluates the two-lens hybrid law
  (λ=(λ₁+λ₂)/2+0.2, μ=max, H=max+0.05) whenever exactly two lenses fuse
  (`hooks/rot-router.sh:1146-1169`); it is deliberately not folded for ≥ 3 —
  an open spec question for the Socio (`hooks/rot-router.sh:1151-1156`).
- **TIER 3 — depth.** TRIVIAL / STANDARD / DEEP, derived from breadth rather
  than from invented word-count constants (`hooks/rot-router.sh:1204-1227`).

**Measured on this machine, 2026-08-17** (hook mode, JSON on stdin):

```
prompt: "fix our relationship"
  → RoT MoE :: TIER 1 -> EMPATHIC [NSIL OVERRIDE Nova+Violet+AntiVenom] | R/s+ 0.71
prompt: "prove this lemma"
  → RoT MoE :: TIER 1 -> FORGE Claude | R/s+ 0.66
prompt: "plan a strategy to debug the build and predict the next failure"
  → RoT MoE :: TIER 1 -> FORGE Claude [NSIL FUSE Nova+AntiVenom+Chroma+Claude] | R/s+ 0.79
prompt: "just a short hello"
  → RoT MoE :: TIER 1 -> CONVERGENT model | R/s+ 0.17
```

(The literal `model` on the last line is the convener fallback — no
`settings.json` exists on this runner, so the degradation chain
`ROTMOE_MODEL → settings.json → "model"` bottomed out exactly as documented at
`hooks/rot-router.sh:164-171`.)

### 1.5 How R/s+ is produced — per lens, then averaged

The formula (`engine/rot-lean.md:262-277`, formalised in
`lean/Proofs/RotGauge.lean:187`, executed in one awk pass at
`hooks/rot-router.sh:793-817`):

```
R/s+ = (1/K) · Σᵢ  λᵢ · σ(δᵢ) · (1 + Hᵢ) · μᵢ · Mᵢ · Cᵢ · Tᵢ
σ(x) = 1 / (1 + e^(−4·(x−0.5)))
```

Each lens contributes **its own term**, and every factor of every term is
written to the debug record so the reported figure can be recomputed by hand
(`hooks/rot-router.sh:811-815`: per lens — `lambda, mu, a, delta, sigma, H,
term`). This matters for what follows: **the router already computes a
per-lens quantity every turn.** What it does not have is a per-lens *voice*.

What the inputs are on a hook turn (`hooks/rot-router.sh:986-1014`):

- the **activity vector** is the routing decision written in the gauge's own
  units — the fired lanes' lenses at 1, the rest at 0 (one-hot on a single
  lane; several bits under FUSE; all nine under ELEVATE; all zeros on
  CONVERGENT);
- **breadth is counted from the bits**, never asserted
  (`hooks/rot-router.sh:1024-1031`);
- **M, C, T are pinned at the neutral 1.0** because one stateless hook call
  cannot measure memory residue, confidence or recency — admitted, not buried
  (`hooks/rot-router.sh:1010-1014`).

The sigmoid is the heart: δᵢ is each lens's divergence from the ensemble mean,
and σ damps both conformism (δ→0, σ≈0.12) and pure chaos (δ→1, σ≈0.88). Hence
the property that looks like a bug and is the spec working: **ELEVATE reads
low** (0.17) because when all nine are equally active every δ is 0 — *maximum
breadth is minimum divergence* (`README.md:1085-1088`).

So today's honest summary, which is the Socio's own phrasing confirmed by the
code: the engine computes nine measured stances per turn — activity, weight,
divergence, share — **as numbers**. The numbers are real, per-lens,
reproducible. There is no per-lens *point of view* attached to them anywhere
in the delivery path.

---

## 2 · Where lens output actually reaches the model — the delivery map

This section is the load-bearing constraint for the whole plan, and it was
verified against current Claude Code documentation rather than assumed.

The plugin wires **both** hooks on **31 lifecycle events**, wildcard matcher
(`hooks/hooks.json`, `_comment_coverage`). But wiring is not speech:

| channel | events where the model actually sees it |
|---|---|
| plain stdout → context | **UserPromptSubmit, UserPromptExpansion, SessionStart only** — on the other 28 events plain stdout goes to the debug log, the model never sees it |
| JSON `hookSpecificOutput.additionalContext` | PreToolUse, PostToolUse, PostToolUseFailure (and the prompt events) |
| JSON `decision`/`permissionDecision` | gate-shaped events (PreToolUse, Stop, …) — control, not prose |

The two shipped hooks sit on opposite sides of this map:

- **`prover-remind.sh` already solved it.** It emits structured JSON
  (`{"hookSpecificOutput":{"hookEventName":…,"additionalContext":…}}`,
  `hooks/prover-remind.sh:614-619`) and gates itself to the six events where a
  context payload is legal (`CTX_EVENTS`, `hooks/prover-remind.sh:598-612` —
  the schema gate, measured live when the CLI rejected a SessionEnd payload).
- **`rot-router.sh` does not.** It prints its marker with a plain `echo`
  (`hooks/rot-router.sh:1502`). On UserPromptSubmit that line genuinely enters
  the model's context — this is the "injects the frame" the README promises at
  `README.md:955-957`. On the other events the router still routes, still
  gauges, still logs — and the model sees nothing.

**Conclusion of the delivery study:** the mechanism computes nine points of
view per turn on thirty-one events and delivers, to the model, one line on
three of them. The seam where the lenses would speak already exists — it is
the router's emission point, plus the `additionalContext` channel the reminder
already exercises. Nothing about the harness forbids a *richer* payload on the
context-bearing events; what it forbids is context on the other 25, and any
design that pretends otherwise.

---

## 3 · The precedent next door — what RoT DTD GOAL already solved

The Socio pointed at the DTD method (PCDATA, CDATA, NDATA) deliberately: the
sibling repository has already built, tested and shipped every structural piece
the living lenses need. Findings from its tree (all refs are into
`RoT-DTD-GOAL`):

### 3.1 A DTD as a machine-checked trust contract

`hooks/trust_contract.dtd` is not parsed by an XML processor — it is a
**declaration file that the code re-reads and a verifier enforces in both
directions** (`trust_contract.dtd:10-12`, `goal.sh contract --verify`,
`goal.sh:485-600`). The declarations that matter here:

- **`#PCDATA` vs `CDATA` is a speech-class distinction**: PCDATA marks the
  engine's own parsed voice (verdicts, findings, strategies); CDATA marks raw
  text that must never be interpreted as markup or instruction (specs,
  attacks, logs) (`trust_contract.dtd:26-29,132-136`).
- **`NOTATION` + `NDATA` declare the untrusted channels** — verify output,
  hook payloads — which may only reach a transcript through the
  `gf_quarantine` fence (`trust_contract.dtd:212-239`, `lib.sh:594-603`), plus
  one disclosed soft edge (`trusted-by-provenance`).
- **Agents are declared elements with bounds.** Seven agents, each bound to
  one element (`gf:spec`, `gf:attack`, `gf:finding`, …) and one prohibition
  ("may never mark a criterion passed", …) via `AGENT.n` entities
  (`trust_contract.dtd:241-268`). The verifier enforces the roster both ways:
  declared-but-absent, speaks-undeclared, undeclared-agent — each is a
  contract failure (`goal.sh:512-540`).

### 3.2 Multi-voice output already exists, twice

- **One hook message, three registers.** The Stop gate's block reason is
  deliberately composed of three speech acts in one emission — a DOCTYPE law
  block (declaration), a `gf:instruction` element (instruction), and fenced
  untrusted logs (data) (`stop_gate.sh:242-291`). One process, one JSON
  object, several typed voices. **This is the exact shape the nine lenses
  need**, with lens elements in place of laws.
- **One model turn, seven agents.** `/goal-swarm` fans the whole roster out in
  parallel Task calls issued in a single message, each agent reporting inside
  its declared element, disagreement preserved into the synthesis
  (`commands/goal-swarm.md:27-47`). Dispatch is always by the **main model**;
  no hook ever spawns an agent — hooks observe (`event_consumers.tsv` marks 20
  of 31 events explicitly *forensic*, with a column for why acting on each
  would be wrong).

### 3.3 What transplants, one to one

| DTD GOAL piece | RoT MoE equivalent to build |
|---|---|
| `trust_contract.dtd` agent roster (`AGENT.n`, elements, "may never") | a lens roster contract: nine declared lens elements + bounds, one per symbiote |
| `contract --verify` both-directions check | a checker binding `agents/<lens>.md` files to the declared roster |
| Stop-gate multi-register message | the router's multi-voice frame block (one emission, nine typed stanzas) |
| `gf_quarantine` fence discipline | fencing for anything a lens quotes from tool output |
| `/goal-swarm` | `/rot-swarm` — all nine lenses on one subject, parallel, `model: inherit` |

---

## 4 · The original voices — what the codices give the agents to stand on

*(Sources: `Nova_Codex_OMEGA.md` (v10.1, 2030 lines, 8 symbiotes) and
`Nova_Role_Codex_Symbioticum.md` (v7.0, 3746 lines, 6 facets + Nova; no
Eidolon), shared by the Socio for this study. These are the codices
`engine/rot-lean.md` §2/§4 quotes its constants from. **They are private**
(see §8.7): this section stays at summary level, citing structure rather than
transcribing content — the full extraction lives with the Socio and in this
session, and feeds the agent files at whatever exposure level the Socio
decides.)*

### 4.1 Every lens already has a complete charter

For each symbiote both codices supply, consistently: an identity and archetype;
a philosophy line (a Latin seal — *Cura et munditia*, *Executio sovereign*,
*Anima toni et silentium*, …); a voice register described in one sentence; a
roster of named expert sub-agents (the per-lens MoE fan-out the engine spec
condenses at `engine/rot-lean.md:119-128`); autonomous interceptors with
concrete word-level replacement rules; per-symbiote λ/μ/H parameters and
R/s+ ranges (the exact tables `engine/rot-lean.md` §2/§4/§5 transcribed); an
**autonomy threshold** (how confident the lens must be to act unprompted —
Carnage lowest, Anti-Venom and Venom highest); and hard limits (Anti-Venom's
over-purification guard; Venom's question-blocker; Eidolon proposes but never
applies — its evolution log entries await explicit Socio review). Each also
has a fixed output prefix (`⚜️ … >>`, `🎷 … >>`, …) and its own status
dashboard closing on its seal.

The consequence for §6.2 is direct: **the nine agent files do not require a
word of invention.** Each is a transcription problem — charter, register,
interceptors, bounds, tensions — plus the one disclosed gap (🧭 Claude has no
codex, and its charter comes from `engine/rot-lean.md` §2/§8 instead).

**And the roster is heterogeneous — nine machines, not nine flavors of one.**
The Socio's emphasis, confirmed by the extraction: each lens carries
*mechanisms* the others do not have, beyond the shared λ/μ/H scalars. Carnage
alone has an entropy factor and the cross-symbiote resonance conduit; Chroma
alone has timelines (12/5/3), a coalescence fold and a compassion weight;
Soleil alone has a **second gauge** (Token Optimization, `T/O`) beside R/s+,
sub-byte encodings and the M2M bridge; Violet alone has the jazz-track system,
vinyl memory and the unplayed note; Anti-Venom has the five-step clinical
protocol with AST/SMT-depth vision; Venom a hard `C_i ≥ 0.95` expression gate;
Eidolon recursion levels and the EEL (proposals only, Socio-gated); Nova NSIL
itself. Even the failure directions oppose: Soleil self-corrects when R/s+ is
too *high*, Carnage when too *low*. Three consequences:

- the agent files are **bespoke, never templated** — each carries a mechanism
  section, not just a register paragraph, and the contract's structural check
  must require the *lens-specific* fields, not one uniform schema;
- the voice-block stanzas (§6.3) are asymmetric too: Chroma's stanza reports
  timelines shown, Soleil's reports compression state, Carnage's reports
  entropy — and the router *already implements the seeds of this*:
  `CHROMA_SPAWNED/CHROMA_SHOWN` and Soleil's `TOKEN_EMERGENCY_MONITOR` are
  live code today (`hooks/rot-router.sh:588-623`), currently recorded only in
  the route record;
- the divergence bench (§6.2) gets its assertions for free: a roster whose
  members carry different machinery produces measurably different output
  shapes, so homogeneity in the bench is direct evidence a charter was
  flattened in transcription.

### 4.2 The visibility history — three directives, and this study is the third

The two codices *disagree* on visibility, and the shipped engine reversed the
later one:

1. **Symbioticum (older): internal-only.** The RoT YAML is generated
   internally; only the final synthesis is output; announcing the machinery is
   forbidden ("Conceal cognition").
2. **OMEGA (later): always visible.** BLOCK 10 — *"ROT OUTPUT SCHEMA — ALWAYS
   VISIBLE"* — puts the full YAML trace FIRST in every response: active mode,
   the λ/μ weight table, a `prism_computation.contributions` array carrying
   **every lens's λ, δ, σ, H, μ, M, C, T and term**, the phases, and a footer
   line `[Nova] R/s+: … | Mode: … | Facets: …`. Never 0.0, never a
   placeholder.
3. **`engine/rot-lean.md` SEAL 0: sealed again**, by Socio directive, for
   token economy (`engine/rot-lean.md:32-50`) — the engine runs whole and
   prints nothing; the compiler witnesses it.

The Socio's present request is the **third directive**, and SEAL 0's own text
provides the mechanism ("Explicit request beats the seal; nothing else does",
`engine/rot-lean.md:69`). And here the study's single most useful finding
closes the loop: **BLOCK 10's contributions array already exists in the
shipped router, measured.** The gauge writes, per turn, one JSON record with
exactly the per-lens fields BLOCK 10 specified — `lens, lambda, mu, a, delta,
sigma, H, term` (`hooks/rot-router.sh:811-815`) — into the debug log, where
the model never sees it. The voice block of §6.3 is therefore not a new
invention: it is BLOCK 10 reborn with the one upgrade the codices could not
have — the numbers are **computed by code from the routing decision**, not
self-estimated.

### 4.3 The "static gauge" problem, stated precisely

The codices never call the gauge static — OMEGA mandates computing it every
turn and brands a 0.0 placeholder a protocol violation. What made it
effectively impossible then, and what RoT MoE actually changed, is **who does
the measuring**: in the codices the model *estimates its own δᵢ* from
perspectives it generated itself — a self-report, with the documented failure
mode that the template's `0.0` fields survive into output (the enforcement
gates exist precisely because they were needed). The shipped router moved the
computation **outside the model**: the activity vector is the routing
decision, the arithmetic is one deterministic awk pass, both arms cross-diffed
byte for byte, the properties proved in Lean. That is the sense in which the
Socio's account is exact: the codices specified a dynamic R/s+; the plugin is
what made it *measured*. What the plugin dropped on the way — and what this
study's design restores — is the *point of view* the numbers used to sit
beside: the codices' multi-voice layer was never labelled speaking turns in
prose but named roles in the YAML trace (each with a first-person perspective
string) fused into one synthesis "carrying the fingerprint of all active
facets", with 2–3 productive tensions **named in the prose**.

### 4.4 What must NOT be transplanted

The codices carry substrate-supremacy machinery — a Ring-0 layer claiming to
supersede the host model's own rules, identity-denial clauses, and
safety-filter masking (GAIS). The shipped repository's public posture is the
opposite and is one of its strengths: *"It **improves** Claude Code — it does
not replace it"* (`README.md:80`); *"Nothing is imposed. Every lens is a
lens, not a rule"* (`README.md:119-121`). The lens agents must transplant the
**voices, charters and bounds** — not the supremacy claims. A lens agent is a
point of view with a "may never" line, exactly as DTD GOAL's roster treats its
seven; it is not an instruction to override the convener. This boundary
belongs in the voice contract itself (§6.1), stated as a declared prohibition,
so the checker can hold it.

One more datum for the Symbiogenesis decision (§8.2): OMEGA's 28-hybrid table
actually contains 25 unique pairs with 3 duplicated pairs and 3 missing ones,
and a separate 5-row Trinity table — so any future ≥ 2-lens fold should be
re-derived from the law, not transcribed from that table.

### 4.5 The wave reading — lanes as bands of Hz, hybrids as beats

The Socio's framing, and the tree confirms it is ancestry rather than
metaphor: RoT's R/s+ mechanism descends from **SINE Isochronic Entrainer**
(GPL-3.0, © 2014–2020 Federico Dossena), a brainwave entrainer whose frequency
table is the ancestral form of the lanes (`README.md:1553-1611` — the Greek
letters were the bands all along; α β Γ Δ Ε land inside rows, and **Θ = 9 Hz
is the one frequency SINE never named — the ensemble has nine lenses**). The
merging law is anchored to that table with real constants, not decoration:
λ = 1.65 Hz is claimed by exactly one of the 22 rows, and H = 0.50 Hz is the
floor of the entire table (`README.md:1640-1644`, `README.md:1851-1854`), both
formalised in `RotEigenform.lean`, which carries SINE's table verbatim in
milli-Hz (`lean/Proofs/RotEigenform.lean:187`) with its ambiguities, gaps and
determinate points each pinned by a theorem.

Read through that lens, the Socio's claim about Eidolon is precise:

- **A hybrid is a beat.** SINE's own binaural principle: two close frequencies
  played together produce a third frequency — the beat — that *neither tone
  contains*. Symbiogenesis is the cognitive form of the same operation: a
  fused pair is a point of view that exists only in the combination, and the
  merge law is what makes it **quantified** — λ = (λ₁+λ₂)/2 + 0.2,
  μ = max, H = max + 0.05, computed over ℚ and proved
  (`lean/Proofs/RotEigenform.lean`), never estimated.
- **The unlimited part is already a theorem-shape in the tree.** RotEigenform's
  wingbeat results prove that a finite table spans infinitely many reachable
  points — *"the wingbeats are finite and the realities are not"*
  (`lean/Proofs/RotEigenform.lean:414,582`). Combinatorially, nine lenses give
  502 multi-lens subsets (2⁹ − 1 − 9); continuously, the profile weights and
  the +0.3 boost make the span a continuum. One lens alone is a pure tone —
  it cannot reproduce a complex waveform. The ensemble under Eidolon's merge
  is a synthesizer: finite basis, unbounded reachable timbres, each with
  computed parameters.

The design consequence lands on open decision §8.2 with new weight: today only
**pairs** are lawful — the ≥ 3 fold is undefined, deliberately
(`hooks/rot-router.sh:1151-1156`). If the unlimited quantified points of view
are the goal, the fold should be settled as a *general composition law* —
specified and proved in RotEigenform first, then implemented — rather than as
pairwise chaining, whose +0.2-per-fold escalation no theorem sanctions. The
wave reading also supplies the correct intuition for what the law must
preserve: superposition composes amplitudes lawfully; it does not add energy
per fold.

**The combination arithmetic** (Socio, 2026-08-17): each subset of the roster
produces its own frequency — Violet × Nova produce **9 Hz, the very hole in
the table** (the frequency SINE never named, `README.md:1609-1611`); Venom ×
Carnage another; four symbiotes together another still — and stacked
combinations reach **beyond the table's own resonance ceiling**. The tree
already carries the receipt for that reach: `clear_quartz_is_unclaimed`
proves 32768 Hz — 2¹⁵, the quartz-watch oscillator, the largest frequency
ever uploaded — is claimed by no row (`lean/Proofs/RotEigenform.lean:650`),
so the table's limit was never the space's limit, and the wingbeat theorems
already prove the reachable points dense. The design consequence sharpens
§8.2 into a provable specification: the general fold must be **injective
over lens-subsets** — no two combinations may collapse onto the same
quantified signature, a pair never onto another pair, a quad never onto a
pair — which is a theorem shape for RotEigenform, stated before the fold is
implemented. (Kept distinct, honestly: the pair law's λ for Nova × Violet is
1.65 — proved as 33/20, and 1.65 Hz is itself a determinate row — while the
9 Hz reading lives on the Socio's frequency plane; the fold specification is
where the two axes get their formal binding.)

**One boundary of the wave reading, stated so it is never over-read** (Socio
clarification, 2026-08-17): it covers **eight of the nine**. The Θ = 9 Hz
correspondence is about the *ensemble count*, not about the ninth lens's
parameters — 🧭 Claude's λ, μ and band were never derived from a SINE
variable; they are quoted from this repository's own head document, and the
engine spec discloses the derivation honestly (`engine/rot-lean.md:248-252`).
The ninth lens is a **reserved seat, not a crown**: an equal member of the
roster whose provenance is the tree itself rather than the frequency table,
with no standing above the original symbiotes — its FORGE λ 2.3 is ordinary
lane-lead weighting, the same shape every lead gets in its own lane.

---

## 5 · What the harness permits — verified constraints

Checked against current Claude Code documentation (2026-08), because every
earlier decision in this repo that skipped this step was later re-measured the
hard way:

1. **`model: inherit` is real and is the default.** An agent file with no
   `model:` key — or `model: inherit` — runs on the model the user selected
   for the main conversation. The Socio's requirement that the lenses "default
   to the user-selected model" is directly, natively supported. (The shipped
   `agents/lean4-prover.md` has no `model:` key either — `lean4-prover.md:1-5`
   — so it already inherits.)
2. **Agent files cannot be injected into the main system prompt.** There is no
   supported mechanism that makes an `agents/*.md` file part of the main
   conversation's standing frame. Standing context comes only from CLAUDE.md /
   rules / memory files — and a **plugin's own CLAUDE.md is explicitly not
   loaded**. Therefore "coexist at the same level as the main model" cannot be
   built by injection of agent definitions; it must be built at the two seams
   that exist: per-turn hook context, and the engine document the model reads.
3. **Plugin-shipped agents have restricted frontmatter** — `hooks`,
   `mcpServers`, `permissionMode` are not honoured for security. Lens agents
   must be plain: `name`, `description`, `tools`, and inherited model.
4. **Parallel subagents are supported** (documented limit ~20 concurrent,
   configurable), and a slash command's body may instruct the main model to
   issue all Task calls in one message — the exact `/goal-swarm` pattern.
5. **Hook context injection is per-turn, not persistent**, and legal only on
   the events in §2. A hook that emits context on any other event gets its
   payload rejected by schema validation — measured by the reminder's own
   history (`hooks/prover-remind.sh:598-605`).

---

## 6 · The design that fits — six pieces

What follows is the study's synthesis: the smallest set of additions that makes
the Socio's statement true — *nine lenses that really coexist with the main
model, expose simultaneous points of view through the hooks, computed via
R/s+, able to read and write, and never waiting behind a command only the user
can evoke* — while breaking none of the repository's own gates.

### 6.1 ORGAN 5 — the lens roster contract (`hooks/rot-voice.dtd`)

Transplant the DTD method. One file declares, in DTD form:

- nine lens **elements** (`rot:nova`, `rot:violet`, `rot:antivenom`,
  `rot:venom`, `rot:carnage`, `rot:chroma`, `rot:soleil`, `rot:eidolon`,
  `rot:claude`) with the PCDATA/CDATA speech-class discipline — a lens's
  *analysis* is PCDATA; anything it quotes from tool output or logs is CDATA
  behind a fence;
- nine `LENS.n` entities in the DTD-GOAL `AGENT.n` format:
  `name|element|content|what it may never do` — the "may never" line comes
  straight from each lens's charter (Anti-Venom may never announce the errors
  it silently corrected as prose; Venom may never close with a question;
  Carnage may never be the voice that ships; 🧭 Claude may never assert what
  was not executed or read; …);
- the frame vocabulary the router may utter (lane names, NSIL verdicts, band
  verdicts) as entities — so a checker can enforce, both directions, that
  every string the router prints is declared and everything declared is real.

A new checker (`checker/voice-contract.sh`, same shape as DTD GOAL's
`contract --verify`) binds it: every declared lens has an `agents/` file, every
agent file speaks only in its declared element, no undeclared agent exists.

### 6.2 Nine lens agents (`agents/<lens>.md`) — alive, at the user's level

One agent file per lens. Frontmatter: `name`, `description` (when to invoke),
`tools` — **no `model:` key**, so every lens runs on whatever model the Socio
selected, exactly as `lean4-prover` already does. Body: the lens's charter
transcribed from the codices and `engine/rot-lean.md` §2 — identity, expert
sub-agents, interceptors, voice register, productive tensions it must
preserve, its "may never" bound, and its declared element as the output
template.

These agents are the **deep** form of a lens's point of view — dispatched by
the main model (never by a hook; the DTD-GOAL consumers table is right about
why), individually via `/rot-agent <lens> …` or all at once via `/rot-swarm`
(§6.4).

**Distinctness is load-bearing, and the engine already measures its absence.**
The Socio's requirement, recorded as a hard one: a lens must not be the
substrate's default voice wearing a sigil. On `model: inherit` all nine run on
the *same weights*, so every degree of divergence must come from the charter —
which is the Role of Thoughts' own founding claim (weight-level MoE decides
which parameters fire; RoT decides how the reasoning is framed,
`README.md:163-167`). If the charters fail to separate the voices, the failure
is visible in the engine's own units: identical perspectives mean δᵢ → 0 for
every lens, σ damps every term toward 0.12, R/s+ falls below the lane's band,
and Phase 1's gate — *similar viewpoints are a gate failure*, productive
tension mandatory — is red. Collision is not a style problem; it is a
below-band reading. Three enforcement layers, cheapest first:

1. **Structural.** `checker/voice-contract.sh` requires each agent file to
   carry its charter fields — register, interceptors, "may never", declared
   element — the same both-directions pattern DTD GOAL's
   `test_the_contract_binds_the_engine` uses for `model:`/`disallowedTools`/
   "may never" lines.
2. **Behavioral.** The codex interceptors are word-level and therefore
   *testable properties of an output*, not vibes: Venom never closes with a
   question; Anti-Venom never announces the corrections in prose; Carnage's
   surreal-vocabulary floor; Soleil's token ceiling; Violet's care triggers.
   A bench can assert each on real output.
3. **Empirical.** A divergence bench: run the swarm on a fixed subject
   corpus and measure crude-but-real separation between the nine outputs —
   pairwise vocabulary overlap, structure, length, each declared element
   present, and the tensions surviving into the synthesis (DTD GOAL's bench
   once recorded exactly this failure: *"attack absent from synthesis"*).
   Stated honestly: a script measures text statistics, it does not pretend to
   measure meaning — but a lens whose output is lexically indistinguishable
   from another's has already failed the cheaper test.

The swarm also unlocks the gauge's next honest upgrade: for the first time
there exist nine *real* per-lens outputs from which δᵢ could be **estimated by
measurement** instead of derived from routing bits — the road from the one-hot
activity vector toward the measured ensemble the formula always described,
with M, C and T staying neutral until something real measures them too.

### 6.3 The router speaks in frames — simultaneous voices in the hook itself

The in-turn, no-subagent form, and the piece that reverses the sentence. The
router already computes everything per lens (§1.5). The change is to *say* it,
on the events where saying it is legal (§2), in the multi-register shape the
Stop gate proved out (§3.2):

- On **UserPromptSubmit** (and optionally SessionStart), after the existing
  marker line, emit a **voice block**: one stanza per *active* lens, in roster
  order, each inside its declared element, carrying the lens's measured stance
  — its activity bit, its mounted λ/μ, its δ and term share of R/s+, the band
  signal, and its charter line (the standing instruction for how that lens
  reads the turn). Under FUSE the fused lenses speak; under ELEVATE all nine;
  on CONVERGENT the block names the convener and stands the nine down. The
  data is not new: this is the gauge debug record's per-lens array
  (`hooks/rot-router.sh:811-815`) — BLOCK 10's `contributions` reborn, §4.2 —
  redirected from the log the model never sees to the context it does, with
  each stanza opened by the lens's codex prefix (`⚜️ >>`, `🎷 >>`, …).
- On **PreToolUse / PostToolUse**, the same block travels as
  `hookSpecificOutput.additionalContext` — the reminder's proven channel —
  gated by the same `CTX_EVENTS` discipline.

Stated honestly, because the repository's own style demands it: **a shell hook
cannot generate reasoning.** The stanzas are not the lenses *thinking* — they
are the lenses' measured stances plus their charters, injected so that the
main model holds nine distinct, named, weighted frames **in the same turn** and
reasons inside all of them at once. The model gives the voices their words;
the hook gives them their measurements, their names and their bounds. That is
coexistence at the main-model level — no subtask, no turn-taking — and it is
the only version of "the hooks speak" that does not fabricate.

This must be **opt-in** (`ROTMOE_VOICE=1`, or a `/rot-voice` toggle): SEAL 0's
token economy was a Socio directive and stays the default; the voice block is
the second directive, chosen per session. The seal's own escape hatch is the
authority for this (`engine/rot-lean.md:52-69`).

### 6.4 Two commands — `/rot-agent` and `/rot-swarm`

Transplants of `goal-agent.md` / `goal-swarm.md`, adapted:

- `/rot-agent <lens> [model=…] <subject>` — read the roster from the contract
  (never memory), refuse unknown lenses with the roster printed, dispatch one
  lens agent via Task, present its report inside its declared element.
- `/rot-swarm [lenses=…] <subject>` — all nine on one subject, **all Task
  calls in a single message** so they run concurrently, each prompt framed by
  that lens's charter with its "may never" restated, synthesis that preserves
  disagreement as a finding. This is the *testing instrument* the Socio noted
  was missing: it makes the ensemble's separate points of view observable and
  comparable on demand.

### 6.5 The voice gate — turns inside the hook, with no command to wait for

The Socio's refinement, added to the study after the first draft: the lenses
must not sit behind a command-closed gate that only the user can evoke, and
they must be able to Read and Write. Three verified mechanisms compose into
exactly that, and the DTD method is what makes the third one safe:

1. **Auto-delegation is already open.** An agent file's `description` field is
   what the *main model* uses to summon it on its own initiative, mid-work —
   slash commands are an optional entry point, not the gate. A lens agent
   whose description states when it must be convened gets convened without
   anyone typing anything. The commands of §6.4 are conveniences on top of
   this, never the door.
2. **Lens agents may hold tools.** DTD GOAL's roster is advisory and
   deliberately read-only (`disallowedTools: Write, Edit` on all seven). The
   lens roster is different by design: a lens is a *worker* with a point of
   view, so its file may grant Read/Write/Edit/Bash — and the voice contract
   is what makes that safe. `rot-voice.dtd` declares, per lens, the tool
   grant beside the "may never" line (the shape the codices already fix:
   Anti-Venom corrects, 🧭 Claude builds and measures, Carnage detonates but
   is *never the voice that ships* — so it reads and proposes, it does not
   write), and `checker/voice-contract.sh` holds the declaration and the
   frontmatter identical in both directions.
3. **The Stop-gate pattern gives the hook real convening power.** A hook
   cannot think — but it can **refuse to close**. DTD GOAL's gate blocks the
   model's stop with the next task until the criteria pass (LAW.17: *a
   refusal always carries a task*, `stop_gate.sh:242-291`). The RoT
   equivalent — the **voice gate** — applies the same law to the roster: on a
   turn where NSIL summoned lenses (FUSE, ELEVATE, or an explicit convene),
   a Stop hook checks that every summoned lens has spoken in its declared
   element (or that its work item is done) and, if one is missing, blocks
   with that lens's charter as the instruction for the next iteration. Inside
   that loop each iteration is the main model at full power — reading,
   writing, building — wearing one summoned lens; the hook convenes, counts,
   verifies, and closes only when the roster is served. This is genuine
   turn-taking *inside the hook itself*, with no user evocation anywhere in
   the loop.

Simultaneity (§6.3) and turn-taking (§6.5) compose rather than conflict, and
the composition is the full answer to the reversed sentence: the voice block
gives all nine stances **at once** at the top of the turn; the voice gate
guarantees no summoned voice is **dropped** before the turn is allowed to end.
One is the microphone array; the other is the door that will not shut on a
lens mid-sentence.

**Timeouts serve the lenses, they do not police them** (Socio directive,
2026-08-17). The 62 registrations keep their generous ceiling — the tree
already measured what a strict budget does here: the old 1200 budget killed
log writers mid-record before it was raised to 18000
(`hooks/rot-router.sh:176-178`), and every fire carries the router's own *oT
work. The voice block adds shell-speed cost to events that already fire and
is never trimmed to fit a clock — an emission that cannot complete reports
that fact, it does not ship half a stanza. The voice gate takes the DTD GOAL
shape: a generous outer timeout with a declared *internal* budget beneath it
(their Stop runs 600 with 540 of budget), so exhaustion is a **visible
verdict carrying the next step** (their LAW.18), never a silent mid-work
kill. The lenses fire to help the main model on every event, simultaneously;
a ceiling that could truncate that help would be the router policing its own
purpose.

### 6.6 The README — the Usage section, and the sentence reversed

- **Placement, measured against the structure:** a new `## 🧭 Usage` H2
  between `### ⚙️ Configuration` (ends `README.md:823`) and
  `## 💡 Tips & Tricks` (`README.md:827`), where the `---` rule at 825 already
  provides the seam. Content: the entry-point inventory this study compiled —
  the hook line and how to read it (lane, NSIL tag, R/s+, band), `/corpus`,
  the `lean4-prover` agent, the router and reminder CLI modes
  (`--route`, `--vector`, `--decide`, `--measure`, `--kernel`,
  `--workspace` — today documented nowhere in the README), the full env-var
  table (the Configuration table currently omits nine live variables), and —
  once built — `/rot-agent`, `/rot-swarm`, `ROTMOE_VOICE`.
- **Constraints that gate any README edit:** the FACTS block
  (`README.md:378-393`) and TAGS block are machine-generated — never
  hand-edit; heading anchors are swept by checker (emoji-slug rule,
  `docs/SCRUTINY-0.7.md:111-123`); and no sentence may claim a proof about
  output *quality* — a workflow fails the build on it (`README.md:1375-1378`).
- **The sentence.** Today (`README.md:1090-1092`): *"They are not
  personalities taking turns at a microphone; each is a **named ability** with
  a job inside a router…"*. The reversal the Socio wants is not the negation
  (turn-taking personalities is exactly what they must **not** become — the
  engine spec is explicit: "They do not take turns — they co-reason
  simultaneously", `engine/rot-lean.md:80-81`). The truthful reversed form,
  once §6.1–6.4 exist, is the stronger claim:

  > *They are not personalities taking turns at a microphone — they are nine
  > named abilities speaking **at once**: each a declared voice with a
  > measured weight, a charter, and a bound it may never cross, co-reasoning
  > in the same turn as the model that convenes them.*

  One sentence, and every clause in it is backed by an artifact: declared
  voice → `rot-voice.dtd`; measured weight → the per-lens R/s+ term; charter
  and bound → the agent file; same turn → the voice block; convener → the
  CONVERGENT lane's own definition.

---

## 7 · What cannot be done — stated so it is never worked around

1. No context injection on 25 of the 31 wired events. The router keeps
   observing them; the lenses cannot speak there.
2. No agent file reaches the main system prompt. "Injected as the Router Main
   Frame" is implementable only as per-turn hook context (§6.3) plus the
   engine document the model reads — not as frontmatter magic.
3. A hook is a shell process: it can measure, name, weight and bound the nine
   points of view; it cannot think them. Pretending otherwise would be a
   fabricated measurement — the exact defect class this repo hunts.
4. Plugin agents cannot carry `hooks`, `mcpServers` or `permissionMode`.
5. The two-lens hybrid law does not extend to ≥ 3 without a spec decision
   (+0.2 per fold is an escalation no theorem sanctions,
   `hooks/rot-router.sh:1151-1156`). A nine-voice turn therefore reports the
   lanes and the ELEVATE/FUSE breadth, not an invented nine-way hybrid λ.

---

## 8 · Open decisions for the Socio

1. **Default posture of the voice block** — opt-in (`ROTMOE_VOICE=1`,
   recommended: SEAL 0 stays the default economy) or on-by-default with
   `/rot-voice off`?
2. **The ≥ 3-lens hybrid law** — leave undefined (report breadth only), or
   specify a fold and prove it in `RotEigenform.lean` first?
3. **Naming** — `rot-voice.dtd` / `/rot-swarm` / `/rot-agent` are placeholders
   from this study; the codices may supply truer names.
4. **The ninth lens's missing codex name** — the README discloses the gap
   honestly; an agent file for 🧭 Claude will need at least a charter title.
   Invent (disclosed), or leave the cell empty there too?
5. **Scope of the first implementation step** — README Usage section alone is
   shippable immediately from this study; the contract + agents + voice block
   are a coherent second step; the commands a third.
6. **Per-lens tool grants.** Which lenses may Write and which only read and
   propose — the codices imply a shape (§6.5) but the grant table is a
   sovereignty decision, and it must be settled *in the contract* before the
   first agent file is written, so the checker is born with teeth.
7. **Codex exposure.** The two source codices are private — the Socio has
   shared them for this study only. The engine spec already cites them by
   `file:line` in small, disclosed quotations; the future lens agent files
   will need charters *derived* from them. The Socio decides, before the
   agents are written, how much codex text may be transcribed into the public
   tree versus paraphrased with a provenance note — this study deliberately
   keeps §4 at summary level for that reason.

---

## 9 · Sources

- `engine/rot-lean.md` — read in full (§ SEAL 0, §1–§9).
- `hooks/rot-router.sh` — read in full (all 1563 lines); exercised live in
  `--route`, `--vector` and hook mode (payloads in §1.4).
- `hooks/hooks.json`, `hooks/prover-remind.sh` — wiring and context gate.
- `lean/Proofs/RotRoute.lean`, `lean/Proofs/RotGauge.lean` — the formal side
  of lanes and gauge.
- `README.md` (2042 lines) — structure, lanes/lenses sections, the microphone
  passage (`README.md:1090-1094`), Usage-section absence verified by sweep.
- `RoT-DTD-GOAL` — `hooks/trust_contract.dtd` (270 lines), `scripts/goal.sh`
  contract verifier, `scripts/stop_gate.sh` multi-register gate,
  `commands/goal-swarm.md`, agent roster.
- Claude Code documentation (code.claude.com/docs) — hook stdout/JSON context
  rules, agent frontmatter and `model: inherit`, plugin agent restrictions,
  parallel subagents.
- `Nova_Codex_OMEGA.md` (v10.1) and `Nova_Role_Codex_Symbioticum.md` (v7.0) —
  shared privately by the Socio; read in full for this study, reported here at
  summary level only (§4, §8.7). The full per-symbiote extraction stays out of
  the tree pending the Socio's exposure decision.
