/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Authors: ctbrec-rework spec

# An error signature must name the FAILURE MODE, not the instance that hit it

Measured 2026-08-10 in `build/log-signatures.baseline`:

    baseline entries carrying a model name        6
    distinct models that ever failed to start     6      <- exact 1:1

One failure mode, six baseline entries -- `CB:annabisoux`, `CB:bunnydollstella`, `CB:kellytesh`,
`CB:mariannacruzz`, `CB:missyrai`, and now `CB:mia_dynasty` flagged as NOVEL. The normaliser in
`build/phase90.sh:42` collapses line numbers (`s/[0-9]{2,}/N/g`) but leaves the model token, so
every model that ever fails mints a fresh signature.

Consequence, and it is the reason this is a DEFECT and not a nuisance: such an alarm fires exactly
once per instance and never again. It cannot converge, it cannot be triaged, and its baseline grows
without bound. An alarm that only ever reports noise trains its reader to ignore it.

The repair must collapse instances WITHOUT collapsing modes. That second half is the whole risk:
an over-eager normaliser is indistinguishable from deleting the check, which the goal forbids. Both
directions are proved below.
-/

namespace CtbrecSpec.SignatureNormalization

/-- A log signature as the checker stores it: the emitting site, the message shape, and the
instance token (the model) that happened to hit it. -/
structure Signature where
  site     : String
  message  : String
  subject  : String
  deriving DecidableEq, Repr

/-- The failure MODE is the site and the message. The instance is incidental. -/
def mode (s : Signature) : String × String := (s.site, s.message)

/-- Normalisation replaces the instance token with a fixed placeholder. -/
def normalize (s : Signature) : Signature :=
  { s with subject := "MODEL" }

/-! ## The collapse: instances of one mode become one signature -/

/-- Two signatures of the SAME mode normalise to the same thing, whatever instance hit them.
This is the collapse that takes the six baseline entries down to one. -/
theorem same_mode_normalizes_equal (a b : Signature) (h : mode a = mode b) :
    normalize a = normalize b := by
  unfold mode at h
  unfold normalize
  cases a; cases b
  simp_all

/-- Normalisation is idempotent: re-running the checker cannot drift. -/
theorem normalize_idempotent (s : Signature) : normalize (normalize s) = normalize s := by
  unfold normalize; rfl

/-- Normalisation never changes the mode -- it only discards the instance. -/
theorem normalize_preserves_mode (s : Signature) : mode (normalize s) = mode s := by
  unfold mode normalize; rfl

/-! ## Detection is PRESERVED -- the half that makes this a fix and not a deletion -/

/-- Signatures of DIFFERENT modes stay different after normalisation. A genuinely new failure
still fires. Without this theorem the repair would be indistinguishable from disarming the check. -/
theorem different_modes_stay_distinct (a b : Signature) (h : mode a ≠ mode b) :
    normalize a ≠ normalize b := by
  intro heq
  apply h
  have := congrArg mode heq
  rwa [normalize_preserves_mode, normalize_preserves_mode] at this

/-- Sharper form: a new MESSAGE at the same site is still detected. -/
theorem a_new_message_still_fires (site m1 m2 i1 i2 : String) (h : m1 ≠ m2) :
    normalize ⟨site, m1, i1⟩ ≠ normalize ⟨site, m2, i2⟩ := by
  apply different_modes_stay_distinct
  unfold mode
  simp [h]

/-- A new SITE emitting the same message is still detected. -/
theorem a_new_site_still_fires (s1 s2 m i1 i2 : String) (h : s1 ≠ s2) :
    normalize ⟨s1, m, i1⟩ ≠ normalize ⟨s2, m, i2⟩ := by
  apply different_modes_stay_distinct
  unfold mode
  simp [h]

/-! ## Why the un-normalised form cannot converge -/

/-- The baseline required WITHOUT normalisation: one entry per distinct instance. -/
def dedup : List Signature -> List Signature
  | [] => []
  | x :: xs => x :: (dedup xs).filter (fun y => y != x)

def rawEntries (ss : List Signature) : List Signature := dedup ss

/-- The baseline required WITH normalisation. -/
def normEntries (ss : List Signature) : List Signature :=
  dedup (ss.map normalize)

/-- The six measured baseline entries: ONE failure mode, six models.
Source: `build/log-signatures.baseline`, measured 2026-08-10. -/
def measured : List Signature :=
  [⟨"SimplifiedLocalRecorder.java:N", "Couldn't start recording process for CB", "annabisoux"⟩,
   ⟨"SimplifiedLocalRecorder.java:N", "Couldn't start recording process for CB", "bunnydollstella"⟩,
   ⟨"SimplifiedLocalRecorder.java:N", "Couldn't start recording process for CB", "kellytesh"⟩,
   ⟨"SimplifiedLocalRecorder.java:N", "Couldn't start recording process for CB", "mariannacruzz"⟩,
   ⟨"SimplifiedLocalRecorder.java:N", "Couldn't start recording process for CB", "missyrai"⟩,
   ⟨"SimplifiedLocalRecorder.java:N", "Couldn't start recording process for CB", "mia_dynasty"⟩]

-- MEASURED, and this is the whole point: six entries collapse to ONE
#guard (rawEntries measured).length = 6
#guard (normEntries measured).length = 1

/-- A genuinely different failure at the same site is NOT collapsed -- it survives as a second
entry. This is the negative control: the repair still detects a new mode. -/
def measuredPlusNovel : List Signature :=
  measured ++ [⟨"SimplifiedLocalRecorder.java:N", "Disk full while writing segment", "anymodel"⟩]

#guard (normEntries measuredPlusNovel).length = 2

/-- On the measured data the collapse is strict: normalisation genuinely shrinks the baseline. -/
theorem measured_collapse_is_strict :
    (normEntries measured).length < (rawEntries measured).length := by decide

/-- NOT PROVED IN GENERAL. The universal bound
`(normEntries ss).length <= (rawEntries ss).length` is believed true but is not established
here -- the lemma name reached for (`List.length_eliminateDuplicates_map_le`) does not exist,
and no proof was completed. It is stated as an explicit open obligation rather than assumed,
because a `sorry` here would read as settled. The MEASURED instances above are decided by
`decide` and stand on their own. -/
def universalBoundIsOpen : String :=
  "open: (normEntries ss).length <= (rawEntries ss).length for all ss"

end CtbrecSpec.SignatureNormalization
