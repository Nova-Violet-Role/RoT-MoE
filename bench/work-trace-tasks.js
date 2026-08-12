#!/usr/bin/env node
// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// ===========================================================================
// P2.4 OBSERVABLES, PER TASK -- because a session total cannot feed the rule.
//
// THE DEFECT THIS EXISTS TO FIX. `bench/work-trace.js` extracts O1-O4 from a
// transcript and was run, correctly, over each arm's whole 40-turn session. But
// §7 of bench/P24-PREREGISTRATION.md scores "a two-sided sign test across the 40
// tasks" -- it needs a PAIR per task, and four session totals cannot produce
// forty pairs. Reporting the session totals as the P2.4 result would be
// answering a different question than the one preregistered, which is the exact
// substitution the preregistration exists to prevent.
//
// SEGMENTATION, MEASURED NOT ASSUMED. In the Claude Code transcript format a
// task prompt is a record with `type === "user"` whose `message.content` is a
// STRING; every tool result is also `type === "user"` but carries an ARRAY.
// Measured on the four main-run transcripts: 40 string-content user records per
// session, exactly matching the 40-task corpus, against 49 array-content ones in
// the same file. The distinction is the segmentation, and this script REFUSES
// rather than guesses if the count is not exactly 40.
//
// ONE EXTRACTOR. `observables` and `parseEvents` are imported from
// work-trace.js, never copied, so the 16 controls in its `--selftest` exercise
// the same code path that produces these numbers.
//
// exit: 0 ok | 2 bad usage / unreadable | 3 segmentation did not yield 40 tasks
// ===========================================================================
"use strict";

const fs = require("fs");
const path = require("path");
const { parseEvents, observables } = require("./work-trace.js");

// --- the corpus, in its frozen order ---------------------------------------
function loadCorpus(root) {
  const p = path.join(root, "bench", "corpus-40.jsonl");
  const lines = fs.readFileSync(p, "utf8").split("\n").map((s) => s.trim()).filter(Boolean);
  if (lines.length !== 40) {
    console.error("corpus-40.jsonl has " + lines.length + " lines, expected exactly 40");
    process.exit(2);
  }
  return lines.map((l) => JSON.parse(l));
}

// --- segmentation -----------------------------------------------------------
// Returns an array of arrays of raw transcript lines, one per task, in the order
// the session ran them.
function segment(raw) {
  const out = [];
  let cur = null;
  for (const line of raw.split("\n")) {
    const s = line.trim();
    if (!s) continue;
    let o;
    try { o = JSON.parse(s); } catch { continue; }
    const isPrompt = o && o.type === "user" && o.message && typeof o.message.content === "string";
    if (isPrompt) {
      if (cur) out.push(cur);
      cur = [s];
    } else if (cur) {
      cur.push(s);
    }
    // records before the first prompt are session scaffolding and belong to no task
  }
  if (cur) out.push(cur);
  return out;
}

// The corpus index a given execution position maps to. Identical convention to
// bench/main-score.js: forward runs task 1..40 in order, reverse runs 40..1, so
// position k (1-based) is corpus index k-1 forward and 40-k reverse. Stated as
// one function so the two scripts cannot drift apart on it.
function corpusIndexOf(position, ordering) {
  return ordering === "forward" ? position - 1 : 40 - position;
}

function main() {
  const [, , transcript, ordering, arm] = process.argv;
  if (!transcript || !ordering || !arm) {
    console.error("usage: node bench/work-trace-tasks.js <transcript.jsonl> <forward|reverse> <routed|unrouted>");
    process.exit(2);
  }
  if (ordering !== "forward" && ordering !== "reverse") {
    console.error("ordering must be exactly 'forward' or 'reverse', got: " + ordering);
    process.exit(2);
  }
  if (arm !== "routed" && arm !== "unrouted") {
    console.error("arm must be exactly 'routed' or 'unrouted', got: " + arm);
    process.exit(2);
  }

  let raw;
  try { raw = fs.readFileSync(transcript, "utf8"); }
  catch (e) { console.error("cannot read " + transcript + ": " + e.message); process.exit(2); }

  const root = path.join(__dirname, "..");
  const corpus = loadCorpus(root);
  const tasks = segment(raw);

  if (tasks.length !== 40) {
    console.error("SEGMENTATION REFUSED: " + tasks.length + " task segment(s), expected exactly 40.");
    console.error("A transcript that does not split into 40 tasks cannot be paired against the");
    console.error("frozen corpus, and guessing an alignment would fabricate the pairing that the");
    console.error("sign test depends on. Nothing is emitted.");
    process.exit(3);
  }

  for (let k = 1; k <= 40; k++) {
    const idx = corpusIndexOf(k, ordering);
    const obs = observables(parseEvents(tasks[k - 1].join("\n")));
    process.stdout.write(JSON.stringify({
      ordering,
      arm,
      position: k,
      task: corpus[idx].id,
      O1: obs.O1_verification_steps,
      O2: obs.O2_rework_edits,
      O3: obs.O3_files_read_before_first_write,
      O4: obs.O4_unsupported_claims,
      O4_usable: obs.O4_usable,
      O4_false_negative_rate: obs.O4_false_negative_rate,
      tool_calls: obs.tool_calls,
      evidence_bytes: obs.evidence_bytes,
      files_written: obs.files_written
    }) + "\n");
  }
}

if (require.main === module) main();
module.exports = { segment, corpusIndexOf };
