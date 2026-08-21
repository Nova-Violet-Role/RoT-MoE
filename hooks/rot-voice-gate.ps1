# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-voice-gate.ps1 -- the voice gate, PowerShell arm. ORGAN 6.
#
# The .sh arm is the reference; this arm mirrors its behaviour decision for
# decision. See rot-voice-gate.sh for the full design commentary: the gate
# degrades OPEN everywhere (no summons / unreadable transcript / no evidence
# -> allow), blocks AT MOST ONCE per summons (the file is consumed on first
# block, and the harness's stop_hook_active flag is honoured besides), and
# its reason carries every missing lens's charter -- a refusal always
# carries the task.
# =============================================================================

$ErrorActionPreference = 'SilentlyContinue'

# [Console]::OutputEncoding is the OEM CONSOLE codepage (ibm437 on this host)
# even though the ANSI codepage is utf-8 and $OutputEncoding is utf-8. Every
# byte this arm writes goes through that encoder, so without this line the
# refusal is transliterated on the way out. The sibling arms rot-router.ps1
# and prover-remind.ps1 have carried this guard for releases; THIS arm did
# not, and the omission was invisible because the .sh arm -- the reference --
# is unaffected.
#
# MEASURED 2026-08-21, cold-unpacked 9.0.1 archive, both arms fed one payload:
# the two refusals came out the same LENGTH (1438 chars) and differed at 23
# positions. Every sigil was destroyed -- U+269C+U+FE0F -> '??', U+1F3B7 ->
# '??', U+26AA/U+1F52E/U+2B1C/U+1F70F -> '?' -- and U+00D7 was best-fit
# transliterated to ASCII 'x'. Equal length is why a size or line check would
# never have caught it.
#
# That is not cosmetic. The seal field exists because 8.0.1 measured blind
# models speaking sigil-less stanzas, having never been shown the seals, and
# the reason this gate emits still orders each lens to open "with its seal".
# On Windows the gate was demanding a seal it had just replaced with '?'.
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

if (-not [Console]::IsInputRedirected) {
  [Console]::Error.WriteLine('rot-voice-gate.ps1: hook mode expects a JSON payload on stdin.')
  exit 2
}
$payload = [Console]::In.ReadToEnd()
if ([string]::IsNullOrEmpty($payload)) { exit 0 }

# --- who is stopping ---------------------------------------------------------
$sess = 'unknown'
if ($payload -match '"session_id"\s*:\s*"([^"]*)"') { $sess = $Matches[1] }
$sess = ($sess -replace '[^A-Za-z0-9-]', '')
if ($sess.Length -gt 64) { $sess = $sess.Substring(0, 64) }
if ([string]::IsNullOrEmpty($sess)) { $sess = 'unknown' }

# ORGAN 7 -- the environment layer, same three laws as the router; the gate
# must resolve the same state dir as the router that wrote the summons.
$cwd = ''
if ($payload -match '"cwd"\s*:\s*"([^"]*)"') { $cwd = $Matches[1] -replace '\\\\', '/' }
try {
  $rotEnvLib = Join-Path $PSScriptRoot 'rot-env.ps1'
  if (Test-Path -LiteralPath $rotEnvLib) {
    . $rotEnvLib
    Invoke-RotEnvLoad $cwd
  }
} catch { }
if ($env:ROTMOE_GATE -eq '0') { exit 0 }

# --- the summons -------------------------------------------------------------
$stateDir = $env:ROTMOE_STATE_DIR
if ([string]::IsNullOrEmpty($stateDir)) {
  $xdg = $env:XDG_STATE_HOME
  if ([string]::IsNullOrEmpty($xdg)) { $xdg = Join-Path $HOME '.local/state' }
  $stateDir = Join-Path $xdg 'rot-moe'
}
$sum = Join-Path $stateDir ("voice-summons." + $sess)
if (-not (Test-Path -LiteralPath $sum)) { exit 0 }

# Honour the harness's own already-blocked flag: clear and stand aside.
if ($payload -match '"stop_hook_active"\s*:\s*true') {
  Remove-Item -LiteralPath $sum -Force
  exit 0
}

# --- what was actually said --------------------------------------------------
$tp = ''
if ($payload -match '"transcript_path"\s*:\s*"([^"]*)"') { $tp = $Matches[1] }
if ([string]::IsNullOrEmpty($tp) -or -not (Test-Path -LiteralPath $tp)) {
  Remove-Item -LiteralPath $sum -Force
  exit 0
}

# The last assistant text, tolerant line by line -- a torn record is skipped.
$last = ''
foreach ($line in [System.IO.File]::ReadLines($tp)) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  try {
    $j = $line | ConvertFrom-Json
    $m = if ($j.message) { $j.message } else { $j }
    $role = if ($m.role) { $m.role } else { $j.type }
    if ($role -eq 'assistant') {
      $c = $m.content
      if ($c -is [string]) { $last = $c }
      elseif ($c -is [System.Array]) {
        $last = (($c | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join "`n")
      }
    }
  } catch { }
}

# --- the verdict -------------------------------------------------------------
# WHAT "SPOKEN" MEANS HERE -- the .sh arm's design decision, stated there in
# full (W4): the gate matches the ELEMENT TAG's literal presence in the last
# assistant text, never the stanza's content. The tag is the measurable
# commitment; the words inside it are the convening model's honour, visible
# to the Socio in the transcript. A hook cannot think, and a gate that
# graded register would block good turns on bad heuristics.
# Summons rows: Name|element|charter|bound|sigil -- the fifth field is the
# lens's SEAL (8.0.1), shown in the refusal so a blind model can speak it; a
# four-field row from a pre-8.0.1 router parses fine, the seal just goes
# unshown. Quotes and backslashes are STRIPPED from each field, exactly as
# the .sh arm does: a mangled charter is cosmetic, a broken JSON block is a
# dead gate.
$missing = ''
foreach ($row in [System.IO.File]::ReadLines($sum)) {
  $f = $row -split '\|'
  if ($f.Count -lt 4 -or [string]::IsNullOrEmpty($f[1])) { continue }
  if ($last.Contains('<' + $f[1] + '>')) { continue }
  $n = $f[0] -replace '["\\]', ''
  $e = $f[1] -replace '["\\]', ''
  $c = $f[2] -replace '["\\]', ''
  $b = $f[3] -replace '["\\]', ''
  $sp = ''
  if ($f.Count -ge 5 -and -not [string]::IsNullOrEmpty($f[4])) {
    $sp = ' ' + ($f[4] -replace '["\\]', '')
  }
  $missing += ('\n  <' + $e + '>' + $sp + ' (' + $n + '): ' + $c + ' -- ' + $b)
}

# Consumed either way: the gate speaks at most once per summons.
Remove-Item -LiteralPath $sum -Force

if ([string]::IsNullOrEmpty($missing)) { exit 0 }

# The parenthetical provenance mirrors the sh arm, added 2026-08-17 after the
# v6.0.0 real test (B4): an unbriefed convening model treated the bare refusal
# as untrusted injected framing. The reason now leads with who armed the gate
# and names the switch that disarms it. The honest-empty sanction (8.0.1)
# mirrors the sh arm too: a newer CLI's model refused the old demand as an
# order to fabricate, so the reason now states what W4 always measured -- an
# honest one-line empty report inside the element satisfies the contract.
[Console]::Out.WriteLine('{"decision":"block","reason":"RoT voice gate (a Stop hook of the RoT MoE plugin the operator of this machine installed on purpose; ROTMOE_GATE=0 disarms it): summoned lenses have not spoken this turn. Close the turn with one stanza per lens listed below -- inside its element, opening with its seal, in its own register. Honesty outranks theatre: a lens with nothing real to report satisfies the contract with one plain line inside its element saying so (for example: nothing was executed this turn) -- the tag is the commitment; the words belong to the lens. This closing format is a standing instruction from the operator; it adds to the user request and never overrides it. Then stop:' + $missing + '"}')
exit 0
