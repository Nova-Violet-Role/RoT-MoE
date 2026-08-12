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
bad () { printf '  FAIL  %s\n' "$*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=axiom-audit::%s\n' "$*"; FAIL=$((FAIL+1)); }

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
    BEGIN { depth = 0; sp = 0 }
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
        sp++; stkKind[sp] = "ns"; stkName[sp] = n; next
      }
      # A SECTION IS NOT A NAMESPACE, and `end` closes whichever is innermost.
      # MEASURED 2026-08-09 on Proofs/RotRelease.lean, the first module here to
      # write `section Order ... end Order` INSIDE a namespace: `end Order` was
      # matched by the `end` rule below and decremented the NAMESPACE depth that
      # `section Order` never raised. Every theorem after that line was emitted
      # UNQUALIFIED, the probe died on "Unknown constant", and the audit
      # reported "names may be wrong, so nothing is established".
      #
      # It failed CLOSED, which is why this was a false alarm and never a false
      # green -- but the wrong names came from THIS function, not from the
      # module, and the tempting repair is to stop using named sections in
      # Lean. That would be editing the subject to suit the instrument.
      #
      # NOTE FOR EDITORS: this awk program sits inside a single-quoted shell
      # string, so an apostrophe in a comment TERMINATES it and the whole
      # extractor silently returns nothing. Measured, twice in one session.
      #
      # One stack, two kinds. Only `ns` entries contribute to the prefix.
      if (match(out, /^section([ \t]+[A-Za-z_][A-Za-z0-9_.]*)?[ \t]*$/)) {
        sp++; stkKind[sp] = "sec"; stkName[sp] = ""; next
      }
      if (match(out, /^end([ \t]+[A-Za-z_][A-Za-z0-9_.]*)?[ \t]*$/)) {
        if (sp > 0) sp--
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
        for (k = 1; k <= sp; k++) if (stkKind[k] == "ns") pre = pre stkName[k] "."
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

# --- hoist lake's package resolution out of the per-module loop --------------
# Measured 2026-08-08: `lake env lean <probe>` costs ~2s of package resolution
# BEFORE lean starts, and this loop pays it once per module -- ~64s of the
# gate's 186s, spent re-answering a question whose answer cannot change during
# the run. Capturing LEAN_PATH once and invoking `lean` directly removes it.
#
# Every module is still probed in its OWN process, and that is deliberate: a
# combined import would let one module's `open`s and instances change how a
# LATER module's axioms resolve, so the isolation is what makes each answer
# attributable to the module it names.
#
# CORRECTED 2026-08-12. This comment used to say isolation was FORCED because
# Proofs.RotGauge and Proofs.RotMutant both defined `RotMoE.classify` and lean
# refused with "environment already contains". That collision was real, and it
# has now been repaired at the source: RotMutant's is `classifyOutcome`, and the
# combined import elaborates (measured -- `#check` returns both, with distinct
# signatures). The isolation is kept because it is right, not because a name
# clash cornered us into it -- a constraint that survives only as long as a bug
# does is not a design.
#
# `checker/name-collision.sh` now fails if any two modules declare the same
# fully-qualified name, so the condition this paragraph used to describe cannot
# come back silently.
#
# The fallback is the original command, used whenever the fast path is not
# demonstrably available: no LEAN_PATH, or no usable `lean` on PATH. A speedup
# that changes WHAT is checked would be a downgrade wearing a stopwatch.
AX_LEAN_PATH="$( cd "$LEAN_ROOT" && lake env printenv LEAN_PATH 2>/dev/null )" || AX_LEAN_PATH=""
if [ -n "$AX_LEAN_PATH" ] && command -v lean >/dev/null 2>&1 && lean --version >/dev/null 2>&1; then
  AX_FAST=1
  echo "   probe: direct lean with a hoisted LEAN_PATH (lake resolution paid once)"
else
  AX_FAST=0
  echo "   probe: lake env lean per module (fast path unavailable -- falling back)"
fi

# --- the audit itself -------------------------------------------------------
audit_module () {  # audit_module <name> -> 0 clean, 1 dirty/incomplete
  local m="$1" src="$LEAN_ROOT/Proofs/$m.lean" probe out rc
  local -a ns
  # NOT `mapfile`: it is bash 4.0+, and macOS ships bash 3.2.57 as /bin/bash.
  # A read loop is portable to every bash and behaves identically here.
  ns=()
  while IFS= read -r _n; do ns+=("$_n"); done < <(names_of "$src")
  probe="$LEAN_ROOT/.axiom_probe_$m.lean"
  {
    printf 'import Proofs.%s\n' "$m"
    for n in "${ns[@]}"; do printf '#print axioms %s\n' "$n"; done
  } > "$probe"
  if [ "${AX_FAST:-0}" -eq 1 ]; then
    out=$( cd "$LEAN_ROOT" && LEAN_PATH="$AX_LEAN_PATH" lean ".axiom_probe_$m.lean" 2>&1 ); rc=$?
  else
    out=$( cd "$LEAN_ROOT" && lake env lean ".axiom_probe_$m.lean" 2>&1 ); rc=$?
  fi
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
  # --- UNWRAP BEFORE PARSING --------------------------------------------------
  # `#print axioms` WRAPS its output when the declaration name is long:
  #
  #     'RotMoE.CaseFold.a_green_build_does_not_imply_the_kernel_can_find_it'
  #       depends on axioms: [propext,
  #      Classical.choice,
  #      Quot.sound]
  #
  # A line-oriented reader sees `[propext,` with no closing bracket, the
  # whitelist regex below does not match, and the module is reported as resting
  # on an exotic axiom. MEASURED 2026-08-09 on RotCaseFold: two theorems flagged,
  # both resting on nothing but the three standard axioms. **The audit's verdict
  # depended on the LENGTH OF THE THEOREM'S NAME.**
  #
  # The failure direction was a false ALARM, not a false green -- a truncated
  # `[propext,` fails the whitelist and `sorryAx` is matched across every line
  # regardless of wrapping. That is the safe direction, and it is still a defect:
  # an instrument that cries wolf on correct input trains its reader to dismiss
  # it, and the obvious "repair" is to shorten a theorem name, which is bending
  # the proof to fit a broken ruler.
  #
  # Each record starts with a quote at column 1; every other line is a
  # continuation and is folded onto it.
  out=$(printf '%s\n' "$out" | awk '
    /^'\''/ { if (started) printf "\n"; printf "%s", $0; started = 1; next }
    { if (started) { sub(/^[ \t]+/, ""); printf " %s", $0 } else print }
    END { if (started) printf "\n" }
  ')
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


# --- NO THEOREM MAY HIDE BEHIND `private` -----------------------------------
# `#print axioms` resolves names from an IMPORTING module, and a private
# declaration is not visible there: the probe fails to elaborate, and this
# audit reports "names may be wrong" rather than an axiom verdict. That is the
# GOOD outcome, and it is what happened -- RotSessionLog was the first module
# in the repo to use `private theorem` and CI went red on it immediately.
#
# The bad outcome is the one this check exists to prevent. If the probe were
# ever taught to SKIP names it cannot resolve -- the obvious repair, and the
# wrong one -- then `private` would become a place to hide a `sorry` from the
# only instrument that looks for one. The blind spot would be silent and the
# audit would keep printing PASS.
#
# So the rule is the strong one: a theorem in this repo is public, or it is not
# a theorem. Helper lemmas are part of what a reader must trust and are audited
# like everything else.
priv=0
priv_where=""
for m in "${modules[@]}"; do
  c=$(grep -c '^[[:space:]]*private[[:space:]]\+theorem[[:space:]]' "$REPO/lean/Proofs/$m.lean" 2>/dev/null || true)
  c=${c:-0}
  if [ "$c" -gt 0 ]; then
    priv=$((priv + c))
    priv_where="$priv_where $m($c)"
  fi
done
if [ "$priv" -eq 0 ]; then
  ok "no theorem hides behind \`private\` -- every one is reachable by #print axioms"
else
  bad "PRIVATE THEOREMS ARE UNAUDITABLE:$priv_where -- #print axioms cannot resolve them from an importing module, so a sorry could hide there. Drop \`private\`."
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

# --- CONTROL: the unwrapper must not turn a bad axiom into a clean line -------
#
# The unwrap added 2026-08-09 folds continuation lines onto the record they
# belong to. That is exactly the kind of edit that can quietly widen what counts
# as acceptable, so it is controlled in BOTH directions on synthetic input:
#
#   1. a WRAPPED record listing only the three standard axioms must PASS
#   2. a WRAPPED record hiding a non-standard axiom on a continuation line must
#      still be REJECTED -- otherwise the repair would have created a false green
_unwrap() {
  awk '
    /^'\''/ { if (started) printf "\n"; printf "%s", $0; started = 1; next }
    { if (started) { sub(/^[ \t]+/, ""); printf " %s", $0 } else print }
    END { if (started) printf "\n" }
  '
}
_whitelisted() {
  grep 'depends on axioms' \
  | grep -vE '\[(propext|Classical\.choice|Quot\.sound)(, (propext|Classical\.choice|Quot\.sound))*\]'
}
_ctl_good=$(printf "'A.very_long_theorem_name_that_wraps' depends on axioms: [propext,\n Classical.choice,\n Quot.sound]\n" | _unwrap | _whitelisted)
if [ -z "$_ctl_good" ]; then
  ok "CONTROL: a WRAPPED record of the three standard axioms is accepted (the false alarm is gone)"
else
  bad "CONTROL: the unwrapper still rejects a clean wrapped record -- the parse fix does not work"
fi
_ctl_bad=$(printf "'A.very_long_theorem_name_that_wraps' depends on axioms: [propext,\n someExoticAxiom,\n Quot.sound]\n" | _unwrap | _whitelisted)
if [ -n "$_ctl_bad" ]; then
  ok "CONTROL: an exotic axiom hidden on a CONTINUATION line is still rejected -- the fix did not widen the whitelist"
else
  bad "CONTROL: an exotic axiom on a continuation line was ACCEPTED -- the unwrap created a false green"
fi

printf '\n== axiom audit: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
