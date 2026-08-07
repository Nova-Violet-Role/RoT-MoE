#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotLog.lean, THE DEBUG LOG AND ITS ROUTING AUDIT.
#
# This file was derived from mutate_rotmutant.sh, and the first version of this
# header came with it -- describing `firesWord_imp_fires` and a set of MATCHER
# mutations that live in RotStem and appear nowhere below. A header that
# describes a different module is not a cosmetic defect: it is the file telling
# a reader, in its own voice, that it tests something it does not test. It is
# recorded here rather than silently overwritten, because "derived from a
# sibling" is exactly when this happens.
#
# WHY THIS SUITE EXISTS. RotLog is the module that decides whether a DEBUG LOG
# can be believed -- the artifact a user hands over when the router misbehaves.
# It had theorems from the first Lean release and never a suite, so nothing had
# ever tried to break them. The routing audit made that worse before it made it
# better: its claim is that a route record's `stem` explains its `lane`, and
# that passing the audit ENTAILS the log carries no prompt text. A privacy
# claim resting on an unmutated theorem is the least defensible thing here.
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
# The ten mutants are described where they are written, at the bottom of this
# file, next to the needles they use -- so a needle that moves and the sentence
# explaining it cannot drift apart.
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutlog.XXXXXX")"
MODULES="RotLog"

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
if [ ! -d "$_WSDIR/.lake/packages" ] || [ ! -f "$_WSDIR/.lake/build/lib/lean/Proofs/RotLog.olean" ]; then
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

echo "=== RotLog mutation suite (the debug log, and the routing audit in it) ==="

# WHY THESE MUTATIONS. Each one is a way the audit could be weakened while the
# file still compiled and every checker stayed green:
#
#   L01  the empty-stem clause flips to CONVERGENT-means-anything -- the audit
#        stops rejecting a lane that fired while naming nothing
#   L02  `laneOfStem` stops requiring the OWNING lane and accepts any lane that
#        exists, which is precisely a mis-route certified as correct
#   L03  the vocabulary check admits anything, which is the leak: prompt text in
#        the stem field would pass
#   L04  `find?` becomes "last owner wins", inverting the priority order the
#        router's table encodes
#   L05  the mis-route example is edited to a lane that DOES own the stem, so
#        `vocabSafe_not_imp_auditable` would have nothing to witness
#   L06  the duplicate-stem detector is made to accept duplicates
#   L07  the non-vacuity row for that detector is pointed at a table with no
#        duplicate, so the control would certify itself
#   L08  the shipped table loses a stem that a live measurement recorded, which
#        is the drift between the router and the spec this file exists to catch
#   L09  the pairing tolerance is widened past the rounding rule
#   L10  `consistent_Rs_eq_gauge`'s conclusion is weakened to an inequality

run_mut L01 RotLog \
  'if r.stem = "" then r.lane = "CONVERGENT" else laneOfStem t r.stem = some r.lane' \
  'if r.stem = "" then True else laneOfStem t r.stem = some r.lane' \
  'empty_stem_iff_convergent, and the example rejecting FORGE with no stem'

run_mut L02 RotLog \
  'laneOfStem t r.stem = some r.lane' \
  '(laneOfStem t r.stem).isSome = true' \
  'the mis-route example, auditable_imp_vocabSafe, vocabSafe_not_imp_auditable'

run_mut L03 RotLog \
  'r.stem = "" ∨ r.stem ∈ vocab t' \
  'r.stem = "" ∨ True' \
  'the leaked-text example on VocabSafe'

run_mut L04 RotLog \
  '(t.find? (fun p => p.2.contains s)).map Prod.fst' \
  '(t.reverse.find? (fun p => p.2.contains s)).map Prod.fst' \
  'first_owner_wins, second_owner_reachable'

run_mut L05 RotLog \
  '{ lane := "STEALTH", stem := "prove" }, Or.inr ?_, by decide' \
  '{ lane := "FORGE", stem := "prove" }, Or.inr ?_, by decide' \
  'vocabSafe_not_imp_auditable -- its witness would no longer be a counterexample'

run_mut L06 RotLog \
  'v.all (fun s => (v.filter (fun x => x == s)).length == 1)' \
  'v.all (fun s => (v.filter (fun x => x == s)).length >= 1)' \
  'the non-vacuity row: noDuplicateStems would accept a duplicated stem'

run_mut L07 RotLog \
  'noDuplicateStems [("FORGE", ["lean"]), ("STEALTH", ["lean"])] = false' \
  'noDuplicateStems [("FORGE", ["lean"]), ("STEALTH", ["qed"])] = false' \
  'the duplicate detectors own control'

run_mut L08 RotLog \
  '"tactic","sorry","mathlib",".lean","prove","proof","lemma","lean","qed"' \
  '"tactic","sorry","mathlib",".lean","proof","lemma","lean","qed"' \
  'the FORGE/prove example measured live against the shipped router'

# L09 and L10 were first written from MEMORY of this file's contents and both
# were DISCARDED on the first run -- needle occurs 0 times. The values below are
# read off RotLog.lean:203 and :77. Recording the miss rather than quietly
# fixing it: a discard is the harness reporting on itself, and the two rounds it
# cost are the argument for measuring a needle instead of recalling one.
# L09 SURVIVED at 1/2 on the first honest run, and the survival was informative
# rather than embarrassing: `mismatched_pair_detected` rejects the pair (0, 1),
# whose gap is 1, so ANY tolerance below 1 still rejects it. 1/2 was not a
# weakening of the claim, it was a mutation too small to reach it. The mutant is
# corrected upward instead of the theorem being adjusted downward -- the
# survivor was evidence about this harness, and a survivor is never a licence to
# soften what it failed to kill.
run_mut L09 RotLog \
  'noncomputable def displayEps : ℝ := 1 / 200' \
  'noncomputable def displayEps : ℝ := 200' \
  'mismatched_pair_detected -- 0 and 1 would count as a faithful rounding'

run_mut L10 RotLog \
  'r.Rs * (r.K : ℝ) = r.sum' \
  'r.Rs * (r.K : ℝ) ≥ 0' \
  'consistent_Rs_eq_gauge, consistent_Rs_unique, inconsistent_witness'

echo
echo "killed=$killed survived=$survived discarded=$discarded"
echo
# --- back to a VERIFIED green baseline ---------------------------------------
# The contract at the top of this file promises step 5: "restore from the backup,
# ALWAYS, and rebuild to a verified green baseline". The EXIT trap does the first
# half. Nothing did the second, and the header said otherwise -- so this suite
# ended with the source correct and NO OLEAN, because the last mutant's build
# failed and its artifact was deleted before it ran.
#
# That is not cosmetic. `checker/axiom-class.sh` imports the module to probe it,
# and a missing olean makes it report "18 unaccounted for" -- a red that looks
# exactly like a broken proof and is really a leftover from a suite that ran to
# completion. It cost a full attribution cycle to tell those two apart.
#
# A harness that leaves the tree unbuildable has not finished, whatever its
# summary says.


# --- StepProbe: the CI-red incident of 2026-08-07 ---------------------------
# A gate went RED on a correct commit because the step-log probe guessed how
# GitHub rewrites '/' in a filename. These four mutants are what keep the
# repair load-bearing rather than a comment about a past outage.

# The wildcard removed: the probe goes back to demanding a literal slash, which
# is what no sanitised filename ever contains. This is the CI-red defect itself.
run_mut L11 RotLog \
  'then Pat.any else Pat.lit c' \
  'then Pat.lit c else Pat.lit c' \
  'wildProbe_patMatches_any_substitution'

# A wildcard that swallows the rest of the string. Matches everything from that
# point on, so a truncated or wrong filename would pass.
run_mut L12 RotLog \
  '  | Pat.any :: ps, _ :: ds => patMatches ps ds' \
  '  | Pat.any :: ps, _ :: ds => true' \
  'wildProbe_rejects_a_truncated_name'

# Literals stop being compared. The probe then matches any name of the right
# length -- a green that means nothing.
run_mut L13 RotLog \
  '  | Pat.lit c :: ps, d :: ds => (c == d) && patMatches ps ds' \
  '  | Pat.lit c :: ps, d :: ds => patMatches ps ds' \
  'wildProbe_still_rejects_a_different_name'

# The runner is modelled as rewriting NOTHING, which is the assumption that made
# the old probe look correct. If sanitisation is a no-op the bug is invisible.
run_mut L14 RotLog \
  'then sub else c' \
  'then c else c' \
  'guessProbe_misses_when_the_guess_is_wrong'

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
echo "baseline restored and REBUILT green -- the workspace is as it was found"

if [ "$discarded" -gt 0 ]; then
  echo "DISCARDED > 0: at least one patch never landed, so it tested NOTHING."
  echo "A discard is a defect in this harness, never evidence about a theorem."
  exit 1
fi
if [ "$survived" -gt 0 ]; then
  echo "SURVIVED > 0: a theorem tolerated a mutation it should have caught."
  exit 1
fi
echo "every mutant KILLED -- the log's theorems are load-bearing"
exit 0
