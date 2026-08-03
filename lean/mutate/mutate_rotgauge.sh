#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# Mutation harness for Proofs/RotGauge.lean
#!/usr/bin/env bash
# Mutation harness for Proofs/RotGauge.lean
#
# Contract (the part that makes this an instrument rather than decoration):
#   1. assert the needle is present EXACTLY once before mutating; if not -> DISCARDED
#   2. assert the replacement is present and the needle gone AFTER mutating
#   3. delete the stale .olean so Lake cannot skip the rebuild
#   4. build, read the exit code DIRECTLY
#   5. attribute each error line to the enclosing declaration
#   6. restore and rebuild at the end, confirming a clean baseline
#
# DISCARDED != SURVIVED. The first is a defect in this harness, the second is a
# claim about the theorem. They are reported separately and never merged.

set -u
F=${LEAN_ROOT:-.}/Proofs/RotGauge.lean
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotGauge.olean
LOG=/d/tmp/mut

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotGauge ) >/tmp/mut_pre_rotgauge.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotGauge)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotgauge.log
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

  # assertion 2: the mutation actually landed
  local after_needle after_repl
  after_needle=$(grep -F -c -- "$needle" "$F")
  after_repl=$(grep -F -c -- "$repl" "$F")
  if [ "$after_needle" -ne 0 ] || [ "$after_repl" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed (needle=$after_needle repl=$after_repl)"
    discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi

  rm -f "$OLEAN"
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotGauge ) > "$LOG/$id.log" 2>&1
  local ec=$?

  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   (build still exit 0)  expected to kill: $expect"
    survived=$((survived+1))
  else
    local dead
    dead=$(grep -oE "^error: Proofs/RotGauge\.lean:[0-9]+" "$LOG/$id.log" | grep -oE "[0-9]+$" | sort -un | \
      while read -r ln; do
        awk -v L="$ln" '
          /^(theorem|def|noncomputable def|instance|structure|inductive|example)/ {
            if (NR <= L) { name=$0; nline=NR }
          }
          END { if (name != "") print name }
        ' "$F"
      done | sed -E 's/^(noncomputable )?(theorem|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' | sort -u | tr '\n' ',' )
    # THE `dead:` LIST IS A LOWER BOUND, NOT AN INVENTORY. Measured 2026-08-03
    # on M03 (gauge replaced by a constant): the errors landed at lines 192,
    # 282, 311 and 338, and `gauge_not_constant` at :346 was NOT among them --
    # so the list appeared to show it surviving a mutation whose whole purpose
    # was to kill it. It did not survive. Two facts settle it:
    #
    #   1. The mutant build produces NO olean. Nothing downstream can use ANY
    #      theorem in the module, so every one of them is dead in the only
    #      sense a consumer cares about.
    #   2. `gauge_not_constant` elaborated only because Lean's error recovery
    #      keeps the STATEMENT of the broken lemma it rewrites with (:338)
    #      alive. Its `rw` matched a lemma that no longer has a proof.
    #
    # That is exactly the failure the doctrine warns about -- attribute through
    # DEPENDENCIES, never by which line reported an error. Reporting the list
    # without this caveat would let a reader conclude a theorem is decorative
    # when the truth is the opposite, which is how a real overclaim gets
    # dismissed as noise. The line below now says what the list is worth.
    if [ ! -f "$OLEAN" ]; then
      echo "$id  KILLED     exit=$ec  MODULE DEAD (no olean: every theorem in it is unusable)"
      echo "        errors reported at: ${dead%,}  <- LOWER BOUND, not the full set"
      echo "        expected: $expect"
    else
      echo "$id  KILLED     exit=$ec  dead: ${dead%,}  | expected: $expect"
    fi
    killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

echo "=== RotGauge mutation suite ==="

run_mut M01 \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1 / 2)))' \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (4 * (x - 1 / 2)))' \
  'sigma_strictMono (slope sign flipped)'

run_mut M02 \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1 / 2)))' \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1 / 3)))' \
  'sigma_half (centre moved)'

run_mut M03 \
  '  (∑ i, term L a breadth M C T i) / (Fintype.card ι)' \
  '  0' \
  'gauge_pos, gauge_not_constant (gauge replaced by a constant)'

run_mut M04 \
  '  if breadth = 0 then 0 else min 1 (actR a i / (breadth : ℝ))' \
  '  if breadth = 0 then 0 else max 1 (actR a i / (breadth : ℝ))' \
  'entropyAt_le_one, entropyAt_allQuiet (cap inverted)'

run_mut M05 \
  'noncomputable def deltaAt (a : ι → Bool) (i : ι) : ℝ := |actR a i - meanAct a|' \
  'noncomputable def deltaAt (a : ι → Bool) (i : ι) : ℝ := actR a i - meanAct a' \
  'deltaAt_nonneg, gauge_ge_floor (absolute value dropped)'

run_mut M06 \
  '  (∑ i, term L a breadth M C T i) / (Fintype.card ι)' \
  '  (∑ i, term L a breadth M C T i) / 9' \
  'gauge_divisor_eq_card (K hardcoded to 9)'

run_mut M07 \
  '  if R < lo then .below else if hi < R then .above else .inRange' \
  '  if R ≤ lo then .below else if hi < R then .above else .inRange' \
  'classify_below_iff, classify_inRange_iff (band off-by-one)'

run_mut M08 \
  '  | .claude => ⟨2.3, 1.15⟩' \
  '  | .claude => ⟨-2.3, 1.15⟩' \
  'forge_posWeights (a shipped weight made negative)'

run_mut M09 \
  '  sigma (deltaAt a i) * (1 + entropyAt a breadth i)' \
  '  sigma (deltaAt a i) * (1 + 0 * entropyAt a breadth i)' \
  'term_eq_ps1_order, gauge_allLive_eq_two_mul_allQuiet (breadth bonus removed)'

run_mut M10 \
  'def actR (a : ι → Bool) (i : ι) : ℝ := if a i then 1 else 0' \
  'def actR (a : ι → Bool) (i : ι) : ℝ := if a i then 0 else 0' \
  'actR_allLive, gauge_not_constant (every lens pinned to 0 -- the :362-366 bug class)'

# M11 -- the SHIPPING weight table itself. `forge` is the one thing in this file
# that is a claim about the configuration in production rather than about
# mathematics, and it had no mutant: forge_posWeights could have been proved for
# a table with a non-positive entry and nothing here would have noticed.
# checker/lean-binds-shell.sh separately pins these numbers to the shell, so the
# table is now covered from both sides -- Lean proves it satisfies PosWeights,
# the checker proves it is the profile that actually ships.
run_mut M11 \
  '| .claude => ⟨2.3, 1.15⟩' \
  '| .claude => ⟨-2.3, 1.15⟩' \
  'forge_posWeights (a negative lambda in the shipped table)'

# M12 -- collapse the band so `inRange` is never returned. This is the mutant
# that exposes the difference between a decorative theorem and a real one:
# classify_total SURVIVES it (it is true of any function), classify_surjective
# must DIE. If both survived, the audit that added classify_surjective bought
# nothing and should be reported as such.
run_mut M12 \
  'if R < lo then .below else if hi < R then .above else .inRange' \
  'if R < lo then .below else .above' \
  'classify_surjective, classify_inRange_iff (band collapsed: inRange unreachable)'

# restore and confirm a clean baseline
cp "$BAK" "$F"
rm -f "$OLEAN"
( cd ${LEAN_ROOT:-.} && lake build Proofs.RotGauge ) > "$LOG/baseline.log" 2>&1
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
if ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotGauge ) >/tmp/mut_post_rotgauge.log 2>&1; then
  echo "baseline restored and REBUILT green (olean present again)"
else
  echo "FATAL: the tree does not build after restore -- the suite left damage."
  tail -5 /tmp/mut_post_rotgauge.log
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
