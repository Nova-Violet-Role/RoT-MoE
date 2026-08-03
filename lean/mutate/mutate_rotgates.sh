#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotGates.lean (the fast/deep gate split)
#
# The contract, identical to the other suites in this directory:
#   1. assert the needle is present EXACTLY once before mutating; if not -> DISCARDED
#   2. assert the mutation LANDED after patching (needle gone, replacement present)
#   3. delete the stale .olean so Lake cannot skip the rebuild
#   4. rebuild, read the exit code DIRECTLY
#   5. restore from the backup, always
#
# DISCARDED != SURVIVED. The first is a defect in this harness, the second is a
# claim about the theorem. Folding them together manufactures reassurance.
#
# WHAT THIS SUITE IS AIMED AT. The split it models is a mechanism that already
# produced one false green in this repo: a gate behind `FULL=1` was red while
# the default sweep reported 26/26 GREEN. So the mutations are not arbitrary
# edits -- each one RE-CREATES a way the split could silently stop protecting:
#
#   M01  the run drops fast gates          (what FULL=1 did)
#   M02  triggers match only exact paths   (a directory prefix stops escalating)
#   M03  an empty trigger list fires       (the silent hole, inverted)
#   M04  the two tiers overlap             (a gate in both, or in neither)
#   M05  every gate becomes fast           (the split silently does nothing)
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotGates.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotGates.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutgates.XXXXXX")"

[ -f "$F" ] || {
  echo "FATAL: $F not found. Refusing to run: every mutant would fail to build"
  echo "and be scored KILLED without a line having been mutated."
  exit 2
}

# --- NO-DOWNLOAD GUARD ------------------------------------------------------
# `lake build` RESOLVES the package first, and against the vendored `lean/` tree
# that resolution starts fetching mathlib INTO the repository (measured: 7.2 GB
# before it was caught, against a tree that ships as ~200 KB). A workspace that
# was never built cannot satisfy this suite, so it SKIPS rather than builds.
# Exit 3 is a skip everywhere in this repo, and a skip is never a pass.
_WSDIR="${LEAN_ROOT:-.}"
if [ ! -d "$_WSDIR/.lake/packages" ] || [ ! -f "$OLEAN" ]; then
  echo "SKIP: $_WSDIR is not a BUILT Lean workspace (.lake/packages or $OLEAN absent)."
  echo "      Refusing to invoke lake: resolving mathlib would DOWNLOAD ~7.2 GB."
  echo "      Set LEAN_ROOT to an already-built workspace to run this suite."
  echo "      This is a SKIP (exit 3), never a pass."
  exit 3
fi

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotGates ) >/tmp/mut_pre_rotgates.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotGates)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotgates.log
  exit 2
fi
echo "preflight: baseline builds GREEN, $F present -- kills are attributable"

cp "$F" "$BAK"
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"' EXIT

killed=0; survived=0; discarded=0

run_mut() {
  local id="$1" needle="$2" repl="$3" expect="$4"
  cp "$BAK" "$F"

  local n
  n=$(grep -F -c -- "$needle" "$BAK")
  if [ "$n" -ne 1 ]; then
    echo "$id  DISCARDED  needle occurs $n times (expected 1) -- patch not applied"
    discarded=$((discarded+1)); return
  fi

  awk -v needle="$needle" -v repl="$repl" '{
    p = index($0, needle)
    if (p > 0) { $0 = substr($0,1,p-1) repl substr($0, p+length(needle)) }
    print
  }' "$BAK" > "$F"

  local after_needle after_repl
  after_needle=$(grep -F -c -- "$needle" "$F")
  after_repl=$(grep -F -c -- "$repl" "$F")
  if [ "$after_needle" -ne 0 ] || [ "$after_repl" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed (needle=$after_needle repl=$after_repl)"
    discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi

  rm -f "$OLEAN"
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotGates ) > "$LOG/$id.log" 2>&1
  local ec=$?

  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   (build still exit 0)  expected to kill: $expect"
    survived=$((survived+1))
  else
    # Attribution note, inherited from the RotGauge suite and just as true here:
    # the reported error lines are a LOWER BOUND on what died, not an inventory.
    # A mutant build produces no olean, so every theorem in the module is
    # unusable downstream regardless of which line the elaborator complained at.
    local dead
    dead=$(grep -oE "^error: Proofs/RotGates\.lean:[0-9]+" "$LOG/$id.log" \
      | grep -oE "[0-9]+$" | sort -un | while read -r ln; do
        awk -v L="$ln" '
          /^(theorem|def|private def|instance|structure|inductive|example)/ {
            if (NR <= L) { name=$0 }
          }
          END { if (name != "") print name }
        ' "$F"
      done | sed -E 's/^(private )?(theorem|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' \
      | sort -u | tr '\n' ',')
    local guards
    guards=$(grep -c "did not evaluate to .true." "$LOG/$id.log")
    if [ ! -f "$OLEAN" ]; then
      echo "$id  KILLED     exit=$ec  MODULE DEAD (no olean: every theorem unusable)"
      echo "        errors at: ${dead%,}  <- LOWER BOUND, not the full set"
      echo "        #guard failures: $guards"
      echo "        expected: $expect"
    else
      echo "$id  KILLED     exit=$ec  dead: ${dead%,}  guards failed: $guards"
    fi
    killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

echo "=== RotGates mutation suite ==="

# M01 -- the exact shape of the FULL=1 regression: the run stops including the
# gates that are supposed to be unconditional.
run_mut M01 \
  '  gs.filter (fun g => isFast g || fires g staged)' \
  '  gs.filter (fun g => fires g staged)' \
  'fast_always_runs, stagedRun_nil, and the count guards'

# M02 -- triggers stop being prefixes. `lean/` would no longer escalate on
# `lean/Proofs/RotGauge.lean`, so a proof edit would skip the Lean gates.
run_mut M02 \
  '  p.take trigger.length = trigger' \
  '  p = trigger' \
  'the staged-run count guards (directory prefixes stop matching)'

# M03 -- the silent hole, inverted: a gate with NO triggers starts firing, which
# would make `no_trigger_never_escalates` false.
run_mut M03 \
  '  staged.any (fun p => g.triggers.any (fun t => hits t p))' \
  '  staged.any (fun p => g.triggers.all (fun t => hits t p))' \
  'no_trigger_never_escalates, stagedRun_nil'

# M04 -- the tiers overlap instead of partitioning.
run_mut M04 \
  '  gs.filter (fun g => !isFast g)' \
  '  gs.filter (fun g => isFast g)' \
  'tiers_disjoint, tier_lengths, mem_tier_total, deepSet guards'

# M05 -- the split silently does nothing: every gate is fast again.
run_mut M05 \
  '  | Tier.deep => false' \
  '  | Tier.deep => true' \
  'the fastSet/deepSet count guards, the deep-trigger guard'

echo
echo "killed=$killed survived=$survived discarded=$discarded"
if [ "$discarded" -ne 0 ]; then
  echo "REFUSING to report a verdict: $discarded mutation(s) did not apply."
  echo "A patch that did not land tells you nothing about the theorem."
  exit 2
fi
if [ "$survived" -ne 0 ]; then
  echo "$survived mutation(s) SURVIVED -- those theorems do not constrain the model."
  exit 1
fi
echo "ALL $killed MUTATIONS KILLED."
exit 0
