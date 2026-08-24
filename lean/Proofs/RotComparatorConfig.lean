/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.

THE MEASUREMENT THIS FILE FORMALISES
====================================

`checker/release-longsession.sh` was run uncapped for the first time on
2026-08-21 (the previous 21-passed/6-failed reading was void -- its exit 124
was the audit's own `timeout 600`, not the gate's conclusion).

  wall clock            1455s   (07:35:47 -> 08:00:02)
  exit                  1
  verdict               24 passed, 3 failed
  turns                 138 total, 138 real model answers, 138 router firings

All three FAILs were the same assertion, once per variant:

  release-longsession.sh:67    FAIL  core:     53 of 53 turns disagreed with the artifact's own router
  release-longsession.sh:114   FAIL  lean:     34 of 34 turns disagreed with the artifact's own router
  release-longsession.sh:178   FAIL  unsealed: 51 of 51 turns disagreed with the artifact's own router

138 of 138. A disagreement rate of exactly 100% is the signature of a
comparator whose two sides were never able to agree, so the verdict was not
believed until the mechanism was named.

THE TWO SIDES READ DIFFERENT CONFIGURATION
------------------------------------------

The gate compares a rendered line against itself:

  live   -- the router as it fired inside the real session, scraped from the
            --debug-file, at checker/release-longsession.sh:255
  oracle -- the same hooks/rot-router.sh, run standalone on the same prompt
            text, at checker/release-longsession.sh:232

Both sides are the same script and the same prompt. They still differ, and
hooks/rot-router.sh:167 says why, in the router's own words:

    There is NO `model` key in the payload. So it is read from the settings file

The rendered line therefore carries two things: the routing decision, which
depends on the prompt, and a model tag, which depends on the settings file.
The two sides read different settings files:

  checker/release-longsession.sh:200
      printf '{\n  "model": "sonnet"\n}\n' > "$CFG/settings.json"
  checker/release-longsession.sh:229   run_turn
      CLAUDE_CONFIG_DIR="$CFG" timeout "$TURN_TIMEOUT" claude "$@"     -> sonnet
  checker/release-longsession.sh:232   oracle
      | bash "$PLUG/hooks/rot-router.sh"                               -> host settings, opus[1m]

The oracle is invoked with no CLAUDE_CONFIG_DIR at all, so it reads this
machine's real settings rather than the sandbox's. The model tag is thus
guaranteed to differ on every single turn, and the comparison at :259 is
whole-string equality:

    if [ -n "$live" ] && [ "$live" = "$want" ]; then matched=$((matched+1)); fi

So `matched` cannot be incremented on any turn whose rendered line carries a
model tag.

A CORRECTION, MADE BY A CONTROL THAT REFUSED TO FIRE
----------------------------------------------------

The first draft of this header said the gate was unsatisfiable "for any turn, on
any tree, forever". That was too strong, and the control caught it. Running the
router twice on `debug this failing test`, once with the host settings and once
with a sonnet-pinned CLAUDE_CONFIG_DIR, produced IDENTICAL output both times:

    CLINICAL AntiVenom | R/s+ 0.72
    CLINICAL AntiVenom | R/s+ 0.72

No divergence, because there is no model tag on that line at all. The second
field of a rendered line is the LENS name on every lane except CONVERGENT, where
it is the MODEL. Re-running on a prompt that actually routes CONVERGENT is what
made the control fire:

    hello there, no CLAUDE_CONFIG_DIR   ->  CONVERGENT opus[1m] | R/s+ 0.17
    hello there, CLAUDE_CONFIG_DIR set  ->  CONVERGENT sonnet   | R/s+ 0.17

and `hooks/rot-router.sh:263` names the mechanism exactly:

    _cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

So the precise claim is narrower and sharper than the first draft. The
configuration defect can only decide a turn when BOTH sides render CONVERGENT.
In the observed run the live side rendered CONVERGENT on all 138 turns, so the
turns on which the gate could otherwise have passed are exactly the 9 turns on
which the oracle also said CONVERGENT -- and those are exactly the 9 turns the
configuration defect turned red. The defect did not break every turn. It broke
precisely the turns that would otherwise have passed, which is why the gate
showed 0 matches rather than 9.

The theorems below are unaffected: they quantify over readings whose
configuration components differ, and say nothing about how often that difference
is observable. It is the mapping from the model to the artifact that was
overstated, and it is corrected here rather than quietly narrowed.

THE DIRECT PROOF, FROM THE RUN ITSELF
-------------------------------------

Nine of the 138 rows had the SAME mode on both sides. They still read MISMATCH:

    turn 1   router=CONVERGENT sonnet | R/s+ 0.17 oracle=CONVERGENT opus[1m] | R/s+ 0.17 MISMATCH
    turn 11  router=CONVERGENT sonnet | R/s+ 0.17 oracle=CONVERGENT opus[1m] | R/s+ 0.17 MISMATCH
    turn 12  router=CONVERGENT sonnet | R/s+ 0.17 oracle=CONVERGENT opus[1m] | R/s+ 0.17 MISMATCH
    (x3 variants)

Same mode. Same gauge, 0.17 against 0.17. Verdict red. The only difference is
the model tag, which is not a routing decision at all -- and the failure line
claims the turn "disagreed with the artifact's own router", which is a claim
about routing. The instrument reports a routing disagreement it did not observe.

WHICH FAMILY THIS IS -- AND WHY IT IS NOT A TENTH
-------------------------------------------------

This is FAMILY 1 (Vacuous) on its second axis: SIGN.

Family 1 as first written is a gate that cannot return red. This one cannot
return green. The pathology is identical -- a verdict fixed by construction
rather than determined by the subject -- and the sign does not change what is
wrong with it. A permanently-red gate teaches exactly as much about the tree as
a permanently-green one, which is nothing, and `the_verdict_ignores_the_mode`
below proves that in the strong form: the verdict is invariant under exchanging
the two routing decisions, so it is not a function of routing at all.

This is the same move already recorded for FAMILY 7, which gained a second axis
(subject, alongside time) rather than becoming a tenth family. Nine families
stands. Growing the taxonomy to score a finding is the over-purification the
compendium warns against.

WHAT IS PROVED HERE, AND WHAT IS ONLY MEASURED
----------------------------------------------

PROVED (below): a comparator whose two sides read different configuration
returns red for every pair of routing decisions; it stays red when the routing
decisions agree; its verdict is independent of routing entirely; and BOTH
candidate repairs restore discernment -- comparing the mode alone
(`modeOnly`), or giving the two sides the same configuration
(`shared_config_restores_the_whole_line`). The repaired comparator is shown
non-vacuous: it still returns red on a genuine mode disagreement.

MEASURED, NOT PROVED, AND NOT YET ATTRIBUTED: across all 138 turns the live
router emitted one single verdict, `CONVERGENT sonnet | R/s+ 0.17`, while the
oracle produced ten distinct verdicts on those same prompts, with an uneven
prompt-shaped spread (16/16/16/15/14/13/13/13/13/9). The oracle varies with the
prompt; the in-session router did not vary at all. That is a real observation
and it is NOT explained by the configuration defect proved here -- the config
defect explains why every row reads MISMATCH, not why one side is constant.
The mechanism behind the constancy is UNATTRIBUTED. A correlation is not a
cause, and it is recorded as open rather than guessed at.
-/

import Proofs.RotVacuousGate

namespace RotMoE.Comparator

open RotMoE.Vacuity
open Verdict

/-- A routing decision: which lane the prompt was sent down. -/
abbrev Mode := Nat

/-- A configuration source. Distinct values are distinct settings files. -/
abbrev Config := Nat

/-- One rendered router line. It carries the routing decision, which depends on
the prompt, and a tag derived from the configuration, which does not.
`hooks/rot-router.sh:167`. -/
structure Reading where
  mode : Mode
  cfg  : Config
deriving DecidableEq, Repr

/-- Whole-line equality: what `checker/release-longsession.sh:259` actually
compares. Both components must agree. -/
def wholeLine (a b : Reading) : Verdict :=
  if a.mode = b.mode ∧ a.cfg = b.cfg then green else red

/-- Mode-only equality: what the failure message at `:178` CLAIMS to compare
when it says a turn "disagreed with the artifact's own router". -/
def modeOnly (a b : Reading) : Verdict :=
  if a.mode = b.mode then green else red

/-- A verdict function is independent of the routing decisions when no choice of
either one can change it. This is the precise sense in which such a gate
measures nothing about routing. -/
def IndependentOfMode (f : Mode → Mode → Verdict) : Prop :=
  ∀ m₁ m₂ m₃ m₄, f m₁ m₂ = f m₃ m₄

/-- The sandbox reads `"model": "sonnet"` (`:200`). -/
def sandbox : Config := 0

/-- The oracle, given no `CLAUDE_CONFIG_DIR`, reads the host settings (`:232`). -/
def host : Config := 1

theorem the_two_sides_read_different_configuration : sandbox ≠ host := by decide

/-- The core defect. Different configuration forces red for EVERY pair of
routing decisions -- the prompt cannot rescue it. -/
theorem differing_config_forces_red (a b : Reading) (h : a.cfg ≠ b.cfg) :
    wholeLine a b = red := by
  simp [wholeLine, h]

/-- The nine observed rows, in general form: the modes agree, and the verdict is
still red. This is the case that proves the failure message is describing
something it did not observe. -/
theorem red_even_when_the_modes_agree
    (a b : Reading) (hm : a.mode = b.mode) (hc : a.cfg ≠ b.cfg) :
    wholeLine a b = red ∧ modeOnly a b = green := by
  exact ⟨by simp [wholeLine, hc], by simp [modeOnly, hm]⟩

/-- No routing decision whatsoever makes the gate green. Unsatisfiable, not
merely failing. -/
theorem no_mode_makes_it_green (c₁ c₂ : Config) (h : c₁ ≠ c₂) (m₁ m₂ : Mode) :
    wholeLine ⟨m₁, c₁⟩ ⟨m₂, c₂⟩ ≠ green := by
  simp [wholeLine, h]

/-- The strong form: with the configurations fixed apart, the verdict is
invariant under exchanging BOTH routing decisions, so it is not a function of
routing at all. A gate in this state measures nothing about the thing its
failure message names. -/
theorem the_verdict_ignores_the_mode (c₁ c₂ : Config) (h : c₁ ≠ c₂) :
    IndependentOfMode (fun x y => wholeLine ⟨x, c₁⟩ ⟨y, c₂⟩) := by
  intro m₁ m₂ m₃ m₄
  simp [wholeLine, h]

/-- FAMILY 1, second axis. A gate pinned green is independent of routing in
exactly the same sense as one pinned red: the sign of the constant is not what
is wrong with it. -/
theorem always_green_is_equally_uninformative :
    IndependentOfMode (fun _ _ => green) := by
  intro _ _ _ _; rfl

/-- The two comparators genuinely disagree, so the choice between them is a real
decision and not a restatement. -/
theorem the_two_comparators_disagree :
    ∃ a b : Reading, wholeLine a b ≠ modeOnly a b := by
  refine ⟨⟨0, sandbox⟩, ⟨0, host⟩, ?_⟩
  decide

/-- REPAIR 1 -- compare the routing decision alone. The configuration can no
longer block a match. -/
theorem modeOnly_ignores_the_config (m : Mode) (c₁ c₂ : Config) :
    modeOnly ⟨m, c₁⟩ ⟨m, c₂⟩ = green := by
  simp [modeOnly]

/-- REPAIR 1 is not vacuous: it still returns red on a genuine routing
disagreement, which is the property the original gate was reaching for. -/
theorem modeOnly_still_returns_red (m₁ m₂ : Mode) (c₁ c₂ : Config) (h : m₁ ≠ m₂) :
    modeOnly ⟨m₁, c₁⟩ ⟨m₂, c₂⟩ = red := by
  simp [modeOnly, h]

/-- REPAIR 2 -- give both sides the same configuration, by exporting
`CLAUDE_CONFIG_DIR="$CFG"` to the oracle. Whole-line equality then agrees with
mode-only equality everywhere, so the original comparator becomes correct
without being rewritten. -/
theorem shared_config_restores_the_whole_line (m₁ m₂ : Mode) (c : Config) :
    wholeLine ⟨m₁, c⟩ ⟨m₂, c⟩ = modeOnly ⟨m₁, c⟩ ⟨m₂, c⟩ := by
  simp [wholeLine, modeOnly]

/-- Both repairs land on the same verdict, so they are interchangeable and the
choice between them is one of engineering taste, not of correctness. -/
theorem the_two_repairs_agree (m₁ m₂ : Mode) (c : Config) :
    wholeLine ⟨m₁, c⟩ ⟨m₂, c⟩ = modeOnly ⟨m₁, sandbox⟩ ⟨m₂, host⟩ := by
  simp [wholeLine, modeOnly]

/-- And the repaired gate can return green, which the broken one never could --
the property that separates an instrument from a constant. -/
theorem the_repaired_gate_can_be_green :
    modeOnly ⟨7, sandbox⟩ ⟨7, host⟩ = green := by decide

end RotMoE.Comparator
