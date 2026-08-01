#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# CROSS-DIFF, ORGAN 4 -- the two reminder arms must agree BYTE FOR BYTE.
#
# `checker/cross-diff.sh` does this for the router. This is the same instrument
# aimed at `hooks/prover-remind.sh` and `hooks/prover-remind.ps1`, and it exists
# for the same reason: a router that only fires on one operating system is a
# router for one machine, and so is a reminder.
#
# WHY --decide AND NOT THE HOOK PATH. The hook path measures the filesystem and
# git, so its output depends on the machine it runs on -- untestable as an
# equality. `--decide` takes the measurements as ARGUMENTS and reads nothing, so
# the DECISION (the part that can silently diverge between two languages) is
# comparable exactly. What --decide does not cover -- that both arms measure the
# same things off disk -- is stated in the README boundary rather than implied
# by this green.
#
# THE COMPARISON IS ON STRINGS, not on "did both produce something". A one-
# character difference in a label is a real divergence: it is what a user reads.
#
# NON-VACUITY IS ASSERTED, not assumed. The corpus must contain at least one row
# that speaks and one row that is SILENT. Without both, an arm that always
# printed -- or never did -- would pass a hundred rows of "they agree".
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

SH="hooks/prover-remind.sh"
PS1="hooks/prover-remind.ps1"
CORPUS="checker/corpus-remind.txt"

pass=0; fail=0; skip=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }

echo "== cross-diff: the two reminder arms =="

[ -f "$SH" ]  || { bad "missing $SH";  echo "  cross-diff-remind: FAIL"; exit 1; }
[ -f "$PS1" ] || { bad "missing $PS1"; echo "  cross-diff-remind: FAIL"; exit 1; }
[ -f "$CORPUS" ] || { bad "missing $CORPUS"; echo "  cross-diff-remind: FAIL"; exit 1; }

PWSH=""
for c in pwsh powershell; do command -v "$c" >/dev/null 2>&1 && { PWSH="$c"; break; }; done
if [ -z "$PWSH" ]; then
  echo "  SKIP  no PowerShell on this runner -- the arms were NOT compared."
  echo "        This is a SKIP, never a PASS: an unrun comparison proves nothing."
  skip=1
fi

spoke=0; silent=0; rows=0
while read -r ev mins last debt kred ksorry alarms; do
  case "$ev" in ''|\#*) continue ;; esac
  rows=$((rows+1))
  a=$(sh "$SH" --decide "$ev" "$mins" "$last" "$debt" "$kred" "$ksorry" "$alarms" 2>/dev/null)
  arc=$?
  if [ "$arc" -ne 0 ]; then
    bad "row $rows: the POSIX arm exited $arc (it must never fail): $ev $mins $last $debt $kred $ksorry $alarms"
    continue
  fi
  if [ -n "$a" ]; then spoke=$((spoke+1)); else silent=$((silent+1)); fi

  if [ -n "$PWSH" ]; then
    b=$("$PWSH" -NoProfile -File "$PS1" -Decide "$ev" "$mins" "$last" "$debt" "$kred" "$ksorry" "$alarms" 2>/dev/null)
    brc=$?
    if [ "$brc" -ne 0 ]; then
      bad "row $rows: the Windows arm exited $brc: $ev $mins $last $debt $kred $ksorry $alarms"
      continue
    fi
    if [ "$a" = "$b" ]; then
      ok "row $rows agrees ($ev mins=$mins debt=$debt kred=$kred): $( [ -n "$a" ] && echo "speaks ${#a} chars" || echo 'SILENT' )"
    else
      bad "row $rows DISAGREES: $ev $mins $last $debt $kred $ksorry $alarms"
      echo "        sh : $a"
      echo "        ps1: $b"
    fi
  fi
done < "$CORPUS"

echo
echo "-- non-vacuity of the corpus --"
[ "$rows" -gt 0 ] && ok "corpus has $rows row(s)" || bad "corpus is EMPTY -- every comparison below is vacuous"
[ "$spoke" -gt 0 ] && ok "$spoke row(s) produce a reminder" \
  || bad "NO row produces output -- an arm that never speaks would pass this suite"
[ "$silent" -gt 0 ] && ok "$silent row(s) are SILENT (the healthy state is exercised)" \
  || bad "NO row is silent -- an arm that always speaks would pass this suite"

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed, $skip skipped"
if [ "$fail" -eq 0 ] && [ "$skip" -eq 0 ]; then
  echo "  cross-diff-remind: PASS"; exit 0
elif [ "$fail" -eq 0 ]; then
  echo "  cross-diff-remind: PASS (POSIX arm only; the comparison did not run)"; exit 0
else
  echo "  cross-diff-remind: FAIL"; exit 1
fi
