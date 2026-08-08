# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# prover-remind.ps1 -- ORGAN 4 of the packet, Windows arm: the proof-debt
# reminder.
#
# This is the SAME reminder as hooks/prover-remind.sh, and "same" is mechanical:
# checker/cross-diff-remind.sh runs both over one corpus in --decide mode and
# requires BYTE-IDENTICAL output on every row. A shared bug would have to be
# written twice, in two languages, by hand.
#
# The full rationale -- why a constant doctrine string became wallpaper, why
# silence is the healthy state, why the kernel verdict outranks everything --
# is in the POSIX arm's header and is not duplicated here, because two copies
# of a paragraph drift and only one of them gets corrected.
#
# NEVER THROWS, ALWAYS EXITS 0 in hook mode. A reminder that breaks a session is
# worse than no reminder. `-Decide` may exit 2 on a usage error: a checker
# calling it wrongly must not silently pass.
# =============================================================================

[CmdletBinding()]
param(
  [switch] $Decide,
  # -Measure / -Workspace: the MEASUREMENT half of the contract, at parity with
  # the POSIX arm's --measure / --workspace. -Decide made the DECISION
  # cross-armable and the checker states outright that what it does not cover is
  # "that both arms measure the same things off disk". That uncovered half is
  # exactly where the one-level proof scan lived, in both arms at once, while
  # every gate stayed green.
  [switch] $Measure,
  [switch] $Workspace,
  [switch] $Version,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $Rest
)

$ErrorActionPreference = 'Stop'

if ($Version) { Write-Output 'prover-remind.ps1 1.0.0'; exit 0 }

# --- CONFIG ------------------------------------------------------------------
function Get-EnvOr([string] $Name, [string] $Default) {
  $v = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($v)) { return $Default } else { return $v }
}
$Here      = Split-Path -Parent $MyInvocation.MyCommand.Path
# WHERE THE USER'S OWN PROOFS LIVE -- which is NOT where ours live. The POSIX
# arm carries the full rationale; the chain is identical and deliberately so:
# an explicit environment variable beats a recorded install, and a recorded
# install beats our own shipped corpus. Defaulting to the bundled lean/ folder
# pointed every measurement at a READ-ONLY corpus that can never acquire debt.
# THE MIRROR OF A BUG THIS FILE'S SIBLING ALREADY DOCUMENTS, and it was found by
# checker/remind-measure.sh on its very first run.
#
# prover-remind.sh normalises backslashes on READ because the PowerShell
# installer naturally writes `<drive>:\path\Lean`. The reverse direction was
# never handled: SETUP_LEAN.sh's `record_workspace` writes `$_ws` verbatim, and
# under Git Bash on Windows that is a POSIX drive path, `/<letter>/...`, and
# `Test-Path -LiteralPath` REFUSES that spelling on Windows -- so this function
# good recorded workspace and fell through -- the recorded step was dead in this
# arm for every user who ran the POSIX installer, which on Windows is most of
# them. Silently: no error, just the wrong tree measured forever.
#
# The literal path is tried FIRST and the drive-letter reading only as a
# fallback, which is what makes this safe on Linux -- there `/<letter>/...` is an
# ordinary absolute path and must win. Preferring what EXISTS over what a rule
# says should exist is the only version that cannot break the other platform.
function Resolve-RecordedPath([string] $v) {
  if ([string]::IsNullOrWhiteSpace($v)) { return '' }
  $v = $v -replace '\\', '/'
  if (Test-Path -LiteralPath $v) { return $v }
  if ($v -match '^/([A-Za-z])/(.*)$') {
    $win = $Matches[1].ToUpperInvariant() + ':/' + $Matches[2]
    if (Test-Path -LiteralPath $win) { return $win }
  }
  return ''
}
function Get-RecordedWorkspace {
  try {
    $sd = Get-EnvOr 'ROTMOE_STATE_DIR' (Join-Path (Get-HomeDir) '.local/state/rot-moe')
    $f  = Join-Path $sd 'workspace'
    if (Test-Path -LiteralPath $f) {
      $v = (Get-Content -LiteralPath $f -TotalCount 1 -ErrorAction Stop).Trim()
      $r = Resolve-RecordedPath $v
      if ($r) { return $r }
    }
  } catch { }
  return ''
}
$WatchRepo = Get-EnvOr 'ROTMOE_WATCH_REPO' '.'
# HOME, ON EVERY PLATFORM POWERSHELL RUNS ON.
#
# MEASURED ON ubuntu-latest, 2026-08-01: this line read
#   Join-Path $env:USERPROFILE '.local/state/rot-moe'
# and USERPROFILE does not exist outside Windows. `Join-Path` REFUSES a null
# Path -- "Cannot bind argument to parameter 'Path' because it is null" -- and
# the script died at CONFIG time, before parsing an argument. Every one of the
# 23 corpus rows reported "the Windows arm exited 1" on Linux, while the POSIX
# arm (which uses $HOME) was fine. PowerShell Core is cross-platform; a hook
# that assumes Windows because it is written in PowerShell is the same category
# of mistake as assuming a shell script means Linux.
#
# Reproducible on Windows without a Linux box, which is how it was fixed here:
#   env -u USERPROFILE pwsh -NoProfile -File hooks/prover-remind.ps1 -Decide ...
function Get-HomeDir {
  foreach ($n in 'USERPROFILE', 'HOME') {
    $v = [Environment]::GetEnvironmentVariable($n)
    if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
  }
  # Last resort: .NET's own idea of it. Never null, so Join-Path cannot throw.
  $p = [Environment]::GetFolderPath('UserProfile')
  if ([string]::IsNullOrWhiteSpace($p)) { return '.' } else { return $p }
}

# RESOLVED HERE, BELOW Get-HomeDir, AND THE ORDER IS LOAD-BEARING. PowerShell
# executes a script top to bottom, so a function is not callable above its own
# definition. The first draft of this put the resolution at line 58 while
# Get-RecordedWorkspace calls Get-HomeDir, defined at 77 -- the call threw
# CommandNotFoundException, my own try/catch swallowed it, and the workspace
# SILENTLY fell back to the bundled corpus. That is worse than a crash: the
# feature would have been dead in exactly the case it exists for, with every
# gate green. Resolution stays below every function it depends on.
#
# DISCOVERY -- cross-arm parity with prover-remind.sh's `_ws_discover`, and it is
# called out because the first attempt at this fix added discovery to the POSIX
# arm ONLY. Two arms that resolve the workspace differently are two products: a
# Windows user would keep getting "no proof written for 2907 minutes" from a
# corpus nobody works in while a Linux user got the right answer, and no
# cross-diff would see it, because --decide takes the measurements as arguments
# and never resolves a workspace at all.
#
# The chain env -> RECORDED -> bundled corpus has a hole: nothing in the plugin
# install path writes the recorded file, so the middle step is permanently empty
# for a marketplace install. Discovery asks the filesystem instead. Both layouts
# are accepted -- the workspace itself, and a project keeping Lean in a `lean/`
# subdirectory, which is this repository's own shape.
function Test-LeanWorkspace([string] $d) {
  if ([string]::IsNullOrWhiteSpace($d)) { return $false }
  if (-not (Test-Path -LiteralPath (Join-Path $d 'Proofs'))) { return $false }
  return (Test-Path -LiteralPath (Join-Path $d 'lakefile.toml')) -or
         (Test-Path -LiteralPath (Join-Path $d 'lakefile.lean'))
}
function Get-DiscoveredWorkspace {
  try {
    $d = Get-EnvOr 'ROTMOE_CWD' (Get-Location).Path
    for ($n = 0; $n -lt 8 -and $d; $n++) {
      if (Test-LeanWorkspace $d)                    { return $d }
      if (Test-LeanWorkspace (Join-Path $d 'lean')) { return (Join-Path $d 'lean') }
      $p = Split-Path -Parent $d
      if (-not $p -or $p -eq $d) { break }
      $d = $p
    }
  } catch { }
  return ''
}
$Ws = $env:ROTMOE_LEAN_WORKSPACE
if (-not $Ws) { $Ws = Get-RecordedWorkspace }
if (-not $Ws) { $Ws = Get-DiscoveredWorkspace }
if (-not $Ws) { $Ws = Join-Path $Here '../lean' }
$ProofsDir = Join-Path $Ws 'Proofs'
$StateDir  = Get-EnvOr 'ROTMOE_STATE_DIR' (Join-Path (Get-HomeDir) '.local/state/rot-moe')
$GoalFile  = Get-EnvOr 'ROTMOE_GOAL_FILE' ''
$StaleMin  = [int](Get-EnvOr 'ROTMOE_PROOF_STALE_MIN' '45')
$DebtExt   = (Get-EnvOr 'ROTMOE_DEBT_EXT' 'rs c h cpp hpp go ts js py java kt swift') -split '\s+'
$RiskRe    = Get-EnvOr 'ROTMOE_DEBT_PATTERN' 'as u8|as u16|as u32|as i8|as i16|as i32|as usize|saturating_|wrapping_|checked_|\.clamp\(|\.max\(|\.min\(|<<|>>|MAX_|MIN_|_CAP|_FLOOR|_LIMIT'

# --- THE PROOF SCAN, IN ONE PLACE --------------------------------------------
# Hook mode and -Measure must not each carry their own copy of this. A second
# copy is how one of them would keep a defect the other had fixed -- which is
# precisely the history here: the one-level scan survived because the only thing
# that ever exercised the measurement was hook mode, and nothing compared it to
# anything. One function, two callers, and the checker drives the exported one.
function Get-ProofScan {
  $r = [pscustomobject]@{ Count = 0; Mins = -1; Last = '-' }
  try {
    $all = @(Get-ChildItem -LiteralPath $ProofsDir -Filter '*.lean' -Recurse -ErrorAction Stop)
    $r.Count = $all.Count
    $p = $all | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($p) {
      $r.Mins = [int]((Get-Date).ToUniversalTime() - $p.LastWriteTimeUtc).TotalMinutes
      $r.Last = $p.BaseName
    }
  } catch { }
  return $r
}

if ($Measure) {
  $s = Get-ProofScan
  Write-Output ('' + $s.Count + ' ' + $s.Mins + ' ' + $s.Last)
  exit 0
}
if ($Workspace) {
  # WHICH STEP OF THE CHAIN ANSWERED. Four steps, and the middle one was empty
  # for every marketplace install until discovery was added; being able to ask
  # turns that diagnosis into one command.
  $src = 'bundled'
  if ($env:ROTMOE_LEAN_WORKSPACE)   { $src = 'env' }
  elseif (Get-RecordedWorkspace)    { $src = 'recorded' }
  elseif (Get-DiscoveredWorkspace)  { $src = 'discovered' }
  Write-Output ($src + ' ' + $Ws)
  exit 0
}

# --- DECIDE ------------------------------------------------------------------
# A PURE function of measured inputs, mirroring the POSIX `decide()` clause for
# clause and word for word. Field order is the contract: preamble, kernel,
# sorry, debt, staleness, alarms, method.
function Split-Csv([string] $S) {
  if ([string]::IsNullOrEmpty($S) -or $S -eq '-') { return @() }
  return @($S -split ',' | Where-Object { $_ -match '\S' })
}
function Join-FirstN([string[]] $Items, [int] $N) {
  return (($Items | Select-Object -First $N) -join ',')
}

function Invoke-Decide {
  param([string] $Event, [int] $Mins, [string] $Last, [string] $Debt,
        [string] $KRed, [string] $KSorry, [int] $Alarms)

  if ($Last -eq '-') { $Last = '' }
  $d = Split-Csv $Debt; $r = Split-Csv $KRed; $s = Split-Csv $KSorry
  $nd = @($d).Count; $nr = @($r).Count; $ns = @($s).Count

  # SILENCE. The kernel conditions are ANDed in deliberately: a rejected proof
  # term or a stray `sorry` breaks silence no matter how fresh the last proof is.
  if ($nd -eq 0 -and $Mins -ge 0 -and $Mins -lt $StaleMin -and $nr -eq 0 -and $ns -eq 0) {
    return $null
  }

  switch ($Event) {
    'PreToolUse' {
      $out = 'BEFORE YOU ACT: this is the one moment a proof obligation can change the action rather than judge it. If what you are about to do touches a bound, a cast or a clamp, decide NOW whether it needs a theorem -- deciding afterwards is how debt accumulates.'
    }
    'UserPromptSubmit' {
      $out = 'THE SOCIO JUST SPOKE -- re-read the goal before assuming it is unchanged. Carry the standing proof debt into whatever was just asked; a new instruction does not retire an open obligation.'
    }
    default {
      $out = 'RESULT IS IN -- attribute it. A green build is elaboration, not truth; bind the measurement to a theorem or say plainly that it is MEASURED, not PROVED.'
    }
  }

  # Split the watchdog's red list into modules the kernel actually REJECTED and
  # modules whose re-check never finished (trailing `?`, written by the reader
  # below). A timeout reported as a rejection is a false accusation; measured
  # 2026-08-09 on four modules that all verify at exit 0 with zero bytes.
  # This must stay byte-identical in wording to the POSIX arm --
  # checker/cross-diff-remind.sh diffs the two on every corpus row.
  $rejList = @(); $unfList = @()
  foreach ($t in $r) {
    if ([string]::IsNullOrEmpty($t)) { continue }
    if ($t.EndsWith('?')) { $unfList += $t.Substring(0, $t.Length - 1) }
    else                  { $rejList += $t }
  }
  $nrej = $rejList.Count; $nunf = $unfList.Count

  if ($nrej -gt 0) {
    $out = "$out KERNEL REJECTED $nrej module(s): $(Join-FirstN $rejList 4). leanchecker disagrees with lake build -- those theorems are NOT proved. Fix before anything else."
  }
  if ($nunf -gt 0) {
    $out = "$out KERNEL RE-CHECK DID NOT FINISH for $nunf module(s): $(Join-FirstN $unfList 4). A TIMEOUT IS NOT A REJECTION and it is not a pass either -- the question was never answered. Re-run lake env leanchecker on those modules with a longer bound before believing anything about them."
  }
  if ($ns -gt 0) {
    $out = "$out SORRY PRESENT in: $(Join-FirstN $s 4). A sorry is an admission, never a result -- report it with a count."
  }
  if ($nd -gt 0) {
    $more = ''
    if ($nd -gt 4) { $more = " (+$($nd - 4) more)" }
    $out = "$out LEAN DEBT: $nd uncommitted source file(s) carry cast/clamp/saturating/bound code -- $(Join-FirstN $d 4)$more."
    $out = "$out For EACH: state in writing what must hold for ALL inputs, then PROVE it or say plainly there is no universal claim."
  }
  if ($Mins -ge $StaleMin) {
    $out = "$out No proof written for $Mins min (last: $Last)."
  } elseif ($Mins -lt 0) {
    $out = "$out No .lean proofs found in the configured workspace -- verify ROTMOE_LEAN_WORKSPACE before assuming none exist."
  }
  if ($Alarms -gt 0) {
    $out = "$out $Alarms alarm row(s) open in the goal file; an alarm closes ONLY with instrument + negative control."
  }
  $out = "$out Close a proof with THREE instruments: lake build (exit code read DIRECTLY, never through a pipe) -> #print axioms (sorryAx = NOT proved; no axioms at all is usually vacuous) -> lake env leanchecker <Module> (kernel recheck; exit 0 with ZERO bytes = pass, a module with no oleans exits 1 = the control). Then MUTATE, delete the stale .olean, rebuild, confirm the theorems DIE. Zero sorry. Never native_decide. A test SAMPLES; a theorem SETTLES."

  # ASCII guard at the single exit point: a non-ASCII byte under a legacy code
  # page can terminate the JSON string early and kill the injection silently.
  return ($out -replace '[^\x20-\x7E]', ' ')
}

# --- deterministic mode ------------------------------------------------------
if ($Decide) {
  if (@($Rest).Count -ne 7) {
    [Console]::Error.WriteLine('usage: prover-remind.ps1 -Decide EVENT MINS LASTPROOF DEBT KRED KSORRY ALARMS')
    exit 2
  }
  $ctx = Invoke-Decide -Event $Rest[0] -Mins ([int]$Rest[1]) -Last $Rest[2] `
                       -Debt $Rest[3] -KRed $Rest[4] -KSorry $Rest[5] -Alarms ([int]$Rest[6])
  if ($null -ne $ctx) { [Console]::Out.Write($ctx); [Console]::Out.Write("`n") }
  exit 0
}

# --- MEASURE + HOOK MODE -----------------------------------------------------
# =============================================================================
# THE HOOK INVOKES LEAN -- WHEN LEAN WORK HAS JUST HAPPENED, AND ONLY THEN.
# The POSIX arm carries the full rationale and the measurements; this is its
# mirror, and checker/cross-diff-remind.sh exists to keep the two honest.
#
# Measured: router 176 ms · one module no-op 1206 ms · one module edited
# 1287 ms · whole corpus 4850 ms. Building on every prompt and every tool call
# would cost a fifty-call session one to four MINUTES for verdicts that barely
# change. Building on the turn a .lean file is written costs 1.2 s and cannot be
# talked out of its answer.
#
# Silent -- never broken -- when lake is absent, when the build cannot be
# bounded, or when ROTMOE_LEAN_VERIFY=0. An optional dependency that breaks the
# hook when missing is not optional.
function Invoke-LeanVerify {
  param($Payload)
  if (-not $Payload) { return '' }
  if ((Get-EnvOr 'ROTMOE_LEAN_VERIFY' '1') -eq '0') { return '' }
  if (-not (Get-Command lake -ErrorAction SilentlyContinue)) { return '' }

  $fp = ''
  try {
    $ti = $Payload.tool_input
    if ($ti) {
      if ($ti.file_path) { $fp = [string]$ti.file_path }
      elseif ($ti.path)  { $fp = [string]$ti.path }
    }
  } catch { }
  if (-not $fp) { return '' }
  if (-not $fp.EndsWith('.lean')) { return '' }

  $wsAbs = ''
  try { $wsAbs = (Resolve-Path -LiteralPath $Ws -ErrorAction Stop).Path } catch { return '' }
  $norm = $fp -replace '\\', '/'
  $wsn  = $wsAbs -replace '\\', '/'
  $rel  = ''
  if ($norm.StartsWith($wsn + '/')) { $rel = $norm.Substring($wsn.Length + 1) }
  elseif ($norm -match '/lean/(.+)$') { $rel = $Matches[1] }
  else { return '' }
  $mod = ($rel -replace '\.lean$', '') -replace '/', '.'
  if (-not $mod) { return '' }

  $secs = [int](Get-EnvOr 'ROTMOE_LEAN_VERIFY_SECS' '300')
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $job = Start-Job -ScriptBlock {
    param($w, $m)
    Set-Location -LiteralPath $w
    $out = & lake build $m 2>&1 | Out-String
    [pscustomobject]@{ Out = $out; Code = $LASTEXITCODE }
  } -ArgumentList $wsAbs, $mod

  if (-not (Wait-Job $job -Timeout $secs)) {
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return "LEAN TIMED OUT: $mod did not finish in ${secs}s. NOT proved -- a build you killed is not a verdict."
  }
  $res = Receive-Job $job
  Remove-Job $job -Force -ErrorAction SilentlyContinue
  $sw.Stop()
  $ms = [int]$sw.ElapsedMilliseconds
  $code = 0; $out = ''
  if ($res) { $code = [int]$res.Code; $out = [string]$res.Out }

  # A file may contain `sorry` and still elaborate. Reporting that as a pass is
  # the exact laundering this project exists to prevent, so it is a THIRD state.
  #
  # THIS USED TO SCAN THE FILE'S TEXT for \bsorry\b and it cried wolf: a doc
  # comment reading "no sorry, no native_decide" -- the sentence this project's
  # own discipline puts in files -- was counted as an admission. An armed
  # 50-turn session on 2026-08-03 wrote a clean module, was told twice it
  # "contains 1 sorry", and had to argue with its own tool. An alarm that fires
  # on correct work teaches people to ignore alarms.
  #
  # Ask the ELABORATOR instead; it knows a term from a word in a comment.
  # Measured both ways on Lean 4.33.0-rc1:
  #   a real `by sorry`        -> exit 0 AND "declaration uses `sorry`"
  #   `sorry` only in comments -> exit 0 and ZERO such warnings (text scan: 2)
  # Counting the warning is also per-DECLARATION, which is the honest unit.
  $sry = 0
  try {
    $sry = @(($out -split "`n") | Where-Object { $_ -match 'declaration uses .sorry.' }).Count
  } catch { $sry = 0 }

  if ($code -ne 0) {
    $err = ''
    try { $err = (($out -split "`n") | Where-Object { $_ -match 'error:' } | Select-Object -First 1) } catch { }
    if ($err) { $err = $err.Trim(); if ($err.Length -gt 200) { $err = $err.Substring(0, 200) } }
    else { $err = '<no error line captured>' }
    return "LEAN REFUSED: $mod does NOT build (lake build exit $code, ${ms}ms). First error: $err -- this is not proved. Fix it before the code is called delivered."
  }
  if ($sry -gt 0) {
    return "LEAN INCOMPLETE: $mod builds (exit 0, ${ms}ms) but contains $sry sorry. A sorry is an ADMISSION, not a proof -- the module is not done."
  }
  return "LEAN VERIFIED: $mod builds, lake build exit 0 in ${ms}ms, zero sorry. Elaboration is not truth -- close it with #print axioms (sorryAx = not proved) and lake env leanchecker $mod."
}

# Everything below is wrapped so the contract holds: never throw, always exit 0.
try {
  # DISCOVER the invoking event from the hook payload on stdin. IsInputRedirected
  # guards a manual run: reading stdin unconditionally BLOCKS FOREVER when
  # nothing is piped, which would hang the tool that invoked us.
  $ev = 'PostToolUse'
  try {
    if ([Console]::IsInputRedirected) {
      $raw = [Console]::In.ReadToEnd()
      if ($raw -and $raw.Trim()) {
        $j = $raw | ConvertFrom-Json
        if ($j.hook_event_name) { $ev = [string]$j.hook_event_name }
      }
    }
  } catch { }
  $ev = ($ev -replace '[^A-Za-z0-9_-]', '')
  if (-not $ev) { $ev = 'PostToolUse' }

  # VERIFY FIRST, ADVISE SECOND -- the POSIX arm carries the reasoning.
  $leanVerdict = ''
  if ($ev -eq 'PostToolUse' -and $j) {
    try { $leanVerdict = Invoke-LeanVerify $j } catch { $leanVerdict = '' }
  }

  # Per-event throttle: independent stamps, so no lane can silence another.
  $thr = switch ($ev) {
    'UserPromptSubmit' { [int](Get-EnvOr 'ROTMOE_THROTTLE_PROMPT' '0') }
    'PreToolUse'       { [int](Get-EnvOr 'ROTMOE_THROTTLE_PRE'    '7') }
    default            { [int](Get-EnvOr 'ROTMOE_THROTTLE_POST'   '5') }
  }
  if (-not (Test-Path -LiteralPath $StateDir)) {
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
  }
  $stamp = Join-Path $StateDir "prover-remind.$ev.stamp"
  # A build verdict is never throttled: throttling exists so a tight tool loop
  # cannot spam ADVICE, and "this module does not compile" is not advice.
  if ($leanVerdict) { $thr = 0 }
  if ($thr -gt 0 -and (Test-Path -LiteralPath $stamp)) {
    try {
      $age = ((Get-Date).ToUniversalTime() - (Get-Item -LiteralPath $stamp).LastWriteTimeUtc).TotalMinutes
      if ($age -lt $thr) { exit 0 }
    } catch { }
  }

  # 1. minutes since the most recent proof, and its name
  # ONE scan function, shared with -Measure, so the thing the checker drives is
  # the thing the hook runs. -Recurse lives inside it: one level deep meant that
  # as soon as proofs were filed by subject (Proofs\Ctbrec\, ...) the newest
  # visible file was whatever last landed in the root -- measured on one tree at
  # one instant, one level -> 2947 min stale, recursive -> 54 min.
  $scan = Get-ProofScan
  $mins = $scan.Mins; $last = $scan.Last

  # 2. uncommitted source that is PROOF-SHAPED
  $debtFiles = @()
  try {
    Push-Location -LiteralPath $WatchRepo -ErrorAction Stop
    $changed = @(& git diff --name-only --diff-filter=ACM 2>$null) +
               @(& git diff --cached --name-only --diff-filter=ACM 2>$null)
    $changed = $changed | Select-Object -Unique
    foreach ($rel in $changed) {
      $ext = [IO.Path]::GetExtension($rel).TrimStart('.')
      if ($DebtExt -notcontains $ext) { continue }
      if (Test-Path -LiteralPath $rel) {
        try {
          if (Select-String -LiteralPath $rel -Pattern $RiskRe -List -ErrorAction Stop) {
            $debtFiles += (Split-Path $rel -Leaf)
          }
        } catch { }
      }
    }
    Pop-Location
  } catch { try { Pop-Location } catch { } }

  # 3. open alarm rows in the configured goal file, if any
  $alarms = 0
  try {
    if ($GoalFile -and (Test-Path -LiteralPath $GoalFile)) {
      $alarms = @(Select-String -LiteralPath $GoalFile -Pattern '^>\s*\|\s*\*{0,2}R\d+[a-z]?\*{0,2}\s*\|' -ErrorAction Stop).Count
    }
  } catch { }

  # 4. the kernel watchdog's verdict, if a status file exists
  $kred = @(); $ksorry = @()
  try {
    $vs = Join-Path $StateDir 'lean-verify-status.json'
    if (Test-Path -LiteralPath $vs) {
      $v = Get-Content -LiteralPath $vs -Raw | ConvertFrom-Json
      # Mark UNFINISHED re-checks with a trailing `?` so `Decide` can word them
      # as "did not finish" instead of "rejected". Only these two reasons are
      # demoted; an unrecognised reason keeps the full rejection alarm, because
      # the safe default for an unknown failure is to shout. Mirrors the POSIX
      # arm exactly -- cross-diff-remind.sh compares the two on every row.
      if ($v.red) {
        $kred = @($v.red | ForEach-Object {
          $m = $_.module
          $rs = if ($_.reason) { ([string]$_.reason).ToUpper() } else { '' }
          if ($rs -eq 'TIMEOUT' -or $rs -eq 'NOT_FOUND') { "$m`?" } else { $m }
        })
      }
      if ($v.sorryFiles) { $ksorry = @($v.sorryFiles) }
    }
  } catch { }

  $ctx = Invoke-Decide -Event $ev -Mins $mins -Last $last `
           -Debt (($debtFiles -join ',')) -KRed (($kred -join ',')) `
           -KSorry (($ksorry -join ',')) -Alarms $alarms
  # THE VERDICT OUTRANKS THE ADVICE. Invoke-Decide returns nothing in the common
  # case, so a build failure would otherwise be discarded on the way out because
  # the REMINDER had nothing to add. Its presence alone is enough to speak.
  if ($leanVerdict) {
    if ($ctx) { $ctx = "$leanVerdict $ctx" } else { $ctx = $leanVerdict }
  }
  if ($null -eq $ctx -or $ctx -eq '') { exit 0 }

  Set-Content -LiteralPath $stamp -Value (Get-Date -Format 'o') -Encoding ascii -ErrorAction SilentlyContinue

  # The invoking event MUST be echoed back or Claude Code discards the payload.
  $payload = [ordered]@{
    hookSpecificOutput = [ordered]@{
      hookEventName     = $ev
      additionalContext = $ctx
    }
  }
  $json = $payload | ConvertTo-Json -Compress -Depth 6
  if ($json) { [Console]::Out.Write($json) }
} catch { }

exit 0
