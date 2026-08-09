#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# ---------------------------------------------------------------------------
# EVERY `import` MUST MATCH THE FILE ON DISK **EXACTLY**, INCLUDING CASE.
#
# WHY THIS GATE EXISTS. Measured 2026-08-09 in the shared proof tree: the
# directory is `Proofs/RotMoe/` (lowercase e) while 45 modules referenced
# `Proofs.RotMoE.` (uppercase E). Windows resolves paths case-INSENSITIVELY, so
#
#     lake build Proofs.RotMoE.RotCeiling        -> exit 0, olean written
#     lake env leanchecker Proofs.RotMoE.RotCeiling
#         -> uncaught exception: Could not find any oleans
#
# Both true at once. The compiler could not see the error and the kernel could
# not see the proof, so the STRONGEST instrument in the delivery ritual was
# silently unavailable for every delivered module, for weeks, while the build
# stayed green. The same tree would simply fail to build on a Linux CI runner.
#
# A case-insensitive filesystem cannot report this class of defect. Only an
# explicit exact-match comparison can, which is what this gate is.
#
# THE INSTRUMENT MUST BE ABLE TO FAIL. Two positive controls run before any
# clean report: the exact matcher must REJECT a planted wrong-case name, and
# the case-insensitive detector must still SEE it -- otherwise a mismatch would
# be misreported as "module does not exist", which sends the next reader
# looking for the wrong bug. That is exactly the wrong turn taken on 2026-08-09,
# when the failure was blamed on a missing aggregator file.
#
# Proven in lean/Proofs/RotCaseFold.lean:
#   a_green_build_does_not_imply_the_kernel_can_find_it
#   same_tree_is_red_on_a_case_sensitive_host
#   canonical_names_resolve_on_every_host      <- the repair this gate enforces
# ---------------------------------------------------------------------------

set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
LEANDIR="$ROOT/lean"
TMP="${TMPDIR:-/tmp}/rotmoe-modcase.$$"
mkdir -p "$TMP" || { echo "FATAL: cannot create $TMP"; exit 2; }
trap 'rm -rf "$TMP"' EXIT

passed=0; failed=0
ok()  { echo "  ok   $1"; passed=$((passed+1)); }
bad() { echo "  FAIL $1"; failed=$((failed+1)); }

if [ ! -d "$LEANDIR" ]; then
  echo "SKIP: $LEANDIR not present. This is a SKIP (exit 3), never a pass."
  exit 3
fi

# --- the modules that ACTUALLY exist, with their real on-disk case -----------
# `find` reports the name the filesystem stores, which is the whole point: a
# `[ -f path ]` test on Windows would answer yes for the wrong case and this
# gate would certify the defect it was written to catch.
( cd "$LEANDIR" && find . -name '*.lean' -type f ) \
  | sed 's|^\./||; s|\.lean$||; s|/|.|g' | sort -u > "$TMP/modules.txt"

_n=$(wc -l < "$TMP/modules.txt" | tr -d ' ')
if [ "${_n:-0}" -lt 10 ]; then
  echo "FATAL: only ${_n:-0} module(s) discovered under $LEANDIR."
  echo "A clean report over an empty walk is vacuous, not a pass."
  exit 2
fi

# --- POSITIVE CONTROLS, before anything is certified -------------------------
printf 'Proofs.ZzControl\n' > "$TMP/ctl.txt"
if grep -qxF 'Proofs.Zzcontrol' "$TMP/ctl.txt"; then
  bad "positive control: the EXACT matcher accepted a wrong-case name -- this gate is blind to the defect it exists for"
else
  ok "positive control: exact matcher rejects 'Proofs.Zzcontrol' against on-disk 'Proofs.ZzControl'"
fi
if grep -qixF 'Proofs.Zzcontrol' "$TMP/ctl.txt"; then
  ok "positive control: the case-insensitive detector still sees the near-miss, so a mismatch is reported AS a mismatch"
else
  bad "positive control: the case-insensitive detector is blind -- a case mismatch would be misreported as a missing module"
fi

# --- every import, checked exactly -------------------------------------------
grep -rn '^import Proofs' "$LEANDIR" --include='*.lean' > "$TMP/imports.txt" 2>/dev/null || true
_imports=$(wc -l < "$TMP/imports.txt" | tr -d ' ')

_viol=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  mod=$(printf '%s' "$line" | sed 's/^.*:import  *//; s/[[:space:]]*$//')
  loc=$(printf '%s' "$line" | sed 's/:import .*$//')
  if grep -qxF "$mod" "$TMP/modules.txt"; then
    continue
  fi
  _viol=$((_viol+1))
  real=$(grep -ixF "$mod" "$TMP/modules.txt" | head -1)
  if [ -n "$real" ]; then
    bad "$loc imports '$mod' but the file on disk is '$real' -- differs ONLY in case."
    echo "       Windows builds this anyway; leanchecker, git and Linux CI cannot resolve it."
  else
    bad "$loc imports '$mod', which does not exist under $LEANDIR at all."
  fi
done < "$TMP/imports.txt"

if [ "$_viol" -eq 0 ]; then
  ok "all $_imports 'import Proofs...' line(s) match a file on disk with EXACT case"
fi

# --- two files differing only by case are ambiguous on a folding filesystem ---
tr 'A-Z' 'a-z' < "$TMP/modules.txt" | sort | uniq -d > "$TMP/dups.txt"
if [ -s "$TMP/dups.txt" ]; then
  while IFS= read -r d; do
    bad "two modules differ only by case ('$d') -- on a case-insensitive filesystem one silently shadows the other"
  done < "$TMP/dups.txt"
else
  ok "no two modules differ only by case ($_n module(s) checked)"
fi

echo "lean-module-case: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
exit 0
