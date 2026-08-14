/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: a failure must never be readable as "no models" (checklist item A2).

MEASURED 2026-08-03 in ctbrec.log: eleven UnknownHostException for chaturbate.com inside one
two-minute window (16:37:33 - 16:39:30). The tab rendered them with `getLocalizedMessage()`, and
UnknownHostException's message is JUST THE HOSTNAME, so the whole user-visible evidence of a DNS
outage was:

    Error while updating chaturbate.com

beside that same tab's empty-result label, `Nothing found!` (ThumbOverviewTab.java:126). Two
different situations, one indistinguishable reading.

Mirrors src/common/ctbrec/io/FetchFailureDiagnosis.java. Executable agreement on REAL exception
objects, wrapped three deep: tools/probe/FailureDiagnosisProbe.java (10 kinds, 0 collisions).

The wrapping law is the one with teeth: OkHttp and this tree's own rethrow paths deliver the
resolution failure INSIDE an IOException, so a classifier that inspects only the outermost type
reports "Network failure" and the DNS hint never appears. That classifier is mutant D3.

NOT PROVED: that JavaFX draws the label, or that the wording is good English. The probe checks the
strings; the ear and the eye are the Socio's.
-/

namespace Proofs.Ctbrec.FetchFailureDiagnosis

/-- The failure kinds the classifier recognises, plus the two catch-alls. -/
inductive Kind where
  | nameResolution
  | timeout
  | connectionRefused
  | noRoute
  | tls
  | http (code : Nat)
  | interrupted
  | otherIO
  | nonIO
  | noException
  deriving DecidableEq, Repr

/--
What the user is shown, modelled by the properties that matter rather than by the English.
`blank` and `equalsEmptyResult` are the two failure modes A2 forbids; `namesCause` is what it
requires.
-/
structure Diagnosis where
  namesCause : Bool
  namesDns : Bool
  namesRateLimit : Bool
  equalsEmptyResult : Bool
  tag : Nat            -- distinct per rendered sentence; the probe checks the real strings
  deriving DecidableEq, Repr

/-- The rendering, one row per branch of the Java `describe`. -/
def describe : Kind → Diagnosis
  | .nameResolution => ⟨true, true, false, false, 1⟩
  | .timeout => ⟨true, false, false, false, 2⟩
  | .connectionRefused => ⟨true, false, false, false, 3⟩
  | .noRoute => ⟨true, false, false, false, 4⟩
  | .tls => ⟨true, false, false, false, 5⟩
  | .http code =>
      if code = 429 then ⟨true, false, true, false, 6⟩
      else if code ≥ 500 then ⟨true, false, false, false, 7⟩
      else ⟨true, false, false, false, 8⟩
  | .interrupted => ⟨true, false, false, false, 9⟩
  | .otherIO => ⟨true, false, false, false, 10⟩
  | .nonIO => ⟨true, false, false, false, 11⟩
  | .noException => ⟨true, false, false, false, 12⟩

/-! ## Law 1 — THE law of item A2 -/

/--
No failure of any kind is ever rendered as the empty-result text. This is the statement the defect
violated in spirit: the old rendering was not literally "Nothing found!", it was merely
indistinguishable from it, which is why the model also carries `namesCause`.
-/
theorem no_failure_is_ever_reported_as_an_empty_result (k : Kind) :
    (describe k).equalsEmptyResult = false := by
  cases k with
  | http code =>
      by_cases h : code = 429
      · simp [describe, h]
      · by_cases h5 : code ≥ 500 <;> simp [describe, h, h5]
  | _ => rfl

/-- And every failure names its cause — there is no branch that renders a bare host or a bare code. -/
theorem every_failure_names_its_cause (k : Kind) : (describe k).namesCause = true := by
  cases k with
  | http code =>
      by_cases h : code = 429
      · simp [describe, h]
      · by_cases h5 : code ≥ 500 <;> simp [describe, h, h5]
  | _ => rfl

/-- A resolution failure, and ONLY a resolution failure, mentions DNS. -/
theorem only_a_resolution_failure_names_dns (k : Kind) :
    (describe k).namesDns = true ↔ k = .nameResolution := by
  cases k with
  | nameResolution => simp [describe]
  | http code =>
      by_cases h : code = 429
      · simp [describe, h]
      · by_cases h5 : code ≥ 500 <;> simp [describe, h, h5]
  | _ => simp [describe]

/-- 429 gets its own sentence: rate limiting is not "the request was rejected". -/
theorem rate_limiting_is_distinguished_from_a_generic_rejection :
    describe (.http 429) ≠ describe (.http 400) := by
  decide

theorem a_server_fault_is_distinguished_from_a_rejection :
    describe (.http 503) ≠ describe (.http 403) := by
  decide

/-! ## Law 2 — wrapping never hides the cause

A throwable chain is the list from outermost to innermost. `classify` returns the DEEPEST recognised
kind, which is what `rootCauseOfInterest` computes in Java.
-/

def recognised : Kind → Bool
  | .nameResolution => true
  | .timeout => true
  | .connectionRefused => true
  | .noRoute => true
  | .tls => true
  | .http _ => true
  | _ => false

/-- Deepest recognised kind in the chain, else the innermost element, else `noException`. -/
def classify : List Kind → Kind
  | [] => .noException
  | [k] => k
  | k :: rest =>
      let deeper := classify rest
      if recognised deeper then deeper
      else if recognised k then k
      else deeper

/-- THE wrapping law. An IOException carrying a resolution failure is still a resolution failure. -/
theorem wrapping_never_hides_the_cause :
    classify [.otherIO, .nameResolution] = .nameResolution := by
  decide

/-- Three levels deep, as the probe exercises it: Runtime(IOException(UnknownHost)). -/
theorem wrapping_three_deep_never_hides_the_cause :
    classify [.nonIO, .otherIO, .nameResolution] = .nameResolution := by
  decide

/--
THE DEEPEST recognised cause wins, even when the WRAPPER is recognised too.

Added after mutant D3 survived the first suite. D3 rewrote the walk so that the outermost recognised
kind wins, and every theorem here still passed — because each of them wrapped the real cause in an
UNRECOGNISED exception (`otherIO`, `nonIO`), the one case where the two orders agree. The gap was in
the spec, not in the mutant: a retry layer throwing `HttpException` around an `UnknownHostException`
is recognised at BOTH levels, and there the difference is the whole diagnosis — "the site returned
HTTP 503" instead of "cannot resolve chaturbate.com". The deepest cause is the actionable one.
-/
theorem the_deepest_recognised_cause_wins :
    classify [.http 503, .nameResolution] = .nameResolution := by
  decide

/-- Same law with two recognised network kinds, no HTTP involved. -/
theorem a_recognised_wrapper_does_not_outrank_a_recognised_cause :
    classify [.timeout, .nameResolution] = .nameResolution := by
  decide

/-- Three levels, all recognised: still the innermost. -/
theorem the_deepest_wins_through_two_recognised_wrappers :
    classify [.tls, .timeout, .nameResolution] = .nameResolution := by
  decide

/-- And the diagnosis follows: such a chain still names DNS. -/
theorem a_recognised_wrapper_never_hides_the_dns_hint :
    (describe (classify [.http 503, .nameResolution])).namesDns = true := by
  decide

/-- The naive classifier — outermost type only — is what this replaced, and it loses the cause. -/
def classifyNaive : List Kind → Kind
  | [] => .noException
  | k :: _ => k

theorem the_naive_classifier_loses_the_cause :
    classifyNaive [.otherIO, .nameResolution] ≠ .nameResolution := by
  decide

/--
A chain with NOTHING recognised falls back to the innermost cause, not to the outermost wrapper —
otherwise an unrecognised inner exception would be reported as the generic wrapper that carried it.

(An earlier version of this theorem was `chain = [] → … ∧ chain ≠ [] → True`. The second clause is
`True` and therefore proves nothing; it was decoration and is replaced.)
-/
theorem an_unrecognised_chain_falls_back_to_the_innermost :
    classify [.nonIO, .otherIO] = .otherIO := by
  decide

/-- No exception at all is its own case, never silently rendered as one of the network kinds. -/
theorem an_empty_chain_is_the_no_exception_case : classify [] = .noException := by
  decide

/-- An unwrapped failure classifies as itself: adding the walk did not change the simple case. -/
theorem an_unwrapped_failure_classifies_as_itself (k : Kind) : classify [k] = k := by
  cases k <;> rfl

/-- Whatever the chain, the diagnosis still never reads as an empty result. -/
theorem a_wrapped_failure_is_still_never_an_empty_result (chain : List Kind) :
    (describe (classify chain)).equalsEmptyResult = false :=
  no_failure_is_ever_reported_as_an_empty_result _

/-! ## Distinctness: the ten kinds the probe renders produce ten different sentences -/

/-- The list the probe compares pairwise. -/
def probedKinds : List Kind :=
  [.nameResolution, .timeout, .connectionRefused, .tls, .http 429, .http 503, .http 403,
   .otherIO, .nonIO, .noException]

#guard (probedKinds.map (fun k => (describe k).tag)).eraseDups.length == probedKinds.length
#guard probedKinds.length == 10

-- The measured case, end to end.
#guard (describe (classify [.otherIO, .nameResolution])).namesDns == true
#guard (describe (classify [.otherIO, .timeout])).namesDns == false
#guard (describe (classify [])).equalsEmptyResult == false
#guard (describe (.http 429)).namesRateLimit == true
#guard (describe (.http 500)).namesRateLimit == false
-- Every kind at once: none blank, none empty-result-shaped.
#guard probedKinds.all (fun k => (describe k).namesCause && !(describe k).equalsEmptyResult)

end Proofs.Ctbrec.FetchFailureDiagnosis
