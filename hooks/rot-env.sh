#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-env.sh -- ORGAN 7, the environment layer. A LIBRARY, sourced by the
# shipped hooks (never by a project's code), providing one function.
#
# rot_env_load <project-dir>
#
# Reads rot.env files -- plain KEY=VALUE lines, the .env / .bashrc shape --
# and exports what they declare. No JSON anywhere: hooks/rot-voice.dtd is
# the schema, and its ENV.n entities are the ONLY accepted vocabulary.
#
# THREE LAWS, each load-bearing:
#
#   1. PARSED, NEVER SOURCED. A `.` or `source` of a file found in a project
#      directory would execute that project's code inside the user's hook --
#      a config file must be DATA. Lines are read; the value is assigned via
#      `export "$k=$v"`, which performs NO expansion of the value: a value
#      of `$(rm -rf ~)` is exported as those fourteen literal characters.
#   2. DECLARED-ONLY. A key not declared as an ENV.n entity in the DTD is
#      ignored -- not an error, not a warning, ignored. PATH, LD_PRELOAD,
#      PS1: a rot.env cannot touch them because nothing undeclared exists
#      to this parser. ROTMOE_ENV itself is additionally refused: the
#      locator cannot relocate itself from inside a file it located.
#   3. UNSET-ONLY. The live environment outranks every file, and the first
#      file to set a key wins over later files. A file supplies defaults;
#      it never overrides an operator's explicit export.
#
# Load order: $ROTMOE_ENV (an operator's explicit extra file), then
# <project>/.rot-moe/rot.env (per-project), then
# $XDG_CONFIG_HOME/rot-moe/rot.env (the operator's global defaults).
#
# Cost: builtin `read` and parameter expansion only -- zero forks. The DTD
# vocabulary is read once per load, from the same directory this library
# lives in (the plugin's own tree, never the project's).
# =============================================================================

rot_env_load () {   # <project-dir>
  _re_dir=$(dirname "$0" 2>/dev/null)
  [ -n "$_re_dir" ] || _re_dir=.
  _re_dtd="$_re_dir/rot-voice.dtd"
  [ -r "$_re_dtd" ] || _re_dtd="${CLAUDE_PLUGIN_ROOT:-}/hooks/rot-voice.dtd"
  [ -r "$_re_dtd" ] || return 0

  _re_vocab=''
  while IFS= read -r _re_l; do
    case "$_re_l" in
      *'<!ENTITY ENV.'*)
        _re_v=${_re_l#*\"}
        _re_v=${_re_v%\"*}
        _re_v=${_re_v%%|*}
        _re_vocab="$_re_vocab $_re_v"
        ;;
    esac
  done < "$_re_dtd"
  [ -n "$_re_vocab" ] || return 0

  for _re_f in "${ROTMOE_ENV:-}" "${1:+$1/.rot-moe/rot.env}" \
               "${XDG_CONFIG_HOME:-$HOME/.config}/rot-moe/rot.env"; do
    [ -n "$_re_f" ] || continue
    [ -r "$_re_f" ] || continue
    while IFS= read -r _re_l; do
      # Only the exact shape ROTMOE_<A-Z_>=<anything>. Comments, blanks,
      # exports, and every other line shape fall through silently.
      case "$_re_l" in
        ROTMOE_*=*) : ;;
        *) continue ;;
      esac
      _re_k=${_re_l%%=*}
      _re_val=${_re_l#*=}
      # Key charset, strictly: after ROTMOE_ nothing but A-Z and _.
      case "$_re_k" in
        ROTMOE_*[!A-Z_]*) continue ;;
      esac
      # Law 2: the locator cannot relocate itself; undeclared keys do not exist.
      [ "$_re_k" = 'ROTMOE_ENV' ] && continue
      case " $_re_vocab " in
        *" $_re_k "*) : ;;
        *) continue ;;
      esac
      # Law 3: unset-only. The eval is safe: _re_k passed the charset gate.
      eval "_re_set=\${$_re_k+x}"
      [ -n "$_re_set" ] && continue
      export "$_re_k=$_re_val"
    done < "$_re_f"
  done
  return 0
}
