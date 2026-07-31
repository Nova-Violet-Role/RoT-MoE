#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# Mutation suite for Proofs/RotVacuity.lean.
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
SRC="Proofs/RotVacuity.lean"
OLEAN=".lake/build/lib/lean/Proofs/RotVacuity.olean"
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
  if lake build Proofs.RotVacuity >/tmp/mut_$id.log 2>&1; then
    echo "  $id SURVIVED  -- $desc"
    echo "       NOTHING CAUGHT THIS. The theorems above it are decorative."
    survived=$((survived+1))
  else
    dead=$(grep -oE '^error: Proofs/RotVacuity.lean:[0-9]+' /tmp/mut_$id.log | head -3 | tr '\n' ' ')
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
  if lake build Proofs.RotVacuity >/tmp/mut_$id.log 2>&1; then
    echo "  $id SURVIVED  -- $desc"
    echo "       NOTHING CAUGHT THIS. The theorems above it are decorative."
    survived=$((survived+1))
  else
    dead=$(grep -oE '^error: Proofs/RotVacuity.lean:[0-9]+' /tmp/mut_$id.log | head -3 | tr '\n' ' ')
    echo "  $id killed    -- $desc"
    echo "       first failures at: ${dead:-<none captured>}"
    killed=$((killed+1))
  fi
}

echo "== mutation suite: Proofs/RotVacuity.lean (the audit itself) =="


# ---------------------------------------------------------------------------
# The audit's claim is: "if a hypothesis set were unsatisfiable, the
# instantiation below would not compile." Every mutant here makes one witness
# WRONG. If the file still builds, that witness was never load-bearing and the
# corresponding non-vacuity claim is decoration.
# ---------------------------------------------------------------------------

# V01..V03 originally mutated a SECOND copy of the FORGE weight table that had
# been written into RotVacuity.lean. That duplicate was deleted -- RotGauge.lean
# already defines `forge` and already proves `forge_posWeights`, so the copy was
# a second source of truth and the binding checker was validating the wrong one.
# The table's own mutation coverage now lives in mutate_rotgauge.sh, where the
# table lives. These three mutate what is genuinely UNIQUE here: the witnesses.

# V01 -- the scalar arguments no longer match the witness they are discharged
# by. forge_posWeights is stated at M=1.05 C=0.7 T=0.8; move T and the
# instantiation must stop type-checking.
run_mut_nth V01 "1.05 0.7 0.8" "1.05 0.7 0.9" 1 5 \
  "witness scalars moved off forge_posWeights (instantiation must fail)"

# V02 -- gauge_ge_floor's floor is the ALL-QUIET gauge. Swapping in allLive
# claims the floor is the maximum, which the lemma cannot prove.
run_mut_nth V02 "RotMoE.allQuiet RotMoE.Face) 0" "RotMoE.allLive RotMoE.Face) 0" 1 2 \
  "floor witness changed from allQuiet to allLive"

# V03 -- the freshness witness stops being fresh. emptySettings is what makes
# disarm_arm_id applicable; give it a pre-existing hook and the hypothesis it
# discharges becomes false.
run_mut V03 'def emptySettings : Settings := ⟨fun _ => none, fun _ => []⟩' 'def emptySettings : Settings := ⟨fun _ => none, fun _ => ["rot"]⟩' \
  "emptySettings pre-loaded with the command (freshness must fail)"

# V04 -- the drive-letter witness is no longer a letter. 'both_spellings_agree'
# requires d.isAlpha, so `decide` must refuse.
run_mut V04 "both_spellings_agree 'C'" "both_spellings_agree '1'" \
  "non-alphabetic drive witness (isAlpha hypothesis must fail)"

# V05 -- the band witness inverted. classify_above_iff needs lo <= hi.
run_mut V05 "classify 0.9 1.8 R" "classify 1.8 0.9 R" \
  "band witness inverted so lo > hi (the ordering hypothesis must fail)"

# V06 -- forge_priority witnessed with forge FALSE. The hypothesis is
# f.forge = true, so `rfl` must refuse.
run_mut V06 "forge_priority _ rfl" "forge_priority ⟨false, true, true, false, false, false, false, false, false⟩ rfl" \
  "forge_priority witnessed with forge = false"

echo
echo "== RESULT =="
echo "killed=$killed survived=$survived discarded=$discarded"
cp "$BAK" "$SRC"; rm -f "$OLEAN"
lake build Proofs.RotVacuity >/dev/null 2>&1
echo "baseline restored -> lake build exit=$?"
[ "$survived" -eq 0 ] && [ "$discarded" -eq 0 ] && exit 0 || exit 1
