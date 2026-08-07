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
#
# STRING LITERALS ARE STRIPPED TOO, and that is the THIRD case this function has
# paid for. `RotLog.lean` models the router's stem table, and the FORGE lane
# genuinely owns the stem "sorry" -- it is one of the words that routes a prompt
# to the prover lane. The token therefore appears in the spec as DATA:
#
#   ("FORGE", ["run","build",...,"tactic","sorry","mathlib",...])
#
# and the counter reported `files containing sorry | 1` for a tree with none.
# That number was about to be published on the front page of STATUS.md, where it
# means "a proof was admitted rather than closed" -- the single most damaging
# thing this project could say falsely about itself.
#
# A real `sorry` is a TACTIC or a TERM; it is never inside a string literal, so
# excluding quoted text cannot hide one. Escapes are honoured (`\"` does not end
# a string) so a literal containing a quote cannot desynchronise the scan and
# silently swallow the code after it.
count_token () {   # count_token <token> -> number of FILES with a real occurrence
  local tok="$1" n=0
  for f in lean/Proofs/*.lean; do
    [ -f "$f" ] || continue
    if token_in_file "$tok" "$f"; then
      n=$((n + 1))
    fi
  done
  echo "$n"
}

# The scan itself, over ONE file, so it can be aimed at a fixture. Narrowing a
# safety check without a control that proves it still fires is how a check
# becomes decoration; the two fixtures below are that control.
token_in_file () {   # token_in_file <token> <file> -> exit 0 if a REAL occurrence
  local tok="$1" f="$2"
  awk -v tok="$tok" '
      BEGIN { depth = 0; found = 0 }
      {
        line = $0; out = ""; i = 1; instr = 0
        while (i <= length(line)) {
          ch  = substr(line, i, 1)
          two = substr(line, i, 2)
          if (instr) {
            if (ch == "\\") { i += 2; continue }      # escaped char, skip both
            if (ch == "\"") { instr = 0 }
            i++; continue
          }
          if (two == "/-") { depth++; i += 2; continue }
          if (two == "-/") { if (depth > 0) depth--; i += 2; continue }
          if (depth == 0 && ch == "\"") { instr = 1; i++; continue }
          if (depth == 0) out = out ch
          i++
        }
        sub(/--.*$/, "", out)
        if (out ~ ("(^|[^A-Za-z0-9_])" tok "([^A-Za-z0-9_]|$)")) found = 1
      }
      END { exit (found ? 0 : 1) }' "$f"
}

# --- CONTROL: the narrowed counter must still see a real admission -----------
# String literals were excluded so that RotLog's stem table -- which legitimately
# contains the WORD "sorry", because that word routes a prompt to the prover
# lane -- stops being reported as an admitted proof. That exclusion is only safe
# if the counter still fires on the thing it exists to catch. Both directions
# are checked here, on every run, and a failure REFUSES to write STATUS.md
# rather than publishing a number from an instrument that has stopped working.
_ctl="$(mktemp -d "${TMPDIR:-/tmp}/svctl.XXXXXX")"
printf 'theorem t : True := by\n  sorry\n'                     > "$_ctl/real.lean"
printf 'def stems : List String := ["tactic", "sorry", "lake"]\n' > "$_ctl/quoted.lean"
if ! token_in_file sorry "$_ctl/real.lean"; then
  echo "CONTROL FAILED: the counter no longer detects a real 'sorry' tactic."
  echo "Refusing to regenerate STATUS.md from an instrument that cannot fail."
  rm -rf "$_ctl"; exit 1
fi
if token_in_file sorry "$_ctl/quoted.lean"; then
  echo "CONTROL FAILED: the counter still reports a quoted \"sorry\" as an admission."
  rm -rf "$_ctl"; exit 1
fi
rm -rf "$_ctl"

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

emit_verdict () {
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
}

# --- `--write`: SPLICE THE VERDICT IN, SO NOBODY EDITS STATUS.md BY HAND ------
# Until now this script only PRINTED the verdict, and both `verify.yml` and
# `checker/verdict-fresh.sh` told the maintainer to "regenerate and commit it"
# with no tool that does the splicing. That gap is not theoretical: commit
# 37fd513 records STATUS.md being hand-edited and verdict-fresh catching it in
# CI. An instruction to regenerate, with no regenerator, IS an instruction to
# hand-edit.
#
# The layout below is the same one `verify.yml` writes, deliberately: if the two
# diverged, every local regeneration would be reverted by the next weekly run
# and vice versa. Only the text BETWEEN the markers is compared by
# verdict-fresh, so the provenance line differs honestly -- it says the file was
# regenerated locally rather than claiming a CI run that did not happen.
if [ "${1:-}" = "--write" ]; then
  _target="$REPO/STATUS.md"
  _sha="$(git -C "$REPO" rev-parse HEAD 2>/dev/null || echo unknown)"
  {
    echo "<!-- SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2 -->"
    echo "<!-- Copyright 2026 Saimonokuma. -->"
    echo
    echo "# STATUS"
    echo
    echo "Generated by \`.github/workflows/verify.yml\` from"
    echo "\`checker/status-verdict.sh\`. Every row is recounted from source by"
    echo "that script on the run that produced it -- none is a description."
    echo
    echo "<!-- VERDICT-BEGIN -->"
    emit_verdict
    echo "<!-- VERDICT-END -->"
    echo
    echo "Regenerated locally by \`bash checker/status-verdict.sh --write\` on top"
    echo "of commit \`$_sha\`. That line is PROVENANCE and is excluded from the"
    echo "comparison that decides whether the verdict changed: it records WHERE the"
    echo "numbers were counted, and claims nothing about gates having passed."
    echo
    echo "This file changes only when the measurements change. The rows above are"
    echo "recounted from source on every run of the generator."
  } > "$_target"
  echo "wrote $_target"
  exit 0
fi

emit_verdict
