#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotFamily.lean (a partial run is not a pass)
#
#   1. assert the needle is present EXACTLY once before mutating; else DISCARDED
#   2. assert the mutation LANDED after patching
#   3. delete the stale .olean so Lake cannot skip the rebuild
#   4. rebuild, read the exit code DIRECTLY
#   5. restore from the backup, always
#
# DISCARDED != SURVIVED.
#
# AIMED AT a fake green measured in shipped code on 2026-08-10:
# `checker/ci-dryrun.sh --from 9999` windowed out ALL 75 CI steps, printed an
# honest PARTIAL paragraph, and then exited 0 with "ci-dryrun: PASS". The prose
# was right and the exit code was wrong -- and gate-all.sh reads the exit code.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotFamily.lean"
# The module name, DERIVED from F rather than written out a second time.
# Measured 2026-08-10: eight suites grepped for errors in Proofs/RotTrap.lean and
# seven rebuilt Proofs.RotOrdering, both inherited by copy. A second hard-coded
# name is a snapshot waiting to drift -- Proofs/RotSuiteVerdict.lean,
# a_derived_extractor_always_attributes.
MOD=${F##*/}; MOD=${MOD%.lean}
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotFamily.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutrotfamily.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotFamily ) >/tmp/mut_pre_rotfamily.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotFamily)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotfamily.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotFamily ) >/dev/null 2>&1' EXIT

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotFamily ) > "$LOG/$id.log" 2>&1
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

echo "=== RotFamily mutation suite ==="

# Each needle is asserted present EXACTLY once before it is applied, and the
# replacement is asserted present afterwards. A needle that does not match is
# DISCARDED, never SURVIVED.

run_mut M01 "  , (\"O5 task success\",               .sideCondition)" "  , (\"O5 task success\",               .twoSidedTest)" \
  "the_family_size_is_derived_not_chosen, the_side_condition_is_not_a_test -- promote the non-inferiority side condition to a test of its own and m becomes 5; over-correcting is not the safe direction, it buries a real effect while looking rigorous"
run_mut M02 "  , (\"O6 lens breadth and lead\",      .descriptive)" "  , (\"O6 lens breadth and lead\",      .twoSidedTest)" \
  "the_family_size_is_derived_not_chosen, descriptive_observables_do_not_inflate_the_family -- section 3 declares O6 descriptive; spending alpha on something never claimed is the inflation this theorem exists to refuse"
run_mut M03 "def m : Nat := (observables.filter (fun o => o.2 == Role.twoSidedTest)).length" "def m : Nat := 12" \
  "the_family_size_is_derived_not_chosen, adding_a_test_raises_the_family_size, retagging_a_test_as_descriptive_lowers_the_family_size -- THE mutant for this module: hard-code m and it stops tracking the observable table, which is exactly the unsettled state the pilot was blocked on"
run_mut M04 "def symmetricTail (n k : Nat) : Nat := 2 * min (tail n k) (tail n (n - k))" "def symmetricTail (n k : Nat) : Nat := 2 * tail n k" \
  "the_symmetric_repair_would_admit_a_total_loss -- collapse the symmetric statistic back onto the directional one and the refutation has nothing to refute; the case for keeping twoSidedTail asymmetric would rest on prose alone"
run_mut M05 "  else if verdictM m n (n - k) = Verdict.supported then .contradicted" "  else if verdictM m n k = Verdict.supported then .contradicted" \
  "a_thirty_one_of_forty_defeat_was_reported_as_a_null, all_three_outcomes_are_reachable, a_total_loss_is_contradicted -- test the same side twice and CONTRADICTED becomes unreachable, restoring the two-outcome rule that section 7 forbids"
run_mut M06 "  if verdictM m n k = Verdict.supported then .supported" "  if verdictM 1 n k = Verdict.supported then .supported" \
  "the_new_rule_agrees_wherever_the_old_one_spoke -- drop the correction from the first branch only: the three-way rule would then report SUPPORTED at k=11 where the corrected two-way rule says notSupported, so the refinement claim would be false"
run_mut M07 "    (m₁ m₂ n k : Nat) (hm : m₁ ≤ m₂) (h : verdictM m₂ n k = Verdict.supported) :" "    (m₁ m₂ n k : Nat) (hm : m₂ ≤ m₁) (h : verdictM m₂ n k = Verdict.supported) :" \
  "a_larger_family_is_never_more_permissive -- reverse the hypothesis and the monotonicity claim points the wrong way; if this still built, the ordering assumption was carrying no weight"
run_mut M08 ").getLast? = some 10 := by decide" ").getLast? = some 9 := by decide" \
  "the_forty_pair_boundary_at_the_settled_family, the_smallest_admissible_pilot_is_ten_pairs -- move the boundary literal by one. This mutant is why both theorems are stated as the LARGEST supported k and the SMALLEST admissible n: in their original witness-pair form (10 supported AND 11 not) the same edit produced a weaker statement that still built, so the mutant would have SURVIVED and the theorem name would have overclaimed"
run_mut M09 "    (∃ h, h ≤ outOf ∧ admissibleBy mg ⟨h, outOf⟩ = true) ↔ 2 * mg ≤ outOf := by" "    (∃ h, h ≤ outOf ∧ admissibleBy mg ⟨h, outOf⟩ = true) ↔ mg ≤ outOf := by" \
  "a_margin_is_reachable_iff_the_pilot_is_twice_its_size, the_preregistered_gate_admitted_no_outcome -- drop the factor of two and the reachability condition becomes the obvious-looking mg <= outOf, which is exactly the reading under which the preregistered margin 8 on a 10-task pilot looks satisfiable. This is the mutant that reproduces the original defect"
run_mut M10 "    admissibleBy 8 ⟨3, 12⟩ = false ∧ admissibleBy 8 ⟨1, 12⟩ = false := by decide" "    admissibleBy 8 ⟨3, 12⟩ = true ∧ admissibleBy 8 ⟨1, 12⟩ = true := by decide" \
  "the_measured_pilot_is_inadmissible -- claim the measured pilot passed the gate. The one mutation a reader most needs to fail, because a green build under this statement would mean the record of what was observed had drifted from the observation"

run_mut M11 "def marginFor (outOf : Nat) : Nat := outOf / 5" "def marginFor (outOf : Nat) : Nat := outOf / 10" \
  "the_margin_was_a_fraction_of_the_corpus_not_an_absolute, the_corpus_is_refused_and_must_be_rebuilt -- loosen the fraction to a tenth. This is the CONVENIENT mutation: it is the one setting under which the measured pilot passes, and marginFor 40 would be 4 instead of the preregistered 8. If this ever survives, the margin has stopped tracking the document it came from"
run_mut M12 "  admissibleBy mg a && admissibleBy mg b" "  admissibleBy mg a" \
  "the_corpus_is_refused_and_must_be_rebuilt -- judge admissibility on the routed arm alone. The routed arm passes, so this mutation turns a refused corpus into an admitted one while changing nothing about the data; a corpus the unrouted arm always fails cannot show a difference between the arms"

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
