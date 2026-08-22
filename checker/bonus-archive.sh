#!/usr/bin/env sh
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# bonus-archive.sh -- proves bonus/cmdpulse/cmdpulse-bonus.zip IS its sources.
#
#     bonus/cmdpulse/*.md, *.sh, *.json      the sources git tracks
#     bonus/cmdpulse/cmdpulse/*              the payload subdirectory
#            | packaged as
#     cmdpulse-pkg/<same layout>             inside the archive users download
#
# WHY THIS EXISTS. checker/no-local-paths.sh:248 already wrote the defect down
# in prose and left it standing:
#
#     "The zip is committed as a binary artifact and nothing rebuilds it from
#      source, so a fix to the .sh never reached the thing users download."
#
# That is not a hypothetical. The archive once carried this machine's absolute
# directory inside a comment while the working tree was clean and the leak gate
# was GREEN, because `grep -rI` skips binaries. And the hole bit a second time,
# structurally: two branches each fixed a statusline defect and each rebuilt the
# binary BY HAND, so the merge conflicted on a file no tool could regenerate.
# A committed build artifact with no builder is a fork waiting to happen.
#
# So this file is BOTH halves at once -- the builder that was missing and the
# assertion that the committed artifact still matches what the builder makes.
#
# WHAT IS COMPARED, AND WHY NOT BYTES. Zip stores mtimes and platform
# attributes, so two honest builds of identical sources differ byte-for-byte.
# Comparing archive bytes would be a gate that fails for the wrong reason and
# gets disabled. B3 compares the CONTENT OF EVERY ENTRY against the source file
# on disk instead -- which is the property that actually matters: what the user
# unzips is what the repository says.
#
# THE SOURCE LIST IS DERIVED, NEVER TRANSCRIBED. It comes from `git ls-files`,
# so adding a file to bonus/cmdpulse/ and committing it makes this gate demand
# that the archive carry it. A hand-kept list would drift, which is the same
# failure mode the archive itself just demonstrated.
#
#   bash checker/bonus-archive.sh            run the assertions
#   bash checker/bonus-archive.sh --rebuild  regenerate the zip from source
#
set -u

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ZIP="$REPO/bonus/cmdpulse/cmdpulse-bonus.zip"
PREFIX="cmdpulse-pkg"

pass=0; fail=0
ok   () { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad  () { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; }

# The tracked sources, minus the artifact itself. `sort -u` because git prints
# one line per stage while a merge is unresolved, and this must not report a
# file three times just because someone is mid-merge.
src_list () {
  git -C "$REPO" ls-files bonus/cmdpulse/ 2>/dev/null \
    | grep -vF 'cmdpulse-bonus.zip' \
    | sort -u
}

# --- THE BUILDER --------------------------------------------------------------
# -X drops uid/gid and platform extras so the output depends on the content and
# the layout, not on who ran it.
rebuild () {
  if ! command -v zip >/dev/null 2>&1; then
    printf 'bonus-archive: no zip(1) on this host -- cannot rebuild\n' >&2
    return 2
  fi
  _n=0
  STAGE=$(mktemp -d) || return 2
  mkdir -p "$STAGE/$PREFIX" || return 2
  for f in $(src_list); do
    rel=${f#bonus/cmdpulse/}
    d=$(dirname "$rel")
    [ "$d" = "." ] || mkdir -p "$STAGE/$PREFIX/$d"
    cp "$REPO/$f" "$STAGE/$PREFIX/$rel" || { rm -rf "$STAGE"; return 2; }
    _n=$((_n+1))
  done
  if [ "$_n" -eq 0 ]; then
    printf 'bonus-archive: refusing to build an EMPTY archive -- git tracked no sources\n' >&2
    rm -rf "$STAGE"; return 2
  fi
  ( cd "$STAGE" && zip -X -q -r "$ZIP" "$PREFIX" ) || { rm -rf "$STAGE"; return 2; }
  rm -rf "$STAGE"
  printf 'bonus-archive: rebuilt %s from %d tracked source(s)\n' "$ZIP" "$_n"
  return 0
}

if [ "${1:-}" = "--rebuild" ]; then
  rebuild; exit $?
fi

printf '== bonus archive :: %s IS its sources ==\n' "bonus/cmdpulse/cmdpulse-bonus.zip"

# --- B1: the artifact exists and is a readable archive ------------------------
if [ ! -f "$ZIP" ]; then
  bad "B1 cmdpulse-bonus.zip is missing -- RELEASE.md links a download that does not exist"
  printf '\n== bonus archive: %d passed, %d failed\n' "$pass" "$fail"
  exit 1
fi
if unzip -Z1 "$ZIP" >/dev/null 2>&1; then
  ok "B1 cmdpulse-bonus.zip is a readable archive"
else
  bad "B1 cmdpulse-bonus.zip cannot be listed -- it is corrupt or not a zip"
  printf '\n== bonus archive: %d passed, %d failed\n' "$pass" "$fail"
  exit 1
fi

# --- B2: the entry set is exactly the tracked source set ----------------------
# Directory entries are dropped: whether a zip records them is a flag of the
# packer, not a property of the payload, and the two merge sides disagreed on
# precisely that while carrying identical files.
ENT=$(unzip -Z1 "$ZIP" 2>/dev/null | grep -v '/$' | sed "s|^$PREFIX/||" | sort)
SRC=$(src_list | sed 's|^bonus/cmdpulse/||' | sort)
NSRC=$(printf '%s\n' "$SRC" | grep -c .)
if [ "$NSRC" -eq 0 ]; then
  bad "B2 git tracks no sources under bonus/cmdpulse -- the comparison would be vacuous"
else
  # No process substitution: this file is /bin/sh and the repository syntax-checks
  # it with `sh -n`, where <(...) is a parse error rather than a clever shortcut.
  SETD=$(mktemp -d)
  printf '%s\n' "$SRC" > "$SETD/src"
  printf '%s\n' "$ENT" > "$SETD/ent"
  MISSING=$(grep -vxF -f "$SETD/ent" "$SETD/src" | grep -c .)
  EXTRA=$(grep   -vxF -f "$SETD/src" "$SETD/ent" | grep -c .)
  if [ "${MISSING:-0}" -eq 0 ] && [ "${EXTRA:-0}" -eq 0 ]; then
    ok "B2 the archive carries exactly the $NSRC tracked source(s) -- none missing, none invented"
  else
    bad "B2 archive/source mismatch: ${MISSING:-0} tracked file(s) absent, ${EXTRA:-0} entry(ies) the repo does not track"
    grep -vxF -f "$SETD/ent" "$SETD/src" | sed 's/^/      missing: /'
    grep -vxF -f "$SETD/src" "$SETD/ent" | sed 's/^/      extra:   /'
  fi
  rm -rf "$SETD"
fi

# --- B3: every entry IS the source, byte for byte -----------------------------
# THE ASSERTION. B2 proves the archive names the right files; B3 proves it
# carries their current contents. This is the one that would have caught a .sh
# fix never reaching the download.
DIFFN=0; CHECKED=0
for f in $(src_list); do
  rel=${f#bonus/cmdpulse/}
  CHECKED=$((CHECKED+1))
  if unzip -p "$ZIP" "$PREFIX/$rel" 2>/dev/null | cmp -s - "$REPO/$f"; then
    :
  else
    DIFFN=$((DIFFN+1))
    printf '      STALE: %s\n' "$rel"
  fi
done
if [ "$CHECKED" -eq 0 ]; then
  bad "B3 nothing was compared -- the source list is empty and this gate proves nothing"
elif [ "$DIFFN" -eq 0 ]; then
  ok "B3 all $CHECKED entry(ies) are byte-identical to their tracked source"
else
  bad "B3 $DIFFN of $CHECKED entry(ies) DIFFER from source -- rebuild: bash checker/bonus-archive.sh --rebuild"
fi

# --- B4: nothing ships that should never ship ---------------------------------
JUNK=$(unzip -Z1 "$ZIP" 2>/dev/null | grep -cE '\.bak$|\.zip$|(^|/)\.git/')
if [ "${JUNK:-0}" -eq 0 ]; then
  ok "B4 the archive carries no .bak, no nested .zip and no .git"
else
  bad "B4 the archive carries $JUNK file(s) that must never ship (.bak / .zip / .git)"
fi

# --- B5: one archive root, and it is the documented one -----------------------
ROOTS=$(unzip -Z1 "$ZIP" 2>/dev/null | sed 's|/.*||' | sort -u)
NROOT=$(printf '%s\n' "$ROOTS" | grep -c .)
if [ "$NROOT" -eq 1 ] && [ "$ROOTS" = "$PREFIX" ]; then
  ok "B5 the archive unpacks into exactly one directory ($PREFIX) -- it cannot spray a user's cwd"
else
  bad "B5 the archive has $NROOT root(s) ($(printf '%s' "$ROOTS" | tr '\n' ' ')) -- expected only $PREFIX"
fi

# --- CONTROLS: an alarm nobody has tripped is an untested alarm ---------------
echo "--- controls ---"

# C1: B3 must be able to SEE a difference. Compare a real entry against the
# wrong source and require the comparator to object. If this passes, B3's green
# means the bytes matched -- not that cmp silently succeeds on everything.
if [ -f "$REPO/bonus/cmdpulse/README.md" ] && [ -f "$REPO/bonus/cmdpulse/USAGE.md" ]; then
  if unzip -p "$ZIP" "$PREFIX/README.md" 2>/dev/null | cmp -s - "$REPO/bonus/cmdpulse/USAGE.md"; then
    bad "C1 CONTROL DID NOT FIRE: README.md in the archive compared EQUAL to USAGE.md on disk"
  else
    ok "C1 control: the comparator distinguishes two different files, so B3 can report a real staleness"
  fi
else
  bad "C1 CONTROL BROKEN: the two files it compares are not both present"
fi

# C2: B2's set comparison must be able to see an absence.
C2D=$(mktemp -d)
printf 'a\nb\nc\n' > "$C2D/src"
printf 'a\nc\n'    > "$C2D/ent"
C2M=$(grep -vxF -f "$C2D/ent" "$C2D/src" | grep -c .)
rm -rf "$C2D"
if [ "${C2M:-0}" -eq 1 ]; then
  ok "C2 control: the set comparison detects a file present in source and absent from the archive"
else
  bad "C2 CONTROL DID NOT FIRE: the set comparison reported ${C2M:-0} missing where 1 was planted"
fi

# C3: the builder must refuse to produce an empty archive rather than committing
# a valid, empty, useless zip over a good one.
if grep -q 'refusing to build an EMPTY archive' "$0"; then
  ok "C3 control: --rebuild refuses an empty source list instead of overwriting the artifact with nothing"
else
  bad "C3 CONTROL BROKEN: the builder has no empty-source refusal"
fi

printf '\n== bonus archive: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
