#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotSample.lean (calibrating a corpus, and the two ways it cheats)
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
# WHAT THIS SUITE IS AIMED AT. The module proves that the stratified cap in
# bench/calib-prompts.js selects by POSITION and cannot see how either arm was
# graded -- the property that makes it admissible in front of a paired test.
#
#   S01-S03  THE CAP ITSELF. Break the ceiling, the stride, or the max-1 guard.
#            A survivor means cap_never_exceeds or the guards are not pinning
#            the arithmetic the JavaScript is supposed to mirror.
#   S04      MAKE flipGrade THE IDENTITY. This is the mutant that would have
#            survived: with flipGrade = id, every blindness theorem reads
#            "cap pool per = cap pool per" and holds for a cap that DOES read
#            the grades. It is killed by three #guards that were added for
#            exactly this reason, before the suite was written.
#   S05-S07  THE ORDER OF CAP AND GRADE, and the witness that separates them.
#   S08-S10  The shipped shape table and the executable checks.
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotSample.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotSample.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutsample.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotSample ) >/tmp/mut_pre_rotsample.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotSample)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotsample.log
  exit 2
fi
echo "preflight: baseline builds GREEN, $F present -- kills are attributable"

# --- SOURCE SANITY: a green baseline is NOT proof the source is intact -----
# AN EMPTY LEAN FILE BUILDS GREEN, so "the baseline compiles" is weaker than it
# looks. The source is checked for CONTENT before it is copied over the backup.
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotSample ) >/dev/null 2>&1' EXIT

killed=0; survived=0; discarded=0

# --- OPTIONAL FILTER, AND WHY A PARTIAL RUN MUST LOOK PARTIAL ----------------
# The suite is 9 mutants and each one rebuilds the module, so a full pass
# outgrew the wall-clock ceiling of the agent that runs it -- and MEASURED
# 2026-08-07, being killed at that ceiling left a MUTATED RotGuard.lean on
# disk beside its .mutbak. Chunking is the fix; pretending a chunk is the suite
# would be much worse than the timeout.
#
#   MUT_ONLY="A05 A06"   run only those, everything else SKIPPED
#
# A filtered run prints a PARTIAL banner and exits 3, never 0. Nothing that
# consumes this output -- the CHANGELOG count, repo-complete's cross-check, CI
# -- can mistake four killed mutants for forty-eight.
skipped=0
filtered=0
[ -n "${MUT_ONLY:-}" ] && filtered=1

run_mut() {
  local id="$1" needle="$2" repl="$3" expect="$4"

  if [ -n "${MUT_ONLY:-}" ]; then
    case " $MUT_ONLY " in
      *" $id "*) : ;;
      *) skipped=$((skipped+1)); return ;;
    esac
  fi

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotSample ) > "$LOG/$id.log" 2>&1
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
    dead=$(grep -oE "^error: Proofs/RotSample\.lean:[0-9]+" "$LOG/$id.log" \
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

echo "=== RotSample mutation suite ==="

# Each needle is asserted present EXACTLY once before it is applied, and the
# replacement is asserted present afterwards. A needle that does not match is
# DISCARDED, never SURVIVED.

run_mut S01 \
  "  (everyNth pool (pool.length / max 1 per)).take per" \
  "  (everyNth pool (pool.length / max 1 per)).take (per + 1)" \
  "cap_never_exceeds -- the ceiling the JavaScript MAX is supposed to enforce"

run_mut S02 \
  "  (l.zipIdx.filter (fun p => p.2 % (max 1 s) == 0)).map Prod.fst" \
  "  (l.zipIdx.filter (fun p => p.2 % (max 1 s) == 1)).map Prod.fst" \
  "the stride starts at the FIRST element -- an off-by-one drops item one"

run_mut S03 \
  "  (l.zipIdx.filter (fun p => p.2 % (max 1 s) == 0)).map Prod.fst" \
  "  (l.zipIdx.filter (fun p => p.2 % s == 0)).map Prod.fst" \
  "the max-1 guard -- without it a stride of 0 collapses the sample to one item"

run_mut S04 \
  "def flipGrade (i : Item) : Item := { i with routedRight := !i.routedRight }" \
  "def flipGrade (i : Item) : Item := i" \
  "flipGrade MUST flip -- as the identity every blindness theorem is vacuous"

run_mut S05 \
  "  cap (pool.filter (fun i => i.routedRight)) per" \
  "  cap (pool.filter (fun i => !i.routedRight)) per" \
  "grading_first_manufactures_a_routed_win -- the forbidden order's direction"

run_mut S06 \
  "  (cap pool per).filter (fun i => i.routedRight)" \
  "  (cap pool per).filter (fun _ => true)" \
  "capThenGrade actually grades -- otherwise the honest order is a no-op"

run_mut S07 \
  "def witness : List Item := [⟨0, 0, false⟩, ⟨0, 1, true⟩]" \
  "def witness : List Item := [⟨0, 0, true⟩, ⟨0, 1, true⟩]" \
  "grading_first_can_change_the_sample -- the witness must SEPARATE the orders"

run_mut S08 \
  "#guard (shippedShapes.map Prod.snd).sum = 80" \
  "#guard (shippedShapes.map Prod.snd).sum = 79" \
  "the shipped pool is 80 items -- the number the corpus was actually built at"

run_mut S09 \
  "#guard shippedShapes.all (fun p => 0 < p.2) = true" \
  "#guard shippedShapes.all (fun p => 0 < p.2) = false" \
  "no question shape was wiped out by the cap"

run_mut S10 \
  "#guard cap witness 0 = []" \
  "#guard cap witness 0 = witness" \
  "zero_ceiling_selects_nothing -- a cap of 0 must not mean 'no cap'"

_total=$((killed + survived + discarded + skipped))
if [ "${_total:-0}" -eq 0 ]; then
  echo "FAIL: ZERO mutants ran. This suite measured NOTHING."
  echo "A blank or zero count is not a clean sweep -- it is a truncated harness."
  exit 1
fi

# THE VERDICT MUST BE ABLE TO FAIL.
#
# This block used to be an unconditional `exit 0` under a sentence claiming
# every mutant was killed -- so a SURVIVING mutant was reported as a clean
# sweep. Measured 2026-08-09 when C05 survived in mutate_rotsample.sh and the
# suite still exited 0. Every suite in this directory shared the defect.
#
# A survivor and a discard mean different things and neither is a pass:
#   SURVIVED  the mutation applied, the build stayed green -> COVERAGE GAP
#   DISCARDED the mutation never applied -> NOTHING WAS TESTED
if [ "${survived:-0}" -gt 0 ]; then
  echo "FAIL: $survived of $_total mutant(s) SURVIVED -- those beliefs are NOT defended."
  echo "A survivor is a coverage gap. Add the theorem or the #guard; never delete the mutant."
  exit 1
fi
if [ "${discarded:-0}" -gt 0 ]; then
  echo "FAIL: $discarded mutant(s) DID NOT APPLY -- the patch never landed, so nothing was tested."
  echo "Fix the needle. A mutation that cannot be applied is not evidence of anything."
  exit 1
fi
# RESTORE AND REBUILD -- a suite must leave the tree GREEN.
#
# Each mutant deletes the .olean, and the EXIT trap restores only the SOURCE.
# So without this, a PASSING suite leaves the module uncompiled and the next
# instrument (lake env leanchecker) fails for a reason unrelated to any proof.
# Measured 2026-08-09 on Proofs.RotSample.
cp "$BAK" "$F" 2>/dev/null
( cd ${LEAN_ROOT:-.} && lake build Proofs.RotSample ) >/dev/null 2>&1
_base=$?
if [ "$_base" -ne 0 ]; then
  echo "FAIL: the baseline does NOT rebuild after this suite (exit $_base)."
  echo "The tree is left RED. A green mutation report over a red tree is worthless."
  exit 1
fi
echo "baseline restored and rebuilt GREEN"
echo "All $killed mutants killed ($_total ran, 0 survived, 0 discarded)."
echo "Every belief above is refuted by a theorem or a #guard."
exit 0
