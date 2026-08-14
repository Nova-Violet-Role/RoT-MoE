/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the joined string/list property behind the FlareSolverr domain box

Subject: `src/app/ctbrec/ui/settings/api/SimpleJoinedStringListProperty.java`, built once at
`SettingsTab.java:205-207` with delimiter `"\n"` over `settings.flaresolverr.useForDomains`.

It keeps a `String` (what the user types) and an `ObservableList<String>` (what the app reads) in
sync, by `String.join` in one direction and `String.split` in the other. Those two are **not**
inverses, and the consumer makes the difference load-bearing:

* `HttpClient.java:81` — `if (!useForDomains.isEmpty())` **constructs a `FlaresolverrClient`**.
* `HttpClient.java:160` — `useForDomains.contains(host)` decides whether it is ever *used*.

So a list that is non-empty but contains nothing matchable starts the whole FlareSolverr
subsystem — including the remote session repaired at checkpoint 54 — and then never uses it.

## The measured semantics of `String.split`

Measured on this machine with Temurin 21, delimiter `"\n"`, before any of it was modelled:

```
""      -> len=1 [""]     rejoin ""      equalsInput=true
"a"     -> len=1 ["a"]    rejoin "a"     equalsInput=true
"a\nb"  -> len=2 [a, b]   rejoin "a\nb"  equalsInput=true
"a\n"   -> len=1 [a]      rejoin "a"     equalsInput=FALSE
"a\n\n" -> len=1 [a]      rejoin "a"     equalsInput=FALSE
"\na"   -> len=2 ["", a]  rejoin "\na"   equalsInput=true
"\n"    -> len=0 []       rejoin ""      equalsInput=FALSE
"a\n\nb"-> len=3 [a,"",b] rejoin "a\n\nb" equalsInput=true
```

Two behaviours to reproduce faithfully, and the first surprised me: **trailing** empty segments are
discarded but **leading** ones are kept, and `"".split` returns an array of length **one**, not
zero, because `split` short-circuits when the pattern never matches.

## Finding 1 — clearing the box does not disable FlareSolverr

The user empties the field. `"".split("\n")` is `[""]`, so `list.setAll` leaves **one empty
string**. `useForDomains.isEmpty()` is then `false`, `HttpClient.java:81` builds the client, and
`contains(host)` is false for every real host. The setting was cleared; the subsystem still starts.
`a_cleared_box_still_arms_flaresolverr` is that statement, and
`the_repair_disarms_it` is the other half.

## Finding 2 — a trailing delimiter makes the two views disagree permanently

`setValue("a\n")` stores the string `"a\n"` but a list of `["a"]`. Joining the list gives `"a"`.
The property and its list then hold different answers to the same question until something else
overwrites them — the same shape as the `BandwidthMeter.setThroughput` defect at checkpoint 39.
The repair stores the **canonical** join of the filtered list, so the two cannot drift apart:
`the_canonical_form_is_a_fixed_point`.

## Finding 3 — the delimiter is literal to `join` and a REGEX to `split`

`String.join` treats the delimiter literally; `String.split` compiles it as a regular expression.
For today's `"\n"` the two coincide, which is why nothing has broken. The constructor is public and
takes any delimiter, so this is a contingent fact about one call site, not a property of the class
— exactly the shape this project refuses to leave load-bearing. The repair quotes the delimiter.
Today's delimiter is recorded as an `example`, never as a hypothesis.
-/

namespace CtbrecSpec

/-- One segment of the joined text. -/
abbrev Seg := List Char

/-- `String.join(delimiter, parts)`. -/
def joinSegs (d : Char) : List Seg → List Char
  | [] => []
  | [s] => s
  | s :: rest => s ++ d :: joinSegs d rest

/-- The raw split: a delimiter always starts a new segment, and every empty one is kept. -/
def splitAll (d : Char) : List Char → List Seg
  | [] => [[]]
  | c :: cs =>
      if c = d then [] :: splitAll d cs
      else match splitAll d cs with
           | [] => [[c]]
           | seg :: rest => (c :: seg) :: rest

/-- Drop trailing empty segments, as `String.split` with the default limit does. -/
def dropTrailingEmpty (xs : List Seg) : List Seg :=
  (xs.reverse.dropWhile (·.isEmpty)).reverse

/-- `String.split(delimiter)` as MEASURED, including the short-circuit that makes `"".split` return
one empty string rather than none: when the pattern never matches, the whole input is returned. -/
def javaSplit (d : Char) (s : List Char) : List Seg :=
  if d ∈ s then dropTrailingEmpty (splitAll d s) else [s]

/-- Intra-entry whitespace. `'\n'` is deliberately NOT here: it is the delimiter at the one call
site, and a character cannot be both the separator and noise inside a segment. `'\r'` is here
because a pasted CRLF block splits on `'\n'` and leaves a `'\r'` glued to the end of every entry,
which `contains(host)` then never matches. -/
def isSpace (c : Char) : Bool := c = ' ' || c = '\t' || c = '\r'

/-- Remove every whitespace character from a segment.

Checkpoint 59 left trimming as a declared gap because trim-both-ends needs an idempotence proof
that `dropWhile`/`reverse` make awkward. **Removing** whitespace instead of trimming it is a
`List.filter`, whose idempotence is one rewrite — and for a hostname the two agree, because
whitespace is never valid *inside* a domain either. A weaker definition would have been the easy
way out; this one is stronger than trimming and cheaper to prove. -/
def squeeze (s : Seg) : Seg := s.filter (fun c => !isSpace c)

/-- The repair: split literally, squeeze each entry, and keep only what still has content.

One filter now covers both defects — an empty entry and a whitespace-only entry — because after
squeezing, "blank" and "empty" are the same thing. -/
def repairedSplit (d : Char) (s : List Char) : List Seg :=
  ((splitAll d s).map squeeze).filter (fun seg => !seg.isEmpty)

/-! ### The measured trace, reproduced

Each line of the Java measurement above, by `decide`. This is the tightest binding between the
model and the running JDK that this project can make. -/

theorem measured_empty : (javaSplit '\n' "".toList).length = 1 := by decide
theorem measured_a : javaSplit '\n' "a".toList = ["a".toList] := by decide
theorem measured_ab : (javaSplit '\n' "a\nb".toList).length = 2 := by decide
theorem measured_trailing : javaSplit '\n' "a\n".toList = ["a".toList] := by decide
theorem measured_trailing_two : javaSplit '\n' "a\n\n".toList = ["a".toList] := by decide
theorem measured_leading : (javaSplit '\n' "\na".toList).length = 2 := by decide
theorem measured_only_delim : (javaSplit '\n' "\n".toList).length = 0 := by decide
theorem measured_inner_empty : (javaSplit '\n' "a\n\nb".toList).length = 3 := by decide

/-! ### Finding 1 — the cleared box -/

/-- **Clearing the field leaves one empty domain.** `useForDomains.isEmpty()` is therefore false at
`HttpClient.java:81`, which constructs a `FlaresolverrClient` that `contains(host)` at
`HttpClient.java:160` will never match. -/
theorem a_cleared_box_still_arms_flaresolverr :
    (javaSplit '\n' "".toList) ≠ [] ∧ (javaSplit '\n' "".toList).all (·.isEmpty) := by decide

/-- **…and the repair disarms it**, for every delimiter, not just today's. -/
theorem the_repair_disarms_it (d : Char) : repairedSplit d [] = [] := by
  simp [repairedSplit, splitAll, squeeze]

/-- **No empty entry ever reaches the list.** Quantified over every delimiter and every text, so a
leading, inner or trailing empty is all covered by one statement. -/
theorem no_blank_domain_survives_the_repair (d : Char) (s : List Char) :
    [] ∉ repairedSplit d s := by
  simp [repairedSplit, List.mem_filter]

/-- **No whitespace survives anywhere in any entry** — checkpoint 59's declared gap, closed. This
is what makes `isEmpty()` at `HttpClient.java:81` an honest answer: a box holding only spaces now
yields no entries at all, so the client is not constructed. -/
theorem no_whitespace_survives_the_repair (d : Char) (s : List Char) (seg : Seg)
    (hseg : seg ∈ repairedSplit d s) (c : Char) (hc : c ∈ seg) : ¬ isSpace c := by
  simp only [repairedSplit, List.mem_filter, List.mem_map] at hseg
  obtain ⟨⟨y, _, hy⟩, _⟩ := hseg
  subst hy
  simp only [squeeze, List.mem_filter] at hc
  simpa using hc.right

/-- A box holding only spaces disarms FlareSolverr, exactly as an empty one does. -/
theorem a_whitespace_only_box_disarms_flaresolverr :
    repairedSplit '\n' "   ".toList = [] ∧ repairedSplit '\n' " \t\r\n  ".toList = [] := by decide

/-- A pasted CRLF block no longer leaves a `'\r'` glued to every entry. -/
theorem a_pasted_crlf_block_still_matches :
    repairedSplit '\n' "a.com\r\nb.com".toList = ["a.com".toList, "b.com".toList] := by decide

/-- **Anti-amputation.** Squeezing and filtering is not "return nothing": every segment that still
has a non-space character in it survives, as its squeeze. Without this,
`repairedSplit := fun _ _ => []` would satisfy everything above. -/
theorem the_repair_keeps_every_real_entry (d : Char) (s : List Char) (seg : Seg)
    (hmem : seg ∈ splitAll d s) (hne : squeeze seg ≠ []) : squeeze seg ∈ repairedSplit d s := by
  simp only [repairedSplit, List.mem_filter, List.mem_map]
  exact ⟨⟨seg, hmem, rfl⟩, by simpa using hne⟩

/-- Squeezing is idempotent — the property that trimming would have made hard. -/
theorem squeeze_idem (s : Seg) : squeeze (squeeze s) = squeeze s := by
  simp [squeeze, List.filter_filter]

/-- **A newline is never squeezed away.**

Found by mutation, not by inspection: the mutant that adds `'\n'` to `isSpace` SURVIVED the first
sweep, because with today's delimiter `'\n'` no segment ever contains a newline and the two
definitions agree on every input the spec had. It is not an equivalent mutant, and the difference
is not cosmetic — a newline is a *separator* in the user's mental model, so eating one merges two
domains into a third that is neither. Change the call site's delimiter to `','` (an entirely
plausible future edit) and `"a.com\nb.com,c.com"` becomes `["a.comb.com", "c.com"]` under the
mutant: two valid domains silently fused into one that matches nothing. Under this theorem it stays
`["a.com\nb.com", "c.com"]` — still junk, but *visibly* junk rather than a silent merge.

Stated over every segment, so it constrains the definition rather than recording today's delimiter.
-/
theorem a_newline_is_never_squeezed_away (s : Seg) (h : '\n' ∈ s) : '\n' ∈ squeeze s := by
  simp only [squeeze, List.mem_filter]
  exact ⟨h, by decide⟩

/-- The consequence at the level the user sees: two entries on separate lines are never merged,
whatever delimiter the call site picks. -/
theorem separate_lines_are_never_merged :
    repairedSplit ',' "a.com\nb.com,c.com".toList
      = ["a.com\nb.com".toList, "c.com".toList] := by decide

/-- Squeezing never introduces a character, so a delimiter-free segment stays delimiter-free. -/
theorem squeeze_no_delim (d : Char) (s : Seg) (h : d ∉ s) : d ∉ squeeze s := by
  intro hmem
  exact h (List.mem_filter.mp hmem).left

/-- A real domain list still comes through intact. -/
theorem a_real_domain_list_is_preserved :
    repairedSplit '\n' "chaturbate.com\nmyfreecams.com".toList
      = ["chaturbate.com".toList, "myfreecams.com".toList] := by decide

/-! ### Finding 2 — the two views disagreeing -/

/-- **Measured:** with a trailing delimiter the stored string and the joined list differ. -/
theorem a_trailing_delimiter_makes_the_views_disagree :
    joinSegs '\n' (javaSplit '\n' "a\n".toList) ≠ "a\n".toList := by decide

/-- A segment produced by the raw split never contains the delimiter. -/
theorem splitAll_no_delim (d : Char) : ∀ (s : List Char), ∀ seg ∈ splitAll d s, d ∉ seg
  | [], seg, hmem => by simp [splitAll] at hmem; simp [hmem]
  | c :: cs, seg, hmem => by
      by_cases hc : c = d
      · rw [splitAll, if_pos hc] at hmem
        rcases List.mem_cons.mp hmem with h | h
        · simp [h]
        · exact splitAll_no_delim d cs seg h
      · rw [splitAll, if_neg hc] at hmem
        cases hsp : splitAll d cs with
        | nil =>
            rw [hsp] at hmem
            simp at hmem
            subst hmem
            intro hin
            simp at hin
            exact hc hin.symm
        | cons s0 rest =>
            rw [hsp] at hmem
            rcases List.mem_cons.mp hmem with h | h
            · subst h
              have h0 : d ∉ s0 := splitAll_no_delim d cs s0 (by rw [hsp]; simp)
              simp [h0, Ne.symm hc]
            · exact splitAll_no_delim d cs seg (by rw [hsp]; exact List.mem_cons_of_mem _ h)

/-- A text with no delimiter in it splits into exactly itself. -/
theorem splitAll_of_no_delim (d : Char) : ∀ (s : List Char), d ∉ s → splitAll d s = [s]
  | [], _ => rfl
  | c :: cs, h => by
      have hc : c ≠ d := fun he => h (by simp [he])
      have hcs : d ∉ cs := fun hm => h (by simp [hm])
      rw [splitAll, if_neg hc, splitAll_of_no_delim d cs hcs]

/-- Splitting at the first delimiter peels off exactly the segment before it. -/
theorem splitAll_append_delim (d : Char) : ∀ (s rest : List Char), d ∉ s →
    splitAll d (s ++ d :: rest) = s :: splitAll d rest
  | [], rest, _ => by rw [List.nil_append, splitAll, if_pos rfl]
  | c :: cs, rest, h => by
      have hc : c ≠ d := fun he => h (by simp [he])
      have hcs : d ∉ cs := fun hm => h (by simp [hm])
      rw [List.cons_append, splitAll, if_neg hc, splitAll_append_delim d cs rest hcs]

/-- Joining and re-splitting a delimiter-free, non-empty list of segments is the identity. -/
theorem splitAll_joinSegs (d : Char) : ∀ (xs : List Seg), xs ≠ [] → (∀ s ∈ xs, d ∉ s) →
    splitAll d (joinSegs d xs) = xs
  | [], hne, _ => absurd rfl hne
  | [s], _, hd => by
      rw [joinSegs, splitAll_of_no_delim d s (hd s (by simp))]
  | s :: t :: rest, _, hd => by
      -- Every hypothesis is bound with `have` BEFORE the rewrite. An inline `(by …)` sitting in a
      -- `rw` argument is elaborated later, against a metavariable, and the tactic cannot fire --
      -- it resurfaces as an unsolved `case x_1` at the enclosing `by`, which reads like a missing
      -- proof rather than a postponed one. Measured here: `by simp` that closes the very same goal
      -- standalone left it open inline.
      have hs : d ∉ s := hd s (by simp)
      have hnn : (t :: rest) ≠ [] := by simp
      have hsub : ∀ x ∈ (t :: rest), d ∉ x := by
        intro x hx
        exact hd x (List.mem_cons_of_mem s hx)
      have ih : splitAll d (joinSegs d (t :: rest)) = t :: rest :=
        splitAll_joinSegs d (t :: rest) hnn hsub
      show splitAll d (s ++ d :: joinSegs d (t :: rest)) = s :: t :: rest
      rw [splitAll_append_delim d s _ hs, ih]

/-- **The canonical form is a fixed point.** The repaired `setValue` stores the join of the
filtered list, so re-splitting what it stored gives the same list back — the string view and the
list view cannot drift apart, for **every** delimiter and **every** text the user can type. This is
the durable statement; today's `"\n"` is only an `example` below. -/
-- NOTE: this was first stated with a hypothesis `¬ isSpace d`, on the reasoning that squeezing
-- would eat a whitespace delimiter out of the join. The linter reported the binding as never
-- referenced, and it is right: `splitAll` consumes the delimiter *before* `squeeze` is ever applied
-- to a segment, so the fixed point holds for EVERY delimiter including `' '` and `'\t'`. The
-- hypothesis was over-assuming and has been removed rather than left in place looking prudent.
theorem the_canonical_form_is_a_fixed_point (d : Char) (s : List Char) :
    repairedSplit d (joinSegs d (repairedSplit d s)) = repairedSplit d s := by
  -- Every entry the repair produces is non-empty, delimiter-free, and already squeezed.
  have hne : ∀ seg ∈ repairedSplit d s, seg ≠ [] := by
    intro seg hmem
    simp only [repairedSplit, List.mem_filter] at hmem
    simpa using hmem.right
  have hd : ∀ seg ∈ repairedSplit d s, d ∉ seg := by
    intro seg hmem
    simp only [repairedSplit, List.mem_filter, List.mem_map] at hmem
    obtain ⟨⟨y, hy, hyeq⟩, _⟩ := hmem
    subst hyeq
    exact squeeze_no_delim d y (splitAll_no_delim d s y hy)
  have hsq : ∀ seg ∈ repairedSplit d s, squeeze seg = seg := by
    intro seg hmem
    simp only [repairedSplit, List.mem_filter, List.mem_map] at hmem
    obtain ⟨⟨y, _, hyeq⟩, _⟩ := hmem
    subst hyeq
    exact squeeze_idem y
  cases hemp : repairedSplit d s with
  | nil => simp [joinSegs, repairedSplit, splitAll, squeeze]
  | cons a rest =>
      have hne2 : (a :: rest) ≠ [] := by simp
      have hd2 : ∀ seg ∈ (a :: rest), d ∉ seg := by rw [← hemp]; exact hd
      have hall : ∀ seg ∈ (a :: rest), seg ≠ [] := by rw [← hemp]; exact hne
      have hsq2 : ∀ seg ∈ (a :: rest), squeeze seg = id seg := by rw [← hemp]; exact hsq
      show ((splitAll d (joinSegs d (a :: rest))).map squeeze).filter
             (fun seg => !seg.isEmpty) = a :: rest
      rw [splitAll_joinSegs d (a :: rest) hne2 hd2, List.map_congr_left hsq2, List.map_id,
          List.filter_eq_self]
      intro seg hmem
      simpa using hall seg hmem

/-- Today's delimiter, as an `example` and not a hypothesis anything rests on. -/
example : repairedSplit '\n' (joinSegs '\n' (repairedSplit '\n' "a\n\nb\n".toList))
    = repairedSplit '\n' "a\n\nb\n".toList := by decide

/-- The repaired round trip on the measured case that used to disagree. -/
theorem the_repaired_views_agree_on_the_measured_case :
    joinSegs '\n' (repairedSplit '\n' "a\n".toList) = "a".toList := by decide

#guard (javaSplit '\n' "".toList).length == 1
#guard (repairedSplit '\n' "".toList).length == 0
#guard (javaSplit '\n' "\n".toList).length == 0
#guard javaSplit '\n' "a\n".toList == ["a".toList]
#guard repairedSplit '\n' "\na\n".toList == ["a".toList]
#guard repairedSplit '\n' "a\n\nb".toList == ["a".toList, "b".toList]
#guard joinSegs '\n' (repairedSplit '\n' "a\n".toList) == "a".toList
#guard repairedSplit '\n' "chaturbate.com".toList == ["chaturbate.com".toList]
#guard (repairedSplit '\n' "   ".toList).length == 0
#guard repairedSplit '\n' " a.com \n\t\n b.com ".toList == ["a.com".toList, "b.com".toList]
#guard repairedSplit '\n' "a.com\r\nb.com".toList == ["a.com".toList, "b.com".toList]
#guard squeeze (squeeze " a b ".toList) == squeeze " a b ".toList
#guard squeeze "a
b".toList == "a
b".toList
#guard repairedSplit ',' "a.com
b.com,c.com".toList == ["a.com
b.com".toList, "c.com".toList]

end CtbrecSpec
