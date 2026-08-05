#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# EVERY GATE, ONE EXIT CODE.
#
# WHY THIS EXISTS, stated plainly because the reason is a mistake I made:
# I ran the checkers by hand in one shell block, two of them returned 1, and the
# `git commit` in the same block ran ANYWAY because it did not depend on their
# exit codes. The commit message said the work was verified. Two gates were red.
#
# That is the exact false green this whole repo is built to prevent, and the
# reason it happened is that the discipline was MANUAL. A rule you have to
# remember is a rule you will eventually forget at 2am. So it becomes a program
# with one exit code, and a pre-commit hook that refuses.
#
#   bash checker/gate-all.sh && git commit ...
#
# DELIBERATELY NOT INCLUDED, and this is a design decision rather than an
# oversight: the Lean build, the mutation suites, and the live-session smoke.
# They need a mathlib toolchain and minutes of wall clock, and a pre-commit hook
# that takes four minutes is a hook people disable -- which would leave the fast
# checks unenforced too, a net loss. Those run in CI, where minutes are free.
# `--full` opts into them locally when you want the whole thing.
#
# Exit codes:  0 all green   1 at least one gate red   3 nothing ran (a bug)
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

# =============================================================================
# THE TIERS -- and why an unqualified run still executes everything.
#
# MEASURED 2026-08-01, per gate, on this machine: the set below takes 587
# SECONDS. The header above warns that "a pre-commit hook that takes four
# minutes is a hook people disable" -- and the set had quietly become one, at
# nearly ten. Two commits were killed by a wall-clock ceiling mid-run, and one
# of those kills left a live mutant plus four `.mutbak` files on disk.
#
# Four gates own 76% of that: mutate the checker (198 s), axiom audit (94 s),
# axiom class (84 s), release install (71 s).
#
# So each gate now declares a TIER and, if deep, the path prefixes that make it
# relevant:
#
#     fast  -- cheap, and it can be broken by editing almost anything. Always runs.
#     deep  -- expensive, and it reads a specific part of the tree. Runs when the
#              commit TOUCHES that part, and always in a full sweep.
#
# THE DANGER, stated because this repo has already been bitten by exactly it:
# a tier is a way to make a gate INVISIBLE, and invisible looks identical to
# green. `verdict-schedule-sim.sh` sat behind FULL=1, was red, and the default
# local sweep printed "26/26 GREEN" for weeks. Two structural answers:
#
#   1. A BARE `gate-all.sh` STILL RUNS THE WHOLE TABLE. The split is opt-in
#      `--fast`). Nobody gets a weaker run by accident, and CI is untouched.
#   2. A deep gate with an EMPTY trigger list is refused below, because nothing
#      could ever escalate it. That is `RotGates.no_trigger_never_escalates`
#      turned into a runtime refusal; `checker/gate-split.sh` checks the whole
#      table against the Lean witness in `lean/Proofs/RotGates.lean`.
#
# Format:  name|tier|comma,separated,triggers|command
# =============================================================================

MODE=all
case "${1:-}" in
  --full)   MODE=full ;;
  --fast)   MODE=fast ;;
  --staged) MODE=staged ;;
  "")       MODE=all ;;
  *) echo "usage: gate-all.sh [--fast|--staged|--full]"; exit 2 ;;
esac

GATES="
count-theorems selftest|fast||bash checker/count-theorems.sh --selftest
SPDX sweep|fast||sh checker/spdx-sweep.sh
no machine-local paths|fast||sh checker/no-local-paths.sh
install-document lint|fast||bash checker/claude-md-lint.sh
licence bridge|fast||bash checker/license-bridge.sh
release consistency|fast||bash checker/release-consistency.sh
tag consistency|fast||bash checker/tags-consistency.sh
verdict freshness|fast||bash checker/verdict-fresh.sh
mutation discipline|fast||bash checker/mutant-discipline.sh
dorks|fast||bash checker/dorks.sh
hook footprint|fast||bash checker/hook-footprint.sh
Lean witness vs shipped weights|fast||bash checker/lean-binds-shell.sh
release package|fast||bash checker/release-package.sh
hook contract|fast||bash checker/hook-contract.sh
workflow lint + drift|fast||bash checker/workflow-lint.sh
cross-diff (both router arms)|fast||bash checker/cross-diff.sh
router duplication (plugin + ARM must not stack)|fast||bash checker/router-duplication.sh
disarm safety (--dry-run writes nothing, --all reaches plugin entries)|fast||bash checker/disarm-safety.sh
remind measure (both arms, one tree, nested proof)|fast||bash checker/remind-measure.sh
log replay (every gauge record recomputed from its own fields)|fast||bash checker/log-replay.sh
benchmark|fast||bash checker/bench-router.sh
gate split|fast||bash checker/gate-split.sh
repo completeness|deep|README.md,CHANGELOG.md,STATUS.md,lean/|bash checker/repo-complete.sh
cross-diff (both reminder arms)|deep|hooks/prover-remind|bash checker/cross-diff-remind.sh
verdict stability|deep|STATUS.md,checker/verdict|bash checker/verdict-stability.sh
gauge cross|deep|hooks/rot-router,lean/Proofs/RotGauge.lean|bash checker/gauge-cross.sh
profile binding|deep|engine/rot-lean.md,lean/Proofs/RotAbility.lean|bash checker/profile-bind.sh
axiom audit|deep|lean/|bash checker/axiom-audit.sh
axiom class|deep|lean/|bash checker/axiom-class.sh
mutate the checker|deep|checker/,hooks/|bash checker/mutate-checker.sh
portability|deep|checker/,hooks/,ARM_ROUTER,DISARM_ROUTER,.githooks/|bash checker/portability.sh
installer round trip|deep|ARM_ROUTER,DISARM_ROUTER,checker/install,.claude-plugin/|bash checker/install-roundtrip.sh
install parity|deep|ARM_ROUTER,DISARM_ROUTER,hooks/hooks.json,hooks/settings-merge.js|bash checker/install-parity.sh
release install|deep|checker/release,.claude-plugin/|bash checker/release-install.sh
"

if [ "$MODE" = full ]; then
  GATES="$GATES
ci dry run (the CI step list, clean clone)|deep|.github/|bash checker/ci-dryrun.sh
generalization probe (does each theorem CONSTRAIN its function)|deep|lean/|cd lean && bash mutate/generalization_probe.sh
scheduled verdict, three weeks with a remote|deep|STATUS.md,checker/verdict|bash checker/verdict-schedule-sim.sh
plugin + fresh-user install|deep|.claude-plugin/,ARM_ROUTER|bash checker/plugin-install.sh
marketplace session (install as a stranger, router in the loop)|deep|.claude-plugin/,hooks/|bash checker/marketplace-session.sh
live-session smoke|deep|hooks/,agents/|bash checker/live-session-smoke.sh
release session (every variant, every lane, real CLI)|deep|checker/release|bash checker/release-session.sh
sustained session (cloned auth, plugin installed, real conversation)|deep|hooks/|bash checker/release-longsession.sh
CTT session report (the 80-turn corpus the README quotes)|deep|hooks/,checker/ctt-session.sh|bash checker/ctt-session.sh --report
deferred closure (the runner ran what the dry run could not)|deep|.github/|bash checker/deferred-closure.sh
"
fi

# --- what this commit staged, for --staged ----------------------------------
# Read ONCE, here, so the selection below is a pure function of a fixed list.
STAGED=""
if [ "$MODE" = staged ]; then
  STAGED="$(git diff --cached --name-only 2>/dev/null)"
  # An empty staged list is not an invitation to run nothing. It means this was
  # invoked outside a commit (or with nothing added), and the honest response is
  # the conservative one: run everything, exactly as a bare invocation does.
  if [ -z "$STAGED" ]; then
    echo "gate-all: --staged with an EMPTY staged list -- running the FULL set."
    echo "          A commit that stages nothing must not get a weaker run."
    MODE=all
  fi
fi

# Does any staged path start with any of this gate's triggers?
# Prefix matching, mirroring RotGates.hits: `lean/` fires on `lean/Proofs/X.lean`.
fires() {
  _trigs="$1"
  [ -z "$_trigs" ] && return 1
  _oldifs="$IFS"; IFS=','
  for _t in $_trigs; do
    IFS="$_oldifs"
    [ -z "$_t" ] && continue
    printf '%s\n' "$STAGED" | while IFS= read -r _p; do
      case "$_p" in "$_t"*) exit 7 ;; esac
    done
    [ "$?" -eq 7 ] && return 0
    IFS=','
  done
  IFS="$_oldifs"
  return 1
}

# =============================================================================
# PREFLIGHT: REFUSE TO RUN ON A TREE A MUTATION SUITE LEFT BEHIND.
#
# MEASURED 2026-07-31. A gate-all run was interrupted while `mutate-checker.sh`
# had a mutant applied. Its restore is an EXIT trap, and a process that does not
# reach its trap does not restore: the tree was left with mutant H07 live in
# `hooks/rot-router.sh` and four `.mutbak` files sitting beside it. Every
# subsequent checker then measured THE MUTANT and called it the baseline.
#
# The damage was caught by an unrelated cross-check disagreeing, which is luck,
# not method. A `.mutbak` on disk is unambiguous evidence that a suite did not
# finish, and it is cheap to look for -- so the roll-up now refuses rather than
# certifying a tree whose state is unknown. Recovery is stated, not implied,
# because the backups ARE the repair.
# =============================================================================
leftover="$(find . -name '*.mutbak' -not -path './.git/*' 2>/dev/null)"
if [ -n "$leftover" ]; then
  echo "REFUSING: a mutation suite did not finish -- these .mutbak files remain:"
  printf '%s\n' "$leftover" | sed 's/^/    /'
  echo
  echo "The tree may still carry a live mutant, and every gate below would be"
  echo "measuring it instead of the baseline. Restore each file from its backup"
  echo "(cp <f>.mutbak <f>), delete the backups, and re-run."
  exit 2
fi

# =============================================================================
# PREFLIGHT 2: VALIDATE THE WHOLE TABLE BEFORE RUNNING ANYTHING.
#
# This ran inline in the loop first, and the negative control showed why that
# was wrong: the refusal fired only when the bad row was REACHED, after ten
# gates had already printed `0`. A reader skimming that output sees a column of
# greens above a refusal and has to work out which one won. Validate first, run
# second -- then a malformed table costs nothing and reads unambiguously.
#
# Two refusals, both structural:
#   * an unknown tier      -- a gate whose schedule nobody decided
#   * deep with no triggers -- invisible to every commit, which is the FULL=1
#     defect exactly. Runtime form of RotGates.no_trigger_never_escalates.
# =============================================================================
while IFS='|' read -r name tier trigs cmd; do
  [ -z "${name:-}" ] && continue
  [ -z "${cmd:-}" ]  && continue
  case "${tier:-}" in
    fast) : ;;
    deep)
      if [ -z "${trigs:-}" ]; then
        echo "REFUSING: deep gate '$name' declares NO triggers."
        echo "Nothing could ever escalate it, so it would run only in a full"
        echo "sweep while reading as covered. Give it trigger paths or make it"
        echo "fast. See lean/Proofs/RotGates.lean:no_trigger_never_escalates."
        exit 2
      fi ;;
    *)
      echo "REFUSING: gate '$name' has tier '${tier:-<empty>}' (expected fast|deep)."
      echo "An untiered gate is a gate whose schedule nobody decided."
      exit 2 ;;
  esac
done <<EOF
$GATES
EOF

ran=0; red=0
LOGDIR="$(mktemp -d "${TMPDIR:-/tmp}/gateall.XXXXXX")"
printf '%-34s %s\n' "GATE" "EXIT"
printf '%-34s %s\n' "----------------------------------" "----"

skipped=0
while IFS='|' read -r name tier trigs cmd; do
  [ -z "${name:-}" ] && continue
  [ -z "${cmd:-}" ]  && continue

  if [ "$MODE" = fast ] && [ "$tier" = deep ]; then
    skipped=$((skipped+1)); continue
  fi
  if [ "$MODE" = staged ] && [ "$tier" = deep ]; then
    if ! fires "$trigs"; then
      skipped=$((skipped+1)); continue
    fi
  fi

  ran=$((ran+1))
  # Exit code read DIRECTLY. Never through a pipe -- a pipe reports the LAST
  # command's status, which is how a false green gets manufactured.
  sh -c "$cmd" > "$LOGDIR/$ran.log" 2>&1
  rc=$?
  if [ "$rc" -eq 3 ]; then
    printf '%-34s %s\n' "$name" "SKIP (3) -- never a pass"
  elif [ "$rc" -ne 0 ]; then
    printf '%-34s %s\n' "$name" "RED ($rc)"
    red=$((red+1))
    echo "      ---- last 12 lines ----"
    tail -12 "$LOGDIR/$ran.log" | sed 's/^/      /'
  else
    printf '%-34s %s\n' "$name" "0"
  fi
done <<EOF
$GATES
EOF

echo
if [ "$ran" -eq 0 ]; then
  echo "NOTHING RAN -- the gate list did not parse. This is a bug, not a pass."
  rm -rf "$LOGDIR"; exit 3
fi

# Say what was NOT run, every time, and say it in the same breath as the green.
# A summary that reports only what passed is how a narrowed run gets mistaken
# for a full one -- which is the FULL=1 defect wearing a different hat.
if [ "$skipped" -gt 0 ]; then
  echo "mode=$MODE -- $skipped deep gate(s) NOT RUN (untouched by this commit)."
  echo "             They are not passes. Run 'gate-all.sh' bare for all $(printf '%s' "$GATES" | grep -c '|')."
fi

if [ "$red" -eq 0 ]; then
  echo "ALL $ran GATES GREEN."
  rm -rf "$LOGDIR"; exit 0
else
  echo "$red of $ran GATES RED. Logs kept in $LOGDIR"
  echo "Do NOT commit on top of this."
  exit 1
fi
