/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: the startup DNS preflight's ACCOUNTING (checklist item A3).

MEASURED 2026-08-03: the model list went blank because chaturbate.com would not resolve, and the
only evidence was eleven UnknownHostException stack traces two minutes into a 17 000-line log.
Nothing at startup distinguished "the app is broken" from "this machine cannot resolve anything" --
a live distinction here, since a self-protected security product rewrites the adapter's DNS to a
sentinel address and reverted a -ResetServerAddresses within three seconds (measured 2026-08-13).

Mirrors src/common/ctbrec/io/DnsPreflight.java. Executed against the REAL resolver by
tools/probe/DnsPreflightProbe.java, which measured 3/3 real hosts resolved and a negative control
("...invalid") correctly reported as FAILED with a reason -- the alarm can fire.

The properties worth proving are the ones that make the summary line trustworthy:

  * a host is never counted as both resolved and failed,
  * the counts always add up to the number of hosts checked,
  * one failure never suppresses the successes beside it (the log must show 2/3, not nothing),
  * duplicates never inflate the totals,
  * the summary is emitted whether or not anything failed -- a preflight that is silent when healthy
    cannot be distinguished from one that never ran.

NOT PROVED: that any particular host resolves. That is the network's business, measured by the probe
and by the app at runtime; a theorem claiming chaturbate.com resolves would be false the moment the
Socio's resolver breaks, which is precisely the event this instrument exists to report.
-/

namespace Proofs.Ctbrec.DnsPreflight

/-- One host's outcome. `addresses = 0` exactly when it did not resolve. -/
structure Result where
  host : String
  resolved : Bool
  addresses : Nat
  hasFailureReason : Bool
  deriving DecidableEq, Repr

/-- The invariant every row must satisfy, as the Java record's construction guarantees. -/
def wellFormed (r : Result) : Bool :=
  (r.resolved && r.addresses > 0 && !r.hasFailureReason)
    || (!r.resolved && r.addresses == 0 && r.hasFailureReason)

/-- Resolution modelled as an oracle: Lean cannot resolve a name, and must not pretend to. -/
def rowFor (oracle : String → Option Nat) (host : String) : Result :=
  match oracle host with
  | some n => if n > 0 then ⟨host, true, n, false⟩ else ⟨host, false, 0, true⟩
  | none => ⟨host, false, 0, true⟩

/-- Deduplicate preserving order, as the Java `LinkedHashSet` does. -/
def distinctHosts : List String → List String
  | [] => []
  | h :: t => if t.contains h then distinctHosts t else h :: distinctHosts t

def resolveAll (oracle : String → Option Nat) (hosts : List String) : List Result :=
  (distinctHosts hosts).map (rowFor oracle)

def resolvedCount (rs : List Result) : Nat := (rs.filter (·.resolved)).length
def failedCount (rs : List Result) : Nat := (rs.filter (fun r => !r.resolved)).length

/-! ## Law 1 — a host is never both resolved and failed -/

theorem every_row_is_well_formed (oracle : String → Option Nat) (host : String) :
    wellFormed (rowFor oracle host) = true := by
  unfold rowFor
  cases h : oracle host with
  | none => simp [wellFormed]
  | some n =>
      by_cases hn : n > 0
      · simp [wellFormed, hn]
      · simp [wellFormed, hn]

theorem no_row_claims_both (oracle : String → Option Nat) (host : String) :
    ¬((rowFor oracle host).resolved = true ∧ (rowFor oracle host).hasFailureReason = true) := by
  unfold rowFor
  cases h : oracle host with
  | none => simp
  | some n =>
      by_cases hn : n > 0
      · simp [hn]
      · simp [hn]

/-- A resolved host always has at least one address; "resolved with 0 addresses" cannot be built. -/
theorem resolved_implies_an_address (oracle : String → Option Nat) (host : String)
    (h : (rowFor oracle host).resolved = true) : 0 < (rowFor oracle host).addresses := by
  unfold rowFor at h ⊢
  cases ho : oracle host with
  | none => simp [ho] at h
  | some n =>
      simp only [ho] at h ⊢
      by_cases hn : n > 0
      · simpa [hn] using hn
      · simp [hn] at h

/-! ## Law 2 — the counts add up, always -/

theorem the_counts_partition_the_rows (rs : List Result) :
    resolvedCount rs + failedCount rs = rs.length := by
  induction rs with
  | nil => rfl
  | cons r rest ih =>
      cases hr : r.resolved with
      | true => simp [resolvedCount, failedCount, hr] at ih ⊢; omega
      | false => simp [resolvedCount, failedCount, hr] at ih ⊢; omega

/-- One row per distinct host: the summary's denominator is honest. -/
theorem one_row_per_distinct_host (oracle : String → Option Nat) (hosts : List String) :
    (resolveAll oracle hosts).length = (distinctHosts hosts).length := by
  simp [resolveAll]

/-- Duplicates never inflate the totals — the probe's five-entry / one-host case. -/
theorem duplicates_do_not_inflate_the_count (oracle : String → Option Nat) (h : String) :
    (resolveAll oracle [h, h, h]).length = 1 := by
  simp [resolveAll, distinctHosts]

/-! ## Law 3 — a failure does not suppress the successes

This is the law the naive implementation breaks by returning early, or by logging only the first
failure and abandoning the rest of the list.
-/

/-- Every host still gets a row even when an earlier one failed. -/
theorem a_failure_does_not_stop_the_sweep (oracle : String → Option Nat) (a b : String)
    (hab : a ≠ b) : (resolveAll oracle [a, b]).length = 2 := by
  simp [resolveAll, distinctHosts, hab]

/-- With one good and one bad host, the good one is still counted. -/
theorem a_success_survives_a_neighbouring_failure :
    resolvedCount (resolveAll (fun h => if h = "good" then some 2 else none) ["good", "bad"]) = 1 := by
  decide

/-- And the failure is still counted too: 1 of 2, never 2 of 2 nor 0 of 2. -/
theorem the_failure_is_also_counted :
    failedCount (resolveAll (fun h => if h = "good" then some 2 else none) ["good", "bad"]) = 1 := by
  decide

/-! ## Law 4 — the summary is emitted either way

`summaryEmitted` models the Java: the INFO line is unconditional, the WARN lines are per failure.
-/

def summaryEmitted (_rs : List Result) : Bool := true
def warnCount (rs : List Result) : Nat := failedCount rs

/-- A HEALTHY preflight still says so. A silent success is indistinguishable from never running. -/
theorem a_healthy_preflight_still_reports :
    summaryEmitted (resolveAll (fun _ => some 1) ["a", "b"]) = true := rfl

theorem the_summary_is_always_emitted (rs : List Result) : summaryEmitted rs = true := rfl

/-- Exactly one WARN per failed host: no failure is silent, and none is reported twice. -/
theorem one_warning_per_failure (rs : List Result) : warnCount rs = failedCount rs := rfl

/-- With everything healthy there are no WARNs at all: a quiet log means quiet, not broken. -/
theorem a_healthy_preflight_warns_about_nothing :
    warnCount (resolveAll (fun _ => some 1) ["a", "b"]) = 0 := by
  decide

/-! ## The measured runs, as `#guard` -/

-- The probe's real run: 3 hosts, all resolved (chaturbate 4 addrs, camsoda 1, stripchat 4).
#guard resolvedCount (resolveAll (fun h =>
    if h = "chaturbate.com" then some 4
    else if h = "www.camsoda.com" then some 1
    else if h = "stripchat.com" then some 4 else none)
  ["chaturbate.com", "www.camsoda.com", "stripchat.com"]) == 3
-- The probe's negative control: the .invalid host.
#guard failedCount (resolveAll (fun _ => none) ["this-host-cannot-exist-ctbrec-probe.invalid"]) == 1
-- The mixed run the probe measured as 2/3.
#guard resolvedCount (resolveAll (fun h =>
    if h = "bad.invalid" then none else some 2)
  ["chaturbate.com", "bad.invalid", "www.camsoda.com"]) == 2
#guard failedCount (resolveAll (fun h =>
    if h = "bad.invalid" then none else some 2)
  ["chaturbate.com", "bad.invalid", "www.camsoda.com"]) == 1
-- The probe's duplicate case: 5 entries (2 of them blank/null in Java), 1 distinct host.
#guard (resolveAll (fun _ => some 4) ["chaturbate.com", "chaturbate.com", "chaturbate.com"]).length == 1
-- Every row well formed on every one of those runs.
#guard (resolveAll (fun h => if h = "bad.invalid" then none else some 2)
  ["chaturbate.com", "bad.invalid", "www.camsoda.com"]).all wellFormed

end Proofs.Ctbrec.DnsPreflight
