#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE TWO DEFECTS A WINDOWS-ONLY DEVELOPER CANNOT SEE.
#
# Both were found on 2026-08-01 by the FIRST CI run after the repository was
# pushed to GitHub -- not by any of the eighteen local gates, which were all
# green. That is the entire argument for CI in one sentence, and it is the
# reason this checker exists: to bring both defects back to a machine where
# they can be caught before a push.
#
# DEFECT 1 -- THE EXECUTABLE BIT (found on ubuntu-latest).
#   All 40 shipped .sh files were committed as mode 100644. Windows does not
#   track the bit, so nothing locally noticed. On Linux, every direct
#   invocation dies with `Permission denied` -- cross-diff.sh failed 20 rows
#   because it runs the router as `"$ROUTER" --vector ...`. A user cloning on
#   Linux would have found ARM_ROUTER.sh unrunnable. Note that the PowerShell
#   arm passed the whole time: the plugin was broken on Linux only.
#
# DEFECT 2 -- CRLF (found on windows-latest).
#   `core.autocrlf` is on by DEFAULT for a Windows checkout, so corpus rows
#   arrive with a trailing `\r`. `[ "14\r" -gt 0 ]` is not a valid integer
#   test: it is false, and prover-remind.sh SILENTLY DROPPED its entire alarm
#   warning. The PowerShell arm parsed it fine, so the arms disagreed -- which
#   is the only reason it was visible at all. A hook that goes quiet about
#   alarms is worse than one that errors.
#
# Exit: 0 clean · 1 a portability guarantee is broken · 2 refuse.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad() { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }

command -v git >/dev/null 2>&1 || { echo "REFUSE: git absent"; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "REFUSE: not a git tree"; exit 2; }

# ---------------------------------------------------------------------------
echo "== 1. every shipped .sh is executable IN THE INDEX =="
# ---------------------------------------------------------------------------
# The index, not the working tree. The working tree mode on Windows is a
# fiction; what a Linux user gets is whatever git recorded, so that is what
# must be asserted.
total=$(git ls-files -- '*.sh' | grep -c .)
nonexec=$(git ls-files -s -- '*.sh' | awk '$1!="100755"{print $4}')
n_bad=$(printf '%s' "$nonexec" | grep -c . || true)
if [ "$total" -eq 0 ]; then
  bad "no .sh files tracked at all -- this checker would pass vacuously"
elif [ "$n_bad" -eq 0 ]; then
  ok "all $total tracked .sh files are mode 100755"
else
  bad "$n_bad of $total .sh files are NOT executable -- they will fail on Linux:"
  printf '%s\n' "$nonexec" | head -10 | sed 's/^/        /'
fi

# The four ORGANS and the two arm scripts are the ones a user runs by hand
# first. Named individually so a regression names the file, not a count.
for f in ARM_ROUTER.sh DISARM_ROUTER.sh SETUP_LEAN.sh hooks/rot-router.sh hooks/prover-remind.sh; do
  mode=$(git ls-files -s -- "$f" | awk '{print $1}')
  [ "$mode" = "100755" ] || bad "$f is mode ${mode:-<untracked>}, must be 100755"
done

# CONTROL: the check must be able to see a non-executable file.
ctl_dir=$(mktemp -d); trap 'rm -rf "$ctl_dir"' EXIT
(
  cd "$ctl_dir" || exit 1
  git init -q .; printf '#!/bin/sh\necho hi\n' > victim.sh
  git add victim.sh 2>/dev/null
  m=$(git ls-files -s -- victim.sh | awk '{print $1}')
  [ "$m" = "100644" ] && exit 0 || exit 1
) && ok "CONTROL: a freshly added .sh with no bit IS mode 100644 -- the check can see one" \
  || ok "CONTROL: this platform adds .sh as executable by default (the defect is inexpressible here, not absent)"

# ---------------------------------------------------------------------------
echo
echo "== 2. the reminder survives a CRLF checkout =="
# ---------------------------------------------------------------------------
CORPUS="checker/corpus-remind.txt"
[ -f "$CORPUS" ] || { echo "REFUSE: $CORPUS missing"; exit 2; }

# Compare the two arms on the SAME row, once with LF and once with CRLF. The
# guarantee is not "the arms agree" (cross-diff-remind.sh owns that) -- it is
# that neither arm's answer DEPENDS on the line ending.
row_lf=$(bash hooks/prover-remind.sh --decide PostToolUse 10 RotGauge a.rs - - "14" 2>&1)
row_cr=$(bash hooks/prover-remind.sh --decide PostToolUse 10 RotGauge a.rs - - "$(printf '14\r')" 2>&1)
if [ "$row_lf" = "$row_cr" ]; then
  ok "prover-remind.sh gives byte-identical output for '14' and '14\\r'"
else
  bad "prover-remind.sh output CHANGES with a trailing CR -- a CRLF checkout breaks it"
  printf '        LF: %.120s\n' "$row_lf"
  printf '        CR: %.120s\n' "$row_cr"
fi

# The alarm clause is the one that vanished. Assert the CONTENT, not just
# equality -- two identically BROKEN outputs would satisfy the test above.
case "$row_cr" in
  *"alarm row(s)"*) ok "the alarm warning survives the CR (this is the sentence that disappeared)" ;;
  *) bad "the alarm warning is MISSING under CRLF -- the exact CI defect is back" ;;
esac

# CONTROL: the assertion must be able to fail. A stripper that does nothing
# must be caught, so simulate the pre-fix behaviour and require a mismatch.
pre_fix=$(printf 'x %s alarm row(s)' "$(printf '14\r')")
post_fix=$(printf 'x %s alarm row(s)' "14")
if [ "$pre_fix" = "$post_fix" ]; then
  bad "CONTROL DEAD: this shell cannot distinguish a CR-tainted string at all"
else
  ok "CONTROL: a CR-tainted string IS distinguishable here -- the test above is real"
fi

# Whole-corpus round: convert to CRLF, run the real cross-diff, restore. The
# copy is restored from a backup taken in the same breath, and the restoration
# is VERIFIED, because a checker that corrupts the corpus it tests is a worse
# defect than the one it looks for.
BK=$(mktemp); cp "$CORPUS" "$BK"
sed 's/$/\r/' "$BK" > "$CORPUS"
bash checker/cross-diff-remind.sh > "$ctl_dir/crlf.log" 2>&1
rc=$?
cp "$BK" "$CORPUS"; rm -f "$BK"
if git diff --quiet -- "$CORPUS"; then
  ok "the corpus was restored byte-identical after the CRLF round"
else
  bad "THE CORPUS WAS LEFT MODIFIED -- restore it from git before trusting anything"
fi
if [ "$rc" -eq 0 ]; then
  ok "both reminder arms agree with the ENTIRE corpus in CRLF (the windows-latest failure)"
else
  bad "the arms disagree under a CRLF corpus -- exit $rc"
  grep -E "DISAGREES" "$ctl_dir/crlf.log" | head -3 | sed 's/^/        /'
fi

# ---------------------------------------------------------------------------
echo
echo "== 3. the PowerShell arms run where Windows variables do not exist =="
# ---------------------------------------------------------------------------
# DEFECT 3, found by the SECOND CI run (ubuntu-latest, 2026-08-01), after the
# first two were fixed. prover-remind.ps1 built its state directory with
#   Join-Path $env:USERPROFILE '.local/state/rot-moe'
# and USERPROFILE does not exist outside Windows. Join-Path REFUSES a null
# Path, so the script died at CONFIG time, before parsing an argument: all 23
# corpus rows reported "the Windows arm exited 1". PowerShell Core is
# cross-platform, and assuming Windows because the file is .ps1 is the same
# mistake as assuming Linux because a file is .sh.
#
# THE INSTRUMENT IS THE POINT: this needs no Linux box. Unsetting the variable
# on Windows reproduces the exact condition, and that is how it was fixed here.
if command -v pwsh >/dev/null 2>&1 && command -v env >/dev/null 2>&1; then
  for arm in hooks/prover-remind.ps1 hooks/rot-router.ps1; do
    [ -f "$arm" ] || { bad "$arm missing"; continue; }
    case "$arm" in
      *prover-remind*) args="-Decide PostToolUse 10 RotGauge - - - 0" ;;
      *)               args="-Route lake build" ;;
    esac
    # shellcheck disable=SC2086
    env -u USERPROFILE pwsh -NoProfile -File "$arm" $args >/dev/null 2>&1
    rc1=$?
    # shellcheck disable=SC2086
    env -u USERPROFILE -u HOME pwsh -NoProfile -File "$arm" $args >/dev/null 2>&1
    rc2=$?
    if [ "$rc1" -le 1 ] && [ "$rc2" -le 1 ]; then
      ok "$arm survives with USERPROFILE unset (exit $rc1) and with HOME unset too (exit $rc2)"
    else
      bad "$arm DIES without Windows env vars: USERPROFILE-unset exit $rc1, both-unset exit $rc2"
      env -u USERPROFILE pwsh -NoProfile -File "$arm" $args 2>&1 | head -2 | sed 's/^/        /'
    fi
  done

  # The output must not merely SURVIVE -- it must be the same answer. A hook
  # that silently degrades on Linux is a subtler version of the same defect.
  n1=$(pwsh -NoProfile -File hooks/prover-remind.ps1 -Decide PostToolUse 10 RotGauge a.rs - - 14 2>&1)
  n2=$(env -u USERPROFILE pwsh -NoProfile -File hooks/prover-remind.ps1 -Decide PostToolUse 10 RotGauge a.rs - - 14 2>&1)
  if [ "$n1" = "$n2" ]; then
    ok "the reminder's answer is byte-identical with and without USERPROFILE"
  else
    bad "the reminder answers DIFFERENTLY when USERPROFILE is absent -- it degrades silently on Linux"
  fi

  # CONTROL: the probe must be able to see a null-dereference. Plant the
  # pre-fix line in a scratch copy and require it to die.
  #
  # THE CONTROL WAS DEAD ON ITS FIRST RUN, and the reason is worth recording:
  # PowerShell's null-Path error is NON-TERMINATING by default, so the scratch
  # script exited 0 and the control reported that a null dereference is
  # harmless. It is not -- all three shipped .ps1 files set
  # `$ErrorActionPreference = 'Stop'` (prover-remind.ps1:32, rot-router.ps1:33,
  # SETUP_LEAN.ps1:35), which is exactly why the real defect KILLED the script.
  # A control must reproduce the conditions of the code it stands in for, or it
  # measures a different program than the one that ships.
  ctl_ps="$ctl_dir/ctl.ps1"
  printf '%s\n' 'param([switch]$Decide)' \
                '$ErrorActionPreference = "Stop"' \
                '$d = Join-Path $env:ROTMOE_DEFINITELY_UNSET_VAR ".local/state"' \
                'Write-Output $d' > "$ctl_ps"
  if env -u USERPROFILE pwsh -NoProfile -File "$ctl_ps" -Decide >/dev/null 2>&1; then
    bad "CONTROL DEAD: a Join-Path on a null variable did NOT fail -- this probe proves nothing"
  else
    ok "CONTROL: Join-Path on an unset variable DOES kill a script here"
  fi
else
  echo "  NOTE  pwsh or env(1) absent -- phase 3 NOT run (a gap, not a pass)"
fi

# A source-level scan as well, because the runtime probe only covers the code
# paths those two invocations reach. Windows-only variables must never be
# dereferenced bare in a shipped .ps1.
winvars=0
for arm in hooks/*.ps1 ARM_ROUTER.ps1 DISARM_ROUTER.ps1 SETUP_LEAN.ps1; do
  [ -f "$arm" ] || continue
  hits=$(sed 's/#.*$//' "$arm" | grep -nE '\$env:(USERPROFILE|APPDATA|LOCALAPPDATA|HOMEDRIVE|HOMEPATH|ProgramFiles)' || true)
  if [ -n "$hits" ]; then
    # A guarded use is fine; a bare one inside Join-Path is the defect.
    # `[$]` rather than `\$`: two rounds of sed rewriting this line ate the
    # backslash, leaving `$env:` -- where ERE reads `$` as end-of-line and the
    # scan silently matches nothing. A bracket expression cannot be de-escaped
    # by accident, so the pattern survives the next person's `sed -i`.
    if grep -qE 'Join-Path[[:space:]]+[$]env:' <<< "$hits"; then
      bad "$arm passes a Windows-only variable straight to Join-Path:"
      printf '%s\n' "$hits" | head -3 | sed 's/^/        /'
      winvars=1
    fi
  fi
done
[ "$winvars" -eq 0 ] && ok "no shipped .ps1 feeds a Windows-only variable directly to Join-Path"

# ---------------------------------------------------------------------------
echo
echo "== 4. no pipe into an early-exiting consumer =="
# ---------------------------------------------------------------------------
# DEFECT 4, found by the THIRD CI run (ubuntu-latest, 2026-08-01).
# checker/workflow-lint.sh did `printf '%s' "$BIG" | grep -qF "$needle"` and
# reported EIGHT WIRED CHECKERS as NOT RUN BY ANY WORKFLOW, each accompanied by
# `printf: write error: Broken pipe`. grep -q exits on first match, printf takes
# EPIPE, and `set -o pipefail` turns that into a failed pipeline -- so a MATCH
# was scored as a MISS and the lint declared the repository less verified than
# it is. The inversion of its purpose.
#
# It cannot reproduce on Git Bash: the string fits the pipe buffer before grep
# can exit. That is the whole danger -- the outcome depends on the platform's
# pipe buffer size, so the same code is green here and red there, and neither
# result is trustworthy. `case` or a here-string removes the pipe entirely.
sigpipe=0
for f in checker/*.sh hooks/*.sh; do
  [ -f "$f" ] || continue
  # Lines carrying the pragma are the CONTROLS below, which must contain the
  # forbidden pattern in order to prove the scan can see it. Excluded by an
  # explicit marker rather than by loosening the pattern -- the same lesson as
  # hook-footprint.sh, where a checker that fires on a line DOCUMENTING the rule
  # gets deleted by the next person who trips over it.
  hits=$(grep -v 'SIGPIPE-ALLOW' "$f" | sed 's/#.*$//' | grep -nE '(printf|echo|cat)[^|]*\|[[:space:]]*grep[[:space:]]+-[A-Za-z]*q' || true)
  if [ -n "$hits" ]; then
    bad "$f pipes into grep -q -- SIGPIPE + pipefail makes this platform-dependent:"
    printf '%s\n' "$hits" | head -3 | sed 's/^/        /'
    sigpipe=1
  fi
done
[ "$sigpipe" -eq 0 ] && ok "no shipped script pipes a string into an early-exiting grep"

# CONTROL 1: the scan must see the pattern.
ctl_sh="$ctl_dir/sigpipe.sh"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s" "$X" | grep -q needle' > "$ctl_sh"
if sed 's/#.*$//' "$ctl_sh" | grep -qE '(printf|echo|cat)[^|]*\|[[:space:]]*grep[[:space:]]+-[A-Za-z]*q'; then  # SIGPIPE-ALLOW
  ok "CONTROL: a planted printf|grep -q IS detected"  # SIGPIPE-ALLOW
else
  bad "CONTROL DEAD: the scan cannot see the pattern it forbids"
fi

# CONTROL 2 -- the one that proves the DEFECT is real, not just the pattern.
# Force the race with a string far larger than any pipe buffer and require the
# pipeline to fail under pipefail. If this ever stops failing, the rule above
# has become superstition and should be re-argued rather than kept on faith.
big=$(head -c 400000 /dev/zero 2>/dev/null | tr '\0' 'a' 2>/dev/null)
if [ -n "$big" ]; then
  ( set -o pipefail; printf 'needle%s' "$big" | grep -q needle ) 2>/dev/null  # SIGPIPE-ALLOW
  rc=$?
  if [ "$rc" -ne 0 ]; then
    ok "CONTROL: with a 400 KB string the pipeline really does fail under pipefail (exit $rc) -- the defect is real here too"
  else
    echo "  NOTE  the race did not reproduce on this platform's buffer (it did on ubuntu-latest);"
    echo "        the rule stands on the CI measurement, not on this machine's pipe size."
  fi
else
  echo "  NOTE  could not build a large test string -- control 2 not run"
fi

printf '\n== portability: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
