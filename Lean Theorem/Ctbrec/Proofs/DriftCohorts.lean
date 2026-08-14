/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — a confounded corpus is not a dead end: partition it, do not merge it

`tools/drift-corpus.sh` measures A/V drift over the recordings on disk and refuses to state a drift
figure when the corpus was produced by more than one ffmpeg build:

```
n (admissible)    = 16
distinct binaries = 2
VERDICT: CONFOUNDED -- 2 different ffmpeg builds in one corpus.
         No pre/post drift claim is admissible from this cohort.
              5 libavcodec-62.29.101
             11 releaseVersion-8.0.1
```

**That verdict is correct, and it was checked rather than assumed.** The first reading of those two
labels was that they name the same binary under two log formats — the prefix in the app's log did
change from `using ffmpeg Version[...]` to `using ffmpeg with libavcodec Version[...]` when the
units bug was fixed, so the suspicion was reasonable. Measuring the three binaries on this machine
refuted it:

| path | version | libavcodec |
|---|---|---|
| `lib/ffmpeg/ffmpeg.exe` (bundled) | 7.1.3-Jellyfin | 61.19.101 |
| `…/Chocolatey/bin/ffmpeg.exe` | 8.0.1-full | **62.11.100** |
| `C:/Hybrid/64bit/ffmpeg.exe` | N-123549-g70537ec8e6 | **62.29.101** |

`62.29.101` and `62.11.100` are different muxers. The corpus really is mixed, and the conservative
verdict stands.

## The defect is what happens next

The corpus contains recordings from before the resolver fix and after it. Those old recordings never
expire, so `distinct binaries ≥ 2` **forever**, so the tool reports "no drift claim is admissible"
**forever**. An instrument that can never again produce a verdict on correct data is not
conservative, it is broken — the same shape as a theorem that freezes a contingent fact: green
today, and permanently uninformative tomorrow.

The fix is not to relax the homogeneity test. That test caught a real confound and weakening it
would be a violation. The fix is that **a mixed corpus is a set of homogeneous cohorts**: partition
by provenance, state a drift figure per cohort, and let the whole-corpus verdict stay CONFOUNDED.
Strictly more information, and nothing is loosened — `the_partition_never_merges_two_binaries` is
the guarantee that carries the old test's strength into the new one.
-/

import Proofs.Ctbrec.ModelViews

namespace CtbrecSpec

/-- A drift sample: which binary produced it (as an opaque provenance id) and the measured
video-minus-audio drift in milliseconds. -/
structure CohortSample where
  binary : Nat
  driftMs : Int
  deriving DecidableEq, Repr

/-- Every sample in the list came from the same binary. -/
def homogeneous : List CohortSample → Bool
  | [] => true
  | s :: rest => rest.all (fun t => t.binary == s.binary)

/-- The samples of one binary. -/
def cohortOf (b : Nat) (xs : List CohortSample) : List CohortSample :=
  xs.filter (fun s => s.binary == b)

/-- The distinct binaries present. Order is deliberately NOT specified: the tail is resolved first,
so this returns them in order of LAST appearance. Nothing below depends on the order, and saying so
is cheaper than a guard that pins an order the callers do not need. -/
def binaries : List CohortSample → List Nat
  | [] => []
  | s :: rest =>
    let r := binaries rest
    if r.contains s.binary then r else s.binary :: r

/-- The corpus split into one cohort per binary. -/
def partitionByBinary (xs : List CohortSample) : List (List CohortSample) :=
  (binaries xs).map (fun b => cohortOf b xs)

/-! ### The old test's strength is preserved -/

/-- **Every cohort is homogeneous.** This is the theorem that carries the confound test's guarantee
into the partitioned world: no cohort can mix two binaries, so a per-cohort drift figure is exactly
as admissible as a figure from a corpus that only ever saw one binary. -/
theorem every_cohort_is_homogeneous (b : Nat) (xs : List CohortSample) :
    homogeneous (cohortOf b xs) = true := by
  unfold cohortOf
  cases h : xs.filter (fun s => s.binary == b) with
  | nil => simp [homogeneous]
  | cons s rest =>
    simp only [homogeneous, List.all_eq_true]
    intro t ht
    have hs : s ∈ xs.filter (fun s => s.binary == b) := by rw [h]; exact List.mem_cons_self ..
    have htf : t ∈ xs.filter (fun s => s.binary == b) := by
      rw [h]; exact List.mem_cons_of_mem _ ht
    have h1 := (List.mem_filter.mp hs).2
    have h2 := (List.mem_filter.mp htf).2
    simp only [beq_iff_eq] at h1 h2 ⊢
    rw [h1, h2]

/-- **The partition never merges two binaries** — stated over the whole partition, so it is a
property of the method rather than of the two cohorts that happen to exist today. -/
theorem the_partition_never_merges_two_binaries (xs : List CohortSample) :
    (partitionByBinary xs).all homogeneous = true := by
  simp only [partitionByBinary, List.all_eq_true, List.mem_map]
  intro c hc
  obtain ⟨b, _, rfl⟩ := hc
  exact every_cohort_is_homogeneous b xs

/-! ### ...and no sample is lost, which is where a "fix" would cheat -/

/-- **Anti-amputation.** Dropping the awkward samples would also make every cohort homogeneous. Every
sample must still appear in the cohort of its own binary. -/
theorem no_sample_is_discarded (s : CohortSample) (xs : List CohortSample) (h : s ∈ xs) :
    s ∈ cohortOf s.binary xs := by
  unfold cohortOf
  exact List.mem_filter.mpr ⟨h, by simp⟩

/-- **A cohort contains only real samples** — the partition cannot invent data to reach a verdict. -/
theorem a_cohort_invents_nothing (b : Nat) (xs : List CohortSample) (s : CohortSample)
    (h : s ∈ cohortOf b xs) : s ∈ xs :=
  (List.mem_filter.mp h).1

/-! ### The whole-corpus verdict is NOT weakened -/

/-- What the tool reports about a corpus taken as one lump. -/
inductive CorpusVerdict where
  | homogeneousCorpus
  | confounded
  /-- **Added 2026-08-06.** The tool has always emitted a third verdict — `PROVENANCE UNKNOWN`,
  "an unread binary is not a matching binary" — and this model had only two. That gap made
  `spec-check` phase 64 infer CONFOUNDED from `distinct binaries > 1`, which is wrong whenever
  any sample is unreadable. See `provenance_unknown_dominates` below. -/
  | provenanceUnknown
  deriving DecidableEq, Repr

def corpusVerdict (xs : List CohortSample) : CorpusVerdict :=
  if (binaries xs).length ≤ 1 then .homogeneousCorpus else .confounded

/-- **The mixed corpus is still CONFOUNDED after the change.** Partitioning adds per-cohort figures;
it does not license a whole-corpus drift claim. The conservative answer survives intact — that is
the difference between amplifying an instrument and disarming it. -/
theorem a_mixed_corpus_stays_confounded (xs : List CohortSample)
    (h : 2 ≤ (binaries xs).length) : corpusVerdict xs = .confounded := by
  unfold corpusVerdict
  split
  · omega
  · rfl

/-- ...and a genuinely single-binary corpus is still allowed its verdict, so the test has not become
a blanket refusal. -/
theorem a_single_binary_corpus_is_still_admissible (xs : List CohortSample)
    (h : (binaries xs).length ≤ 1) : corpusVerdict xs = .homogeneousCorpus := by
  unfold corpusVerdict; simp [h]

/-- The worst drift in a cohort, as the tool reports it. -/
def worstDrift (xs : List CohortSample) : Nat :=
  xs.foldl (fun acc s => max acc s.driftMs.natAbs) 0

/-- **The worst drift of a cohort never exceeds the worst of the whole corpus.** So partitioning can
never manufacture a *better-looking* headline number than the corpus already had — the direction in
which a "fix" would be tempted to cheat. -/
theorem a_cohort_cannot_beat_the_corpus (b : Nat) (xs : List CohortSample) :
    worstDrift (cohortOf b xs) ≤ worstDrift xs := by
  unfold worstDrift cohortOf
  have gen : ∀ (l : List CohortSample) (a c : Nat), a ≤ c →
      (l.filter (fun s => s.binary == b)).foldl (fun acc s => max acc s.driftMs.natAbs) a
        ≤ l.foldl (fun acc s => max acc s.driftMs.natAbs) c := by
    intro l
    induction l with
    | nil => intro a c h; simpa using h
    | cons x rest ih =>
      intro a c h
      by_cases hx : (x.binary == b) = true
      · simp only [List.filter_cons, hx, List.foldl_cons, if_true]
        exact ih _ _ (by omega)
      · simp only [List.filter_cons, hx, List.foldl_cons, if_false, Bool.false_eq_true]
        exact ih _ _ (by omega)
  exact gen xs 0 0 (Nat.le_refl 0)

/-! ### Provenance, and the spec defect it exposed (2026-08-06)

**The spec was wrong, not the code.** Phase 64 read `distinct binaries = 2` and demanded
`VERDICT: CONFOUNDED`. On 2026-08-06 the corpus gained its first samples carrying a readable
`libavcodec-62.29.101` tag — because recording started working again after the linkage repair —
so `distinct binaries` went 1 → 2 while 22 of 24 samples still had no readable provenance. The
tool correctly answered `PROVENANCE UNKNOWN`, which is *stricter* than CONFOUNDED, and the phase
called that a failure.

That is the shape this project treats as a defect in the spec: a check pinned to a contingent
fact that goes red on a correct change, where the tempting repair — delete the assertion — would
destroy real coverage. The repair is to model the verdict the tool actually has. -/

/-- A sample as the corpus tool sees it BEFORE provenance is resolved. `binary = none` is
`binary=unknown` in the log: the encoder tag could not be read out of the container. -/
structure RawSample where
  binary  : Option Nat
  driftMs : Int
  deriving DecidableEq, Repr

/-- Samples whose provenance was readable, as `CohortSample`s. -/
def resolvedSamples (xs : List RawSample) : List CohortSample :=
  xs.filterMap (fun s => s.binary.map (fun b => { binary := b, driftMs := s.driftMs }))

/-- The verdict the tool actually emits. Unknown provenance is checked FIRST and dominates. -/
def rawVerdict (xs : List RawSample) : CorpusVerdict :=
  if xs.any (fun s => s.binary.isNone) then .provenanceUnknown
  else corpusVerdict (resolvedSamples xs)

/-- **THE THEOREM PHASE 64 WAS MISSING.** A single unreadable sample forces
`PROVENANCE UNKNOWN`, no matter how many distinct binaries the readable ones show. So
`distinct binaries ≥ 2` does NOT imply `CONFOUNDED`, and any checker that assumes it will go
red on a corpus that is merely honest about what it could not read. -/
theorem provenance_unknown_dominates (xs : List RawSample) (s : RawSample)
    (hs : s ∈ xs) (h : s.binary = none) : rawVerdict xs = .provenanceUnknown := by
  unfold rawVerdict
  have : xs.any (fun t => t.binary.isNone) = true := by
    simp only [List.any_eq_true]
    exact ⟨s, hs, by simp [h]⟩
  simp [this]

/-- **Nothing was weakened.** When every sample's provenance IS readable, the new three-valued
verdict agrees exactly with the old two-valued one. The added constructor can only ever make the
answer more conservative, never less. -/
theorem fully_known_agrees_with_the_old_verdict (xs : List RawSample)
    (h : xs.all (fun s => s.binary.isSome) = true) :
    rawVerdict xs = corpusVerdict (resolvedSamples xs) := by
  unfold rawVerdict
  have : xs.any (fun t => t.binary.isNone) = false := by
    simp only [List.all_eq_true] at h
    simp only [List.any_eq_false]
    intro t ht
    have := h t ht
    cases hb : t.binary <;> simp [hb] at this ⊢
  simp [this]

/-- No verdict licenses a whole-corpus drift claim except a genuinely homogeneous one. This is
what makes UNKNOWN *at least as strict* as CONFOUNDED rather than an escape hatch. -/
def licensesAWholeCorpusClaim : CorpusVerdict → Bool
  | .homogeneousCorpus => true
  | .confounded        => false
  | .provenanceUnknown => false

theorem unknown_provenance_licenses_nothing :
    licensesAWholeCorpusClaim .provenanceUnknown = false := by decide

/-- The three verdicts are genuinely distinct — without this the new constructor could be a
synonym for one of the others and the fix would be cosmetic. -/
theorem the_three_verdicts_are_distinct :
    CorpusVerdict.provenanceUnknown ≠ .confounded ∧
    CorpusVerdict.provenanceUnknown ≠ .homogeneousCorpus ∧
    CorpusVerdict.confounded ≠ .homogeneousCorpus := by
  decide

/-- **THE LIVE CORPUS OF 2026-08-06**, in miniature: two samples with a readable and *different*
binary, one sample without. `distinct binaries = 2`, and the verdict is UNKNOWN, not CONFOUNDED.
This is the exact configuration that turned phase 64 red on a correct tree. -/
def liveCorpusShape : List RawSample :=
  [{ binary := some 62, driftMs := 1000 },
   { binary := some 61, driftMs := -183 },
   { binary := none,    driftMs := -1433 }]

theorem the_live_corpus_is_unknown_not_confounded :
    rawVerdict liveCorpusShape = .provenanceUnknown ∧
    (binaries (resolvedSamples liveCorpusShape)).length = 2 := by
  decide

/-- And with the unreadable sample removed it WOULD be confounded — so the dominance above is
doing real work rather than swallowing every corpus. -/
theorem removing_the_unreadable_sample_gives_confounded :
    rawVerdict [{ binary := some 62, driftMs := 1000 },
                { binary := some 61, driftMs := -183 }] = .confounded := by
  decide

/-- ...and a readable single-binary corpus still gets its admissible verdict, so the three-valued
model has not become a blanket refusal. -/
theorem a_readable_single_binary_corpus_is_still_admissible :
    rawVerdict [{ binary := some 62, driftMs := 1000 },
                { binary := some 62, driftMs := -183 }] = .homogeneousCorpus := by
  decide

#guard rawVerdict liveCorpusShape == CorpusVerdict.provenanceUnknown
#guard licensesAWholeCorpusClaim (rawVerdict liveCorpusShape) == false
#guard (resolvedSamples liveCorpusShape).length == 2
#guard rawVerdict [] == CorpusVerdict.homogeneousCorpus
#guard rawVerdict [{ binary := none, driftMs := 0 }] == CorpusVerdict.provenanceUnknown
#guard licensesAWholeCorpusClaim CorpusVerdict.confounded == false
#guard licensesAWholeCorpusClaim CorpusVerdict.homogeneousCorpus == true

#guard homogeneous [] == true
#guard homogeneous [{ binary := 1, driftMs := 5 }] == true
#guard homogeneous [{ binary := 1, driftMs := 5 }, { binary := 1, driftMs := -3 }] == true
#guard homogeneous [{ binary := 1, driftMs := 5 }, { binary := 2, driftMs := -3 }] == false
#guard binaries [{ binary := 1, driftMs := 5 }, { binary := 2, driftMs := 1 },
                 { binary := 1, driftMs := 0 }] == [2, 1]
#guard (partitionByBinary [{ binary := 1, driftMs := 5 }, { binary := 2, driftMs := 1 },
                           { binary := 1, driftMs := 0 }]).length == 2
#guard corpusVerdict [{ binary := 1, driftMs := 5 }, { binary := 2, driftMs := 1 }]
        == CorpusVerdict.confounded
#guard corpusVerdict [{ binary := 1, driftMs := 5 }, { binary := 1, driftMs := 1 }]
        == CorpusVerdict.homogeneousCorpus
#guard worstDrift [{ binary := 1, driftMs := 5 }, { binary := 2, driftMs := -1433 }] == 1433
#guard worstDrift (cohortOf 1 [{ binary := 1, driftMs := 5 },
                               { binary := 2, driftMs := -1433 }]) == 5

end CtbrecSpec
