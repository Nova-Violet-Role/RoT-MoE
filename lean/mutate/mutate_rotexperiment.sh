#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotExperiment.lean (a partial run is not a pass)
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

F="Proofs/RotExperiment.lean"
# The module name, DERIVED from F rather than written out a second time.
# Measured 2026-08-10: eight suites grepped for errors in Proofs/RotTrap.lean and
# seven rebuilt Proofs.RotOrdering, both inherited by copy. A second hard-coded
# name is a snapshot waiting to drift -- Proofs/RotExperiment.lean,
# a_derived_extractor_always_attributes.
MOD=${F##*/}; MOD=${MOD%.lean}
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotExperiment.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutrotexperiment.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotExperiment ) >/tmp/mut_pre_rotexperiment.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotExperiment)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotexperiment.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotExperiment ) >/dev/null 2>&1' EXIT

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotExperiment ) > "$LOG/$id.log" 2>&1
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

echo "=== RotExperiment mutation suite ==="

# Each needle is asserted present EXACTLY once before it is applied, and the
# replacement is asserted present afterwards. A needle that does not match is
# DISCARDED, never SURVIVED.

run_mut X01 "def scoreOf (s : Session) : Nat := score s.trace" "def scoreOf (s : Session) : Nat := (match s.arm with | .routed => 1 | .disarmed => 0) + score s.trace" \
  "score_is_blind -- let the scorer consult the ARM and blinding stops being rfl. This is the mutation the design promised: widening what the scorer can see BREAKS THE BUILD, no runtime check needed"
run_mut X02 "def twoSidedTail (n k : Nat) : Nat := 2 * tail n k" "def twoSidedTail (n k : Nat) : Nat := 1 * tail n k" \
  "the_forty_pair_boundary -- silently making the test one-sided is the classic way to manufacture significance; the boundary must move if the doubling is removed"
run_mut X03 "  if 100 * twoSidedTail n k ≤ 2 ^ n then .supported else .notSupported" "  .supported" \
  "verdict_can_be_negative -- a verdict function that always SUPPORTS satisfies theorem 2 vacuously; non-vacuity is what refutes it"
run_mut X04 "  r.bothOrderings && r.blindedScorer && r.saturated && r.preregistered" "  true" \
  "a_perfect_margin_does_not_rescue_a_defective_run / supported_is_attributable_to_the_arm -- an honesty gate that always passes cannot attribute anything to the arm"
run_mut X05 "def pilotNull : Nat × Nat := (10, 5)" "def pilotNull : Nat × Nat := (10, 0)" \
  "verdict_can_be_negative -- move the null witness to a clean sweep and the non-vacuity check silently becomes a second copy of the positive case"
run_mut X06 "  10 * w.perLoadBearing < w.perFalseGreen &&" "  0 * w.perLoadBearing < w.perFalseGreen &&" \
  "a_false_green_outweighs_ten_theorems_for_every_weighting / a_cheap_false_green_is_not_admissible -- let the family admit a cheap false green and a fabricated success becomes buyable"
run_mut X07 "def scoreW (w : Weights) (a : Artifacts) : Int := (credit w a : Int) - (debit w a : Int)" "def scoreW (w : Weights) (a : Artifacts) : Int := (credit w a : Int) + (debit w a : Int)" \
  "an_unverified_claim_lowers_the_score / extra_cost_lowers_the_score -- turn the debit into a credit and the routed arm wins by emitting more unverified text at greater cost"
run_mut X08 "  w.perLoadBearing * a.loadBearing + w.perNegControl * a.negControls" "  3 * a.decorative + w.perLoadBearing * a.loadBearing + w.perNegControl * a.negControls" \
  "decorative_theorems_earn_nothing -- pay for theorems no mutant kills and the scorer rewards fragmentation, which is the defect the loadBearing gate exists to close"
run_mut X09 "  1 ≤ w.perCostSec && w.perCostSec ≤ w.perLoadBearing" "  0 ≤ w.perCostSec && w.perCostSec ≤ w.perLoadBearing" \
  "free_cost_is_not_admissible / three_times_the_work_at_ten_times_the_cost_loses -- make a second of wall-clock free and the experiment can no longer go negative on cost"
run_mut X10 "  v.nova + v.violet + v.antiVenom + v.venom + v.carnage +" "  v.nova + v.antiVenom + v.venom + v.carnage +" \
  "every_lens_counts_equally / violet_weighs_exactly_what_claude_weighs -- DROP VIOLET FROM THE TOTAL, which is exactly the defect an earlier draft shipped. Nine lenses folded equally is a theorem, not an assurance"
run_mut X11 "  (v.nova < u.nova || v.violet < u.violet || v.antiVenom < u.antiVenom ||" "  (v.nova < u.nova && v.violet < u.violet && v.antiVenom < u.antiVenom ||" \
  "winning_on_violet_alone_is_winning -- require several lenses to improve at once and a profile that wins on Violet alone stops counting as a win"
run_mut X12 "def profileEmpathic : LensVector := ⟨0, 9, 0, 0, 0, 0, 0, 0, 0⟩" "def profileEmpathic : LensVector := ⟨0, 0, 9, 0, 0, 0, 0, 0, 0⟩" \
  "violet_is_not_cosmetic -- collapse the empathic profile onto the cautious one and the witness stops distinguishing the lens it was written to distinguish"

run_mut X13 "  else .incomparable" "  else .better" \
  "a_scalar_tie_is_reported_as_incomparable / better_implies_a_higher_total -- report every non-dominating pair as a WIN. This is the exact defect the three-valued verdict exists to prevent: laundering a projection tie into a finding"
run_mut X14 "  decide (scoreW w b * ((a.costSec : Int) + 1) < scoreW w a * ((b.costSec : Int) + 1))" "  decide (scoreW w a * ((b.costSec : Int) + 1) < scoreW w b * ((a.costSec : Int) + 1))" \
  "integer_division_manufactures_a_tie -- swap the operands of the cross-multiplication and the density verdict inverts, so the direction of the ratio is load-bearing and not a convention"
run_mut X15 "  (e.art.falseGreen == 0) && (e.art.pipedReads == 0)" "  (e.art.pipedReads == 0)" \
  "a_single_false_green_is_refused -- stop checking for false greens in the evidence record. The one unforgivable output would pass the gate that exists to catch it"
run_mut X16 "  (100 * e.comparisons * twoSidedTail e.n e.against ≤ 2 ^ e.n) &&" "  (100 * twoSidedTail e.n e.against ≤ 2 ^ e.n) &&" \
  "the_corrected_boundary_is_nine_of_forty -- drop the multiplicity correction from the computed premise and 10 against out of 40 is admitted, which is the family-wise error the correction was added to close"
run_mut X17 "  (e.corpusHash == e.expectedHash) &&" "  (0 == 0) &&" \
  "a_wrong_corpus_hash_is_refused -- disarm the corpus comparison and any corpus passes, which turns the one hypothesis the checker computes back into an assumption"

run_mut X18 "def tailMinRepair (n k : Nat) : Nat := 2 * tail n (min k (n - k))" "def tailMinRepair (n k : Nat) : Nat := 2 * tail n k" \
  "the_min_repair_would_admit_a_total_loss -- remove the min and the audited repair stops being the repair, so the theorem that REFUTES it no longer refutes anything"
run_mut X19 "  if 100 * m * twoSidedTail n k ≤ 2 ^ n then .supported else .notSupported" "  if 100 * twoSidedTail n k ≤ 2 ^ n then .supported else .notSupported" \
  "twelve_comparisons_do_not_move_the_forty_pair_boundary / a_ten_pair_pilot_cannot_reach_a_corrected_verdict -- drop the family-wise factor and ten of forty is admitted, and a ten-pair pilot starts passing"
run_mut X20 "def tail (n k : Nat) : Nat := ((row n).take (k + 1)).foldl (· + ·) 0" "def tail (n k : Nat) : Nat := ((row n).take k).foldl (· + ·) 0" \
  "the whole tail arithmetic -- an off-by-one in the cumulative sum moves every boundary this file pins, including the audited nine of forty"
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
# downgraded to a skip -- Proofs/RotExperiment.lean, a_survivor_outranks_a_skip.
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
