---
description: Install the RoT MoE plugin from this clone -- verify the tree, arm the router, prove it is running. Never elevates, never downloads without asking.
---

<!--
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

The user types `/rot-moe-install` and this becomes the prompt. It is deliberately
SHORT and delegates the detail to CLAUDE.md at the repository root: two copies of
an install procedure drift, and only one of them gets corrected.

`checker/claude-md-lint.sh` asserts that every command named in either file
actually exists in this repository, with a planted-fake negative control. An
install document that has gone stale is worse than none: it sends an agent to
run something that is not there.
-->

Install RoT MoE from this clone. Read `CLAUDE.md` at the repository root first
and follow it exactly, in order.

The short form, so you can check yourself against it:

1. `bash checker/gate-all.sh` — read the exit code **directly**, never through a
   pipe. If it is not 0, STOP and report which gate went red. A red tree is a
   finding, not an obstacle.
2. `bash ARM_ROUTER.sh` (POSIX) or `pwsh -NoProfile -File .\ARM_ROUTER.ps1`
   (Windows). Offline, seconds, and `DISARM_ROUTER` undoes it completely.
3. Prove it runs rather than assuming: `bash hooks/rot-router.sh --route "prove
   this lemma"` should print a lane, and
   `bash hooks/prover-remind.sh --decide PostToolUse 90 RotGauge - - - 0` should
   print a reminder.

Three limits, and they hold for the whole task:

* **Never elevate.** No `sudo`, no admin shell, no package manager. Nothing here
  needs it.
* **Never download without asking in this conversation.** The plugin installs
  offline. The Lean toolchain in step 3 of `CLAUDE.md` is **several gigabytes**
  and is entirely optional — it only lets the user re-verify the proofs that CI
  already verifies on every commit.
* **Report real output.** Exact error text, exact exit code. Never "there was an
  issue", never a green claimed from a command you did not read the status of.

Finish by telling the user, in two lines: whether the gates were green, and
whether the router is armed. If either is not true, say which and why.
