/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — choosing the most advanced ffmpeg available

Subject: `src/common/ctbrec/OS.java:139-165`, which builds the ffmpeg command line.
The binary is **hard-coded** to `<jarDir>/ffmpeg/ffmpeg.exe`; there is no setting, no
environment override, no search. On this machine that pins ctbrec to the bundled
**7.1.3-Jellyfin** while **8.0.1-full** sits in
`C:\Users\<you>\AppData\Local\UniGetUI\Chocolatey\bin\ffmpeg.exe`.

Measured with `tools/ffmpeg-ab.sh` over the eight command shapes ctbrec actually emits
(TS preset, MP4 preset, HLS playlist, remux, concat with `-xerror`, contact-sheet frame
extraction, `ffmetadata` probe, live AMF args): **no regression** — 8.0.1 succeeds
everywhere 7.1.3 does, byte-identical output on six of the eight.

Replacing the bundled binary would work once and rot immediately: it discards the
Jellyfin build, and it encodes a fact about today's filesystem rather than a policy.
What is modelled here instead is a **resolver** — enumerate candidates, ask each for its
version, take the newest, fall back to the bundled binary when nothing else answers.

The properties that make it safe to put in front of a recorder:

* it never invents a path (`resolve_is_a_candidate`);
* it never picks something older than a candidate it saw (`resolve_never_downgrades`);
* a candidate that will not report a version is ignored rather than run
  (`unusable_candidates_are_ignored`);
* with no usable candidate at all it returns the bundled binary, so behaviour is
  exactly today's (`resolve_falls_back_to_bundled`).

That last one is the anti-amputation clause: the worst case of this feature is the
status quo.
-/

namespace CtbrecSpec

/-! ## Versions -/

/-- An ffmpeg version as reported by `ffmpeg -version`, e.g. `7.1.3` or `8.0.1`. -/
structure Version where
  major : Nat
  minor : Nat
  patch : Nat
  deriving DecidableEq, Repr, Inhabited

/-- Lexicographic "not newer than". -/
def verLe (a b : Version) : Bool :=
  a.major < b.major ||
    (a.major == b.major &&
      (a.minor < b.minor || (a.minor == b.minor && a.patch ≤ b.patch)))

theorem verLe_refl (a : Version) : verLe a a = true := by
  simp [verLe]

/-- Totality — needed for "the pick is maximal", and false for a comparison that
forgets a component. -/
theorem verLe_total (a b : Version) : verLe a b = true ∨ verLe b a = true := by
  simp [verLe]
  omega

theorem verLe_trans {a b c : Version} (h₁ : verLe a b = true) (h₂ : verLe b c = true) :
    verLe a c = true := by
  simp [verLe] at h₁ h₂ ⊢
  omega

theorem verLe_antisymm {a b : Version} (h₁ : verLe a b = true) (h₂ : verLe b a = true) :
    a = b := by
  have hc : a.major = b.major ∧ a.minor = b.minor ∧ a.patch = b.patch := by
    simp [verLe] at h₁ h₂
    omega
  obtain ⟨hM, hm, hp⟩ := hc
  cases a; cases b; simp_all

/-- The two versions on this machine, as measured by `ffmpeg -version`. -/
def v7 : Version := ⟨7, 1, 3⟩
def v8 : Version := ⟨8, 0, 1⟩

#guard verLe v7 v8 == true
#guard verLe v8 v7 == false
#guard verLe v7 v7 == true
-- the component that a naive "compare major only" would get wrong
#guard verLe ⟨7, 1, 3⟩ ⟨7, 1, 4⟩ == true
#guard verLe ⟨7, 2, 0⟩ ⟨7, 1, 9⟩ == false

/-! ## Candidates -/

/-- A place ffmpeg might live, together with the version it reported. `none` means it
did not answer `-version` — missing, not executable, or not ffmpeg at all. -/
structure Candidate where
  path : String
  version : Option Version
  deriving DecidableEq, Repr, Inhabited

/-- A candidate is usable exactly when it reported a version. -/
def usable (c : Candidate) : Bool := c.version.isSome

/-- The reported version, or `0.0.0` for an unusable candidate. Only ever applied to
usable candidates in the statements below. -/
def ver (c : Candidate) : Version := c.version.getD ⟨0, 0, 0⟩

/-- Scan for the newest, carrying the best seen so far. On a tie the **earlier**
candidate is kept, so the caller controls precedence by ordering the list. -/
def bestOf (acc : Candidate) : List Candidate → Candidate
  | [] => acc
  | c :: rest => bestOf (if verLe (ver c) (ver acc) then acc else c) rest

/-- Pick the newest of a list. -/
def pickBest : List Candidate → Option Candidate
  | [] => none
  | c :: rest => some (bestOf c rest)

/-- The resolver: consider only candidates that answered, take the newest, and fall
back to the bundled binary. -/
def resolve (candidates : List Candidate) (bundled : Candidate) : Candidate :=
  (pickBest (candidates.filter usable)).getD bundled

/-! ## The properties -/

theorem pickBest_none_iff (l : List Candidate) : pickBest l = none ↔ l = [] := by
  cases l <;> simp [pickBest]

/-- The scan returns the accumulator or one of the candidates — never anything else. -/
theorem bestOf_mem : ∀ (l : List Candidate) (acc : Candidate),
    bestOf acc l = acc ∨ bestOf acc l ∈ l
  | [], acc => by simp [bestOf]
  | c :: rest, acc => by
    simp only [bestOf]
    by_cases h : verLe (ver c) (ver acc) = true
    · rw [if_pos h]
      rcases bestOf_mem rest acc with h1 | h1
      · exact Or.inl h1
      · exact Or.inr (List.mem_cons_of_mem _ h1)
    · rw [if_neg h]
      rcases bestOf_mem rest c with h1 | h1
      · rw [h1]; exact Or.inr List.mem_cons_self
      · exact Or.inr (List.mem_cons_of_mem _ h1)

/-- The scan never returns something older than what it started with. -/
theorem bestOf_ge_acc : ∀ (l : List Candidate) (acc : Candidate),
    verLe (ver acc) (ver (bestOf acc l)) = true
  | [], acc => by simpa [bestOf] using verLe_refl (ver acc)
  | c :: rest, acc => by
    simp only [bestOf]
    by_cases h : verLe (ver c) (ver acc) = true
    · rw [if_pos h]; exact bestOf_ge_acc rest acc
    · rw [if_neg h]
      have hca : verLe (ver acc) (ver c) = true := by
        rcases verLe_total (ver acc) (ver c) with ht | ht
        · exact ht
        · exact absurd ht h
      exact verLe_trans hca (bestOf_ge_acc rest c)

/-- **Nothing scanned is newer than the result.** -/
theorem bestOf_maximal : ∀ (l : List Candidate) (acc d : Candidate), d ∈ l →
    verLe (ver d) (ver (bestOf acc l)) = true
  | [], _, d, hd => by simp at hd
  | c :: rest, acc, d, hd => by
    simp only [bestOf]
    rcases List.mem_cons.mp hd with heq | hdr
    · subst heq
      by_cases h : verLe (ver d) (ver acc) = true
      · rw [if_pos h]; exact verLe_trans h (bestOf_ge_acc rest acc)
      · rw [if_neg h]; exact bestOf_ge_acc rest d
    · by_cases h : verLe (ver c) (ver acc) = true
      · rw [if_pos h]; exact bestOf_maximal rest acc d hdr
      · rw [if_neg h]; exact bestOf_maximal rest c d hdr

/-- **The pick is always one of the candidates offered** — never a fabricated path. -/
theorem pickBest_mem : ∀ (l : List Candidate) (c : Candidate), pickBest l = some c → c ∈ l
  | [], c, h => by simp [pickBest] at h
  | d :: rest, c, h => by
    simp only [pickBest, Option.some.injEq] at h
    subst h
    rcases bestOf_mem rest d with h1 | h1
    · rw [h1]; exact List.mem_cons_self
    · exact List.mem_cons_of_mem _ h1

/-- **Nothing offered is newer than the pick.** This is the theorem that makes the
resolver an upgrade rather than a lottery. -/
theorem pickBest_maximal : ∀ (l : List Candidate) (c d : Candidate),
    pickBest l = some c → d ∈ l → verLe (ver d) (ver c) = true
  | [], c, d, h, _ => by simp [pickBest] at h
  | e :: rest, c, d, h, hd => by
    simp only [pickBest, Option.some.injEq] at h
    subst h
    rcases List.mem_cons.mp hd with heq | hdr
    · subst heq; exact bestOf_ge_acc rest d
    · exact bestOf_maximal rest e d hdr

/-- The resolver returns the bundled binary or one of the candidates — nothing else. -/
theorem resolve_is_a_candidate (cands : List Candidate) (bundled : Candidate) :
    resolve cands bundled = bundled ∨ resolve cands bundled ∈ cands := by
  unfold resolve
  cases hp : pickBest (cands.filter usable) with
  | none => left; simp
  | some c =>
    right
    have hmem : c ∈ cands.filter usable := pickBest_mem _ c hp
    have h2 : c ∈ cands := (List.mem_filter.mp hmem).1
    simpa using h2

/-- **No downgrade.** Every usable candidate is at most as new as the one chosen. -/
theorem resolve_never_downgrades (cands : List Candidate) (bundled d : Candidate)
    (hd : d ∈ cands) (hu : usable d = true) :
    verLe (ver d) (ver (resolve cands bundled)) = true := by
  unfold resolve
  have hdf : d ∈ cands.filter usable := List.mem_filter.mpr ⟨hd, hu⟩
  cases hp : pickBest (cands.filter usable) with
  | none =>
    have hnil : cands.filter usable = [] := (pickBest_none_iff _).mp hp
    rw [hnil] at hdf
    simp at hdf
  | some c =>
    simpa using pickBest_maximal _ c d hp hdf

/-- **The worst case is today's behaviour.** If nothing answers `-version`, the bundled
binary is used, exactly as the shipped code does unconditionally. -/
theorem resolve_falls_back_to_bundled (cands : List Candidate) (bundled : Candidate)
    (h : ∀ c ∈ cands, usable c = false) : resolve cands bundled = bundled := by
  have hnil : cands.filter usable = [] := by
    rw [List.filter_eq_nil_iff]
    intro a ha
    rw [h a ha]
    exact Bool.false_ne_true
  simp [resolve, hnil, pickBest]

/-- A candidate that will not report a version cannot change the outcome — the resolver
never runs a binary it could not identify. -/
theorem unusable_candidates_are_ignored (cands : List Candidate) (bundled c : Candidate)
    (hu : usable c = false) :
    resolve (cands ++ [c]) bundled = resolve cands bundled := by
  simp [resolve, List.filter_append, hu]

/-! ## The concrete situation on this machine

`#guard`s, not theorems: they record today's two binaries. The theorems above are what
must keep holding when these change. -/

def bundled : Candidate := ⟨"lib/ffmpeg/ffmpeg.exe", some v7⟩
def system : Candidate := ⟨"AppData/Local/UniGetUI/Chocolatey/bin/ffmpeg.exe", some v8⟩
def missing : Candidate := ⟨"nowhere/ffmpeg.exe", none⟩

#guard (resolve [bundled, system] bundled).path == system.path      -- picks 8.0.1
#guard (resolve [bundled, missing] bundled).path == bundled.path     -- ignores the dud
#guard (resolve [missing] bundled).path == bundled.path              -- falls back
#guard (resolve [] bundled).path == bundled.path                     -- today's behaviour
#guard (resolve [system, bundled] bundled).path == system.path       -- order-independent

/-- Stated over the versions rather than over the paths, so it survives either binary
being upgraded: the selection is at least as new as **both** candidates. Written first
with a `verLe (ver a) (ver b)` hypothesis, which the proof never used — removed, since a
hypothesis a proof does not need is an over-assumption. -/
theorem newer_of_the_two_is_chosen (a b : Candidate)
    (ha : usable a = true) (hb : usable b = true) :
    verLe (ver a) (ver (resolve [a, b] a)) = true ∧
      verLe (ver b) (ver (resolve [a, b] a)) = true :=
  ⟨resolve_never_downgrades [a, b] a a List.mem_cons_self ha,
   resolve_never_downgrades [a, b] a b (List.mem_cons_of_mem _ List.mem_cons_self) hb⟩

/-! ## The comparator was blind to the best binary on the machine

**This section exists because the section above was wrong about the world, not about logic.**

Everything proved so far is sound, and `unusable_candidates_are_ignored` is the theorem that
silently threw away the newest ffmpeg on this machine. The defect is not in the theorem — it is
in what `usable` MEANS. `FfmpegResolver` decides usability with

```java
Pattern.compile("ffmpeg version n?(\\d+)\\.(\\d+)(?:\\.(\\d+))?")
```

A git-master snapshot reports `ffmpeg version N-123549-g70537ec8e6`. There is no
`major.minor.patch` in that string, the regex does not match, the candidate reports no version,
and `usable` is false. The binary runs perfectly; the parser cannot describe it, so the resolver
pretends it is not there.

**Measured on this machine** — all four ffmpeg builds present, `ffmpeg -version`:

| build | ffmpeg version string | libavcodec | semver parses? |
|---|---|---|---|
| `C:/Hybrid/64bit` | `N-123549-g70537ec8e6` | **62.29.101** | **no** |
| `C:/Hybrid/32bit` | `N-123477-g5640bd3a4f` | 62.29.100 | **no** |
| Chocolatey | `8.0.1-full_build-www.gyan.dev` | 62.11.100 | yes — **selected today** |
| bundled | `7.1.3-Jellyfin` | 61.19.101 | yes |

Capability was checked before preferring it, not after: the Hybrid 64-bit build has `https`,
`tls`, the `hls` demuxer, the `mp4` muxer, `aac`/`h264`/`hevc`/`vp9`, the `aac_adtstoasc`
bitstream filter, and 59 `--enable` flags.

**The durable comparator is the library version, not the release string.** `libavcodec` is
reported by every build, release and master alike, and it increases monotonically across both.
The existing `verLe` needs no change — only the numbers fed to it do. That is the whole repair:
same proved lexicographic ordering, a source of numbers that exists for every build. -/

/-- What the SEMVER parser sees when handed a git-master build: nothing. -/
def masterBuildAsSemverSeesIt : Candidate := ⟨"C:/Hybrid/64bit/ffmpeg.exe", none⟩

/-- **The parser cannot see a master build at all.** -/
theorem a_master_build_is_invisible_to_the_semver_parser :
    usable masterBuildAsSemverSeesIt = false := by decide

/-- The four builds keyed by **libavcodec**, exactly as measured. -/
def hybrid64 : Candidate := ⟨"C:/Hybrid/64bit/ffmpeg.exe", some ⟨62, 29, 101⟩⟩
def hybrid32 : Candidate := ⟨"C:/Hybrid/32bit/ffmpeg.exe", some ⟨62, 29, 100⟩⟩
def chocolatey : Candidate := ⟨"AppData/Local/UniGetUI/Chocolatey/bin/ffmpeg.exe", some ⟨62, 11, 100⟩⟩
def bundledLib : Candidate := ⟨"lib/ffmpeg/ffmpeg.exe", some ⟨61, 19, 101⟩⟩

/-- The four builds **the resolver's search set offers**, keyed by libavcodec.

CP79 correction: this list was documented as "every build on the machine". It is not, and never
was — a machine-wide sweep for `ffmpeg.exe` (CP79, 2026-08-06) found **22**. The four here are
the ones the resolver can currently reach. The full census is `censusAll` below, and the two
lists exist precisely so that the difference between *what is installed* and *what is offered*
stays visible instead of being asserted away in a doc comment. -/
def measuredMachine : List Candidate := [bundledLib, chocolatey, hybrid32, hybrid64]

/-- **Under the library comparator every offered build is usable** — 4 of 4, where the semver
parser could describe only 2. -/
theorem every_build_reports_a_libavcodec_version :
    (measuredMachine.filter usable).length = 4 := by decide

/-- **The machine's best binary is the 64-bit master build.** -/
theorem the_machine_best_is_the_master_build :
    pickBest measuredMachine = some hybrid64 := by decide

/-- **And it is strictly newer than the one in use today.** -/
theorem the_master_build_beats_the_selected_one :
    verLe (ver chocolatey) (ver hybrid64) = true ∧ ver chocolatey ≠ ver hybrid64 := by decide

/-- **Anti-amputation, three ways.** The rule is not "always prefer Hybrid": remove it and the
resolver falls back correctly, all the way down to today's behaviour. A rule that hard-coded the
winner would satisfy the theorem above and break the moment the filesystem changed. -/
theorem without_the_master_builds_it_picks_chocolatey :
    pickBest [bundledLib, chocolatey] = some chocolatey := by decide

theorem with_only_the_bundled_build_it_picks_bundled :
    pickBest [bundledLib] = some bundledLib := by decide

theorem with_nothing_offered_it_falls_back :
    (resolve [] bundledLib).path = bundledLib.path := by decide

/-- 64-bit beats 32-bit on the same day's master: 62.29.101 over 62.29.100. The patch field is
load-bearing here, so a comparator that stopped at minor would tie. -/
theorem the_64bit_master_beats_the_32bit_master :
    pickBest [hybrid32, hybrid64] = some hybrid64 := by decide

/-- **The rule is about the ordering, not about today's paths.** Any candidate that is at least
as new as every other is a valid selection — so a future build newer than Hybrid wins without
this file being touched. This is the durable form; the concrete theorems above are the
measurement. -/
-- No `usable d` hypothesis: `pickBest_maximal` does not need one, and this file's own rule is
-- that a hypothesis a proof does not use is an over-assumption. Dropping it makes the statement
-- strictly stronger — it holds for every candidate offered, usable or not.
theorem the_selection_is_never_older_than_any_candidate
    (l : List Candidate) (c d : Candidate) (h : pickBest l = some c) (hd : d ∈ l) :
    verLe (ver d) (ver c) = true :=
  pickBest_maximal l c d h hd

/-! ### CP79 — is the candidate SET complete? (the question the ordering theorems cannot answer)

Every theorem above is relative to the candidates offered. None of them says anything about a
binary the resolver never saw, and that is not a gap in the proofs — it is the actual shape of
the guarantee. A machine-wide sweep is the only way to answer it, and a sweep is a measurement,
so the two are kept apart here: the *general* theorems below are load-bearing, the census is
`#guard`-pinned evidence about today.

Measured 2026-08-06, `find /c /d -iname ffmpeg.exe`: **22 binaries**, 21 of which answer
`-version`. The newest on the whole machine is `C:/Hybrid/64bit` at libavcodec 62.29.101 — which
is already in the search set and is already what the resolver picks. -/

/-- The distinct libavcodec versions found machine-wide, one representative path each. Backup
copies of older ctbrec deployments collapse into their version; the MSI Center binary is the one
that answered nothing. -/
def censusEssentials : Candidate := ⟨"C:/FFmpeg/ffmpeg-8.0.1-essentials_build/bin/ffmpeg.exe", some ⟨62, 11, 100⟩⟩
def censusGitEssentials : Candidate := ⟨"ctbrec2/lib/ffmpeg/ffmpeg.exe", some ⟨61, 33, 102⟩⟩
def censusJellyfin711 : Candidate := ⟨"Backup Old Ctbrec/ctbrec/lib/ffmpeg/ffmpeg.exe", some ⟨61, 19, 101⟩⟩
def censusJellyfin702 : Candidate := ⟨"Mono/ctbrec/lib/ffmpeg/ffmpeg.exe", some ⟨61, 3, 100⟩⟩
def censusStremio : Candidate := ⟨"Programs/LNV/Stremio-4/ffmpeg.exe", some ⟨58, 134, 100⟩⟩
def censusOld421 : Candidate := ⟨"Desktop/ctbrec2/lib/ffmpeg/ffmpeg.exe", some ⟨58, 54, 100⟩⟩
def censusMp4Tools : Candidate := ⟨"MP4Tools/bin/ffmpeg.exe", some ⟨58, 35, 100⟩⟩
def censusLavFilters : Candidate := ⟨"KMPplayer/LAVFilters64/ffmpeg.exe", some ⟨58, 18, 100⟩⟩
def censusMoo0 : Candidate := ⟨"Moo0 VideoCutter/optional_tools/ffmpeg.exe", some ⟨58, 9, 100⟩⟩
/-- MSI Center's bundled binary: present on disk, answers nothing. -/
def censusMsiCenter : Candidate := ⟨"WindowsApps/MSICenter/DCv2/Coreliquid/ffmpeg.exe", none⟩

/-- Every ffmpeg on this machine, by distinct version. -/
def censusAll : List Candidate :=
  [hybrid64, hybrid32, censusEssentials, chocolatey, censusGitEssentials, censusJellyfin711,
   bundledLib, censusJellyfin702, censusStremio, censusOld421, censusMp4Tools,
   censusLavFilters, censusMoo0, censusMsiCenter]

/-- **The four the resolver offers are a subset of what exists.** Trivial to state, and the
reason it is stated: this is the fact the old doc comment denied. -/
theorem the_offered_set_is_part_of_the_census :
    measuredMachine.all (fun c => censusAll.contains c) = true := by decide

/-- **The census contains binaries the resolver cannot reach.** The honest converse — proving
the search set is a proper subset means the completeness question is real, not rhetorical. -/
theorem the_census_is_strictly_larger_than_the_offered_set :
    (censusAll.filter (fun c => !measuredMachine.contains c)).length = 10 := by decide

/-- **Nothing on this machine beats what the resolver picks.** Decidable over the census, so it
is checked rather than believed. This is a fact about TODAY's filesystem — it is a `theorem` only
because the census is a fixed list; it makes no claim about tomorrow, which is why the durable
statements are the two below it. -/
theorem the_selection_is_maximal_over_the_whole_machine :
    censusAll.all (fun d => verLe (ver d) (ver hybrid64)) = true := by decide

/-- **The build outside the search set does not change the answer today** — 62.11.100 ties
Chocolatey and loses to Hybrid. Recorded so that the gap is documented as *latent* rather than
harmless: update that install and not Hybrid, and it would be missed. -/
theorem the_essentials_build_would_not_change_the_answer :
    pickBest (censusEssentials :: measuredMachine) = some hybrid64 := by decide

/-- **Widening the search can never make the answer worse.** For any extra binaries discovered,
the pick over the larger set is at least as new as the pick over the smaller one.

This is the theorem that licenses adding directories to `searchDirs()` at all: without it, every
new probe would need its own argument that it cannot cause a downgrade. With it, discovery is
monotone by construction — which is exactly why the fix for CP79 is *more search*, never a
hard-coded path. -/
theorem widening_the_search_never_downgrades
    (small extra : List Candidate) (c c' : Candidate)
    (h : pickBest small = some c) (h' : pickBest (small ++ extra) = some c') :
    verLe (ver c) (ver c') = true :=
  pickBest_maximal (small ++ extra) c' c h'
    (List.mem_append_left extra (pickBest_mem small c h))

/-- **And the honest limit of every theorem in this file.** A binary that is not offered can be
strictly newer than the answer, so "the resolver picks the most advanced ffmpeg" is true only
relative to the search set. Stated as an existence proof rather than left as a caveat in prose,
because a caveat cannot be mutation-tested. -/
theorem a_binary_outside_the_set_can_beat_the_answer :
    ∃ (outside : Candidate) (offered : List Candidate) (chosen : Candidate),
      pickBest offered = some chosen ∧ verLe (ver outside) (ver chosen) = false := by
  refine ⟨hybrid64, [bundledLib, chocolatey], chocolatey, by decide, by decide⟩

#guard usable masterBuildAsSemverSeesIt == false
#guard censusAll.length == 14
#guard (censusAll.filter usable).length == 13
#guard (censusAll.filter (fun c => !usable c)).length == 1
#guard (resolve censusAll bundledLib).path == hybrid64.path
#guard censusAll.all (fun d => verLe (ver d) (ver hybrid64)) == true
#guard (pickBest (censusEssentials :: measuredMachine)).isSome == true
#guard verLe (ver censusEssentials) (ver chocolatey) == true
#guard verLe (ver chocolatey) (ver censusEssentials) == true
#guard (measuredMachine.filter usable).length == 4
#guard (resolve measuredMachine bundledLib).path == hybrid64.path
#guard (resolve [bundledLib, chocolatey] bundledLib).path == chocolatey.path
#guard (resolve [bundledLib] bundledLib).path == bundledLib.path
#guard verLe (ver chocolatey) (ver hybrid64) == true
#guard verLe (ver hybrid64) (ver chocolatey) == false

/-! ## Binding the RUNTIME choice to the spec (spec-check phase 41)

Everything above proves what `resolve` *would* do. None of it proves what the app *did*. The
running recorder logs its choice —

```
CTBREC-REWORK: using ffmpeg with libavcodec Version[major=62, minor=29, patch=101]
                at C:\Hybrid\64bit\ffmpeg.exe (bundled has libavcodec 61.19.101)
```

— and that line is the only evidence that the powerful implementation is actually armed in the
process the Socio runs. Measured over the live log: 20 selection events, the most recent
resolving to the git-master build. Phase 41 re-derives the comparison from the machine and
requires the recorded choice to still be maximal.

**The trap this section exists to avoid.** A check reading "the log must name `C:\Hybrid`" would
be a dated spec: install a newer ffmpeg and a *correct* run goes red. Worse, the obvious repair
is to weaken the check. The durable statement quantifies over the candidate set instead, and the
checker only considers binaries that already existed when the line was written. -/

/-- The choice the log recorded: a path and the version it reported at the time. -/
structure RecordedChoice where
  path : String
  version : Version
  deriving DecidableEq, Repr

/-- A recorded choice is **sound** for a candidate set when nothing in that set is newer. Stated
over an arbitrary set, so it survives any future machine. -/
def choiceIsMaximal (r : RecordedChoice) (l : List Candidate) : Bool :=
  l.all (fun d => verLe (ver d) r.version)

/-- **What `resolve` guarantees, transported to the log line.** If the app picked what `pickBest`
picks, the recorded choice is maximal over everything offered — for every candidate list. This is
the theorem phase 41 checks against reality. -/
theorem a_resolved_choice_is_maximal (l : List Candidate) (c : Candidate)
    (h : pickBest l = some c) :
    choiceIsMaximal ⟨c.path, ver c⟩ l = true := by
  unfold choiceIsMaximal
  simp only [List.all_eq_true, decide_eq_true_eq]
  intro d hd
  exact pickBest_maximal l c d h hd

/-- **And a stale choice is always detected.** If any candidate is strictly newer than what the
log recorded, the check fires. Without this the phase could pass by never firing. -/
theorem a_superseded_choice_is_detected (r : RecordedChoice) (l : List Candidate) (d : Candidate)
    (hd : d ∈ l) (hnew : verLe (ver d) r.version = false) :
    choiceIsMaximal r l = false := by
  unfold choiceIsMaximal
  cases hall : l.all (fun x => verLe (ver x) r.version) with
  | false => rfl
  | true =>
    have hx := (List.all_eq_true.mp hall) d hd
    simp [hnew] at hx

/-- **The check is not a claim that a specific path wins.** Any candidate at least as new as the
recorded one keeps the check green, so installing a newer build and re-running is a pass the
moment the app selects it — the spec does not have to be edited. -/
theorem the_check_admits_any_newer_build (r : RecordedChoice) (l : List Candidate)
    (h : choiceIsMaximal r l = true) (e : Candidate) (he : verLe (ver e) r.version = true) :
    choiceIsMaximal r (e :: l) = true := by
  unfold choiceIsMaximal at *
  simp only [List.all_cons, Bool.and_eq_true]
  exact ⟨by simp [he], h⟩

/-- The measured state of this machine at checkpoint 42, as the log recorded it. -/
def recordedOnThisMachine : RecordedChoice := ⟨"C:/Hybrid/64bit/ffmpeg.exe", ⟨62, 29, 101⟩⟩

-- The live log's most recent selection is maximal over every binary measured on this machine.
#guard choiceIsMaximal recordedOnThisMachine measuredMachine == true
-- Had it recorded the Chocolatey build instead, the master build would supersede it.
#guard choiceIsMaximal ⟨chocolatey.path, ver chocolatey⟩ measuredMachine == false
-- And the bundled build is superseded by everything.
#guard choiceIsMaximal ⟨bundledLib.path, ver bundledLib⟩ measuredMachine == false

end CtbrecSpec
