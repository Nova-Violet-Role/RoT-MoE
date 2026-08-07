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

# --- OPTIONAL FILTER, AND WHY A PARTIAL RUN MUST LOOK PARTIAL ----------------
# The suite is 48 mutants and each one rebuilds the module, so a full pass
# outgrew the wall-clock ceiling of the agent that runs it -- and MEASURED
# 2026-08-07, being killed at that ceiling left a MUTATED RotObserve.lean on
# disk beside its .mutbak. Chunking is the fix; pretending a chunk is the suite
# would be much worse than the timeout.
#
#   MUT_ONLY="M45 M46"   run only those, everything else SKIPPED
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

# --- §7, the audit that silently narrows its own scope ----------------------

# M15 -- the control stops checking anything. This is the state the checker was
# in before 14382b0: no control at all, and a classifier free to drop harnesses
# without anyone noticing.
run_mut M15 \
  'def controlHolds (sel : Nat → Bool) (required : List Nat) : Bool := required.all sel' \
  'def controlHolds (_sel : Nat → Bool) (_required : List Nat) : Bool := true' \
  'control_detects_the_drop'

# M16 -- the audit judges every candidate instead of only the selected ones.
# If that were true there would be no gap to prove, so both §7 theorems about
# the gap must die.
run_mut M16 \
  '  (xs.filter sel).all judge' \
  '  xs.all judge' \
  'passing_audit_can_hide_a_failure, the_verdict_cannot_see_the_drop'

# M17 -- the control weakened from ALL to ANY: it would pass as long as ONE
# required harness was selected. That is the plausible wrong version, and the
# one most likely to be written by accident.
run_mut M17 \
  'def controlHolds (sel : Nat → Bool) (required : List Nat) : Bool := required.all sel' \
  'def controlHolds (sel : Nat → Bool) (required : List Nat) : Bool := required.any sel' \
  'control_detects_the_drop, control_holds_when_nothing_is_dropped'

# --- §8, the step that could only skip --------------------------------------

# M18 -- the always-skipping step given a reachable outcome. If that were the
# real shape there would be nothing to prove, so the theorem must die.
run_mut M18 \
  'def alwaysSkips (_world : Nat) : Outcome := Outcome.skip' \
  'def alwaysSkips (world : Nat) : Outcome := if world == 0 then Outcome.pass else Outcome.skip' \
  'a_step_that_only_skips_is_not_evidence'

# M19 -- the corpus re-derivation neutered to `true`. This is THE mutation that
# matters: it is exactly what happens if gauge-cross.sh stops checking the
# corpus against Lean, and the theorem that says the platform check transfers to
# the model must stop holding.
run_mut M19 \
  'def corpusMatchesModel (corpus model : Nat) : Bool := corpus == model' \
  'def corpusMatchesModel (_corpus _model : Nat) : Bool := true' \
  'verified_corpus_transfers_to_the_model'

# M20 -- the replacement step made unable to fail, i.e. the exact defect it was
# written to remove. A step that always passes is the same kind of decoration as
# one that always skips.
run_mut M20 \
  '  if hookMatchesCorpus hook 49 then Outcome.pass else Outcome.fail' \
  '  Outcome.pass' \
  'the_corpus_step_is_evidence'

# --- §9, the evidence counter that increments in the failure path -----------

# M21 -- the repair reverted: drop the "did any turn succeed" conjunct and the
# success-aware verdict IS the blind one. This is the exact line that was
# missing on 2026-08-06, so if the theorem survives it, the theorem is not
# guarding the fix.
run_mut M21 \
  '  ts.any (fun t => t.ok) && recordsOf ts != 0' \
  '  recordsOf ts != 0' \
  'success_aware_verdict_detects_total_failure'

# M22 -- the blind verdict taught to read outcomes. Then total failure would NOT
# pass it, and the theorem recording the measured green must die.
run_mut M22 \
  'def sideEffectVerdict (ts : List SessionTurn) : Bool := recordsOf ts != 0' \
  'def sideEffectVerdict (ts : List SessionTurn) : Bool := ts.any (fun t => t.ok)' \
  'total_failure_passes_the_side_effect_verdict'

# M23 -- the over-correction: a verdict that refuses everything. It would satisfy
# "detects total failure" while being useless, which is why the pass-a-real-run
# theorem exists to kill it.
run_mut M23 \
  '  ts.any (fun t => t.ok) && recordsOf ts != 0' \
  '  false' \
  'success_aware_verdict_still_passes_a_real_run'

# --- §10, the detector satisfied by the test's own setup --------------------

# M24 -- the loose detector tightened. Then it would NOT be constant after
# setup, and the theorem recording the measured CI defect must die.
run_mut M24 \
  'def looseDetector (e : Precondition) : Bool := e.hasCredential || e.hasOwnArtifact' \
  'def looseDetector (e : Precondition) : Bool := e.hasCredential' \
  'loose_detector_is_constant_after_setup'

# M25 -- the strict detector loosened back to the shipped defect. This is the
# exact line that was deleted from live-session-smoke.sh, so the invariance
# theorem must not survive it.
# NOTE THE SHAPE OF THIS NEEDLE. The obvious mutation -- widening the body to
# `e.hasCredential || e.hasOwnArtifact` -- was DISCARDED on the first run,
# because the replacement CONTAINS the needle, so the post-check that verifies
# the needle is gone can never pass. That is the M11-M13 trap this repository
# already recorded, and it reports as `discarded`, never as `survived`.
# Reading the detector off the wrong field is disjoint and tests the same thing.
run_mut M25 \
  'def strictDetector (e : Precondition) : Bool := e.hasCredential' \
  'def strictDetector (e : Precondition) : Bool := e.hasOwnArtifact' \
  'strict_detector_survives_setup'

# --- §11, link versus copy --------------------------------------------------

# M26 -- the link made to behave like a copy. If that were true a link WOULD be
# one-way and the theorem saying it is not must fail.
run_mut M26 \
  'def writeThroughLink (_c : Creds) (v : Nat) : Creds := { live := v, test := v }' \
  'def writeThroughLink (c : Creds) (v : Nat) : Creds := { c with test := v }' \
  'a_link_lets_the_test_overwrite_the_live_credential'

# M27 -- the copy made to write back, which is precisely what a symlink would
# do. The isolation property must die with it.
run_mut M27 \
  'def writeInTest (c : Creds) (v : Nat) : Creds := { c with test := v }' \
  'def writeInTest (_c : Creds) (v : Nat) : Creds := { live := v, test := v }' \
  'a_copy_never_propagates_backwards'

# M28 -- the refresh neutered so it carries nothing forward. Then the copy would
# be one-way by being inert, which is the useless version of the design.
run_mut M28 \
  'def refreshCopy (c : Creds) : Creds := { c with test := c.live }' \
  'def refreshCopy (c : Creds) : Creds := c' \
  'a_copy_carries_the_original_forward'

# --- §12, a check reachable only through the thing it checks ----------------

# M29 -- the permissive hook made to refuse red trees. Then a swapped hook would
# be harmless and the theorem recording the measured disarm must die.
run_mut M29 \
  '  | .permissive, _ => true' \
  '  | .permissive, _ => t.green' \
  'swap_makes_admission_uninformative'

# M30 -- the out-of-band verifier blinded. It then agrees with the in-band one
# in both worlds, so the theorem that it SEPARATES them must fail.
run_mut M30 \
  '  | .permissive => true' \
  '  | .permissive => false' \
  'out_of_band_detector_sees_the_replacement'

# M31 -- the in-band audit made to fire when replaced, which is exactly the
# capability it does not have. The blindness theorem must die.
run_mut M31 \
  '  | .permissive => false    -- never runs, so it reports nothing at all' \
  '  | .permissive => true     -- pretends it still runs' \
  'in_band_detector_is_blind_to_its_own_replacement'

# M32 -- the real gate turned permissive. If this survived, `admits .gate` would
# not be a gate at all.
run_mut M32 \
  '  | .gate, t => t.green' \
  '  | .gate, _ => true' \
  'gate_admits_exactly_green'

# --- §13, a bound below the cost silences a working component ---------------

# M33 -- the observation inverted. A completed hook would emit nothing and a
# killed one would emit the marker, so both the adequacy theorem and the
# measured instance must die.
run_mut M33 \
  '  if completes bound w then some "marker" else none' \
  '  if completes bound w then none else some "marker"' \
  'an_adequate_bound_is_observed'

# M34 -- "no hook installed" made to emit a marker. The indistinguishability
# theorem is then false: silence would no longer look like absence, and the
# whole reason the defect hid for weeks would evaporate.
run_mut M34 \
  'def absentOutput : Option String := none' \
  'def absentOutput : Option String := some "marker"' \
  'silenced_is_indistinguishable_from_absent'

# M35 -- the witness weakened to work BOTH bounds complete. The two products
# then agree on it, so the existence claim behind the agreement check dies.
run_mut M35 \
  '  refine ⟨⟨b₁ + 1⟩, ?_⟩' \
  '  refine ⟨⟨b₁⟩, ?_⟩' \
  'different_bounds_are_different_products'

# M36 -- the comparison reversed, so a hook "completes" only when its cost
# EXCEEDS the bound. Monotonicity and adequacy both rest on this direction.
run_mut M36 \
  'def completes (bound : Nat) (w : Work) : Bool := decide (w.cost ≤ bound)' \
  'def completes (bound : Nat) (w : Work) : Bool := decide (bound ≤ w.cost)' \
  'completion_is_monotone'

# --- §14, what an endpoint can attribute ------------------------------------

# M37 -- attribution turned into a SUM. The excess over the control arm becomes
# a total, so the leak metric that measured 9 treated against 12 control would
# report 21 "attributable" occurrences of a mechanism that was switched off.
run_mut M37 \
  'def attributable (m : Endpoint) : Nat := m treated - m control' \
  'def attributable (m : Endpoint) : Nat := m treated + m control' \
  'control_at_least_treated_attributes_nothing'

# M38 -- "improved" reversed, so scoring HIGHER with the mechanism counts as a
# win. Both floor theorems rest on the direction of this comparison.
run_mut M38 \
  'def improved (m : Endpoint) : Prop := m treated < m control' \
  'def improved (m : Endpoint) : Prop := m control < m treated' \
  'floor_endpoint_cannot_improve'

# M39 -- separation redefined as EQUALITY: identical arms would then "separate",
# which is the precise inversion of what a paired endpoint means.
run_mut M39 \
  'def separates (m : Endpoint) : Prop := m treated ≠ m control' \
  'def separates (m : Endpoint) : Prop := m treated = m control' \
  'equal_arms_attribute_nothing'

# M40 -- the win predicate loosened to include ties. Eighty tied pairs would
# then read as eighty wins, which is exactly the false positive the sign-count
# theorem exists to forbid.
run_mut M40 \
  '(ps.filter (fun p => decide (p.1 < p.2))).length' \
  '(ps.filter (fun p => decide (p.1 ≤ p.2))).length' \
  'all_ties_leave_no_sign_count'

# --- §15, the mismatch that renders identically ------------------------------

# M41 -- the screen stops hiding CR. If rendering were faithful, the whole
# section would be unnecessary: `0.09 != 0.09` could not have happened.
run_mut M41 \
  'def shown (f : Field) : Field := f.filter (fun c => c != Cell.cr)' \
  'def shown (f : Field) : Field := f' \
  'shown_can_hide_a_real_difference'

# M42 -- normalisation inverted: keep ONLY the carriage returns. A checker that
# stripped this way would compare two empty fields and pass everything.
run_mut M42 \
  'def stripCell (f : Field) : Field := f.filter (fun c => c != Cell.cr)' \
  'def stripCell (f : Field) : Field := f.filter (fun c => c == Cell.cr)' \
  'stripCell_faithful'

# M43 -- the escape drops CR instead of showing it, which is precisely the
# useless failure message this section exists to replace.
run_mut M43 \
  '  | Cell.cr      => [Glyph.backslash, Glyph.rLetter]' \
  '  | Cell.cr      => []' \
  'escape_injective'

# M44 -- the control example weakened to compare a field with itself. A control
# that cannot fail is not a control, and this proves the one in §15 is real.
run_mut M44 \
  '      stripCell [Cell.digit 0, Cell.dot, Cell.digit 1, Cell.digit 9] := by decide' \
  '      stripCell [Cell.digit 0, Cell.dot, Cell.digit 0, Cell.digit 9] := by decide' \
  'stripCell_faithful'

# --- §16, the interrupted mutation run ---------------------------------------

# M45 -- the backup step becomes a no-op, which is exactly "mutate first". The
# original then exists nowhere the moment the mutant is written.
run_mut M45 \
  'def saveBackup (d : Disk) : Disk := { d with backup := some d.live }' \
  'def saveBackup (d : Disk) : Disk := d' \
  'backup_then_mutate_is_recoverable'

# M46 -- restore leaves the backup behind, so the next run sees a repaired tree
# as an interrupted one and recovers forever.
run_mut M46 \
  '  | some b => { live := b, backup := none }' \
  '  | some b => { live := b, backup := some b }' \
  'restore_clears_the_backup'

# M47 -- dropping the backup becomes harmless, which would make "rm the stray
# .mutbak" a safe cleanup. It is the one irreversible move there is.
run_mut M47 \
  'def dropBackup (d : Disk) : Disk := { d with backup := none }' \
  'def dropBackup (d : Disk) : Disk := d' \
  'dropping_the_backup_loses_the_original'

# M48 -- recoverability demands BOTH copies instead of either, so a correctly
# backed-up mutant would read as unrecoverable and the guard would fire always.
run_mut M48 \
  '  d.live = orig ∨ d.backup = some orig' \
  '  d.live = orig ∧ d.backup = some orig' \
  'backup_then_mutate_is_recoverable'

# --- §17, atomicity that loses the mode --------------------------------------

# M49 -- the fresh temp is given the exec bit, so the CI failure this section
# records could not have happened. If this survives, the section is fiction.
run_mut M49 \
  'def freshTemp (c : Blob) : Entry := { content := c, exec := false }' \
  'def freshTemp (c : Blob) : Entry := { content := c, exec := true }' \
  'fresh_temp_drops_the_exec_bit'

# M50 -- the clone stops carrying the original's attributes, i.e. the repair is
# undone and cloning becomes just another fresh temp.
run_mut M50 \
  'def clonedTemp (orig : Entry) (c : Blob) : Entry := { orig with content := c }' \
  'def clonedTemp (_orig : Entry) (c : Blob) : Entry := { content := c, exec := false }' \
  'cloned_temp_preserves_the_exec_bit'

# M51 -- the rename keeps the TARGET instead of the temp. That would make every
# write a silent no-op: contents never change, and no mutant would ever kill.
run_mut M51 \
  'def renameOver (_target : Entry) (temp : Entry) : Entry := temp' \
  'def renameOver (target : Entry) (_temp : Entry) : Entry := target' \
  'cloned_temp_still_writes'

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
if [ "$filtered" -eq 1 ]; then
  echo "=== RotObserve: PARTIAL RUN (MUT_ONLY='$MUT_ONLY') -- $killed killed, $survived survived, $discarded discarded, $skipped SKIPPED ==="
  echo "NOT a suite result. $skipped mutants were never applied and prove nothing."
  [ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && exit 3
  exit 1
fi
echo "=== RotObserve: $killed killed, $survived survived, $discarded discarded ==="
[ "$discarded" -gt 0 ] && echo "NOTE: discarded mutants tested NOTHING -- fix the needles, do not count them as survivors."
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && exit 0
exit 1
