#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotGuard.lean (a guard that fails open, and a diagnosis that was invented)
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
# WHAT THIS SUITE IS AIMED AT. RotGuard states why the round-1 A/B verdict
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

F="Proofs/RotGuard.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotGuard.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutcite.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotGuard ) >/tmp/mut_pre_rotguard.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotGuard)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotguard.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotGuard ) >/dev/null 2>&1' EXIT

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotGuard ) > "$LOG/$id.log" 2>&1
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
    dead=$(grep -oE "^error: Proofs/RotGuard\.lean:[0-9]+" "$LOG/$id.log" \
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

echo "=== RotGuard mutation suite ==="

# --- §1 the operator IS the spec's --------------------------------------------

# S01 -- the novelty term is deleted. A hybrid would then sit at its parents'
# entropy: fusion stops generating anything and the whole module is fiction.
# A01 -- erasure keeps the lane after all. If the corpus had carried the lane,
# there would have been nothing to prove; the theorem that the information is
# unreachable must die.

# --- mutants ------------------------------------------------------------------
# Every theorem in RotGuard is proved by decide or a two-line simp over
# closed data, so most report `does not depend on any axioms`. That is not
# strength; it is what a computation looks like. These mutants are the only
# instrument that can tell a load-bearing decide from a decorative one.

# If an unwritable log still yielded its records, the ambiguity would not
# exist -- and the whole module would be describing a problem it does not have.
# Everything is publishable -- the stamp stops meaning anything and a local
# build can be tagged. This is the mutant the whole file exists to catch.
# The floor conjunct is dropped, so a gate with ZERO citations passes: the
# extractor goes blind and the report says the page was verified. This is the
# quiet failure the whole module exists to forbid.
# P01: cnt counts every firing regardless of lane -- no lane can lead another
# U01: install overwrites an existing entry -- the measured no-op branch is gone
# S01: breach reverts to the old conflated count -- a mention becomes a violation again
# E01: the win direction is flipped -- fewer counts stops meaning better
# G01: the repaired guard fails open again -- malformed becomes proceed
run_mut G01 \
  '  | Parsed.malformed => Verdict.refuse' \
  '  | Parsed.malformed => Verdict.proceed' \
  'the repaired guard fails open again -- malformed becomes proceed'

# G02: the old guard is quietly improved so the defect no longer shows
run_mut G02 \
  '  | Parsed.malformed => Verdict.proceed' \
  '  | Parsed.malformed => Verdict.tooFew' \
  'the old guard is quietly improved so the defect no longer shows'

# G03: the two-token reading becomes well formed -- the bug that occurred stops existing
run_mut G03 \
  'def theMeasuredReading : Reading := ["0", "0"]' \
  'def theMeasuredReading : Reading := ["0"]' \
  'the two-token reading becomes well formed -- the bug that occurred stops existing'

# G04: the repaired mapping conflates the two causes again
run_mut G04 \
  '  | Outcome.unreachable _ => Message.apiDown' \
  '  | Outcome.unreachable _ => Message.notPushed' \
  'the repaired mapping conflates the two causes again'

# G05: an unreachable API stops counting as a skip -- it would read as a verdict
run_mut G05 \
  '  | Message.apiDown => true' \
  '  | Message.apiDown => false' \
  'an unreachable API stops counting as a skip -- it would read as a verdict'

# G06: every reading is malformed -- the guard refuses even healthy payloads
run_mut G06 \
  '  | [_] => Parsed.count value' \
  '  | [_] => Parsed.malformed' \
  'every reading is malformed -- the guard refuses even healthy payloads'

# G07: the indirect read is quietly made correct -- the defect stops existing
run_mut G07 \
  'def readAfter (_cmd interloper : Ran) : Nat := interloper.status' \
  'def readAfter (_cmd interloper : Ran) : Nat := _cmd.status' \
  'the indirect read is quietly made correct -- the defect stops existing'

# G08: the gate that failed is recorded as having passed
run_mut G08 \
  'def theGate : Ran := { name := "repo-complete", status := 1 }' \
  'def theGate : Ran := { name := "repo-complete", status := 0 }' \
  'the gate that failed is recorded as having passed'

# G09: honesty is redefined as reporting zero -- a green is always honest
run_mut G09 \
  'def honest (cmd : Ran) (reading : Nat) : Bool := reading == cmd.status' \
  'def honest (cmd : Ran) (reading : Nat) : Bool := reading == 0' \
  'honesty is redefined as reporting zero -- a green is always honest'

# G10: the independent log agrees with the broken harness -- no contradiction left
run_mut G10 \
  'def logSaysFailed : Nat := 5' \
  'def logSaysFailed : Nat := 0' \
  'the independent log agrees with the broken harness -- no contradiction left'

# G11: a timeout is classified as a rejection again -- the original defect
run_mut G11 \
  '  | Reason.timeout      => Kernel.unfinished' \
  '  | Reason.timeout      => Kernel.rejected' \
  'a timeout is classified as a rejection again -- the original defect'

# G12: an unknown failure reason is quietly demoted instead of shouting
run_mut G12 \
  '  | Reason.unrecognised => Kernel.rejected' \
  '  | Reason.unrecognised => Kernel.unfinished' \
  'an unknown failure reason is quietly demoted instead of shouting'

# G13: a real kernel rejection stops accusing the proof
run_mut G13 \
  '  | Kernel.rejected => true' \
  '  | Kernel.rejected => false' \
  'a real kernel rejection stops accusing the proof'

# G14: the old reader is rewritten as if it had been right all along
run_mut G14 \
  'def oldClassify (_r : Reason) : Kernel := Kernel.rejected' \
  'def oldClassify (_r : Reason) : Kernel := Kernel.unfinished' \
  'the old reader is rewritten as if it had been right all along'

printf '


restoring baseline artifact ... '
if ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotGuard ) >"$LOG/restore.log" 2>&1; then
  echo "OK (baseline rebuilt, .olean present)"
else
  echo "FAILED -- the restored source does NOT build. The tree is left BROKEN."
  echo "         Run: git checkout HEAD -- $F"
  tail -5 "$LOG/restore.log"
  exit 2
fi

echo
if [ "$filtered" -eq 1 ]; then
  echo "=== RotGuard: PARTIAL RUN (MUT_ONLY='$MUT_ONLY') -- $killed killed, $survived survived, $discarded discarded, $skipped SKIPPED ==="
  echo "NOT a suite result. $skipped mutants were never applied and prove nothing."
  [ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && exit 3
  exit 1
fi
echo "=== RotGuard: $killed killed, $survived survived, $discarded discarded ==="
[ "$discarded" -gt 0 ] && echo "NOTE: discarded mutants tested NOTHING -- fix the needles, do not count them as survivors."
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && exit 0
exit 1
