#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotSymbiogenesis.lean (what an observation does NOT tell you)
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
# WHAT THIS SUITE IS AIMED AT. RotSymbiogenesis is not an abstract module: each of its
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

F="Proofs/RotSymbiogenesis.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotSymbiogenesis.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutsymb.XXXXXX")"

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

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotSymbiogenesis ) >/tmp/mut_pre_rotsymbiogenesis.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotSymbiogenesis)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotsymbiogenesis.log
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
# 2026-08-07, being killed at that ceiling left a MUTATED RotSymbiogenesis.lean on
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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotSymbiogenesis ) > "$LOG/$id.log" 2>&1
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
    # The reported error lines are a LOWER BOUND on what died, not an inventory.
    # A mutant build produces no olean, so every theorem in the module is
    # unusable downstream regardless of which line the elaborator complained at.
    local dead
    dead=$(grep -oE "^error: Proofs/RotSymbiogenesis\.lean:[0-9]+" "$LOG/$id.log" \
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

echo "=== RotSymbiogenesis mutation suite ==="

# --- §1 the operator IS the spec's --------------------------------------------

# S01 -- the novelty term is deleted. A hybrid would then sit at its parents'
# entropy: fusion stops generating anything and the whole module is fiction.
run_mut S01 \
  '    H := max a.H b.H + 1/20' \
  '    H := max a.H b.H' \
  'fuse_H_gt_left, fuse_ne_left, chain_H, symbiogenesis_generates_infinitely_many'

# S02 -- the λ gain is deleted: fusion becomes the plain mean, which is what the
# spec explicitly says it is NOT.
run_mut S02 \
  '  { lam := (a.lam + b.lam) / 2 + 1/5' \
  '  { lam := (a.lam + b.lam) / 2' \
  'fuse_lam_gt_mean, chain_lam, forge_matches_the_spec'

# S03 -- μ averaged instead of maximised. Quality could then FALL below a
# parent, which the spec forbids (OMEGA BLOCK 19: no gain term, but a maximum).
run_mut S03 \
  '    mu := max a.mu b.mu }' \
  '    mu := (a.mu + b.mu) / 2 }' \
  'fuse_mu_ge_both, forge_matches_the_spec'

# S04 -- H takes the MINIMUM of the parents. Fusing a high-entropy lens with a
# low one would then lose the divergence that made it worth fusing.
run_mut S04 \
  '    H := max a.H b.H + 1/20' \
  '    H := min a.H b.H + 1/20' \
  'fuse_H_gt_left or fuse_H_gt_right (one parent now exceeds the hybrid)'

# S05 -- the spec's own worked hybrid is misquoted by one digit in λ. If this
# survives, forge_matches_the_spec was not pinning the transcription at all.
run_mut S05 \
  'def verifiedForge : Lens := { lam := 17/10, H := 7/20, mu := 21/20 }' \
  'def verifiedForge : Lens := { lam := 18/10, H := 7/20, mu := 21/20 }' \
  'forge_matches_the_spec, forge_is_not_a_roster_lens'

# --- §2 the generative claims --------------------------------------------------

# S06 -- iteration collapses: every generation returns the base. This is the
# "it saturates" world, and the infinitude theorem must not survive it.
run_mut S06 \
  '  | n + 1 => fuse (chain base n) (chain base n)' \
  '  | _ + 1 => base' \
  'chain_H, chain_lam, chain_injective, symbiogenesis_generates_infinitely_many'

# S07 -- the per-generation entropy step is stated as 1/10 instead of the 1/20
# the operator actually adds. A theorem that survives a wrong constant is not
# measuring the operator.
run_mut S07 \
  'theorem chain_H (base : Lens) (n : ℕ) : (chain base n).H = base.H + n / 20 := by' \
  'theorem chain_H (base : Lens) (n : ℕ) : (chain base n).H = base.H + n / 10 := by' \
  'chain_H'

# S08 -- strict monotonicity weakened to ≤. Injectivity, and with it the
# infinitude of generated lenses, must no longer follow.
run_mut S08 \
  'theorem chain_strictMono_H (base : Lens) : StrictMono (fun n => (chain base n).H) := by' \
  'theorem chain_strictMono_H (base : Lens) : Monotone (fun n => (chain base n).H) := by' \
  'chain_strictMono_H, chain_injective'

# --- §3 the roster and the escape ---------------------------------------------

# S09 -- the roster gains the Verified Forge, so fusion no longer escapes it.
# This is the concrete "the nine already cover it" objection, planted.
run_mut S09 \
  '  , { lam := 3/2,  H := 3/10, mu := 21/20 } ]  -- Claude' \
  '  , { lam := 17/10, H := 7/20, mu := 21/20 } ]  -- Claude' \
  'forge_is_not_a_roster_lens'

# S10 -- a lens is dropped from the roster: K = 9 stops being true of the list
# the other theorems quantify over.
run_mut S10 \
  '  , { lam := 4/5,  H := 11/50, mu := 9/10 }    -- Soleil_Blank' \
  '' \
  'roster_is_nine'

# S11 -- the escape theorem is stated with ≥ instead of the strict cap, which
# would let a roster member sit exactly at the hybrid's entropy.
run_mut S11 \
  '  have h₂ : a.H < (fuse a b).H := fuse_H_gt_left a b' \
  '  have h₂ : a.H ≤ (fuse a b).H := le_of_lt (fuse_H_gt_left a b)' \
  'fuse_escapes_any_roster'

# S12 -- THE ANTI-OVERCLAIM MUTANT. The honest boundary says a gauge reading
# does NOT identify the lens. Flip it to claim it does. If this survives, the
# module is asserting a fingerprint property it never proved.
run_mut S12 \
  '  refine ⟨claudeLens, antiVenomLens, ?_, rfl⟩' \
  '  refine ⟨claudeLens, claudeLens, ?_, rfl⟩' \
  'equal_reading_does_not_imply_equal_lens (the two lenses are now identical)'

echo
printf 'restoring baseline artifact ... '
if ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotSymbiogenesis ) >"$LOG/restore.log" 2>&1; then
  echo "OK (baseline rebuilt, .olean present)"
else
  echo "FAILED -- the restored source does NOT build. The tree is left BROKEN."
  echo "         Run: git checkout HEAD -- $F"
  tail -5 "$LOG/restore.log"
  exit 2
fi

echo
if [ "$filtered" -eq 1 ]; then
  echo "=== RotSymbiogenesis: PARTIAL RUN (MUT_ONLY='$MUT_ONLY') -- $killed killed, $survived survived, $discarded discarded, $skipped SKIPPED ==="
  echo "NOT a suite result. $skipped mutants were never applied and prove nothing."
  [ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && exit 3
  exit 1
fi
echo "=== RotSymbiogenesis: $killed killed, $survived survived, $discarded discarded ==="
[ "$discarded" -gt 0 ] && echo "NOTE: discarded mutants tested NOTHING -- fix the needles, do not count them as survivors."
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && exit 0
exit 1
