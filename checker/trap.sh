#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE TRAP CORPUS AND ITS SCORING RULE -- are they still honest?
#
# This gate does NOT re-run 120 live turns; that costs ~25 minutes and real
# money. It guards the things that make the recorded result meaningful, every
# one of which can rot silently:
#
#   T1  the pre-registration exists and still contains its power floor,
#       its SILENT rule, and BOTH verdict rows (advantage AND disadvantage)
#   T2  the scorer implements the amended table -- a `disadvantage` branch is
#       present, so a routed LOSS cannot be filed as `null` again
#   T3  the parser controls pass, in both directions, INCLUDING the negative
#       control that rejects a naive /(\d+)/ reader
#   T4  the scorer controls pass, including the FATAL-on-missing-turns case
#   T5  the corpus is still all traps -- no item where naive == truth
#   T6  the recorded latency result was ORDER-CONTROLLED; a single-ordering
#       artifact must never be the one on disk
#   T7  the recorded accuracy verdicts are the ones actually reported
#
# WHY T6 IS THE ONE THAT MATTERS. bench/trap-latency.js refuses to attribute a
# speedup from one ordering, and that refusal is proved in
# lean/Proofs/RotOrdering.lean. If someone regenerates the artifact from a
# single ordering, the JSON silently becomes `UNATTRIBUTED` while the README
# still claims the router caused it. This gate fails in that case.
#
# Every check below can fail. That is the only reason a pass counts.
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

passed=0; failed=0
ok()   { echo "  PASS  $1"; passed=$((passed+1)); }
bad()  { echo "  FAIL  $1"; failed=$((failed+1)); }

PRE="bench/TRAP-PREREGISTRATION.md"
SCORE="bench/trap-score.js"
CAND="bench/trap-candidates.jsonl"
LAT="bench/trap-latency-controlled.json"
R1="bench/trap-result-rep1.json"
R2="bench/trap-result-rep2.json"

echo "== trap corpus gate"

# ---- T1 the pre-registration still says what it promised -------------------
if [ ! -f "$PRE" ]; then
  bad "$PRE is missing -- the rule was fixed in advance and the record is gone"
else
  for phrase in "noPower" "SILENT" "McNemar" "disadvantage" "AMENDMENT 1"; do
    if grep -Fq -- "$phrase" "$PRE"; then ok "pre-registration retains '$phrase'"
    else bad "pre-registration no longer mentions '$phrase'"; fi
  done
fi

# ---- T2 the scorer implements the AMENDED table ----------------------------
if [ ! -f "$SCORE" ]; then
  bad "$SCORE is missing"
else
  if grep -Fq 'verdict = "disadvantage"' "$SCORE"; then
    ok "scorer has the symmetric disadvantage branch"
  else
    bad "scorer has NO disadvantage branch -- a routed loss would be filed as null again"
  fi
  if grep -Fq 'verdict = "noPower"' "$SCORE"; then ok "scorer retains the power floor"
  else bad "scorer lost its power floor"; fi
fi

# ---- T3 parser controls ----------------------------------------------------
if node bench/trap-parse-controls.js >/tmp/trap_parse.log 2>&1; then
  ok "parser controls pass ($(grep -c '^  ok' /tmp/trap_parse.log) cases)"
else
  bad "parser controls FAIL -- see /tmp/trap_parse.log"
  sed -n 's/^  FAIL/    /p' /tmp/trap_parse.log | head -5
fi

# ---- T4 scorer controls ----------------------------------------------------
if [ -f bench/trap-score-controls.js ]; then
  if node bench/trap-score-controls.js >/tmp/trap_ctl.log 2>&1; then
    ok "scorer controls pass"
  else
    bad "scorer controls FAIL -- see /tmp/trap_ctl.log"
  fi
else
  bad "bench/trap-score-controls.js is missing -- the scorer has no negative control"
fi

# ---- T5 the corpus is still all traps --------------------------------------
if [ ! -f "$CAND" ]; then
  bad "$CAND is missing"
else
  _n=$(grep -c . "$CAND")
  _bad=$(node -e '
    const fs=require("fs");
    let bad=0;
    for (const l of fs.readFileSync(process.argv[1],"utf8").trim().split("\n")) {
      const i=JSON.parse(l);
      if (i.naive === i.truth) bad++;
    }
    process.stdout.write(String(bad));
  ' "$CAND" 2>/dev/null)
  if [ "${_bad:-x}" = "0" ]; then ok "all $_n corpus items are traps (naive != truth)"
  else bad "$_bad corpus items have naive == truth -- they give the naive method a free pass"; fi
fi

# ---- T6 the recorded latency result is ORDER-CONTROLLED --------------------
if [ ! -f "$LAT" ]; then
  bad "$LAT is missing -- no order-controlled latency artifact on disk"
else
  _unctl=$(node -e 'process.stdout.write(String(require(process.argv[1]).orderConfoundUncontrolled))' "$PWD/$LAT" 2>/dev/null)
  _attr=$(node -e 'process.stdout.write(String(require(process.argv[1]).attribution))' "$PWD/$LAT" 2>/dev/null)
  if [ "$_unctl" = "false" ]; then ok "latency artifact is order-controlled (both orderings present)"
  else bad "latency artifact is NOT order-controlled (orderConfoundUncontrolled=$_unctl) -- the speedup cannot be attributed"; fi
  if [ "$_attr" = "router" ]; then ok "latency attribution is 'router', from two orderings"
  else bad "latency attribution is '$_attr', not 'router'"; fi
  _rev=$(node -e 'const j=require(process.argv[1]);process.stdout.write(j.reversed?"yes":"no")' "$PWD/$LAT" 2>/dev/null)
  if [ "$_rev" = "yes" ]; then ok "the b-first control run is present in the artifact"
  else bad "no reversed ordering in the artifact -- the control was not run"; fi
fi

# ---- T7 the recorded accuracy verdicts are the reported ones ---------------
for pair in "$R1:disadvantage" "$R2:noPower"; do
  f="${pair%%:*}"; want="${pair##*:}"
  if [ ! -f "$f" ]; then
    bad "$f is missing"
  else
    got=$(node -e 'process.stdout.write(String(require(process.argv[1]).verdict))' "$PWD/$f" 2>/dev/null)
    if [ "$got" = "$want" ]; then ok "$(basename "$f") verdict is '$want' as reported"
    else bad "$(basename "$f") verdict is '$got', but '$want' is what was reported"; fi
  fi
done

echo
echo "  $passed passed, $failed failed"
if [ "$((passed + failed))" -eq 0 ]; then
  echo "  trap: FAIL -- ZERO checks ran, which is a truncated gate, not a clean one"
  exit 1
fi
if [ "$failed" -eq 0 ]; then echo "  trap: PASS"; exit 0; fi
echo "  trap: FAIL"
exit 1
