/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Authors: ctbrec-rework
-/

/-!
# A status code is a CATEGORY, not a number

Measured 2026-08-10. `build/phase90.sh` normalised every run of >=2 digits to `N`, so

```
Couldn't check if model X is online. HTTP Response: 429      (rate limited -- MY fault, 27+ launches)
Couldn't check if model Y is online. HTTP Response: 503      (site unavailable)
```

collapsed to ONE signature `HTTP Response: N`. I had flagged that masking risk in writing when
the digit normaliser was introduced, and then **accepted the merged signature into the baseline
anyway**. The alarm was working; the baseline silenced it. The consequence was measured on the
Socio's machine: 23 x HTTP 429 went unreported while the app showed no thumbnails and started no
recordings, and the failure was misattributed twice before the status code was read.

The lesson generalises past HTTP: **a normaliser must collapse the INCIDENTAL and preserve the
DIAGNOSTIC.** A model name is incidental -- one failure mode, many instances. A status code is
diagnostic -- different codes are different failure modes with different responses (429: back
off; 503: retry; 403: credentials). Collapsing the second is not normalisation, it is data loss.

`build/phase90.sh` now maps codes to names BEFORE the digit pass, so no digit mask can reach
them. This module proves that mapping keeps distinct categories distinct.
-/

namespace CtbrecSpec.HttpStatusSignature

/-- The categories `phase90.sh` maps, plus `other` for a code with no name yet. -/
inductive Status where
  | rateLimited    -- 429: back off. NEVER let this hide.
  | unavailable    -- 503: transient, retry
  | badGateway     -- 502
  | serverError    -- 500
  | clientError    -- 40x other than 429
  | other          -- unmapped; still normalised to a digit mask
  deriving DecidableEq, Repr

/-- The rendered token that lands in a signature. -/
def render : Status → String
  | .rateLimited => "RATE_LIMITED"
  | .unavailable => "UNAVAILABLE"
  | .badGateway  => "BAD_GATEWAY"
  | .serverError => "SERVER_ERROR"
  | .clientError => "CLIENT_ERR_40x"
  | .other       => "N"

/-- The OLD normaliser: every code became the digit mask. -/
def renderOld (_ : Status) : String := "N"

#guard render .rateLimited = "RATE_LIMITED"
#guard render .unavailable = "UNAVAILABLE"
#guard render .rateLimited ≠ render .unavailable
#guard renderOld .rateLimited = renderOld .unavailable   -- the defect, reproduced

/-- THE DEFECT, stated as a theorem: the old normaliser could not tell a rate limit from an
outage. This is why 23 x HTTP 429 never reached the Socio. -/
theorem old_normaliser_hid_the_rate_limit :
    renderOld .rateLimited = renderOld .unavailable := by rfl

/-- THE REPAIR. Every named category renders distinctly from every other named category. -/
theorem named_categories_stay_distinct {a b : Status}
    (ha : a ≠ .other) (hb : b ≠ .other) (hab : a ≠ b) : render a ≠ render b := by
  cases a <;> cases b <;> simp_all [render] <;> decide

/-- The one that mattered on the day: a rate limit is never confused with an outage. -/
theorem rate_limit_is_not_an_outage : render .rateLimited ≠ render .unavailable := by decide

/-- NEGATIVE CONTROL. `other` still collapses to the digit mask, so `render` is NOT injective
and the theorem above is a real constraint rather than a tautology about distinct constructors.
An unmapped code CAN still hide -- stated honestly instead of pretending the fix is total. -/
theorem unmapped_codes_still_collapse : render .other = renderOld .rateLimited := by rfl

/-- A signature carries the site, the message shape and the status. -/
structure Sig where
  site : String
  message : String
  status : Status
  deriving DecidableEq, Repr

/-- Normalisation keeps the status category; only the instance data is collapsed. -/
def normalize (s : Sig) : String := s.site ++ "|" ++ s.message ++ " " ++ render s.status

/-- Two failures differing ONLY in status category remain two signatures. This is the property
`phase90.sh` must have for the alarm to be able to report a rate limit at all. -/
theorem status_alone_separates_signatures {s : Sig} {t : Status}
    (h : s.status ≠ t) (hs : s.status ≠ .other) (ht : t ≠ .other) :
    normalize s ≠ normalize { s with status := t } := by
  simp only [normalize]
  intro hEq
  exact named_categories_stay_distinct hs ht h (by simpa using hEq)

-- The exact pair from the incident: same site, same message, different code.
def measured429 : Sig :=
  { site := "OnlineMonitor.java:N",
    message := "Couldn't check if model MODEL is online. HTTP Response:",
    status := .rateLimited }

def measured503 : Sig := { measured429 with status := .unavailable }

#guard normalize measured429 ≠ normalize measured503
#guard (normalize measured429).endsWith "RATE_LIMITED"

/-- The incident, settled: the two lines the Socio's log actually contained are two signatures
under the repaired normaliser, and were one under the old one. -/
theorem the_incident_is_now_two_signatures :
    normalize measured429 ≠ normalize measured503 := by decide

end CtbrecSpec.HttpStatusSignature
