#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# ---------------------------------------------------------------------------
# hook-contract.sh -- EXECUTE THE COMMAND STRINGS hooks/hooks.json REGISTERS,
# with the payload Claude Code really delivers, and require real output.
#
# WHY THIS EXISTS. The plugin shipped a hooks.json that registered
#
#     pwsh -NoProfile -File "...rot-router.ps1" -Route "${CLAUDE_USER_PROMPT}"
#
# and Claude Code DOES NOT EXPAND ${CLAUDE_USER_PROMPT} -- the variable does not
# exist. The script got an empty route, fell through to waiting on stdin, and
# hung until the harness killed it. Measured in a real session: exit 124, zero
# bytes, debug log line "Hook UserPromptSubmit (UserPromptSubmit) success:" with
# nothing after the colon. Killed rather than failed, so the "|| bash" fallback
# never ran either. The router was DEAD for every marketplace install.
#
# Every gate was green while that was true, because every check tested a PROXY:
#   - hooks.json is valid JSON               -> it was
#   - it declares three events               -> it did
#   - `claude plugin details` lists Hooks (3)-> it does
#   - the router routes 10/10 lanes          -> it does, when called directly
# Not one of them ran the string that hooks.json actually registers. That is the
# whole lesson: a plugin is not what its manifest says, it is what the harness
# executes. This checker closes the gap by being the only thing that runs it.
#
# Exit: 0 pass, 1 fail, 2 refuse, 3 skip (never a pass).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

PASS=0; FAIL=0
ok  () { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad () { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }

HJ="hooks/hooks.json"
[ -f "$HJ" ] || { echo "REFUSE: $HJ is missing"; exit 2; }

echo "== hook contract: run what hooks.json REGISTERS =="

# --- extract every registered command ---------------------------------------
CMDS="$(mktemp "${TMPDIR:-/tmp}/hc.XXXXXX")"
node -e '
  const j=JSON.parse(require("fs").readFileSync("hooks/hooks.json","utf8"));
  const out=[];
  for (const [ev,arr] of Object.entries(j.hooks||{}))
    for (const m of arr) for (const h of (m.hooks||[])) out.push(ev+"\x1f"+h.command);
  process.stdout.write(out.join("\n")+"\n");
' > "$CMDS" 2>/dev/null
n=$(grep -c . "$CMDS" || true)
if [ "${n:-0}" -lt 1 ]; then
  bad "no commands extracted from $HJ -- this checker would pass vacuously"
  rm -f "$CMDS"; printf '\n== hook-contract: %d passed, %d failed\n' "$PASS" "$FAIL"; exit 1
fi
ok "$n registered command(s) extracted from $HJ"

# --- the forbidden shape, checked in the COMMANDS ONLY ----------------------
# Scanned in the extracted command strings rather than across the file, because
# the file also EXPLAINS the defect in prose. A whole-file grep flagged this
# checker's own documentation -- the third time today a scanner matched the text
# describing the bug instead of the bug. Name the forbidden thing where it does
# damage: inside a command the harness executes.
if grep -q 'CLAUDE_USER_PROMPT' "$CMDS"; then
  bad "a registered command passes \${CLAUDE_USER_PROMPT} -- the harness never expands it; the hook hangs and returns nothing"
else
  ok "no registered command references \${CLAUDE_USER_PROMPT} (the variable the harness does not provide)"
fi

# --- run each one the way the harness does ----------------------------------
# Substitute CLAUDE_PLUGIN_ROOT with the repo, feed the real payload shape on
# stdin, and BOUND it -- a hook that hangs is the precise failure being hunted,
# so an unbounded run here would reproduce the bug instead of reporting it.
PLUG="$(pwd)"
PAYLOAD='{"session_id":"test","prompt":"lake build the theorem","tool_name":"Bash","hook_event_name":"UserPromptSubmit"}'
have_timeout=0; command -v timeout >/dev/null 2>&1 && have_timeout=1

run_hook () { # run_hook <command-string> -> prints output, returns exit code
  local c; c="$(printf '%s' "$1" | sed "s|\${CLAUDE_PLUGIN_ROOT}|$PLUG|g")"
  if [ "$have_timeout" -eq 1 ]; then
    printf '%s' "$PAYLOAD" | timeout 25 bash -c "$c" 2>/dev/null
  else
    printf '%s' "$PAYLOAD" | bash -c "$c" 2>/dev/null
  fi
}

routers=0
while IFS= read -r rec; do
  [ -n "$rec" ] || continue
  ev="${rec%%$(printf '\x1f')*}"; cmd="${rec#*$(printf '\x1f')}"
  rc=0; out="$(run_hook "$cmd")" || rc=$?
  short="$(printf '%s' "$cmd" | sed 's/.*hooks\///; s/".*//' | cut -c1-24)"
  if [ "$rc" -eq 124 ]; then
    bad "$ev/$short HUNG (exit 124) -- exactly the shipped defect"
  elif [ -z "$out" ]; then
    bad "$ev/$short produced NO output -- the harness would inject nothing"
  else
    ok "$ev/$short answered: $(printf '%s' "$out" | head -1 | cut -c1-58)"
  fi
  case "$out" in *"RoT MoE :: TIER"*) routers=$((routers+1)) ;; esac
done < "$CMDS"

# The marker is the observable a user can see. Requiring it by NAME stops a
# future edit from passing this checker with a hook that merely prints something.
[ "$routers" -ge 1 ] \
  && ok "the router marker 'RoT MoE :: TIER' reached stdout from a registered command ($routers of $n)" \
  || bad "NO registered command emitted the router marker -- the router is not wired to any event"

# --- NEGATIVE CONTROL -------------------------------------------------------
# The shipped-broken form must be caught by the same runner. Without this, a
# checker that only ever sees the fixed file proves nothing about its own
# ability to detect the bug it was written for.
BROKEN="pwsh -NoProfile -File \"$PLUG/hooks/rot-router.ps1\" -Route \"\" < /dev/null || bash \"$PLUG/hooks/rot-router.sh\" --route \"\""
rc=0; out="$(printf '%s' "$PAYLOAD" | { [ "$have_timeout" -eq 1 ] && timeout 25 bash -c "$BROKEN" 2>/dev/null || bash -c "$BROKEN" 2>/dev/null; })" || rc=$?
case "$out" in
  *"RoT MoE :: TIER"*) bad "CONTROL DEAD: the broken -Route form still emitted the marker -- this checker cannot tell the shapes apart" ;;
  *)                   ok "CONTROL: the shipped -Route form does NOT produce the marker (that is the bug, reproduced here on purpose)" ;;
esac

# --- the scripts themselves still work in hook mode --------------------------
# Separates "the registration is wrong" from "the router is broken". When this
# passes and the block above fails, the defect is in hooks.json, not the logic.
for s in hooks/rot-router.sh hooks/prover-remind.sh; do
  [ -f "$s" ] || { bad "$s missing"; continue; }
  rc=0; out="$(printf '%s' "$PAYLOAD" | { [ "$have_timeout" -eq 1 ] && timeout 25 bash "$s" 2>/dev/null || bash "$s" 2>/dev/null; })" || rc=$?
  [ -n "$out" ] && [ "$rc" -ne 124 ] \
    && ok "$(basename "$s") answers in hook mode (stdin payload, no arguments)" \
    || bad "$(basename "$s") produced nothing in hook mode (exit $rc)"
done

rm -f "$CMDS"
printf '\n== hook-contract: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
