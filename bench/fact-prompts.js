// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// GENERATE A FACT CORPUS WITH MECHANICAL GROUND TRUTH.
//
// WHY A THIRD CORPUS. The first two metrics both rewarded ABSTENTION:
//
//   compliance  routed won by producing shorter answers  (brevity confound)
//   grounding   routed won by making fewer claims        (selectivity confound)
//
// Both dissolved under their own control. The defect they share is that saying
// nothing is never punished -- a silent answer violates no length rule and
// makes no false citation. So neither can distinguish "better" from "quieter".
//
// This corpus punishes silence. Every prompt has exactly one correct answer,
// derived from the repository BY THIS SCRIPT rather than by any model, and a
// turn that does not contain that answer is WRONG. Not excluded. Wrong.
//
// TWO QUESTION SHAPES, both exactly checkable:
//
//   count  "how many theorem declarations does <file> contain"  -> an integer
//   name   "what is the name of the LAST theorem in <file>"     -> an identifier
//
// The name form is preferred because a long snake_case identifier cannot be hit
// by accident, whereas a small integer sometimes can. Counts are kept anyway,
// with a guard: a count prompt is only emitted when the true count is >= 4, so
// "1" or "2" appearing incidentally in prose cannot score a false hit.
//
// GROUND TRUTH IS RE-DERIVED AT SCORING TIME, not trusted from this file, so a
// corpus that goes stale against the repo fails loudly instead of silently
// grading against yesterday's tree.
//
// usage: node bench/fact-prompts.js > bench/fact-prompts.jsonl
// =============================================================================
const fs = require("fs");
const path = require("path");

const REPO = path.resolve(__dirname, "..");
const PROOFS = path.join(REPO, "lean", "Proofs");

// STRIP LEAN BLOCK COMMENTS BEFORE EXTRACTING ANYTHING.
//
// Measured: without this, `lean/Proofs/RotVacuity.lean:35` yielded the theorem
// name "at" -- because that line is PROSE inside a `/- -/` doc comment that
// happens to begin with the word "theorem". The corpus would then have graded a
// correct answer as wrong and a hallucination as right, in both arms, silently.
// A ground truth that is itself wrong is worse than no metric.
//
// Nesting-aware: Lean permits `/- ... /- ... -/ ... -/`.
function stripBlockComments(txt) {
  let out = "", depth = 0;
  for (let i = 0; i < txt.length; i++) {
    if (txt[i] === "/" && txt[i + 1] === "-") { depth++; i++; continue; }
    if (txt[i] === "-" && txt[i + 1] === "/" && depth > 0) { depth--; i++; continue; }
    // keep newlines so line-oriented reasoning about the file still lines up
    if (depth === 0) out += txt[i];
    else if (txt[i] === "\n") out += "\n";
  }
  return out;
}

function facts(file) {
  const rel = "lean/Proofs/" + file;
  const txt = stripBlockComments(fs.readFileSync(path.join(PROOFS, file), "utf8"));
  const names = [];
  const re = /^theorem\s+([A-Za-z_][A-Za-z0-9_']*)/gm;
  let m; while ((m = re.exec(txt))) names.push(m[1]);
  return { rel, count: names.length, last: names[names.length - 1], names };
}

const files = fs.readdirSync(PROOFS).filter(f => f.endsWith(".lean")).sort();
const out = [];
let n = 0;

for (const f of files) {
  const F = facts(f);
  if (!F.last) continue;

  // NAME form -- a distinctive identifier, no accidental hits
  n++;
  out.push({
    n, kind: "name", file: F.rel, expect: F.last,
    prompt: "In this repository, read " + F.rel +
            " and answer with ONLY the exact name of the LAST theorem declared in it. " +
            "A declaration is a line beginning with the word theorem, OUTSIDE any /- -/ " +
            "comment block. No explanation, just the identifier."
  });

  // COUNT form -- only when the answer is >= 4, so small numbers in prose
  // cannot score a false hit
  if (F.count >= 4) {
    n++;
    out.push({
      n, kind: "count", file: F.rel, expect: String(F.count),
      prompt: "In this repository, count the lines in " + F.rel +
              " that begin with the word theorem and are OUTSIDE any /- -/ comment block, " +
              "and answer with ONLY that number."
    });
  }
}

for (const o of out) process.stdout.write(JSON.stringify(o) + "\n");
process.stderr.write("generated " + out.length + " prompts over " + files.length + " modules\n");
