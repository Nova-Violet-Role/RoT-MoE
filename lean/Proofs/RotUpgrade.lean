/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A successful install is not an upgrade, and the config is not the running build

Measured against the real CLI on 2026-08-08, installing the plugin into the CTT
instance while an older build was already present:

    claude plugin marketplace add <the extracted release directory>
      -> "Marketplace 'rot-moe' already on disk"          exit 0
    claude plugin install rot-moe@rot-moe
      -> "Plugin rot-moe@rot-moe is already installed"    exit 0

Both succeeded. Neither changed anything. The registry still read

    installPath: ...\plugins\cache\rot-moe\rot-moe\0.9.2
    version:     0.9.2

while `settings.json` named the new release directory as the marketplace source.
So the configuration said 1.0.1, the loop ran 0.9.2, and both commands exited 0.
`checker/ctt-session.sh` printed the truth -- 0.9.2 -- only because it reads the
REGISTRY. A harness that had read `settings.json` to decide what it was testing
would have measured the old build and labelled the result with the new version.

The uninstall-then-install sequence moved it to 1.0.1.

This module makes those three facts theorems rather than an anecdote in a
commit message.

**Success is not a state.** `install` returning ok tells you the command did not
fail; it does not tell you which build is now in the loop. The exit code is
constant across both branches, so nothing about the resulting version can be
inferred from it -- `exit_code_says_nothing_about_version` says exactly that,
and it is why the harness must read the registry after installing rather than
trusting the command it just ran.

**The config is not the running build.** Two different functions, and the theorem
`config_can_disagree_with_running` exhibits a reachable state where they differ.
Any check that reads the wrong one is measuring a build it is not running.

**The repair is sound and the naive form is not.** `upgrade_needs_uninstall_first`
proves the plain install leaves the old version when one is present;
`uninstall_then_install_upgrades` proves the two-step sequence lands on the
requested one. Both are needed: the second alone would not show the first is
required.
-/

namespace RotMoE.Upgrade

/-- A plugin version as the registry stores it. -/
abbrev Ver := String

/-- Where the CLI unpacks a build. The version is part of the path, which is why
a stale entry is visible on disk and not only in JSON. -/
def cachePath (v : Ver) : String :=
  "plugins/cache/rot-moe/rot-moe/" ++ v

/-- The installed-plugins registry: at most one entry for this plugin. -/
structure Registry where
  /-- The installed version and the path it was unpacked to, if any. -/
  entry : Option (Ver × String)
  deriving DecidableEq, Repr

/-- The user settings: which marketplace source is declared, and what that
source currently offers. -/
structure Config where
  /-- The marketplace directory named in settings. -/
  source : String
  /-- The version that directory currently contains. -/
  offers : Ver
  /-- Whether the plugin is enabled for the session. -/
  enabled : Bool
  deriving DecidableEq, Repr

/-- The build actually in the loop: whatever the registry points at. -/
def running (r : Registry) : Option Ver := r.entry.map Prod.fst

/-- The build a reader of settings would BELIEVE is in the loop. -/
def believed (c : Config) : Ver := c.offers

/-- The measured behaviour of `claude plugin install`. When an entry already
exists it reports success and changes nothing; otherwise it installs what the
source offers. The Bool is the success the command reports. -/
def install (r : Registry) (c : Config) : Registry × Bool :=
  match r.entry with
  | some _ => (r, true)
  | none => ({ entry := some (c.offers, cachePath c.offers) }, true)

/-- The measured behaviour of `claude plugin uninstall`. -/
def uninstall (_r : Registry) : Registry := { entry := none }

/-! ## Concrete states from the measurement -/

/-- CTT before the attempt: 0.9.2 installed from the old cache. -/
def before : Registry := { entry := some ("0.9.2", cachePath "0.9.2") }

/-- Settings after repointing at the extracted 1.0.1 release.

The source is a placeholder, not the path it was measured at: no theorem below
mentions `source`, so pinning a machine's directory into it would date the
module without strengthening anything -- and `checker/no-local-paths.sh` is
right to refuse it. -/
def cfg : Config :=
  { source := "<the extracted release directory>", offers := "1.0.1", enabled := true }

/-! ## Success is not a state -/

/-- The command reports success on a registry that already has an entry. -/
theorem install_reports_success_when_present : (install before cfg).2 = true := by decide

/-- And it reports success on an empty registry too. The exit code is the same
in both branches, so it carries no information about which build resulted --
this is why reading the registry afterwards is not optional. -/
theorem exit_code_says_nothing_about_version (r : Registry) (c : Config) :
    (install r c).2 = true := by
  cases r with
  | mk e => cases e <;> rfl

/-- **The defect.** Installing over an existing entry leaves the registry exactly
as it was, while reporting success. -/
theorem install_is_a_noop_when_present (r : Registry) (c : Config) (v : Ver) (p : String)
    (h : r.entry = some (v, p)) : (install r c).1 = r := by
  unfold install
  rw [h]

/-- Stated on the measured state: after a successful install, CTT was still
running 0.9.2 even though the source offered 1.0.1. -/
theorem still_running_the_old_build :
    running (install before cfg).1 = some "0.9.2" ∧ believed cfg = "1.0.1" := by decide

/-! ## The config is not the running build -/

/-- **A reachable state where the two disagree.** A checker that reads settings
to decide what it is testing reports 1.0.1 while the loop runs 0.9.2. -/
theorem config_can_disagree_with_running :
    running (install before cfg).1 ≠ some (believed cfg) := by decide

/-- The disagreement is not inevitable -- it is specifically what a no-op install
produces. From an empty registry the two agree, which is why the bug hides: on a
clean machine the naive reading is correct. -/
theorem clean_install_makes_them_agree (c : Config) :
    running (install { entry := none } c).1 = some (believed c) := by
  rfl

/-! ## The repair, and the proof that it is needed -/

/-- **The naive sequence does not upgrade.** With any entry present, a plain
install cannot reach a different version. -/
theorem upgrade_needs_uninstall_first (r : Registry) (c : Config) (v : Ver) (p : String)
    (h : r.entry = some (v, p)) : running (install r c).1 = some v := by
  unfold install running
  rw [h]
  simp [h]

/-- **The repair works, from any starting state.** -/
theorem uninstall_then_install_upgrades (r : Registry) (c : Config) :
    running (install (uninstall r) c).1 = some c.offers := by
  rfl

/-- And it lands on the right path too, so the on-disk evidence agrees with the
registry rather than only the version string matching. -/
theorem repair_fixes_the_path (r : Registry) (c : Config) :
    (install (uninstall r) c).1.entry = some (c.offers, cachePath c.offers) := by
  rfl

/-- Installing twice is the same as installing once: the second call is the
no-op branch. Idempotence is the reason a retry never fixes a stale entry. -/
theorem install_twice_is_install_once (r : Registry) (c : Config) :
    install (install r c).1 c = ((install r c).1, true) := by
  cases r with
  | mk e =>
    cases e with
    | none => rfl
    | some p => rfl

/-! ## What a harness must do -/

/-- An install attempt is SOUND only if the build in the loop afterwards is the
one the source offered. Success alone does not establish this. -/
def upgradeSound (r : Registry) (c : Config) : Prop :=
  running (install r c).1 = some c.offers

/-- The measured attempt was not sound. `upgradeSound` is a `Prop` wrapping a
decidable equation, so it has to be unfolded before `decide` can see one. -/
theorem the_measured_attempt_was_not_sound : ¬ upgradeSound before cfg := by
  unfold upgradeSound
  decide

/-- The measured repair was. -/
theorem the_measured_repair_was_sound : upgradeSound (uninstall before) cfg := by
  unfold upgradeSound
  rfl

/-! ## Executable checks -/

/-- The stale path really is the 0.9.2 cache directory. -/
example : (install before cfg).1.entry
    = some ("0.9.2", "plugins/cache/rot-moe/rot-moe/0.9.2") := by decide

/-- And the repaired one is the 1.0.1 directory. -/
example : (install (uninstall before) cfg).1.entry
    = some ("1.0.1", "plugins/cache/rot-moe/rot-moe/1.0.1") := by decide

end RotMoE.Upgrade
