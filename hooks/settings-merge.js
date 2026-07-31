// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// ============================================================================
// settings-merge.js -- the ONE merge engine, shared by both installer arms.
//
// WHY THIS FILE EXISTS AS A SEPARATE FILE.
//
// The spec requires ARM_ROUTER.sh and ARM_ROUTER.ps1 to honour "the same
// contract". The tempting reading is "write it twice and keep them in step",
// and that is how the two arms of a thing drift: PowerShell's ConvertTo-Json
// and node's JSON.stringify do not agree on escaping, key order or depth
// handling, so two installers written natively would produce DIFFERENT BYTES
// from identical inputs while both looking correct.
//
// The router keeps two independent implementations ON PURPOSE -- there, the
// agreement of two arms is the evidence, and a shared bug would have to be
// written twice. The installer is the opposite case: there is nothing to
// cross-check, the file it edits is the user's session, and byte-divergence is
// pure risk. So the router is duplicated and the merge is shared, deliberately,
// for opposite reasons.
//
// node is available wherever this matters: Claude Code is itself a Node
// application. Measured on the development machine, python/python3/py are all
// absent; node is not a lucky dependency here, it is the platform.
//
// Usage:  node settings-merge.js <arm|disarm> <settings-path> <command-string>
// Exit:   0 changed · 10 nothing to do · 3 input invalid · 4 validation failed
// ============================================================================

"use strict";
const fs = require("fs");

const [, , mode, file, cmd] = process.argv;
if (!mode || !file || !cmd) {
  console.error("usage: settings-merge.js <arm|disarm> <settings.json> <command>");
  process.exit(2);
}
const EVENTS = ["UserPromptSubmit", "PreToolUse"];

// --- read, preserving every encoding decision the file already made ---------
const raw = fs.readFileSync(file, "utf8");
const hadBOM = raw.charCodeAt(0) === 0xFEFF;
const body = hadBOM ? raw.slice(1) : raw;
const hadNL = body.endsWith("\n");

// Indent is DETECTED, not assumed. Hardcoding 2 would silently reformat a file
// indented with 4 spaces or tabs -- a whole-file diff on a file we were told to
// preserve. Honest limit: JSON.stringify cannot reproduce INTRA-LINE layout, so
// `"env": { "A": "b" }` on one line comes back expanded. Values, keys, order,
// BOM and indent width survive; compact inline objects do not.
const im = body.match(/\n([ \t]+)"/);
const indent = im ? (im[1][0] === "\t" ? "\t" : im[1].length) : 2;

let s;
try {
  s = JSON.parse(body);
} catch (e) {
  console.error("  FATAL: settings.json does not parse BEFORE we touch it: " + e.message);
  console.error("  Refusing to write. Nothing has been changed.");
  process.exit(3);
}
const before = JSON.parse(JSON.stringify(s));

// --- the edit ---------------------------------------------------------------
let touched = [];

if (mode === "arm") {
  const alreadyIn = (ev) =>
    ((s.hooks && s.hooks[ev]) || []).some(g => (g.hooks || []).some(h => h.command === cmd));
  s.hooks = s.hooks || {};
  for (const ev of EVENTS) {
    s.hooks[ev] = s.hooks[ev] || [];
    if (alreadyIn(ev)) { console.log("  " + ev + ": already armed, skipping"); continue; }
    // APPEND a NEW group. Appending into an existing group would mutate an
    // object the user owns; adding one leaves every existing group untouched
    // and lands at the END, so the user's own hooks keep firing first.
    s.hooks[ev].push({ matcher: "*", hooks: [{ type: "command", command: cmd }] });
    touched.push(ev);
  }
  if (touched.length === 0) { console.log("  nothing to do -- already armed on every event"); process.exit(10); }
} else if (mode === "disarm") {
  let removed = 0;
  for (const ev of Object.keys(s.hooks || {})) {
    const groups = s.hooks[ev];
    if (!Array.isArray(groups)) continue;
    const keep = [];
    let removedHere = 0;
    for (const g of groups) {
      if (!Array.isArray(g.hooks)) { keep.push(g); continue; }
      const had = g.hooks.some(h => h.command === cmd);
      const n = g.hooks.length;
      // Remove ONLY our exact command string. An uninstaller that took a
      // neighbour with it would satisfy "the router is gone" perfectly while
      // destroying the user's setup.
      g.hooks = g.hooks.filter(h => h.command !== cmd);
      removedHere += n - g.hooks.length;
      // Drop a group ONLY if WE emptied it. A group the user left empty stays
      // empty: tidying it is a change to a key this script did not come to touch.
      if (had && g.hooks.length === 0) continue;
      keep.push(g);
    }
    removed += removedHere;
    if (removedHere > 0) {
      s.hooks[ev] = keep;
      if (keep.length === 0) delete s.hooks[ev];
      touched.push(ev);
    }
  }
  if (removed === 0) { console.log("  not armed -- nothing to remove"); process.exit(10); }
  console.log("  removed    : " + removed + " router hook entr" + (removed === 1 ? "y" : "ies"));
} else {
  console.error("  unknown mode: " + mode);
  process.exit(2);
}

// --- write ------------------------------------------------------------------
let out = JSON.stringify(s, null, indent);
if (hadNL) out += "\n";
if (hadBOM) out = "﻿" + out;
fs.writeFileSync(file, out, "utf8");
if (mode === "arm") console.log("  armed on   : " + touched.join(", "));

// --- VALIDATE by re-reading from disk ---------------------------------------
// Not by trusting the object we just serialised: a writer bug lives between
// those two things.
const raw2 = fs.readFileSync(file, "utf8");
const body2 = raw2.charCodeAt(0) === 0xFEFF ? raw2.slice(1) : raw2;
let after;
try { after = JSON.parse(body2); }
catch (e) { console.error("  VALIDATION FAILED: written file does not parse: " + e.message); process.exit(4); }
if ((raw2.charCodeAt(0) === 0xFEFF) !== hadBOM) {
  console.error("  VALIDATION FAILED: BOM state changed"); process.exit(4);
}

if (mode === "arm") {
  // Remove exactly what we added, then require deep equality with the snapshot.
  // This is the strong form of preservation: not "the four critical keys
  // survived" but "NOTHING survived differently" -- the version that still
  // holds the day a fifth critical key appears.
  const stripped = JSON.parse(JSON.stringify(after));
  for (const ev of touched) {
    stripped.hooks[ev] = stripped.hooks[ev].filter(
      g => !((g.hooks || []).some(h => h.command === cmd)));
    if (stripped.hooks[ev].length === 0 && !(before.hooks && before.hooks[ev])) delete stripped.hooks[ev];
  }
  if (Object.keys(stripped.hooks || {}).length === 0 && !before.hooks) delete stripped.hooks;
  const a = JSON.stringify(stripped), b = JSON.stringify(before);
  if (a !== b) {
    console.error("  VALIDATION FAILED: a pre-existing value changed.");
    console.error("  before: " + b.slice(0, 400));
    console.error("  after : " + a.slice(0, 400));
    process.exit(4);
  }
  console.log("  validated  : every pre-existing key byte-identical (deep compare)");
}
process.exit(0);
