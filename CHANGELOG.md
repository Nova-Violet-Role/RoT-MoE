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

## [6.0.2] — 2026-08-19

**Patch: the thirty-turn foreground campaign's warnings, closed — and the
original idea delivered.** A subject session running this plugin was fed
thirty natural client asks, one per completed turn, and audited from the
outside: zero critical findings, zero bugs, eight warnings. Everything
below traces to one of those warnings or was found on the way to one. The
first warning — the version string lagging the release — is retired by
this release's own mechanics, which is the only way that one can be.

### Added — the dynamic share: each summoned lens speaks its own turn

The centerpiece, on the Socio's ruling: keep the lean defaults, but
respect the original idea — the lenses' dynamic, distinct points of view,
properly this time. Every stanza now carries δ and μ beside λ, σ and H, so
the whole R/s+ term is recomputable by hand from the stanza alone — and on
ELEVATE the visible δ 0 *explains* the low gauge: nine agreeing lenses,
zero divergence, the engine's own teaching on display. On top of the
measured base, dynamic clauses in a fixed order, each printed only when
the turn earns it: the lead lens's band verdict between the gauge's own
brackets with section 5's correction verb; Nova's NSIL verdict on every
stanza she speaks; a boosted λ saying so beside the risen number; a fused
pair stating the merge law's result with section 3's canonical name;
Chroma's shown timelines; Soleil's *accepted* budget or the word unknown —
never a guess; Violet's jazz track, defaulted by the clock and saying so
("by hour HH") because her charter selects by emotional frequency and that
reading belongs to the convening model, not to a shell. The frame closes
with the turn: NSIL verdict, depth, and section 7's productive tensions
whose both members were summoned. Violet's five track names became a
shell constant mirrored in her formula YAML, held both ways by a new
`voice-contract.sh` D11 arm that was proven able to fail before it was
trusted. The DTD's voice-block comment now declares the grammar the
emission actually honours.

### Added — the CREATIVE lane learns the words people actually use

The campaign's ideation asks — "brainstorm", "ideate", "imagine", "a
tagline" — routed CONVERGENT because the lane's vocabulary only knew its
own nouns. Four stems admitted: `brainstorm`, `ideat`, `imagin`,
`tagline`, across all five surfaces in one commit (both router arms, the
engine spec's TIER 1 row, the Lean snapshot trued up the same day, two new
cross-diff corpus rows). Negatives measured on the shipped matcher:
"ideal", "idea", "brains" and "tag" all stay CONVERGENT. One overlap is
accepted and disclosed: "imaginary" fires `imagin`.

### Fixed — the voice speaks before the act, once

Both Pre and Post tool events built the same routing text from the same
`tool_input` fields, so every tool call injected the identical voice block
twice. The context events are now `PreToolUse` only: the voice speaks
before the act, and the debug records still write on every event.

### Fixed — the density verdicts belong to human queries

BOOST and ELEVATE read prompt density, and tool-loop events were reaching
them with command text — nine lenses at full weight for a `grep`. Both
verdicts are now gated on the query events; tool traffic keeps CONFIRM,
FUSE and OVERRIDE, which never read density.

### Fixed — the reminder cannot accuse the bundled corpus

On a machine with no Lean workspace the reminder fell back to the plugin's
own bundled proofs and then reported *their* age as the operator's proof
debt — an accusation with no defendant. A bundled corpus now suppresses
the staleness clock entirely, and staleness-only advice (nothing failing,
only old) repeats no faster than `STALE_MIN` itself, held by a stamp file.

### Fixed — the debug channel defaults on in hook mode

A capability that is never on does not ship: installed hooks now default
`ROTMOE_DEBUG_LOG` to a per-session file under the state directory —
explicit `0` disables, an explicit path redirects, and a janitor removes
per-session sinks older than seven days. The CLI stays opt-in. `ENV.5`
in the DTD says all of this.

### Fixed — `--route` records like a turn

The CLI printed a lane and wrote nothing, so a scripted route was
invisible to the audit stream. With a debug log configured, `--route` now
runs the same shared pipeline a hook turn runs and writes the same
gauge+route record pair; stdout stays the pre-NSIL lane, byte-identical.

### Fixed — a skip is never a pass

Found on the way, the release's most important repair: on a machine
without PowerShell, both cross-diff checkers skipped every arm-vs-arm row
and then exited 0 — a fake green wearing the words "a skip is never a
PASS". Skips now exit 3 (fail still outranks skip), the checker-mutation
suite gained an INEXPRESSIBLE verdict and a PARTIAL exit for that state,
and the portability gate learned the same branch. The wall distinguishes
green from unmeasured, on every machine.

### Changed — what "spoken" means is written where the gate decides it

The voice gate matches the element tag's literal presence in the last
assistant text, never the stanza's content — closed as works-as-designed,
and the decision now sits at the verdict block of both arms: the tag is
the measurable commitment, the words inside it are the convening model's
honour, and a hook that graded register would block good turns on bad
heuristics.

### For 7.0.0

`bench/ungap-7.0.0.md` opened, per the night order: a single-arm golden
corpus so a pwsh-less machine can still kill single-arm mutants, and the
portability gate's third section vanishing silently without PowerShell.
