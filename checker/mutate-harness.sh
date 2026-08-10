#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE MUTATION HARNESS ITSELF IS AN INSTRUMENT, AND NOBODY WAS CHECKING IT.
#
# Measured 2026-08-10, and it is the worst class of defect this repo hunts:
#
#   MUT_ONLY=NOSUCHID bash lean/mutate/mutate_rotpartialrun.sh
#     -> "All 0 mutants killed (13 ran, 0 survived, 0 discarded)."
#     -> exit 0
#
# Nothing ran. Both figures in that sentence were false. `skipped` was counted,
# folded into the total, and never consulted by the verdict. 21 of the 37 suites
# that accept MUT_ONLY behaved that way -- the same second-counter defect CP51
# fixed in ci-dryrun.sh and CP52 in mutate-checker.sh, which never reached the
# per-module suites.
#
# Two more copy-paste defects surfaced in the same sweep, both of the "the
# evidence printed is not the evidence" family:
#
#   * 8 suites grepped `error: Proofs/RotTrap.lean:` while mutating a DIFFERENT
#     module, so the "which theorems died" field was always EMPTY. It read as
#     "nothing could be named" rather than "the extractor is looking elsewhere".
#   * 7 suites ended with `lake build Proofs.RotOrdering` under a comment reading
#     "a suite must leave the tree GREEN". The assertion passed whenever
#     RotOrdering built -- whether or not the mutated module was restored.
#
# All three are proved in lean/Proofs/RotSuiteVerdict.lean. This checker is what
# stops them coming back, because the fix was mechanical and so is the relapse.
#
# Exit: 0 all checks pass | 1 a defect is present | 2 the checker cannot run
# =============================================================================
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
MUTDIR="$REPO/lean/mutate"
passed=0; failed=0

ok  () { printf '  ok   %s\n' "$1"; passed=$((passed+1)); }
bad () { printf '  FAIL %s\n' "$1"; failed=$((failed+1)); }

[ -d "$MUTDIR" ] || { echo "FATAL: $MUTDIR not found"; exit 2; }

# THE REPO PATH CONTAINS SPACES ("C:/GIT External Repo/RoT MoE").
#
# The first version of this file iterated `for f in $SUITES` over an unquoted
# variable. Every path split on its spaces, every grep failed with
# "grep: /c/GIT: Is a directory", not one suite was read -- AND THE CHECKER
# EXITED 0, because a failing grep just means "no match", which reads as "no
# defect found". That is the exact fake green this file was written to catch,
# committed by the file itself within minutes of being written.
#
# Two changes, both load-bearing: iterate line by line so a path may contain
# spaces, and REFUSE when a suite cannot be read. "I could not open it" and
# "it is clean" must never produce the same exit code.
SUITES_FILE=$(mktemp "${TMPDIR:-/tmp}/muths.XXXXXX") || { echo "FATAL: mktemp failed"; exit 2; }
trap 'rm -f "$SUITES_FILE"' EXIT INT TERM
ls "$MUTDIR"/mutate_*.sh > "$SUITES_FILE" 2>/dev/null

_n_suites=$(wc -l < "$SUITES_FILE" | tr -d ' ')
[ "${_n_suites:-0}" -gt 0 ] || { echo "FATAL: no mutation suites found. Refusing to report a"; \
  echo "clean sweep over an empty set -- that is the very defect this file exists for."; exit 2; }

# Every suite must be readable before any verdict is formed over the set.
_unreadable=0
while IFS= read -r f; do
  [ -r "$f" ] || { printf '  FAIL unreadable suite: %s\n' "$f"; _unreadable=$((_unreadable+1)); }
done < "$SUITES_FILE"
if [ "$_unreadable" -gt 0 ]; then
  echo "FATAL: $_unreadable suite(s) could not be read. A sweep that cannot open its"
  echo "inputs has measured nothing, and must not be reported as a clean one."
  exit 2
fi

echo "== mutation harness integrity :: $_n_suites suite(s) =="

# ---------------------------------------------------------------------------
# 1. EVERY SUITE THAT ACCEPTS A FILTER MUST REFUSE A FILTERED RUN.
#
# Two accepted shapes, because the directory has two generations and both are
# correct: the older suites branch on `filtered`, the newer ones on `skipped`.
# The rule is the BEHAVIOUR -- a partial run must not exit 0 -- so the check
# accepts either spelling rather than freezing one house style.
# ---------------------------------------------------------------------------
_unguarded=""
_filterable=0
while IFS= read -r f; do
  grep -q 'MUT_ONLY' "$f" || continue
  _filterable=$((_filterable+1))
  if grep -qE '\$filtered" -eq 1|\{filtered:-0\}" -eq 1|\$\{?skipped[:"]?[^=]*-gt 0' "$f"; then
    :
  else
    _unguarded="$_unguarded $(basename "$f")"
  fi
done < "$SUITES_FILE"
if [ -z "$_unguarded" ]; then
  ok "all $_filterable filterable suite(s) refuse a partial run (no fake green)"
else
  bad "suite(s) with MUT_ONLY and NO partial-run guard -- a filtered run exits 0:"
  for s in $_unguarded; do printf '         %s\n' "$s"; done
fi

# ---------------------------------------------------------------------------
# 2. NO SUITE MAY NAME A MODULE OTHER THAN ITS OWN.
#
# Derived, not frozen: the expected name comes from the suite's own `F=` line,
# so adding a module moves this automatically. A hard-coded roster here would be
# the same stale snapshot the defect came from.
# ---------------------------------------------------------------------------
_wrong_grep=""; _wrong_build=""
while IFS= read -r f; do
  own=$(sed -n 's|^F="Proofs/\([A-Za-z0-9]*\)\.lean"|\1|p' "$f" | head -1)
  [ -n "$own" ] || own=$(grep -oE 'Proofs/[A-Za-z0-9]+\.lean' "$f" | head -1 | sed 's|Proofs/||; s|\.lean||')
  [ -n "$own" ] || continue
  # A literal module name inside the error-line pattern that is not this module.
  while read -r m; do
    [ -z "$m" ] && continue
    [ "$m" = "$own" ] || _wrong_grep="$_wrong_grep $(basename "$f"):$m"
  done <<EOF
$(grep -o 'error: Proofs/[A-Za-z0-9]*' "$f" | sed 's|error: Proofs/||' | sort -u)
EOF
  while read -r m; do
    [ -z "$m" ] && continue
    [ "$m" = "$own" ] || _wrong_build="$_wrong_build $(basename "$f"):$m"
  done <<EOF
$(grep -o 'lake build Proofs\.[A-Za-z0-9]*' "$f" | sed 's|lake build Proofs\.||' | sort -u)
EOF
done < "$SUITES_FILE"
if [ -z "$_wrong_grep" ]; then
  ok "no suite extracts dead theorems from another module's error lines"
else
  bad "suite(s) grepping the WRONG module -- the attribution field is always empty:"
  for s in $_wrong_grep; do printf '         %s\n' "$s"; done
fi
if [ -z "$_wrong_build" ]; then
  ok "no suite verifies its baseline by rebuilding a different module"
else
  bad "suite(s) rebuilding the WRONG module -- the green says nothing about the mutated one:"
  for s in $_wrong_build; do printf '         %s\n' "$s"; done
fi

# ---------------------------------------------------------------------------
# 3. NEGATIVE CONTROLS. An alarm nobody has tripped on purpose is untested.
#
# Each control builds a suite that IS defective and asserts this checker's own
# predicates catch it. Without these, a checker whose regex silently stopped
# matching would report a clean sweep forever.
# ---------------------------------------------------------------------------
CTL=$(mktemp -d "${TMPDIR:-/tmp}/muthc.XXXXXX") || { echo "FATAL: mktemp failed"; exit 2; }
trap 'rm -rf "$CTL"' EXIT INT TERM

cat > "$CTL/mutate_fake.sh" <<'EOF'
F="Proofs/RotFake.lean"
if [ -n "${MUT_ONLY:-}" ]; then :; fi
dead=$(grep -oE "^error: Proofs/RotTrap\.lean:[0-9]+" x)
( cd . && lake build Proofs.RotOrdering )
EOF

_c=0
if grep -q 'MUT_ONLY' "$CTL/mutate_fake.sh" && \
   ! grep -qE '\$filtered" -eq 1|\{filtered:-0\}" -eq 1|\$\{?skipped[:"]?[^=]*-gt 0' "$CTL/mutate_fake.sh"; then
  _c=$((_c+1))
else
  bad "control 1 DID NOT FIRE: an unguarded suite was not detected as unguarded"
fi
# R20: NEVER pipe into `grep -q` under `set -o pipefail`.
#
# `grep -q` exits the instant it matches, closing the pipe; the upstream grep
# then dies of SIGPIPE (141), and pipefail reports 141 for the whole pipeline --
# so A MATCH REPORTS FAILURE. checker/workflow-lint.sh caught both of these
# sites in this very file minutes after it was written, which is the rule doing
# its job on its author. The fix is to collect first and test the string.
_m2=$(grep -o 'error: Proofs/[A-Za-z0-9]*' "$CTL/mutate_fake.sh" | grep -v 'RotFake')
if [ -n "$_m2" ]; then
  _c=$((_c+1))
else
  bad "control 2 DID NOT FIRE: a wrong-module grep was not detected"
fi
_m3=$(grep -o 'lake build Proofs\.[A-Za-z0-9]*' "$CTL/mutate_fake.sh" | grep -v 'RotFake')
if [ -n "$_m3" ]; then
  _c=$((_c+1))
else
  bad "control 3 DID NOT FIRE: a wrong-module rebuild was not detected"
fi
[ "$_c" -eq 3 ] && ok "3/3 negative controls fired on a deliberately defective suite"

# ---------------------------------------------------------------------------
# 4. ONE LIVE BEHAVIOURAL PROBE. Static text is not behaviour.
#
# Static checks 1-3 read source. This RUNS a suite with a filter that selects
# nothing and asserts the exit code is 3. It is bounded to one suite because
# each invocation builds a baseline; the static sweep covers the rest.
#
# ROTMOE_HARNESS_PROBE names the suite; the default is the one the defect was
# measured on. Exit code read DIRECTLY -- reading it through a pipe is what
# produced a false green in this repository before.
# ---------------------------------------------------------------------------
PROBE="${ROTMOE_HARNESS_PROBE:-mutate_rotpartialrun.sh}"
if [ ! -f "$MUTDIR/$PROBE" ]; then
  bad "live probe SKIPPED: $PROBE not found -- a static-only pass is weaker than advertised"
elif [ ! -d "$REPO/lean/.lake/packages" ]; then
  # Not a pass and not a failure: say so, and let the caller decide.
  echo "  ---- live probe not run: lean/ is not a built workspace (would download mathlib)"
  echo "       static checks above still applied to all $_n_suites suite(s)."
else
  ( cd "$REPO/lean" && MUT_ONLY=NOSUCHID bash "mutate/$PROBE" ) > "$CTL/probe.log" 2>&1
  _rc=$?
  if [ "$_rc" -eq 3 ]; then
    ok "live probe: $PROBE with a filter matching NOTHING exits 3 (PARTIAL, never a pass)"
  elif [ "$_rc" -eq 0 ]; then
    bad "live probe: $PROBE ran ZERO mutants and exited 0 -- THE FAKE GREEN IS BACK"
    tail -3 "$CTL/probe.log" | sed 's/^/         /'
  else
    bad "live probe: $PROBE exited $_rc, expected 3"
    tail -3 "$CTL/probe.log" | sed 's/^/         /'
  fi
fi

echo
echo "mutate-harness: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
exit 0
