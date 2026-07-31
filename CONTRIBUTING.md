<!-- SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2 -->
<!-- Copyright 2026 Saimonokuma. -->

# Contributing

## The one rule

**No claim without a green run.** Paste the command and its real exit code. Not
"this should work" — the output.

Read the exit code **directly**, never through a pipe. `bash checker/x.sh | tail`
gives you `tail`'s status, not the checker's. That has produced a false green in
this repository before, and it is recorded in `NOTICE.md` rather than hidden.

## Before you open a PR

```sh
bash checker/preflight.sh          # what you have, what will SKIP
sh   checker/spdx-sweep.sh         # every source file carries the dual grant
sh   checker/no-local-paths.sh     # no machine-local path escapes into the packet
bash checker/install-roundtrip.sh  # installer contract, scratch config only
bash checker/cross-diff.sh         # both router arms agree byte-for-byte
bash checker/mutate-checker.sh     # the checker itself can still fail
```

And if you touched `lean/`:

```sh
cd lean
lake build Proofs.RotGauge Proofs.RotRoute Proofs.RotInstall
lake env leanchecker Proofs.RotGauge      # exit 0 with ZERO output is the pass
bash mutate/mutate_rotgauge.sh            # the theorems must DIE when the model breaks
```

## Standards that are not negotiable

* **Zero `sorry`.** A `sorry` is an admission, not a proof.
* **Never `native_decide`.** It trusts the compiler binary instead of the kernel.
* **Every new theorem gets `#print axioms`.** `sorryAx` means not proved. A
  theorem depending on *nothing* is usually vacuous rather than strong.
* **Every new theorem gets a mutation.** One that no mutation kills is
  `[DECORATIVE]` — label it honestly or delete it.
* **Every new check gets a negative control.** An instrument is guilty until
  proven able to fail. A check that has never gone red is an untested alarm.
* **A mutation that did not apply is DISCARDED, never SURVIVED.** They mean
  opposite things: one is a claim about the theorem, the other about your
  harness. Assert the needle is present before building.

## Things that will get a PR sent back

* Weakening a theorem or deleting a check to make something pass. If a check is
  wrong, say so in the first sentence and fix the *check*, with evidence.
* A spec that freezes a contingent fact. Ask of every theorem: *which future
  correct change would make this false?* If the answer is one the project might
  legitimately make, restate it quantified over the thing that moves.
* Adding a dependency. `node` is the only one, and it is justified structurally:
  Claude Code is itself a Node application.
* Silent formatting churn in `settings.json` handling. That file is somebody's
  live session.

## Where to look first

| you want to change | file |
|---|---|
| the routing lanes or their priority | `hooks/rot-router.sh` + `.ps1`, then `lean/Proofs/RotRoute.lean` |
| the gauge arithmetic | both arms, then `lean/Proofs/RotGauge.lean`, then `checker/corpus-gauge.txt` |
| the installer | `hooks/settings-merge.js` — **one engine, both arms** |
| what the checker proves | `checker/`, and add the mutation that would catch you |

The router is duplicated on purpose: two independent implementations that agree
is evidence a single green cannot fake. The installer shares one engine on
purpose: there is nothing to cross-check it against, and two implementations
editing a live config are two chances to be wrong. Keep that asymmetry.
