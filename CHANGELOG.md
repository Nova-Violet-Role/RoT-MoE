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

## The three numbers are not a roadmap

`0.7.0`, `0.7.1` and `0.7.2` are **released together, on the same commit**. The
version *is* the variant. Nothing in `0.7.1` supersedes `0.7.0`; it adds a
Lean 4 workshop on top of it. Nothing in `0.7.2` fixes `0.7.1`; it unseals a
tactic that `0.7.1` withholds **by policy**, and ships the instrument that keeps
that honest.

| pick | if you want |
|---|---|
| `0.7.0` Pure Router | the nine-lane router and nothing else. No Lean, no toolchain, no network. |
| `0.7.1` Router + Lean 4 | the same router **plus the machine that makes the theorems** — bounded installer, official hosts, your own proved repos. |
| `0.7.2` Router + Lean + Extra | all of the above with `native_decide` unsealed, and `checker/axiom-class.sh` to tell KERNEL from COMPILER trust. |

The patch digit **is** the tier, and it has been for every release in
[`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md): `0` core, `1` lean, `2` unsealed.
`.claude-plugin/plugin.json` carries the `.2` by convention, so a **directory- or
git-sourced** marketplace install reports `0.7.2` — it is installing the tree,
and the tree is the unsealed superset. The `.0` and `.1` tiers are what the three
`.release/` archives carve out of it, which is why
`checker/release-package.sh` builds all three from one commit and now derives
their versions from that manifest instead of a hardcoded triple.

---

## PRIOR → AFTER, at a glance

Every row was **measured on the shipped code**, before and after. This table is
the whole release in one screen; the sections beneath it give each row its
evidence.

| # | what | PRIOR (0.6.2, measured) | AFTER (0.7.x, measured) |
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
| 14 | theorems / modules | 205 / 14 | **281 / 18** |
| 15 | gates | 29 | **33** (22 fast, 11 deep) |
| 16 | mutation suites | 10 suites | **14 suites — 116 applied, 116 killed**, 0 survived, 0 discarded |

Rows 1–8 are defects that **had already reached a live machine** while
twenty-nine gates were green. Rows 9–12 are a routing fix that could not be made
until the matcher itself was specified. Row 13 is the instrument that would have
caught a drift nobody was watching for.

> **Why the PRIOR column never restates an old total.** `checker/repo-complete.sh`
> re-measures every "N applied, M killed" in this file against the suites as they
> exist **today**, and the newest section is scanned in full — a prior-versus-after
> table lives inside it. Writing the previous release's total there would put a
> correct historical number where the checker can only read it as a false present
> claim. The PRIOR cells therefore say what *changed* (ten suites became twelve);
> the settled totals stay in
> [`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md), which is exempt as history.
> The alternative — loosening the rule so it skips table rows — would have put a
> hole in the one check that stops a mutation claim from drifting.

---

## [0.7.0] · [0.7.1] · [0.7.2] — 2026-08-04

Three archives, one tree. The patch digit is the tier: `0` core, `1` lean,
`2` unsealed.

**Every defect fixed in this release had already reached a live machine while
twenty-nine gates were green.** That is the only sentence of this entry that
matters, and it is the reason four of the additions below are gates rather than
features.

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

### New Lean modules

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

- **281** machine-checked theorems across 18 modules (was 205 across 14),
  0 `sorry`, 0 `native_decide`, 0 build warnings.
- **33** gates (was 29); 22 fast, 11 deep.
- Every new theorem `#print axioms`-audited and `leanchecker`-re-verified.

---

