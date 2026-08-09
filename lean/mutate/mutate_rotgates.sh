#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotGates.lean (the fast/deep gate split)
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
# WHAT THIS SUITE IS AIMED AT. The split it models is a mechanism that already
# produced one false green in this repo: a gate behind `FULL=1` was red while
# the default sweep reported 26/26 GREEN. So the mutations are not arbitrary
# edits -- each one RE-CREATES a way the split could silently stop protecting:
#
#   M01  the run drops fast gates          (what FULL=1 did)
#   M02  triggers match only exact paths   (a directory prefix stops escalating)
#   M03  an empty trigger list fires       (the silent hole, inverted)
#   M04  the two tiers overlap             (a gate in both, or in neither)
#   M05  every gate becomes fast           (the split silently does nothing)
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotGates.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotGates.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutgates.XXXXXX")"

[ -f "$F" ] || {
  echo "FATAL: $F not found. Refusing to run: every mutant would fail to build"
  echo "and be scored KILLED without a line having been mutated."
  exit 2
}

# --- NO-DOWNLOAD GUARD ------------------------------------------------------
# `lake build` RESOLVES the package first, and against the vendored `lean/` tree
# that resolution starts fetching mathlib INTO the repository (measured: 7.2 GB
# before it was caught, against a tree that ships as ~200 KB). A workspace that
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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotGates ) >/tmp/mut_pre_rotgates.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotGates)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotgates.log
  exit 2
fi
echo "preflight: baseline builds GREEN, $F present -- kills are attributable"

# --- SOURCE SANITY: a green baseline is NOT proof the source is intact -----
# Measured 2026-08-03, the hard way. A run of this suite was killed by a
# wall-clock timeout DURING `awk ... > "$F"`. The redirection truncates the
# file before awk writes, so the source was left at ZERO BYTES. The EXIT trap
# never ran (SIGKILL). Then the next run did `cp "$F" "$BAK"` and copied the
# EMPTY file over the only good backup, reported every needle as DISCARDED,
# and restored the emptiness. `rm -f "$BAK"` then deleted the evidence.
#
# The preflight could not see it: AN EMPTY LEAN FILE BUILDS GREEN. "The
# baseline compiles" is a weaker statement than it looks, so the source is
# checked for CONTENT before it is ever copied over the backup.
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotGates ) >/dev/null 2>&1' EXIT

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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotGates ) > "$LOG/$id.log" 2>&1
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
    # Attribution note, inherited from the RotGauge suite and just as true here:
    # the reported error lines are a LOWER BOUND on what died, not an inventory.
    # A mutant build produces no olean, so every theorem in the module is
    # unusable downstream regardless of which line the elaborator complained at.
    local dead
    dead=$(grep -oE "^error: Proofs/RotGates\.lean:[0-9]+" "$LOG/$id.log" \
      | grep -oE "[0-9]+$" | sort -un | while read -r ln; do
        awk -v L="$ln" '
          /^(theorem|def|private def|instance|structure|inductive|example)/ {
            if (NR <= L) { name=$0 }
          }
          END { if (name != "") print name }
        ' "$F"
      done | sed -E 's/^(private )?(theorem|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' \
      | sort -u | tr '\n' ',')
    local guards
    guards=$(grep -c "did not evaluate to .true." "$LOG/$id.log")
    if [ ! -f "$OLEAN" ]; then
      echo "$id  KILLED     exit=$ec  MODULE DEAD (no olean: every theorem unusable)"
      echo "        errors at: ${dead%,}  <- LOWER BOUND, not the full set"
      echo "        #guard failures: $guards"
      echo "        expected: $expect"
    else
      echo "$id  KILLED     exit=$ec  dead: ${dead%,}  guards failed: $guards"
    fi
    killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

echo "=== RotGates mutation suite ==="

# M01 -- the exact shape of the FULL=1 regression: the run stops including the
# gates that are supposed to be unconditional.
run_mut M01 \
  '  gs.filter (fun g => isFast g || fires g staged)' \
  '  gs.filter (fun g => fires g staged)' \
  'fast_always_runs, stagedRun_nil, and the count guards'

# M02 -- triggers stop being prefixes. `lean/` would no longer escalate on
# `lean/Proofs/RotGauge.lean`, so a proof edit would skip the Lean gates.
run_mut M02 \
  '  p.take trigger.length = trigger' \
  '  p = trigger' \
  'the staged-run count guards (directory prefixes stop matching)'

# M03 -- the silent hole, inverted: a gate with NO triggers starts firing, which
# would make `no_trigger_never_escalates` false.
run_mut M03 \
  '  staged.any (fun p => g.triggers.any (fun t => hits t p))' \
  '  staged.any (fun p => g.triggers.all (fun t => hits t p))' \
  'no_trigger_never_escalates, stagedRun_nil'

# M04 -- the tiers overlap instead of partitioning.
run_mut M04 \
  '  gs.filter (fun g => !isFast g)' \
  '  gs.filter (fun g => isFast g)' \
  'tiers_disjoint, tier_lengths, mem_tier_total, deepSet guards'

# M05 -- the split silently does nothing: every gate is fast again.
run_mut M05 \
  '  | Tier.deep => false' \
  '  | Tier.deep => true' \
  'the fastSet/deepSet count guards, the deep-trigger guard'

# --- the CI-honesty asymmetry (added after run 31045719329) ------------------
# M06 re-opens the exact hole that run found: let the `failure` arm consult
# `isScaffolding`, so a `Post ` step that FAILS becomes acceptable. This is the
# checker bug transcribed into the model. If nothing dies, the asymmetry is
# decoration and the law does not actually forbid the thing it was written for.
run_mut M06 \
  '  | _        => false' \
  '  | _        => s.isScaffolding' \
  'scaffolding_failure_is_still_dishonest, post_checkout_failure_is_dishonest, failure_sinks_the_run, honest_run_has_no_failure, and the run31045719329 guards'

# M07 -- the other direction: every skip is tolerated, scaffolding or not. This
# is the `bc1272d` defect ("gauge-cross had NEVER run") re-legalised.
run_mut M07 \
  '  | .skipped => s.isScaffolding' \
  '  | .skipped => true' \
  'any_authored_skip_is_dishonest, skipping_somewhere_is_still_dishonest, no_authored_skip_is_implied, and the run31035932155 guard'

# M08 -- the exemption widens to swallow authored steps. `isPrefixOf ""` is true
# of every name, so EVERY step becomes scaffolding. The narrowness of the
# scaffolding predicate is the only thing keeping the skip exemption honest.
run_mut M08 \
  '"Post ".isPrefixOf s.name' \
  '"".isPrefixOf s.name' \
  'any_authored_skip_is_dishonest and the run31035932155 guard (every name becomes scaffolding)'

# --- the exhaustive-dispatch law (added after the missing-`else` defect) ------
# M09 -- a dispatch that selected NO branch starts counting as evidence. This is
# the Windows leg of run 31052104913 exactly: the if/elif chain fell through and
# the step asserted things about a pty it never allocated.
run_mut M09 \
  '  | Option.none   => false' \
  '  | Option.none   => true' \
  'unselected_asserts_nothing, unselected_dispatch_is_as_green_as_a_skip, guard_is_exactly_assertion, and the windows #guard'

# M10 -- the artifact conjunct is dropped: naming a branch becomes enough, even
# if it produced nothing. Both conjuncts were violated on DIFFERENT platforms in
# the same run, so dropping either lets one leg back through.
run_mut M10 \
  '  | Option.some _ => d.producedArtifact' \
  '  | Option.some _ => true' \
  'selected_without_artifact_asserts_nothing, guard_is_exactly_assertion'

# --- M11 / M12 / M13: the tag-trigger law (measured defect, 2026-08-06) -------
#
# NOTE ON SHAPE, learned by getting it wrong here first. The post-check above
# requires the needle to be ABSENT after the edit. A replacement that merely
# EXTENDS the needle (`X` -> `X || Y`) still contains it, so all three of these
# were DISCARDED on their first run with `needle=1 repl=1`. That is the harness
# being right: an edit whose before-text is still present is not a clean
# mutation. Each replacement below is disjoint from its needle.

# M11 destroys the asymmetry that IS the defect -- a tag no longer fires when
# `branches` is absent. Under that (wrong, intuitive) model a `paths`-only
# trigger would not run on a tag, which is exactly what the three tag pushes of
# 2026-08-06 disproved.
run_mut M11 \
  '  | Ref.tag _    => t.branches.isEmpty' \
  '  | Ref.tag _    => t.branches.contains "v0.8.1"' \
  'paths_do_not_restrain_a_tag, branches_exclude_every_tag'

# M13 breaks the FIX rather than the defect: the branch arm stops firing at all.
# If no theorem dies, then nothing is checking that the repair kept `main`
# working -- a fix that silences the tag runs by silencing everything.
run_mut M13 \
  '  | Ref.branch n => t.branches.isEmpty || t.branches.contains n' \
  '  | Ref.branch n => false' \
  'the_fix_keeps_main'

# M12 widens the run-conclusion whitelist so that the conclusion measured on tag
# v0.8.1 would pass. This is the mutation that matters most: it is the exact
# shape of the "repair" someone reaches for when a cancelled run blocks a
# release. `only_success_is_honest` exists to make that impossible to land
# quietly, and this mutant is what proves it does.
run_mut M12 \
  'def runConcludedHonestly (conclusion : String) : Bool := conclusion == "success"' \
  'def runConcludedHonestly (conclusion : String) : Bool := conclusion != "failure"' \
  'cancelled_is_not_honest, only_success_is_honest'

echo
# --- RESTORE THE BASELINE ---------------------------------------------------
# The EXIT trap restores the SOURCE, but the last mutant deleted the .olean and
# nothing rebuilt it. Measured 2026-08-03: re-running a suite immediately after
# itself hit its own no-download guard and reported SKIP, because the workspace
# was no longer built -- and a later `leanchecker` sweep over the same tree would
# report `Could not find any oleans`, which reads as a KERNEL failure when it is
run_mut M14 \
  '  i.gate.triggers.any (fun t => hits t i.script)' \
  '  i.gate.triggers.all (fun t => hits t i.script)' \
  'self-triggering demands EVERY trigger match the script, not any'

echo

run_mut M15 \
  '            , triggers := [".github/workflows/".toList] }' \
  '            , triggers := ["checker/".toList] }' \
  'the measured before-row is given a trigger that DOES cover its script'

echo

run_mut M16 \
  '            , triggers := [".github/workflows/".toList, "checker/ci-honesty.sh".toList] }' \
  '            , triggers := ["checker/ci-honesty.sh".toList] }' \
  'the repaired row loses the original workflow trigger'

echo

# only a deleted artifact. A false red is as corrosive as a false green.
cp "$BAK" "$F"
if ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotGates ) >/tmp/mut_post_rotgates.log 2>&1; then
  echo "baseline restored and REBUILT green (olean present again)"
else
  echo "FATAL: the tree does not build after restore -- the suite left damage."
  tail -5 /tmp/mut_post_rotgates.log
  exit 2
fi
echo "killed=$killed survived=$survived discarded=$discarded"
if [ "$discarded" -ne 0 ]; then
  echo "REFUSING to report a verdict: $discarded mutation(s) did not apply."
  echo "A patch that did not land tells you nothing about the theorem."
  exit 2
fi
if [ "$survived" -ne 0 ]; then
  echo "$survived mutation(s) SURVIVED -- those theorems do not constrain the model."
  exit 1
fi
echo "ALL $killed MUTATIONS KILLED."
exit 0
