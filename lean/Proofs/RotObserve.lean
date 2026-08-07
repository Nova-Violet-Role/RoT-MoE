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

/-! ## §9 — when the evidence counter increments in the failure path

MEASURED 2026-08-06, in this repository's own session suite.

`checker/ctt-session.sh` ran twenty turns against the CTT instance. All twenty
returned `Not logged in - Please run /login`, because the cloned credential had
gone stale. **The checker exited 0.**

Its refusal asked the reasonable-sounding question *"were any route records
written?"* — and twenty had been. The router hook fires when the prompt is
**submitted**, before the turn reaches the API and dies. So the counter the
verdict rested on increments in the *failure* path, and a pass condition built
on it is satisfied by total failure. Twenty failed turns, zero measurement, exit
0.

This is not the same defect as §7. There the verdict was blind to items it never
selected; here every item *was* selected, and the verdict reads a signal that
cannot tell success from failure. Both produce a green run; only one is fixed by
a control over the selection. -/

/-- One session turn: whether it actually succeeded, and whether it left a
record. They are independent, which is the entire problem. -/
structure SessionTurn where
  /-- Did the turn complete successfully? -/
  ok : Bool
  /-- Did the hook write a route record for it? -/
  record : Bool
  deriving DecidableEq, Repr

/-- The hook writes on submission, so a record says nothing about the outcome. -/
def recordsOf (ts : List SessionTurn) : Nat :=
  ((ts.map (fun t => t.record)).filter id).length

/-- The verdict as it was: "some record was written". -/
def sideEffectVerdict (ts : List SessionTurn) : Bool := recordsOf ts != 0

/-- The verdict as it must be: a session suite in which no session succeeded has
measured nothing, however many records the hook wrote on the way down. -/
def successAwareVerdict (ts : List SessionTurn) : Bool :=
  ts.any (fun t => t.ok) && recordsOf ts != 0

/-- **The measured run, exactly.** Twenty turns, every one failed, every one
recorded — and the old verdict passes. -/
theorem total_failure_passes_the_side_effect_verdict :
    sideEffectVerdict (List.replicate 20 { ok := false, record := true }) = true := by
  decide

/-- The durable statement, quantified over runs rather than about twenty:
**a verdict reading only the side effect cannot distinguish any two runs with the
same records**, whatever their outcomes. Re-reading that log line can never
reveal the failure — which is why nobody noticed. -/
theorem side_effect_verdict_is_blind_to_outcomes (ts us : List SessionTurn)
    (h : ts.map (fun t => t.record) = us.map (fun t => t.record)) :
    sideEffectVerdict ts = sideEffectVerdict us := by
  have hrec : recordsOf ts = recordsOf us := by
    simp only [recordsOf, h]
  simp [sideEffectVerdict, hrec]

/-- The repair, stated over an arbitrary run: if no turn succeeded, the
success-aware verdict is false — records or no records. -/
theorem success_aware_verdict_detects_total_failure (ts : List SessionTurn)
    (h : ∀ t ∈ ts, t.ok = false) : successAwareVerdict ts = false := by
  simp only [successAwareVerdict, Bool.and_eq_false_imp]
  intro hany
  simp only [List.any_eq_true] at hany
  obtain ⟨t, ht, hok⟩ := hany
  exact absurd (h t ht) (by simp [hok])

/-- And it is a test, not a refusal: a run with a successful turn and a record
still passes. Without this the "fix" would be a checker that never passes. -/
theorem success_aware_verdict_still_passes_a_real_run :
    successAwareVerdict [{ ok := true, record := true }] = true := by
  decide

/-! ## §10 — a test that manufactures its own precondition

MEASURED 2026-08-06 in CI run 31116857127, on all three platforms at once.

`checker/live-session-smoke.sh` guarded its authenticated phase with

```sh
[ -f "$HOME/.claude/.credentials.json" ] && HAVE_CREDS=1
ls "$HOME/.claude"/*.json >/dev/null 2>&1 && HAVE_CREDS=1     # <- this line
```

The glob matches **`settings.json`** — a file this same script's own
`ARM_ROUTER.sh` call creates a few lines earlier. So on a runner with no
credentials at all, the detector reported *present*, the phase ran, the session
could not authenticate, and CI logged:

```
PARTIAL the router line appeared 1 time(s) but the session exited 1.
```

green, because `PARTIAL` incremented neither counter.

Two distinct defects met in three lines. The verdict half is §9 — the marker is
written by the hook on submission, so it is present in the failure path. The
half stated here is different and worth its own name: **the detector's predicate
was satisfied by an artifact the test itself produces**, so after setup it is
constant, and a constant detector detects nothing. -/

/-- What the runner actually has, versus what the setup leaves lying around. -/
structure Precondition where
  /-- The real requirement: a usable credential. -/
  hasCredential : Bool
  /-- An artifact the test's own setup creates, unrelated to the requirement. -/
  hasOwnArtifact : Bool
  deriving DecidableEq, Repr

/-- The detector as written: satisfied by either. -/
def looseDetector (e : Precondition) : Bool := e.hasCredential || e.hasOwnArtifact

/-- The detector as it must be: only the requirement counts. -/
def strictDetector (e : Precondition) : Bool := e.hasCredential

/-- Running the setup, which creates the artifact. -/
def afterSetup (e : Precondition) : Precondition := { e with hasOwnArtifact := true }

/-- **After its own setup the loose detector is `true` for every world.** It is
not a weak precondition check; past that line it is not a check at all. -/
theorem loose_detector_is_constant_after_setup (e : Precondition) :
    looseDetector (afterSetup e) = true := by
  simp [looseDetector, afterSetup]

/-- The measured consequence: a runner with NO credential is reported ready. -/
theorem loose_detector_cannot_see_a_missing_credential :
    ∃ e : Precondition, e.hasCredential = false ∧ looseDetector (afterSetup e) = true := by
  exact ⟨⟨false, false⟩, by decide, by decide⟩

/-- The repair, and the property that makes something a detector at all: it is
**invariant under the test's own setup**, so what it reports is a fact about the
environment rather than about having run. -/
theorem strict_detector_survives_setup (e : Precondition) :
    strictDetector (afterSetup e) = e.hasCredential := by
  simp [strictDetector, afterSetup]

/-- And it still distinguishes the two worlds, so it is a test and not a
constant in the other direction. -/
theorem strict_detector_is_evidence :
    strictDetector ⟨true, true⟩ ≠ strictDetector ⟨false, true⟩ := by decide

/-! ## §11 — there is no such thing as a one-way link

Asked directly: *"we need just a 1 way symlink that only updates based on the
original, not the other way around."*

The intent is exactly right and the mechanism cannot deliver it. A link is
**shared identity**: reads and writes both resolve to the same object, so a
session that refreshes its OAuth token writes the live credential. That is not a
property of any particular filesystem — it is what a link means.

What *does* deliver the intent is what the maintainer's `CTT` launcher already
does and what `checker/ctt-session.sh` now mirrors: **copy on every launch.**
The copy propagates the original forward and nothing backward.

Below, `live` and `test` are the two credential slots. A LINK makes them one
slot; a COPY makes `test` a snapshot refreshed at launch. The theorems say which
one has the property that was asked for. -/

/-- The two credential slots. -/
structure Creds where
  /-- The maintainer's real credential. -/
  live : Nat
  /-- What the test instance reads. -/
  test : Nat
  deriving DecidableEq, Repr

/-- Linked: `test` IS `live`, so a write to either is a write to both. -/
def writeThroughLink (_c : Creds) (v : Nat) : Creds := { live := v, test := v }

/-- Copied: the test slot is refreshed FROM live at launch. -/
def refreshCopy (c : Creds) : Creds := { c with test := c.live }

/-- A write performed by the test session, under the copy discipline. -/
def writeInTest (c : Creds) (v : Nat) : Creds := { c with test := v }

/-- **A link cannot be one-way.** Whatever the test session writes, the live
credential now holds it. This is the property that was asked for and it is
unobtainable from a link, for every value. -/
theorem a_link_propagates_backwards (c : Creds) (v : Nat) :
    (writeThroughLink c v).live = v := rfl

/-- Concretely: the live credential is changed by a test-side write. -/
theorem a_link_lets_the_test_overwrite_the_live_credential :
    ∃ c : Creds, ∃ v : Nat, (writeThroughLink c v).live ≠ c.live := by
  exact ⟨⟨1, 1⟩, 2, by decide⟩

/-- **The copy is the one-way link.** Nothing the test session writes reaches
`live` — for every prior state and every written value. -/
theorem a_copy_never_propagates_backwards (c : Creds) (v : Nat) :
    (writeInTest c v).live = c.live := rfl

/-- And it is not one-way by being inert: the refresh does carry the live value
forward, which is the half that keeps the credential from going stale. -/
theorem a_copy_carries_the_original_forward (c : Creds) :
    (refreshCopy c).test = c.live := rfl

/-- The two halves together, stated as the isolation property the CTT design
depends on: after a refresh and any amount of test-side writing, `live` is
untouched and the test started from `live`. -/
theorem refresh_then_write_preserves_the_live_credential (c : Creds) (v : Nat) :
    (writeInTest (refreshCopy c) v).live = c.live
    ∧ (refreshCopy c).test = c.live := ⟨rfl, rfl⟩

/-! ## §12 — a check reachable only through the thing it checks

MEASURED 2026-08-06 21:41:17, and it is the **second** occurrence: an unrelated
local tool wrote `.githooks/pre-commit` wholesale, replacing the repository's
commit gate with its own index-maintenance hook whose header states outright
`Never blocks a commit: every failure path exits 0`. `core.hooksPath` is
`.githooks`, so from that moment the commit gate was disarmed.

Dating saved the record: the overwrite is 21:41:17 and the last commit is
21:32:29, so every commit actually recorded had run the real gate.

`checker/workflow-lint.sh` DOES detect the substitution — measured in both
directions, exit 1 with three named failures against the planted hook, exit 0
and 156 passed against the real one. That is not the gap.

The gap is **reachability**. Locally that detector runs because the pre-commit
gate invokes it — so when the gate is the thing that has been replaced, the
detector is precisely what stops running. A guard that audits itself through
itself is silent in exactly the state it exists to report.

The theorems below say it in general: replacing a guard with a permissive twin
makes admission uninformative, an in-band detector cannot see it, and only a
verifier whose execution does not depend on the guard can. -/

/-- The state a commit gate is supposed to judge. -/
structure Tree where
  /-- Whether the checks actually pass. -/
  green : Bool
  deriving DecidableEq, Repr

/-- Which hook is installed. -/
inductive Hook where
  /-- The repository's gate. -/
  | gate
  /-- Any hook that never refuses -- here, the tool that overwrote it. -/
  | permissive
  deriving DecidableEq, Repr

/-- Does the commit get recorded? -/
def admits : Hook → Tree → Bool
  | .gate, t => t.green
  | .permissive, _ => true

/-- An audit invoked BY the hook: it runs only if the real gate is installed. -/
def inBandDetects : Hook → Bool
  | .gate => false          -- correctly reports "nothing wrong"
  | .permissive => false    -- never runs, so it reports nothing at all

/-- An audit whose execution does not depend on the hook -- CI on the committed
tree, or any verifier run out of band. -/
def outOfBandDetects : Hook → Bool
  | .gate => false
  | .permissive => true

/-- The gate is a real gate: it admits exactly the green trees. -/
theorem gate_admits_exactly_green (t : Tree) : admits .gate t = t.green := rfl

/-- The replacement admits everything, for every tree. -/
theorem permissive_admits_everything (t : Tree) : admits .permissive t = true := rfl

/-- **So admission stops carrying information.** A red tree is recorded. -/
theorem swap_makes_admission_uninformative :
    ∃ t : Tree, t.green = false ∧ admits .permissive t = true := by
  exact ⟨⟨false⟩, by decide, by decide⟩

/-- **The catch-22, stated exactly.** The in-band audit reports nothing wrong in
BOTH worlds — it is indistinguishable from a working audit, and it is silent in
the one case that matters. -/
theorem in_band_detector_is_blind_to_its_own_replacement :
    inBandDetects .gate = inBandDetects .permissive := rfl

/-- The out-of-band verifier separates the two worlds, which is what makes it a
detector rather than a constant. -/
theorem out_of_band_detector_sees_the_replacement :
    outOfBandDetects .gate ≠ outOfBandDetects .permissive := by decide

/-- And it fires on exactly the bad world -- no false alarm on the good one. -/
theorem out_of_band_alarm_is_exact (h : Hook) :
    outOfBandDetects h = true ↔ h = .permissive := by
  cases h <;> simp [outOfBandDetects]

/-! ## §13 — a bound below the cost turns a working component into a silent one

MEASURED 2026-08-07 by the maintainer, and found only by accident: opening the
debug view (CTRL+O) showed the router **timing out** on real prompts.

Neither install path declared a `timeout`, so the platform default of 30 s
applied. A hook that reaches its limit is killed, and a killed hook contributes
**nothing** — no marker, no lane, no gauge, no partial output. The turn proceeds
normally and the transcript looks exactly as it would if no hook were installed
at all.

That is the whole trap, and it is the reason every earlier "the router did not
fire here" reading has to be treated as suspect: **silenced and absent produce
the same observable.** No amount of staring at the output distinguishes them.

The work is proportional to the traffic — nine lens activities computed per turn
over the prompt and the reply — so a bound chosen for a trivial script is the
wrong *shape* of bound, not merely a small one.

The theorems below say what the repair has to satisfy, and deliberately never
mention 1200. `checker/hook-timeout.sh` enforces the same two properties on the
shipped files: the bound must EXCEED the default it replaces, and both install
paths must declare the SAME bound. A number can move; these cannot. -/

/-- Work whose cost is whatever the turn demands. -/
structure Work where
  /-- Time the hook needs, in the same units as the bound. -/
  cost : Nat
  deriving DecidableEq, Repr

/-- Does the hook finish inside its bound? -/
def completes (bound : Nat) (w : Work) : Bool := decide (w.cost ≤ bound)

/-- What an observer sees. `none` is the empty observation. -/
def hookOutput (bound : Nat) (w : Work) : Option String :=
  if completes bound w then some "marker" else none

/-- What an observer sees when no hook is installed at all. -/
def absentOutput : Option String := none

/-- **A killed hook emits nothing** — for every bound and every work. -/
theorem killed_hook_emits_nothing (b : Nat) (w : Work) (h : completes b w = false) :
    hookOutput b w = none := by
  simp [hookOutput, h]

/-- **Silenced is indistinguishable from absent.** The observation produced by a
hook that ran and was killed is *equal* to the observation produced by no hook
at all, so no observer of the output can tell the two apart. This is why the
defect survived every session log. -/
theorem silenced_is_indistinguishable_from_absent (b : Nat) (w : Work)
    (h : completes b w = false) : hookOutput b w = absentOutput := by
  simp [hookOutput, absentOutput, h]

/-- Raising the bound never loses an observation: completion is monotone. -/
theorem completion_is_monotone (b b' : Nat) (w : Work) (hb : b ≤ b')
    (h : completes b w = true) : completes b' w = true := by
  simp only [completes, decide_eq_true_eq] at h ⊢
  exact Nat.le_trans h hb

/-- **Adequacy is a relation, not a number.** Whenever the bound covers the cost
the marker is hookOutput — stated for every bound and every work, so no particular
value is frozen into the specification. -/
theorem an_adequate_bound_is_observed (b : Nat) (w : Work) (h : w.cost ≤ b) :
    hookOutput b w = some "marker" := by
  simp [hookOutput, completes, h]

/-- The measured instance: work costing more than the platform default is
silent under it and observable under a larger bound. Concrete on purpose — it
records what happened — while the general statements above carry the spec. -/
theorem the_default_silenced_real_work :
    hookOutput 30 ⟨600⟩ = none ∧ hookOutput 1200 ⟨600⟩ = some "marker" := by
  constructor <;> decide

/-- **Why both install paths must agree.** For ANY two different bounds there is
work they disagree about, so shipping two bounds ships two products. This is the
theorem behind the agreement phase of `checker/hook-timeout.sh`. -/
theorem different_bounds_are_different_products (b₁ b₂ : Nat) (h : b₁ < b₂) :
    ∃ w : Work, hookOutput b₁ w ≠ hookOutput b₂ w := by
  refine ⟨⟨b₁ + 1⟩, ?_⟩
  have h₁ : completes b₁ ⟨b₁ + 1⟩ = false := by
    simp [completes]
  have h₂ : completes b₂ ⟨b₁ + 1⟩ = true := by
    simp only [completes, decide_eq_true_eq]
    exact h
  simp [hookOutput, h₁, h₂]

/-! ## §14 — what an endpoint can and cannot attribute

Measured 2026-08-07, from the A/B run itself: 80 paired turns with the plugin
armed against 80 with it disabled, same prompts, tools off in both arms.

Two of the three pre-registered primary endpoints came back **0.000 in both
arms, 80 ties**. That is not a null result about the router -- it is an endpoint
that had no room to move. The third, a leak counter, fired **9 times in the
routed arm and 12 in the UNROUTED one**, where the mechanism it claims to detect
did not exist at all.

Both are properties of the METRIC, not of the router, and both are decidable
facts about the numbers rather than opinions about the outcome. So they are
stated here as theorems, where they cannot be quietly forgotten the next time a
flat result invites the conclusion "the mechanism does nothing".

**What this section does NOT do.** It does not rescue the router. The primary
endpoints are still null and the pre-registered hypothesis is still
unsupported. What it settles is which of those nulls are *evidence about the
router* and which are *evidence about the instrument* -- a distinction the
experiment needs before round 2 picks new endpoints. -/

/-- An experimental arm: the mechanism under test is present, or it is not. -/
structure Arm where
  mechanism : Bool
  deriving DecidableEq, Repr

/-- The treated arm and the control arm, named so the theorems read as claims
about an experiment rather than about a boolean. -/
def treated : Arm := ⟨true⟩
def control : Arm := ⟨false⟩

/-- An endpoint counts occurrences of something in an arm. -/
abbrev Endpoint := Arm → Nat

/-- An endpoint SEPARATES the arms when it takes different values on them.
Separation is the whole of what a mechanical endpoint can offer; anything more
is interpretation laid on top of it. -/
def separates (m : Endpoint) : Prop := m treated ≠ m control

/-- The endpoint improved: fewer occurrences with the mechanism than without. -/
def improved (m : Endpoint) : Prop := m treated < m control

/-- **A floor endpoint cannot improve.** If the control arm already scores zero,
no mechanism can lower it, and a tie proves nothing about the mechanism.

This is the trailing-question and self-narration result exactly: both were 0.000
in the unrouted arm across all 80 turns. Reporting those as "the router did not
help" reads a fact about the endpoint as a fact about the router. -/
theorem floor_endpoint_cannot_improve (m : Endpoint) (h : m control = 0) :
    ¬ improved m := by
  unfold improved
  omega

/-- The positive form, and the one a protocol should be checked against BEFORE
collecting data: an endpoint can only show an improvement if the control arm
leaves room for one. -/
theorem improvement_requires_room (m : Endpoint) (h : improved m) : 0 < m control := by
  unfold improved at h
  omega

/-- Equal values attribute nothing -- in either direction. A tie is not weak
evidence for the mechanism and not weak evidence against it. -/
theorem equal_arms_attribute_nothing (m : Endpoint) (h : m treated = m control) :
    ¬ separates m := by
  unfold separates
  exact fun hne => hne h

/-- How much of an endpoint's count can be laid at the mechanism's door:
the excess over what appears with the mechanism absent, and never less than 0. -/
def attributable (m : Endpoint) : Nat := m treated - m control

/-- **The metric-9 theorem.** When the control arm scores at least as high as
the treated arm, NOTHING is attributable to the mechanism -- whatever the raw
count. Measured: 9 routed against 12 unrouted, so the attributable share is 0
and the "leak detector" was reading prompt echo. -/
theorem control_at_least_treated_attributes_nothing (m : Endpoint)
    (h : m control ≥ m treated) : attributable m = 0 := by
  unfold attributable
  omega

/-- And the general shape: whatever the control arm scores is a ceiling on how
much of the treated arm's count the mechanism can be blamed for. -/
theorem attributable_le_difference (m : Endpoint) :
    attributable m + m control ≥ m treated := by
  unfold attributable
  omega

/-- An endpoint may come out WORSE in the treated arm. The hedging count did:
three turns with the router, none without. The design must be able to express
that, or it is not a test. -/
theorem an_endpoint_can_be_worse_when_treated :
    ∃ m : Endpoint, m control < m treated := by
  refine ⟨fun a => if a.mechanism then 3 else 0, ?_⟩
  decide

/-- A paired comparison: per prompt, the treated count and the control count. -/
abbrev Pairs := List (Nat × Nat)

/-- Pairs where the treated arm scored strictly lower. -/
def wins (ps : Pairs) : Nat := (ps.filter (fun p => decide (p.1 < p.2))).length

/-- Pairs where the treated arm scored strictly higher. -/
def losses (ps : Pairs) : Nat := (ps.filter (fun p => decide (p.2 < p.1))).length

/-- **Every pair a tie means an empty sign count, whatever the sample size.**
Eighty ties is the same evidence as one tie: none. Sample size does not convert
a floor endpoint into a measurement. -/
theorem all_ties_leave_no_sign_count (ps : Pairs) (h : ∀ p ∈ ps, p.1 = p.2) :
    wins ps = 0 ∧ losses ps = 0 := by
  refine ⟨?_, ?_⟩
  · unfold wins
    simp only [List.length_eq_zero_iff, List.filter_eq_nil_iff]
    intro p hp
    have hp' := h p hp
    simp [hp']
  · unfold losses
    simp only [List.length_eq_zero_iff, List.filter_eq_nil_iff]
    intro p hp
    have hp' := h p hp
    simp [hp']

/-- The measured trailing-question endpoint, as a concrete witness: zero in both
arms, so by `floor_endpoint_cannot_improve` no improvement was reachable. -/
example : ¬ improved (fun _ => 0) := floor_endpoint_cannot_improve _ rfl

/-- The measured leak endpoint: 9 treated, 12 control, nothing attributable. -/
example : attributable (fun a => if a.mechanism then 9 else 12) = 0 :=
  control_at_least_treated_attributes_nothing _ (by decide)

/-- And the control that keeps the previous example honest -- an endpoint that
DOES separate the arms, so the machinery above is not trivially true of
everything. Cost per turn, in tenths of a cent: 101 routed, 148 unrouted. -/
example : separates (fun a => if a.mechanism then 101 else 148) := by
  unfold separates treated control
  decide

example : improved (fun a => if a.mechanism then 101 else 148) := by
  unfold improved treated control
  decide

/-! ## §15 — a mismatch that renders identically

Measured 2026-08-07, CI run 31148233876, `checkers (windows-latest)`, step
"gauge hook corpus". Six rows failed like this:

```
FAIL  row 1: hook 0.09 != corpus 0.09
```

The gate was **right**. GitHub's Windows runner checks out with
`core.autocrlf=true`, so every corpus line arrived with a trailing CR, the last
tab-separated field was `0.09\r`, and it genuinely differed from the hook's
`0.09`. Ubuntu and macOS passed the same commit.

What the gate could not do was **show** the difference. A terminal renders CR as
no glyph at all, so the failure message printed two identical-looking numbers
and the diagnosis cost an hour that the bytes would have given away instantly.

Two separate obligations fall out, and they pull in opposite directions:

1. **Normalisation must recover the comparison** -- stripping CR has to make
   `0.09\r` and `0.09` compare equal, or the checker stays broken.
2. **Normalisation must not invent agreement** -- it must never merge two values
   that really do differ, or the fix has disarmed the gate. That is the more
   dangerous half, and it is why `stripCell_faithful` is here.

And one about the message itself: a diagnostic that maps two different inputs to
the same output cannot be trusted to report a difference, however loudly it
fails. `escape_injective` is the property the repaired message needs. -/

/-- One character of a corpus field, cut down to the alphabet the gauge corpus
actually uses: digits, a decimal point, and the carriage return that broke it. -/
inductive Cell where
  /-- A decimal digit. -/
  | digit : Fin 10 → Cell
  /-- The decimal point. -/
  | dot : Cell
  /-- Carriage return: the byte with no glyph. -/
  | cr : Cell
  deriving DecidableEq, Repr

/-- A corpus field, as bytes. -/
abbrev Field := List Cell

/-- What a terminal SHOWS. CR produces no glyph, so it simply is not there. -/
def shown (f : Field) : Field := f.filter (fun c => c != Cell.cr)

/-- The checker's normalisation, which is the same operation -- deliberately
named apart, because they are different claims about the same function: one is
what the screen does to you, the other is what you do about it. -/
def stripCell (f : Field) : Field := f.filter (fun c => c != Cell.cr)

/-- A field with no carriage return in it. -/
def crFree (f : Field) : Prop := ∀ c ∈ f, c ≠ Cell.cr

instance (f : Field) : Decidable (crFree f) := by
  unfold crFree; infer_instance

/-- **The screen can hide a real difference.** Two fields that are not equal can
render identically -- which is exactly what `0.09 != 0.09` was. -/
theorem shown_can_hide_a_real_difference :
    ∃ a b : Field, a ≠ b ∧ shown a = shown b := by
  refine ⟨[Cell.dot], [Cell.dot, Cell.cr], ?_, ?_⟩ <;> decide

/-- **Normalisation recovers the comparison.** A trailing CR makes no difference
once it is stripped -- the first obligation, for every field. -/
theorem stripCell_ignores_trailing_cr (f : Field) :
    stripCell (f ++ [Cell.cr]) = stripCell f := by
  simp [stripCell, List.filter_append]

/-- More strongly: CR anywhere is irrelevant, not only at the end. The Windows
checkout put one at the end of every line, but a mid-record CR must not corrupt
an argument either -- which is why the checker strips every field, not the last. -/
theorem stripCell_ignores_cr_anywhere (f g : Field) :
    stripCell (f ++ Cell.cr :: g) = stripCell (f ++ g) := by
  simp [stripCell, List.filter_append]

/-- Stripping a field that has no CR changes nothing. -/
theorem stripCell_id_of_crFree {f : Field} (h : crFree f) : stripCell f = f := by
  unfold stripCell
  apply List.filter_eq_self.mpr
  intro c hc
  simp [h c hc]

/-- **Normalisation does not invent agreement.** If two CR-free fields normalise
to the same thing, they WERE the same thing. This is the theorem that keeps the
repair from being a disarmament: stripping CR cannot make a genuine mismatch
pass. -/
theorem stripCell_faithful {a b : Field} (ha : crFree a) (hb : crFree b)
    (h : stripCell a = stripCell b) : a = b := by
  rw [stripCell_id_of_crFree ha, stripCell_id_of_crFree hb] at h
  exact h

/-- Stripping is idempotent, so a doubly-normalised comparison is the same
comparison -- a checker may strip defensively without changing its verdict. -/
theorem stripCell_idem (f : Field) : stripCell (stripCell f) = stripCell f := by
  simp [stripCell, List.filter_filter]

/-- The output alphabet of a failure message: glyphs that are all visible. -/
inductive Glyph where
  /-- A digit, printed as itself. -/
  | digit : Fin 10 → Glyph
  /-- The decimal point. -/
  | dot : Glyph
  /-- A literal backslash, which starts an escape. -/
  | backslash : Glyph
  /-- The letter `r`, as in `\r`. -/
  | rLetter : Glyph
  deriving DecidableEq, Repr

/-- How one byte is printed in a failure message. CR becomes the two visible
glyphs `\r`; nothing else emits a backslash, which is what makes the code
prefix-free and therefore readable back. -/
def esc : Cell → List Glyph
  | Cell.digit n => [Glyph.digit n]
  | Cell.dot     => [Glyph.dot]
  | Cell.cr      => [Glyph.backslash, Glyph.rLetter]

/-- A whole field, escaped for display. -/
def escape (f : Field) : List Glyph := f.flatMap esc

/-- **The escaped message cannot hide a difference.** Different fields print
differently -- so a failure message built this way can always be trusted to
show what actually differed. This is the property `0.09 != 0.09` lacked. -/
-- The `simp only` sets below are SQUEEZED, not hand-guessed: mathlib's
-- flexible-simp linter refuses a bare `simp ... at hb ⊢` whose result a later
-- `exact` depends on, and it is right to -- the proof would then rest on
-- whatever simp happens to do next release. These lists came from `simp?`.
theorem escape_injective : ∀ a b : Field, escape a = escape b → a = b := by
  intro a
  induction a with
  | nil =>
    intro b hb
    cases b with
    | nil => rfl
    | cons y ys =>
      cases y <;>
        simp only [escape, List.flatMap_nil, List.flatMap_cons, esc,
          List.cons_append, List.nil_append, List.nil_eq, reduceCtorEq] at hb
  | cons x xs ih =>
    intro b hb
    cases b with
    | nil =>
      cases x <;>
        simp only [escape, List.flatMap_cons, esc, List.cons_append,
          List.nil_append, List.flatMap_nil, reduceCtorEq] at hb
    | cons y ys =>
      cases x <;> cases y <;>
        simp only [escape, List.flatMap_cons, esc, List.cons_append,
          List.nil_append, List.cons.injEq, Glyph.digit.injEq, Cell.digit.injEq,
          reduceCtorEq, false_and] at hb ⊢ <;>
        exact ⟨hb.1, ih ys (by simpa [escape] using hb.2)⟩

/-- The measured pair, as the corpus and the runner actually had them:
`0.09` against `0.09\r`. -/
def field009 : Field :=
  [Cell.digit 0, Cell.dot, Cell.digit 0, Cell.digit 9]

/-- The same field as the Windows checkout delivered it. -/
def field009cr : Field := field009 ++ [Cell.cr]

/-- The two are genuinely different -- the gate was correct to fail. -/
example : field009 ≠ field009cr := by decide

/-- They render identically -- which is why the message was useless. -/
example : shown field009 = shown field009cr := by decide

/-- Normalised, they agree, so the repaired checker passes on this input. -/
example : stripCell field009 = stripCell field009cr := by decide

/-- Escaped, they differ, so the repaired MESSAGE would have named the byte. -/
example : escape field009 ≠ escape field009cr := by decide

/-- And the control that keeps `stripCell` honest: a real mismatch survives
normalisation. `0.09` against `0.19` does not become equal just because the
checker strips carriage returns. -/
example :
    stripCell field009 ≠
      stripCell [Cell.digit 0, Cell.dot, Cell.digit 1, Cell.digit 9] := by decide

/-! ## §16 — an interrupted mutation run, and why the backup comes first

Measured 2026-08-07, three times in one session. A commit whose gate run exceeded
a wall-clock ceiling had its entire process tree **SIGKILLed**. The mutation
checker has a `trap ... EXIT INT TERM` that restores every file it touched, and
that trap is correct — but SIGKILL cannot be trapped. What was left on disk:

```
hooks/rot-router.sh        MUTATED: STEMS_STEALTH missing 'token compress'
hooks/rot-router.sh.mutbak the only surviving copy of the original
```

A live mutant in a **shipped** hook, one `git add -A` away from being published
as the real router.

Three facts fall out, and each is a property rather than an anecdote:

* recovery must not depend on a signal handler, because one signal ignores them;
* the backup must be written **before** the mutation, or an interruption in
  between destroys the original;
* a stray backup must be **restored, never deleted** — deleting it promotes the
  mutant to the truth, and that is the one irreversible move available.

`checker/mutate-checker.sh` now recovers at start-up and `checker/repo-complete.sh`
refuses a commit while any `.mutbak` exists. -/

/-- The contents of one file, abstractly. -/
abbrev Blob := Nat

/-- What is on disk: the working file, and the backup if one has been written. -/
structure Disk where
  /-- The file a build or a commit would read. -/
  live : Blob
  /-- The saved original, if any. -/
  backup : Option Blob
  deriving DecidableEq, Repr

/-- Write the backup. -/
def saveBackup (d : Disk) : Disk := { d with backup := some d.live }

/-- Overwrite the live file with the mutant. -/
def applyMutant (d : Disk) (m : Blob) : Disk := { d with live := m }

/-- Put the original back and drop the backup. -/
def restore (d : Disk) : Disk :=
  match d.backup with
  | some b => { live := b, backup := none }
  | none   => d

/-- The original is recoverable from this state: either the live file is already
it, or the backup holds it. -/
def recoverable (d : Disk) (orig : Blob) : Prop :=
  d.live = orig ∨ d.backup = some orig

/-- **Backup first, and every interruption point is survivable.** After
`saveBackup` then `applyMutant`, the original is still recoverable — which is
what let the tree be repaired after the SIGKILL. -/
theorem backup_then_mutate_is_recoverable (d : Disk) (m : Blob) :
    recoverable (applyMutant (saveBackup d) m) d.live := by
  right; rfl

/-- Recoverable before the backup is even written -- the live file is still the
original, so an interruption there is harmless too. -/
theorem recoverable_before_backup (d : Disk) : recoverable d d.live := by
  left; rfl

/-- Recoverable immediately after the backup, before any mutation. -/
theorem recoverable_after_backup (d : Disk) : recoverable (saveBackup d) d.live := by
  left; rfl

/-- **Mutate first and an interruption loses the original.** With no prior
backup, the state after a mutation does not contain the original anywhere --
this is the order the checker must never use. -/
theorem mutate_then_backup_can_lose_the_original :
    ∃ (d : Disk) (m : Blob),
      d.backup = none ∧ m ≠ d.live ∧ ¬ recoverable (applyMutant d m) d.live := by
  refine ⟨{ live := 1, backup := none }, 2, rfl, by decide, ?_⟩
  intro h
  rcases h with h | h <;> simp [applyMutant] at h

/-- Restoring from a backup returns exactly the original. -/
theorem restore_recovers (d : Disk) (orig : Blob) (h : d.backup = some orig) :
    (restore d).live = orig := by
  simp [restore, h]

/-- **Restore is idempotent**, so recovering twice is safe -- the start-up
recovery may run on a tree a trap already repaired. -/
theorem restore_idem (d : Disk) : restore (restore d) = restore d := by
  cases h : d.backup <;> simp [restore, h]

/-- Restoring leaves no backup behind, so the next run cannot mistake a repaired
tree for an interrupted one. -/
theorem restore_clears_the_backup (d : Disk) : (restore d).backup = none := by
  cases h : d.backup <;> simp [restore, h]

/-- Deleting the backup instead of restoring it. -/
def dropBackup (d : Disk) : Disk := { d with backup := none }

/-- **Deleting a stray backup makes the mutant permanent.** From a mutated state
whose original lives only in the backup, dropping the backup destroys the last
copy — the irreversible mistake, stated so no cleanup script can be written that
way by accident. -/
theorem dropping_the_backup_loses_the_original (d : Disk) (m : Blob)
    (hne : m ≠ d.live) :
    ¬ recoverable (dropBackup (applyMutant (saveBackup d) m)) d.live := by
  intro h
  rcases h with h | h
  · exact hne h
  · simp [dropBackup] at h

/-- And the whole cycle, executed: save, mutate, restore returns the original
and leaves nothing behind. -/
theorem save_mutate_restore_round_trips (d : Disk) (m : Blob) :
    restore (applyMutant (saveBackup d) m) = { live := d.live, backup := none } := by
  simp [restore, applyMutant, saveBackup]

/-- The measured case, as bytes: the router at 22614, the mutant at 22620. -/
example :
    restore (applyMutant (saveBackup { live := 22614, backup := none }) 22620)
      = { live := 22614, backup := none } := by decide

/-- And the failure that actually happened: interrupted after the mutation, the
live file is the MUTANT -- but the original is still there to be recovered. -/
example :
    (applyMutant (saveBackup { live := 22614, backup := none }) 22620).live = 22620
    ∧ recoverable (applyMutant (saveBackup { live := 22614, backup := none }) 22620) 22614 := by
  constructor
  · rfl
  · right; rfl

/-! ## §17 — atomicity is not enough: the replacement must carry the mode

§16 says a write should be a temp file plus a rename, so an interruption leaves
the old content or the new content and never a truncated file. That is true, and
implementing it naively broke CI.

Measured 2026-08-07, run on `6791683`. The mutation harness wrote
`… > "$f.mtmp" && mv -f "$f.mtmp" "$f"`. A shell redirect **creates** the temp
at `0666 & ~umask` = `0644`, and `mv` carries the **temp's** mode onto the
target — so `hooks/rot-router.sh` arrived non-executable. `checker/cross-diff.sh:52`
runs it directly, the call produced nothing, and H00 — the meta-control asserting
that a NO-OP edit leaves the checker green — went red on ubuntu and macos.

`checkers (windows-latest)` passed the same commit, because Windows has no
executable bit. An atomicity fix that traded one corruption for another, on a
platform I cannot observe locally.

The lesson generalises past file modes: **a replacement carries every attribute
of the replacement, not of the thing replaced.** Anything the old object had and
the new one was not given is silently lost at the moment of the swap. So the
temp must be built *from* the original, never from nothing. -/

/-- A file as the filesystem sees it: contents, and whether it may be executed. -/
structure Entry where
  /-- The bytes. -/
  content : Blob
  /-- The executable bit. -/
  exec : Bool
  deriving DecidableEq, Repr

/-- A fresh temp created by a shell redirect: the caller's default mode, which
does **not** include the executable bit. -/
def freshTemp (c : Blob) : Entry := { content := c, exec := false }

/-- A temp created by `cp -p` from the original and then truncated in place: a
redirect onto an EXISTING file does not change its mode, so the clone keeps it. -/
def clonedTemp (orig : Entry) (c : Blob) : Entry := { orig with content := c }

/-- `mv -f temp target` — the target becomes the temp, wholesale. This is the
step that loses whatever the temp was not given. -/
def renameOver (_target : Entry) (temp : Entry) : Entry := temp

/-- **The bug, as a property.** Replacing an executable file via a fresh temp
produces a non-executable file, whatever the contents. -/
theorem fresh_temp_drops_the_exec_bit (orig : Entry) (c : Blob) (_h : orig.exec = true) :
    (renameOver orig (freshTemp c)).exec = false := by
  simp [renameOver, freshTemp]

/-- Stated the way it bit: there EXISTS an executable file whose atomic
replacement is no longer executable. `0.09`-style silent breakage, but for a
shipped hook. -/
theorem naive_atomic_replace_can_break_an_executable :
    ∃ e : Entry, e.exec = true ∧ (renameOver e (freshTemp 22620)).exec = false := by
  exact ⟨{ content := 22614, exec := true }, rfl, rfl⟩

/-- **The repair.** Cloning the original's mode into the temp preserves the bit
through the rename, for every file and every new content. -/
theorem cloned_temp_preserves_the_exec_bit (orig : Entry) (c : Blob) :
    (renameOver orig (clonedTemp orig c)).exec = orig.exec := by
  simp [renameOver, clonedTemp]

/-- And it still does the job: the contents really are replaced. A mode-
preserving write that failed to write would be the opposite failure. -/
theorem cloned_temp_still_writes (orig : Entry) (c : Blob) :
    (renameOver orig (clonedTemp orig c)).content = c := by
  simp [renameOver, clonedTemp]

/-- The general statement, and the one worth keeping: cloning preserves EVERY
attribute the original had except the content. Stated as equality of the whole
entry with only `content` updated, so a future field cannot quietly escape it —
the theorem fails to compile rather than silently narrowing. -/
theorem cloned_temp_changes_only_the_content (orig : Entry) (c : Blob) :
    renameOver orig (clonedTemp orig c) = { orig with content := c } := by
  simp [renameOver, clonedTemp]

/-- Restoring a backup must preserve the mode too, not just the mutation. The
harness restores four shipped hooks on every exit path; a restore that dropped
the bit would leave the tree broken after a perfectly successful run. -/
theorem restore_via_clone_preserves_exec (live backup : Entry) :
    (renameOver live (clonedTemp live backup.content)).exec = live.exec := by
  simp [renameOver, clonedTemp]

/-- A non-executable file is unharmed by the naive path — which is exactly why
this went unnoticed on Windows, where nothing is executable in this sense. The
theorem is here to record that "it worked on my machine" was TRUE and useless. -/
theorem naive_replace_is_harmless_when_nothing_is_executable
    (orig : Entry) (c : Blob) (h : orig.exec = false) :
    (renameOver orig (freshTemp c)).exec = orig.exec := by
  simp [renameOver, freshTemp, h]

/-- The measured case: the router, executable, at 22614 bytes, mutated to 22620.
The naive path yields a mutant that cannot be run; the cloned path yields one
that can. -/
example :
    (renameOver { content := 22614, exec := true } (freshTemp 22620)).exec = false
    ∧ (renameOver { content := 22614, exec := true }
        (clonedTemp { content := 22614, exec := true } 22620)).exec = true := by
  decide

/-- Both paths agree on the CONTENT, which is why only the mode betrayed it and
why every mutant still "killed" while the baseline was broken. -/
example :
    (renameOver { content := 22614, exec := true } (freshTemp 22620)).content
      = (renameOver { content := 22614, exec := true }
          (clonedTemp { content := 22614, exec := true } 22620)).content := by
  decide

end RotObserve
