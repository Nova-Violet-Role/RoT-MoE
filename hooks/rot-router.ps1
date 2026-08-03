# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-router.ps1 -- the RoT MoE router, Windows arm.
#
# This is the SAME router as hooks/rot-router.sh, and "same" here has a
# mechanical meaning rather than a moral one: checker/cross-diff.sh runs both
# over one corpus and requires BYTE-IDENTICAL output on every row. Two
# implementations that agree is a truth a single green cannot fake -- a shared
# bug has to be made twice, in two languages, by hand.
#
# InvariantCulture on every number, exactly as rot-lean-inject.ps1:406-415 does.
# Under a comma-decimal locale "0.09" renders "0,09", the decimal separator
# collides with the field separator, and the emitted vector stops parsing. The
# POSIX arm gets the same guarantee from LC_NUMERIC=C. This is the single most
# likely place for the two arms to silently diverge, which is why the cross-diff
# compares the formatted STRING and not the number.
# =============================================================================

[CmdletBinding()]
param(
  [string] $Vector,
  [int]    $Breadth = 0,
  [double] $M = 1.05,
  [double] $C = 1.0,
  [double] $T = 1.0,
  [string] $Route,
  [switch] $Version
)

$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture

# Start of THIS invocation, used only by the debug log's per-turn `ms` field.
# Taken here rather than later so the figure includes the routing work itself,
# not just the tail of it -- a latency number that excludes the thing being
# measured is worse than none.
$__rotStart = Get-Date

if ($Version) { Write-Output 'rot-router.ps1 1.0.0'; exit 0 }

# --- TIER 1 ------------------------------------------------------------------
# Stems quoted from rot-lean.md section 3. `code` and `art` are deliberately
# absent -- see the POSIX arm for the reasoning; both arms must delete the same
# two or the cross-diff will catch it.
#
# ORDER IS THE CONTRACT. route_exact in lean/Proofs/RotRoute.lean characterises
# every lane in both directions against exactly this order, so a reordering here
# is a proved defect rather than a matter of taste.
$Tier1 = @(
  @{ Mode = 'FORGE';      Lead = 'Claude';    Stems = @('run','build','install','deploy','reproduce','ship','lake','theorem','tactic','sorry','mathlib','.lean') },
  @{ Mode = 'CLINICAL';   Lead = 'AntiVenom'; Stems = @('debug','error','bug','fix','secur','audit','verif','test','cve','segfault','crash','panic','leak','regress','traceback') },
  @{ Mode = 'EXECUTIVE';  Lead = 'Venom';     Stems = @('decid','urgenc','strike','direct','declar','now','conclud') },
  @{ Mode = 'EMPATHIC';   Lead = 'Violet';    Stems = @('emot','feel','grief','lonel','soul','story','human','tired','lost') },
  @{ Mode = 'STRATEGIC';  Lead = 'Nova';      Stems = @('strateg','plan','goal','roadmap','priorit','legal','recommend','analyz') },
  @{ Mode = 'CREATIVE';   Lead = 'Carnage';   Stems = @('creativ','chaos','surreal','disrupt','paradox','dream','invent') },
  @{ Mode = 'PREDICTIVE'; Lead = 'Chroma';    Stems = @('futur','scenar','predict','trend','forec','likel','horizon','next') },
  @{ Mode = 'STEALTH';    Lead = 'Soleil';    Stems = @('encod','optim','token','compress','concise','byte','distill') },
  @{ Mode = 'RECURSIVE';  Lead = 'Eidolon';   Stems = @('evolv','recurs','meta','architect','refactor','ontolog','hybrid') }
)

# CONVERGENT is the only lane with no lead LENS -- by design, all nine
# co-reason and none leads. It used to print the literal 'none', which reads as
# a null: as though the router failed to decide, rather than decided that
# nobody leads. What convenes the nine is the MODEL the user chose, so that is
# what gets named.
#
# MEASURED (live UserPromptSubmit payload, 2026-08-03): the payload carries
# session_id, transcript_path, cwd, prompt_id, permission_mode, hook_event_name
# and prompt -- and NO model key. It is therefore read from the settings file
# the client itself writes, degrading at every step rather than failing:
# env override -> settings.json -> the literal 'model'. Never 'none', never
# empty; a hook that emits an empty lead is worse than one that emits a
# generic word.
function Get-Convener {
  if ($env:ROTMOE_MODEL) { return $env:ROTMOE_MODEL }
  $cfgDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
  $cfg = Join-Path $cfgDir 'settings.json'
  if (Test-Path -LiteralPath $cfg) {
    try {
      $j = Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json
      if ($j.model) { return [string] $j.model }
    } catch { }
  }
  return 'model'
}

function Invoke-Route([string] $Prompt) {
  $p = $Prompt.ToLowerInvariant()
  foreach ($lane in $Tier1) {
    foreach ($stem in $lane.Stems) {
      if ($p.Contains($stem)) { return "$($lane.Mode) $($lane.Lead)" }
    }
  }
  return "CONVERGENT $(Get-Convener)"
}

# --- THE GAUGE ---------------------------------------------------------------
# LENS ORDER is fixed and load-bearing: corpus, POSIX arm and this file must
# agree on which slot is which lens. FORGE weights quoted from rot-lean.md
# section 4, never re-derived.
$Names   = @('Nova','Violet','AntiVenom','Venom','Carnage','Chroma','Soleil','Eidolon','Claude')
$Lambdas = @(1.4, 0.6, 1.9, 1.2, 0.6, 1.0, 1.0, 1.2, 2.3)
$Mus     = @(1.05, 0.85, 1.10, 1.05, 0.90, 1.10, 0.95, 1.10, 1.15)

# Mirrors ToString('0.##') / ('0.###'): round, then drop trailing zeros and a
# bare trailing dot. Written explicitly rather than relying on the format
# string, so that the rounding rule is visible next to the awk one it must match.
function Format-Num([double] $x, [int] $d) {
  $s = [Math]::Round($x, $d).ToString(('F' + $d), $inv)
  if ($s.Contains('.')) { $s = $s.TrimEnd('0').TrimEnd('.') }
  if ($s -eq '' -or $s -eq '-') { $s = '0' }
  return $s
}

# --- DEBUG LOG ---------------------------------------------------------------
# Set ROTMOE_DEBUG_LOG=<path> and every routing decision appends ONE JSON line
# carrying the whole computation: the lane, the lead lens, and for each of the
# nine lenses its lambda, mu, activity, delta, sigma, H and the resulting term.
#
# This exists because "the router works" was, until now, a claim backed by the
# router's own one-line summary. A summary cannot show you that lens 5 was
# multiplied by the wrong mu, or that a lens never participated at all. The log
# can, because it prints every factor that went into the sum -- so the reported
# R/s+ is reproducible by hand from the record.
#
# Failure here must never break a turn: the hook's job is to route, not to log.
# Every write is wrapped, and a failed write is silently dropped.
function Write-RotDebug([string] $Line) {
  $p = $env:ROTMOE_DEBUG_LOG
  if (-not $p) { return }
  try { Add-Content -LiteralPath $p -Value $Line -Encoding utf8 -ErrorAction Stop } catch { }
}

function Invoke-Gauge([string] $Vec, [int] $Br, [double] $M, [double] $C, [double] $T) {
  $acts = @($Vec -split ',' | ForEach-Object { [double]$_ })
  $K = $acts.Count
  $mean = 0.0; foreach ($a in $acts) { $mean += $a }
  $mean = $mean / $K

  $sum = 0.0
  $active = New-Object System.Collections.Generic.List[string]
  $terms  = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $K; $i++) {
    $a = $acts[$i]
    if ($a -gt 0) { $active.Add($Names[$i]) }
    $d = [Math]::Abs($a - $mean)
    $s = 1.0 / (1.0 + [Math]::Exp(-4.0 * ($d - 0.5)))
    $H = if ($Br -gt 0) { $a / [double]$Br } else { 0.0 }
    if ($H -gt 1.0) { $H = 1.0 }
    $term = $Lambdas[$i] * $s * (1.0 + $H) * $Mus[$i] * $M * $C * $T
    $sum += $term
    if ($env:ROTMOE_DEBUG_LOG) {
      $terms.Add(('{{"lens":"{0}","lambda":{1},"mu":{2},"a":{3},"delta":{4},"sigma":{5},"H":{6},"term":{7}}}' -f `
        $Names[$i], (Format-Num $Lambdas[$i] 3), (Format-Num $Mus[$i] 3), (Format-Num $a 3), `
        (Format-Num $d 4), (Format-Num $s 4), (Format-Num $H 4), (Format-Num $term 5)))
    }
  }
  if ($env:ROTMOE_DEBUG_LOG) {
    Write-RotDebug ('{{"kind":"gauge","ts":"{0}","K":{1},"mean":{2},"breadth":{3},"M":{4},"C":{5},"T":{6},"sum":{7},"Rs":{8},"active":"{9}","lenses":[{10}]}}' -f `
      (Get-Date -Format 'o'), $K, (Format-Num $mean 4), $Br, (Format-Num $M 3), (Format-Num $C 3), (Format-Num $T 3), `
      (Format-Num $sum 5), (Format-Num ($sum / $K) 5), ($(if ($active.Count) { $active -join ',' } else { 'none' })), ($terms -join ','))
  }
  $R = $sum / $K
  $band = if ($R -lt 0.9) { 'BELOW RANGE' } elseif ($R -gt 1.8) { 'ABOVE RANGE' } else { 'IN RANGE (0.9-1.8)' }
  $lenses = if ($active.Count) { $active -join ',' } else { 'none' }
  return ('R/s+ = {0} [{1}] mean={2} breadth={3} K={4} lenses={5}' -f `
          (Format-Num $R 2), $band, (Format-Num $mean 3), $Br, $K, $lenses)
}

if ($Route)  { Write-Output (Invoke-Route $Route); exit 0 }
if ($Vector) { Write-Output (Invoke-Gauge $Vector $Breadth $M $C $T); exit 0 }

# --- HOOK MODE, and the defect it exists to fix ------------------------------
# This script previously ENDED at Write-Error. ARM_ROUTER registers it as a hook
# command with no arguments, so every real invocation reached that line and
# exited 2 -- the hook fired on every turn and did nothing but complain.
#
# Every other instrument was green while that was true: the build, the kernel
# re-check, a 49-row byte-identical cross-diff, a byte-identical installer round
# trip, 10/10 mutants killed. None of them invokes the hook the way Claude Code
# invokes it. A live session found it in one run.
#
# Claude Code sends the invoking event as JSON on stdin -- measured in the
# shipped hook at rot-lean-inject.ps1:119-128. IsInputRedirected is the guard
# that keeps a manual run from blocking forever on a terminal; reading stdin
# unconditionally would hang.
$payload = ''
if ([Console]::IsInputRedirected) {
  try { $payload = [Console]::In.ReadToEnd() } catch { $payload = '' }
}

if ([string]::IsNullOrWhiteSpace($payload)) {
  Write-Error 'rot-router.ps1: hook mode expects a JSON payload on stdin. Try -Route "some text".'
  exit 2
}

$prompt = ''
try {
  $j = $payload | ConvertFrom-Json
  # MEASURED DEFECT, 2026-08-03 -- see the same note in rot-router.sh. Reading
  # only the tool NAME made every PreToolUse firing route to CONVERGENT, because
  # "Bash", "Edit", "Read" and "Grep" match no stem. The autonomous half of the
  # router was inert and looked healthy. Route on what the tool is DOING.
  if ($j.prompt)         { $prompt = [string]$j.prompt }
  elseif ($j.tool_name)  {
    $ti = $j.tool_input
    $act = @()
    if ($ti) {
      foreach ($f in 'command','file_path','path','pattern','description') {
        $v = $ti.$f
        if ($v -is [string] -and $v) { $act += $v }
      }
    }
    if ($act.Count -gt 0) { $prompt = ([string]$j.tool_name) + ' ' + ($act -join ' ') }
    else                  { $prompt = [string]$j.tool_name }
  }
} catch {
  # A payload that does not parse is not a reason to fail the user's turn. Route
  # the raw text: the routing decision degrades, the session does not break.
  $prompt = $payload
}

# README.md:77 promises this line carries a named lane AND A GAUGE READING. See
# the long note at the same point in rot-router.sh: the vector is the ROUTING
# DECISION expressed one-hot -- the lead lens of the fired lane at 1, the rest
# at 0 -- which is measured, not invented. A CONVERGENT turn fires no lens, so
# its vector is all zeros with breadth 0, and the gauge is defined there too.
# M, C and T are the neutral element 1.0 because one stateless hook call cannot
# measure memory residue, confidence or recency; that is stated, not hidden.
# The index comes from $Names so a roster change moves both arms together.
$lane  = Invoke-Route $prompt
$lens  = ($lane -split ' ')[1]
$acts  = @()
$br    = 0
foreach ($n in $Names) {
  if ($n -eq $lens) { $acts += '1'; $br = 1 } else { $acts += '0' }
}
$g  = Invoke-Gauge ($acts -join ',') $br 1 1 1
$rs = if ($g -match '^R/s\+ = ([0-9.]+)') { $Matches[1] } else { 'n/a' }

# One record per ROUTED TURN, distinct from the per-lens gauge record above.
# `chars` rather than the prompt itself: the log must be safe to paste into an
# issue, and the routing decision is what is under test, not the user's text.
if ($env:ROTMOE_DEBUG_LOG) {
  $ms = [int]((Get-Date) - $__rotStart).TotalMilliseconds
  Write-RotDebug ('{{"kind":"route","ts":"{0}","lane":"{1}","lens":"{2}","Rs":"{3}","chars":{4},"arm":"ps1","ms":{5}}}' -f `
    (Get-Date -Format 'o'), (($lane -split ' ')[0]), $lens, $rs, $prompt.Length, $ms)
}

Write-Output ("RoT MoE :: TIER 1 -> " + $lane + " | R/s+ " + $rs)
exit 0
