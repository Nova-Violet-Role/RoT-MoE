/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Mathlib

/-! # The proof scan and the workspace chain, formalized

Two defects lived here for weeks, in **both** arms at once, with every gate
green. Both are measured, and both are the same shape: an instrument that was
right about what it looked at, and looked at the wrong thing.

**Defect 1 — the scan was one level deep.** `"$PROOFS_DIR"/*.lean` in the POSIX
arm and `Get-ChildItem -Filter '*.lean'` with no `-Recurse` in the PowerShell arm.
The moment proofs are filed by subject — `Proofs/<SubjectA>/`, `Proofs/<SubjectB>/` —
the newest file either arm could see was whatever last landed in the root.
Measured on a real tree at one instant: **2947 minutes stale one level deep, 54
minutes recursive**. A 55x error, and the hook spent an entire working session
insisting no proof had been written while eighteen modules were being written
into a subfolder.

**Defect 2 — the workspace chain had a step nothing wrote.** `env → RECORDED →
bundled corpus` reads like three answers. Only `SETUP_LEAN` ever writes RECORDED,
so for a marketplace install the middle step is permanently empty and the chain
silently degrades to two — pointing every measurement at the plugin's own
read-only corpus, which can never acquire debt.

**What is worth proving, and what is not.** "The fix works on my tree" is a
measurement; it holds for one tree at one instant. The statements below hold for
every tree: that a one-level scan can only ever report something *more stale*
than the truth (`flat_never_underreports`) — so its failure mode is a false
accusation, never a false silence — and that the resolution chain returns the
first step that answers, so adding a step can only ever *narrow* the fallback.

**What is NOT modelled.** Lean does not read a filesystem. Whether the shipped
`find` and `-Recurse` actually enumerate what `recScan` denotes is the checker's
job (`checker/remind-measure.sh` drives both arms over one fixture tree
containing a nested proof and compares). A green build here means the *rule* is
sound, never that the *scan was implemented*.
-/

namespace RotMoE.Scan

/-- A proof file as the reminder sees it: a name, how deep below `Proofs/` it
sits, and a modification time in minutes since the epoch. Depth is the whole
point — it is the field the shipped glob was blind to. -/
structure PFile where
  name : String
  depth : Nat
  mtime : Nat
deriving DecidableEq, Repr

/-- The scan that shipped: only files directly in `Proofs/`. -/
def flatScan (fs : List PFile) : List PFile := fs.filter (fun f => f.depth == 0)

/-- The scan that ships now: every `.lean` under `Proofs/`, at any depth. -/
def recScan (fs : List PFile) : List PFile := fs

/-- Newest modification time in a scan result. `0` for the empty scan, which is
the sentinel the shipped hooks use for "no proof found". -/
def maxTime : List PFile → Nat
  | [] => 0
  | f :: rest => max f.mtime (maxTime rest)

theorem maxTime_ge (fs : List PFile) : ∀ f ∈ fs, f.mtime ≤ maxTime fs := by
  induction fs with
  | nil => simp
  | cons g rest ih =>
    intro f hf
    simp only [maxTime]
    rcases List.mem_cons.mp hf with rfl | h
    · exact le_max_left _ _
    · exact le_trans (ih f h) (le_max_right _ _)

/-- Monotone in the set of files seen. Stated over membership rather than over
`Sublist` because that is the property that matters: a scan is characterised by
*which files it finds*, not by the order it finds them in. -/
theorem maxTime_le_of_subset {l₁ l₂ : List PFile} (h : ∀ f ∈ l₁, f ∈ l₂) :
    maxTime l₁ ≤ maxTime l₂ := by
  induction l₁ with
  | nil => exact Nat.zero_le _
  | cons g rest ih =>
    simp only [maxTime, max_le_iff]
    exact ⟨maxTime_ge l₂ g (h g (by simp)),
           ih (fun f hf => h f (List.mem_cons_of_mem _ hf))⟩

/-! ## The scan -/

/-- **Everything the flat scan finds, the recursive scan also finds.** -/
theorem flat_subset_rec (fs : List PFile) (f : PFile) (h : f ∈ flatScan fs) :
    f ∈ recScan fs := by
  simp only [flatScan, List.mem_filter] at h
  exact h.1

/-- **The recursive scan finds everything there is.** Without this, a scan that
returned the empty list would satisfy every inequality below. -/
theorem rec_sees_everything (fs : List PFile) (f : PFile) (h : f ∈ fs) :
    f ∈ recScan fs := h

/-- Staleness as the hook computes it: minutes between now and the newest proof.
Natural subtraction truncates at zero, which is exactly the shipped behaviour for
a file written in the future by a clock skew. -/
def staleMins (now : Nat) (fs : List PFile) : Nat := now - maxTime fs

/-- **The one-level scan can only ever OVER-report staleness — never under.**

This is the theorem worth having, because it names the failure mode. The broken
hook did not go quiet when it should have spoken; it *spoke when it should have
been quiet*, and an alarm that fires falsely gets ignored, which is how the
reminder became wallpaper. Holds for every tree, not for the one that was
measured. -/
theorem flat_never_underreports (now : Nat) (fs : List PFile) :
    staleMins now (recScan fs) ≤ staleMins now (flatScan fs) := by
  simp only [staleMins]
  exact Nat.sub_le_sub_left (maxTime_le_of_subset (flat_subset_rec fs)) now

/-- **And the gap is real, not merely possible.** The witness is the shape of the
measured tree: one old proof in the root, one fresh proof in a subdirectory. The
flat scan reports the root's age; the recursive scan reports the subdirectory's.
`decide` executes the model rather than arguing about it. -/
theorem flat_gap_is_real :
    ∃ (now : Nat) (fs : List PFile),
      staleMins now (recScan fs) < staleMins now (flatScan fs) := by
  refine ⟨3000, [⟨"SanctumPulse", 0, 53⟩, ⟨"LlhlsSequence", 1, 2946⟩], ?_⟩
  decide

/-- **A scan of a tree with no nested files loses nothing.** The complement of
the theorem above, and the reason the fix is not a behaviour change for anyone
whose proofs all sit in the root: on a flat tree the two scans agree exactly. -/
theorem flat_equals_rec_on_flat_tree (fs : List PFile) (h : ∀ f ∈ fs, f.depth = 0) :
    maxTime (flatScan fs) = maxTime (recScan fs) := by
  apply le_antisymm
  · exact maxTime_le_of_subset (flat_subset_rec fs)
  · refine maxTime_le_of_subset ?_
    intro f hf
    simp only [flatScan, List.mem_filter]
    exact ⟨hf, by simp [h f hf]⟩

/-! ## The workspace chain -/

/-- Which step of the chain answered. Being able to ASK this is the difference
between diagnosing a wrong workspace in one command and in an afternoon, which is
why both shipped arms now print it (`--workspace` / `-Workspace`). -/
inductive WsSource where
  | env | recorded | discovered | bundled
deriving DecidableEq, Repr

/-- The chain as it ships in 0.7.0: explicit environment override, then the
recorded install, then discovery from the session's directory, then our own
bundled corpus. `bundled` is a `String` rather than an `Option`, which is the
formal statement that the chain is TOTAL — the hook can always answer. -/
def resolve (env recorded discovered : Option String) (bundled : String) :
    WsSource × String :=
  match env with
  | some v => (WsSource.env, v)
  | none =>
    match recorded with
    | some v => (WsSource.recorded, v)
    | none =>
      match discovered with
      | some v => (WsSource.discovered, v)
      | none => (WsSource.bundled, bundled)

/-- The chain as it shipped up to 0.6.2 — no discovery step. -/
def resolveOld (env recorded : Option String) (bundled : String) :
    WsSource × String :=
  match env with
  | some v => (WsSource.env, v)
  | none =>
    match recorded with
    | some v => (WsSource.recorded, v)
    | none => (WsSource.bundled, bundled)

/-- **An explicit override always wins.** -/
theorem resolve_env_first (v : String) (r d : Option String) (b : String) :
    resolve (some v) r d b = (WsSource.env, v) := rfl

/-- **A recorded install beats discovery.** Discovery is a guess from the
session's directory; a recorded workspace is an answer someone gave on purpose.
Ordering them the other way would let a session that happens to sit inside some
other Lake project silently redirect every measurement. -/
theorem resolve_recorded_beats_discovered (v : String) (d : Option String) (b : String) :
    resolve none (some v) d b = (WsSource.recorded, v) := rfl

/-- **Discovery answers exactly when nothing above it did.** -/
theorem resolve_discovered_when_unset (v b : String) :
    resolve none none (some v) b = (WsSource.discovered, v) := rfl

/-- **The chain is total: it always returns a workspace.** A resolution chain
that could fail would leave the hook with nothing to measure and no way to say
so. -/
theorem resolve_total (e r d : Option String) (b : String) :
    ∃ s v, resolve e r d b = (s, v) := ⟨_, _, rfl⟩

/-- **The measured defect, as a theorem.** With no environment override and no
recorded file — the state of every marketplace install, because nothing in that
path writes the recorded file — the old chain falls through to the bundled
read-only corpus while the new chain finds the workspace the user is actually
working in.

Stated on the **path** component, and the hypothesis is what makes it worth
stating. The first draft asserted the whole pairs differ and carried `ws ≠
bundled` as a hypothesis it never used — Lean's unused-variable linter said so,
and it was right: the labels `bundled` and `discovered` differ for free, so that
version proved something true and irrelevant while its doc comment claimed the
2907-minute false alarm. The measurement that went wrong was the PATH, so that is
what the theorem is about. -/
theorem old_chain_measures_the_wrong_tree (ws bundled : String) (h : ws ≠ bundled) :
    (resolveOld none none bundled).2 ≠ (resolve none none (some ws) bundled).2 := by
  simpa [resolveOld, resolve] using (Ne.symm h)

/-- The label difference, which genuinely does hold unconditionally — kept as its
own statement rather than smuggled in as an unused hypothesis on the one above.
It is what makes `--workspace` diagnostic: the two chains do not merely disagree
about the path, they disagree about *which step answered*. -/
theorem old_chain_reports_a_different_source (ws bundled : String) :
    (resolveOld none none bundled).1 ≠ (resolve none none (some ws) bundled).1 := by
  simp [resolveOld, resolve]

/-- **Adding the step cannot change any answer the old chain already gave.**
The other half, and the one that makes the change safe to ship: whenever the old
chain answered `env` or `recorded`, the new chain answers identically. A fix that
only ever narrows a fallback is a fix nobody has to re-test. -/
theorem resolve_agrees_when_old_answered (e r : Option String) (d : Option String)
    (b : String) (h : e.isSome ∨ r.isSome) :
    resolve e r d b = resolveOld e r b := by
  cases e with
  | some v => rfl
  | none =>
    cases r with
    | some v => rfl
    | none => simp at h

end RotMoE.Scan
