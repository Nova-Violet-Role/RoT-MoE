#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# R14 -- the checker itself must be able to fail.
#
# A checker nobody has broken on purpose is an untested alarm. This breaks the
# SHIPPED HOOKS deliberately, one defect at a time, and requires cross-diff.sh
# to go RED for each. A mutant that leaves it green is a hole in the checker and
# is reported as SURVIVED -- a finding about the checker, never about the hook.
#
# Same contract as the Lean mutation suites, for the same reason:
#   * the needle must be present EXACTLY ONCE before the edit, else DISCARDED
#   * the replacement must be present and the needle gone after it
#   * DISCARDED is never folded into SURVIVED -- they mean opposite things
#   * the tree is restored and re-verified green at the end
#
# H00 is the meta-control and it runs FIRST: a no-op edit must leave the checker
# GREEN. Without it, a checker that failed on absolutely everything would score
# a perfect 8/8 here and look excellent.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SH="$REPO/hooks/rot-router.sh"
PS1="$REPO/hooks/rot-router.ps1"
LOG="${TMPDIR:-/tmp}/rotmoe-mutchk"; mkdir -p "$LOG"

cp "$SH" "$SH.mutbak"; cp "$PS1" "$PS1.mutbak"
killed=0; survived=0; discarded=0

restore () { cp "$SH.mutbak" "$SH"; cp "$PS1.mutbak" "$PS1"; }

run () {  # run <id> <file> <needle> <replacement> <expect: RED|GREEN> <note>
  local id="$1" f="$2" needle="$3" repl="$4" expect="$5" note="$6"
  restore
  local n; n=$(grep -F -c -- "$needle" "$f")
  if [ "$n" -ne 1 ]; then
    echo "$id  DISCARDED  needle occurs $n times, expected 1 -- patch NOT applied"
    discarded=$((discarded+1)); return
  fi
  awk -v needle="$needle" -v repl="$repl" '{
    p = index($0, needle)
    if (p > 0) { $0 = substr($0,1,p-1) repl substr($0, p+length(needle)) }
    print }' "$f.mutbak" > "$f"
  if [ "$(grep -F -c -- "$needle" "$f")" -ne 0 ] || [ "$(grep -F -c -- "$repl" "$f")" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed -- patch NOT applied"
    discarded=$((discarded+1)); restore; return
  fi

  bash "$REPO/checker/cross-diff.sh" > "$LOG/$id.log" 2>&1
  local rc=$?
  if [ "$expect" = "GREEN" ]; then
    if [ "$rc" -eq 0 ]; then echo "$id  OK (meta-control) checker stayed GREEN on a no-op -- $note"; killed=$((killed+1))
    else echo "$id  META-CONTROL FAILED: the checker goes red on a NO-OP edit."
         echo "     It is not measuring the hooks; every other row below is worthless."
         survived=$((survived+1)); fi
  else
    if [ "$rc" -ne 0 ]; then
      echo "$id  KILLED     checker went RED (exit $rc) -- $note"; killed=$((killed+1))
    else
      echo "$id  SURVIVED   checker stayed GREEN -- HOLE IN THE CHECKER: $note"; survived=$((survived+1))
    fi
  fi
  restore
}

echo "=== R14: breaking the shipped hooks on purpose ==="

run H00 "$SH" \
  '# --- THE GAUGE ---' \
  '# --- THE GAUGE (no-op comment edit) ---' \
  GREEN 'meta-control: a comment change must not turn the checker red'

run H01 "$SH" \
  "LAMBDAS='1.4 0.6 1.9 1.2 0.6 1.0 1.0 1.2 2.3'" \
  "LAMBDAS='1.4 0.6 1.9 1.2 0.6 1.0 1.0 1.2 2.4'" \
  RED 'one lambda changed in the POSIX arm (Claude 2.3 -> 2.4)'

run H02 "$PS1" \
  '$Lambdas = @(1.4, 0.6, 1.9, 1.2, 0.6, 1.0, 1.0, 1.2, 2.3)' \
  '$Lambdas = @(1.4, 0.6, 1.9, 1.2, 0.6, 1.0, 1.0, 1.2, 2.4)' \
  RED 'one lambda changed in the WINDOWS arm only -- the arms must disagree'

run H03 "$SH" \
  'R = sum / K;' \
  'R = 1.2;' \
  RED 'gauge hardcoded to a constant -- the "the number is decoration" failure mode'

run H04 "$SH" \
  'MUS=' \
  'MUS_UNUSED=' \
  RED 'mu vector detached -- every quality multiplier silently becomes empty'

# H05 REPLACED, and the reason is a finding rather than a fix.
#
# The first H05 inverted the entropy clamp (`if (H > 1.0) H = 1.0` -> `= 0.0`)
# and SURVIVED. That was scored as a hole in the checker. It is not: the clamp
# is UNREACHABLE. Activities are 0 or 1 and the branch is guarded by
# `breadth > 0`, so H = a/breadth <= 1 always -- which is exactly what
# entropyAt_le_one proves in lean/Proofs/RotGauge.lean. The clamp is defensive
# code that no input can execute, and mutating unreachable code and demanding a
# red was MY design error, not a gap in the corpus.
#
# It is still worth writing down: a clamp that can never fire is decoration in
# the same sense a theorem no mutation can kill is decoration. It stays in the
# source because it is cheap and because the invariant it guards is only proved
# in Lean, not enforced by the shell -- but it is not a check.
#
# The replacement mutates the line that IS reachable: the breadth bonus itself.
run H05 "$SH" \
  'H  = (breadth > 0 ? act / breadth : 0.0);' \
  'H  = 0.0;' \
  RED 'breadth bonus removed entirely -- (1+H) collapses to 1 for every lens'

# Needle corrected: the source aligns the assignment with TWO spaces (`s  =`).
# The first version used one and was correctly DISCARDED at zero occurrences --
# the guard doing its job. A `>= 1` guard would have silently done nothing here
# and reported SURVIVED.
run H06 "$SH" \
  's  = 1.0 / (1.0 + exp(-4.0 * (d - 0.5)));' \
  's  = 1.0 / (1.0 + exp(4.0 * (d - 0.5)));' \
  RED 'sigmoid slope sign flipped -- divergence now PENALISED instead of rewarded'

run H07 "$SH" \
  'if   fired "$_p" "$STEMS_FORGE";      then echo "FORGE Claude"' \
  'if   fired "$_p" "$STEMS_CLINICAL";   then echo "CLINICAL AntiVenom"' \
  RED 'TIER 1 priority reordered -- FORGE no longer wins its collisions'

run H08 "$SH" \
  "STEMS_STEALTH='encod optim token compress concise byte distill'" \
  "STEMS_STEALTH='encod optim concise byte distill'" \
  RED 'two stems deleted from a lane -- a prompt stops reaching its lead'

# H09 REPLACED. The original needle contained `\.` regex escapes; passing them
# through `awk -v` mangled the backslashes, the replacement never matched, and
# the harness reported DISCARDED. That is the guard working -- but the lesson is
# the one this project keeps relearning: NEEDLES WITH BACKSLASHES ARE WHERE
# STRING-SURGERY HARNESSES LIE. The replacement below contains none.
run H09 "$SH" \
  'printf "R/s+ = %s [%s] mean=%s breadth=%d K=%d lenses=%s' \
  'printf "R/s = %s [%s] mean=%s breadth=%d K=%d lenses=%s' \
  RED 'output label changed by one character -- proves the comparison is BYTE-for-byte, not numeric'

# H10 -- the locale trap, and its result is ENVIRONMENT-DEPENDENT, so it is
# probed rather than assumed. If a comma-decimal locale is not installed, awk
# falls back to C, the mutation cannot express itself, and the honest answer is
# SKIPPED. Reporting that as SURVIVED would claim a hole in the checker; as
# KILLED it would claim a guarantee never tested. Neither is true.
CLOC=""
for cand in de_DE.UTF-8 de_DE.utf8 fr_FR.UTF-8 it_IT.UTF-8; do
  # THE PROBE THAT MATTERED. The first version asked `locale -a` whether the
  # locale EXISTS, found de_DE, forced it, saw no change and reported SURVIVED
  # -- i.e. "hole in the checker". The truth was the opposite: the mutation
  # could not express itself, because awk in this build formats %.2f in the C
  # locale REGARDLESS of LC_ALL. Existence of a locale is not the same question
  # as whether the formatter honours it, and only the second one is the test.
  #
  # Measured here: LC_ALL=de_DE.UTF-8 awk 'BEGIN{printf "%.2f",0.09}' -> 0.09
  #                LC_ALL=de_DE.UTF-8 printf '%.2f' 0.09              -> 0,00
  #                                    ...and printf REJECTS 0.09 as invalid.
  # So the trap is real for printf(1) and inert for this awk. LC_ALL=C is
  # therefore defence in depth here and load-bearing on a glibc CI runner.
  if [ "$(LC_ALL=$cand awk 'BEGIN{printf "%.2f", 0.09}' 2>/dev/null)" = "0,09" ]; then
    CLOC="$cand"; break
  fi
done
if [ -n "$CLOC" ]; then
  run H10 "$SH" 'LC_ALL=C' "LC_ALL=$CLOC" \
    RED "THE LOCALE TRAP under $CLOC: 0.09 must not render 0,09"
else
  echo "H10  INEXPRESSIBLE  no available locale makes this awk emit a comma"
  echo "     decimal, so the trap CANNOT be triggered against the gauge on this"
  echo "     machine. Recorded as INEXPRESSIBLE -- not KILLED (which would claim"
  echo "     a guarantee never tested) and not SURVIVED (which would claim a hole"
  echo "     that does not exist). A glibc CI runner can express it; the"
  echo "     locale-invariance phase in cross-diff.sh is what exercises it there."
fi

restore
bash "$REPO/checker/cross-diff.sh" > "$LOG/baseline.log" 2>&1
base=$?
rm -f "$SH.mutbak" "$PS1.mutbak"

echo "---"
echo "killed=$killed survived=$survived discarded=$discarded"
echo "baseline restored -> cross-diff exit=$base"
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && [ "$base" -eq 0 ] && exit 0 || exit 1
