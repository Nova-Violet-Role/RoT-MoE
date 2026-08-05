#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE GATE SPLIT, BOUND TO ITS PROOF.
#
# `lean/Proofs/RotGates.lean` proves things about a MODEL of the fast/deep gate
# split: that the tiers partition, that a fast gate runs on every commit, that
# staging more never runs less, and -- the load-bearing one -- that a deep gate
# with no triggers is invisible to every possible commit.
#
# None of that says a word about `checker/gate-all.sh`. A proof about a model
# that nothing compares to the code is decoration, and this repository has
# already shipped one of those (`classify_total`, green and vacuous for a week).
#
# So this checker reads BOTH tables -- the shell one out of gate-all.sh, the
# Lean one out of RotGates.lean -- and requires them to agree gate for gate,
# tier for tier, trigger for trigger. If someone retiers a gate in the shell and
# forgets the witness, this goes red. If someone edits the witness to match a
# mistake, the Lean #guards go red instead.
#
# WHAT THIS IS NOT. This is a TEXT-level binding: it compares two tables, it
# does not run Lean. That is deliberate -- Lean must stay optional for a hook
# (see checker/hook-footprint.sh) -- and it is stated plainly rather than
# implied, because "bound to its proof" could otherwise be read as stronger
# than it is. The division of labour:
#
#   this checker      the two tables are THE SAME TABLE
#   lake build        that table has the properties the theorems claim
#   mutate_rotgates   those theorems are load-bearing, not decorative
#
# Exit: 0 bound   1 disagreement   2 refuse (a side could not be read)
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

SH="checker/gate-all.sh"
LN="lean/Proofs/RotGates.lean"
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  PASS  $1"; }
bad() { fail=$((fail+1)); [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=gate-split::%s\n' "$*"; echo "  FAIL  $1"; }

for f in "$SH" "$LN"; do
  [ -f "$f" ] || { echo "REFUSING: $f not found -- one side of the binding is missing."; exit 2; }
done

# --- side A: the shell table -------------------------------------------------
# Only the DEFAULT block (between `GATES="` and the closing lone quote). The
# `--full` session gates are appended in a second block and are deliberately
# outside the witness.
extract_sh() {
  awk '/^GATES="$/{inb=1;next} inb&&/^"$/{exit} inb&&/\|/{print}' "$SH" \
  | while IFS='|' read -r n t g c; do
      [ -z "$n" ] && continue
      printf '%s|%s|%s\n' "$n" "$t" "$g"
    done
}

# --- side B: the Lean witness ------------------------------------------------
# `f "name"` is a fast gate with no triggers; `d "name" ["a", "b"]` is a deep
# gate with triggers. Normalised to the same `name|tier|a,b` shape.
extract_lean() {
  awk '
    /^def shipped/ { inb=1; next }
    inb && /^  \]/ { exit }
    inb && /[,[] *f "/ {
      match($0, /f "[^"]*"/); s = substr($0, RSTART+3, RLENGTH-4)
      print s "|fast|"; next
    }
    inb && /[,[] *d "/ {
      match($0, /d "[^"]*"/); s = substr($0, RSTART+3, RLENGTH-4)
      rest = substr($0, RSTART+RLENGTH)
      trig = ""
      while (match(rest, /"[^"]*"/)) {
        t = substr(rest, RSTART+1, RLENGTH-2)
        trig = (trig == "" ? t : trig "," t)
        rest = substr(rest, RSTART+RLENGTH)
      }
      print s "|deep|" trig; next
    }
  ' "$LN"
}

A="$(extract_sh)"
B="$(extract_lean)"

# --- anti-vacuity: neither side may be empty --------------------------------
# A comparison of two empty strings passes, and would report the tables as
# identical when the truth is that the parser broke. Measured discipline from
# checker/verdict-fresh.sh, applied here for the same reason.
na=$(printf '%s\n' "$A" | grep -c '|')
nb=$(printf '%s\n' "$B" | grep -c '|')
echo "== the two tables =="
if [ "$na" -lt 10 ] || [ "$nb" -lt 10 ]; then
  echo "REFUSING: extraction returned $na shell rows and $nb Lean rows."
  echo "One of the parsers is broken. An empty-vs-empty comparison would PASS,"
  echo "which is a false green, so this refuses instead."
  exit 2
fi
ok "both sides parsed ($na shell rows, $nb Lean rows)"

# --- the binding ------------------------------------------------------------
if [ "$(printf '%s\n' "$A" | sort)" = "$(printf '%s\n' "$B" | sort)" ]; then
  ok "the shell table and the Lean witness are THE SAME TABLE"
else
  bad "the shell table and the Lean witness DISAGREE:"
  diff <(printf '%s\n' "$A" | sort) <(printf '%s\n' "$B" | sort) | sed 's/^/        /'
fi

# --- the properties the theorems make checkable ------------------------------
echo
echo "== the properties RotGates proves about a table like this =="

# no_trigger_never_escalates: a deep gate with no triggers is invisible.
orphans=$(printf '%s\n' "$A" | awk -F'|' '$2=="deep" && $3==""{print $1}')
if [ -z "$orphans" ]; then
  ok "every deep gate has at least one trigger (no_trigger_never_escalates)"
else
  bad "deep gates with NO trigger -- invisible to every commit: $orphans"
fi

# A trigger on a fast gate is dead configuration that reads as protection.
deadcfg=$(printf '%s\n' "$A" | awk -F'|' '$2=="fast" && $3!=""{print $1}')
if [ -z "$deadcfg" ]; then
  ok "no fast gate carries triggers (they run unconditionally anyway)"
else
  bad "fast gates carrying dead trigger config: $deadcfg"
fi

# Every gate is in exactly one tier (mem_tier_total / tiers_disjoint).
untiered=$(printf '%s\n' "$A" | awk -F'|' '$2!="fast" && $2!="deep"{print $1}')
if [ -z "$untiered" ]; then
  ok "every gate is exactly fast or deep (mem_tier_total, tiers_disjoint)"
else
  bad "gates with no valid tier: $untiered"
fi

# Every trigger must name a path a COMMIT CAN ACTUALLY STAGE. Two ways to fail
# that, and the second is the one CI found:
#
#   1. the path does not exist -- moved or deleted, so nothing matches it;
#   2. the path is GITIGNORED -- it may exist on your disk and still never
#      appear in `git diff --cached --name-only`, which is what the runner
#      matches against. The trigger is then dead BY CONSTRUCTION, not by
#      accident, and no amount of editing files there will ever escalate it.
#
# Measured 2026-08-03: `release install` carried a `.release/` trigger.
# `.gitignore:9` ignores that directory, so the gate could never be escalated by
# any commit; it merely looked covered. It has other, live triggers, so nothing
# was actually dark -- but the row was decoration and is now gone.
#
# Both cases are the same defect as an empty trigger list
# (`no_trigger_never_escalates`), arriving by different roads.
missing=""; ignored=""
while IFS='|' read -r n t g; do
  [ "$t" = deep ] || continue
  _o="$IFS"; IFS=','
  for tr in $g; do
    IFS="$_o"
    [ -z "$tr" ] && continue
    if git check-ignore -q "$tr" 2>/dev/null; then
      ignored="$ignored $n:$tr"
    elif [ ! -e "$tr" ] && [ -z "$(find . -path "./$tr*" -not -path './.git/*' 2>/dev/null | head -1)" ]; then
      missing="$missing $n:$tr"
    fi
    IFS=','
  done
  IFS="$_o"
done <<EOF
$A
EOF
if [ -z "$missing" ]; then
  ok "every trigger names a path that exists in this tree"
else
  bad "triggers pointing at nothing (the gate is dark):$missing"
fi
if [ -z "$ignored" ]; then
  ok "no trigger names a gitignored path (which no commit could ever stage)"
else
  bad "triggers on GITIGNORED paths -- dead by construction:$ignored"
fi

# CONTROL: the gitignored-trigger check must be able to fire. `.release/` is
# ignored in this repo, so it is the natural probe -- asserted in memory, never
# written into the table.
if git check-ignore -q ".release/" 2>/dev/null; then
  ok "CONTROL: a gitignored trigger IS recognised (probe: .release/)"
else
  note "CONTROL INCONCLUSIVE: .release/ is not ignored here, so the probe proves nothing"
fi

# Every command in the table must be a checker that exists.
missingcmd=""
awk '/^GATES="$/{inb=1;next} inb&&/^"$/{exit} inb&&/\|/{print}' "$SH" \
| while IFS='|' read -r n t g c; do
    for w in $c; do
      case "$w" in checker/*|mutate/*) [ -f "$w" ] || echo "$n:$w" ;; esac
    done
  done > /tmp/gs_missingcmd.$$
missingcmd="$(cat /tmp/gs_missingcmd.$$)"; rm -f /tmp/gs_missingcmd.$$
if [ -z "$missingcmd" ]; then
  ok "every gate's command names a checker that exists"
else
  bad "gates naming a missing checker: $missingcmd"
fi

# --- NEGATIVE CONTROLS -------------------------------------------------------
# Every check above is worthless unless it can fail. These corrupt each side IN
# MEMORY -- never on disk -- and require the comparison to notice.
echo
echo "== controls: each check must be able to FAIL =="

Abad="$(printf '%s\n' "$A" | sed 's/^benchmark|fast|/benchmark|deep|/')"
if [ "$(printf '%s\n' "$Abad" | sort)" = "$(printf '%s\n' "$B" | sort)" ]; then
  bad "CONTROL: a retiered gate was NOT detected -- the comparison is blind"
else
  ok "CONTROL: retiering one gate in the shell IS detected"
fi

Bbad="$(printf '%s\n' "$B" | sed 's#^axiom audit|deep|lean/#axiom audit|deep|leen/#')"
if [ "$(printf '%s\n' "$A" | sort)" = "$(printf '%s\n' "$Bbad" | sort)" ]; then
  bad "CONTROL: a mistyped trigger in the witness was NOT detected"
else
  ok "CONTROL: a changed trigger in the Lean witness IS detected"
fi

Aorph="$(printf '%s\n' "$A" | sed 's#^axiom audit|deep|.*#axiom audit|deep|#')"
if [ -z "$(printf '%s\n' "$Aorph" | awk -F'|' '$2=="deep" && $3==""{print $1}')" ]; then
  bad "CONTROL: an orphaned deep gate was NOT detected"
else
  ok "CONTROL: a deep gate stripped of triggers IS detected"
fi

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  echo "  gate-split: FAIL"
  exit 1
fi
echo "  gate-split: the split is bound to lean/Proofs/RotGates.lean"
exit 0
