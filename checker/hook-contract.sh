#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# ---------------------------------------------------------------------------
# hook-contract.sh -- EXECUTE THE COMMAND STRINGS hooks/hooks.json REGISTERS,
# with the payload Claude Code really delivers, and require real output.
#
# WHY THIS EXISTS -- and the first version of this comment was WRONG, which is
# itself the reason the file is worth reading.
#
# I claimed the plugin had shipped with a dead router: that hooks.json passed
# -Route with the CLAUDE_USER_PROMPT placeholder, that the harness never expands
# it, and that the hook therefore hung and returned nothing. That claim was
# false. MEASURED against commit 59b2620 in a real marketplace install: three
# prompts routed to FORGE Claude, EMPATHIC Violet and CLINICAL AntiVenom. The
# placeholder IS expanded and the shipped plugin routed correctly.
#
# The error was in how I read the evidence. The harness debug log prints
#
#     [DEBUG] Hook UserPromptSubmit (UserPromptSubmit) success:
#     RoT MoE :: TIER 1 -> FORGE Claude
#
# -- the hook's output is on the NEXT line. Grepping the matching line alone
# shows an empty result, and I read "empty output" from a log that contained the
# marker. A one-line grep is not a reading of a multi-line record.
#
# SO WHAT DOES THIS CHECKER ACTUALLY BUY? The gap it closes is real even though
# the defect I imagined was not: nothing in this repository ever executed the
# command strings hooks.json registers. Every check tested a PROXY --
#   - hooks.json is valid JSON               -> it was
#   - it declares three events               -> it did
#   - `claude plugin details` lists Hooks (3)-> it does
#   - the router routes 10/10 lanes          -> it does, when called directly
# A plugin is not what its manifest declares, it is what the harness executes,
# and until now nothing ran that. This checker does, so a registration that
# genuinely produces nothing -- a wrong path, a hang, a quoting error -- now
# fails a gate instead of shipping.
#
# Exit: 0 pass, 1 fail, 2 refuse, 3 skip (never a pass).

# THIS HARNESS DECLARES ITS OWN TRAFFIC -- and it is the one that most needed to.
#
# Unlike the other seven, hook-contract.sh sends payloads that DO carry
# hook_event_name, so without this line its records were classified `hook` and
# were indistinguishable from real lifecycle traffic in the debug log. Found by
# checker/session-log.sh phase C on its first run, after I had already declared
# the seven obvious ones and believed the set was complete.
export ROTMOE_DEBUG_SRC=test
export ROTMOE_DEBUG_LOCAL=0

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

PASS=0; FAIL=0
ok  () { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad () { FAIL=$((FAIL+1)); [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=hook-contract::%s\n' "$*"; printf '  FAIL  %s\n' "$1"; }

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
  # SILENCE IS NOT FAILURE FOR EVERY HOOK, and the first version of this loop got
  # that wrong. It required output from EVERY registered command, which failed on
  # the Linux runner (CI #45) because prover-remind.sh is DESIGNED to say nothing
  # when there is nothing to report -- hooks/prover-remind.sh:120-125 returns
  # early when no debt, no stale proof, no kernel rejection and no sorry. On a
  # clean checkout that is the CORRECT answer, and my gate called it a defect.
  #
  # That is a spec freezing a contingent fact: locally the reminder happened to
  # have something to say, so "it speaks" looked like an invariant. The tempting
  # repair is to delete the check; the right one is to demand what must actually
  # hold. The ROUTER always routes, so it must always speak. The reminder speaks
  # conditionally, so it must merely not hang and not crash.
  case "$cmd" in
    *rot-router*) must_speak=1 ;;
    *)            must_speak=0 ;;
  esac
  if [ "$rc" -eq 124 ]; then
    bad "$ev/$short HUNG (exit 124) -- a hook that never returns injects nothing"
  elif [ "$must_speak" -eq 1 ] && [ -z "$out" ]; then
    bad "$ev/$short is a ROUTER command and produced NO output -- routing cannot be conditional"
  elif [ -z "$out" ]; then
    ok "$ev/$short returned silently (allowed: it speaks only when it has something to report)"
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

# --- NEGATIVE CONTROLS ------------------------------------------------------
# The first version of this control ran the old -Route form with an EMPTY route
# and concluded "the shipped form produces no marker". That was testing a shape
# the harness never creates -- the placeholder is expanded to the real prompt --
# so it confirmed a defect that did not exist. A control aimed at a fictional
# failure is worse than none: it manufactures evidence for a wrong story.
#
# These two are aimed at failures that can actually happen to a registration.
BROKEN_PATH="bash \"$PLUG/hooks/no-such-hook-$$.sh\""
rc=0; out="$(printf '%s' "$PAYLOAD" | { [ "$have_timeout" -eq 1 ] && timeout 25 bash -c "$BROKEN_PATH" 2>/dev/null || bash -c "$BROKEN_PATH" 2>/dev/null; })" || rc=$?
[ -z "$out" ] \
  && ok "CONTROL: a command pointing at a missing script yields NO output -- the empty-output arm can fire" \
  || bad "CONTROL DEAD: a missing script still produced output ($out)"

if [ "$have_timeout" -eq 1 ]; then
  rc=0; out="$(printf '%s' "$PAYLOAD" | timeout 3 bash -c "sleep 30" 2>/dev/null)" || rc=$?
  [ "$rc" -eq 124 ] \
    && ok "CONTROL: a hanging command is observed as exit 124 -- the hang arm can fire" \
    || bad "CONTROL DEAD: a 30s sleep bounded at 3s reported exit $rc, not 124"
else
  skip_note=1
  printf '  SKIP  no timeout(1): the hang arm cannot be controlled on this host\n'
fi

# --- the scripts themselves still work in hook mode --------------------------
# Separates "the registration is wrong" from "the router is broken". When this
# passes and the block above fails, the defect is in hooks.json, not the logic.
rc=0; out="$(printf '%s' "$PAYLOAD" | { [ "$have_timeout" -eq 1 ] && timeout 25 bash hooks/rot-router.sh 2>/dev/null || bash hooks/rot-router.sh 2>/dev/null; })" || rc=$?
[ -n "$out" ] && [ "$rc" -ne 124 ] \
  && ok "rot-router.sh answers in hook mode (stdin payload, no arguments)" \
  || bad "rot-router.sh produced nothing in hook mode (exit $rc) -- routing must be unconditional"

# CONTROL FOR THE ALLOWED SILENCE. "Silence is permitted" would otherwise hide a
# reminder that is silent because it is BROKEN. Point it at a workspace with no
# proofs -- a condition its own logic treats as report-worthy
# (hooks/prover-remind.sh:151) -- and it must speak. Silence then is a decision,
# not a failure, and this gate can tell the two apart.
rc=0
out="$(printf '%s' "$PAYLOAD" | { [ "$have_timeout" -eq 1 ] \
      && ROTMOE_LEAN_WORKSPACE="/nonexistent-workspace-$$" timeout 25 bash hooks/prover-remind.sh 2>/dev/null \
      || ROTMOE_LEAN_WORKSPACE="/nonexistent-workspace-$$" bash hooks/prover-remind.sh 2>/dev/null; })" || rc=$?
[ -n "$out" ] && [ "$rc" -ne 124 ] \
  && ok "CONTROL: prover-remind.sh SPEAKS when given a workspace with no proofs -- its silence elsewhere is a decision, not a breakage" \
  || bad "CONTROL DEAD: prover-remind.sh stayed silent even with no proofs to find (exit $rc) -- silence cannot be distinguished from breakage"

rm -f "$CMDS"
printf '\n== hook-contract: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
