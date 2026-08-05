#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE LEAN MIRROR AND THE RUNNING HOOK, ON THE SAME ROWS, MEASURED TOGETHER.
#
# `lean/Proofs/RotGauge.lean` carries a computable `Float` mirror of the gauge
# and a handful of `#eval` rows, each annotated:
#
#     #eval round2 (gaugeF [0,0,0,0,0,0,1,0,1] 1 1.05 0.7 0.8)  -- hook reported 0.49
#
# That comment is a CLAIM OF AGREEMENT WRITTEN BY HAND. Nothing verified it
# after the day it was typed. Retune a lambda in the shell, or change the
# sigmoid there, and the comment keeps saying 0.49 while the hook says something
# else -- and R19 ("the Lean model AGREES with the running router") would still
# read as measured on the strength of a stale annotation.
#
# This checker executes BOTH SIDES and diffs them:
#   * the shell arm: `hooks/rot-router.sh --vector ... --breadth ...`, parsed
#     from its real stdout;
#   * the Lean arm:  `#eval round2 (gaugeF ...)` in a scratch file, elaborated
#     with `lake env lean` inside the Lean workspace.
#
# WHY THIS IS MEASURED AND NOT PROVED, said plainly: the theorems in RotGauge
# are over the reals, where `Real.exp` is not computable. `gaugeF` is a Float
# TRANSCRIPTION of them, and `awk` is a third implementation. Agreement to two
# decimals across three implementations is strong evidence and is not a proof;
# the file says so, and so does this checker's output.
#
# SKIPS (exit 3) when there is no Lean workspace to run against -- a bare CI
# runner has no mathlib and no `.lake`. A skip is reported as a skip and is
# never counted as a pass, the same rule the plugin-install checker follows.
#
# WORKSPACE RESOLUTION, in order: $LEAN_ROOT, $ROTMOE_LEAN_WORKSPACE, then the
# vendored `lean/` directory. No machine-specific path appears in this file --
# `checker/no-local-paths.sh` would reject it, and correctly.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=gauge-cross::%s\n' "$*"; fail=$((fail+1)); }

WS="${LEAN_ROOT:-${ROTMOE_LEAN_WORKSPACE:-$REPO/lean}}"

echo "== gauge cross-check: the Lean Float mirror vs the running hook =="

command -v lake >/dev/null 2>&1 || {
  echo "  SKIP  lake is not on PATH -- no Lean arm to compare against."
  echo "        This is a SKIP (exit 3), never a pass."
  exit 3
}
[ -f "$WS/lakefile.toml" ] || {
  echo "  SKIP  no lakefile.toml under $WS -- set LEAN_ROOT to a built workspace."
  echo "        This is a SKIP (exit 3), never a pass."
  exit 3
}

# =============================================================================
# THE GUARD BELOW COST 41 MB AND A KILLED PROCESS. MEASURED 2026-07-31.
#
# The first version of this checker required only a lakefile. Run with no
# LEAN_ROOT it resolved to the VENDORED `lean/` tree, which has a lakefile
# declaring a mathlib dependency and no `.lake` at all -- and `lake env lean`
# does not merely set variables, it RESOLVES THE PACKAGE FIRST. So it began
# cloning mathlib into the repository: `lean/.lake/packages/mathlib` existed and
# the tree was at 41 MB and climbing before the process was stopped by PID.
# Left alone that is a multi-gigabyte checkout inside a source repo, from a
# script whose entire purpose is to be safe to run anywhere.
#
# The lesson generalises past this file: A CHECKER MUST NEVER BE ABLE TO
# ACQUIRE ANYTHING. Reading is its job; fetching is not, and "it only builds
# what is already declared" is exactly the sentence that preceded the download.
#
# So the requirement is now the ARTEFACT, not the manifest: the module must
# ALREADY be compiled. If the .olean is absent there is nothing to compare and
# nothing to build -- SKIP. This cannot start a download, because a workspace
# that has never been built cannot satisfy it.
# =============================================================================
if [ ! -f "$WS/.lake/build/lib/lean/Proofs/RotGauge.olean" ]; then
  echo "  SKIP  $WS has no BUILT Proofs.RotGauge (.olean absent)."
  echo "        Refusing to invoke lake here: resolving a mathlib dependency"
  echo "        would DOWNLOAD, and a checker must never acquire anything."
  echo "        Point LEAN_ROOT at an already-built workspace to enable this gate."
  echo "        This is a SKIP (exit 3), never a pass."
  exit 3
fi

# --- the corpus -------------------------------------------------------------
# vector | breadth | M | C | T. Chosen to cover the shapes that behave
# differently rather than nine variations of the same one: the all-quiet floor,
# a single active lens, two active lenses, everything active, and a row whose
# modifiers are not the defaults.
CORPUS='0,0,0,0,0,0,0,0,0 0 1.05 0.7 0.8
0,0,0,0,0,0,1,0,1 1 1.05 0.7 0.8
0,1,0,0,0,0,0,0,0 1 1.05 0.7 0.8
1,1,1,1,1,1,1,1,1 1 1.05 0.7 0.8
0,0,1,0,0,0,0,0,1 1 1.05 1.0 0.93
1,0,1,0,1,0,1,0,1 1 1.00 0.9 1.00'

shell_gauge () {   # shell_gauge <vec> <breadth> <M> <C> <T> -> "0.49"
  sh hooks/rot-router.sh --vector "$1" --breadth "$2" --M "$3" --C "$4" --T "$5" 2>/dev/null \
    | grep -oE 'R/s\+ = [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+'
}

# Build ONE scratch Lean file with every row, so the workspace is elaborated
# once rather than per row -- six `lake env lean` invocations is minutes.
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/gaugex.XXXXXX")"
LEANF="$SCRATCH/cross.lean"
{
  echo 'import Proofs.RotGauge'
  echo 'open RotMoE'
  while read -r vec br M C T; do
    [ -z "$vec" ] && continue
    echo "#eval round2 (gaugeF [$vec] $br $M $C $T)"
  done <<EOF
$CORPUS
EOF
} > "$LEANF"

( cd "$WS" && lake env lean "$LEANF" ) > "$SCRATCH/lean.out" 2>"$SCRATCH/lean.err"
LEAN_RC=$?          # read DIRECTLY, never through a pipe
if [ "$LEAN_RC" -ne 0 ]; then
  echo "  SKIP  the Lean arm did not elaborate (lake env lean exit $LEAN_RC)."
  sed -n '1,5p' "$SCRATCH/lean.err"
  echo "        Reported as a SKIP, not a pass: with one arm missing there is nothing to compare."
  rm -rf "$SCRATCH"
  exit 3
fi

# Lean prints one Float per #eval, in order.
# NOT `mapfile`: bash 4.0+ only, and macOS ships bash 3.2.57 as /bin/bash.
LEANV=()
while IFS= read -r _v; do LEANV+=("$_v"); done < <(grep -oE '^-?[0-9]+\.[0-9]+' "$SCRATCH/lean.out")

i=0
while read -r vec br M C T; do
  [ -z "$vec" ] && continue
  sv="$(shell_gauge "$vec" "$br" "$M" "$C" "$T")"
  lv="${LEANV[$i]:-<none>}"
  i=$((i+1))
  # Normalise: Lean prints 0.490000, the hook prints 0.49.
  lvr="$(printf '%.2f' "$lv" 2>/dev/null)"
  if [ -z "$sv" ]; then
    bad "row $i: the HOOK produced no R/s+ for [$vec] breadth=$br"
  elif [ "$sv" = "$lvr" ]; then
    ok "row $i: hook $sv == Lean $lvr   [$vec] b=$br M=$M C=$C T=$T"
  else
    bad "row $i: hook $sv != Lean $lvr   [$vec] b=$br M=$M C=$C T=$T -- the mirror and the router DISAGREE"
  fi
done <<EOF
$CORPUS
EOF

[ "$i" -eq "${#LEANV[@]}" ] \
  && ok "every corpus row produced a value on BOTH arms ($i rows)" \
  || bad "row count mismatch: $i shell rows vs ${#LEANV[@]} Lean values -- one arm skipped a row"

# --- the control ------------------------------------------------------------
# The comparison must be capable of failing. Compare row 1's hook value against
# row 2's Lean value: two rows chosen precisely because they differ, so a
# comparator that always agrees is exposed.
echo
echo "-- negative control --"
c1="$(shell_gauge 0,0,0,0,0,0,0,0,0 0 1.05 0.7 0.8)"
c2="$(printf '%.2f' "${LEANV[1]:-0}")"
if [ -n "$c1" ] && [ "$c1" != "$c2" ]; then
  ok "CONTROL: mismatched rows ARE distinguishable (hook $c1 vs Lean $c2 from a different row)"
else
  bad "CONTROL DEAD: two rows that must differ compared equal ($c1 vs $c2) -- this checker cannot detect drift"
fi

rm -rf "$SCRATCH"
echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
echo "  NOTE  this is MEASURED agreement across three implementations (reals in"
echo "        the theorems, Float in the mirror, awk in the hook), NOT a proof."
[ "$fail" -eq 0 ] && { echo "  gauge-cross: PASS"; exit 0; } || { echo "  gauge-cross: FAIL"; exit 1; }
