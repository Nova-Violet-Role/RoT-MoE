#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# R20 -- THE PACKET RUNS IN A REAL CLAUDE CODE SESSION.
#
# Everything else in checker/ answers a different question:
#   lake build      -- the model elaborates
#   leanchecker     -- the kernel re-verifies the proof terms
#   cross-diff      -- the two router arms agree byte for byte
#   install-roundtrip -- the installer does not damage settings.json
#
# NONE of them shows the router FIRING. A packet can pass all four and still be
# inert in a real session: a wrong hook event name, a quoting bug in the command
# string, a plugin manifest the CLI silently ignores. Those defects live in the
# gap between "the code is correct" and "the code runs", and only an executed
# session can see them.
#
# SAFETY, and it is not negotiable:
#   * A SCRATCH config dir. The live ~/.claude is never opened, never armed,
#     never disarmed. Testing an installer against the config the current
#     session is using is how you lose the session you are testing from.
#   * NO process is signalled, by PID or by pattern. On a developer machine a
#     local proxy may be carrying the very API traffic this test runs through,
#     and a pattern kill would take out the endpoint under the test. Never kill
#     by name; this script starts nothing it does not also bound with a timeout.
#   * One short --print prompt. This spends real tokens, so it spends few.
#
# THE NEGATIVE CONTROL IS THE POINT: disarm, run the SAME prompt again, and the
# router line must be ABSENT. A smoke test that cannot go quiet proves nothing,
# and "the log mentions the router" is satisfied just as well by a log that
# mentions the router because the test harness put it there.
# =============================================================================

set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rotmoe-live.XXXXXX")"
export CLAUDE_DIR="$WORK/.claude"          # consumed by ARM_ROUTER.sh
mkdir -p "$CLAUDE_DIR"
SETTINGS="$CLAUDE_DIR/settings.json"
PROMPT="lake build the theorem"

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=live-session-smoke::%s\n' "$*"; fail=$((fail+1)); }

echo "== R20: live Claude Code session smoke test =="
echo "  scratch config : $CLAUDE_DIR"
echo "  live ~/.claude : NOT TOUCHED"

if ! command -v claude >/dev/null 2>&1; then
  echo "  SKIP  the claude CLI is not on PATH."
  echo "        This is a SKIP, not a PASS: the packet is unproven in a live"
  echo "        session on this machine. CI installs the CLI and runs it there."
  exit 3
fi
echo "  claude CLI     : $(claude --version 2>/dev/null)"

# --- a minimal scratch settings.json ----------------------------------------
# Deliberately carries a key of its own, so that if ARM_ROUTER damages the file
# the session fails for a reason we can name rather than a mystery.
cat > "$SETTINGS" <<'JSON'
{
  "env": { "ROTMOE_SMOKE": "1" },
  "hooks": {}
}
JSON

SESSION_TIMEOUT="${ROTMOE_SESSION_TIMEOUT:-180}"

run_session () {   # run_session <tag> -> writes $WORK/<tag>.debug and .out
  tag="$1"
  # ISOLATION, and the first version got this wrong. `--settings` overrides only
  # the settings FILE; it does NOT relocate the config dir, so the first run
  # loaded the live user's plugins -- the debug log recorded
  # "Registered 6 hooks from 4 plugins" out of ~/.claude/plugins. Nothing was
  # written there, but the session was not the clean one this test claims to
  # measure. CLAUDE_CONFIG_DIR is what actually moves the config root, and both
  # are set now: the env var for the root, --settings for the file.
  #
  # A TIMEOUT IS MANDATORY. The first full run exited 124 because the second
  # session had no bound. An unbounded network call inside a checker turns a
  # failing test into a hanging one, and a hang reports nothing at all.
  CLAUDE_CONFIG_DIR="$CLAUDE_DIR" \
  timeout "$SESSION_TIMEOUT" claude -p "$PROMPT" \
    --settings "$SETTINGS" \
    --debug hooks \
    --debug-file "$WORK/$tag.debug" \
    > "$WORK/$tag.out" 2> "$WORK/$tag.err"
  rc=$?
  echo "  session[$tag] exit=$rc (timeout ${SESSION_TIMEOUT}s)"
  [ "$rc" -eq 124 ] && echo "  NOTE session[$tag] TIMED OUT -- treat its evidence as absent, not negative"
  return $rc
}

# The observable is the router's OWN OUTPUT, not its command string. Measured:
# Claude Code's hook debug log never echoes the command it ran, so grepping for
# "rot-router" finds nothing even when the hook fires 19 times. Grepping for a
# string the router itself prints is both available and the thing that actually
# matters -- it is what reaches the model's context.
MARKER='RoT MoE :: TIER 1 ->'

# ============================================================================
echo
echo "-- phase 1: ARM, then run a session --"
bash "$REPO/ARM_ROUTER.sh" > "$WORK/arm.log" 2>&1
ARM_RC=$?
[ "$ARM_RC" -eq 0 ] && ok "ARM_ROUTER exit 0 against the scratch config" \
                    || bad "ARM_ROUTER exit $ARM_RC"
grep -q 'rot-router' "$SETTINGS" && ok "router registered in scratch settings.json" \
                                 || bad "router NOT registered"

run_session armed
ARMED_HIT=$(grep -cF "$MARKER" "$WORK/armed.debug" "$WORK/armed.out" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$ARMED_HIT" -gt 0 ]; then
  ok "ARMED: the router hook FIRED ($ARMED_HIT emissions of its own output)"
else
  bad "ARMED: the router never emitted -- it did not fire"
  echo "        debug log head:"; head -15 "$WORK/armed.debug" 2>/dev/null | sed 's/^/        /'
fi

# --- INVOKED IS NOT THE SAME AS WORKED --------------------------------------
# The first version of this file stopped at the count above and reported PASS.
# It was counting an ERROR as a success: the debug log's four "rot-router"
# references were three lines of a PowerShell stack trace plus the message
# "no mode given (-Vector or -Route)". The hook fired on every turn and did
# nothing, and this test called that a green.
#
# A test that cannot tell "ran" from "worked" is the live-session equivalent of
# scoring a mutation that never applied as SURVIVED. So both are now asserted,
# separately, and the error check comes first because it is the one that was
# missing.
# SCOPE THE ERROR SEARCH, and this is the second defect this phase had.
# The first version grepped the WHOLE log for /Exception|usage:/ and reported
# "the router ERRORED" because the model's own prose contained the English word
# "Exception:". A detector that reads the assistant's free text as diagnostic
# output will fail at random forever, and it fails in the ALARMING direction --
# which is almost as bad as failing green, because it trains you to ignore it.
#
# Only lines naming this router, or a hook the CLI itself reports as failed,
# count as evidence about this router.
ARMED_ERR=$(grep -hiE 'rot-router|Hook [A-Za-z]+ .*(failed|error)' \
              "$WORK/armed.debug" "$WORK/armed.err" 2>/dev/null \
            | grep -ciE 'no mode given|Write-Error|Exception|command not found|usage:|failed')
if [ "$ARMED_ERR" -eq 0 ]; then
  ok "ARMED: no error attributable to the router"
else
  bad "ARMED: the router ERRORED $ARMED_ERR time(s) -- invoked, but not working:"
  grep -hiE 'rot-router|Hook [A-Za-z]+ .*(failed|error)' \
    "$WORK/armed.debug" "$WORK/armed.err" 2>/dev/null | head -3 | sed 's/^/        /'
fi

# The routing decision itself must be correct, not merely present. The prompt is
# "lake build the theorem": three FORGE stems, so any other lane is a defect.
if grep -hF "$MARKER" "$WORK/armed.debug" "$WORK/armed.out" 2>/dev/null | grep -c 'FORGE Claude' >/dev/null; then
  ok "ARMED: routed CORRECTLY -- '$PROMPT' -> FORGE Claude"
  grep -hF "$MARKER" "$WORK/armed.debug" "$WORK/armed.out" 2>/dev/null | head -1 | sed 's/^/        /'
else
  bad "ARMED: wrong lane for '$PROMPT' (expected FORGE Claude)"
  grep -hF "$MARKER" "$WORK/armed.debug" "$WORK/armed.out" 2>/dev/null | head -2 | sed 's/^/        /'
fi

# ============================================================================
echo
echo "-- phase 2: NEGATIVE CONTROL -- disarm, run the SAME prompt --"
bash "$REPO/DISARM_ROUTER.sh" > "$WORK/disarm.log" 2>&1
DIS_RC=$?
[ "$DIS_RC" -eq 0 ] && ok "DISARM_ROUTER exit 0" || bad "DISARM_ROUTER exit $DIS_RC"
grep -q 'rot-router' "$SETTINGS" && bad "router STILL in settings after disarm" \
                                 || ok "router removed from scratch settings.json"

run_session disarmed
DIS_HIT=$(grep -cF "$MARKER" "$WORK/disarmed.debug" "$WORK/disarmed.out" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$DIS_HIT" -eq 0 ]; then
  ok "CONTROL: with the router disarmed the line is ABSENT ($DIS_HIT references)"
else
  bad "CONTROL DEAD: the router still appears after disarm ($DIS_HIT references)."
  echo "        The armed run proves nothing -- the signal is not coming from"
  echo "        the installation. Something else is producing it."
fi

# The two runs must DIFFER. Equal counts mean the test is measuring something
# that has nothing to do with whether the packet is installed.
if [ "$ARMED_HIT" -gt 0 ] && [ "$DIS_HIT" -eq 0 ]; then
  ok "armed=$ARMED_HIT vs disarmed=$DIS_HIT -- the difference is attributable to the install"
else
  bad "armed=$ARMED_HIT vs disarmed=$DIS_HIT -- not attributable"
fi

# ============================================================================
echo
echo "-- phase 3: DOES THE OUTPUT REACH THE MODEL? --"
# WHAT PHASES 1-2 DO AND DO NOT ESTABLISH.
#
# They run with CLAUDE_CONFIG_DIR pointed at a scratch dir, which is the right
# isolation and has one consequence measured here: that dir holds no
# credentials, so the session prints "Not logged in - Please run /login" and
# exits 1. The UserPromptSubmit hook fires BEFORE that, which is why phase 1
# sees the router's output and phase 2 sees none -- the attribution is sound,
# both runs having identical lifecycles.
#
# But a session that never reaches the model cannot demonstrate that the
# router's line reaches the model's CONTEXT. That is a separate claim and it
# needs a session that actually completes. Phase 3 makes it, using the real
# config dir for CREDENTIALS ONLY while still pinning --settings to the scratch
# file, and it verifies by byte count that the live settings.json is not
# written. If there are no credentials, this phase SKIPS -- it never passes by
# default.
LIVE_SETTINGS="$HOME/.claude/settings.json"
LIVE_BEFORE=$(wc -c < "$LIVE_SETTINGS" 2>/dev/null || echo 0)
# CREDENTIALS ARE `.credentials.json` OR AN API KEY. NOTHING ELSE.
#
# This read `ls "$HOME/.claude"/*.json && HAVE_CREDS=1`, which matches
# **settings.json** -- a file THIS SCRIPT's own `ARM_ROUTER.sh` call creates a
# few lines below. So a runner with no credentials whatsoever reported
# HAVE_CREDS=1, ran a session that could not authenticate, and exited 1.
#
# Measured in CI run 31116857127, on all three platforms:
#     PARTIAL the router line appeared 1 time(s) but the session exited 1.
# and the job was GREEN, because PARTIAL incremented neither counter.
#
# A test that manufactures its own precondition is not a test. The glob is gone.
HAVE_CREDS=0
[ -f "$HOME/.claude/.credentials.json" ] && HAVE_CREDS=1
[ -n "${ANTHROPIC_API_KEY:-}" ] && HAVE_CREDS=1

if [ "$HAVE_CREDS" -eq 0 ]; then
  echo "  SKIP  no credentials found -- context delivery UNVERIFIED (not passed)"
else
  bash "$REPO/ARM_ROUTER.sh" > "$WORK/arm3.log" 2>&1
  # ONE RETRY WITH A DOUBLED BUDGET, and it does not weaken the claim.
  #
  # A timeout is not evidence of a defect -- a busy machine changes the pacing,
  # measured here at ${SESSION_TIMEOUT}s while the router itself fired 12 times
  # perfectly. It is not evidence of success either, so it cannot be shrugged
  # off the way the old PARTIAL branch did.
  #
  # The pass condition is UNCHANGED: the session must COMPLETE and carry the
  # line. All the retry does is refuse to call a slow machine a defect on the
  # first sample, and refuse to call it a pass on the second.
  timeout "$SESSION_TIMEOUT" claude -p "$PROMPT" \
    --settings "$SETTINGS" --debug hooks --debug-file "$WORK/ctx.debug" \
    > "$WORK/ctx.out" 2> "$WORK/ctx.err"
  CTX_RC=$?
  if [ "$CTX_RC" -eq 124 ]; then
    echo "  session[ctx] exit=124 at ${SESSION_TIMEOUT}s -- retrying ONCE at $((SESSION_TIMEOUT*2))s before calling it"
    timeout "$((SESSION_TIMEOUT*2))" claude -p "$PROMPT" \
      --settings "$SETTINGS" --debug hooks --debug-file "$WORK/ctx.debug" \
      > "$WORK/ctx.out" 2> "$WORK/ctx.err"
    CTX_RC=$?
  fi
  echo "  session[ctx] exit=$CTX_RC (real credentials, scratch --settings)"
  CTX_HIT=$(grep -cF "$MARKER" "$WORK/ctx.debug" "$WORK/ctx.out" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
  if [ "$CTX_RC" -eq 0 ] && [ "$CTX_HIT" -gt 0 ]; then
    ok "session COMPLETED (exit 0) and carried the router line $CTX_HIT time(s)"
  elif [ "$CTX_HIT" -gt 0 ]; then
    # THIS BRANCH USED TO INCREMENT NEITHER COUNTER, so a session that FAILED
    # left the run green. The label was honest -- "firing is established;
    # delivery is not" -- and the verdict still treated it as a non-failure,
    # which is the whole defect: the marker is written by the hook when the
    # prompt is submitted, BEFORE the session can die, so it is present in the
    # failure path and cannot testify to anything about the outcome.
    #
    # We have credentials here (the branch requires them), so a non-zero exit is
    # a real problem and is now counted as one. Inconclusive is not a pass.
    if [ "$CTX_RC" -eq 124 ]; then
      bad "the session TIMED OUT at ${SESSION_TIMEOUT}s -- the router line appeared $CTX_HIT time(s), but context DELIVERY is unproven. Evidence absent is not evidence of success."
    else
      bad "the session EXITED $CTX_RC with credentials present -- the router line appeared $CTX_HIT time(s), which the hook writes on submission and so proves only that the hook ran. Context DELIVERY is unproven."
    fi
  else
    bad "the router line never appeared in a completed session"
  fi
  bash "$REPO/DISARM_ROUTER.sh" > "$WORK/disarm3.log" 2>&1
fi

LIVE_AFTER=$(wc -c < "$LIVE_SETTINGS" 2>/dev/null || echo 0)
if [ "$LIVE_BEFORE" = "$LIVE_AFTER" ]; then
  ok "live settings.json unchanged across phase 3 ($LIVE_AFTER bytes)"
else
  bad "LIVE settings.json CHANGED: $LIVE_BEFORE -> $LIVE_AFTER bytes"
fi

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
echo "  artifacts: $WORK"
echo "  live ~/.claude untouched; no process signalled"
[ "$fail" -eq 0 ] && { echo "  R20: PASS"; exit 0; } || { echo "  R20: FAIL"; exit 1; }
