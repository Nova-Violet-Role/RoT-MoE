/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CP77 -- the throughput floor is a three-valued verdict, and contention is MEASURED.

WHAT WENT WRONG
---------------
`tools/PreviewCheck.java` phase 4 asserted `achieved >= 60.0` and nothing else. One full-suite
run in six went red on it; four standalone re-runs of the same checker against the same ffmpeg
binary all agreed. The red was real and the green was real -- which is the signature of a spec
that has frozen a *contingent fact* (what this machine happened to deliver at that instant) as
if it were an invariant of the pipeline.

THE MEASUREMENT THAT SETTLED IT
-------------------------------
`tools/preview-flake-hunt.sh`, 24 instrumented runs of the real checker on the real binary
`C:\Hybrid\64bit\ffmpeg.exe`:

  quiet, 12 runs         fps 70.6 - 71.8   0 failures   sysMean 0.372 - 0.690
  3 rival encodes, 12    fps 24.0 - 71.6   8 failures   sysMean 0.597 - 1.000
     of those, the 8 slow runs                          sysMean 0.818 - 1.000

The pipeline was never at fault. Every slow run happened on a machine whose mean CPU load was at
least 0.818; every quiet run sat at or below 0.690. The two bands do not overlap, and the gap is
0.128 wide.

Two signals were measured and REJECTED, which is worth as much as the one that was kept:
  * `sysMax` reaches 1.000 during quiet runs too -- a momentary spike says nothing;
  * `procMean` never exceeds 0.062, because the decoding is done by a CHILD process and the JVM
    itself is idle. A checker that watched its own process load would see nothing at all.

WHAT THIS FILE DOES NOT DO
--------------------------
It does not lower the floor. Lowering 60 to 28 would make the suite green and would delete the
only coverage that matters: a genuine regression in the decode path, on an idle machine, would
then pass. `a_slow_run_on_an_idle_machine_always_fails` is the theorem that pins that shut, and
`the_threshold_can_be_disabled_but_not_inverted` is the anti-disarm pair.

Units: fps in TENTHS (715 = 71.5 fps) and CPU load in integer PERCENT (69 = 0.690), so every
statement here is decidable and every measured run can be replayed by `#guard`.
-/

namespace CtbrecSpec.ThroughputVerdict

/-- One instrumented run of the preview throughput phase. -/
structure Sample where
  /-- Decode+scale ceiling in tenths of a frame per second. -/
  fpsTenths : Nat
  /-- Mean machine-wide CPU load across the decode window, in percent. -/
  loadPct : Nat
  /-- Did frames actually arrive? A run that produced nothing is broken however loaded the box. -/
  framesFlowed : Bool
  deriving DecidableEq, Repr

/-- The three outcomes. `degraded` is NOT a pass: it is reported, and it is never silent. -/
inductive Verdict
  | pass
  | degraded
  | fail
  deriving DecidableEq, Repr

/--
The verdict, parameterised on both constants so that no theorem below depends on the particular
numbers this machine produced today.

Order matters and is deliberate: a run with no frames is a failure *before* anything else is
consulted, so contention can never excuse a dead pipeline.
-/
def verdict (floorTenths contendedPct : Nat) (s : Sample) : Verdict :=
  if !s.framesFlowed then Verdict.fail
  else if s.fpsTenths ≥ floorTenths then Verdict.pass
  else if s.loadPct ≥ contendedPct then Verdict.degraded
  else Verdict.fail

/-- The floor the checker uses: 60.0 fps. Unchanged from the original assertion. -/
def floor60 : Nat := 600

/--
The contention threshold, 75 %. Chosen from the measurement above: it sits 6 points above the
highest quiet run (69) and 6 points below the slowest contended run (81).

This constant is CONTINGENT -- it describes this machine. Nothing load-bearing may rest on the
value 75; `a_threshold_anywhere_in_the_gap_separates_the_measured_bands` is the durable form,
quantified over every admissible threshold.
-/
def contended75 : Nat := 75

/-! ## The four branches, each pinned -/

/-- A run that clears the floor passes, no matter what the machine was doing. -/
theorem a_fast_run_always_passes (floorTenths contendedPct : Nat) (s : Sample)
    (hflow : s.framesFlowed = true) (hfast : s.fpsTenths ≥ floorTenths) :
    verdict floorTenths contendedPct s = Verdict.pass := by
  simp [verdict, hflow, hfast]

/--
**The anti-weakening theorem.** A slow run on an idle machine is still a hard failure. This is
the coverage that lowering the floor would have destroyed, and it is why the three-valued verdict
is a repair rather than a loosening.
-/
theorem a_slow_run_on_an_idle_machine_always_fails (floorTenths contendedPct : Nat) (s : Sample)
    (hflow : s.framesFlowed = true) (hslow : s.fpsTenths < floorTenths)
    (hidle : s.loadPct < contendedPct) :
    verdict floorTenths contendedPct s = Verdict.fail := by
  simp [verdict, hflow, Nat.not_le.mpr hslow, Nat.not_le.mpr hidle]

/--
`degraded` cannot become a catch-all: reaching it requires frames to have flowed, the floor to
have been missed, AND measured contention. Without the load evidence the verdict is `fail`.
-/
theorem degraded_requires_evidence_of_contention (floorTenths contendedPct : Nat) (s : Sample)
    (h : verdict floorTenths contendedPct s = Verdict.degraded) :
    s.framesFlowed = true ∧ s.fpsTenths < floorTenths ∧ s.loadPct ≥ contendedPct := by
  unfold verdict at h
  by_cases hflow : s.framesFlowed = true
  · by_cases hfast : s.fpsTenths ≥ floorTenths
    · simp [hflow, hfast] at h
    · by_cases hload : s.loadPct ≥ contendedPct
      · exact ⟨hflow, Nat.not_le.mp hfast, hload⟩
      · simp [hflow, hfast, hload] at h
  · simp [hflow] at h

/-- No frames is a failure whatever the load and whatever the number attached to it. -/
theorem no_flow_is_always_a_failure (floorTenths contendedPct : Nat) (s : Sample)
    (hdead : s.framesFlowed = false) :
    verdict floorTenths contendedPct s = Verdict.fail := by
  simp [verdict, hdead]

/-- Passing is exactly "frames flowed and the floor was cleared" -- nothing else can produce it. -/
theorem passing_is_exactly_clearing_the_floor (floorTenths contendedPct : Nat) (s : Sample) :
    verdict floorTenths contendedPct s = Verdict.pass ↔
      (s.framesFlowed = true ∧ s.fpsTenths ≥ floorTenths) := by
  constructor
  · intro h
    unfold verdict at h
    by_cases hflow : s.framesFlowed = true
    · by_cases hfast : s.fpsTenths ≥ floorTenths
      · exact ⟨hflow, hfast⟩
      · by_cases hload : s.loadPct ≥ contendedPct <;> simp [hflow, hfast, hload] at h
    · simp [hflow] at h
  · intro ⟨hflow, hfast⟩
    exact a_fast_run_always_passes floorTenths contendedPct s hflow hfast

/-- A degraded run is never reported as a pass, so it can never go silently green. -/
theorem degraded_is_never_a_pass (floorTenths contendedPct : Nat) (s : Sample)
    (h : verdict floorTenths contendedPct s = Verdict.degraded) :
    verdict floorTenths contendedPct s ≠ Verdict.pass := by
  rw [h]; intro hc; cases hc

/-! ## Durable statements — quantified over the constants, not over today's values -/

/--
Monotonicity in the floor: if a run clears a stricter floor it clears every looser one. So a
future decision to RAISE the floor can never turn a failure into a pass, and the verdict cannot
be gamed by moving the constant in the safe-looking direction.
-/
theorem raising_the_floor_never_turns_a_fail_into_a_pass
    (loose strict contendedPct : Nat) (s : Sample) (hle : loose ≤ strict)
    (h : verdict strict contendedPct s = Verdict.pass) :
    verdict loose contendedPct s = Verdict.pass := by
  rw [passing_is_exactly_clearing_the_floor] at h ⊢
  exact ⟨h.1, Nat.le_trans hle h.2⟩

/--
**Anti-disarm.** A threshold above 100 % is unreachable (load is a percentage), so setting one
recovers the original two-valued check exactly: every run is `pass` or `fail`, never `degraded`.
The new behaviour is therefore a strict refinement of the old, and it can be switched off without
changing any other branch.
-/
theorem the_threshold_can_be_disabled (floorTenths contendedPct : Nat) (s : Sample)
    (hover : contendedPct > 100) (hload : s.loadPct ≤ 100) :
    verdict floorTenths contendedPct s ≠ Verdict.degraded := by
  intro h
  have := (degraded_requires_evidence_of_contention floorTenths contendedPct s h).2.2
  omega

/--
The other direction, stated so the danger is on the record: a threshold of 0 would excuse every
slow run that produced frames. The constant is load-bearing; this theorem is the reason it may
never be "relaxed" to make a suite green.
-/
theorem a_zero_threshold_would_excuse_every_slow_run (floorTenths : Nat) (s : Sample)
    (hflow : s.framesFlowed = true) (hslow : s.fpsTenths < floorTenths) :
    verdict floorTenths 0 s = Verdict.degraded := by
  simp [verdict, hflow, Nat.not_le.mpr hslow]

/-! ## The measured corpus — every run of the hunt, replayed -/

/-- The 12 quiet runs: fps in tenths, load in percent, frames flowed. -/
def quietRuns : List Sample :=
  [ ⟨711, 42, true⟩, ⟨706, 69, true⟩, ⟨713, 67, true⟩, ⟨716, 37, true⟩
  , ⟨713, 50, true⟩, ⟨717, 37, true⟩, ⟨717, 37, true⟩, ⟨710, 63, true⟩
  , ⟨713, 64, true⟩, ⟨718, 38, true⟩, ⟨714, 39, true⟩, ⟨711, 40, true⟩ ]

/-- The 12 runs taken against three rival ffmpeg encodes. -/
def loadedRuns : List Sample :=
  [ ⟨249, 91, true⟩, ⟨714, 92, true⟩, ⟨716, 59, true⟩, ⟨716, 59, true⟩
  , ⟨240, 93, true⟩, ⟨257, 100, true⟩, ⟨309, 81, true⟩, ⟨256, 100, true⟩
  , ⟨256, 100, true⟩, ⟨249, 100, true⟩, ⟨288, 100, true⟩, ⟨619, 84, true⟩ ]

/-- Every quiet run passes at the deployed constants. -/
theorem every_quiet_run_passes :
    quietRuns.all (fun s => verdict floor60 contended75 s == Verdict.pass) = true := by
  decide

/-- No quiet run is excused as degraded — the quiet band never touches the contention branch. -/
theorem no_quiet_run_is_degraded :
    quietRuns.all (fun s => verdict floor60 contended75 s != Verdict.degraded) = true := by
  decide

/-- Under load, nothing FAILS: every run either clears the floor or is attributed to contention. -/
theorem no_loaded_run_fails :
    loadedRuns.all (fun s => verdict floor60 contended75 s != Verdict.fail) = true := by
  decide

/--
**The durable separation.** For EVERY admissible threshold in the measured gap -- not merely for
75 -- the quiet band passes and the slow contended band is attributed. A future recalibration
inside the gap changes nothing, which is exactly what makes the constant safe to move.
-/
theorem a_threshold_anywhere_in_the_gap_separates_the_measured_bands
    (t : Nat) (hlo : 70 ≤ t) (hhi : t ≤ 81) :
    quietRuns.all (fun s => verdict floor60 t s == Verdict.pass) = true ∧
    (∀ s ∈ loadedRuns, verdict floor60 t s ≠ Verdict.fail) := by
  refine ⟨?_, ?_⟩
  · simp [quietRuns, verdict, floor60]
  · intro s hs
    simp only [loadedRuns, List.mem_cons, List.not_mem_nil, or_false] at hs
    rcases hs with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
      simp [verdict, floor60] <;> omega

/-- The deployed threshold is inside that gap, so it inherits the statement above. -/
theorem the_deployed_threshold_is_admissible : 70 ≤ contended75 ∧ contended75 ≤ 81 := by
  decide

/-! ## Guards — the shape of the corpus, pinned -/

#guard quietRuns.length == 12
#guard loadedRuns.length == 12
#guard quietRuns.all (fun s => s.fpsTenths ≥ 600)
#guard (loadedRuns.filter (fun s => s.fpsTenths < 600)).length == 8
#guard (loadedRuns.filter (fun s => verdict floor60 contended75 s == Verdict.degraded)).length == 8
#guard (loadedRuns.filter (fun s => verdict floor60 contended75 s == Verdict.pass)).length == 4
#guard quietRuns.all (fun s => s.loadPct ≤ 69)
#guard (loadedRuns.filter (fun s => s.fpsTenths < 600)).all (fun s => s.loadPct ≥ 81)
#guard verdict floor60 contended75 ⟨715, 39, true⟩ == Verdict.pass
#guard verdict floor60 contended75 ⟨249, 91, true⟩ == Verdict.degraded
#guard verdict floor60 contended75 ⟨249, 39, true⟩ == Verdict.fail
#guard verdict floor60 contended75 ⟨715, 39, false⟩ == Verdict.fail
#guard verdict floor60 101 ⟨249, 100, true⟩ == Verdict.fail

end CtbrecSpec.ThroughputVerdict
