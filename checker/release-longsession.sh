#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE SUSTAINED SESSION: a CLONED, AUTHENTICATED Claude Code, the plugin
# INSTALLED the way a user installs it, and a REAL conversation held for
# minutes across many turns -- per release variant.
#
# WHY THIS FILE EXISTS, and it is a correction of my own work:
#
#   checker/release-session.sh runs 27 one-shot `claude -p` calls against an
#   EMPTY scratch config. Measured afterwards, every one of those sessions
#   returned:
#        is_error: true,  result: "Not logged in - Please run /login",  exit 1
#   The UserPromptSubmit hook fires BEFORE the model call, so the router output
#   appeared in the debug log and every assertion passed -- while no model turn
#   ever happened. That file proves THE HOOK FIRES IN A REAL CLI PROCESS. It
#   does not prove a conversation works, and I described it as if it did.
#
#   This is the failure mode worth naming: an empty scratch config makes a test
#   pass for a reason unrelated to the thing under test. The fix is not a
#   stricter grep, it is CLONING a working config so the session is real.
#
# WHAT IS CLONED, and what is deliberately NOT:
#   CLONED   .credentials.json and .claude.json -- the authentication and CLI
#            state that make the scratch session a REAL session.
#   NOT      the live settings.json. It registers this repository's own
#            rot-router under UserPromptSubmit; copying it would make the
#            "plugin absent" control print the marker anyway, and a control that
#            cannot fail proves nothing. The hook surface starts CLEAN and the
#            plugin under test is the only thing that adds to it.
#
# TWO INSTALL PATHS, because users have two:
#   PLUGIN   `claude --plugin-dir <artifact.zip>` -- the CLI loads a plugin
#            straight from the release zip. This is the marketplace shape.
#   HOOK     ARM_ROUTER.sh writing into the cloned settings.json.
#
# THE ORACLE IS THE ARTIFACT'S OWN ROUTER. For every prompt this harness runs
# the shipped hooks/rot-router.sh locally on the same text and requires the LIVE
# session to have produced the SAME lane. A hard-coded expectation table would
# be a second source of truth -- and it would be wrong: measured, the prompt
# "now I feel lonely and tired" routes EXECUTIVE, not EMPATHIC, because `now` is
# an EXECUTIVE stem and EXECUTIVE is tested first. The router is right; a
# hand-written expectation would have been wrong.
#
# SAFETY:
#   * The live ~/.claude is opened READ-ONLY, for two files. Never written,
#     never armed, never disarmed. An interlock aborts if the installer would
#     resolve anywhere but the scratch clone.
#   * NO process is signalled, by PID or by pattern.
#   * Every turn is bounded by `timeout`.
#   * The clone holds a real credential: it lives under the scratchpad and is
#     removed on exit, including on failure.
#
# Exit: 0 all variants held a real multi-turn conversation with the router
#       firing every turn · 1 failure · 2 refuse · 3 SKIP (no CLI / no auth).
# =============================================================================


# THIS HARNESS DECLARES ITS OWN TRAFFIC.
#
# Measured 2026-08-09: seven checkers feed the router synthetic payloads and
# write into whatever ROTMOE_DEBUG_LOG points at. 738 of 955 sh route records
# in the live log were theirs, and nothing in the schema said so -- so every
# "live router health" figure computed from that log silently mixed real
# lifecycle traffic with replayed corpus traffic. The instrument was
# contaminating its own measurement and could not report that it was.
#
# RotSessionLog.test_is_never_hook proves the consequence: a record declared
# here can never be classified as live traffic, whatever the payload contains.
export ROTMOE_DEBUG_SRC=test

# Never write a per-session log into the repository being tested. A checker
# that leaves files behind is not a read-only observer.
export ROTMOE_DEBUG_LOCAL=0

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=release-longsession::%s\n' "$*"; FAIL=$((FAIL+1)); }
note() { printf '  ----  %s\n' "$*"; }

command -v claude >/dev/null 2>&1 || { echo "SKIP: the claude CLI is not on PATH"; exit 3; }
command -v node   >/dev/null 2>&1 || { echo "REFUSE: node absent (needed to parse the result JSON)"; exit 2; }
command -v unzip  >/dev/null 2>&1 || { echo "REFUSE: unzip absent"; exit 2; }

REL="${ROTMOE_RELEASE_DIR:-$REPO/.release}"
# THE MAP IS ASKED FOR, NEVER COPIED. This file was once the THIRD copy of a
# map defined exactly once, in checker/release-package.sh -- found 2026-08-04
# while fixing the second copy, then found AGAIN by workflow-lint rule 6 when
# the copy had become a sed over the packager's source text, which broke the
# day the map stopped being a literal. A constant duplicated in three places is
# not a constant, it is three independent claims that happen to agree until one
# of them does not. Execute the packager and let it print the map it will use.
#
# SINCE 6.0.0 the map is one line per variant, `<archive-basename>:<version>`:
# version-less constant names, the tier in the name. The names ARE spelled in
# archive_of below -- but spelled AND verified against the packager's answer,
# so a rename there becomes a loud failure here, not a hunt for a ghost.
VARIANT_MAP=$(bash "$REPO/checker/release-package.sh" --print-variants 2>/dev/null)
case "$VARIANT_MAP" in
  *RoT-MoE-*.zip:*) : ;;
  *) echo "REFUSE: could not parse the variant map from checker/release-package.sh (got '$VARIANT_MAP')."
     echo "        Refusing a hardcoded fallback -- that is the drift being removed."
     exit 2 ;;
esac
WANT="${ROTMOE_VARIANTS:-core lean unsealed}"

TURN_TIMEOUT="${ROTMOE_TURN_TIMEOUT:-180}"
# Wall-clock budget PER VARIANT. Three variants at 400s is a ~20 minute run.
BUDGET="${ROTMOE_TURN_BUDGET:-400}"

LIVE="$HOME/.claude"
SCRATCH_ROOT="${ROTMOE_SCRATCHPAD:-D:/Temp/claude/rotmoe-longsession}"
mkdir -p "$SCRATCH_ROOT" 2>/dev/null || SCRATCH_ROOT="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "$SCRATCH_ROOT/run.XXXXXX")"
# The clone carries a real credential. Remove it on EVERY exit path.
trap 'rm -rf "$WORK"' EXIT INT TERM

echo "== sustained session :: cloned auth, plugin installed, real conversation =="
note "claude $(claude --version 2>&1 | head -1)"
note "scratchpad: $WORK"
note "budget: ${BUDGET}s per variant, turn timeout ${TURN_TIMEOUT}s"

[ -r "$LIVE/.credentials.json" ] || { echo "SKIP: no $LIVE/.credentials.json to clone -- cannot hold a real session"; exit 3; }

archive_of () {   # $1 = tier -> the basename the packager declares for it
  case "$1" in
    core)     _b="RoT-MoE-Router.zip" ;;
    lean)     _b="RoT-MoE-Router-Lean.zip" ;;
    unsealed) _b="RoT-MoE-Router-Lean-Extra.zip" ;;
    *)        return 1 ;;
  esac
  for vp in $VARIANT_MAP; do
    [ "${vp%%:*}" = "$_b" ] && { printf '%s' "$_b"; return 0; }
  done
  return 1
}

# --- the conversation ---------------------------------------------------------
# A working session, not a lane drill: the turns build on each other, and they
# sweep the lane table as a side effect. Turn 1 opens the session; the rest are
# resumed into it, which is the only way to observe a hook that fires once and
# then stops.
turn_text () {
  case "$1" in
    1)  echo "Give me a one-line summary of what a UserPromptSubmit hook does." ;;
    2)  echo "debug this error for me: the audit found a security regression" ;;
    3)  echo "I feel lonely and tired today, this whole story makes me sad" ;;
    4)  echo "plan the roadmap and prioritize the legal strategy for that" ;;
    5)  echo "invent a surreal paradox about it, embrace the chaos" ;;
    6)  echo "what is the likely future scenario, forecast the trend" ;;
    7)  echo "compress your last answer, distill it concise, fewer tokens" ;;
    8)  echo "refactor the meta architecture, evolve the ontology" ;;
    9)  echo "decide, declare the urgency, conclude it" ;;
    10) echo "lake build the theorem and fix the sorry in mathlib" ;;
    11) echo "Recall: what did I ask you in my very first message this session?" ;;
    12) echo "Name one thing you have said earlier in this conversation." ;;
    # PAST THE SCRIPTED TURNS, CYCLE THE LANES -- do not emit filler.
    # Measured on the first full run: a constant tail prompt carries no stems, so
    # turns 13..76 all routed CONVERGENT. Every one of them still proved the hook
    # FIRES late in a long session, which is the point of the budget, but they
    # stopped exercising the TABLE. Cycling means a 400-second run re-tests all
    # nine lanes deep into the conversation, where a truncated or compacted
    # context is most likely to break routing.
    *)  _c=$(( ($1 - 13) % 9 + 2 )); turn_text "$_c" ;;
  esac
}

MARKER="MoE :: TIER"

TOTAL_TURNS=0; TOTAL_FIRED=0; TOTAL_REAL=0

for v in $WANT; do
  zn="$(archive_of "$v")"
  if [ -z "$zn" ]; then
    bad "$v: the packager's map does not declare this tier's archive -- name drift, not a missing build"
    continue
  fi
  ART="$REL/$zn"
  echo
  echo "############ $v ($zn) ############"
  [ -s "$ART" ] || { bad "$v: no artifact at $ART -- run checker/release-package.sh"; continue; }

  VW="$WORK/$v"; CFG="$VW/.claude"; PLUG="$VW/plugin"
  mkdir -p "$CFG" "$PLUG"
  unzip -q "$ART" -d "$PLUG" 2>/dev/null || { bad "$v: artifact did not unpack"; continue; }

  # --- CLONE: authentication only, hook surface clean ------------------------
  cp "$LIVE/.credentials.json" "$CFG/.credentials.json" 2>/dev/null \
    && ok "$v: cloned the credential into the scratchpad (live config read-only)" \
    || { bad "$v: could not clone the credential"; continue; }
  [ -r "$HOME/.claude.json" ] && cp "$HOME/.claude.json" "$CFG/.claude.json" 2>/dev/null
  [ -s "$CFG/.claude.json" ] || printf '{}' > "$CFG/.claude.json"
  printf '{\n  "model": "sonnet"\n}\n' > "$CFG/settings.json"
  cp "$CFG/settings.json" "$VW/settings.before.json"

  # --- AUTH GATE: prove the clone can actually talk, BEFORE trusting a turn --
  # Without this the whole run can pass on hook-fired-but-never-answered, which
  # is exactly how release-session.sh misled me.
  CLAUDE_CONFIG_DIR="$CFG" timeout "$TURN_TIMEOUT" claude -p "Reply with the single word: READY" \
      --output-format json > "$VW/auth.json" 2>"$VW/auth.err"
  authrc=$?
  aerr=$(node -e 'try{const j=require(process.argv[1]);console.log(j.is_error?("ERR:"+String(j.result).slice(0,80)):"OK")}catch(e){console.log("PARSE")}' "$VW/auth.json" 2>/dev/null)
  if [ "$aerr" = "OK" ] && [ "$authrc" -eq 0 ]; then
    ok "$v: the cloned session is AUTHENTICATED and answered a real turn"
  else
    bad "$v: the clone cannot hold a real session ($aerr, exit $authrc) -- every later turn would be meaningless"
    continue
  fi

  # --- INSTALL, the plugin way: the CLI loads it straight from the zip -------
  # `--plugin-dir` accepts a directory OR a .zip (measured: claude --help).
  # This is the marketplace shape, and it never touches settings.json.
  run_turn () {   # $1 tag, $2 prompt, $3 "plug"|"noplug", $4 session-id-or-empty
    _tag="$1"; _p="$2"; _mode="$3"; _sid="${4:-}"
    set -- -p "$_p" --output-format json --debug hooks --debug-file "$VW/$_tag.debug"
    [ "$_mode" = "plug" ] && set -- "$@" --plugin-dir "$ART"
    [ -n "$_sid" ] && set -- "$@" --resume "$_sid"
    CLAUDE_CONFIG_DIR="$CFG" timeout "$TURN_TIMEOUT" claude "$@" \
      > "$VW/$_tag.json" 2> "$VW/$_tag.err"
    return $?
  }
  sid_of  () { node -e 'try{console.log(require(process.argv[1]).session_id||"")}catch(e){console.log("")}' "$1" 2>/dev/null; }
  real_of () { node -e 'try{const j=require(process.argv[1]);console.log(j.is_error?"no":"yes")}catch(e){console.log("no")}' "$1" 2>/dev/null; }
  # THE ORACLE: the artifact's own router, on the same text.
  oracle  () { printf '{"prompt":%s}' "$(node -e 'console.log(JSON.stringify(process.argv[1]))' "$1")" \
                 | bash "$PLUG/hooks/rot-router.sh" 2>/dev/null | sed -n 's/.*-> //p' | head -1; }

  echo "-- a real conversation, resumed turn after turn, budget ${BUDGET}s --"
  START=$(date +%s); n=0; SID=""; fired=0; realturns=0; matched=0
  while :; do
    now=$(date +%s); [ $((now-START)) -ge "$BUDGET" ] && break
    n=$((n+1))
    p="$(turn_text "$n")"
    run_turn "t$n" "$p" plug "$SID"; trc=$?
    if [ "$trc" -eq 124 ]; then note "turn $n TIMED OUT -- evidence absent, not negative"; continue; fi
    [ -z "$SID" ] && SID="$(sid_of "$VW/t$n.json")"
    TOTAL_TURNS=$((TOTAL_TURNS+1))
    [ "$(real_of "$VW/t$n.json")" = "yes" ] && { realturns=$((realturns+1)); TOTAL_REAL=$((TOTAL_REAL+1)); }
    # THE DEBUG LOG CONTAINS *LITERAL* BACKSLASH-r BACKSLASH-n, not control
    # characters -- Claude Code writes the hook's stdout JSON-escaped:
    #     "Hook UserPromptSubmit ... success:\nRoT MoE :: TIER 1 -> FORGE Claude\r\n"
    # The first draft trimmed that with  tr -d '\r\\n"'  whose SET expands to the
    # four characters CR, backslash, n and quote -- so it deleted every letter
    # `n` in the payload: AntiVenom became AtiVeom, none became oer, and all ten
    # turns reported MISMATCH against a router that was correct every time.
    # A comparator that mangles its input fails LOUDLY here, which is lucky; the
    # same class of bug in the other direction reports a clean match forever.
    live="$(grep -hF "$MARKER" "$VW/t$n.debug" 2>/dev/null | sed -n 's/.*-> //p' | head -1 \
            | sed 's/\\[rn]//g; s/"[[:space:]]*$//; s/[[:space:]]*$//')"
    if [ -n "$live" ]; then fired=$((fired+1)); TOTAL_FIRED=$((TOTAL_FIRED+1)); fi
    want="$(oracle "$p" | sed 's/[[:space:]]*$//')"
    if [ -n "$live" ] && [ "$live" = "$want" ]; then matched=$((matched+1)); fi
    printf '    turn %-2s  router=%-18s oracle=%-18s %s\n' "$n" "${live:-<SILENT>}" "${want:-?}" \
      "$([ -n "$live" ] && [ "$live" = "$want" ] && echo match || echo MISMATCH)"
  done
  elapsed=$(( $(date +%s) - START ))
  note "$v: $n turns in ${elapsed}s of continuous conversation"

  [ "$n" -ge 3 ] && ok "$v: held a multi-turn conversation ($n turns, ${elapsed}s)" \
                 || bad "$v: only $n turn(s) -- not a sustained session"
  [ "$realturns" -eq "$TOTAL_TURNS" ] 2>/dev/null || true
  if [ "$realturns" -eq "$n" ] && [ "$n" -gt 0 ]; then
    ok "$v: every one of $n turns was a REAL model answer (is_error false)"
  else
    bad "$v: only $realturns of $n turns were real model answers"
  fi
  if [ "$fired" -eq "$n" ] && [ "$n" -gt 0 ]; then
    ok "$v: the router fired on EVERY turn ($fired/$n) -- it does not stop after turn 1"
  else
    bad "$v: the router fired on only $fired of $n turns"
  fi
  if [ "$matched" -eq "$n" ] && [ "$n" -gt 0 ]; then
    ok "$v: the live lane agreed with the shipped router on all $n turns"
  else
    bad "$v: $((n-matched)) of $n turns disagreed with the artifact's own router"
  fi
  [ -n "$SID" ] && ok "$v: session continuity held (id ${SID%%-*}...)" \
                || bad "$v: no session id -- the turns were not one conversation"

  # --- CONTROL 1: same cloned config, plugin NOT loaded ---------------------
  run_turn "noplug" "$(turn_text 10)" noplug ""; nrc=$?
  # `grep -c` PRINTS 0 and EXITS 1 when there is no match, so `|| echo 0`
  # appended a SECOND zero and the variable became the two-line string "0\n0",
  # which then blew up `[ "$nhit" -eq 0 ]` with "integer expression expected"
  # and reported the control DEAD. Take the count, then default it -- never
  # chain an echo onto a command that already printed the answer.
  nhit=$(grep -cF "$MARKER" "$VW/noplug.debug" 2>/dev/null | head -1)
  [ -n "$nhit" ] || nhit=0
  if [ "$nrc" -eq 124 ]; then
    bad "$v: CONTROL INCONCLUSIVE -- the no-plugin turn timed out"
  elif [ "$nhit" -eq 0 ]; then
    ok "$v: CONTROL -- without --plugin-dir the router is SILENT, so the hits were the plugin"
  else
    bad "$v: CONTROL DEAD -- marker appears $nhit time(s) with NO plugin loaded"
    grep -hF "$MARKER" "$VW/noplug.debug" | head -2 | sed 's/^/        /'
  fi

  # --- CONTROL 2: the plugin path must not have written to settings.json ----
  if cmp -s "$VW/settings.before.json" "$CFG/settings.json"; then
    ok "$v: settings.json is BYTE-IDENTICAL -- --plugin-dir installs without editing config"
  else
    bad "$v: --plugin-dir MODIFIED settings.json:"
    diff -u "$VW/settings.before.json" "$CFG/settings.json" 2>/dev/null | head -8 | sed 's/^/        /'
  fi
done

echo
printf '  ----  %d turns total, %d real model answers, %d router firings\n' "$TOTAL_TURNS" "$TOTAL_REAL" "$TOTAL_FIRED"
[ "$TOTAL_TURNS" -eq 0 ] && bad "NO TURN RAN AT ALL -- harness failure, not a pass"

printf '\n== sustained session: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
