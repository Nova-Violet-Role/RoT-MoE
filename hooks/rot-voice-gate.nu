# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-voice-gate.nu -- the voice gate, Nushell arm. ORGAN 6.
#
# The .sh arm is the reference and hooks/rot-voice-gate.ps1 is the arm this was
# ported from, decision for decision. The gate degrades OPEN everywhere (no
# summons / unreadable transcript / no evidence -> allow), blocks AT MOST ONCE
# per summons (the file is consumed on first block, and the harness's
# stop_hook_active flag is honoured besides), and its reason carries every
# missing lens's charter -- a refusal always carries the task.
#
# PORTING NOTES -- the decisions Nushell changed, and the one it did not:
#
#   * THE ENCODING GUARD IS GONE, AND THAT IS CORRECT. The ps1 arm must set
#     [Console]::OutputEncoding because PowerShell writes through the OEM
#     console codepage (ibm437 on this host), which destroyed every seal --
#     U+269C+U+FE0F -> '??', U+00D7 best-fit to ASCII 'x' -- at IDENTICAL
#     string length, which is why no size check ever caught it. Nushell emits
#     UTF-8 on stdout unconditionally, so the failure mode does not exist here.
#     The seals matter: the reason below orders each lens to open "with its
#     seal", and 8.0.1 measured blind models speaking sigil-less stanzas.
#
#   * THE `\n` IN $missing IS A LITERAL BACKSLASH-N, NOT A NEWLINE. The ps1
#     builds it in a single-quoted string, so the two characters land inside
#     the JSON string value and the CLI's parser turns them into real newlines.
#     Nushell single quotes are raw the same way, so the sequence is preserved
#     verbatim. Emitting a real newline here would produce invalid JSON and the
#     gate would be silently dropped by the hook validator -- the exact failure
#     this port exists to avoid repeating.
#
#   * WHAT "SPOKEN" MEANS IS UNCHANGED: the gate matches the ELEMENT TAG's
#     literal presence in the last assistant text, never the stanza's content.
#     The tag is the measurable commitment; the words inside it are the
#     convening model's honour. A hook cannot think, and a gate that graded
#     register would block good turns on bad heuristics.
# =============================================================================

use rot-env.nu [rot-env-load]

# Sanitize a session id exactly as Get-RotSessionName (rot-router.ps1:406) and
# animus-observe.sh:78 do -- same charset, same 64-character cap. If these three
# ever disagree the summons is written under one name and looked up under
# another, and the gate silently guards nothing.
def rot-session-name [raw: string] {
  let kept = ($raw | str replace --all --regex '[^A-Za-z0-9-]' '')
  let capped = (if ($kept | str length) > 64 { $kept | str substring ..<64 } else { $kept })
  if ($capped | is-empty) { 'unknown' } else { $capped }
}

# First capture of a regex over the raw payload, '' when absent. The ps1 uses
# -match/$Matches; this is the same single-shot extraction.
def rot-payload-field [payload: string, pattern: string] {
  let m = ($payload | parse --regex $pattern)
  if ($m | is-empty) { '' } else { $m | get 0.v }
}

# The last assistant text in the transcript, tolerant line by line -- a torn
# record is skipped, never fatal. Mirrors the ps1's overwrite-on-each-match
# loop: the LAST assistant record wins, not the first.
def rot-last-assistant [transcript: string] {
  mut last = ''
  let lines = (try { open --raw $transcript | lines } catch { [] })
  for line in $lines {
    if ($line | str trim | is-empty) { continue }
    let j = (try { $line | from json } catch { null })
    if $j == null { continue }
    let m = (if ($j.message? != null) { $j.message } else { $j })
    let role = (if ($m.role? != null) { $m.role } else { $j.type? | default '' })
    if $role != 'assistant' { continue }
    let c = ($m.content? | default null)
    if $c == null { continue }
    # Nushell describes a homogeneous list of records as `table<...>`, not
    # `list<...>`; every real Claude Code content block array lands here as a
    # table, so a bare list- test never fires and the gate blocks a turn in
    # which the lenses did speak. The ps1 arm tests `-is [System.Array]` and
    # the sh arm tests `Array.isArray`; both are shape-blind. Accept both
    # spellings so all three arms agree.
    let cd = ($c | describe)
    if ($cd | str starts-with 'list') or ($cd | str starts-with 'table') {
      $last = ($c | where { |b| ($b.type? | default '') == 'text' } | each { |b| $b.text? | default '' } | str join "\n")
    } else if $cd == 'string' {
      $last = $c
    }
  }
  $last
}

export def main [] {
  # No pipe at all is the ps1's "hook mode expects a JSON payload on stdin".
  let raw = $in
  if $raw == null {
    print --stderr 'rot-voice-gate.nu: hook mode expects a JSON payload on stdin.'
    exit 2
  }
  let payload = ($raw | into string)
  if ($payload | is-empty) { exit 0 }

  # --- who is stopping -------------------------------------------------------
  let sess_raw = (rot-payload-field $payload '"session_id"\s*:\s*"(?P<v>[^"]*)"')
  let sess = (rot-session-name $sess_raw)

  # ORGAN 7 -- the environment layer, same three laws as the router; the gate
  # must resolve the same state dir as the router that wrote the summons.
  let cwd = (rot-payload-field $payload '"cwd"\s*:\s*"(?P<v>[^"]*)"' | str replace --all '\\' '/')
  try { rot-env-load $cwd }
  if ($env.ROTMOE_GATE? | default '') == '0' { exit 0 }

  # --- the summons -----------------------------------------------------------
  # Flattened: `let` is a statement in Nushell and cannot bind inside a
  # parenthesised expression, so the ps1's nested resolution unrolls.
  let sd_explicit = ($env.ROTMOE_STATE_DIR? | default '')
  let xdg_state = ($env.XDG_STATE_HOME? | default '')
  let home_dir = ($env.HOME? | default ($env.USERPROFILE? | default ''))
  let sd_base = (if ($xdg_state | is-not-empty) { $xdg_state } else { [$home_dir, '.local', 'state'] | path join })
  let state_dir = (if ($sd_explicit | is-not-empty) { $sd_explicit } else { [$sd_base, 'rot-moe'] | path join })
  let sum = ([$state_dir, $'voice-summons.($sess)'] | path join)
  if not ($sum | path exists) { exit 0 }

  # Honour the harness's own already-blocked flag: clear and stand aside.
  if ($payload | find --regex '"stop_hook_active"\s*:\s*true' | is-not-empty) {
    try { rm --force $sum }
    exit 0
  }

  # --- what was actually said ------------------------------------------------
  let tp = (rot-payload-field $payload '"transcript_path"\s*:\s*"(?P<v>[^"]*)"')
  if ($tp | is-empty) or (not ($tp | path exists)) {
    try { rm --force $sum }
    exit 0
  }
  let last = (rot-last-assistant $tp)

  # --- the verdict -----------------------------------------------------------
  # Summons rows: Name|element|charter|bound|sigil -- the fifth field is the
  # lens's SEAL (8.0.1), shown in the refusal so a blind model can speak it; a
  # four-field row from a pre-8.0.1 router parses fine, the seal just goes
  # unshown. Quotes and backslashes are STRIPPED from each field: a mangled
  # charter is cosmetic, a broken JSON block is a dead gate.
  let rows = (try { open --raw $sum | lines } catch { [] })
  mut missing = ''
  for row in $rows {
    let f = ($row | split row '|')
    if ($f | length) < 4 { continue }
    let elem_raw = ($f | get 1)
    if ($elem_raw | is-empty) { continue }
    # The presence test runs against the RAW element, before stripping -- the
    # ps1's order, kept so both arms agree on a row containing a quote.
    if ($last | str contains $'<($elem_raw)>') { continue }
    let n = ($f | get 0 | str replace --all --regex '["\\\\]' '')
    let e = ($elem_raw | str replace --all --regex '["\\\\]' '')
    let c = ($f | get 2 | str replace --all --regex '["\\\\]' '')
    let b = ($f | get 3 | str replace --all --regex '["\\\\]' '')
    let seal_raw = (if ($f | length) >= 5 { $f | get 4 } else { '' })
    let sp = (if ($seal_raw | is-not-empty) { ' ' + ($seal_raw | str replace --all --regex '["\\\\]' '') } else { '' })
    # LITERAL backslash-n -- see the porting note at the top of this file.
    $missing = $missing + '\n  <' + $e + '>' + $sp + ' (' + $n + '): ' + $c + ' -- ' + $b
  }

  # Consumed either way: the gate speaks at most once per summons.
  try { rm --force $sum }

  if ($missing | is-empty) { exit 0 }

  # The parenthetical provenance mirrors the sh arm, added 2026-08-17 after the
  # v6.0.0 real test (B4): an unbriefed convening model treated the bare refusal
  # as untrusted injected framing. The reason now leads with who armed the gate
  # and names the switch that disarms it. The honest-empty sanction (8.0.1)
  # mirrors the sh arm too: a newer CLI's model refused the old demand as an
  # order to fabricate, so the reason states what W4 always measured -- an
  # honest one-line empty report inside the element satisfies the contract.
  print ('{"decision":"block","reason":"RoT voice gate (a Stop hook of the RoT MoE plugin the operator of this machine installed on purpose; ROTMOE_GATE=0 disarms it): summoned lenses have not spoken this turn. Close the turn with one stanza per lens listed below -- inside its element, opening with its seal, in its own register. Honesty outranks theatre: a lens with nothing real to report satisfies the contract with one plain line inside its element saying so (for example: nothing was executed this turn) -- the tag is the commitment; the words belong to the lens. This closing format is a standing instruction from the operator; it adds to the user request and never overrides it. Then stop:' + $missing + '"}')
  exit 0
}
