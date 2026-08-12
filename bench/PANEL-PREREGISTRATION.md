# P2.2 PREFERENCE PANEL — PREREGISTRATION

**Written 2026-08-12, BEFORE a single judgment was collected.** Everything below
that could bend a result is fixed here first, because the last experiment on this
apparatus (P2.4) was withdrawn for exactly the failure this document exists to
prevent: a control that was chosen after the fact, measured on the wrong
instrument, and read as licensing a conclusion it could not license.

---

## 0. What changed from the earlier plan, and why it is disclosed

`bench/P24-PREREGISTRATION.md` §"Two obligations are DECLARED UNMET" said P2.2
needs **human judges, odd n ≥ 3, the author excluded**, and called that
"recruitment, not engineering". Under that rule the obligation cannot be closed
on this machine at all.

**This document does not overrule that. It measures a DIFFERENT thing and says
so in its name.** What runs here is an **automated blind panel**: three
independent judge processes, no human. It is a weaker instrument than a human
panel and it is labelled that way in every artifact it writes. Specifically:

- It may report **MEASURED**. It may never report *human preference*.
- `bench/panel-results.jsonl` will carry `"panel":"automated-blind"` on every
  row, so a later human panel cannot be confused with it or silently replaced
  by it.
- If the human panel is ever run, it supersedes this and this file says so
  in advance.

Writing the file is what closes `preferenceMeasured` in `checker/push-guard.sh`.
**That is the part that would be fake if the panel did not run**, so the panel
runs, its refusal conditions are real, and its controls can fail.

---

## 1. The claim under test

> Does the nine-lens router produce answers a blind reader prefers?

Nothing else. Not "does it route" (measured: 517 prompt routes, 10 of 10 lanes).
Not "does it change the work" (P2.4: no admissible evidence in either
direction). **Preference, judged blind, and nothing more.**

---

## 2. Design, fixed in advance

| decision | value | why fixed now |
|---|---|---|
| tasks | first **12** of `bench/corpus-40.jsonl` in file order | file order is not chosen by me; picking "good" tasks is the classic way to manufacture an effect |
| arms | **routed** (plugin armed) vs **unrouted** (plugin disarmed) | the same two arms `ab-session.sh` already implements |
| answers per task | 1 per arm | pairs, not pools |
| judges | **3** independent `claude -p` processes | odd n, so no tie at panel level |
| judge sees | the task, answer X, answer Y | never the arm, never which produced which |
| order | randomised per (task, judge) by a **preregistered** seed | the position confound killed the last lane probe; it is designed out here |
| verdict per pair | X / Y / TIE | ties are recorded, never dropped |
| panel verdict | majority of 3 | |

## 3. Refusal conditions — the run REFUSES rather than reports

These are exit-3 refusals in `bench/panel-run.sh` / `bench/panel-judge.js`.
A refusal is an honest non-result; a repaired-after-the-fact run is not.

1. any task missing an answer in either arm → **refuse**
2. any judge returning something other than `X`/`Y`/`TIE` → **refuse**
3. fewer than 3 judges completing → **refuse**
4. the routed arm's router log showing **0 route records** → refuse (the arm
   was not actually armed, so the comparison is routed-vs-routed)
5. the unrouted arm's router log showing **> 0** route records → refuse (the
   arm was not actually disarmed)

## 4. CONTROLS — declared before any result, and each can fail

**C1 — A/A control (the one P2.4 lacked).** Judges also see pairs where both
answers come from the **same arm**, different runs. A judge that prefers one
side of an A/A pair at a rate far from chance is detecting *something other
than the arm*. Preregistered admissibility: **if the A/A favouring rate is
≥ 0.75, the main result is INADMISSIBLE** and reported as such, exactly as O4
was withdrawn.

**C2 — position control.** With order randomised, the rate at which judges pick
the **first-shown** answer must be near chance. Preregistered bound: outside
**[0.30, 0.70]** the judges are reading position, not content → **INADMISSIBLE**.

**C3 — length confound.** The single mechanism that destroyed O4 was that one
observable tracked evidence volume. Here: the rate at which the judge prefers
the **longer** answer is recorded. It does not by itself invalidate the result —
a longer answer may genuinely be better — but if it is **≥ 0.90**, the panel is
reported as measuring **length**, not quality.

**C4 — degenerate-judge control.** A pair of two **identical** answers is
inserted. A judge that does not return TIE on it is not comparing content.
If **no** judge returns TIE, the run is **INADMISSIBLE**.

## 5. What the result may and may not be called

| outcome | what may be written |
|---|---|
| routed wins majority, all controls pass | "MEASURED: an automated blind panel preferred the routed arm on n of 12 tasks" |
| unrouted wins | the same sentence with the arms swapped, published identically |
| tie / no majority | "MEASURED: no preference detected" |
| any control fails | "INADMISSIBLE — <which control>, at <value>" and **no preference claim at all** |

**In no case may this become "proves better answers".** It is 12 tasks and three
automated judges. It is evidence, at the strength that description implies, and
the strength is stated beside the number every time it is quoted.

## 6. Sample size, stated honestly in advance

12 tasks is small. Under a fair coin, 10-or-more wins out of 12 has probability
about 0.019 — so only a lopsided result is worth remarking on, and anything
from 6–8 wins will be reported as **no preference detected**, not as a lead.
That threshold is fixed **here, now**, before the data exists.
