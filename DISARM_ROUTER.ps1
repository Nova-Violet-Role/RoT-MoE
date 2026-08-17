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
param(
  # -DryRun: report what WOULD be removed and write nothing. Named to match
  # ARM_ROUTER.ps1. Its absence here -- on the DESTRUCTIVE half of the pair --
  # cost a live configuration: the flag was passed to preview a removal, the
  # POSIX arm ignored it, and two real router hook entries were deleted.
  [switch] $DryRun,
  # -All: remove EVERY hook entry invoking a RoT MoE router script, whatever
  # path or version it names. The default matches this directory's exact command
  # string, which cannot remove a plugin-cache entry -- measured, and the reason
  # this switch exists.
  [switch] $All
)
$ErrorActionPreference = 'Stop'

# CLAUDE_CONFIG_DIR FIRST -- it is the variable Claude Code itself reads to
# relocate its configuration. Honouring only our own CLAUDE_DIR armed the
# WRONG directory for any user who had set it. Ours stays second so the
# existing checkers keep working; the home-relative .claude remains the default.
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR }
             elseif ($env:CLAUDE_DIR)     { $env:CLAUDE_DIR }
             else { Join-Path $HOME '.claude' }
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
$RouterCmd = 'command -v pwsh >/dev/null 2>&1 && pwsh -NoProfile -File "' + (ConvertTo-PosixPath $RouterPs1) +
             '" || bash "' + (ConvertTo-PosixPath $RouterSh) + '"'

# EXACT MODE MUST KNOW EVERY STRING THE INSTALLER WRITES -- same block, same
# reason, as DISARM_ROUTER.sh. Measured 2026-08-05: once ARM_ROUTER began wiring
# prover-remind on three events, exact removal took the router and left all three
# reminder entries behind, with no documented way to remove them. The cross-arm
# round trip in install-roundtrip.sh is what caught it, on the PowerShell side
# only -- the POSIX arm had already been fixed, which is exactly how two arms of
# one contract drift.
$RemindPs1 = Join-Path $SelfDir 'hooks/prover-remind.ps1'
$RemindSh  = Join-Path $SelfDir 'hooks/prover-remind.sh'
$RemindCmd = 'command -v pwsh >/dev/null 2>&1 && pwsh -NoProfile -File "' + (ConvertTo-PosixPath $RemindPs1) +
             '" || bash "' + (ConvertTo-PosixPath $RemindSh) + '"'
$GatePs1 = Join-Path $SelfDir 'hooks/rot-voice-gate.ps1'
$GateSh  = Join-Path $SelfDir 'hooks/rot-voice-gate.sh'
$GateCmd = 'command -v pwsh >/dev/null 2>&1 && pwsh -NoProfile -File "' + (ConvertTo-PosixPath $GatePs1) +
           '" || bash "' + (ConvertTo-PosixPath $GateSh) + '"'

$Mode = if ($All) { 'disarm-any' } else { 'disarm' }

Write-Output 'RoT MoE :: DISARM_ROUTER (PowerShell arm)'
Write-Output ('  settings   : ' + $Settings)
Write-Output ('  match      : ' + $(if ($All) { 'ANY RoT MoE router entry (-All)' } else { 'exact command string of this directory' }))
if ($DryRun) { Write-Output '  mode       : DRY RUN -- nothing will be written' }

if (-not (Test-Path -LiteralPath $Settings)) {
  Write-Output '  no settings.json -- nothing to disarm'; exit 0
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Output '  FATAL: node not found.'; exit 2
}

# DRY RUN -- cross-arm parity with DISARM_ROUTER.sh. The removal runs FOR REAL
# against a copy, so the preview and the act share one code path and cannot
# disagree; a dry run computed by a second implementation is a second thing to
# be wrong.
if ($DryRun) {
  $Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("rotmoe-disarm-dry-" + $PID + ".json")
  Copy-Item -LiteralPath $Settings -Destination $Tmp -Force
  # A read-only settings.json copies read-only, and node would then fail to
  # write -- reporting "would FAIL" for a removal that would in fact succeed.
  try { Set-ItemProperty -LiteralPath $Tmp -Name IsReadOnly -Value $false } catch { }
  $before = @(Select-String -LiteralPath $Settings -Pattern 'rot-router' -SimpleMatch).Count
  & node $Merge $Mode $Tmp $RouterCmd | Out-Null
  $rc = $LASTEXITCODE
  & node $Merge $Mode $Tmp $RemindCmd | Out-Null
  $rc2 = $LASTEXITCODE
  if ($rc -eq 10 -and $rc2 -ne 10) { $rc = $rc2 }
  # Third pass for the voice gate, same absence rule as the reminder.
  & node $Merge $Mode $Tmp $GateCmd | Out-Null
  $rc3 = $LASTEXITCODE
  if ($rc -eq 10 -and $rc3 -ne 10) { $rc = $rc3 }
  if ($rc -eq 10) {
    Write-Output '  would remove: 0 router hook entries'
  } elseif ($rc -ne 0) {
    Write-Output ('  would FAIL with code ' + $rc + ' -- nothing would be written')
  } else {
    $after = @(Select-String -LiteralPath $Tmp -Pattern 'rot-router' -SimpleMatch).Count
    Write-Output ('  router lines: ' + $before + ' now -> ' + $after + ' if disarmed')
  }
  Remove-Item -LiteralPath $Tmp -Force -ErrorAction SilentlyContinue
  Write-Output ('  DRY RUN complete -- ' + $Settings + ' was NOT modified.')
  exit 0
}

$Stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = "$Settings.pre-disarmrouter-$Stamp.bak"
Copy-Item -LiteralPath $Settings -Destination $Backup -Force
Write-Output ('  backup     : ' + $Backup)
Write-Output ('  restore    : Copy-Item "' + $Backup + '" "' + $Settings + '" -Force')

& node $Merge $Mode $Settings $RouterCmd
$rc = $LASTEXITCODE
& node $Merge $Mode $Settings $RemindCmd
$rc2 = $LASTEXITCODE
# A run that removed only the reminder still CHANGED the file; reporting
# `nothing to remove` there would be a false all-clear.
if ($rc -eq 10 -and $rc2 -ne 10) { $rc = $rc2 }
# Third pass for the voice gate, same absence rule as the reminder.
& node $Merge $Mode $Settings $GateCmd
$rc3 = $LASTEXITCODE
if ($rc -eq 10 -and $rc3 -ne 10) { $rc = $rc3 }

switch ($rc) {
  4 { Copy-Item -LiteralPath $Backup -Destination $Settings -Force
      Write-Output '  AUTO-RESTORED from backup.'; exit 4 }
  3 { Write-Output '  settings.json was already invalid. Nothing written.'; exit 3 }
  10 { Remove-Item -LiteralPath $Backup -Force
       Write-Output '  nothing to remove -- backup removed.'
       # Say so when the answer is misleading: `nothing to remove` while router
       # entries are visibly present is the exact shape of the measured defect.
       if ((-not $All) -and @(Select-String -LiteralPath $Settings -Pattern 'rot-router' -SimpleMatch).Count -gt 0) {
         Write-Output ''
         Write-Output '  BUT settings.json still contains RoT MoE router entries that do NOT'
         Write-Output "  match this directory's command string (a plugin-cache or older-version"
         Write-Output '  install). This run could not touch them. To remove those as well:'
         Write-Output '      pwsh -NoProfile -File .\DISARM_ROUTER.ps1 -All -DryRun   # look first'
         Write-Output '      pwsh -NoProfile -File .\DISARM_ROUTER.ps1 -All'
       }
       exit 0 }
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
