#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotAttribute.lean (a null can belong to the analysis, not the world)
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
# WHAT THIS SUITE IS AIMED AT. RotAttribute states why the round-1 A/B verdict
# was wrong, and every mutant below breaks one of those reasons. If a mutant
# actually wrong, while installing 0.8.2 into CTT on 2026-08-06. So every mutant
# below RE-INSTALLS one of those wrong beliefs as if it were the definition:
#
#   M01  armedness is whatever settings.json says   ("the install did nothing")
#   M02  the arm guard is deleted                   (double registration returns)
#   M03  double-binding means EITHER path bound it  (the guard stops guarding)
#   M04  a pipeline reports its FIRST stage         ("$? is the tool's status")
#   M05  the bare plugin name resolves              ("not found" == not installed)
#   M06  the marker count IS the firing count       ("0 markers, so it never ran")
#   M07  the seal is inverted                       (a leak counts as sealed)
#   M08  firings are counted from the transcript    (the same conflation, mirrored)
#
# If a mutant SURVIVES, the corresponding theorem was decorative and the belief
# it was written to refute can walk back in unnoticed.
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotAttribute.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotAttribute.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutsymb.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotAttribute ) >/tmp/mut_pre_rotsymbiogenesis.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotAttribute)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotsymbiogenesis.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotAttribute ) >/dev/null 2>&1' EXIT

killed=0; survived=0; discarded=0

# --- OPTIONAL FILTER, AND WHY A PARTIAL RUN MUST LOOK PARTIAL ----------------
# The suite is 9 mutants and each one rebuilds the module, so a full pass
# outgrew the wall-clock ceiling of the agent that runs it -- and MEASURED
# 2026-08-07, being killed at that ceiling left a MUTATED RotAttribute.lean on
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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotAttribute ) > "$LOG/$id.log" 2>&1
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
    dead=$(grep -oE "^error: Proofs/RotAttribute\.lean:[0-9]+" "$LOG/$id.log" \
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

echo "=== RotAttribute mutation suite ==="

# --- §1 the operator IS the spec's --------------------------------------------

# S01 -- the novelty term is deleted. A hybrid would then sit at its parents'
# entropy: fusion stops generating anything and the whole module is fiction.
# A01 -- erasure keeps the lane after all. If the corpus had carried the lane,
# there would have been nothing to prove; the theorem that the information is
# unreachable must die.
run_mut A01 \
  'def erase (s : Sample) : ℚ := s.value' \
  'def erase (s : Sample) : ℚ := (s.lane : ℚ)' \
  'erasure_hides_information_a_lane_aware_reading_has, erasure_loses_a_real_distinction'

# A02 -- the lane-aware reading is blinded too: `lanes` returns a constant, so
# stratifying buys nothing. The whole argument for per-lane scoring collapses.
run_mut A02 \
  'def lanes (d : List Sample) : List Nat := d.map Sample.lane' \
  'def lanes (d : List Sample) : List Nat := d.map (fun _ => 0)' \
  'erasure_hides_information_a_lane_aware_reading_has'

# A03 -- routed stops winning lane 1. The Simpson instance needs BOTH strata to
# favour routed; if one does not, the paradox is not demonstrated.
run_mut A03 \
  'def lane1Routed : List ℚ := [10]' \
  'def lane1Routed : List ℚ := [30]' \
  'routed_wins_lane1, stratified_and_pooled_disagree'

# A04 -- routed stops winning lane 2, the other half of the same requirement.
run_mut A04 \
  'def lane2Control : List ℚ := [110]' \
  'def lane2Control : List ℚ := [90]' \
  'routed_wins_lane2, stratified_and_pooled_disagree'

# A05 -- THE CAUSE, NOT THE EFFECT. This mutant has a history worth keeping.
#
# Its first form shrank `lane1Control` from nine turns to one, expecting the
# Simpson reversal to collapse. It SURVIVED (measured 2026-08-07), and the
# survival was correct: a one-sided rebalance does not remove the imbalance, it
# moves it to the other arm, so the reversal persists. The mutant had been
# written against what I assumed the instance depended on rather than what it
# actually depends on.
#
# The repair was to the MODULE, not to this suite's bookkeeping: the balanced
# control `balanced_pooling_agrees_with_the_strata` was added, which pins the
# reversal on unequal stratum sizes by exhibiting the same values with equal
# ones. A05 now breaks THAT balance -- nine routed turns in lane 1 back down to
# one -- so the pooled verdict flips and the control must die.
#
# If A05 ever survives again, the module is demonstrating a paradox without
# demonstrating its cause, which is where it started.
run_mut A05 \
  'def lane1RoutedBal : List ℚ := [10, 10, 10, 10, 10, 10, 10, 10, 10]' \
  'def lane1RoutedBal : List ℚ := [10]' \
  'balanced_pooling_agrees_with_the_strata'

# A06 -- `mean` stops dividing by the count and becomes a SUM. A summary that
# ignores group size cannot exhibit the paradox honestly.
run_mut A06 \
  'def mean (xs : List ℚ) : ℚ := xs.sum / xs.length' \
  'def mean (xs : List ℚ) : ℚ := xs.sum' \
  'routed_wins_lane1, pooling_reverses_every_stratum'

# A07 -- the projection is widened to include the token count. Then the
# primaries CANNOT tie while the turn differs, and the third failure shape --
# the one that actually produced the false null -- is no longer stated.
run_mut A07 \
  'def primaries (t : Turn) : Nat × Nat := (t.q, t.narr)' \
  'def primaries (t : Turn) : Nat × Nat := (t.q, t.outTok)' \
  'primaries_can_tie_while_the_turn_differs'

# A08 -- the measured direction is flipped: routed is recorded as emitting MORE
# tokens than the control. This is the mutant that guards the number itself, so
# a later edit cannot quietly reverse what the experiment found.
run_mut A08 \
  'def measuredRoutedMeanTokens : Nat := 440' \
  'def measuredRoutedMeanTokens : Nat := 700' \
  'measured_routed_emits_fewer_tokens'

# A09 -- the two measured means are made equal. A tie is precisely the verdict
# round 1 published, so if this survives the module cannot tell the corrected
# result from the wrong one.
run_mut A09 \
  'def measuredControlMeanTokens : Nat := 675' \
  'def measuredControlMeanTokens : Nat := 440' \
  'measured_routed_emits_fewer_tokens'

# --- SECTION 5: lane coverage and the refuted universal ----------------------
# These exist because section 5 is proved ENTIRELY by `decide` over closed
# data, so every theorem in it reports `does not depend on any axioms`. An
# empty axiom list is NOT evidence of strength -- it is what a computation
# looks like. Mutation is the only instrument that separates a load-bearing
# decide from a decorative one, so each mutant breaks one datum and names the
# theorem that must notice.

run_mut A10 \
  '{ name := "EMPATHIC",   n := 4,  routed := 256, control := 220 } ]' \
  '{ name := "EMPATHIC",   n := 4,  routed := 256, control := 999 } ]' \
  'not_every_lane_shrinks'

# Make EMPATHIC shrink and the one lane refuting the universal is gone, so
# the false claim -- the router shortens EVERY lane -- becomes provable.

run_mut A11 \
  'def scored (r : LaneResult) : Bool := 0 < r.n' \
  'def scored (r : LaneResult) : Bool := true' \
  'an_unsampled_lane_is_not_scored'

# A lane with zero samples would report as scored: precisely the overclaim
# the per-lane checker FAIL exists to prevent.

run_mut A12 \
  '(rs.filter (fun r => decide (r.routed < r.control))).length' \
  '(rs.filter (fun r => decide (r.control < r.routed))).length' \
  'nine_lanes_shrink'

run_mut A13 \
  '{ name := "EMPATHIC",   n := 4,  routed := 256, control := 220 } ]' \
  '{ name := "EMPATHIC",   n := 0,  routed := 256, control := 220 } ]' \
  'every_measured_lane_is_scored'

# A13 is the CI failure reproduced in Lean: a lane present in the table with
# no prompts behind it. The first per-lane run hit exactly this on EMPATHIC
# and STRATEGIC, and it was closed by MEASURING, not by relaxing the check.

run_mut A14 \
  '  have := h r hr' \
  '  clear h; have : True := trivial' \
  'a_report_covers_exactly_what_it_sampled'

# A14 removes the coverage hypothesis from the proof that USES it. If the
# theorem still closes, the hypothesis was decoration.


echo
printf 'restoring baseline artifact ... '
if ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotAttribute ) >"$LOG/restore.log" 2>&1; then
  echo "OK (baseline rebuilt, .olean present)"
else
  echo "FAILED -- the restored source does NOT build. The tree is left BROKEN."
  echo "         Run: git checkout HEAD -- $F"
  tail -5 "$LOG/restore.log"
  exit 2
fi

echo
if [ "$filtered" -eq 1 ]; then
  echo "=== RotAttribute: PARTIAL RUN (MUT_ONLY='$MUT_ONLY') -- $killed killed, $survived survived, $discarded discarded, $skipped SKIPPED ==="
  echo "NOT a suite result. $skipped mutants were never applied and prove nothing."
  [ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && exit 3
  exit 1
fi
echo "=== RotAttribute: $killed killed, $survived survived, $discarded discarded ==="
[ "$discarded" -gt 0 ] && echo "NOTE: discarded mutants tested NOTHING -- fix the needles, do not count them as survivors."
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && exit 0
exit 1
