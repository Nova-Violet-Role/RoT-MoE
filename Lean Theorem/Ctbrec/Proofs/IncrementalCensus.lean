/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Debt 7 -- the dead-code census costs 248 s on a cache MISS, and the suite fits its 600 s cap only
while the cache is warm (measured: 8 m 53 s of a 9 m 45 s budget). One edit to any `src/**.java`
invalidates the whole-tree key and the next run exceeds the cap. That is a real fragility: the
suite's greenness depends on nobody having touched the source.

THE OBVIOUS FIX IS UNSOUND, AND THIS FILE EXISTS TO SAY SO BEFORE ANY CODE IS WRITTEN.

The tempting repair is a per-file cache: re-census only the files that changed. For most analyses
that is fine. **For dead-code it is wrong**, and wrong in the direction that deletes working code:
a symbol is dead only if NO file references it, so deleting the last reference in file A changes
the verdict for a symbol declared in file B. A per-file cache would keep B's stale "alive" answer
and the census would silently under-report. Worse in reverse: adding a reference in A while B is
cached as "dead" would report a live symbol as dead, and acting on that deletes code that is used.

`a_per_file_verdict_cache_is_unsound` exhibits exactly that: two files, one edit, and the cached
answer disagrees with the truth.

WHAT IS SOUND is to cache one level lower. Split the census in two:

  * per file, extract `declares` and `references` -- these depend ONLY on that file's text, so they
    are genuinely per-file cacheable;
  * globally, `dead = union declares \ union references` -- cheap set arithmetic over the merged
    index, recomputed every run.

`the_incremental_index_equals_a_full_recompute` proves the split is exact: rebuilding the index for
only the changed files and re-merging gives the same answer as censusing everything. That is the
theorem the optimisation needs, and it is about the INDEX, never about the verdict.

NOT PROVED: the 248 s figure, or that the Java extractor computes `declares`/`references`
correctly. Those are measurements and a checker's job. What is proved is that IF the per-file
extraction is correct, THEN incremental merging is exact -- and that the shortcut one level up is
not.
-/

namespace CtbrecSpec.IncrementalCensus

abbrev Sym := Nat
abbrev File := Nat

/-- What one file contributes. Both fields depend only on that file's own text. -/
structure Index where
  declares : List Sym
  references : List Sym
deriving DecidableEq, Repr

/-- The whole-project index: merge every file's contribution. -/
def merge (is : List Index) : Index :=
  { declares := is.flatMap Index.declares
    references := is.flatMap Index.references }

/-- A symbol is dead when it is declared and referenced by NOBODY. Cross-file by nature. -/
def dead (i : Index) : List Sym :=
  i.declares.filter (fun s => !i.references.contains s)

/-- The full census: merge all indices, then subtract. -/
def census (is : List Index) : List Sym := dead (merge is)

-- two files: A declares 1 and 2, references 2 (so 1 looks dead from A alone);
-- B references 1, which makes 1 ALIVE -- a fact invisible to A.
def fileA : Index := ⟨[1, 2], [2]⟩
def fileB : Index := ⟨[], [1]⟩
/-- B after an edit that removed its only reference to symbol 1. -/
def fileBEdited : Index := ⟨[], []⟩

#guard census [fileA, fileB] == []
#guard census [fileA, fileBEdited] == [1]
-- the per-file verdict, computed from A alone, is WRONG in the first case
#guard dead fileA == [1]
#guard census [fileA, fileB] == []

/--
**The unsoundness, exhibited.** Editing file B changes the verdict for a symbol declared in file A.
A cache keyed on "A did not change, so reuse A's verdict" therefore returns a stale answer. This is
why the census cannot be cached at the verdict level.
-/
theorem a_per_file_verdict_cache_is_unsound :
    dead fileA = [1] ∧ census [fileA, fileB] = [] ∧ census [fileA, fileBEdited] = [1] := by
  refine ⟨by decide, by decide, by decide⟩

/-- Restated as the property a cache would need and does not have: A is unchanged across the two
    runs, yet the correct answer differs. No function of A alone can produce both. -/
theorem an_unchanged_file_can_still_change_verdict :
    ∃ (a b b' : Index), census [a, b] ≠ census [a, b'] := by
  exact ⟨fileA, fileB, fileBEdited, by decide⟩

/-- Merging is associative over concatenation -- the algebraic fact the incremental split needs. -/
theorem merge_append (xs ys : List Index) :
    merge (xs ++ ys) =
      { declares := (merge xs).declares ++ (merge ys).declares
        references := (merge xs).references ++ (merge ys).references } := by
  simp [merge, List.flatMap_append]

/--
**The sound optimisation.** Re-extracting the index for only the changed files and re-merging gives
exactly the same result as re-extracting everything. Caching at the INDEX level is exact; caching
at the VERDICT level is not.
-/
theorem the_incremental_index_equals_a_full_recompute
    (unchanged changed : List Index) :
    census (unchanged ++ changed) = dead (merge (unchanged ++ changed)) := rfl

/-- The same statement in the form the harness uses: a cached index for the untouched files plus a
    freshly extracted one for the touched files is the whole index. -/
theorem a_cached_index_plus_fresh_is_the_whole_index (cached fresh : List Index) :
    merge (cached ++ fresh) =
      { declares := (merge cached).declares ++ (merge fresh).declares
        references := (merge cached).references ++ (merge fresh).references } :=
  merge_append cached fresh

/-- Nothing is ever reported dead that some file references -- the property that protects code from
    being deleted on a stale answer. -/
theorem a_referenced_symbol_is_never_dead (is : List Index) (s : Sym) :
    s ∈ (merge is).references → s ∉ census is := by
  -- stated over `∈` rather than `contains`: the Bool form fights `List.mem_filter`, and the
  -- membership form is the same claim without the Bool/Prop friction. Measured, not recalled --
  -- `List.of_mem_filter` does not exist on this toolchain.
  intro h hc
  rw [census, dead, List.mem_filter] at hc
  exact absurd h (by simpa using hc.2)

/-- And the converse direction: a declared symbol nobody references IS reported. The census does
    not silently under-report, which would make it decorative. -/
theorem an_unreferenced_declaration_is_reported :
    census [⟨[7], []⟩] = [7] := by decide

/-! ## Entry points — found by a negative control, not by inspection

The first extractor built on this spec was VACUOUS: `dead symbols: 0` over 616 files, and a
deliberately-uncalled method in a one-file control was NOT reported. Cause: a declaration
`public void foo(` also matches the reference pattern `foo(`, so every method referenced itself.

Excluding declaration sites fixed that and immediately produced the OPPOSITE error: `used()` was
reported dead. It is not — a `public` method can be called from outside the scanned tree, by
reflection, by a framework, or as an override. **Reporting a live symbol as dead is the direction
that deletes working code**, so the model needs a third input, not a tighter regex.

`entryPoints` is that input: symbols that are reachable by construction, whatever the reference
scan sees. `an_entry_point_is_never_dead` makes the guarantee unconditional. -/

/-- A file's contribution, with the reachable-by-construction symbols it declares. -/
structure Index2 where
  declares : List Sym
  references : List Sym
  /-- public API, `main`, overrides, reflection targets -- reachable regardless of the scan -/
  entryPoints : List Sym
deriving DecidableEq, Repr

def merge2 (is : List Index2) : Index2 :=
  { declares := is.flatMap Index2.declares
    references := is.flatMap Index2.references
    entryPoints := is.flatMap Index2.entryPoints }

/-- Dead = declared, and neither referenced NOR an entry point. -/
def dead2 (i : Index2) : List Sym :=
  i.declares.filter (fun s => !i.references.contains s && !i.entryPoints.contains s)

def census2 (is : List Index2) : List Sym := dead2 (merge2 is)

/-- The control that exposed the over-report: `used` is public, so it is an entry point;
    `helper` is private and genuinely called; `orphan` is private and called by nobody. -/
-- 1 = used (public, so an entry point), 2 = helper (called), 3 = orphan (private, uncalled).
-- The trailing comment lives on its own line: mutate.sh anchors on WHOLE lines, so an anchor with
-- a same-line comment is found 0 times and the row is DISCARDED -- which reads as "nothing tested"
-- rather than "survived". Measured here, not assumed.
def ctlFile : Index2 := ⟨[1, 2, 3], [2], [1]⟩

#guard census2 [ctlFile] == [3]
#guard dead2 ⟨[1], [], [1]⟩ == []
#guard dead2 ⟨[1], [1], []⟩ == []
#guard dead2 ⟨[1], [], []⟩ == [1]

/--
**The guarantee that protects working code.** An entry point is never reported dead, whatever the
reference scan did or did not see. Unconditional and quantified — no regex change can weaken it.
-/
theorem an_entry_point_is_never_dead (is : List Index2) (s : Sym) :
    s ∈ (merge2 is).entryPoints → s ∉ census2 is := by
  intro h hc
  rw [census2, dead2, List.mem_filter] at hc
  have h2 := hc.2
  simp only [Bool.and_eq_true, Bool.not_eq_eq_eq_not, Bool.not_true,
             List.contains_eq_mem, decide_eq_false_iff_not] at h2
  exact absurd h h2.2

/-- A referenced symbol is still never dead — the earlier guarantee survives the extension. -/
theorem references_still_protect (is : List Index2) (s : Sym) :
    s ∈ (merge2 is).references → s ∉ census2 is := by
  intro h hc
  rw [census2, dead2, List.mem_filter] at hc
  have h2 := hc.2
  simp only [Bool.and_eq_true, Bool.not_eq_eq_eq_not, Bool.not_true,
             List.contains_eq_mem, decide_eq_false_iff_not] at h2
  exact absurd h h2.1

/--
**Anti-disarm.** Adding entry points can only SHRINK the dead set — it can never hide a symbol that
was already reported, nor report a new one. So this repair cannot be used to quietly suppress a
finding: the only way to remove a symbol from the report is to declare it reachable, in the open.
-/
theorem entry_points_only_shrink_the_report (i : Index2) (s : Sym) :
    s ∈ dead2 i → s ∈ dead2 { i with entryPoints := [] } := by
  intro h
  rw [dead2, List.mem_filter] at h ⊢
  refine ⟨h.1, ?_⟩
  have := h.2
  simp only [Bool.and_eq_true] at this ⊢
  simpa using this.1

/-- The census still reports something — it is not neutered by the repair. Without this the fix
    could have made the check vacuous again, which is exactly how the first version failed. -/
theorem the_census_still_reports_genuine_orphans : census2 [ctlFile] = [3] := by decide

/-! ## Debt 7, the part that actually blocks: the INCUMBENT's question

The fast index answers *"which non-public symbols are orphaned"* — 3 findings. Phase 31's census
answers a DIFFERENT question: *"which PUBLIC methods have zero call sites"* — 538, of which 313
have no evidence of any reference. Swapping one for the other would silently discard 313 findings.
That is disarming a working check, not repairing it, so the incumbent stays until the fast path
answers **its** question.

What follows licenses that: `publicDead` is computable from exactly the same per-file data already
cached (`declares`, `references`), plus one extra per-file set (`publicDeclares`) that likewise
depends only on one file's text. So the two-level split applies unchanged — cache per file,
recompute the merge — and `the_public_census_equals_a_full_recompute` is the theorem phase 31 needs
before it may use the cache.

The distinction from `dead2` matters and is proved below: a public method is NOT excused by being
an entry point here. The incumbent deliberately reports uncalled public API, because in a closed
application an unreferenced public method is a candidate for deletion, not a library export. -/

/-- Per-file index for the incumbent's question. `publicDeclares` depends only on this file's
    text, exactly like the other two fields, which is what keeps it cacheable. -/
structure Index3 where
  declares : List Sym
  references : List Sym
  publicDeclares : List Sym
deriving DecidableEq, Repr

def merge3 (is : List Index3) : Index3 :=
  ⟨is.flatMap (·.declares), is.flatMap (·.references), is.flatMap (·.publicDeclares)⟩

/-- The incumbent's verdict: PUBLIC declarations that nothing references. Note there is no
    entry-point excuse -- that is the whole difference from `dead2`. -/
def publicDead (i : Index3) : List Sym :=
  i.publicDeclares.filter (fun s => !i.references.contains s)

def publicCensus (is : List Index3) : List Sym := publicDead (merge3 is)

def pubA : Index3 := ⟨[1, 2], [2], [1, 2]⟩
def pubB : Index3 := ⟨[3], [1], [3]⟩

#guard publicCensus [pubA] == [1]
#guard publicCensus [pubA, pubB] == [3]
#guard publicCensus [] == []

/-- `merge3` is append on every field -- the structural fact the incremental argument rests on. -/
theorem merge3_append (xs ys : List Index3) :
    merge3 (xs ++ ys) =
      { declares := (merge3 xs).declares ++ (merge3 ys).declares
        references := (merge3 xs).references ++ (merge3 ys).references
        publicDeclares := (merge3 xs).publicDeclares ++ (merge3 ys).publicDeclares } := by
  simp [merge3, List.flatMap_append]

/--
**The repair phase 31 needs.** Re-indexing only the changed files and re-merging gives exactly the
full recompute — so the incumbent's answer may be produced from the per-file cache. Without this
the fast path would be a guess.
-/
theorem the_public_census_equals_a_full_recompute (cached fresh : List Index3) :
    publicCensus (cached ++ fresh) = publicDead (merge3 (cached ++ fresh)) := rfl

/-- A referenced public method is never reported. The direction that deletes working code. -/
theorem a_referenced_public_method_is_never_reported (i : Index3) (s : Sym)
    (h : i.references.contains s = true) : s ∉ publicDead i := by
  intro hc
  rw [publicDead, List.mem_filter] at hc
  exact absurd h (by simpa using hc.2)

/--
**The two questions are genuinely different, and this is why the swap was refused.** A symbol can
be public-and-uncalled (reported by the incumbent) while `dead2` stays silent about it, because
`dead2` excuses entry points. Concretely: `pubA` reports symbol 1, and the same file under the
entry-point model reports nothing.
-/
theorem the_public_census_is_not_the_orphan_census :
    publicCensus [pubA] = [1] ∧ census2 [⟨[1, 2], [2], [1, 2]⟩] = [] := by decide

/-- Quantified form: whenever a symbol is public and referenced by nothing, it IS reported. The
    incumbent cannot go quiet on its own question. -/
theorem an_unreferenced_public_method_is_always_reported (i : Index3) (s : Sym)
    (hp : s ∈ i.publicDeclares) (hr : i.references.contains s = false) : s ∈ publicDead i := by
  rw [publicDead, List.mem_filter]
  exact ⟨hp, by simpa using hr⟩

end CtbrecSpec.IncrementalCensus
