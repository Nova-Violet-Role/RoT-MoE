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

FULL=0
[ "${1:-}" = "--full" ] && FULL=1

# name:command -- the FAST gates, the ones that must never be skipped.
GATES="
count-theorems selftest|bash checker/count-theorems.sh --selftest
repo completeness|bash checker/repo-complete.sh
SPDX sweep|sh checker/spdx-sweep.sh
no machine-local paths|sh checker/no-local-paths.sh
Lean witness vs shipped weights|bash checker/lean-binds-shell.sh
workflow lint + drift|bash checker/workflow-lint.sh
cross-diff (both router arms)|bash checker/cross-diff.sh
cross-diff (both reminder arms)|bash checker/cross-diff-remind.sh
install-document lint|bash checker/claude-md-lint.sh
licence bridge (NOTICE vs disk)|bash checker/license-bridge.sh
tag consistency (local half of R18)|bash checker/tags-consistency.sh
gauge cross (Lean mirror vs hook)|bash checker/gauge-cross.sh
mutate the checker|bash checker/mutate-checker.sh
installer round trip|bash checker/install-roundtrip.sh
"

if [ "$FULL" -eq 1 ]; then
  GATES="$GATES
ci dry run (the CI step list, clean clone)|bash checker/ci-dryrun.sh
plugin + fresh-user install|bash checker/plugin-install.sh
live-session smoke|bash checker/live-session-smoke.sh
"
fi

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

ran=0; red=0
LOGDIR="$(mktemp -d "${TMPDIR:-/tmp}/gateall.XXXXXX")"
printf '%-34s %s\n' "GATE" "EXIT"
printf '%-34s %s\n' "----------------------------------" "----"

while IFS='|' read -r name cmd; do
  [ -z "${name:-}" ] && continue
  [ -z "${cmd:-}" ]  && continue
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

if [ "$red" -eq 0 ]; then
  echo "ALL $ran GATES GREEN."
  rm -rf "$LOGDIR"; exit 0
else
  echo "$red of $ran GATES RED. Logs kept in $LOGDIR"
  echo "Do NOT commit on top of this."
  exit 1
fi
