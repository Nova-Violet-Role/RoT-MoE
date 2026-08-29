#!/bin/sh
# R22 -- Is the newest statement about the FULL-only tier about THIS tree?
#
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# Ten gates live behind `gate-all.sh --full`. No commit triggers them, nothing
# recorded when they last ran, and the instruction to run them before publishing
# was PROSE -- an assertion with no assertor. This gate is the assertor.
#
# The model is proved, not invented: lean/Proofs/RotFreshness.lean.
#   absence_and_green_must_not_agree  -- no receipt must read RED, never silent
#   stale_never_passes                -- a receipt from another tree cannot pass
#   check_sound                       -- every green came from a fresh receipt
#   ignoring_freshness_is_unsound     -- the naive checker greens a red tree
#
# The receipt is written ONLY by a full run that reached the end with no red,
# and only through --stamp with FULL_RUN_COMPLETED=1 in the environment. A
# receipt this gate could hand-write itself would be evidence of nothing.
#
# EXPECTED RED until the first real full run. That red is the finding, not a
# defect in this script: branch 9.0.0 has never had one.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

RECEIPT="$ROOT/.full-run-receipt"
MAX_DRIFT=${FULL_MAX_DRIFT:-25}

# Every verdict below rests on git answering questions about history. If git
# cannot answer at all, `cat-file -e` fails for a reason that has nothing to do
# with the receipt, and the gate would report "unknown-commit" -- a true-looking
# red for the wrong reason, which is worse than a crash. Say so instead.
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "R22 RED: not inside a git work tree -- $ROOT"
  echo "         This gate reasons about commit history; without it every"
  echo "         verdict it could print would be an artefact of the failure."
  exit 1
fi

# --- the one function every verdict comes from -------------------------------
# Production and all four controls call THIS. A control that exercised a
# reimplementation would be testing a copy nobody ships.
#
# Prints: "GREEN drift=<n>" | "RED <reason>"
receipt_verdict () {
  f="$1"; maxd="$2"

  if [ ! -f "$f" ]; then
    echo "RED no-receipt"
    return 0
  fi

  sha=$(sed -n 's/^sha=\([0-9a-f]\{40\}\)$/\1/p' "$f" | head -1)
  if [ -z "$sha" ]; then
    echo "RED malformed-sha"
    return 0
  fi

  if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
    echo "RED unknown-commit"
    return 0
  fi

  if ! git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
    echo "RED not-ancestor"
    return 0
  fi

  drift=$(git rev-list --count "${sha}..HEAD")
  if [ "$drift" -gt "$maxd" ]; then
    echo "RED drift=$drift>$maxd"
    return 0
  fi

  echo "GREEN drift=$drift"
}

# --- --stamp: record that a full run happened --------------------------------
if [ "${1:-}" = "--stamp" ]; then
  if [ "${FULL_RUN_COMPLETED:-0}" != "1" ]; then
    echo "REFUSED: --stamp writes evidence that a full run completed."
    echo "         Set FULL_RUN_COMPLETED=1 only from the tail of a full run"
    echo "         that finished with zero red gates. A receipt written by hand"
    echo "         is an unauthored claim -- exactly what this gate exists to catch."
    exit 1
  fi
  # A receipt names a COMMIT. If the tree was dirty when the full run happened,
  # the run tested a state that no commit records, and the receipt would claim
  # HEAD had been verified when HEAD is not what ran. That is the staleness bug
  # with the sign flipped -- stale in the other direction.
  if [ -n "$(git status --porcelain)" ]; then
    echo "REFUSED: the working tree is dirty."
    echo "         A receipt names a commit. The full run just tested something"
    echo "         no commit contains, so no commit sha honestly describes it."
    echo "         Commit first, then run --full, then stamp."
    exit 1
  fi
  head_sha=$(git rev-parse HEAD)
  {
    echo "# Written by checker/full-freshness.sh --stamp at the end of a green"
    echo "# gate-all.sh --full run. Do not edit by hand; see lean/Proofs/RotFreshness.lean."
    echo "sha=$head_sha"
    echo "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$RECEIPT"
  echo "STAMPED $head_sha"
  exit 0
fi

echo "R22 -- freshness of the FULL-only tier"
echo

fail=0

# --- CONTROLS ----------------------------------------------------------------
# Four, and they must trip in BOTH directions. A gate proved only to go red is
# a gate that might be stuck red; one proved only to go green is not a gate.
CTL_TMP=${TMPDIR:-/tmp}/r22ctl.$$
mkdir -p "$CTL_TMP" || exit 1
# EXIT and INT/TERM DELIBERATELY SEPARATE. Sixth and last instance of one
# mechanism -- release-longsession.sh:134-135, live-session-smoke.sh:445-462,
# hook-footprint.sh:118-136, install-parity.sh:61-83, mutate-harness.sh:60,153.
# A POSIX sh signal handler that does not itself exit RESUMES where the signal
# landed. $CTL_TMP is read at :125 :133 :134 :144 :145 :157 :158.
#
# This file was ONCE CLEARED BY COUNTING and the clearing was wrong, which is
# why the reasoning is written out rather than asserted. The count asked how
# many ok/bad calls follow the trap and got zero -- but this file does not use
# those helpers at all. It scores with `echo "CONTROL n ok"` and `fail=1`, so
# the instrument measured a vocabulary this file never spoke.
#
# Both failure directions are present here, in one section:
#   :124  CONTROL 1 passes a path that is SUPPOSED to be missing and expects
#         "RED no-receipt". With $CTL_TMP gone it still prints ok -- it passes
#         BECAUSE absence is what it asserts, and the handler manufactures
#         absence. A green reached without the instrument existing.
#   :133  CONTROL 2, :144 CONTROL 3 and :157 CONTROL 4 cannot write their
#         fixtures, so all three collapse to "RED no-receipt" and report FAILED
#         -- including CONTROL 4, the one whose whole job is proving this gate
#         is not stuck red.
#   :164  the run then prints "R22 RED: the controls did not behave", charging
#         receipt_verdict with a defect it does not have.
trap 'rm -rf "$CTL_TMP"' EXIT
trap 'rm -rf "$CTL_TMP"; printf "\n  ---- KILLED by signal: run INCOMPLETE. The control fixtures were removed by this handler. CONTROL 1 can still print ok on the resulting absence, CONTROLS 2-4 collapse to no-receipt, and any R22 RED below is charged to the kill, NOT to receipt_verdict. No verdict was reached.\n"; exit 143' INT TERM

# CONTROL 1 -- absence must read RED (absence_and_green_must_not_agree)
c1=$(receipt_verdict "$CTL_TMP/nothing-here" "$MAX_DRIFT")
case "$c1" in
  "RED no-receipt") echo "CONTROL 1 ok    -- a missing receipt reads RED" ;;
  *) echo "CONTROL 1 FAILED -- missing receipt gave: $c1"; fail=1 ;;
esac

# CONTROL 2 -- a sha this repository has never seen must read RED
printf 'sha=%s\nutc=1970-01-01T00:00:00Z\n' \
  0000000000000000000000000000000000000000 > "$CTL_TMP/unknown"
c2=$(receipt_verdict "$CTL_TMP/unknown" "$MAX_DRIFT")
case "$c2" in
  "RED unknown-commit") echo "CONTROL 2 ok    -- an unknown commit reads RED" ;;
  *) echo "CONTROL 2 FAILED -- unknown sha gave: $c2"; fail=1 ;;
esac

# CONTROL 3 -- a real but distant ancestor must read RED (stale_never_passes)
depth=$(git rev-list --count HEAD)
if [ "$depth" -gt 31 ]; then
  old=$(git rev-parse HEAD~30)
  printf 'sha=%s\nutc=1970-01-01T00:00:00Z\n' "$old" > "$CTL_TMP/stale"
  c3=$(receipt_verdict "$CTL_TMP/stale" 5)
  case "$c3" in
    "RED drift="*) echo "CONTROL 3 ok    -- 30 commits of drift past a bound of 5 reads RED" ;;
    *) echo "CONTROL 3 FAILED -- stale receipt gave: $c3"; fail=1 ;;
  esac
else
  echo "CONTROL 3 FAILED -- history is $depth commits; cannot build the stale case"
  fail=1
fi

# CONTROL 4 -- THE OTHER DIRECTION. A receipt naming HEAD must read GREEN, or
# this gate is stuck red and its red carries no information.
printf 'sha=%s\nutc=1970-01-01T00:00:00Z\n' "$(git rev-parse HEAD)" > "$CTL_TMP/fresh"
c4=$(receipt_verdict "$CTL_TMP/fresh" "$MAX_DRIFT")
case "$c4" in
  "GREEN drift=0") echo "CONTROL 4 ok    -- a receipt naming HEAD reads GREEN" ;;
  *) echo "CONTROL 4 FAILED -- fresh receipt gave: $c4"; fail=1 ;;
esac

echo

if [ "$fail" -ne 0 ]; then
  echo "R22 RED: the controls did not behave. No verdict on the real receipt is"
  echo "         trustworthy while the instrument itself is unproven."
  exit 1
fi

# --- THE REAL QUESTION -------------------------------------------------------
v=$(receipt_verdict "$RECEIPT" "$MAX_DRIFT")

case "$v" in
  "GREEN drift="*)
    d=${v#GREEN drift=}
    when=$(sed -n 's/^utc=//p' "$RECEIPT" | head -1)
    echo "The FULL-only tier last ran at $when"
    echo "  commit  $(sed -n 's/^sha=//p' "$RECEIPT" | head -1)"
    echo "  drift   $d commit(s) behind HEAD, bound $MAX_DRIFT"
    echo
    echo "R22 GREEN."
    exit 0
    ;;
  "RED no-receipt")
    echo "R22 RED: no full run has ever been recorded for this tree."
    echo
    echo "  Ten gates run under --full and nothing else triggers them. With no"
    echo "  receipt, the newest statement about them is of unknown age -- which"
    echo "  is not the same as 'they passed'."
    echo
    echo "  Fix:  bash checker/gate-all.sh --full"
    echo "  Then: FULL_RUN_COMPLETED=1 sh checker/full-freshness.sh --stamp"
    echo
    echo "  lean/Proofs/RotFreshness.lean:absence_and_green_must_not_agree"
    exit 1
    ;;
  *)
    echo "R22 RED: $v"
    echo
    echo "  The receipt does not describe this tree. A verdict computed on"
    echo "  another state of the repository says nothing about this one."
    echo
    echo "  Fix:  bash checker/gate-all.sh --full"
    echo "  Then: FULL_RUN_COMPLETED=1 sh checker/full-freshness.sh --stamp"
    echo
    echo "  lean/Proofs/RotFreshness.lean:stale_never_passes"
    exit 1
    ;;
esac
