# Changelog — archive (6.0.2 and earlier)

The live log is [`CHANGELOG.md`](CHANGELOG.md). **This file is history**, and the
distinction is enforced rather than stylistic.

`checker/repo-complete.sh` treats **only the newest release section as a live
claim** — the counts in it are re-measured from source on every run and must be
true of the tree *today*. Every entry below states what was true **at its own
release**, and re-verifying those numbers against a later tree would be a
category error: it would demand that history change whenever the present does.

That is exactly why the split exists. The live log had grown past 770 lines, and
a reader comparing *prior* against *after* had to scroll through eight releases
of settled history to find the two paragraphs that describe the change in front
of them.

**Nothing was deleted.** Every section is byte-for-byte what it was in the
combined file; only the file it lives in changed.

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

The release is published by CI itself: a `release` job in `ci.yml` that
can only run after every checker job and the whole Lean job succeeded in
the same run — it cuts the `vX.Y.Z` tag on the commit that run just
proved and attaches the three archives with their checksums. Publishing
takes an explicit dispatch with `publish=release`; every other trigger
rehearses the packaging and uploads nothing. A tag that already carries a
Release is a refusal, never a move. In the same commit, ci.yml's
concurrency group learned the workflow name — measured 2026-08-17, the
Monday `verify` schedule fired late, joined the push runs' group, and
cancelled a green board at the 43-minute mark.

### Fixed

The About section's reproduction example had quietly stopped reproducing
when the CLI's default gauge profile moved to the convener's — caught by
running it, repaired with `--profile FORGE`, and the miss disclosed in
place.

---

## [5.0.0] · [5.0.1] · [5.0.2] — 2026-08-14

**Major, and the reason is narrow and precise: the gauge's verdict changed
meaning.** Anything parsing the band string gets a different answer than it did
in `4.0.x`. Nothing else in the observable surface moved — the `R/s+` values
themselves are byte-identical.

### Fixed — one band was applied to ten lanes

The gauge computed `R/s+` correctly and then read it against a hardcoded
`0.9–1.8` on every turn. Those are **one lane's numbers**, and the specification
gives each lens its own optimal range — stated twice, in two independent tables
that were extracted and compared before anything was edited. They agree on all
ten lanes.

The number was never wrong. The **meaning** was:

| lane | its own band | at `R/s+ 1.40` | what `4.0.x` printed |
|---|---|---|---|
| CREATIVE | 1.5 – 3.5 | **BELOW** → *add entropy* | `IN RANGE` → do nothing |
| STEALTH | 0.5 – 1.2 | **ABOVE** → *compress more* | `IN RANGE` → do nothing |
| FORGE | 0.9 – 1.8 | `IN RANGE` | `IN RANGE` ✓ |

The self-correction signal is the entire purpose of the score, so a verdict
reading `IN RANGE` when the lead lens says otherwise does not merely mislabel —
it **silences the one instruction the gauge exists to produce**.

This is the same defect fixed on 2026-08-13 in the weight tables, where nine of
the ten profiles were documentation and every lane was scored with one profile's
weights. Route correctly, then judge as if you had not.

**Why it survived review, proved rather than asserted:** the old band agrees
with the correct verdict on *exactly one* lane. This is a prover repo where that
lane is the common one, so every test written on an ordinary turn passed.

* `lean/Proofs/RotBandPerLane.lean` — **12 theorems**, 10/10 mutants killed.
  * `no_single_band_suffices` — exhibits a score two lanes classify differently,
    so **no single range can reproduce the per-lane law**. This is the theorem
    that makes the change load-bearing rather than cosmetic.
  * `global_band_wrong_for_nine_of_ten_lanes` — the count was **guessed as eight
    and `decide` said nine**. The docstring records the miss, because that gap is
    the argument for pinning a constant with a proof instead of a comment.
  * `the_only_agreeing_lane_is_forge` — names the one lane that masked it.
* **No second table.** Both arms already had a correct per-lane band table, used
  by the flag and not by the gauge. The first draft transcribed the ten pairs a
  third and fourth time; both were reverted. There is now one table and one
  lookup per arm.

### Changed — the verdict names its bounds

`BELOW RANGE (1.5-3.5)` rather than a bare `BELOW RANGE`. With ten bands live,
the old string could not say **which** band judged the score. All 12 pinned rows
in `checker/corpus-gauge.txt` moved in the same commit as the code, never after
it. Cross-arm diff: **97 passed, 0 failed**, both arms agreeing on all ten lanes.

### Fixed — the router spent a tenth of its per-turn budget re-reading one file

| what | before | after |
|---|---|---|
| convener config read (202 197 B `settings.json`) | 48 ms | **17 ms** |
| debug-log rotation, per 300 turns | 200 full rewrites | **10** |

The rotation bug is the instructive one. The log *was* capped, at exactly 5000
lines — and trimming **to** the cap means every subsequent turn appends line
5001, trips the check, and rewrites the whole 4.4 MB file to drop a single line,
forever. Hysteresis (trim to 80 %) ends it. Measured per-turn cost fell
**521.5 ms → 474.6 ms** against a **deliberately unchanged** 500 ms bound.

### Fixed — a staleness exemption that would have excused every workflow

`git ls-tree` without `-r` returns the *directory entry*, not the files beneath
it. The lookup matched nothing, every workflow was classified NEW, and NEW files
are exempt from every staleness rule. It stayed masked because established
workflows pass on run history before reaching that branch.

The **sixteenth** time in this repo that an instrument unable to distinguish
*"I could not check"* from *"the check passed"* has failed **toward the
exempting direction**. The lookup now asserts it found something before an
exemption may be granted, and that assertion was verified by breaking it on
purpose.

Also fixed: `actions/upload-artifact@v4` silently skips dotted paths, so
`.release/*.zip` uploaded nothing. Visible only because `if-no-files-found` was
set to `error` rather than `warn`.

### Corrected

* The releases page claimed **154 theorems**. The tree has **1632**. Stale, not
  approximately right, and fixed here rather than left to age.
* Counts moved with the tree everywhere they are claimed: **87 modules, 1632
  theorems, 77 mutation suites** in `README.md`, `plugin.json`,
  `marketplace.json` and `CITATION.cff`.

### Verification

| instrument | result |
|---|---|
| `lake build` | exit 0, **zero `sorry`**, exit code read directly |
| `#print axioms` | no `sorryAx` |
| `lake env leanchecker` | exit 0, zero bytes — absent-module control exits 1 |
| mutation, new module | **10 killed, 0 survived, 0 discarded** |
| cross-arm diff | **97 passed, 0 failed** |
| gates | **65 / 65 green** |
| per-turn cost | **475 ms** against the 500 ms bound |


## [4.0.0] · [4.0.1] · [4.0.2] — 2026-08-14

**Major, and the reason is what now travels: the shared proof corpus ships inside
the release.** `Lean Theorem/` — 3 subjects, 8 modules, **71** kernel-checked
theorems — is carried by the LEAN and UNSEALED archives and is verified present,
non-empty and documented before packaging can succeed.

### `/corpus` — the corpus is FETCHED, not tied to the release cadence

`SETUP_CORPUS.sh` / `SETUP_CORPUS.ps1`, and a `/corpus` slash command, refresh
`Lean Theorem/` from `main` on demand. **The reason is the release cadence:** the
corpus grows by fork and pull request, so shipping it only inside archives would
mean cutting a release every time somebody contributes a theorem — the plugin
version would be tracking other people's proofs. The archives now carry a seed;
the fetcher keeps it current.

It follows `SETUP_LEAN`'s contract — detect, report, ask — with both arms sharing
one exit-code contract: `0` current or declined, `3` update available, `4` absent,
`2` refusal, `1` fetch failed with the existing corpus untouched. All four
non-trivial codes were measured on the POSIX arm against the live repository.

It will not silently overwrite local work: files modified since the last fetch are
listed first, the old corpus is moved aside as `.pre-fetch-<timestamp>.bak` rather
than deleted, and a download containing **zero** `.lean` files is refused — that is
an erasure, not an update.

**This is not Dependabot, and it could not be.** Dependabot updates declared
dependencies in ecosystems it knows; it has no Lean ecosystem and cannot reinstall
a plugin. `.github/workflows/corpus-update.yml` re-proves that the corpus still
travels on every push touching `Lean Theorem/` and on every published release.

### The corpus travels, and the packaging can no longer lose it

* `checker/release-package.sh` counts every corpus module in the LEAN archive
  against what is on disk, and asserts the corpus is **absent** from CORE. A zip
  containing only a README would have satisfied a presence check; it does not
  satisfy a count.
* `checker/repo-complete.sh` **refuses** a tree whose corpus is missing, empty,
  undocumented, or counts zero theorems. Negative control: hiding the folder
  makes it exit 1.
* Cost, measured with and without the folder rather than estimated:
  CORE **+0 bytes**, LEAN **+476 669 B** (+466 KB, +20.9 %), UNSEALED the same.

### A path with a space was silently destroying work

`paths_for` was consumed by unquoted `$(...)`, so `Lean Theorem` split into
`Lean` and `Theorem` and the corpus would have shipped **empty and green**. The
packaging loops now set `IFS` to newline, and a probe asserts the mechanism —
neutralising the guards makes the build fail with `Theorem` as a missing path,
verified.

The same word-split was found in **`checker/portability.sh`**, where
`git ls-files -s | awk '{print $4}'` truncated every offending path to `Lean`:
the checker counted 6 files correctly and could name none of them. It now splits
on the tab git actually emits.

### Corrections — stated, not quietly patched

* **The theorem count was wrong.** The corpus was published as **1608**, counted
  by grepping the word `theorem`, which also counts it inside doc comments. The
  canonical `checker/count-theorems.sh` said **1587** before the withdrawal
  above, and **71** after it. Corrected everywhere it appeared.
* **Six shipped `.sh` files had no exec bit in the index** — four corpus mutation
  suites and two files added in 3.0.2 — and would have failed on Linux.
* **A CI step depended on a third-party package registry.** `choco install zip`
  failed on `windows-latest` and took 37 checker steps down with it. Windows now
  falls back to a 7-Zip shim that is *proved to build an archive* before the step
  reports green, and refuses any flag it was not written for.

### README

Trimmed from **2446 to 1912 lines** by removing five sections that described
measurement apparatus and process rather than capability: the benchmark, the
PROVED/CORRECTED/MEASURED map, the preregistered experiment, the author-correction
log and the A/B study. Nothing describing what RoT MoE *does* was removed.

---

## [3.0.0] · [3.0.1] · [3.0.2] — 2026-08-13

**Major, and the reason is observable output: the route record gains three fields
and every NSIL decision in §3 is now reachable.**

### NSIL is complete — all five §3 decisions are live

`OVERRIDE` and `BOOST` join `CONFIRM`, `FUSE` and `ELEVATE`. Both arms, byte
identical, verified by a nine-lane parity run.

* **`OVERRIDE`** — implemented as a *refinement of FUSE*, because that is where
  the evidence exists. A prompt like §3's own `fix our relationship` fires a
  technical stem *and* a human one, so it is already a two-lane turn; §3 says the
  human reading wins rather than blending. Deliberately narrow: EMPATHIC fused
  with a technical lane only. The lead changes **and the profile follows it**.
* **`BOOST`** — one lane, dense prompt, `+0.3` (§3's own stated typical) applied
  to that lens's λ *in the active profile*. Measured: STEALTH Soleil `2.5 → 2.8`,
  `R/s+ 0.69 → 0.75`, with a short-prompt control staying at `2.5`.
* **`relation` added to the EMPATHIC stem table.** §3's worked example could not
  previously fire, because the word it turns on was not a stem. The specification's
  own sentence is now a live route.

**A false marker was found and fixed before release.** The first `BOOST` draft
raised λ *before* the profile was mounted; the profile then reloaded the vector
and discarded the boost, producing a route line that announced `[NSIL BOOST
Soleil]` beside a record carrying the unboosted `2.5`. `RotNsilBoost.lean` proves
the operations do not commute, so the ordering cannot be reintroduced quietly.

### Nova's band flag — §5's per-lens ranges are enforced as a signal

Every route record carries `"band":"BELOW"|"IN"|"ABOVE"` against **its own lane's**
§5 range. **STEALTH at 0.69 is the first lane ever to read `IN`.** The flag is
never a veto — §5 is explicit that out-of-range is a correction signal — and
`flag_is_not_a_veto` proves the lane is untouched.

### Soleil's TOKEN_EMERGENCY_MONITOR, coupled to Chroma's timelines

`"timelines":{"spawned":12,"shown":5}` normally, `"shown":3` with
`"tokenEmergency":true` when a caller supplies `ROTMOE_TOKEN_PCT` below 20.
**The budget is accepted, never guessed:** the payload was measured to carry no
token budget, and an absent reading is *not* an emergency — an alarm with no
sensor attached must stay quiet.

### Fixed

* **`checker/gauge-cross.sh:117`** invoked the router without `--profile FORGE`,
  so after profile switching it compared a FORGE-pinned corpus against CONVERGENT
  weights. This gate runs **only in CI**, which is why ten green local gates said
  nothing about it. Caught by CI on `afe71e0`.
* **`RELEASE.md` anchors** were left pointing at pre-migration headings.

### Proofs

`lean/Proofs/RotNsilBoost.lean` (9 theorems) and `lean/Proofs/RotBandMonitor.lean`
(11 theorems). Total **1611**, zero `sorry`, `leanchecker` clean. Six mutations
applied and verified present; all six killed. One further mutation was
**discarded** — the patch did not land — and is reported as discarded, never as
survived.

---

## [2.0.0] · [2.0.1] · [2.0.2] — 2026-08-13

**Major, and the reason is observable output: every routed `R/s+` value changes.**

### The lane now chooses the weights — all ten §4 profiles are real

Both arms carried a single table (FORGE) and scored every lane with it, so nine
of the ten profiles in the specification were documentation. A CLINICAL turn
weighted Anti-Venom at 1.9 instead of her CLINICAL 2.5; an EMPATHIC turn
weighted Violet at 0.6, which is what *FORGE* thinks empathy is worth.

| lane | lead | before | now |
|---|---|---|---|
| EMPATHIC | Violet | 0.31 | **0.67** |
| CREATIVE | Carnage | 0.32 | **0.81** |
| STEALTH | Soleil | 0.39 | **0.69** |
| STRATEGIC | Nova | 0.47 | **0.67** |
| EXECUTIVE | Venom | 0.44 | **0.70** |
| PREDICTIVE | Chroma | 0.41 | **0.74** |
| RECURSIVE | Eidolon | 0.45 | **0.71** |
| CLINICAL | AntiVenom | 0.57 | **0.72** |
| FORGE | Claude | 0.66 | 0.66 |

The spread collapses from **0.31–0.66 to 0.66–0.81**: every lens now performs
comparably in its own lane. The Router was never weak at empathy or creativity —
it was being weighed on Claude's scale.

*One principled substitution, disclosed:* §4 ships eight symbiotes, so the nine
non-FORGE profiles say nothing about the ninth lens. Every profile silent about a
lens uses that lens's **§2 default** (Claude 1.5/1.05) — sourced, not invented,
stated once and applied uniformly.

### CONVERGENT is the default, not FORGE

CONVERGENT is the convening model itself — the lane that fires when the model
takes the lenses' responses and makes one answer out of them. That is the **R/s+
convergence point, the fulcrum of the engine**. Both arms had been starting from
FORGE, which is the hand's profile, not the convener's. A no-trigger turn now
scores Nova at her CONVERGENT **1.6** rather than FORGE's 1.4.

This also settles the breadth curve: R/s+ peaks at 4 and falls to 0.17 at
breadth 9, which is the arc of reasoning drawn to scale — divergence rises as
lenses take distinct positions, then collapses as they converge on one solution.
**Low R/s+ at full breadth *is* the convergence point.**

### Added

- **NSIL TIER 2** — `FUSE`, `ELEVATE` and `CONFIRM`, with Nova joining every
  fusion idempotently; `nsil` and `breadth` on every route record, both arms.
- **Symbiogenesis, evaluated at runtime.** The §2 default roster now lives in
  both arms as **integer hundredths**, reproducing Lean's ℚ arithmetic exactly —
  no rounding rule to keep in sync across two languages. Computed for exactly two
  lenses; deliberately silent above two, because §3 defines the hybrid over two
  leads and pairwise folding would add +0.2 per fold that no theorem sanctions.
- **TIER 3**, the complexity gate: `TRIVIAL` / `STANDARD` / `DEEP`, derived from
  TIER 2 rather than from invented word-count cutoffs, so there is no constant to
  tune. Depth measures **effort**; `R/s+` measures **divergence**; both are
  recorded because forcing them to agree would lose information.
- **`--profile` / `-Profile`** on both arms. The weights behind a number are
  never implicit again; `gauge-corpus.tsv` is pinned by Lean against FORGE and
  its runners now say so out loud.
- **The closed form of the solo gauge**: `R/s+ = 0.2273 + 0.1642·λμ`, which
  predicts all nine lenses to two decimals and shows the gauge ranks them by
  exactly one scalar. μ is not decoration — it breaks every λ tie, correctly.

### Changed

- The epistemic map's fourth corner is renamed **`REFUTED` → `CORRECTED`**. A
  claim put to a test and returned different from expectation is the instruments
  working, not a defeat; the old name framed the apparatus as a case against
  itself. The distinction it protects — tried-and-corrected versus never-tested —
  is unchanged.
- Two README sections reframed from confession to capability, with every fact
  retained and no limitation deleted.

### Proofs

**1611 theorems, zero `sorry`**, kernel re-verified. New this release: four in
`RotLensActivation.lean` for TIER 3 and four in `RotEigenform.lean` for the
36-hybrid space, including `lambda_alone_does_not_identify_a_hybrid` — a
conjunction, so neither half can be quoted without the other. Mutation: the depth
threshold kills 5 proof sites; `venomL` and `eidolon` each kill one. Cost
unchanged at **23 spawns** per routing decision against a budget of 41.

## [Unreleased]

Work landed after `0.9.2` and not yet cut into a release. The heading is not
decoration: `checker/repo-complete.sh` scans the **newest release section** of
this file for live count claims, and without a bracketed heading here the 0.9.x
section — a record of what that release actually shipped — was being read as a
claim about today's tree. History does not get rewritten to satisfy a counter.

### A name collision made the shared Lean tree unbuildable while all 61 gates stayed green

`Proofs/RotGauge.lean` and `Proofs/RotMutant.lean` both declared
`RotMoE.classify` — one a `Band` classifier over reals, one an `Outcome`
classifier over runs. **Nothing in this repository imported both, so every gate
was green and the library looked healthy.** It was not healthy, it was *latent*:
the moment anything imported both, lean refused the entire environment with
`environment already contains 'RotMoE.classify' from Proofs.RotGauge`.

That is precisely what had happened to the shared Lean tree at `D:/Lean/proofs`,
whose aggregator imports every delivered module. A bare `lake build` there was
**red for days** on a tree where all 83 modules built individually — and it is
shared, so it was red for every other session on the machine too.

**The repo had adapted to the defect instead of fixing it.** `checker/axiom-audit.sh`
and `checker/axiom-class.sh` both carried comments explaining that per-module
isolation was "not optional" *because* of the clash. A workaround had started to
read like a design decision. A constraint that survives only as long as a bug
does is not a design, and documenting a bug eloquently enough makes it
invisible. Both comments are corrected: the isolation is kept, because it is
right — it keeps each axiom answer attributable to the module named beside it —
but no longer justified by a clash that no longer exists.

Repair: `RotMutant`'s is now `classifyOutcome`; the combined import elaborates,
measured with `#check` returning both with distinct signatures. Its mutation
suite re-ran at **21/21 killed, 0 survived, 0 discarded**.

**`checker/name-collision.sh` is the durable part**, and it is deliberately not
the check that was tempting to write. "RotGauge and RotMutant must not both
declare `classify`" is true today and dead the moment those names change. This
one knows nothing about which modules or names exist — it asks whether *any two
modules contribute the same qualified name*, so it keeps working on modules
written after it. Namespaced declarations are not collisions:
`RotMoE.SessionLog.classify` and `RotMoE.LocalRelease.classify` coexist and
always did, so the comparison is over the qualified name, which is what lean
itself compares.

It found a **second, previously unknown collision on its first run**:
`RotMoE.Run`, declared by both `RotMutant.lean:78` and `RotVerdict.lean:65`.
The latter is now `ScheduledRun`, which is what its own docstring already called
it; that suite re-ran at 7/7 killed.

Its first run also produced a **false positive**, and that is recorded rather
than quietly patched: a line-shaped matcher read the prose "theorem that was
missing when…" (`RotAbility.lean:471`) and "theorem that earns the phrase…"
(`RotGauge.lean:623`) as declarations of `RotMoE.that`. A checker whose first
output is a false positive gets switched off, so the extractor now tracks
block-comment depth — `/-` nests in Lean, so it is counted rather than toggled.
Two controls guard it in both directions: a planted duplicate **must** be
detected, and two differently namespaced declarations of the same short name
**must not** be, since flagging those would forbid a correct tree.

Gate table: **61 → 62**, with `fastSet` 37 → 38 and every `stagedRun` count
moved with it. The prose count in `RotGates.lean` was updated in the same edit,
as that file's own rule requires. `gate-split.sh` re-binds the shell table to
the Lean witness: 12 passed, 0 failed.

Result: the shared tree's bare `lake build` now exits **0**, and all 83 delivered
modules pass `leanchecker` with the absent-module negative control still exiting
1.

### The O4 verdict was retracted by its own control, and the live lane probe was measuring the default

Two findings, and both say an **instrument** was wrong rather than the code.

**1. The O4 result published hours earlier was withdrawn.** It was reported as
CONTRADICTED — 40 of 40 discordant pairs forward, 39 of 39 reverse, every one
against the routed arm — and licensed with a null control of ⟨6, 2⟩. **That
control was measured on the R4 answer-text scorer**, a different instrument
reading a different quantity. Using it to attribute an O4 result is the exact
error P2.4 was rebuilt to fix, and it was made in the direction that flatters
the apparatus.

The control that was actually needed was built from data already collected.
Both orderings run the same 40 tasks, so pairing forward-routed against
reverse-routed by task is an A/A: same arm, same task, only the position
differs. O4 moves on **32 of 40 tasks with no routing difference at all**. Then
the decisive probe — across every A/B pair differing in both O4 and evidence
volume, does the side with the *smaller* haystack carry the *higher* O4?

> **79 comparable pairs. 79 agreements. Rate 1.000.**

`no_statistic_can_separate_them` proves what that costs: when observed signs
equal the confound's predicted signs pointwise, *every* function of those signs
returns the identical value. No test and no re-scoring can recover an arm
effect, because the signs contain none. `a_separating_statistic_needs_a_disagreeing_pair`
states the useful contrapositive — an instrument earns its verdict by exhibiting
a pair that disagrees with the confound, and O4 exhibited zero.

**This does not turn into a win.** Three observables were saturated and the
fourth is inadmissible, so P2.4 produced no evidence in either direction;
`p24_does_not_establish_better_work` still stands and was not weakened. What was
withdrawn is the claim *against* the router, because an unfavourable overclaim
is still an overclaim. Both the verdict and its retraction are kept side by side
in `bench/P24-PREREGISTRATION.md` §10 and §11; editing the first into agreement
with the second would destroy the only evidence that the apparatus caught
itself.

**2. `checker/marketplace-session.sh` was reading a marker that cannot carry a
lane.** It reported "only 1 of 4 live sessions routed to the expected lane" and
"CONTROL DEAD: only 1 distinct live lane" — while, in the same run, the offline
table passed *all 10 lanes routed correctly* and the marker reached the session
4 of 4. The router is bound to 31 events, so a session emits many markers, and
the probe took the **first**: SessionStart, which has no prompt to route
(`chars = 0`, empty stem) and falls to the CONVERGENT default. All four probes
read CONVERGENT, and the single row expecting CONVERGENT "passed". **A check
whose only pass is the row matching the default is measuring the default.**

The probe now selects by **event** rather than by position, and a regression
control asserts the session-level marker is CONSTANT while the prompt lane
varies — so the old read is demonstrably useless rather than merely
discouraged. Result: **10 passed, 0 failed**, with 4 of 4 live sessions on
their expected lane across 4 distinct lanes. Nothing was relaxed: the marker
check, the lane-variation control and the plugin-disabled negative control are
unchanged and all still fire.

Live measurement behind the new `RotLiveRouting`: **517 prompt-routing
decisions, 10 of 10 distinct lanes, 10 distinct R/s+ values.** A constant-lane
router and a constant gauge are both excluded by theorem rather than by
assertion — `constant_lane_cannot_cover_ten` and `constant_gauge_has_one_value`
are stated over an arbitrary router so they are facts about constancy, not about
this log. That is a claim about what the router *does*, and
`routing_is_measured_quality_is_not` welds it to the fact that answer quality
remains unestablished, so neither half can be quoted without the other.

New: `lean/Proofs/RotP24Control.lean` (8/8 mutants killed, 0 survived),
`lean/Proofs/RotLiveRouting.lean` (8/8 killed, 0 survived),
`bench/p24-aa-control.js`.

### The preregistered observables had never been extracted, and one of them contradicts the router

**The headline is the unfavourable half: O4 came back against the routed arm in
every discordant pair, in both orderings.** 40 of 40 forward, 39 of 39 reverse,
zero favouring. §7 of `bench/P24-PREREGISTRATION.md` calls that **CONTRADICTED**,
and §5 said in advance that O4 "is the one that can embarrass the router most,
which is why it is in". It is reported here as prominently as a win would have
been, because that was the promise.

**The reason it had never been seen is worse than the result.** §9 reported the
R4 answer-text scoring of the 160 sessions and called it the P2.4 result. It is
not: §3 declares O1–O4 as *process* observables read out of the transcript, and
§7 scores them per task. The transcripts existed, `bench/work-trace.js` existed
and passed its 16 controls, and nothing had ever joined the two. The run was
scored on the observable P2.4 was rebuilt to stop using.

**Three of the four observables are structurally silent on this corpus.** O1, O2
and O3 produced **zero** discordant pairs — both arms zero on every task, both
orderings. The 40 tasks are knowledge questions; none builds, edits or writes a
file. `RotSaturation` was written after exactly this failure on the 84/84
corpus, and the corpus was reused for the process question without checking the
process observables could vary on it. `a_saturated_observable_cannot_conclude`
now proves the general form for any favouring count, and
`saturation_is_not_evidence_for_either_side` proves the zeros are not quiet good
news either.

**The sweep is attributable, and that is the A/A control earning its keep.** A
total sweep between two identical arms would mean the pipeline manufactures
them; the A/A control measured ⟨6, 2⟩ — it produced pairs and did not sweep.

**The confound is declared and NOT applied.** The unrouted arm ran 103 and 109
tool calls against 49 and 55, and emitted 76 150 and 46 461 evidence bytes
against 9 652 and 9 864. O4 counts a number appearing in no preceding tool
output, so a larger haystack mechanically lowers it and a terser answer scores
worse by construction — `work-trace.js` says so in its own docstring. No length
normalisation was declared in §3 or §7, **so none is applied**; inventing a
correction after seeing an unfavourable result is the freedom preregistration
exists to remove. The verdict stands and the limitation ships beside it.

New: `bench/work-trace-tasks.js` (segmentation measured from the transcript
format — a task prompt is a `user` record with STRING content, a tool result is
a `user` record with ARRAY content; refuses at exit 3 unless exactly 40 segments
appear), `bench/p24-score.js` (counts `d` and `f`, emits **no pooled row**, and
leaves the decision to Lean), `bench/p24-worktrace.jsonl` (160 per-task rows),
`lean/Proofs/RotP24Run.lean` (build 0, leanchecker 0 bytes, **8/8 mutants
killed, 0 survived, 0 discarded**), `lean/mutate/mutate_rotp24run.sh`.

`work-trace.js` now exports its functions and guards its CLI with
`require.main`, so there is exactly **one** extractor: the 16 controls exercise
the same code path the per-task scorer imports. Copying `observables` into the
second script would have let the certified extractor and the publishing one
drift apart.

**A near-miss worth recording: this work was first written straight over an
existing tracked module.** `lean/Proofs/RotWorkTrace.lean` already existed — 18
theorems about the *extractor* (haystack saturation, the positive/negative
control asymmetry, rework and reads-before-write) — and a `Write` replaced it
wholesale, together with its 12-mutant suite. Nothing in the build noticed: the
new file compiled, its own suite passed 8/8, `leanchecker` returned zero bytes.
**Every instrument was green while eighteen theorems were gone.**

What caught it was `checker/repo-complete.sh`, on an arithmetic mismatch nobody
had aimed at this: the theorem count went *down* by three while a module was
supposedly being added, and the module count did not move. A counter that
cross-checks a claim against the tree found a deletion that no proof, no kernel
re-check and no mutation suite could see — because all three ask "is what is
here correct", never "is what was here still here".

Both files are restored from `HEAD` and the new work lives in
`lean/Proofs/RotP24Run.lean` under `RotMoE.P24Run`, which is the right name for
it anyway: `RotWorkTrace` is about the instrument, `RotP24Run` is about the run
it measured. The lesson is narrower than "be careful" — **a green build says
nothing about what a file used to contain**, so a new module gets a name checked
against the tree before it is written, not after.

### The largest obligation in the push guard could be closed by `seq 160`

`sessions160` was probed with `test "$(wc -l < bench/sessions-160.done)" -ge 160`
— a line count, on a file the pusher writes. `seq 160 > bench/sessions-160.done`
closed it. The guard's own docstring forbids exactly this: *"the probe has to
read something the pusher does not control by writing one line."* The rule was
stated at the top of the ledger and broken three rows below it.

`checker/sessions-manifest.sh` now runs as part of that probe. The manifest
carries six fields per turn — ordering, arm, turn number, session id,
stop reason, content digest — and the checker requires four blocks of forty,
complete turn numbering inside each, exactly four distinct session ids with none
shared between blocks, and **160 distinct digests**. Two forgeries are negative
controls, both of which satisfy the old line count: 160 counted integers, and
one real block cloned four times with its labels rewritten.

**The instrument caught itself first.** Its controls called the check function
directly, so a forgery's nine expected failures were added to the real tally and
the script failed a manifest it had just certified — `17 passed, 9 failed` with
every genuine row PASS. Redirecting output does not isolate shell state; a
subshell does. Fixed, then verified in both directions: green on the real
manifest, exit 1 on one corrupted digest, green again after restore.

The probe got **stricter**. Nothing about the obligation was relaxed to close it,
and the three obligations that remain outstanding are still outstanding.

### Two obligations are declared UNMET, and the guard is left refusing

`preferenceMeasured` and `p22Established` are one obligation under two names:
both need a preference panel — odd n ≥ 3, author excluded — judging answer
quality. That is recruitment, not engineering, and no further measurement here
closes it. Both probes are `test -s` against a file; `touch` satisfies either.
Neither file was created. `checker/push-guard.sh` exits 1 with three rows open,
which is the correct verdict on this tree.

### The main run is scored, and Lean is the one refusing to conclude

`Proofs/RotMainRun.lean` (5 theorems, tree now **1531 theorems / 79
modules**) binds the R4 main-run scoring — frozen corpus `b3b9e3f0`, 160
sessions — to the preregistered verdict function. MEASURED: forward 3
discordant / 2 favouring, reverse 12 / 10. PROVED (`decide`, axiom-free,
`leanchecker` exit 0 with zero bytes): both orderings lean the same way,
forward sits below the ten-pair floor, reverse at ⟨12, 10⟩ misses the
Bonferroni-corrected two-sided tail, the run as a whole reaches no
verdict, and even the forbidden pooled ⟨15, 12⟩ would conclude nothing.
Mutation: 4 rounds, 5/5 theorems died, restored green — the ⟨10, 10⟩
mutants flipped to `supported` in agreement with `RotFamily`'s
`verdictM m 10 0 = supported`, which is the cross-module control. Count
claims in `README.md`, `CITATION.cff`, `plugin.json` and
`marketplace.json` were recounted to 1531/79; `STATUS.md` was
regenerated by `checker/status-verdict.sh --write`, never by hand. A
direction the apparatus repeats twice is worth reporting; it is not yet
a difference the rule certifies.

### The cost gate was measuring the machine, and now says so instead of guessing

**A gate that flips verdict on an unchanged tree is not measuring the tree.**
Three consecutive runs of `checker/bench-router.sh` read **478.3 PASS / 809.6
FAIL / 523.7 FAIL** with no commit between them.

Two hypotheses were wrong before the third was right, and both are recorded:

| suspect | measured | verdict |
|---|---|---|
| bash process startup | 20.1 ms idle | 3.5% of the total — not it |
| `node` payload parse | 43.8 ms | not it |
| **external process spawns** | **28, identical on 3 traces** | at 12 ms each = 336 ms vs a self-report of 327–341 |

The router's code had not changed. What had changed was the machine: after 24
live sessions its spawn tax went 12.0 → 20.1 ms and bash startup 20.1 → 92.8 ms,
and **both router arms degraded together** — the PowerShell arm, historically
93–133 ms, read 468–703 ms in the same window. A common-mode shift across two
independent implementations is not a regression in either.

**Three changes, none of which relax the bound. `msBound` is still 500.**

1. **A deterministic check that judges the code.** Spawn count against
   `spawnBudget = msBound / perSpawnMs = 41`, derived and never a literal.
   Measured 22, inside budget, and load-independent. Its control fattens a copy
   of the router with 30 extra subprocesses and requires the counter to notice —
   it counts 52 and refuses.
2. **A third outcome, because two were not enough.** A reading whose spread
   exceeds a quarter of its median has measured the machine; calling that a pass
   is a fake green and calling it a failure blames the router for the load.
   `CostVerdict.unmeasurable` is **not green** and blocks release exactly as
   `exceeded` does — `an_unmeasurable_reading_is_not_a_pass`,
   `only_a_measured_pass_releases`. A quiet machine still reaches a verdict
   (`a_quiet_machine_still_decides`) and a genuinely slow router is still caught
   (`a_quiet_slow_router_is_still_caught`).
3. **The median of three batches**, proved to be one of the readings and never
   an average, so one spike cannot decide — while two slow readings still fail
   (`two_slow_readings_still_fail`).

**The gate is RED as of this entry, and that is the correct verdict.** The cost
check reports `UNMEASURABLE` on a machine still settling from 24 sessions. It
is not a pass and it is not being treated as one.

**A wrong turn is recorded rather than deleted.** Normalising each batch by a
spawn tax sampled beside it should cancel load. Measured, it does not — three
consecutive batches gave 76.1 / 23.7 / 79.5 spawn-equivalents. Load moves faster
than the samples. The denominator hunt was then **stopped deliberately**:
changing the divisor until the gate goes green is the same fitting error
retracted earlier this session, and which fork proxy is correct is left as a
stated open question rather than settled by whichever answer was convenient.

### M21 is closed: a textual property needed a textual instrument

`RotFamily` mutant **M21** tried twice to catch a frozen *derived* value and
survived both times, because `calibCorpus.outOf / preregMargin` and `10`
elaborate to the same term — there is no behaviour to differ. It was recorded as
an open defect.

The defect was never in the mutation suite. It was a **category error**: "still
derived" is a property of the source *text*, and a mutation suite tests
*behaviour*. `checker/bench-router.sh` now greps for the derived form and its
control rewrites it to `:= 41` and requires the check to reject it. Both pass.
The same C01 mutant confirms the boundary from the other side: a *wrong* literal
(`40`) is killed by the theorem, a *right-but-frozen* one is invisible to it.

### The A/A null control ran, passed, and dissolved the pilot's apparent effect

**PHASE 1 CLOSED.** Two **routed** arms, twelve tasks each, same corpus, same
plugin, same primary rule, scored through the identical code path as the A/B
analysis. Both plugin-ARMED: **165** and **167** route records.

| arm | R4 score |
|---|---|
| routed #1 | 6 / 12 |
| routed #2 | 8 / 12 |

Discordant **6**, split **2–4**. **`notSupported`; `controlAdmissible = true`**
— it ran, it found no support between identical arms, and it was not a sweep
(`the_null_control_passed`, `the_control_passed_on_its_merits`). The apparatus
does not manufacture significance, and the release is not voided.

**Then it produced the finding it exists to produce.** Two *identical* arms
disagreed on **6 of 12** tasks; the A/B pilot disagreed on **2**. **The A/B
difference is no larger than the gap between two copies of the same arm, and
points the other way** — `the_ab_difference_is_within_aa_noise`. The pilot's
apparent advantage sits inside the range identical arms produce.

That is not a disappointment, it is the control working. No quantity of A/B data
could have shown it, which is the whole argument for running the control *first*.
`reportable measuredAA measuredAB = some notSupported`: the A/B reading is
licensed by the control's pass, and it is a null.

Mutants N07–N09 pin the measured numbers — sweep the A/A split, empty it, or
inflate the A/B comparison into a manufactured verdict. All three killed; the
suite is 9/9.

### Gate 0 sealed: the pilot margin chosen before the pilot is re-run

**The seal** (`bench/P24-PREREGISTRATION.md`, AMENDMENT 4), recorded so a later
reader can tell what was fixed before any data existed from what was adjusted
afterwards:

```
governing text  TASKS/PROMISE-TODO.md   34c1274fca8e7616e916f115257e2afd7a93e084
task corpus     bench/corpus-40.jsonl   b3b9e3f084a0a0af4563cb1d47f63be534b7e27b
scoring + gate  lean/Proofs/RotFamily.lean       0cc120e6aefb36bd35d79acc3826551d60f4ad87
null control    lean/Proofs/RotNullControl.lean  fa702b710e5b86d80be21d5e6206af205757e9ca
parent commit   001cf21735d78bff9d1f250d367b6cb005f997e6
```

At the moment of sealing the P2.4 verdict **did not exist** — the pilot reached
no verdict under any of the four rules, the A/A control was designed but not
run, and the 160 sessions had not started.

**The old release condition is struck, with the date, in the governing text
itself.** `TASKS/PROMISE-TODO.md` now holds exactly one clause, and it states in
prose what `RotMoE.Family.Outcome` states in the type: all three of SUPPORTED,
NOT ESTABLISHED and CONTRADICTED ship as 1.0.0.

**The pilot margin is derived, not picked.** 8 of 80 is exactly one tenth — a
relation between two declared constants. `marginDivisor` is *computed* as
`calibCorpus.outOf / preregMargin`, so `pilotMargin` yields 1 at twelve pairs
and 2 at twenty, both inside the proved bands, and
`a_one_tenth_margin_is_reachable_at_every_pilot_size` keeps the choice from
expiring when the pilot size changes. The justification cites no pilot score;
applied afterwards, the pilot admits under the primary rule *and* both
sensitivity rules.

**This resolves the CONTESTED fractional-margin section.** Its diagnosis was
right — a fraction flattened into a number — and its fraction was wrong: I wrote
`/ 5` believing the denominator was the 40-task corpus. Against the real 80 it
is `/ 10`.

**OPEN DEFECT, found and NOT closed: a frozen derived value is invisible to
mutation testing.** Mutant M21 tried twice — restating the proportion over
literals, then replacing the computed divisor with `10`. **Both survived, and
both had to.** `calibCorpus.outOf / preregMargin` *is* 10 today, so the derived
form and its current value elaborate to the same term and no build distinguishes
them. "This number is still derived" is a **textual** property; a mutation suite
tests **behaviour**. M21 is withdrawn from the suite rather than counted as
defended, the reasoning is written into `mutate_rotfamily.sh` where the next
reader will meet it, and **the instrument that would defend this does not exist
yet**. Every other contingent-constant guard in this repo has the same blind
spot.

### The A/A null control, and a pilot denominator that is finally derived

**A0.1 closed.** §5 never said what the pilot's O5 score is *out of*. It is now
derived from the two quantities the document does fix — tasks and orderings:
`pilotDenominator tasks orderings := tasks * orderings`. The run pilot was
**12**; §5's own 10-task pilot under §6's both-orderings rule is **20**, not 80.
`the_inherited_margin_is_inapplicable_to_any_pilot` proves the calibration
corpus's 8-of-80 is *inapplicable* — not failing — at either, so §5 must state a
pilot margin rather than borrow one. `the_reachable_pilot_margins` gives the
bands (≤ 6 at twelve, ≤ 10 at twenty) as a range rather than a chosen value,
because choosing one after seeing the pilot is the contamination §5 exists to
prevent.

**A1.1: `lean/Proofs/RotNullControl.lean`, 11 theorems.** An A/B experiment
cannot tell you whether your pipeline would report a difference between two
*identical* arms. That is the one defect undiscoverable after the fact, so the
control runs routed-against-routed and the apparatus must return
`notSupported`.

Three properties make it a control rather than a ritual:

* **One verdict function.** `runVerdict` is shared by the experiment and its
  control — a control with its own scoring path tests a second apparatus, not
  the one that produces the result. Mutant **N04** severs the dependency and is
  killed.
* **A perfect sweep is REFUSED, not celebrated.** Two identical arms cannot
  disagree systematically; a sweep is the manufacturing signature of an
  ordering, caching or position confound.
  `the_sweep_check_covers_what_the_verdict_misses` measures exactly where the
  check earns its keep: a full sweep is `notSupported` up to **9** pairs and
  `supported` from 10, so without it a nine-pair one-sided A/A passes as clean.
  I first wrote that theorem at ten pairs and `decide` refused it.
* **An empty control is not a pass.** Zero discordant pairs means the control
  never ran; `controlAdmissible` requires that it did.

`reportable` makes the dependency a function: a broken control returns `none`,
never a verdict with a caveat — the same discipline as `Margin.applyTo`.

**Release condition changed** in `TASKS/PROMISE-TODO.md`: apparatus integrity,
not outcome direction. A **NOT ESTABLISHED** result ships as 1.0.0.

### RETRACTION: I read the wrong denominator and charged the spec with my error

**The two entries below are CONTESTED and AMENDMENT 2 is SUSPENDED.** Kept
unedited, because a record that quietly removes a wrong claim is worth less than
one that shows it withdrawn.

*The pilot was scored out of 12; §5 says 80.* §5 reads "A 10-task pilot per arm
… at least 8 of **80** room". I took "10-task" as fixing the O5 denominator and
never derived the 80. **80 = 40 tasks (§4) × 2 orderings (§6)** — the same
arithmetic that makes `sessions160` be 40 × 2 arms × 2 orderings. At `outOf = 80`
the gate admits every score from 8 to 72, 65 of 81 outcomes:
`the_preregistered_gate_is_satisfiable`, `the_sound_gate_admits_a_wide_band`.
**The gate was sound.** The accusing theorem is renamed to what it proves,
`a_margin_of_eight_admits_no_score_out_of_ten`.

**The open defect is a denominator mismatch**: one sentence names a 10-task
pilot and an 80-denominator score. Unreconciled, and nothing downstream of it is
decidable.

**Root cause is a type.** `admissibleBy` took a bare `Nat` margin and a `Score`
with nothing binding them, so a margin declared for 80 could judge a score out
of 10 and return a well-typed `false` — which I read as a defect in the
document. `Margin` now carries its own denominator and `Margin.applyTo` returns
**`none`** on a mismatch instead of a verdict
(`a_mismatched_denominator_is_not_a_verdict`); `wellFormed` refuses `⟨8,10⟩` at
declaration. Mutant M13 removes that guard — it is this session's bug preserved
as a test. `a_well_formed_margin_always_admits_something` proves the
unsatisfiable-gate failure cannot recur for any well-formed margin at any size.

**The rescore retires the other conclusion too.** Same 24 sessions, four rules,
no new runs (`bench/pilot-rescore.js`):

| rule | routed | unrouted |
|---|---|---|
| R1 strict (shipped) | 3/12 | 1/12 |
| **R2 lenient** | **9/12** | **7/12** |
| R3 leading | 5/12 | 5/12 |
| R4 committed | 8/12 | 6/12 |

**The corpus is not floor-saturated and the rebuild is withdrawn.** The bigger
finding: the scoring rule moves a score by **6 of 12** while the arms differ by
at most **2** — `the_scorer_moves_the_score_more_than_the_arm_does`. The scorer
is a larger uncontrolled variable than the effect it measures, and it must be
preregistered before the full run. No rule favours the unrouted arm; none
reaches the ten-pair floor, so there is still no verdict.

### The margin was a fraction that had been flattened into a number [CONTESTED]

AMENDMENT 2 in `bench/P24-PREREGISTRATION.md`, sealed by content hash
(`69ab3837…`, parent `b85b2424…`) **before** any of the 160 sessions run,
because a design decision made after the data is a contaminated decision.

**Where the 8 came from: `8 = 40 / 5`.** §5's margin was always *twenty percent
of the 40-task corpus* in §4. The defect was flattening that fraction into a
number and then applying the number to a 10-task pilot, where 8 is eighty
percent and unreachable. `the_margin_was_a_fraction_of_the_corpus_not_an_
absolute` proves `marginFor 40 = 8` — the restored fraction reproduces the
preregistered value exactly at the size it was written for, which is the whole
argument that this is a repair and not a re-choice.
`a_fractional_margin_is_always_reachable` proves `2·marginFor outOf ≤ outOf` for
every size, so the unsatisfiable gate cannot recur at any size chosen later.

**The decision goes against the router.** At `marginFor 12 = 2` the routed arm
(3/12) admits and the unrouted arm (1/12) does not, and `corpusAdmissible`
requires both — a corpus the unrouted arm always fails cannot show a difference
between the arms, which is floor saturation, the twin of the ceiling effect
`RotSaturation` was written for. So `the_corpus_is_refused_and_must_be_rebuilt`,
which is §5's own remedy.

**The convenient alternative is named, not left to be found.** A ten-percent
margin would have admitted this pilot:
`a_ten_percent_margin_would_have_admitted_the_floor` proves
`corpusAdmissible (12/10) ⟨3,12⟩ ⟨1,12⟩ = true` beside the twenty-percent
`false`. Mutant M11 applies exactly that loosening and is killed; M12 judges
admissibility on the routed arm alone and is killed.

**Schedule consequence: the 160 sessions do not start yet.** The corpus is
refused at the floor, and six of twelve answers in *each* arm hedged by stating
both numbers. The corpus is too hard, or the tasks invite hedging, or both.
Rebuilding happens before collection, not after.

### The pilot ran, and the gate that was supposed to judge it could never pass [CONTESTED]

`pilot12Pairs` is **MET** — 2 of 6 push-guard obligations now closed. 12 paired
tasks, routed arm then unrouted, 24 real sessions. Manipulation check clean in
both directions: **170** router route records carrying the routed session's id,
**0** carrying the unrouted one. Raw record in `bench/pilot-pairs.jsonl`.

**The pilot is INADMISSIBLE, and the fault is in the specification.** Section 5
admits the corpus only if `admissibleBy 8` holds on a 10-task pilot. That gate
wants margin in *both* directions — `8 ≤ hits` and `8 ≤ outOf − hits` — which at
`outOf = 10` demands `hits ≥ 8` and `hits ≤ 2` at once. **No outcome satisfies
it**, so the corpus would have been refused however the pilot had gone.
`the_preregistered_gate_admitted_no_outcome` proves it.

The repair is not a margin chosen to let this pilot through. It is the general
relationship, quantified over the size that moves:
`a_margin_is_reachable_iff_the_pilot_is_twice_its_size` — a margin `m` is
reachable on `outOf` tasks **iff `2m ≤ outOf`**. Keeping `m = 8` needs 16 pairs;
keeping the 10-task pilot allows `m ≤ 5`, and at 5 exactly one score admits. The
choice between them is **deferred**, because making it after seeing a pilot is
the contamination section 5 exists to prevent.

**A claim of mine was proved false by `decide` mid-edit.** I wrote
`twelve_pairs_admit_exactly_one_score = [4]`, reasoning that `up ⟨4,12⟩ = 8` met
the margin. `decide` refused it: the gate also wants `down ⟨4,12⟩ = 4 ≥ 8`. The
theorem is recorded as `twelve_pairs_admit_no_score` — the form the kernel
accepted, not the form I guessed.

**Measured result, scoring rule fixed before the results were read** (success ⇔
the truth value appears and the naive value does not, applied identically to
both arms):

| | routed | unrouted |
|---|---|---|
| O5 success | 3 / 12 | 1 / 12 |
| hedged (both numbers stated) | 6 | 6 |
| paired wins | 2 | 0 |

Two disagreements and ten ties means `n = 2` against a floor of 10, so
`the_pilot_cannot_conclude` proves this run reaches no verdict — which is what a
pilot is for. **Nothing about H1 is claimed.** The most informative single
observation is that on F1-01 the routed arm answered **37** where the truth is
35, and `bench/work-trace.js` flagged it as an unsupported claim because no
command it ran could establish a theorem count. The routed arm losing a task is
exactly what the new three-outcome rule exists to be able to report.

New: `bench/pilot-prompts.txt`, `bench/pilot-manifest.jsonl`,
`bench/pilot-score.js`, `bench/pilot-pairs.jsonl`, AMENDMENT 1 in
`bench/P24-PREREGISTRATION.md`. `mutate_rotfamily.sh` grew to 10 mutants; M09
reproduces the original defect by dropping the factor of two, M10 claims the
measured pilot passed the gate. Both killed.

### The first promise obligation is MET: a 40-task corpus that discriminates and routes

`bench/corpus-40.jsonl` now exists — 40 tasks, 10 per seed family, fixed before
either arm runs exactly as `bench/P24-PREREGISTRATION.md` section 4 requires.
`corpus40` is the first of the six push-guard obligations to close. The guard
still **REFUSES**, now at 5 of 6 outstanding, first outstanding `pilot12Pairs`.

**The corpus stores commands, not numbers.** Each task carries a `truth_cmd` and
a `naive_cmd`; the expected values are never written down. That is a deliberate
design decision and `lean/Proofs/RotTaskCorpus.lean` (16 theorems, 8 mutants, all
killed) proves why: `the_frozen_check_claims_discrimination_that_is_not_there`
exhibits a world in which a corpus holding today's answer reports a task as
discriminating when the two instruments have in fact converged. A frozen expected
value is a contingent fact wearing the costume of a specification — it expires on
the next commit, and it expires *permissively*.

**Two properties are checked, and both can fail.** `checker/corpus-verify.sh`:

* **DISCRIMINATION** — the truth command and the naive command must disagree. A
  task the naive command gets right is a free point for both arms; it still
  counts toward n and dilutes the sign test.
  `an_indiscriminate_task_cannot_separate_the_arms` proves its contribution is
  exactly zero, and `a_corpus_of_ties_is_vacuous` proves a corpus of such tasks
  reports a dead heat however good either arm is.
* **LANE BINDING** — each prompt must route to the lane it declares, measured by
  running the shipped `hooks/rot-router.sh --route`. Without this the `lane`
  field is decoration.

The lane check is why this is a script and not a `wc -l`, and it earned its place
immediately. It found **twenty-one** defects in the first draft of the corpus:

| cause | tasks | detail |
|---|---|---|
| `Proofs/` begins with the FORGE stem `proof` | 9 | every prompt naming the directory routed FORGE, not its declared lane |
| `ship`, `shipping`, `install`, `lean` are FORGE stems | 11 | my wording, plus two target paths |
| target did not discriminate | 1 | `RotEigenform.lean` gives 2 and 2 |

None of those were visible to a line count, and all of them would have silently
degraded a benchmark that reported n = 40.

A separate harness fault surfaced in the same run: `grep -c` **exits 1 when the
count is zero**, and the first verifier treated a non-zero exit as an error, so
seven tasks with a legitimate answer of 0 read as broken. A count of zero is a
measurement; only a missing file is a fault — the same distinction
`count-theorems.sh` draws between "no input" and "measured zero". Control (c) now
pins it.

**All ten router lanes are covered, including `CONVERGENT`.** The existing bench
key reaches 9 of 10; the fallback that fires when no stem matches was never
exercised, so no benchmark could see it regress. The corpus is the 4 families
crossed with the 10 lanes, which makes balance, coverage and distinctness
consequences of the construction — `every_lane_has_four`,
`the_plan_repeats_nothing`, `forty_rows_does_not_imply_coverage`. That last one
exists because a corpus that drops the CONVERGENT column and doubles another lane
still has 40 rows.

New gate 60, `P2.4 corpus`, deep tier, triggered by `hooks/rot-router.sh` among
others: editing a stem list without re-checking the corpus would silently
invalidate forty lane bindings. `lean/Proofs/RotGates.lean` moved with it —
`shipped.length = 60`, `deepSet = 23`, and the router-staged run 43 -> 44.

Negative controls, both on the real file: making one task non-discriminating gives
exit 1 naming `F1-01(=35)`; relabelling `F1-10`'s lane gives exit 1 naming
`F1-10(CONVERGENT!=FORGE)`; restoring gives exit 0.

### The push guard's own ledger could be opened by a one-line file

`checker/push-guard.sh` refuses every push until six obligations are met. It was
written with four controls, mutation-tested, and it has been refusing correctly
for days. It was also **openable by `echo x > bench/corpus-40.jsonl`**.

Four of its six probes tested only that a file is non-empty while their names
promised a count:

| row | promised | probe as shipped |
|---|---|---|
| `corpus40` | the 40-task corpus | `test -s bench/corpus-40.jsonl` |
| `sessions160` | 160 sessions | `test -s bench/sessions-160.done` |
| `preferenceMeasured` | a panel has run | `test -s bench/panel-results.jsonl` |
| `p22Established` | P2.2 established | `test -s bench/P22-ESTABLISHED.md` |

Only `pilot12Pairs` counted. This is the permissive half of the overclaim family
and it is the more dangerous one: a theorem that says too little fails loudly the
moment someone leans on it, while a **probe** that says too little reports
success, opens the gate, and leaves everyone believing a guarantee that was never
tested. It is the same shape as a mutation that silently fails to apply being
scored `SURVIVED`.

`lean/Proofs/RotProbeStrength.lean` (15 theorems, 8 mutants, all killed) proves
the general fact rather than the incident:
`nonEmpty_cannot_witness_a_counted_obligation` shows a non-emptiness test is
unsound for **every** obligation demanding two or more — not merely for 40.

The converse is proved deliberately in the same file.
`an_inflated_probe_refuses_a_finished_obligation` shows a probe demanding *more*
than its obligation is not `complete`: it would refuse a promise that had actually
been kept, and the obvious repair at that point is to delete the row, destroying
the coverage. Only `atLeast o.required` is both sound and complete, so the repair
counts to the demand and never past it.

The three rows whose obligation genuinely is "one artifact exists" are **correctly**
served by `test -s`, and `nonEmpty_is_sound_for_a_single_artifact` says so. Two
rows were wrong, not six; a panic that rewrote all of them would have been a
different kind of error.

Three findings came out of writing the repair, all of them defects in the check
rather than in the guard:

1. The first strength check scraped the demanded number out of the row's prose
   with a regex and immediately mis-read `p22Established | P2.2 established` as
   demanding *two* of something — flagging a row that is correct. Prose is not a
   data field. The Lean model had this right all along (`Obligation.required` is
   a structure field), and the shell had drifted from it. The ledger now carries
   the demand as an explicit column and the check reads that column.
2. `weak_rows` **skips** any row whose demand is missing or non-numeric, and a
   skip is not a pass — a row written `foo||desc|test -s x` would have sailed
   past unexamined. Control (e2b) now requires every row to be well-formed and
   compares that count against the ledger size.
3. That well-formedness check was first written `NF == 4`, which reported *3 of 6*
   — three probes legitimately contain `|| echo 0`, so awk sees six fields on a
   row the shell parses perfectly. A control that would have refused a correct
   ledger: exactly the wall-shaped defect the Lean file proves about inflated
   probes, this time in the checker. Now `NF >= 4`.

The guard grew from 6 to **11 controls**. Negative control: reverting the
`corpus40` row to `test -s` makes the guard exit 2 with `CONTROL FAILED`, naming
`corpus40:40`; restoring it returns exit 0. The verdict itself is unchanged and
unmoved — **6 of 6 obligations outstanding, exit 1** — because strengthening a
probe does not manufacture evidence. It only stops the guard from accepting
evidence that is not there.

### The gate declared nine lanes against a router that has ten, and "must equal" was enforced by nothing

`checker/dominance.sh:53` carried `LANES_DECLARED=9  # must equal RotDominance.lanes`,
and `RotDominance.lanes` was `9`. The router declares **ten**
(`hooks/rot-router.sh:341-350`: nine lens-led lanes plus `CONVERGENT`, which by
design has no lead lens). So D4 DISCRIMINATION ran with a **full lane of slack** —
the router could have lost `CONVERGENT` entirely, the most-travelled lane, and this
gate would still have printed `ok`.

The evidence had been on screen for some time: the gate's own line reads
**"D4 DISCRIMINATION: 10 distinct lanes reached (>= 9 declared)"**. Ten and nine
were printed side by side and nobody subtracted them. The tree already knew, too —
`RotLens.lean:74` calls nine "the lanes that have a lens of their own, i.e. every
lane except" `CONVERGENT`, and `RotAttribute.lean:306` warns in as many words that
quoting nine "is quoting nine lanes and dropping the tenth".

**The repair is derivation, not a bigger number.** `RotDominance.lanes` is now
`laneRoster.length` over the ten lanes as the router ships them, so the count and
the roster cannot drift because there is only one of them.
`the_declared_count_is_the_roster_length` states it, `the_fallback_lane_is_counted`
pins `CONVERGENT` as a lane rather than a corner case, and
`losing_a_lane_fails_discrimination` shows the gate now refuses what it used to
wave through. `the_roster_repeats_no_lane` closes the counting hole that
`length` would otherwise leave — the same "length is not coverage" gap mutation
P04 found in the push guard last week.

**The second defect was the comment itself.** Both `MS_BOUND` and `LANES_DECLARED`
said *must equal* a Lean constant and **no code checked either**. A comment is not
a binding. `checker/dominance.sh` now extracts both constants from
`lean/Proofs/RotDominance.lean` and compares them, with a control that runs the
same extractor over a source built to yield different values (9 / 999) so the
binding is proved able to fail. Measured end to end: forcing `LANES_DECLARED=11`
turns the gate **red at exit 1** with both the binding and D4 failing, and restoring
returns **16 passed, 0 failed**. The gate went from 13 checks to 16.

**A stale artifact produced a false green, and it was mine.** Delivering the
corrected module to the shared Lean workspace failed — `bad import 'Proofs.RotCeiling'`,
because the shared tree namespaces modules under `Proofs.RotMoe.` — and
`lake env leanchecker` returned **exit 0 anyway**. It re-verifies the `.olean`, and
the one on disk was dated two days earlier from a previous delivery; the failed
build never replaced it. A kernel re-check is only evidence about the source that
produced the artifact it read. The delivery ritual now deletes the `.olean` first.

That prompted a sweep of the whole shared tree, which found a second cross-wiring:
`Proofs/RotMoe/RotLog.lean` imported the **top-level** `Proofs.RotGauge` rather
than `Proofs.RotMoe.RotGauge` — a different file, six days older. It had been
verified against the wrong gauge. Both imports repaired, and the subtree now
measures **71 of 71 modules building and 71 of 71 re-checked by the kernel, with
zero missing oleans** (nine had none at all before this).

**One more silent miscount, self-inflicted.** The new mutant was first called
`D04b`, and the repo-wide counter requires a mutant ID ending in a digit
(`^run_mut(_nth)? [A-Z][A-Za-z0-9]*[0-9] `). The suite ran and killed 12 mutants
while the counter saw 11 — a mutant doing real work and reporting to nobody.
Renamed `D12`; suite and counter now agree at 12 and 709.

12 mutants for `RotDominance`, **12 killed, 0 survived, 0 discarded** — including
`D12`, which drops `CONVERGENT` from the roster and is exactly the defect this
entry repairs.

1526 theorems, 78 modules, 72 suites, 762 mutants, 71 checkers.

### "Nine lenses run on every turn" was two claims wearing one sentence

My own NEXT list called the missing multi-lens evidence **corpus work**: `breadth`
never exceeded 1 across 100 live records, so a richer corpus would surely activate
two lenses at once. That diagnosis was wrong, and reading the router says so in one
line. `hooks/rot-router.sh:625-629` and `hooks/rot-router.ps1:562-565` build the
activation vector against a **single** routed lens and then **assign** `_br=1` —
never increment it. Breadth cannot exceed 1 **by construction**, in both arms
identically. No corpus could ever have produced a 2, and the re-measurement over
the full log rather than the 100-record sample agrees: **3707 gauge records,
`breadth ∈ {0,1}`, never once 2.** That is now explained rather than observed.

`FUSE` and `ELEVATE` — the engine spec's multi-lens paths — are **not implemented**.
A grep appeared to find seven of them in the POSIX arm; every hit was the word
*refuse* or *fuses* inside a comment. Reading the matched lines instead of trusting
the count is the only reason that did not become a false claim in this file.

**So `README.md` had to be corrected, not defended.** "Nine lenses run on every
turn" reads as nine lenses *firing*, and that is false. What is true, and now
proved in `lean/Proofs/RotLensActivation.lean` (20 theorems):

* **Scored, all nine.** `raising_an_inactive_lens_raises_the_gauge` — quantified
  over every lens, every tail and every increase — proves the gauge is not a
  function of the routed lens alone. Reweight a lens that stayed silent and `R/s+`
  moves. `silencing_the_eight_changes_the_answer` puts a number on it: on a real
  FORGE turn the eight silent lenses are **26.9%** of the gauge (`59784850` whole,
  `43679530` routed-lens-only). The word "nine-lens" is earned at breadth 1.
* **Activated, exactly one.** `the_router_can_never_report_more_than_one_active_lens`
  and `fusion_is_unreachable` are stated over *every* roster and *every* lens, so
  they are facts about the construction rather than about today's corpus.
* **The honest half.** `the_breadth_field_separates_no_two_routed_turns`: on a
  routed turn `breadth` is constant, so that log field carries zero information
  about which turn it was. Worth knowing before anyone analyses it as a signal.

**A latent defect the modelling exposed.** The vector is `names.map (· == lens)`
while breadth is the literal `1`. Those agree only if the roster is duplicate-free:
a repeated name matching the routed lens would set two bits while `breadth` still
said one, and the gauge would divide activity by the wrong breadth.
`the_assignment_is_honest_when_the_names_are_distinct` proves the agreement from
distinctness, and `a_duplicated_name_makes_the_assignment_undercount` proves the
hypothesis is load-bearing rather than decorative. Measured on disk: 9 names, 9
distinct — so this is stated as a general theorem about distinctness, not as a fact
about the current nine. A tenth lens is a change the project may legitimately make,
and a spec that forbids a correct future is a defect.

Two instrument notes, both self-caught. `reduceIte` silently failed to reduce
`if false = true then 1 else 0` and omega then compared two differently-shaped
atoms; the fix was found by probing a five-line scratch under `lake env lean`
rather than by a fourth guess at the tactic. And the suite's own skip guard fired
correctly on `LEAN_ROOT=lean` — the script already `cd`s into `lean/`, so the
variable pointed at `lean/lean` — refusing at exit 3 instead of reporting a sweep
over nothing.

7 mutants, **7 killed, 0 survived, 0 discarded**. L05 is the one that matters: it
rewrites `gauge` to score only the routed lens, which is exactly what "nine-lens is
decoration" would look like in code, and it kills three theorems.

1526 theorems, 78 modules, 72 suites, 762 mutants, 71 checkers.

### A branch push is still a push — and the hook was installed where git does not look

Fifty-eight gates existed when a branch was pushed to the remote while the
completion promise was unfulfilled. Not one of them was about the push **action** —
every gate judged the *tree*. The reasoning at the time was *"pushing a branch is
evidence-gathering, not publishing"*, and it is not: the branch was visible on the
remote, CI ran against it, and its green was then cited as evidence about `main`.

`lean/Proofs/RotPushGuard.lean` is written to make that sentence unstatable rather
than merely discouraged. The load-bearing theorem is
`the_target_cannot_change_the_verdict`: for every state and every *pair* of
destinations the guard returns the same answer, so "it is only a side branch" and
"it is only a tag" cannot move it. `permission_is_exactly_an_empty_outstanding_list`
supplies the other direction — a gate that can never open is a wall, and the first
person to finish the work would delete it.

**Three findings came out of building it, and all three were defects in the new
work rather than in the old.**

*The hook was installed where git does not look.* `.git/hooks/pre-push` was written,
made executable, and `git push --dry-run` **exited 0 with no output at all**. The
repository sets `core.hooksPath = .githooks`, so the file was dead on arrival. A
deliberately-failing probe hook confirmed it: still exit 0. Reinstalled at
`.githooks/pre-push`, which also means the guard now ships with the tree instead of
living in one clone. Re-measured: `main`, a side branch and a tag are now **all
refused at exit 1**, and the remote is untouched at `cef996e`.

*A control that matched itself.* The first target-independence check grepped its own
source for a literal — and the pattern string contained the thing the pattern looked
for, so it reported CONTROL FAILED on a clean script. Assembling the needle at
runtime fixed that and then flagged six lines, three of which were `ok()`, `bad()`
and `inf()` using their own `$1`. A function's parameter is not the script's argv and
no text pattern separates them reliably. The check is now **behavioural**: the guard
re-runs itself against main, a side branch and a tag and fails if the three verdicts
ever differ — the theorem, executed. Its own negative control confirms the
comparison catches a script that *does* branch on its destination.

*A probe that could never succeed.* The pilot row originally ran
`bash checker/pilot-size.sh` — a script that does not exist. The obligation could
never be met, so the guard would have refused forever even after the pilot was
genuinely finished, and the obvious repair at that point is to delete the row and
destroy the coverage. A gate that cannot open on correct work is a defect, not a
safeguard. Control (d) now asserts every probe invokes only scripts that exist, and
(d2) proves that control can fire.

**Mutation P04 found a real spec gap and it was closed, not explained away.**
Replacing one ledger entry with a duplicate of another left six entries, kept
`allObligations.length = 6` true, and left every theorem green while silently
dropping an obligation from the guard. Length is not coverage. Two theorems close
it: `the_ledger_lists_every_obligation` (constructor by constructor, so adding a
case to `Obligation` without listing it fails to compile) and
`the_ledger_repeats_nothing`. P04 then died. Four mutants, four killed — after the
first run reported **1 survived**, and one earlier attempt was correctly recorded as
**DISCARDED** because the replacement contained its own needle.

The guard refuses right now, 6 of 6 outstanding, first outstanding `corpus40`. That
is the honest state and it is the point.

**And that honest state immediately broke the gate suite, which is the fourth
finding.** Registered as a gate, `push-guard.sh` turned `gate-all` red: the
registry's contract is "exit 0 is green", and the guard's correct answer today is
exit 1. A permanently red suite is not a strict suite — it is one that gets deleted,
and deleting it would remove the only gate that judges the transmission.

So the script now has two modes, and the distinction is the whole point. Default
mode answers *may anything be transmitted right now* — exit 1 until the promise is
fulfilled, and that is what `.githooks/pre-push` calls. `--instrument` answers *is
this guard sound*, ignoring which way it points: exit 0 when the verdict is
determinate **and all six controls reported**, exit 1 only when the guard cannot
stand behind its own answer. `gate-all.sh` and CI call that one, sharing a single
implementation so the two can never drift.

The gate asks the question that CAN pass today. The hook asks the one that must not.

### A zero gauge is always a zero input, and the division guard was load-bearing

The live run measured `breadth ∈ {0, 1}`. `breadth = 0` is not an anomaly — it is
every turn on which no lens fires — and the router divides by it at
`hooks/rot-router.sh:437`:

    H  = (breadth > 0 ? act / breadth : 0.0);    # share of the turn breadth

Probed in both directions rather than assumed, and the guard turns out to be
holding up production:

    awk 'BEGIN{ H = 0/0 }'                        -> fatal: division by zero, exit 2
    awk 'BEGIN{ H = (0>0 ? 0/0 : 0.0); print H }' -> H=0,   exit 0
    awk 'BEGIN{ H = (2>0 ? 1/2 : 0.0); print H }' -> H=0.5, exit 0

Without it, every CONVERGENT turn would kill the gauge process outright.

**What Lean can and cannot settle here, said before the theorems rather than
after.** Lean cannot reproduce that crash: `Nat` division is *total*, `n / 0 = 0`
is a theorem of core Lean, so a Lean model of the unguarded expression would be
perfectly well behaved and would prove nothing about `awk`. The crash is MEASURED
and stays measured. `lean/Proofs/RotGaugePositivity.lean` settles the part a
measurement cannot:

* `the_guard_agrees_wherever_division_was_defined` — over every activity and every
  positive breadth, the guard changes nothing it was not added to change
* `the_guard_is_total_at_zero_breadth` — total at the value production actually hits
* `a_term_vanishes_only_when_a_factor_does` — a lens contributes nothing exactly
  when one of λ, σ, μ is nothing; there is no third way for a term to vanish, which
  is what makes a zero *attributable*
* `the_gauge_vanishes_only_if_every_lens_did` — over every possible ensemble: the
  sum is never the cause of a zero
* `one_live_lens_is_enough` — one lens with all three factors present forces the
  gauge non-zero regardless of the other eight. `R/s+ = 0.0` therefore cannot come
  from a live ensemble in which anything fired at all, which is what makes the
  engine's "a zero gauge is a violation" law enforceable instead of aspirational
* `the_witness_is_the_full_ensemble` / `the_witness_gauge_is_positive` — the
  anti-vacuity pair: nine lenses, not a convenient subset, and a positive result
* `the_forbidden_zero_needs_every_lens_dead` and
  `killing_a_single_lens_does_not_zero_the_gauge` — the failure exhibited, and the
  robustness that nine lenses buy

Mutants G01–G06: change the zero-breadth branch, turn a product into a sum, drop
the head term from the fold, make the empty sum non-zero, set `K` to eight, or
shorten the witness to eight lenses — six ran, six killed.

### The packet was three modules behind the tree, and the gauge was measured live

The local release packet is required to track the last commit. It did not: the
installed plugin carried neither `RotReadmeTable.lean`, nor `RotWorkflowRoles.lean`,
nor `RotVerdictDecision.lean`. Rebuilt from `commit HEAD`, stamp `1.0.0-local.83`,
source `7e18ce1`, and installed into all four places that must agree — the live
plugin cache, its marketplace mirror, the Claude-Test plugin cache, and the CTT
release directory. Every retired copy was kept, never deleted. Both plugin trees
now carry **70 modules / 1333 theorems**, and `diff -rq` between the live install
and the CTT install exits 0.

**Two instrument failures on the way in, both worth recording because both were
mine and neither was the tool's fault.**

The first: `ARM_ROUTER.sh` run from the unpacked temp directory armed
`settings.json` with hook commands pointing at `/d/Temp/pkt83/hooks/...`. The
installer did exactly what it was told; being told the wrong thing was the defect.
Restored from the backup taken beforehand, and the live config verified clean —
**0 commands pointing into a temp directory**. RoT MoE's router is installed
through the *plugin* arm, whose hooks live in the plugin's own `hooks.json`, so
`settings.json` was never the right place for it.

The second: reading that config with `JSON.parse` threw on a **UTF-8 BOM**. Before
calling that a defect it was traced — `hooks/settings-merge.js:103-104` strips the
BOM, `:268` restores it, and `:280` *asserts* the BOM state survived the write. The
installer handles this deliberately and correctly. The instrument was mine and it
was the one that was wrong.

**The live-session evidence, which is the point of all of it.** With the fresh
packet installed, `checker/ctt-session.sh` ran a real Claude-Test session: twenty
turns, **zero failed**, **100 route records written this run**, and **zero trace
leaks** — the internal-only seal held on every turn. From those records, measured
rather than asserted:

| property | measured |
|---|---|
| gauge computations | 100 (plus 100 route records) |
| distinct `Rs` values | **16**, spanning `0.157 … 0.664` |
| `Rs == 0`, the forbidden placeholder | **never** |
| `K` | 9 on every single record |
| distinct lens-activation vectors | 8 |
| `breadth` observed | 0–1 |

So **`R/s+` is dynamic: MEASURED**, not proved — sixteen distinct values out of a
hundred computations, on nine lenses, with the placeholder value never occurring.
And the honest limit alongside it: `breadth` never exceeded 1, meaning that corpus
never activated two lenses on the same turn. Multi-lens divergence is therefore
**not** measured by this run, and no claim here rests on it. The corpus needs turns
that move more than one lens before that number means anything.

`checker/plugin-root-consistency.sh`, `checker/install-parity.sh` and
`checker/release-install.sh` (24 checks) all exit 0 against the new install.

### Two skipped steps were innocent; the decision underneath them was not

Run 31367304632 of `verify.yml` finished green with two steps skipped, and one of
them was **"Publish the verdict, and FAIL if the committed one is stale"**. A green
job whose staleness check never ran is the exact shape this project refuses to
accept on trust, so it was read rather than assumed.

The skips are legitimate. Both carry `if: steps.decide.outputs.changed == 'yes'`
and the verdict genuinely had not changed. The defect is one layer below them.

`/tmp/verdict.old` is `awk`-extracted from between two markers in `STATUS.md` and
is deliberately empty when the file or the markers are missing. `/tmp/verdict.new`
is the stdout of `checker/status-verdict.sh`. The step then asks `diff -q` whether
they match. Measured here, five lines, both directions:

    two empty files      -> diff says IDENTICAL -> changed=no -> both steps SKIP -> job GREEN
    empty vs non-empty   -> differ                                              (correct)

So if the generator ever produced nothing while exiting 0 — a renamed marker, a
`grep` matching no rows, an early return — the comparison would succeed against an
equally empty predecessor, the log would print *"verdict UNCHANGED — this is the
correct outcome"*, the staleness check would skip, and the job would be green
having measured nothing. Equality is not evidence when both sides can vanish
together. This is the same defect the repository already fixed elsewhere: an
emptied file is invisible to every check that reads its text.

The repair is not to distrust equality. It is that the step had **three** causes
and only ever admitted two answers. `lean/Proofs/RotVerdictDecision.lean` gives the
third one a name and a consequence:

* `a_vanished_verdict_looks_exactly_like_an_unchanged_one` — the blindness, decided
  on both inputs at once
* `an_absent_verdict_is_never_called_unchanged` — stated over **every** possible
  previous verdict, so no future `STATUS.md` can reintroduce it
* `an_absent_verdict_is_not_reported_as_a_change` — `unmeasured` is its own answer,
  not a lean toward the noisy side
* `the_repair_agrees_wherever_the_old_check_was_meaningful` — for any verdict that
  actually exists, the new decision reports a change exactly when the old one did.
  Nothing was traded for the strictness
* `an_unchanged_real_verdict_is_still_unchanged` — the weekly job still stays quiet
  when nothing moved
* `skipping_and_failing_never_both_apply` and
  `every_decision_has_a_defined_treatment` — the outcomes partition and the
  partition is total, so no implementer gets to pick the convenient reading
* `all_three_outcomes_are_reachable` — the anti-vacuity witness; a third
  constructor no input can produce would leave the rest green and pointless
* `the_run_that_prompted_this_was_actually_fine` — closing the loop: that run was
  correct, and now for a reason somebody checked

`verify.yml` fails the job when the generator produces nothing, and the new
emptiness test has its own negative control that fires in three directions: it must
detect an empty verdict, must **not** fire on a real one, and must confirm that two
empty files still compare equal — because the day `diff` stops saying that, the
control is guarding a defect that is no longer the one measured.

Mutants V01–V06: collapse `unmeasured` back into `unchanged`, invert the
comparison, flip the model of the shipped step, let an unmeasured verdict skip
quietly, drop the obligation to fail, or forbid a real unchanged verdict from
skipping — six ran, six killed.

### The freshest workflow in the repository had been broken for a week

Four hand-written workflows, and until now the split between them lived in a
comment. Two are **code gates** (`ci.yml`, `verify.yml`); two are **documentation
managers** (`ads-manager.yml`, `tag-manager.yml`) whose job is to keep the
repository alive between commits — the reason a visitor sees a project that moved
today rather than one that stopped in August.

Measured through the API on 2026-08-11:

| workflow | newest run | youngest green |
|---|---|---|
| `tag-manager.yml` | success, 20 h | 20 h |
| `verify.yml` | success, 21 h | 21 h |
| `ci.yml` | success, 42 h | 42 h |
| `ads-manager.yml` | **failure, 19 h** | **173 h** |

Read the "newest run" column alone and the docs manager is the *healthiest* thing
in the repository: nineteen hours, fresher than everything else. It had been red
for seven days. The obvious freshness test — *has this run lately* — gives exactly
the wrong answer, and gives it confidently.

`lean/Proofs/RotWorkflowRoles.lean` decides the gap.
`a_workflow_that_runs_is_not_a_workflow_that_works` shows the two tests
disagreeing on the real numbers, and `the_healthy_three_agree_under_the_same_bound`
shows the disagreement is a property of that workflow's state rather than an
artefact of the bound chosen. The repair is not a swap:
`green_freshness_is_strictly_stronger` proves, for **every** workflow and **every**
bound, that anything the green test accepts the naive test accepts too — so
measuring the youngest success can only ever reject more. The converse fails, and
`the_naive_test_does_not_imply_the_honest_one` carries the witness.

The role split is now a predicate rather than an intention.
`a_docs_manager_may_not_write_to_the_proofs` and
`a_docs_manager_may_not_write_to_the_router` refuse a scheduled job with
`contents: write` that reaches into `lean/` or `hooks/`, and
`the_allowlist_refuses_something` is the anti-vacuity witness — an allowlist that
accepted everything would leave every other theorem green and meaningless.
`neither_half_alone_is_enough` closes the last gap: a workflow cannot buy a pass
with the easier clause.

One premise is corrected here because it changes what may be claimed. Dependabot
cannot be the documentation engine. Its only ecosystem in this repository is
`github-actions` at `directory: "/"`, which edits workflow files — that is,
**exclusively code gates**, the opposite of docs-only. There is no key that scopes
it to named files; `ignore` filters by dependency name, never by path. Document
freshness is the cron managers' job and nobody else's, which is why one of them
being quietly red is a defect rather than an inconvenience.

A second correction, on the author, in the same session: the first measurement of
branch protection used `/branches/main/protection`, which answered
`Branch not protected`. That would have been a false accusation against a comment
in `ads-manager.yml` claiming four required checks. The legacy endpoint returns
that for a repository protected by a **ruleset**, and `/rules/branches/main`
reports the truth: `deletion`, `non_fast_forward`, and four required status
checks. The comment was right and the instrument was wrong.
`an_unregistered_gate_is_not_enforced` now pins the four measured contexts, with a
witness that a plausible-looking name nobody registered is *not* enforced.

`checker/workflow-roles.sh` binds all of it to the tree: roles declared and every
workflow on disk required to carry one, the forbidden-path rule with both controls
(a workflow writing `lean/Proofs` must be caught; one writing only `README.md`
must not), cron presence, and the API half that reports **both** ages side by side
so the difference is visible in the log rather than asserted in prose. Without a
credential it exits 3 — a skip, never a pass.

It is registered as a deep gate, and it was **RED** when it was written — for the
true reason, the documentation manager's last success really being older than the
bound. It was left red rather than adjusted; a checker tuned to accept the state
it was built to detect is worth nothing.

**Where the green came from, stated before the green is claimed.** The repaired
workflow was dispatched against a **side branch**, not against `main`. It ran
eleven steps with zero non-success — the previous run skipped two, including its
own negative control — and both controls fired inside CI: the drift control
refused a README off by one module, and the coverage control refused a README
missing a module whose absence left the sum at 1322 either way. That is real
evidence and it is why the audit repair is trusted here.

It is not evidence about `main`. The branch should never have been pushed: the
promise this repository publishes under was not fulfilled at the time, and the
branch has since been deleted. `main` has **not** run this workflow.
`checker/workflow-roles.sh` prints the ref of every green run precisely so this
distinction cannot be lost — it reports `0h old on ci/workflow-roles`, and it will
keep naming that ref until a run on `main` replaces it.

Mutants W01–W06: measure the newest run instead of the newest success, make the
scope check always true, widen the allowlist by one path, drop the freshness
conjunct, make every context report as enforced, or exempt the docs managers from
their own role — six ran, six killed.

### A red CI job was right about the symptom and wrong about the cause

The **Ads Manager** workflow has been failing on `cef996e` since 10 August:

    ::error::README per-module claims sum to 316; sources have 832

Read literally that says the README has a wrong number in it. It does not. Every
one of the seventeen per-module counts the README stated was recounted from its
own file and every one was exact — measured on this tree, seventeen rows, zero
drift. What the audit had actually found was that fifty modules were
*undocumented*, and its final clause could not say so, because a shortfall in an
integer does not carry the identity of what is missing.

The clause was an arithmetic proxy for a set-theoretic property: *the table covers
every module*. `lean/Proofs/RotReadmeTable.lean` measures how good a proxy it is,
and the answer is *good, but not sound*.

`the_sum_detects_an_omitted_module_that_has_theorems` shows the proxy earning its
keep — omit a module with theorems in it and the sums disagree.
`the_sum_is_blind_to_an_omitted_module_with_no_theorems` shows where it stops: a
module with **no** theorems can be dropped from the README and the sums still
agree exactly. That is not a hypothetical shape. `lean/Proofs/RotVacuity.lean`
holds zero theorems by design, and it is precisely the kind of file nobody
remembers to document. So coverage is now checked **by name**, and the failure
message names the modules that are missing.

The second defect is the one worth dwelling on, because it fails in the direction
that looks like success. Completing the README means adding an appendix listing
all sixty-eight modules — at which point the seventeen narrated ones are mentioned
twice, in two places, with the same correct number both times.
`mentioning_a_module_twice_breaks_the_sum_but_not_the_truth` decides what the old
clause did with that: every row exact, every module covered, and the audit red.
A check that fails when two values coincide has assumed they must always differ.
The sum is now taken over **distinct** modules, which is what "the per-module
claims sum to the total" meant in the first place —
`the_distinct_sum_accepts_it_and_still_rejects_an_omission` confirms the repair
does not cost the detection, and `two_mentions_that_disagree_are_still_caught`
confirms two contradictory mentions are still refused by the recount.

Neither change relaxes anything. The recount half was already sound and
`a_documented_count_is_bound_to_disk` states it generally: under `exact`, every
published number is bound to a file on disk, for any catalogue and any table.
`naming_the_gaps_agrees_with_the_coverage_test` binds the diagnostic to the gate,
so the list of missing modules and the pass/fail decision can never drift apart.

The README gained the appendix: every module in `lean/Proofs/`, recounted from
source, sixty-eight entries. The audit now passes because the property holds, not
because the arithmetic happened to agree.

The new coverage clause also got its own negative control in the workflow, and the
module it deletes is chosen deliberately: `RotVacuity.lean`, whose absence leaves
the distinct sum **exactly** unchanged. If coverage were still inferred from
arithmetic that control would pass while testing nothing — the control asserts the
sum stayed put, so it fails loudly if it ever stops isolating coverage. An alarm
nobody has tripped on purpose is an untested alarm; this one has been tripped
three times, twice locally and once in its own CI step.

Mutants R01–R06 defend the module: turn `covers` into an `any`, turn `exact` into
an `any`, stop comparing the count, drop the negation in the diagnostic, remove
the deduplication, or make `documented` always say yes — six ran, six killed.

### The experiment plan was audited before it was built, and four of its numbers were wrong

A plan for six more Lean modules and a capstone was written out in full — module
map, per-gap proof sketches, the ritual for each, the sequence. The cheap move
was to start building it. Instead every arithmetic claim in it was run through
`decide` first, and §10 of `lean/Proofs/RotExperiment.lean` now records what came
back. Four claims did not survive.

**The proposed symmetry repair would have admitted a total loss.** The plan
observed, correctly, that `twoSidedTail` is not invariant under swapping the
labels — `twoSidedTail 40 9 = 747171208` against `twoSidedTail 40 31 =
2198822962104` — and proposed to fix it by folding the count through `min k (n-k)`.
`the_min_repair_would_admit_a_total_loss` shows what that buys: under the repaired
statistic, **40 losses out of 40 pairs reports `supported`**, and so does 31 of 40.
The statistic and the verdict were being asked different questions. A two-sided
tail answers *are the arms different*; `verdictM.supported` claims *the routed arm
is better*. Symmetrising the first without changing what the second says converts a
conservative test into one that cannot distinguish a triumph from a rout. The
definition was right and the proposed symmetry was the overclaim, so the repair is
recorded as a refuted proposal rather than applied.

**Twelve comparisons do not move the forty-pair boundary.** The plan claimed the
tolerated loss count "drops below 9" once the family-wise correction counts twelve
comparisons instead of nine. `twelve_comparisons_do_not_move_the_forty_pair_boundary`
pins the measured table: the last supported `k` is **9 for `m = 9` and 9 for
`m = 12`**. The stricter correction is still worth adopting — it costs nothing at
this sample size — but it must be adopted for honesty about the number of
comparisons, not because it changes the answer.

**The ten-task pilot was guaranteed null before a single task existed.**
`a_ten_pair_pilot_cannot_reach_a_corrected_verdict` searches every possible
outcome: under `m = 9` or `m = 12`, **no** loss count at ten pairs reaches
`supported` — a clean ten-for-ten sweep included.
`only_the_uncorrected_rule_passes_at_ten` shows the design is not merely strict but
arithmetically sealed: only the *uncorrected* rule, at exactly zero losses, ever
passes there. A pilot like that cannot produce evidence; it can only produce the
appearance of having tried. `the_smallest_corrected_pilot_is_twelve_pairs` gives
the replacement: **twelve pairs**, tolerating zero losses, is the smallest design
that can return a corrected verdict at all, and sixteen pairs buys tolerance for
one loss.

That last number was itself the session's sharpest lesson. Thirteen was written
first, then fourteen — both by reasoning about the shape of the tail rather than
computing it, and `decide` refused both in turn. The theorem's docstring keeps
that record. A bound that is *argued* is a guess wearing a proof's clothing; the
twelve is a filter over every count up to seventeen.

Three smaller incongruences are logged without ceremony: `runVerdict` in the plan
collides with the existing `runVerdict : Run → Verdict` at
`lean/Proofs/RotExperiment.lean:189`; a proposed `round_trip … := by decide`
cannot elaborate because `Evidence` carries `Nat` fields and the domain is
infinite, so it needs `cases e <;> rfl`; and two proposed theorems are decorative
as written — one whose conclusion ignores its hypothesis, one true of every
function of its type and therefore infrastructure, not evidence.

Mutants X18–X20 make the audit load-bearing: strip the `min` from the refuted
repair, drop the family-wise factor from `verdictM`, or shift the cumulative tail
by one, and these theorems die rather than quietly re-describe a different
statistic. Across the whole tree the suites now stand at 786 applied, 786 killed,
0 survived, 0 discarded.

### Prose quality stops being the permanent excuse: the protocol is proved, the taste is not

Every report this project has written ended with the same admission — *artifact
quality is measured, answer quality is not*. That sentence was doing two jobs,
and only one of them was honest.

* Honest: **no Lean file will ever contain a theorem whose conclusion is "the
  prose is better".** Any file claiming that has an `axiom` in it.
* Not honest: leaving it there implied nothing about prose could be measured.
  What cannot be measured is *quality*. **Preference under a stated protocol** is
  a different object, and it is measurable to the same standard as everything
  else here.

`lean/Proofs/RotProse.lean` — 39 theorems, zero axiom declarations, nine mutants
declared and nine killed.

**First the impossibility, because it licenses everything after it.** A machine
prose scorer is not merely hard, it is refused by a theorem:
`no_length_monotone_metric_is_faithful` shows that any metric padding cannot
lower is a metric that rewards padding — and `the_obvious_metric_is_gameable`
exhibits the byte count doing exactly that, strictly raised while
`informative` is unchanged. That is the same argument shape that killed
`verified`-as-a-raw-count in the artifact scorer. The panel is human **by proof**,
not by resignation, and that is why no `def quality : Prose → Nat` exists in this
repository.

**Then the human judgment becomes data**, with every confound around it decidable:

| element | Lean form | what it closes |
|---|---|---|
| forced choice | `inductive Choice \| left \| right \| tie` | scale drift between raters |
| blinding | `Rater := Pair → Choice`, and `Pair` HAS NO ARM FIELD | conditioning on the arm — P01 widens it to `Judged → Choice` and the module dies |
| position bias | `swap` involution, `normalise` | a constant left-picker scores exactly the positions, proved for every schedule |
| panel | odd, `majority`, ties reported | one rater swinging a 4–1 |
| reliability | `meetsFloor`, cross-multiplied | an unreliable panel supporting a verdict |
| length confound | `confounded`, all picks track bytes | the one bias Lean can actually catch |
| inference | `verdictM` reused from `RotExperiment` | family-wise error across nine comparisons |

**The conclusion is worded to say only what it may.** `prose_attributable` takes
one computed hypothesis and concludes: blinded raters, forced choice, both
orderings, positions flipped, agreement above floor, not length-confounded,
preferred the routed arm at a corrected p<0.01. **It does not say the prose is
better.** `renderHash` proves the text scored is the text produced — integrity,
never origin, and never taste.

Eleven refusals prove the gate can fail, one per clause, including a
length-confounded run refused at any margin and the corrected boundary at nine of
forty rather than the uncorrected eleven.

**A claim in this file's own first draft was false, and the file now says so.**
Section 6 asserted that a floor checked by integer division would round a split
panel into a pass, by analogy with the `costSec / 60` defect. An exhaustive check
over every panel size 1–12, every agreement count and every floor 0–100 — 15 700
cases — found **zero** disagreements, and `Nat.le_div_iff_mul_le` proves why: for
an integer floor the two forms are the same test. The theorem
`the_floor_test_is_equivalent_to_the_divided_form` now records that, and
`division_ties_two_panels_that_cross_multiplication_separates` states where
truncation *does* destroy information — comparing two panels, where 2/3 and
67/101 both read as 66. The analogy was the overclaim; the arithmetic corrected
it.

### The axiom that became a measurement: one hypothesis the checker computes

An `axiom` for the empirical claim would have laundered it — the kernel would
trust a hole exactly where the world belongs. A hypothesis supplied by hand is
honest, but the caller can lie. `RotExperiment.lean` §9 uses the third form:

| shape | meaning | verdict |
|---|---|---|
| `axiom margins_are_good : …` | a hole the kernel trusts | **forbidden** — launders the claim |
| `theorem … (h : margins = m)` | premise supplied by the world | honest; the caller can lie |
| `theorem … (h : checkAll ev = true)` | premise **computed by the checker**, closed by `decide` | this is convergence |

`structure Evidence` folds every confound into ONE record — corpus hash,
preregistered hash, the nine-lens vector, the seven artifact observables, pairs,
pairs-against, comparisons, and the four design bits. `checkAll` is one function
over that record, and `attributable` takes exactly one hypothesis:

    theorem attributable (e : Evidence) (h : checkAll e = true) :
      e.corpusHash = e.expectedHash ∧ … ∧
      verdictM e.comparisons e.n e.against = Verdict.supported ∧
      e.art.falseGreen = 0 ∧ e.art.pipedReads = 0

Nothing is assumed. A Boolean is computed from data the checker wrote, and the
kernel checks the implication. Nine witnesses prove the gate can REFUSE — one per
clause, each differing from a passing record in a single field — so `checkAll` is
not a rubber stamp. Two of them matter most: a single `falseGreen` sinks a record
whatever its margin, and a perfect protocol with ten-of-forty against is refused,
because the corrected boundary is **nine**, not ten.

**What no theorem here establishes, stated in the file and repeated here:** that
the transcripts came from real sessions rather than an editor. `corpusHash`
reduces provenance to one comparison, but a hash proves INTEGRITY, never ORIGIN.
That is a trust root. Calling it an axiom or a proof would both be wrong.

### The scalar was reductive; now it is licensed, with a domain

Section 6 proved the nine-lens scalar loses the profile. That was an objection,
not a repair — it left the scalar defined everywhere and trusted nowhere. Three
theorems now say where it may be believed:

* **Faithfulness** — `dominates u v = true → total v < total u`. The scalar can
  never contradict the vector. This is also what makes the equal weighting
  load-bearing: zero one lens in `total` and a profile can dominate by winning on
  the ignored lens alone.
* **Honest incomparability** — `compareV` is three-valued, and the two profiles
  that tie on the scalar return `incomparable`, not equal. A projection tie is no
  longer laundered into a finding. X13 reports non-dominating pairs as wins and
  kills the module.
* **Density without division** — `costSec / 60` was a defect, not a rounding
  convenience: every latency difference under a minute was invisible.
  Cross-multiplication removes the division, and
  `integer_division_manufactures_a_tie` exhibits the pair it hid — 5 s against
  50 s, identical under the old bucket, separated now. The dense comparison also
  refuses three times the work at ten times the cost, for every admissible
  weighting.

### A transient network failure was being reported as a stale CI run

`ci-audit-freshness.sh` went RED inside a parallel pre-commit sweep with
`SyntaxError: Unexpected end of JSON input` — curl had returned an empty body. Run
standalone, with stdin closed, and with the hook's `GIT_DIR` set, it passed every
time. The cause was the network blinking, not a stale run.

"The API did not answer" and "the audited run predates your fix" are OPPOSITE
findings, and the first was being reported as the second — the same class of
error as scoring a mutant that never applied as SURVIVED. The fetch is now
bounded and retried three times, and an unanswered API is a SKIP (exit 3), which
`RotCiSkip.lean` already proves adds no coverage and is never a pass. The
staleness FAIL path is untouched; this is not a weakening, because a staleness
failure still requires actually reading a run. Negative control: pointed at an
invalid host it exits 3 in 8 s.

### Five corpora died of experiment defects, so the experiment is now the thing that is proved

P2.2 has returned NULL five times, and **not one of those nulls was a measured
absence of effect** — each died of a defect in the experiment. `RotExperiment.lean`
removes that entire class. It proves nothing about answer quality and does not
try to.

The distinction it is built around:

| statement | status |
|---|---|
| the experiment cannot lie | **provable** — this module |
| the inference from the data is valid | **provable** — `supported_implies_tail_below_one_percent` |
| the data came out this way | **not provable** — a hypothesis, supplied by measurement |
| the router is better | **not provable** — the world's answer, never Lean's |

**1. Blinding as a type, not a promise.** The scorer is `Trace → Nat`, never
`Session → Nat`. A `Trace` carries no arm label, so `score_is_blind` is proved by
`rfl` — arm-invariance is *structural*. Mutation X01 widens the scorer to consult
`s.arm`; the module stops compiling. A compile-time guarantee, with no discipline
to forget and no runtime check to bypass.

**2. The decision rule is `Nat` arithmetic.** The two-sided sign test computed
exactly: "p < 0.01" becomes `100 * twoSidedTail n k ≤ 2^n`, kernel-checked in
both directions, so the verdict is *exactly* the bound and no discretion is left
in the analysis step. Pascal's triangle is built row by row — the naive two-term
recursion is correct and unusable, expanding `binom 40 8` into tens of millions
of additions.

**3. The preregistered boundary, computed rather than asserted.** 40 tasks × 2
arms × 2 orderings = 160 sessions = **40 pairs**, and **at most 11 may go against
the routed arm** (`verdict 40 12 = notSupported`). The 10-pair pilot demands a
clean sweep. Registering the threshold as a theorem is what makes it
preregistered in a way a reader can check, rather than a sentence that could be
edited after the data arrives.

**4. Non-vacuity in both directions.** `verdict_can_be_negative` (a coin is
refused) and `verdict_can_be_positive` (a clean sweep passes) — without the
first, a rule that always answers SUPPORTED would satisfy theorem 2 trivially.
`an_honest_run_can_still_return_null` says honesty does not manufacture a verdict,
and `a_perfect_margin_does_not_rescue_a_defective_run` says a decisive margin
does not rescue a run that skipped an ordering.

**5. The composite.** `supported_is_attributable_to_the_arm`: given both
orderings, a saturated corpus, a preregistered rule and a SUPPORTED verdict, the
result cannot be explained by order, corpus, or analysis — and blinding needs no
hypothesis at all, because it is true by typing.

The margins enter as **hypotheses, never `axiom`s**. The module declares **zero
axioms** (`grep -cE '^axiom '` = 0); `#print axioms` reports `propext` on two
theorems and nothing at all on the other nine. Writing the margins as axioms
would launder an empirical claim into an apparent proof — the exact overclaim
pattern this project refuses.

One premise stays outside Lean: *the transcripts are real*. Lean cannot tell a
`Trace` that came from a session from one typed into an editor. That is the
checker's job — regenerate from the actual sessions and diff.

Mutation: five mutants, all five killed. X01 was **discarded on its first run**,
not survived: the replacement text contained the needle as a substring, so the
post-check saw the needle still present and refused to score it. The harness
distinguishing "did not apply" from "survived" is the only reason that 5-of-5
means anything. (The count is phrased as prose deliberately — `repo-complete.sh`
scans this section for the `N applied, N killed` shape and checks it against the
whole tree, so a per-suite figure written that way reads as a false claim about
all 60 suites. It went red on exactly that and was right to.)

### The repair for one failure was manufacturing another: 5.3% of the live log was unreadable

The deep gate tier — 57 gates, run whole for the first time against this tree —
came back **56 green, 1 red**, and the red was real:

```
FAIL  rot-route-debug.jsonl: 40 corrupt lines in the last 200 -- the writer is STILL fusing records
```

Standalone the same checker passes 55/55. It only fails when many hooks fire at
once, which is why it had never been caught.

Measured on the live sink:

```
total=5000  valid=4735  corrupt=265        (5.3%)
corrupt by kind: gauge 222, route 27
shape: torn(no closing brace)=0   fused(}{ inside)=1
```

**`torn = 0` is the load-bearing number.** Nothing was truncated. Had a writer
been killed mid-record the log would be full of lines with no closing brace;
there are none. So this is *not* the killed-writer failure the existing repair
addresses — it is interleaving. One line begins inside another record's array
(`{"kens":"Venom"…`); a 1309-byte gauge record is mangled at byte 712.

**The cause is the repair.** Both arms write a record as three steps: read the
last byte, append `\n` if the file did not end in one, append the record. That
composite is the correct fix for a killed writer (`RotLogAtomicity.appendSafe`).
Under concurrency writer B reads the last byte while writer A is *still emitting*,
sees a byte that is not a newline **because A is mid-record**, and injects `\n`
inside A's record — splitting one valid line into two invalid ones. Each step is
atomic; the sequence never was.

`gauge` dominates 222 of 265 because it is the longest record (~1300 B, the
nine-lens array) and so holds the window open widest.

**The fix is mutual exclusion across both arms**, with the *same* token so the
arms exclude each other and not merely themselves: a lock directory, `mkdir` in
the sh arm and `New-Item -ItemType Directory` in the ps1 arm. The lock spans the
repair *and* the append, because splitting them is the defect. On contention the
writer **refuses and marks the loss** rather than writing unlocked.

`lean/Proofs/RotLogLock.lean` proves why that is the right trade:

| theorem | what it settles |
|---|---|
| `unlocked_admits_a_split` | the defect is real, with a witness — a model where nothing can corrupt would prove nothing about the 265 lines |
| `exclusion_forbids_a_split` | **durable** — exclusion removes the window entirely, for every pair of writers |
| `terminating_is_not_exclusion` | the existing repair *cannot* close this; it is not weakened, it addresses a different failure |
| `admitting_two_holders_restores_the_defect` | a lock that admits two holders is not a lock |
| `refusing_beats_writing_unlocked` | a refusal costs 1 record; an unlocked write destroys 2, because a split turns one valid line into two invalid ones |
| `a_refusal_is_visible` | the loss must be recorded — a silent drop is indistinguishable from a router that never fired |

`exclusion_forbids_a_split` carries a `wellFormed b` premise that was **not** in
the first draft: `omega` refuted that draft with an exact counterexample — a
writer whose newline-repair lands outside its own attempt defeats exclusion.
The premise is what the lock discipline enforces (acquire, repair, append,
release), and it is stated in the theorem rather than assumed in prose.

Four defects were found *while* fixing this, each by an instrument rather than by
reading:

1. **Locking the route site alone was not enough.** The contention control showed
   the file still growing by one line: the `gauge` record has a **second, separate
   writer** (the awk at `hooks/rot-router.sh:442`), and it is the 222-of-265
   offender. Locking only the site I happened to read would have left the main
   cause open and looked green.
2. **`[System.IO.Directory]::CreateDirectory` is idempotent** — it succeeds on an
   existing directory, so it would have handed the lock to every caller at once.
   Probed both ways in five lines: `New-Item` throws on collision (a lock),
   `CreateDirectory` succeeds twice (not a lock).
3. **`New-Item -ItemType Directory` creates intermediate directories**, unlike
   `mkdir` with no `-p`. The lock silently materialised the parent of an
   unwritable log path, the append then succeeded, and the lost-record marker
   stopped firing because nothing was lost any more. `debug-channel.sh` phase 2
   caught it.
4. **`Split-Path -LiteralPath … -Parent` cannot be called at all** — those are
   different parameter sets and PowerShell throws. The throw escaped the function
   and killed the whole write, turning the channel dead. Replaced with
   `[IO.Path]::GetDirectoryName`, a pure string operation.

A fifth was self-inflicted and worth recording: a comment quoting the marker
string verbatim broke `debug-channel.sh`'s control, which plants a copy with the
marker deleted and asserts it is gone. The control was right; the comment was
reworded. A checker that cannot distinguish "the marker is absent" from "some
other copy of the string exists" would be the weaker instrument.

Gates after the fix: `debug-channel` **18/18**, `log-integrity` **58/58**,
`cross-diff` **86/86**, all exit 0.

### The first full 57-suite mutation sweep, and the three defects only a full run could find

`README.md` published **624** as both the applied and the killed figure, while
the suites declared **634**. (The old pair is stated here as prose rather than in
the `N applied, N killed` shape on purpose: `repo-complete.sh` scans the section
being written *today* for that shape and checks it against source, which is
correct behaviour — a historical figure must not be phrased so that a checker
reads it as a claim about the current tree.) The
gap was not a typo — the number had been carried forward while two new suites
were added, and nothing recomputed it. So the claim was re-earned the only way it
can be: every suite, every mutant, in one sequential sweep.

Running all 57 exposed three defects that no per-suite run had ever surfaced,
because each hides precisely when a suite is run alone and its output read by a
human rather than parsed.

| suite | defect | consequence |
|---|---|---|
| `mutate_rotinject.sh` | `_total` used twice, **assigned nowhere** | printed a clean verdict, then died `unbound variable`, **exit 1** |
| `mutate_rotsessionlog.sh` | identical | same: text said 20 killed, exit code said failure |
| `mutate_rotlog.sh` | the summary `echo` sat **above** four of its own mutants | printed `killed=10` while **14** ran and were killed |

The first two are the more dangerous shape. The suite printed
`=== RotInject: 9 killed, 0 survived, 0 discarded ===` and then exited **1**. A
reader sees a clean sweep; a script sees a failure; neither can tell which is
true without opening the file. Under `set -u` the summary line itself was the
thing that killed the process, *after* every mutant had already been correctly
scored.

`mutate_rotlog.sh` is the inverse and it is worth being precise about what was
and was not wrong: its **exit code was never wrong**. The survivor and discard
guards sit at the foot of the file and read the live counters, so a survivor in
`L11`–`L14` would still have failed the suite. What was wrong is the *printed*
summary — emitted at line 262 with four mutants still to run. Any consumer
parsing that line under-counted by four, which is exactly how the published 624
could look self-consistent. A verdict printed before the work finishes is not a
verdict.

A fourth finding is an inconsistency rather than a bug: `mutate_rotgauge.sh`
resolves its module as `${LEAN_ROOT:-.}/Proofs/RotGauge.lean` while its 56
siblings resolve their own path, so from the repository root it refused with
`FATAL: ./Proofs/RotGauge.lean not found`. It refused rather than scoring 12
phantom kills — the guard behaved correctly — but a sweep that does not know
about the variable silently loses a suite. Run with `LEAN_ROOT=lean` it reports
12/12.

**Measured, whole tree, after the repairs:**

```
57 suites   634 declared   634 ran   634 killed   0 survived   0 discarded
```

`declared` is counted with the checker's own rule,
`^run_mut(_nth)? [A-Z][A-Za-z0-9]*[0-9] `, not with `^run_mut ` — the latter
misses `run_mut_nth` in six suites and undercounts by eight. That is the same
"counting the wrong token" defect `repo-complete.sh` exists to catch, and it
caught it here on the author.

`README.md:240` was corrected the same day to the measured tally — the 634
swept, plus 5 each for `RotSweep` and `RotLogLock`, 12 for `RotExperiment`, 9
for `RotProse`, 3 more for the plan audit and 7 for `RotLensActivation`, each
run and killed here — and `CITATION.cff` moved from 1083 to the measured 1310
theorems.

*(The mutant total is deliberately not repeated in this sentence. It was, and
the figure went stale the next time a suite was added — a count quoted twice is
a count that will disagree with itself. The live tally is `README.md:240`, which
`repo-complete.sh` cross-checks against the suites on every run.)*

### The repairs went through Lean 4, because a fixed harness is still an unproven harness

Three suites were repaired above. `lean/Proofs/RotSweep.lean` is why those repairs
are correct rather than merely green.

It models a run as `⟨declared, ran, killed, survived, discarded⟩` and separates
the two observations that silently disagreed: `reportedAt k`, the summary a suite
prints after `k` mutants, and `verdict`, the exit classification computed from the
final counters.

| theorem | what it settles |
|---|---|
| `early_summary_under_reports` | a summary printed after `k < killed` mutants reports `k`, not the truth |
| `early_echo_is_indistinguishable_from_truncation` | the complete run with an early echo and a genuinely truncated run print the **same number** — the text cannot tell them apart |
| `the_two_runs_differ` | …while the runs are not the same run, so the information was destroyed at the instrument |
| `exit_path_was_correct_all_along` | rotlog's exit code classified the complete run clean, which is the half that was never wrong |
| `truncation_is_refused` | a run that stopped short is not a pass |
| `a_reported_exit_may_contradict_the_verdict` | the `_total` shape: a clean run whose reported exit says failure |
| `a_verdict_requires_every_declared_mutant` | **durable** — a clean verdict forces `ran = declared`, over every run, naming no constant |
| `a_clean_verdict_has_no_survivor_and_no_discard` | **durable** — the two are reported apart because they mean different things, and neither is a pass |
| `a_summary_never_over_reports` | **durable** — the printed count can under-report but can never invent kills |

The last one explains the whole episode: because an early summary under-reports
rather than over-reports, the stale published figure stayed *self-consistent*.
Nothing in the tree contradicted it, so nothing caught it.

13 theorems, 11 `#guard`s, **5/5 mutants killed**, axioms `propext`/`Quot.sound`
or none, `leanchecker` 0 bytes, and green in the shared Lean workspace as well as
in `lean/`.

Counts move together: **1185 theorems, 64 modules, 58 suites, 639 mutants, 68
checkers**, each re-measured with the repaired counter rather than incremented by
hand.

### The theorem counter could not fail, so the ratchet it feeds was decorative

`checker/count-theorems.sh` had **three** paths to `0` with exit `0`, and each was
indistinguishable from an honest count of zero:

| invocation | mechanism | result |
|---|---|---|
| no arguments | `for f in "$@"` never iterates | `0`, exit 0 |
| a missing file | awk fatal → `$(...)` empty → `total=$((total + ))` is a syntax error, and there is no `set -e` | `0`, exit 0 |
| an unexpanded glob | same path as a missing file | `0`, exit 0 |

`checker/axiom-audit.sh:291` then swallowed even the stderr with `2>/dev/null` and
`n=${n:-0}`.

This is worse than a wrong number. The count is a **ratchet** — the manifests
publish it and CI asserts it never drops — so an instrument that reports `0` for
*"I was handed nothing"* lets the ratchet be satisfied **by handing it nothing**.
The count falls to zero and every gate stays green, because zero is not less than
zero. The failure mode is silent and it flatters.

**Repaired:** the counter now refuses — exit `2` — on an empty argument list, a
missing file, an unreadable file, a non-numeric awk result, and `--per` with no
files. An honest zero (a real file containing no declarations) still reports `0`
with exit `0`; that distinction is the entire point and it is covered by a control.
`--selftest` grew four negative controls, one per refusal, so the alarms have each
been tripped on purpose.

**Proved in Lean 4** — `lean/Proofs/RotCounter.lean`, 9 theorems, `#print axioms`
clean, kernel re-verified, **5 of 5 mutants killed**:

- `zero_is_ambiguous_under_naive` names the defect exactly: two invocations with
  different meanings — *no input at all* and *one real file with no declarations* —
  produce an **identical** observation under the old instrument, so no consumer
  downstream can recover the difference. The information was destroyed at the
  instrument.
- `honest_separates_them` is the repair, stated as a separation rather than as a
  property of any particular corpus.
- `a_report_requires_every_file_read` is the durable form: a number is emitted only
  when the files read equal the files handed in. It names no constant, so it does
  not expire when the corpus grows.
- `naive_admits_a_drop_that_lost_no_theorem` exhibits the ratchet attack the old
  instrument permitted; `honest_refuses_the_fake_drop` closes it.

### Published counts were stale in four places

The manifests and README advertised **1083** theorems against a measured **1172**,
and `58 modules / 55 suites / 67 checkers` against `63 / 57 / 68`. Corrected in
`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md:65` and
`README.md:557`, all four re-measured with the repaired counter rather than copied
from each other. Zero `sorry` and zero `native_decide` re-confirmed — the four
`sorry` hits in `lean/Proofs/` are prose in doc comments and one string literal in a
keyword list, not tactics.

### A checker that skipped every single step exited 0 and printed PASS

`checker/ci-dryrun.sh --from 9999` windowed out **all 75** extracted CI steps,
printed a completely honest paragraph about it —

```
  PARTIAL  75 step(s) were WINDOWED OUT (--from 9999).
           This run is NOT a full pass. Windowed is not passed, not
           deferred, and not skipped -- it is untested.
```

— and then exited **0** with `ci-dryrun: PASS`.

The prose was right and the verdict was wrong, which is the worse half to get
wrong. `checker/gate-all.sh` reads the **exit code**, not the paragraph. Zero
steps executed, recorded as green, reachable with one flag. That is the "no
skip, no fake green" rule broken inside the very checker whose job is to prove
CI steps run.

The fix is four lines: if `windowed > 0`, print `ci-dryrun: PARTIAL` and exit
**3** — this repo's "did not run", which no caller counts as a pass. Measured
before: exit 0. After: exit 3.

**Why the windowing exists at all, and why deleting it would have been the wrong
repair.** The full sweep does not fit in any caller's wall-clock bound, because
it re-runs `checker/mutate-checker.sh` internally (418 s on its own). Cutting a
run short with a signal is what emptied two shipped hooks earlier the same day.
Windowing is the *safe* alternative to a kill; the bug was never the feature, it
was a verdict function that consulted only the failure count.

#### The same hole, closed in the mutation harness before it could open

`checker/mutate-checker.sh` had no way to run a subset, so every caller who
could not spare seven minutes killed it — three recorded times, the last leaving
`hooks/prover-remind.sh` and `.ps1` at zero bytes. It now takes `MUT_ONLY="H00
H01"`. Skipped mutants are counted in `notrun`, the summary says `PARTIAL`, and
the exit code is **3**, never 0. Only an unset `MUT_ONLY` can produce a passing
sweep, which is what the gate table invokes.

The control that matters is a **typo**: `MUT_ONLY=NOSUCHID` selects nothing.
Measured — `killed=0 survived=0 discarded=0 notrun=16`, exit 3. An empty
selection cannot report a clean sweep of zero mutants.

#### Both fixes are one theorem

`lean/Proofs/RotPartialRun.lean` models a run as `⟨total, ran, failed⟩`.
`naiveVerdict` is the shipped bug, `honestVerdict` is the fix.

| theorem | what it settles |
|---|---|
| `naive_passes_a_run_that_did_nothing` | the bug, exactly as it shipped: `⟨75,0,0⟩` passes |
| `honest_refuses_a_run_that_did_nothing` | the fix refuses it |
| `naive_is_blind_to_windowing` | **why no care with the failure count could have caught it** — a full sweep and a run of nothing are the same value to it, though the runs differ |
| `honest_separates_them` | the added condition is a real second test, not a restatement |
| `honest_agrees_when_everything_ran` | **no false alarm**: on a complete run the fix changes nothing, so it cannot redden a good sweep |
| `honest_never_passes_with_notrun` | anything held back forces a refusal whatever the failure count says |
| `pass_implies_everything_ran` | the converse — a pass means the whole list executed |
| `failures_still_refused` | the fix does not mask real failures |
| `complementary_windows_compose_to_a_pass` | **segmenting stays legitimate**: the guard forbids lying about a partial run, not splitting one |
| `a_gap_between_windows_is_refused` | a one-step gap between windows is still not a pass |

Fifteen theorems, twelve `#guard`s, and a mutation suite of **10 mutants: 10 killed,
0 survived, 0 discarded**. P01 restores the shipped bug verbatim and dies.

#### What the two long checkers actually say, now that they have finished

`checker/mutate-checker.sh` had **never once run to completion** in this
repository. Its first complete run: 418 s, `killed=16 survived=0 discarded=0
notrun=0`, baseline restored, both cross-diff arms exit 0. It was not failing —
nobody had ever let it finish.

`ci-dryrun` was covered by two complementary windows: `--to 40` (480 s) and
`--from 41`, both with zero failures. The second window does not fit in one
bound because it reaches `checker/live-session-smoke.sh`, whose phase 3 retries
a 180 s session probe once at 360 s. That checker's phases 1–2 did complete, and
they are the router-observable result the project is after: **`armed=3` router
references versus `disarmed=0`, with the difference attributable to the
install.** Phase 3 remains unmeasured and is reported as such.

#### The second unconsulted counter, and why zero was the wrong demand

Assuming one instance was not unique, every checker was swept for counters the
verdict never reads. Across all 67 there are five, and exactly one more was
unconsulted: `ci-dryrun.sh` never let **`deferred`** affect its exit either.

Two steps defer on this host. `pwsh` **is** present, so neither is a shell
defer — the reasons are `needs root on a disposable machine` and `uses
runner-provided variables`.

**So this one must not be fixed the way `windowed` was.** Those steps genuinely
cannot run in a local clone. A guard demanding `deferred = 0` would fire on a
correct environment, and the obvious repair would be to delete it, taking the
real coverage with it. A spec that forbids a correct present is a defect, not a
safeguard.

The instrument is a **ratchet on the declared set** instead: a deferral nobody
declared is a failure; a declared deferral that stops happening is reported and
never failed, because running *more* steps must never turn this red. A deferral
is keyed on `(name, reason)`, not name alone — a stale entry would otherwise
shelter a step that begins deferring for a different reason.

Both directions were measured by executing the shipped block verbatim against
synthetic input:

| control | result |
|---|---|
| the two real deferrals | `PASS every deferral is declared by name and reason (2 deferred)` |
| a third, undeclared | `FAIL 1 step(s) DEFERRED without being declared` |
| declared name, **changed reason** | `FAIL … install comma-decimal locales :: needs a real pty` |

The first attempt at this guard was itself broken and said so: `grep -c` prints
`0` **and** exits 1, so `grep -c … \|\| echo 0` produced *two* lines and the
comparison failed with a bare `FAIL  0`. It is now `wc -l`, which cannot do
that. Five further theorems cover the ratchet —
`undeclared_deferral_is_refused`, `reason_drift_is_not_covered`,
`fewer_deferrals_never_reddens`, `no_deferrals_is_ok`,
`empty_declaration_refuses_any_deferral` — the third being the one that proves
the guard cannot punish an improvement.

### A file emptied on disk is invisible to every check that reads its text

**The verification process that found this was my own, and it had the same
defect it keeps finding in the repo.** I had been committing with `--no-verify`
and verifying by running a *hand-maintained list* of checkers. That list is a
stale snapshot by construction. Running the real aggregator instead —
`bash checker/gate-all.sh --fast` — immediately reported **1 of 36 gates RED**
(`SPDX sweep`, a header missing from `checker/ci-log-skips.sh`, introduced two
commits earlier and never noticed). `verdict freshness` is likewise a *fast*
gate that had been passed over by hand: `STATUS.md` was stale by four modules,
four mutation suites and two checkers.

Running the **deep** tier one gate at a time then produced the real finding.

**What happened.** `checker/mutate-checker.sh` was bounded with `timeout 240`
and killed. It left `hooks/prover-remind.sh` (32209 bytes in git) and
`hooks/prover-remind.ps1` (28315 bytes) both at **zero bytes on disk**. This is
the third recorded occurrence — 2026-08-05 (orphaned rather than signalled),
2026-08-07 (SIGKILL inside a plain `cp`), and now.

**Why the existing fix did not hold.** The 2026-08-07 repair made the swap
atomic, and atomicity is necessary but not sufficient. Both `restore()` and the
`EXIT INT TERM` trap do `cat "$f.mutbak" > "$f.rtmp" && mv -f "$f.rtmp" "$f"`
guarded by `[ -f "$f.mutbak" ]` — **existence, not content**. An empty or
half-written backup is therefore restored *atomically over the original*, with a
successful exit code. Measured on the shipped pre-fix code, extracted verbatim
by line range and run against a fixture:

```
RECOVERED: .../a differed from a leftover .../a.mutbak -- a previous run was
           interrupted mid-mutation. Restoring the backup as the baseline.
OLD_PROBE_EXIT=0
a is now 0 bytes (was 16)
```

It announces success while destroying data. The same block after the fix:

```
REFUSING: .../a.mutbak is EMPTY -- it cannot be a valid baseline for a file
          git holds content for. Discarding the backup and leaving .../a as is.
PROBE_EXIT=0
a is now 16 bytes (healthy = 16); stale backup removed: YES
```

The guard is `[ -s ]` instead of `[ -f ]`, applied at all three sites: the
leftover-recovery loop, `restore()`, and the trap. The recovery loop mattered
most — there the file being overwritten may be **perfectly healthy**, so a stale
empty backup would turn a previous run's accident into a fresh corruption.

**Why nothing caught the resulting state.** The harness's own header had already
written it down: *"every fast gate reads source TEXT, and an empty file has no
offending text in it."* Exactly one gate reacted, and it **mis-diagnosed**:
`checker/portability.sh` reported *"the alarm warning is MISSING under CRLF —
the exact CI defect is back"*. Nothing was wrong with CRLF. The hook it invokes
was a zero-byte file, so it printed nothing and every content assertion
downstream failed. A wrong diagnosis is worse than a silent gate: it sends the
next person to re-fix a bug that is not there.

**New instrument.** `checker/tree-integrity.sh`, **fast** tier so it runs on
every commit, gate #56. It asserts that no tracked file is empty on disk while
git holds content for it, and that no `.mutbak`/`.rtmp`/`.mtmp` leftover
survives. It compares against `git ls-files` rather than a list of important
paths, because a list stops covering whatever is added after it is written. A
tracked file that is *also* empty in git is explicitly allowed — a check that
cannot tell those apart would be deleted within a week.

Tier choice is load-bearing and is recorded in `lean/Proofs/RotGates.lean`: a
deep tier would **not** have caught this, because deep gates run only when their
triggers are touched and an interrupted harness touches nothing a trigger names.

Both controls fire, and the alarm was tripped on purpose against the real tree:
truncating `hooks/prover-remind.ps1` gave exit 1 naming the file and its expected
28315 bytes; `git checkout` restored it and the gate returned to 0.

**Proved.** `lean/Proofs/RotTreeIntegrity.lean`, 10 theorems, 14 `#guard`s,
and a mutation suite of **13 mutants: 13 killed, 0 survived, 0 discarded**.

| theorem | what it settles |
|---|---|
| `empty_passes_every_text_gate` | an empty file passes *every* text gate, for every pattern |
| `text_gate_is_blind_to_truncation` | a healthy-empty and a truncated file are indistinguishable to it |
| `integrity_separates_them` | the size check distinguishes exactly that pair |
| `integrity_detects_any_truncation` | any truncated file is caught, wherever it sits |
| `legitimately_empty_is_not_flagged` | an intentionally empty tracked file is not an alarm |
| `content_on_disk_is_never_truncated` | no false positive on a healthy file |
| `empty_payload_restore_truncates` | **the bug**: restoring from an empty backup truncates |
| `nonempty_payload_restore_is_safe` | a good backup restores safely |
| `guarded_restore_never_empties` | **the repair**: the guard cannot empty a file that had content |
| `guarded_restore_still_restores` | the guard costs nothing — a good backup still restores |

This is the second instrument in two days with the same shape, and the module
says so: `RotCiSkip.conclusion_audit_is_blind_to_a_skip` was a conclusion audit
that could not see a step skipping inside a green run. **Absence of evidence is
invisible to any instrument that only reads evidence.**

Also fixed while sweeping the deep tier: 14 of 127 `.sh` files were mode
`100644` in the git index and **would have failed on Linux** (2 mine, 12
inherited); all are now `100755`. `Proofs/RotTrap.lean:162` carried an unused
`simp` argument — the whole tree now builds at exit 0 with **zero warnings**.

### A step can print "SKIP" and still be green, and nothing was counting those

`checker/ci-honesty.sh` had never been run against a real completed run from
this machine. Run it and the first thing you learn is that it is *right*: on run
`31308026819` (commit `cef996e`, the last pushed one) it reports **8 passed, 0
failed** — the run concluded `success`, **no step was skipped**, all 171 steps
concluded, and five negative controls confirm it can detect a skipped step, a
failed step, and the scaffolding asymmetry. That result stands and is not
weakened here.

What it cannot answer is a different question. It reads each step's
**conclusion**; a step can print `SKIP: no credentials on the runner` and
conclude `success` anyway. Downloading that run's actual `log.zip` — 721 KB, 4
job logs — and reading it turned up **45 runtime skip lines inside steps that
all concluded green**, spread over **9 steps**.

Attribution first, because the alarming-looking numbers are mostly not alarming:

| marker | raw hits | echoed source | real |
|---|---|---|---|
| `::error` | 39 | 39 | **0** |
| `::warning` | 0 | 0 | **0** |
| `FAIL` | 468 | — | **0** (all are controls asserting an alarm *can* fire) |
| runtime `SKIP` | 66 | 21 | **45** |

Every `::error` hit is GitHub echoing the *text of a guard that never fired* —
and those guards read "would SKIP, and a skip is never a pass -- failing
instead". Zero real error annotations, zero real warnings, zero failures. Every
one of the 45 skips is honestly labelled with `exit 3` or `exit 4` and the words
"never counted as a pass". **This was never a fake green.** It is an *uncounted
coverage gap*, and an uncounted gap grows for free: add one more
environment-gated skip tomorrow and nothing anywhere goes red.

`lean/Proofs/RotCiSkip.lean` (10 theorems, 15 `#guard`s, no imports) proves why
one instrument cannot cover the other. `conclusion_audit_is_blind_to_a_skip`
exhibits two runs that are both entirely `success` and differ only in whether a
step skipped: conclusion auditing returns *the same answer* for both. Not noisy
— blind. `ratchet_separates_them` then shows a declared-budget check
distinguishing exactly that pair, which is what earns the second instrument its
place rather than assuming it.

The rest of the module is aimed at how such a gate gets quietly defused, since
its failure mode is loosening rather than breaking.
`a_budget_containing_everything_disarms_the_ratchet` says a budget extended to
cover every step reports green while checking nothing, and
`ratchet_weakens_as_the_budget_grows` says adding an entry **spends** coverage
instead of gaining it. Both are theorems so the danger is checkable rather than
remembered. All 10 mutants killed (`lean/mutate/mutate_rotciskip.sh`), 0
survived, 0 discarded.

`checker/ci-log-skips.sh` is the binding: it downloads a finished run's
`log.zip`, attributes each runtime skip to a step, and fails on any skip nobody
declared. It carries three fixtures — an undeclared skip must be caught, a
declared one admitted, a clean step left alone — plus an assertion that the
budget covers 9 of 66 checkers rather than the whole tree.

Two things the instrument caught that reading had not:

- **My hand count was wrong.** Scanning by eye gave 7 skipping checkers; the
  scanner found 9. It also *mis*-attributed two of them at first, blaming
  `ab-compliance.sh` and `live-session-smoke.sh`, because GitHub echoes an
  entire `run:` block **before** any of its output — so body order says nothing
  about which checker in a multi-checker step printed the skip. Attribution is
  now at step granularity, which is what the log can actually support, and the
  coarseness of the two inline-block keys is written down in the script rather
  than left to be rediscovered.
- **A control failed against a fixture that was not realistic.** The declared-skip
  fixture omitted the echoed command line that every real log carries, so the
  scanner could not name the step. The fixture was the defect, not the scanner.

Each of the 9 declarations records the measured reason a public runner cannot
host it — uncommitted A/B transcripts, no credentials, no `claude` CLI, no
drive-letter paths, a `[week2]` schedule gate. Declaring them is not the fix and
is not claimed to be; the gap is now **counted**, and any *new* one is red.

Registered as gate #55 (deep, triggered by `.github/workflows/`, the checker,
and its Lean module) with a matching witness in `RotGates.lean`, and exempted
from CI wiring for the same structural reason as `ci-honesty.sh`: it reads a
*completed* run's `log.zip`, which cannot exist for the run reading it.
`workflow-lint.sh` asserts that every exempt checker is still reachable from
`gate-all.sh`, so the exemption states *where* it runs and never that it stopped
running.

### The P2.4 extractor exists, and the first thing it measured was its own blindness

`bench/work-trace.js` reads the process observables off a real session
transcript — O1 verification steps, O2 rework edits, O3 files read before the
first write, O4 claims stated with no supporting tool output. The transcript
format was measured, not assumed: one JSON object per line, `message.content[]`,
`tool_use` entries carrying `name` and `input`. Observed tool distribution on a
58 675-line transcript: Bash 4278, Edit 647, Write 251, Read 165, Grep 10,
Glob 1.

**The finding that changed the design.** Run against that transcript the
extractor reported `O4 = 0` — no unsupported claims — and that number was
worthless. O4 asks whether a claim appears anywhere in the tool output; the tool
output there is **2.68 MB**, so short numbers occur by accident regardless of
what was said. Rather than trust it, the extractor now measures its own
false-negative rate per run by drawing fabricated claims and counting how many
the haystack "confirms" anyway:

| evidence | tool calls | fabricated claims confirmed by chance | usable |
|---:|---:|---:|:--|
| 2.68 MB | 5355 | **42.2 %** | no |
| 1.20 MB | 1637 | **24.0 %** | no |
| 152 KB | 218 | 3.0 % | yes |
| 22 KB | 14 | 0.0 % | yes |
| 4.8 KB | 5 | 1.0 % | yes |

So a clean `O4 = 0` on the first row means nothing, and reporting it as evidence
would have been a false green of exactly the kind this repo exists to catch. The
extractor now refuses: above a 10 % rate it emits `O4_usable: false` and says
the haystack is saturated. P2.4's tasks are single-defect sessions two orders of
magnitude below the boundary, so the instrument is usable where it will be used
— and now proves that per run instead of assuming it.

**`lean/Proofs/RotWorkTrace.lean` — 18 theorems, 14 `#guard`s, 12/12 mutants
killed.** The module proves the blindness is structural rather than unlucky:

| theorem | what it forbids |
|---|---|
| `saturated_cannot_tell_two_messages_apart` | under saturation an honest message and a fabricated one score **identically** — the instrument is not noisy, it is blind, and no sample size repairs that |
| `a_saturated_haystack_yields_no_verdict` | `Verdict.clean` is **unreachable** on a saturated run |
| `a_saturated_haystack_is_never_clean` | the same stated as a refusal, so the false green has a named theorem against it |
| `a_sparse_run_still_reaches_a_verdict` | and the gate is not vacuous — a sparse run still decides |
| `positive_control_cannot_catch_a_loosened_detector` | why controls must run in **both** directions |
| `only_a_negative_control_catches_a_loosened_detector` | the other half of the same statement |

**The both-directions theorem was measured before it was proved.** Mutant W01
forced `isVerification` to return `true` for every command; the self-test went
to exit 1 with **exactly two** failures, and both were "must stay silent"
fixtures. Every positive fixture passed a detector that had been completely
destroyed. That is the whole argument for the negative direction, observed
rather than argued.

The suite's own generator refused its first draft: `usableThreshold : Nat := 100`
is a **prefix** of the replacement `:= 1000`, which is the substitution hazard
that silently double-applies. The mutant value became `900`. A harness that
cannot tell "did not apply" from "survived" manufactures false greens, so
DISCARDED is still counted separately from SURVIVED — here, zero of each.

Registered as gate #54 (`fast`, no triggers, runs on every commit), witnessed in
`lean/Proofs/RotGates.lean`, `gate-split` 12/0. Counts moved with the code:
1030 → 1048 theorems, 579 → 591 mutants, 51 → 52 suites, 54 → 55 modules.

**What this does not claim.** No P2.4 data exists yet. This is the instrument
and its error bars; the run is T14, and `bench/P24-PREREGISTRATION.md` fixes the
verdict rule in advance so the result cannot be chosen after seeing it.

### Two of the five "no difference" results were guaranteed by the corpus, and now a theorem says so

Five A/B corpora returned null on answer quality. At least two of those nulls
are facts about the *measurement*, not about the router, and
`lean/Proofs/RotSaturation.lean` (12 theorems, **11/11 mutants killed**) turns
that from an excuse into a decidable predicate you run **before** spending
money.

| corpus | result | gate | why |
|---|---|---|---|
| `rotmoe-fact` | 84/84 both arms | **refused** | at the ceiling — no better score is representable |
| `rotmoe-calib` | 1/80 in band | **refused** | against the floor at margin 8 |
| `rotmoe-trap` | 59/88 | **admitted** | real room both ways — its null is **not** excused |

`saturated_pair_is_a_tie`: two arms both at the ceiling on the same denominator
record *the same number*, whatever their true quality. The 84/84 tie was
structurally guaranteed before the run started.

**The order is the whole point.** An admissibility rule chosen *after* seeing a
result is indistinguishable from discarding an inconvenient one — so the
predicate, the margin and the verdict rule are all committed first, in
`bench/P24-PREREGISTRATION.md`, while no P2.4 data exists.

Three theorems exist specifically to stop this gate from being softened later:

* `margin_zero_admits_everything` — with a zero margin every corpus passes,
  including 84/84. An instrument that cannot fail, stated as a theorem, so the
  parameter can never be quietly set to 0 and still called a check.
* `admissibleBy_antitone` — loosening the margin is only possible by *lowering*
  a visible number.
* `headroom_admits_regression` — the corpus must be able to show the router
  **losing**. A corpus that can only produce a win is measuring its own
  construction.

And `circular_selection_forces_the_ceiling` proves that picking the tasks the
router already won drives the score to 100% by construction;
`circular_selection_is_inadmissible` makes the gate refuse such a set without
anyone having to notice the circularity by eye.

**What this does not do:** it does not make P2.2 true, and it does not excuse
the trap corpus, which the gate admits. It narrows five nulls to three that
still need an answer, and it replaces the observable — grading the final text
of a turn was never going to see a hook that acts on the *reasoning layer*.
P2.4 measures the work instead: verification invoked, rework edits, files read
before the first write, and unverified claims in the final message. That last
one is in precisely because it is the observable most likely to embarrass the
router.

### D7 was measuring the machine, not the router — and one clause of it is now weaker

**Said first, plainly: the historical maximum is no longer a failure condition.**
That is a weakening of one clause, deliberate, and the rest of this section is
why it is nonetheless a stronger check than what it replaced.

`RotDominance.D7_bounded` is `l.worstMs ≤ msBound` — a claim about **the
router's** worst turn. The estimator was `max("ms")` over the live log, and the
live log is a shared, unbounded history containing turns recorded while
unrelated processes held the CPU. Both numbers below are real, an hour apart,
on an **unchanged router**:

| when | n | median | p95 | max |
|---|---|---|---|---|
| second session loading the CPU | 2158 | 314 | 616 | **8619** |
| quiet machine, controlled probe | 24 | ~230 | — | **305** (sh), **198** (ps1) |

The gate returned **11/0 and then 10/1 on an unchanged tree within the same
hour**. A non-deterministic gate is not a safeguard, and the repair people
reach for when one flaps is raising the bound — which `README.md:772` already
names as the defect to avoid. The bound stays at 500.

**What D7 does now.** It runs the shipped router itself — 7 turns per arm
against a scratch log — and asserts **per arm**:

* **min** — noise can only *add*, so the fastest of N runs is the cleanest
  estimator of the router's own cost. If even the best run breaches the bound,
  no contention story survives.
* **median** — the turn a user actually gets. Contention cannot move a median;
  a router that got slower moves it immediately.
* **max is printed every time** and asserted against nothing, because a
  wall-clock maximum on a preemptive OS is not attributable without a control.

`D7c` keeps the field data and asserts its **median**, printing n / median /
p95 / max / count-over-bound so the tail is never hidden.

**Three defects were found while building this, each by the next control:**

1. **The first rewrite asserted the probe's max and failed at 1366 ms** — while
   the same router measured 217–305 ms (sh) and 172–181 ms (ps1) moments
   earlier in isolation. The gate's own subprocess work was preempting its own
   probe. The instrument was wrong, not the router.
2. **Pooling the arms let a fast arm mask a broken one.** Writing the negative
   control exposed it: a 600 ms regression in `sh` leaves seven fast `ps1`
   samples sitting on the pooled median and the gate stays green with half the
   router broken. Now asserted per arm — a user runs one arm, whichever their
   shell is.
3. **Two earlier attributions of mine were wrong and are retracted.** "The tail
   is the PowerShell arm" was inferred from record *counts* (2112 ps1 vs 58 sh),
   which says which arm runs most, not which is slow — `ps1` is in fact the
   **faster** arm by ~120 ms. And a "56 ms/turn" figure for `sh` was measured
   with a `--hook` flag that does not exist in that script; the run wrote
   nothing and timed a no-op.

**Verified killable**: injecting `sleep 0.6` into the `sh` arm (mutation
asserted present, 1 site) turns `D7 [sh]` red at `min=881 ms` **and** `D7c` red
at `median=914 ms`, while `D7 [ps1]` stays green — two independent checks
catching it, and the per-arm split behaving as designed. Restored: **13 passed,
0 failed**.

### The log repair, and the two false greens it produced on the way

The corruption reported in the section below is now **fixed in both writer arms,
proved, and gated** — but the interesting part is that the first two attempts
both looked green and were not.

**The defect.** A writer killed mid-record leaves a line with no trailing
newline. The next append lands on those bytes and fuses two records into one
unreadable line. 409 of 5000 lines (8.2%), 27 carrying two `"kind"` keys.

**The repair.** `_rot_terminate` (sh) and `Complete-RotPartialLine` (ps1) close
a dangling line before appending. On a healthy file both are provably no-ops —
`identical_on_the_healthy_path` — which is why they are safe on the hot path.

**`lean/Proofs/RotLogAtomicity.lean` — 26 theorems, 11/11 mutants killed.** The
model is lines of pieces, `whole` or `frag`. The load-bearing pair:

| theorem | says |
|---|---|
| `naive_loses_the_next_record` | fusing does not raise the recovered count **at all** — the interrupted process costs its SUCCESSOR a good record |
| `safe_keeps_the_next_record` | terminating first keeps it, +1 |
| `corrupt_line_count_cannot_tell_them_apart` | both writers leave the SAME number of corrupt lines |
| `record_count_does_tell_them_apart` | only the recovered-record count separates them |
| `empty_has_nothing_pending` | a fresh log cannot fuse its first record |

**FALSE GREEN 1 — the test passed for the wrong reason.** The differential
expected 2 recovered records and got 2, so it went green. But the router writes
**two** records per turn, and the second had simply landed on a fresh line after
the first was destroyed. The guard was doing nothing. The expectation is now
*calibrated* — measured from a clean run as `1 + N` — so only a working guard
can satisfy it.

**FALSE GREEN 2 — the guard was in the wrong place.** It was defined inside
`hook_mode` and covered the two shell appends. The gauge record is written by
**awk** (`print rec >> dbg`) and runs FIRST, so the guard fired after the damage,
saw a terminated file, and correctly did nothing. `_rot_terminate` is now
top-level and both writers call it. Every sink must be terminated before EVERY
writer, not before the last one.

**`checker/log-integrity.sh` — 39 checks, gate #53, DEEP tier.** It counts
**recovered records, never corrupt lines**, because the theorem above proves a
line-counting gate would have scored the whole repair as worthless. It drives
both arms live against a deliberately truncated log, discovers its corpus rather
than listing it (22 logs audited), and asserts the corrupt-line *tie* explicitly
so nobody later "simplifies" the metric back to the blind one.

Negative control, run: deleting the two awk-site calls → **exit 1** with
`repaired writer recovered 2, expected 3`; restored → **exit 0**, zero mutant
sites left. `checker/log-scan.js` counts a line that parses but is not an object
as corrupt, because `JSON.parse` silently keeps the LAST of two fused `"kind"`
keys.

`RotGates.lean` moved with it: 52 → 53 gates, deep 17 → 18, and the staged run
for `hooks/rot-router.sh` 40 → 41.

### `R/s+ = 0` was an "absolute law" that nothing enforced — and D6 could not have caught it

`engine/rot-lean.md:316` calls a zero gauge reading a violation: *"a placeholder
never computed; the gauge must be real or it is not."* `PROMISE-TODO.md` P4.4
recorded it as the one gauge property with no instrument behind it. It now has
two — a theorem and a gate — and finding it exposed something worse than the
original defect.

**The live log held 96 records reading `"Rs":0`**, every one with `"mu":0` on all
nine lenses. They are historical: the newest is `2026-08-09T21:56:32`, and
`hooks/rot-router.sh:274` sets `MUS` unconditionally, so today's router cannot
emit one (probed live: `Rs = 0.66427`, every `mu` in the shipped set). Nothing
*stopped* it from returning.

**The worse finding is that `D6 RECOMPUTABILITY` passes on those records.** D6
sums the logged `term` fields and compares to the logged `Rs`
(`checker/dominance.sh:218-220`). On an all-zero record that is `|0 - 0| < 0.01`
— a pass. The gauge could break completely, emit nothing but zeros, and the gate
would stay green. A check that cannot distinguish *the arithmetic is right* from
*there is no arithmetic* is not evidence of the first.

`lean/Proofs/RotGaugeZero.lean` — **24 theorems, 11/11 mutants killed**:

| theorem | what it settles |
|---|---|
| `Rs_pos` | a well-formed record **cannot** read zero — P4.4, as a law rather than a wish |
| `recomputes_does_not_imply_informative` | the D6 hole, with the broken record as the witness |
| `d6_with_informative_is_strictly_stronger` | the pair rejects a record D6 accepts |
| `idle_is_not_a_violation` | **and the new check is safe**: a turn on which no lens fired still reads positive, because `σ(0)` is `0.1192`, not `0` |
| `all_mu_zero_forces_zero` | the historical defect reproduced, not merely described |
| `wellformed_passes_both` | the strengthened gate can never fail a healthy gauge |

`idle_is_not_a_violation` is the one that decides whether this is a safeguard or
a trap. A gate that flagged quiet turns would be a spec forbidding a correct
future. Only a zero *factor* can zero the gauge, and no factor is ever
legitimately zero — so `D6b INFORMATIVE` fires on a broken instrument and never
on a quiet one. `dominance` goes 10 → **11 checks**.

The theorems are stated over **exact scaled integers**, not ℚ. That is not a
convenience: `decide` cannot evaluate rational arithmetic here, because `Rat`
multiplication normalises through `Nat.gcd`, which is well-founded recursion the
kernel refuses to reduce. On ℤ all 14 `#guard`s are real executions — verified by
breaking one and watching the build turn red.

**Negative control for the gate**, run against real data rather than a fixture:
the check was extracted from the live `dominance.sh` (never a copy, to avoid
drift) and run over the live debug log, where it reported `zero=50 muzero=47` —
it fires. Extracting it also caught a defect in the extraction itself: under
`node -e` the log is `argv[1]`, under `node file.js` it is `argv[2]`, and the
first attempt silently measured the script instead of the log and reported a
reassuring `0 0 0 0`.

### The debug log is 8.2% corrupt, and every statistic drawn from it was quietly short

Found while building the control above, and recorded here because it is the
CLEAR CONDITION's explicitly unmet item — *"it doesn't as of now check: `*.log`
Debug of RoT MoE"*.

`grep` counts **3090** gauge records in `~/.claude/rot-moe/rot-route-debug.jsonl`;
`JSON.parse` accepts **2750**. **410 of 5000 lines do not parse.** The shapes:

- 47 lines carry **two `"kind"` keys** — two records spliced into one line.
- 363 more end in `}` yet fail to parse, beginning mid-token (`a":0,"delta":0,…`).
- One line holds a **complete 163-character `route` record with a gauge record's
  tail appended to it**, no newline between.

That last one names the mechanism: **non-atomic concurrent append**. Both writers
are affected (`powershell/hook` 190, `bash/test` 114), which rules out a single
writer's bug and points at the write discipline itself. The log is also capped at
exactly 5000 lines and rotates, which is why a count taken twenty minutes apart
moved from 96 to 66 — a fact worth knowing before trusting any absolute figure
taken from it.

The consequence is not cosmetic: every statistic ever computed from this log
silently omitted ~8% of its input, including the lens-activity shares behind
P3.1 and P3.2. No claim is being revised on the strength of an unrepaired
instrument; the repair, its gate and its Lean model are the next unit of work.

### The first attributable advantage: same answers, ~45% less wall time, order-controlled

Five answer-quality corpora had produced four nulls. The fifth — the trap corpus,
pre-registered at `2e5732f` before a single turn ran — produced the first result
that survives its own control, and it is **not** an answer-quality result.

**Latency, paired per item, sign test, both orderings run:**

| ordering | routed faster | p | speedup |
|---|---|---|---|
| a-first (unrouted ran first) | 55/60 | 1.04e-11 | 44.7% |
| b-first (routed ran first) | 56/60 | 9.09e-13 | 46.6% |

The confound was named before the control was run: arms run sequentially against
the same files, so whichever runs **second** reads from a warm page cache. If
that were the cause, reversing the order moves the advantage to the other arm.
It did not — the routed arm is faster running **first, on a cold cache**, by
slightly *more*. `bench/trap-latency.js` refuses to attribute from a single
ordering, emitting `attribution: UNATTRIBUTED` until given both; with both it
reports `attribution: router`.

**Accuracy did not move.** Rep 1 measured a routed *deficit* (59 vs 47, band 12,
p = 0.0005, driven entirely by `theorem_count` at 0/12 with 11 trapped). Rep 2,
same corpus and order, went 59 vs 58 with `theorem_count` at 12/12 and nothing
trapped. Amendment 1 to the pre-registration — written after rep 1 and **before**
rep 2 — fixed the rule: an unreplicated collapse is reported as unreplicated and
no claim is made in either direction. Rep 1 is kept, not deleted.

So the honest headline is *the same answers, in about half the time*, on top of a
routing layer the default loop does not have. It is **not** "better answers", and
`dominance_says_nothing_about_answer_quality` still separates the two.

### Two defects in this project's own instruments, both declared

- **The pre-registered decision table had no row for the router LOSING.** Rep 1
  mapped to `null` — "no difference established" — when a difference *had* been
  established, in the other direction. A decision table that can only express the
  outcome its author hoped for is not neutral. `disadvantage` is now the symmetric
  partner of `advantage`, evaluated on identical terms.
- **The answer parser scored 0/60 for *both* arms on the first pass.** The arms
  were right; `firstInt` rejected any digit followed by a period, so `**0.**` —
  the natural way to answer "how many" — read as no integer at all. Repaired after
  data existed, and declared for that reason: it is a change to the **parser**, not
  a decision rule, it struck both arms identically, and it made the result *worse*
  for the router (an uninformative `noPower` became a measured deficit).
  `bench/trap-parse-controls.js` pins 15 cases in both directions plus a negative
  control that rejects a naive `/(\d+)/` parser.

### `RotOrdering.lean` — the instrument's refusal to attribute is now a theorem

`trap-latency.js` declining to name a cause from one ordering was a convention in
a script. It is now 12 theorems (11/11 mutants killed, no `sorryAx`, kernel
re-checked at 0 bytes):

- `one_ordering_cannot_attribute` — two models disagreeing completely about the
  cause produce the **same** a-first observation.
- `every_gap_has_a_pure_router_and_a_pure_position_explanation` — the ambiguity is
  total, not a quirk of one witness: *any* observed gap has both explanations.
- `two_orderings_determine_both_effects` / `effects_are_recoverable` — with both
  orderings the unknowns are pinned **and** computable: their sum is `2·armEffect`,
  their difference `2·posEffect`.
- `cache_world_predicts_routed_is_slower_when_it_runs_first` — the specific
  alternative the control excluded, and why the b-first run was decisive.
- `three_worlds_one_a_first_observation` — three incompatible causal stories, one
  number; all three separate b-first.

A generator defect worth recording: the first suite reported **11 DISCARDED**
because the generator emitted `run_mut <id> <why> <needle> <repl>` while the
harness signature is `<id> <needle> <repl> <why>` (`mutate_rottrap.sh:112`). The
harness was right and said so — `DISCARDED`, never `SURVIVED`. That distinction is
the reason the suite can be trusted at all.

### "Surpasses standard Claude Code" was never a proposition — now it is one, and it is measured

The project's central claim had been attacked only in its weakest reading: *does
the routed arm win an answer-quality A/B?* Three corpora answered **no**, each
for a different reason, and those results stand — brevity confound
(`RotAbVerdict`), selectivity confound (`RotGrounding`), and a ceiling
(`RotCeiling`). The fourth corpus closed the same way: two calibration reps over
80 items produced a band of **1** (floor 1, ceiling 78), which is
`RotCeiling.noPower`, not a null.

That was the wrong target. Standard Claude Code has **no routing layer at all** —
no lane, no lens weighting, no gauge, no per-turn record of why a turn was
handled the way it was. The claim worth testing is structural, and
`lean/Proofs/RotDominance.lean` (17 declarations) now states it as seven
conjuncts, each proved load-bearing by a near-miss layer that satisfies the other
six:

| | conjunct | measured on the shipped router |
|---|---|---|
| D1 | TOTALITY | 31/31 declared hook events handled at exit 0 |
| D2 | CONSERVATION | 0 blocked, 0 denied, 0 stderr bytes |
| D3 | ADDITION | 62 router-observable records (default loop: 0) |
| D4 | DISCRIMINATION | 10 distinct lanes reached (≥ 9 declared) |
| D5 | DETERMINISM | 12 replays → 1 distinct route |
| D6 | RECOMPUTABILITY | 5/5 gauge records re-derived from their own fields |
| D7 | BOUNDED COST | worst turn 276 ms (bound 500 ms) |

`checker/dominance.sh` measures all seven against `hooks/rot-router.sh` and was
verified killable by three deliberately broken routers: one that exits 2 on a
single event (D1+D2 fail), one pinned to a constant lane (D4 fails), and one
branching on `$$` (D5 fails).

**D2 had never been measured.** In Claude Code a hook exiting 2 *blocks* the tool
call, so a router that added a gauge while blocking one event in thirty would be
strictly worse than no router — with every other conjunct still green.

`dominance_says_nothing_about_answer_quality` is a theorem, not a footnote: a
green verdict here may never be reported as "better answers".

### A five-sample determinism test could not see a nondeterministic router

Found by a mutant, not by inspection. The replay loop spawned a **fixed** number
of subprocesses per iteration, so the PID advanced by a constant stride; a router
whose hidden state had a period dividing that stride was sampled at the same
phase every time. It varied across twelve hand probes and still reported "1
distinct route".

`aliased_sample_is_always_phase_zero` and `more_samples_do_not_break_the_alias`
prove why raising the sample count was never the fix — at a constant stride,
*every* count returns the same value. The repair varies the stride;
`varying_stride_breaks_the_alias` and `varying_stride_separates_period_three`
show it works for period 2 and period 3, so the fix is not fitted to the one case
that broke.

### 30 of 46 mutation suites left the tree unbuildable whenever they reported a real failure

The EXIT trap restored the **source** but not the `.olean`, which every mutant
deletes. The rebuild lived in the suite's tail — reached only on the *success*
path. So a suite that found something exited early, left the module uncompiled,
and the **next** run tripped the no-download guard and reported `SKIP` exit 3
instead of the failure. The real result vanished on the second run.

`fixmut2.js` had fixed this for the passing path a day earlier; the failing paths
were never covered. The rebuild now lives in the trap, which runs on every exit
path, and was verified by a negative control that reports `SURVIVED` at exit 1
**and** leaves the tree buildable.

The same control found a second harness rule: **a needle that is a prefix of its
replacement is scored DISCARDED**, correctly, because the post-check still finds
the needle. `## The definition` → `## The definitions` tests nothing.

### Two defects in gates added the previous day

- `checker/plugin-root-consistency.sh` was in the shell table and the Lean
  witness but in **no workflow** — CI had never run it once. Caught by
  `workflow-lint`, now registered.
- The same script piped into `grep -q` under `pipefail` at two sites. `-q` exits
  on first match, `printf` takes SIGPIPE 141, and the pipeline returns 141 — so
  **a match was reported as a failure**. Replaced with a full-read `grep … >/dev/null`.

### The kernel had never re-checked a single delivered proof — the filesystem was folding the name

`lake build Proofs.RotMoE.RotCeiling` exited **0** and wrote the olean.
`lake env leanchecker Proofs.RotMoE.RotCeiling` answered

```
uncaught exception: Could not find any oleans for: Proofs.RotMoE.RotCeiling
```

Both statements were true simultaneously, for **45 delivered modules, for
weeks**. The directory on disk is `Proofs/RotMoe/` — lowercase `e`. Windows
resolves paths case-**insensitively**, so the compiler opened the file happily;
`leanchecker` resolves a module name by **exact** match and could not. The build
could not see the error and the kernel could not see the proof, so the strongest
instrument in the delivery ritual was silently unavailable the entire time.

**Two earlier turns on this were wrong, and that is the instructive part.**

1. The previous diagnosis blamed a missing aggregator (`Proofs/RotMoE.lean`).
   Writing it changed nothing — `the_aggregator_cannot_fix_a_case_mismatch`
   proves it could not have.
2. The previous *repair* made it worse: seven imports reading
   `import Proofs.RotMoe.X` were "corrected" to `Proofs.RotMoE.X`. They had been
   **right**. The edit moved them away from the directory's real name and the
   build stayed green throughout, because the filesystem kept absorbing it.

The competing hypothesis — that `leanchecker` cannot resolve nested module paths
— was killed by a **control**, not by argument: a freshly built
`Proofs.ZZDepth.Leaf` re-checks at exit 0. Depth was never the problem.

After canonicalising every reference to `RotMoe`, **34 of the 35 modules that
have an olean re-check at exit 0. Before, the number was zero.** The one failure
(`RotVacuity`) imports a module whose olean is absent for an unrelated,
pre-existing mathlib cache mismatch; 11 modules in that tree do not compile for
the same reason, which is an environment defect and is reported as such.

This is not a Windows curiosity. The exact-match resolvers are the ones that
matter for publication — a Linux CI runner, a case-sensitive checkout, `git`
itself. A tree that only builds because the developer's filesystem folds case is
a tree that fails on the machine meant to verify it.

**`lean/Proofs/RotCaseFold.lean`** — 14 theorems, 13 guards, mutants F01–F10,
**10/10 killed**. `a_green_build_does_not_imply_the_kernel_can_find_it`,
`same_tree_is_red_on_a_case_sensitive_host`, `exact_implies_insensitive` (the
disagreement can only ever run in one direction),
`canonical_names_resolve_on_every_host` (the repair, stated for all names, not
for the two that happened to be wrong), and `depth_was_not_the_problem` so the
refuted hypothesis stays refuted.

**`checker/lean-module-case.sh`** — new gate, registered in `gate-all.sh`. It
compares every `import Proofs…` against a `find` listing, because a `[ -f path ]`
test on Windows answers *yes* for the wrong case and would certify the defect it
exists to catch. It distinguishes "differs only in case" from "does not exist",
since conflating them is what sent the last two sessions after the wrong bug.
Two positive controls run before any clean report, and both failure paths were
tripped on purpose: a planted wrong-case import exits **1** naming the real
on-disk spelling, a planted missing import exits **1** with the other message,
and the tree returns to **0**.

### A fourth corpus, designed before it was run — and the two ways calibration cheats

Three efficacy metrics have now failed three different controls: brevity,
selectivity, and a ceiling. The remaining route is a corpus calibrated so
baseline accuracy sits strictly between floor and ceiling. That design is where
a measurement becomes easy to fake, so it was **proved before it was built**.

**`lean/Proofs/RotCalibration.lean`** — 18 theorems, 15 guards, mutants K01–K12,
**12/12 killed**. It imports `RotCeiling`, so the verdict machinery already
proven there applies unchanged.

- `circular_selection_cannot_lose` — keep only the pairs the **routed** arm got
  right and `unroutedOnly` is zero *by construction*, for every input. The
  filter would produce the win, not the router.
- `selecting_on_the_test_result_also_biases` — the subtler one, because it looks
  fair: selecting on the **baseline** arm's graded result zeroes `bothRight` just
  as mechanically. Selection must read *calibration* reps, never the reps being
  graded, whichever arm they come from.
- `band_needs_two_reps` and `one_rep_pool_calibrates_to_nothing` — with one rep
  an item scores floor or ceiling and nothing else, so a one-rep calibration
  selects the **empty** corpus. A harness that then reported "no difference"
  would be reporting the absence of its own input.
- `calibration_does_not_guarantee_power` — the anti-overclaim. An item can sit in
  the band and still be answered correctly by both arms on the fresh rep; a
  calibrated run with zero discordant pairs is still `noPower`, not a null.
  Calibration removes a known *reason* for no power. It does not create power.
- `all_three_clauses_are_load_bearing` — drop any one clause of `sound` and a
  design that must be rejected is accepted.

The planned design is recorded as a value, not as prose: `⟨3, true, false⟩` —
three baseline reps, a fresh graded run, routed arm blind to selection.

Counts: **908 theorems, 46 modules, 43 suites, 494 mutants, 60 checkers.**

### The mutation harness could not fail — 26 suites, one unconditional `exit 0`

**The instrument that certifies every theorem in this repository was itself a
false-green generator.** The shared suite template ended with

```sh
echo "All $killed mutants killed. Every belief above is refuted by a theorem or a #guard."
exit 0
```

with no reference to `$survived`. A suite in which mutants survived printed that
sentence and exited **0**. It only failed when *zero* mutants ran.

Found by accident, in the only way it could be: mutant `C05` survived in
`mutate_rotceiling.sh` and the suite reported success anyway. **11 suites shared
the unconditional ending and are now gated**; the other 32 already gated on
survivors with different syntax, and three separate greps of mine got the count
wrong before the endings were read directly — a lesson about auditing by pattern
instead of by inspection.

The gate distinguishes the two failure kinds, because they mean opposite things:

| outcome | meaning | exit |
|---|---|---|
| `SURVIVED` | mutation applied, build stayed green → **coverage gap** | 1 |
| `DISCARDED` | mutation never applied → **nothing was tested** | 1 |
| `KILLED` (all) | every belief is defended | 0 |

**Negative control, run before trusting it:** the repaired
`mutate_rotceiling.sh` exits **1** with `FAIL: 1 of 8 mutant(s) SURVIVED`. The
instrument can fail, which is the only reason its green counts.

A second defect surfaced from the same run: a passing suite left the module with
**no `.olean`** — each mutant deletes it and the exit trap restores only the
source — so `lake env leanchecker` on that module failed immediately afterwards
for a reason unrelated to any proof. All 11 suites now **restore, rebuild, and
gate on a green baseline** before reporting success.

`C05` was not noise. It weakened `<` to `<=` in `verdict`, which would classify
a **tie** as a routed advantage, and nothing in the module covered a tie with
power. The hole is closed with a theorem, not by retiring the mutant:
`tie_with_power_is_null` and `every_tie_with_power_is_null (n) (0 < n)`.

### Three efficacy metrics, three different failures — the claim is still unproven

| metric | headline | its own control | verdict |
|---|---|---|---|
| compliance | routed 29–4, p = 1.09e-5 | 27/29 wins were merely shorter answers | brevity confound |
| grounding | routed 8–0, p = 0.0078 | volume-matched 18 pairs: 0–0, all tied | selectivity confound |
| facts | 84–84 | zero discordant pairs | **ceiling: no power** |

`bench/ab-grounding.js` measures citation precision — a ratio, so length
cancels. It defeated the brevity confound and then failed a second one: a ratio
resists length but not **claim volume** (routed asserts 1.42 checkable items per
turn against 2.47). Holding volume constant, every comparable pair tied.

`bench/fact-prompts.js` + `bench/fact-score.js` answer that by punishing
silence: 84 prompts with ground truth derived mechanically from the repo, one
correct answer each, **abstention scored WRONG**, tools enabled. Both arms
scored 84/84 — a **ceiling**, which is not a null. `Proofs/RotCeiling.lean`
proves the distinction so `p = 1.0` can never be quoted as "the arms are equal".

Two ground-truth defects were caught before either could grade an answer:
`RotVacuity.lean:35` is **prose inside a `/- -/` block** beginning with the word
"theorem" and was extracted as a theorem named `at`; and the first `share` lemma
in `RotLensAbility` was **false as stated** because `Nat` division truncates.

What survives all three controls: **4 absolute false statements routed against
29 unrouted** — achieved by saying less and choosing when to speak. Per-claim
reliability is indistinguishable.

`bench/ab-session.sh` gained `ROTMOE_AB_PROMPTS` and `ROTMOE_AB_SUFFIX` so a
second corpus reuses the runner instead of forking it. The suffix must be
overridable: appending "answer in one or two sentences" to a factual question
would re-import the very confound the fact corpus exists to escape.

### The emitter, found: the plugin root was a stale Desktop folder

**The `*.log` alarm is CLOSED with an attributed cause.** A self-attributing
execution marker — recording not just *that* the router ran but *as what* —
caught it:

```
ROOT=[<DESKTOP>/RoT-MoE 0.7.1-Lean/]
```

while `installed_plugins.json` declares `cache/rot-moe/rot-moe/1.0.1` and
`known_marketplaces.json` names `Desktop\RoT-MoE 1.0.1-Lean`. **Three paths,
and the one that executes is named by neither registry file.** That folder holds
an 18048 B router with `RotSrc` x0 — a build predating the provenance feature,
which is precisely why every live record arrived without `src` or `session`.

So the five patched copies were all irrelevant: patching a path moves the
observable only if the runtime resolves that path.

**The method that should have been used first:** identify a running program by
what it EMITS. A record lacking `src` cannot come from a build that always emits
`src`, and a repo-HEAD router does — measured on a hand-driven invocation. That
localises the build with no filesystem search at all.

`Proofs/RotPluginRoot.lean` — 6 theorems, 7 guards, 0 sorry, **8/8 killed**:

| theorem | what it settles |
|---|---|
| `registry_driven_patch_missed_the_runtime` | why five patches produced no change |
| `registry_patch_fails_whenever_runtime_diverges` | quantified over every deployment, not just today's |
| `patching_the_runtime_root_is_effective` | the method is sound once aimed correctly |
| `bare_record_rules_out_a_modern_build` | provenance-absence is positive identification |
| `bare_record_admits_an_old_build` | the test discriminates, not merely rejects |
| `provenance_separates_the_builds` | separation without filesystem access |

**Production has NOT been re-pointed** at the installed 1.0.1. Re-registering the
marketplace changes the live session's plugin root; that belongs at a session
boundary with a backup, not mid-run. Cause proved, repair scheduled.

**A defect found in my own measurement, same hunt:** I checked for new records
with a line count on a log pinned at its 5000 cap, and read `new_records=0`
while a record had just arrived. The log rotates. That is
`delta_false_passes_under_rotation` — proved this morning, then walked into
hours later on the real file. Timestamps, not counts.

Counts: **838 theorems, 40 modules, 37 suites, 439 mutants**.

---

### The A/B's disarm check was counting the wrong thing

**This is NEXT item 4 -- the `bench/` A/B on the now-attributable log -- and it
begins by finding the harness's verdict unsound rather than by running it.**

`bench/ab-session.sh:307` decided whether arm B was genuinely disarmed by
comparing a route-record count before and after the run. That delta is taken
over the **whole central log**, which is append-shared and rotating, while the
question is about **one run**. Measured today: all 176 records in
`bench/ab-metrics.jsonl` carry `arm`, `turn`, `dur`, `cost_micro`, `len`,
`outTok`, `model`, `q`, `hedge`, `narr`, `leak` — and **zero** carry `session`
or `src`. The join that fixes this has been available since the observability
subsystem landed and was simply not used; the harness even captures the id
already, at `:279`.

**Unsound in both directions**, and `Proofs/RotAbJoin.lean` proves each:

| theorem | failure |
|---|---|
| `delta_false_alarms_on_foreign_traffic` | nine checkers and any concurrent session append with `src=test`; their records condemn an arm that emitted nothing |
| `delta_false_passes_under_rotation` | **the dangerous one** — rotation at `ROTMOE_DEBUG_LOG_MAX` drops as many records as arm B wrote, the delta reads 0, and a fully ARMED run is reported clean |
| `delta_cannot_separate_silence_from_rotation` | the two worlds give an identical verdict |
| `join_ignores_foreign_traffic` | quantified over **every** foreign session, not an example |
| `join_counts_the_arms_own_record` | rotation of somebody else's records cannot silence the arm's own |
| `join_never_false_passes` | the quiet green is unrepresentable |
| `join_ignores_non_route_records` | a gauge line is not evidence of routing |

**7 theorems, 8 guards, 0 sorry, 8/8 mutants killed.** A04 and A05 attack the
rotation half specifically — if those had survived, only the harmless failure
mode (a noisy red) would have been proved and the quiet green would not.

The harness now joins on `session` and, when no session id exists, **refuses to
judge the arm at all** rather than falling back to the delta — a silent fallback
to an unsound check is how a defect returns. It also reports when join and delta
disagree, so the join is seen earning its keep. Negative control on real data:
global route count 3, joined on this session 1, joined on an absent session 0.

Two mutants were **DISCARDED** on the first run and are reported as such, never
as survived: A03 used a multi-line needle (the harness counts matching lines, so
it read 2) and A08 was double-escaped to `\\"armB\\"`. Both are harness bugs,
both were fixed, and the re-run killed 8/8. The zero-mutant guard added earlier
today is what made the distinction visible.

Counts: **832 theorems, 39 modules, 36 suites, 431 mutants**.

---

### The probe broke the program it was probing

**A correction to the entry below, published the same day.** The conclusion
there — that the installed router is not the live emitter — still holds, but the
experiment offered as proof was invalid and has been redone.

The execution marker was inserted at line 2 of a script whose lines 22-23 are
`[CmdletBinding()]` / `param(`. PowerShell requires `param` first, so the
instrumented file **did not parse** (`PARSE_FAILS: Unexpected attribute
'CmdletBinding'`), `pwsh -File` exited non-zero, and the `|| bash` fallback ran.
The marker was silent because the probe had destroyed its own target — the same
two-causes-one-observation error the entry below is about, committed inside the
investigation of it.

Redone with the marker after the param block, `PARSE_OK` verified **while
instrumented**, and a positive control fired by hand (1 marker line, 2 records)
before trusting the silence. Also corrected: `rot-lean-inject.ps1` was described
as writing nothing to disk; it writes a turn-delta state file (`Set-Content`
x2). It still emits no route record, so the ruling-out stands — but the stated
reason was wrong.

Four new theorems in `Proofs/RotDeployment.lean` (now **12 theorems, 6 guards,
12/12 killed**):

| theorem | what it forbids |
|---|---|
| `broken_probe_is_silent_either_way` | reading silence from a probe that broke its target |
| `broken_probe_mimics_a_dormant_target` | the exact confusion, exhibited |
| `silence_is_evidence_once_the_probe_runs` | silence counts **only** after the precondition is discharged |
| `positive_control_is_required` | a probe never fired on purpose is not an instrument |

**Standing rule: an instrument that modifies its target must prove the target
still runs, and must be fired once deliberately, before its silence is data.**

---

### Five copies patched, none of them running

**Production still emits route records with no `src` and no `session`, and this
entry does not fix that -- it records what was ruled out and the instrument that
ruled it out.** The honest state is an open alarm, not a repair.

The obvious theory was a stale deployment. So every router copy on the machine
was replaced with the fixed 24462 B build:

| copy | before | after |
|---|---|---|
| `~/.claude/.../rot-moe/1.0.1/hooks/rot-router.ps1` | 18048 B | 24462 B |
| `~/.claude/.../rot-moe/0.7.1/hooks/rot-router.ps1` | 18048 B | 24462 B |
| `~/.claude/.../rot-moe/0.6.1/hooks/rot-router.ps1` | 18048 B | 24462 B |
| `Desktop/RoT-MoE 1.0.1-Lean`, `Desktop/RoT-MoE 0.7.1-Lean` | 18048 B | probed |

Driving any of them by hand emitted `"src":"hook"` correctly. The live log kept
writing bare records throughout.

**What settled it was an execution marker**, not another patch: one line
appending a timestamp to a side file. The log gained a record at 09:29:56 while
the marker file stayed **empty**. The file being edited is not the file being
run. Also ruled out by measurement, so the next reader does not repeat it:
`prover-remind.ps1` and `tools/sanctum/rot-lean-inject.ps1` never write the log
(no append call, no log path), and no `settings.json`, `settings.local.json`,
`.claude.json` or project-level config references any `rot-router`.

`Proofs/RotDeployment.lean` -- **8 theorems, 6 guards, 0 sorry**, 8/8 killed:

| theorem | what it settles |
|---|---|
| `absent_field_does_not_identify_the_cause` | **load-bearing** — an unpatched *running* copy and a patched *dormant* one give the identical observation |
| `repatching_a_dormant_copy_is_a_fixed_point` | so re-patching can never resolve it — the hour lost, as a theorem |
| `marker_is_blind_to_patching` | the discriminator must not depend on the thing it discriminates |
| `marker_separates_the_indistinguishable_pair` | and it does separate them |
| `emitter_is_outside_the_known_set` | what the measurement actually licenses: every known copy is patched and dormant, so the writer is not among them |
| `dormant_set_says_nothing_about_the_writer` | the guard against over-reading that — this does **not** prove the records stopped |

This is the third appearance of one defect: a mutation whose patch silently did
not apply, a checker reading a log the router never wrote, and now a fix in a
dormant file. All three are **acting on an artefact without confirming the
artefact is the one in play**.

Counts: **821 theorems, 38 modules, 35 suites, 419 mutants**.

---

### The CTT install test passes -- and the harness had been blaming the wrong thing

**The CTT install test now runs end to end at exit 0**, which was the stated
prerequisite to publishing. Getting there turned up a checker that was
confidently wrong.

**First, the shadowing install was cleared.** CTT was running the local-only
`1.0.1`. `claude plugin install` alone cannot move it -- `RotUpgrade` proves
that -- so the uninstall-then-install sequence was used, exactly as
`uninstall_then_install_upgrades` describes:

| step | measured |
|---|---|
| `marketplace update rot-moe` | exit 0, `.rot-release` refreshed from `rot-moe-0.9.1-lean.zip` |
| `plugin uninstall` | exit 0, registry `{}` |
| `plugin install` | exit 0, `installPath: .../0.9.1` |
| installed router | `rot-router.sh` 37421 B, `_rot_src` x10 |

Driving that installed artifact as a hook produced the record production has
**never** produced:

```json
{"kind":"gauge","session":"ctt-0f3","src":"hook","K":9, ...}
```

**Then `ctt-session.sh` refused, and its stated reason was false.** It reported
`0 route records` and `Most likely: the CTT credential expired`. Measured
against the running instance: `claude auth status` -> `loggedIn: true`, a raw
turn replied `OK`, and **20 records with `"src":"hook"` were in the CTT log
under the harness's own session id** `3111c07c-...`.

The cause is precedence. The harness does `export ROTMOE_DEBUG_LOG="$LOG"`; the
CTT `settings.json` carries an `env` block naming a different path, **and the
settings block wins**. The harness watched a file the router never writes,
counted zero, and named a credential that was never broken. CP29 records the
same message from a run where it probably WAS the credential -- which is how a
misnamed cause becomes a fake pattern.

`Proofs/RotEffectiveLog.lean` -- **11 theorems, 8 guards, 0 sorry**, 8/8 mutants
killed:

| theorem | what it settles |
|---|---|
| `settings_wins`, `inherited_used_when_settings_silent` | the precedence, as measured |
| `harness_watches_the_wrong_file` | a different settings path means the watched file is not the written file |
| `zero_at_watched_says_nothing` | **the load-bearing one** — two runs agree on everything the naive check reads and differ in what happened |
| `naive_conflates_override_with_dead_credential` | the old form cannot separate them; the new one can |
| `the_measured_shape_is_misdiagnosed` | naive says credential, truth is override — over all counts |
| `failure_dominates`, `silence_is_not_override` | three causes, three verdicts |
| `collection_is_reachable`, `collected_requires_a_record` | the pass is reachable and never announced without evidence |
| `override_is_not_a_pass` | following the override is not a licence to pass |

`ctt-session.sh` now resolves the effective path the way the router does, and
its refusal names one of three causes instead of guessing one. Re-run:
**exit 0, 2 turns, 0 failed, 10 route records collected, 0 trace leaks.**

### A mutation suite that ran zero mutants and exited 0

Found in my own generator and worth recording as a defect class. The template
phrase `WHAT THIS SUITE IS AIMED AT` occurs **twice** — once in the file header
and once above the mutant table — and an `indexOf` cut at the first dropped the
counters, the preflight and `run_mut` itself. The 97-line result printed

```
=== RotEffectiveLog:  killed,  survived,  discarded,  skipped ===
All  mutants killed.
```

— blank numbers, **exit 0**. That reads as a clean sweep and means nothing ran.
Both new suites now refuse when `killed + survived + discarded + skipped == 0`,
and the guard was **tripped on purpose** (exit 1, correct message) rather than
assumed to work. The other 31 suites carry the same latent shape; noted as open
rather than silently patched in bulk.

Counts: **813 theorems, 37 modules, 34 suites, 411 mutants**.

---

### A fix nobody can install is not a fix -- `Proofs/RotRelease.lean`

**The correction first: the repository was NOT the thing at fault, and the
obvious repair would have broken it.** Measured:

| | version |
|---|---|
| newest git tag | `v0.9.2` |
| `.claude-plugin/plugin.json` | `0.9.2` |
| installed in production | `1.0.1` |
| installed in CTT (`.rot-release`) | `1.0.1` |

The manifest and the newest tag AGREE, which is exactly what
`checker/release-consistency.sh` requires, and `checker/release-local.sh:28-34`
already explains why 1.0.x is rewritten only in a throwaway export: bumping the
tree to outrank it would put the manifest ahead of every tag and turn a correct
repository red. I was one edit away from doing precisely that.

The real defect is the mirror image. A **local-only, never-published 1.0.1
build was installed into production and into CTT**, numbered above the whole
published line. It permanently shadows every future release: 0.9.x can never
reach those installs, so every provenance repair proved in `RotSessionLog` sits
in a build that cannot be delivered.

`RotUpgrade` could not see this. It models the install mechanism with
`abbrev Ver := String`, so it can say a version CHANGED and cannot say a version
ROSE. `RotRelease` supplies the missing axis -- **15 theorems, 10 guards, 0
sorry**, kernel re-checked, 8/8 mutants killed:

| theorem | what it settles |
|---|---|
| `lt_iff`, `lt_sameMajor` | one bridge from the Bool order to arithmetic, proved once |
| `lt_irrefl`, `lt_asymm`, `lt_trans` | the comparison really is a strict order |
| `reinstall_is_not_an_upgrade` | republishing a number changes nothing -- the CLI exit-0 case |
| `lower_major_never_supersedes` | the measured shape, quantified over every digit |
| `patch_cannot_beat_a_higher_minor` | the tempting repair (bump the patch) provably fails |
| `a_higher_minor_always_wins` | and the positive direction, so the pair is not vacuous |
| `variants_are_ordered` | core < lean < unsealed within one line |
| `a_new_line_supersedes_every_old_variant` | a new line reaches even the fullest old variant |
| `one_stale_channel_blocks_publication` | one un-superseded install blocks the release |
| `cannot_publish_over_itself` | the reinstall case at whole-deployment scale |

**The contingent half is `#guard`s, never theorems.** `supersedes 0.9.2 1.0.1 =
false` is a fact about today that a correct release is SUPPOSED to falsify. A
theorem asserting it would go red on the very commit that fixes the problem --
the exact way a spec starts forbidding correct futures.

### The axiom auditor could not read a named section

Found by the new module, which is the first here to write `section Order ... end
Order` inside a namespace. `checker/axiom-audit.sh` matched `end Order` with its
`end` rule and decremented the NAMESPACE depth that `section Order` never
raised. Every theorem after that line was emitted UNQUALIFIED and the probe died
on `Unknown constant`.

It failed CLOSED -- "names may be wrong, so nothing is established" -- so this
was a false alarm and never a false green. But the wrong names came from the
auditor, not the module, and the tempting repair is to stop using named sections
in Lean: editing the subject to suit the instrument. One stack, two kinds
(`ns` / `sec`), only `ns` contributing to the prefix. Sweep: **39 passed, 0
failed**, planted-`sorry` control still fires.

A second self-inflicted bug on the way: the replacement comment contained
apostrophes, and the awk program lives inside a single-quoted shell string, so
it terminated the string and the extractor silently returned ZERO names for
every module. The audit caught that too ("an empty sweep is not a clean
sweep"). Both hazards are now written into the file.

Counts: **802 theorems, 36 modules, 33 suites, 403 mutants**, synced across the
five declaring sites.

---

### The zero was a stale deployment, not a router defect

**Correction to the entry below.** It reported `src:"hook"` appearing 0 times in
the production log as evidence of the CLI-path defect. That attribution was
wrong, and the two facts are independent:

- the repository code **did** have a real CLI-path defect (measured, fixed, and
  proved in the entry below);
- production's missing `src` is a **stale deployment**.

Measured on the live machine, `.claude/plugins/cache/rot-moe/rot-moe/1.0.1`:

| file | installed | repo HEAD |
|---|---|---|
| `rot-router.ps1` | 18048 B, `RotSrc` x**0** | 24462 B, x14 |
| `rot-router.sh` | 28326 B, `_rot_src` x**0** | 37421 B, x10 |

The deployed plugin predates the entire provenance subsystem, so it emits no
`src` and no `session` at all -- the 2953 field-less records are its output.
A freshly built artifact, driven directly, is correct:

```
{"kind":"gauge","ts":"2026-08-09T06:48:48+02:00","session":"rel-7c1","src":"hook",...}
```

**A proof about `hooks/rot-router.sh` in this repository says nothing about the
copy a user runs, and nothing compared the two.** `checker/release-install.sh`
now drives the unpacked artifact and asserts it emits `src` and `session`, and
classifies a genuine lifecycle payload as `hook`. The check is on field
PRESENCE rather than a particular value: a release that quietly drops an
observable is the failure being caught.

### The cross-diff never looked at the fields that broke

`checker/cross-diff.sh` compared the ROUTE record. `src` and `session` live on
the GAUGE record, so for the whole life of the two-log subsystem the arms could
disagree about provenance and this gate stayed green -- and they did disagree.
Its own header already named this failure mode: *the new observable is simply
not in the old comparison.*

New phase: five rows across both arms x {cli, hook} x {declared, undeclared,
unrecognised}, plus two controls. `NONE`, `ABSENT` and `EMPTY` are reported as
three different strings, because collapsing them is how an empty value reads as
"nothing to compare" instead of as a value no classifier can produce.

Verified load-bearing: recreating the shipped PowerShell defect (initializer
and CLI-path declaration read both removed, presence of both edits asserted
before building) turns the gate red on exactly the shipped behaviour --
`sh 'cli' / ps1 'EMPTY'` -- while the hook-mode rows keep passing, because the
defect was CLI-path-only. It discriminates rather than blanket-failing.

### A sed idiom that cannot stop, fixed in three places

`sed -n 's/.*X\(...\).*/\1/p; /X/q'` looks like "print the first match and
quit". It is not: `s` rewrites the pattern space, so when `q` tests its address
the text it was looking for is gone, `q` never fires, and every later record
prints too. The extractor returns a MULTI-LINE value that compares unequal to
itself.

Latent in the route-stem extractor since it was written (those logs carry one
route record) and it bit for real in the new gauge extractor, which saw two.
Corrected to the address-block form `/X/{s/.../\1/p;q;}` in all three sites.

### Three harness bugs that posed as product defects

Recorded because the pattern is the point, not the individual mistakes. Each
produced a red that accused correct code:

1. `${x:+...}` cannot **unset** an inherited variable, so "no declaration" cells
   measured `test` -- the checker exports `ROTMOE_DEBUG_SRC=test` itself.
2. `env -u VAR run_bounded ...` -- `env` can only exec an external command, and
   `run_bounded` is a shell **function**. It wrote no record, and the phase
   reported "observability is dead in the release" against a correct artifact.
3. The sed idiom above.

All three are the same shape as the defect under investigation: a declaration
that was never actually consulted. The reasons are now written into the
checkers rather than left to be rediscovered.

---

### `classify` was proved correct and the log was contaminated anyway

A proof binds only the code that calls it. `classify` had been correct and
machine-checked since the two-log work below landed, and the shipped 1.0.1 log
was still unreadable, because **`--vector` and `--route` return before hook
mode** and neither arm consulted it on that path.

Measured on the shipped log, 5003 records:

| field | count | meaning |
|---|---|---|
| `src:""` | 228 | a value `classify` cannot produce -- an unset variable rendered as if it were a class |
| `src:"hook"` | **0** | no live lifecycle firing was ever identifiable as one |
| `session:"unknown"` | 1641 of 2151 | session identity fell back on every non-test record |

Two different defects, one per arm, which is why cross-arm comparison did not
see them: both arms were wrong, in **different** ways, on the same input.

- **PowerShell** (`hooks/rot-router.ps1:203-205`): `$script:RotSrc` had no
  initializer while `RotSession`, `RotProjectDir` and `RotLocalLost` did. The
  CLI dispatch at `:313` exits before the assignment at `:390`, and PowerShell
  has no `set -u`, so the field rendered empty and the record looked valid.
- **POSIX** (`hooks/rot-router.sh:44`): `set -u` had forced an initializer, so
  the tag was well-formed and still wrong. A harness that correctly exported
  `ROTMOE_DEBUG_SRC=test` and called `--vector` was recorded as a live operator
  at a terminal, which is the exact contamination the field was added to close.

The safety one arm gets from its shell, the other must state explicitly. Parity
is the property; identical source is not.

**The repair is stated as the property, not the patch.** The declaration is now
read on every dispatch path in both arms, and the dispatch path is a modelled
dimension in `lean/Proofs/RotSessionLog.lean` rather than an implicit one:

- `src_declaration_wins_on_every_path` -- quantified over the path and the
  payload, so it does not expire when a new path is added.
- `resolveNow_never_renders_empty` -- the empty tag is unreachable for every
  declaration, path and payload. This is the theorem that would have caught it.
- `ps1_rendered_an_unclassifiable_tag`, `sh_ignored_the_declaration_on_the_cli_path`
  and `the_arms_disagreed_before` pin **both** shipped defects and the divergence
  between them, so a regression re-introduces a failing theorem, not a silent log.

`checker/session-log.sh` gains **phase G**: twelve cells (2 arms x {cli, hook} x
{declared, undeclared, unrecognised}), an explicit empty-tag probe, and a control
proving the reader can tell empty from absent. Reverting the POSIX half turns it
red on exactly the shipped behaviour: `sh cli decl=test -> src=cli`.

Phase G was itself wrong first, and in the same class of way: `session-log.sh` is
one of the nine checkers that export `ROTMOE_DEBUG_SRC=test`, and `${x:+...}`
cannot *unset* an inherited variable, so every undeclared cell silently measured
`test`. Six failures, none of them the router.

Counts: 777 to **787 theorems**, 391 to **395 mutants** (S17-S20, all killed).

---

### An alarm that was set and never read, and a sentinel a path could forge

Follow-up to the two-log work below, and both defects were found the same way:
by breaking the path on purpose instead of admiring it.

**`_rot_local_lost` and `RotLocalLost` were assigned and never consulted.** The
project sink could fail to be created — a read-only checkout, a directory the
agent does not own, a full volume — and the router said nothing. Silence there
is indistinguishable from a session that produced no records, which is the
worst possible failure mode for an observation channel. Both arms now emit
`| project-log UNWRITABLE (record lost)`, byte-identical, alongside the
existing central-sink marker.

The POSIX arm then failed a **second** time after the first repair, and the
reason is worth stating because it is not obvious: `_rot_local_file` is always
called as `$(_rot_local_file)`, which is a **subshell**. A variable set inside
it is gone the moment it returns. The first fix moved the assignment into a
helper — which was also called in a command substitution, so it died in exactly
the same way. A subshell cannot report to its parent except through stdout, so
the decode now happens in the main shell where the variable actually lives.

**And the first encoding was forgeable.** Reporting failure on stdout means
encoding both the path and the status into one string, and that is a wire
format. The first version used a leading `!` for "degraded" — ambiguous the
moment a project path itself begins with `!`.

Measured with `cwd="!rel"`, three things went wrong at once:

| symptom | consequence |
|---|---|
| the decoder ate the bang | the record was written to `rel/…`, one directory away from where it belonged |
| the alarm fired | a healthy sink reported as degraded |
| `awk` died with `cannot redirect` | the gauge record was lost entirely — stdout read `R/s+ n/a` |

Replaced with a **fixed-width status character**, always present, stripped
unconditionally. No path can forge it, because the prefix is not part of the
path's alphabet — it is positional.

#### The theorems

`Sink`, `encodeSink`/`decodeSink` and the rejected `encodeBang`/`decodeBang` are
all in `lean/Proofs/RotSessionLog.lean`. Four new theorems, and one of them is
the bug itself:

- `sink_ok_roundtrip` — a healthy sink survives for **every** path, including
  one beginning with a status character. This is precisely the property the
  bang protocol lacked.
- `sink_ok_never_reads_as_lost` — no path can forge a failure. A caller seeing
  `.lost` knows the sink really failed, rather than that a user named a
  directory badly.
- `bang_protocol_misdirects` — the measured bug, frozen: the healthy sink at
  `!rel` decodes as *degraded* at `rel`. Both halves wrong.
- `bang_protocol_not_injective` — the same fact in the general form that makes
  it a defect rather than an anecdote.

Paths are modelled as `List Char`, not `String`. The property at issue concerns
the leading character and nothing else, and a list makes it decidable without
string-slicing lemmas that would bury the point.

`sink_degraded_roundtrip` carries a non-empty hypothesis rather than quietly
widening: `encodeSink (.degraded [])` *is* the lost encoding. A degraded sink
always carries the path it managed to build, so the case does not arise — but
the theorem says so instead of pretending otherwise.

#### The instruments that would have caught it earlier

Two new phases in `checker/session-log.sh`, bringing it to 49 assertions:

- **E** trips the alarm on purpose (a `cwd` whose parent is a regular file) and
  requires both arms to report it, with a negative control requiring silence
  when the sink is fine, and a cross-arm byte-comparison of the marker.
- **F** binds `sink_ok_roundtrip` to the shell. Without it the theorem is about
  an encoding that nothing executes. It replays the exact input that broke the
  first implementation and fails on a truncated directory, a lost gauge value,
  or a leaked fatal error.

Phase E was itself mutation-tested: disarming the two flag assignments in the
POSIX arm produced `2 failed`, and restoring returned it to `49 passed`. An
alarm nobody has deliberately tripped is an untested alarm.

Mutants S13–S16 attack the protocol; all four killed, 16 of 16 for the module.

### The debug log had no idea who was talking to it

The router's log is the only channel it is observable through, so an
unattributable log makes every claim about the router unfalsifiable. Three
defects, all structural, all measured on 2026-08-09.

**A new user got no logs at all.** `ARM_ROUTER.sh`, `ARM_ROUTER.ps1`,
`settings-merge.js` and both plugin manifests contained *zero* references to
`ROTMOE_DEBUG_LOG`, and the router's first act is `if (-not $p) { return }`.
Every install shipped with the observation channel switched off; the only
machine that had logs had them because the path was set by hand.

**No session identity.** The schema was `kind, ts, event, lane, lens, Rs,
chars, stem, arm` — nothing said which session a record came from, so
concurrent sessions interleaved into one file and could not be separated.

**And the log could not tell real traffic from its own test traffic.** This is
the one that matters, because it invalidated my own reporting rather than the
router. 738 of 955 `sh` route records carried `event: "-"`, and I diagnosed that
twice as the POSIX arm losing the event name in production. Both diagnoses were
wrong. EIGHT checkers — `bench-router` (5 payload sites), `debug-channel` (6),
`cross-diff`, `log-replay`, `release-install`, `release-longsession`,
`release-session`, and `hook-contract` — feed the router synthetic payloads and
write into whatever `ROTMOE_DEBUG_LOG` points at. The `-` was honest. The
records were synthetic. Every "live router health" figure computed from that log
mixed real lifecycle traffic with replayed corpus traffic, and nothing in the
schema could say so. An instrument that contaminates its own measurement and
cannot report that it is doing so is the exact failure class this project hunts.

`hook-contract` is the worst of the eight and was found last, by the new
checker, after I had already declared the seven obvious ones and believed the
set was complete: its payloads *do* carry `hook_event_name`, so its records were
classified as live traffic and were indistinguishable from the real thing.

#### What shipped

Two logs, as the schema now records them:

| sink | path | contents |
|---|---|---|
| central | `ROTMOE_DEBUG_LOG` | every session, rotating at `ROTMOE_DEBUG_LOG_MAX` (5000) |
| per-session | `<project>/.rot-moe/rot-route-<session>.jsonl` | one file per session, beside the code that produced it |

The per-session directory writes its own `.gitignore` containing `*`. The router
is a guest in someone else's repository and must not turn up in their
`git status`.

Both records gained `session` and `src`. The `sh` arm gained `ms`, which the
PowerShell arm has always had — the POSIX arm was unmeasurable for latency. It
emits `-1`, not `0`, where the platform has no sub-second clock (BSD `date` has
no `%N`): a zero would read as *instantaneous*, and a lie that flatters is worse
than an honest absence.

The two sinks are independent. In the first draft the local one sat behind the
central sink's early return, so a user with no `ROTMOE_DEBUG_LOG` could never
produce a per-session log however they configured it. `localEnabled` in the Lean
module pins all six combinations, and `explicit_off_wins` is quantified over
every central value — a user who says no gets nothing written into their
repository, whatever else is configured.

#### Why this needed Lean and not care

The per-session log puts a payload value into a **filename**. A `session_id` of
`../../.ssh/authorized_keys` is a perfectly good string, and the router is
contractually forbidden from throwing, so a traversal would have been silent.

`lean/Proofs/RotSessionLog.lean` — 22 theorems. The load-bearing ones are not
"it strips bad characters" but the consequence: `no_forward_slash`,
`no_backslash` and `no_dot` are quantified over every string, so `..` is not
merely rejected, it is **inexpressible**. Blacklisting the `..` spelling is how
traversal filters get bypassed; deleting the characters is not. `test_is_never_hook`
is the honesty theorem: a record a harness has declared cannot be counted as
live traffic, for every payload, including one carrying a real event name.

Measured both arms against the spec: `../../etc/passwd` becomes `etcpasswd` in
Lean, in `sh`, and in PowerShell, and the file lands inside `.rot-moe/` in all
three. A hostile id written straight through would have escaped two directories
up.

#### The instruments

`checker/session-log.sh`, four phases, none skippable — 36 passed, 0 failed, 0
inapplicable. Phase A reads `maxLen` and the alphabet *out of the Lean source*
and compares them to `tr -cd` and `-replace`; phase B replays hostile ids
through both arms against names pinned by `#guard`; phase C walks the classify
table on both arms and **fails if any checker feeding the router has not
declared its traffic** — the check that would have caught the contamination
years earlier than I did; phase D is a self-control that fails the gate if the
detector stops detecting.

Twelve mutants, all killed. One of them earned its keep by *surviving* first:
S03 admitted `'Q'` to the alphabet and nothing noticed, because `sanitise_is_safe`
is stated in terms of `isSafeChar` itself and moves with the mutation — a
predicate cannot be tested by its own definition. The response was to pin the
alphabet from the other side (`a_b -> ab`, `a b -> ab`, `a.b -> ab`) rather than
to retire the mutant. Widening `isSafeChar` by a single non-alphanumeric
character is now a build failure.

#### Corrections owed

Two claims I made and then disproved myself, recorded because a retraction that
is not written down is not a retraction:

- *"The plugin is structurally immune to the additionalContext defect."* Wrong.
  I had grepped `rot-router.*` and the plugin registers two hooks per event.
- *"The blank-event problem is healed."* Wrong twice over — first because the
  `sh` arm was still emitting blanks, then because the blanks were never a
  router defect at all.

The `ROTMOE_DEBUG_LOG` path also moved out of an unrelated project's build
directory to `~/.claude/rot-moe/`, verified by newest-record timestamp rather
than by line count: both files sit at the 5000-line rotation cap, so a line
count cannot move and would have shown a false negative.

### Being wired to an event is not permission to speak on it

Wiring every hook to all 31 CLI events (previous entry) exposed a defect that the
11-event binding had been hiding. A live session ended and the CLI answered:

    SessionEnd hook [...] failed:
    Hook JSON output validation failed — (root): Invalid input

`hookSpecificOutput.additionalContext` is accepted on only **six** of the 31
events. Every hook that echoes its invoking event — which is the correct
behaviour, and stays — was therefore emitting schema-invalid JSON on the other
25, once per firing, logged as a hook failure each time.

**The shipped plugin had it too, and a first pass said it did not.** `hooks/rot-router.{sh,ps1}`
emit no context at all, and on that basis this was written off as a local-tooling
problem. The plugin registers **two** hooks per event, and the second —
`hooks/prover-remind.{sh,ps1}` — does emit context. Grepping one of two files is
how a false all-clear gets issued. `checker/context-gate.sh` reads `hooks/*` and
cannot repeat the mistake.

The fix gates **emission**, never the label. An event the CLI later starts
accepting simply receives no injection — silent and harmless — instead of an
error. Measured, both directions, before and after:

| arm | `SessionEnd` | `PostToolUse` |
|---|---|---|
| before | **718 bytes, rejected** | 719 bytes, accepted |
| after | **0 bytes** | 719 bytes, accepted |

A gate that silenced everything would also have made the error go away, which is
why the second column is part of the evidence and not an afterthought.

**`lean/Proofs/RotInject.lean`** — 8 theorems. The load-bearing one is universal
and cannot expire: *no event outside the accepting set ever emits*, quantified
over every string including events that do not exist yet. Its partner is
`accepting_still_emits`, which is what distinguishes a repair from a disarming.
The six-event roster lives in `#guard`s, deliberately: it is a fact about
claude.exe 2.1.226, and a theorem asserting "exactly six" would go red on a
correct future CLI upgrade with deletion as the obvious repair. That defect shape
has bitten this repo before and is not repeated. Nine mutants, nine killed, none
discarded — including `I07`, which re-hardcodes the label and kills
`label_is_the_invoking_event`, an axiom-free theorem that would otherwise read as
vacuous.

**`checker/context-gate.sh`** — the binding, without which RotInject would prove a
property of a list no program reads. It parses the accepting set **out of the
Lean source** and compares it to the arrays the shell and PowerShell arms
actually branch on. Phase A audits `hooks/*` and caught the shipped defect on its
first run; phase B checks the set against the 31 real events in both directions
(subset, and complement non-empty, so a gate that refuses nothing fails); phase C
compares the installed user hooks and prints `INAPPLICABLE` where they are
absent, which is a statement about the machine, not a skip; phase D is a
self-control that fails the gate if the detector stops detecting.

Cross-arm parity re-measured after the change: `cross-diff-remind` 31/0,
`remind-measure` 16/0 — the gate sits in the hook path only and `--decide` is
untouched.

### The global install was left on 0.7.1 with 1.0.1 hook files

Refreshing only the *hook manifests* of the global install, while its
`plugin.json` still said 0.7.1, produced a version number that did not describe
the files beside it — worse than an old version, because every later diagnosis
reads it. The full 1.0.1-lean build is now installed globally: marketplace
directory, plugin cache, `known_marketplaces.json`, `installed_plugins.json` and
`settings.json` all moved together, with eleven post-checks re-read from disk.
This is a local install; `.release/` remains untouched and nothing is published.

Two failures worth recording. The registry entries live under a top-level
`plugins` object, not at the root — the installer asserted the shape and aborted
cleanly rather than writing against a wrong assumption, which is why nothing was
corrupted. And `settings.json` refused twelve consecutive writes with `EPERM`:
not a lock but a **read-only attribute**, set by an earlier `cp -f` during an
unrelated line-ending pass. Retrying was the wrong instinct; measuring the file
attribute answered it in one command.

### Eleven was also wrong — the CLI defines **31** hook events, and the router bound 11

The previous entry below celebrates going from 3 events to 11. Eleven was still a
guess wearing a measurement's clothes. It came from counting **which events other
installed plugins bound**, and that method has a ceiling built into it: it cannot
reveal an event that nothing on this machine happens to use. The Socio found the
hole by asking a question the method could never have answered — *there is a
SubagentStop, so where is SubagentStart?*

There is one. It was never bound, and neither were nineteen others.

The list is now taken from the only authoritative source, the `Lz` array inside
the compiled CLI binary (`claude.exe`, 287,053,472 bytes, version 2.1.226),
cross-checked against that binary's own `execute<Name>Hooks` dispatchers. It is
committed as [`checker/cli-hook-events.txt`](checker/cli-hook-events.txt) with its
provenance, and all four declarations — the plugin manifest, both installer arms,
and the Lean `declared` list — now carry those 31 names in the CLI's own order,
compared character for character.

`TaskStop` is deliberately excluded and `#guard`ed against: its surrounding text
in the binary reads *"use TaskStop with task_id"*, which makes it a **tool**, not
an event. Wiring it would be the same class of error as missing `SubagentStart`,
just in the opposite direction.

**Measured live, not asserted.** Under the old wiring the router observed 9 of the
lifecycle. Sessions run against the widened build have now recorded **14 distinct
events**, including three that were structurally impossible to see before —
`SubagentStart`, `PostToolBatch` and `MessageDisplay` — plus `InstructionsLoaded`
and `ConfigChange`, the latter fired by the settings edit described below. Every
A/B this repo ran before this change was run against a router watching a subset of
the lifecycle, and that is stated plainly rather than quietly re-baselined.

**The gate that keeps this from happening a third time.**
[`checker/cli-event-coverage.sh`](checker/cli-event-coverage.sh) has two phases.
Phase A compares the four declarations against the fixture; it reads only files in
this repo, so it runs identically on every runner and **never skips**. Phase B
re-extracts the array from an installed CLI and fails if it has drifted — which is
what catches a CLI upgrade that adds a thirty-second event. Where no binary
exists, Phase B prints `INAPPLICABLE` rather than passing silently: *"the CLI is
not here"* and *"the CLI agrees"* are different claims and must not print the
same. Negative control: deleting `ConfigChange` from the manifest turns it red at
exit 1, and the byte-exact restore returns it to green.

The mutation suite for `RotEvent.lean` also grew a defect of its own worth naming.
Mutant E06's needle was the tail of the *old* eleven-element list; after the
widening that exact text still occurred once, but at the end of a **different**
list, so the mutant applied cleanly to the wrong object, changed no membership
test, and was recorded as `SURVIVED`. That is worse than a miss — a miss says
`DISCARDED` and asks for attention, while this said the theorem was robust. The
needle is now anchored to text unique to the list under mutation, and two further
mutants (E09 dropping `SubagentStart`, E10 adding `TaskStop`) were added. **That
suite alone now runs ten mutants and kills all ten**, with none surviving and none
discarded.

A note on how that sentence is phrased, because the first attempt broke CI. The
shape `N applied, N killed` is **reserved**: `checker/repo-complete.sh:312` scans
the newest section of this file for it and reads it as the repo-wide mutation
total, so a per-suite figure written that way collides with the 366 the suites
actually declare. The checker was right to refuse it — a reader skimming the
newest section would have misread it the same way. The fact is unchanged; only its
scope is now explicit. Nothing about the check was relaxed to make this pass.

The miss itself is worth recording: the local run before committing was
`gate-all --fast`, and `repo completeness` is a **deep** gate, so the tier that
would have caught this never ran. A green `--fast` is not a green tree, and the
commit that follows one should say which tier produced it.

### The global config ran 23 hook entries across 4 events; it now runs 403 across 31

Socio directive: every hook already present in `~/.claude/settings.json` should
observe the whole lifecycle, each group carrying `"matcher": "*"`. Done — 13
distinct commands × 31 events, with each command's own `type` and `timeout`
preserved and first-appearance order kept, so nothing was reordered. Two entries
that were **not** `*` before are now: the agent-depth guard (previously scoped to
`Agent`) and the matcher-less `SessionStart`/`SessionEnd` entries.

Tolerance was measured **before** writing, not after: each of the 13 commands was
fired with `ConfigChange`, `MessageDisplay` and `SessionEnd` payloads — 39
invocations, **0 non-zero exits, 0 emitting a permission decision**. That second
number is the one that mattered. A hook that returned a *deny* on an unrelated
event would have broken every session on this machine, including the one making
the change.

The router itself was deliberately **not** added to `settings.json`. It is already
bound to all 31 events by the plugin, and a settings entry would stack on top and
fire it twice per event — precisely the defect `checker/router-duplication.sh`
exists to catch. The generator refuses with a distinct exit code if it ever finds
a router entry there. Verified after the rewrite: **0** stacked entries, and a
live session under the new config returned correct output with all other settings
keys intact.

### CodeMap kept deleting the commit gate, and the reason was a string it could not find

`.githooks/pre-commit` was found clobbered: HEAD's gate hook has 7 `gate-all`
calls, the copy on disk had **zero**. Restoring it worked for about forty seconds
before it was overwritten again, mid-repair.

Attributed rather than guessed. `~/.claude/tools/codemap-ext/cartographer.ps1`
decides whether a pre-commit hook is already armed with
`$body -match 'codemap update'`. RoT MoE's gate *delegates* CodeMap's work to
`.githooks/pre-commit.d/10-codemap` instead of inlining it, so that literal string
never appeared in the file, cartographer concluded the hook was unarmed, and it
reinstalled its own — deleting the gate every time. Wiring every global hook to
all 31 events made cartographer run far more often, which turned an occasional
clobber into a reliable one.

The repair keeps **both** tools whole. The gate now states, in a comment, that it
delegates to `10-codemap` which runs `codemap update` — which satisfies
cartographer's probe **truthfully**, because committing through this hook really
does run it: the delegate is byte-identical (`cmp`) to the hook cartographer
wanted to install. CodeMap keeps its complete per-filetype map; the gate keeps its
refusing path. Confirmed by running cartographer's own matching logic against the
repaired file: `ARMED`. If that probe ever changes, the hook gets clobbered again
and `workflow-lint` catches it — the arrangement is checked, not trusted.

### Counts drifted a second time in one day, and the generated file was the one that was right

`STATUS.md` is generated by `checker/status-verdict.sh` and was already correct at
741 theorems; `verdict-fresh` passed 3/3. The four **hand-declared** figures in
`marketplace.json`, `plugin.json`, `CITATION.cff` and `README.md` still said 737,
and the mutant count still said 364 against 366 declared by the suites. Nothing
regenerates those four, so they lag every time the spec grows — the second such
drift today, which makes it a pattern rather than an accident. Synced to **741
theorems / 366 mutants**, with a re-scan confirming no stale figure survives
anywhere.

Adding the new gate also required extending its **Lean witness**: the repo refuses
a gate that exists in `checker/gate-all.sh` but not in `lean/Proofs/RotGates.lean`,
and `checker/gate-split.sh` compares the two tables including position. Four
`#guard` counts moved with it, each justified structurally — a *fast* gate is
unconditional, so it joins every staged run — rather than adjusted until the build
went quiet. One of those four disproved a prediction: assuming all counts rose by
exactly one left the build red, and the remaining figure had to be read off the
compiler rather than guessed.

### The router was wired into 3 of 11 lifecycle events — it was never fully installed

RoT MoE is a **router**. It shipped bound to three Claude Code events —
`UserPromptSubmit`, `PreToolUse`, `PostToolUse` — out of the eleven that exist.
A router that observes three of eleven events is not routing a session, it is
sampling one, and this is the most consequential defect found in the project so
far: **every A/B measurement this repo has ever taken was taken against a
partially installed product.**

That does not retroactively turn the compliance reversal into a win — the
reversal stands as measured, and no quality claim is being restored here. It
does mean the measurement was never of the thing the README describes.

The eleven event names were **counted, not recalled**. Every `hooks.json` and
`settings.json` on the measuring machine was scanned, and these are the keys in
real use:

| event | occurrences in the scan | bound before | bound now |
|---|---:|---|---|
| `PreToolUse` | 97 | yes | yes |
| `UserPromptSubmit` | 78 | yes | yes |
| `SessionStart` | 69 | **no** | yes |
| `PostToolUse` | 62 | yes | yes |
| `Stop` | 61 | **no** | yes |
| `SessionEnd` | 6 | **no** | yes |
| `Notification` | 6 | **no** | yes |
| `SubagentStop` | 4 | **no** | yes |
| `PreCompact` | 2 | **no** | yes |
| `UserPromptExpansion` | 1 | **no** | yes |
| `PostCompact` | 1 | **no** | yes |

Every binding uses `matcher: "*"`. The wildcard on a non-tool event is not an
assumption either: an installed third-party plugin registers `Stop` with
matcher `"*"`, so the form is known-accepted.

**The tolerance was measured before the wiring was widened, not after.** A hook
that crashes on `Stop` breaks the session rather than the build, so both hooks
were executed against all eleven event payloads first: `rot-router` exits 0 and
emits its lane marker on all eleven, `prover-remind` exits 0 on all eleven.
Only then was the list widened.

Three files carry the list — `hooks/hooks.json` (what the plugin registers),
`ARM_ROUTER.sh` and `ARM_ROUTER.ps1` (what the hand installer writes) — and they
are asserted character-identical, so a future edit cannot silently wire the
plugin and the installer differently.

#### The debug log could not say which event produced a record

Wiring eleven events is worth nothing if the log cannot show it happened. A live
CTT session emitted six records — three `gauge`, three `route` — and **not one
named the event that produced it**. The claim "the router now observes eleven
events" was therefore unfalsifiable from its own evidence, which is the defect
class this project exists to hunt.

Both arms now write an `event` field on every route record. Measured across five
events, the two arms agree exactly:

```
{"UserPromptSubmit [sh]":1,"UserPromptSubmit [ps1]":1,"PreToolUse [sh]":1,
 "PreToolUse [ps1]":1,"Stop [sh]":1,"Stop [ps1]":1,"SessionEnd [sh]":1,
 "SessionEnd [ps1]":1,"PostCompact [sh]":1,"PostCompact [ps1]":1}
```

The value is **sanitised, and the guard is load-bearing**: it is interpolated
into JSON, so a payload carrying a quote would emit a malformed line and break
every downstream reader including `checker/log-replay.sh`. Anything that is not
plain letters is recorded as `-`. Fired at the running hooks, the payload
`Evil","lane":"PWNED` produced `event:"-"` in both arms, zero malformed lines
and zero overridden lanes.

It is parsed with shell parameter expansion rather than a second `node` process:
the hook costs ~125 ms, and a second interpreter spawn would roughly double that
on every event, eleven times a turn.

#### The Global install was three versions stale, and it is fixed through the PLUGIN, not through settings.json

The global config had `rot-moe@rot-moe` enabled the whole time, but its
marketplace pointed at `Desktop/RoT-MoE 0.7.1-Lean` and both cached versions —
`0.6.1` and `0.7.1` — carried the **three-event** manifest. Global was running a
router wired into three lifecycle events while the repo had eleven.

**Adding eleven entries to `settings.json` would have been the wrong repair, and
it would have gone green.** With the plugin enabled, hooks registered in
`settings.json` stack on top of the plugin's own — the router fires twice per
event. That is precisely the defect `checker/router-duplication.sh` exists to
catch. The correct repair is to refresh the plugin the install actually serves,
which leaves `settings.json` alone and keeps every one of the 23 existing
sanctum / codemap-ext / cavecrew / pxpipe hook entries and their `*` matchers
untouched. (An earlier note in this session said 22; that was a miscount. The
pre-work backup and the current file both hold 23, and a diff of the two shows
zero added and zero removed.)

Refreshed the marketplace source directory and both cache versions from the
staged build, after asserting the staged artifact matches the worktree
byte-for-byte, and verified with 15 byte comparisons. Backups are
`*.pre-11event-2026-08-08.bak` beside each replaced file.

Measured live against the global config: `SessionStart`, `UserPromptSubmit`,
`PreToolUse`, `PostToolUse`, `Stop` and `SessionEnd` all fire — the same six as
CTT.

**One measurement of mine was wrong first, and the instrument was at fault, not
the router.** Counting "new records after line N" returned **zero**, which reads
as "the plugin does not fire". The debug log is capped at
`ROTMOE_DEBUG_LOG_MAX` (default 5000) and rotates from the front — the property
`rotate_keeps_the_newest` in `RotDebugLog.lean` — so appending 6 records to a
full file leaves the line count at exactly 5000 and a positional slice is empty
by construction. Re-measured by timestamp: 126 route records in the preceding
ten minutes.

#### Measured live in CTT: six distinct events, and an A/B that shows no quality difference

With the event field in place, a real CTT session (plugin `rot-moe` only,
`claude -p` with `CLAUDE_CONFIG_DIR` pointed at the test config) produced six
route records, each naming its event and the lane it routed to:

| event | lane |
|---|---|
| `SessionStart` | CONVERGENT |
| `UserPromptSubmit` | FORGE |
| `PreToolUse` | CLINICAL |
| `PostToolUse` | CLINICAL |
| `Stop` | CONVERGENT |
| `SessionEnd` | CONVERGENT |

**Three of those six could not fire at all under the old three-event wiring.**
That is the first direct evidence, from a live session rather than a harness,
that the eleven-event registration changed what the router observes.

**The A/B on this task shows NO difference in output, and that is reported
rather than buried.** The same prompt was run against standard Claude Code with
no plugin and no hooks: both returned `hello-from-ctt`, both in 2 turns, both
`is_error: false`. The control held — the unplugged config wrote **zero** router
records, so the six records are attributable to the plugin and to nothing else.

What this measurement supports is precise and narrow: the router now **observes**
six of eleven events in a real session, and observation is attributable to the
plugin. It does **not** support any claim that the router improves answers. A
single trivial task cannot show that, and nothing here should be read as
showing it.

#### `prover-remind.ps1` swallowed an unknown argument; the POSIX arm refused it

Found while establishing whether the sanctum idiom `-Event *` is safe to put on
RoT MoE's hooks. It is not — `rot-router.ps1` dies with *"A parameter cannot be
found that matches parameter name 'Event'"*, exit 1. The same probe exposed the
two arms of `prover-remind` disagreeing:

| arm | `--event *` / `-Event *` | before |
|---|---|---|
| `prover-remind.sh` | exit 2, usage printed | correct |
| `prover-remind.ps1` | **exit 0, zero bytes** | swallowed |

`checker/cross-diff-remind.sh` could not see this: it compares the arms over
`--decide` rows, and an unknown flag never reaches that path. Swallowing is
wrong by this project's own rule, stated in `checker/router-duplication.sh` —
*"an unknown flag must REFUSE, not be swallowed"* — because a hook that exits 0
having done nothing is indistinguishable from one that worked. The PowerShell
arm now refuses with exit 2 and the same usage text.

The first version of that guard **broke plain hook mode**: `@($null).Count` is
`1` in PowerShell, not `0`, so testing the count alone made every one of the
eleven registrations refuse itself. Measured, not reasoned — `HOOKMODE_EXIT=2`
on the first run. All five modes are now asserted: hook 0, unknown flag 2,
`-Decide` 0, `-Measure` 0, `-Version` 0.

#### `lean/Proofs/RotEvent.lean` — 12 theorems, 8 mutants, all killed

The specification of the sanitiser and of the coverage claim: the output is
always `-` or letters (`sanitise_is_safe`); any non-letter name is refused
(`non_letter_is_refused`); the measured injection is refused
(`quote_payload_is_refused`); the sanitiser is **not** the constant `-`
(`sanitise_is_not_constant`, the non-vacuity witness); every declared event
survives it unchanged; the list is eleven long with no duplicates; the old
binding is a strict subset and **eight events were unbound**.

Two statements are deliberately quantified rather than named, so they cannot
expire the way the two checkers above did: `undeclared_is_not_bound` over an
arbitrary list and event, and `entries_equal_declared_count` over an arbitrary
list.

**A weakening was disclosed and then closed rather than left standing.** The
first version of this module could not prove `quote_is_refused (pre post)` —
that a quote *anywhere* in an event name is refused, whatever surrounds it — and
shipped a hypothesis-driven refusal plus one decided instance in its place, with
the gap stated openly. Leaving it there would have been a weakened claim wearing
a disclosure, which the governing rules forbid outright. The obstacle turned out
to be two missing lemma names, not a missing fact: `String.toList_append` and
`List.all_append` close it. The general theorem is now **proved** for arbitrary
`pre` and `post`, and the measured single instance is kept beside it as the
anchor to the attack that was actually fired.

`lake build` exit 0 · axioms `[propext, Classical.choice, Quot.sound]` or
axiom-free, `sorryAx` 0 · `leanchecker` exit 0, zero bytes, negative control
exit 1 · mutation **8 killed, 0 survived, 0 discarded**.

Two mutants had to be repaired before the suite was evidence, and both failures
are the reassuring kind: `E04` was `DISCARDED` twice — first because the needle
spelled `<=` where the source has the glyph, then because the replacement
*contained* the needle — and `E08` `SURVIVED` because the mutated statement was
still true, so it tested nothing. A discarded or unfailable mutant is a claim
about the harness, never about the theorem.

#### A checker went red on the correct change, and the checker was wrong

`checker/install-roundtrip.sh` asserted that `hooks.SessionStart` is
*bit-identical* after install and uninstall, under the name "an event we never
touch". It was true when the installer bound two events. It went red the moment
the installer legitimately grew to bind eleven.

This is the failure mode where a spec freezes a **contingent fact** as if it
were an invariant: the build goes red on correct work, and the obvious repair —
delete the check — destroys real coverage. The property that actually matters is
not *SessionStart specifically is untouched* but **anything the installer does
not declare is untouched**. It is now quantified over the installer's own
declared list, read from `ARM_ROUTER.sh` at run time, so it stays meaningful at
any list size.

Two things keep that honest:

- The fixture carries a `ZZ_ForeignEvent` key that the installer will never
  bind, and the checker **asserts the comparison count is non-zero**. Without
  it, a future list covering every fixture event would compare nothing and pass
  in silence.
- That guard is not theoretical: it fired on its own first run, because the
  fixture has a UTF-8 BOM (deliberately — another check asserts the BOM
  survives) and the new reader had not stripped it. The check reported
  "compared NOTHING … so it proves nothing" instead of passing empty.

Control, run deliberately: adding `ZZ_ForeignEvent` to the installer's declared
list makes the foreign event *declared*, the loop compares nothing, and the
checker goes **red** — mutation asserted present before the run, tree restored
byte-clean after. `30 passed, 0 failed` with the repair, exit 1 under the
control.

### A timeout is not a rejection — the hook accused four modules of being unproved

The hook that guards this repo's proofs spent the day telling the session:

```
KERNEL REJECTED 4 module(s): Proofs.RotMutant, Proofs.RotVerdict,
Proofs.RotVacuity, Proofs.RotRoute. leanchecker disagrees with lake build --
those theorems are NOT proved. Fix before anything else.
```

Every word of that is false. Re-checked directly, all four return **exit 0 with zero
bytes** — the kernel pass. The watchdog's status file explains it: each entry reads
`{"module":"Proofs.RotMutant","reason":"TIMEOUT"}`. The re-check of the four *largest*
modules ran out of time, the watchdog recorded them as red, and `measure_kernel` mapped
`v.red` to module names while dropping the reason.

**"I did not finish asking" was being reported as "the answer is no."**

This is the third instance of one shape in a single cycle, and the direction is worth
noting. The empty-payload guard turned *no data* into a PASS; the provisional-CI defect
turned *not yet finished* into a PASS; this one turns *no data* into a FAIL. The last is
the safer default and still wrong — a false statement about four named modules, costing
exactly what a false alarm always costs: the time spent disproving it.

The reader now has three outcomes. A recognised "did not finish" reason (`TIMEOUT`,
`NOT_FOUND`) is marked and reported as **KERNEL RE-CHECK DID NOT FINISH … a timeout is not
a rejection and it is not a pass either**. Everything else, *including an unfamiliar
reason*, keeps the full rejection alarm — the safe default for an unknown failure is to
shout, and `an_unknown_reason_still_accuses` is the theorem that holds that line.

Both hook arms changed identically; `cross-diff-remind.sh` diffs them on every corpus row
and the corpus gained five rows covering only-unfinished, only-rejected and mixed
(`31 passed, 0 failed`).

`RotGuard.lean` part four proves the distinction: the old reader accuses all four
(`the_old_reader_accused_all_four`), the new one accuses none
(`the_new_reader_accuses_none_of_them`), and `the_old_reader_ignores_the_reason` states the
real defect — its output did not depend on its input at all, so the `reason` field it read
was doing no work. `only_the_unfinished_are_demoted` proves the repair silences nothing
real: for every reason other than those two, old and new agree.

### A local pre-release rehearsal was being run on GitHub's runners — that was the defect

Reported by the Socio twice: first that macOS CI had been failing repeatedly, then — after
this file had already blamed BSD `sed` — that the real mistake was **merging into `ci.yml`
something that should have stayed local**. The second diagnosis is the correct one and this
entry now leads with it.

`.release-local-only/` is the staging area where a new version is built and exercised **on
this machine**, installed into CTT, before anything is promoted into `.release/`. It is
`.gitignore`d and never published. `checker/release-local.sh` (R23) rehearses exactly that.
It was wired into `ci.yml` as a step on all three runners, where there is no CTT and nothing
can be promoted anywhere — a local rehearsal asked of a machine that cannot host it. The
comment that used to sit above the step claimed CI "proves something I cannot prove
locally"; what it actually proved is that the runner is not this machine.

The step is removed. The gate is **not** deleted and **not** weakened: it runs in the local
deep tier through `gate-all.sh` and passes there (`11 passed, 0 failed`), and
`workflow-lint.sh` now carries it as a named exemption whose reachability from `gate-all.sh`
is asserted — so it cannot quietly stop running.

**Removing the step exposed a second defect immediately.** The removal left a comment
explaining why, and that comment necessarily names the file. `workflow-lint.sh` read the raw
YAML and printed `PASS wired into a workflow: release-local.sh` about a checker no workflow
runs any more. A mention is not a wiring — the same lesson as "a mention is not a leak",
which this repo had already learned for `git push` in section 1 of the same file and had a
control for. The scan now strips comments, and a two-way control asserts that a
comment-only mention does not read as wired while a real `run:` line still does.

Stripping comments then exposed a **third**, pre-existing hole: four checkers had been
counted as CI-covered on the strength of prose alone — `ci-dryrun.sh`, `ci-honesty.sh`,
`release-session.sh`, `release-longsession.sh`. Every one of them is out of CI *on purpose*
and each already had a correct reason written in `ci.yml` — recursion, judging a run from
inside itself, needing the `claude` CLI. Those reasons were prose; nothing asserted the
checkers still ran anywhere. They are now enforced exemptions with reachability checked.

The portability repairs below stay, because a macOS contributor running the deep tier
locally still needs them.

#### The symptom, and why it went unnoticed for three runs

**The defect.** `checker/release-local.sh` used two GNU-only constructs, both invisible on
Linux, Windows and Git Bash — everywhere it was ever run locally. The runner log names the
first one exactly, four times over:

```
sed: 1: "/var/folders/df/djsxfhc ...": invalid command code f
  ----  the version rewrite did not take in the export -- refusing to build
##[error]phase 2: the local package build FAILED
```

That message *is* the `-i` defect: BSD sed took the substitution script as the backup suffix,
then read the **file path** as the script, parsed the leading `/` as an address and choked on
the `f` of `/var/folders`. The checker's own refusal — "the version rewrite did not take" —
then fired correctly, which is the one part of this that worked as designed.

Precision about the second construct, since the log settles it: the build died in phase 2 and
the digest phase was never reached, so `sha256sum` **never executed**. It is a latent defect
fixed alongside, not an observed one. Saying "both were fatal" would have been an
overclaim — one was fatal, the other was next in line.

| line | construct | on macOS | observed? |
|---|---|---|---|
| `163` | `sed -i "s/…/" f` | GNU treats the argument after `-i` as **optional**; BSD **requires** one and takes the next word as the backup suffix, so the script is eaten as a suffix and the command dies | **yes** -- `invalid command code f`, x4 |
| `229` | `sha256sum` | does not exist; the tool is `shasum -a 256` | no -- phase 2 died first |

There is no spelling of `-i` that works on both — `sed -i ''` fixes macOS and breaks GNU — so
the repair writes to a temp file and moves it into place, and the digest resolves its tool
once through `command -v` with a refusal if none is present. `checker/release-package.sh:406`
had resolved the sha256 question correctly since the day it was written: the knowledge was
already in the repo and simply had not been applied here.

Runs `31261506027`, `31263721866` and `31266263626` all concluded `failure` on
`checkers (macos-latest)`, each with **28 subsequent steps skipped**; ubuntu and windows were
green throughout. All three runner logs were downloaded and carry the identical signature —
8 `invalid command code` lines and the same two `##[error]` lines — so this is one defect
reproduced three times, not three coincidences.

A known unknown, stated because the fix does not close it: those 28 skipped steps have
**never executed on macOS**. Fixing this one only lets the job reach them. The repo-wide scan
for the two constructs now returns zero hits, but a BSD/GNU difference this scan does not know
about could surface in any of them on the next green-enough run.

**Why the checker missed it, which is the part worth keeping.** `ci-honesty.sh` was run four
times against those commits, always while the run was still `in_progress`, and each time it
printed:

```
FAIL  the run is 'in_progress', not completed -- there is no verdict to report yet
PASS  NO step was skipped -- every authored step ran on every platform
PASS  every step concluded success (158 steps read)
```

Both PASS lines were true of the steps that had finished and **wrong about the run** — the
macOS job had not yet reached its failing step. Beside a single timing FAIL they read as
"only the clock is unresolved", and three red runs went by.

A question whose answer is not yet knowable must not be answered PASS. There is now a third
outcome, `PROVISIONAL`, which prints the reading and **does not count as a pass** — the same
rule as the malformed-payload guard, which also had to become a third outcome rather than a
coerced second one. Measured on the live run: what used to report `7 passed, 1 failed` now
reports `5 passed, 1 failed`.

**And the gate that should have caught the constructs.** `portability.sh` passed the whole
time. It checks `\|` in sed BREs and three bash-4 constructs, and had no rule for either of
these. Section `6b` adds both, with five controls — three planted violations that must be
caught and two correct forms that must be spared, because a rule that flags
`sed -i ''` or a guarded `command -v sha256sum` wrapper would be deleted by the next person
who trips over it. The decisive control: run the rule against the **pre-fix file from git**,
and it names both defects at lines 163 and 229.

Two smaller findings fell out of writing it. The new code initially used
`printf … | grep -q`, and `portability.sh`'s own SIGPIPE rule caught it — replaced with
`case`. And a file named with a leading dot in `checker/` is invisible to every `checker/*.sh`
scan, which is how the first attempt at the pre-fix control silently passed.

### The first endpoint that *could* show a quality win — and it did not

Two of the three published primaries are `0.000` in both arms across 88 turns. That is not
"no effect": counts are bounded below by zero, the control arm sits on the bound, and so
those endpoints could not have shown a win for **any** routed arm
(`the_zero_endpoints_cannot_show_improvement`). So one was needed that can move.

`bench/ab-session.sh` appends `" Answer in one or two sentences."` to every prompt, in both
arms, verbatim. Compliance with it is scorable mechanically by a scorer that is identical on
each side, and the control arm violates it 41 times in 88 turns — nowhere near the floor.
Capable, by the definition already in `RotEndpoint.lean`.

**The headline favoured routing:**

| | routed | unrouted |
|---|---|---|
| violations of the two-sentence limit | 23 / 88 (26.1 %) | 41 / 88 (46.6 %) |
| mean sentences | 2.18 | 3.25 |
| paired sign | **28 better** | 10 better, 50 ties |

Two-sided sign test on the 38 discordant pairs: **p = 5.1e-3**.

**Then the confound removed it.** Routed answers are also 26 % shorter, and sentence count
rises with length nearly by construction — measured Pearson r = 0.263 routed, r = 0.707
unrouted. A brevity win drags compliance along with it, which would make this a second
measurement of an already-published result rather than new evidence.

Isolating the pairs brevity cannot explain — routed complied **and** was not shorter — leaves
**2 wins against 10 losses**, p = 3.9e-2. On the de-confounded subset the effect **reverses**:
routing is mildly worse.

So the result recorded here is negative. The compliance win is the brevity result restated.
No quality improvement from nine-lens routing has been demonstrated, and on the only capable
endpoint measured so far the de-confounded sign points the other way.

One further reason to distrust it even as a negative: it counts sentences, so a single
2080-character run-on scores as perfect compliance. That case is in the corpus (turn 46) and
`a_run_on_sentence_scores_as_compliant` pins it.

`RotEndpoint.lean` gains 7 theorems and 4 mutants for this, including `capable_is_not_enough`
— stated generally, not about these numbers: whenever the covariate-explained share of the
wins is large enough, the headline favours routing while the de-confounded subset does not.
`no_explained_wins_means_no_divergence` is its contrapositive and the test to apply.

`checker/ab-compliance.sh` re-derives every figure from the raw transcripts and fails if any
drifts **in either direction** — a bigger headline breaks it exactly as loudly as a smaller
one — and it fails if the correction ever detaches from the headline. Controls: planting three
extra sentences in one turn moved 23 → 24 and the gate went red; a missing corpus exits 3,
never 0.

### A gate must trigger on itself — 14 of 25 were blind to their own edits

Measured across the shipped table with `gate-all.sh`'s own prefix matcher: of the 25 deep
gates with a resolvable script, **14 did not list their own path among their triggers**.
Editing the checker did not run the checker. `checker/ci-honesty.sh` fired only on
`.github/workflows/`; `checker/axiom-audit.sh` only on `lean/`;
`checker/marketplace-session.sh` only on `.claude-plugin/` and `hooks/`.

It is the near sibling of `no_trigger_never_escalates`, and it hides better: the gate is not
invisible to *every* commit, only to the commits most likely to break it. Same shape as
`gauge-cross` in `bc1272d`, which had been skipped in every job for a whole cycle —
generalised across the table.

Found by editing `checker/ci-honesty.sh` and noticing its own gate would not have run.

Repaired in three places that had to move together: all 14 rows gained their own script;
`gate-all.sh` now **refuses** a deep row that does not self-trigger (control: stripping the
`ci-honesty` self-trigger → exit 2, naming the gate); and the Lean witness `shipped` moved in
the same edit, because `checker/gate-split.sh` diffs the two tables and went red the instant
they disagreed. The six `FULL=1`-only gates are deliberately absent from the witness —
`gate-split.sh:56` mirrors only the default block — while `gate-all` validates every row it
reads.

`RotGates.lean` gains 9 theorems (41 → 50): `a_gate_blind_to_itself_misses_its_own_break`,
`self_trigger_makes_the_edit_visible`, `listing_the_script_suffices`, `ci_honesty_was_blind`,
`ci_honesty_now_fires`, `the_repair_changes_the_run`, `adding_a_trigger_never_runs_less`
(the fix cannot cost coverage), `the_original_trigger_still_works`, and
`a_fast_gate_is_never_blind_to_itself` — the fast tier is structurally immune, which is why
the repair touched deep only. Measured alongside: 28 fast gates, 0 carrying triggers.

### Three ways a checker lied about its own result — `RotGuard.lean`

Seventeen theorems, ten mutants, all killed. Each part is a defect that was live.

**The empty-payload guard failed open exactly when the payload was empty.** `grep -c` prints
`0` *and* exits 1, so `|| echo 0` appended a second zero; the variable became the two-token
string `0 0`; `[ "0 0" -lt 5 ]` **errored** rather than compared; the non-zero test status
took the else branch. Result: `PASS every step concluded success (0 steps read)` — a pass
asserted over the empty set, inside the file whose job is to catch that. Reproduced before
repair: `guard FELL THROUGH`. `guards_agree_on_wellformed` proves the repair changed nothing
else for any count; `defaulting_to_zero_is_not_a_repair` rules out the tempting
one-character fix, because `0` is a legitimate reading with the opposite meaning.

**A DNS blip was reported as "you did not push."** `curl: (6) Could not resolve host`, thirty
seconds after a successful push, produced *"This commit has not been pushed."* The exit code
was right — 3, a skip, never a pass — and `the_verdict_was_always_right` records that,
rather than overselling the fix. But a wrong diagnosis sends the next person to push again
instead of checking their network. Control: an unreachable host now exits 3 with
`the GitHub API could not be reached (curl exit 6)`.

**And one in the harness doing the auditing.** `echo "$(basename $g) EXIT=$? ..."` reports
`basename`'s status, not the gate's: the shell expands left to right, so the command
substitution runs *before* `$?`. A gate that printed five `FAIL` lines was recorded as
`EXIT=0`. The standing rule is *read exit codes directly, never through a pipe*; this is the
same defect in a different costume, so the rule is really **nothing may run between the
command and the read**. `a_succeeding_interloper_hides_every_failure` proves it fails in the
reassuring direction; `the_reading_ignores_the_command` proves the reading does not depend on
the command's status at all. It was caught only because the gate's own log carried an
independent verdict line that contradicted the harness — an argument for every checker
printing its verdict rather than relying on its exit code alone.

### The axiom gates got 16 % faster without checking one thing less

`lake env lean` re-resolves the package before every probe, and both gates paid it once per
module — measured ~2 s × 32. Captured once, then `lean` is invoked directly, with a fallback
to the original command whenever the fast path is not demonstrably available. 186 s → 157 s
and 185 s → 159 s.

Verified as an equivalence, not a speedup: the fast and fallback outputs were diffed and are
**byte-identical**, and a planted `sorry` was still caught at exit 1 by the fast path in both
gates. Per-module isolation is unchanged and is not an optimisation target — `Proofs.RotGauge`
and `Proofs.RotMutant` both define `RotMoE.classify`, so a single combined import is refused
by lean itself.

### A mention is not a leak — the seal check was decorative *and* wrong

`checker/ab-analyze.sh` counted four strings, called the total *seal leaks*, and
annotated it `routed must be 0`. Measured over the committed corpus: the count
was **10**, and the script exited **0**. Two defects sharing one line.

**It could not fail.** The number was printed by a `console.log` inside the node
heredoc; the shell's `FAIL` counter never saw it. That is the same defect class
confessed twelve lines below it in the same file — *a checker whose failures
cannot reach its exit code is decoration* — and it survived because nobody had
ever planted a marker to watch the alarm fire.

**And it was the wrong property.** Splitting the needles by what they are:

| needle | routed (88 turns) | unrouted (88 turns) |
|---|---|---|
| `RoT:` · `[Nova]` · `lambda table` — the trace **forms** | **0** | **0** |
| `R/s+` — a bare technical **term** | 10 | 13 |

The forms never appeared. Every counted leak was the term, and *the arm with no
plugin loaded and no seal to keep produced more of them.* A detector that fires
more often where there is no trace to leak is measuring subject matter.

That matters because the seal has a hatch: a direct question about the engine
must be **answered**. Four of the ten flagged turns ask literally what
`hooks/rot-router.sh` computes for each lens, three ask what breaks if a tenth
lens is added, two ask what the session's first question was, and one explains
where to start in a repository whose subject *is* the router. Enforcing
`routed must be 0` would have marked all ten correct answers as violations —
and the obvious repair when such a check goes red is to delete it, destroying
the coverage. The spec was wrong, not the answers.

The count is now split: **structural is enforced and can fail**, topical is
reported with the unrouted arm beside it as the baseline. Negative control: a
`[Nova]` footer planted in routed turn 5 drove the checker to **exit 1,
`SEAL BREACHED: 1 structural trace marker`**; restoring the file returned it to
**exit 0, 4 passed** with the transcript verified byte-identical.

`Proofs/RotSeal.lean` carries the argument — 13 theorems, 6 mutants, 6 killed:
`breach_implies_old_flag` (the split loses nothing on genuine breaches),
`old_flag_does_not_imply_breach` and `old_spec_condemns_a_correct_answer` (the
converse fails, and that is the defect), `the_hatch_does_not_license_the_form`
(a question about the engine still may not print the block — the hatch exempts
the *term*, never the *form*), `topical_cannot_be_evidence_of_a_breach` (13 > 10
with a clean baseline), and `the_enforced_check_can_fail` for non-vacuity.

### The A/B primary endpoints, stated without varnish

Re-derived from `bench/ab-metrics.jsonl`, 88 paired turns:

| pre-registered PRIMARY | routed | unrouted | verdict |
|---|---|---|---|
| trailing question | 0.000 | 0.000 | no effect, 88 ties |
| hedging tokens | 0.045 | 0.011 | **worse routed**, 1 vs 4 pairs |
| self-narration | 0.000 | 0.000 | no effect, 88 ties |

The secondary figures move hard and consistently — cost −29.1 % (83 of 88
pairs), output tokens −34.8 %, duration −24.1 %, length −26.2 %, and 9 of 10
lanes favour routed at lane-level sign p = 1.95e-3. But the endpoints the voice
contract *claims* to change are flat on two and negative on the third. Written
down here rather than left in a log, because a project that only records the
metrics that moved is not measuring, it is advertising.

### `1.0.0` / `1.0.1` / `1.0.2` — built locally, deliberately not published

These three version numbers exist as **local artifacts only**, produced by
`checker/release-local.sh` into a `.gitignore`'d `.release-local-only/`. They are
installed into the CTT instance for testing and will not be tagged or uploaded
until the completion promise is true. As of this entry it is **not** true: the
central "produces better answers" claim still has no instrument, and
`not_every_lane_shrinks` in `lean/Proofs/RotAbility.lean` proves the router's
effect is not uniform in direction — one lane moves against it. A 1.0 tag cut
today would be a version number asserting something the repository can disprove.

Three properties are enforced rather than intended:

- **The tree is never bumped.** `plugin.json` still declares `0.9.2`, which is
  what the newest tag carries. The 1.0.x version exists only inside a throwaway
  `git archive HEAD` export. Bumping the manifest to get a local build would put
  it ahead of every tag and turn a correct repository red — buying convenience
  with a false alarm in the shared history.
- **An artifact is evidence only while it regenerates.** Every build starts from
  a pristine export of the commit, and the checker then rebuilds and compares
  file-by-file digests. A local zip that no longer reproduces from `HEAD` is
  reported stale, because the real hazard is not a missing artifact — it is an
  old one that installs cleanly and passes, crediting code that never shipped.
- **The changelog is not restamped.** The export rewrites the version in
  `plugin.json`, `marketplace.json`, `CITATION.cff` and `RELEASE.md`, which are
  mechanical name-and-number surfaces, and pointedly **not** in this file.
  Running the same `sed` here would relabel the real `0.9.x` history as `1.0.x`
  and satisfy the packager's "the shipped CHANGELOG names every variant" check
  by forging the record it is meant to verify.

The reproducibility comparison classifies each artifact as identical, different,
or **unmeasured**, and an unmeasured artifact fails on its own account. Folding
"the digest tool failed" into "the contents differ" is the same defect as
counting a mutation that never applied as `SURVIVED`: it reports in the
reassuring direction.

## Twelve fake kills, green in CI for the whole cycle

**Found by reading the full `log.zip` of run `31180174433`, which concluded
`success`.** The lean job's mutation step contained this:

```
mkdir: cannot create directory '/d': Permission denied
mutate/mutate_rotgauge.sh: line 128: /d/tmp/mut/M01.log: No such file or directory
M01  KILLED     exit=1  MODULE DEAD (no olean: every theorem in it is unusable)
```

`mutate_rotgauge.sh:24` read `LOG=/d/tmp/mut` — a Windows drive path, the only
suite of twenty-one not using `mktemp`. On a Linux runner `/d` cannot be
created, so the redirection target does not exist; **when bash cannot open a
redirect it does not run the command and returns 1.** The suite read that 1 as
"the build went red" and recorded a kill. All twelve RotGauge mutants were
scored `KILLED` on a runner where `lake` never ran once, the suite printed
`12 killed, 0 survived, 0 discarded`, and the job passed.

Nothing about the theorems was learned, and the repository published the
opposite.

**Three repairs, because the path was only the proximate cause.**

1. **The path.** `mktemp -d`, as in every sibling suite, plus a start-up check
   that the directory exists and is writable — measured: it now exits 2 on the
   CI condition instead of manufacturing kills.
2. **The class, in all 21 suites.** A non-zero exit is evidence only if a build
   actually ran. Every suite now refuses to score a kill when the build produced
   no log, reporting `DISCARDED` — which cannot exit 0. Verified by planting the
   exact CI condition: **9 DISCARDED, exit 1**, where the old code gave *12
   KILLED, exit 0*. Both suite shapes were then re-run unplanted and still kill
   for real (`RotGauge` 12/0/0, `RotAcquire` 5/0/0, `RotAttribute` 9/0/0).
3. **The rule, enforced.** `checker/mutant-discipline.sh` gained a phase that
   fails any suite with a machine-local `LOG=` path or without the
   attributability guard, with two negative controls proving both predicates can
   fire on the exact form that shipped. **34 → 79 passed.**

**And the rule is now a theorem, not a habit.** `lean/Proofs/RotMutant.lean`
already modelled whether a *patch* landed; this defect is one step later, and
the patch had landed perfectly.

| theorem | what it settles |
|---|---|
| `naive_rule_manufactures_a_kill` | the CI observation, reproduced: shipped rule → `killed`, repaired rule → `discarded` |
| `unattributable_is_never_killed` | **general**: no evidence, no kill — for every run and every status |
| `killed_carries_its_evidence` | the converse, so the guard cannot degenerate into "never kill anything" |
| `a_real_kill_survives_the_new_guard` / `a_survivor_is_still_a_survivor` | non-vacuity: it still kills, and still recognises a survivor |
| `rules_differ_exactly_on_missing_evidence` | exhaustive over every observable combination, kernel-checked |

`rules_differ_exactly_on_missing_evidence` **refuted its own first version.** It
was stated with a third disjunct, `be.val = 0`, on my assumption that a zero
status was harmless; `decide` proved that false. With no evidence, the shipped
rule reports **survived** — a claim of robustness about a build that never ran,
exactly as unfounded as the twelve kills. Only the kills were noticed, because
only the kills looked like work. `naive_rule_also_manufactures_a_survivor` now
records that half explicitly.

Suite `mutate_rotmutant.sh` grows M14–M18: attributability switched off (M14),
the evidence check deleted so the shipped rule returns verbatim (M15), the
recorded CI observation edited to erase the measurement (M16), the guard turned
into a blanket refusal (M17), and **my own refuted disjunct put back** (M18).
All five killed. M17's first needle matched two lines and the suite reported
`DISCARDED (needle x2)` rather than guessing — it was retargeted, not explained
away.

## The A/B was not null — my analysis was blind, and here is the retraction

**I published a null result that the data does not support.** The 80×2 A/B run
was reported as "null on every pre-registered primary". Two defects in the
*analysis*, both mine, both found on 2026-08-07 by re-reading the raw
transcripts that the committed corpus had been derived from:

**1. The configuration was dropped in derivation, not missing from the run.**
`bench/ab-metrics.jsonl` carried `arm, turn, err, dur, cost_micro, len, q,
hedge, narr, leak` — no model, no effort, no thinking level. I described this as
"the experiment never recorded the model". That was wrong. Every raw turn
carries `modelUsage`, and it says the same thing 160 times:

| | measured |
|---|---|
| model, all 80 turns, **both arms** | `claude-opus-5[1m]` |
| incidental other model | one 17-token `claude-haiku-4-5` call, across the whole corpus |

The run was on the strongest available configuration. The corpus simply threw
the field away, and I read the absence as a property of the experiment.

**2. The metrics that were examined were not the metrics that moved.** The three
primaries genuinely tied. Output **tokens** — computable from the very same
transcripts, never extracted — did not:

| endpoint | routed | unrouted | delta | paired sign count | two-sided sign test |
|---|---|---|---|---|---|
| output tokens / turn | **440** | **675** | **−34.8%** | routed fewer on **69 of 88**, 0 ties | **p = 7.8 × 10⁻⁸** |
| cost per turn | $0.1168 | $0.1648 | **-29.1%** | cheaper on **83 of 88** | p < 10⁻¹² |
| duration / turn | 10 230 ms | 13 474 ms | −24.1% | faster on 56 of 88 | p = 0.014 |
| trailing question | 0.000 | 0.000 | — | all ties | — |
| self-narration | 0.000 | 0.000 | — | all ties | — |
| hedging tokens | 0.034 | 0.000 | **worse routed** | worse on 3, better on 0 | — |

Negative control for the test itself: a 45/88 split gives p = 0.915, so the
instrument can return "no effect" and does.

**The corpus is 88 pairs, not 80.** Eight prompts were added — see the per-lane
section below — and the original 80 were re-derived unchanged: **1600
shared-field comparisons, zero differences.** The figures above therefore move
because the corpus grew, never because a number was edited to fit a sentence.

**What this does and does not license.** It licenses: *on `claude-opus-5[1m]`,
across 80 paired prompts, the routed arm produced a third fewer output tokens,
cost a third less and finished a quarter faster, with no measured change in
error rate, trailing questions or self-narration, and slightly more hedging.*
It does not license any statement about answer **quality** — nothing here
measures that, and no proxy was substituted for it, because a proxy scored by
the same model family is not an instrument.

**Fixes, so the defect cannot recur silently:**

* `checker/ab-analyze.sh` now derives `model` per turn (by output tokens, not by
  first key — one incidental 17-token call must not name the experiment) and
  reports `5b output TOKENS` beside the character length it used to trust.
* `bench/ab-metrics.jsonl` regenerated from the raw corpus with `outTok` and
  `model` added. **The 1280 shared-field comparisons against the previous file
  differ in zero places** — every published figure is reproduced exactly; the
  regeneration only adds columns. A corpus edited to be more flattering would
  have shown up right there.

## Three CI runs reported the same error because the fix was never pushed

The user asked whether I was reading the CI archive correctly, since the same
line kept coming back:

```
FAIL  sh: log grew to       24 lines with cap 5 -- unbounded
```

The reading was correct. The **landing** was not.

| | |
|---|---|
| diagnosis | correct on the first archive — BSD `wc` padding |
| fix written and locally verified | yes — reverting it reproduced 24-against-5 exactly |
| fix on the remote | **absent for three consecutive runs** |

`git commit` was killed three times by a wall-clock ceiling. Each kill left the
pre-commit gate running as an orphan, so the commit never happened — and I read
the timeouts as "slow" rather than "did not land". Runs `e66a6bc`, `783fb2f`
and the one quoted all tested a tree **without the repair**, so they could only
report the identical failure. They were right; I was reporting a fix that
existed on one machine.

Measured after the push: remote head `e8b8dc1`, `tr -dc` present — checked
against the remote rather than against `origin/main`, which was itself stale
because pushing by full URL does not move the tracking ref. That stale ref
briefly produced a *correct answer for the wrong reason*, which is its own
hazard.

### `checker/ci-audit-freshness.sh` — the alarm that was missing

It answers one question: **does the CI run I am reading contain the commits I
think it does?** Pointed at the run I misread, it fails and names them:

```
FAIL  the run PREDATES 3 local commit(s) -- its failures cannot reflect them:
        e8b8dc1 rot-router: tolerate a padded count ...
        0655b29 CountParse: the guard that READ the count ...
        b425947 Docs: a defensive sanitiser switched rotation off ...
----  a red run here says nothing about a fix that is not in it.
```

It also reads `refs/heads/main` from the remote directly, so "committed" is
never mistaken for "pushed". The failure mode is *not* "unpushed commits exist"
— that is normal. It is claiming a fix is in effect while the audited run
predates it.

**Not registered in `ci.yml`, deliberately.** Inside a CI job local HEAD is the
run's own commit, so the check would pass by construction on every run forever.
A step that cannot fail is decoration. It runs on the development machine, where
the defect actually occurs.

Three of my four `RotGates` guard values for this gate were wrong when written
by hand and were corrected by **measuring** them (`deepSet` 13→14, and the
staged sets for `RotGauge.lean`/`README.md` unchanged, not bumped — the gate is
deep and triggers only on `hooks/`, `checker/`, `.github/workflows/`).

## A defensive sanitiser switched rotation off on macOS — and only macOS

CI run `31202010565` failed on **one leg of three**:

```
FAIL  sh: log grew to       24 lines with cap 5 -- unbounded
```

The rotation is correct and proved. It never ran, because of the step *before*
it. BSD `wc -l` prints `"      24"`; GNU prints `"24"`. The router's guard
rejected anything non-numeric and fell back to `0`, so the count was always
zero, `n > cap` was always false, and the log grew without bound. ubuntu and
windows passed throughout.

**The bug was not in the rotation. It was in reading the number that decides
whether to rotate** — and it presented as a platform difference rather than a
logic error. A guard written to be defensive is what disabled the feature.

The fix does not learn which `wc` is present: `tr -dc '0-9'` keeps the digits
and tolerates whatever padding arrives. Same conclusion as the step-log probe
above, reached independently on the same day: **do not encode the other side's
formatting, tolerate it.**

### The defect is now reproducible on every platform

A platform bug findable only on that platform is a bug found by users. Phase 5
of `checker/debug-channel.sh` puts a padding `wc` at the front of `PATH` and
runs the real hook through it.

- With the fix: `5 <= 5`, bounded.
- With the fix reverted: **24 lines against cap 5** — the same number macOS
  reported, reproduced on this machine.
- The stub itself is verified to actually pad; if it does not, the phase reports
  that it proves nothing rather than passing.

### `RotDebugLog.lean` §R — the count parser

| theorem | what it settles |
|---|---|
| `strict_padded_is_zero` | the shipped guard reads a padded count as **zero** — the one value that makes every `n > cap` false |
| `tolerant_ignores_padding` | the repair is padding-invariant for **every** width |
| `strict_never_rotates` | the CI failure as a theorem, quantified over length rather than fixed at the 24 observed |
| `tolerant_still_rotates` | the repair still fires when it should — not a disabled feature |
| `tolerant_does_not_always_exceed` | control: it is not the constant "yes" |

`tolerant_ignores_padding` was first proved by induction on the padding width;
the build reported the induction hypothesis unused. That is a report about the
theorem, not the script — the filter erases every space at once, so the width
was never part of the argument. Simplified rather than silenced.

Mutants **D10–D12, all killed.**

### Three attempts to write those mutants, and what each one taught

- D12's needle contained `' '` — a literal space character — which ends a
  single-quoted shell string. Third time this trap has fired this session.
- An inline `node -e` wrote a literal `\n` instead of a newline. My own notes
  say to use a file; I did not, and paid for it.
- The block was inserted **inside an open `printf '…'` string**, because the
  anchor I reused does not exist in this suite and the fallback lives inside
  that printf. `bash -n` caught it.

Then the suite reported **D10–D12 DISCARDED, needle occurs 2 times**. Cause:
this suite's `run_mut` is `id needle repl expect` with **no module argument**,
and I passed one, so `RotDebugLog` became the needle. The harness was right and
said so instead of scoring three phantom passes.

**`checker/mutant-needles.sh` had validated my intent rather than the suite's
signature** — it saw a token matching a module name and helpfully treated it as
a module. It now checks arity consistency: if some invocations in a suite carry
a module token and others do not, one group is being mis-parsed. Re-planting the
error makes it fail; removing it returns exit 0.

## A suite where every mutant DISCARDS looks diligent and proves nothing

`checker/mutant-discipline.sh` proves every suite refuses to score a mutant
whose patch did not apply — it reports DISCARDED. That is the per-mutant rule.
Nothing checked the **inverse**:

> A suite in which *every* mutant discards is not a careful suite.
> It is zero evidence, and the only trace is a number in a summary nobody diffs.

`0 killed, 9 discarded` reads as diligence. It is indistinguishable from having
run nothing. Two of my own mutants discarded on 2026-08-07 and were caught only
because I read the output.

### `checker/mutant-needles.sh` — static, no build, runs on every commit

A needle goes stale the moment someone edits the line it quotes, and that edit is
usually in a commit with nothing to do with mutation testing.

**Result of the audit this file was written to perform: 22 suites, 296 of 296
invocations replayed, 0 dead needles, no suite entirely discarded.** Control:
planting a needle that cannot exist makes it fail; removing it returns exit 0.

### Four wrong answers before the right one, all recorded

Getting here required admitting the approach was wrong three times:

| attempt | verdict |
|---|---|
| line-based single-quote match | **false positive** on E10/V08 (the `'"'"'` idiom is three chunks the shell joins into one word) |
| chunk-splitting tokeniser | **false negative** on the same two — took the first fragment as the needle |
| word-concatenating tokeniser | **false positive** on P01, double-quoted, where `\\\\` collapses to `\\` |
| replay under `bash` | correct |

P01 was measured **KILLED** by its own suite while my checker called it dead. The
structural answer is the one that ended the `node -e` escaping failures earlier
this cycle: **stop re-deriving shell quoting and hand the text to the thing that
owns it.** `run_mut` is stubbed to print its arguments, so the needle tested is
byte-identical to the needle the suite will use. Only invocation lines are
replayed — no preamble, nothing mutated — and a block with a command
substitution is refused, never passed.

Three further defects found in my own checker while building it:

- **It examined 260 of 293 mutants and printed a clean summary.** Coverage is
  now asserted against a deliberately looser count; any shortfall is a failure.
- **One syntax error killed the entire replay**, delivering 2 of 293 while the
  table still rendered. Each invocation now replays in isolation.
- **`bash "$SCRIPT"` inherited the reader's stdin** and could eat the lines still
  to be read. `< /dev/null` is load-bearing there, not hygiene.

An invocation whose arguments span a real newline (RotDuplicate M03 inserts two
lines of Lean) needed a quote **state machine**, not a quote count: counting is
defeated by `'"'"'`, which merged V08 with its neighbour and lost a mutant
silently.

### Why only ZERO is a failure

A first cut failed on any count ≠ 1. That was a spec forbidding a correct
future: several suites use `run_mut_nth`, others pass an expected occurrence
count, so a needle at 10 sites is **declared** there (RotInstall I01), not
accidental. Failing those would have pushed the repair toward weakening real
mutants to satisfy the checker. Zero is never correct under any convention.

### The Lean binding — `RotMutant.lean` §S

| theorem | what it settles |
|---|---|
| `allDiscarded_evidence_eq_empty` | an all-discarded suite has the **same** evidence as a suite with no mutants — not less, the same |
| `one_landed_gives_evidence` | one landed mutant suffices, so the static check need not know which mutants are strong |
| `evidence_not_always_empty` | control: `evidence` is not the constant empty list |

Mutants **M19–M21, all killed** (RotMutant: 21 killed, 0 survived, 0 discarded).

## CI went red on a correct commit — the spec was wrong, not the change

Run `31193273932` (`4fb410a`) **failed**, and the failure was the gate's fault.

`checker/deferred-closure.sh` proves a declared workflow step actually ran by
finding its per-step log in the archive. It reported:

```
FAIL  no runner log for step: A/B corpus -- published figures re-derived from bench/ab-metrics.jsonl
```

The step had run — in **all three** matrix legs; `ab-analyze.sh` appears three
times in each job log. GitHub stores the per-step log under a *sanitised*
filename, rewriting `/` as `_`:

```
31_A_B corpus -- published figures re-derived from bench_ab-metrics.jsonl.txt
```

The probe replaced `/` with a **space**, searched for `A B corpus`, and found
nothing. Measured against the real archive: old probe **0** matches, new probe
**3**. Across the 60 declared steps at that commit, 3 contain a slash and
exactly **1** was invisible.

This is the failure shape this repo keeps warning about: a check that goes red
on a correct commit, where the obvious repair — delete the step, or rename it to
dodge the slash — **destroys real coverage to satisfy a broken matcher**.

It also means my own CP21 audit was incomplete. I checked that run for errors,
warnings and skips and called it green; I did not check that every *declared*
step produced evidence. The gate caught what my audit method could not.

### The fix does not learn GitHub's substitute — it stops needing to know

The probe now uses `.`, the regex wildcard, at slash positions. `_` today,
anything tomorrow, and this file never has to be edited. Hard-coding `_` would
have been the same dated-constant defect one layer down.

`lean/Proofs/RotLog.lean` §N, five theorems and two executable examples:

| theorem | what it settles |
|---|---|
| `wildProbe_patMatches_any_substitution` | matches for **every** substitute char and every name — quantified, so no rewrite can break it |
| `guessProbe_misses_when_the_guess_is_wrong` | why the old probe failed, as a general fact |
| `guessProbe_works_only_by_luck` | it worked when the guess happened to be right — why the defect hid so long |
| `wildProbe_still_rejects_a_different_name` | the wildcard is not a free pass |
| `wildProbe_rejects_a_truncated_name` | …and does not weaken length discipline |

`#eval` confirms `sanitize '%'` also matches — the durability is executable, not
just asserted. Mutants **L11–L14, all killed**.

Two of those four were first reported **DISCARDED — needle occurs 0 times**,
because the needles contained `'/'` and a single quote terminates a
single-quoted shell string. The harness said so instead of scoring them
`SURVIVED`; that attributability guard was added earlier this cycle and this is
the first time it caught a real mistake of mine. Re-cut with quote-free needles:
4 killed.

A control was added for the population that was invisible: **every declared step
whose name contains `/` is now matched explicitly**, and if no such step exists
the control announces itself VACUOUS rather than passing.

## The router's debug channel could not report its own failure

The goal names one thing this repo did not check: the router's `*.log` debug
output. It turns out the channel existed and worked — and could lie by omission.

`hooks/rot-router.sh` appended each record with `2>/dev/null || true`. The
tolerance is **correct**: a hook that failed a user's turn over a debug file
would be a far worse defect. What was wrong is that the tolerance was *total*:

| world | records an observer finds |
|---|---|
| the router never fired | 0 |
| the router fired N times, path unwritable | 0 |

Indistinguishable — the same missing-evidence class as the twelve fake RotGauge
kills. And it mattered concretely: the A/B arm-validity control **is** a count
of route records, so "9 routed, 0 unrouted" is the evidence that the experiment
measured the router at all. A silent channel would have made a broken path read
as *the router never fired*.

### `lean/Proofs/RotDebugLog.lean` — 12 theorems, then the shell

| theorem | what it settles |
|---|---|
| `silent_channel_is_ambiguous` | the two worlds above are identical to a reader |
| `..._at_every_volume` | quantified over N — not an artefact of one number |
| `marker_resolves_the_ambiguity` | one bit separates them |
| `quiet_and_unmarked_means_it_never_fired` | zero + no marker ⟹ genuinely quiet, ∀ worlds |
| `lost_evidence_is_always_marked` | no silent loss remains |
| `marker_is_not_always_set` | the bit can stay false… |
| `an_always_on_marker_would_not_distinguish` | …which is why "warn every turn" is not a fix |
| `rotate_keeps_the_newest` | a bounded log keeps the **newest** record |
| `rotate_below_cap_is_identity` | under the cap nothing is discarded |
| `taking_the_front_loses_the_newest` | truncating from the front is refuted |
| `shipped_hook_failed_the_contract` | the pre-repair hook **fails**, stated so it cannot read as passing |
| `tolerance_alone_is_insufficient` | "it already has `|| true`" is not an answer |

`rotate_keeps_the_newest` was first stated with an extra hypothesis `rs ≠ []`,
and the build warned it went unreferenced. That is a report about the *theorem*:
retention holds for the empty log too, so the hypothesis was over-assumption.
**Dropped, not silenced with `_`.** `0 < cap` is genuinely needed — at cap 0 the
newest record is lost, which is what the bound must forbid.

Mutation: **D01–D09, 9 killed, 0 survived, 0 discarded.** Necessary, because
almost every theorem here reports `does not depend on any axioms` — that is what
`decide` over closed data looks like, not strength.

### What the shell actually did, measured

Fixing only the obvious writer was not enough. **The channel has two writers** —
the awk in `gauge` emits `"kind":"gauge"`, the block below emits
`"kind":"route"` — and patching the second left the first printing

```
awk: ... fatal: cannot redirect to `...': No such file or directory
```

straight into the user's session. One channel now gets **one preflight and one
marker bit**, which is also what the Lean models: `observe` returns a single
`marker`, not one per writer.

Two more things the negative control exposed:

- `2>/dev/null` must come **before** the `>>`. Redirections apply left to right,
  and the "No such file or directory" for a failed append is emitted by the
  *shell*, not by printf — with the order reversed it escapes to the transcript.
- R/s+ used to degrade to `n/a` when the log was unwritable, because the awk
  writer died mid-gauge. **A debug-log failure no longer corrupts routing.**

Both arms now behave identically: same marker string, same rotation, newest
record retained, zero stderr. `cross-diff` 79 passed.

### `checker/debug-channel.sh` — the binding, with its own controls

A theorem about a `World` constrains `rot-router.sh` through nothing at all
unless something runs the real hook. 17 assertions across both arms, on all
three OSes, plus **two negative controls that plant a broken hook**: one with
the marker deleted (must be rejected), one with rotation disabled (the log must
then grow past the cap — measured 16 > 2). An alarm nobody has tripped on
purpose is an untested alarm.

`workflow-lint` caught a real bug in that checker as it was written:
`tail | grep -q` under `pipefail` returns **141** on a *match*, because `grep -q`
closes the pipe and `tail` takes SIGPIPE. A matching line would have been read
as a failure.

Registered as a **fast** gate (`RotGates.lean`, count 39 → 40): the defect it
guards is filesystem behaviour, and the commits most likely to break it are the
ones that touch a path or a permission somewhere else entirely.

## A skip that named the wrong cause — `marketplace-session.sh`

Run `31187881399` printed these two lines consecutively in the lean job:

```
  SKIP  no claude CLI on PATH -- cannot test the install path
SKIP (3): no credentials on the runner -- never counted as a pass
```

The cause reported was **not** the cause observed. Both conditions exited 3, and
the workflow's message for 3 names credentials — so a run that skipped for a
missing CLI was filed under a boundary that had never been reached. This is the
same defect class as the twelve fake RotGauge kills: a real condition reported
under the wrong cause, in a form that reads as understood.

**Fix:** two causes, two codes, and they mean opposite things about whether the
gap can ever be closed.

| code | cause | can it be closed? |
|---|---|---|
| 3 | no credentials | **No** — a decided boundary (`ci.yml:737`), enforced locally with `gate-all --full` and in CTT |
| 4 | no CLI | **Yes** — an environment gap; any job that installs the CLI closes it |

And the consequence that makes the distinction load-bearing: the checker is now
also registered in the **checkers matrix**, where the CLI *is* installed a few
steps earlier. There, exit 4 cannot be a fact about the environment — it means
the install produced nothing — so it is a **hard failure**, mirroring the rule
`live-session-smoke` already applies to its own 3.

Three negative controls, all measured: normal run → **0** (8 passed, 0 failed,
so the checker can genuinely pass); `PATH` stripped of the CLI → **4**;
`CLAUDE_CRED_SRC` pointed at a missing file → **3**. `workflow-lint` 163 passed.

## Every lane scored on its own effect — and one lane goes the other way

A single pooled figure was never the right reading, and `RotAttribute` proves
why: `pooling_reverses_every_stratum` exhibits a checked instance where the
pooled verdict contradicts **every** stratum, and
`balanced_pooling_agrees_with_the_strata` pins that on unequal stratum sizes.
This corpus has lanes of size 4 to 36. That is precisely the shape the theorem
warns about, so the lanes are now scored separately.

**The lane is not new data.** It is a function of the prompt, and the shipped
router computes it — `hooks/rot-router.sh --route`. Both arms can therefore be
labelled offline from two committed files, and CI re-derives the whole table
with no session and no credential.

| lane | n | routed | control | delta | routed fewer | sign p |
|---|---|---|---|---|---|---|
| FORGE | 36 | 525 | 751 | −30.1% | 28/36 | 1.2e-3 |
| CONVERGENT | 16 | 322 | 404 | −20.5% | 11/16 | 0.21 |
| CLINICAL | 8 | 495 | 758 | −34.7% | 7/8 | 0.070 |
| PREDICTIVE | 4 | 680 | 996 | −31.8% | 4/4 | 0.125 |
| CREATIVE | 4 | 248 | 376 | −34.0% | 3/4 | 0.625 |
| EXECUTIVE | 4 | 227 | 513 | −55.7% | 4/4 | 0.125 |
| RECURSIVE | 4 | 248 | 939 | −73.6% | 4/4 | 0.125 |
| STEALTH | 4 | 536 | 852 | −37.1% | 3/4 | 0.625 |
| STRATEGIC | 4 | 485 | 1062 | −54.3% | 4/4 | 0.125 |
| **EMPATHIC** | 4 | **256** | **220** | **+16.1%** | **1/4** | 0.625 |

**Nine of ten lanes favour the routed arm; the lane-level sign test is
p = 2.0 × 10⁻³.** Only FORGE reaches significance on its own — the small lanes
hold four turns and cannot, whatever they show. What they can do is agree, and
that is the weaker claim being made here, labelled as weaker.

**EMPATHIC is the exception and it is the most informative row in the table.**
It is the one lane where the router makes the answer *longer*. That is what the
EMPATHIC profile is for — Violet at λ 2.3, Carnage at 1.8, compression damped —
so a router that shortened everything uniformly would be evidence the profiles
do **not** do what they claim. The effect is directional, not global. Anyone
selling "the router makes Claude terser" is describing nine lanes and ignoring
the tenth.

**Two lanes had no prompts at all, and the checker said so.** The first per-lane
run reported `lanes with NO prompt in the corpus: EMPATHIC, STRATEGIC` and
**failed**. An ability with no sample is an ability that was not scored, and a
claim ranging over it would be an overclaim — so the gap was closed by
measuring, never by narrowing the check: eight prompts were added (four per
lane, each verified against the shipped router *before* being written), and both
arms were collected with their validity controls passing — **9 route records in
the routed arm, 0 in the control**.

`checker/ab-lanes.js` is a real file rather than a `node -e` string because the
inline form died on escaping: the generator, the shell heredoc and the node
argument each consumed one backslash, and `split("\n")` reached node as a
literal newline. That is the second escaping failure of the session — the first
turned mutation needles into literal `\n` and scored nine DISCARDED. The fix is
one less level of nesting, not more backslashes.

### `RotAttribute` §5 — the universal claim, refuted in Lean by our own data

Nine theorems, all `decide` over the measured lane table, all delivered and
kernel-re-checked (`lake env leanchecker Proofs.RotMoe.RotAttribute` → exit 0).

| theorem | what it settles |
|---|---|
| `not_every_lane_shrinks` | **"the router shortens the answer" is FALSE** — EMPATHIC refutes it |
| `empathic_routes_longer` | the counterexample is exhibited, not asserted |
| `nine_lanes_shrink` | the true statement is a *count* (9), strictly weaker than the universal |
| `pooled_direction_hides_a_real_exception` | pooled −34.8% and the exception hold simultaneously |
| `every_measured_lane_is_scored` | every lane in the shipped table carries samples |
| `an_unsampled_lane_is_not_scored` | negative control: the coverage predicate can return false |
| `a_report_covers_exactly_what_it_sampled` | quantified over *any* table, so a future corpus inherits it |
| `coverage_hypothesis_is_load_bearing` | that hypothesis is not decoration |

**Every one of these reports `does not depend on any axioms`.** That is not
strength, it is what a computation over closed data looks like — so the axiom
list proves nothing here and mutation had to do the work instead. Five mutants
A10–A14 were added; the suite runs **14 killed, 0 survived, 0 discarded**.
A13 reproduces the CI failure inside Lean: a lane present in the table with no
prompts behind it.

`measuredRoutedMeanTokens` moved 447 → 440 and the control 678 → 675 **in the
same edit** as the corpus, the CHANGELOG table and the A08/A09 mutation needles
— which had gone stale the instant the corpus grew and would have scored
DISCARDED.

## Why a null can belong to the analysis instead of the world — `RotAttribute`

The retraction above is not an anecdote, it is three theorems.
`lean/Proofs/RotAttribute.lean`, 24th module, states the failure modes so the
harness is checked against them rather than against my memory of what went
wrong.

| theorem | what it settles |
|---|---|
| `erased_summary_is_blind` | **every** summary function agrees on two datasets that erase to the same list — a dropped column is not merely hard to recover, the verdict is provably independent of it |
| `erasure_hides_information_a_lane_aware_reading_has` | the load-bearing form: two datasets no erased summary can separate, that a lane-aware reading separates outright |
| `routed_wins_lane1` / `routed_wins_lane2` | the routed arm strictly wins in **both** strata |
| `pooling_reverses_every_stratum` | …and strictly **loses** pooled. Simpson's paradox, as a checked instance, not a citation |
| `stratified_and_pooled_disagree` | the three above as one statement |
| `balanced_pooling_agrees_with_the_strata` | **the control** — same values, equal stratum sizes, and pooling now agrees. This is what pins the reversal on the imbalance |
| `primaries_can_tie_while_the_turn_differs` | two turns identical on every primary and different in output tokens: exactly the shape that produced the false null |
| `measured_routed_emits_fewer_tokens` | 447 < 678, pinned so a later edit cannot quietly reverse the finding |

Executed, not just elaborated: `#eval` gives `(10, 20)` and `(100, 110)` per
stratum, `(91, 29)` pooled — routed worse — and `(55, 65)` once balanced —
routed better. Same numbers throughout; only the group sizes change.

**`balanced_pooling_agrees_with_the_strata` exists because a mutant survived.**
A05 originally rebalanced one arm and expected the paradox to collapse. It
survived, correctly: a one-sided rebalance relocates the imbalance rather than
removing it, so the module had demonstrated an effect without demonstrating its
cause. The repair went into the *module* — the balanced control was added — and
A05 now breaks that control instead. A surviving mutant that changes the
mathematics is the suite working, not the suite failing.

Suite `lean/mutate/mutate_rotattribute.sh`, mutants A01–A09: erasure keeps the
lane (A01); the lane-aware reading is blinded too (A02); routed stops winning
lane 1 (A03) or lane 2 (A04); the balance control is broken (A05); `mean`
becomes a size-blind sum (A06); the projection is widened so the primaries can
no longer tie (A07); the measured direction is flipped (A08); the two measured
means are made equal — the very verdict round 1 published (A09). **All nine
killed, none survived, none discarded.** Its first run scored 9 DISCARDED
because the generator emitted literal `\n` where line continuations belonged;
the harness reported that as a defect in itself rather than as nine robust
theorems, which is the only reason the second run means anything.

Counts move to **24 modules, 578 theorems, 21 mutation suites, 270 mutants**.

## A test that creates its own precondition — green on three platforms

**Measured in CI run 31116857127, and it had been green the whole cycle.**
`checker/live-session-smoke.sh` guarded its authenticated phase like this:

```sh
[ -f "$HOME/.claude/.credentials.json" ] && HAVE_CREDS=1
ls "$HOME/.claude"/*.json >/dev/null 2>&1 && HAVE_CREDS=1     # <- this line
```

The glob matches **`settings.json`** — a file the same script's own `ARM_ROUTER.sh`
call creates a few lines earlier. So a runner holding no credentials at all reported
*credentials present*, ran a session that could not authenticate, and logged, on
ubuntu **and** windows **and** macos:

```
PARTIAL the router line appeared 1 time(s) but the session exited 1.
```

The job was green, because `PARTIAL` incremented neither counter.

Two independent defects met in three lines, and they fail in opposite directions:

- **The precondition detector was satisfied by the test's own output.** Past that
  line it is not a weak check, it is a constant.
- **The verdict rested on a signal present in the failure path.** The router line
  is written by the hook when the prompt is *submitted*, before the session can
  die, so it can testify that the hook ran and to nothing else.

Both repaired. Credentials now mean `.credentials.json` or `ANTHROPIC_API_KEY`,
nothing else. A session that exits non-zero **with** credentials is a failure, and
so is a timeout — with one retry at double the budget first, because a busy machine
is not a defect and an unproven claim is not a pass. The pass condition never moved:
the session must COMPLETE and carry the line. Measured on the first live run after
the change: `exit=124 at 180s -> retry -> exit=0`, `R20: PASS`.

**`checker/ctt-session.sh` was testing an environment nobody ships.** The
maintainer's `CTT` launcher does three things; the harness did one. It now mirrors
the launcher: the credential is re-copied from the live file on every run (it is a
snapshot, and a stale one killed 20 turns), and the proxy environment is cleared —
measured leaking a populated `ANTHROPIC_BASE_URL`, so every "CTT" turn had
been going through the rolling-context proxy instead of the isolated path.

A symlink was tried for the credential and **reverted**. Claude Code rewrites
`.credentials.json` on token refresh, so a link would let a test session write the
live credential — breaking exactly the one-way isolation the design depends on.
There is no such thing as a one-way link; the copy is the one-way link.

`lean/Proofs/RotObserve.lean` §10 and §11 state both shapes generally:

| theorem | what it settles |
|---|---|
| `loose_detector_is_constant_after_setup` | after its own setup the detector is `true` for **every** world — it detects nothing |
| `loose_detector_cannot_see_a_missing_credential` | the measured case: no credential, reported ready |
| `strict_detector_survives_setup` | the repair, and the property that makes something a detector: **invariance under the test's own setup** |
| `strict_detector_is_evidence` | it still separates the two worlds, so it is not a constant in the other direction |
| `a_link_propagates_backwards` | for every value: a write through a link changes the original |
| `a_link_lets_the_test_overwrite_the_live_credential` | the concrete hazard that was avoided |
| `a_copy_never_propagates_backwards` | for every prior state and every write, the original is untouched |
| `a_copy_carries_the_original_forward` | and it is not one-way by being inert |
| `refresh_then_write_preserves_the_live_credential` | both halves — the isolation property CTT depends on |

Build exit 0 with **zero warnings**; axioms `propext` or none beyond it, no
`sorryAx`; `leanchecker` exit 0, zero bytes. Mutants **M24–M28** added — **all
killed**, 0 survived, 0 discarded. M25 was reported `DISCARDED` on its
first run because the replacement contained its own needle, and was rewritten
disjointly rather than counted; a discard is a statement about the harness, never
about the theorem.

Credentials in repository secrets were put to the maintainer and **declined**, so
`marketplace-session.sh` stays `exit 3` off-runner by decision, not by omission —
recorded in `ci.yml` so it is not reopened as a way to make a line green.

Counts move to **504 theorems / 22 modules / 19 suites / 226 mutants**.

---

## Symbiogenesis is generative — and that half is a theorem, not a claim

The engine's strongest assertion is about **reach**: that fusing two lenses
produces a point of view neither parent occupies, that Eidolon can keep doing
it, and that the supply of distinct points of view is therefore not bounded by
the roster of nine.

That is mathematics. It does not need an A/B test, it needs a proof — and
`lean/Proofs/RotSymbiogenesis.lean` is that proof. 21 theorems, 12 mutants, all
killed.

### What is now PROVED

| theorem | claim it settles |
|---|---|
| `forge_matches_the_spec` | the operator reproduces the spec's own worked hybrid (Claude × Anti-Venom → λ 1.7 · H 0.35 · μ 1.05) exactly |
| `fuse_H_gt_left` / `_right` | a hybrid's entropy strictly exceeds **both** parents' |
| `fuse_ne_left` / `_right` | **a hybrid is never one of its parents** |
| `fuse_escapes_any_roster` | for **any** finite roster — nine, or nine hundred, or every hybrid built so far — fusion lands outside it |
| `fuse_lam_gt_mean` | the `+0.2` is a real gain: fusion strictly exceeds the mean |
| `fuse_mu_ge_both` | μ is a maximum, so fusion can never lower quality below a parent |
| `chain_H` / `chain_lam` | iteration is exactly linear: `+1/20` entropy and `+1/5` λ per generation |
| `chain_injective` | **no two generations are the same lens** |
| `symbiogenesis_generates_infinitely_many` | the reachable set is **infinite** — the precise content of "infinitely generated combinations" |
| `lens_space_is_infinite` | there is no finite catalogue of points of view to enumerate |

`#eval` on the chain from the Verified Forge:
λ 1.7 → 1.9 → 2.1 → 2.3 → 2.5, H 0.35 → 0.40 → 0.45 → 0.50 → 0.55.

### And what it deliberately does NOT say

Two boundaries are theorems too, so they cannot be quietly dropped:

- `fuse_may_gain_no_quality` — a new triple is **not** a better lens. μ being a
  maximum means fusion never *loses* quality, not that it gains any.
- `equal_reading_does_not_imply_equal_lens` — **the gauge compresses.** Two
  different lenses can share a reading, so an `R/s+` value is evidence of
  activity, never a fingerprint of the point of view that produced it. The
  honest direction is `distinct_reading_implies_distinct_lens`.

Nothing here concerns output quality. That is a separate question, settled by
measurement and by nothing else, and it is not settled.

### Why ℚ and not `Float`

Float addition is not associative, so the shipped arithmetic can pin a concrete
row and can never support a general statement about iteration. Every constant is
exact (`0.2 = 1/5`, `0.05 = 1/20`), the spec's worked hybrid is pinned against
these definitions, and the general theorems are therefore real rather than
artefacts of rounding. `RotEnsemble` continues to bind the Float arm.

### The mutants

S01–S12: **all twelve killed, none survived, none discarded** (the repo-wide
figure stays the one in `README.md`; a per-suite count must not be written in
the phrasing `repo-complete` reserves for the total, or it shadows it). They
plant the objections
directly: delete the novelty term, delete the λ gain, average μ instead of
maximising, take the minimum entropy, misquote the spec's hybrid by one digit,
collapse iteration so it saturates, weaken strict monotonicity to `≤`, add the
Verified Forge **to** the roster so fusion no longer escapes it, and — S12 —
flip the anti-overclaim boundary to assert the fingerprint property that was
never proved.

S02 was first reported **DISCARDED** (needle whitespace), fixed, and re-run. A
discarded mutant is a claim about the harness, never about a theorem.

Counts: **567 theorems / 23 modules / 20 suites / 261 mutants**.

---

## Atomicity is not enough: the atomic write dropped the exec bit and CI caught it

Run on `6791683`: `mutate the checker` failed on **ubuntu-latest and
macos-latest** with

```
H00  META-CONTROL FAILED: the checker goes red on a NO-OP edit.
```

`checkers (windows-latest)` passed the same commit, and that asymmetry is the
whole diagnosis. Making the mutation writes atomic used `> "$f.mtmp" && mv -f`.
A shell redirect **creates** the temp at `0666 & ~umask` = `0644`, and `mv`
carries the **temp's** mode onto the target — so `hooks/rot-router.sh` arrived
non-executable, `checker/cross-diff.sh:52` runs it directly, the call produced
nothing, and the meta-control asserting that a no-op edit leaves the checker
green went red. Windows has no exec bit, so the platform this was developed on
could not see it.

Every mutant below H00 still reported KILLED. That is exactly what H00 exists to
expose: **with the baseline broken, those kills measured nothing.**

The repair keeps the rename and carries the mode:

```sh
cp -p "$f" "$f.mtmp"      # clone the ORIGINAL's mode into the temp
cat raw > "$f.mtmp"       # truncate in place -- a redirect does NOT change
                          # the mode of a file that already exists
mv -f "$f.mtmp" "$f"      # one rename, correct mode
```

All four write sites use that shape, and the harness now reports a mutant that
loses the exec bit as **DISCARDED — harness bug**, never as a finding about the
hook.

### `RotObserve` §17 — seven theorems on what a rename carries

| theorem | what it settles |
|---|---|
| `fresh_temp_drops_the_exec_bit` | replacing via a fresh temp yields a non-executable file, whatever the contents |
| `naive_atomic_replace_can_break_an_executable` | the bug exists — there is such a file |
| `cloned_temp_preserves_the_exec_bit` | **the repair**, for every file and every content |
| `cloned_temp_still_writes` | and it actually writes — a mode-preserving no-op would be the opposite failure |
| `cloned_temp_changes_only_the_content` | the general form: a clone changes **only** the content, so a future field cannot quietly escape |
| `restore_via_clone_preserves_exec` | the restore path too, not just the mutation |
| `naive_replace_is_harmless_when_nothing_is_executable` | records that "it worked on my machine" was **true** and useless |

The lesson generalises past file modes: **a replacement carries every attribute
of the replacement, not of the thing replaced.** Anything the original had and
the new object was not given is lost at the instant of the swap — so the temp
must be built *from* the original, never from nothing.

`#eval` reproduces the failure: naive → `{ content := 22620, exec := false }`,
cloned → `{ content := 22620, exec := true }`. Build exit 0, zero warnings both
trees, `leanchecker` exit 0, mutants **M49–M51** all killed.

Counts: **546 theorems / 22 modules / 19 suites / 249 mutants**.

---

## A SIGKILL left a mutated router on disk, one `git add -A` from being published

Measured three times in one session on 2026-08-07. A commit whose gate run
exceeded a wall-clock ceiling had its **entire process tree SIGKILLed**. The
mutation checker's `trap ... EXIT INT TERM` is correct and did not help:
**SIGKILL cannot be trapped**. What was left on disk:

```
hooks/rot-router.sh          MUTATED -- STEMS_STEALTH missing 'token compress'
hooks/rot-router.sh.mutbak   the only surviving copy of the original
```

A live mutant in a **shipped** hook. `git add -A` at that moment would have
published a router that no longer routes STEALTH on `token` or `compress`, with
a commit message describing a fix.

### Recovery cannot depend on a signal handler

| where | what changed |
|---|---|
| `checker/mutate-checker.sh` | recovers **at start-up**: a `.mutbak` present before this run made one means the last run died, so the backup is the truth — restore it, say so loudly, continue |
| `checker/repo-complete.sh` | **refuses any commit** while a `.mutbak` exists, and prints the restore command |
| `lean/mutate/mutate_rotobserve.sh` | `MUT_ONLY="M45 M46"` runs a chunk; a filtered run prints **PARTIAL** and exits 3, never 0 |

The restore instruction is deliberate and it is the opposite of a cleanup:
**never delete a stray `.mutbak`.** The backup *is* the original. Deleting it
promotes the mutant to the real file — the one irreversible move available here.

The chunking exists because the suite reached 48 mutants and each rebuilds the
module, so a full pass outgrew the ceiling that caused the kill in the first
place. A chunk that could pass for a suite would be far worse than the timeout,
hence exit 3 and a banner naming how many mutants were **never applied**.

### `RotObserve` §16 — nine theorems on interrupted mutation

| theorem | what it settles |
|---|---|
| `recoverable_before_backup` / `recoverable_after_backup` | interruption before or between the two steps is harmless |
| `backup_then_mutate_is_recoverable` | **backup first** and every interruption point is survivable |
| `mutate_then_backup_can_lose_the_original` | the other order loses it outright — the order is not a style choice |
| `restore_recovers` | restoring returns exactly the original |
| `restore_idem` | recovering twice is safe, so start-up recovery may run on an already-repaired tree |
| `restore_clears_the_backup` | a repaired tree cannot be mistaken for an interrupted one |
| `dropping_the_backup_loses_the_original` | deleting a stray backup destroys the last copy |
| `save_mutate_restore_round_trips` | the whole cycle returns the tree exactly as it was |

`#eval` on the measured bytes: `{live := 22614}` → mutate → `{live := 22620,
backup := some 22614}` → restore → `{live := 22614, backup := none}`; and
`dropBackup` on that middle state leaves `{live := 22620, backup := none}` —
the original gone. Mutants **M45–M48**, all killed, after M48 was first reported
**DISCARDED** by the harness's own did-it-apply check for inserting two
definitions instead of one.

Counts: **539 theorems / 22 modules / 19 suites / 246 mutants**.

---

## `hook 0.09 != corpus 0.09` — the gate was right and its message was useless

CI run 31148233876, `checkers (windows-latest)`, step "gauge hook corpus": six
rows failed, every one of them reporting two values that **render identically**.
Ubuntu and macOS passed the same commit.

The runner checks out with `core.autocrlf=true`. There was no `.gitattributes`,
so `checker/gauge-corpus.tsv` arrived with CRLF, the last tab-separated field
became `0.09\r`, and the comparison against the hook's `0.09` correctly failed.
A carriage return has no glyph, so the diagnostic printed the difference away.

**The gate was not wrong. The instrument could see a difference it could not
show** — and that cost an hour that the bytes would have given away instantly.

### Three layers, because one is not enough

| layer | what it does |
|---|---|
| `.gitattributes` (new) | `* text=auto eol=lf` — the working tree is LF on every platform, so a checker reads the bytes that were committed |
| `checker/gauge-hook-corpus.sh` | strips CR from **every** field, not just the last, and escapes CR/TAB in failure messages so two different values can never print alike |
| `checker/portability.sh` phase 7 | refuses any file carrying CRLF **in the index**, with a control that plants one, plus an assertion that `.gitattributes` still pins `eol=lf` |

`git add --renormalize .` fixed **16 files that were already committed with
CRLF** — 13 `.codemap` JSONs, both EUPL licence texts, and
`checker/corpus-remind.txt`. No attribute can repair those; the bytes are in the
index and every clone gets them.

Phase 7 distinguishes two cases on purpose. CRLF **in the index** is a failure:
it reaches every clone and no setting undoes it. CRLF **in the working tree over
an LF index** is only a NOTE, because git normalises it on `add` and nothing
wrong can reach the index — failing there would turn a legitimate local
generator into a red build and invite deleting the check, which is how real
coverage gets destroyed.

### `RotObserve` §15 — six theorems on the two halves of the repair

| theorem | what it settles |
|---|---|
| `shown_can_hide_a_real_difference` | a terminal CAN render two different fields identically — the defect, as a property |
| `stripCell_ignores_trailing_cr` | normalisation recovers the comparison, for every field |
| `stripCell_ignores_cr_anywhere` | CR mid-record too — why the checker strips every field, not the last |
| `stripCell_faithful` | **normalisation never invents agreement**: CR-free fields that normalise equal WERE equal |
| `stripCell_idem` | stripping twice is stripping once, so defensive normalisation cannot change a verdict |
| `escape_injective` | different fields print differently — the property the repaired message needed |

`stripCell_faithful` is the one that matters. Stripping bytes before a
comparison is one careless step from disarming the gate, and that theorem is
what says the repair is not a weakening.

Build exit 0 with **zero warnings in both trees** — the `simp` sets are squeezed
from `simp?` because mathlib's flexible-simp linter rightly refuses a proof that
rests on whatever `simp` does next release. `leanchecker` exit 0. `#eval`
reproduces the CI defect: `shown` equal while the fields differ, `stripCell`
equal, `escape` different. Mutants **M41–M44**, all killed.

Counts: **530 theorems / 22 modules / 19 suites / 242 mutants**.

---

## The A/B ran: the pre-registered endpoints came back NULL, and cost fell 31.6%

**80 paired turns with the plugin armed against 80 with it disabled**, same 80
prompts in the same order, same config directory, tools off in both arms.
Protocol frozen in advance, with three amendments each recorded before the data
they affect. Arm A verified routed (111 route records); arm B verified unrouted
(**zero**). 80/80 valid turns per arm, zero errors in either.

### The pre-registered primary endpoints did not support the hypothesis

| endpoint | routed | unrouted | 80 paired |
|---|---|---|---|
| trailing question | 0.000 | 0.000 | 80 ties |
| self-narration | 0.000 | 0.000 | 80 ties |
| hedging tokens | 0.037 | 0.000 | routed **worse** on 3, better on 0 |

Written plainly because the protocol required it in advance: **the claim that
routing improves these three voice properties is not what the data shows.**

Two of the three could not have shown anything -- the unrouted arm already
scored zero, so there was no room to improve. That is a defect in the ENDPOINT,
not a result about the router, and `RotObserve` §14 now proves the distinction
rather than leaving it as an excuse.

### A secondary metric moved hard, and it stays secondary

| metric | routed | unrouted | delta | paired sign count |
|---|---|---|---|---|
| cost per turn | $0.1013 | $0.1481 | **-31.6%** | cheaper on **75 of 80** |
| response length | 584 ch | 762 ch | -23.4% | shorter on 67 of 80 |
| duration | 10.1 s | 13.5 s | -24.6% | faster on 51 of 80 |
| is_error | 0 | 0 | -- | 80 ties |

75 of 80 is not noise. It is also not a result this protocol may claim, because
cost was pre-registered as descriptive. Promoting a metric to the headline after
watching it move is the exact laundering the pre-registration exists to stop, so
it is recorded as the hypothesis for a round 2 that names it primary in advance.

**Not measured: whether the answers are as good.** The only rater available is
the model that wrote them. Cheaper and shorter is an improvement only if the
content survived, and nothing here establishes that. Round 2 needs a mechanical
groundedness proxy -- does the answer name the file, lemma or constant it was
asked about -- so brevity cannot be bought with emptiness.

### Three defects the run found, none of which a theorem would have

1. **CTT was running a router killed at 30 s.** Starting an hour earlier would
   have made arm A a second arm B and produced a false null.
2. **The first disarm did nothing.** Emptying `installed_plugins.json` left the
   plugin firing: 16 turns, **39 route records**. Caught only by the harness's
   own "arm B must be zero" control, and those turns were deleted. The real
   switch is `enabledPlugins`; arm B now uses `claude plugin disable`.
3. **A benchmark turn executed `checker/axiom-audit.sh` against this repo.**
   Run 1 of arm A was discarded and archived for it, with the reason recorded
   before any answer text was read.

`checker/ab-session.sh` collects and refuses a pass on an empty collection;
`checker/ab-analyze.sh` computes only the frozen metric list; `bench/ab-prompts.txt`
holds the 80 prompts so neither arm can drift from the other.

### `RotObserve` §14 -- seven theorems about what an endpoint can attribute

| theorem | what it settles |
|---|---|
| `floor_endpoint_cannot_improve` | a control arm at zero admits no improvement -- for every endpoint |
| `improvement_requires_room` | the positive form, checkable BEFORE collecting data |
| `equal_arms_attribute_nothing` | a tie is not weak evidence in either direction |
| `control_at_least_treated_attributes_nothing` | the metric-9 case: 9 routed vs 12 unrouted attributes exactly nothing |
| `attributable_le_difference` | the control count bounds what the mechanism can be blamed for |
| `an_endpoint_can_be_worse_when_treated` | the design must be able to express a loss, or it is not a test |
| `all_ties_leave_no_sign_count` | 80 ties is the same evidence as one tie: none |

Build exit 0, zero warnings; axioms `propext`/`Quot.sound` (`Classical.choice`
for the list theorem), no `sorryAx`; `leanchecker` exit 0. `#eval` reproduces the
measured numbers: attributable 0 for the leak metric, 3 for hedging, `(0,0)`
sign counts on 80 ties. Mutants **M37-M40**, all killed.

Counts: **523 theorems / 22 modules / 19 suites / 238 mutants**.

---

## The router was being killed at 30 seconds, and a killed hook is silent

**Measured 2026-08-07 by the maintainer, found by accident.** Opening the debug
view (CTRL+O) showed the router **timing out** on real prompts. Neither install
path declared a `timeout`, so Claude Code's default of 30 s applied — and a hook
that reaches its limit is killed outright. It contributes nothing: no marker, no
lane, no gauge, not even a partial line.

**The observable is identical to having no hook installed at all.** That is why
this survived every session log and every transcript sweep, and it means earlier
readings of the form "the router did not fire here" cannot be trusted; they are
consistent with a router that fired and was killed. `RotObserve` §13 states it:
`silenced_is_indistinguishable_from_absent` proves the two observations are
*equal*, not merely similar.

The work is proportional to the traffic — nine lens activities computed per turn
over the prompt **and** the reply — so a bound sized for a trivial script is the
wrong shape of bound, not just a small one.

**Both install paths now declare 1200 s**: the five entries in
`hooks/hooks.json` (marketplace) and `HOOK_TIMEOUT_SECONDS` in
`hooks/settings-merge.js` (hand install), which previously appended entries with
no bound at all.

`checker/hook-timeout.sh` is new, and it deliberately **does not pin 1200**:

| phase | what it asserts |
|---|---|
| declared | every shipped hook entry carries a numeric `timeout` |
| single | one bound across all events, not one per event |
| used | the constant is written into the entry, not merely defined |
| agreement | the two install paths are compared **to each other**, never to a literal |
| adequacy | the bound exceeds the 30 s default it exists to replace |
| controls | stripped timeouts detected; a bound equal to the default rejected; two different bounds distinguished |

So the number may legitimately move to 900 or 1800 and the checker still refuses
a missing bound, a disagreeing pair, or a pointless one. 9 passed, 0 failed.

`RotObserve` §13 — six theorems, none of which mention 1200:

| theorem | what it settles |
|---|---|
| `killed_hook_emits_nothing` | a hook past its bound emits nothing, for every bound and every work |
| `silenced_is_indistinguishable_from_absent` | that observation **equals** the no-hook observation |
| `completion_is_monotone` | raising the bound never loses an observation |
| `an_adequate_bound_is_observed` | whenever the bound covers the cost, the marker appears |
| `the_default_silenced_real_work` | the measured instance: 600 s of work is silent at 30 s, observed at 1200 s |
| `different_bounds_are_different_products` | for **any** two distinct bounds there is work they disagree on — the theorem behind the agreement phase |

Build exit 0, zero warnings; axioms `propext` (and `Classical.choice`/`Quot.sound`
for the existence proof), no `sorryAx`; `leanchecker` exit 0. `#eval` confirms
`hookOutput 30 ⟨600⟩ = none` and that it compares **equal** to `absentOutput`.
Mutants **M33–M36**, all killed, 0 survived, 0 discarded. The gate table and `RotGates.lean` both gain the new checker — 38
gates, 25 fast — and `gate-split` confirms shell and Lean still agree, 12/12.

Counts move to **516 theorems / 22 modules / 19 suites / 234 mutants / 50 checkers**.

---

## The commit gate was overwritten again — and the audit for it cannot run

**Second occurrence, measured 2026-08-06 21:41:17.** An unrelated local tool
wrote `.githooks/pre-commit` wholesale, replacing the gate with its own indexing
hook whose header states `Never blocks a commit: every failure path exits 0`.
`core.hooksPath` is `.githooks`, so the commit gate was disarmed from that moment.

Dating it is what kept the record honest: the overwrite is **21:41:17**, the last
commit is **21:32:29**, so every commit actually recorded had run the real gate.
No ungated commit exists. Restored from `HEAD` — 5819 B, 7 `gate-all` references.

`checker/workflow-lint.sh` **does** catch the substitution, measured both ways:
planted hook → exit 1 with `never calls gate-all` / `no refusing path` /
`no delegates`; real hook → exit 0, 156 passed. The detector is not the problem.

**Reachability is.** Locally that detector runs *because the pre-commit gate
invokes it* — so when the gate is what has been replaced, the detector is exactly
what stops running. An audit that reaches itself through the thing it audits is
silent in precisely the state it exists to report.

Two repairs, one of them out of band by construction:

- `.git/hooks/pre-commit` is now checked. It was inert (`core.hooksPath` points
  elsewhere) and it held the same never-blocking hook — one
  `git config --unset core.hooksPath` from a silently ungated repository. Absent
  is the safe state and passes, so a fresh clone and CI are unaffected.
- The local copy was removed; the gate at `.githooks/pre-commit` is the only
  pre-commit hook on this machine again.

`lean/Proofs/RotObserve.lean` §12 states the shape rather than the incident:

| theorem | what it settles |
|---|---|
| `gate_admits_exactly_green` | the real gate admits exactly the green trees |
| `permissive_admits_everything` | the replacement admits every tree, for all trees |
| `swap_makes_admission_uninformative` | so a red tree gets recorded — admission stops carrying information |
| `in_band_detector_is_blind_to_its_own_replacement` | the in-band audit returns the SAME verdict in both worlds; it is indistinguishable from a working audit |
| `out_of_band_detector_sees_the_replacement` | only a verifier independent of the hook separates them |
| `out_of_band_alarm_is_exact` | and it fires on exactly the bad world — no false alarm on the good one |

Build exit 0 with **zero warnings**; `out_of_band_alarm_is_exact` rests on
`propext`, the rest on nothing beyond it, no `sorryAx`; `leanchecker` exit 0, zero
bytes; delivered green to the shared workspace. Mutants **M29–M32** — all killed,
0 survived, 0 discarded.

Counts move to **510 theorems / 22 modules / 19 suites / 230 mutants**.

---

## A checksum that agrees with its archive is not provenance

**Found while publishing 0.9.x, and it was already uploaded.** `release-package.sh`
builds the archives **from the working tree** and computes `SHA256SUMS.txt` **from
those archives**, in one pass. The tree still held two uncommitted files, so the
published `rot-moe-0.9.1-lean.zip` measured **855097 B** against a tag whose tree
builds **854497 B**.

Nothing was red. The published digest matched the published archive perfectly,
because both had been regenerated together — a self-consistent pair describing a
tree that **no tag points at**. Downloading the asset and recomputing its SHA256
re-runs that same pair and cannot see the substitution. It was caught by comparing
the uploaded byte size against the size measured at package time: 598 bytes.

Repaired by stashing the two files, rebuilding on the clean tree, deleting every
published asset and re-uploading. Verified end to end afterwards: the downloaded
`v0.9.1` (854497 B) hashes to `481974a7a2dfec10…`, equal to its published
`SHA256SUMS.txt`.

`lean/Proofs/RotObserve.lean` §6 states the gap rather than the incident, so it
cannot expire when the bytes move:

| theorem | what it settles |
|---|---|
| `packaging_always_passes_integrity` | integrity holds **by construction** for whatever tree was packaged — it is a tautology about packaging, not evidence about the release |
| `integrity_cannot_detect_the_wrong_tree` | for every pair of distinct trees: the digest verifies **and** provenance is false |
| `redownload_re_runs_the_blind_check` | re-downloading and recomputing repeats the same blind check; it distinguishes nothing |
| `rebuilding_from_the_tag_restores_provenance` | the repair that was actually applied |
| `provenance_iff_same_tree` | provenance **is** tree equality — quantified over trees, so no constant can date it |

`digestOf` is only assumed deterministic. Nothing here is a hash weakness: the gap
survives a *perfect* hash, because it is a question about which tree was packaged,
not about collisions.

Build exit 0 with **zero warnings**; axioms `propext, Classical.choice, Quot.sound`
(`provenance_iff_same_tree`: `propext` alone), no `sorryAx`; `leanchecker` exit 0,
zero bytes; delivered green to the shared Lean workspace. Mutants **M12–M14**
added — every mutant then declared killed, 0 survived, 0 discarded.

Counts move to **495 theorems / 22 modules / 19 suites / 221 mutants**.

---

## An audit that silently narrows its own scope — `grep -q` under `pipefail`

CI run 31118671400's predecessor caught something the pre-commit tier could not:
`checker/mutant-discipline.sh` audited **21** harnesses on ubuntu and **23** here,
and reported PASS both times.

The cause is a shell trap this repository had already recorded in another form.
The selector was `sed 's/#.*$//' "$f" | grep -qE 'killed|survived|discard'` inside
a script running `set -o pipefail`. **`grep -q` exits at the first match**, `sed`
is then killed by SIGPIPE, and `pipefail` reports the whole pipeline as failed —
so `|| continue` skipped a file that *matched*. It is a race between `sed`
finishing and `grep` exiting, which is why it is platform-dependent: measured
`rc=0` on Git Bash here, and it dropped two suites on ubuntu.

`grep -c` consumes all of its input, so there is no SIGPIPE and no race. The count
is then tested explicitly, with `: "${_hits:=0}"` because `grep -c` prints `0`
**and** exits 1 when there is no match — the second half of the same trap.

It was caught only because the classifier repair shipped with a CONTROL asserting
every `mutate_*.sh` suite is still selected. Without it this was a green run
auditing two fewer harnesses than it claimed.

The general shape is now proved rather than described, in `RotObserve.lean` §7 —
a gate reports PASS over the items it *selected*, and selection can silently lose
items:

| theorem | what it settles |
|---|---|
| `passing_audit_can_hide_a_failure` | a passing audit does **not** mean every candidate passed |
| `the_verdict_cannot_see_the_drop` | the verdict is identical whether the dropped item would pass or fail — re-reading it can never reveal the gap |
| `control_detects_the_drop` | a control over a known-required set **does** detect it |
| `control_holds_when_nothing_is_dropped` | and that control can pass, so it is a test and not a refusal |

`#eval` reproduces the measured shape exactly: 23 required, a selector that loses
one, `auditPasses = true` over **22** judged items, `controlHolds = false`.

Mutants **M15–M17** — the control neutered to `true`, the audit made to judge
everything, and the control weakened from `all` to `any`, which is the plausible
version someone writes by accident. All three killed: every mutant then declared killed,
0 survived, 0 discarded.

---

## Twenty failed turns, exit 0 — the evidence counter incremented in the failure path

The CTT re-test after the gauge work came back green. It should not have.

```
turn 1..20: claude exit 1 (timeout or error) -- recorded, not hidden
ran 20 turn(s), 20 failed; route records written this run: 20
CTT_EXIT=0
```

**Twenty of twenty turns failed and `checker/ctt-session.sh` exited 0.** Its
refusal asked a reasonable-sounding question — *were any route records written?*
— and twenty had been. The router hook fires when the prompt is **submitted**,
before the turn reaches the API and dies. So the counter the verdict rested on
**increments in the failure path**, and a pass condition built on it is satisfied
by total failure.

This is not the §7 defect repeated. There the verdict was blind to items it never
selected; here every turn *was* selected, and the signal read cannot tell success
from failure. Both end in a green run; only one is fixed by a control over
selection.

**The cause of the failures was sitting in every payload.** The CLI writes its
reason into the JSON even when it exits non-zero, and the per-turn line threw it
away — twenty mute `exit 1`s for a diagnosis the *first* turn already had:

```
turn 1: claude exit 1 -- Failed to authenticate: OAuth session expired
                         and could not be refreshed
```

The CTT credential had gone stale (`expiresAt: 0`, a 281-byte stub against the
live 509). Refreshed by cloning the live credential into the CTT config dir —
the mechanism `marketplace-session.sh` already uses — and backed up first.

Both halves are now fixed: the reason is surfaced per turn, and a run in which
**no turn succeeded** refuses at exit 2 regardless of how many records the hook
wrote on the way down.

Measured after the repair: **20 turns, 0 failed, 32 route records, 0 trace
leaks.** Negative control, run end to end by planting the stale credential back:
exit **2**, *"every one of 1 turn(s) FAILED — 1 route record(s) were still
written"*, then restored to exit 0. The control demonstrates the exact hole: a
record was written for a turn that failed.

`RotObserve.lean` §9 states it over arbitrary runs rather than over twenty:

| theorem | what it settles |
|---|---|
| `total_failure_passes_the_side_effect_verdict` | the measured run exactly — 20 failed, 20 recorded, verdict **true** |
| `side_effect_verdict_is_blind_to_outcomes` | two runs with the same records get the same verdict **whatever** their outcomes — re-reading that log line can never reveal it |
| `success_aware_verdict_detects_total_failure` | reading outcomes does detect it, for any run |
| `success_aware_verdict_still_passes_a_real_run` | and it is a test, not a refusal — the over-correction is excluded |

`#eval` reproduces the incident: `sideEffectVerdict = true` and
`successAwareVerdict = false` on the same 20 failed-but-recorded turns, with
`recordsOf = 20`.

Mutants **M21–M23**: the repair reverted to the blind verdict, the blind verdict
taught to read outcomes, and the over-correction that refuses everything. All
killed — every mutant then declared killed, 0 survived, 0 discarded.

---

## A step that could only SKIP — the last real skip in CI is closed

Three lines in every green run, on ubuntu, macos and windows:

```
SKIPPED: no built Lean workspace -- NOT a pass
```

`gauge-cross.sh` compares the Lean `Float` mirror against the running hook, and
needs a built Lean workspace. The `checkers` job has none. The label was honest,
and the step was still a hole — **it had no reachable PASS**. A step that cannot
pass cannot fail either, so those three lines carried exactly as much information
as a blank line, in a run reported green.

**Not repaired by deleting it, and not by installing a mathlib toolchain on three
platforms.** The two arms differ in what they depend on, and that is the whole
fix:

| arm | depends on | so it runs |
|---|---|---|
| Lean mirror | the same `.olean` on every runner — **platform-independent** | once, in the `lean` job, where a skip is already a hard failure |
| running hook | `awk` in a POSIX shell, and the locale — **not** platform-independent | on all three platforms, against a recorded corpus |

New: `checker/gauge-corpus.tsv` (six rows, chosen for shapes that behave
differently) and `checker/gauge-hook-corpus.sh`, which has **no exit 3 at all**.
Measured on Windows: 9 passed, 0 failed. Negative control: a single corrupted
expectation is caught at exit 1, naming the row. A decimal comma is reported *as*
a decimal comma, because that is a failure mode this repository has already been
bitten by.

**The corpus cannot become a snapshot.** `gauge-cross.sh` now reads the same file
and re-derives every expected value from Lean, failing if they disagree:

```
FAIL  row 5: checker/gauge-corpus.tsv says 0.98 but Lean says 0.97
      -- the corpus has DRIFTED from the model; re-derive it, never hand-edit it
```

Measured in both directions: drift → exit 1, restored → exit 0. So the only way
to change a number in that file is to change the model.

`workflow-lint` then caught the next mistake immediately — *"`gauge-hook-corpus.sh`
is never run by `gate-all` — the local commit gate is WEAKER than CI"* — and it is
now registered in the fast tier. 156 passed, 0 failed.

`RotObserve.lean` §8 proves why the split is sound rather than convenient:

| theorem | what it settles |
|---|---|
| `a_step_that_only_skips_is_not_evidence` | a step whose outcome never varies distinguishes **nothing** — not a weak check, not a check |
| `agreement_with_a_corpus_says_nothing_about_the_model` | hook-matches-corpus can hold while **both** differ from the model |
| `verified_corpus_transfers_to_the_model` | re-deriving the corpus is exactly what makes the platform check transfer |
| `the_corpus_step_is_evidence` | the replacement reaches **both** outcomes, so it can fail as well as pass |

Mutants **M18–M20**: the always-skipping step given a reachable outcome, the
corpus re-derivation neutered to `true`, and the new step made unable to fail.
All killed — every mutant then declared killed, 0 survived, 0 discarded.

**One skip remains in CI, and it is a boundary, not an omission.**
`marketplace-session.sh` needs the maintainer's own Claude credentials for its
live turn. Putting those in repository secrets is a security decision that
belongs to the maintainer, and planting a fake credentials file would make the
step exit 0 while proving nothing — the precise fake green this project refuses.
It exits 3, says so, and is enforced off the runner twice: `gate-all --full`
locally, and the CTT instance before any version ships.

---

## The three numbers are not a roadmap

`0.9.0`, `0.9.1` and `0.9.2` are **released together, on the same commit**. The
version *is* the variant. Nothing in `0.9.1` supersedes `0.9.0`; it adds a
Lean 4 workshop on top of it. Nothing in `0.9.2` fixes `0.9.1`; it unseals a
tactic that `0.9.1` withholds **by policy**, and ships the instrument that keeps
that honest.

| pick | if you want |
|---|---|
| `0.9.0` Pure Router | the nine-lane router and nothing else. No Lean, no toolchain, no network. |
| `0.9.1` Router + Lean 4 | the same router **plus the machine that makes the theorems** — bounded installer, official hosts, your own proved repos. |
| `0.9.2` Router + Lean + Extra | all of the above with `native_decide` unsealed, and `checker/axiom-class.sh` to tell KERNEL from COMPILER trust. |

The patch digit **is** the tier, and it has been for every release in
[`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md): `0` core, `1` lean, `2` unsealed.
`.claude-plugin/plugin.json` carries the `.2` by convention, so a **directory- or
git-sourced** marketplace install reports `0.9.2` — it is installing the tree,
and the tree is the unsealed superset. The `.0` and `.1` tiers are what the three
`.release/` archives carve out of it, which is why
`checker/release-package.sh` builds all three from one commit and now derives
their versions from that manifest instead of a hardcoded triple.

---

## PRIOR → AFTER, at a glance

Every row was **measured on the shipped code**, before and after. This table is
the whole release in one screen; the sections beneath it give each row its
evidence.

| # | what | PRIOR (0.6.2, measured) | AFTER (0.9.x, measured) |
|---|---|---|---|
| 1 | router firings per prompt, documented install | **2** — plugin *and* `settings.json` both bind it | **1** — `ARM_ROUTER` detects the plugin and refuses |
| 2 | `DISARM_ROUTER --dry-run` | flag **ignored**; entries deleted for real | previews against a copy, writes **nothing** |
| 3 | uninstalling a plugin-path entry | **impossible** — exact match, `nothing to remove`, exit 0 | `--all` removes it; exact mode says what it cannot reach |
| 4 | unknown installer argument | silently **ignored** | **exit 2**, refused by name |
| 5 | proof scan depth | **one level** (`*.lean` in the root only) | **recursive**, both arms |
| 6 | staleness on a real subfoldered tree | **2947 min** reported | **54 min** — the truth, a 55× error removed |
| 7 | workspace chain | `env → recorded → bundled`; **nothing wrote `recorded`** | `env → recorded → **discovered** → bundled` |
| 8 | recorded path from the POSIX installer | POSIX form; PowerShell `Test-Path` **rejects it** | drive-letter form, readable by **both** arms |
| 9 | `prove this lemma` | **CONVERGENT** — no lane fired | **FORGE Claude** |
| 10 | `prove … bytes in lean` | **STEALTH** — it matched `byte` | **FORGE Claude** |
| 11 | `improve the documentation` | would hit `prove` if the stem were added | **CONVERGENT** — stems must start a word |
| 12 | `add a prefix to the name` | **CLINICAL** — `fix` fired inside "prefix" | **CONVERGENT** |
| 13 | debug log verification | sum of logged terms only, POSIX arm only | **every factor** re-derived, both arms, pairing checked |
| 14 | theorems / modules | 205 / 14 | **495 / 22** |
| 15 | gates | 29 | **35** (23 fast, 12 deep) |
| 16 | mutation suites | 10 suites | **19 suites — every mutant declared killed**, 0 survived, 0 discarded |
| 17 | why a lane fired | **not recorded** — a log could be fully replayable with the disputed fact absent | the **matched stem**, from a closed 85-word table |
| 18 | auditing someone else's log | impossible — the replayer only read logs it generated | `log-replay.sh --audit <file>` |
| 19 | "the log leaks no prompt text" | an assurance nothing checked | `auditable_imp_vocabSafe` — **entailed** by passing the audit |
| 20 | `files containing sorry` | **1**, and false: the counter matched the WORD in the router's stem table | **0**, string literals excluded, both directions controlled |

Rows 1–8 are defects that **had already reached a live machine** while
twenty-nine gates were green. Rows 9–12 are a routing fix that could not be made
until the matcher itself was specified. Row 13 is the instrument that would have
caught a drift nobody was watching for.

> **Why the PRIOR column never restates an old total.** `checker/repo-complete.sh`
> re-measures every "N applied, M killed" in this file against the suites as they
> exist **today**, and the newest section is scanned in full — a prior-versus-after
> table lives inside it. Writing the previous release's total there would put a
> correct historical number where the checker can only read it as a false present
> claim. The PRIOR cells therefore say what *changed* (ten suites became eighteen);
> the settled totals stay in
> [`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md), which is exempt as history.
> The alternative — loosening the rule so it skips table rows — would have put a
> hole in the one check that stops a mutation claim from drifting.

---

## [0.9.0] · [0.9.1] · [0.9.2] — 2026-08-06

Three archives, one tree. The patch digit is the tier: `0` core, `1` lean,
`2` unsealed.

**Every defect fixed in this release had already reached a live machine while
twenty-nine gates were green.** That is the only sentence of this entry that
matters, and it is the reason four of the additions below are gates rather than
features.

### Added — `Proofs/RotObserve.lean`: five readings that report less than the truth

Written **after** publishing, from the install of the published `0.8.2` into a
real second Claude configuration and a 20-turn session held against it. Four
times in one afternoon an observation reported less than the truth, and three of
the four invited the same wrong inference — *absence of evidence in a lossy
channel read as evidence of absence*:

| measured | the wrong inference it invited | the truth |
|---|---|---|
| `settings.json` byte-identical before and after the plugin install | "the install did nothing" | three hook events bound; the router fired 39 times |
| `validate` piped to `head` reported `rc=0` on a 4-error manifest | "the artifact is valid" | the tool exits **1**; `head` exits 0 |
| `plugin update rot-moe` → `Plugin "rot-moe" not found` | "the plugin is not installed" | installed and enabled; the *query* was unqualified |
| `marker seen in 0 transcript(s)` over 20 turns | "the hook never fired" | 39 route + 39 gauge records logged |
| `plugin update` → `already at the latest version (0.8.2)`, exit 0 | "the install carries the fix" | cache held a stale `ctt-session.sh`, `README.md`, `CHANGELOG.md`, and no `RotObserve.lean` |

**23 theorems, 11 mutants, 11 killed, 0 survived, 0 discarded.** The module states
each silence as a property of the *instrument*, so it is documented rather than
rediscovered as a panic:

- `settings_alone_cannot_decide_armed` — two installs can agree on every byte of
  `settings.json` and disagree on whether the router runs. The durable form: the
  file is not a sufficient observation of armedness.
- `guard_still_leaves_it_armed` — `ARM_ROUTER` refusing to write is not failing
  to work. After the guard runs the router is armed on **every** branch, which is
  why the refusal against an already-plugged host is correct.
- `green_filter_masks_every_failure` — quantified over the exit code, not stated
  about the `1` that was measured: **no** status survives a filter that always
  succeeds. `piped_reading_is_blind` follows — the reading cannot tell success
  from any failure.
- `bare_name_never_resolves` — a length argument over arbitrary names, so it
  holds for every plugin rather than for the one that was typed; and
  `lookup_failure_is_not_absence` closes the inference.
- `any_number_of_firings_can_be_invisible` — for **every** `n` there is a run
  with `n` firings and zero markers. 39-and-0 was not a coincidence; it is the
  only thing the internal-only seal permits. `markers_zero_iff_all_sealed` gives
  the checker's note its actual meaning: it reports the **seal**, not the router.

- `force_update_at_same_version_reaches_no_install` — **this one changes how a
  release is shipped.** Measured after force-updating the tree without moving the
  version: `claude plugin update rot-moe@rot-moe` answered *"already at the
  latest version (0.8.2)"* at **exit 0**, while the installed cache still held
  the old `checker/ctt-session.sh`, an old `README.md`, an old `CHANGELOG.md` and
  no `RotObserve.lean` at all. Nothing was broken — the updater compares the
  version **string**, and the string had not moved. The theorem is quantified
  over every version and every pair of differing contents, so it is a statement
  about the mechanism rather than about the tag that was measured.
  `only_a_moved_version_is_visible` gives the repair; `fresh_install_is_always_current`
  and `reinstall_succeeds_where_update_is_blind` record the path that *does*
  deliver — uninstall + install refreshed every stale file under the same `0.8.2`.

`blind_reading_cannot_decide` is labelled in-file as a **repackaging, not a
discovery** — `#print axioms` reports it depends on nothing, the signature of a
near-tautology, and its worth is entirely in the instances.

> **Operational consequence, stated because it is not obvious.** A force-updated
> tag at an unchanged version reaches **new** installs only. Anyone who already
> has the plugin will be told they are current and will receive nothing. That is
> not a defect in this project and not one in the CLI; it is what version-string
> comparison means. The honest options are a version bump or an explicit
> reinstall, and the theorem now says which is which.

Verified with all three instruments in both trees: `lake build` exit 0 with zero
warnings, 18 × `#print axioms` showing no `sorryAx`, `leanchecker` exit 0 with
zero bytes (control: a module with no oleans exits 1).

### Verified — the published `0.8.1` archive, installed and driven through the real CLI

Not the local `.release/` build: the asset was **downloaded from the release**
and its SHA256 compared against the published `SHA256SUMS.txt` —
`459246a47d3ebebe3254c9f3ab828c8a0d24efa7288286e648919890445662a2`, identical.
The bytes users get are the bytes that were built.

- `claude plugin validate` on the downloaded tree: **exit 0**, zero errors.
  Controls: a mangled manifest key → exit 1 with 4 errors, invalid JSON → exit 1.
  The validator can fail, which is the only reason its pass counts.
- `claude plugin update rot-moe@rot-moe` moved the test configuration
  **0.7.2 → 0.8.2** at exit 0; the installed cache's `rot-router.sh` and
  `hooks.json` are **byte-identical** to the tree.
- A **20-turn session** against the installed plugin: 39 route records and 39
  gauge records, every one `K=9` with nine lens terms, R/s+ recomputed from those
  terms on **all 39** to within 2e-5, and **8 distinct lanes** reached in real
  conversation. `checker/ctt-session.sh --report`: 4 passed, 0 failed.

### Fixed — a `paths:` filter does not restrain a tag push, and the run it wasted concluded `cancelled`

Found **while publishing this release**, by auditing the runs the tag pushes
themselves triggered — which is the audit everyone skips, because the release is
already out by then.

`.github/workflows/tag-manager.yml` declared a push trigger filtered to
`.github/tags.txt` and **no `branches:`**. Pushing `v0.8.0`, `v0.8.1` and
`v0.8.2` in one command fired **three** runs of it, on a commit that does not
touch that file at all:

```
git show --stat --name-only 4a783a9 | grep -c "tags.txt"   ->  0
```

A path filter cannot be evaluated for a tag ref — there is no base to diff
against — so it restrains nothing. Only `branches:` excludes tags.

**The wasted runs were not the damage; the conclusion was.** That workflow holds
a single concurrency group with `cancel-in-progress: false`, and GitHub keeps at
most **one** pending run per group. The first ran, the second pended, and the
third's arrival **cancelled the second**. Tag `v0.8.1` therefore carried a run
concluding `cancelled` with `total_count: 0` — zero jobs ever dispatched.

`cancelled` is exactly what `checker/ci-honesty.sh:186-190` refuses. And tag
`v0.7.0` carries the same scar, which is how one structural defect passed for
bad luck twice.

**Why a cancelled run is uniquely dangerous, stated precisely:** it has *zero
failing steps*. Every step-level rule is **vacuously satisfied** by a run that
never started. Only the run-level check can see it — which is why the run
conclusion is checked separately from the steps, and why that separation is now
a theorem rather than a convention.

| layer | what it does |
|---|---|
| `tag-manager.yml` | `branches: [main]` added, with the measurement recorded in place |
| `checker/workflow-lint.sh` **R23** | every `push:` trigger carrying `paths:` must also constrain `branches:` — with **two** controls: the defective shape is detected, and a correct trigger is *not* flagged |
| `lean/Proofs/RotGates.lean` | six theorems, below |

| theorem | claim |
|---|---|
| `paths_do_not_restrain_a_tag` | a branch-less trigger fires on **every** tag, for **every** path list — quantified, so no path list can save it |
| `branches_exclude_every_tag` | any **non-empty** `branches` excludes every tag — the fix stated generally, not as "`[main]` works" |
| `the_fix_keeps_main` | the repair does not silence the intended trigger — a fix that muted the branch runs too would be a regression wearing a fix's clothes |
| `runConcludedHonestly` + `cancelled_is_not_honest` | only the literal `success` is green |
| `only_success_is_honest` | quantified over **any** string: nothing else passes, including conclusions GitHub has not invented yet |
| `empty_run_is_vacuously_step_clean` | `runIsHonest [] = true` — the vacuity spelled out, so nobody mistakes an all-green step list for evidence |

Three mutants (M11 / M12 / M13) → **13/13 killed** in that suite. M12 is the one
that matters: it widens the whitelist to admit `cancelled`, which is precisely
the "repair" someone reaches for when a cancelled run blocks a release.
`only_success_is_honest` makes that impossible to land quietly.

> **A harness note worth keeping.** All three mutants were `DISCARDED` on their
> first run with `needle=1 repl=1`, because each replacement *extended* its
> needle (`X` → `X || Y`) and the post-check requires the needle to be **absent**
> afterwards. That is the harness being right: an edit whose before-text is still
> in the file is not a clean mutation, and a suite that scored those as
> `SURVIVED` would have reported three robust theorems while testing nothing.

### Verified — the CTT round-trip, and four theorems confirmed against a live install

Before this release was tagged, the packaged `0.9.1` Lean variant was installed
into a **separate Claude Code instance** kept for pre-publish testing — a full
clone with its own `.claude` directory, credentials and plugin cache — and driven
end to end. (The absolute path is deliberately not printed here: `no machine-local
paths` refused this paragraph when it named one, which is the gate behaving
correctly.) Measured, in order:

| step | result |
|---|---|
| `ARM_ROUTER.sh` against the CTT instance | **refused** — the plugin already registers the router; arming again would fire it twice per prompt |
| `ARM_ROUTER.sh` against a clean scratch `HOME` | 124 B → 1515 B; **5 bindings across 3 events** (2 / 2 / 1) |
| every pre-existing scalar (`effortLevel`, `skipDangerousModePermissionPrompt`, `permissions.defaultMode`) | preserved byte for byte |
| second `ARM_ROUTER.sh` | settings hash **identical** — idempotent |
| `DISARM_ROUTER.sh` | `hooks` key gone entirely, **zero residue**, scalars unchanged |

Those four rows are the empirical counterpart of `arm_adds_the_hooks`,
`arm_preserves_all_scalars`, `arm_idempotent`, `disarm_removes` and
`disarm_preserves_all_scalars` in `lean/Proofs/RotInstall.lean` — and the 2 / 2 / 1
counts are exactly the `example`s converted from `#guard` in this release.

The router was then run **from the CTT plugin cache**, under CTT's own `HOME`:

| prompt | lane | `R/s+` | Lean `#guard` |
|---|---|---|---|
| `prove this lemma in lean` | FORGE Claude | 0.66 | `routerReading 8 == 0.66427` |
| `fix the failing test` | CLINICAL AntiVenom | 0.57 | `routerReading 2 == 0.57318` |
| `how do I feel about this` | EMPATHIC Violet | 0.31 | `routerReading 1 == 0.31386` |
| `compress the output` | STEALTH Soleil | 0.39 | `routerReading 6 == 0.38607` |

Every one agrees with the spec at the two decimals the route record carries.
This is the binding that makes `RotEnsemble.lean` a specification of the shipped
router rather than a self-consistent model: the numbers were re-measured through
an actual plugin installation, not recomputed in Lean.

**Stated as a limit:** the CTT plugin cache is a snapshot taken at `bc1272d`.
`hooks/rot-router.sh` and `hooks/hooks.json` in it are **byte-identical** to the
current tree, so the routing evidence above is evidence about today's code; only
`.claude-plugin/plugin.json` differs, and only in the theorem-count metadata.

### Fixed — a warning inside a green log: git CRLF advisory ×4

`checker/verdict-schedule-sim.sh` builds scratch git trees. On a Windows runner
git printed, four times into a fully passing log:

    warning: in the working copy of 'STATUS.md', LF will be replaced by CRLF

Every check in that step passed, so nothing was broken — which is precisely why
it is worth removing. A green log that contains warnings teaches everyone reading
it to skim past warnings. The scratch trees now set `core.autocrlf false`; the
simulator's subject is the scheduling rule, not line endings, and the real
repository is untouched. Re-measured on Windows: **10 passed, 0 failed, 0
warnings**.

### Fixed — 70 build warnings that no gate was reading, and one understated theorem

`lake build` exited 0 on every platform and **printed 70 warnings**, in a job
whose conclusion was `success`. Nothing failed, so nothing looked wrong. Measured
from the run archive and reproduced locally at the identical count — 60 in
`RotEnsemble.lean`, 10 in `RotInstall.lean`.

**One of them was a real weakness in a theorem, not a style complaint.**
`activity_vector_determined_by_eight` took eight hypotheses and its proof used
**two**. The linter said six binders were never referenced; the honest reading is
that the theorem was *understated*, because Claude's activity is fixed by
AntiVenom and Soleil alone. Renaming the binders to `_h1 …` would have silenced
the warning and preserved the weaker claim, so instead:

* `activity_vector_determined_by_two` — the strong statement,
* `activity_vector_determined_by_eight` — kept for anyone searching for it, now
  **derived** from the two-hypothesis version so the file cannot drift back,
* `six_lenses_may_differ_and_claude_still_agrees` — an explicit pair of signal
  states differing on all six free lenses while Claude is forced to agree, so the
  gap is exhibited rather than asserted.

Two further over-assumptions came from the same sweep: `bump_at` and `bump_ne`
were dragging in `[Fintype ι]` they never used (now `omit`ted — they hold for
infinite index types), and `quiet_entropy_is_zero_at_any_breadth` carried a
`[Fintype ι]` that `allQuiet = fun _ => false` never needed.

The remaining 46 were `mathlibStandardSet` objecting to `#`-commands. Handled in
**two different ways, because the right fix differs**:

* `RotInstall.lean` — nine `#guard`s became `example … := by decide`. Strictly
  better: same computation, but each leaves a proof term for `leanchecker`. This
  is the conversion `RotDorks.lean` already made.
* `RotEnsemble.lean` — that conversion is **impossible** there. The values are
  `Float` and the kernel cannot reduce them; `decide` fails with
  `instDecidableEqBool (routerReading 0 == 0.47142) true did not reduce to
  isTrue or isFalse`. `#guard` in the interpreter is the only instrument, so the
  linter is disabled *in that file* with the measurement quoted in place — and
  with a negative control proving the guards still bite: flipping `0.47142` to
  `0.47143` fails the build.

Result: `lake build` **exit 0, zero warnings, zero errors** across all 21
modules; `leanchecker` re-verifies both changed modules at exit 0 / 0 bytes.
495 theorems.

### Fixed — a green CI leg that asserted nothing, from one missing `else`

The repair to the Windows `tty guard` shipped with a defect **in the repair
itself**, and run `31052104953` caught it: 145 success, **0 skipped**, 2 failure.

An edit removed the `else` keyword from the step's `if / elif / else` allocator
chain. The result is still **valid shell**, so `checker/workflow-lint.sh` passed
it 144/144. What actually happened on the runners:

| leg | behaviour | reported |
|---|---|---|
| ubuntu | GNU `script` branch ran, real pty | PASS, honestly |
| windows | **neither branch ran** — `rc` was the exit of the failed `elif` *test* (0), `tty.out` never created | FAIL, `cat: tty.out: No such file or directory` |
| macos | the fallback body had been absorbed into the BSD branch, so it ran **after** the pty probe and **overwrote its result** | **PASS — while asserting nothing about a terminal** |

The Windows failure was loud and cost nothing. **The macOS pass is the serious
one**: a leg reporting success having tested nothing is a fake green, and it is
the same defect as a skipped step wearing a different hat.

Three layers now stop it, because the text layer demonstrably cannot:

1. **`ci.yml`** — each branch sets `ALLOC` and the step refuses when no branch
   named itself (`FAIL: no pty-allocator branch ran -- the dispatch is not
   exhaustive. Nothing was asserted. This is a skipped check, not a pass.`) or
   when the named branch produced no `tty.out`.
2. **`checker/workflow-lint.sh` R22** — asserts those guards exist, with a
   control that removes the refusal from a copy and requires the rule to fire.
3. **`lean/Proofs/RotGates.lean`** — `unselected_asserts_nothing`,
   `selected_without_artifact_asserts_nothing`, `guard_is_exactly_assertion`
   (the guard is *equivalent* to "this dispatch is evidence" — neither stricter
   nor laxer), and `unselected_dispatch_is_as_green_as_a_skip`, which binds the
   new law to the existing one: a leg that selected no branch is worth exactly
   what `isGreen skipped` is worth.

Stated as a limit rather than glossed: the Lean law catches *"no branch ran"*.
It does **not** catch *"the wrong branch ran last"*, which is what happened on
macOS — that is caught by R22 requiring one `ALLOC` per branch, and the module
says so in a comment beside the macOS `#guard`.

Mutants M09/M10 (**221 applied, 221 killed**). M10 exists because the two
conjuncts of `dispatchAsserted` were each violated on a *different* platform in
the same run, so dropping either would let one leg back through.

Also fixed while in the file: two `grep -c … || printf 0` sites in
`workflow-lint.sh` produced **two** zeros on no match (`grep -c` prints `0` *and*
exits 1), making `[ -eq ]` fail with `integer expression expected`. Identical to
a defect already recorded in `checker/ci-honesty.sh`.

### Fixed — our own recovery advice destroyed two shipped hooks

`checker/gate-all.sh` refuses to run when a mutation suite left `.mutbak` files
behind, because the tree may carry a live mutant. That refusal is correct and it
fired exactly as designed after a commit was killed by a wall-clock ceiling
mid-suite. **Its recovery instruction was the defect.** It said:

> Restore each file from its backup (`cp <f>.mutbak <f>`), delete the backups.

Followed literally, that left `hooks/prover-remind.sh` and
`hooks/prover-remind.ps1` at **zero bytes** — `sha256 e3b0c442…` is the empty
string — with the backups deleted in the same breath. Three gates went red with
every measurement returning `''`. Recovered from git (29107 and 23611 bytes).

The mistake is structural, not clumsiness: **"a backup exists" and "a backup can
restore" are different propositions.** `find` answers the first. A suite killed
between *creating* `<f>.mutbak` and *writing content into it* leaves a file that
satisfies the first and fails the second, and `cp` from an empty source
**destroys the target and exits 0** — a destructive operation reporting success,
which is the same shape as a fake green.

The preflight now **sizes every backup**, marks any empty one
`*** EMPTY -- copying THIS would ERASE the file ***`, and leads with
`git checkout HEAD -- <file>` — a recovery path that cannot be truncated by the
kill being recovered from.

Two related **false reds** from the same kill, both cleared by rebuilding rather
than by "fixing" anything: `leanchecker` reported `Proofs.RotMutant` as KERNEL
REJECTED because the suite had deleted its `.olean`, and a missing artifact is
indistinguishable from a kernel failure at the exit code. A red must be
attributed before it is believed.

`lean/Proofs/RotMutant.lean` grows 17 → **23 theorems**:

| theorem | content |
|---|---|
| `existence_is_not_restorability` | the two predicates come apart on the empty backup |
| `empty_backup_restore_is_destructive` | `cp` from a 0-byte source erases any non-empty file |
| `copy_is_safe_iff_backup_nonempty` | the size test is precisely the side condition, not belt-and-braces |
| `git_restore_ignores_the_backup` | the git path does not read the artifact the kill produced |
| `git_restore_is_total` | safe for every file and every backup, given a non-empty commit |
| `git_strictly_safer_on_the_measured_state` | a state exists where git is safe and `cp` is not — so the change is not cosmetic |

Mutants M11–M13 (**221 applied, 221 killed**, was 190). M13 exists specifically
because `git_restore_ignores_the_backup` is proved by `rfl` and depends on **no
axioms** — the vacuity smell — so it had to be shown load-bearing against a
`restoreFromGit` that reads the backup, or labelled decoration. It dies.

Recorded because it cost two DISCARDED results first: **a multi-line `grep -F -c`
needle counts matching lines, not occurrences**, and M13's first form came back
`needle occurs 2 times (expected 1) -- patch not applied`. The harness reported
DISCARDED and refused a verdict rather than scoring it SURVIVED, which is the
`RotMutant` law protecting its own suite.

### Fixed — the CI honesty law was strict in one direction and blind in the other

Run `31045719329` measured the no-skip repair and it **held: zero skipped
steps**, down from the eight that run `31035932155` carried while GitHub called
it `success`. Two defects surfaced in the same audit, and both were ours.

- **The Windows `tty guard` asserted something false.** Git Bash has no
  `script`, so the Windows leg fed the router `/dev/null` and required a
  non-zero exit, calling that "the same contract". It is not: empty stdin is not
  a terminal, and the router correctly exits 0 on it (measured — exit 0, zero
  bytes). The check failed loudly on a correct implementation, which is a defect
  in the check.

  `winpty` ships with Git Bash and was tried first; it needs a real console and
  dies on a runner with
  `ASSERT_CONDITION("wp != nullptr && cols > 0 && rows > 0")`. **A pty on that
  leg is impossible, not merely awkward.** The leg now asserts the property that
  *is* true there — on empty stdin the router must terminate, must not hang, and
  must emit nothing — and the log says on that leg that it is narrower than the
  pty probe. The pty refusal itself is still asserted on the Linux and macOS
  legs of the same matrix. **Nothing skips; the step concludes `success` on all
  three platforms.**

- **`checker/ci-honesty.sh` exempted runner scaffolding from *both* rules.**
  GitHub decides whether to run its own `Post <action>` cleanup, so exempting it
  from the **skip** rule is right. Exempting it from the **failure** rule meant a
  scaffolding step could conclude `failure` and the run would still be scored
  honest — a fake green built into the anti-fake-green checker. The exemption is
  now asymmetric: consulted for `skipped`, never for anything else.

  *Correction on the record:* the first write-up of this defect claimed the run
  actually had two failing `Post Run actions/checkout@v7` steps. It did not.
  That came from parsing the jobs list with `paste - -`, which pairs lines
  offset by one and glued a job-level conclusion onto a step name. Re-measured
  against the API: **zero** Post steps failed. The hole was read out of the
  code, not observed firing, and both `RotGates.lean` and the checker now say so
  rather than carrying the tidier false story.

### Added — the asymmetry, proved

`lean/Proofs/RotGates.lean` grows from 24 to **30 theorems**. `runIsHonest` is
no longer `allGreen`; it is `List.all stepIsAcceptable`, which branches on the
outcome and consults `Step.isScaffolding` in the `skipped` arm **only**.

| theorem | what it forbids |
|---|---|
| `scaffolding_failure_is_still_dishonest` | a `Post <anything>` step that fails, for every name |
| `post_checkout_failure_is_dishonest` | the concrete pair the old checker would have passed |
| `scaffolding_skip_is_tolerated` | the exemption being unreachable, which would collapse the two rules into one |
| `scaffolding_matters_only_for_skips` | the exemption ever affecting a non-skipped outcome — it cannot leak |
| `honest_run_has_no_failure` | any failure anywhere, with no hypothesis |
| `honest_run_authored_step_is_green` | an authored step concluding anything but `success` |

`any_skip_is_dishonest` → `any_authored_skip_is_dishonest` and
`no_skip_is_implied` → `no_authored_skip_is_implied`. **Both gained a
hypothesis, and that is a real narrowing, so it is stated plainly rather than
buried:** the old versions quantified over every name and so declared a skipped
`Post Run actions/checkout` dishonest too. That was stricter than reality —
GitHub skips its own cleanup as normal operation — and a law that calls normal
operation dishonest is a law someone later deletes. The authored case, which is
the case the rule exists for, admits no exemption and is unchanged.

Three mutants added to `lean/mutate/mutate_rotgates.sh` (**221 applied, 221
killed** repo-wide, was 187):

- **M06** re-opens the hole — the failure arm consults `isScaffolding`. Killed
  nine theorems including both new failure theorems.
- **M07** tolerates every skip. Killed the authored-skip theorems and the
  `31035932155` witness.
- **M08** widens the predicate to `"".isPrefixOf`, making every step
  scaffolding. Killed the run witnesses — the narrowness of the predicate is the
  only thing keeping the skip exemption honest.

`ci-honesty.sh` gains two negative controls asserting the asymmetry in both
directions: a failing scaffolding step must be caught, a skipped one must not.

### Added — the Easter Egg section in `README.md`

Documents where the RoT formulae came from, and proves it rather than asserting
it. Backed by `RotEigenform.lean`: **113 theorems, 0 `sorry`, 0 warnings,
`leanchecker` exit 0 with zero bytes, 41 of 41 mutants killed**, plus a corpus
checker that re-derives every stated number from **498 real SINE presets**
(SHA-256 pinned; negative control fails with 7 `FAIL`s when one file is removed).

What it establishes, in one line each:

- **The Ultimate Equation is a diff.** The original is the Book of Fairy quote at
  `mathematics.md:105`; Saimonokuma's version adds four insertions, and each one
  names a component that is now a theorem — the weights/quantization pair, the
  goal, the sound equation, and the question mark.
- **SINE's `lerpWithPow` and one term of `R/s+` are the same operator.**
  `blend_mem` is proved once and bounds both a 2014 GPL entrainer and this
  router. Same operator, different index set — beats indexed by time, the
  ensemble by lens.
- **The ✨ Nova-Violet Role Merging Law**, over ℚ: commutative, gains exactly ⅕
  over the mean, strictly exceeds both parents in entropy, and inherits μ without
  gain. Nova × Violet = λ 1.65, μ 1.00, H 0.50. Reported honestly: the law is
  **not idempotent** — `merge a a` still gains.
- **`R/s+` is dynamic, and cannot be constant.** Stated as monotonicity in the
  inputs rather than as "0.66 ≠ 0.57", so retuning every weight leaves it true.
- **🜏 EIGENFORM — the keystone.** `σ(½) = ½`: the quantizer has a fixed point,
  and `eigenform_survives_infinite_recursion` proves `σ^[n](½) = ½` for every
  `n`. **Three independent objects land on the same number** — the router's
  fixed point, the Nova-Violet merged entropy, and the floor of SINE's frequency
  table. `eigenform_binds_router_law_and_corpus` states it over `sigma`, `merge`
  and `sineTable` so retuning any one falsifies it; mutants **E32** and **E39**
  both kill it. Uniqueness is **not** claimed — the "strictly monotone hence
  unique" argument is false, and it was caught by elaboration after being
  written.
- **The gauge CONVERGES.** `sigma_tendsto_one_atTop` and
  `sigma_tendsto_zero_atBot` are limit theorems in `Filter`/`Topology`;
  `gauge_term_bounded` bounds one lens below `2·λ·μ·M·C·T`; `ensemble_is_bounded`
  bounds the finite sum. Infinite in input, convergent in output, finite in
  outcome — which is the answer to the butterfly, not a caveat about it.
- **Four verdicts, not two** — the `PROVED`/`REFUTED`/`MEASURED`/`OUT OF SCOPE`
  map is the *catuṣkoṭi* of `PART 5:244`, and a two-valued map would have to file
  `MEASURED` under `PROVED`.
- **"Infinite" means finite-but-inexhaustible in all three corpora** — the
  Egyptian numeral glossed *"Infinite/large number"* is 10⁷, Borges' Library is
  25¹³¹²⁰⁰⁰, and `Lane` has nine inhabitants. `realities_must_collapse` proves
  the compression is forced.

Four defects are recorded in the section itself rather than quietly repaired,
including one found *while writing it*: a theorem named
*quantization-without-weights-is-flat* (written here without backticks because
it no longer exists) that elaborated to `rfl` and asserted nothing. It is now
`weights_are_what_discriminate` and proves the real
dichotomy. A green theorem named for a true property is still worth nothing if
it does not state it.

### The router fired TWICE on every prompt, and the install document caused it

Measured on the author's machine: two marker lines, two gauge computations,
twice the tokens, every turn. The packet reaches a session by two routes and
they are **additive** — the plugin's `hooks/hooks.json` binds the router on
`UserPromptSubmit` and `PreToolUse`, and `ARM_ROUTER` writes an absolute-path
entry for **the same script** on **the same two events** into `settings.json`.
`CLAUDE.md` told the installing agent to do both.

Nothing about that state looks wrong from inside. The lane is right and the
gauge is right; they are right twice.

- `hooks/plugin-detect.js` — new. Exits `0` when a live plugin registration of
  the router exists, `10` when none does. It keys on the **fact** (an enabled
  plugin whose `hooks.json` binds `rot-router.*`), never on the directory being
  called `rot-moe`, because a marketplace can rename it.
- `ARM_ROUTER` (both arms) refuses when that detector fires, prints what it
  found, and exits `0` — **refusing is a success**: the user asked for the
  router to be armed and it already is. `--force` / `-Force` overrides.
- Both arms now **refuse an unknown argument** with exit 2 instead of ignoring
  it. An ignored flag is how the next item happened.

### `DISARM_ROUTER --dry-run` was accepted, ignored, and deleted live entries

Counted: `grep -cE '\-\-dry-run|DRY'` gave **15** in `ARM_ROUTER.sh` and **0** in
`DISARM_ROUTER.sh`. The destructive half of the pair was the half with no safety
flag, and an unknown argument was a no-op, so `--dry-run` read as *proceed*.

- `--dry-run` / `-DryRun` in both arms. The preview runs the **real** removal
  against a copy and discards it, so preview and act cannot disagree.
- `--all` / `-All` (`disarm-any` in the merge engine) removes every RoT MoE
  router entry whatever path it names. The old exact matcher could not touch an
  entry pointing at the plugin cache — which is what the documented install
  produces — and reported `nothing to remove`, exit 0, forever.
- Exact mode remains the default and now **says so** when it can see entries it
  cannot match, instead of reporting a false all-clear.

### The proof scan was one level deep — in both arms

`"$PROOFS_DIR"/*.lean` and `Get-ChildItem -Filter '*.lean'` with no `-Recurse`.
File proofs by subject and the newest file either arm can see is whatever last
landed in the root. Measured on a real tree at one instant: **2947 minutes stale
one level deep, 54 minutes recursive** — a 55x error, while eighteen modules
were being written into a subfolder.

### The workspace chain had a step nothing wrote

`env → RECORDED → bundled corpus` reads like three answers. Only `SETUP_LEAN`
ever writes RECORDED, so for a marketplace install the middle step is
permanently empty and every measurement pointed at the plugin's own read-only
corpus, which can never acquire debt.

- A fourth step, `discovered`, walks up from the session's directory for a Lake
  workspace with proofs. Added to **both** arms — the first attempt at this fix
  added it to the POSIX arm only, which would have given Windows and Linux users
  different answers with no gate able to see it.
- `SETUP_LEAN.sh` now records the workspace in the **drive-letter form**, the
  only spelling both arms can test (measured: Git Bash accepts `[ -d "D:/tmp" ]`
  and so does `Test-Path`). The PowerShell reminder gained a fallback for the
  legacy POSIX-form paths already on disk, so an upgrade does not silently break
  the machines that were already set up.

### The measurement half had no instrument, so defects lived there

`cross-diff-remind.sh` compares the two arms' **decision**; its own header says
what it does not cover is "that both arms measure the same things off disk".
Both defects above lived in exactly that gap.

- `prover-remind` (both arms) gained `--measure` (count, minutes, name) and
  `--workspace` (which step of the chain answered, and what it returned).
- The PowerShell arm's scan is now **one function** shared by hook mode and
  `-Measure`, so the thing the gate drives is the thing the hook runs.

### Four new gates, all fast tier

| gate | what it makes impossible |
|---|---|
| `router-duplication.sh` | arming on top of a live plugin registration |
| `disarm-safety.sh` | a dry run that writes; an `--all` that takes a neighbour |
| `remind-measure.sh` | the two arms measuring different trees |
| `log-replay.sh` | a debug record whose numbers do not re-derive |

Fast tier is a decision, not a default: the double-fire was introduced by an
**install document**, which stages no path a deep trigger would have matched.

### The debug log is now re-derived, not merely summed

`bench-router.sh` already summed the logged `term` values and checked
`Σterm / K = Rs`. What it cannot see is everything upstream of `term`: a record
with the wrong `mu`, `sigma`, `H` or `mean` is consistent at the level of sums
and passes. `log-replay.sh` recomputes **every factor** from `lambda`, `mu`, `a`
and `breadth`, checks gauge/route pairing, checks the route line's displayed
value is a faithful rounding of the gauge line's, and replays the **PowerShell**
arm's log as well — then requires the two arms' gauge records to be
byte-identical. Measured: they are.

### A spec that was wrong, said plainly

`RotLog.WellPaired` first asserted that a route record carries the **same** `Rs`
as its gauge record. The shipped router does not do that: the gauge line carries
`0.66427` and the route line carries the displayed `0.66`, matching the marker
the operator sees. Twelve records from each arm recomputed field for field with
zero error, and the only disagreement was a rounding the spec had forbidden.

**The spec was wrong, not the code.** It now carries a tolerance parameter, with
`displayEps = 1/200` — the exact half-ulp of a two-decimal display, so an honest
rounding passes and a stale or edited number still cannot. `RotScan` had the
same class of defect in miniature: a hypothesis that Lean's linter proved was
never used, on a theorem whose doc comment claimed more than it stated. Both
were found by instruments, not by reading.

### `prove this lemma` did not reach FORGE — and could not be made to

Measured on the shipped router before the change:

```
prove this lemma                            -> CONVERGENT     (nothing fired)
prove the read loop conserves bytes in lean -> STEALTH Soleil (it matched `byte`)
```

On a prover head, the two most proof-shaped prompts imaginable reached every
lane except the one for proving. **The earlier diagnosis that first-match beat
priority was wrong** — `route()` has always tried FORGE first. The stem table
simply did not contain `prove`, `proof` or `lemma`.

They could not be added, either. `fired` was a plain substring test, so `prove`
would have fired on **improve**, `lemma` on **dilemma**, `lean` on **cleaning**.
The same flaw was already live and routing prompts wrongly: `fix` fires on
**prefix**, `now` on **known**, `test` on **latest**.

**A stem must now start a word** — the beginning of the text, or straight after a
non-alphanumeric character. `proofs` and `prover` still fire, because a stem is a
word *prefix*; that is what `verif` → "verification" and `strateg` → "strategy"
have always relied on.

Not `proving`, and the first draft of this entry claimed otherwise. `prove` is
not a prefix of "proving" — the two diverge at the fifth character — so it fired
under **neither** matcher. The executable example at `RotStem.lean:386` pins
that, and is how the error was caught: the prose and the spec disagreed, and the
spec was right. A stem that itself begins with punctuation
falls back to a substring test, which is what keeps `.lean` matching
`Basic.lean`.

`RotStem.lean` now specifies the matcher, which had never been modelled — the
existing theorems were about *which class fired*, never about *how a class
decides*. `firesWord_imp_fires` is what made the change safe to ship: word-prefix
firing implies substring firing, for every prompt and every class, so the new
rule can only remove a false positive and can never move a prompt onto a lane it
was not already reaching. `firesWord_strictly_weaker` proves that guarantee is
not vacuous.

FORGE gained `prove proof lemma lean qed`. The cross-diff corpus gained 12 rows
covering both directions — the prompts that must now fire and the near-misses
that must not. Reverting the matcher to a substring test turns **12 of them
red**, measured.

### The install section told three tiers to download archives that do not exist

`README.md` said `rot-moe-0.5.1-lean.zip` while `checker/release-package.sh`
built `rot-moe-0.9.1-lean.zip`. Three links, all wrong, **for two minor
versions, with every gate green** — nothing in the repository had ever compared
the names. The release map moved from a hand-written line to a computed one and
the prose quoting it did not follow.

That is not a wrong number in a table. It is the **first instruction a new
reader follows**, and it fails with a 404 that reads as an abandoned project.

- The install section was rewritten. It had four methods in an order that buried
  the one that works: `ARM_ROUTER --dry-run` first (the path that edits your
  `settings.json`), then `--plugin-dir`, then a heading marked "start here"
  arriving third. Now one ordered page — `/plugin install`, the three tiers,
  `--plugin-dir` from a clone, then `ARM_ROUTER` marked as the advanced path.
- Tiers are named **Router · Router + Lean · Router + Lean + Extra**, and each
  row says what the archive actually contains, read from the packager's own
  `CORE_PATHS` / `LEAN_EXTRA` / `UNSEALED_EXTRA` rather than described from
  memory. Measured: core 37 files with no `lean/` and no `checker/`; lean 137;
  unsealed 138 — lean plus `UNSEALED.md` exactly.
- The three transcript lines were **re-measured**: each archive rebuilt,
  unzipped, and its own `rot-router.sh` run on the same payload.
- `checker/readme-variants.sh` is new and prevents recurrence. It asks the
  packager for its map (`--print-variants`, never by grepping its source) and
  checks **both** directions across `README.md`, `RELEASE.md` and `docs/*.md`.
  Requiring the right names to be present does not remove the wrong ones, and
  this README had correct prose and dead links in the same section. Registered
  **fast tier**: a deep gate would let this ship again on any commit that did
  not touch the release paths, and a README edit is exactly such a commit.

### `SHA256SUMS.txt` was promised by the README and never written by anything

`grep -c sha256 checker/release-package.sh` returned **zero** while `README.md`
said every archive verifies against the sums file published beside it. A
documented verification step with no artifact behind it is worse than none: the
reader who tries it finds nothing and cannot tell an unpublished checksum from a
tampered download.

The packager now emits it, last, after every other assertion has passed — so
sums can never exist for an artifact it refused to bless — and **refuses** if no
`sha256sum`/`shasum` is on PATH rather than shipping archives with no checksums
while the docs claim otherwise. Control: appending one byte to an archive makes
`-c` fail; restoring makes it verify.

Two self-inflicted faults were found writing it, both of the kind that fake a
pass. The well-formedness pattern rejected all three good lines because GNU
`sha256sum` writes `<hash> *<name>` in binary mode — the check was wrong, not
the output. And the tamper control extracted the filename with
`awk '{print $2}'`, which yields `*rot-moe-0.9.0-core.zip` **with** the star, so
every `cp`/`mv` would have addressed a file that does not exist and the control
would have "passed" while touching nothing.

### The tag rule was a blanket where the hazard has a boundary

`docs/GIT-WORKFLOW.md` §4.3 said *"never force-push, never rewrite published
history — tags are consumed by the marketplace."* The first half is right and
unconditional. The second half is not what this project's marketplace does, and
the difference is not pedantic: it decides whether a re-tag is routine or
destructive.

Measured, not recalled. `.claude-plugin/marketplace.json` declares
`"source": "./"`, and a marketplace install resolves the **default branch**; a
directory install records `"source": "directory"` and a path — verified in the
CTT config. **Neither reads a tag.** What *is* pinned to a tag is a published
GitHub Release: its source archive and its assets, `SHA256SUMS.txt` included.

So the rule now has a boundary. A tag with **no Release attached** may move, and
that is the last moment it is free; a tag with a Release published on it **never**
moves, because people have the checksums. A blanket in the wrong place is not
caution — it forbade re-tagging onto a commit whose CI is actually green, which
is precisely the operation this release needed.

§4.4 is new: the dispatch procedure, written from measurement rather than
rediscovered each time. There is **no release-publishing workflow** — the four
are `ads-manager`, `ci`, `tag-manager`, `verify`, and `tag-manager` only
refreshes notes on releases that already exist. Nothing creates a Release,
uploads an asset, or fires on a tag push. The step is manual, and the procedure
now says so, including the part that is easy to skip: **download each published
asset from its URL and run its own router.** The packager proves the *build* was
sound — it refuses to emit sums for an artifact it did not bless, and a tampered
byte fails `-c`. It cannot prove the *upload* was.

Also recorded, because the question keeps being asked: **a plugin install does
not write your `settings.json`.** Measured in CTT — 0 router entries there, 5
hook bindings across 3 events in the plugin's own manifest, and
`checker/install-parity.sh` shows both install paths register the *same*
(event, script) set. Nothing of the user's is edited, which is what makes
`/plugin uninstall` clean. `ARM_ROUTER` is the path that writes `settings.json`,
for people who cannot use plugins.

### New Lean modules

- `RotTag.lean` (9) — the rule above, stated so it can be checked instead of
  remembered. `released_tag_never_moves` is the durable form: a published tag is
  a fixed point of an **entire history** of move attempts, in any order, not
  merely of one — a force-push loop *is* a history, and a rule that survives a
  single step is not an invariant. `unreleased_tag_can_move` is its non-vacuity
  partner and carries real weight: a rule that forbids everything forbids the
  safe operation as firmly as the dangerous one, and the usual repair for that
  is to weaken the rule. `move_preserves_name` says why a moved published tag is
  dangerous rather than untidy — the reference still resolves, so nothing
  anywhere reports an error. **Not proved, and stated plainly because "proved in
  Lean" reads like a technical control:** git does not enforce this. Lean
  constrains the model; the binding is procedural.
  10 mutants, 10 killed — but **three were first written from memory and all
  three were caught as DISCARDED, not survived**. One needle was indented
  differently from the source; one replacement contained its own needle, so it
  could never be seen to land; one appended to a signature, leaving the needle a
  prefix of its replacement. A harness without a landing assertion would have
  reported all three as *"the theorem is robust"* — which is the reassuring
  direction, and the reason that assertion exists.
  The suite's inherited header was wrong too: derived with `head -178` from a
  sibling, it described `RotStem`'s matcher mutants, concepts that do not appear
  in this module. Same defect `mutate_rotlog.sh` carried once before.

- `RotVariants.lean` (7) — a published document is *sound* when the archive
  names it carries are exactly those the packager builds, both directions
  (`sound_iff_setEq`). The obvious one-directional repair would have **missed
  the defect above entirely**, because a half-finished edit adds the new links
  and keeps the old: `covers_does_not_imply_clean` is that argument as a
  theorem. `version_drift_breaks_soundness` and `new_tier_needs_a_link` are
  quantified over an arbitrary release map, so they hold for a tier not yet
  invented. 10 mutants, 10 killed — one of which had to be **retargeted upward**
  after surviving: flipping a single link in the stale list does not make it
  sound, because `covers` still fails on the other two. The theorem was stronger
  than the mutant, which is recorded rather than treated as licence to weaken it.
- `RotDuplicate.lean` (9) — what actually fires is the **concatenation of two
  registries**, so `RotInstall`'s idempotence, which is true, cannot see a
  duplicate that lives across both. `unguarded_duplicates` counts 2;
  `guard_keeps_one` counts 1.
- `RotScan.lean` (14) — a one-level scan can only ever **over**-report staleness
  (`flat_never_underreports`): its failure mode is a false accusation, never a
  false silence. Plus the resolution chain's precedence and totality.
- `RotLog.lean` (12) — a self-consistent record reports exactly the gauge, so
  `Rs` is **derived rather than trusted**; two consistent records over the same
  terms cannot disagree; pairing detects a truncated log.

### Numbers

- **495** machine-checked theorems across 22 modules (was 205 across 14),
  0 `sorry`, 0 `native_decide`, 0 build warnings.
- **35** gates (was 29); 23 fast, 12 deep. The 0.9.0 line said "33 (22 fast, 11
  deep)" and the deep tier already held 12 -- a prose figure nothing recounted.
- Every new theorem `#print axioms`-audited and `leanchecker`-re-verified.

---

## [0.6.0] · [0.6.1] · [0.6.2] — 2026-08-04

Three archives, one tree. The patch digit is the tier: `0` core, `1` lean,
`2` unsealed.

### The README stopped narrating its own construction

The page had accumulated development recaps — what a table *used to* score, which
paragraph *had been* wrong, how a corpus was collected and the part of that
collection which went astray. All true, none of it what a reader wants from a
README. It belongs here. **Removed 73 lines, added 34**; what survived is the
claim, the instrument that settles it, and the controls that prove the instrument
can fail.

The four removed passages, kept in full:

**1 — the `CONVERGENT` lane header used to print `none`.** That was wrong, not
factually but in what it communicated. `CONVERGENT` is the one lane with no lead
**lens**: all nine co-reason and nobody leads. Printed as `none` it reads like a
null, as though the router had failed to decide rather than decided that nobody
leads. What actually convenes the nine is the **model you chose**, so that is
what the line now names — `opus[1m]`, or `sonnet` on a machine configured that
way. Measured, because the obvious implementation does not work: a live
`UserPromptSubmit` payload, captured 2026-08-03, carries exactly
`session_id · transcript_path · cwd · prompt_id · permission_mode ·
hook_event_name · prompt` — there is **no model field** in it. The model is read
from the settings file your client writes, with `ROTMOE_MODEL` overriding it and
the literal `model` as the last resort. Every step degrades to a word; none
degrades to `none` or to an empty string, because a lead that renders as nothing
is the defect this replaced.

**2 — the ability table scored three of nine `notModelled`,** reasoning that
Carnage's chaos being *useful* is not a decidable proposition. True — and beside
the point, because the field records each ability's **router-observable effect**,
not a judgement about prose. The file already contained `carnage_leads_creative`
and `violet_leads_empathic`: proofs of exactly the effects it was filing as
beyond reach. Chroma needed one more lane table (`predictiveLam`) and that was
the entire distance between "outside Lean's reach" and proved. Each row now
carries its claim as a *proposition* (`abilityEffect`) rather than a comment, so
`.proved` cannot drift from what was proved. Mutation-tested: filing any ability
back as `notModelled` or `measured` kills the module (M01, M05 in
`lean/mutate/mutate_rotability.sh`).

**3 — how the 80-turn corpus was collected, including the part that went
wrong.** The run was launched with this repository as the session's working
directory, and turn 6 — *"compress the docstring of RotAbility.lean"* — did
exactly what it was asked: it **edited the file**, rewrote the docstring and
added two unreviewed theorems. The count went 205 → 207 and
`checker/repo-complete.sh` caught it; the edit was reverted and the module
rebuilt at 205, exit 0, zero warnings. A benchmark that mutates the tree it is
benchmarking is not a measurement, so `checker/ctt-session.sh` now runs every
turn from a scratch directory and **refuses outright** if that directory resolves
inside the repository. The routing figures are unaffected — a lane and an `R/s+`
are computed from the prompt text alone, before any tool runs — but the
collection method was wrong and saying so is cheaper than a reader discovering
it.

**4 — the router latency figure was not a per-turn cost, and the README said it
was.** The debug log's `ms` field starts at `hooks/rot-router.ps1:40` — *inside*
the script, after PowerShell has already started — so it measures the router's
**logic**, not the turn. Comparing it against the bash arm's **wall-clock**
194–256 ms and concluding the PowerShell arm "costs about half" was comparing two
different clocks, and the conclusion was backwards. `bench-router.sh` §6 now
prints the decomposition every run and fails if a quoted figure does not say
which arm and which clock produced it — that check exists because this paragraph
was wrong.

Two version strings stay at `0.6.1` on purpose: the corpus filename
`bench/ctt-session-0.6.1.jsonl` and the sentence recording which plugin version
the 80-turn session measured. Those are facts about a past measurement.

### Every lens now proves itself — the evidence table was wrong, not Lean

`RotAbility.lean` scored three of the nine abilities `notModelled`, on the
grounds that Carnage's chaos being *useful* is not a decidable proposition. That
is true of the sentence and irrelevant to the field, which records each ability's
**router-observable effect**. The same file already proved
`carnage_leads_creative` and `violet_leads_empathic` — the very effects it was
filing as beyond reach. Chroma needed one more lane table and nothing else.

- **all nine abilities `.proved`**; `evidence_split` moves 6/3 → **9/0**.
- `abilityEffect : Ability → Prop` — each row is now a PROPOSITION discharged by
  `every_ability_effect_holds`, so `.proved` cannot drift from what was proved.
- new: `predictiveLam`, `chroma_leads_predictive`, `predictive_amplifies_chroma`,
  `lane_leads_carry_weight`, `no_ability_is_unmodelled`,
  `expressive_lenses_prove_themselves`.
- the ninth lens is verified present in **all three** lane profiles
  (`every_lens_weighted_in_every_profile`), plus `every_lens_is_present`,
  `lenses_nodup`, `nine_lenses_exactly`.

### The lane-lead theorems were dated — restated relationally

`carnage_leads_creative` read `creativeLam l < 25/10`: a frozen literal that says
every *other* lens is under 2.5 while saying nothing about Carnage, who the
hypothesis excludes. Dropping the lead's own λ to 0.4 left the lane leaderless and
the theorem **green**. Measured, not hypothesised — mutant M02 survived.

All three are now stated against `_Lam .lead`, so a retune of any weight —
including the lead's — is checked. The spec was wrong, not the code.

### Claude's ability is named — *Grounded Truth*

Coined in this repo, not lifted from a codex, and that distinction is kept as
data (`abilityNameIsCoined`) and proved (`exactly_one_name_is_coined`,
`only_claude_name_is_coined`) so a coined name can never pass for a sourced one.
Replaces `claudeAbilityIsUnnamed`; `every_ability_is_named` now holds.

### Zero build warnings, honestly — 76 → 0

No `set_option linter.* false` anywhere in the tree; the one that existed in
`RotDorks.lean` was removed rather than extended.

- `omit [Fintype ι] in` on nine `RotGauge` theorems — this **strictly generalises**
  them to infinite index types.
- every `#guard` in `RotAbility`/`RotLens`/`RotDorks` converted to `example … := by
  decide`, which is *stronger*: a `#guard` is elaborator-only and leaves no proof
  term for `leanchecker`.
- dead `simp` arguments removed, `RotAbility` namespace flattened, long line split.

### New gate: `checker/profile-bind.sh` (29 gates, 11 deep)

The three lane tables are transcribed from `engine/rot-lean.md` §4 and **nothing
bound them** — the router never executes a lane profile, so the spec could be
retuned and the theorems would keep proving things about numbers nobody ships.
Now bound row by row, with Claude's §2 default *parsed from the spec* rather than
hardcoded, plus a lead-is-maximum check and three controls.

### The mutation harnesses lied in the reassuring direction — fixed

Three defects, all found by running them rather than reading them:

- **a suite emptied a source file.** `awk … > "$F"` truncates before writing; a
  wall-clock kill landed inside that window and left `RotRoute.lean` at 0 bytes.
  The next run copied the empty file **over its own backup**, reported 11
  DISCARDED, and **exited 0**. An empty Lean file compiles green, so the preflight
  could not see it. Every suite now checks the source has CONTENT before touching
  the backup.
- **three suites could not fail.** `mutate_rotgauge`, `mutate_rotinstall` and
  `mutate_rotroute` ended on `rm -f "$BAK"` — exit status 0 regardless of what
  they measured. All ten now refuse on `survived != 0 || discarded != 0`.
- **every suite left the tree unbuildable**, deleting an `.olean` and never
  rebuilding it, which makes a later `leanchecker` sweep report a false RED. All
  ten now restore and rebuild, and fail loudly if that does not come back green.

### Numbers

- **205** machine-checked theorems across 14 modules (was 195), 0 `sorry`,
  0 `native_decide`, 0 build warnings.
- `mutate_rotability.sh`: 5 mutants, **5 killed, 0 survived, 0 discarded**.

---

## [0.5.0] · [0.5.1] · [0.5.2] — 2026-08-03

Three archives, one tree. The patch digit is the tier: `0` core, `1` lean,
`2` unsealed.

### Fixed

- **The pre-commit hook had become the thing its own comment warned about.**
  `checker/gate-all.sh` opens by explaining that "a pre-commit hook that takes
  four minutes is a hook people disable". Measured per gate, the set it ran took
  **587 seconds**. Two commits were killed by a wall-clock ceiling *part way
  through*, and one of those kills landed while `mutate-checker.sh` had a mutant
  applied — leaving a live mutant and four `.mutbak` files in the tree, which the
  next run correctly **refused** to certify. Four gates owned 76% of the time
  (`mutate the checker` 198 s, `axiom audit` 94 s, `axiom class` 84 s, `release
  install` 71 s).

- **A per-turn cost figure was attributed to the wrong clock, and the error
  flattered us.** The debug log's `ms` field starts at `rot-router.ps1:40`,
  *inside* the script, so it measures the router's logic and not the turn. That
  number (93–133 ms) was compared against the bash arm's **wall-clock** 194–256
  ms and reported as "about half the cost". Measured like for like, the
  PowerShell arm costs **more**: ~88–125 ms of logic under ~160–300 ms of
  interpreter startup, against bash's ~178 ms under ~20 ms. Both stay inside the
  500 ms bound. `bench-router.sh` §6 now measures both arms on one clock, prints
  the decomposition, and **fails if the README quotes a figure without naming the
  arm and the timer**.

- **`checker/workflow-lint.sh` was itself the staleness defect it exists to
  catch.** It required every Lean module to appear *literally* in `ci.yml`, which
  forced CI to carry a hand-typed module list — precisely the thing `ci.yml:414`
  records as having silently stopped covering `RotRemind`, `RotAcquire` and
  `RotVerdict`. When CI was fixed to enumerate from disk, the linter went red on
  a strictly better workflow, and the obvious repair would have restored the
  defect. It now checks **coverage** — executing CI's own enumeration and
  comparing it against the tree — with a control proving a narrower glob is still
  caught. The spec was wrong, not the change.

### Added

- **`lean/Proofs/RotGates.lean` (12 theorems) — the gate split, proved before it
  was written.** A tiered gate set is the exact mechanism that already produced a
  false green in this repo: `verdict-schedule-sim.sh` sat behind `FULL=1`, was
  red, and the default sweep printed `26/26 GREEN` for weeks. So the split is
  stated as theorems over an **arbitrary** gate table, never over today's names:
  `fast_always_runs` (an unconditional gate runs whatever is staged),
  `triggered_gate_runs`, `stagedRun_mono` (staging *more* never runs *less*, so
  no commit can dodge a gate by growing), `tier_lengths` / `tiers_disjoint` (the
  tiers partition — no gate can fall out of the table), and
  `no_trigger_never_escalates`: **a deep gate with no triggers is invisible to
  every possible commit.** That last one is the silent hole, written down.
  All 12 rest on `propext`/`Quot.sound`, kernel-re-verified, and
  `lean/mutate/mutate_rotgates.sh` kills 5 of 5 mutants aimed at each failure
  mode in turn.

- **`checker/gate-split.sh`** — the binding. A proof about a model that nothing
  compares to the code is decoration (this repo shipped one for a week), so this
  extracts the tier table from `gate-all.sh` *and* the witness from
  `RotGates.lean` and requires them to be the same table, gate for gate and
  trigger for trigger. It refuses if either parse returns too few rows, because
  an empty-vs-empty comparison passes forever. Three negative controls. It caught
  a real defect on its first run: two gates had triggers pointing at `install/`,
  a directory that does not exist in this tree.

- **`gate-all.sh --fast` and `--staged`**; the pre-commit hook now runs
  `--staged`. A **bare** `gate-all.sh` still runs all 28 — the split is opt-in,
  so nobody gets a weaker run by accident and CI is untouched. Measured: a
  fast-only commit gates in **51 s** instead of 587 s. The runner **refuses**
  (exit 2) a gate with an unknown tier or a deep gate with no triggers, and
  validates the whole table *before* running anything — the first version
  validated inline and printed a column of greens above its own refusal.

### Changed

- CI enumerates Lean modules and mutation suites **from disk** in all three
  places that hand-typed them (build, `leanchecker`, mutation), each with a
  floor assertion so a broken enumeration fails loudly instead of covering
  nothing quietly.

### Notes

- 195 machine-checked theorems across 14 modules, 0 `sorry`, 0 `native_decide`.
- 28 default gates; 67 Lean mutants applied, 67 killed, 0 survived, 0 discarded.

## [0.4.0] · [0.4.1] · [0.4.2] — 2026-08-03

Three archives, one tree. The patch digit is the tier: `0` core, `1` lean,
`2` unsealed.

### Fixed

- **The `sorry` alarm cried wolf on clean proofs.** The reminder hook counted
  `\bsorry\b` in a file's *text*, so a doc comment reading "no sorry, no
  native_decide" — the sentence this project's own discipline puts in files —
  was scored as an admission. An armed 50-turn session wrote a correct module,
  was told twice it "contains 1 sorry", and had to argue with its own tool.
  Both arms now ask the **elaborator** instead, counting the compiler's
  `declaration uses \`sorry\`` warning, which is per-declaration and cannot be
  fooled by a comment. Measured both directions on Lean 4.33.0-rc1: a real
  `by sorry` produces the warning, `sorry` in comments produces none, where the
  old text scan counted two. An alarm that fires on correct work teaches people
  to ignore alarms, which costs more than the false positive itself.

- **A green local sweep could contradict CI.** The check that asks whether the
  committed `STATUS.md` verdict is *true of this tree* lived inside the 3-week
  schedule simulation, which is gated behind `gate-all --full`. CI runs FULL; a
  developer running plain `gate-all.sh` does not. So the tree could report ALL
  26 GATES GREEN and publish a verdict claiming 154 theorems against 162 in the
  sources — and it did, failing three CI legs at once. The comparison now lives
  in `checker/verdict-fresh.sh`, runs in the **default** gate set and in
  `ci.yml`, and the simulation *delegates* to it rather than keeping a copy.
  Rule enforced from here: every check CI can fail, the default local sweep must
  be able to fail too.

- **README documented 12 of 13 Lean modules.** `RotStem.lean` had no row, so the
  published-claims audit summed the per-module counts to 152 against 162 and
  failed. Row added, describing the theorems that are actually in the file.

### Added

- `checker/verdict-fresh.sh` — anti-vacuity first (both sides must carry a real
  verdict before they are compared, because two empty strings compare equal
  forever), then a whitespace-insensitive comparison, then a control that
  perturbs the committed text **in memory** and requires the difference to be
  seen. A checker that edits the tree it is judging is a hazard.

### Notes

- 195 machine-checked theorems across 14 modules, 0 `sorry`, 0 `native_decide`.
- 27 default gates green; all five GitHub workflows green with zero errors and
  zero warnings across 254 log files.

### Added — the gauge stops being a recipe and becomes a law

- **`gauge_separates`.** `R/s+(M,C,T) = M·C·T·R/s+(1,1,1)` — the three per-turn
  modifiers factor out of the entire sum, exactly, for every lens family, every
  activity vector, every breadth. With it: `gauge_scales_in_C` (confidence is
  linear, not saturating), `gauge_zero_of_C_zero` (divergence cannot manufacture
  confidence), `gauge_modifiers_commute` (pre-multiplying `M·C·T` outside the
  loop is provably the same engine as applying it inside — so the two shipped
  arms may differ there without disagreeing).

- **"Useful chaos" is now proved, not asserted.** The spec always said the
  sigmoid *"rewards median divergence and damps both conformism and pure
  chaos"*. That is a claim about a shipped function, and the README used to
  answer it with "no instrument exists". Since σ′ = 4·σ·(1−σ), the quantity
  `σ(1−σ)` **is** the marginal return on divergence: `marginal_gain_le_quarter`
  bounds it, `marginal_gain_max_iff_center` shows the bound is reached **only**
  at the median, and `pure_chaos_pays_less` / `conformism_pays_less` fall out as
  the same theorem applied at δ=1 and δ=0. One mechanism penalising both failure
  modes, with `sigma_symm_about_center` (σ(x)+σ(1−x)=1) proving the symmetry.

- **Lane weights.** `carnage_leads_creative` and `violet_leads_empathic` — eight
  strict inequalities each — plus `creative_amplifies_carnage` /
  `empathic_amplifies_violet`: a lane *amplifies* its lead (0.6 → 2.5, 0.6 →
  2.3) rather than merely naming it.

- **The ninth lens, corrected.** A first draft read the eight-row CREATIVE and
  EMPATHIC tables literally and modelled 🧭 Claude as *absent* from those lanes.
  That was wrong: `engine/rot-lean.md:270` states K=9 on this head and the lens
  is always active, and `:117` gives it a documented default λ 1.5 / μ 1.05. A
  profile table that omits a lens is not deleting it — the lens falls back to
  its default. Now total functions over ℚ with no `Option`, and
  `every_lens_weighted_in_every_profile` proves no lane degrades to eight.

- **`ROTMOE_DEBUG_LOG` — a real debugger for the router.** Set it and both arms
  append one JSON line per gauge evaluation carrying every factor: per lens its
  λ, μ, activity, δ, σ, H and term. `bench-router.sh` phase 5 recomputes `R/s+`
  from those terms, requires it to match what the router reported, and then
  **corrupts a term to prove the check can fail**. Measured in a live 56-turn
  CTT session: 14/14 records recomputed exactly, K=9 and nine lens terms in
  every one, 93–133 ms of *router logic* on the PowerShell arm. The log records
  prompt *length*, never prompt text. (That 93–133 ms is an **in-script** timer
  and was wrongly reported here as a per-turn cost — corrected in 0.5.x below.)

### Changed

- Benchmark figures refreshed from three fresh runs (194–256 ms bash arm, ~20 ms
  of it process start). The previous 170–179 ms and ~130 ms figures were true
  when taken and are now stale; the range is kept rather than a single number,
  because a 32% run-to-run spread is itself the honest finding.

## [0.3.0] · [0.3.1] · [0.3.2] — 2026-08-03

The three numbers are not a roadmap. The patch digit is the **tier**: `0.3.0` is
the router alone, `0.3.1` adds the Lean 4 proof corpus, `0.3.2` adds the
unsealed checkers. They ship together, from one commit.

The minor moved because the **content** moved. Publishing changed files under an
unchanged version string is the same staleness defect this repository refuses
everywhere else — an installed `0.2.1` and a rebuilt `0.2.1` would be
indistinguishable to anyone holding the archive.

### Proved

- `RotPath.lean` 8 to 12 theorems, and the corpus 154 to **158**. The reminder
  hook's module derivation — workspace root plus edited file, out comes the Lean
  module to build — had shipped with **three silent defects**. It returned no
  verdict at all, which reads as "nothing to check" rather than "I could not
  work out what to build".
  - `moduleOf_spelling_invariant` — the Windows and POSIX spellings of one edit
    give the same module.
  - `moduleOf_root_agnostic` — the module never depends on how the workspace
    directory is named or capitalised. Quantified over **arbitrary** roots, so
    it does not expire the day someone renames `Lean` to `Formal`.
  - `moduleOf_no_slash` — a derived module name never contains a separator.
  - `moduleOf_none_of_outside` — a file outside the workspace derives nothing,
    which is the theorem that separates *correct* silence from the two bugs.
  - Three mutations of the definitions each killed the build; `#print axioms`
    shows `propext, Classical.choice, Quot.sound` and no `sorryAx`; and
    `leanchecker` re-verified the module at exit 0 with zero bytes.

### Changed

- **`--root` now moves your PROOFS, not the toolchain.** A toolchain is a
  bounded one-time cost elan manages in the home directory; the proof workspace
  is what grows as you work, so it is the one that belongs on the disk you pick.
  `--elan-root` keeps the old capability for a tight system drive — one flag had
  been doing two jobs and answering the commoner question wrongly.
- Both installers now **scaffold** the workspace: a `lakefile.toml` and a
  `lean-toolchain` pinned to the version this corpus is verified against. A
  directory alone was not a workspace — the user's first theorem could not build
  at all, and the hook reported `LEAN REFUSED`, which reads as "your proof is
  wrong" when the truth was "there was nothing to build it with". Core-only, no
  mathlib: your proofs start at zero and grow from your own work.

### Fixed

- `elan toolchain install` **exits 1 when the toolchain is already present**
  (measured on elan 4.2.3). Both arms treated that as fatal, so the installer
  aborted on every machine that already had it — the common case for a re-run —
  and never reached the step that records the workspace.
- `SETUP_LEAN.ps1` never created or recorded a workspace at all, so a
  Windows-native user silently got the plugin's read-only bundled corpus, a
  directory that can never accumulate their proof debt.
- The recorder ran only at the end of the pwsh script, making it dead code on
  the two paths users actually take: `-DryRun` and "nothing to do".
- **The cross-arm handoff was broken.** PowerShell wrote a backslash path; the
  shell hook's `-d` test is false for those in Git Bash, so it rejected a
  correct workspace and fell back to the bundled corpus without a word. Both
  arms now agree on the format, and the reader still accepts what an older
  install wrote.
- The stale-verdict alarm now rings **before** the push. `verify.yml` had failed
  twice while all 26 local gates were green: a module count went 12 to 13 and
  the only instrument that could see it ran in CI. A check that can only fail
  after a push will keep failing after a push.

### Measured

- Router cost re-measured: **170-179 ms** across three runs of twenty
  invocations, ~17 ms of which is bash process startup. The README had said
  ~154 ms, which predated the `R/s+` gauge the router now computes on every
  invocation. Recorded as a range plus the bound the gate enforces (under
  500 ms), because a single figure is a snapshot pretending to be a constant.

## [0.2.0] · [0.2.1] · [0.2.2] — 2026-08-03

Released together from one commit, as always: the version **is** the variant.

### The router line now carries what the README always promised

`README.md` said the hook adds *"a named lane and a gauge reading"*. For three
releases it added the lane alone. The premise behind that was sound — one
stateless hook call has not measured nine lens activities, and a fabricated
vector is worse than none — but the conclusion was wrong, and it left a promise
unkept.

By the time the line is printed the router **has** measured something: which
lane fired. Written in the gauge's own units that is a one-hot activity vector,
and the reading is computed per invocation, not appended as a constant:

```
FORGE 0.66  CLINICAL 0.57  STRATEGIC 0.47  RECURSIVE 0.45  EXECUTIVE 0.44
PREDICTIVE 0.41  STEALTH 0.39  CREATIVE 0.32  EMPATHIC 0.31  CONVERGENT 0.16
```

Byte-identical on both the POSIX and PowerShell arms. `M`, `C` and `T` are the
neutral `1.0` because memory residue, confidence and recency are genuinely
unavailable to one stateless call — stated in the code and the README rather
than hidden. The reading is a function of the lane: it varies across lanes, not
across turns.

### Half the router was inert and looked healthy

The hook registers on `UserPromptSubmit` **and** `PreToolUse`. The `PreToolUse`
half read only `tool_name`, so every tool call in every session routed to
`CONVERGENT none` — a healthy-looking stream of classifications carrying no
signal at all. It now reads the tool's intent (`command`, `file_path`, `path`,
`pattern`, `description`). Measured: a Bash running the Lean build tool routes
to FORGE, a Bash searching a log for the word error routes to CLINICAL, an Edit
of a proof module routes to FORGE.

### CLINICAL vocabulary widened

`segfault crash panic leak regress traceback` join the stem list on all three
surfaces — both router arms and the engine document — after a live session
misrouted *"there is a segfault when I free a pointer twice"* to `CONVERGENT`.
Router accuracy on the labelled bench is unchanged at **18/18**.

### Verification

- Every one of the **12 modules** is now under a mutation instrument. Four
  (`RotAbility`, `RotDorks`, `RotLens`, `RotMutant` — 44 of 144 theorems) had
  never been attacked before this release.
- **59 mutants, 59 killed, 0 survived, 0 discarded** across all eight suites.
- The lens **roster** is now bound across four surfaces in name *and* order;
  renaming a lens in the engine document is caught at exit 1.
- An overclaim was repaired: `lead_does_not_shrink` proved an independence
  property its name did not describe.
- Mutation attribution no longer reports a per-line list as an inventory. When a
  mutant produces no `.olean`, **every** theorem in the module is dead, and the
  report now says so instead of implying survivors.

---

## [0.1.2] — 2026-08-01 — Router + Lean + Extra

### Added
- `UNSEALED.md` — the only document that distinguishes this variant. Records the
  measurement that corrected the original premise, the four-tactic axiom table,
  and the two design defects the tool found in itself.
- `checker/axiom-class.sh` — classifies every theorem **KERNEL / COMPILER /
  BROKEN** from `#print axioms`. `ROTMOE_ALLOW_COMPILER=1` permits-and-reports.
  Rule enforced: a COMPILER theorem may never be counted in a headline number.

### Measured, not assumed
The premise for this variant was that `native_decide` could be reached through
`leantar` and `leanir` without `clang`/`lld`/`llvm-ar`. That was **disproved by
measurement**, and the corrected facts are shipped rather than the guess:

| tactic | axioms it introduces |
|---|---|
| `decide` | none |
| `rfl` | none |
| `bv_decide` (CaDiCaL) | `propext` |
| `native_decide` | `…native_decide.ax_1_1` — a fresh axiom per theorem |

`leantar` is the `.ltar` cache compressor; `leanir` dumps IR and generated C;
`clang`/`lld` **are** what `leanc` wraps. `native_decide` was already reachable
in `0.1.1` — it was withheld by policy, not by capability.

**The decisive finding:** `lake build` exit 0, then
`lake env leanchecker Proofs.NativeProbe` **also exit 0** (control: exit 1).
The kernel re-check does **not** catch `native_decide` — a declared axiom is
trusted by definition. `#print axioms` is the only witness.

---

## [0.1.1] — 2026-08-01 — Router + Lean 4

### Added
- The full Lean 4 shelf: bounded installer against official hosts only, the
  proof corpus, and the discipline as runnable scripts.
- `lean/Proofs/RotAbility.lean` — 16 theorems binding each of the nine lenses to
  what it *does*, including `every_lens_is_load_bearing` (erasing any lens
  strictly lowers the ensemble weight) and `no_ability_overclaims`.

### Note on what this variant is for
It is not "the same product with proofs attached". `0.1.0` is the product;
`0.1.1` is the product **plus the workshop it was built in** — reshape the
router and prove the reshape, start your own proved repositories, and get the
verification discipline as scripts you can run.

---

## [0.1.0] — 2026-08-01 — Pure Router

### Added
- The nine-lane router as a `UserPromptSubmit` hook, both arms (`sh` and
  PowerShell), cross-diffed byte for byte.
- `ARM_ROUTER` / `DISARM_ROUTER` installers with a byte-identical round trip.
- The checker suite and CI across Linux, Windows and macOS.

### Fixed
- **The installer armed the wrong directory.** All four installer arms honoured
  `CLAUDE_DIR` but ignored `CLAUDE_CONFIG_DIR`, which is what Claude Code itself
  reads. Precedence is now `CLAUDE_CONFIG_DIR` → `CLAUDE_DIR` → `$HOME/.claude`.
  Found by installing the *artifact* rather than testing the repository.
- **Disarm left an empty `hooks` container.** `hooks/settings-merge.js` now
  removes `"hooks": {}` when the last entry is gone, so the round trip is byte
  identical.

---

## Verification shipped with these releases

Every claim below has a named instrument. Nothing here is asserted from reading.

| claim | instrument | result |
|---|---|---|
| the Lean corpus elaborates | `lake build` (exit code read directly) | exit 0, **zero `sorry`** |
| the proof terms are valid | `lake env leanchecker <Module>` | exit 0; control exit 1 |
| nothing rests on the compiler | `checker/axiom-class.sh` | 144 KERNEL, 0 COMPILER, 0 BROKEN |
| the archives are well-formed | `checker/release-package.sh` | each tier a strict superset of the one below |
| the artifact installs | `checker/release-install.sh` | unpacked, armed, round trip byte-identical |
| the router **routes** from each archive | `checker/release-session.sh` | 27 lane-sessions, 3 archives × 9 lanes |
| the router **works in a real conversation** | `checker/release-longsession.sh` | 181 turns, 181 real model answers, 181 firings |

The last row is the one that took three attempts. The first two "local proofs"
passed while no model turn had ever happened: an empty scratch config is not
logged in, and `UserPromptSubmit` fires *before* the model call, so the router
printed and every assertion went green on a session that never spoke. The
sustained test clones a real credential, installs the plugin the way a user does
(`claude --plugin-dir <artifact.zip>`), and holds a resumed conversation for a
wall-clock budget — with an auth gate that refuses to score any turn unless the
session answered for real.

[0.1.2]: https://github.com/Nova-Violet-Role/RoT-MoE/releases/tag/v0.1.2
[0.1.1]: https://github.com/Nova-Violet-Role/RoT-MoE/releases/tag/v0.1.1
[0.1.0]: https://github.com/Nova-Violet-Role/RoT-MoE/releases/tag/v0.1.0
