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
bad() { printf '  FAIL  %s\n' "$*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=portability::%s\n' "$*"; FAIL=$((FAIL+1)); }

command -v git >/dev/null 2>&1 || { echo "REFUSE: git absent"; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "REFUSE: not a git tree"; exit 2; }

# ---------------------------------------------------------------------------
echo "== 1. every shipped .sh is executable IN THE INDEX =="
# ---------------------------------------------------------------------------
# The index, not the working tree. The working tree mode on Windows is a
# fiction; what a Linux user gets is whatever git recorded, so that is what
# must be asserted.
total=$(git ls-files -- '*.sh' | grep -c .)
# SPLIT ON THE TAB, not on whitespace. `git ls-files -s` emits
# "<mode> <sha> <stage>\t<path>", so a path containing a SPACE -- this repo has
# `Lean Theorem/` -- is truncated by `{print $4}` to its first word. Measured:
# the checker correctly counted 6 offenders and then printed "Lean" four times,
# naming none of them. A failure report that cannot name the file it failed on
# sends the reader hunting; that is a defect in the instrument, not cosmetics.
nonexec=$(git ls-files -s -- '*.sh' | awk -F'\t' '{split($1,m," "); if (m[1]!="100755") print $2}')
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
# BUILD THE CRLF VARIANT WITH printf, NOT WITH sed.
#
# MEASURED 2026-08-01, and this round had been VACUOUS ON WINDOWS since the
# day it was written. The old line appended a CR at end-of-line with sed. On a
# Windows checkout core.autocrlf has ALREADY put CRLF in the working tree, and
# Git Bash sed opens files in TEXT MODE: it strips the CR-LF pair on read and
# writes it back, so the append changed NOTHING. Byte sizes identical, 1839
# in and 1839 out -- measured.
#
# The consequence is the false green this repository exists to hunt:
# cross-diff-remind then ran against an UNCHANGED corpus and this phase
# reported 'both reminder arms agree with the ENTIRE corpus in CRLF' having
# compared the LF path with itself. The round was real on Linux and macOS,
# where the corpus is LF so the append does land, and decorative on the one
# platform whose default checkout creates the very defect it was written to
# catch.
#
# bash printf writes raw bytes with no line-ending translation on any
# platform, so the variant below is exact by construction. The CR is stripped
# first, making the conversion idempotent and independent of what the checkout
# already did.
: > "$CORPUS"
while IFS= read -r _line || [ -n "$_line" ]; do
  _line=${_line%$'\r'}
  printf '%s\r\n' "$_line" >> "$CORPUS"
done < "$BK"
sed_rc=$?

# Assert the BYTES rather than trusting the loop.
if [ "$(tr -dc '\r' < "$CORPUS" | wc -c | tr -d ' ')" -eq 0 ]; then
  bad "the CRLF variant contains no CR at all -- the conversion produced nothing"
fi
# THE MUTATION MUST BE PROVEN TO HAVE LANDED BEFORE ITS RESULT MEANS ANYTHING.
# This is `RotMoE.landed` from lean/Proofs/RotMutant.lean, executed: the patch
# tool exited 0, the product is NOT empty, and it DIFFERS from the original.
#
# Without it this round had a live false-green path. If `sed` failed, $CORPUS
# would be EMPTY, cross-diff-remind would compare two arms over zero rows, find
# no disagreement, and this phase would report that CRLF input is handled
# correctly -- having tested nothing at all. `killed_implies_all_three` is the
# theorem that forbids exactly that, and checker/mutant-discipline.sh is what
# noticed this site did not obey it.
# `landed` from lean/Proofs/RotMutant.lean, EXECUTED. The third condition is
# 'differs from the original' -- and when the checkout was already CRLF the
# variant legitimately equals it, so the comparison that carries meaning is
# against the LF form. An LF corpus and a CRLF corpus that are byte-equal
# would mean the conversion did nothing.
LFV=$(mktemp); tr -d '\r' < "$BK" > "$LFV"
if [ "$sed_rc" -ne 0 ] || [ ! -s "$CORPUS" ] || cmp -s "$CORPUS" "$LFV"; then
  rm -f "$LFV"
  cp "$BK" "$CORPUS"; rm -f "$BK"
  bad "CRLF round DISCARDED -- the mutation did not land (sed exit $sed_rc, empty or unchanged corpus). Nothing was tested; this is NOT a pass."
else
  rm -f "$LFV"
  ok "the CRLF variant LANDED (printf-built, non-empty, genuinely differs from the LF form)"
bash checker/cross-diff-remind.sh > "$ctl_dir/crlf.log" 2>&1
rc=$?
cp "$BK" "$CORPUS"
# ASK THE RIGHT WITNESS. This compared the restored corpus against GIT, which
# answers a different question: "does the working tree match HEAD". Measured
# 2026-08-08, when five rows were deliberately added to the corpus and not yet
# committed -- the CRLF round restored the file perfectly and this still reported
# THE CORPUS WAS LEFT MODIFIED. An intentional uncommitted edit is not a failed
# restore.
#
# The honest witness is the backup this section took moments earlier: compare
# after-bytes to before-bytes. That is exactly the property claimed ("restored
# byte-identical"), it holds whether or not the tree is clean, and it still
# fails loudly if the round really does leave the file changed.
if cmp -s "$BK" "$CORPUS"; then
  rm -f "$BK"
  ok "the corpus was restored byte-identical after the CRLF round (compared to the pre-round bytes, not to git)"
else
  bad "THE CORPUS WAS LEFT MODIFIED by the CRLF round -- restore it from $BK"
fi
if [ "$rc" -eq 0 ]; then
  ok "both reminder arms agree with the ENTIRE corpus in CRLF (the windows-latest failure)"
else
  bad "the arms disagree under a CRLF corpus -- exit $rc"
  grep -E "DISAGREES" "$ctl_dir/crlf.log" | head -3 | sed 's/^/        /'
fi
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
if sed 's/#.*$//' "$ctl_sh" | grep -cE '(printf|echo|cat)[^|]*\|[[:space:]]*grep[[:space:]]+-[A-Za-z]*q' >/dev/null; then  # SIGPIPE-ALLOW
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
  ( set -o pipefail; printf 'needle%s' "$big" | grep -c needle >/dev/null ) 2>/dev/null  # SIGPIPE-ALLOW
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

# ---------------------------------------------------------------------------
echo
echo "== 5. no bash-4-only construct (macOS ships bash 3.2.57) =="
# ---------------------------------------------------------------------------
# MEASURED on macos-latest, 2026-08-01, the first time a macOS runner ever ran
# this repository: `checker/workflow-lint.sh` died at
#
#     checker/workflow-lint.sh: line 69: declare: -A: invalid option
#     checker/workflow-lint.sh: line 70: preflight.sh: syntax error:
#         invalid arithmetic operator (error token is ".sh")
#
# Apple froze /bin/bash at 3.2.57 (2007), the last GPLv2 release, and has never
# shipped a newer one. `declare -A` arrived in bash 4.0 (2009); so did
# `mapfile`/`readarray` and the `${v^^}` / `${v,,}` case operators. bash 3.2
# does not merely reject an associative-array subscript, it REINTERPRETS it as
# arithmetic, so `EXCEPT[preflight.sh]=` becomes a syntax error about an
# operator -- a message that names nothing to do with the real cause.
#
# WHY A STATIC SCAN AND NOT A RUN: this machine has no bash 3.2 to run under,
# and neither does the ubuntu runner. Only the macOS job can execute the real
# thing, and it does. This phase makes the failure reproducible EVERYWHERE and
# BEFORE the push, which is the difference between a rule and a postmortem.
#
# The scan strips comments first -- every fix above documents the banned
# construct by name, and a rule that flags its own explanation is unusable.
B4_RE='(declare|local|typeset)[[:space:]]+-[A-Za-z]*A[A-Za-z]*[[:space:]]|(mapfile|readarray)[[:space:]]|\$\{[A-Za-z_][A-Za-z0-9_]*(\^\^|,,)'
b4_hits=0
for f in checker/*.sh hooks/*.sh .githooks/* *.sh; do
  [ -f "$f" ] || continue
  case "$f" in */portability.sh) continue ;; esac   # this file names them all
  h=$(grep -v 'BASH4-ALLOW' "$f" | sed 's/#.*$//' | grep -nE "$B4_RE" || true)
  if [ -n "$h" ]; then
    bad "$f uses a bash-4-only construct -- macOS /bin/bash is 3.2.57:"
    printf '%s\n' "$h" | sed 's/^/        /' | head -4
    b4_hits=$((b4_hits+1))
  fi
done
[ "$b4_hits" -eq 0 ] && ok "no bash-4-only construct in any shipped script ($(ls checker/*.sh hooks/*.sh 2>/dev/null | wc -l | tr -d ' ') files scanned)"

# ---------------------------------------------------------------------------
echo
echo "== 6. no GNU-only \\| alternation inside sed (BSD sed ignores it) =="
# ---------------------------------------------------------------------------
# MEASURED on macos-latest, run #20: TWO gates failed, and both blamed the wrong
# file.
#
#   checker/repo-complete.sh -> "checker/repo-complete.sh invokes a Python
#       interpreter". It does not. Its strip line used
#       sed 's/...\(say\|echo\|printf\|ok\|bad\).*$//', BSD sed left the text
#       untouched, and the control's OWN message -- "(python3 -c, | python -,
#       $(uv run), py -3)" -- was then read as an invocation.
#
#   checker/workflow-lint.sh -> "SETUP_LEAN.sh defects: USES_SUDO". It uses no
#       sudo. The surviving line was say "This installer never asks for sudo".
#       The gate failed on the sentence promising the opposite.
#
# `\|` inside a Basic Regular Expression is a GNU EXTENSION. GNU sed honours it;
# BSD sed (macOS) treats \| as a literal pipe, so the substitution matches
# nothing and silently does NOTHING. That is the dangerous half: a strip that
# fails OPEN leaves more text than intended, and every detector downstream then
# fires on prose it was supposed to have removed. Ubuntu is green, macOS is red,
# and the error message points at the file being read rather than the reader.
#
# THE FIX IS ONE FLAG: `sed -E` takes an ERE, where (a|b) is standard and both
# BSD and GNU agree. There is no portability argument for the BRE form.
#
# DELIBERATELY NOT FLAGGED: `grep` with \| . Measured in the same run --
# checker/hook-footprint.sh:92 and checker/license-bridge.sh:71 both depend on
# BRE alternation in grep and both PASSED on macOS, so BSD grep does accept it.
# Banning grep here would be a rule invented from doctrine rather than from a
# failure, and it would flag working code. sed and grep differ; the scan says
# only what was measured.
sed_hits=0
for f in checker/*.sh hooks/*.sh .githooks/* *.sh; do
  [ -f "$f" ] || continue
  case "$f" in */portability.sh) continue ;; esac   # this file quotes the form
  # A line is a hit when it invokes sed WITHOUT -E/-r and still carries \| .
  h=$(sed 's/#.*$//' "$f" \
      | grep -n 'sed' \
      | grep -F '\|' \
      | grep -vE 'sed[[:space:]]+-[A-Za-z]*[Er]' || true)
  if [ -n "$h" ]; then
    bad "$f uses \\| inside a BRE sed -- BSD sed ignores it, the strip fails OPEN:"
    printf '%s\n' "$h" | sed 's/^/        /' | head -4
    sed_hits=$((sed_hits+1))
  fi
done
[ "$sed_hits" -eq 0 ] && ok "no sed uses GNU-only \\| alternation (use sed -E with (a|b))"

echo "== 6b. no in-place sed and no sha256sum (both are GNU-only) =="
# MEASURED 2026-08-08, and the reason this section exists: checker/release-local.sh
# failed on EVERY macOS run from 2026-08-08 while ubuntu and windows passed, and
# section 6 above did not see it. Two constructs, each fatal on BSD userland:
#
#   sed -i "s/a/b/" f    GNU treats the argument after -i as OPTIONAL. BSD sed
#                        REQUIRES one and takes the next word as the BACKUP
#                        SUFFIX, so the script itself is consumed as a suffix and
#                        the command dies. `sed -i ''` is the BSD spelling and it
#                        breaks GNU. NO spelling of -i works on both, which is
#                        why the rule is a ban and not a preferred form: write to
#                        a temp file and mv it into place.
#
#   sha256sum            GNU coreutils. Does not exist on macOS, where the tool
#                        is `shasum -a 256`. checker/release-package.sh:406 has
#                        resolved this correctly since it was written -- the
#                        knowledge was in the repo and simply was not applied
#                        here, which is exactly what a checker is for.
#
# EXEMPTION, deliberately narrow: a line that already carries BOTH spellings is a
# platform fallback (`.github/workflows/ci.yml:237` does this on purpose), and a
# `command -v` line is resolving the tool rather than calling it.
gnu_only_hits=0
for f in checker/*.sh hooks/*.sh .githooks/* bench/*.sh *.sh; do
  [ -f "$f" ] || continue
  case "$f" in */portability.sh) continue ;; esac   # this file quotes both forms
  body=$(sed 's/#.*$//' "$f")
  h=$(printf '%s\n' "$body" | grep -nE "sed[[:space:]]+(-[A-Za-z]*[[:space:]]+)*-i([[:space:]]|$)" \
      | grep -vE "sed[[:space:]]+-i[[:space:]]+''" || true)
  if [ -n "$h" ]; then
    bad "$f uses in-place sed -- BSD sed needs an argument to -i, GNU sed must not have one:"
    printf '%s\n' "$h" | sed 's/^/        /' | head -3
    gnu_only_hits=$((gnu_only_hits+1))
  fi
  # The sha256sum rule judges at FILE scope, not line scope. The recommended
  # pattern is a `command -v sha256sum` probe that installs a wrapper, and the
  # wrapper's body necessarily contains the bare word -- flagging that line
  # would be flagging the fix. A file that probes has demonstrably resolved the
  # tool. LIMITATION, stated rather than hidden: a file could probe once and
  # still call it unguarded somewhere else, and this scan would not catch that.
  # The control below therefore checks an UNPROBED file is still caught, which
  # is the case that has actually shipped.
  # `case` rather than `| grep -q`: this file's own rule 3 bans piping into
  # grep -q, because SIGPIPE plus pipefail makes the status platform-dependent.
  # The rule caught this very line when it was first written that way.
  case "$body" in
    *"command -v sha256sum"*) s="" ;;
    *) s=$(printf '%s\n' "$body" | grep -n 'sha256sum' | grep -vE 'shasum' || true) ;;
  esac
  if [ -n "$s" ]; then
    bad "$f calls sha256sum -- absent on macOS, use shasum -a 256 behind a command -v probe:"
    printf '%s\n' "$s" | sed 's/^/        /' | head -3
    gnu_only_hits=$((gnu_only_hits+1))
  fi
done
[ "$gnu_only_hits" -eq 0 ] && ok "no in-place sed and no unguarded sha256sum in any shell script"

# --- controls for 6b: both rules must be able to fire ------------------------
# The bug this section was written for shipped BECAUSE a scan passed. A scan
# that cannot fail is worth nothing, so break each rule on purpose.
ctl6b="${TMPDIR:-/tmp}/b6bctl.$$.sh"
b6b_ok=0; b6b_n=0
for probe in 'sed -i "s/a/b/" f' 'sha256sum "$f" | cut -d" " -f1' 'sed -i -e "s/a/b/" f'; do
  printf '#!/usr/bin/env bash\n%s\n' "$probe" > "$ctl6b"
  b6b_n=$((b6b_n+1))
  cb=$(sed 's/#.*$//' "$ctl6b")
  hit=$(printf '%s\n' "$cb" | grep -nE "sed[[:space:]]+(-[A-Za-z]*[[:space:]]+)*-i([[:space:]]|$)" | grep -vE "sed[[:space:]]+-i[[:space:]]+''" || true)
  case "$cb" in
    *"command -v sha256sum"*) hit2="" ;;
    *) hit2=$(printf '%s\n' "$cb" | grep -n 'sha256sum' | grep -vE 'shasum' || true) ;;
  esac
  if [ -n "$hit" ] || [ -n "$hit2" ]; then b6b_ok=$((b6b_ok+1)); else echo "        control MISSED: $probe"; fi
done
# And the exemptions must NOT fire, or the rule would flag correct code.
for probe in "sed -i '' 's/a/b/' f" 'if command -v sha256sum >/dev/null; then SHA() { sha256sum "$1"; }; fi'; do
  printf '#!/usr/bin/env bash\n%s\n' "$probe" > "$ctl6b"
  cb=$(sed 's/#.*$//' "$ctl6b")
  hit=$(printf '%s\n' "$cb" | grep -nE "sed[[:space:]]+(-[A-Za-z]*[[:space:]]+)*-i([[:space:]]|$)" | grep -vE "sed[[:space:]]+-i[[:space:]]+''" || true)
  case "$cb" in
    *"command -v sha256sum"*) hit2="" ;;
    *) hit2=$(printf '%s\n' "$cb" | grep -n 'sha256sum' | grep -vE 'shasum' || true) ;;
  esac
  b6b_n=$((b6b_n+1))
  if [ -z "$hit" ] && [ -z "$hit2" ]; then b6b_ok=$((b6b_ok+1)); else echo "        exemption WRONGLY flagged: $probe"; fi
done
rm -f "$ctl6b"
if [ "$b6b_ok" -eq "$b6b_n" ]; then
  ok "CONTROL: all $b6b_n probes behaved ($((b6b_n-2)) violations caught, 2 exemptions spared)"
else
  bad "CONTROL: only $b6b_ok of $b6b_n probes behaved -- rule 6b is not trustworthy"
fi

# --- controls ---------------------------------------------------------------
# Three separate constructs, because one regex alternative passing says nothing
# about the other two -- and each of the three is a defect that has really
# shipped in this repo (declare -A and mapfile both did, today).
ctl4="${TMPDIR:-/tmp}/b4ctl.$$.sh"
b4_ctl_ok=0; b4_ctl_n=0
for probe in 'declare -A M' 'mapfile -t xs < <(echo hi)' 'echo "${name^^}"'; do
  printf '#!/usr/bin/env bash\n%s\n' "$probe" > "$ctl4"
  b4_ctl_n=$((b4_ctl_n+1))
  hit=$(sed 's/#.*$//' "$ctl4" | grep -nE "$B4_RE" || true)
  if [ -n "$hit" ]; then b4_ctl_ok=$((b4_ctl_ok+1)); fi
done
rm -f "$ctl4"
if [ "$b4_ctl_ok" -eq "$b4_ctl_n" ]; then
  ok "CONTROL: all $b4_ctl_n planted bash-4 constructs ARE detected (declare -A, mapfile, \${v^^})"
else
  bad "CONTROL DEAD: only $b4_ctl_ok of $b4_ctl_n planted bash-4 constructs were caught -- the scan is partly blind"
fi
# And the converse: an ordinary INDEXED array must NOT be flagged. Without this
# the rule could be a blanket ban on the word `declare` and still look green.
printf '#!/usr/bin/env bash\ndeclare -a xs\nxs+=(one)\n' > "$ctl4"
if [ -z "$(sed 's/#.*$//' "$ctl4" | grep -nE "$B4_RE" || true)" ]; then
  ok "CONTROL: a plain indexed array (declare -a) is NOT flagged -- the rule is specific"
else
  bad "CONTROL: declare -a was flagged; the rule is too broad and would ban portable code"
fi
rm -f "$ctl4"

# --- controls for phase 6 ----------------------------------------------------
# The scan must FIRE on the exact form that broke macOS, and must NOT fire on
# the portable replacement -- otherwise the "fix" would still be flagged and the
# rule would push people back to the broken form.
s6_scan () {   # same expression as the sweep; a control that tests a different
               # pipeline from the one it vouches for is not a control.
  sed 's/#.*$//' "$1" | grep -n 'sed' | grep -F '\|' \
    | grep -vE 'sed[[:space:]]+-[A-Za-z]*[Er]' || true
}
ctl5="$(mktemp "${TMPDIR:-/tmp}/rotmoe-s6a.XXXXXX")"
printf '#!/bin/sh\nsed %s s/x/y/ f\n' "'" > "$ctl5"
printf '#!/bin/sh\nsed "s/\\(say\\|echo\\).*$//" f\n' > "$ctl5"
if [ -n "$(s6_scan "$ctl5")" ]; then
  ok "CONTROL: a planted BRE sed with \\| IS flagged"
else
  bad "CONTROL DEAD: the phase-6 scan cannot see the exact form that broke macOS"
fi
printf '#!/bin/sh\nsed -E "s/(say|echo).*$//" f\n' > "$ctl5"
if [ -z "$(s6_scan "$ctl5")" ]; then
  ok "CONTROL: the portable sed -E form is NOT flagged -- the fix stays green"
else
  bad "CONTROL: sed -E was flagged; the rule would reject its own remedy"
fi
rm -f "$ctl5"

# --- PHASE 7: no tracked text file may carry CRLF ----------------------------
# MEASURED, run 31148233876, `checkers (windows-latest)`: the Windows runner
# checks out with core.autocrlf=true, so `checker/gauge-corpus.tsv` arrived with
# a CR on every line, the last field became `0.09\r`, and six comparisons failed
# with `hook 0.09 != corpus 0.09` -- byte-different, rendering identical.
#
# `.gitattributes` now pins the working tree to LF, which is the real fix. This
# phase is what makes the fix CHECKABLE: if the attribute file is deleted,
# weakened, or fails to cover a new extension, a CRLF file reaches the gates and
# this says so by name -- rather than a downstream checker failing with a
# message no one can read.
#
# `git ls-files --eol` is the right instrument: it reports the INDEX and
# WORKTREE line endings per tracked file, so it sees the actual bytes rather
# than guessing from a file name.
echo
echo "-- phase 7: line endings (the Windows checkout defect) --"
if git rev-parse --git-dir >/dev/null 2>&1; then
  # THE INDEX is what fails: an `i/crlf` file arrives with CRLF in EVERY clone,
  # on every platform, and no attribute can undo it -- the bytes are committed.
  # That is the hard rule.
  crlf_index="$(git ls-files --eol 2>/dev/null \
    | awk '$1 ~ /^i\/crlf/ { print $NF }' | head -20)"
  if [ -z "$crlf_index" ]; then
    ok "no tracked file carries CRLF in the INDEX -- every clone gets LF"
  else
    n=$(printf '%s\n' "$crlf_index" | grep -c .)
    bad "$n tracked file(s) carry CRLF in the index -- every clone gets CRLF and a byte comparison fails unreadably:"
    printf '%s\n' "$crlf_index" | sed 's/^/        /'
    echo "        repair: git add --renormalize ."
  fi

  # A WORKTREE CRLF over an LF index is a different animal and must NOT fail.
  # A generator that writes CRLF locally is legitimate: `.gitattributes` makes
  # git normalise it on `add`, so nothing wrong ever reaches the index. Failing
  # here would make a correct workflow go red and invite deleting the check --
  # the exact way real coverage gets destroyed. Report it, do not refuse it.
  crlf_work="$(git ls-files --eol 2>/dev/null \
    | awk '$1 ~ /^i\/lf/ && $2 ~ /^w\/crlf/ { print $NF }' | head -5)"
  if [ -n "$crlf_work" ]; then
    echo "  ----  NOTE: $(printf '%s\n' "$crlf_work" | grep -c .) file(s) are CRLF in the working tree over an LF index."
    echo "        git normalises these on add; nothing reaches the index. Not a failure."
  fi

  # CONTROL: the scan must be able to SEE a CRLF file, or its green means
  # nothing. Plant one, ask git how it reads it, remove it.
  ctl7="$(mktemp "${TMPDIR:-/tmp}/rotmoe-s7.XXXXXX")"
  printf 'a\r\nb\r\n' > "$ctl7"
  # No `| grep -q` here: under `set -o pipefail` grep -q exits on the first
  # match, the writer takes SIGPIPE, and the pipeline reports 141 -- so a
  # SUCCESSFUL match would read as a failure. This repository's own
  # workflow-lint caught that in this very control, which is the argument for
  # having it. Capture first, match the string afterwards.
  ctl7_eol="$(git ls-files --eol --others -- "$ctl7" 2>/dev/null || true)"
  ctl7_cr="$(od -c < "$ctl7" | grep -c '\\r' || true)"
  case "$ctl7_eol" in
    *w/crlf*) ok "CONTROL: a planted CRLF file IS visible to git ls-files --eol" ;;
    *)
      if [ "${ctl7_cr:-0}" -gt 0 ]; then
        ok "CONTROL: a planted CRLF file IS visible (CR bytes confirmed on disk)"
      else
        bad "CONTROL DEAD: the phase-7 scan cannot see a CRLF file at all"
      fi
      ;;
  esac
  rm -f "$ctl7"

  # And the attribute file itself must exist and pin eol=lf. Without it the
  # phase above passes on Linux while Windows still gets CRLF -- green on the
  # platform that was never affected.
  if [ -f .gitattributes ] && grep -qE '^\*[[:space:]]+text=auto[[:space:]]+eol=lf' .gitattributes; then
    ok ".gitattributes pins the working tree to LF on every platform"
  else
    bad ".gitattributes does not pin '* text=auto eol=lf' -- Windows will check out CRLF"
  fi
else
  bad "not a git worktree -- phase 7 cannot read line endings and is NOT a pass"
fi

printf '\n== portability: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
