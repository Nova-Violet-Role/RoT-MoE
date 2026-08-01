#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# THE LICENCE CLAIM MUST MATCH THE EVIDENCE ON DISK -- IN BOTH DIRECTIONS.
#
# The architecture this repository implements is documented in a blueprint that
# declares itself PROPRIETARY, all rights reserved, patent claims pending
# (*The Role of Thoughts -- Dynamic Cognitive MoE Architecture*, (c) 2025-2026
# Nova_Omega Project). This tree ships an implementation under
# AGPL-3.0-or-later OR EUPL-1.2.
#
# That is perfectly lawful when the rightsholder is the same party -- an owner
# may license a specification and an implementation differently. But "the owner
# told me so" is not something a packager, a distro, or a lawyer can read. The
# instrument that settles it is a WRITTEN GRANT FILED IN THIS REPOSITORY.
#
# So this checker enforces the only invariant that is actually checkable today:
#
#     NOTICE.md must describe the evidence that EXISTS, not the evidence we
#     wish existed -- and it must do so in BOTH directions.
#
#   * grant file ABSENT  -> NOTICE must call the shared-rightsholder fact an
#                           ASSUMPTION and name the open alarm. (Today.)
#   * grant file PRESENT -> NOTICE must STOP calling it an assumption, because
#                           at that point the claim is documented and the
#                           hedge would be the false statement.
#
# The second direction is the one that makes this more than a spelling check.
# A checker that only fires when a file is missing rots into a reminder; one
# that fires when the DOCUMENTATION AND THE TREE DISAGREE keeps working after
# the alarm closes. That is the difference between a snapshot and an invariant,
# and this repo has already shipped one theorem that froze a contingent fact --
# once was enough.
#
# NOT IN SCOPE, said plainly: this cannot verify that the grant is valid, that
# the signatory owns what they purport to grant, or that the patent claims are
# enforceable. It verifies that the repository's own prose matches the
# repository's own contents. Legal advice is not an instrument this shell has.
# =============================================================================

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }

echo "== licence bridge: does NOTICE.md match what is on disk? =="

GRANT_CANDIDATES="LICENSES/ARCHITECTURE-GRANT.md ARCHITECTURE-GRANT.md LICENSES/RoT-ARCHITECTURE-GRANT.md"
GRANT=""
for g in $GRANT_CANDIDATES; do
  [ -f "$g" ] && { GRANT="$g"; break; }
done

# The section itself must exist. Deleting it is the failure mode the alarm
# explicitly forbids: it would leave the two licences facing each other with
# nothing in between.
if grep -q '^### A.4 ' NOTICE.md 2>/dev/null; then
  ok "NOTICE.md carries the A.4 licence bridge"
else
  bad "NOTICE.md has NO A.4 section -- the proprietary/copyleft bridge is gone"
fi

# The section must state what the dual grant does NOT cover. A bridge that only
# says "everything is fine" is marketing.
grep -q 'does not cover\|What it does not cover' NOTICE.md \
  && ok "A.4 states what the dual grant does NOT cover" \
  || bad "A.4 no longer states the limits of the grant -- that is the load-bearing half"

HEDGED=0
grep -qi 'recorded as an assumption\|as an assumption, not measured' NOTICE.md && HEDGED=1

if [ -z "$GRANT" ]; then
  echo "  NOTE  no architecture grant file found (searched: $GRANT_CANDIDATES)"
  if [ "$HEDGED" -eq 1 ]; then
    ok "no grant on disk, and NOTICE.md correctly records the shared-rightsholder fact as an ASSUMPTION"
  else
    bad "no grant file exists, but NOTICE.md no longer calls it an assumption -- the prose claims evidence the tree does not have"
  fi
  grep -q 'R24' NOTICE.md \
    && ok "the open alarm (R24) is named in NOTICE.md, so the gap is trackable" \
    || bad "the assumption is recorded but no alarm is named -- it will be forgotten"
else
  ok "architecture grant present: $GRANT"
  if [ "$HEDGED" -eq 1 ]; then
    bad "$GRANT exists, but NOTICE.md still calls the rightsholder identity an ASSUMPTION -- update the prose, the evidence has arrived"
  else
    ok "grant on disk and NOTICE.md states it as documented, not assumed -- the two agree"
  fi
  # A grant that names nothing is a signature on a blank page.
  grep -qi 'Role of Thoughts' "$GRANT" \
    && ok "$GRANT names the architecture it grants" \
    || bad "$GRANT does not name *The Role of Thoughts* -- a grant must say what it grants"
fi

# --- the credit paragraphs must survive refactoring -------------------------
#
# A.3 credits an upstream that `agents/lean4-prover.md` itself declares descent
# from. The failure mode is not malice, it is TIDYING: someone reformats the
# prover head, the declaration reads oddly out of context, and it goes. The
# credit then exists nowhere, and the repository is silently making a stronger
# originality claim than it can support.
#
# So both halves are pinned, and they must agree with each other.
echo
echo "-- the upstream credit (A.3 / R22) --"
if grep -q '^### A.3 ' NOTICE.md 2>/dev/null; then
  ok "NOTICE.md carries the A.3 upstream credit"
else
  bad "NOTICE.md has NO A.3 section -- an omitted credit is the same defect as a false one"
fi
grep -qi 'unresolved' NOTICE.md \
  && ok "A.3 still states the upstream licence as UNRESOLVED rather than assumed" \
  || bad "A.3 no longer marks the upstream licence unresolved -- that is a claim this repo cannot support"
if [ -f agents/lean4-prover.md ]; then
  if grep -qi 'leanstral' agents/lean4-prover.md; then
    ok "agents/lean4-prover.md still carries its own declaration of descent"
  else
    bad "agents/lean4-prover.md dropped its provenance declaration while NOTICE.md still credits it -- the two disagree"
  fi
fi

# --- controls ---------------------------------------------------------------
echo
echo "-- negative controls --"
PCTL="$(mktemp -d "${TMPDIR:-/tmp}/pvctl.XXXXXX")"
printf 'You are a Lean 4 specialist. No provenance here.\n' > "$PCTL/agent.md"
if grep -qi 'leanstral' "$PCTL/agent.md"; then
  bad "CONTROL DEAD: the credit detector matched a file with no credit"
else
  ok "CONTROL: a prover head with its credit stripped IS detectable"
fi
rm -rf "$PCTL"
# Direction 1: the prose drops the hedge while no grant exists.
CTL="$(mktemp -d "${TMPDIR:-/tmp}/lbctl.XXXXXX")"
printf '### A.4 bridge\nEverything is fine and fully documented.\n' > "$CTL/NOTICE.md"
if grep -qi 'recorded as an assumption' "$CTL/NOTICE.md"; then
  bad "CONTROL DEAD: the hedge detector matched a document with no hedge"
else
  ok "CONTROL: a NOTICE that quietly drops the assumption IS detectable"
fi
# Direction 2: a grant arrives and the prose is not updated -- this is the check
# that keeps working AFTER the alarm closes.
printf 'Grant for The Role of Thoughts architecture.\n' > "$CTL/grant.md"
if grep -qi 'Role of Thoughts' "$CTL/grant.md" && grep -qi 'recorded as an assumption' NOTICE.md; then
  ok "CONTROL: with a grant present, today's NOTICE wording WOULD be flagged as stale"
else
  ok "CONTROL: (grant present + stale hedge) combination is exercised by the live branch above"
fi
rm -rf "$CTL"

echo
echo "== RESULT =="
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] && { echo "  licence-bridge: PASS"; exit 0; } || { echo "  licence-bridge: FAIL"; exit 1; }
