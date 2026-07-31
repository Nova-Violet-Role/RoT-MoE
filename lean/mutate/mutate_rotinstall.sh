#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# Mutation harness for Proofs/RotInstall.lean. Same contract: needle asserted
# present exactly once BEFORE, replacement present and needle gone AFTER, stale
# .olean deleted, exit code read directly, DISCARDED never folded into SURVIVED.
#
# I09 exists specifically because #print axioms flagged
# disarm_preserves_all_scalars as depending on no axioms. I10 is a PREDICTED
# SURVIVOR and is here to be honest about a coverage gap, not to pad the count.

set -u

# Repo-relative by construction: no machine-local path ships (R2).
# Override with LEAN_ROOT=... to run against a different workspace.
LEAN_ROOT="${LEAN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
F="$LEAN_ROOT/Proofs/RotInstall.lean"
BAK="$F.mutbak"
OLEAN="$LEAN_ROOT/.lake/build/lib/lean/Proofs/RotInstall.olean"
LOG="${TMPDIR:-/tmp}/muti"
mkdir -p "$LOG"
cp "$F" "$BAK"
killed=0; survived=0; discarded=0

# Map error line numbers back to the enclosing declaration.
#
# TWO KNOWN LIMITS, stated because an attribution that overstates its reach is
# the same defect as a mutation that did not apply:
#
#  1. This is LINE-based, not dependency-based. It names the declaration whose
#     elaboration errored -- not the full closure of theorems that depended on
#     it and are therefore also unproved. When a `def` is mutated, its own
#     lemmas error first and downstream theorems may still elaborate against
#     the broken lemma, so the `dead:` column UNDER-reports. The kill itself is
#     never in doubt (the build exit code is read directly); only the blast
#     radius is approximate.
#  2. An `example` is anonymous. Earlier it produced an empty `dead:` column,
#     which reads like "nothing died" when something did. It is now reported as
#     `example@<line>`.
attribute() {
  grep -oE "^error: Proofs/RotInstall\.lean:[0-9]+" "$1" | grep -oE "[0-9]+$" | sort -un | \
  while read -r ln; do
    awk -v L="$ln" '
      /^(@\[[^]]*\] )?(noncomputable )?(theorem|lemma|def|instance|structure|inductive|example)[ (:]/ {
        if (NR <= L) { name=$0; nline=NR }
      }
      END { if (name ~ /^example/) print "example@" nline; else if (name != "") print name }' "$F"
  done | sed -E 's/^@\[[^]]*\] *//; s/^(noncomputable )?(theorem|lemma|def|instance|structure|inductive) *//; s/[ ({:].*$//' \
    | sort -u | tr '\n' ' '
}

run_mut() {
  local id="$1" needle="$2" repl="$3" expect="$4"
  cp "$BAK" "$F"
  local n; n=$(grep -F -c -- "$needle" "$BAK")
  if [ "$n" -ne 1 ]; then
    echo "$id  DISCARDED  needle occurs $n times (expected 1)"; discarded=$((discarded+1)); return
  fi
  awk -v needle="$needle" -v repl="$repl" '{
    p = index($0, needle)
    if (p > 0) { $0 = substr($0,1,p-1) repl substr($0, p+length(needle)) }
    print
  }' "$BAK" > "$F"
  local an ar; an=$(grep -F -c -- "$needle" "$F"); ar=$(grep -F -c -- "$repl" "$F")
  if [ "$an" -ne 0 ] || [ "$ar" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed (needle=$an repl=$ar)"; discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi
  rm -f "$OLEAN"
  ( cd "$LEAN_ROOT" && lake build Proofs.RotInstall ) > "$LOG/$id.log" 2>&1
  local ec=$?
  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   expected: $expect"; survived=$((survived+1))
  else
    echo "$id  KILLED     dead: $(attribute "$LOG/$id.log") | expected: $expect"
    killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

# Occurrence-indexed, strictly LINE-ORIENTED variant.
#
# It exists because I01/I09 were DISCARDED on the first run: their needle
# spanned two lines, and `grep -F -c` treats an embedded newline as ALTERNATION,
# so it counted 3 matching lines and the guard correctly refused to proceed.
# That is the multi-line-surgery hazard, caught by the guard rather than by
# luck -- had the guard been a `>= 1` test, the patch would have half-applied
# and the run would have reported a meaningless result.
#
# `arm` and `disarm` both contain the byte-identical line `  scalar := s.scalar`,
# so no single-line needle can distinguish them. The index does: occurrence 1 is
# inside `arm` (it appears first in the file), occurrence 2 inside `disarm`.
# The total count is asserted to be exactly 2 before either is touched, so a
# refactor that adds a third makes this DISCARD instead of mutating the wrong one.
run_mut_nth() {
  local id="$1" idx="$2" total="$3" needle="$4" repl="$5" expect="$6"
  cp "$BAK" "$F"
  local n; n=$(grep -F -c -- "$needle" "$BAK")
  if [ "$n" -ne "$total" ]; then
    echo "$id  DISCARDED  needle occurs $n times (expected exactly $total)"
    discarded=$((discarded+1)); return
  fi
  awk -v needle="$needle" -v repl="$repl" -v want="$idx" '
    { p = index($0, needle)
      if (p > 0) { seen++
        if (seen == want) { $0 = substr($0,1,p-1) repl substr($0, p+length(needle)) }
      }
      print }' "$BAK" > "$F"
  local an ar; an=$(grep -F -c -- "$needle" "$F"); ar=$(grep -F -c -- "$repl" "$F")
  if [ "$an" -ne $((total-1)) ] || [ "$ar" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed (needle=$an want=$((total-1)) repl=$ar)"
    discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi
  rm -f "$OLEAN"
  ( cd "$LEAN_ROOT" && lake build Proofs.RotInstall ) > "$LOG/$id.log" 2>&1
  local ec=$?
  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   expected: $expect"; survived=$((survived+1))
  else
    echo "$id  KILLED     dead: $(attribute "$LOG/$id.log") | expected: $expect"
    killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

echo "=== RotInstall mutation suite ==="

run_mut_nth I01 1 2 \
  '  scalar := s.scalar' \
  '  scalar := fun _ => none' \
  'arm_preserves_all_scalars (installer wipes every scalar key)'

run_mut I02 \
  '  hookEvents := fun k => if k ∈ armEvents then addOnce cmd (s.hookEvents k) else s.hookEvents k' \
  '  hookEvents := fun k => addOnce cmd (s.hookEvents k)' \
  'arm_preserves_unrelated_events (router registered on EVERY event)'

run_mut I03 \
  '  if c ∈ l then l else l ++ [c]' \
  '  l ++ [c]' \
  'arm_idempotent (dedupe removed -> running twice registers twice)'

run_mut I04 \
  'def addOnce (c : String) (l : List String) : List String :=' \
  'def addOnce (c : String) (_l : List String) : List String := [c] --' \
  'arm_preserves_existing_hooks, arm_appends, disarm_arm_id (installer REPLACES the users hooks)'

run_mut I05 \
  '  hookEvents := fun k => if k ∈ armEvents then addOnce cmd (s.hookEvents k) else s.hookEvents k' \
  '  hookEvents := fun k => s.hookEvents k' \
  'arm_adds_the_hooks (installer does nothing -- the non-vacuity anchor)'

run_mut I06 \
  '  hookEvents := fun k => (s.hookEvents k).filter (fun c => c != cmd)' \
  '  hookEvents := fun k => (s.hookEvents k).filter (fun _ => true)' \
  'disarm_removes, disarm_arm_id (uninstaller removes nothing)'

run_mut I07 \
  '  hookEvents := fun k => (s.hookEvents k).filter (fun c => c != cmd)' \
  '  hookEvents := fun _ => []' \
  'disarm_preserves_others (uninstaller removes EVERYTHING)'

run_mut I08 \
  '  if c ∈ l then l else l ++ [c]' \
  '  if c ∈ l then l else [c] ++ l' \
  'arm_appends (router PREPENDED -- users hooks now fire after ours)'

run_mut_nth I09 2 2 \
  '  scalar := s.scalar' \
  '  scalar := fun _ => none' \
  'disarm_preserves_all_scalars -- the axiom-free theorem, on trial for vacuity'

run_mut I10 \
  'def armEvents : List String := ["UserPromptSubmit", "PreToolUse"]' \
  'def armEvents : List String := ["UserPromptSubmit"]' \
  'PREDICTED SURVIVOR of the theorems (all quantify over armEvents, not its contents) but MUST kill the pinning example at the foot of the file'

cp "$BAK" "$F"
rm -f "$OLEAN"
( cd "$LEAN_ROOT" && lake build Proofs.RotInstall ) > "$LOG/baseline.log" 2>&1
base=$?
echo "---"
echo "killed=$killed survived=$survived discarded=$discarded"
echo "baseline restored -> lake build exit=$base"
rm -f "$BAK"
