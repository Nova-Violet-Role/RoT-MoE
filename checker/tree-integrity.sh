#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# tree-integrity.sh -- no tracked file is EMPTY on disk while git holds content.
#
# WHY THIS EXISTS. Three times now a mutation harness has been interrupted and
# left shipped hooks at ZERO BYTES:
#
#   2026-08-05  a bounded gate-all sweep ORPHANED checker/mutate-checker.sh
#               rather than signalling it; the EXIT/INT/TERM trap never fired
#               and three hooks were left empty with no .mutbak beside them.
#   2026-08-07  a SIGKILL inside a plain `cp` truncated the destination before
#               it was rewritten. Fixed by making the swap atomic.
#   2026-08-10  `timeout 240` (SIGTERM) around mutate-checker.sh left
#               hooks/prover-remind.sh (32209 bytes in git) and
#               hooks/prover-remind.ps1 (28315 bytes) both at ZERO on disk.
#
# The 2026-08-07 atomicity fix is real and it is not enough, because the danger
# is not only a half-written file. `restore()` and the EXIT trap both do
# `cat "$f.mutbak" > "$f.rtmp" && mv -f "$f.rtmp" "$f"`, guarded by `[ -f ... ]`
# -- EXISTENCE, not content. An empty or half-written backup therefore restores
# EMPTINESS over the original, atomically and with a successful exit code.
#
# WHY NO OTHER GATE CATCHES IT. mutate-checker.sh's own header says it: this is
# "the one state gate-all's leftover-backup refusal cannot see", and "two fast
# sweeps stayed green afterwards: every fast gate reads source TEXT, and an
# empty file has no offending text in it." Emptying a file is itself one of that
# harness's mutants -- so the tree carries a LIVE MUTANT with the evidence
# deleted.
#
# On 2026-08-10 exactly one gate went red: checker/portability.sh, and it
# reported "the alarm warning is MISSING under CRLF -- the exact CI defect is
# back". That diagnosis is WRONG. Nothing was wrong with CRLF handling; the hook
# it invokes was a zero-byte file, so it printed nothing and every content
# assertion downstream failed. A wrong diagnosis is worse than a silent gate: it
# sends the next person to re-fix a CRLF bug that is not there. This checker
# exists to make the true cause the FIRST thing anyone reads.
#
# It is deliberately cheap -- `git ls-files` plus a stat per file -- so it can
# sit in the fast tier and run on every commit.
#
# EXITS  0 pass | 1 a tracked file is empty on disk | 2 usage/tooling

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

pass=0; fail=0
ok  () { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
bad () { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }

echo "== tree integrity: emptiness is a mutant, not an absence of content =="

# -----------------------------------------------------------------------------
# 1. THE CHECK. A tracked file that git believes has content must have content.
#
# Comparing against HEAD rather than a hardcoded list is deliberate: a list of
# "important files" stops covering whatever is added after it is written, which
# is the stale-snapshot defect this repo keeps finding in its own instruments.
empties=""
n_checked=0
while IFS= read -r f; do
  [ -f "$f" ] || continue          # deleted-in-worktree is a different question
  n_checked=$((n_checked+1))
  [ -s "$f" ] && continue
  # Empty on disk. Is it empty in git too? A legitimately empty tracked file is
  # fine and must NOT be reported -- only a file git says has content.
  blob="$(git rev-parse "HEAD:$f" 2>/dev/null)" || continue
  sz="$(git cat-file -s "$blob" 2>/dev/null)" || continue
  [ "${sz:-0}" -gt 0 ] && empties="$empties$f ($sz bytes in git)"$'\n'
done < <(git ls-files)

if [ -z "$empties" ]; then
  ok "no tracked file is empty on disk while git holds content ($n_checked checked)"
else
  bad "TRACKED FILES ARE EMPTY ON DISK -- git has content for them:"
  printf '%s' "$empties" | while IFS= read -r line; do
    [ -n "$line" ] && printf '        %s\n' "$line"
  done
  echo "        This is the mutate-checker interruption signature. It is a LIVE"
  echo "        MUTANT with the evidence deleted, and text-reading gates cannot"
  echo "        see it. Recover with:"
  echo "            git checkout HEAD -- <path>"
  echo "        Do NOT re-run the mutation harness first: if a .mutbak is stale"
  echo "        it will restore the emptiness again."
fi

# -----------------------------------------------------------------------------
# 2. NO MUTATION BACKUP MAY SURVIVE A FINISHED RUN. A leftover .mutbak means a
# harness did not complete, so the tree may still carry a live mutant.
leftovers="$(find . -name '*.mutbak' -o -name '*.rtmp' -o -name '*.mtmp' -o -name '*.mtmp.raw' 2>/dev/null \
             | grep -v '/\.lake/' || true)"
if [ -z "$leftovers" ]; then
  ok "no .mutbak/.rtmp/.mtmp leftovers -- no harness died mid-run"
else
  bad "mutation leftovers on disk -- a harness did not finish:"
  printf '%s\n' "$leftovers" | sed 's/^/        /'
fi

# -----------------------------------------------------------------------------
# 3. CONTROLS. Both directions, in a scratch git repo so nothing here can touch
# the real tree. An alarm nobody has tripped on purpose is an untested alarm.
CTL="$(mktemp -d "${TMPDIR:-/tmp}/rot-treeint.XXXXXX")" || exit 2
trap 'rm -rf "$CTL"' EXIT

(
  cd "$CTL" || exit 2
  git init -q . 2>/dev/null
  git config user.email t@t; git config user.name t
  printf 'real content\n' > kept.sh
  : > legitimately-empty.txt
  git add -A >/dev/null 2>&1
  git commit -q -m base >/dev/null 2>&1
) || { echo "  FAIL  CONTROL: could not build the scratch repo"; exit 2; }

probe () {  # <dir> -> 0 if clean, 1 if an empty tracked file was found
  ( cd "$1" || exit 2
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      [ -s "$f" ] && continue
      blob="$(git rev-parse "HEAD:$f" 2>/dev/null)" || continue
      sz="$(git cat-file -s "$blob" 2>/dev/null)" || continue
      [ "${sz:-0}" -gt 0 ] && exit 1
    done < <(git ls-files)
    exit 0 )
}

if probe "$CTL"; then
  ok "CONTROL: a clean tree is not flagged (and an empty file that is ALSO empty in git is allowed)"
else
  bad "CONTROL: a clean tree was flagged -- the check is too strict"
fi

: > "$CTL/kept.sh"          # the exact incident: truncate a file git has content for
if probe "$CTL"; then
  bad "CONTROL: a TRUNCATED tracked file was NOT detected -- this check is decoration"
else
  ok "CONTROL: a truncated tracked file IS detected (the 2026-08-10 signature)"
fi

echo
echo "== tree-integrity: $pass passed, $fail failed"
if [ "$fail" -eq 0 ]; then echo "  tree-integrity: PASS"; exit 0; fi
echo "  tree-integrity: FAIL"; exit 1
