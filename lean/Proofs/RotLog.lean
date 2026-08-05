/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Proofs.RotGauge

/-! # The debug log, formalized — a record that can be re-derived, or it is decoration

`ROTMOE_DEBUG_LOG` makes both router arms append one JSON line per gauge
computation and one per routed turn. The gauge line carries **every factor of the
sum**: `K`, `mean`, `breadth`, `M`, `C`, `T`, the per-lens `lambda`, `mu`, `a`,
`delta`, `sigma`, `H`, `term`, then `sum` and `Rs`.

That shape was chosen deliberately — `rot-router.sh` says so in its own comment:
*"one JSON line carrying every factor of the sum, so the reported R/s+ can be
recomputed by hand from the record."*

**And nothing ever recomputed it.** The log was written, never read, never
checked — measured: no checker in `checker/` opened `ROTMOE_DEBUG_LOG` before
0.7.0. A record whose stated purpose is to be re-derivable, and which nobody
re-derives, is decoration: it can drift from the number it claims to explain and
every gate stays green.

This module states what makes such a record *evidence*, and
`checker/log-replay.sh` is the instrument that enforces it against real logs
produced by both arms.

**The central idea.** A gauge record is not a report, it is a **claim with its own
proof attached**. If the per-lens terms in the line are the model's terms, and the
line's own `sum` and `Rs` relate to them as stated, then `Rs` is *determined* —
there is exactly one value it can honestly hold. So an edited, stale or truncated
`Rs` is not a matter of trust; it is arithmetically detectable from the line
itself.

**What is NOT modelled.** JSON syntax, decimal rounding, and whether the shipped
`awk` and PowerShell actually emit these fields. Lean cannot read a log file.
`checker/log-replay.sh` parses real records from both arms and recomputes every
field with an explicit tolerance; that tolerance is a checker concern precisely
because it is about decimal text, not about arithmetic.
-/

namespace RotMoE.Log

-- `RotGauge.lean` puts its gauge model directly in `RotMoE`, not in a `Gauge`
-- sub-namespace. Opening the parent is what binds this module to THAT model
-- rather than to a re-declared copy of it -- a second definition of `term` here
-- would let the log spec and the gauge spec drift apart silently, which is the
-- whole failure mode this file exists to close.
open RotMoE

variable {ι : Type*} [Fintype ι]

/-! ## A gauge record -/

/-- One `{"kind":"gauge",...}` line, reduced to the fields that carry arithmetic.
`terms` is the `lenses[].term` array; `sum` and `Rs` are the line's own claims
about them. -/
structure GaugeRec (ι : Type*) where
  K : ℕ
  sum : ℝ
  Rs : ℝ
  terms : ι → ℝ

/-- **What it means for a record to be self-consistent.** Three clauses, each one
a thing the checker actually asserts against a parsed line:

* `K` is the number of lenses, not a literal — the same rule `gauge` follows;
* `sum` is the sum of the per-lens terms the line itself lists;
* `Rs * K = sum`, written as a product so the statement carries no division and
  therefore no hidden `K ≠ 0` side condition.

A line failing any clause is corrupt *on its own evidence*, with no need to know
what the router was doing at the time. -/
def GaugeRec.Consistent (r : GaugeRec ι) : Prop :=
  r.K = Fintype.card ι ∧ r.sum = ∑ i, r.terms i ∧ r.Rs * (r.K : ℝ) = r.sum

/-- **A self-consistent record whose terms are the model's terms reports exactly
the gauge.** This is the theorem that makes the log evidence rather than a
souvenir: `Rs` is not trusted, it is *derived*, and any other value contradicts
the line's own fields. -/
theorem consistent_Rs_eq_gauge [Nonempty ι] (L : ι → Lens) (a : ι → Bool)
    (breadth : ℕ) (M C T : ℝ) (r : GaugeRec ι)
    (hc : r.Consistent) (ht : ∀ i, r.terms i = term L a breadth M C T i) :
    r.Rs = gauge L a breadth M C T := by
  obtain ⟨hK, hsum, hRs⟩ := hc
  have hcard : (0 : ℝ) < (Fintype.card ι : ℝ) := by exact_mod_cast Fintype.card_pos
  have h1 : r.Rs * (Fintype.card ι : ℝ) = ∑ i, term L a breadth M C T i := by
    rw [← hK, hRs, hsum]
    exact Finset.sum_congr rfl (fun i _ => ht i)
  unfold gauge
  rw [← h1, mul_div_assoc, div_self (ne_of_gt hcard), mul_one]

/-- **Two consistent records over the same terms cannot disagree.** The
determinism the checker relies on when it compares the POSIX arm's line against
the PowerShell arm's line for one input: if they disagree on `Rs`, at least one of
them is not consistent with its own terms — there is no third possibility such as
"a different but equally valid reading". -/
theorem consistent_Rs_unique [Nonempty ι] (r s : GaugeRec ι)
    (hr : r.Consistent) (hs : s.Consistent) (h : ∀ i, r.terms i = s.terms i) :
    r.Rs = s.Rs := by
  obtain ⟨hrK, hrsum, hrRs⟩ := hr
  obtain ⟨hsK, hssum, hsRs⟩ := hs
  have hcard : (0 : ℝ) < (Fintype.card ι : ℝ) := by exact_mod_cast Fintype.card_pos
  have hsum : r.sum = s.sum := by
    rw [hrsum, hssum]; exact Finset.sum_congr rfl (fun i _ => h i)
  have : r.Rs * (Fintype.card ι : ℝ) = s.Rs * (Fintype.card ι : ℝ) := by
    rw [← hrK, hrRs, hsum, ← hsRs, hsK, hrK]
  exact mul_right_cancel₀ (ne_of_gt hcard) this

/-- **A record that claims a sum its own terms do not add up to is not
consistent** — the negative control, and the reason `Consistent` is not
vacuously true of everything. Without a witness like this, a predicate that held
of every record would make every theorem above worthless. -/
theorem inconsistent_witness :
    ∃ (r : GaugeRec (Fin 1)), ¬ r.Consistent := by
  refine ⟨⟨1, 5, 5, fun _ => 1⟩, ?_⟩
  rintro ⟨-, hsum, -⟩
  norm_num at hsum

/-! ## The one-hot vector a routed turn actually writes

The hook does not invent a lens activity profile — it writes *this turn's routing
decision in the gauge's own units*: the lead lens of the lane that fired at 1,
every other lens at 0, breadth 1. So a route record's activity vector is always
one-hot, and a CONVERGENT turn's is always all-quiet. Those are the only two
shapes the router can legitimately produce, which is a rule a log checker can
enforce. -/

/-- The activity vector of a routed turn: exactly the lead lens fired. -/
def oneHot [DecidableEq ι] (j : ι) : ι → Bool := fun i => i == j

theorem sum_actR_oneHot [DecidableEq ι] (j : ι) :
    (∑ i, actR (oneHot j) i) = 1 := by
  simp [actR, oneHot]

/-- **A routed turn's mean activity is exactly `1/K`.** The log line reports
`mean`; this is the only value it can hold for a lane that fired, so a record
claiming anything else is either not a routed turn or is corrupt. -/
theorem meanAct_oneHot [DecidableEq ι] [Nonempty ι] (j : ι) :
    meanAct (oneHot j) = 1 / (Fintype.card ι : ℝ) := by
  unfold meanAct
  rw [sum_actR_oneHot]

/-- **A route record can never honestly carry `Rs = 0`.**

`R/s+ = 0.0` is named a violation by the engine specification — "a placeholder
never computed". Here it is not a rule of etiquette but a consequence: with
positive weights the gauge is strictly positive for *every* activity vector, so a
zero in a route record means the number was never computed. That is a check a log
replayer can run on a line in isolation. -/
theorem route_Rs_ne_zero [Nonempty ι] {L : ι → Lens} {M C T : ℝ}
    (h : PosWeights L M C T) (a : ι → Bool) (breadth : ℕ) :
    gauge L a breadth M C T ≠ 0 :=
  ne_of_gt (gauge_pos h a breadth)

/-! ## Pairing — one gauge line per routed turn

Both arms emit the gauge line first and the route line second, carrying the same
`Rs`. A truncated log — the common case, since the write is appended with `>>`
and any failure is swallowed so that logging can never break a turn — shows up as
a route line with no gauge line before it. That is worth detecting: it is exactly
the state in which a reader would take an unverifiable number at face value. -/

/-- A log line, reduced to its kind and its `Rs`. -/
inductive Rec where
  | gauge (rs : ℝ)
  | route (rs : ℝ)

/-- Every route line is immediately preceded by a gauge line carrying the **same
reading to within `ε`**.

**`ε` is here because the first version of this spec was wrong, and the checker
caught it on its first run.** The pairing condition was written as `g = r`, plain
equality. The shipped router does not do that: the gauge line carries the full
reading (`"Rs":0.66427`) while the route line carries the **displayed** one
(`"Rs":"0.66"`), matching the marker the operator actually sees. Twelve records
from each arm recomputed field for field — mean, delta, sigma, H, term, sum, Rs
all exact — and the only disagreement was this rounding, which the spec had
forbidden.

That is a spec defect, not a code defect, and it is the dangerous kind: a
theorem that says more than the program does, going red on correct behaviour and
inviting someone to "fix" the program to match the spec. The honest statement is
the one with the tolerance in it, and `ε = 1/200` — half of the last displayed
digit — is not a fudge factor: it is the exact half-ulp of a two-decimal display,
so a route line further than that from its gauge line **cannot have been rounded
from it**. Tampering is still caught; rounding is not called tampering.

Quantified over `ε` rather than fixed at `1/200`, because the display precision
is a presentation choice this project may change on purpose. -/
def WellPaired (ε : ℝ) : List Rec → Prop
  | [] => True
  | (Rec.route _) :: _ => False
  | (Rec.gauge g) :: (Rec.route r) :: rest => |g - r| ≤ ε ∧ WellPaired ε rest
  | (Rec.gauge _) :: rest => WellPaired ε rest

/-- Half the last digit of a two-decimal display: the largest gap that rounding
alone can produce. `noncomputable` because real division is — which is exactly
why the checker does this arithmetic in `node` with an explicit tolerance and
Lean states only the rule. -/
noncomputable def displayEps : ℝ := 1 / 200

/-- What one routed turn appends: the full reading, then the displayed one. -/
def emit (rs disp : ℝ) : List Rec := [Rec.gauge rs, Rec.route disp]

/-- **A turn's own emission is well paired, exactly when the displayed value is a
faithful rounding of the reading.** The hypothesis is the whole content: an
emission whose route line does not round-trip to its gauge line is *not*
accepted, which is what keeps this from being satisfied by any pair of numbers. -/
theorem emit_wellPaired (rs disp ε : ℝ) (h : |rs - disp| ≤ ε) :
    WellPaired ε (emit rs disp) := by
  simp [emit, WellPaired, h]

/-- **Appending a turn to a well-paired log keeps it well paired** — so a log
built only by this router is well paired however many turns it has, without being
re-examined as a whole. -/
theorem emit_append_wellPaired (rs disp ε : ℝ) (l : List Rec)
    (h : |rs - disp| ≤ ε) (hl : WellPaired ε l) :
    WellPaired ε (emit rs disp ++ l) := by
  simp [emit, WellPaired, h, hl]

/-- **A truncated log is detected.** The real failure mode: the gauge line was
lost (a swallowed write, a rotated file, a partial copy) and only the route line
survives, still carrying a number that now rests on nothing. Holds for every
tolerance, including a generous one — no `ε` makes an orphan acceptable. -/
theorem orphan_route_detected (rs ε : ℝ) : ¬ WellPaired ε [Rec.route rs] := by
  simp [WellPaired]

/-- **A disagreeing pair is detected at the display tolerance.** `0` against `1`
is three hundred times the half-ulp: the shape a stale or hand-edited log has,
never the shape rounding produces. -/
theorem mismatched_pair_detected :
    ¬ WellPaired displayEps [Rec.gauge 0, Rec.route 1] := by
  simp [WellPaired, displayEps]
  norm_num

/-- **An honest rounding is ACCEPTED at the same tolerance.** This is the theorem
that stops the tolerance from being tightened back to equality by someone who
reads `mismatched_pair_detected` alone: the real measured pair
`0.66427 / 0.66` must pass, and it does. -/
theorem measured_rounding_accepted :
    WellPaired displayEps (emit 0.66427 0.66) := by
  apply emit_wellPaired
  rw [abs_le]
  constructor <;> norm_num [displayEps]

/-- **The predicate discriminates** — it accepts the honest log, accepts an
honest rounding, and rejects both corruptions. Stated as one theorem so the
controls cannot be half-deleted without a red build. -/
theorem wellPaired_discriminates :
    WellPaired displayEps (emit 0.66427 0.66) ∧
      (∀ rs : ℝ, ¬ WellPaired displayEps [Rec.route rs]) ∧
      ¬ WellPaired displayEps [Rec.gauge 0, Rec.route 1] :=
  ⟨measured_rounding_accepted, fun rs => orphan_route_detected rs displayEps,
   mismatched_pair_detected⟩


/-! ## §4 The stem is the reason — routing becomes auditable from the log alone

Everything above audits the **gauge**: a `gauge` record carries every factor of
its own sum, so the reported `R/s+` can be recomputed and a corrupted one is
rejected. The `route` record had no such property, and the gap was not academic.

Measured by trying to diagnose a mis-route from a log: the record carried
`lane`, `lens`, `Rs`, `chars` and `arm`. Every field can be checked and **none of
them explains the decision.** A user reporting "my proof prompt routed
CONVERGENT" could hand over a complete, valid, fully-replayable log in which the
one thing under dispute — *why that lane* — is absent. `chars` is the prompt's
length precisely because the text must never enter the log, and that choice,
which is right, is what left routing unfalsifiable.

`hooks/rot-router.sh:139` and `hooks/rot-router.ps1:129` now return
`"<LANE LENS>|<matched stem>"`, and the route record carries `stem`. A stem is
the missing datum and it is the ONLY safe one: stems come from a closed table
written in the router itself, so recording one leaks nothing about the user's
text beyond which fixed vocabulary word occurred — which is exactly the routing
decision, and nothing more.

The theorem that makes this more than a new field is `auditable_imp_vocabSafe`:
**a record cannot pass the audit while carrying text that is not a stem.** The
privacy property is not a second check bolted on beside the correctness one and
liable to be dropped — it is implied by it. -/

namespace Stemlog

/-- A lane's stem table: the lane name and the stems it owns, in priority order.
Quoted from `hooks/rot-router.sh:57-65`; the ps1 arm's `$Tier1` is the same list
and `checker/cross-diff.sh` is what keeps the two honest. -/
abbrev Table := List (String × List String)

/-- One routed turn as the log now records it. `chars` and `ts` are omitted:
they are real fields, and neither participates in this property. Modelling them
here would be decoration. -/
structure RouteRec where
  lane : String
  stem : String
  deriving DecidableEq, Repr

/-- The router's decision, replayed from the table. `find?` returns the FIRST
lane owning the stem, which is what makes the priority order load-bearing rather
than cosmetic. -/
def laneOfStem (t : Table) (s : String) : Option String :=
  (t.find? (fun p => p.2.contains s)).map Prod.fst

/-- Every stem the router can possibly emit. -/
def vocab (t : Table) : List String := t.flatMap Prod.snd

/-- A record is **auditable** when its stem explains its lane: an empty stem
means no table fired, which is CONVERGENT and nothing else; a non-empty stem must
be owned by the lane that was recorded. -/
def Auditable (t : Table) (r : RouteRec) : Prop :=
  if r.stem = "" then r.lane = "CONVERGENT" else laneOfStem t r.stem = some r.lane

/-- The privacy property, stated as a predicate so it can be compared with the
correctness one rather than asserted beside it. -/
def VocabSafe (t : Table) (r : RouteRec) : Prop :=
  r.stem = "" ∨ r.stem ∈ vocab t

instance (t : Table) (r : RouteRec) : Decidable (Auditable t r) := by
  unfold Auditable; infer_instance

instance (t : Table) (r : RouteRec) : Decidable (VocabSafe t r) := by
  unfold VocabSafe; infer_instance

/-- A stem that resolves to a lane is a member of that lane's list. The bridge
from `find?` back to membership, and the lemma everything else leans on. -/
theorem laneOfStem_sound {t : Table} {s l : String} (h : laneOfStem t s = some l) :
    ∃ ss : List String, (l, ss) ∈ t ∧ s ∈ ss := by
  unfold laneOfStem at h
  cases hf : t.find? (fun p => p.2.contains s) with
  | none => rw [hf] at h; simp at h
  | some p =>
    rw [hf] at h
    simp only [Option.map_some] at h
    have hmem := List.mem_of_find?_eq_some hf
    have hcond := List.find?_some hf
    have hl : l = p.1 := (Option.some.inj h).symm
    subst hl
    exact ⟨p.2, by simpa using hmem, by simpa using hcond⟩

/-- **The audit implies the privacy property.** A record cannot be certified
correct while its `stem` carries text the router could never have produced — so
the log's safety to paste into a public issue is not a separate check that could
be dropped, it is a consequence of the one that certifies the routing. -/
theorem auditable_imp_vocabSafe (t : Table) (r : RouteRec) (h : Auditable t r) :
    VocabSafe t r := by
  unfold Auditable at h
  by_cases hs : r.stem = ""
  · exact Or.inl hs
  · rw [if_neg hs] at h
    obtain ⟨ss, hss, hin⟩ := laneOfStem_sound h
    exact Or.inr (List.mem_flatMap.mpr ⟨(r.lane, ss), hss, hin⟩)

/-- The converse fails, which is why the audit is the stronger check: a stem can
be perfectly in-vocabulary and still be attached to the wrong lane. This is the
mis-route the log previously could not express at all. -/
theorem vocabSafe_not_imp_auditable :
    ∃ (t : Table) (r : RouteRec), VocabSafe t r ∧ ¬ Auditable t r := by
  refine ⟨[("FORGE", ["prove"]), ("STEALTH", ["token"])],
          { lane := "STEALTH", stem := "prove" }, Or.inr ?_, by decide⟩
  decide

/-- An empty stem is CONVERGENT and only CONVERGENT. A lane that claims to have
fired while naming no stem is a contradiction in the record itself. -/
theorem empty_stem_iff_convergent (t : Table) (r : RouteRec) (h : r.stem = "") :
    Auditable t r ↔ r.lane = "CONVERGENT" := by
  unfold Auditable; rw [if_pos h]

/-- Priority is what `find?` encodes: if two lanes own the same stem, the FIRST
wins and the second's entry is dead — reachable by no prompt. Stated over an
arbitrary table so it stays true of whatever the router's list becomes. -/
theorem first_owner_wins (a b : String) (sa sb : List String) (rest : Table)
    (s : String) (ha : sa.contains s = true) :
    laneOfStem ((a, sa) :: (b, sb) :: rest) s = some a := by
  unfold laneOfStem
  rw [List.find?_cons_of_pos (by simpa using ha)]
  rfl

/-- …and it is not vacuous: with the stem in the SECOND lane only, that lane is
the answer, so `first_owner_wins` is about priority and not about the head of a
list always winning. -/
theorem second_owner_reachable (a b : String) (sb : List String) (s : String)
    (hb : sb.contains s = true) :
    laneOfStem [(a, []), (b, sb)] s = some b := by
  unfold laneOfStem
  rw [List.find?_cons_of_neg (by simp),
      List.find?_cons_of_pos (by simpa using hb)]
  rfl

/-! ### The shipped table, as it stands today

These are `#guard`s, not theorems, and the distinction is deliberate. The stem
lists are a routing CHOICE that the project changes on purpose — `prove proof
lemma lean qed` joined FORGE in 0.7.0. A theorem asserting today's words would
go red on a correct future edit and the obvious repair would be to delete it.
The theorems above are quantified over an arbitrary `Table` for exactly that
reason; what follows pins the present, and is expected to move. -/

/-- The nine tables, in the router's priority order. -/
def shipped : Table :=
  [("FORGE", ["run","build","install","deploy","reproduce","ship","lake","theorem",
              "tactic","sorry","mathlib",".lean","prove","proof","lemma","lean","qed"]),
   ("CLINICAL", ["debug","error","bug","fix","secur","audit","verif","test","cve",
                 "segfault","crash","panic","leak","regress","traceback"]),
   ("EXECUTIVE", ["decid","urgenc","strike","direct","declar","now","conclud"]),
   ("EMPATHIC", ["emot","feel","grief","lonel","soul","story","human","tired","lost"]),
   ("STRATEGIC", ["strateg","plan","goal","roadmap","priorit","legal","recommend","analyz"]),
   ("CREATIVE", ["creativ","chaos","surreal","disrupt","paradox","dream","invent"]),
   ("PREDICTIVE", ["futur","scenar","predict","trend","forec","likel","horizon","next"]),
   ("STEALTH", ["encod","optim","token","compress","concise","byte","distill"]),
   ("RECURSIVE", ["evolv","recurs","meta","architect","refactor","ontolog","hybrid"])]

-- The four lanes measured live against the shipped router (2026-08-05):
--   "prove this lemma"        -> FORGE      stem=prove
--   "debug this error"        -> CLINICAL   stem=debug
--   "refactor the meta layer" -> RECURSIVE  stem=meta
--   "hello there"             -> CONVERGENT stem=
example : Auditable shipped { lane := "FORGE",      stem := "prove" } := by decide
example : Auditable shipped { lane := "CLINICAL",   stem := "debug" } := by decide
example : Auditable shipped { lane := "RECURSIVE",  stem := "meta"  } := by decide
example : Auditable shipped { lane := "CONVERGENT", stem := ""      } := by decide

-- The mis-route the old record could not express: a real stem, the wrong lane.
example : ¬ Auditable shipped { lane := "STEALTH", stem := "prove" } := by decide
-- A CONVERGENT record that names a stem is self-contradictory.
example : ¬ Auditable shipped { lane := "CONVERGENT", stem := "prove" } := by decide
-- A lane that fired while naming nothing is rejected on the same clause.
example : ¬ Auditable shipped { lane := "FORGE", stem := "" } := by decide
-- Leaked prompt text cannot pass, which is `auditable_imp_vocabSafe` made concrete.
example : ¬ Auditable shipped { lane := "FORGE", stem := "my secret project name" } := by decide
example : ¬ VocabSafe shipped { lane := "FORGE", stem := "my secret project name" } := by decide

/-- No stem is owned by two lanes today. A duplicate would not be a soundness
bug — `first_owner_wins` says the second copy is simply dead — but a dead table
entry is a routing intention that silently does nothing, so it is worth a red
build. -/
def noDuplicateStems (t : Table) : Bool :=
  let v := vocab t
  v.all (fun s => (v.filter (fun x => x == s)).length == 1)

example : noDuplicateStems shipped = true := by decide

-- Non-vacuity of the duplicate check: it says `false` on a table that has one.
example : noDuplicateStems [("FORGE", ["lean"]), ("STEALTH", ["lean"])] = false := by decide

end Stemlog

end RotMoE.Log
