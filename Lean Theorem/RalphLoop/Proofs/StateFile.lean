/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Authors: Saimono
-/

/-! # Ralph Loop state-file round-trip

The `ralph-loop` plugin persists the task in `.claude/ralph-loop.local.md` as a
markdown file with YAML frontmatter, and the Stop hook feeds the body back on
every iteration. The body is recovered with one awk program
(`hooks/stop-hook.sh:150`):

```
awk '/^---$/{i++; next} i>=2' .claude/ralph-loop.local.md
```

`awkExtract` below is that program, transcribed. The point of the file is a
**silent** defect: the `next` consumes *every* line equal to `---`, not only the
two frontmatter delimiters, so a horizontal rule inside the prompt is deleted
from what the loop feeds back. Measured first, then settled here:

* `roundTrip` — with no bare `---` in the body, extraction is exact.
* `extract_eq_filter` — in general, extraction returns the body with **all**
  `---` lines removed, which is the defect stated as an equation rather than as
  an anecdote about one input.
* `roundTrip_iff` — the two above joined: extraction is faithful **iff** the
  body has no bare `---`. This is what licences the launcher's guard, and it
  says the guard is not merely sufficient but necessary.

Core Lean only; no mathlib is needed.
-/

namespace RalphLoop

/-- The frontmatter delimiter, `---`. -/
def sep : String := "---"

/--
`hooks/stop-hook.sh:150` transcribed: `awk '/^---$/{i++; next} i>=2'`.
`i` counts delimiters seen so far; a line is emitted only when `2 ≤ i` and the
line is not itself a delimiter (the `next` skips it).
-/
def awkExtract : Nat → List String → List String
  | _, [] => []
  | i, l :: ls =>
      if l = sep then awkExtract (i + 1) ls
      else if 2 ≤ i then l :: awkExtract i ls
      else awkExtract i ls

/--
`scripts/setup-ralph-loop.sh:140-151` transcribed: the heredoc emits the opening
delimiter, the frontmatter, the closing delimiter, a blank line, then the prompt.
-/
def stateFile (fm body : List String) : List String :=
  sep :: (fm ++ sep :: "" :: body)

/-- The launcher's guard, as a predicate: no line of the prompt is a bare `---`. -/
def noBareSep (ls : List String) : Prop := ∀ l ∈ ls, l ≠ sep

instance (ls : List String) : Decidable (noBareSep ls) := by
  unfold noBareSep; infer_instance

/-! ### Behaviour once both delimiters have been seen -/

/-- Past the second delimiter, awk emits exactly the non-`---` lines. -/
theorem extract_eq_filter (i : Nat) (h : 2 ≤ i) (ls : List String) :
    awkExtract i ls = ls.filter (fun l => l != sep) := by
  induction ls generalizing i with
  | nil => simp [awkExtract]
  | cons l ls ih =>
      by_cases hl : l = sep
      · have h2 : 2 ≤ i + 1 := by omega
        simp [awkExtract, hl, List.filter, ih (i + 1) h2]
      · have hb : (l != sep) = true := by simp [hl]
        simp [awkExtract, hl, h, List.filter, hb, ih i h]

/-! ### Behaviour before the second delimiter -/

/-- Frontmatter lines (none of which is `---`) are skipped while `i < 2`. -/
theorem skip_frontmatter (fm : List String) (hfm : noBareSep fm) (i : Nat)
    (hi : i < 2) (rest : List String) :
    awkExtract i (fm ++ rest) = awkExtract i rest := by
  induction fm with
  | nil => simp
  | cons l fm ih =>
      have hl : l ≠ sep := hfm l (by simp)
      have hfm' : noBareSep fm := fun x hx => hfm x (by simp [hx])
      have : ¬ (2 ≤ i) := by omega
      simp [awkExtract, hl, this, ih hfm']

/-! ### The round trip -/

/--
**The defect, as an equation.** With no assumption on the prompt at all, the
Stop hook feeds back the prompt with *every* bare `---` line deleted. This is the
statement the launcher's guard exists to avoid, and it holds for any body.
-/
theorem extract_deletes_seps (fm body : List String) (hfm : noBareSep fm) :
    awkExtract 0 (stateFile fm body) = "" :: body.filter (fun l => l != sep) := by
  have hb : (("" : String) != sep) = true := by decide
  have h0 : awkExtract 0 (stateFile fm body) = awkExtract 1 (fm ++ sep :: "" :: body) := by
    simp [stateFile, awkExtract]
  have h1 : awkExtract 1 (sep :: "" :: body) = awkExtract 2 ("" :: body) := by
    simp [awkExtract]
  rw [h0, skip_frontmatter fm hfm 1 (by omega), h1, extract_eq_filter 2 (by omega),
    List.filter_cons, hb]
  simp

/--
**Soundness of the guard.** If neither the frontmatter nor the prompt contains a
bare `---`, the Stop hook recovers the prompt exactly (after the blank separator
line the heredoc writes).
-/
theorem roundTrip (fm body : List String)
    (hfm : noBareSep fm) (hbody : noBareSep body) :
    awkExtract 0 (stateFile fm body) = "" :: body := by
  have hbody' : body.filter (fun l => l != sep) = body :=
    List.filter_eq_self.mpr fun a ha => by simp [hbody a ha]
  rw [extract_deletes_seps fm body hfm, hbody']

/--
**The guard is necessary, not merely sufficient.** Extraction is faithful
exactly when the prompt has no bare `---`. Rejecting such a prompt therefore
discards no case the loop would have handled correctly.
-/
theorem roundTrip_iff (fm body : List String) (hfm : noBareSep fm) :
    awkExtract 0 (stateFile fm body) = "" :: body ↔ noBareSep body := by
  constructor
  · intro h a ha hsep
    rw [extract_deletes_seps fm body hfm] at h
    have hf : body.filter (fun l => l != sep) = body := by simpa using h
    have hmem : a ∉ body.filter (fun l => l != sep) := by
      simp [List.mem_filter, hsep]
    rw [hf] at hmem
    exact hmem ha
  · intro hbody
    exact roundTrip fm body hfm hbody

/-! ### The engine's two repairs

`ralph-engine.sh` does not merely *reject* a goal the loop would corrupt; it
repairs it, because refusing a legitimate goal is its own defect. Two repairs,
and each needs to be shown total rather than merely tried:

* `sanitize` rewrites a bare `---` line to `***`, which markdown renders the
  same. It must always produce a goal the round trip carries intact, and must
  leave an already-clean goal untouched.
* `normalizeEOL` collapses CRLF and lone CR to LF. Measured first: the goal
  lifted out of the transcript arrived with CRLF, the stored file then differed
  from what the state file read back, and `write_state` refused to arm the loop.
-/

/-- The rewrite the launcher applies: a bare `---` line becomes `***`. -/
def sanitizeLine (l : String) : String := if l = sep then "***" else l

/-- `sanitize` applied to the whole goal body. -/
def sanitize (ls : List String) : List String := ls.map sanitizeLine

/--
**The repair always succeeds.** No goal survives `sanitize` still containing a
bare `---`, so the launcher never has to refuse a goal it was handed.
-/
theorem sanitize_noBareSep (ls : List String) : noBareSep (sanitize ls) := by
  intro l hl
  simp only [sanitize, List.mem_map] at hl
  obtain ⟨a, _, rfl⟩ := hl
  unfold sanitizeLine
  by_cases h : a = sep
  · simp [h]; decide
  · simp [h]

/--
**The repair is a no-op on a clean goal.** A goal with no bare `---` is passed
through byte for byte, so the launcher cannot mangle text it had no business
touching.
-/
theorem sanitize_id_of_clean (ls : List String) (h : noBareSep ls) : sanitize ls = ls := by
  induction ls with
  | nil => rfl
  | cons a as ih =>
      have ha : a ≠ sep := h a (by simp)
      have has : noBareSep as := fun x hx => h x (by simp [hx])
      simpa [sanitize, sanitizeLine, ha] using ih has

/--
**The engine's guarantee, unconditional.** After `sanitize`, the Stop hook feeds
the goal back exactly — for *every* input body, with no hypothesis on it at all.
This is what licenses the launcher arming the loop rather than refusing.
-/
theorem engine_roundTrip (fm body : List String) (hfm : noBareSep fm) :
    awkExtract 0 (stateFile fm (sanitize body)) = "" :: sanitize body :=
  roundTrip fm (sanitize body) hfm (sanitize_noBareSep body)

/-- CRLF and lone CR both collapse to LF, as `perl -pe 's/\r\n/\n/g; s/\r/\n/g'`. -/
def normalizeEOL : List Char → List Char
  | [] => []
  | '\r' :: '\n' :: cs => '\n' :: normalizeEOL cs
  | '\r' :: cs => '\n' :: normalizeEOL cs
  | c :: cs => c :: normalizeEOL cs

/--
**No carriage return survives.** The stored goal is LF-only, which is exactly the
precondition `write_state`'s round-trip check was failing on before the fix.
-/
theorem normalizeEOL_no_cr (cs : List Char) : '\r' ∉ normalizeEOL cs := by
  induction cs using normalizeEOL.induct <;> simp_all [normalizeEOL] <;>
    (intro h; subst h; simp_all)

/-- Normalising twice is normalising once: the repair is stable under re-entry. -/
theorem normalizeEOL_idem (cs : List Char) :
    normalizeEOL (normalizeEOL cs) = normalizeEOL cs := by
  induction cs using normalizeEOL.induct <;> simp_all [normalizeEOL]

/-! ### Execution: the definitions agree with the shell on concrete input -/

/-- The frontmatter the setup script actually writes. -/
def sampleFm : List String :=
  ["active: true", "iteration: 1", "session_id: 7c62", "max_iterations: 0",
   "completion_promise: null", "started_at: \"2026-08-07T01:44:26Z\""]

-- Measured against the shell: `line one / --- / line three` comes back mangled.
-- The shell run printed exactly `line one` then `line three`; so does this.
#guard awkExtract 0 (stateFile sampleFm ["line one", sep, "line three"])
        = ["", "line one", "line three"]

-- The same prompt without the rule comes back whole.
#guard awkExtract 0 (stateFile sampleFm ["line one", "***", "line three"])
        = ["", "line one", "***", "line three"]

-- A blockquote-heavy prompt, the shape that broke the stock command, survives.
#guard awkExtract 0 (stateFile sampleFm
        ["[CLEAR CONDITION START]--->", "", "> [!GOAL]", "> Fortify it.",
         "<---[CLEAR CONDITION END]--->"])
        = ["", "[CLEAR CONDITION START]--->", "", "> [!GOAL]", "> Fortify it.",
           "<---[CLEAR CONDITION END]--->"]

-- The guard is decidable, so the launcher's check is the same predicate.
#guard decide (noBareSep ["line one", "***", "line three"]) = true
#guard decide (noBareSep ["line one", sep, "line three"]) = false

-- `--->` is not `---`: the guard does not over-reject the arrow markers.
#guard decide (noBareSep ["--->", "<---", "----"]) = true

end RalphLoop
