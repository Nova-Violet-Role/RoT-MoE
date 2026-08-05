/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Mathlib

/-! # The double-fire, formalized — two install paths that ADD instead of choosing

**The defect this module exists for was measured, not imagined.** On 2026-08-04,
on the author's own machine, the router fired **twice on every prompt**. Two
identical marker lines, two gauge computations, twice the tokens, and nothing
about the state looked wrong from inside: the lane was right, the reading was
right — it was right twice.

The cause is that the packet reaches a session by two routes and they are
**additive**:

* the marketplace/plugin path registers `hooks/hooks.json`, which binds the
  router on `UserPromptSubmit` and `PreToolUse` through `${CLAUDE_PLUGIN_ROOT}`;
* `ARM_ROUTER` writes an absolute-path entry for **the same script** on **the
  same two events** into `settings.json`.

`CLAUDE.md` told the installing agent to do both. Every user who followed the
documented procedure got the duplicate.

**Why Lean and not just a checker.** A checker can assert "after arming with a
plugin present, the count is 1". This module states the thing that makes the
checker's assertion the right one: what fires is the **concatenation of two
sources**, so a claim about only one of them cannot see the duplication at all.
`RotInstall` proves `arm` is idempotent — and it is, *within `settings.json`*.
Idempotence in one registry says nothing about a second registry holding the same
command, which is exactly how a proved-idempotent installer produced a duplicate.
That gap is the finding, and `unguarded_duplicates` is it written down.

**What is NOT modelled.** Whether Claude Code actually concatenates the two
sources at run time is an empirical fact about the harness, measured from a live
transcript (the marker appears twice) and from the two files that each account
for one occurrence. Lean cannot read a transcript. `fires` encodes that measured
behaviour as a definition, and `checker/router-duplication.sh` is what keeps the
shipped installer honest about it.
-/

namespace RotMoE.Duplicate

/-- Where a hook command can come from. Both are real registries on disk:
`plugin` is the plugin's own `hooks/hooks.json`, `settings` is the user's
`settings.json`. The installer can only write the second one. -/
structure Registry where
  plugin : String → List String
  settings : String → List String

/-- **What actually fires for an event.** Not one registry or the other — the
concatenation. This single definition is the whole finding: every theorem in
`RotInstall` is about `settings` alone, and no amount of reasoning about one list
can detect a duplicate that lives across two. -/
def fires (r : Registry) (e : String) : List String :=
  r.plugin e ++ r.settings e

/-- The events the router owns, quoted from `hooks/hooks.json` and from
`ARM_ROUTER`'s own `EVENTS`. Both register on exactly these. -/
def armEvents : List String := ["UserPromptSubmit", "PreToolUse"]

/-- Arming with no guard: append to `settings`, whatever the plugin already
does. This is the shipped behaviour of every version up to 0.6.2. -/
def armUnguarded (cmd : String) (r : Registry) : Registry where
  plugin := r.plugin
  settings := fun e => if e ∈ armEvents then r.settings e ++ [cmd] else r.settings e

/-- Is a plugin registration live for this command? Decidable, because the guard
in the shipped installer is a program (`hooks/plugin-detect.js`) and a spec whose
predicate cannot be evaluated cannot be `decide`d against a fixture. -/
def pluginRegisters (cmd : String) (r : Registry) : Bool :=
  armEvents.all (fun e => (r.plugin e).contains cmd)

/-- Arming **with** the guard: if the plugin already registers the router, change
nothing at all. Refusing is a success — the user asked for the router to be armed
and it already is. -/
def arm (cmd : String) (r : Registry) : Registry :=
  if pluginRegisters cmd r then r else armUnguarded cmd r

/-! ## The defect, stated as a theorem -/

/-- **The unguarded installer really does produce two firings.**

Hypotheses are the measured situation, not a contrived one: the plugin registers
the command once on this event, the user's `settings.json` does not yet, and the
event is one the installer owns. The conclusion counts occurrences in `fires`,
i.e. in what the session actually runs.

This is the theorem that would have failed on 0.6.2 had it been asked for. -/
theorem unguarded_duplicates (cmd : String) (r : Registry) (e : String)
    (he : e ∈ armEvents)
    (hplug : (r.plugin e).count cmd = 1)
    (hset : (r.settings e).count cmd = 0) :
    (fires (armUnguarded cmd r) e).count cmd = 2 := by
  simp only [fires, armUnguarded, if_pos he, List.count_append, hplug, hset]
  simp

/-- **The guard reduces it to one.** Same hypotheses, guarded installer. -/
theorem guard_keeps_one (cmd : String) (r : Registry) (e : String)
    (hb : pluginRegisters cmd r = true)
    (hplug : (r.plugin e).count cmd = 1)
    (hset : (r.settings e).count cmd = 0) :
    (fires (arm cmd r) e).count cmd = 1 := by
  simp only [arm, if_pos hb, fires, List.count_append, hplug, hset]

/-- **The guard changes nothing else either.** Refusing must mean refusing
entirely: not a partial write, not a reordering, not a tidy-up of the user's
file. Equality of the whole registry is the strongest available statement. -/
theorem guard_is_a_no_op (cmd : String) (r : Registry)
    (hb : pluginRegisters cmd r = true) : arm cmd r = r := by
  simp [arm, hb]

/-! ## The theorems that stop the guard from being a way to do nothing

A guard that always refused would satisfy `guard_keeps_one` and
`guard_is_a_no_op` perfectly while disabling the installer for everyone who is
NOT using the plugin. These are the anchors against that. -/

/-- **Without a plugin registration, arming still arms.** -/
theorem guard_still_arms (cmd : String) (r : Registry)
    (hb : pluginRegisters cmd r = false) : arm cmd r = armUnguarded cmd r := by
  simp [arm, hb]

/-- **And the command is then genuinely present in what fires.** -/
theorem armed_fires (cmd : String) (r : Registry) (e : String)
    (he : e ∈ armEvents) (hb : pluginRegisters cmd r = false) :
    cmd ∈ fires (arm cmd r) e := by
  simp only [arm, if_neg (by simp [hb] : ¬ (pluginRegisters cmd r = true)),
    fires, armUnguarded, if_pos he]
  simp

/-- **The guard is FALSIFIABLE, and this is not decoration — it was found by
mutation.**

`guard_still_arms` and `armed_fires` above are both stated *under the hypothesis*
`pluginRegisters cmd r = false`. Mutant M03 of `mutate/mutate_rotduplicate.sh`
replaced `pluginRegisters` with the constant `true` — a guard that refuses to arm
for everyone, forever, which is precisely the over-cautious "fix" a nervous
change produces — and **both theorems survived**, because an unsatisfiable
hypothesis makes them vacuously true. Eight of ten mutants died; that one lived,
and it lived on a real gap.

So the existence of a registry where the guard does NOT fire is stated outright,
with the arming that follows from it. A constant-`true` guard now fails to
elaborate this, which is what makes the pair above load-bearing rather than
merely true. -/
theorem guard_can_decline :
    ∃ (cmd : String) (r : Registry) (e : String),
      pluginRegisters cmd r = false ∧ e ∈ armEvents ∧ cmd ∈ fires (arm cmd r) e := by
  refine ⟨"rot-router", ⟨fun _ => [], fun _ => []⟩, "UserPromptSubmit", ?_, ?_, ?_⟩
  · decide
  · decide
  · decide

/-- **A concrete witness of the whole story**, decidable end to end, so the model
can be executed rather than only believed. Left: what 0.6.2 did. Right: what the
guard does. -/
example :
    let r : Registry :=
      { plugin := fun e => if e ∈ armEvents then ["rot-router"] else []
      , settings := fun _ => [] }
    (fires (armUnguarded "rot-router" r) "UserPromptSubmit").count "rot-router" = 2 ∧
    (fires (arm "rot-router" r) "UserPromptSubmit").count "rot-router" = 1 := by
  refine ⟨?_, ?_⟩ <;> decide

/-! ## The uninstaller's blind spot, in the same model

The guard stops NEW duplicates. It does nothing for the machines that already
have one, and removing those is where the second measured defect lived: removal
matched the exact command string rebuilt from the directory the uninstaller ran
from, so an entry naming the plugin cache survived a full uninstall from a source
checkout — reporting `nothing to remove`, exit 0.

`disarmExact` is that behaviour. `disarmAny` is the `--all` mode added in 0.7.0:
it removes every entry a predicate recognises as ours, whatever path it names. -/

/-- Remove exactly one command string from `settings`. The plugin registry is
not ours to edit — uninstalling the plugin is the marketplace's job. -/
def disarmExact (cmd : String) (r : Registry) : Registry where
  plugin := r.plugin
  settings := fun e => (r.settings e).filter (fun c => c != cmd)

/-- Remove every command the predicate recognises. In the shipped engine the
predicate is "the command mentions a RoT MoE router script"; here it is abstract,
because the theorems must hold for whatever recogniser is used — pinning the
regex into the spec would make it a snapshot of today's file names. -/
def disarmAny (ours : String → Bool) (r : Registry) : Registry where
  plugin := r.plugin
  settings := fun e => (r.settings e).filter (fun c => ! ours c)

/-- **Exact removal cannot remove a differently-spelled entry.** The measured
defect, as a theorem: `d` is one of ours by the predicate, but is not the string
the uninstaller rebuilt, and it survives. -/
theorem exact_misses_foreign_spelling (cmd d : String) (r : Registry) (e : String)
    (hne : d ≠ cmd) (hmem : d ∈ r.settings e) :
    d ∈ (disarmExact cmd r).settings e := by
  simp only [disarmExact, List.mem_filter]
  exact ⟨hmem, by simpa using hne⟩

/-- **`--all` removes every entry the predicate claims.** -/
theorem any_removes_all (ours : String → Bool) (r : Registry) (e : String)
    (c : String) (hc : ours c = true) : c ∉ (disarmAny ours r).settings e := by
  simp [disarmAny, List.mem_filter, hc]

/-- **`--all` removes nothing else.** The broad mode is the dangerous one, so
this is the theorem that keeps it honest: a hook the predicate does not claim is
still there afterwards, wherever the user put it. -/
theorem any_preserves_foreign (ours : String → Bool) (r : Registry) (e : String)
    (d : String) (hd : ours d = false) (hmem : d ∈ r.settings e) :
    d ∈ (disarmAny ours r).settings e := by
  simp only [disarmAny, List.mem_filter]
  exact ⟨hmem, by simp [hd]⟩

/-- **`--all` never touches the plugin registry.** Uninstalling the plugin is the
marketplace's job; a script that reached into the plugin cache to delete a
registration would be editing a file it does not own. -/
theorem any_preserves_plugin (ours : String → Bool) (r : Registry) (e : String) :
    (disarmAny ours r).plugin e = r.plugin e := rfl

/-- **Today's event list, as an `example` and deliberately not a theorem.**

Every theorem above quantifies over `armEvents` rather than its contents, which
is right: binding the router to a third event is a change this project would make
on purpose, and a theorem forbidding it would be a spec defect rather than a
safeguard. This line pins the present without becoming a hypothesis. -/
example : armEvents = ["UserPromptSubmit", "PreToolUse"] := rfl

end RotMoE.Duplicate
