#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# CmdPulse installer — copies scripts, merges settings, wires all 31 hook events.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
command -v jq >/dev/null 2>&1 || { echo "jq is required: https://jqlang.github.io/jq/"; exit 1; }

mkdir -p "$DEST/cmdpulse"
cp "$HERE/statusline.sh"                   "$DEST/statusline.sh"
cp "$HERE/cmdpulse/record.sh"              "$DEST/cmdpulse/record.sh"
cp "$HERE/cmdpulse/cmdpulse.sh"            "$DEST/cmdpulse/cmdpulse.sh"
cp "$HERE/cmdpulse/cmdpulse-web.sh"        "$DEST/cmdpulse/cmdpulse-web.sh"
cp "$HERE/cmdpulse/wezterm-cmdpulse.lua"   "$DEST/cmdpulse/wezterm-cmdpulse.lua"
chmod +x "$DEST/statusline.sh" "$DEST/cmdpulse/"*.sh
echo "scripts -> $DEST"

S="$DEST/settings.json"; [ -f "$S" ] || echo '{}' > "$S"
BAK="$S.pre-cmdpulse-$(date +%Y%m%d-%H%M%S)"; cp "$S" "$BAK"; echo "backup -> $BAK"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    B='C:\Program Files\Git\bin\bash.exe'
    U=$(cd "$DEST" && pwd -W 2>/dev/null || echo "$DEST")
    SL="\"$B\" \"$U/statusline.sh\""; REC="\"$B\" \"$U/cmdpulse/record.sh\"" ;;
  *)
    SL="bash $DEST/statusline.sh";    REC="bash $DEST/cmdpulse/record.sh" ;;
esac

# refreshInterval 3: a render slower than the interval is ABORTED by the next one, which
# blanks the status line entirely. 3 is safe on Windows; see README "the one number".
jq --arg sl "$SL" --arg rec "$REC" '
  ["ConfigChange","CwdChanged","DirectoryAdded","Elicitation","ElicitationResult","FileChanged",
   "InstructionsLoaded","MessageDisplay","Notification","PermissionDenied","PermissionRequest",
   "PostCompact","PostToolBatch","PostToolUse","PostToolUseFailure","PreCompact","PreToolUse",
   "SessionEnd","SessionStart","Setup","Stop","StopFailure","SubagentStart","SubagentStop",
   "TaskCompleted","TaskCreated","TeammateIdle","UserPromptExpansion","UserPromptSubmit",
   "WorktreeCreate","WorktreeRemove"] as $events
  | .statusLine = {type:"command", command:$sl, refreshInterval:3}
  | .hooks //= {}
  | reduce $events[] as $e (.;
      .hooks[$e] //= [{matcher:"*", hooks:[]}]
      | .hooks[$e][0].hooks |= map(select((.command // "") | test("cmdpulse") | not))
      | .hooks[$e][0].hooks +=
          (if $e == "PreToolUse"  then [{type:"command", command:($rec+" pre"),  timeout:10000}]
           elif $e == "PostToolUse" then [{type:"command", command:($rec+" post"), timeout:10000}]
           else [{type:"command", command:($rec+" event "+$e), timeout:5000}] end))
' "$BAK" > "$S.tmp" && jq -e . "$S.tmp" >/dev/null && mv "$S.tmp" "$S" \
  && echo "settings wired: statusLine + 31 hook events" \
  || { echo "settings merge FAILED — original untouched"; rm -f "$S.tmp"; exit 1; }

echo; echo "Done. No restart needed — Claude Code re-reads settings.json live."
