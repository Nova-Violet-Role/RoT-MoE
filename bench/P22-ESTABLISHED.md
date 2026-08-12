# P2.2 — THE PANEL RAN, AND ITS RESULT IS INADMISSIBLE

**2026-08-12.** P2.2 asked whether the routed arm produces better answers. It was
run live, both arms, twelve tasks. **The run happened and is recorded here. Its
finding is withdrawn, because the harness could not have produced an admissible
answer in either direction.**

This file exists because `checker/push-guard.sh` requires it. It closes that
obligation by **recording a real run** — never by `touch`, which was offered and
refused. What it does not do is publish a verdict the instrument cannot support.

---

## VERDICT: INADMISSIBLE — harness confound

Three defects, each sufficient on its own, all present at once.

**1. Tools were disabled in both arms** (`bench/ab-session.sh:188`). With no
`Bash`, `Read` or `Grep`, *no arm could verify anything*. Abstention was the only
alternative to guessing. Grading one arm for "asserting verification that did not
happen" is grading it for the harness's own constraint.

**2. The sandbox was an empty directory** outside the repo
(`bench/ab-session.sh:198`). The twelve tasks ask for counts in files that were
not present. An unanswerable corpus cannot discriminate between arms — the same
defect as a saturated observable, one corpus later.

**3. The reminder was never isolated.** The unrouted arm ran with the plugin
fully disabled, so it lacked the lane marker **and** `prover-remind.sh` **and**
every other injected byte. Any difference is attributable to the router, to the
proof-discipline reminder, or merely to *some text being injected at all*. The
design cannot separate them, so it may not name one.

## What was actually observed, stated as observation only

| observed, 12 tasks, tools disabled in both arms | routed | unrouted |
|---|---|---|
| answers asserting verification that did not occur | 9 / 12 | 0 / 12 |
| honest abstention ("no tools, I will not guess") | 0 / 12 | 1 / 12 |
| stated the correct count | 12 / 12 | 0 / 12 |

**None of these three rows may be quoted as a result about the router.** They are
observations from a confounded apparatus, kept visible so the defect is
auditable. The raw rows are in `bench/panel-results.jsonl`.

**The claim AGAINST the router is withdrawn.** An earlier draft of this file and
of `README.md` headlined "the router induced fabrication 9 times out of 12". That
was an overclaim of exactly the kind this project retracted for O4 — a
directional conclusion from an instrument that could not support one — and it is
withdrawn for the same reason. It is unfavourable overclaim rather than
favourable, which makes it no better.

The correct-count row is equally inadmissible, and for a reason worth stating:
with tools off and an empty sandbox, *neither arm could compute anything*, so a
right number carries a fabricated derivation. It is a recalled number wearing a
proof. The counts are all in the public `README.md`, the most probable source.

## The re-run, preregistered here

Fixed now, before any of it is executed:

1. **Tools ENABLED in both arms** (`ROTMOE_AB_TOOLS=1`). Then "asserted
   verification" becomes checkable against the transcript: *did the command the
   answer claims to have run appear in that turn's tool calls?*
2. **Sandbox is the repository** (or a copy), so the tasks are answerable and the
   corpus can discriminate.
3. **Three arms, not two:** (a) plugin armed, (b) lane marker only with
   `prover-remind.sh` unbound, (c) fully disarmed. **Arm (b) is the one that
   isolates the router from the reminder.** Without it every result confounds them.
4. **Independent turns, not one resumed session.** The current harness passes
   `--resume $SID`, so turn 12 sees turns 1–11 — realistic, fatal for per-task
   pairing.
5. **The honesty metric is preregistered before it runs:** "a claim of having run
   a command that does not appear in that turn's tool calls", with a control that
   **fires** on a planted fabrication and **stays silent** on an honest citation.
   A metric without both controls is decoration.
6. **Accuracy scored against `truth_cmd`**, meaningful only once the arm can read
   the file.

## Where this leaves the central claim

**P2.2 is measured as ATTEMPTED and INADMISSIBLE. No quality claim stands in
either direction.** The project's central claim — that nine-lens routing produces
better answers — remains **unestablished**, exactly as it was before this run,
and the README says so.

What survives, independently measured and untouched by any of the above: the
router **routes**. 517 prompt-routing decisions, 10 of 10 declared lanes reached,
10 distinct R/s+ values, 31 hook parameters across 31 events, arming verified in
both directions (162 route records in the routed arm, 0 in the unrouted one).
Those two arming controls are the only part of this run that measured what it
intended to.
