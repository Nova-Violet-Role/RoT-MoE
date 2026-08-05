#!/usr/bin/env bash
# This file is part of the RoT MoE Easter Egg (SINE / Phantom Books white-paper).
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- RotEigenform.lean
#
# WHY THIS SUITE EXISTS.
#
# RotEigenform is the file most likely in this whole project to produce
# beautiful, green, meaningless Lean. Its subject matter is evocative -- a
# butterfly, an ultimate equation, phantom books, an infinite array of
# realities -- and that is exactly the condition under which a theorem gets
# written to SOUND like the quote instead of to CONSTRAIN anything.
#
# It has already happened here twice, and both are recorded in the Lean file
# rather than quietly repaired:
#
#   * the frequency table was transcribed in TENTHS of a Hz, a resolution that
#     cannot represent the 20.215 Hz row. That row and one more vanished, the
#     Lean list still had a tidy twenty entries, and a FALSE sentence ("30 Hz
#     is the last row") became true of the truncation.
#   * the first corpus census matched one of the library's two XML dialects and
#     reported 190 envelopes where there are 1084. Nothing errored. The number
#     was simply wrong, and entirely plausible.
#
# Neither was caught by a build. Both would have been caught by a mutant.
#
# THE CONTRACT (identical to every other suite in this project):
#   1. assert the needle is present EXACTLY once before mutating; if not -> DISCARDED
#   2. assert the mutation LANDED after patching (needle gone, replacement present)
#   3. delete the stale .olean so Lake cannot skip the rebuild
#   4. rebuild, read the exit code DIRECTLY -- never through a pipe
#   5. restore from the backup, ALWAYS, and rebuild to a verified green baseline
#
# DISCARDED != SURVIVED. The first is a defect in this harness, the second is a
# claim about the theorem. Folding them together manufactures reassurance.
#
# LAYOUT. This suite runs from two places and behaves identically in both. The
# defaults are DETECTED from the script's own location, not configured -- see
# the block below. All three remain overridable for an unusual tree:
#
#   EGG_HOME   directory holding RotEigenform.lean
#   LEAN_ROOT  a BUILT workspace with mathlib (this module imports it)
#   MOD_PATH   module path inside that workspace; must start with `Proofs`
#
# ATTRIBUTION. A non-zero exit is not accepted as a kill on its own. The build
# log must carry an error anchored at `^error: Proofs.../RotEigenform.lean:N`,
# and the theorem names are read back out of the file at those lines. A build
# that fails for an unrelated reason is reported DISCARDED, never KILLED --
# without this, a broken dependency would score all 41 mutants as kills and the
# suite would report a perfect record while testing nothing.
# =============================================================================

set -uo pipefail

# --- LAYOUT DETECTION -------------------------------------------------------
# This suite runs from two places and must behave identically in both:
#
#   repo       lean/mutate/mutate_roteigenform.sh   -> lean/Proofs/RotEigenform.lean
#   standalone RoT-EasterEgg/mutate_roteigenform.sh -> D:/Lean/proofs workspace
#
# Detected from the script's own location rather than configured, because a
# suite that needs the right environment variable to be correct is a suite that
# will one day be run without it and score every mutant DISCARDED.
_HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$_HERE/../Proofs/RotEigenform.lean" ]; then
  # In-repo: the source IS the build target, so no copy step is needed.
  EGG_HOME="${EGG_HOME:-$_HERE/../Proofs}"
  LEAN_ROOT="${LEAN_ROOT:-$_HERE/..}"
  MOD_PATH="${MOD_PATH:-Proofs}"
else
  EGG_HOME="${EGG_HOME:-$_HERE}"
  LEAN_ROOT="${LEAN_ROOT:-D:/Lean/proofs}"
  MOD_PATH="${MOD_PATH:-Proofs/RotEasterEgg}"
fi
MOD_NAME="$(echo "$MOD_PATH" | tr '/' '.').RotEigenform"

# Everything below anchors error attribution on a path that must begin with
# `Proofs`. Assert it rather than assume it: if MOD_PATH is ever overridden to
# something else, the anchor would silently match nothing and every kill would
# be scored DISCARDED -- a suite that reports "nothing was tested" is recoverable,
# but only if it says so instead of drifting.
case "$MOD_PATH" in
  Proofs|Proofs/*) ;;
  *) echo "FATAL: MOD_PATH='$MOD_PATH' does not start with 'Proofs'."
     echo "Error attribution is anchored on that prefix and would match nothing."
     exit 2 ;;
esac
_SUB="${MOD_PATH#Proofs}"

LOG="$(mktemp -d "${TMPDIR:-/tmp}/muteigenform.XXXXXX")"
SRC="$EGG_HOME/RotEigenform.lean"
DST="$LEAN_ROOT/$MOD_PATH/RotEigenform.lean"
OLEAN="$LEAN_ROOT/.lake/build/lib/lean/$MOD_PATH/RotEigenform.olean"

# --- NO-DOWNLOAD GUARD ------------------------------------------------------
# `lake build` RESOLVES the package first, and against an unbuilt tree that
# resolution starts fetching mathlib -- gigabytes. A workspace that was never
# built cannot satisfy this suite, so it SKIPS rather than builds.
# Exit 3 is a skip, and a skip is NEVER a pass.
[ -f "$SRC" ] || {
  echo "FATAL: $SRC not found. Refusing to run: every mutant would fail to"
  echo "build and be scored KILLED without a line having been mutated."
  exit 2
}
if [ ! -d "$LEAN_ROOT/.lake/packages" ]; then
  echo "SKIP: $LEAN_ROOT is not a BUILT Lean workspace."
  echo "      Refusing to invoke lake: resolving mathlib would DOWNLOAD gigabytes."
  echo "      Set LEAN_ROOT to an already-built workspace to run this suite."
  echo "      This is a SKIP (exit 3), never a pass."
  exit 3
fi

mkdir -p "$LEAN_ROOT/$MOD_PATH"
# In the repo layout SRC and DST are the same file; `cp` would refuse. The
# comparison is on resolved paths, not on the strings, so a symlink or a `..`
# in either cannot make this miss.
if [ "$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC")" \
     != "$(cd "$(dirname "$DST")" && pwd)/$(basename "$DST")" ]; then
  cp "$SRC" "$DST"
fi

if ! ( cd "$LEAN_ROOT" && lake build "$MOD_NAME" ) >"$LOG/pre.log" 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build ($MOD_NAME)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 "$LOG/pre.log"
  exit 2
fi
echo "preflight: the baseline builds GREEN -- kills are attributable"

# --- SOURCE SANITY ----------------------------------------------------------
# An EMPTY Lean file builds green. "The baseline compiles" is therefore a weaker
# statement than it looks, and a truncated source copied over the backup would
# score the whole suite as DISCARDED while destroying the file. Content is
# checked BEFORE anything is copied.
_lines=$(wc -l < "$SRC" 2>/dev/null || echo 0)
_thms=$(grep -c "^theorem \|^example " "$SRC" 2>/dev/null || echo 0)
if [ "${_lines:-0}" -lt 100 ] || [ "${_thms:-0}" -lt 20 ]; then
  echo "FATAL: $SRC looks DAMAGED ($_lines lines, $_thms theorems)."
  echo "Refusing to overwrite its backup. Restore it before running this suite."
  exit 2
fi
BAK="$LOG/RotEigenform.lean.mutbak"
cp "$SRC" "$BAK"
trap 'cp "'"$BAK"'" "'"$DST"'" 2>/dev/null' EXIT

killed=0; survived=0; discarded=0

run_mut() {
  local id="$1" needle="$2" repl="$3" expect="$4"

  # ONLY="E32 E33" runs a subset. Added because the full suite now exceeds a
  # single foreground shell timeout, and a suite killed mid-run can leave a
  # mutant on disk -- the split keeps every run bounded and self-restoring.
  # Mutants skipped this way are NEITHER killed nor survived: they are simply
  # not run, and the totals below count only what actually executed.
  if [ -n "${ONLY:-}" ] && [[ " $ONLY " != *" $id "* ]]; then
    return 0
  fi

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
  }' "$BAK" > "$DST"

  local after_needle after_repl
  after_needle=$(grep -F -c -- "$needle" "$DST")
  after_repl=$(grep -F -c -- "$repl" "$DST")
  if [ "$after_needle" -ne 0 ] || [ "$after_repl" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed (needle=$after_needle repl=$after_repl)"
    discarded=$((discarded+1)); cp "$BAK" "$DST"; return
  fi

  # Lake is incremental and will happily not rebuild a module it believes is
  # unchanged. Deleting the artifact removes the doubt.
  rm -f "$OLEAN"
  ( cd "$LEAN_ROOT" && lake build "$MOD_NAME" ) > "$LOG/$id.log" 2>&1
  local ec=$?

  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   (build still exit 0)  expected to kill: $expect"
    survived=$((survived+1))
  else
    # ANCHORED ATTRIBUTION -- a non-zero exit is NOT by itself a kill.
    #
    # A build can fail for reasons that have nothing to do with the mutant: a
    # broken dependency, a missing olean upstream, a toolchain that moved. Every
    # one of those would be scored as a kill by an exit-code test, and the suite
    # would report a perfect record while testing nothing. The error must be
    # attributed to THIS module, anchored at the start of the line so that a
    # module name merely quoted inside some other message cannot satisfy it.
    # `$_SUB` is "" in the repo layout and "/RotEasterEgg" standalone, so the
    # anchor below is literally `^error: Proofs...` in BOTH -- which is also what
    # checker/workflow-lint.sh greps every suite for. Using `basename $MOD_PATH`
    # here was wrong: standalone it would have anchored on `^error: RotEasterEgg`
    # and matched nothing, turning every real kill into a DISCARDED.
    local dead
    dead=$(grep -oE "^error: Proofs${_SUB}/RotEigenform\.lean:[0-9]+" \
             "$LOG/$id.log" | grep -oE '[0-9]+$' | sort -un | while read -r ln; do
        awk -v L="$ln" '
          /^(theorem|def|noncomputable def|private def|instance|structure|inductive|example)/ {
            if (NR <= L) { name=$0 }
          }
          END { if (name != "") print name }
        ' "$DST"
      done | sed -E 's/^(private |noncomputable )?(theorem|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' \
      | sort -u | tr '\n' ',')

    if [ -z "$dead" ]; then
      echo "$id  DISCARDED  build failed (exit=$ec) but NO error is anchored to"
      echo "        RotEigenform.lean -- the failure is not attributable to this"
      echo "        mutant. Counting it as a kill would be a false green."
      sed -n '1,4p' "$LOG/$id.log" | sed 's/^/        /'
      discarded=$((discarded+1)); cp "$BAK" "$DST"; return
    fi

    # The reported error lines are a LOWER BOUND on what died, not an inventory:
    # a mutant build produces no olean, so every theorem in the module is
    # unusable downstream regardless of which line the elaborator stopped at.
    if [ ! -f "$OLEAN" ]; then
      echo "$id  KILLED     exit=$ec  MODULE DEAD (no olean: every theorem unusable)"
      echo "        errors at: ${dead%,}  <- LOWER BOUND, not the full set"
      echo "        expected: $expect"
    else
      echo "$id  KILLED     exit=$ec  dead: ${dead%,}"
    fi
    killed=$((killed+1))
  fi
  cp "$BAK" "$DST"
}

echo "=== RotEigenform mutation suite (the Easter Egg, and the math under it) ==="

# --- §1  the interpolator, transcribed from shipped GPL Java ----------------

# E01 -- THE CLAMP IS DELETED. This is the defect that would let a preset emit a
# frequency outside the envelope its author drew: an interpolation factor above
# 1 extrapolates past the endpoint instead of stopping at it.
run_mut E01 \
  'noncomputable def clamp01 (f : ℝ) : ℝ := if f > 1 then 1 else if f < 0 then 0 else f' \
  'noncomputable def clamp01 (f : ℝ) : ℝ := f' \
  'clamp01_nonneg, clamp01_le_one, lerp_mem_segment'

# E02 -- the upper clamp only. Half a safety check is the shape a real bug takes.
run_mut E02 \
  'if f > 1 then 1 else if f < 0 then 0 else f' \
  'if f > 1 then 1 else f' \
  'clamp01_nonneg, lerp_mem_segment'

# E03 -- the blend stops being convex: the weights no longer sum to 1, so the
# output leaves the segment. This is the arithmetic error that `blend_mem`
# exists to forbid, in both machines at once.
run_mut E03 \
  'noncomputable def blend (a b m : ℝ) : ℝ := a * (1 - m) + b * m' \
  'noncomputable def blend (a b m : ℝ) : ℝ := a * (1 + m) + b * m' \
  'blend_mem, sine_is_a_blend, lens_contribution_is_bounded'

# E04 -- the sigmoid loses its saturation and becomes unbounded. A divergence
# could then contribute more than a lens is worth.
run_mut E04 \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1/2)))' \
  'noncomputable def sigma (x : ℝ) : ℝ := Real.exp (4 * (x - 1/2))' \
  'sigma_lt_one, lens_contribution_is_bounded, lens_contribution_is_strict'

# --- §2  the transcription of frequencies.html ------------------------------

# E05 -- THE TRANSCRIPTION IS FALSIFIED. The 8 Hz overlap is removed by moving
# the "Reduces stress" row off 8.000 Hz. If the ambiguity claim were an
# invention rather than a reading of frequencies.html, this would not matter.
run_mut E05 \
  '  , ⟨8000,  8600,  "Reduces stress"⟩' \
  '  , ⟨8001,  8600,  "Reduces stress"⟩' \
  'sine_table_ambiguous_at_8, sine_table_is_not_deterministic'

# E06 -- the gap disappears: Euphoria is stretched UPWARD to swallow 25 Hz.
#
# THIS MUTANT SURVIVED ON ITS FIRST RUN IN THE PREVIOUS EDITION, AND THE MUTANT
# WAS WRONG -- NOT THE THEOREM. It stretched Euphoria DOWNWARD, to a range that
# still did not reach the 25 Hz the theorem names, so the build stayed green
# correctly. A survivor is never a licence to weaken the theorem it failed to
# kill; the repair belongs in the mutant.
run_mut E06 \
  '  , ⟨18000, 24000, "Euphoria"⟩' \
  '  , ⟨18000, 26000, "Euphoria"⟩' \
  'sine_table_has_gaps'

# E07 -- the determinate frequency is made ambiguous too, which would make the
# table uniformly broken and the non-vacuity theorem false.
run_mut E07 \
  '  , ⟨30000, 30000, "Believed to mimic the effects of Marijuana"⟩' \
  '  , ⟨29000, 31000, "Believed to mimic the effects of Marijuana"⟩' \
  'sine_table_is_determinate_somewhere, lambda_value_is_a_table_row'

# E08 -- claims() flips to an OR, so a row claims everything outside itself.
run_mut E08 \
  'def claims (b : Band) (x : ℤ) : Bool := decide (b.lo ≤ x) && decide (x ≤ b.hi)' \
  'def claims (b : Band) (x : ℤ) : Bool := decide (b.lo ≤ x) || decide (x ≤ b.hi)' \
  'every counting theorem in §2 and §8'

# --- §3  the palace and the router ------------------------------------------

# E09 -- the palace is given nine loci for nine thoughts, so the pigeonhole
# vanishes and the method-of-loci limit stops being a limit.
run_mut E09 \
  'theorem palace_needs_room (place : Fin 10 → Lane) : ¬ Function.Injective place := by' \
  'theorem palace_needs_room (place : Fin 9 → Lane) : ¬ Function.Injective place := by' \
  'palace_needs_room -- 9 into 9 CAN be injective'

# --- §5  the butterfly -------------------------------------------------------

# E10 -- the butterfly is asked for a perturbation that does NOT move the
# output. Sensitive dependence is the one modellable half of the Ultimate
# Equation, and this is the mutant that checks it was really proved.
run_mut E10 \
  '∃ f'"'"' : ℝ, |f'"'"' - (1/2)| < ε ∧ lerpWithPow a b f'"'"' 1 ≠ lerpWithPow a b (1/2) 1' \
  '∃ f'"'"' : ℝ, |f'"'"' - (1/2)| < ε ∧ lerpWithPow a b f'"'"' 1 = lerpWithPow a b (1/2) 1' \
  'butterfly -- the proof produces a DIFFERENT value, not an equal one'

# --- §2b  the two rows that actually went missing ---------------------------
# These are the mutants that would have caught the real defect. They did not
# exist when the defect shipped, which is precisely why they exist now.

# E11 -- Desensitizer is pushed BELOW the 30 Hz row, so no row remains above
# Marijuana and the table's top really is 30 Hz -- the exact false state the
# original truncation created.
#
# THIS MUTANT SURVIVED ITS FIRST RUN, AND THE MUTANT WAS WRONG -- NOT THE
# THEOREM. It first moved Desensitizer from 32 Hz to 31 Hz, which is still
# ABOVE 30, so `thirty_is_not_the_top` (∃ a row with lo > 30000) remained true
# and the build stayed green, correctly. Moving a number is not the same as
# contradicting a statement about it. Corrected DOWNWARD, to 29 Hz, where the
# theorem genuinely has nothing left to witness.
run_mut E11 \
  '  , ⟨32000, 32000, "Desensitizer"⟩' \
  '  , ⟨29000, 29000, "Desensitizer"⟩' \
  'thirty_is_not_the_top -- no row would be above 30 Hz any more'

# E12 -- the LSD row is rounded to a tenth of a Hz, which is the exact
# arithmetic that erased it. 20.215 -> 20.200 Hz.
run_mut E12 \
  '  , ⟨20215, 20215, "Believed to mimic the effects of LSD"⟩' \
  '  , ⟨20200, 20200, "Believed to mimic the effects of LSD"⟩' \
  'lsd_row_is_present'

# E13 -- the universal gap theorem loses its `+1` and stops exceeding every
# upper bound, so the witness it produces may be claimed after all.
run_mut E13 \
  'refine ⟨(t.map Band.hi).foldr max 0 + 1, ?_⟩' \
  'refine ⟨(t.map Band.hi).foldr max 0, ?_⟩' \
  'every_finite_table_has_a_gap'

# --- §7  the corpus measurement ---------------------------------------------
# A measured constant is only evidence if getting it wrong breaks something.

# E14 -- the envelope total is falsified by one. The cross-check that proves the
# census was not a miscount (tracks*3 + presets = envelopes) must fail.
run_mut E14 \
  'def corpusEnvelopes : ℕ := 3750' \
  'def corpusEnvelopes : ℕ := 3751' \
  'corpus_envelope_count_is_forced'

# E15 -- the dialect split is falsified, using the very number the single-quote
# parser bug produced. This is the mutant that models the real defect.
run_mut E15 \
  'def corpusSingleQuote : ℕ := 104' \
  'def corpusSingleQuote : ℕ := 190' \
  'corpus_dialects_partition'

# E16 -- the escape fraction is deflated until the corpus appears to stay inside
# its own table. If the 37.3% result survived this, it would be decoration.
run_mut E16 \
  'def corpusUnclaimed : ℕ := 3068' \
  'def corpusUnclaimed : ℕ := 2000' \
  'corpus_escapes_the_table, corpus_coverage_is_exhaustive'

# --- §8  the isopsephy collision --------------------------------------------

# E17 -- Theta is moved out of the hole and into the Alertness band, which would
# destroy the one asymmetry that keeps §8 honest: the fact that the letters do
# NOT all line up.
run_mut E17 \
  '  , ("Theta",   9000)' \
  '  , ("Theta",   10000)' \
  'theta_falls_in_a_hole, the_ensemble_number_is_the_gap'

# E18 -- the quartz outlier is moved onto a frequency the table DOES claim. The
# largest value anyone uploaded being unclaimed is the corpus-escape result at
# its extreme, and this checks the theorem is about that value.
run_mut E18 \
  'theorem clear_quartz_is_unclaimed : claimants sineTable 32768000 = 0 := by decide' \
  'theorem clear_quartz_is_unclaimed : claimants sineTable 32000 = 0 := by decide' \
  'clear_quartz_is_unclaimed -- 32 Hz IS claimed, by Desensitizer'

# --- §9  the per-preset walk over all 498 -----------------------------------
# The histograms are the strongest empirical claim in the file. If a bucket can
# be falsified without anything failing, the walk was decoration.

# E19 -- one preset is moved from the alpha bucket to the beta bucket. Both
# histograms still LOOK plausible; only the partition theorem sees it.
run_mut E19 \
  'def bandAlpha : ℕ := 143' \
  'def bandAlpha : ℕ := 142' \
  'band_histogram_is_a_partition, alpha_is_the_busiest_band'

# E20 -- the single-band bucket is inflated until multi-band presets are no
# longer the majority. This is the mutant for the headline of §9.
run_mut E20 \
  'def spans1 : ℕ := 169' \
  'def spans1 : ℕ := 300' \
  'span_histogram_is_a_partition, multi_band_outnumbers_single'

# E21 -- the "not two thirds" guard is inverted by inflating the six-band tail
# until the fraction really would clear 2/3. The guard exists to stop a round
# number creeping into the prose, so it must die when the number changes.
run_mut E21 \
  'def spans6 : ℕ := 59' \
  'def spans6 : ℕ := 130' \
  'span_histogram_is_a_partition, it_is_a_majority_but_not_two_thirds'

# --- §10  the Library of Babel ----------------------------------------------

# E22 -- Borges' page arithmetic is falsified. 410*40*80 is the one place in
# this file where a number is read straight out of a Phantom Book, so it is the
# one place a transcription slip would look exactly like the §2 defect.
run_mut E22 \
  'def babelChars : ℕ := 410 * 40 * 80' \
  'def babelChars : ℕ := 410 * 40 * 81' \
  'babel_characters_per_book'

# E23 -- the library law is inverted: n ^ 25 instead of 25 ^ n. The alphabet and
# the book length swap roles, which is the classic off-by-a-transposition in a
# combinatorial count and is invisible to the eye at a glance.
run_mut E23 \
  'theorem library_card (n : ℕ) : Fintype.card (Fin n → Fin 25) = 25 ^ n := by' \
  'theorem library_card (n : ℕ) : Fintype.card (Fin n → Fin 25) = n ^ 25 := by' \
  'library_card'

# E24 -- the Library collapses to a single book. Both the "dwarfs the corpus"
# result and the non-triviality guard must die: a space with one reality in it
# makes §5's butterfly meaningless, and that is exactly what the non-vacuity
# theorem is there to forbid.
run_mut E24 \
  'def babelBooks : ℕ := 25 ^ babelChars' \
  'def babelBooks : ℕ := 25 ^ 0' \
  'babel_dwarfs_the_corpus, babel_is_not_trivial'

# --- §11  the gauge is dynamic ----------------------------------------------

# E25 -- the confidence factor is DELETED from the gauge term. A gauge that
# ignores C is exactly the "static number with a decimal point" the section
# exists to rule out, and the monotonicity theorem must refuse to hold.
run_mut E25 \
  '  lam * sig * (1 + H) * mu * M * C * T' \
  '  lam * sig * (1 + H) * mu * M * T' \
  'gauge_strict_in_C, gauge_is_not_constant, gauge_strict_in_T'

# --- §12  the Nova-Violet Role Merging Law -----------------------------------

# E26 -- the hybridisation gain is removed: fusion becomes the plain mean. This
# is the single most plausible "simplification" anyone would make to
# Symbiogenesis, and it must not survive.
run_mut E26 \
  '  { lam := (a.lam + b.lam) / 2 + 1/5' \
  '  { lam := (a.lam + b.lam) / 2' \
  'merge_gain_is_exactly_one_fifth, nova_violet_hybrid'

# E27 -- the novelty margin on entropy is removed, so a hybrid is exactly as
# predictable as its more chaotic parent.
run_mut E27 \
  '  , hHi := max a.hHi b.hHi + 1/20 }' \
  '  , hHi := max a.hHi b.hHi }' \
  'merge_entropy_strictly_exceeds, nova_violet_hybrid, nova_violet_entropy_is_the_table_floor'

# E28 -- mu is given a gain term it does not have in the specification. The one
# place Symbiogenesis refuses a bonus is the one place a careless edit adds one.
#
# THIS MUTANT WAS DISCARDED ON ITS FIRST RUN, AND THE HARNESS WAS RIGHT.
# The replacement was written as `max a.mu b.mu + 1/10`, which CONTAINS the
# needle `max a.mu b.mu` as a prefix -- so the post-check "the needle is gone"
# could never be satisfied, no matter how well the patch applied. It was
# reported DISCARDED rather than SURVIVED, which is the entire point of keeping
# those two counts apart: a harness limitation must never be readable as a
# claim about the theorem. Rewritten with the gain on the LEFT so the needle
# genuinely disappears.
run_mut E28 \
  '  , mu := max a.mu b.mu' \
  '  , mu := 1/10 + max a.mu b.mu' \
  'merge_mu_has_no_gain, nova_violet_hybrid'

# E29 -- the merge is made NON-COMMUTATIVE by taking the FIRST parent's entropy
# instead of the higher one. A "merging law" whose result depends on which lens
# you name first is not a merging law, and `merge_comm` is the theorem that says
# so. Single-line on purpose: a needle that spans lines is the classic way a
# mutant silently fails to apply and gets scored SURVIVED.
run_mut E29 \
  '  , hHi := max a.hHi b.hHi + 1/20 }' \
  '  , hHi := a.hHi + 1/20 }' \
  'merge_comm, merge_entropy_strictly_exceeds'

# E30 -- Violet is retuned. Every downstream number about the hybrid must move,
# and this is the mutant that proves §12 is about the ROSTER rather than about
# three hard-coded fractions.
run_mut E30 \
  'def violet : Lens := ⟨13/10, 19/20, 9/20⟩' \
  'def violet : Lens := ⟨13/10, 19/20, 8/20⟩' \
  'nova_violet_hybrid, nova_violet_entropy_is_the_table_floor'

# E31 -- the table floor is lowered by editing the Pain relief row. The claim
# that the merged entropy sits exactly ON the floor must then be false.
run_mut E31 \
  '  [ ⟨500,   1500,  "Pain relief"⟩' \
  '  [ ⟨400,   1500,  "Pain relief"⟩' \
  'table_floor_is_500, nova_violet_entropy_is_the_table_floor'

# --- §13  weights and quantization -------------------------------------------

# E32 -- the sigmoid's slope is set to ZERO, making sigma a constant function.
# This is the mutant that decides whether the butterfly section says anything:
# a constant quantizer is not injective, no wingbeat changes anything, and the
# gauge really would be static.
run_mut E32 \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1/2)))' \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (0 * (x - 1/2)))' \
  'sigma_strictly_mono, sigma_is_injective, butterfly_resolves, weights_are_what_discriminate'

# --- §14/§15  the books, the sutras, the sigils, the numerals ----------------

# E33 -- the Egyptian "infinite" numeral is moved off its power of ten.
run_mut E33 \
  'def egyptianInfinite : ℕ := 10000000' \
  'def egyptianInfinite : ℕ := 10000001' \
  'egyptian_infinity_is_finite, three_corpora_one_regime, egyptian_system_is_closed_under_ten'

# E34 -- the numeral list loses its top entry, so it is no longer 10^0..10^7.
run_mut E34 \
  'def egyptianNumerals : List ℕ := [1, 10, 100, 1000, 10000, 100000, 1000000, 10000000]' \
  'def egyptianNumerals : List ℕ := [1, 10, 100, 1000, 10000, 100000, 1000000]' \
  'egyptian_numerals_are_powers_of_ten, egyptian_infinity_is_finite'

# E35 -- the sigil count is moved off 9x8. If this survives, the "72 = ordered
# pairs of lenses" claim was about the numeral and not about the roster.
run_mut E35 \
  'def solomonSpirits : ℕ := 72' \
  'def solomonSpirits : ℕ := 71' \
  'sigils_are_the_ordered_pairs'

# E36 -- the sutra count is raised past the chapter count, so the book would
# have more rules than chapters presenting them.
run_mut E36 \
  'def vedicSutras : ℕ := 16' \
  'def vedicSutras : ℕ := 41' \
  'vedic_rules_fewer_than_chapters, vedic_volumes_match_sutras'

# E37 -- a real book is deleted from the corpus list, dropping 14 to 13.
run_mut E37 \
  '    "Lesser Key of Solomon", "The Library of Babel",' \
  '    "The Library of Babel",' \
  'real_books_outnumber_phantom'

# E38 -- the phantom list is padded until the fiction outnumbers the world. The
# asymmetry that licenses this whole file must not survive its own negation.
run_mut E38 \
  '  [ "Book of Fairy", "Book of Styx", "Book of Wisdom", "Book of the Eleusis Ritual" ]' \
  '  [ "Book of Fairy", "Book of Styx", "Book of Wisdom", "Book of the Eleusis Ritual", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k" ]' \
  'real_books_outnumber_phantom'

# --- §17/§18  convergence and the EIGENFORM ----------------------------------

# E39 -- the sigmoid's CENTRE is moved off 1/2. The eigenform sigma(1/2)=1/2 is
# a consequence of that constant, and the three-way agreement with the hybrid
# entropy and the table floor must collapse with it. If this survives, the
# eigenform section was arithmetic about numerals and not about the router.
run_mut E39 \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1/2)))' \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1/3)))' \
  'sigma_fixed_point, eigenform_survives_infinite_recursion, eigenform_binds_router_law_and_corpus'

# E40 -- the slope SIGN is flipped, so the quantizer runs backwards: it would
# converge to 0 at +infinity and 1 at -infinity. The two limit theorems name a
# direction, and a mutant that reverses it must not pass.
run_mut E40 \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (-4 * (x - 1/2)))' \
  'noncomputable def sigma (x : ℝ) : ℝ := 1 / (1 + Real.exp (4 * (x - 1/2)))' \
  'sigma_tendsto_one_atTop, sigma_tendsto_zero_atBot, sigma_strictly_mono'

# E41 -- the merged entropy gain is changed so the Nova-Violet hybrid no longer
# lands on 1/2. This is the mutant that decides whether the eigenform's
# three-way agreement is about `merge` or about a hard-coded fraction.
run_mut E41 \
  '  , hHi := max a.hHi b.hHi + 1/20 }' \
  '  , hHi := max a.hHi b.hHi + 1/10 }' \
  'nova_violet_hybrid, eigenform_binds_router_law_and_corpus'

echo
# --- back to a VERIFIED green baseline ---------------------------------------
# A mutation run that does not end at a clean baseline has told you nothing
# about the final state of the tree.
cp "$BAK" "$DST"
rm -f "$OLEAN"
if ! ( cd "$LEAN_ROOT" && lake build "$MOD_NAME" ) > "$LOG/post.log" 2>&1; then
  echo "FATAL: the tree does NOT build after restoring ($MOD_NAME)."
  echo "The suite has left this workspace red. Do not trust the counts above."
  tail -5 "$LOG/post.log"
  exit 2
fi
if [ ! -f "$OLEAN" ]; then
  echo "FATAL: $MOD_NAME built but produced no olean -- downstream probes will fail."
  exit 2
fi
echo "baseline restored and REBUILT green (olean present again)"

echo "=== RotEigenform: killed=$killed survived=$survived discarded=$discarded ==="
# DISCARDED is reported on its own line and never folded into survived: the first
# is a defect in this harness, the second a claim about a theorem.
if [ "$survived" -gt 0 ] || [ "$discarded" -gt 0 ]; then exit 1; fi
exit 0
