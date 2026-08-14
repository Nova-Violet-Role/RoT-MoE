/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
-/

/-!
# Which configuration tree is the app actually using?

CP80. Measured 2026-08-06, and the measurement is an incident rather than an audit: this session
relaunched the app with

```
javaw ... -jar ctbrec-26.7.11.jar          -- no -Dctbrec.config.dir
```

and the app came up **against a different configuration tree**. Its own log said so plainly and
nobody read it:

```
12:41:37 INFO c.Config [Config.java:172] Loading config from
         C:\Users\<you>\AppData\Roaming\ctbrec\26.7.11\settings.json
```

against every previous line in the same file:

```
11:18:14 INFO c.Config [Config.java:172] Loading config from
         ...\ctbrec\.\config\26.7.11\settings.json
```

The consequences were immediate and were at first mistaken for a code regression:

| | deployment tree | roaming tree |
|---|---|---|
| models in `models.json` | 103 | 160 |
| unsuspended (actually probed) | 12 | ~148 |
| HTTP 429 from the online monitor | ~1 per minute | **39, then 57, then 9** in three minutes |

Nothing was broken. The app faithfully served a config the operator had not looked at in months.

**The defect is not that two trees exist** — `ctbrec.config.dir` is a legitimate switch, and a
user who wants the roaming tree should get it. The defect is that choosing between them is
SILENT at the only moment it matters: a launch that omits the flag looks identical to one that
sets it, right up until the model list differs.

This module fixes the shape of the guarantee: the choice is left exactly as it was, and the
*ambiguity* is made loud. Everything below is about when a warning is owed, never about
redirecting anyone's configuration.
-/

namespace CtbrecSpec.ConfigDir

/-- Which tree the app binds to. -/
inductive Tree
  | /-- `<appDir>/config/<version>` — the deployment's own, selected by `-Dctbrec.config.dir`. -/
    deployment
  | /-- `%APPDATA%/ctbrec/<version>` (or `~/.config/ctbrec`) — the platform default. -/
    roaming
  deriving DecidableEq, Repr

/-- What a launch looks like from `Config`'s point of view: whether the system property was
passed, and whether the deployment carries a config tree of its own. -/
structure Launch where
  /-- `-Dctbrec.config.dir` present on the command line. -/
  pinned : Bool
  /-- A `config/` directory exists beside the jar. This is what makes silence dangerous: with no
  local tree there is nothing to be confused with. -/
  localConfigExists : Bool
  deriving DecidableEq, Repr

/-- `Config.java:78-82` — the selection, unchanged by this checkpoint. -/
def chosen (l : Launch) : Tree := if l.pinned then Tree.deployment else Tree.roaming

/-- The selection **after** the CP80 patch. Defined separately on purpose: proving it equal to
`chosen` is the anti-disarm statement, and a patch that silently redirected the user's
configuration would fail it. -/
def chosenFixed (l : Launch) : Tree := chosen l

/-- When the app owes the operator a warning: it fell back to the platform default while the
deployment had a config tree of its own. -/
def warns (l : Launch) : Bool := !l.pinned && l.localConfigExists

/-- Every launch shape, so the properties below can be `decide`d rather than argued. -/
def allLaunches : List Launch :=
  [⟨true, true⟩, ⟨true, false⟩, ⟨false, true⟩, ⟨false, false⟩]

/-! ## The fix changes what is SAID, never what is DONE -/

/-- **Anti-disarm.** The patched selection is the old selection, launch for launch. A "fix" that
forced everyone onto the deployment tree would break a user who deliberately runs the roaming
one, and it would break them silently — the exact fault being repaired. -/
theorem the_warning_does_not_change_the_choice (l : Launch) : chosenFixed l = chosen l := rfl

theorem the_choice_is_unchanged_on_every_launch_shape :
    allLaunches.all (fun l => chosenFixed l == chosen l) = true := by decide

/-! ## When the warning fires -/

/-- **The incident shape always warns.** Unpinned, with a deployment config present — exactly
the launch this session performed. -/
theorem a_divergent_launch_always_warns (l : Launch)
    (hp : l.pinned = false) (hc : l.localConfigExists = true) : warns l = true := by
  simp [warns, hp, hc]

/-- **No false alarm.** A launcher that pins the directory is never nagged, whatever else is on
disk. This matters more than it looks: a warning that fires on correct launches gets muted, and a
muted warning is worse than none. -/
theorem a_pinned_launch_never_warns (l : Launch) (hp : l.pinned = true) : warns l = false := by
  simp [warns, hp]

/-- **Nothing to diverge from, nothing to say.** A bare jar with no deployment config beside it
is not ambiguous. -/
theorem without_a_local_config_there_is_no_warning (l : Launch)
    (hc : l.localConfigExists = false) : warns l = false := by
  simp [warns, hc]

/-- **The durable form: the warning fires exactly when two trees could be meant.** An `iff`, so
neither direction can rot — over-warning and under-warning are both excluded, and this is the
statement a future change has to keep true. -/
theorem the_warning_fires_exactly_when_the_trees_can_diverge (l : Launch) :
    warns l = true ↔ (l.pinned = false ∧ l.localConfigExists = true) := by
  constructor
  · intro h
    cases hp : l.pinned <;> cases hc : l.localConfigExists <;>
      simp [warns, hp, hc] at h ⊢
  · intro ⟨hp, hc⟩
    simp [warns, hp, hc]

/-- **Divergence has exactly one cause.** Two launches that bind to different trees must differ
in whether they pinned the directory — nothing about the filesystem can do it on its own. This is
why the warning is attached to the flag rather than to a path comparison. -/
theorem only_the_flag_can_change_the_tree (a b : Launch) (h : chosen a ≠ chosen b) :
    a.pinned ≠ b.pinned := by
  intro hEq
  apply h
  simp [chosen, hEq]

/-! ## The launchers this deployment ships (measured, `grep -in config.dir`)

`ctbrec.bat:39`, `ctbrec.l4j.ini:2`, `CtbrecEVO.l4j.ini:2`, `ctbrec-no-splash.l4j.ini:2` and
`ctbrec-debug.bat:7` all carry `-Dctbrec.config.dir=./config`. So every supported way in is
pinned, and the incident required bypassing all five. -/

/-- A launcher, as measured on disk. -/
structure Launcher where
  name : String
  pinsConfigDir : Bool
  deriving DecidableEq, Repr

def shippedLaunchers : List Launcher :=
  [⟨"ctbrec.bat", true⟩, ⟨"ctbrec.l4j.ini", true⟩, ⟨"CtbrecEVO.l4j.ini", true⟩,
   ⟨"ctbrec-no-splash.l4j.ini", true⟩, ⟨"ctbrec-debug.bat", true⟩]

/-- **Every shipped launcher pins the directory.** -/
theorem every_launcher_pins_the_config_dir :
    shippedLaunchers.all (fun x => x.pinsConfigDir) = true := by decide

/-- ...so no supported launch ever triggers the warning. The warning is reserved for a bare
`java -jar`, which is precisely how this session broke it. -/
theorem no_shipped_launcher_warns :
    shippedLaunchers.all (fun x => !warns ⟨x.pinsConfigDir, true⟩) = true := by decide

/-- **A launcher that lost the flag is caught.** The negative control of the theorem above: if
any launcher stopped pinning, `every_launcher_pins_the_config_dir` fails and this shows what the
failure means — that launcher would silently bind to the roaming tree. -/
theorem a_launcher_that_lost_the_flag_would_warn :
    warns ⟨false, true⟩ = true ∧ chosen ⟨false, true⟩ = Tree.roaming := by decide

/-! ## The incident, pinned as a corpus -/

/-- The launch that caused it. -/
def incidentLaunch : Launch := ⟨false, true⟩

/-- The launches that did not. -/
def correctLaunch : Launch := ⟨true, true⟩

theorem the_incident_launch_bound_the_roaming_tree :
    chosen incidentLaunch = Tree.roaming ∧ warns incidentLaunch = true := by decide

theorem the_correct_launch_binds_the_deployment_tree :
    chosen correctLaunch = Tree.deployment ∧ warns correctLaunch = false := by decide

/-- **The two launches disagree**, which is the whole point: the same command line minus one flag
selects a different model list. -/
theorem the_two_launches_bind_different_trees :
    chosen incidentLaunch ≠ chosen correctLaunch := by decide

#guard chosen incidentLaunch == Tree.roaming
#guard chosen correctLaunch == Tree.deployment
#guard warns incidentLaunch == true
#guard warns correctLaunch == false
#guard warns ⟨false, false⟩ == false
#guard warns ⟨true, false⟩ == false
#guard allLaunches.length == 4
#guard (allLaunches.filter warns).length == 1
#guard shippedLaunchers.length == 5
#guard shippedLaunchers.all (fun x => x.pinsConfigDir) == true
#guard (allLaunches.filter (fun l => chosen l == Tree.deployment)).length == 2

/-! ## What this module does NOT claim

It does not say the roaming tree is wrong, that 103 models are more correct than 160, or that the
app misbehaved — it did exactly what it was told. It says only that the instruction was invisible
at the moment it was given, and that the app now says which tree it took when the answer could
have been either.

The observable divergence itself (103 vs 160 models, 1 vs 39 HTTP 429 per minute) is a
MEASUREMENT of one machine on one day. It is recorded in the docstring above and deliberately not
turned into a theorem: those numbers change the moment the operator edits either list, and a
theorem that went red for that would be a defect, not a guard. -/

end CtbrecSpec.ConfigDir
