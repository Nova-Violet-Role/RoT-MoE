<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# How to work with this repository

**Audience.** Anyone — human or agent — about to change RoT MoE and push it to
`github.com/Nova-Violet-Role/RoT-MoE`.

**The one rule everything else serves:** a green build is a *measurement*, and a
measurement you did not take is not a result. Every procedure below exists
because skipping it has already produced a false green on this repo.

---

## 1. Before you touch anything: take a baseline

```sh
bash checker/gate-all.sh          # 33 gates, >10 min -- run it, do not skip it
```

A repository that was **already red is not your regression**, and you cannot know
which it was after you start editing. This is not ceremony: the last session
opened with one red gate (`workflow lint + drift`) caused by an *unrelated
plugin* overwriting `.githooks/pre-commit` with a version whose header read
*"Never blocks a commit: every failure path exits 0"*. Had that been discovered
after the edits, it would have been attributed to them.

If a gate is red before you start, **write down which one**, then decide
deliberately whether to fix it first or work around it.

### Reading exit codes

```sh
bash checker/cross-diff.sh; echo "EXIT=$?"          # correct
bash checker/cross-diff.sh | tail -5; echo "EXIT=$?" # WRONG -- that is tail's status
```

`$?` after a pipe is the *last* command's status. This has produced a false green
here. When you need both the code and the output:

```sh
bash checker/cross-diff.sh > /tmp/out.log 2>&1; echo "EXIT=$?"; tail -5 /tmp/out.log
```

---

## 2. The change itself

### 2.1 Both arms, always

Every hook ships twice: `*.sh` (POSIX) and `*.ps1` (PowerShell). **A fix to one
arm that does not reach the other is a defect**, and it will not be obvious —
Windows and Linux users simply get different answers.

`checker/cross-diff.sh` and `checker/cross-diff-remind.sh` compare the arms
row-by-row. Run both after any hook change.

Known asymmetries that are *not* bugs: path spelling under MSYS (`/tmp/x` vs
`D:/tmp/x`), and the PowerShell route record carrying an extra `"ms"` field.

### 2.2 If it changes behaviour, it changes the Lean spec

This repo's rule, and the reason it exists: a checker that asserts what the code
already does can be satisfied by editing the checker. A theorem cannot.

```sh
cd lean
lake build Proofs.<Module>; echo "EXIT_DIRECT=$?"       # never through a pipe
lake env leanchecker Proofs.<Module>; echo "EXIT=$?"    # kernel re-verification
```

Then audit what the theorem rests on:

```sh
cd lean && printf 'import Proofs.<Module>\n#print axioms <Namespace>.<thm>\n' > .probe.lean
lake env lean .probe.lean; rm -f .probe.lean
```

`propext`, `Classical.choice`, `Quot.sound` are fine. `sorryAx` means **not
proved**. A theorem depending on *nothing* is usually vacuous rather than strong.

`checker/axiom-audit.sh` does this over every module; run it rather than trusting
a spot check.

### 2.3 Mutate what you added

A theorem no mutation kills is decorative. A gate no mutation reddens is an
untested alarm. Both get labelled as such, or they get fixed.

```sh
bash lean/mutate/mutate_<module>.sh; echo "EXIT=$?"
```

A mutation is evidence **only if it landed**. Every harness here counts its
needle before patching and reports three outcomes, never two:

| outcome | means |
|---|---|
| `KILLED` | the theorem was load-bearing |
| `SURVIVED` | a claim about the theorem — it did not constrain what it appeared to |
| `DISCARDED` | a claim about the *harness* — the patch never applied, nothing was tested |

Folding `DISCARDED` into `SURVIVED` is how a mutation suite lies in the
reassuring direction. `checker/mutant-discipline.sh` enforces that every
patch-applying harness names the third category.

**End at a verified green baseline.** A suite that restores sources but does not
rebuild leaves the tree compiled-out; that has already happened here and the
damage surfaced two gates later as *"the axiom probe did not elaborate"*.

---

## 3. Before you commit

Run these; each has caught a real defect:

```sh
bash checker/repo-complete.sh    # counts in every doc match the source; anchors resolve
bash checker/verdict-fresh.sh    # STATUS.md matches checker/status-verdict.sh
bash checker/release-consistency.sh
bash checker/portability.sh      # exec bits, shebangs, no bashisms in sh scripts
bash checker/no-local-paths.sh   # no machine-local path leaked into the packet
bash checker/workflow-lint.sh    # every checker is actually run by a workflow
```

### If you added a checker

Four edits, and **all four are required** — three gates independently enforce
this and will refuse otherwise:

1. `chmod +x checker/<new>.sh` **and** `git update-index --chmod=+x` (the index
   bit is what CI sees; the filesystem bit is not enough);
2. register it in `checker/gate-all.sh` with its tier and triggers;
3. add it to `shipped` in `lean/Proofs/RotGates.lean` and update the `#guard`
   totals — `checker/gate-split.sh` compares the shell table to the Lean witness
   and fails if they disagree;
4. add a step to `.github/workflows/ci.yml` — `workflow-lint` fails with
   `NOT RUN BY ANY WORKFLOW` otherwise.

### If you changed counts

Theorem counts appear in five files and are re-measured from source:

```sh
bash checker/count-theorems.sh lean/Proofs/*.lean      # the truth
# then update: .claude-plugin/marketplace.json, .claude-plugin/plugin.json,
#              CITATION.cff, README.md, CHANGELOG.md
bash checker/status-verdict.sh                          # regenerate the STATUS block
```

`CHANGELOG.md`'s **newest section only** is a live claim; older releases live in
`CHANGELOG-ARCHIVE.md` and are exempt as history. A prior-versus-after table sits
inside the live section, so its PRIOR cells must describe *what changed* rather
than restate a superseded total — otherwise a correct historical number lands
where the checker can only read it as a false present claim.

---

## 4. Committing, tagging, releasing

### 4.1 The release triple

Three tags on **one commit**: `vX.Y.0`, `vX.Y.1`, `vX.Y.2`. The patch digit *is*
the tier — `0` Pure Router, `1` Router + Lean 4, `2` Router + Lean + Extra — and
this convention holds for every release in the archive.

`.claude-plugin/plugin.json` carries the `.2`. That is why a **directory- or
git-sourced** marketplace install reports the `.2` version: it installs the tree,
and the tree is the unsealed superset. The `.0` and `.1` tiers are what
`checker/release-package.sh` carves out of that one commit.

```sh
bash checker/release-package.sh                  # builds all three zips
bash checker/release-package.sh --print-variants  # the map, asked for not grepped
bash checker/release-install.sh                   # installs each as a stranger would
bash checker/tags-consistency.sh
```

A version bump is **one edit** — `plugin.json` — plus the doc counts. The
packager derives the triple from it; do not reintroduce a hardcoded list.

### 4.2 The pre-commit hook

`.githooks/pre-commit` runs the fast tier. If another tool overwrites it (the
CodeMap plugin has), restore it and use the delegate slot instead:

```sh
git checkout -- .githooks/pre-commit
ls .githooks/pre-commit.d/        # cooperating tools belong HERE
```

A pre-commit hook whose failure paths all `exit 0` is not a hook.

### 4.3 Never force-push, never rewrite published history

**Branch history is never rewritten. Full stop.**

Tags are narrower than this section used to claim, and the difference decides
whether a re-tag is routine or destructive. Measured:

* `.claude-plugin/marketplace.json` declares `"source": "./"`, and a
  `claude plugin marketplace add Nova-Violet-Role/RoT-MoE` resolves the
  **default branch**, not a tag. A directory-sourced install records
  `"source": "directory"` and a path. **Neither reads a tag.**
* What *is* pinned to a tag is a **GitHub Release** — its source archive and its
  assets. Move a tag that has a Release attached and every download published
  under it silently changes meaning.

So the rule is a boundary, not a blanket:

| state of the tag | may it move |
|---|---|
| created, pushed, **no Release attached** | yes — and this is the last moment it is free |
| **a Release is published on it** | **never.** People have the checksums |

Re-tagging onto a later commit before publishing is how a triple ends up on a
commit whose CI is actually green. Re-tagging after publishing is how a
`SHA256SUMS.txt` someone saved stops matching the file they can download.

### 4.4 Dispatching a pre-release — the measured procedure

**There is no release-publishing workflow.** The four workflows are
`ads-manager`, `ci`, `tag-manager` and `verify`; `tag-manager` only refreshes
the tag block inside notes of releases that are **already published**. Nothing
creates a Release, uploads an asset, or fires on a tag push. `gh` is not
installed on the author's machine either, so this step is done by hand, with a
token or in the GitHub UI.

Order matters, and every step has an exit code you read directly:

```sh
# 1. CI green on the exact commit you are about to tag -- all four jobs
#    (checkers on ubuntu/macos/windows, and lean). Not "the last run", THIS commit.

# 2. the payloads, rebuilt from that commit
bash checker/release-package.sh          # 3 zips + SHA256SUMS.txt, or exit 1
bash checker/release-install.sh          # installs each one as a stranger would

# 3. the tags, onto the green commit
git tag -f -a v0.7.0 -m "Router"                <green-sha>
git tag -f -a v0.7.1 -m "Router + Lean"         <green-sha>
git tag -f -a v0.7.2 -m "Router + Lean + Extra" <green-sha>
git push -f origin v0.7.0 v0.7.1 v0.7.2   # allowed ONLY while no Release exists

# 4. three Pre-Releases, one per tag, each carrying its OWN archive and the
#    shared SHA256SUMS.txt. Mark them pre-release; every 0.7.x is pre-release.

# 5. verify from OUTSIDE: download each published asset from its URL, check it
#    against the published sums, unzip it, and run ITS OWN hooks/rot-router.sh.
#    A release nobody downloaded is a release nobody tested.
```

Step 5 is not ceremony. The archives are verified locally by the packager
(`checker/release-package.sh` refuses to emit sums for an artifact it did not
bless, and a tampered byte fails `-c`), but that proves the *build* was sound,
not that the *upload* was. Only fetching the published bytes tests the upload.

**The tier names go in the tag annotation and the release title**, because the
patch digit alone does not tell a reader which one to take:

| tag | title |
|---|---|
| `v0.7.0` | Router |
| `v0.7.1` | Router + Lean |
| `v0.7.2` | Router + Lean + Extra |

**Until a Release exists, every download link in the docs is a 404** — however
correct its filename. `checker/readme-variants.sh` proves the names match what
the packager builds; it cannot prove the file was uploaded, and it says so.

---

## 5. Testing an install for real (CTT)

Never test installer changes against the configuration you are using. Point at a
scratch config:

```sh
CLAUDE_CONFIG_DIR=/tmp/scratch bash ARM_ROUTER.sh
```

For a full end-to-end check, use the cloned CLI instance:

```sh
export CLAUDE_CONFIG_DIR="<CTT>/.claude"
cp "$CLAUDE_CONFIG_DIR/settings.json" "$CLAUDE_CONFIG_DIR/settings.json.pre-<reason>.bak"
claude plugin marketplace update rot-moe
claude plugin update rot-moe@rot-moe          # `install` says "already installed"
```

Then verify — and these four are the whole point:

```sh
node hooks/plugin-detect.js "$CLAUDE_CONFIG_DIR"        # 0 = a live registration
grep -c rot-router "$CLAUDE_CONFIG_DIR/settings.json"    # MUST be 0 for a plugin install
bash ARM_ROUTER.sh                                       # MUST refuse, exit 0
md5sum "$CLAUDE_CONFIG_DIR/settings.json"                # MUST be unchanged
```

**Zero settings entries plus a live plugin is the correct state** — one firing
path. If `ARM_ROUTER` writes an entry there, the router fires twice per prompt
and nothing in the session looks wrong: the lane is right and the gauge is right,
twice.

The cache accumulates every version you have ever installed.
`plugins/installed_plugins.json` names the one that actually loads; the rest are
inert. Do not read the cache directory as a list of active registrations.

---

## 6. Things that will bite you

| trap | what happens | do this |
|---|---|---|
| exit code through a pipe | reports the pipe's status; **false green** | read `$?` directly |
| `sed` bracket class on non-ASCII | strips *some* UTF-8 bytes, leaves the rest | `tr -d '\200-\377'` first |
| POSIX path in a JSON manifest | node/PowerShell resolve it to another drive | write the native form (`cygpath -w`) |
| blanket string replace | `->` also rewrites the `->` inside `<->` | longest distinctive form first, then grep for the mangling |
| Lake incremental build | a mutant "survives" because nothing rebuilt | `rm .lake/build/lib/lean/Proofs/<M>.olean` first |
| well-founded Lean recursion | `decide` cannot reduce it | make it structural |
| `leanchecker --help` | **hangs forever** on stdin | always pass a module name |
| killing by process pattern | takes down unrelated services | stop by exact PID |
| paths with spaces | `GIT External Repo`, `RoT MoE` word-split | `git ls-files -z`, quote everything |

---

## 7. What a good commit message looks like here

State the **defect**, the **measurement**, and the **instrument** that now
catches it. The subject line is a finding, not a category:

```
a stem that matches inside a word routed `improve` to FORGE -- so `prove` could never be added

MEASURED on the shipped router: `prove this lemma` -> CONVERGENT, and
`prove ... bytes in lean` -> STEALTH (it matched `byte`). ...

12 corpus rows in both directions; reverting the matcher turns 12 red.
```

`git log` is the only place a future reader learns *why* a check exists. "fix
routing" teaches nobody anything.

## 5. The debug log subsystem — how to work with it

Arming (`ARM_ROUTER.sh` / `ARM_ROUTER.ps1`) writes a default `ROTMOE_DEBUG_LOG`
if and only if you have none; disarm removes only its own default, never a
value you set. Env vars:

| var | meaning |
|---|---|
| `ROTMOE_DEBUG_LOG` | central sink path; unset = no central log |
| `ROTMOE_DEBUG_LOG_MAX` | rotation cap, default 5000 records |
| `ROTMOE_DEBUG_LOCAL` | per-session sink control |
| `ROTMOE_DEBUG_SRC` | provenance tag; every harness MUST set `test` |

Per-session log: `<project>/.rot-moe/rot-route-<session>.jsonl`, self-ignoring
via its own `.gitignore` — never commit it, never rely on it being committed.

Rules when touching this subsystem:

1. Any new checker that feeds the router synthetic payloads MUST export
   `ROTMOE_DEBUG_SRC=test` — otherwise it poisons every health figure computed
   from the central log. Eight checkers already do; copy their preamble.
2. Never filter the log by `event` to find live traffic; filter by `src`.
   Harness records may carry real event names (`hook-contract.sh` does).
3. Both arms (`hooks/rot-router.sh`, `hooks/rot-router.ps1`) must change in
   lockstep; `checker/cross-diff.sh` and `checker/session-log.sh` enforce it.
4. A new alarm counts only after you have tripped it deliberately once and
   watched it fire. Gate it in `checker/session-log.sh`.
5. `lean/Proofs/RotSessionLog.lean` owns the filename-safety proofs. If you
   change the sanitiser alphabet, pin it from the outside (literal set), never
   via its own predicate — see mutant S03 in `docs/SCRUTINY-LOG.md`.
6. No `private theorem` anywhere: `checker/axiom-audit.sh` fails the repo on
   sight, because private names are invisible to `#print axioms`.
