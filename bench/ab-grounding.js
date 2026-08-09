// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// A/B GROUNDING -- the metric that BREVITY CANNOT FAKE.
//
// WHY THIS EXISTS. The compliance analysis (ab-compliance.js) found routing cut
// instruction violations 40 -> 15 with p = 1.09e-5, and then found that 27 of
// the 29 wins were turns where the routed answer was simply SHORTER. Fewer
// sentences follows trivially from less text, so the headline could not be
// separated from a brevity effect and `survivesDeconfounding` was FALSE.
//
// A ratio fixes that. For each answer:
//
//     precision = citations that EXIST on disk / citations the answer MAKES
//
// Length cancels. A short answer citing one false path scores 0.0; a long
// answer citing ten true paths scores 1.0. Padding cannot raise it and terseness
// cannot raise it -- only being RIGHT can.
//
// WHAT COUNTS AS A CITATION. Two kinds, both mechanically checkable against the
// repository, never against a model's opinion:
//
//   path     something shaped like  dir/file.ext  -- checked with fs.existsSync
//   theorem  a snake_case identifier -- checked against the set of names
//            actually declared in lean/Proofs/*.lean
//
// TURNS WITH ZERO CITATIONS ARE EXCLUDED, not scored 0. An answer that asserts
// nothing checkable is not wrong, it is silent, and counting silence as failure
// would re-introduce a length effect through the back door. The number of
// excluded turns is REPORTED per arm, because a router that wins by saying
// nothing checkable would show up there and must not be able to hide.
//
// usage: node bench/ab-grounding.js <corpus-dir>
// exit 0 always on a valid corpus; 3 = no corpus. The verdict is data, not exit.
// =============================================================================
const fs = require("fs");
const path = require("path");

const CORPUS = process.argv[2];
if (!CORPUS) { console.log("usage: ab-grounding.js <corpus-dir>"); process.exit(2); }
const REPO = path.resolve(__dirname, "..");

// ---- the ground truth: what actually exists -------------------------------
const theoremNames = new Set();
function scanLean(dir) {
  let ents = [];
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return; }
  for (const e of ents) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { scanLean(p); continue; }
    if (!e.name.endsWith(".lean")) continue;
    const txt = fs.readFileSync(p, "utf8");
    const re = /^(?:theorem|lemma|def|structure|abbrev)\s+([A-Za-z_][A-Za-z0-9_']*)/gm;
    let m; while ((m = re.exec(txt))) theoremNames.add(m[1]);
  }
}
scanLean(path.join(REPO, "lean"));

const pathRe = /\b((?:[A-Za-z0-9_.-]+\/)+[A-Za-z0-9_.-]+\.(?:lean|sh|js|json|md|ps1|yml|cff|toml))\b/g;
// a snake_case identifier with at least two underscores: theorem-shaped, and
// unlikely to collide with ordinary prose or with file names
const thmRe = /\b([a-z][a-z0-9]*(?:_[a-z0-9]+){2,})\b/g;

function citationsOf(text) {
  const cites = [];
  let m;
  pathRe.lastIndex = 0;
  while ((m = pathRe.exec(text))) {
    const rel = m[1];
    cites.push({ kind: "path", raw: rel, ok: fs.existsSync(path.join(REPO, rel)) });
  }
  thmRe.lastIndex = 0;
  while ((m = thmRe.exec(text))) {
    const id = m[1];
    if (/\.(lean|sh|js|json|md)$/.test(id)) continue;
    cites.push({ kind: "thm", raw: id, ok: theoremNames.has(id) });
  }
  return cites;
}

function readArm(arm) {
  const d = path.join(CORPUS, "arm" + arm);
  const out = new Map();
  let files = [];
  try { files = fs.readdirSync(d).filter(f => /^turn-\d+\.json$/.test(f)); } catch (e) { return null; }
  for (const f of files) {
    let j = null;
    try { j = JSON.parse(fs.readFileSync(path.join(d, f), "utf8")); } catch (e) { continue; }
    if (!j || typeof j.result !== "string" || !j.result.trim()) continue;
    out.set(Number(f.slice(5, 8)), j.result);
  }
  return out;
}

const A = readArm("a"), B = readArm("b");
if (!A || !B) { console.log("NOCORPUS"); process.exit(3); }
const turns = [...A.keys()].filter(k => B.has(k)).sort((x, y) => x - y);
if (!turns.length) { console.log("NOCORPUS"); process.exit(3); }

function armStats(M) {
  let cited = 0, valid = 0, turnsWith = 0, turnsWithout = 0, hallucTurns = 0, chars = 0;
  for (const t of turns) {
    const txt = M.get(t); chars += txt.length;
    const c = citationsOf(txt);
    if (!c.length) { turnsWithout++; continue; }
    turnsWith++; cited += c.length;
    const good = c.filter(x => x.ok).length;
    valid += good;
    if (good < c.length) hallucTurns++;
  }
  return { cited, valid, precision: cited ? valid / cited : null,
           turnsWith, turnsWithout, hallucTurns, meanChars: Math.round(chars / turns.length) };
}

const sa = armStats(A), sb = armStats(B);

// ---- paired comparison, only on turns where BOTH arms cite something -------
let aBetter = 0, bBetter = 0, tie = 0, paired = 0;
const examples = [];
for (const t of turns) {
  const ca = citationsOf(A.get(t)), cb = citationsOf(B.get(t));
  if (!ca.length || !cb.length) continue;
  paired++;
  const pa = ca.filter(x => x.ok).length / ca.length;
  const pb = cb.filter(x => x.ok).length / cb.length;
  if (pa > pb) { aBetter++; if (examples.length < 3) examples.push({ t, pa: pa.toFixed(2), pb: pb.toFixed(2) }); }
  else if (pb > pa) bBetter++;
  else tie++;
}

// ---- VOLUME-MATCHED: the selectivity control -------------------------------
// Precision is a ratio, so raw length cannot inflate it. But an arm that makes
// FEWER claims per turn has fewer chances to be wrong, and the routed arm does
// exactly that (1.42 citations/turn against 2.47). That is a second confound
// wearing the first one's coat, and it must be tested, not waved away.
//
// So compare ONLY the turns where both arms cited the SAME NUMBER of items.
// Claim volume is then held constant by construction and the sole remaining
// difference is how many of those claims were true.
let vmA = 0, vmB = 0, vmTie = 0, vmPairs = 0;
for (const t of turns) {
  const ca = citationsOf(A.get(t)), cb = citationsOf(B.get(t));
  if (!ca.length || !cb.length) continue;
  if (ca.length !== cb.length) continue;
  vmPairs++;
  const ga = ca.filter(x => x.ok).length, gb = cb.filter(x => x.ok).length;
  if (ga > gb) vmA++; else if (gb > ga) vmB++; else vmTie++;
}

function signP(k, n) {
  if (n === 0) return 1;
  const C = (n, k) => { let r = 1; for (let i = 0; i < k; i++) r = r * (n - i) / (i + 1); return r; };
  let tail = 0;
  const lo = Math.min(k, n - k);
  for (let i = 0; i <= lo; i++) tail += C(n, i);
  return Math.min(1, 2 * tail / Math.pow(2, n));
}
const p = signP(Math.min(aBetter, bBetter), aBetter + bBetter);

console.log(JSON.stringify({
  turns: turns.length,
  theoremNamesKnown: theoremNames.size,
  routed:   sa,
  unrouted: sb,
  pairedTurns: paired,
  routedBetter: aBetter, unroutedBetter: bBetter, ties: tie,
  p: p,
  // The verdict is a RATIO comparison, so it is not length-confounded by
  // construction. meanChars is reported so a reader can see the length gap
  // that broke the compliance metric, and confirm it no longer decides.
  significant: p < 0.05,
  routedWins: p < 0.05 && aBetter > bBetter,
  volumeMatched: {
    pairs: vmPairs, routedBetter: vmA, unroutedBetter: vmB, ties: vmTie,
    p: signP(Math.min(vmA, vmB), vmA + vmB),
    survivesSelectivity: signP(Math.min(vmA, vmB), vmA + vmB) < 0.05 && vmA > vmB
  }
}, null, 1));
