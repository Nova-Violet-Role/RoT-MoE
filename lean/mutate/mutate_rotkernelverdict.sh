#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotKernelVerdict.lean (a non-answer is not a rejection)
#
# The contract, identical to the other suites in this directory:
#   1. assert the needle is present EXACTLY once before mutating; if not -> DISCARDED
#   2. assert the mutation LANDED after patching (needle gone, replacement present)
#   3. delete the stale .olean so Lake cannot skip the rebuild
#   4. rebuild, read the exit code DIRECTLY
#   5. restore from the backup, always
#
# DISCARDED != SURVIVED. The first is a defect in this harness, the second is a
# claim about the theorem. Folding them together manufactures reassurance.
#
# WHAT THIS SUITE IS AIMED AT. The module proves that the prover hook tells a
# CHECK THAT NEVER COMPLETED apart from a KERNEL REFUSAL. That distinction was
# added on 2026-08-08, documented at length, and never once fired: it compared
# the whole reason string to "TIMEOUT" while the producer writes "TIMEOUT after
# 90s". Four groups:
#
#   K01-K03  THE PREFIX SET. Remove one leading token. Each should kill exactly
#            the theorem that quantifies over that prefix. A survivor means the
#            universal statement is not reading the list it claims to.
#   K04-K05  THE DEFAULT. FAIL LOUD ON THE UNKNOWN is the whole safety argument:
#            an unrecognised reason must still shout. If flipping the default
#            leaves everything green, `unmatched_reason_shouts` is decorative.
#   K06      THE INFIX SEARCH. Resource failures arrive mid-string
#            ("exit=1 ... std::bad_alloc"), so the search must not be anchored.
#   K07-K08  THE REFUTATION. The old predicate and the prefix lemma. If breaking
#            these changes nothing, the file DESCRIBES the historical defect
#            rather than reproducing it -- the difference between a record and
#            a story.
#
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotKernelVerdict.lean"
MOD=${F##*/}; MOD=${MOD%.lean}
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotKernelVerdict.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutkernelverdict.XXXXXX")"

[ -f "$F" ] || {
  echo "FATAL: $F not found. Refusing to run: every mutant would fail to build"
  echo "and be scored KILLED without a line having been mutated."
  exit 2
}

# --- NO-DOWNLOAD GUARD ------------------------------------------------------
_WSDIR="${LEAN_ROOT:-.}"
if [ ! -d "$_WSDIR/.lake/packages" ] || [ ! -f "$OLEAN" ]; then
  echo "SKIP: $_WSDIR is not a BUILT Lean workspace (.lake/packages or $OLEAN absent)."
  echo "      Refusing to invoke lake: resolving mathlib would DOWNLOAD ~7.2 GB."
  echo "      Set LEAN_ROOT to an already-built workspace to run this suite."
  echo "      This is a SKIP (exit 3), never a pass."
  exit 3
fi

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotKernelVerdict ) >/tmp/mut_pre_rotkernelverdict.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotKernelVerdict)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotkernelverdict.log
  exit 2
fi
echo "preflight: baseline builds GREEN, $F present -- kills are attributable"

# --- SOURCE SANITY: a green baseline is NOT proof the source is intact -----
# AN EMPTY LEAN FILE BUILDS GREEN, so "the baseline compiles" is weaker than it
# looks. The source is checked for CONTENT before it is copied over the backup.
_lines=$(wc -l < "$F" 2>/dev/null || echo 0)
_thms=$(grep -c "^theorem \|^@\[simp\] theorem \|^example " "$F" 2>/dev/null || echo 0)
if [ "${_lines:-0}" -lt 20 ] || [ "${_thms:-0}" -lt 1 ]; then
  echo "FATAL: $F looks DAMAGED ($_lines lines, $_thms theorem/example lines)."
  echo "Refusing to overwrite the backup with it. An empty or truncated source"
  echo "compiles green and would be scored as a suite full of DISCARDED mutants."
  echo "Restore the file (git checkout -- <path>) before running this suite."
  exit 2
fi

cp "$F" "$BAK"
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"; ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotKernelVerdict ) >/dev/null 2>&1' EXIT

killed=0; survived=0; discarded=0
skipped=0
filtered=0
[ -n "${MUT_ONLY:-}" ] && filtered=1

run_mut() {
  local id="$1" needle="$2" repl="$3" expect="$4"

  if [ -n "${MUT_ONLY:-}" ]; then
    case " $MUT_ONLY " in
      *" $id "*) : ;;
      *) skipped=$((skipped+1)); return ;;
    esac
  fi

  cp "$BAK" "$F"

  local n
  n=$(grep -F -c -- "$needle" "$BAK")
  if [ "$n" -ne 1 ]; then
    echo "$id  DISCARDED  needle occurs $n times (expected 1) -- patch not applied"
    discarded=$((discarded+1)); return
  fi

  awk -v needle="$needle" -v repl="$repl" '{
    p = index($0, needle)
    if (p > 0) { $0 = substr($0,1,p-1) repl substr($0, p+length(needle)) }
    print
  }' "$BAK" > "$F"

  local after_needle after_repl
  after_needle=$(grep -F -c -- "$needle" "$F")
  after_repl=$(grep -F -c -- "$repl" "$F")
  if [ "$after_needle" -ne 0 ] || [ "$after_repl" -lt 1 ]; then
    echo "$id  DISCARDED  post-check failed (needle=$after_needle repl=$after_repl)"
    discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi

  rm -f "$OLEAN"
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotKernelVerdict ) > "$LOG/$id.log" 2>&1
  local ec=$?

  if [ ! -s "$LOG/$id.log" ]; then
    echo "$id  DISCARDED  build produced NO log (exit=$ec) -- lake did not run,"
    echo "                so this is a harness fault, not a dead theorem."
    discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi

  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   (build still exit 0)  expected to kill: $expect"
    survived=$((survived+1))
  else
    local dead
    dead=$(grep -oE "^error: Proofs/$MOD.lean:[0-9]+" "$LOG/$id.log" \
      | grep -oE "[0-9]+$" | sort -un | while read -r ln; do
        awk -v L="$ln" '
          /^(theorem|def|private def|instance|structure|inductive|example)/ {
            if (NR <= L) { name=$0 }
          }
          END { if (name != "") print name }
        ' "$F"
      done | sed -E 's/^(private )?(theorem|def|instance|structure|inductive|example) *//; s/[ ({:].*$//' \
      | sort -u | tr '\n' ',')
    if [ ! -f "$OLEAN" ]; then
      echo "$id  KILLED     exit=$ec  MODULE DEAD (no olean: every theorem unusable)"
      echo "        errors at: ${dead%,}  <- LOWER BOUND, not the full set"
      echo "        expected: $expect"
    else
      echo "$id  KILLED     exit=$ec  dead: ${dead%,}"
    fi
    killed=$((killed+1))
  fi
  cp "$BAK" "$F"
}

echo "=== RotKernelVerdict mutation suite ==="

# K01-K03 -- THE PREFIX SET.
run_mut K01 \
  '["TIMEOUT".toList, "NOT_FOUND".toList, "LAUNCH_FAILED".toList]' \
  '["NOT_FOUND".toList, "LAUNCH_FAILED".toList]' \
  'timeout_any_suffix_is_unfinished -- drop TIMEOUT and every timeout becomes a false accusation again'

run_mut K02 \
  '["TIMEOUT".toList, "NOT_FOUND".toList, "LAUNCH_FAILED".toList]' \
  '["TIMEOUT".toList, "NOT_FOUND".toList]' \
  'launch_failed_any_suffix_is_unfinished -- a checker that never started is not a refused proof'

run_mut K03 \
  '["TIMEOUT".toList, "NOT_FOUND".toList, "LAUNCH_FAILED".toList]' \
  '["TIMEOUT".toList, "LAUNCH_FAILED".toList]' \
  'not_found_any_suffix_is_unfinished -- nothing to check is not a failed check'

# K04-K05 -- THE DEFAULT. This is the safety argument itself.
run_mut K04 \
  '  else .rejected' \
  '  else .unfinished' \
  'unmatched_reason_shouts -- demoting the UNKNOWN makes the alarm permanently deaf'

run_mut K05 \
  'if unfinishedPrefixes.any (fun p => p.isPrefixOf reason) then .unfinished' \
  'if unfinishedPrefixes.any (fun p => p.isPrefixOf reason) then .rejected' \
  'all three prefix theorems -- the matched branch must yield unfinished, not rejected'

# K06 -- THE INFIX SEARCH must not be anchored to the front.
run_mut K06 \
  '    | _ :: cs => hasInfix t cs' \
  '    | _ :: _ => false' \
  'bad_alloc_anywhere_is_unfinished -- std::bad_alloc arrives mid-string, never at position 0'

# K07-K08 -- THE REFUTATION and the lemma under it.
run_mut K07 \
  'reason == "TIMEOUT".toList || reason == "NOT_FOUND".toList' \
  'reason.isPrefixOf "TIMEOUT".toList || reason == "NOT_FOUND".toList' \
  'old_logic_fires_only_on_two_exact_strings -- the point is that the OLD test was equality'

run_mut K08 \
  '    p.isPrefixOf (p ++ suf) = true := by' \
  '    p.isPrefixOf (suf ++ p) = true := by' \
  'isPrefixOf_self_append -- the lemma every universal theorem in the file rests on'

echo
echo "  killed=$killed survived=$survived discarded=$discarded skipped=$skipped"

if [ "$discarded" -gt 0 ]; then
  echo "  RotKernelVerdict: FAIL -- $discarded mutant(s) DISCARDED (harness fault, not a result)"
  exit 1
fi
if [ "$survived" -gt 0 ]; then
  echo "  RotKernelVerdict: FAIL -- $survived mutant(s) SURVIVED"
  exit 1
fi
if [ "$filtered" -eq 1 ]; then
  echo "  RotKernelVerdict: PARTIAL RUN ($skipped skipped by MUT_ONLY) -- never a pass"
  exit 3
fi
echo "  RotKernelVerdict: PASS -- all $killed mutants killed"
exit 0
