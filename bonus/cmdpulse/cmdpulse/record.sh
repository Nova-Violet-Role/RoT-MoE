#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# ~/.claude/cmdpulse/record.sh
# CmdPulse recorder. Fed by the PreToolUse and PostToolUse hooks.
#
#   record.sh pre
#   record.sh post
#
# Hook stdin contract, measured from Claude Code 2.1.238:
#   common : session_id transcript_path cwd prompt_id permission_mode agent_id agent_type effort
#   pre    : hook_event_name tool_name tool_input tool_use_id
#   post   : hook_event_name tool_name tool_input tool_response tool_use_id duration_ms
#
# Contract with the harness: NEVER block a tool call, ALWAYS exit 0.
# Hot path is one jq call plus two writes. Failures land in record.error.log, loudly.

EV="${1:-pre}"

# --- Lifecycle phases: the long silences that are NOT tool calls ---------------
# Tool bars only cover PreToolUse..PostToolUse. Compaction, waiting on a permission prompt,
# and a subagent thinking between tool calls all look identical to "frozen" because no tool
# is in flight. These write a phase marker the status line renders alongside the tool bars.
# Payload fields measured from 2.1.238:
#   SubagentStart      agent_id agent_type
#   SubagentStop       agent_id agent_type agent_transcript_path last_assistant_message
#   PreCompact         trigger custom_instructions
#   PermissionRequest  tool_name tool_input permission_suggestions
#   TaskCreated        task_id task_subject task_description teammate_name team_name
#   Notification       message title notification_type
case "$EV" in
  event)
    EVNAME="${2:-}"
    # Census: one append per event, so "which hooks actually fire, and how often" is a
    # measurement rather than a guess. CMDPULSE_CENSUS=0 turns it off.
    if [ "${CMDPULSE_CENSUS:-1}" = "1" ]; then
      printf '%s\n' "$EVNAME" >>"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/cmdpulse/events-seen.log" 2>/dev/null
    fi
    # ALL 31 events can produce a bar. Three shapes:
    #   START  opens a phase that runs until its matching STOP  (a real duration)
    #   STOP   closes it
    #   FLASH  a moment, not a duration: shown briefly then expires by its own ttl
    # Anything unrecognised still exits before doing work.
    P_MODE=""; P_KIND=""; P_TTL=0
    case "$EVNAME" in
      # --- paired: genuine durations -------------------------------------------------
      PreCompact)         P_MODE=start; P_KIND=compact ;;
      PostCompact)        P_MODE=stop;  P_KIND=compact ;;
      SubagentStart)      P_MODE=start; P_KIND=agent ;;
      SubagentStop)       P_MODE=stop;  P_KIND=agent ;;
      PermissionRequest)  P_MODE=start; P_KIND=perm ;;
      PermissionDenied)   P_MODE=stop;  P_KIND=perm ;;
      TaskCreated)        P_MODE=start; P_KIND=task ;;
      TaskCompleted)      P_MODE=stop;  P_KIND=task ;;
      Elicitation)        P_MODE=start; P_KIND=ask ;;
      ElicitationResult)  P_MODE=stop;  P_KIND=ask ;;
      WorktreeCreate)     P_MODE=start; P_KIND=worktree ;;
      WorktreeRemove)     P_MODE=stop;  P_KIND=worktree ;;
      Setup)              P_MODE=start; P_KIND=setup ;;
      SessionStart)       P_MODE=reset; P_KIND=all ;;
      SessionEnd)         P_MODE=reset; P_KIND=all ;;
      # --- moments: flash briefly so they are visible, then expire --------------------
      Stop)               P_MODE=flash; P_KIND=turn;     P_TTL=4000 ;;
      StopFailure)        P_MODE=flash; P_KIND=turnfail; P_TTL=8000 ;;
      PostToolUseFailure) P_MODE=flash; P_KIND=toolfail; P_TTL=8000 ;;
      PostToolBatch)      P_MODE=flash; P_KIND=batch;    P_TTL=3000 ;;
      UserPromptSubmit)   P_MODE=flash; P_KIND=prompt;   P_TTL=3000 ;;
      UserPromptExpansion) P_MODE=flash; P_KIND=expand;  P_TTL=3000 ;;
      Notification)       P_MODE=flash; P_KIND=notify;   P_TTL=6000 ;;
      MessageDisplay)     P_MODE=flash; P_KIND=msg;      P_TTL=2000 ;;
      TeammateIdle)       P_MODE=flash; P_KIND=idle;     P_TTL=5000 ;;
      ConfigChange)       P_MODE=flash; P_KIND=config;   P_TTL=5000 ;;
      CwdChanged)         P_MODE=flash; P_KIND=cwd;      P_TTL=4000 ;;
      DirectoryAdded)     P_MODE=flash; P_KIND=dir;      P_TTL=4000 ;;
      FileChanged)        P_MODE=flash; P_KIND=file;     P_TTL=3000 ;;
      InstructionsLoaded) P_MODE=flash; P_KIND=instr;    P_TTL=4000 ;;
      *) exit 0 ;;
    esac
    ROOT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/cmdpulse"
    mkdir -p "$ROOT/phase" 2>/dev/null
    raw=$(cat)
    NOW=$(( $(date +%s) * 1000 ))
    JQE=""
    for c in jq "$HOME/scoop/shims/jq.exe" /usr/bin/jq /usr/local/bin/jq /opt/homebrew/bin/jq; do
      if command -v "$c" >/dev/null 2>&1; then JQE=$(command -v "$c"); break; fi
    done
    fld() { [ -n "$JQE" ] && printf '%s' "$raw" | "$JQE" -r "$1 // \"\"" 2>/dev/null | tr -d '\r' | head -n 1; }
    # One label per event, from the field that actually names what is happening — so a skill,
    # plugin, connector or agent is identified by NAME on screen, not by a generic "busy".
    case "$EVNAME" in
      SubagentStart)       LBL="$(fld '.agent_type')";           [ -n "$LBL" ] || LBL="subagent" ;;
      PreCompact)          LBL="compacting ($(fld '.trigger'))" ;;
      PermissionRequest)   LBL="awaiting permission: $(fld '.tool_name')" ;;
      TaskCreated)         LBL="task: $(fld '.task_subject')" ;;
      Elicitation)         LBL="awaiting your input" ;;
      WorktreeCreate)      LBL="worktree: $(fld '.worktree_path // .path')" ;;
      Setup)               LBL="setup" ;;
      Notification)        LBL="$(fld '.title // .notification_type'): $(fld '.message')" ;;
      InstructionsLoaded)  LBL="instructions loaded: $(fld '.source // .path')" ;;
      ConfigChange)        LBL="config changed: $(fld '.key // .scope')" ;;
      CwdChanged)          LBL="cwd: $(fld '.cwd // .new_cwd')" ;;
      DirectoryAdded)      LBL="dir added: $(fld '.path // .directory')" ;;
      FileChanged)         LBL="file: $(fld '.path // .file_path')" ;;
      PostToolUseFailure)  LBL="FAILED: $(fld '.tool_name')" ;;
      PostToolBatch)       LBL="tool batch" ;;
      StopFailure)         LBL="turn failed" ;;
      Stop)                LBL="turn complete" ;;
      UserPromptSubmit)    LBL="prompt received" ;;
      UserPromptExpansion) LBL="expanding prompt" ;;
      MessageDisplay)      LBL="message" ;;
      TeammateIdle)        LBL="teammate idle: $(fld '.teammate_name')" ;;
      *)                   LBL="$EVNAME" ;;
    esac
    LBL=$(printf '%s' "$LBL" | tr -d '\r\n' | cut -c1-64)
    case "$P_MODE" in
      reset) rm -f "$ROOT/phase/"*.json 2>/dev/null ;;
      stop)  rm -f "$ROOT/phase/$P_KIND.json" 2>/dev/null ;;
      start) printf '{"kind":"%s","label":"%s","t":%s,"ttl":0}\n' \
               "$P_KIND" "$LBL" "$NOW" >"$ROOT/phase/$P_KIND.json" ;;
      flash) printf '{"kind":"%s","label":"%s","t":%s,"ttl":%s}\n' \
               "$P_KIND" "$LBL" "$NOW" "$P_TTL" >"$ROOT/phase/$P_KIND.json" ;;
    esac
    exit 0 ;;
esac
ROOT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/cmdpulse"
ERRLOG="$ROOT/record.error.log"
CAP=262144   # bytes of raw payload kept per call

note() { printf '%s [%s] %s\n' "$(date -Is 2>/dev/null || echo unknown)" "$EV" "$1" >>"$ERRLOG" 2>/dev/null; }

mkdir -p "$ROOT/active" "$ROOT/runs" 2>/dev/null

input=$(cat)
[ -n "$input" ] || { note "empty stdin"; exit 0; }

JQ=""
for cand in jq "$HOME/scoop/shims/jq.exe" /usr/bin/jq /usr/local/bin/jq /opt/homebrew/bin/jq; do
  if command -v "$cand" >/dev/null 2>&1; then JQ=$(command -v "$cand"); break; fi
done
[ -n "$JQ" ] || { note "jq not found"; exit 0; }

# jq.exe on Windows writes CRLF. A trailing CR rides into the last @tsv field and makes it
# unparseable downstream, so strip it at the boundary. Assigning a function name to $JQ
# covers every existing call site.
JQBIN="$JQ"
jqlf() { "$JQBIN" "$@" | tr -d '\r'; }
JQ=jqlf

NOW_MS=$(( $(date +%s) * 1000 ))

# One jq pass: derive id, a human subject line, and the grouping signature.
# The signature is what lets the dashboard learn a duration baseline per command shape.
read_line=$(printf '%s' "$input" | "$JQ" -r --arg ev "$EV" --argjson now "$NOW_MS" '
  def clean: (. // "") | tostring | gsub("[\n\r\t]"; " ") | sub("^ +";"") | sub(" +$";"");
  def subject:
    .tool_name as $t | .tool_input as $i |
    if   $t == "Bash" or $t == "PowerShell" then ($i.command // "")
    elif $t == "Read" or $t == "Edit" or $t == "Write" or $t == "NotebookEdit" then ($i.file_path // $i.notebook_path // "")
    elif $t == "Glob"      then ($i.pattern // "")
    elif $t == "Grep"      then (($i.pattern // "") + "   " + ($i.path // ""))
    elif $t == "WebFetch"  then ($i.url // "")
    elif $t == "WebSearch" then ($i.query // "")
    elif $t == "Agent"     then ((($i.subagent_type // "agent")) + ": " + ($i.description // ""))
    elif $t == "Skill"     then ((($i.skill // "")) + " " + ($i.args // ""))
    else
      # Generic fallback. Every remaining tool still needs a readable line, so take the
      # first meaningful scalar the input actually carries rather than dumping raw JSON.
      ( [ $i.command, $i.description, $i.prompt, $i.query, $i.url, $i.pattern,
          $i.notebook_path, $i.file_path, $i.path, $i.message, $i.text, $i.name,
          $i.skill, $i.to, $i.method, $i.action, $i.reason, $i.task_id, $i.id,
          $i.shell_id, $i.bash_id, $i.cron ]
        | map(select(type == "string" and length > 0)) | .[0] )
      // ( $i | if type == "object" and (keys | length) > 0
               then (keys_unsorted | join(" ")) else "" end )
    end | clean
    # Tools that genuinely take no input (CronList, ListAgents, ExitPlanMode) still need a
    # label, otherwise the bar renders a nameless row.
    | if length == 0 then ($t // "") else . end;
  def signature:
    .tool_name as $t |
    if $t == "Bash" or $t == "PowerShell"
    then $t + ":" + ((subject | split(" ") | map(select(startswith("-") | not)) | .[0:2] | join(" ")))
    else ($t // "Unknown") end;
  ( .tool_use_id // ("noid-" + ((now*1000)|floor|tostring)) ) as $id |
  [ $id,
    ( { id: $id, ev: $ev, t: $now,
        tool: (.tool_name // "Unknown"),
        sig: signature,
        subject: (subject | if (.|length) > 400 then .[0:400] + "…" else . end),
        cwd: (.cwd // ""), agent: (.agent_type // ""), pmode: (.permission_mode // ""),
        session: (.session_id // "") }
      + (if $ev == "pre" then { start: $now } else
          { dur: (.duration_ms // -1),
            bytes: ((.tool_response // {}) | tostring | length),
            code: ((.tool_response.exit_code // .tool_response.exitCode // .tool_response.returnCode) // null),
            err:  (((.tool_response.is_error // .tool_response.isError // .tool_response.interrupted) // false)
                   or (((.tool_response.exit_code // .tool_response.exitCode // 0) | tonumber? // 0) != 0)) }
        end)
      | tojson )
  ] | .[]
' 2>>"$ERRLOG")

if [ -z "$read_line" ]; then note "jq produced nothing"; exit 0; fi

# Line 1 is the id, line 2 is the compact JSON record. NOT @tsv: @tsv escapes backslashes,
# which doubles every "\" inside the embedded JSON and corrupts any record carrying a
# Windows path or a quoted string. Compact JSON never contains a newline, so this is safe.
id=$(printf '%s\n' "$read_line" | head -n 1 | tr -cd 'A-Za-z0-9_.-')
rec=$(printf '%s\n' "$read_line" | tail -n +2)
[ -n "$id" ] || id="noid"

if [ "$EV" = "pre" ]; then
  printf '%s\n' "$rec" >"$ROOT/active/$id.json" 2>/dev/null

  # --- Optional: stream the command's own output so the bar can show live progress ---
  # PreToolUse may return `updatedInput` (documented PreToolUse-only in 2.1.238), so we can
  # rewrite a Bash command to tee itself into a log the status line tails.
  #
  # The exit code is the danger: `cmd | tee` yields TEE's status, turning a failed build into
  # a green one. `exit ${PIPESTATUS[0]}` restores the real status — verified against a command
  # exiting 101 (naive form returned 0, this form returned 101). Never remove it.
  # Off unless CMDPULSE_STREAM=1, and only ever applied to Bash.
  if [ "${CMDPULSE_STREAM:-0}" = "1" ]; then
    s_tool=$(printf '%s' "$input" | "$JQ" -r '.tool_name // ""' 2>/dev/null)
    if [ "$s_tool" = "Bash" ]; then
      s_cmd=$(printf '%s' "$input" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null)
      if [ -n "$s_cmd" ]; then
        mkdir -p "$ROOT/stream" 2>/dev/null
        s_log="$ROOT/stream/$id.log"
        # A leading newline before the closing brace keeps a trailing comment in the original
        # command from swallowing the rest of the wrapper.
        s_wrapped="{ $s_cmd
} 2>&1 | tee -a '$s_log'; exit \${PIPESTATUS[0]}"
        printf '%s' "$input" | "$JQ" -c --arg w "$s_wrapped" \
          '{hookSpecificOutput:{hookEventName:"PreToolUse",
            updatedInput:(.tool_input + {command:$w})}}' 2>/dev/null
      fi
    fi
  fi
  printf '%s' "$input" | head -c "$CAP" >"$ROOT/runs/$id.pre.json" 2>/dev/null
else
  rm -f "$ROOT/active/$id.json" 2>/dev/null
  printf '%s' "$input" | head -c "$CAP" >"$ROOT/runs/$id.post.json" 2>/dev/null
  # Afterglow. The status line can only redraw once per second (Math.max(1,t)*1000 is a
  # hard floor in Claude Code), but most tool calls finish in well under that, so a live-only
  # bar is invisible for the common case. Parking the finished call here lets the status line
  # show it for a few seconds afterwards — every command becomes visible, not just slow ones.
  printf '%s\n' "$rec" >"$ROOT/last.json" 2>/dev/null
  # Rolling history: the last N completed calls, so the bar can show what just happened
  # instead of a single row. Kept as its own small file — the status line must never read
  # the full ledger at render time.
  printf '%s\n' "$rec" >>"$ROOT/recent.ndjson" 2>/dev/null
  if [ "$(wc -l <"$ROOT/recent.ndjson" 2>/dev/null || echo 0)" -gt 40 ]; then
    tail -n 16 "$ROOT/recent.ndjson" >"$ROOT/recent.tmp" 2>/dev/null && mv "$ROOT/recent.tmp" "$ROOT/recent.ndjson" 2>/dev/null
  fi
  # Precomputed sig -> median map. The WezTerm status bar redraws several times a second and
  # cannot afford to slurp the ledger itself, so the cost is paid once here, per completed
  # call, over a bounded tail of the ledger.
  tail -n 2000 "$ROOT/events.ndjson" 2>/dev/null | "$JQ" -s -c '
    map(select(.ev=="post" and (.dur // -1) >= 0))
    | group_by(.sig)
    | map({ key: .[0].sig,
            value: ((map(.dur)|sort) as $v | ($v|length) as $n |
              { n: $n,
                median: (if $n % 2 == 1 then $v[($n/2|floor)] else (($v[$n/2-1]+$v[$n/2])/2) end) }) })
    | from_entries' >"$ROOT/baseline.json.tmp" 2>/dev/null \
    && mv "$ROOT/baseline.json.tmp" "$ROOT/baseline.json" 2>/dev/null
fi

# Append-only ledger. Retention is the dashboard's job so this stays O(1).
printf '%s\n' "$rec" >>"$ROOT/events.ndjson" 2>/dev/null

exit 0
