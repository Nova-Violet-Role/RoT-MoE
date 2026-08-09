/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A fix nobody can install is not a fix: version ORDER, not version CHANGE

`RotUpgrade` models the install mechanism and proves that a successful install
is not an upgrade. It carries `abbrev Ver := String`, so it can say the version
CHANGED and cannot say the version ROSE. That distinction is the whole content
of this module, and the gap it leaves was measured on 2026-08-09:

    repository  .claude-plugin/plugin.json      0.9.2   (8 commits unchanged)
    deployed    ~/.claude/plugins/cache/...     1.0.1
    CTT         .rot-release/.../plugin.json    1.0.1

Every provenance repair proved in `RotSessionLog` sits in a build numbered
BELOW the build already installed. A marketplace offering 0.9.2 to an install
running 1.0.1 offers a downgrade, so the fix reaches nobody -- and every gate in
the repository stays green, because each one asks whether the code is correct
and none asks whether it is REACHABLE.

## What is proved here, and what is deliberately not

The durable statement is about ORDER, quantified over the digits that move:
`lower_major_never_supersedes`, `patch_cannot_beat_a_higher_minor`,
`reinstall_is_not_an_upgrade`. Those stay true through every future release.

The measured pair (0.9.2 against 1.0.1) is a `#guard`, NOT a theorem. It is a
fact about today that a correct release is supposed to falsify: the moment the
version is bumped past 1.0.1 the pair stops being a downgrade, and a theorem
asserting otherwise would go red on the very commit that fixes the problem.
Freezing a contingent fact as an invariant is how a spec starts forbidding
correct futures, so the contingent half is pinned where it belongs.

`supersedes` is stated as a Bool so the checker can execute the same predicate
the theorems constrain, rather than reimplementing the comparison in shell --
which is where a second, subtly different ordering would be born.
-/

namespace RotMoE.Release

/-- A semantic version as the plugin manifest and the cache path both spell it. -/
structure SemVer where
  major : Nat
  minor : Nat
  patch : Nat
deriving DecidableEq, Repr

/-- Lexicographic strict order: major, then minor, then patch. Written as a
`Bool` on purpose -- the release checker executes this exact function, so the
shell cannot drift into a different comparison. -/
def lt (a b : SemVer) : Bool :=
  a.major < b.major ||
    (a.major == b.major &&
      (a.minor < b.minor || (a.minor == b.minor && a.patch < b.patch)))

/-- `candidate` may be published over `deployed` only if it is strictly newer.
Equality is NOT enough: an equal version is the case the CLI reports as
"already installed" and exits 0 on, which `RotUpgrade` proves changes nothing. -/
def supersedes (candidate deployed : SemVer) : Bool := lt deployed candidate

section Order

/-- THE BRIDGE, proved once. Every ordering result below goes through this
rather than re-deriving the boolean algebra, because a `= false` goal and a
`= true` goal need different `simp` lemmas and mixing them by hand is how two
of these proofs failed on the first build. -/
theorem lt_iff (a b : SemVer) :
    lt a b = true ↔
      (a.major < b.major ∨
        (a.major = b.major ∧
          (a.minor < b.minor ∨ (a.minor = b.minor ∧ a.patch < b.patch)))) := by
  simp [lt]

theorem lt_irrefl (v : SemVer) : lt v v = false := by
  simp [lt]

theorem lt_asymm {a b : SemVer} (h : lt a b = true) : lt b a = false := by
  have hn : ¬ (lt b a = true) := by
    intro hba
    rw [lt_iff] at h hba
    omega
  simpa using hn

theorem lt_trans {a b c : SemVer} (hab : lt a b = true) (hbc : lt b c = true) :
    lt a c = true := by
  rw [lt_iff] at hab hbc ⊢
  omega

/-- Publishing the same number again is never an upgrade. This is the formal
content of the CLI's "already installed", exit 0. -/
theorem reinstall_is_not_an_upgrade (v : SemVer) : supersedes v v = false := by
  simp [supersedes, lt_irrefl]

/-- Two builds cannot each supersede the other. -/
theorem supersession_is_one_way {a b : SemVer} (h : supersedes a b = true) :
    supersedes b a = false := by
  exact lt_asymm h

end Order

section TheDefectClass

/-- THE MEASURED SHAPE, stated generally. A candidate whose MAJOR is lower can
never supersede, no matter how far its minor and patch have advanced. This is
why 0.9.2 cannot reach a 1.0.1 install, and it is quantified over every digit
so it does not expire when those digits move. -/
theorem lower_major_never_supersedes (a b : SemVer) (h : a.major < b.major) :
    supersedes a b = false := by
  have hn : ¬ (lt b a = true) := by
    intro hba
    rw [lt_iff] at hba
    omega
  simpa [supersedes] using hn

/-- Same-line specialisation. `lt_iff` leaves `SemVer.major ⟨M, m, p⟩` standing
as an opaque projection, which `omega` cannot see through -- measured, it is why
the two theorems below failed to close on the first attempt. -/
theorem lt_sameMajor (M m₁ p m₂ q : Nat) :
    lt ⟨M, m₁, p⟩ ⟨M, m₂, q⟩ = true ↔ (m₁ < m₂ ∨ (m₁ = m₂ ∧ p < q)) := by
  simp [lt]

/-- A patch digit cannot compensate for a lower minor. The tempting repair for
a stalled release is to bump the patch; against a higher minor it does nothing. -/
theorem patch_cannot_beat_a_higher_minor (M m₁ m₂ p q : Nat) (h : m₁ < m₂) :
    supersedes ⟨M, m₁, p⟩ ⟨M, m₂, q⟩ = false := by
  have hn : ¬ (lt ⟨M, m₂, q⟩ ⟨M, m₁, p⟩ = true) := by
    intro hba
    rw [lt_sameMajor] at hba
    omega
  simpa [supersedes] using hn

/-- And the positive direction: raising the minor supersedes regardless of how
high the old patch had climbed. -/
theorem a_higher_minor_always_wins (M m₁ m₂ p q : Nat) (h : m₁ < m₂) :
    supersedes ⟨M, m₂, q⟩ ⟨M, m₁, p⟩ = true := by
  rw [supersedes, lt_sameMajor]
  omega

end TheDefectClass

section Variants

/-- The three shipped variants share one MAJOR.MINOR and differ only in the
patch digit, which IS the tier: 0 core, 1 lean, 2 unsealed. This mirrors
`checker/release-package.sh`, which computes the same map from the manifest. -/
inductive Tier where
  | core
  | lean
  | unsealed
deriving DecidableEq, Repr

def Tier.patch : Tier → Nat
  | .core => 0
  | .lean => 1
  | .unsealed => 2

def variantOf (M m : Nat) (t : Tier) : SemVer := ⟨M, m, t.patch⟩

/-- Within one release line the three variants are strictly ordered. -/
theorem variants_are_ordered (M m : Nat) :
    lt (variantOf M m .core) (variantOf M m .lean) = true ∧
    lt (variantOf M m .lean) (variantOf M m .unsealed) = true := by
  constructor <;> simp [lt, variantOf, Tier.patch]

/-- THE PROPERTY THE RELEASE PROCESS ACTUALLY NEEDS: bumping the minor
supersedes EVERY variant of the previous line, including its unsealed tier.
Publishing only a new core build over an old unsealed install is the subtle way
to ship a version that cannot reach the people running the fullest variant. -/
theorem a_new_line_supersedes_every_old_variant (M m : Nat) (t t' : Tier) :
    supersedes (variantOf M (m + 1) t) (variantOf M m t') = true := by
  cases t <;> cases t' <;>
    simp [supersedes, lt, variantOf, Tier.patch]

end Variants

section Publishing

/-- Can this candidate be published given everything already deployed? Every
known install must be strictly older. `List.all` over the deployed set is the
point: superseding the newest is not enough if an older channel carries a
higher number, which is exactly the state measured on 2026-08-09. -/
def canPublish (candidate : SemVer) (deployed : List SemVer) : Bool :=
  deployed.all (fun d => supersedes candidate d)

theorem canPublish_nil (v : SemVer) : canPublish v [] = true := by
  simp [canPublish]

/-- One install that is not superseded blocks the release. -/
theorem one_stale_channel_blocks_publication
    (cand d : SemVer) (ds : List SemVer) (h : supersedes cand d = false) :
    canPublish cand (d :: ds) = false := by
  simp [canPublish, h]

/-- A candidate can never be published against itself -- the reinstall case
again, now at the level of the whole deployed set. -/
theorem cannot_publish_over_itself (v : SemVer) (ds : List SemVer) :
    canPublish v (v :: ds) = false := by
  simp [canPublish, reinstall_is_not_an_upgrade]

end Publishing

section Measured

/-! The CONTINGENT half. These are `#guard`s, never theorems: a correct release
is supposed to falsify them, and a theorem here would go red on the commit that
fixes the problem. -/

/-- What the repository declared on 2026-08-09. -/
def repoDeclared : SemVer := ⟨0, 9, 2⟩

/-- What was actually installed, in production and in the CTT instance. -/
def deployedProduction : SemVer := ⟨1, 0, 1⟩

-- The blocking fact: the tree could not upgrade the field.
#guard supersedes repoDeclared deployedProduction = false
-- And the direction is not symmetric confusion -- the deployed build is newer.
#guard supersedes deployedProduction repoDeclared = true
-- Bumping only the patch, the tempting repair, still fails.
#guard supersedes ⟨0, 9, 3⟩ deployedProduction = false
-- The smallest bump that actually reaches a 1.0.1 install.
#guard supersedes ⟨1, 0, 2⟩ deployedProduction = true
-- The whole 1.1 line reaches it, every variant.
#guard canPublish ⟨1, 1, 0⟩ [deployedProduction, repoDeclared] = true
-- ... while the 0.9 line reaches neither.
#guard canPublish repoDeclared [deployedProduction] = false
-- Executable agreement with the ordering theorems on concrete triples.
#guard lt ⟨0, 9, 2⟩ ⟨1, 0, 1⟩ = true
#guard lt ⟨1, 0, 1⟩ ⟨0, 9, 2⟩ = false
#guard lt ⟨1, 0, 1⟩ ⟨1, 0, 1⟩ = false
#guard variantOf 1 1 .unsealed = ⟨1, 1, 2⟩

end Measured

end RotMoE.Release
