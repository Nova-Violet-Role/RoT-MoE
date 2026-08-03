#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# Mutation suite for Proofs/RotVacuity.lean.
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

#   4. A KILL IS ONLY A KILL IF THE BASELINE WAS GREEN. This suite and
#      mutate_rotpath.sh were both caught on 2026-07-31 reporting a full sweep
#      of kills while having never opened their source file: `cd
#      "$(dirname "$0")"` put them in `lean/mutate/`, where `Proofs/*.lean` does
#      not exist and `lake` has no lakefile. Every build failed for that reason
#      and every failure was scored KILLED. The needle guard did not save it --
#      `$n` was empty, so `[ "$n" -ne 1 ]` errored instead of firing. A guard
#      that crashes is not a guard, and a suite that cannot tell "my workspace
#      is missing" from "the theorem caught it" is not an instrument.
#      Repaired the same way in both files: resolve from LEAN_ROOT, make every
#      guard robust to an empty measurement, and PREFLIGHT a green baseline.

set -uo pipefail
# Override with LEAN_ROOT=... to run against a different workspace.
LEAN_ROOT="${LEAN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$LEAN_ROOT" || { echo "FATAL: cannot enter LEAN_ROOT=$LEAN_ROOT"; exit 2; }
SRC="Proofs/RotVacuity.lean"
OLEAN=".lake/build/lib/lean/Proofs/RotVacuity.olean"
BAK="$SRC.mutbak"

# --- PREFLIGHT: no green baseline, no attributable kills --------------------
[ -f "$SRC" ] || {
  echo "FATAL: $SRC not found under LEAN_ROOT=$LEAN_ROOT."
  echo "Refusing to run: every mutant would 'fail to build' and be scored KILLED"
  echo "without a single line having been mutated."
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

if ! lake build Proofs.RotVacuity >/tmp/mut_baseline_prev.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (lake build Proofs.RotVacuity != 0)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_baseline_prev.log
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
  if lake build Proofs.RotVacuity >/tmp/mut_$id.log 2>&1; then
    echo "  $id SURVIVED  -- $desc"
    echo "       NOTHING CAUGHT THIS. The theorems above it are decorative."
    survived=$((survived+1))
  else
    dead=$(grep -oE '^error: Proofs/RotVacuity.lean:[0-9]+' /tmp/mut_$id.log | head -3 | tr '\n' ' ')
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
  if lake build Proofs.RotVacuity >/tmp/mut_$id.log 2>&1; then
    echo "  $id SURVIVED  -- $desc"
    echo "       NOTHING CAUGHT THIS. The theorems above it are decorative."
    survived=$((survived+1))
  else
    dead=$(grep -oE '^error: Proofs/RotVacuity.lean:[0-9]+' /tmp/mut_$id.log | head -3 | tr '\n' ' ')
    echo "  $id killed    -- $desc"
    echo "       first failures at: ${dead:-<none captured>}"
    killed=$((killed+1))
  fi
}

echo "== mutation suite: Proofs/RotVacuity.lean (the audit itself) =="


# ---------------------------------------------------------------------------
# The audit's claim is: "if a hypothesis set were unsatisfiable, the
# instantiation below would not compile." Every mutant here makes one witness
# WRONG. If the file still builds, that witness was never load-bearing and the
# corresponding non-vacuity claim is decoration.
# ---------------------------------------------------------------------------

# V01..V03 originally mutated a SECOND copy of the FORGE weight table that had
# been written into RotVacuity.lean. That duplicate was deleted -- RotGauge.lean
# already defines `forge` and already proves `forge_posWeights`, so the copy was
# a second source of truth and the binding checker was validating the wrong one.
# The table's own mutation coverage now lives in mutate_rotgauge.sh, where the
# table lives. These three mutate what is genuinely UNIQUE here: the witnesses.

# V01 -- the scalar arguments no longer match the witness they are discharged
# by. forge_posWeights is stated at M=1.05 C=0.7 T=0.8; move T and the
# instantiation must stop type-checking.
run_mut_nth V01 "1.05 0.7 0.8" "1.05 0.7 0.9" 1 5 \
  "witness scalars moved off forge_posWeights (instantiation must fail)"

# V02 -- gauge_ge_floor's floor is the ALL-QUIET gauge. Swapping in allLive
# claims the floor is the maximum, which the lemma cannot prove.
run_mut_nth V02 "RotMoE.allQuiet RotMoE.Face) 0" "RotMoE.allLive RotMoE.Face) 0" 1 2 \
  "floor witness changed from allQuiet to allLive"

# V03 -- the freshness witness stops being fresh. emptySettings is what makes
# disarm_arm_id applicable; give it a pre-existing hook and the hypothesis it
# discharges becomes false.
run_mut V03 'def emptySettings : Settings := ⟨fun _ => none, fun _ => []⟩' 'def emptySettings : Settings := ⟨fun _ => none, fun _ => ["rot"]⟩' \
  "emptySettings pre-loaded with the command (freshness must fail)"

# V04 -- the drive-letter witness is no longer a letter. 'both_spellings_agree'
# requires d.isAlpha, so `decide` must refuse.
run_mut V04 "both_spellings_agree 'C'" "both_spellings_agree '1'" \
  "non-alphabetic drive witness (isAlpha hypothesis must fail)"

# V05 -- the band witness inverted. classify_above_iff needs lo <= hi.
run_mut V05 "classify 0.9 1.8 R" "classify 1.8 0.9 R" \
  "band witness inverted so lo > hi (the ordering hypothesis must fail)"

# V06 -- forge_priority witnessed with forge FALSE. The hypothesis is
# f.forge = true, so `rfl` must refuse.
run_mut V06 "forge_priority _ rfl" "forge_priority ⟨false, true, true, false, false, false, false, false, false⟩ rfl" \
  "forge_priority witnessed with forge = false"

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
if ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotVacuity ) >/tmp/mut_post_rotvacuity.log 2>&1; then
  echo "baseline restored and REBUILT green (olean present again)"
else
  echo "FATAL: the tree does not build after restore -- the suite left damage."
  tail -5 /tmp/mut_post_rotvacuity.log
  exit 2
fi
echo "killed=$killed survived=$survived discarded=$discarded"
cp "$BAK" "$SRC"; rm -f "$OLEAN"
lake build Proofs.RotVacuity >/dev/null 2>&1
base=$?
echo "baseline restored -> lake build exit=$base"
# The restored baseline GATES the verdict; it used to be printed and ignored.
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && [ "$base" -eq 0 ] && exit 0 || exit 1
