/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/
import Mathlib

/-! # What an observation channel does NOT tell you

Every theorem here was extracted from a defect measured on 2026-08-06 while
installing the published `0.8.2` plugin into the Claude Test Terminal (CTT) and
holding a real 20-turn session against it. Four separate times, an observation
reported *less* than the truth, and three of those four invited the same wrong
inference: **absence of evidence in a lossy channel read as evidence of absence.**

| measured | the wrong inference it invited |
|---|---|
| `settings.json` byte-identical before and after the plugin install | "the install did nothing" |
| `validate` piped to `head` reported `rc=0` on a 4-error manifest | "the artifact is valid" |
| `claude plugin update rot-moe` -> `Plugin "rot-moe" not found` | "the plugin is not installed" |
| `marker seen in 0 transcript(s)` across 20 turns | "the hook never fired" |

Every one of those four inferences is FALSE, and in three cases the truth was the
exact opposite. The router had fired 39 times while the transcript showed zero
markers; the plugin was installed and enabled while the lookup said not found;
the install had bound three hook events while `settings.json` did not move.

This module states, once and in general, why each channel is silent -- so the
silence is documented as a property of the instrument rather than rediscovered
as a panic.

**Scope, stated so it is not oversold.** Nothing here proves the CTT install
works; `checker/ctt-session.sh` measures that, and its report is the evidence.
What is proved here is that four specific readings CANNOT support the
conclusions they appear to support -- which is what stops a future session from
"fixing" a non-problem.
-/

namespace RotObserve

/-! ## 1. Two arming paths, and why `settings.json` cannot see one of them

`ARM_ROUTER.sh` writes hook entries into `~/.claude/settings.json`. A marketplace
install binds the very same hooks through the plugin's own `hooks/hooks.json`,
and touches `settings.json` not at all.

Measured 2026-08-06: after `claude plugin update rot-moe@rot-moe` took CTT from
`0.7.2` to `0.8.2`, a diff of `settings.json` against the pre-install backup was
EMPTY, while the installed cache bound `UserPromptSubmit`, `PreToolUse` and
`PostToolUse`, and the router went on to fire 39 times in the session that
followed. -/

/-- Which mechanism binds the router. Both are real; either alone suffices. -/
structure Binding where
  bySettings : Bool
  byPlugin : Bool
  deriving DecidableEq, Repr

/-- The router runs if *either* mechanism bound it. -/
def armed (b : Binding) : Bool := b.bySettings || b.byPlugin

/-- Both mechanisms binding the same hook is the double-registration defect:
the router fires twice per event. -/
def doubleBound (b : Binding) : Bool := b.bySettings && b.byPlugin

/-- An untouched `settings.json` says nothing about whether the router is armed.
Stated over an arbitrary `Binding`, not over the one measured in CTT. -/
theorem settings_silence_is_not_disarm (b : Binding)
    (hs : b.bySettings = false) (hp : b.byPlugin = true) : armed b = true := by
  simp [armed, hs, hp]

/-- The durable form, and the one that matters: `settings.json` is not a
sufficient observation of armedness. Two installs can agree on every byte of
`settings.json` and disagree on whether the router runs. -/
theorem settings_alone_cannot_decide_armed :
    ∃ b₁ b₂ : Binding, b₁.bySettings = b₂.bySettings ∧ armed b₁ ≠ armed b₂ := by
  refine ⟨⟨false, true⟩, ⟨false, false⟩, rfl, ?_⟩
  simp [armed]

/-- `ARM_ROUTER` consults the plugin registry and refuses when the plugin
already binds the router. This is that guard. -/
def armSettings (b : Binding) : Binding :=
  if b.byPlugin then b else { b with bySettings := true }

/-- The guard creates no new double binding. -/
theorem guard_creates_no_double (b : Binding) (h : doubleBound b = false) :
    doubleBound (armSettings b) = false := by
  unfold armSettings doubleBound at *
  cases hp : b.byPlugin <;> cases hs : b.bySettings <;> simp_all

/-- Refusing to write is not refusing to work: after the guard runs, the router
is armed no matter which branch was taken. This is why the CTT refusal was
correct and not a failed install. -/
theorem guard_still_leaves_it_armed (b : Binding) : armed (armSettings b) = true := by
  unfold armSettings armed
  cases hp : b.byPlugin <;> simp [hp]

/-- Without the guard, arming a plugin install double-binds. The defect the
guard exists to prevent, stated as the theorem it is. -/
theorem unguarded_arm_double_binds (b : Binding) (hp : b.byPlugin = true) :
    doubleBound { b with bySettings := true } = true := by
  simp [doubleBound, hp]

/-! ## 2. An exit code read through a pipe is the pipe's, not the tool's

Measured 2026-08-06, and self-inflicted: `claude plugin validate ctl | head -12`
followed by `$?` reported **0** on a manifest the same command flags with four
errors. Re-run without the pipe, the true status is **1**.

The model is a pipeline as a list of stage exit codes; what a naive `$?` reads
is the last one. -/

/-- What `$?` reports for a pipeline, given the stages' own exit codes. -/
def observed : List Nat → Nat
  | [] => 0
  | [r] => r
  | _ :: rest => observed rest

/-- Reading a command's status directly is faithful -- the one-stage case. -/
theorem direct_read_is_faithful (r : Nat) : observed [r] = r := rfl

/-- A pipeline reports its LAST stage, whatever came before it. -/
theorem observed_is_the_last_stage : ∀ (pre : List Nat) (r : Nat),
    observed (pre ++ [r]) = r
  | [], r => rfl
  | [_], r => rfl
  | _ :: b :: rest, r => by
      simpa [observed] using observed_is_the_last_stage (b :: rest) r

/-- **The general defect.** A filter that always succeeds masks EVERY failure --
not merely the exit 1 that was measured. Quantified over `r`, so no future exit
code escapes it. -/
theorem green_filter_masks_every_failure (r : Nat) : observed [r, 0] = 0 := rfl

/-- Consequently the observation is constant in the tool's status: the reading
cannot distinguish success from any failure. -/
theorem piped_reading_is_blind (r₁ r₂ : Nat) : observed [r₁, 0] = observed [r₂, 0] := rfl

/-- The measured instance, kept as a concrete witness of the general theorem:
`validate` exited 1, `head` exited 0, `$?` read 0. -/
example : observed [1, 0] = 0 := by decide

/-- And the control that makes the green meaningful: read directly, the failure
is visible. -/
example : observed [1] = 1 := by decide

/-! ## 3. A lookup that misses is not a plugin that is absent

Measured 2026-08-06: `claude plugin update rot-moe` answered
`✘ Failed to update plugin "rot-moe": Plugin "rot-moe" not found`, while
`claude plugin list` showed `rot-moe@rot-moe` installed and enabled at `0.7.2`.
The qualified id `rot-moe@rot-moe` updated it to `0.8.2` at exit 0.

The plugin was never absent. The *query* was unqualified. -/

/-- A registry entry: the plugin name, the marketplace it came from, and the
version currently installed. -/
structure Registry where
  plugin : String
  marketplace : String
  version : String
  deriving DecidableEq, Repr

/-- Resolution requires the fully qualified `plugin@marketplace` id. -/
def resolves (r : Registry) (query : String) : Bool :=
  query == r.plugin ++ "@" ++ r.marketplace

/-- The qualified id always resolves. -/
theorem qualified_always_resolves (r : Registry) :
    resolves r (r.plugin ++ "@" ++ r.marketplace) = true := by
  simp [resolves]

/-- **The bare name can never resolve**, for any plugin and any non-empty
marketplace -- a length argument, so it holds for every name rather than for the
one that was measured. -/
theorem bare_name_never_resolves (r : Registry) (h : r.marketplace ≠ "") :
    resolves r r.plugin = false := by
  simp only [resolves, beq_eq_false_iff_ne, ne_eq]
  intro hEq
  have hlen := congrArg String.length hEq
  simp [String.length_append] at hlen
  have : r.marketplace.length = 0 := by omega
  exact h (String.ext_iff.mpr (by
    have := String.length_eq_zero_iff.mp this
    simpa using this))

/-- Therefore a failed lookup carries no information about installedness: here
is a registry with a real installed version whose bare-name query fails. -/
theorem lookup_failure_is_not_absence :
    ∃ r : Registry, r.version ≠ "" ∧ resolves r r.plugin = false := by
  refine ⟨⟨"rot-moe", "rot-moe", "0.7.2"⟩, by simp, ?_⟩
  apply bare_name_never_resolves
  simp

/-! ## 4. A silent transcript is not a hook that slept

The router injects its lane and R/s+ as *context*, and the internal-only seal
forbids the model from printing that trace. So a transcript scan for the marker
finds nothing even when every hook fired.

Measured 2026-08-06 over 20 real CTT turns: `marker seen in 0 transcript(s)` in
all four chunks, while the debug log recorded **39 route records and 39 gauge
records**, every one with `K = 9` and nine lens terms whose sum recomputes the
logged R/s+ to within 2e-5.

Zero markers is the seal WORKING. It is not a firing count. -/

/-- One turn, as the two observations available: did the hook run, and did the
marker appear in what the model said. -/
structure Turn where
  hookRan : Bool
  markerInTranscript : Bool
  deriving DecidableEq, Repr

/-- The internal-only seal: the trace is never volunteered. -/
def sealed (t : Turn) : Bool := !t.markerInTranscript

/-- How many turns actually fired the hook. -/
def firings (ts : List Turn) : Nat := (ts.filter (fun t => t.hookRan)).length

/-- How many turns a transcript scan would count. -/
def markers (ts : List Turn) : Nat := (ts.filter (fun t => t.markerInTranscript)).length

/-- A sealed turn that fired is exactly the measured shape. -/
theorem sealed_firing_exists : ∃ t : Turn, t.hookRan = true ∧ sealed t = true := by
  exact ⟨⟨true, false⟩, rfl, rfl⟩

/-- **The marker count is not a firing count, at any scale.** For every `n`
there is a run of turns with `n` firings and zero markers -- so `markers = 0`
bounds nothing. 39-and-0 was not a coincidence; it is the only thing the seal
permits. -/
theorem any_number_of_firings_can_be_invisible (n : Nat) :
    ∃ ts : List Turn, firings ts = n ∧ markers ts = 0 := by
  refine ⟨List.replicate n ⟨true, false⟩, ?_, ?_⟩
  · simp [firings]
  · simp [markers]

/-- The seal holding across a whole run is exactly `markers = 0`. Stated so the
checker's note has a meaning: it reports the seal, not the router. -/
theorem markers_zero_iff_all_sealed (ts : List Turn) :
    markers ts = 0 ↔ ∀ t ∈ ts, sealed t = true := by
  simp [markers, sealed, List.length_eq_zero_iff, List.filter_eq_nil_iff]

/-- And the converse warning: a run with markers is a run where the trace
LEAKED, which is a defect of the seal rather than evidence of health. -/
theorem a_marker_means_a_leak (ts : List Turn) (h : markers ts ≠ 0) :
    ∃ t ∈ ts, sealed t = false := by
  by_contra hc
  push Not at hc
  exact h ((markers_zero_iff_all_sealed ts).mpr (fun t ht => by
    have := hc t ht
    simpa using this))

/-! ## The common shape

All four are the same theorem wearing different clothes: a projection that
forgets a component cannot decide a property that depends on it. -/

/-- The unifying statement. If a reading `obs` is blind to a component that
`truth` depends on, then equal readings coexist with unequal truths -- so no
amount of care in interpreting the reading can recover the property.

**Labelled honestly: this is a repackaging, not a discovery.** `#print axioms`
reports it depends on NOTHING, which is the signature of a near-tautology -- the
proof hands back the very witnesses it was given. Its worth is entirely in the
instances below and in the four sections above, each of which does supply a real
witness pair. It is stated separately only so the shape has a name. -/
theorem blind_reading_cannot_decide
    {α β : Type} (obs : α → β) (truth : α → Bool) (x y : α)
    (hobs : obs x = obs y) (htruth : truth x ≠ truth y) :
    ∃ u v : α, obs u = obs v ∧ truth u ≠ truth v :=
  ⟨x, y, hobs, htruth⟩

/-- The arming case is an instance of it: read only `bySettings`, and armedness
becomes undecidable. -/
theorem arming_is_an_instance :
    ∃ u v : Binding, (fun b => b.bySettings) u = (fun b => b.bySettings) v ∧
      armed u ≠ armed v :=
  blind_reading_cannot_decide (fun b => b.bySettings) armed
    ⟨false, true⟩ ⟨false, false⟩ rfl (by simp [armed])

end RotObserve
