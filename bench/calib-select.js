// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// SELECT THE CALIBRATED CORPUS -- the band filter, and the three refusals.
//
//   node bench/calib-select.js <candidatesJsonl> <outJsonl> <rep1.json> <rep2.json> ...
//
// Keeps exactly the items the UNROUTED arm answered correctly at least once and
// incorrectly at least once. `RotCalibration.lean` proves what that buys and
// what it does not:
//
//   band_excludes_both_saturations   an item at floor or ceiling is dropped
//   band_needs_two_reps              one rep can only produce 0 or 1, so a
//                                    one-rep calibration selects NOTHING
//   circular_selection_cannot_lose   select on the ROUTED arm and the routed
//                                    arm cannot lose a pair, for ANY input
//   calibration_does_not_guarantee_power   the anti-overclaim: a calibrated run
//                                    can still be noPower, and that is not a null
//
// THE THREE REFUSALS ARE THE POINT. This script exits non-zero rather than
// produce a corpus when the design is unsound, because an unsound corpus still
// produces a number and the number looks exactly like a result.
// =============================================================================
const fs = require("fs");

const args = process.argv.slice(2);
// NOTE the bound: `< 3`, not `< 4`. With `< 4` a run given exactly ONE rep hit
// this generic usage message and exited 2, so the dedicated one-rep refusal
// below -- the one that names `band_needs_two_reps` and exits 3 -- was
// unreachable. Found by tripping it on purpose. A refusal no input can reach is
// the same silent hole as a gate no commit can trigger.
if (args.length < 3) {
  console.error("usage: calib-select.js <candidatesJsonl> <outJsonl> <rep1.json> <rep2.json> [...]");
  console.error("at least TWO reps are required -- see band_needs_two_reps");
  process.exit(2);
}
const [candPath, outPath, ...repPaths] = args;

// --- REFUSAL 1: fewer than two reps ------------------------------------------
// With one rep every item scores 0 or 1 = floor or ceiling, so the band is
// empty and the harness would report "no difference" over an EMPTY corpus --
// the absence of its own input, dressed as a null. `one_rep_pool_calibrates_to_nothing`.
if (repPaths.length < 2) {
  console.error(`FATAL: ${repPaths.length} calibration rep(s). Need >= 2.`);
  console.error("With one rep the band is empty by construction (band_needs_two_reps).");
  process.exit(3);
}

// --- REFUSAL 2: any rep drawn from the routed arm ----------------------------
// Selecting on the arm under test cannot lose. This is not a heuristic: the
// filtered comparison has unroutedOnly = 0 for EVERY input
// (`circular_selection_cannot_lose`), so the "win" would be the filter's, not
// the router's.
const routed = repPaths.filter(p => /arma|routed|arm-a/i.test(p));
if (routed.length > 0) {
  console.error("FATAL: calibration rep(s) drawn from the ROUTED arm:");
  for (const p of routed) console.error("   " + p);
  console.error("Selection must never read the arm under test (circular_selection_cannot_lose).");
  process.exit(3);
}

const cand = fs.readFileSync(candPath, "utf8").trim().split("\n").map(l => JSON.parse(l));
const reps = repPaths.map(p => JSON.parse(fs.readFileSync(p, "utf8")));

// --- REFUSAL 3: the reps do not describe the same corpus ---------------------
for (const r of reps) {
  if (r.n !== cand.length) {
    console.error(`FATAL: rep ${r.turns} scored ${r.n} items but the candidate pool has ${cand.length}.`);
    console.error("A band computed across mismatched corpora is meaningless.");
    process.exit(3);
  }
}

const tally = new Map(cand.map(c => [c.id, 0]));
for (const r of reps) for (const row of r.results) {
  if (row.correct) tally.set(row.id, (tally.get(row.id) || 0) + 1);
}

const reps_n = reps.length;
const kept = cand.filter(c => { const k = tally.get(c.id); return k > 0 && k < reps_n; });
const atFloor = cand.filter(c => tally.get(c.id) === 0).length;
const atCeiling = cand.filter(c => tally.get(c.id) === reps_n).length;

// Per-shape breakdown: which question shapes actually produced usable items.
const byKind = {};
for (const c of cand) {
  const k = tally.get(c.id);
  byKind[c.kind] = byKind[c.kind] || { total: 0, floor: 0, ceiling: 0, band: 0 };
  byKind[c.kind].total++;
  if (k === 0) byKind[c.kind].floor++;
  else if (k === reps_n) byKind[c.kind].ceiling++;
  else byKind[c.kind].band++;
}

fs.writeFileSync(outPath, kept.map(k => JSON.stringify(k)).join("\n") + (kept.length ? "\n" : ""));
fs.writeFileSync(outPath.replace(/\.jsonl$/, "") + "-design.json", JSON.stringify({
  // The Design value from RotCalibration.lean, recorded rather than asserted in prose.
  calibReps: reps_n,
  testRepsAreFresh: true,          // enforced by calib-verdict.js, which refuses a reused dir
  selectionUsedRoutedArm: false,   // enforced by REFUSAL 2 above
  candidatePool: cand.length,
  selected: kept.length,
  atFloor, atCeiling,
  calibrationReps: repPaths,
  byKind
}, null, 1));

console.log(`pool ${cand.length} -> band ${kept.length}   (floor ${atFloor}, ceiling ${atCeiling}, reps ${reps_n})`);
for (const [k, v] of Object.entries(byKind)) {
  console.log(`  ${k.padEnd(18)} total ${String(v.total).padStart(3)}  floor ${String(v.floor).padStart(3)}  ceiling ${String(v.ceiling).padStart(3)}  BAND ${String(v.band).padStart(3)}`);
}

// An empty band is not a corpus. It is the ceiling failure again, one stage
// earlier -- `empty_corpus_reproduces_the_ceiling_failure`.
if (kept.length === 0) {
  console.error("FATAL: the band is EMPTY. Every candidate saturated at floor or ceiling.");
  console.error("Running a paired test on this would reproduce the ceiling failure exactly.");
  process.exit(4);
}
if (kept.length < 20) {
  console.log(`WARNING: only ${kept.length} item(s) in band. A sign test over this is weak;` +
              ` report the power, do not hide it.`);
}
