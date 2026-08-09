// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// SCORE THE FACT CORPUS. Right or wrong. Silence is WRONG.
//
// The two earlier metrics both rewarded abstention and both dissolved under
// their own control (brevity, then selectivity). This one cannot be gamed that
// way: every prompt has exactly one correct answer, and an answer that does not
// contain it is counted WRONG whether it was a hallucination, a hedge, or
// nothing at all.
//
// GROUND TRUTH IS RE-DERIVED HERE, from the repository as it stands right now,
// and cross-checked against the expectations frozen in fact-prompts.jsonl. If
// the tree has moved since the corpus was generated, this REFUSES rather than
// grading answers against a stale key. A scorer that silently grades against
// yesterday's truth is worse than no scorer.
//
// MATCHING, kept deliberately generous to the model:
//   name   the exact identifier appears anywhere in the answer, on a word
//          boundary. A correct name wrapped in prose still counts.
//   count  the FIRST integer in the answer equals the expected count. Taking
//          the first integer rather than "contains" prevents a wrong answer
//          from scoring because the right number appeared incidentally later.
//
// usage: node bench/fact-score.js <corpus-dir>
// exit 0 scored, 2 usage, 3 no corpus, 4 STALE ground truth (refuses to score)
// =============================================================================
const fs = require("fs");
const path = require("path");

const CORPUS = process.argv[2];
if (!CORPUS) { console.log("usage: fact-score.js <corpus-dir>"); process.exit(2); }
const REPO = path.resolve(__dirname, "..");
const PROOFS = path.join(REPO, "lean", "Proofs");

function stripBlockComments(txt) {
  let out = "", depth = 0;
  for (let i = 0; i < txt.length; i++) {
    if (txt[i] === "/" && txt[i + 1] === "-") { depth++; i++; continue; }
    if (txt[i] === "-" && txt[i + 1] === "/" && depth > 0) { depth--; i++; continue; }
    if (depth === 0) out += txt[i]; else if (txt[i] === "\n") out += "\n";
  }
  return out;
}
function facts(rel) {
  const txt = stripBlockComments(fs.readFileSync(path.join(REPO, rel), "utf8"));
  const names = [];
  const re = /^theorem\s+([A-Za-z_][A-Za-z0-9_']*)/gm;
  let m; while ((m = re.exec(txt))) names.push(m[1]);
  return { count: names.length, last: names[names.length - 1] };
}

const key = fs.readFileSync(path.join(REPO, "bench", "fact-prompts.jsonl"), "utf8")
  .trim().split("\n").map(JSON.parse);

// --- STALENESS GATE ---------------------------------------------------------
const stale = [];
for (const k of key) {
  const F = facts(k.file);
  const now = k.kind === "name" ? F.last : String(F.count);
  if (now !== k.expect) stale.push(k.n + " " + k.file + " " + k.kind + ": key=" + k.expect + " now=" + now);
}
if (stale.length) {
  console.log("REFUSE: ground truth has moved since the corpus was generated -- " +
              stale.length + " of " + key.length + " expectations are stale.");
  for (const s of stale.slice(0, 8)) console.log("  " + s);
  console.log("Regenerate with: node bench/fact-prompts.js > bench/fact-prompts.jsonl");
  process.exit(4);
}

function readArm(arm) {
  const d = path.join(CORPUS, "arm" + arm);
  const out = new Map();
  let files = [];
  try { files = fs.readdirSync(d).filter(f => /^turn-\d+\.json$/.test(f)); } catch (e) { return null; }
  for (const f of files) {
    let j = null;
    try { j = JSON.parse(fs.readFileSync(path.join(d, f), "utf8")); } catch (e) { continue; }
    out.set(Number(f.slice(5, 8)), (j && typeof j.result === "string") ? j.result : "");
  }
  return out;
}
const A = readArm("a"), B = readArm("b");
if (!A || !B) { console.log("NOCORPUS"); process.exit(3); }

function correct(k, ans) {
  if (!ans || !ans.trim()) return false;          // silence is WRONG
  if (k.kind === "name") {
    return new RegExp("\\b" + k.expect.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\b").test(ans);
  }
  const m = ans.match(/-?\d+/);
  return !!m && m[0] === k.expect;
}

let aOK = 0, bOK = 0, aWin = 0, bWin = 0, both = 0, neither = 0, scored = 0;
let aChars = 0, bChars = 0, aSilent = 0, bSilent = 0;
const byKind = { name: { a: 0, b: 0, n: 0 }, count: { a: 0, b: 0, n: 0 } };
for (const k of key) {
  if (!A.has(k.n) || !B.has(k.n)) continue;
  const ta = A.get(k.n), tb = B.get(k.n);
  scored++; aChars += ta.length; bChars += tb.length;
  if (!ta.trim()) aSilent++;
  if (!tb.trim()) bSilent++;
  const ca = correct(k, ta), cb = correct(k, tb);
  if (ca) aOK++; if (cb) bOK++;
  byKind[k.kind].n++; if (ca) byKind[k.kind].a++; if (cb) byKind[k.kind].b++;
  if (ca && !cb) aWin++; else if (cb && !ca) bWin++; else if (ca && cb) both++; else neither++;
}

function signP(k, n) {
  if (n === 0) return 1;
  const C = (n, k) => { let r = 1; for (let i = 0; i < k; i++) r = r * (n - i) / (i + 1); return r; };
  let tail = 0;
  const lo = Math.min(k, n - k);
  for (let i = 0; i <= lo; i++) tail += C(n, i);
  return Math.min(1, 2 * tail / Math.pow(2, n));
}
const p = signP(Math.min(aWin, bWin), aWin + bWin);

console.log(JSON.stringify({
  scored,
  routedCorrect: aOK, unroutedCorrect: bOK,
  routedAccuracy: +(aOK / scored).toFixed(4),
  unroutedAccuracy: +(bOK / scored).toFixed(4),
  discordant: { routedOnly: aWin, unroutedOnly: bWin, bothRight: both, bothWrong: neither },
  p: p, significant: p < 0.05,
  routedWins: p < 0.05 && aWin > bWin,
  byKind: byKind,
  // Reported so the brevity confound can be checked rather than assumed away:
  // on THIS metric a shorter answer cannot help, because a missing answer is
  // wrong. The numbers are here so a reader can verify that for themselves.
  meanChars: { routed: Math.round(aChars / scored), unrouted: Math.round(bChars / scored) },
  silentTurns: { routed: aSilent, unrouted: bSilent }
}, null, 1));
