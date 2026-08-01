#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# EXECUTE THE CI STEP LIST ITSELF, IN A CLEAN CLONE, WITHOUT A RUNNER.
#
# R15 is "CI is green on a clean clone". Two things stand between this machine
# and that claim, and they are NOT the same size:
#
#   (a) the STEP LIST -- do the commands CI will run actually exist, parse, and
#       pass on a tree with no local state? This needs nothing but a clone.
#   (b) the RUNNER -- ubuntu-latest, windows-latest, the mathlib cache, a real
#       pty, comma-decimal locales. This needs GitHub, and there is no remote.
#
# `checker/repo-complete.sh` and R15a already cover "gate-all passes in a clean
# clone". That is NOT the same as this: gate-all is a list maintained by hand,
# and CI is a different list. A step could be added to ci.yml with a typo, or
# call a script with the wrong flag, and every local gate would stay green while
# the pipeline broke on the first push. This checker closes exactly that gap by
# taking the commands FROM ci.yml -- not from a copy of them written here.
#
# WHAT IT REFUSES TO DO, and why the honesty matters more than the coverage:
# steps that need the runner are NOT executed and are NOT counted as passes.
# They are listed as DEFERRED with the reason. A dry run that silently skipped
# `sudo locale-gen` and then reported "all CI steps pass" would be the exact
# overclaim this repository exists to refuse. Anything that would DOWNLOAD
# (elan, lake, mathlib cache) is deferred for a second reason as well: a
# checker must never acquire anything.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }

WF=".github/workflows/ci.yml"
[ -f "$WF" ] || { echo "  FAIL  $WF missing -- there is no step list to dry-run"; exit 1; }

echo "== CI dry run: the step list from $WF, executed in a clean clone =="

# --- 1. extract the steps ---------------------------------------------------
# Line-oriented on purpose. A YAML library would be more correct in general and
# is not available here; what matters is that the extractor is EXERCISED BY A
# CONTROL below, so a silent parse failure cannot masquerade as "no steps".
extract_steps () {   # extract_steps <workflow> -> "NAME\x1fWORKDIR\x1fCMD" per step
  # BUFFER PER STEP, FLUSH ONCE. The first version printed a record both when a
  # block ended AND when the next step began, so `mutate the checker` ran TWICE
  # and one step was reported DEFER and FAIL simultaneously. A dry run that
  # executes a step twice is not merely slow -- it makes the output unreadable
  # precisely where it matters.
  #
  # `working-directory:` IS PART OF THE COMMAND. Ignoring it produced three
  # false failures (`cat lean-toolchain`, `mutate/generalization_probe.sh`),
  # which look exactly like real CI defects and are not. A harness that invents
  # failures is as useless as one that hides them -- it just costs its time on
  # the other side.
  awk '
    function flush() {
      # ASCII RECORD SEPARATOR (\x1e) ENDS EACH RECORD, never a newline. A
      # `run: |` block IS multi-line, so with newline-delimited records `read`
      # stopped at the first line: `if grep ...; then` arrived alone, bash
      # exited 2 on a syntax error, and the harness reported "this CI step would
      # FAIL on a clean clone". A harness that truncates its input INVENTS
      # failures, and an invented failure costs the same hour as a real one.
      if (name != "" && cmd != "") printf "%s\x1f%s\x1f%s\x1e", name, wd, cmd
      name = ""; cmd = ""; wd = ""
    }
    /^      - name: /            { flush(); name = substr($0, 15); next }
    /^        working-directory: / { wd = substr($0, 28); next }
    /^        run: \|/           { inblock = 1; cmd = ""; next }
    /^        run: /             { cmd = substr($0, 14); inblock = 0; next }
    inblock {
      if ($0 ~ /^          /)          { cmd = cmd substr($0, 11) "\n"; next }
      else if ($0 ~ /^[[:space:]]*$/)  { cmd = cmd "\n"; next }
      else                             { inblock = 0 }
    }
    END { flush() }
  ' "$1"
}

# Runner-only classification. Each pattern names something this machine cannot
# provide or must not fetch.
runner_only () {   # runner_only <cmd> -> 0 if it must be deferred
  case "$1" in
    *sudo*|*apt-get*|*locale-gen*)            return 0 ;;  # needs root on a disposable box
    *elan*|*"lake exe cache"*|*"lake build"*|*"lake env"*)  return 0 ;;  # would DOWNLOAD
    # The Lean mutation suites shell out to `lake build` from INSIDE a loop,
    # so the step command never contains the string above and this function
    # let it run. Measured 2026-08-01: exit 124 -- it hit the 600s bound
    # rebuilding modules for eight suites. Deferring it is honest (the
    # summary prints DEFERRED IS NOT PASSED and the lean job runs it for
    # real); letting it time out reported a FAILURE that was a local budget,
    # not a defect in the step.
    # The step runs with `working-directory: lean`, so its command reads
    # `mutate/mutate_rotgauge.sh` -- WITHOUT the `lean/` prefix. The first
    # pattern written here matched `lean/mutate/` and therefore matched
    # nothing, and the step timed out again. Match the form that is actually
    # in the file.
    *mutate/mutate_*)                         return 0 ;;  # would DOWNLOAD (lake, indirectly)
    *"script -q"*)                            return 0 ;;  # needs a real pty
    *GITHUB_*|*github.workspace*)             return 0 ;;  # runner-provided variables
    *) return 1 ;;
  esac
}

nsteps=$(extract_steps "$WF" | tr -cd "$(printf '')" | wc -c | tr -d ' ')
echo "  NOTE  $nsteps run-steps extracted from $WF"
if [ "$nsteps" -eq 0 ]; then
  bad "no steps extracted -- the parser sees nothing, so a green here would be vacuous"
  exit 1
fi

# --- 2. the clean clone -----------------------------------------------------
CLONE="$(mktemp -d "${TMPDIR:-/tmp}/cidry.XXXXXX")"
mkdir -p "$CLONE/repo"
# NOT `git clone`. A clone carries HEAD, so the first version dry-ran THE LAST
# COMMIT and reported two failures that had already been fixed in the working
# tree -- and would equally have missed a defect introduced by the change being
# tested. A pre-commit instrument that tests the previous commit is worse than
# none: it is confidently about the wrong tree.
#
# `git ls-files -co --exclude-standard` is the tree AS IT STANDS -- tracked plus
# untracked, minus anything .gitignore excludes. That drops exactly the local
# state this checker must not inherit (.lake, logs, editor droppings) while
# keeping the file you just wrote and have not committed.
copied=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  mkdir -p "$CLONE/repo/$(dirname "$f")"
  cp -p "$f" "$CLONE/repo/$f"
  copied=$((copied+1))
done < <(git ls-files -co --exclude-standard)
if [ "$copied" -eq 0 ]; then
  bad "no files copied -- there is no tree to dry-run"
  rm -rf "$CLONE"; exit 1
fi
# A CHECKOUT HAS A .git. Without one, `git ls-files` returns nothing and every
# checker that sweeps TRACKED files silently sweeps zero -- repo-complete.sh
# reported "plugin.json is not tracked" and went red for a reason that exists
# only in this harness. Initialising a repo here reproduces what actions/checkout
# gives the runner, which is the whole point of the exercise.
( cd "$CLONE/repo" && git init -q && git add -A ) >/dev/null 2>&1

# REPRODUCE THE INDEX MODES, or this tree is not what CI checks out.
#
# MEASURED 2026-08-01. The step above builds the scratch tree with `git init`
# + `git add` ON WINDOWS, where the filesystem carries no executable bit -- so
# every tracked .sh landed as 100644 and checker/portability.sh reported
# "43 of 43 .sh files are NOT executable". A real CI runner CLONES, and a clone
# takes its modes from the INDEX, where all 43 are 100755. The dry run was
# failing a step that passes in CI, on a defect it had manufactured itself.
#
# A harness that does not reproduce what it claims to simulate produces false
# REDS, which cost exactly as much trust as false greens: the obvious repair is
# to stop believing the instrument. The modes are copied over from the real
# index instead of being invented by the filesystem.
while IFS= read -r mode_and_path; do
  m=${mode_and_path%% *}; f=${mode_and_path#* }
  [ "$m" = "100755" ] || continue
  ( cd "$CLONE/repo" && git update-index --chmod=+x -- "$f" ) >/dev/null 2>&1
done < <(git ls-files -s | awk '$1=="100755"{print $1, $4}')

# Assert the transfer landed rather than trusting it: a silent failure here
# would put the false red straight back.
want_x=$(git ls-files -s | awk '$1=="100755"' | wc -l | tr -d " ")
got_x=$( ( cd "$CLONE/repo" && git ls-files -s ) | awk '$1=="100755"' | wc -l | tr -d " ")
if [ "$want_x" -ne "$got_x" ]; then
  bad "the scratch index has $got_x executable entries, the real one has $want_x -- the dry run is not simulating a clone"
fi
ok "clean tree materialised: $copied file(s), working tree as it stands, no .lake, no ~/.claude"

# --- 3. run what can be run -------------------------------------------------
ran=0; deferred=0; broke=0
while IFS=$'\x1f' read -r -d $'\x1e' name wd cmd; do
  [ -z "${name:-}" ] && continue
  [ -z "${cmd:-}" ]  && continue
  if runner_only "$cmd"; then
    reason="needs the runner"
    case "$cmd" in
      *sudo*|*apt-get*|*locale-gen*) reason="needs root on a disposable machine" ;;
      *elan*|*lake*)                 reason="would DOWNLOAD a toolchain or mathlib" ;;
      *"script -q"*)                 reason="needs a real pty" ;;
      *GITHUB_*)                     reason="uses runner-provided variables" ;;
    esac
    printf '  DEFER %-52s -- %s\n' "$name" "$reason"
    deferred=$((deferred+1))
    continue
  fi
  ran=$((ran+1))
  # Exit code read DIRECTLY. `timeout` bounds a step that hangs; a hang in CI is
  # a 6-hour job, and a hang here would be an unbounded session.
  # working-directory honoured: the lean job runs from `lean/`, and a step run
  # from the wrong directory fails for a reason that has nothing to do with CI.
  # STDIN FROM /dev/null, and this is not hygiene -- it is a measured defect.
  # Without it a step inherits the loop's own input stream and EATS THE REMAINING
  # RECORDS: the run stopped silently after 16 of 31 steps and still printed
  # PASS. A harness that consumes its own worklist reports a green for the steps
  # it never reached, which is the false green this repository exists to refuse.
  ( cd "$CLONE/repo/${wd:-.}" && timeout 600 bash -c "$cmd" ) </dev/null > "$CLONE/step.$ran.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '  ok    %-52s exit 0\n' "$name"
  elif [ "$rc" -eq 3 ]; then
    printf '  SKIP  %-52s exit 3 -- reported as a skip, never a pass\n' "$name"
  else
    bad "CI step would FAIL on a clean clone: $name (exit $rc)"
    tail -6 "$CLONE/step.$ran.log" | sed 's/^/          /'
    broke=$((broke+1))
  fi
done < <(extract_steps "$WF")

echo
# EVERY EXTRACTED STEP MUST BE ACCOUNTED FOR. This is the assertion that would
# have caught the stdin-eating loop immediately instead of after a green:
# ran + deferred must equal the number of records extracted, or the harness
# stopped early and its verdict covers a tree it did not finish reading.
accounted=$((ran + deferred))
if [ "$accounted" -eq "$nsteps" ]; then
  ok "every extracted step accounted for: $ran run + $deferred deferred = $nsteps"
else
  bad "ACCOUNTING GAP: $ran run + $deferred deferred = $accounted, but $nsteps were extracted -- the loop stopped early and this verdict is incomplete"
fi
[ "$broke" -eq 0 ] && ok "$ran executable CI step(s) pass in a clean clone; $deferred deferred to the runner"
echo "  NOTE  DEFERRED IS NOT PASSED. $deferred step(s) remain unverified until"
echo "        this repository has a remote -- that is the open half of R15."

# --- 4. controls ------------------------------------------------------------
echo
echo "-- negative controls --"
# (a) the extractor must see a planted step
CTLWF="$CLONE/ctl.yml"
cat > "$CTLWF" <<'YAML'
jobs:
  x:
    steps:
      - name: planted control step
        shell: bash
        run: |
          exit 9
YAML
pcmd="$(extract_steps "$CTLWF" | { IFS=$'' read -r -d $'' _n _w _c; printf '%s' "$_c"; })"
if grep -q 'exit 9' <<< "$pcmd"; then
  ok "CONTROL: the extractor reads a planted step's command back"
else
  bad "CONTROL DEAD: the extractor did not recover a planted step (got: '$pcmd')"
fi
# (b) a failing step must be reported as a failure, not swallowed
( cd "$CLONE/repo" && bash -c "$pcmd" ) >/dev/null 2>&1
prc=$?
[ "$prc" -eq 9 ] \
  && ok "CONTROL: a failing step's exit code arrives intact (9), so a red step cannot read as green" \
  || bad "CONTROL DEAD: a step exiting 9 was observed as $prc"

# A step may still hold a handle here (Windows keeps a directory busy longer
# than POSIX does). Report the leftover rather than emit a bare `rm` error that
# reads like a failure of the check itself.
rm -rf "$CLONE" 2>/dev/null || echo "  NOTE  temp tree still busy, left behind: $CLONE"
echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  ci-dryrun: PASS"; exit 0; } || { echo "  ci-dryrun: FAIL"; exit 1; }
