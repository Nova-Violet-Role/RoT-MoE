/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Authors: ctbrec-rework
-/
import Mathlib.Data.List.Dedup

/-!
# Normalising can only SHRINK the signature set

The open obligation from CP158, closed. `phase90.sh` maps each raw error line to a normalised
signature and deduplicates. The question left open was whether normalisation can ever make the
signature set BIGGER -- if it could, "the baseline has 16 entries" would bound nothing.

The first attempt failed: after `cons`, `omega` was asked to relate two filters under DIFFERENT
predicates, which it cannot do and which is not even true in that shape. The right statement is
about the IMAGE of a map under dedup, and it needs a cardinality argument, not arithmetic --
`List.Nodup.length_le_of_subset` is the lemma that does the work.

This is the load-bearing fact behind every count phase90 reports.
-/

namespace CtbrecSpec.DedupBound

/-- Normalisation never invents signatures: the deduplicated image is no larger than the
deduplicated source. Proved, not measured -- it holds for EVERY normaliser `f` and every log. -/
theorem dedup_map_length_le {α β : Type} [DecidableEq α] [DecidableEq β]
    (f : α → β) (xs : List α) :
    (xs.map f).dedup.length ≤ xs.dedup.length := by
  have hsub : (xs.map f).dedup ⊆ (xs.dedup).map f := by
    intro b hb
    have : b ∈ xs.map f := List.mem_dedup.mp hb
    obtain ⟨a, ha, rfl⟩ := List.mem_map.mp this
    exact List.mem_map.mpr ⟨a, List.mem_dedup.mpr ha, rfl⟩
  have hnd : (xs.map f).dedup.Nodup := List.nodup_dedup _
  calc (xs.map f).dedup.length ≤ ((xs.dedup).map f).length :=
        List.Nodup.length_le_of_subset hnd hsub
    _ = xs.dedup.length := List.length_map _

/-- The bound is TIGHT, not slack: an injective normaliser loses nothing. Without this the
theorem above would be compatible with a normaliser that collapses everything to one line --
which is exactly the HTTP-status defect measured on 2026-08-10. -/
theorem injective_normaliser_loses_nothing {α β : Type} [DecidableEq α] [DecidableEq β]
    (f : α → β) (hf : Function.Injective f) (xs : List α) :
    (xs.map f).dedup.length = xs.dedup.length := by
  rw [List.dedup_map_of_injective hf, List.length_map]

end CtbrecSpec.DedupBound
