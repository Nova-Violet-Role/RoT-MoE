#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# CONTEXT GATE -- a hook wired to an event may not speak on it
#
# WHAT THIS BINDS. Proofs/RotInject.lean proves that no event outside the
# accepting set can emit `hookSpecificOutput.additionalContext`. That is a
# theorem about a MODEL. This checker is the part that makes it a claim about
# the shipped code: it reads the accepting set out of the Lean source and
# compares it to the arrays the shell/PowerShell hooks actually branch on.
# Without this file, RotInject.lean would be a decorative proof about a list
# that no program reads.
#
# WHY IT EXISTS. Measured 2026-08-09, live:
#     SessionEnd hook [...rot-lean-inject.ps1 -Event *] failed:
#     Hook JSON output validation failed - (root): Invalid input
# Wiring every hook to all 31 CLI events made three of them emit context on
# events whose schema does not accept it -- roughly 25 invalid payloads per
# session, each one logged as a hook failure.
#
# THREE PHASES, NONE OF WHICH MAY SKIP.
#   A  the repo's OWN hooks: any file emitting additionalContext must gate it.
#      Portable, no CLI and no user profile needed, so it runs everywhere.
#   B  the Lean accepting set is a subset of the 31 real events.
#   C  the three global hooks, IF PRESENT: their $ctxEvents array must equal the
#      Lean set exactly. Absent (a CI runner, another machine) prints
#      INAPPLICABLE, which is neither a pass nor a skip -- it states that the
#      artifact is not here, and phases A and B still had to pass.
#
# SELF-CONTROL. Phase D feeds the detector a file it MUST reject. An alarm
# nobody has tripped on purpose is an untested alarm, and this repo has shipped
# two of those already.
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

pass=0; fail=0; inapp=0

ok()   { pass=$((pass+1)); printf 'PASS %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
note() { inapp=$((inapp+1)); printf 'INAPPLICABLE %s\n' "$1"; }

LEANF="lean/Proofs/RotInject.lean"
EVENTS="checker/cli-hook-events.txt"

[ -f "$LEANF" ] || { echo "FATAL: $LEANF missing -- the accepting set has no source of truth"; exit 2; }
[ -f "$EVENTS" ] || { echo "FATAL: $EVENTS missing -- cannot check the set against real events"; exit 2; }

# --- read the accepting set out of the Lean source --------------------------
# Taken from `def accepting : List String :=` up to the closing bracket, so the
# Lean file is the single definition and this script never restates it.
lean_set=$(awk '
  /^def accepting : List String :=/ { grab=1; next }
  grab { print; if (/\]/) exit }
' "$LEANF" | grep -oE '"[A-Za-z]+"' | tr -d '"' | sort)

lean_n=$(printf '%s\n' "$lean_set" | grep -c .)
if [ "$lean_n" -lt 1 ]; then
  bad "could not parse the accepting set out of $LEANF (found $lean_n entries)"
else
  ok "accepting set parsed from $LEANF: $lean_n event(s)"
fi

# =============================================================================
# PHASE A -- the repo's own hooks must gate what they emit
# =============================================================================
# The router currently emits NO additionalContext at all, which is why it never
# hit this defect. That is a property worth locking down: if a future change
# starts injecting context, it must arrive with a gate in the same commit.
emitters=0
ungated=0
for f in hooks/*.sh hooks/*.ps1; do
  [ -f "$f" ] || continue
  if grep -qF 'additionalContext' "$f"; then
    emitters=$((emitters+1))
    if grep -qE 'ctxEvents|CTX_EVENTS' "$f"; then
      ok "phase A: $f emits context AND carries a gate"
    else
      ungated=$((ungated+1))
      bad "phase A: $f emits additionalContext with NO event gate -- it will emit schema-invalid JSON on every non-accepting event it is wired to"
    fi
  fi
done
if [ "$emitters" -eq 0 ]; then
  ok "phase A: no repo hook emits additionalContext (structurally immune to the SessionEnd defect)"
fi

# =============================================================================
# PHASE B -- every accepting event is a real dispatched event
# =============================================================================
# A typo here disables a working lane silently: the hook keeps running, emits
# nothing, and no error is logged anywhere.
missing=""
while read -r e; do
  [ -n "$e" ] || continue
  if ! grep -qxF "$e" "$EVENTS"; then
    missing="$missing $e"
  fi
done <<< "$lean_set"
if [ -n "$missing" ]; then
  bad "phase B: accepting set names event(s) the CLI does not dispatch:$missing"
else
  ok "phase B: all $lean_n accepting events appear in $EVENTS"
fi

# The complement must be non-empty, or the gate is not gating anything.
total_events=$(grep -cE '^[A-Za-z]+$' "$EVENTS")
if [ "$lean_n" -ge "$total_events" ]; then
  bad "phase B: accepting set ($lean_n) covers every dispatched event ($total_events) -- the gate would refuse nothing"
else
  ok "phase B: $((total_events - lean_n)) of $total_events events are refused by the gate"
fi

# =============================================================================
# PHASE C -- the installed global hooks, if this machine has them
# =============================================================================
TOOLS="${ROTMOE_TOOLS_DIR:-$HOME/.claude/tools}"
checked=0
for rel in sanctum/rot-lean-inject.ps1 sanctum/lean4-prover-remind.ps1 sanctum/rootcause-trace.ps1; do
  f="$TOOLS/$rel"
  if [ ! -f "$f" ]; then
    note "phase C: $rel not present on this machine"
    continue
  fi
  checked=$((checked+1))
  if ! grep -qF '$ctxEvents' "$f"; then
    bad "phase C: $rel emits context but has no \$ctxEvents gate"
    continue
  fi
  # Extract the array and compare as SETS, so a reordering is not a failure but
  # a changed membership is.
  ps_set=$(grep -F '$ctxEvents = @(' "$f" | grep -oE "'[A-Za-z]+'" | tr -d "'" | sort)
  if [ "$ps_set" = "$lean_set" ]; then
    ok "phase C: $rel gate matches the Lean accepting set exactly"
  else
    bad "phase C: $rel gate DIFFERS from the Lean accepting set"
    printf '     lean: %s\n' "$(printf '%s' "$lean_set" | tr '\n' ' ')"
    printf '     ps1 : %s\n' "$(printf '%s' "$ps_set"  | tr '\n' ' ')"
  fi
done
[ "$checked" -eq 0 ] && note "phase C: no gated global hook found under $TOOLS (phases A and B still applied)"

# =============================================================================
# PHASE D -- the control: this detector must reject a file it should reject
# =============================================================================
# Two synthetic hooks, one broken and one correct. If the broken one passes, the
# phase A detector is decoration and every PASS above is worthless.
ctl=$(mktemp -d "${TMPDIR:-/tmp}/ctxgate.XXXXXX")
printf '%s\n' 'echo "{\"hookSpecificOutput\":{\"additionalContext\":\"x\"}}"' > "$ctl/broken.sh"
printf '%s\n' 'ctxEvents="PreToolUse PostToolUse"' 'echo "{\"hookSpecificOutput\":{\"additionalContext\":\"x\"}}"' > "$ctl/gated.sh"

_detect() {  # 1 = would be flagged, 0 = would pass
  if grep -qF 'additionalContext' "$1" && ! grep -qE 'ctxEvents|CTX_EVENTS' "$1"; then echo 1; else echo 0; fi
}
d_broken=$(_detect "$ctl/broken.sh")
d_gated=$(_detect "$ctl/gated.sh")
rm -rf "$ctl"

if [ "$d_broken" -eq 1 ] && [ "$d_gated" -eq 0 ]; then
  ok "phase D control: detector flags an ungated emitter and clears a gated one"
else
  bad "phase D control: detector is broken (ungated->$d_broken expected 1, gated->$d_gated expected 0) -- every phase A result above is meaningless"
fi

echo
echo "context gate: $pass passed, $fail failed, $inapp inapplicable"
[ "$fail" -eq 0 ] || exit 1
exit 0
