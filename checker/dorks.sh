#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# DORKS -- ROTATE THE PUBLISHED TAG ORDER WITHOUT EVER CHANGING THE TAG SET.
#
# The signature block in README.md is regenerated from `.github/tags.txt`
# [SIGNATURE] on every tag-manager run. Regenerating identical bytes changes
# nothing, so the page never looks refreshed. Rotating the ORDER makes the
# rendered block differ from day to day while the SET of tags is bit-for-bit
# the one in tags.txt.
#
# WHY ARITHMETIC AND NOT `shuf`:
#
#   1. A random shuffle is not reproducible. Nobody could re-derive what was
#      published on a given day, so a drift check could not tell a legitimate
#      rotation from a corrupted block.
#   2. `shuf -n` or a shuffle with a bug can DROP or DUPLICATE entries. Losing
#      a tag silently is exactly the failure this repository refuses: the
#      README would advertise 41 tags and no gate would notice, because nothing
#      would be obviously broken.
#
# The permutation used here is  i -> (i * stride + offset) mod n  with
# gcd(stride, n) = 1. Under that condition the map is a BIJECTION on
# {0..n-1}, so the output is a permutation of the input by construction --
# no tag can be lost, none duplicated, whatever the seed. That is a property
# of modular arithmetic, not of this implementation being careful.
#
# The seed is the calendar day (UTC). Same day -> same block anywhere it is
# regenerated; next day -> a different order. Reproducible AND fresh, which
# `shuf` cannot be at the same time.
#
# THE SET IS THE INVARIANT, THE ORDER IS THE VARIABLE. checker/tags-consistency.sh
# already compares the rendered block against tags.txt AS A SET, so it keeps
# passing across rotations and would still catch a real drift. This checker
# guards the other half: that the rotation is a permutation, is deterministic,
# and actually moves.
#
# Usage:
#   dorks.sh --order [seed]   print the rotated tag list, one per line
#   dorks.sh --seed           print the seed this machine would use today
#   dorks.sh --selftest       run the controls (default)
#
# Exit: 0 pass · 1 a property failed · 2 refuse (missing input)
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

TAGSFILE=".github/tags.txt"
PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }

[ -f "$TAGSFILE" ] || { echo "REFUSE: $TAGSFILE missing"; exit 2; }

# --- the source of truth, exactly as tag-manager.yml reads it ----------------
# Same awk section extractor, same comment/blank stripping. If these two ever
# disagree the rotation would publish a different set than the validator checked.
section () {
  awk -v s="[$1]" '$0==s{f=1;next} /^\[/{f=0} f' "$TAGSFILE" | grep -vE '^[[:space:]]*(#|$)'
}

# --- the seed ----------------------------------------------------------------
# Days since epoch, UTC. An integer that advances exactly once per day.
# ROT_DORK_SEED overrides it, which is what makes the controls below able to
# ask for a specific rotation instead of waiting for tomorrow.
today_seed () {
  if [ -n "${ROT_DORK_SEED:-}" ]; then printf '%s' "$ROT_DORK_SEED"; return; fi
  local d
  d=$(date -u +%s 2>/dev/null) || d=0
  printf '%s' "$(( d / 86400 ))"
}

gcd () { local a=$1 b=$2 t; while [ "$b" -ne 0 ]; do t=$b; b=$(( a % b )); a=$t; done; printf '%s' "$a"; }

# --- the permutation ---------------------------------------------------------
# stride: the first integer at or above a seed-derived start that is coprime
# with n. Coprimality is CHECKED, not assumed -- a stride sharing a factor with
# n would collapse the map onto a subset and silently drop tags. n is 42 today
# (= 2*3*7), and hard-coding a stride that happens to be coprime with 42 would
# be a spec frozen to a contingent fact: add a tag, n becomes 43, and the
# hard-coded value could be wrong. It is computed from n instead.
rotate () {
  local seed="$1"; shift
  local n=$#
  [ "$n" -le 1 ] && { printf '%s\n' "$@"; return; }
  local start=$(( (seed % (n - 1)) + 1 ))
  local stride=$start
  local tries=0
  while [ "$(gcd "$stride" "$n")" -ne 1 ]; do
    stride=$(( (stride % (n - 1)) + 1 ))
    tries=$(( tries + 1 ))
    # n >= 2 always has 1 as a coprime, so this terminates; the bound only
    # stops an infinite loop if the arithmetic above is ever changed wrongly.
    [ "$tries" -gt "$n" ] && { stride=1; break; }
  done
  local offset=$(( seed % n ))
  local i j
  for i in $(seq 0 $(( n - 1 ))); do
    j=$(( (i * stride + offset) % n ))
    eval "printf '%s\n' \"\${$(( j + 1 ))}\""
  done
}

emit_order () {
  local seed="${1:-$(today_seed)}"
  local tags=()
  while IFS= read -r line; do [ -n "$line" ] && tags+=("$line"); done < <(section SIGNATURE)
  [ "${#tags[@]}" -eq 0 ] && { echo "REFUSE: [SIGNATURE] is empty in $TAGSFILE" >&2; exit 2; }
  rotate "$seed" "${tags[@]}"
}

case "${1:---selftest}" in
  --order) emit_order "${2:-}" ; exit 0 ;;
  --seed)  today_seed; echo   ; exit 0 ;;
  --selftest) : ;;
  *) echo "REFUSE: unknown argument '$1'"; exit 2 ;;
esac

# =============================================================================
# CONTROLS. Each one can fail, and says what a failure would mean.
# =============================================================================
echo "== dorks: the rotation must permute, never edit, the tag set =="

BASE=$(section SIGNATURE | sort)
NBASE=$(printf '%s\n' "$BASE" | grep -c . || true)
[ "$NBASE" -gt 0 ] \
  && ok "[SIGNATURE] read from $TAGSFILE: $NBASE tag(s)" \
  || bad "no signature tags found -- every check below would be vacuous"

# (1) THE SET IS INVARIANT, over many seeds. This is the property that makes
#     rotation safe to publish. One seed proves nothing: a permutation bug
#     usually shows up only for particular strides.
setfail=0; checked=0
for s in 0 1 2 3 7 13 41 42 43 100 365 999 20260802; do
  got=$(emit_order "$s" | sort)
  checked=$((checked+1))
  [ "$got" = "$BASE" ] || { setfail=$((setfail+1)); echo "        seed $s changed the set"; }
done
[ "$setfail" -eq 0 ] \
  && ok "the tag SET is identical under all $checked seeds tested -- nothing added, dropped or duplicated" \
  || bad "$setfail seed(s) changed the tag set -- the map is not a bijection and tags would vanish from the README"

# (2) THE COUNT IS INVARIANT. Stated separately from the set because a
#     duplicate plus a loss can leave `sort -u` looking right.
cntfail=0
for s in 0 5 41 42 4242; do
  n=$(emit_order "$s" | grep -c . || true)
  [ "$n" -eq "$NBASE" ] || { cntfail=$((cntfail+1)); echo "        seed $s emitted $n, expected $NBASE"; }
done
[ "$cntfail" -eq 0 ] \
  && ok "the tag COUNT is $NBASE under every seed tested -- no silent duplicate-and-drop" \
  || bad "$cntfail seed(s) emitted the wrong number of tags"

# (3) DETERMINISM. Same seed must give byte-identical output, or no drift check
#     could ever distinguish a legitimate rotation from corruption.
a=$(emit_order 12345); b=$(emit_order 12345)
[ "$a" = "$b" ] \
  && ok "the same seed reproduces the same order exactly -- the block is re-derivable" \
  || bad "the same seed produced two different orders -- the rotation is not reproducible"

# (4) IT ACTUALLY ROTATES. A permutation that always returns the input is a
#     correct permutation and a useless rotation: the README would never change
#     and this whole mechanism would be decoration that passes every test.
moved=0; pairs=0
prev=""
for s in 1 2 3 4 5 6 7 8; do
  cur=$(emit_order "$s")
  if [ -n "$prev" ]; then
    pairs=$((pairs+1))
    [ "$cur" != "$prev" ] && moved=$((moved+1))
  fi
  prev="$cur"
done
[ "$moved" -eq "$pairs" ] \
  && ok "consecutive seeds all produce a DIFFERENT order ($moved/$pairs) -- the rotation is not a no-op" \
  || bad "only $moved of $pairs consecutive seeds changed the order -- the block would look static"

# (5) THE IDENTITY IS NOT WHAT IT PUBLISHES. Distinct from (4): every day could
#     differ from the day before while one of them is still the untouched file
#     order. Not fatal, but if EVERY seed returned file order the rotation is dead.
same_as_file=0
FILEORDER=$(section SIGNATURE)
for s in 1 2 3 4 5 6 7 8 9 10; do
  [ "$(emit_order "$s")" = "$FILEORDER" ] && same_as_file=$((same_as_file+1))
done
[ "$same_as_file" -lt 10 ] \
  && ok "the published order differs from the raw file order for at least one seed ($same_as_file/10 identical)" \
  || bad "every seed returned the file order unchanged -- rotation is a no-op"

# (6) NEGATIVE CONTROL: the checks above must be ABLE to fail. A stride sharing
#     a factor with n collapses the map onto a subset. Proving the harness
#     detects that is the only reason its greens count.
n_bad=6   # shares 2 and 3 with 42
declare -a probe=()
while IFS= read -r line; do [ -n "$line" ] && probe+=("$line"); done < <(section SIGNATURE)
np=${#probe[@]}
if [ "$np" -gt 2 ] && [ "$(gcd "$n_bad" "$np")" -ne 1 ]; then
  broken=$(for i in $(seq 0 $(( np - 1 ))); do
             j=$(( (i * n_bad) % np ))
             printf '%s\n' "${probe[$j]}"
           done | sort -u | grep -c . || true)
  [ "$broken" -lt "$np" ] \
    && ok "CONTROL: a NON-coprime stride collapses $np tags to $broken distinct -- the set check has something to catch" \
    || bad "CONTROL DEAD: a non-coprime stride lost nothing, so the set check proves nothing"
else
  bad "CONTROL SKIPPED: could not construct a non-coprime stride for n=$np -- SKIP IS NOT A PASS"
fi

# (7) ARCHIVAL COPIES MUST NOT ROTATE. This binds the spec to the workflow that
#     implements it. CITATION.cff is ingested by Zenodo and OpenAIRE and is what
#     people cite; rotating its keyword order churns it daily for zero discovery
#     benefit, because nothing renders that list to a reader. Measured: feeding
#     the rotated array there turned the drift gate red on 3951c2a.
#
#     The README block is the opposite case and must NOT be pinned to file
#     order, or the rotation this whole file exists for would be dead. Both
#     directions are asserted, so neither can be flipped without a failure.
WF=".github/workflows/tag-manager.yml"
if [ ! -f "$WF" ]; then
  bad "$WF is missing -- the rotation has no consumer and this checker guards nothing"
else
  cit_line=$(grep -n 'for t in .*; do echo "  - ' "$WF" | head -1)
  case "$cit_line" in
    *'TAGS_FILE[@]'*) ok "CONTROL: CITATION.cff keywords are emitted from the FILE order, not the rotation" ;;
    "")               bad "could not find the CITATION.cff keyword loop in $WF -- this check went vacuous" ;;
    *)                bad "the CITATION.cff keyword loop does not use TAGS_FILE -- archival metadata would rotate daily: $(printf '%s' "$cit_line" | cut -c1-90)" ;;
  esac
  rdm=$(grep -c 'printf .`#%s` .*"\${TAGS\[@\]}"\|for t in "\${TAGS\[@\]}"' "$WF" || true)
  [ "$rdm" -ge 1 ] \
    && ok "the README/release block still renders from the ROTATED array -- the rotation is reaching a real surface" \
    || bad "no rendered surface uses the rotated array -- the rotation would be dead code"
fi

printf '\n== dorks: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { echo "  dorks: PASS"; exit 0; } || { echo "  dorks: FAIL"; exit 1; }
