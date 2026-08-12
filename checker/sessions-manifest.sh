#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE SESSION MANIFEST, CHECKED AGAINST ITS OWN STRUCTURE.
#
# THE DEFECT THIS EXISTS TO FIX.
#
# `checker/push-guard.sh` closes the `sessions160` obligation with
#
#     test "$(wc -l < bench/sessions-160.done)" -ge 160
#
# and the guard's own docstring names the hazard directly: "a hand-maintained
# promise.json would be edited by the same process that wants to push. The probe
# has to read something the pusher does not control by writing one line."
#
# A line count is exactly such a probe. `seq 160 > bench/sessions-160.done`
# satisfies it. The obligation would read MET on a file with no experiment
# behind it -- the permissive half of the overclaim family, and the dangerous
# half, because a probe that says too little reports SUCCESS and opens the gate.
#
# So the manifest is given STRUCTURE that a fabricated file cannot imitate by
# accident, and this script checks it. None of these properties can be satisfied
# by counting to 160:
#
#   1. exactly 160 rows, six fields each
#   2. exactly four blocks -- {forward,reverse} x {routed,unrouted} -- 40 each
#   3. turn numbers 001..040 complete within every block, no gaps, no repeats
#   4. exactly four distinct session ids, one per block, and no id shared
#      between blocks (a copy-pasted block would collapse this to fewer)
#   5. 160 DISTINCT content digests -- duplicated rows are duplicated evidence
#   6. every digest is 16 lowercase hex characters
#
# WHAT THIS DOES NOT CLAIM. It cannot re-derive the digests: the run directories
# live outside the repository (`D:/Temp/rotmoe-main-*`) and are not published,
# so CI has nothing to hash. This checks the manifest is INTERNALLY the shape a
# real 160-turn collection produces, and that the digests are unique -- it does
# not prove those digests came from those files. That verification is available
# to anyone holding the run directories and is stated in the preregistration
# rather than implied here. Saying so is the point: an instrument that overstates
# its own reach is the thing this repository keeps finding and fixing.
# =============================================================================
set -u

cd "$(dirname "$0")/.." || exit 2
M="bench/sessions-160.done"

_pass=0; _fail=0
ok ()  { printf '  PASS  %s\n' "$1"; _pass=$((_pass+1)); }
bad () { printf '  FAIL  %s\n' "$1"; _fail=$((_fail+1)); }
inf () { printf '  ----  %s\n' "$1"; }

echo "== session manifest: is it the shape a real collection makes? =="

if [ ! -s "$M" ]; then
  bad "$M is missing or empty -- the obligation is OUTSTANDING, not met"
  echo ""
  echo "== session manifest: $_pass passed, 1 failed"
  exit 1
fi

# --- the check, as a function, so the control can run it on a forgery --------
check_manifest () {
  local f="$1" prefix="$2" fails=0
  local rows fields blocks ids digests

  rows=$(wc -l < "$f" | tr -d ' ')
  if [ "$rows" -eq 160 ]; then ok "$prefix exactly 160 rows"
  else bad "$prefix $rows rows, expected exactly 160"; fails=$((fails+1)); fi

  fields=$(awk '{print NF}' "$f" | sort -u | tr '\n' ',' | sed 's/,$//')
  if [ "$fields" = "6" ]; then ok "$prefix every row has 6 fields"
  else bad "$prefix field counts seen: $fields (expected 6 only)"; fails=$((fails+1)); fi

  blocks=$(awk '{print $1" "$2}' "$f" | sort | uniq -c | awk '{print $1"x"$2"-"$3}' | sort | tr '\n' ' ')
  if [ "$blocks" = "40xforward-routed 40xforward-unrouted 40xreverse-routed 40xreverse-unrouted " ]; then
    ok "$prefix four blocks of 40: forward/reverse x routed/unrouted"
  else bad "$prefix blocks are: $blocks"; fails=$((fails+1)); fi

  # turn numbers complete inside every block
  local badturns=0 b
  for b in "forward routed" "forward unrouted" "reverse routed" "reverse unrouted"; do
    local got
    got=$(awk -v o="${b% *}" -v a="${b#* }" '$1==o && $2==a {print $3}' "$f" | sort -u | wc -l | tr -d ' ')
    [ "$got" -eq 40 ] || badturns=$((badturns+1))
  done
  if [ "$badturns" -eq 0 ]; then ok "$prefix turn numbers 001..040 complete in all four blocks"
  else bad "$prefix $badturns block(s) have gapped or repeated turn numbers"; fails=$((fails+1)); fi

  ids=$(awk '{print $4}' "$f" | sort -u | wc -l | tr -d ' ')
  if [ "$ids" -eq 4 ]; then ok "$prefix exactly 4 distinct session ids, one per block"
  else bad "$prefix $ids distinct session ids, expected 4"; fails=$((fails+1)); fi

  # no session id may appear in two different blocks
  local shared
  shared=$(awk '{print $4" "$1" "$2}' "$f" | sort -u | awk '{print $1}' | uniq -d | wc -l | tr -d ' ')
  if [ "$shared" -eq 0 ]; then ok "$prefix no session id is shared between blocks"
  else bad "$prefix $shared session id(s) span more than one block"; fails=$((fails+1)); fi

  digests=$(awk '{print $6}' "$f" | sort -u | wc -l | tr -d ' ')
  if [ "$digests" -eq 160 ]; then ok "$prefix 160 distinct content digests -- no row is a copy of another"
  else bad "$prefix $digests distinct digests, expected 160 (duplicated evidence)"; fails=$((fails+1)); fi

  local malformed
  malformed=$(awk '$6 !~ /^[0-9a-f]{16}$/ {c++} END{print c+0}' "$f")
  if [ "$malformed" -eq 0 ]; then ok "$prefix every digest is 16 lowercase hex characters"
  else bad "$prefix $malformed digest(s) are not 16 hex characters"; fails=$((fails+1)); fi

  return $fails
}

check_manifest "$M" "manifest:"

# -----------------------------------------------------------------------------
# NEGATIVE CONTROLS. An alarm nobody has tripped on purpose is an untested alarm.
# Both forgeries below SATISFY the push-guard's line-count probe, which is the
# whole reason this script exists.
# -----------------------------------------------------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# (a) the forgery the line-count probe cannot see: 160 lines of nothing.
#
# NOTE ON THE SUBSHELLS, because the first version of this script got it wrong.
# `check_manifest` reports through the shared `ok`/`bad` counters. Called
# directly -- even with output redirected -- a forgery's nine expected failures
# were added to the REAL tally, and this script failed on a manifest it had just
# certified: "17 passed, 9 failed" with every genuine row PASS. Redirecting
# output does not isolate state. The `( ... )` does: the counters move inside the
# subshell and die with it, while the exit status still crosses back, which is
# the only thing the control needs.
seq 160 > "$TMP/counted.done"
if ( check_manifest "$TMP/counted.done" "control-a:" >/dev/null 2>&1 ); then
  bad "CONTROL: a file of 160 counted integers was ACCEPTED -- the check is decorative"
else
  ok "CONTROL: 160 lines of counted integers are REFUSED (they pass push-guard's probe)"
fi

# (b) the subtler forgery: one real block copy-pasted four times. Correct row
#     count, correct field count, correct block labels -- and it collapses the
#     distinct-id and distinct-digest properties, which is why both are checked.
awk '$1=="forward" && $2=="routed"' "$M" > "$TMP/one.txt"
{ cat "$TMP/one.txt"
  sed 's/^forward routed/forward unrouted/' "$TMP/one.txt"
  sed 's/^forward routed/reverse routed/'   "$TMP/one.txt"
  sed 's/^forward routed/reverse unrouted/' "$TMP/one.txt"
} > "$TMP/cloned.done"
if ( check_manifest "$TMP/cloned.done" "control-b:" >/dev/null 2>&1 ); then
  bad "CONTROL: one block cloned into four was ACCEPTED -- duplicated evidence is invisible"
else
  ok "CONTROL: one block cloned four times is REFUSED (ids and digests repeat)"
fi

inf "the run directories are not published, so the digests cannot be re-derived here"
inf "holders of D:/Temp/rotmoe-main-{fwd,rev} can re-hash and compare; the preregistration says so"

echo ""
echo "== session manifest: $_pass passed, $_fail failed"
[ "$_fail" -eq 0 ] || exit 1
exit 0
