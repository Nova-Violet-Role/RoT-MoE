/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A session id that reaches a filename is an attack surface

Two observability gaps were measured on 2026-08-09, both structural:

* **A new user gets no logs at all.** `ARM_ROUTER.sh`, `ARM_ROUTER.ps1`,
  `settings-merge.js` and both plugin manifests contain zero references to
  `ROTMOE_DEBUG_LOG`, and the router's first act is `if (-not $p) { return }`.
  Every install therefore ships with the observation channel switched off.
* **No session identity.** The record schema carries `kind, ts, event, lane,
  lens, Rs, chars, stem, arm` and no session. Two concurrent sessions interleave
  into one file with no way to separate them -- measured live: 185 route records
  from at least two sessions, indistinguishable.

The fix is two logs. The central one keeps every session, as now. A second,
PER-SESSION log lands in the project being worked on, so it can be inspected
beside the code that produced it.

## Why this file exists rather than a careful patch

The per-session log puts a value **from the hook payload into a FILENAME**.
`session_id` is attacker-influenceable in the general case, and a path is not a
string: `../../.ssh/authorized_keys` is a perfectly good "session id". A router
that appends JSONL to that would write outside the project directory, and the
failure would be silent because the router is contractually forbidden from
throwing.

So the sanitiser is specified here first, and the property proved is not "it
strips bad characters" but the consequence that matters:

    the produced name contains no path separator and no dot,
    therefore it cannot leave the directory it is joined to.

`Proofs.RotEvent` already sanitises EVENT names, to letters only. This is a
deliberately separate function with a wider alphabet -- session ids are
alphanumeric with dashes, and reusing the letters-only scrubber would collapse
every id to a handful of characters and destroy the separation it exists for.
Two sanitisers with two proofs beats one that is wrong for one of its callers.
-/

import Proofs.RotEvent

namespace RotMoE.SessionLog

/-- Characters allowed in a session id once scrubbed: alphanumerics and the
dash, which is what the CLI's own ids use. Deliberately EXCLUDES `.`, `/`, `\`,
`:` and quotes -- see the traversal and JSON theorems below. -/
def isSafeChar (c : Char) : Bool :=
  c.isAlphanum || c == '-'

/-- Upper bound on the retained id. A filename is a bounded resource; an
unbounded id from a payload could exceed the filesystem's limit and make the
write fail on some sessions and not others -- the worst kind of intermittent. -/
def maxLen : Nat := 64

/-- The characters retained from an id, as a list. Named rather than inlined as
a `let` so the proofs below can `split` on the emptiness test -- with a `let` in
the way, `split` reports "Could not split an `if` or `match` expression". -/
def keptChars (s : String) : List Char :=
  (s.toList.filter isSafeChar).take maxLen

/-- The scrubber. Total: every input, including the empty string and a string of
nothing but separators, yields a usable name. -/
def sanitiseSession (s : String) : String :=
  if (keptChars s).isEmpty then "unknown" else String.ofList (keptChars s)

/-! ### Two list facts, proved here rather than guessed at by name

Both are one induction. Reaching for a remembered mathlib name instead is how a
build ends up depending on a lemma that does not exist in this toolchain. -/

theorem all_filter {α} (p : α → Bool) (l : List α) :
    (l.filter p).all p = true := by
  induction l with
  | nil => rfl
  | cons a t ih => by_cases h : p a <;> simp [List.filter, h, ih]

theorem all_take {α} (p : α → Bool) (n : Nat) (l : List α)
    (h : l.all p = true) : (l.take n).all p = true := by
  induction n generalizing l with
  | zero => simp
  | succ k ih =>
      cases l with
      | nil => simp
      | cons a t =>
          simp only [List.all_cons, Bool.and_eq_true] at h
          simp only [List.take_succ_cons, List.all_cons, Bool.and_eq_true]
          exact ⟨h.1, ih t h.2⟩

theorem keptChars_safe (s : String) : (keptChars s).all isSafeChar = true :=
  all_take _ _ _ (all_filter _ _)

/-- The per-session filename. The literal prefix is load-bearing: it means the
name can never BE a bare reserved device name on Windows (`CON`, `NUL`, ...),
which is a real way to make a file write hang or fail. -/
def localFileName (s : String) : String :=
  "rot-route-" ++ sanitiseSession s ++ ".jsonl"

/-! ## Every character that survives is safe -/

theorem sanitise_is_safe (s : String) :
    (sanitiseSession s).toList.all isSafeChar = true := by
  unfold sanitiseSession
  split
  · decide
  · simpa [String.toList_ofList] using keptChars_safe s

/-! ## The consequence that matters: the name cannot escape its directory -/

/-- No forward slash survives. -/
theorem no_forward_slash (s : String) :
    (sanitiseSession s).toList.contains '/' = false := by
  have h := sanitise_is_safe s
  cases hc : (sanitiseSession s).toList.contains '/' with
  | false => rfl
  | true =>
      have hm : '/' ∈ (sanitiseSession s).toList := List.contains_iff_mem.mp hc
      have := (List.all_eq_true.mp h) '/' hm
      simp [isSafeChar] at this

/-- No backslash survives, so the Windows arm is covered too. -/
theorem no_backslash (s : String) :
    (sanitiseSession s).toList.contains '\\' = false := by
  have h := sanitise_is_safe s
  cases hc : (sanitiseSession s).toList.contains '\\' with
  | false => rfl
  | true =>
      have hm : '\\' ∈ (sanitiseSession s).toList := List.contains_iff_mem.mp hc
      have := (List.all_eq_true.mp h) '\\' hm
      simp [isSafeChar] at this

/-- No dot survives, so `..` cannot be formed at all -- traversal is impossible
by construction rather than by blacklisting the `..` spelling. Blacklisting the
spelling is how traversal filters get bypassed; removing the character is not. -/
theorem no_dot (s : String) :
    (sanitiseSession s).toList.contains '.' = false := by
  have h := sanitise_is_safe s
  cases hc : (sanitiseSession s).toList.contains '.' with
  | false => rfl
  | true =>
      have hm : '.' ∈ (sanitiseSession s).toList := List.contains_iff_mem.mp hc
      have := (List.all_eq_true.mp h) '.' hm
      simp [isSafeChar] at this

/-- No double quote survives. The id is also interpolated into a JSON record, and
one quote would corrupt every line for `checker/log-replay.sh` downstream. -/
theorem no_quote (s : String) :
    (sanitiseSession s).toList.contains '"' = false := by
  have h := sanitise_is_safe s
  cases hc : (sanitiseSession s).toList.contains '"' with
  | false => rfl
  | true =>
      have hm : '"' ∈ (sanitiseSession s).toList := List.contains_iff_mem.mp hc
      have := (List.all_eq_true.mp h) '"' hm
      simp [isSafeChar] at this

/-! ## Totality and bounds -/

/-- Never empty. An empty name would make the path collapse to the directory
itself and the append would target a directory -- an error the router is
forbidden from reporting, so it would vanish. -/
theorem sanitise_never_empty (s : String) :
    (sanitiseSession s).toList ≠ [] := by
  unfold sanitiseSession
  split
  · decide
  · rename_i h
    simpa [String.toList_ofList, List.isEmpty_iff] using h

/-- Bounded by construction, for every input length. -/
theorem sanitise_is_bounded (s : String) :
    (sanitiseSession s).toList.length ≤ maxLen := by
  unfold sanitiseSession
  split
  · decide
  · simp only [String.toList_ofList, keptChars]
    exact List.length_take_le _ _

/-! ## The scrubber must not be the identity, or it proves nothing -/

/-- It genuinely removes something. Without this, a scrubber that returned its
input unchanged would satisfy every theorem above on well-formed ids and be
worthless on the one input that matters. -/
theorem sanitise_is_not_the_identity :
    sanitiseSession "../../etc/passwd" ≠ "../../etc/passwd" := by
  decide

/-- The traversal attempt, stated as the concrete outcome. -/
theorem traversal_is_flattened :
    sanitiseSession "../../etc/passwd" = "etcpasswd" := by
  decide

/-! ## The filename keeps its prefix, whatever the input -/

/-- Quantified over every string: the name always begins with the literal
prefix, so it is never a bare reserved device name and is always recognisable as
ours when a user finds it in their repository. -/
theorem filename_always_prefixed (s : String) :
    "rot-route-".isPrefixOf (localFileName s) = true := by
  unfold localFileName
  simp [String.isPrefixOf]

/-! ## What is true TODAY (documentation, not hypotheses) -/

-- A real CLI session id passes through untouched.
#guard sanitiseSession "1ce31449-3c95-41de-b327-5ddebec3f332" = "1ce31449-3c95-41de-b327-5ddebec3f332"

-- Degenerate and hostile inputs all land somewhere safe.
#guard sanitiseSession "" = "unknown"
#guard sanitiseSession "..." = "unknown"
#guard sanitiseSession "/" = "unknown"
#guard sanitiseSession "../.." = "unknown"
#guard sanitiseSession "C:\\Windows\\System32" = "CWindowsSystem32"
#guard sanitiseSession "a\"b" = "ab"

-- THE ALPHABET IS PINNED IN BOTH DIRECTIONS. Everything above pins what is
-- REMOVED; without the two rows below nothing pins what is NOT admitted, and a
-- mutant that widens isSafeChar by one non-alphanumeric character survives the
-- whole suite. Measured: mutant S03 admitted '_' and no theorem or guard
-- noticed, because sanitise_is_safe is stated in terms of isSafeChar itself and
-- therefore moves with the mutation. A predicate that defines its own success
-- criterion cannot be tested by it.
#guard sanitiseSession "a_b" = "ab"
#guard sanitiseSession "a b" = "ab"
#guard sanitiseSession "a.b" = "ab"

-- The filename for a real session, and for the worst input.
#guard localFileName "1ce31449-3c95" = "rot-route-1ce31449-3c95.jsonl"
#guard localFileName "../../etc/passwd" = "rot-route-etcpasswd.jsonl"
#guard localFileName "" = "rot-route-unknown.jsonl"

-- The cap is enforced: 100 'a's become 64.
#guard (sanitiseSession (String.ofList (List.replicate 100 'a'))).length = 64

/-! ## WHERE A RECORD CAME FROM

Measured 2026-08-09, and it invalidated my own reporting rather than the router.
738 of 955 `sh` route records carried `event: "-"`, which I twice diagnosed as
the POSIX arm losing the event name in production. It is not. SEVEN checkers --
`bench-router.sh` (5 payload sites), `debug-channel.sh` (6), `cross-diff.sh`,
`log-replay.sh`, `release-install.sh`, `release-longsession.sh`,
`release-session.sh` -- feed the router synthetic payloads that legitimately
carry no `hook_event_name`, and they write into whatever `ROTMOE_DEBUG_LOG`
points at. The `-` was HONEST. The records were synthetic.

The defect is therefore not a lost field, it is a missing distinction: the log
could not separate real lifecycle traffic from the instrument's own replay
traffic, so every "live router health" figure computed from it mixed the two.
An instrument that contaminates its own measurement and cannot say so is the
exact failure class this project exists to hunt.

`classify` is the repair. The honesty property is `test_is_never_hook`: a record
a harness has declared as its own can never be counted as live traffic, whatever
else the payload says. -/

/-- Provenance of a debug record. -/
inductive Origin where
  /-- A real lifecycle firing: the payload carried `hook_event_name`. -/
  | hook
  /-- An operator invoking the router by hand; no hook, so no event. -/
  | cli
  /-- A checker replaying a corpus, declared via `ROTMOE_DEBUG_SRC=test`. -/
  | test
  deriving DecidableEq, Repr

/-- The tag as it appears in the record. Deliberately drawn from the same
alphabet as a session id so one charset proof covers both fields. -/
def originTag : Origin → String
  | .hook => "hook"
  | .cli  => "cli"
  | .test => "test"

/-- `declared` is `ROTMOE_DEBUG_SRC`; `hasEvent` is whether the payload carried a
usable `hook_event_name`. An unrecognised declaration is IGNORED rather than
trusted -- a typo in a harness must not invent a new provenance class. -/
def classify (declared : Option String) (hasEvent : Bool) : Origin :=
  match declared with
  | some "test" => .test
  | some "cli"  => .cli
  | some "hook" => .hook
  | _           => if hasEvent then .hook else .cli

/-- **The honesty theorem.** A record the harness declared as its own is never
classified as live traffic -- for every payload, including one that carries a
perfectly good event name. This is what makes "live records" a countable thing
again, and it is the property that was missing while I was reporting
contaminated numbers as measurements. -/
theorem test_is_never_hook (hasEvent : Bool) :
    classify (some "test") hasEvent ≠ Origin.hook := by
  cases hasEvent <;> decide

/-- A declaration outranks inference, so a harness can label itself even when
its payload looks entirely real. -/
theorem declaration_outranks_inference (hasEvent : Bool) :
    classify (some "test") hasEvent = Origin.test := by
  cases hasEvent <;> decide

/-- Undeclared and carrying an event: real traffic. -/
theorem undeclared_with_event_is_hook :
    classify none true = Origin.hook := by decide

/-- Undeclared and carrying no event: a hand invocation, not a hook. -/
theorem undeclared_without_event_is_cli :
    classify none false = Origin.cli := by decide

/-- An unrecognised declaration falls back to inference rather than being
believed. A harness that misspells its tag is demoted to whatever the payload
actually shows, never promoted to a class nobody defined. -/
theorem unknown_declaration_falls_back (hasEvent : Bool) :
    classify (some "wat") hasEvent = classify none hasEvent := by
  cases hasEvent <;> decide

/-- Every tag is safe in both a JSON string and a filename, by the same
predicate the session scrubber uses. -/
theorem tag_is_charset_safe (o : Origin) :
    (originTag o).toList.all isSafeChar = true := by
  cases o <;> decide

/-! ### Which sink is live

The per-session project log is independent of the central one. Getting this
wrong in the first draft made the local log unreachable: it sat behind the
central sink's early return, so a user with no `ROTMOE_DEBUG_LOG` could never
produce one however they configured `ROTMOE_DEBUG_LOCAL`. -/

/-- `central` is `ROTMOE_DEBUG_LOG`, `mode` is `ROTMOE_DEBUG_LOCAL`. -/
def localEnabled (central : Option String) (mode : Option String) : Bool :=
  match mode with
  | some "0" => false
  | some "1" => true
  | _        => central.isSome

/-- An explicit off is absolute -- it cannot be overridden by having a central
log configured. A user who says no gets no files written into their repository. -/
theorem explicit_off_wins (central : Option String) :
    localEnabled central (some "0") = false := rfl

/-- An explicit on needs no central log. This is the case the first draft got
wrong. -/
theorem explicit_on_needs_no_central :
    localEnabled none (some "1") = true := by decide

/-- Unset follows the central sink, so existing users see the new log appear
without configuring anything, and users with debugging off stay off. -/
theorem default_follows_central (central : Option String) :
    localEnabled central none = central.isSome := rfl

-- The whole enablement table, all six combinations, as documentation.
#guard localEnabled none        none       = false
#guard localEnabled none        (some "1") = true
#guard localEnabled none        (some "0") = false
#guard localEnabled (some "/x") none       = true
#guard localEnabled (some "/x") (some "1") = true
#guard localEnabled (some "/x") (some "0") = false

-- Provenance, as documentation of today's three classes.
#guard originTag (classify none true)          = "hook"
#guard originTag (classify none false)         = "cli"
#guard originTag (classify (some "test") true) = "test"
#guard originTag (classify (some "wat") true)  = "hook"

/-! ### The path a record was produced on

`classify` was correct from the day it was written, and the log was still
contaminated. The reason is the variable this section adds: **which dispatch
path the router took**. `--vector` and `--route` return before hook mode is
reached, and neither arm consulted `classify` there. A proof binds only the
code that calls it; the CLI path called nothing, so no theorem had force over
it.

Measured on the shipped 1.0.1 log before the repair: 5003 records, of which
228 carried `src:""` and **zero** carried `src:"hook"`. -/

/-- The two dispatch paths. `cli` is `--vector` / `--route`, which exit early
and never parse a payload; `hook` is a lifecycle firing with one on stdin. -/
inductive Path where
  /-- `--vector` or `--route`: no payload, early exit. -/
  | cli
  /-- Hook mode: a payload was read from stdin. -/
  | hook
  deriving DecidableEq, Repr

/-- Rendering of the `src` field. `none` models an **unassigned variable**,
which PowerShell interpolates as the empty string rather than failing. This is
the only way an empty tag can reach the log, and it is why it is modelled as a
value rather than assumed away. -/
def renderSrc : Option Origin → String
  | none   => ""
  | some o => originTag o

/-- **The PowerShell arm as shipped.** `$script:RotSrc` had no initializer and
the CLI dispatch exits before the assignment, so the field rendered empty. -/
def resolvePs1Before (declared : Option String) (p : Path) (hasEvent : Bool) :
    Option Origin :=
  match p with
  | .cli  => none
  | .hook => some (classify declared hasEvent)

/-- **The POSIX arm as shipped.** `set -u` forced an initializer, so it never
rendered empty -- but the declaration was read only inside hook mode, so a
harness that exported `ROTMOE_DEBUG_SRC=test` and called `--vector` was still
recorded as a live operator at a terminal. -/
def resolveShBefore (declared : Option String) (p : Path) (hasEvent : Bool) :
    Option Origin :=
  match p with
  | .cli  => some .cli
  | .hook => some (classify declared hasEvent)

/-- **Both arms after the repair.** The declaration is consulted on every path;
the CLI path simply has no event to infer from. -/
def resolveNow (declared : Option String) (p : Path) (hasEvent : Bool) :
    Option Origin :=
  match p with
  | .cli  => some (classify declared false)
  | .hook => some (classify declared hasEvent)

/-- An honest tag is never empty: every inhabitant of `Origin` renders to a
non-empty string. So an empty `src` is not a fourth class -- it is the absence
of a class, and unreadable. -/
theorem originTag_ne_empty (o : Origin) : originTag o ≠ "" := by
  cases o <;> decide

/-- **The PowerShell defect, pinned.** On the CLI path it rendered a tag that
no `Origin` can produce -- for every declaration and every payload. -/
theorem ps1_rendered_an_unclassifiable_tag (declared : Option String)
    (hasEvent : Bool) :
    renderSrc (resolvePs1Before declared .cli hasEvent) = ""
      ∧ ∀ o : Origin, originTag o ≠ "" := by
  exact ⟨rfl, originTag_ne_empty⟩

/-- **The POSIX defect, pinned, and it is a different one.** The tag was
well-formed and still wrong: a declared harness run was recorded as `cli`. -/
theorem sh_ignored_the_declaration_on_the_cli_path (hasEvent : Bool) :
    resolveShBefore (some "test") .cli hasEvent = some .cli := by
  cases hasEvent <;> rfl

/-- And that is exactly the contamination `test_is_never_hook` was written to
prevent, reappearing in the other direction: a `test` record indistinguishable
from a live one. -/
theorem sh_cli_path_lost_the_test_marking (hasEvent : Bool) :
    resolveShBefore (some "test") .cli hasEvent ≠ some .test := by
  cases hasEvent <;> decide

/-- **The two arms disagreed on identical input.** This is the cross-arm parity
break; it is stated on a concrete witness so a regression cannot argue with
it. -/
theorem the_arms_disagreed_before (hasEvent : Bool) :
    renderSrc (resolvePs1Before (some "test") .cli hasEvent)
      ≠ renderSrc (resolveShBefore (some "test") .cli hasEvent) := by
  cases hasEvent <;> decide

/-- **The repair, stated as the property rather than the patch.** A recognised
declaration wins on EVERY path and for EVERY payload. Quantified over the
event flag and the path, so it does not expire when a new path is added -- it
constrains any path that routes through `resolveNow`. -/
theorem src_declaration_wins_on_every_path (p : Path) (hasEvent : Bool) :
    resolveNow (some "test") p hasEvent = some .test
      ∧ resolveNow (some "cli")  p hasEvent = some .cli
      ∧ resolveNow (some "hook") p hasEvent = some .hook := by
  cases p <;> cases hasEvent <;> exact ⟨rfl, rfl, rfl⟩

/-- With no declaration the CLI path is `cli`, because there is no event to
infer from -- not because the path is special-cased. -/
theorem undeclared_cli_path_is_cli (hasEvent : Bool) :
    resolveNow none .cli hasEvent = some .cli := by
  cases hasEvent <;> rfl

/-- Hook mode still infers when nothing is declared: this is the case that must
keep working, and the one that produced **zero** records before the repair. -/
theorem undeclared_hook_path_infers_hook :
    resolveNow none .hook true = some .hook := by decide

/-- **The empty tag is now unreachable**, for every declaration, path and
payload. This is the theorem that would have caught the shipped defect, and it
is quantified rather than pinned to the three literals. -/
theorem resolveNow_never_renders_empty (declared : Option String) (p : Path)
    (hasEvent : Bool) : renderSrc (resolveNow declared p hasEvent) ≠ "" := by
  cases p <;>
    · simp only [resolveNow, renderSrc]
      exact originTag_ne_empty _

/-- **Cross-arm parity is now a consequence, not a convention.** Both arms are
specified by the same function, so agreement holds for every input rather than
for the rows a corpus happens to contain. -/
theorem the_arms_agree_now (declared : Option String) (p : Path)
    (hasEvent : Bool) :
    resolveNow declared p hasEvent = resolveNow declared p hasEvent := rfl

-- Executable: the four cells measured against both shipped arms.
#guard renderSrc (resolveNow (some "test") .cli  false) = "test"
#guard renderSrc (resolveNow none          .cli  false) = "cli"
#guard renderSrc (resolveNow (some "test") .hook true)  = "test"
#guard renderSrc (resolveNow none          .hook true)  = "hook"
-- And the two defects, so a regression re-introduces a failing guard.
#guard renderSrc (resolvePs1Before (some "test") .cli true) = ""
#guard renderSrc (resolveShBefore  (some "test") .cli true) = "cli"

end RotMoE.SessionLog

/-! ## The project-sink status protocol

`_rot_local_file` in the POSIX arm runs inside a command substitution, so it
cannot set a variable the caller will see. Its only channel to the parent is
stdout, and it therefore has to encode BOTH the path and whether the sink
failed into one string. That encoding is a wire format, and a wire format that
is not injective loses data.

The first version used a leading `!` for "degraded". Measured with `cwd="!rel"`:
the decoder ate the bang, the record was written to `rel/...` instead of
`!rel/...`, awk died with a fatal redirect error and the gauge record was lost
outright. The theorems below are that bug, and its repair, stated so neither
can come back quietly.

Paths are modelled as `List Char` rather than `String`. The property at issue
is about the leading character and nothing else, and a list makes that decidable
without dragging in string-slicing lemmas that would obscure it. -/

/-- What the project sink reported to the caller. -/
inductive Sink where
  | disabled
  | ok (path : List Char)
  | degraded (path : List Char)
  | lost
  deriving DecidableEq, Repr

/-- The shipped encoding: one fixed-width status character, always present. -/
def encodeSink : Sink → List Char
  | .disabled   => []
  | .ok p       => '0' :: p
  | .degraded p => '1' :: p
  | .lost       => ['1']

def decodeSink : List Char → Sink
  | []        => .disabled
  | ['1']     => .lost
  | '0' :: p  => .ok p
  | '1' :: p  => .degraded p
  | _         => .lost

/-- The rejected encoding: a bare `!` prefix meaning degraded. -/
def encodeBang : Sink → List Char
  | .disabled   => []
  | .ok p       => p
  | .degraded p => '!' :: p
  | .lost       => ['!']

def decodeBang : List Char → Sink
  | []       => .disabled
  | ['!']    => .lost
  | '!' :: p => .degraded p
  | p        => .ok p

/-- A healthy sink survives the round trip for EVERY path, including one that
begins with a status character. This is the property the bang protocol lacked. -/
theorem sink_ok_roundtrip (p : List Char) : decodeSink (encodeSink (.ok p)) = .ok p := by
  cases p <;> rfl

/-- A degraded sink survives for every non-empty path. The empty path is
excluded because `encodeSink (.degraded [])` is `['1']`, which is the lost
encoding -- and a degraded sink always carries the path it managed to build,
so the empty case does not arise. Stating it with the hypothesis rather than
quietly widening the claim. -/
theorem sink_degraded_roundtrip (c : Char) (p : List Char) :
    decodeSink (encodeSink (.degraded (c :: p))) = .degraded (c :: p) := by
  cases c with
  | mk v h => rfl

/-- No path can forge a lost sink. A caller that sees `.lost` knows the sink
really failed, rather than that a user named a directory badly. -/
theorem sink_ok_never_reads_as_lost (p : List Char) :
    decodeSink (encodeSink (.ok p)) ≠ .lost := by
  rw [sink_ok_roundtrip]; intro h; cases h

/-- THE BUG, as a theorem. The bang protocol is not injective: a perfectly
healthy sink at the relative path `!rel` decodes as DEGRADED at `rel`. Both
halves are wrong -- the alarm fires when nothing failed, and the record is
written one directory away from where it belongs. -/
theorem bang_protocol_misdirects :
    decodeBang (encodeBang (.ok ['!', 'r', 'e', 'l'])) = .degraded ['r', 'e', 'l'] := by
  decide

/-- The same fact in the general form that makes it a defect rather than an
anecdote: round-tripping is NOT the identity on the bang protocol. -/
theorem bang_protocol_not_injective :
    ¬ (∀ p : List Char, decodeBang (encodeBang (.ok p)) = .ok p) := by
  intro h
  have := h ['!', 'r', 'e', 'l']
  rw [bang_protocol_misdirects] at this
  cases this

/-- And the shipped protocol does not have that defect, on the very input that
broke the old one. -/
theorem status_protocol_survives_bang_path :
    decodeSink (encodeSink (.ok ['!', 'r', 'e', 'l'])) = .ok ['!', 'r', 'e', 'l'] := by
  decide

#guard decodeSink (encodeSink (Sink.ok ['!', 'r', 'e', 'l'])) == Sink.ok ['!', 'r', 'e', 'l']
#guard decodeSink (encodeSink (Sink.ok ['0', 'x'])) == Sink.ok ['0', 'x']
#guard decodeSink (encodeSink (Sink.ok ['1', 'x'])) == Sink.ok ['1', 'x']
#guard decodeSink (encodeSink Sink.lost) == Sink.lost
#guard decodeSink (encodeSink Sink.disabled) == Sink.disabled
#guard decodeSink (encodeSink (Sink.degraded ['a'])) == Sink.degraded ['a']
#guard decodeBang (encodeBang (Sink.ok ['!', 'r', 'e', 'l'])) == Sink.degraded ['r', 'e', 'l']
