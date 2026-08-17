# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-env.ps1 -- ORGAN 7, the environment layer, PowerShell arm. The .sh
# library is the reference; same three laws, decision for decision:
#   1. PARSED, never dot-sourced -- a project's config file is DATA.
#   2. DECLARED-ONLY -- the DTD's ENV.n entities are the whole vocabulary;
#      ROTMOE_ENV itself is never file-settable.
#   3. UNSET-ONLY -- the live environment outranks every file; first file
#      to set a key wins over later files.
# Load order: $env:ROTMOE_ENV, <project>/.rot-moe/rot.env, then the
# operator's global $XDG_CONFIG_HOME/rot-moe/rot.env.
# =============================================================================

function Invoke-RotEnvLoad {
  param([string] $ProjectDir)

  $dtd = Join-Path $PSScriptRoot 'rot-voice.dtd'
  if (-not (Test-Path -LiteralPath $dtd)) {
    if ($env:CLAUDE_PLUGIN_ROOT) { $dtd = Join-Path (Join-Path $env:CLAUDE_PLUGIN_ROOT 'hooks') 'rot-voice.dtd' }
  }
  if (-not (Test-Path -LiteralPath $dtd)) { return }

  $vocab = @()
  foreach ($l in [System.IO.File]::ReadLines($dtd)) {
    if ($l -like '*<!ENTITY ENV.*') {
      $v = [string]$l
      $q = $v.IndexOf('"'); if ($q -ge 0) { $v = $v.Substring($q + 1) }
      $q = $v.LastIndexOf('"'); if ($q -ge 0) { $v = $v.Substring(0, $q) }
      $vocab += ($v -split '\|')[0]
    }
  }
  if ($vocab.Count -eq 0) { return }

  $xdg = $env:XDG_CONFIG_HOME
  if ([string]::IsNullOrEmpty($xdg)) { $xdg = Join-Path $HOME '.config' }
  $files = @()
  if ($env:ROTMOE_ENV) { $files += $env:ROTMOE_ENV }
  if ($ProjectDir) { $files += (Join-Path (Join-Path $ProjectDir '.rot-moe') 'rot.env') }
  $files += (Join-Path (Join-Path $xdg 'rot-moe') 'rot.env')

  foreach ($f in $files) {
    if (-not (Test-Path -LiteralPath $f)) { continue }
    foreach ($l in [System.IO.File]::ReadLines($f)) {
      if ($l -notmatch '^(ROTMOE_[A-Z_]+)=(.*)$') { continue }
      $k = $Matches[1]; $v = $Matches[2]
      if ($k -eq 'ROTMOE_ENV') { continue }
      if ($k -eq 'ROTMOE_HOME') { continue }
      if ($vocab -cnotcontains $k) { continue }
      # Unset-only, and assignment is a literal store -- no expansion of $v.
      if ($null -ne [Environment]::GetEnvironmentVariable($k)) { continue }
      [Environment]::SetEnvironmentVariable($k, $v)
    }
  }
}
