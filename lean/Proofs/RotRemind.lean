/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

/-!
# The reminder speaks only when it has something to say

## Why this file exists

Organ 4 (`hooks/prover-remind.sh` and `.ps1`) exists because its ancestor
emitted the same paragraph on every turn until it became **wallpaper** — present,
ignored, and therefore worse than absent, because its presence implied someone
was watching. The cure was to make silence the healthy state and speech
conditional on a *measurement*.

`checker/cross-diff-remind.sh` establishes that the two arms agree byte for byte
on 23 corpus rows. That is a strong statement about **those rows**. It says
nothing about the row nobody wrote — and the properties that matter here are
universal:

* it is **silent** whenever there is genuinely nothing to report, for *every*
  event and *every* alarm count;
* once something *is* wrong it **cannot fall silent again** by the mere passage
  of time;
* a **kernel rejection always speaks**, whatever else is true.

Those quantify over infinitely many inputs. A corpus samples; this settles.

## What is modelled, and what is not

Modelled: the `decide` function's *branch* — speak or stay silent — as a
function of the six measured signals, exactly as both shell arms compute it.

**NOT modelled: the message text.** Whether the two arms produce byte-identical
prose is the cross-diff's job and is checked there. A theorem about strings
assembled by `printf` would be a theorem about my transcription of `printf`.
That boundary is deliberate and is stated in `NOTICE.md` §B.

The threshold is a **parameter**, never the constant 45. A theorem stated about
today's default would freeze a value the project may legitimately retune, and
would then go red on a correct change — the failure mode this repository calls a
dated spec. The shipped default appears once, in an `example`, as a fact about
the present rather than a hypothesis anything rests on.
-/

namespace RotRemind

/-- The six signals the reminder measures before it decides anything.

`mins` is an `Int` on purpose: the shell arms use **-1** to encode *"no `.lean`
files were found in the configured workspace"*, which is a different situation
from "a proof was written 0 minutes ago" and must not be silently folded into
it. Modelling it as `Nat` would erase the distinction the code actually makes. -/
structure Signals where
  /-- minutes since the most recent proof; `-1` means "no proofs found at all" -/
  mins : Int
  /-- uncommitted source files carrying cast/clamp/bound code -/
  debt : List String
  /-- modules the kernel re-check REJECTED -/
  kernelRed : List String
  /-- modules containing `sorry` -/
  kernelSorry : List String
  /-- open alarm rows in the goal file -/
  alarms : Nat
  deriving DecidableEq, Repr

/-- The silence branch, transcribed from `decide` in `hooks/prover-remind.sh`:

```sh
if [ "$_nd" -eq 0 ] && [ "$_mins" -ge 0 ] && [ "$_mins" -lt "$STALE_MIN" ] \
   && [ "$_nr" -eq 0 ] && [ "$_ns" -eq 0 ]; then
  return 1
fi
```

Note what is **absent** from that condition: `alarms`. Open alarms alone do not
make the reminder speak, and `silent_regardless_of_alarms` below proves the
model has that same shape rather than merely claiming it. -/
def silent (T : Int) (s : Signals) : Prop :=
  s.debt = [] ∧ 0 ≤ s.mins ∧ s.mins < T ∧ s.kernelRed = [] ∧ s.kernelSorry = []

instance (T : Int) (s : Signals) : Decidable (silent T s) := by
  unfold silent; infer_instance

/-- The reminder speaks exactly when it is not silent. -/
def speaks (T : Int) (s : Signals) : Prop := ¬ silent T s

instance (T : Int) (s : Signals) : Decidable (speaks T s) := by
  unfold speaks; infer_instance

/-! ## The characterisation, both directions -/

/-- **Speech is exactly the disjunction of the five reasons.**

Stated as an `↔` on purpose. One direction alone would leave the interesting
failure uncaught: an implementation that speaks *more* often than its reasons
justify still satisfies "if there is debt then it speaks", and that is precisely
the wallpaper regression this organ exists to prevent. -/
theorem speaks_iff (T : Int) (s : Signals) :
    speaks T s ↔
      (s.debt ≠ [] ∨ s.mins < 0 ∨ T ≤ s.mins ∨
       s.kernelRed ≠ [] ∨ s.kernelSorry ≠ []) := by
  unfold speaks silent
  constructor
  · intro h
    by_cases hd : s.debt = []
    · by_cases hlo : 0 ≤ s.mins
      · by_cases hhi : s.mins < T
        · by_cases hr : s.kernelRed = []
          · by_cases hs : s.kernelSorry = []
            · exact absurd ⟨hd, hlo, hhi, hr, hs⟩ h
            · exact Or.inr (Or.inr (Or.inr (Or.inr hs)))
          · exact Or.inr (Or.inr (Or.inr (Or.inl hr)))
        · exact Or.inr (Or.inr (Or.inl (by omega)))
      · exact Or.inr (Or.inl (by omega))
    · exact Or.inl hd
  · rintro (hd | hm | hm | hr | hs) ⟨h1, h2, h3, h4, h5⟩
    · exact hd h1
    · omega
    · omega
    · exact hr h4
    · exact hs h5

/-! ## Silence is the healthy state -/

/-- **Nothing wrong ⇒ nothing said, for EVERY alarm count.**

The `alarms` field is universally quantified, which is the load-bearing part:
it proves open alarms alone never trigger the reminder. That is not an
aesthetic choice — this repository routinely runs with a dozen open alarm rows,
and a reminder that fired on them would speak on every single turn and become
the wallpaper it replaced. -/
theorem silent_regardless_of_alarms (T : Int) (m : Int) (a : Nat)
    (hlo : 0 ≤ m) (hhi : m < T) :
    silent T { mins := m, debt := [], kernelRed := [], kernelSorry := [],
               alarms := a } := by
  exact ⟨rfl, hlo, hhi, rfl, rfl⟩

/-- **A kernel rejection always speaks** — whatever the freshness, the debt, or
the alarm count. The kernel's verdict outranks every other signal, and this says
so over all inputs rather than on the corpus rows that happen to exercise it. -/
theorem kernel_red_always_speaks (T : Int) (s : Signals) (h : s.kernelRed ≠ []) :
    speaks T s := by
  rw [speaks_iff]
  exact Or.inr (Or.inr (Or.inr (Or.inl h)))

/-- A `sorry` always speaks, on the same footing. A `sorry` is an admission, and
an admission that can be aged out by a clock is not an admission. -/
theorem sorry_always_speaks (T : Int) (s : Signals) (h : s.kernelSorry ≠ []) :
    speaks T s := by
  rw [speaks_iff]
  exact Or.inr (Or.inr (Or.inr (Or.inr h)))

/-- Debt always speaks. -/
theorem debt_always_speaks (T : Int) (s : Signals) (h : s.debt ≠ []) :
    speaks T s := by
  rw [speaks_iff]
  exact Or.inl h

/-! ## Time can only make it worse, never better -/

/-- **Monotone in staleness.** If the reminder speaks at `m₁` minutes, it still
speaks at any later `m₂` with everything else unchanged.

This is the anti-amnesia property. A reminder that went quiet as the debt got
*older* would be exactly backwards, and no finite corpus can rule it out — the
row that breaks it is always the next one.

**The hypothesis `0 ≤ m₁` is not decoration, and it was not there first.** The
statement was written without it, the compiler refused, and it was right to:
`-1` does not mean "one minute ago", it means *"no proofs were found at all"*.
A tree that reported `-1` and later reports `10` has acquired proofs, and going
quiet is then the correct behaviour, not amnesia. `stale_monotone_needs_nonneg`
below proves the hypothesis cannot be dropped, so this is a real side condition
rather than a convenient one. -/
theorem stale_monotone (T : Int) (s : Signals) (m₁ m₂ : Int)
    (hnn : 0 ≤ m₁) (hle : m₁ ≤ m₂) (h : speaks T { s with mins := m₁ }) :
    speaks T { s with mins := m₂ } := by
  rw [speaks_iff] at h ⊢
  simp only at h ⊢
  rcases h with hd | hm | hm | hr | hs
  · exact Or.inl hd
  · omega
  · exact Or.inr (Or.inr (Or.inl (by omega)))
  · exact Or.inr (Or.inr (Or.inr (Or.inl hr)))
  · exact Or.inr (Or.inr (Or.inr (Or.inr hs)))

/-- **The freshness hypothesis above cannot be dropped**, and here is the
witness: at `-1` the reminder speaks (no proofs found), at `10` it is silent
(a proof exists and is recent), and `-1 ≤ 10`.

Stated as a theorem rather than left as a remark, because "this hypothesis is
necessary" is exactly the kind of claim that quietly stops being true. -/
theorem stale_monotone_needs_nonneg :
    ∃ (T m₁ m₂ : Int) (s : Signals), m₁ ≤ m₂ ∧
      speaks T { s with mins := m₁ } ∧ ¬ speaks T { s with mins := m₂ } := by
  refine ⟨45, -1, 10,
    { mins := 0, debt := [], kernelRed := [], kernelSorry := [], alarms := 0 },
    by omega, ?_, ?_⟩ <;> decide

/-! ## The threshold is a parameter, not the number 45 -/

/-- **Lowering the threshold can only add speech, never remove it.**

Quantified over both thresholds, so it survives any retune of
`ROTMOE_PROOF_STALE_MIN`. A theorem written about `45` would be true today and
would go red on a legitimate change — a dated spec, which this project treats as
a defect in the spec rather than in the change. -/
theorem lower_threshold_speaks_more (T₁ T₂ : Int) (s : Signals)
    (hle : T₁ ≤ T₂) (h : speaks T₂ s) : speaks T₁ s := by
  rw [speaks_iff] at h ⊢
  rcases h with hd | hm | hm | hr | hs
  · exact Or.inl hd
  · exact Or.inr (Or.inl hm)
  · exact Or.inr (Or.inr (Or.inl (by omega)))
  · exact Or.inr (Or.inr (Or.inr (Or.inl hr)))
  · exact Or.inr (Or.inr (Or.inr (Or.inr hs)))

/-! ## Non-vacuity: both branches are inhabited

A characterisation theorem is worthless if one side is empty. These are
`example`s evaluated by the kernel — concrete instances, so a green build is a
positive statement that each branch really happens. -/

/-- A clean tree at the shipped default: silent. -/
example : silent 45 { mins := 10, debt := [], kernelRed := [], kernelSorry := [],
                      alarms := 14 } := by decide

/-- **`silent_regardless_of_alarms` instantiated at a real witness.**

`#print axioms` reports that theorem as depending on *no axioms at all*, which
in this repository is treated as a vacuity smell rather than a badge: a theorem
whose hypotheses can never be satisfied is trivially true and says nothing.
This discharges the doubt by applying it — 14 open alarms, a proof 10 minutes
old, the shipped threshold — so the hypotheses are demonstrably inhabited. -/
example : silent 45 { mins := 10, debt := [], kernelRed := [], kernelSorry := [],
                      alarms := 14 } :=
  silent_regardless_of_alarms 45 10 14 (by decide) (by decide)

/-- The same tree 45 minutes later: speaks. The boundary is inclusive (`T ≤ mins`),
matching `[ "$_mins" -ge "$STALE_MIN" ]` in the shell and `-ge` in PowerShell —
the exact character that mutant H21/H22 flips. -/
example : speaks 45 { mins := 45, debt := [], kernelRed := [], kernelSorry := [],
                      alarms := 0 } := by decide

/-- One minute earlier: still silent. The pair pins the boundary from both
sides, which is what makes the off-by-one mutant detectable. -/
example : silent 45 { mins := 44, debt := [], kernelRed := [], kernelSorry := [],
                      alarms := 0 } := by decide

/-- `-1` — no proofs found at all — speaks, even though `-1 < 45`. -/
example : speaks 45 { mins := -1, debt := [], kernelRed := [], kernelSorry := [],
                      alarms := 0 } := by decide

/-- A kernel rejection on a freshly-proved tree still speaks. -/
example : speaks 45 { mins := 0, debt := [], kernelRed := ["Proofs.RotGauge"],
                      kernelSorry := [], alarms := 0 } := by decide

/-- **The shipped default, recorded as a FACT ABOUT THE PRESENT and nothing
more.** It is an `example`, deliberately not a theorem and not a hypothesis
anything else uses, so retuning the default cannot make any proof above false.
`checker/cross-diff-remind.sh` is what binds this number to the two shell arms;
Lean cannot see a shell variable. -/
example : (45 : Int) = 45 := rfl

/-! ## Executable mirror

The definitions compute, so the spec can be checked against concrete inputs
without a proof — the cheapest way to notice that a definition does not mean
what its name suggests. -/

/-- Decision for a row, as the corpus would express it. -/
def verdict (T : Int) (s : Signals) : String :=
  if silent T s then "SILENT" else "SPEAKS"

#guard verdict 45 { mins := 10, debt := [], kernelRed := [], kernelSorry := [],
                    alarms := 14 } = "SILENT"
#guard verdict 45 { mins := 45, debt := [], kernelRed := [], kernelSorry := [],
                    alarms := 0 } = "SPEAKS"
#guard verdict 45 { mins := 44, debt := ["mod.rs"], kernelRed := [],
                    kernelSorry := [], alarms := 0 } = "SPEAKS"
#guard verdict 45 { mins := -1, debt := [], kernelRed := [], kernelSorry := [],
                    alarms := 0 } = "SPEAKS"

end RotRemind
