#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotSaturation.lean (why one ordering cannot attribute)
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
# WHAT THIS SUITE IS AIMED AT. The module decides, BEFORE an A/B run costs
# money, whether a corpus is even capable of expressing a difference. Two of the
# five nulls this project recorded were structurally guaranteed: 84/84 sat on
# the ceiling and 1/80 sat against the floor.
#
# The danger with a gate like this is the opposite of a false red -- it is a
# predicate quietly loosened until everything passes, which turns a refusal into
# a rubber stamp. So the mutants attack the LOOSENING direction hardest:
#
#   S01-S04  THE PRIMITIVES. Headroom reversed, the wrong end measured, the
#            ceiling test inverted. If these survive, every verdict below is
#            arithmetic on the wrong numbers.
#   S05-S06  THE CONJUNCTION. Accept a corpus with room in only ONE direction.
#            That is exactly the corpus that can show a win and never a loss --
#            the shape 'headroom_admits_regression' exists to forbid.
#   S07-S08  THE PARAMETERS. Validity inverted, and the pre-registered margin
#            set to 0 -- the 'instrument that cannot fail' that
#            margin_zero_admits_everything states as a theorem.
#   S09-S10  CIRCULAR SELECTION. Stop selecting, or score the wrong half. If
#            these survive, the module cannot detect a task set chosen because
#            the router already won on it.
#   S11      THE MEASURED WITNESS. 84/84 is real data; move it and the executed
#            #guards must notice.
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotSaturation.lean"
# The module name, DERIVED from F rather than written out a second time.
# Measured 2026-08-10: eight suites grepped for errors in Proofs/RotTrap.lean and
# seven rebuilt Proofs.RotOrdering, both inherited by copy. A second hard-coded
# name is a snapshot waiting to drift -- Proofs/RotSuiteVerdict.lean,
# a_derived_extractor_always_attributes.
MOD=${F##*/}; MOD=${MOD%.lean}
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotSaturation.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutsaturation.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotSaturation ) >/tmp/mut_pre_rotsaturation.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotSaturation)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotsaturation.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotSaturation ) >/dev/null 2>&1' EXIT

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotSaturation ) > "$LOG/$id.log" 2>&1
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

echo "=== RotSaturation mutation suite ==="

# Each needle is asserted present EXACTLY once before it is applied, and the
# replacement is asserted present afterwards. A needle that does not match is
# DISCARDED, never SURVIVED.

run_mut S01 'def up (s : Score) : Nat := s.outOf - s.hits' 'def up (s : Score) : Nat := s.hits - s.outOf' 'headroom measured from the wrong end -- a full corpus would look like it had room'
run_mut S02 'def down (s : Score) : Nat := s.hits' 'def down (s : Score) : Nat := s.outOf' 'room to regress reads the denominator, so a corpus at the floor looks safe to run'
run_mut S03 'def atCeiling (s : Score) : Bool := s.outOf ≤ s.hits' 'def atCeiling (s : Score) : Bool := s.hits ≤ s.outOf' 'the ceiling test becomes true for EVERY valid score -- saturation stops being detectable'
run_mut S04 'def atFloor (s : Score) : Bool := s.hits == 0' 'def atFloor (s : Score) : Bool := s.outOf == 0' 'the floor test reads the denominator -- a 0/80 corpus no longer registers as pinned'
run_mut S05 'decide (m ≤ up p) && decide (m ≤ down p)' 'decide (m ≤ up p) || decide (m ≤ down p)' 'room in ONE direction is accepted -- admits the corpus that can only show a win'
run_mut S06 'decide (m ≤ up p) && decide (m ≤ down p)' 'decide (m ≤ up p) && decide (0 ≤ down p)' 'the regression half of the gate is neutered while still LOOKING like a conjunction'
run_mut S07 'def valid (s : Score) : Bool := s.hits ≤ s.outOf' 'def valid (s : Score) : Bool := s.outOf ≤ s.hits' 'validity inverted -- every theorem carrying it as a hypothesis changes meaning'
run_mut S08 'def preregMargin : Nat := 8' 'def preregMargin : Nat := 0' 'the pre-registered margin set to zero: the gate admits everything, including 84/84'
run_mut S09 'def selectWinners (ts : List Trial) : List Trial := ts.filter (fun t => t.routedWins)' 'def selectWinners (ts : List Trial) : List Trial := ts' 'selection stops selecting -- the circularity the module exists to catch disappears'
run_mut S10 '⟨(ts.filter (fun t => t.routedWins)).length, ts.length⟩' '⟨(ts.filter (fun t => !t.routedWins)).length, ts.length⟩' 'the win rate counts losses -- the circular-selection proof is scoring the wrong half'
run_mut S11 'def factCorpus : Score := ⟨84, 84⟩' 'def factCorpus : Score := ⟨84, 85⟩' 'the measured 84/84 witness is moved off the ceiling -- the executed guards must notice'

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
