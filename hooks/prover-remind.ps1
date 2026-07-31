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
$Ws        = Get-EnvOr 'ROTMOE_LEAN_WORKSPACE' (Join-Path $Here '../lean')
$ProofsDir = Join-Path $Ws 'Proofs'
$WatchRepo = Get-EnvOr 'ROTMOE_WATCH_REPO' '.'
$StateDir  = Get-EnvOr 'ROTMOE_STATE_DIR' (Join-Path $env:USERPROFILE '.local/state/rot-moe')
$GoalFile  = Get-EnvOr 'ROTMOE_GOAL_FILE' ''
$StaleMin  = [int](Get-EnvOr 'ROTMOE_PROOF_STALE_MIN' '45')
$DebtExt   = (Get-EnvOr 'ROTMOE_DEBT_EXT' 'rs c h cpp hpp go ts js py java kt swift') -split '\s+'
$RiskRe    = Get-EnvOr 'ROTMOE_DEBT_PATTERN' 'as u8|as u16|as u32|as i8|as i16|as i32|as usize|saturating_|wrapping_|checked_|\.clamp\(|\.max\(|\.min\(|<<|>>|MAX_|MIN_|_CAP|_FLOOR|_LIMIT'

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

  if ($nr -gt 0) {
    $out = "$out KERNEL REJECTED $nr module(s): $(Join-FirstN $r 4). leanchecker disagrees with lake build -- those theorems are NOT proved. Fix before anything else."
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
  if ($thr -gt 0 -and (Test-Path -LiteralPath $stamp)) {
    try {
      $age = ((Get-Date).ToUniversalTime() - (Get-Item -LiteralPath $stamp).LastWriteTimeUtc).TotalMinutes
      if ($age -lt $thr) { exit 0 }
    } catch { }
  }

  # 1. minutes since the most recent proof, and its name
  $mins = -1; $last = '-'
  try {
    $p = Get-ChildItem -LiteralPath $ProofsDir -Filter '*.lean' -ErrorAction Stop |
         Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($p) {
      $mins = [int]((Get-Date).ToUniversalTime() - $p.LastWriteTimeUtc).TotalMinutes
      $last = $p.BaseName
    }
  } catch { }

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
      if ($v.red)        { $kred   = @($v.red | ForEach-Object { $_.module }) }
      if ($v.sorryFiles) { $ksorry = @($v.sorryFiles) }
    }
  } catch { }

  $ctx = Invoke-Decide -Event $ev -Mins $mins -Last $last `
           -Debt (($debtFiles -join ',')) -KRed (($kred -join ',')) `
           -KSorry (($ksorry -join ',')) -Alarms $alarms
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
