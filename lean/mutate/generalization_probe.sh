#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE GENERALIZATION PROBE -- does the theorem actually constrain the function?
#
# The sharpest test for a decorative theorem: take the statement, replace the
# SPECIFIC function with an ARBITRARY one of the same type, and ask whether the
# statement is still true. If it is, the theorem never said anything about the
# function -- the name and the doc comment were carrying the meaning.
#
# That is how `classify_total` was caught in this repo:
#
#   classify_total : exists-unique b, classify lo hi R = b
#
# holds with `classify` replaced by any f whatsoever. Green, clean axioms,
# survived leanchecker, said nothing.
#
# -----------------------------------------------------------------------------
# A DEFECT IN THE FIRST VERSION OF THIS FILE, kept in the record because it is
# the more instructive half:
#
# The first design wrote each generalized statement and required it to FAIL to
# compile. Every probe duly failed and every theorem was reported LOAD-BEARING.
# But the failures were `failed to synthesize Decidable (forall f : Flags, ...)`
# -- the TACTIC could not run. A tactic that cannot execute is not evidence that
# a statement is false, and the probe was manufacturing exactly the reassuring
# verdict it existed to challenge. Its own positive control caught it.
#
# So the probes below REFUTE instead: each exhibits a concrete function for
# which the generalized statement is FALSE, and must COMPILE. A refutation that
# elaborates is proof; a tactic that fails to fire is nothing.
# -----------------------------------------------------------------------------
#
# WHY NOT THE AXIOM SWEEP: because it was measured and it failed here. "Depends
# on no axioms" is often cited as a vacuity smell. On this packet it flagged SIX
# theorems -- route_fires, route_covers_every_mode, nsil_overrides_tier1,
# nsil_confirm_is_tier1, nsil_boost_preserves_lead, disarm_preserves_all_scalars
# -- all load-bearing (decidable statements closed by `decide`, which
# legitimately needs no axioms). And it MISSED classify_total, which depends on
# [propext, Classical.choice, Quot.sound] because it is stated over the reals.
# Six false positives and one false negative on the only case where the answer
# was known. It is not used as a gate here, and that is a measurement, not a
# preference.
# =============================================================================

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# LEAN_ROOT is what every mutation suite in this directory honours. Accepting
# only LEAN_DIR here meant `LEAN_ROOT=... generalization_probe.sh` silently ran
# against the VENDORED tree instead of the workspace the caller named -- and
# after the guard below, silently SKIPPED. Two spellings for one concept is how
# that happens; both are accepted now, LEAN_DIR winning because it was first.
LEAN_DIR="${LEAN_DIR:-${LEAN_ROOT:-$(cd "$HERE/.." && pwd)}}"
cd "$LEAN_DIR"

# =============================================================================
# NO-DOWNLOAD GUARD. MEASURED 2026-07-31, and the number is not a typo.
#
# This script calls `lake env lean`, and `lake env` RESOLVES THE PACKAGE before
# it runs anything. Run against the VENDORED `lean/` tree -- which is the
# DEFAULT above, and therefore what a contributor or a CI dry run gets -- that
# resolution began fetching mathlib into the repository and reached **7.2 GB**
# before it was noticed and removed. It also left a `lake-manifest.json` behind.
#
# The tree ships as ~200 KB of source. A script that can silently turn it into
# 7.2 GB is a defect regardless of what it proves afterwards, and "it only
# resolves declared dependencies" is exactly the sentence that precedes the
# download.
#
# So: the workspace must ALREADY be built. A never-built workspace cannot
# satisfy this, which is what makes the fetch impossible rather than unlikely.
# SKIP is exit 3 -- reported as a skip by every caller, never as a pass.
# =============================================================================
_built=$(find "$LEAN_DIR/.lake/build/lib/lean" -name '*.olean' 2>/dev/null | head -1)
if [ ! -d "$LEAN_DIR/.lake/packages" ] || [ -z "$_built" ]; then
  echo "SKIP: $LEAN_DIR is not a BUILT Lean workspace (.lake/packages or the"
  echo "      Proofs.RotGauge .olean is absent)."
  echo "      Refusing to invoke lake here: resolving mathlib would DOWNLOAD"
  echo "      ~7.2 GB into a repository that ships as ~200 KB. Measured, once."
  echo "      Point LEAN_DIR at an already-built workspace to run this probe."
  echo "      This is a SKIP (exit 3), never a pass."
  exit 3
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/genprobe.XXXXXX")"
pass=0; fail=0

probe () {   # probe <name> <expect: OK|NOCOMPILE> <description> <lean source>
  local name="$1" expect="$2" desc="$3" src="$4"
  printf '%s\n' "$src" > "$TMP/$name.lean"
  lake env lean "$TMP/$name.lean" > "$TMP/$name.log" 2>&1
  local rc=$?
  if [ "$expect" = "OK" ]; then
    if [ "$rc" -eq 0 ]; then
      echo "  PASS  $name -- $desc"
      pass=$((pass+1))
    else
      echo "  FAIL  $name -- expected this to compile: $desc"
      sed 's/^/          /' "$TMP/$name.log" | head -6
      fail=$((fail+1))
    fi
  else
    if [ "$rc" -ne 0 ]; then
      echo "  PASS  $name -- $desc (refused, exit $rc)"
      pass=$((pass+1))
    else
      echo "  FAIL  $name -- IT COMPILED, and it must not: $desc"
      fail=$((fail+1))
    fi
  fi
}

echo "== generalization probe =="

# --- the decorative shape, both directions ---------------------------------
probe decorative_holds OK \
  "classify_total's shape holds for an ARBITRARY function: DECORATIVE" '
import Proofs.RotGauge
example (f : ℝ → ℝ → ℝ → RotMoE.Band) (lo hi R : ℝ) : ∃! b, f lo hi R = b :=
  ⟨f lo hi R, rfl, fun _ h => h.symm⟩
'

probe decorative_irrefutable NOCOMPILE \
  "and it cannot be refuted -- confirming it constrains nothing" '
import Proofs.RotGauge
example : ¬ (∀ (f : ℝ → ℝ → ℝ → RotMoE.Band) (lo hi R : ℝ), ∃! b, f lo hi R = b) := by
  intro h
  exact absurd (h (fun _ _ _ => RotMoE.Band.below) 0 0 0) (by simp)
'

# --- THE EXCEPTION: when "it generalizes" is the POINT, not the defect ------
# `lead_does_not_shrink` generalizes -- swap `lead` for any function and it
# still holds. By the rule above that reads DECORATIVE, and it is not: the claim
# README.md:676 makes is "choosing a lead removes NOBODY from the ensemble",
# which is precisely an INDEPENDENCE claim. A statement that survives replacing
# `lead` with an arbitrary function is the strongest form of "the choice cannot
# affect this", not the weakest form of saying nothing.
#
# The distinction is not a loophole, because it costs something: a theorem
# excused this way must be killed by a DIFFERENT mutation, or it is decorative
# after all. The second probe below is that obligation discharged -- shorten the
# roster and the same statement becomes FALSE, so it does constrain the object
# it is really about. Measured 2026-08-03: dropping one lens from `lenses` also
# fails the real theorem in RotLens.lean.
probe lead_shrink_generalizes OK \
  "lead_does_not_shrink generalizes -- INDEPENDENCE is the claim, not a defect" '
import Proofs.RotLens
open RotMoE.Ensemble in
example (f : Mode → Lens) (m : Mode) :
    (lenses.erase (f m)).length = 8 ∧ ∀ l : Lens, l ∈ lenses := by
  refine ⟨?_, by intro l; cases l <;> decide⟩
  cases f m <;> decide
'

probe lead_shrink_roster_sensitive NOCOMPILE \
  "but on a roster of EIGHT the same statement is false -- it constrains the roster" '
import Proofs.RotLens
open RotMoE.Ensemble in
example :
    (([.nova, .violet, .antivenom, .venom, .carnage, .chroma, .soleil, .eidolon]
      : List Lens).erase (lead .clinical)).length = 8 := by decide
'

# --- THE UNCOVERED MODULES -------------------------------------------------
# MEASURED GAP, 2026-08-03: eight mutation suites existed and covered eight
# modules. RotAbility (16 theorems), RotDorks (5), RotLens (13) and RotMutant
# (10) had NONE -- 44 of 144 theorems had never been broken on purpose. That is
# not an academic hole: `lead_does_not_shrink` was an overclaim living in
# RotLens, one of the four, and it survived a year of green builds precisely
# because nothing ever tried to kill it. The three probes below put each
# remaining module under the same instrument.
probe ability_contribution OK \
  "contribution_pos generalized is FALSE (a zero-valued weight contributes nothing)" '
import Proofs.RotAbility
open RotMoE.Ability RotMoE.Ensemble in
example : ¬ (∀ (f : Lens → ℚ) (l : Lens), l ∈ lenses → 0 < f l) := by
  intro h
  exact absurd (h (fun _ => 0) Lens.nova (by decide)) (by norm_num)
'

probe dorks_injective OK \
  "rot_injective generalized is FALSE (a constant rotation collides)" '
import Proofs.RotDorks
example : ¬ (∀ (f : Nat → Nat) (i j : Nat), i < 5 → j < 5 → f i = f j → i = j) := by
  intro h
  exact absurd (h (fun _ => 0) 0 1 (by decide) (by decide) rfl) (by decide)
'

probe mutant_classify OK \
  "killed_implies_all_three generalized is FALSE (an arbitrary verdict proves nothing)" '
import Proofs.RotMutant
open RotMoE in
example : ¬ (∀ (g : Run → Bool → Outcome) (r : Run) (a : Bool),
      g r a = Outcome.killed → r.toolExit = 0) := by
  intro h
  exact absurd (h (fun _ _ => Outcome.killed) { toolExit := 1, empty := false, changed := true } true rfl)
    (by decide)
'

# --- the load-bearing theorems: each generalization is REFUTED -------------
probe route_fires OK \
  "route_fires generalized is FALSE (a constant router does not fire)" '
import Proofs.RotRoute
open RotMoE.Route
example : ¬ (∀ (g : Flags → Mode) (f : Flags), fired f (g f) = true) := by
  intro h
  have := h (fun _ => Mode.forge) ⟨false, false, false, false, false, false, false, false, false⟩
  simp [fired] at this
'

probe disarm_preserves_all_scalars OK \
  "disarm_preserves_all_scalars generalized is FALSE (a function may clobber)" '
import Proofs.RotInstall
open RotMoE.Install
example : ¬ (∀ (d : String → Settings → Settings) (cmd : String) (s : Settings) (k : String),
    (d cmd s).scalar k = s.scalar k) := by
  intro h
  have := h (fun _ _ => ⟨fun _ => some (Val.num 1), fun _ => []⟩) "x"
              ⟨fun _ => none, fun _ => []⟩ "k"
  simp at this
'

probe classify_surjective OK \
  "classify_surjective generalized is FALSE (a constant classifier misses bands)" '
import Proofs.RotGauge
example : ¬ (∀ (f : ℝ → ℝ → ℝ → RotMoE.Band) (lo hi : ℝ), lo ≤ hi →
    ∀ b, ∃ R, f lo hi R = b) := by
  intro h
  obtain ⟨R, hR⟩ := h (fun _ _ _ => RotMoE.Band.below) 0 0 le_rfl RotMoE.Band.above
  exact RotMoE.Band.noConfusion hR
'

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
rm -rf "$TMP"
[ "$fail" -eq 0 ] && exit 0 || exit 1
