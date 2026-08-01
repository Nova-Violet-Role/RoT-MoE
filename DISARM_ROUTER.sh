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

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-${CLAUDE_DIR:-$HOME/.claude}}"
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
node "$SELF_DIR/hooks/settings-merge.js" disarm "$SETTINGS" "$ROUTER_CMD" || RC=$?

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
