/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — ffmpeg exit-code classification

The subject is `ctbrec` 26.7.11 (decompiled tree at `src/common/ctbrec/...`).

The codebase contained **two contradictory notions of "ffmpeg succeeded"**:

| site                                   | predicate         |
|----------------------------------------|-------------------|
| `recorder/postprocessing/Concatenate.java:338,351`      | `exitCode == 0` |
| `recorder/postprocessing/CreateContactSheet.java:74,143`| `exitCode == 0` |
| `recorder/postprocessing/Script.java:49`                | `exitCode == 0` |
| `recorder/postprocessing/Remux.java:55,59`              | `exitCode != 1` |
| `recorder/FFmpeg.java:57`                               | `exitCode != 1` |

MEASURED on this machine (2026-08-03) **through the channel the app actually reads**,
`java.lang.Process.waitFor()`, identical on both `lib/ffmpeg/ffmpeg.exe`
(7.1.3-Jellyfin) and the system `ffmpeg.exe` (8.0.1-full_build gyan.dev):

  | scenario           | exit          | hex        | meaning                      |
  |--------------------|---------------|------------|------------------------------|
  | `-version`         | 0             | 0x00000000 | success                      |
  | missing input file | -2            | 0xFFFFFFFE | `AVERROR(ENOENT)`            |
  | unwritable output  | -2            | 0xFFFFFFFE | `AVERROR(ENOENT)`            |
  | unknown option     | -1414549496   | 0xABAFB008 | `AVERROR_OPTION_NOT_FOUND`   |
  | unknown encoder    | -1129203192   | 0xBCB1BA08 | `AVERROR_ENCODER_NOT_FOUND`  |
  | no arguments       | 1             | 0x00000001 | usage error                  |

An earlier draft of this file quoted 127 and 8. Those were measured through a
**bash** shell, which remaps a Windows exit status; they are not what the JVM sees
and they were wrong for this app. The general theorems below never mentioned them,
which is why the correction cost nothing — that is the point of stating the rule
over all exit codes instead of over today's constants.

Every genuine ffmpeg error is a **negative** AVERROR. `exitCode != 1` therefore
caught exactly one thing — ffmpeg invoked with no arguments — and classified every
real failure as success. In `Remux.finalizeStep` that verdict **deletes the original
recording**.

`ExitCode` is `Int` because Java's `Process.waitFor()` returns a signed `int`, and
both AVERROR values and Windows structured-exception exits arrive negative.
-/

namespace CtbrecSpec

/-- A process exit status as observed by `java.lang.Process.waitFor()`. -/
abbrev ExitCode := Int

/-- The legacy predicate at `Remux.java:55,59` and `FFmpeg.java:57`: clean unless exactly 1. -/
def cleanLegacy (e : ExitCode) : Bool := e != 1

/-- The predicate the rest of the codebase already used, and the corrected one. -/
def cleanCorrect (e : ExitCode) : Bool := e == 0

/-! ## Measured witnesses

These pin the concrete values measured from the two real binaries. They are
deliberately `example`s and `#guard`s, not load-bearing theorems: they document
what today's ffmpeg returns, and a future ffmpeg is free to return something else
without making the general theorems below false. -/

/-- `AVERROR(ENOENT)` — missing input file, or an output path that cannot be written. -/
example : cleanLegacy (-2) = true ∧ cleanCorrect (-2) = false := by decide

/-- `AVERROR_OPTION_NOT_FOUND` (0xABAFB008) — an unknown option in `ffmpeg.args`. -/
example : cleanLegacy (-1414549496) = true ∧ cleanCorrect (-1414549496) = false := by decide

/-- `AVERROR_ENCODER_NOT_FOUND` (0xBCB1BA08) — a codec the shipped build lacks. -/
example : cleanLegacy (-1129203192) = true ∧ cleanCorrect (-1129203192) = false := by decide

/-- A Windows access violation surfaces as a negative exit. -/
example : cleanLegacy (-1073741819) = true ∧ cleanCorrect (-1073741819) = false := by decide

/-- The one code the legacy guard did catch: ffmpeg invoked with no arguments. -/
example : cleanLegacy 1 = false ∧ cleanCorrect 1 = false := by decide

#guard cleanLegacy (-2) && !cleanCorrect (-2)
#guard cleanLegacy (-1414549496) && !cleanCorrect (-1414549496)
#guard cleanLegacy (-1129203192) && !cleanCorrect (-1129203192)
#guard cleanCorrect 0 && cleanLegacy 0

/-! ## The general statements

These do not mention 127 or 8. They hold for every exit code, so they survive an
ffmpeg release that renumbers its errors. -/

/-- **Exactly** which exit codes the legacy predicate misclassifies: every code
except 0 (a genuine success) and 1 (the one failure it did catch). This is the
durable form of "127 and 8 slip through". -/
theorem legacy_misclassifies_iff (e : ExitCode) :
    (cleanLegacy e = true ∧ cleanCorrect e = false) ↔ (e ≠ 0 ∧ e ≠ 1) := by
  simp [cleanLegacy, cleanCorrect, and_comm]

/-- The correction is strictly stricter: it never rejects an exit the legacy
predicate accepted *for the right reason*. No genuine success is lost. -/
theorem correct_implies_legacy (e : ExitCode) :
    cleanCorrect e = true → cleanLegacy e = true := by
  simp +contextual [cleanLegacy, cleanCorrect]

/-- The two predicates are not equivalent — the fix is a real change in behaviour,
not a rename. -/
theorem legacy_ne_correct : ∃ e : ExitCode, cleanLegacy e ≠ cleanCorrect e :=
  ⟨-2, by decide⟩

/-- **The sharpened statement.** Every ffmpeg AVERROR is negative by construction —
`AVERROR(e) = -e` for an errno, and the `FFERRTAG` codes are negative too. So the
legacy guard misclassified *every* library-level ffmpeg failure, not merely the two
that happened to be measured. This quantifies over all negative codes, so a future
ffmpeg cannot escape it by renumbering. -/
theorem legacy_misclassifies_all_averror (e : ExitCode) (h : e < 0) :
    cleanLegacy e = true ∧ cleanCorrect e = false := by
  -- `omega` is unusable here: measured on Lean 4.32.2, it does not see through the
  -- `abbrev ExitCode := Int` on a hypothesis, reporting "No usable constraints found".
  rw [legacy_misclassifies_iff]
  refine ⟨?_, ?_⟩ <;> rintro rfl <;> exact absurd h (by decide)

/-- After the fix, `Remux` agrees with `Concatenate`/`CreateContactSheet`/`Script`,
which all test `exitCode == 0`. One codebase, one notion of success. -/
theorem correct_agrees_with_rest_of_codebase (e : ExitCode) :
    cleanCorrect e = true ↔ e = 0 := by
  simp [cleanCorrect]

/-! ## The consequence that actually costs data

`Remux.finalizeStep` deletes the input file when it judges the run clean and the
output file exists. ffmpeg writes its output incrementally, so a run that dies at
40% still leaves a (truncated) output file on disk — `outputExists` is *not*
evidence of success. -/

/-- What `Remux.finalizeStep` observes after an ffmpeg run. -/
structure RemuxOutcome where
  /-- The exit code from `ffmpeg.waitFor()`. -/
  exit : ExitCode
  /-- Whether the remuxed output file exists — true even for a truncated file. -/
  outputExists : Bool
  deriving DecidableEq, Repr

/-- `Remux.finalizeStep` deletes the source recording exactly when the guard passes
and the output file is present (`Remux.java:59-73`). -/
def deletesInput (clean : ExitCode → Bool) (o : RemuxOutcome) : Bool :=
  clean o.exit && o.outputExists

/-- **The safety property.** With the corrected predicate the original recording is
deleted only after ffmpeg genuinely succeeded. -/
theorem correct_deletes_input_only_on_success (o : RemuxOutcome) :
    deletesInput cleanCorrect o = true → o.exit = 0 := by
  simp +contextual [deletesInput, cleanCorrect]

/-- **The bug, stated as data loss.** The legacy predicate destroys the source
recording after a *failed* ffmpeg run that left a truncated file behind. -/
theorem legacy_loses_data :
    ∃ o : RemuxOutcome, o.exit ≠ 0 ∧ deletesInput cleanLegacy o = true :=
  ⟨⟨-2, true⟩, by decide, by decide⟩

/-- The corrected predicate admits no such outcome — for *any* failing exit code. -/
theorem correct_never_loses_data (o : RemuxOutcome) (h : o.exit ≠ 0) :
    deletesInput cleanCorrect o = false := by
  simp [deletesInput, cleanCorrect, h]

/-! ## Evidence preservation

`FFmpeg.shutdown` (`FFmpeg.java:57-63`) deletes the ffmpeg log when it judges the
run clean. Under the legacy predicate a failing run is judged clean, so the log
that would explain the failure is deleted — which is why the failures were
invisible in `ctbrec.log`. -/

/-- `FFmpeg.shutdown` deletes its log iff it judges the run clean. -/
def deletesLog (clean : ExitCode → Bool) (e : ExitCode) : Bool := clean e

/-- With the correction, a failing run always keeps its log. -/
theorem correct_keeps_log_on_failure (e : ExitCode) (h : e ≠ 0) :
    deletesLog cleanCorrect e = false := by
  simp [deletesLog, cleanCorrect, h]

/-- Under the legacy predicate the evidence for exit 127 was deleted. -/
theorem legacy_destroys_evidence : deletesLog cleanLegacy (-2) = true := by decide

end CtbrecSpec
