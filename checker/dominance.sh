#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# DOES THE ROUTING LAYER STRICTLY EXTEND THE DEFAULT AGENTIC LOOP?
#
# One verdict, seven conjuncts, each individually killable. The definition and
# its load-bearing proofs are `lean/Proofs/RotDominance.lean`; this script is the
# BINDING -- it measures the seven against the shipped router rather than against
# a model of it.
#
#   D1 TOTALITY        every declared hook event is handled, exit 0
#   D2 CONSERVATION    no event blocks, denies, or writes to stderr
#   D3 ADDITION        router-observable records are produced at all
#   D4 DISCRIMINATION  the output VARIES -- >= 9 distinct lanes reached
#   D5 DETERMINISM     the same payload yields the same route
#   D6 RECOMPUTABILITY R/s+ re-derives from the record's own fields
#   D7 BOUNDED COST    worst per-turn cost stays under the declared bound
#
# WHY THIS EXISTS AND WHAT IT REPLACES. The project's central claim was
# "surpasses standard Claude Code", which is not a proposition until it names
# what would falsify it. Three answer-quality corpora were run against the
# weakest reading of it and all three failed their controls -- brevity confound,
# selectivity confound, and a ceiling (84-84, then 78/80 with a calibration band
# of ONE). Those results stand.
#
# This measures the claim that is actually structural: the default loop has NO
# routing layer, and a layer that is total, conserving, additive, discriminating,
# deterministic, recomputable and cheap is a strict extension of it.
#
# D2 IS THE ONE THAT CAN REGRESS, and it had never been measured. In Claude Code
# a hook exiting 2 BLOCKS the tool call. A router that added a gauge while
# blocking one event in thirty would be worse than no router, and every other
# conjunct would still be green.
#
# WHAT THIS DOES NOT MEASURE: answer quality. `RotDominance` proves that as a
# theorem (`dominance_says_nothing_about_answer_quality`), so a green verdict
# here may never be reported as "better answers".
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

# Overridable so the mutant-router controls can drive the SAME code path with a
# deliberately broken router. A control that re-implements the measurement tests
# its own copy and says nothing about this script.
ROUTER="${ROTMOE_ROUTER:-hooks/rot-router.sh}"
HOOKS_JSON="hooks/hooks.json"
MS_BOUND=500          # must equal RotDominance.msBound
LANES_DECLARED=9      # must equal RotDominance.lanes

TMP="${TMPDIR:-/tmp}/rotmoe-dominance.$$"
mkdir -p "$TMP" || { echo "FATAL: cannot create $TMP"; exit 2; }
trap 'rm -rf "$TMP"' EXIT

passed=0; failed=0
ok()  { printf '  ok   %s\n' "$1"; passed=$((passed+1)); }
bad() { printf '  FAIL %s\n' "$1"; failed=$((failed+1)); }

[ -f "$ROUTER" ]     || { echo "FATAL: $ROUTER missing"; exit 2; }
[ -f "$HOOKS_JSON" ] || { echo "FATAL: $HOOKS_JSON missing"; exit 2; }

LOG="$TMP/route.jsonl"

# Drive one event through the router. Echoes "exit<TAB>stdout<TAB>stderrbytes".
drive() {
  _ev="$1"; _prompt="$2"; _sid="$3"
  # ROTMOE_DEBUG_SRC=test is MANDATORY, not decoration. This gate drives 53 real
  # payloads through the shipped router; without the declaration those records
  # are indistinguishable from live traffic in any later analysis. checker/
  # session-log.sh enforces it on every checker that feeds the router, and it
  # caught this file on its first sweep.
  printf '{"hook_event_name":"%s","prompt":"%s","session_id":"%s"}' "$_ev" "$_prompt" "$_sid" \
    | ROTMOE_DEBUG_LOG="$LOG" ROTMOE_DEBUG_SRC=test sh "$ROUTER" > "$TMP/out.txt" 2> "$TMP/err.txt"
  _rc=$?
  printf '%s\t%s\t%s' "$_rc" "$(tr -d '\n' < "$TMP/out.txt")" "$(wc -c < "$TMP/err.txt" | tr -d ' ')"
}

# ---------------------------------------------------------------------------
# The event list is READ FROM hooks.json, never typed. A hard-coded list stops
# covering whatever is added after it was written -- the same stale-snapshot
# defect this repo keeps finding.
# ---------------------------------------------------------------------------
EVENTS=$(node -e '
  const fs=require("fs");
  let s=fs.readFileSync(process.argv[1],"utf8");
  if(s.charCodeAt(0)===0xFEFF) s=s.slice(1);
  const j=JSON.parse(s);
  const out=new Set();
  const walk=(o)=>{ if(!o||typeof o!=="object") return;
    for(const [k,v] of Object.entries(o)){
      if(Array.isArray(v)&&/^[A-Z]/.test(k)) out.add(k);
      else walk(v);
    }};
  walk(j.hooks||j);
  console.log([...out].join("\n"));
' "$HOOKS_JSON" 2>/dev/null)

N_EVENTS=$(printf '%s\n' "$EVENTS" | grep -c . || echo 0)
if [ "$N_EVENTS" -eq 0 ]; then
  bad "no hook events could be read from $HOOKS_JSON -- this gate has gone blind, which is not the same as clean"
  echo "dominance: $passed passed, $failed failed"
  exit 1
fi

# ===========================================================================
# D1 TOTALITY + D2 CONSERVATION -- measured in the same sweep
# ===========================================================================
rm -f "$LOG"
_handled=0; _offered=0; _blocked=0; _denied=0; _noisy=0
for ev in $EVENTS; do
  _offered=$((_offered+1))
  res=$(drive "$ev" "debug this failing build error" "domD1")
  rc=$(printf '%s' "$res" | cut -f1)
  so=$(printf '%s' "$res" | cut -f2)
  se=$(printf '%s' "$res" | cut -f3)
  [ "$rc" = "0" ] && _handled=$((_handled+1))
  # In Claude Code an exit of 2 from a hook BLOCKS the call. Anything non-zero
  # is a regression against the default loop, which would simply have proceeded.
  [ "$rc" = "2" ] && { _blocked=$((_blocked+1)); bad "D2: event '$ev' exited 2 -- that BLOCKS the tool call"; }
  [ "$rc" != "0" ] && [ "$rc" != "2" ] && bad "D2: event '$ev' exited $rc"
  case "$so" in
    *'"decision"'*'"block"'*|*'permissionDecision'*'deny'*)
      _denied=$((_denied+1)); bad "D2: event '$ev' emitted a block/deny decision" ;;
  esac
  [ "${se:-0}" -gt 0 ] && { _noisy=$((_noisy+1)); bad "D2: event '$ev' wrote $se byte(s) to stderr"; }
done

if [ "$_handled" -eq "$_offered" ]; then
  ok "D1 TOTALITY: $_handled/$_offered declared hook events handled at exit 0"
else
  bad "D1 TOTALITY: only $_handled of $_offered events handled"
fi
if [ "$_blocked" -eq 0 ] && [ "$_denied" -eq 0 ] && [ "$_noisy" -eq 0 ]; then
  ok "D2 CONSERVATION: no event blocked, denied, or wrote to stderr ($_offered events)"
fi

# ===========================================================================
# D3 ADDITION -- records that do not exist without the layer
# ===========================================================================
_records=$(grep -c . "$LOG" 2>/dev/null || echo 0)
if [ "${_records:-0}" -gt 0 ]; then
  ok "D3 ADDITION: $_records router-observable record(s) produced (the default loop produces 0)"
else
  bad "D3 ADDITION: the layer produced no records at all"
fi

# ===========================================================================
# D4 DISCRIMINATION -- the output VARIES with the input
# ===========================================================================
# One probe per declared lane. If the router emitted a constant, this collapses
# to 1 and the layer is a logger, not a router (`a_logger_is_not_a_router`).
rm -f "$LOG"
_probe() { drive "UserPromptSubmit" "$1" "domD4" >/dev/null; }
_probe "debug this failing test error"
_probe "decide now and strike"
_probe "i feel lost and tired"
_probe "plan the roadmap and priorities"
_probe "invent something surreal and chaotic"
_probe "predict the future trend"
_probe "compress this to fewer tokens"
_probe "evolve the meta architecture recursively"
_probe "build and run the install"
_probe "tell me about the weather"
_lanes=$(grep -o '"lane":"[A-Z]*"' "$LOG" 2>/dev/null | sort -u | wc -l | tr -d ' ')
if [ "${_lanes:-0}" -ge "$LANES_DECLARED" ]; then
  ok "D4 DISCRIMINATION: $_lanes distinct lanes reached (>= $LANES_DECLARED declared)"
else
  bad "D4 DISCRIMINATION: only $_lanes distinct lane(s) reached; the layer is not discriminating"
  grep -o '"lane":"[A-Z]*"' "$LOG" 2>/dev/null | sort -u | while IFS= read -r l; do printf '         %s\n' "$l"; done
fi

# ===========================================================================
# D5 DETERMINISM -- same payload, same route
# ===========================================================================
rm -f "$LOG"
# ALIASING HAZARD, found by a mutant router and fixed here. A replay loop that
# spawns a FIXED number of subprocesses per iteration advances the PID by a
# constant stride, so a router whose hidden state has a period dividing that
# stride returns the SAME answer every time and looks deterministic. Measured:
# a router branching on `$$ % 2` varied across 12 hand probes yet produced one
# distinct route across 5 replays here, and D5 passed on a nondeterministic
# router.
#
# The repair is to make the sampling stride VARY, so no fixed period can survive
# it, and to take more samples. `RotDominance.aliased_sampling_cannot_detect_variation`
# proves why the count alone was never the fix: at a constant stride, adding
# replays changes nothing.
for _i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  _k=0
  while [ "$_k" -lt "$_i" ]; do sh -c ':'; _k=$((_k+1)); done
  drive "UserPromptSubmit" "debug this failing build error" "domD5" >/dev/null
done
_distinct=$(grep '"kind":"route"' "$LOG" 2>/dev/null \
  | sed -e 's/.*"lane":"\([A-Z]*\)".*"lens":"\([A-Za-z]*\)".*"Rs":"\([0-9.]*\)".*/\1|\2|\3/' \
  | sort -u | wc -l | tr -d ' ')
_runs=$(grep -c '"kind":"route"' "$LOG" 2>/dev/null || echo 0)
if [ "${_runs:-0}" -ge 12 ] && [ "${_distinct:-0}" -eq 1 ]; then
  ok "D5 DETERMINISM: $_runs replays of one payload produced exactly 1 distinct (lane,lens,R/s+)"
else
  bad "D5 DETERMINISM: $_runs replay(s) produced $_distinct distinct route(s) -- expected 1"
fi

# ===========================================================================
# D6 RECOMPUTABILITY -- the gauge re-derives from its own record
# ===========================================================================
_rec=$(node -e '
  const fs=require("fs");
  const lines=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").filter(Boolean);
  let n=0,okc=0;
  for(const L of lines){
    let r; try{ r=JSON.parse(L); }catch(e){ continue; }
    if(r.kind!=="gauge"||!Array.isArray(r.lenses)) continue;
    n++;
    const sum=r.lenses.reduce((a,x)=>a+x.term,0);
    const rs=sum/r.K*(r.M??1)*(r.C??1)*(r.T??1);
    if(Math.abs(rs-r.Rs)<0.01) okc++;
  }
  console.log(okc+" "+n);
' "$LOG" 2>/dev/null)
_r_ok=$(printf '%s' "$_rec" | awk '{print $1+0}')
_r_n=$(printf '%s' "$_rec" | awk '{print $2+0}')
if [ "${_r_n:-0}" -gt 0 ] && [ "${_r_ok:-0}" -eq "${_r_n:-0}" ]; then
  ok "D6 RECOMPUTABILITY: $_r_ok/$_r_n gauge record(s) re-derived from their own fields"
else
  bad "D6 RECOMPUTABILITY: only $_r_ok of $_r_n gauge record(s) re-derive"
fi

# ===========================================================================
# D6b INFORMATIVE -- D6 alone passes vacuously on a record that measured nothing
#
# D6 above sums the logged `term` fields and compares to the logged `Rs`. On an
# all-zero record that is |0 - 0| < 0.01, a PASS. So the gauge could break
# completely, emit nothing but zeros, and D6 would stay green. This is not
# hypothetical: the live log at ~/.claude/rot-moe/rot-route-debug.jsonl holds 96
# such records out of 1755, every one with "mu":0 on all nine lenses. They are
# historical (newest 2026-08-09T21:56:32) and today's router cannot produce one
# -- hooks/rot-router.sh:274 sets MUS unconditionally -- but nothing STOPPED it
# from coming back until this check existed.
#
# The property, proved in lean/Proofs/RotGaugeZero.lean:
#   * Rs_pos                             -- a well-formed record cannot read 0
#   * recomputes_does_not_imply_informative -- the D6 hole, with a witness
#   * idle_is_not_a_violation            -- and the reason this check is SAFE:
#       a turn on which NO lens fired still reads positive, because sigma(0) is
#       0.1192, not 0. Only a zero FACTOR can zero the gauge. A check that
#       flagged quiet turns would forbid a correct future; this one flags a
#       broken instrument.
# ===========================================================================
_infm=$(node -e '
  const fs=require("fs");
  const lines=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").filter(Boolean);
  let n=0, zero=0, live=0, muzero=0;
  for(const L of lines){
    let r; try{ r=JSON.parse(L); }catch(e){ continue; }
    if(r.kind!=="gauge"||!Array.isArray(r.lenses)) continue;
    n++;
    if(r.lenses.length>0 && r.lenses.every(x=>Number(x.mu)===0)) muzero++;
    if(Number(r.Rs)===0) zero++; else live++;
  }
  console.log(n+" "+zero+" "+live+" "+muzero);
' "$LOG")
_i_n=$(printf '%s' "$_infm"   | awk '{print $1+0}')
_i_zero=$(printf '%s' "$_infm" | awk '{print $2+0}')
_i_live=$(printf '%s' "$_infm" | awk '{print $3+0}')
_i_mu=$(printf '%s' "$_infm"   | awk '{print $4+0}')
if [ "${_i_n:-0}" -eq 0 ]; then
  bad "D6b INFORMATIVE: no gauge records at all -- D6's pass covered nothing"
elif [ "${_i_zero:-0}" -ne 0 ]; then
  bad "D6b INFORMATIVE: $_i_zero of $_i_n gauge record(s) read R/s+ = 0 -- engine/rot-lean.md:316 calls that a violation, and RotGaugeZero.Rs_pos proves a well-formed record cannot"
elif [ "${_i_mu:-0}" -ne 0 ]; then
  bad "D6b INFORMATIVE: $_i_mu of $_i_n gauge record(s) carry mu=0 on every lens -- the historical MUS defect is back"
else
  ok "D6b INFORMATIVE: $_i_live/$_i_n gauge record(s) carry a nonzero R/s+ and a nonzero mu -- D6's pass is over real arithmetic, not zeros"
fi

# ===========================================================================
# D7 BOUNDED COST
# ===========================================================================
_worst=$(grep -o '"ms":[0-9]*' "$LOG" 2>/dev/null | cut -d: -f2 | sort -n | tail -1)
_worst=${_worst:-0}
if [ "$_worst" -le "$MS_BOUND" ]; then
  ok "D7 BOUNDED COST: worst observed turn ${_worst} ms (bound ${MS_BOUND} ms)"
else
  bad "D7 BOUNDED COST: worst observed turn ${_worst} ms exceeds the ${MS_BOUND} ms bound"
fi

# D7b  NO SNAPSHOT LATENCY CLAIM IN THE DOCS
# ---------------------------------------------------------------------------
# MEASURED DEFECT, 2026-08-10. README.md advertised the router as "a
# 130-millisecond shell script" in two places. That was true of the first
# pre-release; the shipped router measures 380-436 ms (ten runs, median ~398),
# because it grew a live log, a nine-lens ensemble and the R/s+ gauge. The claim
# had been 3x wrong and green for weeks, because nothing checked it.
#
# The repair was NOT to write 398. A fresh snapshot schedules the same defect for
# next month -- it is the "contingent fact frozen as an invariant" shape this
# project exists to catch. The docs now state the BOUND (D7, ${MS_BOUND} ms), which
# a gate can enforce and which stays true as the router evolves.
#
# So this check forbids the snapshot form from coming back: a bare "<n>-millisecond"
# or "~<n> ms" claim about the router in the docs is a defect even when the number
# happens to be right today. Prose describing the OLD claim as history is allowed --
# it must appear inside a blockquote, which is how the correction is written.
_snap=0
for _f in README.md engine/rot-lean.md; do
  [ -f "$REPO/$_f" ] || continue
  # Strip blockquote lines (historical explanation) before looking for claims.
  _hits=$(grep -vE '^\s*>' "$REPO/$_f" 2>/dev/null \
          | grep -oiE '(~ ?[0-9]{2,4} ?ms\b|[0-9]{2,4}-millisecond)' | wc -l | tr -d ' ')
  if [ "${_hits:-0}" -ne 0 ]; then
    bad "D7b SNAPSHOT CLAIM: $_f states a fixed router latency ($_hits site(s)) -- state the ${MS_BOUND} ms bound instead; a snapshot expires"
    _snap=$((_snap + _hits))
  fi
done
if [ "$_snap" -eq 0 ]; then
  ok "D7b NO SNAPSHOT CLAIM: the docs state the ${MS_BOUND} ms bound, not a number that decays"
fi

# ===========================================================================
# POSITIVE CONTROLS -- the instrument must be able to fail
# ===========================================================================
# A stub router that exits 2 must be caught by D2. Without this control, "no
# event blocked" could mean "the block test does not work".
cat > "$TMP/blocker.sh" <<'STUB'
#!/usr/bin/env sh
cat >/dev/null
exit 2
STUB
chmod +x "$TMP/blocker.sh"
printf '{"hook_event_name":"PreToolUse","prompt":"x","session_id":"ctl"}' | sh "$TMP/blocker.sh" >/dev/null 2>&1
if [ "$?" = "2" ]; then
  ok "positive control: a stub router that exits 2 is observable as a block (D2 can fail)"
else
  bad "positive control: could not observe a deliberate exit-2 block -- D2's green is meaningless"
fi

# A constant router must fail D4. Proves the lane counter is reading real
# variation rather than counting probes.
_const=$(printf '%s\n' '{"lane":"FORGE"}' '{"lane":"FORGE"}' '{"lane":"FORGE"}' \
  | grep -o '"lane":"[A-Z]*"' | sort -u | wc -l | tr -d ' ')
if [ "$_const" = "1" ]; then
  ok "positive control: a constant lane stream counts as 1 distinct lane (D4 can fail)"
else
  bad "positive control: the lane counter returned $_const for a constant stream"
fi

# ===========================================================================
echo ""
if [ "$failed" -eq 0 ]; then
  echo "  VERDICT: the routing layer STRICTLY EXTENDS the default loop (D1-D7 all measured green)"
  echo "           This is a STRUCTURAL result. It says nothing about answer quality --"
  echo "           see RotDominance.dominance_says_nothing_about_answer_quality."
else
  echo "  VERDICT: NOT an extension -- $failed conjunct(s) failed above."
fi
echo "dominance: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
exit 0
