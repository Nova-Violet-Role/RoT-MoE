#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# NO TWO MODULES MAY DECLARE THE SAME FULLY-QUALIFIED NAME
#
# THE DEFECT THIS EXISTS FOR (measured 2026-08-12). `Proofs/RotGauge.lean` and
# `Proofs/RotMutant.lean` both declared `RotMoE.classify` -- one a Band
# classifier over reals, one an Outcome classifier over runs. Nothing in this
# repository imported both, so every gate stayed green for weeks and the library
# looked healthy.
#
# It was not healthy, it was LATENT. The moment anything imported both, lean
# refused the whole environment:
#
#     error: environment already contains 'RotMoE.classify' from Proofs.RotGauge
#
# That is exactly what happened to the shared Lean tree at D:/Lean/proofs, whose
# aggregator imports every delivered module: a bare `lake build` there went red
# on a tree where all 83 modules built individually. A defect that only fires
# for the NEXT correct change is the worst kind, because the person who trips it
# did nothing wrong and the error names files they never touched.
#
# Worse, the repo had adapted to it. Two checkers carried comments explaining
# that per-module isolation was "not optional" BECAUSE of the clash -- a
# workaround that had started to read like a design decision. A constraint that
# survives only as long as a bug does is not a design, and documenting a bug
# eloquently enough makes it invisible.
#
# WHY THIS IS THE DURABLE FORM. The tempting check is "RotGauge and RotMutant
# must not both declare classify" -- true today, and dead the moment those two
# names change. This check knows nothing about which modules or which names
# exist; it asks the general question, so it keeps working on modules written
# after it.
#
# Namespaced declarations are NOT collisions. `RotMoE.SessionLog.classify` and
# `RotMoE.LocalRelease.classify` coexist happily and always did; the qualifier
# is what makes them different names. So the comparison is over the qualified
# name a module actually contributes, which is what lean itself compares.
#
# Exit 0 = no two modules contribute the same qualified name.
# Exit 1 = a collision exists, named, with both files.
# Exit 2 = the checker could not run (no modules found, unreadable tree).
# =============================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROOFS="$ROOT/lean/Proofs"

pass=0; fail=0
ok  () { printf '  PASS  %s\n' "$*"; pass=$((pass+1)); }
bad () { printf '  FAIL  %s\n' "$*"; fail=$((fail+1)); }
inf () { printf '  ----  %s\n' "$*"; }

echo "== name-collision: no two modules may declare the same qualified name =="

[ -d "$PROOFS" ] || { echo "  name-collision: $PROOFS not found"; exit 2; }

# --- extract (qualifiedName, file) for every top-level declaration -----------
# The namespace in force is tracked as a stack, because a declaration's real
# name is the namespace path plus its own. `namespace A.B` pushes one frame
# holding "A.B"; `end` pops it. Anonymous `section`s do not affect names, so
# they are ignored on purpose -- treating them as frames would invent
# qualifiers that lean does not.
# BLOCK COMMENTS ARE SKIPPED, and this was found by the checker's own first run.
# Lean docstrings wrap prose, and prose in this repo contains sentences like
# "theorem that was missing when ..." (RotAbility.lean:471) and "theorem that
# earns the phrase ..." (RotGauge.lean:623). A line-shaped matcher read both as
# declarations of `RotMoE.that` and reported a collision between two modules
# that share nothing. A checker whose first output is a false positive gets
# switched off, so the depth counter is not a nicety -- it is the difference
# between an alarm and a nuisance. `/-` nests in Lean, so depth is counted
# rather than toggled.
emit_decls () {
  awk '
    function top() { return n > 0 ? stack[n] : "" }
    {
      line = $0
      # depth BEFORE this line decides whether the line is code
      wascode = (depth == 0)
      tmp = line
      opens = gsub(/\/-/, "", tmp)
      tmp2 = line
      closes = gsub(/-\//, "", tmp2)
      depth += opens - closes
      if (depth < 0) depth = 0
      if (!wascode) next
      sub(/[ \t]*--.*$/, "", line)
      if (line ~ /^namespace[ \t]+[A-Za-z_]/) {
        split(line, a, /[ \t]+/)
        pre = top()
        stack[++n] = (pre == "" ? a[2] : pre "." a[2])
        next
      }
      if (line ~ /^end[ \t]+[A-Za-z_]/ || line ~ /^end[ \t]*$/) { if (n > 0) n--; next }
      if (line ~ /^(noncomputable[ \t]+)?(private[ \t]+)?(protected[ \t]+)?(def|abbrev|structure|inductive|theorem|lemma|opaque|axiom)[ \t]+[A-Za-z_]/) {
        # strip leading modifiers, then take the declaration name
        s = line
        sub(/^(noncomputable[ \t]+)?(private[ \t]+)?(protected[ \t]+)?/, "", s)
        split(s, b, /[ \t]+/)
        name = b[2]
        gsub(/[^A-Za-z0-9_'"'"'.].*$/, "", name)
        if (name == "") next
        pre = top()
        print (pre == "" ? name : pre "." name)
      }
    }
  ' "$1"
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/namecoll.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

modules=0
for f in "$PROOFS"/*.lean; do
  [ -f "$f" ] || continue
  modules=$((modules+1))
  b="$(basename "$f")"
  emit_decls "$f" | sort -u | while IFS= read -r nm; do
    [ -n "$nm" ] && printf '%s\t%s\n' "$nm" "$b"
  done >> "$TMP/all.tsv"
done

if [ "$modules" -eq 0 ]; then
  echo "  name-collision: no modules found under $PROOFS -- refusing to pass vacuously"
  exit 2
fi
if [ ! -s "$TMP/all.tsv" ]; then
  echo "  name-collision: extracted ZERO declarations from $modules module(s)."
  echo "  A checker that finds nothing cannot find a collision either. This is a"
  echo "  harness fault, not a clean bill of health."
  exit 2
fi

total=$(wc -l < "$TMP/all.tsv")
inf "$modules module(s), $total top-level declaration(s) examined"

# A collision is one qualified name contributed by two or more DISTINCT files.
cut -f1 "$TMP/all.tsv" | sort | uniq -d > "$TMP/dupnames"
collisions=0
while IFS= read -r nm; do
  [ -n "$nm" ] || continue
  files=$(awk -F'\t' -v n="$nm" '$1==n {print $2}' "$TMP/all.tsv" | sort -u)
  count=$(printf '%s\n' "$files" | grep -c .)
  if [ "$count" -ge 2 ]; then
    collisions=$((collisions+1))
    bad "$nm is declared in $count modules: $(printf '%s' "$files" | tr '\n' ' ')"
  fi
done < "$TMP/dupnames"

[ "$collisions" -eq 0 ] && ok "no qualified name is declared by two modules"

# --- NEGATIVE CONTROL: the check must be able to FAIL ------------------------
# Without this the whole file could be a no-op and would look identical. Two
# synthetic modules are given the same qualified name and the SAME detection
# path is run over them; if it reports no collision, the checker is decoration
# and this script fails on itself.
CTL="$TMP/ctl"; mkdir -p "$CTL"
printf 'namespace Fixture\ndef shared : Nat := 1\nend Fixture\n' > "$CTL/A.lean"
printf 'namespace Fixture\ndef shared : Nat := 2\nend Fixture\n' > "$CTL/B.lean"
: > "$CTL/all.tsv"
for f in "$CTL/A.lean" "$CTL/B.lean"; do
  emit_decls "$f" | sort -u | while IFS= read -r nm; do
    [ -n "$nm" ] && printf '%s\t%s\n' "$nm" "$(basename "$f")"
  done >> "$CTL/all.tsv"
done
ctl_hits=$(cut -f1 "$CTL/all.tsv" | sort | uniq -d | grep -c . || true)
if [ "${ctl_hits:-0}" -ge 1 ]; then
  ok "CONTROL: a planted duplicate (Fixture.shared in two files) IS detected"
else
  bad "CONTROL DEAD: the planted duplicate was NOT detected -- this checker cannot fail,"
  bad "              so its green above means nothing"
fi

# And the mirror control: two DIFFERENTLY namespaced declarations of the same
# short name must NOT be reported, or the checker would forbid a correct tree.
printf 'namespace Alpha\ndef shared : Nat := 1\nend Alpha\n' > "$CTL/C.lean"
printf 'namespace Beta\ndef shared : Nat := 2\nend Beta\n'   > "$CTL/D.lean"
: > "$CTL/all2.tsv"
for f in "$CTL/C.lean" "$CTL/D.lean"; do
  emit_decls "$f" | sort -u | while IFS= read -r nm; do
    [ -n "$nm" ] && printf '%s\t%s\n' "$nm" "$(basename "$f")"
  done >> "$CTL/all2.tsv"
done
ctl2=$(cut -f1 "$CTL/all2.tsv" | sort | uniq -d | grep -c . || true)
if [ "${ctl2:-0}" -eq 0 ]; then
  ok "CONTROL: differently namespaced Alpha.shared / Beta.shared are NOT flagged"
else
  bad "CONTROL: namespaced names were flagged as colliding -- this would forbid a correct tree"
fi

echo
echo "== name-collision: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
