#!/usr/bin/env sh
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# env-wiring.sh -- proves the CONFIGURATION SPECTRUM is wired end to end:
#
#     hooks/rot-voice.dtd      the declared vocabulary -- THE FULCRUM
#            | generates
#     engine/rot.env.example   the shipped config file, DERIVED not authored
#            | loaded by
#     hooks/rot-env.sh         ORGAN 7, the POSIX loader
#     hooks/rot-env.ps1        ORGAN 7, the PowerShell twin -- SAME file, same keys
#            | sourced by
#     engine/rot.bashrc        the shell activation (macOS / Linux / git-bash)
#
# Both shipped artifacts live beside engine/rot-lean.md ON PURPOSE: ORGAN 1 is
# the specification of what the packet does, and the configuration surface is
# part of that specification, not loose furniture at the repository root.
#            | configures
#     hooks/rot-router.sh      the router that reads ROTMOE_*
#
# WHY THIS EXISTS. `checker/env-layer.sh` proves the LOADER obeys its three
# laws. Nothing proved that the packet SHIPS a config file at all, and it did
# not: the loader read `rot.env` from three locations while the repository
# tracked no such file and no activation for it. A loader with nothing to load
# is an organ with no blood supply.
#
# WHY THE FILE IS GENERATED. The engine spec drifted from the router by six
# undocumented stems, and nothing caught it because the two lists were
# TRANSCRIBED. A transcription drifts; a derivation cannot. `rot.env.example`
# is emitted from the DTD by `--emit` below, and W2 asserts the tracked file is
# byte-identical to a fresh emission. Add an ENV.35 entity without regenerating
# and this gate fails -- which is the whole point.
#
#   bash checker/env-wiring.sh          run the assertions
#   bash checker/env-wiring.sh --emit   print the canonical rot.env.example
#
set -u

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DTD="$REPO/hooks/rot-voice.dtd"
ENVEX="$REPO/engine/rot.env.example"
BASHRC="$REPO/engine/rot.bashrc"
LOADER="$REPO/hooks/rot-env.sh"

pass=0; fail=0
ok   () { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad  () { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; }

# --- THE GENERATOR ------------------------------------------------------------
# Reads every `<!ENTITY ENV.n "NAME|TYPE|DESCRIPTION">` out of the DTD and emits
# the config file. Three of those entities (ENV.25, ENV.33, ENV.34) carry a
# DESCRIPTION that spans lines, so this is a state machine, not a line filter --
# a line filter would silently truncate three of the thirty-four.
#
# No backslash escapes anywhere: this repository has twice corrupted a generated
# file because a backslash was eaten in transport (a 0x01 byte, and an awk
# character class that matched nothing). Quote characters are built with
# sprintf("%c", 34) instead.
emit_env () {
  awk '
    BEGIN { q = sprintf("%c", 34); acc = ""; n = 0 }
    {
      line = $0
      if (index(line, "<!ENTITY ENV.") > 0) { acc = line }
      else if (acc != "")                   { acc = acc " " line }
      if (acc == "") next
      # an entity is complete when it carries the closing quote-then-angle
      if (index(acc, q ">") == 0) next

      # payload = the text between the FIRST quote and the LAST quote
      first = index(acc, q)
      body  = substr(acc, first + 1)
      last  = 0
      for (i = length(body); i > 0; i--) { if (substr(body, i, 1) == q) { last = i; break } }
      if (last > 1) body = substr(body, 1, last - 1)

      nf = split(body, f, "|")
      if (nf >= 2) {
        name = f[1]; type = f[2]; desc = ""
        for (i = 3; i <= nf; i++) { desc = (desc == "" ? f[i] : desc " | " f[i]) }
        gsub(/^[ \t]+|[ \t]+$/, "", name)
        gsub(/^[ \t]+|[ \t]+$/, "", type)
        gsub(/^[ \t]+|[ \t]+$/, "", desc)
        gsub(/[ \t]+/, " ", desc)
        if (index(name, "ROTMOE_") == 1) {
          n++
          names[n] = name; types[n] = type; descs[n] = desc
        }
      }
      acc = ""
    }
    END {
      print "# ============================================================================="
      print "# rot.env -- RoT MoE configuration."
      print "#"
      print "# GENERATED FROM hooks/rot-voice.dtd -- DO NOT EDIT BY HAND."
      print "#   regenerate:  bash checker/env-wiring.sh --emit > engine/rot.env.example"
      print "#   verified by: bash checker/env-wiring.sh   (W2 fails if this file drifts)"
      print "#"
      print "# HOW TO USE IT. Copy, then uncomment only what you want to change:"
      print "#   per project : <project>/.rot-moe/rot.env"
      print "#   per operator: $XDG_CONFIG_HOME/rot-moe/rot.env   (~/.config/rot-moe/rot.env)"
      print "#   explicit    : export ROTMOE_ENV=/path/to/rot.env"
      print "#"
      print "# Every line here is COMMENTED OUT on purpose: copying this file verbatim"
      print "# changes nothing. W5 asserts that, so the shipped default stays inert."
      print "#"
      print "# THREE LAWS the loader enforces (hooks/rot-env.sh:21-35):"
      print "#   1. NO EXPANSION. The value is data. $(rm -rf ~) exports as literal text."
      print "#   2. DECLARED-ONLY. A key not declared below does not exist to the parser,"
      print "#      so a rot.env can never reach PATH, LD_PRELOAD or PS1."
      print "#   3. UNSET-ONLY. A live export outranks every file; the first file wins."
      print "#"
      print "# Works identically on macOS, Linux and Windows: the POSIX loader"
      print "# (hooks/rot-env.sh) and the PowerShell loader (hooks/rot-env.ps1) read"
      print "# THIS ONE FILE FORMAT. W7 asserts both arms agree on it."
      printf "# %d keys declared.\n", n
      print "# ============================================================================="
      for (i = 1; i <= n; i++) {
        print ""
        printf "# %s\n", names[i]
        printf "#   type: %s\n", types[i]
        if (descs[i] != "") printf "#   %s\n", descs[i]
        # ROTMOE_ENV and ROTMOE_HOME decide WHICH FILE and WHICH CODE run. Law 2
        # refuses them from inside a file -- a locator cannot relocate itself.
        if (names[i] == "ROTMOE_ENV" || names[i] == "ROTMOE_HOME") {
          print "#   REFUSED FROM A FILE -- export it in the shell instead."
          printf "#   export %s=...\n", names[i]
        } else {
          printf "#%s=\n", names[i]
        }
      }
    }
  ' "$DTD"
}

if [ "${1:-}" = "--emit" ]; then emit_env; exit 0; fi

echo "=== env wiring: hooks/rot-voice.dtd -> rot.env.example -> rot.bashrc -> router ==="

# --- W1: the fulcrum is readable and NOT empty (anti-vacuity) -----------------
DECL=$(grep -oE 'ROTMOE_[A-Z_]+' "$DTD" 2>/dev/null | sort -u | grep -c .)
if [ "${DECL:-0}" -ge 30 ]; then
  ok "W1 the DTD declares $DECL distinct ROTMOE_ names (the vocabulary is real)"
else
  bad "W1 the DTD declared only ${DECL:-0} names -- every assertion below would be vacuous"
fi

# --- W2: THE BINDING. the shipped file IS the derivation ---------------------
if [ ! -f "$ENVEX" ]; then
  bad "W2 rot.env.example is not shipped -- ORGAN 7 loads a file the packet never provides"
else
  TMPG=$(mktemp); emit_env > "$TMPG" 2>/dev/null
  if cmp -s "$TMPG" "$ENVEX"; then
    ok "W2 rot.env.example is byte-identical to a fresh emission from the DTD"
  else
    bad "W2 rot.env.example DRIFTED from the DTD -- regenerate: bash checker/env-wiring.sh --emit > engine/rot.env.example"
    diff "$ENVEX" "$TMPG" 2>/dev/null | head -8 | sed 's/^/      /'
  fi
  rm -f "$TMPG"
fi

# --- W3: every declared key is present, none invented ------------------------
if [ -f "$ENVEX" ]; then
  MISS=0; EXTRA=0
  for k in $(grep -oE 'ROTMOE_[A-Z_]+' "$DTD" | sort -u); do
    grep -q "^# *$k\$" "$ENVEX" || MISS=$((MISS+1))
  done
  for k in $(grep -oE '^#?ROTMOE_[A-Z_]+' "$ENVEX" | tr -d '#' | sort -u); do
    grep -q "$k" "$DTD" || EXTRA=$((EXTRA+1))
  done
  [ "$MISS" -eq 0 ]  && ok "W3a every DTD-declared key appears in rot.env.example" \
                     || bad "W3a $MISS declared key(s) missing from rot.env.example"
  [ "$EXTRA" -eq 0 ] && ok "W3b rot.env.example invents no key the DTD does not declare" \
                     || bad "W3b rot.env.example carries $EXTRA undeclared key(s)"
fi

# --- W4: the two self-referential keys are documented as REFUSED -------------
if [ -f "$ENVEX" ]; then
  R=0
  for k in ROTMOE_ENV ROTMOE_HOME; do
    grep -q "REFUSED FROM A FILE" "$ENVEX" || R=$((R+1))
    grep -qE "^#?$k=" "$ENVEX" && R=$((R+1))   # must NOT appear as a settable line
  done
  [ "$R" -eq 0 ] && ok "W4 ROTMOE_ENV and ROTMOE_HOME are documented as refused, not offered as settings" \
                 || bad "W4 a locator key is offered as a file setting ($R problem(s)) -- law 2 says it cannot work"
fi

# --- W5: the shipped default is INERT ----------------------------------------
if [ -f "$ENVEX" ]; then
  ACTIVE=$(grep -cE '^[A-Za-z_]+=' "$ENVEX")
  [ "$ACTIVE" -eq 0 ] && ok "W5 rot.env.example has 0 active assignments -- copying it changes nothing" \
                      || bad "W5 rot.env.example carries $ACTIVE ACTIVE assignment(s) -- copying it would silently reconfigure the router"
fi

# --- W6: the activation exists and is portable -------------------------------
if [ ! -f "$BASHRC" ]; then
  bad "W6 rot.bashrc is not shipped -- there is no documented way to activate the config"
else
  if sh -n "$BASHRC" 2>/dev/null; then
    ok "W6a rot.bashrc parses under POSIX sh (portable to macOS, Linux and git-bash)"
  else
    bad "W6a rot.bashrc is not POSIX-clean -- sh -n refuses it"
  fi
  if grep -q "rot-env.sh" "$BASHRC"; then
    ok "W6b rot.bashrc binds to the ORGAN 7 loader by name"
  else
    bad "W6b rot.bashrc never references hooks/rot-env.sh -- it is not wired to the loader"
  fi
  # Grepping for the word "bash" would be a broken instrument: the file is NAMED
  # rot.bashrc and its own comments discuss bash. Test for the CONSTRUCTS that
  # actually break dash and zsh, ignoring comment lines.
  BISM=$(grep -vE '^[[:space:]]*#' "$BASHRC" \
         | grep -nE '\[\[|BASH_SOURCE|declare -|^[[:space:]]*local |=\(|\$\{[A-Za-z_]+,,\}|^[[:space:]]*source ' \
         | head -5)
  if [ -z "$BISM" ]; then
    ok "W6c rot.bashrc uses no bash-only construct ([[, arrays, BASH_SOURCE, local, source)"
  else
    bad "W6c rot.bashrc contains bash-only construct(s) -- dash and zsh would fail:"
    printf '%s\n' "$BISM" | sed 's/^/      /'
  fi
  # W6d: it must actually WORK when sourced by a POSIX shell, not merely parse.
  W6OUT=$(sh -c '. "$1" "$2" >/dev/null 2>&1; printf "%s" "${ROTMOE_HOME:-unset}"' _ "$BASHRC" "$REPO" 2>/dev/null)
  if [ "$W6OUT" = "$REPO" ]; then
    ok "W6d sourcing rot.bashrc in a POSIX shell resolves and exports ROTMOE_HOME"
  else
    bad "W6d sourcing rot.bashrc did not export ROTMOE_HOME (got '$W6OUT')"
  fi
  # W6e: and it must define the loader it advertises.
  W6FN=$(sh -c '. "$1" "$2" >/dev/null 2>&1; command -v rot_env_load >/dev/null 2>&1 && printf yes || printf no' _ "$BASHRC" "$REPO" 2>/dev/null)
  [ "$W6FN" = "yes" ] && ok "W6e after activation, rot_env_load is defined in the shell" \
                      || bad "W6e activation did not bring rot_env_load into scope"
fi

# --- W7: BOTH loader arms accept the same file -------------------------------
# The whole cross-platform claim rests on this. If the ps1 loader parsed a
# different shape, a Windows box without bash would silently ignore the operator
# configuration that macOS honours.
PROJ=$(mktemp -d); mkdir -p "$PROJ/.rot-moe"
printf 'ROTMOE_PROOF_STALE_MIN=77\nROTMOE_TOKEN_PCT=13\nPATH=/evil\n' > "$PROJ/.rot-moe/rot.env"
SH_OUT=$(
  CLAUDE_PLUGIN_ROOT="$REPO" sh -c '. "$1/hooks/rot-env.sh"; rot_env_load "$2" >/dev/null 2>&1; printf "%s|%s|%s" "${ROTMOE_PROOF_STALE_MIN:-unset}" "${ROTMOE_TOKEN_PCT:-unset}" "${PATH}"' _ "$REPO" "$PROJ" 2>/dev/null
)
SH_MIN=$(printf '%s' "$SH_OUT" | cut -d'|' -f1)
SH_PCT=$(printf '%s' "$SH_OUT" | cut -d'|' -f2)
SH_PATH=$(printf '%s' "$SH_OUT" | cut -d'|' -f3)
if [ "$SH_MIN" = "77" ] && [ "$SH_PCT" = "13" ]; then
  ok "W7a the POSIX loader honours a rot.env written in the shipped shape (77/13)"
else
  bad "W7a the POSIX loader did NOT apply the shipped shape (got '$SH_MIN'/'$SH_PCT')"
fi
case "$SH_PATH" in
  /evil) bad "W7b LAW 2 BREACHED -- a rot.env reached PATH" ;;
  *)     ok  "W7b the undeclared PATH key was ignored, as law 2 requires" ;;
esac
if command -v pwsh >/dev/null 2>&1 && [ -f "$REPO/hooks/rot-env.ps1" ]; then
  # PowerShell cannot read a POSIX path. Handing it /tmp/tmp.XXXX makes it look
  # for C:\tmp\tmp.XXXX, find nothing, and report a divergence that does not
  # exist -- this checker did exactly that on its first run. cygpath -m converts
  # when it is available; elsewhere (macOS, Linux) the path is already native.
  winpath () { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
  W_REPO=$(winpath "$REPO"); W_PROJ=$(winpath "$PROJ")
  PS_MIN=$(pwsh -NoProfile -Command "
      \$env:CLAUDE_PLUGIN_ROOT='$W_REPO'
      . '$W_REPO/hooks/rot-env.ps1'
      Invoke-RotEnvLoad '$W_PROJ' | Out-Null
      if (\$env:ROTMOE_PROOF_STALE_MIN) { \$env:ROTMOE_PROOF_STALE_MIN } else { 'unset' }
    " 2>/dev/null | tr -d '\r\n ')
  if [ "$PS_MIN" = "77" ]; then
    ok "W7c the PowerShell loader reads the SAME file to the same value (77) -- one config, three OSes"
  else
    bad "W7c ARM DIVERGENCE: the POSIX loader read 77, the PowerShell loader read '$PS_MIN' from the same rot.env"
  fi
else
  printf 'SKIP  W7c no pwsh on this host -- the PowerShell arm could not be compared\n'
fi
rm -rf "$PROJ"

# --- CONTROLS: an alarm nobody has tripped is an untested alarm ---------------
echo "--- controls ---"

# C1: a new DTD entity that nobody regenerated MUST break W2.
CTL=$(mktemp -d); cp "$DTD" "$CTL/dtd"
printf '<!ENTITY ENV.99 "ROTMOE_CONTROL_KEY|0 or 1|planted by the control">\n' >> "$CTL/dtd"
C1=$(DTD="$CTL/dtd" awk 'BEGIN{q=sprintf("%c",34)} index($0,"ROTMOE_CONTROL_KEY")>0 {n++} END{print n+0}' "$CTL/dtd")
if [ "$C1" -ge 1 ]; then
  TMPC=$(mktemp); DTD_SAVE="$DTD"; DTD="$CTL/dtd"; emit_env > "$TMPC" 2>/dev/null; DTD="$DTD_SAVE"
  if grep -q "ROTMOE_CONTROL_KEY" "$TMPC"; then
    if cmp -s "$TMPC" "$ENVEX"; then
      bad "C1 CONTROL DID NOT FIRE: a planted DTD key produced a file identical to the shipped one"
    else
      ok "C1 control: a planted DTD entity changes the emission, so W2 would catch an un-regenerated file"
    fi
  else
    bad "C1 CONTROL BROKEN: the generator ignored a planted entity -- it may be ignoring real ones too"
  fi
  rm -f "$TMPC"
else
  bad "C1 CONTROL BROKEN: could not plant a test entity"
fi
rm -rf "$CTL"

# C2: an active assignment MUST break W5.
CTL2=$(mktemp); cp "$ENVEX" "$CTL2" 2>/dev/null; printf 'ROTMOE_VOICE=0\n' >> "$CTL2"
A2=$(grep -cE '^[A-Za-z_]+=' "$CTL2" 2>/dev/null)
[ "${A2:-0}" -ge 1 ] && ok "C2 control: an uncommented assignment is detected by the W5 probe" \
                     || bad "C2 CONTROL DID NOT FIRE: the W5 probe cannot see an active assignment"
rm -f "$CTL2"

# C3: the generator must not silently emit nothing.
G=$(emit_env 2>/dev/null | grep -c '^# ROTMOE_')
[ "$G" -ge 30 ] && ok "C3 control: the generator emits $G key blocks (a silent empty emission would pass W2 against an empty file)" \
                || bad "C3 CONTROL: the generator emitted only $G key blocks"

printf '\n== env wiring: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
