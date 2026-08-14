/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: the DNS fallback layer (`ctbrec.io.ResilientDns`, `ctbrec.io.DnsWire`).

WHY THIS EXISTS, and what it is NOT.

Measured 2026-08-13: this machine has no working resolver. Both servers configured on the active
adapter (127.7.7.10 = Heimdal DarkLayer Guard's own listener, and 127.0.0.2) answer nothing, for
`example.com` and `microsoft.com` exactly as for the cam sites, so it is not content filtering. The
app recorded `UnknownHostException` for chaturbate.com and www.camsoda.com inside one minute and
every tab went blank at once.

The REPAIR for that is on the host, not here (Checklist.md H1). This layer is hardening for the
NEXT time, and it is DEFAULT OFF: with an empty fallback list it is provably identical to the
shipped system-only behaviour (`an_empty_chain_is_exactly_the_shipped_behaviour`). That theorem is
the honest content of the claim "this changes nothing unless you ask for it".

DELIBERATELY NOT PROVED HERE: that any particular address answers. `127.7.7.10` and `192.168.178.1`
are contingent facts about today's network and appear in NO theorem — a spec that froze them would
go red the day the Socio changes his router, on a correct change. They live in the settings file.
-/

namespace CtbrecSpec.DnsFallback

/-! ## Part 1 — resolver ordering

An address is opaque: nothing below depends on what an address IS, only on whether a resolver
produced any. That is what makes these laws hold for every resolver, including ones not written yet.
-/

abbrev Addr := Nat
abbrev Answer := List Addr

/-- A resolver maps a host to the addresses it answers with. `[]` means "no answer". -/
abbrev Resolver := Nat → Answer

/--
The outcome of a lookup. The two constructors are the whole point: there is no
"successful empty answer", because an empty list reaching the UI is what renders an unresolved host
as "no models". A failure carries the host so the log line can name it.
-/
inductive Outcome where
  | addresses : Answer → Outcome
  | unresolved : Nat → Outcome
  deriving DecidableEq, Repr

/-- First resolver in the list that answers with something. Order is load-bearing. -/
def firstAnswer : List Resolver → Nat → Option Answer
  | [], _ => none
  | r :: rs, h =>
      match r h with
      | [] => firstAnswer rs h
      | as => some as

/-- The shipped behaviour before this work: ask the system resolver, and that is the only chance. -/
def systemOnly (sys : Resolver) (h : Nat) : Outcome :=
  match sys h with
  | [] => .unresolved h
  | as => .addresses as

/--
`ResilientDns.lookup`: the primary is always asked first and its non-empty answer is returned
unchanged; the fallback list is consulted only when the primary produced nothing.
-/
def chain (sys : Resolver) (fbs : List Resolver) (h : Nat) : Outcome :=
  match sys h with
  | [] =>
      match firstAnswer fbs h with
      | some as => .addresses as
      | none => .unresolved h
  | as => .addresses as

/-- `firstAnswer` reports `some` only for a resolver that answered, so it never yields `some []`. -/
theorem firstAnswer_ne_nil : ∀ (l : List Resolver) (x : Nat) (as : Answer),
    firstAnswer l x = some as → as ≠ [] := by
  intro l x as h
  induction l with
  | nil => simp [firstAnswer] at h
  | cons r rs ih =>
      cases hr : r x with
      | nil => simp only [firstAnswer, hr] at h; exact ih h
      | cons b bs =>
          simp only [firstAnswer, hr] at h
          simp at h
          subst h
          simp

/-- Appending to the resolver list cannot change an answer the list already produced. -/
theorem firstAnswer_append_stable : ∀ (l : List Resolver) (r : Resolver) (x : Nat) (as : Answer),
    firstAnswer l x = some as → firstAnswer (l ++ [r]) x = some as := by
  intro l r x as h
  induction l with
  | nil => simp [firstAnswer] at h
  | cons q qs ih =>
      cases hq : q x with
      | nil =>
          simp only [firstAnswer, hq] at h
          simp only [List.cons_append, firstAnswer, hq]
          exact ih h
      | cons c cs =>
          simp only [firstAnswer, hq] at h
          simp only [List.cons_append, firstAnswer, hq]
          exact h

/--
THE law that keeps this layer honest. Whatever the fallback list contains, a working primary wins.
So the layer cannot redirect traffic, cannot defeat a hosts-file entry, and cannot route around the
Socio's DNS filter while that filter is doing its job.
-/
theorem a_successful_primary_is_never_overridden
    (sys : Resolver) (fbs : List Resolver) (h : Nat) (hne : sys h ≠ []) :
    chain sys fbs h = .addresses (sys h) := by
  unfold chain
  cases hs : sys h with
  | nil => exact absurd hs hne
  | cons a as => simp

/-- The fallback is reached only on an empty primary. -/
theorem the_fallback_is_consulted_only_when_the_primary_is_empty
    (sys : Resolver) (fbs : List Resolver) (h : Nat) (hs : sys h = []) :
    chain sys fbs h = match firstAnswer fbs h with
                      | some as => .addresses as
                      | none => .unresolved h := by
  unfold chain; rw [hs]

/--
DEFAULT OFF, proved. With no configured fallback server the new code is indistinguishable from the
old one — this is what licenses shipping it unarmed rather than asking the Socio to trust a diff.
-/
theorem an_empty_chain_is_exactly_the_shipped_behaviour (sys : Resolver) (h : Nat) :
    chain sys [] h = systemOnly sys h := by
  unfold chain systemOnly firstAnswer
  cases sys h <;> simp

/-- No lookup ever reports success with nothing in hand: "unresolved" and "zero addresses" stay distinct. -/
theorem a_lookup_never_answers_with_an_empty_list (sys : Resolver) (fbs : List Resolver) (h : Nat) :
    chain sys fbs h ≠ .addresses [] := by
  intro hcon
  unfold chain at hcon
  cases hs : sys h with
  | cons a as => rw [hs] at hcon; simp at hcon
  | nil =>
      rw [hs] at hcon
      cases hf : firstAnswer fbs h with
      | none => rw [hf] at hcon; simp at hcon
      | some bs =>
          rw [hf] at hcon
          simp at hcon
          exact firstAnswer_ne_nil fbs h bs hf hcon

/-- A failure names the host that was asked, so the log line is attributable without a live shell. -/
theorem a_failure_names_the_host_that_was_asked
    (sys : Resolver) (fbs : List Resolver) (h k : Nat) (hu : chain sys fbs h = .unresolved k) :
    k = h := by
  unfold chain at hu
  cases hs : sys h with
  | cons a as => rw [hs] at hu; simp at hu
  | nil =>
      rw [hs] at hu
      cases hf : firstAnswer fbs h with
      | some as => rw [hf] at hu; simp at hu
      | none =>
          rw [hf] at hu
          simp at hu
          exact hu.symm

/--
DURABLE, and the reason no theorem here names an IP: appending a resolver can never lose an answer
the chain already had. Adding a server to the settings file is therefore safe by construction, and
this spec does not have to be edited when the Socio changes his network.
-/
theorem appending_a_resolver_never_loses_an_answer
    (sys : Resolver) (fbs : List Resolver) (r : Resolver) (h : Nat) (as : Answer)
    (hok : chain sys fbs h = .addresses as) :
    chain sys (fbs ++ [r]) h = .addresses as := by
  unfold chain at hok ⊢
  cases hs : sys h with
  | cons a as' =>
      rw [hs] at hok
      simp at hok ⊢
      exact hok
  | nil =>
      rw [hs] at hok
      simp only at hok ⊢
      cases hf : firstAnswer fbs h with
      | some bs =>
          rw [hf] at hok
          rw [firstAnswer_append_stable fbs r h bs hf]
          exact hok
      | none => rw [hf] at hok; simp at hok

/-- Order decides the winner: the first resolver that answers is the one whose answer is used. -/
theorem the_first_answering_resolver_wins
    (r : Resolver) (rs : List Resolver) (h : Nat) (hr : r h ≠ []) :
    firstAnswer (r :: rs) h = some (r h) := by
  unfold firstAnswer
  cases hx : r h with
  | nil => exact absurd hx hr
  | cons a as => simp [hx]

/-! ### The mutation targets for Part 1

`disarmedChain` is what a careless "simplification" of `lookup` looks like: try the fallback first,
or prefer it when it answers. It is here so the spec can PROVE the difference rather than assert it.
-/

/-- A chain that prefers the fallback. This is the bypass the ordering law forbids. -/
def fallbackFirstChain (sys : Resolver) (fbs : List Resolver) (h : Nat) : Outcome :=
  match firstAnswer fbs h with
  | some as => .addresses as
  | none => systemOnly sys h

/-- Witness that the two are NOT interchangeable: a fallback-first chain overrides a working primary. -/
theorem a_fallback_first_chain_overrides_a_working_primary :
    ∃ (sys : Resolver) (fbs : List Resolver) (h : Nat),
      sys h ≠ [] ∧ fallbackFirstChain sys fbs h ≠ chain sys fbs h := by
  refine ⟨(fun _ => [1]), [(fun _ => [2])], 0, by simp, ?_⟩
  simp [fallbackFirstChain, chain, firstAnswer, systemOnly]

/-! ## Part 2 — the DNS wire format (`DnsWire`)

QNAME encoding is where a silent defect would be invisible: a truncated label asks a DIFFERENT
question, and the answer to that question looks perfectly valid. So the encoder is proved to be
injective in the only way that matters — it round-trips.
-/

/-- A label is a list of octets; a name is a list of labels. -/
abbrev Label := List Nat
abbrev Name := List Label

/-- RFC 1035 2.3.4: a label is 1..63 octets. Zero is impossible — the zero octet TERMINATES a name. -/
def labelOk (l : Label) : Prop := 0 < l.length ∧ l.length ≤ 63

instance (l : Label) : Decidable (labelOk l) := by unfold labelOk; infer_instance

def nameOk (n : Name) : Prop := ∀ l ∈ n, labelOk l

/-- `DnsWire.encodeQname`: every label prefixed by its length, terminated by a zero octet. -/
def encodeQname : Name → List Nat
  | [] => [0]
  | l :: ls => l.length :: (l ++ encodeQname ls)

/--
The decoder, structural on a fuel bound. Fuel is not a modelling convenience: the real parser
bounds its walk too (`DnsWire.MAX_JUMPS`), because an unbounded walk over hostile input is a denial
of service.
-/
def decodeQname : Nat → List Nat → Option Name
  | 0, _ => none
  | _ + 1, [] => none
  | f + 1, n :: rest =>
      if n = 0 then some []
      else if n ≤ 63 && n ≤ rest.length then
        (decodeQname f (rest.drop n)).map (fun ls => rest.take n :: ls)
      else none

/-- Encoding a well-formed name and decoding it returns exactly that name. -/
theorem decode_encode_roundtrip (n : Name) (h : nameOk n) :
    decodeQname (n.length + 1) (encodeQname n) = some n := by
  induction n with
  | nil => simp [encodeQname, decodeQname]
  | cons l ls ih =>
      have hl : labelOk l := h l (by simp)
      have hls : nameOk ls := fun x hx => h x (by simp [hx])
      have hpos : l.length ≠ 0 := Nat.pos_iff_ne_zero.mp hl.1
      have hle : l.length ≤ 63 := hl.2
      have hlen : l.length ≤ (l ++ encodeQname ls).length := by
        simp [List.length_append]
      have ht : (l ++ encodeQname ls).take l.length = l := by simp
      have hd : (l ++ encodeQname ls).drop l.length = encodeQname ls := by simp
      simp only [encodeQname, decodeQname, List.length_cons, if_neg hpos]
      simp only [hle, hlen, decide_true, Bool.and_self, if_true, ht, hd, ih hls,
        Option.map_some]

/-- A name with an over-long label is not encodable, so it is refused rather than truncated. -/
theorem an_over_long_label_is_not_wellformed (l : Label) (hl : 63 < l.length) : ¬ labelOk l := by
  intro h; exact absurd h.2 (Nat.not_le.mpr hl)

/-- An empty label cannot appear in a well-formed name: it would be read as the terminator. -/
theorem an_empty_label_is_not_wellformed : ¬ labelOk [] := by
  intro h; exact absurd h.1 (by simp)

/-- The encoding of a non-empty name is strictly longer than the encoding of its tail. -/
theorem encoding_grows_with_each_label (l : Label) (ls : Name) :
    (encodeQname (l :: ls)).length = l.length + 1 + (encodeQname ls).length := by
  simp [encodeQname, List.length_append]
  omega

/--
Every encoded name ends with the root (zero) octet — stated as "is something followed by 0", which
is the property the parser relies on to know where a name stops.
-/
theorem every_encoded_name_ends_with_the_root (n : Name) :
    ∃ pre, encodeQname n = pre ++ [0] := by
  induction n with
  | nil => exact ⟨[], by simp [encodeQname]⟩
  | cons l ls ih =>
      obtain ⟨pre, hpre⟩ := ih
      refine ⟨l.length :: (l ++ pre), ?_⟩
      simp [encodeQname, hpre, List.append_assoc]

/-! ### Mutation target for Part 2 -/

/-- A "simplified" encoder that drops the terminator. It changes the question that is asked. -/
def encodeNoRoot : Name → List Nat
  | [] => []
  | l :: ls => l.length :: (l ++ encodeNoRoot ls)

theorem dropping_the_root_octet_changes_the_message :
    encodeNoRoot [[1]] ≠ encodeQname [[1]] := by
  simp [encodeNoRoot, encodeQname]

/-! ## Part 3 — executable checks on the measured shapes

`#guard` rather than a theorem, on purpose: these pin TODAY's values (the ones actually observed on
the wire and on this machine) and are expected to change. Nothing above depends on them.
-/

-- "chaturbate.com" as label lengths: 11 + 3
#guard (encodeQname [List.replicate 11 99, List.replicate 3 99]).length == 17
#guard (encodeQname []) == [0]
#guard decodeQname 3 (encodeQname [[1], [2]]) == some [[1], [2]]
#guard decodeQname 1 (encodeQname [[1], [2]]) == none          -- fuel exhaustion is a refusal, not a guess
#guard decodeQname 5 [64, 1, 0] == none                        -- label > 63 rejected
#guard decodeQname 5 [5, 1, 0] == none                         -- length beyond the buffer rejected
#guard firstAnswer [] 0 == none
#guard firstAnswer [(fun _ => []), (fun _ => [7])] 0 == some [7]
#guard chain (fun _ => [1]) [(fun _ => [2])] 0 == Outcome.addresses [1]
#guard chain (fun _ => []) [(fun _ => [2])] 0 == Outcome.addresses [2]
#guard chain (fun _ => []) [] 0 == Outcome.unresolved 0
#guard systemOnly (fun _ => []) 0 == Outcome.unresolved 0

end CtbrecSpec.DnsFallback
