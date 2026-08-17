#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-profile.sh -- ORGAN 7's interactive face: the .bashrc layer.
#
# One line in the operator's shell profile:
#
#   . /path/to/RoT-MoE/hooks/rot-profile.sh
#
# and every terminal carries the `rot` command family. This file is the
# .bashrc role of the trio -- SHIPPED code the operator chooses to source,
# which is exactly why it may be executable where rot.env may not: the
# operator sources the plugin's own tree, never a project's. The functions
# (.sh) edit the data (.env) under the schema (the DTD): `rot env set`
# refuses any key the ENV.n vocabulary does not declare, in the WRITE
# direction, the same law the loader enforces in the READ direction.
#
#   rot route "text"        one TIER 1 routing, printed
#   rot gauge a1,..,a9 N    the gauge, CLI form (extra flags pass through)
#   rot voice on|off        set ROTMOE_VOICE in the project rot.env
#   rot gate on|off         set ROTMOE_GATE in the project rot.env
#   rot env set KEY VALUE   write a declared key to the project rot.env
#   rot env get KEY         show a key's file value, if any
#   rot env list            the declared vocabulary, from the DTD
#   rot summons             show this machine's live voice summons, if any
#   rot check               run the voice contract, exit code reported
#   rot help                this list
#
# Resolution: ROTMOE_HOME if the operator set it, else the directory this
# file was sourced from (bash/zsh); a POSIX sh that provides neither gets a
# clear error naming the fix rather than a wrong guess.
# =============================================================================

if [ -z "${ROTMOE_HOME:-}" ]; then
  # shellcheck disable=SC3054  # BASH_SOURCE is probed, not assumed
  if [ -n "${BASH_SOURCE:-}" ]; then
    ROTMOE_HOME=$(cd "$(dirname "${BASH_SOURCE}")/.." 2>/dev/null && pwd)
  elif [ -n "${ZSH_VERSION:-}" ]; then
    # shellcheck disable=SC2296
    ROTMOE_HOME=$(cd "$(dirname "${(%):-%N}")/.." 2>/dev/null && pwd)
  fi
fi
export ROTMOE_HOME

rot () {
  _rp_home="${ROTMOE_HOME:-}"
  if [ -z "$_rp_home" ] || [ ! -r "$_rp_home/hooks/rot-voice.dtd" ]; then
    echo "rot: set ROTMOE_HOME to the RoT-MoE checkout (hooks/rot-voice.dtd not found)" >&2
    return 2
  fi
  _rp_dtd="$_rp_home/hooks/rot-voice.dtd"
  case "${1:-help}" in
    route)
      shift; sh "$_rp_home/hooks/rot-router.sh" --route "$*" ;;
    gauge)
      shift; _rp_v="${1:-}"; _rp_b="${2:-1}"
      [ -n "$_rp_v" ] || { echo "rot gauge a1,..,a9 [breadth] [extra flags]" >&2; return 2; }
      # A vector is nine comma-separated numbers, and anything else is refused
      # WITH the usage line. MEASURED 2026-08-17 (v6.0.0 real test, anomaly 3):
      # `rot gauge --vector 1,0,...` -- flag syntax where the positional form
      # belongs -- fell through and computed a degenerate K=1 lenses=none
      # gauge at exit 0: a number derived from garbage, wearing the exit code
      # of a measurement. A wrapper that validates nothing adds nothing.
      case "$_rp_v" in
        *[!0-9.,]*|*,,*|,*|*,)
          echo "rot gauge: '$_rp_v' is not a vector -- expected a1,..,a9, nine comma-separated numbers" >&2
          echo "rot gauge a1,..,a9 [breadth] [extra flags]" >&2; return 2 ;;
      esac
      _rp_n=$(printf '%s' "$_rp_v" | awk -F',' '{print NF}')
      [ "$_rp_n" -eq 9 ] || {
        echo "rot gauge: the vector has $_rp_n entries, expected 9 (one per lens)" >&2; return 2; }
      case "$_rp_b" in
        *[!0-9]*)
          echo "rot gauge: breadth '$_rp_b' is not a count -- give the breadth before any extra flags" >&2
          return 2 ;;
      esac
      shift 2 2>/dev/null || shift $#
      sh "$_rp_home/hooks/rot-router.sh" --vector "$_rp_v" --breadth "$_rp_b" "$@" ;;
    voice)
      case "${2:-}" in
        on)  rot env set ROTMOE_VOICE 1 ;;
        off) rot env set ROTMOE_VOICE 0 ;;
        *)   echo "rot voice on|off" >&2; return 2 ;;
      esac ;;
    gate)
      case "${2:-}" in
        on)  rot env set ROTMOE_GATE 1 ;;
        off) rot env set ROTMOE_GATE 0 ;;
        *)   echo "rot gate on|off" >&2; return 2 ;;
      esac ;;
    env)
      case "${2:-}" in
        list)
          sed -n 's/.*<!ENTITY ENV\.[0-9][0-9]* *"\(.*\)">.*/\1/p' "$_rp_dtd" \
            | awk -F'|' '{printf "  %-26s %-16s %s\n", $1, $2, $3}' ;;
        get)
          [ -n "${3:-}" ] || { echo "rot env get KEY" >&2; return 2; }
          for _rp_f in ".rot-moe/rot.env" "${XDG_CONFIG_HOME:-$HOME/.config}/rot-moe/rot.env"; do
            [ -r "$_rp_f" ] || continue
            grep "^${3}=" "$_rp_f" 2>/dev/null && return 0
          done
          echo "rot: $3 not set in any rot.env" >&2; return 1 ;;
        set)
          [ -n "${3:-}" ] && [ -n "${4+x}" ] || { echo "rot env set KEY VALUE" >&2; return 2; }
          # The WRITE direction of declared-only: a key the DTD does not
          # declare is refused with the vocabulary printed -- never guessed.
          if ! sed -n 's/.*<!ENTITY ENV\.[0-9][0-9]* *"\([A-Z_]*\)|.*/\1/p' "$_rp_dtd" | grep -qx "$3"; then
            echo "rot: '$3' is not a declared key. The vocabulary:" >&2
            rot env list >&2
            return 2
          fi
          case "$3" in ROTMOE_ENV|ROTMOE_HOME)
            echo "rot: $3 is never file-settable -- it decides what runs, so only your shell may set it" >&2; return 2 ;;
          esac
          mkdir -p .rot-moe 2>/dev/null || { echo "rot: cannot create .rot-moe here" >&2; return 1; }
          [ -f .rot-moe/rot.env ] || : > .rot-moe/rot.env
          grep -v "^${3}=" .rot-moe/rot.env > .rot-moe/rot.env.tmp 2>/dev/null || :
          printf '%s=%s\n' "$3" "$4" >> .rot-moe/rot.env.tmp
          mv .rot-moe/rot.env.tmp .rot-moe/rot.env
          echo "rot: $3=$4 -> $(pwd)/.rot-moe/rot.env" ;;
        *) echo "rot env list|get KEY|set KEY VALUE" >&2; return 2 ;;
      esac ;;
    summons)
      _rp_sd="${ROTMOE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/rot-moe}"
      _rp_found=0
      for _rp_f in "$_rp_sd"/voice-summons.*; do
        [ -e "$_rp_f" ] || continue
        _rp_found=1
        echo "== $_rp_f"
        cat "$_rp_f"
      done
      [ "$_rp_found" -eq 1 ] || echo "rot: no live summons -- every summoned lens has spoken" ;;
    check)
      sh "$_rp_home/checker/voice-contract.sh"
      _rp_rc=$?
      echo "voice-contract exit=$_rp_rc"
      return $_rp_rc ;;
    help|*)
      sed -n 's/^#   rot /  rot /p' "$_rp_home/hooks/rot-profile.sh" ;;
  esac
}
