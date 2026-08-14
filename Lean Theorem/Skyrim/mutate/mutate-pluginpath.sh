#!/usr/bin/env bash
# This file is part of RoT MoE -- shared Lean Theorem corpus.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# =======================================================================================
# Mutation suite for Proofs.Skyrim.PluginPath.
#
# A theorem that survives every plausible bad edit proves nothing. Each mutant below breaks
# ONE thing in the model and the build must go RED. A mutant that builds green is reported
# as SURVIVED and the theorem it should have killed is decoration.
#
# Three rules this harness obeys, because a mutation suite lies in the reassuring direction
# when it does not:
#   1. the mutation is ASSERTED PRESENT in the file before building. A patch that silently
#      fails to apply otherwise records as SURVIVED, which reads as "robust" but means
#      "nothing was tested". Counted needles, and a distinct DISCARDED status.
#   2. the stale .olean is DELETED before each build, because lake is incremental and will
#      happily not rebuild a module it believes is unchanged.
#   3. the run ends by restoring the original and rebuilding, so the tree is provably back
#      at green rather than assumed to be.
# =======================================================================================
set -u

cd "${LEAN_ROOT:-.}" || exit 9
SRC=Proofs/Skyrim/PluginPath.lean
OLEAN=.lake/build/lib/lean/Proofs/Skyrim/PluginPath.olean
BAK=/tmp/PluginPath.orig.lean

cp "$SRC" "$BAK" || exit 9
echo "baseline saved ($(wc -c < "$BAK") bytes)"

killed=0; survived=0; discarded=0

mutate () {
  local id="$1" needle="$2" replacement="$3" expect="$4"
  cp "$BAK" "$SRC"

  local n
  n=$(grep -F -c "$needle" "$SRC")
  if [ "$n" -ne 1 ]; then
    echo "$id DISCARDED - needle found $n times, expected exactly 1"
    discarded=$((discarded + 1))
    return
  fi

  # line-oriented replacement of a whole unique line; no multi-line string surgery
  awk -v needle="$needle" -v rep="$replacement" '
    index($0, needle) { print rep; next } { print }
  ' "$BAK" > "$SRC.tmp" && mv "$SRC.tmp" "$SRC"

  if ! grep -F -q "$replacement" "$SRC"; then
    echo "$id DISCARDED - replacement is not present after the edit"
    discarded=$((discarded + 1))
    return
  fi
  if grep -F -q "$needle" "$SRC"; then
    echo "$id DISCARDED - the original line is still there"
    discarded=$((discarded + 1))
    return
  fi

  rm -f "$OLEAN"
  lake build Proofs.Skyrim.PluginPath > /tmp/mut.log 2>&1
  local rc=$?

  if [ "$rc" -ne 0 ]; then
    echo "$id KILLED (exit $rc) - should break: $expect"
    grep -m1 '^error' /tmp/mut.log | cut -c1-120
    killed=$((killed + 1))
  else
    echo "$id SURVIVED (exit 0) - $expect is NOT load-bearing"
    survived=$((survived + 1))
  fi
}

# M01 - the game also loads plugins one level deep. Breaks the whole premise.
mutate "M01" \
  "  | [c₁, c₂, f] => c₁ == skse && c₂ == plugins && isDll f" \
  "  | [_, c₁, c₂, f] => c₁ == skse && c₂ == plugins && isDll f" \
  "fomod_layout_is_inert / wrapped_never_loads"

# M02 - flatten keeps the wrapper component instead of dropping it (the no-op repair).
mutate "M02" \
  "      | d :: tl => if d = dir then tl :: flatten dir rest else flatten dir rest" \
  "      | d :: tl => if d = dir then (d :: tl) :: flatten dir rest else flatten dir rest" \
  "flatten_loads / flatten_activates"

# M03 - the repair keeps the AE binary. Green build, wrong DLL on a 1.5.97 runtime.
mutate "M03" \
  "def fixedLayout : Layout := [ [skse, plugins, dllSpidSE] ]" \
  "def fixedLayout : Layout := [ [skse, plugins, dllSpidAE] ]" \
  "flatten_loads / flatten_picks_se"

# M04 - a mod counts as active whenever it holds any file at all.
mutate "M04" \
  "def active (l : Layout) : Bool := !(loaded l).isEmpty" \
  "def active (l : Layout) : Bool := !l.isEmpty" \
  "fomod_layout_inactive / active_iff"

# M05 - the .xml counts as a plugin, so the FOMOD wrapper looks alive.
mutate "M05" \
  "  | xmlModuleConfig | txtReadme" \
  "  | xmlModuleConfig | txtReadme -- mutated: see isDll below" \
  "nothing - this is a CONTROL that should NOT break anything"

echo
echo "restoring baseline"
cp "$BAK" "$SRC"
rm -f "$OLEAN"
lake build Proofs.Skyrim.PluginPath > /tmp/restore.log 2>&1
rc=$?
echo "restored build exit=$rc"
if [ "$rc" -ne 0 ]; then
  echo "RESTORE FAILED - the tree is NOT back at green"
  tail -5 /tmp/restore.log
  exit 3
fi

echo
echo "killed=$killed survived=$survived discarded=$discarded"
[ "$discarded" -gt 0 ] && echo "NOTE: discarded mutants tested NOTHING - they are not survivors"
exit 0
