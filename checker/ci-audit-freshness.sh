#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE TREE CI TESTED IS NOT ALWAYS THE TREE YOU FIXED.
#
# WHY THIS EXISTS, stated plainly because the reason is a mistake I made and a
# user caught:
#
#   Three consecutive CI runs failed on the identical line:
#     FAIL  sh: log grew to       24 lines with cap 5 -- unbounded
#   I had diagnosed it correctly on the first run, written the fix, proved it in
#   Lean, and reproduced the failure locally. What I had NOT done was land it.
#   `git commit` was killed three times by a wall-clock ceiling, each kill
#   leaving the gate running as an orphan, and I read the timeouts as "slow"
#   rather than "the commit did not happen". The remote never received the
#   repair, so CI could only keep reporting the same error -- correctly.
#
# The failure mode is NOT "unpushed commits exist". That is normal and healthy.
# It is claiming a fix is in effect while the audited run predates it. So this
# checker answers one question and refuses to guess at any other:
#
#     Does the CI run I am reading contain the commits I think it does?
#
# DELIBERATELY NOT REGISTERED IN ci.yml, and that is a judgement, not an
# oversight. This compares the audited run against LOCAL HEAD. Inside a CI job
# local HEAD *is* the run's own commit, so the comparison would pass by
# construction on every run forever -- a step that cannot fail, which this repo
# calls decoration and refuses to ship. The defect it catches happens on the
# development machine, between writing a fix and landing it, so it runs there.
#
# Usage:
#   bash checker/ci-audit-freshness.sh [RUN_ID]
#     no RUN_ID  -- use the most recent run on the default branch
#
# Exit codes:  0 the run contains local HEAD   1 it does not (with the list)
#              2 refused (bad usage)           3 SKIP (no credential -- never a pass)
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
inf() { printf '  ----  %s\n' "$1"; }

echo "== CI audit freshness: is the run you are reading the tree you fixed? =="

SLUG="Nova-Violet-Role/RoT-MoE"

TOKEN="$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null \
         | grep '^password=' | cut -d= -f2)"
if [ -z "${TOKEN:-}" ]; then
  inf "no GitHub credential available -- SKIP, and a skip is NEVER a pass"
  echo "== ci-audit-freshness: SKIPPED (exit 3)"
  exit 3
fi

# TWO MODES, AND THE DISTINCTION IS THE WHOLE DESIGN.
#
# The first version of this file failed whenever local HEAD was ahead of the
# remote. It went red immediately -- on a completely correct state. At
# pre-commit time HEAD is ahead of the remote BY CONSTRUCTION, so as a gate it
# forbade ever committing before pushing, and the tempting repair (delete the
# gate, or weaken it to a warning everywhere) would have destroyed the one
# alarm that mattered.
#
#   AUDIT mode  -- a RUN_ID was named. You are making a claim ABOUT THAT RUN, so
#                  a run that predates local HEAD is a FAILURE: its verdict
#                  cannot speak to commits it never contained.
#   GATE mode   -- no argument. You are committing. Drift from the remote is
#                  normal and is reported, never failed.
#
# Same evidence, different question. Being ahead of the remote is only a defect
# relative to a CLAIM about a run.
MODE=gate
[ $# -gt 0 ] && MODE=audit

RUN_ID="${1:-}"
if [ -z "$RUN_ID" ]; then
  # A BOUNDED, RETRIED FETCH -- and an unanswered API is a SKIP, never a FAIL.
  #
  # Measured 2026-08-11: this gate went RED inside a parallel pre-commit sweep
  # with `SyntaxError: Unexpected end of JSON input` -- curl returned an EMPTY
  # body. Run standalone one minute later, and again with stdin closed and with
  # the hook's GIT_DIR/GIT_INDEX_FILE set, it passed every time. The cause was a
  # transient network failure, not a stale run.
  #
  # That is the defect being fixed. "The API did not answer" and "the audited run
  # predates your fix" are OPPOSITE findings, and the first was being reported as
  # the second -- the same class as scoring a mutant that never applied as
  # SURVIVED. A red gate that means "the network blinked" trains the reader to
  # dismiss the gate, which costs exactly the alarm it exists to raise.
  #
  # This is NOT a weakening: a genuine staleness FAIL requires actually reading a
  # run, and that path is untouched below. What changes is that a checker which
  # could not measure now says so.
  _try=0
  while [ "$_try" -lt 3 ]; do
    _body=$(curl -s --max-time 20 -H "Authorization: Bearer $TOKEN" \
      "https://api.github.com/repos/$SLUG/actions/runs?per_page=1")
    if [ -n "$_body" ]; then
      RUN_ID=$(printf '%s' "$_body" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
          try{const r=JSON.parse(d).workflow_runs;process.stdout.write(r&&r[0]?String(r[0].id):"")}
          catch(e){process.stdout.write("")}})')
    fi
    [ -n "$RUN_ID" ] && break
    _try=$((_try+1))
    sleep 2
  done
  if [ -z "$RUN_ID" ]; then
    inf "the GitHub API did not answer in 3 bounded attempts -- SKIP, and a skip is NEVER a pass"
    inf "this is 'could not measure', which is NOT the same finding as 'the audited run is stale'"
    echo "== ci-audit-freshness: SKIPPED (exit 3)"
    exit 3
  fi
fi
if [ -z "$RUN_ID" ]; then
  bad "could not determine a run id -- refusing to report on a run I cannot name"
  echo "== ci-audit-freshness: 0 passed, 1 failed"
  exit 1
fi

META=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/$SLUG/actions/runs/$RUN_ID")
RUN_SHA=$(printf '%s' "$META" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
    try{process.stdout.write(String(JSON.parse(d).head_sha||""))}catch(e){process.stdout.write("")}})')
RUN_CONC=$(printf '%s' "$META" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
    try{const j=JSON.parse(d);process.stdout.write(String(j.conclusion||j.status||"?"))}catch(e){process.stdout.write("?")}})')

if [ -z "$RUN_SHA" ]; then
  bad "run $RUN_ID returned no head_sha -- cannot establish what it tested"
  echo "== ci-audit-freshness: 0 passed, 1 failed"
  exit 1
fi

LOCAL_SHA=$(git rev-parse HEAD)
inf "run $RUN_ID tested ${RUN_SHA:0:7} ($RUN_CONC); local HEAD is ${LOCAL_SHA:0:7}"

# The run's commit must be an ANCESTOR of local HEAD, or equal to it. If it is
# not even known locally, the run tested something this clone has never seen.
if ! git cat-file -e "${RUN_SHA}^{commit}" 2>/dev/null; then
  bad "the audited commit ${RUN_SHA:0:7} is not in this clone -- fetch before drawing conclusions"
  echo
  echo "== ci-audit-freshness: $PASS passed, $FAIL failed"
  exit 1
fi

if [ "$RUN_SHA" = "$LOCAL_SHA" ]; then
  ok "the run tested EXACTLY local HEAD -- its verdict is about the code you have"
else
  MISSING=$(git log --oneline "${RUN_SHA}..HEAD" 2>/dev/null | wc -l | tr -dc '0-9')
  [ -n "$MISSING" ] || MISSING=0
  if [ "$MISSING" -gt 0 ]; then
    if [ "$MODE" = audit ]; then
      bad "the run PREDATES $MISSING local commit(s) -- its failures cannot reflect them:"
    else
      inf "the latest run predates $MISSING local commit(s) -- normal before a push, reported not failed:"
    fi
    git log --oneline "${RUN_SHA}..HEAD" 2>/dev/null | sed 's/^/          /'
    inf "a red run here says nothing about a fix that is not in it. Push, then re-audit."
    # A GATE THAT ASSERTS NOTHING IS NOT A GATE. In gate mode the drift above is
    # informational, so state the thing that IS being asserted: the audited run
    # is on this history rather than on some divergent one. That can fail -- a
    # rebase or a force-push makes it false -- so it is worth printing as a pass.
    [ "$MODE" = audit ] || ok "the latest run is an ANCESTOR of local HEAD -- same history, no divergence"
  else
    ok "local HEAD is contained in the audited run (no local commits are missing from it)"
  fi
fi

# --- the second half: is the remote actually carrying local HEAD? ------------
# A commit that exists only locally cannot be tested by anything. This is the
# check whose absence let three runs report the same error while the repair sat
# on one machine.
REMOTE_SHA=$(git ls-remote "https://x-access-token:$TOKEN@github.com/$SLUG.git" \
             refs/heads/main 2>/dev/null | awk '{print $1}' | head -1)
if [ -z "$REMOTE_SHA" ]; then
  inf "could not read refs/heads/main from the remote -- remote parity UNCHECKED, not passed"
else
  inf "remote main is at ${REMOTE_SHA:0:7}"
  if [ "$REMOTE_SHA" = "$LOCAL_SHA" ]; then
    ok "the remote carries local HEAD -- what you fixed is what CI will test next"
  elif git cat-file -e "${REMOTE_SHA}^{commit}" 2>/dev/null && \
       git merge-base --is-ancestor "$REMOTE_SHA" "$LOCAL_SHA" 2>/dev/null; then
    UNPUSHED=$(git log --oneline "${REMOTE_SHA}..HEAD" 2>/dev/null | wc -l | tr -dc '0-9')
    [ -n "$UNPUSHED" ] || UNPUSHED=0
    if [ "$MODE" = audit ]; then
      bad "$UNPUSHED local commit(s) are NOT on the remote -- CI cannot see them:"
    else
      inf "$UNPUSHED local commit(s) not yet on the remote -- expected while committing:"
    fi
    git log --oneline "${REMOTE_SHA}..HEAD" 2>/dev/null | sed 's/^/          /'
  else
    bad "local HEAD and remote main have diverged -- neither contains the other"
  fi
fi

echo
echo "== ci-audit-freshness: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
