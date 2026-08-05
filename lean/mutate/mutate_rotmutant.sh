#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotMutant.lean, MUTATION DISCIPLINE ITSELF.
#
# WHY THIS SUITE EXISTS, and why its absence was a hole rather than an oversight.
# RotMutant shipped in an early release with theorems about WHICH CLASS FIRED and
# no suite of its own. In 0.7.0 it gained the specification of HOW A CLASS
# DECIDES -- `firesWord_imp_fires`, the theorem that made it safe to change the
# live router's matcher. That theorem is the strongest safety claim in the
# release, and until this file existed nothing had ever tried to break it.
#
# A theorem no mutation kills is decorative. The headline theorem of a release
# is the last one that should be taken on trust.
#
# The contract, identical to the other suites in this directory:
#   1. assert the needle is present EXACTLY once before mutating; if not -> DISCARDED
#   2. assert the mutation LANDED after patching (needle gone, replacement present)
#   3. delete the stale .olean so Lake cannot skip the rebuild
#   4. rebuild, read the exit code DIRECTLY
#   5. restore from the backup, ALWAYS, and rebuild to a verified green baseline
#
# DISCARDED != SURVIVED. The first is a defect in this harness, the second is a
# claim about the theorem. Folding them together manufactures reassurance.
#
# WHY THESE MUTATIONS. Each re-creates a matcher defect that this repo has
# actually shipped or nearly shipped:
#
#   M01  every character is a boundary      -- the collapse back to substring
#                                              matching, which is the defect the
#                                              whole 0.7.0 routing fix removes
#   M02  the boundary condition is dropped  -- a stem fires anywhere in a word
#   M03  the word branch reverts to infix   -- the SHIPPED 0.6.x behaviour,
#                                              restored exactly
#   M04  the punctuation carve-out dies     -- `.lean` stops matching Basic.lean
#   M05  the punctuation carve-out swallows -- EVERY stem takes the infix path,
#        the word branch                       so the carve-out becomes the rule
#   M06  `any` becomes `all`                -- a stem list stops being a
#                                              disjunction
#   M07  the empty stem fires               -- an empty list entry becomes a
#                                              wildcard matching every prompt
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutmutant.XXXXXX")"
MODULES="RotMutant"

# --- NO-DOWNLOAD GUARD ------------------------------------------------------
# `lake build` RESOLVES the package first, and against the vendored `lean/` tree
# that resolution starts fetching mathlib INTO the repository. A workspace that
# was never built cannot satisfy this suite, so it SKIPS rather than builds.
# Exit 3 is a skip everywhere in this repo, and a skip is never a pass.
_WSDIR="${LEAN_ROOT:-.}"
for m in $MODULES; do
  [ -f "Proofs/$m.lean" ] || {
    echo "FATAL: Proofs/$m.lean not found. Refusing to run: every mutant would"
    echo "fail to build and be scored KILLED without a line having been mutated."
    exit 2
  }
done
if [ ! -d "$_WSDIR/.lake/packages" ] || [ ! -f "$_WSDIR/.lake/build/lib/lean/Proofs/RotMutant.olean" ]; then
  echo "SKIP: $_WSDIR is not a BUILT Lean workspace."
  echo "      Refusing to invoke lake: resolving mathlib would DOWNLOAD gigabytes."
  echo "      Set LEAN_ROOT to an already-built workspace to run this suite."
  echo "      This is a SKIP (exit 3), never a pass."
  exit 3
fi

for m in $MODULES; do
  if ! ( cd "$_WSDIR" && lake build "Proofs.$m" ) >"$LOG/pre_$m.log" 2>&1; then
    echo "FATAL: the UNMUTATED baseline does not build (Proofs.$m)."
    echo "A kill measured against a red baseline is unattributable. Fix the tree first."
    tail -5 "$LOG/pre_$m.log"
    exit 2
  fi
done
echo "preflight: the baseline builds GREEN -- kills are attributable"

# --- SOURCE SANITY: a green baseline is NOT proof the source is intact -------
# An EMPTY Lean file builds green. "The baseline compiles" is therefore a weaker
# statement than it looks, and a truncated source copied over the backup would
# score the whole suite as DISCARDED while destroying the file. Content is
# checked before anything is copied.
for m in $MODULES; do
  _lines=$(wc -l < "Proofs/$m.lean" 2>/dev/null || echo 0)
  _thms=$(grep -c "^theorem \|^example " "Proofs/$m.lean" 2>/dev/null || echo 0)
  if [ "${_lines:-0}" -lt 20 ] || [ "${_thms:-0}" -lt 1 ]; then
    echo "FATAL: Proofs/$m.lean looks DAMAGED ($_lines lines, $_thms theorems)."
    echo "Refusing to overwrite its backup. Restore it before running this suite."
    exit 2
  fi
  cp "Proofs/$m.lean" "Proofs/$m.lean.mutbak"
done
trap 'for m in '"$MODULES"'; do cp "Proofs/$m.lean.mutbak" "Proofs/$m.lean" 2>/dev/null; rm -f "Proofs/$m.lean.mutbak"; done' EXIT

killed=0; survived=0; discarded=0

run_mut() {
  local id="$1" mod="$2" needle="$3" repl="$4" expect="$5"
  local F="Proofs/$mod.lean" BAK="Proofs/$mod.lean.mutbak"
  local OLEAN="$_WSDIR/.lake/build/lib/lean/Proofs/$mod.olean"
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

  # Lake is incremental and will happily not rebuild a module it believes is
  # unchanged. Deleting the artifact removes the doubt.
  rm -f "$OLEAN"
  ( cd "$_WSDIR" && lake build "Proofs.$mod" ) > "$LOG/$id.log" 2>&1
  local ec=$?

  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   (build still exit 0)  expected to kill: $expect"
    survived=$((survived+1))
  else
    local dead
    dead=$(grep -oE "^error: Proofs/$mod\.lean:[0-9]+" "$LOG/$id.log" \
      | grep -oE "[0-9]+$" | sort -un | while read -r ln; do
        awk -v L="$ln" '
          /^(theorem|def|noncomputable def|private def|instance|structure|inductive|example)/ {
            if (NR <= L) { name=$0 }
          }
          END { if (name != "") print name }
        ' "$F"
      done | sed -E 's/^(private |noncomputable )?(theorem|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' \
      | sort -u | tr '\n' ',')
    # The reported error lines are a LOWER BOUND on what died, not an inventory:
    # a mutant build produces no olean, so every theorem in the module is
    # unusable downstream regardless of which line the elaborator complained at.
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

echo "=== RotMutant mutation suite (the module that DEFINES mutation discipline) ==="

# WHY THIS SUITE EXISTS AT ALL.
#
# RotMutant.lean is the specification every other suite is measured against:
# `landed`, `classify`, and `killed_implies_all_three` are what
# checker/mutant-discipline.sh enforces on the whole tree. It had no suite of its
# own. The module that decides whether everyone else's mutants are honest had
# never had a mutant pointed at it -- which is exactly the shape of oversight it
# was written to forbid.
#
# Every mutant below re-creates a real way the discipline could be hollowed out.

# M01 -- LANDING STOPS REQUIRING A SUCCESSFUL PATCH TOOL. This is the FIRST
# measured defect in this repository's history (route 2: sed exited 1, wrote an
# empty file, and the harness called it a kill). If `toolExit` drops out of
# `landed`, that false kill becomes legal again.
run_mut M01 RotMutant \
  '  r.toolExit == 0 && !r.empty && r.changed' \
  '  !r.empty && r.changed' \
  'tool_failed_never_killed, killed_implies_all_three, the exhaustive #guard'

# M02 -- AN EMPTY MUTANT COUNTS AS LANDED. The other half of route 2: a patch
# that produced a zero-byte file is not a mutation, it is a deletion.
run_mut M02 RotMutant \
  '  r.toolExit == 0 && !r.empty && r.changed' \
  '  r.toolExit == 0 && r.changed' \
  'empty_never_killed, route2 guard, killed_implies_all_three'

# M03 -- AN UNCHANGED FILE COUNTS AS LANDED. Route 1, measured: sed succeeded and
# matched nothing, so the "mutant" was byte-identical to the original. A suite
# with this defect reports SURVIVED for every theorem while testing nothing --
# the reassuring direction, which is why it is the dangerous one.
run_mut M03 RotMutant \
  '  r.toolExit == 0 && !r.empty && r.changed' \
  '  r.toolExit == 0 && !r.empty' \
  'unchanged_never_killed, route1 guard, killed_implies_all_three'

# M04 -- DISCARDED COLLAPSES INTO SURVIVED. The single most dishonest edit
# available here: a patch that never applied would be reported as a theorem that
# withstood attack.
run_mut M04 RotMutant \
  '  else Outcome.discarded' \
  '  else Outcome.survived' \
  'not_landed_discarded, discarded_never_counts, outcomes_distinct'

# M05 -- A DISCARDED RUN STARTS COUNTING TOWARD THE TOTAL. The totals in README
# and CHANGELOG are built from this; if discards count, the applied/killed totals
# stop meaning anything.
run_mut M05 RotMutant \
  '  o != Outcome.discarded' \
  '  true' \
  'discarded_never_counts, counts guards on route2'

# M06 -- THE ASSERTION VERDICT IS IGNORED. If `accepts` no longer decides between
# killed and survived, a mutant the assertion did NOT catch is reported killed.
run_mut M06 RotMutant \
  '  if landed r then (if accepts then Outcome.survived else Outcome.killed)' \
  '  if landed r then (if accepts then Outcome.killed else Outcome.killed)' \
  'landed_accepted_survived, the exhaustive #guard'

# --- the CLASSIFIER half, added 2026-08-05 ----------------------------------

# M07 -- THE CLASSIFIER STOPS SELECTING FILES THAT REPORT KILLS. This is the
# mutant that guards the repair itself: if `saysKilled` drops out, a real
# mutation harness escapes discipline entirely, which is the failure the
# narrowing was accused of causing. It must not stay green.
run_mut M07 RotMutant \
  '  f.patches && (f.saysKilled || f.saysSurvived || f.saysDiscard)' \
  '  f.patches && (f.saysSurvived || f.saysDiscard)' \
  'discipline_applies_to_every_kill, repair_is_not_vacuous, the 32-shape #guard'

# M08 -- THE REPAIR IS REVERTED. `CONTROL` back in the adjudication test: the two
# classifiers become identical, so `repair_is_not_vacuous` -- the theorem that
# proves the change was not a no-op -- must fail.
run_mut M08 RotMutant \
  'def isHarness (f : FileEvidence) : Bool :=' \
  'def isHarnessUnused (f : FileEvidence) : Bool :=' \
  'every classifier theorem and #guard (the definition disappears)'

# M09 -- PATCHING STOPS BEING REQUIRED. A file that merely talks about kills
# would owe mutation discipline; that is the over-broad direction, and
# no_patch_no_discipline exists to forbid it.
run_mut M09 RotMutant \
  '  f.patches && (f.saysKilled || f.saysSurvived || f.saysDiscard)' \
  '  (f.saysKilled || f.saysSurvived || f.saysDiscard)' \
  'no_patch_no_discipline, a_control_alone_is_not_a_harness, the 32-shape #guard'

# M10 -- THE LOOSE CLASSIFIER LOSES ITS CONTROL TERM, which is what made it
# loose. With both forms equal, the exhaustive 32-shape guard that pins WHERE
# they differ must go red.
run_mut M10 RotMutant \
  '  f.patches && (f.saysKilled || f.saysSurvived || f.saysDiscard || f.saysControl)' \
  '  f.patches && (f.saysKilled || f.saysSurvived || f.saysDiscard)' \
  'repair_is_not_vacuous, the 32-shape difference #guard'

# --- the RESTORE section (added after the 2026-08-06 near-miss) --------------
# M11 -- `canRestore` stops looking at the size and just says yes, which is the
# `find`-only check the shell used to rely on. If nothing dies, the size test is
# decoration and the old advice was fine.
run_mut M11 RotMutant \
  'def canRestore (b : Artifact) : Bool := b.bytes != 0' \
  'def canRestore (_b : Artifact) : Bool := true' \
  'existence_is_not_restorability, copy_is_safe_iff_backup_nonempty'

# M12 -- the safety predicate stops noticing that a non-empty file became empty.
run_mut M12 RotMutant \
  '  (before.bytes == 0) || (after.bytes != 0)' \
  '  true' \
  'empty_backup_restore_is_destructive, git_strictly_safer_on_the_measured_state, and the restore #guards'

# M13 -- git restore starts depending on the BACKUP. This is the mutation that
# tests whether `git_restore_ignores_the_backup` earns its place: it is proved by
# `rfl` and depends on NO axioms, which is the vacuity smell, so it has to be
# shown load-bearing against exactly this change or labelled decoration.
#
# NOTE ON THE NEEDLE, and it is the hazard this repository keeps re-learning:
# the first version of M13 spanned TWO lines and came back
# `needle occurs 2 times (expected 1) -- patch not applied`, because a multi-line
# `grep -F -c` counts matching LINES, not occurrences of the pattern. It was
# reported DISCARDED, never SURVIVED -- the harness refusing to draw a conclusion
# from a patch that did not land. Single-line needles only.
run_mut M13 RotMutant \
  'def restoreFromGit (committed : Artifact) (_f _b : Artifact) : Artifact :=' \
  'def restoreFromGit (_committed : Artifact) (_f b : Artifact) : Artifact := b --' \
  'git_restore_ignores_the_backup, git_restore_is_total, git_strictly_safer_on_the_measured_state'

echo
# --- back to a VERIFIED green baseline ---------------------------------------
# Every other suite in this directory ends by rebuilding after the final restore.
# This one did not: it was derived with `head -165` from a sibling, and the tail
# that carried the guard was exactly what the truncation cut off. The same
# derivation produced the same hole in mutate_rotlog.sh.
#
# The consequence is a FALSE RED, not a false green, and it is still expensive:
# the last mutant's build fails, its olean is deleted and never rebuilt, so the
# suite exits 0 having left the workspace unbuildable. `checker/axiom-class.sh`
# then imports the module to probe it and reports theorems "unaccounted for",
# which reads exactly like a broken proof. Telling those two apart cost a full
# attribution cycle.
for m in $MODULES; do
  cp "Proofs/$m.lean.mutbak" "Proofs/$m.lean" 2>/dev/null
done
_baseline_bad=0
for m in $MODULES; do
  if ! ( cd "$_WSDIR" && lake build "Proofs.$m" ) > "$LOG/post_$m.log" 2>&1; then
    echo "FATAL: the tree does NOT build after restoring (Proofs.$m)."
    echo "The suite has left this workspace red. Do not trust the counts above."
    tail -5 "$LOG/post_$m.log"
    _baseline_bad=1
  elif [ ! -f "$_WSDIR/.lake/build/lib/lean/Proofs/$m.olean" ]; then
    echo "FATAL: Proofs.$m built but produced no olean -- downstream probes will fail."
    _baseline_bad=1
  fi
done
if [ "$_baseline_bad" -ne 0 ]; then exit 2; fi
echo "baseline restored and REBUILT green (olean present again)"

echo "=== RotMutant: killed=$killed survived=$survived discarded=$discarded ==="
# DISCARDED is reported on its own line and never folded into survived: the first
# is a defect in this harness, the second a claim about a theorem.
if [ "$survived" -gt 0 ] || [ "$discarded" -gt 0 ]; then exit 1; fi
exit 0
