#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# release-body.sh -- proves the three release bodies ARE one body.
#
# THE CLAIM THIS ENFORCES IS THE DOCUMENT'S OWN. Every generated body closes
# with:
#
#     "Three tags are cut from one commit: v9.0.0 Router, v9.0.1 Lean,
#      v9.0.2 Lean+Extra. They differ by archive content, not by source tree --
#      THE TABLE ABOVE IS THE WHOLE DIFFERENCE."
#
# That sentence is a promise to whoever reads the release page, and nothing
# checked it. The gate-all row is titled "release notes -- one body, three
# tiers" and runs the generator three times into /dev/null:
#
#     bash checker/release-notes.sh core > /dev/null && ... lean ... && ... unsealed ...
#
# which asserts exit 0 and NOTHING ELSE. A generator that emitted three
# completely different pages, or leaked the Lean tier's archive name into the
# core body, would pass that row green. This repository has already shipped one
# defect of exactly that shape -- a wiring that printed FAIL and still exited 0.
#
# WHY NOT COUNT DIFF HUNKS. The obvious rule -- "exactly three differences" --
# is FABRICATED, and measuring it proved so before it was written. core vs lean
# reports 4 change hunks while core vs unsealed reports 3, from the same
# generator, with no defect present: `| UNSEALED.md | no |` happens to be
# identical in core and lean, so diff splits the table into two hunks, and
# differs in unsealed, so it merges into one. Hunk count is an artifact of which
# adjacent lines coincide. A gate built on it would fail the day a table value
# repeated.
#
# So the invariant is stated structurally instead: a body is a HEADER (title,
# subtitle, facts table) plus a SHARED REMAINDER, and the remainder must be
# byte-identical across all three tiers. Inside the table, only declared
# tier-specific keys may carry differing values.
#
#   bash checker/release-body.sh
#
set -u

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TIERS="core lean unsealed"

pass=0; fail=0
ok   () { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad  () { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; }

# The table rows whose VALUE is allowed to differ between tiers. Everything else
# in the table, and everything outside it, must match. Derived from what the
# tiers genuinely are: a different archive, holding a different number of files,
# a different amount of Lean, a policy page or not, and its own manifest version.
TIER_KEYS=" archive files Lean_4_sources UNSEALED.md manifest_version_inside "

# No backslash escapes anywhere in this file: this repository has twice corrupted
# a generated script because a backslash was eaten in transport. `substr($0,1,1)`
# does the work a /^\|/ regex would.
shared_of () {   # everything AFTER the last table row
  awk '{ l[NR]=$0; if (substr($0,1,1)=="|") last=NR }
       END { for (i=last+1; i<=NR; i++) print l[i] }' "$1"
}
table_of () {    # the table rows themselves
  awk 'substr($0,1,1)=="|" { print }' "$1"
}
key_of () {      # normalised key from a table row: "| archive | x |" -> archive
  printf '%s' "$1" | awk -F'|' '{ k=$2; gsub(/^ +| +$/, "", k); gsub(/ /, "_", k); print k }'
}
val_of () {
  printf '%s' "$1" | awk -F'|' '{ v=$3; gsub(/^ +| +$/, "", v); print v }'
}

WORK=$(mktemp -d) || exit 2
trap 'rm -rf "$WORK"' EXIT

printf '== release body :: three tiers, one body ==\n'

# --- R1: every tier generates a non-empty body --------------------------------
gen_ok=1
for t in $TIERS; do
  if bash "$REPO/checker/release-notes.sh" "$t" > "$WORK/$t.md" 2>"$WORK/$t.err"; then
    if [ -s "$WORK/$t.md" ]; then :; else
      bad "R1 tier '$t' generated an EMPTY body"; gen_ok=0
    fi
  else
    bad "R1 tier '$t' failed to generate (exit non-zero)"; gen_ok=0
    sed 's/^/      /' "$WORK/$t.err" | head -3
  fi
done
if [ "$gen_ok" -eq 1 ]; then
  ok "R1 all three tiers generate a non-empty body"
else
  printf '\n== release body: %d passed, %d failed\n' "$pass" "$fail"
  exit 1
fi

# --- R2: the shared remainder is byte-identical across all three --------------
# THE ASSERTION. This is "one body" stated so a machine can refuse it.
for t in $TIERS; do shared_of "$WORK/$t.md" > "$WORK/$t.shared"; done
if [ ! -s "$WORK/core.shared" ]; then
  bad "R2 the shared remainder is EMPTY -- the partition found no table, so this gate would compare nothing"
else
  r2=0
  for t in lean unsealed; do
    cmp -s "$WORK/core.shared" "$WORK/$t.shared" || {
      bad "R2 the body below the table DIFFERS between core and $t -- the tiers are not one body"
      diff "$WORK/core.shared" "$WORK/$t.shared" | head -6 | sed 's/^/      /'
      r2=1
    }
  done
  [ "$r2" -eq 0 ] && ok "R2 the body below the table is byte-identical across all three tiers ($(grep -c . "$WORK/core.shared") lines)"
fi

# --- R3: inside the table, only declared keys may differ ----------------------
for t in $TIERS; do table_of "$WORK/$t.md" > "$WORK/$t.table"; done
r3=0; r3n=0
nrow=$(grep -c . "$WORK/core.table")
i=0
while [ "$i" -lt "$nrow" ]; do
  i=$((i+1))
  crow=$(sed -n "${i}p" "$WORK/core.table")
  ckey=$(key_of "$crow")
  for t in lean unsealed; do
    trow=$(sed -n "${i}p" "$WORK/$t.table")
    tkey=$(key_of "$trow")
    if [ "$ckey" != "$tkey" ]; then
      bad "R3 table row $i names '$ckey' in core but '$tkey' in $t -- the tables are not the same table"
      r3=1
      continue
    fi
    if [ "$(val_of "$crow")" != "$(val_of "$trow")" ]; then
      r3n=$((r3n+1))
      case "$TIER_KEYS" in
        *" $ckey "*) : ;;
        *) bad "R3 table key '$ckey' differs between core and $t but is not declared tier-specific"; r3=1 ;;
      esac
    fi
  done
done
if [ "$nrow" -eq 0 ]; then
  bad "R3 no table rows found -- the comparison is vacuous"
elif [ "$r3n" -eq 0 ]; then
  bad "R3 NO table value differs between any two tiers -- three identical tables means the generator ignored its tier argument"
elif [ "$r3" -eq 0 ]; then
  ok "R3 every differing table value ($r3n across the pairs) sits on a declared tier-specific key"
fi

# --- R4: each body announces its OWN tier and version -------------------------
# The patch digit IS the tier (core .0, lean .1, unsealed .2) -- the
# manufacturing rule restored in 9.0.x. A body whose title disagrees with the
# manifest version printed inside its own table is the exact defect that shipping
# three tags from one commit invites.
r4=0
for t in $TIERS; do
  case "$t" in core) want=0 ;; lean) want=1 ;; unsealed) want=2 ;; esac
  title=$(sed -n '1p' "$WORK/$t.md")
  tv=$(printf '%s' "$title"  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  mv=$(grep -F 'manifest version inside' "$WORK/$t.md" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ -z "$tv" ] || [ -z "$mv" ]; then
    bad "R4 tier '$t': could not read a version from the title and the table (title='$title')"; r4=1
  elif [ "$tv" != "$mv" ]; then
    bad "R4 tier '$t': the title says $tv but the table says the manifest inside is $mv"; r4=1
  elif [ "${tv##*.}" != "$want" ]; then
    bad "R4 tier '$t': patch digit is ${tv##*.}, expected $want -- the patch digit IS the tier"; r4=1
  fi
done
[ "$r4" -eq 0 ] && ok "R4 each tier's title, its manifest version and its patch digit agree (0=core, 1=lean, 2=unsealed)"

# --- R5: no body names another tier's archive ---------------------------------
# A reader who downloads the wrong zip because the core page advertised the Lean
# archive has been actively misled, and every one of these bodies is published.
r5=0
for t in $TIERS; do
  arch=$(grep -F '| archive |' "$WORK/$t.md" | grep -oE 'RoT-MoE-[A-Za-z-]*\.zip' | head -1)
  [ -n "$arch" ] || { bad "R5 tier '$t' names no archive at all"; r5=1; continue; }
  for u in $TIERS; do
    [ "$u" = "$t" ] && continue
    other=$(grep -F '| archive |' "$WORK/$u.md" | grep -oE 'RoT-MoE-[A-Za-z-]*\.zip' | head -1)
    [ "$other" = "$arch" ] && continue
    if grep -qF "$other" "$WORK/$t.md"; then
      bad "R5 the '$t' body mentions $other, which is the '$u' tier's archive"; r5=1
    fi
  done
done
[ "$r5" -eq 0 ] && ok "R5 each body names its own archive and no other tier's"

# --- CONTROLS -----------------------------------------------------------------
echo "--- controls ---"

# C1: R2 must be able to see a divergent remainder.
cp "$WORK/core.shared" "$WORK/ctl.shared"
printf 'a line only this copy has\n' >> "$WORK/ctl.shared"
if cmp -s "$WORK/core.shared" "$WORK/ctl.shared"; then
  bad "C1 CONTROL DID NOT FIRE: an appended line compared EQUAL -- R2 cannot detect a divergent body"
else
  ok "C1 control: R2's comparator reports a one-line divergence, so its green means the bodies matched"
fi

# C2: R3 must reject an undeclared differing key. Planted, not hoped for.
c2row='| some undeclared row | value-A |'
c2key=$(key_of "$c2row")
case "$TIER_KEYS" in
  *" $c2key "*) bad "C2 CONTROL BROKEN: the planted key '$c2key' is in the declared set" ;;
  *)            ok  "C2 control: an undeclared key is recognised as undeclared, so R3 can refuse one" ;;
esac

# C3: the partition must actually split something. If shared_of ever returned the
# whole file (no table found), R2 would compare identical whole documents and
# pass while asserting nothing about the table.
whole=$(grep -c . "$WORK/core.md")
sh_n=$(grep -c . "$WORK/core.shared")
if [ "$sh_n" -gt 0 ] && [ "$sh_n" -lt "$whole" ]; then
  ok "C3 control: the header/remainder partition is a real split ($sh_n shared of $whole lines), not the whole document"
else
  bad "C3 CONTROL DID NOT FIRE: the partition returned $sh_n of $whole lines -- R2 may be comparing whole files"
fi

printf '\n== release body: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
