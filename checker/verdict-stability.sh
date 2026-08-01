#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE WEEKLY VERDICT MUST BE ABLE TO SAY NOTHING.
#
# `verify.yml` runs on a schedule and commits STATUS.md "only when the verdict
# changed". That rule is the difference between a status file and a green-square
# generator, and until now NOTHING TESTED IT -- it lived as a comment beside a
# step that violated it. Measured 2026-08-01: the file being compared contained
# `date -u` and ${GITHUB_SHA}, so the "no change, no commit" branch was
# unreachable and the bot would have committed every week forever.
#
# This checker holds the fixed design to three properties, each with a control:
#
#   1. DETERMINISM   -- two runs of checker/status-verdict.sh on an unchanged
#                       tree are byte-identical. A generator with a clock in it
#                       makes the commit rule undecidable.
#   2. SENSITIVITY   -- a real change to the tree MUST move the verdict. A
#                       generator that never changes is the opposite failure and
#                       would freeze the published numbers at whatever was true
#                       the day it was written.
#   3. THE WORKFLOW COMPARES THE VERDICT, NOT THE FILE -- structurally: it must
#                       call the script, delimit the block, diff the block, keep
#                       the clock OUTSIDE it, and never pass --allow-empty.
#
# Property 3 is checked on a COPY that is deliberately broken, so the assertion
# is exercised rather than merely satisfied by a workflow that already passes.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PASS=0; FAIL=0
ok   () { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad  () { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }
head_() { printf '\n== %s\n' "$*"; }

WF=".github/workflows/verify.yml"
GEN="checker/status-verdict.sh"

for f in "$WF" "$GEN"; do
  [ -f "$f" ] || { echo "FATAL: missing $f"; exit 2; }
done

# ---------------------------------------------------------------------------
head_ "1. DETERMINISM -- the same tree must produce the same verdict"
# ---------------------------------------------------------------------------
A=$(mktemp); B=$(mktemp)
bash "$GEN" > "$A"; rcA=$?
bash "$GEN" > "$B"; rcB=$?
if [ "$rcA" -ne 0 ] || [ "$rcB" -ne 0 ]; then
  bad "the generator exited non-zero (rc=$rcA/$rcB) -- no verdict can be published"
elif [ ! -s "$A" ]; then
  bad "the generator produced an EMPTY verdict; an empty block would compare equal to a missing STATUS.md forever"
elif cmp -s "$A" "$B"; then
  ok "two runs byte-identical ($(wc -l < "$A" | tr -d ' ') lines)"
else
  bad "two runs of $GEN DIFFER -- the commit rule is undecidable"
  diff -u "$A" "$B" | sed 's/^/        /' | head -20
fi

# No clock, no commit id, no path, no hostname may appear in the verdict.
if grep -nEi '[0-9]{4}-[0-9]{2}-[0-9]{2}|UTC|GITHUB_SHA|[0-9a-f]{40}' "$A" >/dev/null; then
  bad "the verdict contains something that changes with time or with the commit:"
  grep -nEi '[0-9]{4}-[0-9]{2}-[0-9]{2}|UTC|GITHUB_SHA|[0-9a-f]{40}' "$A" | sed 's/^/        /'
else
  ok "the verdict carries no clock and no commit id"
fi

# ---------------------------------------------------------------------------
head_ "2. SENSITIVITY -- a real change MUST move the verdict"
# ---------------------------------------------------------------------------
# On a scratch copy. The real tree is never mutated by this checker: a harness
# that edits the repository to test itself is one interruption away from leaving
# the mutation behind, which is the R25 lesson.
mk_scratch () {
  local T; T=$(mktemp -d)
  mkdir -p "$T/lean/Proofs" "$T/lean/mutate" "$T/checker"
  cp lean/Proofs/*.lean            "$T/lean/Proofs/"   2>/dev/null
  cp lean/mutate/mutate_*.sh       "$T/lean/mutate/"   2>/dev/null
  cp checker/count-theorems.sh     "$T/checker/"
  cp checker/status-verdict.sh     "$T/checker/"
  cp lean/lean-toolchain           "$T/lean/"          2>/dev/null
  echo "$T"
}

probe () {  # probe <label> <mutator-fn> ; the verdict MUST differ afterwards
  local label="$1" fn="$2" T base after
  T=$(mk_scratch)
  base=$( cd "$T" && bash checker/status-verdict.sh )
  "$fn" "$T"
  after=$( cd "$T" && bash checker/status-verdict.sh )
  if [ "$base" = "$after" ]; then
    bad "$label -- the verdict did NOT move; it is blind to this change"
  else
    ok "$label -- verdict moved"
  fi
  rm -rf "$T"
}

m_theorem () { printf '\ntheorem planted_probe_thm : True := trivial\n' >> "$1/lean/Proofs/RotPath.lean"; }
m_module  () { printf 'theorem m : True := trivial\n' > "$1/lean/Proofs/ZPlanted.lean"; }
m_suite   () { printf '#!/usr/bin/env bash\n' > "$1/lean/mutate/mutate_zplanted.sh"; }
m_tool    () { printf 'leanprover/lean4:v9.99.9\n' > "$1/lean/lean-toolchain"; }
m_sorry   () { printf '\ntheorem planted_hole : True := by sorry\n' >> "$1/lean/Proofs/RotPath.lean"; }

probe "a new theorem"                m_theorem
probe "a new module"                 m_module
probe "a new mutation suite"         m_suite
probe "a toolchain bump"             m_tool
probe "a planted \`sorry\`"          m_sorry

# The counter must NOT be fooled the other way: prose and identifiers that
# merely contain the word are not holes. This is the exact false positive the
# first version of the generator produced -- it reported one file containing
# `sorry` when the three hits were two doc comments and the theorem name
# `sorry_always_speaks`.
T=$(mk_scratch)
base=$( cd "$T" && bash checker/status-verdict.sh )
{ printf '%s\n' ''
  printf '%s\n' '/-- a doc comment mentioning sorry and native_decide -/'
  printf '%s\n' 'theorem sorry_shaped_name_native_decide_too : True := trivial'
  printf '%s\n' '-- a line comment: sorry'
} >> "$T/lean/Proofs/RotPath.lean"
after=$( cd "$T" && bash checker/status-verdict.sh )
b_s=$(printf '%s\n' "$base"  | awk -F'|' '/containing `sorry`/{gsub(/ /,"",$3);print $3}')
a_s=$(printf '%s\n' "$after" | awk -F'|' '/containing `sorry`/{gsub(/ /,"",$3);print $3}')
b_n=$(printf '%s\n' "$base"  | awk -F'|' '/native_decide/{gsub(/ /,"",$3);print $3}')
a_n=$(printf '%s\n' "$after" | awk -F'|' '/native_decide/{gsub(/ /,"",$3);print $3}')
if [ "$b_s" = "$a_s" ] && [ "$b_n" = "$a_n" ]; then
  ok "prose and identifiers containing the words are NOT counted as holes (sorry $b_s->$a_s, native_decide $b_n->$a_n)"
else
  bad "a doc comment or an identifier was counted as a hole (sorry $b_s->$a_s, native_decide $b_n->$a_n)"
fi
rm -rf "$T"

# ---------------------------------------------------------------------------
head_ "3. THE WORKFLOW must compare the VERDICT, not the whole file"
# ---------------------------------------------------------------------------
wf_verdict () {   # wf_verdict <file> -> 0 if it obeys the rule, 1 with reasons
  local f="$1" bad_=0 why=()
  grep -q 'checker/status-verdict.sh'        "$f" || { why+=("does not call checker/status-verdict.sh"); bad_=1; }
  grep -q 'VERDICT-BEGIN'                    "$f" || { why+=("no VERDICT-BEGIN marker"); bad_=1; }
  grep -q 'VERDICT-END'                      "$f" || { why+=("no VERDICT-END marker"); bad_=1; }
  # NOT merely "the file mentions a diff of the two temp files" -- the DECISION
  # must be that diff. The first version asserted the weaker form and its own
  # control walked through it: replacing the `if diff -q old new` conditional
  # with `git diff --staged --quiet` still left the *reporting* line
  # `diff -u old new || true` in the changed branch, which satisfied the grep.
  # An assertion that a string appears somewhere is not an assertion about
  # control flow.
  grep -qE '^[^#]*if diff .*verdict\.old .*verdict\.new' "$f" \
    || { why+=("the decision is not the diff of the extracted block against the new one"); bad_=1; }
  # ONLY a real `git commit` counts. The first version of this line grepped the
  # bare flag and flagged the workflow for the sentence explaining that the flag
  # is deliberately absent -- a checker that cannot tell an invocation from a
  # comment about an invocation punishes the documentation it asked for.
  grep -qE '^[^#]*git commit[^#]*--allow-empty' "$f" && { why+=("passes --allow-empty to git commit, which commits a week that changed nothing"); bad_=1; }
  # The decisive one: the clock and the SHA must NOT be produced by the step
  # that generates the compared block. Both may appear only in the write step,
  # which runs solely when the verdict already changed. Shell comments are
  # stripped for the same reason as above -- the step EXPLAINS the old defect,
  # and naming `date -u` in that explanation is not emitting it.
  local step
  step=$(awk '/Decide whether the VERDICT changed/{f=1} f && /^      - name:/ && !/Decide whether/{f=0} f' "$f" \
         | grep -vE '^[[:space:]]*#')
  if grep -qE "date -u|GITHUB_SHA" <<< "$step"; then
    why+=("the compare step itself emits a timestamp or a commit id -- the comparison can never be equal"); bad_=1
  fi
  # And the guarded steps must actually be guarded.
  grep -q "steps.decide.outputs.changed == 'yes'" "$f" || { why+=("the write/commit steps are not gated on the decision"); bad_=1; }
  if [ "$bad_" -ne 0 ]; then printf '%s\n' "${why[@]}"; return 1; fi
  return 0
}

if out=$(wf_verdict "$WF"); then
  ok "$WF compares the verdict block, keeps the clock outside it, and gates the commit"
else
  bad "$WF violates the verdict rule:"; printf '%s\n' "$out" | sed 's/^/        /'
fi

# --- CONTROLS: the assertion must REJECT each way of getting this wrong ------
ctl () {  # ctl <label> <sed-program>
  local label="$1" prog="$2" C
  C=$(mktemp)
  sed "$prog" "$WF" > "$C"
  if cmp -s "$C" "$WF"; then
    bad "CONTROL '$label' did not apply -- the assertion was NOT exercised (discarded, not survived)"
  elif wf_verdict "$C" >/dev/null; then
    bad "CONTROL '$label' was ACCEPTED -- the check cannot fail, so its pass means nothing"
  else
    ok "CONTROL '$label' rejected"
  fi
  rm -f "$C"
}
ctl "the old bug: a clock inside the compared step" \
    's|^          if \[ -f STATUS.md \]; then|          echo "$(date -u)" >> /tmp/verdict.new\n          if [ -f STATUS.md ]; then|'
ctl "--allow-empty restored"           's|git commit -m "ci: re-verified|git commit --allow-empty -m "ci: re-verified|'
ctl "the markers removed"              's|VERDICT-BEGIN|VERDICT-OPENED|g'
ctl "compares the whole file again"    's|diff -q /tmp/verdict.old /tmp/verdict.new|git diff --staged --quiet|'
ctl "the write step no longer gated"   "s|if: steps.decide.outputs.changed == 'yes'|if: always()|g"

printf '\n== verdict stability: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
