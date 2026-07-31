/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

-- NEGATIVE CONTROL for the vacuity audit.
-- A theorem whose hypotheses can never hold. It compiles, passes #print axioms,
-- and survives leanchecker -- which is exactly the point.
theorem impressive_sounding_name (h : (1:Nat) = 2) : False := by omega

-- The audit's method applied to it: try to produce a WITNESS. If the vacuity
-- audit is a real instrument, THIS must fail to compile.
example : False := impressive_sounding_name (by decide)
