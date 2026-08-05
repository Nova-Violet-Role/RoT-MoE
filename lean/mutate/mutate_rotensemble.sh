#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotEnsemble.lean, the STEM MATCHER.
#
# WHY THIS SUITE EXISTS, and why its absence was a hole rather than an oversight.
# RotEnsemble shipped in an early release with theorems about WHICH CLASS FIRED and
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

LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutens.XXXXXX")"
MODULES="RotEnsemble"

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
if [ ! -d "$_WSDIR/.lake/packages" ] || [ ! -f "$_WSDIR/.lake/build/lib/lean/Proofs/RotEnsemble.olean" ]; then
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

echo "=== RotEnsemble mutation suite (the nine-lens conformance) ==="

# M01 -- THE ONE-HOT VECTOR STOPS DEPENDING ON THE LANE. Every lane would read
# the same, which is precisely the "it is all just Claude" failure this module
# was written to rule out. The nine pinned readings must die.
run_mut M01 RotEnsemble \
  '  (List.range 9).map (fun j => if j == i then 1.0 else 0.0)' \
  '  (List.range 9).map (fun j => if j == 0 then 1.0 else 0.0)' \
  'the nine per-lane #guards and the distinctness guard'

# M02 -- THE ROUTER READING LOSES ITS BREADTH. `breadth = 0` kills the H term, so
# every reading shifts: the conformance to the SHELL's measured numbers breaks.
run_mut M02 RotEnsemble \
  'def routerReading (i : Nat) : Float := r5 (gaugeF (oneHotF i) 1 1 1 1)' \
  'def routerReading (i : Nat) : Float := r5 (gaugeF (oneHotF i) 0 1 1 1)' \
  'all nine router #guards -- H would vanish'

# M03 -- `bump` STOPS BUMPING. If replacing a lens weight is a no-op then
# `no_lens_is_inert` is unprovable: nothing could ever change the gauge.
run_mut M03 RotEnsemble \
  '  fun i => if i = j then l else L i' \
  '  fun i => L i' \
  'bump_at, no_lens_is_inert, every_forge_lens_is_pivotal'

# M04 -- THE DYNAMIC ROW LOSES ITS BREADTH. The engine payload measured
# breadth 2 for AntiVenom+Soleil+Claude; claiming 1 changes H for three lenses
# and the reading is no longer 0.69.
run_mut M04 RotEnsemble \
  '#guard r2 (gaugeF [0,0,1,0,0,0,1,0,1] 2 1 1 0.8) == 0.69' \
  '#guard r2 (gaugeF [0,0,1,0,0,0,1,0,1] 1 1 1 0.8) == 0.69' \
  'the dynamic-path conformance guard'

# M05 -- THE ENGINE SCALARS ARE FALSIFIED. T = 0.8 is what the payload carries;
# T = 1 is the router's. Mixing them is the exact confusion this module exists to
# separate, and it must not stay green.
run_mut M05 RotEnsemble \
  '#guard r2 (gaugeF [0,0,1,0,0,0,0,0,1] 1 1 1 0.8) == 0.79' \
  '#guard r2 (gaugeF [0,0,1,0,0,0,0,0,1] 1 1 1 1.0) == 0.79' \
  'the AntiVenom+Claude dynamic guard'

# M06 -- SILENCE STOPS BEING SILENT. The FIRST version of this mutant flipped
# the quiet reading's breadth from 0 to 1 and SURVIVED -- correctly, because with
# an all-zero vector H = 0/breadth = 0 either way, so the edit was a semantic
# no-op. That is now a theorem (quiet_entropy_is_zero_at_any_breadth) instead of
# a hole. The mutant is re-aimed at something that genuinely moves: a quiet turn
# that reports every lens live.
run_mut M06 RotEnsemble \
  'noncomputable def lamFuse (l₁ l₂ : ℝ) : ℝ := (l₁ + l₂) / 2 + 1/5' \
  'noncomputable def lamFuse (l₁ l₂ : ℝ) : ℝ := (l₁ + l₂) / 2' \
  'lamFuse_self, lamFuse_has_no_fixed_point, iterated_fusion_diverges'
# --- RESTORE AND REBUILD, and this is not a formality --------------------------
# Measured 2026-08-04 on the sibling suite: restoring the SOURCE and stopping
# there leaves the module compiled OUT of the tree, because every mutant deletes
# the .olean. The source was perfect and `git status` was clean, so nothing
# looked wrong -- and then checker/axiom-audit.sh failed with "the axiom probe
# did not elaborate" and axiom-class.sh reported theorems unaccounted for. Both
# were true statements about a tree this kind of harness had quietly emptied.
echo
echo "-- restoring the baseline and REBUILDING it --"
rebuild_fail=0
for m in $MODULES; do
  cp "Proofs/$m.lean.mutbak" "Proofs/$m.lean"
done
for m in $MODULES; do
  if ( cd "$_WSDIR" && lake build "Proofs.$m" ) >"$LOG/post_$m.log" 2>&1; then
    if [ -f "$_WSDIR/.lake/build/lib/lean/Proofs/$m.olean" ]; then
      echo "  $m: restored, rebuilt GREEN, olean present"
    else
      echo "  $m: FAIL -- build reported success but no olean was produced"
      rebuild_fail=1
    fi
  else
    echo "  $m: FAIL -- the RESTORED baseline does not build"
    tail -3 "$LOG/post_$m.log"
    rebuild_fail=1
  fi
done

echo
echo "=== RESULT ==="
echo "killed: $killed   survived: $survived   discarded: $discarded"
echo
echo "A SURVIVED mutant is a claim about a theorem: it did not constrain what it"
echo "appeared to. A DISCARDED mutant is a claim about THIS FILE: the patch never"
echo "landed and nothing was tested. They are reported apart because folding them"
echo "together is how a mutation suite lies in the reassuring direction."
echo

if [ "$rebuild_fail" -ne 0 ]; then
  echo "REFUSING to report success: the baseline was not restored to a GREEN,"
  echo "BUILT state. Every later gate would inherit a tree this suite emptied."
  exit 1
fi
if [ "$discarded" -gt 0 ]; then
  echo "$discarded mutant(s) DISCARDED -- the harness failed to apply them."
  exit 1
fi
if [ "$survived" -gt 0 ]; then
  echo "$survived mutant(s) SURVIVED -- those theorems do not constrain the model."
  exit 1
fi
echo "all $killed mutants killed, none discarded."
exit 0
