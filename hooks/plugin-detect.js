// This file is part of RoT MoE.
// SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
// Copyright 2026 Saimonokuma.
//
// ============================================================================
// plugin-detect.js -- is the RoT MoE router ALREADY registered by the installed
// plugin?
//
// THE DEFECT THIS EXISTS TO PREVENT, measured on a live machine 2026-08-04.
//
// There are two ways this router reaches a session and they are ADDITIVE, not
// alternatives:
//
//   1. the marketplace/plugin path -- `claude plugin install rot-moe@rot-moe`
//      registers `hooks/hooks.json`, which already binds rot-router on
//      UserPromptSubmit and PreToolUse via ${CLAUDE_PLUGIN_ROOT};
//   2. ARM_ROUTER -- which writes an absolute-path entry for the SAME script on
//      the SAME two events into settings.json.
//
// CLAUDE.md told the installing agent to do BOTH: install the plugin, then run
// ARM_ROUTER. The result is not "extra safety", it is the router firing TWICE
// per prompt: two identical `RoT MoE :: TIER 1 -> ...` lines injected into the
// context, two gauge computations, twice the tokens, forever, on every machine
// that followed the documented procedure. Measured in a real session -- the
// transcript carries the marker twice, and settings.json plus the plugin's own
// hooks.json each account for exactly one of them.
//
// Nothing about that state looks wrong from inside: the hook works, the lane is
// right, the gauge is right. It is right TWICE. That is why this has to be a
// program and not a sentence in a README.
//
// WHAT IT CHECKS, and why it is spelled this way.
//
// A plugin's registration is live only if BOTH hold:
//   * a plugin directory reachable from the Claude config dir ships a
//     hooks/hooks.json that mentions the router script, AND
//   * settings.json has that plugin ENABLED (enabledPlugins["<name>@<mp>"] is
//     true). A disabled plugin registers nothing, so arming is then correct.
//
// It does NOT hardcode "rot-moe" as a directory name: a marketplace may rename
// it, and a name is a snapshot while the hooks.json content is the fact. The
// plugin identity used for the enabled-check is derived from the path
// (cache/<marketplace>/<plugin>/<version>), which is the layout Claude Code
// itself writes.
//
// Usage:  node plugin-detect.js <claude-config-dir>
// Exit:   0  a plugin registration IS live (arming would duplicate)
//         10 no live plugin registration (arming is the right move)
//         2  usage error
// stdout: one human line, plus `path=` lines for each detected registration.
// ============================================================================

"use strict";
const fs = require("fs");
const path = require("path");

const dir = process.argv[2];
if (!dir) {
  console.error("usage: plugin-detect.js <claude-config-dir>");
  process.exit(2);
}

// --- which plugins does the user's settings.json have ENABLED? ---------------
// Read defensively: this file must never throw. It is called from an installer
// whose whole contract is "nothing unexpected happens to your config".
let enabled = {};
try {
  const raw = fs.readFileSync(path.join(dir, "settings.json"), "utf8");
  const s = JSON.parse(raw.replace(/^﻿/, ""));
  enabled = s.enabledPlugins || {};
} catch (e) { enabled = {}; }

function safeReaddir(p) {
  try { return fs.readdirSync(p, { withFileTypes: true }); } catch (e) { return []; }
}

// --- WHICH VERSION IS ACTUALLY LOADED? ---------------------------------------
// MEASURED on the CTT instance 2026-08-04, and it corrected this file.
//
// The cache is an ACCUMULATOR: `claude plugin update` leaves every previous
// version in place. That instance held SEVEN directories -- 0.1.2 through 0.7.2
// -- each with a hooks.json binding the router, under one enabled plugin id. The
// first version of this detector walked the cache and reported all seven as live
// registrations, which reads like a sevenfold duplication and is simply false.
//
// `plugins/installed_plugins.json` is the authority. It records ONE entry per
// plugin id with an explicit `installPath`, and that is the directory Claude
// Code loads hooks from; the other six are inert leftovers. Measured there:
//   "rot-moe@rot-moe": [ { installPath: ".../0.7.2", version: "0.7.2", ... } ]
//
// So the manifest is consulted FIRST and the cache walk is the FALLBACK, for a
// config written by a CLI old enough not to have the manifest. Keying on a
// directory layout when an authoritative record exists is how a detector drifts
// from the truth the day the layout changes.
const found = [];
const manifestPath = path.join(dir, "plugins", "installed_plugins.json");
let manifestUsed = false;
try {
  const m = JSON.parse(fs.readFileSync(manifestPath, "utf8").replace(/^﻿/, ""));
  const plugins = (m && m.plugins) || {};
  for (const id of Object.keys(plugins)) {
    const entries = Array.isArray(plugins[id]) ? plugins[id] : [plugins[id]];
    for (const e of entries) {
      if (!e || !e.installPath) continue;
      const hj = path.join(e.installPath, "hooks", "hooks.json");
      let txt = "";
      try { txt = fs.readFileSync(hj, "utf8"); } catch (err) { continue; }
      if (!/rot-router\.(ps1|sh)/.test(txt)) continue;
      found.push({ id: id, path: hj, enabled: enabled[id] === true, src: "manifest" });
      manifestUsed = true;
    }
  }
} catch (e) { /* no manifest, or unreadable: fall through to the cache walk */ }

// --- FALLBACK: walk the plugin cache for a hooks.json that binds OUR router ---
// Layout, as written by Claude Code:  <dir>/plugins/cache/<mp>/<plugin>/<ver>/
const roots = manifestUsed ? [] : [path.join(dir, "plugins", "cache")];

for (const root of roots) {
  for (const mp of safeReaddir(root)) {
    if (!mp.isDirectory()) continue;
    for (const pl of safeReaddir(path.join(root, mp.name))) {
      if (!pl.isDirectory()) continue;
      for (const ver of safeReaddir(path.join(root, mp.name, pl.name))) {
        if (!ver.isDirectory()) continue;
        const hj = path.join(root, mp.name, pl.name, ver.name, "hooks", "hooks.json");
        let txt = "";
        try { txt = fs.readFileSync(hj, "utf8"); } catch (e) { continue; }
        // The FACT is that this hooks.json binds the router script. The plugin's
        // NAME is not the fact -- a marketplace can rename it and the duplicate
        // would come back.
        if (!/rot-router\.(ps1|sh)/.test(txt)) continue;
        const id = pl.name + "@" + mp.name;
        found.push({ id: id, path: hj, enabled: enabled[id] === true, src: "cache" });
      }
    }
  }
}

const live = found.filter(f => f.enabled);

for (const f of found) {
  console.log("  path=" + f.path.replace(/\\/g, "/") + " id=" + f.id +
              " enabled=" + (f.enabled ? "true" : "false") + " via=" + f.src);
}
if (!manifestUsed && found.length > 0) {
  console.log("  (no installed_plugins.json -- read from the cache layout, which" +
              " can hold superseded versions)");
}

if (live.length > 0) {
  console.log("  plugin registration is LIVE (" + live.map(f => f.id).join(", ") + ")");
  process.exit(0);
}
console.log("  no live plugin registration of the router");
process.exit(10);
