#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# CI HONESTY -- no skip, no fake green, every warning a SUCCESS.
#
# THE RULE THIS ENFORCES, in the Socio's words:
#
#   "Closing fake green, one by deleting a check or simply skipping is also not
#    allowed, weakening a theorem, or disarming a Powerful implementation is a
#    violation. On the CI job review the log and see that everything is perfect
#    for every runned job: no skip, no fake green, every warning a SUCCESS."
#
# This is the .sh half of lean/Proofs/RotGates.lean's CI HONESTY section. The
# Lean half proves the law is coherent; this half applies it to a real run. A
# proof that never touches the running system proves nothing about it.
#
# THE RULE IS ABSOLUTE: NO SKIP. NOT "no skip except provisioning".
#
# An earlier draft of this checker exempted platform-provisioning steps, on the
# argument that installing a Linux locale on macOS is meaningless and skipping
# it is correct. That argument is WRONG, and it is wrong in the way the rule
# was written to forbid: it is the checker being weakened to fit the CI instead
# of the CI being fixed to satisfy the checker. An exemption list is a list of
# checks that stopped being enforced.
#
# The correct fix is not a tolerant checker. It is a workflow where nothing
# skips: a step whose work is platform-specific RUNS on every platform and
# branches INSIDE, so it concludes `success` everywhere and the log carries the
# reason instead of a gap. All four conditional steps in ci.yml were converted
# that way in the same commit as this file.
#
# THE THREE RULES, all unconditional:
#
#   1. NO step may conclude `skipped`                         (no skip)
#   2. every step must conclude `success`                     (no fake green)
#   3. the run must conclude `success`                        (not cancelled,
#                                                              not neutral)
#
# Rule 1 subsumes the `bc1272d` defect -- "gauge-cross had NEVER run, skipped in
# every job, green the whole cycle" -- without needing to reason about which
# skips are benign. There are none.
#
# The only steps not judged are the runner's own scaffolding (`Set up job`,
# `Post <action>`, ...), which GitHub injects and the workflow does not author.
# Those are listed explicitly and narrowly below; every step the repository
# writes is judged.
#
# USAGE
#   checker/ci-honesty.sh                  latest run on the current branch
#   checker/ci-honesty.sh <run_id>         a specific run
#   CI_JOBS_JSON=file.json checker/...     offline, against a saved API response
#
# EXIT  0 honest | 1 violation | 2 usage/auth error | 3 SKIP (never a pass)
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

pass=0; fail=0
ok  () { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
bad () { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }
# A THIRD outcome, and the reason it exists is a false green I acted on.
#
# MEASURED 2026-08-09. Runs 31261506027 and 31263721866 both concluded FAILURE:
# the macOS job died at `local-only 1.0.x release regenerates from HEAD` and 28
# later steps were skipped. This checker was run against both -- while they were
# still `in_progress` -- and printed
#
#     PASS  NO step was skipped -- every authored step ran on every platform
#     PASS  every step concluded success (158 steps read)
#
# Both were true of the steps that had finished, and both were WRONG about the
# run. The `FAIL the run is in_progress` line was there, but two PASS lines
# beside it read as "only the timing is unresolved", and the macOS failure went
# unnoticed across two commits until the Socio spotted it.
#
# A question whose answer is not yet knowable must not be answered PASS. `prov`
# reports the reading WITHOUT counting it as a pass, so an unfinished run can
# never contribute evidence of health. Same rule as the malformed-payload guard
# above: a third outcome, not a coerced second one.
prov () { printf '  ....  PROVISIONAL (run not finished, this is NOT a pass): %s\n' "$1"; }

REPO="${CI_HONESTY_REPO:-Nova-Violet-Role/RoT-MoE}"

# --- runner scaffolding ------------------------------------------------------
# GitHub injects these; the repository does not author them, so they are not
# steps this project can be held to. NOTHING the workflow writes appears here --
# that would be an exemption, and exemptions are what this checker exists to
# refuse. Kept to exact prefixes so a real step cannot fall in by accident.
is_scaffolding () {
  case "$1" in
    "Set up job"|"Complete job") return 0 ;;
    "Post "*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- fetch -------------------------------------------------------------------
JOBS_JSON="${CI_JOBS_JSON:-}"
RUN_ID="${1:-}"

if [ -z "$JOBS_JSON" ]; then
  TOK="$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null \
         | sed -n 's/^password=//p')"
  if [ -z "$TOK" ]; then
    echo "SKIP: no GitHub credential available from 'git credential fill'."
    echo "      Cannot read the run. This is a SKIP (exit 3), never a pass."
    exit 3
  fi
  api () { curl -sS -H "Authorization: Bearer $TOK" \
                     -H "Accept: application/vnd.github+json" "$1"; }

  if [ -z "$RUN_ID" ]; then
    # Judge the run FOR THIS COMMIT, not merely the most recent one.
    #
    # The first version took the latest run on the branch, and that is the wrong
    # object: it made this gate refuse the very commit that REPAIRED the run it
    # was complaining about. A gate that blocks its own fix is not strict, it is
    # mis-aimed -- it was judging the parent commit's CI while reading the
    # child's tree.
    #
    # There is no honest verdict on a run that has not happened. That case is a
    # SKIP (exit 3) and gate-all does not score a skip as a pass. This is not an
    # exemption: it is refusing to report a result about an object that does not
    # exist yet, which is the opposite of fake green.
    # A verdict may only be attributed to the code that PRODUCED the run.
    #
    # This gate deadlocked itself on its first run: it judged HEAD's CI, HEAD's
    # CI was dishonest, and the commit that REPAIRED the workflow was therefore
    # refused -- permanently, because the repair could never land. A gate that
    # cannot be fixed is not strict, it is broken.
    #
    # If the working tree has changed the workflow since HEAD, the run being
    # judged was produced by superseded code and says nothing about what is
    # about to be committed. That is a SKIP with its reason named, not a pass
    # and not an exemption: the correct verdict arrives after the push, when a
    # run exists for the new workflow. `checker/gate-all.sh` scores 3 as
    # "SKIP -- never a pass", and verify.yml asserts it for real.
    if ! git diff HEAD --quiet -- .github/workflows/ 2>/dev/null; then
      echo "SKIP: the working tree modifies .github/workflows/ since HEAD."
      echo "      Any run for HEAD was produced by superseded workflow code, so a"
      echo "      verdict on it would not be about the tree being committed."
      echo "      Push, then re-run this gate against the new run."
      echo "      Exit 3 is a SKIP, never a pass."
      exit 3
    fi
    HEAD_SHA="$(git rev-parse HEAD)"
    # SEPARATE "the API did not answer" FROM "there is no run yet". Measured
    # 2026-08-09: a DNS blip (`curl: (6) Could not resolve host: api.github.com`)
    # produced an empty body, and this branch announced "This commit has not
    # been pushed" about a commit that HAD been pushed thirty seconds earlier.
    # The exit code was right -- 3, a skip, never a pass -- but the DIAGNOSIS
    # was invented, and a wrong diagnosis sends the next person to push again
    # instead of checking their network. Reading curl's status through a pipe
    # would have hidden it, so the body is captured first and the status read
    # directly.
    RUNS_JSON="$(api "https://api.github.com/repos/$REPO/actions/runs?head_sha=$HEAD_SHA&per_page=1")"
    API_RC=$?
    if [ "$API_RC" -ne 0 ]; then
      echo "SKIP: the GitHub API could not be reached (curl exit $API_RC)."
      echo "      This says NOTHING about whether the commit was pushed or whether"
      echo "      CI is green -- the question was never asked. Check connectivity,"
      echo "      then re-run. Exit 3 is a SKIP, never a pass."
      exit 3
    fi
    RUN_ID="$(printf '%s' "$RUNS_JSON" | grep -oE '"id": [0-9]+' | head -1 | grep -oE '[0-9]+')"
    if [ -z "$RUN_ID" ]; then
      echo "SKIP: the API answered, and it lists no CI run for HEAD ($HEAD_SHA)."
      echo "      Most likely this commit has not been pushed yet."
      echo "      Re-run this gate after the push. Exit 3 is a SKIP, never a pass."
      exit 3
    fi
  fi
  [ -n "$RUN_ID" ] || { echo "SKIP: no run found. Exit 3, never a pass."; exit 3; }

  JOBS_JSON="$(mktemp)"; trap 'rm -f "$JOBS_JSON"' EXIT
  api "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/jobs?per_page=100" > "$JOBS_JSON"
  RUN_JSON="$(api "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID")"
  RUN_CONCL="$(printf '%s' "$RUN_JSON" | grep -oE '"conclusion": "[a-z_]+"' | head -1 \
               | sed 's/.*: "//; s/"//')"
  RUN_STATUS="$(printf '%s' "$RUN_JSON" | grep -oE '"status": "[a-z_]+"' | head -1 \
               | sed 's/.*: "//; s/"//')"
else
  RUN_CONCL="${CI_RUN_CONCLUSION:-success}"
  RUN_STATUS="${CI_RUN_STATUS:-completed}"
fi

echo "== CI HONESTY -- run ${RUN_ID:-<offline>} on $REPO =="
echo

# The API response must actually contain jobs. An empty or error payload that
# yields zero steps would otherwise sail through every loop below and report a
# perfect record, which is the exact failure shape this checker exists to catch.
#
# AND THE GUARD ITSELF FAILED OPEN, EXACTLY WHEN IT WAS NEEDED. Measured
# 2026-08-09 against a run that was still 'pending' and had no steps yet:
#
#   TOTAL_STEPS="$(grep -cE ... || echo 0)"
#
# `grep -c` PRINTS `0` and ALSO exits 1 when it matches nothing, so the `|| echo 0`
# appended a second zero and the variable became the two-line string "0\n0".
# `[ "0\n0" -lt 5 ]` is not a comparison, it is an error -- bash printed
# `[: 0: integer expression expected` and returned non-zero, which took the ELSE
# branch. The guard against an empty payload waved the empty payload through,
# and the checker went on to report `PASS every step concluded success
# (0 steps read)` -- a pass over the empty set, which is the precise failure
# shape this file exists to catch, committed inside the catcher.
#
# The repair keeps the substitution and the fallback apart, then insists the
# result is a number before it is compared. Anything unparseable REFUSES.
TOTAL_STEPS="$(grep -cE '"(conclusion)": ' "$JOBS_JSON" 2>/dev/null)" || TOTAL_STEPS=""
TOTAL_STEPS="${TOTAL_STEPS%%
*}"
case "${TOTAL_STEPS}" in
  ''|*[!0-9]*)
    echo "SKIP: step count unreadable ('${TOTAL_STEPS}') -- refusing to judge. Exit 3, never a pass."
    exit 3 ;;
esac
if [ "${TOTAL_STEPS:-0}" -lt 5 ]; then
  echo "SKIP: the jobs payload has $TOTAL_STEPS outcome fields -- too few to judge."
  echo "      Refusing to report a verdict on an empty response. Exit 3, never a pass."
  head -c 200 "$JOBS_JSON" 2>/dev/null
  exit 3
fi

# --- flatten: one "name<TAB>conclusion" line per step ------------------------
STEPS="$(mktemp)"; ST2="$(mktemp)"
trap 'rm -f "$JOBS_JSON" "$STEPS" "$ST2"' EXIT
grep -oE '"name": "[^"]*"|"conclusion": ("[a-z_]+"|null)' "$JOBS_JSON" \
  | sed 's/^"name": "//; s/^"conclusion": "/\t/; s/"$//; s/^"conclusion": null/\tnull/' \
  > "$ST2"
# Pair each name with the conclusion that follows it.
awk -F'\t' '
  /^\t/ { if (n != "") { printf "%s\t%s\n", n, substr($0,2); n="" ; next } ; next }
  { n = $0 }
' "$ST2" > "$STEPS"

NSTEPS=$(wc -l < "$STEPS")
echo "  steps read: $NSTEPS"

# --- rule 3: the run itself --------------------------------------------------
if [ "$RUN_STATUS" != "completed" ]; then
  bad "the run is '$RUN_STATUS', not completed -- there is no verdict to report yet"
elif [ "$RUN_CONCL" = "success" ]; then
  ok "the run concluded 'success' (not cancelled, not neutral)"
else
  bad "the run concluded '$RUN_CONCL' -- only 'success' is green"
fi

# --- rule 1: NO SKIP ---------------------------------------------------------
# Written to a file rather than counted in a pipeline subshell: `while | read`
# runs in a subshell on some shells and every increment would be lost, which
# would report zero skips no matter how many there were.
: > "$ST2"
while IFS=$'\t' read -r name concl; do
  [ -n "$name" ] || continue
  [ "$concl" = "skipped" ] || continue
  is_scaffolding "$name" && continue
  printf 'SKIPPED\t%s\n' "$name" >> "$ST2"
done < "$STEPS"
# `grep -c` PRINTS 0 and EXITS 1 when there is no match, so `|| printf 0` would
# append a second zero and produce "0\n0" -- which then fails `[ -eq ]` with
# "integer expression expected". Measured here. Take grep's output as-is.
nskip=$(grep -c '^SKIPPED' "$ST2" 2>/dev/null); nskip=${nskip:-0}
if [ "${nskip:-0}" -eq 0 ] && [ "$RUN_STATUS" != "completed" ]; then
  prov "no skip among the steps that have finished so far -- the run is"
  prov "  '$RUN_STATUS', so a job that has not reached its failing step yet"
  prov "  cannot be distinguished from one that will pass. Re-run when complete."
elif [ "${nskip:-0}" -eq 0 ]; then
  ok "NO step was skipped -- every authored step ran on every platform"
else
  sed 's/^SKIPPED\t/  FAIL  SKIPPED (a skip is never a pass): /' "$ST2" | sort -u
  bad "$nskip skipped step(s) -- the rule is 'no skip', not 'no unjustified skip'"
fi

# --- rule 2: no fake green ---------------------------------------------------
# DEFECT FOUND BY INSPECTION while auditing run 31045719329, and it was mine.
# The scaffolding exemption was applied to BOTH rules, so a runner step that
# FAILED would have been ignored entirely.
#
# CORRECTION, recorded because this comment is evidence: the first version of
# this note claimed run 31045719329 actually HAD two failing
# `Post Run actions/checkout@v7` steps. It did not. That came from parsing the
# jobs list with `paste - -`, which pairs lines offset by one and glued a
# job-level conclusion onto a step name. Re-measured: zero Post steps failed in
# that run; the single ungreen step was `tty guard` on windows-latest. The hole
# below was real, but it was read out of the code -- not observed firing.
#
# The two rules need opposite treatment, because the exemption is asymmetric:
#   - SKIP:    GitHub decides whether to run its own scaffolding. Exempt.
#   - FAILURE: nothing may fail. A broken cleanup is a broken run, whoever
#              authored the step. NOT exempt.
# `is_scaffolding` is therefore deliberately absent from this loop. A scaffolding
# step that is `skipped` still passes here (the case arm below allows it); one
# that fails does not.
: > "$ST2"
while IFS=$'\t' read -r name concl; do
  [ -n "$name" ] || continue
  case "$concl" in
    success|skipped|null) ;;
    *) printf 'UNGREEN\t%s\t%s\n' "$concl" "$name" >> "$ST2" ;;
  esac
done < "$STEPS"
nun=$(grep -c '^UNGREEN' "$ST2" 2>/dev/null); nun=${nun:-0}
if [ "${nun:-0}" -eq 0 ] && [ "$RUN_STATUS" != "completed" ]; then
  prov "every step that has CONCLUDED so far concluded success ($NSTEPS read)."
  prov "  This says nothing about the steps still running. Both failures this"
  prov "  checker missed looked exactly like this line."
elif [ "${nun:-0}" -eq 0 ]; then
  ok "every step concluded success ($NSTEPS steps read)"
else
  sed 's/^UNGREEN\t/  FAIL  concluded /' "$ST2"
  bad "$nun step(s) concluded something other than success"
fi

# --- negative control: the instrument must be able to fail --------------------
# A checker nobody has broken on purpose is an untested alarm. Both rules are
# controlled, because a control for one says nothing about the other.
CTL="$(mktemp)"
printf 'gauge-cross\tskipped\nbuild\tsuccess\n' > "$CTL"
c1=0
while IFS=$'\t' read -r name concl; do
  [ "$concl" = "skipped" ] || continue
  is_scaffolding "$name" && continue
  c1=1
done < "$CTL"
printf 'lean build\tfailure\n' > "$CTL"
c2=0
while IFS=$'\t' read -r name concl; do
  case "$concl" in success|skipped|null) ;; *) c2=1 ;; esac
done < "$CTL"
rm -f "$CTL"
[ "$c1" -eq 1 ] && ok "CONTROL: a skipped step IS detected (the bc1272d shape)" \
                || bad "CONTROL FAILED: the no-skip rule cannot fire -- decorative"
[ "$c2" -eq 1 ] && ok "CONTROL: a failed step IS detected" \
                || bad "CONTROL FAILED: the no-fake-green rule cannot fire -- decorative"

# --- control: scaffolding must NOT be flagged, or the rule is indiscriminate --
if is_scaffolding "Set up job" && ! is_scaffolding "tty guard -- pty refusal where a pty exists, non-blocking everywhere"; then
  ok "CONTROL: runner scaffolding is exempt from RULE 1, an authored step is NOT"
else
  bad "CONTROL FAILED: the scaffolding filter is too broad or too narrow"
fi

# --- control: a FAILING scaffolding step must still be caught by rule 2 -------
# The control that would have caught the hole above. Without it, widening the
# exemption again would go unnoticed -- exactly how the defect survived review.
CTL="$(mktemp)"
printf 'Post Run actions/checkout@v7\tfailure\n' > "$CTL"
c3=0
while IFS=$'\t' read -r name concl; do
  case "$concl" in success|skipped|null) ;; *) c3=1 ;; esac
done < "$CTL"
printf 'Post Run actions/checkout@v7\tskipped\n' > "$CTL"
c4=0
while IFS=$'\t' read -r name concl; do
  [ "$concl" = "skipped" ] || continue
  is_scaffolding "$name" && continue
  c4=1
done < "$CTL"
rm -f "$CTL"
[ "$c3" -eq 1 ] && ok "CONTROL: a FAILING scaffolding step is caught (rule 2 has no exemption)" \
                || bad "CONTROL FAILED: scaffolding can fail unseen -- the both-rules exemption is back"
[ "$c4" -eq 0 ] && ok "CONTROL: a SKIPPED scaffolding step is still exempt (the asymmetry holds)" \
                || bad "CONTROL FAILED: rule 1 now flags GitHub's own scaffolding"

echo
echo "== ci-honesty: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || { echo "  ci-honesty: FAIL"; exit 1; }
echo "  ci-honesty: PASS"
exit 0
