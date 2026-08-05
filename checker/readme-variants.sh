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
#   2. every `name:version` pair in that map appears in the README as the exact
#      archive filename `rot-moe-<version>-<name>.zip`;
#   3. NO OTHER `rot-moe-*.zip` name appears anywhere in the README. This is the
#      half that catches staleness: requiring the right names to be present does
#      not remove the wrong ones, and the README had both correct prose and dead
#      links in the same section.
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

README="README.md"
[ -f "$README" ] || { echo "REFUSE: $README missing"; exit 2; }

# THE MAP IS ASKED FOR, NOT PARSED OUT OF THE PACKAGER'S TEXT. Three files in
# this repository once recovered the release map by `sed`-ing
# release-package.sh's source, and all three broke silently when the line they
# matched became a computed expression. `--print-variants` exists for exactly
# this, and workflow-lint rule 6 now forbids the other way.
MAP="$(bash "$REPO/checker/release-package.sh" --print-variants 2>/dev/null)"
_n=$(printf '%s\n' "$MAP" | tr ' ' '\n' | grep -c ':' )
if [ "${_n:-0}" -lt 3 ]; then
  bad "the packager returned $_n variant(s), expected at least 3 -- refusing to compare against a map that did not load"
  echo "  readme-variants: REFUSE"; exit 2
fi
ok "packager map read: $MAP"

# --- 1. every declared archive must be named in the README -------------------
expected=""
for pair in $MAP; do
  name="${pair%%:*}"; ver="${pair##*:}"
  zip="rot-moe-$ver-$name.zip"
  expected="$expected $zip"
  if [ "$(grep -c -F "$zip" "$README")" -gt 0 ]; then
    ok "README names $zip"
  else
    bad "README never mentions $zip -- the $name tier has no download link"
  fi
done

# --- 2. no archive name that the packager does not produce -------------------
# The half that catches staleness. `grep -o` over the whole file, then subtract
# the expected set; anything left is a link to something that does not exist.
_stale=0
for found in $(grep -oE 'rot-moe-[0-9]+\.[0-9]+\.[0-9]+-[a-z]+\.zip' "$README" | sort -u); do
  _known=0
  for e in $expected; do [ "$found" = "$e" ] && _known=1; done
  if [ "$_known" -eq 0 ]; then
    bad "README links $found, which the packager does not build -- a dead download"
    _stale=$((_stale+1))
  fi
done
[ "$_stale" -eq 0 ] && ok "no README link names an archive the packager does not build"

# --- 3. CONTROL: this check must be able to fail -----------------------------
# Both directions, on a COPY -- the README is never touched. A checker whose
# controls are skipped when a tool is missing is a checker that silently stops
# being one, so this uses nothing but grep and a temp file.
CTL="$(mktemp -d "${TMPDIR:-/tmp}/rmvar.XXXXXX")"
trap 'rm -rf "$CTL"' EXIT

# (a) a stale link must be SEEN
sed 's/rot-moe-[0-9]*\.[0-9]*\.[0-9]*-core\.zip/rot-moe-0.1.0-core.zip/' "$README" > "$CTL/stale.md"
if [ "$(grep -c -F 'rot-moe-0.1.0-core.zip' "$CTL/stale.md")" -eq 0 ]; then
  bad "CONTROL DISCARDED: the stale-link plant did not apply -- nothing was tested"
else
  _seen=0
  for found in $(grep -oE 'rot-moe-[0-9]+\.[0-9]+\.[0-9]+-[a-z]+\.zip' "$CTL/stale.md" | sort -u); do
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

# (b) a MISSING link must be seen. Deleting every line that names the core
# archive is the shape of the real defect: a tier quietly loses its download.
grep -v -F "rot-moe-$(printf '%s' "$MAP" | tr ' ' '\n' | grep '^core:' | cut -d: -f2)-core.zip" "$README" > "$CTL/gone.md"
_corezip="rot-moe-$(printf '%s' "$MAP" | tr ' ' '\n' | grep '^core:' | cut -d: -f2)-core.zip"
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
