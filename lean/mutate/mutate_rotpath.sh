#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# Mutation suite for Proofs/RotPath.lean.
#
# A theorem no mutation kills is decoration. Each mutant below breaks the MODEL
# in a way a careless edit really could, and the theorems must die.
#
# Three rules, learned the hard way in this repo:
#   1. ASSERT THE NEEDLE IS PRESENT before building. A patch that silently fails
#      to apply produces a green build and gets scored SURVIVED, which reads as
#      "robust" and means "nothing was tested".
#   2. DELETE THE STALE .olean. Lake is incremental and will happily not rebuild.
#   3. DISCARDED is not SURVIVED. One is a claim about the harness, the other
#      about the theorem.

set -uo pipefail
cd "$(dirname "$0")"
SRC="Proofs/RotPath.lean"
OLEAN=".lake/build/lib/lean/Proofs/RotPath.olean"
BAK="$SRC.mutbak"
cp "$SRC" "$BAK"
trap 'cp "$BAK" "$SRC"; rm -f "$BAK"' EXIT

killed=0; survived=0; discarded=0

run_mut () {  # run_mut <id> <needle> <replacement> <description>
  id="$1"; needle="$2"; repl="$3"; desc="$4"
  cp "$BAK" "$SRC"
  n=$(grep -F -c "$needle" "$SRC")
  if [ "$n" -ne 1 ]; then
    echo "  $id DISCARDED -- needle appears $n times (expected exactly 1): $desc"
    discarded=$((discarded+1)); return
  fi
  # Line-oriented replacement: multi-line string surgery is where escaping breaks.
  awk -v needle="$needle" -v repl="$repl" '
    { i = index($0, needle)
      if (i > 0) { $0 = substr($0,1,i-1) repl substr($0,i+length(needle)) }
      print }' "$SRC" > "$SRC.tmp" && mv "$SRC.tmp" "$SRC"
  if grep -F -q "$needle" "$SRC"; then
    echo "  $id DISCARDED -- replacement did not land: $desc"
    discarded=$((discarded+1)); return
  fi
  rm -f "$OLEAN"
  if lake build Proofs.RotPath >/tmp/mut_$id.log 2>&1; then
    echo "  $id SURVIVED  -- $desc"
    echo "       NOTHING CAUGHT THIS. The theorems above it are decorative."
    survived=$((survived+1))
  else
    dead=$(grep -oE 'RotPath\.lean:[0-9]+' /tmp/mut_$id.log | head -3 | tr '\n' ' ')
    echo "  $id killed    -- $desc"
    echo "       first failures at: ${dead:-<none captured>}"
    killed=$((killed+1))
  fi
}

run_mut_nth () {  # run_mut_nth <id> <needle> <repl> <occurrence> <total> <desc>
  # Needed because a needle can legitimately appear twice: once in the
  # DEFINITION and once in a theorem STATEMENT that quotes it. Mutating the
  # definition is the meaningful test; requiring uniqueness would discard it
  # forever, and blindly replacing both would also rewrite the theorem, which
  # makes the mutant tautologically green -- the exact false SURVIVED this
  # harness exists to avoid.
  id="$1"; needle="$2"; repl="$3"; occ="$4"; total="$5"; desc="$6"
  cp "$BAK" "$SRC"
  n=$(grep -F -c "$needle" "$SRC")
  if [ "$n" -ne "$total" ]; then
    echo "  $id DISCARDED -- needle appears $n times (expected $total): $desc"
    discarded=$((discarded+1)); return
  fi
  # awk -v PROCESSES ESCAPE SEQUENCES in the assignment: a needle containing
  # a literal backslash arrives mangled and matches nothing, which this harness
  # would then report as DISCARDED (correctly) forever. ENVIRON does not.
  MUT_NEEDLE="$needle" MUT_REPL="$repl" MUT_WANT="$occ" awk '
      BEGIN { needle = ENVIRON["MUT_NEEDLE"]; repl = ENVIRON["MUT_REPL"]; want = ENVIRON["MUT_WANT"]+0 }
    { seen_line = 0
      out = ""
      rest = $0
      while ((i = index(rest, needle)) > 0) {
        hit++
        if (hit == want) {
          out = out substr(rest,1,i-1) repl
        } else {
          out = out substr(rest,1,i-1) needle
        }
        rest = substr(rest, i+length(needle))
        seen_line = 1
      }
      print (seen_line ? out rest : $0) }' "$SRC" > "$SRC.tmp" && mv "$SRC.tmp" "$SRC"
  left=$(grep -F -c "$needle" "$SRC")
  if [ "$left" -ne $((total-1)) ]; then
    echo "  $id DISCARDED -- expected $((total-1)) needle(s) left, found $left: $desc"
    discarded=$((discarded+1)); return
  fi
  rm -f "$OLEAN"
  if lake build Proofs.RotPath >/tmp/mut_$id.log 2>&1; then
    echo "  $id SURVIVED  -- $desc"
    echo "       NOTHING CAUGHT THIS. The theorems above it are decorative."
    survived=$((survived+1))
  else
    dead=$(grep -oE 'RotPath\.lean:[0-9]+' /tmp/mut_$id.log | head -3 | tr '\n' ' ')
    echo "  $id killed    -- $desc"
    echo "       first failures at: ${dead:-<none captured>}"
    killed=$((killed+1))
  fi
}

echo "== mutation suite: Proofs/RotPath.lean =="

# P01 -- the whole point of slashify. If backslashes are not converted, the two
# spellings cannot converge and the stranding bug returns.
run_mut_nth P01 "if c = '\\\\' then '/' else c" "c" 1 2 \
  "slashify becomes the identity (backslashes survive)"

# P02 -- drive letter not lowercased: C: and c: would produce different strings,
# so an install from one shell could not be removed from the other.
run_mut_nth P02 "'/' :: d.toLower :: '/' :: rest" "'/' :: d :: '/' :: rest" 1 2 \
  "drive letter no longer lowercased"

# P03 -- the alpha guard dropped: '1:/x' would be rewritten to '/1/x'.
run_mut P03 "if d.isAlpha then" "if true then" \
  "drive-prefix guard accepts any character"

# P04 -- the colon in the pattern changed, so no drive prefix ever matches and
# normalize degenerates to slashify.
run_mut P04 "| d :: ':' :: '/' :: rest =>" "| d :: ';' :: '/' :: rest =>" \
  "drive pattern looks for ';' instead of ':'"

# P05 -- separator emitted is a backslash: output is no longer POSIX.
run_mut P05 "then '/' :: d.toLower" "then '\\\\' :: d.toLower" \
  "canonical form emits a backslash as its root separator"

echo
echo "== RESULT =="
echo "killed=$killed survived=$survived discarded=$discarded"
cp "$BAK" "$SRC"; rm -f "$OLEAN"
lake build Proofs.RotPath >/dev/null 2>&1
echo "baseline restored -> lake build exit=$?"
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && exit 0 || exit 1
