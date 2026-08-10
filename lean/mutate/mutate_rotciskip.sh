#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotCiSkip.lean (why one ordering cannot attribute)
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
# WHAT THIS SUITE IS AIMED AT. checker/ci-honesty.sh judges a CI run by reading
# every step's CONCLUSION, and on run 31308026819 it passed 8/0 with five working
# negative controls. That result stands. What it structurally cannot see is a
# step whose BODY printed "SKIP: no credentials" and then concluded success --
# measured on that same run's log.zip: 45 runtime skip lines inside green steps,
# across 7 checkers, with zero real ::error and zero real ::warning annotations.
#
# That is not a fake green -- every skip is labelled "a SKIP is never a pass".
# It is an UNCOUNTED COVERAGE GAP, and an uncounted gap grows for free.
#
# The failure mode of the ratchet that closes it is loosening, not breaking:
# a budget quietly extended until it covers everything still reports green while
# checking nothing. So the mutants attack the detector and the budget:
#
#   C01-C03  THE DETECTOR. Skip-detection inverted, or a skipping step counted
#            as substantive. If these survive, coverage is arithmetic on nothing.
#   C04-C06  THE RATCHET. Never fires, always fires, or the declared-budget test
#            reversed so declaring a skip is what triggers the alarm.
#   C07-C08  THE BLINDNESS PAIR. The two runs the conclusion audit cannot tell
#            apart -- if a mutant makes allSuccess distinguish them, the whole
#            argument for a second instrument collapses and must be re-made.
#   C09-C10  THE MEASURED WITNESS. Step and checker counts from the real run.
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotCiSkip.lean"
# The module name, DERIVED from F rather than written out a second time.
# Measured 2026-08-10: eight suites grepped for errors in Proofs/RotTrap.lean and
# seven rebuilt Proofs.RotOrdering, both inherited by copy. A second hard-coded
# name is a snapshot waiting to drift -- Proofs/RotSuiteVerdict.lean,
# a_derived_extractor_always_attributes.
MOD=${F##*/}; MOD=${MOD%.lean}
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotCiSkip.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutciskip.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotCiSkip ) >/tmp/mut_pre_rotciskip.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotCiSkip)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotciskip.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotCiSkip ) >/dev/null 2>&1' EXIT

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotCiSkip ) > "$LOG/$id.log" 2>&1
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
    dead=$(grep -oE "^error: Proofs/$MOD.lean:[0-9]+" "$LOG/$id.log" \
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

echo "=== RotCiSkip mutation suite ==="

# Each needle is asserted present EXACTLY once before it is applied, and the
# replacement is asserted present afterwards. A needle that does not match is
# DISCARDED, never SURVIVED.

run_mut C01 'def substantive (s : Step) : Bool := s.success && !s.skipped' 'def substantive (s : Step) : Bool := s.success' 'a step that printed SKIP now counts as having exercised its subject'
run_mut C02 '  | s :: rest => cond (substantive s) 1 0 + covered rest' '  | s :: rest => cond (substantive s) 0 0 + covered rest' 'coverage is structurally zero, so no run can ever be shown to have covered anything'
run_mut C03 '  s.skipped && !(decl.contains s.id)' '  s.skipped && (decl.contains s.id)' 'the budget test is reversed: DECLARING a skip is what raises the alarm'
run_mut C04 '  !(r.any (undeclared decl))' '  true' 'the ratchet never fires -- the exact rubber stamp a_budget_containing_everything warns about'
run_mut C05 'def undeclared (decl : List Nat) (s : Step) : Bool :=' 'def undeclared (_decl : List Nat) (s : Step) : Bool :=' 'the budget parameter is ignored, so a declared skip can no longer be admitted'
run_mut C06 'def allSuccess (r : List Step) : Bool := r.all (fun s => s.success)' 'def allSuccess (r : List Step) : Bool := r.all (fun s => !s.skipped)' 'conclusion auditing silently becomes skip auditing, erasing the gap between the instruments'
run_mut C07 '    allSuccess [⟨1, true, false⟩] = allSuccess [⟨1, true, true⟩] ∧' '    allSuccess [⟨1, true, false⟩] ≠ allSuccess [⟨1, true, true⟩] ∧' 'the blindness claim is inverted -- if this passes, no second instrument is justified'
run_mut C08 '    ratchet [] [⟨1, true, true⟩] = false := by decide' '    ratchet [] [⟨1, true, true⟩] = true := by decide' 'the ratchet is claimed to accept an undeclared skip, destroying the separation result'
run_mut C09 'def measuredRunSteps : Nat := 171' 'def measuredRunSteps : Nat := 3' 'the measured step count is moved below the skipping-checker count it must exceed'
run_mut C10 'def measuredErrorAnnotations : Nat := 0' 'def measuredErrorAnnotations : Nat := 5' 'the run is recorded as carrying real error annotations, contradicting the executed guard'

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
# sweep. Measured 2026-08-09 when C05 survived in mutate_rottrap.sh and the
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

# A FILTERED RUN IS NOT A SUITE RESULT.
#
# MEASURED 2026-08-10: `MUT_ONLY=NOSUCHID` selected no mutant at all, and this
# script printed "All 0 mutants killed (13 ran, 0 survived, 0 discarded)" and
# exited 0. Nothing had run. Both figures in that sentence were false.
#
# `skipped` was counted, folded into $_total, and then never consulted by the
# verdict -- the same second-counter defect CP51 fixed in ci-dryrun.sh and CP52
# fixed in mutate-checker.sh. The repair never reached the per-module suites:
# 21 of the 37 that accept MUT_ONLY behaved this way.
#
# Exit 3 is this repository's skip code and is never a pass. It is placed AFTER
# the survivor and discard tests on purpose, so a real finding is never
# downgraded to a skip -- Proofs/RotSuiteVerdict.lean, a_survivor_outranks_a_skip.
# The whole verdict is proved there: honest_is_never_weaker shows nothing the old
# verdict rejected is now accepted.
if [ "${skipped:-0}" -gt 0 ]; then
  echo "PARTIAL: $skipped of $_total mutant(s) were NOT RUN (MUT_ONLY='${MUT_ONLY:-}')."
  echo "         $killed killed, $survived survived, $discarded discarded, $skipped SKIPPED."
  echo "         A filtered run has not tested this suite. This is exit 3, never a pass."
  exit 3
fi
# RESTORE AND REBUILD -- a suite must leave the tree GREEN.
#
# Each mutant deletes the .olean, and the EXIT trap restores only the SOURCE.
# So without this, a PASSING suite leaves the module uncompiled and the next
# instrument (lake env leanchecker) fails for a reason unrelated to any proof.
# Measured 2026-08-09 on Proofs.RotOrdering.
cp "$BAK" "$F" 2>/dev/null
( cd ${LEAN_ROOT:-.} && lake build Proofs.$MOD ) >/dev/null 2>&1
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
