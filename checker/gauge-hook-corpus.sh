#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# THE HOOK ARM OF THE GAUGE CROSS-CHECK -- runs anywhere, skips never.
#
# WHY THIS EXISTS. `checker/gauge-cross.sh` compares the Lean Float mirror
# against the running hook, and needs a built Lean workspace. In the `checkers`
# job there is none, so that step could only ever print
#
#     SKIPPED: no built Lean workspace -- NOT a pass
#
# and exit 0 -- on ubuntu, macos AND windows, on every run. The label was honest
# and the step was still a hole: it had no reachable PASS. A step that cannot
# pass cannot fail either, and an instrument that cannot fail is decoration.
#
# The repair is NOT to delete it. The two arms differ in what they depend on:
#
#   * the LEAN arm is platform-independent -- the same .olean, the same Float,
#     the same value on every runner. Running it three times measures nothing
#     new, and costs a mathlib toolchain on each platform to say so.
#   * the HOOK arm is emphatically NOT. It is awk arithmetic in a POSIX shell,
#     and this repository has already been bitten by a DECIMAL COMMA locale
#     turning 0.49 into 0,49. That is exactly a per-platform risk.
#
# So the Lean arm stays in the lean job (where a skip is a hard failure), and
# this runs the hook against `checker/gauge-corpus.tsv` everywhere else.
#
# THE CORPUS IS NOT A SNAPSHOT. `gauge-cross.sh` re-derives every expected value
# from Lean in the lean job and FAILS if the file disagrees, so this cannot
# quietly freeze a wrong number: to change a value here you must change the
# model, and the lean job is what says you did.
#
# Exit 0 = every row matched. Exit 1 = a row disagreed, or the control died.
# There is no exit 3. This checker has no reason to skip and is not allowed one.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO" || exit 1

CORPUS_FILE="$REPO/checker/gauge-corpus.tsv"
pass=0; fail=0
ok ()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad () { echo "  FAIL  $*"; fail=$((fail+1)); }

echo "== gauge hook corpus: the RUNNING hook vs the Lean-verified expectations =="
echo "   platform: $(uname -s 2>/dev/null || echo unknown)   shell: ${BASH_VERSION:-posix}"
echo

if [ ! -f "$CORPUS_FILE" ]; then
  echo "  FAIL  the corpus is missing: $CORPUS_FILE"
  echo "        This is a FAILURE, not a skip: the file is committed, so its"
  echo "        absence means the packet is incomplete."
  exit 1
fi

# The hook arm. `sh`, not bash, because that is how the router is invoked.
hook_gauge () {   # hook_gauge <vec> <breadth> <M> <C> <T> -> "0.49"
  sh hooks/rot-router.sh --vector "$1" --breadth "$2" --M "$3" --C "$4" --T "$5" 2>/dev/null \
    | grep -oE 'R/s\+ = [0-9]+[.,][0-9]+' | grep -oE '[0-9]+[.,][0-9]+'
}

# Rows, comments stripped. Not `mapfile`: bash 4.0+ only, and macOS ships
# bash 3.2.57 as /bin/bash -- the same reason gauge-cross.sh avoids it.
rows=0
while IFS=$'\t' read -r vec br M C T want; do
  case "$vec" in ''|\#*) continue ;; esac
  rows=$((rows+1))
  got="$(hook_gauge "$vec" "$br" "$M" "$C" "$T")"
  if [ -z "$got" ]; then
    bad "row $rows: the HOOK produced no R/s+ at all for [$vec] b=$br"
  elif [ "$got" = "$want" ]; then
    ok "row $rows: hook $got == corpus $want   [$vec] b=$br M=$M C=$C T=$T"
  else
    # A decimal comma is a REAL failure mode here, not a formatting quibble:
    # the hook's own consumers parse this number. Name it when it is what
    # happened, so the next reader is not left guessing at a digit mismatch.
    case "$got" in
      *,*) bad "row $rows: hook produced '$got' -- DECIMAL COMMA. The locale is leaking into the gauge; expected $want" ;;
      *)   bad "row $rows: hook $got != corpus $want   [$vec] b=$br M=$M C=$C T=$T -- the router and the Lean-verified value DISAGREE" ;;
    esac
  fi
done < "$CORPUS_FILE"

if [ "$rows" -eq 0 ]; then
  bad "the corpus produced NO rows -- an empty corpus makes this checker vacuous"
else
  ok "every corpus row was executed against the hook ($rows rows)"
fi

# --- the controls -----------------------------------------------------------
# Two, because they answer different questions.
echo
echo "-- negative controls --"

# 1. The comparison can FAIL. Feed the hook row 1's inputs and compare against
#    row 2's expectation: two rows chosen because their values differ, so a
#    comparator that always agrees is exposed.
c_got="$(hook_gauge 0,0,0,0,0,0,0,0,0 0 1.05 0.7 0.8)"
c_want="$(awk -F'\t' '$1 !~ /^#/ && NF >= 6 { n++; if (n == 2) { print $6; exit } }' "$CORPUS_FILE")"
if [ -n "$c_got" ] && [ -n "$c_want" ] && [ "$c_got" != "$c_want" ]; then
  ok "CONTROL: a wrong expectation IS detected (hook $c_got vs $c_want from another row)"
else
  bad "CONTROL DEAD: rows that must differ compared equal ($c_got vs $c_want) -- this checker cannot detect drift"
fi

# 2. The hook is genuinely being executed. If `hooks/rot-router.sh` were absent
#    or silent, every row would fail with an empty value -- but a corpus that
#    somehow matched empty against empty would look green. Assert the hook
#    emits a gauge for an input NOT in the corpus, so the pass cannot come from
#    the corpus file alone.
live="$(hook_gauge 1,1,0,0,0,0,0,0,0 1 1.05 0.7 0.8)"
if [ -n "$live" ]; then
  ok "CONTROL: the hook really ran (off-corpus input produced $live)"
else
  bad "CONTROL DEAD: the hook produced nothing for an off-corpus input -- these PASSes came from somewhere else"
fi

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
echo "  NOTE  this is the HOOK arm. Lean-vs-hook agreement is gauge-cross.sh in"
echo "        the lean job; this checks the running hook against what Lean said,"
echo "        on a platform Lean is not installed on."
[ "$fail" -eq 0 ] && { echo "  gauge-hook-corpus: PASS"; exit 0; } || { echo "  gauge-hook-corpus: FAIL"; exit 1; }
