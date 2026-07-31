#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE INSTALL DOCUMENT IS A SPEC, AND SPECS GO STALE.
#
# `CLAUDE.md` and `.claude/commands/rot-moe-install.md` tell an AGENT WITH A
# SHELL what to run on someone else's machine. That makes a stale line in them
# more dangerous than a stale line in a README: a human reading "run
# checker/gate-all.sh" and finding no such file shrugs; an agent improvises.
#
# So every path and flag those documents name is checked to EXIST here, and the
# consent language they depend on is checked to still be present in the scripts
# themselves. This is the same binding discipline the Lean checkers use --
# prose is validated against the code, never the other way round.
#
# CONTROLS, in both directions:
#   * a planted document naming a file that does not exist MUST be rejected
#   * a planted document naming only real files MUST pass
# Without both, this file is a green that has never been seen to fail.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }

echo "== install-document lint =="

DOCS="CLAUDE.md .claude/commands/rot-moe-install.md"
for d in $DOCS; do
  [ -f "$d" ] && ok "present: $d" || bad "MISSING: $d -- the agent-facing install path is gone"
done

# --- 1. every repo path the documents name must exist ------------------------
# Extract candidates: anything inside backticks that looks like a repo-relative
# path with a known extension, plus the bare script names.
extract_paths () {   # extract_paths <file>
  grep -oE '(checker|hooks|lean|engine|agents|\.claude)/[A-Za-z0-9_./-]+|ARM_ROUTER\.(sh|ps1)|DISARM_ROUTER\.(sh|ps1)|SETUP_LEAN\.(sh|ps1)|CLAUDE\.md' "$1" \
    | sed 's/[.,)]*$//' | sort -u
}

missing=0; checked=0
for d in $DOCS; do
  [ -f "$d" ] || continue
  while read -r p; do
    [ -z "$p" ] && continue
    # `lean/Proofs/...` module names appear as Lean module ids, not paths; skip
    # anything with no dot-extension AND no directory that exists.
    checked=$((checked+1))
    if [ ! -e "$p" ]; then
      bad "$d names '$p' which does NOT exist in this repository"
      missing=$((missing+1))
    fi
  done < <(extract_paths "$d")
done
[ "$checked" -gt 0 ] || bad "no paths extracted at all -- the extractor is broken, not the docs"
[ "$checked" -gt 0 ] && [ "$missing" -eq 0 ] && ok "all $checked path reference(s) in the install docs exist"

# --- 2. the consent language must still be real ------------------------------
# CLAUDE.md promises the toolchain fetch refuses by default. If someone removes
# that refusal from the script, the DOCUMENT becomes a lie that an agent will
# act on. Check the promise against the code.
if grep -q 'refuses by default' CLAUDE.md 2>/dev/null; then
  if grep -q 'REFUSING' SETUP_LEAN.sh 2>/dev/null && grep -q 'REFUSING' SETUP_LEAN.ps1 2>/dev/null; then
    ok "CLAUDE.md's 'refuses by default' promise is backed by both SETUP_LEAN arms"
  else
    bad "CLAUDE.md promises SETUP_LEAN refuses by default, but a script no longer does"
  fi
else
  bad "CLAUDE.md no longer states that the toolchain fetch refuses by default"
fi

# The no-elevation rule must appear in the agent-facing docs, because an agent
# reads THESE, not SECURITY.md.
for d in $DOCS; do
  [ -f "$d" ] || continue
  grep -qi 'never elevate\|no `sudo`\|No `sudo`' "$d" \
    && ok "$d states the no-elevation rule" \
    || bad "$d does not state the no-elevation rule -- an agent will not infer it"
done

# And the documents must not themselves contain an elevated command.
for d in $DOCS; do
  [ -f "$d" ] || continue
  if grep -nE '^[^#<]*\bsudo [a-z]' "$d" >/dev/null 2>&1; then
    bad "$d contains an actual sudo INVOCATION"
  else
    ok "$d contains no sudo invocation"
  fi
done

# --- 3. controls -------------------------------------------------------------
echo
echo "-- negative controls --"
CTL="$(mktemp -d "${TMPDIR:-/tmp}/cmdlint.XXXXXX")"
printf 'Run `checker/this-does-not-exist.sh` to begin.\n' > "$CTL/stale.md"
if [ "$(extract_paths "$CTL/stale.md")" = "checker/this-does-not-exist.sh" ] \
   && [ ! -e "checker/this-does-not-exist.sh" ]; then
  ok "CONTROL: a document naming a nonexistent checker IS detected"
else
  bad "CONTROL DEAD: the extractor did not see a planted stale path"
fi
printf 'Run `checker/gate-all.sh` to begin.\n' > "$CTL/fresh.md"
if [ "$(extract_paths "$CTL/fresh.md")" = "checker/gate-all.sh" ] && [ -e "checker/gate-all.sh" ]; then
  ok "CONTROL: a document naming a real checker is NOT flagged"
else
  bad "CONTROL: a real path was mis-flagged -- this lint would cry wolf"
fi
rm -rf "$CTL"

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  claude-md-lint: PASS"; exit 0; } || { echo "  claude-md-lint: FAIL"; exit 1; }
