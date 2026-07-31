# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# DISARM_ROUTER.ps1 -- remove the RoT MoE router hooks. Windows arm.
#
# Same contract and the same shared engine as DISARM_ROUTER.sh. An installer
# whose uninstaller has never been run is an untested alarm, and an uninstaller
# that exists only on one platform is worse: it strands whoever installed from
# the other arm.
#
# KNOWN LIMIT, PROVED RATHER THAN DISCLAIMED (lean/Proofs/RotInstall.lean):
# `disarm_arm_id` holds only under a freshness hypothesis, and
# `disarm_arm_not_id` proves that hypothesis cannot be dropped. If you had
# already registered this exact command string by hand, this removes your entry
# too -- it cannot tell yours from ours, because they are identical strings.
# That is why the installer writes a backup and prints its restore line.
# =============================================================================

[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$ClaudeDir = if ($env:CLAUDE_DIR) { $env:CLAUDE_DIR } else { Join-Path $HOME '.claude' }
$Settings  = Join-Path $ClaudeDir 'settings.json'
$SelfDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RouterSh  = Join-Path $SelfDir 'hooks/rot-router.sh'
$RouterPs1 = Join-Path $SelfDir 'hooks/rot-router.ps1'
$Merge     = Join-Path $SelfDir 'hooks/settings-merge.js'
# Must produce the SAME string ARM_ROUTER.ps1 and ARM_ROUTER.sh produce -- see
# the long note in ARM_ROUTER.ps1. Removal matches by exact command string, so a
# one-character difference here silently strands the user's hook entry.
function ConvertTo-PosixPath([string] $p) {
  if ([string]::IsNullOrEmpty($p)) { return $p }
  $q = $p -replace '\\', '/'
  if ($q -match '^([A-Za-z]):/(.*)$') { $q = '/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2] }
  return $q
}
$RouterCmd = 'pwsh -NoProfile -File "' + (ConvertTo-PosixPath $RouterPs1) +
             '" || bash "' + (ConvertTo-PosixPath $RouterSh) + '"'

Write-Output 'RoT MoE :: DISARM_ROUTER (PowerShell arm)'
Write-Output ('  settings   : ' + $Settings)

if (-not (Test-Path -LiteralPath $Settings)) {
  Write-Output '  no settings.json -- nothing to disarm'; exit 0
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Output '  FATAL: node not found.'; exit 2
}

$Stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = "$Settings.pre-disarmrouter-$Stamp.bak"
Copy-Item -LiteralPath $Settings -Destination $Backup -Force
Write-Output ('  backup     : ' + $Backup)
Write-Output ('  restore    : Copy-Item "' + $Backup + '" "' + $Settings + '" -Force')

& node $Merge disarm $Settings $RouterCmd
$rc = $LASTEXITCODE

switch ($rc) {
  4 { Copy-Item -LiteralPath $Backup -Destination $Settings -Force
      Write-Output '  AUTO-RESTORED from backup.'; exit 4 }
  3 { Write-Output '  settings.json was already invalid. Nothing written.'; exit 3 }
  10 { Remove-Item -LiteralPath $Backup -Force
       Write-Output '  nothing to remove -- backup removed.'; exit 0 }
  0 { }
  default { Copy-Item -LiteralPath $Backup -Destination $Settings -Force
            Write-Output ('  unexpected failure (' + $rc + '). AUTO-RESTORED.'); exit $rc }
}

Write-Output '  --- diff ---'
$d = Compare-Object (Get-Content -LiteralPath $Backup) (Get-Content -LiteralPath $Settings)
if ($d) { $d | ForEach-Object { Write-Output ('  ' + $_.SideIndicator + ' ' + $_.InputObject) } }
else    { Write-Output '  (no textual difference)' }
Write-Output 'RoT MoE :: disarmed.'
exit 0
