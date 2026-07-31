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
  @{ Mode = 'CLINICAL';   Lead = 'AntiVenom'; Stems = @('debug','error','bug','fix','secur','audit','verif','test','cve') },
  @{ Mode = 'EXECUTIVE';  Lead = 'Venom';     Stems = @('decid','urgenc','strike','direct','declar','now','conclud') },
  @{ Mode = 'EMPATHIC';   Lead = 'Violet';    Stems = @('emot','feel','grief','lonel','soul','story','human','tired','lost') },
  @{ Mode = 'STRATEGIC';  Lead = 'Nova';      Stems = @('strateg','plan','goal','roadmap','priorit','legal','recommend','analyz') },
  @{ Mode = 'CREATIVE';   Lead = 'Carnage';   Stems = @('creativ','chaos','surreal','disrupt','paradox','dream','invent') },
  @{ Mode = 'PREDICTIVE'; Lead = 'Chroma';    Stems = @('futur','scenar','predict','trend','forec','likel','horizon','next') },
  @{ Mode = 'STEALTH';    Lead = 'Soleil';    Stems = @('encod','optim','token','compress','concise','byte','distill') },
  @{ Mode = 'RECURSIVE';  Lead = 'Eidolon';   Stems = @('evolv','recurs','meta','architect','refactor','ontolog','hybrid') }
)

function Invoke-Route([string] $Prompt) {
  $p = $Prompt.ToLowerInvariant()
  foreach ($lane in $Tier1) {
    foreach ($stem in $lane.Stems) {
      if ($p.Contains($stem)) { return "$($lane.Mode) $($lane.Lead)" }
    }
  }
  return 'CONVERGENT none'
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

function Invoke-Gauge([string] $Vec, [int] $Br, [double] $M, [double] $C, [double] $T) {
  $acts = @($Vec -split ',' | ForEach-Object { [double]$_ })
  $K = $acts.Count
  $mean = 0.0; foreach ($a in $acts) { $mean += $a }
  $mean = $mean / $K

  $sum = 0.0
  $active = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $K; $i++) {
    $a = $acts[$i]
    if ($a -gt 0) { $active.Add($Names[$i]) }
    $d = [Math]::Abs($a - $mean)
    $s = 1.0 / (1.0 + [Math]::Exp(-4.0 * ($d - 0.5)))
    $H = if ($Br -gt 0) { $a / [double]$Br } else { 0.0 }
    if ($H -gt 1.0) { $H = 1.0 }
    $sum += $Lambdas[$i] * $s * (1.0 + $H) * $Mus[$i] * $M * $C * $T
  }
  $R = $sum / $K
  $band = if ($R -lt 0.9) { 'BELOW RANGE' } elseif ($R -gt 1.8) { 'ABOVE RANGE' } else { 'IN RANGE (0.9-1.8)' }
  $lenses = if ($active.Count) { $active -join ',' } else { 'none' }
  return ('R/s+ = {0} [{1}] mean={2} breadth={3} K={4} lenses={5}' -f `
          (Format-Num $R 2), $band, (Format-Num $mean 3), $Br, $K, $lenses)
}

if ($Route)  { Write-Output (Invoke-Route $Route); exit 0 }
if ($Vector) { Write-Output (Invoke-Gauge $Vector $Breadth $M $C $T); exit 0 }

Write-Error 'rot-router.ps1: no mode given (-Vector or -Route)'
exit 2
