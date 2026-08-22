# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot.profile.ps1 -- ACTIVATION, PowerShell arm. The one file an operator
# dot-sources to bind the RoT MoE configuration into a PowerShell session, on
# Windows PowerShell 5.1 and PowerShell 7+.
#
#   add to your $PROFILE:
#       . "C:/path/to/RoT-MoE/engine/rot.profile.ps1"
#
#   or with an explicit tree, if it lives somewhere unusual:
#       . "C:/path/to/RoT-MoE/engine/rot.profile.ps1" "C:/path/to/RoT-MoE"
#
# engine/rot.bashrc is the reference. This is its twin, decision for decision,
# and checker/env-wiring.sh W8 asserts the two reach IDENTICAL values from the
# same rot.env. That assertion is the whole point of shipping two files: a
# Windows box without bash gets the same configuration a mac gets, or the
# packet has silently forked.
#
# It ships beside engine/rot-lean.md, engine/rot.env.example and
# engine/rot.bashrc: the engine specification, the configuration it accepts,
# and both activations that apply it are one organ, not five loose files.
#
# WHY NOT A MODULE. Import-Module runs the manifest in its own session state,
# so a module would have to export its variables back out explicitly and would
# still not survive the operator running it before $PROFILE finished. Dot-
# sourcing is what $PROFILE already does to everything else it loads, and it is
# the exact analogue of sourcing rot.bashrc. There is no .psd1 to keep in sync.
#
# WHY NOT Set-DotEnv. It is a third-party command, it is not installed here,
# and it sets ANY key it finds -- including PATH. ORGAN 7 law 2 says the DTD's
# ENV.n entities are the whole vocabulary. A generic dotenv loader discards
# that law by design, which is exactly what lean/Proofs/RotEnvWiring.lean's
# load_declared_only theorem forbids.
#
# WHAT IT DOES NOT DO. It never edits your PATH, never overrides a variable you
# already exported (ORGAN 7 law 3: UNSET-ONLY), and never runs the router. It
# resolves the tree, dot-sources the loader, and applies your rot.env.
#
# ASCII ONLY, deliberately. hooks/rot-voice-gate.ps1 shipped 8.0.1 emitting
# mojibake because a PowerShell host with a non-UTF-8 output encoding mangles
# every non-ASCII byte. No glyph in this file means no encoding guard needed.
# =============================================================================

# ROTMOE_HOME decides WHICH CODE RUNS, so a rot.env is forbidden from setting
# it (ORGAN 7 law 2). It is resolved here instead -- in the session, before any
# file is read. A locator cannot relocate itself from inside the file it
# located. Same reasoning, same order, same candidate list as rot.bashrc.
function Invoke-RotActivate {
  [CmdletBinding()]
  param([string] $PluginRoot = '')

  $root = $PluginRoot
  if ([string]::IsNullOrEmpty($root)) { $root = $env:ROTMOE_HOME }

  # The probe file is the PowerShell arm of ORGAN 7. rot.bashrc probes for
  # rot-env.sh for the same reason: a tree is only "the tree" if it carries the
  # loader THIS activation is about to use.
  $probe = { param($d) -not [string]::IsNullOrEmpty($d) -and (Test-Path -LiteralPath (Join-Path (Join-Path $d 'hooks') 'rot-env.ps1')) }

  if (-not (& $probe $root)) {
    $root = ''
    $claude = Join-Path $HOME '.claude'
    $plugins = Join-Path $claude 'plugins'
    foreach ($c in @(
      (Join-Path (Join-Path $plugins 'marketplaces') 'rot-moe'),
      (Join-Path $plugins 'rot-moe'),
      (Join-Path $HOME '.rot-moe'),
      $PWD.Path
    )) {
      if (& $probe $c) { $root = $c; break }
    }
  }

  if ([string]::IsNullOrEmpty($root)) {
    [Console]::Error.WriteLine('rot.profile.ps1: no RoT MoE tree found. Dot-source it with an explicit path:')
    [Console]::Error.WriteLine('    . "C:/path/to/RoT-MoE/engine/rot.profile.ps1" "C:/path/to/RoT-MoE"')
    return $false
  }

  $env:ROTMOE_HOME = $root

  # The hooks locate their own siblings through CLAUDE_PLUGIN_ROOT. Setting it
  # only when unset keeps an operator's explicit choice authoritative, which is
  # the same law the config files obey.
  if ([string]::IsNullOrEmpty($env:CLAUDE_PLUGIN_ROOT)) {
    $env:CLAUDE_PLUGIN_ROOT = $root
  }

  # ORGAN 7 -- hooks/rot-env.ps1. A library: dot-sourcing defines
  # Invoke-RotEnvLoad and sets nothing by itself.
  #
  # THE ASYMMETRY THAT MAKES THIS FILE NOT A TRANSLATION. In POSIX sh, `.` from
  # inside a function defines the sourced functions in the SHELL, so rot.bashrc
  # gets rot_env_load into the operator's namespace for free. PowerShell scopes
  # a dot-source to the caller -- here, to Invoke-RotActivate -- so the loader
  # would vanish the instant this function returned. The operator would then have
  # ROTMOE_HOME set, values applied, and no Invoke-RotEnvLoad to re-run.
  #
  # checker/env-wiring.sh W8c caught exactly this on the assertion's first run:
  # 3 of 4 functions in scope. The promotion below is the fix, and W8c is the
  # thing that stops it silently regressing.
  $loader = Join-Path (Join-Path $root 'hooks') 'rot-env.ps1'
  try {
    . $loader
  } catch {
    [Console]::Error.WriteLine('rot.profile.ps1: the ORGAN 7 loader failed to load: ' + $_.Exception.Message)
    return $false
  }

  $cmd = Get-Command Invoke-RotEnvLoad -ErrorAction SilentlyContinue
  if (-not $cmd) {
    [Console]::Error.WriteLine('rot.profile.ps1: hooks/rot-env.ps1 did not define Invoke-RotEnvLoad')
    return $false
  }
  # Publish it where the operator can actually reach it, matching what sourcing
  # rot.bashrc gives a POSIX shell.
  Set-Item -Path 'function:global:Invoke-RotEnvLoad' -Value $cmd.ScriptBlock

  # Apply the configuration for the directory we are standing in. Law 3 means
  # anything already set in this session wins, so this is safe to re-run.
  $where = $env:ROTMOE_CWD
  if ([string]::IsNullOrEmpty($where)) { $where = $PWD.Path }
  try { Invoke-RotEnvLoad -ProjectDir $where | Out-Null } catch { }

  return $true
}

# Re-apply after changing project. The load is UNSET-ONLY, so a value already
# in the environment is never replaced -- start a fresh session to change one.
function Invoke-RotReload {
  [CmdletBinding()]
  param([string] $PluginRoot = '')
  $r = $PluginRoot
  if ([string]::IsNullOrEmpty($r)) { $r = $env:ROTMOE_HOME }
  return (Invoke-RotActivate -PluginRoot $r)
}

# Report what is actually in force. Prints only the keys that are SET, so an
# empty report is the honest signal that nothing was configured. Same ten keys,
# same order, same two-space indent as rot_env_show -- W8d compares the two
# reports as text, so a divergence here is a divergence in the packet.
function Show-RotEnv {
  [CmdletBinding()]
  param()
  $n = 0
  foreach ($k in @(
    'ROTMOE_HOME', 'ROTMOE_VOICE', 'ROTMOE_GATE', 'ROTMOE_MODEL',
    'ROTMOE_LEAN_WORKSPACE', 'ROTMOE_WATCH_REPO', 'ROTMOE_STATE_DIR',
    'ROTMOE_PROOF_STALE_MIN', 'ROTMOE_TOKEN_PCT', 'ROTMOE_ANIMUS'
  )) {
    $v = [Environment]::GetEnvironmentVariable($k, 'Process')
    if (-not [string]::IsNullOrEmpty($v)) {
      Write-Output ('  ' + $k.PadRight(24) + ' ' + $v)
      $n = $n + 1
    }
  }
  if ($n -eq 0) {
    Write-Output '  (nothing set -- the packet is running on its defaults)'
  }
}

# rot.bashrc ends with `rot_activate "${1:-}"`. A dot-sourced PowerShell script
# receives its arguments in $args, so this is the same line: activate with the
# explicit tree when one was given, otherwise resolve it.
$rotProfileArg = ''
if ($args.Count -ge 1) { $rotProfileArg = [string]$args[0] }
Invoke-RotActivate -PluginRoot $rotProfileArg | Out-Null
Remove-Variable -Name rotProfileArg -ErrorAction SilentlyContinue
