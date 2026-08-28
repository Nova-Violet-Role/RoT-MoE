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
       -o -name '*.yaml' -o -name '*.toml' -o -name '*.js' -o -name '*.dtd' -o -name '*.lua' \
       -o -name '*.bashrc' \) \
    -not -path '*/.git/*' -not -path '*/.lake/*' -not -path '*/LICENSES/*' \
    -not -path '*/.cocoindex_code/*'
}

# --- NO EXTENSION MAY ESCAPE UNDECLARED --------------------------------------
# Every extension in the tree must be either COVERED (carries the header) or
# EXEMPT (declared here, with the reason). Anything else REFUSES and is named,
# so the next file type that lands forces a decision instead of slipping past.
# A list nobody can add to silently is the only kind that stays honest.
SPDX_COVERED='lean sh ps1 yml yaml toml js dtd lua bashrc nu'
# EXEMPT, and why: prose and data carry no code; archives and images are opaque;
# .bak is a working-copy artefact and is git-ignored.
#
# 2026-08-19 -- AND THEN THE LIST ITSELF BECAME THE DEFECT.
#
# A scheduling tool dropped .claude/scheduled_tasks.lock into the working copy
# and the WHOLE SUITE went red: "extension(s) ... neither covered nor declared
# exempt: lock". The file is git-ignored, ships in nothing, and is not this
# repository's work -- but the census walked it anyway, because the census
# scope is a hand-written list of directories and .claude/ was not on it.
#
# That is precisely what the header above condemns at "an instrument whose
# scope is written down instead of derived". Every tool that ever drops a
# file in this tree either turns the suite red or forces an edit HERE, and a
# gate that goes red for something the repository did not do is the gate
# someone disables. Excluding '*/.claude/*' would have been the wrong repair
# twice over: it is another hand-written entry, and .claude/ DOES carry
# tracked content (.claude/commands/rot-moe-install.md), so the exclusion
# would blind the census to real shipped files -- a hiding place.
#
# The criterion was already written down three paragraphs up, applied by hand
# to .cocoindex_code/: "it is git-ignored, release-package.sh excludes it by
# name, and nothing in it ships". Derive it instead. Git-ignored means it does
# not ship; not shipping means it is out of scope for a licence sweep.
#
# MEASURED 2026-08-19: 542 files in the census, 83 of them git-ignored.
# Dropping the ignored ones removes exactly four extensions -- bak, count,
# lock, log -- and THREE OF THOSE FOUR WERE ALREADY IN SPDX_EXEMPT. The
# exempt list had been absorbing transient tool droppings as though they were
# repository file types.
#
# So bak, count and log are removed from the list below, and that is not
# tidying -- it is the canary. Every one of them exists ONLY as a git-ignored
# file, so if the derived filter is ever deleted or broken, this gate goes red
# naming bak/count/log on the very next run. The fix tests itself.
SPDX_EXEMPT='md gif jsonl txt json zip tsv done cff 2'

# The census, as a function, so the CONTROL below exercises the code
# production actually runs rather than a copy of it.
census_unknown () {
  _c_all=$(find "$ROOT" -type f \
             -not -path '*/.git/*' -not -path '*/.lake/*' \
             -not -path '*/LICENSES/*' -not -path '*/.codemap/*' \
             -not -path '*/.cocoindex_code/*' \
           | sed "s#^$ROOT/##")
  # .lake/ and .cocoindex_code/ stay pruned above purely for speed -- both are
  # git-ignored and the filter below would drop them anyway. They are the last
  # two entries that may remain hand-written, because they prune the WALK.
  _c_ign=$(printf '%s\n' "$_c_all" | git -C "$ROOT" check-ignore --stdin || true)
  # An empty pattern file makes `grep -Fxv -f` match EVERY line and discard the
  # whole census, reporting a clean tree. Guard it explicitly.
  if [ -n "$_c_ign" ]; then
    _c_ignf=$(mktemp); printf '%s\n' "$_c_ign" > "$_c_ignf"
    _c_keep=$(printf '%s\n' "$_c_all" | grep -Fxv -f "$_c_ignf" || true)
    rm -f "$_c_ignf"
  else
    _c_keep="$_c_all"
  fi
  _c_unknown=''
  for _ext in $(printf '%s\n' "$_c_keep" | sed -n 's/.*\.\([A-Za-z0-9]\{1,6\}\)$/\1/p' | sort -u); do
    case " $SPDX_COVERED $SPDX_EXEMPT " in
      *" $_ext "*) : ;;
      *) _c_unknown="$_c_unknown $_ext" ;;
    esac
  done
  printf '%s' "$_c_unknown"
}

# CONTROL: the census must still SEE a new type that genuinely ships, and must
# NOT see one that cannot. Both probes carry an extension no real file uses.
# Without the first arm the derived filter could silently discard everything.
_ctl_live="$ROOT/.spdx-census-probe.zzq"
: > "$_ctl_live"
_ctl_saw_live=$(census_unknown)
rm -f "$_ctl_live"
_ctl_ign="$ROOT/.lake/.spdx-census-probe.zzr"
mkdir -p "$ROOT/.lake" 2>/dev/null || true
: > "$_ctl_ign"
_ctl_saw_ign=$(census_unknown)
rm -f "$_ctl_ign"
case " $_ctl_saw_live " in
  *" zzq "*) : ;;
  *) echo "FAIL: control -- the census did NOT see a planted shipping file type."
     echo "      Every 'no undeclared type' verdict from this gate is vacuous."
     exit 2 ;;
esac
case " $_ctl_saw_ign " in
  *" zzr "*) echo "FAIL: control -- a git-ignored file type was reported as undeclared."
     echo "      The derived exclusion is not applied; transient tool files can"
     echo "      turn this suite red for work the repository never did."
     exit 2 ;;
  *) : ;;
esac
echo "control OK: census sees a planted shipping type, ignores a git-ignored one"

_unknown=''
# `.cocoindex_code/` joins `.lake/` for the same reason: it is a local index a
# tool builds inside the working copy, it is git-ignored, `release-package.sh`
# excludes it by name, and nothing in it ships. Its `data.mdb`/`lock.mdb` and
# `.db` files were reported as three undeclared source types, which is the
# mathlib-`.py` shape of false positive -- a gate naming a DEPENDENCY's files as
# the repository's undeclared work. Exempting `db`/`mdb` instead would have been
# the wrong repair: it would declare types this repository does not ship.
_unknown=$(census_unknown)
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
