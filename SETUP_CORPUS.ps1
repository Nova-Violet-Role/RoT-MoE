# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# SETUP_CORPUS -- Windows arm. Same contract as SETUP_CORPUS.sh, same exit codes.
#
# TWO ARMS, ONE BEHAVIOUR. This repository ships every hook and installer in a
# POSIX and a PowerShell arm, and checks them against each other, because the
# alternative is a Windows user running a different product. The exit codes are
# the contract and they are identical:
#
#   0  the corpus is current (or the user declined -- nothing was written)
#   2  refusal: bad argument, no downloader, or the remote is unreachable
#   3  --check only: an update is available
#   4  --check only: the corpus is absent
#   1  a fetch was attempted and FAILED; the existing corpus is untouched
#
#   .\SETUP_CORPUS.ps1              # detect, report, ask
#   .\SETUP_CORPUS.ps1 -Check       # report only; never writes
#   .\SETUP_CORPUS.ps1 -Yes         # non-interactive
#   .\SETUP_CORPUS.ps1 -Dest <dir>  # where the corpus should live
# =============================================================================

[CmdletBinding()]
param(
  [switch]$Check,
  [switch]$Yes,
  [string]$Dest
)

$ErrorActionPreference = 'Stop'

$RepoSlug = if ($env:ROTMOE_CORPUS_REPO)   { $env:ROTMOE_CORPUS_REPO }   else { 'Nova-Violet-Role/RoT-MoE' }
$Branch   = if ($env:ROTMOE_CORPUS_BRANCH) { $env:ROTMOE_CORPUS_BRANCH } else { 'main' }
$Folder   = 'Lean Theorem'

$SelfDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Dest) { $Dest = Join-Path $SelfDir $Folder }

function Say([string]$m) { Write-Host $m }

# --- what do we have? --------------------------------------------------------
# COUNTED, not merely tested for existence: an empty directory left by an
# interrupted fetch passes a -PathType Container test and means nothing.
$localMods = 0
if (Test-Path -LiteralPath $Dest) {
  $localMods = @(Get-ChildItem -LiteralPath $Dest -Recurse -Filter *.lean -File -ErrorAction SilentlyContinue).Count
}

$Stamp = Join-Path $Dest '.corpus-stamp'
$haveStamp = ''
if (Test-Path -LiteralPath $Stamp) { $haveStamp = (Get-Content -LiteralPath $Stamp -TotalCount 1).Trim() }

Say '== shared Lean corpus =='
if ($localMods -eq 0) {
  Say "  local:  ABSENT (no .lean files under '$Dest')"
} else {
  Say "  local:  $localMods module(s) in '$Dest'"
  if ($haveStamp) { Say ("          last fetched at commit " + $haveStamp.Substring(0, [Math]::Min(12, $haveStamp.Length))) }
}

# --- what does upstream have? ------------------------------------------------
$remoteSha = ''
try {
  $api  = "https://api.github.com/repos/$RepoSlug/commits/$Branch"
  $resp = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = 'rot-moe-setup-corpus' } -TimeoutSec 30
  $remoteSha = [string]$resp.sha
} catch {
  $remoteSha = ''
}

if (-not $remoteSha) {
  Say "  remote: UNREACHABLE ($RepoSlug@$Branch)"
  Say ''
  Say '  Nothing was changed. Re-run when you have a connection; the corpus you'
  Say '  already have on disk is untouched and still usable.'
  exit 2
}
Say ("  remote: $RepoSlug@$Branch at " + $remoteSha.Substring(0,12))

# --- decide ------------------------------------------------------------------
$status = 'update'
if     ($localMods -eq 0)                              { $status = 'absent'  }
elseif ($haveStamp -and ($haveStamp -eq $remoteSha))   { $status = 'current' }

switch ($status) {
  'current' { Say '  -> up to date; nothing to do.' }
  'absent'  { Say '  -> the corpus is not installed here.' }
  'update'  { Say '  -> an update is available.' }
}

if ($Check) {
  switch ($status) { 'current' { exit 0 } 'update' { exit 3 } 'absent' { exit 4 } }
}
if ($status -eq 'current') { exit 0 }

# --- protect local modifications ---------------------------------------------
if ($haveStamp -and (Test-Path -LiteralPath $Dest)) {
  $stampTime = (Get-Item -LiteralPath $Stamp).LastWriteTimeUtc
  $modified  = @(Get-ChildItem -LiteralPath $Dest -Recurse -Filter *.lean -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.LastWriteTimeUtc -gt $stampTime } | Select-Object -First 20)
  if ($modified.Count -gt 0) {
    Say ''
    Say '  !! these files changed AFTER the last fetch -- refreshing REPLACES them:'
    foreach ($m in $modified) { Say ('       ' + $m.FullName) }
    Say ''
  }
}

if (-not $Yes) {
  Say ''
  Say '  This will replace the contents of:'
  Say "      $Dest"
  Say ("  with '$Folder' from $RepoSlug@$Branch (" + $remoteSha.Substring(0,12) + ').')
  $answer = Read-Host 'proceed? [y/N]'
  if ($answer -notmatch '^(y|Y|yes|YES)$') { Say '  aborted; nothing was written.'; exit 0 }
}

# --- fetch into a temp dir, swap in only when known good ---------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("rotcorpus-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
  $tarball = "https://codeload.github.com/$RepoSlug/tar.gz/$remoteSha"
  Say ''
  Say ('  downloading ' + $remoteSha.Substring(0,12) + ' ...')
  $archive = Join-Path $tmp 'src.tar.gz'
  Invoke-WebRequest -Uri $tarball -OutFile $archive -Headers @{ 'User-Agent' = 'rot-moe-setup-corpus' } -TimeoutSec 300

  if (-not (Test-Path -LiteralPath $archive) -or (Get-Item -LiteralPath $archive).Length -eq 0) {
    Say '  REFUSE: download failed -- your existing corpus is untouched'
    exit 1
  }

  # tar ships with Windows 10 1803+ and with Git for Windows.
  Push-Location $tmp
  try { & tar -xzf 'src.tar.gz' } finally { Pop-Location }

  $src = Get-ChildItem -LiteralPath $tmp -Recurse -Directory -Filter $Folder -ErrorAction SilentlyContinue |
         Select-Object -First 1
  if (-not $src) {
    Say "  REFUSE: the download contains no '$Folder' folder -- refusing to touch your copy"
    exit 1
  }

  $newMods = @(Get-ChildItem -LiteralPath $src.FullName -Recurse -Filter *.lean -File).Count
  if ($newMods -eq 0) {
    Say "  REFUSE: the downloaded '$Folder' holds no .lean file -- that is not an update,"
    Say '          it is an erasure. Your copy is untouched.'
    exit 1
  }

  if (Test-Path -LiteralPath $Dest) {
    $bak = "$Dest.pre-fetch-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak'
    Move-Item -LiteralPath $Dest -Destination $bak
    Say ('  previous corpus kept at: ' + (Split-Path -Leaf $bak))
  }
  Move-Item -LiteralPath $src.FullName -Destination $Dest
  Set-Content -LiteralPath (Join-Path $Dest '.corpus-stamp') -Value $remoteSha -Encoding ascii

  $final = @(Get-ChildItem -LiteralPath $Dest -Recurse -Filter *.lean -File).Count
  $subj  = @(Get-ChildItem -LiteralPath $Dest -Directory).Count
  Say ''
  Say ("  installed: $subj subject(s), $final module(s) at " + $remoteSha.Substring(0,12))
  if ($final -ne $newMods) {
    Say "  FAIL: expected $newMods modules but $final are on disk after the swap"
    exit 1
  }
  Say '  done.'
  exit 0
}
finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
