#!/bin/sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# ANIMUS -- the paired observer (8.0.0). Self-distillation through hard study.
#
# Two agents in parallel: a WORKER session solves the task, and this process
# watches what the worker is actually DOING -- not its words, its measured
# events -- and queues the self-acknowledgment the worker forgot, mid-turn,
# through the same channel the lenses already speak on. The worker-side ear
# is in both router arms (ROTMOE_ANIMUS=1, PostToolUse, one remark FIFO per
# event); this file is the eye.
#
# THE OBSERVER IS DETERMINISTIC. It is the router applied to the event
# stream, never a second model: every trigger below is a measured predicate
# over the worker's own debug sink, every threshold is declared in
# hooks/rot-voice.dtd (ENV.26-32), and a checker can replay any firing from
# the same records. A judgment no checker could replay does not belong here.
#
# WHAT IT READS: the worker's central debug sink,
#   <state-dir>/rot-debug.<session>.jsonl
# -- the same path hooks/rot-router.sh resolves (read from the router, not
# guessed: the naming lives at its W7 default block). Records used:
#   kind=route   event/lane/stem/chars/ms  (the worker's every step)
#   kind=anomaly shape/tool                (the sentinel's own log line)
#
# WHAT IT WRITES: at most one remark line per trigger firing, "Lens|text",
# into <state-dir>/animus-queue.<session>. The queue is CROSS-PROCESS, so
# every write is rename-atomic and NEVER touches an existing queue file:
# pending remarks wait in a private spool until the worker has consumed the
# previous batch, then land as one atomically-linked file. The consumer's
# whole-file mv-take can therefore never read a half-written line, and a
# consumed remark can never be resurrected by a late writer. The one
# theoretical loss window (consumer writing its FIFO remainder back at the
# exact instant this side links a fresh queue) loses a remark, never
# duplicates one -- and the counters keep counting, so a lost remark
# re-earns its place. Degradation is always toward silence.
#
# BUDGETS (frozen 2026-08-19, Soleil's pricing): at most THREE remarks per
# lens per run -- a critic that repeats is wallpaper, the blind campaign's
# own word. The one-remark-per-event half of the budget is the consumer's.
#
# THE DISTILLATE is the memory: every remark and its measured next-action
# delta (the 3 events before vs the 3 after, quoted from the sink -- raw
# data, no prose judgment) appends to the project distillate and the global
# one. The next run loads global first, then project (the specific overrides
# the general). The hooks never read either file.
#
# This is an OPERATOR TOOL, not a hook: nothing registers it, it blocks no
# turn, and it has no PowerShell twin by design (the DTD says so). POSIX sh.
#
# usage: animus-observe.sh <worker-session> [--task <text>] [--once] [--watch]
#   --task   the worker's task text, for the text-vs-stream pair (Violet /
#            Chroma): the router itself judges the task's register.
#   --once   one pass over the sink as it stands, then exit (checkers).
#   --watch  narrate every record classification, not just the firings.
# =============================================================================

# --- arguments ---------------------------------------------------------------
SESS=''
TASK=''
ONCE=0
WATCH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --task)  TASK=${2:-}; shift 2 ;;
    --once)  ONCE=1; shift ;;
    --watch) WATCH=1; shift ;;
    -*)      echo "animus-observe: unknown option $1" >&2; exit 2 ;;
    *)       SESS=$1; shift ;;
  esac
done
[ -n "$SESS" ] || { echo "usage: animus-observe.sh <worker-session> [--task <text>] [--once] [--watch]" >&2; exit 2; }

# Same scrub as the router's _rot_scrub: the session id becomes a filename.
SESS=$(printf '%s' "$SESS" | tr -cd 'A-Za-z0-9-' | cut -c1-64)
[ -n "$SESS" ] || SESS=unknown

SELF_DIR=${0%/*}

# --- paths: read from the router's own naming, never guessed -----------------
STATE="${ROTMOE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/rot-moe}"
SINK="$STATE/rot-debug.$SESS.jsonl"
Q="$STATE/animus-queue.$SESS"

# --- thresholds: every one DECLARED (rot-voice.dtd ENV.26-32) ----------------
AN_N=${ROTMOE_ANIMUS_ANOMALY_N:-2}
COST_N=${ROTMOE_ANIMUS_COST_N:-3}
DITHER_N=${ROTMOE_ANIMUS_DITHER_N:-3}
BLOAT_N=${ROTMOE_ANIMUS_BLOAT_N:-3}
LOOP_N=${ROTMOE_ANIMUS_LOOP_N:-4}
TEXT_N=${ROTMOE_ANIMUS_TEXT_N:-6}
STALL_S=${ROTMOE_ANIMUS_STALL_SECS:-120}
for _v in "$AN_N" "$COST_N" "$DITHER_N" "$BLOAT_N" "$LOOP_N" "$TEXT_N" "$STALL_S"; do
  case "$_v" in *[!0-9]*|'') echo "animus-observe: a threshold is not a number: '$_v'" >&2; exit 2 ;; esac
done

# --- distillates (two tiers, both declared: ENV.33 / ENV.34) -----------------
DIST="${ROTMOE_ANIMUS_DISTILLATE:-$PWD/.rot-moe/animus-distillate.md}"
DIST_G="${ROTMOE_ANIMUS_DISTILLATE_GLOBAL:-$STATE/animus-distillate.md}"

# The project tier lives in .rot-moe/, which self-gitignores exactly as the
# router's project sink does: operator data must never pollute someone
# else's `git status` or get committed by accident.
_dist_dir=${DIST%/*}
if [ "$_dist_dir" != "$DIST" ] && [ ! -d "$_dist_dir" ]; then
  if mkdir -p "$_dist_dir" 2>/dev/null; then
    case "$_dist_dir" in
      */.rot-moe) [ -f "$_dist_dir/.gitignore" ] || printf '*\n' > "$_dist_dir/.gitignore" 2>/dev/null || : ;;
    esac
  fi
fi
mkdir -p "$STATE" 2>/dev/null || :

distill () {
  printf '%s\n' "$1" >> "$DIST" 2>/dev/null || :
  printf '%s\n' "$1" >> "$DIST_G" 2>/dev/null || :
}

say () { printf 'animus: %s\n' "$1"; }
watchsay () { [ "$WATCH" -eq 1 ] && printf 'animus? %s\n' "$1"; return 0; }

# --- working state -----------------------------------------------------------
WORK=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/animus-work.$$")
mkdir -p "$WORK" 2>/dev/null
PEND="$WORK/pending"; : > "$PEND"
PAIRS="$WORK/pairs"; : > "$PAIRS"
trap 'rm -rf "$WORK" 2>/dev/null; exit 0' INT TERM

n_blank=0; n_interrupted=0; n_zerobyte=0
cost_run=1;  cost_start=''
bloat_run=1; bloat_start=''
prev_ms=''; prev_chars=''
dither_run=0
text_seen=0; text_hit=0; text_fired=0
stall_pending=0; stall_epoch=0
recent3=''
delta_arm=-1; delta_lens=''; delta_prev=''
b_Nova=0; b_Violet=0; b_AntiVenom=0; b_Venom=0; b_Carnage=0
b_Chroma=0; b_Soleil=0; b_Eidolon=0; b_Claude=0

# --- the text-vs-stream pair: the ROUTER judges the task's register ----------
TASK_LANE=''
if [ -n "$TASK" ] && [ -r "$SELF_DIR/rot-router.sh" ]; then
  _r=$(ROTMOE_DEBUG_SRC=test ROTMOE_DEBUG_LOCAL=0 sh "$SELF_DIR/rot-router.sh" --route "$TASK" 2>/dev/null)
  TASK_LANE=${_r%% *}
  case "$TASK_LANE" in EMPATHIC|PREDICTIVE) ;; *) TASK_LANE='' ;; esac
fi

# --- field extraction: parameter expansion, one shell, no interpreter --------
f_str () { # $1=line $2=key -> string value, or empty
  case "$1" in
    *"\"$2\":\""*) _x=${1#*\"$2\":\"}; printf '%s' "${_x%%\"*}" ;;
    *) printf '' ;;
  esac
}
f_num () { # $1=line $2=key -> bare number, or empty
  case "$1" in
    *"\"$2\":"*) _x=${1#*\"$2\":}; _x=${_x%%,*}; _x=${_x%%\}*}; printf '%s' "$_x" ;;
    *) printf '' ;;
  esac
}

# --- the queue: rename-atomic, never touches an existing file ----------------
queue_remark () { # $1=Lens $2=text
  eval "_b=\${b_$1}"
  if [ "$_b" -ge 3 ]; then
    watchsay "$1 over budget (3/run) -- remark withheld"
    return 0
  fi
  eval "b_$1=\$((_b+1))"
  printf '%s|%s\n' "$1" "$2" >> "$PEND"
  say "REMARK $1 | $2"
  distill "- $(date -Is 2>/dev/null || date) | $SESS | $1 | $2"
  delta_arm=3; delta_lens=$1; delta_prev=$recent3
}
flush_pending () {
  [ -s "$PEND" ] || return 0
  [ -f "$Q" ] && return 0
  cp "$PEND" "$Q.an.$$" 2>/dev/null || return 0
  if ln "$Q.an.$$" "$Q" 2>/dev/null; then
    rm -f "$Q.an.$$"
    : > "$PEND"
  else
    rm -f "$Q.an.$$"
  fi
}

# --- one record --------------------------------------------------------------
handle_record () {
  line=$1
  case "$line" in
    *'"kind":"anomaly"'*)
      shape=$(f_str "$line" shape); tool=$(f_str "$line" tool)
      case "$shape" in
        blank)       n_blank=$((n_blank+1));             _n=$n_blank ;;
        interrupted) n_interrupted=$((n_interrupted+1)); _n=$n_interrupted ;;
        zerobyte)    n_zerobyte=$((n_zerobyte+1));       _n=$n_zerobyte ;;
        *) return 0 ;;
      esac
      watchsay "anomaly $shape on $tool ($_n of $AN_N)"
      if [ "$_n" -ge "$AN_N" ]; then
        queue_remark AntiVenom "the $shape result has recurred ${_n}x (last on $tool) -- the same absence twice is a pattern, not a coincidence; stop and read what is already there before acting again."
        case "$shape" in
          blank) n_blank=0 ;; interrupted) n_interrupted=0 ;; zerobyte) n_zerobyte=0 ;;
        esac
      fi
      return 0 ;;
    *'"kind":"route"'*) ;;
    *) return 0 ;;
  esac

  ev=$(f_str "$line" event); lane=$(f_str "$line" lane); stem=$(f_str "$line" stem)
  ms=$(f_num "$line" ms); chars=$(f_num "$line" chars)
  [ -n "$ev" ] || return 0
  watchsay "route ev=$ev lane=$lane stem=$stem ms=$ms chars=$chars"

  # the rolling 3-event window the delta measurement quotes
  recent3="$recent3 $ev:$lane"
  set -- $recent3; [ $# -gt 3 ] && shift $(($# - 3)); recent3="$*"
  if [ "$delta_arm" -gt 0 ]; then
    delta_arm=$((delta_arm-1))
    if [ "$delta_arm" -eq 0 ]; then
      distill "  delta(3) after $delta_lens: [$delta_prev] -> [$recent3]"
      delta_arm=-1
    fi
  fi

  # text-vs-stream (Violet EMPATHIC / Chroma PREDICTIVE), once per run
  if [ -n "$TASK_LANE" ] && [ "$text_fired" -eq 0 ]; then
    text_seen=$((text_seen+1))
    [ "$lane" = "$TASK_LANE" ] && text_hit=1
    if [ "$text_seen" -ge "$TEXT_N" ] && [ "$text_hit" -eq 0 ]; then
      text_fired=1
      if [ "$TASK_LANE" = EMPATHIC ]; then
        queue_remark Violet "the task itself routes EMPATHIC and $TEXT_N events have not visited that register -- hear what is not being said before the next edit."
      else
        queue_remark Chroma "the task asks for consequences and $TEXT_N events have routed elsewhere -- PREDICTIVE has never led; price the downstream before shipping."
      fi
    fi
  fi

  case "$ev" in
    UserPromptSubmit)
      dither_run=$((dither_run+1))
      if [ "$dither_run" -ge "$DITHER_N" ]; then
        queue_remark Venom "$DITHER_N prompt turns and not one act between them -- analysis is complete somewhere behind you; decide and move."
        dither_run=0
      fi ;;
    PreToolUse)
      dither_run=0
      stall_pending=1; stall_epoch=$(date +%s 2>/dev/null || echo 0)
      # Eidolon: one lane+stem pair looping. Pre only, one count per action.
      if [ -n "$stem" ] && [ "$stem" != '-' ]; then
        printf '%s|%s\n' "$lane" "$stem" >> "$PAIRS"
        # grep -c prints its count even when that count is 0 (and exits 1),
        # so an `|| echo 0` here would emit a SECOND zero into the capture.
        _pn=$(grep -Fxc "$lane|$stem" "$PAIRS" 2>/dev/null)
        case "$_pn" in *[!0-9]*|'') _pn=0 ;; esac
        if [ "$_pn" -ge "$LOOP_N" ]; then
          queue_remark Eidolon "the pair $lane+$stem has now recurred ${_pn}x -- the pattern is the finding; name it instead of repeating it."
          grep -Fxv "$lane|$stem" "$PAIRS" > "$PAIRS.t" 2>/dev/null; mv "$PAIRS.t" "$PAIRS" 2>/dev/null || :
        fi
      fi
      # Soleil: the action text growing every time (the chars field is the
      # measured length of tool name + command/path/pattern, the router's own
      # 2026-08-03 fix -- input-side volume, and the remark says so).
      case "$chars" in *[!0-9]*|'') prev_chars=''; bloat_run=1 ;;
        *)
          if [ -n "$prev_chars" ] && [ "$chars" -gt "$prev_chars" ]; then
            [ "$bloat_run" -eq 1 ] && bloat_start=$prev_chars
            bloat_run=$((bloat_run+1))
            if [ "$bloat_run" -ge "$BLOAT_N" ]; then
              queue_remark Soleil "$BLOAT_N actions, each longer than the last ($bloat_start -> $chars chars) -- you are writing more and landing less; compress the approach, not the prose."
              bloat_run=1
            fi
          else bloat_run=1; fi
          prev_chars=$chars ;;
      esac ;;
    PostToolUse)
      dither_run=0
      stall_pending=0
      # Chroma: consecutive actions each costlier than the last (ms is the
      # hook's measured wall for the event; -1 means no clock and resets).
      case "$ms" in *[!0-9]*|'') prev_ms=''; cost_run=1 ;;
        *)
          if [ -n "$prev_ms" ] && [ "$ms" -gt "$prev_ms" ]; then
            [ "$cost_run" -eq 1 ] && cost_start=$prev_ms
            cost_run=$((cost_run+1))
            if [ "$cost_run" -ge "$COST_N" ]; then
              queue_remark Chroma "$COST_N consecutive actions, each costlier than the last (${cost_start}ms -> ${ms}ms) -- the branch you are on prices badly; reconsider before paying a fourth time."
              cost_run=1
            fi
          else cost_run=1; fi
          prev_ms=$ms ;;
      esac ;;
  esac
}

# --- the loop: 1 s poll (frozen; the sink is synchronous, 134 ms measured) ---
say "observing session $SESS"
say "sink  $SINK"
say "queue $Q"
[ -n "$TASK_LANE" ] && say "task routes $TASK_LANE -- the text-vs-stream watch is armed"
distill "## animus run $(date -Is 2>/dev/null || date) | session $SESS${TASK:+ | task: $(printf '%.100s' "$TASK")}"

LAST=0
while :; do
  if [ -r "$SINK" ]; then
    n=$(wc -l < "$SINK" 2>/dev/null | tr -dc '0-9'); [ -z "$n" ] && n=0
    # The router CAPS the sink (5000 lines, 80% low-water): a shrink is the
    # trim keeping the newest, not new traffic. Skip forward, never re-read.
    [ "$n" -lt "$LAST" ] && LAST=$n
    if [ "$n" -gt "$LAST" ]; then
      tail -n +$((LAST+1)) "$SINK" > "$WORK/new" 2>/dev/null
      LAST=$n
      while IFS= read -r _line; do handle_record "$_line"; done < "$WORK/new"
    fi
  fi
  # Claude: the stall caught on the run -- a PreToolUse whose Post never
  # lands. Observer wall clock, not record timestamps (no date parsing).
  if [ "$stall_pending" -eq 1 ]; then
    _now=$(date +%s 2>/dev/null || echo 0)
    _age=$((_now - stall_epoch))
    if [ "$_age" -ge "$STALL_S" ]; then
      queue_remark Claude "the action opened ${_age}s ago and no result has landed -- a measurement that never returns is not a measurement; read its state now instead of waiting on it."
      stall_pending=0
    fi
  fi
  flush_pending
  [ "$ONCE" -eq 1 ] && break
  sleep 1
done

rm -rf "$WORK" 2>/dev/null
exit 0
