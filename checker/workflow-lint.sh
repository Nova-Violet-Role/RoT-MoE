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
  esac
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

WF_TEXT="$(cat .github/workflows/*.yml)"
for c in checker/*.sh; do
  base="$(basename "$c")"
  if contains "$WF_TEXT" "$base"; then
    ok "wired into a workflow: $base"
  elif [ -n "$(except_reason "$base")" ]; then
    echo "  NOTE  exempt: $base -- $(except_reason "$base")"
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
    b="$(basename "$c")"
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
    gb="$(basename "$g")"
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
  mod="$(basename "$m" .lean)"
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
  contains_line "$_narrow" "$(basename "$m" .lean)" || _missed=$((_missed+1))
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
  base="$(basename "$s")"
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
  b="$(basename "$h")"
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
if grep -q 'LEAN_ROOT' "$MCTL/mutate_broken.sh" || grep -qE 'preflight|FATAL' "$MCTL/mutate_broken.sh"; then
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
  sed 's/#.*$//' "$f" | sed -E 's/(say|echo|printf).*$//' | grep -qE '(^|[^[:alnum:]_])sudo ' && v="$v USES_SUDO"
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

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  workflow-lint: PASS"; exit 0; } || { echo "  workflow-lint: FAIL"; exit 1; }
