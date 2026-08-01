#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# R2 -- no machine-local path ships.
#
# ---------------------------------------------------------------------------
# WHY THIS IS grep -F -f AND NOT ONE -E ALTERNATION.
#
# The first version of this sweep was a single ERE alternation and it produced
# a FALSE GREEN: it reported a clean tree while fourteen occurrences of
# `/d/Lean/proofs` sat in the shipped mutation scripts. Measured cause:
#
#     grep -rInE '/d/Lean'         -> 14 hits
#     grep -rInE 'ZZZ|/d/Lean'     -> 14 hits
#     grep -rInE 'D:\|/d/Lean'     ->  0 hits
#
# In ERE, `\|` is an ESCAPED PIPE -- a literal `|`, not alternation. Because a
# forbidden pattern legitimately ends in a backslash (`D:\`), the escape ran
# into the separator and collapsed the whole expression into one literal string
# that matches nothing. The check passed by matching nothing at all.
#
# So: fixed strings, one per line, in a data file. `-F` means no metacharacter
# has any meaning, which removes the entire class of bug rather than fixing one
# instance of it. A pattern list is data; an escaped alternation is a program,
# and this one had a bug that failed SILENTLY and in the reassuring direction.
#
# THE INSTRUMENT IS GUILTY UNTIL PROVEN ABLE TO FAIL. This script therefore
# runs a POSITIVE control (a planted needle MUST be found) before it will
# report a clean tree at all. That is the check the original sweep lacked --
# it never asked whether it could still see anything.
# ---------------------------------------------------------------------------

set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PAT="$(dirname "$0")/patterns-forbidden.txt"
TMP="${TMPDIR:-/tmp}/rotmoe-r2.$$"
rc=0

[ -f "$PAT" ] || { echo "FAIL: pattern file missing: $PAT"; exit 2; }

# --- POSITIVE CONTROL --------------------------------------------------------
# Plant a file containing the first forbidden pattern. If the sweep does not
# find it, the sweep is blind and every clean result it has ever produced is
# worthless. This runs FIRST and its failure is fatal.
mkdir -p "$TMP"
first_pat=$(head -1 "$PAT")
printf '%s\n' "$first_pat" > "$TMP/planted.txt"
if grep -rIF -f "$PAT" "$TMP" >/dev/null 2>&1; then
  echo "control OK: planted '$first_pat' was detected"
else
  echo "FAIL: positive control missed a planted forbidden pattern -- THE SWEEP IS BLIND"
  rm -rf "$TMP"; exit 2
fi

# --- NEGATIVE CONTROL --------------------------------------------------------
# A file of innocuous text must NOT trip the sweep, or it flags everything and
# a green result would be unobtainable rather than meaningful.
printf 'hooks fire on UserPromptSubmit and PreToolUse\n' > "$TMP/innocent.txt"
rm -f "$TMP/planted.txt"
if grep -rIF -f "$PAT" "$TMP" >/dev/null 2>&1; then
  echo "FAIL: negative control -- innocuous text matched a forbidden pattern"
  rm -rf "$TMP"; exit 2
else
  echo "control OK: innocuous text did not match"
fi
rm -rf "$TMP"

# --- THE SWEEP ---------------------------------------------------------------
echo "sweeping: $ROOT"
raw=$(grep -rIn -F -f "$PAT" \
        --exclude-dir=.git \
        --exclude-dir=.lake \
        --exclude="patterns-forbidden.txt" \
        --exclude="no-local-paths.sh" \
        "$ROOT" 2>/dev/null)

# --- THE ALLOWLIST, and why it is per-LINE and counted ----------------------
# Documentation legitimately quotes the forbidden patterns: NOTICE.md explains
# that `D:\` ending in a backslash is what broke the first version of this
# sweep, and it cannot explain that without writing it down.
#
# The wrong fix is `--exclude=NOTICE.md` -- that exempts a whole file forever,
# including the machine-local path someone pastes into it next year. The fix
# here is a per-LINE marker: a line is exempt only if it also carries the token
# R2-ALLOW. Narrow, visible in a diff, and impossible to apply by accident.
#
# The number of exemptions is PRINTED on every run. An allowlist that grows
# quietly is how a check dies of a thousand small concessions, so it is made
# loud: if this number is bigger than you expect, that is the finding.
hits=$(printf '%s\n' "$raw" | grep -v 'R2-ALLOW' | grep -v '^$')
allowed=$(printf '%s\n' "$raw" | grep -c 'R2-ALLOW')
echo "allowlisted lines (must carry an explicit R2-ALLOW marker): $allowed"

if [ -n "$hits" ]; then
  echo "FAIL: machine-local paths present in the packet:"
  printf '%s\n' "$hits"
  rc=1
else
  echo "PASS: no machine-local path in the packet"
fi

exit "$rc"
