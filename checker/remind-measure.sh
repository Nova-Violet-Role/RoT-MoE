#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# REMIND MEASURE -- the half of the reminder that had no instrument.
#
# `checker/cross-diff-remind.sh` compares the two arms' DECISION over a corpus,
# and its own header says what it does not cover:
#
#     "What --decide does not cover -- that both arms measure the same things off
#      disk -- is stated in the README boundary rather than implied by this
#      green."
#
# THAT UNCOVERED HALF IS WHERE TWO DEFECTS LIVED, in both arms simultaneously,
# for weeks, with 29 gates green:
#
#   * the proof scan was ONE LEVEL DEEP (`"$PROOFS_DIR"/*.lean`, and
#     `Get-ChildItem -Filter '*.lean'` with no -Recurse). Measured on a real
#     tree: 2947 minutes stale one level deep, 54 minutes recursive -- a 55x
#     error, while eighteen modules were being written into a subfolder;
#   * the workspace chain had a step NOTHING WROTE (only SETUP_LEAN writes the
#     recorded file, so a marketplace install always fell through to the
#     plugin's own read-only corpus).
#
# A documented boundary is a place defects live. So the arms now expose their
# measurement (`--measure` / `-Measure`, `--workspace` / `-Workspace`) and this
# gate drives BOTH over ONE fixture tree.
#
# THE FIXTURE HAS A NESTED PROOF ON PURPOSE. A flat fixture would pass against
# the defective scan -- which is exactly how the defect survived to a live
# install. lean/Proofs/RotScan.lean states the general rule
# (`flat_never_underreports`, `flat_gap_is_real`); this measures the shipped code.
#
# THE COMPARISON: count and name are compared EXACTLY (they do not move with the
# wall clock); minutes is allowed one minute of drift, because the two arms are
# two processes and a minute boundary can fall between them. Anything tighter
# would be a flaky gate, and a flaky gate gets disabled, which is worse.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

SH="hooks/prover-remind.sh"
PS1="hooks/prover-remind.ps1"

pass=0; fail=0; skip=0
ok()   { echo "  PASS  $*"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $*"; fail=$((fail+1)); }

echo "== remind measure: both arms, one tree, including a NESTED proof =="

TMP="$(mktemp -d "${TMPDIR:-/tmp}/rotmeas.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# --- the fixture -------------------------------------------------------------
# Root proof written FIRST, nested proof written SECOND, so the newest file is
# the one only a recursive scan can see. That ordering is the whole test.
WS="$TMP/ws"
mkdir -p "$WS/Proofs/Subject"
printf 'name = "fixture"\n' > "$WS/lakefile.toml"
printf 'theorem root_one : True := trivial\n'   > "$WS/Proofs/RootProof.lean"
sleep 1
printf 'theorem nested_one : True := trivial\n' > "$WS/Proofs/Subject/NestedProof.lean"

STATE="$TMP/nostate"     # a state dir with no recorded workspace

# --- 1. the POSIX arm sees the nested proof ----------------------------------
sh_out="$(ROTMOE_LEAN_WORKSPACE="$WS" ROTMOE_STATE_DIR="$STATE" sh "$SH" --measure 2>/dev/null)"
sh_count="$(printf '%s' "$sh_out" | awk '{print $1}')"
sh_mins="$(printf '%s'  "$sh_out" | awk '{print $2}')"
sh_name="$(printf '%s'  "$sh_out" | awk '{print $3}')"

[ "$sh_count" = "2" ] \
  && ok "[sh] counted BOTH proofs (2) -- the scan is recursive" \
  || bad "[sh] counted $sh_count of 2 proofs -- the scan is one level deep again"
[ "$sh_name" = "NestedProof" ] \
  && ok "[sh] newest proof is the NESTED one" \
  || bad "[sh] newest proof reported as '$sh_name', expected NestedProof"

# --- 2. the PowerShell arm must agree ----------------------------------------
if command -v pwsh >/dev/null 2>&1; then
  ps_out="$(ROTMOE_LEAN_WORKSPACE="$WS" ROTMOE_STATE_DIR="$STATE" pwsh -NoProfile -File "$PS1" -Measure 2>/dev/null)"
  ps_count="$(printf '%s' "$ps_out" | awk '{print $1}')"
  ps_mins="$(printf '%s'  "$ps_out" | awk '{print $2}')"
  ps_name="$(printf '%s'  "$ps_out" | awk '{print $3}')"

  [ "$ps_count" = "2" ] \
    && ok "[ps1] counted BOTH proofs (2) -- -Recurse is present" \
    || bad "[ps1] counted $ps_count of 2 proofs -- -Recurse is missing again"
  [ "$ps_name" = "NestedProof" ] \
    && ok "[ps1] newest proof is the NESTED one" \
    || bad "[ps1] newest proof reported as '$ps_name', expected NestedProof"

  # CROSS-ARM: the thing no existing gate could see.
  [ "$sh_count" = "$ps_count" ] && [ "$sh_name" = "$ps_name" ] \
    && ok "both arms agree on count and name ($sh_count, $sh_name)" \
    || bad "the arms DISAGREE: sh='$sh_out' ps1='$ps_out'"

  d=$(( sh_mins - ps_mins )); [ "$d" -lt 0 ] && d=$(( -d ))
  [ "$d" -le 1 ] \
    && ok "both arms agree on staleness within 1 minute (sh=$sh_mins ps1=$ps_mins)" \
    || bad "staleness differs by $d minutes (sh=$sh_mins ps1=$ps_mins) -- not clock drift"
else
  echo "  SKIP  no pwsh on this runner -- the PowerShell arm was NOT measured."
  echo "        This is a SKIP, never a PASS: an unrun arm proves nothing."
  skip=1
fi

# --- 3. the workspace chain, step by step ------------------------------------
# Each step is asserted to answer WHEN IT SHOULD and to be OVERRIDDEN when
# something more specific is available. A chain whose precedence nobody tests is
# a chain that can silently reorder.
w="$(ROTMOE_LEAN_WORKSPACE="$WS" ROTMOE_STATE_DIR="$STATE" sh "$SH" --workspace 2>/dev/null | awk '{print $1}')"
[ "$w" = "env" ] && ok "[sh] an explicit ROTMOE_LEAN_WORKSPACE wins" \
                 || bad "[sh] env override did not win: got '$w'"

# RECORD IT THE WAY THE INSTALLER DOES. SETUP_LEAN.sh normalises to the
# drive-letter form because that is the only spelling BOTH arms can test --
# measured: Git Bash accepts `[ -d "D:/tmp" ]` and so does PowerShell's
# Test-Path, while `/d/tmp` works only in the shell. Writing the raw POSIX path
# here would test a fixture the installer never produces.
canon_ws () {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1" 2>/dev/null | tr '\\' '/'
  else
    printf '%s' "$1"
  fi
}
mkdir -p "$TMP/state"; canon_ws "$WS" > "$TMP/state/workspace"
w="$(ROTMOE_STATE_DIR="$TMP/state" sh "$SH" --workspace 2>/dev/null | awk '{print $1}')"
[ "$w" = "recorded" ] && ok "[sh] a RECORDED workspace answers when there is no override" \
                      || bad "[sh] recorded workspace ignored: got '$w'"

# Discovery: run FROM INSIDE the fixture with no state file. This is the step
# that did not exist before 0.7.0, and the one every marketplace install needs.
w="$(cd "$WS/Proofs/Subject" && ROTMOE_STATE_DIR="$STATE" sh "$REPO/$SH" --workspace 2>/dev/null | awk '{print $1}')"
[ "$w" = "discovered" ] && ok "[sh] DISCOVERY finds the workspace from a session inside it" \
                        || bad "[sh] discovery did not fire: got '$w'"

# And the fallback still exists: nowhere to discover, nothing recorded.
w="$(cd "$TMP" && ROTMOE_STATE_DIR="$STATE" sh "$REPO/$SH" --workspace 2>/dev/null | awk '{print $1}')"
[ "$w" = "bundled" ] && ok "[sh] the bundled corpus is still the last resort" \
                     || bad "[sh] fallback broken: got '$w'"

if command -v pwsh >/dev/null 2>&1; then
  w="$(ROTMOE_LEAN_WORKSPACE="$WS" ROTMOE_STATE_DIR="$STATE" pwsh -NoProfile -File "$PS1" -Workspace 2>/dev/null | awk '{print $1}')"
  [ "$w" = "env" ] && ok "[ps1] env override wins" || bad "[ps1] env override did not win: got '$w'"
  w="$(ROTMOE_STATE_DIR="$TMP/state" pwsh -NoProfile -File "$PS1" -Workspace 2>/dev/null | awk '{print $1}')"
  [ "$w" = "recorded" ] && ok "[ps1] recorded answers" || bad "[ps1] recorded ignored: got '$w'"
  # THE PARITY HOLE THIS GATE EXISTS TO CLOSE. The first attempt at the fix added
  # discovery to the POSIX arm only; Windows users would have kept the wrong
  # workspace and no cross-diff could have seen it, because --decide never
  # resolves a workspace at all.
  w="$(cd "$WS/Proofs/Subject" && ROTMOE_STATE_DIR="$STATE" pwsh -NoProfile -File "$REPO/$PS1" -Workspace 2>/dev/null | awk '{print $1}')"
  [ "$w" = "discovered" ] && ok "[ps1] DISCOVERY fires too -- the arms resolve alike" \
                          || bad "[ps1] discovery missing: got '$w' (parity hole)"

  # LEGACY STATE FILES must keep working. A machine that ran an OLDER installer
  # has a Git-Bash-form path on disk already, and an upgrade that silently stopped
  # honouring it would reintroduce the very defect this section is about --
  # quietly, on exactly the machines that had already been set up. The reader's
  # fallback is what covers them, so it gets its own assertion rather than
  # riding on the writer's fix.
  legacy="$(canon_ws "$WS" | sed -E 's#^([A-Za-z]):/#/\L\1/#')"
  case "$legacy" in
    /?/*)
      mkdir -p "$TMP/legacy"; printf '%s\n' "$legacy" > "$TMP/legacy/workspace"
      w="$(cd "$TMP" && ROTMOE_STATE_DIR="$TMP/legacy" pwsh -NoProfile -File "$REPO/$PS1" -Workspace 2>/dev/null | awk '{print $1}')"
      [ "$w" = "recorded" ] \
        && ok "[ps1] a LEGACY POSIX-form recorded path ($legacy) still resolves" \
        || bad "[ps1] legacy recorded path '$legacy' was discarded: got '$w'"
      ;;
    *) echo "  SKIP  no drive-letter paths on this platform -- legacy form not applicable"; skip=1 ;;
  esac
fi

# --- 4. THE NEGATIVE CONTROL -------------------------------------------------
# A gate that cannot go red proves nothing. A flat tree with ONE proof must not
# report 2, and an empty tree must report the -1 sentinel rather than inventing
# a measurement.
FLAT="$TMP/flat"; mkdir -p "$FLAT/Proofs"
printf 'name = "flat"\n' > "$FLAT/lakefile.toml"
printf 'theorem only_one : True := trivial\n' > "$FLAT/Proofs/Only.lean"
c="$(ROTMOE_LEAN_WORKSPACE="$FLAT" ROTMOE_STATE_DIR="$STATE" sh "$SH" --measure 2>/dev/null | awk '{print $1}')"
[ "$c" = "1" ] && ok "CONTROL: a flat tree with one proof counts 1, not 2" \
               || bad "CONTROL: flat tree counted $c -- the counter is not counting"

EMPTY="$TMP/empty"; mkdir -p "$EMPTY/Proofs"
printf 'name = "empty"\n' > "$EMPTY/lakefile.toml"
m="$(ROTMOE_LEAN_WORKSPACE="$EMPTY" ROTMOE_STATE_DIR="$STATE" sh "$SH" --measure 2>/dev/null)"
case "$m" in
  "0 -1 -") ok "CONTROL: an empty tree reports the -1 sentinel, not a fabricated age" ;;
  *) bad "CONTROL: empty tree measured '$m', expected '0 -1 -'" ;;
esac

echo
echo "  $pass passed, $fail failed, $skip skipped"
if [ "$fail" -gt 0 ]; then echo "  remind-measure: FAIL"; exit 1; fi
echo "  remind-measure: PASS"
exit 0
