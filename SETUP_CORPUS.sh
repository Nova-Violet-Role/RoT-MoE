#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# SETUP_CORPUS -- fetch or refresh the shared `Lean Theorem/` corpus.
#
# WHY THIS EXISTS, and why it is not a release artifact.
#
# The corpus GROWS BY FORK AND PULL REQUEST. Shipping it inside the release
# archives means a new release every time somebody contributes a theorem --
# which is backwards: the plugin version would be tracking other people's
# proofs. So the archives carry a SEED, and this fetches whatever `main` holds
# right now.
#
# It follows SETUP_LEAN's contract exactly, because that contract is already
# proven here: DETECT what you have, SAY what will change, ASK before doing it,
# and never invent a destination the user did not choose.
#
#   ./SETUP_CORPUS.sh              # detect, report, ask
#   ./SETUP_CORPUS.sh --check      # report only; never writes. Exit 0 = current,
#                                  #   3 = an update is available, 4 = absent
#   ./SETUP_CORPUS.sh --yes        # non-interactive: fetch/refresh without asking
#   ./SETUP_CORPUS.sh --dest=<dir> # where the corpus should live
#
# THE ONE RULE THIS FILE WILL NOT BREAK: it never silently overwrites a modified
# corpus. If your copy differs from what was last fetched, you are told which
# files differ and asked. A fetcher that quietly discards someone's local proof
# work is not a convenience, it is data loss with a progress bar.
# =============================================================================

set -uo pipefail

REPO_SLUG="${ROTMOE_CORPUS_REPO:-Nova-Violet-Role/RoT-MoE}"
BRANCH="${ROTMOE_CORPUS_BRANCH:-main}"
FOLDER="Lean Theorem"

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$SELF_DIR/$FOLDER"

MODE="ask"
for a in "$@"; do
  case "$a" in
    --check) MODE="check" ;;
    --yes|-y) MODE="yes" ;;
    --dest=*) DEST="${a#--dest=}" ;;
    -h|--help)
      sed -n '6,33p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "SETUP_CORPUS: unknown argument '$a' -- refusing rather than guessing" >&2
       exit 2 ;;
  esac
done

say () { printf '%s\n' "$*"; }

# --- what do we have right now? ----------------------------------------------
# Counted, never assumed. "The folder exists" is not the same as "the corpus is
# here": an empty directory left behind by an interrupted fetch would satisfy a
# -d test and teach the user nothing.
local_mods=0
if [ -d "$DEST" ]; then
  local_mods=$(find "$DEST" -name '*.lean' 2>/dev/null | grep -c . || true)
fi

STAMP="$DEST/.corpus-stamp"
have_stamp=""
[ -f "$STAMP" ] && have_stamp="$(head -1 "$STAMP" 2>/dev/null || true)"

say "== shared Lean corpus =="
if [ "$local_mods" -eq 0 ]; then
  say "  local:  ABSENT (no .lean files under '$DEST')"
else
  say "  local:  $local_mods module(s) in '$DEST'"
  [ -n "$have_stamp" ] && say "          last fetched at commit ${have_stamp:0:12}"
fi

# --- what does upstream have? ------------------------------------------------
# One network call, and it is allowed to fail: this script must degrade to a
# clear message, never to a stack trace or a silent no-op.
need_tool () { command -v "$1" >/dev/null 2>&1; }
if ! need_tool curl && ! need_tool wget; then
  say "  REFUSE: neither curl nor wget is available -- cannot reach GitHub"
  exit 2
fi

fetch_stdout () {  # fetch_stdout <url>
  if need_tool curl; then curl -fsSL "$1"; else wget -qO- "$1"; fi
}

API="https://api.github.com/repos/$REPO_SLUG/commits/$BRANCH"
remote_sha="$(fetch_stdout "$API" 2>/dev/null | tr ',' '\n' | grep -m1 '"sha"' | tr -d ' "' | cut -d: -f2 || true)"

if [ -z "$remote_sha" ]; then
  say "  remote: UNREACHABLE ($REPO_SLUG@$BRANCH)"
  say ""
  say "  Nothing was changed. Re-run when you have a connection; the corpus you"
  say "  already have on disk is untouched and still usable."
  [ "$MODE" = "check" ] && exit 2
  exit 2
fi
say "  remote: $REPO_SLUG@$BRANCH at ${remote_sha:0:12}"

# --- decide ------------------------------------------------------------------
status="update"
if [ "$local_mods" -eq 0 ]; then
  status="absent"
elif [ -n "$have_stamp" ] && [ "$have_stamp" = "$remote_sha" ]; then
  status="current"
fi

case "$status" in
  current) say "  -> up to date; nothing to do." ;;
  absent)  say "  -> the corpus is not installed here." ;;
  update)  say "  -> an update is available." ;;
esac

if [ "$MODE" = "check" ]; then
  case "$status" in
    current) exit 0 ;;
    update)  exit 3 ;;
    absent)  exit 4 ;;
  esac
fi

[ "$status" = "current" ] && exit 0

# --- protect local modifications ---------------------------------------------
# If a stamp exists we know what we last wrote. Anything newer than the stamp
# file is the user's own work, and it is not ours to discard.
modified=""
if [ -n "$have_stamp" ] && [ -d "$DEST" ]; then
  modified="$(find "$DEST" -name '*.lean' -newer "$STAMP" 2>/dev/null | head -20)"
fi
if [ -n "$modified" ]; then
  say ""
  say "  !! these files changed AFTER the last fetch -- refreshing REPLACES them:"
  printf '%s\n' "$modified" | sed 's/^/       /'
  say ""
fi

if [ "$MODE" = "ask" ]; then
  say ""
  say "  This will replace the contents of:"
  say "      $DEST"
  say "  with '$FOLDER' from $REPO_SLUG@$BRANCH (${remote_sha:0:12})."
  printf 'proceed? [y/N]: '
  read -r answer || answer=""
  case "$answer" in
    y|Y|yes|YES) : ;;
    *) say "  aborted; nothing was written."; exit 0 ;;
  esac
fi

# --- fetch -------------------------------------------------------------------
# Into a TEMP directory first, and only swapped in once the download is known
# good. Extracting straight over the destination leaves a half-updated corpus if
# the transfer dies -- and a half-updated corpus is the state that looks fine
# and builds wrong.
TMP="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/rotcorpus.$$")"
mkdir -p "$TMP" || { say "  REFUSE: cannot create a temp directory"; exit 2; }
cleanup () { rm -rf "$TMP"; }
trap cleanup EXIT

TARBALL="https://codeload.github.com/$REPO_SLUG/tar.gz/$remote_sha"
say ""
say "  downloading ${remote_sha:0:12} ..."
if need_tool curl; then
  curl -fsSL "$TARBALL" -o "$TMP/src.tar.gz"
else
  wget -qO "$TMP/src.tar.gz" "$TARBALL"
fi
rc=$?
if [ "$rc" -ne 0 ] || [ ! -s "$TMP/src.tar.gz" ]; then
  say "  REFUSE: download failed (exit $rc) -- your existing corpus is untouched"
  exit 1
fi

# Extract ONLY the corpus folder. The tarball's top directory is
# "<repo>-<sha>", which we do not know verbatim, so strip one component and
# select by path.
( cd "$TMP" && tar -xzf src.tar.gz ) || { say "  REFUSE: the archive did not extract"; exit 1; }
SRC="$(find "$TMP" -maxdepth 2 -type d -name "$FOLDER" | head -1)"
if [ -z "$SRC" ]; then
  say "  REFUSE: the download contains no '$FOLDER' folder -- refusing to touch your copy"
  exit 1
fi

new_mods=$(find "$SRC" -name '*.lean' | grep -c . || true)
if [ "$new_mods" -eq 0 ]; then
  say "  REFUSE: the downloaded '$FOLDER' holds no .lean file -- that is not an update,"
  say "          it is an erasure. Your copy is untouched."
  exit 1
fi

# --- swap in -----------------------------------------------------------------
if [ -d "$DEST" ]; then
  BAK="$DEST.pre-fetch-$(date +%Y%m%d-%H%M%S).bak"
  mv "$DEST" "$BAK" || { say "  REFUSE: could not move the old corpus aside"; exit 1; }
  say "  previous corpus kept at: $(basename "$BAK")"
fi
mv "$SRC" "$DEST" || { say "  REFUSE: could not install the new corpus"; exit 1; }
printf '%s\n' "$remote_sha" > "$DEST/.corpus-stamp"

final=$(find "$DEST" -name '*.lean' | grep -c . || true)
subj=$(find "$DEST" -mindepth 1 -maxdepth 1 -type d | grep -c . || true)
say ""
say "  installed: $subj subject(s), $final module(s) at ${remote_sha:0:12}"
if [ "$final" -ne "$new_mods" ]; then
  say "  FAIL: expected $new_mods modules but $final are on disk after the swap"
  exit 1
fi
say "  done."
exit 0
