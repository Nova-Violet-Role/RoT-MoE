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

/-! ## 5. "Already at the latest version" is a claim about a STRING

Measured 2026-08-06, after force-updating the tree without changing the version:
`claude plugin update rot-moe@rot-moe` answered
`✔ rot-moe is already at the latest version (0.8.2)` at **exit 0**, while the
installed cache held a `checker/ctt-session.sh` whose SHA256 differed from the
tree's, a stale `README.md`, a stale `CHANGELOG.md`, and no `RotObserve.lean` at
all.

Nothing was broken. The updater compares the version *string*, and the string had
not moved. This is the fourth section's lesson aimed at distribution: **a
force-updated tag at an unchanged version reaches no existing install, and the
tool actively reassures the user that it did.** -/

/-- A published artifact as the two things a user can compare: the version they
are shown, and the content they actually receive. -/
structure Artifact where
  version : String
  content : String
  deriving DecidableEq, Repr

/-- What `plugin update` compares. -/
def updateSaysCurrent (installed published : Artifact) : Bool :=
  installed.version == published.version

/-- What actually determines whether the user has the fix. -/
def isCurrent (installed published : Artifact) : Bool :=
  installed.content == published.content

/-- **A force-update at an unchanged version reaches nobody.** Quantified over
every version and every pair of differing contents, so it is a statement about
the release *mechanism* and not about the one tag that was measured. -/
theorem force_update_at_same_version_reaches_no_install
    (v c₁ c₂ : String) (h : c₁ ≠ c₂) :
    updateSaysCurrent ⟨v, c₁⟩ ⟨v, c₂⟩ = true ∧ isCurrent ⟨v, c₁⟩ ⟨v, c₂⟩ = false := by
  constructor
  · simp [updateSaysCurrent]
  · simpa [isCurrent] using h

/-- Consequently the updater's verdict cannot decide currency: it is the blind
reading of section 1, wearing a version number. -/
theorem update_verdict_cannot_decide_currency :
    ∃ i₁ i₂ p : Artifact,
      updateSaysCurrent i₁ p = updateSaysCurrent i₂ p ∧ isCurrent i₁ p ≠ isCurrent i₂ p := by
  refine ⟨⟨"0.8.2", "old"⟩, ⟨"0.8.2", "new"⟩, ⟨"0.8.2", "new"⟩, ?_, ?_⟩
  · simp [updateSaysCurrent]
  · simp [isCurrent]

/-- The repair, stated as the property that makes it work: only a version that
actually MOVES is visible to an installed copy. -/
theorem only_a_moved_version_is_visible
    (v₁ v₂ c₁ c₂ : String) (h : v₁ ≠ v₂) :
    updateSaysCurrent ⟨v₁, c₁⟩ ⟨v₂, c₂⟩ = false := by
  simpa [updateSaysCurrent] using h

/-- A fresh install is content-addressed: it takes what is published, so it is
current by construction whatever the version says. Measured: uninstall followed
by install delivered the new `ctt-session.sh`, `README.md` and `RotObserve.lean`
under the very same `0.8.2`. -/
def freshInstall (published : Artifact) : Artifact := published

theorem fresh_install_is_always_current (p : Artifact) :
    isCurrent (freshInstall p) p = true := by
  simp [isCurrent, freshInstall]

/-- So the two paths genuinely differ, and the difference is not cosmetic: for
any real content change there is a state where updating reports success and
changes nothing, while reinstalling delivers it. -/
theorem reinstall_succeeds_where_update_is_blind
    (v c₁ c₂ : String) (h : c₁ ≠ c₂) :
    isCurrent ⟨v, c₁⟩ ⟨v, c₂⟩ = false ∧ isCurrent (freshInstall ⟨v, c₂⟩) ⟨v, c₂⟩ = true := by
  refine ⟨?_, ?_⟩
  · simpa [isCurrent] using h
  · simp [isCurrent, freshInstall]

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

/-! ## §6 — a checksum agreeing with its archive is not provenance

MEASURED 2026-08-06, during the 0.9.x publication, and it very nearly shipped.

`release-package.sh` builds the archives **from the working tree** and computes
`SHA256SUMS.txt` **from those archives**, in one pass. The working tree held two
uncommitted files, so the uploaded `rot-moe-0.9.1-lean.zip` measured 855097 B
against a tag whose tree produces 854497 B.

Nothing was red. The published digest matched the published archive exactly,
because both had been regenerated together — a self-consistent pair describing a
tree that **no tag points at**. Downloading the asset and recomputing its SHA256
(which I did, and it MATCHED) re-verifies that same pair and cannot detect the
substitution. Integrity and provenance are different questions, and only one of
them was being asked.

`digestOf` is modelled as a deterministic function of the archive bytes. Nothing
below assumes it is injective, collision-free, or cryptographic — the gap proved
here is not a hash weakness. It survives a *perfect* hash. -/

/-- What a release publishes: the bytes attached, and the digest published beside
them. -/
structure Release where
  archive : String
  digest  : String
  deriving DecidableEq, Repr

/-- A digest is any deterministic function of the bytes. -/
def digestOf (a : String) : String := a

/-- `release-package.sh`: build from a tree, then digest **that build**. -/
def package (tree : String) : Release := ⟨tree, digestOf tree⟩

/-- The check that was run: recompute the digest of the published archive and
compare it to the published digest. -/
def integrityHolds (r : Release) : Bool := digestOf r.archive == r.digest

/-- The check that was actually needed: the archive is the one the TAG's tree
builds. -/
def provenanceHolds (tag : String) (r : Release) : Bool :=
  r.archive == (package tag).archive

/-- Integrity is satisfied **by construction**, for whatever tree was packaged.
It is therefore incapable of reporting that the wrong tree was packaged: it is a
tautology about the packaging step, not evidence about the release. -/
theorem packaging_always_passes_integrity (tree : String) :
    integrityHolds (package tree) = true := by
  simp [integrityHolds, package, digestOf]

/-- THE MEASURED DEFECT. Package the working tree `w` while the tag names `t`:
the published pair verifies, and the provenance it is trusted to establish is
false. Both halves at once, for every pair of distinct trees. -/
theorem integrity_cannot_detect_the_wrong_tree (t w : String) (h : t ≠ w) :
    integrityHolds (package w) = true ∧ provenanceHolds t (package w) = false := by
  refine ⟨by simp [integrityHolds, package, digestOf], ?_⟩
  simp only [provenanceHolds, package, beq_eq_false_iff_ne]
  exact h.symm

/-- Re-downloading the asset and recomputing does not close the gap: it re-runs
the same self-consistent check on the same pair. Verifying the download is
`integrityHolds`, and `integrityHolds` was just shown blind. -/
theorem redownload_re_runs_the_blind_check (t w : String) (h : t ≠ w) :
    integrityHolds (package w) = integrityHolds (package t) ∧
      provenanceHolds t (package w) = false ∧
      provenanceHolds t (package t) = true := by
  refine ⟨by simp [integrityHolds, package, digestOf], ?_, by simp [provenanceHolds]⟩
  simp only [provenanceHolds, package, beq_eq_false_iff_ne]
  exact h.symm

/-- The repair that was applied: rebuild from the tagged tree. Then provenance
holds — and note this is the ONLY way it holds, by `integrity_cannot_detect_the_wrong_tree`. -/
theorem rebuilding_from_the_tag_restores_provenance (tag : String) :
    provenanceHolds tag (package tag) = true := by
  simp [provenanceHolds]

/-- Provenance is exactly tree equality: it is decidable, and it is the whole
question. Stated over arbitrary trees so it cannot expire when the bytes move. -/
theorem provenance_iff_same_tree (tag tree : String) :
    provenanceHolds tag (package tree) = true ↔ tree = tag := by
  simp [provenanceHolds, package]

/-! ## §7 — an audit that silently narrows its own scope

MEASURED 2026-08-06 in CI run 31118671400's predecessor: `mutant-discipline.sh`
selected harnesses with `sed ... | grep -qE ...` under `set -o pipefail`.
`grep -q` exits at the FIRST match, `sed` dies of SIGPIPE, and pipefail reports
the PIPELINE as failed — so a file that MATCHED was skipped. It is a race, so it
is platform-dependent: green on Git Bash here, and on ubuntu it audited **21**
harnesses while claiming the discipline of all of them. 23 were required.

The general shape, which outlives that one bug: **a gate reports PASS over the
items it SELECTED, and selection can silently lose items.** The verdict is then
true of a subset and read as true of the whole. This is the same defect as §6 in
a different costume — an instrument agreeing with itself rather than with the
world — so it is proved here rather than described in a comment. -/

/-- An audit judges only what its selector kept. -/
def auditPasses (sel judge : Nat → Bool) (xs : List Nat) : Bool :=
  (xs.filter sel).all judge

/-- The control that saved the real run: every REQUIRED item must be selected. -/
def controlHolds (sel : Nat → Bool) (required : List Nat) : Bool := required.all sel

/-- A passing audit does NOT mean every candidate passed: the ones the selector
dropped were never judged. This is exactly what a green run auditing 21 of 23
harnesses was asserting. -/
theorem passing_audit_can_hide_a_failure :
    ∃ (xs : List Nat) (sel judge : Nat → Bool),
      auditPasses sel judge xs = true ∧ xs.all judge = false := by
  exact ⟨[0, 1], (fun n => n == 0), (fun n => n == 0), by decide, by decide⟩

/-- And it hides it *silently*: the audit's verdict is unchanged whether the
dropped item would have passed or failed, so no amount of re-reading the verdict
can reveal the gap. -/
theorem the_verdict_cannot_see_the_drop (judge : Nat → Bool) :
    auditPasses (fun n => n == 0) judge [0] =
      auditPasses (fun n => n == 0) judge [0, 1] := by
  simp [auditPasses]

/-- A control over a KNOWN-REQUIRED set does detect it: if a required item is
dropped, the control is false. This is why the repair shipped with one, and why
the CI failure was a caught defect rather than a hidden one. -/
theorem control_detects_the_drop (sel : Nat → Bool) (required : List Nat) (x : Nat)
    (hx : x ∈ required) (hdrop : sel x = false) : controlHolds sel required = false := by
  simp only [controlHolds, Bool.eq_false_iff, ne_eq, List.all_eq_true]
  intro h
  exact absurd (h x hx) (by simp [hdrop])

/-- The control is not vacuous in the other direction: when nothing is dropped it
holds, so it is a test that can pass as well as fail. -/
theorem control_holds_when_nothing_is_dropped (sel : Nat → Bool) (required : List Nat)
    (h : ∀ x ∈ required, sel x = true) : controlHolds sel required = true := by
  simpa [controlHolds, List.all_eq_true] using h

/-! ## §8 — a step that can only SKIP, and the corpus that repairs it

MEASURED 2026-08-06 in CI run 31092203143 and again in 31116857127: the
`checkers` job ran `gauge-cross.sh`, which needs a built Lean workspace, on
three platforms that have none. It printed `SKIPPED: no built Lean workspace --
NOT a pass` and exited 0 every time, on every runner, for the whole cycle. The
label was honest; the step was still a hole, because it had **no reachable
PASS**.

The repair is not deletion and not a mathlib toolchain on three platforms to
recompute a platform-independent number. It is a split by what each arm depends
on: the Lean arm is verified once where Lean exists, and its values are written
to `checker/gauge-corpus.tsv`, which the hook is then checked against everywhere.

That split is only sound because of one step people are tempted to omit —
re-deriving the corpus from the model. Without it, hook-agrees-with-corpus is
two artifacts agreeing with each other and saying nothing about the model. That
is §6's defect again, so it is proved rather than trusted. -/

/-- What a CI step can report. -/
inductive Outcome where
  | pass | fail | skip
  deriving DecidableEq, Repr

/-- The step as it was: whatever the world does, it skips. -/
def alwaysSkips (_world : Nat) : Outcome := Outcome.skip

/-- A step is evidence only if two different worlds can drive it to different
outcomes. -/
def distinguishes (step : Nat → Outcome) : Prop := ∃ a b, step a ≠ step b

/-- A step that can only skip distinguishes NOTHING — it is not a weak check,
it is not a check. Its log line is the same whether the packet is correct or
broken, which is why three of them sat in a green run unnoticed. -/
theorem a_step_that_only_skips_is_not_evidence : ¬ distinguishes alwaysSkips := by
  rintro ⟨a, b, hab⟩
  exact hab rfl

/-- The platform check: the running hook against the recorded corpus. -/
def hookMatchesCorpus (hook corpus : Nat) : Bool := hook == corpus

/-- The lean job's obligation: the corpus is what the model says. -/
def corpusMatchesModel (corpus model : Nat) : Bool := corpus == model

/-- WITHOUT the re-derivation, agreement is worthless: the hook can match the
corpus exactly while both differ from the model. This is the failure the corpus
file would introduce if `gauge-cross.sh` did not check it. -/
theorem agreement_with_a_corpus_says_nothing_about_the_model :
    ∃ hook corpus model : Nat,
      hookMatchesCorpus hook corpus = true ∧ (hook == model) = false := by
  exact ⟨1, 1, 2, by decide, by decide⟩

/-- WITH it, the platform check transfers to the model: this is precisely what
makes the split honest rather than a way to stop running the real check. -/
theorem verified_corpus_transfers_to_the_model (hook corpus model : Nat)
    (hcorpus : hookMatchesCorpus hook corpus = true)
    (hmodel : corpusMatchesModel corpus model = true) : hook = model := by
  simp only [hookMatchesCorpus, beq_iff_eq] at hcorpus
  simp only [corpusMatchesModel, beq_iff_eq] at hmodel
  exact hcorpus.trans hmodel

/-- And the replacement step is real: unlike `alwaysSkips`, it reaches different
outcomes for different worlds, so it can fail as well as pass. -/
def corpusStep (hook : Nat) : Outcome :=
  if hookMatchesCorpus hook 49 then Outcome.pass else Outcome.fail

theorem the_corpus_step_is_evidence : distinguishes corpusStep := by
  exact ⟨49, 50, by decide⟩

end RotObserve
