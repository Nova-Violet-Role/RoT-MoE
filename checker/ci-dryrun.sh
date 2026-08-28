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

# --- a bound that does not assume GNU coreutils ------------------------------
# macOS does NOT ship `timeout` (it is GNU coreutils). A bare `timeout N cmd` is
# "command not found" there, which returns an EMPTY capture -- and an empty
# capture reads exactly like a tool that answered nothing. Homebrew installs the
# same binary as `gtimeout`. If neither exists the call runs UNBOUNDED, and that
# is announced rather than hidden. Full story: checker/release-install.sh.
if command -v timeout >/dev/null 2>&1; then TMOBIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then TMOBIN=gtimeout
else TMOBIN=""; fi
run_bounded () {   # run_bounded <seconds> <cmd...>; reads stdin like the command it wraps
  _secs="$1"; shift
  if [ -n "$TMOBIN" ]; then "$TMOBIN" "$_secs" "$@"; else
    [ -n "${_unbounded_warned:-}" ] || { printf "  ----  UNBOUNDED: no timeout/gtimeout on PATH; a hang cannot be detected here\n" >&2; _unbounded_warned=1; }
    "$@"
  fi
}
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=ci-dryrun::%s\n' "$*"; fail=$((fail+1)); }

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
      if (name != "" && cmd != "") printf "%s\x1f%s\x1f%s\x1f%s\x1e", name, wd, sh, cmd
      name = ""; cmd = ""; wd = ""; sh = ""
    }
    /^      - name: /            { flush(); name = substr($0, 15); next }
    /^        working-directory: / { wd = substr($0, 28); next }
    # THE DECLARED SHELL IS PART OF THE STEP. Without it every step ran under
    # bash -c, so a pwsh step had its PowerShell body parsed as bash and died on
    # a syntax error at the opening brace. That is not the step failing, it is
    # the harness running it wrong -- and it reported the invented failure in the
    # same words as a real one, the exact confusion the comment above warns of.
    # NOTE: this awk program is single-quoted, so no apostrophe may appear in
    # these comments. Quoting the shell error verbatim here ended the quote and
    # broke the whole script -- measured, bash reported a syntax error on this
    # very line.
    /^        shell: /           { sh = substr($0, 16); next }
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
    # `lake --version` belongs here with the rest: on a machine without the
    # toolchain it is not a cheap read, it is `bash: lake: command not found`
    # exit 127 -- MEASURED 2026-08-17 on the "toolchain (read, never assumed)"
    # step, reported as "CI step would FAIL on a clean clone" when the clone
    # was fine and only this machine lacks Lean. The step exists to READ the
    # runner's toolchain; without a toolchain there is nothing to read, and
    # installing one to answer a dry run is exactly the download this list
    # exists to refuse.
    *elan*|*"lake exe cache"*|*"lake build"*|*"lake env"*|*"lake --version"*)  return 0 ;;  # would DOWNLOAD
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

# ⚠ THIS FILE CONTAINS THREE RAW CONTROL BYTES ON PURPOSE -- DO NOT "CLEAN" THEM.
#
# The line below and the read at the bottom of this file use ASCII RS (0x1E,
# record separator) and US (0x1F, unit separator) as delimiters. They are
# written as `printf '<RS>'` and `$'<US>'`, so in an editor they look like an
# EMPTY string and an odd `$''` -- which is exactly why this note exists.
#
# WHY THESE BYTES: a workflow step's `run:` block contains newlines, tabs,
# quotes, pipes and colons, so every printable delimiter can occur inside the
# payload. RS and US cannot: they are the two bytes YAML will never carry.
#
# THEY ARE THE ONLY EXCEPTION to the project's "no control bytes but TAB and LF"
# rule, they are load-bearing, and a sweep that strips them does not fail
# silently -- `nsteps` becomes 0 and the guard immediately below refuses with
# "no steps extracted ... a green here would be vacuous". Loud, not quiet. But
# a reader who deletes them will still have broken a working checker, so:
#   verify with   LC_ALL=C grep -c -P '[\x1e\x1f]' checker/ci-dryrun.sh   -> 3
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
# The path is taken from the TAB-delimited field, never from a whitespace
# split: `awk '{print $4}'` truncated 'Lean Theorem/...' to 'Lean', the
# update-index above it failed into /dev/null, and the assertion below went
# red by exactly the number of executable paths containing a space (4).
while IFS= read -r f; do
  ( cd "$CLONE/repo" && git update-index --chmod=+x -- "$f" ) >/dev/null 2>&1
done < <(git ls-files -s | awk -F'\t' 'index($1, "100755") == 1 {print $2}')

# Assert the transfer landed rather than trusting it: a silent failure here
# would put the false red straight back.
want_x=$(git ls-files -s | awk '$1=="100755"' | wc -l | tr -d " ")
got_x=$( ( cd "$CLONE/repo" && git ls-files -s ) | awk '$1=="100755"' | wc -l | tr -d " ")
if [ "$want_x" -ne "$got_x" ]; then
  bad "the scratch index has $got_x executable entries, the real one has $want_x -- the dry run is not simulating a clone"
fi
# A REAL CLONE HAS A COMMIT. This scratch repo had an index -- the exec-bit
# transfer above proves that -- but no HEAD, and several CI steps read HEAD:
# `git rev-parse HEAD`, `git archive HEAD`, `git diff HEAD`. They failed here
# and passed on ubuntu and windows in the same cycle, which is the definition of
# a harness manufacturing its own red. checker/release-local.sh printed
# `REFUSE: could not read HEAD` for exactly this reason.
#
# The same lesson as the exec bits twenty lines up: reproduce what you claim to
# simulate. Deferring these steps would have been the cheap answer and the wrong
# one -- it hides a real capability behind a shrug instead of restoring it.
#
# Identity is passed with -c so nothing is read from, or written to, the user's
# git config.
( cd "$CLONE/repo" \
  && git -c user.email=dryrun@invalid -c user.name="ci-dryrun" \
       commit -q -m "dry-run baseline" --no-verify ) >/dev/null 2>&1
scratch_head=$( ( cd "$CLONE/repo" && git rev-parse HEAD 2>/dev/null ) )
case "$scratch_head" in
  [0-9a-f][0-9a-f]*)
    ok "the scratch clone has a readable HEAD -- steps that read HEAD can actually run" ;;
  *)
    bad "the scratch clone has NO HEAD; every step reading HEAD will fail for a reason CI does not have" ;;
esac

ok "clean tree materialised: $copied file(s), working tree as it stands, no .lake, no ~/.claude"

# --- 3. run what can be run -------------------------------------------------
# `--from N` / `--to N` SELECT A STEP WINDOW, and the reason is operational
# rather than cosmetic. A full pass over the step list exceeds ten minutes, and
# the agent harness driving this repo terminates a foreground command at exactly
# that bound -- so the only way to complete a pass was to detach it. That is how
# a run of this checker once overlapped a mutation suite, which deletes .olean
# files mid-flight, and reported two Lean steps RED for a reason that existed
# only in the concurrency. Neither reproduced when re-run alone.
#
# A window makes the whole list reachable BY HAND, in sequence, with nothing else
# touching the tree:
#     bash checker/ci-dryrun.sh --to 20
#     bash checker/ci-dryrun.sh --from 21
#
# The default is unchanged -- bare invocation still runs everything, and CI still
# calls it bare. A window narrows what is EXECUTED, never what is judged: steps
# outside it are reported as WINDOWED and counted separately, so a partial pass
# can never read as a full green.
FROM=1; TO=0   # TO=0 means "no upper bound"
while [ $# -gt 0 ]; do
  case "$1" in
    --from) FROM="${2:-1}"; shift 2 ;;
    --to)   TO="${2:-0}";   shift 2 ;;
    -h|--help)
      echo "usage: ci-dryrun.sh [--from N] [--to N]"
      echo "  no flags: every step (the CI-equivalent run)"
      echo "  a window runs a contiguous slice; the rest are reported WINDOWED,"
      echo "  never as passes. Step numbers are stable for one step list."
      exit 0 ;;
    *) echo "REFUSE: unknown argument '$1' -- an ignored flag is how a checker"
       echo "        silently stops checking. Use --help."; exit 2 ;;
  esac
done
case "$FROM$TO" in *[!0-9]*) echo "REFUSE: --from/--to take integers"; exit 2 ;; esac

ran=0; deferred=0; broke=0; windowed=0; stepno=0; deferred_names=""
while IFS=$'\x1f' read -r -d $'\x1e' name wd sh cmd; do
  [ -z "${name:-}" ] && continue
  [ -z "${cmd:-}" ]  && continue
  stepno=$((stepno+1))
  if [ "$stepno" -lt "$FROM" ] || { [ "$TO" -gt 0 ] && [ "$stepno" -gt "$TO" ]; }; then
    printf '  ...   %-52s WINDOWED (step %d, not run)\n' "$name" "$stepno"
    windowed=$((windowed+1)); continue
  fi
  # HONOUR THE DECLARED SHELL, or DEFER -- never run a body under the wrong one.
  # `shell: pwsh` steps exist in ci.yml (the Windows zip provisioning), and
  # running their PowerShell under bash produced a syntax error reported as
  # "CI step would FAIL on a clean clone". Measured at 61fc0ec in a clean
  # worktree, so it predates today's edits: 4 passed, 1 failed, every time.
  RUNNER_SH="bash"
  case "${sh:-}" in
    ""|bash|sh) RUNNER_SH="bash" ;;
    pwsh|powershell)
      if command -v pwsh >/dev/null 2>&1; then
        RUNNER_SH="pwsh"
      else
        printf '  DEFER %-52s -- declares shell: %s and pwsh is absent here\n' "$name" "$sh"
        deferred=$((deferred+1))
        deferred_names="$deferred_names$name :: pwsh absent"$'\n'; continue
      fi ;;
    *)
      printf '  DEFER %-52s -- declares an unsupported shell: %s\n' "$name" "$sh"
      deferred=$((deferred+1))
      deferred_names="$deferred_names$name :: unsupported shell"$'\n'; continue ;;
  esac
  if runner_only "$cmd"; then
    reason="needs the runner"
    case "$cmd" in
      *sudo*|*apt-get*|*locale-gen*) reason="needs root on a disposable machine" ;;
      *elan*|*lake*)                 reason="would DOWNLOAD a toolchain or mathlib" ;;
      *"script -q"*)                 reason="needs a real pty" ;;
      *GITHUB_*)                     reason="uses runner-provided variables" ;;
    esac
    printf '  DEFER %-52s -- %s\n' "$name" "$reason"
    deferred=$((deferred+1)); deferred_names="$deferred_names$name :: $reason"$'\n'
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
  if [ "$RUNNER_SH" = "pwsh" ]; then
    ( cd "$CLONE/repo/${wd:-.}" && run_bounded 600 pwsh -NoProfile -Command "$cmd" ) </dev/null > "$CLONE/step.$ran.log" 2>&1
  else
    ( cd "$CLONE/repo/${wd:-.}" && run_bounded 600 bash -c "$cmd" ) </dev/null > "$CLONE/step.$ran.log" 2>&1
  fi
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
# WINDOWED steps are counted here so the accounting identity still holds. That
# identity is the guard against the loop stopping early and the verdict reading
# green for steps nobody reached -- a real defect this harness has had -- so a
# window must be ACCOUNTED FOR, never subtracted from the total.
accounted=$((ran + deferred + windowed))
if [ "$accounted" -eq "$nsteps" ]; then
  ok "every extracted step accounted for: $ran run + $deferred deferred + $windowed windowed = $nsteps"
else
  bad "ACCOUNTING GAP: $ran run + $deferred deferred + $windowed windowed = $accounted, but $nsteps were extracted -- the loop stopped early and this verdict is incomplete"
fi
# DEFERRAL MUST BE DECLARED, BY NAME AND BY REASON.
#
# `deferred` was the second counter this verdict never consulted. Unlike
# `windowed` it must NOT force a non-zero exit: the two steps below genuinely
# cannot run in a local clone -- one needs root on a disposable machine, the
# other reads runner-provided variables -- and a check that reddens for a
# correct environment is a defect, not a safeguard. It would be deleted the
# first time it fired, taking the real coverage with it.
#
# So the guard is a RATCHET on the declared SET, not a demand for zero:
#   * a deferral that is not declared here is a FAILURE -- a step has quietly
#     become unverifiable and nobody said so;
#   * a declared deferral that did NOT happen is reported, never failed, because
#     running MORE steps must never turn this red.
#
# Name AND reason are matched. Name alone would let a stale entry shelter a step
# that starts deferring for an entirely different reason under the same name.
#
# Measured 2026-08-10 (pwsh IS present on this host, so neither is a shell defer).
#
# RE-MEASURED 2026-08-17, and the table below is the repair of a defect this
# very ratchet caught: the extractor reads EVERY job in ci.yml, the lean job's
# steps defer by pattern (downloads, runner variables, a real pty), and none of
# them had ever been declared -- thirteen undeclared deferrals on a bare run,
# on any machine. The ratchet fired exactly as designed; the table had simply
# never been taught the lean job. Every entry below is a deferral that
# genuinely cannot run in a local clone, each with the reason the classifier
# itself assigns. Entries that DO run on a better-equipped host ("provide zip"
# runs wherever pwsh exists) are fine to declare: a declared deferral that did
# not happen is reported, never failed.
DECLARED_DEFERRALS="install comma-decimal locales :: needs root on a disposable machine
provide a bound (gtimeout/timeout must exist on every runner) :: uses runner-provided variables
plugin root consistency (declared roots exist and agree) :: uses runner-provided variables
provide zip (Git Bash on Windows ships unzip only) :: pwsh absent
tty guard -- pty refusal where a pty exists, non-blocking everywhere :: needs a real pty
install elan (toolchain pinned by lean/lean-toolchain) :: would DOWNLOAD a toolchain or mathlib
toolchain (read, never assumed) :: would DOWNLOAD a toolchain or mathlib
mathlib cache -- NEVER build it from source :: would DOWNLOAD a toolchain or mathlib
lake build (exit code read DIRECTLY, never through a pipe) :: would DOWNLOAD a toolchain or mathlib
gauge cross-check -- Lean mirror vs the running hook (MUST run here) :: would DOWNLOAD a toolchain or mathlib
axiom audit -- #print axioms on every theorem, zero sorryAx :: uses runner-provided variables
non-vacuity audit -- every guarded theorem has a witness :: would DOWNLOAD a toolchain or mathlib
non-vacuity NEGATIVE CONTROL -- the audit must be able to fail :: would DOWNLOAD a toolchain or mathlib
decorative-vs-load-bearing isolation :: would DOWNLOAD a toolchain or mathlib
leanchecker -- kernel re-verification, with its negative control :: would DOWNLOAD a toolchain or mathlib
mutation suites -- theorems must DIE when the model breaks :: needs the runner
publish the release -- only a dispatch asks, only this run's proof answers :: uses runner-provided variables"

UNDECL="${TMPDIR:-/tmp}/cidry-undeclared.$$"
: > "$UNDECL"
printf '%s' "$deferred_names" | while IFS= read -r d; do
  [ -z "$d" ] && continue
  case "$DECLARED_DEFERRALS" in
    *"$d"*) : ;;
    *) printf '%s\n' "$d" >> "$UNDECL" ;;
  esac
done
# `grep -c` prints 0 AND exits 1 on no match, so `grep -c ... || echo 0` yields
# TWO lines and every later [ -eq ] on it is a syntax error reported as a FAIL
# with an empty message. Measured here on the first run: "FAIL  0". wc -l cannot
# do that.
undeclared=$(wc -l < "$UNDECL" | tr -d ' ')
if [ "${undeclared:-0}" -eq 0 ]; then
  ok "every deferral is declared by name and reason ($deferred deferred)"
else
  while IFS= read -r u; do echo "        undeclared deferral: $u"; done < "$UNDECL"
  bad "$undeclared step(s) DEFERRED without being declared -- a step became unverifiable and the verdict stayed green"
fi
rm -f "$UNDECL"

if [ "$windowed" -gt 0 ]; then
  echo "  PARTIAL  $windowed step(s) were WINDOWED OUT (--from $FROM${TO:+ --to $TO})."
  echo "           This run is NOT a full pass. Windowed is not passed, not"
  echo "           deferred, and not skipped -- it is untested. Run the"
  echo "           complementary window before calling the step list green."
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
pcmd="$(extract_steps "$CTLWF" | { IFS=$'' read -r -d $'' _n _w _s _c; printf '%s' "$_c"; })"
if grep -q 'exit 9' <<< "$pcmd"; then
  ok "CONTROL: the extractor reads a planted step's command back"
else
  bad "CONTROL DEAD: the extractor did not recover a planted step (got: '$pcmd')"
fi
# (a2) THE SHELL FIELD MUST BE RECOVERED TOO. It is what decides which
# interpreter runs the body, and a capture that silently returned empty would
# send every step back to bash -- reinstating the defect this control exists for,
# invisibly, because bash is also the correct answer for most steps.
pshell="$(extract_steps "$CTLWF" | { IFS=$'\x1f' read -r -d $'\x1e' _n _w _s _c; printf '%s' "$_s"; })"
[ "$pshell" = "bash" ] \
  && ok "CONTROL: the extractor recovers the declared shell (bash)" \
  || bad "CONTROL DEAD: the declared shell was not recovered (got: '$pshell')"
CTLWF2="$CLONE/ctl2.yml"
cat > "$CTLWF2" <<'YAML'
jobs:
  x:
    steps:
      - name: planted pwsh step
        shell: pwsh
        run: |
          exit 9
YAML
pshell2="$(extract_steps "$CTLWF2" | { IFS=$'\x1f' read -r -d $'\x1e' _n _w _s _c; printf '%s' "$_s"; })"
[ "$pshell2" = "pwsh" ] \
  && ok "CONTROL: a non-bash shell is recovered as itself (pwsh), not defaulted away" \
  || bad "CONTROL DEAD: a pwsh step was recovered as '$pshell2' -- it would run under the wrong interpreter"
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

# A WINDOWED RUN IS NOT A PASS, AND THE EXIT CODE MUST SAY SO.
#
# Measured 2026-08-10: `ci-dryrun.sh --from 9999` windowed out ALL 76 steps,
# printed the honest PARTIAL paragraph above -- "This run is NOT a full pass" --
# and then exited 0 with "ci-dryrun: PASS". The prose was right and the verdict
# was wrong, which is the worse half to get wrong: checker/gate-all.sh reads the
# EXIT CODE, not the paragraph. Zero steps executed, recorded as green.
#
# That is precisely the "no skip, no fake green" violation this repo bans, and
# it was reachable with one flag. Exit 3 is this repo's "did not run", which no
# caller counts as a pass.
if [ "$windowed" -gt 0 ]; then
  echo "  ci-dryrun: PARTIAL -- $windowed of $nsteps step(s) never ran (exit 3, never a pass)"
  exit 3
fi
[ "$fail" -eq 0 ] && { echo "  ci-dryrun: PASS"; exit 0; } || { echo "  ci-dryrun: FAIL"; exit 1; }
