#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# WORKFLOW LINT -- and the drift check that is the actual reason it exists.
#
# Two failures this catches, neither of which any other gate can see:
#
#   1. A WORKFLOW THAT DOES NOT PARSE. Costs a full red CI run to discover, and
#      the error arrives from GitHub rather than from anything you can run
#      locally. Cheap to check here.
#
#   2. A CHECKER THAT CI NEVER RUNS. This is the dangerous one. Add
#      `checker/new-thing.sh`, run it by hand once, commit -- and CI is green
#      forever without ever executing it. The repo then LOOKS more verified
#      than it is, which is the same false-green class this project keeps
#      hunting: the instrument exists, nobody wired it up, and the green tick
#      says nothing about it.
#
# So: every executable in checker/ must appear in a workflow, or be listed as a
# deliberate exception WITH a reason. Silence is not an option.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }

echo "== workflow lint =="

# --- 1. do they parse? ------------------------------------------------------
YAML_OK=0
if node -e 'require("js-yaml")' >/dev/null 2>&1; then YAML_OK=1
elif npx --yes --quiet js-yaml --help >/dev/null 2>&1; then YAML_OK=2; fi

if [ "$YAML_OK" -eq 0 ]; then
  echo "  SKIP  no YAML parser available -- workflows NOT parsed. Not a pass."
else
  for wf in .github/workflows/*.yml; do
    if npx --yes --quiet js-yaml "$wf" >/dev/null 2>&1; then
      ok "parses: $wf"
    else
      bad "DOES NOT PARSE: $wf"
      npx --yes --quiet js-yaml "$wf" 2>&1 | head -3 | sed 's/^/        /'
    fi
  done

  # NEGATIVE CONTROL: the parser must reject something. A linter that passes
  # everything is not a linter.
  BADF="$(mktemp "${TMPDIR:-/tmp}/badwf.XXXXXX").yml"
  printf 'name: broken\non:\n  push:\njobs:\n  x:\n    steps:\n      - run: echo hi\n     bad_indent: true\n' > "$BADF"
  if npx --yes --quiet js-yaml "$BADF" >/dev/null 2>&1; then
    bad "CONTROL DEAD: the parser accepted deliberately broken YAML"
  else
    ok "CONTROL: deliberately broken YAML was rejected"
  fi
  rm -f "$BADF"
fi

# --- 2. does CI actually run every checker? ---------------------------------
echo
echo "-- drift: every checker must be wired into a workflow --"
# Deliberate exceptions, each with a reason. An empty reason is not allowed.
declare -A EXCEPT
EXCEPT[preflight.sh]="informational; run as the first CI step but not a gate"
EXCEPT[workflow-lint.sh]="would recurse; run from CI as its own step below"
# gate-all is an AGGREGATOR for local use and the pre-commit hook. Running it in
# CI would re-run every gate a second time inside one step, and a failure would
# report as "gate-all failed" instead of naming the check that broke. Per-step
# granularity is worth more in CI than a single roll-up. It is exercised on
# every local commit via .githooks/pre-commit, and the phase below asserts that
# every gate it lists is a real, present checker -- so it cannot silently rot.
EXCEPT[gate-all.sh]="aggregator for the pre-commit hook; CI runs each gate as its own named step"

WF_TEXT="$(cat .github/workflows/*.yml)"
for c in checker/*.sh; do
  base="$(basename "$c")"
  if printf '%s' "$WF_TEXT" | grep -qF "$base"; then
    ok "wired into a workflow: $base"
  elif [ -n "${EXCEPT[$base]:-}" ]; then
    echo "  NOTE  exempt: $base -- ${EXCEPT[$base]}"
  else
    bad "NOT RUN BY ANY WORKFLOW: $base"
    echo "        The repo looks more verified than it is. Wire it up, or add it"
    echo "        to EXCEPT in this file WITH a reason."
  fi
done

# --- 2b. the aggregator must not rot ----------------------------------------
# gate-all.sh is exempt from the CI-wiring rule above, so it needs its own
# check: every gate it names must be a checker that actually exists. A typo
# there would silently drop a gate from every local commit, and the roll-up
# would still print ALL GREEN -- the failure being green is the whole problem.
echo
echo "-- the pre-commit aggregator lists only real checkers --"
if [ -f checker/gate-all.sh ]; then
  listed=0; missing=0
  while read -r cmd; do
    [ -z "$cmd" ] && continue
    listed=$((listed+1))
    [ -f "$cmd" ] || { bad "gate-all names a checker that does not exist: $cmd"; missing=$((missing+1)); }
  done < <(grep -oE 'checker/[a-z-]+\.sh' checker/gate-all.sh | sort -u)
  if [ "$listed" -eq 0 ]; then
    bad "gate-all lists NO checkers -- it would pass vacuously on every commit"
  elif [ "$missing" -eq 0 ]; then
    ok "gate-all names $listed checkers, all present"
  fi
  # The hook that CALLS it must exist, be executable, and actually call it.
  if [ -f .githooks/pre-commit ]; then
    ok "pre-commit hook present"
    grep -q "gate-all.sh" .githooks/pre-commit       && ok "pre-commit actually calls gate-all"       || bad "pre-commit exists but never calls gate-all -- it guards nothing"
    grep -q "exit 1" .githooks/pre-commit       && ok "pre-commit can refuse a commit"       || bad "pre-commit has no refusing path"
  else
    bad ".githooks/pre-commit missing -- the red-gate commit can happen again"
  fi

  # It must also refuse: a roll-up that cannot go red is decoration.
  grep -q 'exit 1' checker/gate-all.sh \
    && ok "gate-all can exit non-zero" \
    || bad "gate-all has no failing exit path -- it cannot stop a bad commit"
else
  bad "checker/gate-all.sh is missing -- the pre-commit hook has nothing to call"
fi

# --- 3. does CI build every Lean module and run every mutation suite? -------
echo
echo "-- drift: every Lean module and mutation suite must be in CI --"
for m in lean/Proofs/*.lean; do
  mod="$(basename "$m" .lean)"
  printf '%s' "$WF_TEXT" | grep -qF "Proofs.$mod" \
    && ok "CI builds Proofs.$mod" \
    || bad "CI NEVER BUILDS Proofs.$mod -- it is unverified in CI"
done
for s in lean/mutate/mutate_*.sh; do
  base="$(basename "$s")"
  printf '%s' "$WF_TEXT" | grep -qF "$base" \
    && ok "CI runs $base" \
    || bad "CI NEVER RUNS $base -- those theorems are unmutated in CI"
done

# --- 4. the anti-inauthenticity rule ----------------------------------------
echo
echo "-- the --allow-empty rule (R18) --"
# SCOPE IT TO AN ACTUAL INVOCATION. The first version grepped the whole file and
# flagged the COMMENTS explaining why --allow-empty is absent -- a check that
# fires on its own documentation. Same defect shape as the live-session detector
# that matched the word "Exception:" in the model's prose: a pattern broad enough
# to match prose will match prose, and it fails in the alarming direction, which
# trains you to ignore it.
ALLOW_RE='^[^#]*git commit[^#]*--allow-empty'
if grep -rnE "$ALLOW_RE" .github/workflows/ >/dev/null 2>&1; then
  bad "a workflow COMMITS with --allow-empty: that manufactures activity"
  grep -rnE "$ALLOW_RE" .github/workflows/ | sed 's/^/        /'
else
  ok "no workflow COMMITS with --allow-empty (a commit means the verdict CHANGED)"
fi

# CONTROL: the pattern must be able to fire, or its green means nothing.
CTLDIR="$(mktemp -d "${TMPDIR:-/tmp}/wfctl.XXXXXX")"
printf '      run: git commit --allow-empty -m "keepalive"\n' > "$CTLDIR/w.yml"
if grep -qE "$ALLOW_RE" "$CTLDIR/w.yml"; then
  ok "CONTROL: a planted keepalive commit WOULD be detected"
else
  bad "CONTROL DEAD: a planted keepalive commit was not detected"
fi
# And the converse control: a mere mention in a comment must NOT fire.
printf '# --allow-empty is deliberately absent from the commit below\n' > "$CTLDIR/c.yml"
if grep -qE "$ALLOW_RE" "$CTLDIR/c.yml"; then
  bad "CONTROL: a COMMENT about --allow-empty still trips the check"
else
  ok "CONTROL: a comment mentioning --allow-empty does NOT trip it"
fi
rm -rf "$CTLDIR"

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  workflow-lint: PASS"; exit 0; } || { echo "  workflow-lint: FAIL"; exit 1; }
