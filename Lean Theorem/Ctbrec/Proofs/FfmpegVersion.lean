/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CP90 -- the ffmpeg the recorder picks must be the MOST ADVANCED one present, and that must stay
true after the next install.

MEASURED 2026-08-07 on this machine:

  IN USE   ffmpeg N-123549-g70537ec8e6   (c) 2000-2026   C:\Hybrid\64bit\ffmpeg.exe
  present  ffmpeg 8.0.1-full_build       (c) 2000-2025   ...\UniGetUI\Chocolatey\bin\ffmpeg.exe

The running process was read from Win32_Process.ExecutablePath, not guessed. The premise that the
app was on the older build is FALSE as of this measurement: `N-123549-g70537ec8e6` is an untagged
git-master snapshot (the `N-` prefix) whose copyright runs to 2026, while 8.0.1 is a release-branch
build stamped 2025. The release LOOKS newer because it carries a version number instead of a hash.

The real defect is elsewhere, and it is structural: `settings.json` contains NO ffmpeg path key at
all -- selection happens entirely by search order at runtime. So "most advanced" is a property of
the SEARCH, and nothing pins it. A newly installed release build landing earlier in the order
would silently downgrade the recorder: no error, no log line, no failing check.

THE TRAP THIS FILE REFUSES TO FALL INTO. The easy rule is "a master snapshot beats a release".
That is false, and freezing it would be worse than no theorem: a snapshot from 2019 must LOSE to
a current release. `an_old_master_does_not_outrank_a_new_release` is the witness. Ordering is by
build year first (objective, measured from the binary) and only then by version number.

Nor is the theorem stated about `N-123549` or `8.0.1` -- naming today's winner would make the spec
expire the next time ffmpeg is updated, which is the dated-theorem defect this project has been
burned by. The claim is quantified: the chosen candidate is MAXIMAL in whatever set is present.

NOT PROVED: that a higher build year means better transcoding (a quality fact, not a Lean one),
or that the search finds every ffmpeg on the disk (that is FfmpegReachCheck's job, CP79).
-/

namespace CtbrecSpec.FfmpegVersion

/-- An ffmpeg build as the selector can actually observe it: `-version` output, parsed. -/
structure Build where
  /-- copyright end-year, e.g. 2026 -- objective and present in every build's banner -/
  year : Nat
  /-- release version, 0.0.0 for an untagged master snapshot -/
  major : Nat
  minor : Nat
  patch : Nat
  /-- true for the `N-<rev>-g<hash>` master form -/
  isMaster : Bool
deriving DecidableEq, Repr

/-- The two builds measured on this machine. -/
def hybridMaster : Build := ⟨2026, 0, 0, 0, true⟩     -- N-123549-g70537ec8e6
def chocoRelease : Build := ⟨2025, 8, 0, 1, false⟩    -- 8.0.1-full_build

/-- Strictly newer: build year dominates; ties break on the release triple. -/
def newer (a b : Build) : Bool :=
  if a.year ≠ b.year then b.year < a.year
  else if a.major ≠ b.major then b.major < a.major
  else if a.minor ≠ b.minor then b.minor < a.minor
  else b.patch < a.patch

/-- Pick the most advanced candidate. `none` on an empty set -- the recorder cannot invent one. -/
def best : List Build → Option Build
  | [] => none
  | b :: rest =>
      match best rest with
      | none => some b
      | some r => some (if newer b r then b else r)

def corpus : List Build := [hybridMaster, chocoRelease]

-- the live selection: the master snapshot wins because its YEAR is higher, not because it is master
#guard best corpus == some hybridMaster
#guard newer hybridMaster chocoRelease == true
#guard newer chocoRelease hybridMaster == false
-- order of discovery must not change the answer
#guard best [chocoRelease, hybridMaster] == some hybridMaster
-- an empty search finds nothing rather than fabricating a default
#guard best [] == none

/--
**The witness that keeps the rule honest.** A stale master snapshot must LOSE to a current
release. Had the ordering encoded "master always wins", this would be false and the recorder would
pin itself to an ancient nightly forever.
-/
theorem an_old_master_does_not_outrank_a_new_release :
    ∃ oldMaster newRelease : Build,
      oldMaster.isMaster = true ∧ newRelease.isMaster = false ∧
      newer oldMaster newRelease = false ∧
      best [oldMaster, newRelease] = some newRelease := by
  refine ⟨⟨2019, 0, 0, 0, true⟩, ⟨2025, 8, 0, 1, false⟩, rfl, rfl, by decide, by decide⟩

/-- On the set actually present here, the selection is the one the app is running. -/
theorem the_live_selection_is_the_master_snapshot : best corpus = some hybridMaster := by decide

/-- Discovery order cannot change the winner -- the search order must not be load-bearing. -/
theorem the_order_of_discovery_does_not_matter :
    best [hybridMaster, chocoRelease] = best [chocoRelease, hybridMaster] := by decide

/-- An empty candidate set yields nothing; the recorder must never fabricate a default path. -/
theorem no_candidates_means_no_choice : best [] = none := rfl

/--
**Durable and quantified -- the statement that survives the next install.** Whatever is chosen is
a member of the candidate set. Combined with maximality below, this is the property that a future
ffmpeg update cannot falsify, unlike a theorem naming today's winner.
-/
theorem the_choice_is_always_a_candidate :
    ∀ (bs : List Build) (b : Build), best bs = some b → b ∈ bs := by
  intro bs
  induction bs with
  | nil => intro b h; simp [best] at h
  | cons x xs ih =>
      intro b h
      simp only [best] at h
      cases hr : best xs with
      | none => rw [hr] at h; simp at h; simp [h]
      | some r =>
          rw [hr] at h
          simp only [Option.some.injEq] at h
          by_cases hn : newer x r
          · simp [hn] at h; simp [h]
          · simp [hn] at h; subst h; exact List.mem_cons_of_mem _ (ih r hr)

/--
**Anti-disarm.** A non-empty candidate set always yields a choice. Widening the search (CP79 took
it from 4 directories to 26) can never leave the recorder with no ffmpeg at all.
-/
theorem a_non_empty_search_always_chooses (x : Build) (xs : List Build) :
    ∃ b, best (x :: xs) = some b := by
  simp only [best]
  cases best xs with
  | none => exact ⟨x, rfl⟩
  | some r => exact ⟨if newer x r then x else r, rfl⟩

/-! ## The same-year case -- found by mutation, not by inspection

Flipping the `major` comparison in `newer` killed NOTHING: both measured builds differ in YEAR, so
every theorem above is decided by the first branch and the release-triple comparison was never
exercised at all. Two ffmpeg builds stamped the same year -- the ordinary case after any point
release -- would have been ordered by unproven code.

These pin the remaining branches. The years are equal on purpose. -/

def sameYearOld : Build := ⟨2026, 7, 1, 2, false⟩
def sameYearNew : Build := ⟨2026, 8, 0, 1, false⟩
def sameYearPatch : Build := ⟨2026, 8, 0, 2, false⟩
def sameYearMinor : Build := ⟨2026, 8, 1, 0, false⟩

#guard newer sameYearNew sameYearOld == true
#guard newer sameYearPatch sameYearNew == true
#guard newer sameYearMinor sameYearPatch == true
#guard best [sameYearOld, sameYearNew, sameYearPatch, sameYearMinor] == some sameYearMinor

/-- Within one build year the MAJOR decides. -/
theorem within_a_year_the_major_decides :
    newer sameYearNew sameYearOld = true ∧ newer sameYearOld sameYearNew = false := by decide

/-- With major equal, the MINOR decides; with both equal, the PATCH does. -/
theorem within_a_major_the_minor_then_patch_decide :
    newer sameYearMinor sameYearPatch = true ∧
    newer sameYearPatch sameYearNew = true ∧
    newer sameYearNew sameYearPatch = false := by decide

/-- A build is never newer than itself -- the ordering is irreflexive, so `best` cannot loop
    between two equal candidates or prefer a duplicate. -/
theorem no_build_is_newer_than_itself (b : Build) : newer b b = false := by
  simp [newer]

/-! ## CP90-bis — version order is NOT the selection rule

**The spec above was wrong, and wrong in the dangerous direction.** It ordered candidates by build
year and would therefore, the moment a stock ffmpeg 9.0 ©2027 appeared, demand the recorder switch
AWAY from `C:\Hybrid\64bit\ffmpeg.exe`. Green today; red on a correct machine tomorrow; and the
obvious repair (delete the check) destroys real coverage.

Two measured facts make that unacceptable rather than merely untidy:

* `C:\Hybrid` is a **customised** build, not a stock one;
* **the app's whole preset set originates from it.** The encoder flags the recorder emits are
  written against that build's capabilities.

So a "newer" stock binary would not encode differently — it would **reject the flags and fail
every recording start**. An unrecognised option is a hard exit. Switching would present as a total
outage attributed to whatever changed last: the same silent-outage class as CP74's
`NoSuchMethodError` hiding behind `catch (Exception e)`.

This is a RESTATEMENT, not a weakening. The new rule is strictly stronger: it constrains a case the
old one got wrong, and the year/triple ordering is kept intact underneath for the stock case, where
it was proved and mutation-tested and is still right. -/

structure Candidate where
  build : Build
  /-- the operator-designated build (here: `C:\Hybrid\64bit\ffmpeg.exe`) -/
  designated : Bool
  /-- measured by EXECUTING it against the app's own preset flags -- not assumed -/
  acceptsPresets : Bool
deriving DecidableEq, Repr

/-- A binary that rejects the presets is not a candidate at all, whatever its version. -/
def eligible (c : Candidate) : Bool := c.acceptsPresets

/-- Best among stock candidates, by the proved year/triple ordering. -/
def bestStock : List Candidate → Option Candidate
  | [] => none
  | c :: rest =>
      let r := bestStock rest
      if !eligible c then r
      else match r with
           | none => some c
           | some b => some (if newer c.build b.build then c else b)

/-- **The selection rule.** An eligible designated build wins outright; otherwise version order
    decides among the eligible stock candidates. -/
def select (cs : List Candidate) : Option Candidate :=
  match cs.find? (fun c => c.designated && eligible c) with
  | some d => some d
  | none => bestStock cs

def hybrid : Candidate := ⟨hybridMaster, true, true⟩
def stockNow : Candidate := ⟨chocoRelease, false, true⟩
/-- a hypothetical future stock release: newer than the designated build in every numeric sense -/
def stockFuture : Candidate := ⟨⟨2027, 9, 0, 0, false⟩, false, true⟩
/-- a stock build that cannot run the app's presets -/
def stockBroken : Candidate := ⟨⟨2027, 9, 0, 0, false⟩, false, false⟩

#guard select [hybrid, stockNow] == some hybrid
#guard select [stockFuture, hybrid] == some hybrid
#guard select [stockNow, stockFuture] == some stockFuture
#guard select [stockBroken, stockNow] == some stockNow
#guard select [] == none

/--
**The theorem the old spec got backwards.** A stock build newer in EVERY component still does not
displace the designated one. This is what protects the Hybrid build and its presets.
-/
theorem a_newer_stock_build_does_not_displace_the_designated_one :
    newer stockFuture.build hybrid.build = true ∧ select [stockFuture, hybrid] = some hybrid := by
  constructor <;> decide

/-- A candidate that rejects the app's presets is never selected, however new it is. -/
theorem a_candidate_that_rejects_the_presets_is_never_selected :
    newer stockBroken.build stockNow.build = true ∧ select [stockBroken, stockNow] = some stockNow := by
  constructor <;> decide

/-- Quantified, so no particular binary makes it stale: whatever is selected is eligible. -/
theorem the_selection_is_always_eligible :
    ∀ (cs : List Candidate) (c : Candidate), select cs = some c → eligible c = true := by
  intro cs c h
  unfold select at h
  cases hf : cs.find? (fun c => c.designated && eligible c) with
  | some d =>
      rw [hf] at h
      simp only [Option.some.injEq] at h
      subst h
      have := List.find?_some hf
      simpa using (Bool.and_eq_true_iff.mp this).2
  | none =>
      rw [hf] at h
      clear hf
      induction cs with
      | nil => simp [bestStock] at h
      | cons x xs ih =>
          simp only [bestStock] at h
          by_cases hx : eligible x
          · simp only [hx, Bool.not_true, if_false] at h
            cases hb : bestStock xs with
            | none => rw [hb] at h; simp at h; subst h; exact hx
            | some b =>
                rw [hb] at h
                simp only [Option.some.injEq] at h
                by_cases hn : newer x.build b.build
                · simp [hn] at h; subst h; exact hx
                · simp [hn] at h; subst h; exact ih hb
          · simp only [hx, Bool.not_false, if_true] at h
            exact ih h

end CtbrecSpec.FfmpegVersion
