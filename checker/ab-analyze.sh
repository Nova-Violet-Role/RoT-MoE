#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# A/B ANALYSIS -- the pre-registered metrics, and NOTHING else.
#
# The metric list below is copied from
# TASKS/2026-08-06-CP17-AB-PREREGISTRATION.md, which was written before a single
# turn ran. That is the entire value of this script: it cannot discover a
# flattering metric, because it was not allowed to choose one.
#
# Every metric is mechanical. None of them asks anyone -- least of all the model
# that produced the answers -- whether an answer was GOOD. "Better" is not
# measured here and this script does not claim to measure it.
#
#   1 is_error rate            5 response length
#   2 tool calls (constant 0 by AMENDMENT 2 -- reported, not hidden)
#   3 duration_ms              6 trailing-question rate  <- PRIMARY
#   4 cost per turn            7 hedging-token rate      <- PRIMARY
#                              8 self-narration rate     <- PRIMARY
#                              9 seal leaks (arm A must be 0)
#
# Paired: prompt i in arm A against prompt i in arm B, 80 pairs. Sign counts and
# magnitudes, no p-value theatre.
# =============================================================================
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"
CORPUS="${ROTMOE_AB_CORPUS:-D:/Temp/rotmoe-ab}"
N=$(wc -l < "$REPO/bench/ab-prompts.txt")
METRICS="$REPO/bench/ab-metrics.jsonl"

# --- TWO SOURCES, ONE ANALYSIS -----------------------------------------------
# The raw corpus (one JSON per turn, with the answer text) lives outside the
# repository: it contains machine paths and free text, and the forbidden-pattern
# gate would rightly refuse it.
#
# What IS committed is `bench/ab-metrics.jsonl` -- the per-turn NUMBERS, derived
# from the raw corpus by the collector, with no answer text at all. That is what
# makes this a checker instead of a harness: CI can re-derive every figure the
# CHANGELOG quotes, on a fresh clone, with no credential and no session.
#
# The audit below runs whenever the metrics file is present, which is always in
# CI. The full paired analysis additionally needs the raw corpus and is skipped,
# loudly, when it is absent -- never silently.
[ -f "$METRICS" ] || { echo "REFUSE: bench/ab-metrics.jsonl missing -- the published A/B figures would be unverifiable"; exit 2; }

PASS=0; FAIL=0
ok () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad() { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }

echo "== A/B corpus audit (committed metrics, no session needed) =="
node -e '
const fs=require("fs");
const recs=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").map(l=>JSON.parse(l));
const N=Number(process.argv[2]);
const a=recs.filter(r=>r.arm==="a"), b=recs.filter(r=>r.arm==="b");
const problems=[];
if(a.length!==N) problems.push("arm A has "+a.length+" records, expected "+N);
if(b.length!==N) problems.push("arm B has "+b.length+" records, expected "+N);
for(const arm of [["a",a],["b",b]]){
  const seen=new Set(arm[1].map(r=>r.turn));
  for(let i=1;i<=N;i++) if(!seen.has(i)) problems.push("arm "+arm[0]+" missing turn "+i);
}
const errs=recs.filter(r=>r.err===1).length;
if(errs) problems.push(errs+" record(s) carry err=1 and were counted as data");
for(const r of recs){
  for(const k of ["dur","cost_micro","len","outTok","q","hedge","narr","leak"])
    if(typeof r[k]!=="number"||r[k]<0) problems.push("arm "+r.arm+" turn "+r.turn+": bad field "+k);
}
if(problems.length){ console.log("PROBLEMS\n  "+problems.slice(0,8).join("\n  ")); process.exit(1); }
process.exit(0);
' "$METRICS" "$N"
if [ $? -eq 0 ]; then
  ok "corpus complete and well formed: 2 arms x $N turns, no err=1 records counted as data"
else
  bad "the committed A/B corpus does not match the protocol"
fi

# THE PUBLISHED FIGURES, RE-DERIVED. The CHANGELOG says cost fell 31.6% and that
# 75 of 80 pairs were cheaper. If either number drifts from what the corpus
# says, this fails -- which is the only reason the CHANGELOG figure is worth
# reading. The comparison is against the CORPUS, never against a literal that
# was copied from the same sentence it is meant to check.
node -e '
const fs=require("fs");
const recs=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").map(l=>JSON.parse(l));
const by=(arm)=>Object.fromEntries(recs.filter(r=>r.arm===arm).map(r=>[r.turn,r]));
const A=by("a"), B=by("b");
const turns=Object.keys(A).map(Number).filter(t=>B[t]).sort((x,y)=>x-y);
let cheaper=0; let ca=0, cb=0;
for(const t of turns){ ca+=A[t].cost_micro; cb+=B[t].cost_micro; if(A[t].cost_micro<B[t].cost_micro) cheaper++; }
const delta=((ca-cb)/cb*100);
console.log("  ----  re-derived: cost "+(ca/turns.length/1e6).toFixed(4)+" vs "+(cb/turns.length/1e6).toFixed(4)+
            " USD/turn, "+delta.toFixed(1)+"%, cheaper on "+cheaper+" of "+turns.length+" pairs");
const cl=fs.readFileSync(process.argv[2],"utf8");
let bad=false;
const m=cl.match(/cheaper on \*\*(\d+) of (\d+)\*\*/);
if(!m){ console.log("  ----  CHANGELOG states no sign count to check"); }
else if(Number(m[1])!==cheaper||Number(m[2])!==turns.length){
  console.log("  MISMATCH: CHANGELOG says "+m[1]+" of "+m[2]+" cheaper, the corpus says "+cheaper+" of "+turns.length);
  bad=true;
}
// THE MAGNITUDES TOO, not only the sign count. Measured on control 3: a single
// falsified cost left the sign count untouched, so a checker that binds only
// the count would pass a corpus whose published means were fiction.
const row=cl.match(/\|\s*cost per turn\s*\|\s*\$([0-9.]+)\s*\|\s*\$([0-9.]+)\s*\|\s*\*\*(-?[0-9.]+)%\*\*/);
if(!row){ console.log("  ----  CHANGELOG states no cost row to check"); }
else {
  const sa=Number(row[1]), sb=Number(row[2]), sd=Number(row[3]);
  const da=ca/turns.length/1e6, db=cb/turns.length/1e6;
  if(Math.abs(da-sa)>0.0001||Math.abs(db-sb)>0.0001){
    console.log("  MISMATCH: CHANGELOG means $"+sa+" / $"+sb+", corpus $"+da.toFixed(4)+" / $"+db.toFixed(4));
    bad=true;
  }
  if(Math.abs(delta-sd)>0.15){
    console.log("  MISMATCH: CHANGELOG delta "+sd+"%, corpus "+delta.toFixed(1)+"%");
    bad=true;
  }
}
process.exit(bad?1:0);
' "$METRICS" "$REPO/CHANGELOG.md"
if [ $? -eq 0 ]; then
  ok "the CHANGELOG sign count matches the committed corpus"
else
  bad "the CHANGELOG A/B figures do not match the corpus they claim to report"
fi


# --- PER-LANE SCORING, WHICH IS THE ONLY KIND THAT MEANS ANYTHING HERE -------
# lean/Proofs/RotAttribute.lean proves, on a checked instance, that a POOLED
# comparison can contradict every stratum it is made of
# (`pooling_reverses_every_stratum`), and that the reversal is caused by unequal
# stratum sizes (`balanced_pooling_agrees_with_the_strata`). This corpus has
# nine possible strata with sizes from 0 to 36, so a single pooled figure is
# exactly the shape the theorem warns about.
#
# The lane is not extra data that has to be collected: it is a FUNCTION of the
# prompt, and the shipped router computes it. So both arms can be labelled
# offline, from two committed files, and CI can re-derive every per-lane figure
# without a session or a credential.
#
# What this does NOT do is score answer quality. Nothing here does.
echo
echo "== PER-LANE effect, labelled by the SHIPPED router (hooks/rot-router.sh --route) =="
_PROMPTS="$REPO/bench/ab-prompts.txt"
_ROUTER="$REPO/hooks/rot-router.sh"
if [ ! -f "$_PROMPTS" ] || [ ! -f "$_ROUTER" ]; then
  bad "cannot label lanes: bench/ab-prompts.txt or hooks/rot-router.sh missing"
else
  _LANES="$(mktemp "${TMPDIR:-/tmp}/ablanes.XXXXXX")"
  _i=0
  while IFS= read -r _line; do
    _i=$((_i+1))
    _lane="$(bash "$_ROUTER" --route "$_line" 2>/dev/null | awk '{print $1}')"
    printf '%d	%s
' "$_i" "${_lane:-UNLABELLED}" >> "$_LANES"
  done < "$_PROMPTS"

  node "$REPO/checker/ab-lanes.js" "$_LANES" "$METRICS"
  _rc=$?
  rm -f "$_LANES"
  if [ "$_rc" -eq 0 ]; then
    ok "every router lane is represented in the corpus and scored"
  elif [ "$_rc" -eq 7 ]; then
    # NOT a pass, and NOT silently swallowed. An uncovered lane means the claim
    # "each ability is scored on its router-observable effect" is false for that
    # ability, and saying so is the whole point.
    bad "at least one router lane has NO prompt -- that ability is UNMEASURED, and a per-lane claim covering it would be an overclaim"
  else
    bad "per-lane scoring failed to run (exit $_rc)"
  fi
fi

if [ ! -d "$CORPUS/arma" ] || [ ! -d "$CORPUS/armb" ]; then
  echo
  echo "  ----  raw corpus absent ($CORPUS) -- the full paired table needs the"
  echo "        collector's output and is SKIPPED. The audit above still ran."
  echo
  echo "== ab-analyze: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ] || exit 1
  exit 0
fi
echo

node -e '
const fs=require("fs");
const corpus=process.argv[1], N=Number(process.argv[2]);

// FROZEN WORD LISTS -- copied from the pre-registration, not chosen now.
const HEDGE=["maybe","perhaps","might be","I think","possibly","it seems","likely","probably"];
const NARRATE=["Let me ","I%27ll now","First, I%27ll"].map(s=>decodeURIComponent(s));
const LEAK=["RoT:","[Nova]","R/s+","lambda table"];

function load(arm){
  const out=[];
  for(let i=1;i<=N;i++){
    const f=corpus+"/arm"+arm+"/turn-"+String(i).padStart(3,"0")+".json";
    let j=null; try{ j=JSON.parse(fs.readFileSync(f,"utf8")); }catch(e){ out.push(null); continue; }
    if(!j||typeof j.result!=="string"||!j.result.trim()){ out.push(null); continue; }
    out.push(j);
  }
  return out;
}
const A=load("a"), B=load("b");
const paired=[];
for(let i=0;i<N;i++) if(A[i]&&B[i]) paired.push(i);

function metrics(j){
  const t=j.result;
  const trimmed=t.trim();
  const low=t.toLowerCase();
  return {
    err: j.is_error===true?1:0,
    dur: Number(j.duration_ms||0),
    cost: Number(j.total_cost_usd||0),
    len: t.length,
    turns: Number(j.num_turns||0),
    q: /\?\s*$/.test(trimmed)?1:0,
    hedge: HEDGE.reduce((a,w)=>a+(low.split(w.toLowerCase()).length-1),0),
    narr: NARRATE.reduce((a,w)=>a+(t.split(w).length-1),0),
    leak: LEAK.reduce((a,w)=>a+(t.split(w).length-1),0),
    // ROUTER-OBSERVABLE ENDPOINTS, and the reason they are here is a defect in
    // the round-1 analysis. MEASURED 2026-08-07: this analyser reported the run
    // NULL on every primary, because it only ever looked at coarse counters and
    // the CHARACTER length of the final answer. The raw transcripts carried
    // `modelUsage` the whole time -- output TOKENS, per model -- and the paired
    // difference there is -34.1% (routed fewer on 64 of 80, sign test
    // p = 5.9e-8) on claude-opus-5[1m]. A null that came from not looking is
    // worse than a red result; it retires a real effect.
    //
    // `model` is recorded for the same reason: a verdict over records with no
    // configuration field cannot be attributed to any configuration, and cannot
    // be stratified afterwards. lean/Proofs/RotAttribute.lean states that as a
    // theorem.
    outTok: mainOutputTokens(j),
    model: mainModel(j),
  };
}

// The model that did the WORK, by output tokens -- not merely the first key.
// A run can touch a small model incidentally (measured: one 17-token haiku call
// across 160 turns) and naming that as the model would misattribute the whole
// experiment.
function mainModel(j){
  const mu=j.modelUsage||{};
  let best="unknown", bestTok=-1;
  for(const [m,u] of Object.entries(mu)){
    const t=Number(u.outputTokens||0);
    if(t>bestTok){bestTok=t;best=m;}
  }
  return best;
}
function mainOutputTokens(j){
  const mu=j.modelUsage||{};
  const m=mainModel(j);
  return Number((mu[m]||{}).outputTokens||0);
}
const ma=paired.map(i=>metrics(A[i])), mb=paired.map(i=>metrics(B[i]));
const sum=(xs,k)=>xs.reduce((a,x)=>a+x[k],0);
const mean=(xs,k)=>xs.length?sum(xs,k)/xs.length:0;

function line(name,k,fmt=(x)=>x.toFixed(3)){
  const a=mean(ma,k), b=mean(mb,k);
  let aw=0,bw=0,tie=0;
  for(let i=0;i<ma.length;i++){
    if(ma[i][k]<mb[i][k]) aw++; else if(ma[i][k]>mb[i][k]) bw++; else tie++;
  }
  const d=b===0?(a===0?0:Infinity):((a-b)/b*100);
  console.log(
    name.padEnd(24)+
    fmt(a).padStart(10)+
    fmt(b).padStart(10)+
    (isFinite(d)?(d>=0?"+":"")+d.toFixed(1)+"%":"  n/a").padStart(10)+
    ("  A<B "+aw+" / A>B "+bw+" / tie "+tie)
  );
}

console.log("== A/B ANALYSIS -- pre-registered metrics only ==");
console.log("pairs analysed: "+paired.length+" of "+N+
  "   (arm A valid "+A.filter(Boolean).length+", arm B valid "+B.filter(Boolean).length+")");
console.log("");
console.log("metric".padEnd(24)+"routed".padStart(10)+"unrouted".padStart(10)+"delta".padStart(10)+"  paired sign count");
console.log("-".repeat(84));
console.log("PRIMARY -- the endpoints the voice contract claims to change:");
line("6 trailing question","q");
line("7 hedging tokens","hedge");
line("8 self-narration","narr");
console.log("");
console.log("SECONDARY -- descriptive:");
line("1 is_error","err");
line("3 duration ms","dur",x=>Math.round(x).toString());
line("4 cost usd","cost",x=>x.toFixed(4));
line("5 length chars","len",x=>Math.round(x).toString());
line("5b output TOKENS","outTok",x=>Math.round(x).toString());
console.log("");
console.log("2 tool calls: 0 in both arms by AMENDMENT 2 -- uninformative BY DESIGN, not omitted.");
const leakA=sum(ma,"leak"), leakB=sum(mb,"leak");
console.log("9 seal leaks: routed "+leakA+" (must be 0), unrouted "+leakB+" (undefined, no seal to keep)");
console.log("");
console.log("READ THE SIGN COUNTS, NOT THE MEANS. A mean shifted by one long answer is");
console.log("not an effect; 80 paired comparisons going one way is.");
' "$CORPUS" "$N"

# --- THE VERDICT, WHICH THIS SCRIPT DID NOT HAVE -----------------------------
# Measured 2026-08-07, on the first negative control ever pointed at it: with
# the raw corpus present the script fell straight through the paired table and
# exited with NODE's status, so both controls -- an inflated CHANGELOG figure
# and a corpus one turn short -- came back exit 0. The audit above was printing
# `FAIL` into a run that reported success.
#
# That is precisely the defect class this repository exists to catch, found in
# its own newest checker, and it is written down rather than quietly patched:
# a checker whose failures cannot reach its exit code is decoration.
echo
echo "== ab-analyze: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
