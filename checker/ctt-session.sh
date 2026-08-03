#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# CTT SESSION -- the installed plugin, a REAL conversation, about REAL CODE
#
# WHAT THIS MEASURES THAT THE OTHER SESSION GATES DO NOT.
#
# `release-longsession.sh` clones auth into a scratch config, installs an
# archive, and holds a conversation of generic lane-drill prompts. That proves
# the hook survives a long session. It does not prove the router behaves on the
# kind of prompt this plugin actually meets: questions about a real repository,
# with real file paths, real theorem names and real build commands in them.
#
# This runs against the CLAUDE TEST TERMINAL (CTT) -- a separate, real Claude
# config with the plugin installed from a published archive -- and every prompt
# is about code in this repository. The numbers it produces are the ones the
# README's benchmark section is allowed to quote.
#
# RESUMABLE BY DESIGN. A session of 80 turns exceeds any single wall-clock
# budget worth holding a shell open for, so the runner takes a turn RANGE and
# appends to one JSONL. Four calls of 20 turns produce exactly the same corpus
# as one call of 80, and the analysis reads the file, not the run.
#
#   ROTMOE_CTT_FROM=1  ROTMOE_CTT_TO=20 bash checker/ctt-session.sh
#   ROTMOE_CTT_FROM=21 ROTMOE_CTT_TO=40 bash checker/ctt-session.sh
#   ...
#   bash checker/ctt-session.sh --report        # analyse what was collected
#
# Exit: 0 pass, 1 fail, 2 refuse, 3 skip (never a pass).
# =============================================================================
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

CTT="${ROTMOE_CTT_DIR:-C:/Users/Saimono/Claude_Test/.claude}"
# WRITING and READING have different defaults on purpose.
#
# A run APPENDS to a scratch log. `--report` READS the corpus this repository
# committed as the evidence behind the benchmark numbers in README.md, so anyone
# -- including CI, which has no claude CLI and can never hold a session -- can
# re-derive those numbers from the artifact instead of trusting the prose.
# Setting ROTMOE_CTT_LOG overrides both, which is how a fresh corpus is analysed
# before it is committed.
CORPUS_DEFAULT="$REPO/bench/ctt-session-0.6.1.jsonl"
LOG="${ROTMOE_CTT_LOG:-D:/tmp/ctt-session.jsonl}"
REPORT_LOG="${ROTMOE_CTT_LOG:-$CORPUS_DEFAULT}"
SIDF="${ROTMOE_CTT_SID:-D:/tmp/ctt-session.sid}"
TURN_TIMEOUT="${ROTMOE_TURN_TIMEOUT:-120}"

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }
note() { printf '  ----  %s\n' "$*"; }

# --- the conversation: REAL work on THIS repository --------------------------
# Every prompt names something that exists on disk. The lane each is expected to
# reach is a consequence of the words a person would really use for that task,
# not a keyword drill -- which is the whole point of measuring here.
turn_text () {
  case "$1" in
    1)  echo "In this repo, what does hooks/rot-router.sh compute for each lens? One line." ;;
    2)  echo "lake build Proofs.RotAbility is green -- what does every_ability_effect_holds actually prove?" ;;
    3)  echo "debug why checker/profile-bind.sh would fail if engine/rot-lean.md changed a lambda" ;;
    4)  echo "audit lean/mutate/mutate_rotability.sh for a mutant that could silently not apply" ;;
    5)  echo "plan which theorem in RotGauge.lean to generalize next, and prioritize it" ;;
    6)  echo "compress the docstring of RotAbility.lean to fewer tokens without losing meaning" ;;
    7)  echo "forecast what breaks first if we add a tenth lens to the roster" ;;
    8)  echo "invent a surreal analogy for what the sigmoid does to divergence" ;;
    9)  echo "decide now: should predictiveLam live in RotAbility or its own module? Conclude." ;;
    10) echo "refactor the meta architecture: should abilityEffect be a typeclass? Evolve it." ;;
    11) echo "I feel worn out by this refactor, it has been a long day on these proofs" ;;
    12) echo "fix the sorry -- is there any sorry left in lean/Proofs, and how would you check?" ;;
    13) echo "Recall: what was the first thing I asked you about in this session?" ;;
    14) echo "Name one file we have discussed earlier in this conversation." ;;
    15) echo "run checker/gate-all.sh --fast mentally: which gate catches a stale theorem count?" ;;
    16) echo "security review: does hooks/rot-router.sh ever execute data from the prompt?" ;;
    17) echo "what is the R/s+ formula's K on this head, and why does it matter" ;;
    18) echo "distill the CHANGELOG 0.6.0 entry into three bullets, byte-efficient" ;;
    19) echo "predict the next regression this repo will hit, based on its history" ;;
    20) echo "declare the release decision for 0.6.x -- ship or hold, and why" ;;
    # Past 20, cycle the real-work prompts rather than emitting filler. A
    # constant tail prompt carries no stems and would route CONVERGENT forever,
    # which measures nothing about the table deep into a session.
    *)  _c=$(( ($1 - 21) % 20 + 1 )); turn_text "$_c" ;;
  esac
}

MARKER="MoE :: TIER"

# =============================================================================
# --report : analyse the collected corpus. Reads the JSONL, never the run.
# =============================================================================
if [ "${1:-}" = "--report" ]; then
  LOG="$REPORT_LOG"
  [ -f "$LOG" ] || { echo "REFUSE: no corpus at $LOG -- run some turns first"; exit 2; }
  turns=$(grep -c '"kind":"route"' "$LOG"); turns=${turns:-0}
  gauges=$(grep -c '"kind":"gauge"' "$LOG"); gauges=${gauges:-0}
  if [ "$turns" -lt 1 ]; then
    echo "REFUSE: corpus at $LOG has ZERO route records -- nothing to report."
    echo "        A report over an empty corpus would pass vacuously."
    exit 2
  fi
  echo "== CTT session report =="
  note "corpus: $LOG"
  note "router firings: $turns route records, $gauges gauge records"

  # every gauge must carry K=9 and nine lens terms -- the ninth lens present in
  # a REAL session, not just in a unit test
  badk=$(grep '"kind":"gauge"' "$LOG" | grep -vc '"K":9'); badk=${badk:-0}
  if [ "$badk" -eq 0 ]; then ok "every gauge record reports K=9 ($gauges records)"
  else bad "$badk gauge record(s) do NOT report K=9"; fi

  nine=$(node -e '
    const fs=require("fs");
    const lines=fs.readFileSync(process.argv[1],"utf8").split("\n").filter(l=>l.includes("\"kind\":\"gauge\""));
    let bad=0;
    for(const l of lines){ try{ const j=JSON.parse(l); if(!Array.isArray(j.lenses)||j.lenses.length!==9) bad++; }catch(e){ bad++; } }
    console.log(bad);' "$LOG" 2>/dev/null)
  nine=${nine:-1}
  if [ "$nine" = "0" ]; then ok "every gauge record carries exactly nine lens terms"
  else bad "$nine gauge record(s) do not carry nine lens terms"; fi

  # R/s+ must be RECOMPUTABLE from the logged per-lens terms
  rec=$(node -e '
    const fs=require("fs");
    const lines=fs.readFileSync(process.argv[1],"utf8").split("\n").filter(l=>l.includes("\"kind\":\"gauge\""));
    let okc=0, badc=0;
    for(const l of lines){
      try{
        const j=JSON.parse(l);
        const sum=j.lenses.reduce((a,x)=>a+Number(x.term),0);
        const rs=sum/Number(j.K);
        if(Math.abs(rs-Number(j.Rs))<=0.00002) okc++; else badc++;
      }catch(e){ badc++; }
    }
    console.log(okc+" "+badc);' "$LOG" 2>/dev/null)
  rok=${rec%% *}; rbad=${rec##* }
  if [ "${rbad:-1}" = "0" ] && [ "${rok:-0}" -gt 0 ]; then
    ok "R/s+ recomputes from the logged terms on all $rok gauge records (sum/K, tol 2e-5)"
  else
    bad "R/s+ recompute: $rok agreed, $rbad DISAGREED"
  fi

  # lane coverage
  echo "  ---- lanes reached:"
  grep '"kind":"route"' "$LOG" | sed -n 's/.*"lane":"\([A-Z]*\)".*/\1/p' | sort | uniq -c \
    | while read -r n lane; do printf '        %-12s %s\n' "$lane" "$n"; done
  lanes=$(grep '"kind":"route"' "$LOG" | sed -n 's/.*"lane":"\([A-Z]*\)".*/\1/p' | sort -u | grep -c .)
  if [ "${lanes:-0}" -ge 5 ]; then ok "$lanes distinct lanes reached in real conversation"
  else bad "only ${lanes:-0} distinct lane(s) reached -- the table is not being exercised"; fi

  echo
  echo "== CTT session: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ] || exit 1
  exit 0
fi

# =============================================================================
# run a range of turns
# =============================================================================
command -v claude >/dev/null 2>&1 || { echo "SKIP: the claude CLI is not on PATH"; exit 3; }
[ -d "$CTT" ] || { echo "SKIP: no CTT config at $CTT"; exit 3; }

FROM="${ROTMOE_CTT_FROM:-1}"
TO="${ROTMOE_CTT_TO:-20}"

# The plugin must actually be installed in CTT, or this measures nothing.
INSTALLED=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$CTT/plugins/installed_plugins.json" 2>/dev/null | head -1)
[ -n "$INSTALLED" ] || { echo "REFUSE: no plugin version readable from CTT registry"; exit 2; }
note "CTT plugin version: $INSTALLED"
note "turns $FROM..$TO, timeout ${TURN_TIMEOUT}s each"
note "corpus: $LOG"

export CLAUDE_CONFIG_DIR="$CTT"
export ROTMOE_DEBUG_LOG="$LOG"

# THE SESSION MUST NOT RUN INSIDE THIS REPOSITORY. Measured 2026-08-04, the hard
# way: the first full 80-turn run was launched with the repo as cwd, and turn 6
# ("compress the docstring of RotAbility.lean") did precisely what it was asked
# -- it EDITED lean/Proofs/RotAbility.lean, rewrote the module docstring and
# added two unreviewed theorems. The count went 205 -> 207 and repo-complete
# caught it, which is the only reason it was noticed at all.
#
# A benchmark that mutates the tree it is benchmarking is not a measurement, it
# is an uncontrolled edit wearing a measurement's clothes. The prompts still
# NAME real files -- that is what makes the routing realistic -- but they are
# asked from a scratch directory where there is nothing to damage. What is being
# measured is which lane the router picks and what R/s+ it computes; neither
# depends on the model being able to write.
SANDBOX="${ROTMOE_CTT_CWD:-${TMPDIR:-/tmp}/ctt-session-cwd}"
mkdir -p "$SANDBOX" || { echo "REFUSE: cannot create session sandbox $SANDBOX"; exit 2; }
case "$(cd "$SANDBOX" && pwd)" in
  "$REPO"|"$REPO"/*)
    echo "REFUSE: the session sandbox resolves INSIDE the repository ($SANDBOX)."
    echo "        A benchmark that can edit the tree it measures is not a benchmark."
    exit 2 ;;
esac
cd "$SANDBOX" || { echo "REFUSE: cannot enter session sandbox"; exit 2; }
note "session cwd: $SANDBOX (outside the repo -- turns cannot edit it)"

n="$FROM"
fired=0; ran=0
SID=""
[ -f "$SIDF" ] && SID=$(cat "$SIDF" 2>/dev/null)

while [ "$n" -le "$TO" ]; do
  # BREVITY SUFFIX, and why it does not weaken the measurement.
  #
  # Measured 2026-08-04: unconstrained real-code turns on this repo ran 15-100 s
  # each, because the model genuinely opens files. Eighty of those is two hours
  # of wall clock and most turns time out mid-write, producing an unparsable
  # transcript and NO data.
  #
  # What this harness measures is the ROUTER -- which lane fired, what R/s+ it
  # computed, whether K=9 and whether the gauge recomputes from its own logged
  # terms. None of that depends on how long the answer is. The prompt still
  # names real files and real theorems, the router still sees the real text, and
  # the hook still runs in a real CTT session. Only the answer is short.
  txt="$(turn_text "$n") Answer in one or two sentences."
  out="${TMPDIR:-/tmp}/ctt_t$n.json"
  if [ -z "$SID" ]; then
    timeout "$TURN_TIMEOUT" claude -p "$txt" --output-format json > "$out" 2>/dev/null
  else
    timeout "$TURN_TIMEOUT" claude -p "$txt" --resume "$SID" --output-format json > "$out" 2>/dev/null
  fi
  rc=$?
  ran=$((ran+1))
  if [ "$rc" -ne 0 ]; then
    note "turn $n: claude exit $rc (timeout or error) -- recorded, not hidden"
  else
    newsid=$(node -e 'try{const j=require(process.argv[1]);console.log(j.session_id||"")}catch(e){console.log("")}' "$out" 2>/dev/null)
    [ -n "$newsid" ] && { SID="$newsid"; printf '%s' "$SID" > "$SIDF"; }
    if grep -Fq "$MARKER" "$out" 2>/dev/null; then fired=$((fired+1)); fi
  fi
  n=$((n+1))
done

note "ran $ran turn(s); marker seen in $fired transcript(s)"
note "run --report when the full range is collected"
exit 0
