#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# ~/.claude/cmdpulse/cmdpulse.sh
# CmdPulse terminal dashboard — long live progress bars for Claude Code tool calls.
#
# Run in a SECOND pane. It owns that screen and never touches the status line.
#   bash ~/.claude/cmdpulse/cmdpulse.sh          live dashboard
#   bash ~/.claude/cmdpulse/cmdpulse.sh top      where the time goes
#   bash ~/.claude/cmdpulse/cmdpulse.sh last     inspect the most recent call
#   bash ~/.claude/cmdpulse/cmdpulse.sh id <id>  inspect one tool_use_id
#   bash ~/.claude/cmdpulse/cmdpulse.sh follow   one line per event, pipe-friendly
#
# The percentage is an ETA against the learned median for that command signature.
# Real progress is unknowable for an arbitrary command, so it is labelled ETA and a
# signature with no history gets a sweeping indeterminate bar instead of a fake number.

set -u
MODE="${1:-live}"
ROOT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/cmdpulse"
EVENTS="$ROOT/events.ndjson"
ACTIVE="$ROOT/active"
RUNS="$ROOT/runs"
BARW="${CMDPULSE_BAR_WIDTH:-44}"
mkdir -p "$ACTIVE" "$RUNS" 2>/dev/null

JQ=""
for c in jq "$HOME/scoop/shims/jq.exe" /usr/bin/jq /usr/local/bin/jq /opt/homebrew/bin/jq; do
  if command -v "$c" >/dev/null 2>&1; then JQ=$(command -v "$c"); break; fi
done
[ -n "$JQ" ] || { echo "cmdpulse: jq not found"; exit 1; }

# jq.exe on Windows writes CRLF; a trailing CR corrupts the last @tsv field.
JQBIN="$JQ"
jqlf() { "$JQBIN" "$@" | tr -d '\r'; }
JQ=jqlf

R=$'\033[0m'; D=$'\033[2m'; B=$'\033[1m'
VIO=$'\033[38;2;180;100;255m'; GLD=$'\033[38;2;255;215;0m'; GRY=$'\033[38;2;128;128;128m'
WHT=$'\033[38;2;255;255;255m'; RED=$'\033[38;2;255;95;95m'; GRN=$'\033[38;2;120;220;140m'
CYN=$'\033[38;2;110;220;235m'
FULL='▰'; EMPT='▱'
SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

now_ms() { echo $(( $(date +%s) * 1000 )); }

fmt_dur() { # ms
  local m=${1%%.*}; case "$m" in ''|*[!0-9-]*) m=0;; esac
  if [ "$m" -lt 0 ]; then printf '   —  '
  elif [ "$m" -lt 1000 ]; then printf '%4dms' "$m"
  elif [ "$m" -lt 60000 ]; then printf '%3d.%01ds' $((m/1000)) $(((m%1000)/100))
  else printf '%3dm%02ds' $((m/60000)) $(((m%60000)/1000)); fi
}
fmt_bytes() {
  local b=${1%%.*}; case "$b" in ''|*[!0-9-]*) b=0;; esac
  if   [ "$b" -lt 1024 ]; then printf '%dB' "$b"
  elif [ "$b" -lt 1048576 ]; then printf '%d.%01dK' $((b/1024)) $(((b%1024)*10/1024))
  elif [ "$b" -lt 1073741824 ]; then printf '%d.%01dM' $((b/1048576)) $(((b%1048576)*10/1048576))
  else printf '%d.%02dG' $((b/1073741824)) $(((b%1073741824)*100/1073741824)); fi
}
trunc() { local s="$1" w="$2"; s="${s//$'\n'/ }"
  if [ "${#s}" -le "$w" ]; then printf '%-*s' "$w" "$s"; else printf '%s...' "${s:0:$((w-3))}"; fi; }

# Baseline: median / p95 / max duration per signature, from the ledger.
baseline() {
  [ -s "$EVENTS" ] || { echo '{}'; return; }
  "$JQ" -s -c '
    map(select(.ev=="post" and (.dur // -1) >= 0))
    | group_by(.sig)
    | map({ key: .[0].sig,
            value: ( (map(.dur) | sort) as $v | ($v|length) as $n |
              { n: $n,
                median: (if $n % 2 == 1 then $v[($n/2|floor)] else (($v[$n/2-1]+$v[$n/2])/2) end),
                p95: $v[([$n-1, ($n*0.95|floor)] | min)],
                max: $v[$n-1],
                total: ($v|add) }) })
    | from_entries' "$EVENTS" 2>/dev/null || echo '{}'
}

bar() { # pct(0-100 int) indeterminate frame color
  local pct=$1 indet=$2 frame=$3 col=$4 i s='' pos
  if [ "$indet" = "1" ]; then
    pos=$(( frame % (BARW*2) )); [ "$pos" -ge "$BARW" ] && pos=$(( BARW*2 - pos - 1 ))
    for ((i=0;i<BARW;i++)); do
      if [ $((i>pos?i-pos:pos-i)) -le 2 ]; then s+="${col}${FULL}"; else s+="${D}${EMPT}${R}"; fi
    done
    printf '%s' "$s$R"; return
  fi
  [ "$pct" -gt 100 ] && pct=100; [ "$pct" -lt 0 ] && pct=0
  local fill=$(( pct * BARW / 100 ))
  s="$col"; for ((i=0;i<fill;i++)); do s+="$FULL"; done
  s+="$D"; for ((i=fill;i<BARW;i++)); do s+="$EMPT"; done
  printf '%s' "$s$R"
}

inspect() { # $1 = id or "last"
  local f
  if [ "$1" = "last" ]; then
    f=$(ls -t "$RUNS"/*.post.json "$RUNS"/*.pre.json 2>/dev/null | head -1)
  else
    f=$(ls -t "$RUNS"/*"$1"*.post.json 2>/dev/null | head -1)
    [ -n "$f" ] || f=$(ls -t "$RUNS"/*"$1"*.pre.json 2>/dev/null | head -1)
  fi
  [ -n "$f" ] || { echo "${GRY}no run matching '$1'$R"; return 1; }
  local id; id=$(basename "$f"); id="${id%%.*}"
  local pre="$RUNS/$id.pre.json" post="$RUNS/$id.post.json"

  echo
  printf '%s\n' "$B$WHT  $( [ -f "$post" ] && "$JQ" -r '.tool_name' "$post" || "$JQ" -r '.tool_name' "$pre" )$R  $D$id$R"
  printf '%s\n' "$GRY  ────────────────────────────────────────────────────────────────$R"
  if [ -f "$pre" ]; then
    "$JQ" -r --arg d "$D" --arg r "$R" '
      "  \($d)cwd     \($r)  \(.cwd // "")",
      "  \($d)agent   \($r)  \(.agent_type // "main")     \($d)mode\($r) \(.permission_mode // "")",
      "  \($d)session \($r)  \(.session_id // "")"' "$pre"
  fi
  if [ -f "$post" ]; then
    "$JQ" -r --arg d "$D" --arg r "$R" '
      "  \($d)duration\($r)  \(.duration_ms // -1) ms",
      "  \($d)exit    \($r)  \((.tool_response.exit_code // .tool_response.exitCode // "—")|tostring)"' "$post"
  else
    printf '%s\n' "  ${GLD}still running$R"
  fi
  echo; printf '%s\n' "$CYN  INPUT$R"
  "$JQ" -r '.tool_input' "${post:-$pre}" 2>/dev/null | sed 's/^/  /'
  if [ -f "$post" ]; then
    echo; printf '%s\n' "$CYN  OUTPUT$R"
    "$JQ" -r '.tool_response | if type=="string" then . else tostring end' "$post" 2>/dev/null | head -400 | sed 's/^/  /'
  fi
  echo
}

show_top() {
  [ -s "$EVENTS" ] || { echo "${GRY}no calls recorded yet$R"; return; }
  echo
  printf '%s\n' "$B$WHT  CmdPulse — where the time goes$R"
  printf '%s\n' "$GRY  ──────────────────────────────────────────────────────────────────────────$R"
  printf '  %-34s %6s %8s %8s %8s %6s %9s\n' SIGNATURE CALLS MEDIAN P95 SLOWEST FAIL TOTAL
  "$JQ" -s -r '
    map(select(.ev=="post"))
    | group_by(.sig) | map({
        sig: .[0].sig, calls: length,
        fails: (map(select(.err)) | length),
        total: (map(.dur // 0) | add),
        v: (map(.dur // 0) | sort) })
    | map(. + { n: (.v|length) })
    | map(. + { median: (if .n % 2 == 1 then .v[(.n/2|floor)] else ((.v[.n/2-1]+.v[.n/2])/2) end),
                p95: .v[([.n-1, (.n*0.95|floor)] | min)], max: .v[.n-1] })
    | sort_by(-.total) | .[:30]
    | .[] | [.sig, .calls, .median, .p95, .max, .fails, .total] | @tsv' "$EVENTS" |
  while IFS=$'\t' read -r sig calls med p95 mx fails total; do
    fc="$D"; [ "${fails:-0}" -gt 0 ] && fc="$RED"
    printf '  %-34s %6s %8s %8s %8s ' "$(trunc "$sig" 34)" "$calls" \
      "$(fmt_dur "$med")" "$(fmt_dur "$p95")" "$(fmt_dur "$mx")"
    printf '%s%6s%s %9s\n' "$fc" "$fails" "$R" "$(fmt_dur "$total")"
  done
  echo
}

follow() {
  local seen=0 n
  while true; do
    n=$(wc -l < "$EVENTS" 2>/dev/null || echo 0)
    if [ "$n" -gt "$seen" ]; then
      tail -n +$((seen+1)) "$EVENTS" 2>/dev/null | "$JQ" -r --arg g "$GLD" --arg gr "$GRN" --arg rd "$RED" --arg r "$R" '
        (if .ev=="pre" then "\($g)>>\($r)" elif .err then "\($rd)!!\($r)" else "\($gr)<<\($r)" end) as $t
        | "\($t) \(.tool|.[0:12]) \((.dur // "")|tostring)  \(.subject|.[0:90])"'
      seen=$n
    fi
    sleep 0.4
  done
}

case "$MODE" in
  top) show_top; exit 0 ;;
  last) inspect last; exit 0 ;;
  id) inspect "${2:-}"; exit 0 ;;
  follow) follow; exit 0 ;;
esac

# ---------------- live dashboard ----------------
cleanup() { printf '\033[?25h\033[?1049l'; }
trap cleanup EXIT INT TERM
printf '\033[?1049h\033[?25l'

frame=0
BASE=$(baseline); base_at=$(date +%s)

while true; do
  nowsec=$(date +%s)
  if [ $((nowsec - base_at)) -ge 5 ]; then BASE=$(baseline); base_at=$nowsec; fi
  NOW=$(now_ms)
  cols=$(tput cols 2>/dev/null || echo 120); [ "$cols" -lt 80 ] && cols=80
  subw=$((cols - BARW - 34)); [ "$subw" -lt 16 ] && subw=16

  out=""
  out+="$B$WHT CmdPulse$R $D· live tool-call telemetry · $(date +%H:%M:%S)$R"$'\n'
  line=""; for ((i=0;i<cols-1;i++)); do line+="─"; done
  out+="$GRY$line$R"$'\n'

  nact=$(ls "$ACTIVE"/*.json 2>/dev/null | wc -l | tr -d ' ')
  ndone=$("$JQ" -s -r 'map(select(.ev=="post"))|length' "$EVENTS" 2>/dev/null || echo 0)
  nfail=$("$JQ" -s -r 'map(select(.ev=="post" and .err))|length' "$EVENTS" 2>/dev/null || echo 0)
  fc="$R"; [ "${nfail:-0}" -gt 0 ] && fc="$RED"
  out+=" ${D}running$R $GLD$nact$R   ${D}completed$R $ndone   ${D}failures$R $fc$nfail$R"$'\n\n'

  out+=" $CYN▎RUNNING$R"$'\n'
  if [ "${nact:-0}" -eq 0 ]; then
    out+="   $D(idle — no tool call in flight)$R"$'\n'
  else
    for af in "$ACTIVE"/*.json; do
      [ -f "$af" ] || continue
      IFS=$'\t' read -r atool asig asub astart < <("$JQ" -r '[.tool,.sig,.subject,.start]|@tsv' "$af" 2>/dev/null)
      [ -n "${astart:-}" ] || continue
      el=$(( NOW - astart ))
      med=$(printf '%s' "$BASE" | "$JQ" -r --arg s "$asig" '.[$s].median // 0' 2>/dev/null)
      n=$(printf '%s' "$BASE" | "$JQ" -r --arg s "$asig" '.[$s].n // 0' 2>/dev/null)
      med=${med%%.*}; n=${n%%.*}
      spin="${SPIN[$((frame % 10))]}"
      if [ "${n:-0}" -lt 2 ] || [ "${med:-0}" -le 0 ]; then
        bstr=$(bar 0 1 "$frame" "$VIO"); lbl="$D  ETA?$R"
      else
        pct=$(( el * 100 / med ))
        col="$VIO"; [ "$pct" -ge 80 ] && col="$GLD"; [ "$pct" -ge 100 ] && col="$RED"
        bstr=$(bar "$pct" 0 "$frame" "$col")
        if [ "$pct" -ge 100 ]; then lbl="$RED over $R"; else lbl=$(printf '%s%4d%%%s' "$VIO" "$pct" "$R"); fi
      fi
      out+="   $GLD$spin$R $(printf '%-11s' "${atool:0:11}") $bstr $lbl $(fmt_dur "$el")  $(trunc "$asub" "$subw")"$'\n'
      if [ "${n:-0}" -ge 2 ] && [ "${med:-0}" -gt 0 ]; then
        out+="      $D baseline median $(fmt_dur "$med") over $n runs$R"$'\n'
      fi
    done
  fi

  out+=$'\n'" $CYN▎RECENT$R"$'\n'
  if [ -s "$EVENTS" ]; then
    while IFS=$'\t' read -r etool edur eerr ebytes esub; do
      [ -n "${etool:-}" ] || continue
      mark="$GRN✓$R"; [ "$eerr" = "true" ] && mark="$RED✗$R"
      rate=""
      if [ "${edur:-0}" -gt 0 ] && [ "${ebytes:-0}" -gt 0 ]; then
        rate="$(fmt_bytes $(( ebytes * 1000 / edur )))/s"
      fi
      out+="   $mark $(printf '%-11s' "${etool:0:11}") $D$(fmt_dur "$edur")$R $(printf '%9s' "$rate")  $(trunc "$esub" "$subw")"$'\n'
    done < <("$JQ" -s -r 'map(select(.ev=="post"))|reverse|.[:12]|.[]|[.tool,(.dur//0),(.err//false),(.bytes//0),.subject]|@tsv' "$EVENTS" 2>/dev/null)
  fi

  out+=$'\n'"$GRY$line$R"$'\n'
  out+="$D q$R quit   $D t$R top   $D i$R inspect last   $D w$R web dashboard"$'\n'

  printf '\033[H%s\033[0J' "$out"

  if read -rsn1 -t 0.1 key 2>/dev/null; then
    case "$key" in
      q) break ;;
      t) printf '\033[?1049l'; show_top; read -rsn1 -p "press any key "; printf '\033[?1049h' ;;
      i) printf '\033[?1049l'; inspect last; read -rsn1 -p "press any key "; printf '\033[?1049h' ;;
      w) bash "$ROOT/cmdpulse-web.sh" --once >/dev/null 2>&1 && printf '\033[?1049l' && echo "dashboard: $ROOT/dashboard.html" && read -rsn1 -p "press any key " && printf '\033[?1049h' ;;
    esac
  fi
  frame=$((frame+1))
done
