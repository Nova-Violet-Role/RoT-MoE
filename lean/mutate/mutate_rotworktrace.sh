#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotWorkTrace.lean (why one ordering cannot attribute)
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
# WHAT THIS SUITE IS AIMED AT. The module constrains what bench/work-trace.js
# is ALLOWED TO CONCLUDE. Its subject is an instrument that fails in the
# reassuring direction: O4 asks "does this claim appear anywhere in the tool
# output", and on a long session the output is megabytes, so every short number
# matches by accident and the detector reports a clean 0 it did not earn.
# Measured 2026-08-10: 42.2% of fabricated claims are "confirmed" by chance on a
# 2.68 MB transcript, 24.0% at 1.20 MB, 3.0% at 152 KB.
#
# A blind instrument that reports 0 is a false green, so the mutants attack the
# machinery that makes blindness DETECTABLE and REFUSED:
#
#   W01-W04  THE COUNTERS. Flagging inverted, or a counter that never counts.
#            If these survive, every number the extractor prints is arithmetic
#            on nothing.
#   W05      THE GATE. The saturated fallback returns 'clean' instead of
#            'noVerdict' -- precisely the false green
#            a_saturated_haystack_is_never_clean forbids.
#   W06-W08  DISTINCTNESS AND ORDER. Stop deduplicating, keep counting reads
#            after the first write, or make rework structurally zero. These are
#            O2 and O3, and each mutation makes the routed arm look tidier.
#   W09-W10  THE BOTH-DIRECTIONS CONTROL. W10 is the sharp one: it makes the
#            loosened detector honest, which no positive fixture can notice.
#            Only the negative-direction theorem can kill it.
#   W11-W12  THE MEASURED WITNESS. 42.2% is real data and 10% is the threshold
#            it is compared against; move either and the executed #guards must
#            notice.
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotWorkTrace.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotWorkTrace.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutworktrace.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotWorkTrace ) >/tmp/mut_pre_rotworktrace.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotWorkTrace)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotworktrace.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotWorkTrace ) >/dev/null 2>&1' EXIT

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotWorkTrace ) > "$LOG/$id.log" 2>&1
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
    dead=$(grep -oE "^error: Proofs/RotTrap\.lean:[0-9]+" "$LOG/$id.log" \
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

echo "=== RotWorkTrace mutation suite ==="

# Each needle is asserted present EXACTLY once before it is applied, and the
# replacement is asserted present afterwards. A needle that does not match is
# DISCARDED, never SURVIVED.

run_mut W01 'def flagged (evidence : List Nat) (c : Nat) : Bool := !(evidence.contains c)' 'def flagged (evidence : List Nat) (c : Nat) : Bool := evidence.contains c' 'flagging inverted -- a claim counts as unsupported exactly when the evidence DOES support it'
run_mut W02 '  decide (10 * confirmed e probes ≤ probes.length)' '  decide (1 * confirmed e probes ≤ probes.length)' 'the 10% usability bar drops to 100%, so a fully saturated haystack is declared usable'
run_mut W03 '  | c :: rest => cond (flagged evidence c) 1 0 + countFlags evidence rest' '  | c :: rest => cond (flagged evidence c) 0 0 + countFlags evidence rest' 'O4 never counts anything: every transcript reports zero unsupported claims'
run_mut W04 '  | p :: rest => cond (e.contains p) 1 0 + confirmed e rest' '  | p :: rest => cond (e.contains p) 0 0 + confirmed e rest' 'the chance-confirmation probe always reads zero, so saturation can never be detected'
run_mut W05 '  else Verdict.noVerdict' '  else Verdict.clean' 'the saturated fallback reports CLEAN -- the exact false green the gate exists to prevent'
run_mut W06 '  | x :: xs => if xs.contains x then dedup xs else x :: dedup xs' '  | x :: xs => x :: dedup xs' 'deduplication removed, so re-reading one file inflates O3 and rework stops being visible'
run_mut W07 '  | Ev.write _ :: _ => []' '  | Ev.write _ :: rest => readsBefore rest' 'reads AFTER the first write keep counting -- O3 stops meaning read-before-you-write'
run_mut W08 'def rework (writes : List Nat) : Nat := writes.length - (dedup writes).length' 'def rework (writes : List Nat) : Nat := (dedup writes).length - writes.length' 'rework is now structurally zero on every input: truncated subtraction hides all repeats'
run_mut W09 'def isVerification (cmd : Nat) : Bool := cmd == 1' 'def isVerification (cmd : Nat) : Bool := cmd == 0' 'the verification predicate answers about the wrong command, inverting both control theorems'
run_mut W10 'def loosened (_ : Nat) : Bool := true' 'def loosened (cmd : Nat) : Bool := cmd == 1' 'the loosened detector is made honest -- only the NEGATIVE-direction theorem can notice this'
run_mut W11 'def measuredLongSession : Nat := 422' 'def measuredLongSession : Nat := 42' 'the measured 42.2% saturation rate is moved below the threshold it is supposed to exceed'
run_mut W12 'def usableThreshold : Nat := 100' 'def usableThreshold : Nat := 900' 'the usability threshold is raised until the measured saturation no longer counts as saturated'

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
# RESTORE AND REBUILD -- a suite must leave the tree GREEN.
#
# Each mutant deletes the .olean, and the EXIT trap restores only the SOURCE.
# So without this, a PASSING suite leaves the module uncompiled and the next
# instrument (lake env leanchecker) fails for a reason unrelated to any proof.
# Measured 2026-08-09 on Proofs.RotOrdering.
cp "$BAK" "$F" 2>/dev/null
( cd ${LEAN_ROOT:-.} && lake build Proofs.RotOrdering ) >/dev/null 2>&1
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
