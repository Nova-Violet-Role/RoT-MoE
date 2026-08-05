#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# LOG REPLAY -- the debug log was written by both arms and read by NOTHING.
#
# `rot-router.sh` states the log's purpose in its own comment:
#
#     "one JSON line carrying every factor of the sum, so the reported R/s+ can
#      be recomputed by hand from the record."
#
# WHAT WAS ALREADY COVERED, MEASURED BEFORE WRITING A LINE OF THIS -- because
# the first draft of this header said "the log is read by NOTHING", and that is
# FALSE. `checker/bench-router.sh` §5 already opened the log and already did the
# most important thing with it. Stating the delta honestly is the whole point of
# a gate; a new checker justified by a defect that does not exist is exactly the
# padding this project refuses.
#
# bench-router.sh §5 checks, on the POSIX arm's log only:
#   * the log is non-empty and has one gauge record per evaluation
#   * every record carries K=9 and nine per-lens terms (no lens dropped out)
#   * SUM of the logged `term` values, divided by K, equals the logged `Rs`
#
# That is a real check and it stays. What it CANNOT see is everything upstream of
# `term`: it sums the terms the record already claims. A record with the wrong
# `mu`, the wrong `sigma`, the wrong `H` or the wrong `mean` is internally
# consistent at the level of sums and passes -- the headline number stays
# plausible, which is the failure mode bench-router's own comment names two
# paragraphs earlier and then does not reach.
#
# THE DELTA THIS GATE ADDS, each item verified by a control below:
#   1. every factor is RECOMPUTED from lambda, mu, a, breadth -- mean, delta,
#      sigma, H and the term itself -- not merely summed;
#   2. PAIRING: a route record must follow a gauge record carrying the same
#      reading, so a truncated log cannot present an unverifiable number;
#   3. the route line's displayed value must be a faithful ROUNDING of the gauge
#      line's, which is what binds the marker the operator reads to the
#      arithmetic behind it;
#   4. every line must be valid JSON;
#   5. the PowerShell arm's log is replayed too, and the two arms' gauge records
#      must be byte-identical -- bench-router runs the ps1 arm for TIMING and
#      never replays what it wrote.
#
# WHAT THIS DOES. It runs BOTH arms over a prompt corpus with logging on, then
# recomputes, from each record's OWN fields:
#
#     mean = (Σ a) / K            delta = |a - mean|
#     sigma = 1 / (1 + e^(-4(delta - 1/2)))
#     H = min(1, a / breadth)     (0 when breadth = 0)
#     term = lambda * sigma * (1 + H) * mu * M * C * T
#     sum = Σ term                Rs = sum / K
#
# and compares every one against what the line claims. It also checks pairing
# (every route line preceded by a gauge line carrying the same reading) and
# cross-arm equality of the gauge records for one input.
#
# The Lean statements are lean/Proofs/RotLog.lean: `consistent_Rs_eq_gauge`
# (a consistent record reports exactly the gauge), `consistent_Rs_unique` (two
# consistent records over the same terms cannot disagree), `orphan_route_detected`
# and `mismatched_pair_detected` (the corruptions this must catch).
#
# TOLERANCE IS A CHECKER CONCERN, DELIBERATELY. The log holds rounded decimal
# text -- 4 to 5 places -- so exact equality would fail on honest records. The
# tolerance is stated once, applied everywhere, and is far tighter than any real
# arithmetic error: 2e-3 absolute. A tolerance loose enough to hide a wrong mu
# would make this gate decorative, so the negative controls below perturb a field
# by more than that and require a RED.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0; skip=0
ok()   { echo "  PASS  $*"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $*"; fail=$((fail+1)); }

echo "== log replay: every gauge record recomputed from its own fields =="

command -v node >/dev/null 2>&1 || { bad "node not found"; echo "  log-replay: FAIL"; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/rotlog.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# --- the replayer ------------------------------------------------------------
# Reads a log on argv[1]. Exits 0 if every record is self-consistent and the log
# is well paired; 1 otherwise, naming the first offending line. This is the
# instrument; everything below is its corpus and its controls.
cat > "$TMP/replay.js" <<'JS'
"use strict";
const fs = require("fs");
const TOL = 2e-3;
const file = process.argv[2];
const lines = fs.readFileSync(file, "utf8").split(/\r?\n/).filter(l => l.trim() !== "");
let errs = [];
const near = (a, b) => Math.abs(a - b) <= TOL;

let prevGauge = null;      // the last gauge record seen, for pairing
let nGauge = 0, nRoute = 0;

lines.forEach((l, idx) => {
  const where = "line " + (idx + 1);
  let r;
  try { r = JSON.parse(l); }
  catch (e) { errs.push(where + ": not valid JSON -- " + e.message); return; }

  if (r.kind === "gauge") {
    nGauge++;
    const L = r.lenses || [];
    if (L.length === 0) { errs.push(where + ": gauge record carries no lenses"); return; }
    if (r.K !== L.length) errs.push(where + ": K=" + r.K + " but " + L.length + " lenses listed");

    // mean, from the activities the record itself lists
    const sumA = L.reduce((s, x) => s + x.a, 0);
    const mean = sumA / L.length;
    if (!near(mean, r.mean)) errs.push(where + ": mean claimed " + r.mean + ", recomputed " + mean.toFixed(6));

    let sum = 0;
    for (const x of L) {
      const delta = Math.abs(x.a - mean);
      if (!near(delta, x.delta))
        errs.push(where + " [" + x.lens + "]: delta claimed " + x.delta + ", recomputed " + delta.toFixed(6));
      const sigma = 1 / (1 + Math.exp(-4 * (delta - 0.5)));
      if (!near(sigma, x.sigma))
        errs.push(where + " [" + x.lens + "]: sigma claimed " + x.sigma + ", recomputed " + sigma.toFixed(6));
      const H = r.breadth > 0 ? Math.min(1, x.a / r.breadth) : 0;
      if (!near(H, x.H))
        errs.push(where + " [" + x.lens + "]: H claimed " + x.H + ", recomputed " + H.toFixed(6));
      const term = x.lambda * sigma * (1 + H) * x.mu * r.M * r.C * r.T;
      if (!near(term, x.term))
        errs.push(where + " [" + x.lens + "]: term claimed " + x.term + ", recomputed " + term.toFixed(6));
      sum += x.term;
    }
    if (!near(sum, r.sum)) errs.push(where + ": sum claimed " + r.sum + ", terms add to " + sum.toFixed(6));
    const Rs = r.sum / r.K;
    if (!near(Rs, r.Rs)) errs.push(where + ": Rs claimed " + r.Rs + ", sum/K = " + Rs.toFixed(6));
    // RotLog.route_Rs_ne_zero: with positive weights the gauge cannot be zero,
    // so a zero here means the number was never computed.
    if (r.Rs === 0) errs.push(where + ": Rs is exactly 0 -- a placeholder, not a measurement");
    prevGauge = r;
  } else if (r.kind === "route") {
    nRoute++;
    // RotLog.WellPaired: a route line must be preceded by a gauge line carrying
    // the same reading. An orphan route line is a truncated log presenting an
    // unverifiable number as if it had been derived.
    if (!prevGauge) { errs.push(where + ": route record with no gauge record before it"); }
    else {
      // THE ROUTE LINE CARRIES THE *DISPLAYED* READING, not the full one:
      // "Rs":0.66427 on the gauge line, "Rs":"0.66" on the route line, matching
      // the marker the operator sees. Measured on the first run of this gate --
      // twelve records per arm recomputed field for field with zero error, and
      // this rounding was the only disagreement, because the rule asserted plain
      // equality.
      //
      // The rule now asserts what is actually true and is STRICTER than a loose
      // tolerance would be: the route value must equal the gauge value rounded
      // to the precision the route value is written at. Half an ulp, no more. A
      // stale or hand-edited number cannot survive that; an honest rounding
      // cannot fail it. The corresponding statement is RotLog.WellPaired, whose
      // tolerance parameter exists for this same reason.
      const txt = String(r.Rs);
      const dot = txt.indexOf(".");
      const dec = dot < 0 ? 0 : txt.length - dot - 1;
      const rounded = Number(prevGauge.Rs.toFixed(dec));
      if (parseFloat(txt) !== rounded)
        errs.push(where + ": route Rs=" + txt + " is not the gauge reading " +
                  prevGauge.Rs + " rounded to " + dec + " places (" + rounded + ")");
    }
    if (!r.lane || !r.lens) errs.push(where + ": route record missing lane or lens");
    prevGauge = null;
  } else {
    errs.push(where + ": unknown record kind '" + r.kind + "'");
  }
});

if (nGauge === 0 || nRoute === 0) {
  errs.push("the log has " + nGauge + " gauge and " + nRoute + " route records -- a log with neither proves nothing");
}
if (errs.length) { console.log(errs.slice(0, 6).join("\n")); process.exit(1); }
console.log("records: " + nGauge + " gauge, " + nRoute + " route -- all recomputed");
process.exit(0);
JS

# --- 1. produce a real log from both arms ------------------------------------
CORPUS='lake build the meter theorem
debug this segfault in the parser
compress this byte stream
what should we do about the roadmap
tell me a story about the sea
some entirely unremarkable sentence'

LOG_SH="$TMP/sh.log"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  printf '{"prompt":"%s"}' "$p" | ROTMOE_DEBUG_LOG="$LOG_SH" sh hooks/rot-router.sh >/dev/null 2>&1
done <<EOF
$CORPUS
EOF

if [ -s "$LOG_SH" ]; then
  ok "[sh] the router wrote a debug log ($(wc -l < "$LOG_SH" | tr -d ' ') records)"
else
  bad "[sh] ROTMOE_DEBUG_LOG produced nothing -- the log is not being written at all"
fi

out="$(node "$TMP/replay.js" "$LOG_SH" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "[sh] every record recomputes: $out" \
              || { bad "[sh] the log does not recompute"; echo "$out" | sed 's/^/        /'; }

if command -v pwsh >/dev/null 2>&1; then
  LOG_PS="$TMP/ps.log"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    printf '{"prompt":"%s"}' "$p" | ROTMOE_DEBUG_LOG="$LOG_PS" pwsh -NoProfile -File ./hooks/rot-router.ps1 >/dev/null 2>&1
  done <<EOF
$CORPUS
EOF
  if [ -s "$LOG_PS" ]; then
    ok "[ps1] the router wrote a debug log ($(wc -l < "$LOG_PS" | tr -d ' ') records)"
  else
    bad "[ps1] ROTMOE_DEBUG_LOG produced nothing"
  fi
  out="$(node "$TMP/replay.js" "$LOG_PS" 2>&1)"; rc=$?
  [ "$rc" = 0 ] && ok "[ps1] every record recomputes: $out" \
                || { bad "[ps1] the log does not recompute"; echo "$out" | sed 's/^/        /'; }

  # CROSS-ARM: the gauge records must be IDENTICAL apart from the timestamp.
  # RotLog.consistent_Rs_unique says two consistent records over the same terms
  # cannot disagree -- so a difference here is a real divergence, not a rounding
  # accident.
  norm () { grep '"kind":"gauge"' "$1" | sed 's/"ts":"[^"]*",//'; }
  if diff -q <(norm "$LOG_SH") <(norm "$LOG_PS") >/dev/null 2>&1; then
    ok "both arms' gauge records are byte-identical (timestamp excluded)"
  else
    bad "the arms' gauge records DIFFER -- one of them is computing something else"
    diff <(norm "$LOG_SH") <(norm "$LOG_PS") | head -4 | sed 's/^/        /'
  fi
else
  echo "  SKIP  no pwsh on this runner -- the PowerShell arm's log was NOT replayed."
  echo "        This is a SKIP, never a PASS: an unrun arm proves nothing."
  skip=1
fi

# --- 2. THE NEGATIVE CONTROLS ------------------------------------------------
# A replayer that accepts everything is worse than none: it certifies. Each
# control corrupts ONE field by more than the tolerance and requires a RED.
ctl () {   # ctl <label> <sed-expression>
  label="$1"; expr="$2"
  f="$TMP/ctl.log"; cp "$LOG_SH" "$f"
  sed -i "$expr" "$f"
  # A CONTROL IS EVIDENCE ONLY IF THE CORRUPTION LANDED. `cmp -s` against the
  # original is the check, and a patch that did not apply is reported as
  # DISCARDED -- never folded into a pass. The two mean opposite things: a pass
  # is a claim about the replayer, a discard is a claim about this harness. A
  # sed whose escaping is wrong leaves the file untouched, the replayer then
  # correctly accepts an honest log, and a harness that did not check would
  # record that as "the control fired" when nothing was tested.
  if cmp -s "$f" "$LOG_SH"; then
    bad "CONTROL DISCARDED: $label -- the corruption did not apply, so NOTHING was tested"
    return
  fi
  node "$TMP/replay.js" "$f" >/dev/null 2>&1
  rc=$?
  if [ ! -s "$f" ]; then
    bad "CONTROL DISCARDED: $label -- the mutated log is empty, so the RED is meaningless"
  elif [ "$rc" -ne 0 ]; then
    ok "CONTROL: $label is REJECTED"
  else
    bad "CONTROL: $label was ACCEPTED -- the replayer certifies corruption"
  fi
}

ctl "a tampered Rs"        's/"Rs":0\.66427/"Rs":0.99999/'
# The ROUTE line specifically -- the rounding rule must not have loosened this.
# 0.66 -> 0.70 is a rounding of nothing; it is a different number wearing the
# right number of digits.
ctl "a tampered route Rs"  's/"Rs":"0\.66"/"Rs":"0.70"/'
ctl "a tampered sum"       's/"sum":5\.97843/"sum":4.00000/'
ctl "a wrong mu"           's/"mu":1\.15/"mu":1.55/'
ctl "a wrong sigma"        's/"sigma":0\.8257/"sigma":0.5000/'

# Structural corruptions: an orphan route line, and a broken JSON line.
f="$TMP/orphan.log"; grep '"kind":"route"' "$LOG_SH" | head -1 > "$f"
node "$TMP/replay.js" "$f" >/dev/null 2>&1
[ $? -ne 0 ] && ok "CONTROL: an orphan route record (truncated log) is REJECTED" \
             || bad "CONTROL: an orphan route record was ACCEPTED"

f="$TMP/broken.log"; cp "$LOG_SH" "$f"; printf '{"kind":"gauge", NOT JSON\n' >> "$f"
node "$TMP/replay.js" "$f" >/dev/null 2>&1
[ $? -ne 0 ] && ok "CONTROL: a malformed line is REJECTED" \
             || bad "CONTROL: a malformed line was ACCEPTED"

# And the positive control for the controls: the untouched log still passes, so
# the four REDs above are attributable to the corruption and not to the harness.
node "$TMP/replay.js" "$LOG_SH" >/dev/null 2>&1
[ $? -eq 0 ] && ok "CONTROL: the untouched log still passes (the REDs are the corruptions)" \
             || bad "CONTROL: the untouched log now fails -- the harness is broken"

echo
echo "  $pass passed, $fail failed, $skip skipped"
if [ "$fail" -gt 0 ]; then echo "  log-replay: FAIL"; exit 1; fi
echo "  log-replay: PASS"
exit 0
