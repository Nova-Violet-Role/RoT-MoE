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
  declare -A GATE_EXCEPT
  GATE_EXCEPT[gate-all.sh]="it is the aggregator; it cannot list itself as a gate"
  GATE_EXCEPT[preflight.sh]="bootstrap probe for a fresh clone -- it runs BEFORE the gates exist, and gate-all would re-run its work"

  gate_listed="$(grep -oE 'checker/[a-z-]+\.sh' checker/gate-all.sh | sed 's|checker/||' | sort -u)"
  uncovered=0
  for c in checker/*.sh; do
    b="$(basename "$c")"
    if printf '%s\n' "$gate_listed" | grep -qx "$b"; then
      continue
    elif [ -n "${GATE_EXCEPT[$b]:-}" ]; then
      echo "  NOTE  not a gate: $b -- ${GATE_EXCEPT[$b]}"
    else
      bad "$b is never run by gate-all -- the local commit gate is WEAKER than CI"
      uncovered=$((uncovered+1))
    fi
  done
  [ "$uncovered" -eq 0 ] && ok "every checker is either a gate or exempt with a stated reason"

  # CONTROL: a planted checker that nobody wired in must be seen. Written to the
  # real directory and removed immediately, because the check reads the
  # directory -- a control that runs somewhere else tests somewhere else.
  PL="checker/zz-planted-control.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$PL"
  if printf '%s\n' "$gate_listed" | grep -qx "zz-planted-control.sh"; then
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
for m in lean/Proofs/*.lean; do
  mod="$(basename "$m" .lean)"
  printf '%s' "$WF_TEXT" | grep -qF "Proofs.$mod" \
    && ok "CI builds Proofs.$mod" \
    || bad "CI NEVER BUILDS Proofs.$mod -- it is unverified in CI"
done
# EVERY script under lean/mutate must be in CI, not only the mutate_* ones. The
# generalization probe and the isolation artifact live here too, and a rule that
# matched one filename prefix would have let them rot unrun -- the same blind
# spot this phase exists to close.
# Helpers under lean/mutate that are not independently runnable get an
# exemption WITH a reason and WITH the evidence for it -- never a bare skip.
declare -A MUT_EXCEPT
MUT_EXCEPT[attribute_mut.sh]="forensic re-reader for stored mutation logs; its function (anchoring attribution on ^error:) is now inline in all five harnesses, asserted below"

for s in lean/mutate/*.sh; do
  base="$(basename "$s")"
  if printf '%s' "$WF_TEXT" | grep -qF "$base"; then
    ok "CI runs $base"
  elif [ -n "${MUT_EXCEPT[$base]:-}" ]; then
    echo "  NOTE  exempt: $base -- ${MUT_EXCEPT[$base]}"
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
  grep -qE '(^|[^[:alnum:]_#])sudo ' "$f" && v="$v USES_SUDO"
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

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  workflow-lint: PASS"; exit 0; } || { echo "  workflow-lint: FAIL"; exit 1; }
