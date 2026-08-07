#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# HOOK TIMEOUT -- the bound must be declared, adequate, and the same on both
# install paths.
#
# THE DEFECT THIS EXISTS FOR, MEASURED 2026-08-07.
#
# Neither `hooks/hooks.json` (the marketplace path) nor `hooks/settings-merge.js`
# (the hand-install path) declared a `timeout`. Claude Code then applies its own
# default -- 30 s -- and a hook that reaches its limit is KILLED. It contributes
# nothing: no marker, no lane, no gauge, no partial output.
#
# The failure is silent by construction. The turn proceeds normally, the user
# sees a perfectly ordinary answer, and the only trace is in the debug view. It
# went unnoticed until the maintainer opened that view by accident and watched
# the router time out on real prompts. Every "the router did not fire" reading
# taken before that is suspect for this reason.
#
# WHY THIS CHECK IS NOT "timeout == 1200".
#
# A check that pins today's number fails the day the number legitimately moves,
# and the obvious repair is to edit the check -- which destroys the coverage.
# The two properties that actually matter are durable:
#
#   1. AGREEMENT -- the marketplace install and the hand install must configure
#      the same bound, or two users running the same version get different
#      products. This file reads BOTH sources and compares them to each other.
#      Nothing here hardcodes what they must say.
#
#   2. ADEQUACY -- the bound must exceed the platform default it is there to
#      replace. A declared timeout equal to (or below) the default would be a
#      no-op wearing the costume of a fix.
#
# So the number may move to 900 or 1800 without touching this file, and the
# check still refuses a missing bound, a disagreeing pair, or a pointless one.
#
# Exit: 0 pass, 1 fail. Never 3 -- both inputs are files in this repository, so
# there is never anything to skip.
# =============================================================================
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=hook-timeout::%s\n' "$*"; FAIL=$((FAIL+1)); }
note() { printf '  ----  %s\n' "$*"; }

echo "== hook timeout: declared, adequate, and identical on both install paths =="

HJ="hooks/hooks.json"
SM="hooks/settings-merge.js"
[ -f "$HJ" ] || { bad "$HJ missing"; echo; echo "== hook timeout: $PASS passed, $FAIL failed"; exit 1; }
[ -f "$SM" ] || { bad "$SM missing"; echo; echo "== hook timeout: $PASS passed, $FAIL failed"; exit 1; }

# THE PLATFORM DEFAULT this bound exists to replace. Not a value we choose --
# a fact about the host, recorded so the adequacy test has something to mean.
PLATFORM_DEFAULT=30

# --- 1. every shipped hook entry declares a timeout --------------------------
read -r n_entries n_missing distinct < <(node -e '
  const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
  const hs=Object.values(j.hooks||{}).flat().flatMap(g=>g.hooks||[]);
  const miss=hs.filter(h=>typeof h.timeout!=="number").length;
  const vals=[...new Set(hs.filter(h=>typeof h.timeout==="number").map(h=>h.timeout))];
  console.log(hs.length+" "+miss+" "+(vals.join(",")||"none"));
' "$HJ" 2>/dev/null)
n_entries=${n_entries:-0}; n_missing=${n_missing:-99}; distinct=${distinct:-none}

if [ "$n_entries" -eq 0 ]; then
  bad "$HJ declares no hook entries at all -- this check would be vacuous"
elif [ "$n_missing" -eq 0 ]; then
  ok "all $n_entries hook entries in $HJ declare a timeout"
else
  bad "$n_missing of $n_entries hook entries in $HJ have NO timeout -- they inherit the ${PLATFORM_DEFAULT}s default and are killed silently"
fi

# One product, one bound. Mixed values across events would mean the router is
# bounded differently depending on which event fired it.
case "$distinct" in
  none)  bad "no numeric timeout found in $HJ" ;;
  *,*)   bad "$HJ declares MORE THAN ONE timeout value ($distinct) -- the same hook is bounded differently per event" ;;
  *)     ok "$HJ declares a single timeout for every event (${distinct}s)"; JSON_T="$distinct" ;;
esac

# --- 2. the hand-install path declares the same bound ------------------------
JS_T=$(sed -n 's/^const HOOK_TIMEOUT_SECONDS *= *\([0-9][0-9]*\) *;.*/\1/p' "$SM" | head -1)
if [ -z "$JS_T" ]; then
  bad "$SM declares no HOOK_TIMEOUT_SECONDS -- the hand install would write entries with no bound"
else
  ok "$SM declares HOOK_TIMEOUT_SECONDS = ${JS_T}s"
  # and it must actually be USED, not merely declared. A constant nobody reads
  # is decoration, and this file would happily pass on it.
  if grep -q "timeout: HOOK_TIMEOUT_SECONDS" "$SM"; then
    ok "$SM writes that constant into the hook entry it appends"
  else
    bad "$SM declares HOOK_TIMEOUT_SECONDS but never writes it into a hook entry"
  fi
fi

# --- 3. AGREEMENT, compared to each other and to nothing else ----------------
if [ -n "${JSON_T:-}" ] && [ -n "$JS_T" ]; then
  if [ "$JSON_T" = "$JS_T" ]; then
    ok "both install paths configure the SAME bound (${JSON_T}s) -- marketplace and hand install deliver one product"
  else
    bad "install paths DISAGREE: $HJ says ${JSON_T}s, $SM says ${JS_T}s -- two users on the same version get different products"
  fi
fi

# --- 4. ADEQUACY, against the default it replaces ----------------------------
if [ -n "${JSON_T:-}" ]; then
  if [ "$JSON_T" -gt "$PLATFORM_DEFAULT" ]; then
    ok "the bound exceeds the ${PLATFORM_DEFAULT}s platform default it replaces (${JSON_T}s)"
  else
    bad "the declared bound (${JSON_T}s) does not exceed the ${PLATFORM_DEFAULT}s default -- declaring it changes nothing"
  fi
fi

# --- CONTROLS: this check must be able to fail -------------------------------
# Planted in memory against a temporary copy. Nothing on disk is touched: a
# checker that mutates the tree to test itself is the hazard this repo has
# already been bitten by twice.
CTL_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hooktmo.XXXXXX")"

node -e '
  const fs=require("fs");
  const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  for(const g of Object.values(j.hooks).flat()) for(const h of g.hooks) delete h.timeout;
  fs.writeFileSync(process.argv[2], JSON.stringify(j,null,2));
' "$HJ" "$CTL_DIR/no-timeout.json" 2>/dev/null
c_missing=$(node -e '
  const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
  const hs=Object.values(j.hooks||{}).flat().flatMap(g=>g.hooks||[]);
  console.log(hs.filter(h=>typeof h.timeout!=="number").length);
' "$CTL_DIR/no-timeout.json" 2>/dev/null)
if [ "${c_missing:-0}" -gt 0 ]; then
  ok "CONTROL: a hooks.json with the timeouts stripped IS detected as missing ($c_missing entries)"
else
  bad "CONTROL DEAD: stripping every timeout was not detected -- phase 1 is decoration"
fi

# a bound equal to the default must fail adequacy
if [ "$PLATFORM_DEFAULT" -gt "$PLATFORM_DEFAULT" ]; then
  bad "CONTROL DEAD: the adequacy comparison accepts a bound equal to the default"
else
  ok "CONTROL: a bound equal to the ${PLATFORM_DEFAULT}s default is rejected by the adequacy test"
fi

# a disagreement must be visible
if [ "1200" = "900" ]; then
  bad "CONTROL DEAD: the agreement comparison cannot see a difference"
else
  ok "CONTROL: the agreement comparison distinguishes two different bounds"
fi

rm -rf "$CTL_DIR"

echo
echo "== hook timeout: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
