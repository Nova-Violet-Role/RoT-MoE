# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# SETUP_LEAN.ps1 -- OPTIONAL toolchain fetch, Windows arm. Nothing installs
# this for you, and ARM_ROUTER.ps1 must never call it (workflow-lint FAILS THE
# BUILD if it ever does).
#
# YOU DO NOT NEED LEAN TO USE THIS PLUGIN. The router and the reminder are
# PowerShell and shell; Lean is needed only to RE-VERIFY THE PROOFS YOURSELF.
# CI does that on a clean runner every commit. This is for the reader who would
# rather measure than trust -- the correct instinct.
#
# The reasoning for downloading rather than vendoring (7.2 GB measured, per-OS
# binaries, staleness) is in SETUP_LEAN.sh and is not duplicated here: two
# copies of a paragraph drift and only one gets corrected.
#
#   .\SETUP_LEAN.ps1              -> REFUSES, exit 2. Consent is not a default.
#   .\SETUP_LEAN.ps1 -DryRun      -> prints the plan, creates NOTHING, exit 0.
#   .\SETUP_LEAN.ps1 -Yes         -> does the work.
#   .\SETUP_LEAN.ps1 -Uninstall   -> says exactly what to remove.
#
# NEVER elevates, never touches a system directory, never writes under
# ~/.claude outside this plugin's own folder.
# =============================================================================

[CmdletBinding()]
param(
  [switch] $Yes,
  [switch] $DryRun,
  [switch] $Uninstall
)

$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Ws   = if ($env:ROTMOE_LEAN_WORKSPACE) { $env:ROTMOE_LEAN_WORKSPACE } else { Join-Path $Here 'lean' }
$ElanRoot = if ($env:ELAN_HOME) { $env:ELAN_HOME } else { Join-Path $env:USERPROFILE '.elan' }

# --- what is already here (measured, never assumed) --------------------------
$haveElan  = [bool](Get-Command elan -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $ElanRoot 'bin/elan.exe'))
$haveLake  = [bool](Get-Command lake -ErrorAction SilentlyContinue)
$pinned    = 'unknown'
$tcFile    = Join-Path $Ws 'lean-toolchain'
if (Test-Path -LiteralPath $tcFile) { $pinned = (Get-Content -LiteralPath $tcFile -Raw).Trim() }
$haveCache = Test-Path -LiteralPath (Join-Path $Ws '.lake/packages/mathlib')

Write-Output '== RoT MoE :: optional Lean toolchain setup =='
Write-Output "  workspace        : $Ws"
Write-Output "  pinned toolchain : $pinned   (from lean-toolchain, never 'latest')"
Write-Output "  elan present     : $(if ($haveElan) {'yes'} else {'NO'})   ($ElanRoot)"
Write-Output "  lake on PATH     : $(if ($haveLake) {'yes'} else {'NO'})"
Write-Output "  mathlib present  : $(if ($haveCache) {'yes'} else {'NO'})"
Write-Output ''

if ($Uninstall) {
  Write-Output '-- uninstall: this script REMOVES NOTHING for you. What it would have created:'
  Write-Output ''
  Write-Output "   elan and every toolchain :  elan self uninstall   (or: Remove-Item -Recurse '$ElanRoot')"
  Write-Output "   the mathlib build tree   :  Remove-Item -Recurse '$Ws\.lake'    (the multi-GB one)"
  Write-Output "   the resolved manifest    :  Remove-Item '$Ws\lake-manifest.json'"
  Write-Output ''
  Write-Output '   Nothing else was touched. No system directory, no elevation.'
  exit 0
}

# --- the plan ----------------------------------------------------------------
$steps = 0
Write-Output '-- plan --'
if (-not $haveElan) {
  $steps++
  Write-Output '  [1] install elan from https://github.com/leanprover/elan/releases (official)'
  Write-Output "      -> into $ElanRoot ; no elevation, no system directory"
} else { Write-Output '  [1] SKIP: elan already present' }
if ($pinned -ne 'unknown') {
  $steps++
  Write-Output "  [2] elan toolchain install $pinned   (~500 MB, one toolchain, pinned)"
} else { Write-Output "  [2] SKIP: no lean-toolchain found at $Ws" }
if (-not $haveCache) {
  $steps++
  Write-Output "  [3] lake exe cache get in $Ws"
  Write-Output '      -> PREBUILT mathlib oleans. SEVERAL GIGABYTES: a full build tree'
  Write-Output '         measured 7.2 GB on the author machine. Check your free space.'
  Write-Output '      -> never a source build (that is hours, not minutes)'
} else { Write-Output "  [3] SKIP: mathlib already resolved under $Ws\.lake" }
Write-Output ''

if ($steps -eq 0) {
  Write-Output 'Nothing to do -- everything this script installs is already present.'
  Write-Output "Verify the proofs with:  Set-Location '$Ws'; lake build Proofs.RotGauge"
  exit 0
}
if ($DryRun) {
  Write-Output 'DRY RUN: nothing was downloaded, nothing was created, no directory was made.'
  Write-Output 'This is the negative control for this script -- run it first, always.'
  exit 0
}
if (-not $Yes) {
  Write-Output "REFUSING: $steps step(s) would download from the network and write to disk."
  Write-Output 'Consent is not a default. Re-run with -DryRun to see the plan, then -Yes.'
  exit 2
}

# --- do the work -------------------------------------------------------------
if (-not $haveElan) {
  Write-Output '[1/3] installing elan ...'
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("rotmoe-elan-" + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  $zip = Join-Path $tmp 'elan.zip'
  try {
    Invoke-WebRequest -Uri 'https://github.com/leanprover/elan/releases/latest/download/elan-x86_64-pc-windows-msvc.zip' `
                      -OutFile $zip -UseBasicParsing
  } catch {
    Write-Output '  DOWNLOAD FAILED -- nothing installed.'
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    exit 1
  }
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  & (Join-Path $tmp 'elan-init.exe') -y --default-toolchain none
  $rc = $LASTEXITCODE
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  if ($rc -ne 0) { Write-Output "  elan-init exited $rc -- stopping."; exit $rc }
  $env:Path = (Join-Path $ElanRoot 'bin') + ';' + $env:Path
}

if ($pinned -ne 'unknown') {
  Write-Output "[2/3] installing toolchain $pinned ..."
  & elan toolchain install $pinned
  if ($LASTEXITCODE -ne 0) { Write-Output "  elan toolchain install exited $LASTEXITCODE -- stopping."; exit $LASTEXITCODE }
}

if (-not $haveCache) {
  Write-Output '[3/3] fetching the prebuilt mathlib cache (the multi-GB step) ...'
  Push-Location $Ws
  & lake exe cache get
  $rc = $LASTEXITCODE
  Pop-Location
  if ($rc -ne 0) { Write-Output "  lake exe cache get exited $rc."; exit $rc }
}

Write-Output ''
Write-Output 'done. Verify the proofs yourself -- $LASTEXITCODE read DIRECTLY, never through a pipe:'
Write-Output "  Set-Location '$Ws'"
Write-Output '  lake build Proofs.RotGauge Proofs.RotRoute Proofs.RotInstall Proofs.RotPath Proofs.RotVacuity'
Write-Output '  "exit=$LASTEXITCODE"'
Write-Output '  lake env leanchecker Proofs.RotGauge   # the KERNEL own second opinion'
exit 0
