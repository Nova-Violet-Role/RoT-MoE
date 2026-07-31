/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

import Proofs.RotPath
import Proofs.RotInstall
import Proofs.RotRoute
import Proofs.RotGauge

/-!
# Non-vacuity audit — proving the hypotheses can actually be MET

## The failure this file exists to catch

`SECURITY.md` in this repo declares that **a theorem claiming more than it proves
is a security defect**, because the project's entire value is that its claims are
checkable. Having written that, the honest next step is to run the audit against
my own theorems — and the sharpest mechanical form of overclaim is **vacuity**.

A theorem with contradictory hypotheses is *true*, compiles green, passes
`#print axioms`, survives `leanchecker`, and says **nothing at all**:

```lean
theorem impressive_sounding_name (h : 0 = 1) : EverythingIsFine := by omega
```

Every instrument this repo already runs would report that as verified. None of
them asks the one question that matters: *can the hypotheses ever hold?*

## What this file does

For every hypothesis-carrying theorem in the packet, it **instantiates the
theorem at a concrete witness** and discharges each hypothesis by `decide` or
`rfl`. If any hypothesis set were unsatisfiable, the instantiation below would
not compile.

So `lake build Proofs.RotVacuity` exiting 0 is a positive statement:
**every guarded theorem in this packet has at least one real case it applies
to.** It is not a proof that the theorems are *useful* — nothing mechanical can
be — but it does rule out the one failure mode that is invisible to every other
gate here.

## Honest scope

This covers the theorems that carry hypotheses. Theorems with no hypotheses
cannot be vacuous in this sense (though they can still be weak, which is a
judgement call no checker makes for you). Where a hypothesis is a universally
quantified side condition about `Char`, the witness supplies it for the concrete
characters that actually occur — the same modelling decision documented in
`RotPath.lean`, applied consistently.
-/

namespace RotMoE.Vacuity

open RotMoE.Path RotMoE.Install RotMoE.Route

/-! ## RotPath -/

/-- `both_spellings_agree` carries FIVE hypotheses. If any pair of them were
contradictory the theorem would be vacuous, and it is the load-bearing theorem
of the whole path module — precisely the one worth checking hardest.

Witness: the real drive letter `C`. Every hypothesis is discharged by `decide`,
so this is executed evidence rather than an assumption. -/
example :
    normalize ('C' :: ':' :: '\\' :: "a/b".toList) =
      normalize ('/' :: 'c' :: '/' :: "a/b".toList) :=
  both_spellings_agree 'C' "a/b".toList (by decide) (by decide) (by decide)
    (by decide) (by decide)

/-- A second witness on a different letter, because a single instance can hide a
hypothesis that only one character happens to satisfy. -/
example :
    normalize ('X' :: ':' :: '\\' :: "tmp".toList) =
      normalize ('/' :: 'x' :: '/' :: "tmp".toList) :=
  both_spellings_agree 'X' "tmp".toList (by decide) (by decide) (by decide)
    (by decide) (by decide)

/-- `normalize_not_alpha_drive` takes a universally quantified side condition on
`Char`. A condition that no character satisfies would make it vacuous; here is a
character that does satisfy it, so the quantifier ranges over a non-empty set. -/
example : ('c' : Char).isAlpha = true ∧ ('c' : Char).toLower ≠ ':' := by decide

/-- `slashify_eq_self_of_no_backslash` needs a backslash-free path. Such paths
exist — every POSIX path is one. -/
example : slashify "/c/a/b".toList = "/c/a/b".toList :=
  slashify_eq_self_of_no_backslash (by decide)

/-! ## RotInstall -/

/-- The brand-new user's settings: no scalars, no hooks anywhere. This is the
state `checker/plugin-install.sh` exercises against the real installer. -/
def emptySettings : Settings := ⟨fun _ => none, fun _ => []⟩

/-! **The freshness hypothesis is the one most at risk of being vacuous**, and it
is the hypothesis that makes `disarm ∘ arm = id` true at all. If no `Settings`
could ever satisfy "this command appears under no key", the theorem would be an
elaborate way of saying nothing. -/
example : disarm "rot" (arm "rot" emptySettings) = emptySettings :=
  disarm_arm_id "rot" emptySettings (by intro k; simp [emptySettings])

/-- `arm_appends` requires a key in `armEvents` whose hook list lacks the
command. Both halves are satisfiable simultaneously — shown here rather than
assumed. -/
example :
    (arm "rot" emptySettings).hookEvents "UserPromptSubmit" = [] ++ ["rot"] :=
  arm_appends "rot" emptySettings "UserPromptSubmit" (by decide) (by simp [emptySettings])

/-- `arm_preserves_unrelated_events` quantifies over keys NOT in `armEvents`.
That set must be non-empty or the theorem protects nothing. It is: any key the
installer does not touch, such as `Stop`. -/
example : ("Stop" : String) ∉ armEvents := by decide

example :
    (arm "rot" emptySettings).hookEvents "Stop" = emptySettings.hookEvents "Stop" :=
  arm_preserves_unrelated_events "rot" emptySettings "Stop" (by decide)

/-- `addOnce_of_not_mem` needs a list genuinely lacking the element. -/
example : addOnce "b" ["a"] = ["a"] ++ ["b"] :=
  addOnce_of_not_mem (by decide)

/-! ## RotRoute -/

/-- `route_default_convergent` has a NINE-fold conjunction as its hypothesis.
That is the shape most likely to be quietly unsatisfiable — one flipped
polarity anywhere and no `Flags` value could satisfy it, leaving a theorem that
looks like it characterises the default lane while constraining nothing.

Witness: all flags false, which is the real all-quiet input. -/
example : route ⟨false, false, false, false, false, false, false, false, false⟩ = Mode.convergent :=
  route_default_convergent _
    ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- `forge_priority` needs `forge = true`, and must still hold when OTHER flags
are also set — that is the entire point of a priority claim. A witness with only
`forge` set would not test priority at all. -/
example :
    route ⟨true, true, true, false, false, false, false, false, false⟩ = Mode.forge :=
  forge_priority _ rfl

/-! ## RotGauge

`PosWeights` is a FIVE-field structure appearing as a hypothesis on most of the
gauge theorems. If no weight assignment could satisfy all five at once, the
entire gauge module would be vacuous — every theorem true, every gate green,
nothing said.

The witness below is deliberately **not** a convenient toy. It is the FORGE
profile that actually ships, with the λ and μ this project really uses, so the
witness answers the sharper question: not merely *can* the hypotheses be met, but
are they met **by the configuration in production**. A theorem that only applies
to weights nobody runs would be technically non-vacuous and practically useless.
-/

/-! **A duplicate was found here and removed, which is itself the audit working.**

This section originally defined its own nine-lens table and re-proved
`PosWeights` for it. Both already existed: `RotMoE.forge` at
`RotGauge.lean:432` and `RotMoE.forge_posWeights` at `:446`. Two tables of
the same shipping weights in one packet is a second source of truth, and the
checker that binds Lean to the shell was validating the COPY -- so the table
the gauge theorems actually use could have drifted from the router with every
gate still green. The witnesses below now use the real one. -/

open RotMoE in
/-- `gauge_pos` instantiated at the shipping profile: not vacuous, and true of
the configuration actually in use. Holds for EVERY activity vector and breadth,
so the witness does not depend on a lucky input either. -/
example (a : RotMoE.Face → Bool) (breadth : ℕ) :
    0 < RotMoE.gauge RotMoE.forge a breadth 1.05 0.7 0.8 :=
  RotMoE.gauge_pos RotMoE.forge_posWeights a breadth

open RotMoE in
/-- `gauge_ge_floor` needs only non-negativity, which follows from the same
witness — so its hypothesis is satisfiable too. -/
example (a : RotMoE.Face → Bool) (breadth : ℕ) :
    RotMoE.gauge RotMoE.forge (RotMoE.allQuiet RotMoE.Face) 0 1.05 0.7 0.8 ≤
      RotMoE.gauge RotMoE.forge a breadth 1.05 0.7 0.8 :=
  RotMoE.gauge_ge_floor (fun i => RotMoE.weight_nonneg RotMoE.forge_posWeights i) a breadth

open RotMoE in
/-- `gauge_not_constant` — the theorem that says the gauge is not a decorative
constant — instantiated at the shipping profile. This is the one that would be
most embarrassing to have proved vacuously. -/
example :
    RotMoE.gauge RotMoE.forge (RotMoE.allLive RotMoE.Face) 1 1.05 0.7 0.8 ≠
      RotMoE.gauge RotMoE.forge (RotMoE.allQuiet RotMoE.Face) 0 1.05 0.7 0.8 :=
  RotMoE.gauge_not_constant RotMoE.forge_posWeights

open RotMoE in
/-- `classify_above_iff` needs `lo ≤ hi`. Witnessed with the REAL FORGE band
`0.9 – 1.8`, not an arbitrary pair — the band this project publishes. -/
example (R : ℝ) : RotMoE.classify 0.9 1.8 R = RotMoE.Band.above ↔ 1.8 < R :=
  RotMoE.classify_above_iff (by norm_num)

end RotMoE.Vacuity
