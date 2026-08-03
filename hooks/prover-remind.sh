#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# prover-remind.sh -- ORGAN 4 of the packet, POSIX arm: the proof-debt reminder.
#
# WHAT IT IS FOR, stated as the failure it replaces. The first version of this
# hook emitted a CONSTANT doctrine paragraph every five minutes, byte-identical
# regardless of what the session was doing. A message that never changes stops
# being read -- it becomes wallpaper. Worse, doctrine cannot create initiative
# because it names no TARGET: "prove what must hold for all inputs" is
# unactionable until something says WHICH inputs, in WHICH file, right now.
#
# So this hook MEASURES first and speaks only when it has something specific:
# named files, a named module, a number of minutes. SILENCE IS THE HEALTHY
# STATE and it is the most common one. A reminder that always fires is the
# wallpaper it replaced.
#
# ESCALATION
#   silence            no proof-shaped change pending, a proof was written
#                      recently, and the kernel has nothing to report
#   gentle             debt exists, or the last proof is old
#   loud, first        the KERNEL rejected a module, or a `sorry` is present --
#                      these break silence regardless of everything else,
#                      because `lake build` exit 0 means ELABORATED, and
#                      leanchecker disagreeing means the proof is not a proof
#
# CONTRACT, every clause deliberate:
#   * never blocks, never throws, ALWAYS exits 0. A reminder must not break a
#     build. (`--decide` is the one exception: a usage error exits 2, because a
#     checker calling it wrongly must not silently pass.)
#   * ASCII ONLY in the emitted payload. A non-ASCII byte under a legacy code
#     page can close the JSON string early and silently kill the injection --
#     measured on the private original this is ported from.
#   * throttled per EVENT, not globally, so a tight PreToolUse loop can never
#     starve the UserPromptSubmit lane. Three events are three vantage points:
#     PreToolUse is the only moment a proof obligation can change the action
#     rather than grade it; PostToolUse is when debt becomes attributable;
#     UserPromptSubmit is when the goal itself may have moved.
#
# NOTHING MACHINE-LOCAL. The original hardcoded one workspace, one repo and one
# goal file. Every one of those is an environment variable here with a default
# that works on a fresh clone -- see CONFIG below, and `checker/no-local-paths.sh`
# fails the build if an absolute local path ever returns.
#
# DETERMINISTIC MODE -- this is what makes the two arms cross-diffable:
#
#   prover-remind.sh --decide EVENT MINS LASTPROOF DEBT KRED KSORRY ALARMS
#
# reads NOTHING from disk and prints the decision line (or nothing, for
# silence). `-` means "empty" for any list field. checker/cross-diff-remind.sh
# runs both arms over one corpus and compares byte for byte; two
# implementations that agree is a truth a single green cannot fake.
# =============================================================================

LC_ALL=C
export LC_ALL

# --- CONFIG ------------------------------------------------------------------
# Every one of these is measured from the environment, never baked in.
HERE=$(dirname "$0")
# WHERE THE USER'S OWN PROOFS LIVE -- which is NOT where ours live.
#
# This defaulted straight to the plugin's bundled corpus, and that was wrong in
# a way that quietly disabled the whole point. The bundled lean/ folder sits
# inside plugins/cache: it is READ-ONLY, it is ours, and it never changes. A
# user's own theorems -- the ones that start at zero and accumulate as they
# work -- had no home any hook could see, so the reminder measured debt against
# a corpus that cannot acquire debt, and reported healthy forever.
#
# SETUP_LEAN already asks which filesystem ROOT to install under (C:/, D:/, /)
# and puts .elan there. It now records the workspace it created in the state
# directory as well, so the answer to "where does this machine keep its proofs"
# survives the install and is readable by every later session.
#
# The chain, most specific first. Each step is a deliberate answer, never a
# guess: an explicit environment variable beats a recorded install, and a
# recorded install beats our own shipped corpus.
_ws_from_state () {
  _f="${ROTMOE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/rot-moe}/workspace"
  [ -f "$_f" ] || return 1
  # Backslashes are translated to forward slashes because THIS FILE IS SHARED
  # WITH THE POWERSHELL INSTALLER, which naturally produces a backslash path of
  # the form <drive>:\path\Lean. To POSIX test a backslash is an ordinary
  # character rather than a separator, so testing such a path with -d is
  # false, and this function then returned nothing and the caller fell back to
  # the plugin's READ-ONLY bundled corpus -- emitting no verdict at all rather
  # than an error. The pwsh arm now normalises on write; this normalises on read
  # so a state file recorded by an EARLIER install still resolves.
  _v=$(head -1 "$_f" 2>/dev/null | tr -d '\r' | tr '\\' '/')
  [ -n "$_v" ] && [ -d "$_v" ] && printf '%s' "$_v"
}
WS=${ROTMOE_LEAN_WORKSPACE:-$(_ws_from_state 2>/dev/null)}
[ -n "$WS" ] || WS="$HERE/../lean"
PROOFS_DIR="$WS/Proofs"
WATCH_REPO=${ROTMOE_WATCH_REPO:-.}
STATE_DIR=${ROTMOE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/rot-moe}
GOAL_FILE=${ROTMOE_GOAL_FILE:-}
STALE_MIN=${ROTMOE_PROOF_STALE_MIN:-45}
# Extensions scanned for proof-shaped code. The original was Rust-only; a
# shipped artifact must not be. Override with a space-separated list.
DEBT_EXT=${ROTMOE_DEBT_EXT:-rs c h cpp hpp go ts js py java kt swift}

# The constructs that belong in Lean: casts that can truncate, saturating or
# wrapping arithmetic, clamps, shifts, explicit bounds. Extended-regex.
RISK_RE=${ROTMOE_DEBT_PATTERN:-'as u8|as u16|as u32|as i8|as i16|as i32|as usize|saturating_|wrapping_|checked_|\.clamp\(|\.max\(|\.min\(|<<|>>|MAX_|MIN_|_CAP|_FLOOR|_LIMIT'}

# --- DECIDE ------------------------------------------------------------------
# A PURE function of measured inputs. Nothing below touches the disk, which is
# precisely why it can be compared against the PowerShell arm byte for byte.
#
# Field order is the contract: preamble, kernel, sorry, debt, staleness,
# alarms, method. Any change here must move in the same edit as the .ps1 and as
# checker/corpus-remind.txt, or the cross-diff goes red -- which is the point.
first_n () {   # first_n <csv> <n> -> comma-joined first n items
  printf '%s' "$1" | tr ',' '\n' | sed -n "1,${2}p" | paste -sd',' - 2>/dev/null \
    || printf '%s' "$1" | tr ',' '\n' | sed -n "1,${2}p" | tr '\n' ',' | sed 's/,$//'
}
count_csv () {   # count_csv <csv> -> number of non-empty items
  [ -z "$1" ] || [ "$1" = "-" ] && { echo 0; return; }
  printf '%s' "$1" | tr ',' '\n' | grep -c '[^[:space:]]'
}

# STRIP CARRIAGE RETURNS AT THE BOUNDARY.
#
# MEASURED ON THE GITHUB WINDOWS RUNNER, 2026-08-01, and reproduced locally by
# converting the corpus to CRLF: with `core.autocrlf` on -- which is the DEFAULT
# on a Windows checkout -- the last field of every corpus row arrives as `14\r`.
# `[ "14\r" -gt 0 ]` is not a valid integer comparison, the test is false, and
# the reminder SILENTLY DROPS ITS ENTIRE ALARM WARNING. Not a cosmetic space:
# the sentence disappears, and the hook goes quiet about exactly the thing it
# exists to shout about.
#
# The PowerShell arm never had this -- .NET's integer parse tolerates the CR --
# so the two arms disagreed, which is how it was caught. Neither arm should
# depend on the line endings of the file it was handed.
strip_cr () { printf '%s' "$1" | tr -d '\r'; }

decide () {   # decide EVENT MINS LASTPROOF DEBT KRED KSORRY ALARMS
  _ev=$(strip_cr "$1"); _mins=$(strip_cr "$2"); _last=$(strip_cr "$3")
  _debt=$(strip_cr "$4"); _kred=$(strip_cr "$5"); _ksorry=$(strip_cr "$6")
  _alarms=$(strip_cr "$7")
  [ "$_last" = "-" ] && _last=""
  [ "$_debt" = "-" ] && _debt=""
  [ "$_kred" = "-" ] && _kred=""
  [ "$_ksorry" = "-" ] && _ksorry=""

  _nd=$(count_csv "$_debt"); _nr=$(count_csv "$_kred"); _ns=$(count_csv "$_ksorry")

  # SILENCE. The kernel conditions are ANDed in deliberately: a rejected proof
  # term or a stray `sorry` breaks silence no matter how fresh the last proof is.
  if [ "$_nd" -eq 0 ] && [ "$_mins" -ge 0 ] && [ "$_mins" -lt "$STALE_MIN" ] \
     && [ "$_nr" -eq 0 ] && [ "$_ns" -eq 0 ]; then
    return 1
  fi

  case "$_ev" in
    PreToolUse)
      _out='BEFORE YOU ACT: this is the one moment a proof obligation can change the action rather than judge it. If what you are about to do touches a bound, a cast or a clamp, decide NOW whether it needs a theorem -- deciding afterwards is how debt accumulates.' ;;
    UserPromptSubmit)
      _out='THE SOCIO JUST SPOKE -- re-read the goal before assuming it is unchanged. Carry the standing proof debt into whatever was just asked; a new instruction does not retire an open obligation.' ;;
    *)
      _out='RESULT IS IN -- attribute it. A green build is elaboration, not truth; bind the measurement to a theorem or say plainly that it is MEASURED, not PROVED.' ;;
  esac

  if [ "$_nr" -gt 0 ]; then
    _out="$_out KERNEL REJECTED $_nr module(s): $(first_n "$_kred" 4). leanchecker disagrees with lake build -- those theorems are NOT proved. Fix before anything else."
  fi
  if [ "$_ns" -gt 0 ]; then
    _out="$_out SORRY PRESENT in: $(first_n "$_ksorry" 4). A sorry is an admission, never a result -- report it with a count."
  fi
  if [ "$_nd" -gt 0 ]; then
    _more=""
    [ "$_nd" -gt 4 ] && _more=" (+$((_nd - 4)) more)"
    _out="$_out LEAN DEBT: $_nd uncommitted source file(s) carry cast/clamp/saturating/bound code -- $(first_n "$_debt" 4)$_more."
    _out="$_out For EACH: state in writing what must hold for ALL inputs, then PROVE it or say plainly there is no universal claim."
  fi
  if [ "$_mins" -ge "$STALE_MIN" ]; then
    _out="$_out No proof written for $_mins min (last: $_last)."
  elif [ "$_mins" -lt 0 ]; then
    _out="$_out No .lean proofs found in the configured workspace -- verify ROTMOE_LEAN_WORKSPACE before assuming none exist."
  fi
  if [ "$_alarms" -gt 0 ] 2>/dev/null; then
    _out="$_out $_alarms alarm row(s) open in the goal file; an alarm closes ONLY with instrument + negative control."
  fi
  _out="$_out Close a proof with THREE instruments: lake build (exit code read DIRECTLY, never through a pipe) -> #print axioms (sorryAx = NOT proved; no axioms at all is usually vacuous) -> lake env leanchecker <Module> (kernel recheck; exit 0 with ZERO bytes = pass, a module with no oleans exits 1 = the control). Then MUTATE, delete the stale .olean, rebuild, confirm the theorems DIE. Zero sorry. Never native_decide. A test SAMPLES; a theorem SETTLES."

  # ASCII guard, applied at the single point every path leaves through.
  printf '%s' "$_out" | tr -c '\40-\176' ' '
  return 0
}

# --- MEASURE -----------------------------------------------------------------
# Each probe is individually tolerant: one unreadable path must not blind the
# whole hook. Nothing here is assumed; a probe that cannot measure reports the
# sentinel (-1 / empty) and the decision handles it.
measure_mins_since_proof () {
  [ -d "$PROOFS_DIR" ] || { echo "-1 -"; return; }
  _newest=""; _newest_t=0
  for f in "$PROOFS_DIR"/*.lean; do
    [ -f "$f" ] || continue
    _t=$( { stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null; } )
    [ -z "$_t" ] && continue
    if [ "$_t" -gt "$_newest_t" ]; then _newest_t=$_t; _newest=$f; fi
  done
  [ -z "$_newest" ] && { echo "-1 -"; return; }
  _now=$(date +%s)
  echo "$(( (_now - _newest_t) / 60 )) $(basename "$_newest" .lean)"
}

measure_debt () {
  ( cd "$WATCH_REPO" 2>/dev/null || exit 0
    git rev-parse --git-dir >/dev/null 2>&1 || exit 0
    { git diff --name-only --diff-filter=ACM 2>/dev/null
      git diff --cached --name-only --diff-filter=ACM 2>/dev/null; } | sort -u |
    while IFS= read -r rel; do
      [ -f "$rel" ] || continue
      _ok=0
      for e in $DEBT_EXT; do
        case "$rel" in *.$e) _ok=1 ;; esac
      done
      [ "$_ok" -eq 1 ] || continue
      grep -Eq "$RISK_RE" "$rel" 2>/dev/null && basename "$rel"
    done | paste -sd',' - 2>/dev/null )
}

measure_alarms () {
  [ -n "$GOAL_FILE" ] && [ -f "$GOAL_FILE" ] || { echo 0; return; }
  grep -cE '^>[[:space:]]*\|[[:space:]]*\*{0,2}R[0-9]+[a-z]?\*{0,2}[[:space:]]*\|' "$GOAL_FILE" 2>/dev/null || echo 0
}

measure_kernel () {   # echoes "<red csv>|<sorry csv>" from the watchdog status file
  _vs="$STATE_DIR/lean-verify-status.json"
  [ -f "$_vs" ] || { echo "|"; return; }
  if command -v node >/dev/null 2>&1; then
    node -e '
      const fs=require("fs");
      try{const v=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
        const red=(v.red||[]).map(x=>x.module||x).join(",");
        const s=(v.sorryFiles||[]).join(",");
        process.stdout.write(red+"|"+s);}catch(e){process.stdout.write("|");}' "$_vs" 2>/dev/null || echo "|"
  else
    echo "|"
  fi
}

# --- HOOK MODE ---------------------------------------------------------------
# =============================================================================
# THE HOOK INVOKES LEAN -- WHEN LEAN WORK HAS JUST HAPPENED, AND ONLY THEN.
#
# Reminding a model that it owes a proof is not the same as making it prove one.
# Until this function existed, the reminder READ the workspace off disk -- file
# mtimes, counts -- and reported debt. Nothing ever checked whether the .lean
# file that was just written actually COMPILES. The model could write a theorem,
# be congratulated by its own reminder, and move on; the defect surfaced later,
# in CI, or never.
#
# So: the moment a .lean file is written or edited, the module it belongs to is
# BUILT, and the verdict goes back into the transcript. Practical code is not
# "delivered" until the theorem behind it elaborates.
#
# WHY NOT ON EVERY TURN, WHICH IS THE OBVIOUS ASK. Measured on this machine:
#
#   router hook                       176 ms
#   lake build, ONE module, no-op    1206 ms
#   lake build, one module, edited   1287 ms
#   lake build, whole corpus, no-op  4850 ms
#
# Registering `lake` against every prompt and every tool call adds 1.2-4.9 s to
# each -- a fifty-tool-call session pays one to four MINUTES of waiting for
# answers that are almost always identical to the last one. That is not caution,
# it is arithmetic. Lean runs when Lean work happens: full strength on the turn
# that matters, zero cost on the turns that do not.
#
# THREE GUARDS, each of which makes this SILENT rather than broken:
#   1. no toolchain on PATH  -> silent. The Core variant ships no Lean and must
#      keep working exactly as before; so must a Lean user who has not run
#      SETUP_LEAN yet. A hook that fails because an OPTIONAL dependency is
#      missing has made it mandatory.
#   2. no timeout binary     -> silent. An unbounded build inside a hook does not
#      fail, it HANGS, and a hung hook looks like a hung model.
#   3. ROTMOE_LEAN_VERIFY=0  -> silent, for anyone who wants the router alone.
#
# This is deliberately NOT throttled. Throttling exists so a tight tool loop
# cannot spam advice; a proof that does not compile is not advice.
verify_lean_edit () {
  _pl="$1"
  [ -n "$_pl" ] || return 0
  [ "${ROTMOE_LEAN_VERIFY:-1}" = "0" ] && return 0
  command -v node >/dev/null 2>&1 || return 0
  command -v lake >/dev/null 2>&1 || return 0

  _fp=$(printf '%s' "$_pl" | node -e '
    let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
      try{
        const j=JSON.parse(s), t=j.tool_input||{};
        process.stdout.write(String(t.file_path||t.path||""));
      }catch(e){process.stdout.write("");}});' 2>/dev/null)
  case "$_fp" in
    *.lean) : ;;
    *) return 0 ;;
  esac

  # Bound it or do not run it. Never leave a build unbounded inside a hook.
  if command -v timeout >/dev/null 2>&1; then _tmo=timeout
  elif command -v gtimeout >/dev/null 2>&1; then _tmo=gtimeout
  else return 0; fi

  # The path arrives in whatever form the tool used; the module name is derived
  # from the part BELOW the workspace root. Both separators are handled because
  # a Windows tool call reports backslashes while the shell speaks forward ones.
  # THREE candidate spellings of the same directory, because `pwd` and the tool
  # call disagree on Windows and the mismatch fails SILENTLY:
  #
  #   pwd      -> /d/tmp/ws/Lean      (Git Bash POSIX form)
  #   pwd -W   -> D:/tmp/ws/Lean      (Windows form; unsupported off Git Bash)
  #   $WS      -> whatever was recorded, e.g. D:/tmp/ws/Lean
  #
  # The tool reports 'D:/tmp/ws/Lean/Proofs/X.lean', so matching ONLY against
  # `pwd` never fired, control fell to the fallback, and the fallback below was
  # LOWERCASE-ONLY -- so a workspace at <root>/Lean, which is the layout the
  # installer now creates, matched nothing and the hook returned quietly. A
  # verifier that goes silent on the supported layout is worse than one that
  # errors, because nothing tells you it stopped looking.
  _wsp=$(cd "$WS" 2>/dev/null && pwd) || return 0
  _wsw=$(cd "$WS" 2>/dev/null && pwd -W 2>/dev/null) || _wsw=""
  _norm=$(printf '%s' "$_fp" | tr '\\' '/')
  _rel=""
  for _cand in "$_wsw" "$_wsp" "$WS"; do
    [ -n "$_cand" ] || continue
    _c=$(printf '%s' "$_cand" | tr '\\' '/')
    case "$_norm" in "$_c"/*) _rel=${_norm#"$_c"/}; break ;; esac
  done
  if [ -z "$_rel" ]; then
    # Both spellings of the directory name. Case matters to `case`, and the
    # installer creates 'Lean' while the bundled corpus ships as 'lean'.
    case "$_norm" in
      */lean/*) _rel=${_norm##*/lean/} ;;
      */Lean/*) _rel=${_norm##*/Lean/} ;;
      *)        return 0 ;;
    esac
  fi
  _mod=$(printf '%s' "${_rel%.lean}" | tr '/' '.')
  [ -n "$_mod" ] || return 0

  _t0=$(date +%s%N 2>/dev/null)
  _log=$( cd "$WS" 2>/dev/null && "$_tmo" "${ROTMOE_LEAN_VERIFY_SECS:-300}" lake build "$_mod" 2>&1 )
  _rc=$?
  _t1=$(date +%s%N 2>/dev/null)
  _ms=$(( (${_t1:-0} - ${_t0:-0}) / 1000000 ))
  [ "$_ms" -lt 0 ] && _ms=0

  # A file may contain `sorry` and still elaborate. Reporting that as a pass is
  # the exact laundering this project exists to prevent, so it is a THIRD state.
  #
  # THIS USED TO SCAN THE FILE'S TEXT for `\bsorry\b`, and it was WRONG in the
  # direction that matters least for safety but most for trust: it cried wolf.
  # A doc comment reading "no sorry, no native_decide" -- the exact sentence
  # this project's own discipline puts in files -- was counted as an admission.
  # Found by an armed 50-turn session on 2026-08-03 that wrote a clean module,
  # was told twice it "contains 1 sorry", and had to argue with its own tool.
  #
  # An alarm that fires on correct work teaches people to ignore alarms, which
  # costs more than the false positive itself.
  #
  # The fix is to stop guessing from text and ask the ELABORATOR, which knows
  # the difference between a term and a word in a comment. Measured both ways
  # on Lean 4.33.0-rc1:
  #   a real `by sorry`          -> build exit 0 AND "declaration uses `sorry`"
  #   `sorry` only in comments   -> build exit 0 and ZERO such warnings
  #                                 (the old text scan counted 2 -- the bug)
  # The compiler's own warning is per-DECLARATION, so the count is also more
  # honest than "how many times the word appears".
  _sry=$(printf '%s' "$_log" | grep -c "declaration uses \`sorry\`" 2>/dev/null)
  case "$_sry" in ''|*[!0-9]*) _sry=0 ;; esac

  if [ "$_rc" -eq 124 ]; then
    printf 'LEAN TIMED OUT: %s did not finish in %ss. NOT proved -- a build you killed is not a verdict.' \
      "$_mod" "${ROTMOE_LEAN_VERIFY_SECS:-300}"
  elif [ "$_rc" -ne 0 ]; then
    _err=$(printf '%s' "$_log" | grep -m1 'error:' | cut -c1-200)
    printf 'LEAN REFUSED: %s does NOT build (lake build exit %s, %sms). First error: %s -- this is not proved. Fix it before the code is called delivered.' \
      "$_mod" "$_rc" "$_ms" "${_err:-<no error line captured>}"
  elif [ "$_sry" -gt 0 ]; then
    printf 'LEAN INCOMPLETE: %s builds (exit 0, %sms) but contains %s sorry. A sorry is an ADMISSION, not a proof -- the module is not done.' \
      "$_mod" "$_ms" "$_sry"
  else
    printf 'LEAN VERIFIED: %s builds, lake build exit 0 in %sms, zero sorry. Elaboration is not truth -- close it with #print axioms (sorryAx = not proved) and lake env leanchecker %s.' \
      "$_mod" "$_ms" "$_mod"
  fi
}

# No arguments means "you were called as a hook". That default is not a
# nicety: R20 measured the router shipping with only its flag modes while
# ARM_ROUTER registered it with none, so every real invocation hit the usage
# branch and exited 2 -- green everywhere, dead in production.
hook_mode () {
  ev=PostToolUse
  if [ ! -t 0 ]; then
    payload=$(cat)
    if [ -n "$payload" ] && command -v node >/dev/null 2>&1; then
      _e=$(printf '%s' "$payload" | node -e '
        let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
          try{const j=JSON.parse(s);process.stdout.write(String(j.hook_event_name||""));}
          catch(e){process.stdout.write("");}});' 2>/dev/null)
      [ -n "$_e" ] && ev=$_e
    fi
  fi
  # Scrub: the event is echoed back into JSON, so it may only be a name.
  ev=$(printf '%s' "$ev" | tr -cd 'A-Za-z0-9_-')
  [ -z "$ev" ] && ev=PostToolUse

  # VERIFY FIRST, ADVISE SECOND. If a .lean file was just written, the build
  # verdict is the most important thing that can go back into the transcript --
  # more important than any reminder, and immune to being talked out of.
  _lean=""
  [ "$ev" = "PostToolUse" ] && _lean=$(verify_lean_edit "${payload:-}" 2>/dev/null)

  # Per-event throttle. Independent stamps, so no lane can silence another.
  case "$ev" in
    UserPromptSubmit) thr=${ROTMOE_THROTTLE_PROMPT:-0} ;;
    PreToolUse)       thr=${ROTMOE_THROTTLE_PRE:-7} ;;
    *)                thr=${ROTMOE_THROTTLE_POST:-5} ;;
  esac
  # A build verdict is never throttled. Throttling exists so a tight tool loop
  # cannot spam ADVICE; "this module does not compile" is not advice, and a
  # verdict suppressed because a similar one appeared four minutes ago is a
  # defect that ships.
  [ -n "$_lean" ] && thr=0
  mkdir -p "$STATE_DIR" 2>/dev/null
  stampf="$STATE_DIR/prover-remind.$ev.stamp"
  if [ "$thr" -gt 0 ] && [ -f "$stampf" ]; then
    _st=$( { stat -c %Y "$stampf" 2>/dev/null || stat -f %m "$stampf" 2>/dev/null; } )
    if [ -n "$_st" ]; then
      _age=$(( ($(date +%s) - _st) / 60 ))
      [ "$_age" -lt "$thr" ] && exit 0
    fi
  fi

  set -- $(measure_mins_since_proof)
  mins=${1:--1}; lastp=${2:--}
  debt=$(measure_debt); [ -z "$debt" ] && debt=-
  kern=$(measure_kernel)
  kred=${kern%%|*}; [ -z "$kred" ] && kred=-
  ksorry=${kern#*|}; [ -z "$ksorry" ] && ksorry=-
  alarms=$(measure_alarms)

  ctx=$(decide "$ev" "$mins" "$lastp" "$debt" "$kred" "$ksorry" "$alarms") || ctx=""

  # THE VERDICT OUTRANKS THE ADVICE, and the `|| exit 0` this replaced is why
  # that has to be said in code. `decide` returns non-zero when it has nothing
  # worth saying, which is the common case -- so a build failure would have been
  # discarded on the way out because the REMINDER was feeling quiet. The verdict
  # goes first, and its presence alone is enough to speak.
  if [ -n "$_lean" ]; then
    ctx="$_lean${ctx:+ }$ctx"
  fi
  [ -z "$ctx" ] && exit 0

  date +%s > "$stampf" 2>/dev/null
  # The invoking event MUST be echoed back or Claude Code discards the payload
  # silently -- a hook that appears wired, runs, and delivers nothing.
  esc=$(printf '%s' "$ctx" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}' "$ev" "$esc"
  exit 0
}

# --- entry point -------------------------------------------------------------
[ $# -eq 0 ] && hook_mode

case "$1" in
  --decide)
    shift
    [ $# -eq 7 ] || { echo "usage: prover-remind.sh --decide EVENT MINS LASTPROOF DEBT KRED KSORRY ALARMS" >&2; exit 2; }
    decide "$1" "$2" "$3" "$4" "$5" "$6" "$7" && printf '\n'
    exit 0 ;;
  --version) echo "prover-remind.sh 1.0.0"; exit 0 ;;
  *) echo "usage: prover-remind.sh                (hook mode, JSON on stdin)" >&2
     echo "       prover-remind.sh --decide EVENT MINS LASTPROOF DEBT KRED KSORRY ALARMS" >&2
     exit 2 ;;
esac
