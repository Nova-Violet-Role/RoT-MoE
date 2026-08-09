#!/usr/bin/env node
// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// PAIRED LATENCY AND REASONING-VOLUME COMPARISON OVER THE TRAP CORPUS.
//
// bench/trap-score.js answers "which arm is RIGHT more often". This answers a
// different and independent question: "at what COST". They are kept apart on
// purpose -- an arm that is faster and wrong is not better, and collapsing the
// two into one score is how a speed win gets sold as a quality win.
//
// Paired by item: both arms saw the same prompt, so the sign test over
// per-item deltas needs no distributional assumption.
//
// THE ORDER CONFOUND IS THE WHOLE DIFFICULTY. The arms run sequentially against
// the same files, so whichever runs SECOND reads from a warm OS page cache. A
// large wall-clock gap is exactly what ordering produces, which is why this
// script reports `orderConfoundUncontrolled: true` unless it is given both
// orderings. It refuses to emit a verdict from one ordering alone -- the number
// is real, the attribution is not.
//
// Usage:
//   node bench/trap-latency.js <candidates.jsonl> <armA_dir> <armB_dir> [<revA_dir> <revB_dir>]
//     armA_dir/armB_dir  the a-first ordering
//     revA_dir/revB_dir  optional, the b-first ordering (the control)
// =============================================================================

const fs = require("fs");
const path = require("path");

const [, , CAND, DIR_A, DIR_B, REV_A, REV_B] = process.argv;
if (!CAND || !DIR_A || !DIR_B) {
  console.error("usage: trap-latency.js <candidates.jsonl> <armA_dir> <armB_dir> [<revA_dir> <revB_dir>]");
  process.exit(2);
}

const items = fs.readFileSync(CAND, "utf8").trim().split("\n").map((l) => JSON.parse(l));

function load(dir, id) {
  const p = path.join(dir, "turn-" + String(id).padStart(3, "0") + ".json");
  if (!fs.existsSync(p)) return null;
  try { return JSON.parse(fs.readFileSync(p, "utf8")); } catch (e) { return null; }
}

function lchoose(n, k) { let s = 0; for (let i = 1; i <= k; i++) s += Math.log(n - k + i) - Math.log(i); return s; }
function binomTwoSided(k, n) {
  if (n === 0) return 1;
  const pk = (i) => Math.exp(lchoose(n, i) - n * Math.log(2));
  const t = pk(k) * (1 + 1e-9);
  let p = 0;
  for (let i = 0; i <= n; i++) if (pk(i) <= t) p += pk(i);
  return Math.min(1, p);
}
const med = (xs) => {
  if (!xs.length) return 0;
  const s = [...xs].sort((x, y) => x - y);
  return s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2;
};

function compare(dirA, dirB, label) {
  let bFaster = 0, aFaster = 0, sumA = 0, sumB = 0, pairs = 0, missing = 0;
  const fam = {};
  for (const it of items) {
    const ja = load(dirA, it.id), jb = load(dirB, it.id);
    if (!ja || !jb) { missing++; continue; }
    pairs++;
    sumA += ja.duration_ms; sumB += jb.duration_ms;
    if (jb.duration_ms < ja.duration_ms) bFaster++; else if (ja.duration_ms < jb.duration_ms) aFaster++;
    const f = (fam[it.family] = fam[it.family] || { n: 0, bFaster: 0, a: [], b: [], aOut: [], bOut: [] });
    f.n++; if (jb.duration_ms < ja.duration_ms) f.bFaster++;
    f.a.push(ja.duration_ms); f.b.push(jb.duration_ms);
    f.aOut.push((ja.usage && ja.usage.output_tokens) || 0);
    f.bOut.push((jb.usage && jb.usage.output_tokens) || 0);
  }
  const byFamily = {};
  for (const [k, f] of Object.entries(fam)) {
    byFamily[k] = {
      n: f.n, routedFaster: f.bFaster,
      medianMsUnrouted: med(f.a), medianMsRouted: med(f.b),
      medianOutTokUnrouted: med(f.aOut), medianOutTokRouted: med(f.bOut),
    };
  }
  return {
    label, pairs, missing,
    routedFaster: bFaster, unroutedFaster: aFaster,
    signTestP: binomTwoSided(Math.min(bFaster, aFaster), bFaster + aFaster),
    totalMsUnrouted: sumA, totalMsRouted: sumB,
    routedSpeedupPct: sumA > 0 ? Number((((sumA - sumB) / sumA) * 100).toFixed(1)) : 0,
    byFamily,
  };
}

const out = { primary: compare(DIR_A, DIR_B, "a-first (arm a ran first, arm b second)") };

if (REV_A && REV_B) {
  out.reversed = compare(REV_A, REV_B, "b-first (arm b ran first, arm a second)");
  // The control's logic, stated so it cannot be reinterpreted later:
  //   if the ROUTED arm is faster in BOTH orderings, ordering is excluded
  //   if the SECOND-RUN arm is faster in both, the effect follows run order
  const p = out.primary, r = out.reversed;
  const routedWinsBoth = p.routedFaster > p.unroutedFaster && r.routedFaster > r.unroutedFaster;
  const secondWinsBoth = p.routedFaster > p.unroutedFaster && r.unroutedFaster > r.routedFaster;
  out.orderConfoundUncontrolled = false;
  out.attribution = routedWinsBoth ? "router"
    : secondWinsBoth ? "run-order (page cache) -- the latency claim is VOID"
    : "mixed -- neither attribution is supported";
} else {
  // One ordering cannot separate "the router is faster" from "the second run is
  // faster". Saying so is the whole point; a single-ordering number that gets
  // reported as a router property is the defect this flag exists to prevent.
  out.orderConfoundUncontrolled = true;
  out.attribution = "UNATTRIBUTED -- only one ordering was measured; run the b-first control";
}

console.log(JSON.stringify(out, null, 2));
