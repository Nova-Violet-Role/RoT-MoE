#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# BUILD THE THREE RELEASE VARIANTS -- AND REFUSE TO SHIP A DISHONEST ONE.
#
# The version number IS the variant. This is not a roadmap where 0.1.2 succeeds
# 0.1.1; all three are built from one tree, in one run, and shipped together:
#
#   0.1.0  core       the router. No Lean, no fetcher, NO NETWORK AT ALL.
#   0.1.1  lean       core + the Lean 4 toolchain fetcher + the proof corpus.
#   0.1.2  unsealed   lean + the axiom classifier + the policy that permits
#                     native_decide in YOUR proofs, with the instrument that
#                     keeps that honest.
#
# Each variant is a strict superset of the one before it. That is asserted, not
# assumed: `variant_is_superset` below fails if a file ever leaves a larger tier.
#
# WHY THIS IS A CHECKER AND NOT A BUILD SCRIPT. Each artifact carries promises in
# its own release page -- "no network, ever" for core; "the classifier is in
# here" for unsealed -- and a promise no machine checks survives exactly until
# someone adds a file. So every claim is asserted against the ZIP THAT WILL BE
# UPLOADED, and this exits non-zero rather than emit one that lies.
#
# THE MANIFEST INSIDE EACH ZIP IS REWRITTEN TO ITS VARIANT'S VERSION. A user who
# downloads 0.1.0 and finds a manifest saying 0.1.2 has been handed a file that
# contradicts its own name, and no gate in the tree would ever notice.
#
# Exit: 0 all three built and every assertion held · 1 an assertion FAILED
#       (nothing is uploaded) · 2 refuse (a tool is missing) · 3 SKIP.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }
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

# --- THE VARIANT MAP ----------------------------------------------------------
# One place, read by everything below. Adding a variant means adding a line here
# and a paths block; nothing else in this file hard-codes a variant name.
VARIANTS="core:0.1.0 lean:0.1.1 unsealed:0.1.2"

# The tree's own version must be one of the variants, and by convention the
# HIGHEST -- that is the version the newest tag will carry, and
# checker/release-consistency.sh binds the tree to the newest tag. If they drift,
# the tag says one thing and the manifest another.
TOPVER=""
for vp in $VARIANTS; do TOPVER="${vp#*:}"; done
if [ "$TREEVER" = "$TOPVER" ]; then
  ok "the tree declares $TREEVER, the highest variant -- it matches the newest tag it will carry"
else
  bad "the tree declares $TREEVER but the highest variant is $TOPVER -- the tag and the manifest will disagree"
fi

OUT="${ROTMOE_RELEASE_DIR:-$REPO/.release}"
rm -rf "$OUT"; mkdir -p "$OUT"

echo "== release package :: 3 variants from tree $TREEVER =="
note "output directory: $OUT"

# --- what belongs in each variant ---------------------------------------------
# CORE is what a user installs to get the router. Deliberately a SUBSET: someone
# downloading "core" and finding a proof corpus and a multi-gigabyte fetcher
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
NOTICE.md
LICENSE
LICENSE-EUPL-1.2
LICENSES
SECURITY.md
CONTRIBUTING.md
CODE_OF_CONDUCT.md
CITATION.cff
CLAUDE.md
"
# LEAN adds what makes re-verification -- and your own proving -- possible.
LEAN_EXTRA="
SETUP_LEAN.sh
SETUP_LEAN.ps1
lean
checker
"
# UNSEALED adds the document that names the trade. The classifier itself lives
# in checker/ and therefore already ships with LEAN; what 0.1.2 adds is the
# POLICY and the page that states it, which is why UNSEALED.md is the marker
# file every assertion below keys on.
UNSEALED_EXTRA="
UNSEALED.md
"

paths_for () {
  case "$1" in
    core)     printf '%s' "$CORE_PATHS" ;;
    lean)     printf '%s %s' "$CORE_PATHS" "$LEAN_EXTRA" ;;
    unsealed) printf '%s %s %s' "$CORE_PATHS" "$LEAN_EXTRA" "$UNSEALED_EXTRA" ;;
  esac
}

missing=0
for p in $CORE_PATHS $LEAN_EXTRA $UNSEALED_EXTRA; do
  [ -e "$p" ] || { bad "declared for packaging but not on disk: $p"; missing=$((missing+1)); }
done
[ "$missing" -eq 0 ] && ok "every declared path exists on disk"

# --- build --------------------------------------------------------------------
# MATERIALISE listings; never pipe into `grep -q`. pipefail is on and grep -q
# exits at the first match, SIGPIPEing unzip and making the PIPELINE status
# non-zero even when the match SUCCEEDED. Measured here: an artifact was reported
# as missing a file it demonstrably contained.
list_to () { unzip -Z1 "$1" > "$2" 2>/dev/null; }
has ()     { grep -q "$2" "$1"; }

STAGE="$OUT/.stage"
for vp in $VARIANTS; do
  v="${vp%%:*}"; ver="${vp#*:}"
  z="$OUT/rot-moe-$ver-$v.zip"

  # Stage, then rewrite the manifest to THIS variant's version. Editing the
  # tree's own plugin.json would be a destructive side effect of a checker.
  rm -rf "$STAGE"; mkdir -p "$STAGE"
  # EXCLUDE build output DURING the copy, never after it. Copying lean/ wholesale
  # drags in .lake -- measured at 7.2 GB on the machine this was written on --
  # only to delete it a moment later. That is slow, it needs the disk headroom
  # twice, and it leaves a window in which the tree looks half-built to anything
  # else watching: a concurrent leanchecker sweep fired a spurious "kernel
  # rejected" alarm during exactly that window. Never materialise a state you
  # intend to destroy.
  for p in $(paths_for "$v"); do
    [ -e "$p" ] || continue
    d="$STAGE/$(dirname "$p")"; mkdir -p "$d"
    if [ -d "$p" ]; then
      # tar is the portable way to copy a tree WITH exclusions applied as it
      # goes; cp has no --exclude on every platform this must run on.
      tar -cf - --exclude='.lake' --exclude='*.olean' --exclude='.git' \
                --exclude='*.mutbak' "$p" 2>/dev/null | ( cd "$STAGE" && tar -xf - ) 2>/dev/null
    else
      cp "$p" "$d/" 2>/dev/null
    fi
  done

  sed "s/\"version\"[[:space:]]*:[[:space:]]*\"$TREEVER\"/\"version\": \"$ver\"/" \
      "$MANIFEST" > "$STAGE/.claude-plugin/plugin.json.new" \
    && mv "$STAGE/.claude-plugin/plugin.json.new" "$STAGE/.claude-plugin/plugin.json"

  ( cd "$STAGE" && zip -q -r "$z" . ) >/dev/null 2>&1
  zrc=$?
  if [ "$zrc" -eq 0 ] && [ -s "$z" ]; then
    note "$(basename "$z"): $(wc -c < "$z" | tr -d ' ') bytes"
    list_to "$z" "$OUT/.list-$v"
  else
    bad "$v zip did not build (zip exit $zrc)"
  fi
done
rm -rf "$STAGE"

L_CORE="$OUT/.list-core"; L_LEAN="$OUT/.list-lean"; L_UNS="$OUT/.list-unsealed"

# --- 1. CORE MUST NOT BE ABLE TO REACH THE NETWORK ---------------------------
# The assertion that earns the promise on the release page. Stated as a property
# of the ZIP, not of the tree, because the zip is what a stranger runs.
if [ -s "$L_CORE" ]; then
  leak=0
  for forbidden in SETUP_LEAN.sh SETUP_LEAN.ps1 UNSEALED.md; do
    has "$L_CORE" "^$forbidden$" && { bad "CORE contains $forbidden -- its 'no network' / 'no extras' promise is FALSE"; leak=$((leak+1)); }
  done
  has "$L_CORE" '^lean/' && { bad "CORE contains the lean/ corpus -- it is not the core artifact"; leak=$((leak+1)); }
  [ "$leak" -eq 0 ] && ok "CORE (0.1.0) carries no fetcher, no corpus, no unsealed page -- it cannot download anything"
fi

# --- 2. LEAN MUST CARRY WHAT ITS NAME SELLS, AND NOT THE TIER ABOVE ----------
if [ -s "$L_LEAN" ]; then
  short=0
  for needed in SETUP_LEAN.sh SETUP_LEAN.ps1 lean/lakefile.toml lean/lean-toolchain checker/axiom-class.sh; do
    has "$L_LEAN" "^$needed$" || { bad "LEAN is missing $needed"; short=$((short+1)); }
  done
  nmod=$(grep -c '^lean/Proofs/.*\.lean$' "$L_LEAN" || true)
  ondisk=$(find lean/Proofs -name '*.lean' | grep -c . || true)
  [ "$nmod" -ne "$ondisk" ] && { bad "LEAN carries $nmod proof module(s) but $ondisk are on disk"; short=$((short+1)); }
  # It must NOT carry the tier above it, or the tiers are not distinct.
  has "$L_LEAN" '^UNSEALED.md$' && { bad "LEAN contains UNSEALED.md -- 0.1.1 and 0.1.2 would be the same artifact"; short=$((short+1)); }
  [ "$short" -eq 0 ] && ok "LEAN (0.1.1) carries both fetchers, the pinned toolchain, all $nmod proof module(s), and NOT the unsealed page"
fi

# --- 3. UNSEALED MUST ACTUALLY DIFFER FROM LEAN ------------------------------
# A tier whose extra content cannot be pointed at is marketing.
if [ -s "$L_UNS" ]; then
  u=0
  for needed in UNSEALED.md checker/axiom-class.sh SETUP_LEAN.sh lean/lean-toolchain; do
    has "$L_UNS" "^$needed$" || { bad "UNSEALED is missing $needed"; u=$((u+1)); }
  done
  [ "$u" -eq 0 ] && ok "UNSEALED (0.1.2) carries the unsealed page AND the axiom classifier"
fi

# --- 4. EACH TIER IS A STRICT SUPERSET OF THE ONE BELOW ----------------------
# The property that makes the numbering mean something. Checked by set
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

# --- 6. THE VERSION INSIDE IS THE VERSION ON THE BOX -------------------------
for vp in $VARIANTS; do
  v="${vp%%:*}"; ver="${vp#*:}"; z="$OUT/rot-moe-$ver-$v.zip"
  [ -s "$z" ] || continue
  inner=$(unzip -p "$z" ".claude-plugin/plugin.json" 2>/dev/null \
          | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  if [ "$inner" = "$ver" ]; then
    ok "$(basename "$z") declares version $inner inside, matching its name"
  else
    bad "$(basename "$z") is named for $ver but its manifest says '$inner'"
  fi
done

# --- 7. RELEASE.md MUST DESCRIBE THE ARTIFACTS ACTUALLY BUILT ----------------
# Deliberately NOT asserted: byte sizes and gate counts. Both are true today and
# false after the next commit; the page states size as a BOUND, and that bound is
# asserted, because a bound survives a change that a snapshot does not.
RMD="RELEASE.md"
if [ ! -f "$RMD" ]; then
  bad "$RMD is missing -- the release has no page to point a downloader at"
else
  rmd=0
  for vp in $VARIANTS; do
    v="${vp%%:*}"; ver="${vp#*:}"; n="rot-moe-$ver-$v.zip"
    grep -qF -- "$n" "$RMD" || { rmd=1; note "$RMD does not name the asset $n"; }
    grep -qF -- "$ver" "$RMD" || { rmd=1; note "$RMD does not mention version $ver"; }
  done
  grep -qiF -- "no network" "$RMD" || { rmd=1; note "$RMD does not carry the no-network claim assertion 1 enforces"; }
  if [ "$rmd" -eq 0 ]; then ok "$RMD names all 3 assets and all 3 variant versions"
  else bad "$RMD has drifted from the artifacts -- move them in the same edit"; fi

  # --- 7b. EVERY ARCHIVE CARRIES ITS OWN CHANGELOG ---------------------------
  # Measured after the CHANGELOG was written: it shipped in NONE of the three
  # archives, because CORE_PATHS never listed it. The core zip came back
  # byte-identical to the pre-CHANGELOG build, which is the tell -- a new
  # top-level document that changes no artifact was never packaged.
  #
  # The assertion is not "the file exists". It is that the SHIPPED copy names
  # ALL THREE versions, so an archive can never carry a changelog that predates
  # a variant it was built alongside.
  cl=0
  for vp in $VARIANTS; do
    v="${vp%%:*}"; ver="${vp#*:}"; z="$OUT/rot-moe-$ver-$v.zip"
    [ -s "$z" ] || continue
    unzip -p "$z" CHANGELOG.md > "$OUT/.cl.$v" 2>/dev/null
    if [ ! -s "$OUT/.cl.$v" ]; then
      cl=1; note "rot-moe-$ver-$v.zip ships NO CHANGELOG.md"
    else
      for vp2 in $VARIANTS; do
        grep -qF -- "${vp2#*:}" "$OUT/.cl.$v" \
          || { cl=1; note "the CHANGELOG inside $v does not mention ${vp2#*:}"; }
      done
    fi
    rm -f "$OUT/.cl.$v"
  done
  [ "$cl" -eq 0 ] && ok "every archive ships a CHANGELOG naming all 3 variant versions" \
                  || bad "a shipped CHANGELOG is missing or stale"

  cz="$OUT/rot-moe-0.1.0-core.zip"
  if [ -s "$cz" ]; then
    cb=$(wc -c < "$cz" | tr -d ' ')
    if [ "$cb" -lt 1048576 ]; then ok "CORE is $cb bytes -- under the 1 MB the page claims"
    else bad "CORE is $cb bytes, over 1 MB -- the page's bound is now FALSE"; fi
  fi
fi

# --- negative controls --------------------------------------------------------
echo
echo "-- negative controls --"

CZ="$OUT/rot-moe-0.1.0-core.zip"
if [ -s "$CZ" ]; then
  probe="$OUT/probe-core.zip"; cp "$CZ" "$probe"
  ( cd "$REPO" && zip -q "$probe" SETUP_LEAN.sh ) >/dev/null 2>&1
  prc=$?; plist="$OUT/.list-probe"; list_to "$probe" "$plist"
  if [ "$prc" -ne 0 ]; then bad "CONTROL DID NOT APPLY: could not plant SETUP_LEAN.sh (zip exit $prc) -- discarded, NOT survived"
  elif ! has "$plist" '^SETUP_LEAN.sh$'; then bad "CONTROL DID NOT APPLY: planted file absent from probe -- discarded, NOT survived"
  else ok "CONTROL: a core zip with SETUP_LEAN.sh planted IS detectable -- assertion 1 can fire"; fi
  rm -f "$probe" "$plist"

  if has "$L_CORE" '^SETUP_LEAN.sh$'; then bad "CONTROL: the real core zip trips the predicate -- it is always-fail"
  else ok "CONTROL: the real core zip does NOT trip it -- the check discriminates"; fi
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

if [ "$TREEVER" = "0.0.0-not-a-real-version" ]; then
  bad "CONTROL DEAD: the sentinel compares equal to the real version"
else
  ok "CONTROL: a wrong version string IS distinguishable from $TREEVER"
fi

printf '\n== release package: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
  echo "   NOTHING IS UPLOADED. Fix the artifact, not the assertion."
  exit 1
fi
echo "   artifacts ready:"
for vp in $VARIANTS; do
  v="${vp%%:*}"; ver="${vp#*:}"
  echo "     $OUT/rot-moe-$ver-$v.zip"
done
exit 0
