# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# ARM_ROUTER.ps1 -- install the RoT MoE router hooks. Windows arm.
#
# SAME CONTRACT as ARM_ROUTER.sh, and "same" is mechanical here rather than
# aspirational: checker/install-roundtrip.sh runs BOTH installers over the same
# fixture and requires the resulting settings.json to be BYTE-IDENTICAL.
#
# It is byte-identical because both arms call ONE merge engine,
# hooks/settings-merge.js. That is a deliberate asymmetry with the router, and
# the reasoning is worth stating because it looks inconsistent at first glance:
#
#   the ROUTER is duplicated on purpose -- two independent implementations that
#   agree is evidence a single green cannot fake; a shared bug would have to be
#   written twice, in two languages.
#
#   the INSTALLER shares one engine on purpose -- there is nothing to
#   cross-check against, the file it edits is the user's live session, and
#   PowerShell's ConvertTo-Json and node's JSON.stringify disagree on escaping,
#   key order and depth. Two native implementations would produce different
#   bytes from identical inputs while both looked correct.
#
# Evidence beats duplication where evidence exists; where it does not,
# duplication is just two chances to be wrong.
#
# The seven rules -- backup, additive merge, preserve, validate with
# auto-restore, idempotent by command string, show the diff, never leave the
# config dir -- are enforced jointly: the shell half here does backup/restore
# and the diff, the engine does merge/preserve/validate/idempotence.
# =============================================================================

[CmdletBinding()]
param(
  [switch] $DryRun,   # -DryRun: show the change, write nothing
  # -Force: arm even when the installed plugin already registers the router.
  # That DUPLICATES it -- see the guard below, which exists because of a measured
  # double-fire on a real machine.
  [switch] $Force
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

# --- PATH NORMALISATION, and the stranding bug that forced it ----------------
# The cross-arm phase of checker/install-roundtrip.sh caught this on its first
# run. Unnormalised, the two arms wrote DIFFERENT command strings for the same
# install:
#
#   .sh   ->  bash "/c/path/to/RoT MoE/hooks/rot-router.sh"
#   .ps1  ->  bash "C:\path\to\RoT MoE\hooks\rot-router.sh"
#
# (Written with a placeholder path on purpose: checker/no-local-paths.sh caught
# the first draft of this very comment for containing a real machine-local path.
# A file documenting a portability bug is not exempt from the portability rule.)
#
# Removal matches by exact command string, so a user who installed from Git Bash
# and uninstalled from PowerShell would be left with a dead hook entry FOREVER,
# with both scripts reporting success. Nothing in Lean, and nothing in a
# single-arm test, can see that: it only appears when the two arms are compared.
#
# POSIX is the normal form, and the choice is empirical rather than aesthetic.
# Claude Code executes hooks through Git Bash on Windows -- measured in a live
# session debug log: `Using bash path: "C:\Program Files\Git\bin\bash.exe"` --
# and the POSIX-form command is the one OBSERVED FIRING in that session
# (checker/live-session-smoke.sh). The Windows-form string has never been seen
# to fire. Between a form that is measured to work and one that merely looks
# native, the measured one wins.
function ConvertTo-PosixPath([string] $p) {
  if ([string]::IsNullOrEmpty($p)) { return $p }
  $q = $p -replace '\\', '/'
  # C:/foo -> /c/foo   (drive letter lowercased, matching Git Bash's own form)
  if ($q -match '^([A-Za-z]):/(.*)$') {
    $q = '/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2]
  }
  return $q
}

# The command string is the identity used for idempotence AND for removal. It
# must match ARM_ROUTER.sh character for character, or the arms install entries
# the other cannot uninstall. The roundtrip checker compares the written bytes,
# which is what makes that a tested claim rather than an intention.
$RouterCmd = 'pwsh -NoProfile -File "' + (ConvertTo-PosixPath $RouterPs1) +
             '" || bash "' + (ConvertTo-PosixPath $RouterSh) + '"'
$EventsCsv = 'UserPromptSubmit,PreToolUse'

# The reminder, on the THREE events the plugin binds it to. Measured parity gap:
# the plugin registered 5 bindings across 3 events, this installer wrote 2, and
# no installer in the tree had ever wired prover-remind at all. See the same
# block in ARM_ROUTER.sh -- the two arms must stay character-identical here or
# each installs an entry the other cannot remove.
$RemindPs1 = Join-Path $SelfDir 'hooks/prover-remind.ps1'
$RemindSh  = Join-Path $SelfDir 'hooks/prover-remind.sh'
$RemindCmd = 'pwsh -NoProfile -File "' + (ConvertTo-PosixPath $RemindPs1) +
             '" || bash "' + (ConvertTo-PosixPath $RemindSh) + '"'
$RemindEventsCsv = 'UserPromptSubmit,PreToolUse,PostToolUse'

Write-Output 'RoT MoE :: ARM_ROUTER (PowerShell arm)'
Write-Output ('  config dir : ' + $ClaudeDir)
Write-Output ('  settings   : ' + $Settings)

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Output '  FATAL: node not found. Claude Code is a Node application, so if you'
  Write-Output '         can run Claude Code you have node -- check your PATH.'
  exit 2
}

# --- THE DOUBLE-FIRE GUARD (cross-arm parity with ARM_ROUTER.sh) -------------
# MEASURED DEFECT, 2026-08-04. The plugin path and ARM_ROUTER are ADDITIVE, and
# the documentation told the user to take both: hooks/hooks.json already binds
# rot-router on UserPromptSubmit and PreToolUse via ${CLAUDE_PLUGIN_ROOT}, and
# ARM_ROUTER writes an absolute-path entry for the same script on the same two
# events. The router then fires TWICE per prompt -- two marker lines, two gauge
# computations, twice the tokens, on every machine that followed the procedure.
# Counted in a live transcript, one firing attributable to each source.
#
# Refusing is a SUCCESS: the user wanted the router armed and it already is.
$Detect = Join-Path $SelfDir 'hooks/plugin-detect.js'
if ((-not $Force) -and (Test-Path -LiteralPath $Settings) -and (Test-Path -LiteralPath $Detect)) {
  $detectOut = & node $Detect $ClaudeDir 2>$null
  if ($LASTEXITCODE -eq 0) {
    $detectOut | ForEach-Object { Write-Output $_ }
    Write-Output ''
    Write-Output '  ALREADY ARMED BY THE INSTALLED PLUGIN -- nothing to do.'
    Write-Output "  The plugin's hooks.json already binds the router on UserPromptSubmit"
    Write-Output '  and PreToolUse. Adding a settings.json entry too would fire it TWICE'
    Write-Output '  per prompt: two marker lines, two gauges, twice the tokens.'
    Write-Output ''
    Write-Output '  ARM_ROUTER is for installs that are NOT via the marketplace/plugin.'
    Write-Output '  If you really want a second registration: ARM_ROUTER.ps1 -Force'
    exit 0
  }
}

if (-not (Test-Path -LiteralPath $Settings)) {
  Write-Output '  no settings.json found -- creating a minimal one'
  New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
  # No BOM, LF: a file we create sets its own conventions, and these are the
  # ones the engine will then preserve on every later run.
  [System.IO.File]::WriteAllText($Settings, "{}`n", (New-Object System.Text.UTF8Encoding($false)))
}

# --- rule 1: backup ---------------------------------------------------------
if ($DryRun) {
  # Operate on a copy, for the same reason as the bash arm: a flag checked at
  # the write site is one forgotten branch away from writing anyway.
  $DryDir = Join-Path ([System.IO.Path]::GetTempPath()) ('rotmoe-dryrun-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $DryDir | Out-Null
  $DryOrig = $Settings
  $Settings = Join-Path $DryDir 'settings.json'
  Copy-Item -LiteralPath $DryOrig -Destination $Settings -Force
  Write-Output ('  DRY RUN    : nothing will be written to ' + $DryOrig)
}

$Stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = "$Settings.pre-armrouter-$Stamp.bak"
Copy-Item -LiteralPath $Settings -Destination $Backup -Force
Write-Output ('  backup     : ' + $Backup)
Write-Output ('  restore    : Copy-Item "' + $Backup + '" "' + $Settings + '" -Force')

# --- rules 2,3,4,5: the shared engine ---------------------------------------
& node $Merge arm $Settings $RouterCmd $EventsCsv
$rc = $LASTEXITCODE

# The reminder is armed on the same terms as the router: if it cannot be written
# the whole install is rolled back, because a settings.json carrying half the
# hooks is a state no uninstall path was designed for.
if ($rc -eq 0 -or $rc -eq 10) {
  & node $Merge arm $Settings $RemindCmd $RemindEventsCsv
  $rrc = $LASTEXITCODE
  if ($rrc -eq 4 -or $rrc -eq 3) {
    Copy-Item -LiteralPath $Backup -Destination $Settings -Force
    Write-Output ('  AUTO-RESTORED from backup: the reminder could not be armed (exit ' + $rrc + ').')
    exit $rrc
  }
  if ($rrc -eq 0) { $rc = 0 }
}

switch ($rc) {
  4 { Copy-Item -LiteralPath $Backup -Destination $Settings -Force
      Write-Output '  AUTO-RESTORED from backup. settings.json is as it was.'; exit 4 }
  3 { Write-Output '  settings.json was already invalid. Nothing written.'; exit 3 }
  10 { Remove-Item -LiteralPath $Backup -Force
       Write-Output '  already armed -- backup removed, nothing changed.'; exit 0 }
  0 { }
  default { Copy-Item -LiteralPath $Backup -Destination $Settings -Force
            Write-Output ('  unexpected failure (' + $rc + '). AUTO-RESTORED.'); exit $rc }
}

# --- rule 6: show the diff --------------------------------------------------
Write-Output '  --- diff ---'
$a = Get-Content -LiteralPath $Backup
$b = Get-Content -LiteralPath $Settings
$d = Compare-Object $a $b
if ($d) { $d | ForEach-Object { Write-Output ('  ' + $_.SideIndicator + ' ' + $_.InputObject) } }
else    { Write-Output '  (no textual difference)' }
if ($DryRun) {
  Write-Output '  --- the above is what WOULD change ---'
  Write-Output ('  DRY RUN: ' + $DryOrig + ' was NOT modified.')
  Remove-Item -LiteralPath $DryDir -Recurse -Force
  exit 0
}
Write-Output 'RoT MoE :: armed.'
exit 0
