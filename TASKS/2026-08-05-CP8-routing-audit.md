# CP8 — the log recorded WHICH lane fired and never WHY

Commit `13300fe`, pushed to `main`. Previous checkpoint: CP7 (`e4f825a`).

The standing goal names one gap explicitly — *"it doesn't as of now check
`*(*.log)` Debug of RoT MoE"*. This checkpoint closes the half of it that was
still open, and the half that was open was not the half it looked like.

---

## 1. What was already covered, measured before writing anything

`checker/log-replay.sh` already recomputed **the gauge**: every factor of the
sum re-derived from the record's own fields, pairing enforced, rounding checked,
both arms compared byte for byte, five negative controls. That is real and it
stays.

What it could not see: **the routing decision.** The `route` record carried

```json
{"kind":"route","lane":"FORGE","lens":"Claude","Rs":"0.66","chars":31,"arm":"sh"}
```

Every field checkable. **None of them an explanation.** A user reporting "my
proof prompt routed CONVERGENT" could hand over a complete, valid, fully
replayable log in which the one disputed fact was simply not present.

`chars` rather than the prompt is the *right* call — a debug log has to be safe
to paste into an issue — and it is precisely what left routing unfalsifiable.

## 2. The datum that closes it without reopening privacy

The **matched stem**. Stems come from a closed table written in the router
itself (85 words, 9 lanes), so recording one leaks nothing about the user's text
beyond which fixed vocabulary word occurred — which *is* the routing decision.

| | before | after |
|---|---|---|
| `route()` returns | `echo "FORGE Claude"` per branch | `"<LANE LENS>\|<stem>"`, printed once |
| `--route` output | `FORGE Claude` | `FORGE Claude` — **unchanged**, verified both arms |
| route record | no reason field | `"stem":"prove"` |
| CONVERGENT | — | `"stem":""`, and that is enforced |

Both arms changed identically; `cross-diff` exit 0.

## 3. The theorem that makes it more than a new field

`lean/Proofs/RotLog.lean` §4, 6 theorems, 12 kernel-checked `example`s.

```
auditable_imp_vocabSafe : Auditable t r → VocabSafe t r
```

**Passing the audit entails the stem came from the router's table.** So "this
log is safe to paste in public" is not a second promise beside the correctness
one, liable to be dropped — it is a *consequence* of the check that certifies
the routing. `vocabSafe_not_imp_auditable` proves the converse false, which is
what makes the audit the stronger of the two.

`first_owner_wins` / `second_owner_reachable` pin the priority order; the second
exists so the first is not just "the head of a list wins".

**The shipped stem table appears only as `example`s, deliberately.** The word
lists are a routing choice the project changes on purpose (`prove proof lemma
lean qed` joined FORGE in 0.7.0). A theorem asserting today's words would go red
on a correct future edit and the obvious repair would be to delete it. The
theorems quantify over an arbitrary table; the executable rows pin the present.

| instrument | result |
|---|---|
| `lake build Proofs.RotLog` | **exit 0**, 0 errors, **0 warnings** |
| `#print axioms` | `propext`, `Quot.sound` — no `sorryAx`; `empty_stem_iff_convergent` none |
| `lake env leanchecker` | **exit 0, 0 bytes**; control on a missing module exit 1 |
| delivery to `D:/Lean/proofs` | build 0, leanchecker 0 |

`second_owner_reachable` shipped with a hypothesis it did not need — the
`[]`-contains-nothing premise is provable. **Dropped rather than silenced**; the
theorem is now strictly stronger.

## 4. The checker, and the tool that was missing

* the lane→stem map is **read out of `hooks/rot-router.sh` at run time**, never
  copied — a second list here would drift silently, which is the defect
  workflow-lint rule 6 already forbids elsewhere;
* if that parse returns other than **9 lanes** the gate **refuses** rather than
  certify records against an empty table (which would pass everything);
* four new controls, each a real corruption of a real log: **wrong lane ·
  leaked text · empty stem on a fired lane · missing field**. All four REJECTED,
  0 discarded.

**`bash checker/log-replay.sh --audit <file>`** — the instrument existed and was
unreachable. It only ever read logs it generated itself; a user holding a log
had no way to ask whether it was self-consistent. Controls: mis-routed log → 1
with `stem 'token' is owned by STEALTH but the record says FORGE`; junk → 1;
missing file → 2.

`lean/mutate/mutate_rotlog.sh` is **new** — RotLog had theorems since the first
Lean release and never a suite. **10 applied, 10 killed, 0 survived, 0
discarded.**

## 5. Three things this turned up on the way

| # | what | why it matters |
|---|---|---|
| 1 | STATUS.md was about to publish **`files containing sorry \| 1`** for a tree with none | the counter matched the WORD `"sorry"` in the router's stem table, where it is **data**. String literals now excluded, **both directions controlled**, and the script REFUSES to write rather than publish from a broken instrument. Mutating `instr = 0` → `instr = 1` fires the control, measured. |
| 2 | `bench-router` parsed `echo "FORGE Claude"` out of the router | when `route` stopped using that form it went RED with *"the probe broke, not the README"*. The row-count guard is why this was a loud failure and not nine lanes agreeing against an **empty list**. |
| 3 | `mutate_rotlog.sh`'s header was inherited from `mutate_rotmutant.sh` | it described **RotStem's** matcher mutants, which appear nowhere in it. A file that says in its own voice that it tests something it does not test is not a cosmetic defect. Rewritten, and the inheritance recorded. |

Also: `mutate-checker.sh` H07's needle moved with `route()`. Left unedited it
would have been **DISCARDED** — the harness would have said so. 16 killed, 0
survived, 0 discarded after the repair.

**L09 SURVIVED on the first honest run.** The mutant widened the pair tolerance
to `1/2`; the gap it must reject is `1`. The mutation was too small to reach the
claim, not a weakening of it. **The mutant was corrected upward rather than the
theorem downward** — a survivor is never a licence to soften what it failed to
kill.

**No version was invented.** Five comments referred to "0.7.3"; the patch digit
is the *variant selector* (`core:0.7.0 lean:0.7.1 unsealed:0.7.2`), so 0.7.3
cannot exist. All five reworded descriptively.

## 6. Measurements

| what | value | instrument |
|---|---|---|
| theorems | 281 → **287** | `checker/repo-complete.sh` |
| mutants | 116 → **126**, all killed | 15 suites |
| suites | 14 → **15** | `ls lean/mutate/mutate_*.sh` |
| fast gates | **ALL 22 GREEN** | `gate-all.sh --fast` exit 0 |
| deep gates run individually | 11, all exit 0 | incl. `mutate-checker` 16 killed |
| CTT changed files | **14/14 byte-identical** | `cmp` per file |
| CTT lanes driven live | FORGE 0.66 · CLINICAL 0.57 · CREATIVE 0.32 · PREDICTIVE 0.41 · CONVERGENT 0.16 | installed plugin, hook mode |
| CTT log audited | **PASS**, by the *installed* checker | `--audit` |

The five distinct readings are the point: the gauge is **dynamic**, driven by
which lens fired, not a constant printed beside a lane name.

---

## NEXT

1. **Read CI for `13300fe`** — four jobs. The stem change touches both arms, so
   `cross-diff` on macOS/ubuntu is the row to watch; `log-replay` now parses the
   router with `sed`, and BSD vs GNU `sed` has already cost this repo one red.
2. **`ci-dryrun --from 28 --to 54` failed once, passed three times** — still
   unattributed, still not called fixed. Carried from CP7.
3. **The tenth signal bit for Claude's own lens.** `own_signal_restores_
   independence` is proved; wiring it is a change to the injector and needs a
   decision, not a proof. Carried from CP7.
4. **`--audit` is not yet reachable from the plugin surface** — a user has the
   tool only if they cloned the repo. A slash command or a documented one-liner
   against the installed cache path would close that.
5. **The ps1 arm's `stem` is untested by the ps1 route CLI** — `Split-Routed`
   has no direct unit control; it is covered only through the log. A row in
   `cross-diff` comparing the two arms' *stems* over the corpus would bind it.
