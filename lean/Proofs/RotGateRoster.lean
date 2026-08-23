/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

  RotGateRoster -- a suite verdict is about the gates that RAN, and the runner
  never checked that those were the gates it registered.

  MEASURED, 2026-08-19, branch 9.0.0, the first full sweep ever run on it:

    registered rows   83   (73 in the default block + 10 added under --full)
    rows executed     77
    difference         6
    runner said       "2 of 77 GATES RED"

  Six registered gates never ran. Nothing printed. The suite named its own
  denominator -- 77 -- from the gates it happened to reach, so the six that
  vanished could not appear as missing in a total computed from what arrived.

  The cause is mechanical and reproduced in isolation. The runner drives its
  gate list with a `while read` loop fed by a heredoc, and executes each gate as

      sh -c "$cmd" > "$LOGDIR/$ran.log" 2>&1

  which redirects stdout and stderr and leaves STDIN attached to the heredoc.
  A gate whose command reads stdin therefore consumes the remaining gate rows.
  Four rows, one of them a `cat`, reproduce it exactly: RAN=2, no error. The
  same list with `< /dev/null` per gate runs all four.

  `< /dev/null` fixes THIS cause. It does not fix the class: any future gate
  that consumes the list, any `break` on an unexpected field, any parse that
  drops a row, truncates the run again and is again invisible, because the
  verdict is computed from the survivors. The durable repair is to make the
  roster a bound the run must satisfy rather than a list it happens to walk.

  That is what this module states. `verdict` is the rule as written: it reads
  the red count and nothing else. `verdictChecked` refuses any run whose ran
  plus skipped does not equal the roster it was given.

  The distinction this rests on: a skipped gate is DECLARED -- the runner knows
  it exists, names it, and counts it out. A truncated gate is not skipped. It is
  absent from the arithmetic entirely, and absence must read red or it reads
  green, which is the law this repository already carries from
  Proofs/RotFreshness.lean.
-/

import Proofs.RotVacuousGate

namespace RotMoE.Roster

open RotMoE.Vacuity
open Verdict

/-- One run of the suite, in the four numbers it actually tracks. -/
structure Run where
  registered : Nat
  ran : Nat
  skipped : Nat
  red : Nat
deriving DecidableEq, Repr

/-- Every registered gate is accounted for: it ran, or it was declared skipped.
There is no third bucket, and in particular no bucket for "was never reached". -/
def Accounted (r : Run) : Prop := r.ran + r.skipped = r.registered

/-- The rule as written. The roster is not an input. -/
def verdict (r : Run) : Verdict :=
  if r.red = 0 then green else red

/-- The repair: the roster is a precondition, not a footnote. -/
def verdictChecked (r : Run) : Verdict :=
  if r.ran + r.skipped = r.registered then (if r.red = 0 then green else red) else red

/-- The measured run: 83 registered, 77 reached, 4 declared skips, 2 red. -/
def theFullSweep : Run := ⟨83, 77, 4, 2⟩

/-- THE DEFECT. A run that never reached six of its gates can report green,
because the rule as written cannot see the roster. -/
theorem a_truncated_run_can_report_green :
    ∃ r : Run, ¬ Accounted r ∧ verdict r = green := by
  refine ⟨⟨83, 77, 0, 0⟩, ?_, rfl⟩
  show ¬(77 + 0 = 83)
  omega

/-- Worse than reportable: truncation is not even visible. A run that reached
every gate and a run that lost six are the same verdict, because the denominator
is computed from the survivors. -/
theorem truncation_is_invisible_in_the_verdict :
    verdict ⟨83, 77, 0, 0⟩ = verdict ⟨77, 77, 0, 0⟩ := rfl

/-- The checked rule refuses the truncated run. -/
theorem checked_verdict_refuses_a_truncated_run :
    verdictChecked ⟨83, 77, 0, 0⟩ = red := rfl

/-- Universally: no unaccounted run passes, whatever its red count. -/
theorem an_unaccounted_run_is_always_red (r : Run) (h : ¬ Accounted r) :
    verdictChecked r = red := by
  unfold Accounted at h
  unfold verdictChecked
  rw [if_neg h]

/-- And it is not a blanket red. When the roster balances, the checked rule is
exactly the old rule -- this adds a precondition, it does not change a verdict
that was already entitled to be green. -/
theorem checked_agrees_when_every_gate_is_accounted (r : Run) (h : Accounted r) :
    verdictChecked r = verdict r := by
  unfold Accounted at h
  unfold verdictChecked verdict
  rw [if_pos h]

/-- A balanced run still reaches green. -/
theorem a_balanced_run_still_passes :
    verdictChecked ⟨77, 77, 0, 0⟩ = green := rfl

/-- The sweep that was actually measured does NOT balance: 77 + 4 = 81, not 83.
Its red verdict was right by accident -- two gates happened to fail. Had those
two been green, the run would have reported ALL GREEN while six gates had never
executed. -/
theorem the_measured_sweep_did_not_balance : ¬ Accounted theFullSweep := by
  show ¬(77 + 4 = 83)
  omega

/-- The accident, stated so it cannot be mistaken for a pass: the same roster
gap with a clean red count reports green. -/
theorem the_measured_gap_would_have_reported_green :
    verdict ⟨83, 77, 4, 0⟩ = green ∧ verdictChecked ⟨83, 77, 4, 0⟩ = red :=
  ⟨rfl, rfl⟩

end RotMoE.Roster
