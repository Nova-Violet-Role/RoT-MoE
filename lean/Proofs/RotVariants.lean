/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

/-!
# A download link that names nothing is the first instruction a reader follows

## The defect this file is about

`README.md` told three tiers to download `rot-moe-0.5.1-lean.zip` while
`checker/release-package.sh` was building `rot-moe-0.7.1-lean.zip`. Three links,
all wrong, for two minor versions, with every gate green — because nothing in the
repository ever compared the names. The release map had moved from a
hand-written line to a computed one, and the prose quoting it did not follow.

That is not a wrong number in a table. It is the **first instruction a new reader
follows**, and it fails with a 404 that reads as an abandoned project.

## What is proved here, and why the checker has two halves

`checker/readme-variants.sh` asks the packager for its map and then checks two
things. The obvious half is that every declared archive is **named** somewhere in
the docs. It is tempting to stop there, and stopping there would have left the
original defect completely undetected — because the README could perfectly well
have named the new archives *and kept the old ones*, which is exactly the state a
half-finished edit produces.

`covers_does_not_imply_clean` is that argument as a theorem: a document can name
every archive the packager builds and *still* carry a dead link. So the second
half of the checker — no named archive may be undeclared — is not belt and
braces, it is the half that catches staleness.

`sound_iff_setEq` states the pair together: a document passes both halves exactly
when the set of names it carries is the set the packager builds. Nothing weaker
is worth checking, and nothing stronger is true.

## What is NOT proved

That any file on disk satisfies this. Lean constrains the MODEL; the binding to
the real `README.md`, `RELEASE.md` and `docs/*.md` is the checker, which reads
the packager's own `--print-variants` output. Neither instrument substitutes for
the other, and the concrete historical case appears below only as `example`s —
executed evidence about a past state, never a hypothesis anything rests on.
-/

namespace RotMoE.Variants

/-- An archive name, reduced to the two things that can be wrong about it: which
tier it is, and which version it claims. The `rot-moe-` prefix and `.zip` suffix
are fixed by the packager and carry no information. -/
structure Archive where
  /-- The tier: `core`, `lean` or `unsealed`. -/
  tier : List Char
  /-- The version string the filename claims, e.g. `0.7.1`. -/
  ver : List Char
  deriving DecidableEq, Repr

/-- What the packager declares it builds — the output of `--print-variants`. -/
abbrev Declared := List Archive

/-- What a published document actually names. -/
abbrev Named := List Archive

/-- Every declared archive is named somewhere in the docs. The obvious half. -/
def covers (d : Declared) (n : Named) : Bool :=
  d.all (fun a => n.contains a)

/-- No name in the docs is an archive the packager does not build. The half that
catches staleness. -/
def clean (d : Declared) (n : Named) : Bool :=
  n.all (fun a => d.contains a)

/-- What the checker reports. -/
def sound (d : Declared) (n : Named) : Bool :=
  covers d n && clean d n

/-! ### The two halves are genuinely different -/

/-- **A document can name every archive the packager builds and still carry a
dead link.** This is the whole reason `readme-variants.sh` has a second half.

The witness is not invented: it is the shape the real README was in the moment
before the defect was found — the 0.7.x names could have been added while the
0.5.x links stayed, and a one-directional check would have called that green. -/
theorem covers_does_not_imply_clean :
    ∃ (d : Declared) (n : Named), covers d n = true ∧ clean d n = false := by
  refine ⟨[⟨"lean".toList, "0.7.1".toList⟩],
          [⟨"lean".toList, "0.7.1".toList⟩, ⟨"lean".toList, "0.5.1".toList⟩], ?_, ?_⟩
  · decide
  · decide

/-- And the converse gap: a document can be free of dead links while simply
failing to mention a tier at all. A tier with no download link is a tier nobody
can install. -/
theorem clean_does_not_imply_covers :
    ∃ (d : Declared) (n : Named), clean d n = true ∧ covers d n = false := by
  refine ⟨[⟨"core".toList, "0.7.0".toList⟩, ⟨"lean".toList, "0.7.1".toList⟩],
          [⟨"core".toList, "0.7.0".toList⟩], ?_, ?_⟩
  · decide
  · decide

/-- Neither half alone is the property. Both together are exactly it: the names
carried are the names built, in both directions. -/
theorem sound_iff_setEq (d : Declared) (n : Named) :
    sound d n = true ↔ ((∀ a ∈ d, a ∈ n) ∧ (∀ a ∈ n, a ∈ d)) := by
  simp [sound, covers, clean, List.all_eq_true]

/-! ### The historical defect, stated so it could not recur silently -/

/-- The packager's map as it stands: three tiers, patch digit = tier. -/
def shipped : Declared :=
  [⟨"core".toList, "0.7.0".toList⟩,
   ⟨"lean".toList, "0.7.1".toList⟩,
   ⟨"unsealed".toList, "0.7.2".toList⟩]

/-- What the README carried before the repair. -/
def staleReadme : Named :=
  [⟨"core".toList, "0.5.0".toList⟩,
   ⟨"lean".toList, "0.5.1".toList⟩,
   ⟨"unsealed".toList, "0.5.2".toList⟩]

/-- What it carries now. -/
def repairedReadme : Named := shipped

/-- **The defect was detectable.** The stale README fails, and it fails on BOTH
halves — it named nothing that existed and everything that did not. -/
theorem stale_readme_is_unsound : sound shipped staleReadme = false := by decide

/-- The repaired README passes. A checker that cannot pass is as useless as one
that cannot fail. -/
theorem repaired_readme_is_sound : sound shipped repairedReadme = true := by decide

/-- **A version bump alone makes a document unsound**, whatever else is right
about it. This is the durable statement: it is quantified over the tier and both
versions, so it stays true for a release map this project has not made yet. -/
theorem version_drift_breaks_soundness
    (t v v' : List Char) (h : v ≠ v') :
    sound [⟨t, v⟩] [⟨t, v'⟩] = false := by
  simp [sound, covers, clean, Archive.mk.injEq]
  intro hc
  exact absurd hc h

/-- Adding a tier to the packager without adding its link makes the docs
unsound — the failure mode a future release will actually hit. Stated over an
arbitrary map and an arbitrary new tier rather than over today's three. -/
theorem new_tier_needs_a_link (d : Declared) (n : Named) (a : Archive)
    (hnew : a ∉ n) : sound (a :: d) n = false := by
  simp [sound, covers, List.all_eq_true]
  exact fun hmem => absurd hmem hnew
/-! ### Executed evidence about the present -/

-- The map the packager prints today, and the README that quotes it.
example : sound shipped repairedReadme = true := by decide
example : sound shipped staleReadme = false := by decide

-- Each half, separately, on the historical case: the stale README covered
-- nothing and was not clean. Both readings are recorded because "it failed" is
-- less useful than "it failed for these two reasons".
example : covers shipped staleReadme = false := by decide
example : clean shipped staleReadme = false := by decide

-- The mixed state a half-finished edit produces: new links added, old ones left.
-- `covers` is satisfied; `clean` is not. This is the state a one-directional
-- check calls green, and it is the reason the second half exists.
example :
    covers shipped (repairedReadme ++ staleReadme) = true
    ∧ clean shipped (repairedReadme ++ staleReadme) = false := by decide

-- Three tiers, and the patch digit IS the tier.
example : shipped.length = 3 := by decide

end RotMoE.Variants
