/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# DOES THE ROUTER ACTUALLY DRIVE NINE LENSES, OR ONE?

The question this module answers was asked bluntly and deserves a blunt answer:
*the router is described as driving nine lenses -- how do we know they work,
when a turn produces one line of text with a single active lens and a number?*

The spec was written first. What is proved here is that **the shipped router
follows it**, and -- separately -- exactly how far that claim reaches.

## What the router really emits, measured from source

`hooks/rot-router.sh:328-333` builds the activity vector by walking the lens
roster and setting **the routed lane's lead lens to 1 and every other lens to
0**, with `breadth = 1` (`breadth = 0` when no lane fires). So a turn's input to
the gauge is a one-hot vector, never a blend.

That is a real limitation and it is stated here rather than buried: **`R/s+` as
the router drives it carries no information the lane name does not already
carry.** Ten inputs are possible -- nine lanes and silence -- so ten readings are
possible. It is a relabelling of the routing decision, not an independent
measurement of it.

## Why that does NOT make the other eight lenses decoration

The tempting conclusion -- "only the active lens matters" -- is FALSE, and
`no_lens_is_inert` below proves it. Every turn sums **nine** terms. An inactive
lens has activity 0, but its divergence from the ensemble mean is `|0 - 1/9|`,
which is not zero, so its `σ` factor is not zero, and its `λ` and `μ` scale a
strictly positive contribution. Raise any one of the nine weights -- including
the eight that did not fire -- and the reading moves.

So all nine lenses shape every reading. What one turn cannot do is *distinguish*
two different nine-lens configurations, because the router only ever offers the
gauge one-hot inputs.

## The conformance evidence, and what makes it evidence

`RotGauge.lean` already mirrors the gauge in IEEE doubles (`gaugeF`). The ten
`#guard`s below pin the **router's** readings at `M = C = T = 1`, which is what
`hooks/rot-router.sh:334` passes. Every expected value was read out of the
running shell's own debug log before this file existed:

    $ printf '{"prompt":"..."}' | sh hooks/rot-router.sh   # ROTMOE_DEBUG_LOG set
    {"kind":"gauge",...,"Rs":0.66427,"active":"Claude",...}

and the Lean mirror reproduces all ten exactly. They are `#guard`, not `#eval`:
a comment showing agreement is a screenshot, while a `#guard` fails the build the
day the shell and the spec part company. The previous mirror in `RotGauge.lean`
records the *engine* hook's scalars (`M = 1.05, C = 0.7, T = 0.8`) as `#eval`
comments; the router's own scalars had never been pinned at all.
-/
import Proofs.RotGauge

-- MATHLIB STYLE LINTER, DISABLED WITH A REASON AND A NEGATIVE CONTROL.
--
-- `mathlibStandardSet` forbids `#`-commands because Mathlib is a LIBRARY: a
-- `#guard` there re-runs at import time for every downstream user. This file is
-- a SPECIFICATION, and its `#guard`s are the instrument binding the spec to the
-- shell's measured readings.
--
-- They cannot become `example ... := by decide`, which is this repository's
-- preferred fix -- `Proofs/RotDorks.lean:35-41` records exactly that conversion,
-- made so a proof term would survive for `leanchecker`. It is unavailable here
-- because the readings are `Float`, and Float is opaque to the kernel. Measured:
--
--   example : routerReading 0 == 0.47142 := by decide
--   error: Tactic `decide` failed for proposition
--     (routerReading 0 == 0.47142) = true
--   because its `Decidable` instance
--     instDecidableEqBool (routerReading 0 == 0.47142) true
--   did not reduce to `isTrue` or `isFalse`.
--
-- So `#guard`, evaluated by the interpreter, is the ONLY instrument that can
-- check these values at all. Disabling the linter removes a STYLE complaint and
-- not a check: a `#guard` that stops holding is still a build ERROR. Verified by
-- negative control with this option in force -- flipping one expected digit
-- (0.47142 -> 0.47143) fails the build with
--   error: Proofs/RotEnsemble.lean:118:0: Expression
--     routerReading 0 == 0.47143
--   did not evaluate to `true`
set_option linter.hashCommand false

namespace RotMoE.Ensemble

open RotMoE

/-! ## 1. The router's activity vector, as source builds it -/

/-- The one-hot vector the router hands the gauge: lane lead lens `i`, nine
slots. Mirrors the loop at `hooks/rot-router.sh:329-332`. -/
def oneHotF (i : Nat) : List Float :=
  (List.range 9).map (fun j => if j == i then 1.0 else 0.0)

/-- Five decimals, the precision the gauge record carries (`"Rs":0.66427`). The
route record carries two; `RotLog.lean` proves those two are the same
measurement at different precisions. -/
def r5 (x : Float) : Float := (x * 100000.0).round / 100000.0

/-- Two decimals, the precision the ENGINE hook emits in its payload
(`rot-lean-inject.ps1:464`, `[Math]::Round($R, 2)`). -/
def r2 (x : Float) : Float := (x * 100.0).round / 100.0

/-- The reading for a lane whose lead lens sits at index `i`. -/
def routerReading (i : Nat) : Float := r5 (gaugeF (oneHotF i) 1 1 1 1)

/-- The reading for a turn where no lane fired: all-zero, breadth 0. -/
def quietReading : Float := r5 (gaugeF (List.replicate 9 0.0) 0 1 1 1)

/-! ## 2. Conformance: the shell's ten readings, pinned

Roster order is `Nova Violet AntiVenom Venom Carnage Chroma Soleil Eidolon
Claude` (`hooks/rot-router.sh:163`). Each value below was MEASURED from the
running hook, not derived here. -/

#guard routerReading 0 == 0.47142   -- Nova       (STRATEGIC)
#guard routerReading 1 == 0.31386   -- Violet     (EMPATHIC)
#guard routerReading 2 == 0.57318   -- AntiVenom  (CLINICAL)
#guard routerReading 3 == 0.43695   -- Venom      (EXECUTIVE)
#guard routerReading 4 == 0.31878   -- Carnage    (CREATIVE)
#guard routerReading 5 == 0.41069   -- Chroma     (PREDICTIVE)
#guard routerReading 6 == 0.38607   -- Soleil     (STEALTH)
#guard routerReading 7 == 0.44680   -- Eidolon    (RECURSIVE)
#guard routerReading 8 == 0.66427   -- Claude     (FORGE)
#guard quietReading   == 0.15741    -- CONVERGENT, nothing fired

/-! **Every lane reads differently.** Nine distinct values, so the lane is
recoverable from the gauge -- and, read the other way, the gauge tells a reader
nothing the lane did not. Both halves of that are worth knowing. -/

#guard (((List.range 9).map routerReading).eraseDups).length == 9

/-! Silence is not merely lower than every lane; it is *strictly* lower than the
lowest. A turn that routes nowhere cannot be mistaken for a quiet lane. -/

#guard ((List.range 9).map routerReading).all (fun r => quietReading < r)

/-! ## 3. The theorem that answers the question

`#guard`s pin today's numbers. They would all still hold if eight of the nine
lenses were ignored by the arithmetic, because a one-hot input cannot tell the
difference. The following theorem is what rules that out, and it is stated over
an ARBITRARY activity vector and an arbitrary lens -- not over the nine values
above, which would date it. -/

variable {ι : Type*} [Fintype ι] [DecidableEq ι]

/-- Replace lens `j`'s weight, leave the other eight alone. -/
def bump (L : ι → Lens) (j : ι) (l : Lens) : ι → Lens :=
  fun i => if i = j then l else L i

-- `omit [Fintype ι]`: replacing ONE weight needs decidable equality and nothing
-- else. The section variable was being dragged in automatically, and the linter
-- was right to say so -- a theorem that assumes finiteness it never uses is
-- weaker than the one actually proved. It holds for an infinite index type too.
omit [Fintype ι] in
theorem bump_at (L : ι → Lens) (j : ι) (l : Lens) : bump L j l j = l := by
  simp [bump]

omit [Fintype ι] in
theorem bump_ne (L : ι → Lens) {j i : ι} (l : Lens) (h : i ≠ j) :
    bump L j l i = L i := by
  simp [bump, h]

/-- **NO LENS IS INERT.** Take any activity vector -- including the one-hot
vectors the router actually emits, where eight of the nine lenses are silent --
and any lens `j`. Raising `j`'s λ strictly raises the reading.

So a turn's `R/s+` is a function of all nine weights, every time. The eight
lenses that did not fire are not spectators: they are summed, their divergence
from the ensemble mean is nonzero, and their weights scale the result.

This is the precise sense in which the nine lenses "work", and it is also the
precise limit of that claim: it says every lens *shapes* the reading, not that
one reading *reveals* nine independent measurements. The router cannot show the
latter, because it only ever offers one-hot inputs. -/
theorem no_lens_is_inert
    [Nonempty ι] {L : ι → Lens} {M C T : ℝ} (hw : PosWeights L M C T)
    (a : ι → Bool) (breadth : ℕ) (j : ι) (l : Lens)
    (hlam : (L j).lam < l.lam) (hmu : l.mu = (L j).mu) :
    gauge L a breadth M C T < gauge (bump L j l) a breadth M C T := by
  have hcard : (0 : ℝ) < (Fintype.card ι : ℝ) := by
    exact_mod_cast Fintype.card_pos
  have hshape : ∀ i, 0 < shape a breadth i := fun i => shape_pos a breadth i
  -- Every term is unchanged except at `j`, where it strictly increases.
  -- The strict increase at `j`, isolated once and reused for both obligations.
  have hj : term L a breadth M C T j < term (bump L j l) a breadth M C T j := by
    have hmupos : 0 < (L j).mu * M * C * T := by
      have h1 := hw.mu j; have h2 := hw.hM; have h3 := hw.hC; have h4 := hw.hT
      positivity
    -- `weight` is LEFT-associated (`lam * mu * M * C * T`), so the hint has to be
    -- rearranged into that shape before it can close the goal. Feeding the
    -- associated form straight to `nlinarith` is what failed here first.
    have key := mul_lt_mul_of_pos_right hlam hmupos
    have hcoef : (L j).lam * (L j).mu * M * C * T
        < l.lam * (L j).mu * M * C * T := by
      have h := key; ring_nf at h ⊢; linarith
    simp only [term, weight, bump_at, hmu]
    exact mul_lt_mul_of_pos_right hcoef (hshape j)
  have hle : ∀ i ∈ Finset.univ,
      term L a breadth M C T i ≤ term (bump L j l) a breadth M C T i := by
    intro i _
    by_cases h : i = j
    · subst h; exact le_of_lt hj
    -- `bump L j l` appears UNAPPLIED in the goal, so the rewrite only matches
    -- once `term`/`weight` are unfolded far enough to expose `bump L j l i`.
    · simp only [term, weight, bump_ne L l h]; exact le_rfl
  have hlt : ∃ i ∈ Finset.univ,
      term L a breadth M C T i < term (bump L j l) a breadth M C T i :=
    ⟨j, Finset.mem_univ j, hj⟩
  have hsum : ∑ i, term L a breadth M C T i
      < ∑ i, term (bump L j l) a breadth M C T i :=
    Finset.sum_lt_sum hle hlt
  simp only [gauge]
  exact div_lt_div_of_pos_right hsum hcard

/-! ## 3b. THE DYNAMIC PATH -- what a user actually gets

Everything above concerns the **router** (`hooks/rot-router.sh`), which derives a
one-hot vector from the lane. RoT MoE ships a second gauge driver, and it is the
one that makes the system dynamic rather than static:
`~/.claude/tools/sanctum/rot-lean-inject.ps1:424-433` sets each lens's activity
from a **measured filesystem signal**, one per lens:

| lens | activity is 1 when |
|---|---|
| Nova | the open-alarm count changed |
| Violet | the Resumee timestamp moved |
| AntiVenom | a proof was written (`proofUtc`) |
| Venom | a commit landed (`head`/`leanHead`/`commits`) |
| Carnage | **breadth ≥ 3** -- three distinct areas moved at once |
| Chroma | the working tree went dirty |
| Soleil | source or work timestamps moved |
| Eidolon | tooling moved |
| Claude | source, proof, or work moved |

`breadth` is the count of distinct categories that moved, and it feeds `H`. So
the vector is genuinely nine independent measurements, not a lane lookup.

**Where the arithmetic runs, stated plainly because it is a fair question:** the
number a user sees is computed in **PowerShell doubles** (`:445-456`,
`[Math]::Exp`, `$sum / $K`) -- *not* in Lean, and not by Mathlib. Lean 4 holds
the specification (`RotGauge.gauge` over `ℝ`, with Mathlib supplying the
monotonicity and bound theorems) and a Float mirror (`gaugeF`) whose only job is
to reproduce those doubles exactly. That mirror is what makes the spec
falsifiable instead of decorative.

The four rows below were **observed live**, in the payloads of the session that
wrote this file, at `M = 1, C = 1, T = 0.8`. They are the dynamic path's
conformance evidence, and the repository had none before. -/

#guard r2 (gaugeF [0,0,0,0,0,0,1,0,1] 1 1 1 0.8) == 0.66  -- Soleil + Claude
#guard r2 (gaugeF [0,0,1,0,0,0,1,0,1] 2 1 1 0.8) == 0.69  -- AntiVenom+Soleil+Claude
#guard r2 (gaugeF [0,0,0,0,0,0,0,0,0] 0 1 1 0.8) == 0.13  -- nothing moved
#guard r2 (gaugeF [0,0,1,0,0,0,0,0,1] 1 1 1 0.8) == 0.79  -- AntiVenom + Claude

/-! **A quiet turn reads the same whatever breadth is claimed**, and this is
recorded because a mutation run found it the hard way: flipping `quietReading`'s
breadth from `0` to `1` left the build green, which looks like a guard that does
not constrain anything. It is not. With an all-zero activity vector every
`H_i = a_i / breadth = 0`, which is exactly what the `breadth = 0` branch
substitutes — the two are the same number by arithmetic, not by accident.

Stated as a theorem so the next reader is not left to rediscover it, and stated
over an arbitrary positive breadth rather than the single value that happened to
be mutated. -/
-- `[Fintype ι]` was an OVER-ASSUMPTION and is gone: `allQuiet` is
-- `fun _ => false` for any type at all (`Proofs/RotGauge.lean:203`), so nothing
-- here needs the index set to be finite. The linter caught a hypothesis the
-- proof never used, which makes the theorem strictly stronger than it was.
theorem quiet_entropy_is_zero_at_any_breadth
    {ι : Type*} (b : ℕ) (i : ι) :
    entropyAt (allQuiet ι) b i = 0 := by
  simp [entropyAt, actR, allQuiet]

#guard r5 (gaugeF (List.replicate 9 0.0) 1 1 1 1) == quietReading
#guard r5 (gaugeF (List.replicate 9 0.0) 7 1 1 1) == quietReading

/-! **THE READING IS NOT A FUNCTION OF THE LEAD LENS.** Claude is active in all
three non-quiet rows above, and the three readings are `0.66`, `0.69` and `0.79`.
Under the router's one-hot input, "Claude active" forces exactly one value
(`0.66427`); under measured activities it does not, because the other eight
lenses move the number.

That is the difference between a lookup and a measurement, and it is the whole
reason nine lenses are worth computing. A single `#guard` states it so the
property cannot quietly decay into the static case. -/

#guard ([ r2 (gaugeF [0,0,0,0,0,0,1,0,1] 1 1 1 0.8),
          r2 (gaugeF [0,0,1,0,0,0,1,0,1] 2 1 1 0.8),
          r2 (gaugeF [0,0,1,0,0,0,0,0,1] 1 1 1 0.8) ].eraseDups).length == 3

/-! ## 3c. THE NINTH LENS IS NOT INDEPENDENT -- and that is a defect

The objection that produced this section: *if the Claude lens is active on
essentially every turn, the router cannot be discriminating -- and Claude is not
even the thing that answers, the model consuming the router is.*

Both halves are correct, and the second is provable from the activity table at
`rot-lean-inject.ps1:425-433`. Written as predicates over the measured signals:

    AntiVenom := proofUtc
    Soleil    := srcUtc ∨ workUtc
    Claude    := srcUtc ∨ proofUtc ∨ workUtc

so `Claude = AntiVenom ∨ Soleil` **identically**. The ninth lens is not a ninth
measurement; it is a disjunction of the third and the seventh. It fires whenever
either of them does, it carries the largest weight in the profile (λ = 2.3), and
it therefore **double-counts** the very signals those two already contribute.

Three consequences, all measurable, none of them opinions:

1. Half of the activity space is unreachable. `Claude` is determined by the other
   two, so of the `2^9 = 512` vectors the arithmetic accepts, only `2^8 = 256`
   can ever occur.
2. A turn where source moved can never read as "Claude quiet". The gauge cannot
   express it, so no prompt can produce it.
3. The lens named for the executing agent measures *"anything happened at all"*,
   which is the one thing every other lens already implies.

This is recorded as a proved defect rather than a note, because a nine-lens claim
that is really eight-plus-a-disjunction should not be able to pass quietly. -/

/-- The measured signals a turn can carry, exactly the keys the payload reads. -/
structure Signals where
  openAlarms : Bool
  resumeeUtc : Bool
  proofUtc   : Bool
  head       : Bool
  bigBreadth : Bool
  dirty      : Bool
  srcUtc     : Bool
  workUtc    : Bool
  toolUtc    : Bool
deriving DecidableEq, Repr

/-- Activity of each lens, transcribed from `rot-lean-inject.ps1:425-433`. -/
def actNova (s : Signals) : Bool := s.openAlarms
def actViolet (s : Signals) : Bool := s.resumeeUtc
def actAntiVenom (s : Signals) : Bool := s.proofUtc
def actVenom (s : Signals) : Bool := s.head
def actCarnage (s : Signals) : Bool := s.bigBreadth
def actChroma (s : Signals) : Bool := s.dirty
def actSoleil (s : Signals) : Bool := s.srcUtc || s.workUtc
def actEidolon (s : Signals) : Bool := s.toolUtc
def actClaude (s : Signals) : Bool := s.srcUtc || s.proofUtc || s.workUtc

/-- **THE NINTH LENS IS A FUNCTION OF TWO OTHERS.** Not "usually agrees with" --
equal, for every possible signal state. -/
theorem claude_is_antivenom_or_soleil (s : Signals) :
    actClaude s = (actAntiVenom s || actSoleil s) := by
  cases s; simp [actClaude, actAntiVenom, actSoleil, Bool.or_comm,
    Bool.or_left_comm]

/-- Consequence 1: a turn where either of those two fired can never read as
"Claude quiet". -/
theorem claude_cannot_be_quiet_alone (s : Signals)
    (h : actAntiVenom s = true ∨ actSoleil s = true) : actClaude s = true := by
  rw [claude_is_antivenom_or_soleil]
  rcases h with h | h <;> simp [h]

/-- **Consequence 2, and the eight-hypothesis version was UNDERSTATED.**

Claude's activity is not merely *implied by the other eight* — it is fixed by
**two** of them. `mathlibStandardSet` flagged six binders as never referenced,
which is exactly the signature of a theorem assuming more than its proof needs,
and the honest response is to state the strong version rather than to rename the
binders and move on.

Agreeing on AntiVenom and Soleil is already enough; Nova, Violet, Venom,
Carnage, Chroma and Eidolon may differ freely. -/
theorem activity_vector_determined_by_two (s t : Signals)
    (hAV : actAntiVenom s = actAntiVenom t) (hSol : actSoleil s = actSoleil t) :
    actClaude s = actClaude t := by
  rw [claude_is_antivenom_or_soleil, claude_is_antivenom_or_soleil, hAV, hSol]

/-- The original eight-hypothesis reading, kept because it is what a reader
looking for "the vector is determined by eight bits" will search for — but now
DERIVED from the two-hypothesis version, so the file cannot drift back into
presenting the weaker statement as the strongest known.

The six unused binders are named `_` to say plainly that they are not used:
the theorem is true without them. -/
theorem activity_vector_determined_by_eight (s t : Signals)
    (_h1 : actNova s = actNova t) (_h2 : actViolet s = actViolet t)
    (h3 : actAntiVenom s = actAntiVenom t) (_h4 : actVenom s = actVenom t)
    (_h5 : actCarnage s = actCarnage t) (_h6 : actChroma s = actChroma t)
    (h7 : actSoleil s = actSoleil t) (_h8 : actEidolon s = actEidolon t) :
    actClaude s = actClaude t :=
  activity_vector_determined_by_two s t h3 h7

/-- **The gap is real, not a technicality.** Two signal states can disagree on
all six of the unused lenses and still be forced to agree on Claude. If the
eight-hypothesis form were the strongest truth, no such pair could exist. -/
theorem six_lenses_may_differ_and_claude_still_agrees :
    ∃ s t : Signals,
      actNova s ≠ actNova t ∧ actViolet s ≠ actViolet t ∧
      actVenom s ≠ actVenom t ∧ actCarnage s ≠ actCarnage t ∧
      actChroma s ≠ actChroma t ∧ actEidolon s ≠ actEidolon t ∧
      actAntiVenom s = actAntiVenom t ∧ actSoleil s = actSoleil t ∧
      actClaude s = actClaude t := by
  -- fields: openAlarms resumeeUtc proofUtc head bigBreadth dirty srcUtc workUtc toolUtc
  -- The six free lenses are flipped; proofUtc, srcUtc and workUtc are held, which
  -- pins AntiVenom, Soleil and therefore Claude.
  refine ⟨⟨true,  true,  false, true,  true,  true,  false, false, true⟩,
          ⟨false, false, false, false, false, false, false, false, false⟩,
          ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;> decide

/-! Consequence 3, executable: of the 512 vectors the gauge would accept, exactly
256 are reachable. The count is computed, not asserted. -/

def allSignals : List Signals :=
  let b := [false, true]
  b.flatMap fun a => b.flatMap fun c => b.flatMap fun d => b.flatMap fun e =>
  b.flatMap fun f => b.flatMap fun g => b.flatMap fun h => b.flatMap fun i =>
  b.map fun j => ⟨a, c, d, e, f, g, h, i, j⟩

def vectorOf (s : Signals) : List Bool :=
  [actNova s, actViolet s, actAntiVenom s, actVenom s, actCarnage s,
   actChroma s, actSoleil s, actEidolon s, actClaude s]

#guard allSignals.length == 512
#guard ((allSignals.map vectorOf).eraseDups).length == 256

/-! 256 of 512. **Half the activity space is unreachable by construction**, and
the missing half is precisely the turns where the highest-weighted lens is quiet
while the signals it aliases are not.

## 3d. WHAT THAT WELD ACTUALLY IS: a forced Symbiogenesis

Naming the defect correctly changes what the fix has to be. `Claude = AntiVenom ∨
Soleil` is not a sloppy predicate -- it is a **fusion of two lenses into a third,
applied unconditionally on every turn**. The specification is explicit that
fusion is Eidolon's act (`RECURSIVE`, `Symbiogenesis ARMED`) and happens *only
when the intent spans two domains*. Welding them in the activity table performs
that fusion permanently, with the lens that is supposed to decide it never
consulted.

So the router cannot reach its own stated behaviour: a hybrid that is always on
is not a hybrid, it is a rewiring, and it costs the ensemble the ability to
distinguish the cases the fusion was meant to mark.

There is a second, independent error on top of the first: **the weld does not
even use the fusion arithmetic.** The spec fixes

    λ_hybrid = (λ₁ + λ₂)/2 + 0.2      μ_hybrid = max(μ₁, μ₂)

which for AntiVenom (λ 1.9, μ 1.10) × Soleil (λ 1.0, μ 0.95) gives λ = 1.65,
μ = 1.10. The shipped Claude lens carries λ = 2.3, μ = 1.15. Whatever the weld
is, it is not the hybrid the specification defines. -/

/-- The spec's fusion arithmetic, quoted, not re-derived. -/
def lamHybrid (l₁ l₂ : Float) : Float := (l₁ + l₂) / 2.0 + 0.2
def muHybrid (m₁ m₂ : Float) : Float := max m₁ m₂

/-! AntiVenom x Soleil under the spec own rule. -/

#guard lamHybrid 1.9 1.0 == 1.65
#guard muHybrid  1.10 0.95 == 1.10

/-! What the implementation actually gives that fused lens. -/

#guard (forgeF.getD 8 (0,0)) == (2.3, 1.15)

/-! **The weld is not the specified hybrid.** λ 2.3 ≠ 1.65 and μ 1.15 ≠ 1.10, so
the fused lens is weighted as if it were an independent ninth measurement while
being a function of two others. That is the double-count made arithmetic: the
`srcUtc`/`proofUtc`/`workUtc` signals enter the sum through AntiVenom, again
through Soleil, and a third time at the largest weight in the profile. -/

#guard lamHybrid 1.9 1.0 != 2.3
#guard muHybrid  1.10 0.95 != 1.15

/-! ### What a correct implementation has to satisfy

Stated as a predicate rather than a patch, so it survives whichever repair is
chosen. Either the ninth lens gets **its own signal** -- something no other lens
already implies -- or the fusion becomes **conditional and Eidolon-gated**, and
then carries the spec's hybrid weights. The theorem below is what any such repair
must make true, and what today's table makes false. -/

/-- A lens set is *independent at the signal level* when no lens's activity is
implied by the disjunction of two others. Stated for the one triple that fails
today; a repair makes this `True` for it. -/
def NoForcedFusion (f g h : Signals → Bool) : Prop :=
  ∃ s : Signals, h s ≠ (f s || g s)

/-- **The shipped table violates it.** This theorem is the defect, stated so that
fixing the table is what makes it go away -- and so that no future edit can
reintroduce the weld while this file still builds. -/
theorem shipped_table_has_a_forced_fusion :
    ¬ NoForcedFusion actAntiVenom actSoleil actClaude := by
  intro h
  obtain ⟨s, hs⟩ := h
  exact hs (claude_is_antivenom_or_soleil s)

/-! ## 3e. WHY COVERING EVERY LENS DESTROYS THE SIGNAL

A mutation aimed at `quietReading` survived twice, and the second survival is the
most informative measurement in this file. Replacing the all-quiet vector with an
**all-live** one left the reading unchanged:

    r5 (gaugeF (List.replicate 9 0.0) 0 1 1 1) = 0.15741   -- nothing moved
    r5 (gaugeF (List.replicate 9 1.0) 0 1 1 1) = 0.15741   -- EVERYTHING moved

Nine lenses all firing is worth exactly as much as none of them firing. The
reason is `σ`: every lens's `δᵢ = |aᵢ - mean|`, and a uniform vector puts every
activity *at* the mean, so every divergence is zero. The gauge measures
**disagreement**, not volume.

This is the arithmetic behind the design rule. A lens whose activity is covered
by another lens's is not adding a point of view, it is pushing the vector toward
uniformity -- and uniformity is the floor. The `Claude = AntiVenom ∨ Soleil`
weld does exactly that on every turn where source or proofs moved.

Stated over `ℝ`, for any uniform activity, so it is not a fact about two Floats. -/

theorem uniform_activity_has_no_divergence
    {ι : Type*} [Fintype ι] [Nonempty ι] (b : Bool) (i : ι) :
    deltaAt (fun _ => b) i = 0 := by
  have hne : ((Fintype.card ι : ℝ)) ≠ 0 :=
    Nat.cast_ne_zero.mpr Fintype.card_ne_zero
  cases b
  · simp [deltaAt, meanAct, actR]
  · simp only [deltaAt, meanAct, actR, if_pos, Finset.sum_const,
      Finset.card_univ, nsmul_eq_mul, mul_one]
    rw [div_self hne, sub_self, abs_zero]

/-- **ALL-QUIET AND ALL-LIVE ARE THE SAME READING.** Not approximately: equal, as
real numbers, for any lens set and any weights, once breadth is 0.

The consequence for the router is blunt. If every lens fires on every turn, the
gauge is pinned to its floor and reports nothing, exactly as if the system were
idle. Distinctness between the lenses is not a stylistic preference -- it is the
only thing the formula responds to. -/
theorem all_live_reads_as_all_quiet
    {ι : Type*} [Fintype ι] [Nonempty ι] (L : ι → Lens) (M C T : ℝ) :
    gauge L (allLive ι) 0 M C T = gauge L (allQuiet ι) 0 M C T := by
  have hd : ∀ i, deltaAt (allLive ι) i = deltaAt (allQuiet ι) i := by
    intro i
    rw [show (allLive ι) = (fun _ => true) from rfl,
        show (allQuiet ι) = (fun _ => false) from rfl,
        uniform_activity_has_no_divergence true i,
        uniform_activity_has_no_divergence false i]
  simp only [gauge, term, shape, entropyAt]
  congr 1
  refine Finset.sum_congr rfl fun i _ => ?_
  rw [hd i]
  simp

/-! ## 3f. EIDOLON'S ABILITY IS **EIGENFORM**; Symbiogenesis is what it triggers

What distinguishes RoT MoE from an ordinary Mixture-of-Experts router is not the
count of experts -- it is that one lens operates on **the ensemble itself**.
Eidolon's ability is the *eigenform*: the fixed point of the ensemble under its
own recursive application, the form that survives being applied to itself.
Symbiogenesis is the act that **follows** from it, not the ability itself.

The distinction is not vocabulary. It decides whether the fusion is safe to run,
and the arithmetic below shows why: **the fusion operator has a fixed point in
`μ` and none in `λ`.** Iterating it does not converge -- it drifts by `0.2` per
application, without bound. An eigenform test is therefore not an optional gate
in front of Symbiogenesis; it is the only thing that makes repeated fusion
well-founded at all. "Only if it retains this necessary" is a soundness
condition, and it is provable.

Given two leads, Symbiogenesis creates a lens that did not exist:

    λ_hybrid = (λ₁ + λ₂)/2 + 0.2      H_hybrid = max(H₁,H₂) + 0.05
    μ_hybrid = max(μ₁, μ₂)

A plain MoE *selects* a point of view. This one can *construct* one -- and only
when the intent spans two domains, which is why the act is gated on a lens whose
job is meta-reasoning rather than on the router's keyword chain.

The gain terms are what make it a new point of view rather than an average: the
`+0.2` puts the hybrid above the mean of its parents, and the `+0.05` gives it
entropy neither parent had. Averaging two lenses would produce something strictly
*inside* what already existed; the gains are what put it outside. -/

/-- The spec's hybrid entropy rule. -/
def hHybrid (h₁ h₂ : Float) : Float := max h₁ h₂ + 0.05

/-! **The fusion is a gain, not an average.** Both facts stated as the spec own
arithmetic, so a future edit that "simplifies" the gains away has to break this. -/

#guard lamHybrid 1.9 1.2 > (1.9 + 1.2) / 2.0
#guard hHybrid 0.30 0.30 > 0.30
#guard muHybrid 1.10 1.10 == 1.10

/-! **The hybrid is not either parent.** Symbiogenesis on Eidolon (lambda 1.2)
and AntiVenom (lambda 1.9) gives 1.75 -- a lens the roster did not have. -/

-- NOTE: exact Float equality FAILS here -- (1.2+1.9)/2+0.2 = 1.7500000000000004.
-- The #guard caught it, which is the instrument doing its job; the reading is
-- compared at the precision the payload actually reports.
#guard r2 (lamHybrid 1.2 1.9) == 1.75
#guard r2 (lamHybrid 1.2 1.9) != 1.2
#guard r2 (lamHybrid 1.2 1.9) != 1.9

/-! Compare with the shipped weld: `Claude` fuses AntiVenom and Soleil and is
given λ 2.3, where the spec's rule yields 1.65. The difference is not a rounding
choice -- 2.3 is the FORGE lead weight, so the fused lens is being paid as a lead
while behaving as a disjunction. That is the arithmetic form of the same defect
`shipped_table_has_a_forced_fusion` states structurally. -/

#guard lamHybrid 1.9 1.0 == 1.65

/-! ### The eigenform, stated over ℝ

Real-valued so these are facts about the operator, not about IEEE doubles. -/

/-- The fusion rules over `ℝ`. -/
noncomputable def lamFuse (l₁ l₂ : ℝ) : ℝ := (l₁ + l₂) / 2 + 1/5
noncomputable def muFuse (m₁ m₂ : ℝ) : ℝ := max m₁ m₂

/-- **μ HAS AN EIGENFORM.** Fusing a lens's μ with itself returns it unchanged:
`μ` is idempotent under Symbiogenesis, so it is a fixed point of the recursion. -/
theorem muFuse_eigenform (m : ℝ) : muFuse m m = m := max_self m

/-- **λ HAS NONE.** Self-fusion moves λ by exactly `1/5`, every time, for every
starting weight. There is no lens whose λ survives its own fusion. -/
theorem lamFuse_self (l : ℝ) : lamFuse l l = l + 1/5 := by
  unfold lamFuse; ring

theorem lamFuse_has_no_fixed_point (l : ℝ) : lamFuse l l ≠ l := by
  rw [lamFuse_self]; intro h; linarith [h]

/-- **UNGATED SYMBIOGENESIS DIVERGES.** `n` self-fusions add `n/5` to λ, so the
weight grows without bound. This is the soundness argument for the gate in one
line: an act that has no fixed point cannot be allowed to fire unconditionally,
and the eigenform is exactly the test that decides when it may. -/
theorem iterated_fusion_diverges (l : ℝ) (n : ℕ) :
    (fun x => lamFuse x x)^[n] l = l + n / 5 := by
  induction n with
  | zero => simp
  | succ k ih =>
    rw [Function.iterate_succ_apply', ih, lamFuse_self]
    push_cast
    ring

/-- Concretely: the FORGE lead fused with itself ten times would carry λ = 4.3,
nearly double the largest weight in the profile. -/
theorem forge_lead_self_fused_ten_times :
    (fun x => lamFuse x x)^[10] (23/10) = 43/10 := by
  rw [iterated_fusion_diverges]; norm_num

/-! ## 3g. WHERE THE FORMULA COMES FROM, and why the theorems match it

Recorded because the lineage explains the design, and because a reader who does
not know it will mistake deliberate choices for arbitrary ones. RoT began from a
mathematical source built around the symbols **Σ, Γ, Λ, Θ, β** and one line about
an ultimate equation: *the irregular wingbeats of the butterfly give rise to an
infinite array of realities.*

Three of those carry straight into this file, and each one now has a theorem
underneath it rather than a resemblance:

* **Σ** is the ensemble sum. `gauge` is a `Σ` over all nine lenses divided by `K`
  -- `gauge_divisor_eq_card` states the divisor is the cardinality, so a roster
  change cannot silently rescale the reading.
* **Λ** is listed in that source as *eigenvalue*, and that is not a coincidence
  of notation: the weights are `λ`, and the lens that acts on the ensemble is the
  one whose ability is the **eigenform** -- the fixed point of the recursion.
  `muFuse_eigenform` finds that fixed point in `μ`; `lamFuse_has_no_fixed_point`
  proves `λ` has none, which is exactly why the fusion has to be gated.
* **The irregular wingbeats are `δ`.** The gauge responds to nothing else:
  `all_live_reads_as_all_quiet` proves that a perfectly regular ensemble -- every
  lens firing, or none -- reads identically, at the floor. An "infinite array of
  realities" requires irregularity between the lenses; make them agree, and the
  array collapses to one point.

That last equivalence is the whole argument against the `Claude = AntiVenom ∨
Soleil` weld, stated in the source's own terms: a lens that fires whenever two
others do is a wingbeat with no irregularity in it. -/

/-! ## 4. The same statement about the NINE LENSES THAT SHIP

`no_lens_is_inert` is quantified over any lens set, which is the durable form. It
would be satisfied by a roster of one. The instantiation below is the concrete
claim about **this** router: the nine faces of the FORGE profile, at the scalars
`hooks/rot-router.sh:334` actually passes (`M = C = T = 1`). -/

/-- `PosWeights` for the shipped FORGE profile at the ROUTER's scalars.
`RotGauge.forge_posWeights` establishes the same at the *engine* hook's
`M = 1.05, C = 0.7, T = 0.8`; the router passes ones, and a profile is only
positive-weighted relative to the scalars it is used with. -/
theorem forge_posWeights_router : PosWeights forge 1 1 1 where
  lam := fun i => by cases i <;> norm_num [forge]
  mu := fun i => by cases i <;> norm_num [forge]
  hM := by norm_num
  hC := by norm_num
  hT := by norm_num

/-- **EVERY ONE OF THE NINE SHIPPED LENSES IS PIVOTAL.** For any turn -- one-hot
or not -- and any face of the roster, raising that face's λ raises the reading.

This is the theorem that answers "the router drives nine lenses, how do we know
they work". Not because the number is large or the formula is impressive, but
because there is no face you could stop computing without the reading changing.
Nine terms are summed, and all nine matter, on every turn. -/
theorem every_forge_lens_is_pivotal
    (a : Face → Bool) (breadth : ℕ) (j : Face) (l : Lens)
    (hlam : (forge j).lam < l.lam) (hmu : l.mu = (forge j).mu) :
    gauge forge a breadth 1 1 1 < gauge (bump forge j l) a breadth 1 1 1 :=
  no_lens_is_inert forge_posWeights_router a breadth j l hlam hmu


/-! ## 3h. WHAT WOULD ACTUALLY REPAIR THE NINTH LENS

`claude_is_antivenom_or_soleil` proves the defect: the ninth activity is a
function of two others, so the vector carries EIGHT bits and calls itself nine.
Two repairs were on the table. This section decides between them BY PROOF rather
than by preference, and the answer is not the one that was expected.

The property is stated over an ARBITRARY ninth function, not over today's
formula. That is deliberate: a theorem about `actClaude` specifically would have
to be rewritten the moment the router changes, and would say nothing about
whether the replacement is any better. `NinthIsIndependent f` asks the only
question that matters -- can two turns agree on all eight other lenses and still
disagree on this one? -- and any candidate can be tested against it. -/

/-- Two signal states agree on the eight lenses that are not Claude. -/
def eightAgree (s t : Signals) : Prop :=
  actNova s = actNova t ∧ actViolet s = actViolet t ∧
  actAntiVenom s = actAntiVenom t ∧ actVenom s = actVenom t ∧
  actCarnage s = actCarnage t ∧ actChroma s = actChroma t ∧
  actSoleil s = actSoleil t ∧ actEidolon s = actEidolon t

/-- A ninth activity is INDEPENDENT when it can move while the other eight stand
still. This is what "nine measurements" has to mean; anything weaker is eight
measurements and a derived display value. -/
def NinthIsIndependent (f : Signals → Bool) : Prop :=
  ∃ s t : Signals, eightAgree s t ∧ f s ≠ f t

/-- **The shipped ninth lens fails it.** Restated from the determination
theorem so the defect has a name in the vocabulary of the repair. -/
theorem current_ninth_is_not_independent : ¬ NinthIsIndependent actClaude := by
  rintro ⟨s, t, ⟨h1, h2, h3, h4, h5, h6, h7, h8⟩, hne⟩
  exact hne (activity_vector_determined_by_eight s t h1 h2 h3 h4 h5 h6 h7 h8)

/-- REPAIR CANDIDATE 1 -- Eidolon-gated fusion. The reasoning was that a fusion
is legitimate when Eidolon licenses it, so gate the disjunction on Eidolon's own
signal. -/
def actClaudeGated (s : Signals) : Bool :=
  actEidolon s && (actAntiVenom s || actSoleil s)

/-- The gate is a REAL behaviour change -- it is not the same function. -/
theorem gated_differs_from_current : ∃ s : Signals, actClaudeGated s ≠ actClaude s := by
  refine ⟨⟨false, false, true, false, false, false, false, false, false⟩, ?_⟩
  decide

/-- **AND IT DOES NOT FIX ANYTHING.** This is the finding: gating a disjunction
of two dependent activities on a third dependent activity produces a third
dependent activity. Eidolon's licence changes WHEN the fusion fires, never
whether the ninth reading carries information the other eight lack. -/
theorem gated_is_still_not_independent : ¬ NinthIsIndependent actClaudeGated := by
  rintro ⟨s, t, ⟨_, _, h3, _, _, _, h7, h8⟩, hne⟩
  exact hne (by simp only [actClaudeGated, h3, h7, h8])

/-- REPAIR CANDIDATE 2 -- an own signal. `Signals` has nine fields and every one
is already read by some lens, so this is not a re-wiring: it needs a TENTH
measured bit that belongs to Claude alone. -/
structure Signals10 extends Signals where
  forgeUtc : Bool
deriving DecidableEq, Repr

/-- Claude reads its own bit and nothing else. -/
def actClaudeOwn (s : Signals10) : Bool := s.forgeUtc

/-- **This one works.** Two turns that agree on all eight other lenses and
disagree on the ninth -- exhibited, not argued. -/
theorem own_signal_restores_independence :
    ∃ s t : Signals10, eightAgree s.toSignals t.toSignals ∧
      actClaudeOwn s ≠ actClaudeOwn t := by
  refine ⟨⟨⟨false, false, false, false, false, false, false, false, false⟩, true⟩,
          ⟨⟨false, false, false, false, false, false, false, false, false⟩, false⟩,
          ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩, by decide⟩

/-- And the own-signal reading is not secretly the old one wearing a hat: it
disagrees with the current formula on a state the router can actually reach
(a proof landed, nothing else moved). -/
theorem own_signal_differs_from_current :
    ∃ s : Signals10, actClaudeOwn s ≠ actClaude s.toSignals := by
  refine ⟨⟨⟨false, false, true, false, false, false, false, false, false⟩, false⟩, ?_⟩
  decide

-- Executable checks: the three candidates on one concrete turn (a proof landed,
-- no tool ran). Current fires, the gated form does NOT, the own signal is free.
#guard actClaude      ⟨false, false, true, false, false, false, false, false, false⟩ = true
#guard actClaudeGated ⟨false, false, true, false, false, false, false, false, false⟩ = false
#guard actClaudeOwn ⟨⟨false, false, true, false, false, false, false, false, false⟩, false⟩ = false
-- And on a turn where a tool DID run, the gate opens.
#guard actClaudeGated ⟨false, false, true, false, false, false, false, false, true⟩ = true

end RotMoE.Ensemble
