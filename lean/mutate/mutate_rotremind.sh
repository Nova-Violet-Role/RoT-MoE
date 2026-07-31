#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# Mutation suite for Proofs/RotRemind.lean.
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
# below is relative, so `Proofs/RotRemind.lean` resolved to
# `lean/mutate/Proofs/RotRemind.lean` -- a file that has never existed. Every run
# therefore did this, silently, and scored a perfect suite:
#
#   cp: cannot stat 'Proofs/RotRemind.lean.mutbak'
#   grep: Proofs/RotRemind.lean: No such file or directory
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
SRC="Proofs/RotRemind.lean"
OLEAN=".lake/build/lib/lean/Proofs/RotRemind.olean"
BAK="$SRC.mutbak"

# --- PREFLIGHT: no green baseline, no attributable kills --------------------
[ -f "$SRC" ] || {
  echo "FATAL: $SRC not found under LEAN_ROOT=$LEAN_ROOT."
  echo "Refusing to run: every mutant would 'fail to build' and be scored KILLED"
  echo "without a single line having been mutated. That is the defect this"
  echo "preflight exists to make impossible."
  exit 2
}
if ! lake build Proofs.RotRemind >/tmp/mut_baseline_pre.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (lake build Proofs.RotRemind != 0)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_baseline_pre.log
  exit 2
fi
echo "preflight: baseline builds GREEN, $SRC present -- kills are attributable"

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
  if lake build Proofs.RotRemind >/tmp/mut_$id.log 2>&1; then
    echo "  $id SURVIVED  -- $desc"
    echo "       NOTHING CAUGHT THIS. The theorems above it are decorative."
    survived=$((survived+1))
  else
    dead=$(grep -oE '^error: Proofs/RotRemind.lean:[0-9]+' /tmp/mut_$id.log | head -3 | tr '\n' ' ')
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
  if lake build Proofs.RotRemind >/tmp/mut_$id.log 2>&1; then
    echo "  $id SURVIVED  -- $desc"
    echo "       NOTHING CAUGHT THIS. The theorems above it are decorative."
    survived=$((survived+1))
  else
    dead=$(grep -oE '^error: Proofs/RotRemind.lean:[0-9]+' /tmp/mut_$id.log | head -3 | tr '\n' ' ')
    echo "  $id killed    -- $desc"
    echo "       first failures at: ${dead:-<none captured>}"
    killed=$((killed+1))
  fi
}

echo "== mutation suite: Proofs/RotRemind.lean =="

# NEEDLE COUNTS ARE MEASURED, NOT GUESSED. `0 ≤ s.mins` and `s.mins < T`
# each occur TWICE -- once in the definition and once inside the proof of
# `speaks_iff`, which case-splits on the same comparisons. Mutating only the
# definition is the meaningful test; replacing both would rewrite the proof to
# agree with the mutant and produce a false SURVIVED. That is what run_mut_nth
# is for, and the totals below were counted with grep -F -c before being written.

# R01 -- the staleness boundary loosened by one. `s.mins < T` becoming
# `s.mins ≤ T` makes the boundary EXCLUSIVE: the reminder would stay silent AT
# exactly STALE_MIN. This is mutant H21/H22 from the shell suite, expressed in
# the model. The 45/44 witness pair pins it from both sides.
run_mut_nth R01 "s.mins < T ∧" "s.mins ≤ T ∧" 1 1   "staleness boundary becomes exclusive (silent AT the threshold)"

# R02 -- the "no proofs found" sentinel loses its meaning. `-1` starts looking
# like a fresh proof, so a workspace containing NO Lean files at all reports as
# healthy. That is the worst failure available to this organ: silence that means
# "nothing was checked" being read as "all is well".
run_mut_nth R02 "0 ≤ s.mins" "-99 ≤ s.mins" 1 2   "the -1 no-proofs-found sentinel is swallowed as if it were fresh"

# R03 -- kernel rejections stop being a reason to speak.
run_mut R03 "s.kernelRed = [] ∧ s.kernelSorry = []" "s.kernelSorry = []"   "a rejected module no longer forces speech"

# R04 -- debt stops being a reason to speak.
run_mut R04 "s.debt = [] ∧ 0 ≤ s.mins" "0 ≤ s.mins"   "uncommitted cast/clamp debt no longer forces speech"

# R05 -- THE WALLPAPER MUTANT, and the reason this module exists. Speech becomes
# unconditional -- the ancestor that emitted the same paragraph every turn until
# nobody read it. It must die on the SILENT witnesses. If it ever survives, every
# theorem in the file is equally satisfied by something that never stops talking.
#
# THE REPLACEMENT MUST NOT CONTAIN THE NEEDLE. First attempt was
# `¬ silent T s` -> `¬ silent T s ∨ True`, and the harness reported DISCARDED,
# correctly: its landing check asserts the needle is GONE, and an EXTENDING edit
# leaves it in place. It was scored discarded and not survived, which is the one
# distinction that keeps a mutation harness honest -- "my patch failed" and "the
# theorem is robust" are opposite facts. Rewritten as a REPLACING edit with the
# same meaning.
run_mut R05 "¬ silent T s" "True"   "the reminder speaks unconditionally (the wallpaper regression)"

# R06 -- alarms wired INTO the silence condition. With 14 alarm rows open in the
# goal file this fires on every turn. The theorem that catches it is the one
# quantified over the alarm count, which is why that quantifier is load-bearing
# rather than tidy.
run_mut R06 "s.debt = [] ∧ 0 ≤ s.mins ∧ s.mins < T"   "s.debt = [] ∧ s.alarms = 0 ∧ 0 ≤ s.mins ∧ s.mins < T"   "open alarms alone start forcing speech (fires every turn)"

echo
echo "== RESULT =="
echo "killed=$killed survived=$survived discarded=$discarded"
cp "$BAK" "$SRC"; rm -f "$OLEAN"
lake build Proofs.RotRemind >/dev/null 2>&1
base=$?
echo "baseline restored -> lake build exit=$base"
# The restored baseline GATES the verdict. It used to be printed and ignored, so
# a suite that left the tree red still exited 0 -- a run that ends on a broken
# tree has told you nothing about the state of that tree.
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && [ "$base" -eq 0 ] && exit 0 || exit 1
