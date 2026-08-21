-- ~/.claude/cmdpulse/wezterm-cmdpulse.lua
-- CmdPulse live bar in WezTerm's own status bar.
--
-- Why this exists: Claude Code's status line cannot show a live bar. Its scheduler debounces
-- execution by 300ms and resets that debounce on every input change (`iz0=300`, `#b()` in
-- 2.1.238), so during a tool call the status line command is never actually run — measured at
-- 0 invocations across a 12-second call. WezTerm's status bar redraws on its OWN timer and is
-- completely independent of Claude Code, so it can animate while a tool is running.
--
-- Wire it from ~/.wezterm.lua, before `return config`:
--     require('cmdpulse')            -- if on the lua path, or:
--     dofile(wezterm.home_dir .. '/.claude/cmdpulse/wezterm-cmdpulse.lua')(config)
--
-- Reads only:  ~/.claude/cmdpulse/active/*.json   (written at PreToolUse)
--              ~/.claude/cmdpulse/baseline.json   (sig -> median, written at PostToolUse)
--              ~/.claude/cmdpulse/last.json       (the afterglow)

local wezterm = require 'wezterm'

local VIOLET, GOLD, GREY = '#b464ff', '#ffd700', '#808080'
local RED, GREEN, DIM = '#ff5f5f', '#78dc8c', '#5a5468'
local FULL, EMPTY = '▰', '▱'
local SPIN = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

-- wezterm.home_dir on Windows is "C:\Users\you" (backslashes). Mixing separators makes the
-- glob silently return nothing, which renders as "only the afterglow ever shows".
local HOME = tostring(wezterm.home_dir):gsub('\\', '/')
local ROOT = ((os.getenv('CLAUDE_CONFIG_DIR') or (HOME .. '/.claude')):gsub('\\', '/')) .. '/cmdpulse'
local BAR_W = 22

-- Set CMDPULSE_LUA_DEBUG=1 to have every frame append what it actually saw.
local DEBUG = os.getenv('CMDPULSE_LUA_DEBUG') ~= '0'
local function dbg(msg)
  if not DEBUG then return end
  local f = io.open(ROOT .. '/wezterm-debug.log', 'a')
  if f then f:write(tostring(msg) .. '\n'); f:close() end
end

-- Glob is the fragile part on Windows, so try the forward-slash form, then the native form.
local function list_active()
  local out = {}
  local pats = { ROOT .. '/active/*.json', (ROOT .. '/active/*.json'):gsub('/', '\\') }
  for _, p in ipairs(pats) do
    local ok, files = pcall(wezterm.glob, p)
    if ok and files and #files > 0 then
      dbg('glob HIT  ' .. p .. '  n=' .. #files)
      return files
    end
    dbg('glob MISS ' .. p)
  end
  return out
end

local function read_file(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  if s == nil or s == '' then return nil end
  return s
end

local function read_json(path)
  local s = read_file(path)
  if not s then return nil end
  local ok, v = pcall(wezterm.json_parse, s)
  if ok then return v end
  return nil
end

local function now_ms()
  -- wezterm.time.now() is monotonic-ish; os.time() is seconds. Use os.clock-independent wall time.
  return math.floor(os.time() * 1000)
end

local function fmt_dur(ms)
  if ms < 1000 then return string.format('%dms', ms) end
  if ms < 60000 then return string.format('%.1fs', ms / 1000) end
  return string.format('%dm%02ds', math.floor(ms / 60000), math.floor((ms % 60000) / 1000))
end

-- Build one bar. pct nil => indeterminate sweep driven by elapsed time.
local function bar_cells(pct, elapsed, colour)
  local cells = {}
  if pct == nil then
    local period = BAR_W * 2
    local pos = math.floor(elapsed / 150) % period
    if pos >= BAR_W then pos = period - pos - 1 end
    for i = 0, BAR_W - 1 do
      if math.abs(i - pos) <= 1 then
        table.insert(cells, { Foreground = { Color = VIOLET } })
        table.insert(cells, { Text = FULL })
      else
        table.insert(cells, { Foreground = { Color = DIM } })
        table.insert(cells, { Text = EMPTY })
      end
    end
    return cells
  end
  local fill = math.floor(math.max(0, math.min(1, pct)) * BAR_W + 0.5)
  for i = 1, BAR_W do
    if i <= fill then
      table.insert(cells, { Foreground = { Color = colour } })
      table.insert(cells, { Text = FULL })
    else
      table.insert(cells, { Foreground = { Color = DIM } })
      table.insert(cells, { Text = EMPTY })
    end
  end
  return cells
end

local function build_status()
  local cells = {}
  local baseline = read_json(ROOT .. '/baseline.json') or {}
  local now = now_ms()
  local any = false

  -- Every in-flight tool call, newest first.
  local actives = {}
  for _, path in ipairs(list_active()) do
    local a = read_json(path)
    if a and a.start then
      table.insert(actives, a)
    else
      dbg('unreadable or no .start: ' .. tostring(path))
    end
  end
  dbg('frame actives=' .. #actives)
  table.sort(actives, function(x, y) return (x.start or 0) > (y.start or 0) end)

  for _, a in ipairs(actives) do
    any = true
    local elapsed = now - (a.start or now)
    if elapsed < 0 then elapsed = 0 end
    local b = baseline[a.sig or '']
    local pct, colour, label
    if b and (b.n or 0) >= 2 and (b.median or 0) > 0 then
      local p = elapsed / b.median
      pct = p
      if p >= 1.0 then colour, label = RED, 'over'
      elseif p >= 0.8 then colour, label = GOLD, string.format('%d%%', math.floor(p * 100))
      else colour, label = VIOLET, string.format('%d%%', math.floor(p * 100)) end
    else
      pct, colour, label = nil, VIOLET, '···'
    end

    local spin = SPIN[(math.floor(elapsed / 120) % #SPIN) + 1]
    table.insert(cells, { Foreground = { Color = GOLD } })
    table.insert(cells, { Text = ' ' .. spin .. ' ' })
    table.insert(cells, { Foreground = { Color = '#ffffff' } })
    table.insert(cells, { Attribute = { Intensity = 'Bold' } })
    table.insert(cells, { Text = string.format('%-10s', (a.tool or '?'):sub(1, 10)) })
    table.insert(cells, { Attribute = { Intensity = 'Normal' } })
    for _, c in ipairs(bar_cells(pct, elapsed, colour)) do table.insert(cells, c) end
    table.insert(cells, { Foreground = { Color = colour } })
    table.insert(cells, { Text = string.format(' %5s ', label) })
    table.insert(cells, { Foreground = { Color = GREY } })
    table.insert(cells, { Text = fmt_dur(elapsed) .. '  ' .. tostring(a.subject or ''):sub(1, 40) .. ' ' })
  end

  -- Nothing running: hold the last finished call briefly so fast tools are still visible.
  if not any then
    local l = read_json(ROOT .. '/last.json')
    if l and l.t then
      local age = now - l.t
      if age >= 0 and age <= 6000 then
        local ok = not l.err
        local colour = ok and GREEN or RED
        table.insert(cells, { Foreground = { Color = colour } })
        table.insert(cells, { Text = ' ' .. (ok and '✓' or '✗') .. ' ' })
        table.insert(cells, { Foreground = { Color = '#ffffff' } })
        table.insert(cells, { Text = string.format('%-10s', (l.tool or '?'):sub(1, 10)) })
        for _, c in ipairs(bar_cells(1.0, 0, colour)) do table.insert(cells, c) end
        table.insert(cells, { Foreground = { Color = colour } })
        table.insert(cells, { Text = '  done ' })
        table.insert(cells, { Foreground = { Color = GREY } })
        table.insert(cells, { Text = fmt_dur(l.dur or 0) .. '  ' .. tostring(l.subject or ''):sub(1, 40) .. ' ' })
      end
    end
  end

  return cells
end

return function(config)
  -- 200ms: five redraws a second, on WezTerm's clock, regardless of what Claude Code is doing.
  config.status_update_interval = 100

  wezterm.on('update-status', function(window, _pane)
    local ok, cells = pcall(build_status)
    if not ok or cells == nil or #cells == 0 then
      window:set_right_status('')
      return
    end
    window:set_right_status(wezterm.format(cells))
  end)

  return config
end
