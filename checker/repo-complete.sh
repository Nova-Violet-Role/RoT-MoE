#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# REPO COMPLETENESS -- required files, and NUMBERS THAT MUST STILL BE TRUE.
#
# Two jobs, and the second is the one that matters:
#
#   1. Required files exist. Cheap, and it stops a shipped packet from silently
#      losing its licence texts or its community files.
#
#   2. EVERY COUNT IN THE PROSE IS RECOUNTED FROM SOURCE. A README saying "63
#      theorems" after a module was added is not a typo -- it is the project
#      lying about the one thing it sells. The count in prose is a CLAIM; the
#      count from `grep` over `lean/Proofs/*.lean` is a MEASUREMENT. When they
#      disagree, the prose is wrong.
#
# This checker was written after the author's own stale-memory error: a "next
# steps" list named three community files as missing that had been committed
# hours earlier. Stating from memory what can be measured is exactly the habit
# every other instrument in this repo exists to break, and prose drifts the same
# way code does.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; [ "${GITHUB_ACTIONS:-}" = "true" ] && printf '::error title=repo-complete::%s\n' "$*"; fail=$((fail+1)); }

echo "== repo completeness =="

# --- 1. required files ------------------------------------------------------
REQUIRED="
README.md
NOTICE.md
LICENSE
LICENSE-EUPL-1.2
LICENSES/AGPL-3.0-or-later.txt
LICENSES/EUPL-1.2.txt
SECURITY.md
CONTRIBUTING.md
CODE_OF_CONDUCT.md
CITATION.cff
.gitignore
.claude-plugin/plugin.json
hooks/hooks.json
hooks/rot-router.sh
hooks/rot-router.ps1
hooks/settings-merge.js
ARM_ROUTER.sh
ARM_ROUTER.ps1
DISARM_ROUTER.sh
DISARM_ROUTER.ps1
lean/lakefile.toml
lean/lean-toolchain
SETUP_LEAN.sh
SETUP_LEAN.ps1
"
for f in $REQUIRED; do
  [ -f "$f" ] && ok "present: $f" || bad "MISSING: $f"
done

# --- 1b. THE FOUR ORGANS ----------------------------------------------------
#
# MEASURED DEFECT, 2026-07-31. This checker reported a COMPLETE repository while
# three of the packet's four organs did not exist: there was no `engine/`, no
# `agents/`, and no reminder hook. The list above named the router and the
# licences, so the tree it certified was a router with paperwork.
#
# The lesson is not "add three filenames". It is that a completeness check must
# be written against the STRUCTURE THE PROJECT CLAIMS TO SHIP, not against the
# files that happened to exist when the check was written. Each organ below is
# named with what it IS, so a future reader can tell whether a replacement
# satisfies it.
echo
echo "-- the four organs of the packet --"
organ () {   # organ <path> <what it is>
  if [ -f "$1" ]; then ok "organ present: $1 -- $2"
  else bad "ORGAN MISSING: $1 -- $2"; fi
}
organ engine/rot-lean.md        "the engine specification the router implements"
organ agents/lean4-prover.md    "the prover head, with its frontmatter and tool list"
organ hooks/rot-router.sh       "the router, POSIX arm"
organ hooks/rot-router.ps1      "the router, Windows arm"
organ hooks/prover-remind.sh    "the proof-debt reminder, POSIX arm"
organ hooks/prover-remind.ps1   "the proof-debt reminder, Windows arm"

# An agent file without frontmatter is a text file: Claude Code will not load
# it, and the organ would be present and inert.
if [ -f agents/lean4-prover.md ]; then
  if head -1 agents/lean4-prover.md | grep -c '^---$' >/dev/null && grep -q '^name: lean4-prover$' agents/lean4-prover.md; then
    ok "agents/lean4-prover.md carries the frontmatter that makes it loadable"
  else
    bad "agents/lean4-prover.md has no usable frontmatter -- present but inert"
  fi
fi

# --- 2. the counts ----------------------------------------------------------
echo
echo "-- counts recounted from source, never trusted from prose --"

# ONE definition of the count, comment-aware and self-tested. A bare grep here
# counted a `theorem` line written inside a doc comment -- prose illustrating
# what a vacuous theorem looks like -- and reported 73 where the truth was 71.
# The instrument that checks every prose claim could itself be inflated by
# writing English.
bash "$REPO/checker/count-theorems.sh" --selftest >/dev/null 2>&1 \
  || { echo "  FAIL  the theorem counter failed its own selftest"; exit 1; }
TH=$(bash "$REPO/checker/count-theorems.sh" lean/Proofs/*.lean)
MODS=$(ls lean/Proofs/*.lean 2>/dev/null | wc -l | tr -d ' ')
SUITES=$(ls lean/mutate/mutate_*.sh 2>/dev/null | wc -l | tr -d ' ')
echo "  measured: $TH theorems, $MODS modules, $SUITES mutation suites"

# --- THE SHARED CORPUS MUST BE PRESENT AND NON-EMPTY -------------------------
# `Lean Theorem/` is the contributed proof base. It is not decoration: the LEAN
# and UNSEALED archives ship it, so a tree that has lost it produces a release
# whose corpus silently shrinks to nothing. Refuse here, before packaging.
#
# COUNTED FROM DISK, never against a frozen number. The corpus is meant to GROW
# by fork-and-PR; an assertion pinned to today's 8 modules would go red on the
# first accepted contribution and the obvious "fix" would be to delete it.
#
# USE `bad`, NEVER A HAND-ROLLED FLAG. The first draft of this block set `RC=1`
# on failure -- a variable this script does not read. The result was a gate that
# printed FAIL and exited 0: it announced the defect and passed anyway. Caught by
# running the negative control and reading the EXIT CODE, not the message.
# `bad` increments `fail`, and `fail` is what the final `exit` consults.
CORP_DIR="Lean Theorem"
if [ ! -d "$CORP_DIR" ]; then
  bad "the shared corpus '$CORP_DIR/' is missing -- the LEAN archive would ship an empty promise"
else
  CORP_MODS=$(find "$CORP_DIR" -name '*.lean' 2>/dev/null | grep -c . || true)
  CORP_SUBJ=$(find "$CORP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -c . || true)
  CORP_KB=$(du -sk "$CORP_DIR" 2>/dev/null | cut -f1)
  if [ "$CORP_MODS" -eq 0 ]; then
    bad "'$CORP_DIR/' exists but holds no .lean file -- an empty corpus is worse than none, it looks shipped"
  elif [ ! -f "$CORP_DIR/README.md" ]; then
    bad "'$CORP_DIR/' has no README.md -- a stranger cannot tell what the folder is or how to contribute"
  else
    # NUL-delimited, one invocation per file, summed. The first draft of this
    # line was `$(find ... | tr '\n' ' ')` unquoted -- which word-split on the
    # space in "Lean Theorem", passed no readable file, and reported 0 theorems
    # while `|| echo 0` swallowed the error that would have said so. Caught by
    # reading the number, not by the exit code: it was green and wrong.
    CORP_TH=0
    while IFS= read -r -d '' _f; do
      _n=$(bash "$REPO/checker/count-theorems.sh" "$_f")
      case "$_n" in (''|*[!0-9]*)
        bad "the theorem counter returned '$_n' for $_f -- refusing to report a corpus total built on a non-number"; _n=0 ;;
      esac
      CORP_TH=$((CORP_TH + _n))
    done < <(find "$CORP_DIR" -name '*.lean' -print0)
    if [ "$CORP_TH" -eq 0 ]; then
      bad "shared corpus counts 0 theorems across $CORP_MODS modules -- the counter is not reading these files"
    else
      ok "shared corpus: $CORP_SUBJ subject(s), $CORP_MODS modules, $CORP_TH theorems, ${CORP_KB} KB -- present, non-empty, documented"
    fi
  fi
fi

# Every "<n> theorems" / "<n> machine-checked" claim must equal TH -- ANYWHERE
# IN THE TREE, not in three files chosen by hand.
#
# MEASURED DEFECT, 2026-07-31, and the reason this loop is no longer a fixed
# list. The scan covered README.md, NOTICE.md and CITATION.cff. It did not cover
# `.claude-plugin/plugin.json`, whose description read "63 machine-checked
# theorems" while the source held 72 -- nine short, green, and sitting in THE
# ONE FILE A MARKETPLACE READER SEES FIRST. plugin.json was in REQUIRED, so the
# gate confirmed it EXISTED and never read a word of it.
#
# A hand-maintained list of files-that-may-carry-a-claim has the same defect as
# a hand-maintained list of modules: it stops covering whatever is added after
# it was written. Sweep every tracked file instead, and exempt only the files
# that carry the pattern BY CONSTRUCTION, each with a reason.
#
# `git ls-files -z` because this checkout's path contains spaces (`GIT External
# Repo`, `RoT MoE`); anything that word-splits produces fragments, which is
# precisely how the R1 sweep once reported 68 missing files in a tree of 17.
claim_exempt () {   # 0 = exempt (carries the pattern by construction)
  case "$1" in
    checker/repo-complete.sh)  return 0 ;;  # this file: the control plants 99999
    checker/count-theorems.sh) return 0 ;;  # its comments quote the 73-vs-71 defect
    .github/workflows/*)       return 0 ;;  # ads-manager plants its own control count
    .codemap/*)                return 0 ;;  # generated index, not prose
    # CHANGELOG-ARCHIVE.md is HISTORY, whole. It is the same argument this file
    # already accepted for the newest-section rule twenty lines below: 0.5.x
    # really did ship 195 theorems and really did report 62 mutants, and
    # demanding that those lines track today's tree does not catch drift -- it
    # demands the history be rewritten on every commit, which is the one thing a
    # changelog must never do. The file is exempt BY CONSTRUCTION: every section
    # in it is a settled release, and no live claim is written there. The live
    # log, CHANGELOG.md, is still scanned and still scoped to its newest section.
    CHANGELOG-ARCHIVE.md)      return 0 ;;
    # TASKS/* are DATED CHECKPOINT REPORTS -- the same argument again, and the
    # third time this file has had to make it. `TASKS/2026-08-04-CP2...` states
    # what was measured ON 2026-08-04: 82 mutants across 11 suites, which was
    # true, and which stopped being today's number the moment a twelfth suite was
    # added. Re-measuring a dated report against a later tree does not catch
    # drift; it demands that a record of the past be edited whenever the present
    # moves, and a checkpoint that gets rewritten is not a checkpoint.
    #
    # This is an exemption for HISTORY, not for prose in general. Every live
    # surface -- README.md, CHANGELOG.md's newest section, STATUS.md, both plugin
    # manifests, CITATION.cff -- is still scanned, and the controls below still
    # prove the rule can fire.
    #
    # AS OF THIS COMMIT `TASKS/` IS GITIGNORED AND LOCAL-ONLY, so this arm can no
    # longer fire: the scan enumerates `git ls-files`, and an untracked file is
    # never offered to it. It is kept deliberately rather than deleted. The
    # checkpoints are still written, still read during a session, and a future
    # decision to track any of them again must not silently re-arm a rule that
    # was reasoned about once and then thrown away. A dead arm with a note is
    # cheaper than rediscovering the argument.
    TASKS/*)                   return 0 ;;
    # FINDINGS-<version>.md are DATED AUDIT REPORTS -- the fourth time this file
    # has had to make the same argument, and the first time the rule was not just
    # anachronistic but measuring the wrong quantity outright.
    #
    # FINDINGS-8.0.1.md G4 reads "50 applied, 50 killed" and names its own scope
    # on the same line: rotgauge 12 + rotroute 11 + rotinstall 16 + rotpath 5 +
    # rotvacuity 6 = 50, the FIVE CORE suites. This scan compared that against the
    # 797 mutants declared across ALL suites and called it a false claim. It was
    # never a claim about all of them -- so the failure was not staleness that a
    # rewrite could fix. Editing the 50 to 797 would have replaced a true,
    # measured, scoped sentence with a false one, and the checker would have gone
    # green on the lie.
    #
    # Same exemption for HISTORY, same limit: every live surface is still scanned,
    # and the controls below still prove the rule can fire.
    FINDINGS-*.md)             return 0 ;;
    *) return 1 ;;
  esac
}
claims=0; wrong=0; scanned=0
scan_file_claims () {   # scan_file_claims <file> ; echoes "<file> <claimed>" per claim
  # MEASURED DEFECT, 2026-07-31: this was line-based, and README.md wrapped its
  # own claim across a line break --
  #
  #     ... computes an `R/s+` gauge from them, and **72
  #     machine-checked theorems in Lean 4** state what that gauge must satisfy
  #
  # so the sweep that exists to catch a stale count walked straight past the
  # most prominent claim in the repository. Every OTHER file was caught; the
  # front page was not, purely because a paragraph was rewrapped. A checker
  # whose blind spot is "the author reflowed a sentence" fails exactly when
  # prose is being edited, which is exactly when counts go stale.
  #
  # Folding newlines to spaces first removes the blind spot. Markdown emphasis
  # markers are stripped for the same reason: `**72** machine-checked` is the
  # same claim to a reader and must be the same claim to the checker.
  # A CHANGELOG IS A LOG. Its older entries state what was true AT THAT RELEASE,
  # and 0.5.x really did ship 195 theorems. Requiring every historical entry to
  # track the current tree does not catch drift -- it demands the history be
  # rewritten on every commit that adds a theorem, which is the one thing a
  # changelog must never do. Measured 2026-08-03: the count went 195 -> 205 and
  # this rule went red on two entries that were, and remain, correct.
  #
  # So for CHANGELOG.md only the NEWEST release section is a LIVE claim; earlier
  # sections are history and are not scanned. This is a scope fix, not a hole:
  # the current entry is still checked, so a stale claim in the section being
  # written today still fails. `--newest-section-only` is proved to still catch
  # that by the control at the end of this block.
  _src="$1"
  if [ "$(basename "$1")" = "CHANGELOG.md" ]; then
    _src=$(mktemp "${TMPDIR:-/tmp}/chlog.XXXXXX")
    awk '
      /^## \[/ { seen++ }
      seen >= 2 { exit }
      { print }
    ' "$1" > "$_src"
  fi
  tr '\n' ' ' < "$_src" | tr -s ' ' | sed 's/\*\*//g; s/__//g' \
    | grep -oE '[0-9]+ machine-checked( Lean 4)? theorems?' \
    | grep -oE '^[0-9]+' \
    | while read -r n; do printf '%s %s\n' "$1" "$n"; done
  [ "$_src" != "$1" ] && rm -f "$_src"
  return 0
}
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  claim_exempt "$f" && continue
  # skip binaries
  grep -Iq . "$f" 2>/dev/null || continue
  scanned=$((scanned+1))
  while read -r cf n; do
    claims=$((claims+1))
    if [ "$n" != "$TH" ]; then
      bad "$cf claims $n theorems; source has $TH"
      wrong=$((wrong+1))
    fi
  done < <(scan_file_claims "$f")
done < <(git ls-files -z)
echo "  scanned $scanned tracked text file(s) for count claims"
[ "$claims" -eq 0 ] && bad "no theorem-count claim found in the prose -- the check is vacuous"
[ "$claims" -gt 0 ] && [ "$wrong" -eq 0 ] && ok "all $claims theorem-count claim(s) match source ($TH)"

# Per-module counts in the README bullets, e.g. "(34 theorems)".
if [ -f README.md ]; then
  permod=0; permod_wrong=0
  for m in lean/Proofs/*.lean; do
    base="$(basename "$m" .lean)"
    real=$(bash "$REPO/checker/count-theorems.sh" "$m")
    claimed=$(grep -oE "$base\.lean\*\*\` \(([0-9]+) theorems\)" README.md | grep -oE '\([0-9]+' | tr -d '(')
    [ -z "$claimed" ] && claimed=$(grep -A1 "$base.lean" README.md | grep -oE '\(([0-9]+) theorems\)' | grep -oE '[0-9]+' | head -1)
    if [ -n "$claimed" ]; then
      permod=$((permod+1))
      [ "$claimed" != "$real" ] && { bad "README says $base has $claimed theorems; source has $real"; permod_wrong=$((permod_wrong+1)); }
    fi
  done
  [ "$permod" -gt 0 ] && [ "$permod_wrong" -eq 0 ] && ok "all $permod per-module count(s) match source"
fi

# --- MUTANT-COUNT CLAIMS ----------------------------------------------------
# "62 applied, 62 killed, 0 survived, 0 discarded" is the single strongest
# sentence in the README, and until now NOTHING re-derived it. Re-running the
# suites is the honest measurement and it costs upward of fifteen minutes, so
# CI owns that; what belongs here is the half that is free and that actually
# went stale: HOW MANY MUTANTS ARE DECLARED. Every mutant is one `run_mut` or
# `run_mut_nth` call, countable without building anything, and the claim moved
# by hand from 55 to 62 in the same edit that added a suite -- by hand is
# exactly the process this repository does not trust.
#
# What this does NOT establish: that they all still KILL. A count is coverage,
# not a result, and saying so here is cheaper than a reader assuming otherwise.
declared_mut=0
for s in lean/mutate/mutate_rot*.sh; do
  [ -f "$s" ] || continue
  # An INVOCATION carries a mutant ID (`run_mut V01 ...`); the two function
  # DEFINITIONS at the top of each suite do not. The first version matched
  # `^run_mut ` and counted the definitions too -- 72 declared against 62
  # measured, which is a checker that would have made a correct README look
  # wrong and invited someone to "fix" a true number. Requiring the ID is what
  # makes this a count of mutants rather than a count of lines.
  n=$(grep -cE '^run_mut(_nth)? [A-Z][A-Za-z0-9]*[0-9] ' "$s" 2>/dev/null); n=${n:-0}
  declared_mut=$((declared_mut + n))
done
if [ "$declared_mut" -gt 0 ]; then
  mut_claims=0; mut_wrong=0
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    claim_exempt "$f" && continue
    grep -Iq . "$f" 2>/dev/null || continue
    # SAME SCOPING AS THE THEOREM COUNT, and the asymmetry was a real gap rather
    # than a considered difference. The theorem-count scan learned in 0.6.x that
    # a changelog's older entries are history and must not be re-measured; the
    # mutant-count scan on the same file kept scanning top to bottom. Nothing
    # exposed it until a release entry quoted the PREVIOUS release's mutant total
    # in a prior-versus-after table -- a correct, measured, historical number that
    # this rule called a lie.
    #
    # Scoping it is not a hole: a stale mutant count in the section being written
    # today still fails, which the control at the end of this block proves by
    # planting one.
    _msrc="$f"
    if [ "$(basename "$f")" = "CHANGELOG.md" ]; then
      _msrc=$(mktemp "${TMPDIR:-/tmp}/chmut.XXXXXX")
      awk '
        /^## \[/ { seen++ }
        seen >= 2 { exit }
        { print }
      ' "$f" > "$_msrc"
    fi
    while read -r n k; do
      mut_claims=$((mut_claims+1))
      if [ "$n" != "$declared_mut" ] || [ "$k" != "$declared_mut" ]; then
        bad "$f claims $n applied / $k killed; the suites declare $declared_mut mutants"
        mut_wrong=$((mut_wrong+1))
      fi
    done < <(tr '\n' ' ' < "$_msrc" | tr -s ' ' | sed 's/\*\*//g' \
             | grep -oE '[0-9]+ applied, [0-9]+ killed' \
             | awk '{print $1, $3}')
    [ "$_msrc" != "$f" ] && rm -f "$_msrc"
  done < <(git ls-files -z)
  if [ "$mut_claims" -eq 0 ]; then
    bad "no mutant-count claim found in the prose -- this check is vacuous"
  elif [ "$mut_wrong" -eq 0 ]; then
    ok "all $mut_claims mutant-count claim(s) match the $declared_mut mutants the suites declare"
  fi
fi

# --- 3. the control ---------------------------------------------------------
# An instrument that has never been seen to fail proves nothing.
echo
echo "-- negative control --"
CTL="$(mktemp -d "${TMPDIR:-/tmp}/repocomp.XXXXXX")"

# The mutant-count check gets its own control: a false claim must be extracted
# and rejected, and a TRUE one must be accepted -- a check that rejects
# everything would pass the first half and be useless.
printf 'the suites report **99999 applied, 99999 killed**, 0 survived.\n' > "$CTL/mut.md"
mc=$(tr '\n' ' ' < "$CTL/mut.md" | sed 's/\*\*//g' | grep -oE '[0-9]+ applied, [0-9]+ killed' | awk '{print $1, $3}')
if [ "$mc" = "99999 99999" ] && [ "99999" != "$declared_mut" ]; then
  ok "CONTROL: a false mutant count (99999 applied/killed) is extracted and would be rejected"
else
  bad "CONTROL DEAD: the mutant-count extractor did not see a planted false claim (got '$mc')"
fi
printf 'the suites report %d applied, %d killed.\n' "$declared_mut" "$declared_mut" > "$CTL/mutok.md"
mc2=$(tr '\n' ' ' < "$CTL/mutok.md" | grep -oE '[0-9]+ applied, [0-9]+ killed' | awk '{print $1, $3}')
if [ "$mc2" = "$declared_mut $declared_mut" ]; then
  ok "CONTROL: a TRUE mutant count is accepted -- the check does not simply reject everything"
else
  bad "CONTROL: a true mutant count was not extracted (got '$mc2')"
fi

printf 'This project has 99999 machine-checked theorems.\n' > "$CTL/fake.md"
# Run the SAME function the sweep runs, not a re-typed grep. A control that
# exercises a copy of the logic tests the copy.
planted=$(scan_file_claims "$CTL/fake.md" | awk '{print $2}')
if [ "$planted" = "99999" ] && [ "$planted" != "$TH" ]; then
  ok "CONTROL: a planted false count (99999) is extracted by the sweep's own function and would be rejected"
else
  bad "CONTROL DEAD: the extractor did not see the planted count"
fi
# SCOPE CONTROL. The defect this phase was rewritten for was not a broken
# extractor -- it was an extractor pointed at three files. So prove the sweep
# reaches beyond prose: a JSON manifest must be reachable and readable by it.
# `plugin.json` is not required to CARRY a claim (a future edit may drop the
# sentence); what must hold is that if it does, the sweep sees it.
# WRAP CONTROL. The blind spot that actually shipped: a claim split across a
# line break by ordinary paragraph rewrapping. Planted in the exact shape
# README.md had it, so this control fails the day someone makes the scan
# line-based again.
printf 'the router computes a gauge, and **99999\nmachine-checked theorems in Lean 4** say what it must satisfy.\n' > "$CTL/wrapped.md"
if [ "$(scan_file_claims "$CTL/wrapped.md" | awk '{print $2}')" = "99999" ]; then
  ok "WRAP CONTROL: a claim split across a line break IS detected (the README's own shape)"
else
  bad "WRAP CONTROL DEAD: a rewrapped claim is invisible -- the front page could go stale unseen"
fi
if git ls-files --error-unmatch .claude-plugin/plugin.json >/dev/null 2>&1; then
  cp .claude-plugin/plugin.json "$CTL/manifest.json"
  # plant a wrong count into the COPY -- the tree is never touched
  printf '\n{"description": "99999 machine-checked theorems"}\n' >> "$CTL/manifest.json"
  if [ "$(scan_file_claims "$CTL/manifest.json" | awk '{print $2}' | tail -1)" = "99999" ]; then
    ok "SCOPE CONTROL: a false count planted in a JSON manifest is detected (the class that shipped 63 vs $TH)"
  else
    bad "SCOPE CONTROL DEAD: a JSON manifest claim is invisible to the sweep"
  fi
else
  bad "SCOPE CONTROL: .claude-plugin/plugin.json is not tracked -- the sweep cannot reach it"
fi
rm -rf "$CTL"

# =============================================================================
# NO PYTHON IN THE PACKET.
#
# This repository ships bash, PowerShell, one Node merge engine and Lean. That
# is the whole runtime surface a user is asked to trust, and every one of those
# is either already required by Claude Code or already required by the proofs.
# Adding Python would add an interpreter to the install story that buys nothing:
# a user without it could not run the checkers, and a user with it gets a fourth
# language to audit.
#
# The rule is enforced here rather than remembered, because "we do not use
# Python" is exactly the kind of convention that survives until the first
# convenient one-off script and then quietly stops being true. A .py file used
# as a throwaway editing tool is fine -- OUTSIDE the tree. Inside it, it is a
# dependency whether or not anyone calls it a dependency.
echo
echo "== NO PYTHON IN THE PACKET =="
py_tracked=$(git ls-files '*.py' '*.pyw' | grep -c . || true)
if [ "$py_tracked" -eq 0 ]; then
  ok "no Python file is tracked in the repository"
else
  bad "$py_tracked Python file(s) are tracked -- the packet has grown an interpreter dependency:"
  git ls-files '*.py' '*.pyw' | sed 's/^/        /' | head -10
fi

# Untracked ones matter too: they are what a build script would reach for, and
# they are invisible to `git ls-files` right up until someone commits them.
#
# `.lake/` is EXCLUDED, and that is a correction, not a loophole. Measured:
# lean/.lake/packages/mathlib/scripts/ carries 29 .py files of mathlib's own
# tooling. They arrive with `lake exe cache get`, they are gitignored, and
# checker/release-package.sh already excludes .lake from every archive -- so
# they are not in the packet by any definition this suite uses. Flagging them
# printed "delete them or move them outside" 29 times about a dependency's
# source, which is advice that breaks the build, and it buried any genuine
# stray .py underneath a wall of false positives. A checker that cries wolf
# about files the operator must not touch trains the operator to ignore it.
#
# The count of what was skipped is PRINTED rather than silently dropped: an
# exclusion nobody can see is how a scan quietly stops covering anything.
py_all=$(find . -name '*.py' -o -name '*.pyw' 2>/dev/null | grep -v '^\./\.git/' | grep -c . || true)
py_loose=$(find . -name '*.py' -o -name '*.pyw' 2>/dev/null | grep -v '^\./\.git/' | grep -v '/\.lake/' | grep -c . || true)
py_dep=$((py_all - py_loose))
if [ "$py_loose" -eq 0 ]; then
  ok "no untracked Python file is sitting in the working tree either ($py_dep skipped inside .lake/, a dependency checkout)"
else
  bad "$py_loose untracked Python file(s) in the tree -- delete them or move them outside"
  find . -name '*.py' -o -name '*.pyw' 2>/dev/null | grep -v '^\./\.git/' | grep -v '/\.lake/' | sed 's/^/        /' | head -10
fi

# No shipped script may INVOKE python either. A repository with no .py that
# shells out to `python3 -c` has the dependency without the evidence, which is
# the worse of the two states: nothing to grep for and everything to break.
#
# THE PATTERN MATCHES A COMMAND POSITION, NOT THE WORD. The first version of
# this check matched `python|python3|py` as bare tokens and reported four files,
# every one of them a FALSE POSITIVE: a `'*.py'` glob in this very file, a
# `check_lang python '*.py'` row in the repo-topic table, and `py` sitting in a
# list of source extensions the proof-debt reminder scans. A rule that fires on
# the NAME of a language cannot tell a dependency from a mention of one, and a
# gate that cries wolf gets weakened by the next person who has to ship past it.
#
# So the interpreter must appear where a command appears: at the start of a
# line, or after ; | & ( or a $( -- and bare `py` counts only as the Windows
# launcher form `py -3`, because two letters collide with everything.
PYCMD='(^|[;|&(]|\$\()[[:space:]]*(python3?|uv[[:space:]]+run)([[:space:]]|$)'
PYLAUNCH='(^|[;|&(]|\$\()[[:space:]]*py[[:space:]]+-[0-9]'
PYTMP="$(mktemp "${TMPDIR:-/tmp}/rotmoe-pyscan.XXXXXX")"
py_call=0
for f in $(git ls-files '*.sh' '*.ps1' '*.js' '*.yml' '*.yaml'); do
  [ -f "$f" ] || continue
  # strip comments and printed strings first, or the paragraph you are reading
  # right now would trip the detector that it describes
  # Write the stripped text to a FILE and grep the file. Piping into `grep -q`
  # is forbidden repo-wide (checker/portability.sh) because grep -q exits at the
  # first match, SIGPIPEs the writer, and under `set -o pipefail` the pipeline
  # status then depends on the platform's pipe buffer. A `case` glob cannot
  # replace it here -- these two patterns are extended regexes -- so the text
  # goes through a temp file instead.
  # `sed -E`, NOT a BRE with \( \| \). Measured on the macOS runner: `\|`
  # alternation inside a BRE is a GNU EXTENSION. BSD sed treats it literally, so
  # the strip silently does NOTHING and line 407 below -- the control's own
  # message, "(python3 -c, | python -, $(uv run), py -3)" -- survives and trips
  # the detector that it exists to describe. Ubuntu passed, macOS failed, and
  # the checker blamed the file it was reading.
  # -E is accepted by both BSD and GNU sed, so the alternation is portable.
  sed -E 's/#.*$//; s/\/\/.*$//; s/(say|echo|printf|Write-Output|note|ok|bad).*$//' "$f" > "$PYTMP"
  if grep -qE "$PYCMD" "$PYTMP" || grep -qE "$PYLAUNCH" "$PYTMP"; then
    bad "$f invokes a Python interpreter"
    py_call=$((py_call+1))
  fi
done
[ "$py_call" -eq 0 ] && ok "no shipped script invokes a Python interpreter ($(git ls-files '*.sh' '*.ps1' '*.js' '*.yml' '*.yaml' | grep -c .) files scanned)"

# --- controls: all three predicates must be able to fire ---------------------
PYCTL="$(mktemp -d "${TMPDIR:-/tmp}/rotmoe-pyctl.XXXXXX")"
printf 'print("hello")\n' > "$PYCTL/planted.py"
if [ "$(find "$PYCTL" -name '*.py' | grep -c .)" -eq 1 ]; then
  ok "CONTROL: a planted .py IS found by the same find expression"
else
  bad "CONTROL DEAD: the find expression cannot see a planted .py"
fi
detects () {   # $1 = file. Same two expressions, and the same temp-file shape,
               # as the sweep above -- a control that tests a DIFFERENT pipeline
               # from the one it is vouching for is not a control.
  sed -E 's/#.*$//; s/\/\/.*$//; s/(say|echo|printf|Write-Output|note|ok|bad).*$//' "$1" > "$PYTMP"
  grep -qE "$PYCMD" "$PYTMP" && return 0
  grep -qE "$PYLAUNCH" "$PYTMP" && return 0
  return 1
}

# It must FIRE on a real invocation -- three shapes, since one shape proves one shape.
pos_ok=0
printf '#!/bin/sh\npython3 -c "print(1)"\n'          > "$PYCTL/a.sh"; detects "$PYCTL/a.sh" && pos_ok=$((pos_ok+1))
printf '#!/bin/sh\ncat f | python -\n'               > "$PYCTL/b.sh"; detects "$PYCTL/b.sh" && pos_ok=$((pos_ok+1))
printf '#!/bin/sh\nv=$(uv run script)\n'             > "$PYCTL/c.sh"; detects "$PYCTL/c.sh" && pos_ok=$((pos_ok+1))
printf '#!/bin/sh\npy -3 thing\n'                    > "$PYCTL/d.sh"; detects "$PYCTL/d.sh" && pos_ok=$((pos_ok+1))
if [ "$pos_ok" -eq 4 ]; then
  ok "CONTROL: all 4 planted invocations ARE detected (python3 -c, | python -, \$(uv run), py -3)"
else
  bad "CONTROL DEAD: only $pos_ok of 4 planted Python invocations were detected"
fi

# And it must NOT fire on any of the four shapes that made it cry wolf. These are
# not hypotheticals: each is copied from the file that was falsely accused.
neg_bad=0
printf '#!/bin/sh\necho "we never call python here"\n'      > "$PYCTL/n1.sh"
printf '#!/bin/sh\ngit ls-files "*.py" "*.pyw"\n'           > "$PYCTL/n2.sh"
printf '#!/bin/sh\ncheck_lang python "*.py"\n'              > "$PYCTL/n3.sh"
printf '#!/bin/sh\nDEBT_EXT="rs c h go ts js py java kt"\n' > "$PYCTL/n4.sh"
for n in n1 n2 n3 n4; do
  if detects "$PYCTL/$n.sh"; then
    bad "CONTROL: $n.sh (a mention, not an invocation) is flagged -- the rule is too broad again"
    neg_bad=$((neg_bad+1))
  fi
done
if [ "$neg_bad" -eq 0 ]; then
  ok "CONTROL: a printed word, a '*.py' glob, a language table row and an extension list are NOT flagged"
fi
rm -rf "$PYCTL"
rm -f "$PYTMP"

# --- 4. EVERY THEOREM README CITES MUST EXIST -------------------------------
# THE GAP THIS CLOSES (measured 2026-08-03). Section 2 recounts the per-module
# theorem NUMBERS, so a count that drifts is caught. Nothing checked the NAMES.
# README.md cites 58 theorems by name -- `route_fires`, `lead_does_not_shrink`,
# `claude_leads_forge` and the rest -- and a rename or a deletion would have
# left the page citing a ghost with every gate still green. The citation is the
# reader's only route from a claim to its proof; a dead one is a broken promise
# that looks exactly like a kept one.
#
# THE SCAN MUST BE COMMENT-AWARE, and that is not a detail. A naive
# `grep '^theorem'` over the corpus reports `lead_does_not_shrink` TWICE,
# because the doc comment of the real theorem quotes its own former statement
# in a fenced block that starts at column 0. The same trap has now been hit
# four times in this repository by four different scanners, so the stripper
# below is the same nesting-aware one `count-theorems.sh` uses.
echo
echo "== README CITATIONS: every theorem named on the page must exist =="
RCTMP="$(mktemp -d "${TMPDIR:-/tmp}/readmecite.XXXXXX")"
strip_lean_comments () {
  awk '{ line=$0; i=1; out=""
         while (i <= length(line)) {
           two = substr(line, i, 2)
           if (two == "/-") { depth++; i += 2; continue }
           if (two == "-/") { if (depth > 0) depth--; i += 2; continue }
           if (depth == 0) out = out substr(line, i, 1)
           i++ }
         print out }' "$1"
}
for f in lean/Proofs/*.lean; do strip_lean_comments "$f"; done \
  | grep -oE '^(@\[[^]]*\] )?(private |protected |noncomputable )*(theorem|lemma) [A-Za-z_][A-Za-z0-9_]*' \
  | awk '{print $NF}' | sort -u > "$RCTMP/real.txt"

# A citation is a backticked snake_case identifier: at least one underscore and
# no dot or slash, which excludes file names, flags and module paths.
#
# THE SURFACE FOLLOWS THE CONTENT (7.0.0). The compression moved the front
# page's depth -- the module arguments, the lens benchmark, the Easter Egg --
# into docs/ files, and most of the 58 citations moved with it. A scan pinned
# to README.md alone would have gone from 58 names to single digits and called
# its own blindness a defect of the page. The surface is now the README plus
# exactly the five depth files that carry moved front-page content. NOT the
# whole of docs/: SCRUTINY-LOG and its kind are HISTORY -- they may cite
# theorems as they stood at the time, and binding them would demand the log be
# rewritten, the one thing a log must never do (module-claims.sh states the
# same scope rule for counts).
CIT_SURFACE="README.md docs/lean-and-corpus.md docs/modules.md docs/tips.md docs/lens-bench.md docs/easter-egg.md"
: > "$RCTMP/cited.raw"
for _cf in $CIT_SURFACE; do
  [ -f "$_cf" ] && grep -oE '`[a-z][a-z0-9]*(_[a-z0-9]+)+`' "$_cf" >> "$RCTMP/cited.raw"
done
tr -d '`' < "$RCTMP/cited.raw" | sort -u > "$RCTMP/cited.txt"
# Words that are legitimately snake_case and are NOT theorems.
NOT_THEOREMS='native_decide|lake_build|lean_lib|rot_moe|claude_config_dir'
grep -vE "^($NOT_THEOREMS)$" "$RCTMP/cited.txt" > "$RCTMP/cited2.txt" || true

ghosts=0
while read -r nm; do
  [ -n "$nm" ] || continue
  grep -qx "$nm" "$RCTMP/real.txt" || { bad "the published pages cite \`$nm\` -- no such theorem in lean/Proofs"; ghosts=$((ghosts+1)); }
done < "$RCTMP/cited2.txt"
ncit=$(wc -l < "$RCTMP/cited2.txt" | tr -d ' ')
[ "$ghosts" -eq 0 ] && ok "all $ncit theorem names cited across README.md + the docs depth files resolve to a real declaration"

# The citation set must not be allowed to shrink to nothing: an extractor that
# silently stops matching would report "0 ghosts" and look like a pass. The
# floor is held over the whole surface (the depth files carry most names now).
if [ "$ncit" -ge 40 ]; then
  ok "the citation extractor found $ncit names (a scan that matched nothing would pass vacuously)"
else
  bad "only $ncit citations extracted from the citation surface -- the extractor has gone blind, not the pages clean"
fi

# CONTROL: a cited name that does not exist MUST be reported. The needle is
# assembled at run time so this file cannot match its own fixture -- the
# mistake that has already cost this repo two false greens.
GHOST="no_such$(printf '_')theorem_$$"
if grep -qx "$GHOST" "$RCTMP/real.txt"; then
  bad "CONTROL BROKEN: the invented name somehow exists"
else
  ok "CONTROL: an invented citation (\`$GHOST\`) is absent from the corpus, so the lookup can fail"
fi
rm -rf "$RCTMP"

# --- 5. EVERY IN-DOCUMENT ANCHOR MUST RESOLVE TO A HEADING -------------------
# MEASURED 2026-08-04: RELEASE.md's three variant badges -- the first thing a
# reader sees and clicks -- pointed at `#-v010--pure-router`, `#-v011-...` and
# `#-v012-...`. Those headings stopped existing after 0.1.x. The links had been
# dead through six releases, in the document whose entire job is telling a
# stranger which archive to download.
#
# Nothing could have caught it. The version bump is a sed over `0.6.x -> 0.7.x`
# in the HEADINGS; the anchors carry a squashed spelling (`v012`) that no
# version-shaped pattern matches, so they sit still while everything around them
# moves. That is the signature of rot: not a wrong edit, an edit that could not
# reach.
#
# The rule is general and does not expire: a `](#...)` in a shipped Markdown file
# must match a heading in the same file, under GitHub's slug rules -- lowercase,
# non-alphanumerics dropped, spaces to hyphens.
echo
echo "== INTERNAL ANCHORS: every '](#...)' must name a heading in its own file =="
anch_total=0; anch_dead=0
for f in $(git ls-files '*.md'); do
  [ -f "$f" ] || continue
  # Slugs of every heading in this file.
  # NON-ASCII IS DROPPED FIRST, and that is not tidiness. `sed`'s bracket class
  # is BYTE-wise in this locale: `s/[^a-z0-9 _-]//g` over a heading beginning
  # with an emoji removes some of its UTF-8 bytes and leaves the rest, so the
  # slug came out as `\xa6-v070--pure-router` and every emoji heading was
  # reported dead. The check would have been a 7-line false alarm shipped as a
  # gate. `tr -d '\200-\377'` removes the whole character, which is also what
  # GitHub does with emoji before slugging.
  slugs=$(grep -E '^#{1,6} ' "$f" \
    | sed -E 's/^#{1,6} //' \
    | tr '[:upper:]' '[:lower:]' \
    | tr -d '\200-\377' \
    | sed -E 's/`//g; s/[^a-z0-9 _-]//g; s/ /-/g')
  for a in $(grep -oE '\]\(#[a-zA-Z0-9_-]+\)' "$f" | sed -E 's/^\]\(#//; s/\)$//'); do
    anch_total=$((anch_total+1))
    # A here-string, NOT `printf | grep -q`. `grep -q` exits at the first match
    # and SIGPIPEs the writer; under `set -o pipefail` that is a platform-
    # dependent failure, which is why checker/portability.sh refuses the shape.
    grep -qx -- "$a" <<<"$slugs" || {
      bad "$f: anchor '#$a' matches no heading in that file"
      anch_dead=$((anch_dead+1))
    }
  done
done
if [ "$anch_total" -eq 0 ]; then
  bad "no internal anchors found at all -- this check is vacuous"
elif [ "$anch_dead" -eq 0 ]; then
  ok "all $anch_total internal anchors resolve"
fi
# CONTROL: the slug rule must be able to reject. A heading that does not exist
# has to be reported, or the sweep above is decoration.
_actl=$(mktemp -d "${TMPDIR:-/tmp}/anchctl.XXXXXX")
printf '# Real Heading\n\n[go](#real-heading) and [dead](#not-a-heading)\n' > "$_actl/t.md"
_s=$(grep -E '^#{1,6} ' "$_actl/t.md" | sed -E 's/^#{1,6} //' \
     | tr '[:upper:]' '[:lower:]' | sed -E 's/`//g; s/[^a-z0-9 _-]//g; s/ /-/g')
if grep -qx -- "real-heading" <<<"$_s" \
   && ! grep -qx -- "not-a-heading" <<<"$_s"; then
  ok "CONTROL: the slug rule accepts a real heading and rejects an invented one"
else
  bad "CONTROL DEAD: the slug rule cannot tell a real heading from an invented one"
fi
rm -rf "$_actl"

# --- A LIVE MUTANT MUST NEVER REACH A COMMIT ---------------------------------
# MEASURED 2026-08-07: a gate run was SIGKILLed at a wall-clock ceiling while
# checker/mutate-checker.sh had `hooks/rot-router.sh` mutated. SIGKILL is
# untrappable, so the restore handler never ran and the tree kept a router with
# two STEALTH stems deleted, beside four `.mutbak` files holding the originals.
# `git add -A` at that moment would have published the mutant as the router.
#
# `.mutbak` in the tree therefore means exactly one thing: a mutation run died,
# and the ORIGINAL IS IN THE BACKUP. This refuses the commit and says how to
# recover -- restore, never delete. Deleting the backup makes the mutant
# permanent, which is the one irreversible mistake available here.
# The properties are in lean/Proofs/RotObserve.lean §16.
mutbaks="$(find . -name '*.mutbak' -not -path './.git/*' 2>/dev/null | head -10)"
if [ -z "$mutbaks" ]; then
  ok "no .mutbak in the tree -- no mutation run died holding an original"
else
  n=$(printf '%s\n' "$mutbaks" | grep -c .)
  bad "$n .mutbak file(s) present: a mutation run was INTERRUPTED and a MUTANT may be live:"
  printf '%s\n' "$mutbaks" | sed 's/^/        /'
  echo "        RESTORE, do not delete:  for b in \$(find . -name '*.mutbak'); do cp \"\$b\" \"\${b%.mutbak}\" && rm \"\$b\"; done"
  echo "        Deleting a .mutbak promotes the mutant to the real file."
fi

echo
echo "== INVENTORY CLAIMS: modules, suites and CHECKERS, not just theorems =="
#
# MEASURED DEFECT, 2026-08-10. README.md:557 read "51 modules, 968 theorems,
# 48 mutation suites ... (63 checkers)" while the tree held 64 checkers. The
# theorem count was caught -- it is swept everywhere -- and the other three were
# not, because `$MODS` and `$SUITES` were MEASURED at line 116 and then only
# PRINTED. A number that is computed and never compared is decoration.
#
# The checker count was not even measured. Adding a 64th checker (`trap.sh`)
# left a stale "63 checkers" claim in the shipping README, green, in the same
# table that advertises the release tiers.
#
# Same sweep discipline as the theorem loop: every tracked file, the existing
# exemption list, no hand-maintained roster of files-that-may-carry-a-claim.
CHKS=$(ls "$REPO"/checker/*.sh 2>/dev/null | wc -l | tr -d ' ')
echo "  measured: $MODS modules, $SUITES mutation suites, $CHKS checkers"

inv_check () {   # <regex with one capture> <expected> <label>
  local re="$1" want="$2" label="$3" hits=0 bad=0
  while IFS= read -r -d '' f; do
    claim_exempt "$f" && continue
    [ -f "$REPO/$f" ] || continue
    # CHANGELOG.md IS NOT SCANNED BY THIS BLOCK, and the reason is a scope
    # judgement worth writing down rather than a convenience.
    #
    # The theorem sweep above can scan it safely because it matches a
    # DISTINCTIVE LIVE-CLAIM PHRASE -- "<n> machine-checked theorems" -- which
    # narrative prose does not accidentally contain. There is no such phrase for
    # suites or checkers, so a bare `<n> mutation suites` pattern reads the
    # changelog's own HISTORY as a claim about today. Measured on the first run
    # of this block, it flagged two lines that are correct and must not change:
    #
    #   "### 30 of 46 mutation suites left the tree unbuildable ..."   (an event)
    #   "Counts move to 24 modules, 578 theorems, 21 mutation suites"  (a past release)
    #
    # Editing either to satisfy a counter would falsify the record, which is the
    # one thing a changelog must never do.
    #
    # THE RESIDUAL GAP, STATED: a stale suite/checker count written into the
    # NEWEST changelog section is not caught here. It is caught for theorems
    # (distinctive phrase, newest section only), and README plus all four
    # manifests -- where a reader actually meets the number -- are fully covered
    # by this block. Closing the gap properly needs a live-claim marker in the
    # changelog, not a broader regex.
    [ "$f" = "CHANGELOG.md" ] && continue
    # GREP THE FILE DIRECTLY. The previous form slurped the whole file into
    # `body=$(cat ...)` and re-emitted it with `printf '%s\n' "$body"`, which
    # CRASHED on macOS: run 31635348645, checkers (macos-latest), a stream of
    #
    #   checker/repo-complete.sh: line 683: 12035 Bus error: 10  printf '%s\n' "$body"
    #
    # macOS ships bash 3.2, and a single argument holding an entire README is
    # enough to take it down with SIGBUS. Ubuntu and Windows (both modern bash)
    # scanned the same file and passed, so this read as a macOS-only phantom.
    #
    # WHAT THE CRASH ACTUALLY DID is the part worth recording: the subshell died
    # producing NO output, so the loop below simply saw no claims. The scan did
    # not report an error -- it reported nothing, which is indistinguishable from
    # "this file makes no claim". Only the `hits -eq 0` guard further down turned
    # that silence into a FAIL. Without it, a checker crashing on every file
    # would have printed a clean green.
    #
    # Passing the filename to grep removes the giant-argument path entirely, and
    # is what the theorem loop already does.
    while IFS= read -r got; do
      [ -n "$got" ] || continue
      hits=$((hits+1))
      if [ "$got" != "$want" ]; then
        echo "  FAIL  $f claims $got $label; the tree has $want"
        fail=$((fail+1)); bad=$((bad+1))
      fi
    done < <(grep -oE "$re" "$REPO/$f" 2>/dev/null | grep -oE '[0-9]+')
  done < <(cd "$REPO" && git ls-files -z)
  if [ "$hits" -eq 0 ]; then
    # Zero sites is not a pass. If the phrasing changes, this check silently
    # stops covering anything -- the same invisible-gate failure the tier split
    # was written to prevent.
    echo "  FAIL  no '$label' claim found anywhere -- this check now covers nothing"
    fail=$((fail+1))
  elif [ "$bad" -eq 0 ]; then
    echo "  PASS  $hits '$label' claim(s), all = $want"
    pass=$((pass+1))
  else
    # Printing PASS beside a FAIL for the same check is how a red line gets read
    # as green in a long log. Measured here on the first run of this block.
    echo "  ....  $hits '$label' claim(s) scanned, $bad wrong -- see the FAILs above"
  fi
}

inv_check '\([0-9]+ checkers\)'   "$CHKS"   "checkers"
inv_check '[0-9]+ mutation suites' "$SUITES" "mutation suites"

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  repo-complete: PASS"; exit 0; } || { echo "  repo-complete: FAIL"; exit 1; }
