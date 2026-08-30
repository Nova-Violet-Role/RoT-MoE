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
#   2. PAIRING: a route record must be preceded, within a bounded concurrency
#      window, by an UNCONSUMED gauge record carrying the same reading -- so a
#      truncated log cannot present an unverifiable number, and (since 6.0.2,
#      measured in the 80-turn hard session) two hook processes appending in
#      parallel cannot get their honest interleaving called corruption;
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


# THIS HARNESS DECLARES ITS OWN TRAFFIC.
#
# Measured 2026-08-09: seven checkers feed the router synthetic payloads and
# write into whatever ROTMOE_DEBUG_LOG points at. 738 of 955 sh route records
# in the live log were theirs, and nothing in the schema said so -- so every
# "live router health" figure computed from that log silently mixed real
# lifecycle traffic with replayed corpus traffic. The instrument was
# contaminating its own measurement and could not report that it was.
#
# RotSessionLog.test_is_never_hook proves the consequence: a record declared
# here can never be classified as live traffic, whatever the payload contains.
export ROTMOE_DEBUG_SRC=test

# Never write a per-session log into the repository being tested. A checker
# that leaves files behind is not a read-only observer.
export ROTMOE_DEBUG_LOCAL=0

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0; skip=0
ok()   { echo "  PASS  $*"; pass=$((pass+1)); }
# See the long note on the same function in checker/hook-footprint.sh: an
# unauthenticated caller cannot read CI logs (403, admin rights), so a failure
# that only exists in the log is a failure nobody outside the org can diagnose.
# This checker failed on macos-latest ALONE -- passing on ubuntu, windows and the
# development machine -- and the public annotation said only "Process completed
# with exit code 1". `::error::` lines become annotations, which are public.
bad()  {
  echo "  FAIL  $*"
  [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=log-replay::%s\n' "$*"
  fail=$((fail+1))
}

echo "== log replay: every gauge record recomputed from its own fields =="

command -v node >/dev/null 2>&1 || { bad "node not found"; echo "  log-replay: FAIL"; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/rotlog.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# --- the stem table, dumped from the router itself ---------------------------
# The replayer needs to know which lane owns which stem in order to certify a
# route record. It must NOT carry its own copy: a second list here would be a
# snapshot, and when the router's table changed the check would go on passing
# while checking something that no longer exists. So it is read out of the
# router's own STEMS_* assignments, in the router's own priority order.
#
# The parse is asserted, not assumed. If the assignment format ever changes this
# produces the wrong number of rows and the gate REFUSES rather than certifying
# route records against an empty table -- which would pass everything.
STEMS="$TMP/stems.txt"
sed -n "s/^STEMS_\([A-Z]*\)='\(.*\)'$/\1 \2/p" "$REPO/hooks/rot-router.sh" > "$STEMS"
_lanes=$(wc -l < "$STEMS" | tr -d ' ')
if [ "$_lanes" -ne 9 ]; then
  bad "parsed $_lanes lanes out of hooks/rot-router.sh, expected 9 -- the stem table did not load, so route records would be certified against nothing"
  echo "  log-replay: FAIL"; exit 1
fi
ok "stem table read from the router: $_lanes lanes, $(tr ' ' '\n' < "$STEMS" | grep -cv '^[A-Z]*$') stems"

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

// THE STEM TABLE IS READ FROM THE ROUTER, NEVER COPIED HERE. A second list of
// stems in this file would be a snapshot that drifts the day the router's table
// changes, and it would drift SILENTLY -- the check would keep passing while
// checking the wrong thing. Same defect the release-map rule (workflow-lint
// rule 6) exists to forbid, so it is not repeated here.
//
// argv[3] is a two-column dump produced by the shell below straight out of
// `hooks/rot-router.sh`'s own STEMS_* assignments: "<LANE> <stem> <stem> ...",
// in the router's priority order. First lane to own a stem wins, which is
// RotLog.Stemlog.first_owner_wins.
const LANE_OF_STEM = {};
{
  const tbl = fs.readFileSync(process.argv[3], "utf8").split(/\r?\n/).filter(l => l.trim() !== "");
  if (tbl.length !== 9) {
    console.log("the stem table dumped from the router has " + tbl.length +
                " lanes, not 9 -- the parse broke, so NOTHING would be checked");
    process.exit(2);
  }
  for (const row of tbl) {
    const parts = row.trim().split(/\s+/);
    const lane = parts.shift();
    for (const s of parts) if (!(s in LANE_OF_STEM)) LANE_OF_STEM[s] = lane;
  }
  if (Object.keys(LANE_OF_STEM).length < 50) {
    console.log("only " + Object.keys(LANE_OF_STEM).length +
                " stems parsed from the router -- refusing to certify against a stub table");
    process.exit(2);
  }
}

// THE PAIRING BUFFER -- concurrency-aware since 6.0.2. The original rule
// held one slot: a route record had to be IMMEDIATELY preceded by its gauge
// record. That is an assumption about a single-writer log, and MEASURED in
// the 80-turn hard session (bench/hard-session-6.0.1.md, turn 78) it is
// false in ordinary use: Claude Code batches tool calls in parallel, two
// router processes append their gauge/route pairs concurrently, and the
// sink reads ...gauge, gauge, route, route... -- 6 of 19,772 honest records
// were rejected as corrupt. Same defect shape as 6.0.0's OVERRIDE blindness:
// the auditor modelled less than the runtime does.
//
// The repair: a bounded window of UNCONSUMED gauge records. A route record
// consumes the NEWEST unconsumed gauge whose full reading rounds to the
// route's displayed reading -- the same half-ulp rule as before, so a
// tampered route value still matches nothing and is still rejected, and a
// route with no gauge before it is still an orphan. The window is small
// (8: more concurrent hook processes than that is not a workload this
// plugin produces) so a stale gauge from long ago can never launder a
// mismatched route.
let gaugeBuf = [];
const GAUGE_WINDOW = 8;
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
    gaugeBuf.push(r);
    if (gaugeBuf.length > GAUGE_WINDOW) gaugeBuf.shift();
  } else if (r.kind === "route") {
    nRoute++;
    // A route line must be preceded, within the concurrency window, by an
    // UNCONSUMED gauge line carrying the same reading. An orphan route line is
    // a truncated log presenting an unverifiable number as if it derived.
    if (gaugeBuf.length === 0) { errs.push(where + ": route record with no gauge record before it"); }
    else {
      // THE ROUTE LINE CARRIES THE *DISPLAYED* READING, not the full one:
      // "Rs":0.66427 on the gauge line, "Rs":"0.66" on the route line, matching
      // the marker the operator sees. The route value must equal a buffered
      // gauge value rounded to the precision the route value is written at --
      // half an ulp, no more. A stale or hand-edited number matches nothing in
      // the window and cannot survive; an honest rounding cannot fail; an
      // honest INTERLEAVING (two writers, measured in the hard session) finds
      // its own gauge a slot or two back and consumes exactly it.
      const txt = String(r.Rs);
      const dot = txt.indexOf(".");
      const dec = dot < 0 ? 0 : txt.length - dot - 1;
      const want = parseFloat(txt);
      let hit = -1;
      for (let k = gaugeBuf.length - 1; k >= 0; k--) {
        if (Number(gaugeBuf[k].Rs.toFixed(dec)) === want) { hit = k; break; }
      }
      if (hit < 0)
        errs.push(where + ": route Rs=" + txt + " matches no unconsumed gauge reading " +
                  "in the concurrency window (newest gauge: " + gaugeBuf[gaugeBuf.length - 1].Rs + ")");
      else gaugeBuf.splice(hit, 1);
    }
    if (!r.lane || !r.lens) errs.push(where + ": route record missing lane or lens");

    // RotLog.Stemlog.Auditable -- the ONLY clause here that certifies the
    // ROUTING DECISION. Everything above audits the gauge; the route record used
    // to carry lane, lens, Rs, chars and arm, every one of them checkable, and
    // none of them an explanation. A report of "my proof prompt routed
    // CONVERGENT" arrived with a fully replayable log in which the disputed fact
    // was simply absent.
    //
    // RotLog.Stemlog.auditable_imp_vocabSafe is why this is also the PRIVACY
    // check rather than a second one liable to be dropped: passing it entails
    // the stem came from the router's closed table, so a log that certifies
    // cannot simultaneously be carrying the user's text in that field.
    if (typeof r.stem !== "string") {
      errs.push(where + ": route record has no stem -- the routing decision is unexplained");
    } else if (r.stem === "") {
      // RotLog.Stemlog.empty_stem_iff_convergent
      if (r.lane !== "CONVERGENT")
        errs.push(where + ": lane " + r.lane + " fired while naming no stem -- unexplainable");
    } else {
      const owner = LANE_OF_STEM[r.stem];
      if (owner === undefined)
        errs.push(where + ": stem '" + r.stem + "' is not in the router's table -- " +
                  "this log carries text the router could not have produced");
      // NSIL OVERRIDE is the ONE verdict whose whole meaning is that the lane
      // deliberately departed from the stem's owner -- rot-lean.md section 3's
      // own worked example, `fix our relationship`: TIER 1 fires a CLINICAL
      // stem, Nova's TIER 2 overrides the lane to EMPATHIC, and the record
      // honestly carries both facts. MEASURED 2026-08-17, the v6.0.0 real
      // test (bench/real-test-6.0.0.md B8): this clause did not consult the
      // `nsil` field, so the honest record of a documented feature was
      // rejected as "a mis-route" -- and it shipped green because the corpus
      // below contained no OVERRIDE prompt. The exemption is NARROW and
      // load-bearing in BOTH directions: only `"nsil":"OVERRIDE"` earns it
      // (an absent or different verdict keeps the strict rule, so old logs
      // and mis-routes are judged exactly as before), and an OVERRIDE whose
      // lane still equals the stem's owner is rejected too -- an override
      // that overrode nothing is a contradiction in the record itself.
      // Vocabulary safety is UNTOUCHED: the stem must resolve in the
      // router's table before this branch is ever reached.
      else if (r.nsil === "OVERRIDE") {
        if (owner === r.lane)
          errs.push(where + ": nsil OVERRIDE but lane " + r.lane + " already owns stem '" +
                    r.stem + "' -- an override that overrode nothing");
      }
      else if (owner !== r.lane)
        errs.push(where + ": stem '" + r.stem + "' is owned by " + owner +
                  " but the record says " + r.lane + " -- a mis-route");
    }
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

# --- --audit: point the instrument at somebody else's log --------------------
# THE GATE BELOW PROVES THE REPLAYER WORKS ON LOGS THIS SCRIPT GENERATED. That
# is the right thing for CI and the wrong thing for the situation the log exists
# for: a user whose router misbehaved, holding a file, with no way to ask
# whether it is self-consistent. The instrument existed and was unreachable.
#
#   bash checker/log-replay.sh --audit /path/to/rotmoe.log
#
# Same replayer, same stem table read from the same router, no corpus and no
# controls -- it is the audit alone. Exit 0 means every record recomputes, every
# route line pairs with its gauge line, and every stem explains its lane.
#
# It deliberately does NOT regenerate anything or touch the tree: the one thing
# a diagnostic must never do is alter the state being diagnosed.
if [ "${1:-}" = "--audit" ]; then
  _f="${2:-}"
  if [ -z "$_f" ] || [ ! -f "$_f" ]; then
    echo "usage: log-replay.sh --audit <logfile>"
    echo "  audits a ROTMOE_DEBUG_LOG produced by either router arm."
    exit 2
  fi
  if [ ! -s "$_f" ]; then
    echo "  FAIL  $_f is empty -- there is nothing to audit"
    exit 1
  fi
  echo "== auditing $_f ($(wc -l < "$_f" | tr -d ' ') records) against hooks/rot-router.sh =="
  node "$TMP/replay.js" "$_f" "$STEMS"
  _rc=$?
  if [ "$_rc" -eq 0 ]; then echo "  log-replay --audit: PASS"; else echo "  log-replay --audit: FAIL"; fi
  exit "$_rc"
fi

# --- 1. produce a real log from both arms ------------------------------------
# The last prompt is the specification's own OVERRIDE worked example, added
# 2026-08-17 after the v6.0.0 real test proved this corpus never met the one
# record class the audit could not certify (bench/real-test-6.0.0.md B8). A
# corpus without an OVERRIDE prompt lets the stem clause ship untested against
# the router's flagship behaviour -- which is exactly what it did.
CORPUS='lake build the meter theorem
debug this segfault in the parser
compress this byte stream
what should we do about the roadmap
tell me a story about the sea
some entirely unremarkable sentence
fix our relationship'

# Each arm gets its OWN FRESH state dir. M and T are state (streak file +
# wall-clock gap), and the real state dir leaks: earlier checker steps in the
# same CI job had already run the sh router under session "unknown", so the sh
# arm opened with M=1.1/T=1.09 while the ps1 arm read a different view and
# wrote M=1/T=1.1 -- byte-identity across arms is impossible unless both start
# from the same (empty) state and replay the same corpus. MEASURED on
# ubuntu-latest: the cross-arm diff fired on M/T alone; every record still
# recomputed, so it was state skew, not arithmetic.
LOG_SH="$TMP/sh.log"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  printf '{"prompt":"%s"}' "$p" | ROTMOE_DEBUG_LOG="$LOG_SH" ROTMOE_STATE_DIR="$TMP/state-sh" sh hooks/rot-router.sh >/dev/null 2>&1
done <<EOF
$CORPUS
EOF

if [ -s "$LOG_SH" ]; then
  ok "[sh] the router wrote a debug log ($(wc -l < "$LOG_SH" | tr -d ' ') records)"
else
  bad "[sh] ROTMOE_DEBUG_LOG produced nothing -- the log is not being written at all"
fi

out="$(node "$TMP/replay.js" "$LOG_SH" "$STEMS" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "[sh] every record recomputes: $out" \
              || { bad "[sh] the log does not recompute"; echo "$out" | sed 's/^/        /'; }

if command -v pwsh >/dev/null 2>&1; then
  LOG_PS="$TMP/ps.log"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    printf '{"prompt":"%s"}' "$p" | ROTMOE_DEBUG_LOG="$LOG_PS" ROTMOE_STATE_DIR="$TMP/state-ps" pwsh -NoProfile -File ./hooks/rot-router.ps1 >/dev/null 2>&1
  done <<EOF
$CORPUS
EOF
  if [ -s "$LOG_PS" ]; then
    ok "[ps1] the router wrote a debug log ($(wc -l < "$LOG_PS" | tr -d ' ') records)"
  else
    bad "[ps1] ROTMOE_DEBUG_LOG produced nothing"
  fi
  out="$(node "$TMP/replay.js" "$LOG_PS" "$STEMS" 2>&1)"; rc=$?
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
  # `sed -i` IS NOT PORTABLE, and this is the exact failure it caused.
  #
  # GNU sed reads `-i` with an OPTIONAL suffix attached (`-i.bak`); BSD sed, as
  # shipped on macOS, requires the suffix as a SEPARATE argument. So on macOS
  #     sed -i "$expr" "$f"
  # takes "$expr" as the backup suffix and "$f" as the script, which is not a
  # valid sed program -- the command errors and THE FILE IS NEVER TOUCHED.
  #
  # MEASURED on macos-latest: all five controls reported
  #     CONTROL DISCARDED: ... the corruption did not apply, so NOTHING was tested
  # while ubuntu and windows were green. The harness was right and loud about it;
  # this is what it was reporting. (It was only readable because the ::error::
  # annotation added the commit before carried the message off the runner --
  # the log itself needs admin rights.)
  #
  # The redirect form is POSIX and behaves identically on all three runners.
  sed "$expr" "$f" > "$f.mut" && mv "$f.mut" "$f"
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
  node "$TMP/replay.js" "$f" "$STEMS" >/dev/null 2>&1
  rc=$?
  if [ ! -s "$f" ]; then
    bad "CONTROL DISCARDED: $label -- the mutated log is empty, so the RED is meaningless"
  elif [ "$rc" -ne 0 ]; then
    ok "CONTROL: $label is REJECTED"
  else
    bad "CONTROL: $label was ACCEPTED -- the replayer certifies corruption"
  fi
}

# VALUE-AGNOSTIC patterns, deliberately. The first draft hardcoded the live
# numbers ("Rs":0\.66427, "sum":5\.97843, "Rs":"0\.66") and paid for it: when
# leaked state shifted M/T, the live values moved, all three seds matched zero
# bytes, and the harness reported CONTROL DISCARDED three times on ubuntu.
# A control keyed to today's output is a control that dies the day the output
# legitimately changes. These match the FIELD, not the value; they corrupt
# every record, and cmp -s still proves the mutation landed.
ctl "a tampered Rs"        's/"Rs":[0-9][0-9.]*/"Rs":9.99999/'
# The ROUTE line specifically (quoted Rs) -- the rounding rule must not have
# loosened. A forged two-digit value is a different number wearing the right
# number of digits.
ctl "a tampered route Rs"  's/"Rs":"[0-9][0-9.]*"/"Rs":"9.99"/'
ctl "a tampered sum"       's/"sum":[0-9][0-9.]*/"sum":4.00000/'
ctl "a wrong mu"           's/"mu":1\.15/"mu":1.55/'
ctl "a wrong sigma"        's/"sigma":0\.8257/"sigma":0.5000/'

# --- controls for the STEM clause -------------------------------------------
# The four corruptions the routing audit exists to catch. Without these the
# clause is an untested alarm: it passed on honest logs above, which proves only
# that it does not fire spuriously.
#
# The corpus's first prompt is "lake build the meter theorem", so the FORGE
# record carries stem "lake" -- that is the field these rewrite.
#
# 1. THE MIS-ROUTE. A real stem, attached to a lane that does not own it. This
#    is the failure the whole section was built for: before the stem existed,
#    such a record was indistinguishable from a correct one.
ctl "a mis-routed record (FORGE claiming a CLINICAL stem)" 's/"stem":"build"/"stem":"debug"/'
# 2. THE LEAK. Text that is not a stem at all. RotLog.Stemlog.auditable_imp_vocabSafe
#    says the audit entails vocabulary safety; this is that theorem's control, and
#    a green here is what makes the privacy claim testable rather than asserted.
ctl "prompt text leaked into the stem field"              's/"stem":"build"/"stem":"acme merger q3"/'
# 3. A lane that fired while naming nothing -- RotLog.Stemlog.empty_stem_iff_convergent.
ctl "a fired lane with an empty stem"                     's/"stem":"build"/"stem":""/'
# 4. THE FIELD REMOVED ENTIRELY, which is also what a log from a router older than
#    router looks like. Rejecting it is deliberate: an old log cannot answer the
#    question this gate asks, and silently certifying it would report "routing
#    verified" about records in which the routing evidence does not exist. The
#    honest outcome is a red that tells the reporter to re-capture.
ctl "a route record with no stem field at all"            's/,"stem":"build"//'

# --- controls for the OVERRIDE exemption --------------------------------------
# Added with the exemption itself (2026-08-17): an exemption without controls
# is how the ORIGINAL defect shipped -- an untested clause meeting an untested
# record class. The corpus's `fix our relationship` record carries
# stem "fix" (owned by CLINICAL), lane EMPATHIC, nsil OVERRIDE.
#
# 5. THE EXEMPTION MUST NOT LEAK to other verdicts: the same record relabelled
#    CONFIRM is an ordinary mis-route again and must be rejected.
ctl "an OVERRIDE relabelled CONFIRM (the exemption must stay narrow)" 's/"nsil":"OVERRIDE"/"nsil":"CONFIRM"/'
# 6. AN OVERRIDE THAT OVERRODE NOTHING: lane rewritten to the stem's own
#    owner while still claiming OVERRIDE -- a contradiction in the record.
ctl "an OVERRIDE whose lane already owns the stem" '/"nsil":"OVERRIDE"/s/"lane":"EMPATHIC"/"lane":"CLINICAL"/'

# --- controls for the CONCURRENCY window (added with it, 2026-08-18) ---------
# MEASURED in the 80-turn hard session: parallel tool calls fire two router
# processes whose gauge/route pairs interleave in the shared sink -- six of
# 19,772 honest records were rejected by the old adjacency rule. The window
# pairing must ACCEPT a real interleaving and still REJECT a route that
# arrives before any gauge exists. Tampering rejection is already held by
# the "tampered route Rs" control above: a forged value matches nothing.
f="$TMP/interleave.log"
awk 'NR<=4{l[NR]=$0} END{print l[1]; print l[3]; print l[2]; print l[4]}' "$LOG_SH" > "$f"
node "$TMP/replay.js" "$f" "$STEMS" >/dev/null 2>&1
[ $? -eq 0 ] && ok "CONTROL: a concurrent interleaving (gauge,gauge,route,route) is ACCEPTED" \
             || bad "CONTROL: an honest two-writer interleaving was REJECTED -- the hard-session defect is back"

f="$TMP/routefirst.log"
awk 'NR<=2{l[NR]=$0} END{print l[2]; print l[1]}' "$LOG_SH" > "$f"
node "$TMP/replay.js" "$f" "$STEMS" >/dev/null 2>&1
[ $? -ne 0 ] && ok "CONTROL: a route record arriving before any gauge is still REJECTED" \
             || bad "CONTROL: a gauge-less route was ACCEPTED -- the window has no floor"

# Structural corruptions: an orphan route line, and a broken JSON line.
f="$TMP/orphan.log"; grep '"kind":"route"' "$LOG_SH" | head -1 > "$f"
node "$TMP/replay.js" "$f" "$STEMS" >/dev/null 2>&1
[ $? -ne 0 ] && ok "CONTROL: an orphan route record (truncated log) is REJECTED" \
             || bad "CONTROL: an orphan route record was ACCEPTED"

f="$TMP/broken.log"; cp "$LOG_SH" "$f"; printf '{"kind":"gauge", NOT JSON\n' >> "$f"
node "$TMP/replay.js" "$f" "$STEMS" >/dev/null 2>&1
[ $? -ne 0 ] && ok "CONTROL: a malformed line is REJECTED" \
             || bad "CONTROL: a malformed line was ACCEPTED"

# And the positive control for the controls: the untouched log still passes, so
# the four REDs above are attributable to the corruption and not to the harness.
node "$TMP/replay.js" "$LOG_SH" "$STEMS" >/dev/null 2>&1
[ $? -eq 0 ] && ok "CONTROL: the untouched log still passes (the REDs are the corruptions)" \
             || bad "CONTROL: the untouched log now fails -- the harness is broken"

echo
echo "  $pass passed, $fail failed, $skip skipped"
if [ "$fail" -gt 0 ]; then echo "  log-replay: FAIL"; exit 1; fi
echo "  log-replay: PASS"
exit 0
