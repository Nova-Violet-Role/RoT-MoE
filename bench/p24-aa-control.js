#!/usr/bin/env node
// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// THE A/A CONTROL THE O4 VERDICT ACTUALLY NEEDS
//
// The P2.4 write-up licensed an O4 sweep with a null control of <6, 2> that was
// measured on the R4 ANSWER-TEXT scorer. That control says nothing about
// whether the O4 detector manufactures sweeps: it is a different instrument
// reading a different quantity. Attributing an O4 result with an R4 control is
// the same class of error as scoring a process hypothesis with an answer-text
// observable -- which is the defect P2.4 was rebuilt to fix.
//
// This script builds the control from data already collected. The 160 sessions
// are four blocks: {forward, reverse} x {routed, unrouted}. Both orderings run
// the SAME 40 tasks. So pairing
//
//     forward-routed[task]  against  reverse-routed[task]
//
// is an A/A comparison: identical arm, identical task, only the position in the
// session differs. Routing cannot explain any difference found there. The same
// holds for unrouted-vs-unrouted.
//
// If O4 sweeps in the A/A as hard as it does in the A/B, the sweep is a
// property of the DETECTOR, not of the router, and the A/B verdict is
// inadmissible rather than contradicted.
//
// A second, independent probe is emitted alongside: how often the side with
// FEWER evidence bytes carries the HIGHER O4 count. O4 counts numbers in the
// final message absent from preceding tool output, so if that rate is at or
// near 100% the detector is reading haystack size.
//
// It prints Lean literals. It computes no p-value and reaches no verdict --
// verdictM in RotFamily owns that decision, exactly as p24-score.js does.
// =============================================================================
"use strict";

const fs = require("fs");

const path = process.argv[2] || "bench/p24-worktrace.jsonl";
const rows = fs
  .readFileSync(path, "utf8")
  .split("\n")
  .filter((l) => l.trim())
  .map((l) => JSON.parse(l));

if (rows.length !== 160) {
  console.error(
    `REFUSED: expected 160 rows (4 blocks x 40 tasks), found ${rows.length}.`
  );
  console.error(
    "A partial extract would silently narrow the control and make the A/A look"
  );
  console.error("cleaner than it is. Exit 3 is a refusal, never a pass.");
  process.exit(3);
}

const key = (r) => `${r.ordering}|${r.arm}|${r.task}`;
const by = new Map(rows.map((r) => [key(r), r]));

// --- the A/A pairs: same arm, same task, the two orderings -------------------
function aa(arm) {
  let discordant = 0;
  let favouring = 0; // "favouring" = forward side higher, an arbitrary but FIXED side
  const tasks = [
    ...new Set(rows.filter((r) => r.arm === arm).map((r) => r.task)),
  ].sort();
  if (tasks.length !== 40) {
    console.error(`REFUSED: arm ${arm} covers ${tasks.length} tasks, expected 40.`);
    process.exit(3);
  }
  for (const t of tasks) {
    const f = by.get(`forward|${arm}|${t}`);
    const v = by.get(`reverse|${arm}|${t}`);
    if (!f || !v) {
      console.error(`REFUSED: task ${t} is missing a half of the ${arm} A/A pair.`);
      process.exit(3);
    }
    if (f.O4 === v.O4) continue;
    discordant++;
    if (f.O4 > v.O4) favouring++;
  }
  return { discordant, favouring };
}

// --- does O4 track the size of the haystack rather than the arm? -------------
// Across every A/B pair, count how often the side with fewer evidence bytes
// carries the strictly higher O4. A detector reading behaviour has no reason to
// agree with byte count; a detector reading haystack size agrees almost always.
function haystack() {
  let comparable = 0;
  let smallerHaystackHigher = 0;
  const tasks = [...new Set(rows.map((r) => r.task))].sort();
  for (const ordering of ["forward", "reverse"]) {
    for (const t of tasks) {
      const a = by.get(`${ordering}|routed|${t}`);
      const b = by.get(`${ordering}|unrouted|${t}`);
      if (!a || !b) continue;
      if (a.O4 === b.O4) continue;
      if (a.evidence_bytes === b.evidence_bytes) continue;
      comparable++;
      const smaller = a.evidence_bytes < b.evidence_bytes ? a : b;
      const larger = smaller === a ? b : a;
      if (smaller.O4 > larger.O4) smallerHaystackHigher++;
    }
  }
  return { comparable, smallerHaystackHigher };
}

const aaRouted = aa("routed");
const aaUnrouted = aa("unrouted");
const hs = haystack();

console.log("=== A/A CONTROL ON O4 (same arm, both orderings) ===");
console.log(
  `routed   vs routed  : discordant=${aaRouted.discordant} favouring=${aaRouted.favouring}`
);
console.log(
  `unrouted vs unrouted: discordant=${aaUnrouted.discordant} favouring=${aaUnrouted.favouring}`
);
console.log("");
console.log("=== HAYSTACK PROBE (A/B pairs, does O4 track evidence bytes?) ===");
console.log(
  `comparable pairs=${hs.comparable}  smaller haystack carried higher O4=${hs.smallerHaystackHigher}`
);
if (hs.comparable > 0) {
  const pct = ((100 * hs.smallerHaystackHigher) / hs.comparable).toFixed(1);
  console.log(`rate=${pct}%`);
}
console.log("");
console.log("=== LEAN LITERALS ===");
console.log(
  `def aaRoutedO4 : NullControl.Comparison := ⟨${aaRouted.discordant}, ${aaRouted.favouring}⟩`
);
console.log(
  `def aaUnroutedO4 : NullControl.Comparison := ⟨${aaUnrouted.discordant}, ${aaUnrouted.favouring}⟩`
);
console.log(
  `def haystackProbe : Nat × Nat := (${hs.comparable}, ${hs.smallerHaystackHigher})`
);
