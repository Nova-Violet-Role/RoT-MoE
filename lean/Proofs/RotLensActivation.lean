/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # Nine lenses are SCORED every turn; exactly one is ACTIVATED

`README.md:772` says *"Nine lenses run on every turn."* This module settles what
that sentence may and may not mean, because a previous NEXT list of mine got it
wrong in a way worth recording.

## The wrong diagnosis, and the measurement that corrected it

Across 100 live gauge records the field `breadth` never exceeded 1, and I filed
that as **corpus work**: "that corpus never activated two lenses on one turn",
implying a richer corpus would. It would not. Reading the shipped router:

    hooks/rot-router.sh:625-629      hooks/rot-router.ps1:562-565
      _vec=''; _br=0                   $acts = @(); $br = 0
      for _n in $NAMES; do             foreach ($n in $Names) {
        if [ "$_n" = "$_lens" ]        if ($n -eq $lens) { $acts += '1'; $br = 1 }
          then _vec="$_vec,1"; _br=1   else { $acts += '0' }
          else _vec="$_vec,0"; fi      }
      done

`_br` is **assigned** 1, never incremented, and `$_lens` is a single name taken
from `($lane -split ' ')[1]`. Breadth cannot exceed 1 **by construction**, in both
arms identically — so no corpus could ever have produced a 2. Re-measured over the
full log rather than the 100-record sample: 3707 gauge records, `breadth ∈ {0,1}`,
`breadth ≥ 2` **never**, which is now explained rather than merely observed.

`FUSE` and `ELEVATE` — the multi-lens paths in the engine spec — are **not
implemented**. A grep for them returns seven hits in the POSIX arm and one in the
PowerShell arm, and every one of them is the word *refuse* or *fuses* inside a
comment. That is not a defect to be hidden: it is the precise boundary of the
claim, and the theorems below draw it.

## What this costs the central claim, and what it does not

It does **not** make "nine lenses" decorative. `K = 9` is real: every lens
contributes a term to `R/s+` on every turn through its own `λ·σ(δ)·μ`, and
`raising_an_inactive_lens_raises_the_gauge` proves the gauge is not a function of
the active lens alone — change a *silent* lens's weight and the number moves.

It **does** bound the claim to this: nine lenses are *scored*, one is *activated*.
`the_breadth_field_separates_no_two_routed_turns` is the honest half — on a routed
turn `breadth` is constant, so that field carries zero information about which turn
it was.

## The latent defect this modelling exposed

`_br=1` is an assignment while the vector is `names.map (· == lens)`. Those two
agree only if `NAMES` is duplicate-free: a repeated name matching the routed lens
would put two `1`s in the vector while `breadth` still said `1`, and the gauge
would then divide activity by the wrong breadth. Measured on disk: 9 names, 9
distinct, so the invariant holds **today**. It is stated below as a general theorem
about distinctness rather than as a fact about the current list, because a tenth
lens is a change the project may legitimately make and a spec that forbids a
correct future is a defect.

Values are fixed-point naturals: λ×10 and μ×100 exactly as
`hooks/rot-router.sh:362-363` ships them, σ×10000. Under one-hot activation the
`(1 + H)` factor is **exact, not approximated** — `H = a/breadth` is 1 for the
active lens at breadth 1 and 0 for every other case the router can reach.
-/

namespace RotMoE.LensActivation

/-! ## The lens roster, and the distinctness the assignment depends on -/

/-- The shipped lens order, quoted from `hooks/rot-router.sh:364` and identical in
`hooks/rot-router.ps1:152`. -/
def shippedNames : List String :=
  ["Nova", "Violet", "AntiVenom", "Venom", "Carnage", "Chroma", "Soleil",
   "Eidolon", "Claude"]

/-- Membership, self-contained so every proof here stands on its own recursion. -/
def mentions : List String → String → Bool
  | [], _ => false
  | n :: ns, l => (n == l) || mentions ns l

/-- Duplicate-freeness. -/
def distinct : List String → Bool
  | [] => true
  | n :: ns => !mentions ns n && distinct ns

/-- How many names actually match the routed lens — the TRUE count. -/
def hits : List String → String → Nat
  | [], _ => 0
  | n :: ns, l => (if n == l then 1 else 0) + hits ns l

/-- The activation vector the router builds: one bit per lens, set where the name
matches the single routed lens. -/
def routerVector (names : List String) (lens : String) : List Bool :=
  names.map (fun n => n == lens)

/-- The breadth actually present in a vector: how many bits are set. -/
def trueBreadth : List Bool → Nat
  | [] => 0
  | b :: bs => (if b then 1 else 0) + trueBreadth bs

/-- The breadth the router ASSIGNS — `_br=1` at `hooks/rot-router.sh:627` and
`$br = 1` at `hooks/rot-router.ps1:564`. Note it is an assignment, not a count. -/
def assignedBreadth (names : List String) (lens : String) : Nat :=
  if mentions names lens then 1 else 0

#guard shippedNames.length = 9
#guard distinct shippedNames = true
#guard assignedBreadth shippedNames "Claude" = 1
#guard trueBreadth (routerVector shippedNames "Claude") = 1
#guard trueBreadth (routerVector shippedNames "Gandalf") = 0

/-- The vector really does carry the count the name-matching implies. -/
theorem the_vector_counts_what_the_names_hit (names : List String) (lens : String) :
    trueBreadth (routerVector names lens) = hits names lens := by
  induction names with
  | nil => rfl
  | cons n ns ih =>
    simp only [routerVector, List.map_cons] at ih ⊢
    simp [trueBreadth, hits, ih]

/-- A lens absent from the roster is hit zero times. -/
theorem no_mention_means_no_hit (names : List String) (lens : String)
    (h : mentions names lens = false) : hits names lens = 0 := by
  induction names with
  | nil => rfl
  | cons n ns ih =>
    rw [mentions, Bool.or_eq_false_iff] at h
    simp [hits, h.1, ih h.2]

/-- A lens present on the roster is hit at least once. -/
theorem a_mention_is_at_least_one_hit (names : List String) (lens : String)
    (h : mentions names lens = true) : 1 ≤ hits names lens := by
  induction names with
  | nil => simp [mentions] at h
  | cons n ns ih =>
    rw [mentions, Bool.or_eq_true] at h
    cases h with
    | inl h1 => simp [hits, h1]
    | inr h2 =>
      have hh := ih h2
      simp only [hits]
      split <;> omega

/-- **Distinctness is what holds the count down.** Without it the roster could hit
the same routed lens twice. -/
theorem distinct_names_hold_the_count_to_one (names : List String) (lens : String)
    (h : distinct names = true) : hits names lens ≤ 1 := by
  induction names with
  | nil => simp [hits]
  | cons n ns ih =>
    rw [distinct, Bool.and_eq_true] at h
    have hm : mentions ns n = false := by simpa using h.1
    cases hn : (n == lens) with
    | false => simp only [hits, hn]; simpa using ih h.2
    | true =>
      have hln : n = lens := eq_of_beq hn
      subst hln
      have hz : hits ns n = 0 := no_mention_means_no_hit ns n hm
      simp [hits, hz]

/-- **The assignment is honest exactly because the names are distinct.** `_br=1`
agrees with the real number of set bits whenever the roster has no duplicates —
stated over every roster, so a tenth lens cannot invalidate it. -/
theorem the_assignment_is_honest_when_the_names_are_distinct
    (names : List String) (lens : String) (h : distinct names = true) :
    assignedBreadth names lens = trueBreadth (routerVector names lens) := by
  rw [the_vector_counts_what_the_names_hit]
  unfold assignedBreadth
  cases hm : mentions names lens with
  | false => simp [no_mention_means_no_hit names lens hm]
  | true =>
    have h1 := a_mention_is_at_least_one_hit names lens hm
    have h2 := distinct_names_hold_the_count_to_one names lens h
    simp only [if_pos]
    omega

/-- **And it lies without them.** A duplicated roster entry sets two bits while the
assignment still reports one — the gauge would then divide by the wrong breadth.
This is why the hypothesis above is load-bearing rather than decorative. -/
theorem a_duplicated_name_makes_the_assignment_undercount :
    assignedBreadth ["Nova", "Nova"] "Nova"
      ≠ trueBreadth (routerVector ["Nova", "Nova"] "Nova") := by decide

/-- Today's roster satisfies the hypothesis. Measured, and pinned. -/
theorem the_shipped_names_are_distinct : distinct shippedNames = true := by decide

/-! ## What the router can and cannot reach -/

/-- **Breadth never exceeds one, for any roster and any lens.** Not a property of
the corpus — a property of the construction. -/
theorem the_router_can_never_report_more_than_one_active_lens
    (names : List String) (lens : String) : assignedBreadth names lens ≤ 1 := by
  unfold assignedBreadth; split <;> omega

/-- **Fusion is unreachable.** The engine spec's `FUSE` would need breadth 2; no
input to the shipped builder produces it. -/
theorem fusion_is_unreachable (names : List String) (lens : String) :
    assignedBreadth names lens ≠ 2 := by
  have := the_router_can_never_report_more_than_one_active_lens names lens
  omega

/-- **The honest half: `breadth` distinguishes no two routed turns.** Any two
lenses on the roster yield the same breadth, so that field carries no information
about which turn it was. -/
theorem the_breadth_field_separates_no_two_routed_turns
    (names : List String) (l₁ l₂ : String)
    (h₁ : mentions names l₁ = true) (h₂ : mentions names l₂ = true) :
    assignedBreadth names l₁ = assignedBreadth names l₂ := by
  simp [assignedBreadth, h₁, h₂]

/-- Both breadths seen in 3707 live records are reachable, and only those. -/
theorem both_observed_breadths_are_reachable :
    assignedBreadth shippedNames "Claude" = 1
      ∧ assignedBreadth shippedNames "Gandalf" = 0 := by decide

/-! ## TIER 2 (NSIL): the builder that SHIPS NOW, in which breadth is COUNTED

Everything above this line models a router that assigned `_br=1` beside the bit
it had just written. That builder has been replaced, and the two theorems just
above -- `the_router_can_never_report_more_than_one_active_lens` and
`fusion_is_unreachable` -- are the reason this section exists rather than a
deletion.

**They were dated, not wrong.** Both are true of `assignedBreadth`, and
`assignedBreadth` was an honest model of the shipped code on the day it was
written. What they are not is invariants: they froze *"the feature has not been
built yet"* into a shape that reads like *"the feature can never exist"*. This
file's own header (line 60) already says a spec that forbids a correct future is
a defect; the rule simply had not been turned on its own theorems.

So they stay, scoped to the retired builder, and the durable property they were
groping toward is stated below over the builder that ships: **breadth is the
number of active lenses, and it never exceeds the roster.** That survives fusion,
survives elevation, and survives a tenth lens. -/

/-- The activation vector NSIL builds: one bit per roster name, set when that
lens is in the active set. `hooks/rot-router.sh` builds exactly this with a
membership test against `$_nsil_act`, and `hooks/rot-router.ps1` with
`$nsilAct -contains $n`. -/
def nsilVector (names : List String) (active : List String) : List Bool :=
  names.map (fun n => mentions active n)

/-- Breadth as the shipped router now computes it: **counted from the vector**,
never assigned beside it. This is the whole substantive change -- the field
became a measurement of the vector instead of an assertion about it. -/
def countedBreadth (names : List String) (active : List String) : Nat :=
  trueBreadth (nsilVector names active)

/-- **Breadth counts set bits, by construction.** True definitionally, which is
the point: there is no longer a gap between the number and the thing it counts,
so no distinctness hypothesis is needed to keep them honest. -/
theorem counted_breadth_is_the_number_of_set_bits
    (names active : List String) :
    countedBreadth names active = trueBreadth (nsilVector names active) := rfl

/-- **The durable replacement for `the_router_can_never_report_more_than_one_active_lens`.**
Breadth never exceeds the roster -- for ANY active set, including a malformed one
naming lenses that do not exist. Quantified over the roster, so a tenth lens
raises the ceiling automatically instead of falsifying the theorem. -/
theorem breadth_never_exceeds_the_roster (names active : List String) :
    countedBreadth names active ≤ names.length := by
  unfold countedBreadth nsilVector
  induction names with
  | nil => simp [trueBreadth]
  | cons n ns ih =>
    simp only [List.map_cons, trueBreadth, List.length_cons]
    split <;> omega

/-- **FUSE is reachable, and this is the exact case that was proved impossible.**
`fusion_is_unreachable` said breadth 2 could not happen. It can, and here is the
witness the shipped router prints as
`FORGE Claude [NSIL FUSE Nova+Claude] | R/s+ 0.73`. -/
theorem fusion_is_reachable :
    countedBreadth shippedNames ["Nova", "Claude"] = 2 := by decide

/-- **ELEVATE is reachable: the whole roster at once.** Printed by the shipped
router as `CONVERGENT opus[1m] [NSIL ELEVATE Nova+...+Claude]`. -/
theorem elevation_activates_the_whole_roster :
    countedBreadth shippedNames shippedNames = 9 := by decide

/-- The set NSIL activates on a FUSE turn: the lenses that fired, plus Nova.
`hooks/rot-router.sh` does this with a `case` guard, `.ps1` with `-notcontains`. -/
def fuseSet (fired : List String) : List String :=
  if mentions fired "Nova" then fired else "Nova" :: fired

/-- **NSIL is the *Nova* Sovereign Intent Layer, and the code obeys the name.**
A fused turn always carries Nova, whatever fired -- because the fusion is
something Nova DID, and a vector that omitted her would describe a decision with
no decider. Stated over every possible fired set, not the two that happen to be
common. -/
theorem nova_is_active_in_every_fusion (fired : List String) :
    mentions (fuseSet fired) "Nova" = true := by
  unfold fuseSet
  split
  · assumption
  · simp [mentions]

/-- **Nova is idempotent, so `breadth = 2` stays reachable.** When STRATEGIC is
one of the lanes that fired, joining Nova changes nothing -- the guard is not a
floor of 3 sneaked in under a different name. -/
theorem joining_nova_is_idempotent (fired : List String)
    (h : mentions fired "Nova" = true) : fuseSet fired = fired := by
  simp [fuseSet, h]

/-- `beq` on strings is symmetric. Needed only to line up the two vector
orientations below; `mentions` tests `name == query` and `routerVector` tests
`query == name`. -/
theorem string_beq_comm (a b : String) : (a == b) = (b == a) := by
  by_cases h : a = b
  · subst h; rfl
  · have h1 : (a == b) = false := beq_eq_false_iff_ne.mpr h
    have h2 : (b == a) = false := beq_eq_false_iff_ne.mpr (Ne.symm h)
    rw [h1, h2]

/-- **The single-lane turn did not move.** For a one-element active set the new
counted breadth equals the old assigned breadth, on any roster with distinct
names -- which is the formal statement of the measured fact that
`RoT MoE :: TIER 1 -> FORGE Claude | R/s+ 0.66` is byte-identical before and
after. The new layer ADDS reachable states; it does not disturb the old one. -/
theorem a_single_lane_turn_is_unchanged
    (names : List String) (lens : String) (h : distinct names = true) :
    countedBreadth names [lens] = assignedBreadth names lens := by
  have hv : nsilVector names [lens] = routerVector names lens := by
    unfold nsilVector routerVector
    apply List.map_congr_left
    intro n _
    simp [mentions, string_beq_comm]
  unfold countedBreadth
  rw [hv]
  exact (the_assignment_is_honest_when_the_names_are_distinct names lens h).symm

/-- Today's roster, elevated, is nine -- and nine is the roster length, not a
literal that would survive a tenth lens being added. -/
theorem elevation_is_exactly_the_roster_size :
    countedBreadth shippedNames shippedNames = shippedNames.length := by decide

/-! ## The gauge: nine terms, one doubled -/

/-- A lens as the gauge sees it: `λ` (×10), `σ(δ)` (×10000), `μ` (×100). -/
structure Lens where
  lam : Nat
  sig : Nat
  mu  : Nat
deriving DecidableEq, Repr

/-- Activity as a number: `a_i ∈ {0,1}`. -/
def hOne (a : Bool) : Nat := if a then 1 else 0

@[simp] theorem hOne_true : hOne true = 1 := rfl
@[simp] theorem hOne_false : hOne false = 0 := rfl

/-- The shipped division guard, `hooks/rot-router.sh:437`. -/
def guardedH (act breadth : Nat) : Nat :=
  if breadth > 0 then act / breadth else 0

/-- **The entropy factor is EXACT, not an approximation** — at every breadth the
router can actually produce, `H = a/breadth` is just `a`. This is what makes the
doubling below a faithful model rather than a convenient one. -/
theorem the_entropy_term_is_exact_at_every_breadth_the_router_can_produce
    (a : Bool) (b : Nat) (hb : b ≤ 1) (hab : a = true → b = 1) :
    guardedH (hOne a) b = hOne a := by
  cases a with
  | true =>
    have hb1 : b = 1 := hab rfl
    subst hb1
    decide
  | false => simp [guardedH, hOne]

/-- One lens's contribution: `λ · σ(δ) · μ · (1 + H)`. -/
def term (l : Lens) (a : Bool) : Nat := l.lam * l.sig * l.mu * (1 + hOne a)

/-- The ensemble sum, before the `1/K`. -/
def gauge (ls : List (Lens × Bool)) : Nat := (ls.map (fun p => term p.1 p.2)).sum

/-- The exact price of activation under one-hot: the routed lens counts double. -/
theorem the_active_lens_counts_exactly_double (l : Lens) :
    term l true = 2 * term l false := by
  simp only [term, hOne_true, hOne_false, Nat.add_zero, Nat.mul_one]
  omega

/-- **Every lens contributes a positive term, active or not.** This is the content
of `K = 9`: silence is not absence. -/
theorem every_lens_contributes_a_positive_term (l : Lens) (a : Bool)
    (hl : 0 < l.lam) (hs : 0 < l.sig) (hm : 0 < l.mu) : 0 < term l a := by
  unfold term
  have h1 : 0 < l.lam * l.sig := Nat.mul_pos hl hs
  have h2 : 0 < l.lam * l.sig * l.mu := Nat.mul_pos h1 hm
  have h3 : 0 < 1 + hOne a := by unfold hOne; split <;> omega
  exact Nat.mul_pos h2 h3

/-- **The gauge is not a function of the active lens alone.** Raise the weight of a
lens that did NOT fire and the number moves — quantified over every lens, every
tail and every increase, so no future weight table can make it false. This is the
theorem that earns the word "nine-lens" at breadth 1. -/
theorem raising_an_inactive_lens_raises_the_gauge
    (l : Lens) (rest : List (Lens × Bool)) (m : Nat)
    (hl : 0 < l.lam) (hs : 0 < l.sig) (h : l.mu < m) :
    gauge ((l, false) :: rest) < gauge (({ l with mu := m }, false) :: rest) := by
  have hp : 0 < l.lam * l.sig := Nat.mul_pos hl hs
  have hterm : term l false < term { l with mu := m } false := by
    simp only [term, hOne_false, Nat.add_zero, Nat.mul_one]
    exact Nat.mul_lt_mul_of_pos_left h hp
  simp only [gauge, List.map_cons, List.sum_cons]
  exact Nat.add_lt_add_right hterm _

/-- The same fact as a witness pair: identical active lens, different gauge. -/
theorem two_turns_can_share_an_active_lens_and_differ :
    ∃ x y : List (Lens × Bool),
      x.head? = y.head? ∧ gauge x ≠ gauge y := by
  refine ⟨[(⟨23, 8257, 115⟩, true), (⟨6, 1743, 85⟩, false)],
          [(⟨23, 8257, 115⟩, true), (⟨6, 1743, 86⟩, false)], ?_, ?_⟩ <;> decide

/-- The nine FORGE rows exactly as `hooks/rot-router.sh:362-363` ships them, with
Claude routed. σ is the one-hot pair: `σ(8/9) ≈ 0.8257` for the active lens,
`σ(1/9) ≈ 0.1743` for the eight silent ones. -/
def forgeClaudeTurn : List (Lens × Bool) :=
  [(⟨14, 1743, 105⟩, false),   -- Nova
   (⟨6,  1743, 85⟩,  false),   -- Violet
   (⟨19, 1743, 110⟩, false),   -- AntiVenom
   (⟨12, 1743, 105⟩, false),   -- Venom
   (⟨6,  1743, 90⟩,  false),   -- Carnage
   (⟨10, 1743, 110⟩, false),   -- Chroma
   (⟨10, 1743, 95⟩,  false),   -- Soleil
   (⟨12, 1743, 110⟩, false),   -- Eidolon
   (⟨23, 8257, 115⟩, true)]    -- Claude, routed

#guard forgeClaudeTurn.length = 9
#guard (forgeClaudeTurn.filter (fun p => p.2)).length = 1

/-- **Dropping the eight silent lenses changes the answer.** A router that scored
only the lens it routed to would report a different number on this exact turn, so
the other eight are load-bearing arithmetic and not ornament. -/
theorem silencing_the_eight_changes_the_answer :
    gauge forgeClaudeTurn ≠ gauge (forgeClaudeTurn.filter (fun p => p.2)) := by
  decide

/-- **The claim, bounded exactly.** On any routed turn the ensemble keeps all nine
terms while the router activates precisely one. Both halves in one statement, so
neither can be quoted without the other. -/
theorem the_ensemble_keeps_all_nine_while_the_router_activates_one
    (lens : String) (h : mentions shippedNames lens = true) :
    assignedBreadth shippedNames lens = 1
      ∧ (routerVector shippedNames lens).length = 9 := by
  constructor
  · simp [assignedBreadth, h]
  · simp [routerVector, shippedNames]

/-! ## TIER 3 — the complexity gate

`rot-lean.md` §3: "TIER 3 — complexity gate. TRIVIAL / STANDARD / DEEP. It
regulates ONLY how much thinking is spent, never whether the mechanism runs."

The router derives depth from **breadth** rather than from word-count cutoffs.
That choice is the whole point and is worth stating plainly: three invented
thresholds would be three constants nothing justifies, and constants nothing
justifies are what later get tuned until an output looks right. Deriving from
TIER 2 means the gate moves automatically if the FUSE or ELEVATE criteria ever
change, and there is no number to tune. -/

inductive Depth where
  | trivial
  | standard
  | deep
  deriving DecidableEq, Repr

/-- The shipped rule, transcribed from both arms. -/
def depthOf (breadth : Nat) : Depth :=
  if 2 ≤ breadth then Depth.deep
  else if breadth = 1 then Depth.standard
  else Depth.trivial

/-- **The gate is total and deterministic**: every breadth gets exactly one
depth. Trivial to state, and it is the property that makes the field safe to log
— a classifier with a gap would write an empty column that readers would take
for "not measured" rather than "not classified". -/
theorem every_breadth_has_exactly_one_depth (b : Nat) :
    depthOf b = Depth.trivial ∨ depthOf b = Depth.standard ∨ depthOf b = Depth.deep := by
  unfold depthOf
  split
  · exact Or.inr (Or.inr rfl)
  · split
    · exact Or.inr (Or.inl rfl)
    · exact Or.inl rfl

/-- **DEEP is exactly fusion.** The durable statement of the TIER 3 ↔ TIER 2
binding: a turn is deep precisely when two or more lenses contribute. Stated as
an iff over *every* breadth rather than as a table of the values that happen to
occur today, so widening the roster cannot falsify it. -/
theorem deep_iff_at_least_two_lenses (b : Nat) :
    depthOf b = Depth.deep ↔ 2 ≤ b := by
  unfold depthOf
  by_cases h1 : 2 ≤ b
  · simp [h1]
  · by_cases h2 : b = 1 <;> simp [h1, h2]

/-- **TRIVIAL is exactly silence**, and it is not the same as STANDARD. The
distinction matters because breadth 0 and breadth 1 produce nearly the same R/s+
(0.16 vs 0.47 measured), so the gauge alone cannot tell them apart — the depth
field can. -/
theorem trivial_iff_nothing_engaged (b : Nat) :
    depthOf b = Depth.trivial ↔ b = 0 := by
  unfold depthOf
  by_cases h1 : 2 ≤ b
  · simp [h1]; omega
  · by_cases h2 : b = 1
    · simp [h2]
    · simp [h1, h2]; omega

/-- The three depths are genuinely distinct constructors — a guard against the
classifier silently collapsing, which would make the column look populated while
carrying no information. -/
theorem the_three_depths_are_distinct :
    Depth.trivial ≠ Depth.standard ∧ Depth.standard ≠ Depth.deep
      ∧ Depth.trivial ≠ Depth.deep := by
  refine ⟨?_, ?_, ?_⟩ <;> decide

end RotMoE.LensActivation
