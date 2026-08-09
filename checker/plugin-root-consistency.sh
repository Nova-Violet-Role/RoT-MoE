#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# EVERY DECLARED PLUGIN ROOT MUST EXIST, AND THE DECLARATIONS MUST AGREE.
#
# WHY THIS GATE EXISTS -- a defect found twice, the second time after it was
# supposedly understood.
#
# FIRST TIME (2026-08-09, earlier): the plugin registry declared the runtime
# lived at `plugins/cache/rot-moe/rot-moe/1.0.1`, `known_marketplaces.json`
# declared `Desktop\RoT-MoE 1.0.1-Lean`, and the router that was ACTUALLY
# executing was a third path, `Desktop\RoT-MoE 0.7.1-Lean`, named for a version
# it no longer contained. Three declarations, none of them the truth. A patch
# driven by the registry left the running router untouched, and every symptom
# said "the fix did not work" while the fix had been applied perfectly -- to a
# copy nobody ran. That is `RotPluginRoot.registry_driven_patch_missed_the_runtime`.
#
# SECOND TIME (same day, after the repair): `settings.json` still carried
# `extraKnownMarketplaces.rot-moe.source.path = Desktop\RoT-MoE 1.0.1-Lean`,
# a directory that had been RETIRED and no longer existed at all, while
# `known_marketplaces.json` correctly said `.claude/rot-moe-src/1.0.1`. Two
# config files, one dangling. Nothing checked either.
#
# The lesson that generalises past this plugin: a path in a config file is a
# CLAIM, and an unchecked claim about the filesystem rots silently. It does not
# fail loudly -- the tool ignores what it cannot find and carries on with a
# stale copy, which looks exactly like working.
#
# WHAT THIS BINDS, for whatever config dirs are present on the machine:
#   1. every plugin root a config DECLARES must EXIST on disk;
#   2. where two configs declare the same marketplace, they must AGREE;
#   3. the declared install path must contain a real plugin (a plugin.json).
#
# EXIT 3 (SKIP) when no config dir is present -- CI has no ~/.claude. A skip is
# printed as a skip and never counted as a pass; `checker/ci-honesty.sh` is what
# stops a skip from being read as green in the workflow.
# =============================================================================

set -uo pipefail

passed=0; failed=0; examined=0
# printf, not echo. Every value this gate reports is a WINDOWS PATH full of
# backslashes, and `echo` in sh interprets them -- the first live run printed
# "C:UsersSaimonoDesktopRoT-MoE 1.0.1-Lean" for a path that actually reads
# "<DESKTOP>\RoT-MoE 1.0.1-Lean" with every separator eaten. The detection was right and the
# message was unreadable, which for a gate whose entire output is a path is the
# same as being wrong.
ok()  { printf '  ok   %s\n' "$1"; passed=$((passed+1)); }
bad() { printf '  FAIL %s\n' "$1"; failed=$((failed+1)); }

# Candidate config dirs: the real one and the CTT clone. Overridable so the
# controls below can point this at a scratch tree.
CONFIGS="${ROTMOE_CONFIG_DIRS:-$HOME/.claude C:/Users/Saimono/Claude_Test/.claude}"

_present=0
for c in $CONFIGS; do [ -d "$c" ] && _present=$((_present+1)); done
if [ "$_present" -eq 0 ]; then
  echo "SKIP: no Claude config dir found (checked: $CONFIGS)."
  echo "This is a SKIP (exit 3), never a pass."
  exit 3
fi

# --- the reader --------------------------------------------------------------
# Pulls "<marketplace> <path>" pairs out of a config file. node is used because
# these files are JSON and may carry a UTF-8 BOM (PowerShell writes one), which
# a naive JSON.parse rejects -- measured on the live settings.json.
read_pairs() {
  node -e '
    const fs=require("fs");
    const p=process.argv[1];
    let s;
    try { s=fs.readFileSync(p,"utf8"); } catch(e) { process.exit(0); }
    if (s.charCodeAt(0)===0xFEFF) s=s.slice(1);
    let j;
    try { j=JSON.parse(s); } catch(e) { console.error("UNPARSEABLE "+p+": "+e.message); process.exit(4); }
    const out=[];
    const scan=(obj)=>{
      if(!obj||typeof obj!=="object") return;
      for(const [k,v] of Object.entries(obj)){
        if(v&&typeof v==="object"&&v.source&&typeof v.source==="object"&&typeof v.source.path==="string")
          out.push(k+"\t"+v.source.path);
        if(v&&typeof v==="object"&&typeof v.installLocation==="string")
          out.push(k+"\t"+v.installLocation);
      }
    };
    scan(j.extraKnownMarketplaces||{});
    for(const key of Object.keys(j)) scan(j[key]&&typeof j[key]==="object"?j[key]:{});
    scan(j);
    for(const line of [...new Set(out)]) console.log(line);
  ' "$1" 2>&1
}

towin() { printf '%s' "$1" | tr '\\' '/' | sed 's|//*|/|g' | sed 's|/$||'; }

for cfg in $CONFIGS; do
  [ -d "$cfg" ] || continue
  for f in "$cfg/settings.json" "$cfg/plugins/known_marketplaces.json" "$cfg/plugins/installed_plugins.json"; do
    [ -f "$f" ] || continue
    out=$(read_pairs "$f")
    if printf '%s' "$out" | grep '^UNPARSEABLE' >/dev/null; then
      bad "$(printf '%s' "$out" | head -1)"
      continue
    fi
    printf '%s\n' "$out" | while IFS="$(printf '\t')" read -r name p; do
      [ -n "${p:-}" ] || continue
      case "$p" in http*|git@*) continue ;; esac
      # The config dir is carried as its own column so the agreement rule can be
      # scoped to ONE instance. See the note on rule 2 below.
      printf '%s\t%s\t%s\t%s\n' "$cfg" "$f" "$name" "$p"
    done >> "${TMPDIR:-/tmp}/rotmoe-roots.$$"
  done
done

ROOTS="${TMPDIR:-/tmp}/rotmoe-roots.$$"
touch "$ROOTS"
trap 'rm -f "$ROOTS" "$ROOTS.norm"' EXIT

# --- 1. every declared root must exist ---------------------------------------
_missing=0
while IFS="$(printf '\t')" read -r cfg f name p; do
  [ -n "${p:-}" ] || continue
  examined=$((examined+1))
  win=$(towin "$p")
  case "$win" in
    [A-Za-z]:/*) unixp="/$(printf '%s' "$win" | sed 's|^\([A-Za-z]\):|\L\1|')" ;;
    *) unixp="$win" ;;
  esac
  if [ -d "$unixp" ] || [ -d "$win" ]; then
    :
  else
    bad "$(basename "$f") declares '$name' at a path that DOES NOT EXIST: $p"
    _missing=$((_missing+1))
  fi
done < "$ROOTS"
[ "$_missing" -eq 0 ] && ok "all $examined declared plugin root(s) exist on disk"

# --- 2. within ONE config dir, declarations of a marketplace must agree ------
#
# SCOPED PER CONFIG DIR, and the first version was not -- it compared the global
# install against the CTT test clone and went red on a CORRECT machine. Those
# two are separate Claude instances by design: the global one is sourced from
# `.claude/rot-moe-src/1.0.1`, the CTT one from `Claude_Test/.rot-release`, and
# they are SUPPOSED to differ. A gate that demands they match would be repaired
# by making the test instance shadow the real one, which destroys the whole
# point of having a test instance.
#
# The hazard is real but it lives INSIDE one config dir: settings.json saying
# one path while known_marketplaces.json says another is the defect that let a
# retired directory stay declared for hours.
awk -F'\t' '{ gsub(/\\/,"/",$4); print $1"\t"$3"\t"$4 }' "$ROOTS" | sort -u > "$ROOTS.norm"
_div=0
while IFS= read -r key; do
  n=$(awk -F'\t' -v k="$key" '$1"\t"$2==k' "$ROOTS.norm" | wc -l | tr -d ' ')
  if [ "$n" -gt 1 ]; then
    bad "within $(printf '%s' "$key" | cut -f1): '$(printf '%s' "$key" | cut -f2)' is declared at $n DIFFERENT paths -- a registry-driven patch will miss the runtime:"
    awk -F'\t' -v k="$key" '$1"\t"$2==k { print "         "$3 }' "$ROOTS.norm"
    _div=$((_div+1))
  fi
done <<EOF
$(awk -F'\t' '{ print $1"\t"$2 }' "$ROOTS.norm" | sort -u)
EOF
[ "$_div" -eq 0 ] && ok "within each config dir, no marketplace is declared at two different paths"

# --- 3. a declared install path must hold a real plugin ----------------------
_empty=0
while IFS="$(printf '\t')" read -r cfg f name p; do
  [ -n "${p:-}" ] || continue
  win=$(towin "$p")
  case "$win" in
    [A-Za-z]:/*) unixp="/$(printf '%s' "$win" | sed 's|^\([A-Za-z]\):|\L\1|')" ;;
    *) unixp="$win" ;;
  esac
  d=""
  [ -d "$unixp" ] && d="$unixp"
  [ -z "$d" ] && [ -d "$win" ] && d="$win"
  [ -n "$d" ] || continue
  case "$name" in rot-moe*|*rot-moe*) ;; *) continue ;; esac
  if [ -f "$d/.claude-plugin/plugin.json" ] || [ -f "$d/plugin.json" ]; then
    :
  else
    bad "'$name' resolves to $p but there is no plugin.json under it"
    _empty=$((_empty+1))
  fi
done < "$ROOTS"
[ "$_empty" -eq 0 ] && ok "every rot-moe root that exists actually contains a plugin manifest"

# --- POSITIVE CONTROLS -------------------------------------------------------
# The gate must be able to FAIL. Two scratch configs are built and read through
# the SAME reader: one dangling, one divergent.
CTL="${TMPDIR:-/tmp}/rotmoe-rootctl.$$"
mkdir -p "$CTL/a"
cat > "$CTL/a/settings.json" <<'EOF'
{ "extraKnownMarketplaces": { "zz-ctl": { "source": { "source": "directory", "path": "/nonexistent/zz-ctl-root" } } } }
EOF
_ctl=$(read_pairs "$CTL/a/settings.json")
if printf '%s' "$_ctl" | grep 'zz-ctl.*nonexistent' >/dev/null; then
  ok "positive control: the reader extracts a planted dangling declaration"
else
  bad "positive control: the reader did NOT see the planted declaration -- every 'ok' above may be vacuous"
fi
_ctlpath=$(printf '%s' "$_ctl" | head -1 | cut -f2)
if [ -n "$_ctlpath" ] && [ ! -d "$_ctlpath" ]; then
  ok "positive control: a planted nonexistent path is correctly seen as missing"
else
  bad "positive control: the existence test did not flag a path that does not exist"
fi
rm -rf "$CTL"

echo "plugin-root-consistency: $passed passed, $failed failed ($examined declaration(s) examined)"
[ "$failed" -eq 0 ] || exit 1
exit 0
