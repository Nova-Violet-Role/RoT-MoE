#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE VERDICT BODY -- everything in STATUS.md that is a MEASUREMENT, and nothing
# that merely proves time passed.
#
# THE DEFECT THIS EXISTS TO FIX, found 2026-08-01 by reading the workflow that
# was supposed to prevent it.
#
# `verify.yml` writes STATUS.md weekly and commits it only "if the verdict
# changed", with `--allow-empty` deliberately absent and a comment explaining
# that a bot which commits regardless manufactures activity. Correct intent.
# But the file it compared contained:
#
#     | verified at | $(date -u '+%Y-%m-%d %H:%M UTC') |
#     | commit      | ${GITHUB_SHA} |
#
# Both change on EVERY run. `git diff --staged --quiet` therefore could never be
# true, and the weekly job would have committed every week forever -- the exact
# behaviour the comment forbids, implemented directly underneath it. The rule
# was enforced in prose and defeated by the payload.
#
# So the comparison must be made against the MEASUREMENTS ALONE. This script
# prints exactly those, deterministically, with no clock and no commit id in
# sight. `verify.yml` diffs its output against the marked block inside
# STATUS.md; the timestamp and SHA are written only when that block actually
# differs, where they belong -- as provenance for a verdict that changed, not as
# a reason to claim one did.
#
# DETERMINISM IS THE CONTRACT: two runs on an unchanged tree must be
# byte-identical, and any real change must move at least one line.
# `checker/verdict-stability.sh` holds this to both halves.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

# Recounted from source every time. A number typed into a README is a claim; a
# number recounted here is a measurement -- and the counter's own selftest runs
# first, so a counter inflatable by prose cannot publish an inflated verdict.
bash checker/count-theorems.sh --selftest >/dev/null 2>&1 || {
  echo "FATAL: the theorem counter failed its own selftest -- refusing to publish a verdict" >&2
  exit 2
}

TH=0
for f in lean/Proofs/*.lean; do
  n=$(bash checker/count-theorems.sh "$f" 2>/dev/null); n=${n:-0}
  TH=$((TH + n))
done
MOD=$(ls lean/Proofs/*.lean 2>/dev/null | wc -l | tr -d ' ')
MUT=$(ls lean/mutate/mutate_*.sh 2>/dev/null | wc -l | tr -d ' ')
TOOLCHAIN=$(tr -d '\r\n' < lean/lean-toolchain 2>/dev/null)
CHECKERS=$(ls checker/*.sh 2>/dev/null | wc -l | tr -d ' ')

# `sorry` and `native_decide` are COUNTED, not asserted. A line saying "none"
# that nothing recounts is the kind of claim this repository exists to refuse.
#
# COMMENT-AWARE AND IDENTIFIER-AWARE, and both halves were paid for on the first
# run of this script: a naive `grep -E '(^|[^a-zA-Z])sorry'` reported **1 file
# containing sorry** and would have published that number to the front page. The
# three hits were:
#
#   /-- modules containing `sorry` -/            <- a doc comment
#   /-- A `sorry` is an admission ... -/         <- prose
#   theorem sorry_always_speaks ...              <- an IDENTIFIER; `_` is not
#                                                   [^a-zA-Z], so the naive
#                                                   pattern matched it
#
# An alarming number that is wrong is worse than no number: it trains a reader
# to discount the whole table. Block comments are stripped (they NEST in Lean,
# so a boolean flag is wrong), line comments are dropped, and the token must be
# bounded by non-identifier characters -- `_` included.
count_token () {   # count_token <token> -> number of FILES with a real occurrence
  local tok="$1" n=0
  for f in lean/Proofs/*.lean; do
    [ -f "$f" ] || continue
    if awk -v tok="$tok" '
      BEGIN { depth = 0; found = 0 }
      {
        line = $0; out = ""; i = 1
        while (i <= length(line)) {
          two = substr(line, i, 2)
          if (two == "/-") { depth++; i += 2; continue }
          if (two == "-/") { if (depth > 0) depth--; i += 2; continue }
          if (depth == 0) out = out substr(line, i, 1)
          i++
        }
        sub(/--.*$/, "", out)
        if (out ~ ("(^|[^A-Za-z0-9_])" tok "([^A-Za-z0-9_]|$)")) found = 1
      }
      END { exit (found ? 0 : 1) }' "$f"; then
      n=$((n + 1))
    fi
  done
  echo "$n"
}
SORRY=$(count_token sorry)
NATIVE=$(count_token native_decide)

# --- expose the counter, so nobody has to rewrite it -------------------------
# `--count <token>` prints ONE number and exits. It exists because
# .github/workflows/ads-manager.yml had reimplemented this with
#     grep -rc 'sorry' lean/Proofs/*.lean | awk ...
# and that naive counter reported sorry=3 on a corpus with ZERO real holes --
# a doc comment, a line of prose, and the THEOREM NAME `sorry_always_speaks`.
# The next step in that job refuses to advertise when sorry != 0, so the job
# would have failed for being CLEAN. Exactly the failure documented 40 lines
# above, reintroduced in a second place because the fix lived in a function
# nobody outside this file could call.
#
# One counter, one selftest, two callers. Adding a third caller must not mean
# writing the awk a third time.
if [ "${1:-}" = "--count" ]; then
  case "${2:-}" in
    sorry)         printf '%s\n' "$SORRY" ;;
    native_decide) printf '%s\n' "$NATIVE" ;;
    *) echo "usage: $0 --count sorry|native_decide" >&2; exit 2 ;;
  esac
  exit 0
fi

cat <<EOF
| field | value |
|---|---|
| theorems | $TH |
| modules | $MOD |
| mutation suites | $MUT |
| checkers | $CHECKERS |
| toolchain | \`$TOOLCHAIN\` |
| files containing \`sorry\` | $SORRY |
| files containing \`native_decide\` | $NATIVE |
EOF
