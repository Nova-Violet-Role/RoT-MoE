/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

/-!
# A tag may move until someone can have downloaded it

## Why this file exists

`docs/GIT-WORKFLOW.md` §4.3 said "never force-push, never rewrite published
history — tags are consumed by the marketplace". The first half is right and
unconditional. The second half was measured to be false about this project:
`.claude-plugin/marketplace.json` declares `"source": "./"` and a marketplace
install resolves the **default branch**, while a directory install records a
path. Neither reads a tag.

What *is* pinned to a tag is a **GitHub Release** — its source archive and its
published assets, including `SHA256SUMS.txt`. So the hazard has a boundary
rather than being a blanket, and a blanket rule in the wrong place is not
caution: it forbids the one safe operation (re-tagging onto a commit whose CI is
actually green) while giving no extra protection to the dangerous one.

This file is that boundary, stated so it can be checked instead of remembered.

## The property that matters

`released_tag_never_moves` is the load-bearing one: once a tag is published,
**no sequence of move attempts changes what it resolves to**. Not one move — any
number, in any order, with any commits. That is what makes a checksum somebody
saved yesterday still describe the bytes they can fetch today.

`unreleased_tag_can_move` is its non-vacuity partner. A theorem that forbids
everything is not a safety property, it is a bug; the freedom has to be real
before the restriction means anything.

## What is NOT proved

That git enforces this. Lean constrains the MODEL of the rule; git will happily
move any tag you tell it to. The binding is procedural — `docs/GIT-WORKFLOW.md`
§4.3 and §4.4 — and that is stated plainly rather than implied, because "proved
in Lean" could otherwise be read as a technical control that exists. It does
not. What the theorems buy is that the *rule* is coherent: it cannot be
satisfied while a published tag drifts.
-/

namespace RotMoE.Tag

/-- A tag: the name a consumer types, the commit it currently resolves to, and
whether a Release has been published on it. -/
structure Tag where
  /-- The tag name, e.g. `v0.7.1`. -/
  name : List Char
  /-- The commit this tag currently resolves to. -/
  commit : List Char
  /-- Whether a GitHub Release is attached. Once true, assets exist that someone
  may already have downloaded and checksummed. -/
  released : Bool
  deriving DecidableEq, Repr

/-- What a consumer gets when they resolve the tag. -/
def resolves (t : Tag) : List Char := t.commit

/-- May this tag be re-pointed? Only while nothing is published on it. -/
def mayMove (t : Tag) : Bool := !t.released

/-- Attempt to re-point a tag at another commit. `none` is a refusal, and a
refusal is a success: the caller asked for something that would silently change
what a published download means. -/
def move (t : Tag) (c : List Char) : Tag :=
  if mayMove t then { t with commit := c } else t

/-- Publish a Release on a tag. This is the one-way door. -/
def publish (t : Tag) : Tag := { t with released := true }

/-! ### The door only turns one way -/

/-- **A published tag never moves.** Whatever commit is requested, what the tag
resolves to is unchanged. -/
theorem released_move_is_identity (t : Tag) (c : List Char)
    (h : t.released = true) : move t c = t := by
  simp [move, mayMove, h]

/-- The same statement in the form a consumer cares about: the bytes they
resolve do not change. -/
theorem released_resolves_fixed (t : Tag) (c : List Char)
    (h : t.released = true) : resolves (move t c) = resolves t := by
  simp [resolves, released_move_is_identity t c h]

/-- **No SEQUENCE of move attempts moves a published tag.** This is the durable
form: not "one move is refused" but "the tag is a fixed point of the whole
history", for any list of requested commits in any order. A rule that only
survives a single step is not an invariant. -/
theorem released_tag_never_moves (t : Tag) (cs : List (List Char))
    (h : t.released = true) : cs.foldl move t = t := by
  induction cs generalizing t with
  | nil => rfl
  | cons c cs ih =>
    rw [List.foldl_cons, released_move_is_identity t c h]
    exact ih t h

/-- Publishing is idempotent, and after it the tag is frozen for good. -/
theorem publish_then_frozen (t : Tag) (cs : List (List Char)) :
    cs.foldl move (publish t) = publish t :=
  released_tag_never_moves (publish t) cs (by simp [publish])

/-! ### The freedom is real -- otherwise the restriction says nothing -/

/-- **An unpublished tag does move.** Non-vacuity: without this,
`released_tag_never_moves` could be true of a model where nothing ever moves,
and it would forbid the safe operation as firmly as the dangerous one. -/
theorem unreleased_move_lands (t : Tag) (c : List Char)
    (h : t.released = false) : (move t c).commit = c := by
  simp [move, mayMove, h]

/-- Concretely: re-tagging onto a green commit before publishing is allowed, and
changes what the tag resolves to. -/
theorem unreleased_tag_can_move :
    ∃ (t : Tag) (c : List Char), resolves (move t c) ≠ resolves t := by
  refine ⟨⟨"v0.7.1".toList, "95c4f6d".toList, false⟩, "c4f44f5".toList, ?_⟩
  decide

/-! ### Moving a tag does not rename it -- which is exactly the hazard -/

/-- A move keeps the NAME. This is why a moved published tag is dangerous rather
than merely untidy: the consumer's reference still resolves, it just resolves to
something else, so nothing anywhere reports an error. -/
theorem move_preserves_name (t : Tag) (c : List Char) :
    (move t c).name = t.name := by
  simp [move, mayMove]
  split <;> rfl

/-- A move never publishes, and never un-publishes. The release flag is changed
only by `publish`. -/
theorem move_preserves_released (t : Tag) (c : List Char) :
    (move t c).released = t.released := by
  simp [move, mayMove]
  split <;> rfl

/-- Therefore an unpublished tag stays movable, however many times it is moved:
the freedom is not consumed by using it. -/
theorem moves_do_not_consume_freedom (t : Tag) (cs : List (List Char))
    (h : t.released = false) : (cs.foldl move t).released = false := by
  induction cs generalizing t with
  | nil => exact h
  | cons c cs ih =>
    rw [List.foldl_cons]
    exact ih (move t c) (by rw [move_preserves_released]; exact h)

/-! ### Executed evidence about the present -/

-- The three tags as they stand: pointing at an old commit, nothing published.
-- This is the state that makes the re-tag legal, and it is the last moment it is.
def v070 : Tag := ⟨"v0.7.0".toList, "95c4f6d".toList, false⟩
def v071 : Tag := ⟨"v0.7.1".toList, "95c4f6d".toList, false⟩
def v072 : Tag := ⟨"v0.7.2".toList, "95c4f6d".toList, false⟩

example : mayMove v070 = true := by decide
example : mayMove v071 = true := by decide
example : mayMove v072 = true := by decide

-- Re-pointing them lands, because none carries a Release yet.
example : (move v071 "c4f44f5".toList).commit = "c4f44f5".toList := by decide

-- Publish, and the same request is refused -- silently, by doing nothing, which
-- is why the rule has to be procedural: git will not refuse for you.
example : (move (publish v071) "deadbee".toList).commit = "95c4f6d".toList := by
  decide

-- A published tag is a fixed point of an entire history of attempts.
example :
    (["a".toList, "b".toList, "c".toList].foldl move (publish v071)).commit
      = "95c4f6d".toList := by decide

end RotMoE.Tag
