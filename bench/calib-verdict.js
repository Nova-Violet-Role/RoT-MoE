// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// THE PAIRED VERDICT over the calibrated corpus.
//
//   node bench/calib-verdict.js <design.json> <routedScore.json> <unroutedScore.json>
//
// The verdict rules are NOT invented here. They mirror `lean/Proofs/RotCeiling.lean`
// line for line:
//
//   discordant c          = routedOnly + unroutedOnly
//   hasPower c            = 0 < discordant c
//   verdict c             = noPower           if !hasPower c
//                           advantage         if unroutedOnly < routedOnly
//                           null              otherwise
//
// THREE OUTCOMES, NOT TWO. `noPower` is not a null. The fact corpus scored 84-84
// with zero discordant pairs and was nearly written up as "no measurable
// difference"; `ceiling_is_not_a_null` is the theorem that forbids it. A run
// with no discordant pairs has measured NOTHING about the router.
//
// FRESHNESS IS ENFORCED, NOT ASSUMED. `selecting_on_the_test_result_also_biases`
// proves that grading the reps you selected on biases the comparison whichever
// arm they came from. This script refuses to run if either scored directory is
// one of the calibration directories recorded in the design.
// =============================================================================
const fs = require("fs");

const [designPath, routedPath, unroutedPath] = process.argv.slice(2);
if (!designPath || !routedPath || !unroutedPath) {
  console.error("usage: calib-verdict.js <design.json> <routedScore.json> <unroutedScore.json>");
  process.exit(2);
}
const design = JSON.parse(fs.readFileSync(designPath, "utf8"));
const routed = JSON.parse(fs.readFileSync(routedPath, "utf8"));
const unrouted = JSON.parse(fs.readFileSync(unroutedPath, "utf8"));

// --- the design must be sound (RotCalibration.sound) -------------------------
const problems = [];
if (!(design.calibReps >= 2)) problems.push(`calibReps = ${design.calibReps}, need >= 2`);
if (design.selectionUsedRoutedArm) problems.push("selection read the ROUTED arm");
const calibDirs = (design.calibrationReps || []).map(p => String(p));
const norm = s => String(s).replace(/\\/g, "/").toLowerCase();
for (const [label, s] of [["routed", routed], ["unrouted", unrouted]]) {
  for (const c of calibDirs) {
    // The calibration reps are score FILES; their `turns` field names the dir.
    let cdir = "";
    try { cdir = JSON.parse(fs.readFileSync(c, "utf8")).turns || ""; } catch (e) { cdir = c; }
    if (cdir && norm(cdir) === norm(s.turns)) {
      problems.push(`${label} arm was graded on a CALIBRATION directory (${s.turns}) -- reps are not fresh`);
    }
  }
}
if (problems.length) {
  console.error("FATAL: the design is UNSOUND. Refusing to produce a verdict:");
  for (const p of problems) console.error("   - " + p);
  console.error("See RotCalibration.sound / all_three_clauses_are_load_bearing.");
  process.exit(3);
}

// --- pair the items ----------------------------------------------------------
if (routed.n !== unrouted.n) {
  console.error(`FATAL: arms scored different corpora (${routed.n} vs ${unrouted.n}).`);
  process.exit(3);
}
const rm = new Map(routed.results.map(r => [r.id, r.correct]));
const um = new Map(unrouted.results.map(r => [r.id, r.correct]));
let routedOnly = 0, unroutedOnly = 0, bothRight = 0, bothWrong = 0, unpaired = 0;
for (const [id, rc] of rm) {
  if (!um.has(id)) { unpaired++; continue; }
  const uc = um.get(id);
  if (rc && uc) bothRight++;
  else if (rc && !uc) routedOnly++;
  else if (!rc && uc) unroutedOnly++;
  else bothWrong++;
}
if (unpaired > 0) {
  console.error(`FATAL: ${unpaired} item(s) present in one arm only. A paired test needs pairs.`);
  process.exit(3);
}

const discordant = routedOnly + unroutedOnly;
const hasPower = discordant > 0;
const verdict = !hasPower ? "noPower" : (unroutedOnly < routedOnly ? "advantage" : "null");

// Two-sided exact binomial on the discordant pairs (the sign test).
function choose(n, k) { let r = 1; for (let i = 1; i <= k; i++) r = r * (n - k + i) / i; return r; }
function signTestP(a, b) {
  const n = a + b;
  if (n === 0) return null;
  const k = Math.min(a, b);
  let tail = 0;
  for (let i = 0; i <= k; i++) tail += choose(n, i);
  return Math.min(1, 2 * tail / Math.pow(2, n));
}
const p = signTestP(routedOnly, unroutedOnly);

console.log("== calibrated corpus, paired verdict ==");
console.log(`  corpus              ${routed.n} item(s)   (pool ${design.candidatePool}, band ${design.selected})`);
console.log(`  routed accuracy     ${routed.correct}/${routed.n}  (${(100 * routed.correct / routed.n).toFixed(1)}%)  mean ${routed.meanChars} chars`);
console.log(`  unrouted accuracy   ${unrouted.correct}/${unrouted.n}  (${(100 * unrouted.correct / unrouted.n).toFixed(1)}%)  mean ${unrouted.meanChars} chars`);
console.log(`  bothRight ${bothRight}   routedOnly ${routedOnly}   unroutedOnly ${unroutedOnly}   bothWrong ${bothWrong}`);
console.log(`  discordant          ${discordant}`);
console.log(`  sign test p         ${p === null ? "n/a" : p.toExponential(3)}`);
console.log(`  VERDICT             ${verdict}`);
if (verdict === "noPower") {
  console.log("  noPower is NOT a null. Zero discordant pairs means this run measured");
  console.log("  nothing about the router (RotCeiling.ceiling_is_not_a_null).");
}
if (verdict === "advantage" && (p === null || p >= 0.05)) {
  console.log(`  NOTE: a majority without significance. p = ${p.toExponential(3)} >= 0.05, so this`);
  console.log("  is a direction, not a demonstrated advantage. Do not claim the Promise on it.");
}
// The brevity confound that sank metric one: report it every time, unasked.
const ratio = unrouted.meanChars ? routed.meanChars / unrouted.meanChars : 0;
console.log(`  length ratio        ${ratio.toFixed(2)}x (routed/unrouted)` +
            (ratio < 0.8 || ratio > 1.25 ? "   <-- CONFOUND: the arms differ in verbosity" : ""));
