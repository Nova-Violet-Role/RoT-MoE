#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# DISARM_ROUTER.sh -- remove the RoT MoE router hooks from settings.json
#
# An installer whose uninstaller has never been run is an untested alarm, so
# this is written and tested BEFORE the router it removes is finished.
#
# It removes exactly the command string ARM_ROUTER installed, and exactly the
# empty matcher groups that removal leaves behind -- nothing else. Same BOM,
# newline and preservation rules as the installer, for the same reason: this
# script also writes a file the user's session depends on.
#
# KNOWN LIMIT, PROVED RATHER THAN DISCLAIMED (lean/Proofs/RotInstall.lean):
# `disarm_arm_id` holds only under a freshness hypothesis, and
# `disarm_arm_not_id` proves that hypothesis cannot be dropped. If you had
# already registered this exact command by hand before installing, this removes
# your entry too -- it cannot tell yours from ours, because they are identical
# strings. That is why ARM_ROUTER writes a backup and prints its restore line.
# =============================================================================

set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROUTER_SH="$SELF_DIR/hooks/rot-router.sh"
ROUTER_PS1="$SELF_DIR/hooks/rot-router.ps1"
ROUTER_CMD="pwsh -NoProfile -File \"$ROUTER_PS1\" || bash \"$ROUTER_SH\""

echo "RoT MoE :: DISARM_ROUTER"
echo "  settings   : $SETTINGS"

[ -f "$SETTINGS" ] || { echo "  no settings.json -- nothing to disarm"; exit 0; }

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$SETTINGS.pre-disarmrouter-$STAMP.bak"
cp "$SETTINGS" "$BACKUP"
echo "  backup     : $BACKUP"
echo "  restore    : cp \"$BACKUP\" \"$SETTINGS\""

RC=0
ROUTER_CMD="$ROUTER_CMD" SETTINGS="$SETTINGS" node - <<'NODE' || RC=$?
const fs = require("fs");
const file = process.env.SETTINGS;
const cmd  = process.env.ROUTER_CMD;

const raw = fs.readFileSync(file, "utf8");
const hadBOM = raw.charCodeAt(0) === 0xFEFF;
const body   = hadBOM ? raw.slice(1) : raw;
const hadNL  = body.endsWith("\n");

let s;
try { s = JSON.parse(body); }
catch (e) { console.error("  FATAL: settings.json does not parse: " + e.message); process.exit(3); }

const before = JSON.parse(JSON.stringify(s));
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
    // Remove ONLY our exact command string. Anything else in the same group
    // stays -- an uninstaller that took a neighbour with it would satisfy
    // "the router is gone" perfectly while destroying the user's setup.
    g.hooks = g.hooks.filter(h => h.command !== cmd);
    removedHere += n - g.hooks.length;
    // Drop a group ONLY if WE emptied it. A group the user left empty stays
    // empty: it is not ours to tidy, and tidying it would be a change to a key
    // this script did not come to touch.
    if (had && g.hooks.length === 0) continue;
    keep.push(g);
  }
  removed += removedHere;
  if (removedHere > 0) {
    s.hooks[ev] = keep;
    if (keep.length === 0) delete s.hooks[ev];
  }
}

if (removed === 0) { console.log("  not armed -- nothing to remove"); process.exit(10); }

// Indent detected, not assumed -- same rule and same reason as ARM_ROUTER.
const im = body.match(/\n([ \t]+)"/);
const indent = im ? (im[1][0] === "\t" ? "\t" : im[1].length) : 2;
let out = JSON.stringify(s, null, indent);
if (hadNL) out += "\n";
if (hadBOM) out = "﻿" + out;
fs.writeFileSync(file, out, "utf8");

// Validate by re-reading, exactly as the installer does.
const raw2 = fs.readFileSync(file, "utf8");
const body2 = raw2.charCodeAt(0) === 0xFEFF ? raw2.slice(1) : raw2;
try { JSON.parse(body2); }
catch (e) { console.error("  VALIDATION FAILED: written file does not parse"); process.exit(4); }
if ((raw2.charCodeAt(0) === 0xFEFF) !== hadBOM) {
  console.error("  VALIDATION FAILED: BOM state changed"); process.exit(4);
}
console.log("  removed    : " + removed + " router hook entr" + (removed === 1 ? "y" : "ies"));
NODE

if [ "$RC" -eq 4 ]; then
  cp "$BACKUP" "$SETTINGS"; echo "  AUTO-RESTORED from backup."; exit 4
elif [ "$RC" -eq 3 ]; then
  echo "  settings.json was already invalid. Nothing written."; exit 3
elif [ "$RC" -eq 10 ]; then
  rm -f "$BACKUP"; echo "  nothing to remove -- backup removed."; exit 0
elif [ "$RC" -ne 0 ]; then
  cp "$BACKUP" "$SETTINGS"; echo "  unexpected failure ($RC). AUTO-RESTORED."; exit "$RC"
fi

echo "  --- diff ---"
diff -u "$BACKUP" "$SETTINGS" | sed 's/^/  /' || true
echo "RoT MoE :: disarmed."
