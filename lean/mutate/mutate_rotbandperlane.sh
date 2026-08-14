#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotBandPerLane.lean (one band for ten lanes)
#
# WHAT THIS SUITE IS AIMED AT. The module proves that reading every lane's
# R/s+ against a single range cannot reproduce the per-lane law -- the gauge
# did exactly that, using one lane's range for all ten, and a CREATIVE turn at
# 1.4 therefore printed IN RANGE while its own band starts at 1.50 and the
# correct signal was ADD ENTROPY. The theorems are all `decide` over closed
# types and depend on NO axioms, which is precisely the shape that can be
# vacuous. This suite is how that is ruled out rather than asserted.
#
# A theorem that no mutation kills is decorative. These mutants break the band
# table and the classifier in ways a careless edit really could, and each one
# must take the build down. Three rules, all learned the hard way in this repo:
#
#   1. ASSERT THE MUTATION LANDED. A sed whose pattern misses leaves the file
#      untouched, the build stays green, and a naive harness records SURVIVED --
#      which reads as "the theorem is robust" when it means "nothing was tested".
#      A miss is reported as DISCARDED and is never counted as a survival.
#   2. DELETE THE STALE OLEAN. Lake is incremental and will happily not rebuild
#      a module it believes is unchanged.
#   3. END ON A CLEAN BASELINE. A run that does not restore and rebuild has said
#      nothing about the state it leaves behind.
set -u
cd "$(dirname "$0")/.." || exit 2
# THE WORKSPACE IS NAMED, NOT ASSUMED. Without LEAN_ROOT this suite would build
# in whatever directory it happened to be invoked from, and a build that
# succeeds somewhere else proves nothing about this module.
_WSDIR="${LEAN_ROOT:-.}"
SRC="Proofs/RotBandPerLane.lean"
OLEAN="${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotBandPerLane.olean"
BAK="$SRC.mutbak"
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutbandperlane.XXXXXX")"

[ -f "$SRC" ] || {
  echo "FATAL: $SRC not found. Refusing to run: every mutant would fail to build"
  echo "and be scored KILLED without a line having been mutated."
  exit 2
}

# --- NO-DOWNLOAD GUARD ------------------------------------------------------
# Run from a clean clone, `lake build` would resolve mathlib and pull ~7.2 GB
# into the repo. A suite that silently starts a multi-gigabyte download is worse
# than one that refuses, so this is a SKIP (exit 3) and never a pass.
if [ ! -d "$_WSDIR/.lake/packages" ] || [ ! -f "$OLEAN" ]; then
  echo "SKIP: $_WSDIR is not a BUILT Lean workspace (.lake/packages or $OLEAN absent)."
  echo "      Refusing to invoke lake: resolving mathlib would DOWNLOAD ~7.2 GB."
  echo "      Set LEAN_ROOT to an already-built workspace to run this suite."
  echo "      This is a SKIP (exit 3), never a pass."
  exit 3
fi

# --- PREFLIGHT: a kill measured against a red baseline is unattributable -----
if ! ( cd "$_WSDIR" && lake build Proofs.RotBandPerLane ) >/tmp/mut_pre_rotbandperlane.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotBandPerLane)."
  echo "Every mutant would be scored KILLED by a failure that was already there."
  tail -5 /tmp/mut_pre_rotbandperlane.log
  exit 2
fi
echo "preflight: baseline builds GREEN, $SRC present -- kills are attributable"

# --- SOURCE SANITY: AN EMPTY LEAN FILE BUILDS GREEN -------------------------
# So "the baseline compiles" is weaker than it looks, and a truncated source
# would be copied over the backup and score the whole suite as DISCARDED.
_lines=$(wc -l < "$SRC" 2>/dev/null || echo 0)
_thms=$(grep -c "^theorem " "$SRC" 2>/dev/null || echo 0)
if [ "${_lines:-0}" -lt 20 ] || [ "${_thms:-0}" -lt 1 ]; then
  echo "FATAL: $SRC looks DAMAGED ($_lines lines, $_thms theorem lines)."
  echo "Refusing to overwrite the backup with it."
  exit 2
fi

cp "$SRC" "$BAK" || exit 2
restore () { cp "$BAK" "$SRC"; rm -f "$OLEAN"; }
trap 'restore; rm -f "$BAK"; ( cd "$_WSDIR" && lake build Proofs.RotBandPerLane ) >/dev/null 2>&1' EXIT

killed=0; survived=0; discarded=0

mutant () { # name, sed-expr, needle-that-must-appear
  cp "$BAK" "$SRC"
  sed -i "$2" "$SRC"
  # THREE INDEPENDENT WAYS THIS CAN LIE, ALL CHECKED BEFORE THE BUILD RUNS.
  #
  # (a) EMPTY. A sed that truncates leaves a file that is not the module any
  #     more; whatever the build then says is about nothing.
  if [ ! -s "$SRC" ]; then
    printf '  DISCARDED  %-38s (mutation EMPTIED the file -- NOT a survival)\n' "$1"
    discarded=$((discarded+1)); return
  fi
  # (b) UNCHANGED. This is the one that silently manufactures reassurance: the
  #     patch misses, the file is identical, the build is green because nothing
  #     was touched, and a naive harness records SURVIVED. `cmp` against the
  #     backup is stronger than any needle -- it cannot be fooled by a needle
  #     that happened to be there already.
  if cmp -s "$SRC" "$BAK"; then
    printf '  DISCARDED  %-38s (file UNCHANGED -- patch did not apply)\n' "$1"
    discarded=$((discarded+1)); return
  fi
  # (c) WRONG CHANGE. The file differs, but not in the way intended.
  n=$(grep -c -- "$3" "$SRC")
  if [ "$n" -eq 0 ]; then
    printf '  DISCARDED  %-38s (changed, but the needle is absent)\n' "$1"
    discarded=$((discarded+1)); return
  fi
  rm -f "$OLEAN"
  ( cd "$_WSDIR" && lake build Proofs.RotBandPerLane ) >"$LOG/$1.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '  SURVIVED   %-38s <-- the theorems did not notice\n' "$1"
    survived=$((survived+1))
    return
  fi
  # NO LOG, NO FINDING. A non-zero exit whose build produced NO log cannot be
  # attributed to anything -- lake may never have started (unwritable log dir,
  # missing toolchain, a typo in this harness). Scoring that as KILLED is how
  # twelve fake kills were once published in this repo. It is DISCARDED.
  if [ ! -s "$LOG/$1.log" ]; then
    printf '  DISCARDED  %-38s (build produced NO log -- unattributable)\n' "$1"
    discarded=$((discarded+1)); return
  fi
  # ANCHORED ATTRIBUTION. A non-zero exit is not yet a kill: the build could
  # have failed for a reason that has nothing to do with the mutation -- a
  # broken dependency, a missing package, a typo this harness introduced
  # elsewhere. Scoring that as KILLED credits the theorem with catching
  # something it never saw, which is the reassuring direction to be wrong in.
  # A kill counts only when the error is reported AGAINST THIS MODULE.
  if grep -qE "^error: Proofs/RotBandPerLane.lean:[0-9]+" "$LOG/$1.log"; then
    printf '  killed     %-38s (%s)\n' "$1" \
      "$(grep -oE '^error: Proofs/RotBandPerLane.lean:[0-9]+' "$LOG/$1.log" | head -1 | sed 's|^error: Proofs/RotBandPerLane.lean:|line |')"
    killed=$((killed+1))
  else
    printf '  DISCARDED  %-38s (build failed, but NOT in this module -- unattributable)\n' "$1"
    discarded=$((discarded+1))
  fi
}

echo "== mutating RotBandPerLane =="

# The band table itself. Every one of these is a plausible typo.
mutant "CREATIVE lo 150 -> 90"      's/| .creative   => (150, 350)/| .creative   => ( 90, 350)/'  '( 90, 350)'
mutant "STEALTH hi 120 -> 180"      's/| .stealth    => ( 50, 120)/| .stealth    => ( 50, 180)/'  '( 50, 180)'
mutant "CLINICAL lo 80 -> 90"       's/| .clinical   => ( 80, 150)/| .clinical   => ( 90, 150)/'  '( 90, 150)'
mutant "EMPATHIC hi 250 -> 180"     's/| .empathic   => (120, 250)/| .empathic   => (120, 180)/'  '(120, 180)'
mutant "STRATEGIC copies FORGE"     's/| .strategic  => (100, 200)/| .strategic  => ( 90, 180)/'  '| .strategic  => ( 90, 180)'

# The classifier. Endpoint handling is exactly where an off-by-one lives.
mutant "classify < becomes <="      's/if r < (band l).1/if r <= (band l).1/'                     'if r <= (band l).1'
mutant "classify > becomes >="      's/if r > (band l).2/if r >= (band l).2/'                     'if r >= (band l).2'
mutant "classify reads hi for lo"   's/if r < (band l).1/if r < (band l).2/'                      'if r < (band l).2'

# The lane list. Dropping a lane must not leave the exhaustive proofs green.
mutant "allLanes drops .stealth"    's/\.recursive, \.forge\]/.recursive, .forge]/; s/\.predictive, \.stealth,/.predictive,/' '.predictive,'

# The global band -- if this can be changed freely, the comparison proves nothing.
mutant "forgeBand widened to 0-999" 's/def forgeBand : Nat × Nat := (90, 180)/def forgeBand : Nat × Nat := (0, 999)/' '(0, 999)'

restore
if ( cd "$_WSDIR" && lake build Proofs.RotBandPerLane ) >/dev/null 2>&1; then base="GREEN"; else base="RED"; fi
printf '\n== rotbandperlane: %d killed, %d survived, %d discarded | baseline restored: %s\n' \
  "$killed" "$survived" "$discarded" "$base"
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && [ "$base" = "GREEN" ]
