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
bad () { printf '  FAIL  %s\n' "$*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=ctt-session::%s\n' "$*"; FAIL=$((FAIL+1)); }
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

  # --- ATTRIBUTION ----------------------------------------------------------
  # Pooling runs from different plugin builds can report a leading lane that led
  # NEITHER build -- exhibited in Proofs/RotCorpus.lean:pooling_invents_a_leader.
  # So a report must say which build it is talking about, and refuse when it
  # cannot know. Attribution is the nearest PRECEDING marker
  # (Proofs/RotCorpus.lean:assign), which is what awk reproduces here.
  vers=$(grep '"kind":"version"' "$LOG" | sed -n 's/.*"ver":"\([^"]*\)".*/\1/p' | sort -u)
  nvers=$(printf '%s\n' "$vers" | grep -c .)
  pre=$(awk '/"kind":"version"/{seen=1} /"kind":"route"/{ if (!seen) n++ } END{print n+0}' "$LOG")

  # A CORPUS MAY CARRY ITS VERSION IN ITS NAME, and that is not a defect.
  # The committed benchmark is bench/ctt-session-0.6.1.jsonl: one file, one
  # build, the version in the filename. An in-file marker check written as an
  # absolute requirement FAILS that file -- and the tempting repair, deleting
  # the check, throws away the coverage. So: prefer the marker, accept a
  # filename that names exactly one version, refuse only when NEITHER exists.
  # The distinction is reported, because the two are not equally strong: a
  # marker is written per run and survives concatenation, a filename does not.
  namever=$(basename "$LOG" | sed -n 's/^ctt-session-\([0-9][0-9.]*\)\.jsonl$/\1/p')
  if [ "${nvers:-0}" -eq 0 ] && [ -n "$namever" ]; then
    ok "corpus is attributed by FILENAME to $namever (no in-file marker; weaker, but unambiguous)"
    note "  attributed to $namever: $turns firing(s)"
    note "  a marker survives concatenation and a filename does not -- new corpora carry markers"
  elif [ "${nvers:-0}" -eq 0 ]; then
    bad "corpus carries NO version marker and its name encodes no version -- all $turns firings are unattributable"
    echo "        Proofs/RotCorpus.lean:no_marker_attributes_nothing states exactly this."
    echo "        Re-collect with a build of the harness that writes the marker."
  else
    ok "corpus carries $nvers version marker value(s): $(printf '%s ' $vers)"
    if [ "${pre:-0}" -gt 0 ]; then
      bad "$pre firing(s) precede the first marker -- those are unattributable and are NOT counted"
    else
      ok "every firing follows a marker (marker_first_attributes_all)"
    fi
    # per-version counts, so a pooled number is never the headline
    for v in $vers; do
      c=$(awk -v want="$v" '
        /"kind":"version"/ { if (match($0, /"ver":"[^"]*"/)) { cur=substr($0,RSTART+7,RLENGTH-8) } }
        /"kind":"route"/   { if (cur == want) n++ }
        END { print n+0 }' "$LOG")
      note "  attributed to $v: $c firing(s)"
    done
    if [ "${nvers:-0}" -gt 1 ]; then
      bad "this corpus MIXES $nvers builds -- a single pooled figure over it is not a measurement of any one of them"
      echo "        Report per-version, or re-collect against one build."
    fi
  fi

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

# --- VERSION MARKER ---------------------------------------------------------
# The router hook writes each route record, and the hook does not know which
# plugin build it is running inside -- so a record carries no version. Measured
# 2026-08-08: the corpus held 120 records, 60 from 0.9.2 and 60 from 1.0.1, and
# nothing in the file told them apart, while this file's own header calls these
# "the numbers the README's benchmark section is allowed to quote".
#
# Why a marker and not a post-hoc annotation: attribution is a left fold that
# carries the announced version forward, so appending a run cannot disturb the
# runs already collected. That is Proofs/RotCorpus.lean:
#   appending_preserves_earlier   -- four calls of 20 == one call of 80
#   marker_first_attributes_all   -- a marked corpus attributes every firing
#   no_marker_attributes_nothing  -- an unmarked one attributes none of them
#   pooling_invents_a_leader      -- and pooling two runs can name a leading
#                                    lane that led NEITHER of them
mkdir -p "$(dirname "$LOG")"
printf '{"kind":"version","ts":"%s","ver":"%s","from":%s,"to":%s}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$INSTALLED" "$FROM" "$TO" >> "$LOG"
_mk=$(grep -c '"kind":"version"' "$LOG")
[ "${_mk:-0}" -ge 1 ] \
  || { echo "REFUSE: version marker was not written to $LOG -- this run would be unattributable"; exit 2; }
note "version marker written: this run's firings attribute to $INSTALLED"

export CLAUDE_CONFIG_DIR="$CTT"
export ROTMOE_DEBUG_LOG="$LOG"

# MIRROR THE `CTT` LAUNCHER, because a harness that does not is testing
# something else and calling it CTT.
#
# The maintainer's PowerShell profile defines `function CTT` and it does three
# things this script was doing only one of. Both gaps were measured, not guessed:
#
# 1. IT RE-COPIES THE CREDENTIAL ON EVERY LAUNCH. Its own comment says why:
#    "Credentials are a SNAPSHOT and the live ones refresh, so a cloned copy goes
#    stale and the session dies on 'OAuth session expired'". This script assumed
#    the file was current, so it inherited whatever the last launch left behind
#    -- measured 2026-08-06 as a 281-byte stub with expiresAt 0, and twenty
#    turns died on it.
#
#    A SYMLINK IS THE WRONG FIX and was reverted after being tried. The profile
#    is explicit: "NOT symlinked, unlike GGF... CTT exists precisely so a
#    /plugin install cannot contaminate the real one", and the copy is described
#    as "a one-way read of the live file; nothing in the test tree is ever
#    written back". Claude Code REWRITES .credentials.json when it refreshes a
#    token, so a symlink would let a test session write the live credential --
#    breaking exactly the one-way property the isolation depends on.
#
# 2. IT CLEARS THE PROXY ENV. Measured in this shell: ANTHROPIC_BASE_URL held a
#    populated loopback endpoint, so every "CTT" turn this harness ran went
#    through a local proxy instead of the isolated path the launcher creates.
#    The turns were real; the ENVIRONMENT was not the one being certified.
#
#    ONE MACHINE'S VARIABLE NAMES DO NOT BELONG IN A SHIPPED CHECKER, and this
#    repository enforces that: `checker/patterns-forbidden.txt` lists the
#    maintainer's private env flag, and the first draft of this block hardcoded
#    it -- the `no machine-local paths` gate refused the commit, correctly.
#    Generic names are cleared below; anything site-specific is named by the
#    operator through ROTMOE_CTT_UNSET (a space-separated list), so fidelity to
#    a particular launcher is configuration rather than something baked into an
#    artifact every user downloads.
_live_cred="$HOME/.claude/.credentials.json"
if [ -f "$_live_cred" ]; then
  cp "$_live_cred" "$CTT/.credentials.json" 2>/dev/null \
    && note "credential refreshed from the live file (one-way read, as the CTT launcher does)"
else
  note "no live credential to refresh from -- turns will report their own reason"
fi
unset ANTHROPIC_BASE_URL ROLLING_CONTEXT_PORT ROLLING_CONTEXT_UPSTREAM \
      ROLLING_CONTEXT_TRIGGER ROLLING_CONTEXT_TARGET
_extra=0
for _v in ${ROTMOE_CTT_UNSET:-}; do unset "$_v"; _extra=$((_extra+1)); done
note "proxy env cleared -- the session does not go through a local proxy ($_extra site-specific var(s) also cleared)"

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

# RECORDS BEFORE THE RUN. A collection pass that collects NOTHING must not be
# able to exit 0 -- see the refusal at the end of this file for why.
_before=$(grep -c '"kind":"route"' "$LOG" 2>/dev/null)
: "${_before:=0}"

n="$FROM"
fired=0; ran=0; failed=0
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
    failed=$((failed+1))
    # THE CLI WRITES THE REASON INTO THE JSON EVEN WHEN IT EXITS NON-ZERO, and
    # this line used to throw it away. Measured 2026-08-06: twenty consecutive
    # turns reported nothing but "exit 1 (timeout or error)", and the actual
    # cause -- `Not logged in - Please run /login` -- was sitting in `.result`
    # of every one of them. Twenty mute failures cost a diagnosis that the
    # first turn already had. A failure that does not say WHY is a failure you
    # will misattribute.
    why=$(node -e 'try{const j=require(process.argv[1]);const r=String(j.result||j.error||"").replace(/\s+/g," ").trim();console.log(r?r.slice(0,120):"(no reason in the payload)")}catch(e){console.log("(no JSON payload -- the turn produced nothing)")}' "$out" 2>/dev/null)
    note "turn $n: claude exit $rc -- ${why:-(no reason available)}"
  else
    newsid=$(node -e 'try{const j=require(process.argv[1]);console.log(j.session_id||"")}catch(e){console.log("")}' "$out" 2>/dev/null)
    [ -n "$newsid" ] && { SID="$newsid"; printf '%s' "$SID" > "$SIDF"; }
    if grep -Fq "$MARKER" "$out" 2>/dev/null; then fired=$((fired+1)); fi
  fi
  n=$((n+1))
done

_after=$(grep -c '"kind":"route"' "$LOG" 2>/dev/null)
: "${_after:=0}"
_new=$((_after - _before))

note "ran $ran turn(s), $failed failed; route records written this run: $_new (corpus: $_after)"

# THE MARKER COUNT IS NOT A FIRING COUNT, and reporting it bare invited exactly
# the wrong inference -- measured 2026-08-06, when `marker seen in 0
# transcript(s)` printed in all four chunks of a run whose debug log held 39
# route and 39 gauge records.
#
# The router injects its lane as CONTEXT and the internal-only seal forbids the
# model from printing it, so zero is the CORRECT value and any other number is a
# leak. `Proofs/RotObserve.lean` proves both halves:
#   markers_zero_iff_all_sealed          -- 0 markers <-> every turn stayed sealed
#   any_number_of_firings_can_be_invisible -- for EVERY n, n firings can show 0
# so this line reports the seal, never the router.
if [ "$fired" -eq 0 ]; then
  note "trace leaks: 0 -- the internal-only seal held on all $ran turn(s) (0 is the PASS value here)"
else
  note "trace leaks: $fired transcript(s) printed the marker -- the seal LEAKED, investigate"
fi

# --- REFUSAL: a collection pass that collected nothing is not a success -------
# Measured 2026-08-06: the CTT credential had expired (`loggedIn: false`), and
# every turn would have returned exit 1 with not one record written. This script
# ended in an unconditional `exit 0`, so that run would have reported success
# while measuring NOTHING -- the same defect this suite exists to catch, living
# in the suite itself.
#
# `--report` already refuses an empty corpus, but that is a LATER, SEPARATE
# invocation. A scheduled collection step that never reaches it would have been
# green forever.
# --- REFUSAL: EVERY TURN FAILED -------------------------------------------
# THIS IS THE HOLE THE REFUSAL BELOW DID NOT COVER, and it was live.
#
# Measured 2026-08-06: the CTT credential had gone stale (`expiresAt: 0`), all
# TWENTY turns returned `Not logged in - Please run /login`, and this script
# exited **0**. The refusal below asks "were any route records written?" -- and
# twenty were, because the router hook fires on prompt submission, BEFORE the
# turn reaches the API and dies. The evidence counter increments in the FAILURE
# PATH, so a pass condition resting on it is satisfied by total failure.
#
# That is the same defect class this suite exists to catch, living in the suite
# itself, and it is proved rather than described in `Proofs/RotObserve.lean` §9:
#   side_effect_verdict_cannot_see_total_failure -- a verdict reading only the
#     side effect is IDENTICAL whether every turn succeeded or every turn failed
#   success_aware_verdict_detects_total_failure  -- and one that reads outcomes
#     does detect it
#
# A session suite in which no session happened has measured nothing. It does not
# matter how many records the hook managed to write on the way down.
if [ "$ran" -gt 0 ] && [ "$failed" -eq "$ran" ]; then
  echo "REFUSE: every one of $ran turn(s) FAILED."
  echo "        $_new route record(s) were still written -- the hook fires when the"
  echo "        prompt is submitted, so records prove the hook ran, NOT that the"
  echo "        session worked. This is not a pass."
  echo "        The per-turn lines above now carry the CLI's own reason; read the"
  echo "        first one. A stale CTT credential reports:"
  echo "          Not logged in - Please run /login"
  echo "        Refresh it by cloning the live credential into the CTT config dir,"
  echo "        which is what checker/marketplace-session.sh already does."
  exit 2
fi

if [ "$ran" -gt 0 ] && [ "$_new" -eq 0 ]; then
  echo "REFUSE: $ran turn(s) ran and NOT ONE route record was written."
  echo "        The session produced no measurement, so this is not a pass."
  echo "        $failed of $ran turn(s) exited non-zero."
  echo "        Most likely: the CTT credential expired. Check with"
  echo "          CLAUDE_CONFIG_DIR=\"\$CTT\" claude auth status"
  echo "        A collection run that collects nothing must never exit 0."
  exit 2
fi

note "run --report when the full range is collected"
exit 0
