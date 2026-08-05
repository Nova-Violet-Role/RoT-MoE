/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

/-!
# The gate split — what a commit is allowed to skip

## Why this file exists

`checker/gate-all.sh` ran every gate on every commit. Measured 2026-08-01, that
is **587 seconds**, and the file's own header comment warned that "a pre-commit
hook that takes four minutes is a hook people disable". It had become one. Two
commits were killed by a wall-clock ceiling mid-run, and one of those kills left
a live mutant plus four `.mutbak` files on disk.

So the set gets split: cheap gates run on every commit, expensive gates run when
the commit **touches something they check**, and everything runs in CI.

## The hazard this file exists to prevent

A tiered gate set is exactly the mechanism that already produced a false green
here once. `checker/verdict-schedule-sim.sh` sat behind `FULL=1`; the default
local sweep reported **26/26 GREEN** while that gate was red, and only CI
noticed. The lesson is not "be careful choosing tiers" — it is that a gate which
no realistic commit can trigger is **invisible**, and invisible looks identical
to green.

Hence `no_trigger_never_escalates`: a deep gate with an empty trigger list can
never be selected by any staged file set, for any file set whatsoever. That is
the silent hole, stated as a theorem so it can be checked rather than
remembered. `checker/gate-split.sh` then refuses any deep gate with no triggers.

## The durable form, and why the theorems are quantified

Everything below is stated over an **arbitrary** `gs : List Gate` and an
arbitrary staged set. A theorem about today's twenty-eight gate names would be
true today and would have to be deleted the first time a gate is added — which
is the failure mode where a correct change makes a spec go red and the obvious
repair destroys the coverage. The concrete twenty-eight appear only as `#guard`s
at the foot of the file: executed evidence about the present, never a hypothesis
anything rests on.

## What is NOT proved here

That `gate-all.sh` implements this selection. Lean constrains the MODEL. The
binding to the shipped runner is `checker/gate-split.sh`, which extracts the
real tier table out of the shell source and compares it against the witness
below, then asserts the properties the theorems make checkable. Neither
instrument substitutes for the other.
-/

namespace RotMoE.Gates

/-- When a gate runs.

`fast` gates run on **every** commit. `deep` gates run when a staged path fires
one of their triggers, and always in a full sweep. -/
inductive Tier where
  /-- Runs unconditionally, on every commit. -/
  | fast : Tier
  /-- Runs only when triggered by a staged path, or in a full sweep. -/
  | deep : Tier
  deriving DecidableEq, Repr

/-- A gate: what it is called, when it runs, and the path prefixes that force it
to run even when it is `deep`. -/
structure Gate where
  /-- The gate's name, as it appears in the runner's table. -/
  name : List Char
  /-- Whether it runs on every commit or only when triggered. -/
  tier : Tier
  /-- Path prefixes that escalate a `deep` gate into the run. -/
  triggers : List (List Char)
  deriving DecidableEq, Repr

/-- Decision procedure for the tier, as `Bool`, so every selection below is
executable and every concrete claim is `by decide`. -/
def isFast (g : Gate) : Bool :=
  match g.tier with
  | Tier.fast => true
  | Tier.deep => false

/-- One staged path fires a trigger if the trigger is a prefix of it. -/
def hits (trigger p : List Char) : Bool :=
  p.take trigger.length = trigger

/-- Does this commit's staged file set escalate this gate? -/
def fires (g : Gate) (staged : List (List Char)) : Bool :=
  staged.any (fun p => g.triggers.any (fun t => hits t p))

/-- The gates that run on every commit. -/
def fastSet (gs : List Gate) : List Gate :=
  gs.filter isFast

/-- The gates that run only on demand or when triggered. -/
def deepSet (gs : List Gate) : List Gate :=
  gs.filter (fun g => !isFast g)

/-- The run a commit actually gets: every fast gate, plus every deep gate the
staged paths escalated. -/
def stagedRun (gs : List Gate) (staged : List (List Char)) : List Gate :=
  gs.filter (fun g => isFast g || fires g staged)

/-! ### The partition is total — no gate can fall out of the table -/

/-- Every gate is in exactly one tier: the two selections cover the table. -/
theorem mem_tier_total (gs : List Gate) (g : Gate) :
    g ∈ gs ↔ g ∈ fastSet gs ∨ g ∈ deepSet gs := by
  simp only [fastSet, deepSet, List.mem_filter]
  cases hg : isFast g <;> simp_all

/-- The two tiers are disjoint: nothing runs twice. -/
theorem tiers_disjoint {gs : List Gate} {g : Gate}
    (h : g ∈ fastSet gs) : g ∉ deepSet gs := by
  simp only [fastSet, deepSet, List.mem_filter] at h ⊢
  simp [h.2]

/-- Counting version of the partition: no gate is lost and none is duplicated. -/
theorem tier_lengths (gs : List Gate) :
    (fastSet gs).length + (deepSet gs).length = gs.length := by
  induction gs with
  | nil => rfl
  | cons g gs ih =>
    simp only [fastSet, deepSet, List.filter_cons] at *
    cases hg : isFast g <;> simp_all <;> omega

/-! ### The run is sound — it never invents a gate and never drops a fast one -/

/-- A staged run never runs anything that is not in the table. -/
theorem stagedRun_subset {gs : List Gate} {staged : List (List Char)} {g : Gate}
    (h : g ∈ stagedRun gs staged) : g ∈ gs :=
  (List.mem_filter.mp h).1

/-- **Every fast gate runs on every commit**, whatever was staged. This is the
property the `FULL=1` regression violated. -/
theorem fast_always_runs {gs : List Gate} {staged : List (List Char)} {g : Gate}
    (h : g ∈ fastSet gs) : g ∈ stagedRun gs staged := by
  simp only [fastSet, List.mem_filter] at h
  simp only [stagedRun, List.mem_filter, h.1, true_and]
  simp [h.2]

/-- **A gate whose trigger was staged runs.** The load-bearing statement: this
is what makes the split safe rather than merely fast. -/
theorem triggered_gate_runs {gs : List Gate} {staged : List (List Char)}
    {g : Gate} (hmem : g ∈ gs) (hfire : fires g staged = true) :
    g ∈ stagedRun gs staged := by
  simp only [stagedRun, List.mem_filter, hmem, true_and]
  simp [hfire]

/-- Anything the commit skipped was deep, and was not triggered. Nothing else
can be skipped, for any reason. -/
theorem skipped_is_untriggered_deep {gs : List Gate} {staged : List (List Char)}
    {g : Gate} (hmem : g ∈ gs) (hskip : g ∉ stagedRun gs staged) :
    g.tier = Tier.deep ∧ fires g staged = false := by
  simp only [stagedRun, List.mem_filter, hmem, true_and, Bool.or_eq_true,
    not_or] at hskip
  refine ⟨?_, ?_⟩
  · cases h : g.tier with
    | fast => exact absurd (by simp [isFast, h]) hskip.1
    | deep => rfl
  · simpa using hskip.2

/-! ### The silent hole — a deep gate nothing can trigger -/

/-- **A gate with no triggers is invisible to every commit**, whatever is
staged. This is the shape of the `FULL=1` regression, and the reason
`checker/gate-split.sh` refuses a deep gate with an empty trigger list. -/
theorem no_trigger_never_escalates (g : Gate) (staged : List (List Char))
    (h : g.triggers = []) : fires g staged = false := by
  simp [fires, h]

/-- An empty commit runs exactly the fast set — no more, no less. -/
theorem stagedRun_nil (gs : List Gate) :
    stagedRun gs [] = fastSet gs := by
  simp [stagedRun, fastSet, fires]

/-! ### Staging more never runs less -/

/-- Firing is monotone in the staged set. -/
theorem fires_mono {g : Gate} {s t : List (List Char)} (hsub : ∀ p ∈ s, p ∈ t)
    (h : fires g s = true) : fires g t = true := by
  simp only [fires, List.any_eq_true] at h ⊢
  obtain ⟨p, hp, hq⟩ := h
  exact ⟨p, hsub p hp, hq⟩

/-- **Staging more files never shrinks the run.** A larger commit is always
checked at least as hard as a smaller one — so no commit can dodge a gate by
adding files to itself. -/
theorem stagedRun_mono {gs : List Gate} {s t : List (List Char)} {g : Gate}
    (hsub : ∀ p ∈ s, p ∈ t) (h : g ∈ stagedRun gs s) : g ∈ stagedRun gs t := by
  simp only [stagedRun, List.mem_filter, Bool.or_eq_true] at h ⊢
  refine ⟨h.1, ?_⟩
  rcases h.2 with hf | hfire
  · exact Or.inl hf
  · exact Or.inr (fires_mono hsub hfire)

/-- A full sweep is the whole table: any commit's run is contained in it. -/
theorem full_covers_every_run {gs : List Gate} {staged : List (List Char)}
    {g : Gate} (h : g ∈ stagedRun gs staged) : g ∈ gs :=
  stagedRun_subset h

/-! ### The shipped table — executed evidence, never a hypothesis

These `#guard`s pin the present. They are deliberately **not** theorems: a
theorem naming today's twenty-eight gates would go red the first time a gate is
added, and the obvious repair — deleting it — would remove real coverage. The
durable statements are the quantified ones above. -/

/-- A fast gate, written compactly. -/
private def f (n : String) : Gate :=
  { name := n.toList, tier := Tier.fast, triggers := [] }

/-- A deep gate with its triggering path prefixes. -/
private def d (n : String) (ts : List String) : Gate :=
  { name := n.toList, tier := Tier.deep, triggers := ts.map String.toList }

/-- The gate table as shipped, mirrored from `checker/gate-all.sh`.
`checker/gate-split.sh` compares this witness against the real runner. -/
def shipped : List Gate :=
  [ f "count-theorems selftest"
  , f "SPDX sweep"
  , f "no machine-local paths"
  , f "install-document lint"
  , f "licence bridge"
  , f "release consistency"
  , f "tag consistency"
  , f "verdict freshness"
  , f "mutation discipline"
  , f "dorks"
  , f "hook footprint"
  , f "Lean witness vs shipped weights"
  , f "release package"
  , f "hook contract"
  , f "workflow lint + drift"
  , f "cross-diff (both router arms)"
  -- Four gates joined on 2026-08-04, all FAST, and the tier is a decision worth
  -- recording. Each one guards a defect that had already reached a live machine:
  -- the double-fire, the dry run that deleted, the one-level proof scan, the
  -- debug log nothing read. A defect that has shipped once is not a candidate
  -- for "run it when someone touches the right directory" -- the double-fire was
  -- introduced by an INSTALL DOCUMENT, which stages no path a deep trigger would
  -- have matched. They cost seconds; they run every commit.
  , f "router duplication (plugin + ARM must not stack)"
  , f "disarm safety (--dry-run writes nothing, --all reaches plugin entries)"
  , f "remind measure (both arms, one tree, nested proof)"
  , f "log replay (every gauge record recomputed from its own fields)"
  , f "benchmark"
  , f "gate split"
  , d "repo completeness" ["README.md", "CHANGELOG.md", "STATUS.md", "lean/"]
  , d "cross-diff (both reminder arms)" ["hooks/prover-remind"]
  , d "verdict stability" ["STATUS.md", "checker/verdict"]
  , d "gauge cross" ["hooks/rot-router", "lean/Proofs/RotGauge.lean"]
  , d "profile binding" ["engine/rot-lean.md", "lean/Proofs/RotAbility.lean"]
  , d "axiom audit" ["lean/"]
  , d "axiom class" ["lean/"]
  , d "mutate the checker" ["checker/", "hooks/"]
  -- `lean/` joined 2026-08-05. The gate asserts that EVERY tracked `.sh` carries
  -- the exec bit in the index, but its trigger named only four path prefixes --
  -- so a new harness under `lean/mutate/` could never escalate the gate that
  -- checks it. Measured twice in one session: `mutate_rotensemble.sh` and
  -- `mutate_rotmutant.sh` both reached CI at mode 100644, and CI's Linux runner
  -- was the first thing to notice. A trigger narrower than the property it
  -- guards is a dead trigger for everything outside it.
  , d "portability" ["checker/", "hooks/", "lean/", "ARM_ROUTER", "DISARM_ROUTER", ".githooks/"]
  , d "installer round trip" ["ARM_ROUTER", "DISARM_ROUTER", "checker/install", ".claude-plugin/"]
  , d "install parity" ["ARM_ROUTER", "DISARM_ROUTER", "hooks/hooks.json", "hooks/settings-merge.js"]
  , d "release install" ["checker/release", ".claude-plugin/"]
  ]

-- Thirty-four gates: `profile binding` joined on 2026-08-03, deep tier; the
-- four installer/measurement/log gates on 2026-08-04, fast tier; `install
-- parity` on 2026-08-05, deep tier, after the two documented install paths were
-- measured to deliver DIFFERENT products (plugin 5 bindings / 3 events,
-- ARM_ROUTER 2 bindings / 2 events -- no installer had ever wired prover-remind).
#guard shipped.length = 34

-- Twenty-two run on every commit.
#guard (fastSet shipped).length = 22

-- Twelve are escalated by path (`install parity` joined 2026-08-05).
#guard (deepSet shipped).length = 12

-- The partition is total on the shipped table too, not just in principle.
#guard (fastSet shipped).length + (deepSet shipped).length = shipped.length

-- No shipped deep gate is invisible: every one has at least one trigger.
-- This is `no_trigger_never_escalates` used as a check, not as a warning.
#guard (deepSet shipped).all (fun g => !g.triggers.isEmpty)

-- No fast gate carries triggers -- they run anyway, so a trigger there would be
-- dead configuration that reads as protection.
#guard (fastSet shipped).all (fun g => g.triggers.isEmpty)

-- Editing a Lean proof escalates the gates that read Lean.
--
-- 26 -> 27 on 2026-08-05, and the number moved because the BEHAVIOUR moved:
-- `portability` gained `lean/` as a trigger, so a Lean edit now also re-checks
-- that every tracked `.sh` carries its exec bit. This guard is a measurement of
-- the trigger table, not an independent claim, so it is expected to follow the
-- table -- what would be wrong is editing it to keep a red build quiet while the
-- table said something else.
#guard (stagedRun shipped ["lean/Proofs/RotGauge.lean".toList]).length = 27

-- A commit that touches nothing runs exactly the fast set.
#guard (stagedRun shipped []).length = 22

-- Touching the router escalates the gates that cross-check it.
#guard (stagedRun shipped ["hooks/rot-router.sh".toList]).length = 25

-- A documentation-only commit still gets the completeness gate, because
-- `README.md` is one of its triggers.
#guard (stagedRun shipped ["README.md".toList]).length = 23

-- Every gate is reachable: some staged path escalates it. A gate no commit can
-- reach is the silent hole this file exists to prevent.
#guard shipped.all (fun g => isFast g || g.triggers.any (fun t => fires g [t]))

end RotMoE.Gates
