#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# BUILD THE THREE RELEASE VARIANTS -- AND REFUSE TO SHIP A DISHONEST ONE.
#
# THE TIER LIVES IN THE NAME NOW, NOT IN THE VERSION. Through 5.x the patch
# digit WAS the tier -- X.Y.0 core, X.Y.1 lean, X.Y.2 unsealed -- three version
# numbers for one tree, and every consumer had to be taught that 0.5.2 does not
# succeed 0.5.1. That convention is RETIRED AT 6.0.0. One tree, ONE version --
# the one plugin.json declares -- and three archives whose NAMES say what they
# carry:
#
#   RoT-MoE-Router.zip             the router AND the organs that are now the
#                                  product: the voice contract, the nine
#                                  charters, both voice-gate arms, the
#                                  environment layer, the commands. No Lean,
#                                  no fetcher, NO NETWORK AT ALL.
#   RoT-MoE-Router-Lean.zip        Router + the Lean 4 toolchain fetcher + the
#                                  proof corpus.
#   RoT-MoE-Router-Lean-Extra.zip  Router-Lean + the policy page that permits
#                                  native_decide in YOUR proofs, with the
#                                  instrument that keeps that honest.
#
# THE CRITERIA CHANGED AT 6.0.0 AND THE ASSERTIONS FOLLOWED. The voices, their
# contract, the gate and the environment layer are not extras a larger tier
# earns -- they ARE the product -- so they ride in the SMALLEST archive and are
# asserted there (assertion 1b), with the roster COUNTED against the DTD's own
# declaration, never against a number somebody remembered.
#
# Each variant is a strict superset of the one before it. That is asserted, not
# assumed: the superset check below fails if a file ever leaves a larger tier.
#
# WHY THIS IS A CHECKER AND NOT A BUILD SCRIPT. Each artifact carries promises
# in its own release page -- "no network, ever" for Router; "the instrument is
# in here" for Router-Lean-Extra -- and a promise no machine checks survives
# exactly until someone adds a file. So every claim is asserted against the ZIP
# THAT WILL BE UPLOADED, and this exits non-zero rather than emit one that lies.
#
# Exit: 0 all three built and every assertion held · 1 an assertion FAILED
#       (nothing is uploaded) · 2 refuse (a tool is missing) · 3 SKIP.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=release-package::%s\n' "$*"; FAIL=$((FAIL+1)); }
note() { printf '  ----  %s\n' "$*"; }

command -v zip   >/dev/null 2>&1 || { echo "REFUSE: zip absent";   exit 2; }
command -v unzip >/dev/null 2>&1 || { echo "REFUSE: unzip absent"; exit 2; }

MANIFEST=".claude-plugin/plugin.json"
[ -f "$MANIFEST" ] || { echo "REFUSE: $MANIFEST missing"; exit 2; }
TREEVER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -1)
case "$TREEVER" in
  [0-9]*.[0-9]*.[0-9]*) : ;;
  *) echo "REFUSE: could not read a semver version from $MANIFEST (got '$TREEVER')"; exit 2 ;;
esac

# THE PATCH DIGIT IS THE TIER AGAIN -- restored at 9.0.x, and stamped, not hoped.
#
# Through 5.x the patch digit WAS the tier; 6.0.0 retired it and deleted the
# per-variant rewrite with a warning worth keeping: "a sed that should change
# nothing is a defect waiting for the day it does." That warning is honoured
# here rather than ignored -- the stamp is applied, and then READ BACK OUT OF
# THE ZIP and compared against THIS TIER's expected digit (assertion 6). A sed
# that writes the wrong version is therefore caught by the assertion, which is
# the protection the old comment was asking for.
#
# The tree's manifest declares the DEFAULT INSTALL tier -- lean -- because the
# verification surface is the point of this project. BASEVER is its major.minor.
BASEVER=${TREEVER%.*}
tier_version () {                      # core=.0  lean=.1  unsealed=.2
  case "$1" in
    core)     echo "$BASEVER.0" ;;
    lean)     echo "$BASEVER.1" ;;
    unsealed) echo "$BASEVER.2" ;;
    *) echo "REFUSE: no tier digit declared for variant '$1'" >&2; return 2 ;;
  esac
}
# The tree's own version MUST be one the map can produce, or the manifest and
# the packager have silently diverged.
_tv_ok=0
for _t in core lean unsealed; do [ "$(tier_version "$_t")" = "$TREEVER" ] && _tv_ok=1; done
[ "$_tv_ok" -eq 1 ] || { echo "REFUSE: $MANIFEST declares $TREEVER, which no tier digit produces"; exit 2; }
case x in x)
esac

# --- THE VARIANT MAP ----------------------------------------------------------
# One place, read by everything below. Adding a variant means adding an entry
# here and a paths block; nothing else in this file hard-codes an archive name.
#
# THE NAMES ARE DELIBERATELY CONSTANT. The old map embedded a version in every
# name -- first a hand-typed `core:0.6.0 ...` that went red the day plugin.json
# moved, then a computed `core:$_MM.0 ...` that made every release bump ripple
# through nine filenames and every consumer that spelled one. A constant name
# cannot go stale that way: nothing in `RoT-MoE-Router.zip` moves when the tree
# does. The VERSION is still read from the manifest above, still refused unless
# it is semver, and it now lives in exactly three places -- plugin.json, the
# stamped header of SHA256SUMS.txt, and the git tag -- instead of the filenames.
VARIANTS="core:RoT-MoE-Router.zip lean:RoT-MoE-Router-Lean.zip unsealed:RoT-MoE-Router-Lean-Extra.zip"

# `--print-variants` IS THE MAP'S ONLY PUBLIC FORM. checker/release-install.sh,
# checker/readme-variants.sh and the session gates consume it; they used to
# read it by grepping this file for `^VARIANTS="..."`, which broke silently the
# moment the line stopped being a literal. Parsing another script's source is
# the fragile half of "single source of truth". ASKING it is the robust half:
# the value is produced by the same code that uses it, so the two cannot
# disagree even in principle.
#
# FORMAT, one line per variant: `<archive-basename>:<version>`, e.g.
#   RoT-MoE-Router.zip:6.0.0
# The version is the SAME on every line by construction -- one tree, one
# version. A consumer that needs the tier reads it out of the name.
if [ "${1:-}" = "--print-variants" ]; then
  for vp in $VARIANTS; do printf '%s:%s\n' "${vp#*:}" "$TREEVER"; done
  exit 0
fi

OUT="${ROTMOE_RELEASE_DIR:-$REPO/.release}"
rm -rf "$OUT"; mkdir -p "$OUT"

echo "== release package :: 3 variants, one version $TREEVER =="
note "output directory: $OUT"

# --- what belongs in each variant ---------------------------------------------
# CORE is what a user installs to get the router. Deliberately a SUBSET: someone
# downloading "Router" and finding a proof corpus and a multi-gigabyte fetcher
# would be right to feel misled.
CORE_PATHS="
.claude-plugin
hooks
agents
engine
ARM_ROUTER.sh
ARM_ROUTER.ps1
DISARM_ROUTER.sh
DISARM_ROUTER.ps1
README.md
RELEASE.md
CHANGELOG.md
CHANGELOG-ARCHIVE.md
docs
NOTICE.md
LICENSE
LICENSE-EUPL-1.2
LICENSES
SECURITY.md
CONTRIBUTING.md
CODE_OF_CONDUCT.md
CITATION.cff
CLAUDE.md
commands
"
# LEAN adds what makes re-verification -- and your own proving -- possible.
#
# `Lean Theorem` is the SHARED CORPUS -- contributed proofs about other people's
# code. It rides with LEAN and never with CORE, by the same rule that keeps
# `lean/` out of CORE: someone downloading "Router" to get a router has not
# asked for a proof corpus. Measured cost: 112 KB across 8 modules, which is
# why it is affordable to ship at all.
#
# THE SPACE IN THE NAME IS LOAD-BEARING AND DANGEROUS. This list is consumed by
# `for p in $(paths_for ...)`, and unquoted command substitution splits on IFS --
# so "Lean Theorem" would arrive as two paths, `Lean` and `Theorem`, neither of
# which exists. That is not hypothetical: on 2026-08-14 an unquoted
# `$(find "Lean Theorem" ...)` split exactly this way, every write in the loop
# failed, and the counter still printed "200 added" because it counted attempts.
# The loops below therefore set IFS to newline. Add nothing to these lists that
# contains a newline.
LEAN_EXTRA="
SETUP_LEAN.sh
SETUP_LEAN.ps1
SETUP_CORPUS.sh
SETUP_CORPUS.ps1
lean
Lean Theorem
checker
"
# UNSEALED adds the document that names the trade. The classifier itself lives
# in checker/ and therefore already ships with LEAN; what Router-Lean-Extra
# adds is the POLICY and the page that states it, which is why UNSEALED.md is
# the marker file every assertion below keys on.
UNSEALED_EXTRA="
UNSEALED.md
"

# Joined with NEWLINE, never with a space -- a space here would re-introduce the
# very splitting the newline IFS exists to prevent, and it would do so silently.
paths_for () {
  case "$1" in
    core)     printf '%s' "$CORE_PATHS" ;;
    lean)     printf '%s\n%s' "$CORE_PATHS" "$LEAN_EXTRA" ;;
    unsealed) printf '%s\n%s\n%s' "$CORE_PATHS" "$LEAN_EXTRA" "$UNSEALED_EXTRA" ;;
  esac
}

missing=0
_OLDIFS=$IFS; IFS='
'
for p in $CORE_PATHS $LEAN_EXTRA $UNSEALED_EXTRA; do
  [ -n "$p" ] || continue
  [ -e "$p" ] || { bad "declared for packaging but not on disk: $p"; missing=$((missing+1)); }
done
IFS=$_OLDIFS
[ "$missing" -eq 0 ] && ok "every declared path exists on disk"

# A path containing a space must survive the split. This asserts the MECHANISM,
# not today's file list: if someone reverts the IFS handling, `Lean Theorem`
# arrives as `Lean` and this fails loudly instead of shipping a corpus-less zip.
_split_probe=0
_OLDIFS=$IFS; IFS='
'
for p in $(paths_for lean); do
  [ -n "$p" ] || continue
  case "$p" in ("Lean Theorem") _split_probe=1 ;; esac
done
IFS=$_OLDIFS
if [ "$_split_probe" -eq 1 ]; then
  ok "a path with a space survives word-splitting intact (Lean Theorem)"
else
  bad "WORD-SPLIT REGRESSION: 'Lean Theorem' did not survive paths_for -- the corpus would ship EMPTY"
fi

# --- build --------------------------------------------------------------------
# MATERIALISE listings; never pipe into `grep -q`. pipefail is on and grep -q
# exits at the first match, SIGPIPEing unzip and making the PIPELINE status
# non-zero even when the match SUCCEEDED. Measured here: an artifact was reported
# as missing a file it demonstrably contained.
list_to () { unzip -Z1 "$1" > "$2" 2>/dev/null; }
has ()     { grep -q "$2" "$1"; }

STAGE="$OUT/.stage"
for vp in $VARIANTS; do
  v="${vp%%:*}"; zn="${vp#*:}"
  z="$OUT/$zn"

  # Stage into a scratch tree; never zip the repository in place.
  rm -rf "$STAGE"; mkdir -p "$STAGE"
  # EXCLUDE build output DURING the copy, never after it. Copying lean/ wholesale
  # drags in .lake -- measured at 7.2 GB on the machine this was written on --
  # only to delete it a moment later. That is slow, it needs the disk headroom
  # twice, and it leaves a window in which the tree looks half-built to anything
  # else watching: a concurrent leanchecker sweep fired a spurious "kernel
  # rejected" alarm during exactly that window. Never materialise a state you
  # intend to destroy.
  # IFS is newline for the WHOLE loop: every expansion in the body is quoted, so
  # nothing here needs the default. Restoring it per-iteration was the first
  # draft and it was three chances to get it wrong for no benefit.
  _OLDIFS=$IFS; IFS='
'
  for p in $(paths_for "$v"); do
    [ -n "$p" ] || continue
    [ -e "$p" ] || continue
    d="$STAGE/$(dirname "$p")"; mkdir -p "$d"
    if [ -d "$p" ]; then
      # tar is the portable way to copy a tree WITH exclusions applied as it
      # goes; cp has no --exclude on every platform this must run on.
      # .cocoindex_code is the ccc semantic index: machine-local, binary, and
      # full of absolute paths. ASSERTION 7 would refuse the zip for carrying an
      # untracked entry, but the deeper reason is the leak class no-local-paths.sh
      # is blind to -- grep -rI skips binaries, which is how bonus/cmdpulse
      # shipped an absolute path under a green gate.
      tar -cf - --exclude='.lake' --exclude='*.olean' --exclude='.git' \
                --exclude='*.mutbak' --exclude='*.bak' --exclude='.rot-moe' \
                --exclude='.cocoindex_code' "$p" 2>/dev/null | ( cd "$STAGE" && tar -xf - ) 2>/dev/null
    else
      cp "$p" "$d/" 2>/dev/null
    fi
  done
  IFS=$_OLDIFS

  # STAMP THE STAGED MANIFEST WITH THIS TIER'S VERSION. Not a no-op sed: for two
  # of the three variants it genuinely changes the digit, and assertion 6 reads
  # it back out of the finished zip to prove which one landed.
  _tver=$(tier_version "$v") || exit 2
  _sm="$STAGE/.claude-plugin/plugin.json"
  if [ -f "$_sm" ]; then
    sed 's/"version"[[:space:]]*:[[:space:]]*"[^"]*"/"version": "'"$_tver"'"/' "$_sm" > "$_sm.n" && mv "$_sm.n" "$_sm" || { echo "REFUSE: could not stamp $v manifest with $_tver"; exit 2; }
    _got=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$_sm" | head -1)
    [ "$_got" = "$_tver" ] || { echo "REFUSE: stamp did not land for $v (wanted $_tver, got '$_got')"; exit 2; }
  else
    echo "REFUSE: no staged manifest to stamp for $v"; exit 2
  fi

  # HISTORY. Through 5.x this loop sed-ed each
  # staged plugin.json to its variant's version, because the patch digit WAS
  # the tier and an archive named 0.5.0 carrying a manifest saying 0.5.2 would
  # contradict its own name. That convention is retired at 6.0.0: all three
  # archives ship the tree's own manifest, byte for byte, declaring the ONE
  # version $TREEVER. The rewrite is gone rather than kept as a no-op -- a sed
  # that "should" change nothing is a defect waiting for the day it does --
  # and assertion 6 below reads the version back OUT OF EACH ZIP rather than
  # trusting this comment.

  ( cd "$STAGE" && zip -q -r "$z" . ) >/dev/null 2>&1
  zrc=$?
  if [ "$zrc" -eq 0 ] && [ -s "$z" ]; then
    note "$zn: $(wc -c < "$z" | tr -d ' ') bytes"
    list_to "$z" "$OUT/.list-$v"
  else
    bad "$v zip did not build (zip exit $zrc)"
  fi
done
rm -rf "$STAGE"

L_CORE="$OUT/.list-core"; L_LEAN="$OUT/.list-lean"; L_UNS="$OUT/.list-unsealed"

# --- 1. ROUTER MUST NOT BE ABLE TO REACH THE NETWORK -------------------------
# The assertion that earns the promise on the release page. Stated as a property
# of the ZIP, not of the tree, because the zip is what a stranger runs.
if [ -s "$L_CORE" ]; then
  leak=0
  for forbidden in SETUP_LEAN.sh SETUP_LEAN.ps1 UNSEALED.md; do
    has "$L_CORE" "^$forbidden$" && { bad "Router contains $forbidden -- its 'no network' / 'no extras' promise is FALSE"; leak=$((leak+1)); }
  done
  has "$L_CORE" '^lean/' && { bad "Router contains the lean/ corpus -- it is not the core artifact"; leak=$((leak+1)); }
  has "$L_CORE" '^Lean Theorem/' && { bad "Router contains the shared Lean Theorem corpus -- it is not the core artifact"; leak=$((leak+1)); }
  [ "$leak" -eq 0 ] && ok "Router carries no fetcher, no corpus, no unsealed page -- it cannot download anything"
fi

# --- 1b. THE SMALLEST TIER MUST CARRY THE PRODUCT ----------------------------
# New at 6.0.0, and it is the reason the tiers were re-cut: the voice contract,
# the nine charters, both voice-gate arms, the environment layer and the
# commands are not extras -- they ARE the plugin. A Router archive without them
# would install a router that summons voices it does not ship. Presence is
# asserted per organ file, and the roster is COUNTED against the DTD's own
# declaration -- parsed with the same pattern checker/voice-contract.sh uses --
# because a "9" written here would be a snapshot, false the day a lens lands,
# while the DTD is the contract the voice gate already answers to.
# LOCALE, and it is load-bearing -- MEASURED 2026-08-21 on Win11 + GNU sed 4.9.
# Under a UTF-8 locale this sed SILENTLY DROPS every DTD row whose sigil is a
# 4-byte (astral) character: `.*` fails to match once mbrtowc rejects the
# sequence, so U+1F3B7 U+1F577 U+1FA78 U+1F52E U+1F70F U+1F9ED vanish and the
# nine-lens roster is counted as THREE. checker/voice-contract.sh has exported
# LC_ALL=C since its line 33 and therefore never saw this; this file had not,
# and read a whole product as incomplete. Byte-wise is the correct mode here:
# the pattern is pure ASCII and the payload is opaque.
NLENS=$(LC_ALL=C sed -n 's/.*<!ENTITY LENS\.[0-9][0-9]* *"\(.*\)">.*/\1/p' hooks/rot-voice.dtd 2>/dev/null | grep -c . || true)
# A PARTIAL parse used to be indistinguishable from a small roster: the guard
# below only refused NLENS=0. Bind the extractor to the raw declaration count
# instead, so "the reader lost rows" can never again be read as "the product
# lost lenses". This holds for any future roster size, not just nine.
NLENS_RAW=$(LC_ALL=C grep -c '<!ENTITY LENS\.' hooks/rot-voice.dtd || true)
if [ "$NLENS" -ne "$NLENS_RAW" ]; then
  bad "the DTD reader extracted $NLENS of $NLENS_RAW declared LENS rows -- the EXTRACTOR lost rows (locale?), the roster did not"
fi
if [ -s "$L_CORE" ]; then
  organ=0
  for needed in hooks/rot-voice.dtd \
                hooks/rot-voice-gate.sh hooks/rot-voice-gate.ps1 \
                hooks/rot-env.sh hooks/rot-env.ps1 hooks/rot-profile.sh \
                commands/rot-agent.md commands/rot-swarm.md; do
    has "$L_CORE" "^$needed$" || { bad "Router is missing $needed -- an organ of the product did not travel"; organ=$((organ+1)); }
  done
  nag=$(grep -c '^agents/rot-[^/]*\.md$' "$L_CORE" || true)
  if [ "$NLENS" -eq 0 ]; then
    bad "hooks/rot-voice.dtd declares NO lenses -- the roster count has no contract to stand on"
  elif [ "$nag" -ne "$NLENS" ]; then
    bad "Router carries $nag rot-* charter(s) but the DTD declares $NLENS -- the roster did not travel whole"
  elif [ "$organ" -eq 0 ]; then
    ok "Router carries the contract, both gate arms, the environment layer, both commands, and all $NLENS declared charters"
  fi
fi

# --- 2. LEAN MUST CARRY WHAT ITS NAME SELLS, AND NOT THE TIER ABOVE ----------
if [ -s "$L_LEAN" ]; then
  short=0
  for needed in SETUP_LEAN.sh SETUP_LEAN.ps1 lean/lakefile.toml lean/lean-toolchain checker/axiom-class.sh; do
    has "$L_LEAN" "^$needed$" || { bad "Router-Lean is missing $needed"; short=$((short+1)); }
  done
  nmod=$(grep -c '^lean/Proofs/.*\.lean$' "$L_LEAN" || true)
  ondisk=$(find lean/Proofs -name '*.lean' | grep -c . || true)
  [ "$nmod" -ne "$ondisk" ] && { bad "Router-Lean carries $nmod proof module(s) but $ondisk are on disk"; short=$((short+1)); }

  # THE SHARED CORPUS MUST TRAVEL. Counted, not merely present: a zip containing
  # `Lean Theorem/README.md` and nothing else would satisfy an existence check
  # and ship an empty promise. The count is compared to disk, so the assertion
  # follows the corpus as it grows instead of freezing today's number.
  ncorp=$(grep -c '^Lean Theorem/.*\.lean$' "$L_LEAN" || true)
  corpdisk=$(find "Lean Theorem" -name '*.lean' | grep -c . || true)
  if [ "$corpdisk" -gt 0 ]; then
    [ "$ncorp" -ne "$corpdisk" ] && { bad "Router-Lean carries $ncorp shared-corpus module(s) but $corpdisk are on disk -- the corpus did not travel"; short=$((short+1)); }
    has "$L_LEAN" '^Lean Theorem/README.md$' || { bad "Router-Lean carries the corpus without its README -- a stranger cannot tell what it is"; short=$((short+1)); }
  fi
  # It must NOT carry the tier above it, or the tiers are not distinct.
  has "$L_LEAN" '^UNSEALED.md$' && { bad "Router-Lean contains UNSEALED.md -- it and Router-Lean-Extra would be the same artifact"; short=$((short+1)); }
  [ "$short" -eq 0 ] && ok "Router-Lean carries both fetchers, the pinned toolchain, all $nmod proof module(s), all $ncorp shared-corpus module(s), and NOT the unsealed page"
fi

# --- 3. EXTRA MUST ACTUALLY DIFFER FROM LEAN ---------------------------------
# A tier whose extra content cannot be pointed at is marketing.
if [ -s "$L_UNS" ]; then
  u=0
  for needed in UNSEALED.md checker/axiom-class.sh SETUP_LEAN.sh lean/lean-toolchain; do
    has "$L_UNS" "^$needed$" || { bad "Router-Lean-Extra is missing $needed"; u=$((u+1)); }
  done
  [ "$u" -eq 0 ] && ok "Router-Lean-Extra carries the unsealed page AND the axiom classifier"
fi

# --- 4. EACH TIER IS A STRICT SUPERSET OF THE ONE BELOW ----------------------
# The property that makes the naming mean something. Checked by set
# difference, so a file silently DROPPED from a larger tier is caught -- the
# failure a size comparison would miss entirely.
superset () {  # $1 = smaller list, $2 = larger list, $3 = label
  lost=$(comm -23 <(sort "$1") <(sort "$2") | grep -c . || true)
  if [ "$lost" -eq 0 ]; then
    ok "$3: every entry of the smaller tier is present in the larger one"
  else
    bad "$3: $lost entr(ies) present in the smaller tier are MISSING from the larger:"
    comm -23 <(sort "$1") <(sort "$2") | sed 's/^/        /' | head -8
  fi
}
[ -s "$L_CORE" ] && [ -s "$L_LEAN" ] && superset "$L_CORE" "$L_LEAN" "core -> lean"
[ -s "$L_LEAN" ] && [ -s "$L_UNS" ]  && superset "$L_LEAN" "$L_UNS"  "lean -> unsealed"

# --- 5. NO BUILD OUTPUT, NO HISTORY, IN ANY VARIANT --------------------------
for vp in $VARIANTS; do
  v="${vp%%:*}"; l="$OUT/.list-$v"
  [ -s "$l" ] || continue
  junk=$(grep -cE '(^|/)\.lake/|\.olean$|(^|/)\.git/' "$l" || true)
  if [ "$junk" -gt 0 ]; then bad "$v carries $junk build-output or history entr(ies)"
  else ok "$v carries no .lake, no .olean, no .git"; fi
done

# --- 6. THE VERSION INSIDE IS THE TREE'S ONE VERSION -------------------------
# The name no longer carries a version, so the manifest can no longer contradict
# its own filename -- but it can still contradict the TREE. A stale staged copy,
# or a revival of the per-variant rewrite this file used to do, would ship an
# archive whose plugin.json names a version the tag never will. Read it back
# out of each zip; trust nothing about how it got there.
for vp in $VARIANTS; do
  zn="${vp#*:}"; z="$OUT/$zn"
  [ -s "$z" ] || continue
  inner=$(unzip -p "$z" ".claude-plugin/plugin.json" 2>/dev/null \
          | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  _want=$(tier_version "${vp%%:*}") || _want='<no tier>'
  if [ "$inner" = "$_want" ]; then
    ok "$zn declares version $inner inside -- this tier's own digit"
  else
    bad "$zn ships a manifest saying '$inner' but tier ${vp%%:*} must declare $_want"
  fi
done

# --- 7. RELEASE.md MUST DESCRIBE THE ARTIFACTS ACTUALLY BUILT ----------------
# Deliberately NOT asserted: byte sizes and gate counts. Both are true today and
# false after the next commit. (Through 5.x the core page stated a 1 MB bound
# and this file asserted it -- against a filename hardcoded to 0.5.0, so the
# check had been silently dead since the 0.6 bump. The 6.0.0 page states no
# bound; a bound returns here the day the page claims one, keyed to the map.)
RMD="RELEASE.md"
if [ ! -f "$RMD" ]; then
  bad "$RMD is missing -- the release has no page to point a downloader at"
else
  rmd=0
  for vp in $VARIANTS; do
    zn="${vp#*:}"
    grep -qF -- "$zn" "$RMD" || { rmd=1; note "$RMD does not name the asset $zn"; }
  done
  grep -qF -- "$TREEVER" "$RMD" || { rmd=1; note "$RMD does not mention version $TREEVER"; }
  # THE NO-NETWORK CLAIM MOVED AT 6.0.0. Through 5.x RELEASE.md itself said
  # "no network" and this grep held that page to assertion 1. The 6.0.0 release
  # page defers the claims to the README's claims table ("No network, ever."),
  # and the README ships inside every archive. The binding follows the claim:
  # it must be STATED on a page a downloader reads -- RELEASE.md or README.md --
  # and assertion 1 still enforces it against the zip either way.
  if ! grep -qiF -- "no network" "$RMD" && ! grep -qiF -- "no network" README.md; then
    rmd=1; note "neither $RMD nor README.md states the no-network claim assertion 1 enforces"
  fi
  if [ "$rmd" -eq 0 ]; then ok "$RMD names all 3 assets and the release version $TREEVER"
  else bad "$RMD has drifted from the artifacts -- move them in the same edit"; fi

  # --- 7b. EVERY ARCHIVE CARRIES ITS OWN CHANGELOG ---------------------------
  # Measured after the CHANGELOG was written: it shipped in NONE of the three
  # archives, because CORE_PATHS never listed it. The core zip came back
  # byte-identical to the pre-CHANGELOG build, which is the tell -- a new
  # top-level document that changes no artifact was never packaged.
  #
  # The assertion is not "the file exists". It is that the SHIPPED copy names
  # THE RELEASE VERSION, so an archive can never carry a changelog that
  # predates the release it was built for.
  cl=0
  for vp in $VARIANTS; do
    v="${vp%%:*}"; zn="${vp#*:}"; z="$OUT/$zn"
    [ -s "$z" ] || continue
    unzip -p "$z" CHANGELOG.md > "$OUT/.cl.$v" 2>/dev/null
    if [ ! -s "$OUT/.cl.$v" ]; then
      cl=1; note "$zn ships NO CHANGELOG.md"
    else
      grep -qF -- "$TREEVER" "$OUT/.cl.$v" \
        || { cl=1; note "the CHANGELOG inside $zn does not mention $TREEVER"; }
    fi
    rm -f "$OUT/.cl.$v"
  done
  [ "$cl" -eq 0 ] && ok "every archive ships a CHANGELOG naming the release version $TREEVER" \
                  || bad "a shipped CHANGELOG is missing or stale"
fi

# --- negative controls --------------------------------------------------------
echo
echo "-- negative controls --"

# CONSTANT NAMES REVIVED THESE CONTROLS. This block used to open with
# `CZ="$OUT/rot-moe-0.5.0-core.zip"` -- a name frozen at 0.5.0, so from the 0.6
# bump onward `-s` was false, the whole block silently skipped, and assertion
# 1's control had been dead for four minor versions without a line of output
# saying so. A version-less name cannot expire that way.
CZ="$OUT/RoT-MoE-Router.zip"
if [ -s "$CZ" ]; then
  probe="$OUT/probe-core.zip"; cp "$CZ" "$probe"
  ( cd "$REPO" && zip -q "$probe" SETUP_LEAN.sh ) >/dev/null 2>&1
  prc=$?; plist="$OUT/.list-probe"; list_to "$probe" "$plist"
  if [ "$prc" -ne 0 ]; then bad "CONTROL DID NOT APPLY: could not plant SETUP_LEAN.sh (zip exit $prc) -- discarded, NOT survived"
  elif ! has "$plist" '^SETUP_LEAN.sh$'; then bad "CONTROL DID NOT APPLY: planted file absent from probe -- discarded, NOT survived"
  else ok "CONTROL: a Router zip with SETUP_LEAN.sh planted IS detectable -- assertion 1 can fire"; fi
  rm -f "$probe" "$plist"

  if has "$L_CORE" '^SETUP_LEAN.sh$'; then bad "CONTROL: the real Router zip trips the predicate -- it is always-fail"
  else ok "CONTROL: the real Router zip does NOT trip it -- the check discriminates"; fi
fi

# The superset check must be able to FAIL, or assertion 4 is decoration.
if [ -s "$L_LEAN" ] && [ -s "$L_UNS" ]; then
  fake="$OUT/.list-truncated"
  grep -v '^checker/axiom-class.sh$' "$L_UNS" > "$fake"
  if cmp -s "$fake" "$L_UNS"; then
    bad "CONTROL DID NOT APPLY: removing a line changed nothing -- discarded, NOT survived"
  else
    lost=$(comm -23 <(sort "$L_LEAN") <(sort "$fake") | grep -c . || true)
    if [ "$lost" -gt 0 ]; then ok "CONTROL: a file dropped from the larger tier IS detected ($lost missing)"
    else bad "CONTROL: dropping a file from the larger tier went unnoticed -- assertion 4 is blind"; fi
  fi
  rm -f "$fake"
fi

# The roster count must be able to FAIL, or assertion 1b is decoration. Strip
# one charter from a COPY of the Router listing and require the same count to
# come up short. The copy is the instrument under test; the archive itself is
# never touched.
if [ -s "$L_CORE" ] && [ "$NLENS" -gt 0 ]; then
  fake="$OUT/.list-noroster"
  grep -v '^agents/rot-nova\.md$' "$L_CORE" > "$fake"
  if cmp -s "$fake" "$L_CORE"; then
    bad "CONTROL DID NOT APPLY: removing rot-nova changed nothing -- discarded, NOT survived"
  else
    nfake=$(grep -c '^agents/rot-[^/]*\.md$' "$fake" || true)
    if [ "$nfake" -ne "$NLENS" ]; then
      ok "CONTROL: a charter dropped from the archive IS detected ($nfake counted, $NLENS declared)"
    else
      bad "CONTROL: dropping rot-nova went unnoticed -- the roster count is blind"
    fi
  fi
  rm -f "$fake"
fi

if [ "$TREEVER" = "0.0.0-not-a-real-version" ]; then
  bad "CONTROL DEAD: the sentinel compares equal to the real version"
else
  ok "CONTROL: a wrong version string IS distinguishable from $TREEVER"
fi

# ASSERTION 7 -- nothing ships that git does not track.
# MEASURED 2026-08-21: the staging tar above copies from the WORKING TREE, not
# from a commit, so seven stray *.bak backups and a session route log carrying a
# live UUID were sitting inside the Lean archives while every assertion here
# reported green. Excluding *.bak and .rot-moe removes today's leak; THIS
# assertion is what makes the class impossible, because the next stray file
# will not be called .bak.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "REFUSE: not a git work tree -- cannot prove the archives ship only tracked files"; exit 2
fi
git ls-files | sort > "$OUT/.tracked"
for vp in $VARIANTS; do
  _zn=${vp#*:}
  unzip -Z1 "$OUT/$_zn" | grep -v "/$" | sort > "$OUT/.inzip"
  _stray=$(comm -23 "$OUT/.inzip" "$OUT/.tracked" | wc -l)
  if [ "$_stray" -eq 0 ]; then
    ok "$_zn ships only files git tracks"
  else
    bad "$_zn ships $_stray file(s) git does not track"
    comm -23 "$OUT/.inzip" "$OUT/.tracked" | sed "s|^|         |"
  fi
done
rm -f "$OUT/.tracked" "$OUT/.inzip"

printf '\n== release package: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
  echo "   NOTHING IS UPLOADED. Fix the artifact, not the assertion."
  exit 1
fi
# --- SHA256SUMS.txt ----------------------------------------------------------
# THE README PROMISED THIS FILE AND NOTHING PRODUCED IT. `README.md` says "Every
# archive verifies against the `SHA256SUMS.txt` published beside it", and a grep
# of this packager for `sha256` returned ZERO hits. A documented verification
# step with no artifact behind it is worse than none: a reader who tries it finds
# nothing and cannot tell an unpublished checksum from a tampered download.
#
# The fix is to emit the file, never to delete the sentence. The docs described
# the correct behaviour; the code was the part that was missing.
#
# Written LAST, after every assertion above has passed, so a checksum file can
# never exist for an artifact this script refused to bless. If FAIL is non-zero
# the script has already exited and no sums are written.
#
# THE HEADER LINE CARRIES THE VERSION. The filenames no longer do, so this file
# and the release tag are where a downloader reads which release the sums bless.
# `#` comment lines are ignored by both GNU sha256sum -c and perl shasum -c
# (verified before this line was written), so `-c` still passes untouched.
SUMS="$OUT/SHA256SUMS.txt"
rm -f "$SUMS"
_sha_tool=""
if command -v sha256sum >/dev/null 2>&1; then _sha_tool="sha256sum"
elif command -v shasum >/dev/null 2>&1; then _sha_tool="shasum -a 256"
fi
if [ -z "$_sha_tool" ]; then
  # REFUSE rather than ship archives with no checksums while the README says
  # they have some. Silence here would recreate the exact defect this block
  # exists to close.
  echo "   FAIL: no sha256sum or shasum on PATH -- cannot produce SHA256SUMS.txt"
  echo "   The README promises this file. Refusing to leave the promise unbacked."
  exit 1
fi
printf '# RoT MoE %s\n' "$TREEVER" > "$SUMS"
( cd "$OUT" && for vp in $VARIANTS; do
    $_sha_tool "${vp#*:}"
  done ) >> "$SUMS"

# The file must contain one line per variant and each hash must be 64 hex chars.
# A truncated or empty sums file would verify nothing while looking official.
_want=$(printf '%s\n' $VARIANTS | grep -c .)
# The `[*]?` is not cosmetic. GNU sha256sum writes `<hash> *<name>` in BINARY
# mode and `<hash>  <name>` in text mode; this run emitted the star form and the
# first version of this pattern rejected all three lines while the file was
# perfectly good. The check was wrong, not the output -- so the pattern moved,
# and the sums file was left exactly as the tool writes it, because `-c` has to
# read it back and the tool's own format is the one it understands.
_got=$(grep -cE '^[0-9a-f]{64}[[:space:]]+[*]?RoT-MoE-Router(-Lean(-Extra)?)?\.zip$' "$SUMS")
if [ "$_got" -ne "$_want" ]; then
  echo "   FAIL: SHA256SUMS.txt has $_got well-formed line(s), expected $_want"
  cat "$SUMS"
  exit 1
fi

# CONTROL: the sums must actually VERIFY, and a tampered byte must break them.
# Checking that a file exists is not checking that it is right.
if ( cd "$OUT" && $_sha_tool -c SHA256SUMS.txt >/dev/null 2>&1 ); then
  ok "SHA256SUMS.txt verifies against all $_got archive(s)"
else
  bad "SHA256SUMS.txt does NOT verify against the archives it names"
  exit 1
fi
# THE NAME IS STRIPPED OF ITS BINARY-MODE STAR ONCE, into one variable. Written
# inline as `awk '{print $2}'` it yields `*RoT-MoE-Router.zip`, and every
# `cp`/`mv` below would then address a file that does not exist -- the tamper
# control would appear to pass while touching nothing at all. That is the
# "mutation never landed" failure, in the one place whose whole job is to prove
# a mutation lands. The version header is skipped the same way: `head -1` would
# now hand awk the comment line and the control would hunt a file named "MoE".
_ctlname=$(grep -v '^#' "$SUMS" | head -1 | awk '{print $2}'); _ctlname="${_ctlname#\*}"
_ctlzip="$OUT/.sumctl.orig"
[ -f "$OUT/$_ctlname" ] || { echo "   FAIL: control target $_ctlname not found"; exit 1; }
cp "$OUT/$_ctlname" "$_ctlzip"
printf 'tamper' >> "$OUT/$_ctlname"
if ( cd "$OUT" && $_sha_tool -c SHA256SUMS.txt >/dev/null 2>&1 ); then
  bad "CONTROL: a tampered archive still passed its checksum -- the sums are decoration"
  mv "$_ctlzip" "$OUT/$_ctlname"
  exit 1
else
  ok "CONTROL: a tampered archive FAILS its checksum"
fi
mv "$_ctlzip" "$OUT/$_ctlname"
( cd "$OUT" && $_sha_tool -c SHA256SUMS.txt >/dev/null 2>&1 ) \
  || { echo "   FAIL: restore after the tamper control left a bad archive"; exit 1; }

echo "   artifacts ready:"
for vp in $VARIANTS; do
  echo "     $OUT/${vp#*:}"
done
echo "     $SUMS"
exit 0
