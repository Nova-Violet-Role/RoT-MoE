#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-voice-gate.sh -- the voice gate, POSIX arm. ORGAN 6.
#
# A hook cannot think, but it can refuse to close. On a turn where NSIL
# summoned several lenses (FUSE or ELEVATE), the router records the summons;
# this gate, on Stop, checks that every summoned lens actually spoke in its
# declared element and, if one is missing, blocks the stop ONCE with the
# missing lens's charter as the task. The shape is RoT DTD GOAL's stop gate
# (their LAW.17: a refusal always carries a task; their LAW.18: running out
# of room is a visible verdict, never a silent pass) applied to the roster.
#
# THE GATE DEGRADES OPEN, EVERYWHERE, and that is a design decision worth
# stating: a gate that blocks when it could not MEASURE would be holding the
# Socio's session hostage to a missing file. No summons -> allow. Unreadable
# transcript -> allow, clear the summons. No node -> allow. stop_hook_active
# already true -> allow, clear (never block twice; one refusal per turn is a
# reminder, two is a cage). The single-shot rule is enforced twice: the
# summons file is consumed on the first block, and the harness's own
# stop_hook_active flag is honoured besides.
#
# Timeout discipline (Socio directive): this entry carries the SAME 18000
# every other hook carries -- one product, one bound, and hook-timeout.sh
# fails the tree on a second value. The gate's own work is milliseconds.
# =============================================================================

LC_ALL=C
export LC_ALL

# Never hang a human at a terminal: hook mode expects a payload on stdin.
if [ -t 0 ]; then
  echo "rot-voice-gate.sh: hook mode expects a JSON payload on stdin." >&2
  exit 2
fi
payload=$(cat)
[ -z "$payload" ] && exit 0

# --- who is stopping ---------------------------------------------------------
_sess=unknown
case "$payload" in
  *'"session_id"'*)
    _sess=${payload#*\"session_id\"}
    _sess=${_sess#*\"}
    _sess=${_sess%%\"*}
    ;;
esac
_sess=$(printf '%s' "$_sess" | tr -cd 'A-Za-z0-9-' | cut -c1-64)
[ -n "$_sess" ] || _sess=unknown

# ORGAN 7 -- the environment layer, same three laws as the router: parsed
# never sourced, declared-only, unset-only. The gate honours a project's
# rot.env (ROTMOE_GATE=0, ROTMOE_STATE_DIR) exactly as the router that wrote
# the summons did, or the two would resolve different state directories.
_cwd=''
case "$payload" in
  *'"cwd"'*)
    _cwd=${payload#*\"cwd\"}
    _cwd=${_cwd#*\"}
    _cwd=${_cwd%%\"*}
    ;;
esac
_cwd=$(printf '%s' "$_cwd" | tr '\\' '/')
if [ -r "${0%/*}/rot-env.sh" ]; then
  . "${0%/*}/rot-env.sh" 2>/dev/null && rot_env_load "$_cwd" || :
fi
[ "${ROTMOE_GATE:-1}" = 0 ] && exit 0

# --- the summons -------------------------------------------------------------
STATE_DIR="${ROTMOE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/rot-moe}"
SUM="$STATE_DIR/voice-summons.$_sess"
[ -r "$SUM" ] || exit 0

# The harness marks a stop that already survived one block. Honour it: clear
# the summons and stand aside. One refusal per turn carries the task; a
# second would be the gate arguing with the model instead of informing it.
case "$payload" in
  *'"stop_hook_active":true'*|*'"stop_hook_active": true'*)
    rm -f "$SUM" 2>/dev/null || :
    exit 0
    ;;
esac

# --- what was actually said --------------------------------------------------
_tp=''
case "$payload" in
  *'"transcript_path"'*)
    _tp=${payload#*\"transcript_path\"}
    _tp=${_tp#*\"}
    _tp=${_tp%%\"*}
    ;;
esac
if [ -z "$_tp" ] || [ ! -r "$_tp" ] || ! command -v node >/dev/null 2>&1; then
  # Cannot measure -> cannot block. The summons is cleared so a transient
  # unreadability does not arm a stale gate against some later turn.
  rm -f "$SUM" 2>/dev/null || :
  exit 0
fi

# The last assistant text in the transcript, via an exact parse. Tolerant
# line by line: a torn record is skipped, never fatal.
_last=$(node -e '
  const fs=require("fs");
  let out="";
  const lines=fs.readFileSync(process.argv[1],"utf8").split("\n");
  for (const l of lines) {
    if (!l.trim()) continue;
    try {
      const j=JSON.parse(l);
      const m=j.message||j;
      const role=m.role||j.type;
      if (role==="assistant") {
        const c=m.content;
        if (typeof c==="string") out=c;
        else if (Array.isArray(c))
          out=c.filter(x=>x&&x.type==="text").map(x=>x.text).join("\n");
      }
    } catch(e) {}
  }
  process.stdout.write(out);
' "$_tp" 2>/dev/null)

# --- the verdict -------------------------------------------------------------
# Summons rows are written by the router as: Name|element|charter|bound.
# Every field originates in hooks/rot-voice.dtd, which this repository
# authors -- but the JSON reason must stay valid even if someone edits the
# DTD carelessly, so quotes and backslashes are STRIPPED from each field
# rather than escaped: a mangled charter is a cosmetic loss, a broken JSON
# block is a dead gate. `\n` below are intentional two-character sequences
# that the JSON parser, not the shell, turns into newlines.
_missing=''
while IFS='|' read -r _n _e _c _b; do
  [ -n "$_e" ] || continue
  case "$_last" in
    *"<$_e>"*) : ;;
    *)
      _n=$(printf '%s' "$_n" | tr -d '"\\')
      _e=$(printf '%s' "$_e" | tr -d '"\\')
      _c=$(printf '%s' "$_c" | tr -d '"\\')
      _b=$(printf '%s' "$_b" | tr -d '"\\')
      _missing="$_missing\\n  <$_e> ($_n): $_c -- $_b"
      ;;
  esac
done < "$SUM"

# Consumed either way: the gate speaks at most once per summons.
rm -f "$SUM" 2>/dev/null || :

[ -z "$_missing" ] && exit 0

# The parenthetical provenance was added 2026-08-17 after the v6.0.0 real
# test (B4): an unbriefed convening model treated this refusal as untrusted
# injected framing and declined the stanzas -- correctly, by its own lights,
# because nothing in the reason said the OPERATOR installed this gate. Now
# the reason leads with who armed it and names the switch that disarms it.
printf '{"decision":"block","reason":"RoT voice gate (a Stop hook of the RoT MoE plugin the operator of this machine installed on purpose; ROTMOE_GATE=0 disarms it): summoned lenses have not spoken this turn. Give each its stanza -- inside its element, in its own register -- then stop:%s"}\n' "$_missing"
exit 0
