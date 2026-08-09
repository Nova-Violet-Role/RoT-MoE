#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotAbility.lean (every lens proves itself)
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
# WHAT THIS SUITE IS AIMED AT. This module used to score three of the nine
# abilities `notModelled` -- while proving the router-observable effect for two
# of them fifty lines further down. The evidence table and the theorems had
# drifted apart and nothing noticed, because a `--` comment beside a table row
# is not checked by anything. The mutations below re-create exactly that drift:
#
#   M01  an ability is filed as beyond reach again   (the original defect)
#   M02  a lane lead stops leading its own lane      (the arithmetic breaks)
#   M03  the ninth lens loses its weight in a lane   (K silently becomes 8)
#   M04  an effect names the wrong lens              (table/theorem drift)
#   M05  an ability is filed as merely measured      (proved -> unproved)
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotAbility.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotAbility.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutability.XXXXXX")"

[ -f "$F" ] || {
  echo "FATAL: $F not found. Refusing to run: every mutant would fail to build"
  echo "and be scored KILLED without a line having been mutated."
  exit 2
}

# --- NO-DOWNLOAD GUARD ------------------------------------------------------
# `lake build` RESOLVES the package first, and against the vendored `lean/` tree
# that resolution starts fetching mathlib INTO the repository. A workspace that
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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotAbility ) >/tmp/mut_pre_rotability.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotAbility)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotability.log
  exit 2
fi
echo "preflight: baseline builds GREEN, $F present -- kills are attributable"

# --- SOURCE SANITY: a green baseline is NOT proof the source is intact -----
# Measured 2026-08-03, the hard way. A run of this suite was killed by a
# wall-clock timeout DURING `awk ... > "$F"`. The redirection truncates the
# file before awk writes, so the source was left at ZERO BYTES. The EXIT trap
# never ran (SIGKILL). Then the next run did `cp "$F" "$BAK"` and copied the
# EMPTY file over the only good backup, reported every needle as DISCARDED,
# and restored the emptiness. `rm -f "$BAK"` then deleted the evidence.
#
# The preflight could not see it: AN EMPTY LEAN FILE BUILDS GREEN. "The
# baseline compiles" is a weaker statement than it looks, so the source is
# checked for CONTENT before it is ever copied over the backup.
_lines=$(wc -l < "$F" 2>/dev/null || echo 0)
_thms=$(grep -c "^theorem \|^@\[simp\] theorem \|^example " "$F" 2>/dev/null || echo 0)
if [ "${_lines:-0}" -lt 20 ] || [ "${_thms:-0}" -lt 1 ]; then
  echo "FATAL: $F looks DAMAGED ($_lines lines, $_thms theorem/example lines)."
  echo "Refusing to overwrite the backup with it. An empty or truncated source"
  echo "compiles green and would be scored as a suite full of DISCARDED mutants."
  echo "Restore the file (git checkout -- <path>) before running this suite."
  exit 2
fi

cp "$F" "$BAK"
# The rebuild lives in the TRAP, not in the tail, so it runs on EVERY exit
# path -- DISCARDED and SURVIVED included. With it in the tail only, a suite
# that reported a real failure left the module with no .olean, and the NEXT
# run reported SKIP (exit 3) instead of the failure. Measured 2026-08-09.
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotAbility ) >/dev/null 2>&1' EXIT

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotAbility ) > "$LOG/$id.log" 2>&1
  local ec=$?

  # --- IS THIS KILL ATTRIBUTABLE? -------------------------------------------
  # A non-zero exit proves the theorems died only if a build actually happened.
  # A failed redirection, a missing toolchain or a killed process each give a
  # non-zero status with NO build log, and each would otherwise be filed as a
  # kill. MEASURED in CI run 31180174433: mutate_rotgauge.sh wrote its logs to a
  # hard-coded /d/tmp/mut, mkdir was refused on the Linux runner, bash declined
  # to run each build because the redirect could not be opened, and all twelve
  # mutants were scored KILLED without lake running once. The job was green.
  #
  # No log, or an empty one, means nothing was learned. DISCARDED -- which
  # cannot exit 0 -- rather than a finding.
  if [ ! -s "$LOG/$id.log" ]; then
    echo "$id  DISCARDED  build produced NO log (exit=$ec) -- lake did not run,"
    echo "                so this is a harness fault, not a dead theorem."
    discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi

  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   (build still exit 0)  expected to kill: $expect"
    survived=$((survived+1))
  else
    # The reported error lines are a LOWER BOUND on what died, not an inventory.
    # A mutant build produces no olean, so every theorem in the module is
    # unusable downstream regardless of which line the elaborator complained at.
    local dead
    dead=$(grep -oE "^error: Proofs/RotAbility\.lean:[0-9]+" "$LOG/$id.log" \
      | grep -oE "[0-9]+$" | sort -un | while read -r ln; do
        awk -v L="$ln" '
          /^(theorem|def|private def|instance|structure|inductive|example)/ {
            if (NR <= L) { name=$0 }
          }
          END { if (name != "") print name }
        ' "$F"
      done | sed -E 's/^(private )?(theorem|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' \
      | sort -u | tr '\n' ',')
    if [ ! -f "$OLEAN" ]; then
      echo "$id  KILLED     exit=$ec  MODULE DEAD (no olean: every theorem unusable)"
      echo "        errors at: ${dead%,}  <- LOWER BOUND, not the full set"
      echo "        expected: $expect"
    else
      echo "$id  KILLED     exit=$ec  dead: ${dead%,}"
    fi
    killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

echo "=== RotAbility mutation suite ==="

# M01 -- the original defect, restored: an ability is filed as beyond Lean's
# reach even though the lane-lead theorem below settles it.
run_mut M01 \
  '  | .chaosWeaving              => .proved' \
  '  | .chaosWeaving              => .notModelled' \
  'every_ability_is_proved, evidence_split, no_ability_is_unmodelled, expressive_lenses_prove_themselves'

# M02 -- Chroma stops leading PREDICTIVE. The ability is exactly this
# inequality, so the ability claim must fall with it.
run_mut M02 \
  '  | .chroma => 24/10' \
  '  | .chroma => 4/10' \
  'chroma_leads_predictive, every_ability_effect_holds'

# M03 -- the ninth lens loses its weight in a lane, which is how K silently
# degrades from 9 to 8 without anything printing a warning.
#
# The needle MUST be one line. An earlier version spanned two lines plus a blank
# one; `grep -F -c` treats embedded newlines as SEPARATE patterns, so it counted
# 525 "occurrences" and the mutant was correctly DISCARDED rather than scored.
# That is the harness's assertion doing its job -- a multi-line needle silently
# not matching is exactly how a suite reports SURVIVED for a patch that never
# landed. `predictiveLam .chroma` is the only 24/10 in the file, so the lead's
# own weight is a unique single-line target.
run_mut M03 \
  '  | .claude => 15/10   -- Claude OWN §2 default lambda; Chroma LEADS PREDICTIVE' \
  '  | .claude => 0' \
  'every_lens_weighted_in_every_profile'

# M04 -- table/theorem drift in its purest form: the effect names a different
# lens than the one whose lane it describes.
run_mut M04 \
  '      (∀ l ∈ lenses, l ≠ .chroma → predictiveLam l < predictiveLam .chroma) ∧' \
  '      (∀ l ∈ lenses, l ≠ .carnage → predictiveLam l < predictiveLam .chroma) ∧' \
  'every_ability_effect_holds'

# M05 -- an ability slides from proved to merely measured.
run_mut M05 \
  '  | .emotionalResonanceMapping => .proved' \
  '  | .emotionalResonanceMapping => .measured' \
  'every_ability_is_proved, evidence_split, nothing_is_merely_measured'

echo
# --- RESTORE THE BASELINE ---------------------------------------------------
# The EXIT trap restores the SOURCE, but the last mutant deleted the .olean and
# nothing rebuilt it. Measured 2026-08-03: re-running this suite immediately
# afterwards hit its own no-download guard and reported SKIP, because the
# workspace it was pointed at was no longer built. A suite that leaves the tree
# unbuildable has told you nothing about the final state of the tree.
cp "$BAK" "$F"
if ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotAbility ) >/tmp/mut_post_rotability.log 2>&1; then
  echo "baseline restored and REBUILT green (olean present again)"
else
  echo "FATAL: the tree does not build after restore -- the suite left damage."
  tail -5 /tmp/mut_post_rotability.log
  exit 2
fi

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
