#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotInject.lean (eleven events, and a log that can name which one fired)
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

F="Proofs/RotInject.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotInject.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutinject.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotInject ) >/tmp/mut_pre_rotinject.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotInject)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotinject.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotInject ) >/dev/null 2>&1' EXIT

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotInject ) > "$LOG/$id.log" 2>&1
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
    dead=$(grep -oE "^error: Proofs/RotInject\.lean:[0-9]+" "$LOG/$id.log" \
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

echo "=== RotInject mutation suite ==="

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
run_mut I01 \
  '"SessionStart", "UserPromptSubmit", "UserPromptExpansion"]' \
  '"SessionStart", "UserPromptSubmit", "UserPromptExpansion", "SessionEnd"]' \
  'the SessionEnd guard, the length guard and the 25-refused guard'

# I02 -- emission on everything: the behaviour that produced ~25 invalid
# payloads per session. If nothing dies, the safety property proves nothing.
run_mut I02 \
  'def emits (e : String) : Bool := accepting.contains e' \
  'def emits (_e : String) : Bool := true' \
  'some_events_are_refused and every negative guard'

# I03 -- THE DISARMING. Silence everything and the error message disappears too,
# which is why "the error is gone" is not evidence that the fix is a fix. The
# positive guards are the only thing standing between a repair and a mute.
run_mut I03 \
  'def emits (e : String) : Bool := accepting.contains e' \
  'def emits (_e : String) : Bool := false' \
  'every positive guard (PostToolUse, PreToolUse, PostToolBatch, ...)'

# I04 -- one character wrong in an event name. The lane goes silent and nothing
# else in the system notices; only the cross-check against `declared` can see it.
run_mut I04 \
  '"PostToolBatch",' \
  '"PostToolBatchh",' \
  'accepting_are_real_events and the PostToolBatch guard'

# I05 -- a REAL event substituted for an accepting one. Passes any "is it a real
# event" check and still breaks injection; only the accepting-set guards catch it.
run_mut I05 \
  '"PostToolBatch",' \
  '"ConfigChange",' \
  'the PostToolBatch guard and the ConfigChange-is-refused guard'

# I06 -- the busiest lane is dropped. A partial disarm is the easiest kind to
# ship by accident and the hardest to notice, because most events still work.
run_mut I06 \
  '["PreToolUse", "PostToolUse", "PostToolBatch",' \
  '["PreToolUse", "PostToolBatch",' \
  'the PostToolUse guard and the length guard'

# I07 -- the label is hardcoded again. This is the older defect the hook'\''s own
# comments describe; the gate sits next to that code and must not reintroduce it.
run_mut I07 \
  'def labelOf (e : String) : String := e' \
  'def labelOf (_e : String) : String := "PostToolUse"' \
  'label_is_the_invoking_event and emitted_payload_is_valid'

# I08 -- "31 events are wired, so 31 events accept context". The conflation of
# dispatch with schema acceptance, which is the root cause in one line.
run_mut I08 \
  'def emits (e : String) : Bool := accepting.contains e' \
  'def emits (e : String) : Bool := declared.contains e' \
  'some_events_are_refused and the SessionEnd/ConfigChange/Stop guards'

# I09 -- a duplicate entry masking a dropped one: the shape drift between the
# PowerShell array and this model would actually take.
run_mut I09 \
  '"PreToolUse", "PostToolUse", "PostToolBatch",' \
  '"PreToolUse", "PreToolUse", "PostToolBatch",' \
  'the dedup guard and the PostToolUse guard'

echo
echo "=== RotInject: $killed killed, $survived survived, $discarded discarded, $skipped skipped ==="

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
# Measured 2026-08-09 on Proofs.RotInject.
cp "$BAK" "$F" 2>/dev/null
( cd ${LEAN_ROOT:-.} && lake build Proofs.RotInject ) >/dev/null 2>&1
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
