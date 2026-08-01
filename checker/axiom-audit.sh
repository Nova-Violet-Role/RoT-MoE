#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# WHAT EVERY THEOREM ACTUALLY RESTS ON -- `#print axioms`, on all of them, from
# a list nobody typed.
#
# THE DEFECT THIS REPLACES, measured 2026-08-01 in `.github/workflows/ci.yml`.
# The step was named "axiom gate -- zero sorryAx" and did neither thing:
#
#   for m in RotGauge RotRoute RotInstall RotPath RotVacuity; do
#     printf 'import Proofs.%s\n' "$m" > /tmp/ax_$m.lean
#     lake env lean /tmp/ax_$m.lean
#   done
#
#   1. IT NEVER RAN `#print axioms`. It imported the module and elaborated an
#      otherwise empty file. Measured on this machine: a file consisting of one
#      import exits 0 regardless of what the module rests on -- and a file
#      containing `theorem ctl : 1 = 1 := by sorry` ALSO exits 0, because
#      `sorry` is a WARNING, not an error. The gate could not fail.
#   2. ITS MODULE LIST WAS A SNAPSHOT. Three modules added after it was written
#      -- RotRemind, RotAcquire, RotVerdict -- were never audited at all, and
#      nothing said so. A hard-coded list silently stops covering whatever comes
#      next; that is the same stale-snapshot defect this repository keeps
#      finding in its own instruments.
#
# What remained was a text `grep sorry` with hand-tuned exclusions, and that
# shape was measured wrong on the same day: `sorry_always_speaks` is an
# identifier and `/-- ... `sorry` ... -/` is a doc comment, both of which a
# naive grep reports as holes.
#
# THIS CHECKER: enumerate the modules from disk, enumerate every theorem name
# from the source (comment-aware, namespace-aware), `#print axioms` each one,
# and require every name to be answered. A name that vanished, a module that
# was skipped, or an empty sweep is a FAILURE -- silence is never a pass.
#
# Exit codes: 0 audited clean · 1 something rests on sorryAx or the sweep is
# incomplete · 2 refuse (bad usage/tree) · 3 SKIP, no built workspace.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LEAN_ROOT="${LEAN_ROOT:-$REPO/lean}"

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }

[ -d "$LEAN_ROOT/Proofs" ] || {
  echo "REFUSE: no Proofs/ under LEAN_ROOT=$LEAN_ROOT"; exit 2; }

# --- NO-DOWNLOAD GUARD ------------------------------------------------------
# This checker invokes `lake env lean`, and lake RESOLVES THE PACKAGE before it
# runs anything. Against the vendored `lean/` tree that resolution once began
# fetching mathlib INTO the repository and reached 7.2 GB. A workspace that was
# never built gets a SKIP (exit 3), never a build, and a SKIP is never a pass.
# The evidence is `.lake/packages` plus SOME built module -- deliberately not
# this audit's own artefacts, which are scratch and get deleted.
_built=$(find "$LEAN_ROOT/.lake/build/lib/lean" -name '*.olean' 2>/dev/null | head -1)
if [ ! -d "$LEAN_ROOT/.lake/packages" ] || [ -z "$_built" ]; then
  echo "SKIP: $LEAN_ROOT is not a BUILT Lean workspace (.lake/packages or any .olean absent)."
  echo "      Refusing to invoke lake: resolving mathlib would DOWNLOAD ~7.2 GB into a"
  echo "      repository that ships as ~200 KB. Measured, once."
  echo "      Set LEAN_ROOT to an already-built workspace. This is a SKIP (exit 3), never a pass."
  exit 3
fi

# --- theorem names, from the SOURCE, comment- and namespace-aware ------------
# Lean block comments NEST, so a boolean flag is wrong. Doc comments carry
# theorem-shaped prose, so line-based grepping over raw text is wrong too --
# measured today on `sorry_always_speaks`.
names_of () {  # names_of <file> -> fully-qualified theorem names, one per line
  awk '
    BEGIN { depth = 0; nsdepth = 0 }
    {
      line = $0; out = ""; i = 1
      while (i <= length(line)) {
        two = substr(line, i, 2)
        if (two == "/-") { depth++; i += 2; continue }
        if (two == "-/") { if (depth > 0) depth--; i += 2; continue }
        if (depth == 0) out = out substr(line, i, 1)
        i++
      }
      sub(/--.*$/, "", out)
      if (match(out, /^namespace[ \t]+[A-Za-z_][A-Za-z0-9_.]*/)) {
        n = out; sub(/^namespace[ \t]+/, "", n); sub(/[ \t].*$/, "", n)
        ns[++nsdepth] = n; next
      }
      if (match(out, /^end[ \t]+[A-Za-z_][A-Za-z0-9_.]*/)) {
        if (nsdepth > 0) nsdepth--
        next
      }
      # Strip leading whitespace, then ATTRIBUTES, then modifiers. The first
      # version matched `^theorem` only and missed every `@[simp] theorem` --
      # six of them in RotGauge.lean, which is how an audit reports a clean
      # sweep of 29 theorems in a file that has 35. The cross-check against
      # checker/count-theorems.sh below exists so that can never again be
      # invisible.
      sub(/^[ \t]+/, "", out)
      while (match(out, /^@\[[^]]*\][ \t]*/)) sub(/^@\[[^]]*\][ \t]*/, "", out)
      sub(/^(private|protected|nonrec|noncomputable)[ \t]+/, "", out)
      sub(/^(private|protected|nonrec|noncomputable)[ \t]+/, "", out)
      if (match(out, /^(theorem|lemma)[ \t]+[A-Za-z_][A-Za-z0-9_'"'"'!?]*/)) {
        t = out
        sub(/^(theorem|lemma)[ \t]+/, "", t)
        sub(/[ \t({:\[].*$/, "", t)
        pre = ""
        for (k = 1; k <= nsdepth; k++) pre = pre ns[k] "."
        print pre t
      }
    }' "$1"
}

# THE MODULE SET IS THIS REPOSITORY'S, THE WORKSPACE IS WHEREVER LEAN_ROOT SAYS.
# First version enumerated `$LEAN_ROOT/Proofs/*.lean` and, pointed at the shared
# mathlib workspace this machine builds in, tried to audit several hundred
# modules belonging to other projects -- it ran for ten minutes and was killed,
# leaving a scratch probe behind. LEAN_ROOT answers "where can this be built",
# never "what am I responsible for".
modules=()
for f in "$REPO"/lean/Proofs/*.lean; do
  [ -f "$f" ] || continue
  b=$(basename "$f" .lean)
  case "$b" in *.pre-*|*bak*) continue;; esac
  modules+=("$b")
done
[ "${#modules[@]}" -gt 0 ] || { echo "REFUSE: no modules under $REPO/lean/Proofs"; exit 2; }
# Every module this repository ships must be present in the workspace, or the
# audit would silently cover less than it claims -- which is the defect it
# replaces, in a new costume.
missing=0
for m in "${modules[@]}"; do
  [ -f "$LEAN_ROOT/Proofs/$m.lean" ] || { bad "$m is shipped by the repo but ABSENT from LEAN_ROOT=$LEAN_ROOT"; missing=1; }
done
[ "$missing" -eq 0 ] || { printf '\n== axiom audit: %d passed, %d failed\n' "$PASS" "$FAIL"; exit 1; }
echo "== axiom audit over ${#modules[@]} modules shipped by this repo (list read from disk, never typed)"

# --- the audit itself -------------------------------------------------------
audit_module () {  # audit_module <name> -> 0 clean, 1 dirty/incomplete
  local m="$1" src="$LEAN_ROOT/Proofs/$m.lean" probe out rc
  local -a ns
  mapfile -t ns < <(names_of "$src")
  probe="$LEAN_ROOT/.axiom_probe_$m.lean"
  {
    printf 'import Proofs.%s\n' "$m"
    for n in "${ns[@]}"; do printf '#print axioms %s\n' "$n"; done
  } > "$probe"
  out=$( cd "$LEAN_ROOT" && lake env lean ".axiom_probe_$m.lean" 2>&1 ); rc=$?
  rm -f "$probe"

  if [ "${#ns[@]}" -eq 0 ]; then
    # A module with no theorems is legitimate (RotVacuity is examples), but it
    # must be SAID, so that a name-extractor that silently stopped working
    # cannot look like a clean module.
    if [ "$rc" -eq 0 ]; then
      echo "  NOTE  $m: no theorems declared (examples only) -- nothing to audit"
      return 0
    fi
    bad "$m: no theorems found AND the probe failed (rc=$rc)"; printf '%s\n' "$out" | head -5
    return 1
  fi
  if [ "$rc" -ne 0 ]; then
    bad "$m: the axiom probe did not elaborate (rc=$rc) -- names may be wrong, so nothing is established"
    printf '%s\n' "$out" | head -8 | sed 's/^/        /'
    return 1
  fi
  local answered
  answered=$(printf '%s\n' "$out" | grep -c "depends on axioms\|does not depend on any axioms")
  if [ "$answered" -ne "${#ns[@]}" ]; then
    bad "$m: ${#ns[@]} theorems extracted but $answered answered -- the sweep is INCOMPLETE"
    return 1
  fi
  if grep -q 'sorryAx' <<< "$out"; then
    bad "$m: rests on sorryAx --"
    printf '%s\n' "$out" | grep 'sorryAx' | sed 's/^/        /'
    return 1
  fi
  # Anything beyond the three standard axioms is reported, not hidden.
  local exotic
  exotic=$(printf '%s\n' "$out" | grep 'depends on axioms' \
           | grep -vE '\[(propext|Classical\.choice|Quot\.sound)(, (propext|Classical\.choice|Quot\.sound))*\]' | head -3)
  if [ -n "$exotic" ]; then
    bad "$m: an axiom outside {propext, Classical.choice, Quot.sound} --"
    printf '%s\n' "$exotic" | sed 's/^/        /'
    return 1
  fi
  ok "$m: ${#ns[@]} theorems, all answered, no sorryAx"
  return 0
}

total=0
for m in "${modules[@]}"; do
  audit_module "$m" || true
  n=$(names_of "$LEAN_ROOT/Proofs/$m.lean" | wc -l | tr -d ' ')
  total=$((total + n))
done
echo "  ---- $total theorems audited across ${#modules[@]} modules"
[ "$total" -gt 0 ] || bad "ZERO theorems audited -- an empty sweep is not a clean sweep"

# TWO INDEPENDENT COUNTERS MUST AGREE. `checker/count-theorems.sh` counts
# declarations; the extractor above resolves NAMES. They are written
# differently and can fail differently, so their agreement is evidence and
# their disagreement is a defect in one of them -- measured immediately when
# this line was added: the extractor missed six `@[simp] theorem` declarations
# and reported a clean sweep over 29 of RotGauge's 35. An audit that skips a
# theorem is indistinguishable from an audit that passed it, unless something
# counts.
declared=0
for m in "${modules[@]}"; do
  n=$(bash "$REPO/checker/count-theorems.sh" "$REPO/lean/Proofs/$m.lean" 2>/dev/null); n=${n:-0}
  declared=$((declared + n))
done
if [ "$total" -eq "$declared" ]; then
  ok "the name extractor and checker/count-theorems.sh agree: $total theorems"
else
  bad "COUNT MISMATCH: $total names extracted, $declared declarations counted -- one of the two is broken, so the sweep's coverage is unknown"
fi

# --- NEGATIVE CONTROL: the audit must be able to fail -----------------------
# A `sorry` is a WARNING in Lean: `lake env lean` on a file containing one exits
# 0 (measured). So an audit that merely builds cannot see a hole, and this
# control is the only evidence that this one can.
CTL_MOD="AxiomAuditControlScratch"
CTL_SRC="$LEAN_ROOT/Proofs/$CTL_MOD.lean"
cleanup_ctl () {
  rm -f "$CTL_SRC" "$LEAN_ROOT/.axiom_probe_$CTL_MOD.lean"
  rm -f "$LEAN_ROOT/.lake/build/lib/lean/Proofs/$CTL_MOD."{olean,ilean} 2>/dev/null
  rm -f "$LEAN_ROOT/.lake/build/ir/Proofs/$CTL_MOD.c" 2>/dev/null
}
trap cleanup_ctl EXIT
cat > "$CTL_SRC" <<'LEAN'
/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/
namespace RotMoE
/-- Scratch: a deliberate hole, written by checker/axiom-audit.sh and deleted
by it. If this file is ever found in a tree, the audit was interrupted. -/
theorem audit_control_hole : 1 = 1 := by sorry
end RotMoE
LEAN
# In a SUBSHELL: the control is EXPECTED to fail, and `audit_module` increments
# the failure counter as it does its job. The first version called it directly,
# so the control's own success was recorded as a failure of the audit -- a
# harness reporting "9 passed, 1 failed" with no failure printed anywhere.
if ( audit_module "$CTL_MOD" ) >/dev/null 2>&1; then
  bad "CONTROL: a theorem proved by \`sorry\` was audited CLEAN -- this checker proves nothing"
else
  ok "CONTROL: a planted \`sorry\` is caught (sorryAx), so a clean sweep means something"
fi
cleanup_ctl
trap - EXIT
if [ -f "$CTL_SRC" ]; then
  bad "the control module was left behind at $CTL_SRC"
else
  ok "the control module was removed -- the workspace is as it was found"
fi

printf '\n== axiom audit: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
