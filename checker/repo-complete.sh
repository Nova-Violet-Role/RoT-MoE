#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# REPO COMPLETENESS -- required files, and NUMBERS THAT MUST STILL BE TRUE.
#
# Two jobs, and the second is the one that matters:
#
#   1. Required files exist. Cheap, and it stops a shipped packet from silently
#      losing its licence texts or its community files.
#
#   2. EVERY COUNT IN THE PROSE IS RECOUNTED FROM SOURCE. A README saying "63
#      theorems" after a module was added is not a typo -- it is the project
#      lying about the one thing it sells. The count in prose is a CLAIM; the
#      count from `grep` over `lean/Proofs/*.lean` is a MEASUREMENT. When they
#      disagree, the prose is wrong.
#
# This checker was written after the author's own stale-memory error: a "next
# steps" list named three community files as missing that had been committed
# hours earlier. Stating from memory what can be measured is exactly the habit
# every other instrument in this repo exists to break, and prose drifts the same
# way code does.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }

echo "== repo completeness =="

# --- 1. required files ------------------------------------------------------
REQUIRED="
README.md
NOTICE.md
LICENSE
LICENSE-EUPL-1.2
LICENSES/AGPL-3.0-or-later.txt
LICENSES/EUPL-1.2.txt
SECURITY.md
CONTRIBUTING.md
CODE_OF_CONDUCT.md
CITATION.cff
.gitignore
.claude-plugin/plugin.json
hooks/hooks.json
hooks/rot-router.sh
hooks/rot-router.ps1
hooks/settings-merge.js
ARM_ROUTER.sh
ARM_ROUTER.ps1
DISARM_ROUTER.sh
DISARM_ROUTER.ps1
lean/lakefile.toml
lean/lean-toolchain
"
for f in $REQUIRED; do
  [ -f "$f" ] && ok "present: $f" || bad "MISSING: $f"
done

# --- 2. the counts ----------------------------------------------------------
echo
echo "-- counts recounted from source, never trusted from prose --"

TH=$(grep -hcE '^(@\[[^]]*\] )?(private |protected |noncomputable )*(theorem|lemma) ' \
       lean/Proofs/*.lean | awk '{s+=$1} END{print s+0}')
MODS=$(ls lean/Proofs/*.lean 2>/dev/null | wc -l | tr -d ' ')
SUITES=$(ls lean/mutate/mutate_*.sh 2>/dev/null | wc -l | tr -d ' ')
echo "  measured: $TH theorems, $MODS modules, $SUITES mutation suites"

# Every "<n> theorems" / "<n> machine-checked" claim in the prose must equal TH.
claims=0; wrong=0
for f in README.md NOTICE.md CITATION.cff; do
  [ -f "$f" ] || continue
  while read -r n; do
    claims=$((claims+1))
    if [ "$n" != "$TH" ]; then
      bad "$f claims $n theorems; source has $TH"
      wrong=$((wrong+1))
    fi
  done < <(grep -oE '[0-9]+ machine-checked( Lean 4)? theorems?' "$f" | grep -oE '^[0-9]+')
done
[ "$claims" -eq 0 ] && bad "no theorem-count claim found in the prose -- the check is vacuous"
[ "$claims" -gt 0 ] && [ "$wrong" -eq 0 ] && ok "all $claims theorem-count claim(s) match source ($TH)"

# Per-module counts in the README bullets, e.g. "(34 theorems)".
if [ -f README.md ]; then
  permod=0; permod_wrong=0
  for m in lean/Proofs/*.lean; do
    base="$(basename "$m" .lean)"
    real=$(grep -cE '^(@\[[^]]*\] )?(private |protected |noncomputable )*(theorem|lemma) ' "$m")
    claimed=$(grep -oE "$base\.lean\*\*\` \(([0-9]+) theorems\)" README.md | grep -oE '\([0-9]+' | tr -d '(')
    [ -z "$claimed" ] && claimed=$(grep -A1 "$base.lean" README.md | grep -oE '\(([0-9]+) theorems\)' | grep -oE '[0-9]+' | head -1)
    if [ -n "$claimed" ]; then
      permod=$((permod+1))
      [ "$claimed" != "$real" ] && { bad "README says $base has $claimed theorems; source has $real"; permod_wrong=$((permod_wrong+1)); }
    fi
  done
  [ "$permod" -gt 0 ] && [ "$permod_wrong" -eq 0 ] && ok "all $permod per-module count(s) match source"
fi

# --- 3. the control ---------------------------------------------------------
# An instrument that has never been seen to fail proves nothing.
echo
echo "-- negative control --"
CTL="$(mktemp -d "${TMPDIR:-/tmp}/repocomp.XXXXXX")"
printf 'This project has 99999 machine-checked theorems.\n' > "$CTL/fake.md"
planted=$(grep -oE '[0-9]+ machine-checked( Lean 4)? theorems?' "$CTL/fake.md" | grep -oE '^[0-9]+')
if [ "$planted" = "99999" ] && [ "$planted" != "$TH" ]; then
  ok "CONTROL: a planted false count (99999) is extracted and would be rejected"
else
  bad "CONTROL DEAD: the extractor did not see the planted count"
fi
rm -rf "$CTL"

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  repo-complete: PASS"; exit 0; } || { echo "  repo-complete: FAIL"; exit 1; }
