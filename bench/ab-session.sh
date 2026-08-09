#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# A/B EFFICACY RUNNER -- routed vs unrouted, same prompts, same config dir.
#
# THE CLAIM UNDER TEST is the one claim no theorem in this repository touches:
# does nine-lens routing produce different output from no routing? Everything
# proved here is mechanism -- that the router routes as specified, that the
# gauge computes as specified, that the gates cannot be faked. None of it says
# the router HELPS. This runner collects the data that can answer it.
#
# The protocol is pre-registered in TASKS/2026-08-06-CP17-AB-PREREGISTRATION.md,
# written before a single turn ran, including AMENDMENT 1. This script collects;
# it does not judge. Analysis is a separate pass over the corpus so the metrics
# cannot be chosen after seeing the answers.
#
# WHAT MAKES THE TWO ARMS COMPARABLE.
#
#   same config dir       CTT, in both arms -- not a copy, THE SAME directory,
#                         so CLAUDE.md, agents, commands and model are identical
#   same prompts          bench/ab-prompts.txt, read by line number. Neither arm
#                         can drift from the other because there is one file
#   same environment      proxy variables cleared, credential refreshed one-way
#   sequential arms       arm B disarms the plugin, runs, and restores it
#
# ARM B REMOVES THE WHOLE PLUGIN, not only the router, and that is stated
# plainly rather than glossed: the plugin also ships prover-remind. So the
# comparison is "plugin installed" vs "plugin absent", which is what a user
# actually chooses between. It is NOT a clean isolation of the routing hook
# alone, and the analysis must say so.
#
# RESUMABLE. Turns are stored one JSON per turn under the corpus directory, so
# any range can be re-run and the analysis reads the files, not the run.
#
#   bash checker/ab-session.sh a 1 4      # arm A, turns 1-4
#   bash checker/ab-session.sh b 1 4      # arm B, same prompts
#   bash checker/ab-session.sh --status   # what has been collected so far
#
# Exit: 0 pass, 1 fail, 2 refuse. Never a pass on an empty collection.
# =============================================================================
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

CTT="${ROTMOE_CTT_DIR:-C:/Users/Saimono/Claude_Test/.claude}"
CORPUS="${ROTMOE_AB_CORPUS:-D:/Temp/rotmoe-ab}"
PROMPTS="$REPO/bench/ab-prompts.txt"
TURN_TIMEOUT="${ROTMOE_TURN_TIMEOUT:-120}"
REGISTRY="$CTT/plugins/installed_plugins.json"

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }
note() { printf '  ----  %s\n' "$*"; }

[ -f "$PROMPTS" ] || { echo "REFUSE: $PROMPTS missing -- the arms would not be paired"; exit 2; }
NPROMPTS=$(wc -l < "$PROMPTS")

# --- --status: report the corpus, never run anything -------------------------
if [ "${1:-}" = "--status" ]; then
  echo "== A/B corpus status =="
  # COUNT VALID TURNS, NOT FILES. A timed-out turn still creates its output
  # file (the redirect happens before the command runs), so counting files
  # reported 70 collected when five of them were empty. That is the same shape
  # of defect this repository keeps finding in other people's harnesses: an
  # instrument whose success value is reachable without the thing succeeding.
  # A turn counts only if its JSON parses AND carries a non-empty result.
  for arm in a b; do
    d="$CORPUS/arm$arm"
    read -r good empty err < <(node -e '
      const fs=require("fs"), path=process.argv[1];
      let good=0, empty=0, err=0;
      let files=[]; try{ files=fs.readdirSync(path).filter(f=>/^turn-\d+\.json$/.test(f)); }catch(e){}
      for(const f of files){
        let j=null;
        try{ j=JSON.parse(fs.readFileSync(path+"/"+f,"utf8")); }catch(e){ empty++; continue; }
        if(!j || typeof j.result!=="string" || !j.result.trim()){ empty++; continue; }
        if(j.is_error===true) err++;
        good++;
      }
      console.log(good+" "+empty+" "+err);
    ' "$d" 2>/dev/null)
    printf '  arm %s: %3s / %s VALID turns, %s empty-or-unparsable, %s with is_error\n' \
      "$arm" "${good:-0}" "$NPROMPTS" "${empty:-0}" "${err:-0}"
    if [ "${empty:-0}" -gt 0 ]; then
      miss=$(node -e '
        const fs=require("fs"), path=process.argv[1], n=Number(process.argv[2]);
        const bad=[];
        for(let i=1;i<=n;i++){
          const f=path+"/turn-"+String(i).padStart(3,"0")+".json";
          let j=null;
          try{ j=JSON.parse(fs.readFileSync(f,"utf8")); }catch(e){ bad.push(i); continue; }
          if(!j || typeof j.result!=="string" || !j.result.trim()) bad.push(i);
        }
        console.log(bad.join(","));
      ' "$d" "$NPROMPTS" 2>/dev/null)
      printf '         turns needing a re-run: %s\n' "${miss:-unknown}"
    fi
  done
  rl=$(grep -c '"kind":"route"' "$CORPUS/arma-router.log" 2>/dev/null); rl=${rl:-0}
  rb=$(grep -c '"kind":"route"' "$CORPUS/armb-router.log" 2>/dev/null); rb=${rb:-0}
  printf '  router route records: arm A = %s (must be > 0), arm B = %s (must be 0)\n' "$rl" "$rb"
  exit 0
fi

ARM="${1:-}"
FROM="${2:-1}"
TO="${3:-$NPROMPTS}"
case "$ARM" in
  a|b) ;;
  *) echo "usage: ab-session.sh <a|b> [from] [to]   |   ab-session.sh --status"; exit 2 ;;
esac
[ "$TO" -le "$NPROMPTS" ] || { echo "REFUSE: turn $TO exceeds the $NPROMPTS frozen prompts"; exit 2; }

OUT="$CORPUS/arm$ARM"
mkdir -p "$OUT" || { echo "REFUSE: cannot create $OUT"; exit 2; }
LOG="$CORPUS/arm$ARM-router.log"

echo "== A/B arm $ARM, turns $FROM..$TO =="

# --- the environment, identical in both arms ---------------------------------
export CLAUDE_CONFIG_DIR="$CTT"
export ROTMOE_DEBUG_LOG="$LOG"
_live_cred="$HOME/.claude/.credentials.json"
if [ -f "$_live_cred" ]; then
  cp "$_live_cred" "$CTT/.credentials.json" 2>/dev/null && note "credential refreshed (one-way copy, as the launcher does)"
else
  note "no live credential to copy -- turns will report their own reason"
fi
unset ANTHROPIC_BASE_URL ROLLING_CONTEXT_PORT ROLLING_CONTEXT_UPSTREAM \
      ROLLING_CONTEXT_TRIGGER ROLLING_CONTEXT_TARGET
for _v in ${ROTMOE_CTT_UNSET:-}; do unset "$_v"; done

# --- TOOLS OFF, IDENTICALLY IN BOTH ARMS -------------------------------------
# MEASURED 2026-08-07, and it is why run 1 of arm A was discarded: the process
# table caught a benchmark turn running `checker/axiom-audit.sh` against the
# repository. The prompts name real files, so the model goes and reads them --
# and sometimes RUNS them. A benchmark that executes its subject's tooling is
# measuring the machine, and five of sixty turns died on the 110 s cap doing it.
#
# The pre-registered primary endpoints are properties of LANGUAGE: trailing
# questions, hedging tokens, self-narration. Tool use adds variance correlated
# with the PROMPT rather than the ARM, which is exactly the variance a paired
# design cannot absorb.
#
# So tools are off in BOTH arms. This narrows what the experiment can claim --
# it measures the router's effect on language, not on agentic behaviour -- and
# the analysis says so rather than letting the reader assume otherwise.
NOTOOLS="${ROTMOE_AB_TOOLS:+}"
if [ -z "${ROTMOE_AB_TOOLS:-}" ]; then
  NOTOOLS="--disallowedTools Bash Read Write Edit Glob Grep Task WebFetch WebSearch TodoWrite NotebookEdit"
  note "tools DISABLED for this arm (identical in both arms; set ROTMOE_AB_TOOLS=1 to re-enable)"
else
  note "tools ENABLED -- this is NOT the pre-registered configuration"
fi

# --- a sandbox OUTSIDE the repository ----------------------------------------
# Measured 2026-08-04 on the earlier harness: a turn asked to "compress the
# docstring" DID IT, editing the tree that was being measured. A benchmark that
# can write to its own subject is not a benchmark.
SANDBOX="${ROTMOE_AB_CWD:-$CORPUS/cwd}"
mkdir -p "$SANDBOX" || { echo "REFUSE: cannot create sandbox"; exit 2; }
case "$(cd "$SANDBOX" && pwd)" in
  "$REPO"|"$REPO"/*) echo "REFUSE: sandbox resolves inside the repository"; exit 2 ;;
esac

# --- ARM PRECONDITIONS, verified against something the harness did NOT create -
# RotObserve section 10 is the rule here: a detector satisfied by an artifact
# the setup produces is a constant. So arm A is verified by the plugin REGISTRY
# and the cached manifest, and confirmed afterwards by route records appearing
# in the debug log -- evidence the router actually ran, not that we asked it to.
armed_version () {
  node -e '
    try{
      const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      const e=(j.plugins||{})["rot-moe@rot-moe"]||[];
      console.log(e.length? e[0].version : "");
    }catch(err){ console.log(""); }
  ' "$REGISTRY" 2>/dev/null
}
armed_timeout () {
  local v="$1"
  node -e '
    try{
      const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      const hs=Object.values(j.hooks||{}).flat().flatMap(g=>g.hooks||[]);
      const t=[...new Set(hs.map(h=>h.timeout))];
      console.log(t.length===1 && typeof t[0]==="number" ? t[0] : 0);
    }catch(err){ console.log(0); }
  ' "$CTT/plugins/cache/rot-moe/rot-moe/$v/hooks/hooks.json" 2>/dev/null
}

RESTORE_REGISTRY=0
if [ "$ARM" = "a" ]; then
  V="$(armed_version)"
  [ -n "$V" ] || { echo "REFUSE: arm A needs the plugin installed in CTT; the registry lists none"; exit 2; }
  T="$(armed_timeout "$V")"; T=${T:-0}
  if [ "$T" -le 30 ]; then
    echo "REFUSE: the installed plugin ($V) declares timeout=${T}s."
    echo "        At or below the 30s platform default the router is KILLED mid-turn,"
    echo "        and RotObserve.silenced_is_indistinguishable_from_absent proves that"
    echo "        observation EQUALS arm B. Arm A would silently be a second arm B."
    exit 2
  fi
  ok "arm A: plugin $V installed, hook bound with timeout=${T}s (> 30s default)"
else
  # ARM B: DISARM WITH THE PRODUCT'S OWN MECHANISM.
  #
  # The first attempt emptied `plugins/installed_plugins.json` and looked
  # convincing. It disarmed NOTHING: the run produced 39 route records and the
  # negative control below caught it, which is the only reason those 15 turns
  # were discarded instead of published as "unrouted".
  #
  # The actual switch is `enabledPlugins` in settings.json, and the CLI exposes
  # it as `claude plugin disable`. Using the product's own command rather than
  # editing state by hand is also the honest disarm: it is what a user does.
  if node -e '
      const fs=require("fs"), p=process.argv[1];
      try{ const s=JSON.parse(fs.readFileSync(p,"utf8").replace(/^﻿/,""));
           process.exit((s.enabledPlugins||{})["rot-moe@rot-moe"]===true?0:1); }
      catch(e){ process.exit(1); }
    ' "$CTT/settings.json"; then
    claude plugin disable rot-moe@rot-moe >/dev/null 2>&1
    RESTORE_REGISTRY=1
    still=$(node -e '
      const fs=require("fs");
      try{ const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8").replace(/^﻿/,""));
           console.log((s.enabledPlugins||{})["rot-moe@rot-moe"]===true?"yes":"no"); }
      catch(e){ console.log("unknown"); }
    ' "$CTT/settings.json")
    if [ "$still" = "no" ]; then
      ok "arm B: plugin DISABLED via the CLI (enabledPlugins now false/absent; re-enabled on exit)"
    else
      echo "REFUSE: 'claude plugin disable' did not clear enabledPlugins (still: $still)."
      echo "        Running now would collect a second arm A wearing arm B's label."
      exit 2
    fi
  else
    note "arm B: plugin already disabled in settings.json, nothing to do"
  fi
fi
restore_registry () {
  if [ "$RESTORE_REGISTRY" = "1" ]; then
    claude plugin enable rot-moe@rot-moe >/dev/null 2>&1
    printf '  ----  plugin re-enabled (arm B cleanup)\n'
  fi
}
trap restore_registry EXIT INT TERM

# --- the turns ---------------------------------------------------------------
SIDF="$CORPUS/arm$ARM.sid"
SID=""
[ -f "$SIDF" ] && SID=$(cat "$SIDF" 2>/dev/null)

_before=$(grep -c '"kind":"route"' "$LOG" 2>/dev/null); : "${_before:=0}"
ran=0; failed=0; wrote=0
n="$FROM"
while [ "$n" -le "$TO" ]; do
  txt="$(sed -n "${n}p" "$PROMPTS") Answer in one or two sentences."
  dest="$OUT/turn-$(printf '%03d' "$n").json"
  start=$(date +%s)
  if [ -z "$SID" ]; then
    timeout "$TURN_TIMEOUT" claude -p "$txt" $NOTOOLS --output-format json > "$dest" 2>/dev/null
  else
    timeout "$TURN_TIMEOUT" claude -p "$txt" $NOTOOLS --resume "$SID" --output-format json > "$dest" 2>/dev/null
  fi
  rc=$?
  end=$(date +%s)
  ran=$((ran+1))
  if [ "$rc" -ne 0 ]; then
    failed=$((failed+1))
    why=$(node -e 'try{const j=require(process.argv[1]);const r=String(j.result||j.error||"").replace(/\s+/g," ").trim();console.log(r?r.slice(0,110):"(no reason in payload)")}catch(e){console.log("(no JSON payload)")}' "$dest" 2>/dev/null)
    note "turn $n: exit $rc after $((end-start))s -- ${why:-unknown}"
  else
    wrote=$((wrote+1))
    newsid=$(node -e 'try{const j=require(process.argv[1]);console.log(j.session_id||"")}catch(e){console.log("")}' "$dest" 2>/dev/null)
    [ -n "$newsid" ] && { SID="$newsid"; printf '%s' "$SID" > "$SIDF"; }
    note "turn $n: ok in $((end-start))s"
  fi
  n=$((n+1))
done

_after=$(grep -c '"kind":"route"' "$LOG" 2>/dev/null); : "${_after:=0}"
_new=$((_after - _before))

# --- THE JOIN: attribute records to THIS RUN, not to the file ----------------
# The delta above is a DIAGNOSTIC only. It must never decide the arm, because a
# global count over a shared, rotating log is unsound in both directions and
# Proofs/RotAbJoin.lean proves it:
#
#   delta_false_alarms_on_foreign_traffic  -- nine checkers and any concurrent
#       session append to this same log with src=test. Their records inflate
#       $_new and condemn an arm that emitted nothing.
#   delta_false_passes_under_rotation      -- the log rotates at
#       ROTMOE_DEBUG_LOG_MAX. If rotation drops as many old records as arm B
#       wrote, $_new is 0 and a fully ARMED run is reported clean. That is a
#       quiet green over a real failure, which is the worse direction.
#
# Every record has carried "session" since the observability subsystem landed,
# and the harness already knows this run's id ($SID, captured at :279). So join
# on it: sessionRouteCount, exactly as the module defines it.
_sid_now=""
[ -f "$SIDF" ] && _sid_now=$(cat "$SIDF" 2>/dev/null)
if [ -z "$_sid_now" ]; then
  # No id means the join is impossible. REFUSE rather than fall back to the
  # delta -- a silent fallback to an unsound check is how the defect returns.
  bad "no session id for arm $ARM -- cannot attribute records to this run; refusing to judge the arm on a global delta"
  _joined=-1
else
  _joined=$(grep '"kind":"route"' "$LOG" 2>/dev/null | grep -c "\"session\":\"$_sid_now\"")
  : "${_joined:=0}"
fi
note "ran $ran turn(s), $failed failed, $wrote stored; route records THIS SESSION: $_joined (global delta, diagnostic only: $_new)"

# --- VERDICT: the arm must have been what it claims to be --------------------
if [ "$wrote" -eq 0 ]; then
  bad "not one turn was stored -- a collection pass that collected nothing is not a success"
else
  ok "$wrote turn(s) stored in $OUT"
fi

if [ "$_joined" -lt 0 ]; then
  note "arm verdict SKIPPED: no session id, and the global delta is not allowed to stand in for it"
elif [ "$ARM" = "a" ]; then
  if [ "$_joined" -gt 0 ]; then
    ok "arm A was ROUTED: $_joined route record(s) carrying this session's id"
  else
    bad "arm A produced NO route records for session $_sid_now -- the router did not run, so these turns are arm B and must be discarded"
  fi
else
  if [ "$_joined" -eq 0 ]; then
    ok "arm B was UNROUTED: zero route records carrying this session's id, as required"
  else
    bad "arm B produced $_joined route record(s) for session $_sid_now -- the plugin was still armed and the arm is invalid"
  fi
fi

# Disagreement between the two is not an error -- it is the whole point, and it
# is worth SAYING when it happens so the next reader sees the join earning its
# keep rather than duplicating the delta.
if [ "$_joined" -ge 0 ] && [ "$_joined" -ne "$_new" ]; then
  note "join and delta DISAGREE ($_joined vs $_new) -- foreign traffic or rotation moved the file during this run; the join is the one that decided"
fi

echo
echo "== A/B arm $ARM: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
