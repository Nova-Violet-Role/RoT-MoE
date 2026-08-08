/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

# A measurement corpus with no version tag cannot attribute anything

`checker/ctt-session.sh` collects router firings from a live CTT session into
one JSONL, and its own header says these are "the numbers the README's
benchmark section is allowed to quote". The corpus is resumable by design: four
calls of twenty turns are meant to produce exactly the same file as one call of
eighty.

Measured on 2026-08-08, a record carries exactly these fields:

    kind, ts, K, mean, breadth, M, C, T, sum, Rs, active, lenses

There is no version among them. The router hook writes the record and the hook
does not know which plugin build it is running inside, so this is not an
oversight in the harness -- it is a fact about the data. The consequence is
concrete: the corpus on disk held 120 records, 60 produced by plugin 0.9.2 and
60 by 1.0.1, and nothing in the file distinguishes them. A report over that file
attributes to whichever version you happen to believe was running.

This module proves three things about that situation.

**Pooling can invent a result that neither version produced.** This is the
theorem that makes the missing tag a defect rather than an untidiness. Two runs
are exhibited in which one lane strictly dominates the first, a different lane
strictly dominates the second, and in the pooled corpus a THIRD lane strictly
dominates both -- a lane that was the leader of neither run. A benchmark quoted
from the pooled file would name a winner that no version of the router ever
exhibited.

**A marker makes attribution total, and its absence makes it impossible.**
Attribution walks the corpus carrying the version last announced. With no marker
before the first firing, every record attributes to `none`; with one, every
record attributes to some version, and no later marker can undo that.

**Appending a run cannot disturb the runs already collected.** This is exactly
the property the resumable design assumes and never checked. It is what makes
"four calls of twenty" equal "one call of eighty" -- and it holds only because
attribution is a left fold carrying the version forward, which is why the fix is
a marker record rather than a post-hoc annotation.

The repair follows from the third theorem, not from taste: the harness writes a
version marker when a run begins, and the report partitions on it.
-/

namespace RotMoE.Corpus

/-- The routing lanes the gauge can report. `CONVERGENT` is the default lane. -/
inductive Lane where
  | CONVERGENT | CLINICAL | EXECUTIVE | EMPATHIC | STRATEGIC
  | CREATIVE | PREDICTIVE | STEALTH | RECURSIVE | FORGE
  deriving DecidableEq, Repr

/-- A plugin version, kept as a plain string so it matches what the registry holds. -/
abbrev Ver := String

/-- One line of the corpus. A run announces itself with `mark`; every router
firing appends a `route`. -/
inductive Rec where
  /-- A version marker: the run that follows was produced by this build. -/
  | mark (v : Ver)
  /-- A router firing on the named lane. -/
  | route (lane : Lane)
  deriving DecidableEq, Repr

/-- The version in effect after reading a corpus, starting from `cur`. -/
def finalVer : List Rec → Option Ver → Option Ver
  | [], cur => cur
  | Rec.mark v :: rest, _ => finalVer rest (some v)
  | Rec.route _ :: rest, cur => finalVer rest cur

/-- Attribute every firing to the version of the nearest preceding marker.
`none` means the record cannot be attributed to any build. -/
def assign : List Rec → Option Ver → List (Option Ver × Lane)
  | [], _ => []
  | Rec.mark v :: rest, _ => assign rest (some v)
  | Rec.route l :: rest, cur => (cur, l) :: assign rest cur

/-- Count the firings on one lane, ignoring markers. -/
def cnt (l : Lane) : List Rec → Nat
  | [] => 0
  | Rec.mark _ :: rest => cnt l rest
  | Rec.route x :: rest => (if x = l then 1 else 0) + cnt l rest

/-- Keep only the firings attributed to one version. -/
def onlyVer (v : Ver) (xs : List (Option Ver × Lane)) : List Lane :=
  (xs.filter (fun p => p.1 = some v)).map Prod.snd

/-! ## The two runs that produce the counterexample -/

/-- A run of plugin 0.9.2: FORGE leads, three to two over EMPATHIC. -/
def runA : List Rec :=
  [Rec.route Lane.FORGE, Rec.route Lane.FORGE, Rec.route Lane.FORGE,
   Rec.route Lane.EMPATHIC, Rec.route Lane.EMPATHIC]

/-- A run of plugin 1.0.1: CLINICAL leads, three to two over EMPATHIC. -/
def runB : List Rec :=
  [Rec.route Lane.CLINICAL, Rec.route Lane.CLINICAL, Rec.route Lane.CLINICAL,
   Rec.route Lane.EMPATHIC, Rec.route Lane.EMPATHIC]

/-! ## Pooling invents a leader -/

/-- FORGE strictly leads the first run. -/
theorem forge_leads_runA : cnt Lane.FORGE runA > cnt Lane.EMPATHIC runA := by decide

/-- CLINICAL strictly leads the second run. -/
theorem clinical_leads_runB : cnt Lane.CLINICAL runB > cnt Lane.EMPATHIC runB := by decide

/-- **The defect, exhibited.** In the pooled corpus EMPATHIC strictly outscores
both FORGE and CLINICAL -- so the pooled file names a leading lane that led
neither of the two runs it is made of. -/
theorem pooling_invents_a_leader :
    cnt Lane.EMPATHIC (runA ++ runB) > cnt Lane.FORGE (runA ++ runB) ∧
    cnt Lane.EMPATHIC (runA ++ runB) > cnt Lane.CLINICAL (runA ++ runB) := by decide

/-- And the invented leader is not an artefact of one lane being rare: EMPATHIC
led neither run on its own. -/
theorem invented_leader_led_neither :
    ¬ (cnt Lane.EMPATHIC runA > cnt Lane.FORGE runA) ∧
    ¬ (cnt Lane.EMPATHIC runB > cnt Lane.CLINICAL runB) := by decide

/-! ## Counting is faithful once you can partition -/

/-- Lane counts add across a concatenation. Pooling is not wrong arithmetic --
it is correct arithmetic over a question nobody asked, which is why the repair
is a tag and not a different sum. -/
theorem cnt_append (l : Lane) (xs ys : List Rec) :
    cnt l (xs ++ ys) = cnt l xs + cnt l ys := by
  induction xs with
  | nil => simp [cnt]
  | cons r rest ih =>
    cases r with
    | mark _ => simpa [cnt] using ih
    | route x => simp [cnt, ih, Nat.add_assoc]

/-! ## A marker makes attribution total -/

/-- Once a version is in effect, every later firing is attributed to some
version. No subsequent marker can push a record back to `none`. -/
theorem attributed_of_started (rs : List Rec) :
    ∀ v : Ver, ∀ p ∈ assign rs (some v), p.1 ≠ none := by
  induction rs with
  | nil => intro v p hp; simp [assign] at hp
  | cons r rest ih =>
    intro v p hp
    cases r with
    | mark w => exact ih w p (by simpa [assign] using hp)
    | route l =>
      simp only [assign, List.mem_cons] at hp
      rcases hp with h | h
      · subst h; simp
      · exact ih v p h

/-- **A corpus that opens with a marker attributes every firing.** -/
theorem marker_first_attributes_all (v : Ver) (rs : List Rec) :
    ∀ p ∈ assign (Rec.mark v :: rs) none, p.1 ≠ none := by
  intro p hp
  exact attributed_of_started rs v p (by simpa [assign] using hp)

/-- **And without one, nothing is attributable.** A corpus of pure firings --
exactly what the router hook writes today -- maps every record to `none`. -/
theorem no_marker_attributes_nothing (ls : List Lane) :
    ∀ p ∈ assign (ls.map Rec.route) none, p.1 = none := by
  induction ls with
  | nil => intro p hp; simp [assign] at hp
  | cons l rest ih =>
    intro p hp
    simp only [List.map_cons, assign, List.mem_cons] at hp
    rcases hp with h | h
    · subst h; rfl
    · exact ih p h

/-! ## Resumability: appending a run cannot disturb the earlier ones -/

/-- Attribution of a concatenation is the attribution of each part, the second
starting from the version left in effect by the first. -/
theorem assign_append (xs ys : List Rec) (cur : Option Ver) :
    assign (xs ++ ys) cur = assign xs cur ++ assign ys (finalVer xs cur) := by
  induction xs generalizing cur with
  | nil => simp [assign, finalVer]
  | cons r rest ih =>
    cases r with
    | mark v => simpa [assign, finalVer] using ih (some v)
    | route l => simpa [assign, finalVer] using ih cur

/-- **The property the resumable design assumed and never checked.** Appending
a later run leaves every earlier attribution exactly as it was, so four calls of
twenty turns really do produce the same attributed corpus as one call of eighty.
-/
theorem appending_preserves_earlier (xs ys : List Rec) (cur : Option Ver) :
    (assign (xs ++ ys) cur).take (assign xs cur).length = assign xs cur := by
  rw [assign_append]
  simp

/-- A marked run keeps its own version even when another run is appended after
it -- the second marker governs only the records that follow it. -/
theorem later_marker_does_not_recolour (v w : Ver) (ls ms : List Lane) :
    onlyVer v (assign ((Rec.mark v :: ls.map Rec.route) ++
                          (Rec.mark w :: ms.map Rec.route)) none)
      = onlyVer v (assign (Rec.mark v :: ls.map Rec.route) none) ∨ v = w := by
  by_cases h : v = w
  · exact Or.inr h
  · left
    rw [assign_append]
    simp only [onlyVer, List.filter_append, List.map_append]
    have : (assign (Rec.mark w :: ms.map Rec.route)
              (finalVer (Rec.mark v :: ls.map Rec.route) none)).filter
             (fun p => p.1 = some v) = [] := by
      have hw : ∀ p ∈ assign (ms.map Rec.route) (some w), p.1 = some w := by
        clear h
        induction ms with
        | nil => intro p hp; simp [assign] at hp
        | cons m rest ih =>
          intro p hp
          simp only [List.map_cons, assign, List.mem_cons] at hp
          rcases hp with h1 | h1
          · subst h1; rfl
          · exact ih p h1
      apply List.filter_eq_nil_iff.mpr
      intro p hp
      simp only [assign] at hp
      have := hw p hp
      simp [this, Ne.symm h]
    simp [this]

/-! ## Executable checks: the model agrees with the numbers on disk -/

/-- The pooled corpus really does show four EMPATHIC against three and three. -/
example : cnt Lane.EMPATHIC (runA ++ runB) = 4 := by decide

/-- Each run on its own shows three. -/
example : cnt Lane.FORGE runA = 3 ∧ cnt Lane.CLINICAL runB = 3 := by decide

/-- A marked, pooled corpus splits back into the two runs exactly. -/
example :
    (onlyVer "0.9.2" (assign ((Rec.mark "0.9.2" :: runA) ++ (Rec.mark "1.0.1" :: runB)) none)).length = 5 ∧
    (onlyVer "1.0.1" (assign ((Rec.mark "0.9.2" :: runA) ++ (Rec.mark "1.0.1" :: runB)) none)).length = 5 := by
  decide

end RotMoE.Corpus
