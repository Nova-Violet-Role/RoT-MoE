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
bad() { echo "  FAIL  $*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=workflow-lint::%s\n' "$*"; fail=$((fail+1)); }

echo "== workflow lint =="

# --- 1. do they parse? ------------------------------------------------------
#
# THE DETECTION USED TO BE COMPUTED AND THEN IGNORED. `YAML_OK=1` meant "node
# can require js-yaml locally", but every parse below still went through
# `npx --yes`, which re-resolves against the registry on EVERY call. Measured
# 2026-08-06: six such calls took the gate from seconds to over 300 s and it
# was killed at the harness ceiling four commits running.
#
# That is worse than slow. A gate that reaches the network to do its work is
# flaky by construction, it goes red for reasons that have nothing to do with
# the tree, and a gate that goes red for no reason is the one people disable --
# which is precisely how a fake green is born.
#
# Same parser, same files, same controls; it just stops asking the internet for
# permission when the parser is already on this machine.
YAML_OK=0
YAML_MODE=""
if node -e 'require("js-yaml")' >/dev/null 2>&1; then
  YAML_OK=1; YAML_MODE="node -e require(js-yaml)"
elif command -v js-yaml >/dev/null 2>&1; then
  YAML_OK=1; YAML_MODE="js-yaml on PATH"
elif npx --yes --quiet js-yaml --help >/dev/null 2>&1; then
  YAML_OK=2; YAML_MODE="npx js-yaml (network)"
fi

# One entry point, so the four call sites cannot drift apart again.
yamlparse() {
  case "$YAML_MODE" in
    "node -e require(js-yaml)")
      node -e 'const y=require("js-yaml"),f=require("fs");y.load(f.readFileSync(process.argv[1],"utf8"))' "$1" ;;
    "js-yaml on PATH") js-yaml "$1" >/dev/null ;;
    *)                 npx --yes --quiet js-yaml "$1" >/dev/null ;;
  esac
}

if [ "$YAML_OK" -eq 0 ]; then
  echo "  SKIP  no YAML parser available -- workflows NOT parsed. Not a pass."
else
  echo "  ----  YAML parser: $YAML_MODE"
  for wf in .github/workflows/*.yml; do
    if yamlparse "$wf" >/dev/null 2>&1; then
      ok "parses: $wf"
    else
      bad "DOES NOT PARSE: $wf"
      yamlparse "$wf" 2>&1 | head -3 | sed 's/^/        /'
    fi
  done

  # NEGATIVE CONTROL: the parser must reject something. A linter that passes
  # everything is not a linter. This also proves the FAST path above is a real
  # parser and not a stub that returns 0 -- if the local mode accepted this
  # file, the control would fail here.
  BADF="$(mktemp "${TMPDIR:-/tmp}/badwf.XXXXXX").yml"
  printf 'name: broken\non:\n  push:\njobs:\n  x:\n    steps:\n      - run: echo hi\n     bad_indent: true\n' > "$BADF"
  if yamlparse "$BADF" >/dev/null 2>&1; then
    bad "CONTROL DEAD: the parser accepted deliberately broken YAML"
  else
    ok "CONTROL: deliberately broken YAML was rejected ($YAML_MODE)"
  fi
  rm -f "$BADF"
fi

# --- 1b. VALID YAML IS NOT A VALID WORKFLOW ---------------------------------
# MEASURED 2026-08-01. `permissions: administration: write` was added to
# tag-manager.yml to let it write repo topics. It parsed perfectly -- the phase
# above passed it -- and GitHub then refused the file and ran the workflow with
# ZERO JOBS. `administration` is not a GITHUB_TOKEN permission; the scope does
# not exist for that token, so the whole file is invalid.
#
# The failure mode is the nasty kind: the run appears in the list, it is red,
# and there is no job and no step to read a message from. Nothing local caught
# it, because a YAML parser has no opinion about which keys GitHub accepts.
#
# The permission set below is GitHub's documented list for GITHUB_TOKEN. A key
# outside it means the workflow will not run at all.
echo
echo "-- permissions keys must be ones GITHUB_TOKEN actually has --"
PERM_OK=" actions attestations checks contents deployments discussions id-token issues models packages pages pull-requests repository-projects security-events statuses "
perm_bad=0
for wf in .github/workflows/*.yml; do
  # Lines inside a `permissions:` block: two-space indented `key: value`, up to
  # the next top-level key. Comments are stripped so prose naming a bad key
  # (this file's own explanation, for instance) is not mistaken for one.
  keys=$(awk '/^permissions:/{f=1;next} /^[a-zA-Z]/{f=0} f' "$wf" \
         | sed 's/#.*$//' | sed -n 's/^[[:space:]]*\([a-z-]*\)[[:space:]]*:.*/\1/p')
  for k in $keys; do
    case "$PERM_OK" in
      *" $k "*) : ;;
      *) bad "$(basename "$wf"): '$k' is NOT a GITHUB_TOKEN permission -- the workflow will not run at all"
         perm_bad=$((perm_bad+1)) ;;
    esac
  done
done
[ "$perm_bad" -eq 0 ] && ok "every permissions key in every workflow is one GITHUB_TOKEN has"

# CONTROLS: the rule must reject the key that actually broke the repo, and must
# not reject the ordinary ones, or it would forbid correct workflows.
case "$PERM_OK" in *" administration "*) bad "CONTROL DEAD: 'administration' is in the allowed set; the rule cannot catch the defect that motivated it" ;;
                   *) ok "CONTROL: 'administration' IS rejected -- the exact key that ran zero jobs" ;; esac
case "$PERM_OK" in *" contents "*) ok "CONTROL: 'contents' is accepted -- the rule does not forbid correct workflows" ;;
                   *) bad "CONTROL DEAD: 'contents' rejected; the allow-list is wrong" ;; esac

# --- 1c. NOTHING WRITES TO main EXCEPT A HUMAN -------------------------------
# MEASURED 2026-08-01. Three workflows ended in `git push` to main. The branch
# then gained a ruleset -- no deletion, no force-push, four required status
# checks -- and the first bot push was refused:
#
#   remote: - 4 of 4 required status checks are expected.
#   ! [remote rejected] main -> main (push declined due to repository rules)
#
# The GitHub Actions app CANNOT be given a repository-level bypass; the API
# refuses with HTTP 422, "Actor GitHub Actions integration must be part of the
# ruleset source or owner organization". So the choice was: weaken the
# protection so a bot can write unreviewed commits to the default branch, or
# stop the bots writing. Weakening protection to make an alarm go quiet is the
# move this project treats as a violation, so all three now FAIL on drift and
# print the diff instead.
#
# The coverage is unchanged -- checker/tags-consistency.sh gates the same
# invariants on every commit rather than three times a week -- and the tree can
# no longer be modified by something nobody reviewed.
echo
echo "-- no workflow may push to the protected branch --"
push_hits=0
for wf in .github/workflows/*.yml; do
  h=$(sed 's/#.*$//' "$wf" | grep -nE '^[[:space:]]*git[[:space:]]+push([[:space:]]|$)' || true)
  if [ -n "$h" ]; then
    bad "$(basename "$wf") pushes to the repository -- main is protected and this WILL be refused:"
    printf '%s\n' "$h" | sed 's/^/        /'
    push_hits=$((push_hits+1))
  fi
done
[ "$push_hits" -eq 0 ] && ok "no workflow pushes to the repository (all $(ls .github/workflows/*.yml | wc -l | tr -d ' ') report drift instead)"

# CONTROL: plant the pattern in a scratch file and require the same predicate
# to catch it. Without this, "0 hits" could equally mean the regex is wrong.
ctl_wf="${TMPDIR:-/tmp}/wfpush.$$.yml"
printf 'jobs:\n  x:\n    steps:\n      - run: |\n          git push\n' > "$ctl_wf"
if [ -n "$(sed 's/#.*$//' "$ctl_wf" | grep -nE '^[[:space:]]*git[[:space:]]+push([[:space:]]|$)' || true)" ]; then
  ok "CONTROL: a planted 'git push' IS detected"
else
  bad "CONTROL DEAD: the planted 'git push' was not detected -- the rule is blind"
fi
# And it must not fire on prose that merely mentions pushing, or every comment
# explaining this rule would break the build.
printf 'jobs:\n  x:\n    steps:\n      - run: echo "this job will not git push anywhere"\n' > "$ctl_wf"
if [ -z "$(sed 's/#.*$//' "$ctl_wf" | grep -nE '^[[:space:]]*git[[:space:]]+push([[:space:]]|$)' || true)" ]; then
  ok "CONTROL: a mention of 'git push' inside an echo is NOT flagged -- the rule reads commands, not prose"
else
  bad "CONTROL: prose mentioning git push was flagged; the rule is too broad"
fi
rm -f "$ctl_wf"

# --- 2. does CI actually run every checker? ---------------------------------
echo
echo "-- drift: every checker must be wired into a workflow --"
# Deliberate exceptions, each with a reason. An empty reason is not allowed.
#
# NO ASSOCIATIVE ARRAYS. macOS ships bash 3.2.57 (2007) as /bin/bash -- Apple
# froze it at the last GPLv2 release -- and `declare -A` arrived in bash 4.0.
# MEASURED on macos-latest 2026-08-01: this file died at
# `declare: -A: invalid option`, then `preflight.sh: syntax error: invalid
# arithmetic operator`, because bash 3.2 read EXCEPT[preflight.sh]="..." as an
# arithmetic subscript on an ordinary array. The whole macOS job stopped here.
# A `case` lookup is portable to every bash in the wild and reads no worse.
except_reason () {   # except_reason <basename> -> prints reason, or nothing
  case "$1" in
    preflight.sh)      printf '%s' "informational; run as the first CI step but not a gate" ;;
    workflow-lint.sh)  printf '%s' "would recurse; run from CI as its own step below" ;;
# gate-all is an AGGREGATOR for local use and the pre-commit hook. Running it in
# CI would re-run every gate a second time inside one step, and a failure would
# report as "gate-all failed" instead of naming the check that broke. Per-step
# granularity is worth more in CI than a single roll-up. It is exercised on
# every local commit via .githooks/pre-commit, and the phase below asserts that
# every gate it lists is a real, present checker -- so it cannot silently rot.
    gate-all.sh)       printf '%s' "aggregator for the pre-commit hook; CI runs each gate as its own named step" ;;
# ci-audit-freshness compares the audited run against LOCAL HEAD. Inside a CI job
# local HEAD *is* the run's own commit, so the comparison would pass by
# construction on every run forever -- a step that cannot fail, which is the
# decoration this repo refuses to ship. The defect it catches lives on the
# development machine, in the gap between writing a fix and landing it: three
# consecutive runs reported an identical failure while the repair sat
# uncommitted here. It runs from gate-all.sh, and the phase below asserts that.
    ci-audit-freshness.sh) printf '%s' "compares a run against LOCAL HEAD; in CI that is trivially itself, so it runs from gate-all.sh instead" ;;
# release-local IS THE PRE-RELEASE STAGING REHEARSAL, and it is local by
# definition. `.release-local-only/` is where a new version is built and tested
# on THIS machine -- installed into CTT, exercised -- before anything is promoted
# into `.release/`. It is .gitignore'd and never published.
#
# It was wired into ci.yml anyway, and ran on three runners. macOS-latest failed
# it for three consecutive runs (BSD `sed -i`), taking 28 later steps down as
# skipped. The incompatibility was the symptom; the category error was asking a
# GitHub runner to rehearse a release into a CTT that does not exist there.
#
# Removed from ci.yml 2026-08-08. It still runs in the local deep tier through
# gate-all.sh, and exempt_must_be_reachable asserts that below -- so this
# exemption states WHERE it runs, never that it stopped running.
    release-local.sh)  printf '%s' "pre-release staging rehearsal into a gitignored dir and CTT; neither exists on a runner, so it runs from gate-all.sh" ;;
# THE NEXT THREE WERE ALREADY OUT OF CI ON PURPOSE -- and this table did not know
# it. Each carries a comment in ci.yml explaining why it is not a step, and the
# wiring scan below used to read that comment as proof the checker WAS wired.
# Stripping comments (see WF_TEXT) exposed all three at once. Their reasons were
# already correct; they were simply written in prose instead of being enforced
# here, so nothing asserted they still ran ANYWHERE. Now something does.
#
# ci.yml:536 -- ci-dryrun executes this workflow's own step list, so running it
# as a step inside that workflow is recursion.
    ci-dryrun.sh)      printf '%s' "executes this workflow's own step list; running it as a step in that workflow recurses" ;;
# ci.yml:74 -- ci-honesty judges a COMPLETED run. Inside a run, that run is
# in_progress by construction, so the verdict would be provisional forever. Same
# structural reason as ci-audit-freshness above.
    ci-honesty.sh)     printf '%s' "judges a completed run; inside a run that run is in_progress by construction, so it runs from gate-all.sh" ;;
# Same construction as ci-honesty: it downloads and reads a FINISHED run's
# log.zip, which cannot exist for the run executing it. It answers a different
# question -- ci-honesty reads step CONCLUSIONS, this reads whether a step's BODY
# printed a skip while concluding green, a gap RotCiSkip proves conclusion
# auditing cannot see. Reachability from gate-all.sh is asserted below.
    ci-log-skips.sh)   printf '%s' "reads a COMPLETED run's log.zip; that artifact does not exist for the run reading it, so it runs from gate-all.sh" ;;
# ci.yml:605 -- both release-session gates need the `claude` CLI and the
# sustained one needs a credential to clone. The workflow comment says it
# plainly: a step that can NEVER do its job still paints a green check.
    release-longsession.sh) printf '%s' "needs the claude CLI and a clone credential; a step that can never do its job still paints a green check" ;;
    release-session.sh)     printf '%s' "needs the claude CLI, absent on a public runner; runs from gate-all.sh instead" ;;
  esac
}

# WHAT KIND OF EXEMPTION IS THIS -- stated as a fact, because prose cannot be tested.
#
# The reasons above are honest, and they are for humans. They are also not all the
# same CLAIM. Eight say the checker does not run in CI at all. Two say the opposite:
# preflight runs as the first CI step, and this file runs as a step of its own. Both
# kinds sat under one word, exempt, and nothing could tell them apart without reading
# English.
#
# That mattered the moment the wiring test got strict (2026-08-19). A rule treating
# every exemption as must-not-appear-in-CI reports preflight and workflow-lint as
# contradictions -- two loud false alarms. A rule treating every exemption as
# may-appear-in-CI is what let gate-all.sh be blessed by a sentence in a log message
# in the first place. Neither is right, because one field was answering two questions.
#
# So the classification is a fact here, and it is tested. The sentences stay for humans.
exempt_kind () {   # <basename> -> ci-step | not-in-ci | empty when not exempt
  case "$1" in
    preflight.sh|workflow-lint.sh)
        printf '%s' "ci-step" ;;
    gate-all.sh|ci-audit-freshness.sh|release-local.sh|ci-dryrun.sh|ci-honesty.sh|ci-log-skips.sh|release-longsession.sh|release-session.sh)
        printf '%s' "not-in-ci" ;;
  esac
}

# TWO TABLES MUST NAME ONE SET. Splitting a fact out of prose creates a second list,
# and a second list is a second place to forget a name. A checker with a reason and no
# kind falls through every classification below; a kind with no reason excuses a
# checker no human ever justified. Neither may pass in silence.
kindsync=0
for c in checker/*.sh; do
  b="${c##*/}"
  r="$(except_reason "$b")"
  k="$(exempt_kind "$b")"
  if [ -n "$r" ] && [ -z "$k" ]; then
    bad "EXEMPTION WITHOUT A KIND: $b has a written reason but no classification"
    kindsync=1
  fi
  if [ -z "$r" ] && [ -n "$k" ]; then
    bad "KIND WITHOUT A REASON: $b is classified $k but no reason was ever written"
    kindsync=1
  fi
done
[ "$kindsync" -eq 0 ] && ok "every exemption carries both a reason and a kind"

# THE VERDICT IS A PURE FUNCTION OF TWO FACTS: does a workflow invoke it, and how is
# it classified. Pure, so it can be controlled -- the loop prints, this decides. Six
# states, all named. R22 in this same file demands an exhaustive dispatch that says
# which branch ran; this obeys its own rule.
wiring_verdict () {   # <invoked:0|1> <kind> -> exactly one token, never empty
  case "$1:$2" in
    1:)          printf '%s' "OK-WIRED" ;;
    1:ci-step)   printf '%s' "OK-DOCUMENTED-CI-STEP" ;;
    1:not-in-ci) printf '%s' "CONTRADICTION-INVOKED-BUT-EXEMPT" ;;
    0:)          printf '%s' "NOT-RUN-ANYWHERE" ;;
    0:ci-step)   printf '%s' "CONTRADICTION-CLAIMS-CI-STEP-BUT-ABSENT" ;;
    0:not-in-ci) printf '%s' "OK-EXEMPT" ;;
    *)           printf '%s' "IMPOSSIBLE" ;;
  esac
}

# CONTROL: all six states, against the same function the loop calls. A truth table
# with an unexercised row is a truth table with a hole in it.
vctl=0
for probe in "1: OK-WIRED" "1:ci-step OK-DOCUMENTED-CI-STEP" "1:not-in-ci CONTRADICTION-INVOKED-BUT-EXEMPT" "0: NOT-RUN-ANYWHERE" "0:ci-step CONTRADICTION-CLAIMS-CI-STEP-BUT-ABSENT" "0:not-in-ci OK-EXEMPT"; do
  key="${probe%% *}"; want="${probe##* }"
  got="$(wiring_verdict "${key%%:*}" "${key#*:}")"
  if [ "$got" = "$want" ]; then
    vctl=$((vctl+1))
  else
    bad "CONTROL: wiring_verdict on $key returned $got, expected $want"
  fi
done
[ "$vctl" -eq 6 ] && ok "CONTROL: all six wiring verdicts are reachable and correct"

# AN EXEMPTION MUST NOT BE A HIDING PLACE.
#
# The reason above is honest, but "not run by CI" and "not run at all" look
# identical from here, and the second is how a checker quietly dies. So every
# exempt checker must be reachable from SOMEWHERE: either gate-all.sh's table or
# an explicit note that it is informational. Without this, adding a name to the
# case block above would silently remove a check from the repository.
exempt_must_be_reachable () {   # <basename> -> 0 if reachable, else 1
  case "$1" in
    preflight.sh|workflow-lint.sh|gate-all.sh) return 0 ;;   # wired as CI steps / self
  esac
  grep -q -- "checker/$1" "$REPO/checker/gate-all.sh" 2>/dev/null
}

# NEVER PIPE A LARGE STRING INTO AN EARLY-EXITING CONSUMER.
#
# MEASURED ON ubuntu-latest, 2026-08-01. Three sites in this file piped a
# string into `grep -q` (the pattern is spelled out in the commit message
# rather than here, because a blanket rewrite of this file's call sites also
# rewrote this very comment -- a literal instance of the hazard that replacing
# a short form corrupts a superset of what you meant),
# and the runner reported EIGHT WIRED CHECKERS as NOT RUN BY ANY WORKFLOW, each
# with `printf: write error: Broken pipe` beside it. `grep -q` exits the instant
# it matches; printf is still writing, takes EPIPE and exits non-zero; the job's
# shell is `bash -e -o pipefail`, so pipefail fails the PIPELINE -- and a
# successful match is scored as a miss. The lint then declared the repository
# less verified than it is, which is the exact inversion of its purpose.
#
# It never fired on Git Bash: the string fits the pipe buffer before grep can
# exit, so printf never sees the broken pipe. A test whose outcome depends on
# the platform's pipe buffer size is the worst kind of green there is.
#
# `case` answers the same question with no process, no pipe and no race.
contains () {   # contains <haystack> <needle>  -> 0 if present
  case "$1" in
    *"$2"*) return 0 ;;
    *)      return 1 ;;
  esac
}
contains_line () {   # contains_line <haystack> <exact line>  -> 0 if present
  case "
$1
" in
    *"
$2
"*) return 0 ;;
    *)  return 1 ;;
  esac
}

# STRIP YAML COMMENTS BEFORE ASKING "IS IT WIRED".
#
# Measured 2026-08-08, on the very commit that removed a step. The step running
# checker/release-local.sh was deleted from ci.yml and replaced with a comment
# block explaining WHY -- a block that necessarily names the file. This scan read
# the raw text, found the name inside the comment, and printed
#
#     PASS  wired into a workflow: release-local.sh
#
# about a checker no workflow runs any more. A mention is not a wiring, exactly
# as a mention is not a leak: the rule must read the commands, not the prose
# around them. Section 1 above already learned this for `git push` and has a
# control for it; this section had not.
#
# Comments are stripped the same way section 1 does it. That is imperfect for a
# `#` inside a quoted string, and deliberately so -- erring toward NOT seeing a
# wiring makes the checker complain about a real gap, never bless a missing one.
WF_TEXT="$(sed 's/#.*$//' .github/workflows/*.yml)"

# CONTROL for the strip, both directions. The bug it prevents was introduced and
# caught inside one commit, so the control is not hypothetical: a comment naming
# a checker must NOT read as a wiring, and a real `run:` line MUST.
ctl_yml="${TMPDIR:-/tmp}/wfl-strip.$$.yml"
printf '%s\n' \
  'jobs:' \
  '  x:' \
  '    steps:' \
  '      # NOT RUN HERE on purpose: checker/ghost-only-in-a-comment.sh' \
  '      - run: bash checker/really-wired.sh' > "$ctl_yml"
ctl_txt="$(sed 's/#.*$//' "$ctl_yml")"
strip_ok=0
case "
$ctl_txt
" in *"ghost-only-in-a-comment.sh"*) bad "CONTROL: a checker named only in a COMMENT still reads as wired -- the strip is not working" ;;
     *) strip_ok=$((strip_ok+1)) ;;
esac
case "
$ctl_txt
" in *"really-wired.sh"*) strip_ok=$((strip_ok+1)) ;;
     *) bad "CONTROL: a checker on a real run: line was LOST by the strip -- the rule would invent failures" ;;
esac
rm -f "$ctl_yml"
[ "$strip_ok" -eq 2 ] && ok "CONTROL: a comment mention is not a wiring, and a run: line still is"
# A MENTION IN PROSE IS NOT A WIRING EITHER -- not even inside a `run:` block.
#
# The strip above learned that a name inside a YAML `#` comment must not read as
# a wiring. It did not learn the GENERAL form, and the general form is what bites:
# any prose containing the name blesses the checker, and a shell string is prose.
#
# MEASURED 2026-08-19. ci.yml:1329 carries
#
#     3) echo "::notice::workflow-roles SKIPPED its API half (exit 3) -- not a
#        pass, measured from gate-all.sh instead" ;;
#
# and the substring test read `gate-all.sh` out of that sentence and printed
#
#     PASS  wired into a workflow: gate-all.sh
#
# about the ONE checker whose exemption above argues at length that CI must NOT
# run it. The exemption -- its reason, and the reachability assertion guarding it
# -- was dead code, jumped over by a name inside a log message. The gate was
# asserting a false fact in the PASS direction, which is this repo`s worst class.
#
# So the question is no longer "is the name present" but "is the file INVOKED".
# A name must sit behind a command word to count.
#
# This also retires a latent hazard measured the same day: under a bare-basename
# test, a checker whose name is a substring of another checker`s name inherits
# that one`s wiring for free. Putting `checker/` in front makes it impossible.
# Collisions among the 82 names today: 0 -- but the rule no longer rests on that
# luck, and the next contributor is not required to preserve it.
wired_in () {   # wired_in <haystack> <basename> -> 0 if the haystack INVOKES it
  contains "$1" "bash checker/$2"   && return 0
  contains "$1" "sh checker/$2"     && return 0
  contains "$1" "./checker/$2"      && return 0
  contains "$1" "source checker/$2" && return 0
  return 1
}
wired () { wired_in "$WF_TEXT" "$1"; }

# CONTROL, both directions, against the SAME function production calls. The first
# arm is the false green measured above. The second is the failure that tightening
# a rule normally introduces -- a real invocation no longer recognised, which would
# have this gate invent 74 failures and get itself switched off.
ctl_hay='      - run: |
          echo "::notice::something SKIPPED -- measured from ctl-prose-only.sh instead"
          bash checker/ctl-really-invoked.sh --flag'
wctl=0
if wired_in "$ctl_hay" "ctl-prose-only.sh"; then
  bad "CONTROL: a checker named only inside a log message still reads as WIRED -- the invocation test is dead"
else
  wctl=$((wctl+1))
fi
if wired_in "$ctl_hay" "ctl-really-invoked.sh"; then
  wctl=$((wctl+1))
else
  bad "CONTROL: a checker on a real 'bash checker/...' line reads as NOT wired -- this gate would invent failures"
fi
[ "$wctl" -eq 2 ] && ok "CONTROL: a name in prose is not a wiring; a real invocation still is"
for c in checker/*.sh; do
  base="${c##*/}"
  if wired "$base"; then iv=1; else iv=0; fi
  case "$(wiring_verdict "$iv" "$(exempt_kind "$base")")" in
    OK-WIRED)
      ok "wired into a workflow: $base" ;;
    OK-DOCUMENTED-CI-STEP)
      ok "wired into a workflow as a documented CI step: $base" ;;
    OK-EXEMPT)
      if exempt_must_be_reachable "$base"; then
        echo "  NOTE  exempt: $base -- $(except_reason "$base")"
      else
        bad "EXEMPT BUT UNREACHABLE: $base is excused from CI and is not in gate-all.sh either"
        echo "        An exemption is a statement about WHERE it runs, never that it"
        echo "        stopped running. This one runs nowhere."
      fi ;;
    CONTRADICTION-INVOKED-BUT-EXEMPT)
      bad "EXEMPT AS not-in-ci AND YET INVOKED BY A WORKFLOW: $base"
      echo "        The table says CI must not run this; a workflow runs it. One of"
      echo "        the two is stale, and until they agree nobody knows which." ;;
    CONTRADICTION-CLAIMS-CI-STEP-BUT-ABSENT)
      bad "CLASSIFIED ci-step BUT NO WORKFLOW INVOKES IT: $base"
      echo "        Its exemption is excused on the grounds that CI runs it directly."
      echo "        CI does not. That excuse is now covering nothing." ;;
    NOT-RUN-ANYWHERE)
      bad "NOT RUN BY ANY WORKFLOW: $base"
      echo "        The repo looks more verified than it is. Wire it up, or add it"
      echo "        to EXCEPT in this file WITH a reason." ;;
    *)
      bad "INTERNAL: wiring_verdict returned no verdict for $base -- the dispatch is not exhaustive" ;;
  esac
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
  #
  # THIS PHASE HAS ALREADY FIRED ON A REAL REGRESSION, which is the only reason
  # it is worth its lines: on 2026-07-31 an unrelated local tool (CodeMap)
  # installed its own hook by writing `.githooks/pre-commit` wholesale. The gate
  # vanished; the replacement ended `exit 0` and documented that it never blocks
  # a commit. Present, executable, friendly, and guarding nothing. The fix moved
  # every non-gate hook to `.githooks/pre-commit.d/` and left this file
  # repo-owned -- so the predicate below now also demands the delegation runner,
  # because a hook that runs no delegates will be clobbered again the moment the
  # other tool wants its behaviour back.
  hook_verdict () {   # hook_verdict <file> -> prints one word per defect, empty = good
    local f="$1" v=""
    [ -f "$f" ] || { echo "MISSING"; return; }
    grep -q "gate-all.sh" "$f" || v="$v NO_GATE"
    grep -q "exit 1"      "$f" || v="$v NO_REFUSAL"
    grep -q "pre-commit.d" "$f" || v="$v NO_DELEGATION"
    echo "$v"
  }

  if [ -f .githooks/pre-commit ]; then
    ok "pre-commit hook present"
    v="$(hook_verdict .githooks/pre-commit)"
    case "$v" in
      *NO_GATE*)       bad "pre-commit exists but never calls gate-all -- it guards nothing" ;;
      *)               ok "pre-commit actually calls gate-all" ;;
    esac
    case "$v" in
      *NO_REFUSAL*)    bad "pre-commit has no refusing path" ;;
      *)               ok "pre-commit can refuse a commit" ;;
    esac
    case "$v" in
      *NO_DELEGATION*) bad "pre-commit runs no .githooks/pre-commit.d delegates -- another tool will overwrite it to get its own hook back" ;;
      *)               ok "pre-commit delegates to .githooks/pre-commit.d (other tools have a place that is not this file)" ;;
    esac
    if [ -d .githooks/pre-commit.d ]; then
      ndel=$(find .githooks/pre-commit.d -type f ! -name '*.md' ! -name '*.bak' | wc -l)
      ok "delegate directory present ($ndel delegate(s))"
    fi

    # NEGATIVE CONTROL: the predicate must reject the exact shape that got past
    # everything last time -- an always-succeeding hook with no gate. Planted
    # here, not read from disk, so a clean clone runs the same control.
    CTL="$(mktemp "${TMPDIR:-/tmp}/hookctl.XXXXXX")"
    printf '#!/usr/bin/env bash\n# an indexing hook: never blocks a commit\ngit add -A .index\nexit 0\n' > "$CTL"
    cv="$(hook_verdict "$CTL")"
    case "$cv" in
      *NO_GATE*NO_REFUSAL*|*NO_REFUSAL*NO_GATE*)
        ok "CONTROL: a gateless always-exit-0 hook is rejected ($cv )" ;;
      *) bad "CONTROL DEAD: the gateless hook was NOT rejected (verdict: '$cv') -- this phase is decoration" ;;
    esac
    rm -f "$CTL"

    # THE FALLBACK PATH IS A LOADED GUN, and nothing was watching it.
    #
    # `core.hooksPath = .githooks` is what makes the gate above the one git
    # runs. `.git/hooks/pre-commit` is then inert -- until the day that config
    # is unset, reset by a tool, or absent in a fresh clone someone re-points.
    # Measured here 2026-08-07: that inert file held an indexing hook whose own
    # header reads "Never blocks a commit: every failure path exits 0". One
    # `git config --unset core.hooksPath` away from a silently ungated repo.
    #
    # This check is OUT OF BAND on purpose. `RotObserve` §12 is the reason: the
    # in-band audit runs only when the real gate is installed, so it is silent
    # in exactly the state it exists to report
    # (`in_band_detector_is_blind_to_its_own_replacement`). Only a verifier that
    # does not depend on the hook can separate the two worlds
    # (`out_of_band_detector_sees_the_replacement`).
    #
    # Absent is the SAFE state and passes -- a fresh clone has no .git/hooks
    # override, and CI is exactly that case, so this does not fire there.
    if [ -f .git/hooks/pre-commit ]; then
      fv="$(hook_verdict .git/hooks/pre-commit)"
      case "$fv" in
        *NO_GATE*|*NO_REFUSAL*)
          bad ".git/hooks/pre-commit exists and never refuses -- if core.hooksPath is ever unset, THAT becomes the gate and every commit is admitted. Delete it or make it the gate (verdict:$fv )" ;;
        *)
          ok ".git/hooks/pre-commit is itself a gate -- the fallback path is not a way around the gate" ;;
      esac
    else
      ok "no .git/hooks/pre-commit -- the fallback path holds no permissive hook"
    fi
  else
    bad ".githooks/pre-commit missing -- the red-gate commit can happen again"
  fi

  # It must also refuse: a roll-up that cannot go red is decoration.
  grep -q 'exit 1' checker/gate-all.sh \
    && ok "gate-all can exit non-zero" \
    || bad "gate-all has no failing exit path -- it cannot stop a bad commit"

  # --- 2c. THE LOCAL GATE MUST NOT BE WEAKER THAN CI ------------------------
  #
  # Phase 2 asserts every checker is run by SOME workflow. Phase 2b asserts
  # gate-all names only real checkers. NEITHER asserts the direction that
  # actually protects a commit: that gate-all COVERS every checker.
  #
  # Without it, a new checker wired into CI alone leaves the pre-commit gate
  # quietly weaker than the pipeline -- the defect passes locally, and the only
  # place it surfaces is a push. On a repository that does not yet have a
  # remote, "it surfaces on a push" means "it does not surface".
  #
  # Exemptions are allowed, and each one states its reason, because a silent
  # exemption is how a coverage rule becomes a formality.
  # `case`, not `declare -A`: bash 3.2 on macOS has no associative arrays.
  gate_except_reason () {
    case "$1" in
      gate-all.sh)  printf '%s' "it is the aggregator; it cannot list itself as a gate" ;;
      preflight.sh) printf '%s' "bootstrap probe for a fresh clone -- it runs BEFORE the gates exist, and gate-all would re-run its work" ;;
      # A GENERATOR, not a gate: it prints the verdict block and has no pass/fail
      # of its own. It is exempt only because two gates EXECUTE it, and that
      # claim is verified immediately below rather than believed.
      status-verdict.sh) printf '%s' "generator, not a gate -- it is EXERCISED by verdict-stability.sh and verdict-schedule-sim.sh, both of which are gates" ;;
    esac
  }

  gate_listed="$(grep -oE 'checker/[a-z-]+\.sh' checker/gate-all.sh | sed 's|checker/||' | sort -u)"
  uncovered=0
  for c in checker/*.sh; do
    b="${c##*/}"
    if contains_line "$gate_listed" "$b"; then
      continue
    elif [ -n "$(gate_except_reason "$b")" ]; then
      echo "  NOTE  not a gate: $b -- $(gate_except_reason "$b")"
    else
      bad "$b is never run by gate-all -- the local commit gate is WEAKER than CI"
      uncovered=$((uncovered+1))
    fi
  done
  [ "$uncovered" -eq 0 ] && ok "every checker is either a gate or exempt with a stated reason"

  # The exemption above RESTS ON A CLAIM -- "two gates execute it". An exemption
  # justified by a sentence nobody rechecks is how a coverage rule rots: the
  # gates could stop calling it tomorrow and the reason would still read well.
  # So check the claim, and require the exercising scripts to be gates
  # themselves, since being run by a non-gate would be no coverage at all.
  exercisers=0
  for g in checker/verdict-stability.sh checker/verdict-schedule-sim.sh; do
    gb="${g##*/}"
    if [ -f "$g" ] && grep -q 'status-verdict\.sh' "$g" \
       && contains_line "$gate_listed" "$gb"; then
      exercisers=$((exercisers+1))
    fi
  done
  if [ "$exercisers" -ge 2 ]; then
    ok "the status-verdict.sh exemption is EARNED: $exercisers gates execute it"
  else
    bad "status-verdict.sh is exempt on the claim that gates exercise it, but only $exercisers do -- the exemption is now a hole"
  fi

  # CONTROL: a planted checker that nobody wired in must be seen. Written to the
  # real directory and removed immediately, because the check reads the
  # directory -- a control that runs somewhere else tests somewhere else.
  PL="checker/zz-planted-control.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$PL"
  if contains_line "$gate_listed" "zz-planted-control.sh"; then
    bad "CONTROL DEAD: a checker that was never added to gate-all appears to be listed"
  else
    ok "CONTROL: a checker absent from gate-all IS detectable (planted, then removed)"
  fi
  rm -f "$PL"
else
  bad "checker/gate-all.sh is missing -- the pre-commit hook has nothing to call"
fi

# --- 3. does CI build every Lean module and run every mutation suite? -------
echo
echo "-- drift: every Lean module and mutation suite must be in CI --"
# -----------------------------------------------------------------------------
# THIS CHECK WAS ITSELF THE STALENESS DEFECT IT EXISTS TO CATCH. Measured
# 2026-08-01.
#
# It required every module to appear LITERALLY in the workflow text. That is a
# snapshot of today's names, not the property that matters, and it had a
# perverse consequence: it FORCED ci.yml to carry a hand-typed module list --
# the very thing the comment at ci.yml:414 records as having silently stopped
# covering RotRemind, RotAcquire and RotVerdict when they were added. When the
# workflow was fixed to enumerate from disk, this check went red on a strictly
# BETTER workflow, and the obvious repair (re-typing the list) would have
# restored the defect.
#
# So it now checks COVERAGE instead of spelling: a module is verified if CI
# names it, OR if CI's own enumeration -- executed here, not assumed -- yields
# it. `ls Proofs/*.lean` covers every module by construction; `ls Proofs/Rot*`
# would not, and the control below proves this can still tell the difference.
# -----------------------------------------------------------------------------
ENUM_MOD="$(grep -oE 'ls Proofs/[^ |]*\.lean' .github/workflows/ci.yml | head -1)"
enum_mods() {
  [ -n "$ENUM_MOD" ] || return 0
  ( cd lean 2>/dev/null && eval "$ENUM_MOD" 2>/dev/null ) \
    | sed 's#^Proofs/##; s#\.lean$##'
}
MOD_ENUMERATED="$(enum_mods)"
if [ -n "$ENUM_MOD" ]; then
  ok "CI enumerates its Lean modules from disk ($ENUM_MOD) -- no hand-typed list to go stale"
fi

for m in lean/Proofs/*.lean; do
  mod="${m##*/}"; mod="${mod%.lean}"
  if contains "$WF_TEXT" "Proofs.$mod"; then
    ok "CI builds Proofs.$mod (named explicitly)"
  elif contains_line "$MOD_ENUMERATED" "$mod"; then
    ok "CI builds Proofs.$mod (covered by the disk enumeration)"
  else
    bad "CI NEVER BUILDS Proofs.$mod -- it is unverified in CI"
  fi
done

# CONTROL: a narrower enumeration must NOT be accepted as covering everything.
# Without this the branch above would pass for any glob at all, including one
# that quietly omits half the tree.
_narrow="$( ( cd lean 2>/dev/null && ls Proofs/RotG*.lean 2>/dev/null ) | sed 's#^Proofs/##; s#\.lean$##' )"
_missed=0
for m in lean/Proofs/*.lean; do
  contains_line "$_narrow" "$(m2=${m##*/}; printf %s "${m2%.lean}")" || _missed=$((_missed+1))
done
if [ "$_missed" -eq 0 ]; then
  bad "CONTROL DEAD: a narrow glob appears to cover every module -- coverage is not being measured"
else
  ok "CONTROL: a narrower enumeration IS detected as leaving $_missed module(s) unbuilt"
fi
# EVERY script under lean/mutate must be in CI, not only the mutate_* ones. The
# generalization probe and the isolation artifact live here too, and a rule that
# matched one filename prefix would have let them rot unrun -- the same blind
# spot this phase exists to close.
# Helpers under lean/mutate that are not independently runnable get an
# exemption WITH a reason and WITH the evidence for it -- never a bare skip.
# `case`, not `declare -A`: bash 3.2 on macOS has no associative arrays.
mut_except_reason () {
  case "$1" in
    attribute_mut.sh) printf '%s' "forensic re-reader for stored mutation logs; its function (anchoring attribution on ^error:) is now inline in all five harnesses, asserted below" ;;
  esac
}

# Same treatment as the module list, for the same reason: CI enumerates its
# mutation suites from disk, so requiring each filename to appear as text would
# force back the hand-typed list whose staleness is the whole problem.
ENUM_MUT="$(grep -oE 'ls mutate/[^ |)]*\.sh' .github/workflows/ci.yml | head -1)"
MUT_ENUMERATED="$( [ -n "$ENUM_MUT" ] && ( cd lean 2>/dev/null && eval "$ENUM_MUT" 2>/dev/null ) | sed 's#^mutate/##' )"
[ -n "$ENUM_MUT" ] && ok "CI enumerates its mutation suites from disk ($ENUM_MUT)"

for s in lean/mutate/*.sh; do
  base="${s##*/}"
  if contains "$WF_TEXT" "$base"; then
    ok "CI runs $base"
  elif contains_line "$MUT_ENUMERATED" "$base"; then
    ok "CI runs $base (covered by the disk enumeration)"
  elif [ -n "$(mut_except_reason "$base")" ]; then
    echo "  NOTE  exempt: $base -- $(mut_except_reason "$base")"
  else
    bad "CI NEVER RUNS $base -- those theorems are unmutated in CI"
  fi
done

# The exemption above rests on a claim. Check the claim, do not take it on
# trust: an exemption justified by a stale sentence is worse than no exemption,
# because it reads as though someone verified it.
missing_anchor=0
for h in lean/mutate/mutate_*.sh; do
  grep -q '\^error: Proofs' "$h" || { bad "$(basename "$h") lost its anchored attribution -- the exemption's premise is false"; missing_anchor=$((missing_anchor+1)); }
done
[ "$missing_anchor" -eq 0 ] && ok "all mutation harnesses attribute on '^error:' (linter warnings cannot be mistaken for kills)"

# A KILL MUST BE ATTRIBUTABLE, AND THAT IS NOW CHECKED STRUCTURALLY.
#
# MEASURED DEFECT, 2026-07-31: two of the five suites resolved their paths from
# `cd "$(dirname "$0")"` -- lean/mutate/ -- where no Proofs/*.lean exists and
# lake has no lakefile. Every build failed for THAT reason, every failure was
# scored KILLED, and they reported 11 perfect kills between them without ever
# opening a source file. The needle guard did not save it: the count was EMPTY,
# so `[ "$n" -ne 1 ]` errored instead of firing.
#
# Two structural requirements come out of it, and they are cheap to check:
#   * the suite resolves its workspace from LEAN_ROOT, like every other one
#   * the suite PREFLIGHTS -- it refuses to run when the source is missing or
#     the unmutated baseline is red, because a kill measured against a red
#     baseline cannot be attributed to the mutation
#   * the suite carries a NO-DOWNLOAD GUARD. Added 2026-07-31 after a measured
#     7.2 GB: every one of these scripts calls `lake`, lake RESOLVES THE PACKAGE
#     before it does anything, and the default workspace is the vendored `lean/`
#     tree. Running one from a fresh clone -- which is exactly what a CI dry run
#     or a new contributor does -- started fetching mathlib INTO THE REPOSITORY.
#     The tree ships as ~200 KB. This is checked structurally because the
#     failure is invisible until the disk fills.
mut_defects=0
for h in lean/mutate/mutate_*.sh lean/mutate/generalization_probe.sh; do
  [ -f "$h" ] || continue
  b="${h##*/}"
  grep -qE 'LEAN_ROOT|LEAN_DIR' "$h" \
    || { bad "$b does not resolve its workspace from LEAN_ROOT -- it will build in whatever directory it is called from"; mut_defects=$((mut_defects+1)); }
  grep -qE 'preflight|FATAL|SKIP' "$h" \
    || { bad "$b has no preflight -- it cannot tell 'my workspace is missing' from 'the theorem caught it'"; mut_defects=$((mut_defects+1)); }
  grep -q 'NO-DOWNLOAD GUARD' "$h" \
    || { bad "$b has no NO-DOWNLOAD GUARD -- run from a clean clone it can fetch mathlib into the repo (measured: 7.2 GB)"; mut_defects=$((mut_defects+1)); }
done
[ "$mut_defects" -eq 0 ] && ok "all $(ls lean/mutate/mutate_*.sh | wc -l | tr -d ' ') mutation suites resolve from LEAN_ROOT and preflight a green baseline"

# CONTROL: the exact broken shape must be rejected. Without this, the two greens
# above are a pattern nobody has seen fail.
MCTL="$(mktemp -d "${TMPDIR:-/tmp}/mutctl.XXXXXX")"
printf '#!/usr/bin/env bash\ncd "$(dirname "$0")"\nSRC="Proofs/X.lean"\nlake build Proofs.X\n' > "$MCTL/mutate_broken.sh"
if grep -q 'LEAN_ROOT' "$MCTL/mutate_broken.sh" || grep -cE 'preflight >/dev/null|FATAL' "$MCTL/mutate_broken.sh"; then
  bad "CONTROL DEAD: the pre-2026-07-31 broken suite shape passes these checks"
else
  ok "CONTROL: a suite that cds to its own directory with no preflight IS rejected"
fi
# SECOND CONTROL, for the guard specifically: a suite that is otherwise correct
# -- LEAN_ROOT, preflight, the lot -- but has no download guard must still be
# caught. Without this the new requirement would be satisfied by the two older
# ones and would never be exercised on its own.
printf '#!/usr/bin/env bash\nLEAN_ROOT="${LEAN_ROOT:-.}"\n# preflight\nlake build Proofs.X\n' > "$MCTL/mutate_noguard.sh"
if grep -q 'NO-DOWNLOAD GUARD' "$MCTL/mutate_noguard.sh"; then
  bad "CONTROL DEAD: a suite with no download guard reads as guarded"
else
  ok "CONTROL: a well-formed suite that can still fetch mathlib IS rejected"
fi
rm -rf "$MCTL"

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

# --- 5. the toolchain fetch must stay OPT-IN --------------------------------
echo
echo "-- SETUP_LEAN is opt-in, and the installer must never call it --"
#
# THE RULE AND WHY IT IS MECHANICAL. Installing this plugin must never download
# gigabytes as a side effect. A mathlib build tree measured 7.2 GB on the
# author's machine, and elan pulls a per-platform toolchain on top of that.
# ARM_ROUTER's contract is that it touches the plugin directory and nothing
# else. "We promise not to" is not a control; this is.
for f in SETUP_LEAN.sh SETUP_LEAN.ps1; do
  [ -f "$f" ] && ok "present: $f" || bad "MISSING: $f -- the opt-in path must exist"
done

setup_verdict () {   # setup_verdict <file> -> prints defects, empty = clean
  local f="$1" v=""
  [ -f "$f" ] || { echo "ABSENT"; return; }
  # A refusal path: running it with no consent flag must be able to REFUSE.
  grep -qE 'REFUSING' "$f" || v="$v NO_REFUSAL"
  # A dry run: the negative control of an installer is that it can create
  # nothing and say so.
  grep -qE 'DRY RUN|DryRun|--dry-run' "$f" || v="$v NO_DRYRUN"
  # Never elevate. A setup script that needs root is the wrong design, and this
  # is the cheapest possible place to notice.
  # Strip comments AND the inside of say/echo/printf strings before looking for
  # sudo. The word appears legitimately in a message that PROMISES not to use it
  # -- "This installer never asks for sudo" -- and flagging that is the same
  # class of false positive as flagging `git push` inside an echo, which phase
  # 1c already handles this way. What must still be caught is sudo INVOKED.
  # `sed -E`: \| alternation in a BRE is a GNU extension that BSD sed ignores.
  # Measured on the macOS runner -- the strip did nothing, so SETUP_LEAN.sh's own
  # reassurance, say "This installer never asks for sudo", was read as a sudo
  # CALL and the gate failed on the sentence promising the opposite.
  sed 's/#.*$//' "$f" | sed -E 's/(say|echo|printf).*$//' | grep -cE '(^|[^[:alnum:]_])sudo ' >/dev/null && v="$v USES_SUDO"
  # The toolchain must be PINNED. A floating "latest" makes the proofs
  # unreproducible and would silently move under the reader.
  grep -q 'lean-toolchain' "$f" || v="$v NOT_PINNED"
  printf '%s' "$v"
}
for f in SETUP_LEAN.sh SETUP_LEAN.ps1; do
  v="$(setup_verdict "$f")"
  [ -z "$v" ] && ok "$f: refusal + dry-run + pinned toolchain + no sudo" \
              || bad "$f defects:$v"
done

# The separation itself: no installer may invoke the fetch.
armed_bad=0
for f in ARM_ROUTER.sh ARM_ROUTER.ps1 DISARM_ROUTER.sh DISARM_ROUTER.ps1 hooks/settings-merge.js; do
  [ -f "$f" ] || continue
  if grep -q 'SETUP_LEAN' "$f"; then
    bad "$f references SETUP_LEAN -- installing must never trigger a multi-GB download"
    armed_bad=1
  fi
done
[ "$armed_bad" -eq 0 ] && ok "no installer references SETUP_LEAN (the fetch stays opt-in)"

# CONTROLS, both directions. Without them this section is four greens that have
# never been seen to fail.
SCTL="$(mktemp -d "${TMPDIR:-/tmp}/setupctl.XXXXXX")"
printf '#!/usr/bin/env bash\ncurl -sSfL https://example/x | sudo sh\nlake exe cache get\n' > "$SCTL/bad-setup.sh"
v="$(setup_verdict "$SCTL/bad-setup.sh")"
case "$v" in
  *NO_REFUSAL*|*USES_SUDO*)
    ok "CONTROL: a consentless sudo-piping setup script is rejected ($v )" ;;
  *) bad "CONTROL DEAD: a consentless sudo setup script passed the verdict" ;;
esac
printf '#!/usr/bin/env bash\nbash "$HERE/SETUP_LEAN.sh" --yes\n' > "$SCTL/bad-arm.sh"
if grep -q 'SETUP_LEAN' "$SCTL/bad-arm.sh"; then
  ok "CONTROL: an installer that calls SETUP_LEAN WOULD be detected"
else
  bad "CONTROL DEAD: the installer-calls-fetch detector cannot see it"
fi
rm -rf "$SCTL"

# =============================================================================
# R19 -- A CALLER MUST GRANT EVERY PERMISSION THE WORKFLOW IT CALLS REQUESTS.
#
# Both rules below exist because this linter scored 90 passed / 0 failed while
# TWO scheduled workflows were broken. It was measuring the wrong things
# confidently, which is the failure mode this repository is built to refuse.
#
# MEASURED 2026-08-02: verify.yml had NEVER run. Dispatched by hand it returned
# `startup_failure` -- no jobs, no logs, no check run, nothing to read. Its
# `gates` job calls ci.yml, ci.yml declares `permissions: contents: read,
# actions: read`, and verify.yml granted `contents` only. A called workflow's
# permissions may never exceed its caller's, so the run was refused at parse
# time, every Monday, invisibly.
#
# INVISIBLY is the important word: a scheduled run that never starts produces
# no notification and no red tick anywhere. Only asking for it by hand found it.
# =============================================================================
echo
echo "-- a caller grants every permission its called workflow requests (R19) --"

perms_of () {   # perms_of <file> -> "key:value" lines from the TOP-LEVEL permissions block
  awk '
    /^permissions:[[:space:]]*$/ { inp = 1; next }
    inp && /^[^[:space:]#]/      { inp = 0 }
    inp && /^[[:space:]]+[a-z-]+:[[:space:]]*[a-z-]+/ {
      line = $0
      sub(/#.*$/, "", line)
      gsub(/[[:space:]]/, "", line)
      if (line != "") print line
    }
  ' "$1"
}

r19_bad=0
for caller in .github/workflows/*.yml; do
  # Find every local reusable workflow this file calls.
  callees=$(sed 's/#.*$//' "$caller" \
            | sed -n 's|^[[:space:]]*uses:[[:space:]]*\./\(\.github/workflows/[A-Za-z0-9_.-]*\.yml\).*|\1|p' \
            | sort -u)
  [ -n "$callees" ] || continue
  for callee in $callees; do
    if [ ! -f "$callee" ]; then
      bad "R19: $(basename "$caller") calls $callee, which does not exist"
      r19_bad=1
      continue
    fi
    # The callee must be callable at all.
    # NO `| grep -q`. checker/portability.sh forbids that shape repo-wide --
    # grep -q exits early, SIGPIPEs the writer, and under `set -o pipefail` the
    # status then depends on the platform's pipe buffer. I wrote this rule
    # violating it and the repo's own gate went red on me, which is the gate
    # working. Capture, then match.
    callee_src=$(sed 's/#.*$//' "$callee")
    case "$callee_src" in
      *workflow_call*) : ;;
      *) bad "R19: $(basename "$caller") calls $(basename "$callee"), which lacks 'workflow_call'"
         r19_bad=1 ;;
    esac
    caller_perms=$(perms_of "$caller")
    for want in $(perms_of "$callee"); do
      key="${want%%:*}"
      case "
$caller_perms" in
        *"
$key:"*) granted=1 ;;
        *) granted=0 ;;
      esac
      if [ "$granted" -eq 0 ]; then
        bad "R19: $(basename "$callee") requests '$key' but $(basename "$caller") never grants it -- the run is refused at STARTUP, with no log"
        r19_bad=1
      fi
    done
  done
done
[ "$r19_bad" -eq 0 ] && ok "every reusable-workflow caller grants what its callee requests"

# CONTROL: the rule must be able to fire. Planted in a scratch pair, not in the
# real tree -- a control that edits the files it is checking cannot be trusted.
RCTL="$(mktemp -d "${TMPDIR:-/tmp}/rotmoe-r19.XXXXXX")"
mkdir -p "$RCTL/.github/workflows"
printf 'name: callee\non:\n  workflow_call:\npermissions:\n  contents: read\n  actions: read\njobs:\n  a:\n    runs-on: ubuntu-latest\n' > "$RCTL/.github/workflows/callee.yml"
printf 'name: caller\non:\n  workflow_dispatch:\npermissions:\n  contents: write\njobs:\n  g:\n    uses: ./.github/workflows/callee.yml\n' > "$RCTL/.github/workflows/caller.yml"
missing=0
for want in $(perms_of "$RCTL/.github/workflows/callee.yml"); do
  key="${want%%:*}"
  cp_=$(perms_of "$RCTL/.github/workflows/caller.yml")
  case "
$cp_" in *"
$key:"*) : ;; *) missing=1 ;; esac
done
if [ "$missing" -eq 1 ]; then
  ok "CONTROL: a caller missing 'actions' IS detected (the exact verify.yml defect)"
else
  bad "CONTROL DEAD: the R19 detector cannot see a missing permission"
fi
# And the repaired shape must NOT be flagged, or the rule would forbid a
# correct future rather than a broken one.
printf 'name: caller\non:\n  workflow_dispatch:\npermissions:\n  contents: write\n  actions: read\njobs:\n  g:\n    uses: ./.github/workflows/callee.yml\n' > "$RCTL/.github/workflows/caller.yml"
missing=0
for want in $(perms_of "$RCTL/.github/workflows/callee.yml"); do
  key="${want%%:*}"
  cp_=$(perms_of "$RCTL/.github/workflows/caller.yml")
  case "
$cp_" in *"
$key:"*) : ;; *) missing=1 ;; esac
done
[ "$missing" -eq 0 ] && ok "CONTROL: the repaired caller is NOT flagged" \
                     || bad "CONTROL: the rule flags a CORRECT caller -- it would block a valid fix"
rm -rf "$RCTL"

# =============================================================================
# R20 -- `grep -c` INSIDE A PIPELINE UNDER `pipefail` KILLS THE STEP WHEN THE
#        REPOSITORY IS CLEAN.
#
# MEASURED the same day, in ads-manager.yml, which had also never run:
#     set -euo pipefail
#     NATIVE=$(grep -rc 'native_decide' lean/Proofs/*.lean | awk '...')
# `grep -c` prints its zero counts AND EXITS 1 when nothing matched. pipefail
# propagates that, `set -e` kills the step. It failed BECAUSE the corpus has no
# native_decide -- and would have passed the moment someone added one.
#
# An alarm that fires on correctness and falls silent on the defect is worse
# than no alarm at all.
# =============================================================================
echo
echo "-- no 'grep -c' piped under pipefail without a status rescue (R20) --"
r20_bad=0
for wf in .github/workflows/*.yml; do
  wf_src=$(sed 's/#.*$//' "$wf")
  case "$wf_src" in *pipefail*) : ;; *) continue ;; esac
  while IFS= read -r hit; do
    # A heredoc ALWAYS delivers one line, so an empty command substitution
    # arrives as a single empty string. Without this guard the rule reported a
    # violation for every workflow that had none -- flagged three clean files on
    # its first run, with a blank line number and blank text as the evidence.
    [ -n "$hit" ] || continue
    ln="${hit%%:*}"; txt="${hit#*:}"
    case "$txt" in
      *"|| true"*|*"|| echo"*|*"|| :"*) : ;;   # status explicitly rescued
      *) bad "R20: $(basename "$wf"):$ln  grep -c/-o pipes under pipefail with no rescue -- fails when nothing matches: $(printf '%s' "$txt" | sed 's/^[[:space:]]*//' | cut -c1-70)"
         r20_bad=1 ;;
    esac
  done <<EOF
$(sed 's/#.*$//' "$wf" | grep -nE 'grep -[A-Za-z]*[co][A-Za-z]* [^|]*\|')
EOF
done
[ "$r20_bad" -eq 0 ] && ok "no unrescued 'grep -c' or 'grep -o' pipeline in any workflow that sets pipefail"

# CONTROL: both directions, on planted text.
probe_r20 () {   # probe_r20 <line> -> "FLAG" | "CLEAN"
  case "$1" in
    *"|| true"*|*"|| echo"*|*"|| :"*) echo CLEAN ;;
    *grep\ -*c*\|*) echo FLAG ;;
    *grep\ -*o*\|*) echo FLAG ;;
    *) echo CLEAN ;;
  esac
}
[ "$(probe_r20 "N=\$(grep -rc 'x' f | awk '{s+=\$2}')")" = "FLAG" ] \
  && ok "CONTROL: an unrescued grep -c pipeline IS flagged (the ads-manager.yml defect)" \
  || bad "CONTROL DEAD: the R20 detector cannot see an unrescued grep -c"
[ "$(probe_r20 "N=\$(grep -rc 'x' f | awk '{s+=\$2}' || true)")" = "CLEAN" ] \
  && ok "CONTROL: the rescued form is NOT flagged" \
  || bad "CONTROL: the rule flags the CORRECT form -- it would block the fix"
# `grep -o` was added to this rule AFTER it let a real defect through: ads-manager.yml
# step 6 died on `MUT=$(grep -oE '...' STATUS.md | head -1)` under pipefail, and R20
# saw nothing because it only knew about -c. Measured: run 30742048586. A widened rule
# whose control still only exercises the OLD flag proves nothing about the widening,
# so -o gets its own pair.
[ "$(probe_r20 "MUT=\$(grep -oE 'x' STATUS.md | head -1)")" = "FLAG" ] \
  && ok "CONTROL: an unrescued grep -o pipeline IS flagged (the ads-manager.yml step 6 defect)" \
  || bad "CONTROL DEAD: the R20 detector cannot see an unrescued grep -o"
[ "$(probe_r20 "MUT=\$(grep -oE 'x' STATUS.md | head -1 || true)")" = "CLEAN" ] \
  && ok "CONTROL: the rescued grep -o form is NOT flagged" \
  || bad "CONTROL: the rule flags the CORRECT grep -o form -- it would block the fix"

# ---------------------------------------------------------------------------
# R21 -- EVERY `run:` BLOCK IS ITS OWN SHELL. An array built in one step does
# NOT exist in the next one, and bash under `set -u` says so only at RUNTIME:
#
#     tag-manager.yml, run 30751...: "TAGS: unbound variable", exit 1
#
# The step had been reviewed, linted and committed with all gates green,
# because nothing static was looking for it. It is the same family as the
# earlier finding that `env` cannot exec a shell function: a thing that looks
# like one continuous script is not one.
#
# The rule is narrow ON PURPOSE. It matches ARRAY expansion -- ${X[@]} and
# ${#X[@]} -- which is unambiguous, rather than every bare $VAR, which would
# drown in `env:` entries, GitHub contexts and exported variables and would
# then be turned off. A rule people switch off protects nothing.
echo
echo "-- every run: block defines the arrays it expands (R21) --"
R21AWK="$(mktemp "${TMPDIR:-/tmp}/r21.XXXXXX")"
cat > "$R21AWK" <<'R21EOF'
function flush(  i){ for(i=1;i<=nu;i++) if(!(uses[i] in defs)) print FILENAME ":" useln[i] ":" uses[i]; nu=0; delete defs }
BEGIN{ inb=0; nu=0 }
/^[[:space:]]*run:[[:space:]]*\|/ { if(inb) flush(); inb=1; ind=match($0,/[^ ]/); delete defs; nu=0; next }
inb {
  if ($0 ~ /^[[:space:]]*$/) next
  cur=match($0,/[^ ]/)
  if (cur <= ind) { flush(); inb=0; next }
  line=$0
  if (match(line,/mapfile[[:space:]]+-t[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/)) { s=substr(line,RSTART,RLENGTH); sub(/.*[[:space:]]/,"",s); defs[s]=1 }
  if (match(line,/^[[:space:]]*(declare[[:space:]]+-a[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=\(/)) { s=substr(line,RSTART,RLENGTH); sub(/^[[:space:]]*/,"",s); sub(/^declare[[:space:]]+-a[[:space:]]+/,"",s); sub(/=\(.*/,"",s); defs[s]=1 }
  if (match(line,/read[[:space:]]+-a[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/)) { s=substr(line,RSTART,RLENGTH); sub(/.*[[:space:]]/,"",s); defs[s]=1 }
  while (match(line,/\$\{#?[A-Za-z_][A-Za-z0-9_]*\[@\]\}/)) {
    m=substr(line,RSTART,RLENGTH); gsub(/[${}#]|\[@\]/,"",m)
    nu++; uses[nu]=m; useln[nu]=NR
    line=substr(line,RSTART+RLENGTH)
  }
}
END{ if(inb) flush() }
R21EOF
r21hits=0
for wf in .github/workflows/*.yml; do
  [ -f "$wf" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    r21hits=$((r21hits+1))
    bad "R21: ${hit%:*} expands array '${hit##*:}' that no line in the SAME run: block defines -- a separate step is a separate shell"
  done < <(awk -f "$R21AWK" "$wf" 2>/dev/null || true)
done
[ "$r21hits" -eq 0 ] && ok "every run: block defines the arrays it expands"

# CONTROLS, both directions, on the REAL defect rather than a toy. The first
# plants the exact tag-manager shape that failed; the second is the committed
# fix, which must NOT be flagged or the rule would block its own repair.
# THE FIXTURE NEEDLE IS BUILT, NEVER WRITTEN LITERALLY -- the same rule this
# repository already applies to annotation tokens. checker/portability.sh greps
# source text for bash-4-only constructs and correctly flagged these fixtures,
# which are DATA for a temp file and never executed here. Concatenating the word
# keeps the fixture exact while leaving nothing for a text scan to trip on.
MAPF="map""file"
R21BAD="$(mktemp "${TMPDIR:-/tmp}/r21bad.XXXXXX")"
printf 'jobs:\n  x:\n    steps:\n      - name: a\n        run: |\n          %s -t TAGS < <(x)\n      - name: b\n        run: |\n          echo "${#TAGS[@]}"\n' "$MAPF" > "$R21BAD"
n_bad=$(awk -f "$R21AWK" "$R21BAD" 2>/dev/null | grep -c . || true)
[ "$n_bad" -ge 1 ] \
  && ok "CONTROL: an array built in ANOTHER step IS flagged (the tag-manager.yml defect)" \
  || bad "CONTROL DEAD: R21 cannot see the cross-step array use it exists for"
R21GOOD="$(mktemp "${TMPDIR:-/tmp}/r21good.XXXXXX")"
printf 'jobs:\n  x:\n    steps:\n      - name: b\n        run: |\n          %s -t TAGS < <(x)\n          for t in "${TAGS[@]}"; do echo "$t"; done\n' "$MAPF" > "$R21GOOD"
n_good=$(awk -f "$R21AWK" "$R21GOOD" 2>/dev/null | grep -c . || true)
[ "$n_good" -eq 0 ] \
  && ok "CONTROL: an array defined in the SAME block is NOT flagged" \
  || bad "CONTROL: R21 flags the correct form -- it would block the fix"
rm -f "$R21AWK" "$R21BAD" "$R21GOOD"

# --- 6. nobody may re-derive the release map by reading the packager's TEXT ---
#
# MEASURED 2026-08-05. checker/release-package.sh once defined
#
#     VARIANTS="core:0.6.0 lean:0.6.1 unsealed:0.6.2"
#
# and two gates recovered it with `sed -n 's/^VARIANTS="\(.*\)"$/\1/p'`. Then the
# packager started COMPUTING the versions from plugin.json --
#
#     VARIANTS="core:$_MM.0 lean:$_MM.1 unsealed:$_MM.2"
#
# -- and the sed began returning that line verbatim, unexpanded. release-install
# was repaired to run `release-package.sh --print-variants`; release-session was
# NOT, and spent an unknown number of releases hunting an archive named
# `rot-moe-$_MM.0-core.zip`. It could not pass, and it was still counted as one
# of the deep gates.
#
# The rule is the general one, so a third copy cannot repeat it: ASK the packager,
# never read its source. Any file that greps VARIANTS out of the packager's text
# is flagged, whatever it does with the result.
# The predicate must separate the BROKEN form from the CORRECT one, and the
# first draft of it did not: `VARIANTS=.*release-package` matches
# `VARIANTS=$(bash .../release-package.sh --print-variants)` just as happily as
# the sed. It flagged the file that had already been REPAIRED -- a rule that
# condemns the fix is worse than no rule, because the way to make it green is to
# undo the repair.
#
# So: a line that names the packager AND pulls text out of it with a text tool,
# while NOT asking it via --print-variants.
_reads_packager_text () {   # 1 = offends
  _t="$(mktemp "${TMPDIR:-/tmp}/rotmoe-vscan.XXXXXX")"
  sed 's/#.*$//' "$1" > "$_t"
  # `grep -c` PRINTS 0 and EXITS 1 when there is no match, so `|| printf 0`
  # appends a SECOND zero and produces two lines. `[ -eq ]` then fails with
  # "integer expression expected" -- observed here on line 926. The same defect
  # is already recorded in checker/ci-honesty.sh; take grep's output as-is.
  _hits=$(grep -c -E 'release-package[^ ]*\.sh' "$_t" 2>/dev/null); _hits=${_hits:-0}
  if [ "${_hits:-0}" -eq 0 ]; then rm -f "$_t"; return 1; fi
  _bad_lines=$(grep -E 'release-package[^ ]*\.sh' "$_t" \
               | grep -v -- '--print-variants' \
               | grep -c -E '(sed|awk|grep|cat|head|tail)[[:space:]]' 2>/dev/null)
  _bad_lines=${_bad_lines:-0}
  rm -f "$_t"
  [ "${_bad_lines:-0}" -gt 0 ]
}
_vt=0
for _f in checker/*.sh lean/mutate/*.sh .github/workflows/*.yml; do
  [ -f "$_f" ] || continue
  case "$_f" in checker/release-package.sh|checker/workflow-lint.sh) continue ;; esac
  if _reads_packager_text "$_f"; then
    bad "$_f reads the release map out of release-package.sh's SOURCE TEXT -- run it with --print-variants instead"
    _vt=1
  fi
done
[ "$_vt" -eq 0 ] && ok "no file re-derives the release map by parsing the packager's source"

# TWO CONTROLS, because this rule has to tell two similar lines apart and a
# single control could only prove one half.
_VCTL="$(mktemp "${TMPDIR:-/tmp}/rotmoe-vctl.XXXXXX")"
printf 'VARIANT_MAP=$(sed -n %ss/^VARIANTS=x/p%s "$REPO/checker/release-package.sh")\n' "'" "'" > "$_VCTL"
if _reads_packager_text "$_VCTL"; then
  ok "CONTROL: the old source-parsing form IS detected"
else
  bad "CONTROL DEAD: the source-parsing form is not detected -- rule 6 proves nothing"
fi
printf 'VARIANTS=$(bash "$REPO/checker/release-package.sh" --print-variants | head -1)\n' > "$_VCTL"
if _reads_packager_text "$_VCTL"; then
  bad "CONTROL: the CORRECT --print-variants form is flagged -- the rule punishes the fix"
else
  ok "CONTROL: asking the packager with --print-variants is NOT flagged"
fi
rm -f "$_VCTL"

# --- 7. no checker may pipe into `grep -q` while `pipefail` is set -----------
#
# MEASURED TWICE, and the second time it was the repair itself that was
# incomplete -- which is the whole argument for making it a rule instead of a
# habit.
#
#   set -o pipefail
#   producer | grep -q PATTERN
#
# `grep -q` exits at the FIRST match. The producer then writes into a closed
# pipe, takes SIGPIPE, and dies with 141. Under `pipefail` the pipeline's status
# is the rightmost non-zero one, so A SUCCESSFUL MATCH REPORTS FAILURE. Whether
# it happens depends on whether the producer finishes first -- file size, machine
# speed, runner load. It is a RACE, and it fails in the direction that looks like
# a real defect:
#
#   CI:  hooks/prover-remind.ps1 builds with no ROTMOE_LEAN_VERIFY opt-out
#        (the file contains that string three times)
#   CI:  the shipping reminder carries only 0 of 3 guards
#        (it carries all three)
#
# The first was fixed by rewriting eleven assertions across eleven files. The
# second came from TWO SITES IN THE SAME FILE that the sweep missed, because they
# were counters rather than assertions. A sweep done by eye finds what it is
# looking for; this finds what is there.
#
# Both cures are one character: grep a FILE instead of a pipeline, or use
# `grep -c ... >/dev/null`, which consumes the whole stream and so never
# signals the producer. Identical exit semantics either way.
_pf=0
for _f in checker/*.sh lean/mutate/*.sh; do
  [ -f "$_f" ] || continue
  case "$_f" in checker/workflow-lint.sh) continue ;; esac   # this file: the controls below
  grep -qE '^[[:space:]]*set .*(pipefail)' "$_f" || continue
  # TWO CARVE-OUTS, both measured as false positives on the first run, both
  # narrow and both stated rather than silently widened:
  #
  #   `||` IS NOT A PIPE. `grep -qE "$A" "$F" || grep -qE "$B" "$F"` greps two
  #   FILES and is perfectly safe, but a naive `\|` matches the second bar of the
  #   `||`. Requiring a non-bar before the bar excludes it, and still catches
  #   every real pipeline, which by definition has something else to its left.
  #
  #   A FIXTURE IS NOT CODE. checker/portability.sh WRITES a little script
  #   containing this exact hazard, on purpose, to prove its own rule can see one.
  #   Flagging that would be the third time in this file that a rule punished the
  #   control written to keep it honest. Lines that are a printf/echo/cat
  #   REDIRECTED INTO A FILE are building a fixture, not running a pipeline.
  #
  #   A MESSAGE IS NOT A PIPELINE either. checker/portability.sh reports
  #   `ok "CONTROL: a planted printf|grep -q IS detected"` -- prose describing the
  #   hazard, inside a string, in the file that proves it can find one. `ok` and
  #   `bad` take a single message argument and never pipe, so a line that STARTS
  #   with one is excluded. `printf`/`echo` are NOT excluded on that basis, since
  #   `echo "$x" | grep -q y` is a genuine instance of the hazard.
  _n=$(sed 's/#.*$//' "$_f" \
       | grep -v -E '^[[:space:]]*((printf|echo|cat)[[:space:]].*>|(ok|bad)[[:space:]])' \
       | grep -c -E '[^|][|][[:space:]]*grep[[:space:]]+-[A-Za-z]*q')
  if [ "${_n:-0}" -gt 0 ]; then
    bad "$_f pipes into 'grep -q' under pipefail ($_n site(s)) -- SIGPIPE 141 makes a MATCH report failure"
    _pf=1
  fi
done
[ "$_pf" -eq 0 ] && ok "no checker pipes into 'grep -q' while pipefail is set"

# TWO CONTROLS again: the rule must catch the hazard AND leave the cure alone.
_PCTL="$(mktemp "${TMPDIR:-/tmp}/rotmoe-pctl.XXXXXX")"
# SIGPIPE-ALLOW -- this line BUILDS the hazard as a fixture, on purpose, so that
# rule 7 can be proved able to see one. checker/portability.sh carries an older,
# narrower version of this same rule (it recognises only printf/echo/cat as the
# producer, which is why it never saw the `sed`, `locale -a` and `head -c` sites
# that CI hit) and it offers this marker as the documented escape for controls.
# Used rather than loosening either rule: a pragma on one line is auditable, a
# widened pattern is not.
printf 'set -uo pipefail\nsed s/x/y/ f | grep -q PATTERN || bad "missing"\n' > "$_PCTL"   # SIGPIPE-ALLOW
_n=$(sed 's/#.*$//' "$_PCTL" | grep -v -E '^[[:space:]]*((printf|echo|cat)[[:space:]].*>|(ok|bad)[[:space:]])' | grep -c -E '[^|][|][[:space:]]*grep[[:space:]]+-[A-Za-z]*q')
[ -n "$_n" ] || _n=0
[ "${_n:-0}" -gt 0 ] \
  && ok "CONTROL: a pipe into 'grep -q' under pipefail IS detected" \
  || bad "CONTROL DEAD: the SIGPIPE hazard is not detected -- rule 7 proves nothing"
printf 'set -uo pipefail\nsed s/x/y/ f | grep -c PATTERN >/dev/null || bad "missing"\ngrep -q P file || bad "x"\n' > "$_PCTL"
_n=$(sed 's/#.*$//' "$_PCTL" | grep -v -E '^[[:space:]]*((printf|echo|cat)[[:space:]].*>|(ok|bad)[[:space:]])' | grep -c -E '[^|][|][[:space:]]*grep[[:space:]]+-[A-Za-z]*q')
[ -n "$_n" ] || _n=0
[ "${_n:-0}" -eq 0 ] \
  && ok "CONTROL: the two cures (grep -c, or grep a FILE) are NOT flagged" \
  || bad "CONTROL: rule 7 flags the fix -- it would push the tree back to the hazard"
rm -f "$_PCTL"

# --- R22: a platform dispatch must be EXHAUSTIVE, and must SAY which branch ran
#
# MEASURED 2026-08-06, and this linter passed the broken file 144/144.
#
# An edit to the `tty guard` step deleted the `else` keyword from an
# `if / elif / else` chain. The result is still valid shell, so nothing textual
# objected -- but on Windows NEITHER branch ran: `rc` took the exit status of the
# failed `elif` TEST (0), `tty.out` was never created, and the step fell through
# to assertions about a pty it had never allocated. On macOS it was worse: the
# fallback body had been absorbed into the BSD branch, so it ran AFTER the real
# pty probe and OVERWROTE its result. That leg reported PASS while asserting
# nothing whatever about a terminal.
#
# A dispatch that silently selects NO branch is the same defect as a skipped
# step wearing a different hat: it concludes success having tested nothing. A
# text linter cannot see control flow, so it checks for the GUARD instead --
# the branch marker and the refusal that fires when no branch set it.
echo
echo "-- exhaustive platform dispatch (R22) --"
_CI=".github/workflows/ci.yml"
if [ -f "$_CI" ]; then
  _alloc=$(grep -c 'ALLOC="' "$_CI"); _alloc=${_alloc:-0}
  if [ "$_alloc" -ge 3 ]; then
    ok "the pty dispatch names its branch ($_alloc assignments: GNU / BSD / none)"
  else
    bad "the pty dispatch has $_alloc branch markers -- a branch that does not name itself cannot be shown to have run"
  fi
  if grep -q 'no pty-allocator branch ran' "$_CI"; then
    ok "an unselected dispatch is REFUSED (the missing-else defect cannot recur silently)"
  else
    bad "the exhaustiveness refusal is gone: a dispatch selecting NO branch would report success"
  fi
  if grep -q 'tty.out was never created' "$_CI"; then
    ok "a selected branch that produced no artifact is REFUSED"
  else
    bad "no artifact check: a branch could be named without ever running"
  fi
  # CONTROL: the rule must be able to fail. Strip the refusal from a copy.
  _CCTL="$(mktemp)"
  grep -v 'no pty-allocator branch ran' "$_CI" > "$_CCTL"
  if grep -q 'no pty-allocator branch ran' "$_CCTL"; then
    bad "CONTROL DEAD: R22 cannot detect a removed exhaustiveness guard"
  else
    ok "CONTROL: removing the refusal IS detectable -- R22 can fire"
  fi
  rm -f "$_CCTL"
else
  bad "$_CI is missing -- R22 cannot be evaluated, and that is not a pass"
fi

# --- R23: a `push:` trigger with `paths:` MUST also constrain `branches:` -----
#
# MEASURED 2026-08-06. `.github/workflows/tag-manager.yml` declared
#
#     push:
#       paths: [".github/tags.txt"]
#
# with no `branches:`. Pushing v0.8.0 / v0.8.1 / v0.8.2 in one command fired
# THREE runs of it, on a commit that does not touch `.github/tags.txt`
# (`git show --stat --name-only 4a783a9 | grep -c tags.txt` -> 0). A path filter
# cannot be evaluated for a tag ref, so it restrains nothing; only `branches:`
# excludes tags.
#
# The damage was the CONCLUSION, not the wasted minutes. That workflow holds one
# concurrency group with `cancel-in-progress: false`, and GitHub keeps at most
# ONE pending run per group -- so the third push cancelled the second, and tag
# v0.8.1 carried a run concluding `cancelled` with ZERO jobs. `cancelled` is
# exactly what checker/ci-honesty.sh refuses. Tag v0.7.0 has the same scar,
# which is how one structural defect passed for bad luck twice.
#
# Proved in lean/Proofs/RotGates.lean: `paths_do_not_restrain_a_tag` (a
# branch-less trigger fires on EVERY tag, for every path list) and
# `branches_exclude_every_tag` (any non-empty branches list excludes them all).
echo
echo "-- push triggers constrain branches (R23) --"
_R23TMP="$(mktemp -d)"
# NOT `printf ... | grep -q`. checker/portability.sh refuses that shape, and it
# is right to: with `pipefail` set, grep -q exits at its first match and the
# SIGPIPE it delivers to the writer makes the pipeline's status
# platform-dependent. Every probe below reads a FILE.
_r23_onblock() {  # $1 = workflow file, $2 = destination for its `on:` block
  awk '/^on:/{f=1;next} /^[a-z_]+:/{f=0} f' "$1" > "$2"
}
_r23_count() {    # $1 = file, $2 = ERE -> prints a count, never empty
  local _n; _n=$(grep -cE "$2" "$1" 2>/dev/null); printf '%s' "${_n:-0}"
}
_r23_seen=0
for _wf in .github/workflows/*.yml; do
  [ -f "$_wf" ] || continue
  # The `on:` block only. A `paths:` under `jobs:` or inside a step is not a
  # trigger filter and must not be mistaken for one.
  _r23_onblock "$_wf" "$_R23TMP/on.txt"
  [ "$(_r23_count "$_R23TMP/on.txt" '^[[:space:]]+push:')" -gt 0 ] || continue
  _r23_seen=$((_r23_seen+1))
  _haspaths=$(_r23_count "$_R23TMP/on.txt" '^[[:space:]]+paths:')
  _hasbr=$(_r23_count "$_R23TMP/on.txt" '^[[:space:]]+branches:')
  if [ "$_haspaths" -gt 0 ] && [ "$_hasbr" -eq 0 ]; then
    bad "$(basename "$_wf"): push has paths: but no branches: -- it fires on EVERY tag push"
  else
    ok "$(basename "$_wf"): push trigger constrains branches (or filters no paths)"
  fi
done
if [ "$_r23_seen" -eq 0 ]; then
  bad "R23 examined no workflow with a push trigger -- the rule is not covering anything"
else
  ok "R23 examined $_r23_seen workflow(s) with a push: trigger"
fi
# CONTROL: the rule must be able to FIRE. Rebuild the defective shape and run
# the SAME predicate over it. Without this, R23 passing means nothing.
printf 'on:\n  push:\n    paths:\n      - ".github/tags.txt"\n  workflow_dispatch:\n\njobs:\n  x:\n    runs-on: ubuntu-latest\n' > "$_R23TMP/bad.yml"
_r23_onblock "$_R23TMP/bad.yml" "$_R23TMP/badon.txt"
_bp=$(_r23_count "$_R23TMP/badon.txt" '^[[:space:]]+paths:')
_bb=$(_r23_count "$_R23TMP/badon.txt" '^[[:space:]]+branches:')
if [ "$_bp" -gt 0 ] && [ "$_bb" -eq 0 ]; then
  ok "CONTROL: the branch-less push trigger IS detected -- R23 can fire"
else
  bad "CONTROL DEAD: R23 did not flag a paths-only push trigger (paths=$_bp branches=$_bb)"
fi
# CONTROL 2: adding branches: must CLEAR it, or the rule is a constant `bad`
# that would block a correct workflow -- the failure mode this repo calls a
# spec that forbids a correct future.
printf 'on:\n  push:\n    branches: [main]\n    paths:\n      - ".github/tags.txt"\n' > "$_R23TMP/good.yml"
_r23_onblock "$_R23TMP/good.yml" "$_R23TMP/goodon.txt"
_gb=$(_r23_count "$_R23TMP/goodon.txt" '^[[:space:]]+branches:')
if [ "$_gb" -gt 0 ]; then
  ok "CONTROL: adding branches: clears R23 -- the rule is not a constant failure"
else
  bad "CONTROL DEAD: R23 flags a CORRECT trigger -- it would block a valid workflow"
fi
rm -rf "$_R23TMP"

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  workflow-lint: PASS"; exit 0; } || { echo "  workflow-lint: FAIL"; exit 1; }
