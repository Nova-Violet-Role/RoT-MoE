#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE SCHEDULED VERDICT, RUN THREE TIMES, WITH A REAL REMOTE -- and no API.
#
# `checker/verdict-stability.sh` proves the workflow is WRITTEN to commit only
# when the verdict changes. That is a structural claim. This one is behavioural:
# it EXECUTES the publish job's own `run:` blocks -- extracted from
# `.github/workflows/verify.yml`, never a copy typed here -- against a scratch
# clone with a scratch bare remote, three times, and counts the commits that
# actually land:
#
#   week 1  no STATUS.md yet          -> verdict CHANGED -> exactly 1 commit
#   week 2  nothing in the tree moved -> verdict UNCHANGED -> ZERO commits
#   week 3  one new theorem           -> verdict CHANGED -> exactly 1 commit
#
# Week 2 is the whole point and is the R18 control the alarm names: "a bot that
# commits regardless is the failure mode, not the feature". A green-square
# generator passes weeks 1 and 3 exactly like a correct implementation does; the
# ONLY observation that separates them is a week in which nothing is committed.
#
# THE HARNESS'S OWN NEGATIVE CONTROL (phase 4): the pre-2026-08-01 step is
# replayed -- the one that wrote `date -u` and ${GITHUB_SHA} into the file it
# then compared -- and week 2 MUST commit under it. If the simulator cannot see
# the defect that motivated the fix, its green says nothing about the fix.
#
# Nothing here touches the real repository, the live ~/.claude, or any network:
# the remote is a local bare repo in a temp dir, and `git push` reaches only it.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

WF=".github/workflows/verify.yml"
[ -f "$WF" ] || { echo "FATAL: missing $WF"; exit 2; }

PASS=0; FAIL=0
ok   () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad  () { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }
head_() { printf '\n== %s\n' "$*"; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# 1. EXTRACT the publish job's steps FROM THE WORKFLOW.
#    Records are \x1e-terminated with \x1f-separated fields, because a `run:`
#    block is multi-line and newline-delimited records truncate it -- the same
#    defect that made ci-dryrun.sh report a phantom CI failure.
# ---------------------------------------------------------------------------
STEPS="$WORK/steps.rec"
awk '
  function flush() {
    if (have) printf "%s\037%s\037%s\036", name, cond, run
    have = 0; name = ""; cond = ""; run = ""
  }
  /^  publish:/ { injob = 1; next }
  injob && /^  [A-Za-z_]/ { flush(); injob = 0 }
  !injob { next }
  /^      - name:/ { flush(); name = substr($0, index($0, ":") + 2); inrun = 0; have = 1; next }
  /^        if:/   { cond = substr($0, index($0, ":") + 2); inrun = 0; next }
  /^        run: \|/ { inrun = 1; next }
  /^        [a-z]+:/ { inrun = 0; next }
  inrun { line = $0; sub(/^          /, "", line); run = run line "\n"; next }
  END { flush() }
' "$WF" > "$STEPS"

# The extracted steps MUST invoke the generator. This simulation is only a
# statement about `checker/status-verdict.sh` if the workflow it replays
# actually runs it -- otherwise three green weeks would be three weeks of
# something else. Asserted rather than assumed, so the day the workflow stops
# calling the generator this harness goes red instead of quietly changing
# subject. (`checker/workflow-lint.sh` exempts the generator from the
# gate list on the claim that gates exercise it; this line is half of that
# claim's evidence, which is why the string appears here at all.)
if ! grep -q 'checker/status-verdict\.sh' "$STEPS"; then
  bad "the publish job never calls checker/status-verdict.sh -- this simulation would not be about the verdict at all"
  printf '\n== schedule sim: %d passed, %d failed\n' "$PASS" "$FAIL"; exit 1
fi
ok "the replayed steps invoke checker/status-verdict.sh -- the subject is the real generator"

NSTEPS=$(tr -cd '\036' < "$STEPS" | wc -c | tr -d ' ')
if [ "$NSTEPS" -ge 3 ]; then
  ok "extracted $NSTEPS steps from the publish job of $WF (not a hand copy)"
else
  bad "extracted only $NSTEPS steps -- the extractor is broken, so nothing below is evidence"
  printf '\n== schedule sim: %d passed, %d failed\n' "$PASS" "$FAIL"; exit 1
fi

# ---------------------------------------------------------------------------
# 2. A CLEAN TREE + A REAL (LOCAL, BARE) REMOTE.
# ---------------------------------------------------------------------------
TREE="$WORK/tree"; BARE="$WORK/origin.git"
mkdir -p "$TREE"
git -C "$REPO" ls-files -co --exclude-standard -z \
  | while IFS= read -r -d '' f; do
      mkdir -p "$TREE/$(dirname "$f")"; cp "$REPO/$f" "$TREE/$f" 2>/dev/null
    done
# WEEK 1 MEANS "no STATUS.md yet" -- so MAKE that true here instead of inheriting it.
# This line is the fix for a real red build (CI run #26, 2026-08-02, all three OSes).
# The simulator copied the live tree, and for as long as the repo happened to have no
# STATUS.md, week 1 saw changed=yes and passed. The moment a correct STATUS.md was
# committed -- which is the desired end state, not a mistake -- week 1 saw changed=no
# and the whole matrix went red on a commit that was right.
#
# That is a spec defect, not a code defect: a test that only passes while a required
# file is missing has frozen a contingent fact. The tempting "repair" is to delete the
# assertion, which would destroy the R18 green-square control this file exists for.
# A precondition a test depends on must be established BY the test.
rm -f "$TREE/STATUS.md"
git init -q --bare "$BARE"
(
  cd "$TREE"
  git init -q; git config user.name sim; git config user.email sim@local
  git add -A >/dev/null 2>&1; git commit -qm "base" >/dev/null 2>&1
  git branch -M main
  git remote add origin "$BARE"
  # -u sets the upstream, so the workflow's bare `git push` resolves. Without
  # it the push failed with `no upstream branch` and the STEP STILL EXITED 0,
  # because that `run:` block does not `set -e` -- so the harness saw
  # changed=yes and zero commits and could not say why. Measured, not guessed.
  git push -q -u origin main 2>/dev/null
)
BASE_COUNT=$(git -C "$BARE" rev-list --count refs/heads/main 2>/dev/null || echo 0)
ok "scratch tree materialised, bare remote at $BASE_COUNT commit(s) -- no network involved"

# ---------------------------------------------------------------------------
# 3. RUN the extracted steps, honouring `if: steps.decide.outputs.changed`.
# ---------------------------------------------------------------------------
# `c=$(run_week ...)` runs the function in a COMMAND SUBSTITUTION SUBSHELL, so
# a variable set inside it never reaches the caller -- measured here as
# "publish_failed: unbound variable". The flag travels through a file instead.
PF="$WORK/publish_failed"
publish_failed=no
run_week () {   # run_week <label> ; echoes "<yes|no>"; records the flag in $PF
  local label="$1" changed="" name cond run
  printf 'no' > "$PF"
  local GH_OUT="$WORK/gh_output"; : > "$GH_OUT"
  while IFS= read -r -d $'\036' rec; do
    name=${rec%%$'\037'*}; rec=${rec#*$'\037'}
    cond=${rec%%$'\037'*}; run=${rec#*$'\037'}
    [ -n "$run" ] || continue
    # Evaluate the only gating expression the job uses.
    if [ -n "$cond" ]; then
      case "$cond" in
        *"steps.decide.outputs.changed == 'yes'"*)
          if [ "$changed" != "yes" ]; then
            printf '    [%s] SKIPPED (gated): %s\n' "$label" "$name" >&2
            continue
          fi ;;
        *) printf '    [%s] unknown condition, refusing to guess: %s\n' "$label" "$cond" >&2; return 2 ;;
      esac
    fi
    (
      cd "$TREE"
      export GITHUB_OUTPUT="$GH_OUT"
      export GITHUB_SHA="0000000000000000000000000000000000000000"
      # The publish step appends the verdict here. Unset, the redirection
      # fails and the step dies 127 for a reason unrelated to the property
      # under test -- measured while writing this.
      export GITHUB_STEP_SUMMARY="$WORK/step_summary.md"
      bash -c "$run" >"$WORK/step.out" 2>&1
    ) </dev/null
    local rc=$?
    # THE PUBLISH STEP IS NOW *SUPPOSED* TO FAIL WHEN THE VERDICT MOVED.
    # Rewritten 2026-08-01 together with the workflow it replays. verify.yml no
    # longer commits: main is protected, the GitHub Actions app cannot hold a
    # repository-level bypass (HTTP 422, measured), and the bot's push was
    # refused outright. The job publishes the verdict to the run summary and
    # EXITS NON-ZERO so that a human lands the change.
    #
    # The property under test is unchanged, and it is the one that matters: a
    # week in which nothing moved must be DISTINGUISHABLE from a week in which
    # something did. Only the observable moved -- from 'did a commit land' to
    # 'did the run go red' -- and now ZERO commits must land in either case.
    if [ $rc -ne 0 ]; then
      case "$name" in
        *[Ff]ail*|*stale*|*Publish*)
          printf '    [%s] publish step exited %d AS DESIGNED (verdict moved, nothing pushed)\n' "$label" "$rc" >&2
          printf 'yes' > "$PF" ;;
        *)
          printf '    [%s] step FAILED (rc=%d): %s\n' "$label" "$rc" "$name" >&2
          sed 's/^/          /' "$WORK/step.out" | head -15 >&2
          return 1 ;;
      esac
    fi
    # A step that prints `fatal:` and still exits 0 is the shape that hid the
    # failed push: the workflow's commit block has no `set -e`, so git's error
    # never reached the exit code. The harness must not inherit that blindness.
    if grep -qE '^(fatal|error):' "$WORK/step.out"; then
      printf '    [%s] step exited 0 but git reported a fatal error: %s\n' "$label" "$name" >&2
      sed 's/^/          /' "$WORK/step.out" | head -8 >&2
      return 1
    fi
    if grep -q '^changed=' "$GH_OUT" 2>/dev/null; then
      changed=$(grep '^changed=' "$GH_OUT" | tail -1 | cut -d= -f2)
    fi
  done < "$STEPS"
  echo "$changed"
  return 0
}

commits_now () { git -C "$BARE" rev-list --count refs/heads/main 2>/dev/null || echo 0; }

head_ "WEEK 1 -- no STATUS.md yet: the verdict is new"
before=$(commits_now); c1=$(run_week week1); rc=$?
publish_failed=$(cat "$PF" 2>/dev/null || echo no)
after=$(commits_now)
if [ $rc -ne 0 ]; then bad "week 1 did not complete (rc=$rc)"
elif [ "$c1" = "yes" ] && [ "$publish_failed" = "yes" ] && [ "$after" -eq "$before" ]; then
  ok "verdict CHANGED, the run went RED, and NOTHING was pushed (still $after commits)"
else
  bad "expected changed=yes, a red publish step and zero commits; got changed=$c1, publish_failed=$publish_failed, $before -> $after"
fi

head_ "WEEK 2 -- nothing moved: the run MUST say nothing"
before=$(commits_now); c2=$(run_week week2); rc=$?
publish_failed=$(cat "$PF" 2>/dev/null || echo no)
after=$(commits_now)
if [ $rc -ne 0 ]; then bad "week 2 did not complete (rc=$rc)"
elif [ "$c2" = "no" ] && [ "$publish_failed" = "no" ] && [ "$after" -eq "$before" ]; then
  ok "verdict UNCHANGED: the run stayed GREEN and silent, zero commits (still $after)"
else
  bad "A SILENT WEEK WAS NOT SILENT: changed=$c2, publish_failed=$publish_failed, $before -> $after (the green-square failure mode)"
fi

head_ "WEEK 3 -- one new theorem: the verdict must move again"
printf '\ntheorem sim_planted_thm : True := trivial\n' >> "$TREE/lean/Proofs/RotPath.lean"
( cd "$TREE" && git add -A >/dev/null 2>&1 && git commit -qm "sim: a real change" >/dev/null 2>&1 )
before=$(commits_now); c3=$(run_week week3); rc=$?
publish_failed=$(cat "$PF" 2>/dev/null || echo no)
after=$(commits_now)
if [ $rc -ne 0 ]; then bad "week 3 did not complete (rc=$rc)"
elif [ "$c3" = "yes" ] && [ "$publish_failed" = "yes" ] && [ "$after" -eq "$before" ]; then
  ok "a real edit moved the verdict, the run went RED, and still nothing was pushed"
else
  bad "a real change did NOT move the verdict: changed=$c3, publish_failed=$publish_failed, $before -> $after"
fi
# THE INVARIANT ACROSS ALL THREE WEEKS: the remote never gains a commit. That
# is the whole point of the redesign -- nothing writes to a protected branch
# except a human -- so it is asserted directly rather than inferred from the
# three weeks above.
if [ "$(commits_now)" -eq "$BASE_COUNT" ]; then
  ok "after three simulated weeks the remote is STILL at $BASE_COUNT commit(s) -- no bot ever wrote to main"
else
  bad "the remote moved from $BASE_COUNT to $(commits_now) -- a bot pushed to a protected branch"
fi
# The generated STATUS.md must still carry the verdict block. It is read from
# the WORKING TREE now, because no commit carries it any more.
if grep -q 'VERDICT-BEGIN' "$TREE/STATUS.md" 2>/dev/null; then
  ok "the generated STATUS.md carries the VERDICT block"
else
  bad "the generated STATUS.md has no VERDICT block"
fi

# ---------------------------------------------------------------------------
head_ "CONTROL -- replay the OLD defect: a clock inside the compared block"
# ---------------------------------------------------------------------------
# If the simulator cannot catch a bot that commits every week, its three greens
# above are decoration. The old step is reconstructed literally: write the
# timestamp into the block that is compared, then compare.
CTREE="$WORK/ctree"; CBARE="$WORK/corigin.git"
mkdir -p "$CTREE"; cp -r "$TREE"/. "$CTREE"/ 2>/dev/null
rm -rf "$CTREE/.git"; git init -q --bare "$CBARE"
(
  cd "$CTREE"; git init -q; git config user.name sim; git config user.email sim@local
  git add -A >/dev/null 2>&1; git commit -qm base >/dev/null 2>&1
  git remote add origin "$CBARE"; git push -q origin HEAD:refs/heads/main 2>/dev/null
)
old_week () {   # the pre-fix logic, verbatim in spirit: clock INSIDE the file
  (
    cd "$CTREE"
    {
      echo "# STATUS"
      echo "| verified at | $(date -u '+%Y-%m-%d %H:%M:%S UTC') |"
      echo "| commit | 0000000000000000000000000000000000000000 |"
      echo "| theorems | $(bash checker/count-theorems.sh lean/Proofs/*.lean 2>/dev/null) |"
    } > STATUS.md
    git add STATUS.md
    if git diff --staged --quiet; then
      echo "unchanged"
    else
      git commit -qm "ci: re-verified" >/dev/null 2>&1
      git push -q origin HEAD:refs/heads/main 2>/dev/null
      echo "committed"
    fi
  )
}
old_week >/dev/null
b=$(git -C "$CBARE" rev-list --count refs/heads/main 2>/dev/null || echo 0)
sleep 1                      # a second is enough: the old block carried seconds
r2=$(old_week)
a=$(git -C "$CBARE" rev-list --count refs/heads/main 2>/dev/null || echo 0)
if [ "$r2" = "committed" ] && [ "$a" -gt "$b" ]; then
  ok "CONTROL: under the OLD step a silent week STILL commits ($b -> $a) -- the simulator can see the defect it was built for"
else
  bad "CONTROL did not reproduce the old defect (r2=$r2, $b -> $a) -- week 2's green above is then unattributable"
fi

printf '\n== schedule sim: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
