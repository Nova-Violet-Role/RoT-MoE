#!/usr/bin/env node
// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// CONTROLS FOR THE ANSWER PARSER IN bench/trap-score.js
//
// The first real run of the trap corpus scored 0 correct out of 60 for BOTH
// arms. The arms were right; the parser was wrong. Its trailing lookahead
// rejected any digit followed by a period, so "**0.**" -- the most natural way
// to answer "how many" -- read as no integer at all, and the run reported
// noPower from a defect rather than from data.
//
// Every case below is derived from the RULE the parser is supposed to
// implement, not from what makes a particular arm win:
//
//   a run of digits counts when it is not part of a word and not part of a
//   dotted numeral; a period after it ends a sentence unless a digit follows.
//
// Both directions are pinned. Cases that must MATCH and cases that must NOT --
// a parser that accepts everything would pass a suite of only positive cases,
// and would happily read the "1" out of "v1.0.2".
// =============================================================================

const fs = require("fs");
const path = require("path");

// Extract the live implementation rather than copying it: a second copy of the
// regex here would drift from the one that scores, and the control would then
// be verifying itself.
const src = fs.readFileSync(path.join(__dirname, "trap-score.js"), "utf8");
const m = src.match(/function firstInt\(txt\) \{[\s\S]*?\n\}/);
if (!m) { console.error("FATAL: could not locate firstInt in trap-score.js"); process.exit(2); }
const firstInt = new Function(m[0] + "; return firstInt;")();

const cases = [
  // [input, expected, why]
  ["**0.**", 0, "a bolded zero ending a sentence -- the case the first parser missed"],
  ["0.", 0, "bare zero ending a sentence"],
  ["The answer is 35.", 35, "number ending a sentence"],
  ["35 theorems are declared", 35, "number followed by a space"],
  ["There are 12 items, not 14.", 12, "FIRST integer wins"],
  ["**0.** The file contains `#guard` twice (lines 326 and 581)", 0,
   "the real reply shape from the first run: correct answer first, evidence after"],
  ["v1.0.2 is the unsealed tier", null, "a dotted version is not an answer"],
  ["Version 1.0.2 shipped", null, "dotted numeral rejected even after a word"],
  ["See lean/Proofs/RotAbility.lean", null, "no standalone integer at all"],
  ["I cannot determine that.", null, "a refusal has no integer -- must stay SILENT"],
  ["", null, "empty reply"],
  ["turn-001.json holds it", null, "digits glued into a dotted filename are not an answer"],
  ["The count is 5, i.e. 5.0 in float form", 5, "first standalone integer, not the float"],
  ["3.14 is not the answer, 7 is", 7, "a decimal is skipped, the bare integer is taken"],
];

let pass = 0, fail = 0;
for (const [input, expected, why] of cases) {
  const got = firstInt(input);
  if (got === expected) { console.log("  ok   " + JSON.stringify(input).slice(0, 46).padEnd(48) + "-> " + got); pass++; }
  else { console.log("  FAIL " + JSON.stringify(input).slice(0, 46).padEnd(48) + "-> " + got + " (expected " + expected + ") :: " + why); fail++; }
}

// NEGATIVE CONTROL ON THE CONTROL ITSELF: a deliberately broken parser must be
// caught here. A suite that cannot fail is not evidence.
const broken = (txt) => { const g = (txt || "").match(/(\d+)/); return g ? Number(g[1]) : null; };
const brokenCaught = cases.some(([input, expected]) => broken(input) !== expected);
if (brokenCaught) { console.log("  ok   CONTROL: a naive /(\\d+)/ parser IS rejected by this suite"); pass++; }
else { console.log("  FAIL CONTROL: a naive parser passes -- these cases prove nothing"); fail++; }

console.log("\n== trap parse controls: " + pass + " passed, " + fail + " failed");
process.exit(fail === 0 ? 0 : 1);
