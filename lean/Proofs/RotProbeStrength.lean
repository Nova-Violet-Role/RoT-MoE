/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A probe weaker than the obligation it names is a gate that opens on nothing

`checker/push-guard.sh` refuses every push until six obligations are met. Written
last week, mutation-tested, four controls, and one commit later it was still
**openable by a one-line file** — because four of its six probes check only that a
file is *non-empty* while their names promise a *count*:

    corpus40           | the 40-task corpus exists | test -s bench/corpus-40.jsonl
    sessions160        | 160 sessions collected    | test -s bench/sessions-160.done
    preferenceMeasured | a preference panel has run| test -s bench/panel-results.jsonl
    p22Established     | P2.2 established          | test -s bench/P22-ESTABLISHED.md

`echo x > bench/corpus-40.jsonl` satisfies "the 40-task corpus exists". The guard
would then report that obligation MET, and the only thing standing between an
unfulfilled promise and a push would be five more equally weak tests.

This is the more dangerous half of the overclaim family. A theorem that says too
little fails *loudly* when someone leans on it. A **probe** that says too little
fails *silently and in the permissive direction*: it reports success, the gate
opens, and the guarantee everyone believed in was never tested. It is the same
defect as a mutation that does not apply being scored SURVIVED.

## What is proved here

`sound` is the only property that matters for a gate: everything the probe accepts
really does meet the demand. `nonEmpty_cannot_witness_a_counted_obligation` shows
that a non-emptiness test is unsound for **every** obligation demanding two or more
— not just for 40, and not as a fact about today's ledger.

The converse is proved too, deliberately.
`an_inflated_probe_refuses_a_finished_obligation` shows a probe demanding *more*
than the obligation is not `complete`: it would refuse a promise that had actually
been kept. A gate that can never open is not a safeguard, it is a wall, and the
first person to finish the work deletes it. Only `atLeast o.required` is both.

The three rows whose obligation is genuinely "one artifact exists" —
`preferenceMeasured`, `p22Established`, `verifyRunOnMain` — are **correctly**
served by a non-emptiness test, and the theorems say so rather than sweeping all
six into one verdict. Precision here is the difference between a repair and a
panic.
-/

namespace RotMoE.ProbeStrength

/-! ## Obligations and the probes that claim to witness them -/

/-- An obligation naming how much evidence it demands. `required = 1` means "one
artifact exists"; `required = 40` means forty of something. -/
structure Obligation where
  name : String
  required : Nat
deriving DecidableEq, Repr

/-- The two probe shapes the shipped ledger actually uses. `nonEmpty` is `test -s`;
`atLeast n` is the `wc -l ... -ge n` form. -/
inductive Probe
  | nonEmpty
  | atLeast (n : Nat)
deriving DecidableEq, Repr

/-- What a probe accepts, as a function of how much evidence is really present. -/
def accepts : Probe → Nat → Bool
  | .nonEmpty, k => 1 ≤ k
  | .atLeast n, k => n ≤ k

/-- **Soundness — the property a gate needs.** Everything the probe accepts truly
meets the obligation. An unsound probe opens the gate on evidence that is not
there. -/
def sound (p : Probe) (o : Obligation) : Prop :=
  ∀ k, accepts p k = true → o.required ≤ k

/-- **Completeness — the property that keeps a gate honest.** Every state that
really meets the obligation is accepted. An incomplete probe refuses work that was
genuinely finished. -/
def complete (p : Probe) (o : Obligation) : Prop :=
  ∀ k, o.required ≤ k → accepts p k = true

/-! ## The counted probe is exactly right; the two failure modes are not -/

/-- Counting to the demand is sound. -/
theorem atLeast_is_sound (o : Obligation) : sound (Probe.atLeast o.required) o := by
  intro k hk
  simpa [accepts] using hk

/-- Counting to the demand is also complete — it refuses nothing that was earned. -/
theorem atLeast_is_complete (o : Obligation) : complete (Probe.atLeast o.required) o := by
  intro k hk
  simpa [accepts] using hk

/-- **The defect.** A non-emptiness test cannot witness any obligation demanding
two or more. Stated over every such obligation, so it is a fact about the probe
shape and not about the number 40. -/
theorem nonEmpty_cannot_witness_a_counted_obligation
    (o : Obligation) (h : 2 ≤ o.required) : ¬ sound Probe.nonEmpty o := by
  intro hs
  have h1 : o.required ≤ 1 := hs 1 (by decide)
  omega

/-- **The opposite failure, proved so the repair does not overshoot.** A probe
demanding more than the obligation refuses a promise that was actually kept. This
is the dated-spec hazard: such a gate goes red on correct work, and the obvious
"fix" is to delete it. -/
theorem an_inflated_probe_refuses_a_finished_obligation (o : Obligation) :
    ¬ complete (Probe.atLeast (o.required + 1)) o := by
  intro hc
  have h1 : accepts (Probe.atLeast (o.required + 1)) o.required = true :=
    hc o.required (Nat.le_refl _)
  have h2 : o.required + 1 ≤ o.required := by simpa [accepts] using h1
  omega

/-- Non-emptiness IS the right probe when the obligation is "one artifact exists".
Three of the six rows are in exactly this position, and they are not defects. -/
theorem nonEmpty_is_sound_for_a_single_artifact
    (o : Obligation) (h : o.required ≤ 1) : sound Probe.nonEmpty o := by
  intro k hk
  have : 1 ≤ k := by simpa [accepts] using hk
  omega

/-! ## The ledger, checkable -/

/-- A decidable check that a probe is strong enough for its obligation. -/
def probeSound (o : Obligation) : Probe → Bool
  | .nonEmpty => o.required ≤ 1
  | .atLeast n => o.required ≤ n

/-- The syntactic check really does imply the semantic property. Without this
bridge the `#guard`s below would only be checking a spelling. -/
theorem probeSound_implies_sound (o : Obligation) (p : Probe)
    (h : probeSound o p = true) : sound p o := by
  cases p with
  | nonEmpty =>
    intro k hk
    have h' : o.required ≤ 1 := by simpa [probeSound] using h
    have hk' : 1 ≤ k := by simpa [accepts] using hk
    omega
  | atLeast n =>
    intro k hk
    have h' : o.required ≤ n := by simpa [probeSound] using h
    have hk' : n ≤ k := by simpa [accepts] using hk
    omega

abbrev Row := Obligation × Probe

def rowSound (r : Row) : Bool := probeSound r.1 r.2

def ledgerOk (rows : List Row) : Bool := rows.all rowSound

/-- The ledger as `checker/push-guard.sh` shipped it before this repair. -/
def shippedLedger : List Row :=
  [({ name := "corpus40",           required := 40  }, .nonEmpty),
   ({ name := "pilot12Pairs",       required := 12  }, .atLeast 12),
   ({ name := "sessions160",        required := 160 }, .nonEmpty),
   ({ name := "preferenceMeasured", required := 1   }, .nonEmpty),
   ({ name := "p22Established",     required := 1   }, .nonEmpty),
   ({ name := "verifyRunOnMain",    required := 1   }, .nonEmpty)]

/-- The same ledger with the two counted rows given counting probes. -/
def repairedLedger : List Row :=
  [({ name := "corpus40",           required := 40  }, .atLeast 40),
   ({ name := "pilot12Pairs",       required := 12  }, .atLeast 12),
   ({ name := "sessions160",        required := 160 }, .atLeast 160),
   ({ name := "preferenceMeasured", required := 1   }, .nonEmpty),
   ({ name := "p22Established",     required := 1   }, .nonEmpty),
   ({ name := "verifyRunOnMain",    required := 1   }, .nonEmpty)]

#guard shippedLedger.length = 6
#guard repairedLedger.length = 6
#guard ledgerOk shippedLedger = false
#guard ledgerOk repairedLedger = true
-- one line of evidence satisfies the shipped corpus probe, and 1 < 40
#guard accepts Probe.nonEmpty 1 = true
#guard accepts (Probe.atLeast 40) 1 = false

/-- **The shipped ledger did not pass its own check.** -/
theorem the_shipped_ledger_was_not_sound : ledgerOk shippedLedger = false := by decide

/-- **The repaired one does.** -/
theorem the_repaired_ledger_is_sound : ledgerOk repairedLedger = true := by decide

/-- **The repair changed only what was broken.** Every row the old ledger got right
is still exactly the same row — a repair that rewrote the sound rows too would be
a rewrite, not a fix. -/
theorem the_repair_left_the_sound_rows_alone :
    shippedLedger.drop 3 = repairedLedger.drop 3
      ∧ shippedLedger[1]? = repairedLedger[1]? := by decide

/-- **Every obligation is still present after the repair**, in the same order —
strengthening a probe must not quietly drop a row. -/
theorem the_repair_kept_every_obligation :
    shippedLedger.map Prod.fst = repairedLedger.map Prod.fst := by decide

/-- **The check is not vacuous**: it rejects something. -/
theorem the_ledger_check_can_fail : ∃ l : List Row, ledgerOk l = false :=
  ⟨shippedLedger, the_shipped_ledger_was_not_sound⟩

/-- **And it can pass**, so it is not a wall either. -/
theorem the_ledger_check_can_pass : ∃ l : List Row, ledgerOk l = true :=
  ⟨repairedLedger, the_repaired_ledger_is_sound⟩

/-- **The concrete hole, named.** One line of evidence was accepted by the shipped
`corpus40` probe while the obligation demands forty. -/
theorem one_line_opened_the_forty_task_gate :
    accepts Probe.nonEmpty 1 = true ∧ ¬ (40 ≤ 1) := by decide

/-- **A ledger that passes the check is sound row by row, semantically.** Stated
over *every* ledger rather than the current one, so tomorrow's seventh obligation
inherits the guarantee instead of needing a new theorem. -/
theorem every_row_of_a_checked_ledger_is_sound
    (rows : List Row) (hl : ledgerOk rows = true) (r : Row) (h : r ∈ rows) :
    sound r.2 r.1 :=
  probeSound_implies_sound r.1 r.2 (List.all_eq_true.mp hl r h)

/-- The repaired ledger, as an instance of that. -/
theorem every_repaired_row_is_semantically_sound
    (r : Row) (h : r ∈ repairedLedger) : sound r.2 r.1 :=
  every_row_of_a_checked_ledger_is_sound repairedLedger (by decide) r h

end RotMoE.ProbeStrength
