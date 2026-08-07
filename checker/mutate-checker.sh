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
# Organ 4 -- the reminder arms. Mutated by the same harness because they are
# shipped code with two implementations that must agree, exactly like the
# router. A second pair of arms with no mutation suite would be the "instrument
# exists, nobody broke it on purpose" state this file was written to end.
RSH="$REPO/hooks/prover-remind.sh"
RPS1="$REPO/hooks/prover-remind.ps1"
LOG="${TMPDIR:-/tmp}/rotmoe-mutchk"; mkdir -p "$LOG"

# RECOVER BEFORE BACKING UP, and this ordering is the whole point.
#
# MEASURED 2026-08-05, and it came within one command of being committed: a run
# of this script was KILLED (a harness bounds command duration; `timeout` sends
# SIGKILL, and an EXIT trap does not fire for SIGKILL). It left hooks/rot-router.sh
# EMPTIED -- that is one of the mutants below -- plus four .mutbak files.
#
# The next run then did the worst possible thing: it copied the EMPTY file over
# the good backup and called it the baseline. Twelve mutants came back DISCARDED
# (their needles no longer existed), and the "restored baseline" cross-diff went
# red, because what was restored was the mutant.
#
# So: if a .mutbak survives from a previous run, the file it backs up is by
# construction the PRE-MUTATION original, and the live file may be a mutant.
# Restore first, always, before any new backup is taken. A harness that cannot
# recover from being killed will eventually hand a mutant to the next reader --
# and here that reader was `git commit`.
for f in "$SH" "$PS1" "$RSH" "$RPS1"; do
  if [ -f "$f.mutbak" ]; then
    if ! cmp -s "$f" "$f.mutbak"; then
      echo "RECOVERED: $f differed from a leftover $f.mutbak -- a previous run was"
      echo "           interrupted mid-mutation. Restoring the backup as the baseline."
    fi
    # Atomic, for the same reason as `restore` below: a kill inside a plain `cp`
    # truncates the destination, and here the destination is a shipped hook.
    cp "$f.mutbak" "$f.rtmp" && mv -f "$f.rtmp" "$f"
    rm -f "$f.mutbak"
  fi
  # A leftover .rtmp/.mtmp is the HALF that was being written when a previous
  # run died. It is disposable by construction -- the rename never happened, so
  # the real file still holds whichever complete version it had. This is the one
  # kind of leftover it IS safe to delete, and the distinction from .mutbak (the
  # only copy of an original, never delete) is the whole point of the two names.
  rm -f "$f.rtmp" "$f.mtmp"
done

for f in "$SH" "$PS1" "$RSH" "$RPS1"; do cp "$f" "$f.mutbak"; done

# RESTORE AND CLEAN UP ON *ANY* EXIT, not just the happy path. MEASURED
# 2026-08-05: this script restores the files and removes the backups at the very
# end, as plain statements. An interrupted run -- a timeout, a Ctrl-C, a harness
# that bounds command duration -- never reaches them, and leaves four .mutbak
# files in hooks/.
#
# That is not a cosmetic leftover. checker/gate-all.sh REFUSES to run while any
# .mutbak exists, because the tree may still carry a live mutant and every gate
# below would be measuring it. So one interrupted run of this file blocks the
# pre-commit hook and every subsequent gate sweep, with a message about a live
# mutant that is no longer there. Measured: it blocked a commit.
#
# A trap costs one line and makes the failure impossible. The final `rm -f` is
# kept as well; running it twice is harmless, and the trap must not be the only
# thing standing between a normal run and a clean tree.
trap 'for _tf in "$SH" "$PS1" "$RSH" "$RPS1"; do
        [ -f "$_tf.mutbak" ] && { cp "$_tf.mutbak" "$_tf.rtmp" && mv -f "$_tf.rtmp" "$_tf"; }
        rm -f "$_tf.mutbak" "$_tf.rtmp" "$_tf.mtmp"
      done' EXIT INT TERM

killed=0; survived=0; discarded=0

# THE LOOP VARIABLE IS `_rf`, AND THAT IS LOAD-BEARING. It was `f`, and `run()`
# declares `local f` for the file it is about to mutate -- bash has DYNAMIC
# scope, so `restore` (called from inside `run`) silently reassigned the
# caller's `f` to the LAST file in this list. Every router mutation then
# measured its needle against `prover-remind.ps1`, found 0, and reported
# DISCARDED: 12 of them in one run.
#
# It failed in the safe direction by luck, not by design. Had any needle also
# existed in the last file of the list, the harness would have mutated the WRONG
# FILE and reported the result as if it had mutated the right one. `local` on
# the loop variable is the fix; the rename is what makes it obvious.
# ATOMIC, and the reason is measured. 2026-08-07: a SIGKILL landing inside a
# plain `cp` left hooks/prover-remind.sh and .ps1 at ZERO BYTES -- the
# destination had been truncated and not yet rewritten, and the .mutbak was
# already gone, so nothing on disk held the original. Only the pre-commit
# zero-byte guard stopped an empty hook from being committed.
#
# Writing to a temp file and renaming makes the swap ONE filesystem operation:
# an interruption leaves the OLD content or the NEW content, never a truncated
# file. lean/Proofs/RotObserve.lean §16 states it as a property.
restore () { local _rf; for _rf in "$SH" "$PS1" "$RSH" "$RPS1"; do cp "$_rf.mutbak" "$_rf.rtmp" && mv -f "$_rf.rtmp" "$_rf"; done; }

# run <id> <file> <needle> <replacement> <expect: RED|GREEN> <note> [checker]
# The 7th argument names the checker to run; it defaults to the router
# cross-diff so every existing call site keeps its meaning unchanged.
run () {
  local id="$1" f="$2" needle="$3" repl="$4" expect="$5" note="$6"
  local checker="${7:-checker/cross-diff.sh}"
  restore
  local n; n=$(grep -F -c -- "$needle" "$f")
  if [ "$n" -ne 1 ]; then
    echo "$id  DISCARDED  needle occurs $n times, expected 1 -- patch NOT applied"
    discarded=$((discarded+1)); return
  fi
  awk -v needle="$needle" -v repl="$repl" '{
    p = index($0, needle)
    if (p > 0) { $0 = substr($0,1,p-1) repl substr($0, p+length(needle)) }
    print }' "$f.mutbak" > "$f.mtmp" && mv -f "$f.mtmp" "$f"
  if [ "$(grep -F -c -- "$needle" "$f")" -ne 0 ] || [ "$(grep -F -c -- "$repl" "$f")" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed -- patch NOT applied"
    discarded=$((discarded+1)); restore; return
  fi

  bash "$REPO/$checker" > "$LOG/$id.log" 2>&1
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

# The needle moved when the stem was added: `route` now ASSIGNS the lane and prints
# "<LANE LENS>|<stem>" once at the end, so the old `then echo "FORGE Claude"`
# form no longer exists anywhere in the router. Left unedited this mutant would
# have been DISCARDED -- the harness would have said so, loudly, which is the
# only reason a moved needle is a nuisance here rather than a false green.
run H07 "$SH" \
  'if   fired "$_p" "$STEMS_FORGE";      then _lane="FORGE Claude"' \
  'if   fired "$_p" "$STEMS_CLINICAL";   then _lane="CLINICAL AntiVenom"' \
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

echo
echo "=== ORGAN 4: breaking the reminder arms on purpose ==="
# Same discipline, second pair of arms. H20 is this section's OWN meta-control:
# without it, a reminder cross-diff that failed on everything would score four
# perfect kills below.
run H20 "$RSH" \
  '# --- DECIDE ---' \
  '# --- DECIDE (no-op comment edit) ---' \
  GREEN 'meta-control: a comment change must not turn the reminder cross-diff red' \
  checker/cross-diff-remind.sh

run H21 "$RSH" \
  '[ "$_mins" -lt "$STALE_MIN" ]' \
  '[ "$_mins" -le "$STALE_MIN" ]' \
  RED 'staleness boundary moved in the POSIX arm only -- the 45-minute row flips to silence' \
  checker/cross-diff-remind.sh

run H22 "$RPS1" \
  '$Mins -lt $StaleMin' \
  '$Mins -le $StaleMin' \
  RED 'the SAME boundary moved in the WINDOWS arm only -- caught from the other side' \
  checker/cross-diff-remind.sh

run H23 "$RSH" \
  'A sorry is an admission, never a result' \
  'A sorry is an admission, never a resul' \
  RED 'one character dropped from a message -- proves the comparison is BYTE-for-byte' \
  checker/cross-diff-remind.sh

run H24 "$RPS1" \
  'Select-Object -First $N' \
  'Select-Object -First 99' \
  RED 'truncation limit changed in the Windows arm -- the "(+N more)" rows diverge' \
  checker/cross-diff-remind.sh

# H25 -- the one that matters most, and it is aimed at the hook's PURPOSE
# rather than its arithmetic: silence. An arm that always speaks is the
# wallpaper this organ was rewritten to stop being, and it would pass every
# equality test above if BOTH arms did it. Here only one arm loses silence, so
# the cross-diff names it.
run H25 "$RSH" \
  '    return 1' \
  '    :' \
  RED 'the POSIX arm loses its SILENT branch -- it becomes wallpaper' \
  checker/cross-diff-remind.sh

restore

# --- THE RESTORE MUST BE VERIFIED, NOT ASSUMED -------------------------------
#
# MEASURED 2026-08-05. `timeout` signals its DIRECT CHILD. When a bounded sweep
# of checker/gate-all.sh was killed, THIS script had already been started by it
# and was ORPHANED rather than signalled -- so the EXIT/INT/TERM trap above never
# fired, and the process was later killed outright. It left three shipped hooks
# at ZERO BYTES with no .mutbak beside them, which is the one state gate-all's
# leftover-backup refusal cannot see.
#
# Emptying a file is one of the mutants below, so that is a LIVE MUTANT with the
# evidence removed. Two fast sweeps stayed green afterwards: every fast gate
# reads source TEXT, and an empty file has no offending text in it.
#
# A trap cannot be made to fire for SIGKILL. What CAN be done is refuse to
# report success unless the files this script is allowed to touch are back --
# non-empty, and byte-identical to what git has. `git checkout` is the recovery
# the message names, and it is not run automatically: silently repairing the
# tree would hide the interruption that caused it.
_rbad=0
for _f in "$SH" "$PS1" "$RSH" "$RPS1"; do
  _rel="${_f#"$REPO"/}"
  if [ ! -s "$_f" ]; then
    echo "RESTORE FAILED: $_rel is EMPTY after restore -- a live mutant is on disk."
    _rbad=1
  elif ! git -C "$REPO" diff --quiet -- "$_rel" 2>/dev/null; then
    echo "RESTORE FAILED: $_rel differs from git after restore -- a mutant survived."
    _rbad=1
  fi
done
if [ "$_rbad" -ne 0 ]; then
  echo "Recover with: git checkout HEAD -- hooks/"
  echo "REFUSING to report a result: every gate after this one would measure the mutant."
  exit 1
fi
ok_restore=1

bash "$REPO/checker/cross-diff.sh" > "$LOG/baseline.log" 2>&1
base=$?
bash "$REPO/checker/cross-diff-remind.sh" > "$LOG/baseline-remind.log" 2>&1
baseR=$?
rm -f "$SH.mutbak" "$PS1.mutbak" "$RSH.mutbak" "$RPS1.mutbak"

echo "---"
echo "killed=$killed survived=$survived discarded=$discarded"
echo "baseline restored -> cross-diff exit=$base, cross-diff-remind exit=$baseR"
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && [ "$base" -eq 0 ] && [ "$baseR" -eq 0 ] && exit 0 || exit 1
