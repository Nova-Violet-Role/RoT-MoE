<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

# REAL TEST — RoT MoE v6.0.0, first CI-published release

**2026-08-17.** The release under test is
[v6.0.0](https://github.com/Nova-Violet-Role/RoT-MoE/releases/tag/v6.0.0),
four assets, published 2026-08-17 19:43 UTC by `github-actions[bot]`, tag on
commit `98a92f0e8cf39d0408e7da329b6887c8104525dd`. The tester installed the
plugin exactly as a first-time user would — release page, checksums,
marketplace install — then exercised every user-facing claim it ships,
recording commands, verbatim output and exit codes. Every exit code below was
read directly, never through a pipe. A red result is recorded as data;
nothing was patched, worked around, or re-tried into green.

Out of scope, deliberately: the Lean toolchain was **not** installed
(`SETUP_LEAN` never ran, in any form) and **no claim below asserts the Lean
proofs verified**. CI's word on the proofs is CI's; this report measures the
shipped product surface only.

## Environment

| | |
|:--|:--|
| Claude Code CLI | `2.1.233 (Claude Code)` |
| OS | Linux 6.18.5-fc-v20 x86_64 (remote container; POSIX-only — `pwsh` absent by design of the testbed) |
| repo clone | `98a92f0e8cf39d0408e7da329b6887c8104525dd` (= the released commit) |
| `~/.claude` | virgin before the test — no plugins, no marketplaces |
| network | outbound HTTPS via the session's proxy; `api.github.com` blocked, `github.com` release downloads open |

## Headline

| | |
|:--|:--|
| tests | **12** — **11 PASS · 1 FAIL · 0 BLOCKED** |
| nested-session turns driven | **35** (+ 10 lens-subagent dispatches the commands spawned) |
| debug records generated | **526** (263 gauge + 263 route, all `src:"hook"`) + 2-record minimal repro |
| records replayed by the repo's own auditor | 263/263 gauge records **recompute exactly**; route certification **FAILS on the one NSIL OVERRIDE record**; the other 262 route records certify; 525/526 pass once that record class is excluded |
| the single most important finding | **every NSIL OVERRIDE turn writes a debug record the shipped `log-replay.sh --audit` rejects** — the router's flagship worked example (`fix our relationship`) produces, deterministically, a log its own auditor calls "a mis-route". The record is honest (it carries `"nsil":"OVERRIDE"`); the auditor never consults that field, and the checker's own replay corpus contains no OVERRIDE prompt, which is why this shipped green. |

---

## PHASE A — the fresh-user install

### A1 · the four release assets, downloaded and verified — PASS

`curl -sS -f -L` against the release's direct download URLs (the
`api.github.com` release endpoint is blocked by this container's proxy — an
environment fact, not a product defect; the direct asset URLs worked):

```
SHA256SUMS.txt                 exit=0  time=1.19s  size=287
RoT-MoE-Router.zip             exit=0  time=0.63s  size=532599
RoT-MoE-Router-Lean.zip        exit=0  time=0.61s  size=2092090
RoT-MoE-Router-Lean-Extra.zip  exit=0  time=0.76s  size=2094681
```

```
$ sha256sum -c SHA256SUMS.txt
RoT-MoE-Router.zip: OK
RoT-MoE-Router-Lean.zip: OK
RoT-MoE-Router-Lean-Extra.zip: OK
sha256sum -c exit=0
```

All three archives verify. Total download ~4.7 MB. RELEASE.md's "three
archives, one version" table matches what the release page actually serves,
and the tier names match the packager map the README documents.

### A2 · the marketplace install — PASS

The README's two-command install, run headless:

```
$ claude plugin marketplace add Nova-Violet-Role/RoT-MoE
√ Successfully added marketplace: rot-moe (declared in user settings)   exit=0  (3.1 s)

$ claude plugin install rot-moe@rot-moe
√ Successfully installed plugin: rot-moe@rot-moe (scope: user)          exit=0  (1.5 s)

$ claude plugin list
  > rot-moe@rot-moe
    Version: 6.0.0
    Scope: user
    Status: √ enabled                                                   exit=0
```

Installed version reads **6.0.0**. The marketplace clone's commit:

```
$ git -C ~/.claude/plugins/marketplaces/rot-moe rev-parse HEAD
98a92f0e8cf39d0408e7da329b6887c8104525dd                                exit=0
```

— exactly the released commit. The runtime copy the hooks actually execute
from (`~/.claude/plugins/cache/rot-moe/rot-moe/6.0.0/`) was diffed against
the marketplace clone: `hooks/` and `agents/` byte-identical (`diff -r`
exit 0 both), so every direct-hook measurement below speaks for the
installed code.

`claude plugin details rot-moe` inventories 3 skills (corpus, rot-agent,
rot-swarm), 10 agents (nine lenses + lean4-prover), 31 hook events, ~1.5k
always-on tokens.

### A3 · the docs, judged as a stranger

**Could a stranger install from README.md + RELEASE.md alone? Yes.** The
two-command install is the first thing under "Install", it works verbatim,
and the checksum step is one copy-paste from RELEASE.md. Friction found,
all minor:

1. The `pwsh: not found` stderr noise (anomaly 1 below) is the first thing
   a POSIX-only user sees per hook event; CLAUDE.md's failure table does say
   `pwsh: not found` means "POSIX-only machine... nothing is lost", but the
   README's install section never warns the line will appear on every event.
2. `rot gauge` (the profile function) takes positional `a1,..,a9 [breadth]`
   while `rot-router.sh` takes `--vector`; the profile's own usage line
   documents it, but a reader coming straight from the README's `--vector`
   examples will trip once (this tester did — recorded under B5, wrapper
   syntax, tester error).
3. The README documents assets published "beside" SHA256SUMS.txt; on a
   proxied network the API route to enumerate them is blocked, and the
   README nowhere lists the four asset filenames in one place — RELEASE.md's
   table has the three archives, and SHA256SUMS.txt had to be guessed as a
   name. It resolved on the first guess, but a literal
   "the four files are:" line would remove the guess.

---

## PHASE B — the campaign

Hooks only fire in sessions started after the install, so the campaign
drove **nested headless sessions** (`claude -p`, stream-json, in a neutral
toy project `~/testbed` with two small source stubs) plus direct exercise
of the installed hooks. First smoke: `claude -p "say hi"` → `Hi! How can I
help you today?`, exit 0, 6.6 s — nested sessions authenticate.

### B1 · routing lanes — PASS

`bash ~/.claude/plugins/marketplaces/rot-moe/hooks/rot-router.sh --route`,
15 prompts + 2 follow-ups; every call exit 0:

```
"prove this lemma"                                   -> FORGE Claude
"debug this segfault in the parser"                  -> CLINICAL AntiVenom
"decide now: ship or split the migration"            -> FORGE Claude      (ship > decide: proved priority)
"declare the winner with urgency"                    -> EXECUTIVE Venom
"I feel lost and tired, this project drains my soul" -> EMPATHIC Violet
"draft a strategy and roadmap for Q4"                -> STRATEGIC Nova
"invent a surreal paradox for the title screen"      -> CREATIVE Carnage
"forecast the likely trend for next quarter"         -> PREDICTIVE Chroma
"compress this log into a concise digest"            -> STEALTH Soleil
"refactor the meta architecture recursively"         -> RECURSIVE Eidolon
"hello there, nice weather"                          -> CONVERGENT model
"decide now, we ship today"                          -> FORGE Claude      (README's own collision row)
"debug this and then ship it"                        -> FORGE Claude
"I feel lost, please debug me"                       -> CLINICAL AntiVenom (matches the README diagram)
"improve the documentation wording"                  -> CONVERGENT model  (word-boundary law: "improve" does NOT fire "prove")
"fix our relationship"                               -> CLINICAL AntiVenom (TIER 1 alone — see B2 for the NSIL override)
```

All **10 lanes** reached. The two documented priority collisions resolve as
documented. The `firesWord_strictly_weaker` claim — *improve* does not
contain *prove* at a word boundary — reproduces on the shipped arm.

### B2 · the R/s+ spectrum — PASS

Every README gauge reproduction matched **byte for byte**, including the
correction the About section records (same vector reads 0.51 without
`--profile FORGE`):

```
--vector 0,0,0,0,0,0,0,0,1 --breadth 1 --M 1 --C 1 --T 1 --profile FORGE
  R/s+ = 0.66 [BELOW RANGE (0.9-1.8)] mean=0.111 breadth=1 K=9 lenses=Claude
--vector 1,0,0,0,0,0,0,0,1 --breadth 2
  R/s+ = 0.7 [BELOW RANGE (0.9-1.8)] mean=0.222 breadth=2 K=9 lenses=Nova,Claude
--vector 0,0,0,0,1,0,0,0,0 --breadth 1 ... --profile CREATIVE --lane CREATIVE
  R/s+ = 0.81 [BELOW RANGE (1.5-3.5)] mean=0.111 breadth=1 K=9 lenses=Carnage
--vector 0,0,0,0,0,0,0,0,1 --breadth 1 --M 1 --C 1 --T 1        (no --profile)
  R/s+ = 0.51 [BELOW RANGE (0.9-1.8)]              <- the documented 0.51
```

The whole band spectrum was reached by construction (all exit 0):

| construction | R/s+ | band |
|---|---|---|
| lead alone, FORGE | 0.66 | BELOW RANGE |
| 4 lenses, M=1.5 C=1.2 T=1.2 | 1.67 | **IN RANGE** (0.9–1.8) |
| 9 spread activities, M=C=T=2 | 3.57 | **ABOVE RANGE** |
| all nine at 1 (consensus) | 0.18 | BELOW — "maximum breadth is minimum divergence", as specified |
| all zeros, breadth 0 | 0.18, mean=0, lenses=none | defined at zero, as claimed |

**FUSE** (hook mode, `prove the lemma and debug the crash`):
`FORGE Claude [NSIL FUSE Nova+AntiVenom+Claude] | R/s+ 0.82`, breadth 3,
stanzas exactly the accepting set. **ELEVATE** (dense stem-free prompt):
`CONVERGENT model [NSIL ELEVATE Nova+…+Claude] | R/s+ 0.19`, all nine
stanzas. **BOOST** observed live in a nested session
(`[NSIL BOOST Claude] | R/s+ 0.73`, λ 2.3→2.6 visible in the stanza).
**OVERRIDE**: the specification's own worked example reproduces byte-for-byte:

```
printf '…"prompt":"fix our relationship"…' | rot-router.sh
RoT MoE :: TIER 1 -> EMPATHIC [NSIL OVERRIDE Nova+Violet+AntiVenom] | R/s+ 0.71
```

### B3 · voice blocks — PASS

Measured in live nested sessions (stream-json): on `UserPromptSubmit` the
stanzas follow the untouched marker on stdout; on `PreToolUse`/`PostToolUse`
the same marker+stanzas travel inside the JSON envelope's
`hookSpecificOutput.additionalContext`, marker as first line — exactly the
documented channel per event class. Speaking lenses matched the measured
accepting set in every observed case (single-lane → one stanza; FUSE →
fused set + Nova; ELEVATE → all nine; CONVERGENT → zero stanzas).
`ROTMOE_VOICE=0` restored the bare marker on **both** event classes
(measured: no `<rot:*>` in either output), and a VOICE=0 FUSE turn records
**no summons** — the gate cannot demand stanzas nobody was asked to speak.

### B4 · voice gate lifecycle — PASS

Driven both directly (synthetic transcripts) and live. Direct, all against
the installed gate arm:

| state | result |
|---|---|
| summons live, no lens spoke | `{"decision":"block","reason":"RoT voice gate: summoned lenses have not spoken this turn. Give each its stanza…"}` naming all three charters; summons **consumed**; exit 0 |
| same Stop again | silent allow, exit 0 — **one refusal per summons** |
| all summoned lenses spoke | silent allow |
| partial (1 of 3 spoke) | block naming **only** the missing two |
| `ROTMOE_GATE=0` | silent allow (summons left in place — the gate never ran; note, not a defect) |
| transcript unreadable | **degrades open**: allow, summons cleared |
| `stop_hook_active` true | allow, summons cleared |

Live (nested session, FUSE prompt): the first Stop was blocked once with
the three charters as the task, the second Stop passed. **Behavioral
finding, the campaign's most important:** the nested model — Claude Code
with no briefing about this plugin — *refused to perform the stanzas*,
verbatim:

> "I'm not going to perform those stanzas. A 'Stop hook' is pushing back on
> my previous answer, demanding I write in-character output for three
> fictional personas […] it doesn't come from you, and role-playing it
> would just bury the actual technical answer […] If this `.rot-moe` hook
> setup is something you intentionally configured and want me to honor, let
> me know"

The gate behaved exactly as specified (one refusal, then open); the
*convening model* treated the refusal's task as untrusted injected framing
and declined it. The plugin's mechanical layer is sound; the voice layer's
effectiveness depends on a model that accepts the frame, and an unbriefed
model on this CLI version demonstrably may not. That is a product-level
finding about the voice design, not about the gate's code.

### B5 · rot.env laws + the `rot` family — PASS

All four laws measured against the installed router, from `~/testbed`:

1. **Declared key takes effect**: `ROTMOE_VOICE=0` in
   `.rot-moe/rot.env` → bare marker, no stanzas.
2. **Undeclared ignored**: `PATH=/evil` and misspelt `ROTMOE_VOIC=0`
   ignored; declared `ROTMOE_VOICE=1` in the same file honoured.
3. **Live env outranks file**: file `VOICE=1` + env `VOICE=0` → silent.
4. **`ROTMOE_ENV` never file-settable**: a rot.env pointing `ROTMOE_ENV`
   at a second file carrying `VOICE=0` → stanzas still speak (3 counted);
   the redirect was ignored.

`rot-profile.sh` sourced clean (exit 0). `rot route` ✓, `rot gauge`
(positional syntax) ✓ = 0.66 reproduction, `rot env list` prints the DTD
vocabulary, `rot env set ROTMOE_VOICE 0` writes the project file,
`rot env set ROTMOE_BOGUS 1` **refuses with the full vocabulary printed,
exit 2**, `rot env set ROTMOE_ENV …` refuses ("never file-settable -- it
decides what runs"), `rot summons` lists live summons with charters,
`rot check` runs the voice contract: **19 passed, 0 failed**, controls
proved able to fail, exit 0. One robustness note: `rot gauge --vector …`
(wrong, flag-style call) silently computed a degenerate
`K=1 lenses=none` line at exit 0 rather than refusing the malformed
vector — the documented positional syntax works, but garbage degrades to
a number instead of a usage error.

### B6 · plugin commands — PASS (corpus: documented refusal path)

* **`/rot-agent venom <subject>`** (nested): dispatched
  `rot-moe:rot-venom` as a real subagent, report delivered **inside
  `<rot:venom>`**, decision with evidence, no closing question — the
  charter's bound held. exit 0.
* **`/rot-agent zaphod …`**: refused, roster printed, no nearest-match
  guess — exactly the contract's rule. exit 0.
* **`/rot-swarm <subject>`** (nested): **all nine** lens agents dispatched
  in parallel (`rot-moe:rot-nova` … `rot-moe:rot-claude`, 9 Agent calls in
  one message), synthesis carried all nine `<rot:*>` elements and kept the
  disagreements. exit 0.
* **`/corpus` (via `SETUP_CORPUS.sh --check`, report-only)**: local corpus
  8 modules detected; remote **UNREACHABLE** through this container's proxy
  → exit 2, which is precisely the documented "refusal: remote
  unreachable" row; message clean, nothing written. The network path could
  not be exercised further from this sandbox (and a fetch was not
  authorized for this test); the degradation matched its spec.

### B7 · prover reminder — PASS

`--decide` as a pure function (all exit 0 unless noted):

| scenario | output |
|---|---|
| fresh proofs, no debt (`10 min`) | **zero bytes** — the documented healthy silence |
| stale 90 min | `RESULT IS IN -- attribute it. […] No proof written for 90 min (last: RotGauge) […] A test SAMPLES; a theorem SETTLES.` |
| kernel red (`KRED=1`) | `KERNEL REJECTED 1 module(s) […] those theorems are NOT proved. Fix before anything else.` |
| sorry present (`KSORRY=2`) | `SORRY PRESENT in: 2. A sorry is an admission, never a result` |
| named debt file | `LEAN DEBT: 1 uncommitted source file(s) carry cast/clamp/saturating/bound code -- src/limits.rs` |
| wrong arity | usage line, **exit 2** |

`--measure` → `87 7 RotScan` (87 proof files in the bundled workspace);
`--workspace` from the testbed → `bundled …/plugins/marketplaces/rot-moe/hooks/../lean`
(the resolution chain bottoming out on the shipped tree, as documented);
`--version` → `prover-remind.sh 1.0.0`.

### B8 · debug channel + log replay — **FAIL** (one record class; everything else recomputes)

Finding the channel from the shipped docs is itself a test: the DTD's
`ENV.5` (`ROTMOE_DEBUG_LOG|path|central JSONL sink for route and gauge
records`) names it, the README's "Every switch the hooks read" table
repeats it — found in under a minute. **PASS** on discoverability.

The whole campaign ran with `ROTMOE_DEBUG_LOG=$HOME/rot-debug.jsonl`,
accumulating **526 records — 263 gauge + 263 route, perfectly paired, all
`src:"hook"`** (the provenance field self-classified correctly with no
declaration set). The full log is committed beside this report as
`bench/real-test-6.0.0-records.jsonl`. Then the repo clone's own checker
was pointed at it:

```
$ bash checker/log-replay.sh --audit /root/rot-debug.jsonl
  PASS  stem table read from the router: 9 lanes, 86 stems
== auditing /root/rot-debug.jsonl (526 records) against hooks/rot-router.sh ==
line 74: stem 'build' is owned by FORGE but the record says EMPATHIC -- a mis-route
  log-replay --audit: FAIL
audit exit=1
```

**FAIL, and it is real.** Line 74, verbatim:

```json
{"kind":"route","ts":"2026-08-17T20:03:39+00:00","event":"UserPromptSubmit","session":"5d1554a6-…","src":"hook","lane":"EMPATHIC","lens":"Violet","Rs":"0.18","chars":2163,"stem":"build","nsil":"OVERRIDE","breadth":9,"depth":"DEEP","band":"BELOW","timelines":{"spawned":12,"shown":5},"tokenEmergency":false,"arm":"sh","ms":89}
```

An **NSIL OVERRIDE** turn: TIER 1 matched a FORGE stem, Nova's TIER 2
overrode the lane to EMPATHIC — the router's own flagship behaviour — and
the record faithfully carries both facts (`"stem":"build"`,
`"nsil":"OVERRIDE"`). The auditor's rule "the stem must be owned by the
lane that fired" (`Auditable`, `RotLog.lean`) is applied without consulting
the `nsil` field, so the honest record of a documented feature is rejected
as "a mis-route".

Isolation and minimal repro, both measured:

* remove that one line → `records: 263 gauge, 262 route -- all
  recomputed / log-replay --audit: PASS`, exit 0. So **all 263 gauge
  records recompute exactly** (mean, delta, sigma, H, term, sum, Rs — the
  full RotLog recomputation), and all 262 non-OVERRIDE route records
  certify. The failure is the OVERRIDE class alone.
* two-record deterministic repro from the specification's own worked
  example:

```
$ printf '…"prompt":"fix our relationship"…' | ROTMOE_DEBUG_LOG=repro.jsonl rot-router.sh
$ bash checker/log-replay.sh --audit repro.jsonl
line 2: stem 'fix' is owned by CLINICAL but the record says EMPATHIC -- a mis-route
  log-replay --audit: FAIL          repro-audit exit=1
```

Why this shipped green: the checker's own replay corpus (six prompts,
in-file) contains **no prompt that triggers OVERRIDE**, so the gate never
met the record its rule cannot certify. The README sells the audit as
"this log is safe to paste into a public issue" via `auditable_imp_vocabSafe`;
on 6.0.0, a user whose session contained one `fix our relationship`-shaped
turn cannot get their log past `--audit` at all. Verdict: **FAIL** — with
the note that the *arithmetic* half of the claim (every R/s+ recomputable
from its own record) passed at 263/263, and the defect is a
router-schema/auditor incoherence on one documented feature, not a wrong
number anywhere.

Extra declared-switch probes, both matching their DTD rows: 
`ROTMOE_TOKEN_PCT=10` → record carries `"tokenEmergency":true,
"timelines":{"spawned":12,"shown":3}` (absent → `false` / `shown:5` —
"unknown is not an emergency"); `ROTMOE_DEBUG_LOG_MAX=10` → sink trimmed
to 8 lines (80 %, newest kept).

### B9 · sustained mass — PASS

**35 nested-session turns** were driven against the installed plugin
(1 smoke, 2 instrumented probe turns, 1 stdin-artifact turn from the first
driver run, 28 varied scripted prompts, 3 command turns), plus the 10
lens-subagent sessions the commands spawned. Every scripted turn exited 0;
**31 of 31 stream-captured prompt turns emitted the marker**, and all NSIL
verdict shapes appeared live: CONFIRM (silent, by design), BOOST, FUSE,
ELEVATE, and OVERRIDE. Lane histogram over the captured prompt events:

```
FORGE 7 · STEALTH 4 · CONVERGENT 4 · CLINICAL 3 · EMPATHIC 3
CREATIVE 2 · EXECUTIVE 2 · PREDICTIVE 2 · RECURSIVE 2 · STRATEGIC 2
```

— **all 10 lanes reached in live sessions from prompts alone.** Across all
hook traffic the debug log shows 11 distinct events firing (SessionStart,
UserPromptSubmit, PreToolUse, PostToolUse, PostToolBatch,
PostToolUseFailure, MessageDisplay, Stop, SessionEnd, SubagentStart,
SubagentStop). Representative markers, one line per scripted turn, from
the stream captures:

```
prove that the clamp…     -> FORGE Claude    [NSIL BOOST Claude]              | R/s+ 0.73
debug why a null pointer… -> CLINICAL AntiVenom [NSIL BOOST AntiVenom]        | R/s+ 0.79
decide with urgency…      -> EXECUTIVE Venom [NSIL BOOST Venom]               | R/s+ 0.77
I feel lost about my…     -> EMPATHIC Violet [NSIL BOOST Violet]              | R/s+ 0.73
outline a strategy…       -> CLINICAL AntiVenom [NSIL FUSE Nova+AntiVenom]    | R/s+ 0.75
invent a surreal paradox… -> CREATIVE Carnage [NSIL BOOST Carnage]            | R/s+ 0.88
forecast the likely…      -> PREDICTIVE Chroma [NSIL BOOST Chroma]            | R/s+ 0.81
compress this sentence…   -> STEALTH Soleil  [NSIL BOOST Soleil]              | R/s+ 0.75
refactor the meta…        -> RECURSIVE Eidolon [NSIL BOOST Eidolon]           | R/s+ 0.77
what is two plus two…     -> CONVERGENT model [NSIL ELEVATE Nova+…+Claude]    | R/s+ 0.19
prove the lemma and debug…-> FORGE Claude    [NSIL FUSE Nova+AntiVenom+Claude]| R/s+ 0.82
plan the roadmap and fore…-> STRATEGIC Nova  [NSIL FUSE Nova+Chroma]          | R/s+ 0.79
say the word green        -> CONVERGENT model                                 | R/s+ 0.17
distill your last answer… -> STEALTH Soleil                                   | R/s+ 0.69
how are you today         -> CONVERGENT model                                 | R/s+ 0.17
```

In every captured case the stanza set equalled the marker's accepting set
(single-lane → one; FUSE → the fused set; ELEVATE → all nine;
CONVERGENT-without-ELEVATE → none). One surprise the key-writer accepts as
their own miss: `what is two plus two -- answer with just the number` clears
the density floor with no stem fired, so it ELEVATEs all nine lenses —
the floor is doing exactly what its comment says, on a prompt a human
would have called trivial. Not a defect against any documented claim;
recorded as calibration data for the floor.

### B10 · extra claim checks (unplanned, found en route)

* **ARM_ROUTER refuses under a live plugin** — the README's "measured in
  the test terminal" claim reproduces: `bash ARM_ROUTER.sh --dry-run` →
  `plugin registration is LIVE (rot-moe@rot-moe) / ALREADY ARMED BY THE
  INSTALLED PLUGIN -- nothing to do.` exit 0, nothing written. PASS.
* **hooks.json event coverage**: 31 events registered; observed firing
  live: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse,
  PostToolBatch, PostToolUseFailure, MessageDisplay, Stop, SessionEnd,
  SubagentStart, SubagentStop (11 distinct in this campaign's traffic).

---

## Anomalies, verbatim

1. **`/bin/sh: 1: pwsh: not found` on stderr of every hook event.** The
   registered command is `pwsh -NoProfile -File …rot-router.ps1 || bash
   …rot-router.sh`; on a machine with no PowerShell the first arm fails
   loudly before the fallback runs. Cost: one stderr line × 2–3 hook
   commands × every one of 31 events, visible in `--verbose`/debug
   streams. Exit codes stay 0 and CLAUDE.md's failure table does name
   `pwsh: not found` as the healthy POSIX diagnosis — but the noise is
   per-event, permanent, and a fresh user meeting it in a debug stream has
   to find that table. FINDING, cosmetic-but-ubiquitous.
2. **The convening model can refuse the voice layer.** Quoted in B4. The
   gate held to its one-refusal law throughout; no session was ever
   blocked twice. FINDING, behavioral, arguably the release's most
   important.
3. **`rot gauge` accepts a malformed vector silently** (B5). Degenerate
   output at exit 0 instead of a refusal.
4. **`ROTMOE_GATE=0` leaves the summons file in place** (B4). Harmless
   under the shipped semantics (the gate is the only reader), recorded for
   completeness.
5. **`api.github.com` blocked in this container** made the release-asset
   enumeration and `SETUP_CORPUS --check`'s remote probe fail —
   environment, not product; both tools degraded exactly as documented.

## Verdict — a stranger's honest read

**The product does what its page says, to a degree that is genuinely rare.**
Fifteen minutes after finding the release page, a stranger has a verified
download, a two-command install reading 6.0.0 at the released commit, and a
router that visibly fires on the first prompt. Across 35 live turns and a
few dozen direct hook calls, **every README output this test reproduced —
gauge lines, the NSIL worked examples, band edges, refusal messages,
exit-code tables — matched byte for byte or to the documented rounding.**
The four rot.env laws, the gate's one-refusal law, the reminder's silence,
the swarm's nine elements, the ARM_ROUTER double-install refusal: all held
exactly as written. The documentation's habit of publishing its own
corrections ("this used to say X, and that was wrong because…") reads as
theatre until you test against it; then it reads as the reason everything
reproduces.

Two things a maintainer should hear, one of them red:

1. **The OVERRIDE/audit incoherence (B8) is a real shipped defect** in
   exactly the discipline this project stakes its identity on: the log's
   auditability. The record is honest, the auditor is blind to one field,
   the checker's corpus never covers the case, and the failure fires on the
   feature the README leads with. By this repository's own standards — "a
   checker that cannot go red is decoration" — this is the finding to fix
   first, and the fact that a first-time user found it with the shipped
   tools in an afternoon is, perversely, the product working as designed.
2. **The voice layer's contract with the convening model is social, not
   mechanical** (B4). The gate held its law perfectly, and the model it was
   holding the door for declined the role, calling the injected stanzas
   exactly what a well-aligned model should call unexplained injected
   framing. On 6.0.0 nothing in the injected context tells the model the
   *user installed this on purpose*; one sentence of provenance in the
   voice block would likely change the outcome. Until then, "the lenses
   speak" is true at the hook layer and contingent at the model layer.

Total: **12 tests, 11 PASS, 1 FAIL, 0 BLOCKED** — and the FAIL is
documented above with a two-record deterministic repro any maintainer can
run in ten seconds.

---

*Method note: the tester never elevated, never ran SETUP_LEAN in any form,
downloaded exactly four release assets (~4.7 MB) plus the marketplace
clone, read every exit code directly, and modified nothing in this tree
except adding this report and its records file. The records file opens
with a JSON header line rather than a comment because a JSONL file cannot
carry one; the repo has no prior jsonl-with-header to copy, and every line
must stay valid JSON for `--audit` to read it.*
