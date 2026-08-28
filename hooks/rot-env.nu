# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-env.nu -- ORGAN 7, the environment layer, Nushell arm.
#
# The .sh library is the reference and hooks/rot-env.ps1 is the arm this file
# was ported from, decision for decision. The three laws are unchanged:
#
#   1. PARSED, never sourced -- a project's config file is DATA. Nushell makes
#      this structural rather than disciplinary: there is no `.` operator
#      reachable from here, so a rot.env cannot execute even by mistake.
#   2. DECLARED-ONLY -- the DTD's ENV.n entities are the whole vocabulary;
#      ROTMOE_ENV itself is never file-settable, and neither is ROTMOE_HOME.
#   3. UNSET-ONLY -- the live environment outranks every file; the first file
#      to set a key wins over every later file.
#
# Load order: $env.ROTMOE_ENV, <project>/.rot-moe/rot.env, then the operator's
# global $XDG_CONFIG_HOME/rot-moe/rot.env.
#
# PORTING NOTES -- where Nushell forced a decision the ps1 never had to make:
#
#   * `def --env` is what makes this an environment layer at all. A plain `def`
#     mutates a scope that dies at the closing brace; the ps1's
#     [Environment]::SetEnvironmentVariable mutates the process. `--env` is the
#     only construct that reproduces the ps1's reach into the caller.
#   * The ps1 tests `$null -ne [Environment]::GetEnvironmentVariable($k)`, and
#     that API is CASE-INSENSITIVE on Windows. Nushell's `in` against a record's
#     columns is case-SENSITIVE, so a case-insensitive comparison is written out
#     explicitly below. Getting this wrong would let a rot.env overwrite a live
#     `rotmoe_voice` -- law 3 broken in the one direction that matters.
#   * The vocabulary test stays case-SENSITIVE: the ps1 uses `-cnotcontains`,
#     the c-prefixed operator, deliberately. Both halves are intentional and
#     they are not the same half.
# =============================================================================

# The value of a DTD entity line: the text between the FIRST and the LAST
# double quote. Mirrors the ps1's IndexOf/LastIndexOf pair -- note the second
# search runs over the REMAINDER, not the original line, which is why this is
# two steps and not one regex.
def rot-entity-value [line: string] {
  mut v = $line
  let q1 = ($v | str index-of '"')
  if $q1 >= 0 { $v = ($v | str substring ($q1 + 1)..) }
  let q2 = ($v | str index-of --end '"')
  if $q2 >= 0 { $v = ($v | str substring ..<$q2) }
  $v
}

# Read the declared ENV vocabulary out of the contract. A missing or unreadable
# DTD yields an empty list, which the caller treats as "do nothing" -- the ps1's
# two `return` guards, folded into one value.
def rot-env-vocab [dtd: string] {
  if not ($dtd | path exists) { return [] }
  let lines = (try { open --raw $dtd | lines } catch { [] })
  $lines
  | where { |l| $l | str contains '<!ENTITY ENV.' }
  | each { |l| rot-entity-value $l | split row '|' | get 0 }
}

# Resolve the contract the same way every other organ does: this script's own
# directory first, then the installed plugin root. The ps1 checks existence
# rather than readability here; kept as-is so the two arms fail over together.
def rot-env-dtd [] {
  let here = ([($env.FILE_PWD? | default '.'), 'rot-voice.dtd'] | path join)
  if ($here | path exists) { return $here }
  let root = ($env.CLAUDE_PLUGIN_ROOT? | default '')
  if ($root | is-not-empty) {
    let alt = ([$root, 'hooks', 'rot-voice.dtd'] | path join)
    if ($alt | path exists) { return $alt }
  }
  # Last resort: the installed 9.0.2 tree, which is where the live hooks read
  # their contract from. Named explicitly rather than guessed at runtime.
  let pinned = 'C:/Users/Saimono/.claude/plugins/cache/nestor-plugins/rot-moe/9.0.2/hooks/rot-voice.dtd'
  if ($pinned | path exists) { return $pinned }
  ''
}

# ORGAN 7 proper. `--env` so the assignments outlive this frame, exactly as the
# ps1's process-level writes do.
export def --env rot-env-load [
  project_dir: string = ''   # the payload's cwd; '' skips the project file
] {
  let dtd = (rot-env-dtd)
  if ($dtd | is-empty) { return }

  let vocab = (rot-env-vocab $dtd)
  if ($vocab | is-empty) { return }

  # `let` is a statement, not an expression, so the ps1's inline ternary cannot
  # be transcribed literally -- it binds in three steps here. HOME is absent on
  # a stock Windows shell, hence the USERPROFILE fallback the ps1 gets for free
  # from PowerShell's own $HOME automatic variable.
  let xdg_raw = ($env.XDG_CONFIG_HOME? | default '')
  let home_dir = ($env.HOME? | default ($env.USERPROFILE? | default ''))
  let xdg = (if ($xdg_raw | is-not-empty) { $xdg_raw } else { [$home_dir, '.config'] | path join })

  mut files = []
  let explicit = ($env.ROTMOE_ENV? | default '')
  if ($explicit | is-not-empty) { $files = ($files | append $explicit) }
  if ($project_dir | is-not-empty) {
    $files = ($files | append ([$project_dir, '.rot-moe', 'rot.env'] | path join))
  }
  $files = ($files | append ([$xdg, 'rot-moe', 'rot.env'] | path join))

  for f in $files {
    if not ($f | path exists) { continue }
    let lines = (try { open --raw $f | lines } catch { [] })
    for l in $lines {
      let m = ($l | parse --regex '^(?P<k>ROTMOE_[A-Z_]+)=(?P<v>.*)$')
      if ($m | is-empty) { continue }
      let k = ($m | get 0.k)
      let v = ($m | get 0.v)

      # Law 2, both exclusions, then the declared vocabulary -- case-sensitive,
      # matching the ps1's -cnotcontains.
      if $k == 'ROTMOE_ENV' { continue }
      if $k == 'ROTMOE_HOME' { continue }
      if not ($k in $vocab) { continue }

      # Law 3, unset-only. Case-INSENSITIVE presence test, because the API the
      # ps1 arm consults is case-insensitive on this platform.
      let ku = ($k | str uppercase)
      let live = ($env | columns | any { |c| ($c | str uppercase) == $ku })
      if $live { continue }

      # A literal store: no expansion of the value, ever.
      load-env { $k: $v }
    }
  }
}

# Standalone entry point, used by the differential harness to dump the resulting
# ROTMOE_* surface as JSON so the two arms can be compared byte for byte.
export def main [project_dir: string = ''] {
  rot-env-load $project_dir
  $env
  | transpose k v
  | where { |r| ($r.k | str starts-with 'ROTMOE_') }
  | sort-by k
  | reduce --fold {} { |it, acc| $acc | upsert $it.k $it.v }
  | to json --raw
}
