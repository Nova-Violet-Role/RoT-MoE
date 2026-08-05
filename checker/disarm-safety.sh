#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# DISARM SAFETY -- the destructive half of the installer pair, under test.
#
# TWO MEASURED DEFECTS, both of which reached a live machine.
#
# 1. `--dry-run` WAS ACCEPTED AND SILENTLY IGNORED. Counted:
#      grep -cE '\-\-dry-run|DRY' ARM_ROUTER.sh      -> 15   (parsed, honoured)
#      grep -cE '\-\-dry-run|DRY' DISARM_ROUTER.sh   ->  0   (never parsed)
#    The destructive script was the one missing the safety flag, and an unknown
#    argument was a no-op, so `--dry-run` read as "proceed". It deleted two real
#    router hook entries from a live settings.json.
#
# 2. REMOVAL WAS KEYED TO THE UNINSTALLER'S OWN DIRECTORY. An entry pointing at
#    the installed plugin -- which is what the documented install produces --
#    could never be removed from a source checkout: `nothing to remove`, exit 0,
#    entry stays forever.
#
# The Lean statements are lean/Proofs/RotDuplicate.lean:
# `exact_misses_foreign_spelling`, `any_removes_all`, `any_preserves_foreign`,
# `any_preserves_plugin`. This file is the executable half.
#
# THE ASSERTION THAT MATTERS is not "the script exited 0". It is that the FILE IS
# BYTE-IDENTICAL after a dry run. The first attempt at this fix elsewhere passed
# its own test while still deleting the entries, because the test trusted the
# exit code -- a dry run that exits 0 and deletes is exactly the failure being
# guarded against, so the exit code cannot be the evidence.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0; skip=0
ok()   { echo "  PASS  $*"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=disarm-safety::%s\n' "$*"; fail=$((fail+1)); }

echo "== disarm safety: --dry-run writes nothing, --all reaches plugin entries =="

command -v node >/dev/null 2>&1 || { bad "node not found"; echo "  disarm-safety: FAIL"; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/rotdis.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

hash_of () { md5sum "$1" 2>/dev/null | cut -d' ' -f1 || cksum "$1" | cut -d' ' -f1; }
rot_lines () { grep -c 'rot-router' "$1" 2>/dev/null || true; }

# A config carrying BOTH shapes: an entry naming a plugin cache (which the exact
# matcher cannot reproduce from this directory) and a hook of the user's own that
# must survive everything.
make_cfg () {
  d="$1"; mkdir -p "$d"
  cat > "$d/settings.json" <<'JSON'
{
  "model": "opus",
  "hooks": {
    "UserPromptSubmit": [
      { "matcher": "*", "hooks": [ { "type": "command", "command": "pwsh -NoProfile -File \"/c/Users/someone/.claude/plugins/cache/rot-moe/rot-moe/0.6.1/hooks/rot-router.ps1\" || bash \"/c/Users/someone/.claude/plugins/cache/rot-moe/rot-moe/0.6.1/hooks/rot-router.sh\"" } ] },
      { "matcher": "*", "hooks": [ { "type": "command", "command": "echo the-users-own-hook" } ] }
    ]
  }
}
JSON
}

# --- 1. dry run leaves the bytes alone ---------------------------------------
# THE FIXTURE MUST CONTAIN SOMETHING EACH MODE CAN ACTUALLY REMOVE, or the
# assertion cannot fail. Measured while building this gate: with only a
# plugin-path entry present, the plain `--dry-run` case passed even with the dry
# run DELETED from the script -- exact mode had nothing to match, so nothing
# changed, and "byte-identical" was true for the wrong reason. So the fixture is
# armed from THIS directory first, giving the exact matcher a live target.
for flags in "--dry-run" "--all --dry-run"; do
  d="$TMP/dry$(echo "$flags" | tr -cd 'a-z')"; make_cfg "$d"
  CLAUDE_CONFIG_DIR="$d" bash ARM_ROUTER.sh >/dev/null 2>&1
  armed_lines="$(rot_lines "$d/settings.json")"
  if [ "$armed_lines" -lt 2 ]; then
    bad "fixture setup: expected an armed entry to dry-run against, got $armed_lines"
  fi
  before="$(hash_of "$d/settings.json")"
  CLAUDE_CONFIG_DIR="$d" bash DISARM_ROUTER.sh $flags >"$d/out.txt" 2>&1
  rc=$?
  after="$(hash_of "$d/settings.json")"
  if [ "$before" = "$after" ]; then
    ok "DISARM $flags left settings.json BYTE-IDENTICAL (exit $rc)"
  else
    bad "DISARM $flags MODIFIED settings.json -- this is the measured data-loss defect"
  fi
done

# The dry run must also be INFORMATIVE, or it is a no-op wearing a flag. `--all`
# on this fixture has exactly one entry to remove and must say so.
d="$TMP/dryinfo"; make_cfg "$d"
out="$(CLAUDE_CONFIG_DIR="$d" bash DISARM_ROUTER.sh --all --dry-run 2>&1)"
case "$out" in
  *"1 now -> 0"*) ok "the dry run REPORTS the delta it would make" ;;
  *) bad "the dry run wrote nothing and said nothing useful -- output was: $(echo "$out" | tail -2 | tr '\n' ' ')" ;;
esac

# --- 2. an unknown flag refuses ----------------------------------------------
d="$TMP/badflag"; make_cfg "$d"
before="$(hash_of "$d/settings.json")"
CLAUDE_CONFIG_DIR="$d" bash DISARM_ROUTER.sh --definitely-not-a-flag >"$d/out.txt" 2>&1
rc=$?
after="$(hash_of "$d/settings.json")"
if [ "$rc" = 2 ] && [ "$before" = "$after" ]; then
  ok "an unknown flag refuses (exit 2) and writes nothing"
else
  bad "an unknown flag was swallowed: exit $rc, file changed: $([ "$before" = "$after" ] && echo no || echo YES)"
fi

# --- 3. exact mode cannot reach a plugin-path entry, and SAYS so -------------
d="$TMP/exact"; make_cfg "$d"
out="$(CLAUDE_CONFIG_DIR="$d" bash DISARM_ROUTER.sh 2>&1)"
left="$(rot_lines "$d/settings.json")"
if [ "$left" -ge 1 ]; then
  ok "exact mode leaves the plugin-path entry (it cannot spell it) -- $left line(s) remain"
else
  bad "exact mode removed an entry it could not have matched -- the matcher is too broad"
fi
case "$out" in
  *"--all"*) ok "exact mode TELLS the user about --all instead of reporting a false all-clear" ;;
  *) bad "exact mode said 'nothing to remove' and stayed silent about the entries it can see" ;;
esac

# --- 4. --all removes it, and takes nothing else -----------------------------
d="$TMP/all"; make_cfg "$d"
CLAUDE_CONFIG_DIR="$d" bash DISARM_ROUTER.sh --all >"$d/out.txt" 2>&1
rc=$?
left="$(rot_lines "$d/settings.json")"
[ "$rc" = 0 ] && [ "$left" = "0" ] \
  && ok "--all removed the plugin-path entry (exit 0, 0 router lines left)" \
  || bad "--all failed: exit $rc, $left router lines left"
grep -q 'the-users-own-hook' "$d/settings.json" \
  && ok "--all preserved the user's own unrelated hook" \
  || bad "--all took a neighbouring hook with it -- this is worse than not uninstalling"
grep -q '"model": *"opus"' "$d/settings.json" \
  && ok "--all preserved unrelated scalar keys" \
  || bad "--all changed a key it did not come to touch"
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$d/settings.json" 2>/dev/null \
  && ok "the written file still parses as JSON" \
  || bad "the written file does not parse -- the user's session is broken"

# --- 5. THE CONTROL: real removal still works in EXACT mode ------------------
# Without this, a DISARM that had simply stopped removing anything would pass
# every assertion above. The entry here is the one THIS directory produces, so
# the exact matcher must find it.
d="$TMP/control"; mkdir -p "$d"
printf '{}\n' > "$d/settings.json"
CLAUDE_CONFIG_DIR="$d" bash ARM_ROUTER.sh >/dev/null 2>&1
armed="$(rot_lines "$d/settings.json")"
CLAUDE_CONFIG_DIR="$d" bash DISARM_ROUTER.sh >/dev/null 2>&1
after="$(rot_lines "$d/settings.json")"
if [ "$armed" -ge 2 ] && [ "$after" = "0" ]; then
  ok "CONTROL: exact mode still removes what it installed ($armed -> $after)"
else
  bad "CONTROL: arm/disarm round trip broken ($armed -> $after) -- the uninstaller is dead"
fi

# --- 6. cross-arm parity ------------------------------------------------------
if command -v pwsh >/dev/null 2>&1; then
  d="$TMP/ps1dry"; make_cfg "$d"
  before="$(hash_of "$d/settings.json")"
  CLAUDE_CONFIG_DIR="$d" pwsh -NoProfile -File ./DISARM_ROUTER.ps1 -All -DryRun >"$d/out.txt" 2>&1
  after="$(hash_of "$d/settings.json")"
  [ "$before" = "$after" ] && ok "[ps1] -DryRun left settings.json byte-identical" \
                           || bad "[ps1] -DryRun MODIFIED settings.json"
  d="$TMP/ps1all"; make_cfg "$d"
  CLAUDE_CONFIG_DIR="$d" pwsh -NoProfile -File ./DISARM_ROUTER.ps1 -All >"$d/out.txt" 2>&1
  [ "$(rot_lines "$d/settings.json")" = "0" ] && ok "[ps1] -All removed the plugin-path entry" \
                                              || bad "[ps1] -All did not remove it -- arms disagree"
  grep -q 'the-users-own-hook' "$d/settings.json" \
    && ok "[ps1] -All preserved the user's own hook" \
    || bad "[ps1] -All took a neighbouring hook with it"
else
  echo "  SKIP  no pwsh on this runner -- the PowerShell arm was NOT exercised."
  echo "        This is a SKIP, never a PASS: an unrun arm proves nothing."
  skip=1
fi

echo
echo "  $pass passed, $fail failed, $skip skipped"
if [ "$fail" -gt 0 ]; then echo "  disarm-safety: FAIL"; exit 1; fi
echo "  disarm-safety: PASS"
exit 0
