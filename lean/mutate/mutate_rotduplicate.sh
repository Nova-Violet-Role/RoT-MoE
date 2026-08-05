#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- the three modules added in 0.7.0:
#   Proofs/RotDuplicate.lean  (the double-fire and the uninstaller's blind spot)
#   Proofs/RotScan.lean       (the one-level proof scan, the workspace chain)
#   Proofs/RotLog.lean        (the debug record that must re-derive)
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
# WHY THESE MUTATIONS. Each one re-creates the DEFECT THE MODULE WAS WRITTEN
# ABOUT, in the model rather than in the shell. If the model can be broken back
# into the shape of the shipped bug and the theorems stay green, the theorems
# were never about the bug:
#
#   M01  `fires` reads only settings.json   -- the whole double-fire blind spot:
#                                              this is RotInstall's world view,
#                                              and it must stop the count theorem
#   M02  the guard stops guarding           -- arm ignores a live plugin
#   M03  the guard always refuses           -- the "fix" that breaks the installer
#   M04  disarm-any keeps what it claims    -- the broad mode stops removing
#   M05  disarm-any removes everything      -- the broad mode takes a neighbour
#   M06  the flat scan sees every depth     -- the defect erased, so the gap
#                                              theorem must become unprovable
#   M07  staleness inequality inverted      -- over/under-report swapped
#   M08  the chain prefers discovery        -- a session in a foreign Lake tree
#                                              silently redirects measurement
#   M09  the record's Rs stops being tied to its own sum -- a log line that
#                                              cannot be re-derived
#   M10  pairing accepts an orphan route    -- a truncated log certified
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutdup.XXXXXX")"
MODULES="RotDuplicate RotScan RotLog"

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
if [ ! -d "$_WSDIR/.lake/packages" ] || [ ! -f "$_WSDIR/.lake/build/lib/lean/Proofs/RotDuplicate.olean" ]; then
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
echo "preflight: all three baselines build GREEN -- kills are attributable"

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

echo "=== RotDuplicate / RotScan / RotLog mutation suite ==="

# --- RotDuplicate ------------------------------------------------------------

# M01 -- THE BLIND SPOT ITSELF. `fires` stops being the concatenation of the two
# registries and becomes settings.json alone, which is exactly RotInstall's view
# of the world. If the count theorem survives this, it was never about the
# double-fire.
run_mut M01 RotDuplicate \
  '  r.plugin e ++ r.settings e' \
  '  r.settings e' \
  'unguarded_duplicates (the count would be 1, not 2)'

# M02 -- the guard stops guarding: arm ignores a live plugin registration.
run_mut M02 RotDuplicate \
  '  if pluginRegisters cmd r then r else armUnguarded cmd r' \
  '  armUnguarded cmd r' \
  'guard_keeps_one, guard_is_a_no_op'

# M03 -- the opposite failure, and the one a nervous fix produces: the guard
# always refuses, so the installer is dead for everyone without the plugin.
run_mut M03 RotDuplicate \
  'def pluginRegisters (cmd : String) (r : Registry) : Bool :=' \
  'def pluginRegisters (_cmd : String) (_r : Registry) : Bool := true
def pluginRegistersOld (cmd : String) (r : Registry) : Bool :=' \
  'guard_still_arms, armed_fires'

# M04 -- the broad uninstall mode keeps what it claims to remove.
run_mut M04 RotDuplicate \
  '  settings := fun e => (r.settings e).filter (fun c => ! ours c)' \
  '  settings := fun e => (r.settings e).filter (fun c => ours c)' \
  'any_removes_all, any_preserves_foreign'

# --- RotScan -----------------------------------------------------------------

# M05 -- the defect ERASED: the flat scan starts seeing every depth. The gap
# theorem must then become unprovable, because there is no gap.
run_mut M05 RotScan \
  'def flatScan (fs : List PFile) : List PFile := fs.filter (fun f => f.depth == 0)' \
  'def flatScan (fs : List PFile) : List PFile := fs' \
  'flat_gap_is_real (the witness no longer separates the two scans)'

# M06 -- the inequality inverted. A one-level scan that could UNDER-report would
# have the opposite failure mode: false silence instead of false accusation.
run_mut M06 RotScan \
  '    staleMins now (recScan fs) ≤ staleMins now (flatScan fs) := by' \
  '    staleMins now (flatScan fs) ≤ staleMins now (recScan fs) := by' \
  'flat_never_underreports'

# M07 -- the chain prefers discovery over a recorded install, so a session that
# happens to sit inside some other Lake project silently redirects measurement.
#
# THE NEEDLE IS THE WHOLE SIGNATURE LINE, not `match recorded with`, and that is
# a finding rather than a tidy-up: the short form occurs TWICE (`resolve` and
# `resolveOld` share the shape), the harness counted 2, refused, and reported
# DISCARDED. That is the guard working -- a suite that had patched the first
# occurrence would have mutated whichever function came first and attributed the
# result to the other. Swapping the argument ORDER at the definition achieves the
# same semantic mutation from a line that is unique.
run_mut M07 RotScan \
  'def resolve (env recorded discovered : Option String) (bundled : String) :' \
  'def resolve (env discovered recorded : Option String) (bundled : String) :' \
  'resolve_recorded_beats_discovered, resolve_discovered_when_unset'

# --- RotLog ------------------------------------------------------------------

# M08 -- a record whose Rs is no longer tied to its own sum: the line stops being
# re-derivable, which is the entire reason the log exists.
run_mut M08 RotLog \
  '  r.K = Fintype.card ι ∧ r.sum = ∑ i, r.terms i ∧ r.Rs * (r.K : ℝ) = r.sum' \
  '  r.K = Fintype.card ι ∧ r.sum = ∑ i, r.terms i' \
  'consistent_Rs_eq_gauge, consistent_Rs_unique'

# M09 -- pairing accepts an orphan route line, certifying a truncated log.
run_mut M09 RotLog \
  '  | (Rec.route _) :: _ => False' \
  '  | (Rec.route _) :: _ => True' \
  'orphan_route_detected, wellPaired_discriminates'

# M10 -- the display tolerance widened past any meaning: a route line 100x away
# from its gauge line would be accepted as an honest rounding.
run_mut M10 RotLog \
  'noncomputable def displayEps : ℝ := 1 / 200' \
  'noncomputable def displayEps : ℝ := 2' \
  'mismatched_pair_detected'

# --- RESTORE AND REBUILD, and this is not a formality --------------------------
# Measured 2026-08-04: the first version of this suite restored the SOURCE and
# stopped there. Every mutant deletes the .olean to defeat Lake's incremental
# build, so the run ended with three modules compiled-out of the tree. The source
# was perfect and `git status` was clean, so nothing looked wrong -- and then
# `checker/axiom-audit.sh` failed with "the axiom probe did not elaborate", and
# `axiom-class.sh` reported "36 theorems unaccounted for". Both were true
# statements about a tree this harness had quietly emptied.
#
# A mutation run that does not end at a VERIFIED green baseline has said nothing
# about the state it leaves behind, and the next gate inherits the damage.
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

if [ "$rebuild_fail" -ne 0 ]; then
  echo
  echo "REFUSING to report success: the baseline was not restored to a GREEN,"
  echo "BUILT state. Every later gate would inherit a tree this suite emptied."
  exit 1
fi
if [ "$discarded" -gt 0 ]; then
  echo
  echo "REFUSING to report a clean sweep: $discarded mutant(s) never applied."
  exit 1
fi
if [ "$survived" -gt 0 ]; then
  echo
  echo "$survived mutant(s) SURVIVED -- those theorems do not constrain what they claim."
  exit 1
fi
echo
echo "all $killed mutants killed, none discarded."
exit 0
