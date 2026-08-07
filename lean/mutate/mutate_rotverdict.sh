#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# Mutation suite for Proofs/RotVerdict.lean.
#
# A theorem no mutation kills is decoration. Each mutant below breaks the MODEL
# in a way a careless edit really could, and the theorems must die.
#
# Three rules, learned the hard way in this repo:
#   1. ASSERT THE NEEDLE IS PRESENT before building. A patch that silently fails
#      to apply produces a green build and gets scored SURVIVED, which reads as
#      "robust" and means "nothing was tested".
#   2. DELETE THE STALE .olean. Lake is incremental and will happily not rebuild.
#   3. DISCARDED is not SURVIVED. One is a claim about the harness, the other
#      about the theorem.

#   4. A KILL IS ONLY A KILL IF THE BASELINE WAS GREEN. Added 2026-07-31 after
#      this suite was caught reporting 5 KILLED while it had never opened the
#      source file at all -- see the block below.
#
# =============================================================================
# THE DEFECT THAT WAS FOUND IN THIS FILE, kept because it is worth more than the
# mutants.
#
# The line here read `cd "$(dirname "$0")"`, which is `lean/mutate/`. Every path
# below is relative, so `Proofs/RotVerdict.lean` resolved to
# `lean/mutate/Proofs/RotVerdict.lean` -- a file that has never existed. Every run
# therefore did this, silently, and scored a perfect suite:
#
#   cp: cannot stat 'Proofs/RotVerdict.lean.mutbak'
#   grep: Proofs/RotVerdict.lean: No such file or directory
#   line 33: [: : integer expression expected      <- the needle guard CRASHING
#   error: [root]: no configuration file ...       <- lake, in the wrong dir
#   P02 killed -- drive letter no longer lowercased
#
# Nothing was mutated. Nothing was compiled. Five theorems were reported
# load-bearing. The presence-assertion that exists precisely to separate "did
# not apply" from "survived" was bypassed because `$n` was EMPTY, so `[ "$n"
# -ne 1 ]` errored instead of firing -- a guard that crashes is not a guard.
#
# Three repairs, and the third is the one that generalises:
#   * resolve everything from LEAN_ROOT (the workspace root), never from the
#     script's own directory, and honour the same override the other suites do;
#   * make every guard robust to an empty/absent measurement -- absent is
#     ABORT, never a kill;
#   * PREFLIGHT: the source must exist and the baseline must BUILD GREEN before
#     a single mutant runs. An unattributable kill is not evidence, and a suite
#     that cannot tell "my workspace is missing" from "the theorem caught it"
#     is not an instrument.
# =============================================================================

set -uo pipefail
# Override with LEAN_ROOT=... to run against a different workspace.
LEAN_ROOT="${LEAN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$LEAN_ROOT" || { echo "FATAL: cannot enter LEAN_ROOT=$LEAN_ROOT"; exit 2; }
SRC="Proofs/RotVerdict.lean"
OLEAN=".lake/build/lib/lean/Proofs/RotVerdict.olean"
BAK="$SRC.mutbak"

# --- PREFLIGHT: no green baseline, no attributable kills --------------------
[ -f "$SRC" ] || {
  echo "FATAL: $SRC not found under LEAN_ROOT=$LEAN_ROOT."
  echo "Refusing to run: every mutant would 'fail to build' and be scored KILLED"
  echo "without a single line having been mutated. That is the defect this"
  echo "preflight exists to make impossible."
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

if ! lake build Proofs.RotVerdict >/tmp/mut_baseline_pre.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (lake build Proofs.RotVerdict != 0)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_baseline_pre.log
  exit 2
fi
echo "preflight: baseline builds GREEN, $SRC present -- kills are attributable"

# --- SOURCE SANITY: a green baseline is NOT proof the source is intact -----
# Measured 2026-08-03, the hard way. A run of this suite was killed by a
# wall-clock timeout DURING `awk ... > "$SRC"`. The redirection truncates the
# file before awk writes, so the source was left at ZERO BYTES. The EXIT trap
# never ran (SIGKILL). Then the next run did `cp "$SRC" "$BAK"` and copied the
# EMPTY file over the only good backup, reported every needle as DISCARDED,
# and restored the emptiness. `rm -f "$BAK"` then deleted the evidence.
#
# The preflight could not see it: AN EMPTY LEAN FILE BUILDS GREEN. "The
# baseline compiles" is a weaker statement than it looks, so the source is
# checked for CONTENT before it is ever copied over the backup.
_lines=$(wc -l < "$SRC" 2>/dev/null || echo 0)
_thms=$(grep -c "^theorem \|^@\[simp\] theorem \|^example " "$SRC" 2>/dev/null || echo 0)
if [ "${_lines:-0}" -lt 20 ] || [ "${_thms:-0}" -lt 1 ]; then
  echo "FATAL: $SRC looks DAMAGED ($_lines lines, $_thms theorem/example lines)."
  echo "Refusing to overwrite the backup with it. An empty or truncated source"
  echo "compiles green and would be scored as a suite full of DISCARDED mutants."
  echo "Restore the file (git checkout -- <path>) before running this suite."
  exit 2
fi

cp "$SRC" "$BAK"
trap 'cp "$BAK" "$SRC"; rm -f "$BAK"' EXIT

killed=0; survived=0; discarded=0

run_mut () {  # run_mut <id> <needle> <replacement> <description>
  id="$1"; needle="$2"; repl="$3"; desc="$4"
  cp "$BAK" "$SRC"
  n=$(grep -F -c "$needle" "$SRC" 2>/dev/null); n=${n:-0}
  if [ "$n" -ne 1 ]; then
    echo "  $id DISCARDED -- needle appears $n times (expected exactly 1): $desc"
    discarded=$((discarded+1)); return
  fi
  # Line-oriented replacement: multi-line string surgery is where escaping breaks.
  awk -v needle="$needle" -v repl="$repl" '
    { i = index($0, needle)
      if (i > 0) { $0 = substr($0,1,i-1) repl substr($0,i+length(needle)) }
      print }' "$SRC" > "$SRC.tmp" && mv "$SRC.tmp" "$SRC"
  if grep -F -q "$needle" "$SRC"; then
    echo "  $id DISCARDED -- replacement did not land: $desc"
    discarded=$((discarded+1)); return
  fi
  rm -f "$OLEAN"
  if lake build Proofs.RotVerdict >/tmp/mut_$id.log 2>&1; then
    echo "  $id SURVIVED  -- $desc"
    echo "       NOTHING CAUGHT THIS. The theorems above it are decorative."
    survived=$((survived+1))
  # ATTRIBUTABILITY. A non-zero exit is evidence that the theorems died
  # only if a build actually ran. A failed redirect, a missing toolchain
  # or a killed process each give non-zero with NO log. MEASURED in CI
  # run 31180174433: a sibling suite scored twelve kills exactly that
  # way, on a runner where lake never ran once, and the job was GREEN.
  elif [ ! -s /tmp/mut_$id.log ]; then
    echo "  $id DISCARDED -- build produced NO log; lake did not run, so"
    echo "       nothing was learned. Harness fault, not a dead theorem."
    discarded=$((discarded+1))
  else
    dead=$(grep -oE '^error: Proofs/RotVerdict.lean:[0-9]+' /tmp/mut_$id.log | head -3 | tr '\n' ' ')
    echo "  $id killed    -- $desc"
    echo "       first failures at: ${dead:-<none captured>}"
    killed=$((killed+1))
  fi
}

run_mut_nth () {  # run_mut_nth <id> <needle> <repl> <occurrence> <total> <desc>
  # Needed because a needle can legitimately appear twice: once in the
  # DEFINITION and once in a theorem STATEMENT that quotes it. Mutating the
  # definition is the meaningful test; requiring uniqueness would discard it
  # forever, and blindly replacing both would also rewrite the theorem, which
  # makes the mutant tautologically green -- the exact false SURVIVED this
  # harness exists to avoid.
  id="$1"; needle="$2"; repl="$3"; occ="$4"; total="$5"; desc="$6"
  cp "$BAK" "$SRC"
  n=$(grep -F -c "$needle" "$SRC" 2>/dev/null); n=${n:-0}
  if [ "$n" -ne "$total" ]; then
    echo "  $id DISCARDED -- needle appears $n times (expected $total): $desc"
    discarded=$((discarded+1)); return
  fi
  # awk -v PROCESSES ESCAPE SEQUENCES in the assignment: a needle containing
  # a literal backslash arrives mangled and matches nothing, which this harness
  # would then report as DISCARDED (correctly) forever. ENVIRON does not.
  MUT_NEEDLE="$needle" MUT_REPL="$repl" MUT_WANT="$occ" awk '
      BEGIN { needle = ENVIRON["MUT_NEEDLE"]; repl = ENVIRON["MUT_REPL"]; want = ENVIRON["MUT_WANT"]+0 }
    { seen_line = 0
      out = ""
      rest = $0
      while ((i = index(rest, needle)) > 0) {
        hit++
        if (hit == want) {
          out = out substr(rest,1,i-1) repl
        } else {
          out = out substr(rest,1,i-1) needle
        }
        rest = substr(rest, i+length(needle))
        seen_line = 1
      }
      print (seen_line ? out rest : $0) }' "$SRC" > "$SRC.tmp" && mv "$SRC.tmp" "$SRC"
  left=$(grep -F -c "$needle" "$SRC" 2>/dev/null); left=${left:-0}
  if [ "$left" -ne $((total-1)) ]; then
    echo "  $id DISCARDED -- expected $((total-1)) needle(s) left, found $left: $desc"
    discarded=$((discarded+1)); return
  fi
  rm -f "$OLEAN"
  if lake build Proofs.RotVerdict >/tmp/mut_$id.log 2>&1; then
    echo "  $id SURVIVED  -- $desc"
    echo "       NOTHING CAUGHT THIS. The theorems above it are decorative."
    survived=$((survived+1))
  # ATTRIBUTABILITY. A non-zero exit is evidence that the theorems died
  # only if a build actually ran. A failed redirect, a missing toolchain
  # or a killed process each give non-zero with NO log. MEASURED in CI
  # run 31180174433: a sibling suite scored twelve kills exactly that
  # way, on a runner where lake never ran once, and the job was GREEN.
  elif [ ! -s /tmp/mut_$id.log ]; then
    echo "  $id DISCARDED -- build produced NO log; lake did not run, so"
    echo "       nothing was learned. Harness fault, not a dead theorem."
    discarded=$((discarded+1))
  else
    dead=$(grep -oE '^error: Proofs/RotVerdict.lean:[0-9]+' /tmp/mut_$id.log | head -3 | tr '\n' ' ')
    echo "  $id killed    -- $desc"
    echo "       first failures at: ${dead:-<none captured>}"
    killed=$((killed+1))
  fi
}

echo "== mutation suite: Proofs/RotVerdict.lean (the weekly verdict decision) =="
echo "Each mutant is a way the green-square generator comes back. Theorems must die."
echo

# V01 -- the shipped decision stops looking at the previous verdict and commits
# every week. This is the defect the module exists for, planted directly.
run_mut V01 "if r.prev = some r.cur then false else true" "true"   "commits ALWAYS -- a quiet week still commits"

# V02 -- the opposite failure, and it must be caught just as hard: a decision
# that never commits keeps STATUS.md frozen at whatever was true the day it was
# written, and would pass any test that only checks for absent commits.
run_mut V02 "if r.prev = some r.cur then false else true" "false"   "commits NEVER -- the verdict can never be published"

# V03 -- the old design is quietly repaired, so the theorems that prove it was
# broken lose their subject. If nothing dies here, `designs_disagree` and
# `old_commits_every_week` were describing a defect that was not there.
run_mut V03 "if pv = r.cur ∧ r.prevClock = r.clock ∧ r.prevSha = r.sha" "if pv = r.cur"   "commitsOld silently becomes the fixed design"

# V04 -- the week accumulator stops checking the state: every week counts.
run_mut V04 "(if st = some v then 0 else 1)" "1"   "sched counts a commit every week regardless of state"

# V05 -- the recursion forgets that publishing UPDATES the state, so the first
# publication never becomes the baseline for the next week.
run_mut V05 "+ sched n (some v) v" "+ sched n st v"   "sched never records what it published"

# V06 -- the old accumulator is made silent, which would make the contrast
# theorem vacuous while leaving the module green.
run_mut V06 "| some (pv, pc) => if pv = v ∧ pc = t then 0 else 1" "| some (_pv, _pc) => 0"   "schedOld stops counting its weekly commits"

# V07 -- the executable corpus is load-bearing too: if `tomorrow` stops being a
# different verdict, the #guard asserting a change is published is a tautology.
run_mut V07 "def tomorrow : Verdict := { today with theorems := 90 }" "def tomorrow : Verdict := today"   "the 'changed' corpus row stops being a change"

echo
echo "== RESULT =="
# --- RESTORE THE BASELINE ---------------------------------------------------
# The EXIT trap restores the SOURCE, but the last mutant deleted the .olean and
# nothing rebuilt it. Measured 2026-08-03: re-running a suite immediately after
# itself hit its own no-download guard and reported SKIP, because the workspace
# was no longer built -- and a later `leanchecker` sweep over the same tree would
# report `Could not find any oleans`, which reads as a KERNEL failure when it is
# only a deleted artifact. A false red is as corrosive as a false green.
cp "$BAK" "$SRC"
if ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotVerdict ) >/tmp/mut_post_rotverdict.log 2>&1; then
  echo "baseline restored and REBUILT green (olean present again)"
else
  echo "FATAL: the tree does not build after restore -- the suite left damage."
  tail -5 /tmp/mut_post_rotverdict.log
  exit 2
fi
echo "killed=$killed survived=$survived discarded=$discarded"
cp "$BAK" "$SRC"; rm -f "$OLEAN"
lake build Proofs.RotVerdict >/dev/null 2>&1
base=$?
echo "baseline restored -> lake build exit=$base"
# The restored baseline GATES the verdict. It used to be printed and ignored, so
# a suite that left the tree red still exited 0 -- a run that ends on a broken
# tree has told you nothing about the state of that tree.
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && [ "$base" -eq 0 ] && exit 0 || exit 1
