<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

<div align="center">

# 🜏 RoT MoE — Releases

**Nine voices, one mind — and a kernel that checks the arithmetic**

*Three archives, one version. The tier lives in the name now.*

[![Ko-fi](https://img.shields.io/badge/Support-Ko--fi-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/saimonokuma)
[![Nova-Violet Role](https://img.shields.io/badge/Nova--Violet-Role-9b59b6?style=for-the-badge)](https://github.com/Nova-Violet-Role)
[![License](https://img.shields.io/badge/License-AGPL--3.0_OR_EUPL--1.2-764ba2?style=for-the-badge)](LICENSE)

[![Release](https://img.shields.io/badge/v8.0.1-Animus-0969da?style=flat-square)](#-v801--animus-three-ways)
[![Zero sorry](https://img.shields.io/badge/sorry-0-27ae60?style=flat-square)](#)

</div>

---

## 🎯 Which one do I want?

Three archives, one version — `8.0.1` — and the tier lives in the **name**,
not the patch digit. The `5.x` convention (patch digit as tier) is retired:
the voice contract, the nine charters, the voice gate, the environment
layer and the Animus observer are **the product**, so every archive carries
all eight organs. The tiers differ only in how much of the verification
surface rides along:

| archive | take it when |
|---|---|
| `RoT-MoE-Router.zip` | you want to run it — the whole product, smallest download |
| `RoT-MoE-Router-Lean.zip` | you want to re-prove the claims on your own machine |
| `RoT-MoE-Router-Lean-Extra.zip` | you want the policy argument as well as the proofs |

Nothing is released until everything is green — structurally, not by
promise: the `release` job in `ci.yml` is the only publisher, and it can
only run after every checker job and the whole Lean job succeeded in the
same run, on the same commit the tag lands on.

## 📦 v8.0.1 — Animus, three ways

`RoT-MoE-Router.zip` — the product, in every archive:

| organ | what travels |
|---|---|
| 1 · engine | `engine/rot-lean.md` — the specification |
| 2 · router | `hooks/rot-router.sh` · `.ps1` — routing, the gauge, the voice block |
| 3 · prover | `agents/lean4-prover.md` — the Lean 4 head, an instrument, not a lens |
| 4 · reminder | `hooks/prover-remind.sh` · `.ps1` — speaks only on measured debt |
| 5 · voices | `hooks/rot-voice.dtd` + `agents/rot-nova.md` … `agents/rot-claude.md` — the contract and the nine charters |
| 6 · gate | `hooks/rot-voice-gate.sh` · `.ps1` — one refusal per unspoken summons |
| 7 · environment | `hooks/rot-env.sh` · `.ps1` + `hooks/rot-profile.sh` — `rot.env` under the declared vocabulary, and the `rot` command family |
| 8 · animus | `hooks/animus-observe.sh` + `commands/animus.md` — the paired observer: measured triggers, lens remarks injected mid-run through the router arms' worker-side ear |

`RoT-MoE-Router-Lean.zip` adds the verification surface: `lean/` (the
proof corpus and its mutation suites), `checker/` (every gate this page's
claims answer to) and `SETUP_LEAN` for re-proving on your own machine.
`RoT-MoE-Router-Lean-Extra.zip` adds `UNSEALED.md`, the policy page that
names the `native_decide` trade in full. Each tier is asserted a strict
superset of the one below before anything ships.

Install without unzipping:

```sh
claude --plugin-dir RoT-MoE-Router.zip
```

Or from the marketplace, no download at all:

```
/plugin marketplace add Nova-Violet-Role/RoT-MoE
/plugin install rot-moe@rot-moe
```

## 🔏 Verify what you downloaded

Four files are published, and these are their exact names — so a download
script needs no directory listing (the v6.0.0 Real Test's stranger sat on a
proxy that blocked the release-asset API, and had to guess the fourth):
`RoT-MoE-Router.zip` · `RoT-MoE-Router-Lean.zip` ·
`RoT-MoE-Router-Lean-Extra.zip` · `SHA256SUMS.txt`.

Every archive is published beside its `SHA256SUMS.txt`:

```sh
sha256sum -c SHA256SUMS.txt
```

The packager that built it (`checker/release-package.sh`) asserted the
archive's contents before it shipped — proof modules counted against disk,
charters counted against the declared roster, no build output, no git
history — and proved its own checks can fail before trusting them. The
README's download links are held to the packager's map by
`checker/readme-variants.sh` on every run.

## 🗃️ Prior releases

`8.0.0` (Animus), `7.0.0` (The Working Share), `6.0.2`, `6.0.1`, `6.0.0`
(the first CI-published release), the `5.x` and earlier
three-variant releases remain on the
[Releases page](https://github.com/Nova-Violet-Role/RoT-MoE/releases) as
history, unchanged. Their convention is documented in
`docs/SCRUTINY-0.7.md` and their changelogs in `CHANGELOG-ARCHIVE.md`.
