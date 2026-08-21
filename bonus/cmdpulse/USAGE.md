# CmdPulse — What Each Part Does, Step By Step

Four pieces. You only ever *run* two of them by hand; the other two are driven by Claude Code.

```
  record.sh        (automatic)  hooks fire on every tool call, write the ledger
  statusline.sh    (automatic)  draws the bars + status line inside Claude Code
  cmdpulse.sh      (you run)    terminal dashboard in a second pane
  cmdpulse-web.sh  (you run)    HTML inspector — full input/output, copyable
```

---

## 1. The bars inside Claude Code

Nothing to run. Once installed, every tool call gets a row **above** the status line:

```
⠇ WebFetch     ░░░░░███░░  ···    1s https://example.com/docs
⠇ Read         ██████████ over    1s /home/you/.claude/settings.json
⠇ Bash         ███░░░░░░░  36%    1s git status --porcelain
██████░░░░ 61% | [Opus 5 (1M context)] xhigh ✻ | my-project | ⧉ Inspect
```

One row per **concurrently running** tool. Columns: spinner, tool name, bar, progress, elapsed,
and what it is actually doing.

### Reading the progress figure

| you see | it means |
|---|---|
| `36%` | 36% of the **median time this exact command shape usually takes on your machine** |
| `over` | already past its usual time — this is your "is it stuck?" signal |
| `···` with a sweeping bar | fewer than 2 past runs recorded, so no honest estimate exists yet |

The percentage is an **ETA against learned history**, not bytes-done. Real progress cannot be
known for an arbitrary command, so the script never invents a number it cannot justify — a
command it has not seen twice gets a sweep, not a fake percentage.

Estimates improve as you work. `Bash:git status` becomes accurate after a handful of runs.

### Finished calls (the afterglow)

The status line can only redraw once per second, but most tool calls finish in 50–200ms. So
each finished call is held on screen for 6 seconds:

```
✓ Edit         ██████████ done  53ms src/main.rs
✗ Bash         ██████████ done 210ms cargo build --release
```

Green ✓ succeeded, red ✗ failed, with the real duration. **Without this, fast commands would
be completely invisible** — they begin and end between two redraws.

### Tuning

| variable | default | effect |
|---|---|---|
| `CMDPULSE_BAR_WIDTH` | `10` | cells per bar |
| `CMDPULSE_AFTERGLOW_MS` | `6000` | how long a finished call stays |
| `STATUSLINE_MAX_WIDTH` | `190` | soft cap before the line drops lower-value segments |
| `STATUSLINE_NO_GIT` | unset | set to `1` to skip git probes (faster in huge repos) |
| `STATUSLINE_ASCII` | unset | set to `1` if your font lacks the block/braille glyphs |
| `STATUSLINE_DEBUG` | unset | set to `1` to dump the raw payload for inspection |

---

## 2. The status line itself

Everything after the bars, left to right:

```
██████░░░░ 61% RC | [Opus 5 (1M context)] xhigh ✻ ⚡ !200k | my-project  main* | 433k/1.0M tok | 5h 41% . 7d 12% | $3.42 ~15m | +120/-8 | ⧉ Inspect
```

| segment | meaning |
|---|---|
| `██████░░░░ 61%` | context window used — violet under 50%, gold 50–80%, grey 80–90%, red above |
| `RC` | your rolling-context trigger has been crossed; history is being compressed upstream |
| `[model]` | active model |
| `xhigh` | reasoning effort |
| `✻` / `⚡` | extended thinking on / fast mode on |
| `!200k` | context has exceeded 200k tokens |
| `my-project  main*` | directory and git branch (`*` dirty, `+` staged) |
| `433k/1.0M tok` | tokens used of the window |
| `5h 41% . 7d 12%` | subscription rate limits — grey, gold above 70%, red above 90% |
| `$3.42 ~15m` | session cost and elapsed |
| `+120/-8` | lines added/removed this session |
| `⧉ Inspect` | opens the HTML dashboard (see §4) |

Segments drop from the right as the line gets long, so the bars and context never get pushed
off screen.

---

## 3. Terminal dashboard — `cmdpulse.sh`

Run it in a **second pane**. It takes over that screen and never touches Claude Code.

```bash
bash ~/.claude/cmdpulse/cmdpulse.sh
```

```
 CmdPulse · live tool-call telemetry · 14:22:07
 ────────────────────────────────────────────────
 running 1   completed 214   failures 3

 ▎RUNNING
   ⠹ Bash   ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱  61%   2.9s  cargo build --release
      baseline median   4.8s over 12 runs

 ▎RECENT
   ✓ Edit    ▰▰▰▱▱▱▱▱▱▱▱▱   53ms            src/main.rs
   ✗ Bash    ▰▰▰▰▰▰▰▰▰▰▰▰  18.4s   1.2K/s   cargo build --release
```

Keys: `q` quit · `t` where-the-time-goes · `i` inspect last call · `w` regenerate the web page.

Other modes:

```bash
bash ~/.claude/cmdpulse/cmdpulse.sh top          # slowest / most frequent / failure counts
bash ~/.claude/cmdpulse/cmdpulse.sh last         # full detail of the most recent call
bash ~/.claude/cmdpulse/cmdpulse.sh id toolu_01A # full detail of one call (prefix is fine)
bash ~/.claude/cmdpulse/cmdpulse.sh follow       # one line per event, pipe-friendly
```

`top` is the one worth knowing:

```
  SIGNATURE                     CALLS   MEDIAN      P95  SLOWEST   FAIL     TOTAL
  Bash:cargo build                 12     4.8s    18.4s    18.4s      1     1m04s
  Bash:git status                  47     2.9s     3.5s     4.1s      0     2m16s
  Edit                             36     7.5ms     12ms     31ms      0     270ms
```

That answers "where is my time actually going" with your own numbers.

---

## 4. HTML inspector — `cmdpulse-web.sh`

The full-detail view. Everything selectable and copyable.

```bash
bash ~/.claude/cmdpulse/cmdpulse-web.sh
```

Writes `~/.claude/cmdpulse/dashboard.html`, opens it once, then regenerates every 2s while it
runs. `Ctrl+C` to stop. One-shot instead: `bash cmdpulse-web.sh --once` prints the path.

Click any row to expand:

- **INPUT** — the complete tool input as JSON, with a copy button
- **OUTPUT** — the complete response (capped at 256KB), with a copy button
- **files touched** — pulled from `file_path`/`path`/`notebook_path` and from paths detected
  inside Bash commands; each chip is click-to-select
- cwd, agent, permission mode, duration vs median, output size, throughput, exit code, `tool_use_id`

Top controls: live search across command text **and output text**, a failures-only toggle, and
a stats table. Open rows, your filter and scroll position survive the refresh.

---

## 5. Where things live

```
~/.claude/statusline.sh                  the status line + bars
~/.claude/statusline.error.log           why the status line failed, if it ever does
~/.claude/cmdpulse/
    record.sh cmdpulse.sh cmdpulse-web.sh
    events.ndjson        one JSON line per event (the ledger)
    active/<id>.json     exists only while that call is running
    last.json            the most recent finished call (drives the afterglow)
    runs/<id>.pre.json   full input payload
    runs/<id>.post.json  full response payload
    dashboard.html       generated page
    record.error.log     recorder failures
```

`events.ndjson` is plain NDJSON — query it directly:

```bash
# the ten slowest calls ever
jq -s 'map(select(.ev=="post")) | sort_by(-.dur) | .[:10] | .[] | "\(.dur)ms \(.tool) \(.subject)"' \
  -r ~/.claude/cmdpulse/events.ndjson

# everything that failed today
jq -r 'select(.ev=="post" and .err) | "\(.tool) \(.subject)"' ~/.claude/cmdpulse/events.ndjson
```

---

## 6. Troubleshooting

**No bars at all.** Check the status line renders standalone first:
```bash
echo '{"model":{"display_name":"T"},"workspace":{"current_dir":"/tmp"},
"context_window":{"total_input_tokens":5000,"context_window_size":200000,"used_percentage":2.5},
"cost":{"total_cost_usd":0}}' | bash ~/.claude/statusline.sh
```
If that prints a bar but Claude Code shows nothing, the `statusLine` key is not wired.

**Bars appear but the status line vanished.** Your Claude Code is drawing only the first line.
Multi-line output is what the script emits; if your build draws only the first line, reduce
the rows instead: `CMDPULSE_BAR_WIDTH` smaller, or unset `CMDPULSE_STREAM` so the output line is
not added. There is no inline mode.

**Only one tool type shows up.** Confirm the hook matcher is `*`, not a tool name:
```bash
jq '.hooks.PreToolUse[] | {matcher, n: (.hooks|length)}' ~/.claude/settings.json
```

**Percentages never appear, only `···`.** That signature has fewer than 2 recorded runs. It is
working as designed — use it more, or check the ledger parses:
```bash
jq -s 'length' ~/.claude/cmdpulse/events.ndjson
```
If that errors, one line is corrupt; filter it out:
```bash
cd ~/.claude/cmdpulse && while IFS= read -r l; do printf '%s' "$l" | jq -e . >/dev/null 2>&1 \
  && printf '%s\n' "$l"; done < events.ndjson > clean && mv clean events.ndjson
```

**Everything feels slower.** Each hook costs ~285ms (bash + jq startup), so ~570ms per tool
call. Drop to PostToolUse only — you lose the live bar but keep the afterglow and all history.

**Disk growth.** `runs/` gains two files per call:
```bash
find ~/.claude/cmdpulse/runs -type f -mtime +7 -delete
```

---

## 7. Before sharing this directory

`events.ndjson` and `runs/` contain **every command you ran and its full output**. Delete them
before handing the folder to anyone.

---

## 8. Phase rows — what is happening when no tool is running

Tool bars cover `PreToolUse` → `PostToolUse` only. These rows cover the rest:

```
◈ agent      ░░░░░███░░  wait   2s  lean4-prover
◈ compact    ░░░░░███░░  wait  14s  compacting (auto)
◈ perm       ██░░░░░░░░  wait   8s  awaiting permission: Bash
◈ notify     ░░░░░███░░  wait   1s  Plugin: rot-moe loaded
◈ toolfail   ██░░░░░░░░  wait   3s  FAILED: Bash
```

`perm` is the important one: the machine is not stuck, it is waiting on **you**.

The bar sweeps rather than filling, because a phase has no learned duration — a permission
prompt waits on a human. Colours: gold = waiting on you, violet = compaction, cyan = subagent.

Paired events run until their stop event. Instant events (`Stop`, `Notification`,
`FileChanged`, `MessageDisplay`, …) carry a ttl and reap themselves after 2–8s.

Every row is **named** — the skill, plugin, agent or file is identified, not shown as a
generic "busy".

## 9. Live output streaming

```bash
export CMDPULSE_STREAM=1
```

```
⠸ Bash   ██████░░░░  61%  2m14s  cargo test --release
    └ [  5/20] seed 0004: 145832  (mean: 152340.2, 3.1s/seed)
```

Bash commands are rewritten to tee into `~/.claude/cmdpulse/stream/<id>.log`, which the bar
tails. **Exit codes are preserved** by `exit ${PIPESTATUS[0]}` — a naive `cmd | tee` reports
tee's status and turns a failed build green. If you change the wrapper, re-run this test:

```bash
bash -c '{ bash -c "exit 101"; } 2>&1 | tee -a /tmp/t.log; exit ${PIPESTATUS[0]}'; echo $?
# must print 101
```

## 10. Performance — the thing that breaks it

A render slower than `refreshInterval` is **aborted by the next render**, so the status line
goes blank. Symptoms look identical to "the tool is broken".

```bash
time (echo '{"model":{"display_name":"T"},"workspace":{"current_dir":"/tmp"},
"context_window":{"total_input_tokens":5000,"context_window_size":200000,
"used_percentage":2.5},"cost":{"total_cost_usd":0}}' | bash ~/.claude/statusline.sh)
```

Keep `refreshInterval` comfortably above that. Measured on Windows: ~1.3s idle, ~2.5s with
several phases, because each subprocess spawn costs ~14ms and a render makes ~75.
`STATUSLINE_NO_GIT=1` removes four of them.
