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

YES=0; DRY=0; UNINSTALL=0
for a in "$@"; do
  case "$a" in
    --yes|-y)     YES=1 ;;
    --dry-run|-n) DRY=1 ;;
    --uninstall)  UNINSTALL=1 ;;
    --help|-h)
      sed -n '6,55p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "SETUP_LEAN.sh: unknown argument '$a'" >&2; exit 2 ;;
  esac
done

say () { printf '%s\n' "$*"; }

# --- what is already here ----------------------------------------------------
# Measured, never assumed. An installer that reinstalls what is present is how
# a second 7.2 GB mathlib appears on a disk nobody checked.
have_elan=0;  command -v elan >/dev/null 2>&1 && have_elan=1
[ -x "$ELAN_ROOT/bin/elan" ] && have_elan=1
have_lake=0;  command -v lake >/dev/null 2>&1 && have_lake=1
PINNED="unknown"
[ -f "$WS/lean-toolchain" ] && PINNED="$(tr -d '\r\n' < "$WS/lean-toolchain")"
have_cache=0; [ -d "$WS/.lake/packages/mathlib" ] && have_cache=1

say "== RoT MoE :: optional Lean toolchain setup =="
say "  workspace        : $WS"
say "  pinned toolchain : $PINNED   (from lean-toolchain, never 'latest')"
say "  elan present     : $( [ $have_elan -eq 1 ] && echo yes || echo NO )   ($ELAN_ROOT)"
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
if [ "$PINNED" != "unknown" ]; then
  steps=$((steps+1))
  say "  [2] elan toolchain install $PINNED   (~500 MB, one toolchain, pinned)"
else
  say "  [2] SKIP: no lean-toolchain found at $WS -- nothing to pin to"
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

if [ "$PINNED" != "unknown" ]; then
  say "[2/3] installing toolchain $PINNED ..."
  elan toolchain install "$PINNED"
  rc=$?
  [ "$rc" -ne 0 ] && { say "  elan toolchain install exited $rc -- stopping."; exit "$rc"; }
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
