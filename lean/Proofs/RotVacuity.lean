/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

import Proofs.RotPath
import Proofs.RotInstall
import Proofs.RotRoute

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

/-- **The freshness hypothesis is the one most at risk of being vacuous**, and
it is the hypothesis that makes `disarm ∘ arm = id` true at all. If no
`Settings` could ever satisfy "this command appears under no key", the theorem
would be an elaborate way of saying nothing.

Witness: the empty settings, which is exactly the brand-new user's state — the
case `checker/plugin-install.sh` exercises for real. -/
example :
    disarm "rot" (arm "rot" ⟨fun _ => none, fun _ => []⟩) = (⟨fun _ => none, fun _ => []⟩ : Settings) :=
  disarm_arm_id "rot" ⟨fun _ => none, fun _ => []⟩ (by intro k; simp)

/-- `arm_appends` requires a key in `armEvents` whose hook list lacks the
command. Both halves are satisfiable simultaneously — shown here rather than
assumed. -/
example :
    (arm "rot" ⟨fun _ => none, fun _ => []⟩).hookEvents "UserPromptSubmit" = [] ++ ["rot"] :=
  arm_appends "rot" ⟨fun _ => none, fun _ => []⟩ "UserPromptSubmit" (by decide) (by simp)

/-- `arm_preserves_unrelated_events` quantifies over keys NOT in `armEvents`.
That set must be non-empty or the theorem protects nothing. It is: any key the
installer does not touch, such as `Stop`. -/
example : ("Stop" : String) ∉ armEvents := by decide

example :
    (arm "rot" ⟨fun _ => none, fun _ => []⟩).hookEvents "Stop" = (⟨fun _ => none, fun _ => []⟩ : Settings).hookEvents "Stop" :=
  arm_preserves_unrelated_events "rot" ⟨fun _ => none, fun _ => []⟩ "Stop" (by decide)

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

end RotMoE.Vacuity
