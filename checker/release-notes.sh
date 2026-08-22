#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# release-notes.sh -- compose the release note for ONE tier.
#
# The Socio's shape, stated plainly: THREE tags, THREE releases, ONE body, and
# exactly three differences between them (Router / Lean / Lean+Extra).
#
#   the BODY is the CHANGELOG section for the release version. Authored once,
#   derived here, never retyped, and byte-identical across all three notes.
#
#   the THREE DIFFERENCES are the header this script puts above that body:
#   which archive the tag carries, what is measured inside it, and the install
#   line that serves it. Every number below is READ OUT OF THE BUILT ZIP at
#   compose time -- nothing here is a remembered figure.
#
# Usage:  bash checker/release-notes.sh <core|lean|unsealed> [outfile]
#
# Exits 2 on any refusal. A release note that cannot state what it ships is
# not a smaller note, it is a defect.
set -u

TIER="${1:-}"
OUTF="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || { echo "REFUSE: cannot enter repo root" >&2; exit 2; }

OUT=".release"
MANIFEST=".claude-plugin/plugin.json"
[ -f "$MANIFEST" ] || { echo "REFUSE: $MANIFEST absent" >&2; exit 2; }

TREEVER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -1)
case "$TREEVER" in
  ''|*[!0-9.]*) echo "REFUSE: unreadable version in $MANIFEST" >&2; exit 2 ;;
esac
BASEVER="${TREEVER%.*}"

# Tier map -- the SAME digits checker/release-package.sh stamps into each zip.
# Stated once here so the two files cannot drift apart silently.
case "$TIER" in
  core)     ZIP="RoT-MoE-Router.zip";            VER="$BASEVER.0"; NAME="Router" ;;
  lean)     ZIP="RoT-MoE-Router-Lean.zip";       VER="$BASEVER.1"; NAME="Lean" ;;
  unsealed) ZIP="RoT-MoE-Router-Lean-Extra.zip"; VER="$BASEVER.2"; NAME="Lean+Extra" ;;
  *) echo "REFUSE: tier must be core|lean|unsealed, got '${TIER:-}'" >&2; exit 2 ;;
esac

Z="$OUT/$ZIP"
[ -s "$Z" ] || { echo "REFUSE: $Z absent -- run checker/release-package.sh first" >&2; exit 2; }
command -v unzip >/dev/null 2>&1 || { echo "REFUSE: unzip absent" >&2; exit 2; }

# --- the three differences, MEASURED out of the archive this tag carries -----
ENTRIES=$(unzip -Z1 "$Z" | grep -v "/$" | grep -c . || true)
LEANF=$(unzip -Z1 "$Z" | grep -c "[.]lean$" || true)
KB=$(( $(wc -c < "$Z") / 1024 ))
ZVER=$(unzip -p "$Z" "$(unzip -Z1 "$Z" | grep "plugin.json$" | head -1)" 2>/dev/null \
       | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
UNSEALED=$(unzip -Z1 "$Z" | grep -c "^UNSEALED.md$" || true)

# The note must never claim a version the archive does not carry. This is the
# same read-back the packager does, repeated here because the note is a
# SEPARATE artifact and an unchecked claim in it is still a false claim.
if [ "$ZVER" != "$VER" ]; then
  echo "REFUSE: $ZIP declares '$ZVER' but tier $TIER publishes $VER" >&2; exit 2
fi

# --- the body: one CHANGELOG section, shared by all three -------------------
[ -f CHANGELOG.md ] || { echo "REFUSE: CHANGELOG.md absent" >&2; exit 2; }
BODY=$(awk -v h="## [$TREEVER]" 'index($0,h)==1 {f=1; next} index($0,"## [")==1 {f=0} f' CHANGELOG.md)
# The CHANGELOG section already ends with its own rule; emitting the tail
# rule too renders a double line. Trim trailing blanks and rules -- no
# backslash anywhere in this awk, deliberately: MEASURED this session, a
# backslash written through the tool transport arrives stripped, which is how
# the first draft of the extractor above became a character class and matched
# nothing.
BODY=$(printf '%s' "$BODY" | awk '{a[n++]=$0} END{while(n>0 && (a[n-1]=="---" || a[n-1]=="")) n--; for(i=0;i<n;i++) print a[i]}')
case "$(printf '%s' "$BODY" | tr -d '[:space:]')" in
  '') echo "REFUSE: CHANGELOG.md carries no [$TREEVER] section -- refusing an empty release note" >&2; exit 2 ;;
esac

case "$TIER" in
  core)     WHAT="The router and its organs. No Lean 4, no unsealed policy page." ;;
  lean)     WHAT="Router + the Lean 4 toolchain fetcher and the proof corpus. This is the tier /plugin install serves." ;;
  unsealed) WHAT="Router-Lean + UNSEALED.md, the policy page that permits the unsealed lane." ;;
esac

compose () {
cat <<HEADEOF
## RoT MoE $VER -- $NAME

$WHAT

| this tag ships | measured |
|---|---|
| archive | \`$ZIP\` ($KB KB) |
| files | $ENTRIES |
| Lean 4 sources | $LEANF |
| UNSEALED.md | $( [ "$UNSEALED" -gt 0 ] && echo yes || echo no ) |
| manifest version inside | $ZVER |

Three tags are cut from one commit: \`v$BASEVER.0\` Router, \`v$BASEVER.1\` Lean,
\`v$BASEVER.2\` Lean+Extra. They differ by archive content, not by source tree --
the table above is the whole difference, read out of the zip at publish time.

---

HEADEOF
printf '%s\n' "$BODY"
cat <<'TAILEOF'

---

Verify any download against its published checksum: `sha256sum -c SHA256SUMS.txt`, or on macOS, where that tool does not exist: `shasum -a 256 -c SHA256SUMS.txt`
TAILEOF
}

if [ -n "$OUTF" ]; then
  compose > "$OUTF" || { echo "REFUSE: could not write $OUTF" >&2; exit 2; }
  echo "release note for $TIER ($VER) written to $OUTF"
else
  compose
fi
