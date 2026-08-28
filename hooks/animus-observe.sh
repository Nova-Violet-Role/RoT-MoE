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
# These are BASE counts, and a base is not a verdict. Each one is divided by
# the electing lens's measured share of the gauge before it is tested (eff_n,
# below), so the lens the router is carrying right now speaks sooner and the
# lens it has parked must bring more evidence. The declared defaults are the
# parity case exactly: nine lenses at 1/9 of the weight each leave every base
# standing where it is written. No new knob is introduced -- the measurement
# was always in the sink, and this observer was reading past it.
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

# --- the measured state: the gauge, per run and per turn ---------------------
# s_<Lens>  the lens's share of the elected weight on the LAST gauge record
# c_<Lens>  that share, accumulated over the run   (mean = c / g_seen)
# tc_<Lens> the same, accumulated over the TURN    (mean = tc / t_gauge)
# ta_<Lens> times the gauge actually elected the lens this turn
# All of it is integer permille: POSIX sh has no floats, and nine floating
# point shell-outs per event would cost more than the observation is worth.
g_seen=0; g_rs=0; g_active=''; g_mono=0
t_gauge=0; t_rs_sum=0; t_rs_min=1000; t_rs_max=0; t_breadth=0
t_events=0; t_pre=0; t_post=0; t_chars=0; t_ms=0; t_below=0; t_fuse=0
t_prompt_lane=''; t_lanes=''
prev_turn_chars=0; prev_turn_top=''; prev_turn_lane=''; turns=0
LENSES='Nova Violet AntiVenom Venom Carnage Chroma Soleil Eidolon Claude'
for _L in $LENSES; do eval "s_$_L=0; c_$_L=0; tc_$_L=0; ta_$_L=0"; done

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

# --- the gauge: the router's own measurement, out of this observer's own input
# Beside every route record the router writes a `"kind":"gauge"` record: K, the
# mean share, the breadth, M/C/T, the sum, R/s+, the elected lens, and all nine
# lenses each carrying lambda, mu, a, delta, sigma, H and term. That is the
# entire measurement the voice prints -- and it has been sitting in this
# observer's sink from the first version. Everything below READS it. Nothing
# below recomputes it: a second implementation of the gauge is a second gauge,
# and two gauges that disagree are worse than one that is merely quoted.
#
# The assign-style helpers (v_str/v_num) exist because f_str/f_num are used
# through command substitution, and a gauge record needs eleven extractions --
# eleven forks per event, at 1 Hz, on a platform where a fork is milliseconds.
# These set a variable instead. Same parsing, no subshell.
v_str () { # $1=line $2=key -> _VS
  _VS=''
  case "$1" in *"\"$2\":\""*) _x=${1#*\"$2\":\"}; _VS=${_x%%\"*} ;; esac
}
v_num () { # $1=line $2=key -> _VN
  _VN=''
  case "$1" in *"\"$2\":"*) _x=${1#*\"$2\":}; _x=${_x%%,*}; _VN=${_x%%\}*} ;; esac
}

# "4.95429" -> 4954. Truncating, not rounding: a milli-unit of a share is
# already finer than any decision made from it. Junk -> 0, never an error.
fp2milli () { # $1=number text -> _MILLI
  _MILLI=0
  case "$1" in ''|*[!0-9.]*) return 0 ;; esac
  _w=${1%%.*}
  case "$1" in *.*) _d=${1#*.} ;; *) _d='' ;; esac
  case "$_w" in '') _w=0 ;; *[!0-9]*) return 0 ;; esac
  _d="${_d}000"; _d=${_d%"${_d#???}"}
  case "$_d" in *[!0-9]*) _d=000 ;; esac
  while [ "${#_d}" -gt 1 ] && [ "${_d#0}" != "$_d" ]; do _d=${_d#0}; done
  _MILLI=$(( _w * 1000 + _d ))
}

# One lens's term out of a gauge line. The line is sliced at that lens's own
# object first, so no neighbour's number can be read by mistake.
g_term_of () { # $1=line $2=Lens -> _MILLI
  _MILLI=0
  case "$1" in
    *"\"lens\":\"$2\""*) _g=${1#*\"lens\":\"$2\"} ;;
    *) return 0 ;;
  esac
  _g=${_g#*\"term\":}; _g=${_g%%,*}; _g=${_g%%\}*}
  fp2milli "$_g"
}

# permille -> "12.3%" text, without a fork.
pct () { _PCT="$(( $1 / 10 )).$(( $1 % 10 ))%"; }
# permille -> "0.720" text, zero padded, without a fork.
milli3 () {
  if [ "$1" -ge 1000 ]; then _M3="1.000"; return 0; fi
  _z=$1
  case $_z in ?) _z="00$_z" ;; ??) _z="0$_z" ;; esac
  _M3="0.$_z"
}

# One gauge record: the run's weights, and the turn's.
handle_gauge () {
  v_num "$1" sum; fp2milli "$_VN"; _sum=$_MILLI
  [ "$_sum" -gt 0 ] || return 0
  g_seen=$((g_seen+1)); t_gauge=$((t_gauge+1))
  v_num "$1" Rs; fp2milli "$_VN"; g_rs=$_MILLI
  t_rs_sum=$((t_rs_sum + g_rs))
  [ "$g_rs" -lt "$t_rs_min" ] && t_rs_min=$g_rs
  [ "$g_rs" -gt "$t_rs_max" ] && t_rs_max=$g_rs
  v_num "$1" breadth
  case "$_VN" in ''|*[!0-9]*) _br=0 ;; *) _br=$_VN ;; esac
  t_breadth=$((t_breadth + _br))
  v_str "$1" active; _act=$_VS
  if [ -n "$_act" ] && [ "$_act" = "$g_active" ]; then
    g_mono=$((g_mono+1))
  else
    g_mono=1
  fi
  g_active=$_act
  # `active` is a SET, not a name: under NSIL FUSE the router writes
  # "Nova,AntiVenom,Soleil,Claude", and when nothing is elected it writes
  # "none". Crediting only the single-name case would have every fused lens
  # counted as never elected -- and the starved-lens finding below would then
  # accuse a lens that was leading, in that lens's own voice. Split it.
  case "$_act" in
    ''|none) ;;
    *)
      _rest=$_act
      while [ -n "$_rest" ]; do
        case "$_rest" in
          *,*) _one=${_rest%%,*}; _rest=${_rest#*,} ;;
          *)   _one=$_rest; _rest='' ;;
        esac
        case " $LENSES " in
          *" $_one "*) eval "ta_$_one=\$(( \${ta_$_one:-0} + 1 ))" ;;
        esac
      done ;;
  esac
  for _L in $LENSES; do
    g_term_of "$1" "$_L"
    _sh=$(( _MILLI * 1000 / _sum ))
    eval "s_$_L=\$_sh; c_$_L=\$(( \${c_$_L:-0} + _sh )); tc_$_L=\$(( \${tc_$_L:-0} + _sh ))"
  done
  milli3 "$g_rs"
  watchsay "gauge #$g_seen R/s+ $_M3 elected ${g_active:-none} (${g_mono}x)"
}

# A threshold, weighted by the lens that would speak it. Parity is 1/9 = 111
# permille, which returns the base unchanged; a lens carrying the turn divides
# it down, a lens the gauge has parked multiplies it up, capped at 3x so that
# no weighting can silence a lens outright. This one function is the whole
# difference between a router and a stack of if-statements.
eff_n () { # $1=base $2=Lens -> _EFF
  _EFF=$1
  [ "$g_seen" -gt 0 ] || return 0
  eval "_es=\${s_$2:-0}"
  [ "$_es" -lt 1 ] && _es=1
  _EFF=$(( ($1 * 111 + _es / 2) / _es ))
  [ "$_EFF" -lt 1 ] && _EFF=1
  _cap=$(( $1 * 3 ))
  [ "$_EFF" -gt "$_cap" ] && _EFF=$_cap
  return 0
}

# The budget is the lens's own accumulated weight, not a constant 3. A lens the
# gauge has been carrying earns more; a starved lens still earns one, because
# the point of nine lenses is that the quiet one is sometimes the one that is
# right. It is spent per TURN -- see the Stop arm, which resets it.
lens_budget () { # $1=Lens -> _BUDGET
  _BUDGET=3
  [ "$g_seen" -gt 0 ] || return 0
  eval "_cb=\${c_$1:-0}"
  _BUDGET=$(( ((_cb / g_seen) * 27 + 500) / 1000 ))
  [ "$_BUDGET" -lt 1 ] && _BUDGET=1
  [ "$_BUDGET" -gt 6 ] && _BUDGET=6
  return 0
}

# Every remark carries the measurement that summoned it. A reader who does not
# believe the remark can check the number; a remark whose number cannot be
# checked is decoration. No pipe character may enter this tag -- the queue is
# pipe-separated and the worker-side ear scrubs separators.
gauge_tag () { # $1=Lens -> _TAG
  _TAG=''
  [ "$g_seen" -gt 0 ] || return 0
  eval "_gs=\${s_$1:-0}"
  pct "$_gs"; _gp=$_PCT
  milli3 "$g_rs"
  _TAG=" [gauge: $1 at $_gp of the weight, R/s+ $_M3, elected ${g_active:-none}]"
}
# --- the queue: rename-atomic, never touches an existing file ----------------
queue_remark () { # $1=Lens $2=text
  eval "_b=\${b_$1}"
  lens_budget "$1"
  if [ "$_b" -ge "$_BUDGET" ]; then
    watchsay "$1 over budget ($_BUDGET this turn, by its measured share) -- withheld"
    return 0
  fi
  eval "b_$1=\$((_b+1))"
  gauge_tag "$1"
  set -- "$1" "$2$_TAG"
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

# --- the turn's verdict: the gauge read backwards, at Stop -------------------
# Every voice in this system speaks BEFORE the act. The router reads a prompt
# and elects a lens for work that has not happened yet; the animus reads an
# event and speaks into the next one. Stop is the only event that can see what
# the turn actually did, and it was the one event nobody read -- 52 of them in
# this session alone, each one computing a gauge and throwing it away.
#
# Nothing below is a new measurement. Every finding is a comparison between
# what the gauge ELECTED across the turn and what the turn's own records SHOW,
# and every finding is scored by the weight the gauge gave the lens that would
# speak it -- so the speaker is chosen by the measurement, not by the order of
# the if-statements. Two speak; the rest are written to the distillate, where
# they cost nothing and can still be read tomorrow.
vcand () { # $1=Lens $2=text -- a candidate, scored by its own lens's weight
  eval "_vc=\$(( \${tc_$1:-0} / t_gauge ))"
  printf '%s|%s|%s\n' "$1" "$_vc" "$2" >> "$VC"
}

turn_verdict () {
  [ "$t_gauge" -gt 0 ] || return 0
  [ "$t_events" -gt 0 ] || return 0
  VC="$WORK/verdict"; : > "$VC"

  _mrs=$(( t_rs_sum / t_gauge ))
  _mbr=$(( t_breadth * 100 / t_gauge ))
  _mbr_f=$(( _mbr % 100 )); case $_mbr_f in ?) _mbr_f="0$_mbr_f" ;; esac
  _mbrtxt="$(( _mbr / 100 )).$_mbr_f"
  milli3 "$_mrs"; _mrstxt=$_M3

  # who the gauge CARRIED (share) and who it ELECTED (the active lens)
  _top=''; _topsh=0; _lead=''; _leadn=0
  for _L in $LENSES; do
    eval "_ms=\$(( \${tc_$_L:-0} / t_gauge )); _mn=\${ta_$_L:-0}"
    if [ "$_ms" -gt "$_topsh" ]; then _topsh=$_ms; _top=$_L; fi
    if [ "$_mn" -gt "$_leadn" ]; then _leadn=$_mn; _lead=$_L; fi
  done

  # the turn's dominant lane, counted out of its own ledger
  _dom=''; _domn=0
  for _x in $t_lanes; do
    _cnt=0
    for _y in $t_lanes; do [ "$_y" = "$_x" ] && _cnt=$((_cnt+1)); done
    if [ "$_cnt" -gt "$_domn" ]; then _domn=$_cnt; _dom=$_x; fi
  done

  # -- 1. the register the human wrote in, never visited (Violet / Chroma) ----
  # This is the watch that has never once armed in production: it needed a
  # --task flag that launch-animus does not pass. The prompt event carries the
  # same text, already routed by the same router, on every turn.
  if [ -n "$t_prompt_lane" ] && [ "$t_events" -ge 4 ]; then
    case " $t_lanes " in
      *" $t_prompt_lane "*) ;;
      *)
        case "$t_prompt_lane" in
          EMPATHIC)
            vcand Violet "the turn opened in EMPATHIC -- the register the person actually wrote in -- and closed $t_events events later without one of them landing there. The work happened beside the human who asked for it, not with them." ;;
          PREDICTIVE)
            vcand Chroma "the prompt routed PREDICTIVE and none of this turn's $t_events events did. Every step was priced, no consequence was." ;;
        esac ;;
    esac
  fi

  # -- 2. the starved lens: weighted all turn, elected never ------------------
  # The finding a threshold machine structurally cannot make: it needs the
  # weights, and until now nothing downstream of the gauge ever read them.
  if [ "$t_gauge" -ge 4 ]; then
    for _L in $LENSES; do
      eval "_ms=\$(( \${tc_$_L:-0} / t_gauge )); _mn=\${ta_$_L:-0}"
      if [ "$_ms" -ge 111 ] && [ "$_mn" -eq 0 ]; then
        pct "$_ms"
        vcand "$_L" "the gauge held me at $_PCT of the weight across $t_gauge measurements this turn and elected me on none of them. The turn was decided without the view it was paying for."
      fi
    done
  fi

  # -- 3. one instrument, all turn (Carnage) ---------------------------------
  if [ "$t_gauge" -ge 5 ] && [ -n "$_lead" ] && [ $(( _leadn * 100 / t_gauge )) -ge 80 ]; then
    vcand Carnage "$_lead was in the elected set on $_leadn of $t_gauge measurements and mean breadth held at $_mbrtxt lanes. One instrument, one reading, all turn -- nothing was made to collide with anything."
  fi

  # -- 4. the band said diverge, N times (AntiVenom) -------------------------
  if [ "$t_below" -ge 5 ]; then
    vcand AntiVenom "the router's own band flag read BELOW RANGE on $t_below of this turn's $t_events events, mean R/s+ $_mrstxt. The gauge asked for divergence that many times and got the same lane back every time."
  fi

  # -- 5. regime change nobody named (Chroma) --------------------------------
  if [ "$t_gauge" -ge 5 ] && [ $(( t_rs_max - t_rs_min )) -ge 400 ]; then
    milli3 "$t_rs_min"; _lo=$_M3; milli3 "$t_rs_max"; _hi=$_M3
    vcand Chroma "R/s+ ran from $_lo to $_hi inside one turn. The turn changed regime and no one marked the moment -- that swing is where the next turn's cost was set."
  fi

  # -- 6. the session orbiting itself (Eidolon) ------------------------------
  if [ "$turns" -ge 2 ] && [ -n "$_dom" ] && [ "$_dom" = "$prev_turn_lane" ] && [ -n "$_top" ] && [ "$_top" = "$prev_turn_top" ]; then
    vcand Eidolon "two turns running, the same shape: $_dom led both and the gauge carried $_top through both. A session repeating its own shape is not converging, it is orbiting. Name the invariant and the next turn can be about something else."
  fi

  # -- 7. the approach outgrowing the result (Soleil) ------------------------
  if [ "$prev_turn_chars" -gt 0 ] && [ "$t_events" -ge 4 ] && [ "$t_chars" -gt $(( prev_turn_chars * 3 / 2 )) ]; then
    vcand Soleil "$t_chars characters of action this turn against $prev_turn_chars last turn, for $t_events events. The approach is growing faster than the result."
  fi

  # -- 8. opened but never landed (Claude) -----------------------------------
  if [ $(( t_pre - t_post )) -ge 2 ]; then
    vcand Claude "$t_pre actions opened this turn and $t_post results landed. $(( t_pre - t_post )) measurements never came back, and every one of them is something this turn believes without having read."
  fi

  # -- 9. deliberation with nothing shipped (Venom) --------------------------
  if [ "$t_post" -eq 0 ] && [ "$t_events" -ge 5 ]; then
    vcand Venom "$t_events events this turn and not one result. The turn deliberated and shipped nothing. Decide."
  fi

  # -- 10. lanes present, never fused (Nova) ---------------------------------
  if [ "$t_gauge" -ge 5 ] && [ "$t_fuse" -eq 0 ] && [ "$_mbr" -ge 200 ]; then
    vcand Nova "mean breadth $_mbrtxt lanes across $t_gauge measurements and NSIL never left CONFIRM. The lanes were present the whole turn and were never once fused."
  fi

  # -- the gauge picks the speaker: highest measured share first, two at most -
  if [ -s "$VC" ]; then
    sort -t'|' -k2,2nr "$VC" > "$VC.s" 2>/dev/null || cp "$VC" "$VC.s"
    _spoke=0
    while IFS='|' read -r _vl _vs _vt; do
      [ -n "$_vl" ] || continue
      distill "  verdict | $_vl | share ${_vs} permille | $_vt"
      if [ "$_spoke" -lt 2 ]; then
        queue_remark "$_vl" "$_vt"
        _spoke=$((_spoke+1))
      fi
    done < "$VC.s"
    rm -f "$VC.s" 2>/dev/null
  fi

  distill "  turn $turns closed | $t_events events | $t_gauge measurements | mean R/s+ $_mrstxt | breadth $_mbrtxt | carried $_top | led ${_lead:-none} | lane ${_dom:-none}"
  prev_turn_top=$_top
  prev_turn_lane=$_dom
  return 0
}

# The turn is the unit. A budget spent per RUN is a budget spent in the first
# twenty minutes of a seven-hour session, and eight of the nine lenses are then
# silent for the six hours where the work actually is.
turn_reset () {
  [ "$t_events" -gt 0 ] && prev_turn_chars=$t_chars
  t_gauge=0; t_rs_sum=0; t_rs_min=1000; t_rs_max=0; t_breadth=0
  t_events=0; t_pre=0; t_post=0; t_chars=0; t_ms=0; t_below=0; t_fuse=0
  t_prompt_lane=''; t_lanes=''
  text_seen=0; text_hit=0; text_fired=0
  for _L in $LENSES; do eval "tc_$_L=0; ta_$_L=0"; done
  for _L in $LENSES; do eval "b_$_L=0"; done
  return 0
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
      # the same absence twice is a pattern -- but how soon 'twice' counts is
      # the gauge's call, floored at 2 so the remark's own words stay true.
      eff_n "$AN_N" AntiVenom; [ "$_EFF" -lt 2 ] && _EFF=2
      watchsay "anomaly $shape on $tool ($_n of $_EFF, base $AN_N)"
      if [ "$_n" -ge "$_EFF" ]; then
        queue_remark AntiVenom "the $shape result has recurred ${_n}x (last on $tool) -- the same absence twice is a pattern, not a coincidence; stop and read what is already there before acting again."
        case "$shape" in
          blank) n_blank=0 ;; interrupted) n_interrupted=0 ;; zerobyte) n_zerobyte=0 ;;
        esac
      fi
      return 0 ;;
    *'"kind":"gauge"'*) handle_gauge "$line"; return 0 ;;
    *'"kind":"route"'*) ;;
    *) return 0 ;;
  esac

  ev=$(f_str "$line" event); lane=$(f_str "$line" lane); stem=$(f_str "$line" stem)
  ms=$(f_num "$line" ms); chars=$(f_num "$line" chars)
  [ -n "$ev" ] || return 0
  watchsay "route ev=$ev lane=$lane stem=$stem ms=$ms chars=$chars"

  # --- the turn's ledger: what the turn actually did, for the Stop verdict --
  if [ "$ev" != Stop ]; then
    t_events=$((t_events+1))
    case "$ev" in
      PreToolUse)  t_pre=$((t_pre+1)) ;;
      PostToolUse) t_post=$((t_post+1)) ;;
    esac
    case "$chars" in ''|*[!0-9]*) ;; *) t_chars=$((t_chars + chars)) ;; esac
    case "$ms" in ''|*[!0-9]*) ;; *) t_ms=$((t_ms + ms)) ;; esac
    v_str "$line" band; [ "$_VS" = BELOW ] && t_below=$((t_below+1))
    v_str "$line" nsil
    case "$_VS" in ''|CONFIRM) ;; *) t_fuse=$((t_fuse+1)) ;; esac
    if [ "$ev" = UserPromptSubmit ]; then
      # VIOLET'S WAY IN. The text-vs-stream watch needed --task, and
      # launch-animus has never passed it: the flag exists, the caller does
      # not use it, so the EMPATHIC watch has never armed in production and
      # the most human of the nine has been structurally mute. The prompt
      # event IS the task, already routed by the same router that would have
      # been shelled out to. Take it from there, every turn, for free.
      t_prompt_lane=$lane
      case "$lane" in
        EMPATHIC|PREDICTIVE) TASK_LANE=$lane; text_seen=0; text_hit=0; text_fired=0 ;;
      esac
    else
      [ -n "$lane" ] && t_lanes="$t_lanes $lane"
    fi
  fi

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
    if [ "$TASK_LANE" = EMPATHIC ]; then eff_n "$TEXT_N" Violet; else eff_n "$TEXT_N" Chroma; fi
    [ "$_EFF" -lt 3 ] && _EFF=3
    if [ "$text_seen" -ge "$_EFF" ] && [ "$text_hit" -eq 0 ]; then
      text_fired=1
      if [ "$TASK_LANE" = EMPATHIC ]; then
        queue_remark Violet "the task itself routes EMPATHIC and $text_seen events have not visited that register -- hear what is not being said before the next edit."
      else
        queue_remark Chroma "the task asks for consequences and $text_seen events have routed elsewhere -- PREDICTIVE has never led; price the downstream before shipping."
      fi
    fi
  fi

  case "$ev" in
    Stop)
      # the only event that can see the turn it is closing
      turns=$((turns+1))
      turn_verdict
      turn_reset ;;
    UserPromptSubmit)
      dither_run=$((dither_run+1))
      eff_n "$DITHER_N" Venom; [ "$_EFF" -lt 2 ] && _EFF=2
      if [ "$dither_run" -ge "$_EFF" ]; then
        queue_remark Venom "$dither_run prompt turns and not one act between them -- analysis is complete somewhere behind you; decide and move."
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
        eff_n "$LOOP_N" Eidolon; [ "$_EFF" -lt 2 ] && _EFF=2
        if [ "$_pn" -ge "$_EFF" ]; then
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
            eff_n "$BLOAT_N" Soleil; [ "$_EFF" -lt 2 ] && _EFF=2
            if [ "$bloat_run" -ge "$_EFF" ]; then
              queue_remark Soleil "$bloat_run actions, each longer than the last ($bloat_start -> $chars chars) -- you are writing more and landing less; compress the approach, not the prose."
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
            eff_n "$COST_N" Chroma; [ "$_EFF" -lt 2 ] && _EFF=2
            if [ "$cost_run" -ge "$_EFF" ]; then
              queue_remark Chroma "$cost_run consecutive actions, each costlier than the last (${cost_start}ms -> ${ms}ms) -- the branch you are on prices badly; reconsider before paying again."
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
say "gauge  read from the sink, not recomputed; thresholds scale by measured share"
say "turn   budgets and the retrospective verdict close on every Stop record"
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
    # A weighted Claude waits less, but never less than 45s: below that the
    # remark fires on commands that are merely slow, and a false stall is a
    # lie told in the lens's own voice.
    eff_n "$STALL_S" Claude; [ "$_EFF" -lt 45 ] && _EFF=45
    if [ "$_age" -ge "$_EFF" ]; then
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
