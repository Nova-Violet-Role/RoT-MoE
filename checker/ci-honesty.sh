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
    RUN_ID="$(api "https://api.github.com/repos/$REPO/actions/runs?head_sha=$HEAD_SHA&per_page=1" \
              | grep -oE '"id": [0-9]+' | head -1 | grep -oE '[0-9]+')"
    if [ -z "$RUN_ID" ]; then
      echo "SKIP: no CI run exists for HEAD ($HEAD_SHA)."
      echo "      This commit has not been pushed, so there is no run to judge."
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
TOTAL_STEPS="$(grep -cE '"(conclusion)": ' "$JOBS_JSON" 2>/dev/null || echo 0)"
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
if [ "${nskip:-0}" -eq 0 ]; then
  ok "NO step was skipped -- every authored step ran on every platform"
else
  sed 's/^SKIPPED\t/  FAIL  SKIPPED (a skip is never a pass): /' "$ST2" | sort -u
  bad "$nskip skipped step(s) -- the rule is 'no skip', not 'no unjustified skip'"
fi

# --- rule 2: no fake green ---------------------------------------------------
: > "$ST2"
while IFS=$'\t' read -r name concl; do
  [ -n "$name" ] || continue
  is_scaffolding "$name" && continue
  case "$concl" in
    success|skipped|null) ;;
    *) printf 'UNGREEN\t%s\t%s\n' "$concl" "$name" >> "$ST2" ;;
  esac
done < "$STEPS"
nun=$(grep -c '^UNGREEN' "$ST2" 2>/dev/null); nun=${nun:-0}
if [ "${nun:-0}" -eq 0 ]; then
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
if is_scaffolding "Set up job" && ! is_scaffolding "tty guard -- the router must not block on a terminal"; then
  ok "CONTROL: runner scaffolding is exempt, an authored step is NOT"
else
  bad "CONTROL FAILED: the scaffolding filter is too broad or too narrow"
fi

echo
echo "== ci-honesty: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || { echo "  ci-honesty: FAIL"; exit 1; }
echo "  ci-honesty: PASS"
exit 0
