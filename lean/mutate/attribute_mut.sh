#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# Re-attribute the stored mutation logs using ERROR lines only.
# The first pass grepped every "RotGauge.lean:<n>" occurrence, which includes
# mathlib linter WARNINGS -- so it reported ~8 spurious dead declarations under
# every mutant. Over-reporting is as dishonest as under-reporting: it makes a
# theorem look load-bearing for a mutation that never touched it.
set -u

# Repo-relative by construction: no machine-local path ships (R2).
# Override with LEAN_ROOT=... to run against a different workspace.
LEAN_ROOT="${LEAN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
F="$LEAN_ROOT/Proofs/RotGauge.lean"
for log in ${TMPDIR:-/tmp}/mut/M*.log; do
  id=$(basename "$log" .log)
  lines=$(grep -oE "^error: Proofs/RotGauge\.lean:[0-9]+" "$log" | grep -oE "[0-9]+$" | sort -un)
  [ -z "$lines" ] && { echo "$id  (no error lines)"; continue; }
  dead=$(for ln in $lines; do
    awk -v L="$ln" '
      /^(@\[[^]]*\] )?(noncomputable )?(theorem|lemma|def|instance|structure|inductive|example)[ (]/ { if (NR <= L) name=$0 }
      END { if (name != "") print name }' "$F"
  done | sed -E 's/^@\[[^]]*\] *//; s/^(noncomputable )?(theorem|lemma|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' | sort -u | tr '\n' ' ')
  echo "$id  dead: $dead"
done
