#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# install-parity.sh -- the two install paths must deliver the SAME product.
#
# THE DEFECT THIS EXISTS FOR, measured 2026-08-05.
#
# RoT MoE can be installed two ways, and both are documented:
#
#   marketplace/plugin  -> hooks/hooks.json registers the hooks
#   ARM_ROUTER.sh/.ps1  -> writes entries into ~/.claude/settings.json
#
# They had silently diverged:
#
#   plugin     : 3 events, 5 bindings (rot-router x2, prover-remind x3)
#   ARM_ROUTER : 2 events, 2 bindings (rot-router only)
#
# A grep for `prover-remind` across ARM_ROUTER.sh, ARM_ROUTER.ps1, SETUP_LEAN.sh
# and hooks/settings-merge.js returned NOTHING -- no installer had ever wired it.
# So a hand install produced a product missing the entire proof-reminder organ,
# including the only PostToolUse binding, and no check in the repository could
# see it: every installer test asserted things about the ROUTER, which was
# present, and nothing compared the two paths to each other.
#
# WHAT THIS CHECKS, and why it is stated this way.
#
# Not "there are five bindings" -- that is a snapshot, and it would go red the
# day a tenth hook is added correctly. The invariant is the RELATIONSHIP:
#
#   the set of (event, script) pairs the PLUGIN registers
#   ==
#   the set of (event, script) pairs ARM_ROUTER writes
#
# Add a hook to hooks.json and this fails until the installer learns it; add it
# to the installer and it fails until the plugin declares it. Either direction
# is caught, which is the only version of this check worth having.
# =============================================================================
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
ok  () { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad () { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }

echo "== install parity: plugin registration vs ARM_ROUTER =="

command -v node >/dev/null 2>&1 || { echo "SKIP: node is required"; exit 3; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/rotmoe-parity.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

# --- 1. what the PLUGIN registers -------------------------------------------
# Keyed by (event, script basename). The PATH is deliberately NOT compared: the
# plugin resolves through ${CLAUDE_PLUGIN_ROOT} and the installer writes an
# absolute path, so demanding identical strings would fail for a reason that has
# nothing to do with which hooks run.
node -e '
const h = require(process.argv[1]);
const out = [];
for (const [ev, arr] of Object.entries(h.hooks || h)) {
  for (const g of (arr || [])) {
    for (const hk of (g.hooks || [])) {
      const m = String(hk.command || "").match(/([\w-]+)\.(sh|ps1)/g) || [];
      for (const f of new Set(m.map(x => x.replace(/\.(sh|ps1)$/, "")))) out.push(ev + " " + f);
    }
  }
}
process.stdout.write([...new Set(out)].sort().join("\n") + "\n");
' "$REPO/hooks/hooks.json" > "$WORK/plugin.txt" 2>"$WORK/plugin.err"

if [ ! -s "$WORK/plugin.txt" ]; then
  bad "could not read the plugin's hook registrations from hooks/hooks.json"
  sed 's/^/        /' "$WORK/plugin.err" | head -5
  printf '\n== install parity: %d passed, %d failed\n' "$PASS" "$FAIL"
  exit 1
fi
ok "plugin registrations read: $(wc -l < "$WORK/plugin.txt" | tr -d ' ') (event, script) pair(s)"

# --- 2. what ARM_ROUTER writes ----------------------------------------------
mkdir -p "$WORK/home/.claude"
CLAUDE_DIR="$WORK/home/.claude" sh "$REPO/ARM_ROUTER.sh" > "$WORK/arm.log" 2>&1
ARM_RC=$?
if [ "$ARM_RC" -ne 0 ]; then
  bad "ARM_ROUTER.sh exited $ARM_RC on a clean config"
  sed 's/^/        /' "$WORK/arm.log" | head -8
fi

if [ ! -f "$WORK/home/.claude/settings.json" ]; then
  bad "ARM_ROUTER.sh wrote no settings.json -- nothing to compare"
  printf '\n== install parity: %d passed, %d failed\n' "$PASS" "$FAIL"
  exit 1
fi

node -e '
const s = require(process.argv[1]);
const out = [];
for (const [ev, arr] of Object.entries(s.hooks || {})) {
  for (const g of (arr || [])) {
    for (const hk of (g.hooks || [])) {
      const m = String(hk.command || "").match(/([\w-]+)\.(sh|ps1)/g) || [];
      for (const f of new Set(m.map(x => x.replace(/\.(sh|ps1)$/, "")))) out.push(ev + " " + f);
    }
  }
}
process.stdout.write([...new Set(out)].sort().join("\n") + "\n");
' "$WORK/home/.claude/settings.json" > "$WORK/armed.txt"
ok "ARM_ROUTER registrations read: $(wc -l < "$WORK/armed.txt" | tr -d ' ') (event, script) pair(s)"

# --- 3. THE COMPARISON -------------------------------------------------------
if diff -u "$WORK/plugin.txt" "$WORK/armed.txt" > "$WORK/diff.txt" 2>&1; then
  ok "THE TWO INSTALL PATHS REGISTER THE SAME (event, script) SET"
else
  bad "INSTALL PATHS DIVERGE -- one way to install gives a different product:"
  sed 's/^/        /' "$WORK/diff.txt" | head -20
  echo "        (< only the plugin registers it · > only ARM_ROUTER writes it)"
fi

# Every event the plugin uses must be reachable by the installer. Stated
# separately because a missing EVENT is the failure that hides best: the hooks
# that do exist keep working, so nothing looks broken.
for _ev in $(cut -d' ' -f1 "$WORK/plugin.txt" | sort -u); do
  if grep -q "^$_ev " "$WORK/armed.txt"; then
    ok "event reachable by the installer: $_ev"
  else
    bad "event NOT wired by ARM_ROUTER: $_ev (the plugin binds it)"
  fi
done

# --- 4. the uninstaller must reach everything the installer wrote ------------
# Parity is not only about arming. An installer that writes what its uninstaller
# cannot remove strands the user, and that is a defect this repository has
# already shipped once.
CLAUDE_DIR="$WORK/home/.claude" sh "$REPO/DISARM_ROUTER.sh" > "$WORK/disarm.log" 2>&1
DIS_RC=$?
LEFT=$(grep -cE 'rot-router|prover-remind' "$WORK/home/.claude/settings.json" 2>/dev/null || true)
if [ "$DIS_RC" -eq 0 ] && [ "${LEFT:-0}" -eq 0 ]; then
  ok "DEFAULT (exact) uninstall removed every entry ARM_ROUTER wrote"
else
  bad "exact uninstall left ${LEFT:-?} entr(ies) behind (exit $DIS_RC) -- residue the user cannot remove"
fi

# --- 5. NEGATIVE CONTROL -----------------------------------------------------
# A comparison that cannot fail proves nothing. Drop one pair from the plugin
# side and the diff must go red.
head -n -1 "$WORK/plugin.txt" > "$WORK/plugin.short.txt"
if diff -q "$WORK/plugin.short.txt" "$WORK/armed.txt" >/dev/null 2>&1; then
  bad "CONTROL DEAD: removing a registration did not change the comparison"
else
  ok "CONTROL: removing one registration IS detected"
fi

printf '\n== install parity: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
