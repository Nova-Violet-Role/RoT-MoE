/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the MFC fields the app throws away

Subject: `src/common/ctbrec/sites/mfc/User.java`, `Share.java`, `SessionState.java` and
`src/common/ctbrec/io/json/ObjectMapperFactory.java`.

**Measured, by executing the real deserializer** (`tools/MfcBindCheck.java`), not by reading:

* `MyFreeCamsClient.java:327` and `:849` call `objectMapper.readValue(..., SessionState.class)`;
* Jackson binds nested objects through bean setters, so `setCountry`, `setEthnic`,
  `setOccupation`, `setAvatar` and `setChatColor` **do run** — the dead-code census called them
  unreferenced because no Java source mentions them, which is a limit of the scan, not a fact
  about the program;
* `User`, `Share` and `SessionState` each carry an `additionalProperties` map and a
  `setAdditionalProperty` method — the standard catch-all pattern;
* **none of them carries `@JsonAnySetter`**, and `ObjectMapperFactory` *disables*
  `FAIL_ON_UNKNOWN_PROPERTIES`.

The consequence, measured: a payload carrying `"surpriseKey":"unbound"` deserialized with no
error and `getAdditionalProperties().get("surpriseKey")` returned `null`. **Every field MFC adds
to its protocol is silently discarded**, into a map that exists precisely to hold it. The
implementation was never armed.

This module proves the repair before it is written, including the part that keeps it from
becoming a new defect: a diagnostic that logs every unknown key on every message would repeat
forever. That is not hypothetical here — a single repeated MFC error accounted for
**31.6 % of the whole 4.9 MB log** (RESUMEE-38). So the rule is *once per distinct key*, and the
bound is proved rather than hoped for.
-/

namespace CtbrecSpec

/-- The deserialiser's view of one object: the schema fields it knows, the unknown keys it has
already captured, and the keys it has already reported. -/
structure Catchall where
  /-- Field names the bean has setters for. -/
  known : List String
  /-- Unknown keys captured into `additionalProperties`, newest first. -/
  captured : List String
  /-- Unknown keys already reported once. -/
  reported : List String
  deriving DecidableEq, Repr

/-- A key the bean has a setter for. -/
def isKnown (c : Catchall) (k : String) : Bool := c.known.contains k

/-- **The old behaviour**: an unknown key changes nothing. `FAIL_ON_UNKNOWN_PROPERTIES` is
disabled, so it is not even an error — the value simply ceases to exist. -/
def dropUnknown (c : Catchall) (_k : String) : Catchall := c

/-- **The repair**: `@JsonAnySetter` routes the unknown key into the map. A known key is
untouched, because its own setter already handled it. -/
def captureUnknown (c : Catchall) (k : String) : Catchall :=
  if isKnown c k then c
  else { c with captured := k :: c.captured }

/-- Whether the diagnostic fires for this key: unknown, and not reported before. -/
def shouldReport (c : Catchall) (k : String) : Bool :=
  !isKnown c k && !c.reported.contains k

/-- Reporting marks the key, so the next occurrence is silent. -/
def markReported (c : Catchall) (k : String) : Catchall :=
  if c.reported.contains k then c else { c with reported := k :: c.reported }

/-- One message field: capture it, and report it if this is the first time.

Written flat rather than as `markReported (captureUnknown c k) k`: the nested form produced
three levels of `if` inside every goal and the proofs became unreadable. Equivalent by
`observe_agrees_with_the_composed_form` below, which is stated so the flattening is checked
rather than assumed. -/
def observe (c : Catchall) (k : String) : Catchall :=
  if isKnown c k then c
  else { c with captured := k :: c.captured,
                reported := if c.reported.contains k then c.reported else k :: c.reported }

/-- The flat definition is the composition it replaced. -/
theorem observe_agrees_with_the_composed_form (c : Catchall) (k : String) :
    observe c k = (if shouldReport c k then markReported (captureUnknown c k) k
                   else captureUnknown c k) := by
  by_cases hk : k ∈ c.known
  · simp [observe, shouldReport, captureUnknown, isKnown, hk]
  · by_cases hr : k ∈ c.reported
    · simp [observe, shouldReport, captureUnknown, markReported, isKnown, hk, hr]
    · simp [observe, shouldReport, captureUnknown, markReported, isKnown, hk, hr]

/-- Fold a whole message. -/
def observeAll (c : Catchall) (ks : List String) : Catchall :=
  ks.foldl observe c

/-- **The defect, stated exactly**: the old path never captures anything, whatever arrives. -/
theorem the_old_path_captures_nothing (c : Catchall) (k : String) :
    (dropUnknown c k).captured = c.captured := rfl

/-- **The repair captures every unknown key.** Quantified over the key and the state, so it is
not a claim about one example payload. -/
theorem an_unknown_key_is_captured (c : Catchall) (k : String) (h : isKnown c k = false) :
    (captureUnknown c k).captured = k :: c.captured := by
  unfold captureUnknown
  simp [h]

/-- **A known field is left alone.** The catch-all must not shadow a real setter — that would
turn a fix into a data-corruption bug. -/
theorem a_known_key_is_untouched (c : Catchall) (k : String) (h : isKnown c k = true) :
    captureUnknown c k = c := by
  unfold captureUnknown
  simp [h]

/-- Capture never loses what was already there: the old contents remain a suffix. -/
theorem capture_never_drops (c : Catchall) (k : String) :
    c.captured.length ≤ (captureUnknown c k).captured.length := by
  unfold captureUnknown
  by_cases h : isKnown c k
  · simp [h]
  · simp [h]

/-- **The log bound, first half**: a key is reported at most once. After observing it, the
diagnostic is silent for that key forever. -/
theorem a_reported_key_is_never_reported_again (c : Catchall) (k : String) :
    shouldReport (observe c k) k = false := by
  by_cases hk : k ∈ c.known
  · simp [observe, shouldReport, isKnown, hk]
  · by_cases hr : k ∈ c.reported
    · simp [observe, shouldReport, isKnown, hk, hr]
    · simp [observe, shouldReport, isKnown, hk, hr]

/-- **The log bound, second half**: a known field never produces a line at all. Without this the
diagnostic would fire on every ordinary message — which is the 31.6 %-of-the-log failure. -/
theorem a_known_field_is_never_reported (c : Catchall) (k : String) (h : isKnown c k = true) :
    shouldReport c k = false := by
  unfold shouldReport
  simp [h]

/-- **Idempotence over a repeated field**: seeing the same unknown key twice reports once. This
is the statement a reader of the log cares about. -/
theorem a_repeated_unknown_key_reports_once (c : Catchall) (k : String)
    (h : k ∉ c.known) (hr : k ∉ c.reported) :
    shouldReport c k = true ∧ shouldReport (observe c k) k = false := by
  constructor
  · simp [shouldReport, isKnown, h, hr]
  · exact a_reported_key_is_never_reported_again c k

/-- The reported set only grows — the diagnostic can never re-arm itself for a key it has
already spent. -/
theorem reported_only_grows (c : Catchall) (k : String) :
    c.reported.length ≤ (observe c k).reported.length := by
  by_cases hk : k ∈ c.known
  · simp [observe, isKnown, hk]
  · by_cases hr : k ∈ c.reported
    · simp [observe, isKnown, hk, hr]
    · simp [observe, isKnown, hk, hr]

/-- A schema with the three MFC fields the checker exercises. -/
def userSchema : Catchall := ⟨["country", "ethnic", "occupation", "avatar", "chatColor"], [], []⟩

-- The measured payload: five known fields bind normally, the unknown one is captured.
#guard (captureUnknown userSchema "country").captured == []
#guard (captureUnknown userSchema "surpriseKey").captured == ["surpriseKey"]
-- The old behaviour on the same key, which is what was measured before the repair.
#guard (dropUnknown userSchema "surpriseKey").captured == []
-- The diagnostic fires once and then never again.
#guard shouldReport userSchema "surpriseKey" == true
#guard shouldReport (observe userSchema "surpriseKey") "surpriseKey" == false
#guard shouldReport userSchema "country" == false
-- A whole message with a repeated unknown key reports it once.
#guard (observeAll userSchema ["surpriseKey", "country", "surpriseKey"]).reported == ["surpriseKey"]
#guard (observeAll userSchema ["surpriseKey", "country", "surpriseKey"]).captured
        == ["surpriseKey", "surpriseKey"]

end CtbrecSpec
