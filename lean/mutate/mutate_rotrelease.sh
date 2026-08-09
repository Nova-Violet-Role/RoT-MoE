#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# MUTATION SUITE -- Proofs/RotRelease.lean (a session id that reaches a filename)
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
# WHAT THIS SUITE IS AIMED AT. The module makes two kinds of claim and the
# mutants are split to match. S01-S06 attack the SCRUBBER, whose whole purpose
# is that a payload value landing in a filename cannot escape its directory;
# each one re-admits a character the proofs say is gone, or removes the
# fallback, or disarms the function entirely. S07-S11 attack PROVENANCE and
# ENABLEMENT -- the fields that make live traffic countable and keep the router
# out of a repository whose owner said no.
#
# The one to watch is S07. It makes a declared harness record classify as live
# traffic, which is precisely the contamination that made 738 of 955 records in
# the real log unattributable. If test_is_never_hook does not die on S07, that
# theorem is decoration.
# =============================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

F="Proofs/RotRelease.lean"
BAK="$F.mutbak"
OLEAN=${LEAN_ROOT:-.}/.lake/build/lib/lean/Proofs/RotRelease.olean
LOG="$(mktemp -d "${TMPDIR:-/tmp}/mutrelease.XXXXXX")"

[ -f "$F" ] || {
  echo "FATAL: $F not found. Refusing to run: every mutant would fail to build"
  echo "and be scored KILLED without a line having been mutated."
  exit 2
}

# --- NO-DOWNLOAD GUARD ------------------------------------------------------
# `lake build` RESOLVES the package first, and against the vendored `lean/` tree
# that resolution starts fetching mathlib INTO the repository. A workspace that
# was never built cannot satisfy this suite, so it SKIPS rather than builds.
# Exit 3 is a skip everywhere in this repo, and a skip is never a pass.
_WSDIR="${LEAN_ROOT:-.}"
if [ ! -d "$_WSDIR/.lake/packages" ] || [ ! -f "$OLEAN" ]; then
  echo "SKIP: $_WSDIR is not a BUILT Lean workspace (.lake/packages or $OLEAN absent)."
  echo "      Refusing to invoke lake: resolving mathlib would DOWNLOAD ~7.2 GB."
  echo "      Set LEAN_ROOT to an already-built workspace to run this suite."
  echo "      This is a SKIP (exit 3), never a pass."
  exit 3
fi

if ! ( cd "${LEAN_ROOT:-.}" && lake build Proofs.RotRelease ) >/tmp/mut_pre_rotrelease.log 2>&1; then
  echo "FATAL: the UNMUTATED baseline does not build (Proofs.RotRelease)."
  echo "A kill measured against a red baseline is unattributable. Fix the tree first."
  tail -5 /tmp/mut_pre_rotrelease.log
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
trap 'cp "$BAK" "$F" 2>/dev/null; rm -f "$BAK"' EXIT

killed=0; survived=0; discarded=0

# --- OPTIONAL FILTER, AND WHY A PARTIAL RUN MUST LOOK PARTIAL ----------------
# The suite is 9 mutants and each one rebuilds the module, so a full pass
# outgrew the wall-clock ceiling of the agent that runs it -- and MEASURED
# 2026-08-07, being killed at that ceiling left a MUTATED RotGuard.lean on
# disk beside its .mutbak. Chunking is the fix; pretending a chunk is the suite
# would be much worse than the timeout.
#
#   MUT_ONLY="A05 A06"   run only those, everything else SKIPPED
#
# A filtered run prints a PARTIAL banner and exits 3, never 0. Nothing that
# consumes this output -- the CHANGELOG count, repo-complete's cross-check, CI
# -- can mistake four killed mutants for forty-eight.
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
  ( cd ${LEAN_ROOT:-.} && lake build Proofs.RotRelease ) > "$LOG/$id.log" 2>&1
  local ec=$?

  # --- IS THIS KILL ATTRIBUTABLE? -------------------------------------------
  # A non-zero exit proves the theorems died only if a build actually happened.
  # A failed redirection, a missing toolchain or a killed process each give a
  # non-zero status with NO build log, and each would otherwise be filed as a
  # kill. MEASURED in CI run 31180174433: mutate_rotgauge.sh wrote its logs to a
  # hard-coded /d/tmp/mut, mkdir was refused on the Linux runner, bash declined
  # to run each build because the redirect could not be opened, and all twelve
  # mutants were scored KILLED without lake running once. The job was green.
  #
  # No log, or an empty one, means nothing was learned. DISCARDED -- which
  # cannot exit 0 -- rather than a finding.
  if [ ! -s "$LOG/$id.log" ]; then
    echo "$id  DISCARDED  build produced NO log (exit=$ec) -- lake did not run,"
    echo "                so this is a harness fault, not a dead theorem."
    discarded=$((discarded+1)); cp "$BAK" "$F"; return
  fi

  if [ "$ec" -eq 0 ]; then
    echo "$id  SURVIVED   (build still exit 0)  expected to kill: $expect"
    survived=$((survived+1))
  else
    # The reported error lines are a LOWER BOUND on what died, not an inventory.
    # A mutant build produces no olean, so every theorem in the module is
    # unusable downstream regardless of which line the elaborator complained at.
    local dead
    dead=$(grep -oE "^error: Proofs/RotRelease\.lean:[0-9]+" "$LOG/$id.log" \
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

echo "=== RotRelease mutation suite ==="

# WHAT THIS SUITE IS AIMED AT.
#
# The module exists because the repository declared 0.9.2 while the deployed
# build was 1.0.1, so every proved fix sat in a version that could not reach
# anyone. The theorems are about ORDER. The mutants therefore attack the
# ORDERING FUNCTION and the PUBLISHING PREDICATE -- never a theorem's statement,
# which would only prove that editing a theorem breaks it.
#
#   R01  the major comparison is reversed        (the order runs backwards)
#   R02  the minor comparison is reversed        (same, one digit down)
#   R03  patch comparison admits equality        (a reinstall counts as newer)
#   R04  supersedes compares the wrong direction (a downgrade reads as an upgrade)
#   R05  supersedes accepts anything not older   (equal versions "upgrade")
#   R06  the lean tier shares core's patch digit (variants stop being ordered)
#   R07  canPublish accepts if ANY install is older (one stale channel ignored)
#   R08  the measured deployed version is altered (are the #guards load-bearing?)
#
# R05 is the one to watch. It is the plausible implementation -- "publish unless
# the candidate is older" -- and it silently permits republishing the same
# number, which is exactly the CLI behaviour RotUpgrade proves changes nothing.
# If reinstall_is_not_an_upgrade does not die on R05, that theorem is decoration.

run_mut R01 \
  "  a.major < b.major ||" \
  "  b.major < a.major ||" \
  "lt_iff, lt_trans, lower_major_never_supersedes -- the order reversed"

run_mut R02 \
  "(a.minor < b.minor || (a.minor == b.minor" \
  "(b.minor < a.minor || (a.minor == b.minor" \
  "lt_sameMajor, a_higher_minor_always_wins -- the minor order reversed"

run_mut R03 \
  "&& a.patch < b.patch" \
  "&& a.patch <= b.patch" \
  "lt_irrefl, reinstall_is_not_an_upgrade -- a version now supersedes itself"

run_mut R04 \
  "def supersedes (candidate deployed : SemVer) : Bool := lt deployed candidate" \
  "def supersedes (candidate deployed : SemVer) : Bool := lt candidate deployed" \
  "every supersedes theorem and #guard -- a downgrade would read as an upgrade"

run_mut R05 \
  "def supersedes (candidate deployed : SemVer) : Bool := lt deployed candidate" \
  "def supersedes (candidate deployed : SemVer) : Bool := !(lt candidate deployed)" \
  "reinstall_is_not_an_upgrade, cannot_publish_over_itself -- equality accepted"

run_mut R06 \
  "  | .lean => 1" \
  "  | .lean => 0" \
  "variants_are_ordered -- core and lean would share a patch digit"

run_mut R07 \
  "  deployed.all (fun d => supersedes candidate d)" \
  "  deployed.any (fun d => supersedes candidate d)" \
  "one_stale_channel_blocks_publication -- a single old install would suffice"

run_mut R08 \
  "def deployedProduction : SemVer := ⟨1, 0, 1⟩" \
  "def deployedProduction : SemVer := ⟨0, 0, 1⟩" \
  "the measured #guards -- if these survive, the recorded facts are inert"
echo
echo "=== RotRelease: $killed killed, $survived survived, $discarded discarded, $skipped skipped ==="

if [ "$filtered" -eq 1 ]; then
  echo "PARTIAL RUN (MUT_ONLY='${MUT_ONLY}') -- $skipped mutant(s) never ran."
  echo "A filtered run is never a pass. Exit 3."
  exit 3
fi

if [ "$discarded" -gt 0 ]; then
  echo "FAIL: $discarded mutant(s) DISCARDED -- the harness could not apply them."
  echo "That is a fault in this suite, not a claim about any theorem."
  exit 1
fi

if [ "$survived" -gt 0 ]; then
  echo "FAIL: $survived mutant(s) SURVIVED -- those theorems are decorative."
  exit 1
fi

echo "All $killed mutants killed. Every belief above is refuted by a theorem or a #guard."
exit 0
