#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# CLOSE THE DEFERRED HALF -- WITH THE RUNNER'S OWN LOGS.
#
# `checker/ci-dryrun.sh` executes what it can of the CI step list in a clean
# tree and DEFERS the rest: anything that would install a toolchain, download
# mathlib, need root, need a real pty, or read a runner-provided variable. It
# prints "DEFERRED IS NOT PASSED" and it is right to -- a step nobody ran is a
# step nobody verified.
#
# That leaves an honest gap, and this file closes it from the other end. The
# deferred steps DO run: on the GitHub runner, every push. So fetch the log
# archive of the newest completed CI run and require, for every step declared
# in .github/workflows/ci.yml, that the runner produced a log for it -- and
# that the whole archive is free of `##[error]` and `##[warning]`.
#
# Together the two instruments cover the list with no third state:
#   ci-dryrun          -- would this step fail on a clean clone, before pushing
#   deferred-closure   -- did this step actually run and pass on the runner
#
# NETWORK. This checker talks to api.github.com and is therefore NOT part of
# the fast gate set and NOT part of the pre-commit hook. Without a usable token
# it EXITS 3 (SKIP), which this repository never counts as a pass.
#
# Exit: 0 closed · 1 a step is missing or the run was not clean · 2 refuse ·
#       3 SKIP (no token, no network, or no completed run yet -- NOT a pass).
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }
skip() { printf '  SKIP  %s\n' "$*"; }

WF=".github/workflows/ci.yml"
[ -f "$WF" ] || { echo "REFUSE: $WF missing"; exit 2; }
command -v curl  >/dev/null 2>&1 || { skip "curl absent";  exit 3; }
command -v unzip >/dev/null 2>&1 || { skip "unzip absent"; exit 3; }

echo "== deferred closure: the runner must have run what the dry run could not =="

# --- the token, never printed ------------------------------------------------
# Read from git's credential helper, exactly as the rest of this repo does. A
# missing token is a SKIP, not a failure: a contributor without push rights
# must still be able to run the gate set.
# On a runner there is no credential helper, but there IS a token in the
# environment. Accept it, so this gate is not permanently SKIPPED in the
# one place where the logs it reads are produced. The workflow grants
# `actions: read` for exactly this.
TOK="${ROT_GH_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
if [ -z "$TOK" ]; then
  TOK="$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | sed -n 's/^password=//p')"
fi
if [ -z "${TOK:-}" ]; then
  skip "no GitHub token available from the credential helper -- cannot read the run logs"
  echo "  NOTE  SKIP IS NOT A PASS. The deferred steps remain unverified from here."
  exit 3
fi

SLUG="${ROT_REPO_SLUG:-Nova-Violet-Role/RoT-MoE}"
API="https://api.github.com/repos/$SLUG"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/defclose.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# --- 1. the newest COMPLETED CI run on the default branch --------------------
# The WORKFLOW-scoped endpoint, filtered to completed runs, so the FIRST
# record is the one wanted. No JSON record-splitting -- that is where the
# first version of this parser produced conclusion 'unknown' and then
# reported it as a PASS, which is a false green in the instrument that exists
# to prevent false greens.
curl -sS -H "Authorization: Bearer $TOK" \
     "$API/actions/workflows/ci.yml/runs?per_page=1&branch=main&status=completed" \
     -o "$WORK/runs.json" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ] || [ ! -s "$WORK/runs.json" ]; then
  skip "the runs API was unreachable (curl exit $rc) -- no network, no verdict"
  exit 3
fi

RID=$(grep -o '"id": *[0-9]*' "$WORK/runs.json" | head -1 | tr -dc '0-9')
CONC=$(grep -o '"conclusion": *"[a-z_]*"' "$WORK/runs.json" | head -1 | tr -d '"' | awk '{print $2}')
# NOT `tr -dc` over a hex class: the KEY NAME "head_sha" is itself made of
# characters in that class, so the first version printed the sha as
# "eadab1c..." -- the e,a,d,a of "head_sha" glued onto the real value. It
# was only ever displayed and never asserted on, which is exactly how a
# wrong number survives in a report. Take the quoted VALUE.
SHA=$(grep -o '"head_sha": *"[0-9a-f]*"' "$WORK/runs.json" | head -1 | tr -d '"' | awk '{print $2}')
if [ -z "$RID" ] || [ -z "$CONC" ]; then
  skip "could not identify a completed CI run for this workflow"
  exit 3
fi
ok "newest completed CI run identified: id $RID, conclusion '$CONC', sha ${SHA:0:7}"

if [ "$CONC" != "success" ]; then
  bad "the newest completed CI run concluded '$CONC' -- the deferred steps cannot be closed by a red run"
fi

# --- 2. the log archive -------------------------------------------------------
curl -sSL -H "Authorization: Bearer $TOK" "$API/actions/runs/$RID/logs" -o "$WORK/logs.zip" 2>/dev/null
if [ ! -s "$WORK/logs.zip" ]; then
  skip "the log archive for run $RID could not be downloaded (it expires after 90 days)"
  exit 3
fi
mkdir -p "$WORK/x"
unzip -q -o "$WORK/logs.zip" -d "$WORK/x" 2>/dev/null || { bad "the archive did not extract"; }
NLOG=$(find "$WORK/x" -name '*.txt' | grep -c . || true)
if [ "$NLOG" -lt 10 ]; then
  bad "only $NLOG step logs in the archive -- too few to close anything"
else
  ok "log archive extracted: $NLOG step log(s) from run $RID"
fi

# --- 3. EVERY step declared in ci.yml must have a log ------------------------
# This is the closure. A step that never ran leaves no log, and a step renamed
# without being run leaves the old name behind -- both show up here.
missing=0; checked=0
while IFS= read -r name; do
  [ -n "$name" ] || continue
  checked=$((checked+1))
  # GitHub sanitises the filename: the step name with `/` replaced. Match on a
  # distinctive prefix rather than the whole string, since long names are cut.
  # GitHub sanitises the log filename: it cuts the step name at the first `#`
  # and strips `/`. MEASURED -- "axiom audit -- #print axioms on every theorem,
  # zero sorryAx" is stored as "axiom audit --.txt", so a 28-character probe
  # containing `#print` matched nothing and reported a step MISSING that had in
  # fact run green. Cut where the runner cuts, then take a short prefix.
  probe=$(printf '%s' "$name" | sed 's/#.*$//; s|/| |g' | cut -c1-20 \
          | sed 's/[ ]*$//' | sed 's/[][\\.*^$/]/./g')
  if ! find "$WORK/x" -name '*.txt' | sed 's|.*/||' | grep -q "$probe"; then
    bad "no runner log for step: $name"
    missing=$((missing+1))
  fi
done < <(sed -n 's/^      - name: //p' "$WF")
if [ "$checked" -eq 0 ]; then
  bad "no step names parsed out of $WF -- this closure would be vacuous"
elif [ "$missing" -eq 0 ]; then
  ok "all $checked declared step(s) have a log from the runner -- nothing silently skipped"
fi

# --- 4. the archive must be CLEAN --------------------------------------------
nerr=$(grep -rl '##\[error\]'   "$WORK/x" 2>/dev/null | grep -c . || true)
nwarn=$(grep -rl '##\[warning\]' "$WORK/x" 2>/dev/null | grep -c . || true)
[ "$nerr"  -eq 0 ] && ok "zero ##[error] annotations across the whole run"   || bad "$nerr log(s) carry ##[error]"
[ "$nwarn" -eq 0 ] && ok "zero ##[warning] annotations across the whole run" || bad "$nwarn log(s) carry ##[warning] (a deprecated action or a runner notice)"

# --- 5. the deferred steps specifically ---------------------------------------
# Named by the EVIDENCE they must produce, not by step title, so a rename does
# not silently drop the check. These are precisely the lines ci-dryrun cannot
# reach: a toolchain install, a mathlib cache hit, a real lake build, a kernel
# re-check and a mutation suite that actually killed something.
for probe in \
  "lake build exit=0|the real lake build reported exit 0 on the runner" \
  "all modules re-verified|leanchecker re-verified every module, with its control" \
  "killed=|the mutation suites ran and reported kill counts" \
  "Lean (version|the toolchain was read from lean-toolchain, not assumed"
do
  needle=${probe%%|*}; label=${probe#*|}
  if grep -rqF "$needle" "$WORK/x" 2>/dev/null; then
    ok "$label"
  else
    bad "MISSING from the runner logs: $label (needle '$needle')"
  fi
done

# A mutation suite that discarded everything would print kill counts and prove
# nothing -- RotMutant.lean is explicit that discarded is not a kill.
if grep -rhoE 'killed=[0-9]+ survived=[0-9]+ discarded=[0-9]+' "$WORK/x" 2>/dev/null | grep -qv 'killed=0'; then
  ok "at least one suite reported a NON-ZERO kill count (not all discarded)"
else
  bad "no suite reported a non-zero kill count -- the mutation evidence is empty"
fi

# --- negative controls --------------------------------------------------------
echo
echo "-- negative controls --"
# The matcher must not find a step that does not exist, or step 3 is decoration.
if find "$WORK/x" -name '*.txt' | sed 's|.*/||' | grep -q "a step that never existed"; then
  bad "CONTROL DEAD: a fabricated step name was 'found' in the archive"
else
  ok "CONTROL: a fabricated step name is NOT found -- the matcher can miss"
fi
# And the archive must really have been read: a string that must be present.
# "Set up job" is a FILENAME every job emits, not file content. The first
# version of this control grepped CONTENTS, found nothing, and declared itself
# dead while the archive sat there fully extracted. A control that fails for
# the wrong reason is worth no more than one that cannot fail at all.
if find "$WORK/x" -name '*.txt' | sed 's|.*/||' | grep -q "Set up job"; then
  ok "CONTROL: the step every runner emits IS present -- the archive was really read"
else
  bad "CONTROL DEAD: no 'Set up job' log -- the archive was not read at all"
fi

printf '\n== deferred closure: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
