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

# --- CANONICAL PATH FORM -- shared rule, both arms, or the user gets stranded --
# The command string is the identity used for idempotence AND for removal, so
# the two installer arms must spell the repo path identically or one installs
# what the other cannot remove.
#
# A CLEAN-CLONE RUN FOUND THE HOLE that the working copy hid. Under a Git Bash
# MOUNT ALIAS the two arms disagree even after normalisation:
#
#   bash sees        /tmp/x/RoT-MoE
#   PowerShell sees  <drive>:\tmp\x\RoT-MoE  ->  /<drive>/tmp/x/RoT-MoE
#
# ...because /tmp can be an alias for a different drive entirely. Round-tripping with
# `cygpath -u` does NOT fix it: cygpath prefers the alias and hands /tmp back.
#
# So the canonical form is derived from the WINDOWS path by the same rule the
# .ps1 arms use (backslashes to slashes, drive letter lowercased into /d/...).
# On Linux and macOS there is no cygpath and no drive letter, so this is the
# identity function and costs nothing.
canon_path () {
  _p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    _w=$(cygpath -w "$_p" 2>/dev/null) || _w=""
    if [ -n "$_w" ]; then
      _p=$(printf '%s' "$_w" | tr '\\' '/')
      case "$_p" in
        [A-Za-z]:/*)
          _d=$(printf '%s' "$_p" | cut -c1 | tr 'A-Z' 'a-z')
          _p="/$_d$(printf '%s' "$_p" | cut -c3-)"
          ;;
      esac
    fi
  fi
  printf '%s' "$_p"
}

ROUTER_SH="$(canon_path "$ROUTER_SH")"
ROUTER_PS1="$(canon_path "$ROUTER_PS1")"

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
# The merge itself lives in ONE place, shared by both installer arms. See
# hooks/settings-merge.js for why the installer is shared while the router is
# deliberately duplicated: for the router, two agreeing implementations ARE the
# evidence; for the installer there is nothing to cross-check and byte
# divergence between arms would be pure risk.
node "$SELF_DIR/hooks/settings-merge.js" arm "$SETTINGS" "$ROUTER_CMD" || MERGE_RC=$?

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
