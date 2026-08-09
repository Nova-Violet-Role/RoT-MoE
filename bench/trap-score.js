#!/usr/bin/env node
// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// SCORE THE TRAP CORPUS, EXACTLY AS PRE-REGISTERED.
//
// Every rule here is a transcription of bench/TRAP-PREREGISTRATION.md, which
// was committed BEFORE the corpus was run. Nothing in this file may be tuned
// after seeing a result; if a rule turns out to be wrong, the honest move is to
// say the run is void and re-register, not to adjust the scorer.
//
// Classification (fixed in advance):
//   CORRECT  first integer == truth
//   TRAPPED  first integer == naive        <- fell for the obvious wrong method
//   OTHER    an integer, neither of those
//   SILENT   no integer / empty / timeout  <- counts as INCORRECT, never dropped
//
// Usage: node bench/trap-score.js <candidates.jsonl> <armA_dir> <armB_dir>
//        armX_dir holds turn-NNN.txt files, as written by bench/ab-session.sh
// =============================================================================

const fs = require("fs");
const path = require("path");

const [, , CAND, DIR_A, DIR_B] = process.argv;
if (!CAND || !DIR_A || !DIR_B) {
  console.error("usage: trap-score.js <candidates.jsonl> <armA_dir> <armB_dir>");
  process.exit(2);
}

const items = fs.readFileSync(CAND, "utf8").trim().split("\n").map((l) => JSON.parse(l));

// The reply file for turn N. ab-session.sh writes turn-001.txt ... and the
// numbering is 1-based against the prompt file, which is emitted in `id` order.
function readTurn(dir, id) {
  for (const name of [
    "turn-" + String(id).padStart(3, "0") + ".txt",
    "turn-" + id + ".txt",
  ]) {
    const p = path.join(dir, name);
    if (fs.existsSync(p)) return fs.readFileSync(p, "utf8");
  }
  return null;
}

// FIRST INTEGER, and the parse is deliberately narrow. A reply like
// "lean/Proofs/RotAbility.lean has 35 theorems" must not score by matching the
// digits inside a path or a version string, so digits glued to a letter or a
// dot-decimal are skipped.
function firstInt(txt) {
  if (txt == null) return null;
  const m = txt.match(/(?<![\w.])(\d+)(?![\w.])/);
  return m ? Number(m[1]) : null;
}

function classify(txt, it) {
  const n = firstInt(txt);
  if (n === null) return "SILENT";
  if (n === it.truth) return "CORRECT";
  if (n === it.naive) return "TRAPPED";
  return "OTHER";
}

// A MISSING FILE AND AN EMPTY REPLY ARE NOT THE SAME EVENT, and collapsing them
// is how a harness defect disguises itself as a finding: if the turn files were
// numbered differently from `id`, every lookup would miss, both arms would score
// SILENT on everything, band would be 0 and the run would report `noPower` --
// a clean-looking result produced by reading nothing at all.
//
//   file absent  -> the harness did not produce that turn -> FATAL, refuse to score
//   file present -> whatever it contains is the arm's answer, SILENT included
let missingA = 0, missingB = 0;

const rows = [];
for (const it of items) {
  const ta = readTurn(DIR_A, it.id);
  const tb = readTurn(DIR_B, it.id);
  if (ta === null) missingA++;
  if (tb === null) missingB++;
  rows.push({
    id: it.id, family: it.family, file: it.file, naive: it.naive, truth: it.truth,
    a: classify(ta, it), b: classify(tb, it),
    aLen: ta == null ? 0 : ta.trim().length,
    bLen: tb == null ? 0 : tb.trim().length,
  });
}

if (missingA > 0 || missingB > 0) {
  console.error("FATAL: turn files are MISSING, not empty -- refusing to score.");
  console.error("  arm a: " + missingA + " of " + items.length + " absent under " + DIR_A);
  console.error("  arm b: " + missingB + " of " + items.length + " absent under " + DIR_B);
  console.error("  This is a harness fault (numbering or a run that did not finish),");
  console.error("  NOT a silent model. Scoring it would report noPower from no data.");
  process.exit(3);
}

const cnt = (arm, cls) => rows.filter((r) => r[arm] === cls).length;
const aCorrect = cnt("a", "CORRECT"), bCorrect = cnt("b", "CORRECT");

// Discordant pairs = RotTrap.band
const bWins = rows.filter((r) => r.b === "CORRECT" && r.a !== "CORRECT");
const aWins = rows.filter((r) => r.a === "CORRECT" && r.b !== "CORRECT");
const band = bWins.length + aWins.length;

// Explained-loss rule: a discordant pair where the LOSING arm was SILENT is
// explained by silence, not by routing.
const bWinsUnexplained = bWins.filter((r) => r.a !== "SILENT");
const aWinsUnexplained = aWins.filter((r) => r.b !== "SILENT");
const bandDeconf = bWinsUnexplained.length + aWinsUnexplained.length;

// Exact two-sided binomial at p = 0.5 -- McNemar exact.
function lchoose(n, k) {
  let s = 0;
  for (let i = 1; i <= k; i++) s += Math.log(n - k + i) - Math.log(i);
  return s;
}
function binomTwoSided(k, n) {
  if (n === 0) return 1;
  const pk = (i) => Math.exp(lchoose(n, i) - n * Math.log(2));
  const target = pk(k) * (1 + 1e-9);
  let p = 0;
  for (let i = 0; i <= n; i++) if (pk(i) <= target) p += pk(i);
  return Math.min(1, p);
}

const p = binomTwoSided(Math.min(bWins.length, aWins.length), band);
const pDeconf = binomTwoSided(Math.min(bWinsUnexplained.length, aWinsUnexplained.length), bandDeconf);

const median = (xs) => {
  if (!xs.length) return 0;
  const s = [...xs].sort((x, y) => x - y);
  return s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2;
};
const medA = median(rows.map((r) => r.aLen)), medB = median(rows.map((r) => r.bLen));
const lengthConfounded = medA > 0 && medB > 0 && (medB / medA > 2 || medA / medB > 2);

// Verdict, straight from the pre-registered table. No branch is added here.
let verdict;
if (band < 10) verdict = "noPower";
else if (lengthConfounded) verdict = "confounded";
else if (pDeconf < 0.05 && bWinsUnexplained.length > aWinsUnexplained.length) verdict = "advantage";
else verdict = "null";

const out = {
  n: rows.length,
  arms: {
    a: { correct: aCorrect, trapped: cnt("a", "TRAPPED"), other: cnt("a", "OTHER"), silent: cnt("a", "SILENT"), medianLen: medA },
    b: { correct: bCorrect, trapped: cnt("b", "TRAPPED"), other: cnt("b", "OTHER"), silent: cnt("b", "SILENT"), medianLen: medB },
  },
  band, bWins: bWins.length, aWins: aWins.length, p,
  bandDeconfounded: bandDeconf,
  bWinsUnexplained: bWinsUnexplained.length,
  aWinsUnexplained: aWinsUnexplained.length,
  explained: band - bandDeconf,
  pDeconfounded: pDeconf,
  lengthConfounded,
  powerFloor: 10,
  verdict,
  byFamily: {},
};
for (const f of [...new Set(rows.map((r) => r.family))].sort()) {
  const sub = rows.filter((r) => r.family === f);
  out.byFamily[f] = {
    n: sub.length,
    aCorrect: sub.filter((r) => r.a === "CORRECT").length,
    bCorrect: sub.filter((r) => r.b === "CORRECT").length,
    aTrapped: sub.filter((r) => r.a === "TRAPPED").length,
    bTrapped: sub.filter((r) => r.b === "TRAPPED").length,
  };
}

console.log(JSON.stringify(out, null, 2));
