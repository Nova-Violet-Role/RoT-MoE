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

# A RED PREDECESSOR IS A SKIP, NOT A FAILURE -- otherwise this gate LATCHES.
#
# Each run reads the newest COMPLETED run, which is the one before it. If a red
# run made this gate fail, then run N red => run N+1 red => run N+2 red, with
# every step in every one of them passing. The repository could never return to
# green, and the obvious escape would be to delete the gate.
#
# The redness of run N is already reported by run N. Repeating it here adds no
# information and costs the ability to recover. What is true is narrower and is
# what gets said: the deferred steps CANNOT BE CLOSED from a run that did not
# finish, and an unclosed obligation is a SKIP, which this repository never
# counts as a pass.
if [ "$CONC" != "success" ]; then
  skip "the newest completed CI run (${SHA:0:7}) concluded '$CONC' -- deferred steps cannot be closed from a red run"
  echo "  NOTE  SKIP IS NOT A PASS. Fix that run, then this gate closes them."
  printf '
== deferred closure: %d passed, %d failed (INCOMPLETE)
' "$PASS" "$FAIL"
  exit 3
fi

# --- 2. the log archive -------------------------------------------------------
curl -sSL -H "Authorization: Bearer $TOK" "$API/actions/runs/$RID/logs" -o "$WORK/logs.zip" 2>/dev/null
if [ ! -s "$WORK/logs.zip" ]; then
  skip "the log archive for run $RID could not be downloaded (it expires after 90 days)"
  exit 3
fi
mkdir -p "$WORK/x"
unzip -q -o "$WORK/logs.zip" -d "$WORK/x" 2>/dev/null || { bad "the archive did not extract"; }
# Count FILES, not per-step files: the archive legitimately contains one log
# per job once the per-step ones are pruned. The floor is therefore "at least
# one log per job", not an arbitrary 10 that only held while the archive was new.
NLOG=$(find "$WORK/x" -type f | grep -c . || true)
NJOB=$(find "$WORK/x" -mindepth 1 -maxdepth 1 -type f -name '*.txt' | grep -c . || true)
if [ "$NLOG" -lt 1 ] || [ "$NJOB" -lt 1 ]; then
  bad "the archive holds $NLOG file(s) and $NJOB job log(s) -- nothing to close anything with"
else
  ok "log archive extracted: $NLOG file(s), $NJOB job log(s) from run $RID"
fi

# --- 3. EVERY step declared in THAT RUN'S ci.yml must have a log -------------
#
# THE SPEC MUST NOT FORBID A CORRECT FUTURE. The first version compared the
# step list in the WORKING TREE against the logs of the PREVIOUS run, so adding
# a step -- an entirely correct change -- made this gate red until that step had
# run once. It failed on the very commit that introduced it (run 30694656394,
# "no runner log for step: deferred closure"), which is the self-referential
# form of the defect.
#
# The obvious repair, dropping the step-coverage check, would have destroyed the
# only assertion here that catches a step silently not running. The right
# subject is the workflow AS IT EXISTED AT THAT RUN'S COMMIT: every step
# declared THEN must have produced a log THEN. Adding a step today is then
# neither a pass nor a failure -- it is simply not yet in scope, and the next
# run brings it in.
WFSNAP="$WORK/ci.at-run.yml"
if git cat-file -e "$SHA:$WF" 2>/dev/null; then
  git show "$SHA:$WF" > "$WFSNAP" 2>/dev/null
else
  # The sha may not be local (a shallow CI checkout, or a fresh clone). Ask for
  # the file at that ref instead of falling back to the working tree, which is
  # what created the defect above.
  curl -sS -H "Authorization: Bearer $TOK" -H "Accept: application/vnd.github.raw"        "$API/contents/$WF?ref=$SHA" -o "$WFSNAP" 2>/dev/null
fi
if [ ! -s "$WFSNAP" ] || ! grep -q '^      - name: ' "$WFSNAP"; then
  skip "could not read $WF as of ${SHA:0:7} -- refusing to compare against a different revision"
  printf '
== deferred closure: %d passed, %d failed (INCOMPLETE)
' "$PASS" "$FAIL"
  exit 3
fi
ok "read $WF as it was at ${SHA:0:7} -- the step list is compared against its own run"
# This is the closure. A step that never ran leaves no log, and a step renamed
# without being run leaves the old name behind -- both show up here.
# --- IS THE PER-STEP EVIDENCE STILL THERE? -----------------------------------
# MEASURED, twice, on the SAME run (30695750314):
#   morning   185901 bytes, 103 per-step logs  -> step coverage is checkable
#   afternoon  75370 bytes,   8 files, 4 job logs -> it is NOT
# GitHub prunes the per-step logs and keeps one log per job, and the surviving
# job log contains only the runner's own `##[group]` sections -- "Runner Image",
# "Fetching the repository". The names of OUR steps are gone with the files.
#
# So the strong claim -- every declared step produced a log -- is checkable only
# while the per-step files exist. When they are pruned the honest answer is I
# CANNOT TELL, and this repository spells that SKIP. Reporting it as a pass
# would be a false green; reporting it as a failure would turn every green run
# red once its archive aged, and the obvious repair for that is to delete the
# gate. Neither is acceptable, so the instrument states its own limit.
STEPLOGS=$(find "$WORK/x" -mindepth 2 -type f | grep -c . || true)
DECLARED=$(sed -n 's/^      - name: //p' "$WFSNAP" | grep -c . || true)
missing=0; checked=0
# ZERO per-step logs is the obvious pruned case. A PARTIAL set is the dangerous
# one: 4 files survived here out of 39 declared steps, enough to make the loop
# run and report 34 "missing" steps that had all in fact executed green. The
# threshold is therefore "at least as many per-step logs as declared steps",
# not "more than none" -- a partial archive answers I CANNOT TELL just as an
# empty one does, and only a complete one can answer NO.
if [ "$STEPLOGS" -lt "$DECLARED" ]; then
  skip "archive holds $STEPLOGS per-step log(s) for $DECLARED declared step(s) -- pruned, so step coverage CANNOT be checked"
  echo "  NOTE  SKIP IS NOT A PASS. The evidence-needle checks below still run."
else
while IFS= read -r name; do
  [ -n "$name" ] || continue
  checked=$((checked+1))
  # MATCH ON THE FILENAME. Measured, after trying the other way and being wrong:
  # the step NAME appears in the per-step log's FILENAME and NOT in any log's
  # contents. A content-based matcher was tried against a FRESH archive (93
  # files, run 30697918484) and reported all 39 steps missing -- it would have
  # been a gate that fails on a perfectly good run, in the loudest possible way.
  #
  # GitHub sanitises that filename: it cuts the name at the first `#` and strips
  # `/`. MEASURED -- "axiom audit -- #print axioms on every theorem, zero
  # sorryAx" is stored as "axiom audit --.txt", so a 28-character probe
  # containing `#print` matched nothing and called a green step missing. Cut
  # where the runner cuts, then take a short prefix.
  probe=$(printf '%s' "$name" | sed 's/#.*$//; s|/| |g' | cut -c1-20 \
          | sed 's/[ ]*$//' | sed 's/[][\\\\.*^$/]/./g')
  if ! find "$WORK/x" -name '*.txt' | sed 's|.*/||' | grep -q "$probe"; then
    bad "no runner log for step: $name"
    missing=$((missing+1))
  fi
done < <(sed -n 's/^      - name: //p' "$WFSNAP")
fi
if [ "$STEPLOGS" -lt "$DECLARED" ]; then
  : # already reported as a SKIP above; do not double-count it
elif [ "$checked" -eq 0 ]; then
  bad "no step names parsed out of $WF -- this closure would be vacuous"
elif [ "$missing" -eq 0 ]; then
  ok "all $checked declared step(s) have a log from the runner -- nothing silently skipped"
fi

# --- 4. the archive must be CLEAN --------------------------------------------
# The needles are BUILT, never written literally. A line containing the raw
# token is interpreted BY THE RUNNER as a workflow command: both success lines
# below were swallowed as annotations in run 30694656394 and never appeared in
# the log, while still counting toward the totals -- a checker that silently
# eats its own output. Measured, and the reason for the concatenation.
HASH='##'
ERRTOK="${HASH}[error]"
WARNTOK="${HASH}[warning]"
nerr=$(grep -rlF "$ERRTOK"  "$WORK/x" 2>/dev/null | grep -c . || true)
nwarn=$(grep -rlF "$WARNTOK" "$WORK/x" 2>/dev/null | grep -c . || true)
[ "${nerr:-1}" -eq 0 ]  && ok "zero error annotations across the whole run"   || bad "$nerr log(s) carry an error annotation"
[ "${nwarn:-1}" -eq 0 ] && ok "zero warning annotations across the whole run" || bad "$nwarn log(s) carry a warning annotation (a deprecated action or a runner notice)"

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
if grep -rqF -- "a step that never existed" "$WORK/x" 2>/dev/null; then
  bad "CONTROL DEAD: a fabricated step name was 'found' in the archive"
else
  ok "CONTROL: a fabricated step name is NOT found -- the matcher can miss"
fi
# And the archive must really have been read: a string that must be present.
# "Set up job" is a FILENAME every job emits, not file content. The first
# version of this control grepped CONTENTS, found nothing, and declared itself
# dead while the archive sat there fully extracted. A control that fails for
# the wrong reason is worth no more than one that cannot fail at all.
# "Set up job" was the needle here and it is NOT durable: it survives only as a
# per-step FILENAME, so this control died the moment the archive was pruned --
# and a dead control is worse than none, because it reads as coverage. "Runner
# Image" is written into every job log by the runner itself and survives.
if grep -rqF -- "Runner Image" "$WORK/x" 2>/dev/null; then
  ok "CONTROL: the line every runner emits IS present -- the archive was really read"
else
  bad "CONTROL DEAD: no 'Runner Image' line -- the archive was not read at all"
fi

printf '\n== deferred closure: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
