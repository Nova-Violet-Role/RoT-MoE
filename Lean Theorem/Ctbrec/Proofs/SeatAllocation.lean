/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Seat allocation -- "Max sessions per identity", the fourth marker in Advanced / Devtools.

MEASURED CONTEXT (src/app/ctbrec/ui/settings/SettingsTab.java:531-546, group "Networking"):
  Playlist request timeout (ms)  -> Settings.java:123  playlistRequestTimeout = 2500
  Max requests                   -> Settings.java:124  httpClientMaxRequests
  Max requests per host          -> Settings.java:125  httpClientMaxRequestsPerHost = 16

THE PREMISE THAT DOES NOT HOLD, stated first because it changed the design. The request was
a room-wide cap: 4k users in a Discord room sharing one seat budget. Each user runs their
OWN CTBrecEVO.exe on their OWN machine, and this tree contains no multi-user server -- only
DocServer and ChaturbateLlhlsMediaServer. A number in one client's settings is invisible to
every other client, so a room-wide cap is unenforceable from here. Building it would have
produced a setting that looks like a guarantee and constrains nothing: the exact overclaim
this project forbids.

THE PART THAT IS REAL AND IS BUILT. The CAUSE identified was correct and is currently
unguarded: one logged-in identity opening the same connection repeatedly earns 404/429.
`httpClientMaxRequestsPerHost` limits per HOST and knows nothing about IDENTITY -- one
account recording twenty models hammers a single host under one session, and two different
accounts on that host share the same 16. A limit keyed on IDENTITY is therefore new
coverage, is enforceable inside one process, and is what actually prevents the self-inflicted
429.

THE SEAT MODEL, in the requester's own terms. A credentialed identity holds a NAMED seat --
it is theirs while held and cannot be taken. Anonymous users (no credentials, "greyed out")
share a single anonymous pool, because they are indistinguishable and must not be able to
starve a logged-in user by numbers alone. When the budget is exhausted the allocator REFUSES
rather than queueing without bound: a refusal is visible and retryable, an unbounded queue
is the congestion it was meant to prevent.

NOT MODELLED, and named so nobody infers it: wall-clock timing, real HTTP behaviour, whether
a site actually returns 429 at any given rate, and fairness over time. Those are empirical
and are measured by the checker, never asserted here.
-/

namespace CtbrecSpec.SeatAllocation

/-- Who is asking for a seat. -/
inductive Identity where
  /-- a logged-in account, distinguished by its own index -/
  | credentialed (id : Nat)
  /-- no credentials -- the "greyed out" user. All anonymous requests are one identity. -/
  | anonymous
deriving DecidableEq, Repr

/-- The allocator's state: which identities currently hold a seat, and the admin's cap. -/
structure Seats where
  /-- distinct identities currently holding a seat -/
  held : List Identity
  /-- the admin's configured maximum. 0 means unlimited, matching how the sibling
      networking settings already read a non-positive value. -/
  capacity : Nat
deriving Repr

/-- Unlimited is expressed as 0, consistent with the three existing markers. -/
def unlimited (s : Seats) : Bool := s.capacity == 0

/-- Seats in use.

    No deduplication is needed here, and that is a property of the allocator rather than a
    shortcut: `acquire` adds an identity only when it is not already seated, so `held` never
    contains a duplicate to begin with. Anonymous therefore collapses to one entry however
    many anonymous users arrive -- which is what makes the pool a pool.

    The first version deduplicated inside `inUse` and needed a lemma about
    `(a :: l).eraseDups.length` that core does not provide. Making the invariant hold at the
    only place that can break it is both simpler and closer to what the Java will do. -/
def inUse (s : Seats) : Nat := s.held.length

/-- Is this identity already seated? A held seat is re-entrant: the same identity asking
    twice must not consume a second seat, which is the whole point of keying on identity. -/
def seated (s : Seats) (i : Identity) : Bool := s.held.contains i

/-- Can `i` take a seat right now? -/
def canAcquire (s : Seats) (i : Identity) : Bool :=
  unlimited s || seated s i || inUse s < s.capacity

/-- Acquire. Re-entrant, and a refusal leaves the state untouched. -/
def acquire (s : Seats) (i : Identity) : Seats :=
  if canAcquire s i && !seated s i then { s with held := i :: s.held } else s

/-- Release. Removes every copy so the operation is idempotent. -/
def release (s : Seats) (i : Identity) : Seats :=
  { s with held := s.held.filter (· != i) }

/-! ## Corpus -- concrete states the checker also exercises -/

def empty4 : Seats := ⟨[], 4⟩
def full4  : Seats := ⟨[Identity.credentialed 1, Identity.credentialed 2,
                        Identity.credentialed 3, Identity.anonymous], 4⟩
def uncapped : Seats := ⟨[Identity.credentialed 1], 0⟩

#guard inUse empty4 == 0
#guard inUse full4 == 4
#guard canAcquire empty4 Identity.anonymous == true
#guard canAcquire full4 (Identity.credentialed 9) == false
-- the pool: a second anonymous user takes NO extra seat
#guard inUse (acquire ⟨[Identity.anonymous], 4⟩ Identity.anonymous) == 1
-- an already-seated identity is always admitted, even at capacity
#guard canAcquire full4 Identity.anonymous == true
#guard canAcquire full4 (Identity.credentialed 2) == true
-- 0 means unlimited
#guard canAcquire uncapped (Identity.credentialed 77) == true
#guard inUse (release full4 Identity.anonymous) == 3

/--
**THE CAP IS NEVER EXCEEDED.** For any state within its cap, acquiring cannot push usage
past the cap. This is the property the whole setting exists for; without it the number in
the settings window is decoration.

Stated over ALL states and identities rather than the corpus rows, so it still holds when
the default capacity changes -- a theorem pinned to `4` would expire the first time an admin
picked a different number.
-/
theorem the_cap_is_never_exceeded (s : Seats) (i : Identity)
    (hcap : s.capacity > 0) (hok : inUse s ≤ s.capacity) :
    inUse (acquire s i) ≤ s.capacity := by
  unfold acquire
  split
  · next h =>
    simp only [Bool.and_eq_true, Bool.not_eq_true', canAcquire, unlimited, Bool.or_eq_true,
      beq_iff_eq, decide_eq_true_eq] at h
    obtain ⟨hc, hns⟩ := h
    rcases hc with (hz | hs) | hlt
    · omega                                   -- capacity 0 contradicts hcap
    · rw [hs] at hns; simp at hns             -- already seated contradicts !seated
    · simp only [inUse, List.length_cons] at *; omega
  · exact hok

/--
**A SEATED IDENTITY IS NEVER TURNED AWAY.** Re-entrancy, and it is the difference between a
seat allocator and a request throttle: an identity that already holds a seat must be admitted
even when the allocator is full, or a logged-in user gets locked out of their own session by
their own second request. That is the failure the setting was requested to prevent.
-/
theorem a_seated_identity_is_never_refused (s : Seats) (i : Identity)
    (h : seated s i = true) : canAcquire s i = true := by
  simp [canAcquire, h]

/-- **ANONYMOUS USERS CANNOT STARVE A LOGGED-IN ONE.** However many anonymous users arrive,
    they consume exactly one seat between them -- so a credentialed identity's ability to be
    admitted is unchanged by anonymous volume. The "greyed out user" requirement, as an
    invariant rather than a comment. -/
theorem anonymous_users_share_one_seat (s : Seats)
    (h : seated s Identity.anonymous = true) :
    inUse (acquire s Identity.anonymous) = inUse s := by
  -- `simp` normalises `seated` to list membership in the goal, so the hypothesis has to be
  -- moved into the same form or it cannot discharge the `¬ ∈` branch.
  have hm : Identity.anonymous ∈ s.held := by simpa [seated] using h
  simp [acquire, canAcquire, seated, hm]

/-- **A REFUSAL CHANGES NOTHING.** When the allocator says no, the state is untouched: no
    half-taken seat, nothing to leak. Without this a refused request could still consume
    budget and the cap would drift down over time until nobody could connect. -/
theorem a_refusal_leaves_the_state_untouched (s : Seats) (i : Identity)
    (h : canAcquire s i = false) : acquire s i = s := by
  simp [acquire, h]

/-- **RELEASE IS IDEMPOTENT.** Releasing twice is releasing once -- a double release from a
    retry path cannot free a seat somebody else is holding. -/
theorem release_is_idempotent (s : Seats) (i : Identity) :
    release (release s i) i = release s i := by
  simp [release, List.filter_filter]

/-- **RELEASING WHAT YOU HOLD FREES THE SEAT FOR SOMEONE ELSE.** The liveness direction: a
    cap that never released would deadlock at capacity forever, which is worse than no cap.
    Stated on the concrete full state because it is an existence claim about progress. -/
theorem releasing_frees_a_seat :
    canAcquire full4 (Identity.credentialed 9) = false ∧
    canAcquire (release full4 Identity.anonymous) (Identity.credentialed 9) = true := by
  decide

/-- **ZERO MEANS UNLIMITED, FOR EVERY IDENTITY.** Matching the sibling networking settings.
    Quantified rather than sampled: an admin who leaves the field at its default must never
    be silently throttled. -/
theorem zero_capacity_admits_everyone (s : Seats) (i : Identity)
    (h : s.capacity = 0) : canAcquire s i = true := by
  simp [canAcquire, unlimited, h]

/-- A distinct new identity at capacity is refused -- the cap actually bites. Without this
    every theorem above is satisfied by an allocator that admits everyone. -/
theorem a_new_identity_at_capacity_is_refused :
    canAcquire full4 (Identity.credentialed 42) = false := by decide

/-! ## The paused/recording case — why re-entrancy is the whole mechanism

The concrete failure: with several models paused or recording, the app repeatedly reopens a
connection for the SAME logged-in identity to fetch the m3u8 and to keep the session alive.
One identity, many models, many connections -- and the site answers 404/429.

Keying the seat on `(identity, model)` makes that measurable. The same identity asking again
for a model it already holds must reuse the seat it has, so N paused models under one account
cost N seats and never N x (retries). Two different identities watching the SAME model do not
contend, because their keys differ -- "they don't bite each other", and past the cap the
second is refused rather than added to the pile. -/

/-- A seat is held for a specific model by a specific identity. -/
structure Claim where
  who : Identity
  model : Nat
deriving DecidableEq, Repr

/-- Claims currently held, with the admin's cap. -/
structure Board where
  claims : List Claim
  capacity : Nat
deriving Repr

def heldBy (b : Board) (c : Claim) : Bool := b.claims.contains c
def load (b : Board) : Nat := b.claims.length
def admits (b : Board) (c : Claim) : Bool :=
  b.capacity == 0 || heldBy b c || load b < b.capacity

/-- Reopening a connection: re-entrant on the exact `(identity, model)` pair. -/
def open' (b : Board) (c : Claim) : Board :=
  if admits b c && !heldBy b c then { b with claims := c :: b.claims } else b

def twoPaused : Board := ⟨[⟨Identity.credentialed 1, 100⟩, ⟨Identity.credentialed 1, 200⟩], 2⟩

#guard load twoPaused == 2
-- the retry loop: the same identity re-asking for a model it already holds adds nothing
#guard load (open' twoPaused ⟨Identity.credentialed 1, 100⟩) == 2
#guard load (open' (open' twoPaused ⟨Identity.credentialed 1, 100⟩) ⟨Identity.credentialed 1, 100⟩) == 2
-- a different identity on the SAME model is a different claim, refused only by the cap
#guard admits twoPaused ⟨Identity.credentialed 2, 100⟩ == false
#guard admits ⟨twoPaused.claims, 3⟩ ⟨Identity.credentialed 2, 100⟩ == true

/--
**THE RETRY LOOP CANNOT GROW THE LOAD.** However many times an identity reopens a connection
for a model it already holds, the number of live connections is unchanged. This is the exact
defect described: the app re-establishing the same session repeatedly until the site answers
429. Quantified over every board and claim, not just the two-model corpus.
-/
theorem reopening_an_existing_claim_adds_nothing (b : Board) (c : Claim)
    (h : heldBy b c = true) : load (open' b c) = load b := by
  have hm : c ∈ b.claims := by simpa [heldBy] using h
  simp [open', admits, heldBy, hm]

/-- **AND IT IS STABLE UNDER REPETITION** -- the loop can run forever without drift. A single
    application could be accidental; idempotence is what makes it safe in a retry path. -/
theorem reopening_is_idempotent (b : Board) (c : Claim) :
    open' (open' b c) c = open' b c := by
  unfold open'
  split
  · next h =>
    simp only [Bool.and_eq_true, Bool.not_eq_true'] at h
    simp [heldBy, h.1]
  · rfl

/-- **DIFFERENT IDENTITIES ON THE SAME MODEL DO NOT COLLIDE.** Their claims are distinct, so
    one holding a model never marks it held for the other -- "they don't bite each other".
    Without this, the first user to record a model would silently block everyone else. -/
theorem two_identities_on_one_model_are_distinct_claims (m : Nat) (x y : Nat) (h : x ≠ y) :
    (⟨Identity.credentialed x, m⟩ : Claim) ≠ ⟨Identity.credentialed y, m⟩ := by
  simp [Claim.mk.injEq, h]

/-- **THE CAP STILL BINDS ON CLAIMS.** The same guarantee as `the_cap_is_never_exceeded`,
    carried over to the (identity, model) key so the setting means something here too. -/
theorem the_claim_cap_is_never_exceeded (b : Board) (c : Claim)
    (hcap : b.capacity > 0) (hok : load b ≤ b.capacity) :
    load (open' b c) ≤ b.capacity := by
  unfold open'
  split
  · next h =>
    simp only [Bool.and_eq_true, Bool.not_eq_true', admits, heldBy, Bool.or_eq_true,
      beq_iff_eq, decide_eq_true_eq] at h
    obtain ⟨ha, hns⟩ := h
    rcases ha with (hz | hs) | hlt
    · omega
    · rw [hs] at hns; simp at hns
    · simp only [load, List.length_cons] at *; omega
  · exact hok

/-! ## The "E-S" mark — enforce-seats per model, gated on developer mode

The requirement, in the Socio's terms: a switch that must exist ONLY when the developer
command is enabled, so a testing instance cannot congest a model that is already paused or
recorded, with a visible mark in the thumbnail so misuse is obvious rather than silent.

Two invariants, and they point in opposite directions on purpose:

* **Nothing appears when developer mode is off.** Not the menu item, not the mark. A hidden
  feature that still renders a badge would be worse than no gate: the user sees state they
  cannot explain or change.
* **A mark that IS shown always means the seat is enforced.** A badge that can appear without
  the behaviour behind it is decoration, and decoration on a safety control is the failure
  this whole section exists to prevent.

The pairing is what matters. Either half alone is satisfiable by doing nothing. -/

/-- App-level gate: the developer command. -/
inductive DevMode where
  | enabled
  | disabled
deriving DecidableEq, Repr

/-- Per-model enforce-seats state, as the right-click toggle sets it. -/
structure ModelMark where
  /-- the user asked for enforcement on this model -/
  requested : Bool
  /-- the global developer switch -/
  dev : DevMode
deriving DecidableEq, Repr

/-- Is the menu item offered at all? -/
def offersToggle (m : ModelMark) : Bool := m.dev == DevMode.enabled

/-- Is the "E-S" mark drawn on the thumbnail? Requires BOTH the request and the gate: a
    request made while developer mode was on must stop rendering the moment it goes off,
    rather than leaving an orphaned badge the user can no longer clear. -/
def showsMark (m : ModelMark) : Bool := m.requested && m.dev == DevMode.enabled

/-- Is the seat actually enforced for this model? Identical condition to the mark by
    construction -- that identity IS the anti-decoration guarantee, not a coincidence. -/
def enforcesSeat (m : ModelMark) : Bool := m.requested && m.dev == DevMode.enabled

#guard offersToggle ⟨false, DevMode.enabled⟩ == true
#guard offersToggle ⟨true, DevMode.disabled⟩ == false
#guard showsMark ⟨true, DevMode.enabled⟩ == true
#guard showsMark ⟨true, DevMode.disabled⟩ == false
#guard showsMark ⟨false, DevMode.enabled⟩ == false
#guard enforcesSeat ⟨true, DevMode.enabled⟩ == true

/--
**NOTHING IS OFFERED OR SHOWN WITH DEVELOPER MODE OFF.** Both the menu item and the mark
disappear, even for a model the user previously marked. An orphaned badge the user cannot
explain or clear is worse than no gate at all.
-/
theorem developer_mode_off_hides_everything (m : ModelMark) (h : m.dev = DevMode.disabled) :
    offersToggle m = false ∧ showsMark m = false ∧ enforcesSeat m = false := by
  cases hr : m.requested <;> simp [offersToggle, showsMark, enforcesSeat, h]

/--
**A VISIBLE MARK ALWAYS MEANS THE SEAT IS ENFORCED.** The badge cannot appear without the
behaviour behind it. Without this the "E-S" mark would be decoration on a safety control --
the user would believe a model is protected from the testing instance when it is not.
-/
theorem a_visible_mark_always_enforces (m : ModelMark) (h : showsMark m = true) :
    enforcesSeat m = true := by
  simpa [showsMark, enforcesSeat] using h

/-- And the converse: enforcement is never silent. A seat capped without a visible mark would
    leave the user unable to see why a model behaves differently from its neighbours. -/
theorem enforcement_is_never_invisible (m : ModelMark) (h : enforcesSeat m = true) :
    showsMark m = true := by
  simpa [showsMark, enforcesSeat] using h

/-- **THE TOGGLE IS ONLY REACHABLE WHERE IT IS OFFERED.** A mark can only be set through a
    menu item that was shown, so no code path can enable enforcement behind the gate. -/
theorem a_mark_implies_the_toggle_was_offered (m : ModelMark) (h : showsMark m = true) :
    offersToggle m = true := by
  simp [showsMark, offersToggle] at *
  exact h.2

/-!
## Teardown — the half that was missing

An acquire was once wired into `AbstractDownload.init()` with no matching release. It compiled and
it worked; it also leaked one claim per finished recording until the cap was exhausted by stale
entries, at which point enforcement blocks everything and presents as a hang. That failure is
strictly worse than the unbounded connections the cap exists to prevent, and it surfaces only after
hours of use.

These theorems state what a correct teardown must satisfy, so the wiring is checked against a
specification rather than against the author's memory.
-/

/-- Teardown: drop a claim. Mirrors `SeatGate.release`. -/
def close' (b : Board) (c : Claim) : Board :=
  { b with claims := b.claims.filter (fun x => x != c) }

/-- Removing a claim removes every copy of it, not merely the first. -/
theorem closing_frees_the_claim (b : Board) (c : Claim) :
    heldBy (close' b c) c = false := by
  simp [heldBy, close', List.contains_eq_any_beq]

/-- A double release from a retry path is harmless. -/
theorem close_is_idempotent (b : Board) (c : Claim) :
    close' (close' b c) c = close' b c := by
  simp [close', List.filter_filter]

/-- Releasing a claim never disturbs a different one: one model's teardown cannot free another's. -/
theorem closing_preserves_other_claims (b : Board) (c d : Claim) (h : d ≠ c) :
    heldBy (close' b c) d = heldBy b d := by
  simp only [heldBy, close']
  rw [Bool.eq_iff_iff]
  simp only [List.contains_iff_mem, List.mem_filter, bne_iff_ne, ne_eq, decide_eq_true_eq]
  exact ⟨fun hx => hx.1, fun hx => ⟨hx, h⟩⟩

/-- A claim not held is unaffected by dropping it. The step the leak theorem needs. -/
theorem filter_ne_of_absent (l : List Claim) (c : Claim) (h : l.contains c = false) :
    l.filter (fun x => x != c) = l := by
  have hmem : c ∉ l := by simpa using h
  rw [List.filter_eq_self]
  intro a ha
  simp only [bne_iff_ne, ne_eq, decide_eq_true_eq]
  rintro rfl
  exact hmem ha

/-- **The wiring contract.** Open then close returns the board to exactly its prior state, so a
completed recording leaves no residue. This is the property `AbstractDownload` must honour before
an acquire may be re-introduced there. -/
theorem teardown_restores_the_board (b : Board) (c : Claim) (h : heldBy b c = false) :
    close' (open' b c) c = b := by
  have hb : b.claims.contains c = false := by simpa [heldBy] using h
  unfold open' close'
  by_cases hadm : admits b c && !heldBy b c
  · simp only [hadm, if_pos]
    simp [List.filter_cons, filter_ne_of_absent b.claims c hb]
  · simp only [hadm, if_neg, Bool.false_eq_true, not_false_eq_true]
    simp [filter_ne_of_absent b.claims c hb]

/-- Load returns to its starting value across a full cycle — the executable form of the same fact,
and precisely what `phase88.sh` asserts over 25 iterations. -/
theorem teardown_restores_the_load (b : Board) (c : Claim) (h : heldBy b c = false) :
    load (close' (open' b c) c) = load b := by
  rw [teardown_restores_the_board b c h]

/-- **The leak, stated so it cannot be mistaken for the fixed case.** Opening without closing grows
the load monotonically. If this theorem ever fails, `open'` stopped recording claims and every
capacity guarantee above became vacuous. -/
theorem without_teardown_the_load_grows :
    load (open' (open' ⟨[], 0⟩ ⟨Identity.credentialed 1, 100⟩) ⟨Identity.credentialed 1, 200⟩) = 2 := by
  decide

/-- And with teardown it does not. The contrast is the point: same two opens, load back to zero. -/
theorem with_teardown_the_load_does_not_grow :
    load (close' (close' (open' (open' ⟨[], 0⟩ ⟨Identity.credentialed 1, 100⟩)
      ⟨Identity.credentialed 1, 200⟩) ⟨Identity.credentialed 1, 200⟩)
      ⟨Identity.credentialed 1, 100⟩) = 0 := by
  decide

end CtbrecSpec.SeatAllocation
