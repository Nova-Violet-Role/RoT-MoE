/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Mathlib

/-! # ARM_ROUTER, formalized — arming the router never disarms the user

A model of `ARM_ROUTER.sh` / `ARM_ROUTER.ps1` and their uninstaller, operating on
the user's `~/.claude/settings.json`.

This is the module with the most at stake, because it is the only part of the
packet that **writes to a file the user already depends on**. A wrong proof here
costs someone their session, not a red build. The hazard is measured, not
hypothetical: on this machine a wiring script rewrote that file from 3 674 to
9 564 bytes and `effortLevel` silently changed value in the same window.

**What is modelled.** `settings.json` as two total maps — every scalar key to an
optional value, and every hook event to its list of command strings. `arm`
appends the router's command to the two events it owns; `disarm` removes it.

**What is NOT modelled, stated here rather than discovered later.** Lean sees a
map, not a file. It cannot see a UTF-8 BOM, `\r\n` line endings, key ordering,
`indent=2`, or the difference between `9 564` bytes and `3 674` bytes of the same
JSON. Those are byte-level properties of the writer and they belong to the
checker (R4/R5), which runs the real installer against a scratch `HOME` and
diffs. A green build here means the *merge is sound*, never that the *file was
written correctly*. Both are needed; only one is provable here.

Every preservation theorem below is quantified over **all keys**. Naming the four
critical ones (`permissions.defaultMode` nested, `permissions.allow`,
`skipDangerousModePermissionPrompt`, `effortLevel`) would produce a spec that
goes stale the day a fifth appears — and the day it appears is exactly the day
the theorem is needed.
-/

namespace RotMoE.Install

/-- A JSON scalar, to the depth the installer cares about. The installer never
inspects these; it must only leave them alone. -/
inductive Val where
  | str (s : String)
  | num (n : Int)
  | bool (b : Bool)
deriving DecidableEq, Repr

/-- `settings.json`, as two total maps.

`scalar` covers every ordinary key, **including nested ones** — `permissions.
defaultMode` is a key here like any other, which is what makes the preservation
theorems cover it without naming it. `hookEvents` maps an event name to the
ordered list of command strings registered for it. -/
structure Settings where
  scalar : String → Option Val
  hookEvents : String → List String

/-- The two events the router registers on, measured from `settings.json`: both
hooks are bound at `UserPromptSubmit` and `PreToolUse`, matcher `*`. -/
def armEvents : List String := ["UserPromptSubmit", "PreToolUse"]

/-- Append a command unless it is already present. This is rule 5 of the
installer contract — *idempotent, detected by command string, not by count*. -/
def addOnce (c : String) (l : List String) : List String :=
  if c ∈ l then l else l ++ [c]

theorem addOnce_mem (c : String) (l : List String) : c ∈ addOnce c l := by
  unfold addOnce
  split
  · assumption
  · simp

theorem addOnce_of_mem {c : String} {l : List String} (h : c ∈ l) : addOnce c l = l := by
  unfold addOnce
  exact if_pos h

theorem addOnce_of_not_mem {c : String} {l : List String} (h : c ∉ l) :
    addOnce c l = l ++ [c] := by
  unfold addOnce
  exact if_neg h

/-- **Nothing already present is ever dropped.** The installer only ever grows a
hook list. -/
theorem addOnce_superset (c d : String) (l : List String) (h : d ∈ l) :
    d ∈ addOnce c l := by
  unfold addOnce
  split
  · exact h
  · exact List.mem_append_left _ h

/-- The installer: append the router command to the events it owns, and touch
nothing else. -/
def arm (cmd : String) (s : Settings) : Settings where
  scalar := s.scalar
  hookEvents := fun k => if k ∈ armEvents then addOnce cmd (s.hookEvents k) else s.hookEvents k

/-- The uninstaller: remove exactly that command, wherever it appears. -/
def disarm (cmd : String) (s : Settings) : Settings where
  scalar := s.scalar
  hookEvents := fun k => (s.hookEvents k).filter (fun c => c != cmd)

/-! ## The preservation theorems — quantified over ALL keys -/

/-- **Every scalar key survives, byte for byte, whatever it is.**

Rule 3 of the installer contract. Quantified over all of `String`, so
`permissions.defaultMode`, `permissions.allow`,
`skipDangerousModePermissionPrompt`, `effortLevel`, `env`, `enabledPlugins` and
every key not yet invented are covered without being named.

It is `rfl` because `arm` was *built* not to touch them — which is the point.
A blind-rewrite installer, or one that round-trips through a template, breaks
this immediately. -/
theorem arm_preserves_all_scalars (cmd : String) (s : Settings) (k : String) :
    (arm cmd s).scalar k = s.scalar k := rfl

/-- **Every hook event the router does not own survives exactly.**

The other half of rule 3: `SessionStart`, `SessionEnd`, `PostToolUse`, `Stop`
and anything else the user has wired keep their command lists untouched, in
order. -/
theorem arm_preserves_unrelated_events (cmd : String) (s : Settings) (k : String)
    (h : k ∉ armEvents) : (arm cmd s).hookEvents k = s.hookEvents k := by
  simp [arm, h]

/-- **Even on the events it DOES own, nothing pre-existing is removed.**

The strongest preservation statement, and the one that matters most in practice:
a user with their own `UserPromptSubmit` hooks keeps every one of them. Stated
over an arbitrary command `d`, so it is not about any particular existing hook. -/
theorem arm_preserves_existing_hooks (cmd d : String) (s : Settings) (k : String)
    (h : d ∈ s.hookEvents k) : d ∈ (arm cmd s).hookEvents k := by
  simp only [arm]
  split
  · exact addOnce_superset cmd d _ h
  · exact h

/-! ## The theorems that stop the above from being satisfied by doing nothing -/

/-- **The router IS registered afterwards.**

Without this, an installer that returns its input unchanged satisfies every
preservation theorem above. This is the non-vacuity anchor. -/
theorem arm_adds_the_hooks (cmd : String) (s : Settings) (k : String)
    (h : k ∈ armEvents) : cmd ∈ (arm cmd s).hookEvents k := by
  simp only [arm, if_pos h]
  exact addOnce_mem cmd _

/-- **Running the installer twice registers the router once.**

Rule 5. Detection is by command string, which is what makes this hold for a list
that already contains the command from a previous install. -/
theorem arm_idempotent (cmd : String) (s : Settings) :
    arm cmd (arm cmd s) = arm cmd s := by
  unfold arm
  congr 1
  funext k
  by_cases h : k ∈ armEvents
  · simp only [if_pos h]
    exact addOnce_of_mem (addOnce_mem cmd (s.hookEvents k))
  · simp only [if_neg h]

/-! ## The uninstaller — and the honest limit on it -/

/-- **`disarm` really removes the command.** -/
theorem disarm_removes (cmd : String) (s : Settings) (k : String) :
    cmd ∉ (disarm cmd s).hookEvents k := by
  simp [disarm]

/-- **`disarm` removes nothing else.** An uninstaller that took a neighbouring
entry with it would satisfy `disarm_removes` perfectly. -/
theorem disarm_preserves_others (cmd d : String) (s : Settings) (k : String)
    (hne : d ≠ cmd) (h : d ∈ s.hookEvents k) : d ∈ (disarm cmd s).hookEvents k := by
  simp only [disarm]
  rw [List.mem_filter]
  exact ⟨h, by simpa using hne⟩

/-- Scalars are untouched by the uninstaller too. -/
theorem disarm_preserves_all_scalars (cmd : String) (s : Settings) (k : String) :
    (disarm cmd s).scalar k = s.scalar k := rfl

/-- **`disarm ∘ arm = id` — but ONLY on a settings file that did not already
contain the router command.**

The hypothesis is not a technicality and it is not decoration: it is the exact
condition under which the uninstaller is lossless, and `disarm_arm_not_id` below
proves it cannot be dropped.

Read practically: if the user had already wired this same command by hand, for
their own reasons, then installing and uninstalling **loses their entry**. That
is a real lossy case in a real installer, and per the goal document it has to be
said out loud in the README rather than left for a user to discover. The
mitigation is the backup file, which is a byte-level guarantee the checker
tests — not something this module can provide. -/
theorem disarm_arm_id (cmd : String) (s : Settings)
    (hfresh : ∀ k, cmd ∉ s.hookEvents k) : disarm cmd (arm cmd s) = s := by
  unfold disarm arm
  congr 1
  funext k
  have hk := hfresh k
  by_cases h : k ∈ armEvents
  · simp only [if_pos h, addOnce_of_not_mem hk]
    rw [List.filter_append]
    have hkeep : (s.hookEvents k).filter (fun c => c != cmd) = s.hookEvents k := by
      apply List.filter_eq_self.mpr
      intro a ha
      simp only [bne_iff_ne, ne_eq, decide_eq_true_eq]
      rintro rfl
      exact hk ha
    simp [hkeep]
  · simp only [if_neg h]
    apply List.filter_eq_self.mpr
    intro a ha
    simp only [bne_iff_ne, ne_eq, decide_eq_true_eq]
    rintro rfl
    exact hk ha

/-- **The hypothesis on `disarm_arm_id` cannot be dropped — here is the witness.**

A settings file in which the user has already registered this exact command.
`arm` correctly adds nothing (idempotence), then `disarm` removes it — and the
user's own entry is gone. Round-tripping is **not** the identity.

This theorem exists so that the limitation is a proved fact carried by the
build, rather than a caveat in a comment that a later refactor can delete
without anything going red. -/
theorem disarm_arm_not_id :
    ∃ (cmd : String) (s : Settings), disarm cmd (arm cmd s) ≠ s := by
  refine ⟨"rot-router", ⟨fun _ => none,
    fun k => if k = "UserPromptSubmit" then ["rot-router"] else []⟩, ?_⟩
  intro hcontra
  have h := congrArg (fun t => Settings.hookEvents t "UserPromptSubmit") hcontra
  simp [disarm, arm, armEvents, addOnce] at h

/-! ## Order

The installer appends. A user reading their `settings.json` after installing
should find their own hooks where they left them, with the router last. -/

/-- **The router is appended, never prepended.** On a fresh event list the
existing entries keep their positions and order; the router goes on the end.
An installer that prepended would satisfy every membership theorem above while
changing the order in which the user's hooks fire. -/
theorem arm_appends (cmd : String) (s : Settings) (k : String)
    (h : k ∈ armEvents) (hfresh : cmd ∉ s.hookEvents k) :
    (arm cmd s).hookEvents k = s.hookEvents k ++ [cmd] := by
  simp only [arm, if_pos h]
  exact addOnce_of_not_mem hfresh

/-- **Today's event list, as an `example` — deliberately not a theorem.**

Every theorem above quantifies over `armEvents` rather than over its contents,
which is correct: binding the router to a third event is a change this project
would make on purpose, and a theorem that forbade it would be a spec defect
rather than a safeguard.

But that generality leaves a real gap — the contents of this list are pinned by
nothing, so editing them breaks no theorem. This `example` closes it in the only
honest way: it documents the present without becoming a hypothesis anything
rests on. Editing `armEvents` breaks exactly this line, which is a prompt to
update the checker corpus, not a proof obligation.

The events are measured from `~/.claude/settings.json`: both hooks are registered
on `UserPromptSubmit` and `PreToolUse`, each with matcher `*`. Asserting that
the shipped `hooks/hooks.json` still says so is the checker's job, not Lean's —
Lean cannot read that file. -/
example : armEvents = ["UserPromptSubmit", "PreToolUse"] := rfl

end RotMoE.Install
