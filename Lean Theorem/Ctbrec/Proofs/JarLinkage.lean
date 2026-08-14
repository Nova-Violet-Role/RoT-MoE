/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — cross-jar linkage, and why "all classes load" was worth nothing

Subject: the DEPLOYED artefacts `ctbrec-26.7.11.jar` (app) and `lib/common-26.7.11.jar`
(common), and the checker `tools/JarLinkCheck.java` that now binds them.

## The defect this module exists for (measured 2026-08-06, not reconstructed)

`ctbrec-26.7.11.jar` was rebuilt at 2026-08-05 21:36 for CP71. That rebuild compiled
`CamrecApplication` against the rework source tree, where an earlier checkpoint had moved a
division out of the UI and into `BandwidthMeter.bytesPerSecond(long, Duration)`. The app jar
therefore shipped

```
invokestatic ctbrec/io/BandwidthMeter.bytesPerSecond:(JLjava/time/Duration;)D
```

while **no `common-26.7.11.jar` ever deployed contained that method** — measured across all
13 backups plus the live jar with `javap`, count `bytesPerSecond = 0` in every one.

JVMS 5.4.3 makes symbolic resolution LAZY. So the app started, the toolkit came up, the
recorder logged `Starting recording for model X` — and the start task then died on
`java.lang.NoSuchMethodError`. Measured by JFR `jdk.JavaErrorThrow`:

```
message     = "'double ctbrec.io.BandwidthMeter.bytesPerSecond(long, java.time.Duration)'"
thrownClass = java.lang.NoSuchMethodError
stackTrace  = ctbrec.ui.CamrecApplication.lambda$registerBandwidthMeterListener$21 line: 796
```

`NoSuchMethodError` is an `Error`, not an `Exception`, so
`SimplifiedLocalRecorder.startRecordingProcessSync`'s `catch (Exception e)` did not catch it
and nothing was logged. Consequence, measured on disk: **94 recording starts across 3 h 12 min
produced zero bytes of video**, while `ctbrec.log` showed only routine INFO lines and the
recorder re-started every model every 60 s forever.

## Why the existing instrument passed

`tools/LoadVerify.java` reports `ALL CLASSES LINK`. Loading a class does not resolve the
member references in its constant pool. That green was true and irrelevant — and this module
proves the gap is real rather than asserting it: `loading_does_not_imply_linking`.

## What is proved here

`linkCheckGreen` is the exact predicate `JarLinkCheck` computes. The theorems below say it is
sound AND complete for the property that matters, that it is strictly stronger than the
load-check that missed this, and — the uncomfortable one — that deleting the call site would
also turn it green, which is why `the_call_site_must_survive` is stated separately.
-/

namespace CtbrecSpec
namespace JarLinkage

/-- A member reference exactly as it appears in a constant pool: owning class, name,
descriptor. Descriptor is part of the identity — that is the whole point of this defect, since
a `bytesPerSecond` with a different descriptor would not have resolved either. -/
structure Member where
  owner : String
  name  : String
  desc  : String
deriving DecidableEq, Repr

/-- One artefact on the classpath. `classes` is what a class LOADER can find; `provides` is
what a member RESOLUTION can find. Keeping them separate is not bookkeeping — it is the
difference between the check that passed and the check that would have caught this. -/
structure Jar where
  name     : String
  classes  : List String
  provides : List Member
deriving Repr

abbrev Classpath := List Jar

/-- A class file and the ctbrec-owned member references in its constant pool. -/
structure ClassFile where
  name       : String
  references : List Member
deriving Repr

/-- Member resolution: some jar on the classpath provides exactly this member. -/
def resolves (cp : Classpath) (m : Member) : Bool :=
  cp.any (fun j => j.provides.contains m)

/-- Class loading: some jar on the classpath contains the owning class. This is all
`LoadVerify` establishes. -/
def classLoads (cp : Classpath) (owner : String) : Bool :=
  cp.any (fun j => j.classes.contains owner)

/-- Every referenced owner class can be loaded — the LoadVerify property. -/
def loads (cp : Classpath) (cs : List ClassFile) : Bool :=
  cs.all (fun c => c.references.all (fun m => classLoads cp m.owner))

/-- Exactly what `JarLinkCheck` collects and prints. -/
def unresolved (cp : Classpath) (cs : List ClassFile) : List Member :=
  cs.flatMap (fun c => c.references.filter (fun m => !resolves cp m))

/-- Exit 0 of `tools/JarLinkCheck.java`. -/
def linkCheckGreen (cp : Classpath) (cs : List ClassFile) : Bool :=
  (unresolved cp cs).isEmpty

/-- Every reference resolves — the property a recording start actually needs. -/
def links (cp : Classpath) (cs : List ClassFile) : Bool :=
  cs.all (fun c => c.references.all (fun m => resolves cp m))

/-! ## The checker means what it says -/

/-- SOUND AND COMPLETE in one statement, for every classpath and every class set: the checker
is green exactly when every reference resolves. Quantified over the variables that move, so a
future jar layout cannot make it stale. -/
theorem green_iff_links (cp : Classpath) (cs : List ClassFile) :
    linkCheckGreen cp cs = links cp cs := by
  simp only [linkCheckGreen, links, unresolved]
  rw [Bool.eq_iff_iff]
  simp [List.isEmpty_iff, List.flatMap_eq_nil_iff, List.filter_eq_nil_iff,
        List.all_eq_true]

/-- The direction that matters at run time: a green check forbids the `NoSuchMethodError`
that killed every recording. -/
theorem green_forbids_the_run_time_error
    (cp : Classpath) (cs : List ClassFile) (h : linkCheckGreen cp cs = true)
    (c : ClassFile) (hc : c ∈ cs) (m : Member) (hm : m ∈ c.references) :
    resolves cp m = true := by
  have hl : links cp cs = true := by rw [← green_iff_links]; exact h
  simp [links, List.all_eq_true] at hl
  exact hl c hc m hm

/-- The direction that makes it an instrument rather than a decoration: a member that does not
resolve is REPORTED, by name, not merely counted. A checker that cannot name the break cannot
be acted on. -/
theorem a_missing_member_is_reported
    (cp : Classpath) (cs : List ClassFile) (c : ClassFile) (hc : c ∈ cs)
    (m : Member) (hm : m ∈ c.references) (hr : resolves cp m = false) :
    m ∈ unresolved cp cs ∧ linkCheckGreen cp cs = false := by
  have hmem : m ∈ unresolved cp cs := by
    simp only [unresolved, List.mem_flatMap]
    exact ⟨c, hc, by simp [List.mem_filter, hm, hr]⟩
  refine ⟨hmem, ?_⟩
  cases hu : unresolved cp cs with
  | nil => rw [hu] at hmem; simp at hmem
  | cons a t => simp [linkCheckGreen, hu]

/-! ## Why the green that already existed was worthless

This is the load-bearing pair. The first says the two checks are genuinely different; the
second says the new one is strictly stronger rather than merely different. -/

/-- The real deployment, as three strings measured from the artefacts. -/
def bytesPerSecond : Member :=
  { owner := "ctbrec/io/BandwidthMeter"
    name  := "bytesPerSecond"
    desc  := "(JLjava/time/Duration;)D" }

/-- Another member of the same class, present in every build — this is what made the class
LOADABLE while the member was missing. -/
def getThroughput : Member :=
  { owner := "ctbrec/io/BandwidthMeter"
    name  := "getThroughput"
    desc  := "()J" }

/-- `lib/common-26.7.11.jar` as deployed from 2026-08-05 21:36 to 2026-08-06 00:53:
the class is there, the method is not. -/
def brokenCommon : Jar :=
  { name := "common-26.7.11.jar"
    classes := ["ctbrec/io/BandwidthMeter"]
    provides := [getThroughput] }

/-- The same jar after the fix of 2026-08-06 00:53 (`jar uf` of a `BandwidthMeter.class`
recompiled from `src/common/ctbrec/io/BandwidthMeter.java`). -/
def fixedCommon : Jar :=
  { brokenCommon with provides := getThroughput :: [bytesPerSecond] }

/-- `CamrecApplication.class` from the app jar rebuilt at 2026-08-05 21:36. -/
def camrecApplication : ClassFile :=
  { name := "ctbrec/ui/CamrecApplication.class"
    references := [bytesPerSecond] }

/-- THE INDICTMENT OF THE OLD INSTRUMENT. There exists a deployment where every referenced
class loads and yet a reference does not resolve — so `ALL CLASSES LINK` can be true while the
app is dead. This is a witness, not an opinion: it is the deployment that was actually live. -/
theorem loading_does_not_imply_linking :
    loads [brokenCommon] [camrecApplication] = true ∧
    links [brokenCommon] [camrecApplication] = false := by
  decide

/-- And the new check is not merely different — it is STRICTLY STRONGER, on well-formed
classpaths (every provided member's owner is a class of the same jar, which is a property of
any real jar). Green here implies the old check's green, so nothing is lost by switching. -/
def wellFormed (cp : Classpath) : Bool :=
  cp.all (fun j => j.provides.all (fun m => j.classes.contains m.owner))

theorem linking_implies_loading (cp : Classpath) (cs : List ClassFile)
    (hw : wellFormed cp = true) (h : links cp cs = true) :
    loads cp cs = true := by
  simp only [links, List.all_eq_true] at h
  simp only [wellFormed, List.all_eq_true] at hw
  simp only [loads, List.all_eq_true]
  intro c hc m hm
  have hres := h c hc m hm
  simp only [resolves, List.any_eq_true] at hres
  obtain ⟨j, hj, hjm⟩ := hres
  simp only [classLoads, List.any_eq_true]
  exact ⟨j, hj, hw j hj m (List.mem_of_elem_eq_true hjm)⟩

/-! ## The concrete deployment, before and after -/

/-- The state that produced 94 empty recording starts. -/
theorem the_live_deployment_was_red :
    linkCheckGreen [brokenCommon] [camrecApplication] = false := by decide

/-- The fix, stated as the flip it actually is. -/
theorem deploying_the_member_makes_it_green :
    linkCheckGreen [fixedCommon] [camrecApplication] = true := by decide

/-- Non-vacuity: the reported break is exactly the one measured by JFR, named. Without this
the RED above could be RED for any reason at all. -/
theorem the_break_was_exactly_bytes_per_second :
    unresolved [brokenCommon] [camrecApplication] = [bytesPerSecond] := by decide

/-! ## The uncomfortable theorem, and the guard it forces

A green link check does NOT prove the feature exists. Deleting the call site turns it green
too. Any spec that stopped at `deploying_the_member_makes_it_green` would accept an
amputation as a fix — which is precisely the move the master forbids. -/

/-- Amputation also satisfies the checker. Stated so it can never be forgotten. -/
theorem deleting_the_call_site_also_goes_green :
    linkCheckGreen [brokenCommon] [{ camrecApplication with references := [] }] = true := by
  decide

/-- Therefore the checker is paired with a presence obligation: the call site must still be
there. `phase70` asserts this on the real jar with `javap`. -/
def callSitePresent (cs : List ClassFile) (m : Member) : Bool :=
  cs.any (fun c => c.references.contains m)

theorem the_call_site_must_survive :
    callSitePresent [camrecApplication] bytesPerSecond = true := by decide

theorem amputation_is_visible_to_the_presence_check :
    callSitePresent [{ camrecApplication with references := [] }] bytesPerSecond = false := by
  decide

/-- The conjunction is what "fixed" means, and only the real fix satisfies it: the reference
still exists AND it resolves. Neither half alone is enough. -/
def genuinelyFixed (cp : Classpath) (cs : List ClassFile) (m : Member) : Bool :=
  callSitePresent cs m && linkCheckGreen cp cs

theorem only_the_real_fix_is_genuinely_fixed :
    genuinelyFixed [fixedCommon] [camrecApplication] bytesPerSecond = true ∧
    genuinelyFixed [brokenCommon] [camrecApplication] bytesPerSecond = false ∧
    genuinelyFixed [brokenCommon] [{ camrecApplication with references := [] }]
      bytesPerSecond = false := by
  decide

/-! ## Monotonicity — a deploy that only ADDS can never break linkage

Guards the repair direction: shipping a jar with more members must never turn a green
classpath red, so "the fix broke something else" cannot be blamed on the fix itself. -/

theorem adding_a_jar_preserves_resolution (cp : Classpath) (j : Jar) (m : Member)
    (h : resolves cp m = true) : resolves (j :: cp) m = true := by
  simp only [resolves, List.any_eq_true] at *
  obtain ⟨k, hk, hkm⟩ := h
  exact ⟨k, List.mem_cons_of_mem j hk, hkm⟩

theorem adding_a_jar_preserves_green (cp : Classpath) (cs : List ClassFile) (j : Jar)
    (h : linkCheckGreen cp cs = true) : linkCheckGreen (j :: cp) cs = true := by
  rw [green_iff_links] at h ⊢
  simp only [links, List.all_eq_true] at h ⊢
  intro c hc m hm
  exact adding_a_jar_preserves_resolution cp j m (h c hc m hm)

/-- Anti-amputation on the JAR side: removing a member that is referenced turns the check red.
So "fix the link error by deleting the method" is caught as well. -/
theorem removing_the_member_again_goes_red :
    linkCheckGreen [{ fixedCommon with provides := [getThroughput] }] [camrecApplication]
      = false := by decide

/-! ## Executable checks — the definitions actually run and agree with the theorems -/

#guard linkCheckGreen [brokenCommon] [camrecApplication] == false
#guard linkCheckGreen [fixedCommon] [camrecApplication] == true
#guard loads [brokenCommon] [camrecApplication] == true
#guard unresolved [brokenCommon] [camrecApplication] == [bytesPerSecond]
#guard unresolved [fixedCommon] [camrecApplication] == []
#guard wellFormed [brokenCommon] == true
#guard wellFormed [fixedCommon] == true
#guard callSitePresent [camrecApplication] bytesPerSecond == true
#guard genuinelyFixed [fixedCommon] [camrecApplication] bytesPerSecond == true

end JarLinkage
end CtbrecSpec
