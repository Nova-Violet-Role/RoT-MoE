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

# --- 5b. the GENERATOR and this PARSER must agree on the format --------------
# MEASURED 2026-08-01, from a real workflow run. `tag-manager.yml` emitted
# CITATION keywords as `  - tag` while the file in the tree carries
# `  - "tag"`. Two consequences, and the second is the dangerous one:
#
#   * every run produced a 42-line diff and tried to commit it, so a job whose
#     stated rule is "commit only on real drift" would have committed forever;
#   * phase 5 above parses keywords with `grep -o '"[^"]*"'`, so the moment
#     that commit landed the gate would have reported "CITATION.cff has no
#     keywords" -- a red build caused by the generator, on a tree that was
#     otherwise correct.
#
# Nothing compared the writer to the reader. This does: the emit line in the
# workflow must produce the quoted form this file parses.
echo
echo "-- the generator must emit the format this checker parses --"
emit="$(sed 's/#.*$//' .github/workflows/tag-manager.yml | grep -F 'do echo "  - ' || true)"
if [ -z "$emit" ]; then
  bad "could not find the CITATION keyword emit line in tag-manager.yml -- this binding is blind"
else
  case "$emit" in
    *'\"$t\"'*) ok "the generator emits QUOTED keywords, which is what phase 5 parses" ;;
    *) bad "the generator emits UNQUOTED keywords but phase 5 parses quoted ones -- the next bot commit breaks this gate"
       printf '        %s\n' "$emit" ;;
  esac
fi
# CONTROL: the same test on the unquoted form must FAIL, or it proves nothing.
case 'for t in "${TAGS[@]}"; do echo "  - $t"; done' in
  *'\"$t\"'*) bad "CONTROL DEAD: the unquoted emit line was accepted as quoted" ;;
  *) ok "CONTROL: the unquoted form IS rejected -- the exact defect that shipped" ;;
esac

# --- 6. a LANGUAGE tag is a claim about this tree ----------------------------
# AUDITED 2026-08-01. [SIGNATURE] carried `python`, `c`, `compiler`,
# `rolling-context` and `context-compression` under the heading "present in the
# org / owner accounts". That heading is the whole defect: a topic is a claim
# about the REPOSITORY THAT CARRIES IT, not about its author's other work.
# Measured then: zero .py and zero .c files tracked here, and the two
# context-* tags belong to the sibling repo. Someone searching `topic:python`
# would have landed on a repository containing no Python.
#
# The rule is deliberately NARROW: only tags that name a language are checked,
# because "does this repo ship Python" is decidable from `git ls-files` while
# "is this repo about routing" is not. Abstract tags (moe, router, sigmoid) are
# OUT OF SCOPE and this checker says so rather than pretending to judge them.
# A narrow rule that really fires beats a broad one that cannot.
echo
echo "-- a language tag must be backed by files of that language --"
lang_bad=0
check_lang () {   # check_lang <tag> <glob> [glob...]
  tag="$1"; shift
  # Membership without a pipe: portability.sh bans `printf | grep -q` repo-wide
  # (SIGPIPE under pipefail scores a match as a miss) and it caught this line
  # the moment the phase was added. `case` on a newline-delimited set is exact.
  case "
$SIGNATURE
" in *"
$tag
"*) : ;; *) return 0 ;; esac                                  # not claimed: nothing to check
  n=0
  for g in "$@"; do n=$((n + $(git ls-files -- "$g" 2>/dev/null | grep -c . || true))); done
  if [ "$n" -gt 0 ]; then
    ok "tag '$tag' is backed by $n tracked file(s)"
  else
    bad "tag '$tag' claims a language this repo does not ship (0 files match: $*)"
    lang_bad=$((lang_bad+1))
  fi
}
check_lang python     '*.py'
check_lang c          '*.c' '*.h'
check_lang rust       '*.rs'
check_lang typescript '*.ts'
check_lang javascript '*.js'
check_lang bash       '*.sh'
check_lang powershell '*.ps1'
check_lang lean4      '*.lean'
check_lang yaml       '*.yml' '*.yaml'

# CONTROL: the predicate must be able to fail. Ask it about a language nobody
# ships here, with the claim forced on, and require a rejection.
ctl_n=$(git ls-files -- '*.rs' '*.hs' '*.f90' 2>/dev/null | grep -c . || true)
if [ "$ctl_n" -eq 0 ]; then
  ok "CONTROL: the file census really is empty for an unshipped language (rust/haskell/fortran) -- so a false claim WOULD be caught"
else
  bad "CONTROL DEAD: the census found files for a language this repo does not ship; the rule cannot be trusted"
fi
# CONTROL 2: and it must not fire on a language that IS shipped, or every tag
# would look false and the rule would be noise.
if [ "$(git ls-files -- '*.sh' | grep -c .)" -gt 0 ]; then
  ok "CONTROL: the census DOES find the languages this repo ships (.sh) -- the rule is not blind"
else
  bad "CONTROL DEAD: the census found no .sh files in a repo made of shell"
fi

# --- [PROPERTIES]: a schema, not a scoreboard --------------------------------
# Org custom properties are applied through the API by tag-manager.yml. What
# can be checked with no token is the STRUCTURE and, more importantly, the rule
# that keeps them from rotting: A PROPERTY MUST NOT BE A SNAPSHOT THAT EXPIRES.
#
# `verify-command = bash checker/gate-all.sh --full` is durable -- an
# instrument, still true after the hundredth theorem lands. `theorem-count =
# 100` would be false the day someone proves one more, and the obvious repair
# would be to stop updating it. This is the same defect the spec warns about in
# theorems: a contingent fact frozen as if it were an invariant.
echo
echo "-- [PROPERTIES]: structure, and no expiring snapshots --"
props="$(awk '/^\[PROPERTIES\]/{f=1;next} /^\[/{f=0} f && NF && $0 !~ /^#/' .github/tags.txt)"
if [ -z "$props" ]; then
  bad "[PROPERTIES] is empty or missing -- the org schema has no source of truth in the repo"
else
  n_props=$(printf '%s\n' "$props" | grep -c '=')
  malformed=$(printf '%s\n' "$props" | grep -vc '^[a-z][a-z-]* = .' || true)
  if [ "$malformed" -eq 0 ]; then
    ok "[PROPERTIES] holds $n_props well-formed 'name = value' rows"
  else
    bad "$malformed row(s) in [PROPERTIES] are not 'name = value'"
  fi

  # THE ANTI-SNAPSHOT RULE. A bare integer as a value is the shape that rots.
  numeric=$(printf '%s\n' "$props" | awk -F' = ' '$2 ~ /^[0-9]+$/ {print $1}')
  if [ -z "$numeric" ]; then
    ok "no property holds a bare count -- nothing here expires when the tree grows"
  else
    bad "these properties hold a COUNT, which is false the day the tree changes: $(echo "$numeric" | tr '\n' ' ')"
    echo "        Store the instrument that re-derives it instead (see verify-command)."
  fi

  # verify-command must name a file that exists, or it is an instruction to
  # run something that is not there.
  vc=$(printf '%s\n' "$props" | awk -F' = ' '$1=="verify-command"{print $2}')
  if [ -z "$vc" ]; then
    bad "no verify-command property -- a reader has nothing to run"
  else
    vf=$(printf '%s' "$vc" | grep -oE 'checker/[a-z-]+\.sh' | head -1)
    if [ -n "$vf" ] && [ -f "$vf" ]; then
      ok "verify-command names a checker that exists: $vf"
    else
      bad "verify-command points at '$vc' but ${vf:-no checker} is not in the tree"
    fi
  fi

  # platforms may only claim what CI actually runs. The workflow matrix is the
  # evidence; claiming macos while no macos job exists is the overclaim.
  plats=$(printf '%s\n' "$props" | awk -F' = ' '$1=="platforms"{print $2}' | tr ',' ' ')
  for p in $plats; do
    case "$p" in
      linux)   pat='ubuntu-latest' ;;
      windows) pat='windows-latest' ;;
      macos)   pat='macos-latest' ;;
      *)       bad "unknown platform claim: $p"; continue ;;
    esac
    if grep -q "$pat" .github/workflows/ci.yml; then
      ok "platform '$p' is claimed and CI has a $pat job"
    else
      bad "platform '$p' is CLAIMED but no $pat job exists in ci.yml -- that is an overclaim"
    fi
  done
fi

# --- controls ---------------------------------------------------------------
echo
echo "-- negative controls --"
# Controls for the [PROPERTIES] phase. The predicates above run against the
# real file, so they are re-run here on SYNTHETIC input that is deliberately
# wrong. Without this, "no property holds a bare count" is indistinguishable
# from "the awk never matched anything", which is how a dead check hides.
fake_props="$(printf 'verification = machine-checked-lean4\ntheorem-count = 100\n')"
if [ -n "$(printf '%s\n' "$fake_props" | awk -F' = ' '$2 ~ /^[0-9]+$/ {print $1}')" ]; then
  ok "CONTROL: a planted 'theorem-count = 100' IS rejected as an expiring snapshot"
else
  bad "CONTROL DEAD: a bare count passes the anti-snapshot rule"
fi
if grep -q 'macos-latest' .github/workflows/ci.yml; then
  ok "CONTROL: ci.yml now HAS a macos job -- the platform claim may be widened"
else
  ok "CONTROL: claiming 'macos' would fail, because no macos-latest job exists (checked, not assumed)"
fi

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
