/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

  RotSubjectIdentity -- the newest record can still be about the wrong tree.

  MEASURED, 2026-08-19, branch 9.0.0. Four gates on this branch are blocked by
  a single external record: `checker/deferred-closure.sh` refuses to close any
  deferred step because "the newest completed CI run (67d8791) concluded
  'failure'", and three further CI-reading gates skip for want of a readable
  run. That skip is honest -- SKIP IS NOT A PASS -- and the refusal is the
  right policy. This file is about the premise underneath the policy.

  The measurement. Run 32479070757 is real and it is red. Its two failing
  steps were pulled from the API and read directly:

      lean -- build, axioms, kernel re-check
        FAILED STEP 8: portability -- exec bits in the index, CRLF-proof hooks
      checkers (ubuntu | macos | windows -latest)
        FAILED STEP 7: SPDX + copyright sweep

  Both name the SAME five files:

      bonus/cmdpulse/statusline.sh
      bonus/cmdpulse/install.sh
      bonus/cmdpulse/cmdpulse/cmdpulse.sh
      bonus/cmdpulse/cmdpulse/record.sh
      bonus/cmdpulse/cmdpulse/cmdpulse-web.sh

  On `origin/main` those five are mode 100644 and carry no SPDX header. On
  this branch they are mode 100755 and all five carry the header. Both defects
  are already repaired here. Measured locally, exit codes read directly:

      bash checker/spdx-sweep.sh      -> 0   (337 files, 0 missing)
      bash checker/portability.sh     -> 0   (183 tracked .sh, all 100755)

  And the local sweep genuinely covers that directory -- proved by breaking it
  on purpose rather than by its silence: stripping the header from
  statusline.sh drove the sweep to exit 1 naming that exact file, and the file
  was then restored byte-identical.

  So the red run is not evidence about this tree. It is evidence about a
  different tree, which happens to be the newest evidence available. The gate
  reads it because it is newest, and the branch has never been pushed, so no
  record about THIS tree exists at all.

  What this file settles. The project already proved a freshness law in
  `RotFreshness.lean`: a result ages out because age is a change of subject,
  not a degradation of quality. That law is stated over TIME. The measurement
  above is the same law on a different axis -- the record is not old, it is
  the newest one there is, and it is still about something else. Time was
  never the operative variable. Subject identity was.

  The claim proved here is therefore the general one: a record gates a tree
  only when its subject IS that tree, recency is orthogonal to readability,
  and a reader that ranks by recency alone can pass a gate the target never
  earned. Freshness-by-time falls out as the special case where the subject
  happens to be timestamped.

  This is deliberately NOT recorded as a tenth defect family. It is FAMILY 7
  (Stale) on a second axis, and inflating the taxonomy to score a finding
  would be exactly the over-purification the compendium warns about.
-/

import Proofs.RotVacuousGate

namespace RotMoE.Subject

open RotMoE.Vacuity
open Verdict

/-- An opaque identifier for a tree under test: a commit, a branch, a checkout. -/
abbrev Tree := Nat

/-- A record produced by some external run: what it was about, when, and what
    it concluded. `stamp` is a monotone clock; only its ORDER is used. -/
structure Record where
  subject : Tree
  stamp   : Nat
  verdict : Verdict
  deriving DecidableEq, Repr

/-- A gate is asking a question about one specific tree. -/
structure Gate where
  target : Tree
  deriving DecidableEq, Repr

/-- The record speaks about the tree the gate is asking about. -/
def describes (r : Record) (g : Gate) : Prop := r.subject = g.target

/-- The sound reader. A record that does not describe the target carries no
    information about it, and absence must read RED -- never green, never a
    silent pass. -/
def gateVerdict (r : Record) (g : Gate) : Verdict :=
  if r.subject = g.target then r.verdict else red

/-- The recency reader: of two records, take the newer. Subject is not
    consulted. This is what "the newest completed CI run" means. -/
def newer (a b : Record) : Record :=
  if b.stamp > a.stamp then b else a

/-- A verdict formed by recency alone. -/
def freshVerdict (a b : Record) : Verdict := (newer a b).verdict

/-! ### The core separation -/

/-- A record about another tree reads RED, whatever it concluded. -/
theorem a_record_about_another_tree_reads_red
    (r : Record) (g : Gate) (h : r.subject ≠ g.target) :
    gateVerdict r g = red := by
  simp [gateVerdict, h]

/-- The sharp instance, stated so that it USES the greenness rather than
    decorating itself with it. Reading a foreign green through the gate does
    not merely fail to help -- it INVERTS: the record says green, the gate
    says red, and the two are genuinely different answers.

    (The first draft of this theorem concluded `gateVerdict r g = red` with
    `r.verdict = green` as an unused hypothesis, which made it strictly weaker
    than the universally-quantified theorem above and taught nothing. The
    linter caught it. Same finding as `RotObserverEffect`: a hypothesis that
    the proof never touches is a claim the theorem is not making.) -/
theorem a_foreign_green_is_inverted_by_the_gate
    (r : Record) (g : Gate) (h : r.subject ≠ g.target) (hv : r.verdict = green) :
    gateVerdict r g ≠ r.verdict := by
  simp [gateVerdict, h, hv]

/-- Recency is orthogonal to readability: NO timestamp makes a foreign record
    speak about the target. This is the general form -- quantified over every
    possible stamp, not demonstrated on one. -/
theorem no_stamp_repairs_a_foreign_record
    (s : Tree) (v : Verdict) (g : Gate) (h : s ≠ g.target) :
    ∀ n : Nat, gateVerdict ⟨s, n, v⟩ g = red := by
  intro n
  simp [gateVerdict, h]

/-- Dually, the subject alone decides transmission: the stamp never enters the
    verdict of a matching record. -/
theorem the_stamp_never_enters_a_matching_verdict
    (s : Tree) (v : Verdict) (m n : Nat) (g : Gate) (h : s = g.target) :
    gateVerdict ⟨s, m, v⟩ g = gateVerdict ⟨s, n, v⟩ g := by
  simp [gateVerdict, h]

/-! ### The witness: recency can pass a gate the target never earned -/

/-- Tree 0 is `main`; tree 1 is this branch. -/
def ourGate : Gate := ⟨1⟩

/-- A newer record about ANOTHER tree, which concluded green. -/
def foreignNewGreen : Record := ⟨0, 100, green⟩

/-- An older record about OUR tree, which concluded red. -/
def ourOldRed : Record := ⟨1, 50, red⟩

/-- The recency reader returns GREEN here: it picked the newer record and
    never asked what it was about. -/
theorem recency_passes_a_gate_the_target_never_earned :
    freshVerdict foreignNewGreen ourOldRed = green := by decide

/-- The sound reader refuses the very same input, because the newer record is
    about a different tree. -/
theorem the_sound_reader_refuses_that_same_input :
    gateVerdict (newer foreignNewGreen ourOldRed) ourGate = red := by decide

/-- Stated as the separation itself: on this input the two readers disagree,
    and the recency reader is the one that is wrong. -/
theorem the_two_readers_disagree :
    freshVerdict foreignNewGreen ourOldRed
      ≠ gateVerdict (newer foreignNewGreen ourOldRed) ourGate := by decide

/-! ### Freshness is the special case, not the law -/

/-- When BOTH records already describe the target, recency is sound: ranking
    by stamp cannot then select a foreign subject, because there is none. This
    is exactly the ground on which a freshness law is valid -- and it is an
    assumption about subject, not about time. -/
theorem recency_is_sound_only_once_the_subject_is_fixed
    (a b : Record) (g : Gate) (ha : describes a g) (hb : describes b g) :
    gateVerdict (newer a b) g = freshVerdict a b := by
  unfold describes at ha hb
  by_cases hc : b.stamp > a.stamp
  · simp [gateVerdict, newer, freshVerdict, hc, hb]
  · simp [gateVerdict, newer, freshVerdict, hc, ha]

/-- The measured situation: this branch has never been pushed, so NO record
    about it exists. Every available record is foreign, so the gate reads red
    no matter which one is offered, and no amount of re-running CI on the
    other tree can change that. -/
theorem an_unpushed_tree_has_no_readable_record
    (g : Gate) (rs : List Record) (h : ∀ r ∈ rs, r.subject ≠ g.target) :
    ∀ r ∈ rs, gateVerdict r g = red := by
  intro r hr
  exact a_record_about_another_tree_reads_red r g (h r hr)

/-! ### The control -/

/-- CONTROL. The gate is not stuck at red: a record that genuinely describes
    the target transmits its green. An instrument that cannot return green is
    not discerning, it is broken, and this theorem is what rules that out. -/
theorem the_gate_can_return_green :
    gateVerdict ⟨1, 7, green⟩ ourGate = green := by decide

/-- CONTROL, second arm. A matching record that concluded red transmits its
    red too -- so the green above is the subject speaking, not the reader
    defaulting. -/
theorem a_matching_red_transmits_as_red :
    gateVerdict ⟨1, 7, red⟩ ourGate = red := by decide

end RotMoE.Subject
