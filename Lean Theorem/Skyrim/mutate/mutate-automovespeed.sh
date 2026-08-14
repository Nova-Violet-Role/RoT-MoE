#!/usr/bin/env bash
# This file is part of RoT MoE -- shared Lean Theorem corpus.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# Mutation harness for Proofs.Skyrim.AutoMoveSpeed.
#
# The point of this file is to distinguish three outcomes that a careless harness collapses
# into one reassuring "green":
#   KILLED    - the mutation applied AND the build went red. The theorems are load-bearing.
#   SURVIVED  - the mutation applied and the build stayed green. Something is decorative.
#   DISCARDED - the patch never landed. This says nothing about the theorems, and must never
#               be counted as SURVIVED.
#
# Two safeguards make the difference measurable: the needle count is asserted BEFORE the
# build, and the stale .olean is deleted so Lake cannot hand back a cached green.

set -u
cd "${LEAN_ROOT:-.}" || exit 9

SRC="Proofs/Skyrim/AutoMoveSpeed.lean"
OLEAN=".lake/build/lib/lean/Proofs/Skyrim/AutoMoveSpeed.olean"
BAK="/tmp/automovespeed.baseline.lean"

cp "$SRC" "$BAK" || exit 9

killed=0; survived=0; discarded=0

run_mutant () {
  local id="$1" needle="$2" replacement="$3" expect="$4"
  cp "$BAK" "$SRC"

  local n
  n=$(grep -F -c -- "$needle" "$SRC")
  if [ "$n" -ne 1 ]; then
    echo "$id DISCARDED - needle count $n (expected 1): $needle"
    discarded=$((discarded + 1))
    cp "$BAK" "$SRC"
    return
  fi

  # LITERAL splice via index/substr. An earlier version used awk sub(), which treats the
  # needle as a REGEX and the replacement's '&' as special - and every needle here contains
  # '(', '+' or '|'. That silently mangled lines instead of applying the intended mutation,
  # so a red build could not be attributed to the theorem under test. Never use sub() for
  # this.
  awk -v needle="$needle" -v repl="$replacement" '
    {
      if (!done) {
        idx = index($0, needle)
        if (idx > 0) {
          $0 = substr($0, 1, idx - 1) repl substr($0, idx + length(needle))
          done = 1
        }
      }
      print
    }
  ' "$BAK" > "$SRC.tmp" && mv "$SRC.tmp" "$SRC"

  # The mutant must differ from the baseline on exactly one line. More than one means the
  # splice hit something it should not have; zero means it did not land at all.
  local changed
  changed=$(diff "$BAK" "$SRC" | grep -c '^[<>]')
  if [ "$changed" -ne 2 ]; then
    echo "$id DISCARDED - mutant differs from baseline on $changed diff lines (expected 2)"
    discarded=$((discarded + 1))
    cp "$BAK" "$SRC"
    return
  fi

  if [ "$(grep -F -c -- "$replacement" "$SRC")" -lt 1 ]; then
    echo "$id DISCARDED - replacement not present after edit"
    discarded=$((discarded + 1))
    cp "$BAK" "$SRC"
    return
  fi

  rm -f "$OLEAN"
  lake build Proofs.Skyrim.AutoMoveSpeed > /tmp/mut-$id.log 2>&1
  local rc=$?

  if [ "$rc" -ne 0 ]; then
    echo "$id KILLED    ($expect) - build exit $rc"
    killed=$((killed + 1))
  else
    echo "$id SURVIVED   ($expect) - build exit 0, theorem did not depend on this"
    survived=$((survived + 1))
  fi
  cp "$BAK" "$SRC"
}

# M01: cap the ladder at 2 instead of 3. Three taps can no longer reach running.
run_mutant M01 "def inc (s : Int) : Int := clampInt (s + 1) 0 3" \
               "def inc (s : Int) : Int := clampInt (s + 1) 0 2" \
               "three_taps_reach_running"

# M02: start the mod already at running. Minimality of three taps becomes false.
run_mutant M02 "def defaultSpeed : Int := 0" \
               "def defaultSpeed : Int := 3" \
               "fewer_taps_never_run"

# M03: make a tap do nothing. The whole ladder collapses.
run_mutant M03 "  | n + 1, s => inc (taps n s)" \
               "  | n + 1, s => taps n s" \
               "taps_from_default"

# M04: redefine running as 2. The guide's target no longer matches the source comment.
run_mutant M04 "def running : Int := 3" \
               "def running : Int := 2" \
               "three_taps_reach_running"

# M05: decrease the speed instead of increasing it - the band invariant must still hold,
# but reaching running must fail.
run_mutant M05 "  | n + 1, s => inc (taps n s)" \
               "  | n + 1, s => dec (taps n s)" \
               "three_taps_reach_running"

# M06: CONTROL. A comment-only change must NOT kill anything. If this reports KILLED the
# harness is measuring something other than the theorems.
run_mutant M06 "-- Executable agreement with the model, on the concrete values in the guide." \
               "-- Executable agreement with the model (control mutation, semantics unchanged)." \
               "control: expected SURVIVED"

cp "$BAK" "$SRC"
rm -f "$OLEAN"
lake build Proofs.Skyrim.AutoMoveSpeed > /tmp/mut-restore.log 2>&1
restore_rc=$?

echo "-----"
echo "killed=$killed survived=$survived discarded=$discarded"
echo "baseline restored, rebuild exit $restore_rc"
exit $restore_rc
