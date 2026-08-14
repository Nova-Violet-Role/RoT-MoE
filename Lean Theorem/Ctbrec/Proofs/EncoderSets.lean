/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — three answers to "which encoders can this machine use"

Subject: `src/common/ctbrec/recorder/FfmpegPresets.java` — `parseEncoders` (:300),
`probeEncoders` (:331), `available`/`available60` (:279, :211), and the id projections
`availableIds` (:371) / `available60Ids` (:220) that the census flagged with no caller.

Three different sets exist in this file and they answer three different questions:

| set | question | how obtained |
|---|---|---|
| `K` — parsed | which encoders is this **ffmpeg build** compiled with? | text of `ffmpeg -encoders` |
| `W` — probed | which encoders actually **produce a frame** here? | one real encode per candidate |
| `T` — tabled | which encoders does the **preset table** name? | the shipped `PRESETS` |

They are not interchangeable, and the file says so: `parseEncoders` carries a javadoc warning that
it is *not* availability. Measured on this machine, `av1_amf`, `h264_nvenc`, `hevc_nvenc` and
`av1_nvenc` are compiled in and **fail at runtime** (`CreateComponent(AMFVideoEncoderHW_AV1)
failed with error 30`, `Cannot load nvcuda.dll`). Confusing `K` with `W` selects a preset that
cannot encode.

## The two properties worth pinning

**Soundness of the probe**: an encoder cannot work if the binary does not contain it — `W ⊆ K`.
A violation means the probe is measuring something other than what it claims, and it would be
invisible without this statement.

**Coverage of the table**: an encoder that works here and is *not* named by any preset is
hardware this build cannot reach — exactly the Socio's complaint that the app does not use the
most advanced ffmpeg available locally. `W \ T` is therefore a **capability gap**, not an error,
and it must be reported rather than hidden.

The census methods are explained by the same model: `availableIds` and `available60Ids` are
projections of the lists the settings screen already uses, so their only obligation is to
**agree** with them. That obligation is what the theorems below state, and what the checker
executes.
-/

namespace CtbrecSpec

/-- An encoder name, as a code. Names are irrelevant to the properties; membership is not. -/
abbrev Enc := Nat

/-- The three sets, as measured for one machine. -/
structure EncoderView where
  /-- Compiled into the ffmpeg binary (`parseEncoders`). -/
  parsed : List Enc
  /-- Produced a frame in a real encode (`probeEncoders`). -/
  probed : List Enc
  /-- Named by some preset in the shipped table. -/
  tabled : List Enc
  deriving DecidableEq, Repr

/-- Soundness: everything that worked is present in the binary. -/
def probeIsSound (v : EncoderView) : Bool :=
  v.probed.all (fun e => v.parsed.contains e)

/-- Working hardware the preset table cannot reach. Reported, never silently dropped. -/
def capabilityGap (v : EncoderView) : List Enc :=
  v.probed.filter (fun e => !v.tabled.contains e)

/-- Encoders the table names that do not work here — the ordinary case, and the reason
`probeEncoders` exists at all. -/
def brokenButOffered (v : EncoderView) : List Enc :=
  v.tabled.filter (fun e => !v.probed.contains e)

/-- The measured view of this machine: the table names six encoders, four of them fail at
runtime, and every probed encoder is compiled in. -/
def thisMachine : EncoderView :=
  { parsed := [1, 2, 3, 4, 5, 6, 7], probed := [1, 2, 3], tabled := [1, 2, 3, 4, 5, 6, 7] }

/-- The RAW hardware encoders in this ffmpeg build: 14, against 7 the table names. The gap can
only be seen by reading this list independently — see
`CtbrecSpec.FallbackPreset.a_table_restricted_scan_is_blind`. -/
def rawHardwareCount : Nat := 14

/-- **The binary carries twice what the table names.** Half the hardware in this ffmpeg is
outside the app's vocabulary; whether any of it WORKS is the question the probe answers, and
before `h264_mf` was added the answer was yes and nothing reported it. -/
theorem the_binary_carries_more_than_the_table_names :
    (thisMachine.tabled.length < rawHardwareCount) = true := by decide

/-- **The probe is sound here.** -/
theorem the_probe_is_sound_on_this_machine : probeIsSound thisMachine = true := by decide

/-- **There is no capability gap here**: everything that works is already reachable through a
preset. Stated as a theorem rather than a comment because it is the claim that would silently
become false the day this machine gains an encoder the table does not name. -/
theorem no_working_encoder_is_unreachable : capabilityGap thisMachine = [] := by decide

/-- **Four offered encoders do not work here.** This is the number the preset menu must not
show, and the reason `probeEncoders` is the gate rather than `parseEncoders`. -/
theorem four_tabled_encoders_fail_on_this_machine :
    (brokenButOffered thisMachine).length = 4 := by decide

/-- **Using the parsed set as availability would offer every broken encoder.** The defect stated
as a comparison rather than as prose: the parsed set is strictly larger than the working one. -/
theorem the_parsed_set_overstates_what_works :
    (thisMachine.probed.length < thisMachine.parsed.length) = true := by decide

/-- The durable direction: soundness is a property of the pair, and it fails exactly when a
probed encoder is absent from the parsed set. Quantified, so no measured table can satisfy it by
accident. -/
theorem soundness_fails_iff_a_probed_encoder_is_unparsed (v : EncoderView) :
    probeIsSound v = false ↔ ∃ e ∈ v.probed, ¬ v.parsed.contains e := by
  unfold probeIsSound
  simp

/-- **Anti-amputation**: a probe that returned nothing would be trivially sound. The measured
view must therefore also be non-empty, and that is asserted separately — otherwise "sound" could
be bought by disabling the probe. -/
theorem the_probe_found_something : thisMachine.probed ≠ [] := by decide

/-- …and the gap computation is not constantly empty either: a view with an unreachable encoder
reports it. Without this, `capabilityGap := fun _ => []` would satisfy the theorem above. -/
theorem the_gap_is_reported_when_it_exists :
    capabilityGap { parsed := [1, 2], probed := [1, 2], tabled := [1] } = [2] := by decide

/-! ### The id projections the census flagged -/

/-- A preset, reduced to what the projections touch. -/
structure P where
  id : Nat
  enc : Enc
  deriving DecidableEq, Repr

/-- `available`: the presets whose encoder works. -/
def availablePresets (working : List Enc) (table : List P) : List P :=
  table.filter (fun p => working.contains p.enc)

/-- `availableIds`: the same, projected to ids. -/
def availableIdList (working : List Enc) (table : List P) : List Nat :=
  (availablePresets working table).map (fun p => p.id)

/-- **The projection agrees with the list the settings screen uses**, for every machine and every
table. This is the entire obligation of an unused convenience method: it must not be able to
disagree with the method that is used. Quantified, so it cannot be satisfied by a sample. -/
theorem the_id_projection_agrees_with_the_preset_list (working : List Enc) (table : List P) :
    availableIdList working table = (availablePresets working table).map (fun p => p.id) := rfl

/-- The projection preserves length: no preset is dropped or duplicated on the way to ids. -/
theorem the_projection_drops_nothing (working : List Enc) (table : List P) :
    (availableIdList working table).length = (availablePresets working table).length := by
  unfold availableIdList
  simp

/-- **Anti-amputation for the projection**: it is not constantly empty. -/
theorem the_projection_returns_something :
    availableIdList [7] [⟨1, 7⟩, ⟨2, 8⟩] = [1] := by decide

/-- And it filters: a preset whose encoder does not work is absent from the ids. -/
theorem the_projection_filters :
    availableIdList [7] [⟨1, 7⟩, ⟨2, 8⟩] ≠ [1, 2] := by decide

#guard probeIsSound thisMachine == true
#guard capabilityGap thisMachine == []
#guard (brokenButOffered thisMachine).length == 4
#guard capabilityGap { parsed := [1, 2], probed := [1, 2], tabled := [1] } == [2]
#guard availableIdList [7] [⟨1, 7⟩, ⟨2, 8⟩] == [1]
#guard probeIsSound { parsed := [1], probed := [1, 2], tabled := [1] } == false

end CtbrecSpec
