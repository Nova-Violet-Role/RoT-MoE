/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Authors: Saimono
-/

/-! # A hook that serves N events cannot ASSERT its event name

MEASURED 2026-08-10 on Claude Code **2.1.226** (the Socio's report, reproduced here):

```
PostToolUse:Bash hook error
Failed to run: Hook returned incorrect event name: expected 'PostToolUse' but got 'PreToolUse'.
Full stdout: { ... }
```

`~/.claude/tools/codemap-ext/cartographer-guard.ps1` was wired on **three** events
(`~/.claude/settings.json:117` PostToolUse, `:189` PostToolUseFailure, plus PreToolUse) and
emitted a **hardcoded** `hookEventName = 'PreToolUse'` at its two payload sites (lines 290, 330 of
the pre-fix file, kept as `.pre-evtname.bak`). Claude Code validates that field against the event
it actually fired and rejects the entire payload, so:

* on PreToolUse the advice arrived,
* on the other two events it was **dropped and replaced by a hook error**.

`~/.claude/tools/cavecrew/guard-agent-depth.ps1:129` had the same defect, and worse: its payload
carries `permissionDecision = 'deny'`, which cannot mean anything once the tool has already run.

This module states why the repair is FORCED rather than preferred. It is deliberately quantified
over the event, so adding a fourth or fifth hook event later cannot make it false — the failure
mode the Socio's spec calls a *dated theorem*.

Measured after the fix (all with controls, `pwsh -NoProfile -File … < payload.json`):

```
sent=PostToolUse         got="hookEventName":"PostToolUse"
sent=PreToolUse          got="hookEventName":"PreToolUse"
sent=PostToolUseFailure  got="hookEventName":"PostToolUseFailure"
field absent             got="hookEventName":"PreToolUse"      (documented fallback)
pre-fix .bak, PostToolUse got="hookEventName":"PreToolUse"     (the defect, exhibited)
guard-agent-depth: PreToolUse -> deny STILL fires; PostToolUse -> silent
```
-/

namespace Proofs.Hooks.HookEventEcho

/-- The hook events this machine wires. `other` stands for every event not yet enumerated, which
is what keeps the theorems below from expiring when Claude Code adds one. -/
inductive Evt
  | pre
  | post
  | postFail
  | userPrompt
  | sessionStart
  | other
  deriving DecidableEq, Repr

open Evt

/-- Claude Code 2.1.226 accepts a hook payload only when the name it declares is the event that
actually fired. This is the whole contract, and it is the reason a constant cannot work. -/
def accepted (declared fired : Evt) : Bool := declared = fired

/-- A hook's emitter: given the event that fired, the name it puts in `hookEventName`. -/
abbrev Emitter := Evt → Evt

/-- The repair: echo what arrived. -/
def echoed : Emitter := fun e => e

/-- The shipped defect: assert one name regardless. -/
def asserted : Emitter := fun _ => pre

/-- The payload reaches the model iff the declared name agrees with the fired event. -/
def delivers (f : Emitter) (e : Evt) : Bool := accepted (f e) e

/-- The three events `cartographer-guard.ps1` is wired on (`settings.json:117,189` + PreToolUse). -/
def wired : List Evt := [pre, post, postFail]

/-! ## The echo is total; the assertion is not -/

theorem echo_delivers_on_every_event (e : Evt) : delivers echoed e = true := by
  simp [delivers, echoed, accepted]

/-- Negative control: the shipped constant fails on the very event the Socio saw fail. -/
theorem asserted_fails_on_post : delivers asserted post = false := by decide

theorem asserted_fails_on_postFail : delivers asserted postFail = false := by decide

/-- Exactly one of the wired events survived the constant — which is why two thirds of the
advice silently became hook errors. -/
theorem asserted_delivers_on_pre_alone (e : Evt) : delivers asserted e = true ↔ e = pre := by
  cases e <;> simp [delivers, asserted, accepted]

theorem the_constant_dropped_two_of_three_wired_events :
    (wired.filter (delivers asserted)).length = 1 := by decide

theorem the_echo_keeps_all_three :
    (wired.filter (delivers echoed)).length = wired.length := by decide

/-! ## The repair is FORCED, not a preference

This is the part that must not be stated about today's event list only: *any* emitter that
delivers on every event **is** the identity, and no constant emitter can deliver everywhere. So
"echo the event" is the unique solution, for any future set of events with at least two members. -/

theorem only_the_identity_delivers_everywhere (f : Emitter) :
    (∀ e, delivers f e = true) ↔ f = echoed := by
  constructor
  · intro h
    funext e
    have := h e
    simpa [delivers, accepted, echoed] using this
  · intro h e
    subst h
    exact echo_delivers_on_every_event e

/-- No constant name works, whatever it is: pick any other event and it disagrees. Stated with an
explicit witness so it cannot be vacuous. -/
theorem no_constant_emitter_delivers_everywhere (c : Evt) :
    ¬ (∀ e, delivers (fun _ => c) e = true) := by
  intro h
  -- two distinct events exist, so the constant is wrong on at least one of them
  by_cases hc : c = pre
  · have hp := h post
    simp [delivers, accepted, hc] at hp
  · have hp := h pre
    simp [delivers, accepted] at hp
    exact hc hp

/-! ## `deny` cannot be expressed after the tool has run

`guard-agent-depth.ps1` denies a nested subagent spawn. A `permissionDecision` is only meaningful
BEFORE the call, so on any other event the sound output is silence — and, critically, the repair
must not silence the PreToolUse denial, which would disarm the depth cap. Both directions are
proved, so the fix cannot be mistaken for a weakening. -/

inductive Out
  | silent
  | advice
  | deny
  deriving DecidableEq, Repr

/-- `true` exactly where a permission decision can still change anything. -/
def denyIsMeaningful : Evt → Bool
  | pre => true
  | _ => false

/-- The repaired guard: deny before the call, silence elsewhere. -/
def guard (fired : Evt) (nested : Bool) : Out :=
  if fired = pre then (if nested then Out.deny else Out.silent) else Out.silent

/-- The shipped guard: it emitted the deny payload on whatever event fired. -/
def shippedGuard (_fired : Evt) (nested : Bool) : Out :=
  if nested then Out.deny else Out.silent

theorem guard_never_denies_where_deny_is_meaningless (e : Evt) (n : Bool)
    (h : denyIsMeaningful e = false) : guard e n = Out.silent := by
  cases e <;> simp_all [guard, denyIsMeaningful]

/-- ANTI-DISARM. The depth cap still fires where it can act; the repair removed noise, not
enforcement. -/
theorem guard_still_denies_a_nested_spawn : guard pre true = Out.deny := by decide

theorem guard_allows_a_top_level_spawn : guard pre false = Out.silent := by decide

/-- Negative control: the shipped guard emitted a deny on an event where it cannot mean anything —
which is exactly the payload Claude Code refused. -/
theorem the_shipped_guard_denied_after_the_fact :
    shippedGuard post true = Out.deny ∧ denyIsMeaningful post = false := by decide

/-- The two guards agree wherever a decision is meaningful, so nothing real was lost. -/
theorem the_repair_changes_nothing_where_it_matters (n : Bool) :
    guard pre n = shippedGuard pre n := by
  cases n <;> decide

/-! ## Executable checks — the definitions run, not merely elaborate -/

#guard delivers echoed post = true
#guard delivers asserted post = false
#guard (wired.filter (delivers asserted)).length = 1
#guard (wired.filter (delivers echoed)).length = 3
#guard guard pre true = Out.deny
#guard guard post true = Out.silent
#guard shippedGuard post true = Out.deny

end Proofs.Hooks.HookEventEcho
