#!/usr/bin/env node
// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// ===========================================================================
// P2.4 -- pair the per-task observables and COUNT. It does not decide.
//
// The verdict function lives in Lean (`RotFamily.verdictM`), and this script
// deliberately stops at the two numbers that function consumes: `d`, the number
// of discordant pairs, and `f`, how many of them fall in the direction §3
// claimed IN ADVANCE. Re-implementing a p-value here would put the decision in
// the same language as the counting, where nobody re-checks it; keeping the
// decision in Lean means the boundary is `decide`d by the kernel against a
// family size derived from the observable table.
//
// DIRECTIONS ARE FROM §3 AND ARE NOT NEGOTIABLE AFTER THE FACT:
//   O1 verification steps        routed HIGHER
//   O2 rework edits              routed LOWER
//   O3 reads before first write  routed HIGHER
//   O4 unverified claims         routed LOWER
// `f` counts pairs matching THAT direction. A result that comes out against the
// claim therefore shows up as a small `f` against a large `d`, which is what
// §7's CONTRADICTED arm reads -- the sign cannot be quietly flipped to rescue it.
//
// NO POOLED ROW IS EMITTED. §6 requires the orderings to agree in sign, and an
// average is exactly what would hide a disagreement.
//
// exit: 0 ok | 2 bad usage / unreadable | 3 pairing incomplete
// ===========================================================================
"use strict";

const fs = require("fs");

const DIRECTION = { O1: "higher", O2: "lower", O3: "higher", O4: "lower" };

function main() {
  const file = process.argv[2];
  if (!file) {
    console.error("usage: node bench/p24-score.js <per-task.jsonl>");
    process.exit(2);
  }
  let rows;
  try {
    rows = fs.readFileSync(file, "utf8").split("\n").map((s) => s.trim()).filter(Boolean).map((l) => JSON.parse(l));
  } catch (e) {
    console.error("cannot read " + file + ": " + e.message);
    process.exit(2);
  }

  const key = (r) => r.ordering + "|" + r.task;
  const byKey = new Map();
  for (const r of rows) {
    const k = key(r);
    if (!byKey.has(k)) byKey.set(k, {});
    byKey.get(k)[r.arm] = r;
  }

  const orderings = ["forward", "reverse"];
  const out = {};
  for (const ord of orderings) {
    const pairs = [...byKey.entries()].filter(([k]) => k.startsWith(ord + "|"));
    if (pairs.length !== 40) {
      console.error("PAIRING REFUSED: " + ord + " has " + pairs.length + " task(s), expected 40");
      process.exit(3);
    }
    for (const [k, v] of pairs) {
      if (!v.routed || !v.unrouted) {
        console.error("PAIRING REFUSED: " + k + " is missing an arm -- a half pair cannot enter a sign test");
        process.exit(3);
      }
    }
    out[ord] = {};
    for (const ob of Object.keys(DIRECTION)) {
      let d = 0, f = 0;
      for (const [, v] of pairs) {
        const a = v.routed[ob], b = v.unrouted[ob];
        if (a === b) continue;              // a tie is not a discordant pair
        d += 1;
        const routedBetter = DIRECTION[ob] === "higher" ? a > b : a < b;
        if (routedBetter) f += 1;
      }
      out[ord][ob] = { d, f };
    }
  }

  console.log("== P2.4 per-task observables, paired by task, per ordering ==");
  console.log("");
  console.log("  observable  direction        forward d/f     reverse d/f");
  for (const ob of Object.keys(DIRECTION)) {
    const F = out.forward[ob], R = out.reverse[ob];
    console.log("  " + ob + "          routed " + DIRECTION[ob].padEnd(8) +
      "  " + String(F.d).padStart(6) + "/" + String(F.f).padEnd(6) +
      "  " + String(R.d).padStart(6) + "/" + String(R.f));
  }
  console.log("");
  console.log("  Comparison literals for Lean (RotFamily.verdictM consumes these):");
  for (const ob of Object.keys(DIRECTION)) {
    console.log("    " + ob + "  forward <" + out.forward[ob].d + ", " + out.forward[ob].f + ">" +
      "   reverse <" + out.reverse[ob].d + ", " + out.reverse[ob].f + ">");
  }
  console.log("");
  console.log("  NO POOLED ROW. The orderings must agree in SIGN; an average would hide");
  console.log("  a disagreement, which is the reason both orderings were run at all.");
  process.exit(0);
}

if (require.main === module) main();
