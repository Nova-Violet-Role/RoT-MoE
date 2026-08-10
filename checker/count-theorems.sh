#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE theorem counter. One definition, used by every consumer.
#
# WHY THIS IS A FILE AND NOT A grep REPEATED IN FOUR PLACES.
#
# The count was a bare `grep -cE '^(theorem|lemma) '` copied into repo-complete,
# verify.yml and ads-manager.yml. It was WRONG, and it was wrong in the
# flattering direction: it counted a `theorem ...` line written inside a `/-! -/`
# DOC COMMENT -- prose illustrating what a vacuous theorem looks like -- and
# reported 73 where the truth was 71.
#
# That is the exact failure this repo keeps hunting, turned on itself: a number
# in the README is supposed to be a MEASUREMENT, and the measuring instrument
# could be inflated by writing English. Three copies of a broken grep would also
# have had to be found and fixed three times.
#
# So: comment-aware, in one place, with a self-test below.
#
# Usage:
#   count-theorems.sh <file>...     -> total across the files
#   count-theorems.sh --per <file>  -> "<name> <count>" per file
#   count-theorems.sh --selftest    -> proves the counter rejects prose
# =============================================================================

set -uo pipefail

# --- REFUSAL ----------------------------------------------------------------
# MEASURED 2026-08-10: this counter COULD NOT FAIL. Three ways to get "0" and
# exit 0 out of it, each indistinguishable from an honest count of zero:
#
#   count-theorems.sh                 -> `for f in "$@"` never iterates  -> 0, exit 0
#   count-theorems.sh nosuch.lean     -> awk fatal, $(...) empty,
#                                        `total=$((total + ))` is a syntax
#                                        error, no `set -e` -> 0, exit 0
#   count-theorems.sh 'Proofs/*.lean' -> unexpanded glob, same path      -> 0, exit 0
#
# `checker/axiom-audit.sh:291` then swallowed even that via `2>/dev/null` and
# `n=${n:-0}`. A ratchet fed by an instrument that reports 0 for "I was given
# nothing" is a fake-green generator: the count can only ever go DOWN silently.
#
# A number is a measurement only if the absence of input is DISTINGUISHABLE from
# a measured zero. Proven in lean/Proofs/RotCounter.lean --
# `zero_is_ambiguous_under_naive` / `honest_separates_them`.
die () { echo "count-theorems: $*" >&2; exit 2; }

count_one () {
  [ -e "$1" ] || die "no such file: $1 (an unexpanded glob or a typo is NOT a count of zero)"
  [ -f "$1" ] || die "not a regular file: $1"
  [ -r "$1" ] || die "not readable: $1"
  local _n
  _n=$(_count_awk "$1") || die "awk failed on: $1"
  case "$_n" in
    ''|*[!0-9]*) die "non-numeric count '$_n' from: $1" ;;
  esac
  printf '%s' "$_n"
}

_count_awk () {
  # Skips /- ... -/ block comments (including /-- and /-! forms) and -- line
  # comments, then counts declarations at the start of a line.
  awk '
    BEGIN { depth = 0; n = 0 }
    {
      line = $0
      # Track block comment nesting across the line, character by character:
      # Lean block comments NEST, so a naive "in a comment?" flag is wrong.
      i = 1
      out = ""
      while (i <= length(line)) {
        two = substr(line, i, 2)
        if (two == "/-") { depth++; i += 2; continue }
        if (two == "-/") { if (depth > 0) depth--; i += 2; continue }
        if (depth == 0) out = out substr(line, i, 1)
        i++
      }
      if (depth_at_line_start == 0 && out ~ /^(@\[[^]]*\] )?(private |protected |noncomputable )*(theorem|lemma)[ (]/) n++
      depth_at_line_start = depth
    }
    END { print n+0 }
  ' "$1"
}

if [ "${1:-}" = "--selftest" ]; then
  # An instrument that has never been seen to fail proves nothing.
  T="$(mktemp -d "${TMPDIR:-/tmp}/cnt.XXXXXX")"
  cat > "$T/a.lean" <<'EOF'
/-!
Prose that MENTIONS a declaration must not be counted:

theorem impressive_sounding_name (h : 0 = 1) : False := by omega
-/
theorem real_one : True := trivial
/-- doc comment
theorem also_not_real : True := trivial
-/
lemma real_two : True := trivial
EOF
  # an honest zero must still be reportable: a real file with no declarations
  printf '/-! only prose here -/\n' > "$T/empty.lean"

  got=$(count_one "$T/a.lean")
  fails=0

  [ "$got" = "2" ] || { echo "selftest FAIL: expected 2, got $got -- prose can inflate the counter"; fails=$((fails+1)); }

  # --- NEGATIVE CONTROLS: each of these used to return 0 and exit 0 ----------
  z=$(bash "$0" "$T/empty.lean"); e=$?
  [ "$e" = "0" ] && [ "$z" = "0" ] || { echo "selftest FAIL: an honest zero must report 0 exit 0 (got '$z' exit $e)"; fails=$((fails+1)); }

  bash "$0" >/dev/null 2>&1; e=$?
  [ "$e" = "2" ] || { echo "selftest FAIL: no arguments must REFUSE (exit 2), got exit $e"; fails=$((fails+1)); }

  bash "$0" "$T/nosuch.lean" >/dev/null 2>&1; e=$?
  [ "$e" = "2" ] || { echo "selftest FAIL: a missing file must REFUSE (exit 2), got exit $e"; fails=$((fails+1)); }

  bash "$0" "$T/*.nomatch" >/dev/null 2>&1; e=$?
  [ "$e" = "2" ] || { echo "selftest FAIL: an unexpanded glob must REFUSE (exit 2), got exit $e"; fails=$((fails+1)); }

  bash "$0" --per >/dev/null 2>&1; e=$?
  [ "$e" = "2" ] || { echo "selftest FAIL: --per with no files must REFUSE (exit 2), got exit $e"; fails=$((fails+1)); }

  rm -rf "$T"
  if [ "$fails" -eq 0 ]; then
    echo "selftest PASS: counts 2 real declarations, ignores 2 written in prose,"
    echo "               reports an honest zero, and REFUSES all four empty-input paths."
    exit 0
  fi
  echo "selftest FAIL: $fails check(s) failed"
  exit 1
fi

if [ "${1:-}" = "--per" ]; then
  shift
  [ "$#" -ge 1 ] || die "--per given no files. Zero files is a refusal, never a report."
  for f in "$@"; do
    c=$(count_one "$f") || exit 2
    printf '%s %s\n' "$(basename "$f" .lean)" "$c"
  done
  exit 0
fi

[ "$#" -ge 1 ] || die "no input files. A count over zero files is not a measurement of zero."

total=0
for f in "$@"; do
  c=$(count_one "$f") || exit 2
  total=$((total + c))
done
echo "$total"
