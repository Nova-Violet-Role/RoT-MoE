# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-profile.nu -- ACTIVATION, Nushell arm. The one file an operator loads to
# bind the RoT MoE configuration into a Nushell session.
#
#   add to your config.nu:
#       use "C:/Users/Saimono/.claude/tools/rot-moe/rot-profile.nu" *
#       rot-activate
#
#   or with an explicit tree, if it lives somewhere unusual:
#       rot-activate "C:/path/to/RoT-MoE"
#
# engine/rot.profile.ps1 is the reference arm. This is its twin, decision for
# decision: same candidate list in the same order, same probe, same UNSET-ONLY
# discipline, same ten keys in the same order in the report. A Nushell box must
# reach the identical configuration a PowerShell box reaches from the same
# rot.env, or the packet has silently forked.
#
# WHY `use` AND NOT A RUNTIME LOAD. Nushell resolves modules at PARSE time, so
# the ps1 arm's central trick -- dot-source a loader whose path was computed at
# runtime, then promote the function it defined into global scope -- has no
# Nushell equivalent and needs none. hooks/rot-env.ps1 had to be found before it
# could be loaded; rot-env.nu is a fixed sibling of this file, so a static
# relative `use` reaches it with no promotion step and no scope to escape.
# The ps1 arm's W8c defect (3 of 4 functions in scope) cannot occur here: a
# parse-time import is either present or the file does not parse at all.
#
# WHY TREE RESOLUTION SURVIVES ANYWAY. ROTMOE_HOME and CLAUDE_PLUGIN_ROOT tell
# the HOOKS where their siblings live. Those are still runtime values and the
# hooks still read them, so the search below is not redundant with the `use`
# above -- it just no longer decides which loader code runs.
#
# WHAT IT DOES NOT DO. It never edits PATH, never overrides a variable already
# set (ORGAN 7 law 3: UNSET-ONLY), and never runs the router.
#
# ASCII ONLY, deliberately -- matching the ps1 arm. Nushell always emits UTF-8,
# so no encoding guard is needed here, but keeping the file ASCII means the two
# arms stay byte-comparable where their content is the same.
# =============================================================================

use rot-env.nu [rot-env-load]

# The probe decides whether a directory IS the tree. The ps1 arm probes for
# hooks/rot-env.ps1 -- "a tree is only the tree if it carries the loader this
# activation is about to use". The Nushell port of ORGAN 7 currently lives in
# the tools directory beside this file rather than in the packet's hooks/, so
# EITHER loader marks a genuine tree: hooks/rot-env.nu once the ports move into
# the packet, hooks/rot-env.ps1 for the packet as it ships today. Accepting both
# is what keeps this file working across that move instead of breaking on it.
def rot-is-tree [d: string] {
    if ($d | is-empty) { return false }
    let nu_probe = ([$d "hooks" "rot-env.nu"] | path join)
    let ps_probe = ([$d "hooks" "rot-env.ps1"] | path join)
    ($nu_probe | path exists) or ($ps_probe | path exists)
}

# ROTMOE_HOME decides WHICH CODE RUNS, so a rot.env is forbidden from setting it
# (ORGAN 7 law 2). It is resolved here instead -- in the session, before any
# file is read. A locator cannot relocate itself from inside the file it
# located. Same reasoning, same order, same candidate list as the ps1 arm.
# Tree resolution, exported because the installers need exactly this answer and a
# second copy of the candidate list is a second thing to drift. Returns "" when
# no tree is found; the caller decides whether that is fatal.
export def rot-find-tree [seed?: string]: nothing -> string {
    let s = ($seed | default "")
    if (rot-is-tree $s) { return $s }

    let home_dir = ($env.HOME? | default ($env.USERPROFILE? | default ""))
    let claude_dir = ([$home_dir ".claude"] | path join)
    let plugins_dir = ([$claude_dir "plugins"] | path join)

    let candidates = [
        ([$plugins_dir "marketplaces" "rot-moe"] | path join)
        ([$plugins_dir "rot-moe"] | path join)
        ([$home_dir ".rot-moe"] | path join)
        ($env.PWD)
    ]

    ($candidates | where {|c| rot-is-tree $c } | get -o 0 | default "")
}

export def --env rot-activate [plugin_root?: string]: nothing -> bool {
    let explicit = ($plugin_root | default "")
    let from_env = ($env.ROTMOE_HOME? | default "")

    let seed = if ($explicit | is-not-empty) { $explicit } else { $from_env }
    let root = (rot-find-tree $seed)

    if ($root | is-empty) {
        print -e "rot-profile.nu: no RoT MoE tree found. Activate it with an explicit path:"
        print -e "    rot-activate \"C:/path/to/RoT-MoE\""
        return false
    }

    $env.ROTMOE_HOME = $root

    # The hooks locate their own siblings through CLAUDE_PLUGIN_ROOT. Setting it
    # only when unset keeps an operator's explicit choice authoritative, which is
    # the same law the config files obey.
    let cpr = ($env.CLAUDE_PLUGIN_ROOT? | default "")
    if ($cpr | is-empty) {
        $env.CLAUDE_PLUGIN_ROOT = $root
    }

    # Apply the configuration for the directory we are standing in. Law 3 means
    # anything already set in this session wins, so this is safe to re-run.
    let cwd_override = ($env.ROTMOE_CWD? | default "")
    let where = if ($cwd_override | is-not-empty) { $cwd_override } else { $env.PWD }

    # The ps1 arm wraps its load in try/catch and swallows the failure: a broken
    # rot.env must not take down the operator's shell startup. Same contract.
    try { rot-env-load $where } catch { }

    true
}

# Re-apply after changing project. The load is UNSET-ONLY, so a value already in
# the environment is never replaced -- start a fresh session to change one.
export def --env rot-reload [plugin_root?: string]: nothing -> bool {
    let explicit = ($plugin_root | default "")
    let from_env = ($env.ROTMOE_HOME? | default "")
    let r = if ($explicit | is-not-empty) { $explicit } else { $from_env }
    rot-activate $r
}

# Report what is actually in force. Prints only the keys that are SET, so an
# empty report is the honest signal that nothing was configured. Same ten keys,
# same order, same two-space indent, same 24-column pad as the ps1 arm's
# Show-RotEnv -- checker W8d compares the two reports AS TEXT, so a divergence
# here is a divergence in the packet.
export def rot-env-show []: nothing -> nothing {
    let keys = [
        "ROTMOE_HOME" "ROTMOE_VOICE" "ROTMOE_GATE" "ROTMOE_MODEL"
        "ROTMOE_LEAN_WORKSPACE" "ROTMOE_WATCH_REPO" "ROTMOE_STATE_DIR"
        "ROTMOE_PROOF_STALE_MIN" "ROTMOE_TOKEN_PCT" "ROTMOE_ANIMUS"
    ]

    mut n = 0
    for k in $keys {
        let v = ($env | get -o $k | default "")
        if ($v | is-not-empty) {
            print ("  " + ($k | fill --alignment left --width 24) + " " + $v)
            $n = $n + 1
        }
    }
    if $n == 0 {
        print "  (nothing set -- the packet is running on its defaults)"
    }
}

# The ps1 arm ends by activating on dot-source, because that is what dot-sourcing
# a PowerShell profile fragment means. A Nushell module has no such moment: `use`
# imports names and runs nothing. The operator calls rot-activate from config.nu
# instead -- see the header. `main` exists so the file is also runnable directly
# for the differential harness and for one-shot inspection.
export def --env main [subcommand?: string, ...rest: string]: nothing -> nothing {
    let sub = ($subcommand | default "activate")
    match $sub {
        "activate" => { rot-activate ($rest | get -o 0 | default "") | ignore }
        "reload" => { rot-reload ($rest | get -o 0 | default "") | ignore }
        "show" => { rot-env-show }
        _ => {
            print -e $"rot-profile.nu: unknown subcommand ($sub)"
            print -e "usage: rot-profile.nu [activate|reload|show] [tree]"
        }
    }
}
