#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# Mutation harness for Proofs/RotRoute.lean. Same contract as
# mutate_rotgauge.sh: needle asserted present exactly once BEFORE, replacement
# asserted present and needle gone AFTER, stale .olean deleted, exit code read
# directly, DISCARDED never folded into SURVIVED.
#
# This run has a specific question to answer. #print axioms reports FIVE
# theorems in this module depending on no axioms at all -- route_fires,
# route_covers_every_mode, nsil_overrides_tier1, nsil_confirm_is_tier1,
# nsil_boost_preserves_lead. The spec says treat that as suspected vacuity.
# For a decidable finite model it is usually just "proved by computation", but
# "usually" is not evidence. N01-N07 below aim one mutation at each of them.

set -u

# Repo-relative by construction: no machine-local path ships (R2).
# Override with LEAN_ROOT=... to run against a different workspace.
LEAN_ROOT="${LEAN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
F="$LEAN_ROOT/Proofs/RotRoute.lean"
BAK="$F.mutbak"
OLEAN="$LEAN_ROOT/.lake/build/lib/lean/Proofs/RotRoute.olean"
LOG="${TMPDIR:-/tmp}/mutr"
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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotRoute ) >/tmp/mut_pre_rotroute.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotRoute)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotroute.log
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
  ( cd "$LEAN_ROOT" && lake build Proofs.RotRoute ) > "$LOG/$id.log" 2>&1
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
    echo "$id  SURVIVED   expected to kill: $expect"; survived=$((survived+1))
  else
    local dead
    dead=$(grep -oE "^error: Proofs/RotRoute\.lean:[0-9]+" "$LOG/$id.log" | grep -oE "[0-9]+$" | sort -un | \
      while read -r ln; do
        awk -v L="$ln" '/^(@\[[^]]*\] )?(noncomputable )?(theorem|lemma|def|instance|structure|inductive|example)[ (]/ { if (NR <= L) name=$0 } END { if (name != "") print name }' "$F"
      done | sed -E 's/^@\[[^]]*\] *//; s/^(noncomputable )?(theorem|lemma|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' | sort -u | tr '\n' ' ')
    echo "$id  KILLED     dead: $dead | expected: $expect"; killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

echo "=== RotRoute mutation suite ==="

run_mut N01 \
  '  else if f.executive then .executive' \
  '  else if f.empathic then .empathic' \
  'route_exact (two branches swapped)'

run_mut N02 \
  '  else .convergent' \
  '  else .stealth' \
  'route_exact, route_default_convergent (fallthrough changed)'

run_mut N03 \
  '  else if f.creative then .creative' \
  '  else if f.strategic then .creative' \
  'route_covers_every_mode (creative lane shadowed -> unreachable)'

run_mut N04 \
  '  if f.forge then .forge' \
  '  if f.forge then .clinical' \
  'route_fires, forge_priority, route_exact (branch points at wrong lane)'

run_mut N05 \
  '  | .override m => .single m' \
  '  | .override _ => .single (route f)' \
  'nsil_overrides_tier1 (NSIL ignored -- back to a keyword if-chain)'

run_mut N06 \
  '  | .confirm => .single (route f)' \
  '  | .confirm => .single .convergent' \
  'nsil_confirm_is_tier1 (CONFIRM stops confirming)'

run_mut N07 \
  '  | .boost => .single (route f)' \
  '  | .boost => .ensemble' \
  'nsil_boost_preserves_lead (BOOST moves the lead)'

run_mut N08 \
  'noncomputable def lamH (l₁ l₂ : ℝ) : ℝ := (l₁ + l₂) / 2 + 0.2' \
  'noncomputable def lamH (l₁ l₂ : ℝ) : ℝ := (l₁ + l₂) / 2' \
  'lamH_gt_mean, symbiogenesis_wellformed (+0.2 hybridisation gain dropped)'

run_mut N09 \
  'noncomputable def hH (h₁ h₂ : ℝ) : ℝ := max h₁ h₂ + 0.05' \
  'noncomputable def hH (h₁ h₂ : ℝ) : ℝ := max h₁ h₂' \
  'hH_gt_both, symbiogenesis_wellformed (+0.05 novelty margin dropped)'

run_mut N10 \
  'noncomputable def muH (m₁ m₂ : ℝ) : ℝ := max m₁ m₂' \
  'noncomputable def muH (m₁ m₂ : ℝ) : ℝ := min m₁ m₂' \
  'muH_exact, symbiogenesis_wellformed (max -> min). symbiogenesis_comm should SURVIVE: min is commutative too, so comm alone is a weak property'

run_mut N11 \
  'noncomputable def lamH (l₁ l₂ : ℝ) : ℝ := (l₁ + l₂) / 2 + 0.2' \
  'noncomputable def lamH (l₁ l₂ : ℝ) : ℝ := l₁ + 0.2' \
  'symbiogenesis_comm (fusion made order-DEPENDENT -- this is what comm is for)'

cp "$BAK" "$F"
rm -f "$OLEAN"
( cd "$LEAN_ROOT" && lake build Proofs.RotRoute ) > "$LOG/baseline.log" 2>&1
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
if ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotRoute ) >/tmp/mut_post_rotroute.log 2>&1; then
  echo "baseline restored and REBUILT green (olean present again)"
else
  echo "FATAL: the tree does not build after restore -- the suite left damage."
  tail -5 /tmp/mut_post_rotroute.log
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
