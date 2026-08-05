#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotTag.lean, WHEN A TAG MAY MOVE.
#
# THIS HEADER WAS INHERITED AND WRONG. The file was derived with `head -178`
# from a sibling suite, and the block that arrived described RotStem's MATCHER
# mutants -- `firesWord_imp_fires`, boundary conditions, substring collapse --
# none of which exist in RotTag. The same defect was found and fixed once before
# in mutate_rotlog.sh. A suite whose comments describe a different module is a
# suite nobody can audit: the reader checks the mutants against the prose, the
# prose is about another file, and the mismatch reads as the reader's error.
#
# WHY THIS SUITE EXISTS. `docs/GIT-WORKFLOW.md` §4.3 used to say "never
# force-push, never rewrite published history -- tags are consumed by the
# marketplace". Measured: the marketplace resolves the DEFAULT BRANCH, not a
# tag. What is pinned to a tag is a published GitHub Release and its assets.
# So the rule has a boundary, and RotTag.lean states it: a tag may move until a
# Release is attached, and never after.
#
# That distinction is load-bearing in BOTH directions, which is why the mutants
# come in pairs. Delete the boundary and a published download silently changes
# meaning. Over-correct to "nothing ever moves" and the project can no longer
# re-tag onto a commit whose CI is green -- the safe operation is forbidden as
# firmly as the dangerous one, and the usual repair is to weaken the rule.
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
# WHY THESE MUTATIONS. Each is a way the tag rule could be hollowed out, and
# the pairs are deliberate:
#
#   T01  every tag may move          -- the boundary deleted; "never force-push"
#                                       becomes "always may"
#   T02  no tag may ever move        -- the over-correction, and the reason the
#                                       non-vacuity theorem exists
#   T03  the boundary is inverted    -- published tags move, unpublished freeze
#   T04  a move silently publishes   -- the freedom is consumed by using it
#   T05  a refused move renames      -- the "safe" workaround that breaks every
#                                       existing reference instead
#   T06  publish never sets the flag -- the one-way door never closes
#   T07  the invariant is weakened   -- from "fixed point of the whole history"
#        to a single step               to "one requested commit does nothing";
#                                       a force-push loop IS a history
#   T08  resolves reads the name     -- the consumer-facing claim stops being
#                                       about what is fetched
#   T09  the freedom theorem is      -- it would then assert a PUBLISHED tag
#        handed a released tag          moves, which is the unsafe act itself
#   T10  the concrete tags are       -- the executed evidence would describe a
#        marked released                state this repository is not in
#
# THREE OF THESE TEN WERE FIRST WRITTEN FROM MEMORY AND ALL THREE WERE CAUGHT.
# T04's needle was indented differently from the source; T05's replacement
# contained its own needle so it could never be seen to land; T07 appended to a
# signature, leaving the needle as a prefix of its replacement. Each was scored
# DISCARDED, not SURVIVED -- which is the whole reason the landing assertion
# exists, and the difference between "the theorem is robust" and "nothing was
# tested".
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

LOG="$(mktemp -d "${TMPDIR:-/tmp}/muttag.XXXXXX")"
MODULES="RotTag"

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
if [ ! -d "$_WSDIR/.lake/packages" ] || [ ! -f "$_WSDIR/.lake/build/lib/lean/Proofs/RotTag.olean" ]; then
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

echo "=== RotTag mutation suite (when a tag may move, and when it never may) ==="

# WHY THIS SUITE EXISTS AT ALL.
#
# RotTag.lean is the specification every other suite is measured against:
# `landed`, `classify`, and `killed_implies_all_three` are what
# checker/mutant-discipline.sh enforces on the whole tree. It had no suite of its
# own. The module that decides whether everyone else's mutants are honest had
# never had a mutant pointed at it -- which is exactly the shape of oversight it
# was written to forbid.
#
# Every mutant below re-creates a real way the discipline could be hollowed out.


# T01 -- THE DEFECT THE DOC USED TO ENCODE: the boundary is deleted and every
# tag becomes movable. This is "never force-push" replaced by "always may".
# `released_move_is_identity` and the whole freeze chain must die.
run_mut T01 RotTag \
  'def mayMove (t : Tag) : Bool := !t.released' \
  'def mayMove (t : Tag) : Bool := true' \
  'released_move_is_identity, released_tag_never_moves, publish_then_frozen'

# T02 -- the OPPOSITE over-correction, and the reason the non-vacuity theorem
# exists: nothing may ever move. A rule that forbids everything is not caution,
# it forbids re-tagging onto a green commit as firmly as rewriting a published
# one. `unreleased_move_lands` and `unreleased_tag_can_move` must refuse.
run_mut T02 RotTag \
  'def mayMove (t : Tag) : Bool := !t.released' \
  'def mayMove (t : Tag) : Bool := false' \
  'unreleased_move_lands, unreleased_tag_can_move'

# T03 -- the boundary is inverted: published tags move, unpublished ones are
# frozen. Every theorem in the file is about the wrong side.
run_mut T03 RotTag \
  'def mayMove (t : Tag) : Bool := !t.released' \
  'def mayMove (t : Tag) : Bool := t.released' \
  'every theorem: the freeze and the freedom swap places'

# T04 -- `move` silently publishes. Now a re-tag consumes the freedom it used,
# which is false about git and would make the workflow doc wrong in the
# direction that costs a legitimate operation.
# NEEDLE MEASURED, NOT REMEMBERED. The first version of T04 looked for
# `    { t with commit := c }` on a line of its own; the real source has it
# inline as `  if mayMove t then { t with commit := c } else t`. It matched
# nothing, the patch never landed, and the harness correctly reported DISCARDED
# rather than counting it as a survivor. Three of this suite's ten mutants were
# written from memory and all three were caught by the landing assertion --
# which is the entire reason that assertion exists.
run_mut T04 RotTag \
  '{ t with commit := c }' \
  '{ t with commit := c, released := true }' \
  'move_preserves_released, moves_do_not_consume_freedom'

# T05 -- a refused move quietly renames the tag instead of doing nothing. This
# is the shape of a "safe" workaround that breaks every existing reference.
# The first T05 inserted a whole second definition and so left the needle
# present TWICE -- the harness saw needle=1 repl=2 and discarded it. A mutation
# whose replacement CONTAINS its own needle can never be seen to land. One line,
# one change: a refused move now silently renames instead of doing nothing.
run_mut T05 RotTag \
  'if mayMove t then { t with commit := c } else t' \
  'if mayMove t then { t with commit := c } else { t with name := c }' \
  'move_preserves_name, released_move_is_identity'

# T06 -- `publish` does not set the flag. The one-way door never closes, so
# nothing is ever protected and `publish_then_frozen` is false.
run_mut T06 RotTag \
  'def publish (t : Tag) : Tag := { t with released := true }' \
  'def publish (t : Tag) : Tag := t' \
  'publish_then_frozen'

# T07 -- the durable theorem is weakened to ONE move. This is the mutation that
# matters most: a rule that survives a single step is not an invariant, and a
# history of attempts is exactly what a force-push loop is.
# The first T07 appended an argument to the signature, so the needle survived as
# a PREFIX of its own replacement -- needle=1 repl=1, discarded. The mutation
# that matters is on the CONCLUSION anyway: the invariant is weakened from "the
# tag is a fixed point of the whole history" to "one requested commit does
# nothing". A rule that survives a single step is not an invariant, and a
# force-push loop is precisely a history of attempts.
run_mut T07 RotTag \
  '    (h : t.released = true) : cs.foldl move t = t := by' \
  '    (h : t.released = true) : move t (cs.headD []) = t := by' \
  'released_tag_never_moves induction, publish_then_frozen'

# T08 -- `resolves` stops reading the commit, so the consumer-facing statement
# says nothing about what is fetched.
run_mut T08 RotTag \
  'def resolves (t : Tag) : List Char := t.commit' \
  'def resolves (t : Tag) : List Char := t.name' \
  'unreleased_tag_can_move -- two different commits under one name'

# T09 -- the freedom theorem is handed a RELEASED tag. It then claims a
# published tag moves, which is precisely the unsafe act, and must not prove.
run_mut T09 RotTag \
  '  refine ⟨⟨"v0.7.1".toList, "95c4f6d".toList, false⟩, "c4f44f5".toList, ?_⟩' \
  '  refine ⟨⟨"v0.7.1".toList, "95c4f6d".toList, true⟩, "c4f44f5".toList, ?_⟩' \
  'unreleased_tag_can_move -- a released tag does NOT move'

# T10 -- the concrete tags are marked released. The executed evidence then
# describes a state this repository is not in, and the `mayMove` examples that
# justify re-tagging right now must go red.
run_mut T10 RotTag \
  'def v070 : Tag := ⟨"v0.7.0".toList, "95c4f6d".toList, false⟩' \
  'def v070 : Tag := ⟨"v0.7.0".toList, "95c4f6d".toList, true⟩' \
  'the mayMove v070 example'
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

echo "=== RotTag: killed=$killed survived=$survived discarded=$discarded ==="
# DISCARDED is reported on its own line and never folded into survived: the first
# is a defect in this harness, the second a claim about a theorem.
if [ "$survived" -gt 0 ] || [ "$discarded" -gt 0 ]; then exit 1; fi
exit 0
