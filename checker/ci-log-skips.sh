#!/usr/bin/env bash
# ci-log-skips.sh -- count the checkers whose SUBSTANCE did not run in CI, and
# refuse any that nobody declared.
#
# WHY THIS EXISTS, AND WHY ci-honesty.sh IS NOT ENOUGH.
# checker/ci-honesty.sh reads every step's CONCLUSION. On run 31308026819 it
# passed 8/0 with five working negative controls, and that result stands. But a
# step can print "SKIP: no credentials" and still conclude success, and a
# conclusion audit cannot see the difference -- proved, not asserted:
# RotCiSkip.conclusion_audit_is_blind_to_a_skip shows two runs that are both
# entirely successful and differ only in whether a step skipped.
#
# Measured on that run's log.zip (721 KB, 4 jobs): 45 runtime skip lines inside
# green steps, across 7 checkers. Every one is honestly labelled -- the logs say
# "a SKIP is never a pass", exit 3 or 4 -- and the run carried ZERO real
# ::error and ZERO real ::warning annotations. So this is not a fake green. It
# is an UNCOUNTED COVERAGE GAP, and an uncounted gap grows for free: add one
# more environment-gated skip tomorrow and nothing goes red.
#
# THE BUDGET IS THE THING TO REVIEW, NOT THE VERDICT.
# RotCiSkip.a_budget_containing_everything_disarms_the_ratchet is a theorem: a
# budget extended to cover the whole run reports green while checking nothing.
# So every entry below carries the reason a public runner cannot host it, and
# RotCiSkip.ratchet_weakens_as_the_budget_grows says adding an entry SPENDS
# coverage rather than gaining it. Adding a line here is a decision, not a fix.
#
# USAGE
#   bash checker/ci-log-skips.sh [RUN_ID]     judge a run (downloads its logs)
#   CI_LOG_DIR=<dir> bash checker/ci-log-skips.sh    judge an extracted log dir
#
# EXITS  0 pass | 1 an undeclared skipping step | 2 usage/tooling | 3 SKIP (never a pass)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

pass=0; fail=0
ok  () { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
bad () { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }

# -----------------------------------------------------------------------------
# THE DECLARED BUDGET. One line per checker whose substance a public runner
# genuinely cannot exercise, with the reason. Measured from run 31308026819.
declared_reason () {
  case "$1" in
    checker/preflight.sh)           printf '%s' "optional local tooling is absent on a runner" ;;
    checker/remind-measure.sh)      printf '%s' "needs credentials; a runner has none" ;;
    checker/verdict-schedule-sim.sh) printf '%s' "[week2] phases are schedule-gated by design" ;;
    checker/ab-analyze.sh)          printf '%s' "raw A/B transcripts are deliberately not committed" ;;
    checker/portability.sh)         printf '%s' "drive-letter paths do not exist on POSIX runners" ;;
    checker/marketplace-session.sh) printf '%s' "needs the claude CLI and credentials" ;;
    checker/bench-router.sh)        printf '%s' "its measurement phase is credential-gated" ;;
    # TWO INLINE MULTI-CHECKER BLOCKS. GitHub labels a log group with the run
    # block's FIRST LINE, not the step's name, so these are the only keys the
    # log offers. Both skips were read before being declared, and both are real
    # environment limits -- not convenience:
    #   the LOAD-BEARING block: "SKIP: the raw A/B transcripts are not on this
    #     machine (D:/Temp/rotmoe-ab)" and "SKIPPED BY DESIGN ... (exit 3)"
    #   the `set +e` block: "SKIP (3): no credentials on the runner -- never
    #     counted as a pass", context delivery UNVERIFIED, no auth to clone
    # LIMITATION, STATED NOT HIDDEN: these keys are coarse. `Run set +e` would
    # also match a future step whose block happens to start that way, and that
    # step's skip would be admitted without anyone deciding. The real fix is to
    # split both blocks into one named step per checker so every skip is
    # attributable to exactly one; that touches `|| rc=$?` error handling the
    # workflow calls load-bearing, so it is a deliberate follow-up, not a
    # drive-by edit made while the tree is green.
    *LOAD-BEARING*)                 printf '%s' "A/B transcripts are deliberately not committed (exit 3, by design)" ;;
    "Run set +e")                   printf '%s' "session/context block: no credentials on a public runner" ;;
    *) return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Extract, per job log, the steps whose BODY printed a runtime skip. Echoed
# source lines carry GitHub's command-echo colour (ESC[36;1m) and are excluded:
# the text of a guard that never fired is not evidence that it fired. Measured
# on the real run -- 39 of 39 ::error hits were echoed source, zero were real.
scan_dir () {   # <dir> -> one line per skipping step
  local d="$1" f
  for f in "$d"/*.txt; do
    [ -f "$f" ] || continue
    awk '
      function flush() { if (hit) print (name != "" ? name : g) }
      BEGIN { ESC = sprintf("%c", 27); g = ""; name = ""; hit = 0 }
      index($0, "##[group]") {
        flush()
        g = $0; sub(/.*##\[group\]/, "", g); gsub(/\r/, "", g)
        name = ""; hit = 0
        # The group line itself is "Run bash checker/x.sh" and is a legitimate
        # source of the name. Reading it only from the body assumed every log
        # echoes the command -- true of the real runs, false of a fixture, and
        # that mismatch made a control fail rather than the code.
        if (match(g, /checker\/[A-Za-z0-9_-]+\.sh/))
          name = substr(g, RSTART, RLENGTH)
        next
      }
      {
        line = $0
        # ATTRIBUTION IS AT STEP GRANULARITY, DELIBERATELY. An earlier version
        # took the first checker/*.sh seen in the body, which mis-attributed:
        # GitHub echoes an ENTIRE run: block before any of its output, so for a
        # step invoking several checkers the body order says nothing about which
        # one printed the skip. Measured: that heuristic blamed ab-compliance.sh
        # and live-session-smoke.sh for skips inside multi-checker blocks. The
        # group line is the only reliable key, so the budget is keyed on steps.
        if (index(line, ESC "[36;1m") == 0 &&
            (line ~ /SKIP/ || line ~ /no credentials/ ||
             line ~ /NOT RUN/ || line ~ /not on this machine/))
          hit = 1
      }
      END { flush() }
    ' "$f"
  done
}

judge_dir () {  # <dir> -> 0 clean, 1 an undeclared skipper
  local d="$1" s rc=0 n=0
  local skippers
  skippers="$(scan_dir "$d" | sort -u)"
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    n=$((n+1))
    if declared_reason "$s" >/dev/null 2>&1; then
      printf '  ....  declared: %-32s %s\n' "$s" "$(declared_reason "$s")"
    else
      printf '  ....  UNDECLARED SKIP: %s\n' "$s"
      rc=1
    fi
  done <<< "$skippers"
  printf '  ....  %s step(s) printed a runtime skip\n' "$n"
  return $rc
}

# -----------------------------------------------------------------------------
# CONTROLS FIRST. An alarm nobody has tripped on purpose is an untested alarm,
# and this one must be exercised in BOTH directions -- a detector only ever
# tested where it should fire will fire everywhere.
CTL="$(mktemp -d "${TMPDIR:-/tmp}/rot-cilogskip.XXXXXX")" || exit 2
trap 'rm -rf "$CTL"' EXIT

mkdir -p "$CTL/undeclared" "$CTL/declared" "$CTL/clean"

printf '##[group]Run bash checker/totally-new-thing.sh\nSKIP: no credentials on the runner\n' \
  > "$CTL/undeclared/0_job.txt"
printf '##[group]Run bash checker/ab-analyze.sh\nSKIP: the raw A/B transcripts are not on this machine\n' \
  > "$CTL/declared/0_job.txt"
printf '##[group]Run bash checker/repo-complete.sh\n  53 passed, 0 failed\n' \
  > "$CTL/clean/0_job.txt"

echo "== controls: the detector must fire AND stay silent =="
if judge_dir "$CTL/undeclared" >/dev/null 2>&1; then
  bad "CONTROL: an UNDECLARED skipping step was not detected"
else
  ok "CONTROL: an undeclared skipping step IS detected"
fi
if judge_dir "$CTL/declared" >/dev/null 2>&1; then
  ok "CONTROL: a declared skip is admitted (the budget works)"
else
  bad "CONTROL: a declared skip was wrongly flagged"
fi
if judge_dir "$CTL/clean" >/dev/null 2>&1; then
  ok "CONTROL: a step with no skip is not flagged"
else
  bad "CONTROL: a clean step was flagged as skipping"
fi

# A budget that swallows everything is the documented loosening. Assert the
# shipped budget is SMALLER than the checker tree, so it cannot have become one.
_declared_n=9
_checkers_n="$(find checker -maxdepth 1 -name '*.sh' | wc -l | tr -d ' ')"
if [ "$_declared_n" -lt "$_checkers_n" ]; then
  ok "the budget covers $_declared_n of $_checkers_n checkers, not the whole tree"
else
  bad "the budget covers every checker -- a_budget_containing_everything_disarms_the_ratchet"
fi

# -----------------------------------------------------------------------------
echo
echo "== the run =="
LOG_DIR="${CI_LOG_DIR:-}"
CLEANUP_DL=""

if [ -z "$LOG_DIR" ]; then
  RUN_ID="${1:-}"
  TOK="$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null \
         | sed -n 's/^password=//p')"
  if [ -z "$TOK" ]; then
    echo "SKIP: no GitHub credential from 'git credential fill'; cannot fetch logs."
    echo "      Exit 3 is a SKIP, never a pass."
    exit 3
  fi
  SLUG="$(git remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]##; s#\.git$##')"
  if [ -z "$RUN_ID" ]; then
    HEAD_SHA="$(git rev-parse HEAD)"
    RUNS="$(curl -sS -H "Authorization: Bearer $TOK" -H "Accept: application/vnd.github+json" \
            "https://api.github.com/repos/$SLUG/actions/runs?head_sha=$HEAD_SHA&per_page=10")"
    API_RC=$?
    if [ "$API_RC" -ne 0 ]; then
      echo "SKIP: the GitHub API could not be reached (curl exit $API_RC)."
      echo "      This says NOTHING about the run. Exit 3 is a SKIP, never a pass."
      exit 3
    fi
    RUN_ID="$(printf '%s' "$RUNS" | grep -oE '"id": [0-9]+' | head -1 | grep -oE '[0-9]+')"
  fi
  if [ -z "$RUN_ID" ]; then
    echo "SKIP: no CI run exists for HEAD -- most likely it has not been pushed."
    echo "      Exit 3 is a SKIP, never a pass."
    exit 3
  fi
  LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rot-cilogs.XXXXXX")"; CLEANUP_DL="$LOG_DIR"
  curl -sSL -H "Authorization: Bearer $TOK" -H "Accept: application/vnd.github+json" \
       -o "$LOG_DIR/logs.zip" "https://api.github.com/repos/$SLUG/actions/runs/$RUN_ID/logs"
  DL_RC=$?
  if [ "$DL_RC" -ne 0 ] || [ ! -s "$LOG_DIR/logs.zip" ]; then
    echo "SKIP: could not download logs for run $RUN_ID (curl exit $DL_RC)."
    echo "      Exit 3 is a SKIP, never a pass."
    rm -rf "$CLEANUP_DL"; exit 3
  fi
  ( cd "$LOG_DIR" && unzip -q logs.zip ) || { echo "SKIP: unzip failed. Exit 3."; rm -rf "$CLEANUP_DL"; exit 3; }
  echo "  judging run $RUN_ID on $SLUG"
else
  echo "  judging extracted logs at $LOG_DIR"
fi

if ! ls "$LOG_DIR"/*.txt >/dev/null 2>&1; then
  echo "SKIP: no job logs found under $LOG_DIR. Exit 3 is a SKIP, never a pass."
  [ -n "$CLEANUP_DL" ] && rm -rf "$CLEANUP_DL"
  exit 3
fi

if judge_dir "$LOG_DIR"; then
  ok "every step that skipped was declared, with a reason"
else
  bad "a step printed a runtime skip that nobody declared -- either wire it up or declare it"
fi

[ -n "$CLEANUP_DL" ] && rm -rf "$CLEANUP_DL"

echo
echo "== ci-log-skips: $pass passed, $fail failed"
if [ "$fail" -eq 0 ]; then echo "  ci-log-skips: PASS"; exit 0; fi
echo "  ci-log-skips: FAIL"; exit 1
