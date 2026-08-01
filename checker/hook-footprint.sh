#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE PLUGIN'S FOOTPRINT IN SOMEONE ELSE'S SESSION.
#
# RoT MoE IMPROVES Claude Code's default agent. It does not replace it, override
# it, or impose anything: it adds one routing line before a turn, and the model
# decides everything else exactly as it did before. The README says so in
# "It improves Claude Code -- it does not replace it".
#
# That paragraph is the kind of promise that quietly stops being true. A hook
# gains a `curl` for "just a version check"; a reminder starts shelling out to
# `lake` and suddenly a user with no Lean has a broken session; someone adds a
# tool interception because it was convenient. None of it would fail any other
# gate in this repository -- the theorems would still hold, the arms would still
# agree byte-for-byte, the installer would still round-trip.
#
# So the promise gets an instrument. Three properties of the SHIPPED hooks:
#
#   1. NO NETWORK. No curl/wget/Invoke-WebRequest/Invoke-RestMethod, no URL.
#   2. NO TOOLCHAIN DEPENDENCE. The router and reminder never invoke lake, lean
#      or leanchecker -- a user with no Lean installed must be unaffected.
#   3. THE PROMISE IS ON THE PAGE. If the README stops making the claim, this
#      checker is enforcing something nobody was told; if it makes the claim and
#      the hooks break it, the page is lying. Both directions are failures.
#
# Comments are stripped before matching. A file that EXPLAINS why it makes no
# network call must not be flagged for containing the word `curl` -- that lesson
# cost a green run on verify.yml a day ago, where a checker flagged the sentence
# documenting the very rule it was enforcing.
#
# Exit: 0 clean · 1 a promise is broken · 2 refuse.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok  () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad () { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }

HOOKS="hooks/rot-router.sh hooks/rot-router.ps1 hooks/prover-remind.sh hooks/prover-remind.ps1"
for h in $HOOKS; do [ -f "$h" ] || { echo "REFUSE: shipped hook missing: $h"; exit 2; }; done

# Strip comments so a hook may DOCUMENT what it does not do.
code_of () {
  case "$1" in
    *.ps1) sed 's/#.*$//' "$1" ;;
    *)     sed 's/#.*$//' "$1" ;;
  esac
}

NET_RE='(curl|wget|Invoke-WebRequest|Invoke-RestMethod|iwr |System\.Net|https?://)'

# COMMAND POSITION, not "the word appears". The first version matched `lake` and
# `lean` anywhere and reported all four hooks as invoking a Lean toolchain. Every
# hit was a false positive, and the shape of them is worth keeping:
#
#   STEMS_FORGE='... ship lake theorem tactic sorry mathlib .lean'   <- ROUTING DATA
#   WS=${ROTMOE_LEAN_WORKSPACE:-$HERE/../lean}                       <- a path
#   "... leanchecker disagrees with lake build ..."                  <- a MESSAGE
#
# The router's whole job is to recognise the word `lake` in a prompt; a checker
# that forbids the word forbids the feature. What must never happen is the hook
# EXECUTING lake. So: the name must sit where a command sits -- at the start of
# a statement, or after a separator, or after PowerShell's call operator.
TOOL_RE='(^|[;&|(]|&&|\|\||\$\(|`|^[[:space:]]*&[[:space:]]+)[[:space:]]*(lake|lean|leanchecker)([[:space:]]|$)'

net_bad=0; tool_bad=0
for h in $HOOKS; do
  if code_of "$h" | grep -qEi "$NET_RE"; then
    bad "$h makes (or mentions in code) a NETWORK call:"
    code_of "$h" | grep -nEi "$NET_RE" | head -3 | sed 's/^/        /'
    net_bad=1
  fi
  if code_of "$h" | grep -qE "$TOOL_RE"; then
    bad "$h invokes a Lean toolchain command -- a user with no Lean would be affected:"
    code_of "$h" | grep -nE "$TOOL_RE" | head -3 | sed 's/^/        /'
    tool_bad=1
  fi
done
[ "$net_bad"  -eq 0 ] && ok "no network call in any of the 4 shipped hooks"
[ "$tool_bad" -eq 0 ] && ok "no lake/lean invocation in any of the 4 shipped hooks (Lean stays optional)"

# --- the promise must be ON THE PAGE ----------------------------------------
promise_missing=0
grep -qi 'does not replace' README.md || { bad "README no longer says the plugin does not replace Claude Code"; promise_missing=1; }
grep -qi 'No network, ever\|makes no HTTP call\|no network call' README.md || { bad "README no longer states the no-network promise"; promise_missing=1; }
grep -qi 'No Lean required\|no Lean toolchain at all' README.md || { bad "README no longer states that Lean is optional"; promise_missing=1; }
[ "$promise_missing" -eq 0 ] && ok "README states all three promises this checker enforces"

# --- A FLAG WITHOUT ITS VALUE MUST REFUSE, NOT SPIN -------------------------
# Measured 2026-08-01: `rot-router.sh --vector` with no value ran until it was
# killed at 120 s. It looked like a stdin block and was an INFINITE LOOP -- with
# `$# = 1`, `shift 2` shifts nothing, `$1` is still `--vector`, and the `while`
# re-enters the same branch forever. Every option had it. This is the R20
# family: an argument path nothing exercised, because the hook is normally
# called with NO arguments at all.
#
# A user hits this by typing one flag and forgetting its value. A session that
# hangs is worse than one that errors, so every flag must refuse within seconds.
echo
echo "-- a flag with no value must refuse quickly --"
spin=0
for f in --vector --breadth --M --C --T --route; do
  timeout 10 bash hooks/rot-router.sh "$f" </dev/null >/dev/null 2>&1
  rc=$?
  case "$rc" in
    2) : ;;
    124) bad "rot-router.sh $f HANGS (killed at 10 s) -- a hung hook stalls the user's turn"; spin=1 ;;
    0)   bad "rot-router.sh $f exits 0 with no value -- it silently did something"; spin=1 ;;
    *)   bad "rot-router.sh $f exits $rc; expected 2 (refuse)"; spin=1 ;;
  esac
done
[ "$spin" -eq 0 ] && ok "all 6 POSIX flags refuse with exit 2 when their value is missing"

if command -v pwsh >/dev/null 2>&1; then
  timeout 30 pwsh -NoProfile -File hooks/rot-router.ps1 -Vector </dev/null >/dev/null 2>&1
  rc=$?
  # The arms are NOT required to agree on the code here, and pretending they do
  # would be the overclaim: PowerShell rejects a parameter with no argument at
  # BINDING time and exits 1, while the POSIX arm reaches our own usage branch
  # and exits 2. What must agree is the OBSERVABLE the user cares about --
  # neither hangs, neither pretends to succeed.
  if [ "$rc" -eq 124 ]; then
    bad "rot-router.ps1 -Vector HANGS (killed at 30 s)"
  elif [ "$rc" -eq 0 ]; then
    bad "rot-router.ps1 -Vector exits 0 with no value"
  else
    ok "rot-router.ps1 refuses a valueless flag too (exit $rc, non-zero and prompt)"
  fi
else
  echo "  NOTE  pwsh absent -- the Windows arm's flag handling is NOT checked here (this is a gap, not a pass)"
fi

# The gauge itself must still work, or "it refuses everything" would pass above.
if timeout 20 bash hooks/rot-router.sh --vector 1,0,0,0,0,0,0,0,1 --breadth 2 2>/dev/null | grep -q 'R/s+'; then
  ok "the gauge still answers with real arguments -- the refusal did not eat the feature"
else
  bad "the gauge no longer answers with valid arguments"
fi

# --- CONTROLS: each assertion must be able to fail ---------------------------
echo
echo "-- negative controls --"
CTL=$(mktemp -d); trap 'rm -rf "$CTL"' EXIT

cp hooks/rot-router.sh "$CTL/net.sh"
printf 'curl -s https://example.invalid/ping >/dev/null\n' >> "$CTL/net.sh"
if sed 's/#.*$//' "$CTL/net.sh" | grep -qEi "$NET_RE"; then
  ok "CONTROL: a planted curl IS detected"
else
  bad "CONTROL DEAD: a planted network call is invisible"
fi

cp hooks/rot-router.sh "$CTL/tool.sh"
printf 'lake build Proofs.RotGauge >/dev/null\n' >> "$CTL/tool.sh"
if sed 's/#.*$//' "$CTL/tool.sh" | grep -qE "$TOOL_RE"; then
  ok "CONTROL: a planted lake invocation IS detected"
else
  bad "CONTROL DEAD: a planted lake invocation is invisible"
fi

# The other direction, and it is the one that keeps this checker honest: a hook
# that merely TALKS about curl or Lean in a comment must stay clean, or the
# first person to document the rule gets a red build and deletes the rule.
cp hooks/rot-router.sh "$CTL/comment.sh"
printf '# this hook never calls curl, wget or lake -- see checker/hook-footprint.sh\n' >> "$CTL/comment.sh"
if sed 's/#.*$//' "$CTL/comment.sh" | grep -qEi "$NET_RE|$TOOL_RE"; then
  bad "CONTROL: a COMMENT mentioning curl/lake is flagged -- the checker punishes documentation"
else
  ok "CONTROL: a comment mentioning curl and lake is NOT flagged"
fi

printf '\n== hook footprint: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
