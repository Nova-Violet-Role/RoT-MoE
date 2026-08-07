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
# Exit: 0 pass, 1 fail, 2 refuse, 3 SKIP no credentials, 4 SKIP no CLI.
# 3 and 4 are both skips and NEITHER is ever a pass -- but they are different
# skips, and the workflow treats them differently: 4 is a hard failure in any
# job that installed the CLI. See the block at the CLI check for why.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok   () { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad  () { FAIL=$((FAIL+1)); [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=marketplace-session::%s\n' "$*"; printf '  FAIL  %s\n' "$1"; }
skip () { printf '  SKIP  %s\n' "$1"; }

echo "== marketplace session: install as a stranger, prove the router runs =="

# TWO CAUSES, TWO EXIT CODES. Both of these used to exit 3, and the workflow
# printed "SKIP (3): no credentials on the runner" for either -- so a run where
# the CLI was simply absent was filed in the log under a cause that had not been
# tested. Measured on run 31187881399, the lean job printed BOTH lines at once:
#
#   SKIP  no claude CLI on PATH -- cannot test the install path
#   SKIP (3): no credentials on the runner -- never counted as a pass
#
# That is the same defect class as the twelve fake RotGauge kills: a real
# condition reported under the wrong cause, in a way that reads as understood.
# A skip is only honest if it names the thing that was actually missing.
#
#   3 = no credentials. A DECIDED BOUNDARY (ci.yml:737) -- credentials never go
#       in repository secrets, so this can never be closed on a public runner
#       and is enforced locally and in CTT instead.
#   4 = no CLI. NOT a boundary, an environment gap. Any job that installs the
#       CLI can close it, and a job that installed it and still gets 4 has a
#       BROKEN INSTALL and must fail rather than skip.
command -v claude >/dev/null 2>&1 || {
  skip "no claude CLI on PATH -- cannot test the install path (exit 4, NOT a credential skip)"
  exit 4
}
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

# --- the lane table: prompt -> the lane the router must choose ---------------
# WHY THE LANE AND NOT JUST THE MARKER. This gate used to run the same prompt
# three times and assert only that SOME marker appeared. A router hard-wired to
# emit one constant lane passed it, which means it tested wiring and called the
# result routing. The lane is the thing the plugin is FOR, so the lane is what
# gets asserted.
lane_table () {
cat <<'TBL'
lake build the theorem|FORGE
debug this error in the parser|CLINICAL
i feel lost and tired today|EMPATHIC
decide now, urgent|EXECUTIVE
plan the roadmap and priorities|STRATEGIC
invent something surreal|CREATIVE
what is the future trend|PREDICTIVE
compress these tokens|STEALTH
refactor the meta architecture|RECURSIVE
hello there|CONVERGENT
TBL
}

# --- every lane, against the INSTALLED copy (not the working tree) -----------
# Cheap and exhaustive: this proves the artifact the marketplace actually
# delivered maps each prompt to the right lane. It cannot prove the harness
# calls it -- the live sessions below do that -- so neither check replaces the
# other.
INST="$(find "$WORK" -name rot-router.sh -path '*hooks*' 2>/dev/null | head -1)"
if [ -z "$INST" ]; then
  bad "no rot-router.sh under the installed plugin -- the marketplace delivered no router"
else
  ok "installed router located at ${INST#$WORK/}"
  lbad=0; ltot=0
  while IFS='|' read -r prompt expect; do
    [ -n "$prompt" ] || continue
    ltot=$((ltot+1))
    got=$(run 30 bash "$INST" --route "$prompt" 2>/dev/null | grep -oE '^[A-Z]+' | head -1)
    [ "$got" = "$expect" ] || { lbad=$((lbad+1)); printf '        lane MISMATCH: %-38s expected %-11s got %s\n' "$prompt" "$expect" "${got:-<none>}"; }
  done <<EOF
$(lane_table)
EOF
  [ "$ltot" -ge 10 ] || bad "the lane table shrank to $ltot rows -- a table that covers fewer lanes proves less"
  [ "$lbad" -eq 0 ] \
    && ok "installed router: all $ltot lanes routed correctly" \
    || bad "installed router: $lbad of $ltot lanes routed to the wrong lane"
fi

# --- real sessions: the lane must arrive, and it must VARY ------------------
# Read from the HARNESS debug log, never from the model. Sessions are slow, so
# the default walks a spread of four distinct lanes; ROTMOE_LANES_FULL=1 walks
# all ten. The full sweep was measured 10/10 on 2026-08-03 -- the subset exists
# to keep the gate runnable, not because four lanes is the claim.
if [ "${ROTMOE_LANES_FULL:-0}" = "1" ]; then
  LIVE="$(lane_table)"
else
  LIVE="$(lane_table | sed -n '1p;3p;8p;10p')"
fi
tries=0; marker_runs=0; lane_ok=0; seen=""
while IFS='|' read -r prompt expect; do
  [ -n "$prompt" ] || continue
  tries=$((tries+1))
  rm -f "$WORK/debug/"*.txt 2>/dev/null
  run 300 claude -p "$prompt -- reply only: ok" --debug < /dev/null > "$WORK/sess$tries.log" 2>&1
  L="$(ls -t "$WORK"/debug/*.txt 2>/dev/null | head -1)"
  [ -n "$L" ] || continue
  got=$(grep -ho 'RoT MoE :: TIER 1 -> [A-Za-z]*' "$L" 2>/dev/null | head -1 | sed 's/.*-> //')
  [ -n "$got" ] && marker_runs=$((marker_runs+1))
  if [ "$got" = "$expect" ]; then
    lane_ok=$((lane_ok+1))
    case "$seen" in *"|$got|"*) : ;; *) seen="$seen|$got|" ;; esac
  else
    printf '        live lane MISMATCH: %-34s expected %-11s got %s\n' "$prompt" "$expect" "${got:-<NO MARKER>}"
  fi
done <<EOF
$LIVE
EOF
[ "$marker_runs" -eq "$tries" ] \
  && ok "the router marker reached the session in $marker_runs of $tries runs (harness log, not the model)" \
  || bad "the router marker appeared in only $marker_runs of $tries runs -- the plugin does not reliably wire the router"
[ "$lane_ok" -eq "$tries" ] \
  && ok "every live session routed to its expected lane ($lane_ok of $tries)" \
  || bad "only $lane_ok of $tries live sessions routed to the expected lane"
distinct=$(printf '%s' "$seen" | tr '|' '\n' | grep -c '[A-Z]' || true)
[ "${distinct:-0}" -ge 3 ] \
  && ok "CONTROL: the live lane VARIED across $distinct distinct lanes -- not a constant" \
  || bad "CONTROL DEAD: only ${distinct:-0} distinct live lane(s) -- a constant-lane router would pass this"

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
