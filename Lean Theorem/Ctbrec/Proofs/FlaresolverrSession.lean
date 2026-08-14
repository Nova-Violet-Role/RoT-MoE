/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the FlareSolverr session state machine

Subject: `src/common/ctbrec/io/FlaresolverrClient.java`.

## Why this file is not dead code

`FlaresolverrClient` is **live**: `HttpClient.java:83` constructs it from the settings and
`HttpClient.java:219` calls `getCookies(...)` on every 403 to refresh cookies through the proxy.
Only `createSession`, `destroySession` and `getSessionName` had no caller — the checkpoint-52
ledger's `UNCLASSIFIED | network I/O`.

## The two findings

Both are the same mistake made in opposite directions: **the local record of the session is moved
before the remote call that is supposed to justify it, and never moved back if that call fails.**

`createSession` assigns `this.sessionName = name` and only then calls `makeApiCall`. When the call
fails — the proxy is down, which is the ordinary case for a service on `localhost:8191` that the
user may not be running — the client keeps the name. Every later `createSession` then throws
*"Cannot start new session because another one is already started"*, forever, and `getCookies`
attaches `session: name` to a session the proxy never created. The client is **wedged** with no
recovery short of restarting the application: `the_shipped_client_wedges_on_a_failed_create`.

`destroySession` sets `this.sessionName = ""` before the call, so a failed destroy leaves the
proxy holding a session the client has forgotten and can no longer address —
`the_shipped_client_orphans_the_remote_session_on_a_failed_destroy`. It also **ignores its own
`name` argument** when deciding what to clear: `destroySession("anything")` clears the active
session locally while asking the proxy to destroy a different one
(`the_repaired_destroy_refuses_a_name_that_is_not_active`).

## The shape of the repair

Move the local write to the side of the outcome that earns it: reserve before the call so two
threads cannot both start a session, roll the reservation back if the call fails, and keep the
session on a failed destroy so it can be retried. The load-bearing theorem is
`every_repaired_transition_preserves_agreement` — quantified over *every* client state, *every*
name and *both* outcomes, not over the states a test happens to visit.
-/

namespace CtbrecSpec

/-- Whether the call to the FlareSolverr proxy succeeded. `failed` covers both a transport error
and a non-success response; the client cannot distinguish them and must not care. -/
inductive CallOutcome where
  | ok
  | failed
  deriving DecidableEq, Repr

/-- What the client believes (`localName`) beside what the proxy actually holds (`remoteName`).
The Java keeps only the first; the second is the reality it is supposed to track. -/
structure Client where
  localName : Option String
  remoteName : Option String
  deriving DecidableEq, Repr

/-- The result of an operation: `refused` is a thrown `IOException` that changed nothing. -/
inductive Step where
  | refused
  | done (c : Client)
  deriving DecidableEq, Repr

/-- A client with no session, local or remote. -/
def freshClient : Client := ⟨none, none⟩

/-- The client's view agrees with the proxy's. This is the property the whole file is about. -/
def agrees (c : Client) : Prop := c.localName = c.remoteName

instance (c : Client) : Decidable (agrees c) := by unfold agrees; infer_instance

/-- `getCookies` attaches `session: <name>` whenever the client holds one. When the proxy has no
such session that request is made against a session that does not exist. -/
def sendsAStaleSession (c : Client) : Bool := c.localName.isSome && c.remoteName.isNone

/-! ### As shipped -/

/-- `createSession` as shipped: the name is recorded before the call and never withdrawn. -/
def shippedCreate (c : Client) (name : String) (o : CallOutcome) : Step :=
  if c.localName.isSome then .refused
  else .done ⟨some name, if o = .ok then some name else c.remoteName⟩

/-- `destroySession` as shipped: clears whatever is active, before the call, ignoring `name`. -/
def shippedDestroy (c : Client) (_name : String) (o : CallOutcome) : Step :=
  if c.localName.isNone then .refused
  else .done ⟨none, if o = .ok then none else c.remoteName⟩

/-! ### Repaired -/

/-- Reserve the name first so two threads cannot both start a session, then withdraw the
reservation if the call failed. -/
def repairedCreate (c : Client) (name : String) (o : CallOutcome) : Step :=
  if c.localName.isSome then .refused
  else match o with
    | .ok => .done ⟨some name, some name⟩
    | .failed => .done ⟨none, c.remoteName⟩

/-- Destroy only the session that is actually active, and only give it up once the proxy has
confirmed. A failed destroy leaves the session in place, which is what makes a retry possible. -/
def repairedDestroy (c : Client) (name : String) (o : CallOutcome) : Step :=
  if c.localName ≠ some name then .refused
  else match o with
    | .ok => .done ⟨none, none⟩
    | .failed => .done c

/-! ### What the shipped code does -/

/-- **A failed create wedges the client.** The name is kept although the proxy has no such
session, so the state no longer agrees with reality, `getCookies` sends a session the proxy never
made, and — the part with no recovery — *every* later `createSession` is refused, whatever name it
is given and however the network behaves afterwards. -/
theorem the_shipped_client_wedges_on_a_failed_create (name : String) :
    ∃ c, shippedCreate freshClient name .failed = .done c ∧
      ¬ agrees c ∧ sendsAStaleSession c = true ∧
      ∀ (n2 : String) (o2 : CallOutcome), shippedCreate c n2 o2 = .refused := by
  refine ⟨⟨some name, none⟩, by simp [shippedCreate, freshClient],
    by simp [agrees], by simp [sendsAStaleSession], ?_⟩
  intro n2 o2
  simp [shippedCreate]

/-- **A failed destroy orphans the session on the proxy.** The client has forgotten the name, so
the proxy holds a session nobody will ever destroy — and the client cannot even try, because
`destroySession` now refuses. -/
theorem the_shipped_client_orphans_the_remote_session_on_a_failed_destroy (name : String) :
    ∃ c, shippedDestroy ⟨some name, some name⟩ name .failed = .done c ∧
      ¬ agrees c ∧ c.remoteName = some name ∧
      ∀ (n2 : String) (o2 : CallOutcome), shippedDestroy c n2 o2 = .refused := by
  refine ⟨⟨none, some name⟩, by simp [shippedDestroy], by simp [agrees], by rfl, ?_⟩
  intro n2 o2
  simp [shippedDestroy]

/-- **The shipped destroy clears the wrong session.** Called with a name that is not the active
one it still gives up the local record — while asking the proxy to destroy something else. -/
theorem the_shipped_destroy_ignores_its_argument (active other : String) :
    shippedDestroy ⟨some active, some active⟩ other .ok = .done ⟨none, none⟩ := by
  simp [shippedDestroy]

/-! ### What the repair does -/

/-- **The load-bearing theorem.** Every repaired transition, from *every* state that agreed,
under *every* name and *both* outcomes, either refuses and changes nothing or lands in a state
that still agrees. Quantified over the whole state space rather than the states a test visits. -/
theorem every_repaired_transition_preserves_agreement (c : Client) (name : String) (o : CallOutcome)
    (h : agrees c) :
    (repairedCreate c name o = .refused ∨ ∃ c', repairedCreate c name o = .done c' ∧ agrees c') ∧
    (repairedDestroy c name o = .refused ∨ ∃ c', repairedDestroy c name o = .done c' ∧ agrees c') := by
  constructor
  · by_cases hs : c.localName.isSome
    · exact Or.inl (by simp [repairedCreate, hs])
    · cases o with
      | ok => exact Or.inr ⟨⟨some name, some name⟩, by simp [repairedCreate, hs], rfl⟩
      | failed =>
          refine Or.inr ⟨⟨none, c.remoteName⟩, by simp [repairedCreate, hs], ?_⟩
          have hnone : c.localName = none := Option.not_isSome_iff_eq_none.mp hs
          show (none : Option String) = c.remoteName
          exact hnone ▸ h
  · by_cases hn : c.localName ≠ some name
    · exact Or.inl (by simp [repairedDestroy, hn])
    · cases o with
      | ok => exact Or.inr ⟨⟨none, none⟩, by simp [repairedDestroy, hn], rfl⟩
      | failed => exact Or.inr ⟨c, by simp [repairedDestroy, hn], h⟩

/-- **A failed create is recoverable.** The reservation is withdrawn, so the very next attempt is
allowed to proceed — the exact opposite of the shipped wedge. -/
theorem the_repaired_client_recovers_from_a_failed_create (name n2 : String) :
    repairedCreate freshClient name .failed = .done freshClient ∧
    repairedCreate freshClient n2 .ok = .done ⟨some n2, some n2⟩ := by
  constructor <;> simp [repairedCreate, freshClient]

/-- **A failed destroy stays retryable.** The session is kept, so a later attempt with the same
name is accepted rather than refused. -/
theorem the_repaired_client_keeps_a_failed_destroy_retryable (name : String) :
    repairedDestroy ⟨some name, some name⟩ name .failed = .done ⟨some name, some name⟩ ∧
    repairedDestroy ⟨some name, some name⟩ name .ok = .done freshClient := by
  constructor <;> simp [repairedDestroy, freshClient]

/-- **The repaired destroy refuses a name that is not the active session**, instead of silently
giving up the one that is. -/
theorem the_repaired_destroy_refuses_a_name_that_is_not_active (active other : String)
    (h : other ≠ active) :
    repairedDestroy ⟨some active, some active⟩ other .ok = .refused := by
  simp [repairedDestroy, Ne.symm h]

/-- **The repaired client never sends a session the proxy does not have**, from any state that
agreed. This is the property `getCookies` depends on and the shipped code broke. -/
theorem the_repaired_client_never_sends_a_stale_session (c : Client) (name : String) (o : CallOutcome)
    (h : agrees c) (c' : Client)
    (hstep : repairedCreate c name o = .done c' ∨ repairedDestroy c name o = .done c') :
    sendsAStaleSession c' = false := by
  have hc := every_repaired_transition_preserves_agreement c name o h
  have hag : agrees c' := by
    cases hstep with
    | inl hl =>
        rcases hc.left with hr | ⟨c'', he, hag⟩
        · rw [hr] at hl; exact absurd hl (by simp)
        · rw [he] at hl; cases Step.done.inj hl; exact hag
    | inr hr =>
        rcases hc.right with hrf | ⟨c'', he, hag⟩
        · rw [hrf] at hr; exact absurd hr (by simp)
        · rw [he] at hr; cases Step.done.inj hr; exact hag
  unfold agrees at hag
  cases hl : c'.localName with
  | none => simp [sendsAStaleSession, hl]
  | some v => simp [sendsAStaleSession, hl, ← hag, hl]

/-- A successful round trip returns exactly to the start — no residue on either side. -/
theorem a_successful_round_trip_returns_to_the_start (name : String) :
    repairedCreate freshClient name .ok = .done ⟨some name, some name⟩ ∧
    repairedDestroy ⟨some name, some name⟩ name .ok = .done freshClient := by
  constructor <;> simp [repairedCreate, repairedDestroy, freshClient]

/-! ### Two threads

`HttpClient` is shared across recording threads, and the shipped check-then-assign on a
non-volatile field is not atomic. The repair reserves with a compare-and-set, whose defining
property is that exactly one of two racing callers wins. -/

/-- A compare-and-set reservation: succeeds only from the unreserved state. -/
def reserve (c : Client) (name : String) : Bool × Client :=
  if c.localName.isSome then (false, c) else (true, ⟨some name, c.remoteName⟩)

/-- **Two racing creates cannot both win.** Whichever runs second sees a reserved client and is
refused, so at most one session is ever started. -/
theorem two_creates_cannot_both_win (c : Client) (a b : String) :
    ((reserve c a).1 && (reserve (reserve c a).2 b).1) = false := by
  by_cases h : c.localName.isSome <;> simp [reserve, h]

/-- …and a reservation that wins is genuinely held: the loser's state is the winner's, untouched. -/
theorem the_loser_does_not_disturb_the_winner (c : Client) (a b : String)
    (h : c.localName = none) :
    (reserve (reserve c a).2 b).2 = (reserve c a).2 := by
  simp [reserve, h]

#guard shippedCreate freshClient "s" .failed == .done ⟨some "s", none⟩
#guard shippedCreate ⟨some "s", none⟩ "t" .ok == .refused
#guard sendsAStaleSession ⟨some "s", none⟩ == true
#guard repairedCreate freshClient "s" .failed == .done freshClient
#guard repairedCreate freshClient "s" .ok == .done ⟨some "s", some "s"⟩
#guard repairedDestroy ⟨some "s", some "s"⟩ "s" .failed == .done ⟨some "s", some "s"⟩
#guard repairedDestroy ⟨some "s", some "s"⟩ "other" .ok == .refused
#guard shippedDestroy ⟨some "s", some "s"⟩ "other" .ok == .done freshClient
#guard sendsAStaleSession freshClient == false
#guard (reserve freshClient "a").1 == true
#guard (reserve (reserve freshClient "a").2 "b").1 == false

end CtbrecSpec
