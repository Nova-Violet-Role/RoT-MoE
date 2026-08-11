#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotProse.lean (a partial run is not a pass)
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

F="Proofs/RotProse.lean"
# The module name, DERIVED from F rather than written out a second time.
# Measured 2026-08-10: eight suites grepped for errors in Proofs/RotTrap.lean and
# seven rebuilt Proofs.RotOrdering, both inherited by copy. A second hard-coded
# name is a snapshot waiting to drift -- Proofs/RotProse.lean,
# a_derived_extractor_always_attributes.
MOD=${F##*/}; MOD=${MOD%.lean}
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotProse.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutrotprose.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotProse ) >/tmp/mut_pre_rotprose.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotProse)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotprose.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotProse ) >/dev/null 2>&1' EXIT

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotProse ) > "$LOG/$id.log" 2>&1
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

echo "=== RotProse mutation suite ==="

# Each needle is asserted present EXACTLY once before it is applied, and the
# replacement is asserted present afterwards. A needle that does not match is
# DISCARDED, never SURVIVED.

run_mut P01 "abbrev Rater := Pair → Choice" "abbrev Rater := Judged → Choice" \
  "the_arm_is_not_in_scope -- widen the rater to see the whole item, arm included. Blinding here is a TYPE, not a promise: give the function the arm and the module stops compiling"
run_mut P02 "  if leftIsRouted then c else swap c" "  if leftIsRouted then c else c" \
  "a_constant_left_picker_counts_only_positions -- stop undoing the presentation flip and a rater who always answers left scores the layout instead of the arms"
run_mut P03 "  if r < l then .left else if l < r then .right else .tie" "  if r < l then .left else if l < r then .right else .left" \
  "an_even_split_is_reported_as_a_tie / abstentions_do_not_become_wins -- break the panel tie toward the routed arm and a split panel manufactures a winner"
run_mut P04 "  !js.isEmpty && js.all (fun j => picked j == longerSide j)" "  js.all (fun j => picked j == longerSide j)" \
  "an_empty_panel_is_not_a_clean_run -- drop the emptiness guard and a run with NO judgements reports as length-confounded-free, which is how absence of evidence becomes evidence"
run_mut P05 "  (e.lengthConfounded == false) &&" "  true &&" \
  "a_length_confounded_run_is_refused -- stop reading the confound flag and a panel whose every pick tracked byte length passes as a prose result"
run_mut P06 "  (e.raters % 2 == 1) && (3 ≤ e.raters) &&" "  (3 ≤ e.raters) &&" \
  "an_even_panel_is_refused -- admit even panels and the majority rule can tie itself, which is a verdict the sign test cannot consume"
run_mut P07 "  (100 * e.comparisons * twoSidedTail e.items e.against ≤ 2 ^ e.items)" "  (100 * twoSidedTail e.items e.against ≤ 2 ^ e.items)" \
  "the_prose_boundary_is_nine_of_forty -- drop the multiplicity correction and ten of forty against is admitted, the same family-wise error the artifact gate closes"
run_mut P08 "  (70 ≤ e.agreeFloor) &&" "  (0 ≤ e.agreeFloor) &&" \
  "a_toothless_floor_is_refused -- allow a 0 percent reliability floor and the agreement check becomes unfalsifiable while still appearing in the record"
run_mut P09 "  | .tie => .tie" "  | .tie => .left" \
  "swap_involutive / normalise_preserves_ties -- make the position swap turn a tie into a win and unflipping stops being an exact undo, which silently converts abstentions into routed-arm preferences"
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
# downgraded to a skip -- Proofs/RotProse.lean, a_survivor_outranks_a_skip.
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
