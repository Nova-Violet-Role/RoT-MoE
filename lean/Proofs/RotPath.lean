/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

/-!
# Path canonicalisation — the theorem the stranding bug asked for

## Why this file exists

`ARM_ROUTER` writes a hook entry whose **command string is the identity** used
both for idempotence and for removal. The two installer arms wrote that string
differently for the same install:

```
.sh   ->  bash "/c/path/to/RoT MoE/hooks/rot-router.sh"
.ps1  ->  bash "C:\path\to\RoT MoE\hooks\rot-router.sh"
```

Removal matches by exact string, so a user who installed from one shell and
uninstalled from the other kept a **dead hook entry forever**, with both scripts
reporting success. A second, subtler instance survived the first fix: under a
Git Bash mount alias, `bash` says `/tmp/x` where PowerShell says
`/<drive>/tmp/x`.

Both are one defect in one sentence: **two spellings of one path did not
converge to one string.** That is a claim about a pure function, so it belongs
here rather than in a comment.

## A modelling decision, stated because it changes what the theorems mean

The general statements below take the drive character's properties as
**hypotheses** (`d.toLower ≠ ':'`, and so on) instead of deriving them from
`Char.toLower`'s internals. That is deliberate: reasoning about Unicode case
mapping in general would add a large, irrelevant proof burden, and every
hypothesis is **decidable for any concrete character**, so the `example`s at the
foot of the file discharge them by `decide` for real drive letters.

The honest reading: these are theorems about *any* character that behaves like a
drive letter, plus executed evidence that actual drive letters do. That is
stronger than an unproven claim about Unicode and weaker than a universal one —
and saying which is the point.

## What is NOT proved

That the shell and PowerShell implementations *are* this function. Lean
constrains the MODEL. The binding to the shipped code is
`checker/install-roundtrip.sh`, which runs both real installers and compares the
bytes they write. Neither instrument substitutes for the other.
-/

namespace RotMoE.Path

/-- Windows separators become POSIX ones. -/
def slashify (p : List Char) : List Char :=
  p.map (fun c => if c = '\\' then '/' else c)

/-- The canonical form. `C:\a\b` and `c:/a/b` both become `/c/a/b`; an
already-POSIX path keeps its shape.

Mirrors `canon_path()` in the `.sh` arms and `ConvertTo-PosixPath` in the `.ps1`
arms. -/
def normalize (p : List Char) : List Char :=
  match slashify p with
  | d :: ':' :: '/' :: rest =>
      if d.isAlpha then '/' :: d.toLower :: '/' :: rest
      else d :: ':' :: '/' :: rest
  | q => q

/-! ### Slashification -/

/-- Slashification removes every backslash. -/
theorem no_backslash_slashify (p : List Char) : '\\' ∉ slashify p := by
  simp only [slashify, List.mem_map, not_exists, not_and]
  intro c _
  by_cases h : c = '\\' <;> simp [h]

/-- A path with no backslash is untouched by slashification. -/
theorem slashify_eq_self_of_no_backslash {p : List Char} (h : '\\' ∉ p) :
    slashify p = p := by
  induction p with
  | nil => rfl
  | cons c t ih =>
      have hc : c ≠ '\\' := by
        intro hcc; exact h (by simp [hcc])
      have ht : '\\' ∉ t := fun hm => h (List.mem_cons_of_mem _ hm)
      have := ih ht
      simp only [slashify, List.map_cons, if_neg hc] at *
      rw [this]

/-- Slashification is idempotent. -/
theorem slashify_idem (p : List Char) : slashify (slashify p) = slashify p :=
  slashify_eq_self_of_no_backslash (no_backslash_slashify p)

/-! ### The canonical form -/

/-- On a path that is already backslash-free and does not start with a drive
prefix, `normalize` is the identity. This is the case that must not change, or
every Linux user's command string would be silently rewritten. -/
theorem normalize_posix_id {rest : List Char} (h : '\\' ∉ rest)
    (hd : ∀ a b, rest = a :: ':' :: '/' :: b → ¬ a.isAlpha) :
    normalize rest = rest := by
  unfold normalize
  rw [slashify_eq_self_of_no_backslash h]
  cases rest with
  | nil => simp
  | cons a t =>
      cases t with
      | nil => simp
      | cons b t2 =>
          cases t2 with
          | nil => simp
          | cons c t3 =>
              by_cases hb : b = ':'
              · subst hb
                by_cases hc : c = '/'
                · subst hc
                  have ha : ¬ a.isAlpha := hd a t3 rfl
                  simp [ha]
                · simp [hc]
              · simp [hb]

/-- **The load-bearing theorem.** The Windows spelling and the POSIX spelling of
one path canonicalise to the SAME string.

This is the property whose violation stranded the user. Stated over an
ARBITRARY drive character and an arbitrary tail, so it does not expire the day
the repo moves to another drive — a theorem naming a specific drive would be a
snapshot of today, not an invariant. -/
theorem both_spellings_agree (d : Char) (rest : List Char)
    (hd : d.isAlpha) (hdb : d ≠ '\\')
    (hlow_colon : d.toLower ≠ ':') (hlow_bs : d.toLower ≠ '\\')
    (hrest : '\\' ∉ rest) :
    normalize (d :: ':' :: '\\' :: rest) =
      normalize ('/' :: d.toLower :: '/' :: rest) := by
  have hmap : List.map (fun c => if c = '\\' then '/' else c) rest = rest :=
    slashify_eq_self_of_no_backslash hrest
  unfold normalize slashify
  simp only [List.map_cons, if_neg hdb, if_neg hlow_bs, hmap]
  simp [hd, hlow_colon]

/-- Canonicalisation is idempotent. Without this, a second `ARM_ROUTER` run
could produce a different string from the first and defeat the idempotence
detection that keeps the installer from double-installing. -/
theorem no_backslash_normalize (p : List Char)
    (hbs : ∀ a : Char, a.isAlpha → a.toLower ≠ '\\') :
    '\\' ∉ normalize p := by
  have h := no_backslash_slashify p
  unfold normalize
  cases hq : slashify p with
  | nil => simp
  | cons a t =>
      rw [hq] at h
      cases t with
      | nil => simpa using h
      | cons b t2 =>
          cases t2 with
          | nil => simpa using h
          | cons c t3 =>
              by_cases hb : b = ':'
              · subst hb
                by_cases hc : c = '/'
                · subst hc
                  by_cases ha : a.isAlpha
                  · simp only [if_pos ha, List.mem_cons, not_or]
                    simp only [List.mem_cons, not_or] at h
                    exact ⟨by decide, Ne.symm (hbs a ha), by decide, h.2.2.2⟩
                  · simpa [ha] using h
                · simpa [hc] using h
              · simpa [hb] using h

/-- The canonical form never starts with an **alphabetic** drive prefix — that
one has already been rewritten to `/x/...`.

**A false theorem lived here first, and the compiler refused it.** The obvious
statement is "the output never has the shape `a:/b`", and that is simply untrue:
`normalize` deliberately leaves `1:/foo` alone because `1` is not a drive letter,
and the result still *has* that shape. The honest invariant is the one that
makes idempotence work — if the output has the drive shape, its head is **not**
alphabetic, so a second pass cannot rewrite it either. -/
theorem normalize_not_alpha_drive (p : List Char)
    (hc : ∀ a : Char, a.isAlpha → a.toLower ≠ ':') :
    ∀ x y, normalize p = x :: ':' :: '/' :: y → ¬ x.isAlpha := by
  intro x y
  unfold normalize
  cases hq : slashify p with
  | nil => simp
  | cons a t =>
      cases t with
      | nil => simp
      | cons b t2 =>
          cases t2 with
          | nil => simp
          | cons c t3 =>
              by_cases hb : b = ':'
              · subst hb
                by_cases hcc : c = '/'
                · subst hcc
                  by_cases ha : a.isAlpha
                  · -- output is '/' :: a.toLower :: '/' :: t3, whose SECOND
                    -- character is a letter; matching the drive shape would
                    -- force a.toLower = ':', which hc forbids. Vacuous, and
                    -- vacuous for a reason worth naming.
                    simp only [if_pos ha]
                    intro hcon
                    injection hcon with _ h2
                    injection h2 with h3 _
                    exact absurd h3 (hc a ha)
                  · -- output is unchanged, so its head is `a`, which is not
                    -- alphabetic. This is the case that made the obvious
                    -- statement false.
                    simp only [if_neg ha]
                    intro hcon
                    injection hcon with h1 _
                    exact h1 ▸ ha
                · simp [hcc]
              · simp [hb]

/-- Canonicalisation is idempotent. Without this, a second `ARM_ROUTER` run
could produce a different string from the first and defeat the idempotence
detection that keeps the installer from double-installing.

It falls straight out of the two lemmas above: the output has no backslash and
is not drive-prefixed, which is exactly the hypothesis of `normalize_posix_id`.
That is why those two were worth stating separately. -/
theorem normalize_idem (p : List Char)
    (hbs : ∀ a : Char, a.isAlpha → a.toLower ≠ '\\')
    (hc : ∀ a : Char, a.isAlpha → a.toLower ≠ ':') :
    normalize (normalize p) = normalize p :=
  normalize_posix_id (no_backslash_normalize p hbs) (normalize_not_alpha_drive p hc)

/-! ## Executed evidence

The theorems above constrain the model and take the drive character's behaviour
as hypotheses. These `example`s discharge those hypotheses by `decide` for real
drive letters and pin the model to the exact strings the installers handle — so
a definition that drifted from its intent would fail HERE even while every proof
above still closed. -/

/-- `C:\a\b` becomes `/c/a/b` — the exact rewrite `canon_path()` performs. -/
example : String.ofList (normalize "C:\\a\\b".toList) = "/c/a/b" := by decide

/-- A lowercase drive gives the same answer. -/
example : String.ofList (normalize "c:/a/b".toList) = "/c/a/b" := by decide

/-- An already-POSIX path is left alone. -/
example : String.ofList (normalize "/c/a/b".toList) = "/c/a/b" := by decide

/-- A relative path keeps its shape, separators aside. -/
example :
    String.ofList (normalize "hooks\\rot-router.sh".toList) = "hooks/rot-router.sh" := by
  decide

/-- **The stranding pair, executed.** The two spellings that differed in the wild
now produce one string. -/
example :
    String.ofList (normalize "C:\\p\\RoT MoE\\hooks\\rot-router.sh".toList) =
    String.ofList (normalize "/c/p/RoT MoE/hooks/rot-router.sh".toList) := by decide

/-- The mount-alias pair, the second bug: an `X:`-rooted path and its `/x/` form. -/
example :
    String.ofList (normalize "X:\\tmp\\x\\RoT-MoE".toList) =
    String.ofList (normalize "/x/tmp/x/RoT-MoE".toList) := by decide

/-- Idempotence, executed on the real shape. -/
example :
    normalize (normalize "C:\\p\\hooks\\rot-router.sh".toList) =
    normalize "C:\\p\\hooks\\rot-router.sh".toList := by decide

/-- The hypotheses the general theorems take are decidable for real drive
letters: here they are, discharged. -/
example : ('C' : Char).isAlpha ∧ ('C' : Char) ≠ '\\' ∧
    ('C' : Char).toLower ≠ ':' ∧ ('C' : Char).toLower ≠ '\\' := by decide

/-! ## Module derivation — the part that broke three times

Everything above canonicalises a path. This section models what the reminder
hook does NEXT: turn a workspace root plus an edited file path into the Lean
module name it must build. `verify_lean_edit` in `hooks/prover-remind.sh`.

That derivation shipped with three separate defects, and all three were SILENT —
the hook returned no verdict at all, which reads as "nothing to check" rather
than "I could not work out what to build":

1. the workspace prefix was compared in one spelling only, so the POSIX form
   from `pwd` never matched the Windows form the tool call reports;
2. the fallback pattern was lowercase `*/lean/*`, so a workspace at
   `<root>/Lean` — the layout the installer now creates — matched nothing;
3. a path outside the workspace fell through the same silent return.

The fix was to compare canonically. These theorems are why that fix is correct
rather than merely observed to work on this machine: the first says the two
spellings can never disagree again, and the second says the answer does not
depend on how the workspace directory is capitalised or named.
-/

/-- Drop a `.lean` suffix if present. Mirrors `${_rel%.lean}`. -/
def dropLeanExt (p : List Char) : List Char :=
  let n := p.length
  if p.drop (n - 5) = ".lean".toList then p.take (n - 5) else p

/-- `/` becomes `.` — mirrors `tr '/' '.'`. -/
def dotify (p : List Char) : List Char :=
  p.map (fun c => if c = '/' then '.' else c)

/-- Is `pre` a prefix of `p`? -/
def isPrefix (pre p : List Char) : Bool := p.take pre.length = pre

/-- The relative part of `fp` below workspace `ws`, both canonicalised first.
`none` when the file is not inside the workspace — the hook must then stay
silent, and that silence is CORRECT here because there is genuinely nothing to
build, unlike the three cases above.

Stated WITHOUT `let`-bindings on purpose: a `let` in the body survives `unfold`
and blocks `rw`, so the proofs below would have to zeta-reduce it first. The
definition is the same function either way; this spelling is the one that can be
reasoned about directly. -/
def relBelow (ws fp : List Char) : Option (List Char) :=
  if isPrefix (normalize ws ++ ['/']) (normalize fp)
  then some ((normalize fp).drop (normalize ws ++ ['/']).length)
  else none

/-- Workspace root + edited file → module name. The whole derivation. -/
def moduleOf (ws fp : List Char) : Option (List Char) :=
  (relBelow ws fp).map (fun rel => dotify (dropLeanExt rel))

/-- **The load-bearing theorem, and the one defect 1 violated.** The Windows
spelling and the POSIX spelling of the SAME edit yield the SAME module.

This is what makes the hook's answer independent of which tool reported the
path. `both_spellings_agree` above says the two canonicalise alike; this lifts
that all the way to the module name the build actually receives. -/
theorem moduleOf_spelling_invariant (d : Char) (wrest frest : List Char)
    (hd : d.isAlpha) (hb : d ≠ '\\') (hl : d.toLower ≠ ':') (hlb : d.toLower ≠ '\\')
    (hw : '\\' ∉ wrest) (hf : '\\' ∉ frest) :
    moduleOf (d :: ':' :: '\\' :: wrest) (d :: ':' :: '\\' :: frest)
      = moduleOf ('/' :: d.toLower :: '/' :: wrest)
                 ('/' :: d.toLower :: '/' :: frest) := by
  simp only [moduleOf, relBelow,
    both_spellings_agree d wrest hd hb hl hlb hw,
    both_spellings_agree d frest hd hb hl hlb hf]

/-- **The theorem defect 2 violated.** The module name depends only on the
canonical workspace root and the canonical file path — NEVER on how the
workspace directory is spelled or capitalised.

A `<root>/Lean` workspace and a `<root>/lean` one are handled by the same code
path, so the lowercase-only fallback that shipped was not a missing case, it was
the wrong mechanism. Stated over ARBITRARY roots, so it stays true for whatever
directory name a future layout picks — a theorem naming `Lean` would expire the
moment someone chose `Proofs` or `Formal`. -/
theorem moduleOf_root_agnostic (ws₁ ws₂ fp₁ fp₂ : List Char)
    (hw : normalize ws₁ = normalize ws₂) (hf : normalize fp₁ = normalize fp₂) :
    moduleOf ws₁ fp₁ = moduleOf ws₂ fp₂ := by
  unfold moduleOf relBelow
  rw [hw, hf]

/-- A derived module name never contains a path separator — `/` has become `.`
everywhere. A module name with a slash in it is not a module name, and `lake`
would refuse it. -/
theorem moduleOf_no_slash (ws fp m : List Char) (h : moduleOf ws fp = some m) :
    '/' ∉ m := by
  unfold moduleOf at h
  cases hrel : relBelow ws fp with
  | none => simp [hrel] at h
  | some rel =>
      rw [hrel] at h
      simp only [Option.map] at h
      -- `subst` refuses this: after `simp only [Option.map]` the hypothesis is
      -- `some (dotify …) = some m`, an equation between CONSTRUCTOR
      -- APPLICATIONS rather than the `x = t` form `subst` requires. Injecting
      -- and orienting it by hand is the honest fix; reaching for a bigger
      -- hammer here would hide which step actually discharges the goal.
      have hm : m = dotify (dropLeanExt rel) := (Option.some.inj h).symm
      rw [hm]
      unfold dotify
      intro hmem
      rcases List.mem_map.mp hmem with ⟨c, _, hc⟩
      by_cases hcs : c = '/' <;> simp [hcs] at hc

/-- **The theorem for defect 3, and it is the one that keeps the hook HONEST.**
A file outside the workspace yields `none`, so the hook builds nothing rather
than guessing a module name from an unrelated path. Silence is right here; it
was wrong in the other two cases, and this theorem is what separates them. -/
theorem moduleOf_none_of_outside (ws fp : List Char)
    (h : isPrefix (normalize ws ++ ['/']) (normalize fp) = false) :
    moduleOf ws fp = none := by
  unfold moduleOf relBelow
  rw [h]
  rfl

/-! ### Executable checks — the definitions must MEAN this, not merely typecheck -/

/-- The real case: the layout the installer now creates. -/
example : moduleOf "D:/w/Lean".toList "D:/w/Lean/Proofs/First.lean".toList
    = some "Proofs.First".toList := by decide

/-- The SAME edit reported in Windows spelling gives the SAME module. This is
defect 1 as a concrete instance, and it is `by decide`, so it executes.

`checker/no-local-paths.sh` flags the drive-letter literal below, and it is
RIGHT to flag it — it cannot tell a hardcoded machine path from a test vector,
and it must not try. The per-line `R2-ALLOW` marker is that checker's own
intended exemption: narrow, visible in a diff, and counted out loud on every
run. Claimed here because the Windows spelling IS the thing under test; writing
this vector any other way would test something else. -/
example : moduleOf "D:\\w\\Lean".toList "D:\\w\\Lean\\Proofs\\First.lean".toList -- R2-ALLOW
    = some "Proofs.First".toList := by decide

/-- Lowercase `lean` — defect 2 as a concrete instance. Same answer, no special
case anywhere in the code. -/
example : moduleOf "D:/w/lean".toList "D:/w/lean/Proofs/First.lean".toList
    = some "Proofs.First".toList := by decide

/-- A nested module. -/
example : moduleOf "/w/Lean".toList "/w/Lean/Proofs/Deep/Nest.lean".toList
    = some "Proofs.Deep.Nest".toList := by decide

/-- Outside the workspace: nothing is built. -/
example : moduleOf "/w/Lean".toList "/elsewhere/Proofs/X.lean".toList = none := by decide

/-- A path that merely SHARES A PREFIX STRING with the workspace is not inside
it: `/w/Leanx` is a different directory from `/w/Lean`. The trailing separator
in `relBelow` is what makes this false, and without it the hook would derive a
module for a file it has no business building. -/
example : moduleOf "/w/Lean".toList "/w/Leanx/Proofs/X.lean".toList = none := by decide

end RotMoE.Path
