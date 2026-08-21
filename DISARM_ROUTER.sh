#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# DISARM_ROUTER.sh -- remove the RoT MoE router hooks from settings.json
#
# An installer whose uninstaller has never been run is an untested alarm, so
# this is written and tested BEFORE the router it removes is finished.
#
# It removes exactly the command string ARM_ROUTER installed, and exactly the
# empty matcher groups that removal leaves behind -- nothing else. Same BOM,
# newline and preservation rules as the installer, for the same reason: this
# script also writes a file the user's session depends on.
#
# KNOWN LIMIT, PROVED RATHER THAN DISCLAIMED (lean/Proofs/RotInstall.lean):
# `disarm_arm_id` holds only under a freshness hypothesis, and
# `disarm_arm_not_id` proves that hypothesis cannot be dropped. If you had
# already registered this exact command by hand before installing, this removes
# your entry too -- it cannot tell yours from ours, because they are identical
# strings. That is why ARM_ROUTER writes a backup and prints its restore line.
# =============================================================================

set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-${CLAUDE_DIR:-$HOME/.claude}}"
SETTINGS="$CLAUDE_DIR/settings.json"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROUTER_SH="$SELF_DIR/hooks/rot-router.sh"
ROUTER_PS1="$SELF_DIR/hooks/rot-router.ps1"

# --- CANONICAL PATH FORM -- shared rule, both arms, or the user gets stranded --
# The command string is the identity used for idempotence AND for removal, so
# the two installer arms must spell the repo path identically or one installs
# what the other cannot remove.
#
# A CLEAN-CLONE RUN FOUND THE HOLE that the working copy hid. Under a Git Bash
# MOUNT ALIAS the two arms disagree even after normalisation:
#
#   bash sees        /tmp/x/RoT-MoE
#   PowerShell sees  <drive>:\tmp\x\RoT-MoE  ->  /<drive>/tmp/x/RoT-MoE
#
# ...because /tmp can be an alias for a different drive entirely. Round-tripping with
# `cygpath -u` does NOT fix it: cygpath prefers the alias and hands /tmp back.
#
# So the canonical form is derived from the WINDOWS path by the same rule the
# .ps1 arms use (backslashes to slashes, drive letter lowercased into /d/...).
# On Linux and macOS there is no cygpath and no drive letter, so this is the
# identity function and costs nothing.
canon_path () {
  _p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    _w=$(cygpath -w "$_p" 2>/dev/null) || _w=""
    if [ -n "$_w" ]; then
      _p=$(printf '%s' "$_w" | tr '\\' '/')
      case "$_p" in
        [A-Za-z]:/*)
          _d=$(printf '%s' "$_p" | cut -c1 | tr 'A-Z' 'a-z')
          _p="/$_d$(printf '%s' "$_p" | cut -c3-)"
          ;;
      esac
    fi
  fi
  printf '%s' "$_p"
}

ROUTER_SH="$(canon_path "$ROUTER_SH")"
ROUTER_PS1="$(canon_path "$ROUTER_PS1")"
ROUTER_CMD="if command -v pwsh >/dev/null 2>&1; then pwsh -NoProfile -File \"$ROUTER_PS1\"; else bash \"$ROUTER_SH\"; fi"
# LEGACY (<= 8.0.1). Kept so an install made by the old ARM_ROUTER can still be
# removed by this one. Dropping it would strand those entries with no documented
# way to remove them -- the defect the comment below records, reintroduced by an
# upgrade instead of by a second hook.
ROUTER_CMD_LEGACY="command -v pwsh >/dev/null 2>&1 && pwsh -NoProfile -File \"$ROUTER_PS1\" || bash \"$ROUTER_SH\""

# EXACT MODE MUST KNOW EVERY STRING THE INSTALLER WRITES.
#
# MEASURED 2026-08-05, caught by install-roundtrip the moment ARM_ROUTER started
# wiring the reminder: exact `disarm` matches ONE command string, so it removed
# the router and left all three prover-remind entries behind. The round trip then
# failed against the pre-install file -- residue the user could not remove by any
# documented means, which is precisely the defect `--all` was invented for and
# which had just been reintroduced for a second hook.
#
# Exact mode stays exact: these are the strings THIS tree would have written,
# rebuilt the same way ARM_ROUTER builds them. Nothing heuristic, nothing that
# could reach an entry the installer did not create.
REMIND_SH="$(canon_path "$SELF_DIR/hooks/prover-remind.sh")"
REMIND_PS1="$(canon_path "$SELF_DIR/hooks/prover-remind.ps1")"
REMIND_CMD="if command -v pwsh >/dev/null 2>&1; then pwsh -NoProfile -File \"$REMIND_PS1\"; else bash \"$REMIND_SH\"; fi"
# LEGACY (<= 8.0.1). Kept so an install made by the old ARM_ROUTER can still be
# removed by this one. Dropping it would strand those entries with no documented
# way to remove them -- the defect the comment below records, reintroduced by an
# upgrade instead of by a second hook.
REMIND_CMD_LEGACY="command -v pwsh >/dev/null 2>&1 && pwsh -NoProfile -File \"$REMIND_PS1\" || bash \"$REMIND_SH\""
GATE_SH="$(canon_path "$SELF_DIR/hooks/rot-voice-gate.sh")"
GATE_PS1="$(canon_path "$SELF_DIR/hooks/rot-voice-gate.ps1")"
GATE_CMD="if command -v pwsh >/dev/null 2>&1; then pwsh -NoProfile -File \"$GATE_PS1\"; else bash \"$GATE_SH\"; fi"
# LEGACY (<= 8.0.1). Kept so an install made by the old ARM_ROUTER can still be
# removed by this one. Dropping it would strand those entries with no documented
# way to remove them -- the defect the comment below records, reintroduced by an
# upgrade instead of by a second hook.
GATE_CMD_LEGACY="command -v pwsh >/dev/null 2>&1 && pwsh -NoProfile -File \"$GATE_PS1\" || bash \"$GATE_SH\""

# ALL SIX STRINGS, ONE FOLD -- three current, three legacy (<= 8.0.1).
# settings-merge.js exit 10 means "this string was not present", which is not a
# failure of a pass that DID remove something. So 10 survives only if EVERY pass
# reported 10, and a real error (neither 0 nor 10) wins immediately and stops.
# Sets _DA_RC rather than echoing, so node's own output still reaches the user
# instead of being swallowed by a command substitution.
_disarm_all () {   # <settings-file>
  _DA_RC=10
  for _da_cmd in "$ROUTER_CMD" "$REMIND_CMD" "$GATE_CMD" \
                 "$ROUTER_CMD_LEGACY" "$REMIND_CMD_LEGACY" "$GATE_CMD_LEGACY"; do
    _da_one=0
    node "$SELF_DIR/hooks/settings-merge.js" "$MODE" "$1" "$_da_cmd" || _da_one=$?
    if [ "$_da_one" -ne 0 ] && [ "$_da_one" -ne 10 ]; then _DA_RC=$_da_one; return 0; fi
    { [ "$_DA_RC" -eq 10 ] && [ "$_da_one" -ne 10 ]; } && _DA_RC=$_da_one
  done
  return 0
}

# --- flags -------------------------------------------------------------------
# `--dry-run` was ACCEPTED AND SILENTLY IGNORED here while ARM_ROUTER honoured
# it. Measured consequence on a live machine: the flag was passed to preview a
# removal and this script deleted two real router hook entries instead. The
# destructive half of a pair must not be the half missing the safety flag.
#
# An unknown argument is now a HARD ERROR rather than a no-op. Swallowing an
# argument is what turned a simulation into a deletion, so "I did not understand
# that" must never again read as "proceed".
#
# `--all` is the answer to the second measured defect: removal was keyed to the
# command string rebuilt from THIS directory, so an entry pointing at the
# installed plugin -- which is what the documented install produces -- could
# never be removed from a source checkout. Exact match stays the default because
# it is the one that cannot touch a string it did not write; `--all` is opt-in
# and says plainly what it widens to.
DRY=0
ANY=0
for _arg in "$@"; do
  case "$_arg" in
    --dry-run|-n) DRY=1 ;;
    --all)        ANY=1 ;;
    -h|--help)
      echo "usage: DISARM_ROUTER.sh [--dry-run] [--all]"
      echo "  --dry-run   show what WOULD be removed; settings.json is not written"
      echo "  --all       remove EVERY hook entry invoking a RoT MoE router script,"
      echo "              whatever path or version it names (plugin-cache entries"
      echo "              included). Default removes only this directory's exact"
      echo "              command string."
      exit 0 ;;
    *)
      echo "DISARM_ROUTER: unknown argument '$_arg' -- refusing to run." >&2
      echo "  (an ignored flag is how --dry-run once deleted live hook entries)" >&2
      exit 2 ;;
  esac
done

MODE=disarm
[ "$ANY" -eq 1 ] && MODE=disarm-any

echo "RoT MoE :: DISARM_ROUTER"
echo "  settings   : $SETTINGS"
echo "  match      : $([ "$ANY" -eq 1 ] && echo 'ANY RoT MoE router entry (--all)' || echo 'exact command string of this directory')"
[ "$DRY" -eq 1 ] && echo "  mode       : DRY RUN -- nothing will be written"

[ -f "$SETTINGS" ] || { echo "  no settings.json -- nothing to disarm"; exit 0; }

# DRY RUN: perform the REAL removal against a COPY, report the delta, discard the
# copy. The merge logic is therefore exercised for real -- a dry run that
# predicts by a different code path than the one that acts is a dry run that can
# disagree with the act, which is worse than no dry run at all.
if [ "$DRY" -eq 1 ]; then
  TMP="$(mktemp "${TMPDIR:-/tmp}/rotmoe-disarm-dry.XXXXXX")"
  cp "$SETTINGS" "$TMP"
  chmod u+w "$TMP" 2>/dev/null || true   # a read-only settings.json copies read-only
  _disarm_all "$TMP"; RC=$_DA_RC
  if [ "$RC" -eq 10 ]; then
    echo "  would remove: 0 router hook entries"
  elif [ "$RC" -ne 0 ]; then
    echo "  would FAIL with code $RC -- nothing would be written"
  else
    # NO arithmetic here, deliberately. `grep -c` exits 1 when the count is ZERO
    # while still printing "0", so a `|| echo 0` fallback emits "0\n0"; that fed
    # $(( )) a syntax error, bash aborted the whole guard block and execution
    # FELL THROUGH into the destructive path the branch existed to prevent --
    # measured: the dry run deleted the entries it was meant to preview. A
    # safety branch must not contain a construct that can fail into the thing it
    # guards against.
    BEFORE=$(grep -c 'rot-router' "$SETTINGS" 2>/dev/null || true)
    AFTER=$(grep -c 'rot-router' "$TMP" 2>/dev/null || true)
    echo "  router lines: $BEFORE now -> $AFTER if disarmed"
    echo "  --- would change ---"
    diff -u "$SETTINGS" "$TMP" | sed 's/^/  /' || true
  fi
  rm -f "$TMP"
  echo "  DRY RUN complete -- $SETTINGS was NOT modified."
  exit 0
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$SETTINGS.pre-disarmrouter-$STAMP.bak"
cp "$SETTINGS" "$BACKUP"
echo "  backup     : $BACKUP"
echo "  restore    : cp \"$BACKUP\" \"$SETTINGS\""

_disarm_all "$SETTINGS"; RC=$_DA_RC

if [ "$RC" -eq 4 ]; then
  cp "$BACKUP" "$SETTINGS"; echo "  AUTO-RESTORED from backup."; exit 4
elif [ "$RC" -eq 3 ]; then
  echo "  settings.json was already invalid. Nothing written."; exit 3
elif [ "$RC" -eq 10 ]; then
  rm -f "$BACKUP"
  echo "  nothing to remove -- backup removed."
  # SAY SO WHEN THE ANSWER IS MISLEADING. `nothing to remove` while router
  # entries are visibly present in the file is the exact shape of the measured
  # defect: an entry installed from the plugin cache survived a full DISARM run
  # from a source checkout, and the run exited 0. The count is cheap; silence
  # here is what made the failure invisible.
  if [ "$ANY" -eq 0 ] && grep -q 'rot-router' "$SETTINGS" 2>/dev/null; then
    echo
    echo "  BUT settings.json still contains RoT MoE router entries that do NOT"
    echo "  match this directory's command string (a plugin-cache or older-version"
    echo "  install). This run could not touch them. To remove those as well:"
    echo "      bash DISARM_ROUTER.sh --all --dry-run   # look first"
    echo "      bash DISARM_ROUTER.sh --all"
  fi
  exit 0
elif [ "$RC" -ne 0 ]; then
  cp "$BACKUP" "$SETTINGS"; echo "  unexpected failure ($RC). AUTO-RESTORED."; exit "$RC"
fi

echo "  --- diff ---"
diff -u "$BACKUP" "$SETTINGS" | sed 's/^/  /' || true
echo "RoT MoE :: disarmed."
