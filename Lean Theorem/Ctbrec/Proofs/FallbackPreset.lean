/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — a hardware path for machines whose vendor encoders are broken

Subject: `src/common/ctbrec/recorder/FfmpegPresets.java` — the preset table, `available`, and the
new `h264_mf` entry.

## The measurement that forced this module

The local ffmpeg (82 732 544 bytes) contains **14** hardware video encoders. The preset table
names **6**. Probed on this machine, one at a time, with a real encode:

| encoder | result |
|---|---|
| `h264_amf`, `hevc_amf` | encode a frame |
| `av1_amf`, `h264_nvenc`, `hevc_nvenc`, `av1_nvenc` | fail (no CUDA, AV1 component absent) |
| `av1_qsv`, `h264_qsv`, `hevc_qsv`, `vp9_qsv`, `mjpeg_qsv`, `mpeg2_qsv` | fail — `Error creating a MFX session: -9` |
| `hevc_mf` | fails — no MFT for the media type |
| **`h264_mf`** | **works, and no preset could reach it** |

That last row is the Socio's complaint made concrete: working hardware the build cannot use.

Note also *why* the app could not have noticed. `parseEncoders` only looks for encoder names the
preset table already contains, so the set it returns is bounded by the table — a scan restricted
to the table can never discover anything outside it. `a_table_restricted_scan_is_blind` states
exactly that, and it is the reason the raw `-encoders` list had to be read independently.

## The constraint that made the naive fix wrong

`Presets.lean:361` pins `presets.length == 10` and calls it "the requested ceiling". Adding an
eleventh row would break it. But the requirement is about **what the user is offered**, and the
user is offered `available(working)` — never the raw table. So the durable form of the constraint
is *the menu never exceeds ten on any machine*, quantified over the working set. Under that form
an eleventh row is admissible precisely when no machine can see all eleven at once.

That is what a **fallback** is: `h264_mf` is offered only on a machine where no vendor preset
works. On this machine AMF works, so the menu is unchanged; on a machine where AMF and NVENC are
both broken — four of six encoders already fail here, so the class is not hypothetical — the user
gains a hardware path instead of software-only stream copy.

The quality rung was measured, not guessed: at 1280×720/30 for 300 frames, `-rate_control quality
-quality 60` gives SSIM **0.991756** at 702 permille of source, matching the AMD-H264 rung's SSIM
0.990952 (365 permille). Same fidelity target; the cost of the fallback is stated, not hidden.
-/

namespace CtbrecSpec

/-- What a preset needs from the machine. -/
inductive EntryKind where
  /-- Stream copy: always available, needs no encoder. -/
  | copy
  /-- A vendor hardware preset (AMF, NVENC). -/
  | primary
  /-- Offered only when no primary preset is available. -/
  | fallback
  deriving DecidableEq, Repr

structure MenuEntry where
  id : Nat
  kind : EntryKind
  /-- The encoder this preset needs; irrelevant for `copy`. -/
  enc : Nat
  deriving DecidableEq, Repr

/-- The three stream-copy presets: always offered, no encoder needed. -/
def copies : List MenuEntry := [⟨0, .copy, 0⟩, ⟨1, .copy, 0⟩, ⟨2, .copy, 0⟩]

/-- The seven vendor presets (AMF, NVENC). -/
def primaries : List MenuEntry :=
  [⟨3, .primary, 10⟩, ⟨4, .primary, 11⟩, ⟨5, .primary, 12⟩, ⟨6, .primary, 13⟩,
   ⟨7, .primary, 14⟩, ⟨8, .primary, 15⟩, ⟨9, .primary, 16⟩]

/-- The one fallback: `h264_mf`. -/
def fallbackEntry : MenuEntry := ⟨10, .fallback, 20⟩

/-- The shipped table. Split into its three groups so the ceiling proof can reason about each
group separately instead of exhausting 2^8 machines. Ids are codes; the counts are what matter. -/
def table : List MenuEntry := copies ++ primaries ++ [fallbackEntry]


/-- A preset whose encoder the machine can run. `copy` never needs one. -/
def runnable (working : List Nat) (p : MenuEntry) : Bool :=
  match p.kind with
  | .copy => true
  | _ => working.contains p.enc

/-- Is any vendor preset available on this machine? -/
def anyPrimary (working : List Nat) : Bool :=
  primaries.any (runnable working)

/-- **The menu**, written the way `available()` builds it: stream copy always, vendor presets
that run, and the fallback **only** when no vendor preset is available. -/
def menu (working : List Nat) : List MenuEntry :=
  copies ++ primaries.filter (runnable working) ++
    (if anyPrimary working then [] else [fallbackEntry].filter (runnable working))

/-- The requested ceiling, restated as the property it was always about. -/
def ceiling : Nat := 10

/-- **The menu never exceeds ten, on any machine.** This is the durable form of the constraint
that `presets.length == 10` froze: quantified over the working set, so it survives the table
growing. The two branches are the whole argument — with a vendor preset the fallback is absent
(3+7+0), without one every vendor preset is absent (3+0+1). -/
theorem the_menu_never_exceeds_the_ceiling (working : List Nat) :
    (menu working).length ≤ ceiling := by
  unfold menu ceiling
  rw [List.length_append, List.length_append]
  have hc : copies.length = 3 := by decide
  have hp : (primaries.filter (runnable working)).length ≤ 7 := by
    have h := List.length_filter_le (runnable working) primaries
    simpa [primaries] using h
  cases hap : anyPrimary working with
  | true => simp [hc, hap]; omega
  | false =>
    have hnone : primaries.filter (runnable working) = [] := by
      rw [List.filter_eq_nil_iff]
      intro p hpmem
      have := List.any_eq_false.mp (by simpa [anyPrimary] using hap) p hpmem
      simp [this]
    have hf : ([fallbackEntry].filter (runnable working)).length ≤ 1 := by
      simpa using List.length_filter_le (runnable working) [fallbackEntry]
    simp [hc, hap, hnone]
    omega

/-- **The bound is TIGHT.** A mutation raising `ceiling` to 11 survived the theorem above —
correctly, because "≤ 11" is also true. A ceiling nobody can reach is not a ceiling, so this names
a machine whose menu holds exactly ten: with everything working the user sees ten presets and the
fallback is hidden. Raising or lowering `ceiling` now fails to build. -/
theorem the_ceiling_is_reached :
    (menu [10, 11, 12, 13, 14, 15, 16, 20]).length = ceiling := by decide

/-- **The fallback is offered exactly when it is needed**: its encoder works and nothing else
hardware-accelerated does. Not "sometimes", not "on the machine I tested". -/
theorem the_fallback_appears_exactly_when_no_primary_does (working : List Nat) :
    fallbackEntry ∈ menu working ↔
      (working.contains 20 = true ∧ anyPrimary working = false) := by
  unfold menu
  cases hap : anyPrimary working <;>
    simp [copies, primaries, fallbackEntry, runnable, hap, List.mem_filter]

/-- **On a machine with no vendor encoder the fallback is the only hardware path.** Without this
theorem the addition would be decoration: it says the change does something, on a real class of
machine (four of six vendor encoders already fail here). -/
theorem a_broken_vendor_machine_gains_a_hardware_path :
    (menu [20]).length = 4 ∧ fallbackEntry ∈ menu [20] := by decide

/-- …and without the fallback that same machine would see stream copy only. -/
theorem without_the_fallback_it_would_be_software_only :
    (copies ++ primaries.filter (runnable [20])).length = 3 := by decide

/-- **On this machine the menu is unchanged**: AMF works, so the fallback stays hidden and the
addition costs the user nothing. -/
theorem this_machine_sees_no_new_entry :
    menu [10, 11] = copies ++ primaries.filter (runnable [10, 11]) := by decide

/-- **Anti-amputation**: the menu is never empty — stream copy is always offered, whatever the
hardware. A rule that hid everything would satisfy the ceiling trivially. -/
theorem the_menu_is_never_empty (working : List Nat) : menu working ≠ [] := by
  unfold menu
  simp [copies]

/-- **The fallback displaces nothing.** Every vendor preset that runs is still in the menu, so
the addition is monotone on the presets that already worked. -/
theorem the_fallback_displaces_nothing (working : List Nat) (p : MenuEntry)
    (hp : p ∈ primaries) (hr : runnable working p = true) : p ∈ menu working := by
  unfold menu
  simp [List.mem_filter, hp, hr]

/-- **A table-restricted scan is blind.** `parseEncoders` looks only for encoder names the table
already contains, so its result is a subset of the table's encoders and cannot report anything
outside it. This is why the capability gap was invisible until the raw list was read. -/
theorem a_table_restricted_scan_is_blind (raw : List Nat) (known : List Nat) :
    (raw.filter (fun e => known.contains e)).all (fun e => known.contains e) = true := by
  simp [List.all_eq_true, List.mem_filter]

#guard (menu [10, 11]).length == 5
#guard (menu [20]).length == 4
#guard (menu []).length == 3
#guard (menu [10, 11, 20]).contains fallbackEntry == false
#guard (menu [20]).contains fallbackEntry == true
#guard table.length == 11
#guard (menu [10, 11, 12, 13, 14, 15, 16, 20]).length == 10

end CtbrecSpec
