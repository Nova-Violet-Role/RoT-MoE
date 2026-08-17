# Changelog

All notable changes to **RoT MoE** are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) —
with one deliberate twist documented below.

**History lives in [`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md)** — every
release up to and including `0.6.2`, unchanged. This file carries the current
release only, so *prior* and *after* stay one screen apart instead of eight
releases apart. `checker/repo-complete.sh` re-measures the counts in the newest
section against the source on every run, which is the reason that section must
not be buried.

---

## [6.0.0] — 2026-08-17

**Major, and this time the criteria themselves changed: the packet grew from
four organs to seven, the lenses became voices, and the release scheme
collapses to a single artifact.** The `5.x` convention — the patch digit
as the tier — is retired. There is no meaningful "router without the
voices" any more: the contract, the charters, the gate and the environment
layer are the product, and they travel in every archive. Three archives
still ship, the tier in the name, all under one version:
`RoT-MoE-Router.zip`, `RoT-MoE-Router-Lean.zip`,
`RoT-MoE-Router-Lean-Extra.zip` — and nothing is released until everything
is green.

### Added — ORGAN 5: the voice contract and the nine living lenses

`hooks/rot-voice.dtd` declares the roster in the DTD method: nine lens
elements, one entity per lens (name, element, sigil, charter, tool grant,
bound), the frame vocabulary the router may utter, the environment
vocabulary, and the exclusion markers no charter may carry. Nine agents —
`agents/rot-nova.md` through `agents/rot-claude.md` — carry full charters
transcribed from the source codices (the ninth from this tree, its missing
codex name disclosed rather than invented), each with its own mechanism, a
declared `<rot:formula>` computation layer in YAML-inside-CDATA, and no
`model:` key: every lens runs on the model the operator selected.
`checker/voice-contract.sh` holds it all in both directions — **19 checks,
six controls**, every control proved able to fail.

### Added — the voice block, on both channels, both arms

The router speaks one stanza per active lens after its untouched marker —
measured factors from that turn's gauge, charter and bound from the DTD —
as plain context on the prompt events and inside the JSON envelope's
context field on the tool-loop events, gated by the measured accepting set.
`ROTMOE_VOICE=0` silences everything.

### Added — ORGAN 6: the voice gate

A FUSE or ELEVATE prompt records its summons; on Stop, a summoned lens that
never spoke blocks the stop **once**, the refusal carrying every missing
charter as the task. The summons is consumed by its own block, the
harness's already-blocked flag stands the gate down, and everything the
gate cannot measure allows. Registered by the plugin and both hand
installers alike; `ROTMOE_GATE=0` disarms it.

### Added — ORGAN 7: the environment layer

Configuration as `rot.env` files — `KEY=VALUE`, no JSON — parsed, never
sourced, under the DTD's declared vocabulary: undeclared keys do not exist,
the live environment outranks every file, and the two keys that decide what
runs are never file-settable. `hooks/rot-profile.sh` adds the sourceable
`rot` command family, enforcing the vocabulary in the write direction too.

### Changed

The README carries a Usage section, the reversed nine-voices passage with
its inventory, and the retirement of "decides nothing" stated in public.
`CLAUDE.md` briefs the installing agent on all seven organs. The claims
table names the new instruments. The gate joins `hooks.json`, both
`ARM_ROUTER` arms and both `DISARM_ROUTER` arms at the same uniform
timeout every other entry carries.

### Fixed

The About section's reproduction example had quietly stopped reproducing
when the CLI's default gauge profile moved to the convener's — caught by
running it, repaired with `--profile FORGE`, and the miss disclosed in
place.
