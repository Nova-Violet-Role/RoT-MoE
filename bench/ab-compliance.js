// Instruction compliance, scored from the raw A/B corpus.
//
// WHY THIS ENDPOINT EXISTS. Two of the three published primaries (trailing
// question, self-narration) are 0.000 in both arms across all 88 turns. That is
// not "no effect": counts are bounded below by zero and the control arm sits on
// the bound, so those endpoints could not have shown a win for ANY routed arm.
// Proved as RotMoE.Endpoint.the_zero_endpoints_cannot_show_improvement.
//
// This one can move. bench/ab-session.sh appends
//     " Answer in one or two sentences."
// to every prompt in BOTH arms, verbatim, so compliance is a constraint that
// was actually imposed on every turn and can be scored mechanically after the
// fact. The control arm violates it 41 times in 88 turns -- nowhere near the
// floor -- so a win is expressible.
//
// AND IT DOES NOT SHOW ONE. The headline favours routing (28 pairs to 10,
// p = 5.1e-3), but routed answers are also 26% shorter and sentence count rises
// with length nearly by construction. Removing every win that brevity already
// explains leaves 2 wins against 10 losses -- the effect REVERSES. This script
// prints both numbers, always, so the headline can never be quoted alone.
//
// The scorer is crude and IDENTICAL on both sides. Whatever bias it has, it has
// equally on each arm; what is compared is the difference. Its known loophole is
// recorded rather than hidden: it counts sentences, so a single 2080-character
// run-on scores as perfect compliance (turn 46 is exactly that).
"use strict";
const fs = require("fs");
const path = require("path");

const CORPUS = process.argv[2];
if (!CORPUS) { console.error("usage: ab-compliance.js <corpus-dir>"); process.exit(2); }

function sentences(text) {
  let t = String(text || "");
  t = t.replace(/```[\s\S]*?```/g, " CODEBLOCK ");
  t = t.replace(/`[^`]*`/g, " CODE ");
  t = t.replace(/\b\d+\.\d+/g, "NUM");
  t = t.replace(/\.\.\./g, "ELLIPSIS");
  t = t.replace(/\b(e\.g|i\.e|etc|vs|Mr|Dr|No)\./gi, "$1ABBR");
  const m = t.match(/[.!?](\s|$)/g);
  return m ? m.length : 0;
}

function readArm(arm) {
  const dir = path.join(CORPUS, "arm" + arm);
  if (!fs.existsSync(dir)) return null;
  const out = new Map();
  for (const f of fs.readdirSync(dir)) {
    const mt = f.match(/^turn-(\d+)\.json$/);
    if (!mt) continue;
    let j;
    try { j = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")); } catch (e) { continue; }
    if (typeof j.result === "string" && j.result.length) out.set(parseInt(mt[1], 10), j.result);
  }
  return out;
}

const A = readArm("a"), B = readArm("b");
if (!A || !B) { console.log("NOCORPUS"); process.exit(3); }
const turns = [...A.keys()].filter(k => B.has(k)).sort((x, y) => x - y);
if (turns.length === 0) { console.log("NOCORPUS"); process.exit(3); }

let violA = 0, violB = 0, aBetter = 0, bBetter = 0, tie = 0;
let explained = 0, unexplained = 0, deconfLosses = 0;
for (const t of turns) {
  const ta = A.get(t), tb = B.get(t);
  const sa = sentences(ta), sb = sentences(tb);
  const va = sa > 2, vb = sb > 2;
  if (va) violA++;
  if (vb) violB++;
  if (!va && vb) {
    aBetter++;
    if (ta.length >= tb.length) unexplained++; else explained++;
  } else if (va && !vb) { bBetter++; deconfLosses++; }
  else tie++;
}

function signP(k, n) {
  if (n === 0) return 1;
  const C = (n, k) => { let r = 1; for (let i = 0; i < k; i++) r = r * (n - i) / (i + 1); return r; };
  let tail = 0;
  const lo = Math.min(k, n - k);
  for (let i = 0; i <= lo; i++) tail += C(n, i);
  return Math.min(1, 2 * tail / Math.pow(2, n));
}

const out = {
  turns: turns.length,
  violationsRouted: violA,
  violationsUnrouted: violB,
  headlineWinsRouted: aBetter,
  headlineWinsUnrouted: bBetter,
  ties: tie,
  headlineP: signP(Math.min(aBetter, bBetter), aBetter + bBetter),
  explained: explained,
  unexplained: unexplained,
  deconfoundedLosses: deconfLosses,
  deconfoundedP: signP(Math.min(unexplained, deconfLosses), unexplained + deconfLosses),
  survivesDeconfounding: deconfLosses < unexplained,
};
console.log(JSON.stringify(out));
