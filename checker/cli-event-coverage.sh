#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# cli-event-coverage.sh -- does the router bind EVERY event the CLI defines?
#
# THE DEFECT THIS EXISTS FOR, stated plainly because it is the reason the whole
# checker was written: RoT MoE's event list was derived by COUNTING WHICH EVENTS
# OTHER INSTALLED PLUGINS BOUND. That is a lower bound. It cannot reveal an event
# nothing on the measuring machine happens to use, and it missed twenty of the
# thirty-one the CLI actually defines -- including SubagentStart, which the
# Socio spotted by asking why there was a SubagentStop and no SubagentStart.
#
# A router that observes a subset of the lifecycle is not a router, it is a
# sampler, and every A/B this repo ran before 2026-08-08 was run against one.
#
# TWO PHASES, AND THE SECOND IS THE ONE THAT AGES WELL.
#
#   Phase A (ALWAYS RUNS, no skip): the four declarations in this repo must
#   agree with checker/cli-hook-events.txt, character for character and in
#   order -- hooks/hooks.json, ARM_ROUTER.sh, ARM_ROUTER.ps1, and the `declared`
#   list in lean/Proofs/RotEvent.lean. This needs no claude binary, so it runs
#   identically on every CI runner. There is no SKIP path in this checker.
#
#   Phase B (RUNS WHEN THE BINARY IS PRESENT): re-extract the event array from
#   the installed claude binary and compare it to the fixture. This is what
#   catches a CLI UPGRADE that adds an event -- the fixture goes stale, this
#   phase goes red, and the router gets widened. Without it the fixture is just
#   a snapshot that slowly becomes a lie.
#
# Phase B is deliberately NOT a skip when the binary is missing: a missing
# binary means the check is INAPPLICABLE on that host, and it says so and
# passes Phase A on its own merits. The distinction matters -- "the CLI is not
# here" is not the same claim as "the CLI agrees".
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$ROOT/checker/cli-hook-events.txt"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL  %s\n' "$1"; }

printf '\n== cli event coverage: does the router bind every event the CLI defines?\n\n'

[ -f "$FIXTURE" ] || { printf '  FAIL  fixture missing: %s\n' "$FIXTURE"; exit 1; }

# The fixture, comments stripped, in order.
WANT="$(grep -v '^#' "$FIXTURE" | grep -v '^[[:space:]]*$')"
WANT_CSV="$(printf '%s' "$WANT" | tr '\n' ',' | sed 's/,$//')"
WANT_N="$(printf '%s\n' "$WANT" | wc -l | tr -d ' ')"

[ "$WANT_N" -ge 31 ] || bad "fixture shrank to $WANT_N events -- a fixture that loses entries hides missing coverage"
[ "$WANT_N" -ge 31 ] && ok "fixture declares $WANT_N events (CLI 2.1.226)"

# --- Phase A.1: the plugin manifest --------------------------------------
MAN_CSV="$(node -e '
const fs=require("fs");
const h=JSON.parse(fs.readFileSync(process.argv[1],"utf8").replace(/^﻿/,""));
process.stdout.write(Object.keys(h.hooks).join(","));' "$ROOT/hooks/hooks.json" 2>/dev/null)"
if [ "$MAN_CSV" = "$WANT_CSV" ]; then
  ok "hooks/hooks.json binds all $WANT_N events, in the CLI's order"
else
  bad "hooks/hooks.json disagrees with the CLI event list"
  printf '        manifest: %s\n' "$(printf '%s' "$MAN_CSV" | cut -c1-110)"
  printf '        fixture : %s\n' "$(printf '%s' "$WANT_CSV" | cut -c1-110)"
fi

# --- Phase A.2 + A.3: both installer arms --------------------------------
SH_CSV="$(sed -n "s/^EVENTS_CSV='\\(.*\\)'\$/\\1/p" "$ROOT/ARM_ROUTER.sh" | head -1)"
if [ "$SH_CSV" = "$WANT_CSV" ]; then ok "ARM_ROUTER.sh EVENTS_CSV matches"; else bad "ARM_ROUTER.sh EVENTS_CSV disagrees with the CLI event list"; fi

PS_CSV="$(sed -n "s/^\\\$EventsCsv = '\\(.*\\)'\$/\\1/p" "$ROOT/ARM_ROUTER.ps1" | head -1)"
if [ "$PS_CSV" = "$WANT_CSV" ]; then ok "ARM_ROUTER.ps1 \$EventsCsv matches"; else bad "ARM_ROUTER.ps1 \$EventsCsv disagrees with the CLI event list"; fi

# --- Phase A.4: the Lean specification -----------------------------------
# The spec must not lag the wiring. If Lean says 31 and the manifest says 32,
# the theorems are about a product that no longer ships.
LEAN="$ROOT/lean/Proofs/RotEvent.lean"
if [ -f "$LEAN" ]; then
  LEAN_CSV="$(node -e '
const fs=require("fs");
const s=fs.readFileSync(process.argv[1],"utf8");
const m=s.match(/def declared : List String :=\s*\[([\s\S]*?)\]/);
if(!m){process.stdout.write("PARSE_FAILED");process.exit(0)}
const names=[...m[1].matchAll(/"([A-Za-z]+)"/g)].map(x=>x[1]);
process.stdout.write(names.join(","));' "$LEAN" 2>/dev/null)"
  if [ "$LEAN_CSV" = "$WANT_CSV" ]; then
    ok "lean/Proofs/RotEvent.lean declared list matches the CLI event list"
  else
    bad "the Lean spec disagrees with the CLI event list -- the theorems describe a different product"
    printf '        lean: %s\n' "$(printf '%s' "$LEAN_CSV" | cut -c1-110)"
  fi
else
  bad "lean/Proofs/RotEvent.lean is missing -- the spec cannot be checked"
fi

# --- Phase B: re-extract from the installed CLI --------------------------
printf '\n  -- phase B: the installed CLI itself\n'
CLI_BIN=""
for c in \
  "$HOME/scoop/persist/nodejs-lts/bin/node_modules/@anthropic-ai/claude-code/bin/claude.exe" \
  "$HOME/.claude/local/node_modules/@anthropic-ai/claude-code/bin/claude" \
  "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude" ; do
  [ -f "$c" ] && { CLI_BIN="$c"; break; }
done

if [ -z "$CLI_BIN" ]; then
  # NOT a skip and NOT a pass-by-default: it is an explicit statement that this
  # host cannot answer the question, printed so a reader never mistakes silence
  # for agreement.
  printf '  ----  INAPPLICABLE: no claude binary on this host, so the fixture\n'
  printf '        cannot be re-derived here. Phase A above stands on its own.\n'
else
  EXTRACT="$(grep -a -o -E '"PreToolUse","PostToolUse","PostToolUseFailure"[^]]*' "$CLI_BIN" 2>/dev/null \
             | head -1 | tr -d '"' )"
  if [ -z "$EXTRACT" ]; then
    bad "found the CLI at $CLI_BIN but could not locate its event array -- the extraction pattern may have aged"
  else
    if [ "$EXTRACT" = "$WANT_CSV" ]; then
      ok "the installed CLI's own event array matches the fixture exactly"
    else
      bad "THE CLI HAS CHANGED -- its event array no longer matches the fixture"
      printf '        cli     : %s\n' "$(printf '%s' "$EXTRACT"  | cut -c1-140)"
      printf '        fixture : %s\n' "$(printf '%s' "$WANT_CSV" | cut -c1-140)"
      printf '        This is the check working. Update checker/cli-hook-events.txt,\n'
      printf '        widen the manifest and BOTH installers, extend the Lean declared\n'
      printf '        list, and re-run. Do not edit the fixture alone to go green.\n'
    fi
  fi
fi

printf '\n== cli event coverage: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
