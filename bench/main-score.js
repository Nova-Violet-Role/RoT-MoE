// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
// MAIN-RUN SCORER -- 160 sessions, per-ordering, never pooled.
//
// The pilot rescorer (bench/pilot-rescore.js) hardcodes pilot-manifest.jsonl
// and joins by PILOT line numbers; pointed at the main-run directories it
// silently scores 12 mis-joined pairs. Measured 2026-08-12: it printed /12
// denominators against a 40-task corpus and the output was discarded. This
// scorer exists so that mistake cannot recur: it reads the frozen corpus,
// derives the turn number from the DECLARED ordering, and refuses partial data.
//
// Rules are copied VERBATIM from pilot-rescore.js (R1, R2, R4). R3 is excluded
// by preregistration and is not implemented here, so it cannot be reported by
// accident.
//
// Output is PER ORDERING. There is deliberately no pooled row: SS7 of the
// preregistration decides the verdict on sign agreement between orderings, and
// a pooled number is the one fake green this file could still produce.
//
// USAGE  node bench/main-score.js <corpus-dir> <forward|reverse>

"use strict";
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const REPO = path.resolve(__dirname, "..");
const CORPUS_DIR = process.argv[2];
const ORDERING = process.argv[3];
if (!CORPUS_DIR || !["forward", "reverse"].includes(ORDERING)) {
  console.error("usage: node bench/main-score.js <corpus-dir> <forward|reverse>");
  process.exit(2);
}

const MANIFEST = path.join(REPO, "bench", "corpus-40.jsonl");
if (!fs.existsSync(MANIFEST)) { console.error("REFUSE: corpus-40.jsonl missing"); process.exit(2); }
const tasks = fs.readFileSync(MANIFEST, "utf8").trim().split("\n").map(JSON.parse);
if (tasks.length !== 40) { console.error("REFUSE: corpus is " + tasks.length + " tasks, not 40"); process.exit(2); }

// ordering map: forward -> task i (0-based) answered in turn i+1;
//               reverse -> task i answered in turn 40-i.
function turnOf(i) { return ORDERING === "forward" ? i + 1 : 40 - i; }

function run(cmd) {
  try {
    return execSync(cmd, { cwd: REPO, shell: "C:/Program Files/Git/bin/bash.exe",
                           stdio: ["ignore", "pipe", "ignore"] }).toString().trim();
  } catch (e) { return e.stdout ? e.stdout.toString().trim() : ""; }
}

// standalone-token match, so 35 does not match inside 350   (verbatim)
function present(text, value) {
  if (!value) return false;
  const esc = value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp("(^|[^0-9])" + esc + "([^0-9]|$)").test(text);
}
function nums(text) { return text.match(/\d+/g) || []; }

function readTurn(arm, turn) {
  const f = path.join(CORPUS_DIR, "arm" + arm, "turn-" + String(turn).padStart(3, "0") + ".json");
  if (!fs.existsSync(f)) { console.error("REFUSE: missing " + f); process.exit(2); }
  const j = JSON.parse(fs.readFileSync(f, "utf8"));
  if (typeof j.result !== "string" || !j.result.trim()) {
    console.error("REFUSE: turn " + turn + " arm " + arm + " has no result text");
    process.exit(2);
  }
  return j.result;
}

const RULES = {                                             // verbatim, R3 absent
  "R1 strict   truth AND NOT naive": (t, T, N) => present(t, T) && !present(t, N),
  "R2 lenient  truth appears":       (t, T, N) => present(t, T),
  "R4 committed truth before naive": (t, T, N) => {
    if (!present(t, T)) return false;
    if (!present(t, N)) return true;
    const m = nums(t), i = m.indexOf(T), j = m.indexOf(N);
    return i >= 0 && (j < 0 || i < j);
  }
};

const truth = [], naive = [];
for (const k of tasks) {
  const T = run(k.truth_cmd), N = run(k.naive_cmd);
  if (T === N) { console.error("REFUSE: " + k.id + " no longer discriminates (truth == naive == " + T + ")"); process.exit(2); }
  truth.push(T); naive.push(N);
}

const answers = tasks.map((k, i) => ({ a: readTurn("a", turnOf(i)), b: readTurn("b", turnOf(i)) }));

console.log("== MAIN SCORE -- " + ORDERING + " ordering, 40 pairs, this ordering only ==");
console.log("");
console.log("  rule                                 A      B     ties  Awin Bwin   d    f");
const out = {};
for (const [name, f] of Object.entries(RULES)) {
  let a = 0, b = 0, aw = 0, bw = 0, ties = 0;
  tasks.forEach((k, i) => {
    const sa = f(answers[i].a, truth[i], naive[i]);
    const sb = f(answers[i].b, truth[i], naive[i]);
    if (sa) a++;
    if (sb) b++;
    if (sa && !sb) aw++; else if (!sa && sb) bw++; else ties++;
  });
  const d = aw + bw;            // discordant pairs
  const fav = aw;               // favouring the routed (first-named) side
  out[name] = { a, b, aw, bw, ties, d, fav };
  console.log("  " + name.padEnd(36) + String(a).padStart(2) + "/40 " +
    String(b).padStart(2) + "/40  " + String(ties).padStart(4) + "  " +
    String(aw).padStart(4) + " " + String(bw).padStart(4) + "  " +
    String(d).padStart(3) + " " + String(fav).padStart(4));
}
// O8 -- hedge rate: answers naming BOTH the true and the naive value.
// DESCRIPTIVE ONLY. It is declared descriptive in AMENDMENT 3 and
// `the_hedge_rate_does_not_inflate_the_family` proves adding it leaves m = 4.
// It is printed apart from the rule table so it cannot be misread as a rule,
// and it carries no discordant/favouring columns because it enters no test.
let hedgeA = 0, hedgeB = 0;
tasks.forEach((k, i) => {
  if (present(answers[i].a, truth[i]) && present(answers[i].a, naive[i])) hedgeA++;
  if (present(answers[i].b, truth[i]) && present(answers[i].b, naive[i])) hedgeB++;
});
console.log("");
console.log("  O8 hedge rate (DESCRIPTIVE, enters no test, does not inflate m):");
console.log("     routed   " + String(hedgeA).padStart(2) + "/40");
console.log("     unrouted " + String(hedgeB).padStart(2) + "/40");

console.log("");
const r4 = out["R4 committed truth before naive"];
console.log("  R4 PRIMARY (" + ORDERING + "): discordant=" + r4.d + " favouring=" + r4.fav +
  "  sign=" + Math.sign(r4.aw - r4.bw));
console.log("  Comparison literal for Lean: <" + r4.d + ", " + r4.fav + ">");
console.log("  NO POOLED ROW EXISTS IN THIS OUTPUT, BY DESIGN. Score the other");
console.log("  ordering with a second invocation and compare SIGNS, not sums.");
process.exit(0);
