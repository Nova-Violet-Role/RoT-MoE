#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# ~/.claude/statusline.sh
# Theme: Violet (Low) -> Gold (Medium) -> Grey (High/Full)
# Schema verified against the Claude Code 2.1.238 statusLine stdin contract.
#
# Env overrides:
#   STATUSLINE_DEBUG=1      dump the raw payload to ~/.claude/statusline.debug.json
#   STATUSLINE_ASCII=1      no Nerd Font glyphs
#   STATUSLINE_NO_GIT=1     skip git probes
#   STATUSLINE_MAX_WIDTH=n  soft width cap (default 190)
#
# Failures are LOUD: a red marker is printed and the reason appended to
# ~/.claude/statusline.error.log. Nothing here fails silently.

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
LOG="$CLAUDE_DIR/statusline.error.log"

fail() {
  printf '\033[38;2;255;80;80m[statusline: %s]\033[0m\n' "$1"
  printf '%s %s\n' "$(date -Is 2>/dev/null || echo unknown-time)" "$1" 2>/dev/null >>"$LOG"
  exit 0
}

NOW_S=$(date +%s)          # one clock read for the whole render; rows must agree anyway
NOW_MS=$(( NOW_S * 1000 ))
input=$(cat)
[ -n "$input" ] || fail "empty stdin"
if [ "${STATUSLINE_DEBUG:-0}" = "1" ]; then
  printf '%s\n' "$input" >"$CLAUDE_DIR/statusline.debug.json" 2>/dev/null
fi

# --- 1. Locate jq (PATH is not guaranteed inside the statusline subprocess) ---
JQ=""
for cand in jq "$HOME/scoop/shims/jq.exe" "$USERPROFILE/scoop/shims/jq.exe" \
            /usr/bin/jq /usr/local/bin/jq /opt/homebrew/bin/jq "/c/Program Files/jq/jq.exe"; do
  if command -v "$cand" >/dev/null 2>&1; then JQ=$(command -v "$cand"); break; fi
done
[ -n "$JQ" ] || fail "jq not found"

# --- 2. ONE jq call. Unit-separator joined: a tab would collapse empty fields ---
US=$'\037'
raw=$(printf '%s' "$input" | "$JQ" -j '
  def s: if . == null then "" else tostring end;
  [ (.model.display_name // .model.id // "?")
  , (.session_name // "")
  , (.workspace.current_dir // .cwd // "")
  , (.context_window.total_input_tokens // 0)
  , (.context_window.context_window_size // 0)
  , (.context_window.used_percentage // "")
  , (.cost.total_cost_usd // 0)
  , (.cost.total_lines_added // 0)
  , (.cost.total_lines_removed // 0)
  , (.cost.total_duration_ms // 0)
  , (.effort.level // "")
  , (.thinking.enabled // false)
  , (.fast_mode // false)
  , (.exceeds_200k_tokens // false)
  , (.rate_limits.five_hour.used_percentage // "")
  , (.rate_limits.seven_day.used_percentage // "")
  , (.pr.number // "")
  , (.pr.kind // "")
  , (.worktree.name // .workspace.git_worktree // "")
  , (.agent.name // "")
  , (.session_id // "")
  , "END"
  ] | map(s | split("\n") | join(" ") | split("\r") | join(" ") | split("\u001f") | join(" ")) | join("\u001f")
' 2>/dev/null) || fail "jq parse failed"
[ -n "$raw" ] || fail "jq produced nothing"

IFS="$US" read -r -a F <<<"$raw"
[ "${F[21]:-}" = "END" ] || fail "field count mismatch (${#F[@]})"

model="${F[0]}";     sname="${F[1]}";     cwd="${F[2]}"
ctx_used="${F[3]}";  ctx_size="${F[4]}";  ctx_pct="${F[5]}"
cost="${F[6]}";      ladd="${F[7]}";      ldel="${F[8]}";      dur_ms="${F[9]}"
effort="${F[10]}";   thinking="${F[11]}"; fastmode="${F[12]}"; over200k="${F[13]}"
rl5="${F[14]}";      rl7="${F[15]}"
pr_num="${F[16]}";   pr_kind="${F[17]}";  wt="${F[18]}";       agent="${F[19]}"
sess="${F[20]}"

# --- 3. Colors (Violet / Gold / Grey) ---
RESET=$'\033[0m'; DIM=$'\033[2m'; BOLD=$'\033[1m'
VIOLET=$'\033[38;2;180;100;255m'
GOLD=$'\033[38;2;255;215;0m'
GREY=$'\033[38;2;128;128;128m'
WHITE=$'\033[38;2;255;255;255m'
RED=$'\033[38;2;255;95;95m'
GREEN=$'\033[38;2;120;220;140m'
ORANGE=$'\033[38;5;172m'
CYAN=$'\033[38;2;110;220;235m'

if [ "${STATUSLINE_ASCII:-0}" = "1" ]; then
  G_BRANCH="git"; G_FULL="#"; G_EMPTY="-"; G_THINK="*"; G_FAST=">>"
else
  G_BRANCH=$'\356\202\240'   # U+E0A0 branch icon as octal bytes: no subshell, file stays ASCII
  G_FULL=$'█'; G_EMPTY=$'░'; G_THINK=$'✻'; G_FAST=$'⚡'
fi

int() {
  local v="${1%%.*}"
  case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac
}
# Fork-free equivalents. $(int x) costs a subprocess (~28ms on Windows); iv sets a global
# instead. Same for padding: $(printf '%-12s') forks, rp/lp use parameter expansion.
_SPX='                                                                '
iv() { _I="${1%%.*}"; case "$_I" in ''|*[!0-9]*) _I=0 ;; esac; }
# Pad only, NEVER truncate. These strings carry ANSI colour codes, which count toward
# ${x:0:n} and ${x: -n} but are invisible on screen — truncating turned "STALL" into "LL".
# printf's %Ns only ever pads, so these must too.
rp() { _P="$1"; while [ "${#_P}" -lt "$2" ]; do _P="$_P "; done; }   # like printf %-Ns
lp() { _P="$1"; while [ "${#_P}" -lt "$2" ]; do _P=" $_P"; done; }   # like printf %Ns
z2() { _Z="$1"; [ "$_Z" -lt 10 ] 2>/dev/null && _Z="0$_Z"; }   # like printf %02d
fmt_num() {
  local n; iv "${1:-0}"; n=$_I
  if [ "$n" -ge 1000000 ]; then
    local m=$((n / 100000)); printf '%d.%dM' $((m / 10)) $((m % 10))
  elif [ "$n" -ge 1000 ]; then printf '%dk' $((n / 1000))
  else printf '%d' "$n"; fi
}

# --- 4. Context load bar ---
iv "$ctx_used"; used_i=$_I; iv "$ctx_size"; size_i=$_I
if [ -n "$ctx_pct" ]; then iv "$ctx_pct"; pct=$_I
elif [ "$size_i" -gt 0 ]; then pct=$(( (used_i * 100 + size_i / 2) / size_i ))
else pct=0; fi
[ "$pct" -gt 100 ] && pct=100

BAR_WIDTH=10
filled=$(( (pct * BAR_WIDTH + 50) / 100 ))
[ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
bar=""; i=0
while [ "$i" -lt "$filled" ]; do
  if   [ "$i" -lt 5 ]; then bar="${bar}${VIOLET}${G_FULL}"
  elif [ "$i" -lt 8 ]; then bar="${bar}${GOLD}${G_FULL}"
  else                      bar="${bar}${GREY}${G_FULL}"
  fi
  i=$((i + 1))
done
while [ "$i" -lt "$BAR_WIDTH" ]; do bar="${bar}${DIM}${G_EMPTY}${RESET}"; i=$((i + 1)); done
bar="${bar}${RESET}"

if   [ "$pct" -ge 90 ]; then pct_c="${BOLD}${RED}"
elif [ "$pct" -ge 80 ]; then pct_c="${GREY}"
elif [ "$pct" -ge 50 ]; then pct_c="${GOLD}"
else                         pct_c="${VIOLET}"
fi

# --- 5. Git (optional locks skipped, two cheap probes) ---
branch=""
if [ "${STATUSLINE_NO_GIT:-0}" != "1" ] && [ -n "$cwd" ] && [ -d "$cwd" ]; then
  if git -C "$cwd" --no-optional-locks rev-parse --git-dir >/dev/null 2>&1; then
    b=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
    if [ -z "$b" ]; then b=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null); fi
    if [ -n "$b" ]; then
      dirty=""
      if ! git -C "$cwd" --no-optional-locks diff --quiet 2>/dev/null; then
        dirty="*"
      elif ! git -C "$cwd" --no-optional-locks diff --cached --quiet 2>/dev/null; then
        dirty="+"
      fi
      branch="${WHITE}${G_BRANCH} ${b}${GOLD}${dirty}${RESET}"
    fi
  fi
fi

# --- 6. Caveman badge (same contract as caveman-statusline.ps1) ---
caveman=""
flag="$CLAUDE_DIR/.caveman-active"
if [ -f "$flag" ] && [ ! -L "$flag" ]; then
  # Six forks (wc, head, head, tr, tr, tr) for a badge, measured at 83ms. `read` takes the
  # first line as a builtin, ${x,,} lowercases, and ${x//[^a-z0-9-]/} strips — all zero forks.
  # The old size guard existed to avoid slurping a huge file; reading one line already does.
  mode=""; read -r mode < "$flag" 2>/dev/null
  mode="${mode%$'\r'}"; mode="${mode,,}"; mode="${mode//[^a-z0-9-]/}"
  if [ "${#mode}" -le 64 ]; then
    case "$mode" in
      full) caveman="${ORANGE}[CAVEMAN]${RESET}" ;;
      off)  caveman="" ;;
      lite|ultra|wenyan|wenyan-lite|wenyan-full|wenyan-ultra|commit|review|compress)
            caveman="${ORANGE}[CAVEMAN:${mode^^}]${RESET}" ;;
    esac
  fi
fi

# --- 6b. CmdPulse: the in-flight command, rendered live ---
# record.sh writes active/<tool_use_id>.json at PreToolUse and deletes it at PostToolUse,
# so anything here means a tool call is running RIGHT NOW. The status line re-renders on
# its refreshInterval, which is what makes this tick while the command is still going.
cmd_seg=""
cmd_lines=""
CP="$CLAUDE_DIR/cmdpulse"
# Each running tool gets its OWN line above the status line, with a bar the same 10 cells
# as the context bar — so several concurrent calls stack without eating the screen.
iv "${CMDPULSE_BAR_WIDTH:-10}"; CMD_BAR_W=$_I
[ "$CMD_BAR_W" -lt 4 ] && CMD_BAR_W=10
# ONE jq for every active file AND the baseline, instead of four per row. Profiled at
# ~360ms per row on Windows because each jq startup costs ~60ms; three rows meant twelve
# jq processes. Eight newline-separated fields per file — newlines, because no escape
# survives this file's write path reliably.
declare -A A_SESS A_TOOL A_SIG A_SUB A_START A_MED A_N
_active_list=""
if [ -d "$CP/active" ] && compgen -G "$CP/active/*.json" >/dev/null 2>&1; then
  _bl="$CP/baseline.json"; [ -s "$_bl" ] || _bl=/dev/null
  while IFS= read -r _k; do
    IFS= read -r _v1 || break; IFS= read -r _v2 || break; IFS= read -r _v3 || break
    IFS= read -r _v4 || break; IFS= read -r _v5 || break; IFS= read -r _v6 || break
    IFS= read -r _v7 || break
    A_SESS["$_k"]="$_v1"; A_TOOL["$_k"]="$_v2"; A_SIG["$_k"]="$_v3"; A_SUB["$_k"]="$_v4"
    A_START["$_k"]="$_v5"; A_MED["$_k"]="$_v6"; A_N["$_k"]="$_v7"
  done < <("$JQ" -r --slurpfile bl "$_bl" '
      (.sig // "") as $s
      | ($bl[0] // {}) as $B
      | (.id // ""),
        (.session // ""),
        (.tool // "?"),
        $s,
        ((.subject // "") | gsub("[\n\r]"; " ")),
        ((.start // 0) | tostring),
        (($B[$s].median // 0) | tostring),
        (($B[$s].n // 0) | tostring)
    ' "$CP/active"/*.json 2>/dev/null | tr -d '\r')
fi
# Stall detection. The bar cannot know whether a process is hung — nothing exposes that.
# What IS measurable is silence: if the command's own output log has not grown, it has
# produced nothing for that long. One stat call covers every log, so this costs one fork
# regardless of how many rows are drawn. Only ever says STALLED, never "stuck": a silent
# compile is silent but healthy, and the label must not claim more than it observed.
declare -A A_MT
iv "${CMDPULSE_STALL_S:-300}"; STALL_S=$_I
[ "$STALL_S" -lt 5 ] && STALL_S=300
if [ -d "$CP/stream" ] && compgen -G "$CP/stream/*.log" >/dev/null 2>&1; then
  while read -r _mt _lp; do
    [ -n "${_lp:-}" ] || continue
    _lk="${_lp##*/}"; _lk="${_lk%.log}"; A_MT["$_lk"]="$_mt"
  done < <(stat -c '%Y %n' "$CP/stream"/*.log 2>/dev/null | tr -d '\r')
fi
if [ -d "$CP/active" ]; then
  for af in $(ls -t "$CP/active"/*.json 2>/dev/null); do
    if [ -f "$af" ]; then
    # Every Claude Code window shares ~/.claude/cmdpulse, so without this a second window
    # shows the first one's in-flight calls — and its own look untracked.
    _ak="${af##*/}"; _ak="${_ak%.json}"
    a_sess="${A_SESS[$_ak]:-}"
    if [ -n "${sess:-}" ] && [ -n "$a_sess" ] && [ "$a_sess" != "$sess" ]; then continue; fi
    a_tool="${A_TOOL[$_ak]:-?}"; a_sig="${A_SIG[$_ak]:-}"
    a_sub="${A_SUB[$_ak]:-}";    a_start="${A_START[$_ak]:-}"
    if [ -n "${a_start:-}" ] && [ "$a_start" != "0" ]; then
      now_ms=$NOW_MS
      iv "$a_start"; el=$(( now_ms - _I ))
      [ "$el" -lt 0 ] && el=0
      # An interrupted or denied tool call orphans its active file, so it does need reaping —
      # but the threshold must be far above any REAL command. A 2-minute default reaped
      # 35-minute builds, i.e. precisely the long-running commands this bar exists for.
      # 6 hours: long enough that no genuine tool call is ever discarded.
      iv "${CMDPULSE_STALE_MS:-21600000}"; if [ "$el" -gt "$_I" ]; then
        rm -f "$af" 2>/dev/null
        continue
      fi
      # Read the PRECOMPUTED baseline. This previously slurped the whole ledger with `jq -s`
      # once per active file per render — ~1s idle, 2s with three calls in flight. The status
      # line re-runs every second and each new run ABORTS the previous one still executing
      # (`#_(){ this.#s?.abort() }` in 2.1.238), so any render slower than the interval never
      # completes and the line goes blank. record.sh writes baseline.json at PostToolUse; two
      # tiny reads of a small map replace an O(ledger) slurp.
      # already fetched in the single jq pass above
      iv "${A_MED[$_ak]:-0}"; med=$_I; iv "${A_N[$_ak]:-0}"; nsamp=$_I
      CW=$CMD_BAR_W
      spin_i=$(( (el / 120) % 10 ))
      case "$spin_i" in
        0) sp=$'⠋';; 1) sp=$'⠙';; 2) sp=$'⠹';; 3) sp=$'⠸';; 4) sp=$'⠼';;
        5) sp=$'⠴';; 6) sp=$'⠦';; 7) sp=$'⠧';; 8) sp=$'⠇';; *) sp=$'⠏';;
      esac
      cbar=""; k=0
      # --- TIER 1: real progress, read from the command's OWN output -------------------
      # A generic tool cannot know how much work an arbitrary command has left — but the
      # command itself often says so ([5/20], 45%, "12 of 34"). With CMDPULSE_STREAM=1 that
      # output is already on disk, so parse it. This is MEASURED progress; the median below
      # is only the fallback for commands that report nothing.
      real_pct=""; real_now=""; real_tot=""
      p_log="$CP/stream/${af##*/}"; p_log="${p_log%.json}.log"
      # ONE read of the log, parsed by bash builtins. The previous version read it twice
      # through eight forks (tail|tr|grep|tail, twice) — measured at ~613ms per row on
      # Windows, which alone pushed a three-row render past 4s. mapfile from a single tail
      # is one fork; the regex below costs none.
      s_tail=""
      if [ -f "$p_log" ]; then
        mapfile -t s_lines < <(tail -c 4096 "$p_log" 2>/dev/null | tr -d '\r') 2>/dev/null
        n=${#s_lines[@]}
        # newest non-blank line, for the display row under the bar
        j=$(( n - 1 ))
        while [ "$j" -ge 0 ]; do
          case "${s_lines[$j]}" in ''|' '*) ;; *) s_tail="${s_lines[$j]}"; break ;; esac
          j=$(( j - 1 ))
        done
        # newest line carrying a progress marker, scanning backwards
        j=$(( n - 1 ))
        while [ "$j" -ge 0 ] && [ -z "$real_pct" ]; do
          ln="${s_lines[$j]}"
          if [[ $ln =~ \[[[:space:]]*([0-9]+)[[:space:]]*/[[:space:]]*([0-9]+)[[:space:]]*\] ]]; then
            real_now="${BASH_REMATCH[1]}"; real_tot="${BASH_REMATCH[2]}"
          elif [[ $ln =~ ([0-9]+)[[:space:]]+of[[:space:]]+([0-9]+) ]]; then
            real_now="${BASH_REMATCH[1]}"; real_tot="${BASH_REMATCH[2]}"
          elif [[ $ln =~ ([0-9]+)(\.[0-9]+)?% ]]; then
            real_pct="${BASH_REMATCH[1]}"
          elif [[ $ln =~ ([0-9]+)/([0-9]+) ]]; then
            real_now="${BASH_REMATCH[1]}"; real_tot="${BASH_REMATCH[2]}"
          fi
          if [ -n "$real_tot" ] && [ "$real_tot" -gt 0 ] 2>/dev/null; then
            real_pct=$(( real_now * 100 / real_tot ))
          fi
          j=$(( j - 1 ))
        done
        [ -n "$real_pct" ] && [ "$real_pct" -gt 100 ] 2>/dev/null && real_pct=100
      fi
      if [ -n "$real_pct" ]; then
        cpct="$real_pct"
        ccol="$CYAN"                      # cyan = this number came from the command itself
        cfill=$(( cpct * CW / 100 ))
        while [ "$k" -lt "$cfill" ]; do cbar="${cbar}${ccol}${G_FULL}"; k=$((k+1)); done
        while [ "$k" -lt "$CW" ]; do cbar="${cbar}${DIM}${G_EMPTY}${RESET}"; k=$((k+1)); done
        clbl="${ccol}${cpct}%${RESET}"
        # ETA from real progress: elapsed / done * remaining. No history needed.
        if [ -n "$real_now" ] && [ "$real_now" -gt 0 ] 2>/dev/null && [ -n "$real_tot" ]; then
          rem_ms=$(( el * (real_tot - real_now) / real_now ))
          rs=$(( rem_ms / 1000 ))
          if   [ "$rs" -ge 3600 ]; then eta_s="$(( rs / 3600 ))h$(printf '%02d' $(( (rs % 3600) / 60 )))m"
          elif [ "$rs" -ge 60 ];   then eta_s="$(( rs / 60 ))m$(printf '%02d' $(( rs % 60 )))s"
          else                          eta_s="${rs}s"; fi
          eta_s="${DIM}ETA ${RESET}${ccol}${eta_s}${RESET} ${DIM}${real_now}/${real_tot}${RESET}"
        else
          eta_s="${DIM}live${RESET}"
        fi
      elif [ "$nsamp" -ge 2 ] && [ "$med" -gt 0 ]; then
        cpct=$(( el * 100 / med ))
        [ "$cpct" -gt 100 ] && cpct=100
        ccol="$VIOLET"; [ "$cpct" -ge 80 ] && ccol="$GOLD"
        if [ "$(( el * 100 / med ))" -ge 100 ]; then ccol="$RED"; fi
        cfill=$(( cpct * CW / 100 ))
        while [ "$k" -lt "$cfill" ]; do cbar="${cbar}${ccol}${G_FULL}"; k=$((k+1)); done
        while [ "$k" -lt "$CW" ]; do cbar="${cbar}${DIM}${G_EMPTY}${RESET}"; k=$((k+1)); done
        # ETA = learned median minus elapsed. Only ever shown when this signature has >= 2
        # recorded runs; otherwise there is no honest estimate and the bar sweeps instead.
        eta_ms=$(( med - el ))
        if [ "$(( el * 100 / med ))" -ge 100 ]; then
          # "over" read as "finished/failed" to every human who saw it. The command is still
          # RUNNING — it is merely past its usual time. Say how far past, and keep the word
          # "run" so the state is unambiguous.
          ov=$(( (el - med) / 1000 ))
          if   [ "$ov" -ge 3600 ]; then ov_s="+$(( ov / 3600 ))h$(printf '%02d' $(( (ov % 3600) / 60 )))m"
          elif [ "$ov" -ge 60 ];   then ov_s="+$(( ov / 60 ))m$(printf '%02d' $(( ov % 60 )))s"
          else                          ov_s="+${ov}s"
          fi
          clbl="${RED}${ov_s}${RESET}"; eta_s="${DIM}run${RESET}"
        else
          clbl="${ccol}${cpct}%${RESET}"
          e=$(( eta_ms / 1000 ))
          if   [ "$e" -ge 3600 ]; then eta_s="$(( e / 3600 ))h$(printf '%02d' $(( (e % 3600) / 60 )))m"
          elif [ "$e" -ge 60 ];   then eta_s="$(( e / 60 ))m$(printf '%02d' $(( e % 60 )))s"
          elif [ "$e" -ge 1 ];    then eta_s="${e}s"
          else                         eta_s="<1s"
          fi
          eta_s="${DIM}ETA ${RESET}${ccol}${eta_s}${RESET}"
        fi
      else
        # no history for this command shape: sweep instead of inventing a number
        pos=$(( (el / 150) % (CW * 2) ))
        [ "$pos" -ge "$CW" ] && pos=$(( CW * 2 - pos - 1 ))
        while [ "$k" -lt "$CW" ]; do
          d=$(( k > pos ? k - pos : pos - k ))
          if [ "$d" -le 1 ]; then cbar="${cbar}${VIOLET}${G_FULL}"; else cbar="${cbar}${DIM}${G_EMPTY}${RESET}"; fi
          k=$((k+1))
        done
        clbl="${DIM}···${RESET}"; eta_s="${DIM}ETA ?${RESET}"
      fi
      # Long-running commands are the whole point of this bar, so the clock must stay readable
      # past a minute: 2152s means nothing at a glance, 35m52s does.
      el_s=$(( el / 1000 ))
      if   [ "$el_s" -ge 3600 ]; then el_s="$(( el_s / 3600 ))h$(printf '%02d' $(( (el_s % 3600) / 60 )))m"
      elif [ "$el_s" -ge 60 ];   then el_s="$(( el_s / 60 ))m$(printf '%02d' $(( el_s % 60 )))s"
      else                            el_s="${el_s}s"
      fi
      # Measured silence outranks the estimate: if the command has printed nothing for
      # STALL_S seconds, that observation is worth more than a percentage derived from
      # history. Says STALLED (no output), never "stuck" — a silent compile is healthy.
      _mt="${A_MT[$_ak]:-}"
      if [ -n "$_mt" ]; then
        quiet=$(( NOW_S - _mt ))
        if [ "$quiet" -ge "$STALL_S" ]; then
          if   [ "$quiet" -ge 3600 ]; then q_s="$(( quiet / 3600 ))h"
          elif [ "$quiet" -ge 60 ];   then q_s="$(( quiet / 60 ))m"
          else                             q_s="${quiet}s"
          fi
          clbl="${RED}STALL${RESET}"; eta_s="${RED}quiet ${q_s}${RESET}"
        fi
      fi
      rp "${a_tool:0:12}" 12; f_tool="$_P"; lp "$clbl" 6; f_lbl="$_P"; lp "$el_s" 7; f_el="$_P"
      cmd_lines="${cmd_lines}${GOLD}${sp}${RESET} ${BOLD}${WHITE}${f_tool}${RESET} ${cbar}${RESET} ${f_lbl} ${DIM}${f_el}${RESET} ${eta_s:-} ${WHITE}${a_sub:0:60}${RESET}"$'\n'
      # If CMDPULSE_STREAM wrapped this command, its own output is being tee'd to a log.
      # Show the newest non-empty line: that is the script's real progress, live.
      # Already read above in the single mapfile pass — no second tail, no extra forks.
      [ -n "${s_tail:-}" ] && cmd_lines="${cmd_lines}    ${DIM}└ ${RESET}${GREY}${s_tail:0:88}${RESET}"$'\n'
    fi
    fi
  done
fi

# --- 6c. Recent completed calls -------------------------------------------------------
# The host renders the status line when idle, i.e. after calls finish, so a rolling history
# is what it can actually show. ONE jq over a small file (never the ledger) emits preformatted
# rows; bash only colours them. CMDPULSE_ROWS controls how many (default 3, max 12).
if [ -z "$cmd_lines" ] || [ "${CMDPULSE_ROWS:-3}" -gt 1 ] 2>/dev/null; then
  iv "${CMDPULSE_ROWS:-3}"; ROWS=$_I
  [ "$ROWS" -lt 1 ] && ROWS=1
  [ "$ROWS" -gt 12 ] && ROWS=12
  if [ -s "$CP/recent.ndjson" ]; then
    while IFS='|' read -r r_ok r_tool r_dur r_when r_sub; do
      [ -n "${r_tool:-}" ] || continue
      if [ "$r_ok" = "1" ]; then rcol="$GREEN"; rmark="✓"; else rcol="$RED"; rmark="✗"; fi
      rbar=""; rk=0
      while [ "$rk" -lt "$CMD_BAR_W" ]; do rbar="${rbar}${rcol}${G_FULL}"; rk=$((rk+1)); done
      cmd_lines="${cmd_lines}${rcol}${rmark}${RESET} ${BOLD}${WHITE}$(printf '%-12s' "${r_tool:0:12}")${RESET} ${rbar}${RESET} $(printf '%6s' "done") ${DIM}$(printf '%7s' "$r_dur")${RESET} ${DIM}@${r_when}${RESET} ${WHITE}$(printf '%s' "${r_sub:0:52}")${RESET}"$'\n'
    done < <("$JQ" -r --argjson n "$ROWS" --arg S "${sess:-}" '
        [inputs | select(type == "object") | select(($S == "") or ((.session // "") == $S))] as $all
        | ($all | length) as $len
        | $all[ (if $len > $n then $len - $n else 0 end) : ]
        | reverse
        | .[]
        | ((if .err then "0" else "1" end)
           + "|" + (.tool // "?")
           + "|" + (if (.dur // 0) >= 3600000 then "\(((.dur/3600000)|floor))h\(((.dur%3600000)/60000|floor))m"
                    elif (.dur // 0) >= 60000 then "\(((.dur/60000)|floor))m\(((.dur%60000)/1000|floor))s"
                    elif (.dur // 0) >= 1000  then "\(((.dur/1000)*10|round)/10)s"
                    else "\(.dur // 0)ms" end)
           + "|" + ((((.t // 0) / 1000) | floor | strftime("%H:%M:%S")) // "")
           + "|" + ((.subject // "") | gsub("[\n\r|]"; " ")))' \
      -n "$CP/recent.ndjson" 2>/dev/null | tr -d '\r')
  fi
fi
# --- 6d. Lifecycle phases: the silences that are NOT tool calls ---
# Compaction, a pending permission prompt, a subagent thinking between tool calls — none of
# these have an active/ entry, so without this the bar goes quiet and the session reads as
# frozen. record.sh event <Name> writes/removes these markers.
if [ -d "$CP/phase" ]; then
  for pf in "$CP/phase"/*.json; do
    [ -f "$pf" ] || continue
    # ONE jq per phase file, not four. At ~57ms per jq on Windows, four reads per phase
    # pushed a render with several phases to 2.4s — against a 3s abort budget. Newline
    # separated rather than unit separated: no escape survives the write path reliably.
    { read -r p_kind; read -r p_lab; read -r p_t; read -r p_ttl; } < <(
      "$JQ" -r '(.kind // "phase"), (.label // ""), ((.t // 0)|tostring), ((.ttl // 0)|tostring)' \
        "$pf" 2>/dev/null | tr -d '\r')
    [ -n "${p_lab:-}" ] || continue
    iv "$p_t"; p_ms=$(( NOW_S * 1000 - _I ))
    [ "$p_ms" -lt 0 ] && p_ms=0
    # Flash events (Stop, Notification, FileChanged …) are moments, not durations: they carry
    # a ttl and reap themselves once shown. ttl 0 means "runs until its matching stop event".
    if [ "$p_ttl" -gt 0 ] && [ "$p_ms" -gt "$p_ttl" ]; then rm -f "$pf" 2>/dev/null; continue; fi
    p_el=$(( p_ms / 1000 ))
    if   [ "$p_el" -ge 3600 ]; then p_s="$(( p_el / 3600 ))h$(printf '%02d' $(( (p_el % 3600) / 60 )))m"
    elif [ "$p_el" -ge 60 ];   then p_s="$(( p_el / 60 ))m$(printf '%02d' $(( p_el % 60 )))s"
    else                            p_s="${p_el}s"; fi
    # A phase has no learned duration (a permission prompt waits on a human; compaction
    # varies), so it gets a sweeping bar rather than a percentage — same width as the tool
    # bars so the rows line up, and moving so it reads as "running", not "hung".
    case "$p_kind" in
      perm)    p_col="$GOLD" ;;    # waiting on YOU, not on the machine
      compact) p_col="$VIOLET" ;;
      agent)   p_col="$CYAN" ;;
      *)       p_col="$GREY" ;;
    esac
    p_bar=""; pk=0
    p_pos=$(( (p_el * 1000 / 150) % (CMD_BAR_W * 2) ))
    [ "$p_pos" -ge "$CMD_BAR_W" ] && p_pos=$(( CMD_BAR_W * 2 - p_pos - 1 ))
    while [ "$pk" -lt "$CMD_BAR_W" ]; do
      pd=$(( pk > p_pos ? pk - p_pos : p_pos - pk ))
      if [ "$pd" -le 1 ]; then p_bar="${p_bar}${p_col}${G_FULL}"; else p_bar="${p_bar}${DIM}${G_EMPTY}${RESET}"; fi
      pk=$((pk+1))
    done
    cmd_lines="${cmd_lines}${p_col}◈${RESET} ${BOLD}${WHITE}$(printf '%-12s' "${p_kind}")${RESET} ${p_bar}${RESET} $(printf '%6s' "wait") ${DIM}$(printf '%7s' "$p_s")${RESET} ${WHITE}${p_lab}${RESET}"$'\n'
  done
fi

# --- 7. Segments ---
sep="${DIM}|${RESET}"
short_dir=$(basename "$cwd" 2>/dev/null); [ -n "$short_dir" ] || short_dir="?"
short_dir_s="$short_dir"
if [ "${#short_dir}" -gt 26 ]; then short_dir_s="${short_dir:0:12}..${short_dir: -12}"; fi

flags=""
[ "$thinking" = "true" ] && flags="${flags}${flags:+ }${VIOLET}${G_THINK}${RESET}"
[ "$fastmode" = "true" ] && flags="${flags}${flags:+ }${GOLD}${G_FAST}${RESET}"
[ "$over200k" = "true" ] && flags="${flags}${flags:+ }${RED}!200k${RESET}"
[ -n "$effort" ] && flags="${DIM}${effort}${RESET}${flags:+ }${flags}"

head_seg="${BOLD}${WHITE}[${model}]${RESET}"
[ -n "$agent" ] && head_seg="${head_seg} ${GOLD}@${agent}${RESET}"
[ -n "$flags" ] && head_seg="${head_seg} ${flags}"

dir_suffix=""
[ -n "$wt" ] && dir_suffix=" ${GOLD}(${wt})${RESET}"
if [ -n "$pr_num" ]; then
  if [ "$pr_kind" = "mr" ]; then dir_suffix="${dir_suffix} ${GOLD}MR !${pr_num}${RESET}"
  else dir_suffix="${dir_suffix} ${GOLD}PR #${pr_num}${RESET}"; fi
fi
dir_seg="${VIOLET}${short_dir}${RESET}${dir_suffix}"
dir_seg_s="${VIOLET}${short_dir_s}${RESET}${dir_suffix}"

ctx_seg="${bar} ${pct_c}${pct}%${RESET}"

rc_seg=""
iv "${ROLLING_CONTEXT_TRIGGER:-0}"; rc_trig=$_I
if [ "$rc_trig" -gt 0 ] && [ "$used_i" -ge "$rc_trig" ]; then rc_seg="${GOLD}RC${RESET}"; fi

tok_seg="${DIM}$(fmt_num "$used_i")/$(fmt_num "$size_i") tok${RESET}"

rl_color() {
  local p; iv "$1"; p=$_I
  if   [ "$p" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$p" -ge 70 ]; then printf '%s' "$GOLD"
  else printf '%s' "$GREY"; fi
}
rl_seg=""
if [ -n "$rl5" ]; then iv "$rl5"; rl_seg="$(rl_color "$rl5")5h ${_I}%${RESET}"; fi
if [ -n "$rl7" ]; then
  [ -n "$rl_seg" ] && rl_seg="${rl_seg}${DIM} . ${RESET}"
  iv "$rl7"; rl_seg="${rl_seg}$(rl_color "$rl7")7d ${_I}%${RESET}"
fi

cost_seg=$(printf '%s$%.2f%s' "$GREEN" "$cost" "$RESET" 2>/dev/null)

dur_seg=""; iv "$dur_ms"; d=$_I
[ "$d" -ge 60000 ] && dur_seg="${DIM}~$((d / 60000))m${RESET}"

lines_seg=""; iv "$ladd"; la=$_I; iv "$ldel"; ld=$_I
[ $((la + ld)) -gt 0 ] && lines_seg="${GREEN}+${la}${RESET}${DIM}/${RESET}${RED}-${ld}${RESET}"

sess_seg=""
[ -n "$sname" ] && sess_seg="${DIM}<${sname}>${RESET}"

# --- 8. Assemble, degrading segment by segment until it fits ---
iv "${STATUSLINE_MAX_WIDTH:-${COLUMNS:-190}}"; MAXW=$_I
[ "$MAXW" -lt 60 ] && MAXW=190

# OSC 8 hyperlink — clickable in WezTerm, Windows Terminal and most modern terminals.
# Clicking "Inspect" opens the full CmdPulse dashboard for the whole call history.
inspect_seg=""
if [ -f "$CP/dashboard.html" ] || [ -d "$CP" ]; then
  _url="file:///$(printf '%s' "$CP/dashboard.html" | sed 's#^/\([a-zA-Z]\)/#\1:/#')"
  inspect_seg=$'\033]8;;'"${_url}"$'\033\\'"${CYAN}⧉ Inspect${RESET}"$'\033]8;;\033\\'
fi

# Order is by what you must see in the FIRST few columns, because the status line is
# clipped at the pane width and everything past it is invisible:
#   1. the running command (only thing that changes second to second)
#   2. the context bar
#   3. model, then everything else, in descending value.
build() {
  local lvl="$1" out=""
  out="${ctx_seg}"
  [ -n "$rc_seg" ] && out="$out $rc_seg"
  out="$out $sep $head_seg"
  [ -n "$sess_seg" ] && [ "$lvl" -ge 5 ] && out="$out $sess_seg"
  if [ "$lvl" -ge 4 ]; then out="$out $sep $dir_seg"
  elif [ "$lvl" -ge 2 ]; then out="$out $sep $dir_seg_s"; fi
  [ -n "$branch" ] && [ "$lvl" -ge 3 ] && out="$out $sep $branch"
  [ "$lvl" -ge 5 ] && out="$out $sep $tok_seg"
  [ -n "$rl_seg" ] && [ "$lvl" -ge 6 ] && out="$out $sep $rl_seg"
  [ -n "$cost_seg" ] && [ "$lvl" -ge 7 ] && out="$out $sep $cost_seg"
  [ -n "$dur_seg" ] && [ "$lvl" -ge 8 ] && out="$out $dur_seg"
  [ -n "$lines_seg" ] && [ "$lvl" -ge 8 ] && out="$out $sep $lines_seg"
  [ -n "$caveman" ] && [ "$lvl" -ge 3 ] && out="$out $sep $caveman"
  [ -n "$inspect_seg" ] && out="$out $sep $inspect_seg"
  printf '%s' "$out"
}
# Strips BOTH colour (CSI ... m) and hyperlinks (OSC 8 ... ST). An OSC 8 URL is ~60
# invisible characters; counting them as visible would degrade the line for nothing.
vis_len() {
  printf '%s' "$1" \
    | sed -e 's/\x1b\[[0-9;]*m//g' \
    | perl -pe 'BEGIN{$e=chr(27);$b=chr(92)} s/\Q$e\E\]8;;.*?(\Q$e\E\Q$b\E|\a)//g' \
    | wc -m
}

line=""
for lvl in 8 7 6 5 4 3 2 1; do
  line=$(build "$lvl")
  [ "$(vis_len "$line")" -le "$MAXW" ] && break
done

# Probe: record every invocation, so we can measure whether the host redraws mid-tool-call.
if [ "${CMDPULSE_HEARTBEAT:-1}" = "1" ]; then
  hb_n=$(ls "$CP/active"/*.json 2>/dev/null | wc -l | tr -d ' ')
  printf '%s active=%s\n' "$(date +%H:%M:%S)" "$hb_n" >>"$CP/heartbeat.log" 2>/dev/null
fi

# Running/just-finished tool calls print ABOVE the status line, one row each.
[ -n "$cmd_lines" ] && printf '%s' "$cmd_lines"
printf '%s\n' "$line"
