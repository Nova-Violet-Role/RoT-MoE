#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# voice-contract.sh -- ORGAN 5's verifier: the lens roster, held both ways.
#
# hooks/rot-voice.dtd declares nine lenses -- name, element, charter, tool
# grant, bound -- plus the frame vocabulary the router may utter and the
# exclusion markers no charter may carry. A declaration nobody reads is
# documentation; this checker is what makes it a CONTRACT, in the method
# proved out by RoT DTD GOAL's `goal.sh contract --verify`:
#
#   D1  every declared lens has its agent file        (DECLARED BUT ABSENT)
#   D2  every agent file speaks in its element        (SPEAKS UNDECLARED)
#   D3  every rot-* agent file is declared            (UNDECLARED AGENT)
#   D4  every file carries its bound, verbatim        (BOUND MISSING)
#   D5  every file carries its full tool grant        (GRANT DRIFT)
#   D6  no file carries an exclusion marker           (EXCLUSION PRESENT)
#   D7  no file pins a model -- inheritance is the design (MODEL PINNED)
#   D8  the DTD lane vocabulary and the router's PROF_LANES are identical,
#       both directions                               (LANE DRIFT)
#
# The sweep in D3 is scoped to agents/rot-*.md, disclosed: lean4-prover.md
# is ORGAN 3 and predates this contract; it is bound by repo-complete.sh.
#
# Every check runs against a ROOT argument so the controls can run the same
# code against a planted copy -- a checker that cannot fail proves nothing.
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

# --- contract readers --------------------------------------------------------
# One reader per declaration class. The DTD is the single source; nothing in
# this file restates a lens name, a tool, a bound or a lane.
lens_rows () {   # <root> -> one row per LENS.n entity on stdout
  sed -n 's/.*<!ENTITY LENS\.[0-9][0-9]* *"\(.*\)">.*/\1/p' "$1/hooks/rot-voice.dtd"
}
exclude_rows () {   # <root> -> one exclusion marker per line
  sed -n 's/.*<!ENTITY EXCLUDE\.[0-9][0-9]* *"\(.*\)">.*/\1/p' "$1/hooks/rot-voice.dtd"
}
lane_rows () {   # <root> -> one declared lane per line
  sed -n 's/.*<!ENTITY LANE\.[0-9][0-9]* *"\(.*\)">.*/\1/p' "$1/hooks/rot-voice.dtd"
}

# --- the contract, verified against a root -----------------------------------
# Prints findings; returns 0 when every direction holds, 1 otherwise.
verify () {   # <root>
  _r="$1"
  _st=0

  [ -r "$_r/hooks/rot-voice.dtd" ] || { echo "  no contract at $_r/hooks/rot-voice.dtd"; return 1; }

  _n=0
  lens_rows "$_r" | while IFS='|' read -r _name _elem _sigil _charter _tools _bound; do
    _f="$_r/agents/$_name.md"
    # D1 -- declared but absent
    if [ ! -r "$_f" ]; then
      echo "  DECLARED BUT ABSENT: $_name (no $_f)"
      continue
    fi
    # D2 -- the file speaks in its declared element
    grep -qF "$_elem" "$_f" || echo "  SPEAKS UNDECLARED: $_name never utters $_elem"
    # frontmatter name must be the declared name
    grep -q "^name: $_name\$" "$_f" || echo "  NAME DRIFT: $_f frontmatter is not 'name: $_name'"
    # D4 -- the bound, verbatim
    grep -qF "$_bound" "$_f" || echo "  BOUND MISSING: $_name lacks \"$_bound\""
    # D5 -- the tool grant, every declared tool present in the tools line
    _tline=$(grep '^tools:' "$_f" | head -n 1)
    _oldifs=$IFS; IFS=','
    for _t in $_tools; do
      case "$_tline" in *"$_t"*) : ;; *) echo "  GRANT DRIFT: $_name tools line lacks $_t" ;; esac
    done
    IFS=$_oldifs
    # D7 -- no pinned model; inheritance is the design
    grep -q '^model:' "$_f" && echo "  MODEL PINNED: $_name carries a model key; the lens must inherit the convener"
  done > "$_r/.voice-findings" 2>&1

  # D3 -- nothing undeclared speaks. Scoped to rot-*.md, disclosed above.
  for _f in "$_r"/agents/rot-*.md; do
    [ -e "$_f" ] || continue
    _bn=$(basename "$_f" .md)
    lens_rows "$_r" | cut -d'|' -f1 | grep -qx "$_bn" \
      || echo "  UNDECLARED AGENT: $_bn exists and is not in the roster" >> "$_r/.voice-findings"
  done

  # D6 -- exclusion markers, forbidden in every charter
  exclude_rows "$_r" | while read -r _x; do
    [ -n "$_x" ] || continue
    for _f in "$_r"/agents/rot-*.md; do
      [ -e "$_f" ] || continue
      grep -qF "$_x" "$_f" && echo "  EXCLUSION PRESENT: $(basename "$_f") carries \"$_x\"" >> "$_r/.voice-findings"
    done
  done

  # D8 -- lane vocabulary vs the router, both directions
  if [ -r "$_r/hooks/rot-router.sh" ]; then
    _prof=$(sed -n "s/^PROF_LANES='\(.*\)'.*/\1/p" "$_r/hooks/rot-router.sh")
    lane_rows "$_r" | while read -r _l; do
      case " $_prof " in *" $_l "*) : ;; *) echo "  LANE DRIFT: DTD declares $_l, router does not route it" >> "$_r/.voice-findings" ;; esac
    done
    for _l in $_prof; do
      lane_rows "$_r" | grep -qx "$_l" || echo "  LANE DRIFT: router routes $_l, DTD does not declare it" >> "$_r/.voice-findings"
    done
  fi

  if [ -s "$_r/.voice-findings" ]; then
    cat "$_r/.voice-findings"
    _st=1
  fi
  rm -f "$_r/.voice-findings"
  return $_st
}

# --- the real tree -----------------------------------------------------------
if verify "$ROOT"; then
  ok "voice-contract: every declared lens exists, speaks in its element, carries its bound and its grant; nothing undeclared speaks; no exclusion marker present; lane vocabulary matches the router both ways"
else
  bad "voice-contract: the tree disagrees with hooks/rot-voice.dtd -- findings above"
fi

# --- D9: the voices actually fire --------------------------------------------
# The roster holding on paper says nothing about the session. Feed the POSIX
# arm a real UserPromptSubmit payload and require: a stanza in the routed
# lens's element AFTER the untouched marker line; silence under
# ROTMOE_VOICE=0; and silence on an event whose stdout the model never sees.
# The ps1 arm is exercised by CI where pwsh exists; here the reference arm is
# the measurement.
_pay='{"session_id":"vctl","cwd":"/tmp","hook_event_name":"UserPromptSubmit","prompt":"prove this lemma"}'
_out=$(printf '%s' "$_pay" | ROTMOE_VOICE=1 sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
if printf '%s\n' "$_out" | head -n 1 | grep -q '^RoT MoE :: TIER 1 -> FORGE' \
   && printf '%s\n' "$_out" | grep -q '^<rot:claude>' ; then
  ok "D9: a FORGE prompt speaks in <rot:claude> after an untouched marker"
else
  bad "D9: the voice block did not fire (or the marker moved) on a FORGE prompt"
fi
_out=$(printf '%s' "$_pay" | ROTMOE_VOICE=0 sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
if printf '%s\n' "$_out" | grep -q '^<rot:'; then
  bad "D9: ROTMOE_VOICE=0 still emitted a stanza -- the off switch is dead"
else
  ok "D9: ROTMOE_VOICE=0 silences the voices; the marker stands alone"
fi
_out=$(printf '%s' '{"session_id":"vctl","cwd":"/tmp","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"lake build X"}}' \
       | ROTMOE_VOICE=1 sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
if printf '%s\n' "$_out" | grep -q '^<rot:'; then
  bad "D9: a stanza was emitted on PreToolUse -- plain stdout there never reaches the model, so those bytes are a fabricated capability"
else
  ok "D9: no stanza on a non-context event -- the harness contract is respected"
fi

# --- controls: the checker must be able to fail ------------------------------
# Each control plants one defect in a minimal copy and requires the SAME
# verify() to catch it. A green from a checker whose reds are unreachable is
# silence, not measurement.
CTL=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/voice-ctl.$$")
mkdir -p "$CTL/hooks" "$CTL/agents"
cp "$ROOT/hooks/rot-voice.dtd" "$CTL/hooks/"
cp "$ROOT/hooks/rot-router.sh" "$CTL/hooks/" 2>/dev/null || :
for _f in "$ROOT"/agents/rot-*.md; do [ -e "$_f" ] && cp "$_f" "$CTL/agents/"; done

# CONTROL 1 -- a ghost agent must be caught as undeclared.
printf -- '---\nname: rot-ghost\ntools: [Read]\n---\nA lens nobody declared.\n' > "$CTL/agents/rot-ghost.md"
if verify "$CTL" >/dev/null 2>&1; then
  bad "CONTROL: a planted undeclared agent went unnoticed -- D3 cannot fail"
else
  ok "CONTROL: a planted undeclared agent IS caught"
fi
rm -f "$CTL/agents/rot-ghost.md"

# CONTROL 2 -- a deleted bound must be caught, using whichever roster row
# actually has a file present (the control is skipped honestly when no agent
# has landed yet, and says so).
_victim=''
lens_rows "$ROOT" | cut -d'|' -f1 > "$CTL/.names"
while read -r _n; do
  [ -r "$CTL/agents/$_n.md" ] && { _victim="$_n"; break; }
done < "$CTL/.names"
rm -f "$CTL/.names"
if [ -n "$_victim" ]; then
  _b=$(lens_rows "$ROOT" | awk -F'|' -v n="$_victim" '$1==n{print $6}')
  grep -vF "$_b" "$CTL/agents/$_victim.md" > "$CTL/agents/$_victim.md.tmp" \
    && mv "$CTL/agents/$_victim.md.tmp" "$CTL/agents/$_victim.md"
  if verify "$CTL" >/dev/null 2>&1; then
    bad "CONTROL: a deleted bound went unnoticed -- D4 cannot fail"
  else
    ok "CONTROL: a deleted bound IS caught"
  fi
else
  bad "CONTROL: no agent file present to mutate -- the roster has no landed lens, so D4's control cannot run"
fi

rm -rf "$CTL" 2>/dev/null || :

echo "== voice-contract: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
