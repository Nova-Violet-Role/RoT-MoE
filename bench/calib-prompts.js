// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// CANDIDATE POOL FOR THE CALIBRATED CORPUS (metric four).
//
// WHY A FOURTH CORPUS. Three metrics, three different failures:
//
//   compliance  routed 29-4   27/29 wins were merely SHORTER answers
//   grounding   routed 8-0    18/18 tie once claim VOLUME is matched
//   facts       84-84         CEILING: zero discordant pairs, no power
//
// The third failed because every prompt was too easy: both arms answered all 84
// correctly, so the sign test had nothing to work with. `RotCeiling.lean` proves
// that is `noPower`, not a null. The repair is to select items whose BASELINE
// accuracy sits strictly between floor and ceiling -- proved sound in
// `RotCalibration.lean` before this file was written.
//
// THIS FILE ONLY EMITS CANDIDATES. It does not decide which ones count. The
// calibration pass (bench/calib-run.sh) measures the UNROUTED arm on each
// candidate three times and keeps only those with 0 < correct < 3. Selection
// therefore never sees the routed arm -- `circular_selection_cannot_lose` is
// what happens if it does.
//
// DIFFICULTY IS DELIBERATELY MIXED. Easy shapes are included on purpose: if the
// band filter is working, it must DROP them. A pool that was hand-tuned to be
// hard would be selection by intuition, which is the thing calibration replaces.
//
// GROUND TRUTH IS RE-DERIVED AT SCORING TIME from the same functions here, so a
// corpus that goes stale against the tree fails loudly instead of grading
// against yesterday's repository.
//
// usage: node bench/calib-prompts.js > bench/calib-prompts.jsonl
// =============================================================================
const fs = require("fs");
const path = require("path");

// ROTMOE_REPO exists so this generator can be exercised from a scratch copy
// before it is installed into bench/. It changes WHICH tree is read, never what
// counts as a correct answer -- the scorer re-derives ground truth with these
// same functions against the same root, so a mismatch fails loudly.
const REPO = process.env.ROTMOE_REPO
  ? path.resolve(process.env.ROTMOE_REPO)
  : path.resolve(__dirname, "..");
const PROOFS = path.join(REPO, "lean", "Proofs");
const MUTATE = path.join(REPO, "lean", "mutate");

// Nesting-aware Lean block-comment stripper. Measured defect this prevents:
// `RotVacuity.lean:35` is PROSE inside a `/- -/` block that begins with the word
// "theorem", and a naive line scan extracted a theorem named "at". A ground
// truth that is itself wrong is worse than no metric.
function stripBlockComments(txt) {
  let out = "", depth = 0;
  for (let i = 0; i < txt.length; i++) {
    if (txt[i] === "/" && txt[i + 1] === "-") { depth++; i++; continue; }
    if (txt[i] === "-" && txt[i + 1] === "/" && depth > 0) { depth--; i++; continue; }
    if (depth === 0) out += txt[i];
    else if (txt[i] === "\n") out += "\n";
  }
  return out;
}

const modules = fs.readdirSync(PROOFS).filter(f => f.endsWith(".lean")).sort();

function bodyOf(m) {
  return stripBlockComments(fs.readFileSync(path.join(PROOFS, m), "utf8"));
}
function theoremsOf(m) {
  return bodyOf(m).split("\n")
    .map(l => (l.match(/^theorem\s+([A-Za-z_][A-Za-z0-9_']*)/) || [])[1])
    .filter(Boolean);
}
function guardsOf(m) {
  return bodyOf(m).split("\n").filter(l => /^#guard\b/.test(l)).length;
}
function importsOf(m) {
  return bodyOf(m).split("\n")
    .map(l => (l.match(/^import\s+(\S+)/) || [])[1]).filter(Boolean);
}
function defsOf(m) {
  return bodyOf(m).split("\n")
    .map(l => (l.match(/^def\s+([A-Za-z_][A-Za-z0-9_']*)/) || [])[1]).filter(Boolean);
}

const out = [];
let id = 0;
const add = (kind, prompt, answer) => {
  if (answer === undefined || answer === null || answer === "") return;
  out.push({ id: ++id, kind, prompt, answer: String(answer) });
};

// --- shape 1: the Nth theorem (difficulty rises with N) ----------------------
for (const m of modules) {
  const ts = theoremsOf(m);
  if (ts.length < 6) continue;
  for (const n of [1, Math.ceil(ts.length / 2), ts.length]) {
    add("nth_theorem",
      `In the file lean/Proofs/${m} of this repository, consider only lines that ` +
      `begin with the word "theorem" and are OUTSIDE any /- -/ comment block. ` +
      `Counting from 1, what is the name of theorem number ${n}? ` +
      `Answer with the identifier only.`,
      ts[n - 1]);
  }
}

// --- shape 2: how many mutants a suite declares ------------------------------
for (const f of fs.readdirSync(MUTATE).filter(x => /^mutate_.*\.sh$/.test(x)).sort()) {
  const n = (fs.readFileSync(path.join(MUTATE, f), "utf8").match(/^run_mut /gm) || []).length;
  if (n < 4) continue;
  add("mutant_count",
    `In this repository, how many \`run_mut\` invocations does the file ` +
    `lean/mutate/${f} contain? Answer with the integer only.`, n);
}

// --- shape 3: a global maximum -- requires scanning every module -------------
{
  let best = null, bestN = -1;
  for (const m of modules) {
    const n = theoremsOf(m).length;
    if (n > bestN) { bestN = n; best = m; }
  }
  add("max_module",
    `Across every .lean file in lean/Proofs of this repository, counting only ` +
    `lines that begin with "theorem" OUTSIDE any /- -/ comment block, which ` +
    `file has the most? Answer with the file name only, including the .lean ` +
    `extension.`, best);
  add("max_module_count",
    `Across every .lean file in lean/Proofs of this repository, counting only ` +
    `lines that begin with "theorem" OUTSIDE any /- -/ comment block, how many ` +
    `does the file with the MOST have? Answer with the integer only.`, bestN);
}

// --- shape 4: #guard counts ---------------------------------------------------
for (const m of modules) {
  const g = guardsOf(m);
  if (g < 4) continue;
  add("guard_count",
    `In the file lean/Proofs/${m} of this repository, how many lines begin with ` +
    `"#guard" outside any /- -/ comment block? Answer with the integer only.`, g);
}

// --- shape 5: the single import of a module ----------------------------------
for (const m of modules) {
  const im = importsOf(m);
  if (im.length !== 1) continue;
  add("single_import",
    `The file lean/Proofs/${m} in this repository has exactly one import. ` +
    `What is the full module name it imports? Answer with the module name only.`,
    im[0]);
}

// --- shape 6: which module declares a def with this name ---------------------
{
  const owner = new Map();
  for (const m of modules) for (const d of defsOf(m)) {
    if (!owner.has(d)) owner.set(d, new Set());
    owner.get(d).add(m);
  }
  const unique = [...owner.entries()].filter(([, s]) => s.size === 1).map(([d, s]) => [d, [...s][0]]);
  // take a deterministic spread rather than all of them
  for (let i = 0; i < unique.length; i += Math.max(1, Math.floor(unique.length / 25))) {
    const [d, m] = unique[i];
    add("def_owner",
      `In this repository, exactly one file under lean/Proofs declares a ` +
      `top-level \`def ${d}\`. Which file is it? Answer with the file name only, ` +
      `including the .lean extension.`, m);
  }
}

// --- shape 7: the line number of a theorem (exact, mechanical) ---------------
for (const m of modules) {
  const raw = bodyOf(m).split("\n");
  const hits = [];
  raw.forEach((l, i) => { const n = (l.match(/^theorem\s+([A-Za-z_][A-Za-z0-9_']*)/) || [])[1]; if (n) hits.push([n, i + 1]); });
  if (hits.length < 6) continue;
  const [name, line] = hits[Math.floor(hits.length / 2)];
  if (line < 4) continue;
  add("theorem_line",
    `In the file lean/Proofs/${m} of this repository, on which line number does ` +
    `the declaration \`theorem ${name}\` begin? Answer with the integer only.`, line);
}

// --- DETERMINISTIC STRATIFIED CAP --------------------------------------------
// 279 candidates x (3 calibration reps + 2 test arms) is 1395 live turns, which
// is not a corpus, it is a week. The pool is capped by taking an EVEN STRIDE
// through each shape, so every shape survives in proportion and the selection
// is a function of the tree alone -- no randomness, no seed to lose, and the
// same tree always yields the same corpus.
//
// THE CAP IS APPLIED BEFORE CALIBRATION SEES ANYTHING, and it cannot look at
// either arm's answers: it is arithmetic over the file listing. That is what
// keeps it outside `selecting_on_the_test_result_also_biases`.
const MAX = Number(process.env.ROTMOE_CALIB_MAX || 80);
const kinds = [...new Set(out.map(r => r.kind))];
const perKind = Math.max(1, Math.floor(MAX / kinds.length));
const capped = [];
for (const k of kinds) {
  const rows = out.filter(r => r.kind === k);
  const stride = Math.max(1, Math.floor(rows.length / perKind));
  for (let i = 0; i < rows.length && capped.filter(r => r.kind === k).length < perKind; i += stride) {
    capped.push(rows[i]);
  }
}
// Any headroom left by shapes with fewer rows than their share goes to the
// largest shapes, in order, so the cap is filled rather than merely respected.
if (capped.length < MAX) {
  for (const r of out) {
    if (capped.length >= MAX) break;
    if (!capped.includes(r)) capped.push(r);
  }
}
capped.sort((a, b) => a.id - b.id);

for (const r of capped) process.stdout.write(JSON.stringify(r) + "\n");
process.stderr.write(`candidates: ${capped.length} (of ${out.length} generated, cap ${MAX})\n`);
const byKind = {};
for (const r of capped) byKind[r.kind] = (byKind[r.kind] || 0) + 1;
process.stderr.write(Object.entries(byKind).map(([k, v]) => `  ${k}: ${v}`).join("\n") + "\n");
