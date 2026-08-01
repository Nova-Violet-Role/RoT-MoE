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
  [switch] $Uninstall,
  [switch] $AskRoot,
  [string] $Root = ''
)

$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Ws   = if ($env:ROTMOE_LEAN_WORKSPACE) { $env:ROTMOE_LEAN_WORKSPACE } else { Join-Path $Here 'lean' }
# USERPROFILE does not exist outside Windows, and with $ErrorActionPreference
# set to 'Stop' above, `Join-Path` on a null Path ENDS THE SCRIPT. Found by
# checker/portability.sh's source scan on 2026-08-01, immediately after the
# identical defect in prover-remind.ps1 was fixed -- the scan exists precisely
# because a runtime probe only covers the paths it happens to execute, and
# nothing here had ever executed SETUP_LEAN.ps1 on a machine without Windows
# variables. elan installs to ~/.elan on Linux and macOS just as it does on
# Windows, so the fallback chain is the fix, not a special case.
$HomeDir = @($env:USERPROFILE, $env:HOME, [Environment]::GetFolderPath('UserProfile')) |
           Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
if (-not $HomeDir) { $HomeDir = '.' }
$ElanRoot = if ($env:ELAN_HOME) { $env:ELAN_HOME } else { Join-Path $HomeDir '.elan' }

# --- WHERE does the toolchain go? --------------------------------------------
# Mirrors SETUP_LEAN.sh exactly; checker/cross-diff.sh is what keeps them equal.
# A toolchain is ~500 MB and a mathlib cache adds several GB, so the installer
# ASKS for a filesystem ROOT (C:/, D:/, /) and puts elan in <root>/.elan by
# exporting ELAN_HOME -- the officially supported relocation, no registry edit.
function Resolve-Root([string] $r) {
  # Trim a trailing separator run, then put ONE back for a bare drive letter:
  # 'D:' is NOT a directory to Test-Path while 'D:/' is. The shell arm had this
  # exact bug and its control caught it, so the same shape is handled here
  # rather than rediscovered on a user's machine.
  $x = $r -replace '[\\/]+$', ''
  if ($x -match '^[A-Za-z]:$') { return "$x\" }
  if ([string]::IsNullOrEmpty($x)) { return [System.IO.Path]::DirectorySeparatorChar.ToString() }
  return $x
}
function Assert-Root([string] $r) {
  # ONE validator for both the flag and the prompt. Guarding only the branch a
  # human watches, while the machine-driven --Root path skips the check, reads
  # as safety and is not.
  if (-not (Test-Path -LiteralPath $r -PathType Container)) {
    Write-Output "REFUSE: '$r' is not an existing directory. NOTHING was installed."
    Write-Output "        Create it first, or omit -Root to use the default."
    exit 2
  }
  try {
    $probe = Join-Path $r ('.rotmoe-write-probe-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $probe -ErrorAction Stop | Out-Null
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
  } catch {
    Write-Output "REFUSE: '$r' is not writable by this user. NOTHING was installed."
    Write-Output "        This installer never elevates -- pick a root you own."
    exit 2
  }
}
function Join-ElanDir([string] $r) {
  if ($r.EndsWith('\') -or $r.EndsWith('/')) { return ($r + '.elan') }
  return (Join-Path $r '.elan')
}

if ($Root -ne '') {
  $R = Resolve-Root $Root
  Assert-Root $R
  $ElanRoot = Join-ElanDir $R
  $env:ELAN_HOME = $ElanRoot
} elseif ($AskRoot -and -not $Yes) {
  Write-Output ''
  Write-Output '== where should the Lean toolchain live? =='
  Write-Output '   A toolchain is ~500 MB; a mathlib cache adds several GB more.'
  Write-Output '   Give a filesystem ROOT and elan goes into <root>/.elan:'
  Write-Output ''
  Write-Output '     C:/       ->  C:/.elan        (Windows system drive)'
  Write-Output '     D:/       ->  D:/.elan        (a second drive with room)'
  Write-Output '     /         ->  /.elan          (Unix root; needs write access)'
  Write-Output '     <empty>   ->  keep the default below'
  Write-Output ''
  $answer = Read-Host "install root [default: keep $ElanRoot]"
  if (-not [string]::IsNullOrWhiteSpace($answer)) {
    $R = Resolve-Root $answer
    Assert-Root $R
    $ElanRoot = Join-ElanDir $R
    $env:ELAN_HOME = $ElanRoot
  }
}

# --- what is already here (measured, never assumed) --------------------------
# Two DIFFERENT questions, kept apart: is SOME elan callable, and is there one
# at the root we are about to install into. Conflating them prints
# "elan present: yes (D:/.elan)" for an elan that lives somewhere else.
$haveElanPath = [bool](Get-Command elan -ErrorAction SilentlyContinue)
$haveElanRoot = Test-Path (Join-Path $ElanRoot 'bin/elan.exe')
$elanWhere = if ($haveElanRoot) { "installed at $ElanRoot" }
             elseif ($haveElanPath) { "on PATH, NOT at $ElanRoot" }
             else { "absent; would go to $ElanRoot" }
$haveElan  = $haveElanPath -or $haveElanRoot
$haveLake  = [bool](Get-Command lake -ErrorAction SilentlyContinue)
$pinned    = 'unknown'
$tcFile    = Join-Path $Ws 'lean-toolchain'
if (Test-Path -LiteralPath $tcFile) { $pinned = (Get-Content -LiteralPath $tcFile -Raw).Trim() }
$haveCache = Test-Path -LiteralPath (Join-Path $Ws '.lake/packages/mathlib')

Write-Output '== RoT MoE :: optional Lean toolchain setup =='
Write-Output "  workspace        : $Ws"
Write-Output "  pinned toolchain : $pinned   (from lean-toolchain, never 'latest')"
Write-Output "  elan present     : $(if ($haveElan) {'yes'} else {'NO'})   ($elanWhere)"
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
