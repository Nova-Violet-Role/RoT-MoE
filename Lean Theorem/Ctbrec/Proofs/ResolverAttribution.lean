/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Authors: ctbrec-rework spec

# Resolver attribution: a name that will not resolve is not a broken adapter

Measured 2026-08-10. The app logged three site failures. Two of them were NOT app defects:

    host                  local resolver 127.7.7.10   public 8.8.8.8
    www.streamate.com     FAIL                        207.246.147.194
    stripchat.com         EMPTY                       104.17.117.12
    www.bongacams.com     EMPTY                       195.85.23.246

`java.net.UnknownHostException` was raised before a single HTTP request left the machine.
The adapters were never reached, so nothing about them was tested. Had this been attributed
to the adapter -- the obvious reading of "Streamate: Initial request failed" -- three healthy
site adapters would have been "repaired" for a fault that lives in a loopback DNS filter.

The rule this file settles: **one resolver cannot distinguish a blocked name from a dead one.**
Attribution to the adapter requires that the name resolved FIRST.
-/

namespace CtbrecSpec.ResolverAttribution

/-- A resolver either returns an address for a host, or does not. -/
structure Resolver where
  resolves : String → Bool

/-- An adapter is either healthy or genuinely faulty. This is the thing we want to learn,
and the thing a resolver failure tells us NOTHING about. -/
structure Adapter where
  host    : String
  healthy : Bool

/-- What the app observes: a request either succeeds or raises. -/
inductive Observation
  | ok
  | unknownHost
  | adapterError
  deriving DecidableEq, Repr

/-- The real request path: resolution happens FIRST. If the name does not resolve, the
adapter is never reached and its health cannot influence the observation. -/
def observe (r : Resolver) (a : Adapter) : Observation :=
  if r.resolves a.host then
    (if a.healthy then Observation.ok else Observation.adapterError)
  else
    Observation.unknownHost

/-- The naive attribution that this checkpoint nearly made: any non-ok observation is
blamed on the adapter. -/
def naiveBlamesAdapter (o : Observation) : Bool :=
  o != Observation.ok

/-- The sound attribution: only an actual adapter error implicates the adapter. -/
def soundBlamesAdapter (o : Observation) : Bool :=
  o == Observation.adapterError

/-! ## A resolver failure carries no information about the adapter -/

/-- If the name does not resolve, the observation is `unknownHost` REGARDLESS of health.
This is the core fact: the two worlds are observationally identical. -/
theorem unresolved_hides_health (r : Resolver) (a : Adapter) (h : r.resolves a.host = false) :
    observe r a = Observation.unknownHost := by
  simp [observe, h]

/-- Two adapters differing ONLY in health are indistinguishable under a blocking resolver.
So no experiment through that resolver can determine health. -/
theorem blocked_resolver_cannot_distinguish (r : Resolver) (host : String)
    (h : r.resolves host = false) :
    observe r ⟨host, true⟩ = observe r ⟨host, false⟩ := by
  simp [observe, h]

/-- The naive rule blames a HEALTHY adapter whenever the name is blocked. This is exactly
the false repair that was avoided. -/
theorem naive_blames_a_healthy_adapter (r : Resolver) (host : String)
    (h : r.resolves host = false) :
    naiveBlamesAdapter (observe r ⟨host, true⟩) = true := by
  simp [naiveBlamesAdapter, observe, h]

/-- The sound rule never blames an adapter that was never reached. -/
theorem sound_never_blames_the_unreached (r : Resolver) (a : Adapter)
    (h : r.resolves a.host = false) :
    soundBlamesAdapter (observe r a) = false := by
  simp [soundBlamesAdapter, observe, h]

/-- The sound rule is correct: it blames the adapter exactly when the adapter is at fault
AND was actually reached. -/
theorem sound_is_exact (r : Resolver) (a : Adapter) :
    soundBlamesAdapter (observe r a) = (r.resolves a.host && !a.healthy) := by
  unfold soundBlamesAdapter observe
  cases hr : r.resolves a.host <;> cases hh : a.healthy <;> simp [hr, hh]

/-! ## Why two resolvers were necessary -/

/-- A name is BLOCKED (not dead) when some other resolver returns it. -/
def blocked (local' public' : Resolver) (host : String) : Bool :=
  !local'.resolves host && public'.resolves host

/-- A blocked name proves the LOCAL resolver is at fault, not the network and not the app. -/
theorem blocked_implicates_the_local_resolver (l p : Resolver) (host : String)
    (h : blocked l p host = true) :
    l.resolves host = false ∧ p.resolves host = true := by
  unfold blocked at h
  simp [Bool.and_eq_true, Bool.not_eq_true'] at h
  exact ⟨h.1, h.2⟩

/-- A single resolver cannot establish `blocked`: with only the local answer, a blocked name
and a dead name are the same observation. This is why the second lookup was run. -/
theorem one_resolver_cannot_prove_blocked (l : Resolver) (host : String)
    (h : l.resolves host = false) :
    ∃ p q : Resolver, blocked l p host ≠ blocked l q host := by
  refine ⟨⟨fun _ => true⟩, ⟨fun _ => false⟩, ?_⟩
  simp [blocked, h]

/-- Repair direction: fixing the resolver can only turn `unknownHost` into a real verdict,
never make a healthy adapter look worse. -/
theorem unblocking_never_harms (a : Adapter) (l p : Resolver)
    (hl : l.resolves a.host = false) (hp : p.resolves a.host = true) (hh : a.healthy = true) :
    observe l a = Observation.unknownHost ∧ observe p a = Observation.ok := by
  unfold observe
  exact ⟨by simp [observe, hl], by simp [observe, hp, hh]⟩

/-! ## Concrete instances -- the measured 2026-08-10 data -/

/-- The measured local resolver: blocks the three, allows the three. -/
def measuredLocal : Resolver :=
  ⟨fun h => !(h == "www.streamate.com" || h == "stripchat.com" || h == "www.bongacams.com")⟩

/-- The measured public resolver 8.8.8.8: answered for every host tried. -/
def measuredPublic : Resolver := ⟨fun _ => true⟩

#guard blocked measuredLocal measuredPublic "www.streamate.com" = true
#guard blocked measuredLocal measuredPublic "stripchat.com" = true
#guard blocked measuredLocal measuredPublic "www.bongacams.com" = true
#guard blocked measuredLocal measuredPublic "chaturbate.com" = false
#guard blocked measuredLocal measuredPublic "www.myfreecams.com" = false
#guard blocked measuredLocal measuredPublic "cam4.com" = false

-- Streamate adapter healthy, yet observed as unknownHost
#guard observe measuredLocal ⟨"www.streamate.com", true⟩ = Observation.unknownHost
-- the naive rule would have condemned it
#guard naiveBlamesAdapter (observe measuredLocal ⟨"www.streamate.com", true⟩) = true
-- the sound rule does not
#guard soundBlamesAdapter (observe measuredLocal ⟨"www.streamate.com", true⟩) = false

-- MyFreeCams RESOLVES and still fails, so its fault IS attributable
-- (discrimination that matters operationally)
#guard observe measuredLocal ⟨"www.myfreecams.com", false⟩ = Observation.adapterError
#guard soundBlamesAdapter (observe measuredLocal ⟨"www.myfreecams.com", false⟩) = true

-- three of six hosts blocked: selective, which ruled out a general DNS outage
-- and pointed at a filtering resolver
#guard (["www.streamate.com", "stripchat.com", "www.bongacams.com",
         "chaturbate.com", "www.myfreecams.com", "cam4.com"].filter
          (blocked measuredLocal measuredPublic)).length = 3

end CtbrecSpec.ResolverAttribution
