#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# AXIOM CLASSIFICATION -- what does a reader have to TRUST to believe this?
#
# This is the tool the Unsealed variant exists to ship. `lake build` says a proof
# elaborated. `leanchecker` says its proof TERMS are valid. Neither answers the
# question that decides whether a theorem is worth anything:
#
#     what must I trust, beyond the kernel, to believe this?
#
# Every theorem lands in exactly one of three classes:
#
#   KERNEL      no axioms, or only propext / Classical.choice / Quot.sound.
#               The kernel checked it. Trust Lean's kernel, nothing else.
#
#   COMPILER    depends on a `native_decide` axiom (or `Lean.ofReduceBool` /
#               `Lean.ofReduceNat`). The statement was EXECUTED, not proved. You
#               are trusting the compiler, the runtime and the CPU it ran on.
#
#   BROKEN      depends on sorryAx. Not proved at all.
#
# WHY THIS TOOL HAD TO EXIST, measured rather than assumed:
#
#     lake env leanchecker <a module full of native_decide>  ->  EXIT 0
#
# The kernel re-check PASSES on native_decide, and it always will: the tactic
# emits a declared axiom, and a declared axiom is trusted by definition. So the
# strongest instrument in the normal toolkit is silent here, by construction.
# `#print axioms` is the only thing that sees it -- which is exactly what this
# script automates, per theorem, with a machine-readable verdict.
#
# The rule this enforces, and the reason the Unsealed variant is honest rather
# than a loosening: a COMPILER-class theorem may exist, but it may NEVER be
# counted in a headline theorem number. Executed is not proved, and a count that
# mixes them is a claim its own author cannot defend.
#
# Usage:
#   checker/axiom-class.sh                    # every module in lean/Proofs
#   checker/axiom-class.sh Proofs.RotGauge    # one module
#   ROTMOE_ALLOW_COMPILER=1 checker/axiom-class.sh   # permit COMPILER, still report
#
# Exit: 0 all KERNEL (or COMPILER permitted) · 1 a BROKEN or unpermitted
#       COMPILER theorem exists · 2 refuse (no Lean toolchain) · 3 SKIP.
# =============================================================================

set -uo pipefail

# --- a bound that does not assume GNU coreutils ------------------------------
# macOS does NOT ship `timeout` (it is GNU coreutils). A bare `timeout N cmd` is
# "command not found" there, which returns an EMPTY capture -- and an empty
# capture reads exactly like a tool that answered nothing. Homebrew installs the
# same binary as `gtimeout`. If neither exists the call runs UNBOUNDED, and that
# is announced rather than hidden. Full story: checker/release-install.sh.
if command -v timeout >/dev/null 2>&1; then TMOBIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then TMOBIN=gtimeout
else TMOBIN=""; fi
run_bounded () {   # run_bounded <seconds> <cmd...>; reads stdin like the command it wraps
  _secs="$1"; shift
  if [ -n "$TMOBIN" ]; then "$TMOBIN" "$_secs" "$@"; else
    [ -n "${_unbounded_warned:-}" ] || { printf "  ----  UNBOUNDED: no timeout/gtimeout on PATH; a hang cannot be detected here\n" >&2; _unbounded_warned=1; }
    "$@"
  fi
}
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LEANDIR="$REPO/lean"
cd "$LEANDIR" 2>/dev/null || { echo "REFUSE: no lean/ directory"; exit 2; }

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=axiom-class::%s\n' "$*"; FAIL=$((FAIL+1)); }
note() { printf '  ----  %s\n' "$*"; }

command -v lake >/dev/null 2>&1 || { echo "SKIP: lake is not on PATH -- install the toolchain (SETUP_LEAN)"; exit 3; }

ALLOW_COMPILER="${ROTMOE_ALLOW_COMPILER:-0}"

# --- which modules ------------------------------------------------------------
if [ "$#" -gt 0 ]; then
  MODULES="$*"
else
  # Sweep the directory rather than a remembered list. A hard-coded set silently
  # stops covering whatever is added after it was written -- the same
  # stale-snapshot defect this project gates against everywhere else.
  MODULES=""
  for f in Proofs/*.lean; do
    [ -f "$f" ] || continue
    b=$(basename "$f" .lean)
    MODULES="$MODULES Proofs.$b"
  done
fi

echo "== axiom classification =="
note "toolchain: $(cat lean-toolchain 2>/dev/null || echo unknown)"

# Hoist lake's package resolution out of the per-module probe loop below.
# Measured 2026-08-08 on the sibling gate: ~2s per invocation, paid once per
# module, for an answer that cannot change during the run. Verified there by
# diffing the fast and fallback outputs -- byte-identical verdicts -- and by a
# planted `sorry`, which the fast path still caught at exit 1.
AXC_LEAN_PATH="$( lake env printenv LEAN_PATH 2>/dev/null )" || AXC_LEAN_PATH=""
if [ -n "$AXC_LEAN_PATH" ] && command -v lean >/dev/null 2>&1 && lean --version >/dev/null 2>&1; then
  AXC_FAST=1
  note "probe: direct lean with a hoisted LEAN_PATH (lake resolution paid once)"
else
  AXC_FAST=0
  note "probe: lake env lean per module (fast path unavailable -- falling back)"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/rotmoe-axclass.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# --- extracting declaration names ---------------------------------------------
# A `sed` for `^theorem` is the obvious approach and it is WRONG, measured here:
# it pulled two "theorems" out of RotVacuity.lean that are PROSE inside a doc
# comment -- one of them a deliberately vacuous example the module exists to
# warn about. The probe then asked for axioms of a constant that does not exist,
# lean exited 1, and two verdicts went missing.
#
# checker/count-theorems.sh already solved this, with a selftest that plants two
# real declarations and two written in prose. The comment-depth tracking below is
# that same logic -- Lean block comments NEST, so a boolean "in a comment" flag
# is not enough -- extended to also emit the NAME. Duplicating the idea is bad
# enough; duplicating it in a WEAKER form is how two files end up disagreeing
# about what a theorem is.
names_in () {
  awk '
    BEGIN { depth = 0; depth_at_line_start = 0 }
    {
      line = $0; i = 1; out = ""
      while (i <= length(line)) {
        two = substr(line, i, 2)
        if (two == "/-") { depth++; i += 2; continue }
        if (two == "-/") { if (depth > 0) depth--; i += 2; continue }
        if (depth == 0) out = out substr(line, i, 1)
        i++
      }
      # NAMESPACES NEST, AND THE PROBE MUST FOLLOW THEM.
      #
      # This used to emit a bare name, and the caller prefixed every one of them
      # with the FIRST `namespace` line in the file. That is correct only while
      # a module has exactly one namespace. `RotLog.lean` opens
      # `namespace RotMoE.Log` and then `namespace Stemlog` inside it, so six
      # theorems were probed as `RotMoE.Log.laneOfStem_sound` -- a name that does
      # not exist. ONE unresolvable name makes the whole probe file error out,
      # and with it EVERY verdict for that module: the run reported "287 probed,
      # 269 verdicts, 18 unaccounted", losing all of RotLog rather than six of it.
      #
      # It failed loudly and that is the only reason this is a repair and not a
      # silent hole -- the count reconciliation is what caught it. A stack is
      # kept here instead, so the name emitted is the one the elaborator knows.
      if (depth_at_line_start == 0 && out ~ /^namespace[ ]+/) {
        nsline = out
        sub(/^namespace[ ]+/, "", nsline); sub(/[ ].*$/, "", nsline)
        if (nsline != "") { nsdepth++; nsstack[nsdepth] = nsline }
      }
      if (depth_at_line_start == 0 && out ~ /^end[ ]+/) {
        endline = out
        sub(/^end[ ]+/, "", endline); sub(/[ ].*$/, "", endline)
        if (nsdepth > 0 && endline == nsstack[nsdepth]) { nsdepth-- }
      }
      if (depth_at_line_start == 0 &&
          out ~ /^(@\[[^]]*\] )?(private |protected |noncomputable )*(theorem|lemma)[ (]/) {
        # strip any attribute and modifiers, then take the identifier
        sub(/^(@\[[^]]*\] )?(private |protected |noncomputable )*(theorem|lemma)[ ]+/, "", out)
        sub(/[ (:{\[].*$/, "", out)
        if (out != "") {
          pre = ""
          for (k = 1; k <= nsdepth; k++) pre = pre nsstack[k] "."
          print pre out
        }
      }
      depth_at_line_start = depth
    }
  ' "$1"
}

# --- collect every theorem name, per module ----------------------------------
# `theorem`/`lemma` at column 0 is the shape this repository uses; anything
# indented is inside a proof and is not a top-level declaration.
# ONE PROBE PER MODULE, never a single file importing them all.
#
# The all-at-once form is the obvious design and it is wrong here, measured:
#
#   error: import Proofs.RotMutant failed, environment already contains
#          'RotMoE.classify' from Proofs.RotGauge
#
# Two modules in this corpus declare the same name, so they cannot share an
# environment. Building them separately -- which is what CI does -- never
# notices. A classifier that imported everything would therefore produce ZERO
# verdicts and, without the accounting check below, would have reported a clean
# sweep of a corpus it never read. Per-module probing sidesteps the collision
# entirely and is the more honest shape anyway: each module is classified in the
# environment it actually compiles in.
total=0
: > "$WORK/ax.txt"
probe_rc_bad=0
probed_modules=0
for m in $MODULES; do
  file="Proofs/$(printf '%s' "$m" | sed 's/^Proofs\.//').lean"
  [ -f "$file" ] || { note "no source for $m -- skipped"; continue; }
  # `names_in` now returns FULLY QUALIFIED names -- it walks the namespace stack
  # itself, because a module may open more than one and the old single-prefix
  # form silently produced names that do not exist. See the long note there.
  P="$WORK/probe-$(printf '%s' "$m" | tr '.' '_').lean"
  printf 'import %s\n\n' "$m" > "$P"
  n_here=0
  for t in $(names_in "$file"); do
    printf '#print axioms %s\n' "$t" >> "$P"
    n_here=$((n_here+1))
  done
  # A module with no theorems is not probed at all -- and must NOT be counted as
  # an attempt, or the skip arithmetic below is off by one for every such module.
  # RotVacuity is exactly this case: its only two `theorem` lines are PROSE
  # inside a doc comment, so the comment-aware extractor correctly yields none.
  [ "$n_here" -eq 0 ] && { note "$m declares no theorems -- nothing to classify"; continue; }
  total=$((total+n_here))
  probed_modules=$((probed_modules+1))
  # Same hoist as checker/axiom-audit.sh: `lake env lean` re-resolves the
  # package before every probe, and this loop pays it once per module. The
  # answer cannot change during the run, so it is captured once above and
  # `lean` is invoked directly. Per-module isolation is UNCHANGED and remains
  # deliberate: it is what makes each axiom answer attributable to the module
  # that is named beside it.
  #
  # CORRECTED 2026-08-12: this used to justify the isolation by saying a
  # combined import "is refused by lean itself", because Proofs.RotGauge and
  # Proofs.RotMutant both declared `RotMoE.classify`. That collision has been
  # repaired -- RotMutant's is `classifyOutcome` -- and the combined import now
  # elaborates. Isolation stays because it is correct, not because a name clash
  # enforced it.
  # Falls back to the original command whenever the fast path is unavailable.
  if [ "${AXC_FAST:-0}" -eq 1 ]; then
    run_bounded 1800 env LEAN_PATH="$AXC_LEAN_PATH" lean "$P" >> "$WORK/ax.txt" 2>&1
  else
    run_bounded 1800 lake env lean "$P" >> "$WORK/ax.txt" 2>&1
  fi
  rc=$?
  if [ "$rc" -ne 0 ]; then
    note "probe for $m exited $rc -- its verdicts may be missing (the accounting check below will catch it)"
    probe_rc_bad=$((probe_rc_bad+1))
  fi
done

if [ "$total" -eq 0 ]; then
  bad "no theorems found in: $MODULES -- the sweep found nothing to classify"
  printf '\n== axiom classification: %d passed, %d failed\n' "$PASS" "$FAIL"
  exit 1
fi
note "$total theorem(s) across $(printf '%s' "$MODULES" | wc -w | tr -d ' ') module(s)"

# DISTINGUISH "the environment is not built" FROM "verdicts went missing".
#
# These look identical in the counters and mean opposite things. In a freshly
# unpacked release artifact there is no .lake and no mathlib -- nothing has been
# fetched yet -- so EVERY probe fails and nothing comes back. That is not a
# corpus with a problem; it is a corpus that has not been built, and reporting it
# as a FAILURE trains people to ignore this gate. Conversely, if some probes
# succeeded and verdicts are still short, something is genuinely wrong and must
# not be softened into a skip.
#
# SKIP is exit 3 and is NEVER a pass.
verdicts=$(grep -cE "depends on axioms|does not depend on any axioms" "$WORK/ax.txt" || true)
attempted="$probed_modules"
if [ "$verdicts" -eq 0 ] && [ "$probe_rc_bad" -ge "$attempted" ]; then
  echo
  echo "SKIP: no module could be elaborated -- every one of the $attempted probe(s) failed."
  echo "      This is what a freshly unpacked artifact looks like before SETUP_LEAN has"
  echo "      fetched a toolchain and mathlib. Build the corpus, then classify it."
  echo "      (exit 3 = SKIP, which is never a pass)"
  exit 3
fi

if [ ! -s "$WORK/ax.txt" ]; then
  bad "no axiom output at all from $total probed theorem(s)"
  printf '\n== axiom classification: %d passed, %d failed\n' "$PASS" "$FAIL"
  exit 1
fi

# --- classify -----------------------------------------------------------------
KERNEL=0; COMPILER=0; BROKEN=0; UNSEEN=0
: > "$WORK/compiler.txt"; : > "$WORK/broken.txt"

while IFS= read -r line; do
  case "$line" in
    *"depends on axioms"*|*"does not depend on any axioms"*) : ;;
    *) continue ;;
  esac
  name=$(printf '%s' "$line" | sed "s/^'\([^']*\)'.*/\1/")
  case "$line" in
    *sorryAx*)
      BROKEN=$((BROKEN+1)); printf '%s\n' "$name" >> "$WORK/broken.txt" ;;
    *native_decide*|*ofReduceBool*|*ofReduceNat*)
      COMPILER=$((COMPILER+1)); printf '%s\n' "$name" >> "$WORK/compiler.txt" ;;
    *)
      KERNEL=$((KERNEL+1)) ;;
  esac
done < "$WORK/ax.txt"

seen=$((KERNEL+COMPILER+BROKEN))
UNSEEN=$((total-seen))

echo
printf '  KERNEL   %4d  kernel-checked -- trust the kernel, nothing else\n' "$KERNEL"
printf '  COMPILER %4d  EXECUTED, not proved -- trust the compiler and the CPU\n' "$COMPILER"
printf '  BROKEN   %4d  sorryAx -- not proved at all\n' "$BROKEN"
echo

if [ "$UNSEEN" -ne 0 ]; then
  bad "$total theorem(s) were probed but only $seen verdict(s) came back -- $UNSEEN unaccounted for"
  note "an unaccounted theorem is NOT a passing theorem; the probe or the parser is wrong"
else
  ok "every one of the $total theorem(s) produced a verdict"
fi

if [ "$BROKEN" -ne 0 ]; then
  bad "$BROKEN theorem(s) depend on sorryAx -- these are NOT proved:"
  sed 's/^/        /' "$WORK/broken.txt" | head -10
else
  ok "no theorem depends on sorryAx"
fi

if [ "$COMPILER" -ne 0 ]; then
  sed 's/^/        /' "$WORK/compiler.txt" | head -10
  if [ "$ALLOW_COMPILER" = "1" ]; then
    ok "$COMPILER compiler-trusted theorem(s), PERMITTED by ROTMOE_ALLOW_COMPILER=1"
    note "these may not be counted in any headline theorem number: executed is not proved"
  else
    bad "$COMPILER theorem(s) are compiler-trusted (native_decide). Set ROTMOE_ALLOW_COMPILER=1 to permit."
  fi
else
  ok "no theorem is compiler-trusted -- the whole corpus is kernel-checked"
fi

# --- the headline count may only include KERNEL theorems ---------------------
printf '  ----  headline-eligible (KERNEL only): %d of %d\n' "$KERNEL" "$total"

# --- negative controls --------------------------------------------------------
# The classifier is worth exactly what it can catch. Each line below is fed to
# the SAME case-matching used above.
echo
echo "-- negative controls --"
classify_line () {
  case "$1" in
    *sorryAx*) echo BROKEN ;;
    *native_decide*|*ofReduceBool*|*ofReduceNat*) echo COMPILER ;;
    *"depends on axioms"*|*"does not depend on any axioms"*) echo KERNEL ;;
    *) echo NONE ;;
  esac
}
c1=$(classify_line "'Foo.bar' depends on axioms: [sorryAx]")
c2=$(classify_line "'Foo.bar' depends on axioms: [bar._native.native_decide.ax_1_1]")
c3=$(classify_line "'Foo.bar' depends on axioms: [propext, Classical.choice, Quot.sound]")
c4=$(classify_line "'Foo.bar' does not depend on any axioms")
c5=$(classify_line "'Foo.bar' depends on axioms: [Lean.ofReduceBool]")
if [ "$c1" = BROKEN ] && [ "$c2" = COMPILER ] && [ "$c3" = KERNEL ] && [ "$c4" = KERNEL ] && [ "$c5" = COMPILER ]; then
  ok "CONTROL: all 5 axiom shapes classify correctly (sorryAx, native_decide, the three sound axioms, none, ofReduceBool)"
else
  bad "CONTROL DEAD: classification is wrong -- got $c1 $c2 $c3 $c4 $c5"
fi
# A control that only proves the happy path proves nothing: the classifier must
# also REFUSE to invent a verdict for a line that is not a verdict.
if [ "$(classify_line "warning: unused variable")" = NONE ]; then
  ok "CONTROL: a non-verdict line is NOT silently counted as kernel-checked"
else
  bad "CONTROL DEAD: an unrelated line was given a class"
fi

printf '\n== axiom classification: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
