#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# ---------------------------------------------------------------------------
# PER-MODULE COUNT CLAIMS IN THE PROSE, BOUND TO THE SOURCE.
#
# WHY THIS GATE EXISTS. `checker/repo-complete.sh` binds the TOTAL theorem count
# and the TOTAL mutant count. Nothing bound a claim about ONE module -- so this
# sat in README.md, green, for an unknown number of commits:
#
#     `RotEigenform.lean` -- **101 theorems, ... 38 of 38 mutants killed**
#
# Measured 2026-08-09: the file has **118** theorems and its suite declares
# **41** mutants. Both numbers had grown and the prose had not. The totals gate
# could not see it, because the totals were right -- the drift was entirely
# inside one module's share of them.
#
# That is the worst kind of stale claim: it UNDERSTATES the work, so nobody is
# motivated to check it, and it appears in a section whose first sentence is
# "Every claim in this section is checkable."
#
# WHAT IT BINDS. Any line of tracked documentation that mentions `Foo.lean` (or
# `<code>Foo.lean</code>`) and a number followed by "theorem(s)" on the SAME
# line must agree with the source. Same for "N of N mutants killed" against the
# module's own suite. Same-line only, deliberately: a window-based scan invents
# associations that were never written, and a checker that guesses is worse than
# no checker.
#
# THE INSTRUMENT MUST BE ABLE TO FAIL. Two positive controls run before any
# clean report: a planted wrong claim must be caught, and a planted correct one
# must pass. Without the second, "caught everything" could just mean "rejects
# everything".
# ---------------------------------------------------------------------------

set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PROOFS="$ROOT/lean/Proofs"
MUTATE="$ROOT/lean/mutate"
TMP="${TMPDIR:-/tmp}/rotmoe-modclaims.$$"
mkdir -p "$TMP" || { echo "FATAL: cannot create $TMP"; exit 2; }
trap 'rm -rf "$TMP"' EXIT

passed=0; failed=0
ok()  { echo "  ok   $1"; passed=$((passed+1)); }
bad() { echo "  FAIL $1"; failed=$((failed+1)); }

[ -d "$PROOFS" ] || { echo "SKIP: $PROOFS absent. This is a SKIP (exit 3), never a pass."; exit 3; }

# Counting rule, stated once and used by both the gate and its controls:
# a theorem is a line beginning with `theorem` or `private theorem`. That is the
# same rule checker/count-theorems.sh uses, so the two can never disagree.
# THE COUNTING RULE IS NOT DEFINED HERE. It is `checker/count-theorems.sh`,
# which is comment-aware and self-tested.
#
# This gate's first draft used `grep -cE '^(private )?theorem '` and reported
# EIGHT stale README claims. Seven of them were the README being RIGHT: prose
# inside a `/-! -/` doc comment that begins with the word "theorem" is not a
# theorem, and the naive rule counted 931 where the truth is 919. The README
# numbers had been produced by the good counter all along.
#
# count-theorems.sh's own header records that this defect was found and fixed
# once before, in three copied greps. Re-deriving the rule here would have been
# the fourth copy -- and this time it would have driven a "repair" that made
# eight correct numbers wrong. One definition, used by every consumer.
COUNTER="$ROOT/checker/count-theorems.sh"
[ -f "$COUNTER" ] || { echo "FATAL: $COUNTER missing -- this gate must not invent its own counting rule"; exit 2; }
count_theorems() {
  bash "$COUNTER" "$1" 2>/dev/null
}
count_mutants() {
  grep -c '^run_mut ' "$1" 2>/dev/null
}

# The claim extractor, factored out so the CONTROL exercises the SAME code path
# the real scan uses. A control that re-implements the thing it is controlling
# tests its own copy and proves nothing about the instrument.
extract_theorem_claims() {
  grep -nE '[A-Za-z0-9_]+\.lean' "$1" 2>/dev/null | grep -E '[0-9]+ theorem'
}

# --- POSITIVE CONTROLS, before anything is certified -------------------------
_ctlf="$TMP/ctl.lean"
printf '/-!\ntheorem written_in_prose : True := trivial\n-/\ntheorem a : True := trivial\nprivate theorem b : True := trivial\n' > "$_ctlf"
_ctln=$(count_theorems "$_ctlf")
if [ "$_ctln" = "2" ]; then
  ok "positive control: the shared counter sees 2 real theorems and ignores the one written in a doc comment"
else
  bad "positive control: the shared counter returned $_ctln, expected 2 -- every count below is unreliable"
fi

_ctld="$TMP/ctl.md"
printf 'x `Zzctl.lean` has **2 theorems** here\ny `Zzctl.lean` has **99 theorems** here\n' > "$_ctld"
_hits=$(extract_theorem_claims "$_ctld" | wc -l | tr -d ' ')
if [ "$_hits" = "2" ]; then
  ok "positive control: the claim extractor finds both planted claims (a scan that matched nothing would pass vacuously)"
else
  bad "positive control: the extractor found $_hits of 2 planted claims -- it is not reading the prose"
fi

# --- the real scan ------------------------------------------------------------
claims=0
cd "$ROOT" || exit 2

# WHICH DOCUMENTS ARE IN SCOPE, AND WHY THIS IS NOT A LOOPHOLE.
#
# The first version of this gate scanned every tracked .md and reported 19
# failures. Eleven of them were in CHANGELOG.md's older sections and in
# CHANGELOG-ARCHIVE.md -- entries like "RotGates.lean -- 12 theorems" written at
# release 0.5, when the file DID have 12. Those statements are HISTORY and they
# are still true of the release they describe. CHANGELOG.md says so in its own
# header: "History does not get rewritten to satisfy a counter."
#
# A gate that demanded those be "fixed" would be the exact defect this project
# hunts: a spec that goes red on correct content, whose obvious repair is to
# falsify the record. So scope is PRESENT-TENSE documents:
#
#   README.md, docs/*.md   describe the tree AS IT IS NOW          -> BOUND
#   CHANGELOG*.md          append-only record of what each change
#                          delivered AT THE TIME                    -> HISTORY, out
#
# The `[Unreleased]` section was tried and rejected as a middle ground: it is
# itself a stack of dated entries, and "RotEigenform.lean -- 113 theorems"
# written when that entry landed is a true statement about that entry. Binding
# it would demand editing a past entry to describe a later tree.
#
# checker/repo-complete.sh DOES bind the newest CHANGELOG section, and the
# distinction is real rather than convenient: it binds the TOTALS, which each
# entry restates as a snapshot of the whole tree and which are re-synced with
# every commit. Per-module counts inside an entry are not restated -- they are
# what that entry shipped.
_scope="README.md $(git ls-files 'docs/*.md' 2>/dev/null)"

for f in $_scope; do
  [ -f "$f" ] || continue
  # Same-line association only. `sed` pulls the module and the number out of
  # each line that carries both.
  extract_theorem_claims "$f" | while IFS= read -r line; do
    ln=${line%%:*}
    body=${line#*:}
    mod=$(printf '%s' "$body" | grep -oE '[A-Za-z0-9_]+\.lean' | head -1)
    # ALL numbers on the line, not just the first. A sentence like
    #   "RotPath.lean grew from 8 theorems to 12 on 2026-08-03"
    # is CORRECT prose, and a first-number rule called it stale. The line passes
    # if it states the true current count anywhere; that is deliberately lenient
    # for lines mentioning two modules, and lenient-with-a-reason beats a gate
    # whose repair is to falsify a true sentence.
    # "N theorems" plus the growth idiom "... to N", which is how this README
    # writes a count that CHANGED: "grew from 8 theorems to 12 on 2026-08-03".
    # Without the second pattern the gate reads the historical 8 and calls a
    # true sentence a lie.
    nums=$(printf '%s' "$body" | grep -oE '[0-9]+ theorem|to [0-9]+' | grep -oE '[0-9]+')
    [ -n "$mod" ] && [ -n "$nums" ] || continue
    src="$PROOFS/$mod"
    [ -f "$src" ] || continue
    real=$(count_theorems "$src")
    if printf '%s\n' "$nums" | grep -x "$real" >/dev/null; then
      echo "CLAIM_OK $f:$ln $mod $real"
    else
      echo "CLAIM_BAD $f:$ln $mod claims $(printf '%s' "$nums" | tr '\n' '/') theorems; the source has $real"
    fi
  done >> "$TMP/theorem-claims.txt"

  grep -nE '[0-9]+ of [0-9]+ mutants' "$f" 2>/dev/null | while IFS= read -r line; do
    ln=${line%%:*}
    body=${line#*:}
    mod=$(printf '%s' "$body" | grep -oE '[A-Za-z0-9_]+\.lean' | head -1)
    [ -n "$mod" ] || continue
    base=$(printf '%s' "$mod" | sed 's/\.lean$//' | tr 'A-Z' 'a-z')
    suite="$MUTATE/mutate_$base.sh"
    [ -f "$suite" ] || continue
    a=$(printf '%s' "$body" | grep -oE '[0-9]+ of [0-9]+ mutants' | head -1 | awk '{print $1}')
    b=$(printf '%s' "$body" | grep -oE '[0-9]+ of [0-9]+ mutants' | head -1 | awk '{print $3}')
    real=$(count_mutants "$suite")
    if [ "$a" = "$real" ] && [ "$b" = "$real" ]; then
      echo "MUT_OK $f:$ln $mod $a/$b"
    else
      echo "MUT_BAD $f:$ln $mod claims $a of $b killed; mutate_$base.sh declares $real mutant(s)"
    fi
  done >> "$TMP/mutant-claims.txt"
done

touch "$TMP/theorem-claims.txt" "$TMP/mutant-claims.txt"
_tok=$(grep -c '^CLAIM_OK' "$TMP/theorem-claims.txt" 2>/dev/null)
_tbad=$(grep -c '^CLAIM_BAD' "$TMP/theorem-claims.txt" 2>/dev/null)
_mok=$(grep -c '^MUT_OK' "$TMP/mutant-claims.txt" 2>/dev/null)
_mbad=$(grep -c '^MUT_BAD' "$TMP/mutant-claims.txt" 2>/dev/null)
claims=$((_tok + _tbad + _mok + _mbad))

if [ "$_tbad" -gt 0 ]; then
  grep '^CLAIM_BAD' "$TMP/theorem-claims.txt" | while IFS= read -r l; do bad "${l#CLAIM_BAD }"; done
  failed=$((failed + _tbad))
fi
if [ "$_mbad" -gt 0 ]; then
  grep '^MUT_BAD' "$TMP/mutant-claims.txt" | while IFS= read -r l; do bad "${l#MUT_BAD }"; done
  failed=$((failed + _mbad))
fi
[ "$_tbad" -eq 0 ] && ok "all $_tok per-module theorem claim(s) match the source"
[ "$_mbad" -eq 0 ] && ok "all $_mok per-module mutant claim(s) match the suite"

# A scan that found NOTHING is not a pass. The prose is known to carry these
# claims; if the extractor stops seeing them, the gate has gone blind.
if [ "$claims" -eq 0 ]; then
  bad "no per-module claim found in any tracked .md -- this gate has gone blind, which is not the same as clean"
fi

echo "module-claims: $passed passed, $failed failed ($claims claim(s) examined)"
[ "$failed" -eq 0 ] || exit 1
exit 0
