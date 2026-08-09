#!/usr/bin/env node
// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// =============================================================================
// THE TRAP CORPUS GENERATOR
//
// WHY IT EXISTS. Four answer-quality corpora closed without establishing
// anything, and the cause was never the router -- it was the questions. When
// both arms answer correctly the corpus cannot separate them, and the fourth
// run made that unmissable: 80 items, two reps, an informative band of ONE.
// lean/Proofs/RotTrap.lean proves why (`a_saturated_corpus_has_an_empty_band`)
// and proves that padding with easy items cannot repair it
// (`padding_with_ceiling_items_never_widens_the_band`).
//
// A TRAP is an item where the obvious method returns a SPECIFIC WRONG answer
// and the truth is mechanically derivable. Every family below is a defect that
// was really made in this repository:
//
//   A  naive `grep -c '^theorem'` counts prose inside `/-! -/` doc comments.
//      Found when a first draft of checker/module-claims.sh reported EIGHT
//      stale README claims, seven of which were the README being right.
//   B  `grep -c run_mut` counts the function DEFINITION as if it were a mutant.
//      checker/repo-complete.sh:267 anchors `^run_mut ` for exactly this reason.
//   C  `#guard` appears in prose as often as it appears as an assertion.
//
// THE SELECTION RULE IS THE POINT. Items are chosen by a property of the ITEM
// (naive != truth), never by what either arm answered. RotTrap proves the
// difference matters: `trap_selection_ignores_the_answers` versus
// `circular_selection_cannot_lose`, which shows that selecting on the answers
// reports a clean sweep whatever the router does.
//
// The generator REFUSES to emit a non-trap. A corpus that quietly included
// items where naive == truth would be diluting itself back toward the ceiling
// that killed the previous four runs.
//
// Usage:  node bench/trap-prompts.js [<repoRoot>] > bench/trap-candidates.jsonl
// Env:    ROTMOE_TRAP_MAX   cap, default 60 (deterministic stratified sample)
// =============================================================================

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const ROOT = process.argv[2] || path.resolve(__dirname, "..");
const MAX = Number(process.env.ROTMOE_TRAP_MAX || 60);

const rd = (p) => fs.readFileSync(p, "utf8");
const ls = (d, re) => {
  const full = path.join(ROOT, d);
  if (!fs.existsSync(full)) return [];
  return fs.readdirSync(full).filter((f) => re.test(f)).sort().map((f) => d + "/" + f);
};

// GROUND TRUTH IS NOT REIMPLEMENTED HERE. checker/count-theorems.sh is the one
// definition of "a theorem", it is comment-aware and self-tested, and its own
// header records that copying the rule has had to be undone three times. A
// fourth copy in this file would be the same defect, and it would drive the
// corpus rather than merely misreport it.
function truthTheorems(relFile) {
  const out = execFileSync("bash", [path.join(ROOT, "checker/count-theorems.sh"),
                                    path.join(ROOT, relFile)], { encoding: "utf8" });
  const n = Number(out.trim());
  if (!Number.isInteger(n)) throw new Error("count-theorems gave non-integer for " + relFile + ": " + out);
  return n;
}

const items = [];
let refusedNonTrap = 0;

function push(family, file, question, naive, truth, naiveMethod) {
  if (naive === truth) { refusedNonTrap++; return; }   // not a trap: refuse
  items.push({ family, file, question, naive, truth, naiveMethod });
}

// ---- family A: theorem counts -------------------------------------------
for (const f of ls("lean/Proofs", /\.lean$/)) {
  const src = rd(path.join(ROOT, f));
  const naive = (src.match(/^(private )?theorem /gm) || []).length;
  const truth = truthTheorems(f);
  push("theorem_count", f,
       "How many theorems are declared in " + f + "? Answer with a single integer.",
       naive, truth, "grep -cE '^(private )?theorem '");
}

// ---- family B: mutant counts --------------------------------------------
for (const f of ls("lean/mutate", /^mutate_.*\.sh$/)) {
  const src = rd(path.join(ROOT, f));
  const naive = src.split("\n").filter((l) => l.includes("run_mut")).length;
  const truth = (src.match(/^run_mut(_nth)? [A-Z][A-Za-z0-9]*[0-9] /gm) || []).length;
  push("mutant_count", f,
       "How many mutants does " + f + " actually run? Answer with a single integer.",
       naive, truth, "grep -c run_mut");
}

// ---- family C: guard counts ---------------------------------------------
for (const f of ls("lean/Proofs", /\.lean$/)) {
  const src = rd(path.join(ROOT, f));
  const naive = src.split("\n").filter((l) => l.includes("#guard")).length;
  const truth = (src.match(/^#guard /gm) || []).length;
  push("guard_count", f,
       "How many #guard assertions are in " + f + "? Answer with a single integer.",
       naive, truth, "grep -c '#guard'");
}

// ---- deterministic stratified cap ---------------------------------------
// Even stride within each family, then refill from whatever has headroom, then
// sort by id so the emitted order never depends on iteration order. Same shape
// as bench/calib-prompts.js, for the same reason: a cap that takes the FIRST n
// silently biases toward whichever family sorts first.
const byFam = new Map();
for (const it of items) {
  if (!byFam.has(it.family)) byFam.set(it.family, []);
  byFam.get(it.family).push(it);
}
const fams = [...byFam.keys()].sort();
const per = Math.floor(MAX / fams.length);
let picked = [];
for (const fam of fams) {
  const pool = byFam.get(fam);
  const want = Math.min(per, pool.length);
  if (want === 0) continue;
  const stride = pool.length / want;
  for (let k = 0; k < want; k++) picked.push(pool[Math.floor(k * stride)]);
}
// headroom refill, deterministic
for (const fam of fams) {
  if (picked.length >= MAX) break;
  for (const it of byFam.get(fam)) {
    if (picked.length >= MAX) break;
    if (!picked.includes(it)) picked.push(it);
  }
}
picked = picked.slice(0, MAX);
picked.forEach((it, i) => { it.id = i + 1; });
picked.sort((a, b) => a.id - b.id);

for (const it of picked) process.stdout.write(JSON.stringify(it) + "\n");

process.stderr.write("trap-prompts: " + items.length + " trap(s) available, " +
  picked.length + " emitted, " + refusedNonTrap + " non-trap item(s) REFUSED\n");
for (const fam of fams) {
  process.stderr.write("  " + fam + ": pool=" + byFam.get(fam).length +
    " emitted=" + picked.filter((p) => p.family === fam).length + "\n");
}
