#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotSessionLog.lean (a session id that reaches a filename)
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
# WHAT THIS SUITE IS AIMED AT. The module makes two kinds of claim and the
# mutants are split to match. S01-S06 attack the SCRUBBER, whose whole purpose
# is that a payload value landing in a filename cannot escape its directory;
# each one re-admits a character the proofs say is gone, or removes the
# fallback, or disarms the function entirely. S07-S11 attack PROVENANCE and
# ENABLEMENT -- the fields that make live traffic countable and keep the router
# out of a repository whose owner said no.
#
# The one to watch is S07. It makes a declared harness record classify as live
# traffic, which is precisely the contamination that made 738 of 955 records in
# the real log unattributable. If test_is_never_hook does not die on S07, that
# theorem is decoration.
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotSessionLog.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotSessionLog.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutsesslog.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotSessionLog ) >/tmp/mut_pre_rotsesslog.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotSessionLog)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotsesslog.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotSessionLog ) >/dev/null 2>&1' EXIT

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotSessionLog ) > "$LOG/$id.log" 2>&1
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
    dead=$(grep -oE "^error: Proofs/RotSessionLog\.lean:[0-9]+" "$LOG/$id.log" \
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

echo "=== RotSessionLog mutation suite ==="

# Each mutant RE-INSTALLS a wrong belief that the live SessionEnd failure
# exposed, and states it as if it were the definition. If one survives, the
# theorem written to refute it is decorative and the belief can walk back in.
#
#   I01  the rejecting event is accepted after all  ("wired means allowed")
#   I02  every event accepts context                (the pre-fix behaviour)
#   I03  no event emits at all                      (the DISARMING "fix")
#   I04  a typo'd event name                        (silent loss of a good lane)
#   I05  a real event that does not accept context  (plausible-looking wrong entry)
#   I06  the busiest working lane is dropped        (partial disarm)
#   I07  the label is hardcoded again               (the older, worse defect)
#   I08  accepting == every dispatched event        ("31 wired, 31 accept")
#   I09  a duplicated entry hiding a dropped one    (drift between model and array)

# I01 -- SessionEnd, the event MEASURED to reject additionalContext, is admitted.
# This is the exact belief the CLI disproved with "Invalid input".

# --- S01-S06: the scrubber ---------------------------------------------------
# Each re-admits a character the proofs say cannot survive, or removes the
# fallback, or disarms the function outright.
#
# NOTE ON ORDERING: the new disjunct goes BEFORE the dash, not after. With it
# after, the replacement CONTAINS the needle as a substring, the post-check can
# never see the needle gone, and all three mutants report DISCARDED -- which is
# a fault in this harness and not a claim about any theorem. Measured: S01-S03
# discarded on the first run for exactly that reason.

run_mut S01 \
  "  c.isAlphanum || c == '-'" \
  "  c.isAlphanum || c == '/' || c == '-'" \
  "no_forward_slash -- a session id could now contain a path separator"

run_mut S02 \
  "  c.isAlphanum || c == '-'" \
  "  c.isAlphanum || c == '.' || c == '-'" \
  "no_dot -- '..' becomes constructible again, which is the traversal"

run_mut S03 \
  "  c.isAlphanum || c == '-'" \
  "  c.isAlphanum || c == '_' || c == '-'" \
  "the alphabet #guards -- widening isSafeChar by one non-alphanumeric char"

run_mut S04 \
  '  if (keptChars s).isEmpty then "unknown" else String.ofList (keptChars s)' \
  '  if (keptChars s).isEmpty then "" else String.ofList (keptChars s)' \
  "sanitise_never_empty -- the path would collapse onto the directory itself"

run_mut S05 \
  "  (s.toList.filter isSafeChar).take maxLen" \
  "  (s.toList.filter isSafeChar)" \
  "sanitise_is_bounded -- an unbounded id can exceed the filesystem limit"

run_mut S06 \
  '  if (keptChars s).isEmpty then "unknown" else String.ofList (keptChars s)' \
  '  s' \
  "THE DISARMING: the scrubber becomes the identity and scrubs nothing"

# --- S07-S12: provenance, enablement, and the constant the checker reads ------

run_mut S07 \
  '  | some "test" => .test' \
  '  | some "test" => .hook' \
  "test_is_never_hook -- declared harness traffic counted as live traffic"

run_mut S08 \
  '  | _           => if hasEvent then .hook else .cli' \
  '  | _           => .test' \
  "unknown_declaration_falls_back -- inference replaced by a believed typo"

run_mut S09 \
  '  | some "0" => false' \
  '  | some "0" => true' \
  "explicit_off_wins -- a user who said no gets files in their repository"

run_mut S10 \
  '  | some "1" => true' \
  '  | some "1" => central.isSome' \
  "explicit_on_needs_no_central -- the first draft's bug, reintroduced"

run_mut S11 \
  '  | .hook => "hook"' \
  '  | .hook => "hookX"' \
  "originTag -- a tag the #guards do not expect"

run_mut S12 \
  'def maxLen : Nat := 64' \
  'def maxLen : Nat := 128' \
  "the cap #guard -- the constant checker/session-log.sh reads out of this source"


# S13-S16 attack the project-sink status protocol. S15 is the one to watch: it
# targets the theorem that RECORDS the measured bug (decodeBang eating a leading
# bang). If S15 survives, that theorem has stopped being a regression test and
# is merely a description.
run_mut S13 \
  "  | '0' :: p  => .ok p" \
  "  | '0' :: p  => .lost" \
  "sink_ok_roundtrip -- a healthy sink misreported as a failure"

run_mut S14 \
  "  | .ok p       => '0' :: p" \
  "  | .ok p       => p" \
  "the status prefix itself -- reverting to the ambiguous bang-style encoding"

run_mut S15 \
  "  | '!' :: p => .degraded p" \
  "  | '!' :: p => .ok p" \
  "bang_protocol_misdirects -- the theorem that records the measured bug"

run_mut S16 \
  "  | ['1']     => .lost" \
  "  | ['1']     => .disabled" \
  "the lost encoding -- a failed sink decoding as a disabled one"

# --- the CLI-path provenance repair (2026-08-09) ------------------------------
# Each of these re-creates one half of the shipped defect. S17 is the important
# one: it restores EXACTLY the behaviour measured in the 1.0.1 log, where the
# CLI path ignored ROTMOE_DEBUG_SRC and recorded a declared harness run as live.

run_mut S17 \
  "  | .cli  => some (classify declared false)" \
  "  | .cli  => some .cli" \
  "src_declaration_wins_on_every_path -- the CLI path ignoring the declaration again"

run_mut S18 \
  "  | none   => \"\"" \
  "  | none   => \"cli\"" \
  "ps1_rendered_an_unclassifiable_tag -- an unset variable disguised as a real class"

run_mut S19 \
  "  | .cli  => \"cli\"" \
  "  | .cli  => \"\"" \
  "originTag_ne_empty and resolveNow_never_renders_empty -- an empty tag readmitted"

run_mut S20 \
  "  | .cli  => some .cli" \
  "  | .cli  => some .test" \
  "sh_cli_path_lost_the_test_marking -- the POSIX arm's half of the divergence"
echo
echo "=== RotSessionLog: $killed killed, $survived survived, $discarded discarded, $skipped skipped ==="

if [ "$filtered" -eq 1 ]; then
  echo "PARTIAL RUN (MUT_ONLY='${MUT_ONLY}') -- $skipped mutant(s) never ran."
  echo "A filtered run is never a pass. Exit 3."
  exit 3
fi

if [ "$discarded" -gt 0 ]; then
  echo "FAIL: $discarded mutant(s) DISCARDED -- the harness could not apply them."
  echo "That is a fault in this suite, not a claim about any theorem."
  exit 1
fi

if [ "$survived" -gt 0 ]; then
  echo "FAIL: $survived mutant(s) SURVIVED -- those theorems are decorative."
  exit 1
fi

# THE VERDICT MUST BE ABLE TO FAIL.
#
# This block used to be an unconditional `exit 0` under a sentence claiming
# every mutant was killed -- so a SURVIVING mutant was reported as a clean
# sweep. Measured 2026-08-09 when C05 survived in mutate_rotceiling.sh and the
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
# Measured 2026-08-09 on Proofs.RotSessionLog.
cp "$BAK" "$F" 2>/dev/null
( cd ${LEAN_ROOT:-.} && lake build Proofs.RotSessionLog ) >/dev/null 2>&1
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
