// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// SCORE ONE REP against mechanically re-derived ground truth.
//
//   node bench/calib-score.js <corpusJsonl> <turnsDir> [outJson]
//
// SILENCE IS WRONG, NOT EXCLUDED. The first two metrics both rewarded
// abstention -- a silent answer violates no length rule and makes no false
// citation -- so each of them measured quietness and called it quality. Here a
// turn that does not contain the correct token is WRONG whatever the reason:
// refusal, timeout, empty payload, or a wrong answer.
//
// STALENESS GATE. The corpus carries the answers it was generated with. This
// scorer RE-DERIVES them from the tree and refuses to grade if they disagree,
// because grading yesterday's answers against today's repository silently
// punishes both arms for a change neither of them made.
// =============================================================================
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const [corpusPath, turnsDir, outPath] = process.argv.slice(2);
if (!corpusPath || !turnsDir) {
  console.error("usage: calib-score.js <corpusJsonl> <turnsDir> [outJson]");
  process.exit(2);
}

const corpus = fs.readFileSync(corpusPath, "utf8").trim().split("\n").map(l => JSON.parse(l));
if (corpus.length === 0) { console.error("FATAL: empty corpus -- nothing to grade"); process.exit(2); }

// --- staleness gate ----------------------------------------------------------
// Ground truth is re-derived from the UNCAPPED pool, and the reason is a real
// hazard rather than caution: the cap takes an even stride through each shape,
// so ADDING A MODULE to the tree shifts which items the stride lands on. With a
// capped re-derivation, a frozen item could vanish from `fresh` while its answer
// was still perfectly correct, and the gate would report STALE and refuse to
// grade a run that cost hours of live turns.
//
// The two conditions are not the same thing and must not share a verdict:
//   answer MOVED           -> the item is stale. Refuse. This is the real gate.
//   item no longer SAMPLED -> the cap moved. Says nothing about the item.
// Setting the cap to infinity for the re-derivation leaves only the first.
const gen = path.join(__dirname, "calib-prompts.js");
let fresh = null;
try {
  const raw = execFileSync(process.execPath, [gen], {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    env: Object.assign({}, process.env, { ROTMOE_CALIB_MAX: "999999" }),
  });
  fresh = new Map(raw.trim().split("\n").map(JSON.parse).map(r => [r.prompt, r.answer]));
} catch (e) {
  console.error("FATAL: could not re-derive ground truth: " + e.message);
  process.exit(2);
}
let drift = 0;
for (const r of corpus) {
  const now = fresh.get(r.prompt);
  if (now === undefined) { console.error(`STALE: prompt no longer generated AT ALL (not merely unsampled) -- id ${r.id}`); drift++; }
  else if (now !== r.answer) { console.error(`STALE: id ${r.id} answer moved ${r.answer} -> ${now}`); drift++; }
}
if (drift > 0) {
  console.error(`FATAL: ${drift} of ${corpus.length} item(s) drifted against the tree.`);
  console.error("Refusing to grade. Regenerate the corpus and re-run the calibration.");
  process.exit(2);
}

// --- read the turns ----------------------------------------------------------
// Every failure here scores WRONG -- but they are not the SAME failure, and
// collapsing them to "" would hide which one happened. A run that is 40%
// unparseable is a broken harness; a run that is 40% refusals is a result. The
// reason is carried through to the summary so the two can never be confused.
function readTurn(file) {
  if (!fs.existsSync(file)) return { text: "", reason: "missing" };
  let raw;
  try { raw = fs.readFileSync(file, "utf8"); }
  catch (e) { return { text: "", reason: "unreadable:" + e.code }; }
  let j;
  try { j = JSON.parse(raw); }
  catch (e) { return { text: "", reason: raw.trim() ? "unparseable" : "empty-file" }; }
  const t = String(j.result ?? j.error ?? "");
  if (!t.trim()) return { text: "", reason: j.error ? "error-empty" : "empty-result" };
  return { text: t, reason: j.is_error ? "error-payload" : "ok" };
}

// A token match, anchored so "1" cannot be hit by an unrelated "10".
function hit(answer, text) {
  if (!text) return false;
  const esc = answer.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(`(^|[^A-Za-z0-9_.])${esc}([^A-Za-z0-9_]|$)`).test(text);
}

const files = fs.readdirSync(turnsDir).filter(f => /^turn-\d+\.json$/.test(f)).sort();
const results = [];
const reasons = {};
let correct = 0, silent = 0, totalChars = 0;
for (let i = 0; i < corpus.length; i++) {
  const item = corpus[i];
  const f = path.join(turnsDir, `turn-${String(i + 1).padStart(3, "0")}.json`);
  const { text, reason } = readTurn(f);
  reasons[reason] = (reasons[reason] || 0) + 1;
  if (!text.trim()) silent++;
  totalChars += text.length;
  const ok = hit(item.answer, text);
  if (ok) correct++;
  results.push({ id: item.id, kind: item.kind, correct: ok, chars: text.length, reason });
}

const summary = {
  corpus: corpusPath, turns: turnsDir,
  n: corpus.length, filesFound: files.length,
  correct, wrong: corpus.length - correct,
  silent, accuracy: +(correct / corpus.length).toFixed(4),
  meanChars: Math.round(totalChars / corpus.length),
  reasons,
  results
};
// A harness failure and a wrong answer are both scored WRONG, but only one of
// them is a RESULT. Say which happened, loudly, before any verdict is drawn.
const broken = (reasons["missing"] || 0) + (reasons["unparseable"] || 0) +
               (reasons["unreadable"] || 0) + (reasons["empty-file"] || 0);
if (broken > 0) {
  console.log(`WARNING: ${broken}/${corpus.length} turn(s) failed at the HARNESS level ` +
              `(${JSON.stringify(reasons)}). They are scored wrong, but they measure the ` +
              `harness, not the arm.`);
}
if (outPath) fs.writeFileSync(outPath, JSON.stringify(summary, null, 1));
console.log(`${correct}/${corpus.length} correct (${(100 * correct / corpus.length).toFixed(1)}%), ` +
            `${silent} silent, mean ${summary.meanChars} chars, ${files.length} turn file(s) found`);
if (files.length < corpus.length) {
  console.log(`NOTE: ${corpus.length - files.length} turn file(s) MISSING -- scored WRONG, not skipped.`);
}
