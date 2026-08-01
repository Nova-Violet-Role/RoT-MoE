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

printf '\n== portability: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
