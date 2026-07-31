<!--
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
-->

# NOTICE — provenance, licensing, and the limits of what is proved

## A. Licensing

**RoT MoE is an original work.** It is not a fork, and that single fact decides
the whole licence layout.

| file | what it is | why |
|---|---|---|
| `LICENSE` | verbatim AGPL-3.0 text | GitHub's `licensee` reads the **root `LICENSE` file only**. Measured against this org's other repo via `api.github.com/repos/.../license`, which returned `"path": "LICENSE"` and `"spdx_id": "MIT"` while dual-licence files sat beside it unread. Putting AGPL-3.0 at the root is what makes the repo detect as AGPL-3.0 instead of as nothing. |
| `LICENSE-EUPL-1.2` | verbatim EUPL-1.2 text | the second half of the grant, in the place a human looks |
| `LICENSES/AGPL-3.0-or-later.txt`, `LICENSES/EUPL-1.2.txt` | both texts | the [REUSE](https://reuse.software/) layout, for tooling |

**The grant is `AGPL-3.0-or-later OR EUPL-1.2`, at the recipient's option**, and
it covers **every file in this repository**. Every source file carries the SPDX
tag and `Copyright 2026 Saimonokuma.` in its own header, enforced by
`checker/spdx-sweep.sh`.

### A.1 How this differs from the sibling repo, and why

`Nova-Violet-Role/claude-rolling-context-Lean-4-` is explicitly **a fork**. Its
root `LICENSE` stays MIT © NodeNestor because a fork may not relicense the work
it inherited; the dual grant there covers only the directory of new work. That
repo's own `NOTICE.md` §B records a correction where its Lean proofs had
wrongly carried mathlib's Apache-2.0 header.

RoT MoE inherits no upstream code, so it has no such constraint — and it also
inherits that lesson. **mathlib's Apache-2.0 header must never be pasted into a
file here.** The Lean sources are built *against* mathlib; they are not derived
from it, and carrying its header would misattribute the work. `spdx-sweep.sh`
fails the build if that header appears.

### A.2 Dependencies, which are not covered by the grant above

* **Lean 4** and **mathlib4** — Apache-2.0, © their authors. This project
  depends on them at build time and vendors none of their source. The pinned
  revision is in `lean/lakefile.toml`; the toolchain is in `lean/lean-toolchain`.
* **Claude Code** is a third-party product. This repo is not affiliated with or
  endorsed by Anthropic. "Claude" is used nominatively to say what this plugin
  plugs into.

### A.3 `agents/lean4-prover.md` declares a derivation, and it is credited here

The prover head opens with a sentence it inherited from the private original:

> *"Adapted from Mistral's Leanstral system prompt (`vibe/core/prompts/lean.md`),
> with the local toolchain facts measured on this machine and the verification
> discipline made non-negotiable."*

That is the document's own account of where it came from, so it is stated here
rather than quietly dropped — **an omitted credit is the same defect as a false
one**, and the file would have shipped carrying the sentence either way.

What is credited: the *shape* of a Lean-specialist system prompt (prime rule,
tactic ladder, reporting contract) as adapted from that upstream. What is not:
the substance this repo adds — the instrument table, the mutation discipline,
the ELAN arsenal map, the `leanchecker` ritual and every measured fact, all of
which were written and measured here.

**Unresolved, and stated as unresolved rather than assumed:** the licence of the
upstream prompt has not been verified from a primary source by this project. The
dual grant in §A applies to *this* repository's original content; it makes no
claim over anything traceable to that upstream. If the derivation is found to be
more than structural, or the upstream terms turn out to be incompatible, the
correct fix is to rewrite the affected passages — not to delete this paragraph.
Tracked as an open alarm (R22) rather than treated as settled.

---

## B. What the proofs cover, and what they do not

The README carries the full boundary section. The short form, repeated here
because a `NOTICE` is where a lawyer or a packager looks and neither will read
the README:

1. **No theorem in this repository says anything about output quality.** Not
   that routed reasoning is better, not that the gauge improves an answer. Those
   are empirical claims outside Lean's reach entirely. Where such a property is
   tested, it is labelled **MEASURED**, never PROVED.
2. **`RotRoute.lean` models a specification, not shipping code.** TIER 1 keyword
   routing is not implemented in the PowerShell hook that ships today — the hook
   implements the gauge. Until the POSIX port lands, "verified router" is
   accurate about the *gauge* and about the *spec*, and not about routing in the
   shipped artifact. This limitation is written into the module's docstring so
   it cannot be lost by editing this file.
3. **`RotInstall.lean` proves the merge is sound, not that the file is written
   correctly.** Lean sees a finite map. It cannot see byte-order marks, line
   endings, key order, or indentation, and those are exactly how a settings
   writer corrupts a file in practice. `checker/install-roundtrip.sh` covers
   that half: 21 checks and 5 negative controls against a scratch config
   directory, never the live one.
6. **The installer normalizes JSON layout.** Keys, values, order, BOM state and
   indent width survive exactly; intra-line layout does not, because the merge
   round-trips through a JSON parser rather than editing text. Measured on a
   hostile fixture: **678 → 872 bytes with every value identical**. On a file
   already in canonical form the round trip is **byte-identical**, asserted
   separately as R5b. Stating this matters because the spec named a real
   3 674 → 9 564 byte reformat as a hazard: this installer is not that, but it
   is not a text-preserving editor either, and the difference is measured
   rather than claimed.
7. **The BOM rule departs from the written spec, deliberately.** The spec says
   "writes UTF-8 without BOM". The live `settings.json` on the development
   machine **already has one**, and `JSON.parse` fails on it until stripped.
   Writing it back without a BOM would silently alter the first three bytes of
   a file the installer was told to preserve — the exact class of change the
   preservation rule forbids. So the installer **preserves the input's BOM
   state**: none added if none present, an existing one kept. The rule's
   purpose (never *add* a BOM) is met; its literal wording is not, and that is
   the correct trade.
4. **The uninstaller is lossy in one identified case, and this is proved rather
   than disclaimed.** `disarm_arm_id` holds only under an explicit freshness
   hypothesis, and `disarm_arm_not_id` proves that hypothesis cannot be dropped:
   if you had already registered the same hook command by hand, install +
   uninstall removes your entry. Keep the backup the installer writes.
5. **`Float ≠ ℝ`.** The executable `#eval` corpus mirrors the real-valued
   definitions in `Float` so the spec can be run on concrete inputs. Agreement
   between that mirror and the live hook is **MEASURED** — four vectors, matching
   to two decimals — and is not a theorem.

---

## C. Instruments and their controls

Every claim in this repo names the instrument behind it. Every instrument has a
recorded way to fail, because a check that has never been observed failing is
indistinguishable from no check at all.

| instrument | pass | negative control |
|---|---|---|
| `lake build Proofs.<M>` | exit 0, read directly and never through a pipe | any type error → non-zero |
| `#print axioms` | no `sorryAx` | a `sorry` introduces it |
| `lake env leanchecker Proofs.<M>` | exit 0, **zero bytes** | a module with no oleans → exit 1, `Could not find any oleans for:` |
| mutation suites | every mutant KILLED | a mutant that did not apply is **DISCARDED**, never counted as SURVIVED |
| `checker/spdx-sweep.sh` | exit 0 | strip one SPDX tag → exit 1 |
| `checker/no-local-paths.sh` | exit 0 | plant one machine-local path → exit 1 |

### C.1 Two instrument defects found in this repo's own checkers

Recorded rather than quietly fixed, because a checker that has been wrong once
should be read with that history visible.

* **The path sweep produced a FALSE GREEN.** Written as a single `grep -E`
  alternation, it reported a clean tree while fourteen occurrences of a
  machine-local path sat in the shipped scripts. Cause: one forbidden pattern
  legitimately ends in a backslash (`D:\` — R2-ALLOW), and in ERE `\|` is an *escaped
  pipe* — a literal `|`. The escape ran into the separator and collapsed the
  entire expression into one literal string matching nothing. Fixed by moving
  to `grep -F -f` over a data file, where no metacharacter has meaning, and by
  adding a positive control that plants a needle and requires it to be found.
* **The SPDX sweep over-reported.** `for f in $(find ...)` word-splits on
  spaces, and the development checkout path contains them; it claimed 68 files
  missing a header in a tree of seventeen. It also matched **itself**, because
  the mathlib header it searches for is necessarily written inside it. Fixed by
  reading the file list without word-splitting and by excluding the checker
  from its own scan.

The first failed silently in the reassuring direction; the second failed loudly
in the safe one. Only the difference in luck separated them, which is why both
checkers now begin by proving they can still see.
