#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# env-layer.sh -- ORGAN 7's verifier: the environment layer, and the shell
# face a user is actually told to install.
#
# WHY THIS FILE EXISTS, measured 2026-08-21 and stated plainly because the
# gap is the finding: ORGAN 7 had NO verifier. Nothing in checker/ or CI had
# ever executed hooks/rot-profile.sh -- the `rot` command family README.md:576
# instructs the user to source from their shell rc. Its only recorded
# measurement was a MANUAL note in FINDINGS-8.0.1.md:330, taken by hand at
# 8.0.1 and never re-run. hooks/rot-env.{sh,ps1} fared better only by
# accident: they are sourced by the router and the gate (rot-router.sh:1483,
# rot-voice-gate.sh:68, rot-router.ps1:808, rot-voice-gate.ps1:59), so they
# ride along on somebody else's coverage.
#
# The same shape had just been found one organ over: hooks/rot-voice-gate.ps1
# had never been executed either, and shipped a bug that destroyed every seal
# in its refusal for two releases. A file no gate runs is a file that breaks
# quietly, and a documented install step that breaks quietly breaks in the
# USER's shell, not ours.
#
# hooks/rot-env.sh:21-30 declares three laws. This holds them to it:
#
#   E1  rot-profile.sh sources clean and defines `rot`   (INSTALL BROKEN)
#   E2  help and implementation agree, both directions   (ADVERTISED GHOST)
#   E3  an argument-taking form refuses without one      (SILENT SUCCESS)
#   E4  `rot env list` is exactly the DTD vocabulary     (RUNTIME DRIFT)
#   E5  LAW 1 -- a value is exported with NO expansion   (INJECTION)
#   E6  LAW 2 -- an undeclared key is refused            (VOCABULARY BREACH)
#   E7  LAW 2b -- ROTMOE_ENV is refused from a file      (LOADER HIJACK)
#   E8  LAW 3 -- an operator's explicit export wins      (OVERRIDE)
#
# E4 is deliberately NOT a restatement of voice-contract.sh D12. D12 holds the
# DTD against the SOURCE of rot-env.sh; E4 holds it against what the shipped
# `rot env list` prints AT RUNTIME. A vocabulary can be correct in the file
# and wrong in the hand.
#
# E5 through E8 would every one of them pass if the loader simply loaded
# NOTHING. That is what CONTROL 1 is for, and it is the assertion that gives
# the other four their meaning.
# =============================================================================

set -u
LC_ALL=C
export LC_ALL

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)

PASS=0
FAIL=0
ok ()  { PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"; }
bad () { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$1"; }

PROFILE="$ROOT/hooks/rot-profile.sh"
ENVLIB="$ROOT/hooks/rot-env.sh"
for _f in "$PROFILE" "$ENVLIB" "$ROOT/hooks/rot-voice.dtd"; do
  [ -r "$_f" ] || { printf 'REFUSE: %s is missing or unreadable\n' "$_f"; exit 2; }
done

WD="${TMPDIR:-/tmp}/rotmoe-env.$$"
rm -rf "$WD"; mkdir -p "$WD/proj/.rot-moe"
# Every probe runs with a private HOME and XDG root so this machine's real
# rot.env can never reach the subject under test. A checker that reads the
# operator's own configuration measures the operator, not the code.
FAKE="$WD/home"; mkdir -p "$FAKE/.config"
# CLAUDE_PLUGIN_ROOT is not decoration here. rot-env.sh:42-46 resolves the
# vocabulary from dirname "$0", then falls back to $CLAUDE_PLUGIN_ROOT/hooks;
# under `sh -c` that first path is "." and the fallback is the only one left.
# Without it the loader finds no DTD, returns 0 at :46 and does NOTHING -- and
# every refusal assertion below would then pass against a corpse. That cost one
# false reading, and CONTROL 1 is what caught it. Both real call sites are
# safe: rot-router.sh:1483 and rot-voice-gate.sh:68 source this with $0 set to
# their own path, so dirname lands in hooks/ and the DTD is found.
sandbox () {   # <shell-body> -> runs it with the env layer available, isolated
  HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" ROTMOE_ENV='' \
    CLAUDE_PLUGIN_ROOT="$ROOT" \
    sh -c ". '$ENVLIB' >/dev/null 2>&1; $1" 2>/dev/null
}

# --- E1: the documented install step actually works --------------------------
_e1=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" \
  sh -c ". '$PROFILE' >/dev/null 2>&1; echo \"rc=\$?\"; command -v rot >/dev/null 2>&1 && echo defined" 2>/dev/null)
case "$_e1" in
  *"rc=0"*defined*) ok "E1: rot-profile.sh sources clean and defines the rot command family" ;;
  *defined*)        bad "E1: rot-profile.sh defines rot but exits non-zero -- it would abort a user's shell rc" ;;
  *)                bad "E1: sourcing rot-profile.sh does not define rot -- the README's install step is broken" ;;
esac

# --- E2: help and implementation agree, BOTH directions ----------------------
# The failure this catches is the one documentation always has: a subcommand
# advertised in help that no branch implements, or a branch nobody can find.
# Advertised names are read out of `rot help` itself, so this file names no
# subcommand of its own -- the same discipline voice-contract.sh keeps with
# the DTD.
_adv=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" \
  sh -c ". '$PROFILE' >/dev/null 2>&1; rot help 2>&1" 2>/dev/null \
  | sed -n 's/^  *rot \([a-z][a-z]*\).*/\1/p' | sort -u)
if [ -z "$_adv" ]; then
  bad "E2: rot help advertises nothing parseable -- the family cannot be held to its own manual"
else
  # MEASURED, and it decides the shape of this test: rot-profile.sh:156 ends
  # its dispatch with `help|*)`. There is NO unknown-subcommand path -- an
  # unrecognised name silently prints the manual. So a ghost cannot be found
  # by looking for a complaint; it is found because it answers with help
  # itself, which is exactly what an unimplemented name does.
  _help=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" \
    sh -c ". '$PROFILE' >/dev/null 2>&1; rot help 2>&1" 2>/dev/null)
  _e2bad=0
  for _s in $_adv; do
    # `help` is the fixed point -- it must answer with help.
    [ "$_s" = help ] && continue
    # `check` is skipped, disclosed: rot-profile.sh:152 dispatches it by
    # running checker/voice-contract.sh in full, so probing it here would run
    # a sibling suite inside this one every time gate-all fires. Its dispatch
    # is not in doubt -- it is the only branch that shells out to a file this
    # checker already proves is present.
    [ "$_s" = check ] && continue
    _out=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" \
      sh -c ". '$PROFILE' >/dev/null 2>&1; rot $_s 2>&1" 2>/dev/null)
    if [ "$_out" = "$_help" ]; then
      bad "E2: rot help advertises '$_s' but invoking it just reprints the manual -- an advertised ghost"
      _e2bad=1
    fi
  done
  [ "$_e2bad" -eq 0 ] && ok "E2: every subcommand rot help advertises ($(echo $_adv | tr ' ' ',')) has a branch of its own"
fi

# --- E3: an argument-taking form refuses when given none ---------------------
# Measured cold from the 9.0.1 archive: gauge, voice and gate each print their
# usage line and exit 2. That is the contract -- a command family that returns
# 0 on a missing argument teaches the user it worked.
_e3bad=0
for _s in gauge voice gate; do
  _rc=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" \
    sh -c ". '$PROFILE' >/dev/null 2>&1; rot $_s >/dev/null 2>&1; echo \$?" 2>/dev/null)
  [ "${_rc:-0}" -ne 0 ] || { bad "E3: rot $_s returned 0 with no argument -- a silent success is a lie"; _e3bad=1; }
done
[ "$_e3bad" -eq 0 ] && ok "E3: gauge, voice and gate all refuse an empty invocation"

# --- E4: the runtime vocabulary is exactly the DTD's -------------------------
_dtd=$(sed -n 's/.*<!ENTITY ENV\.[0-9][0-9]* *"\([A-Z_][A-Z_0-9]*\).*/\1/p' "$ROOT/hooks/rot-voice.dtd" | sort -u)
_run=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" \
  sh -c ". '$PROFILE' >/dev/null 2>&1; rot env list 2>&1" 2>/dev/null \
  | sed -n 's/.*\(ROTMOE_[A-Z_0-9]*\).*/\1/p' | sort -u)
if [ -z "$_dtd" ]; then
  bad "E4: the DTD declares no ENV entities -- the vocabulary reader is broken, which is never a pass"
elif [ -z "$_run" ]; then
  bad "E4: rot env list printed no ROTMOE_ key at runtime"
else
  # Temp files, not process substitution: this file runs under /bin/sh and
  # no other checker in this tree uses <(), so it stays portable to the CI
  # runner's shell.
  printf '%s\n' "$_dtd" > "$WD/dtd.keys"
  printf '%s\n' "$_run" > "$WD/run.keys"
  _only_dtd=$(comm -23 "$WD/dtd.keys" "$WD/run.keys" | tr '\n' ' ')
  _only_run=$(comm -13 "$WD/dtd.keys" "$WD/run.keys" | tr '\n' ' ')
  if [ -z "$_only_dtd$_only_run" ]; then
    ok "E4: rot env list prints exactly the $(printf '%s\n' "$_dtd" | wc -l | tr -d ' ') keys the DTD declares"
  else
    [ -n "$_only_dtd" ] && bad "E4: declared but not offered at runtime: $_only_dtd"
    [ -n "$_only_run" ] && bad "E4: offered at runtime but undeclared: $_only_run"
  fi
fi

# --- E5: LAW 1 -- a value is exported with NO expansion ----------------------
# rot-env.sh:21-22 states it outright: a value of $(rm -rf ~) is exported as
# those literal characters. This plants a command substitution that WOULD
# leave a file on disk if it ever ran, and requires both that the file is
# absent and that the value survived verbatim.
PROJ="$WD/proj"
MARK="$WD/PWNED"
printf '%s\n' 'ROTMOE_DEBUG_SRC=$(touch '"$MARK"')' > "$PROJ/.rot-moe/rot.env"
_e5=$(sandbox "rot_env_load '$PROJ'; printf '%s' \"\${ROTMOE_DEBUG_SRC:-}\"")
if [ -e "$MARK" ]; then
  bad "E5: a rot.env value EXECUTED -- command substitution ran during load"
else
  case "$_e5" in
    *'$(touch'*) ok "E5: the value is exported verbatim, unexpanded -- a rot.env cannot inject a command" ;;
    '')          bad "E5: the planted value was dropped entirely -- refusal is not the declared behaviour, verbatim export is" ;;
    *)           bad "E5: the value was transformed on the way out ($_e5)" ;;
  esac
fi
rm -f "$MARK" 2>/dev/null || :

# --- E6: LAW 2 -- an undeclared key is refused -------------------------------
# PATH is the one that matters. rot-env.sh:25-26 claims nothing undeclared
# even exists to this parser; a rot.env that could set PATH would own the
# session.
printf '%s\n' 'PATH=/pwned' 'ROTMOE_NOT_A_REAL_KEY=x' 'HOME=/pwned' > "$PROJ/.rot-moe/rot.env"
# Reported as three verdicts, never as three values: printing $PATH back out
# would bury the finding in a screenful of this machine's directories, and a
# checker that pastes local paths into its own output is one archive away from
# leaking them.
_e6=$(sandbox "rot_env_load '$PROJ'
case \"\$PATH\" in */pwned*) printf 'PATH-BREACHED ' ;; *) printf 'path-held ' ;; esac
case \"\$HOME\" in */pwned*) printf 'HOME-BREACHED ' ;; *) printf 'home-held ' ;; esac
printf '%s' \"\${ROTMOE_NOT_A_REAL_KEY:+INVENTED-KEY-EXPORTED}\"")
case "$_e6" in
  *BREACHED*|*INVENTED-KEY-EXPORTED*) bad "E6: the vocabulary is open -- $_e6" ;;
  'path-held home-held'*) ok "E6: PATH, HOME and an invented ROTMOE_ key are all refused -- the vocabulary is closed" ;;
  *) bad "E6: the vocabulary probe returned nothing readable ('$_e6') -- never a pass" ;;
esac

# --- E7: LAW 2b -- ROTMOE_ENV cannot be set from a file ----------------------
# rot-env.sh:80 refuses it by name. Without that, one rot.env could point the
# loader at another file and the load order stops being the operator's.
printf '%s\n' 'ROTMOE_ENV=/pwned/chain.env' > "$PROJ/.rot-moe/rot.env"
_e7=$(sandbox "rot_env_load '$PROJ'; printf '%s' \"\${ROTMOE_ENV:-unset}\"")
case "$_e7" in
  *pwned*) bad "E7: a rot.env repointed the loader at its own file -- the load order is hijackable" ;;
  *)       ok "E7: ROTMOE_ENV is refused from a file -- only the operator sets the load order" ;;
esac

# --- E8: LAW 3 -- unset-only, the operator's export wins ---------------------
printf '%s\n' 'ROTMOE_DEBUG_SRC=from-file' > "$PROJ/.rot-moe/rot.env"
_e8=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" ROTMOE_ENV='' ROTMOE_DEBUG_SRC=from-operator \
  CLAUDE_PLUGIN_ROOT="$ROOT" \
  sh -c ". '$ENVLIB' >/dev/null 2>&1; rot_env_load '$PROJ'; printf '%s' \"\$ROTMOE_DEBUG_SRC\"" 2>/dev/null)
if [ "$_e8" = 'from-operator' ]; then
  ok "E8: an explicit export outranks the file -- the loader never overrides the operator"
else
  bad "E8: the file overwrote an operator's explicit export (got '$_e8')"
fi

# --- E9: a tier without checker/ must say so, not fake a verdict -------------
# MEASURED on the built archives: RoT-MoE-Router.zip ships hooks/rot-profile.sh
# and no checker/ directory whatsoever. `rot check` therefore pointed sh at a
# path that does not exist and printed "voice-contract exit=<n>" anyway -- a
# result line for a suite that never ran. E2 could never catch this: the branch
# exists, it just lies on one tier. Only the shape of a real install shows it.
TIER="$WD/tierhome"
mkdir -p "$TIER/hooks"
cp "$ROOT/hooks/rot-voice.dtd" "$TIER/hooks/"
cp "$PROFILE" "$TIER/hooks/rot-profile.sh"
_e9=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" ROTMOE_HOME="$TIER" \
  sh -c ". '$TIER/hooks/rot-profile.sh' >/dev/null 2>&1; rot check 2>&1; echo \"rc=\$?\"" 2>/dev/null)
case "$_e9" in
  *"voice-contract exit="*) bad "E9: a checker-less tier printed a voice-contract verdict for a suite that never ran" ;;
  *"no checker/"*"rc=2"*)   ok "E9: a tier that ships no checker/ says so and refuses, instead of inventing a verdict" ;;
  *)                        bad "E9: rot check on a checker-less tier answered unrecognisably ($_e9)" ;;
esac

# --- CONTROL 3: E9 is not passing because rot check is simply broken ---------
# The same probe against a home that DOES carry the suite must reach it. Only
# the presence of checker/ differs between this and E9.
TIER2="$WD/tierhome2"
mkdir -p "$TIER2/hooks" "$TIER2/checker"
cp "$ROOT/hooks/rot-voice.dtd" "$TIER2/hooks/"
cp "$PROFILE" "$TIER2/hooks/rot-profile.sh"
printf '%s\n' '#!/usr/bin/env sh' 'echo "stand-in suite ran"' 'exit 0' > "$TIER2/checker/voice-contract.sh"
_c3=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" ROTMOE_HOME="$TIER2" \
  sh -c ". '$TIER2/hooks/rot-profile.sh' >/dev/null 2>&1; rot check 2>&1" 2>/dev/null)
case "$_c3" in
  *"stand-in suite ran"*"voice-contract exit=0"*) ok "CONTROL 3: with checker/ present rot check DOES reach the suite -- E9 tests the tier, not a dead branch" ;;
  *) bad "CONTROL 3: rot check failed to reach a suite that is present ($_c3) -- E9 proves nothing" ;;
esac

# --- CONTROL 1: the loader is not simply refusing everything -----------------
# Without this, E5 E6 E7 and E8 all pass on a loader that does nothing at all.
printf '%s\n' 'ROTMOE_DEBUG_SRC=loaded-from-file' > "$PROJ/.rot-moe/rot.env"
_c1=$(sandbox "rot_env_load '$PROJ'; printf '%s' \"\${ROTMOE_DEBUG_SRC:-unset}\"")
if [ "$_c1" = 'loaded-from-file' ]; then
  ok "CONTROL 1: a declared key with a plain value IS loaded -- the refusals above are discrimination, not silence"
else
  bad "CONTROL 1: a declared key was NOT loaded (got '$_c1') -- every refusal above is vacuous"
fi

# --- CONTROL 2: the E2 reader can actually catch a ghost ---------------------
# A planted profile whose help advertises a subcommand it does not implement
# must be caught, or E2 is decoration.
# rot-profile.sh:157 builds `rot help` by reading the profile back off disk at
# "$_rp_home/hooks/rot-profile.sh" -- so a ghost copy dropped anywhere else
# would advertise the REAL file's help and the control would silently test
# nothing. The ghost therefore needs a whole plugin home: rot-profile.sh:49-50
# takes $ROTMOE_HOME when it points at a tree with hooks/rot-voice.dtd in it.
GH="$WD/ghosthome"
mkdir -p "$GH/hooks"
cp "$ROOT/hooks/rot-voice.dtd" "$GH/hooks/"
awk '/^#   rot help/ && !d { print "#   rot ghostcmd           advertised, never implemented"; d=1 } { print }' \
  "$PROFILE" > "$GH/hooks/rot-profile.sh"
_g=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" ROTMOE_HOME="$GH" \
  sh -c ". '$GH/hooks/rot-profile.sh' >/dev/null 2>&1; rot help 2>&1" 2>/dev/null \
  | sed -n 's/^  *rot \([a-z][a-z]*\).*/\1/p' | grep -c '^ghostcmd$' || true)
case "${_g:-0}" in
  0) bad "CONTROL 2: the planted ghost never reached help output -- E2's reader is unproven, which is never a pass" ;;
  *) _gh=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" ROTMOE_HOME="$GH" \
       sh -c ". '$GH/hooks/rot-profile.sh' >/dev/null 2>&1; rot help 2>&1" 2>/dev/null)
     _go=$(HOME="$FAKE" XDG_CONFIG_HOME="$FAKE/.config" ROTMOE_HOME="$GH" \
       sh -c ". '$GH/hooks/rot-profile.sh' >/dev/null 2>&1; rot ghostcmd 2>&1" 2>/dev/null)
     if [ "$_go" = "$_gh" ]; then
       ok "CONTROL 2: an advertised-but-unimplemented subcommand IS caught -- it answers with the manual, and E2 tests for exactly that"
     else
       bad "CONTROL 2: the ghost answered with something of its own -- E2 cannot catch what it exists to catch"
     fi ;;
esac

rm -rf "$WD" 2>/dev/null || :

echo "== env-layer: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
