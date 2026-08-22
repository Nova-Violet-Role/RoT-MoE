# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# rot.bashrc -- ACTIVATION. The one file an operator sources to bind the RoT MoE
# configuration into a shell, on macOS, Linux, and Windows under git-bash/MSYS.
#
#   add to ~/.bashrc, ~/.zshrc or ~/.profile:
#       . /path/to/RoT-MoE/engine/rot.bashrc
#
#   or with an explicit tree, if it lives somewhere unusual:
#       . /path/to/RoT-MoE/engine/rot.bashrc /path/to/RoT-MoE
#
# It ships beside engine/rot-lean.md and engine/rot.env.example: the engine
# specification, the configuration it accepts, and the activation that applies
# it are one organ, not three loose files.
#
# WHY THIS IS NOT A BASH SCRIPT DESPITE THE NAME. It is sourced into whatever
# shell the operator runs -- zsh is the macOS default and dash is /bin/sh on
# Debian. So: no [[ ]], no arrays, no BASH_SOURCE, no `local`, no `source`.
# `checker/env-wiring.sh` W6 asserts each of those absences, because a bashism
# here would fail on exactly the two platforms this file exists to serve.
#
# WHAT IT DOES NOT DO. It never edits your PATH, never overrides a variable you
# already exported (ORGAN 7 law 3: UNSET-ONLY), and never runs the router. It
# resolves the tree, sources the loader, and applies your rot.env.

# ROTMOE_HOME decides WHICH CODE RUNS, so a rot.env is forbidden from setting it
# (ORGAN 7 law 2). It is resolved here instead -- in the shell, before any file
# is read. A locator cannot relocate itself from inside the file it located.
rot_activate () {          # [plugin-root]
    rot__root=${1:-${ROTMOE_HOME:-}}

    if [ -z "$rot__root" ] || [ ! -f "$rot__root/hooks/rot-env.sh" ]; then
        rot__root=''
        for rot__c in \
            "$HOME/.claude/plugins/marketplaces/rot-moe" \
            "$HOME/.claude/plugins/rot-moe" \
            "$HOME/.rot-moe" \
            "$PWD"
        do
            if [ -f "$rot__c/hooks/rot-env.sh" ]; then rot__root=$rot__c; break; fi
        done
        unset rot__c
    fi

    if [ -z "$rot__root" ]; then
        printf 'rot.bashrc: no RoT MoE tree found. Source it with an explicit path:\n' >&2
        printf '    . /path/to/RoT-MoE/rot.bashrc /path/to/RoT-MoE\n' >&2
        unset rot__root
        return 1
    fi

    ROTMOE_HOME=$rot__root
    export ROTMOE_HOME
    # The hooks locate their own siblings through CLAUDE_PLUGIN_ROOT. Setting it
    # only when unset keeps an operator's explicit choice authoritative, which is
    # the same law the config files obey.
    if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
        CLAUDE_PLUGIN_ROOT=$rot__root
        export CLAUDE_PLUGIN_ROOT
    fi

    # ORGAN 7 -- hooks/rot-env.sh. A library: sourcing defines rot_env_load and
    # exports nothing by itself.
    . "$rot__root/hooks/rot-env.sh" || { unset rot__root; return 1; }

    # Apply the configuration for the directory we are standing in. Law 3 means
    # anything already exported in this shell wins, so this is safe to re-run.
    rot_env_load "${ROTMOE_CWD:-$PWD}" >/dev/null 2>&1 || :

    unset rot__root
    return 0
}

# Re-apply after changing project. The load is UNSET-ONLY, so a value already in
# the environment is never replaced -- start a fresh shell to change one.
rot_reload () { rot_activate "${1:-${ROTMOE_HOME:-}}"; }

# Report what is actually in force. Prints only the keys that are SET, so an
# empty report is the honest signal that nothing was configured.
rot_env_show () {
    rot__n=0
    for rot__k in ROTMOE_HOME ROTMOE_VOICE ROTMOE_GATE ROTMOE_MODEL \
                  ROTMOE_LEAN_WORKSPACE ROTMOE_WATCH_REPO ROTMOE_STATE_DIR \
                  ROTMOE_PROOF_STALE_MIN ROTMOE_TOKEN_PCT ROTMOE_ANIMUS
    do
        eval "rot__v=\${$rot__k:-}"
        if [ -n "$rot__v" ]; then
            printf '  %-24s %s\n' "$rot__k" "$rot__v"
            rot__n=$((rot__n+1))
        fi
    done
    [ "$rot__n" -eq 0 ] && printf '  (nothing set -- the packet is running on its defaults)\n'
    unset rot__n rot__k rot__v
    return 0
}

rot_activate "${1:-}"
