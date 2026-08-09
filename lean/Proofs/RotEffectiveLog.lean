/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# Zero records where you looked is not zero records written

Measured 2026-08-09 in the CTT instance, immediately after the 0.9.1-lean
artifact was installed:

    checker/ctt-session.sh  ->  exit 2
      "ran 2 turn(s), 0 failed; route records written this run: 0 (corpus: 20)"
      "REFUSE: 2 turn(s) ran and NOT ONE route record was written."
      "Most likely: the CTT credential expired."

Every part of that is honest except the last line, and the last line is wrong.
Measured against the running instance:

    claude auth status            -> loggedIn: true, firstParty
    a raw turn                    -> replied "OK", exit 0
    CTT log rot-route-debug.jsonl -> 20 NEW records, session 3111c07c-...,
                                     which is the harness's own turn cwd,
                                     every one carrying "src":"hook"

The turns ran, the hooks fired, and the router wrote 20 records. The harness
counted zero because it was reading a different file.

## The precedence, measured rather than assumed

`ctt-session.sh:250` does `export ROTMOE_DEBUG_LOG="$LOG"`. The CTT
`settings.json` carries an `env` block naming its own path. **The settings block
wins over the inherited environment** -- that is the measurement above, not a
belief about the CLI: the harness corpus stayed at 20 route records across the
run while the settings-named log gained exactly the 20 the turns produced.

## What this module settles

`effective` makes the precedence explicit, and the rest is about a checker that
draws a conclusion its evidence does not support. `zero_at_watched_says_nothing`
is the load-bearing one: from "the file I watched did not grow" nothing follows
about whether anything was written, and the naive diagnosis reads a dead
credential out of exactly that non-evidence.

The three causes are genuinely different states of the world and a checker must
separate them, because the repair for each is different -- refresh the token,
follow the override, or go look at the hook wiring. `diagnose` does; the naive
form collapses all three onto one message and sends the next reader to the
wrong place. It already has: the same message was recorded at CP29, when it may
well have been true, and it would now hide a healthy install behind a credential
hunt.
-/

namespace RotMoE.EffectiveLog

/-- A log path. Only equality matters here, so a `String` is the whole model. -/
abbrev Path := String

/-- Where the router actually writes. The `settings.json` `env` block wins over
whatever the calling harness exported -- MEASURED, see the header. -/
def effective (inherited : Path) (settings : Option Path) : Path :=
  match settings with
  | some s => s
  | none   => inherited

theorem settings_wins (inherited s : Path) :
    effective inherited (some s) = s := rfl

theorem inherited_used_when_settings_silent (inherited : Path) :
    effective inherited none = inherited := rfl

/-- If the settings block names a DIFFERENT path, the harness is not watching
the file the router writes. Stated as the contrapositive a checker can act on. -/
theorem harness_watches_the_wrong_file
    (inherited s : Path) (h : s ≠ inherited) :
    effective inherited (some s) ≠ inherited := by
  simpa [effective] using h

/-- What a run can observe. `atWatched` is the file the harness exported;
`atEffective` is the file the router actually wrote to. Keeping them as two
fields is the entire point -- the old harness had only one. -/
structure Observation where
  turnsRan : Nat
  turnsFailed : Nat
  atWatched : Nat
  atEffective : Nat
deriving DecidableEq, Repr

inductive Cause where
  /-- Turns failed. The credential, the network, the CLI. -/
  | turnsFailed
  /-- Turns succeeded and records exist -- at the other path. -/
  | logOverridden
  /-- Turns succeeded, nothing was written anywhere: the hooks did not fire. -/
  | genuinelySilent
  /-- Records arrived where expected. Nothing to diagnose. -/
  | collected
deriving DecidableEq, Repr

/-- The honest diagnosis. Order matters: a failed turn explains everything
after it, so it is tested first. -/
def diagnose (o : Observation) : Cause :=
  if o.turnsFailed > 0 then .turnsFailed
  else if o.atWatched > 0 then .collected
  else if o.atEffective > 0 then .logOverridden
  else .genuinelySilent

/-- The shipped behaviour: an empty watched file was reported as a probable dead
credential, with no other state consulted. -/
def diagnoseNaive (o : Observation) : Cause :=
  if o.atWatched > 0 then .collected else .turnsFailed

section TheDefect

/-- THE LOAD-BEARING ONE. An empty watched file is compatible with any number of
records having been written, so nothing about writing follows from it. Exhibited
rather than asserted: two observations agree on everything the naive checker
looks at and disagree on what actually happened. -/
theorem zero_at_watched_says_nothing :
    ∃ a b : Observation,
      a.atWatched = b.atWatched ∧
      a.turnsRan = b.turnsRan ∧
      a.turnsFailed = b.turnsFailed ∧
      a.atEffective ≠ b.atEffective := by
  refine ⟨⟨2, 0, 0, 20⟩, ⟨2, 0, 0, 0⟩, rfl, rfl, rfl, by decide⟩

/-- And the naive diagnosis cannot tell those two apart, while the honest one
can. This is the defect, stated over every run of that shape rather than over
the one that was measured. -/
theorem naive_conflates_override_with_dead_credential
    (r w : Nat) (hw : w > 0) :
    diagnoseNaive ⟨r, 0, 0, w⟩ = diagnoseNaive ⟨r, 0, 0, 0⟩ ∧
    diagnose ⟨r, 0, 0, w⟩ ≠ diagnose ⟨r, 0, 0, 0⟩ := by
  constructor
  · simp [diagnoseNaive]
  · simp [diagnose, Nat.not_lt.mpr, hw]

/-- On the measured shape -- turns ran, none failed, watched file empty, records
present elsewhere -- the naive answer is `turnsFailed` and the truth is
`logOverridden`. Quantified over the counts so it does not expire. -/
theorem the_measured_shape_is_misdiagnosed (r w : Nat) (hw : w > 0) :
    diagnoseNaive ⟨r, 0, 0, w⟩ = .turnsFailed ∧
    diagnose ⟨r, 0, 0, w⟩ = .logOverridden := by
  constructor
  · simp [diagnoseNaive]
  · simp [diagnose, hw]

end TheDefect

section Soundness

/-- A failed turn is always reported as such, whatever the counts say. -/
theorem failure_dominates (o : Observation) (h : o.turnsFailed > 0) :
    diagnose o = .turnsFailed := by
  simp [diagnose, h]

/-- Records at the watched path with no failures is the pass, and it is
reachable -- the diagnosis is not a gate that can never be satisfied. -/
theorem collection_is_reachable (r n : Nat) (hn : n > 0) :
    diagnose ⟨r, 0, n, 0⟩ = .collected := by
  simp [diagnose, hn]

/-- Silence really is distinguished from an override, which is the whole reason
for keeping two counters. -/
theorem silence_is_not_override (r : Nat) :
    diagnose ⟨r, 0, 0, 0⟩ = .genuinelySilent := by
  simp [diagnose]

/-- `collected` is never announced without evidence: it requires a record at the
path that was actually read. -/
theorem collected_requires_a_record (o : Observation)
    (h : diagnose o = .collected) : o.atWatched > 0 := by
  by_cases h2 : o.atWatched > 0
  · exact h2
  · exfalso
    by_cases h1 : o.turnsFailed > 0
    · simp [diagnose, h1] at h
    · by_cases h3 : o.atEffective > 0
      · simp [diagnose, h1, h2, h3] at h
      · simp [diagnose, h1, h2, h3] at h

/-- Following the override is not a licence to pass: an overridden run has
STILL collected nothing at the watched path, and the two verdicts stay distinct. -/
theorem override_is_not_a_pass (r w : Nat) (hw : w > 0) :
    diagnose ⟨r, 0, 0, w⟩ ≠ .collected := by
  simp [diagnose, hw]

end Soundness

section Measured

/-! The CTT run of 2026-08-09, as `#guard`s. Contingent by construction: a
repaired harness reads the effective path and these numbers change. -/

/-- 2 turns, none failed, nothing at the harness corpus, 20 at the CTT log. -/
def cttRun : Observation := ⟨2, 0, 0, 20⟩

#guard diagnose cttRun = Cause.logOverridden
#guard diagnoseNaive cttRun = Cause.turnsFailed
#guard diagnose cttRun ≠ diagnoseNaive cttRun
-- Had the credential really been dead, the honest diagnosis would say so.
#guard diagnose ⟨2, 2, 0, 0⟩ = Cause.turnsFailed
-- Hooks wired but silent is its own state, not a credential problem.
#guard diagnose ⟨2, 0, 0, 0⟩ = Cause.genuinelySilent
-- And a healthy run passes.
#guard diagnose ⟨2, 0, 20, 0⟩ = Cause.collected
-- The precedence itself, on the two real paths.
#guard effective "D:/tmp/ctt-session.jsonl"
  (some "C:/Users/Saimono/Claude_Test/.claude/rot-route-debug.jsonl")
  = "C:/Users/Saimono/Claude_Test/.claude/rot-route-debug.jsonl"
#guard effective "D:/tmp/ctt-session.jsonl" none = "D:/tmp/ctt-session.jsonl"

end Measured

end RotMoE.EffectiveLog
