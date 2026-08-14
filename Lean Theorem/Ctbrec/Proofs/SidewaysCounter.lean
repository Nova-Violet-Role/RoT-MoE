/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
The sideways viewer counter -- one cross-site layer, not fifteen per-site bolt-ons.

MEASURED SITE LANDSCAPE (src/common/ctbrec/sites/, 2026-08):
  15 sites present: bonga cam4 camsoda chaturbate dreamcam fc2live flirt4free mfc showup
                    streamate streamray stripchat winktv xlovecam
  Viewer count available on exactly TWO:
    mfc     -- MyFreeCamsModel.java:42,266  `state.getM().getRc()`, live websocket push
    fc2live -- Fc2Model.java:45             plain field + setter
  The other twelve expose nothing. `viewerCount` is NOT on the `Model` base interface.

WHY "SIDEWAYS" IS THE RIGHT WORD, made precise. A counter bolted into each site class is
fifteen edits, fifteen regressions, and a permanent tax on every new site. A sideways layer
asks each model whether it CAN report, and is silent where it cannot. The property that makes
it genuinely sideways is `an_unsupported_site_perturbs_nothing`: adding or removing a site
that has no counter cannot change what is already displayed or how anything ranks. That is
what lets the layer ship today with two sites and grow later without touching the rest.

THE DEFECT THIS SPEC EXISTS TO PREVENT. `int viewerCount` has a default of 0, and 0 renders
as "nobody is watching". On twelve of fifteen sites that would be a FABRICATION -- the app
does not know the count, and saying zero is worse than saying nothing, because a community
building a leaderboard on it would rank real models below unknown ones. `Reading` therefore
has an explicit `unknown` constructor and `absent_never_renders_as_zero` forbids the
collapse. This is the same class of defect as a spec quantified over a field the code never
populates: a number that looks like a measurement and is actually a default.

NOT MODELLED, and named so nobody infers it: whether recording or pausing actually changes a
site's displayed viewer count (plausible, UNMEASURED here -- an HLS connection may or may not
register as a viewer), and anything about OTHER users' CTBrecEVO instances. A client cannot
observe another client without a coordination server that does not exist in this tree. Both
are empirical or architectural questions, not theorems.
-/

namespace CtbrecSpec.SidewaysCounter

/-- What the layer can learn from one model. `unknown` is load-bearing: it is the honest
    answer for the twelve sites with no counter, and it is NOT zero. -/
inductive Reading where
  /-- the site reported a live count -/
  | viewers (n : Nat)
  /-- the site exposes no counter, or has not reported yet -/
  | unknown
deriving DecidableEq, Repr

/-! ### Capability is DERIVED FROM THE PAYLOAD, not from a table of site names

The first version of this file carried `capabilityOf : String -> Capability`, a hardcoded list
naming mfc and fc2live as the only reporting sites. That table was WRONG, and the way it was
wrong is worth recording because it is the second time this exact mistake has been made here.

The evidence behind it came from grepping ctbrec's JAVA SOURCE for count fields. That
measurement was accurate about the source and false about the world: the counts are in the
API RESPONSES, and ctbrec discards them. `ChaturbateModel.java:428` builds a `JSONObject`
from a response and reads exactly one key out of it; the count is sitting in that payload,
unparsed. So "only two of fifteen sites report" was a fact about ctbrec, stated as if it were
a fact about the sites.

Two defects followed from it, and both are fixed here rather than patched:

1. The table would have FROZEN A CONTINGENT FACT. Even had it been right, it named the sites
   that happen to work today. Any site added later, or any site that starts returning a count,
   would have been declared silent by a spec that could not see it -- a theorem that expires
   and then fails loudly on a correct change.
2. The spec would have MODELLED A STATIC TABLE WHILE THE CODE SCANNED DYNAMICALLY. That is
   the same overclaim already found and repaired once in RootCauseTrace: a spec running ahead
   of, or beside, an implementation that does something else.

What is modelled now is the ACTUAL ALGORITHM in `ViewerCountProbe.java`: walk a set of known
keys in priority order, take the first that holds a valid count, and report nothing when none
does. No site name appears anywhere, which is exactly why the layer is sideways. -/

/-- A payload, reduced to what the probe can see: the key/value pairs it carries. -/
abbrev Payload := List (String × Int)

/-- The keys the probe recognises, in PRIORITY ORDER. Explicit viewer keys come before the
    generic membership key: on some payloads `members` counts followers rather than live
    viewers, and would otherwise shadow a real count that is present in the same object. -/
def knownKeys : List String :=
  ["num_users", "numUsers", "viewer_count", "viewerCount", "viewersCount",
   "viewers", "spectators", "watchers", "numOnline", "onlineCount",
   "usersCount", "totalUsers", "audience", "members"]

/-- A value is a count only when it is a non-negative whole number. Anything else is rejected
    rather than coerced, so a negative or nonsensical value cannot become a plausible count. -/
def asCount (v : Int) : Option Nat := if v ≥ 0 then some v.toNat else none

/-- The scan, mirroring `ViewerCountProbe.search`: first recognised key wins. -/
def probe (p : Payload) : Reading :=
  let rec go : List String → Reading
    | [] => Reading.unknown
    | k :: rest =>
      match p.find? (fun kv => kv.1 == k) with
      | some kv => match asCount kv.2 with
                   | some n => Reading.viewers n
                   | none => go rest
      | none => go rest
  go knownKeys

#guard probe [("num_users", 412)] == Reading.viewers 412
#guard probe [("viewersCount", 88)] == Reading.viewers 88
#guard probe [("username", 0), ("tags", 3)] == Reading.unknown
#guard probe [] == Reading.unknown
-- a genuine zero from a real key IS a fact and is reported
#guard probe [("num_users", 0)] == Reading.viewers 0
-- a negative is not a count; the scan continues rather than coercing it
#guard probe [("viewers", -5)] == Reading.unknown
-- specificity: an explicit viewer key beats the generic membership key
#guard probe [("members", 9999), ("num_users", 12)] == Reading.viewers 12

/-- A site reports exactly when its payload carries a recognised count. No site names. -/
inductive Capability where
  | reports
  | silent
deriving DecidableEq, Repr

/-- Capability is now a function of the PAYLOAD, so a site added tomorrow is supported the
    moment its response contains a known key -- no edit here, no expired table. -/
def capabilityOfPayload (p : Payload) : Capability :=
  match probe p with
  | Reading.viewers _ => Capability.reports
  | Reading.unknown => Capability.silent

#guard capabilityOfPayload [("num_users", 5)] == Capability.reports
#guard capabilityOfPayload [("nothing", 1)] == Capability.silent

/-- **A PAYLOAD WITH NO RECOGNISED KEY IS SILENT, NEVER ZERO.** The dynamic restatement of
    the property this file exists for, now quantified over payloads instead of over a fixed
    list of site names -- so it holds for every site, including ones that do not exist yet. -/
theorem an_unrecognised_payload_is_silent (p : Payload)
    (h : probe p = Reading.unknown) : capabilityOfPayload p = Capability.silent := by
  simp [capabilityOfPayload, h]

/-- **A REPORTED COUNT CAME FROM A RECOGNISED KEY.** The converse, and the one that makes the
    badge trustworthy: nothing is displayed that the scan did not actually find. -/
theorem a_reported_count_was_scanned (p : Payload) (n : Nat)
    (h : probe p = Reading.viewers n) : capabilityOfPayload p = Capability.reports := by
  simp [capabilityOfPayload, h]

/-! A `capabilityOf : String -> Capability` stub was written here during the repair and
    DELETED rather than kept. It returned `reports` for every site, which silently turned
    `a_silent_site_never_renders` and `an_unsupported_site_perturbs_nothing` into claims about
    nothing -- the theorems would still have compiled, green and vacuous. Weakening a theorem
    to make a refactor land is the failure this project forbids outright, and a stub that
    keeps a name alive while gutting its meaning is exactly that in a quieter form. -/

/-- A model as the sideways layer sees it: the site it came from, and the RAW PAYLOAD.

    Carrying the payload rather than a pre-digested reading is the repair. The site name is
    retained for diagnostics only -- nothing in this file branches on it, which is what makes
    the layer sideways and what stops a site table from silently expiring. -/
structure Entry where
  site : String
  payload : Payload
deriving DecidableEq, Repr

/-- What the badge shows. `nothing` is a real outcome -- no badge is drawn at all. -/
inductive Badge where
  | shows (n : Nat)
  | nothing
deriving DecidableEq, Repr

/--
Render. A count is shown only when the site reports AND a reading exists.

The double condition is deliberate. Capability alone is not enough: mfc reports, but before
the first websocket frame arrives its field still holds the Java default of 0. Requiring the
reading too is what stops a freshly-opened list from claiming every model has no viewers.
-/
def render (e : Entry) : Badge :=
  match probe e.payload with
  | Reading.viewers n => Badge.shows n
  | Reading.unknown => Badge.nothing

#guard render ⟨"mfc", [("viewers", 412)]⟩ == Badge.shows 412
#guard render ⟨"mfc", []⟩ == Badge.nothing
-- chaturbate DOES report: the count is in the payload, which the old site table denied
#guard render ⟨"chaturbate", [("num_users", 999)]⟩ == Badge.shows 999
#guard render ⟨"chaturbate", [("username", 1)]⟩ == Badge.nothing
-- a genuine zero from a real key IS shown: nobody watching is a fact, not an absence
#guard render ⟨"mfc", [("viewers", 0)]⟩ == Badge.shows 0
-- a site nobody has heard of works the moment its payload carries a known key
#guard render ⟨"brand-new-site", [("spectators", 33)]⟩ == Badge.shows 33

/--
**AN UNKNOWN READING NEVER RENDERS AS ZERO.** The defect this file exists to prevent: `int`
defaults to 0, and a 0 badge reads as "nobody is watching" on twelve sites where the app
simply does not know. A community ranking models on that number would rank real ones below
unmeasured ones.

Quantified over every entry, so it holds for sites that do not exist yet.
-/
theorem absent_never_renders_as_zero (e : Entry) (h : probe e.payload = Reading.unknown) :
    render e = Badge.nothing := by
  simp [render, h]

/-- **A SILENT PAYLOAD NEVER RENDERS ANYTHING.** Stronger than the site-name version it
    replaces: it holds for every possible response, so a stale or fabricated number that never
    matched a recognised key cannot leak into the UI. The old form quantified over a table of
    fourteen site names; this one quantifies over every payload any site could ever send. -/
theorem a_silent_payload_never_renders (e : Entry)
    (h : capabilityOfPayload e.payload = Capability.silent) : render e = Badge.nothing := by
  cases hp : probe e.payload with
  | viewers n => simp [capabilityOfPayload, hp] at h
  | unknown => simp [render, hp]

/-- **A SHOWN NUMBER WAS ACTUALLY SCANNED OUT OF THE PAYLOAD.** The converse, and the one that
    makes the badge trustworthy: if something is displayed, the probe really found it under a
    recognised key. Without this the layer could invent a number and every theorem above would
    still hold. -/
theorem a_shown_number_was_really_reported (e : Entry) (n : Nat) (h : render e = Badge.shows n) :
    probe e.payload = Reading.viewers n ∧ capabilityOfPayload e.payload = Capability.reports := by
  cases hp : probe e.payload with
  | viewers m => simp [render, hp] at h; simp [hp, h, capabilityOfPayload]
  | unknown => simp [render, hp] at h

/-! ## The sideways property itself -/

/-- Only entries that actually render take part in a ranking. -/
def rankable (es : List Entry) : List Entry := es.filter (fun e => render e != Badge.nothing)

/-- Payload shapes these sites actually return. Chaturbate now RANKS, because its response
    does carry `num_users` -- the old corpus asserted the opposite, which is what a site table
    built from the wrong measurement will do to you. -/
def corpus : List Entry :=
  [⟨"mfc", [("viewers", 412)]⟩,
   ⟨"chaturbate", [("num_users", 999)]⟩,
   ⟨"fc2live", [("viewerCount", 7)]⟩,
   ⟨"stripchat", [("username", 1)]⟩,
   ⟨"mfc", []⟩]

#guard (rankable corpus).length == 3
#guard (rankable corpus).map (fun e => e.site) == ["mfc", "chaturbate", "fc2live"]

/--
**THE SIDEWAYS PROPERTY: AN UNSUPPORTED SITE PERTURBS NOTHING.** Adding an entry from a
silent site leaves the rankable set exactly as it was -- same members, same order.

This is what makes the layer genuinely orthogonal rather than fifteen bolt-ons waiting to
happen. It is also the guarantee that lets this ship today with two sites: no future site,
supported or not, can disturb what already works, so growth costs nothing retroactively.
-/
theorem an_unsupported_site_perturbs_nothing (es : List Entry) (e : Entry)
    (h : capabilityOfPayload e.payload = Capability.silent) :
    rankable (es ++ [e]) = rankable es := by
  simp [rankable, List.filter_append, a_silent_payload_never_renders e h]

/-- The same for a reporting site that has not reported yet -- a model still loading must not
    shuffle the board. Together with the previous theorem this covers every way an entry can
    fail to render. -/
theorem an_unreported_model_perturbs_nothing (es : List Entry) (e : Entry)
    (h : probe e.payload = Reading.unknown) :
    rankable (es ++ [e]) = rankable es := by
  simp [rankable, List.filter_append, absent_never_renders_as_zero e h]

/-- **EVERY RANKED ENTRY IS A REAL MEASUREMENT.** No entry reaches a leaderboard without a
    reporting site behind it, so a ranking can never be built on defaults. -/
theorem every_ranked_entry_renders (es : List Entry) (e : Entry) (h : e ∈ rankable es) :
    render e != Badge.nothing := by
  simp only [rankable, List.mem_filter] at h
  exact h.2

/-- Ranking is a sublist of the input: the layer only ever hides, never invents. -/
theorem ranking_only_removes (es : List Entry) : (rankable es).length ≤ es.length := by
  simp [rankable, List.length_filter_le]

/-! ## Local activity — the honest half of the leaderboard

A cross-user leaderboard needs a coordination server this tree does not have, and that server
would collect which models each user records: the most sensitive data the application
touches. What IS knowable locally, with no server and no privacy cost, is THIS instance's own
activity. That is a true ranking, and it is the part that can ship. -/

/-- One model's local activity in this instance. -/
structure Activity where
  model : String
  /-- currently paused by this user -/
  paused : Bool
  /-- currently recording in this user's instance -/
  recording : Bool
deriving DecidableEq, Repr

/-- A model is *engaged* if this instance is doing either thing with it.

    Counted ONCE even when both are true. Pausing a recording model is one relationship with
    one model, and double-counting it would inflate exactly the models the user interacts
    with most -- the ones a leaderboard is supposed to rank correctly. -/
def engaged (a : Activity) : Bool := a.paused || a.recording

#guard engaged ⟨"alice", true, false⟩ == true
#guard engaged ⟨"bob", false, true⟩ == true
#guard engaged ⟨"carol", true, true⟩ == true
#guard engaged ⟨"dave", false, false⟩ == false

def engagedCount (as : List Activity) : Nat := (as.filter engaged).length

#guard engagedCount [⟨"a", true, true⟩, ⟨"b", false, false⟩, ⟨"c", false, true⟩] == 2

/-- **PAUSED AND RECORDING TOGETHER COUNT ONCE.** The double-count would inflate precisely
    the models the user engages with most, which is the population a ranking must get right. -/
theorem both_states_count_once (m : String) :
    engagedCount [⟨m, true, true⟩] = 1 := by
  -- `decide` cannot close this: `m` is a free variable, so the goal is not a closed
  -- proposition. Quantifying over the model name is the point -- the property must hold for
  -- every model, not for one literal.
  simp [engagedCount, engaged]

/-- **AN IDLE MODEL CONTRIBUTES NOTHING**, so the count cannot drift upward from mere
    presence in the list. -/
theorem an_idle_model_adds_nothing (as : List Activity) (m : String) :
    engagedCount (as ++ [⟨m, false, false⟩]) = engagedCount as := by
  simp [engagedCount, List.filter_append, engaged]

/-- The local count never exceeds the number of models known -- it is a count, not a score. -/
theorem the_local_count_is_bounded (as : List Activity) : engagedCount as ≤ as.length := by
  simp [engagedCount, List.length_filter_le]

/-! ## Sort filters — by viewers, by last-online, ascending or descending, every site

The trap this section exists to disarm: `int viewerCount` defaults to 0, so a naive sort
treats "we do not know" as "zero viewers". Ascending, that puts every unmeasured model at the
TOP of the list; descending, it buries real ones. Either way the ordering is a lie built on a
default, and it is the same defect as rendering a 0 badge -- just harder to notice, because a
sorted list always looks authoritative.

The rule below: entries with no reading are NEVER interleaved with entries that have one.
They keep their relative order and sit after every measured entry, in BOTH directions. So
flipping ascending/descending reorders what is known and never promotes what is not. -/

/-- Sort direction, as the UI offers it. -/
inductive Direction where
  | ascending
  | descending
deriving DecidableEq, Repr

/-- What the user is sorting on. `lastOnline` is a timestamp; `viewers` and `spectators` both
    resolve through the same payload scan, which is why one probe serves every column. -/
inductive SortKey where
  | viewers
  | spectators
  | lastOnline
deriving DecidableEq, Repr

/-- Split a list into the entries that carry a reading and those that do not, preserving the
    relative order of each group. Order preservation is what makes the sort STABLE: two models
    with equal counts keep the order the user last saw them in, instead of shuffling on every
    refresh. -/
def measured (es : List Entry) : List Entry := es.filter (fun e => render e != Badge.nothing)
def unmeasured (es : List Entry) : List Entry := es.filter (fun e => render e == Badge.nothing)

/-- The count used for ordering. Only ever applied to measured entries. -/
def countOf (e : Entry) : Nat :=
  match probe e.payload with
  | Reading.viewers n => n
  | Reading.unknown => 0

/-- Order measured entries by count in the requested direction, then append the unmeasured
    ones unchanged. The append is the whole safety property: unknowns cannot be interleaved
    because they are never given a number to be compared on. -/
def sortEntries (d : Direction) (es : List Entry) : List Entry :=
  let known := measured es
  let ordered := match d with
    | Direction.ascending => known.mergeSort (fun a b => countOf a ≤ countOf b)
    | Direction.descending => known.mergeSort (fun a b => countOf b ≤ countOf a)
  ordered ++ unmeasured es

def mixed : List Entry :=
  [⟨"a", [("num_users", 50)]⟩,
   ⟨"b", []⟩,
   ⟨"c", [("viewers", 7)]⟩,
   ⟨"d", [("nothing", 1)]⟩,
   ⟨"e", [("spectators", 900)]⟩]

#guard (sortEntries Direction.ascending mixed).map (fun e => e.site) == ["c", "a", "e", "b", "d"]
#guard (sortEntries Direction.descending mixed).map (fun e => e.site) == ["e", "a", "c", "b", "d"]
-- both directions keep the two unmeasured entries last, in their original relative order
#guard ((sortEntries Direction.ascending mixed).drop 3).map (fun e => e.site) == ["b", "d"]
#guard ((sortEntries Direction.descending mixed).drop 3).map (fun e => e.site) == ["b", "d"]

/-- The two groups together are the whole list. Core has no lemma for this shape -- `exact?`
    found nothing -- so it is proved directly by induction rather than by hunting for a name
    that does not exist.

    `cases` on the decision, not `by_cases`: the two filters use `!=` and `==` on the same
    value, and splitting the Bool explicitly is what lets `simp` see them as complements. -/
theorem measured_and_unmeasured_partition (es : List Entry) :
    (measured es).length + (unmeasured es).length = es.length := by
  induction es with
  | nil => rfl
  | cons a t ih =>
    -- `bne` must be in the simp set: `measured` filters on `!=` and `unmeasured` on `==`, and
    -- without unfolding `bne` the first filter stays as an unreduced match that omega cannot
    -- see through. The error named it exactly -- a `match render a != Badge.nothing` term.
    cases h : (render a == Badge.nothing) <;>
      simp [measured, unmeasured, List.filter, bne, h] at ih ⊢ <;> omega

/--
**SORTING LOSES NOTHING AND INVENTS NOTHING.** The result has exactly as many entries as the
input. Without this a sort could silently drop the models it could not order -- which is the
tempting shortcut, and it would make an incomplete list look complete.
-/
theorem sorting_preserves_length (d : Direction) (es : List Entry) :
    (sortEntries d es).length = es.length := by
  cases d <;>
    simp [sortEntries, List.length_append, List.length_mergeSort,
          measured_and_unmeasured_partition]

/--
**AN UNMEASURED ENTRY IS NEVER PROMOTED BY THE SORT ORDER.** In both directions the unknowns
occupy the tail, so flipping ascending/descending can never lift a model with no reading above
one with a real count.

This is the sort-order twin of `absent_never_renders_as_zero`, and it is the one that actually
bites: a badge that shows nothing is obviously absent, but a model sitting at the top of an
ascending "fewest viewers" list looks like a measurement.
-/
theorem unmeasured_entries_stay_at_the_tail (d : Direction) (es : List Entry) :
    (sortEntries d es).drop (measured es).length = unmeasured es := by
  cases d <;> simp [sortEntries, List.drop_left', List.length_mergeSort]

/-- **THE DIRECTION ONLY REORDERS WHAT IS KNOWN.** Ascending and descending produce the same
    tail, so the unmeasured group is untouched by the toggle. Together with the previous
    theorem this pins both halves: unknowns stay last AND stay put. -/
theorem direction_does_not_disturb_the_unknown (es : List Entry) :
    (sortEntries Direction.ascending es).drop (measured es).length =
    (sortEntries Direction.descending es).drop (measured es).length := by
  simp [unmeasured_entries_stay_at_the_tail]

/-- **EVERY SORTED ENTRY CAME FROM THE INPUT.** The sort is a rearrangement, never a source of
    new rows -- so a filter cannot conjure a model that is not there. -/
theorem sorting_introduces_nothing (d : Direction) (es : List Entry) (e : Entry)
    (h : e ∈ sortEntries d es) : e ∈ es := by
  cases d <;>
  · simp only [sortEntries, List.mem_append, List.mem_mergeSort, measured, unmeasured,
      List.mem_filter] at h
    rcases h with h | h <;> exact h.1

end CtbrecSpec.SidewaysCounter
