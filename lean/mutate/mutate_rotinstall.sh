#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# Mutation harness for Proofs/RotInstall.lean. Same contract: needle asserted
# present exactly once BEFORE, replacement present and needle gone AFTER, stale
# .olean deleted, exit code read directly, DISCARDED never folded into SURVIVED.
#
# I09 exists specifically because #print axioms flagged
# disarm_preserves_all_scalars as depending on no axioms. I10 is a PREDICTED
# SURVIVOR and is here to be honest about a coverage gap, not to pad the count.

set -u

# Repo-relative by construction: no machine-local path ships (R2).
# Override with LEAN_ROOT=... to run against a different workspace.
LEAN_ROOT="${LEAN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
F="$LEAN_ROOT/Proofs/RotInstall.lean"
BAK="$F.mutbak"
OLEAN="$LEAN_ROOT/.lake/build/lib/lean/Proofs/RotInstall.olean"
LOG="${TMPDIR:-/tmp}/muti"
mkdir -p "$LOG"
# --- PREFLIGHT: no green baseline, no attributable kills --------------------
# Added 2026-07-31 after two SIBLING suites were caught scoring 11 kills
# without ever opening a source file: their builds failed because the
# workspace was not there, and every such failure was recorded as KILLED.
# This suite resolved its paths correctly, but it shared the deeper defect --
# it never checked that the UNMUTATED tree builds. A kill measured against a
# red baseline cannot be attributed to the mutation that supposedly caused it.
[ -f "$F" ] || {
  echo "FATAL: $F not found. Refusing to run: every mutant would fail to build"
  echo "and be scored KILLED without a line having been mutated."
  exit 2
}
# --- NO-DOWNLOAD GUARD (measured 2026-07-31) --------------------------------
# The preflight below runs `lake build`, and lake RESOLVES THE PACKAGE first.
# Against the vendored `lean/` tree -- the default when LEAN_ROOT is unset, and
# what a contributor or a CI dry run therefore gets -- that resolution started
# fetching mathlib INTO THE REPOSITORY and reached 7.2 GB before it was caught.
# The tree ships as ~200 KB.
#
# A never-built workspace gets a SKIP (exit 3), not a build. A workspace that
# has never been built cannot satisfy this test, which is what makes the
# download impossible rather than merely unlikely. Exit 3 is reported as a skip
# by every caller and is never a pass.
_WSDIR="${LEAN_ROOT:-.}"
# THE EVIDENCE OF "ALREADY BUILT" MUST NOT BE THE ARTEFACT THIS SUITE DELETES.
# First version keyed on THIS module's .olean -- which every mutant removes on
# purpose (`rm -f "$OLEAN"`). An interrupted run therefore left the workspace
# looking never-built, and the next run SKIPPED a real workspace: a false skip,
# measured on Proofs.RotVacuity. The durable evidence is `.lake/packages` (which
# nothing here deletes) plus SOME built module, so the guard survives its own
# suite.
_built=$(find "$_WSDIR/.lake/build/lib/lean" -name '*.olean' 2>/dev/null | head -1)
if [ ! -d "$_WSDIR/.lake/packages" ] || [ -z "$_built" ]; then
  echo "SKIP: $_WSDIR is not a BUILT Lean workspace (.lake/packages or $OLEAN absent)."
  echo "      Refusing to invoke lake: resolving mathlib would DOWNLOAD ~7.2 GB"
  echo "      into a repository that ships as ~200 KB. Measured, once."
  echo "      Set LEAN_ROOT to an already-built workspace to run this suite."
  echo "      This is a SKIP (exit 3), never a pass."
  exit 3
fi

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotInstall ) >/tmp/mut_pre_rotinstall.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotInstall)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotinstall.log
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
killed=0; survived=0; discarded=0

# Map error line numbers back to the enclosing declaration.
#
# TWO KNOWN LIMITS, stated because an attribution that overstates its reach is
# the same defect as a mutation that did not apply:
#
#  1. This is LINE-based, not dependency-based. It names the declaration whose
#     elaboration errored -- not the full closure of theorems that depended on
#     it and are therefore also unproved. When a `def` is mutated, its own
#     lemmas error first and downstream theorems may still elaborate against
#     the broken lemma, so the `dead:` column UNDER-reports. The kill itself is
#     never in doubt (the build exit code is read directly); only the blast
#     radius is approximate.
#  2. An `example` is anonymous. Earlier it produced an empty `dead:` column,
#     which reads like "nothing died" when something did. It is now reported as
#     `example@<line>`.
attribute() {
  grep -oE "^error: Proofs/RotInstall\.lean:[0-9]+" "$1" | grep -oE "[0-9]+$" | sort -un | \
  while read -r ln; do
    awk -v L="$ln" '
      /^(@\[[^]]*\] )?(noncomputable )?(theorem|lemma|def|instance|structure|inductive|example)[ (:]/ {
        if (NR <= L) { name=$0; nline=NR }
      }
      END { if (name ~ /^example/) print "example@" nline; else if (name != "") print name }' "$F"
  done | sed -E 's/^@\[[^]]*\] *//; s/^(noncomputable )?(theorem|lemma|def|instance|structure|inductive) *//; s/[ ({:].*$//' \
    | sort -u | tr '\n' ' '
}

run_mut() {
  local id="$1" needle="$2" repl="$3" expect="$4"
  cp "$BAK" "$F"
  local n; n=$(grep -F -c -- "$needle" "$BAK")
  if [ "$n" -ne 1 ]; then
    echo "$id  DISCARDED  needle occurs $n times (expected 1)"; discarded=$((discarded+1)); return
  fi
  awk -v needle="$needle" -v repl="$repl" '{
    p = index($0, needle)
    if (p > 0) { $0 = substr($0,1,p-1) repl substr($0, p+length(needle)) }
    print
  }' "$BAK" > "$F"
  local an ar; an=$(grep -F -c -- "$needle" "$F"); ar=$(grep -F -c -- "$repl" "$F")
  if [ "$an" -ne 0 ] || [ "$ar" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed (needle=$an repl=$ar)"; discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi
  rm -f "$OLEAN"
  ( cd "$LEAN_ROOT" && lake build Proofs.RotInstall ) > "$LOG/$id.log" 2>&1
  local ec=$?
  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   expected: $expect"; survived=$((survived+1))
  else
    echo "$id  KILLED     dead: $(attribute "$LOG/$id.log") | expected: $expect"
    killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

# Occurrence-indexed, strictly LINE-ORIENTED variant.
#
# It exists because I01/I09 were DISCARDED on the first run: their needle
# spanned two lines, and `grep -F -c` treats an embedded newline as ALTERNATION,
# so it counted 3 matching lines and the guard correctly refused to proceed.
# That is the multi-line-surgery hazard, caught by the guard rather than by
# luck -- had the guard been a `>= 1` test, the patch would have half-applied
# and the run would have reported a meaningless result.
#
# `arm` and `disarm` both contain the byte-identical line `  scalar := s.scalar`,
# so no single-line needle can distinguish them. The index does: occurrence 1 is
# inside `arm` (it appears first in the file), occurrence 2 inside `disarm`.
# The total count is asserted to be exactly 2 before either is touched, so a
# refactor that adds a third makes this DISCARD instead of mutating the wrong one.
run_mut_nth() {
  local id="$1" idx="$2" total="$3" needle="$4" repl="$5" expect="$6"
  cp "$BAK" "$F"
  local n; n=$(grep -F -c -- "$needle" "$BAK")
  if [ "$n" -ne "$total" ]; then
    echo "$id  DISCARDED  needle occurs $n times (expected exactly $total)"
    discarded=$((discarded+1)); return
  fi
  awk -v needle="$needle" -v repl="$repl" -v want="$idx" '
    { p = index($0, needle)
      if (p > 0) { seen++
        if (seen == want) { $0 = substr($0,1,p-1) repl substr($0, p+length(needle)) }
      }
      print }' "$BAK" > "$F"
  local an ar; an=$(grep -F -c -- "$needle" "$F"); ar=$(grep -F -c -- "$repl" "$F")
  if [ "$an" -ne $((total-1)) ] || [ "$ar" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed (needle=$an want=$((total-1)) repl=$ar)"
    discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi
  rm -f "$OLEAN"
  ( cd "$LEAN_ROOT" && lake build Proofs.RotInstall ) > "$LOG/$id.log" 2>&1
  local ec=$?
  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   expected: $expect"; survived=$((survived+1))
  else
    echo "$id  KILLED     dead: $(attribute "$LOG/$id.log") | expected: $expect"
    killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

echo "=== RotInstall mutation suite ==="

run_mut_nth I01 1 4 \
  '  scalar := s.scalar' \
  '  scalar := fun _ => none' \
  'arm_preserves_all_scalars (installer wipes every scalar key)'

run_mut I02 \
  '  hookEvents := fun k => if k ∈ armEvents then addOnce cmd (s.hookEvents k) else s.hookEvents k' \
  '  hookEvents := fun k => addOnce cmd (s.hookEvents k)' \
  'arm_preserves_unrelated_events (router registered on EVERY event)'

run_mut I03 \
  '  if c ∈ l then l else l ++ [c]' \
  '  l ++ [c]' \
  'arm_idempotent (dedupe removed -> running twice registers twice)'

run_mut I04 \
  'def addOnce (c : String) (l : List String) : List String :=' \
  'def addOnce (c : String) (_l : List String) : List String := [c] --' \
  'arm_preserves_existing_hooks, arm_appends, disarm_arm_id (installer REPLACES the users hooks)'

run_mut I05 \
  '  hookEvents := fun k => if k ∈ armEvents then addOnce cmd (s.hookEvents k) else s.hookEvents k' \
  '  hookEvents := fun k => s.hookEvents k' \
  'arm_adds_the_hooks (installer does nothing -- the non-vacuity anchor)'

run_mut I06 \
  '  hookEvents := fun k => (s.hookEvents k).filter (fun c => c != cmd)' \
  '  hookEvents := fun k => (s.hookEvents k).filter (fun _ => true)' \
  'disarm_removes, disarm_arm_id (uninstaller removes nothing)'

run_mut I07 \
  '  hookEvents := fun k => (s.hookEvents k).filter (fun c => c != cmd)' \
  '  hookEvents := fun _ => []' \
  'disarm_preserves_others (uninstaller removes EVERYTHING)'

run_mut I08 \
  '  if c ∈ l then l else l ++ [c]' \
  '  if c ∈ l then l else [c] ++ l' \
  'arm_appends (router PREPENDED -- users hooks now fire after ours)'

run_mut_nth I09 2 4 \
  '  scalar := s.scalar' \
  '  scalar := fun _ => none' \
  'disarm_preserves_all_scalars -- the axiom-free theorem, on trial for vacuity'

run_mut I10 \
  'def armEvents : List String := ["UserPromptSubmit", "PreToolUse"]' \
  'def armEvents : List String := ["UserPromptSubmit"]' \
  'PREDICTED SURVIVOR of the theorems (all quantify over armEvents, not its contents) but MUST kill the pinning example at the foot of the file'


# --- THE PLAN MUTANTS -------------------------------------------------------
# Added 2026-08-05 with the install-plan section. A new definition inherits none
# of the old theorems' coverage: when `armOn` and `disarmPlan` first appeared,
# wiping their `scalar` field killed NOTHING, because no theorem named them. The
# suite reported it as two DISCARDED needles (`scalar := s.scalar` had gone from
# two occurrences to four) -- which is the harness saying "I tested nothing",
# not "the code is fine". Both readings had to be repaired: the counts below,
# and the missing theorems in the module.

run_mut_nth I11 3 4 \
  '  scalar := s.scalar' \
  '  scalar := fun _ => none' \
  'armPlan_preserves_all_scalars (arming a PLAN wipes every scalar key)'

run_mut_nth I12 4 4 \
  '  scalar := s.scalar' \
  '  scalar := fun _ => none' \
  'disarmPlan_preserves_all_scalars (uninstalling a PLAN wipes every scalar key)'

# The event list of a binding is what the installer could not express before the
# fix. If `armOn` ignores it and arms every event, `armPlan_untouched_event`
# must die -- that theorem IS the parity guarantee.
run_mut I13 \
  '  hookEvents := fun k => if k ∈ evs then addOnce cmd (s.hookEvents k) else s.hookEvents k' \
  '  hookEvents := fun k => addOnce cmd (s.hookEvents k)' \
  'armPlan_untouched_event (a plan arms EVERY event, ignoring its binding lists)'

# The uninstaller that removes nothing. `disarmPlan_removes_its_own` is the
# theorem that forbids the residue the round trip caught on disk.
run_mut I14 \
  '  hookEvents := fun k => (s.hookEvents k).filter (fun c => !(p.any (fun b => b.1 == c)))' \
  '  hookEvents := fun k => s.hookEvents k' \
  'disarmPlan_removes_its_own (plan uninstall is a no-op -- the measured residue)'

# THE SHIPPED PLAN ITSELF. Dropping the reminder reproduces the exact defect
# this section documents, and the concrete guards plus
# `shipped_plan_reaches_every_declared_event` must all fail.
run_mut I15 \
  'def shippedPlan : List Binding := [routerBinding, remindBinding]' \
  'def shippedPlan : List Binding := [routerBinding]' \
  'shipped_plan_reaches_every_declared_event + the PostToolUse guards (the measured parity gap, restored)'

# And the third event alone -- the one no installer could reach. This is the
# narrowest possible statement of the original bug.
run_mut I16 \
  '  ("prover-remind", ["UserPromptSubmit", "PreToolUse", "PostToolUse"])' \
  '  ("prover-remind", ["UserPromptSubmit", "PreToolUse"])' \
  'the PostToolUse guards (reminder loses the event the plugin binds it to)'
cp "$BAK" "$F"
rm -f "$OLEAN"
( cd "$LEAN_ROOT" && lake build Proofs.RotInstall ) > "$LOG/baseline.log" 2>&1
base=$?
echo "---"
# --- RESTORE THE BASELINE ---------------------------------------------------
# The EXIT trap restores the SOURCE, but the last mutant deleted the .olean and
# nothing rebuilt it. Measured 2026-08-03: re-running a suite immediately after
# itself hit its own no-download guard and reported SKIP, because the workspace
# was no longer built -- and a later `leanchecker` sweep over the same tree would
# report `Could not find any oleans`, which reads as a KERNEL failure when it is
# only a deleted artifact. A false red is as corrosive as a false green.
cp "$BAK" "$F"
if ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotInstall ) >/tmp/mut_post_rotinstall.log 2>&1; then
  echo "baseline restored and REBUILT green (olean present again)"
else
  echo "FATAL: the tree does not build after restore -- the suite left damage."
  tail -5 /tmp/mut_post_rotinstall.log
  exit 2
fi
echo "killed=$killed survived=$survived discarded=$discarded"
echo "baseline restored -> lake build exit=$base"
rm -f "$BAK"

# --- THE VERDICT GATE -------------------------------------------------------
# This suite used to end on `rm -f "$BAK"`, whose exit status is 0, so the run
# reported success no matter what it measured. Verified 2026-08-03 on RotRoute:
# 11 of 11 mutants DISCARDED -- nothing tested at all -- and the suite exited 0,
# which CI reads as a pass. SURVIVED and DISCARDED mean opposite things and
# neither is a pass: one says the theorem does not constrain the model, the
# other says this harness did not run.
if [ "$survived" -ne 0 ] || [ "$discarded" -ne 0 ]; then
  echo "NOT A PASS: survived=$survived discarded=$discarded"
  echo "  survived  = the theorem does not constrain the model."
  echo "  discarded = the patch never landed; this harness tested nothing."
  exit 1
fi
echo "ALL $killed MUTATIONS KILLED."
exit 0
