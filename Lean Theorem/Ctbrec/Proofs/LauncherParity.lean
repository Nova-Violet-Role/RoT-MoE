/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — every launcher must start the SAME JVM

Subject: `ctbrec.bat`, `ctbrec.l4j.ini` (used by `ctbrec.exe`), `CtbrecEVO.l4j.ini` (used by the new
`CtbrecEVO.exe`), and `ctbrec-no-splash.l4j.ini`.

The app can be started several ways. Each way supplies its own JVM argument list, and **nothing
made them agree**. Measured before the repair:

| flag | `ctbrec.bat` | `ctbrec.l4j.ini` |
|---|---|---|
| `-Dctbrec.config.dir=./config` | yes | yes |
| `-Dsun.net.inetaddr.stale.ttl=3600` | yes | yes |
| `--module-path lib` | yes | yes |
| `--add-modules javafx.…` | yes | yes |
| `--enable-native-access=…` | yes | yes |
| `--add-opens javafx.controls/…` | yes | yes |
| **`-Xmx4g`** | yes | **MISSING** |
| **`-Dfile.encoding=utf-8`** | yes | **MISSING** |

So `ctbrec.exe` ran the app on the JVM's *default* heap while `ctbrec.bat` ran it on 4 GB — two
launchers, two different programs. This is the same shape as the mirrored-property defect of
checkpoints 64/66: several write paths, and only one of them updated when the configuration changed.
The `.bat` carries long rework comments explaining `--module-path` and the DNS TTL; those changes
reached the `.ini` and the heap setting did not.

## The statement

The durable property is not "these two files match today". It is: **for every launcher, and every
flag the app requires, that launcher supplies it.** A launcher added tomorrow is covered by the same
theorem, and a flag added tomorrow is covered for every launcher at once — which is exactly what
failed here, since `-Xmx4g` was added to one file only.

`required` is the reference set. `parity` asks the question of a whole launcher list, so the check
cannot silently stop covering a file that someone adds later.
-/

import Proofs.Ctbrec.ModelViews

namespace CtbrecSpec

/-- A launcher is the list of JVM flags it passes, as opaque tokens. -/
abbrev Launcher := List String

/-- One launcher supplies every flag in the reference set. -/
def supplies (req : List String) (l : Launcher) : Bool :=
  req.all (fun f => l.contains f)

/-- Every launcher supplies every required flag. -/
def parity (req : List String) (ls : List Launcher) : Bool :=
  ls.all (supplies req)

/-- The flags missing from one launcher — what the check must print to be actionable. -/
def missingFrom (req : List String) (l : Launcher) : List String :=
  req.filter (fun f => !l.contains f)

/-! ### The defect, and that the repair actually repairs it -/

/-- **A launcher missing one required flag fails parity**, however many others it carries. This is
the shipped `ctbrec.l4j.ini` in one line: six of eight flags present is still a different JVM. -/
theorem one_missing_flag_breaks_parity (req : List String) (l : Launcher) (f : String)
    (hf : f ∈ req) (hl : l.contains f = false) : supplies req l = false := by
  unfold supplies
  cases hall : req.all (fun g => l.contains g) with
  | false => rfl
  | true =>
    rw [List.all_eq_true] at hall
    have hc := hall f hf
    simp only [hl] at hc
    exact Bool.noConfusion hc

/-- `missingFrom` names exactly the offending flags — the check is actionable, not just red. -/
theorem missing_lists_exactly_the_absent_flags (req : List String) (l : Launcher) (f : String) :
    f ∈ missingFrom req l ↔ (f ∈ req ∧ l.contains f = false) := by
  unfold missingFrom
  rw [List.mem_filter, Bool.not_eq_true']

/-- **Parity holds exactly when nothing is missing anywhere.** The two views of the check — the
boolean verdict and the printed list — can never disagree. -/
theorem parity_iff_nothing_missing (req : List String) (l : Launcher) :
    supplies req l = true ↔ missingFrom req l = [] := by
  constructor
  · intro h
    unfold supplies at h
    rw [List.all_eq_true] at h
    apply List.eq_nil_iff_forall_not_mem.mpr
    intro f hf
    rw [missing_lists_exactly_the_absent_flags] at hf
    have hc := h f hf.1
    rw [hf.2] at hc
    exact Bool.noConfusion hc
  · intro h
    unfold supplies
    rw [List.all_eq_true]
    intro f hf
    have hnm : f ∉ missingFrom req l := by
      rw [h]; exact List.not_mem_nil
    cases hc : l.contains f with
    | true => rfl
    | false =>
      exact absurd ((missing_lists_exactly_the_absent_flags req l f).mpr ⟨hf, hc⟩) hnm

/-! ### Anti-amputation — the two ways to fake this green -/

/-- **An empty requirement set makes every launcher pass.** So the check must assert the reference
set is non-empty; "parity holds" is worthless if nothing is required. This is the amputation a future
edit would reach for when a launcher legitimately cannot carry a flag. -/
theorem an_empty_requirement_passes_anything (ls : List Launcher) : parity [] ls = true := by
  simp [parity, supplies]

/-- **An empty launcher LIST also passes.** So the check must assert it found some launchers — a
sweep that globbed nothing reads exactly like a sweep that found everything in order. -/
theorem an_empty_launcher_list_passes_anything (req : List String) : parity req [] = true := by
  simp [parity]

/-- With a non-empty requirement, an empty launcher genuinely fails — the check has teeth once the
two amputations above are ruled out. -/
theorem a_bare_launcher_fails_a_real_requirement (f : String) (req : List String)
    (hf : f ∈ req) : supplies req [] = false := by
  apply one_missing_flag_breaks_parity req [] f hf
  simp

/-- **Adding a flag to a launcher never breaks parity.** So bringing a lagging launcher up to the
reference set is always safe, and the repair cannot regress a launcher that was already correct. -/
theorem adding_a_flag_never_breaks_parity (req : List String) (l : Launcher) (g : String)
    (h : supplies req l = true) : supplies req (g :: l) = true := by
  unfold supplies at h ⊢
  rw [List.all_eq_true] at h ⊢
  intro f hf
  have hc := h f hf
  simp only [List.contains_cons, hc, Bool.or_true]

/-- **Adding a requirement can break parity — for every launcher at once.** This is the theorem that
names what went wrong: `-Xmx4g` was added to the reference and reached only one file. -/
theorem a_new_requirement_is_checked_against_every_launcher
    (req : List String) (ls : List Launcher) (h : parity req ls = true) (l : Launcher)
    (hl : l ∈ ls) : supplies req l = true := by
  unfold parity at h
  rw [List.all_eq_true] at h
  exact h l hl

#guard supplies ["-Xmx4g", "--module-path"] ["-Xmx4g", "--module-path", "lib"] == true
#guard supplies ["-Xmx4g", "--module-path"] ["--module-path", "lib"] == false
#guard missingFrom ["-Xmx4g", "-Dfile.encoding=utf-8"] ["--module-path"]
        == ["-Xmx4g", "-Dfile.encoding=utf-8"]
#guard missingFrom ["-Xmx4g"] ["-Xmx4g"] == []
#guard parity ["-Xmx4g"] [["-Xmx4g"], ["-Xmx4g", "-x"]] == true
#guard parity ["-Xmx4g"] [["-Xmx4g"], ["-x"]] == false
#guard parity [] [["anything"]] == true
#guard parity ["-Xmx4g"] [] == true

end CtbrecSpec
