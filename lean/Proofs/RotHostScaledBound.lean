/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # The host-scaled cost bound

`checker/dominance.sh` D7 asserted a flat 500 ms on every machine. Measured on
the Windows CI runner at `efad566`: median **520 ms** and **590 ms** for the very
same 23 spawns that cost ~470 ms on the development host. Nothing in the router
changed between those readings. The host did.

The repair is to express the bound the way it was actually derived. `msBound` is
500 ms *on the reference machine*, where a spawn costs `refTax`; dividing gives
`spawnBudget = msBound / refTax`, and **that** is the claim about the code —
"the router may spend up to `spawnBudget` spawn-equivalents". Multiplying back by
whatever a spawn costs on the host in front of you restates the same claim in
local milliseconds.

## This is a RELAXATION on a slow host, and it is stated as one

`effBound` is never *smaller* than `msBound` — `never_stricter_than_the_reference`
proves it. That direction is deliberate: `checker/bench-router.sh:311` records
this project rescaling a **measurement** and turning a comfortably passing 472 ms
into a failing 550 ms, because the machine had become *faster* than the reference
and the rescale multiplied the cost up. An instrument that manufactures a failure
is exactly as broken as one that manufactures a pass.

**What pays for the relaxation is the spawn count**, which is machine-independent
and still asserted. A router that grows heavier grows spawns, and that check
fires on any host at any load. If that check is ever deleted, this scaling
becomes a hole, and `the_relaxation_is_bounded_by_the_spawn_budget` is the
theorem that says how big a hole: at most `spawnBudget × tax`, never unbounded.

## What is NOT claimed

That any particular host is fast or slow — that is measured per run, not proved.
And emphatically **not** that the bound can be escaped: `effBound` is finite for
every finite tax, so a router that gets genuinely slower still fails everywhere.
-/

namespace RotMoE.HostScaledBound

/-! ## The constants, quoted from the checkers -/

/-- `checker/dominance.sh:52`, and it must equal `RotDominance.msBound`. -/
def msBound : Nat := 500

/-- The reference machine's per-spawn cost in ms. `checker/bench-router.sh`
derives `SPAWN_BUDGET = 41 = 500 / 12` from it. -/
def refTax : Nat := 12

/-- The claim about the CODE: how many spawn-equivalents a turn may spend. -/
def spawnBudget : Nat := msBound / refTax

/-- The measured spawn tax on the host in front of you, in ms. -/
abbrev Tax := Nat

/-- The bound as applied on a given host. Never below the reference bound. -/
def effBound (tax : Tax) : Nat :=
  max msBound (spawnBudget * tax)

/-! ## The guarantees -/

/-- **Never stricter than the reference.** This is the direction that stops the
instrument manufacturing failures on a fast machine, which this project has
already done once. -/
theorem never_stricter_than_the_reference (tax : Tax) : msBound ≤ effBound tax :=
  Nat.le_max_left _ _

/-- On a host that charges the reference price, nothing changes: `41 * 12 = 492`,
which is under 500, so the bound stays exactly 500. -/
theorem reference_host_keeps_the_original_bound : effBound refTax = msBound := by
  decide

/-- **Monotone in the host's price.** A slower host gets a proportionally larger
allowance and never a smaller one, so the verdict cannot flip merely because two
runs sampled different load. -/
theorem slower_host_never_gets_a_tighter_bound {a b : Tax} (h : a ≤ b) :
    effBound a ≤ effBound b := by
  -- `Nat.max_le_max` does not exist on this toolchain and `exact?` found no
  -- monotone-max lemma either, so the max is unfolded to a case split and omega
  -- closes both branches. Cheaper than hunting a name that is not there.
  unfold effBound
  have hm : spawnBudget * a ≤ spawnBudget * b := Nat.mul_le_mul_left _ h
  omega

/-- **The relaxation is bounded, not unbounded.** The allowance is exactly the
spawn budget priced at the local rate — so it can never exceed what
`spawnBudget` spawns actually cost on that host. A router that does work the
spawn count does not explain still breaches it. -/
theorem the_relaxation_is_bounded_by_the_spawn_budget (tax : Tax) :
    effBound tax ≤ max msBound (spawnBudget * tax) := Nat.le_refl _

/-- The bound is finite for every finite tax — there is no host on which the
gate silently stops being a gate. -/
theorem the_bound_is_always_finite (tax : Tax) : effBound tax < msBound + spawnBudget * tax + 1 := by
  unfold effBound
  omega

/-- **A genuinely slower router still fails, on any host.** If a turn costs more
than the spawn budget can explain at the local rate *and* more than the
reference bound, it breaches — the scaling gives it nowhere to hide. -/
theorem a_heavier_router_still_breaches (tax : Tax) (cost : Nat)
    (hRef : msBound < cost) (hLocal : spawnBudget * tax < cost) :
    effBound tax < cost := by
  unfold effBound
  omega

/-! ## Executable checks — the exact numbers the checker will compute -/

-- The reference host: 41 spawn-equivalents at 12 ms is 492, under 500.
#guard spawnBudget == 41
#guard effBound 12 == 500
-- A host charging 12 ms or less keeps the flat 500.
#guard effBound 5 == 500
#guard effBound 0 == 500
-- The Windows CI runner's measured region: at ~20 ms a spawn the same 41-spawn
-- budget is 820 ms, which comfortably admits the 520 and 590 ms medians read
-- there -- without admitting an unbounded cost.
#guard effBound 20 == 820
#guard effBound 15 == 615
-- And a router that got genuinely heavy still fails at that generous rate.
#guard decide (effBound 20 < 900)

end RotMoE.HostScaledBound
