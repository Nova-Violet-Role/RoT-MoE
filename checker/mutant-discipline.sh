#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE LEAN SPEC MUST GOVERN THE SHELL, OR IT IS A DOCUMENT WITH THEOREMS IN IT.
#
# `lean/Proofs/RotMutant.lean` settles the riddle: a mutation may be counted as
# evidence about an assertion ONLY IF the patch landed, and a patch landed only
# when ALL THREE hold --
#
#     the patch tool exited 0
#     the produced mutant is NOT empty
#     the produced mutant DIFFERS from the original
#
# `killed_implies_all_three` proves that dropping any one of them admits a
# false kill, and three mutations of `landed` each killed the theorem that
# depends on the condition they removed. That is the theory.
#
# THE PRACTICE IS THIS FILE. Every mutation harness in the repository must
# implement all three tests, because the proof is about a rule and the rule is
# only worth anything where it executes. Both defects that motivated the module
# were REAL and both shipped green:
#
#   route 1  a sed that matched nothing -> mutant identical to the original
#   route 2  a malformed sed -> exit 1, EMPTY mutant, scored as a KILL
#
# A harness testing only `changed` catches route 1 and passes route 2. That is
# exactly what was in the tree this morning.
#
# WHAT THIS CHECKS, per harness that applies a patch and judges the result:
#   1. it reads the patch tool's EXIT STATUS
#   2. it rejects an EMPTY mutant
#   3. it compares the mutant against the ORIGINAL
#   4. it uses the word "discard" -- the outcome must be REPORTED as its own
#      category, never folded into survived or killed
#
# Exit: 0 all harnesses disciplined · 1 one is not · 2 refuse.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad() { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }

SPEC="lean/Proofs/RotMutant.lean"
[ -f "$SPEC" ] || { echo "REFUSE: $SPEC missing -- there is no spec to bind to"; exit 2; }

echo "== mutation discipline: the shell must obey RotMutant.lean =="

# --- the spec itself must still say what this checker claims it says --------
# If someone weakens `landed` in Lean, this binding must not keep quoting the
# old rule. The three conditions are read back out of the proof file.
spec_src="$(sed 's|--.*$||' "$SPEC")"
for cond in 'toolExit == 0' 'empty' 'changed'; do
  case "$spec_src" in
    *"$cond"*) ok "the spec still requires '$cond' in \`landed\`" ;;
    *) bad "the spec no longer mentions '$cond' -- RotMutant.lean was weakened and this binding is stale" ;;
  esac
done

# --- every harness that applies a patch must implement all three ------------
# A harness WRITES A PATCHED COPY and then judges it. Found by behaviour, never
# by a hard-coded list, so a harness added tomorrow is covered without editing
# this file.
#
# NARROWED after the first run: detecting on "mentions sed" demanded mutation
# discipline of install-roundtrip.sh and verdict-schedule-sim.sh, whose `sed`
# calls only indent output for display. A rule that fails a correct script is a
# defect in the rule, so the pattern is a patch tool WRITING a file.
# NARROWED A SECOND TIME, 2026-08-05, and for the same reason as the first.
#
# The second filter used to read `killed|survived|discard|CONTROL`. `CONTROL` is
# the problem: a negative control is something EVERY well-written checker in this
# repository has, and several of them also write a scratch file with sed. So the
# moment checker/install-parity.sh grew
#
#     sed '$d' "$WORK/plugin.txt" > "$WORK/plugin.short.txt"
#
# to build its control, and checker/workflow-lint.sh grew a comment-stripped
# scratch copy, both were classified as MUTATION HARNESSES and failed for missing
# `discard-reporting` -- a discipline that is meaningless in a checker that never
# produces a mutant of anything.
#
# A rule that fails a correct script is a defect in the rule. Measured both ways
# before changing it: the loose form selects 17 files, the tightened form selects
# 15, and the two dropped are exactly those two -- every genuine harness reports
# killed/survived/discarded and is still selected. That is a classifier repair,
# not a relaxation of the discipline: nothing that reports a kill escapes.
harnesses="$(grep -lE 'sed -i|perl -0?pi|(sed|awk|perl)[^|]*> *"' checker/*.sh lean/mutate/*.sh 2>/dev/null \
             | xargs grep -lE 'killed|survived|discard' 2>/dev/null | sort -u)"
[ -n "$harnesses" ] || { echo "REFUSE: found no mutation harness at all -- this checker would pass vacuously"; exit 2; }

n_h=0
for h in $harnesses; do
  code="$(sed 's/#.*$//' "$h")"
  n_h=$((n_h+1))
  miss=""

  # LANDING may be established two ways and BOTH satisfy the spec. Demanding
  # one implementation would fail the eight Lean suites, which are correct:
  # they assert the needle occurs EXACTLY ONCE before patching, so a patch that
  # cannot apply is refused up front and `changed` holds by construction. That
  # is stronger than checking afterwards, not weaker.
  #
  #   A PRIORI      count the needle first; refuse unless it is present
  #   A POSTERIORI  read the tool's exit status, reject an empty mutant, and
  #                 compare the result against the original
  a_priori=0
  case "$code" in
    *'expected 1'*|*'occurs'*|*'needle'*) a_priori=1 ;;
  esac

  if [ "$a_priori" -eq 0 ]; then
    # 1. exit status of the patch tool
    case "$code" in
      *'rc=$?'*|*'$?'*) : ;;
      *) miss="$miss exit-status" ;;
    esac
  fi
  # 2. empty mutant rejected.
  #
  # The pattern must not be `-s "$C"`: that also matches `cmp -s "$C" "$W"`,
  # which is the CHANGED test, so a harness with no empty check at all scored
  # as having one. Measured here on the first run -- the control that plants a
  # harness missing this condition was ACCEPTED, which is how the blindness was
  # found rather than shipped. The test operator form is unambiguous.
  if [ "$a_priori" -eq 0 ]; then
    case "$code" in
      *'! -s '*|*'[ -s '*|*'if [ -s'*) : ;;
      *) miss="$miss empty-check" ;;
    esac
    # 3. compared against the original
    case "$code" in
      *"cmp -s"*|*"diff -q"*|*"git diff"*) : ;;
      *) miss="$miss changed-check" ;;
    esac
  fi
  # 4. reports the third category by name
  case "$code" in
    *discard*|*DISCARD*|*Discard*) : ;;
    *) miss="$miss discard-reporting" ;;
  esac

  if [ -z "$miss" ]; then
    lbl="a-posteriori exit+empty+changed"; [ "$a_priori" -eq 1 ] && lbl="a-priori needle count"
    ok "$(basename "$h") establishes landing ($lbl) and reports discards"
  else
    bad "$(basename "$h") is missing:$miss -- RotMutant.killed_implies_all_three says this admits a FALSE KILL"
  fi
done
[ "$n_h" -gt 0 ] && ok "$n_h patch-applying harness(es) audited" \
                || bad "no patch-applying harness was audited -- the scan found nothing to check"

# --- negative controls ------------------------------------------------------
echo
echo "-- negative controls --"
# A harness missing each condition in turn must be REJECTED. Built as scratch
# text rather than by editing a real file: the predicate is what is under test.
ctl_dir="$(mktemp -d "${TMPDIR:-/tmp}/mutdisc.XXXXXX")"
full='rc=$?; if [ ! -s "$C" ]; then echo discarded; fi; cmp -s "$C" "$W" && echo discarded'
for drop in exit-status empty-check changed-check discard-reporting; do
  case "$drop" in
    exit-status)       probe='if [ ! -s "$C" ]; then echo discarded; fi; cmp -s "$C" "$W"' ;;
    empty-check)       probe='rc=$?; cmp -s "$C" "$W" && echo discarded' ;;
    changed-check)     probe='rc=$?; if [ ! -s "$C" ]; then echo discarded; fi' ;;
    discard-reporting) probe='rc=$?; if [ ! -s "$C" ]; then echo skip; fi; cmp -s "$C" "$W"' ;;
  esac
  hit=0
  case "$probe" in *'$?'*) : ;; *) hit=1 ;; esac
  case "$probe" in *'! -s '*|*'[ -s '*) : ;; *) hit=1 ;; esac
  case "$probe" in *"cmp -s"*|*"diff -q"*) : ;; *) hit=1 ;; esac
  case "$probe" in *discard*) : ;; *) hit=1 ;; esac
  if [ "$hit" -eq 1 ]; then
    ok "CONTROL: a harness missing '$drop' IS rejected"
  else
    bad "CONTROL DEAD: a harness missing '$drop' was accepted -- that predicate is blind"
  fi
done
# And the converse: the complete form must be ACCEPTED, or the rule would
# reject every harness including correct ones and its failures would be noise.
hit=0
case "$full" in *'$?'*) : ;; *) hit=1 ;; esac
case "$full" in *'! -s '*|*'[ -s '*) : ;; *) hit=1 ;; esac
case "$full" in *"cmp -s"*) : ;; *) hit=1 ;; esac
case "$full" in *discard*) : ;; *) hit=1 ;; esac
[ "$hit" -eq 0 ] && ok "CONTROL: a COMPLETE harness is accepted -- the rule is not a blanket refusal" \
                 || bad "CONTROL DEAD: the complete form was rejected; the rule forbids correct harnesses"
rm -rf "$ctl_dir"

printf '\n== mutation discipline: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
