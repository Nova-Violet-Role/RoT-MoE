#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE TAG SET IS DERIVED FROM ONE SOURCE, AND THE DERIVATION IS CHECKED HERE --
# ON A MACHINE WITH NO NETWORK AND NO REMOTE.
#
# `tag-manager.yml` enforces the tag invariants on GitHub: the 20-topic server
# cap, the superset rule, and the evidence scan that refuses a tag it cannot
# find in either account's trees. All of that is real, and NONE of it runs
# here. Until this repository has a remote, every one of those invariants is
# unverified locally -- which means `.github/tags.txt`, `README.md` and
# `CITATION.cff` can drift apart for as long as it takes to get a token, and
# the first sign would be a red CI run on a commit that looked fine.
#
# So this checker runs the SUBSET OF THE INVARIANTS THAT NEED NO NETWORK:
#
#   1. [TOPICS] has at most 20 entries          -- the GitHub server cap
#   2. [SIGNATURE] is a SUPERSET of [TOPICS]    -- tier 2 never loses a tag
#   3. no duplicates within a tier              -- a duplicate wastes a slot
#   4. the README signature block matches [SIGNATURE] exactly, as a SET
#   5. CITATION.cff keywords are drawn from [SIGNATURE]
#
# WHAT IT DELIBERATELY DOES NOT DO, stated so the green is not read as more
# than it is: it does NOT verify that a tag names something genuinely present
# in either account. That check requires the API and belongs to the workflow.
# A tag that is locally consistent can still be an overclaim, and this file
# cannot see the difference.
#
# NAMING: the README block is generated with a marker comment. The rule is that
# a HAND EDIT to the block must be caught, because a hand edit is how the
# generated and the source copies diverge in the first place.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }

TAGS=".github/tags.txt"
[ -f "$TAGS" ] || { echo "  FAIL  $TAGS missing -- there is no source of truth to check"; exit 1; }

echo "== tag consistency (local invariants only; the evidence scan is the workflow's) =="

# Section extraction: a tag line is a bare lowercase token; comments and blanks
# are skipped. Written as a function so the control below runs the SAME code
# rather than a re-typed approximation of it.
section () {   # section <file> <NAME>
  awk -v want="[$2]" '
    /^\[/ { insec = ($0 == want); next }
    !insec { next }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { gsub(/[[:space:]]/, ""); if (length($0)) print tolower($0) }
  ' "$1"
}

TOPICS="$(section "$TAGS" TOPICS)"
SIGNATURE="$(section "$TAGS" SIGNATURE)"
n_topics=$(printf '%s\n' "$TOPICS" | grep -c . || true)
n_sig=$(printf '%s\n' "$SIGNATURE" | grep -c . || true)
echo "  NOTE  [TOPICS] $n_topics entries · [SIGNATURE] $n_sig entries"

# 1. the hard server cap
if [ "$n_topics" -le 20 ]; then
  ok "[TOPICS] is within GitHub's 20-topic server cap ($n_topics)"
else
  bad "[TOPICS] has $n_topics entries -- the API rejects the 21st, so $((n_topics-20)) would be silently lost"
fi
[ "$n_topics" -gt 0 ] || bad "[TOPICS] is EMPTY -- the browsable surface would be blank"
[ "$n_sig" -gt 0 ]    || bad "[SIGNATURE] is EMPTY -- the unlimited surface would be blank"

# 2. superset: every topic must also be in the signature
missing="$(comm -23 <(printf '%s\n' "$TOPICS" | sort -u) <(printf '%s\n' "$SIGNATURE" | sort -u))"
if [ -z "$missing" ]; then
  ok "[SIGNATURE] is a superset of [TOPICS] -- no tag is lost between tiers"
else
  bad "[TOPICS] entries absent from [SIGNATURE]: $(echo "$missing" | tr '\n' ' ')"
fi

# 3. duplicates
for sec in TOPICS SIGNATURE; do
  dups="$(section "$TAGS" "$sec" | sort | uniq -d)"
  [ -z "$dups" ] && ok "[$sec] has no duplicates" \
                 || bad "[$sec] contains duplicates: $(echo "$dups" | tr '\n' ' ')"
done

# 4. the README block must match [SIGNATURE] as a set
if grep -q 'TAGS:BEGIN' README.md 2>/dev/null; then
  README_TAGS="$(awk '/TAGS:BEGIN/{f=1;next} /TAGS:END/{f=0} f' README.md \
    | grep -o '#[A-Za-z0-9]*' | sed 's/^#//' | tr 'A-Z' 'a-z' | sort -u)"
  SIG_NORM="$(printf '%s\n' "$SIGNATURE" | tr -d '-' | sort -u)"
  if [ "$README_TAGS" = "$SIG_NORM" ]; then
    ok "the README signature block matches [SIGNATURE] exactly ($(printf '%s\n' "$README_TAGS" | grep -c .) tags)"
  else
    bad "the README signature block has DRIFTED from .github/tags.txt"
    echo "        only in README:   $(comm -23 <(printf '%s\n' "$README_TAGS") <(printf '%s\n' "$SIG_NORM") | tr '\n' ' ')"
    echo "        only in tags.txt: $(comm -13 <(printf '%s\n' "$README_TAGS") <(printf '%s\n' "$SIG_NORM") | tr '\n' ' ')"
  fi
else
  bad "README.md has no TAGS block -- the unlimited surface is not present"
fi

# 5. CITATION keywords must be drawn from the signature tier
if [ -f CITATION.cff ]; then
  CIT="$(awk '/^keywords:/{f=1;next} /^[a-zA-Z]/{f=0} f' CITATION.cff \
    | grep -o '"[^"]*"' | tr -d '"' | tr 'A-Z' 'a-z' | sort -u)"
  n_cit=$(printf '%s\n' "$CIT" | grep -c . || true)
  stray="$(comm -23 <(printf '%s\n' "$CIT") <(printf '%s\n' "$SIGNATURE" | sort -u))"
  if [ "$n_cit" -eq 0 ]; then
    bad "CITATION.cff has no keywords -- citation indexes get nothing"
  elif [ -z "$stray" ]; then
    ok "all $n_cit CITATION.cff keywords come from [SIGNATURE]"
  else
    bad "CITATION.cff keywords not present in [SIGNATURE]: $(echo "$stray" | tr '\n' ' ')"
  fi
fi

# --- controls ---------------------------------------------------------------
echo
echo "-- negative controls --"
TCTL="$(mktemp -d "${TMPDIR:-/tmp}/tagctl.XXXXXX")"
{
  echo "[TOPICS]"
  for i in $(seq 1 21); do echo "tag$i"; done
  echo
  echo "[SIGNATURE]"
  echo "tag1"
} > "$TCTL/tags.txt"
c_topics=$(section "$TCTL/tags.txt" TOPICS | grep -c .)
c_missing="$(comm -23 <(section "$TCTL/tags.txt" TOPICS | sort -u) <(section "$TCTL/tags.txt" SIGNATURE | sort -u))"
if [ "$c_topics" -gt 20 ]; then
  ok "CONTROL: a 21st topic IS detected ($c_topics > 20)"
else
  bad "CONTROL DEAD: the extractor did not see 21 planted topics (saw $c_topics)"
fi
if [ -n "$c_missing" ]; then
  ok "CONTROL: a topic missing from [SIGNATURE] IS detected"
else
  bad "CONTROL DEAD: the superset check missed 20 planted absences"
fi
rm -rf "$TCTL"

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  tags-consistency: PASS"; exit 0; } || { echo "  tags-consistency: FAIL"; exit 1; }
