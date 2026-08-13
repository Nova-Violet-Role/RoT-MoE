#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE BINDING: the Lean witness must carry the SAME weights the shell ships.
#
# lean/Proofs/RotGauge.lean:432 defines `forge`, the nine-lens table the gauge
# theorems are instantiated at -- the SHIPPING numbers, not toy values, so the
# proofs demonstrably apply to the configuration in production.
#
# IT MUST BE THE REAL TABLE. This checker originally read a SECOND copy of the
# same weights that had been written into RotVacuity.lean. Binding the copy
# means `forge` itself could drift from the router with every gate still green
# -- the duplicate was deleted and this now reads the one the theorems use.
#
# That choice creates an obligation this checker discharges. The moment someone
# retunes LAMBDAS or MUS in hooks/rot-router.sh, the Lean witness silently
# becomes a statement about a profile nobody runs. Every gate stays green:
# `lake build` still succeeds, the theorems are still true, the router still
# works -- and the claim "proved for the shipping profile" quietly becomes
# false. Nothing else in this repo can see that.
#
# A NOTE ON WHAT THIS DOES *NOT* SAY, because the distinction is the point:
# this proves the NUMBERS agree. It does not prove the shell computes the same
# FUNCTION as the Lean definition -- that is checker/cross-diff.sh's job, which
# compares both router arms against a corpus of measured live readings. Two
# different claims, two different instruments, neither a substitute.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

SH="hooks/rot-router.sh"
LEAN="lean/Proofs/RotGauge.lean"
pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=lean-binds-shell::%s\n' "$*"; fail=$((fail+1)); }

echo "== Lean witness vs shipped weights =="

[ -f "$SH" ]   || { echo "  FAIL  missing $SH";   exit 1; }
[ -f "$LEAN" ] || { echo "  FAIL  missing $LEAN"; exit 1; }

# --- ALL TEN PROFILES, not just the one that used to be the only one --------
#
# THIS CHECK NEARLY DIED OF ITS OWN SUCCESS. It was written when the router
# mounted a single weight table, so `^LAMBDAS=` found that table and comparing
# it against Lean's `forge` covered 100% of the shipped weights.
#
# Profile switching added nine more tables. `^LAMBDAS=` then matched
# `LAMBDAS=$L_CONVERGENT` -- an INDIRECTION, not a table -- and the shell side
# became the literal string "LAMBDAS=$L_CONVERGENT", one "lens" long. It failed
# loudly, which is luck: had the pattern happened to match a real 9-number line
# for one profile, this check would have gone green while nine tables sat
# unverified behind it.
#
# The durable repair is not to re-pin FORGE. It is to verify EVERY profile the
# shell ships against a Lean witness of the same name, and to REFUSE if the two
# sides disagree about which profiles exist -- so the next table added to the
# router cannot be silently unbound.
PROFILES='CONVERGENT CLINICAL EXECUTIVE EMPATHIC STRATEGIC CREATIVE PREDICTIVE STEALTH RECURSIVE FORGE'

# The Lean witness names them in lower camel, and two differ from a plain
# lower-casing: RECURSIVE is `recursiveP` (`recursive` is reserved-adjacent and
# reads badly beside Lean's own recursion), FORGE is `forge`. Mapped explicitly
# rather than transformed, because a transformation that silently produced a
# non-existent name would extract zero pairs and pass vacuously.
lean_name_for () {
  case $1 in
    CONVERGENT) echo convergent ;; CLINICAL) echo clinical ;;
    EXECUTIVE)  echo executive  ;; EMPATHIC) echo empathic ;;
    STRATEGIC)  echo strategic  ;; CREATIVE) echo creative ;;
    PREDICTIVE) echo predictive ;; STEALTH)  echo stealth  ;;
    RECURSIVE)  echo recursiveP ;; FORGE)    echo forge    ;;
    *) echo '' ;;
  esac
}

# Pull one profile's weights out of the shell's `L_<NAME>=` / `M_<NAME>=` pair.
#
# NOT ANCHORED AT COLUMN 0, and that is the point: the router writes both tables
# on ONE line (`L_STEALTH='...';    M_STEALTH='...'`), so a `^M_` pattern matches
# nothing and every M comparison silently reports "the shell has no table".
# Measured -- it produced ten identical false failures in a row, which is at
# least an honest way to be wrong.
#
# The leading `[^A-Za-z0-9_]` guard stops `M_STEALTH` from also matching some
# hypothetical `X_M_STEALTH`, and `\{0,1\}` keeps it optional so a column-0
# assignment still matches.
sh_weights_for () {   # <PROFILE> <L|M> -> the nine numbers
  sed -n "s/.*[^A-Za-z0-9_]\{0,1\}$2_$1='\([^']*\)'.*/\1/p" "$SH" | head -1
}

# Pull one profile's pairs out of the Lean witness.
lean_pairs_for () {   # <leanName>
  awk -v want="$1" '
    $0 ~ "^def " want " " { inside = 1; next }
    inside && $0 !~ /^[ \t]*\|/ { inside = 0 }
    inside {
      if (match($0, /[0-9]+\.[0-9]+, *[0-9]+\.[0-9]+/)) {
        s = substr($0, RSTART, RLENGTH); gsub(/ /, "", s); print s
      }
    }' "$LEAN"
}

# Numeric comparison, tolerant of 1.1 vs 1.10 -- a formatting difference is not
# a disagreement, and treating it as one would train people to ignore this.
norm () { printf '%s\n' $1 | awk '{printf "%.4f ", $1+0}'; }

for _p in $PROFILES; do
  _ln=$(lean_name_for "$_p")
  if [ -z "$_ln" ]; then bad "no Lean witness NAME mapped for profile $_p"; continue; fi

  _shl=$(sh_weights_for "$_p" L)
  _shm=$(sh_weights_for "$_p" M)
  if [ -z "$_shl" ] || [ -z "$_shm" ]; then
    bad "profile $_p: the SHELL has no L_$_p / M_$_p table"
    continue
  fi

  _pairs=$(lean_pairs_for "$_ln")
  _nl=$(printf '%s\n' "$_pairs" | grep -c .)
  _ns=$(printf '%s\n' $_shl | grep -c .)

  # The extractor must actually find something, or every comparison below is a
  # vacuous pass -- the same failure this repo keeps hunting.
  if [ "$_nl" -eq 0 ]; then
    bad "profile $_p: extracted NOTHING from Lean's \`$_ln\` -- would pass vacuously"
    continue
  fi
  if [ "$_nl" -ne "$_ns" ]; then
    bad "profile $_p: lens COUNT differs -- shell $_ns, Lean $_nl"
    continue
  fi

  _ll=$(printf '%s\n' "$_pairs" | cut -d, -f1 | tr '\n' ' ' | sed 's/ $//')
  _lm=$(printf '%s\n' "$_pairs" | cut -d, -f2 | tr '\n' ' ' | sed 's/ $//')

  if [ "$(norm "$_shl")" = "$(norm "$_ll")" ]; then
    ok "profile $_p: lambdas agree ($_ns lenses)"
  else
    bad "profile $_p: LAMBDAS DIFFER -- shell [$_shl] vs Lean [$_ll]"
  fi
  if [ "$(norm "$_shm")" = "$(norm "$_lm")" ]; then
    ok "profile $_p: mus agree"
  else
    bad "profile $_p: MUS DIFFER -- shell [$_shm] vs Lean [$_lm]"
  fi
done

# THE SHELL MUST NOT SHIP A PROFILE THIS CHECK DOES NOT KNOW ABOUT. Without
# this, adding an eleventh table to the router would leave it unverified and
# every line above would still say PASS.
sh_profile_count=$(grep -c "^L_[A-Z][A-Z]*=" "$SH")
want_count=$(printf '%s\n' $PROFILES | grep -c .)
if [ "$sh_profile_count" -eq "$want_count" ]; then
  ok "the shell ships exactly the $want_count profiles this check verifies"
else
  bad "the shell ships $sh_profile_count profile tables but this check verifies $want_count -- an unbound table would go unchecked"
fi

# --- the legacy single-table comparison, kept for the roster checks below ---
sh_lam=$(sh_weights_for FORGE L)
sh_mu=$(sh_weights_for FORGE M)

# --- extract from the Lean witness ------------------------------------------
# The forge table is a list of ⟨lam, mu⟩ pairs, one per line, with the
# lens name in a trailing comment. Pull the two numbers from each pair.
# PRECISION MATTERS HERE, and the sloppy version was caught in the act. A first
# attempt started the scan on any line merely CONTAINING "forge" -- which caught
# docstrings mentioning `forge_posWeights` and pulled 11 pairs out of a 9-lens
# table. It failed loudly, but a variant of that mistake that over-matched by
# ZERO rows would have compared two empty lists and passed. Anchor on the
# definition, stop at the first line that is not a match arm.
lean_pairs=$(awk '
  /^def forge / { inside = 1; next }
  inside && $0 !~ /^[ \t]*\|/ { inside = 0 }
  inside {
    if (match($0, /[0-9]+\.[0-9]+, *[0-9]+\.[0-9]+/)) {
      s = substr($0, RSTART, RLENGTH); gsub(/ /, "", s); print s
    }
  }' "$LEAN")

lean_lam=$(printf '%s\n' "$lean_pairs" | cut -d, -f1 | tr '\n' ' ' | sed 's/ $//')
lean_mu=$(printf  '%s\n' "$lean_pairs" | cut -d, -f2 | tr '\n' ' ' | sed 's/ $//')

n_lean=$(printf '%s\n' "$lean_pairs" | grep -c .)
n_sh=$(printf '%s\n' $sh_lam | grep -c .)

echo "  shell LAMBDAS : $sh_lam"
echo "  lean  lambdas : $lean_lam"
echo "  shell MUS     : $sh_mu"
echo "  lean  mus     : $lean_mu"

# The extractor must actually find something, or every comparison below is a
# vacuous pass -- the same failure this repo keeps hunting.
if [ "$n_lean" -eq 0 ]; then
  bad "extracted NOTHING from the Lean witness -- this check would pass vacuously"
elif [ "$n_lean" -ne "$n_sh" ]; then
  bad "lens COUNT differs: shell has $n_sh, Lean witness has $n_lean"
else
  ok "lens count agrees ($n_sh)"
fi

# Numeric comparison, tolerant of 1.1 vs 1.10 -- a formatting difference is not
# a disagreement, and treating it as one would train people to ignore this.
norm () { printf '%s\n' $1 | awk '{printf "%.4f ", $1+0}'; }
if [ "$(norm "$sh_lam")" = "$(norm "$lean_lam")" ]; then
  ok "lambdas agree between the shell and the Lean witness"
else
  bad "LAMBDAS DIFFER -- the Lean witness no longer describes the shipping profile"
fi
if [ "$(norm "$sh_mu")" = "$(norm "$lean_mu")" ]; then
  ok "mus agree between the shell and the Lean witness"
else
  bad "MUS DIFFER -- the Lean witness no longer describes the shipping profile"
fi

# --- the ROSTER binds too, not just the numbers -----------------------------
# The weights were bound long before the NAMES were, which left a hole exactly
# the width of a rename: the engine document calls them Violet_Noir,
# Chroma_Spectral, Soleil_Blank and Anti-Venom, while both routers and the Lean
# witness say Violet, Chroma, Soleil, AntiVenom. Nothing checked that those are
# the same nine lenses in the same order, so renaming a lens on one surface
# would have drifted silently and every gate would have stayed green.
#
# The rule is a PREFIX rule, deliberately, and it is the honest shape of the
# relationship: the short name is the stem of the long one. Demanding equality
# would forbid the engine from ever using a full name, which is a spec that
# forbids a correct future -- the defect class this project hunts. Demanding
# only "nine of each" would accept a reordering, which is the actual risk,
# since `lead` and the weight vectors are POSITIONAL.
echo
echo "-- lens roster, all three surfaces --"
canon () { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9'; }

sh_names=$(sed -n "s/^NAMES='\(.*\)'.*/\1/p" "$REPO/hooks/rot-router.sh")
ps_names=$(sed -n "s/.*Names *= *@(\(.*\)).*/\1/p" "$REPO/hooks/rot-router.ps1" | tr -d "'" | tr ',' ' ')
lean_names=$(sed -n '/^inductive Lens where/,/^deriving/p' "$REPO/lean/Proofs/RotLens.lean" \
             | tr '|' '\n' | sed -n 's/^ *\([a-z][a-z0-9]*\) *$/\1/p' | tr '\n' ' ')
# sed -E, and NOT by preference: the first version of this line used BRE
# alternation (\|), which is a GNU extension. BSD sed on macOS ignores it, the
# match never fires, and the extraction FAILS OPEN -- the worst direction, since
# an empty roster makes every comparison below vacuously true. checker/
# portability.sh caught it on this very line. The anti-vacuity guard would have
# converted that silent pass into a loud failure anyway, which is the point of
# having both: one instrument stops the defect, the other stops it from being
# quiet.
eng_names=$(sed -nE 's/.*\*\*(Nova|Violet_Noir|Anti-Venom|Venom|Carnage|Chroma_Spectral|Soleil_Blank|Eidolon|Claude)\*\*.*/\1/p' \
             "$REPO/engine/rot-lean.md" | awk '!seen[$0]++' | tr '\n' ' ')

# ANTI-VACUITY: every surface must actually yield nine names. An extraction that
# silently returns nothing would make every comparison below trivially true --
# the way a roster check turns into decoration without anyone noticing.
for pair in "shell:$sh_names" "pwsh:$ps_names" "lean:$lean_names" "engine:$eng_names"; do
  _who=${pair%%:*}; _what=${pair#*:}
  _n=$(printf '%s\n' $_what | grep -c .)
  if [ "$_n" -eq 9 ]; then ok "$_who roster extracted: 9 lenses"
  else bad "$_who roster extracted $_n names, expected 9 -- extraction is broken, not the roster"; fi
done

i=1; roster_ok=1
for s in $sh_names; do
  p=$(printf '%s\n' $ps_names | sed -n "${i}p")
  l=$(printf '%s\n' $lean_names | sed -n "${i}p")
  e=$(printf '%s\n' $eng_names | sed -n "${i}p")
  cs=$(canon "$s"); cl=$(canon "$l"); ce=$(canon "$e"); cp=$(canon "$p")
  [ "$cs" = "$cp" ] || { bad "position $i: shell '$s' vs pwsh '$p'"; roster_ok=0; }
  [ "$cs" = "$cl" ] || { bad "position $i: shell '$s' vs Lean '$l'"; roster_ok=0; }
  case "$ce" in
    "$cs"*) : ;;
    *) bad "position $i: engine '$e' is not a long form of '$s'"; roster_ok=0 ;;
  esac
  i=$((i+1))
done
[ "$roster_ok" -eq 1 ] && ok "roster agrees in NAME and ORDER across shell, pwsh, Lean and the engine document"

# --- negative control -------------------------------------------------------
echo
echo "-- negative control --"

# The roster control has to break the ORDER, not just a spelling: a swap is the
# failure a positional weight table actually suffers, and a checker that only
# catches typos would pass the dangerous case.
swapped=$(printf '%s\n' $sh_names | awk 'NR==1{print "Venom";next} NR==4{print "Nova";next} {print}' | tr '\n' ' ')
ctl_i=1; ctl_caught=0
for s in $swapped; do
  l=$(printf '%s\n' $lean_names | sed -n "${ctl_i}p")
  [ "$(canon "$s")" = "$(canon "$l")" ] || ctl_caught=1
  ctl_i=$((ctl_i+1))
done
if [ "$ctl_caught" -eq 1 ]; then
  ok "CONTROL: swapping two lenses in the roster WOULD be detected"
else
  bad "CONTROL DEAD: a swapped roster still compared equal"
fi

mutated=$(printf '%s\n' $sh_lam | awk 'NR==1{$1=$1+0.5} {printf "%s ", $1}' | sed 's/ $//')
if [ "$(norm "$mutated")" = "$(norm "$lean_lam")" ]; then
  bad "CONTROL DEAD: a retuned first lambda still compared equal"
else
  ok "CONTROL: retuning one lambda (+0.5) WOULD be detected"
fi

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  lean-binds-shell: PASS"; exit 0; } || { echo "  lean-binds-shell: FAIL"; exit 1; }
