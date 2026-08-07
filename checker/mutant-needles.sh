#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# R22: EVERY MUTANT'S NEEDLE MUST STILL EXIST ON A CLEAN TREE
#
# The suites already refuse to score a mutant whose patch did not apply: they
# report DISCARDED, and `checker/mutant-discipline.sh` proves every suite
# implements that a priori. This file closes the INVERSE hole, which discipline
# cannot see:
#
#     a suite in which EVERY mutant discards is not a strong suite.
#     It is zero evidence -- and it costs minutes of CI to find out.
#
# DISCARDED is honest about one mutant. A suite that is entirely discarded
# tested nothing, and the only signal is a number in a summary line nobody
# diffs. Two of my own mutants (RotLog L11/L14) discarded on 2026-08-07 because
# their needles contained a single quote; that was caught by reading the output,
# not by any gate.
#
# A needle goes stale the moment someone edits the line it quotes, and that edit
# is usually in a commit with nothing to do with mutation testing. This check is
# static -- no build, no mutation -- so it is cheap enough to run every time.
#
# WHY ONLY ZERO IS A FAILURE. A first cut failed on any count != 1. That was a
# spec forbidding a correct future: several suites use `run_mut_nth`, and others
# pass an expected occurrence count, so a needle at 10 sites is DECLARED there
# (RotInstall I01) rather than accidental. Failing those would have pushed the
# repair toward weakening real mutants to satisfy this checker. Zero is never
# correct under any convention.
#
# WHY BASH PARSES THE ARGUMENTS. Three attempts to tokenise these invocations in
# JavaScript gave three different wrong answers, in both directions:
#   * line-based single-quote matching -> FALSE POSITIVE on E10/V08, whose
#     needles use the '"'"' idiom (three chunks the shell joins into one word)
#   * chunk-splitting tokeniser        -> FALSE NEGATIVE on the same two
#   * word-concatenating tokeniser     -> FALSE POSITIVE on P01, double-quoted,
#     where \\\\ collapses to \\ and only the shell knows it
# P01 was measured KILLED by its own suite while this checker called it dead.
# So the invocations are replayed with `run_mut` stubbed to print its arguments:
# the needle tested here is byte-identical to the needle the suite will use.
# Only the invocation lines are replayed -- the suite preamble never runs,
# nothing is mutated, and a block containing a command substitution is REFUSED
# rather than executed. Refused is not passed.
#
# Exit: 0 pass, 1 fail, 2 refuse.
# =============================================================================
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

MUTDIR="$REPO/lean/mutate"
SRCDIR="$REPO/lean/Proofs"
[ -d "$MUTDIR" ] || { echo "REFUSE: $MUTDIR missing"; exit 2; }
[ -d "$SRCDIR" ] || { echo "REFUSE: $SRCDIR missing"; exit 2; }

echo "== R22: mutation needles, checked statically against a clean tree =="

WORK="$(mktemp -d "${TMPDIR:-/tmp}/needles.XXXXXX")"
[ -d "$WORK" ] && [ -w "$WORK" ] || { echo "REFUSE: scratch dir unusable"; exit 2; }
trap 'rm -rf "$WORK"' EXIT

RAW="$WORK/raw"; SCRIPT="$WORK/replay.sh"; DUMP="$WORK/args"
: > "$RAW"

for suite in "$MUTDIR"/mutate_*.sh; do
  sname="$(basename "$suite")"
  # A TRAILING BACKSLASH IS NOT THE ONLY WAY AN INVOCATION CONTINUES.
  # RotDuplicate M03's replacement argument contains a REAL NEWLINE inside a
  # single-quoted string -- it inserts two lines of Lean at once. Ending the
  # block at the first line without a trailing `\` cut it mid-quote, and the
  # unbalanced quote made bash refuse the whole invocation. So a block is closed
  # only when the line does not continue AND every quote in it is paired.
  awk -v S="$sname" '
    # COUNTING QUOTES IS NOT ENOUGH EITHER. The '"'"' idiom puts a single quote
    # INSIDE double quotes, so V08 carries five single quotes and a counting
    # rule declares it forever open -- merging it with the next invocation and
    # losing one mutant with no error at all. Only a state machine that knows
    # which quote is active gets this right.
    function closed(s,   i, c, st) {
      st = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (st == 0)      { if (c == "\047") st = 1; else if (c == "\042") st = 2 }
        else if (st == 1) { if (c == "\047") st = 0 }
        else              { if (c == "\042") st = 0 }
      }
      return (st == 0) && (s !~ /\\[ \t]*$/)
    }
    /^run_mut(_nth)?[ \t]+[A-Z][A-Za-z0-9]*[0-9][ \t]/ {
      inv = 1; buf = $0
      if (closed(buf)) { print "@SUITE " S; print buf; buf = ""; inv = 0 }
      next
    }
    inv {
      buf = buf "\n" $0
      if (closed(buf)) { print "@SUITE " S; print buf; buf = ""; inv = 0 }
    }
    END { if (inv && buf != "") { print "@SUITE " S; print buf } }
  ' "$suite" >> "$RAW"
done

# ONE BLOCK PER SCRIPT, and the isolation is the point. The first version
# emitted every invocation into a single file and replaced any line containing
# `$(` with a stub -- which severed a multi-line invocation mid-continuation.
# Bash parses ahead, so that ONE syntax error killed the entire replay: 2 of 293
# arrived and the rest vanished, while the checker cheerfully printed a table.
# A block that cannot be replayed must fail LOUDLY and alone.
: > "$DUMP"
BLOCKS=0; REFUSED=0; BROKEN=0
cur_suite=""
emit_block () {
  [ -n "${1:-}" ] || return 0
  BLOCKS=$((BLOCKS+1))
  case "$1" in
    *'$('*|*'`'*)
      REFUSED=$((REFUSED+1))
      printf '@SUITE %s\nREFUSED\n' "$cur_suite" >> "$DUMP"
      return 0 ;;
  esac
  {
    echo 'run_mut ()     { printf "ARG\t%s\n" "$@"; printf "END\n"; }'
    echo 'run_mut_nth () { printf "ARG\t%s\n" "$@"; printf "END\n"; }'
    printf '%s\n' "$1"
  } > "$SCRIPT"
  printf '@SUITE %s\n' "$cur_suite" >> "$DUMP"
  # `< /dev/null` is load-bearing, not hygiene. The reader below is a
  # `while IFS= read -r line` over $RAW, and a child bash inherits that stdin --
  # so the replay could consume the very lines still to be read, dropping
  # invocations at random. Measured: 292 of 293 replayed, the loss landing in
  # whichever suite happened to be mid-read.
  if ! bash "$SCRIPT" >> "$DUMP" 2>/dev/null < /dev/null; then
    BROKEN=$((BROKEN+1))
    printf 'BROKEN\n' >> "$DUMP"
    # NAME the invocation. A counter that says "1 failed" and not WHICH is half
    # an alarm: it cannot be acted on, and it cannot be distinguished from a
    # counting bug in this file.
    printf '  ----  BROKEN invocation in %s: %s\n' "$cur_suite" "$(printf '%s' "$1" | head -1)" >&2
  fi
}

block=""
while IFS= read -r line; do
  case "$line" in
    "@SUITE "*)
      emit_block "$block"; block=""
      cur_suite="${line#@SUITE }" ;;
    *)
      if [ -z "$block" ]; then block="$line"; else block="$block
$line"; fi ;;
  esac
done < "$RAW"
emit_block "$block"
DUMP_RC=0
[ "$BROKEN" -eq 0 ] || echo "  ----  $BROKEN invocation(s) failed to replay -- reported, never counted as checked"
[ "$REFUSED" -eq 0 ] || echo "  ----  $REFUSED invocation(s) refused (command substitution) -- refused is not passed"
if [ ! -s "$DUMP" ]; then
  echo "REFUSE: the replay produced no arguments (rc=$DUMP_RC) -- this checker would be vacuous"
  exit 2
fi

node - "$MUTDIR" "$SRCDIR" "$DUMP" <<'NODE'
"use strict";
const fs = require("fs");
const path = require("path");
const [, , MUTDIR, SRCDIR, DUMP] = process.argv;

let pass = 0, fail = 0;
const ok  = (m) => { pass++; console.log("  PASS  " + m); };
const bad = (m) => { fail++;
  if (process.env.GITHUB_ACTIONS === "true") console.log("::error title=mutant-needles::" + m);
  console.log("  FAIL  " + m); };

const proofs = fs.readdirSync(SRCDIR).filter((f) => f.endsWith(".lean")).map((f) => f.replace(/\.lean$/, ""));
const srcCache = new Map();
const readSrc = (mod) => {
  if (srcCache.has(mod)) return srcCache.get(mod);
  const p = path.join(SRCDIR, mod + ".lean");
  const s = fs.existsSync(p) ? fs.readFileSync(p, "utf8") : null;
  srcCache.set(mod, s); return s;
};
// Default target module derived from the suite name, never a hard-coded table:
// a table stops covering suites added after it was written.
const defaultModule = (suite) => {
  const stem = suite.replace(/^mutate_/, "").replace(/\.sh$/, "").toLowerCase();
  return proofs.find((m) => m.toLowerCase() === stem) || null;
};

// Replay output: @SUITE <name> / ARG\t<value> ... / END   (or REFUSED)
const lines = fs.readFileSync(DUMP, "utf8").split("\n");
let suite = null, args = null, refused = 0;
const records = [];
for (const ln of lines) {
  if (ln.startsWith("@SUITE ")) { suite = ln.slice(7).trim(); continue; }
  if (ln === "REFUSED") { refused++; continue; }
  if (ln.startsWith("ARG\t")) { if (args === null) args = []; args.push(ln.slice(4)); continue; }
  if (ln === "END") { if (args) records.push({ suite, args }); args = null; continue; }
}

// Declared counts, straight from the sources, so coverage is asserted not assumed.
const declaredBySuite = new Map();
let declaredTotal = 0;
for (const f of fs.readdirSync(MUTDIR).filter((x) => x.startsWith("mutate_") && x.endsWith(".sh"))) {
  const t = fs.readFileSync(path.join(MUTDIR, f), "utf8");
  const n = (t.match(/^run_mut(?:_nth)?[ \t]+[A-Z][A-Za-z0-9]*[0-9][ \t]/gm) || []).length;
  declaredBySuite.set(f, n); declaredTotal += n;
}

let missing = 0, multi = 0, unresolved = 0;
const seenBySuite = new Map();
for (const r of records) {
  seenBySuite.set(r.suite, (seenBySuite.get(r.suite) || 0) + 1);
  const id = r.args[0];
  let ai = 1, mod = defaultModule(r.suite);
  if (r.args[ai] && proofs.includes(r.args[ai])) { mod = r.args[ai]; ai++; }
  const needle = r.args[ai];
  if (needle === undefined || needle === "") {
    bad(r.suite + " " + id + ": no needle argument parsed -- unchecked is not passed"); unresolved++; continue;
  }
  const src = mod ? readSrc(mod) : null;
  if (src === null) { bad(r.suite + " " + id + ": target module '" + mod + "' not found"); unresolved++; continue; }
  let count = 0, from = 0;
  for (;;) { const k = src.indexOf(needle, from); if (k < 0) break; count++; from = k + 1; }
  if (count === 0) {
    bad(r.suite + " " + id + ": needle occurs 0 times in " + mod + " -- this mutant will DISCARD, testing nothing");
    missing++;
  } else if (count > 1) { multi++; }
}

// Coverage of THIS checker, asserted. An earlier cut silently examined 260 of
// 293 mutants and printed a clean summary -- the same shape as the defect it
// hunts.
let shortfall = 0;
for (const [f, n] of declaredBySuite) {
  const seen = seenBySuite.get(f) || 0;
  if (seen < n) { bad(f + ": replayed " + seen + " of " + n + " declared mutant(s) -- " + (n - seen) + " NOT CHECKED"); shortfall++; }
}

// Per-suite table, and the all-discard verdict this file exists for.
console.log("");
for (const [f, n] of [...declaredBySuite].sort()) {
  const seen = seenBySuite.get(f) || 0;
  const dead = records.filter((r) => r.suite === f).length ? "" : "";
  console.log("        " + String(n).padStart(3) + "  " + f + dead);
}
console.log("");
console.log("  ----  " + declaredBySuite.size + " suite(s), " + declaredTotal + " declared, " +
            records.length + " replayed, " + missing + " dead needle(s), " + multi +
            " multi-site (declared by their own harness), " + refused + " refused");

console.log("");
console.log("-- negative controls --");
{
  let c = 0, from = 0; const src = "def foo : Nat := 1\n";
  for (;;) { const k = src.indexOf("def bar", from); if (k < 0) break; c++; from = k + 1; }
  if (c === 0) ok("CONTROL: an absent needle IS detected as 0 occurrences");
  else bad("CONTROL: the counter found a needle that is not there");
}
{
  let c = 0, from = 0; const src = "x = 1\nx = 1\n";
  for (;;) { const k = src.indexOf("x = 1", from); if (k < 0) break; c++; from = k + 1; }
  if (c === 2) ok("CONTROL: a duplicated needle IS counted twice");
  else bad("CONTROL: duplicate counting is broken (" + c + ")");
}
if (records.length === 0) bad("no mutants replayed at all -- this checker would be vacuous");
else if (shortfall === 0) ok("replayed all " + declaredTotal + " declared mutant(s) across " + declaredBySuite.size + " suite(s)");

// The inverse failure, stated explicitly.
let allDead = 0;
for (const [f, n] of declaredBySuite) {
  const rs = records.filter((r) => r.suite === f);
  if (rs.length === 0) continue;
  let d = 0;
  for (const r of rs) {
    let ai = 1, mod = defaultModule(r.suite);
    if (r.args[ai] && proofs.includes(r.args[ai])) { mod = r.args[ai]; ai++; }
    const src = mod ? readSrc(mod) : null;
    const needle = r.args[ai];
    if (!src || needle === undefined || src.indexOf(needle) < 0) d++;
  }
  if (d === rs.length) { bad(f + ": ALL " + d + " mutant(s) would DISCARD -- zero evidence"); allDead++; }
}
if (allDead === 0) ok("no suite is entirely DISCARDED -- every suite carries real evidence");

console.log("");
console.log("== mutant-needles: " + pass + " passed, " + fail + " failed");
process.exit(fail === 0 ? 0 : 1);
NODE
exit $?
