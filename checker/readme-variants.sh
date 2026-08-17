#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE DOWNLOAD LINKS MUST NAME ARCHIVES THAT EXIST.
#
# WHY THIS EXISTS, and it is not hypothetical. The README's install section told
# readers to download `rot-moe-0.5.1-lean.zip` while the packager was building
# `rot-moe-0.7.1-lean.zip`. Three links, all wrong, for two minor versions --
# every gate green the whole time. Nothing in this repository looked at the
# names, because the release map moved from a hand-written line to a computed
# one and the prose that quoted it did not follow.
#
# A stale download link is a specific kind of defect: it does not degrade the
# product, it makes the FIRST INSTRUCTION A NEW READER FOLLOWS fail. Someone
# arriving at this page gets a 404 and concludes the project is abandoned. That
# is worse than a wrong number in a table, and it was invisible to 45 checkers.
#
# WHAT THIS CHECKS
#   1. the packager's map parses at all (`--print-variants`, never by grepping
#      its source -- workflow-lint rule 6 forbids that and this obeys it);
#   2. every `<archive-basename>:<version>` line in that map appears in the
#      README as the exact archive filename. Since 6.0.0 the names carry no
#      version (`RoT-MoE-Router.zip` and its -Lean / -Lean-Extra tiers), so
#      this half can no longer rot on a release bump -- but the other half
#      still can;
#   3. NO OTHER archive name appears anywhere in the published docs -- neither
#      an unknown `RoT-MoE-*.zip` nor any name in the RETIRED versioned
#      convention (`rot-moe-X.Y.Z[-tier].zip`). This is the half that catches
#      staleness: requiring the right names to be present does not remove the
#      wrong ones, and the README had both correct prose and dead links in the
#      same section.
#
# WHAT THIS DOES NOT CHECK, said plainly: that the archives were uploaded to a
# GitHub Release, or that a link resolves over the network. This runs offline and
# in CI without credentials. It binds the README to the PACKAGER, which is the
# thing that decides the names; publishing them is `checker/release-package.sh`
# and the release workflow.
#
# Exit: 0 all names agree · 1 a mismatch · 2 refuse (the map would not parse).
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
# An unauthenticated caller cannot read CI logs (403, admin rights), so a failure
# that exists only in the log is one nobody outside the org can diagnose.
# `::error::` lines become annotations, and annotations are public.
bad() {
  echo "  FAIL  $*"
  [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=readme-variants::%s\n' "$*"
  fail=$((fail+1))
}

echo "== README download links vs the packager's own variant map =="

# EVERY PUBLISHED DOC, NOT ONLY THE README. The first version of this file read
# README.md alone, which would have left the identical defect free to recur one
# file over: RELEASE.md is the page a downloader lands on and it names the
# archives too. A checker scoped to the one place a defect happened to appear is
# how the same defect comes back wearing a different filename.
#
# `docs/*.md` is included by glob rather than by list, for the same reason the
# mutation suites are enumerated from disk in CI: a document added later must be
# covered without anyone remembering to add it here.
DOCS="README.md RELEASE.md"
for _d in docs/*.md; do [ -f "$_d" ] && DOCS="$DOCS $_d"; done
README="README.md"
[ -f "$README" ] || { echo "REFUSE: $README missing"; exit 2; }
_ndocs=0
for _d in $DOCS; do [ -f "$_d" ] && _ndocs=$((_ndocs+1)); done
ok "scanning $_ndocs published document(s) for archive names"

# THE MAP IS ASKED FOR, NOT PARSED OUT OF THE PACKAGER'S TEXT. Three files in
# this repository once recovered the release map by `sed`-ing
# release-package.sh's source, and all three broke silently when the line they
# matched became a computed expression. `--print-variants` exists for exactly
# this, and workflow-lint rule 6 now forbids the other way.
# The map is one line per variant, `<archive-basename>:<version>` -- e.g.
# `RoT-MoE-Router.zip:6.0.0`. The basename IS the filename; nothing here
# reassembles a name out of parts any more, because reassembly is where the
# 0.5-vs-0.7 defect lived.
MAP="$(bash "$REPO/checker/release-package.sh" --print-variants 2>/dev/null)"
_n=$(printf '%s\n' "$MAP" | tr ' ' '\n' | grep -c ':' )
if [ "${_n:-0}" -lt 3 ]; then
  bad "the packager returned $_n variant(s), expected at least 3 -- refusing to compare against a map that did not load"
  echo "  readme-variants: REFUSE"; exit 2
fi
ok "packager map read: $(printf '%s' "$MAP" | tr '\n' ' ')"

# --- 1. every declared archive must be named in the README -------------------
expected=""
for pair in $MAP; do
  zip="${pair%%:*}"
  expected="$expected $zip"
  if [ "$(grep -c -F "$zip" "$README")" -gt 0 ]; then
    ok "README names $zip"
  else
    bad "README never mentions $zip -- that tier has no download link"
  fi
done

# --- 2. no archive name that the packager does not produce -------------------
# The half that catches staleness. `grep -o` over the whole file, then subtract
# the expected set; anything left is a link to something that does not exist.
#
# BOTH conventions are scanned. An unknown `RoT-MoE-*.zip` is a link to an
# archive the packager does not build; and ANY `rot-moe-X.Y.Z[-tier].zip` is
# the versioned convention retired at 6.0.0, stale by definition -- the
# packager builds no versioned name any more, so none can be in `expected`.
ZIPRE='(RoT-MoE-[A-Za-z][A-Za-z-]*\.zip|rot-moe-[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+)?\.zip)'
_stale=0
for _d in $DOCS; do
  [ -f "$_d" ] || continue
  for found in $(grep -oE "$ZIPRE" "$_d" | sort -u); do
    _known=0
    for e in $expected; do [ "$found" = "$e" ] && _known=1; done
    if [ "$_known" -eq 0 ]; then
      bad "$_d links $found, which the packager does not build -- a dead download"
      _stale=$((_stale+1))
    fi
  done
done
[ "$_stale" -eq 0 ] && ok "no published doc names an archive the packager does not build"

# --- 3. CONTROL: this check must be able to fail -----------------------------
# Both directions, on a COPY -- the README is never touched. A checker whose
# controls are skipped when a tool is missing is a checker that silently stops
# being one, so this uses nothing but grep and a temp file.
CTL="$(mktemp -d "${TMPDIR:-/tmp}/rmvar.XXXXXX")"
trap 'rm -rf "$CTL"' EXIT

# (a) a stale link must be SEEN. Planted by APPENDING, not by sed-rewriting a
# name that is already there: the old plant rewrote `...-core.zip` links in
# place, so the day the README legitimately stopped carrying versioned names
# the plant would silently stop applying and the control would report
# DISCARDED against a correct document. An appended line applies always, and
# the plant is still verified before anything is concluded from it.
cp "$README" "$CTL/stale.md"
printf 'download rot-moe-0.1.0-core.zip today\n' >> "$CTL/stale.md"
if [ "$(grep -c -F 'rot-moe-0.1.0-core.zip' "$CTL/stale.md")" -eq 0 ]; then
  bad "CONTROL DISCARDED: the stale-link plant did not apply -- nothing was tested"
else
  _seen=0
  for found in $(grep -oE "$ZIPRE" "$CTL/stale.md" | sort -u); do
    _known=0
    for e in $expected; do [ "$found" = "$e" ] && _known=1; done
    [ "$_known" -eq 0 ] && _seen=1
  done
  if [ "$_seen" -eq 1 ]; then
    ok "CONTROL: a stale download link IS detected"
  else
    bad "CONTROL FAILED: a planted 0.1.0 link was not detected -- this check is decoration"
  fi
fi

# (b) a MISSING link must be seen. Deleting every line that names the smallest
# tier's archive is the shape of the real defect: a tier quietly loses its
# download. The name comes from the map's first line, never retyped here.
_corezip="$(printf '%s\n' "$MAP" | head -1 | cut -d: -f1)"
grep -v -F "$_corezip" "$README" > "$CTL/gone.md"
if [ "$(grep -c -F "$_corezip" "$CTL/gone.md")" -eq 0 ]; then
  ok "CONTROL: a tier with no download link IS detectable"
else
  bad "CONTROL DISCARDED: the link-removal plant did not apply"
fi

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  echo "  readme-variants: FAIL"
  exit 1
fi
echo "  readme-variants: every download link names an archive the packager builds"
exit 0
