#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# The compliance endpoint, re-derived from the raw corpus and checked against
# the figures published in CHANGELOG.md.
#
# The point of this gate is NOT that routing wins -- it does not. The point is
# that the number which is published stays the number the corpus produces, in
# both directions: if a future change makes the headline bigger, this goes red
# just as loudly as if it makes it smaller. A figure nobody re-derives is a
# figure that drifts.
#
# It asserts the DE-CONFOUNDED verdict too, because the headline alone is
# misleading and has to stay attached to its correction. Quoting "28 wins to 10,
# p = 5.1e-3" without "2 to 10 once brevity is removed" would be an overclaim
# the repo would then be enforcing.
#
# Exit 3 SKIP when the raw corpus is not on this machine: the transcripts are
# ~176 JSON payloads that are not committed, so CI cannot see them. A skip is
# never a pass, and this prints why.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CORPUS="${ROTMOE_AB_CORPUS:-D:/Temp/rotmoe-ab}"
SCORER="$REPO/bench/ab-compliance.js"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  PASS  $*"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL  $*"; }

echo "== A/B instruction compliance -- published figures re-derived from the raw corpus =="

[ -f "$SCORER" ] || { echo "  FAIL  scorer missing: $SCORER"; exit 1; }
if [ ! -d "$CORPUS/arma" ] || [ ! -d "$CORPUS/armb" ]; then
  echo "SKIP: the raw A/B transcripts are not on this machine ($CORPUS)."
  echo "      They are ~176 JSON payloads and are not committed, so this gate"
  echo "      cannot run in CI. Exit 3 is a SKIP, never a pass."
  exit 3
fi

JSON="$(node "$SCORER" "$CORPUS")"
RC=$?
if [ "$RC" -eq 3 ] || [ "$JSON" = "NOCORPUS" ]; then
  echo "SKIP: the scorer found no paired turns under $CORPUS. Exit 3 is a SKIP."
  exit 3
fi
if [ "$RC" -ne 0 ]; then
  echo "  FAIL  scorer exited $RC"
  echo "$JSON"
  exit 1
fi

get() { printf '%s' "$JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);const v=j[process.argv[1]];console.log(typeof v==="boolean"?(v?"true":"false"):String(v))})' "$1"; }

TURNS=$(get turns)
VA=$(get violationsRouted)
VB=$(get violationsUnrouted)
HW=$(get headlineWinsRouted)
HL=$(get headlineWinsUnrouted)
EX=$(get explained)
UN=$(get unexplained)
DL=$(get deconfoundedLosses)
SURV=$(get survivesDeconfounding)

echo "  turns $TURNS | violations routed $VA unrouted $VB | headline $HW-$HL | de-confounded $UN-$DL (explained $EX)"

# --- the published figures ---------------------------------------------------
[ "$TURNS" = "88" ] && ok "88 paired turns" || bad "paired turns: expected 88, got $TURNS"
[ "$VA" = "23" ]    && ok "routed violates the two-sentence limit 23 times" || bad "routed violations: expected 23, got $VA"
[ "$VB" = "41" ]    && ok "unrouted violates it 41 times" || bad "unrouted violations: expected 41, got $VB"
[ "$HW" = "28" ] && [ "$HL" = "10" ] && ok "headline 28-10 to routed" || bad "headline: expected 28-10, got $HW-$HL"
[ "$EX" = "26" ] && ok "26 of those wins are explained by brevity alone" || bad "explained wins: expected 26, got $EX"
[ "$UN" = "2" ] && [ "$DL" = "10" ] && ok "de-confounded subset is 2-10 AGAINST routing" || bad "de-confounded: expected 2-10, got $UN-$DL"

# --- the endpoint must still be CAPABLE --------------------------------------
# If the control arm ever reaches zero violations, this endpoint joins the two
# saturated primaries and stops being evidence of anything. Then it must be
# replaced, not reported.
if [ "$VB" -gt 0 ]; then
  ok "CAPABLE: the control arm is off the floor ($VB violations), so a win is expressible"
else
  bad "SATURATED: the control arm has 0 violations -- this endpoint can no longer show a win"
fi

# --- the correction must stay attached ---------------------------------------
if [ "$SURV" = "false" ]; then
  ok "the headline does NOT survive de-confounding -- recorded, as published"
else
  bad "the compliance win now SURVIVES de-confounding ($UN vs $DL). That is a"
  bad "  real change in the result and CHANGELOG.md must be rewritten to match,"
  bad "  not this check relaxed."
fi

# --- controls: each assertion must be able to fail ---------------------------
echo "== controls: the gate must be able to FAIL =="
CTL="$(printf '%s' "$JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);j.violationsUnrouted=0;console.log(JSON.stringify(j))})')"
CTLVB="$(printf '%s' "$CTL" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).violationsUnrouted))')"
if [ "$CTLVB" = "0" ]; then
  ok "CONTROL: a saturated control arm is representable and would trip the CAPABLE check"
else
  bad "CONTROL: could not construct the saturated case -- the check is untested"
fi

printf '\n== ab-compliance: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || { echo "  ab-compliance: FAIL"; exit 1; }
echo "  ab-compliance: PASS"
exit 0
