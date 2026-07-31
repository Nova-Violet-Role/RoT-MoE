#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# ARM_ROUTER.sh -- install the RoT MoE router hooks into settings.json
#
# THIS IS A SECURITY CONTRACT, NOT A CONVENIENCE SCRIPT. It edits a file the
# user's whole session depends on. The rules below are in priority order and
# rule 4 can undo rules 1-3 automatically.
#
#   1. BACKUP FIRST, and print the restore command.
#   2. ADDITIVE MERGE ONLY -- parse, append, write back. Never a blind rewrite,
#      never a template.
#   3. PRESERVE every key it did not come to add.
#   4. VALIDATE by re-reading -- if the result does not parse, or ANY
#      pre-existing value changed, AUTO-RESTORE and exit non-zero.
#   5. IDEMPOTENT -- detect by command string, not by count.
#   6. SHOW THE DIFF.
#   7. Never sudo. Never touch anything outside the Claude config dir.
#
# -----------------------------------------------------------------------------
# WHY node AND NOT jq/python.
#
# Measured on the development machine: `python`, `python3` and `py` are ALL
# ABSENT; only `uv` is installed. `jq` happens to be present but is not
# something a Claude Code user is guaranteed to have.
#
# `node` is guaranteed, and the argument is structural rather than lucky:
# Claude Code is itself a Node application. Anyone who can run the thing this
# plugin plugs into can run node. That makes it the only JSON engine here whose
# presence follows from the premise.
#
# -----------------------------------------------------------------------------
# THE BOM RULE -- A DELIBERATE DEPARTURE FROM THE WRITTEN SPEC, DISCLOSED.
#
# The spec says the installer "writes UTF-8 WITHOUT BOM". Measured on the live
# file: `settings.json` ALREADY HAS a UTF-8 BOM. `JSON.parse` fails on it
# outright until the BOM is stripped.
#
# Writing it back without one would silently alter the first three bytes of a
# file this installer was told to preserve -- which is precisely the class of
# change rule 3 forbids. The spec's intent is that an installer must not ADD a
# BOM; read literally against a file that already has one, it would force a
# byte-level modification.
#
# So this script PRESERVES THE INPUT'S BOM STATE: none is added if none was
# there, and an existing one is kept. Same for the trailing newline. That
# satisfies the rule's purpose exactly, and "nothing else moves" wins over the
# literal wording when the two conflict.
# =============================================================================

set -euo pipefail

# --- rule 7: scope ----------------------------------------------------------
# CLAUDE_DIR is overridable ONLY so the checker can run this against a scratch
# HOME. That is not a backdoor: it is what makes rules 1-6 testable at all,
# and an installer whose guarantees have never been executed is an untested
# alarm.
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROUTER_SH="$SELF_DIR/hooks/rot-router.sh"
ROUTER_PS1="$SELF_DIR/hooks/rot-router.ps1"

# The command string is the identity used for idempotence and for removal.
# `pwsh ... || bash ...` mirrors the org's working plugin: Windows takes the
# first arm, POSIX falls through to the second.
ROUTER_CMD="pwsh -NoProfile -File \"$ROUTER_PS1\" || bash \"$ROUTER_SH\""
EVENTS='UserPromptSubmit PreToolUse'

echo "RoT MoE :: ARM_ROUTER"
echo "  config dir : $CLAUDE_DIR"
echo "  settings   : $SETTINGS"

if [ ! -f "$SETTINGS" ]; then
  echo "  no settings.json found -- creating a minimal one"
  mkdir -p "$CLAUDE_DIR"
  printf '{}\n' > "$SETTINGS"
fi

# --- rule 1: backup ---------------------------------------------------------
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$SETTINGS.pre-armrouter-$STAMP.bak"
cp "$SETTINGS" "$BACKUP"
echo "  backup     : $BACKUP"
echo "  restore    : cp \"$BACKUP\" \"$SETTINGS\""

# --- rules 2,3,5: the merge -------------------------------------------------
MERGE_RC=0
ROUTER_CMD="$ROUTER_CMD" SETTINGS="$SETTINGS" EVENTS="$EVENTS" node - <<'NODE' || MERGE_RC=$?
const fs = require("fs");
const file = process.env.SETTINGS;
const cmd  = process.env.ROUTER_CMD;
const events = process.env.EVENTS.split(/\s+/).filter(Boolean);

const raw = fs.readFileSync(file, "utf8");
const hadBOM  = raw.charCodeAt(0) === 0xFEFF;
const body    = hadBOM ? raw.slice(1) : raw;
const hadNL   = body.endsWith("\n");

let s;
try { s = JSON.parse(body); }
catch (e) { console.error("  FATAL: settings.json does not parse BEFORE we touch it: " + e.message);
            console.error("  refusing to write. Nothing has been changed."); process.exit(3); }

// Snapshot for rule 4. Deep clone so later mutation cannot reach it.
const before = JSON.parse(JSON.stringify(s));

// rule 5: idempotence is by COMMAND STRING, across every matcher group.
const alreadyIn = (ev) => {
  const groups = (s.hooks && s.hooks[ev]) || [];
  return groups.some(g => (g.hooks || []).some(h => h.command === cmd));
};

s.hooks = s.hooks || {};
let added = [];
for (const ev of events) {
  s.hooks[ev] = s.hooks[ev] || [];
  if (alreadyIn(ev)) { console.log(`  ${ev}: already armed, skipping`); continue; }
  // rule 2: APPEND a NEW group. Appending to an existing group would mutate an
  // object the user owns; adding one leaves every existing group untouched,
  // and it lands at the END so the user's hooks keep firing first.
  s.hooks[ev].push({ matcher: "*", hooks: [{ type: "command", command: cmd }] });
  added.push(ev);
}

if (added.length === 0) {
  console.log("  nothing to do -- already armed on every event (rule 5)");
  process.exit(10);   // distinct code: "no change", not an error
}

// rule 3 + the BOM rule: reproduce the input's encoding decisions exactly.
//
// INDENT IS DETECTED, NOT ASSUMED. The spec says "indent=2", but hardcoding 2
// would silently reformat a file indented with 4 spaces or tabs -- a whole-file
// diff on a file this script was told to preserve. Detect from the first
// nested key and reproduce it.
//
// HONEST LIMIT, and the checker tests for it rather than hiding it:
// JSON.stringify cannot reproduce INTRA-LINE layout. A file containing
// `"env": { "A": "b" }` on one line comes back expanded across three. Values,
// keys, order, BOM and indent width all survive; compact inline objects do
// not. That is a real reformat and it is stated in README and NOTICE.
const im = body.match(/\n([ \t]+)"/);
const indent = im ? (im[1][0] === "\t" ? "\t" : im[1].length) : 2;
let out = JSON.stringify(s, null, indent);
if (hadNL) out += "\n";
if (hadBOM) out = "﻿" + out;
fs.writeFileSync(file, out, "utf8");
console.log("  armed on   : " + added.join(", "));

// rule 4: VALIDATE by re-reading from disk -- not by trusting the object we
// just serialised. A writer bug lives between those two things.
const raw2 = fs.readFileSync(file, "utf8");
const body2 = raw2.charCodeAt(0) === 0xFEFF ? raw2.slice(1) : raw2;
let after;
try { after = JSON.parse(body2); }
catch (e) { console.error("  VALIDATION FAILED: written file does not parse: " + e.message); process.exit(4); }

if ((raw2.charCodeAt(0) === 0xFEFF) !== hadBOM) {
  console.error("  VALIDATION FAILED: BOM state changed"); process.exit(4);
}

// Remove exactly what we added, then require deep equality with the snapshot.
// This is the strong form of rule 3: not "the four critical keys survived" but
// "NOTHING survived differently", which is the version that still holds the day
// a fifth critical key appears.
const stripped = JSON.parse(JSON.stringify(after));
for (const ev of added) {
  stripped.hooks[ev] = stripped.hooks[ev].filter(
    g => !((g.hooks || []).some(h => h.command === cmd)));
  if (stripped.hooks[ev].length === 0 && !(before.hooks && before.hooks[ev])) {
    delete stripped.hooks[ev];
  }
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
NODE

# rule 4: auto-restore on any validation failure.
if [ "$MERGE_RC" -eq 4 ]; then
  cp "$BACKUP" "$SETTINGS"
  echo "  AUTO-RESTORED from backup. settings.json is as it was."
  exit 4
elif [ "$MERGE_RC" -eq 3 ]; then
  echo "  settings.json was already invalid. Nothing written."
  exit 3
elif [ "$MERGE_RC" -eq 10 ]; then
  rm -f "$BACKUP"    # no change made, so the backup is noise
  echo "  already armed -- backup removed, nothing changed."
  exit 0
elif [ "$MERGE_RC" -ne 0 ]; then
  cp "$BACKUP" "$SETTINGS"
  echo "  unexpected failure ($MERGE_RC). AUTO-RESTORED from backup."
  exit "$MERGE_RC"
fi

# --- rule 6: show the diff --------------------------------------------------
echo "  --- diff ---"
if command -v diff >/dev/null 2>&1; then
  diff -u "$BACKUP" "$SETTINGS" | sed 's/^/  /' || true
else
  echo "  (diff unavailable; backup is at $BACKUP)"
fi
echo "RoT MoE :: armed."
