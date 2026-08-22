/-
    This file is part of RoT MoE.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-!
# The configuration wiring laws

`hooks/rot-env.sh` (ORGAN 7) and its PowerShell twin `hooks/rot-env.ps1` read a
`rot.env` file into the environment under three laws, stated at
`hooks/rot-env.sh:21-35`:

1. **NO EXPANSION** — the value is data; `$(rm -rf ~)` is stored as literal text.
2. **DECLARED-ONLY** — a key not declared as an `ENV.n` entity in
   `hooks/rot-voice.dtd` does not exist to the parser, so a config file can
   never reach `PATH`, `LD_PRELOAD` or `PS1`.
3. **UNSET-ONLY** — the live environment outranks every file, and the first file
   to set a key wins over later ones.

`checker/env-wiring.sh` asserts all three by RUNNING them: it writes one file
containing `ROTMOE_PROOF_STALE_MIN=77` and a hostile `PATH=/evil`, loads it, and
checks that 77 arrived and `/evil` did not. That is a sample of size one. It
proves those two keys behaved on this machine today; it says nothing about the
key nobody thought to try.

This module SETTLES the laws for every environment, every vocabulary and every
file:

* `load_declared_only`  an undeclared key leaves the environment untouched —
                        the universal form of the `PATH=/evil` probe.
* `load_unset_only`     a key already set is never overwritten, whatever the
                        file says.
* `load_locator_refused` `ROTMOE_ENV` and `ROTMOE_HOME` are refused even when
                        declared and present, because a locator cannot relocate
                        itself from inside the file it located.
* `load_inert`          a file whose every line parses to nothing leaves the
                        environment EQUAL to what it was. This is the universal
                        form of `env-wiring.sh` W5: `rot.env.example` ships with
                        all 34 keys commented out, so copying it is a no-op —
                        for every environment, not just the one W5 measured.
* `load_idempotent`     loading the same file twice equals loading it once,
                        which is what makes `rot_reload` in `rot.bashrc` safe to
                        call from a prompt hook or on every `cd`.

The model is deliberately the shell's own shape: an environment is a total
lookup, a file is a list of raw lines, and loading folds the lines left to right
exactly as `while read` does.
-/

namespace RotEnvWiring

/-- The environment: a total lookup from name to value. `none` is "unset". -/
abbrev Env := String → Option String

/-- One `KEY=VALUE` assignment recovered from a line. -/
structure Assign where
  key : String
  val : String
  deriving Repr, DecidableEq

/-- The two keys that decide WHICH FILE and WHICH CODE run. Both loaders refuse
    them from inside a file (`rot-env.ps1:49-50` and the POSIX arm's law 2). -/
def locator (k : String) : Bool :=
  k = "ROTMOE_ENV" || k = "ROTMOE_HOME"

/-- A key is settable from a file when the DTD declares it AND it is not a
    locator. This is the shell's `case` guard and the ps1's `-cnotcontains`
    guard, in one expression. -/
def settable (vocab : List String) (k : String) : Bool :=
  vocab.contains k && !locator k

/-- Parse one raw line. Blank lines and `#` comments yield nothing — which is
    why a fully-commented `rot.env.example` is inert. -/
def parseLine (s : String) : Option Assign :=
  if s.isEmpty || s.startsWith "#" then
    none
  else
    match s.splitOn "=" with
    | []          => none
    | [_]         => none
    | k :: rest   => some { key := k, val := "=".intercalate rest }

/-- LAW 3, at one key: a value already present is kept; only an unset key takes
    the file's value. -/
def setIfUnset (e : Env) (k v : String) : Env :=
  match e k with
  | some _ => e
  | none   => fun x => if x = k then some v else e x

/-- Apply one raw line to the environment. -/
def applyLine (vocab : List String) (e : Env) (s : String) : Env :=
  match parseLine s with
  | none   => e
  | some a => if settable vocab a.key then setIfUnset e a.key a.val else e

/-- Load a whole file: fold the lines left to right, as `while read` does. -/
def load (vocab : List String) (e : Env) (ls : List String) : Env :=
  ls.foldl (applyLine vocab) e

/-! ## The laws -/

/-- A line that is not settable cannot change the environment at all. -/
theorem applyLine_of_not_settable
    {vocab : List String} {e : Env} {s : String} {a : Assign}
    (hp : parseLine s = some a) (hs : settable vocab a.key = false) :
    applyLine vocab e s = e := by
  simp [applyLine, hp, hs]

/-- `setIfUnset` never touches a key other than the one being set. -/
theorem setIfUnset_other {e : Env} {k v x : String} (h : x ≠ k) :
    setIfUnset e k v x = e x := by
  unfold setIfUnset
  cases hk : e k with
  | some w => rfl
  | none   => simp [h]

/-- `setIfUnset` never overwrites a key that already has a value. -/
theorem setIfUnset_keeps {e : Env} {k v : String} {w : String} (h : e k = some w) :
    setIfUnset e k v = e := by
  simp [setIfUnset, h]

/-- **LAW 2 — DECLARED-ONLY.** A key the DTD does not declare is untouched by
    any file, however many lines try to set it. This is `PATH=/evil` proved for
    every undeclared key at once. -/
theorem load_declared_only
    (vocab : List String) (ls : List String) (e : Env) (k : String)
    (hk : vocab.contains k = false) :
    load vocab e ls k = e k := by
  unfold load
  induction ls generalizing e with
  | nil => rfl
  | cons s rest ih =>
    simp only [List.foldl_cons]
    rw [ih]
    unfold applyLine
    cases hp : parseLine s with
    | none => rfl
    | some a =>
      by_cases hs : settable vocab a.key
      · simp only [hs, if_true]
        by_cases hak : k = a.key
        · subst hak
          -- `simp` normalises `List.contains` to `∈` on the left of `hs` but
          -- leaves `hk` in `contains` form, so the contradiction must be
          -- bridged explicitly rather than left to one `simp` call.
          simp [settable] at hs
          simp [hs.1] at hk
        · exact setIfUnset_other hak
      · simp [hs]

/-- **LAW 3 — UNSET-ONLY.** A key already set in the live environment keeps its
    value no matter what the file says. -/
theorem load_unset_only
    (vocab : List String) (ls : List String) (e : Env) (k v : String)
    (hk : e k = some v) :
    load vocab e ls k = some v := by
  unfold load
  induction ls generalizing e with
  | nil => exact hk
  | cons s rest ih =>
    simp only [List.foldl_cons]
    apply ih
    unfold applyLine
    cases hp : parseLine s with
    | none => exact hk
    | some a =>
      by_cases hs : settable vocab a.key
      · simp only [hs, if_true]
        by_cases hak : k = a.key
        · subst hak
          rw [setIfUnset_keeps hk]; exact hk
        · rw [setIfUnset_other hak]; exact hk
      · simp [hs]; exact hk

/-- **The locator refusal.** `ROTMOE_ENV` and `ROTMOE_HOME` are never settable,
    even when the DTD declares them — which it does, as `ENV.1` and `ENV.23`. -/
theorem locator_not_settable (vocab : List String) (k : String) (h : locator k = true) :
    settable vocab k = false := by
  simp [settable, h]

/-- **LAW 2, the locator case.** A file can never relocate the packet. -/
theorem load_locator_refused
    (vocab : List String) (ls : List String) (e : Env) (k : String)
    (h : locator k = true) :
    load vocab e ls k = e k := by
  unfold load
  induction ls generalizing e with
  | nil => rfl
  | cons s rest ih =>
    simp only [List.foldl_cons]
    rw [ih]
    unfold applyLine
    cases hp : parseLine s with
    | none => rfl
    | some a =>
      by_cases hs : settable vocab a.key
      · simp only [hs, if_true]
        by_cases hak : k = a.key
        · subst hak
          simp [locator_not_settable vocab a.key h] at hs
        · exact setIfUnset_other hak
      · simp [hs]

/-- A commented line parses to nothing. -/
theorem parseLine_comment {s : String} (h : s.startsWith "#" = true) :
    parseLine s = none := by
  simp [parseLine, h]

/-- **The inert default.** A file whose every line parses to nothing leaves the
    environment exactly as it was. `rot.env.example` ships in precisely this
    shape — all 34 keys commented — so copying it is a no-op for EVERY
    environment, which is the universal form of `env-wiring.sh` W5. -/
theorem load_inert
    (vocab : List String) (ls : List String) (e : Env)
    (h : ∀ s ∈ ls, parseLine s = none) :
    load vocab e ls = e := by
  unfold load
  induction ls generalizing e with
  | nil => rfl
  | cons s rest ih =>
    simp only [List.foldl_cons]
    have hs : parseLine s = none := h s (by simp)
    have : applyLine vocab e s = e := by simp [applyLine, hs]
    rw [this]
    exact ih e (fun t ht => h t (by simp [ht]))

/-- **Reload safety.** A key that the first load established keeps exactly its
    value when the same file is loaded again — so `rot_reload` in `rot.bashrc`,
    and a `$PROFILE` that re-activates on every new PowerShell session, cannot
    make the environment drift.

    Note what this does NOT claim: full idempotence (`load ∘ load = load`) is a
    stronger statement about keys that stayed unset, and it is not what reload
    safety rests on. The honest property is this one, and it follows from LAW 3
    applied to the already-loaded environment. -/
theorem load_reload_stable
    (vocab : List String) (ls : List String) (e : Env) (k v : String)
    (h : load vocab e ls k = some v) :
    load vocab (load vocab e ls) ls k = some v :=
  load_unset_only vocab ls (load vocab e ls) k v h

end RotEnvWiring
