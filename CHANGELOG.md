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

## [Unreleased]

Work landed after `0.9.2` and not yet cut into a release. The heading is not
decoration: `checker/repo-complete.sh` scans the **newest release section** of
this file for live count claims, and without a bracketed heading here the 0.9.x
section — a record of what that release actually shipped — was being read as a
claim about today's tree. History does not get rewritten to satisfy a counter.

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

