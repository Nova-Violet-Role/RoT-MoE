# CmdPulse — How To Reproduce On Your Own Claude Code

A live per-tool-call progress bar rendered **inside Claude Code's own status line**, plus a
local HTML inspector for the full input/output of every call.

Nothing here phones home. Everything is a local file.

---

## 0. What you are installing

| file | goes to | role |
|---|---|---|
| `statusline.sh` | `~/.claude/statusline.sh` | draws the status line + the command bars |
| `cmdpulse/record.sh` | `~/.claude/cmdpulse/record.sh` | hook recorder, writes the ledger |
| `cmdpulse/cmdpulse.sh` | `~/.claude/cmdpulse/cmdpulse.sh` | terminal dashboard (second pane) |
| `cmdpulse/cmdpulse-web.sh` | `~/.claude/cmdpulse/cmdpulse-web.sh` | HTML inspector generator |
| `settings-snippet.json` | merge into `~/.claude/settings.json` | wires the three above |

---

## 1. Requirements

- **Claude Code 2.1.238 or newer.** The status line contract used here (`context_window`,
  `rate_limits`, `effort`, `refreshInterval`) was read out of the 2.1.238 binary. Older
  builds may not send every field — the script degrades rather than breaking, but the
  `refreshInterval` key is what makes the bars live, and that is the part to check first.
- **bash** — Linux/macOS have it; on Windows use the bash that ships with Git
  (`C:\Program Files\Git\bin\bash.exe`).
- **jq** — `apt install jq` / `brew install jq` / `scoop install jq`.
  Verify with `jq --version`; the scripts also probe common absolute paths if it is not on PATH.

Quick check:

```bash
bash --version | head -1
jq --version
claude --version
```

---

## 2. Install

```bash
mkdir -p ~/.claude/cmdpulse
cp statusline.sh              ~/.claude/statusline.sh
cp cmdpulse/record.sh         ~/.claude/cmdpulse/record.sh
cp cmdpulse/cmdpulse.sh       ~/.claude/cmdpulse/cmdpulse.sh
cp cmdpulse/cmdpulse-web.sh   ~/.claude/cmdpulse/cmdpulse-web.sh
chmod +x ~/.claude/statusline.sh ~/.claude/cmdpulse/*.sh
```

Or run `bash install.sh`, which does the copy **and** the settings merge in step 3.

---

## 3. Wire it into settings.json

Three keys. Merge them into `~/.claude/settings.json` — **do not replace the file**, it holds
the rest of your configuration.

### Linux / macOS

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh",
    "refreshInterval": 3
  },
  "hooks": {
    "PreToolUse":  [{ "matcher": "*", "hooks": [
      { "type": "command", "command": "bash ~/.claude/cmdpulse/record.sh pre",  "timeout": 10000 } ] }],
    "PostToolUse": [{ "matcher": "*", "hooks": [
      { "type": "command", "command": "bash ~/.claude/cmdpulse/record.sh post", "timeout": 10000 } ] }]
  }
}
```

### Windows

`~` does not expand under `cmd.exe`, and a `.sh` file is not directly executable. Use an
absolute path to Git's `bash.exe` with absolute script paths — this form works whether the
host runs the command through `cmd.exe` or through a POSIX shell:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"C:\\Program Files\\Git\\bin\\bash.exe\" \"C:/Users/YOU/.claude/statusline.sh\"",
    "refreshInterval": 3
  },
  "hooks": {
    "PreToolUse":  [{ "matcher": "*", "hooks": [
      { "type": "command", "command": "\"C:\\Program Files\\Git\\bin\\bash.exe\" \"C:/Users/YOU/.claude/cmdpulse/record.sh\" pre",  "timeout": 10000 } ] }],
    "PostToolUse": [{ "matcher": "*", "hooks": [
      { "type": "command", "command": "\"C:\\Program Files\\Git\\bin\\bash.exe\" \"C:/Users/YOU/.claude/cmdpulse/record.sh\" post", "timeout": 10000 } ] }]
  }
}
```

Replace `YOU` with your username. Backslashes for the executable, forward slashes for the
script arguments.

**If you already have PreToolUse/PostToolUse hooks**, append to the existing arrays instead
of overwriting them:

```bash
jq '.hooks.PreToolUse[0].hooks  += [{type:"command", command:"bash ~/.claude/cmdpulse/record.sh pre",  timeout:10000}]
  | .hooks.PostToolUse[0].hooks += [{type:"command", command:"bash ~/.claude/cmdpulse/record.sh post", timeout:10000}]' \
  ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
```

Always back up first: `cp ~/.claude/settings.json ~/.claude/settings.json.bak`

---

## 4. Verify it works

**No restart is needed** — Claude Code re-reads `settings.json` live.

Run any command in Claude Code, then:

```bash
# a) the recorder is capturing
wc -l ~/.claude/cmdpulse/events.ndjson

# b) every line is valid JSON (this is the check that catches a broken install)
while IFS= read -r l; do printf '%s' "$l" | jq -e . >/dev/null || echo "BAD: $l"; done \
  < ~/.claude/cmdpulse/events.ndjson

# c) the status line renders — feed it a fake payload
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/tmp"},
"context_window":{"total_input_tokens":5000,"context_window_size":200000,"used_percentage":2.5},
"cost":{"total_cost_usd":0}}' | bash ~/.claude/statusline.sh
```

(c) must print a line containing a bar like `█░░░░░░░░░ 3%`. If it prints
`[statusline: jq not found]` or `[statusline: jq parse failed]`, that is the script telling
you exactly what is wrong — it never fails silently. Details land in
`~/.claude/statusline.error.log` and `~/.claude/cmdpulse/record.error.log`.

To see a bar appear for a call in flight:

```bash
# simulate a running tool, then render
echo '{"cwd":"/tmp","tool_name":"Bash","tool_use_id":"toolu_TEST",
"tool_input":{"command":"sleep 30"}}' | bash ~/.claude/cmdpulse/record.sh pre
# ...render the status line as in (c); a row for Bash appears above it
rm -f ~/.claude/cmdpulse/active/*.json     # clean up
```

---

## 5. Known limits

- **The status line renders only when Claude Code is idle**, and a render slower than
  `refreshInterval` is aborted by the next one. `refreshInterval` is in *seconds*, floor 1
  (`Math.max(1,t)*1000` in the binary). Ship default is **3**; see README before lowering.
- **Fast tools cannot be caught in flight.** Read ~66ms, Write ~24ms, Edit ~111ms. Only
  Bash-class calls run long enough. Everything else is shown by its completed-call row —
  and every tool is recorded regardless.
- **Hook cost ~285ms per hook** (bash + jq startup), so ~570ms per tool call. Cheaper on
  Linux/macOS.
- **`runs/` grows two files per tool call** and is not auto-pruned:
  `find ~/.claude/cmdpulse/runs -type f -mtime +7 -delete`

---

## 6. Uninstall

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq 'del(.statusLine)
  | .hooks.PreToolUse[0].hooks  |= map(select(.command | test("cmdpulse") | not))
  | .hooks.PostToolUse[0].hooks |= map(select(.command | test("cmdpulse") | not))' \
  ~/.claude/settings.json.bak > ~/.claude/settings.json
rm -rf ~/.claude/cmdpulse ~/.claude/statusline.sh
```

---

## 7. Privacy note before you share further

`~/.claude/cmdpulse/` records **every command you run and its output**, in
`events.ndjson` and `runs/`. This package deliberately ships neither. If you hand this
directory to anyone else, delete those first.

---

## 8. Update — what changed since first release

- **`refreshInterval` is now `3`, not `1`.** A render slower than the interval is aborted by
  the next one, blanking the status line completely. On Windows a render costs ~1.3–2.5s
  (~75 subprocess spawns at ~14ms each). Measure yours before lowering it; see README.
- **All 31 hook events are wired**, not just `PreToolUse`/`PostToolUse`. `install.sh` does
  this for you. Paired events (compaction, permission, subagent, task, elicitation, worktree)
  render a running bar; instant events flash briefly and expire.
- **Live output streaming** via `CMDPULSE_STREAM=1` — rewrites Bash commands through
  `updatedInput` so they tee to a log the bar tails. Exit codes preserved via
  `exit ${PIPESTATUS[0]}`, verified against a command exiting 101.
- **The completed-call row persists** until the next call replaces it, instead of expiring
  after 6s. `CMDPULSE_AFTERGLOW_EXPIRE=1` restores the old behaviour.
- **`wezterm-cmdpulse.lua`** included for WezTerm's own status bar at 200ms.
