/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — what a passing control does and does not establish

Subject: the measuring instruments themselves — `tools/deadcode-census.py`,
`tools/capability-triage.py`, and every checker phase in `tools/spec-check.sh`.

This module exists because an instrument in this project **lied while passing all of its
controls**, and the shape of that failure is general enough to be worth a theorem rather than a
paragraph in a resumee.

`tools/deadcode-census.py` reported **608** public methods with zero call sites. It carried three
controls, all of which passed:

```
startStream      (known dead)      -> listed        correct
detectStartTime  (called twice)    -> not listed    correct
parseLibavcodec  (called in probe) -> not listed    correct
```

The instrument was nevertheless wrong. It stripped block comments from the **joined** text of all
614 files, so a single unbalanced `/*` let the non-greedy match run to the next `*/` in a
*different file* and delete every line between. `FfmpegOutputArgs.buildPlaylistOutputArguments`
was reported dead while being called at `ChaturbateLlhlsDownload.java:761`.

Stripping per file and re-running: **563**. The defect had inflated the figure by 45 methods.

The three controls did not catch it because all three happened to sit outside a deleted region.
That is the property below: **a control validates the instrument on the inputs it covers, and on
nothing else.** It is the same shape as `a_clean_record_is_not_evidence` in `PreviewPipeline` —
absence of a failure signal is not a signal of correctness — but one level up, applied to the
measuring apparatus rather than to the code being measured.
-/

namespace CtbrecSpec

/-- An instrument, modelled by the inputs on which it gives the WRONG answer. An input is any
identifier the probe can be run against; here they stand for source-file positions. -/
structure Probe where
  wrongOn : List Nat
  deriving DecidableEq, Repr

/-- A control set passes when the instrument is right on every control. -/
def passesControls (p : Probe) (controls : List Nat) : Bool :=
  controls.all (fun c => !p.wrongOn.contains c)

/-- Sound means wrong on nothing at all — not merely right on the controls. -/
def isSound (p : Probe) : Bool := p.wrongOn.isEmpty

/-- The three original controls: `startStream`, `detectStartTime`, `parseLibavcodec`. -/
def originalControls : List Nat := [1, 2, 3]

/-- The census as first written: wrong at input 761, standing for
`ChaturbateLlhlsDownload.java:761`, where a real call was deleted along with its enclosing
region. None of the controls live there. -/
def censusV1 : Probe := ⟨[761]⟩

/-- The census after stripping comments per file. -/
def censusV2 : Probe := ⟨[]⟩

/-- The controls after the failure was added as a fourth case. -/
def repairedControls : List Nat := [1, 2, 3, 761]

/-- **It passed every control it had.** -/
theorem the_first_census_passed_its_controls :
    passesControls censusV1 originalControls = true := by decide

/-- **And it was wrong anyway.** -/
theorem the_first_census_was_not_sound : isSound censusV1 = false := by decide

/-- The two together: **passing controls does not imply soundness.** A concrete witness is
stronger here than an existential — it names the input that was missed. -/
theorem passing_controls_does_not_imply_soundness :
    passesControls censusV1 originalControls = true ∧ isSound censusV1 = false := by decide

/-- **The repair that actually detects it**: promote the discovered failure to a control. This is
why a bug found in an instrument must become a control and not merely a fixed line — otherwise
the next regression is invisible again. -/
theorem adding_the_failure_as_a_control_detects_it :
    passesControls censusV1 repairedControls = false := by decide

/-- **Anti-amputation.** `passesControls` is not a function that eventually fails everything: the
repaired instrument passes the strengthened control set. Without this, `fun _ _ => false` would
satisfy the theorem above and the model would condemn every instrument. -/
theorem the_repaired_census_passes_the_stronger_controls :
    passesControls censusV2 repairedControls = true := by decide

/-- …and it is sound, which is a strictly stronger claim than passing. -/
theorem the_repaired_census_is_sound : isSound censusV2 = true := by decide

/-- **The durable direction**: a sound instrument passes *every* control set, whatever it
contains. Quantified over the controls, so extending them can never falsify it — the mistake
this project calls a contingent theorem. -/
theorem a_sound_probe_passes_every_control_set (controls : List Nat) :
    passesControls ⟨[]⟩ controls = true := by
  unfold passesControls
  simp

/-- **The other durable direction**: if a control set contains an input the instrument is wrong
on, it fails. Together with the previous theorem this pins `passesControls` from both sides —
neither trivially true nor trivially false. -/
theorem a_control_covering_a_wrong_input_fails (p : Probe) (c : Nat)
    (hmem : c ∈ p.wrongOn) : passesControls p [c] = false := by
  simp [passesControls]
  exact hmem

/-- The measured counts, kept as data: 608 reported, 563 after the repair, 45 inflated. -/
def reportedBefore : Nat := 608
def reportedAfter : Nat := 563

/-- **The defect inflated the count by 45.** Stated as arithmetic so a future edit to either
number has to justify itself. -/
theorem the_defect_inflated_the_count_by_45 : reportedBefore - reportedAfter = 45 := by decide

/-- The corrected figure is genuinely lower — the bug over-reported, it did not under-report.
Which direction an instrument errs in decides whether it alarms or reassures, and this one
alarmed: it invented dead code rather than hiding it. -/
theorem the_defect_over_reported : reportedAfter < reportedBefore := by decide

#guard passesControls censusV1 originalControls == true
#guard isSound censusV1 == false
#guard passesControls censusV1 repairedControls == false
#guard passesControls censusV2 repairedControls == true
#guard reportedBefore - reportedAfter == 45

/-! ## The census under-classified, which is a different fault from over-counting

Third defect found in this instrument. The first two made it report the **wrong number**; this
one made it report the right number with the **wrong meaning**.

`@JsonSerialize(converter = InstantToMillisConverter.class)` hands a class to Jackson, which then
dispatches into it reflectively. Its methods have no textual caller **by design**. The census
counted `Cls.method(` and `new Cls(` and never `Cls.class`, so those methods sat in a list headed
"public methods with ZERO detected call sites" — beside genuinely unreferenced code, inviting
exactly the deletion that would break serialisation.

Measured after both repairs: of **547** methods with no textual call site, **226 are
framework-referenced** and **321 have no evidence of any reference**. 41.3 % of that list was never
a deletion candidate. -/

inductive Reachability where
  /-- A real call site exists in the source. -/
  | textual
  /-- The owning class is handed to a framework as `X.class`; dispatch is reflective. -/
  | framework
  /-- No reference of any kind found. A CANDIDATE for review, never a verdict. -/
  | noEvidence
  deriving DecidableEq, Repr

/-- `callSites` counts textual calls, `classRefs` counts `X.class` occurrences. Order matters:
a textual call is the strongest evidence, a framework reference still forbids the conclusion
"dead", and only the absence of both leaves a candidate. -/
def classify (callSites classRefs : Nat) : Reachability :=
  if 0 < callSites then .textual
  else if 0 < classRefs then .framework
  else .noEvidence

/-- **The theorem the repair encodes**: a class handed to a framework is never reported as
unreferenced, however many call sites it lacks. Quantified over the reference count, so it holds
for every such class rather than for the two that were found. -/
theorem a_framework_reference_is_never_no_evidence (classRefs : Nat) (h : 0 < classRefs) :
    classify 0 classRefs ≠ .noEvidence := by
  unfold classify
  simp [h]

/-- The converters, as measured: 0 call sites, 6 `.class` references each. -/
theorem the_converters_are_framework_reachable : classify 0 6 = .framework := by decide

/-- **Anti-amputation**: the rule does not rescue everything. A method with neither kind of
reference is still a candidate, which is what keeps the census useful. -/
theorem no_reference_of_any_kind_is_still_a_candidate : classify 0 0 = .noEvidence := by decide

/-- And a real call site still wins outright. -/
theorem a_called_method_is_textually_reachable : classify 3 0 = .textual := by decide

/-- **`noEvidence` is not a proof of deadness** — the census cannot see FXML or override
dispatch either. The three values are pairwise distinct so that a reader cannot quietly treat
"I found nothing" as "there is nothing". -/
theorem no_evidence_is_not_framework : Reachability.noEvidence ≠ .framework := by decide

theorem no_evidence_is_not_textual : Reachability.noEvidence ≠ .textual := by decide

/-! ### Fourth defect: a method reference is a call site without a parenthesis

Both census regexes end in `\s*\(`. `Foo::bar` and `this::bar` have no parenthesis, so a method
invoked through a functional interface was invisible to the instrument. Measured: **7 of 265**
distinct candidate names were reachable only this way — `capitalize`, `failed`, `getBlurb`,
`getCountry`, `getEthnic`, `getOccupation`, `at60`.

Counting `::name` as the fourth reference form: **563 → 547**.

Also measured, and it retires an item I had written down as the next step: this app has **0 FXML
files and 0 `@FXML` annotations**. Its UI is built programmatically. RESUMEE-30 named FXML
dispatch as the next classifier rung; that mechanism does not exist here, so the item was
chasing nothing. Recorded rather than quietly dropped. -/

/-- Evidence of reachability, one field per reference form the census can see. -/
structure Evidence where
  /-- `name(` and `.name(` — an ordinary call. -/
  calls : Nat
  /-- `::name` — dispatch through a functional interface. No parenthesis. -/
  methodRefs : Nat
  /-- `X.class` — the owning class handed to a framework. -/
  classRefs : Nat
  deriving DecidableEq, Repr

/-- The repaired classifier. A method reference counts as a real call site, because it is one. -/
def classifyV4 (e : Evidence) : Reachability :=
  if 0 < e.calls + e.methodRefs then .textual
  else if 0 < e.classRefs then .framework
  else .noEvidence

/-- **The durable statement of the fourth repair**: a method reachable only through a method
reference is reachable, for any positive number of references. -/
theorem a_method_reference_is_a_call_site (m : Nat) (h : 0 < m) :
    classifyV4 ⟨0, m, 0⟩ = .textual := by
  unfold classifyV4
  simp [h]

/-- **And the old classifier called exactly those methods unreferenced.** This is the defect
stated as a disagreement between the two instruments, not as prose. -/
theorem the_old_classifier_disagreed (m : Nat) (h : 0 < m) :
    classifyV4 ⟨0, m, 0⟩ ≠ classify 0 0 := by
  rw [a_method_reference_is_a_call_site m h]
  decide

/-- **Anti-amputation**: the fourth form does not rescue everything either. With no evidence of
any kind the verdict is still `noEvidence`. -/
theorem v4_still_reports_the_genuinely_unreferenced :
    classifyV4 ⟨0, 0, 0⟩ = .noEvidence := by decide

/-- The framework case survives the upgrade unchanged. -/
theorem v4_agrees_with_v3_on_framework_dispatch :
    classifyV4 ⟨0, 0, 6⟩ = classify 0 6 := by decide

#guard classifyV4 ⟨0, 3, 0⟩ == Reachability.textual
#guard classifyV4 ⟨0, 0, 0⟩ == Reachability.noEvidence
#guard classifyV4 ⟨0, 0, 6⟩ == Reachability.framework

/-- FXML dispatch, measured: this app does not use it. Kept as data so the claim is checkable
rather than remembered. -/
def fxmlFiles : Nat := 0
def fxmlAnnotations : Nat := 0

theorem fxml_dispatch_is_not_a_blind_spot_here :
    fxmlFiles = 0 ∧ fxmlAnnotations = 0 := by decide

/-- The measured split, as a fact that must be restated if the tree changes.
Was 563 / 235 / 328 before method references were counted; the numbers moved with the code in
the same edit, which is the rule this project holds itself to. -/
def censusTotal : Nat := 547
def censusFramework : Nat := 226
def censusNoEvidence : Nat := 321

theorem the_split_accounts_for_every_candidate :
    censusFramework + censusNoEvidence = censusTotal := by decide

/-- **The number that was misleading**: 235 of the 563 were never deletion candidates.

Named for what it proves. My first draft called this `forty_two_percent_was_never_dead` while
the statement said `= 41` — `Nat` division truncates 41.74, so the name overstated the theorem by
a point. That is the exact defect this project hunts in other people's code, found in my own
within a minute of writing it, and the name moved rather than the number. -/
theorem at_least_forty_one_percent_was_never_dead : 226 * 100 / 547 = 41 := by decide

#guard classify 0 6 == Reachability.framework
#guard classify 0 0 == Reachability.noEvidence
#guard classify 3 0 == Reachability.textual
#guard censusFramework + censusNoEvidence == censusTotal

/-! ## The fifth rung: annotation-driven and machine-generated reachability

The 321 `noEvidence` methods were finally triaged at checkpoint 40, and **210 of them were never
deletion candidates either**. Measured, by reading the owning file of each of the 321:

| channel | count | why a textual scan cannot see it |
|---|---|---|
| XML-binding (`@Xml*`, `javax`/`jakarta.xml.bind`) | **176** | JAXB calls getters and setters reflectively from the schema |
| ANTLR-generated (`org.antlr`) | **28** | the parser calls visitor/listener methods it generates |
| test classes | **6** | called by a runner, not by the app |
| genuinely unexplained | **111** | the real candidate list |

A prediction was made and **disproved** before this: that `@Override` methods reached through
interface dispatch would be a missing rung. Measured, **0 of the 321** carry `@Override` — the
census already excludes them. Recorded because a rung that turned out not to exist is a result,
and inventing it would have inflated the rescue count. -/

/-- Evidence the v4 census could not see: annotation-driven binding, and machine-generated
source whose callers are generated with it. -/
structure EvidenceV5 where
  /-- `name(` and `.name(` — an ordinary call. -/
  calls : Nat
  /-- `::name` — dispatch through a functional interface. -/
  methodRefs : Nat
  /-- `X.class` — the owning class handed to a framework. -/
  classRefs : Nat
  /-- `@Xml*` / `jakarta.xml.bind` on the owning file: the binding layer drives the accessors. -/
  xmlBindings : Nat
  /-- The file is machine-generated (ANTLR, JAXB `ObjectFactory`). -/
  generated : Bool
  deriving DecidableEq, Repr

/-- Reachable only because a binding layer or a generator drives it. **Not** proof of use — proof
that a textual scan cannot decide. Kept distinct from `textual` for exactly that reason. -/
def classifyV5 (e : EvidenceV5) : Reachability :=
  if 0 < e.calls + e.methodRefs then .textual
  else if 0 < e.classRefs then .framework
  else if 0 < e.xmlBindings || e.generated then .framework
  else .noEvidence

/-- **The fifth repair, stated durably**: a method on an XML-bound class is never reported as a
deletion candidate, for any positive number of binding annotations. -/
theorem an_xml_bound_method_is_never_a_candidate (n : Nat) (h : 0 < n) :
    classifyV5 ⟨0, 0, 0, n, false⟩ ≠ .noEvidence := by
  unfold classifyV5
  simp [Nat.not_lt.mpr (Nat.zero_le 0), h]

/-- Machine-generated source likewise. Its callers are generated beside it and are not in the
tree the census scans. -/
theorem generated_source_is_never_a_candidate :
    classifyV5 ⟨0, 0, 0, 0, true⟩ ≠ .noEvidence := by decide

/-- **Anti-amputation, fifth form.** The rescue does not swallow the list: with no evidence of
any kind, including no annotations and no generator, the verdict is still `noEvidence`. Without
this the classifier could rescue everything and report a clean tree by construction. -/
theorem v5_still_reports_the_genuinely_unreferenced :
    classifyV5 ⟨0, 0, 0, 0, false⟩ = .noEvidence := by decide

/-- **The rescue only ever touches `noEvidence`.** A method v4 already called `textual` is still
`textual` under v5 — the new rungs cannot downgrade a real call site into a reflective guess.
Quantified over every evidence value, so no future count breaks it. -/
theorem v5_agrees_with_v4_wherever_v4_had_evidence (e : EvidenceV5)
    (h : classifyV4 ⟨e.calls, e.methodRefs, e.classRefs⟩ ≠ .noEvidence) :
    classifyV5 e = classifyV4 ⟨e.calls, e.methodRefs, e.classRefs⟩ := by
  unfold classifyV4 classifyV5 at *
  by_cases hc : 0 < e.calls + e.methodRefs
  · simp [hc]
  · by_cases hr : 0 < e.classRefs
    · simp [hc, hr]
    · simp [hc, hr] at h

/-- **The honesty clause.** `framework` is not `textual`: this classifier never claims a
reflectively-bound method is *executed*, only that "no evidence" is the wrong label for it. The
distinction is the whole reason the census is a candidate list and not a delete list. -/
theorem reflective_is_not_proof_of_use : Reachability.framework ≠ Reachability.textual := by
  decide

/-- The triage of the 321, measured at checkpoint 40. -/
def triageXmlBound : Nat := 176
/-- ANTLR-generated methods among the 321. -/
def triageGenerated : Nat := 28
/-- Test-class methods among the 321. -/
def triageTests : Nat := 6
/-- What actually remains a deletion candidate. -/
def triageUnexplained : Nat := 111

/-- The triage is exhaustive: every one of the 321 landed in exactly one bucket. An arithmetic
identity is a weak theorem, and it is here for one strong reason — it fails the moment a bucket
is quietly adjusted to make a report look better. -/
theorem the_triage_accounts_for_every_candidate :
    triageXmlBound + triageGenerated + triageTests + triageUnexplained = censusNoEvidence := by
  decide

/-- **Two thirds of the "dead" list was never dead.** Named for what it proves: 210 of 321. -/
theorem at_least_sixty_five_percent_of_the_candidates_survive_triage :
    (triageXmlBound + triageGenerated + triageTests) * 100 / censusNoEvidence = 65 := by decide

#guard classifyV5 ⟨0, 0, 0, 12, false⟩ == Reachability.framework
#guard classifyV5 ⟨0, 0, 0, 0, true⟩ == Reachability.framework
#guard classifyV5 ⟨0, 0, 0, 0, false⟩ == Reachability.noEvidence
#guard classifyV5 ⟨3, 0, 0, 0, false⟩ == Reachability.textual
#guard triageXmlBound + triageGenerated + triageTests + triageUnexplained == censusNoEvidence

/-! ### v6 — the sixth channel: Jackson bean binding

Measured at checkpoint 45 by executing the real deserializer (`tools/MfcBindCheck.java`), not by
reading source: `MyFreeCamsClient.java:327` calls `objectMapper.readValue(..., SessionState.class)`,
and Jackson binds nested beans **through their setters**. A payload of five known fields came back
as `country=IT ethnic=x occupation=dev avatar=7` — so those setters run, while no Java source
mentions them.

The channel is *transitive*, and that is the part a one-level scan gets wrong: `SessionState` is
named in a bind call, `User` never is — it is reached only as a field of `SessionState`. Measured
closure over the tree: 12 seed types, fixed point at **21** types after 3 rounds (round 3 = round
2, so it is a genuine fixed point rather than a truncated walk).

That accounts for **48** of the 111 that survived v5. -/

/-- Evidence about one method, with the Jackson channel added. `beanBoundDepth` is the distance
from a type named in a `readValue`/`convertValue` call: `0` means the class itself is named,
`n > 0` means it is reached through `n` field hops, and `none` means it is not reachable at all. -/
structure EvidenceV6 where
  /-- Everything v5 already knew. -/
  base : EvidenceV5
  /-- Hops from a Jackson bind seed, if reachable. -/
  beanBoundDepth : Option Nat
  /-- Whether the method name is a bean accessor (`get*`/`set*`/`is*`). -/
  isAccessor : Bool
  deriving DecidableEq, Repr

/-- A method is Jackson-driven when it is an accessor on a type in the bind closure — at ANY
depth. Requiring depth `0` is the bug this models away. -/
def jacksonDriven (e : EvidenceV6) : Bool :=
  match e.beanBoundDepth with
  | none => false
  | some _ => e.isAccessor

/-- v6: v5, plus the Jackson channel. -/
def classifyV6 (e : EvidenceV6) : Reachability :=
  match classifyV5 e.base with
  | .noEvidence => if jacksonDriven e then .framework else .noEvidence
  | r => r

/-- **The sixth repair, stated durably**: an accessor on a Jackson-bound type is never reported as
a deletion candidate — at any depth, including types reached only through field hops. -/
theorem a_bean_accessor_on_a_bound_type_is_never_a_candidate (d : Nat) :
    classifyV6 ⟨⟨0, 0, 0, 0, false⟩, some d, true⟩ ≠ .noEvidence := by
  intro h
  exact Reachability.noConfusion h

/-- **Depth is not a discriminator.** Stated separately because the natural implementation — check
whether the class is named in a bind call — is exactly the one that gets this wrong, and it would
be green on `SessionState` while silently dropping `User`. -/
theorem a_nested_bean_is_treated_like_a_named_one (d₁ d₂ : Nat) :
    classifyV6 ⟨⟨0, 0, 0, 0, false⟩, some d₁, true⟩
      = classifyV6 ⟨⟨0, 0, 0, 0, false⟩, some d₂, true⟩ := rfl

/-- **Anti-amputation**: a non-accessor on a bound type is still reported. Jackson does not call
arbitrary methods, and pretending otherwise would launder real dead code into "framework". -/
theorem a_non_accessor_on_a_bound_type_is_still_reported (d : Nat) :
    classifyV6 ⟨⟨0, 0, 0, 0, false⟩, some d, false⟩ = .noEvidence := rfl

/-- **And an accessor on an unbound type is still reported.** Being a getter is not evidence. -/
theorem an_accessor_on_an_unbound_type_is_still_reported :
    classifyV6 ⟨⟨0, 0, 0, 0, false⟩, none, true⟩ = .noEvidence := by decide

/-- **No regression**: wherever v5 already had evidence, v6 returns exactly what v5 returned. The
new channel only ever rescues from `noEvidence`. -/
theorem v6_agrees_with_v5_wherever_v5_had_evidence (e : EvidenceV6)
    (h : classifyV5 e.base ≠ .noEvidence) : classifyV6 e = classifyV5 e.base := by
  unfold classifyV6
  cases hv : classifyV5 e.base with
  | textual => rfl
  | framework => rfl
  | noEvidence => exact absurd hv h

/-- Types named directly in a `readValue`/`convertValue`/`treeToValue` call. -/
def triageBindSeeds : Nat := 12
/-- The fixed point of the field-hop closure over those seeds. -/
def triageBindClosure : Nat := 21
/-- Accessors on closure types, among the 111 v5 left unexplained. -/
def triageJacksonBound : Nat := 48
/-- What remains after the sixth channel. -/
def triageUnexplainedV6 : Nat := 63

/-- **The closure genuinely grew.** If seeds equalled the closure, the transitive walk would be
dead code and `User` would have been missed — this is the theorem that fails if someone
"simplifies" the closure back to a one-level scan. -/
theorem the_closure_is_larger_than_its_seeds : triageBindSeeds < triageBindClosure := by decide

/-- The v6 triage is still exhaustive over the same 321. -/
theorem the_v6_triage_accounts_for_every_candidate :
    triageXmlBound + triageGenerated + triageTests + triageJacksonBound + triageUnexplainedV6
      = censusNoEvidence := by decide

/-- v6 is a refinement of v5, not a contradiction of it: the two new buckets partition v5's
remainder exactly. -/
theorem v6_only_splits_what_v5_left_over :
    triageJacksonBound + triageUnexplainedV6 = triageUnexplained := by decide

/-- **Four fifths of the original list is now explained.** 258 of 321. -/
theorem at_least_eighty_percent_of_the_candidates_survive_triage :
    (triageXmlBound + triageGenerated + triageTests + triageJacksonBound) * 100 / censusNoEvidence
      = 80 := by decide

#guard classifyV6 ⟨⟨0, 0, 0, 0, false⟩, some 0, true⟩ == Reachability.framework
#guard classifyV6 ⟨⟨0, 0, 0, 0, false⟩, some 3, true⟩ == Reachability.framework
#guard classifyV6 ⟨⟨0, 0, 0, 0, false⟩, some 3, false⟩ == Reachability.noEvidence
#guard classifyV6 ⟨⟨0, 0, 0, 0, false⟩, none, true⟩ == Reachability.noEvidence
#guard classifyV6 ⟨⟨2, 0, 0, 0, false⟩, none, false⟩ == Reachability.textual
#guard triageJacksonBound + triageUnexplainedV6 == triageUnexplained

/-! ## The codemap drift detector (spec-check phase 39)

`TASKS/CODEMAP-REWORK.md` carries a per-module (theorems/guards) table that was measured once and
then drifted for three checkpoints — `PreviewPipeline` read 55/33 against a real 77/52, and three
modules were missing from it entirely while being fully proved and mutated. A codemap that is
wrong is worse than one that is missing, because it is read as an inventory: a module absent from
it is a module nobody audits.

Phase 39 makes that prose falsifiable. What follows is the part of that check with a right and a
wrong answer, and in particular why its negative control is DERIVED from the real counts instead
of pinned to them. -/

/-- One row of the codemap table: a module and the counts claimed for it. -/
structure MapRow where
  name : String
  thm : Nat
  guard : Nat
deriving DecidableEq, Repr

/-- The row the files actually justify, looked up by name. `none` = the module is proved but
absent from the table, which the checker reports as drift rather than silence. -/
def rowFor (rows : List MapRow) (n : String) : Option MapRow :=
  rows.find? (fun r => r.name == n)

/-- A module is described correctly when the table holds a row with exactly its counts. -/
def describedBy (rows : List MapRow) (real : MapRow) : Bool :=
  match rowFor rows real.name with
  | none => false
  | some r => r.thm == real.thm && r.guard == real.guard

/-- The drift count: how many real modules the table fails to describe. -/
def driftCount (rows real : List MapRow) : Nat :=
  (real.filter (fun m => !describedBy rows m)).length

/-- A table that describes every module has zero drift. The direction the green run asserts. -/
theorem no_drift_when_every_module_described (rows real : List MapRow)
    (h : ∀ m ∈ real, describedBy rows m = true) : driftCount rows real = 0 := by
  unfold driftCount
  have : real.filter (fun m => !describedBy rows m) = [] := by
    apply List.filter_eq_nil_iff.mpr
    intro m hm
    simp [h m hm]
  simp [this]

/-- **A module missing from the table is always detected.** This is the failure that actually
happened: `Instruments`, `Meter` and `PoolScaling` were proved, mutated and checked while the
codemap did not mention them. -/
theorem an_absent_module_is_detected (rows real : List MapRow) (m : MapRow)
    (hmem : m ∈ real) (habs : rowFor rows m.name = none) : 0 < driftCount rows real := by
  unfold driftCount
  have hd : describedBy rows m = false := by simp [describedBy, habs]
  have : m ∈ real.filter (fun x => !describedBy rows x) := by
    apply List.mem_filter.mpr
    exact ⟨hmem, by simp [hd]⟩
  exact List.length_pos_of_mem this

/-- **Falsifying a row's theorem count is always detected**, for ANY counts. The control does not
depend on today's numbers, which is the whole point: a control pinned to a literal stops
controlling the day the module grows, and then passes by accident. -/
theorem a_falsified_row_is_detected (name : String) (t g : Nat) :
    describedBy [{ name := name, thm := t + 1, guard := g }]
                { name := name, thm := t, guard := g } = false := by
  simp [describedBy, rowFor, List.find?]

/-- The reason the `+ 1` above is a sound way to build a control: it always changes the value.
Stated over every `t`, so no future count can make the control vacuous. -/
theorem bumping_a_count_always_changes_it (t : Nat) : t + 1 ≠ t := by omega

/-- **A detector that never fires establishes nothing.** If `describedBy` were replaced by the
constant `true`, drift is zero even for a table that describes NOTHING -- which is exactly how a
green run can mean "the alarm is dead" rather than "the codemap is right". This is why phase 39
carries a negative control at all. -/
theorem a_blind_detector_passes_everything (real : List MapRow) :
    (real.filter (fun _ => !true)).length = 0 := by
  simp

-- The measured state at checkpoint 39: the table describes all 18 modules.
#guard driftCount [{ name := "Meter", thm := 32, guard := 16 }]
                  [{ name := "Meter", thm := 32, guard := 16 }] == 0
-- The control the checker runs: one falsified row, detected.
#guard driftCount [{ name := "Meter", thm := 33, guard := 16 }]
                  [{ name := "Meter", thm := 32, guard := 16 }] == 1
-- A module absent from the table, detected.
#guard driftCount [] [{ name := "PoolScaling", thm := 16, guard := 6 }] == 1

/-! ## The sixth census defect: unreferenced is not the same as harmless

Three checkpoints in a row found a defect hiding behind "it has no callers", and in all three the
census reported the file the same way — `no-evidence`, indistinguishable from genuinely inert code:

| checkpoint | file | what wiring it would have done |
|---|---|---|
| 49 | `io/XmlParserUtils.java` | parse hostile XML with every XXE guard off (measured: file read) |
| 50 | `ui/controls/range/CustomInputMap.java` | `StackOverflowError` (measured, on the real class) |
| 51 | `recorder/FfmpegPresets.vendors()` | offer a UI heading with no presets under it |

`no-evidence` answers *is anything calling this*. It does not answer *what happens the day
something does*, and those are different questions with different consequences. The comforting
answer — "dead code, ignore it" — was wrong three times out of three.

Note the direction of the error. Reading an armed unit as inert invites deletion or neglect of
code that is one wiring away from a defect; reading an inert unit as armed costs only an
inspection. The census defaulted to the cheap-to-hear answer. -/

/-- What the census can see, and what it cannot. -/
structure UnitFacts where
  /-- Textual call sites, what `no-evidence` is computed from. -/
  callSites : Nat
  /-- Whether the unit is constructed on a path the app actually runs, even if nothing dispatches
  to it afterwards. `CustomInputMap` was: every `RangeSlider` skin builds one. -/
  constructedOnLivePath : Bool
  /-- Whether wiring it up as intended produces a defect. NOT observable from reference counts —
  it takes executing the thing, which is what each checkpoint's probe did. -/
  defectIfWired : Bool
  deriving DecidableEq, Repr

/-- The verdict the census produces today: reference counting, and nothing else. -/
def censusVerdict (u : UnitFacts) : Reachability :=
  if u.callSites > 0 then .textual else .noEvidence

/-- A unit nothing calls, that misbehaves the moment something does. -/
def armed (u : UnitFacts) : Bool := u.callSites == 0 && u.defectIfWired

/-- A unit nothing calls, that is safe to wire. -/
def inert (u : UnitFacts) : Bool := u.callSites == 0 && !u.defectIfWired

/-- **Armed and inert are exclusive, and together they cover every unreferenced unit.** Without
this the two predicates could overlap — a unit reported as safe to wire *and* as a defect waiting
to happen, which is not a classification at all. A mutation that dropped `defectIfWired` from
`inert` survived the whole suite until this was stated. -/
theorem armed_and_inert_partition_the_unreferenced (u : UnitFacts) :
    (armed u && inert u) = false ∧
    (u.callSites == 0) = (armed u || inert u) := by
  simp [armed, inert]
  cases u.defectIfWired <;> simp

/-- The three findings, as facts rather than prose. -/
def xmlParserUtils : UnitFacts := ⟨0, false, true⟩
def customInputMap : UnitFacts := ⟨0, true, true⟩
def presetVendors : UnitFacts := ⟨0, false, true⟩
/-- `ThreadPoolScaler` — also unreferenced, and the contrasting case: its sizing algebra is proved
correct, so wiring it introduces no defect. This is what a genuine `inert` looks like. -/
def threadPoolScaler : UnitFacts := ⟨0, false, false⟩

/-- **The census cannot tell them apart.** An armed unit and an inert one receive the *same*
verdict — so a reader who acts on the census alone is acting on no information about the risk.
This is the defect, stated as the indistinguishability it actually is. -/
theorem the_census_gives_armed_and_inert_the_same_verdict :
    censusVerdict xmlParserUtils = censusVerdict threadPoolScaler ∧
    armed xmlParserUtils ≠ armed threadPoolScaler := by
  decide

/-- Stated generally, not as an anecdote about two files: for **any** pair of units agreeing on
call sites, the census verdict is equal whatever their behaviour when wired. No refinement of
reference counting can recover the distinction, because the distinction is not in the input. -/
theorem reference_counting_cannot_see_the_difference (u v : UnitFacts)
    (h : u.callSites = v.callSites) : censusVerdict u = censusVerdict v := by
  simp [censusVerdict, h]

/-- **Unreferenced does not imply harmless**, which is the sentence the census invited the reader
to believe. Three witnesses, all measured by executing the code. -/
theorem unreferenced_does_not_imply_harmless :
    armed xmlParserUtils ∧ armed customInputMap ∧ armed presetVendors := by
  decide

/-- …and it does not imply armed either. The census is not merely wrong in one direction; it is
silent, and a phase that flagged every unreferenced unit as dangerous would be just as useless. -/
theorem unreferenced_does_not_imply_armed : inert threadPoolScaler := by
  decide

/-- Being constructed on a live path is a *third* fact, independent of the other two.
`CustomInputMap` was built by every `RangeSlider` skin while nothing dispatched to it — so
"unreferenced" concealed an object that the running app really was creating. -/
theorem the_live_path_fact_is_independent :
    customInputMap.constructedOnLivePath = true ∧
    xmlParserUtils.constructedOnLivePath = false ∧
    armed customInputMap = armed xmlParserUtils := by
  decide

/-- A verdict recorded per unit, which is what the ledger adds. -/
inductive Verdict where
  /-- Executed, found defective, repaired, and a checker phase now covers it. -/
  | armedRepaired
  /-- Executed or read, found defective, NOT yet repaired. An open task, not a comfort. -/
  | armedOpen
  /-- Wiring it introduces no defect, and a Lean module says why. -/
  | inertProved
  /-- Nobody has looked. The honest default, and the one the ratchet counts. -/
  | unclassified
  deriving DecidableEq, Repr

/-- The ledger's reading of a unit. Unlike `censusVerdict` it consumes `defectIfWired`, which is
exactly the fact reference counting cannot supply. -/
def ledgerVerdict (u : UnitFacts) (examined : Bool) (repaired : Bool) : Verdict :=
  if u.callSites > 0 then .inertProved
  else if !examined then .unclassified
  else if !u.defectIfWired then .inertProved
  else if repaired then .armedRepaired
  else .armedOpen

/-- **The ledger distinguishes what the census could not** — the same pair, now separated. -/
theorem the_ledger_separates_armed_from_inert :
    ledgerVerdict xmlParserUtils true true ≠ ledgerVerdict threadPoolScaler true true := by
  decide

/-- **An unexamined unit is never reported as safe.** This is the property that keeps the ledger
from becoming the same comfort the census was: silence maps to `unclassified`, never to
`inertProved`, for every unit. -/
theorem silence_is_never_reported_as_safe (u : UnitFacts) (repaired : Bool)
    (h : u.callSites = 0) : ledgerVerdict u false repaired = .unclassified := by
  simp [ledgerVerdict, h]

/-- **A defect that has not been repaired stays visible.** Examining an armed unit and doing
nothing yields `armedOpen`, not a clean bill — so a checkpoint cannot close a finding by merely
looking at it. -/
theorem examining_without_repairing_does_not_clear_it (u : UnitFacts)
    (h : u.callSites = 0) (hd : u.defectIfWired = true) :
    ledgerVerdict u true false = .armedOpen := by
  simp [ledgerVerdict, h, hd]

#guard censusVerdict xmlParserUtils == censusVerdict threadPoolScaler
#guard armed xmlParserUtils == true
#guard inert threadPoolScaler == true
#guard ledgerVerdict xmlParserUtils true true == Verdict.armedRepaired
#guard ledgerVerdict xmlParserUtils true false == Verdict.armedOpen
#guard ledgerVerdict threadPoolScaler true true == Verdict.inertProved
#guard ledgerVerdict customInputMap false true == Verdict.unclassified
#guard ledgerVerdict ⟨3, false, true⟩ false false == Verdict.inertProved

end CtbrecSpec
