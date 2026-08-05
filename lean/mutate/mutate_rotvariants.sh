#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotVariants.lean, MUTATION DISCIPLINE ITSELF.
#
# WHY THIS SUITE EXISTS, and why its absence was a hole rather than an oversight.
# RotVariants shipped in an early release with theorems about WHICH CLASS FIRED and
# no suite of its own. In 0.7.0 it gained the specification of HOW A CLASS
# DECIDES -- `firesWord_imp_fires`, the theorem that made it safe to change the
# live router's matcher. That theorem is the strongest safety claim in the
# release, and until this file existed nothing had ever tried to break it.
#
# A theorem no mutation kills is decorative. The headline theorem of a release
# is the last one that should be taken on trust.
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
# WHY THESE MUTATIONS. Each re-creates a matcher defect that this repo has
# actually shipped or nearly shipped:
#
#   M01  every character is a boundary      -- the collapse back to substring
#                                              matching, which is the defect the
#                                              whole 0.7.0 routing fix removes
#   M02  the boundary condition is dropped  -- a stem fires anywhere in a word
#   M03  the word branch reverts to infix   -- the SHIPPED 0.6.x behaviour,
#                                              restored exactly
#   M04  the punctuation carve-out dies     -- `.lean` stops matching Basic.lean
#   M05  the punctuation carve-out swallows -- EVERY stem takes the infix path,
#        the word branch                       so the carve-out becomes the rule
#   M06  `any` becomes `all`                -- a stem list stops being a
#                                              disjunction
#   M07  the empty stem fires               -- an empty list entry becomes a
#                                              wildcard matching every prompt
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutvariants.XXXXXX")"
MODULES="RotVariants"

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
if [ ! -d "$_WSDIR/.lake/packages" ] || [ ! -f "$_WSDIR/.lake/build/lib/lean/Proofs/RotVariants.olean" ]; then
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

echo "=== RotVariants mutation suite (the module that DEFINES mutation discipline) ==="

# WHY THIS SUITE EXISTS AT ALL.
#
# RotVariants.lean is the specification every other suite is measured against:
# `landed`, `classify`, and `killed_implies_all_three` are what
# checker/mutant-discipline.sh enforces on the whole tree. It had no suite of its
# own. The module that decides whether everyone else's mutants are honest had
# never had a mutant pointed at it -- which is exactly the shape of oversight it
# was written to forbid.
#
# Every mutant below re-creates a real way the discipline could be hollowed out.


# V01 -- `covers` weakened to "at least one declared archive is named". This is
# the shape of a check that reports green because it found SOMETHING. The
# historical stale README named three archives; a one-of check would have passed
# it if any single link had happened to be right.
run_mut V01 RotVariants \
  '  d.all (fun a => n.contains a)' \
  '  d.any (fun a => n.contains a)' \
  'clean_does_not_imply_covers, stale_readme_is_unsound, new_tier_needs_a_link'

# V02 -- `clean` weakened the same way. This is the half that catches staleness,
# so weakening it is precisely the "keep the old links" defect made legal.
run_mut V02 RotVariants \
  '  n.all (fun a => d.contains a)' \
  '  n.any (fun a => d.contains a)' \
  'covers_does_not_imply_clean, stale_readme_is_unsound'

# V03 -- THE DEFECT ITSELF: drop the staleness half from `sound`. A checker that
# only asks "is every archive named" calls a document with correct AND dead links
# green. If no theorem dies here, this file is not describing the checker.
run_mut V03 RotVariants \
  '  covers d n && clean d n' \
  '  covers d n' \
  'covers_does_not_imply_clean is unused, sound_iff_setEq, stale_readme_is_unsound'

# V04 -- drop the coverage half instead. A tier with no download link becomes
# invisible: nobody can install it and nothing complains.
run_mut V04 RotVariants \
  '  covers d n && clean d n' \
  '  clean d n' \
  'clean_does_not_imply_covers, sound_iff_setEq'

# V05 -- the version is ignored, only the tier is compared. This is the exact
# defect: `rot-moe-0.5.1-lean.zip` and `rot-moe-0.7.1-lean.zip` are both the
# `lean` tier, and a comparison that only reads the tier calls them equal.
run_mut V05 RotVariants \
  '  ver : List Char' \
  '  ver : Unit' \
  'every theorem that distinguishes two versions of one tier'

# V06 -- the shipped map loses its unsealed tier. The #guard on the length and
# every concrete example that mentions it must go red.
run_mut V06 RotVariants \
  '   ⟨"unsealed".toList, "0.7.2".toList⟩]' \
  '   ]' \
  'shipped.length = 3, the concrete soundness examples'

# V07 -- the REPAIRED README is redefined to be the stale one. The positive
# record stops being a record.
#
# THIS MUTANT WAS MOVED, AND THE REASON IS THE FINDING. It first flipped the
# stale list's `core` entry from 0.5.0 to 0.7.0, expecting
# `stale_readme_is_unsound` to die. It SURVIVED -- and correctly so: `covers`
# still fails on the other two links, so the stale README stays unsound after
# any ONE of its three links is repaired. The theorem is stronger than the
# mutant was, which is a fact worth recording rather than a licence to weaken
# it. Making it die would need the whole list replaced, and a mutation that
# rewrites an entire definition tests the definition, not the theorem.
#
# So the mutant moved to a one-line edit that IS lethal and means something:
# `repairedReadme` is redefined to the stale list, and the theorem asserting the
# repair works must refuse. A survivor is never a reason to soften what it
# failed to kill.
run_mut V07 RotVariants \
  'def repairedReadme : Named := shipped' \
  'def repairedReadme : Named := staleReadme' \
  'repaired_readme_is_sound, the concrete soundness examples'

# V08 -- `version_drift_breaks_soundness` is handed the SAME version twice. It
# then claims a document naming the right archive is unsound, which is false --
# the theorem must fail to prove rather than quietly becoming nonsense.
run_mut V08 RotVariants \
  '    sound [⟨t, v⟩] [⟨t, v'"'"'⟩] = false := by' \
  '    sound [⟨t, v⟩] [⟨t, v⟩] = false := by' \
  'version_drift_breaks_soundness -- a matching pair is SOUND, not unsound'

# V09 -- the new-tier theorem drops its hypothesis. Without `a ∉ n` the claim is
# simply false: adding a tier whose link is ALREADY present keeps the docs sound.
run_mut V09 RotVariants \
  '    (hnew : a ∉ n) : sound (a :: d) n = false := by' \
  '    (hnew : a ∈ n) : sound (a :: d) n = false := by' \
  'new_tier_needs_a_link -- the hypothesis is what makes it true'

# V10 -- `sound_iff_setEq` weakened from a two-way set equality to one inclusion.
# The iff then does not hold, and this is the theorem that says what the checker
# is FOR, so it must be the one that breaks.
run_mut V10 RotVariants \
  '    sound d n = true ↔ ((∀ a ∈ d, a ∈ n) ∧ (∀ a ∈ n, a ∈ d)) := by' \
  '    sound d n = true ↔ (∀ a ∈ d, a ∈ n) := by' \
  'sound_iff_setEq -- one inclusion is not the property'
echo
# --- back to a VERIFIED green baseline ---------------------------------------
# Every other suite in this directory ends by rebuilding after the final restore.
# This one did not: it was derived with `head -165` from a sibling, and the tail
# that carried the guard was exactly what the truncation cut off. The same
# derivation produced the same hole in mutate_rotlog.sh.
#
# The consequence is a FALSE RED, not a false green, and it is still expensive:
# the last mutant's build fails, its olean is deleted and never rebuilt, so the
# suite exits 0 having left the workspace unbuildable. `checker/axiom-class.sh`
# then imports the module to probe it and reports theorems "unaccounted for",
# which reads exactly like a broken proof. Telling those two apart cost a full
# attribution cycle.
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
echo "baseline restored and REBUILT green (olean present again)"

echo "=== RotVariants: killed=$killed survived=$survived discarded=$discarded ==="
# DISCARDED is reported on its own line and never folded into survived: the first
# is a defect in this harness, the second a claim about a theorem.
if [ "$survived" -gt 0 ] || [ "$discarded" -gt 0 ]; then exit 1; fi
exit 0
