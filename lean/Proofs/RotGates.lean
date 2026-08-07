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
  -- FAST because it reads two files in this repository and compares them to
  -- each other. A hook with no declared timeout is killed at the platform
  -- default and contributes nothing, which is indistinguishable from never
  -- having fired -- so this must run on every commit, not only when hooks/ is
  -- touched: the bound can be broken by editing the merge script alone.
  , f "hook timeout"
  -- FAST, and deliberately so. It replaced a `checkers`-job step that could only
  -- ever SKIP (gauge-cross needs a Lean workspace that job has not got), so it
  -- must run on EVERY commit rather than only when a trigger path is touched --
  -- a deep tier here would recreate the hole it was written to close.
  , f "gauge hook corpus"
  , f "Lean witness vs shipped weights"
  , f "release package"
  , f "hook contract"
  , f "workflow lint + drift"
  -- FAST, and the tier is the whole point of this one. It guards the FIRST
  -- INSTRUCTION a new reader follows: the README told three tiers to download
  -- `rot-moe-0.5.x-*.zip` while the packager built `0.7.x`, for two minor
  -- versions, with every gate green. A deep tier would have let that ship again
  -- on any commit that did not touch the release paths -- and a README edit is
  -- exactly such a commit.
  , f "README download links vs the packager"
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
  , d "CI honesty (no skip, no fake green) -- exit 3 SKIP without a credential" [".github/workflows/"]
  ]

-- Thirty-six gates: `profile binding` joined on 2026-08-03, deep tier; the
-- four installer/measurement/log gates on 2026-08-04, fast tier; `install
-- parity` on 2026-08-05, deep tier, after the two documented install paths were
-- measured to deliver DIFFERENT products (plugin 5 bindings / 3 events,
-- ARM_ROUTER 2 bindings / 2 events -- no installer had ever wired prover-remind);
-- `CI honesty` on 2026-08-05, deep tier, after run 31035932155 concluded
-- `success` with EIGHT skipped steps -- one of them `tty guard`, a real check
-- that had never run on Windows or macOS.
#guard shipped.length = 38

-- Twenty-three run on every commit.
#guard (fastSet shipped).length = 25

-- Thirteen are escalated by path (`CI honesty` joined 2026-08-05).
#guard (deepSet shipped).length = 13

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
#guard (stagedRun shipped ["lean/Proofs/RotGauge.lean".toList]).length = 30

-- A commit that touches nothing runs exactly the fast set.
--
-- All four numbers below moved by exactly +1 on 2026-08-05 for one reason: the
-- `README download links vs the packager` gate joined the FAST tier. A fast gate
-- is in every run by construction, so every one of these measurements shifts
-- together -- and if they had NOT all moved together, that would be the
-- interesting result, because it would mean the new gate is not actually
-- unconditional. They follow the table; they never lead it.
#guard (stagedRun shipped []).length = 25

-- Touching the router escalates the gates that cross-check it.
#guard (stagedRun shipped ["hooks/rot-router.sh".toList]).length = 28

-- A documentation-only commit still gets the completeness gate, because
-- `README.md` is one of its triggers.
#guard (stagedRun shipped ["README.md".toList]).length = 26

-- Every gate is reachable: some staged path escalates it. A gate no commit can
-- reach is the silent hole this file exists to prevent.
#guard shipped.all (fun g => isFast g || g.triggers.any (fun t => fires g [t]))

/-! ## CI HONESTY — no skip, no fake green, every warning a SUCCESS

Everything above is about **commit time**, where a bounded skip is legitimate:
a deep gate that no staged path triggers did not run, and the hook says so out
loud. CI is a different regime with a different law, and this section states it.

**The rule.** *Closing fake green — by deleting a check, by skipping one, by
weakening a theorem, or by disarming a working implementation — is a violation.
Every job of a CI run must be perfect: no skip, no fake green, every warning a
SUCCESS.*

**The rule is absolute: NO SKIP.** Not "no unjustified skip".

An earlier version of this section split steps into `provision` and `verify` and
proved that a provisioning step *may* skip — on the argument that installing a
Linux locale on macOS is meaningless. That was **the rule being weakened to fit
the CI**, which is the precise thing the rule forbids. An exemption class is a
list of checks that stopped being enforced, and it grows.

Measured on run `31035932155` (2026-08-05, `main`, concluded `success`): **eight
steps skipped**, across four workflow steps each scoped by `if: runner.os`.

| step | was scoped to | asserted on the other two legs |
|---|---|---|
| `install comma-decimal locales` | Linux | nothing |
| `provide zip on the Windows runner` | Windows | nothing |
| `provide gtimeout on the macOS runner` | macOS | nothing |
| `tty guard -- the router must not block on a terminal` | Linux | **nothing** |

The last one is a genuine check: the router's tty behaviour was **never tested
on Windows or macOS**, and the run still reported not-red. The correct repair is
not an exemption — it is a workflow where nothing skips. All four steps now run
on every platform and branch *inside*, so each concludes `success` everywhere
and the log carries the reason instead of a gap.

This is `bc1272d` — *"gauge-cross had NEVER run, skipped in every job, green the
whole cycle"* — generalised from an incident into a law. Under the old split it
needed a special theorem; under `no skip` it needs none, because there is no
skip that is acceptable.
-/

/-- What CI reports for a job or step. `neutral` and `cancelled` are included
because both render as "not red" and neither is a pass. -/
inductive Outcome where
  | success | failure | cancelled | skipped | neutral
  deriving DecidableEq, Repr

/-- One step, as it appeared in one job of one run. There is deliberately **no
`kind` field**: an earlier draft carried `provision | verify` so that
provisioning could be excused, and that field was the exemption mechanism in
structural form. Removing it is what makes the law unweakenable — there is
nowhere to put "this one does not count". -/
structure Step where
  name : String
  outcome : Outcome
  deriving DecidableEq, Repr

/-- **Only `success` is green.** This is the anti-fake-green predicate: four of
the five outcomes render as "not a failure" in a CI UI and exactly one of them
is a pass. -/
def isGreen (o : Outcome) : Bool :=
  match o with
  | .success => true
  | _ => false

/-- A step *ran* if it was not skipped. Running and passing are different
questions, and conflating them is how a red step gets read as absent. -/
def didRun (s : Step) : Bool := s.outcome != Outcome.skipped

/-- A run is a list of steps gathered from **every job**, not from one. -/
abbrev Run := List Step

/-- **No step was skipped.** -/
def noSkip (r : Run) : Bool := r.all didRun

/-- **Every step concluded success.** -/
def allGreen (r : Run) : Bool := r.all (fun s => isGreen s.outcome)

/-- Steps GitHub **injects**, which the repository does not author. Matched by
exact name or the `Post ` prefix, narrowly, so an authored step cannot drift in.

This is *not* the `kind` field returning. `kind` let a step declare itself
excusable; this predicate reads a name GitHub assigns and, crucially, buys an
exemption from **one** rule only — see `stepIsAcceptable`. -/
def Step.isScaffolding (s : Step) : Bool :=
  s.name == "Set up job" || s.name == "Complete job" || "Post ".isPrefixOf s.name

/-- **The per-step verdict, and the asymmetry is the whole content.**

Run `31045719329` forced this. Its two `Post Run actions/checkout@v7` steps
concluded `failure`, and the checker — which exempted scaffolding from *both*
rules — would have called the run honest. The exemption was correct for one
rule and catastrophic for the other:

* **skipped** — GitHub decides whether to run its own cleanup. Tolerated for
  scaffolding, never for an authored step.
* **failure** — nothing may fail, whoever wrote it. A broken cleanup is a
  broken run.

So the `skipped` arm consults `isScaffolding` and the failure arms do not. -/
def stepIsAcceptable (s : Step) : Bool :=
  match s.outcome with
  | .success => true
  | .skipped => s.isScaffolding
  | _        => false

/-- **The CI honesty verdict.** -/
def runIsHonest (r : Run) : Bool := r.all stepIsAcceptable

/-- An authored step must have run; scaffolding is excused *this* rule alone. -/
def authoredRan (s : Step) : Bool := s.isScaffolding || didRun s

/-- **No authored step was skipped.** -/
def noSkipAuthored (r : Run) : Bool := r.all authoredRan

/-! ### The law -/

/-- Skipping is not passing. -/
theorem skipped_is_not_green : isGreen Outcome.skipped = false := by decide

/-- Neither is being cancelled, which is how the `v0.7.0` tag run concluded. -/
theorem cancelled_is_not_green : isGreen Outcome.cancelled = false := by decide

/-- Nor `neutral`, the outcome a step gets when it reports without asserting. -/
theorem neutral_is_not_green : isGreen Outcome.neutral = false := by decide

/-- **Exactly one of the five outcomes is a pass.** Stated over the whole type
rather than as three separate facts, so a sixth outcome could not slip in as
green by default. -/
theorem success_is_the_only_green (o : Outcome) : isGreen o = true ↔ o = .success := by
  cases o <;> simp [isGreen]

/-- **ANY skipped authored step sinks the run.** Quantified over an arbitrary
name, with the single hypothesis that the step is one the repository wrote.

The hypothesis is new and it is a real narrowing, so it is flagged rather than
buried: the previous version quantified over *every* name and so claimed a
skipped `Post Run actions/checkout` was dishonest too. That was stricter than
the checker and stricter than reality — GitHub skips its own cleanup as normal
operation, and a law that calls normal operation dishonest is a law someone
later deletes. The authored case, which is the case the rule exists for, is
unchanged and still admits no exemption. -/
theorem any_authored_skip_is_dishonest (n : String)
    (hauth : (Step.mk n .skipped).isScaffolding = false) :
    runIsHonest [⟨n, .skipped⟩] = false := by
  simp [runIsHonest, stepIsAcceptable, hauth]

/-- **Skipping in one job is not redeemed by running in another.** The old law
allowed this ("scoped but live") and it is precisely how `tty guard` went
untested on two platforms while the run stayed green. -/
theorem skipping_somewhere_is_still_dishonest (n : String)
    (hauth : (Step.mk n .skipped).isScaffolding = false) :
    runIsHonest [⟨n, .skipped⟩, ⟨n, .success⟩] = false := by
  simp [runIsHonest, stepIsAcceptable, hauth]

/-- A step that ran and failed sinks the run. -/
theorem failure_sinks_the_run (n : String) :
    runIsHonest [⟨n, .failure⟩] = false := by
  simp [runIsHonest, stepIsAcceptable]

/-- **The theorem run `31045719329` paid for.** Scaffolding buys an exemption
from the skip rule and *only* from the skip rule: a `Post ` step that FAILS is
still dishonest. No hypothesis — this holds for every scaffolding name there
is, which is exactly what the checker's loop must do. -/
theorem scaffolding_failure_is_still_dishonest (n : String) :
    runIsHonest [⟨"Post " ++ n, .failure⟩] = false := by
  simp [runIsHonest, stepIsAcceptable]

/-- And the concrete pair that was green in that run's checker. -/
theorem post_checkout_failure_is_dishonest :
    runIsHonest [ ⟨"Post Run actions/checkout@v7", .failure⟩
                , ⟨"Post Run actions/checkout@v7", .failure⟩ ] = false := by
  decide

/-- The other half of the asymmetry, stated so it cannot silently invert:
scaffolding that is *skipped* is tolerated. Without this the exemption would be
unreachable and the two rules would collapse back into one. -/
theorem scaffolding_skip_is_tolerated :
    runIsHonest [⟨"Post Run actions/checkout@v7", .skipped⟩] = true := by
  -- `decide` cannot close this: `String.isPrefixOf`'s `Decidable` instance does
  -- not reduce in the kernel (measured -- `decide` and `rfl` both refuse).
  -- `simp` unfolds it instead. The `#guard`s below are unaffected: they run in
  -- the interpreter, which evaluates it fine.
  simp [runIsHonest, stepIsAcceptable, Step.isScaffolding, String.isPrefixOf]

/-- So does `cancelled`, and so does `neutral` — the two outcomes that render as
"not red" and assert nothing. Neither is excused for scaffolding either. -/
theorem cancelled_sinks_the_run (n : String) :
    runIsHonest [⟨n, .cancelled⟩] = false := by
  simp [runIsHonest, stepIsAcceptable]

theorem neutral_sinks_the_run (n : String) :
    runIsHonest [⟨n, .neutral⟩] = false := by
  simp [runIsHonest, stepIsAcceptable]

/-- **The exemption cannot leak.** For an arbitrary step, being scaffolding
changes the verdict *only* when the outcome is `skipped`. This is the theorem
that makes the asymmetry load-bearing rather than a comment: no future edit can
widen `isScaffolding` into a way of excusing a failure, because acceptability
for every non-skipped outcome does not mention it. -/
theorem scaffolding_matters_only_for_skips (s : Step) (h : s.outcome ≠ .skipped) :
    stepIsAcceptable s = isGreen s.outcome := by
  cases hc : s.outcome <;> simp [stepIsAcceptable, isGreen, hc] <;>
    exact absurd hc h

/-- **`no authored skip` is entailed, not assumed.** Derived from the verdict
alone — so no future edit can satisfy `runIsHonest` while skipping a check. -/
theorem no_authored_skip_is_implied {r : Run} (hr : runIsHonest r = true) :
    noSkipAuthored r = true := by
  simp only [noSkipAuthored, List.all_eq_true]
  intro s hs
  have h := List.all_eq_true.mp hr s hs
  simp only [stepIsAcceptable] at h
  cases hc : s.outcome <;> rw [hc] at h <;> simp_all [authoredRan, didRun]

/-- **Nothing in an honest run failed** — scaffolding included, no hypothesis.
This is the rule-2 counterpart, and the one the checker's loop implements. -/
theorem honest_run_has_no_failure {r : Run} {s : Step}
    (hr : runIsHonest r = true) (hmem : s ∈ r) :
    s.outcome ≠ .failure := by
  have h := List.all_eq_true.mp hr s hmem
  simp only [stepIsAcceptable] at h
  intro hf
  rw [hf] at h
  simp at h

/-- An honest run's every step is green, *unless* it is scaffolding GitHub
skipped. Stated over an arbitrary member, so it covers runs of any size. -/
theorem honest_run_step_is_green_or_scaffolding_skip {r : Run} {s : Step}
    (hr : runIsHonest r = true) (hmem : s ∈ r) :
    isGreen s.outcome = true ∨ (s.outcome = .skipped ∧ s.isScaffolding = true) := by
  have h := List.all_eq_true.mp hr s hmem
  simp only [stepIsAcceptable] at h
  cases hc : s.outcome <;> rw [hc] at h <;> simp at h
  · exact Or.inl (by simp [isGreen])
  · exact Or.inr ⟨rfl, h⟩

/-- **An authored step in an honest run is green, full stop.** The corollary
that matters for the user-facing rule: for anything the repository wrote, the
exemption is not available and `success` is the only outcome allowed. -/
theorem honest_run_authored_step_is_green {r : Run} {s : Step}
    (hr : runIsHonest r = true) (hmem : s ∈ r) (hauth : s.isScaffolding = false) :
    isGreen s.outcome = true := by
  rcases honest_run_step_is_green_or_scaffolding_skip hr hmem with hg | ⟨_, hs⟩
  · exact hg
  · rw [hauth] at hs; exact absurd hs (by simp)

/-- **The law is not vacuous** — a run that satisfies it exists, and it is the
one every CI run must now be. Without this, everything above could be true of
nothing. -/
theorem honest_runs_exist : runIsHonest [⟨"tty guard", .success⟩] = true := by
  simp [runIsHonest, stepIsAcceptable]

/-! ### The measured run — executed evidence, never a hypothesis

Run `31035932155` on `main`, the commit that added the Easter Egg section. The
eight skips are transcribed with the kind each step actually has. This block is
`#guard`, so it is re-executed on every build rather than asserted in prose. -/

def run31035932155 : Run :=
  [ ⟨"install comma-decimal locales (ubuntu only)", .skipped⟩
  , ⟨"install comma-decimal locales (ubuntu only)", .skipped⟩
  , ⟨"install comma-decimal locales (ubuntu only)", .success⟩
  , ⟨"provide zip on the Windows runner", .skipped⟩
  , ⟨"provide zip on the Windows runner", .skipped⟩
  , ⟨"provide zip on the Windows runner", .success⟩
  , ⟨"provide gtimeout on the macOS runner", .skipped⟩
  , ⟨"provide gtimeout on the macOS runner", .skipped⟩
  , ⟨"provide gtimeout on the macOS runner", .success⟩
  , ⟨"tty guard -- the router must not block on a terminal", .skipped⟩
  , ⟨"tty guard -- the router must not block on a terminal", .skipped⟩
  , ⟨"tty guard -- the router must not block on a terminal", .success⟩ ]

-- **That run is NOT honest, and GitHub called it `success`.** This is the whole
-- point of the section: the platform badge and the law disagree, and the law is
-- the one that is right. Eight steps asserted nothing while the run reported
-- green.
#guard !runIsHonest run31035932155

-- The same run after the repair: all four steps lost their `if: runner.os`
-- guard and now execute on every leg, branching inside. Twelve executions,
-- twelve successes, zero skips.
def run31035932155_repaired : Run :=
  [ ⟨"install comma-decimal locales", .success⟩
  , ⟨"install comma-decimal locales", .success⟩
  , ⟨"install comma-decimal locales", .success⟩
  , ⟨"provide zip (Git Bash on Windows ships unzip only)", .success⟩
  , ⟨"provide zip (Git Bash on Windows ships unzip only)", .success⟩
  , ⟨"provide zip (Git Bash on Windows ships unzip only)", .success⟩
  , ⟨"provide a bound (gtimeout/timeout must exist on every runner)", .success⟩
  , ⟨"provide a bound (gtimeout/timeout must exist on every runner)", .success⟩
  , ⟨"provide a bound (gtimeout/timeout must exist on every runner)", .success⟩
  , ⟨"tty guard -- the router must not block on a terminal", .success⟩
  , ⟨"tty guard -- the router must not block on a terminal", .success⟩
  , ⟨"tty guard -- the router must not block on a terminal", .success⟩ ]

#guard runIsHonest run31035932155_repaired
#guard noSkipAuthored run31035932155_repaired

-- One skip is enough. Not a majority, not a threshold -- one.
#guard !runIsHonest (⟨"anything", .skipped⟩ :: run31035932155_repaired)

/-! ### A `paths:` filter does not restrain a TAG push — and the run it wastes
    can conclude `cancelled`

MEASURED 2026-08-06, while publishing `v0.8.0 / v0.8.1 / v0.8.2`.

`.github/workflows/tag-manager.yml` declared

    push:
      paths: [".github/tags.txt"]

with no `branches:`. Pushing three tags in one command fired **three** runs of
that workflow, on commit `4a783a9`, which does not touch `.github/tags.txt` at
all (`git show --stat --name-only 4a783a9 | grep -c tags.txt` → **0**). A path
filter cannot be evaluated for a tag ref, so it restrains nothing; only
`branches:` excludes tags.

The wasted runs were not the damage. The workflow holds a **single** concurrency
group with `cancel-in-progress: false`, and GitHub keeps at most ONE pending run
per group: the first ran, the second pended, and the third's arrival
**cancelled the second**. Tag `v0.8.1` therefore carried a run concluding
`cancelled` with **zero jobs dispatched** — and `cancelled` is exactly what
`runConcludedHonestly` refuses. `v0.7.0` had the same scar, which is how a
structural defect passed for bad luck twice. -/

/-- A git ref, to the only depth that matters here. -/
inductive Ref where
  | branch (name : String)
  | tag (name : String)
  deriving DecidableEq, Repr

/-- A `push:` trigger as the workflow file declares it. `branches = []` means the
key is **absent**, which is the defect: absent is not "match nothing", it is
"match everything, including tags". -/
structure PushTrigger where
  branches : List String
  paths : List String
  deriving DecidableEq, Repr

/-- **Does this push trigger fire on this ref?**

The asymmetry is the whole point and it is not intuitive: `paths` is consulted
only for a branch. For a tag there is no base to diff against, so the filter is
skipped and the trigger fires -- unless `branches` is present, which excludes
tag refs outright. -/
def triggerFires (t : PushTrigger) (r : Ref) : Bool :=
  match r with
  | Ref.branch n => t.branches.isEmpty || t.branches.contains n
  | Ref.tag _    => t.branches.isEmpty

/-- **THE DEFECT, stated generally.** A trigger with no `branches:` fires on
EVERY tag, whatever its `paths:` list says — so no path filter can save it. -/
theorem paths_do_not_restrain_a_tag (paths : List String) (tagName : String) :
    triggerFires ⟨[], paths⟩ (Ref.tag tagName) = true := by
  simp [triggerFires]

/-- **THE FIX, stated generally.** Any non-empty `branches:` excludes every tag,
for every path list and every tag name. -/
theorem branches_exclude_every_tag
    (b : String) (bs paths : List String) (tagName : String) :
    triggerFires ⟨b :: bs, paths⟩ (Ref.tag tagName) = false := by
  simp [triggerFires]

/-- **The fix does not break the intended trigger.** `main` still fires. A repair
that silenced the tag runs by also silencing the branch runs would be a
regression dressed as a fix. -/
theorem the_fix_keeps_main (paths : List String) :
    triggerFires ⟨["main"], paths⟩ (Ref.branch "main") = true := by
  simp [triggerFires]

/-- The run-level rule, mirroring `checker/ci-honesty.sh:186-190` exactly: only
the literal string `success` is green. `cancelled`, `neutral`, `skipped` and
`timed_out` are all refused, and so is anything new GitHub invents — the
definition is a whitelist of one, not a blacklist that a future conclusion could
slip past. -/
def runConcludedHonestly (conclusion : String) : Bool := conclusion == "success"

/-- **A cancelled run is not a pass**, and it must be said separately because a
`cancelled` conclusion has ZERO failing steps — every step-level rule is
vacuously satisfied by a run that never dispatched a job. -/
theorem cancelled_is_not_honest : runConcludedHonestly "cancelled" = false := by
  decide

/-- The whitelist is genuinely a whitelist: **no** conclusion other than
`success` passes, including ones that do not exist yet. Quantified over the
string rather than enumerated, so a new GitHub conclusion cannot slip through a
gap in a list of cases. -/
theorem only_success_is_honest (c : String) :
    runConcludedHonestly c = true → c = "success" := by
  intro h
  simpa [runConcludedHonestly] using h

/-- **Zero steps is not evidence.** The measured run had `total_count: 0`, so
`r.all stepIsAcceptable` is `true` on the empty list. This is exactly why
`ci-honesty.sh` checks the run conclusion SEPARATELY from the steps, and the
theorem records that an all-green step list proves nothing on its own. -/
theorem empty_run_is_vacuously_step_clean :
    runIsHonest ([] : List Step) = true := by
  decide

-- The three tag pushes of 2026-08-06, as the file was and as it now is.
#guard  triggerFires ⟨[], [".github/tags.txt"]⟩ (Ref.tag "v0.8.1")      -- fired
#guard !triggerFires ⟨["main"], [".github/tags.txt"]⟩ (Ref.tag "v0.8.1") -- cannot
#guard  triggerFires ⟨["main"], [".github/tags.txt"]⟩ (Ref.branch "main")

/-! ### A dispatch that selects NO branch is a skip wearing a different hat

MEASURED 2026-08-06, on the very step written to abolish skips.

The `tty guard` runs on all three platforms and branches inside, choosing a pty
allocator: GNU `script` on Linux, BSD `script` on macOS, and a narrower
non-blocking probe where no pty is possible. An edit removed the `else` keyword
from that `if / elif / else` chain. The result is still **valid shell**, so the
144-check workflow linter passed it — and:

* on Windows **neither branch ran**. `rc` took the exit status of the failed
  `elif` *test* (0), `tty.out` was never created, and the step fell through to
  assertions about a pty it had never allocated.
* on macOS the fallback body had been absorbed into the BSD branch, so it ran
  **after** the real pty probe and **overwrote its result** — that leg reported
  `PASS` while asserting nothing whatever about a terminal.

The second is the dangerous one: a green leg that tested nothing. It is the same
defect as a skipped step — *concluded success, asserted nothing* — and the law
should treat it the same way rather than needing a new category. -/

/-- Which allocator a platform dispatch chose. -/
inductive Allocator where
  | gnuScript | bsdScript | noPty
  deriving DecidableEq, Repr

/-- A dispatch, as observed: which branch it selected (`none` = **no branch
ran**) and whether that branch actually produced its artifact. -/
structure Dispatch where
  selected : Option Allocator
  producedArtifact : Bool
  deriving DecidableEq, Repr

/-- **A dispatch is evidence only if some branch ran AND it produced its
artifact.** Both conjuncts were violated in the measured defect, on different
platforms, so dropping either would let one of the two legs back through. -/
def dispatchAsserted (d : Dispatch) : Bool :=
  match d.selected with
  | Option.none   => false
  | Option.some _ => d.producedArtifact

/-- **No branch ran ⇒ nothing was asserted**, for every artifact flag — so a
leftover `tty.out` from an earlier step could not rescue it either. -/
theorem unselected_asserts_nothing (d : Dispatch) (h : d.selected = Option.none) :
    dispatchAsserted d = false := by
  simp [dispatchAsserted, h]

/-- **A named branch that produced nothing asserts nothing.** This is the
Windows leg: the chain fell through, no `tty.out` existed, and the step still
reached its assertions. -/
theorem selected_without_artifact_asserts_nothing
    (a : Allocator) (d : Dispatch)
    (hs : d.selected = Option.some a) (hp : d.producedArtifact = false) :
    dispatchAsserted d = false := by
  simp [dispatchAsserted, hs, hp]

/-- **Asserting nothing is exactly as green as being skipped.** The binding that
makes this section part of the CI law rather than a separate idea: a leg that
selected no branch has the same evidential value as a step GitHub never ran, and
`isGreen` already says what that is worth. -/
theorem unselected_dispatch_is_as_green_as_a_skip (d : Dispatch)
    (h : d.selected = Option.none) :
    dispatchAsserted d = isGreen Outcome.skipped := by
  simp [dispatchAsserted, isGreen, h]

/-- **The exhaustiveness guard is exactly right — neither too strict nor too
lax.** `ci.yml` refuses when no branch named itself *or* when the artifact is
missing; this proves that pair of refusals is equivalent to "this dispatch is
evidence". A guard that checked only one would pass one of the two measured
legs. -/
theorem guard_is_exactly_assertion (d : Dispatch) :
    (d.selected.isSome && d.producedArtifact) = dispatchAsserted d := by
  cases h : d.selected <;> simp [dispatchAsserted, h]

/-- **Not vacuous:** a dispatch that really asserts something exists. -/
theorem honest_dispatch_exists :
    dispatchAsserted ⟨Option.some Allocator.gnuScript, true⟩ = true := by decide

-- The three legs of run 31052104913 as the broken chain actually behaved.
#guard !dispatchAsserted ⟨Option.none, false⟩                          -- windows
#guard  dispatchAsserted ⟨Option.some Allocator.gnuScript, true⟩       -- ubuntu
-- macOS: a branch WAS selected and an artifact DID exist -- but it was the
-- fallback's, written over the pty probe's. The model cannot see that, and
-- saying so is the point: this theorem catches "no branch ran", not "the wrong
-- branch ran last". The workflow guard catches the second by naming ALLOC once
-- per branch; only R22 in checker/workflow-lint.sh binds that.
#guard  dispatchAsserted ⟨Option.some Allocator.bsdScript, true⟩

/-! ### Run `31045719329` — the repair worked, and one assertion was wrong

The commit that removed every `if: runner.os` produced this run. **Rule 1 was
satisfied outright: 0 skipped steps.** The no-skip repair is measured, not
hoped for.

Rule 2 was not satisfied. `checkers (windows-latest)` went red because the
Windows leg of `tty guard` asserted `rc != 0` after feeding the router
`/dev/null`. Empty stdin is not a terminal, and the router correctly exits 0 on
it (measured: exit 0, zero bytes) — so the assertion was simply **false**. A
wrong check failed loudly instead of passing quietly, which is the system
working as designed.

**A correction belongs here, because this file is evidence.** An earlier draft
of this section stated that two `Post Run actions/checkout@v7` steps also
concluded `failure`, and built a `#guard` on it. That was a misreading: the job
list was parsed with `paste - -`, which pairs lines *offset by one* and
attributed a job-level conclusion to a step name. Re-measured against the API:
**zero** Post steps failed in this run. The claim is withdrawn rather than
quietly deleted.

The checker hole it pointed at was nonetheless real — `is_scaffolding` was
consulted by both rules, so a failing scaffolding step *would* have passed
unseen. It was found by reading the code, not by observing it happen. The law
below still forbids it; what changed is that it is presented as a hazard closed
by inspection, not as a defect caught in the wild. -/

def run31045719329 : Run :=
  [ ⟨"tty guard -- the router must not block on a terminal", .success⟩   -- ubuntu
  , ⟨"tty guard -- the router must not block on a terminal", .success⟩   -- macos
  , ⟨"tty guard -- the router must not block on a terminal", .failure⟩   -- windows
  , ⟨"Post Run actions/checkout@v7", .success⟩
  , ⟨"Post Run actions/checkout@v7", .success⟩
  , ⟨"Post Run actions/checkout@v7", .success⟩ ]

-- Not honest: one authored step failed. Nothing else in the run was wrong.
#guard !runIsHonest run31045719329

-- **Rule 1 was genuinely satisfied** -- this is the no-skip repair, measured.
#guard noSkipAuthored run31045719329

-- CONSTRUCTED, not measured: the run that the pre-repair checker would have
-- called honest. Labelled as hypothetical precisely because the real run was
-- not this. It is what `stepIsAcceptable`'s failure arm exists to reject.
def scaffoldingFailureRun : Run :=
  [ ⟨"Post Run actions/checkout@v7", .failure⟩
  , ⟨"Complete job", .failure⟩ ]

#guard !runIsHonest scaffoldingFailureRun
-- ...and rule 1 alone would NOT have caught it, which is why rule 2 may not
-- share rule 1's exemption.
#guard noSkipAuthored scaffoldingFailureRun

-- Deleting a check is the other half of the rule, and it needs no new theorem
-- here: a deleted step is simply absent, so this law holds vacuously on the
-- empty run. What catches a deletion is the gate count in `shipped` above plus
-- repo-complete's re-measurement. The boundary is stated so nobody reads this
-- law as covering more than it does.
#guard runIsHonest []

end RotMoE.Gates
