# NEXT STEPS — 9.0.x

State: 28 commits on `9.0.0`, 0 behind `main`, tree clean, nothing pushed.

## Ready

| item | evidence |
|---|---|
| three tiers manufacture | 9.0.0 / 9.0.1 / 9.0.2 read OUT of the zips; 21/0 |
| eight organs | each measured with a control that fires |
| Lean at current HEAD | `lake build` exit 0 (8746 jobs) · leanchecker 87/87 · control exit 1 · 0 sorry in constants |
| shell surface | 190 files, 0 syntax failures, error tier 0 |
| live behaviour | 3 separate 2.1.238 sessions; 10 events, FUSE fired, breadth 7 |

## Blocking the tag — one thing

`marketplace.json` was never version-pinned (0 refs to any version). It points at
the source, so `/plugin install` follows the branch, not the tag. **Decide before
tagging:** does the marketplace track `main`, or a tag? Everything else is done.

## Order of operations

1. Merge `9.0.0` into `main` (fast-forward, 0 behind).
2. Tag `v9.0.0`, `v9.0.1`, `v9.0.2` on the SAME commit — the tiers differ by
   archive content, not by tree.
3. CI's `release` job publishes; it can only run after every checker and the
   whole Lean job are green on that commit.
4. Verify after publish: download each archive, read its `plugin.json`, confirm
   the digit matches its tag. The packager asserts this locally; the published
   artifact has never been checked.

## Known red, all attributed

- `plugin root` — two registered roots on this machine. Environmental.
- `release consistency` — clears when the tags exist.
- `workflow lint` — CodeMap's pre-commit never refuses; `core.hooksPath` unset.
- `benchmark` D7 — this host's spawn tax. main 1099 ms vs 9.0.0 995 ms; router
  logic 105.3 -> 105.0 ms. Not a regression.

## Debts still open

1. **21 of 31 hook events never observed live.** `hook-contract` proves all 63
   commands EXECUTE; only 10 events were seen firing in a real session. The
   rest need interactive or subagent paths a `-p` run never reaches. Not
   claimed as verified.
2. **R2 remains a safety property, not a reproduced fix.** The live corruption
   was real; its mechanism was never reproduced from any shell.
3. **The audit harness is the least-audited code here.** Three of my probes
   returned wrong answers that read exactly like defects, and I hit the
   `grep -c` trap twice — it prints 0 AND exits 1, so `|| echo 0` yields "0\n0".
   Worth a checker of its own before the next audit.
