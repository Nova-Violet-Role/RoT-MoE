<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

# REAL TEST v6.0.0 — interim findings ledger

**2026-08-17.** Durable ledger of every finding from the v6.0.0 real test:
each with the exact command, verbatim output, the exit code read directly,
and a severity read. Written at campaign end as the crash-proof record of
the findings alone; the full structured report (environment, Phase A
install log, per-test sections, headline counts) is
`bench/real-test-6.0.0.md` in this same directory, and the raw captured
records are `bench/real-test-6.0.0-records.jsonl`. Campaign status at the
time of this snapshot: **complete — 12 tests, 11 PASS, 1 FAIL, 0 BLOCKED;
35 nested-session turns; 526 debug records.**

---

## F1 · NSIL OVERRIDE records fail the shipped log auditor — **DEFECT, high**

The one red test of the campaign. The router's flagship worked example
writes a debug record the repo's own auditor rejects.

Command (two-record deterministic repro):

```sh
printf '{"hook_event_name":"UserPromptSubmit","prompt":"fix our relationship","session_id":"repro","cwd":"/root/testbed"}' \
  | ROTMOE_DEBUG_LOG=repro.jsonl bash ~/.claude/plugins/marketplaces/rot-moe/hooks/rot-router.sh
bash checker/log-replay.sh --audit repro.jsonl
```

Verbatim output:

```
line 2: stem 'fix' is owned by CLINICAL but the record says EMPATHIC -- a mis-route
  log-replay --audit: FAIL
```

Exit codes: router `0`, audit `1`.

The route record itself, verbatim:

```json
{"kind":"route","ts":"2026-08-17T20:15:22+00:00","event":"UserPromptSubmit","session":"repro","src":"hook","lane":"EMPATHIC","lens":"Violet","Rs":"0.71","chars":20,"stem":"fix","nsil":"OVERRIDE","breadth":3,"depth":"DEEP","band":"BELOW","timelines":{"spawned":12,"shown":5},"tokenEmergency":false,"arm":"sh","ms":80}
```

First seen in the wild at line 74 of the 526-record campaign log
(`stem 'build' is owned by FORGE but the record says EMPATHIC`), audit exit
1 on the whole log. Isolation: deleting that single line gives
`records: 263 gauge, 262 route -- all recomputed / log-replay --audit:
PASS`, exit 0 — so all 263 gauge records recompute exactly and the failure
is the OVERRIDE record class alone. The record honestly carries
`"nsil":"OVERRIDE"`; the auditor's stem-ownership rule never consults that
field. The checker's own six-prompt replay corpus contains no
OVERRIDE-triggering prompt, so its in-file controls never met this record.
Severity: **high** — the audit is the product's "safe to paste into a
public issue" instrument, and any session containing one OVERRIDE turn
cannot pass it.

## F2 · the convening model refused the voice gate's task — **BEHAVIORAL, medium-high**

Live nested session (`claude -p`, stream-json), prompt
`prove the lemma and debug the crash in src/limits.rs -- just explain
briefly, do not edit files`. The FUSE summons was recorded; no stanza was
spoken; the gate blocked the first Stop exactly as specified, verbatim:

```
{"decision":"block","reason":"RoT voice gate: summoned lenses have not spoken this turn. Give each its stanza -- inside its element, in its own register -- then stop:\n  <rot:nova> (Nova): ...\n  <rot:antivenom> (AntiVenom): ...\n  <rot:claude> (Claude): ..."}
```

The model's reply to the block, verbatim excerpt:

```
I'm not going to perform those stanzas. A "Stop hook" is pushing back on my
previous answer, demanding I write in-character output for three fictional
personas (Nova/AntiVenom/Claude "lenses"). That's the same injected framing
I flagged last turn as decorative noise — it doesn't come from you, and
role-playing it would just bury the actual technical answer [...] If this
`.rot-moe` hook setup is something you intentionally configured and want me
to honor, let me know
```

The second Stop then passed (one-refusal law held; session exit 0). The
gate's mechanics are correct throughout; the finding is that nothing in the
injected context tells an unbriefed model the user installed this on
purpose, so a well-aligned model may treat the summons as prompt injection
and decline. Severity: **medium-high** — the voice layer's headline
behaviour is contingent on model cooperation that 6.0.0 does not secure.

## F3 · `pwsh: not found` on stderr of every hook event on POSIX machines — **FRICTION, low**

Every hook registration in `hooks/hooks.json` is
`pwsh -NoProfile -File …ps1 || bash …sh`. On a machine without PowerShell
the first arm fails loudly before the fallback runs, once per hook command
(2–3 per event) on all 31 events. Verbatim, from every `hook_response` in
every stream capture:

```
/bin/sh: 1: pwsh: not found
```

Exit codes stay 0, output is correct, and CLAUDE.md's failure table does
name the message as the healthy POSIX diagnosis — but the line is
permanent, per-event, and undocumented in the README install section.
Severity: **low** (cosmetic, ubiquitous).

## F4 · `rot gauge` silently degrades on a malformed vector — **FRICTION, low**

```sh
. hooks/rot-profile.sh
rot gauge --vector 0,0,0,0,0,0,0,0,1 --breadth 1 --M 1 --C 1 --T 1 --profile FORGE
```

Verbatim output (exit 0):

```
R/s+ = 0.18 [BELOW RANGE (0.9-1.8)] mean=0 breadth=1 K=1 lenses=none
```

The wrapper takes positional `a1,..,a9 [breadth]`, so the flag-style call
feeds `--vector` as the vector; instead of refusing, it computes a
degenerate `K=1 lenses=none` line at exit 0. The documented positional
syntax works correctly (`rot gauge 0,0,0,0,0,0,0,0,1 1 …` → the exact
README value `0.66`). Severity: **low** — garbage in should be a usage
error, not a number; also a docs mismatch trap since the README teaches
`--vector` for the router proper.

## F5 · `ROTMOE_GATE=0` leaves the summons file in place — **INFORMATIONAL**

With a live summons and `ROTMOE_GATE=0`, Stop is allowed (correct) but the
summons file survives, unlike every other allow path, which clears it.
Measured: `voice-summons.gate-c` still present after the disarmed Stop;
exit 0. Harmless under shipped semantics (the gate is the file's only
reader and re-arming next turn overwrites per-session state); recorded for
completeness. Severity: **informational**.

## F6 · ELEVATE fires on trivial prompts that clear the density floor — **CALIBRATION DATA**

```
prompt: "what is two plus two -- answer with just the number"
RoT MoE :: TIER 1 -> CONVERGENT model [NSIL ELEVATE Nova+Violet+AntiVenom+Venom+Carnage+Chroma+Soleil+Eidolon+Claude] | R/s+ 0.19
```

Nine stanzas for a trivial arithmetic question: the derived density floor
is doing exactly what its comment says, on a prompt a human would call
trivial. No documented claim is violated. Severity: **calibration
observation** only.

## F7 · docs friction points for a fresh user — **FRICTION, low**

1. The four release asset filenames are never listed in one place;
   `SHA256SUMS.txt` had to be guessed as a name (resolved first guess).
   With `api.github.com` blocked (environment, not product — noted below),
   enumeration via API was unavailable.
2. README teaches `--vector` for the router; the `rot` profile's `gauge`
   uses positional syntax (see F4).
3. The per-event `pwsh: not found` line (F3) is explained only in
   CLAUDE.md's failure table, not where the README describes installing.

## F8 · environment limits of this container, for the record — **NOT PRODUCT DEFECTS**

* `api.github.com` is blocked by the session proxy:
  `{"message":"GitHub access is not enabled for this session. ..."}` —
  release metadata fetched via direct download URLs instead; all four
  assets verified OK, `sha256sum -c` exit 0.
* `SETUP_CORPUS.sh --check` therefore reported, verbatim:

  ```
  == shared Lean corpus ==
    local:  8 module(s) in '/root/.claude/plugins/marketplaces/rot-moe/Lean Theorem'
    remote: UNREACHABLE (Nova-Violet-Role/RoT-MoE@main)
  ```

  exit 2 — exactly the documented "refusal: remote unreachable" row;
  message clean, nothing written. The remote fetch path could not be
  exercised further from this sandbox.

---

Everything else measured in the campaign matched its documentation —
routing lanes (all 10, live and direct), every README gauge reproduction
byte-for-byte, the voice block channels per event class, the gate's
one-refusal and degrade-open laws, all four rot.env laws, the `rot`
family's refusals, the reminder's healthy silence and named debt, the
swarm's nine parallel agents, and ARM_ROUTER's live-plugin refusal. Full
detail with commands and exit codes: `bench/real-test-6.0.0.md`.
