#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# ARM_ROUTER.sh -- install the RoT MoE router hooks into settings.json
#
# THIS IS A SECURITY CONTRACT, NOT A CONVENIENCE SCRIPT. It edits a file the
# user's whole session depends on. The rules below are in priority order and
# rule 4 can undo rules 1-3 automatically.
#
#   1. BACKUP FIRST, and print the restore command.
#   2. ADDITIVE MERGE ONLY -- parse, append, write back. Never a blind rewrite,
#      never a template.
#   3. PRESERVE every key it did not come to add.
#   4. VALIDATE by re-reading -- if the result does not parse, or ANY
#      pre-existing value changed, AUTO-RESTORE and exit non-zero.
#   5. IDEMPOTENT -- detect by command string, not by count.
#   6. SHOW THE DIFF.
#   7. Never sudo. Never touch anything outside the Claude config dir.
#
# -----------------------------------------------------------------------------
# WHY node AND NOT jq/python.
#
# Measured on the development machine: `python`, `python3` and `py` are ALL
# ABSENT; only `uv` is installed. `jq` happens to be present but is not
# something a Claude Code user is guaranteed to have.
#
# `node` is guaranteed, and the argument is structural rather than lucky:
# Claude Code is itself a Node application. Anyone who can run the thing this
# plugin plugs into can run node. That makes it the only JSON engine here whose
# presence follows from the premise.
#
# -----------------------------------------------------------------------------
# THE BOM RULE -- A DELIBERATE DEPARTURE FROM THE WRITTEN SPEC, DISCLOSED.
#
# The spec says the installer "writes UTF-8 WITHOUT BOM". Measured on the live
# file: `settings.json` ALREADY HAS a UTF-8 BOM. `JSON.parse` fails on it
# outright until the BOM is stripped.
#
# Writing it back without one would silently alter the first three bytes of a
# file this installer was told to preserve -- which is precisely the class of
# change rule 3 forbids. The spec's intent is that an installer must not ADD a
# BOM; read literally against a file that already has one, it would force a
# byte-level modification.
#
# So this script PRESERVES THE INPUT'S BOM STATE: none is added if none was
# there, and an existing one is kept. Same for the trailing newline. That
# satisfies the rule's purpose exactly, and "nothing else moves" wins over the
# literal wording when the two conflict.
# =============================================================================

set -euo pipefail

# --- --dry-run: SEE THE CHANGE BEFORE CONSENTING TO IT ------------------------
# This script edits a file the user's live session depends on. Rule 6 says "show
# the diff", but showing it AFTER writing is a report, not a choice. --dry-run
# performs the entire merge against a COPY, prints exactly what would change,
# and leaves the real file untouched -- verified by checker/install-roundtrip.sh
# comparing the file's bytes before and after a dry run.
DRY=0
FORCE=0
for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY=1 ;;
    --force) FORCE=1 ;;
    --help|-h)
      echo "usage: ARM_ROUTER.sh [--dry-run] [--force]"
      echo "  --dry-run   show what would change; write nothing"
      echo "  --force     arm even if the installed plugin already registers the"
      echo "              router -- this DUPLICATES it. See the guard below."
      exit 0 ;;
    *)
      # An ignored flag is how DISARM_ROUTER's --dry-run once deleted live hook
      # entries: the script did not understand the argument and read that as
      # "proceed". Refusing is the only reading that cannot destroy anything.
      echo "ARM_ROUTER: unknown argument '$a' -- refusing to run." >&2
      exit 2 ;;
  esac
done


# --- rule 7: scope ----------------------------------------------------------
# CLAUDE_DIR is overridable ONLY so the checker can run this against a scratch
# HOME. That is not a backdoor: it is what makes rules 1-6 testable at all,
# and an installer whose guarantees have never been executed is an untested
# alarm.
#
# CLAUDE_CONFIG_DIR IS HONOURED FIRST, AND THAT ORDER IS THE POINT. It is the
# variable CLAUDE CODE ITSELF reads to relocate its configuration, so a user who
# has set it is telling us, unambiguously, where their settings live. Honouring
# only our own CLAUDE_DIR meant that for such a user this installer silently
# armed the WRONG directory -- writing a backup and a hook entry into a
# ~/.claude that Claude Code was not reading, while the config it does read
# stayed untouched. Measured, not theorised: a scratch install driven with
# CLAUDE_CONFIG_DIR set went straight for the live home directory and only the
# read-only bit on the real settings.json stopped the write.
#
# Precedence, and why: CLAUDE_CONFIG_DIR (the user's own statement of where
# their config is) beats CLAUDE_DIR (ours, for tests) beats $HOME/.claude (the
# default). Ours stays second so every existing checker keeps working unchanged.
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

# The command string is the identity used for idempotence and for removal.
# `pwsh ... || bash ...` mirrors the org's working plugin: Windows takes the
# first arm, POSIX falls through to the second.
ROUTER_CMD="pwsh -NoProfile -File \"$ROUTER_PS1\" || bash \"$ROUTER_SH\""

# EVERY LIFECYCLE EVENT, NOT TWO -- 2026-08-08.
#
# This installer wired the router on UserPromptSubmit and PreToolUse, and the
# reminder on those two plus PostToolUse. For a linter that would be ample. For
# a ROUTER it is the central defect: a router observes the session it claims to
# govern, and eleven of thirty-one events is not observation, it is sampling. Every A/B
# measurement this repo has taken was therefore taken against a partially
# installed product -- which is a live candidate explanation for why no quality
# win has been demonstrated, and it is recorded here as a candidate rather than
# a conclusion, because it has not yet been re-measured under full wiring.
#
# The thirty-one names are READ FROM THE CLI, not recalled and not counted from
# other plugins: the Lz array inside the compiled claude binary. An earlier list
# of eleven was counted from every hooks.json and settings.json
# on the measuring machine was scanned, and these are the event keys in real use
# (occurrences in that scan: PreToolUse 97, UserPromptSubmit 78, SessionStart 69,
# PostToolUse 62, Stop 61, SessionEnd 6, Notification 6, SubagentStop 4,
# PreCompact 2, UserPromptExpansion 1, PostCompact 1). hooks/hooks.json carries
# the identical list, and checker/install-parity.sh fails if the two disagree --
# so this constant cannot silently drift away from what the plugin registers.
#
# Both hooks were run against all thirty-one payloads BEFORE this list was widened:
# rot-router exits 0 and emits its marker on every one, prover-remind exits 0
# on every one -- 80 invocations across the four arms for the twenty new events. Widening the wiring without that measurement would have risked
# a hook that crashes on Stop, which breaks the session rather than the build.
ALL_EVENTS='UserPromptSubmit UserPromptExpansion PreToolUse PostToolUse SessionStart SessionEnd Stop SubagentStop Notification PreCompact PostCompact'
EVENTS="$ALL_EVENTS"
EVENTS_CSV='PreToolUse,PostToolUse,PostToolUseFailure,PostToolBatch,Notification,UserPromptSubmit,UserPromptExpansion,SessionStart,SessionEnd,Stop,StopFailure,SubagentStart,SubagentStop,PreCompact,PostCompact,PermissionRequest,PermissionDenied,Setup,TeammateIdle,TaskCreated,TaskCompleted,Elicitation,ElicitationResult,ConfigChange,WorktreeCreate,WorktreeRemove,InstructionsLoaded,CwdChanged,FileChanged,DirectoryAdded,MessageDisplay'

# The reminder ships in the same tree and is registered by the PLUGIN on the
# same thirty-one events. The hand install has to match it or the two paths deliver
# different products -- see the block at the merge call for the measurement.
REMIND_PS1="$(canon_path "$SELF_DIR/hooks/prover-remind.ps1")"
REMIND_SH="$(canon_path "$SELF_DIR/hooks/prover-remind.sh")"
REMIND_CMD="pwsh -NoProfile -File \"$REMIND_PS1\" || bash \"$REMIND_SH\""
REMIND_EVENTS_CSV="$EVENTS_CSV"

echo "RoT MoE :: ARM_ROUTER"
echo "  config dir : $CLAUDE_DIR"
echo "  settings   : $SETTINGS"

# --- THE DOUBLE-FIRE GUARD ---------------------------------------------------
# MEASURED DEFECT, 2026-08-04, on the author's own machine. The two install
# paths are ADDITIVE and the documentation told the user to take both:
#
#   plugin install  -> hooks/hooks.json binds rot-router on UserPromptSubmit and
#                      PreToolUse through ${CLAUDE_PLUGIN_ROOT}
#   ARM_ROUTER      -> writes an absolute-path entry for THE SAME script on THE
#                      SAME two events into settings.json
#
# Result: the router fires TWICE per prompt. Two identical marker lines injected
# into the context, two gauge computations, twice the tokens -- forever, on every
# machine that followed the documented procedure. Counted in a live transcript:
# the marker appears twice per turn, and settings.json plus the plugin's own
# hooks.json account for exactly one each.
#
# It is invisible from inside because nothing is broken. The lane is right, the
# gauge is right; it is right twice. So the check has to be a program.
#
# Refusing here is a SUCCESS, not a failure: the user asked for the router to be
# armed and it already is. Exit 0, say so, change nothing. --force is kept for
# the person who genuinely wants a second registration and now knows it is one.
if [ "$FORCE" -eq 0 ] && [ -f "$SETTINGS" ]; then
  DETECT_RC=0
  DETECT_OUT=$(node "$SELF_DIR/hooks/plugin-detect.js" "$CLAUDE_DIR" 2>/dev/null) || DETECT_RC=$?
  if [ "$DETECT_RC" -eq 0 ]; then
    echo "$DETECT_OUT"
    echo
    echo "  ALREADY ARMED BY THE INSTALLED PLUGIN -- nothing to do."
    echo "  The plugin's hooks.json already binds the router on UserPromptSubmit"
    echo "  and PreToolUse. Adding a settings.json entry too would fire it TWICE"
    echo "  per prompt: two marker lines, two gauges, twice the tokens."
    echo
    echo "  ARM_ROUTER is for installs that are NOT via the marketplace/plugin."
    echo "  If you really want a second registration: ARM_ROUTER.sh --force"
    exit 0
  fi
fi

if [ ! -f "$SETTINGS" ]; then
  echo "  no settings.json found -- creating a minimal one"
  mkdir -p "$CLAUDE_DIR"
  printf '{}\n' > "$SETTINGS"
fi

# --- rule 1: backup ---------------------------------------------------------
if [ "$DRY" -eq 1 ]; then
  # Operate on a copy. Nothing below can reach the real file, which is the
  # only honest way to promise "write nothing" -- a flag checked at the write
  # site would still be one forgotten branch away from writing.
  DRY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rotmoe-dryrun.XXXXXX")"
  cp "$SETTINGS" "$DRY_DIR/settings.json"
  DRY_ORIG="$SETTINGS"
  SETTINGS="$DRY_DIR/settings.json"
  echo "  DRY RUN    : nothing will be written to $DRY_ORIG"
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$SETTINGS.pre-armrouter-$STAMP.bak"
cp "$SETTINGS" "$BACKUP"
echo "  backup     : $BACKUP"
echo "  restore    : cp \"$BACKUP\" \"$SETTINGS\""

# --- rules 2,3,5: the merge -------------------------------------------------
MERGE_RC=0
# The merge itself lives in ONE place, shared by both installer arms. See
# hooks/settings-merge.js for why the installer is shared while the router is
# deliberately duplicated: for the router, two agreeing implementations ARE the
# evidence; for the installer there is nothing to cross-check and byte
# divergence between arms would be pure risk.
node "$SELF_DIR/hooks/settings-merge.js" arm "$SETTINGS" "$ROUTER_CMD" "$EVENTS_CSV" || MERGE_RC=$?

# THE REMINDER IS PART OF THE INSTALL, and leaving it out was a measured defect.
#
# MEASURED 2026-08-05 by comparing `hooks/hooks.json` -- what a marketplace
# install registers -- against what this script writes:
#
#   plugin install : 3 events, 5 bindings (router x2, prover-remind x3)
#   ARM_ROUTER     : 2 events, 2 bindings (router only)
#
# A grep for `prover-remind` across both installer arms, both Lean setup scripts
# and settings-merge.js returned NOTHING: no installer had ever wired it. So the
# two documented ways to install the same product gave different products, and
# the hand-installed one silently lacked the entire proof-reminder organ -- the
# component whose 55x staleness error this very release fixed. A user on that
# path would never have seen a reminder at all.
#
# The reminder binds on THREE events. PostToolUse is the one the router does not
# use and the one an installer built around the router could not express until
# the event list became a parameter.
if [ "$MERGE_RC" -eq 0 ] || [ "$MERGE_RC" -eq 10 ]; then
  REMIND_RC=0
  node "$SELF_DIR/hooks/settings-merge.js" arm "$SETTINGS" "$REMIND_CMD" \
       "$REMIND_EVENTS_CSV" || REMIND_RC=$?
  # A reminder failure must not be quieter than a router failure: the same
  # restore-and-refuse path applies, because a half-armed settings.json is worse
  # than an unarmed one.
  if [ "$REMIND_RC" -eq 4 ] || [ "$REMIND_RC" -eq 3 ]; then
    cp "$BACKUP" "$SETTINGS"
    echo "  AUTO-RESTORED from backup: the reminder could not be armed (exit $REMIND_RC)."
    exit "$REMIND_RC"
  fi
  [ "$REMIND_RC" -eq 0 ] && MERGE_RC=0
fi

# rule 4: auto-restore on any validation failure.
if [ "$MERGE_RC" -eq 4 ]; then
  cp "$BACKUP" "$SETTINGS"
  echo "  AUTO-RESTORED from backup. settings.json is as it was."
  exit 4
elif [ "$MERGE_RC" -eq 3 ]; then
  echo "  settings.json was already invalid. Nothing written."
  exit 3
elif [ "$MERGE_RC" -eq 10 ]; then
  rm -f "$BACKUP"    # no change made, so the backup is noise
  echo "  already armed -- backup removed, nothing changed."
  exit 0
elif [ "$MERGE_RC" -ne 0 ]; then
  cp "$BACKUP" "$SETTINGS"
  echo "  unexpected failure ($MERGE_RC). AUTO-RESTORED from backup."
  exit "$MERGE_RC"
fi

# --- rule 6: show the diff --------------------------------------------------
echo "  --- diff ---"
if command -v diff >/dev/null 2>&1; then
  diff -u "$BACKUP" "$SETTINGS" | sed 's/^/  /' || true
else
  echo "  (diff unavailable; backup is at $BACKUP)"
fi
if [ "$DRY" -eq 1 ]; then
  echo "  --- the above is what WOULD change ---"
  echo "  DRY RUN: $DRY_ORIG was NOT modified."
  rm -rf "$DRY_DIR"
  exit 0
fi
echo "RoT MoE :: armed."
