#!/usr/bin/env bash
# This file is part of RoT MoE -- shared Lean Theorem corpus.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# Mutation harness for Proofs.Skyrim.BuildDetection.
#
# Same discipline as mutate-automovespeed.sh: assert the needle is present exactly once,
# splice LITERALLY (never awk sub(), which reads the needle as a regex), require the mutant
# to differ from the baseline on exactly one line, delete the stale .olean so Lake cannot
# serve a cached green, and restore afterwards.
#
# KILLED / SURVIVED / DISCARDED are kept distinct. DISCARDED is a statement about this
# harness, never about the theorems.

set -u
cd "${LEAN_ROOT:-.}" || exit 9

SRC="Proofs/Skyrim/BuildDetection.lean"
OLEAN=".lake/build/lib/lean/Proofs/Skyrim/BuildDetection.olean"
BAK="/tmp/builddetection.baseline.lean"

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
    {
      if (!done) {
        idx = index($0, needle)
        if (idx > 0) { $0 = substr($0, 1, idx - 1) repl substr($0, idx + length(needle)); done = 1 }
      }
      print
    }
  ' "$BAK" > "$SRC.tmp" && mv "$SRC.tmp" "$SRC"

  local changed
  changed=$(diff "$BAK" "$SRC" | grep -c '^[<>]')
  if [ "$changed" -ne 2 ]; then
    echo "$id DISCARDED - $changed diff lines (expected 2)"
    discarded=$((discarded + 1)); cp "$BAK" "$SRC"; return
  fi

  rm -f "$OLEAN"
  lake build Proofs.Skyrim.BuildDetection > /tmp/mutbd-$id.log 2>&1
  local rc=$?

  if [ "$rc" -ne 0 ]; then
    echo "$id KILLED    ($expect)"
    killed=$((killed + 1))
  else
    echo "$id SURVIVED   ($expect)"
    survived=$((survived + 1))
  fi
  cp "$BAK" "$SRC"
}

# M01: the repaired detector now looks for stock content. It must stop matching the truth.
run_mutant M01 "def detectByContent (fs : List Mesh) : Bool := fs.any (fun m => m.content == Content.built)" \
               "def detectByContent (fs : List Mesh) : Bool := fs.any (fun m => m.content == Content.stock)" \
               "content_detector_is_exact"

# M02: claim the observed disk state was entirely stock. The measured fact must fail.
#
# The first version of this mutation flipped only the CBBE mesh and SURVIVED, because
# `built` is an existential over the list and the HIMBO mesh was still built. That was a
# weak mutation, not a decorative theorem - so the model was refactored to put both
# contents on one line and the mutation now flips the whole state.
run_mutant M02 "def observedContents : List Content := [Content.built, Content.built]" \
               "def observedContents : List Content := [Content.stock, Content.stock]" \
               "observed_was_built"

# M03: make the location detector ignore its exclusion list entirely. The recorded false red
# must stop reproducing.
run_mutant M03 "  fs.any (fun m => !(excluded.contains m.loc))" \
               "  fs.any (fun m => true)" \
               "old_detector_missed_it + both general theorems"

# M04: redefine the ground truth as stock. Everything resting on it must fall.
run_mutant M04 "def built (fs : List Mesh) : Bool := fs.any (fun m => m.content == Content.built)" \
               "def built (fs : List Mesh) : Bool := fs.any (fun m => m.content == Content.stock)" \
               "built-dependent theorems"

# M05: weaken the general theorem to the two folders that happened to be excluded on the
# day. It should still build - which is the POINT: a contingent restatement is not caught by
# the compiler, only by review. Recorded so the report cannot pretend otherwise.
run_mutant M05 "theorem location_detector_always_unsound (excluded : List Loc) (l : Loc)" \
               "theorem location_detector_always_unsound (excluded : List Loc := [Loc.cbbeMod]) (l : Loc)" \
               "control: expected SURVIVED, documents what mutation CANNOT catch"

# M06: CONTROL. Comment-only change must not kill anything.
run_mutant M06 "/-- The build had happened. -/" \
               "/-- The build had happened (control mutation, semantics unchanged). -/" \
               "control: expected SURVIVED"

cp "$BAK" "$SRC"
rm -f "$OLEAN"
lake build Proofs.Skyrim.BuildDetection > /tmp/mutbd-restore.log 2>&1
restore_rc=$?

echo "-----"
echo "killed=$killed survived=$survived discarded=$discarded"
echo "baseline restored, rebuild exit $restore_rc"
exit $restore_rc
