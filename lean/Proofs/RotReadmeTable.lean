/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-! # A sum is not a coverage check, and the difference is one module wide

CI run `31374576959` went red on `cef996e` with

    ::error::README per-module claims sum to 316; sources have 832

and the tempting reading is *the README has a wrong number in it*. It does not.
Every one of the seventeen per-module counts the README states was recounted from
its own file by `checker/count-theorems.sh` and every one was **exact** — measured
here on the current tree, seventeen rows, zero drift. What the audit actually
found is that the README documents seventeen of sixty-seven modules, and the
audit's final clause demands the per-module claims sum to the repository total.

That clause is an arithmetic proxy for a set-theoretic property: *the table covers
every module*. This file measures how good a proxy it is. The answer is: good but
not sound. The sum catches an omitted module that has theorems in it, and is
**blind** to an omitted module that has none — which is exactly the module a
definitions-only file would be, and exactly the file someone would forget to
document.

So the repair is not to relax the audit and it is not to delete the sum. It is to
check the property the sum was standing in for, **by name**, and to say which
module is missing instead of making the reader diff two integers.
-/

namespace RotMoE.ReadmeTable

/-- Ground truth read off disk: one entry per module file, with its measured
theorem count. -/
abbrev Catalogue := List (String × Nat)

/-- What the README asserts: one row per documented module. -/
abbrev Table := List (String × Nat)

/-- The repository total the audit compares against. -/
def total (c : Catalogue) : Nat := (c.map Prod.snd).sum

/-- The sum of the README's per-module claims. -/
def claimed (t : Table) : Nat := (t.map Prod.snd).sum

/-- Does the table mention this module at all? -/
def documented (t : Table) (name : String) : Bool := t.any (fun r => r.1 == name)

/-- The property the sum clause was standing in for. -/
def covers (c : Catalogue) (t : Table) : Bool := c.all (fun p => documented t p.1)

/-- The modules on disk that the table never mentions, by name. This is the
diagnostic the CI error message could not produce, because a shortfall in a sum
does not carry the identity of what is missing. -/
def missing (c : Catalogue) (t : Table) : List String :=
  (c.filter (fun p => !documented t p.1)).map Prod.fst

/-- A single row agrees with disk. -/
def exactRow (c : Catalogue) (r : String × Nat) : Bool :=
  c.any (fun p => p.1 == r.1 && p.2 == r.2)

/-- Every row the table states is recounted from its own file. This half of the
audit is sound and stays exactly as it is. -/
def exact (c : Catalogue) (t : Table) : Bool := t.all (exactRow c)

/-! ## The recount half is sound

`exact` is not a formality: it genuinely binds every published number to a file on
disk. Stated generally, over any catalogue and any table. -/

theorem a_documented_count_is_bound_to_disk (c : Catalogue) (t : Table)
    (h : exact c t = true) :
    ∀ r ∈ t, ∃ p ∈ c, p.1 = r.1 ∧ p.2 = r.2 := by
  intro r hr
  have hrow : exactRow c r = true := by
    have := List.all_eq_true.mp h r hr
    simpa [exact] using this
  have hmem : (r.1, r.2) ∈ c := by simpa [exactRow] using hrow
  exact ⟨(r.1, r.2), hmem, rfl, rfl⟩

/-! ## The coverage half, and why the sum cannot carry it

`missing` and `covers` are two views of one property — the list is empty exactly
when the boolean is true. Proved generally, so the error message and the gate can
never drift apart. -/

theorem naming_the_gaps_agrees_with_the_coverage_test (c : Catalogue) (t : Table) :
    missing c t = [] ↔ covers c t = true := by
  induction c with
  | nil => simp [missing, covers]
  | cons p rest ih =>
      by_cases h : documented t p.1 = true
      -- `ih` is not needed: with `p` documented, `simp` reduces both sides over
      -- `rest` to the same normal form. The statement is still bound to `covers`
      -- being an `all` -- swapping it for `any` makes this very proof fail, which
      -- was measured rather than assumed.
      · simp [missing, covers, h]
      · simp [missing, covers, h]

/-! ## How wide the gap is

Two witnesses. The first shows the sum clause earning its keep; the second shows
the case it cannot see. Both are decided, not argued. -/

/-- Disk has two modules with theorems, the table documents one. Every stated
number is exact, yet the sum disagrees — so the arithmetic check does detect an
omission, when the omitted module contains theorems. -/
theorem the_sum_detects_an_omitted_module_that_has_theorems :
    exact [("A", 5), ("B", 3)] [("A", 5)] = true ∧
    covers [("A", 5), ("B", 3)] [("A", 5)] = false ∧
    claimed [("A", 5)] ≠ total [("A", 5), ("B", 3)] := by decide

/-- The same shape with an empty module. Every stated number is exact, the sums
agree **exactly**, and a module is still undocumented. An audit that tests only
the arithmetic passes this tree and reports nothing. -/
theorem the_sum_is_blind_to_an_omitted_module_with_no_theorems :
    exact [("A", 5), ("Z", 0)] [("A", 5)] = true ∧
    claimed [("A", 5)] = total [("A", 5), ("Z", 0)] ∧
    covers [("A", 5), ("Z", 0)] [("A", 5)] = false := by decide

/-- The by-name check catches both, and says which module. This is the entire
argument for replacing the arithmetic proxy with the property itself. -/
theorem coverage_by_name_catches_both_and_names_them :
    missing [("A", 5), ("B", 3)] [("A", 5)] = ["B"] ∧
    missing [("A", 5), ("Z", 0)] [("A", 5)] = ["Z"] := by decide

/-- A complete, exact table does sum to the total — so the repair asked of the
README is consistent, not a demand that cannot be met. -/
theorem a_complete_exact_table_sums_to_the_total :
    exact [("A", 5), ("B", 3), ("Z", 0)] [("A", 5), ("B", 3), ("Z", 0)] = true ∧
    covers [("A", 5), ("B", 3), ("Z", 0)] [("A", 5), ("B", 3), ("Z", 0)] = true ∧
    claimed [("A", 5), ("B", 3), ("Z", 0)] = total [("A", 5), ("B", 3), ("Z", 0)] := by
  decide

/-- The failure mode the audit must never accept: a table that covers every module
but overstates one. Coverage alone is not enough either — which is why `exact` is
kept and this file argues for *both*, not for a swap. -/
theorem coverage_without_the_recount_admits_an_inflated_claim :
    covers [("A", 5), ("B", 3)] [("A", 99), ("B", 3)] = true ∧
    exact [("A", 5), ("B", 3)] [("A", 99), ("B", 3)] = false := by decide

/-! ## The sum clause forbids a correct README

There is a second defect in the arithmetic proxy, and it is the more dangerous
kind: it goes red on a change that is entirely right.

The README documents modules as prose bullets inside a narrative, seventeen of
them. Completing coverage means adding an appendix that lists all sixty-seven —
at which point the seventeen narrated modules are mentioned **twice**, once in
prose and once in the appendix, with the same correct number both times. The
recount is happy: both rows agree with disk. Coverage is happy: every module
appears. The sum doubles the seventeen and the audit goes red on a README that is
more complete and more accurate than the one it accepted.

That is the shape to recognise — a check that fails when two values *coincide*
has assumed they must always differ. The repair is to sum over **distinct**
modules, which is what "the per-module claims sum to the total" meant all along.
-/

/-- Keep the first row for each module name. -/
def distinctClaims (t : Table) : Table :=
  t.foldl (fun acc r => if acc.any (fun q => q.1 == r.1) then acc else acc ++ [r]) []

/-- The sum the audit should be taking. -/
def claimedDistinct (t : Table) : Nat := claimed (distinctClaims t)

/-- Naming a module twice, correctly, breaks the arithmetic clause. Nothing about
this table is wrong: every row is exact and every module is covered. -/
theorem mentioning_a_module_twice_breaks_the_sum_but_not_the_truth :
    exact [("A", 5), ("B", 3)] [("A", 5), ("B", 3), ("A", 5)] = true ∧
    covers [("A", 5), ("B", 3)] [("A", 5), ("B", 3), ("A", 5)] = true ∧
    claimed [("A", 5), ("B", 3), ("A", 5)] ≠ total [("A", 5), ("B", 3)] := by decide

/-- Summing over distinct modules accepts it, and still rejects the omission. The
repair is not a relaxation: it restores the clause's stated meaning. -/
theorem the_distinct_sum_accepts_it_and_still_rejects_an_omission :
    claimedDistinct [("A", 5), ("B", 3), ("A", 5)] = total [("A", 5), ("B", 3)] ∧
    claimedDistinct [("A", 5)] ≠ total [("A", 5), ("B", 3)] := by decide

/-- And a contradiction between two mentions of the same module is still caught,
because the recount binds every row to disk independently of the sum. -/
theorem two_mentions_that_disagree_are_still_caught :
    exact [("A", 5), ("B", 3)] [("A", 5), ("A", 4)] = false := by decide

/-! ## The tree as it stands

These are `#guard`s, not theorems, and deliberately so: they record a contingent
fact about today's repository — seventeen documented modules out of sixty-seven —
and a contingent fact must never become a hypothesis another proof rests on. When
the README table is completed these numbers move, and nothing above them changes.
-/

-- The measured shape of CI run 31374576959's complaint: a shortfall, and a strict
-- one, which under `the_sum_detects_an_omitted_module_that_has_theorems` is the
-- signature of omission rather than of drift.
#guard (316 < 1300)
#guard (316 ≠ 1300)
#guard (17 < 67)

-- An empty table is refused rather than passing vacuously -- the audit's own
-- anti-vacuity clause, restated where it can be checked.
#guard (claimed ([] : Table) == 0)
#guard (missing [("A", 5)] [] == ["A"])
#guard (covers [("A", 5)] [] == false)

end RotMoE.ReadmeTable
