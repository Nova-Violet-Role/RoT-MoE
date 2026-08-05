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
# GIT-IGNORED FILES ARE NOT PART OF THE PACKET, and this check is about the
# PACKET. The sweep walks the filesystem, so it also read files that git will
# never publish -- and on 2026-08-05 it went red for `TASKS/`, a directory that
# had just been gitignored precisely so it would stay local. A machine-local
# path in a file that cannot be pushed is not a leak; failing on it trains the
# reader to add allowlist markers to a file nobody will ever receive, which is
# how an allowlist starts growing for no reason at all.
#
# The narrowing is exactly "git will not publish this", asked of git rather than
# guessed from a name, and the control below proves the sweep still catches a
# TRACKED file. A leak in anything committed is still a hard failure.
# CONTROL FOR THE NARROWING ITSELF, run every time. Two plants, opposite
# expectations, both inside the real repository so the real `git check-ignore` is
# what answers. Without this, "skip ignored files" is a claim with nothing behind
# it -- and a filter that silently started skipping EVERYTHING would look exactly
# like a clean tree.
#
# THE PLANTS ARE ONLY MADE WHERE THEY CAN BE JUDGED. Measured 2026-08-05 by
# running this file from the INSTALLED plugin copy, which is not a git checkout:
# the plants were written, git was unavailable, so the branch that reads their
# verdict never ran -- and the sweep dutifully reported ITS OWN CONTROL FILES as
# machine-local paths in the packet. A checker that fails on evidence it planted
# itself is worse than one with no controls: it is loud, wrong, and teaches the
# reader to ignore it.
#
# So the decision of whether git can answer is made FIRST, and nothing is
# written unless it can.
_GITOK=0
if command -v git >/dev/null 2>&1 && ( cd "$ROOT" && git rev-parse --git-dir >/dev/null 2>&1 ); then
  _GITOK=1
fi
_ctl_keep="$ROOT/.rotmoe-nolocal-control.txt"     # untracked, NOT ignored -> kept
_ctl_skip="$ROOT/TASKS/.rotmoe-nolocal-control.txt" # inside an ignored dir -> skipped
if [ "$_GITOK" -eq 1 ]; then
  printf 'control D:%s\n' '\\' > "$_ctl_keep"
  [ -d "$ROOT/TASKS" ] && printf 'control D:%s\n' '\\' > "$_ctl_skip"
fi
# THE TWO PATHS ARE REMOVED BY NAME, NOT FROM A SPACE-JOINED LIST. The first
# version accumulated them into one string and looped over it unquoted; this
# checkout lives at `C:/GIT External Repo/RoT MoE`, so word splitting tore both
# paths into fragments and `rm -f` deleted nothing. The control files survived
# the run -- measured, two files left behind. Same spaces-in-path hazard
# `checker/repo-complete.sh` documents at its `git ls-files -z` call.
_ctl_cleanup () { rm -f "$_ctl_keep" "$_ctl_skip"; }
trap '_ctl_cleanup' EXIT

echo "sweeping: $ROOT"
raw_all=$(grep -rIn -F -f "$PAT" \
        --exclude-dir=.git \
        --exclude-dir=.lake \
        --exclude="patterns-forbidden.txt" \
        --exclude="no-local-paths.sh" \
        "$ROOT" 2>/dev/null)

# Drop hits whose file git ignores. `git check-ignore -q` answers 0 for ignored.
# If git is unavailable the sweep keeps every hit -- the strict behaviour -- so a
# missing tool can never quietly widen what is allowed through.
if [ "$_GITOK" -eq 1 ]; then
  raw=""
  _skipped=0
  while IFS= read -r _line; do
    [ -z "$_line" ] && continue
    _file="${_line%%:*}"
    if git check-ignore -q "$_file" 2>/dev/null; then
      _skipped=$((_skipped+1))
    else
      raw="$raw$_line
"
    fi
  done <<EOF
$raw_all
EOF
  [ "$_skipped" -gt 0 ] && echo "skipped $_skipped hit(s) in git-ignored files (never published)"

  # Now read the verdict on the two plants.
  if printf '%s' "$raw" | grep -qF '.rotmoe-nolocal-control.txt'; then
    _kept_ok=1
  else
    _kept_ok=0
  fi
  if [ -d "$ROOT/TASKS" ] && printf '%s' "$raw" | grep -F '.rotmoe-nolocal-control.txt' | grep -qF 'TASKS'; then
    _skip_ok=0
  else
    _skip_ok=1
  fi
  if [ "$_kept_ok" -ne 1 ]; then
    echo "FAIL: CONTROL -- a NON-ignored file carrying a machine-local path was not seen."
    echo "The sweep has stopped catching the thing it exists for. Refusing to report clean."
    _ctl_cleanup; exit 2
  fi
  if [ "$_skip_ok" -ne 1 ]; then
    echo "FAIL: CONTROL -- a file inside a git-ignored directory was still reported."
    echo "The narrowing is not doing what its comment says."
    _ctl_cleanup; exit 2
  fi
  echo "control OK: an unignored plant IS caught, an ignored plant is NOT"
  # Remove the control hits so they cannot be mistaken for findings.
  raw=$(printf '%s' "$raw" | grep -vF '.rotmoe-nolocal-control.txt')
  _ctl_cleanup
else
  raw="$raw_all"
  echo "git unavailable -- keeping every hit, including files git might ignore"
fi

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
