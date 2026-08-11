#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# push-guard.sh -- refuse to transmit while the completion promise is unfulfilled.
#
# WHY THIS EXISTS. On 2026-08-11 a branch was pushed to the remote while the
# promise was unfulfilled, on the reasoning that "pushing a branch is
# evidence-gathering, not publishing". It is not: the branch was visible on the
# remote, CI ran against it, and its green was then cited as evidence about main.
# Fifty-eight gates existed at the time and not one of them was about the push
# ACTION -- every gate judged the TREE.
#
# lean/Proofs/RotPushGuard.lean is the specification. The theorem that matters
# here is `the_target_cannot_change_the_verdict`: for every state and every pair
# of targets the answer is identical, so "it is only a side branch" and "it is
# only a tag" cannot change the verdict. This script is the executable half.
#
# EXIT CODES
#   0  the promise is fulfilled -- transmission permitted
#   1  at least one obligation is outstanding -- REFUSE
#   2  the guard could not determine the state (refuse, loudly; never assume yes)
#
# THE FAIL-CLOSED RULE. Exit 2 is not a pass. A guard that cannot read its own
# inputs must refuse, because "I could not tell" and "yes" are the two answers a
# broken guard is most likely to confuse -- and confusing them in the permissive
# direction is how the original defect happened.
# =============================================================================
#
# TWO MODES, and the distinction is the whole reason this script is not simply
# registered as a gate:
#
#   (default)     answer "may anything be transmitted right now". Exit 1 -- REFUSE
#                 -- is the CORRECT answer on every commit until the promise is
#                 fulfilled. This is what .githooks/pre-push calls.
#
#   --instrument  answer "is this guard sound", ignoring which way it points.
#                 Exit 0 when the verdict is determinate (0 or 1) AND every control
#                 reported; exit 1 only when the guard cannot stand behind its own
#                 answer. This is what gate-all.sh and CI call.
#
# Registering the default mode as a gate would paint the whole suite red until the
# research is finished, and the repair everybody reaches for at that point is
# deleting the gate -- destroying the coverage instead of fixing the spec. A gate
# that cannot pass on correct work is a defect. So the gate asks the question that
# CAN pass today, and the hook asks the question that must not.
set -uo pipefail

MODE="verdict"
case "${1:-}" in
  --instrument) MODE="instrument" ;;
  "") : ;;
  *) : ;;   # git hands the hook a remote name and URL; both are ignored by design
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || { echo "push-guard: cannot reach repo root"; exit 2; }

_pass=0; _fail=0
# Counts how many CONTROLS actually reported. Six are declared below; the
# instrument mode refuses to certify the guard if fewer than six speak, because a
# control that silently stopped running still leaves a healthy-looking verdict.
CONTROLS_SEEN=0
ok ()  { printf '  ok    %s\n' "$1"; _pass=$((_pass+1)); }
bad () { printf '  FAIL  %s\n' "$1"; _fail=$((_fail+1)); }
inf () {
  printf '  ----  %s\n' "$1"
  case "$1" in control:*) CONTROLS_SEEN=$((CONTROLS_SEEN+1)) ;; esac
}

# -----------------------------------------------------------------------------
# THE OBLIGATION LEDGER.
#
# Each row is `key|description|probe`. The probe is a shell command; exit 0 means
# MET. The keys mirror the `Obligation` constructors in RotPushGuard.lean, and
# checker/push-guard-parity.sh would be the place to bind the two lists if this
# ledger ever grows past what a reader can hold in their head.
#
# NOTE ON WHY THESE ARE PROBES AND NOT A FILE OF BOOLEANS: a hand-maintained
# "promise.json" would be edited by the same process that wants to push. The
# probe has to read something the pusher does not control by writing one line.
# -----------------------------------------------------------------------------
LEDGER=$(cat <<'ROWS'
corpus40|40|the 40-task corpus exists and verifies|test "$(wc -l < bench/corpus-40.jsonl 2>/dev/null || echo 0)" -ge 40 && bash checker/corpus-verify.sh >/dev/null 2>&1
pilot12Pairs|12|the pilot has at least 12 pairs|test "$(wc -l < bench/pilot-pairs.jsonl 2>/dev/null || echo 0)" -ge 12
sessions160|160|160 sessions collected|test "$(wc -l < bench/sessions-160.done 2>/dev/null || echo 0)" -ge 160
preferenceMeasured|1|a preference panel has run|test -s bench/panel-results.jsonl
p22Established|1|P2.2 established|test -s bench/P22-ESTABLISHED.md
verifyRunOnMain|1|a verify run exists on main|test -s .rot-moe/verify-on-main.stamp
ROWS
)

DECLARED=$(printf '%s\n' "$LEDGER" | grep -c '^[a-zA-Z]')
if [ "$DECLARED" -eq 0 ]; then
  echo "push-guard: the obligation ledger is EMPTY -- an empty ledger would permit"
  echo "every push, which is the failure this guard exists to prevent."
  exit 2
fi
inf "obligation ledger: $DECLARED row(s)"

# -----------------------------------------------------------------------------
# EVALUATE
# -----------------------------------------------------------------------------
OUTSTANDING=0
FIRST_OPEN=""
while IFS='|' read -r key need desc probe; do
  [ -z "${key:-}" ] && continue
  if eval "$probe" >/dev/null 2>&1; then
    ok "$key -- $desc"
  else
    bad "$key -- $desc  [OUTSTANDING]"
    OUTSTANDING=$((OUTSTANDING+1))
    [ -z "$FIRST_OPEN" ] && FIRST_OPEN="$key"
  fi
done <<< "$LEDGER"

# -----------------------------------------------------------------------------
# INNER MODE. Control (c) below re-runs this script against three destinations and
# compares the verdicts. The inner runs must not re-run the controls -- that would
# recurse without bound -- so they stop here and report the ledger verdict alone.
# This is the ONLY thing PUSHGUARD_INNER changes; the ledger evaluation above is
# identical in both modes, which is what makes the comparison meaningful.
# -----------------------------------------------------------------------------
if [ "${PUSHGUARD_INNER:-0}" = "1" ]; then
  [ "$OUTSTANDING" -eq 0 ] && exit 0
  exit 1
fi

# -----------------------------------------------------------------------------
# NEGATIVE CONTROLS. An alarm nobody has tripped on purpose is an untested alarm.
# All three must hold or the guard reports 2 -- a guard whose controls fail is
# not a guard that happens to be strict, it is a guard of unknown behaviour.
# -----------------------------------------------------------------------------
CTRL_FAIL=0

# (a) An obligation whose probe cannot possibly succeed must be counted open.
if eval "test -s .rot-moe/__no_such_file_ever__" >/dev/null 2>&1; then
  echo "  CONTROL FAILED: an impossible probe reported MET"; CTRL_FAIL=1
else
  inf "control: an impossible probe is counted OUTSTANDING"
fi

# (b) An obligation whose probe trivially succeeds must be counted met -- or the
#     guard refuses everything forever and will be deleted by the first person
#     who finishes the work.
if eval "true" >/dev/null 2>&1; then
  inf "control: a satisfiable probe is counted MET"
else
  echo "  CONTROL FAILED: a trivially true probe reported OUTSTANDING"; CTRL_FAIL=1
fi

# (c) THE TARGET-INDEPENDENCE CONTROL, which is the specific rationalisation that
#     failed. RotPushGuard.the_target_cannot_change_the_verdict says the answer
#     must not depend on where the push is going, so the guard must never consult
#     the destination. `git push` hands a pre-push hook the remote name and URL on
#     argv and the refs on stdin; a guard that reads none of them cannot branch on
#     any of them.
#
#     THIS CONTROL IS BEHAVIOURAL, NOT TEXTUAL, and the two false starts are worth
#     recording because both produced a CONTROL FAILED on a clean script:
#       1. a literal grep pattern matched ITS OWN grep line -- the needle contained
#          the thing the needle looks for;
#       2. assembling the needle at runtime fixed that and then flagged six lines,
#          three of which were `ok()`, `bad()` and `inf()` using their own `$1`.
#          A function's parameter is not the script's argv, and no text pattern
#          distinguishes them reliably.
#     So the guard is run against three different destinations and the verdicts are
#     COMPARED. That is the theorem itself, executed: for every pair of targets the
#     answer is identical.
_v=()
for _tgt in "origin:refs/heads/main" "origin:refs/heads/side-branch" "origin:refs/tags/v1.0.1"; do
  PUSHGUARD_INNER=1 bash "$0" "${_tgt%%:*}" "https://example.invalid/repo.git" \
      >/dev/null 2>&1 <<< "${_tgt#*:} deadbeef ${_tgt#*:} 0000000"
  _v+=("$?")
done
if [ "${_v[0]}" = "${_v[1]}" ] && [ "${_v[1]}" = "${_v[2]}" ]; then
  inf "control: main, side branch and tag all get verdict ${_v[0]} -- the target does not change the answer"
else
  echo "  CONTROL FAILED: verdicts differ by destination (main=${_v[0]} side=${_v[1]} tag=${_v[2]})."
  echo "  RotPushGuard.the_target_cannot_change_the_verdict forbids exactly this."
  CTRL_FAIL=1
fi

# (c2) The comparison must be able to FAIL, or agreement means nothing. A scratch
#      script that DOES branch on its destination must be caught by the same
#      three-way comparison.
_probe=$(mktemp)
printf '#!/usr/bin/env bash\ncase "$1" in main) exit 1 ;; *) exit 0 ;; esac\n' > "$_probe"
_p=(); for _t in main side tag; do bash "$_probe" "$_t" >/dev/null 2>&1; _p+=("$?"); done
rm -f "$_probe"
if [ "${_p[0]}" = "${_p[1]}" ] && [ "${_p[1]}" = "${_p[2]}" ]; then
  echo "  CONTROL FAILED: the three-way comparison did NOT notice a script that"
  echo "  branches on its destination, so control (c) proves nothing."
  CTRL_FAIL=1
else
  inf "control: the comparison DOES catch a target-dependent script (${_p[0]}/${_p[1]}/${_p[2]})"
fi

# (d) EVERY PROBE MUST BE SATISFIABLE IN PRINCIPLE. This is the control that found
#     a real defect in this very file: the pilot row originally ran
#     `bash checker/pilot-size.sh`, and that script does not exist. The probe could
#     therefore NEVER succeed, so the guard would have gone on refusing forever
#     even after the pilot was genuinely finished -- and the obvious repair at that
#     point is to delete the row, destroying the coverage. A gate that cannot open
#     on correct work is a defect, not a safeguard.
#
#     The check: any `checker/*.sh` or `bench/*.sh` a probe invokes must exist.
_unsat=0
while IFS='|' read -r key need desc probe; do
  [ -z "${key:-}" ] && continue
  for _tok in $probe; do
    case "$_tok" in
      checker/*.sh|bench/*.sh)
        if [ ! -f "$_tok" ]; then
          echo "  CONTROL FAILED: obligation '$key' invokes $_tok, which does not exist."
          echo "  That probe can never succeed, so this guard could never open."
          _unsat=$((_unsat+1))
        fi ;;
    esac
  done
done <<< "$LEDGER"
if [ "$_unsat" -eq 0 ]; then
  inf "control: every probe invokes only scripts that exist -- the guard can open"
else
  CTRL_FAIL=1
fi

# (d2) And that control must itself be able to fire, or it is decoration.
_fakeledger='x|y|bash checker/__absent_probe__.sh'
_seen=0
for _tok in $(printf '%s' "$_fakeledger" | cut -d'|' -f3); do
  case "$_tok" in checker/*.sh) [ -f "$_tok" ] || _seen=1 ;; esac
done
if [ "$_seen" -eq 1 ]; then
  inf "control: the satisfiability check DOES fire on a probe naming a missing script"
else
  echo "  CONTROL FAILED: the satisfiability check missed a probe that names a"
  echo "  script which is not there, so control (d) proves nothing."
  CTRL_FAIL=1
fi

# (e) PROBE STRENGTH. A row whose description names a number must have a probe
# that COUNTS to at least that number. Four rows shipped as `test -s` -- a mere
# non-emptiness test -- while their descriptions promised 40 tasks and 160
# sessions, so `echo x > bench/corpus-40.jsonl` would have reported the 40-task
# obligation MET. That is the permissive failure direction: the gate opens, and
# nobody sees a red. Proved unsound in general (not just for 40) by
# lean/Proofs/RotProbeStrength.lean:nonEmpty_cannot_witness_a_counted_obligation.
# The converse is proved there too -- a probe demanding MORE than the obligation
# would refuse work that was genuinely finished -- so this check demands
# `>= the named number`, never `> `.
# The demand is column 2 of the row, DECLARED -- not scraped out of the prose in
# column 3. The first cut of this check parsed the description with a regex and
# immediately mis-read `p22Established | P2.2 established` as demanding two of
# something, flagging a row that is correct. Prose is not a data field. The Lean
# model already had this right: `Obligation.required` is a structure field
# (lean/Proofs/RotProbeStrength.lean), and the shell had drifted from it.
weak_rows() {
  # $1 = ledger text. Emits "name:demand" for every row whose probe cannot
  # possibly witness the count the row itself declares.
  printf '%s\n' "$1" | grep '^[a-zA-Z]' | while IFS='|' read -r _n _need _d _p; do
    case "$_need" in ''|*[!0-9]*) continue ;; esac
    [ "$_need" -ge 2 ] || continue
    _bound=$(printf '%s' "$_p" | grep -oE -- '-ge[[:space:]]+[0-9]+' | grep -oE '[0-9]+' | head -1)
    if [ -z "$_bound" ] || [ "$_bound" -lt "$_need" ]; then
      printf '%s:%s\n' "$_n" "$_need"
    fi
  done
}
_weak=$(weak_rows "$LEDGER")
if [ -z "$_weak" ]; then
  inf "control: every row naming a count has a probe that counts to it"
else
  echo "  CONTROL FAILED: these rows name a number their probe never checks:"
  printf '%s\n' "$_weak" | sed 's/^/    /'
  CTRL_FAIL=1
fi

# (e2) That check must fire on a ledger with the exact defect this repo shipped.
_weakledger='corpus40|40|the 40-task corpus exists|test -s bench/corpus-40.jsonl'
if [ -n "$(weak_rows "$_weakledger")" ]; then
  inf "control: the strength check DOES catch a non-emptiness probe on a counted row"
else
  echo "  CONTROL FAILED: a 'test -s' probe standing in for a 40-task obligation"
  echo "  was accepted, so control (e) proves nothing."
  CTRL_FAIL=1
fi

# (e2b) `weak_rows` SKIPS any row whose required column is missing or not a
# number. A skip is not a pass: a row written `foo||desc|test -s x` would sail
# past the strength check unexamined. Every row must therefore declare a numeric
# demand of at least 1, and the count of well-formed rows must equal the count of
# rows -- otherwise the strength check is silently covering fewer rows than the
# ledger has.
# NF >= 4, never == 4: three of the probes contain `|| echo 0`, so awk counts six
# fields on a row the shell's `read -r _n _need _d _p` parses perfectly (the
# fourth variable absorbs the remainder). The first cut demanded exactly four and
# reported 3 of 6 well-formed -- a control that would have refused a ledger which
# is correct, the same wall-shaped defect the Lean file proves about probes that
# demand more than their obligation.
_wellformed=$(printf '%s\n' "$LEDGER" | grep '^[a-zA-Z]' | awk -F'|' \
  '$2 ~ /^[0-9]+$/ && $2 >= 1 && NF >= 4 { n++ } END { print n+0 }')
if [ "$_wellformed" -eq "$DECLARED" ]; then
  inf "control: all $DECLARED row(s) declare a numeric demand -- none skipped unexamined"
else
  echo "  CONTROL FAILED: only $_wellformed of $DECLARED row(s) declare a numeric"
  echo "  demand in four fields. The rest are SKIPPED by the strength check, which"
  echo "  reports no finding for them -- silence that reads as approval."
  CTRL_FAIL=1
fi

# (e2c) ... and that well-formedness count must itself be able to fall short, on
# both malformed shapes: an empty demand column, and a row missing it entirely.
_malformed=$(printf '%s\n%s\n' 'foo||no demand declared|test -s x' \
                               'bar|three fields only|test -s x' \
  | grep '^[a-zA-Z]' | awk -F'|' \
  '$2 ~ /^[0-9]+$/ && $2 >= 1 && NF >= 4 { n++ } END { print n+0 }')
if [ "$_malformed" -eq 0 ]; then
  inf "control: the well-formedness count DOES reject rows with no declared demand"
else
  echo "  CONTROL FAILED: $_malformed of 2 malformed rows were counted well-formed."
  CTRL_FAIL=1
fi

# (e3) ... and must NOT fire on a correctly counted row, or it is a wall that
# would go red on a ledger that is actually right.
_strongledger='corpus40|40|the 40-task corpus exists|test "$(wc -l < bench/corpus-40.jsonl)" -ge 40'
if [ -z "$(weak_rows "$_strongledger")" ]; then
  inf "control: the strength check stays silent on a correctly counted row"
else
  echo "  CONTROL FAILED: the strength check flagged a row that counts to its own"
  echo "  demand -- it would refuse a ledger that is correct."
  CTRL_FAIL=1
fi

if [ "$CTRL_FAIL" -ne 0 ]; then
  echo
  echo "push-guard: CONTROLS FAILED -- the guard's own behaviour is unverified."
  echo "Refusing rather than reporting a verdict it cannot stand behind."
  exit 2
fi

# -----------------------------------------------------------------------------
# INSTRUMENT MODE. Asks only whether this guard can be trusted, not which way it
# points. Reaching this line means every control passed and the ledger produced a
# determinate count, which is exactly the soundness claim -- so the remaining job
# is to confirm the controls all actually REPORTED. A guard whose controls
# silently stopped running would still produce a verdict and look healthy.
# -----------------------------------------------------------------------------
if [ "$MODE" = "instrument" ]; then
  echo
  if [ "$CONTROLS_SEEN" -lt 6 ]; then
    echo "push-guard --instrument: only $CONTROLS_SEEN of 6 controls reported."
    echo "The guard is not fully instrumented; its verdict is not trustworthy."
    exit 1
  fi
  echo "push-guard --instrument: SOUND -- $CONTROLS_SEEN/6 controls reported,"
  echo "ledger determinate at $OUTSTANDING of $DECLARED outstanding."
  echo "(This says nothing about whether the promise is fulfilled. It is not:"
  echo " run without --instrument for the verdict, which is exit 1 today.)"
  exit 0
fi

# -----------------------------------------------------------------------------
# VERDICT
# -----------------------------------------------------------------------------
echo
if [ "$OUTSTANDING" -eq 0 ]; then
  echo "push-guard: all $DECLARED obligation(s) MET -- transmission permitted."
  exit 0
fi

cat <<MSG
push-guard: REFUSED -- $OUTSTANDING of $DECLARED obligation(s) outstanding.
First outstanding: $FIRST_OPEN

The promise is not fulfilled, so nothing may be transmitted to the remote. This
applies to a side branch and to a tag exactly as it applies to main -- see
RotPushGuard.the_target_cannot_change_the_verdict. "It is only a branch, it is
evidence-gathering not publishing" is the reasoning that caused the incident this
guard was written after, and it is refuted by that theorem.

If the Socio has sanctioned this push, that is a decision above this script:
    git push --no-verify ...
and say in the same breath which obligations were outstanding when you did.
MSG
exit 1
