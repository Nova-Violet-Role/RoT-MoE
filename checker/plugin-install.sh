#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# R17 (Windows half) -- THE OTHER INSTALL PATH, and the brand-new user.
#
# checker/live-session-smoke.sh proves the ARM_ROUTER path works. It is not the
# only way in, and the other two cases are exactly where a packet breaks for
# somebody who is not its author:
#
#   PHASE A  the PLUGIN path -- `claude --plugin-dir <repo>`. This reads
#            .claude-plugin/plugin.json and hooks/hooks.json, which ARM_ROUTER
#            never touches. Those two files have been VALIDATED as JSON and
#            never once EXERCISED. A manifest that parses and a manifest the
#            CLI accepts are different claims.
#
#   PHASE B  the BRAND-NEW USER -- a config dir with NO settings.json at all.
#            Every previous test started from a fixture that already existed.
#            The create-from-nothing branch has never run, and it is the branch
#            every first-time user takes.
#
# WHAT THIS CANNOT ESTABLISH, said plainly rather than left to be assumed:
# R17 asks for a clean LINUX and a clean Windows. There is no Linux on this
# machine and it is not a matter of installing one -- measured: WSL lists only
# `docker-desktop` and reports "nested virtualization is not supported on this
# computer", which also stops Docker's Linux engine. The Linux half of R17 is
# therefore CI's to close, and nothing here should be read as covering it.
#
# Safety: scratch config dir throughout, the live ~/.claude is never opened,
# no process is signalled, every session is bounded by a timeout.
# =============================================================================

set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rotmoe-plugin.XXXXXX")"
SESSION_TIMEOUT="${ROTMOE_SESSION_TIMEOUT:-150}"
PROMPT="lake build the theorem"
MARKER='RoT MoE :: TIER 1 ->'

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=plugin-install::%s\n' "$*"; fail=$((fail+1)); }

echo "== R17 (Windows half): plugin path + brand-new user =="
echo "  scratch : $WORK"
echo "  live ~/.claude : NOT TOUCHED"

if ! command -v claude >/dev/null 2>&1; then
  echo "  SKIP  claude CLI absent -- neither path was exercised. A SKIP is not a PASS."
  exit 3
fi

LIVE="$HOME/.claude/settings.json"
LIVE_BEFORE=$(wc -c < "$LIVE" 2>/dev/null || echo 0)

# ===========================================================================
echo
echo "-- phase A: the PLUGIN path (--plugin-dir), which ARM_ROUTER never uses --"
PA="$WORK/a"; mkdir -p "$PA/.claude"
printf '{\n  "hooks": {}\n}\n' > "$PA/.claude/settings.json"

CLAUDE_CONFIG_DIR="$PA/.claude" timeout "$SESSION_TIMEOUT" claude -p "$PROMPT" \
  --plugin-dir "$REPO" \
  --settings "$PA/.claude/settings.json" \
  --debug hooks --debug-file "$PA/plugin.debug" \
  > "$PA/plugin.out" 2> "$PA/plugin.err"
echo "  session[plugin] exit=$?"

# Did the CLI even accept the manifest? A rejected plugin is silent otherwise.
if grep -qiE 'rot-moe|Loading hooks from plugin' "$PA/plugin.debug" 2>/dev/null; then
  ok "the CLI READ the plugin manifest"
  grep -iE 'rot-moe' "$PA/plugin.debug" 2>/dev/null | head -2 | sed 's/^/        /'
else
  bad "the CLI never mentioned this plugin -- manifest not accepted"
  grep -iE 'plugin' "$PA/plugin.debug" 2>/dev/null | head -5 | sed 's/^/        /'
fi

PLUG_HIT=$(grep -cF "$MARKER" "$PA/plugin.debug" "$PA/plugin.out" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$PLUG_HIT" -gt 0 ]; then
  ok "PLUGIN PATH: the router fired without ARM_ROUTER ever running ($PLUG_HIT)"
else
  bad "PLUGIN PATH: the router did not fire from hooks/hooks.json"
fi

# CONTROL: same session, no --plugin-dir. If the line still appears, phase A was
# measuring something other than the plugin.
CLAUDE_CONFIG_DIR="$PA/.claude" timeout "$SESSION_TIMEOUT" claude -p "$PROMPT" \
  --settings "$PA/.claude/settings.json" \
  --debug hooks --debug-file "$PA/noplugin.debug" \
  > "$PA/noplugin.out" 2> "$PA/noplugin.err"
NOPLUG_HIT=$(grep -cF "$MARKER" "$PA/noplugin.debug" "$PA/noplugin.out" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$NOPLUG_HIT" -eq 0 ]; then
  ok "CONTROL: without --plugin-dir the line is ABSENT ($NOPLUG_HIT)"
else
  bad "CONTROL DEAD: the line appears with no plugin loaded ($NOPLUG_HIT)"
fi

# ===========================================================================
echo
echo "-- phase B: the BRAND-NEW USER -- no settings.json at all --"
PB="$WORK/b"; mkdir -p "$PB/.claude"     # dir exists, FILE does not
[ -f "$PB/.claude/settings.json" ] && bad "fixture is wrong: a settings.json already exists"

CLAUDE_DIR="$PB/.claude" bash "$REPO/ARM_ROUTER.sh" > "$PB/arm.log" 2>&1
ARM_RC=$?
[ "$ARM_RC" -eq 0 ] && ok "ARM_ROUTER exit 0 with NO pre-existing settings.json" \
                    || { bad "ARM_ROUTER exit $ARM_RC on a fresh config"; sed 's/^/        /' "$PB/arm.log" | head -8; }

if [ -f "$PB/.claude/settings.json" ]; then
  ok "settings.json was CREATED"
  node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").replace(/^﻿/,""))' \
       "$PB/.claude/settings.json" 2>/dev/null \
    && ok "the created file is valid JSON" \
    || bad "the created file does NOT parse"
  # A file we create should set clean conventions: no BOM, and it must round trip.
  # `grep -c … >/dev/null` rather than `grep -q`: the producer here is only three
  # bytes, so the SIGPIPE race is vanishingly unlikely -- but "unlikely" is what
  # every other site in this repo looked like until a runner disagreed, and the
  # rule that forbids the shape is worth more than a per-site risk assessment.
  head -c 3 "$PB/.claude/settings.json" | grep -c $'\xef\xbb\xbf' >/dev/null \
    && bad "a NEW file was created WITH a BOM -- we should not add one" \
    || ok "the created file has no BOM (we preserve one, we never add one)"
else
  bad "no settings.json was created"
fi

CLAUDE_DIR="$PB/.claude" bash "$REPO/DISARM_ROUTER.sh" > "$PB/disarm.log" 2>&1
grep -q 'rot-router' "$PB/.claude/settings.json" 2>/dev/null \
  && bad "router still present after disarm on a fresh config" \
  || ok "disarm removed it again on the fresh config"

# ===========================================================================
LIVE_AFTER=$(wc -c < "$LIVE" 2>/dev/null || echo 0)
[ "$LIVE_BEFORE" = "$LIVE_AFTER" ] \
  && ok "live settings.json untouched ($LIVE_AFTER bytes before and after)" \
  || bad "LIVE settings.json CHANGED: $LIVE_BEFORE -> $LIVE_AFTER"

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
echo "  NOT COVERED HERE: the clean-LINUX half of R17. No Linux is reachable on"
echo "  this machine (WSL: nested virtualization unsupported; Docker's Linux"
echo "  engine cannot start). That half belongs to CI and is not claimed here."
echo "  artifacts: $WORK"
[ "$fail" -eq 0 ] && { echo "  R17 (Windows half): PASS"; exit 0; } || { echo "  R17 (Windows half): FAIL"; exit 1; }
