#!/usr/bin/env bash
# This file is part of RoT MoE -- shared Lean Theorem corpus.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# Mutation harness for Proofs.Skyrim.AutoMoveUnstuck.
#
# These theorems exist because the Socio warned that a bad stuck-recovery could reproduce
# the level-0 loop. So the mutations here are not decorative: each one is a plausible way to
# write the routine WRONG, and the point is to confirm the proof catches it before any
# Papyrus is compiled.

set -u
cd "${LEAN_ROOT:-.}" || exit 9

SRC="Proofs/Skyrim/AutoMoveUnstuck.lean"
OLEAN=".lake/build/lib/lean/Proofs/Skyrim/AutoMoveUnstuck.olean"
BAK="/tmp/automoveunstuck.baseline.lean"

cp "$SRC" "$BAK" || exit 9
killed=0; survived=0; discarded=0

run_mutant () {
  local id="$1" needle="$2" replacement="$3" expect="$4"
  cp "$BAK" "$SRC"
  local n
  n=$(grep -F -c -- "$needle" "$SRC")
  if [ "$n" -ne 1 ]; then
    echo "$id DISCARDED - needle count $n (expected 1)"
    discarded=$((discarded + 1)); cp "$BAK" "$SRC"; return
  fi
  awk -v needle="$needle" -v repl="$replacement" '
    { if (!done) { idx = index($0, needle)
        if (idx > 0) { $0 = substr($0,1,idx-1) repl substr($0, idx+length(needle)); done = 1 } }
      print }
  ' "$BAK" > "$SRC.tmp" && mv "$SRC.tmp" "$SRC"
  local changed
  changed=$(diff "$BAK" "$SRC" | grep -c '^[<>]')
  if [ "$changed" -ne 2 ]; then
    echo "$id DISCARDED - $changed diff lines (expected 2)"
    discarded=$((discarded + 1)); cp "$BAK" "$SRC"; return
  fi
  rm -f "$OLEAN"
  lake build Proofs.Skyrim.AutoMoveUnstuck > /tmp/mutum-$id.log 2>&1
  local rc=$?
  if [ "$rc" -ne 0 ]; then echo "$id KILLED    ($expect)"; killed=$((killed+1))
  else echo "$id SURVIVED   ($expect)"; survived=$((survived+1)); fi
  cp "$BAK" "$SRC"
}

# M01: THE level-0 bug. Never set aborted - the routine retries forever.
run_mutant M01 "  else { stuckTicks := 0, attempts := s.attempts + 1, aborted := true }" \
               "  else { stuckTicks := 0, attempts := s.attempts + 1, aborted := false }" \
               "gives_up_when_never_moving / stays_given_up"

# M02: raise the cap so it does not give up within the proved window.
run_mutant M02 "def maxAttempts : Nat := 3" \
               "def maxAttempts : Nat := 99" \
               "gives_up_when_never_moving"

# M03: fire the recovery even while the player is moving - fights the AI package.
run_mutant M03 "  !s.aborted && !moved && !(s.stuckTicks + 1 < stuckThreshold)" \
               "  !s.aborted && !(s.stuckTicks + 1 < stuckThreshold)" \
               "never_fires_while_moving"

# M04: let an aborted machine restart itself.
run_mutant M04 "  if s.aborted then s" \
               "  if s.aborted then initial" \
               "abort_is_absorbing / stays_given_up"

# M05: drop the strict-below-cap half of the invariant, the part that makes the bound
# inductive at all.
run_mutant M05 "  s.attempts ≤ maxAttempts ∧ (s.aborted = false → s.attempts < maxAttempts)" \
               "  s.attempts ≤ maxAttempts" \
               "inv_step / attempts_bounded"

# M06: movement no longer clears the attempt counter - a long trip would abort spuriously.
run_mutant M06 "  else if moved then { stuckTicks := 0, attempts := 0, aborted := false }" \
               "  else if moved then { stuckTicks := 0, attempts := s.attempts, aborted := false }" \
               "movement_resets"

# M07: CONTROL. Comment-only, must survive.
run_mutant M07 "/-- Where every journey starts. -/" \
               "/-- Where every journey starts (control mutation). -/" \
               "control: expected SURVIVED"

cp "$BAK" "$SRC"
rm -f "$OLEAN"
lake build Proofs.Skyrim.AutoMoveUnstuck > /tmp/mutum-restore.log 2>&1
restore_rc=$?
echo "-----"
echo "killed=$killed survived=$survived discarded=$discarded"
echo "baseline restored, rebuild exit $restore_rc"
exit $restore_rc
