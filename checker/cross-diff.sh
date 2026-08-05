#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# R3 / R13 -- bind the Lean model to the shipped hooks, and the hooks to each
# other.
#
# A proof that does not touch the shipped hook proves nothing about it. This
# executes BOTH REAL IMPLEMENTATIONS over one corpus and compares three things:
#
#   1. rot-router.sh  vs  rot-router.ps1     byte-for-byte on every row
#   2. either arm     vs  the Lean #eval corpus for the rows Lean fixes
#   3. either arm     vs  the LIVE readings measured from the running hook
#
# Comparison is on the FORMATTED STRING, not the number. That is deliberate:
# the locale trap (0.09 -> "0,09" under a comma-decimal locale) is invisible to
# a numeric comparison and fatal to the thing that consumes the output.
#
# Two implementations that agree is a truth a single green cannot fake -- a
# shared bug has to be written twice, in two languages, by hand. That is the
# entire argument for maintaining a second arm at all.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SH="$REPO/hooks/rot-router.sh"
PS1="$REPO/hooks/rot-router.ps1"
CORPUS="$REPO/checker/corpus-gauge.txt"

pass=0; fail=0; skip=0
ok()   { echo "  PASS  $*"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $*"; fail=$((fail+1)); }

PWSH=""
for c in pwsh powershell; do command -v "$c" >/dev/null 2>&1 && { PWSH="$c"; break; }; done

echo "== corpus =="
[ -f "$CORPUS" ] || { echo "FATAL: corpus missing: $CORPUS"; exit 2; }
echo "  $(grep -cvE '^\s*(#|$)' "$CORPUS") rows"
[ -n "$PWSH" ] && echo "  PowerShell: $PWSH" || echo "  PowerShell: ABSENT -- arm-vs-arm rows will be SKIPPED, not passed"

echo
echo "== 1+3: POSIX arm vs the expected string (Lean corpus / live readings) =="
while IFS='|' read -r vec br M C T want note; do
  case "$vec" in ''|\#*) continue ;; esac
  got=$("$SH" --vector "$vec" --breadth "$br" --M "$M" --C "$C" --T "$T")
  if [ "$got" = "$want" ]; then ok "$note"
  else bad "$note"; echo "        want: $want"; echo "        got : $got"; fi
done < <(grep -vE '^\s*(#|$)' "$CORPUS")

echo
echo "== 2: cross-diff -- the two arms must agree BYTE FOR BYTE =="
if [ -z "$PWSH" ]; then
  echo "  SKIP  no PowerShell on this machine ($((`grep -cvE '^\s*(#|$)' "$CORPUS"`)) rows unverified)"
  skip=$((skip+1))
else
  while IFS='|' read -r vec br M C T want note; do
    case "$vec" in ''|\#*) continue ;; esac
    a=$("$SH" --vector "$vec" --breadth "$br" --M "$M" --C "$C" --T "$T")
    b=$("$PWSH" -NoProfile -File "$PS1" -Vector "$vec" -Breadth "$br" -M "$M" -C "$C" -T "$T")
    b=$(printf '%s' "$b" | tr -d '\r')
    if [ "$a" = "$b" ]; then ok "arms agree: $note"
    else bad "ARMS DISAGREE: $note"; echo "        sh : $a"; echo "        ps1: $b"; fi
  done < <(grep -vE '^\s*(#|$)' "$CORPUS")
fi

echo
echo "== TIER 1: both arms, every lane =="
# One probe per lane plus the default. This is the routing half of R7b: it
# executes the SHIPPED router, not the model. RotRoute.lean proves the order is
# total and dead-lane-free; this proves the shipped code implements that order.
# CONVERGENT names the MODEL that convenes the nine, not a lead lens, so its
# expected value depends on the machine's settings.json. Pinning the override
# makes the row deterministic on every machine WITHOUT weakening it: the check
# still asserts the exact string, it just asserts one the test controls. An
# expectation that quoted this developer's model would have been a snapshot,
# red on any other machine with nothing wrong.
ROTMOE_MODEL="ROTMOE_TESTMODEL"; export ROTMOE_MODEL

while IFS='|' read -r prompt want; do
  case "$prompt" in ''|\#*) continue ;; esac
  got=$("$SH" --route "$prompt")
  [ "$got" = "$want" ] && ok "sh route: '$prompt' -> $got" \
                       || { bad "sh route: '$prompt'"; echo "        want $want got $got"; }
  if [ -n "$PWSH" ]; then
    gp=$("$PWSH" -NoProfile -File "$PS1" -Route "$prompt" | tr -d '\r')
    [ "$gp" = "$got" ] && ok "arms agree on route: '$prompt'" \
                       || { bad "ROUTE ARMS DISAGREE: '$prompt'"; echo "        sh $got / ps1 $gp"; }
  fi
done <<'ROUTES'
lake build the theorem|FORGE Claude
fix this bug|CLINICAL AntiVenom
decide now|EXECUTIVE Venom
how do i feel|EMPATHIC Violet
plan the roadmap|STRATEGIC Nova
invent a paradox|CREATIVE Carnage
what happens next|PREDICTIVE Chroma
compress the tokens|STEALTH Soleil
refactor the meta layer|RECURSIVE Eidolon
hello there|CONVERGENT ROTMOE_TESTMODEL
# --- 0.7.0: the word-prefix matcher -----------------------------------------
# THE TWO PROMPTS THAT WERE MEASURED WRONG. Before the fix, on the shipped
# router: "prove this lemma" -> CONVERGENT, and the second -> STEALTH, because
# it matched `byte` and nothing in FORGE. On a prover head those are the two
# most proof-shaped prompts imaginable.
prove this lemma|FORGE Claude
prove the read loop conserves bytes in lean|FORGE Claude
# THE COLLISIONS THAT MADE THOSE STEMS UNADDABLE. Each row is a word CONTAINING
# a stem: a substring matcher routes every one of them to FORGE, which is why
# `prove`, `lemma` and `lean` could not simply be appended to the list. These
# rows are the reason the matcher cannot be reverted quietly.
improve the documentation|CONVERGENT ROTMOE_TESTMODEL
that is the dilemma|CONVERGENT ROTMOE_TESTMODEL
cleaning up the tree|CONVERGENT ROTMOE_TESTMODEL
# COLLISIONS THAT WERE ALREADY LIVE before 0.7.0 and are fixed by the same rule:
# `fix` fired on "prefix", `now` on "known", `test` on "latest". Each of these
# used to reach a lane that has nothing to do with the prompt.
add a prefix to the name|CONVERGENT ROTMOE_TESTMODEL
what is known about it|CONVERGENT ROTMOE_TESTMODEL
the latest release notes|CONVERGENT ROTMOE_TESTMODEL
# AND THE PREFIXES THAT MUST STILL FIRE. A stem is a word PREFIX, not a whole
# word -- `verif` has always been expected to catch "verification". A matcher
# tightened to whole words would pass every row above and break these.
proofs of termination|FORGE Claude
verification of the bound|CLINICAL AntiVenom
the strategy document|STRATEGIC Nova
# THE PUNCTUATION-LED EXCEPTION: `.lean` has no word boundary before the dot, so
# it falls back to a substring test. Without that carve-out this row goes red.
check Basic.lean now|FORGE Claude
ROUTES

echo
echo "== LOCALE INVARIANCE: the same row under every installed locale =="
# The locale trap is the one defect that a numeric comparison cannot see and a
# single-locale run cannot reach. Every available comma-decimal locale is forced
# and the output must be BYTE-IDENTICAL to the C-locale output.
#
# HONEST SCOPE, measured rather than assumed: awk in the Git Bash build on the
# development machine formats %.2f in the C locale regardless of LC_ALL, so this
# phase passes there trivially and proves nothing. On a glibc runner it is a
# real test. `printf(1)` under de_DE was measured to render 0.09 as "0,00" AND
# to reject "0.09" as an invalid number -- so the hazard is genuine, it simply
# lands on a different formatter than the one the gauge uses.
base_row=$("$SH" --vector 0,0,0,0,0,0,0,0,0 --breadth 0 --M 1.05 --C 0.7 --T 0.8)
loc_tested=0
for cand in de_DE.UTF-8 de_DE.utf8 fr_FR.UTF-8 it_IT.UTF-8 nl_NL.UTF-8; do
  locale -a 2>/dev/null | grep -qix "$(printf '%s' "$cand" | tr 'A-Z' 'a-z' | sed 's/utf-8/utf8/')" \
    || locale -a 2>/dev/null | grep -qx "$cand" || continue
  loc_tested=$((loc_tested+1))
  got=$(LC_ALL="$cand" LC_NUMERIC="$cand" "$SH" --vector 0,0,0,0,0,0,0,0,0 --breadth 0 --M 1.05 --C 0.7 --T 0.8)
  [ "$got" = "$base_row" ] && ok "locale-invariant under $cand" \
    || { bad "LOCALE DRIFT under $cand"; echo "        C   : $base_row"; echo "        $cand: $got"; }
done
if [ "$loc_tested" -eq 0 ]; then
  echo "  SKIP  no alternative locale installed -- invariance UNTESTED here (not passed)"
  skip=$((skip+1))
else
  # Does this platform's awk even honour a locale? If not, say so rather than
  # letting the passes above read as a guarantee they are not.
  if [ "$(LC_ALL=de_DE.UTF-8 awk 'BEGIN{printf "%.2f",0.09}' 2>/dev/null)" = "0.09" ]; then
    echo "  NOTE  this awk ignores the locale for %.2f, so the rows above are"
    echo "        trivially green. The phase is meaningful on a glibc runner."
  fi
fi

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed, $skip skipped"
if [ "$skip" -gt 0 ]; then
  echo "  NOTE: a SKIP is not a PASS. The cross-diff is the point of this file,"
  echo "        and on a machine without PowerShell it did not run."
fi
[ "$fail" -eq 0 ] && { echo "  R3/R13: PASS"; exit 0; } || { echo "  R3/R13: FAIL"; exit 1; }
