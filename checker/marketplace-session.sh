#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# ---------------------------------------------------------------------------
# marketplace-session.sh -- INSTALL THE PLUGIN THE WAY A STRANGER DOES, then
# prove the router is in the loop of a real session.
#
# THE GAP THIS CLOSES, stated exactly. The repository already had four live
# gates -- live-session-smoke, release-session, plugin-install, longsession --
# and every one of them ARMS THE ROUTER ITSELF by writing a scratch
# settings.json. They prove the router works when THEY wire it. Not one of them
# ran `claude plugin marketplace add` + `claude plugin install`, so nothing ever
# exercised the registration in hooks/hooks.json.
#
# I first reported this as a shipped defect -- that the plugin had gone out with
# a dead router. That was WRONG and the retraction belongs here rather than in a
# commit nobody re-reads: measured against 59b2620 in a real marketplace install,
# the shipped registration routed FORGE, EMPATHIC and CLINICAL correctly. What is
# true is narrower and still worth a gate: no test ever used the marketplace path
# at all, so a registration that genuinely broke would have shipped green.
#
# INSTRUMENT CHOICE MATTERS HERE. Asking the model to quote its own context is
# NOT a valid instrument: measured 5 runs, the model answered ABSENT once and
# the marker four times while the hook produced output every single time. The
# harness debug log records what the hook actually returned, so THAT is what
# this gate reads. A model-mediated observable would have made this test flaky
# and the flakiness would eventually have been "fixed" by deleting it.
#
# Exit: 0 pass, 1 fail, 2 refuse, 3 SKIP (never a pass).
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok   () { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad  () { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
skip () { printf '  SKIP  %s\n' "$1"; }

echo "== marketplace session: install as a stranger, prove the router runs =="

command -v claude >/dev/null 2>&1 || { skip "no claude CLI on PATH -- cannot test the install path"; exit 3; }
SRC_CRED="${CLAUDE_CRED_SRC:-$HOME/.claude/.credentials.json}"
[ -f "$SRC_CRED" ] || { skip "no credentials to clone -- a real session needs auth (CI has none)"; exit 3; }

BOUND=""
command -v timeout >/dev/null 2>&1 && BOUND="timeout"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/mktsess.XXXXXX")"
# node and the shell disagree about /d/... vs D:/..., so hand the CLI a path it
# resolves the same way it will resolve its own config.
WORKWIN="$WORK"
case "$WORK" in /?/*) d=$(printf "%s" "$WORK" | cut -c2 | tr "a-z" "A-Z"); WORKWIN="$d:$(printf "%s" "$WORK" | cut -c3-)" ;; esac
cleanup () { rm -rf "$WORK"; }
trap cleanup EXIT
cp "$SRC_CRED" "$WORK/.credentials.json" 2>/dev/null || { skip "could not clone credentials"; exit 3; }
export CLAUDE_CONFIG_DIR="$WORKWIN"

run () { if [ -n "$BOUND" ]; then timeout "$@"; else shift; "$@"; fi; }

# --- install exactly as documented ------------------------------------------
run 240 claude plugin marketplace add "$REPO" > "$WORK/add.log" 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "marketplace add accepted the repository" \
                || { bad "marketplace add failed (exit $rc): $(tail -1 "$WORK/add.log")"; }
run 240 claude plugin install rot-moe@rot-moe > "$WORK/inst.log" 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "plugin install succeeded" \
                || bad "plugin install failed (exit $rc): $(tail -1 "$WORK/inst.log")"

# --- a real session, read from the HARNESS log, not from the model ----------
marker_runs=0; tries=3
for i in $(seq 1 "$tries"); do
  rm -f "$WORK/debug/"*.txt 2>/dev/null
  run 300 claude -p "say only: ok" --debug < /dev/null > "$WORK/sess$i.log" 2>&1
  L="$(ls -t "$WORK"/debug/*.txt 2>/dev/null | head -1)"
  [ -n "$L" ] || continue
  hit=$(grep -c "RoT MoE :: TIER" "$L" 2>/dev/null || true)
  [ "${hit:-0}" -ge 1 ] && marker_runs=$((marker_runs+1))
done
[ "$marker_runs" -eq "$tries" ] \
  && ok "the router marker reached the session in $marker_runs of $tries runs (harness log, not the model)" \
  || bad "the router marker appeared in only $marker_runs of $tries runs -- the plugin does not reliably wire the router"

# --- NEGATIVE CONTROL: disable the plugin, the marker must vanish -----------
# Without this the test could be passing on a marker that comes from anywhere
# else in the environment.
run 120 claude plugin disable rot-moe > "$WORK/dis.log" 2>&1
rm -f "$WORK/debug/"*.txt 2>/dev/null
run 300 claude -p "say only: ok" --debug < /dev/null > "$WORK/off.log" 2>&1
L="$(ls -t "$WORK"/debug/*.txt 2>/dev/null | head -1)"
offhit=$(grep -c "RoT MoE :: TIER" "${L:-/dev/null}" 2>/dev/null || true)
[ "${offhit:-0}" -eq 0 ] \
  && ok "CONTROL: with the plugin disabled the marker is GONE -- the plugin is what causes it" \
  || bad "CONTROL DEAD: the marker survived disabling the plugin -- it comes from somewhere else"

printf '\n== marketplace-session: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
