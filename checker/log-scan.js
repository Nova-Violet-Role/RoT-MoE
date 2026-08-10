// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// Report `<lines> <recovered> <corrupt>` for a JSONL debug log.
//
//   node checker/log-scan.js <file> [window]
//
// RECOVERED is the metric that matters, and it is not the complement of
// corrupt in any useful sense. `RotLogAtomicity.corrupt_line_count_cannot_
// tell_them_apart` proves the naive and the safe writer leave the SAME number
// of corrupt lines behind; only the recovered-record count separates them.
// A gate built on corrupt lines would have scored the repair as worthless.
//
// With `window`, only the last N lines are considered -- the current writer's
// behaviour, as opposed to history that can only be rotated out.
//
// Exits 2 on a missing file rather than printing zeros: a scanner that reports
// a clean log for a file that is not there is a false green by construction.

const fs = require("fs");

const file = process.argv[2];
const window = process.argv[3] ? parseInt(process.argv[3], 10) : 0;

if (!file) { console.error("usage: node log-scan.js <file> [window]"); process.exit(2); }
if (!fs.existsSync(file)) { console.error("log-scan: no such file: " + file); process.exit(2); }

let text;
try { text = fs.readFileSync(file, "utf8"); }
catch (e) { console.error("log-scan: unreadable: " + e.code); process.exit(2); }

if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);

let lines = text.split(String.fromCharCode(10)).filter((s) => s.length > 0);
if (window > 0 && lines.length > window) lines = lines.slice(-window);

let recovered = 0, corrupt = 0;
for (const line of lines) {
  let obj;
  try { obj = JSON.parse(line); }
  catch { corrupt++; continue; }
  // A line that parses but is not an object is not a record either. Two fused
  // records can, in rare shapes, still parse -- the live log held 27 lines
  // carrying two `"kind"` keys, and JSON.parse keeps the LAST one silently.
  // Counting those as recovered would overstate the health of the file.
  if (obj === null || typeof obj !== "object" || Array.isArray(obj)) { corrupt++; continue; }
  recovered++;
}

console.log(lines.length + " " + recovered + " " + corrupt);
