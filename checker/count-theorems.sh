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

count_one () {
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
  got=$(count_one "$T/a.lean")
  rm -rf "$T"
  if [ "$got" = "2" ]; then
    echo "selftest PASS: counted 2 real declarations, ignored 2 written in prose"
    exit 0
  else
    echo "selftest FAIL: expected 2, got $got -- the counter can be inflated by prose"
    exit 1
  fi
fi

if [ "${1:-}" = "--per" ]; then
  shift
  for f in "$@"; do printf '%s %s\n' "$(basename "$f" .lean)" "$(count_one "$f")"; done
  exit 0
fi

total=0
for f in "$@"; do total=$((total + $(count_one "$f"))); done
echo "$total"
