#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# R1 -- every source file carries the dual grant and the copyright line.
#
# RoT MoE is an ORIGINAL work, not a fork. That is the whole reason its
# licensing differs from the rolling-context repo, where the root LICENSE stays
# MIT (c) NodeNestor and the dual grant covers only `vibe/`. Here the root
# LICENSE is the verbatim AGPL-3.0 text, so GitHub's `licensee` -- which reads
# the ROOT LICENSE FILE ONLY, measured against the org's other repo via
# api.github.com/repos/.../license -- detects AGPL-3.0 rather than nothing.
# `LICENSE-EUPL-1.2` sits beside it and `LICENSES/` carries both texts for REUSE.
#
# Never paste mathlib's Apache-2.0 header into a file here. That mistake was
# made once already in the sibling repo (its NOTICE.md section B records the
# correction) and it misattributes the work.
#
# As with the R2 sweep: the instrument runs a POSITIVE CONTROL first. A checker
# that has gone blind reports every tree as clean, and a clean report from a
# blind checker is worse than no checker.

set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
SPDX='SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2'
COPY='Copyright 2026 Saimonokuma.'
TMP="${TMPDIR:-/tmp}/rotmoe-r1.$$"
rc=0

# Source files that must carry the header. Verbatim licence texts must NOT --
# editing them would break the licences themselves.
# THE TYPE LIST IS THE WHOLE GATE, AND IT WAS A SNAPSHOT -- O5, 8.0.1 audit.
#
# This list read: lean sh ps1 yml yaml toml. `.js` and `.dtd` were absent, so
# the sweep reported "checked 287 source file(s); 0 missing a header" while
# examining ZERO of the 24 JavaScript files -- including the SHIPPED
# hooks/settings-merge.js and hooks/plugin-detect.js -- and zero of the voice
# contract itself. Six bench/*.js were in fact unlicensed and this gate could
# not see them. Same defect as R3 and O1: an instrument whose scope is written
# down instead of derived, reporting green over territory it never covered.
#
# The types are added; the GUARD below is what stops it happening again.
list_sources () {
  find "$ROOT" -type f \
    \( -name '*.lean' -o -name '*.sh' -o -name '*.ps1' -o -name '*.yml' \
       -o -name '*.yaml' -o -name '*.toml' -o -name '*.js' -o -name '*.dtd' -o -name '*.lua' \) \
    -not -path '*/.git/*' -not -path '*/.lake/*' -not -path '*/LICENSES/*'
}

# --- NO EXTENSION MAY ESCAPE UNDECLARED --------------------------------------
# Every extension in the tree must be either COVERED (carries the header) or
# EXEMPT (declared here, with the reason). Anything else REFUSES and is named,
# so the next file type that lands forces a decision instead of slipping past.
# A list nobody can add to silently is the only kind that stays honest.
SPDX_COVERED='lean sh ps1 yml yaml toml js dtd lua'
# EXEMPT, and why: prose and data carry no code; archives and images are opaque;
# .bak is a working-copy artefact and is git-ignored.
SPDX_EXEMPT='md gif jsonl txt json zip bak tsv log done count cff 2'
_unknown=''
for _ext in $(find "$ROOT" -type f \
                -not -path '*/.git/*' -not -path '*/.lake/*' \
                -not -path '*/LICENSES/*' -not -path '*/.codemap/*' \
              | sed -n 's/.*\.\([A-Za-z0-9]\{1,6\}\)$/\1/p' | sort -u); do
  case " $SPDX_COVERED $SPDX_EXEMPT " in
    *" $_ext "*) : ;;
    *) _unknown="$_unknown $_ext" ;;
  esac
done
if [ -n "$_unknown" ]; then
  echo "FAIL: extension(s) in the tree are neither covered nor declared exempt:$_unknown"
  echo "      Add them to SPDX_COVERED (and give them headers) or to SPDX_EXEMPT"
  echo "      with a reason. An undeclared type is how .js escaped this gate."
  exit 1
fi

# --- POSITIVE CONTROL --------------------------------------------------------
mkdir -p "$TMP"
printf 'no header here\n' > "$TMP/bare.lean"
if grep -qF "$SPDX" "$TMP/bare.lean" 2>/dev/null; then
  echo "FAIL: control -- a bare file appears to carry the tag; the check is broken"
  rm -rf "$TMP"; exit 2
fi
printf '%s\n%s\n' "$SPDX" "$COPY" > "$TMP/good.lean"
if grep -qF "$SPDX" "$TMP/good.lean" && grep -qF "$COPY" "$TMP/good.lean"; then
  echo "control OK: tagged file detected, bare file rejected"
else
  echo "FAIL: control -- a correctly tagged file was NOT detected; THE SWEEP IS BLIND"
  rm -rf "$TMP"; exit 2
fi
rm -rf "$TMP"

# --- THE SWEEP ---------------------------------------------------------------
#
# NOT `for f in $(list_sources)`. That was the first version and it was wrong:
# unquoted command substitution word-splits on spaces, and a perfectly ordinary
# checkout path like `.../GIT External Repo/RoT MoE/` turns every filename into
# three or four fragments. The result was "68 source files, 68 missing a
# header" -- for a tree holding nineteen files, none of which were ever opened.
#
# It failed in the SAFE direction (over-reporting, obviously absurd) rather than
# the way the R2 grep failed (silently clean). Both are instrument defects; only
# one of them is survivable, and the difference is luck rather than design. Read
# the list from a file so no splitting can occur, and keep the counters out of a
# subshell so they survive.
LIST="${TMPDIR:-/tmp}/rotmoe-r1-list.$$"
list_sources > "$LIST"
n=0; bad=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$((n+1))
  miss=""
  grep -qF "$SPDX" "$f" || miss="SPDX"
  grep -qF "$COPY" "$f" || miss="$miss COPYRIGHT"
  if [ -n "$miss" ]; then
    echo "MISSING [$miss] $f"
    bad=$((bad+1)); rc=1
  fi
done < "$LIST"
rm -f "$LIST"

# The mathlib header must never appear -- it would misattribute the work.
#
# `--exclude` on this script is not a convenience: without it the check matched
# ITSELF, because the needle it searches for is necessarily written inside it.
# A detector that trips on its own definition reports FAIL on every tree
# forever, which is the mirror image of the R2 sweep that reported PASS on
# every tree forever. Both are checkers that have stopped measuring the subject
# and started measuring themselves.
if grep -rIl 'Released under Apache 2.0 license as described in the file LICENSE' \
     --exclude-dir=.git --exclude-dir=.lake --exclude-dir=LICENSES \
     --exclude="spdx-sweep.sh*" --exclude="*.bak" "$ROOT" 2>/dev/null | grep -q .; then
  echo "FAIL: a mathlib Apache-2.0 header is present -- wrong attribution"
  rc=1
fi

echo "checked $n source file(s); $bad missing a header"
[ "$rc" -eq 0 ] && echo "PASS: every source file carries the dual grant and the copyright line"
exit "$rc"
