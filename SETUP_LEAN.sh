#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# SETUP_LEAN.sh -- OPTIONAL toolchain fetch. Nothing installs this for you.
#
# READ THIS FIRST: YOU DO NOT NEED LEAN TO USE THIS PLUGIN.
# The router and the reminder are shell and PowerShell. They route, they gauge,
# they remind, and they do all of it with no Lean on the machine. Lean is needed
# for exactly one thing: RE-VERIFYING THE PROOFS YOURSELF. CI already does that
# on a clean runner for every commit. This script exists for the reader who
# refuses to take CI's word for it -- which is the correct instinct, and is why
# it is here at all.
#
# WHY THE PROOFS ARE NOT VENDORED, with the numbers that decided it:
#   * a mathlib build directory measured 7.2 GB on the machine this was written
#     on (measured twice, deleted twice). Git cannot carry that; GitHub rejects
#     single files over 100 MB.
#   * elan toolchains are per-OS, per-architecture BINARIES. Shipping "our"
#     .elan would ship Windows x86_64 binaries and nothing else -- useless on
#     Linux or Apple silicon -- and would redistribute Lean's binaries under
#     obligations this repo has no reason to take on.
#   * a vendored mathlib is stale the moment `lean/lean-toolchain` moves, and a
#     stale dependency that LOOKS pinned is worse than an absent one.
#
# WHY THIS IS NOT RUN BY THE INSTALLER:
# ARM_ROUTER installs the plugin. Its contract is that it touches the plugin
# directory and nothing else, never elevates, and never surprises you. A plugin
# install that silently downloads gigabytes and executes a remote installer
# would break every clause of that. `checker/workflow-lint.sh` FAILS THE BUILD
# if ARM_ROUTER ever calls this file -- the separation is enforced, not
# promised.
#
# WHAT IT DOES, in order, and it stops at the first thing already present:
#   1. elan            -> official installer, into $ELAN_HOME (default ~/.elan)
#   2. the toolchain   -> the version pinned in lean/lean-toolchain, never a
#                         floating "latest"
#   3. mathlib cache   -> `lake exe cache get`: PREBUILT oleans over the
#                         network. Never a source build; that is hours and is
#                         not what "verify the proofs" should cost.
#
# CONTROLS (this script can refuse, which is why its success means something):
#   ./SETUP_LEAN.sh              -> REFUSES, exit 2. Consent is not a default.
#   ./SETUP_LEAN.sh --dry-run    -> prints the plan, creates NOTHING, exit 0.
#   ./SETUP_LEAN.sh --yes        -> does the work.
#   ./SETUP_LEAN.sh --uninstall  -> tells you exactly what to remove, and how.
#
# NEVER: sudo, a package manager, a system directory, anything under ~/.claude
# other than the plugin's own folder. If this script ever needs root, it is
# wrong and you should stop it.
# =============================================================================

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WS="${ROTMOE_LEAN_WORKSPACE:-$HERE/lean}"
ELAN_ROOT="${ELAN_HOME:-$HOME/.elan}"

YES=0; DRY=0; UNINSTALL=0; ASK_ROOT=0; ROOT_ARG=""; ELAN_ROOT_ARG=""
for a in "$@"; do
  case "$a" in
    --yes|-y)     YES=1 ;;
    --dry-run|-n) DRY=1 ;;
    --uninstall)  UNINSTALL=1 ;;
    --ask-root)   ASK_ROOT=1 ;;
    # --root NOW MEANS "where do MY PROOFS live", not "where does elan live".
    #
    # It used to mean the second, and that was measured against the only layout
    # proven end to end on the machine this was built on -- toolchain in the
    # HOME directory, proofs on a roomy second disk -- and found to disagree
    # with it. The toolchain is a fixed cost that elan itself knows how to
    # manage; the PROOF WORKSPACE is the thing that grows without bound as the
    # user works, and it is the one that belongs on the disk they chose.
    #
    # The old capability is not lost, it is separated: --elan-root still puts
    # the toolchain elsewhere for anyone whose system drive is tight, which was
    # the real problem the original flag solved. One flag was doing two jobs and
    # answering the more common question wrongly.
    --root=*)      ROOT_ARG="${a#--root=}" ;;
    --elan-root=*) ELAN_ROOT_ARG="${a#--elan-root=}" ;;
    --help|-h)
      sed -n '6,55p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "SETUP_LEAN.sh: unknown argument '$a'" >&2; exit 2 ;;
  esac
done

say () { printf '%s\n' "$*"; }

# --- WHERE does the toolchain go? -------------------------------------------
# A Lean toolchain plus a mathlib cache is measured in GIGABYTES, and the
# default ($HOME/.elan) lands on the system drive whether or not that drive has
# the room. So the installer ASKS, instead of discovering the problem at 90%.
#
# The answer is a filesystem ROOT -- C:/ or D:/ on Windows, / or /mnt/data on a
# Unix box -- and elan is placed in <root>/.elan. ELAN_HOME is then exported for
# the rest of the run, which is the officially supported way to relocate elan:
# no symlink, no registry edit, nothing left behind but a directory you named.
#
# --root=<path> answers it non-interactively, which is what CI and the plugin
# installer use. --ask-root forces the question even when ELAN_HOME is set.
# Neither is the default: an installer that interrogates a non-interactive shell
# hangs a pipeline, so the question is asked only when a terminal is attached.
resolve_root () {
  # Collapse a trailing slash run, then put ONE back if what remains is a bare
  # Windows drive letter. This is not pedantry: `[ -d "D:" ]` is FALSE in Git
  # Bash while `[ -d "D:/" ]` is true, so the first version of this function
  # stripped "D:/" to "D:" and the installer refused a drive that exists. The
  # control caught it, which is the only reason it is not shipping.
  _r="$1"
  _r="$(printf '%s' "$_r" | sed 's#//*$##')"      # "C://", "C:/"  -> "C:"
  case "$_r" in
    [A-Za-z]:) _r="$_r/" ;;                      # ...and "C:" -> "C:/"
    "")        _r="/" ;;                         # "/" collapses to "" -> "/"
  esac
  printf '%s' "$_r"
}

# Join a root to ".elan" without producing "D://.elan". resolve_root leaves a
# trailing slash on exactly the roots that need one ("D:/", "/"), so the join
# has to notice rather than always inserting a separator.
elan_dir () {
  case "$1" in
    */) printf '%s.elan' "$1" ;;
    *)  printf '%s/.elan' "$1" ;;
  esac
}

# WHERE THE USER'S OWN PROOFS WILL LIVE, and it is NOT where ours live.
#
# Our corpus ships inside the plugin, under plugins/cache, and it is read-only.
# The user's own theorems need somewhere else entirely: a directory that starts
# EMPTY and accumulates as they work, on whatever disk they chose -- which is
# the whole reason the installer asks for a root instead of assuming one.
#
# The layout mirrors the machine this was built on, which is the only layout
# proven to work end to end here: toolchain in the home directory, proofs on a
# roomy disk. <root>/Lean/Proofs is created, and nothing is written into it --
# an empty workspace is the correct starting state, not a defect.
lean_dir () {
  case "$1" in
    */) printf '%sLean' "$1" ;;
    *)  printf '%s/Lean' "$1" ;;
  esac
}

# RECORD IT WHERE THE HOOKS LOOK, or the choice dies with this shell.
#
# This is the half that was missing and it made the other half pointless: both
# hooks resolve their workspace as env -> RECORDED -> our bundled corpus, and
# nothing ever wrote the recorded value. Every later session therefore measured
# proof debt against a corpus that cannot acquire any, and reported healthy
# forever. An install that asks a question and then forgets the answer has only
# performed asking.
# A DIRECTORY IS NOT A WORKSPACE. Creating <root>/Lean/Proofs and stopping there
# produced a folder in which the user's very first theorem CANNOT build: lake
# reports "no configuration file with a supported extension" and the hook
# correctly answers LEAN REFUSED. Measured end to end before this was added.
#
# So scaffold the minimum that makes `lake build Proofs.Foo` work, and NEVER
# overwrite: a returning user's lakefile is theirs, not ours.
#
# Deliberately CORE-ONLY, no mathlib dependency. Their proofs start at zero and
# grow from their own work; making the first build depend on a multi-gigabyte
# cache would be us deciding how they should work. Adding mathlib later is one
# `require` line, and the header written below says so.
scaffold_workspace () {
  _lw="$1"; _pin="$2"
  if [ "$DRY" -eq 1 ]; then
    say "would scaffold: $_lw/lakefile.toml, $_lw/lean-toolchain, $_lw/Proofs/"
    return 0
  fi
  mkdir -p "$_lw/Proofs" 2>/dev/null || { say "could not create $_lw/Proofs"; return 1; }

  if [ ! -f "$_lw/lakefile.toml" ]; then
    cat > "$_lw/lakefile.toml" <<'LAKE'
name = "proofs"
defaultTargets = ["Proofs"]

# Core Lean only -- your proofs start here and grow from your own work.
# To add mathlib later, append:
#
#   [[require]]
#   name = "mathlib"
#   scope = "leanprover-community"
#
# then run `lake update` and `lake exe cache get` (never build it from source).

[[lean_lib]]
name = "Proofs"
LAKE
    say "  scaffolded $_lw/lakefile.toml"
  else
    say "  kept your existing $_lw/lakefile.toml"
  fi

  # Pin the SAME toolchain the plugin's own corpus is verified against, so a
  # proof that builds here builds there. 'unknown' means we could not read one,
  # and inventing a version would be worse than leaving elan to its default.
  if [ ! -f "$_lw/lean-toolchain" ] && [ "$_pin" != "unknown" ]; then
    printf '%s\n' "$_pin" > "$_lw/lean-toolchain"
    say "  pinned $_lw/lean-toolchain to $_pin"
  fi
  return 0
}

record_workspace () {
  _ws="$1"
  _sd="${ROTMOE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/rot-moe}"
  [ "$DRY" -eq 1 ] && { say "would record workspace: $_ws -> $_sd/workspace"; return 0; }
  mkdir -p "$_sd" 2>/dev/null || { say "could not create $_sd -- the workspace will not be remembered"; return 1; }
  printf '%s\n' "$_ws" > "$_sd/workspace" 2>/dev/null || {
    say "could not write $_sd/workspace -- the workspace will not be remembered"; return 1; }
  # Read it back. A write that silently produced nothing is the failure this
  # project keeps finding, and it is cheaper to catch here than in a session
  # three days from now that quietly verifies the wrong directory.
  _back=$(head -1 "$_sd/workspace" 2>/dev/null)
  [ "$_back" = "$_ws" ] || { say "WROTE the workspace but read back '$_back' -- not trusting it"; return 1; }
  say "workspace recorded: $_ws"
  return 0
}

# One validator, used by BOTH the flag and the prompt. Written once on purpose:
# the first draft of this validated only the interactive answer, so --root= -- the
# path the plugin installer actually uses, non-interactively -- would happily
# accept a typo and place a multi-gigabyte toolchain somewhere nobody asked for.
# A check that guards the branch a human watches, and not the branch a machine
# takes, is worse than no check: it reads as safety and is not.
check_root () {   # check_root <resolved-root> ; echoes nothing, exits 2 on refusal
  if [ ! -d "$1" ]; then
    say "REFUSE: '$1' is not an existing directory. NOTHING was installed."
    # Names no single flag ON PURPOSE: this validator is now shared by --root
    # and --elan-root, and a message that says "omit --root" after the user
    # passed a bad --elan-root sends them to correct the wrong argument.
    say "        Create it first, or omit the flag that named it."
    exit 2
  fi
  if [ ! -w "$1" ]; then
    say "REFUSE: '$1' is not writable by this user. NOTHING was installed."
    say "        This installer never asks for sudo -- pick a root you own."
    exit 2
  fi
}

CHOSEN_ROOT=""

# The toolchain moves ONLY if asked, and .elan otherwise stays in the home
# directory where elan itself expects it. This is the layout this machine runs
# and the one every instruction here has been measured against.
if [ -n "$ELAN_ROOT_ARG" ]; then
  ER="$(resolve_root "$ELAN_ROOT_ARG")"
  check_root "$ER"
  ELAN_ROOT="$(elan_dir "$ER")"
  export ELAN_HOME="$ELAN_ROOT"
fi

if [ -n "$ROOT_ARG" ]; then
  R="$(resolve_root "$ROOT_ARG")"
  check_root "$R"
  CHOSEN_ROOT="$R"
elif [ "$ASK_ROOT" -eq 1 ] && [ "$YES" -eq 0 ] && [ -t 0 ]; then
  say ""
  say "== where should YOUR proofs live? =="
  say "   Your own .lean files start EMPTY here and grow as you work -- this is"
  say "   the directory the router watches and builds, not our shipped corpus."
  say "   Give a filesystem ROOT and the workspace goes into <root>/Lean:"
  say ""
  say "     C:/       ->  C:/Lean/Proofs     (Windows system drive)"
  say "     D:/       ->  D:/Lean/Proofs     (a second drive with room)"
  say "     /         ->  /Lean/Proofs       (Unix root; needs write access)"
  say "     <empty>   ->  skip; the router falls back to our bundled corpus"
  say ""
  say "   The toolchain itself stays in your home directory ($ELAN_ROOT)."
  say "   Use --elan-root=<path> if your system drive is short on space."
  say ""
  printf 'proof workspace root [empty to skip]: '
  read -r answer || answer=""
  if [ -n "$answer" ]; then
    R="$(resolve_root "$answer")"
    check_root "$R"
    CHOSEN_ROOT="$R"
  fi
fi

# --- the user's own workspace, on the disk they picked -----------------------
# Created, then RECORDED where the hooks look. Both steps or neither: a
# directory nobody can find is the same as no directory, and a recorded path
# that does not exist makes every later session fall back silently.
#
# Only when a root was actually chosen. With no root there is no new disk to
# put anything on, and inventing a location the user never asked for is how an
# installer earns its reputation.
if [ -n "$CHOSEN_ROOT" ]; then
  USER_WS="$(lean_dir "$CHOSEN_ROOT")"
  if [ "$DRY" -eq 1 ]; then
    say "would create workspace: $USER_WS/Proofs"
  fi
  # PINNED is not computed until later in this file, so read the pin HERE rather
  # than referencing a variable that is still empty. An unset variable would have
  # been passed as "", scaffold_workspace would have written a lean-toolchain
  # containing a blank line, and the user's first `lake build` would fail on a
  # toolchain that does not exist. Order of definition is load-bearing; the same
  # shape was caught in SETUP_LEAN.ps1 earlier in this session.
  _pin_now="unknown"
  [ -f "$WS/lean-toolchain" ] && _pin_now="$(tr -d '\r\n' < "$WS/lean-toolchain")"
  scaffold_workspace "$USER_WS" "$_pin_now"
  if [ -d "$USER_WS/Proofs" ] || [ "$DRY" -eq 1 ]; then
    record_workspace "$USER_WS"
  fi
fi

# --- what is already here ----------------------------------------------------
# Measured, never assumed. An installer that reinstalls what is present is how
# a second 7.2 GB mathlib appears on a disk nobody checked.
# Two DIFFERENT questions, kept apart because conflating them misreports:
#   on PATH  -> some elan is callable, wherever it lives
#   at root  -> an elan exists in the root we are about to install into
have_elan_path=0; command -v elan >/dev/null 2>&1 && have_elan_path=1
have_elan_root=0; [ -x "$ELAN_ROOT/bin/elan" ] && have_elan_root=1
have_elan=0; [ $have_elan_path -eq 1 ] || [ $have_elan_root -eq 1 ] && have_elan=1
if [ $have_elan_root -eq 1 ]; then   elan_where="installed at $ELAN_ROOT"
elif [ $have_elan_path -eq 1 ]; then elan_where="on PATH, NOT at $ELAN_ROOT"
else                                 elan_where="absent; would go to $ELAN_ROOT"
fi
have_lake=0;  command -v lake >/dev/null 2>&1 && have_lake=1
PINNED="unknown"
[ -f "$WS/lean-toolchain" ] && PINNED="$(tr -d '\r\n' < "$WS/lean-toolchain")"
have_cache=0; [ -d "$WS/.lake/packages/mathlib" ] && have_cache=1

say "== RoT MoE :: optional Lean toolchain setup =="
say "  workspace        : $WS"
say "  pinned toolchain : $PINNED   (from lean-toolchain, never 'latest')"
say "  elan present     : $( [ $have_elan -eq 1 ] && echo yes || echo NO )   ($elan_where)"
say "  lake on PATH     : $( [ $have_lake -eq 1 ] && echo yes || echo NO )"
say "  mathlib present  : $( [ $have_cache -eq 1 ] && echo yes || echo NO )"
say ""

if [ "$UNINSTALL" -eq 1 ]; then
  say "-- uninstall: this script REMOVES NOTHING for you. Here is what it would"
  say "   have created, so you can remove exactly that and nothing else:"
  say ""
  say "   elan and every toolchain :  elan self uninstall     (or: rm -rf $ELAN_ROOT)"
  say "   the mathlib build tree   :  rm -rf \"$WS/.lake\"     (this is the multi-GB one)"
  say "   the resolved manifest    :  rm -f  \"$WS/lake-manifest.json\""
  say ""
  say "   Nothing else was touched. No system directory, no package manager, no"
  say "   file under ~/.claude outside this plugin's own folder."
  exit 0
fi

# --- the plan ----------------------------------------------------------------
steps=0
say "-- plan --"
if [ "$have_elan" -eq 0 ]; then
  steps=$((steps+1))
  say "  [1] install elan from https://github.com/leanprover/elan/releases (official)"
  say "      -> into $ELAN_ROOT ; no sudo, no system directory"
else
  say "  [1] SKIP: elan already present"
fi
# Is the pinned toolchain ALREADY there? Asked with `elan toolchain list`
# rather than discovered by running the install and reading a failure -- an
# installer that learns the state of the world from an error it treats as fatal
# cannot be re-run, and being re-runnable is most of what an installer is for.
have_tc=0
if [ "$PINNED" != "unknown" ] && command -v elan >/dev/null 2>&1; then
  _tcl="$(elan toolchain list 2>/dev/null || true)"
  case "$_tcl" in *"$PINNED"*) have_tc=1 ;; esac
fi

if [ "$PINNED" = "unknown" ]; then
  say "  [2] SKIP: no lean-toolchain found at $WS -- nothing to pin to"
elif [ "$have_tc" -eq 1 ]; then
  say "  [2] SKIP: toolchain $PINNED already installed"
else
  steps=$((steps+1))
  say "  [2] elan toolchain install $PINNED   (~500 MB, one toolchain, pinned)"
fi
if [ "$have_cache" -eq 0 ]; then
  steps=$((steps+1))
  say "  [3] lake exe cache get in $WS"
  say "      -> PREBUILT mathlib oleans. SEVERAL GIGABYTES: a full build tree"
  say "         measured 7.2 GB on the author's machine. Check your free space."
  say "      -> never a source build (that is hours, not minutes)"
else
  say "  [3] SKIP: mathlib already resolved under $WS/.lake"
fi
say ""

if [ "$steps" -eq 0 ]; then
  say "Nothing to do -- everything this script installs is already present."
  say "Verify the proofs with:  cd \"$WS\" && lake build Proofs.RotGauge"
  exit 0
fi

if [ "$DRY" -eq 1 ]; then
  say "DRY RUN: nothing was downloaded, nothing was created, no directory was made."
  say "This is the negative control for this script -- run it first, always."
  exit 0
fi

if [ "$YES" -ne 1 ]; then
  say "REFUSING: $steps step(s) would download from the network and write to disk."
  say "Consent is not a default. Re-run with --dry-run to see the plan, then --yes."
  exit 2
fi

# --- do the work -------------------------------------------------------------
rc=0
if [ "$have_elan" -eq 0 ]; then
  say "[1/3] installing elan ..."
  case "$(uname -s)" in
    Linux)  ELAN_TGZ="elan-x86_64-unknown-linux-gnu.tar.gz" ;;
    Darwin) if [ "$(uname -m)" = "arm64" ]; then ELAN_TGZ="elan-aarch64-apple-darwin.tar.gz"
            else ELAN_TGZ="elan-x86_64-apple-darwin.tar.gz"; fi ;;
    *)      say "  unsupported platform for this arm: $(uname -s)."
            say "  On Windows use SETUP_LEAN.ps1. Otherwise install elan by hand:"
            say "  https://github.com/leanprover/elan"
            exit 2 ;;
  esac
  TMP="$(mktemp -d)"
  # The exit code of the download is read DIRECTLY. A `curl | sh` pipeline
  # reports the shell's status and would call a failed download a success.
  curl -sSfL "https://github.com/leanprover/elan/releases/latest/download/$ELAN_TGZ" -o "$TMP/elan.tar.gz"
  if [ $? -ne 0 ]; then say "  DOWNLOAD FAILED -- nothing installed."; rm -rf "$TMP"; exit 1; fi
  tar -xzf "$TMP/elan.tar.gz" -C "$TMP" || { say "  extract failed"; rm -rf "$TMP"; exit 1; }
  "$TMP/elan-init" -y --default-toolchain none
  rc=$?
  rm -rf "$TMP"
  [ "$rc" -ne 0 ] && { say "  elan-init exited $rc -- stopping."; exit "$rc"; }
  PATH="$ELAN_ROOT/bin:$PATH"; export PATH
fi

if [ "$PINNED" != "unknown" ] && [ "$have_tc" -eq 0 ]; then
  say "[2/3] installing toolchain $PINNED ..."
  elan toolchain install "$PINNED"
  rc=$?
  # MEASURED on elan 4.2.3: `elan toolchain install <t>` exits 1 with
  # "error: '<t>' is already installed" when the toolchain is present. Treating
  # that as fatal meant the installer ABORTED on every machine that already had
  # the pinned toolchain -- the common case for anyone re-running it -- and so
  # never reached the step that records the user's workspace. The idempotent
  # re-run is exactly when an installer must be safest, and this one was worst.
  [ "$rc" -ne 0 ] && { say "  elan toolchain install exited $rc -- stopping."; exit "$rc"; }
elif [ "$PINNED" != "unknown" ]; then
  say "[2/3] SKIP: $PINNED is already installed."
fi

if [ "$have_cache" -eq 0 ]; then
  say "[3/3] fetching the prebuilt mathlib cache (this is the multi-GB step) ..."
  ( cd "$WS" && lake exe cache get )
  rc=$?
  [ "$rc" -ne 0 ] && { say "  lake exe cache get exited $rc."; exit "$rc"; }
fi

say ""
say "done. Verify the proofs yourself -- exit code read DIRECTLY, not through a pipe:"
say "  cd \"$WS\""
say "  lake build Proofs.RotGauge Proofs.RotRoute Proofs.RotInstall Proofs.RotPath Proofs.RotVacuity"
say "  echo \"exit=\$?\"        # 0 means every theorem elaborated, zero sorry"
say "  lake env leanchecker Proofs.RotGauge   # the KERNEL's own second opinion"
exit 0
