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
