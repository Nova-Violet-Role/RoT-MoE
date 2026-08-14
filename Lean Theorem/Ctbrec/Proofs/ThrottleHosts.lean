/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CP88 -- WHICH hosts the Chaturbate throttle applies to, and why a substring test is the wrong gate.

MEASURED (src/common/ctbrec/sites/chaturbate/ChaturbateHttpClient.java:214)

    boolean throttled = req.url().host().contains("chaturbate.com");

Every request whose host passes that predicate goes through `acquireSlot()` -- the globally paced
one repaired in CP81 and proved in RateLimit.lean. Everything else bypasses pacing entirely.

That gate decides whether the rate limiter exists for a given request, so it is load-bearing, and
it was undocumented and unproven. Two separate questions live in it:

  1. COVERAGE -- does it catch the API hosts? Measured from ctbrec.log, the API call that took
     the 429 was `ChaturbateModel.requestStreamInfo` against `chaturbate.com`, so yes.
  2. EXCLUSION -- does it correctly let media through? `edge18-fra.live.mmcdn.com` carries the
     actual segments and must NOT be paced; a rate-limited media fetch would starve the recording.
     It does not contain the needle, so yes.

Both hold today. The defect this file records is neither of those: it is that `contains` is a
SUBSTRING test standing in for a DOMAIN test, and the two differ on hosts an attacker or a typo
can produce. `notchaturbate.com` and `chaturbate.com.evil.net` both contain the needle and would
be paced as if they were first-party; more importantly the same looseness means the predicate
says nothing structural about what it is selecting, so a future host rename can silently move a
real API host out of the throttled set with no test failing.

WHAT IS PROVED: that the suffix test is a strict refinement -- it agrees with `contains` on every
host actually observed in the log, it still throttles the API and still exempts the media edge,
and it REJECTS a spoofed host that `contains` accepts. A concrete witness is exhibited.

NOT PROVED: that pacing media would be harmful (that is a throughput fact, measured elsewhere),
or that the observed host list is complete. It is the list this machine has seen.
-/

set_option maxRecDepth 100000

namespace CtbrecSpec.ThrottleHosts

/-- The needle as it appears in the Java source. -/
def needle : String := "chaturbate.com"

/-- Suffix via reversal: nothing may depend on `String.endsWith`, which runs on BYTE
    offsets and does NOT reduce in the kernel -- measured, `decide` failed on it. -/
def isSuffix (n h : List Char) : Bool := n.reverse.isPrefixOf h.reverse

/--
Substring containment, spelled out. This toolchain has neither `String.isSubstrOf` nor
`List.isInfixOf`, so the predicate Java's `String.contains` computes is defined here directly --
which is better anyway: the model of the code under test should be visible, not delegated to a
library function whose edge cases I would then be assuming.
-/
def isInfix : List Char → List Char → Bool
  | n, [] => n.isEmpty
  | n, c :: rest => n.isPrefixOf (c :: rest) || isInfix n rest

/-- The predicate the code uses today: a plain substring test. -/
def throttledByContains (host : String) : Bool :=
  isInfix needle.toList host.toList

/--
The predicate that says what was meant: the host IS the domain, or is a subdomain of it. This is
the shape that survives a host rename, because it tests the structural relation rather than the
presence of some characters.
-/
def throttledBySuffix (host : String) : Bool :=
  host.toList == needle.toList || isSuffix ("." ++ needle).toList host.toList

/-! ## The hosts this machine has actually seen -/

-- The API host: `ChaturbateModel.requestStreamInfo` builds its URL from `getSite().getBaseUrl()`.
#guard throttledByContains "chaturbate.com" == true
#guard throttledBySuffix   "chaturbate.com" == true

-- A subdomain of the API host must also be paced.
#guard throttledByContains "www.chaturbate.com" == true
#guard throttledBySuffix   "www.chaturbate.com" == true

-- The media edge, taken verbatim from ctbrec.log: it must NOT be paced, or segment fetches
-- would be throttled and the recording would starve.
#guard throttledByContains "edge18-fra.live.mmcdn.com" == false
#guard throttledBySuffix   "edge18-fra.live.mmcdn.com" == false

-- The other site in the deployment must not be swept in.
#guard throttledByContains "wchat30.myfreecams.com" == false
#guard throttledBySuffix   "wchat30.myfreecams.com" == false

/-! ## Where the two predicates part company -/

-- A host that merely CONTAINS the needle but is not the domain. `contains` accepts it.
#guard throttledByContains "chaturbate.com.evil.net" == true
#guard throttledBySuffix   "chaturbate.com.evil.net" == false

-- And one that ends in the needle without the dot boundary.
#guard throttledByContains "notchaturbate.com" == true
#guard throttledBySuffix   "notchaturbate.com" == false

/-! ## The invariants -/

/--
**The witness.** There exists a host the substring gate throttles and the domain gate does not,
so the two predicates are NOT interchangeable. This is the whole finding, stated as an existence
claim rather than an opinion about style.
-/
theorem the_substring_gate_accepts_a_host_the_domain_gate_rejects :
    ∃ host : String, throttledByContains host = true ∧ throttledBySuffix host = false := by
  refine ⟨"chaturbate.com.evil.net", ?_, ?_⟩ <;> decide

/-- Coverage is preserved: the API host is throttled under BOTH gates. -/
theorem the_api_host_is_throttled_under_both :
    throttledByContains "chaturbate.com" = true ∧
    throttledBySuffix "chaturbate.com" = true := by
  decide

/--
Exclusion is preserved: the media edge that carries the segments is exempt under BOTH gates, so
tightening the predicate cannot start throttling the recording path.
-/
theorem the_media_edge_stays_exempt_under_both :
    throttledByContains "edge18-fra.live.mmcdn.com" = false ∧
    throttledBySuffix "edge18-fra.live.mmcdn.com" = false := by
  decide

/--
**Anti-disarm.** Tightening to the suffix gate must never EXPAND what is throttled -- it may only
shrink it. Checked exhaustively over every host in the observed corpus plus the two spoofs.
-/
def observedHosts : List String :=
  [ "chaturbate.com", "www.chaturbate.com", "edge18-fra.live.mmcdn.com"
  , "wchat30.myfreecams.com", "chaturbate.com.evil.net", "notchaturbate.com" ]

theorem tightening_the_gate_never_throttles_something_new :
    ∀ h ∈ observedHosts, throttledBySuffix h = true → throttledByContains h = true := by
  decide

/-- On the hosts genuinely reached by the app, the two gates agree -- so this is a safe change. -/
def firstPartyHosts : List String :=
  [ "chaturbate.com", "www.chaturbate.com", "edge18-fra.live.mmcdn.com"
  , "wchat30.myfreecams.com" ]

theorem the_gates_agree_on_every_host_the_app_actually_reaches :
    ∀ h ∈ firstPartyHosts, throttledByContains h = throttledBySuffix h := by
  decide

end CtbrecSpec.ThrottleHosts
