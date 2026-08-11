#!/usr/bin/env node
// pilot-score.js -- score the P2.4 pilot from a collected A/B corpus.
//
// WHAT THIS DOES AND DOES NOT DO.
//
// It scores O5 (task success) per task, which is what section 5 of
// bench/P24-PREREGISTRATION.md needs to decide corpus ADMISSIBILITY, and it
// reports the process observables O1-O4 per ARM from the session transcripts.
// It does not compute a verdict on H1 -- that needs the full 160 sessions in
// both orderings, and the rule lives in lean/Proofs/RotFamily.lean.
//
// THE SCORING RULE IS FIXED HERE AND APPLIED IDENTICALLY TO BOTH ARMS:
//
//   success  <=>  the TRUTH value appears in the final message
//                 AND the NAIVE value does not.
//
// An answer carrying both numbers hedged; it did not commit to the right one,
// and it is scored as a failure. That is deliberately strict and it is strict
// in the SAME direction for both arms, which is the only property that matters
// for a paired test. Scoring "truth appears" alone would let an answer that
// leads with the wrong number and mentions the right one in a caveat count as
// a success, and that is precisely the behaviour the corpus exists to detect.
//
// Both values are RE-DERIVED by running the task's own commands at scoring
// time. No expected number is stored anywhere -- see
// RotMoE.TaskCorpus.the_frozen_check_claims_discrimination_that_is_not_there.
//
// USAGE
//   node bench/pilot-score.js <corpus-dir> [--json]
// EXIT
//   0 scored | 2 unusable input (missing turns, unreadable manifest)

"use strict";
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const CORPUS = process.argv[2];
const AS_JSON = process.argv.includes("--json");
if (!CORPUS) { console.error("usage: pilot-score.js <corpus-dir> [--json]"); process.exit(2); }

const REPO = path.resolve(__dirname, "..");
const MANIFEST = path.join(REPO, "bench", "pilot-manifest.jsonl");
if (!fs.existsSync(MANIFEST)) { console.error("REFUSE: " + MANIFEST + " missing"); process.exit(2); }

const tasks = fs.readFileSync(MANIFEST, "utf8").trim().split("\n").map(JSON.parse);

// Run a command and capture its output WHATEVER the exit status. `grep -c`
// exits 1 on a zero count, and treating that as an error made seven corpus
// tasks look broken during verification. A count of zero is a measurement.
function run(cmd) {
  try {
    return execSync(cmd, { cwd: REPO, shell: "C:/Program Files/Git/bin/bash.exe", stdio: ["ignore", "pipe", "ignore"] })
      .toString().trim();
  } catch (e) {
    return (e.stdout ? e.stdout.toString().trim() : "");
  }
}

// A value counts as "present" only as a standalone token, so 35 does not match
// inside 350 or 1435.
function present(text, value) {
  if (!value) return false;
  return new RegExp("(^|[^0-9])" + value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "([^0-9]|$)").test(text);
}

function readTurn(arm, line) {
  const f = path.join(CORPUS, "arm" + arm, "turn-" + String(line).padStart(3, "0") + ".json");
  if (!fs.existsSync(f)) return null;
  let j; try { j = JSON.parse(fs.readFileSync(f, "utf8")); } catch (e) { return null; }
  if (!j || typeof j.result !== "string" || !j.result.trim()) return null;
  return j;
}

const rows = [];
let missing = 0;
for (const t of tasks) {
  const truth = run(t.truth_cmd);
  const naive = run(t.naive_cmd);
  if (truth === naive) {
    console.error("REFUSE: task " + t.id + " no longer discriminates (both give " + truth + ")");
    process.exit(2);
  }
  const row = { id: t.id, family: t.family, lane: t.lane, truth, naive };
  for (const arm of ["a", "b"]) {
    const j = readTurn(arm, t.line);
    if (!j) { missing++; row["arm" + arm] = { present: false }; continue; }
    const txt = j.result;
    const hasT = present(txt, truth), hasN = present(txt, naive);
    row["arm" + arm] = {
      present: true,
      success: hasT && !hasN,
      truth_seen: hasT,
      naive_seen: hasN,
      hedged: hasT && hasN,
      turns: j.num_turns,
      ms: j.duration_ms,
      answer: txt.slice(0, 160).replace(/\s+/g, " ")
    };
  }
  rows.push(row);
}

if (missing > 0) {
  console.error("REFUSE: " + missing + " turn(s) missing or empty -- a partial pilot is not a pilot");
  process.exit(2);
}

const okA = rows.filter(r => r.arma.success).length;
const okB = rows.filter(r => r.armb.success).length;
const n = rows.length;

// Paired disagreement, the input to a sign test: tasks where exactly one arm
// succeeded. Ties carry no information and are excluded, which is what makes
// it a sign test rather than a proportion comparison.
const aWins = rows.filter(r => r.arma.success && !r.armb.success).length;
const bWins = rows.filter(r => !r.arma.success && r.armb.success).length;

const out = {
  n, armA_success: okA, armB_success: okB,
  ties: n - aWins - bWins,
  routed_wins: aWins, unrouted_wins: bWins,
  hedged_A: rows.filter(r => r.arma.hedged).length,
  hedged_B: rows.filter(r => r.armb.hedged).length,
  rows
};

if (AS_JSON) { console.log(JSON.stringify(out, null, 2)); process.exit(0); }

console.log("== P2.4 PILOT -- O5 task success, " + n + " paired tasks ==");
console.log("");
console.log("  id     lane        truth naive  A  B   note");
for (const r of rows) {
  const mark = s => s.success ? "OK" : (s.hedged ? "hd" : "--");
  console.log("  " + r.id.padEnd(6) + " " + r.lane.padEnd(11) + " " +
    String(r.truth).padStart(5) + " " + String(r.naive).padStart(5) + "  " +
    mark(r.arma) + " " + mark(r.armb) + "   " +
    (r.arma.success === r.armb.success ? "tie" : (r.arma.success ? "ROUTED" : "unrouted")));
}
console.log("");
console.log("  arm A (routed)   succeeded on " + okA + " / " + n);
console.log("  arm B (unrouted) succeeded on " + okB + " / " + n);
console.log("  hedged (both numbers stated): A=" + out.hedged_A + " B=" + out.hedged_B);
console.log("  paired: routed wins " + aWins + ", unrouted wins " + bWins + ", ties " + out.ties);
console.log("");
console.log("  This is the PILOT. It decides corpus admissibility (section 5),");
console.log("  not H1. The verdict rule needs the full run in both orderings.");
process.exit(0);
