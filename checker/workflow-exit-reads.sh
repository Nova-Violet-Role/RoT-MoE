#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# =============================================================================
# WORKFLOW EXIT READS -- `rc=$?` after a bare command, under `bash -e`, is dead code.
#
# THE BUG THIS FORBIDS, MEASURED THREE TIMES IN ONE FILE
#   GitHub runs a `run:` block as `bash -e {0}`. Under `-e`, a command that
#   exits non-zero ABORTS THE STEP IMMEDIATELY -- the next line never executes.
#   So this shape:
#
#       bash checker/whatever.sh
#       rc=$?
#       if [ "$rc" -eq 3 ]; then ... tolerate the skip ... fi
#
#   is a tolerance branch that CAN NEVER RUN. The step dies at line 1 with the
#   checker's own exit code, and the careful handling below it is decoration.
#
#   Measured occurrences, all in .github/workflows/ci.yml:
#     - deferred closure, run 30695224024: gate exited 3, step died on the spot,
#       the SKIP branch written to tolerate it never ran. Fixed then, and the
#       comment left behind is what made the other two findable.
#     - workflow roles, run 31622038695: checker reported "10 passed, 0 failed,
#       1 skipped ... Exit 3"; the `case` handling exit 3 as a ::notice had
#       never once executed.
#     - push guard, same run: exit 1 is that guard's NORMAL answer while an
#       obligation is open, and the bare form would have killed the step before
#       it could print the verdict it had just captured to a file.
#
#   NOTE the direction of the damage. It is not that these steps passed when
#   they should have failed -- it is that they failed in a way that LOOKED like
#   the checker's verdict while the step's own logic was never consulted. A
#   reader sees "exit 3" and blames the checker. The step was the defect.
#
# WHAT COUNTS AS SAFE
#   1. the enclosing step ran `set +e` first  -- `-e` is genuinely off
#   2. `if cmd; then rc=0; else rc=$?; fi`    -- the status is part of a
#      compound command, which `-e` does not act on
#   3. the read directly follows `else` or a `; then` -- same reason as (2)
#
#   `set -uo pipefail` is NOT safe and is the trap that caught this repo twice:
#   it looks like strict-mode housekeeping and does not touch `-e` at all.
#
# USAGE   bash checker/workflow-exit-reads.sh
# EXITS   0 every exit-code read is reachable | 1 at least one is dead code | 2 tooling
# =============================================================================

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

pass=0; fail=0
ok  () { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
bad () { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }
inf () { printf '  ----  %s\n' "$1"; }

# scan <file> -> prints "line:text" for each UNREACHABLE exit-code read
scan () {
  awk '
    # A new step resets the shell options: each `run:` gets a fresh shell.
    /^[[:space:]]*-[[:space:]]+(name|uses):/ { pluse = 0 }
    /set[[:space:]]+\+e/                     { pluse = 1 }
    {
      if ($0 ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\$\?[[:space:]]*$/) {
        safe = 0
        if (pluse == 1)                    safe = 1     # -e genuinely off
        if (prev ~ /^[[:space:]]*else[[:space:]]*$/) safe = 1
        if (prev ~ /;[[:space:]]*then/)    safe = 1
        if (prev ~ /^[[:space:]]*if[[:space:]]/) safe = 1
        if (safe == 0) printf "%d:%s\n", NR, $0
      }
      # Comments and blank lines are not the "previous command".
      if ($0 !~ /^[[:space:]]*(#|$)/) prev = $0
    }
  ' "$1"
}

echo "== workflow exit reads: is every \$? actually reachable?"

files=$(ls .github/workflows/*.yml 2>/dev/null)
[ -n "$files" ] || { echo "workflow-exit-reads: no workflows found -- refusing to pass over an empty set"; exit 2; }

total=0; badcount=0
for f in $files; do
  n=$(grep -cE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\$\?[[:space:]]*$' "$f")
  total=$((total + n))
  hits=$(scan "$f")
  if [ -n "$hits" ]; then
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      bad "$f:${h%%:*} -- exit-code read is UNREACHABLE under \`bash -e\`; the handling below it is dead code"
      badcount=$((badcount + 1))
    done <<< "$hits"
  fi
done
inf "$total exit-code read(s) examined across $(echo "$files" | wc -w | tr -d ' ') workflow file(s)"
[ "$total" -gt 0 ] || { echo "workflow-exit-reads: zero reads examined -- the scanner matched nothing, which is a scanner fault"; exit 2; }
[ "$badcount" -eq 0 ] && ok "every exit-code read is guarded (set +e, or the if/else form)"

# --- CONTROLS ----------------------------------------------------------------
# C1: a planted unreachable read MUST be caught.
_c1="$(mktemp)"
printf '%s\n' \
  'jobs:' '  x:' '    steps:' '      - name: planted' '        run: |' \
  '          set -uo pipefail' '          bash checker/whatever.sh' '          rc=$?' > "$_c1"
if [ -n "$(scan "$_c1")" ]; then ok "CONTROL: a planted \`set -uo pipefail\` + bare read IS caught"
else bad "CONTROL: the scanner missed a planted unreachable read -- it is blind"; fi
rm -f "$_c1"

# C2: the guarded forms must NOT be flagged, or the gate would forbid the fix.
_c2="$(mktemp)"
printf '%s\n' \
  'jobs:' '  x:' '    steps:' '      - name: guarded-if' '        run: |' \
  '          if bash checker/whatever.sh; then rc=0; else rc=$?; fi' \
  '      - name: guarded-pluse' '        run: |' '          set +e' \
  '          bash checker/whatever.sh' '          rc=$?' > "$_c2"
if [ -z "$(scan "$_c2")" ]; then ok "CONTROL: both guarded forms are accepted (the gate does not forbid its own repair)"
else bad "CONTROL: a guarded form was flagged -- the gate would block the correct fix"; fi
rm -f "$_c2"

# C3: `set +e` must not leak across steps -- each `run:` is a fresh shell.
_c3="$(mktemp)"
printf '%s\n' \
  'jobs:' '  x:' '    steps:' '      - name: turns-it-off' '        run: |' '          set +e' \
  '          true' '      - name: different-step' '        run: |' \
  '          bash checker/whatever.sh' '          rc=$?' > "$_c3"
if [ -n "$(scan "$_c3")" ]; then ok "CONTROL: \`set +e\` in an EARLIER step does not excuse a later one"
else bad "CONTROL: set +e leaked across a step boundary -- shells are not shared, the scanner is wrong"; fi
rm -f "$_c3"

echo "== workflow-exit-reads: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
