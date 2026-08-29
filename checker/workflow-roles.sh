#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# WORKFLOW ROLES -- four files, two roles, and the difference between a workflow
# that RUNS and a workflow that WORKS.
#
# `lean/Proofs/RotWorkflowRoles.lean` proves the rules. This binds them to the
# YAML on disk and to the runs the API reports, because a theorem about a record
# proves nothing about a file until something reads the file.
#
# THE DEFECT THIS EXISTS FOR, measured through the API on 2026-08-11:
#
#     workflow          newest run          youngest green
#     tag-manager.yml   success  20.4 h      20.4 h
#     ads-manager.yml   FAILURE  19.3 h     173.5 h
#
# By the obvious freshness test -- has it run lately -- the docs manager was the
# HEALTHIEST workflow in the repository. It had been red for seven days and the
# documents it maintains had not moved. `a_workflow_that_runs_is_not_a_workflow_
# that_works` decides that gap; `green_freshness_is_strictly_stronger` proves
# that measuring the youngest GREEN run rejects everything the naive test
# rejected and more, so this is a strengthening and not a swap.
#
# WHY IT MATTERS BEYOND ONE RED JOB: the two managers are the only thing that
# touches this repository between commits. Dependabot cannot do that job -- its
# single ecosystem here is `github-actions` at `directory: "/"`, which edits
# workflow files, i.e. exclusively CODE GATES. There is no key that scopes it to
# named files (`ignore` filters by dependency name, never by path), so document
# freshness is the cron managers' responsibility and nobody else's.
#
# EXIT CODES
#   0  every rule that could be measured held
#   1  a rule was broken
#   3  SKIP -- the API half could not be measured (no token, no network). A skip
#      is never a pass anywhere in this repository.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

pass=0; fail=0; skipped=0
ok()   { echo "  PASS  $*"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=workflow-roles::%s\n' "$*"; fail=$((fail+1)); }
skip() { echo "  SKIP  $*"; skipped=$((skipped+1)); }

echo "== workflow roles: code gates and documentation managers =="

WFDIR=.github/workflows
[ -d "$WFDIR" ] || { echo "FATAL: $WFDIR absent -- refusing to report on workflows I cannot read"; exit 1; }

# --- ROLE DECLARATION -------------------------------------------------------
# The split is declared HERE and checked against the tree, rather than inferred
# from a filename. An inferred role silently reclassifies a workflow the day
# someone renames it, which is the same stale-snapshot defect this repo keeps
# finding in its own counters.
#
# `corpus-update.yml` is a CODE GATE, not a docs manager, and the distinction is
# load-bearing: it runs `repo-complete.sh` and `release-package.sh`, so it can
# FAIL a corpus commit that would have shipped an empty `Lean Theorem/`. A gate
# that can go red on real content belongs with the gates. It holds only
# `contents: read`, which is what the code-gate rule below requires.
# `ci2.yml` is the INDEPENDENT COLD RUNNER -- parallel to ci.yml, never a
# caller of it, `contents: read` only. It re-runs the gates from a cold
# clone, so it is a CODE GATE by the same rule as ci.yml.
CODE_GATES="ci.yml verify.yml corpus-update.yml ci2.yml"
DOCS_MANAGERS="ads-manager.yml tag-manager.yml"

# Every workflow on disk must be classified. A file nobody assigned a role to is
# a file nobody is checking -- and it would pass this checker by being invisible.
declared=" $CODE_GATES $DOCS_MANAGERS "
unclassified=0
for f in "$WFDIR"/*.yml; do
  b=$(basename "$f")
  case "$declared" in
    *" $b "*) : ;;
    *) bad "$b has no declared role -- classify it in checker/workflow-roles.sh or it is checked by nothing"
       unclassified=$((unclassified + 1)) ;;
  esac
done
[ "$unclassified" -eq 0 ] && ok "every workflow on disk carries a declared role"

# The declaration must not name a file that is gone, or the rules below would
# vacuously hold over an empty set.
for b in $CODE_GATES $DOCS_MANAGERS; do
  [ -f "$WFDIR/$b" ] || bad "$b is declared but absent from $WFDIR -- the rules for it would be vacuous"
done

# --- STATIC HALF: what a documentation manager is allowed to touch -----------
# `roleRespected` in the Lean model. The allowlist is kept identical to
# `docsAllowlist` there; a_docs_manager_may_not_write_to_the_proofs and
# a_docs_manager_may_not_write_to_the_router are the theorems this enforces.
FORBIDDEN_PATHS='lean/|hooks/|checker/|\.claude-plugin/|scripts/'
for b in $DOCS_MANAGERS; do
  f="$WFDIR/$b"
  # A doc manager may READ anything -- checking out the tree is not writing to
  # it. Only committing or force-adding a forbidden path is a role violation, so
  # the pattern is anchored on the write verbs rather than on a bare mention.
  hits=$(grep -nE "git (add|commit)[^|;]*($FORBIDDEN_PATHS)" "$f" | grep -v '^\s*#' || true)
  if [ -n "$hits" ]; then
    bad "$b writes outside the documentation allowlist:"; printf '        %s\n' "$hits"
  else
    ok "$b writes no path under lean/, hooks/, checker/ or .claude-plugin/"
  fi
done

# A code gate must not hold `contents: write` at the top level. verify.yml does,
# and legitimately -- it commits STATUS.md when the verdict changes -- so the
# rule is stated as: a code gate with write access must say in the file why.
for b in $CODE_GATES; do
  f="$WFDIR/$b"
  if grep -qE '^\s*contents:\s*write' "$f"; then
    if grep -qiE '#.*(only to commit|STATUS\.md)' "$f"; then
      ok "$b holds contents: write and documents the single reason in the file"
    else
      bad "$b holds contents: write with no stated reason -- a code gate that can push is not a gate"
    fi
  else
    ok "$b holds no top-level contents: write"
  fi
done

# --- SCHEDULES: a manager with no cron cannot keep anything fresh ------------
for b in $DOCS_MANAGERS; do
  if grep -qE '^\s*-\s*cron:' "$WFDIR/$b"; then
    ok "$b is scheduled ($(grep -oE 'cron: *"[^"]*"' "$WFDIR/$b" | head -1))"
  else
    bad "$b has no cron -- it cannot keep the repository fresh between commits"
  fi
done

# --- API HALF: youngest GREEN run, never newest run --------------------------
# This is the half the Lean model is really about. It needs the network, and
# when it cannot run it SKIPS rather than passing.
BOUND_HOURS=${WFROLE_BOUND_HOURS:-72}
TOK=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | sed -n 's/^password=//p')
SLUG=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]##; s/\.git$//')

if [ -z "${TOK:-}" ] || [ -z "${SLUG:-}" ]; then
  skip "no credential or no origin -- the freshness half could not be measured (this is 'could not measure', NOT 'the workflows are fresh')"
else
  now=$(date -u +%s)
  for b in $CODE_GATES $DOCS_MANAGERS; do
    body=$(curl -s --max-time 25 -H "Authorization: Bearer $TOK" \
             -H "Accept: application/vnd.github+json" \
             "https://api.github.com/repos/$SLUG/actions/workflows/$b/runs?per_page=20" 2>/dev/null)
    if [ -z "$body" ]; then
      skip "$b: empty API response -- not measured"
      continue
    fi
    # Two ages, deliberately: the naive one and the honest one. Printing both is
    # what makes the difference visible in the log instead of asserted here.
    # The REF of the green run is reported, not just its age. A workflow can be
    # made green on a side branch, which proves the workflow works but says
    # nothing about the state of `main` -- and a log that hides which one it was
    # invites exactly that confusion.
    # A FOURTH FIELD: THE NEWEST RUN'S CONCLUSION. Age alone cannot tell a
    # workflow that FAILED from one whose run a human CANCELLED, and those are
    # opposite findings -- see the cancelled branch below.
    read -r newest green gref nconc <<EOF
$(printf '%s' "$body" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  let j; try { j = JSON.parse(s); } catch (e) { console.log("ERR ERR ERR ERR"); return; }
  const r=j.workflow_runs||[];
  if(!r.length){ console.log("NONE NONE NONE NONE"); return; }
  const age=x=>Math.round((Date.now()-Date.parse(x.created_at))/3600000);
  const g=r.find(x=>x.conclusion==="success");
  console.log(age(r[0]), g?age(g):"NONE", g?(g.head_branch||"?"):"NONE", r[0].conclusion||"in_progress");
});' 2>/dev/null)
EOF
    if [ "${newest:-ERR}" = "ERR" ] || [ -z "${newest:-}" ]; then
      skip "$b: API body was not JSON -- not measured"
      continue
    fi
    if [ "$green" = "NONE" ]; then
      # A workflow that has never succeeded is usually broken -- but NOT when it
      # has never had the CHANCE. A workflow added in the very commit being
      # checked has no runs by construction, and the old rule made that state
      # unreachable: it could not be pushed until green, and could not be green
      # until pushed. That is a spec forbidding a correct future, not a defect
      # in the change, and the repair is to distinguish the two cases rather
      # than to weaken the rule.
      #
      # NOT-ON-THE-REMOTE is the discriminator, and it is measured, not assumed:
      # if origin/main does not carry this file, GitHub has never seen it, so
      # "no green run" is the only possible state and says nothing about health.
      # The moment it is pushed the normal rule applies with no exemption left
      # behind -- this cannot silently excuse a workflow that later starts
      # failing, because by then the file IS on the remote.
      #
      # `git ls-tree`, NOT `git cat-file -e origin/main:<path>`. On Git Bash the
      # `rev:path` syntax is destroyed by MSYS2 path conversion -- measured, the
      # argument arrived as `origin\main;.github\workflows\ci.yml` and every
      # lookup returned 128. Read as "absent", that would have exempted ALL FIVE
      # workflows, including ones long present on the remote: a false green born
      # from a lookup that could not distinguish "not there" from "I could not
      # ask". `ls-tree` takes the ref and the path as separate arguments.
      #
      # AND NOT `| grep -qx` EITHER. Under `set -o pipefail`, grep -q exits the
      # moment it matches, SIGPIPEs the writer, and the pipeline reports 141 --
      # so a MATCH would read as a failure. workflow-lint caught exactly that in
      # the first version of this block. Capture, then match with `case`: no
      # pipe, no signal, and the newline guards make it a whole-line compare.
      # `-r` IS LOAD-BEARING. Without it, `git ls-tree` handed a directory
      # prints the TREE ENTRY -- one line, ".github/workflows" -- and not the
      # files inside it. The needle below is a full path, so it then matches
      # NOTHING, every workflow is classified NEW, and every staleness rule in
      # this file is silently exempted. Measured 2026-08-14: the bare form
      # returned exactly one line, while `-r` returned all five workflows.
      #
      # It looked healthy because an established workflow PASSES on its run
      # history before ever reaching this branch -- only a workflow with no
      # green run gets here, so the bug stayed masked behind a correct verdict.
      # This is the SECOND lookup in this block to fail by answering a question
      # nobody asked: the first was `git cat-file -e origin/main:<path>`, which
      # MSYS2 mangled to `origin\main;...` and exit 128. Both times the failure
      # read as "absent", which is the direction that exempts rather than the
      # direction that complains -- an instrument that cannot tell "I could not
      # look" from "it is not there" fails toward the false green.
      _remote_wf="$(git ls-tree -r --name-only origin/main -- "$WFDIR" 2>/dev/null)"
      case "
$_remote_wf
" in
        *"
$WFDIR/$b
"*) _on_remote=1 ;;
        *)  _on_remote=0 ;;
      esac
      # THE LOOKUP MUST PROVE IT WORKED BEFORE ITS ANSWER IS TRUSTED. Both bugs
      # above produced an EMPTY-or-useless listing that read as "absent", and
      # both would have been caught in one line by asking: did this lookup see
      # ANY workflow at all? If it did not, the instrument is broken and the
      # honest verdict is a failure, not an exemption. An exemption granted on
      # the strength of a lookup that returned nothing is not a measurement.
      case "$_remote_wf" in
        *"$WFDIR/"*) : ;;
        *) bad "$b: the origin/main workflow listing came back with NO workflows at all -- the lookup is broken, refusing to grant a NEW-file exemption on it"
           continue ;;
      esac
      if [ "$_on_remote" -eq 0 ]; then
        skip "$b is NEW (absent from origin/main) -- it has had no chance to run; the rule applies once pushed"
        continue
      fi
      # THE RUN HISTORY DESCRIBES THE FILE ON THE REMOTE, NOT THE ONE IN HAND.
      # If the local copy differs from origin/main's, those failures were
      # produced by DIFFERENT CODE, and holding them against the version being
      # committed judges the wrong artifact. Without this, a workflow that is
      # broken on the remote can never be repaired: the repair IS the workflow
      # file, so it cannot be committed while the gate is red, and the gate
      # cannot go green until the repair is pushed and runs. That is the same
      # "spec forbids a correct future" defect as the NEW-file case above, one
      # step later in the file's life.
      #
      # Deliberately narrow, because this is the direction that exempts:
      #   * it is a SKIP, never a PASS -- nothing here claims the repair works;
      #   * it lapses the moment the file is pushed, since local and remote
      #     match again and the plain rule returns with no exemption left;
      #   * it cannot hide a workflow that is merely stale, only one with NO
      #     green run at all that is being actively rewritten in this commit.
      # `git ls-tree`, not `rev:path` -- MSYS2 mangling, see the note above.
      _loc_sha=$(git hash-object "$WFDIR/$b" 2>/dev/null)
      _rem_sha=$(git ls-tree -r origin/main -- "$WFDIR/$b" 2>/dev/null | awk '{print $3}')
      if [ -n "$_loc_sha" ] && [ -n "$_rem_sha" ] && [ "$_loc_sha" != "$_rem_sha" ]; then
        skip "$b has never succeeded, but the local file DIFFERS from origin/main -- those runs tested the old copy; this is an untested repair, not a healthy workflow"
        continue
      fi
      bad "$b has NEVER succeeded (newest run ${newest}h old) -- running is not working"
      continue
    fi
    if [ "$green" -le "$BOUND_HOURS" ]; then
      ok "$b youngest GREEN run is ${green}h old on ${gref} (newest run ${newest}h, bound ${BOUND_HOURS}h)"
    else
      # THE SAME TWO ARGUMENTS AS THE never-succeeded BRANCH, ONE STEP LATER IN
      # A WORKFLOW'S LIFE. Both were already written above for a workflow with
      # NO green run; a workflow with a STALE green run fell straight through to
      # `bad`, and that is how this gate deadlocked. MEASURED 2026-08-22:
      # ads-manager.yml was red here at 75h while the local file carried the
      # repair for the very failure being counted, and the repair could not be
      # committed because this gate was red -- "spec forbids a correct future",
      # the third time in this file.
      #
      # 1. LOCAL DIFFERS FROM REMOTE. The stale green describes the copy on the
      #    remote; the file in hand is a different artifact and has no run
      #    history at all. Judging it by those runs judges the wrong file. SKIP,
      #    never PASS, and it lapses the instant the file is pushed.
      _loc_sha2=$(git hash-object "$WFDIR/$b" 2>/dev/null)
      _rem_sha2=$(git ls-tree -r origin/main -- "$WFDIR/$b" 2>/dev/null | awk '{print $3}')
      if [ -n "$_loc_sha2" ] && [ -n "$_rem_sha2" ] && [ "$_loc_sha2" != "$_rem_sha2" ]; then
        skip "$b's youngest GREEN run is ${green}h old, but the local file DIFFERS from origin/main -- that verdict describes the old copy; this is an untested repair, not a healthy workflow"
      elif [ "${nconc:-}" = "cancelled" ]; then
        # 2. THE NEWEST RUN WAS CANCELLED. A cancellation is an operator action,
        #    not a verdict about the code -- it is absence of evidence, and
        #    reading it as a failure is the exact mirror of the "it ran, so it
        #    is healthy" error this whole half exists to reject. The honest
        #    word for it is "not measured". MEASURED 2026-08-22: verify.yml's
        #    newest run (125h) was cancelled, so main carries a commit with no
        #    verify verdict at all -- which a FAIL here would have misreported
        #    as a broken workflow.
        skip "$b's youngest GREEN run is ${green}h old and its newest run (${newest}h) was CANCELLED -- a cancellation carries no verdict, so this is NOT MEASURED rather than broken"
      else
        bad "$b youngest GREEN run is ${green}h old on ${gref}, over the ${BOUND_HOURS}h bound -- its newest run is only ${newest}h old (${nconc:-unknown}), so 'it ran' would have called this healthy"
      fi
    fi
  done
fi

# --- NEGATIVE CONTROL -------------------------------------------------------
# Every rule above must be able to fail. An alarm nobody has tripped on purpose
# is an untested alarm, and this file exists because one such alarm was believed
# for seven days.
CTL=$(mktemp -d)
printf 'jobs:\n  x:\n    steps:\n      - run: git add lean/Proofs/RotGauge.lean\n' > "$CTL/bad.yml"
if grep -qE "git (add|commit)[^|;]*($FORBIDDEN_PATHS)" "$CTL/bad.yml"; then
  ok "CONTROL: a manager writing into lean/Proofs is detected"
else
  bad "CONTROL FAILED: the forbidden-path rule does not fire on a workflow that writes lean/Proofs -- it is decoration"
fi
printf 'jobs:\n  x:\n    steps:\n      - run: git add README.md\n' > "$CTL/good.yml"
if grep -qE "git (add|commit)[^|;]*($FORBIDDEN_PATHS)" "$CTL/good.yml"; then
  bad "CONTROL FAILED: the forbidden-path rule fires on a workflow that only writes README.md -- it would block a correct change"
else
  ok "CONTROL: a manager writing only README.md is accepted"
fi
# The freshness comparison, controlled on the numbers that actually occurred.
_n=19; _g=173; _b=48
if [ "$_n" -le "$_b" ] && [ "$_g" -gt "$_b" ]; then
  ok "CONTROL: the measured 19h/173h pair is accepted by 'it ran' and refused by 'it succeeded'"
else
  bad "CONTROL FAILED: the two freshness tests no longer disagree on the pair that motivated them"
fi
# THE TWO STALE-GREEN EXEMPTIONS, CONTROLLED IN THE DIRECTION THAT MATTERS.
# Both branches added 2026-08-22 EXEMPT, which is the direction that can hide a
# real failure, so the thing to prove is not that they fire -- both fired live
# on this repo -- but that they DO NOT fire on the plain broken case: a stale
# green whose file matches the remote and whose newest run genuinely FAILED.
# The decision is replayed here on fixed inputs, so it is checked even on a run
# where the API half skipped entirely and no workflow reached that code.
_decide () {
  # $1 local sha, $2 remote sha, $3 newest conclusion -> prints the verdict word
  if [ -n "$1" ] && [ -n "$2" ] && [ "$1" != "$2" ]; then echo skip_differs
  elif [ "$3" = "cancelled" ]; then echo skip_cancelled
  else echo bad
  fi
}
_c1=$(_decide aaa bbb failure)      # differs        -> exempt
_c2=$(_decide aaa aaa cancelled)    # same+cancelled -> exempt
_c3=$(_decide aaa aaa failure)      # same+failed    -> MUST still fail
_c4=$(_decide "" "" failure)        # unmeasurable shas -> MUST still fail
if [ "$_c1" = "skip_differs" ] && [ "$_c2" = "skip_cancelled" ] && [ "$_c3" = "bad" ] && [ "$_c4" = "bad" ]; then
  ok "CONTROL: the stale-green exemptions cover 'file differs' and 'cancelled' ONLY -- a matching file with a FAILED newest run still fails"
else
  bad "CONTROL FAILED: the stale-green exemption logic misclassifies ($_c1/$_c2/$_c3/$_c4) -- it can now excuse a genuinely broken workflow"
fi
rm -rf "$CTL"

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed, $skipped skipped"
if [ "$fail" -gt 0 ]; then
  echo "  workflow-roles: FAIL"
  exit 1
fi
if [ "$skipped" -gt 0 ]; then
  echo "  workflow-roles: PARTIAL -- $skipped rule(s) could not be measured."
  echo "  A skip is not a pass. Exit 3."
  exit 3
fi
echo "  workflow-roles: PASS"
exit 0
