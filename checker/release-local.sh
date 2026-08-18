#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# R23: THE LOCAL-ONLY RELEASE -- BUILT FROM HEAD, STAMPED, UNPUBLISHABLE
#
# The Socio asked for releases built and kept current in a .gitignore'd
# `.release-local-only/`, installed into CTT, and NOT published until the
# completion promise is earned. (When this file was written that meant a local
# 1.0.x family, distinct in its version digits; since 6.0.0 the archive names
# carry NO version at all, so what marks a build local is the STAMP and the
# .gitignore -- not a number.) That request has a trap inside it, and this file
# exists to disarm the trap rather than to zip three files.
#
# THE TRAP. An artifact sitting in a directory is evidence of nothing. Nobody can
# tell, a week later, whether `RoT-MoE-Router-Lean-Extra.zip` was built from the
# current tree, from a tree with a since-reverted experiment in it, or by hand.
# A stale local artifact is WORSE than no artifact: it gets installed into CTT,
# it passes, and the pass is attributed to code that is not what shipped. So the
# rule this file enforces is not "a zip exists" but:
#
#   a local release is evidence ONLY while it is regenerable from HEAD.
#
# Which is why nothing here packages the WORKING TREE. Every build starts from
# `git archive HEAD` -- a pristine export of the commit -- so "regenerable from
# HEAD" is true by construction, and phase 4 then proves it by regenerating and
# diffing the contents rather than trusting the claim.
#
# WHY THE LOCAL BUILD DOES NOT TOUCH THE TREE. checker/release-consistency.sh
# binds the manifest version to the newest published tag, so rewriting the real
# manifest to get a differently-versioned local build would put the tree ahead
# of every tag and turn a correct repository red. The version is therefore
# rewritten only in the throwaway export.
#
# Phase 5 asserts the INVARIANT, not the value: the manifest is byte-identical
# before and after this script. Stating it as "the tree still says 0.9.2" was a
# dated spec -- it went red the day the family was legitimately bumped, on a
# change that was entirely correct.
#
# The obligations come from lean/Proofs/RotLocalRelease.lean. These are the REAL
# theorem names, checked against the module -- an earlier draft of this header
# cited five names that did not exist in it, which is exactly the kind of
# citation that makes a checker look bound to a proof while binding to nothing:
#
#   local_never_publishable     -> phase 1: no local stamp is ever taggable
#   stale_is_not_fresh          -> phase 4: a different source is not evidence
#   fresh_survives_rebuild      -> phase 4: rebuilding the same source stays fresh
#   fresh_is_evidence           -> phase 4: something CAN pass; not a dead gate
#   unmeasured_is_not_evidence  -> phase 4: a failed digest is not a match
#   unmeasured_is_not_differs   -> phase 4: nor is it a mismatch -- three outcomes
#   evidence_implies_fresh      -> phase 4: a pass really does mean regenerated
#   publishable_says_nothing_about_freshness -> phases 1 and 4 are separate axes
#
# Phase 6 is the reason to believe the rest: it plants a MUTILATED artifact and
# requires phase 4 to reject it. An alarm nobody has tripped is an untested alarm.
#
# Exit: 0 pass, 1 fail, 2 refuse.
# =============================================================================
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok  () { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad () { FAIL=$((FAIL+1)); [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=release-local::%s\n' "$*"; printf '  FAIL  %s\n' "$1"; }
inf () { printf '  ----  %s\n' "$1"; }

command -v git   >/dev/null 2>&1 || { echo "REFUSE: git absent";   exit 2; }
command -v zip   >/dev/null 2>&1 || { echo "REFUSE: zip absent";   exit 2; }
command -v unzip >/dev/null 2>&1 || { echo "REFUSE: unzip absent"; exit 2; }
command -v tar   >/dev/null 2>&1 || { echo "REFUSE: tar absent";   exit 2; }

LOCALDIR="$REPO/.release-local-only"
MANIFEST=".claude-plugin/plugin.json"

# THE VERSION, DERIVED FROM THE MANIFEST -- never frozen.
#
# This line read `LOCALVER="1.0"` until 2026-08-13, and it is the SAME defect
# phase 5 below already documents having fixed once: a contingent fact written
# down as if it were an invariant. When the family was legitimately bumped the
# gate went RED on a CORRECT tree, hunting last version's archive name -- an
# alarm that names the wrong culprit, because nothing was missing. The durable
# statement is that this script tracks WHATEVER version the manifest declares,
# so the next bump needs no edit here at all. Derived, so it cannot drift.
#
# MAJOR.MINOR used to be enough, because the packager derived the patch digit
# per tier. Since 6.0.0 there is ONE version and the archive names carry none,
# so the full semver is read -- and used only for the banner and the STAMP.
TREEVER="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$REPO/$MANIFEST" | head -1)"
case "$TREEVER" in
  [0-9]*.[0-9]*.[0-9]*) : ;;
  *) echo "REFUSE: could not read a semver version from $MANIFEST (got '$TREEVER')"; exit 2 ;;
esac

# THE ARCHIVE NAMES ARE ASKED FOR, never reassembled. The old
# `rot-moe-$LOCALVER.N-tier.zip` spelling is gone with the convention that
# needed it; the packager prints `<archive-basename>:<version>` per variant,
# and the basenames are what every phase below addresses.
ZIPNAMES="$(bash "$REPO/checker/release-package.sh" --print-variants 2>/dev/null | cut -d: -f1)"
n_zip=$(printf '%s\n' "$ZIPNAMES" | grep -c . || true)
if [ "${n_zip:-0}" -lt 3 ]; then
  echo "REFUSE: could not read the archive names from checker/release-package.sh"
  echo "        (got '$ZIPNAMES') -- refusing a hardcoded fallback."
  exit 2
fi

# --- phase 5 baseline, captured BEFORE any packaging runs -------------------
# Phase 5 asks whether THIS SCRIPT modified the tracked manifest. It used to ask
# a different question -- whether the manifest still literally said "0.9.2" --
# which is a snapshot of a contingent fact, not the property that matters. When
# the family was legitimately bumped to 1.0.x the gate went RED on a CORRECT
# tree, and the obvious repair (delete or weaken the check) would have destroyed
# real coverage. The durable statement is: whatever the version is, this script
# must leave it alone. That holds for 0.9.2, for 1.0.2, and for every bump after.
_MANIFEST_BEFORE="$(cksum < "$REPO/$MANIFEST" 2>/dev/null || echo unreadable)"
_MANIFEST_VER_BEFORE="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$REPO/$MANIFEST" | head -1)"

echo "== release local-only :: $TREEVER from HEAD, never published =="

# --- phase 1: it must be IMPOSSIBLE to publish this by accident ---------------
# Checked BEFORE anything is built. A local-only directory that git can see is
# one `git add -A` away from being in the shared history, and the whole point of
# the Socio's request is that these three artifacts do not ship yet.
if [ -f "$REPO/.gitignore" ] && grep -qx '\.release-local-only/' "$REPO/.gitignore"; then
  ok "phase 1: .release-local-only/ is .gitignore'd -- git cannot stage it"
else
  bad "phase 1: .release-local-only/ is NOT in .gitignore -- a local artifact could be published by accident"
fi

# Belt and braces: ask git itself rather than trusting the pattern parse. A
# .gitignore line can be present and still not match (a leading slash, a typo).
# `git check-ignore` is git's OWN answer to "would you ignore this".
if git check-ignore -q ".release-local-only/probe.zip" 2>/dev/null; then
  ok "phase 1: git check-ignore agrees -- an artifact placed there is ignored"
else
  bad "phase 1: git check-ignore does NOT ignore .release-local-only/ -- the pattern does not match what will be written"
fi

# --- WHICH TREE IS "THE TREE"? ------------------------------------------------
# HEAD is the obvious answer and it is wrong in the one context this gate runs
# most: pre-commit. There, the content being released is in the INDEX -- staged,
# not yet committed -- and a build from HEAD refuses on the very change being
# committed. That is the "spec forbids a correct state" defect this repo already
# hit once with the CI-freshness gate, and the tempting repair (drop the gate
# from pre-commit) destroys the coverage instead of fixing the spec.
#
# So the source is the tree that is ABOUT to become HEAD when anything is staged,
# and HEAD itself otherwise. `git write-tree` turns the current index into a real
# tree object, which `git archive` accepts exactly like a commit. In CI the index
# equals HEAD, so this resolves to HEAD and nothing changes there.
HEADSHA="$(git rev-parse HEAD 2>/dev/null)"
case "$HEADSHA" in
  [0-9a-f][0-9a-f]*) : ;;
  *) echo "REFUSE: could not read HEAD"; exit 2 ;;
esac

SRCREF="$HEADSHA"; SRCWHAT="commit HEAD"
if ! git diff --cached --quiet 2>/dev/null; then
  _it="$(git write-tree 2>/dev/null)"
  case "$_it" in
    [0-9a-f][0-9a-f]*) SRCREF="$_it"; SRCWHAT="the STAGED index (tree $_it)" ;;
    *) inf "staged changes exist but git write-tree failed -- falling back to HEAD" ;;
  esac
fi
inf "packaging from $SRCWHAT"

# A NOTE, NOT A GATE -- but the one that saves the next reader an hour.
# Building from `git archive HEAD` means uncommitted work is INVISIBLE, which is
# the property that makes these artifacts trustworthy and also the most
# confusing failure mode there is: measured here, a freshly written CHANGELOG
# section sat in the working tree while the packager refused three times saying
# the shipped changelog did not mention 1.0.0. Nothing was wrong with either
# half. The build simply reflects the COMMIT. Say so, out loud, every run.
VERIFY_STATUS="$(mktemp "${TMPDIR:-/tmp}/relstatus.XXXXXX")"
git status --porcelain > "$VERIFY_STATUS" 2>/dev/null
DIRTY="$(grep -vc '^!!' "$VERIFY_STATUS")"
if [ "${DIRTY:-0}" -gt 0 ]; then
  inf "working tree has $DIRTY modified path(s) -- this build reflects $SRCWHAT, not the working tree"
  inf "if a packager check fails on content you just wrote: commit it, the export cannot see it"
fi

# --- phase 2: build from a PRISTINE export of HEAD, never the working tree ----
build_into () {
  # $1 = destination release dir. Returns 0 on a successful package.
  local dest="$1"
  local ex; ex="$(mktemp -d "${TMPDIR:-/tmp}/rellocal.XXXXXX")" || return 1
  # git archive is the pristine half: it emits the COMMIT, so an uncommitted
  # experiment in the working tree cannot leak into a local release and be
  # mistaken later for something that was in the history.
  if ! git archive "$SRCREF" | ( cd "$ex" && tar -xf - ) 2>/dev/null; then
    rm -rf "$ex"; return 1
  fi
  # NOTHING IS REWRITTEN IN THE EXPORT ANY MORE. Through 5.x this function
  # sed-ed a local version family into the export's version surfaces, so a
  # local build could never be mistaken for a published one by its digits.
  # Since 6.0.0 the archive names carry no version -- the packager builds the
  # same constant names from any tree -- so a rewritten family would change
  # NOTHING a stranger can see, while forging the very manifest the packager
  # now asserts against the tree (its assertion 6 reads the version back out
  # of every zip and requires the tree's own). What keeps a local build local
  # is the STAMP below and phase 1's .gitignore, not a number.
  rm -rf "$dest"; mkdir -p "$dest"
  # The log CANNOT live in $dest while the packager is running: release-package.sh
  # opens with `rm -rf "$OUT"` on the directory it is handed, which unlinks the
  # log mid-write and leaves a failure with no diagnosis -- measured, the first
  # run of this script reported "build FAILED (see .../build.log)" and there was
  # no such file. Write it outside, copy it in once the directory is final.
  local log; log="$(mktemp "${TMPDIR:-/tmp}/rellocalbuild.XXXXXX")"
  ( cd "$ex" && ROTMOE_RELEASE_DIR="$dest" bash checker/release-package.sh ) >"$log" 2>&1
  local rc=$?
  cp "$log" "$dest/build.log" 2>/dev/null
  rm -f "$log"
  rm -rf "$ex"
  return $rc
}

if build_into "$LOCALDIR"; then
  ok "phase 2: $n_zip variants at $TREEVER packaged from a pristine export of $SRCWHAT"
else
  bad "phase 2: the local package build FAILED (see $LOCALDIR/build.log)"
fi

for zn in $ZIPNAMES; do
  if [ -f "$LOCALDIR/$zn" ]; then
    ok "phase 2: $zn exists"
  else
    bad "phase 2: $zn is MISSING"
  fi
done

# --- phase 3: the stamp -- what commit, when, which build --------------------
# The counter is what makes "keep it constantly updated" auditable: build N+1
# supersedes N, and the sha says which tree each one was.
N=1
[ -f "$LOCALDIR/../.release-local-only.count" ] && N=$(( $(cat "$REPO/.release-local-only.count" 2>/dev/null || echo 0) + 1 ))
printf '%s\n' "$N" > "$REPO/.release-local-only.count"
{
  printf 'stamp: %s-local.%s\n' "$TREEVER" "$N"
  printf 'source: %s\n' "$SRCREF"
  printf 'source_is: %s\n' "$SRCWHAT"
  printf 'built_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'publishable: NO -- local only until the completion promise is earned\n'
} > "$LOCALDIR/STAMP"
if grep -q "^source: $SRCREF$" "$LOCALDIR/STAMP"; then
  ok "phase 3: STAMP records $SRCWHAT as build $TREEVER-local.$N"
else
  bad "phase 3: STAMP does not carry the source tree-ish -- freshness cannot be checked later"
fi

# --- phase 4: REGENERATE and diff -- the claim that makes this evidence -------
# Contents, not zip bytes. Two zips of identical trees differ in their stored
# timestamps, so a byte comparison would fail on a correct pair and teach the
# reader to ignore it. What must match is what a stranger unpacks: the file list
# and the sha256 of every file.
# `sha256sum` is GNU coreutils and DOES NOT EXIST on macOS, where the tool is
# `shasum -a 256`. Measured: this is the second of the two reasons this checker
# failed on every macOS run from 2026-08-08. Resolve the command ONCE, and
# REFUSE if neither is present rather than silently digesting nothing -- an
# empty digest would compare equal to another empty digest and pass.
if command -v sha256sum >/dev/null 2>&1; then
  SHA256() { sha256sum "$1"; }
elif command -v shasum >/dev/null 2>&1; then
  SHA256() { shasum -a 256 "$1"; }
elif command -v openssl >/dev/null 2>&1; then
  SHA256() { printf '%s  %s\n' "$(openssl dgst -sha256 -r "$1" | cut -d' ' -f1)" "$1"; }
else
  echo "REFUSE: no sha256 tool (sha256sum, shasum or openssl) -- cannot compare archives"
  exit 2
fi

digest_of () {
  # $1 = zip, $2 = output digest file
  local z="$1" out="$2" d
  d="$(mktemp -d "${TMPDIR:-/tmp}/reldig.XXXXXX")" || return 1
  unzip -qq "$z" -d "$d" 2>/dev/null || { rm -rf "$d"; return 1; }
  ( cd "$d" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s  %s\n' "$(SHA256 "$f" | cut -d' ' -f1)" "$f"
    done ) > "$out"
  rm -rf "$d"
  [ -s "$out" ]
}

VERIFY="$(mktemp -d "${TMPDIR:-/tmp}/relverify.XXXXXX")"
if build_into "$VERIFY/rel"; then
  # THREE OUTCOMES, NOT TWO. A chain of && here would fold "the digest tool
  # failed" into "the contents differ", and those mean opposite things: the
  # first is a broken instrument, the second is a real finding. Folding them is
  # the same defect as counting a mutation that never applied as SURVIVED -- it
  # reports in the reassuring direction. Each artifact is therefore classified
  # into exactly one of same / differs / UNMEASURED, and an unmeasured artifact
  # fails the phase on its own account with its own message.
  same=0; diffn=0; unmeasured=0
  for zn in $ZIPNAMES; do
    a="$LOCALDIR/$zn"; b="$VERIFY/rel/$zn"
    if [ ! -f "$a" ] || [ ! -f "$b" ]; then
      unmeasured=$((unmeasured+1)); inf "$zn: UNMEASURED -- an artifact is missing, nothing was compared"
      continue
    fi
    if ! digest_of "$a" "$VERIFY/a.$zn" || ! digest_of "$b" "$VERIFY/b.$zn"; then
      unmeasured=$((unmeasured+1)); inf "$zn: UNMEASURED -- the digest tool failed, this is NOT a mismatch"
      continue
    fi
    if cmp -s "$VERIFY/a.$zn" "$VERIFY/b.$zn"; then
      same=$((same+1))
    else
      diffn=$((diffn+1)); inf "$zn: regenerating from HEAD produced DIFFERENT contents"
    fi
  done
  if [ "$unmeasured" -gt 0 ]; then
    bad "phase 4: $unmeasured of $n_zip artifacts UNMEASURED -- reproducibility is unknown, not confirmed"
  fi
  if [ "$diffn" -gt 0 ]; then
    bad "phase 4: $diffn of $n_zip artifacts do not regenerate from HEAD -- the local release is stale or non-reproducible"
  fi
  if [ "$same" -eq "$n_zip" ]; then
    ok "phase 4: all $n_zip artifacts REGENERATE identically from the source tree -- they are evidence, not residue"
  fi
else
  bad "phase 4: the verification rebuild failed -- reproducibility is unproven"
fi

# --- phase 5: the real tree was NOT modified ----------------------------------
# The whole 1.0.x rewrite happens in a throwaway export. If this script ever
# starts editing the manifest in place, the repository silently claims a version
# it has never tagged -- and THAT is the failure this phase catches.
_MANIFEST_AFTER="$(cksum < "$REPO/$MANIFEST" 2>/dev/null || echo unreadable)"
_MANIFEST_VER_AFTER="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$REPO/$MANIFEST" | head -1)"
if [ "$_MANIFEST_BEFORE" = "unreadable" ] || [ -z "$_MANIFEST_VER_BEFORE" ]; then
  bad "phase 5: could not read $MANIFEST before packaging -- this check proves nothing"
elif [ "$_MANIFEST_BEFORE" = "$_MANIFEST_AFTER" ]; then
  ok "phase 5: the tracked manifest is byte-identical after packaging (still $_MANIFEST_VER_AFTER) -- the local build did not move the tree"
else
  bad "phase 5: $MANIFEST CHANGED during packaging ($_MANIFEST_VER_BEFORE -> $_MANIFEST_VER_AFTER) -- a local-only build has modified the tracked tree"
fi

# NOT `git status --porcelain | grep -q ...`: grep -q exits at the first match and
# SIGPIPEs git, so under `set -o pipefail` the pipeline reports 141 -- a MATCH is
# read as a failure. Materialise the output first, then search it.
git status --porcelain > "$VERIFY_STATUS" 2>/dev/null
if grep -q "^.. \.release-local-only" "$VERIFY_STATUS"; then
  bad "phase 5: git can SEE .release-local-only -- it is not effectively ignored"
else
  ok "phase 5: git status does not show .release-local-only -- unpublishable by construction"
fi
rm -f "$VERIFY_STATUS"

# --- phase 6: the negative control -- phase 4 must reject a bad artifact ------
# Without this, "all three regenerate" could equally mean "the comparison never
# runs". Mutilate a copy and require the digest comparison to notice.
CTL="$(mktemp -d "${TMPDIR:-/tmp}/relctl.XXXXXX")"
# The smallest tier is the map's first line -- asked for above, never retyped.
FIRSTZIP="$(printf '%s\n' "$ZIPNAMES" | head -1)"
cp "$LOCALDIR/$FIRSTZIP" "$CTL/mut.zip" 2>/dev/null
if [ -f "$CTL/mut.zip" ]; then
  mkdir -p "$CTL/extra" && printf 'not in HEAD\n' > "$CTL/extra/PLANTED.txt"
  ( cd "$CTL" && zip -q "mut.zip" "extra/PLANTED.txt" ) >/dev/null 2>&1
  if digest_of "$CTL/mut.zip" "$CTL/mut.dig" && digest_of "$LOCALDIR/$FIRSTZIP" "$CTL/good.dig"; then
    if cmp -s "$CTL/mut.dig" "$CTL/good.dig"; then
      bad "phase 6: a MUTILATED artifact compared EQUAL to the good one -- phase 4 proves nothing"
    else
      ok "phase 6: the digest comparison rejects a mutilated artifact -- phase 4's pass is real"
    fi
  else
    bad "phase 6: could not digest the control artifact -- the instrument is unverified"
  fi
else
  bad "phase 6: no artifact to mutilate -- the control could not run"
fi
rm -rf "$CTL" "$VERIFY"

echo
echo "== RESULT =="
printf '  %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
