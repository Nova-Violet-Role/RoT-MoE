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
// Usage:  node settings-merge.js <arm|disarm|disarm-any> <settings-path> <command-string>
// Exit:   0 changed · 10 nothing to do · 3 input invalid · 4 validation failed
//
// ----------------------------------------------------------------------------
// WHY `disarm-any` EXISTS, and why it is a SEPARATE mode rather than a relaxed
// `disarm`.
//
// `disarm` matches the command string EXACTLY, rebuilt from the directory the
// uninstaller was run from. Measured consequence on a real machine: the entry in
// settings.json pointed at the INSTALLED PLUGIN
//
//     .../.claude/plugins/cache/rot-moe/rot-moe/<ver>/hooks/rot-router.ps1
//
// while DISARM was run from a source checkout. It reported `nothing to remove`
// and the entry stayed -- permanently, with the uninstaller exiting 0. An
// uninstaller that cannot remove what the documented install produces is not an
// uninstaller.
//
// The two modes are kept apart on purpose. Exact match is the one with the
// proof (lean/Proofs/RotInstall.lean: `disarm_arm_id` under freshness, and
// `disarm_arm_not_id` showing the hypothesis cannot be dropped); it is what
// runs by default and it can only ever touch the string it wrote. `disarm-any`
// is broader BY DESIGN and therefore opt-in: it removes every hook entry that
// invokes a RoT MoE router script, whatever path or version it names. That is
// exactly what a user with a stale or plugin-path entry needs, and exactly what
// must never happen without being asked for.
// ============================================================================

"use strict";
const fs = require("fs");

const [, , mode, file, cmd, eventsArg] = process.argv;
if (!mode || !file || !cmd) {
  console.error("usage: settings-merge.js <arm|disarm|disarm-any> <settings.json> <command> [events-csv]");
  process.exit(2);
}

// THE EVENT LIST IS A PARAMETER, and it became one for a MEASURED reason.
//
// It was hardcoded to the router's two events. That was correct for the router
// and silently wrong for everything else the plugin registers: comparing
// `hooks/hooks.json` against what this engine writes showed the plugin binding
// FIVE hooks across THREE events (router on UserPromptSubmit + PreToolUse,
// prover-remind on those two AND PostToolUse) while ARM_ROUTER produced TWO.
//
// So a user installing by hand lost the entire proof-reminder organ, including
// the only PostToolUse binding, and nothing reported it -- the installer was
// structurally incapable of writing a third event.
//
// Default preserved so every existing call site behaves exactly as before.
// ONE DEFINITION OF THE BOUND, used by the arm path below and asserted by
// checker/hook-timeout.sh against hooks/hooks.json. Two copies of a number are
// two numbers, and the install paths are required to agree.
const HOOK_TIMEOUT_SECONDS = 18000;

const EVENTS = (eventsArg && eventsArg.trim())
  ? eventsArg.split(",").map(s => s.trim()).filter(Boolean)
  : ["UserPromptSubmit", "PreToolUse"];
if (!EVENTS.length) {
  console.error("  FATAL: an empty event list would arm nothing and report success.");
  process.exit(3);
}


// The default central log path, derived the same way the router derives its
// settings path (rot-router.sh:convener) so the two cannot disagree about where
// a user's configuration lives. Forward slashes: both the POSIX arm and
// PowerShell accept them on every platform this ships to, and a backslash in
// JSON has to be escaped, which is one more thing to get wrong.
const WIN_SEP = String.fromCharCode(92);   // a backslash, spelled without one
const CONFIG_DIR = (process.env.CLAUDE_CONFIG_DIR
  || require("path").join(require("os").homedir(), ".claude")).split(WIN_SEP).join("/");
const DEFAULT_LOG = CONFIG_DIR + "/rot-moe/rot-route-debug.jsonl";
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
let wroteEnv = false;   // the env default is NOT an event; see the verification block

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
    // TIMEOUT IS NOT OPTIONAL, and omitting it is what silenced the router.
    //
    // Claude Code applies a 30 s default when no `timeout` is given, and a hook
    // killed at its limit contributes NOTHING -- no partial output, no marker,
    // no gauge. The failure is silent by construction: the turn proceeds
    // normally and the only trace is in the debug view, which is why it went
    // unnoticed until the maintainer opened it by accident (CTRL+O) and saw the
    // router timing out on real prompts.
    //
    // The nine lenses are computed per turn over the prompt AND the reply, so
    // the work is proportional to the traffic, not constant. A bound chosen for
    // a trivial script is the wrong shape of bound for this one.
    //
    // 18000 s matches HOOK_TIMEOUT_SECONDS below and the plugin's hooks.json, so
    // the two install paths deliver the same product -- the rule this file
    // already enforces for the command string is now enforced for the bound.
    s.hooks[ev].push({ matcher: "*", hooks: [{ type: "command", command: cmd, timeout: HOOK_TIMEOUT_SECONDS }] });
    touched.push(ev);
  }

  // THE OBSERVATION CHANNEL IS ON BY DEFAULT NOW -- THE PIN IS RETIRED.
  //
  // History, because both halves were measured. 2026-08-09: no installer set
  // ROTMOE_DEBUG_LOG and the router of that era wrote nothing when it was
  // unset, so arm began pinning a fixed path here to switch the log on.
  // 7.0.0 then gave the router a real default -- a per-session, trimmed,
  // janitored sink in the STATE directory, the same place the summons live,
  // and the place the Animus observer (ORGAN 8) pairs on. 2026-08-20 (8.0.1),
  // a ten-turn live run measured the consequence of keeping both: the pinned
  // path names a directory nothing creates, the router's writability probe
  // fails, the sink degrades to OFF -- so every ARMED session ran with no
  // sink at all, and the observer watched a file that could never exist.
  // SET wins over the default by design, which made the fossil pin the one
  // thing standing between organ 8 and the armed router.
  //
  // So arm now RETIRES its own pin: if the settings carry exactly the value
  // this installer used to write, it is removed and the router's per-session
  // default takes over. A value the user chose themselves is theirs -- kept,
  // exactly as before. The log FILES are never touched.
  if (s.env && typeof s.env === "object" && !Array.isArray(s.env)) {
    if (s.env.ROTMOE_DEBUG_LOG === DEFAULT_LOG) {
      delete s.env.ROTMOE_DEBUG_LOG;
      if (Object.keys(s.env).length === 0) delete s.env;
      wroteEnv = true;
      console.log("  ROTMOE_DEBUG_LOG: retired our old pin -- the per-session sink takes over");
    } else if (typeof s.env.ROTMOE_DEBUG_LOG === "string" && s.env.ROTMOE_DEBUG_LOG !== "") {
      console.log("  ROTMOE_DEBUG_LOG: user-chosen value kept");
    }
  }
  if (touched.length === 0 && !wroteEnv) { console.log("  nothing to do -- already armed on every event"); process.exit(10); }
} else if (mode === "disarm" || mode === "disarm-any") {
  // THE PREDICATE IS THE ONLY DIFFERENCE between the two modes. Written once,
  // here, so the removal, the group-emptying rule and the container rule cannot
  // drift between them -- two copies of this loop is how the broad mode would
  // eventually acquire a behaviour the narrow one does not have.
  // BOTH SHIPPED HOOKS, not just the router. `--all` promises to remove every
  // RoT MoE entry whatever path it names; once ARM_ROUTER also wires
  // prover-remind, a predicate that only knows the router would leave the
  // reminder behind on every uninstall -- an entry the user cannot remove by any
  // documented means, which is the exact defect `disarm-any` was created to fix.
  // Widening it here rather than at the call sites keeps one definition of
  // "ours" for both arms.

  // SYMMETRY, and only where it is safe. Disarm removes the default we wrote
  // and nothing else: a path the user chose is theirs to keep, and an installer
  // that deletes a customised value on uninstall is worse than one that leaves
  // a harmless variable behind. The log FILES are never touched -- they are the
  // user's data, and an uninstaller that deletes evidence is not a good citizen.
  if (s.env && typeof s.env === "object" && !Array.isArray(s.env)) {
    if (s.env.ROTMOE_DEBUG_LOG === DEFAULT_LOG) {
      delete s.env.ROTMOE_DEBUG_LOG;
      if (Object.keys(s.env).length === 0) delete s.env;
      console.log("  ROTMOE_DEBUG_LOG: our default removed (log files left in place)");
    } else if (typeof s.env.ROTMOE_DEBUG_LOG === "string") {
      console.log("  ROTMOE_DEBUG_LOG: user-chosen value kept");
    }
  }
  const isOurs = (c) => mode === "disarm-any"
    ? (typeof c === "string" && /(rot-router|prover-remind|rot-voice-gate)\.(ps1|sh)/.test(c))
    : (c === cmd);
  let removed = 0;
  for (const ev of Object.keys(s.hooks || {})) {
    const groups = s.hooks[ev];
    if (!Array.isArray(groups)) continue;
    const keep = [];
    let removedHere = 0;
    for (const g of groups) {
      if (!Array.isArray(g.hooks)) { keep.push(g); continue; }
      const had = g.hooks.some(h => isOurs(h.command));
      const n = g.hooks.length;
      // Remove ONLY what the predicate claims. An uninstaller that took a
      // neighbour with it would satisfy "the router is gone" perfectly while
      // destroying the user's setup.
      g.hooks = g.hooks.filter(h => !isOurs(h.command));
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
  // AND REMOVE THE CONTAINER WE FILLED. Deleting the per-event keys above is not
  // enough: a settings.json that had no "hooks" key at all comes back with
  // "hooks": {} still in it, and the round trip is then byte-DIFFERENT from what
  // the user handed us. That is the exact claim the installer makes, so leaving
  // it would make the claim false for the most common starting file there is.
  //
  // The one case this is imperfect for, stated rather than hidden: a user who
  // deliberately kept an empty "hooks": {} gets the key removed. That is a
  // semantic no-op -- Claude Code treats an empty hooks object and an absent one
  // identically -- whereas the alternative is a byte-visible residue for
  // everyone else. This is the opposite choice from the per-GROUP rule above,
  // and deliberately so: an empty group is user-authored content sitting inside
  // a list, while the top-level object is a container we are the ones who filled.
  if (s.hooks && Object.keys(s.hooks).length === 0) {
    delete s.hooks;
    console.log("  removed    : the now-empty hooks container");
  }
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
  // The env RETIREMENT is validated the same way the hook additions are, but
  // mirrored: arm now REMOVES our old pin (8.0.1), so the sanctioned mutation
  // is subtracted from the PRE-image rather than the post-image -- deletion on
  // both sides, never re-insertion, because JSON.stringify would put a
  // restored key at the END and a mere reordering would read as corruption.
  // `touched` holds EVENT NAMES and is indexed into `stripped.hooks`, so
  // pushing a non-event onto it crashes this block -- measured, TypeError at
  // the filter. The flag keeps the strong invariant intact: after removing
  // exactly what we added here and exactly what we retired there, the two
  // images must be deep-equal, not merely "close enough in the keys someone
  // remembered to check".
  const beforeCmp = JSON.parse(JSON.stringify(before));
  if (wroteEnv && beforeCmp.env) {
    delete beforeCmp.env.ROTMOE_DEBUG_LOG;
    if (Object.keys(beforeCmp.env).length === 0) delete beforeCmp.env;
  }
  if (Object.keys(stripped.hooks || {}).length === 0 && !beforeCmp.hooks) delete stripped.hooks;
  const a = JSON.stringify(stripped), b = JSON.stringify(beforeCmp);
  if (a !== b) {
    console.error("  VALIDATION FAILED: a pre-existing value changed.");
    console.error("  before: " + b.slice(0, 400));
    console.error("  after : " + a.slice(0, 400));
    process.exit(4);
  }
  console.log("  validated  : every pre-existing key byte-identical (deep compare)");
}
process.exit(0);
