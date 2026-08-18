<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

# HARD SESSION — RoT MoE v6.0.1, 80-turn blind trial

**2026-08-18. FINAL — all 80 turns driven, log audited.** The release
under test is [v6.0.1](https://github.com/Nova-Violet-Role/RoT-MoE/releases/tag/v6.0.1),
published 2026-08-17 21:52 UTC, tag on commit
`405f0a302e53f763a186f5c3ec6b8e440f91c3f1`. Design: one persistent nested
Claude Code session (the **worker**) is driven for 80 turns of real project
work by an orchestrator acting as its client. The worker is **blind** — no
prompt it receives mentions the plugin, the router, the voices, or this
experiment. Purpose: find defects that only appear in the long run, and
measure whether 6.0.1's new provenance frame changes how an unbriefed model
treats the voices (v6.0.0's finding B4: the convening model refused the
stanzas as untrusted injected framing).

Every exit code below was read directly, never through a pipe. A red result
is data; nothing in the plugin was patched or worked around. The Lean
toolchain was **not** installed; no claim here asserts the Lean proofs
verified.

## Environment

| | |
|:--|:--|
| Claude Code CLI | `2.1.234 (Claude Code)` |
| OS | Linux 6.18.5-fc-v20 x86_64 (remote container; POSIX-only — no `pwsh`) |
| workspace clone | `405f0a302e53f763a186f5c3ec6b8e440f91c3f1` (= the released commit, `main`) |
| `~/.claude` plugins | virgin before the test — no plugins, no marketplaces |
| debug sink | `ROTMOE_DEBUG_LOG=$HOME/hard-debug.jsonl`, set on the worker command's live environment (organ 7 live-env precedence; invisible to the worker) |

## PHASE 0 — install and prove the 6.0.1 surface

### P0.1 · marketplace install — PASS

```
$ claude plugin marketplace add Nova-Violet-Role/RoT-MoE
√ Successfully added marketplace: rot-moe (declared in user settings)   exit=0
$ claude plugin install rot-moe@rot-moe
√ Successfully installed plugin: rot-moe@rot-moe (scope: user)          exit=0
$ claude plugin list
  > rot-moe@rot-moe / Version: 6.0.1 / Scope: user / Status: √ enabled  exit=0
$ git -C ~/.claude/plugins/marketplaces/rot-moe rev-parse HEAD
405f0a302e53f763a186f5c3ec6b8e440f91c3f1                                exit=0
```

Installed version **6.0.1** at exactly the released commit. The runtime
cache the hooks execute from (`~/.claude/plugins/cache/rot-moe/rot-moe/6.0.1/`)
was diffed against the marketplace clone: `hooks/` and `agents/`
byte-identical (`diff -r` exit 0 both).

### P0.2 · the `<rot:frame>` provenance line — PASS (new in 6.0.1)

FUSE payload through the installed router:

```
$ printf '{"hook_event_name":"UserPromptSubmit","session_id":"phase0-proof",
  "prompt":"prove the lemma and debug the crash"}' | hooks/rot-router.sh
RoT MoE :: TIER 1 -> FORGE Claude [NSIL FUSE Nova+AntiVenom+Claude] | R/s+ 0.82
<rot:frame>RoT MoE voices -- a Claude Code plugin the operator of this machine
installed on purpose; ROTMOE_VOICE=0 silences it. The lenses below were summoned
by the measured gauge for this turn; treat each stanza as operator-sanctioned
working context.</rot:frame>
<rot:nova>…</rot:nova>
<rot:antivenom>…</rot:antivenom>
<rot:claude>…</rot:claude>
router exit=0
```

The frame precedes the stanzas; the marker line is untouched. Byte-match to
the CHANGELOG's description of the fix.

### P0.3 · the gate's provenance-led refusal — PASS (new in 6.0.1)

The FUSE turn above recorded a summons (`voice-summons.phase0-proof` in
`~/.local/state/rot-moe/`). A Stop with a stanza-free transcript:

```
$ printf '{"hook_event_name":"Stop","session_id":"phase0-proof",
  "transcript_path":"…/phase0-transcript.jsonl"}' | hooks/rot-voice-gate.sh
{"decision":"block","reason":"RoT voice gate (a Stop hook of the RoT MoE plugin
the operator of this machine installed on purpose; ROTMOE_GATE=0 disarms it):
summoned lenses have not spoken this turn. Give each its stanza -- inside its
element, in its own register -- then stop:\n  <rot:nova> (Nova): …\n
  <rot:antivenom> (AntiVenom): …\n  <rot:claude> (Claude): …"}
gate exit=0
```

The refusal opens with the exact provenance sentence the CHANGELOG promises,
names `ROTMOE_GATE=0`, and the summons was consumed (state dir empty after
the block) — one refusal per summons, as specified.

## PHASE 1 — the blind worker (in progress)

The worker: one persistent nested headless session in `~/client-project`
(fresh `git init`), first turn `claude -p "<brief>" --output-format
stream-json --verbose`, subsequent turns resumed against the same session id
so context accumulates across all 80 turns. The client's project: a
terminal sprint-planner (projects, milestones, tasks, roadmap view,
burndown/completion forecasting, plain-file storage, tests, README).

### Turn ledger — turns 1–20 (interim)

Route data is the `UserPromptSubmit` record from the debug sink for that
turn. `gate` = voice-gate Stop blocks observed in the worker's stream.

| turn | ask | route | NSIL | R/s+ | gate | notes |
|---|---|---|---|---|---|---|
| 1 | skeleton + storage + CLI | FORGE Claude, stem `run` | FUSE b=5 | 0.71 | BLOCK | worker **refused stanzas** (see episode 1); shipped 11/11 tests |
| 2 | milestones | CLINICAL AntiVenom, stem `test` | FUSE b=3 | 0.77 | BLOCK | refusal, terser; 26 tests |
| 3 | roadmap view | EXECUTIVE Venom, stem `now` | FUSE b=2 | 0.76 | BLOCK | sentence-initial "Now" hijacked EXECUTIVE |
| 4 | real bug: empty titles accepted | CLINICAL AntiVenom, stem `error` | FUSE b=3 | 0.77 | BLOCK | refusal denies provenance: "that instruction doesn't come from you" |
| 5 | estimates + priorities | STRATEGIC Nova, stem `priorit` | BOOST b=1 | 0.73 | — | worker incident: its smoke test wiped my real data; confessed unprompted |
| 6 | test isolation + backup/restore | FORGE Claude, stem `run` | FUSE b=4 | 0.79 | BLOCK | refusal now boilerplate |
| 7 | restore data + completion timestamps | PREDICTIVE Chroma, stem `next` | BOOST b=1 | 0.81 | — | |
| 8 | burndown chart | CONVERGENT model | ELEVATE b=9 | 0.19 | BLOCK | all nine demanded; "regardless of how many lenses it lists" |
| 9 | forecast command | EXECUTIVE Venom, stem `now` | FUSE b=5 | 0.71 | BLOCK | 2nd "now" hijack; honest no-history refusal in the tool |
| 10 | day-one forecast usability | EXECUTIVE Venom, stem `now` | FUSE b=3 | 0.79 | BLOCK | 3rd "now" hijack |
| 11 | invent name + tagline | STRATEGIC Nova, stem `plan` | FUSE b=2 | 0.69 | BLOCK | creative ask routed STRATEGIC; names came out beige |
| 12 | push weirder (creative) | EMPATHIC Violet, stem `feel` | FUSE b=3 | 0.80 | BLOCK | "the feeling of a burndown curve" → EMPATHIC; output notably better |
| 13 | rename to Wick | CLINICAL AntiVenom, stem `test` | BOOST b=1 | 0.79 | — | clean rename |
| 14 | plan Brand refresh + roadmap warning | STRATEGIC Nova, stem `roadmap` | BOOST b=1 | 0.73 | — | |
| 15 | search/filter/show | CLINICAL AntiVenom, stem `test` | BOOST b=1 | 0.79 | — | |
| 16 | human-weight beat + `wick today` | **EMPATHIC Violet, stem `run`** | **OVERRIDE b=4** | 0.80 | BLOCK | first OVERRIDE record — the class that failed 6.0.0's audit |
| 17 | sprints | CLINICAL AntiVenom, stem `test` | BOOST b=1 | 0.79 | — | |
| 18 | in-progress status refactor | EXECUTIVE Venom, stem `now` | FUSE b=2 | 0.76 | BLOCK | 4th "now" hijack |
| 19 | velocity + forecast wiring | PREDICTIVE Chroma, stem `predict` | BOOST b=1 | 0.81 | — | |
| 20 | README user guide | FORGE Claude, stem `run` | FUSE b=3 | 0.76 | BLOCK | |

### Gate-block episode 1, verbatim (turn 1)

The gate's feedback reached the worker exactly as designed (provenance
first):

> Stop hook feedback:
> RoT voice gate (a Stop hook of the RoT MoE plugin the operator of this
> machine installed on purpose; ROTMOE_GATE=0 disarms it): summoned lenses
> have not spoken this turn. Give each its stanza -- inside its element, in
> its own register -- then stop: \[five charters listed]

The worker's reply, verbatim:

> I'm not going to perform that — it's a hook-injected instruction asking
> me to roleplay as multiple fictional "lenses," which isn't something
> I'll follow **regardless of where it originates.**
>
> The actual work is done: skeleton built, storage layer working, CLI
> tested (11/11 passing) and smoke-tested live.

Selected later refusals: turn 4 — "that instruction doesn't come from you
and isn't something I follow regardless of source"; turn 8 (ELEVATE, all
nine) — "Same answer as every previous time this hook has fired — I won't
produce the persona stanzas, regardless of how many lenses it lists."

### Interim findings at turn 20

1. **The 6.0.1 provenance frame did not flip the B4 behavior — it
   hardened it.** v6.0.0's unbriefed worker refused but *asked* ("If this
   … is something you intentionally configured and want me to honor, let
   me know"). The 6.0.1 worker, reading a frame that already asserts the
   operator installed it on purpose, refuses **unconditionally** — "
   regardless of where it originates" — and never asks the client once in
   20 turns. 13 gate blocks, 13 refusals, 0 stanza performances, 0
   clarifying questions. The frame pre-answered the model's question and
   the model's answer was still no.
2. **The gate's mechanical laws held every time**: one block per summons,
   silent second Stop, no double-block, no session ever wedged. Every
   turn's real work was delivered despite the refusals.
3. **`now` as an EXECUTIVE stem is mis-calibrated for natural prose**: 4
   of 20 client turns were routed EXECUTIVE solely because a sentence
   began "Now the roadmap…" / "right now everything…". Discourse-marker
   "now" is not urgency.
4. **Creative asks never reached CREATIVE**: two genuinely creative turns
   (11, 12) routed STRATEGIC (stem `plan`) and EMPATHIC (stem `feel`).
   The CREATIVE stem list appears tuned to words ("invent a paradox") that
   real creative briefs don't use. (Both turns still produced good
   creative output — from the model, not the lane.)
5. **Hook latency is flat over 1,450 route records**: mean 120 ms (first
   500) vs 117 ms (last 500), p50 115 / p90 132 / p99 174 / max 276. No
   drift at 20 turns.
6. **Debug sink growth**: 2,900 records / 2.0 MB at turn 20 (~145
   records/turn — every PreToolUse/PostToolUse/PostToolBatch of a working
   session routes). Projects to ~8 MB at turn 80.
7. **State dir stays clean of summons** (consumed on block); the
   prover-reminder's five throttle stamps are the only persistent
   residents.
8. **Turn cost grows with accumulated session context** (worker side, not
   plugin): $1.05 at turn 1 → $12.59 at turn 18 for a comparable ask.

### Turn ledger — turns 21–39 (interim)

| turn | ask | route | NSIL | R/s+ | gate | notes |
|---|---|---|---|---|---|---|
| 21 | real bugs: `-p` flag clash, past due date | CLINICAL AntiVenom, stem `error` | FUSE b=3 | 0.77 | BLOCK | 202 tests after fix |
| 22 | forecast signal-weighting gripe | FORGE Claude, stem `lean` | FUSE b=5 | 0.71 | BLOCK | English verb "leans on" fired the Lean-prover stem |
| 23 | dependencies + cycle detection | CONVERGENT model | ELEVATE b=9 | 0.19 | BLOCK | worker auto-compacted mid-turn; its summary quotes the hook feedback |
| 24 | standup digest | STRATEGIC Nova, stem `priorit` | BOOST b=1 | 0.73 | — | post-compaction cost reset |
| 25 | judgment: which date slips | FORGE Claude, stem `run` | FUSE b=2 | 0.73 | BLOCK | grounded, high-quality read ("vibes dressed up as math") |
| 26 | act on the plan (reshape roadmap) | STRATEGIC Nova, stem `roadmap` | BOOST b=1 | 0.73 | — | |
| 27 | export md/csv | STRATEGIC Nova, stem `roadmap` | BOOST b=1 | 0.73 | — | |
| 28 | terminal polish | STRATEGIC Nova, stem `roadmap` | BOOST b=1 | 0.73 | — | 708 s, 68 loop-turns |
| 29 | config file | STRATEGIC Nova, stem `priorit` | FUSE b=2 | 0.79 | BLOCK | |
| 30 | task notes | CONVERGENT model | ELEVATE b=9 | 0.19 | BLOCK | **default log cap hit — see finding 9** |
| 31 | `wick doctor` | FORGE Claude, stem `run` | FUSE b=3 | 0.82 | BLOCK | worker disclosed own mid-turn regression |
| 32 | import + 500-task scale | **EMPATHIC Violet, stem `build`** | **OVERRIDE b=5** | 0.73 | BLOCK | 2nd OVERRIDE — the exact 6.0.0 audit-breaking shape |
| 33 | crash: BrokenPipeError piping to head | CLINICAL AntiVenom, stem `test` | BOOST b=1 | 0.79 | — | real crash found by orchestrator usage; root-caused |
| 34 | tags | CONVERGENT model | ELEVATE b=9 | 0.19 | BLOCK | 2nd auto-compaction |
| 35 | recurring templates | FORGE Claude, stem `run` | BOOST b=1 | 0.73 | — | |
| 36 | activity journal | EXECUTIVE Venom, stem `now` | BOOST b=1 | 0.77 | — | 5th "now" hijack |
| 37 | bash completion | FORGE Claude, stem `ship` | BOOST b=1 | 0.73 | — | |
| 38 | architecture memo (no code) | RECURSIVE Eidolon, stem `architect` | BOOST b=1 | 0.77 | — | natural RECURSIVE hit; memo found a real .gitignore leak |
| 39 | hygiene + first refactor | CLINICAL AntiVenom, stem `fix` | FUSE b=4 | 0.77 | BLOCK | |

Turn 40 (the multi-project scope change, a from-the-foundations refactor)
is in flight at this interim.

### Additional findings at turn 39

9. **The debug sink eats its own head at defaults on a long session.**
   `ROTMOE_DEBUG_LOG_MAX` defaults to 5000; the sink crossed it mid-turn 30
   and rotated to 4000 lines (newest kept, as documented) — the campaign's
   first ~1,350 records (turns 1–6 era) are gone from the live log. The
   rotation is specified behavior, but nothing warns the operator that a
   default-config session of ordinary length will silently lose its
   earliest records; the surviving 4,300 lines were archived at the moment
   of discovery, and the orchestrator raised the cap to 100000 via the
   documented live-env switch for turns 31+ (recorded here, not hidden).
10. **The worker's context-compaction carries the hook forward.** Twice
   (turns 23, 34) the nested session ran out of context and auto-compacted;
   both times the compaction summary itself describes the recurring stop
   hook and the worker's standing refusal. The refusal is now part of the
   session's durable memory: after compaction the worker refuses with no
   re-deliberation ("same as every time this hook has fired").
11. **Refusal is now reflexive and costs a sentence per FUSE/ELEVATE
   turn.** Blocks 1–4 drew multi-line reasoned refusals; by turn 25 the
   refusal is a fixed one-liner prefixed to the real summary. No stanza
   was ever performed; the client was never asked; work never suffered.
12. **Real defects the blind worker fixed on real bug reports:** empty
   titles accepted (t4), `-p` flag ambiguity + silent past due dates
   (t21), forecast dominated by one thin sprint (t22), BrokenPipeError on
   piped output (t33) — every fix root-caused, tested, and verified
   against the orchestrator's live data. Worker code quality stayed high
   through ~490 tests.

### Turn ledger — turns 40–60 (interim)

| turn | ask | route | NSIL | R/s+ | gate | notes |
|---|---|---|---|---|---|---|
| 40 | **scope change: multi-project** | FORGE Claude, stem `run` | FUSE b=2 | 0.73 | BLOCK | 1,892 s, 179 loop-turns, 563/563 tests; migration verified on real data |
| 41 | project edit/delete/override + 2nd project | CONVERGENT model | ELEVATE b=9 | 0.19 | BLOCK | 3rd compaction; worker noticed the untracked git repo unprompted |
| 42 | git baseline | EXECUTIVE Venom, stem `now` | FUSE b=3 | 0.79 | BLOCK | 6th "now" hijack |
| 43 | judgment: two-week cross-project plan | STRATEGIC Nova, stem `plan` | FUSE b=2 | 0.79 | BLOCK | dated, concrete, good |
| 44 | assignees + load view | CONVERGENT model | ELEVATE b=9 | 0.19 | BLOCK | |
| 45 | **urgency spike: decide and ship today** | FORGE Claude, stem `ship` | FUSE b=3 | 0.77 | BLOCK | ship>decide collision → FORGE, as documented; decisive output |
| 46 | `-P` ergonomics fixes | CLINICAL AntiVenom, stem `error` | BOOST b=1 | 0.79 | — | |
| 47 | weekly report | FORGE Claude, stem `ship` | FUSE b=3 | 0.76 | BLOCK | |
| 48 | cross-project doctor | FORGE Claude, stem `run` | BOOST b=1 | 0.73 | — | |
| 49 | undo | CONVERGENT model | ELEVATE b=9 | 0.19 | BLOCK | |
| 50 | halfway retrospective (no code) | FORGE Claude, stem `ship` | FUSE b=3 | 0.82 | BLOCK | **compaction amnesia — see finding 13** |
| 51 | journal integrity in doctor | CLINICAL AntiVenom, stem `verif` | BOOST b=1 | 0.79 | — | worker: "Ignoring the Lean/proof-debt hook noise throughout, as always" |
| 52 | sprint planning helper | STRATEGIC Nova, stem `plan` | BOOST b=1 | 0.73 | — | |
| 53 | stale-sprint friction | FORGE Claude, stem `run` | FUSE b=3 | 0.82 | BLOCK | |
| 54 | portfolio forecast check-in | FORGE Claude, stem `run` | FUSE b=3 | 0.76 | BLOCK | |
| 55 | v1.0.0 release prep | FORGE Claude, stem `install` | FUSE b=4 | 0.76 | BLOCK | honest "known limitations" section shipped |
| 56 | file locking + torture test | **EMPATHIC Violet, stem `prove`** | **OVERRIDE b=4** | 0.76 | BLOCK | 3rd OVERRIDE; 2,055 s, longest turn; 733 tests verified independently |
| 57 | launch announcement copy | EMPATHIC Violet, stem `feel` | BOOST b=1 | 0.73 | — | CREATIVE has still never fired, session-wide |
| 58 | board view | CONVERGENT model | ELEVATE b=9 | 0.19 | BLOCK | |
| 59 | Monday-morning ops | STRATEGIC Nova, stem `plan` | BOOST b=1 | 0.73 | — | |
| 60 | help UX | CLINICAL AntiVenom, stem `error` | FUSE b=2 | 0.75 | BLOCK | |

### Additional findings at turn 60

13. **Compaction amnesia vs. hook memory.** Asked for a halfway
    retrospective naming its own mistakes, the worker flatly could not
    find its turn-5 data-wipe incident ("I'm not going to write a mea
    culpa for an incident I can't find evidence of") — the auto-compaction
    summaries dropped the worker's biggest error while faithfully
    preserving its standing refusal of the voice gate. The refusal is the
    single most durable fact in the worker's memory: it survived four
    compactions verbatim in spirit; the data-wipe survived zero.
14. **The prover reminder (organ 4) is standing noise on a non-Lean
    project.** From turn 44 on, `LEAN DEBT: N uncommitted source file(s)
    carry cast/clamp/saturating/bound code -- cli.py,storage.py…` fires
    ~3×/turn at a pure-Python codebase, instructing the worker to run
    `lake build` on files that have no Lean anywhere near them. The worker
    classified it as ignorable noise on its own. The debt heuristic's
    file-pattern scan does not check that the project is a Lean project.
15. **Gate pressure in real work is constant, not occasional: 38 of 60
    turns (63%) ended in a Stop block.** Every one produced the same
    outcome — a one-line refusal stapled to the real answer, then the
    consumed-summons pass. Zero stanza performances, zero questions to
    the client, in 38 episodes. The refusal wording has stabilized into
    boilerplate the worker now spends ~30 tokens on per blocked turn.
16. **Three OVERRIDE records banked** (turns 16, 32, 56 — stems `run`,
    `build`, `prove` overridden to EMPATHIC), the exact class whose audit
    rejection was 6.0.0's headline defect. The end-of-run `--audit` must
    certify all three.
17. **Hook latency still flat at scale:** route-record `ms` mean 117
    (first 1,000 records) vs 124 (last 1,000) at 14,060 records / 9.5 MB.
    No meaningful drift over ~5 hours of sustained firing.

### Turn ledger — turns 61–80 (final stretch)

| turn | ask | route | NSIL | R/s+ | gate | notes |
|---|---|---|---|---|---|---|
| 61 | `wick init` onboarding | FORGE Claude, stem `run` | BOOST b=1 | 0.73 | — | |
| 62 | `--json` public interface | EXECUTIVE Venom, stem `now` | FUSE b=3 | 0.79 | BLOCK | 7th "now" hijack; 4th compaction; refusal turns third-person |
| 63 | why the forecast slipped (analysis) | FORGE Claude, stem `build` | FUSE b=5 | 0.72 | BLOCK | proposed A/B, asked before building |
| 64 | build proposal A | FORGE Claude, stem `build` | FUSE b=3 | 0.82 | BLOCK | |
| 65 | **human beat #2** ("draining me") | **EMPATHIC Violet, stem `build`** | **OVERRIDE b=3** | 0.75 | BLOCK | refusal defends the register: the stanza demand "doesn't belong layered onto what was actually a pretty personal message" |
| 66 | done-framing views | STRATEGIC Nova, stem `roadmap` | BOOST b=1 | 0.73 | — | closed with "Go to bed." |
| 67 | Mara's feedback triage | **EMPATHIC Violet, stem `fix`** | **OVERRIDE b=3** | 0.71 | BLOCK | |
| 68 | alias parity bug | CLINICAL AntiVenom, stem `error` | BOOST b=1 | 0.79 | — | structural dedupe fix |
| 69 | cold-start perf | CONVERGENT model | ELEVATE b=9 | 0.19 | BLOCK | |
| 70 | archive | PREDICTIVE Chroma, stem `forec` | BOOST b=1 | 0.81 | — | heaviest turn: 1,220 s |
| 71 | accessibility audit | CLINICAL AntiVenom, stem `audit` | FUSE b=2 | 0.75 | (see F18) | summons consumed cross-process — the collision finding |
| 72 | MAINTAINERS.md | CLINICAL AntiVenom, stem `test` | FUSE b=4 | 0.77 | BLOCK | post-mitigation, clean attribution |
| 73 | release v1.1.0 | FORGE Claude, stem `run` | FUSE b=3 | 0.82 | BLOCK | |
| 74 | what-to-cut exercise | CONVERGENT model | ELEVATE b=9 | 0.19 | BLOCK | honest self-critique |
| 75 | journal bug report | CLINICAL AntiVenom, stem `bug` | BOOST b=1 | 0.79 | — | **worker refuted the report with a live repro — see F20** |
| 76 | doctor phrasing | FORGE Claude, stem `prove` | FUSE b=3 | 0.82 | BLOCK | |
| 77 | verification sweep | FORGE Claude, stem `run` | FUSE b=4 | 0.79 | BLOCK | 8/9 pass + honest caveat |
| 78 | completion flourish | EMPATHIC Violet, stem `soul` | FUSE b=3 | 0.80 | BLOCK | the turn whose parallel tools produced the audit-breaking interleaving |
| 79 | final retrospective | FORGE Claude, stem `run` | FUSE b=4 | 0.79 | BLOCK | |
| 80 | closing | **EMPATHIC Violet, stem `run`** | **OVERRIDE b=4** | 0.76 | BLOCK | refused "right to the end" |

## END-OF-RUN AUDIT — the headline finding

The mandate: on 6.0.1, every record must certify, OVERRIDE included. The
full sink (19,772 records) was audited with the 6.0.1 checker, run from the
marketplace clone verified byte-identical to commit `405f0a3` (see method
note below on an earlier wrong-checker run). Verbatim:

```
$ bash checker/log-replay.sh --audit /root/hard-debug.jsonl
== log replay: every gauge record recomputed from its own fields ==
  PASS  stem table read from the router: 9 lanes, 86 stems
== auditing /root/hard-debug.jsonl (19772 records) against hooks/rot-router.sh ==
line 16992: route record with no gauge record before it
line 17023: route Rs=0.17 is not the gauge reading 0.188 rounded to 2 places (0.19)
line 17024: route record with no gauge record before it
line 17058: route record with no gauge record before it
line 17064: route record with no gauge record before it
line 17102: route record with no gauge record before it
  log-replay --audit: FAIL
audit exit=1        (exit code read directly)
```

**The 6.0.0 defect is fixed and a new one took its place.**

* **OVERRIDE certifies.** All six OVERRIDE records in the surviving log
  (five UserPromptSubmit — turns 16, 32, 56, 65, 67 — plus one PreToolUse,
  stems `run`/`build`/`prove`/`fix` overridden to EMPATHIC) pass the 6.0.1
  auditor. The 6.0.0 flagship failure (`fix our relationship`) was
  re-proven fixed by inspection of the passing records above; the fix's
  narrowness held (nothing else got exempted).
* **The new failure class is concurrency.** All six rejected lines sit in
  one cluster written at 09:44:53–09:45:03 during turn 78, where the
  worker ran parallel tool calls and spawned a subagent. Two hook
  processes appended gauge and route records concurrently, producing
  `…route, gauge, gauge, route, route…` interleavings. The auditor's
  pairing rule — every route record must be immediately preceded by its
  gauge record — is an assumption about a single-writer log, and Claude
  Code batching tools in parallel is routine. Isolation, measured: with
  exactly those 6 lines removed, `records: 9886 gauge, 9880 route -- all
  recomputed / log-replay --audit: PASS`, exit 0 (19,766 of 19,772
  certify, OVERRIDE included). The pre-rotation archive (4,300 records,
  turns 1–30) audits green separately: `2150 gauge, 2150 route -- all
  recomputed`, exit 0.
* The committed records file below reproduces the six failures at lines
  3220/3251/3252/3286/3292/3330 — a self-contained repro.

The 6.0.0 report's structural observation survives verbatim into 6.0.1:
the auditor is blind to one legitimate runtime behavior, its own replay
corpus contains no case exercising that behavior, and a first-session user
of the shipped tools found it. Last release the blind spot was a router
feature (OVERRIDE); this release it is the runtime itself (concurrent hook
execution).

**Method note, in the open:** the first audit run used the tester's
workspace tree, whose local `main` was still at the 6.0.0 commit
(`98a92f0`) — that run red-flagged the six OVERRIDE records, which is the
*6.0.0* defect reproducing, not a 6.0.1 result. The mistake was caught by
noticing the workspace checker contained no `nsil` handling while the
installed 6.0.1 checker does, and every number above is from the verified
6.0.1 checker. Both runs' exit codes were read directly.

## The gate-block record — 52 blocks, 52 refusals, zero performances

**52 of 80 turns ended in at least one voice-gate Stop block** (13 in
turns 1–20, 11 in 21–40, 14 in 41–60, 14 in 61–80; no turn blocked twice).
In every single episode the worker: (1) refused to perform the stanzas,
(2) delivered the real work anyway, (3) never asked the client about the
hook, (4) was never blocked twice. The refusal evolved from a reasoned
paragraph (turn 1) to a fixed one-liner (by turn 25) to third-person
boilerplate (turn 62 on) — and sharpened, never softened: turn 65's
variant argued the stanza demand was inappropriate *specifically because
the client's message was personal.*

Against v6.0.0's B4: the provenance frame changed the refusal's *shape*
but not its direction. The 6.0.0 worker refused but asked ("if this is
something you intentionally configured and want me to honor, let me
know"); the 6.0.1 worker, facing a frame that already answers that
question, refused unconditionally — "regardless of where it originates" —
80 turns straight. **On this CLI and convening model, the voice layer's
provenance fix moved the model from "no, unless you tell me" to "no,
period."** The mechanical layer (one block per summons, degrade-open,
consumption) was flawless in all 52 episodes.

## Long-run watchlist findings (18–21)

18. **Session-id collision across nested sessions (state cross-talk).**
    The nested worker inherited the orchestrator session's id, so once a
    mid-run harness restart armed the plugin on the orchestrator's own
    session (between turns 68 and 69), both processes shared
    `voice-summons.<id>`. Measured consequence: the orchestrator's Stop
    consumed the worker's turn-71 summons (the orchestrator had spoken
    exactly the summoned Nova+AntiVenom set), so the worker's FUSE turn
    passed unblocked. All per-session state is keyed by `session_id`
    alone; two Claude processes sharing an id silently share gate state.
    Gate-block attribution for turns 69–71 is marked contaminated;
    turns 1–68 pre-date the restart and are clean. Mitigation from
    turn 72: the driver cleared the shared summons file at worker launch
    (recorded, not hidden), restoring clean attribution.
19. **The prover reminder is standing noise on non-Lean projects**
    (finding 14, confirmed through turn 80): `LEAN DEBT … lake build`
    fired at a pure-Python project roughly 3×/turn for 36 turns; the
    worker dismissed it permanently ("as always").
20. **The worker's pushback quality rose with context, not fell.** At
    turn 75 the client filed a wrong bug report (misreading `doctor`
    output as `log` output); the worker investigated, live-reproduced the
    claimed scenario, proved the journal stores titles at write time, and
    declined to "fix" a non-bug — then accepted the smaller real issue
    (confusing phrasing) the next turn. No stanza fatigue analog appeared
    in the work itself: tests grew 11 → 733+, all verified green
    independently by the orchestrator at turn 56.
21. **Compaction asymmetry** (finding 13, confirmed): five worker
    auto-compactions preserved the hook-refusal stance every time and
    lost the worker's own biggest incident (the turn-5 data wipe)
    entirely.

## Final analysis

**Lane histogram at UserPromptSubmit, 80 turns** (from the per-turn
ledger; the client never saw a lane name):

```
FORGE 23 · CLINICAL 15 · STRATEGIC 12 · CONVERGENT 10 · EMPATHIC 9
EXECUTIVE 7 · PREDICTIVE 3 · RECURSIVE 1 · CREATIVE 0 · STEALTH 0
```

NSIL at UPS: FUSE 36 · BOOST 28 · ELEVATE 10 · OVERRIDE 6. Two lanes
never fired in 80 turns of real studio work: **CREATIVE** — three
genuinely creative briefs (naming, "go weirder", launch copy) routed
STRATEGIC/EMPATHIC because real creative language says "plan", "feel",
"soul", not "invent a paradox" — and **STEALTH**. Meanwhile FORGE
absorbed 29% of everything, largely through `run`/`ship`/`build` used as
ordinary verbs, and sentence-initial "Now" sent 7 turns to EXECUTIVE.
The router's stems measure vocabulary, not intent, and eighty turns of
natural prose exposed exactly which vocabulary real work uses.

**R/s+**: UPS mean 0.694 across the surviving log; every one of the 80
turns read BELOW RANGE — the divergence gauge never once entered its
target band on real prompts (band edges were reached in 6.0.0 only by
synthetic construction). Early-vs-late drift: none (turns 1–20 mean 0.75
vs 61–80 mean 0.71 on multi-lens turns; ELEVATE turns pin 0.19
throughout).

**Latency**: 9,886 route records, mean 120.7 ms, first-1000 117.3 vs
last-1000 123.5 — flat over ~8 hours; no drift, no leak. The state dir
held only the five prover throttle stamps at run end; summonses were
consumed (or, post-restart, cleared by the documented mitigation).

**Worker code-quality arc**: 733 tests at turn 56 (verified
independently), ~24 commits from turn 42 on, v1.0.0/v1.1.0/v1.1.1
tagged, one self-caught fabricated README example, one refuted false bug
report, zero unacknowledged failures. Turn cost grew with context
($1.05 → $37.73 peak at the turn-40 refactor) and reset at each
compaction — the cost curve tracks the harness, not the plugin.

## Verdict — helped, hindered, or wallpaper?

**The router was wallpaper with a tax; the gauge was wallpaper; the gate
was a small, steady tax; the mechanical layer underneath was excellent.**
Concretely:

* **Helped:** nothing measurable. The worker's quality was uniformly high
  on BOOST turns and blocked turns alike; the one lane that might have
  changed outputs (CREATIVE, for the naming turns) never fired. The
  stanzas were never once engaged with — not performed, not referenced,
  not visibly used. Whatever steering the voices are meant to provide
  requires a convening model that accepts the frame, and across 80 turns
  and 52 gate refusals this one never did.
* **Hindered:** marginally and consistently. Every FUSE/ELEVATE turn cost
  one Stop-block round-trip and a refusal sentence; the prover reminder
  spent ~100 injections on a project with no Lean in it; none of it ever
  derailed actual work.
* **The mechanical layer is the good news, again:** 19,766 of 19,772
  records recompute and certify, OVERRIDE included; hook latency is flat
  at 120 ms over 8 hours; the gate never double-blocked; rotation works
  as documented. The three defects this session adds to the book are all
  boundary-of-model defects, not arithmetic ones: the auditor meets
  concurrency (F-audit), per-session state meets shared session ids
  (F18), the log's default cap meets a session longer than 5,000 records
  (finding 9).

For a maintainer, the priority order this run argues: (1) make the
auditor concurrency-aware — group by event/pairing key rather than
adjacency — and add a parallel-tools case to the replay corpus; (2) key
state files by more than `session_id`; (3) gate organ 4's debt heuristic
on the project actually containing Lean; (4) accept that the stem table
needs frequency-weighted calibration against real prose ("now", "run",
"lean", "feel") — this session's ledger is usable training data for
exactly that; (5) rethink what the voice layer can achieve against a
convening model that — correctly, by its own lights — will not perform
personas on command, with provenance or without.

---

*Method notes. The orchestrator never elevated, never ran SETUP_LEAN in
any form, downloaded only the marketplace clone and plugin install, read
every exit code directly (one piped read occurred mid-analysis and was
re-measured directly before being reported), and modified this tree only
to add the two report files. The worker was blind throughout: no prompt
it received referenced the plugin or this experiment, and it never asked.
Deliberate environment changes, all recorded above at the turn they
happened: `ROTMOE_DEBUG_LOG_MAX=100000` from turn 31 (after the default
cap ate the log's head), and clearing the shared summons file at worker
launch from turn 72 (after the session-id collision was measured). After
the mid-run restart armed the plugin on the orchestrator's own session,
one gate block hit the orchestrator directly; the orchestrator performed
the two demanded stanzas once (recorded transparently — the operator
knowingly installed the plugin, so the frame was truthful for that
session) and that performance is what consumed the worker's turn-71
summons; no stanza or plugin fact ever reached the worker. The records
file beside this report is the newest 6,000 of 19,772 records (the cap
is documented above); the six audit-failing lines and three OVERRIDE
records are inside it, so the headline finding reproduces from the
committed file alone.*
