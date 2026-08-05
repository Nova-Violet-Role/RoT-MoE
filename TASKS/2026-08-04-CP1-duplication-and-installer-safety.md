<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# CP1 — the duplication, the installer safety net, and the measurement half

Date: 2026-08-04 · branch `main` · baseline commit `be55414`

Every line below names the instrument that produced it. Anything not measured is
marked so.

---

## 0. The headline: the router really was firing TWICE, and the docs caused it

**Instrument:** `node` over the live `~/.claude/settings.json` + the plugin's own
`hooks/hooks.json` + this session's own transcript.

```
plugins/cache/rot-moe/rot-moe/0.6.1/hooks/hooks.json  ->  rot-router on UserPromptSubmit, PreToolUse
settings.json                                          ->  rot-router on UserPromptSubmit  (1)
settings.json                                          ->  rot-router on PreToolUse        (1)
enabledPlugins["rot-moe@rot-moe"] = true
```

The two install paths are **additive, not alternatives**, and `CLAUDE.md` told the
installing agent to take both: install the plugin (step 1 of the plugin flow),
then run `ARM_ROUTER`. Result on every machine that followed the documented
procedure: two marker lines, two gauge computations, twice the tokens, every
prompt, forever. Visible in this very session — the `RoT MoE :: TIER 1 -> FORGE
Claude | R/s+ 0.66` line appears twice per turn.

This answers the Socio's question directly: **0.6.0/0.6.1/0.6.2 are not
necessarily broken as routers.** What was broken is the *installation contract*.
The router itself routed correctly — it routed correctly twice.

**Fixed, both arms, measured in both directions:**

| arm | plugin present | plugin absent |
|---|---|---|
| `ARM_ROUTER.sh` | refuses, exit 0, writes nothing | arms normally (2 entries) |
| `ARM_ROUTER.ps1` | refuses, exit 0, writes nothing | arms normally (2 entries) |

New shared detector `hooks/plugin-detect.js` (exit 0 = live plugin registration,
10 = none). It keys on the FACT (a `hooks.json` that binds `rot-router.*` in an
ENABLED plugin), never on the directory being called `rot-moe` — a marketplace
can rename it and the duplicate would come straight back.

`--force` / `-Force` keeps the door open for someone who genuinely wants a second
registration and now knows that is what it is.

---

## 1. `DISARM_ROUTER --dry-run` deleted a live configuration

**Instrument:** `grep -cE '\-\-dry-run|DRY'` — 15 hits in `ARM_ROUTER.sh`, **0** in
`DISARM_ROUTER.sh`. The destructive half of the pair was the half missing the
safety flag, and an unknown argument was silently ignored, so `--dry-run` read as
"proceed".

**Fixed:** both arms parse it; the dry run performs the REAL removal against a
copy and discards it (one code path, so preview and act cannot disagree); an
unknown flag is now `exit 2`, refusing.

Measured on a scratch config: file byte-identical (md5) after `--dry-run` and
after `--all --dry-run`; `--bogus` exits 2 and writes nothing.

## 2. `DISARM` could not remove what the documented install produces

Removal matched the exact command string rebuilt from the directory DISARM was
run from. An entry pointing at the plugin cache survived a full DISARM run from a
source checkout, reporting `nothing to remove`, exit 0.

**Fixed:** `disarm-any` mode in the shared merge engine (`--all` / `-All`), and
the default mode now says so out loud when it finds router entries it could not
match. Exact match stays the default — it is the mode with the Lean proof and the
one that can only touch a string it wrote itself.

Measured: exact run leaves the plugin-path entry (and warns); `--all` removes it,
leaves the user's own unrelated hook intact, file still parses as JSON.

## 3. The proof scan was one level deep — in BOTH arms

`"$PROOFS_DIR"/*.lean` and `Get-ChildItem -Filter '*.lean'` with no `-Recurse`.
The moment proofs are filed by subject the newest file either arm can see is
whatever last landed in the root. Measured on a real tree: 2947 min vs 54 min, a
55x error, while eighteen modules were being written into a subfolder.

**Fixed** in both arms (`find -type f`, `-Recurse`).

## 4. The workspace chain had a step nothing wrote

`env -> RECORDED -> bundled corpus` looked like three answers; only
`SETUP_LEAN.sh` ever writes RECORDED, so for a marketplace install it is
permanently empty and the chain silently degrades to two.

**Fixed:** a fourth step, `discovered`, in **both** arms — the first attempt at
this fix (in the Desktop work-order copy) added it to the POSIX arm only, which
would have given Windows and Linux users different answers with no gate able to
see it. Both layouts are accepted: `<ws>/Proofs` and `<repo>/lean/Proofs`.

## 5. AMPLIFICATION — the measurement half now has an instrument

`--decide` made the DECISION cross-armable; `checker/cross-diff-remind.sh` states
in its own header that what it does not cover is "that both arms measure the same
things off disk". **That uncovered half is exactly where defects 3 and 4 lived**,
in both arms at once, invisible to a green cross-diff for weeks.

New in both arms:

```
prover-remind.sh --measure     ->  "<count> <mins> <name>"
prover-remind.sh --workspace   ->  "<env|recorded|discovered|bundled> <path>"
```

Measured on one fixture tree with a nested proof, both arms: `2 1 Nested`. The
count is what makes the one-level defect *visible to a checker* rather than only
to a live session.

## 6. The repo's OWN pre-commit gate had been disarmed

**Instrument:** `checker/workflow-lint.sh` — `FAIL pre-commit exists but never
calls gate-all -- it guards nothing`.

The CodeMap plugin had overwritten `.githooks/pre-commit` with its own indexing
hook (215 lines ending in `exit 0`, comment: "Never blocks a commit"). The
delegate slot `.githooks/pre-commit.d/10-codemap` exists precisely so this does
not have to happen. Restored from HEAD; `workflow-lint` back to **116 passed, 0
failed**. This is the repo's own negative control firing on a real regression.

---

## Baseline

`bash checker/gate-all.sh` before any edit: **1 of 29 gates RED** — and the red
one was §6 above, not the work. After the restore, that gate is green. Recorded
here so nothing later gets credited or blamed for it.

---

## NEXT

1. **Lean 4 first, then the checkers.** New invariants get theorems before they
   get gates: (a) arming when a plugin registration is live cannot increase the
   firing count — the double-fire is a statement about a multiset of hook
   commands; (b) `disarm-any` removes every router entry and nothing else
   (`disarm_any_removes_all`, `disarm_any_preserves_foreign`); (c) a recursive
   scan dominates a one-level scan (`scan_recursive_ge_flat`, with the strict
   witness that makes it non-vacuous); (d) the workspace chain returns the first
   step that answers.
2. `checker/disarm-safety.sh` — dry run leaves bytes identical, unknown flag
   exits 2, `--all` removes a plugin-path entry, exact mode does not, control
   proving real removal still works.
3. `checker/remind-measure.sh` — both arms over a fixture with a NESTED proof;
   compares count and name exactly, allows 1 minute of drift on mins.
4. `checker/router-duplication.sh` — ARM refuses under a live plugin, arms
   without one, `--force` overrides; both arms.
5. The `*.log` gap the Socio named: `ROTMOE_DEBUG_LOG` records are written and
   **nothing verifies them**. Spec the record shape in Lean, then a checker that
   replays a log and recomputes every `R/s+` in it.
6. Router stems: `prove`, `proof`, `lemma` are NOT FORGE stems today, so
   "prove the read loop conserves bytes in lean" routes to STEALTH on `byte`.
   The priority order is already FORGE-first — the earlier diagnosis of
   "first-match beats priority" was wrong; the stem table is simply missing the
   words. Fix in Lean spec + both arms + corpus together.
7. Wire every new gate into `gate-all.sh`, `gate-split.sh`, `repo-complete.sh`
   and CI. Then CTT install test, then version and publish.
