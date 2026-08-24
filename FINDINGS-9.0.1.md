<!--
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# RoT MoE — 9.0.x audit findings

Breadth-first folder review of the 9.0.x worktree. Facts only; every entry carries the
command that produced it and the control that could have refuted it.

Version note: `9.0.0`, `9.0.1` and `9.0.2` are three distribution tiers of the SAME
commit (`CHANGELOG.md:49`, `NEXT-STEPS-9.0.x.md:24`, `checker/release-body.sh:11`), not a
version sequence. This file is named for the tier `/plugin install` delivers
(`.claude-plugin/plugin.json:3` → `9.0.1`, `RELEASE.md:74`).

## CRITICAL

none recorded

## BUGS

none recorded

## WARNINGS

| id | what happened | evidence | repro |
|---|---|---|---|
| W2b | The 6.0.1 duplicate-injection warning was fixed for the pair it named and survives between a pair that did not exist as a concern then. `PreToolUse` and `PostToolUse` now carry different payloads — that half is genuinely repaired. `PostToolUse` and `PostToolBatch` deliver byte-identical context blocks on one tool call. | `hooks/hooks.json:22` (`PostToolUse`) and `:56` (`PostToolBatch`) are both declared; a single `Bash` call in a live 9.0.x session received the identical RoT ENGINE block from both events. Prior art: `bench/foreground-findings.md:24` (W2, recorded at 6.0.1, Pre/Post pair). | any hooked tool call in a session with both events wired |
| W3 🟠 | Three benchmark scorers hardcode this machine's shell with no fallback, and swallow the resulting spawn failure. Off Windows they do not crash — they return an empty string per command and publish a complete 40-task result scored as forty misses, at exit 0, with no diagnostic. | `bench/main-score.js:47`, `bench/pilot-rescore.js:42`, `bench/pilot-score.js:56` each pass `shell: "C:/Program Files/Git/bin/bash.exe"` to `execSync`. Control that could have cleared it and did not: `grep -c 'process\.platform\|ROTMOE_SHELL\|process\.env\|win32'` returns **0** in all three — no conditional, no override. Reachability: `main-score.js:45` defines `run()`, `:84` consumes it as `const T = run(k.truth_cmd), N = run(k.naive_cmd)` — the scoring path, not a utility. Silence: `:49` is `catch (e) { return e.stdout ? … : "" }`, and `present()` at `:54` short-circuits `if (!value) return false`. | `node bench/main-score.js <corpus-dir> forward` on any non-Windows host, or with Git for Windows installed anywhere but `C:\Program Files` |
| W4 | `bench/PANEL-PREREGISTRATION.md:61` names the two programs that enforce its five refusal conditions. Neither has ever existed, on any branch. The document reads as a five-condition pre-commitment and binds nothing. | `:61` states the conditions "are exit-3 refusals in `bench/panel-run.sh` / `bench/panel-judge.js`". `git log --oneline --all -- bench/panel-run.sh bench/panel-judge.js` returns **0** commits. Negative control, the same query against a file that does exist: `git log --oneline --all -- bench/ab-session.sh` returns **4** — the query works, the subject is absent. `git ls-files 'bench/*.sh' 'bench/*.js'` lists 21 scripts, none named `panel-*`. `git grep -F` for both names across every tracked `*.md` returns 1 hit: the citation itself. | `git log --all -- bench/panel-run.sh bench/panel-judge.js` |
| W5 🟡 | W3's swallow class is wider than the three scorers it named: 9 of 20 `bench/*.js` discard a read error and continue, and a zero-length guard catches total corpus loss but not partial. | `bench/ab-compliance.js:55` `catch (e) { continue; }`, `ab-grounding.js:49,87,90`, `fact-score.js:77,80`, `calib-verdict.js:50` `{ cdir = c; }`, `pilot-rescore.js:60`, `pilot-score.js:73`, `trap-latency.js:44`, `work-trace-tasks.js:58`. Guards that DO fire: `ab-compliance.js:64` and `ab-grounding.js:100` `console.log("NOCORPUS"); process.exit(3)`. | `for f in $(git ls-files 'bench/*.js'); do printf '%s ' "$f"; grep -c 'catch' "$f"; done` then read each catch body |

W5 in full, because the narrow version of this census is how it was missed the first time.
Searching for the *literal* W3 signature — `e.stdout ? … : ""` — returns exactly the three
scorers already known, and 17 clean files. That reads as a closed class and is an artefact
of the pattern, not a fact about the tree: widening to every `catch` in `bench/*.js` returns
**9 files with a silent default**. The regex fired, which proves only that it can fire, never
that it looked in the right places.

The consequence is partial loss, and it is narrower than "these scripts are broken". A
corrupt turn file inside a loop over the 40-turn corpus is skipped by `continue`; the guards
at `ab-compliance.js:64` and `ab-grounding.js:100` test `turns.length === 0`, so five corrupt
files leave 35, pass the guard, and the rate is computed over 35 while it reads as 40. Total
loss is caught; partial loss is not distinguishable from a smaller corpus.

The repair is already in the same directory and needs no invention: `work-trace-tasks.js:42`
refuses with *"corpus-40.jsonl has N lines, expected exactly 40"* and `:104` with
*"SEGMENTATION REFUSED: N task segment(s), expected exactly 40."* — an exact-count refusal
rather than a non-empty check. `calib-score.js:80,83` shows the other half of the pattern,
returning a labelled reason (`"unreadable:"+e.code`, `"unparseable"`, `"empty-file"`) instead
of a bare `""`, and `p24-score.js:46` prints `cannot read` before returning. Four sites in
`bench/` already do this correctly, which is what makes the other nine a defect rather than a
house style.

Not claimed: no scorer was shown to have produced a wrong published number. This is a
silent-failure capacity, measured statically, not an observed miscount.

Class statement, because the pair-level fix is what makes this recur: the invariant is not
*these two events must differ*, it is **no two hook events may inject identical context for
one tool call**. Repairing a named pair leaves the class open for the next pair added.

W3 is a coverage finding, and both gates it escaped are sound within their stated scope.
`checker/no-local-paths.sh` ran green with four self-controls passing and 12 line-level
exemptions printed; `checker/portability.sh` ran green at 26 passed / 0 failed with eleven
self-controls passing. Neither names any of the three files. The fast sweep's own comment at
`no-local-paths.sh:197-199` predicts this case is "caught by CI and NOT by the local sweep —
`portability` is a DEEP gate"; running the deep gate refutes that prediction. The needles
both gates plant are path-shaped (`D:\`, backslash, drive-colon); the survivor here is <!-- R2-ALLOW -->
forward-slash, inside a JS string, under a `catch` that converts the failure into data. No
gate reads a path and its error handling together, which is what makes the result plausible
rather than absent.

The gate does not exempt W3 — by its own criterion it convicts it. `no-local-paths.sh:67-69`
states the property that matters is *"not 'the string is absent' but 'nothing resolves a
drive-letter path UNCONDITIONALLY'"*, and its exemption list at `:60-69` covers overridable
defaults only (`${ROTMOE_AB_CORPUS:-D:/Temp/...}` and two others). W3's shell path is
unconditional — zero fallback tokens in all three files — so it is the exact case the stated
property is meant to catch, and the needle list simply does not spell it.

Precedent, recorded in that same header at `:50-58`: `bench/trap-score-controls.js`
hardcoded the FORWARD-slash drive path, the sweep's backslash-only needles saw nothing, the
file shipped, and it went red on ubuntu and macos across CI run 31629035282. Same directory,
same needle-shape gap, already paid for once. The repair banned the checkout path as *"the
one path that can never be correct anywhere else"* and stopped there. W3 differs in the one
way that matters: `trap-score-controls.js` failed loudly at MODULE_NOT_FOUND exit 1, so CI
caught it. W3's `catch` converts the same class of failure into an empty string and a
scored result.

Minor, in the same block: `:64` cites `bench/pilot-rescore.js:32` as `process.argv[2] || …`.
Line 32 on disk is `const { execSync } = require("child_process");`. The exemption's
rationale survives — an overridable `process.argv[2]` default does exist in that file — but
its citation has drifted, so a reader auditing the exemption lands on the wrong line.

Scope, tested and confirmed at three: a census of every `catch` in all 20 tracked
`bench/*.js` finds 21 blocks, 17 of which carry no `throw`, `process.exit` or `console.error`
within four lines. Classifying those 17 by what the `try` wraps gives ENV 3 / DATA 13 /
unclassified 1, and the ENV three are exactly `main-score.js:49`, `pilot-rescore.js:44`,
`pilot-score.js:58` — this finding's three. The other 13 wrap `readFileSync`, `readdirSync`
or `JSON.parse`, where returning a sentinel for an absent record is design, not defect. A
raw count of silent catches is therefore not evidence for this finding; the class is.

The repair already exists in this directory and is not invented here. `calib-score.js:75`
states it: *"reason is carried through to the summary so the two can never be confused."*
That file's catches return a LABELLED sentinel — `{ text: "", reason: "unreadable:" + e.code }`
at `:80`, `"unparseable"` / `"empty-file"` at `:83` — and the label is consumed: tallied at
`:104`, published in the output object at `:118`, summed into `broken` at `:123-124`, and
printed as a warning naming every reason at `:127`. The three ENV scorers return a bare `""`
with no label and no tally, so an all-miss table is indistinguishable from a real result. The
fix is to apply the sibling file's own pattern, not a new one.

Reading the three ENV sites directly sharpens the mechanism and makes it worse than "failure
becomes absence". All three share one `run()` helper — `main-score.js:45-50`,
`pilot-score.js:54-61`, `pilot-rescore.js:40-45` — and it fails in three compounding ways:

1. `stdio: ["ignore", "pipe", "ignore"]` DISCARDS STDERR AT THE CALL. The diagnostic is not
   swallowed by the handler; it is destroyed before the handler exists. No `catch` rewrite
   can recover what was never captured — the `stdio` array has to change too.
2. `return e.stdout ? e.stdout.toString().trim() : ""` returns PARTIAL STDOUT ON FAILURE. A
   command that dies halfway does not produce absence, it produces a shorter and entirely
   plausible value that is then scored as if complete. This is worse than an all-miss table,
   which at least looks wrong: a truncated result looks RIGHT.
3. The shell is pinned to an absolute path, `C:/Program Files/Git/bin/bash.exe`. Where that
   file is absent, `execSync` throws before running anything, `e.stdout` is undefined, and
   every scored value collapses to `""` with no diagnostic anywhere.

Consequence for the repair: the labelled sentinel from `calib-score.js` is NECESSARY but NOT
SUFFICIENT here. A label attached to truncated stdout still cannot report that it was
truncated. The exit status is the only thing that distinguishes case 2 from success, and the
current helper discards it along with stderr.

Cases 2 and 3 are MEASURED, not read off the source. A two-arm `execSync` probe under the
same options the helper uses (`stdio: ["ignore","pipe","ignore"]`, the same pinned shell):

- ARM A, real shell, command `echo a; echo b; exit 1` → `status=1`, `stdout="a\nb\n"`,
  `stderr=null`. The failing command returned its COMPLETE output alongside a nonzero
  status, and the helper's `e.stdout ? … : ""` hands that text back as the result. Nothing
  downstream can tell it from success.
- ARM B, shell path absent → `code=ENOENT`, `stdout=undefined` → `""`. Every scored value
  collapses, silently.

Scope was tested twice by independent needles and holds at three both times: classifying
silent catches by what the `try` wraps gives ENV 3, and `grep -n 'shell:' bench/*.js` returns
3 sites in 3 files out of 20. The pinned shell is NOT the directory's idiom — it is confined
to this one triplicated helper.

SETTLED BY PROOF, not only by probe. The probe above samples two commands on one machine;
the loss is a property of the return TYPE, and that is now a theorem. Module
`Proofs.RotMoe.RunLosesExitStatus` (shared Lean tree, toolchain `v4.33.0-rc1`; the absolute
path is omitted here on purpose, it would trip `checker/no-local-paths.sh`):

- `observe_not_injective` — two outcomes differing only in exit status have equal
  observations. Axiom-free.
- `no_downstream_can_tell (f : String → α)` — for EVERY function of the observation, at
  every universe, the failing run and the succeeding run give the same answer. Closes by
  `rfl`, depends on no axioms. The information is destroyed before any consumer is reached.
- `sentinel_on_text_alone_is_wrong_somewhere` — any sentinel that inspects only the text
  must return the same verdict for the failing and the succeeding run, so one of its two
  verdicts is always wrong. THIS IS WHY the labelled-sentinel repair borrowed from
  `bench/calib-score.js` is insufficient: it is defeated as a class, not as a proposal.
- `observeFull_injective` and `repair_distinguishes` — carrying the exit status out of the
  helper restores separability. The repair must widen the return type; nothing narrower works.

Instruments, exits read directly: `lake build` 0 with 0 warnings; `#print axioms` over all 11
theorems with `sorryAx` 0 (nine axiom-free, two on `propext`); `lake env leanchecker` 0 with
zero bytes; negative control on a nonexistent module 1. Mutation M1 APPLIED THE REPAIR
(`observe` made to carry the code) and the build died at exit 1 across 12 sites — every
defect theorem, and only those. A defect theorem that survived its own repair would be
proving nothing.

Instrument caveat, recorded because it changes what the census can support: the silent-catch
heuristic keys on the absence of `throw`/`exit`/`console.error` in a four-line window. It
cannot miss a true swallow, but it over-reports any handler that is loud by AGGREGATION
rather than at the catch site, and any handler that reports through `console.log` — the token
list carried `console.error` and `console.warn` and not `console.log`. There are TWO holes,
not one, and only the first is fixable by widening tokens: adding `console.log` moves the
count 17 → 16, catching exactly one site. The second is loudness by AGGREGATION AT DISTANCE,
which no fixed window can detect at any width — the handler stores a label and something
tens of lines away tallies and prints it. Three of the 17 are loud in fact: `calib-score.js:80` and `:83` (tallied and published,
above) and `work-trace.js:307`, which stores `String(e)` and prints it as `FAIL <name>` on
the next line. DATA 13 and the unclassified 1 are upper bounds; ENV 3 is exact, because all
three were read by hand.

Reachability, measured and severity-relevant: `grep -n` across `.github/workflows/*.yml` and
all 84 checkers returns no invocation of any of the three scorers — the only hit is the
`:64` comment above. No automated run has produced an all-miss table; W3 is a live hazard on
the operator-run path, not a published wrong result.

W4 is 🟡 rather than 🟠 on the same principle as S1 below: the five conditions at
`bench/PANEL-PREREGISTRATION.md:64-70` are not themselves wrong, and nothing has been
published on the strength of them. What is missing is force, not correctness.

The contrast sits in the same directory and was measured rather than assumed. P2.4 declares
its controls and implements them — `bench/p24-aa-control.js` and `bench/p24-score.js` are
both tracked. Same genre of document, same author, same week; one binds and one does not.
That is what makes this a defect in P2.2 and not a house convention.

The empirical confirmation was found while trying to refute W4, and it is stronger than the
absence itself. `bench/panel-results.jsonl` exists — 24 records, 5908 B, two commits — so
P2.2 **ran**. The second of those commits is titled *"P2.2 ran, and its result is
INADMISSIBLE — the harness confounded the router with the reminder it ships beside."*
`grep -c -i 'refus\|exit.3'` across those records returns **0**: not one refusal fired.
No tracked script references `panel-results` either; the only references are the three
prose documents. The five refusals existed to stop a bad run before it produced data. The
run produced data, completed, and was discarded afterwards on a confound the
preregistration had not anticipated — which is precisely the failure mode a declared-but-
unimplemented refusal predicts.

Settled as a class rather than as a citation:
`Proofs.RotMoe.PreregBindingForce` defines binding force as `declared ∩ implemented`.
`declaring_more_adds_no_force` then proves that enlarging the declared set against an empty
implemented set is not merely weak but exactly a no-op — five refusals and zero refusals are
the same document by that measure, which is why the section reads strong and is not.
`implementing_one_beats_declaring_many` is the separating theorem that keeps the rest from
being vacuous. `lake build` exit 0 with zero warnings; `sorry` 0 and `native_decide` 0
counted strictly below the header comment, since that comment has twice matched its own
grep; `#print axioms` `sorryAx` 0 across all nine results; `leanchecker` exit 0 at zero
bytes, with a negative control on an absent module at exit 1. Mutation M1 redefined
`binding d i := d` — declaration alone is force, the exact claim being refuted — and four
theorems died on their own evidence. Two more were masked by cascade suppression once their
parent failed, and the separating theorem survived by design.

### W8 🟡 the vacuity audit states a universal and cannot notice a theorem it never covered

`lean/Proofs/RotVacuity.lean:39-41` says a green `lake build Proofs.RotVacuity` means **every
guarded theorem in this packet has at least one real case**. That is a universal about a
population, backed by fifteen hand-authored `example` blocks — one per theorem, each naming
its witness in prose, two witnesses where one character might have been the only satisfier.
Nothing counts the population. Nothing enumerates it.

Proved by plant rather than argued. A hypothesis-carrying theorem was added to
`lean/Proofs/RotPath.lean` immediately before `end RotMoE.Path`:

```lean
theorem planted_guarded_probe (rest : List Char) (h : '\\' ∉ rest) :
    slashify rest = rest :=
  slashify_eq_self_of_no_backslash h
```

No witness for it was added anywhere. `lake build Proofs.RotVacuity` then exited **0** with
zero errors and zero warnings. The claim at `:39-41` was false for that build and the gate
was silent. Plant reverted in the same turn; `RotPath.lean` back to 18948 bytes, CR 0, empty
`git status`.

**This exact drift is already recorded in this tree, for the sibling list, and was repaired
there.** `.github/workflows/ci.yml:1142-1161` preserves the post-mortem of the axiom-audit
step rather than quietly replacing it: it *"looped over a HAND-TYPED module list — `RotGauge
RotRoute RotInstall RotPath RotVacuity` — which had silently stopped covering RotRemind,
RotAcquire and RotVerdict as they were added."* The repair was disk enumeration:
`checker/axiom-audit.sh` *"enumerates the modules from disk, extracts every theorem NAME
(comment- and namespace-aware, attributes included) … and plants a `sorry` to prove it can
fail."* One theory of trust, applied to one list and not the other.

Scope, stated so the finding is not read as larger than it is. `:39-41` says *this packet*,
not the tree — the file does not overclaim across the other modules, and that arm of the
hypothesis was killed before publication. `:45-52` scopes honestly again: hypothesis-free
theorems cannot be vacuous in this sense. The defect is only that the packet's own coverage
is unenforced and can decay silently, which is what the plant demonstrates.

Settled by proof already in the corpus, so no new debt was taken:
`Proofs.RotMoe.RosterSubsetSilent` proves `sublist_alone_cannot_distinguish` — a subset
relation cannot separate a complete read from a short one — and `counting_does_distinguish`,
that comparing against the population can. A witness list is a subset claim. Fifteen
witnesses are consistent with fifteen guarded theorems and with fifty.

**Repair is wiring, not new code — measured, not assumed.** `checker/axiom-audit.sh:74`
defines `names_of <file> -> fully-qualified theorem names, one per line`. Extracted standalone
(62 lines, `bash -n` exit 0) and run against `lean/Proofs/RotPath.lean`: exit 0, zero stderr,
**12 names**, matching that file's theorem count, with `RotMoE.Path.both_spellings_agree`
present exactly once and an absent name returning zero. A checker that calls `names_of` over
the packet's modules, keeps the hypothesis-carrying ones, and requires each to appear in
`RotVacuity.lean` closes this — and by that file's own standard must plant an uncovered
theorem to prove it can fail.

One residual, unclaimed: the build log was not inspected for proof that `RotVacuity`
recompiled rather than hitting cache. The mechanism makes it moot — `RotVacuity.lean`
contains no reference to the planted name, so no rebuild could have failed on it — but the
line was not captured and is not asserted.

## SEAL

| id | what happened | evidence | repro |
|---|---|---|---|
| S1 | The P2.4 preregistration seal pins five git objects; the governing-text pin does not resolve, and no checker verifies any pin. | `bench/P24-PREREGISTRATION.md:262` pins `TASKS/PROMISE-TODO.md 34c1274f…`; `git cat-file -e 34c1274f…` exits 1 (absent), while the four other pins resolve at exit 0. `git ls-files TASKS/` returns nothing. | `git cat-file -e` each hash in the seal block |

Severity 🟡, not 🟠, and the reason is load-bearing: the clause that pin governs is not
lost. `CHANGELOG-ARCHIVE.md:1180-1182` records that `PROMISE-TODO.md` holds exactly one
clause — all three of SUPPORTED, NOT ESTABLISHED and CONTRADICTED ship as 1.0.0 — and that
clause is encoded as a three-constructor inductive at `lean/Proofs/RotFamily.lean:197-200`,
inside a pin that DOES resolve (`0cc120e6…`, exit 0) and that the kernel has re-checked.
Unverifiable is not absent.

Settled mechanically rather than argued:
`Proofs.RotMoe.SealPinUnresolvable.p24_accepts_any_governing_text` — the seal, as written,
accepts every governing text. `lake build` exit 0, `leanchecker` exit 0, mutation confirmed
load-bearing.

## CLEARED — opened, measured, and found sound

An audit that records only defects cannot be told apart from one that never opened the
file. Each entry below names the line that makes it sound, so the next reader does not
re-litigate it at full cost.

**C1 — the router's debug-log write cannot fail silently.** `hooks/rot-router.sh:1337` is
`printf '%s\n' "$_rec" 2>/dev/null >> "$ROTMOE_DEBUG_LOG" && _rot_wrote=1`, and a discarded
stderr is the signature of a path that cannot report itself. It has a consumer: `:1352`
reads `[ "$_rot_wrote" = 1 ]`, `:1336` and `:1349` initialise it to 0, and lock contention
sets `_dbg_lost=1` at `:1350` for the marker branch. The comment at `:1340-1348` records
that `checker/debug-channel.sh` plants a copy with the marker deleted and asserts it is
gone — and that the comment's own first draft quoted the message string and turned that
control red.

**C2 — that checker's green is worth something.** `timeout 240 bash checker/debug-channel.sh`
→ exit 0, **18 passed, 0 failed**, both twins (`sh` and `ps1`) exercised. It carries its own
negative controls: *"a hook without the marker IS rejected by phase 2's test"* and *"with
rotation disabled the log DOES grow past the cap (16 > 2)"*. An alarm nobody has tripped
deliberately is an untested alarm; these have been tripped.

**C3 — W7 ("live session hooks write no debug log") is a default, not a defect.** Every
write path is gated on `[ -n "${ROTMOE_DEBUG_LOG:-}" ]` — `hooks/rot-router.sh:113`, `:809`,
`:1123`, `:1248`. Unset means `:113` returns 0 early. `:1124` tests appendability before
committing to the channel and `:1130` disables it on a bad path; `:1356` caps the log at
5000 lines. Opt-in logging with a writability pre-test and a self-disable is a design
choice. `bench/foreground-findings.md` records W7 as a 6.0.1 measurement; it is not a
9.0.x defect.

**C4 — W4 ("voice gate matches elements, not content") is disclosed at the site.**
`hooks/rot-voice-gate.sh:130-131` states it in the source's own words: `<rot:claude>`
satisfies the Claude row whatever the stanza inside says, and an empty element would
satisfy it too — named there as the honest reach of the instrument. `:184` and the block
message at `:186` make it a contract rather than a gap: *"the tag is the commitment; the
words belong to the lens"*, with an honest-empty line explicitly admissible. A limitation
a tool publishes about itself is a boundary, not a blind spot.

Twin-verified, because a clearance resting on one arm of a two-arm tool is half a clearance.
`hooks/rot-voice-gate.ps1:110-115` names **W4 by its number**, points at the `.sh` arm as the
place it is stated in full, and adds the rationale the `.sh` does not carry: *"A hook cannot
think, and a gate that graded register would block good turns on bad heuristics."* `:146-149`
carries the same honest-empty sanction with its 8.0.1 provenance, and the block message at
`:150` repeats *"the tag is the commitment; the words belong to the lens"* verbatim. The two
arms agree on the decision and on the disclosure; `:119-121` records that the field-stripping
is deliberately identical, *"exactly as the .sh arm does"*, and says why — *"a mangled charter
is cosmetic, a broken JSON block is a dead gate."*

**C5 — `bench/P22-ESTABLISHED.md` withdraws in both directions.** Its title line is
*"P2.2 — THE PANEL RAN, AND ITS RESULT IS INADMISSIBLE"*; `:46` withdraws the claim
**against** the router, `:50` names that claim *"unfavourable overclaim"*, and `:82-84`
leave the central claim *"unestablished, exactly as it was before this run."* Recorded as
an observation and deliberately not raised as a finding: the filename reads `ESTABLISHED`
while the content reads `INADMISSIBLE`. `:34` resolves it — what is established is the
record of what was observed, not the claim — and a filename ambiguity that the first line
settles is not a defect.

**C6 — `bench/hard-session-6.0.1.md` reconciles against its own ledgers, four for four.**
34048 B, 543 lines, one commit, and cited by **zero** other tracked `.md` — the empty
prior-art result was itself controlled, since the same pipeline returns 43 files for a
string known to be present. The headline at `:392-394` claims *"52 of 80 turns ended in at
least one voice-gate Stop block"*. Counted from the four turn-ledger tables rather than
from the prose: `BLOCK` rows 13 + 10 + 15 + 14 = **52**, ledger rows = **80**. The interim
claim at `:167` (*"13 gate blocks"* in turns 1–20) matches its segment exactly, and `:292`'s
*"38 of 60"* is turns 1–60 = 13 + 10 + 15 = **38**. Four counts, four exact matches — the
`README` 26-vs-47 and `status-verdict` 99-vs-100 failure mode is absent here.

One hypothesis formed and killed before publication: `hard-session-6.0.1-records.jsonl`
holds `decision_block` 0 and the word *block* 0 times, which reads at first like a headline
unsupported by its own artifact. It is a different stream, not a missing one — `:34` names
the sink `ROTMOE_DEBUG_LOG` on the worker's live environment and `:108` says *"Route data is
the `UserPromptSubmit` record from the debug sink"*; the file is **3000 `gauge` + 3000
`route`** records, while Stop-hook blocks are ledgered in the prose. The document also
discloses its own telemetry loss ahead of any auditor: `:224-226` records that
`ROTMOE_DEBUG_LOG_MAX` defaults to 5000, that the sink crossed it mid-turn 30, and that
*"the first ~1,350 records (turns 1–6 era) are gone from the live log"* — filed there as its
own finding 9.

## RETRACTED — raised during this audit and killed by their own controls

Recorded so a later reader does not re-raise them. Four of five findings this audit did not
survive verification; the pattern in every case was reading the hit that confirms and
skipping the rows beside it that explain.

| claim | why it failed |
|---|---|
| Manifest disagrees with the release identity (W1 shape). | `git show HEAD:.claude-plugin/plugin.json` and the worktree copy are both `9.0.1` — committed, not in-flight. |
| `marketplace.json` is a third disagreeing version source. | It declares no version and `.claude-plugin/marketplace.json:12` sets `"source": "./"` — it delegates to the repo manifest. Silence is the correct design. |
| `9.0.2` is declared ahead of the shipped manifest. | `9.0.0`/`9.0.1`/`9.0.2` are three archive tiers of one commit; zero tags is `NEXT-STEPS-9.0.x.md:24` step 2 not yet run. |
| Files declaring a `9.0.x` other than `9.0.1` are stale. | The detector was wrong by construction — a CHANGELOG must contain old versions. Its regex `9\.0\.[0-9]*` also matched zero digits, inventing a bare `9.0.` in four rows. |

## METHOD

Findings are gated on a record-first check before any directory is reviewed: every
basename in the target directory is grepped against the 50 record documents in one pass.
Three of this audit's early claims were rediscoveries of text already in
`FINDINGS-8.0.1.md`; the gate exists so that stops happening. It also reorders reads —
`bench/foreground-findings.md` is the machine-readable half of a pair and carries evidence
plus repro for all eight of its findings, so `bench/foreground-test.md` (54961 B, the
narrative half) is deferred rather than skipped.

**C7 — the forced-success class across all 84 checkers is a documented idiom, not a hole,
with one dead line as the exception.** Raw census: 573 swallow sites, only 9 of 84 files
clean. That number is not a finding and must not be published as one — it is W5's own error
run in the opposite direction, a wide pattern mistaken for a wide problem. Split by operator
it separates cleanly: **496 are `2>/dev/null`**, which hides stderr while the exit status
survives intact, and **119 are forced success** (`|| true`, `|| :`).

Of those 119, the overwhelming majority are one idiom — `n=$(… | grep -c . || true)` — and it
is *required*, not sloppy: `grep -c` prints `0` and **exits 1** when it matches nothing, which
under `set -e` kills the checker outright. The tree documents this in its own source at
`checker/cross-diff-remind.sh:221` and at `checker/hook-contract.sh:209-211` (*"Both were
written and both were wrong. `|| true` keeps the printed count"*). The remainder are
`rm -rf … 2>/dev/null || :` cleanup lines. Strongest evidence that the class is understood
rather than overlooked: `checker/workflow-lint.sh:1178,1191` **lints for exactly this
pattern** in workflow files, matching `*"|| true"*|*"|| :"*` and labelling it *"status
explicitly rescued"*, with probes at `:1200,1211`.

The one site that is not the idiom is `checker/release-longsession.sh:361` —
`[ "$realturns" -eq "$TOTAL_TURNS" ] 2>/dev/null || true`. 🟢, and deliberately rated low:
it buys no false green. `[` is a pure predicate, its result is assigned to nothing and
branched on nowhere, and the real check two lines down at `:362` compares against `$n` and
can still reach `bad` at `:365`. The defect is that it *reads* as an assertion while
asserting nothing, and it would be **wrong if it were ever enabled**: `TOTAL_TURNS` is a
cross-version accumulator (`:189` init, `:287` increment, `:416` print), while `:361` sits
inside the per-version block — on the second version it would compare that version's
`realturns` against v1+v2 combined. The `|| true` is the only thing keeping a wrong
comparison harmless. Present identically in worktree, index and HEAD, so it is committed,
not a staging artefact. Fix: delete the line. `:417`
`[ "$TOTAL_TURNS" -eq 0 ] && bad "NO TURN RAN AT ALL -- harness failure, not a pass"` is the
genuine anti-vacuity guard and is correct as written.

Tripped on purpose, because a clearance by reading is a clearance by intent and this class
deserved behaviour. `checker/hook-contract.sh:73` was mutated in place to
`n=$(grep -c . "/nonexistent-path-xyz" || true)` — the harshest form, where the `grep`
does not merely count zero but fails outright with exit 2 on a missing file. Result:
**`MUTANT_EXIT=1`**, with the guard printing `FAIL  no commands extracted from
hooks/hooks.json -- this checker would pass vacuously` and the run closing `0 passed,
1 failed`. The `|| true` did not buy a green, and the reason is visible two lines below it:
`:74-76` immediately audits the rescued value with `if [ "${n:-0}" -lt 1 ]` and exits 1. The
idiom rescues the *status* so the count survives; the count is then checked. That pairing is
what makes it sound, and it is the pattern the other 118 sites should be judged against.
`git status --porcelain checker/hook-contract.sh` was empty before the mutation and empty
after restore.

Still not claimed: one site of 119 was executed, not all of them. The clearance for the
remaining 118 rests on reading plus this one demonstration of the idiom's guarded form, and
any site where the rescued value is *not* audited downstream would be a genuine defect that
this pass would not have caught.
