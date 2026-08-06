#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotObserve.lean (what an observation does NOT tell you)
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
# WHAT THIS SUITE IS AIMED AT. RotObserve is not an abstract module: each of its
# four sections was extracted from an inference that was actually made, and was
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

F="Proofs/RotObserve.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotObserve.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutobserve.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotObserve ) >/tmp/mut_pre_rotobserve.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotObserve)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotobserve.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"' EXIT

killed=0; survived=0; discarded=0

run_mut() {
  local id="$1" needle="$2" repl="$3" expect="$4"
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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotObserve ) > "$LOG/$id.log" 2>&1
  local ec=$?

  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   (build still exit 0)  expected to kill: $expect"
    survived=$((survived+1))
  else
    # The reported error lines are a LOWER BOUND on what died, not an inventory.
    # A mutant build produces no olean, so every theorem in the module is
    # unusable downstream regardless of which line the elaborator complained at.
    local dead
    dead=$(grep -oE "^error: Proofs/RotObserve\.lean:[0-9]+" "$LOG/$id.log" \
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

echo "=== RotObserve mutation suite ==="

# --- section 1: the two arming paths ----------------------------------------

# M01 -- the belief the empty settings.json diff invited: armedness is whatever
# settings.json says. Under this definition a plugin install is "not armed",
# which is exactly the panic the module exists to prevent.
run_mut M01 \
  'def armed (b : Binding) : Bool := b.bySettings || b.byPlugin' \
  'def armed (b : Binding) : Bool := b.bySettings' \
  'settings_silence_is_not_disarm, settings_alone_cannot_decide_armed, guard_still_leaves_it_armed, arming_is_an_instance'

# M02 -- ARM_ROUTER stops consulting the plugin registry. This is the ACTUAL
# defect fixed earlier in this project: the router registered twice and fired
# twice per event.
run_mut M02 \
  '  if b.byPlugin then b else { b with bySettings := true }' \
  '  { b with bySettings := true }' \
  'guard_creates_no_double'

# M03 -- double-binding weakened to "either path bound it". The guard then
# refuses on a perfectly clean host and the concept stops meaning anything.
run_mut M03 \
  'def doubleBound (b : Binding) : Bool := b.bySettings && b.byPlugin' \
  'def doubleBound (b : Binding) : Bool := b.bySettings || b.byPlugin' \
  'guard_creates_no_double'

# --- section 2: the exit code through a pipe --------------------------------

# M04 -- the belief that produced a false green in this very session: that `$?`
# after a pipeline reports the FIRST stage (the real tool) rather than the last.
run_mut M04 \
  '  | _ :: rest => observed rest' \
  '  | r :: _ => r' \
  'observed_is_the_last_stage, green_filter_masks_every_failure, piped_reading_is_blind, the [1,0] example'

# --- section 3: lookup failure vs absence -----------------------------------

# M05 -- the bare name starts resolving. `Plugin "rot-moe" not found` would then
# genuinely mean "not installed", and the correction recorded in this module
# would be wrong.
run_mut M05 \
  '  query == r.plugin ++ "@" ++ r.marketplace' \
  '  query == r.plugin' \
  'qualified_always_resolves, bare_name_never_resolves, lookup_failure_is_not_absence'

# --- section 4: the silent transcript ---------------------------------------

# M06 -- the conflation itself: the marker count becomes the firing count. Under
# this definition `marker seen in 0 transcript(s)` really would mean the hook
# never ran, and the 39 logged firings would be a contradiction.
run_mut M06 \
  'def markers (ts : List Turn) : Nat := (ts.filter (fun t => t.markerInTranscript)).length' \
  'def markers (ts : List Turn) : Nat := (ts.filter (fun t => t.hookRan)).length' \
  'any_number_of_firings_can_be_invisible, markers_zero_iff_all_sealed'

# M07 -- the seal inverted: a turn that LEAKED the trace is scored as sealed.
run_mut M07 \
  'def sealed (t : Turn) : Bool := !t.markerInTranscript' \
  'def sealed (t : Turn) : Bool := t.markerInTranscript' \
  'sealed_firing_exists, markers_zero_iff_all_sealed, a_marker_means_a_leak'

# M08 -- the mirror of M06: firings counted from the transcript instead of from
# the hook. This is how a session could report "0 firings" while the router ran
# on every turn.
run_mut M08 \
  'def firings (ts : List Turn) : Nat := (ts.filter (fun t => t.hookRan)).length' \
  'def firings (ts : List Turn) : Nat := (ts.filter (fun t => t.markerInTranscript)).length' \
  'any_number_of_firings_can_be_invisible'

# --- section 5: version string vs content -----------------------------------

# M09 -- the updater becomes content-aware. If this were true, a force-updated
# tag at an unchanged version WOULD reach existing installs, and the measured
# staleness of the CTT cache would have been impossible.
run_mut M09 \
  '  installed.version == published.version' \
  '  installed.content == published.content' \
  'force_update_at_same_version_reaches_no_install, update_verdict_cannot_decide_currency, only_a_moved_version_is_visible'

# M10 -- the defect promoted to a definition: being current MEANS having the
# same version string. This is precisely what `already at the latest version`
# asserts, and it is what the measurement refuted.
run_mut M10 \
  '  installed.content == published.content' \
  '  installed.version == published.version' \
  'force_update_at_same_version_reaches_no_install, update_verdict_cannot_decide_currency, reinstall_succeeds_where_update_is_blind'

# M11 -- a fresh install stops being content-addressed. The one path measured to
# actually deliver the new bytes (uninstall + install) would no longer do so.
run_mut M11 \
  'def freshInstall (published : Artifact) : Artifact := published' \
  'def freshInstall (published : Artifact) : Artifact := ⟨published.version, "stale"⟩' \
  'fresh_install_is_always_current, reinstall_succeeds_where_update_is_blind'

# --- §6, the release-provenance gap (MEASURED during the 0.9.x publication) ---

# M12 -- the digest stops being computed from the archive that was built. This is
# the honest-looking version of the defect: a digest published beside bytes it
# does not describe. If integrity were doing real work, this must break it.
run_mut M12 \
  'def package (tree : String) : Release := ⟨tree, digestOf tree⟩' \
  'def package (tree : String) : Release := ⟨tree, "sha256-of-something-else"⟩' \
  'packaging_always_passes_integrity, integrity_cannot_detect_the_wrong_tree, redownload_re_runs_the_blind_check'

# M13 -- provenance is asserted rather than checked: the archive is declared to
# come from the tag without comparing anything. Exactly the fake green the
# publication nearly shipped, promoted to a definition.
run_mut M13 \
  '  r.archive == (package tag).archive' \
  '  (tag.length == tag.length)' \
  'integrity_cannot_detect_the_wrong_tree, redownload_re_runs_the_blind_check, provenance_iff_same_tree'

# M14 -- the integrity check inverted. It would then FAIL on a correctly packaged
# release, which is the opposite failure and just as fatal.
run_mut M14 \
  'def integrityHolds (r : Release) : Bool := digestOf r.archive == r.digest' \
  'def integrityHolds (r : Release) : Bool := ! (digestOf r.archive == r.digest)' \
  'packaging_always_passes_integrity, integrity_cannot_detect_the_wrong_tree'

# --- LEAVE THE WORKSPACE USABLE --------------------------------------------
# Measured 2026-08-06: the source is restored from the backup, but the LAST
# mutant's build failed by design and produced no .olean, so the module's
# artifact stays MISSING after the suite exits. The next tool to look at it does
# not see "restored" -- it sees a module that cannot be imported:
#
#   axiom audit -> "the axiom probe did not elaborate (rc=1) ... object file
#                   Proofs/RotObserve.olean of module Proofs.RotObserve does not exist"
#   leanchecker -> reads the same absence as KERNEL REJECTED
#
# Restoring the SOURCE is not restoring the STATE. Rebuild, and say so out loud
# if the rebuild fails, because that would mean the restore itself was bad.
echo
printf 'restoring baseline artifact ... '
if ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotObserve ) >"$LOG/restore.log" 2>&1; then
  echo "OK (baseline rebuilt, .olean present)"
else
  echo "FAILED -- the restored source does NOT build. The tree is left BROKEN."
  echo "         Run: git checkout HEAD -- $F"
  tail -5 "$LOG/restore.log"
  exit 2
fi

echo
echo "=== RotObserve: $killed killed, $survived survived, $discarded discarded ==="
[ "$discarded" -gt 0 ] && echo "NOTE: discarded mutants tested NOTHING -- fix the needles, do not count them as survivors."
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && exit 0
exit 1
