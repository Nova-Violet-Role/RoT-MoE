/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A local-only release is evidence only while it regenerates

`checker/release-local.sh` builds `1.0.0 / 1.0.1 / 1.0.2` into a `.gitignore`d
directory, installs them into CTT, and must never publish them. This module says
what "must never publish" and "still fresh" actually MEAN, so the checker has
something to be checked against rather than a set of habits.

The hazard being modelled is not a missing artifact. It is a **stale** one: a zip
that installs cleanly, passes every session test, and credits code that is not
what shipped. A missing artifact announces itself; a stale one is silently
reassuring, which is the direction that costs you.

Four claims, and one of them is deliberately a non-theorem:

* `local_never_publishable`  — a locally stamped version can never be read as a
  release tag, whatever the counter says.
* `stale_is_not_fresh`       — freshness is regeneration from the *current* head,
  not the presence of a file.
* `fresh_survives_rebuild`   — rebuilding at the same head keeps it fresh, so the
  predicate is not vacuously false.
* `unmeasured_is_not_equal`  — a comparison that could not run is NOT a pass, and
  it is not a failure of the artifact either. Three outcomes, never two.
-/

namespace RotMoE
namespace LocalRelease

/-- A version as the packager sees it: three numbers, plus an optional local
stamp. `local?` is what makes a build unpublishable — it is not cosmetic. -/
structure Version where
  major : Nat
  minor : Nat
  patch : Nat
  /-- `some n` = the n-th local build; `none` = a version that could be tagged. -/
  localBuild : Option Nat
  deriving DecidableEq, Repr

/-- A release artifact, reduced to what actually decides trust: which commit it
was built from, and the digest of what a stranger would unpack. -/
structure Artifact where
  version : Version
  /-- The commit the artifact was built from. -/
  builtFrom : Nat
  /-- Digest of the unpacked CONTENTS, not of the zip bytes: two zips of
  identical trees differ in stored timestamps, so a byte comparison would fail
  on a correct pair and train the reader to ignore it. -/
  digest : Nat
  deriving DecidableEq, Repr

/-- Publishable means tagged, and a local build is by definition not tagged. -/
def publishable (v : Version) : Bool := v.localBuild.isNone

/-- The checker's phase 4, as a predicate: an artifact is fresh at `head` when it
was built from `head` AND regenerating at `head` yields the same contents. -/
def fresh (a : Artifact) (head : Nat) (regenDigest : Nat) : Bool :=
  a.builtFrom = head && a.digest = regenDigest

/-- The outcome of comparing an artifact against a regeneration. `unmeasured` is
a first-class citizen: folding it into `differs` would report a broken instrument
as a broken artifact, and folding it into `same` would report it as a pass. -/
inductive Compared where
  | same
  | differs
  | unmeasured
  deriving DecidableEq, Repr

/-- Classification. `none` for the regeneration digest models "the digest tool
did not produce an answer" — the case a `&&` chain silently swallows. -/
def classify (a : Artifact) (head : Nat) : Option Nat → Compared
  | none => Compared.unmeasured
  | some d => if fresh a head d then Compared.same else Compared.differs

/-- Only `same` may be counted as evidence of reproducibility. -/
def isEvidence : Compared → Bool
  | Compared.same => true
  | _ => false

/-- **A locally stamped version is never publishable** — for every build number.
Stated over `n` rather than over the current counter: the point is that no local
build, however many there have been, becomes taggable by ageing. -/
theorem local_never_publishable (maj min pat n : Nat) :
    publishable ⟨maj, min, pat, some n⟩ = false := by
  simp [publishable]

/-- **An artifact built from another commit is not fresh**, even when its
contents happen to match the regeneration. This is the stale case: the digests
can coincide (nothing relevant changed) and the artifact is still not evidence
*about this head*. -/
theorem stale_is_not_fresh (a : Artifact) (head d : Nat) (h : a.builtFrom ≠ head) :
    fresh a head d = false := by
  simp [fresh, h]

/-- **Freshness is achievable** — the predicate is not vacuously false. Without
this the three theorems above would be satisfied by a `fresh` that never holds,
and the checker would be enforcing an impossibility. -/
theorem fresh_survives_rebuild (a : Artifact) :
    fresh a a.builtFrom a.digest = true := by
  simp [fresh]

/-- **An unmeasured comparison is not evidence.** The `&&`-chain defect, stated:
if the digest tool returns nothing, the artifact must not be counted as
reproducible. -/
theorem unmeasured_is_not_evidence (a : Artifact) (head : Nat) :
    isEvidence (classify a head none) = false := by
  simp [classify, isEvidence]

/-- **…and it is not a mismatch either.** The other half, and the one that makes
the three-way split load-bearing: `unmeasured` is distinct from `differs`, so a
broken instrument can never be reported as a broken artifact. -/
theorem unmeasured_is_not_differs (a : Artifact) (head : Nat) :
    classify a head none ≠ Compared.differs := by
  simp [classify]

/-- **Evidence requires freshness.** The bridge from the comparison back to the
artifact: if a classification counts as evidence, the artifact really was built
from this head and really did regenerate. -/
theorem evidence_implies_fresh (a : Artifact) (head d : Nat)
    (h : isEvidence (classify a head (some d)) = true) :
    fresh a head d = true := by
  by_cases hf : fresh a head d
  · exact hf
  · simp [classify, hf, isEvidence] at h

/-- **Something IS evidence** — a regenerating artifact at its own head passes.

Added after mutant `L06` survived. Rewriting `isEvidence Compared.same` to
`false` left the module green, because every theorem above it is an implication
*out of* `isEvidence`, and an `isEvidence` that never holds satisfies all of them
vacuously. The module therefore permitted the worst kind of checker: one that
cannot pass on any input, is green forever, and gets deleted the first time
someone needs it to succeed. This is the theorem that forbids it. -/
theorem fresh_is_evidence (a : Artifact) :
    isEvidence (classify a a.builtFrom (some a.digest)) = true := by
  simp [classify, fresh, isEvidence]

/-- **A tagged version is not automatically evidence.** Guards against the
overclaim that publishability and freshness are the same axis: a version with no
local stamp is publishable, and says nothing whatever about whether the artifact
regenerates. -/
theorem publishable_says_nothing_about_freshness :
    ∃ a : Artifact, publishable a.version = true ∧
      fresh a (a.builtFrom + 1) a.digest = false := by
  refine ⟨⟨⟨1, 0, 2, none⟩, 7, 42⟩, by simp [publishable], ?_⟩
  simp [fresh]

/-- The counter cannot rescue a local build: `1.0.0-local.N` is unpublishable for
every `N`, which is the property the STAMP file relies on. -/
example : publishable ⟨1, 0, 0, some 3⟩ = false := by decide

/-- A plain `1.0.0` is publishable — so `publishable` is not constantly false. -/
example : publishable ⟨1, 0, 0, none⟩ = true := by decide

/-- Same head, same digest: fresh. -/
example : fresh ⟨⟨1, 0, 2, some 1⟩, 99, 5⟩ 99 5 = true := by decide

/-- Same digest, different head: NOT fresh. The stale case, executed. -/
example : fresh ⟨⟨1, 0, 2, some 1⟩, 98, 5⟩ 99 5 = false := by decide

/-- The three-way split, executed on concrete inputs. -/
example : classify ⟨⟨1, 0, 2, some 1⟩, 99, 5⟩ 99 (some 5) = Compared.same := by decide
example : classify ⟨⟨1, 0, 2, some 1⟩, 99, 5⟩ 99 (some 6) = Compared.differs := by decide
example : classify ⟨⟨1, 0, 2, some 1⟩, 99, 5⟩ 99 none = Compared.unmeasured := by decide

end LocalRelease
end RotMoE
