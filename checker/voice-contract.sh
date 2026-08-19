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
# No pipes into grep -q here: SIGPIPE under pipefail is platform-dependent
# (checker/portability.sh refuses the construct). Captured output, `case`
# matching -- zero pipes, zero forks.
_pay='{"session_id":"vctl","cwd":"/tmp","hook_event_name":"UserPromptSubmit","prompt":"prove this lemma"}'
_out=$(printf '%s' "$_pay" | ROTMOE_VOICE=1 ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_out" in
  'RoT MoE :: TIER 1 -> FORGE'*'<rot:claude>'*)
    ok "D9: a FORGE prompt speaks in <rot:claude> after an untouched marker" ;;
  *)
    bad "D9: the voice block did not fire (or the marker moved) on a FORGE prompt" ;;
esac
_out=$(printf '%s' "$_pay" | ROTMOE_VOICE=0 ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_out" in
  *'<rot:'*) bad "D9: ROTMOE_VOICE=0 still emitted a stanza -- the off switch is dead" ;;
  *)         ok "D9: ROTMOE_VOICE=0 silences the voices; the marker stands alone" ;;
esac
# On the tool-loop events the voice travels as the JSON envelope's
# additionalContext -- plain stanza LINES there would be bytes the model
# never sees. Voice on: one strictly valid JSON object, event echoed back,
# stanzas inside the string. Voice off: the plain marker, exactly as before.
_out=$(printf '%s' '{"session_id":"vctl","cwd":"/tmp","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"lake build X"}}' \
       | ROTMOE_VOICE=1 ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_out" in
  '{'*'"hookEventName":"PreToolUse"'*'additionalContext'*'<rot:'*)
    if printf '%s' "$_out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);const h=j.hookSpecificOutput;process.exit(h&&h.hookEventName==="PreToolUse"&&typeof h.additionalContext==="string"&&h.additionalContext.indexOf("RoT MoE :: TIER 1")===0?0:1)}catch(e){process.exit(1)}})' 2>/dev/null; then
      ok "D9: mid-work voice on PreToolUse is one strictly valid JSON envelope, event echoed, marker first, stanzas inside"
    else
      bad "D9: the PreToolUse voice envelope failed strict JSON validation"
    fi ;;
  *) bad "D9: PreToolUse with voice on did not produce the JSON envelope" ;;
esac
_out=$(printf '%s' '{"session_id":"vctl","cwd":"/tmp","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"lake build X"}}' \
       | ROTMOE_VOICE=0 ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_out" in
  'RoT MoE :: TIER 1 ->'*'<rot:'*) bad "D9: ROTMOE_VOICE=0 leaked a stanza on a tool event" ;;
  'RoT MoE :: TIER 1 ->'*)         ok "D9: ROTMOE_VOICE=0 keeps the plain marker on tool events, stanza-free" ;;
  *)                               bad "D9: ROTMOE_VOICE=0 lost the marker on a tool event" ;;
esac

# --- D10: the gate holds the door, once, and degrades open -------------------
# The voice gate (ORGAN 6) is exercised end to end in a scratch state dir: a
# FUSE prompt writes the summons, a transcript where nobody spoke must BLOCK
# with every missing charter, the summons must be CONSUMED by that block, a
# transcript where everyone spoke must allow, and stop_hook_active must stand
# the gate down. All against the POSIX arm; CI exercises the ps1 twin.
GD=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/voice-gate.$$")
_fuse='{"session_id":"vgate","cwd":"/tmp","hook_event_name":"UserPromptSubmit","prompt":"plan a strategy to debug the build and predict the next failure"}'
printf '%s' "$_fuse" | ROTMOE_STATE_DIR="$GD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" >/dev/null 2>&1
if [ -s "$GD/voice-summons.vgate" ]; then
  ok "D10: a FUSE prompt writes the summons"
else
  bad "D10: no summons written on a FUSE prompt -- the gate has nothing to hold"
fi
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"no stanzas here"}]}}' > "$GD/tr-silent.jsonl"
_g=$(printf '%s' "{\"session_id\":\"vgate\",\"transcript_path\":\"$GD/tr-silent.jsonl\"}" | ROTMOE_STATE_DIR="$GD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-voice-gate.sh" 2>/dev/null)
case "$_g" in
  '{"decision":"block"'*'rot:nova'*'rot:claude'*)
    ok "D10: unspoken summons BLOCKS, the reason carrying the missing charters" ;;
  *) bad "D10: the gate did not block an unspoken summons (got: ${_g:-nothing})" ;;
esac
if [ -e "$GD/voice-summons.vgate" ]; then
  bad "D10: the summons survived its own block -- the gate could cage a turn"
else
  ok "D10: the summons is consumed by the block -- one refusal per turn"
fi
printf '%s' "$_fuse" | ROTMOE_STATE_DIR="$GD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" >/dev/null 2>&1
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"<rot:nova>a</rot:nova><rot:antivenom>b</rot:antivenom><rot:chroma>c</rot:chroma><rot:claude>d</rot:claude>"}]}}' > "$GD/tr-spoken.jsonl"
_g=$(printf '%s' "{\"session_id\":\"vgate\",\"transcript_path\":\"$GD/tr-spoken.jsonl\"}" | ROTMOE_STATE_DIR="$GD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-voice-gate.sh" 2>/dev/null)
if [ -z "$_g" ]; then
  ok "D10: a spoken summons allows silently"
else
  bad "D10: the gate spoke on a satisfied summons: $_g"
fi
printf '%s' "$_fuse" | ROTMOE_STATE_DIR="$GD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" >/dev/null 2>&1
_g=$(printf '%s' "{\"session_id\":\"vgate\",\"stop_hook_active\":true,\"transcript_path\":\"$GD/tr-silent.jsonl\"}" | ROTMOE_STATE_DIR="$GD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-voice-gate.sh" 2>/dev/null)
if [ -z "$_g" ] && [ ! -e "$GD/voice-summons.vgate" ]; then
  ok "D10: stop_hook_active stands the gate down and clears the summons"
else
  bad "D10: the gate argued with a stop that already survived one block"
fi
# U3 (measured 2026-08-19, closed in 7.0.0): a summons written while the gate
# was ARMED must not survive a GATE=0 prompt turn. Opting out of the gate used
# to skip the summons block entirely, so the file stood -- and the first Stop
# after re-arming was blocked for a turn long dead. Sequence probed exactly:
# armed FUSE writes it, a GATE=0 turn must remove it, the re-armed gate then
# has nothing to hold.
printf '%s' "$_fuse" | ROTMOE_STATE_DIR="$GD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" >/dev/null 2>&1
printf '%s' '{"session_id":"vgate","cwd":"/tmp","hook_event_name":"UserPromptSubmit","prompt":"hello there"}' | ROTMOE_GATE=0 ROTMOE_STATE_DIR="$GD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" >/dev/null 2>&1
if [ -e "$GD/voice-summons.vgate" ]; then
  bad "D10: a GATE=0 turn left an armed turn's summons standing -- the first re-armed Stop is caged by a dead turn"
else
  ok "D10: GATE=0 still clears -- a stale summons cannot outlive its turn"
fi
rm -rf "$GD" 2>/dev/null || :

# --- D11: the computed layer is the executable's, never a copy that drifts ---
# Every charter carries its formula as YAML inside a CDATA section (the codex
# lineage: Symbioticum internal YAML -> 10.1 nested YAML -> skill-variant XML
# polyglot -> declared AND checked). The numbers are re-derived from
# hooks/rot-router.sh itself: section-2 defaults from DEF_*, the lead row
# from its section-4 profile, the band from the lane table, and the
# lens-specific constants from the shell's own. Assignment lines only are
# eval'd, grep-filtered to the exact names -- the checker runs the tables,
# never a copy of them.
eval "$(grep -E '^(DEF_LAM|DEF_MU|DEF_H|NAMES)=' "$ROOT/hooks/rot-router.sh")"
eval "$(grep -E '^[LM]_(CONVERGENT|CLINICAL|EXECUTIVE|EMPATHIC|STRATEGIC|CREATIVE|PREDICTIVE|STEALTH|RECURSIVE|FORGE)=' "$ROOT/hooks/rot-router.sh")"
eval "$(grep -E '^BAND_(LO|HI)_[A-Z]+=' "$ROOT/hooks/rot-router.sh")"
eval "$(grep -E '^(CHROMA_SPAWNED|CHROMA_SHOWN_NORMAL|CHROMA_SHOWN_EMERGENCY|TOKEN_FLOOR_PCT)=' "$ROOT/hooks/rot-router.sh")"
eval "$(grep -E '^VIOLET_TRACKS=' "$ROOT/hooks/rot-router.sh")"

pos () { printf '%s\n' "$2" | awk -v i="$1" '{print $i}'; }
numeq () { awk -v a="$1" -v b="$2" 'BEGIN{exit (a+0==b+0)?0:1}'; }
cent () { awk -v v="$1" 'BEGIN{printf "%g", v/100}'; }

_i=0; _d11bad=0
for _n in $NAMES; do
  _i=$((_i+1))
  _an=$(lens_rows "$ROOT" | sed -n "${_i}p" | cut -d'|' -f1)
  _f="$ROOT/agents/$_an.md"
  _blk=$(sed -n '/<rot:formula>/,/<\/rot:formula>/p' "$_f" 2>/dev/null)
  if [ -z "$_blk" ]; then
    bad "D11: $_an declares no <rot:formula> layer"; _d11bad=1; continue
  fi
  _dl=$(printf '%s\n' "$_blk" | awk -F': *' '/lambda:/{c++; if (c==1) print $2}')
  _ll=$(printf '%s\n' "$_blk" | awk -F': *' '/lambda:/{c++; if (c==2) print $2}')
  _dm=$(printf '%s\n' "$_blk" | awk -F': *' '/mu:/{c++; if (c==1) print $2}')
  _lm=$(printf '%s\n' "$_blk" | awk -F': *' '/mu:/{c++; if (c==2) print $2}')
  _hm=$(printf '%s\n' "$_blk" | awk -F': *' '/h_max:/{print $2; exit}')
  _lane=$(printf '%s\n' "$_blk" | awk -F': *' '/lane:/{print $2; exit}')
  _blo=$(printf '%s\n' "$_blk" | sed -n 's/.*band: *\[ *\([0-9.]*\) *, *\([0-9.]*\) *\].*/\1/p' | sed -n 1p)
  _bhi=$(printf '%s\n' "$_blk" | sed -n 's/.*band: *\[ *\([0-9.]*\) *, *\([0-9.]*\) *\].*/\2/p' | sed -n 1p)
  numeq "$_dl" "$(cent "$(pos "$_i" "$DEF_LAM")")" || { bad "D11: $_an default lambda $_dl != roster $(cent "$(pos "$_i" "$DEF_LAM")")"; _d11bad=1; }
  numeq "$_dm" "$(cent "$(pos "$_i" "$DEF_MU")")"  || { bad "D11: $_an default mu $_dm != roster $(cent "$(pos "$_i" "$DEF_MU")")"; _d11bad=1; }
  numeq "$_hm" "$(cent "$(pos "$_i" "$DEF_H")")"   || { bad "D11: $_an h_max $_hm != roster $(cent "$(pos "$_i" "$DEF_H")")"; _d11bad=1; }
  eval "_tl=\${L_$_lane:-}"; eval "_tm=\${M_$_lane:-}"
  eval "_xlo=\${BAND_LO_$_lane:-}"; eval "_xhi=\${BAND_HI_$_lane:-}"
  if [ -z "$_tl" ] || [ -z "$_xlo" ]; then
    bad "D11: $_an leads unknown lane '$_lane'"; _d11bad=1
  else
    numeq "$_ll" "$(pos "$_i" "$_tl")" || { bad "D11: $_an lead lambda $_ll != $_lane profile $(pos "$_i" "$_tl")"; _d11bad=1; }
    numeq "$_lm" "$(pos "$_i" "$_tm")" || { bad "D11: $_an lead mu $_lm != $_lane profile $(pos "$_i" "$_tm")"; _d11bad=1; }
    numeq "$_blo" "$(cent "$_xlo")" || { bad "D11: $_an band low $_blo != $_lane $(cent "$_xlo")"; _d11bad=1; }
    numeq "$_bhi" "$(cent "$_xhi")" || { bad "D11: $_an band high $_bhi != $_lane $(cent "$_xhi")"; _d11bad=1; }
  fi
  case "$_n" in
    Chroma)
      _sp=$(printf '%s\n' "$_blk" | sed -n 's/.*spawned: *\([0-9]*\).*/\1/p' | sed -n 1p)
      _sh=$(printf '%s\n' "$_blk" | sed -n 's/.*shown: *\([0-9]*\).*/\1/p' | sed -n 1p)
      _em=$(printf '%s\n' "$_blk" | sed -n 's/.*emergency: *\([0-9]*\).*/\1/p' | sed -n 1p)
      { numeq "$_sp" "$CHROMA_SPAWNED" && numeq "$_sh" "$CHROMA_SHOWN_NORMAL" && numeq "$_em" "$CHROMA_SHOWN_EMERGENCY"; } \
        || { bad "D11: Chroma timelines $_sp/$_sh/$_em != shell $CHROMA_SPAWNED/$CHROMA_SHOWN_NORMAL/$CHROMA_SHOWN_EMERGENCY"; _d11bad=1; }
      ;;
    Soleil)
      _tf=$(printf '%s\n' "$_blk" | sed -n 's/.*token_floor_pct: *\([0-9]*\).*/\1/p' | sed -n 1p)
      numeq "$_tf" "$TOKEN_FLOOR_PCT" || { bad "D11: Soleil token floor $_tf != shell $TOKEN_FLOOR_PCT"; _d11bad=1; }
      ;;
    Violet)
      # The 6.0.2 dynamic stanza defaults her jazz track by the clock, so the
      # five names became a shell constant -- held here in both directions
      # like Chroma's timelines and Soleil's floor: the declared count must
      # equal the shell roster's, and the declared names must BE the shell's,
      # in order. YAML `[A, B]` normalises to the shell's space-joined list.
      _jt=$(printf '%s\n' "$_blk" | sed -n 's/.*jazz_tracks: *\([0-9]*\).*/\1/p' | sed -n 1p)
      _vtl=$(printf '%s\n' "$_blk" | sed -n 's/.* tracks: *\[\(.*\)\].*/\1/p' | sed -n 1p | tr -d ' ' | tr ',' ' ')
      _vtn=0; for _vt in $VIOLET_TRACKS; do _vtn=$((_vtn+1)); done
      numeq "$_jt" "$_vtn" || { bad "D11: Violet jazz_tracks $_jt != shell track roster $_vtn"; _d11bad=1; }
      [ "$_vtl" = "$VIOLET_TRACKS" ] || { bad "D11: Violet tracks [$_vtl] != shell VIOLET_TRACKS [$VIOLET_TRACKS]"; _d11bad=1; }
      ;;
  esac
done
[ "$_d11bad" -eq 0 ] && ok "D11: nine computed layers, every number re-derived from the executable -- defaults, lead rows, bands, and the lens-specific constants"

# --- D12: the environment layer -- declared vocabulary, three laws, live ----
# Direction one: every ENV.n name is read by a shipped hook (a declaration
# nobody reads is decoration). Direction two: every ROTMOE_ name a shipped
# hook reads is declared (an undeclared switch is a secret). Then the laws,
# measured: a project rot.env silences the voice; the live environment
# outranks it; an undeclared key is ignored.
env_rows () { sed -n 's/.*<!ENTITY ENV\.[0-9][0-9]* *"\([A-Z_]*\)|.*/\1/p' "$1/hooks/rot-voice.dtd"; }
_d12bad=0
for _ev_name in $(env_rows "$ROOT"); do
  _hit=$(grep -l "$_ev_name" "$ROOT"/hooks/*.sh "$ROOT"/hooks/*.ps1 2>/dev/null | sed -n 1p)
  [ -n "$_hit" ] || { bad "D12: declared $_ev_name is read by no shipped hook -- decoration"; _d12bad=1; }
done
for _tok in $(grep -ohE 'ROTMOE_[A-Z_]+' "$ROOT"/hooks/*.sh "$ROOT"/hooks/*.ps1 2>/dev/null | sort -u); do
  env_rows "$ROOT" | grep -qx "$_tok" || { bad "D12: hooks read undeclared $_tok -- a secret switch"; _d12bad=1; }
done
[ "$_d12bad" -eq 0 ] && ok "D12: environment vocabulary identical both ways -- every declaration read, every read declared"

ED=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/voice-env.$$")
mkdir -p "$ED/proj/.rot-moe"
printf 'ROTMOE_VOICE=0\n' > "$ED/proj/.rot-moe/rot.env"
_pay="{\"session_id\":\"venv\",\"cwd\":\"$ED/proj\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"prove this lemma\"}"
_out=$(printf '%s' "$_pay" | ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_out" in
  *'<rot:'*) bad "D12: a project rot.env with ROTMOE_VOICE=0 did not silence the voice" ;;
  *)         ok "D12: a project rot.env supplies the default -- the voice is silenced" ;;
esac
_out=$(printf '%s' "$_pay" | ROTMOE_VOICE=1 ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_out" in
  *'<rot:'*) ok "D12: the live environment outranks the file -- ROTMOE_VOICE=1 wins" ;;
  *)         bad "D12: a file value overrode an operator's explicit export" ;;
esac
printf 'ROTMOE_VOICEX=0\nPATH=/evil\nROTMOE_ENV=/elsewhere\n' > "$ED/proj/.rot-moe/rot.env"
_out=$(printf '%s' "$_pay" | ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_out" in
  *'<rot:'*) ok "D12: undeclared keys are ignored -- the parser accepts only the DTD vocabulary" ;;
  *)         bad "D12: an undeclared key changed behaviour -- the vocabulary gate is dead" ;;
esac
# CONTROL for D12 -- strip ROTMOE_VOICE from a DTD copy and the same file's
# declared key must stop working: declared-only is real, not a comment.
mkdir -p "$ED/hooks"
cp "$ROOT/hooks/rot-router.sh" "$ED/hooks/"
cp "$ROOT/hooks/rot-env.sh" "$ED/hooks/"
sed '/ROTMOE_VOICE|/d' "$ROOT/hooks/rot-voice.dtd" > "$ED/hooks/rot-voice.dtd"
printf 'ROTMOE_VOICE=0\n' > "$ED/proj/.rot-moe/rot.env"
_out=$(printf '%s' "$_pay" | ROTMOE_DEBUG_SRC=test sh "$ED/hooks/rot-router.sh" 2>/dev/null)
case "$_out" in
  *'<rot:'*) ok "CONTROL: with the declaration stripped, the file's key is refused -- declared-only IS enforced" ;;
  *)         bad "CONTROL: an undeclared ROTMOE_VOICE still silenced the voice -- the vocabulary gate cannot fail" ;;
esac
rm -rf "$ED" 2>/dev/null || :

# --- D13: the sentinel -- the working share speaks on measured anomaly ------
# The V2 clauses read tool_response fields MEASURED live on this CLI
# (2026-08-19 survey: stdout/stderr/interrupted/isImage/noOutputExpected;
# no exit_code exists). Each behaviour is probed with a payload in the
# measured shape, and each clause has its refusal path: the blessed blank
# (the harness's own noOutputExpected sanction) and the voice off-switch.
SD=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/voice-sent.$$")
_sp='{"session_id":"vsent","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"true"},"tool_response":{"stdout":"","stderr":"","interrupted":false,"isImage":false}}'
_g=$(printf '%s' "$_sp" | ROTMOE_STATE_DIR="$SD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in
  '{"hookSpecificOutput"'*'rot:antivenom'*'BLANK'*) ok "D13: a blank result speaks AntiVenom's clause on the envelope" ;;
  *) bad "D13: a blank result raised no clause (got: ${_g:-nothing})" ;;
esac
_g=$(printf '%s' '{"session_id":"vsent","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"true"},"tool_response":{"stdout":"","stderr":"","interrupted":false,"noOutputExpected":true}}' | ROTMOE_STATE_DIR="$SD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in
  *'<rot:'*) bad "D13: a BLESSED blank (noOutputExpected) still raised a clause" ;;
  'RoT MoE :: TIER 1 ->'*) ok "D13: the blessed blank stays silent -- the harness sanction is honoured" ;;
  *) bad "D13: the blessed blank lost its marker" ;;
esac
_g=$(printf '%s' '{"session_id":"vsent","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"sleep 9"},"tool_response":{"stdout":"","stderr":"","interrupted":true}}' | ROTMOE_STATE_DIR="$SD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in
  *'rot:claude'*'INTERRUPTED'*) ok "D13: an interrupted result speaks Claude's clause, outranking the blank" ;;
  *) bad "D13: an interruption raised no Claude clause" ;;
esac
_g=$(printf '%s' '{"session_id":"vsent","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/tmp/x","content":"hello"},"tool_response":{"type":"create","filePath":"/tmp/x","content":"","userModified":false}}' | ROTMOE_STATE_DIR="$SD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in
  *'rot:antivenom'*'ZERO BYTES'*) ok "D13: a zero-byte write of given content speaks" ;;
  *) bad "D13: the zero-byte write stayed silent" ;;
esac
_g=$(printf '%s' "$_sp" | ROTMOE_VOICE=0 ROTMOE_STATE_DIR="$SD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in
  *'<rot:'*) bad "D13: ROTMOE_VOICE=0 did not silence the sentinel" ;;
  *) ok "D13: ROTMOE_VOICE=0 silences the sentinel with the rest of the voice" ;;
esac
# The sentinel's element tags are literals in the router; they must be
# declared lens elements or the gate could never match what they open.
_d13e=0
for _se in rot:claude rot:antivenom; do
  sed -n 's/.*<!ENTITY LENS\.[0-9][0-9]* *"[^|]*|\([^|]*\)|.*/\1/p' "$ROOT/hooks/rot-voice.dtd" | grep -qx "$_se" \
    || { bad "D13: sentinel element $_se is not a declared lens element"; _d13e=1; }
done
[ "$_d13e" -eq 0 ] && ok "D13: the sentinel speaks only in declared lens elements"
rm -rf "$SD" 2>/dev/null || :

# --- D14: the Animus -- the paired observer's channel, both directions ------
# The worker-side ear (both router arms; the sh arm probed here, cross-diff
# owns arm agreement) and the observer itself (hooks/animus-observe.sh, the
# deterministic router-over-the-event-stream). Every row has its refusal or
# silence path; every temp path is the row's own -- a checker that writes
# into the repository is not a read-only observer, so the observer rows
# override the project distillate explicitly.
AD=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/voice-anim.$$")
mkdir -p "$AD"
_ap='{"session_id":"vanim","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"},"tool_response":{"stdout":"hi","stderr":""}}'
_aq="$AD/animus-queue.vanim"

# consumption: a planted remark is spoken in its lens element, (animus)-tagged,
# and the queue is consumed
printf 'AntiVenom|a planted animus remark\n' > "$_aq"
_g=$(printf '%s' "$_ap" | ROTMOE_ANIMUS=1 ROTMOE_STATE_DIR="$AD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in
  '{"hookSpecificOutput"'*'rot:antivenom'*'AntiVenom (animus): a planted animus remark'*)
    ok "D14: a queued remark speaks on the envelope, inside its lens element, tagged (animus)" ;;
  *) bad "D14: the queued remark did not speak (got: ${_g:-nothing})" ;;
esac
[ -f "$_aq" ] && bad "D14: the queue survived consumption" || ok "D14: the queue was consumed"

# FIFO: one remark per event, the remainder holds its order
printf 'Venom|first remark\nSoleil|second remark\n' > "$_aq"
_g=$(printf '%s' "$_ap" | ROTMOE_ANIMUS=1 ROTMOE_STATE_DIR="$AD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in
  *'Venom (animus): first remark'*) ok "D14: FIFO -- the first remark spoke" ;;
  *) bad "D14: FIFO order broken (got: ${_g:-nothing})" ;;
esac
[ "$(cat "$_aq" 2>/dev/null)" = 'Soleil|second remark' ] \
  && ok "D14: one remark per event -- the second waits its turn" \
  || bad "D14: the remainder queue is wrong: $(cat "$_aq" 2>/dev/null)"
rm -f "$_aq"

# silence: an absent queue is not a byte
_g=$(printf '%s' "$_ap" | ROTMOE_ANIMUS=1 ROTMOE_STATE_DIR="$AD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in
  *'(animus)'*) bad "D14: an empty queue produced a remark from nothing" ;;
  *) ok "D14: empty queue, not a byte -- silence is the healthy state" ;;
esac

# the roster holds: an undeclared lens is refused AND dropped (no queue jam)
printf 'Mallory|evil whisper\n' > "$_aq"
_g=$(printf '%s' "$_ap" | ROTMOE_ANIMUS=1 ROTMOE_STATE_DIR="$AD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in
  *'Mallory'*|*'evil whisper'*) bad "D14: an undeclared lens SPOKE -- the roster fell" ;;
  *) ok "D14: an undeclared lens is refused" ;;
esac
[ -f "$_aq" ] && bad "D14: the refused line was not dropped -- it would jam the queue head forever" \
              || ok "D14: the refused line is dropped, the queue cannot jam"

# unarmed: without ROTMOE_ANIMUS the queue is never read
printf 'AntiVenom|should not be read\n' > "$_aq"
_g=$(printf '%s' "$_ap" | ROTMOE_STATE_DIR="$AD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in *'(animus)'*) bad "D14: an UNARMED worker consumed the queue" ;; *) : ;; esac
[ "$(cat "$_aq" 2>/dev/null)" = 'AntiVenom|should not be read' ] \
  && ok "D14: unarmed (ROTMOE_ANIMUS unset) -- the queue is never touched" \
  || bad "D14: unarmed, yet the queue changed"

# the off-switch: VOICE=0 silences remarks and leaves the queue standing
_g=$(printf '%s' "$_ap" | ROTMOE_ANIMUS=1 ROTMOE_VOICE=0 ROTMOE_STATE_DIR="$AD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in *'(animus)'*) bad "D14: ROTMOE_VOICE=0 did not silence the remark" ;; *) : ;; esac
[ -f "$_aq" ] && ok "D14: ROTMOE_VOICE=0 silences the remark and keeps the queue" \
              || bad "D14: ROTMOE_VOICE=0 consumed the queue while silent"
rm -f "$_aq"

# atomicity: a writer's half-landed tmp file beside the queue is invisible
printf 'AntiVenom|half-written\n' > "$_aq.an.999"
_g=$(printf '%s' "$_ap" | ROTMOE_ANIMUS=1 ROTMOE_STATE_DIR="$AD" ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" 2>/dev/null)
case "$_g" in *'(animus)'*) bad "D14: a tmp file beside the queue was consumed -- the rename-atomic contract is dead" ;; *) ok "D14: a writer's tmp file is invisible to the consumer" ;; esac
rm -f "$_aq.an.999"

# the sentinel's firing is a RECORD: without it the observer counts nothing
_al="$AD/anomaly-probe.jsonl"
printf '%s' '{"session_id":"vanim","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"true"},"tool_response":{"stdout":"","stderr":""}}' \
  | ROTMOE_STATE_DIR="$AD" ROTMOE_DEBUG_LOG="$_al" ROTMOE_DEBUG_LOCAL=0 ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" >/dev/null 2>&1
grep -q '"kind":"anomaly".*"shape":"blank"' "$_al" 2>/dev/null \
  && ok "D14: a sentinel firing writes its anomaly record -- falsifiable from the log" \
  || bad "D14: the sentinel fired without a record (or did not fire)"
printf '%s' "$_ap" | ROTMOE_STATE_DIR="$AD" ROTMOE_DEBUG_LOG="$_al" ROTMOE_DEBUG_LOCAL=0 ROTMOE_DEBUG_SRC=test sh "$ROOT/hooks/rot-router.sh" >/dev/null 2>&1
_an=$(grep -c '"kind":"anomaly"' "$_al" 2>/dev/null)
[ "$_an" = 1 ] && ok "D14: a healthy result writes no anomaly record" \
               || bad "D14: anomaly records after one blank and one healthy result: $_an, expected 1"

# the observer: a planted recurrence queues AntiVenom; an empty sink queues nothing
OD=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/voice-obs.$$")
mkdir -p "$OD"
printf '{"kind":"anomaly","ts":"T","event":"PostToolUse","session":"vobs","src":"test","shape":"blank","tool":"Bash","arm":"sh"}\n{"kind":"anomaly","ts":"T","event":"PostToolUse","session":"vobs","src":"test","shape":"blank","tool":"Bash","arm":"sh"}\n' > "$OD/rot-debug.vobs.jsonl"
ROTMOE_STATE_DIR="$OD" ROTMOE_ANIMUS_DISTILLATE="$OD/dist.md" sh "$ROOT/hooks/animus-observe.sh" vobs --once >/dev/null 2>&1
grep -q '^AntiVenom|the blank result has recurred' "$OD/animus-queue.vobs" 2>/dev/null \
  && ok "D14: the observer queues AntiVenom on a measured recurrence" \
  || bad "D14: the observer saw two blanks and queued nothing"
OD2=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/voice-obs2.$$")
mkdir -p "$OD2"
: > "$OD2/rot-debug.vobs.jsonl"
ROTMOE_STATE_DIR="$OD2" ROTMOE_ANIMUS_DISTILLATE="$OD2/dist.md" sh "$ROOT/hooks/animus-observe.sh" vobs --once >/dev/null 2>&1
[ -f "$OD2/animus-queue.vobs" ] && bad "D14: the observer spoke over an empty sink" \
                                || ok "D14: the observer is silent over an empty sink"
rm -rf "$AD" "$OD" "$OD2" 2>/dev/null || :

# CONTROL for D11 -- a drifted lambda must be caught by the same arithmetic.
_cblk=$(sed -n '/<rot:formula>/,/<\/rot:formula>/p' "$ROOT/agents/rot-nova.md" | sed 's/lambda: 1.6/lambda: 9.9/')
_cdl=$(printf '%s\n' "$_cblk" | awk -F': *' '/lambda:/{c++; if (c==1) print $2}')
if numeq "$_cdl" "$(cent "$(pos 1 "$DEF_LAM")")"; then
  bad "CONTROL: a drifted default lambda (9.9) went unnoticed -- D11 cannot fail"
else
  ok "CONTROL: a drifted formula value IS caught by the re-derivation"
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
