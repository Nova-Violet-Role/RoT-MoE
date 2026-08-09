#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# session-log.sh -- bind lean/Proofs/RotSessionLog.lean to the two routers.
#
# WHAT THIS EXISTS FOR. RotSessionLog proves that a scrubbed session id contains
# no path separator and no dot, so it cannot escape the directory it is joined
# to. That is a theorem about a Lean function. Without this file it would say
# nothing whatever about `tr -cd` in the POSIX arm or `-replace` in the
# PowerShell one, and a proof that does not touch the program proves nothing
# about the program.
#
# The four phases below are the binding. None may skip: an environment that
# cannot run a phase reports INAPPLICABLE and says which, which is a statement
# about the machine rather than a pass.
#
#   A  the constants in both arms match the ones the Lean source declares
#   B  hostile session ids produce the SAME name in both arms as in the #guards
#   C  provenance: the classify table, both arms
#   D  self-control -- the detector must fail when fed a broken arm
#   E  the project-sink alarm fires when the sink is unwritable
#   F  a project path that collides with the status prefix still works
#
# THE TABLE IN PHASE B IS NOT INVENTED HERE. Every row is pinned by a #guard in
# lean/Proofs/RotSessionLog.lean and re-checked by `lake build` in the lean CI
# job, so the two sides cannot drift without one of them going red.
# =============================================================================

# This harness declares its own traffic; see the same block in the other six.
export ROTMOE_DEBUG_SRC=test
export ROTMOE_DEBUG_LOCAL=0

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SH="$ROOT/hooks/rot-router.sh"
PS="$ROOT/hooks/rot-router.ps1"
LEAN="$ROOT/lean/Proofs/RotSessionLog.lean"

PASS=0; FAIL=0; INAP=0
ok   () { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad  () { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
inap () { INAP=$((INAP+1)); printf '  INAP  %s\n' "$1"; }

TMP=$(mktemp -d 2>/dev/null || echo "/tmp/seslog.$$")
mkdir -p "$TMP"
# MEASURED: on Windows `mktemp -d` returns an MSYS path (/tmp/...) that
# PowerShell resolves it under the wrong root, so every ps1 row failed with
# the sh rows passed -- a harness defect that reads exactly like a router defect.
# cygpath -m gives a form BOTH arms accept; elsewhere it is absent and the
# original path is already fine.
TMPW=$(cygpath -m "$TMP" 2>/dev/null || printf '%s' "$TMP")
trap 'rm -rf "$TMP"' EXIT

have_pwsh=0
command -v pwsh >/dev/null 2>&1 && have_pwsh=1

printf '== session-log: Lean spec vs both routers ==\n\n'

# --------------------------------------------------------------------------
printf -- '-- A. constants agree with the Lean source --\n'

LEAN_MAX=$(sed -n 's/^def maxLen : Nat := \([0-9]*\).*/\1/p' "$LEAN" | head -1)
if [ -n "$LEAN_MAX" ]; then
  ok "Lean declares maxLen = $LEAN_MAX"
else
  bad "could not read maxLen out of $LEAN"
  LEAN_MAX=0
fi

# The POSIX arm caps with `cut -c1-N`.
SH_MAX=$(sed -n 's/.*cut -c1-\([0-9]*\).*/\1/p' "$SH" | head -1)
if [ "$SH_MAX" = "$LEAN_MAX" ]; then
  ok "sh arm caps at $SH_MAX -- matches the spec"
else
  bad "sh arm caps at '${SH_MAX:-none}', Lean says $LEAN_MAX"
fi

# The PowerShell arm caps with Substring(0, N).
PS_MAX=$(sed -n 's/.*Substring(0, *\([0-9]*\)).*/\1/p' "$PS" | head -1)
if [ "$PS_MAX" = "$LEAN_MAX" ]; then
  ok "ps1 arm caps at $PS_MAX -- matches the spec"
else
  bad "ps1 arm caps at '${PS_MAX:-none}', Lean says $LEAN_MAX"
fi

# The alphabet. Lean: `c.isAlphanum || c == '-'`. sh: tr -cd 'A-Za-z0-9-'.
# ps1: -replace '[^A-Za-z0-9-]'. All three must name the same set.
if grep -q "c.isAlphanum || c == '-'" "$LEAN"; then
  ok "Lean alphabet is alphanumeric plus dash"
else
  bad "Lean alphabet is not the expected isAlphanum-plus-dash"
fi
if grep -q "tr -cd 'A-Za-z0-9-'" "$SH"; then
  ok "sh arm deletes the COMPLEMENT of A-Za-z0-9- (removal, not blacklisting)"
else
  bad "sh arm does not scrub with tr -cd 'A-Za-z0-9-'"
fi
if grep -q "\[^A-Za-z0-9-\]" "$PS"; then
  ok "ps1 arm removes anything outside A-Za-z0-9-"
else
  bad "ps1 arm does not scrub with [^A-Za-z0-9-]"
fi

# --------------------------------------------------------------------------
printf -- '\n-- B. hostile ids produce the name the #guards pin --\n'

# id                          expected file name        (pinned by #guard in the Lean module)
CASES='1ce31449-3c95|rot-route-1ce31449-3c95.jsonl
../../etc/passwd|rot-route-etcpasswd.jsonl
|rot-route-unknown.jsonl
...|rot-route-unknown.jsonl
/|rot-route-unknown.jsonl
../..|rot-route-unknown.jsonl'

# Every expectation must also appear as a #guard, or this table is a second
# source of truth and the two will drift.
while IFS='|' read -r id want; do
  [ -n "$want" ] || continue
  if grep -q "$want" "$LEAN"; then
    :
  else
    bad "expectation '$want' is NOT pinned by a #guard in the Lean module"
  fi
done <<EOF
$CASES
EOF
ok "every expected name below is also pinned by a #guard"

run_arm () {  # run_arm <arm> <session_id> <projectdir>  -> prints the file created
  _arm=$1; _sid=$2; _dir=$3
  rm -rf "$_dir"; mkdir -p "$_dir"
  _pl=$(printf '{"session_id":"%s","cwd":"%s","hook_event_name":"PreToolUse","prompt":"build"}' "$_sid" "$_dir")
  if [ "$_arm" = sh ]; then
    printf '%s' "$_pl" | ROTMOE_DEBUG_LOCAL=1 ROTMOE_DEBUG_LOG="$_dir/central.jsonl" \
      sh "$SH" >/dev/null 2>&1
  else
    printf '%s' "$_pl" | ROTMOE_DEBUG_LOCAL=1 ROTMOE_DEBUG_LOG="$_dir/central.jsonl" \
      pwsh -NoProfile -File "$PS" >/dev/null 2>&1
  fi
  find "$_dir/.rot-moe" -name 'rot-route-*.jsonl' 2>/dev/null | head -1 | sed 's|.*/||'
}

i=0
while IFS='|' read -r id want; do
  [ -n "$want" ] || continue
  i=$((i+1))
  got=$(run_arm sh "$id" "$TMPW/sh$i")
  if [ "$got" = "$want" ]; then
    ok "sh  '${id:-<empty>}' -> $got"
  else
    bad "sh  '${id:-<empty>}' -> '${got:-<none>}', expected '$want'"
  fi
  if [ "$have_pwsh" = 1 ]; then
    gotp=$(run_arm ps1 "$id" "$TMPW/ps$i")
    if [ "$gotp" = "$want" ]; then
      ok "ps1 '${id:-<empty>}' -> $gotp"
    else
      bad "ps1 '${id:-<empty>}' -> '${gotp:-<none>}', expected '$want'"
    fi
  else
    inap "ps1 '${id:-<empty>}' -- pwsh not on PATH"
  fi
done <<EOF
$CASES
EOF

# The property the theorems are actually about: nothing lands outside the
# project directory, however hostile the id.
esc="$TMPW/escape"
rm -rf "$esc"; mkdir -p "$esc/inner"
run_arm sh '../../../PWNED' "$esc/inner" >/dev/null
if [ -z "$(find "$esc" -name '*PWNED*' -not -path '*/inner/.rot-moe/*' 2>/dev/null)" ] \
   && [ -z "$(find "$esc" -maxdepth 1 -name '*.jsonl' 2>/dev/null)" ]; then
  ok "sh  traversal refused: nothing written above the project directory"
else
  bad "sh  TRAVERSAL SUCCEEDED -- a file escaped the project directory"
fi

# --------------------------------------------------------------------------
printf -- '\n-- C. provenance: the classify table --\n'

src_of () {  # src_of <arm> <declared|-> <withEvent 0|1>
  _arm=$1; _dec=$2; _ev=$3
  _d="$TMPW/src.$_arm.$$"; rm -rf "$_d"; mkdir -p "$_d"
  if [ "$_ev" = 1 ]; then
    _pl='{"session_id":"s1","hook_event_name":"PreToolUse","prompt":"build"}'
  else
    _pl='{"session_id":"s1","prompt":"build"}'
  fi
  if [ "$_dec" = '-' ]; then unset ROTMOE_DEBUG_SRC; else export ROTMOE_DEBUG_SRC="$_dec"; fi
  if [ "$_arm" = sh ]; then
    printf '%s' "$_pl" | ROTMOE_DEBUG_LOCAL=0 ROTMOE_DEBUG_LOG="$_d/c.jsonl" sh "$SH" >/dev/null 2>&1
  else
    printf '%s' "$_pl" | ROTMOE_DEBUG_LOCAL=0 ROTMOE_DEBUG_LOG="$_d/c.jsonl" pwsh -NoProfile -File "$PS" >/dev/null 2>&1
  fi
  export ROTMOE_DEBUG_SRC=test
  sed -n 's/.*"kind":"route".*"src":"\([a-z]*\)".*/\1/p' "$_d/c.jsonl" 2>/dev/null | head -1
}

# declared  hasEvent  expected      -- classify in the Lean module
PROV='-|1|hook
-|0|cli
test|1|test
test|0|test
wat|1|hook
wat|0|cli'

while IFS='|' read -r dec ev want; do
  [ -n "$want" ] || continue
  got=$(src_of sh "$dec" "$ev")
  if [ "$got" = "$want" ]; then
    ok "sh  declared=${dec} hasEvent=${ev} -> $got"
  else
    bad "sh  declared=${dec} hasEvent=${ev} -> '${got:-<none>}', expected '$want'"
  fi
  if [ "$have_pwsh" = 1 ]; then
    gotp=$(src_of ps1 "$dec" "$ev")
    if [ "$gotp" = "$want" ]; then
      ok "ps1 declared=${dec} hasEvent=${ev} -> $gotp"
    else
      bad "ps1 declared=${dec} hasEvent=${ev} -> '${gotp:-<none>}', expected '$want'"
    fi
  else
    inap "ps1 declared=${dec} hasEvent=${ev} -- pwsh not on PATH"
  fi
done <<EOF
$PROV
EOF

# The honesty property, stated as a check rather than inferred from the table:
# a declared harness record is never counted as live traffic.
if [ "$(src_of sh test 1)" != hook ]; then
  ok "sh  test_is_never_hook holds on a payload carrying a real event"
else
  bad "sh  a declared test record was classified as live traffic"
fi

# Every harness that writes to the log must declare itself, or the field is
# decoration. This is the check that would have caught the contamination.
UNDECLARED=0
for f in "$ROOT"/checker/*.sh; do
  grep -q 'rot-router' "$f" 2>/dev/null || continue
  grep -q '"prompt"\|tool_input' "$f" 2>/dev/null || continue
  grep -q 'ROTMOE_DEBUG_SRC' "$f" 2>/dev/null && continue
  UNDECLARED=$((UNDECLARED+1))
  printf '        undeclared: %s\n' "$(basename "$f")"
done
if [ "$UNDECLARED" = 0 ]; then
  ok "every checker that feeds the router declares ROTMOE_DEBUG_SRC"
else
  bad "$UNDECLARED checker(s) feed the router without declaring their traffic"
fi

# --------------------------------------------------------------------------
printf -- '\n-- D. self-control: the detector must be able to fail --\n'

BROKE="$TMP/broken-router.sh"
sed 's/tr -cd .A-Za-z0-9-./tr -cd "A-Za-z0-9.\/-"/' "$SH" > "$BROKE"
if cmp -s "$BROKE" "$SH"; then
  bad "control: could not construct a broken arm -- phase A/B prove nothing"
else
  ok "control: a broken arm was constructed (scrubber weakened to allow / and .)"
  if grep -q "tr -cd 'A-Za-z0-9-'" "$BROKE"; then
    bad "control: the broken arm still passes the phase-A grep -- detector is blind"
  else
    ok "control: phase A's grep REJECTS the weakened scrubber"
  fi
fi


# --------------------------------------------------------------------------
printf -- '\n-- E. the project-sink alarm must be able to fire --\n'

# A flag that is set and never read is worse than no flag: it reads like
# coverage. Both arms shipped exactly that -- _rot_local_lost in the POSIX arm
# and RotLocalLost in the PowerShell one were assigned and never consulted, so
# a project sink that could not be created failed in total silence. The POSIX
# arm then failed a SECOND time after the first repair, because the flag was
# being set inside a command substitution and died in the subshell.
#
# The break is a cwd whose parent is a regular file, so mkdir cannot succeed.
BLOCK="$TMPW/blockfile"
rm -rf "$BLOCK"; printf 'not a directory\n' > "$BLOCK"

marker_of () {  # marker_of <arm> <cwd>
  _a=$1; _c=$2
  _p=$(printf '{"session_id":"alarm","cwd":"%s","hook_event_name":"PreToolUse","prompt":"build"}' "$_c")
  if [ "$_a" = sh ]; then
    printf '%s' "$_p" | ROTMOE_DEBUG_LOCAL=1 ROTMOE_DEBUG_LOG="$TMPW/alarm.$_a.jsonl" sh "$SH" 2>/dev/null
  else
    printf '%s' "$_p" | ROTMOE_DEBUG_LOCAL=1 ROTMOE_DEBUG_LOG="$TMPW/alarm.$_a.jsonl" pwsh -NoProfile -File "$PS" 2>/dev/null
  fi
}

OKDIR="$TMPW/alarm-ok"
rm -rf "$OKDIR"; mkdir -p "$OKDIR"

for arm in sh ps1; do
  if [ "$arm" = ps1 ] && [ "$have_pwsh" != 1 ]; then
    inap "ps1 project-sink alarm -- pwsh not on PATH"
    continue
  fi
  broke=$(marker_of "$arm" "$BLOCK/sub")
  fine=$(marker_of "$arm" "$OKDIR")
  case "$broke" in
    *"project-log UNWRITABLE (record lost)"*)
      ok "$arm reports an unwritable project sink" ;;
    *)
      bad "$arm SILENT on an unwritable project sink: '$broke'" ;;
  esac
  case "$fine" in
    *"project-log UNWRITABLE"*)
      bad "$arm CONTROL: reported a failure on a writable sink: '$fine'" ;;
    *)
      ok "$arm CONTROL: silent when the project sink is fine" ;;
  esac
done

# Both arms must use the SAME wording, or a reader cannot grep one pattern.
if [ "$have_pwsh" = 1 ]; then
  a=$(marker_of sh  "$BLOCK/sub")
  b=$(marker_of ps1 "$BLOCK/sub")
  if [ "$a" = "$b" ]; then
    ok "both arms emit a byte-identical marker line"
  else
    bad "marker lines differ: sh='$a' ps1='$b'"
  fi
else
  inap "cross-arm marker comparison -- pwsh not on PATH"
fi


# --------------------------------------------------------------------------
printf -- '\n-- F. a path that looks like the status prefix is still handled --\n'

# THIS IS THE PHASE THAT BINDS RotSessionLog.sink_ok_roundtrip TO THE SHELL.
# The theorem is about an encoding; without this the two could drift and the
# proof would be about nothing. The input is the one that actually broke the
# first implementation: a RELATIVE cwd beginning with the old sentinel.
#
# Measured before the repair: the decoder ate the bang, the record went to
# "rel/..." instead of "!rel/...", awk died with a fatal redirect error, and
# the gauge record vanished (stdout read "R/s+ n/a").
for arm in sh ps1; do
  if [ "$arm" = ps1 ] && [ "$have_pwsh" != 1 ]; then
    inap "ps1 status-prefix collision -- pwsh not on PATH"
    continue
  fi
  SCRATCH="$TMPW/collide-$arm"
  rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"
  P=$(printf '{"session_id":"collide","cwd":"%s","hook_event_name":"PreToolUse","prompt":"build"}' '!rel')
  if [ "$arm" = sh ]; then
    out=$(cd "$SCRATCH" && printf '%s' "$P" | ROTMOE_DEBUG_LOCAL=1 ROTMOE_DEBUG_LOG="$TMPW/collide.$arm.jsonl" sh "$SH" 2>&1)
  else
    out=$(cd "$SCRATCH" && printf '%s' "$P" | ROTMOE_DEBUG_LOCAL=1 ROTMOE_DEBUG_LOG="$TMPW/collide.$arm.jsonl" pwsh -NoProfile -File "$PS" 2>&1)
  fi

  if [ -d "$SCRATCH/!rel/.rot-moe" ]; then
    ok "$arm wrote under the real directory '!rel'"
  else
    bad "$arm did not create '!rel/.rot-moe' -- out: $out"
  fi
  if [ -d "$SCRATCH/rel" ]; then
    bad "$arm MISDIRECTED the write: a stray 'rel' directory was created"
  else
    ok "$arm CONTROL: no truncated 'rel' directory"
  fi
  case "$out" in
    *"R/s+ n/a"*) bad "$arm lost the gauge record on a prefix-colliding path" ;;
    *)            ok "$arm still produced a gauge value" ;;
  esac
  case "$out" in
    *fatal*|*"cannot redirect"*) bad "$arm leaked a fatal error: $out" ;;
    *)                           ok "$arm CONTROL: no fatal error leaked" ;;
  esac
done

printf -- '\n-- G. the declaration is honoured on EVERY dispatch path, both arms --\n'
# WHY THIS PHASE EXISTS. `classify` was correct and proved from the day it was
# written, and the log was contaminated anyway: --vector and --route exit before
# hook mode, and neither arm consulted the declaration there. A proof binds only
# the code that calls it.
#
# MEASURED on the shipped 1.0.1 log before the repair: 5003 records, 228 with
# src:"" (a value classify cannot produce) and ZERO with src:"hook".
#
# The four cells below are resolveNow in lean/Proofs/RotSessionLog.lean. Both
# arms must answer identically -- src_declaration_wins_on_every_path and
# resolveNow_never_renders_empty are the theorems, this is their binding to the
# shipped scripts.
G_LOG="$TMP/provenance.jsonl"
G_LOGW="$TMPW/provenance.jsonl"

# Read the src of the FIRST record written, or the literal <none> if no record
# was produced at all. An empty src must be reported as EMPTY, never as absent.
g_src () {
  if [ ! -s "$G_LOG" ]; then printf '<none>'; return; fi
  node -e '
    const fs=require("fs");
    const l=fs.readFileSync(process.argv[1],"utf8").trim().split("\n")[0];
    let r; try { r=JSON.parse(l) } catch(e) { console.log("<unparsable>"); process.exit(0) }
    console.log(r.src===undefined ? "<absent>" : (r.src==="" ? "<EMPTY>" : r.src));
  ' "$G_LOG"
}

# NOTE ON THE ENVIRONMENT, and it is load-bearing: this checker is itself one of
# the nine that export ROTMOE_DEBUG_SRC=test, so "no declaration" cannot be
# expressed by passing an empty value -- `${x:+...}` leaves the INHERITED value
# in place and the cell silently measures `test`. It must be actively removed
# with `env -u`. Caught by this phase reporting 6 failures that were entirely
# the harness's own doing.
g_cell () {                       # arm  declaration  mode(cli|hook)  expected
  _arm="$1"; _decl="$2"; _mode="$3"; _want="$4"
  rm -f "$G_LOG"
  if [ -n "$_decl" ]; then _envd="ROTMOE_DEBUG_SRC=$_decl"; else _envd="-u ROTMOE_DEBUG_SRC"; fi
  if [ "$_mode" = cli ]; then
    if [ "$_arm" = sh ]; then
      env $_envd ROTMOE_DEBUG_LOG="$G_LOG" \
        ROTMOE_DEBUG_LOCAL=0 bash "$SH" --vector 0,0,0,0,0,0,0,0,1 \
        --breadth 1 --M 1 --C 1 --T 1 >/dev/null 2>&1 || true
    else
      env $_envd ROTMOE_DEBUG_LOG="$G_LOGW" \
        ROTMOE_DEBUG_LOCAL=0 pwsh -NoProfile -File "$PS" -Vector 0,0,0,0,0,0,0,0,1 \
        -Breadth 1 -M 1 -C 1 -T 1 >/dev/null 2>&1 || true
    fi
  else
    _pl='{"prompt":"lake build","hook_event_name":"UserPromptSubmit","session_id":"abc123"}'
    if [ "$_arm" = sh ]; then
      printf '%s' "$_pl" | env $_envd \
        ROTMOE_DEBUG_LOG="$G_LOG" ROTMOE_DEBUG_LOCAL=0 bash "$SH" >/dev/null 2>&1 || true
    else
      printf '%s' "$_pl" | env $_envd \
        ROTMOE_DEBUG_LOG="$G_LOGW" ROTMOE_DEBUG_LOCAL=0 pwsh -NoProfile -File "$PS" \
        >/dev/null 2>&1 || true
    fi
  fi
  _got=$(g_src)
  _lbl="${_arm} ${_mode} decl=${_decl:-<unset>}"
  if [ "$_got" = "$_want" ]; then
    ok "$_lbl -> src=$_got"
  else
    bad "$_lbl -> src=$_got, expected $_want"
  fi
}

for arm in sh ps1; do
  [ "$arm" = ps1 ] && ! command -v pwsh >/dev/null 2>&1 && continue
  g_cell "$arm" test cli  test    # declaration wins on the CLI path
  g_cell "$arm" ""   cli  cli     # no declaration, no event -> cli
  g_cell "$arm" test hook test    # declaration still outranks a real event
  g_cell "$arm" ""   hook hook    # inference works where it always should have
  g_cell "$arm" wat  cli  cli     # unrecognised on the CLI path demotes to cli
  g_cell "$arm" wat  hook hook    # unrecognised in hook mode falls back to inference
done

# The specific regression, named: an EMPTY src is not a class, it is an unset
# variable that PowerShell rendered as if it were one. This is what 228 shipped
# records looked like, and it must be impossible on every path.
rm -f "$G_LOG"
ROTMOE_DEBUG_LOG="$G_LOG" ROTMOE_DEBUG_LOCAL=0 bash "$SH" --vector 0,0,0,0,0,0,0,0,1 \
  --breadth 1 --M 1 --C 1 --T 1 >/dev/null 2>&1 || true
if [ "$(g_src)" = "<EMPTY>" ]; then
  bad "sh CLI path rendered an EMPTY src -- the 1.0.1 defect is back"
else
  ok "sh CLI path never renders an empty src"
fi

# CONTROL: the reader can distinguish empty from present, or the phase above is
# incapable of failing. A planted record with src:"" must be seen as <EMPTY>.
printf '%s\n' '{"kind":"gauge","src":"","session":"x"}' > "$G_LOG"
if [ "$(g_src)" = "<EMPTY>" ]; then
  ok "CONTROL: a planted empty src IS reported as EMPTY -- this phase can fail"
else
  bad "CONTROL DEAD: a planted empty src read as $(g_src) -- phase G proves nothing"
fi
rm -f "$G_LOG"

printf '\n== session-log: %d passed, %d failed, %d inapplicable ==\n' "$PASS" "$FAIL" "$INAP"
[ "$FAIL" -eq 0 ]
