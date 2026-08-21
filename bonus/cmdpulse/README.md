# CmdPulse — BONUS Release

> *"for everyone tired about waiting for the next update — I made something everyone was
> searching for, because it is far easier than what I'm working on.*
>
> *It took me about 1 hour to produce that, a function everyone was searching for, easy…
> imagine what the router is capable of after 2 weeks…"*

A live progress bar for **every** Claude Code tool call, rendered inside Claude Code's own
status line. It answers the one question the UI never answers:

**Is it still working, or is it stuck?**

```
⠸ Bash         ██████░░░░  61%   2m14s  cargo test --release
    └ [  5/20] seed 0004: 145832  (mean: 152340.2, 3.1s/seed)
◈ phase        ···                  8s  awaiting permission: Bash
██████░░░░ 47% | [Opus 5 (1M context)] xhigh ✻ | my-project  main* | ⧉ Inspect
```

Everything is local. Nothing is uploaded. No dependencies beyond `bash` and `jq`.

---

## In the wild

A real frame, captured mid-session — two commands in flight, three finished, one phase row:

```
⠿ Bash    ▌▌░░░░░░░░    ···      0s  ETA ?      REPO="/c/GIT External Repo/RoT MoE" echo "=== RELEASE.md hea…
⠿ Bash    ▌▌░░░░░░░░    12%     47s  ETA 5m36s  cd "C:/GIT External Repo/RoT MoE" echo "=== the .lua file(s)…
✓ Bash    ██████████   done    5.9s  @07:50:47  set -u REPO="/c/GIT External Repo/RoT MoE" git -C "$…
✓ Bash    ██████████   done   1m36s  @07:50:34  cd "C:/GIT External Repo/RoT MoE" echo "=== 1. SPDX…
✓ Bash    ██████████   done   619ms  @07:50:19  set -u REPO="/c/GIT External Repo/RoT MoE" P="/c/Use…
◈ msg     ░░░▓▓░░░░░   wait      1s  message
```

Reading it top to bottom: the first command is brand new, so it honestly reports `ETA ?`
rather than guessing. The second has history — 47 seconds elapsed, **5m36s** predicted
remaining, 12% of its learned median. Three completed calls hold their real durations and
start clocks. The `◈ msg` row is a lifecycle event, not a tool call.

<!-- Drop a PNG at docs/cmdpulse-live.png and uncomment to show the coloured original:
![CmdPulse running](docs/cmdpulse-live.png)
-->

---

## What it shows

| element | meaning |
|---|---|
| `██████░░░░ 61%` | how far through the **learned median time for this exact command shape** |
| `over` (red) | already past its usual time — the honest "this might be stuck" signal |
| `···` sweeping | fewer than 2 past runs, so no honest estimate exists yet |
| `2m14s` | live elapsed, readable to hours |
| `└ [ 5/20] seed 0004…` | the command's **own stdout**, streamed live (opt-in) |
| `◈ phase` | compaction, a pending permission prompt, or a subagent running |
| `✓` / `✗` | finished call, with true duration and start clock |
| `⧉ Inspect` | opens the full HTML dashboard |

The percentage is an **ETA against history this machine actually recorded** — never a fake
byte count. A command CmdPulse has not seen twice gets a sweeping bar and the label `···`,
because inventing a number would be worse than admitting there isn't one.

---

## Why the phase rows matter most

Tool bars only cover `PreToolUse` → `PostToolUse`. Three things happen *outside* that window
and look identical to a freeze:

- **context compaction** — long, silent
- **a permission prompt** — the machine is waiting on *you*
- **a subagent thinking** between its own tool calls

CmdPulse wires all **31** Claude Code hook events and renders these as `◈ phase` rows. Nine
carry meaning; the other 22 return immediately so they cost nothing.

---

## Install

```bash
bash install.sh
```

Copies four scripts to `~/.claude/`, backs up `settings.json`, and merges the config —
**appending** to any hooks you already have rather than overwriting them. No restart needed;
Claude Code re-reads `settings.json` live.

Requires `bash` and `jq`. On Windows use Git's bash (`C:\Program Files\Git\bin\bash.exe`);
the installer detects the platform and writes the correct command form.

Manual install and the Windows/POSIX settings forms are in **REPRODUCE.md**.
Every feature, flag and troubleshooting step is in **USAGE.md**.

---

## The one number that matters: `refreshInterval`

```json
"statusLine": { "type": "command", "command": "...", "refreshInterval": 3 }
```

**Do not lower this to 1 without reading USAGE.md §Performance.**

Claude Code re-runs the status line on a timer, and **each new run aborts the previous one
still executing** (`#_(){ this.#s?.abort() }`). On Windows a full render costs ~1.3s, because
a shell script pays ~14ms per subprocess spawn and this one makes ~75. At `refreshInterval: 1`
every render is aborted before it finishes and **the status line goes completely blank** —
which looks exactly like the tool being broken. At `3` each render completes.

On Linux/macOS spawns are far cheaper and `1` is usually fine. Measure before changing it:

```bash
time (echo '{"model":{"display_name":"T"},"workspace":{"current_dir":"/tmp"},
"context_window":{"total_input_tokens":5000,"context_window_size":200000,
"used_percentage":2.5},"cost":{"total_cost_usd":0}}' | bash ~/.claude/statusline.sh)
```

Keep `refreshInterval` comfortably above that number.

---

## Live output streaming (opt-in)

```bash
export CMDPULSE_STREAM=1
```

Rewrites Bash commands via the `updatedInput` field of `PreToolUse` so they tee their output
to a log the bar tails. Your script's own progress lines then appear under the bar, live.

**Exit codes are preserved** — the wrapper ends with `exit ${PIPESTATUS[0]}`. This is not
cosmetic: a naive `cmd | tee` yields *tee's* exit status, silently turning a failed build
green. Verified against a command exiting 101 (naive form returned 0; shipped form returns
101; a succeeding command still returns 0). If you modify the wrapper, re-run that test.

Off by default, and only ever applied to `Bash`.

---

## The other two surfaces

```bash
bash ~/.claude/cmdpulse/cmdpulse.sh        # live dashboard, 200ms, own clock
bash ~/.claude/cmdpulse/cmdpulse.sh top    # where your time actually goes
bash ~/.claude/cmdpulse/cmdpulse-web.sh    # HTML inspector: full input/output, copyable
```

`cmdpulse.sh` in a split pane is the only surface that can animate a bar **while a fast
command runs** — it owns its own clock instead of waiting for Claude Code to be idle.

`wezterm-cmdpulse.lua` is included for WezTerm users: same bar in WezTerm's status bar at
200ms. Inert on other terminals.

---

## Honest limits

- **Fast tools can't be caught live.** `Read` averages 66ms, `Write` 24ms, `Edit` 111ms. The
  status line needs a 300ms quiet gap plus the render time, so only `Bash`-class calls are
  caught in flight. Everything else is shown by the completed-call row instead — and
  everything is recorded either way.
- **The completed bar's fill is a replay**, not live progress. Duration, start time and
  outcome are true measurements; the animation is reconstructed across the afterglow window.
  `CMDPULSE_REPLAY=0` disables it.
- **Hook cost** is ~285ms per hook on Windows (bash + jq startup), so ~570ms per tool call.
  Meaningfully cheaper on Linux/macOS.
- **`runs/` grows** two files per tool call and is not auto-pruned:
  `find ~/.claude/cmdpulse/runs -type f -mtime +7 -delete`

---

## Privacy

`~/.claude/cmdpulse/` records **every command you run and its output** in `events.ndjson`,
`runs/` and (if streaming is on) `stream/`. This package ships none of that. Delete those
directories before sharing your own copy.

---

## Uninstall

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq 'del(.statusLine)
  | .hooks |= with_entries(.value |= map(.hooks |= map(select((.command // "")
      | test("cmdpulse") | not))))' ~/.claude/settings.json.bak > ~/.claude/settings.json
rm -rf ~/.claude/cmdpulse ~/.claude/statusline.sh
```

---

Licensed under the same terms as the rest of this repository.

---

## ETA

```
⠸ Bash  ██░░░░░░░░  20%   4s  ETA 16s  cargo build --release
⠋ Bash  ██████░░░░  60%  12s  ETA 8s   cargo build --release
⠇ Bash  ██████████ over  25s           cargo build --release
```

`ETA` is the learned median minus elapsed, shown **only** when that command signature has at
least 2 recorded runs. Fewer than that and you get `ETA ?` with a sweeping bar — the estimate
does not exist yet, and inventing one would be worse than saying so.

## Rolling history

`CMDPULSE_ROWS` (default 3, max 12) shows the last N completed calls stacked above the status
line, each with mark, duration and start clock — so a burst of fast tools stays visible
instead of each overwriting the last.

## Refresh rate — what is actually achievable

| surface | interval | why |
|---|---|---|
| Claude Code status line | **1s floor**, ships at 3 | `Math.max(1,t)*1000` in the binary; sub-second is not configurable, and a render slower than the interval is aborted, blanking the line |
| `cmdpulse.sh` split pane | **100ms** | owns its own clock, independent of the host |
| WezTerm status bar | **100ms** | same |

A status-line render currently costs ~1.0–1.7s on Windows (~75 subprocess spawns at ~14ms
each). Reaching 100ms there would need roughly an 11× speedup — a single-jq rewrite of the
render path, not a config change. Until then, the split pane is the fast surface.
