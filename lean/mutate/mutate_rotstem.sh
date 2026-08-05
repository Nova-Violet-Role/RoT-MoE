#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotStem.lean, the STEM MATCHER.
#
# WHY THIS SUITE EXISTS, and why its absence was a hole rather than an oversight.
# RotStem shipped in an early release with theorems about WHICH CLASS FIRED and
# no suite of its own. In 0.7.0 it gained the specification of HOW A CLASS
# DECIDES -- `firesWord_imp_fires`, the theorem that made it safe to change the
# live router's matcher. That theorem is the strongest safety claim in the
# release, and until this file existed nothing had ever tried to break it.
#
# A theorem no mutation kills is decorative. The headline theorem of a release
# is the last one that should be taken on trust.
#
# The contract, identical to the other suites in this directory:
#   1. assert the needle is present EXACTLY once before mutating; if not -> DISCARDED
#   2. assert the mutation LANDED after patching (needle gone, replacement present)
#   3. delete the stale .olean so Lake cannot skip the rebuild
#   4. rebuild, read the exit code DIRECTLY
#   5. restore from the backup, ALWAYS, and rebuild to a verified green baseline
#
# DISCARDED != SURVIVED. The first is a defect in this harness, the second is a
# claim about the theorem. Folding them together manufactures reassurance.
#
# WHY THESE MUTATIONS. Each re-creates a matcher defect that this repo has
# actually shipped or nearly shipped:
#
#   M01  every character is a boundary      -- the collapse back to substring
#                                              matching, which is the defect the
#                                              whole 0.7.0 routing fix removes
#   M02  the boundary condition is dropped  -- a stem fires anywhere in a word
#   M03  the word branch reverts to infix   -- the SHIPPED 0.6.x behaviour,
#                                              restored exactly
#   M04  the punctuation carve-out dies     -- `.lean` stops matching Basic.lean
#   M05  the punctuation carve-out swallows -- EVERY stem takes the infix path,
#        the word branch                       so the carve-out becomes the rule
#   M06  `any` becomes `all`                -- a stem list stops being a
#                                              disjunction
#   M07  the empty stem fires               -- an empty list entry becomes a
#                                              wildcard matching every prompt
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutstem.XXXXXX")"
MODULES="RotStem"

# --- NO-DOWNLOAD GUARD ------------------------------------------------------
# `lake build` RESOLVES the package first, and against the vendored `lean/` tree
# that resolution starts fetching mathlib INTO the repository. A workspace that
# was never built cannot satisfy this suite, so it SKIPS rather than builds.
# Exit 3 is a skip everywhere in this repo, and a skip is never a pass.
_WSDIR="${LEAN_ROOT:-.}"
for m in $MODULES; do
  [ -f "Proofs/$m.lean" ] || {
    echo "FATAL: Proofs/$m.lean not found. Refusing to run: every mutant would"
    echo "fail to build and be scored KILLED without a line having been mutated."
    exit 2
  }
done
if [ ! -d "$_WSDIR/.lake/packages" ] || [ ! -f "$_WSDIR/.lake/build/lib/lean/Proofs/RotStem.olean" ]; then
  echo "SKIP: $_WSDIR is not a BUILT Lean workspace."
  echo "      Refusing to invoke lake: resolving mathlib would DOWNLOAD gigabytes."
  echo "      Set LEAN_ROOT to an already-built workspace to run this suite."
  echo "      This is a SKIP (exit 3), never a pass."
  exit 3
fi

for m in $MODULES; do
  if ! ( cd "$_WSDIR" && lake build "Proofs.$m" ) >"$LOG/pre_$m.log" 2>&1; then
    echo "FATAL: the UNMUTATED baseline does not build (Proofs.$m)."
    echo "A kill measured against a red baseline is unattributable. Fix the tree first."
    tail -5 "$LOG/pre_$m.log"
    exit 2
  fi
done
echo "preflight: the baseline builds GREEN -- kills are attributable"

# --- SOURCE SANITY: a green baseline is NOT proof the source is intact -------
# An EMPTY Lean file builds green. "The baseline compiles" is therefore a weaker
# statement than it looks, and a truncated source copied over the backup would
# score the whole suite as DISCARDED while destroying the file. Content is
# checked before anything is copied.
for m in $MODULES; do
  _lines=$(wc -l < "Proofs/$m.lean" 2>/dev/null || echo 0)
  _thms=$(grep -c "^theorem \|^example " "Proofs/$m.lean" 2>/dev/null || echo 0)
  if [ "${_lines:-0}" -lt 20 ] || [ "${_thms:-0}" -lt 1 ]; then
    echo "FATAL: Proofs/$m.lean looks DAMAGED ($_lines lines, $_thms theorems)."
    echo "Refusing to overwrite its backup. Restore it before running this suite."
    exit 2
  fi
  cp "Proofs/$m.lean" "Proofs/$m.lean.mutbak"
done
trap 'for m in '"$MODULES"'; do cp "Proofs/$m.lean.mutbak" "Proofs/$m.lean" 2>/dev/null; rm -f "Proofs/$m.lean.mutbak"; done' EXIT

killed=0; survived=0; discarded=0

run_mut() {
  local id="$1" mod="$2" needle="$3" repl="$4" expect="$5"
  local F="Proofs/$mod.lean" BAK="Proofs/$mod.lean.mutbak"
  local OLEAN="$_WSDIR/.lake/build/lib/lean/Proofs/$mod.olean"
  cp "$BAK" "$F"

  local n
  n=$(grep -F -c -- "$needle" "$BAK")
  if [ "$n" -ne 1 ]; then
    echo "$id  DISCARDED  needle occurs $n times (expected 1) -- patch not applied"
    discarded=$((discarded+1)); return
  fi

  awk -v needle="$needle" -v repl="$repl" '{
    p = index($0, needle)
    if (p > 0) { $0 = substr($0,1,p-1) repl substr($0, p+length(needle)) }
    print
  }' "$BAK" > "$F"

  local after_needle after_repl
  after_needle=$(grep -F -c -- "$needle" "$F")
  after_repl=$(grep -F -c -- "$repl" "$F")
  if [ "$after_needle" -ne 0 ] || [ "$after_repl" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed (needle=$after_needle repl=$after_repl)"
    discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi

  # Lake is incremental and will happily not rebuild a module it believes is
  # unchanged. Deleting the artifact removes the doubt.
  rm -f "$OLEAN"
  ( cd "$_WSDIR" && lake build "Proofs.$mod" ) > "$LOG/$id.log" 2>&1
  local ec=$?

  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   (build still exit 0)  expected to kill: $expect"
    survived=$((survived+1))
  else
    local dead
    dead=$(grep -oE "^error: Proofs/$mod\.lean:[0-9]+" "$LOG/$id.log" \
      | grep -oE "[0-9]+$" | sort -un | while read -r ln; do
        awk -v L="$ln" '
          /^(theorem|def|noncomputable def|private def|instance|structure|inductive|example)/ {
            if (NR <= L) { name=$0 }
          }
          END { if (name != "") print name }
        ' "$F"
      done | sed -E 's/^(private |noncomputable )?(theorem|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' \
      | sort -u | tr '\n' ',')
    # The reported error lines are a LOWER BOUND on what died, not an inventory:
    # a mutant build produces no olean, so every theorem in the module is
    # unusable downstream regardless of which line the elaborator complained at.
    if [ ! -f "$OLEAN" ]; then
      echo "$id  KILLED     exit=$ec  MODULE DEAD (no olean: every theorem unusable)"
      echo "        errors at: ${dead%,}  <- LOWER BOUND, not the full set"
      echo "        expected: $expect"
    else
      echo "$id  KILLED     exit=$ec  dead: ${dead%,}"
    fi
    killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

echo "=== RotStem mutation suite (the word-prefix matcher) ==="

# M01 -- EVERY CHARACTER IS A BOUNDARY. `isWordChar` stops recognising letters
# and digits, so `!prev` holds at every position and the matcher collapses back
# to plain substring containment. This is the 0.6.x defect restated in one line.
run_mut M01 RotStem \
  'def isWordChar (c : Char) : Bool := c.isAlphanum' \
  'def isWordChar (_c : Char) : Bool := false' \
  'the improve/prove examples and firesWord_strictly_weaker'

# M02 -- THE BOUNDARY CONDITION IS DROPPED from the recursive case, so a stem
# fires wherever it occurs, mid-word included.
run_mut M02 RotStem \
  '  | prev, c :: rest => (!prev && s.isPrefixOf (c :: rest)) || wordStart s (isWordChar c) rest' \
  '  | prev, c :: rest => s.isPrefixOf (c :: rest) || wordStart s (isWordChar c) rest' \
  'the collision examples: improve/dilemma/cleaning must not fire'

# M03 -- THE WORD BRANCH REVERTS TO INFIX. This is exactly what the shipped
# router did before 0.7.0, so if the module survives it, nothing in this file
# was ever about the change.
run_mut M03 RotStem \
  '  | c :: _ => if isWordChar c then wordStart s false p else decide (s <:+: p)' \
  '  | c :: _ => if isWordChar c then decide (s <:+: p) else decide (s <:+: p)' \
  'firesWord_strictly_weaker -- the two matchers would be equal again'

# M04 -- THE PUNCTUATION CARVE-OUT DIES. A stem starting with punctuation stops
# matching anything, so `.lean` no longer finds Basic.lean -- the regression the
# carve-out exists to prevent.
run_mut M04 RotStem \
  'if isWordChar c then wordStart s false p else decide (s <:+: p)' \
  'if isWordChar c then wordStart s false p else false' \
  'the .lean example -- a punctuation-led stem must still match'

# M05 -- THE CARVE-OUT SWALLOWS THE WORD BRANCH: the condition is inverted, so
# ordinary stems take the infix path and punctuation-led ones take the word path.
# Both halves of the matcher are wrong at once.
run_mut M05 RotStem \
  '  | c :: _ => if isWordChar c then' \
  '  | c :: _ => if !(isWordChar c) then' \
  'every routing example at once'

# M06 -- A STEM LIST STOPS BEING A DISJUNCTION. `any` -> `all` means a prompt
# must contain EVERY stem of a class to route there.
run_mut M06 RotStem \
  '  stems.any (fun s => firesWord1 p s)' \
  '  stems.all (fun s => firesWord1 p s)' \
  'the routing examples, and firesWord_imp_fires loses its meaning'

# M07 -- THE EMPTY STEM BECOMES A WILDCARD. `firesWord1` returns false for the
# empty stem precisely so an empty entry in a word list cannot match everything.
# Making it true is a one-character edit with a repo-wide blast radius.
run_mut M07 RotStem \
  '  | [] => false' \
  '  | [] => true' \
  'the not-fires examples -- an empty stem must never match'

# --- RESTORE AND REBUILD, and this is not a formality --------------------------
# Measured 2026-08-04 on the sibling suite: restoring the SOURCE and stopping
# there leaves the module compiled OUT of the tree, because every mutant deletes
# the .olean. The source was perfect and `git status` was clean, so nothing
# looked wrong -- and then checker/axiom-audit.sh failed with "the axiom probe
# did not elaborate" and axiom-class.sh reported theorems unaccounted for. Both
# were true statements about a tree this kind of harness had quietly emptied.
echo
echo "-- restoring the baseline and REBUILDING it --"
rebuild_fail=0
for m in $MODULES; do
  cp "Proofs/$m.lean.mutbak" "Proofs/$m.lean"
done
for m in $MODULES; do
  if ( cd "$_WSDIR" && lake build "Proofs.$m" ) >"$LOG/post_$m.log" 2>&1; then
    if [ -f "$_WSDIR/.lake/build/lib/lean/Proofs/$m.olean" ]; then
      echo "  $m: restored, rebuilt GREEN, olean present"
    else
      echo "  $m: FAIL -- build reported success but no olean was produced"
      rebuild_fail=1
    fi
  else
    echo "  $m: FAIL -- the RESTORED baseline does not build"
    tail -3 "$LOG/post_$m.log"
    rebuild_fail=1
  fi
done

echo
echo "=== RESULT ==="
echo "killed: $killed   survived: $survived   discarded: $discarded"
echo
echo "A SURVIVED mutant is a claim about a theorem: it did not constrain what it"
echo "appeared to. A DISCARDED mutant is a claim about THIS FILE: the patch never"
echo "landed and nothing was tested. They are reported apart because folding them"
echo "together is how a mutation suite lies in the reassuring direction."
echo

if [ "$rebuild_fail" -ne 0 ]; then
  echo "REFUSING to report success: the baseline was not restored to a GREEN,"
  echo "BUILT state. Every later gate would inherit a tree this suite emptied."
  exit 1
fi
if [ "$discarded" -gt 0 ]; then
  echo "$discarded mutant(s) DISCARDED -- the harness failed to apply them."
  exit 1
fi
if [ "$survived" -gt 0 ]; then
  echo "$survived mutant(s) SURVIVED -- those theorems do not constrain the model."
  exit 1
fi
echo "all $killed mutants killed, none discarded."
exit 0
