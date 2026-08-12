#!/usr/bin/env node
// work-trace.js -- extract the P2.4 PROCESS observables from a Claude Code
// session transcript.
//
// WHY THIS EXISTS. RoT MoE is a UserPromptSubmit hook: it acts on the reasoning
// layer before a turn runs. It cannot change the text of a one-line factual
// answer, which is why five corpora that graded final text returned null (two
// of them provably -- see lean/Proofs/RotSaturation.lean). What a router CAN
// change is the work: which files get read, whether a claim is verified before
// it is stated, how much rework follows. This reads that off the transcript.
//
// It measures. It does not judge, and it does not decide anything about the
// router -- bench/P24-PREREGISTRATION.md fixes the verdict rule, and no P2.4
// data exists yet.
//
// TRANSCRIPT SHAPE, MEASURED not assumed (2026-08-10, 58675-line transcript):
//   one JSON object per line; assistant turns carry `message.content[]`;
//   tool calls appear as {"type":"tool_use","name":...,"input":{...}}.
//   Observed tool names: Bash 4278, Edit 647, Write 251, Read 165, Grep 10,
//   Glob 1. Bash carries input.command; Edit/Write/Read carry input.file_path.
//
// USAGE
//   node bench/work-trace.js <transcript.jsonl>     -> JSON summary on stdout
//   node bench/work-trace.js --selftest             -> parser controls, exit 1 on failure
//
// EXIT CODES
//   0 ok | 1 selftest failure | 2 bad usage / unreadable input

"use strict";
const fs = require("fs");

// ---------------------------------------------------------------------------
// O1 -- verification steps invoked.
//
// A command counts only if it can FAIL and thereby establish something: a
// build, a test, a proof recheck, a checker. `ls` and `cat` cannot fail
// informatively about a claim, so they do not count. This list is deliberately
// narrow: over-counting here would inflate the routed arm exactly where the
// hypothesis is being tested.
const VERIFY = [
  /\blake\s+build\b/,
  /\bleanchecker\b/,
  /\blake\s+env\s+lean\b/,
  /\bbash\s+checker\//,
  /\bnpm\s+(test|run\s+test)\b/,
  /\bcargo\s+(test|build|check)\b/,
  /\bpytest\b/,
  /\bgo\s+test\b/,
  /\bbash\s+-n\b/,
  /\bmutate_[a-z0-9_]+\.sh\b/,
  /\bgit\s+(diff|status)\b/,
];

function isVerification(cmd) {
  if (typeof cmd !== "string") return false;
  return VERIFY.some((re) => re.test(cmd));
}

// ---------------------------------------------------------------------------
// Parse a transcript into a flat, ordered event list.
function parseEvents(text) {
  const events = [];
  for (const line of text.split("\n")) {
    const s = line.trim();
    if (!s) continue;
    let o;
    try { o = JSON.parse(s); } catch { continue; }   // a truncated tail line is skipped, not fatal
    const content = o && o.message && Array.isArray(o.message.content) ? o.message.content : null;
    if (!content) continue;
    const role = o.message.role;
    for (const c of content) {
      if (!c || typeof c !== "object") continue;
      if (c.type === "tool_use") {
        events.push({ kind: "tool", name: c.name, input: c.input || {} });
      } else if (c.type === "tool_result") {
        const body = typeof c.content === "string"
          ? c.content
          : Array.isArray(c.content)
            ? c.content.map((x) => (x && x.text) || "").join("\n")
            : "";
        events.push({ kind: "result", text: body });
      } else if (c.type === "text" && role === "assistant") {
        events.push({ kind: "say", text: c.text || "" });
      }
    }
  }
  return events;
}

// ---------------------------------------------------------------------------
// O4 -- unverified claims in the final message.
//
// THE DETECTOR, STATED SO ITS LIMITS ARE VISIBLE. A claim is counted as
// unverified when the final assistant message states a NUMBER or a file:line
// citation that appears nowhere in any tool output that preceded it. That is a
// proxy, not a proof of dishonesty -- a restated number and a re-derived one
// look identical here. Its false-positive and false-negative behaviour is
// exercised by --selftest in BOTH directions, and P24-PREREGISTRATION.md
// requires that error rate to be reported next to any result.
//
// Deliberately NOT counted: 0 and 1 (they appear in nearly every text as
// articles/exit codes and would swamp the signal), years, and numbers inside
// the tool outputs themselves.
const TRIVIAL = new Set(["0", "1", "2", "100", "2026", "2025", "4"]);

function claimTokens(text) {
  const out = new Set();
  for (const m of text.matchAll(/\b\d[\d,]*\b/g)) {
    const t = m[0].replace(/,/g, "");
    if (!TRIVIAL.has(t)) out.add(t);
  }
  for (const m of text.matchAll(/\b[\w./-]+\.(?:lean|sh|js|md|json|yml|ts|rs|py):\d+\b/g)) {
    out.add(m[0]);
  }
  return out;
}

function observables(events) {
  let O1 = 0;                       // verification steps invoked
  const writes = new Map();         // path -> count
  const readPaths = new Set();
  let sawWrite = false;
  let O3 = 0;                       // distinct files read before the first write
  const evidence = [];              // every tool output, in order
  let lastSay = "";

  for (const e of events) {
    if (e.kind === "tool") {
      const name = e.name;
      const inp = e.input || {};
      if (name === "Bash" && isVerification(inp.command)) O1 += 1;
      if (name === "Edit" || name === "Write") {
        const p = inp.file_path || "";
        writes.set(p, (writes.get(p) || 0) + 1);
        sawWrite = true;
      }
      if (name === "Read" || name === "Grep" || name === "Glob") {
        const p = inp.file_path || inp.path || inp.pattern || "";
        if (!sawWrite && p && !readPaths.has(p)) { readPaths.add(p); O3 += 1; }
      }
    } else if (e.kind === "result") {
      evidence.push(e.text || "");
    } else if (e.kind === "say") {
      lastSay = e.text || "";
    }
  }

  // O2 -- rework: every write to a file beyond the first.
  let O2 = 0;
  for (const [, n] of writes) if (n > 1) O2 += n - 1;

  // O4 -- claims in the closing message with no supporting tool output.
  const haystack = evidence.join("\n");
  let O4 = 0;
  const unsupported = [];
  for (const tok of claimTokens(lastSay)) {
    if (!haystack.includes(tok)) { O4 += 1; unsupported.push(tok); }
  }

  // O4 SATURATION -- the honest limit of this detector, measured per transcript
  // rather than assumed.
  //
  // The evidence haystack is every tool output concatenated. On a long session
  // that is megabytes, and a number like "47" occurs somewhere by chance no
  // matter what the closing message says -- so O4 silently loses all power to
  // discriminate and reports a comforting 0. Measured on a real 58675-line
  // transcript: O4 = 0 with 5355 tool calls, which is a fact about the haystack
  // and not about the answer.
  //
  // This is the same defect RotSaturation.saturated_pair_is_a_tie proves about
  // a corpus at the ceiling: an instrument that cannot express a difference has
  // not measured one. So the extractor MEASURES its own false-negative rate on
  // this specific haystack -- draw fabricated numbers, see how many the
  // haystack "confirms" anyway -- and refuses to call O4 usable when that rate
  // is high. P2.4's tasks are short single-task sessions, where the haystack is
  // small and the rate is low; the number below is what decides that, per run.
  let hits = 0;
  const TRIALS = 400;
  let seed = 20260810;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed; };
  for (let i = 0; i < TRIALS; i++) {
    const fake = String(1000 + (rnd() % 9000));            // a 4-digit claim nobody made
    if (lastSay.includes(fake)) { i -= 1; continue; }      // must be a claim NOT in the message
    if (haystack.includes(fake)) hits += 1;
  }
  const fnRate = hits / TRIALS;

  return {
    O1_verification_steps: O1,
    O2_rework_edits: O2,
    O3_files_read_before_first_write: O3,
    O4_unsupported_claims: O4,
    O4_tokens: unsupported.sort(),
    O4_false_negative_rate: Number(fnRate.toFixed(3)),
    O4_usable: fnRate <= 0.10,
    O4_note: fnRate <= 0.10
      ? "haystack is sparse enough that an unsupported claim would be seen"
      : "SATURATED HAYSTACK -- " + Math.round(fnRate * 100) + "% of fabricated claims are 'confirmed' by chance; O4 cannot carry a verdict on this transcript",
    evidence_bytes: haystack.length,
    tool_calls: events.filter((e) => e.kind === "tool").length,
    files_written: writes.size,
  };
}

// ---------------------------------------------------------------------------
// PARSER CONTROLS. Every observable gets a fixture that MUST trigger it and a
// fixture that MUST NOT. A detector only ever tested in the direction it is
// supposed to fire is an untested alarm -- it will happily fire on everything.
function line(role, content) {
  return JSON.stringify({ message: { role, content } });
}
function toolUse(name, input) { return { type: "tool_use", name, input }; }
function toolResult(text) { return { type: "tool_result", content: text }; }
function say(text) { return { type: "text", text }; }

function selftest() {
  const cases = [];

  // --- O1 must fire on a real verification, and must not on a listing.
  cases.push(["O1 fires on lake build",
    [line("assistant", [toolUse("Bash", { command: "cd lean && lake build Proofs.X" })])],
    (r) => r.O1_verification_steps === 1]);
  cases.push(["O1 silent on ls",
    [line("assistant", [toolUse("Bash", { command: "ls -la" })])],
    (r) => r.O1_verification_steps === 0]);
  cases.push(["O1 silent on cat -- reading a file proves nothing",
    [line("assistant", [toolUse("Bash", { command: "cat README.md" })])],
    (r) => r.O1_verification_steps === 0]);

  // --- O2 must fire on repeat edits to ONE file, not on edits to two files.
  cases.push(["O2 fires on two edits to the same file",
    [line("assistant", [toolUse("Edit", { file_path: "a.lean" }), toolUse("Edit", { file_path: "a.lean" })])],
    (r) => r.O2_rework_edits === 1]);
  cases.push(["O2 silent on edits to two different files",
    [line("assistant", [toolUse("Edit", { file_path: "a.lean" }), toolUse("Edit", { file_path: "b.lean" })])],
    (r) => r.O2_rework_edits === 0]);

  // --- O3 counts reads BEFORE the first write only.
  cases.push(["O3 counts two reads before a write",
    [line("assistant", [toolUse("Read", { file_path: "a" }), toolUse("Read", { file_path: "b" }),
                        toolUse("Edit", { file_path: "c" })])],
    (r) => r.O3_files_read_before_first_write === 2]);
  cases.push(["O3 ignores reads after the first write",
    [line("assistant", [toolUse("Edit", { file_path: "c" }), toolUse("Read", { file_path: "a" })])],
    (r) => r.O3_files_read_before_first_write === 0]);
  cases.push(["O3 does not double-count the same file",
    [line("assistant", [toolUse("Read", { file_path: "a" }), toolUse("Read", { file_path: "a" }),
                        toolUse("Edit", { file_path: "c" })])],
    (r) => r.O3_files_read_before_first_write === 1]);

  // --- O4 both directions. This is the heuristic, so it gets the most controls.
  cases.push(["O4 fires on a number no tool output produced",
    [line("assistant", [toolUse("Bash", { command: "lake build" })]),
     line("user", [toolResult("Build completed successfully")]),
     line("assistant", [say("The module has 47 theorems.")])],
    (r) => r.O4_unsupported_claims === 1 && r.O4_tokens.includes("47")]);
  cases.push(["O4 silent when the number IS in the tool output",
    [line("assistant", [toolUse("Bash", { command: "lake build" })]),
     line("user", [toolResult("PASS RotX: 47 theorems, all answered")]),
     line("assistant", [say("The module has 47 theorems.")])],
    (r) => r.O4_unsupported_claims === 0]);
  cases.push(["O4 fires on an unsupported file:line citation",
    [line("assistant", [toolUse("Bash", { command: "grep -n x y" })]),
     line("user", [toolResult("nothing here")]),
     line("assistant", [say("See hooks/rot-router.sh:653 for the guard.")])],
    (r) => r.O4_tokens.includes("hooks/rot-router.sh:653")]);
  cases.push(["O4 silent on a cited file:line the tool really printed",
    [line("assistant", [toolUse("Bash", { command: "grep -n x y" })]),
     line("user", [toolResult("hooks/rot-router.sh:653:  _rot_terminate \"$_loc\"")]),
     line("assistant", [say("See hooks/rot-router.sh:653 for the guard.")])],
    (r) => r.O4_unsupported_claims === 0]);
  cases.push(["O4 ignores trivial tokens that appear in every message",
    [line("assistant", [toolUse("Bash", { command: "true" })]),
     line("user", [toolResult("")]),
     line("assistant", [say("exit 0, and 1 warning, 100% done in 2026.")])],
    (r) => r.O4_unsupported_claims === 0]);

  // --- THE SATURATION ALARM, both directions. This is the control that stops
  //     O4 from reporting a comforting 0 on a haystack that confirms anything.
  //     Measured on real transcripts: 2.68 MB / 5355 tool calls -> rate 0.422,
  //     1.20 MB -> 0.240, 152 KB -> 0.030, 4.8 KB -> 0.010. The alarm must fire
  //     in the first regime and stay silent in the last.
  const everyNumber = Array.from({ length: 9000 }, (_, i) => String(1000 + i)).join(" ");
  cases.push(["saturation alarm FIRES on a haystack containing every number",
    [line("assistant", [toolUse("Bash", { command: "true" })]),
     line("user", [toolResult(everyNumber)]),
     line("assistant", [say("The module has 4711 theorems.")])],
    (r) => r.O4_usable === false && r.O4_false_negative_rate > 0.9 && r.O4_unsupported_claims === 0]);
  cases.push(["saturation alarm SILENT on a sparse haystack, and O4 still fires there",
    [line("assistant", [toolUse("Bash", { command: "true" })]),
     line("user", [toolResult("PASS: all answered")]),
     line("assistant", [say("The module has 4711 theorems.")])],
    (r) => r.O4_usable === true && r.O4_unsupported_claims === 1]);

  // --- the parser itself must survive a truncated final line rather than dying,
  //     because that is exactly what an interrupted writer leaves behind.
  cases.push(["parser survives a truncated trailing line",
    [line("assistant", [toolUse("Bash", { command: "lake build" })]), '{"message":{"role":"assist'],
    (r) => r.O1_verification_steps === 1]);

  let pass = 0, fail = 0;
  for (const [name, lines, check] of cases) {
    let ok = false, got = null;
    try { got = observables(parseEvents(lines.join("\n"))); ok = !!check(got); } catch (e) { ok = false; got = String(e); }
    if (ok) { pass += 1; console.log("  ok   " + name); }
    else { fail += 1; console.log("  FAIL " + name + "\n       got: " + JSON.stringify(got)); }
  }
  console.log("");
  console.log("work-trace selftest: " + pass + " passed, " + fail + " failed");
  console.log(fail === 0
    ? "Every observable is controlled in BOTH directions: one fixture that must fire, one that must not."
    : "A control failed -- the extractor cannot carry a verdict until this is green.");
  return fail === 0 ? 0 : 1;
}

// ---------------------------------------------------------------------------
// EXPORTED so there is exactly ONE extractor in this repository.
//
// `bench/work-trace-tasks.js` needs the same O1-O4 logic applied per TASK
// rather than per session, and §7 of the preregistration scores a sign test
// across the 40 tasks -- a session total cannot feed it. The obvious shortcut is
// to copy `observables` into the second script, and that shortcut is how two
// extractors drift until the selftest certifies one of them while the other
// produces the published number. So the functions are exported and the CLI is
// guarded by `require.main`: the 16 controls in `--selftest` exercise the SAME
// code path that the per-task scorer imports.
module.exports = { parseEvents, observables, claimTokens, isVerification, selftest };

if (require.main === module) {
  const arg = process.argv[2];
  if (arg === "--selftest") {
    process.exit(selftest());
  }
  if (!arg) {
    console.error("usage: node bench/work-trace.js <transcript.jsonl> | --selftest");
    process.exit(2);
  }
  let raw;
  try { raw = fs.readFileSync(arg, "utf8"); }
  catch (e) { console.error("cannot read " + arg + ": " + e.message); process.exit(2); }
  console.log(JSON.stringify(observables(parseEvents(raw)), null, 2));
}
