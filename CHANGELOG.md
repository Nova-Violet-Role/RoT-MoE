# Changelog

All notable changes to **RoT MoE** are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) —
with one deliberate twist documented below.

**History lives in [`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md)** — every
release up to and including `6.0.0`, unchanged. This file carries the current
release only, so *prior* and *after* stay one screen apart instead of eight
releases apart. `checker/repo-complete.sh` re-measures the counts in the newest
section against the source on every run, which is the reason that section must
not be buried.

---

## [6.0.1] — 2026-08-17

**Patch: everything the first Real Test caught, fixed the same day.** Hours
after `6.0.0` was published, a separate first-time-user session installed it
from the public release page and exercised every user-facing claim — 12
aimed tests across 35 live turns, every exit code read directly. It found
one real defect, one behavioral gap, and two rough edges. All of it is
repaired here; none of it was worked around; the tester itself fixed
nothing, by design.

### Fixed — the routing audit certifies OVERRIDE records

The route record has always carried its NSIL verdict, and the audit had
never read it: `checker/log-replay.sh --audit` demanded the stem be owned
by the lane that fired, so the honest record of a documented feature —
`fix our relationship`, a CLINICAL stem overridden to EMPATHIC by Nova's
TIER 2 — was rejected as "a mis-route". It shipped that way because the
checker's own replay corpus contained no OVERRIDE prompt. Now the auditor
consults `nsil`, and the exemption is as narrow as the feature: only
`OVERRIDE` earns it, the stem must still resolve in the router's table (the
privacy property survives untouched), and an override whose lane still
equals the stem's owner is rejected as a contradiction on the record's own
evidence. The Lean model learned the same field (`RouteRec.nsil`,
`Auditable`, `auditable_imp_vocabSafe` re-proved through the new branch),
the replay corpus gained the OVERRIDE worked example, the checker gained
two negative controls, the mutation suite gained three mutants aimed at the
exemption — and the Lean snapshot's EMPATHIC row was trued up with the
`relation` stem the router has carried since organ 5.

### Fixed — the voices carry their provenance

The Real Test's most important behavioral finding: an unbriefed convening
model refused to perform the stanzas, correctly treating unexplained
injected personas as untrusted framing — nothing in the block said the
*operator* installed this. Both router arms now open the block with the
`rot:frame` element the DTD had declared for the router's own voice all
along and nothing had ever emitted: one line naming the plugin, the
operator's deliberate install, the measured summons, and the
`ROTMOE_VOICE=0` switch that proves the voice is opt-out. The voice gate's
refusal leads with the same provenance and names `ROTMOE_GATE=0`. The
marker line stays untouched.

### Fixed — the registered hook commands ask before they leap

On a machine without PowerShell, `pwsh ... || bash ...` printed
`pwsh: not found` on stderr for every hook command on every event —
permanent, ubiquitous noise. Every registered command (the plugin's
`hooks.json` and both `ARM_ROUTER`/`DISARM_ROUTER` arms) now guards the
first arm with `command -v pwsh`, with fallback semantics unchanged.

### Fixed — `rot gauge` refuses a malformed vector

Flag-style arguments where the positional form belongs fell through to a
degenerate `K=1 lenses=none` gauge at exit 0 — a number computed from
garbage, wearing the exit code of a measurement. The wrapper now refuses
anything that is not nine comma-separated numbers, and a non-numeric
breadth, with the usage line at exit 2.

### Changed

`RELEASE.md` names all four published files in one line — the Real Test's
stranger had to guess the checksum file's name on a proxied network that
blocked the release-asset API.
