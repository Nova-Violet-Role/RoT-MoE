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
  [string] $Root = '',
  # Named $ElanRoot_ because $ElanRoot is already the COMPUTED install path a
  # few lines below. Two variables one underscore apart is not elegant, and the
  # alternative -- a parameter silently overwritten by the computation it is
  # meant to control -- is a defect rather than an inelegance.
  [Alias('ElanRoot')] [string] $ElanRoot_ = ''
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

function Join-LeanDir([string] $r) {
  if ($r.EndsWith('\') -or $r.EndsWith('/')) { return ($r + 'Lean') }
  return (Join-Path $r 'Lean')
}

# --- the user's OWN workspace ------------------------------------------------
# This half was missing from the pwsh arm entirely: it printed a workspace line
# and then never created or recorded one, so a Windows-native user ended up with
# the hooks resolving the plugin's READ-ONLY bundled corpus inside plugins/cache
# -- a directory that can never accumulate their proof debt.
#
# It is a FUNCTION rather than a block at the end because the script exits early
# on -DryRun, and a block at the end is dead code on exactly the path a careful
# user runs FIRST. Called from both exits, so both report the same thing.
#
# $HomeDir, not a Get-HomeDir call: this file computes the home directory into a
# VARIABLE at the top. A call to a function that does not exist would throw
# under $ErrorActionPreference='Stop' and take the whole installer with it.
function Record-UserWorkspace {
  if ($ChosenRoot -eq '') { return }
  $LeanWs  = Join-LeanDir $ChosenRoot
  $ProofsD = Join-Path $LeanWs 'Proofs'
  $StateD  = if ($env:ROTMOE_STATE_DIR) { $env:ROTMOE_STATE_DIR }
             elseif ($env:XDG_STATE_HOME) { Join-Path $env:XDG_STATE_HOME 'rot-moe' }
             else { Join-Path $HomeDir '.local/state/rot-moe' }
  $StateF  = Join-Path $StateD 'workspace'

  if ($DryRun) {
    Write-Output "would create workspace: $ProofsD"
    Write-Output "would scaffold: $LeanWs\lakefile.toml, $LeanWs\lean-toolchain"
    Write-Output "would record workspace: $LeanWs -> $StateF"
    return
  }

  New-Item -ItemType Directory -Force -Path $ProofsD | Out-Null

  # A DIRECTORY IS NOT A WORKSPACE -- see the matching comment in SETUP_LEAN.sh.
  # Without a lakefile the user's first theorem cannot build at all: lake says
  # "no configuration file with a supported extension" and the hook answers LEAN
  # REFUSED, which reads as "your proof is wrong" when the truth is "there was
  # nothing to build it with". Measured end to end before this was added.
  #
  # NEVER overwrite: a returning user's lakefile is theirs.
  $lakeF = Join-Path $LeanWs 'lakefile.toml'
  if (-not (Test-Path -LiteralPath $lakeF)) {
    $lake = @'
name = "proofs"
defaultTargets = ["Proofs"]

# Core Lean only -- your proofs start here and grow from your own work.
# To add mathlib later, append:
#
#   [[require]]
#   name = "mathlib"
#   scope = "leanprover-community"
#
# then run `lake update` and `lake exe cache get` (never build it from source).

[[lean_lib]]
name = "Proofs"
'@
    Set-Content -LiteralPath $lakeF -Value $lake -Encoding utf8
    Write-Output "  scaffolded $lakeF"
  } else {
    Write-Output "  kept your existing $lakeF"
  }

  # Pin the SAME toolchain this plugin's corpus is verified against, so a proof
  # that builds in your workspace builds in ours. 'unknown' means we could not
  # read one, and inventing a version is worse than leaving elan its default.
  $tcOut = Join-Path $LeanWs 'lean-toolchain'
  if ((-not (Test-Path -LiteralPath $tcOut)) -and $pinned -ne 'unknown') {
    Set-Content -LiteralPath $tcOut -Value $pinned -Encoding utf8
    Write-Output "  pinned $tcOut to $pinned"
  }
  New-Item -ItemType Directory -Force -Path $StateD  | Out-Null

  # NORMALISE TO FORWARD SLASHES BEFORE WRITING. This state file is READ BY THE
  # SHELL HOOK, and a POSIX -d test on a backslash path is FALSE in Git Bash --
  # a backslash is not a separator there. Measured: the pwsh installer recorded a
  # perfectly correct Windows path, the shell hook silently rejected it, fell
  # back to the plugin's read-only bundled corpus, and emitted NO verdict at all.
  # Silence, not an error, which is the worst way for this to fail.
  #
  # Windows APIs accept forward slashes, so one format serves both arms.
  $recorded = $LeanWs -replace '\\', '/'
  Set-Content -LiteralPath $StateF -Value $recorded -Encoding utf8 -NoNewline

  # READ IT BACK. Writing a file is not evidence that the file says what you
  # wrote -- an encoding or a stale handle turns a silent success into a hook
  # that resolves the wrong directory forever after. Refuse to claim success on
  # a mismatch rather than reporting the value we INTENDED to write.
  $back = ''
  if (Test-Path -LiteralPath $StateF) {
    $back = (Get-Content -LiteralPath $StateF -Raw).Trim()
  }
  if ($back -eq $recorded) {
    Write-Output "  workspace recorded: $recorded"
  } else {
    Write-Output "  WARNING: recorded '$back' but meant '$recorded' -- the hooks will not find it."
    Write-Output "           Set ROTMOE_LEAN_WORKSPACE='$recorded' to work around this."
  }
}

# -Root NOW MEANS "where do MY PROOFS live", matching SETUP_LEAN.sh. The
# toolchain is a bounded, one-time cost that elan manages in the home directory;
# the proof workspace is what grows without bound, so it is the one that belongs
# on the disk the user picked. -ElanRoot keeps the old capability for a tight
# system drive, which was the real problem the single flag was solving.
$ChosenRoot = ''

if ($ElanRoot_ -ne '') {
  $ER = Resolve-Root $ElanRoot_
  Assert-Root $ER
  $ElanRoot = Join-ElanDir $ER
  $env:ELAN_HOME = $ElanRoot
}

if ($Root -ne '') {
  $R = Resolve-Root $Root
  Assert-Root $R
  $ChosenRoot = $R
} elseif ($AskRoot -and -not $Yes) {
  Write-Output ''
  Write-Output '== where should YOUR proofs live? =='
  Write-Output '   Your own .lean files start EMPTY here and grow as you work -- this is'
  Write-Output '   the directory the router watches and builds, not our shipped corpus.'
  Write-Output '   Give a filesystem ROOT and the workspace goes into <root>/Lean:'
  Write-Output ''
  Write-Output '     C:/       ->  C:/Lean/Proofs     (Windows system drive)'
  Write-Output '     D:/       ->  D:/Lean/Proofs     (a second drive with room)'
  Write-Output '     /         ->  /Lean/Proofs       (Unix root; needs write access)'
  Write-Output '     <empty>   ->  skip; the router falls back to our bundled corpus'
  Write-Output ''
  Write-Output "   The toolchain itself stays in your home directory ($ElanRoot)."
  Write-Output '   Use -ElanRoot <path> if your system drive is short on space.'
  Write-Output ''
  $answer = Read-Host 'proof workspace root [empty to skip]'
  if (-not [string]::IsNullOrWhiteSpace($answer)) {
    $R = Resolve-Root $answer
    Assert-Root $R
    $ChosenRoot = $R
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
# Is the pinned toolchain ALREADY there? Asked with `elan toolchain list`
# rather than discovered by running the install and reading a failure -- see the
# matching comment in SETUP_LEAN.sh. MEASURED on elan 4.2.3: installing a
# toolchain that is already present exits 1.
$haveTc = $false
if ($pinned -ne 'unknown' -and (Get-Command elan -ErrorAction SilentlyContinue)) {
  $tcl = (& elan toolchain list 2>$null) -join "`n"
  $haveTc = $tcl.Contains($pinned)
}

if ($pinned -eq 'unknown') {
  Write-Output "  [2] SKIP: no lean-toolchain found at $Ws"
} elseif ($haveTc) {
  Write-Output "  [2] SKIP: toolchain $pinned already installed"
} else {
  $steps++
  Write-Output "  [2] elan toolchain install $pinned   (~500 MB, one toolchain, pinned)"
}
if (-not $haveCache) {
  $steps++
  Write-Output "  [3] lake exe cache get in $Ws"
  Write-Output '      -> PREBUILT mathlib oleans. SEVERAL GIGABYTES: a full build tree'
  Write-Output '         measured 7.2 GB on the author machine. Check your free space.'
  Write-Output '      -> never a source build (that is hours, not minutes)'
} else { Write-Output "  [3] SKIP: mathlib already resolved under $Ws\.lake" }
Write-Output ''

# RECORD THE WORKSPACE BEFORE ANY EXIT PATH, not after the downloads.
#
# It was placed at the end and was therefore dead code on the two paths users
# actually take: -DryRun (which a careful reader runs FIRST) and "nothing to do"
# (which is every re-run on a machine that already has the toolchain). Setting
# where your proofs live has NOTHING to do with whether a 7 GB cache needs
# fetching, so it must not be gated behind that work happening.
Record-UserWorkspace

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

if ($pinned -ne 'unknown' -and $haveTc) {
  Write-Output "[2/3] SKIP: $pinned is already installed."
} elseif ($pinned -ne 'unknown') {
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
