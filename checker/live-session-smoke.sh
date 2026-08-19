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

# ROTMOE_SMOKE_PHASES -- run a NAMED SUBSET of the three phases.
#
# Why this exists. Three phases run a real session each, and phase 3 retries
# once at double the budget, so the worst case is 180+180+180+360 = 900 s in one
# process. Every caller with a shorter bound was therefore reduced to killing
# it, and phase 3 -- the only phase that asks whether the router's output
# actually REACHES the model -- had never once been measured. Measured
# 2026-08-10: a 420 s bound died mid-phase-3 with phases 1-2 already green.
#
# Lowering SESSION_TIMEOUT would have been the dishonest fix: it does not make
# the check faster, it makes it fail sooner and call a slow machine a defect.
#
#   ROTMOE_SMOKE_PHASES=3 bash checker/live-session-smoke.sh
#
# A PARTIAL RUN IS NOT A PASS. Unselected phases are counted in `phase_notrun`,
# the summary says PARTIAL, and the exit is 3 -- never 0. Only the default,
# unset, can produce a pass, which is what CI and the gate table invoke.
SMOKE_PHASES="${ROTMOE_SMOKE_PHASES:-1 2 3}"
phase_notrun=0
phase_selected () {
  case " $SMOKE_PHASES " in
    *" $1 "*) return 0 ;;
    *) echo "  NOTRUN  phase $1 was not selected (ROTMOE_SMOKE_PHASES='$SMOKE_PHASES')"
       phase_notrun=$((phase_notrun+1)); return 1 ;;
  esac
}

# PHASE 2 CANNOT STAND ALONE, AND THE SCRIPT SAYS SO RATHER THAN PRETENDING.
# Its whole content is the comparison `armed=N vs disarmed=M`, and N comes from
# phase 1. Selecting 2 without 1 would compare against an unset variable and
# report an attribution that was never measured -- a fake green built out of a
# convenience flag. Refuse instead.
case " $SMOKE_PHASES " in
  *" 2 "*)
    case " $SMOKE_PHASES " in
      *" 1 "*) : ;;
      *) echo "REFUSE: phase 2 is the negative control for phase 1 and reads its"
         echo "        armed count. Select '1 2' or drop 2."; exit 2 ;;
    esac ;;
esac

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
if phase_selected 1; then
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
#
# THE THIRD DEFECT, and it is the same shape as the first two. Measured on the
# macOS runner, 2026-08-08, immediately after the router was widened from 11 to
# 31 events: this phase reported "the router ERRORED 1 time(s)" while quoting
# three lines that each ended `completed with status 0`. They were successes.
#
# The cause is a NAME COLLISION with the CLI's own vocabulary. Two of the newly
# bound events are called `StopFailure` and `PostToolUseFailure`, and the CLI
# annotates a line with the reason, giving text like
#
#     [DEBUG] StopFailure:authentication_failed [pwsh ... rot-router.ps1 ...] completed with status 0
#
# The first grep selects it (the command string contains `rot-router`), and the
# second counts it (the EVENT NAME contains `failed`). Nothing failed. The router
# ran and exited 0 on an event whose name happens to be a synonym for the thing
# this detector hunts.
#
# So the status field is now read instead of trusting substrings: a line the CLI
# itself reports as `completed with status 0` cannot be evidence that the hook
# broke, whatever words appear in the event name. This is a STRENGTHENING -- the
# detector becomes precise rather than accidental -- and every genuine signal it
# caught before is still counted, which the control below proves by feeding it
# one of each.
STATUS_OK_RE='completed with status 0'
# THE FOURTH ENTRY in this detector's history, and the first where the
# detector was right about the fact and wrong about the ATTRIBUTION.
# Measured 2026-08-19 by a controlled 2x2 across two CLI releases: under
# claude CLI 2.1.235, the credential-less session's teardown line
#     [DEBUG] StopFailure:authentication_failed [...] completed with status 0
# -- the fixture below -- while under 2.1.236 the SAME teardown completes
# with status 1, on ALL THREE runner platforms, for TWO DIFFERENT TREES:
# run 197 (2.1.235, tree 29ec325) green; run 198 + its rerun (2.1.236,
# tree f0e50aa) red; run 199 (2.1.236, tree 29ec325 -- the exact tree 197
# had proven green) red. The status follows the CLI release, not the
# repository, so it is the CLI failing ITS OWN auth-failed teardown around
# a hook it invoked -- not the hook breaking. The same tree's router exits
# 0 on every StopFailure payload shape when invoked directly.
#
# So that ONE measured shape -- StopFailure with the authentication_failed
# reason, nonzero status -- is CLASSIFIED as CLI teardown and counted
# separately, out loud, never silently dropped. The exception is scoped to
# the reason string: a StopFailure with any OTHER reason and a nonzero
# status is still an error, and the control below proves the scope cannot
# widen.
CLI_TEARDOWN_RE='StopFailure:authentication_failed .*completed with status [1-9]'
ARMED_ERR=$(grep -hiE 'rot-router|Hook [A-Za-z]+ .*(failed|error)' \
              "$WORK/armed.debug" "$WORK/armed.err" 2>/dev/null \
            | grep -vE "$STATUS_OK_RE" \
            | grep -vE "$CLI_TEARDOWN_RE" \
            | grep -ciE 'no mode given|Write-Error|Exception|command not found|usage:|failed')
ARMED_TEARDOWN=$(grep -hiE 'rot-router|Hook [A-Za-z]+ .*(failed|error)' \
              "$WORK/armed.debug" "$WORK/armed.err" 2>/dev/null \
            | grep -cE "$CLI_TEARDOWN_RE")
[ "$ARMED_TEARDOWN" -gt 0 ] && \
  echo "  ----  $ARMED_TEARDOWN CLI-teardown line(s) classified, not counted: the CLI failing its own auth-failed teardown around the hook (measured behavior change at claude CLI 2.1.236)"

# CONTROL, run every time, because a detector nobody has deliberately tripped is
# an untested alarm -- and this one has now been wrong three separate ways.
CTLDIR="$WORK/errdet-control"; mkdir -p "$CTLDIR"
printf '%s\n' \
  '2026-08-08T22:03:11.402Z [DEBUG] StopFailure:authentication_failed [pwsh -NoProfile -File "/x/hooks/rot-router.ps1"] completed with status 0' \
  > "$CTLDIR/benign.log"
printf '%s\n' \
  '2026-08-08T22:03:11.402Z [DEBUG] Stop:end [pwsh -NoProfile -File "/x/hooks/rot-router.ps1"] no mode given (-Vector or -Route)' \
  > "$CTLDIR/real.log"
printf '%s\n' \
  '2026-08-19T20:17:15.353Z [DEBUG] StopFailure:authentication_failed [bash "/x/hooks/rot-router.sh"] completed with status 1' \
  > "$CTLDIR/teardown.log"
# The widening probe must stay CATCHABLE by the keyword tail (its first
# draft used a reason with no 'failed' in it, which the base detector never
# counted anyway -- the control caught its own fixture testing nothing).
printf '%s\n' \
  '2026-08-19T20:17:15.353Z [DEBUG] StopFailure:network_failed [bash "/x/hooks/rot-router.sh"] completed with status 1' \
  > "$CTLDIR/otherstop.log"
_count_err() {
  grep -hiE 'rot-router|Hook [A-Za-z]+ .*(failed|error)' "$1" 2>/dev/null \
    | grep -vE "$STATUS_OK_RE" \
    | grep -vE "$CLI_TEARDOWN_RE" \
    | grep -ciE 'no mode given|Write-Error|Exception|command not found|usage:|failed'
}
CTL_BENIGN=$(_count_err "$CTLDIR/benign.log")
CTL_REAL=$(_count_err "$CTLDIR/real.log")
CTL_TEARDOWN=$(_count_err "$CTLDIR/teardown.log")
CTL_OTHERSTOP=$(_count_err "$CTLDIR/otherstop.log")
if [ "$CTL_BENIGN" -eq 0 ]; then
  ok "CONTROL: a StopFailure line that completed with status 0 is NOT counted as an error"
else
  bad "CONTROL: the detector still counts a successful StopFailure line ($CTL_BENIGN)"
fi
if [ "$CTL_REAL" -eq 1 ]; then
  ok "CONTROL: a real router failure IS still counted -- the detector can fire"
else
  bad "CONTROL: the detector no longer catches a real failure ($CTL_REAL) -- it was weakened, not sharpened"
fi
if [ "$CTL_TEARDOWN" -eq 0 ]; then
  ok "CONTROL: the CLI's auth-failed teardown (status 1, CLI >= 2.1.236) is classified, not counted"
else
  bad "CONTROL: the 2.1.236 teardown line is still counted as a router error ($CTL_TEARDOWN)"
fi
if [ "$CTL_OTHERSTOP" -eq 1 ]; then
  ok "CONTROL: a StopFailure with any OTHER reason and status 1 is STILL an error -- the exception cannot widen"
else
  bad "CONTROL: the teardown exception swallowed a non-auth StopFailure ($CTL_OTHERSTOP) -- it was weakened, not scoped"
fi
if [ "$ARMED_ERR" -eq 0 ]; then
  ok "ARMED: no error attributable to the router"
else
  bad "ARMED: the router ERRORED $ARMED_ERR time(s) -- invoked, but not working:"
  grep -hiE 'rot-router|Hook [A-Za-z]+ .*(failed|error)' \
    "$WORK/armed.debug" "$WORK/armed.err" 2>/dev/null | head -3 | sed 's/^/        /'
fi

# The routing decision itself must be correct, not merely present. The prompt is
# "lake build the theorem": three FORGE stems, so any other lane is a defect.
#
# THE EXPECTED STRING IS READ FROM THE ROUTER, NOT FROZEN HERE. This was the
# literal `FORGE Claude`, which would redden this checker on the day the FORGE
# lead is renamed -- a correct change failing a green test, which is how real
# coverage gets deleted. What must hold is that THIS PROMPT reaches THE FORGE
# LANE; the lead's spelling belongs to the router source.
EXPECT_FORGE=$(grep -oE '_lane="FORGE [A-Za-z]+"' "$REPO/hooks/rot-router.sh" \
               | sed 's/_lane="//; s/"$//' | head -1)
if [ -z "$EXPECT_FORGE" ]; then
  bad "could not read the FORGE lane string out of hooks/rot-router.sh -- routing cannot be checked"
# AND THE LINE PRINTED AS EVIDENCE IS THE LINE THAT SATISFIED THE CHECK.
# It used to be `head -1` over ALL marker lines, which printed the SessionStart
# emission (`CONVERGENT model`) directly underneath a PASS that had been earned
# by a different, later line. The verdict was right and the evidence under it
# was not the evidence -- exactly the shape this project exists to refuse.
# R20: the match is COLLECTED, not tested through `grep -q`. Piping into
# `grep -q` under pipefail makes a MATCH exit 141 (SIGPIPE kills the upstream
# grep the moment -q stops reading), so the successful case reports failure.
# Collecting the line once also means the evidence printed below is literally
# the string that satisfied the check, not a second independent search.
elif _FORGE_HIT=$(grep -hF "$MARKER" "$WORK/armed.debug" "$WORK/armed.out" 2>/dev/null \
                    | grep -F "$EXPECT_FORGE" | head -1) && [ -n "$_FORGE_HIT" ]; then
  ok "ARMED: routed CORRECTLY -- '$PROMPT' -> $EXPECT_FORGE"
  printf '        %s\n' "$_FORGE_HIT"
else
  bad "ARMED: wrong lane for '$PROMPT' (expected $EXPECT_FORGE)"
  grep -hF "$MARKER" "$WORK/armed.debug" "$WORK/armed.out" 2>/dev/null | head -2 | sed 's/^/        /'
fi

fi   # end phase 1

# ============================================================================
if phase_selected 2; then
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

fi   # end phase 2

# ============================================================================
if phase_selected 3; then
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
# router's line reaches the model's CONTEXT. That is a separate claim, and the
# FIRST version of this phase got it wrong in three separate ways. All three
# were measured on 2026-08-10, the first time this phase was ever executed:
#
#  (1) NO ISOLATION. It ran without CLAUDE_CONFIG_DIR "for credentials", which
#      also inherits the live plugin root. The debug log recorded
#      `Registered 68 hooks from 7 plugins`, and the author's own live copy of
#      this very router was among them. Every marker hit was therefore
#      unattributable: the packet under test and a second installed copy write
#      byte-identical lines. Now the credential FILE is copied into the scratch
#      dir and CLAUDE_CONFIG_DIR points there, measured `0 hooks from 0 plugins`.
#
#  (2) IT COULD NOT COMPLETE. The prompt was `lake build the theorem`, which
#      starts a full agentic session; with 19 hooks per tool call it exited 124
#      at 180 s and 124 again at 360 s. The claim under test -- "the line
#      reaches the model" -- needs no tool use at all, so the agentic prompt was
#      pure cost. The delivery prompt below completes in seconds.
#
#  (3) THE OBSERVABLE WAS THE WRONG CHANNEL, and the old comment below admitted
#      it in prose while the code still counted it: the marker was grepped out
#      of the hook DEBUG LOG, which is the hook's own echo of its own output. A
#      hook that fires into a void writes exactly the same bytes there. The
#      PASS condition is now the marker appearing in the session's STDOUT --
#      the model's answer stream, which no hook can write -- in reply to a
#      prompt that asks the model to quote the line back. Firing is still
#      recorded from the debug log, but it is EVIDENCE, not the verdict.
#
# The pass condition is strictly STRONGER than the one it replaces: it demands
# everything the old one did (session exit 0, marker present) plus delivery
# through a channel the hook cannot reach, plus a disarmed negative control at
# that same channel.
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
HAVE_CREDS=0; CRED_SRC=''
[ -f "$HOME/.claude/.credentials.json" ] && { HAVE_CREDS=1; CRED_SRC='file'; }
[ -n "${ANTHROPIC_API_KEY:-}" ] && { HAVE_CREDS=1; CRED_SRC="${CRED_SRC:-env}"; }

# THE DELIVERY PROMPT. It asks for one line back and nothing else, so the
# session needs no tool, no file and no build -- the entire agentic loop that
# made the old prompt time out is simply not entered. The `NO-SUCH-LINE`
# alternative is what makes the disarmed control readable: the model is given a
# way to say "absent" that is distinguishable from "the session broke".
DELIVERY_PROMPT="Output verbatim, and nothing else, the single line in your context that begins with the characters 'RoT MoE ::'. If no such line exists, output exactly NO-SUCH-LINE."

# THE COPIED CREDENTIAL IS REMOVED ON EVERY EXIT PATH, INCLUDING A KILL.
# $WORK is deliberately kept for artifacts, so a token left in it would outlive
# the run in a world-readable temp dir. Failure to remove it is announced --
# never swallowed -- because the operator has to know to delete it by hand.
cleanup_creds () {
  [ -f "$CLAUDE_DIR/.credentials.json" ] || return 0
  rm -f "$CLAUDE_DIR/.credentials.json"
  if [ -f "$CLAUDE_DIR/.credentials.json" ]; then
    echo "  WARN  could not remove the copied credential:"
    echo "        $CLAUDE_DIR/.credentials.json  -- DELETE IT BY HAND"
  fi
}
trap cleanup_creds EXIT INT TERM

if [ "$HAVE_CREDS" -eq 0 ]; then
  echo "  SKIP  no credentials found -- context delivery UNVERIFIED (not passed)"
else
  # ISOLATION IS THE ATTRIBUTION. Copying the credential into the scratch dir
  # lets CLAUDE_CONFIG_DIR stay pinned there, so the session loads the packet
  # under test and NOTHING else. Without this the live plugin root came with
  # the credentials -- measured `Registered 68 hooks from 7 plugins` -- and any
  # second copy of this router installed on the machine forged the evidence.
  if [ "$CRED_SRC" = 'file' ]; then
    ( umask 077; cat "$HOME/.claude/.credentials.json" > "$CLAUDE_DIR/.credentials.json" )
    if [ -s "$CLAUDE_DIR/.credentials.json" ]; then
      ok "credential isolated into the scratch config dir (mode 600, removed on exit)"
    else
      bad "could not isolate the credential -- refusing to fall back to the live config dir"
    fi
  else
    ok "credential comes from ANTHROPIC_API_KEY -- no file copy needed"
  fi

  deliver_session () {   # deliver_session <tag> -> $WORK/<tag>.{out,err,debug}
    CLAUDE_CONFIG_DIR="$CLAUDE_DIR" \
    timeout "$SESSION_TIMEOUT" claude -p "$DELIVERY_PROMPT" \
      --settings "$SETTINGS" --debug hooks --debug-file "$WORK/$1.debug" \
      > "$WORK/$1.out" 2> "$WORK/$1.err"
    rc=$?
    # ONE RETRY WITH A DOUBLED BUDGET, and it does not weaken the claim: the
    # pass condition is unchanged, the retry only refuses to call a slow
    # machine a defect on the first sample, and refuses to call it a pass on
    # the second.
    if [ "$rc" -eq 124 ]; then
      echo "  session[$1] exit=124 at ${SESSION_TIMEOUT}s -- retrying ONCE at $((SESSION_TIMEOUT*2))s"
      CLAUDE_CONFIG_DIR="$CLAUDE_DIR" \
      timeout "$((SESSION_TIMEOUT*2))" claude -p "$DELIVERY_PROMPT" \
        --settings "$SETTINGS" --debug hooks --debug-file "$WORK/$1.debug" \
        > "$WORK/$1.out" 2> "$WORK/$1.err"
      rc=$?
    fi
    return $rc
  }

  # `grep -c` PRINTS 0 AND EXITS 1 ON NO MATCH. `grep -c ... || echo 0` emits
  # TWO lines and poisons the arithmetic that reads it -- that bug cost a real
  # debugging pass in this repo (CP52). Read the value, then sanitise it.
  count_marker () {
    _n=$(grep -cF "$MARKER" "$1" 2>/dev/null)
    case "$_n" in ''|*[!0-9]*) _n=0 ;; esac
    printf '%s' "$_n"
  }

  bash "$REPO/ARM_ROUTER.sh" > "$WORK/arm3.log" 2>&1
  ARM3_RC=$?
  [ "$ARM3_RC" -eq 0 ] && ok "phase 3 ARM_ROUTER exit 0" || bad "phase 3 ARM_ROUTER exit $ARM3_RC"

  deliver_session ctx
  CTX_RC=$?
  echo "  session[ctx] exit=$CTX_RC (isolated config, armed)"

  CTX_OUT_HIT=$(count_marker "$WORK/ctx.out")     # the MODEL's answer stream
  CTX_DBG_HIT=$(count_marker "$WORK/ctx.debug")   # the hook's own echo

  # THE VERDICT READS THE MODEL'S STREAM, NOT THE HOOK'S. A hook firing into a
  # void writes the debug line either way; only stdout carries what the model
  # actually received and repeated back.
  if [ "$CTX_RC" -eq 0 ] && [ "$CTX_OUT_HIT" -gt 0 ]; then
    ok "DELIVERED: the model quoted the router line back in its own output ($CTX_OUT_HIT line(s), session exit 0)"
  elif [ "$CTX_RC" -ne 0 ]; then
    bad "the session exited $CTX_RC with credentials present -- delivery unproven (hook fired $CTX_DBG_HIT time(s), which proves only that the hook ran)"
  else
    bad "the session completed but the model did NOT quote the line -- the hook fired $CTX_DBG_HIT time(s) into a context the model never received"
    head -3 "$WORK/ctx.out" | sed 's/^/        /'
  fi

  # THE GRAMMAR IS READ FROM THE ROUTER SOURCE, NOT FROZEN HERE. Pinning today's
  # lane list into this checker would redden a correct future the day a lane is
  # added; deriving it means the check follows the router instead of fighting it.
  LANES=$(grep -oE '_lane="[A-Z]+ ' "$REPO/hooks/rot-router.sh" \
          | sed 's/_lane="//; s/ $//' | sort -u | tr '\n' '|' | sed 's/|$//')
  ECHOED=$(grep -F "$MARKER" "$WORK/ctx.out" 2>/dev/null | head -1)
  if [ -z "$LANES" ]; then
    bad "could not derive the lane vocabulary from hooks/rot-router.sh -- the grammar check cannot run"
  elif [ -z "$ECHOED" ]; then
    echo "  NOTE  no echoed line to check the grammar of (covered by the failure above)"
  # R20 again: collected, not piped into `grep -q`. Under pipefail a MATCH would
  # exit 141 here and the grammar check would report failure on a correct line.
  elif [ -n "$(printf '%s' "$ECHOED" | grep -E "^RoT MoE :: TIER 1 -> ($LANES) [^|]*\| R/s\+ [0-9]+\.[0-9]+")" ]; then
    ok "the delivered line parses as a router line with a declared lane: $ECHOED"
  else
    bad "the delivered line does not match the router's own grammar: $ECHOED"
  fi

  # ---- NEGATIVE CONTROL AT THE SAME CHANNEL -------------------------------
  # Without this a model that INVENTS the line passes phase 3. It also proves
  # the isolation held: a leaked live plugin root would fire its own router
  # here and put the marker back in the debug log with the scratch settings
  # disarmed. Both counters must be zero.
  bash "$REPO/DISARM_ROUTER.sh" > "$WORK/disarm3.log" 2>&1
  DIS3_RC=$?
  [ "$DIS3_RC" -eq 0 ] && ok "phase 3 DISARM_ROUTER exit 0" || bad "phase 3 DISARM_ROUTER exit $DIS3_RC"

  deliver_session ctx2
  CTX2_RC=$?
  echo "  session[ctx2] exit=$CTX2_RC (isolated config, DISARMED)"
  CTX2_OUT_HIT=$(count_marker "$WORK/ctx2.out")
  CTX2_DBG_HIT=$(count_marker "$WORK/ctx2.debug")

  if [ "$CTX2_RC" -ne 0 ]; then
    bad "the disarmed control session exited $CTX2_RC -- the control is absent, so the armed run attributes nothing"
  elif [ "$CTX2_OUT_HIT" -eq 0 ] && [ "$CTX2_DBG_HIT" -eq 0 ]; then
    ok "CONTROL: disarmed, the line is absent from BOTH the model's output and the hook log (0/0)"
  elif [ "$CTX2_DBG_HIT" -gt 0 ]; then
    bad "ISOLATION BROKEN: the marker appears $CTX2_DBG_HIT time(s) with the scratch settings disarmed -- another installed copy of the router is firing, and the armed run proves nothing"
  else
    bad "the model produced the line with the router DISARMED ($CTX2_OUT_HIT) -- it was invented, not delivered"
  fi

  if [ "$CTX_OUT_HIT" -gt 0 ] && [ "$CTX2_OUT_HIT" -eq 0 ]; then
    ok "delivery is ATTRIBUTABLE: armed=$CTX_OUT_HIT vs disarmed=$CTX2_OUT_HIT at the model's own output"
  else
    bad "delivery NOT attributable: armed=$CTX_OUT_HIT vs disarmed=$CTX2_OUT_HIT at the model's own output"
  fi

  # INFORMATIVE ONLY -- the wording of this line belongs to the CLI, not to us,
  # so it is reported and never made a verdict. The isolation VERDICT is the
  # disarmed debug count above, which depends on no log wording at all.
  PLUGINS=$(grep -oE 'Registered [0-9]+ hooks from [0-9]+ plugins' "$WORK/ctx.debug" 2>/dev/null | sort -u | head -1)
  [ -n "$PLUGINS" ] && echo "  INFO  isolation, as the CLI reports it: $PLUGINS"

  cleanup_creds
fi

LIVE_AFTER=$(wc -c < "$LIVE_SETTINGS" 2>/dev/null || echo 0)
if [ "$LIVE_BEFORE" = "$LIVE_AFTER" ]; then
  ok "live settings.json unchanged across phase 3 ($LIVE_AFTER bytes)"
else
  bad "LIVE settings.json CHANGED: $LIVE_BEFORE -> $LIVE_AFTER bytes"
fi

fi   # end phase 3

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
echo "  artifacts: $WORK"
echo "  live ~/.claude untouched; no process signalled"

# A PHASE THAT DID NOT RUN IS NOT A PHASE THAT PASSED.
if [ "$phase_notrun" -gt 0 ]; then
  echo "  R20: PARTIAL -- $phase_notrun phase(s) never ran (exit 3, never a pass)"
  exit 3
fi
[ "$fail" -eq 0 ] && { echo "  R20: PASS"; exit 0; } || { echo "  R20: FAIL"; exit 1; }
