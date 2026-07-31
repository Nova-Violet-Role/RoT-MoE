#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-router.sh -- the RoT MoE router, POSIX arm.
#
# Two jobs, and the second one is new:
#
#   TIER 1  keyword routing -> a mode and its lead lens.
#   GAUGE   the R/s+ divergence figure over nine measured lens activities.
#
# WHY TIER 1 IS HERE AT ALL. Grepping the PowerShell that ships today for the
# mode names finds them only in a comment and in payload text: TIER 1 routing
# was SPECIFIED and never implemented. The gauge is what shipped. That gap is
# why lean/Proofs/RotRoute.lean says, in its own docstring, that it models the
# spec rather than running code -- and this file is what closes it. The
# priority order below is the one RotRoute.lean proves total, exhaustive and
# free of dead lanes.
#
# THE LOCALE TRAP IS NOT OPTIONAL. The PowerShell formats every number with
# InvariantCulture (rot-lean-inject.ps1:406-415). Under a comma-decimal locale
# "0.09" renders "0,09", the decimal separator collides with the field
# separator, and the injected vector becomes unparseable. LC_NUMERIC=C is the
# POSIX equivalent and it is set below, unconditionally, before any arithmetic.
#
# DETERMINISTIC MODE, and it is what makes cross-diffing possible at all:
#   rot-router.sh --vector a1,..,a9 --breadth N [--M x --C y --T z]
#   rot-router.sh --route "some prompt text"
# Both print one line and read nothing from disk, so the two implementations
# can be run over an identical corpus and compared byte for byte.
# =============================================================================

LC_ALL=C
LC_NUMERIC=C
export LC_ALL LC_NUMERIC

# --- TIER 1 ------------------------------------------------------------------
# Stems are case-insensitive substrings, quoted from rot-lean.md section 3.
# `code` (CLINICAL) and `art` (CREATIVE) are deliberately ABSENT: on a prover
# head `code` matches nearly every prompt and would pin the router to CLINICAL
# permanently, collapsing the tier into a constant; `art` collides with
# `.artifact`/`artifacts` paths. That deletion is a routing choice and it is
# disclosed here for the same reason the FORGE additions are.
#
# ORDER IS THE CONTRACT, not the word list. FORGE first: on this head the Lean
# stems are the common case. route_exact in RotRoute.lean characterises every
# lane in both directions against exactly this order.
STEMS_FORGE='run build install deploy reproduce ship lake theorem tactic sorry mathlib .lean'
STEMS_CLINICAL='debug error bug fix secur audit verif test cve'
STEMS_EXECUTIVE='decid urgenc strike direct declar now conclud'
STEMS_EMPATHIC='emot feel grief lonel soul story human tired lost'
STEMS_STRATEGIC='strateg plan goal roadmap priorit legal recommend analyz'
STEMS_CREATIVE='creativ chaos surreal disrupt paradox dream invent'
STEMS_PREDICTIVE='futur scenar predict trend forec likel horizon next'
STEMS_STEALTH='encod optim token compress concise byte distill'
STEMS_RECURSIVE='evolv recurs meta architect refactor ontolog hybrid'

fired () {   # fired "<lowercased prompt>" "<stem list>" -> 0 if any stem occurs
  _p="$1"; _s="$2"
  for _stem in $_s; do
    case "$_p" in *"$_stem"*) return 0 ;; esac
  done
  return 1
}

route () {
  _p=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  if   fired "$_p" "$STEMS_FORGE";      then echo "FORGE Claude"
  elif fired "$_p" "$STEMS_CLINICAL";   then echo "CLINICAL AntiVenom"
  elif fired "$_p" "$STEMS_EXECUTIVE";  then echo "EXECUTIVE Venom"
  elif fired "$_p" "$STEMS_EMPATHIC";   then echo "EMPATHIC Violet"
  elif fired "$_p" "$STEMS_STRATEGIC";  then echo "STRATEGIC Nova"
  elif fired "$_p" "$STEMS_CREATIVE";   then echo "CREATIVE Carnage"
  elif fired "$_p" "$STEMS_PREDICTIVE"; then echo "PREDICTIVE Chroma"
  elif fired "$_p" "$STEMS_STEALTH";    then echo "STEALTH Soleil"
  elif fired "$_p" "$STEMS_RECURSIVE";  then echo "RECURSIVE Eidolon"
  else                                       echo "CONVERGENT none"
  fi
}

# --- THE GAUGE ---------------------------------------------------------------
# Ported line for line from rot-lean-inject.ps1:357-416 and proved against
# lean/Proofs/RotGauge.lean. The lens order is fixed and load-bearing: the
# corpus, the PowerShell and this file must agree on which slot is which lens.
#
# LENS ORDER: Nova Violet AntiVenom Venom Carnage Chroma Soleil Eidolon Claude
# FORGE weights, quoted from rot-lean.md section 4, never re-derived here.
LAMBDAS='1.4 0.6 1.9 1.2 0.6 1.0 1.0 1.2 2.3'
MUS='1.05 0.85 1.10 1.05 0.90 1.10 0.95 1.10 1.15'
NAMES='Nova Violet AntiVenom Venom Carnage Chroma Soleil Eidolon Claude'

gauge () {   # gauge "a1,..,a9" breadth M C T
  _acts="$1"; _breadth="$2"; _M="$3"; _C="$4"; _T="$5"
  printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$_acts" "$_breadth" "$_M" "$_C" "$_T" "$LAMBDAS" "$MUS" "$NAMES" |
  awk -F'|' '
    # Match PowerShell ToString("0.##"): round, then strip trailing zeros and a
    # bare trailing dot. 0.90 -> "0.9", 1.00 -> "1", 0.09 -> "0.09".
    # Formatting is part of the observable: the cross-diff compares these
    # STRINGS byte for byte, which is precisely what catches a locale bug.
    function fmt(x, d,   s) {
      s = sprintf("%." d "f", x)
      if (s ~ /\./) { sub(/0+$/, "", s); sub(/\.$/, "", s) }
      return s
    }
    {
      n = split($1, a, ",");
      breadth = $2 + 0; M = $3 + 0; C = $4 + 0; T = $5 + 0;
      split($6, lam, " "); split($7, mu, " "); split($8, nm, " ");

      K = n;
      mean = 0; for (i = 1; i <= n; i++) mean += a[i] + 0;
      mean = mean / K;

      sum = 0; active = "";
      for (i = 1; i <= n; i++) {
        act = a[i] + 0;
        if (act > 0) active = (active == "" ? nm[i] : active "," nm[i]);
        d  = act - mean; if (d < 0) d = -d;          # delta from ensemble mean
        s  = 1.0 / (1.0 + exp(-4.0 * (d - 0.5)));    # sigmoid, slope 4, centre 0.5
        H  = (breadth > 0 ? act / breadth : 0.0);    # share of the turn breadth
        if (H > 1.0) H = 1.0;
        sum += lam[i] * s * (1.0 + H) * mu[i] * M * C * T;
      }
      R = sum / K;
      band = (R < 0.9 ? "BELOW RANGE" : (R > 1.8 ? "ABOVE RANGE" : "IN RANGE (0.9-1.8)"));
      if (active == "") active = "none";
      printf "R/s+ = %s [%s] mean=%s breadth=%d K=%d lenses=%s\n",
             fmt(R, 2), band, fmt(mean, 3), breadth, K, active;
    }'
}

# --- entry point -------------------------------------------------------------
MODE=""; VEC=""; BREADTH=0; M=1.05; C=1.0; T=1.0; PROMPT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --vector)  MODE=gauge; VEC="$2";     shift 2 ;;
    --breadth) BREADTH="$2";             shift 2 ;;
    --M)       M="$2";                   shift 2 ;;
    --C)       C="$2";                   shift 2 ;;
    --T)       T="$2";                   shift 2 ;;
    --route)   MODE=route; PROMPT="$2";  shift 2 ;;
    --version) echo "rot-router.sh 1.0.0"; exit 0 ;;
    *) echo "usage: rot-router.sh --vector a1,..,a9 --breadth N [--M x --C y --T z]" >&2
       echo "       rot-router.sh --route \"prompt text\"" >&2
       exit 2 ;;
  esac
done

case "$MODE" in
  gauge) gauge "$VEC" "$BREADTH" "$M" "$C" "$T" ;;
  route) route "$PROMPT" ;;
  *)     echo "rot-router.sh: no mode given (--vector or --route)" >&2; exit 2 ;;
esac
