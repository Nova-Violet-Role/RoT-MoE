/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A citation gate is only a gate while it can still see

`checker/repo-complete.sh` reads every backticked `snake_case` name on
`README.md` and requires each to resolve to a real declaration under
`lean/Proofs/`. That check has two failure modes, and only one of them is loud.

The loud one is a **ghost**: the page cites `foo_bar`, no such theorem exists,
the gate reports it. Fine.

The quiet one is the gate going **blind**. If the extractor stops matching —
a changed backtick convention, a regex that no longer fires — the citation set
becomes empty, the ghost set is empty *because there is nothing to check*, and
the gate reports a pass. Nothing on the page was verified and the report says
everything was. That is the direction that costs you, so this module makes
"the extractor found enough names" part of what passing MEANS, not a habit.

Underneath both sits the scanner that decides what a "real declaration" is, and
it has been got wrong four times in this repository by four different scanners.
Lean block comments **nest**. A doc comment that quotes a fenced `theorem` line
at column 0 is not a declaration, and a scanner using a boolean in-comment flag
will emit it. `naive_flag_is_fooled` exhibits the exact input on which the two
disagree, so the counter in the shipped `awk` is a proved requirement rather
than a preference.

The instrument for the gate itself is `checker/repo-complete.sh`; this module
says what its two assertions mean.
-/

namespace RotMoE
namespace Cite

/-- A Lean source reduced to the only three things the citation scanner must
tell apart: a block-comment opener, a closer, and a declaration at column 0.

NOTE: the constructor doc comments below deliberately do NOT contain the literal
comment delimiters they describe. Writing them out cost a build here: the opener
inside a doc comment NESTS, swallowing the constructor on the next line, and the
closer inside the next one terminated its doc comment early. The module about
nested-comment scanning was broken by nested comments in its own documentation,
which is the most direct possible evidence that the boolean-flag scanner below is
not a strawman. -/
inductive Tok where
  /-- A block-comment opener. -/
  | bopen
  /-- A block-comment closer. -/
  | bclose
  /-- A `theorem` or `lemma` declaration starting at column 0. -/
  | decl (name : String)
  deriving DecidableEq, Repr

/-- The shipped scanner: a **depth counter**, saturating at zero exactly as the
`awk` does (`if (depth > 0) depth--`). A declaration counts only at depth 0. -/
def scanDepth : List Tok → Nat → List String
  | [], _ => []
  | Tok.bopen :: ts, d => scanDepth ts (d + 1)
  | Tok.bclose :: ts, d => scanDepth ts (d - 1)
  | Tok.decl n :: ts, d => if d = 0 then n :: scanDepth ts d else scanDepth ts d

/-- The naive scanner: a **boolean flag**. This is the one that has been written
four times here and is wrong every time, because it cannot represent nesting. -/
def scanFlag : List Tok → Bool → List String
  | [], _ => []
  | Tok.bopen :: ts, _ => scanFlag ts true
  | Tok.bclose :: ts, _ => scanFlag ts false
  | Tok.decl n :: ts, b => if b then scanFlag ts b else n :: scanFlag ts b

/-- Cited names with no matching declaration. -/
def ghosts (cited real : List String) : List String :=
  cited.filter (fun c => !real.contains c)

/-- The gate, as shipped: **no ghosts AND the extractor still sees enough**.
The second conjunct is the whole point — without it an extractor that matches
nothing reports a pass. -/
def gatePass (cited real : List String) (floor : Nat) : Bool :=
  (ghosts cited real).isEmpty && floor ≤ cited.length

/-- **The nested-comment defect, exhibited.** One input on which the two
scanners disagree: a doc comment that opens, nests a second comment quoting a
`theorem` line, and closes. The counter emits only the real declaration; the
boolean flag emits the quoted one too, because the INNER closer clears its
single bit and the flag then believes it is back in code. This is the input that
produced a duplicate `lead_does_not_shrink` in an earlier scanner here.

(The delimiter is spelled out in words for the third time in this file, and for
the same reason each time.) -/
theorem naive_flag_is_fooled :
    scanDepth [Tok.bopen, Tok.bopen, Tok.bclose, Tok.decl "quoted",
               Tok.bclose, Tok.decl "real"] 0 = ["real"] ∧
    scanFlag  [Tok.bopen, Tok.bopen, Tok.bclose, Tok.decl "quoted",
               Tok.bclose, Tok.decl "real"] false = ["quoted", "real"] := by
  constructor <;> decide

/-- **A declaration inside a comment is never emitted by the counter** — for
every depth reached by opening, and every tail. Stated over an arbitrary `d`
rather than the witness above: the property is about nesting in general. -/
theorem commented_decl_is_not_a_declaration (n : String) (ts : List Tok) (d : Nat) :
    scanDepth (Tok.decl n :: ts) (d + 1) = scanDepth ts (d + 1) := by
  simp [scanDepth]

/-- **A declaration at depth 0 IS emitted.** Non-vacuity for the scanner:
without this, a `scanDepth` that returned `[]` on every input would satisfy the
theorem above and the gate would verify nothing. -/
theorem real_decl_is_seen (n : String) (ts : List Tok) :
    scanDepth (Tok.decl n :: ts) 0 = n :: scanDepth ts 0 := by
  simp [scanDepth]

/-- **A cited name that does not exist is reported.** -/
theorem ghost_is_reported (c : String) (cited real : List String)
    (hc : c ∈ cited) (hr : ¬ real.contains c) :
    c ∈ ghosts cited real := by
  simp only [ghosts, List.mem_filter, Bool.not_eq_true'] at *
  exact ⟨hc, by simpa using hr⟩

/-- **No ghosts means every citation resolved.** The converse direction, so the
empty ghost list cannot mean something weaker than it claims. -/
theorem no_ghosts_means_all_resolve (cited real : List String)
    (h : ghosts cited real = []) (c : String) (hc : c ∈ cited) :
    real.contains c = true := by
  by_cases hr : real.contains c = true
  · exact hr
  · exact absurd (ghost_is_reported c cited real hc hr) (by simp [h])

/-- **A blinded extractor does NOT pass.** The quiet failure, forbidden: with no
citations extracted, the ghost set is empty for the wrong reason, and any floor
of at least one rejects it. This is the theorem the `ncit >= 40` assertion in
`checker/repo-complete.sh` exists to enforce. -/
theorem blind_extractor_fails (real : List String) (floor : Nat) (hf : 0 < floor) :
    gatePass [] real floor = false := by
  simp [gatePass, ghosts]
  omega

/-- **…and it fails even though there are no ghosts.** The two conjuncts are
independent: emptiness of the ghost set is not evidence, so a gate written with
the ghost check alone would have passed the blinded case. -/
theorem blind_has_no_ghosts (real : List String) :
    ghosts [] real = [] := by
  simp [ghosts]

/-- **The gate can pass.** Non-vacuity: a page whose citations all resolve and
whose extractor saw enough names is accepted. Without this the module would
permit a `gatePass` that is constantly false — a gate that can never succeed,
which is green forever and gets deleted the first time it must say yes. -/
theorem gate_can_pass :
    gatePass ["route_fires", "lead_does_not_shrink"]
             ["lead_does_not_shrink", "route_fires", "gauge_is_bounded"] 2 = true := by
  decide

/-- **Raising the floor above what was extracted rejects.** The floor is a real
threshold, not decoration: the same citation set that passes at 2 fails at 3. -/
theorem floor_binds :
    gatePass ["route_fires", "lead_does_not_shrink"]
             ["lead_does_not_shrink", "route_fires", "gauge_is_bounded"] 3 = false := by
  decide

/-- **Passing implies both halves.** The bridge back to the checker: a green
citation gate really does mean every name resolved AND the extractor was awake. -/
theorem pass_implies_both (cited real : List String) (floor : Nat)
    (h : gatePass cited real floor = true) :
    ghosts cited real = [] ∧ floor ≤ cited.length := by
  simp [gatePass, List.isEmpty_iff] at h
  exact h

/-- A ghost in a non-empty citation set is caught, executed. -/
example : gatePass ["real_one", "ghost_one"] ["real_one"] 1 = false := by decide

/-- An extractor that matched nothing is refused, executed. -/
example : gatePass [] ["real_one"] 1 = false := by decide

/-- The counter and the flag agree when nothing nests — so the defect is
specifically about nesting, not about comments in general. -/
example : scanDepth [Tok.bopen, Tok.decl "quoted", Tok.bclose, Tok.decl "real"] 0
        = scanFlag  [Tok.bopen, Tok.decl "quoted", Tok.bclose, Tok.decl "real"] false := by
  decide

end Cite
end RotMoE
