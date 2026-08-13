#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# PROFILE BINDING -- the Lean lane tables must equal the spec they were read from
#
# WHY THIS EXISTS. `lean/Proofs/RotAbility.lean` carries three lane profiles as
# tables of ℚ: `creativeLam`, `empathicLam`, `predictiveLam`. They are not
# invented -- each is transcribed from `engine/rot-lean.md` §4. But transcription
# is exactly the operation that rots: the spec gets retuned, the Lean table does
# not, and the theorems keep proving things about numbers nobody ships any more.
#
# Measured 2026-08-03: NOTHING in this repo bound them. `gauge-cross.sh` binds
# the FORGE vector to the router's `LAMBDAS`/`MUS`, because the router executes
# those. The lane profiles are never executed by the router -- the hook always
# gauges on FORGE -- so they had no counterpart anywhere and could drift from the
# spec forever without a single check going red. A table that nothing binds is
# decoration with a theorem attached.
#
# WHAT IS COMPARED. For each lane, every lens the §4 block lists must carry the
# same λ in Lean. The ninth lens is the interesting case: §4's tables predate it
# and list eight rows, so Claude is absent there. Lean uses his §2 DEFAULT
# instead -- and that default is PARSED FROM §2, never hardcoded here, so moving
# it in the spec moves this check with it.
#
# Exit: 0 pass, 1 fail, 2 refuse (cannot measure), 3 skip.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

SPEC="engine/rot-lean.md"
LEAN="lean/Proofs/RotAbility.lean"
pass=0; fail=0

ok()   { pass=$((pass+1)); echo "PASS  $1"; }
bad()  { fail=$((fail+1)); [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=profile-bind::%s\n' "$*"; echo "FAIL  $1"; }

for f in "$SPEC" "$LEAN"; do
  [ -f "$f" ] || { echo "REFUSE: $f not found -- cannot measure"; exit 2; }
done

# --- the §2 default for the ninth lens, parsed, never assumed ----------------
# §2 row:  | 🧭 | **Claude** | Praxis × ... | 1.5 | 1.05 | 0.20-0.30 | **FORGE** |
CLAUDE_DEF=$(awk -F'|' '
  /\*\*Claude\*\*/ && NF > 6 {
    v=$5; gsub(/[^0-9.]/,"",v);
    if (v != "") { print v; exit }
  }' "$SPEC")
if [ -z "$CLAUDE_DEF" ]; then
  echo "REFUSE: could not parse Claude's §2 default λ from $SPEC."
  echo "        Refusing to fall back to a hardcoded number -- that is the very"
  echo "        drift this checker exists to catch."
  exit 2
fi
echo "note: Claude §2 default λ parsed from the spec = $CLAUDE_DEF"

# --- spec side: lens -> lambda for one §4 block ------------------------------
spec_profile() {   # spec_profile <BLOCK-HEADER-REGEX>
  awk -v hdr="$1" '
    $0 ~ hdr { on=1; next }
    on && /^Depth:/ { on=0 }
    on {
      s=$0
      while (match(s, /[A-Za-z_-]+\(l=[0-9.]+,mu=[0-9.]+\)/)) {
        tok=substr(s, RSTART, RLENGTH)
        split(tok, a, "(")
        name=a[1]
        lam=tok; sub(/^[^(]*\(l=/, "", lam); sub(/,.*$/, "", lam)
        gsub(/-/, "", name)
        print tolower(name) " " lam
        s=substr(s, RSTART+RLENGTH)
      }
    }' "$SPEC"
}

# --- lean side: lens -> lambda for one def ----------------------------------
lean_profile() {   # lean_profile <defname>
  awk -v d="def $1 :" '
    index($0, d)==1 { on=1; next }
    on && /^[^ |]/ && !/^$/ { on=0 }
    on && /^  \| \./ {
      line=$0
      sub(/^  \| \./, "", line)
      split(line, p, " ")
      name=p[1]
      val=line; sub(/^[^=]*=> */, "", val); sub(/ *--.*$/, "", val); gsub(/ /, "", val)
      if (val ~ /\//) { split(val, q, "/"); v = q[1]/q[2] } else { v = val+0 }
      printf "%s %.4f\n", name, v
    }' "$LEAN"
}

norm() { awk -v x="$1" 'BEGIN{ printf "%.4f", x+0 }'; }

check_profile() {  # check_profile <label> <spec-header-regex> <lean-def>
  local label="$1" hdr="$2" def="$3"
  local specrows leanrows n_spec n_lean
  specrows=$(spec_profile "$hdr")
  leanrows=$(lean_profile "$def")
  n_spec=$(printf '%s\n' "$specrows" | grep -c . )
  n_lean=$(printf '%s\n' "$leanrows" | grep -c . )

  # ANTI-VACUITY: a parser that matches nothing must never report success.
  if [ "$n_spec" -lt 8 ]; then
    bad "$label: parsed only $n_spec rows from the spec (expected >= 8) -- parser broken or spec moved"
    return
  fi
  if [ "$n_lean" -ne 9 ]; then
    bad "$label: parsed $n_lean rows from Lean $def (expected exactly 9)"
    return
  fi

  local bad_here=0
  while read -r lens lam; do
    [ -n "$lens" ] || continue
    local want have
    want=$(norm "$lam")
    have=$(printf '%s\n' "$leanrows" | awk -v l="$lens" '$1==l { print $2; exit }')
    if [ -z "$have" ]; then
      bad "$label: spec lists '$lens' but Lean $def has no such lens"
      bad_here=1
    elif [ "$want" != "$have" ]; then
      bad "$label: $lens spec λ=$want but Lean $def has $have"
      bad_here=1
    fi
  done <<< "$specrows"

  # the ninth lens: absent from §4, must equal the §2 default
  local claude_have claude_want
  claude_have=$(printf '%s\n' "$leanrows" | awk '$1=="claude" { print $2; exit }')
  claude_want=$(norm "$CLAUDE_DEF")
  if [ "$claude_have" != "$claude_want" ]; then
    bad "$label: Claude must carry his §2 default λ=$claude_want, Lean has $claude_have"
    bad_here=1
  fi

  [ "$bad_here" -eq 0 ] && ok "$label: all $n_spec spec rows + Claude's §2 default match Lean $def"
}

echo "=== profile binding: engine/rot-lean.md §4  <->  $LEAN ==="
check_profile "CREATIVE"   "^CREATIVE [(]Carnage lead[)]"   "creativeLam"
check_profile "EMPATHIC"   "^EMPATHIC [(]Violet lead[)]"    "empathicLam"
check_profile "PREDICTIVE" "^PREDICTIVE [(]Chroma lead[)]"  "predictiveLam"

# --- the lane lead must actually be the maximum, on the SPEC's own numbers ---
# Lean proves this over its tables; here it is re-derived from the spec text, so
# a spec retune that dethrones a lead is caught even before Lean is rebuilt.
lead_is_max() {   # lead_is_max <label> <spec-header> <expected-lead>
  local label="$1" hdr="$2" lead="$3"
  local rows top topname
  rows=$(spec_profile "$hdr")
  topname=$(printf '%s\n' "$rows" | sort -k2 -g -r | head -1 | awk '{print $1}')
  top=$(printf '%s\n' "$rows" | sort -k2 -g -r | head -1 | awk '{print $2}')
  if [ "$topname" = "$lead" ]; then
    ok "$label: the spec's own numbers make '$lead' the lead (λ=$top)"
  else
    bad "$label: spec says lead is '$lead' but the largest λ belongs to '$topname' ($top)"
  fi
}
lead_is_max "CREATIVE"   "^CREATIVE [(]Carnage lead[)]"  "carnage"
lead_is_max "EMPATHIC"   "^EMPATHIC [(]Violet lead[)]"   "violet"
lead_is_max "PREDICTIVE" "^PREDICTIVE [(]Chroma lead[)]" "chroma"

# --- CONTROLS: an alarm nobody has heard ring is not an alarm ---------------
echo "--- controls ---"
_ctl=$(spec_profile "^NO_SUCH_BLOCK_EVER")
if [ -z "$_ctl" ]; then
  ok "control: a missing spec block parses to zero rows (would trip anti-vacuity)"
else
  bad "control: a missing spec block returned rows -- the parser matches anything"
fi

_ctl2=$(lean_profile "noSuchLamTable")
if [ -z "$_ctl2" ]; then
  ok "control: a missing Lean table parses to zero rows"
else
  bad "control: a missing Lean table returned rows"
fi

# A wrong expected lead must FAIL, or lead_is_max proves nothing.
#
# The regex here MUST be the real, working one. An earlier version left stray
# `\(`...`\)` around it, so the block never matched, `spec_profile` returned
# nothing, and the control "passed" because the parser found zero rows -- not
# because a wrong lead was detected. A control that passes for the wrong reason
# is worse than no control: it certifies the alarm while proving nothing.
_before=$fail
lead_is_max "CONTROL" "^PREDICTIVE [(]Chroma lead[)]" "soleil" >/dev/null 2>&1
if [ "$fail" -gt "$_before" ]; then
  fail=$_before   # that failure was the control succeeding
  ok "control: naming the wrong lead is detected"
else
  bad "control: naming the wrong lead was NOT detected -- lead_is_max is decorative"
fi

# ---------------------------------------------------------------------------
# THE FALLBACK BRANCH WAS UNTESTED CODE, and a mutation proved it.
#
# `select_profile` ends in `*) LAMBDAS=$L_CONVERGENT; MUS=$M_CONVERGENT ;;`.
# Mutation H04 in checker/mutate-checker.sh detached `MUS` in exactly that
# branch and SURVIVED -- every checker stayed green while the fallback's quality
# multipliers were empty. Nothing here ever asked what an UNKNOWN profile does,
# so the branch could be broken in any way at all and no gate would notice.
#
# The claim it should satisfy is small and exact: an unrecognised profile name
# behaves as CONVERGENT, which is the router's documented default. Asserted by
# byte-comparing the two runs.
#
# AND the comparison is proved non-vacuous against a THIRD profile. Without that
# arm, a router that ignored `--profile` entirely would pass this check --
# everything would equal everything. STEALTH is the witness that the flag is
# read at all.
_ROUTER="hooks/rot-router.sh"
if [ -x "$_ROUTER" ] || [ -f "$_ROUTER" ]; then
  # COMMA-separated, and the first draft of this probe got it wrong in a way
  # worth recording: `--vector '1 0 1 ...'` is accepted but parsed as a SINGLE
  # lens, so the run reported `K=1 lenses=Nova` and the mu vector barely
  # participated. The probe then could not tell a detached mu vector from an
  # intact one -- it compared two nearly-degenerate runs and called them equal.
  # An instrument fed the wrong input shape is not a weaker instrument, it is a
  # different one, and this one was measuring almost nothing.
  _vec='1,0,1,0,1,0,1,0,1'
  # `--profile STEALTH` FIRST, and this is the whole instrument.
  #
  # A bare `--profile ZZZ` cannot see a broken fallback: the router already
  # mounts CONVERGENT at startup, so a fallback that assigns nothing at all
  # leaves exactly the CONVERGENT weights in place and looks correct. Measured
  # -- with the mu vector deliberately detached, bare-ZZZ read 0.74 and so did
  # the baseline. The bug was invisible because the correct answer was already
  # sitting in the variable.
  #
  # Mounting STEALTH first makes the fallback DO something: it must overwrite
  # both vectors, not just agree with what was there. Measured with the same
  # mutation: 0.67 against a baseline 0.74. The probe went from blind to sharp
  # by changing the starting state, not the assertion.
  _unknown=$(sh "$_ROUTER" --profile STEALTH --profile ZZZ_NOT_A_PROFILE --vector "$_vec" 2>/dev/null)
  _default=$(sh "$_ROUTER" --profile CONVERGENT        --vector "$_vec" 2>/dev/null)
  _other=$(sh   "$_ROUTER" --profile STEALTH           --vector "$_vec" 2>/dev/null)

  if [ -z "$_unknown" ] || [ -z "$_default" ]; then
    bad "fallback: the router produced NO output for one of the probes -- this check measured nothing"
  elif [ "$_default" = "$_other" ]; then
    bad "fallback: CONVERGENT and STEALTH are indistinguishable -- --profile is not being read, so the fallback test would be vacuous"
  elif [ "$_unknown" = "$_default" ]; then
    ok "fallback: an unknown profile behaves exactly as CONVERGENT (and STEALTH differs, so the probe discriminates)"
  else
    bad "fallback: an unknown profile does NOT fall back to CONVERGENT -- got [$_unknown] vs [$_default]"
  fi
else
  bad "fallback: $_ROUTER not found -- the fallback branch cannot be exercised"
fi

echo
echo "== profile binding: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
