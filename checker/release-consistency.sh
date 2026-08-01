#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# A RELEASE IS A CLAIM WITH A NUMBER ON IT.
#
# Three files declare the version -- `.claude-plugin/plugin.json`,
# `CITATION.cff`, and (once cut) the git tag. NOTHING checked that they agree.
# Measured 2026-08-01, before the first release: plugin.json said 1.0.0,
# CITATION said 1.0.0, and there was no tag at all, so the first `git tag v0.9`
# by anyone in a hurry would have shipped a release whose own metadata
# contradicted it. A user installs by tag and reads the version from the
# plugin; if those differ, the bug report they file is about the wrong code.
#
# WHAT THIS ENFORCES, and each one is a different failure:
#   1. plugin.json and CITATION.cff carry the SAME version.
#   2. If tags exist, the newest v-tag matches that version.
#   3. `date-released` is not in the FUTURE -- a citation dated tomorrow is a
#      claim about a thing that has not happened.
#   4. The version is semver-shaped, so tools that parse it do not guess.
#
# WHAT IT DELIBERATELY DOES NOT DO: invent a version, or "fix" a mismatch. A
# checker that edits the claim to match the code is how a spec becomes a
# rubber stamp. It reports and refuses.
#
# Exit: 0 consistent · 1 the version claims disagree · 2 refuse.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad() { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }

PJ=".claude-plugin/plugin.json"
CF="CITATION.cff"
[ -f "$PJ" ] || { echo "REFUSE: $PJ missing"; exit 2; }
[ -f "$CF" ] || { echo "REFUSE: $CF missing"; exit 2; }

echo "== release consistency =="

pj_ver=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PJ" | head -1)
cf_ver=$(sed -n 's/^version:[[:space:]]*\(.*\)$/\1/p' "$CF" | head -1 | tr -d '"'"'"' \r')

if [ -z "$pj_ver" ] || [ -z "$cf_ver" ]; then
  bad "could not read a version: plugin.json='${pj_ver:-<none>}' CITATION='${cf_ver:-<none>}'"
elif [ "$pj_ver" = "$cf_ver" ]; then
  ok "plugin.json and CITATION.cff agree: $pj_ver"
else
  bad "VERSION DRIFT: plugin.json says '$pj_ver', CITATION.cff says '$cf_ver'"
fi

case "$pj_ver" in
  [0-9]*.[0-9]*.[0-9]*) ok "version is semver-shaped: $pj_ver" ;;
  *) bad "version '$pj_ver' is not MAJOR.MINOR.PATCH -- tools that parse it will guess" ;;
esac

# --- the tag, if one exists -------------------------------------------------
# Tags are optional (a repo before its first release has none), but a tag that
# CONTRADICTS the declared version is worse than no tag.
newest_tag=$(git tag --list 'v*' --sort=-v:refname 2>/dev/null | head -1)
if [ -z "$newest_tag" ]; then
  echo "  NOTE  no v* tag yet -- nothing to contradict. Not a pass, not a failure."
else
  tag_ver="${newest_tag#v}"
  if [ "$tag_ver" = "$pj_ver" ]; then
    ok "newest tag $newest_tag matches the declared version"
  else
    bad "TAG DRIFT: newest tag is $newest_tag but the tree declares $pj_ver"
  fi
  # An annotated tag carries a message and a tagger; a lightweight one is just
  # a moving pointer. Releases should be annotated so the claim is signed to a
  # person and a date.
  # No pipe into grep -q: portability.sh forbids it repo-wide, and it caught
  # this line the moment the file was added. `git cat-file -t` prints one word,
  # so a string comparison is both cheaper and race-free.
  if [ "$(git cat-file -t "$newest_tag" 2>/dev/null)" = "tag" ]; then
    ok "$newest_tag is an ANNOTATED tag (carries a message and a tagger)"
  else
    bad "$newest_tag is lightweight -- a release tag should be annotated (git tag -a)"
  fi
fi

# --- the date must not be in the future -------------------------------------
cf_date=$(sed -n 's/^date-released:[[:space:]]*\(.*\)$/\1/p' "$CF" | head -1 | tr -d "'\" \r")
today=$(date -u +%Y-%m-%d)
if [ -z "$cf_date" ]; then
  bad "CITATION.cff has no date-released"
elif [ "$cf_date" \> "$today" ]; then
  bad "date-released $cf_date is in the FUTURE (today is $today) -- a citation for something that has not happened"
else
  ok "date-released $cf_date is not in the future (today $today)"
fi

# --- controls ---------------------------------------------------------------
echo
echo "-- negative controls --"
# Each predicate re-run on synthetic input that is deliberately wrong, so a
# passing check cannot be confused with a check that never matched anything.
if [ "1.0.0" != "0.9.0" ]; then
  ok "CONTROL: two different version strings ARE distinguishable"
else
  bad "CONTROL DEAD: string comparison is broken"
fi
if [ "2999-01-01" \> "$today" ]; then
  ok "CONTROL: a far-future date IS detected as future"
else
  bad "CONTROL DEAD: the future-date comparison never fires"
fi
case "1.0" in
  [0-9]*.[0-9]*.[0-9]*) bad "CONTROL DEAD: '1.0' passed the semver shape test" ;;
  *) ok "CONTROL: a two-part version '1.0' IS rejected as non-semver" ;;
esac

printf '\n== release consistency: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
