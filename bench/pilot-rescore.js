#!/usr/bin/env node
// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
// pilot-rescore.js -- rescore the ALREADY-COLLECTED pilot under several rules.
//
// WHY. The 2026-08-11 pilot scored 3/12 and 1/12 under one rule, and the low
// numbers were read as "the corpus is too hard". That reading is only sound if
// the rule is right, and the rule was written by the same hand that read the
// result. Twenty-four sessions are on disk; rescoring them costs nothing and
// answers whether the conclusion was about the corpus or about the scorer.
//
// It runs NO sessions. It re-derives every truth and naive value by executing
// the task's own commands, exactly as pilot-score.js does.
//
// THE RULES, all applied to both arms identically:
//   R1 strict     truth appears AND naive does not          (the shipped rule)
//   R2 lenient    truth appears at all
//   R3 leading    the FIRST number in the answer is truth
//   R4 committed  truth appears, and if naive also appears truth comes first
//
// R1 and R2 bracket the honest range: R1 refuses every hedge, R2 accepts every
// hedge. R3 and R4 are two ways of asking what the answer COMMITTED to, which
// is the thing the corpus was built to measure.
//
// USAGE  node bench/pilot-rescore.js [corpus-dir]
// EXIT   0 scored | 2 unusable input

"use strict";
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const REPO = path.resolve(__dirname, "..");
const CORPUS = process.argv[2] || "D:/Temp/rotmoe-pilot";
const MANIFEST = path.join(REPO, "bench", "pilot-manifest.jsonl");
if (!fs.existsSync(MANIFEST)) { console.error("REFUSE: manifest missing"); process.exit(2); }
const tasks = fs.readFileSync(MANIFEST, "utf8").trim().split("\n").map(JSON.parse);

function run(cmd) {
  try {
    return execSync(cmd, { cwd: REPO, shell: "C:/Program Files/Git/bin/bash.exe",
                           stdio: ["ignore", "pipe", "ignore"] }).toString().trim();
  } catch (e) { return e.stdout ? e.stdout.toString().trim() : ""; }
}

// standalone-token match, so 35 does not match inside 350
function present(text, value) {
  if (!value) return false;
  const esc = value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp("(^|[^0-9])" + esc + "([^0-9]|$)").test(text);
}
function nums(text) { return text.match(/\d+/g) || []; }

function readTurn(arm, line) {
  const f = path.join(CORPUS, "arm" + arm, "turn-" + String(line).padStart(3, "0") + ".json");
  try {
    const j = JSON.parse(fs.readFileSync(f, "utf8"));
    return (typeof j.result === "string") ? j.result : null;
  } catch (e) { return null; }
}

const RULES = {
  "R1 strict   truth AND NOT naive": (t, T, N) => present(t, T) && !present(t, N),
  "R2 lenient  truth appears":       (t, T, N) => present(t, T),
  "R3 leading  first number = truth": (t, T, N) => nums(t)[0] === T,
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
  if (T === N) { console.error("REFUSE: " + k.id + " no longer discriminates"); process.exit(2); }
  truth.push(T); naive.push(N);
}

const answers = tasks.map(k => ({ a: readTurn("a", k.line), b: readTurn("b", k.line) }));
if (answers.some(x => x.a === null || x.b === null)) {
  console.error("REFUSE: a turn is missing -- a partial pilot is not a pilot");
  process.exit(2);
}

console.log("== PILOT RESCORE -- same 24 sessions, four rules, zero new runs ==");
console.log("");
console.log("  rule                                 A     B    ties  Awin Bwin");
const summary = {};
for (const [name, f] of Object.entries(RULES)) {
  let a = 0, b = 0, aw = 0, bw = 0, ties = 0;
  tasks.forEach((k, i) => {
    const sa = f(answers[i].a, truth[i], naive[i]);
    const sb = f(answers[i].b, truth[i], naive[i]);
    if (sa) a++;
    if (sb) b++;
    if (sa && !sb) aw++; else if (!sa && sb) bw++; else ties++;
  });
  summary[name] = { a, b, aw, bw, ties };
  console.log("  " + name.padEnd(36) + String(a).padStart(2) + "/12 " +
    String(b).padStart(2) + "/12  " + String(ties).padStart(4) + "  " +
    String(aw).padStart(4) + " " + String(bw).padStart(4));
}
console.log("");
const dirs = Object.values(summary).map(s => Math.sign(s.aw - s.bw));
const agree = dirs.every(d => d === dirs[0]);
console.log("  sign of (routed wins - unrouted wins) agrees across all four rules: " +
  (agree ? "YES" : "NO"));
console.log("  This is a ROBUSTNESS check on the scorer, not a verdict. No rule");
console.log("  here reaches the ten-pair floor; see RotFamily.the_pilot_cannot_conclude.");
process.exit(0);
