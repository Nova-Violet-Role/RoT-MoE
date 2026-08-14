/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

import Proofs.Ctbrec.FfmpegSelection
/-

# ctbrec — the Java runtime it ships and the one it should ship

Requested: run on the lightest and most powerful Java version possible.

Two questions hide inside that, and they pull in opposite directions. *Lightest* wants the
smallest module set; *most powerful* wants the newest JDK and every optional accelerator
linked in. They are only reconcilable because "light" means **few modules**, not **old
version** — a newer JDK with a tighter module set is smaller *and* faster, and the theorems
below are what stop either half from quietly eating the other.

## Measured on this machine

The app ships its own runtime at `ctbrec/jre` — already jlink-trimmed, not a full JDK:

  | | measured |
  |---|---|
  | shipped `jre` version | **21.0.8** (2025-07-15) |
  | shipped `jre` size | **66 MB** |
  | shipped `jre` modules | **23** |
  | app class file major version | **65**, i.e. Java 21 |
  | newest JDK installed | 21.0.11 (temurin21) |
  | JavaFX | 21.0.8, linked into the `jre` as modules |

## The near-miss, recorded because the first read of it was wrong

`jdeps` reports the app's closure needs `java.net.http` and `jdk.jfr`, and **neither is in
the shipped runtime** — probed directly, both `ABSENT`. That looks like a shipped defect,
and it was written up as one for about a minute.

It is not. Both arrive through `requires static`:

  * `org.jsoup.helper.HttpClientExecutor` → `requires static java.net.http` (jsoup 1.21.2)
  * `com.sun.javafx.logging.jfr.JFRInputEvent` → `requires static jdk.jfr` (javafx-base)

`requires static` is a **compile-time-only** dependency: absent at runtime, the class is
simply never loaded and the library takes another path. jsoup falls back to
`HttpURLConnection`; JavaFX skips its JFR probes. Nothing crashes, which the 49 263-line
log agrees with.

That distinction is the entire content of this module. A runtime checker that cannot tell
`requires` from `requires static` reports a false alarm on every optional dependency any
library ever declares — and one that ignores the difference reports nothing at all when a
*mandatory* module goes missing. `missing_optional_is_not_a_defect` and
`missing_mandatory_is_a_defect` are the two halves, and they must both stay true.

## What is worth changing, and why it is an amplification rather than a fix

Adding `java.net.http` is not repairing a break — it is **upgrading a fallback**. jsoup
prefers `HttpClientExecutor` when the module is present, which is HTTP/2 with connection
reuse, against `HttpURLConnection`'s HTTP/1.1. Same for `jdk.jfr`: present, JavaFX emits
flight-recorder events and the app becomes profileable in production.

Both are small. The rule proved below is that adding modules to a runtime can never make a
previously-adequate runtime inadequate (`adding_modules_preserves_adequacy`), so this
direction of change is always safe; it is *removal* that needs the checker.

## On expiry — the mistake this module is written to avoid

The tempting theorem is `shipped_runtime_is_21_0_8`, or `required = [java.base, …]` with
today's twelve module names frozen in. Both are **dated**: the first is false the moment
the runtime is upgraded, which is the very thing being asked for, and the second is false
the moment a library is added.

So nothing here is stated about a particular version or a particular module list. The
invariants are relations — *the runtime's feature version is at least the floor the
bytecode demands*, *every mandatory module is provided* — quantified over the version and
the module set. `tools/JdkCheck.java` supplies today's values by running the real `jdeps`
and the real `java --list-modules`, so the numbers live where they can be re-measured
rather than in a theorem that expires.
-/

namespace CtbrecSpec

/-! ## Class-file version and the floor it imposes

A `.class` file's major version determines the minimum JDK that can load it. This is the
one hard constraint: below the floor the runtime does not start, it throws
`UnsupportedClassVersionError` before any application code runs. -/

/-- The JDK feature release that first emits a given class-file major version.
Major 65 ↔ Java 21, and the offset has been 44 since Java 1.1. -/
def featureOfMajor (major : Nat) : Nat := major - 44

/-- The lowest JDK feature release that can load a class file of this major version. -/
def floorOfMajor (major : Nat) : Nat := featureOfMajor major

#guard featureOfMajor 65 == 21   -- the app, measured with javap -v
#guard featureOfMajor 61 == 17
#guard featureOfMajor 52 == 8
#guard featureOfMajor 69 == 25   -- Temurin 25 LTS

/-- A JDK can load a class file iff its feature release is at least the floor. -/
def canLoad (feature major : Nat) : Bool := floorOfMajor major ≤ feature

#guard canLoad 21 65 == true    -- shipped jre 21 loading the app's major-65 classes
#guard canLoad 25 65 == true    -- a newer JDK still loads them
#guard canLoad 17 65 == false   -- temurin17 would throw UnsupportedClassVersionError

/-- **Newer never breaks older bytecode.** The direction of the whole request: upgrading
the runtime cannot make a class file unloadable. Java's compatibility promise, stated so
that a mutation reversing the comparison is caught. -/
theorem upgrade_never_breaks_loading (f f' major : Nat) (hle : f ≤ f')
    (h : canLoad f major = true) : canLoad f' major = true := by
  simp only [canLoad, decide_eq_true_eq] at *
  exact Nat.le_trans h hle

/-- **Downgrading below the floor does break it** — why `temurin17` is not an option here
even though it is installed and smaller. -/
theorem downgrade_below_floor_breaks (f major : Nat) (h : f < floorOfMajor major) :
    canLoad f major = false := by
  simp only [canLoad, decide_eq_false_iff_not, Nat.not_le]
  exact h

/-- The floor is exactly attainable: a JDK at the floor loads the class file. No
off-by-one, which is the classic way a version gate rejects a valid runtime. -/
theorem floor_is_attainable (major : Nat) : canLoad (floorOfMajor major) major = true := by
  simp [canLoad]

/-! ## Modules: mandatory versus optional

The distinction the near-miss above turned on. -/

/-- How a module is required. `requires static` is compile-time only. -/
inductive Requirement where
  /-- `requires`: the module must be present at runtime or classes fail to link. -/
  | mandatory
  /-- `requires static`: present at compile time, optional at runtime. The library takes
  a different path when it is absent. -/
  | optional
  deriving DecidableEq, Repr, Inhabited

/-- A module the analysis found, and how it is required. -/
structure ModuleDep where
  name : String
  requirement : Requirement
  deriving DecidableEq, Repr, Inhabited

/-- A module is missing when the runtime does not provide it. -/
def isMissing (provided : List String) (d : ModuleDep) : Bool :=
  !provided.contains d.name

/-- **The defect predicate**: a missing module is a defect only when it is mandatory. -/
def isDefect (provided : List String) (d : ModuleDep) : Bool :=
  isMissing provided d && d.requirement == Requirement.mandatory

/-- A runtime is adequate when it has no defects. -/
def adequate (provided : List String) (deps : List ModuleDep) : Bool :=
  deps.all (fun d => !isDefect provided d)

/-- **A missing optional module is not a defect.** This is the theorem that stops the
checker crying wolf on `java.net.http` and `jdk.jfr`. -/
theorem missing_optional_is_not_a_defect (provided : List String) (d : ModuleDep)
    (h : d.requirement = Requirement.optional) : isDefect provided d = false := by
  simp [isDefect, h]

/-- **A missing mandatory module IS a defect.** The other half; without it the checker
could be made silent by declaring everything optional. -/
theorem missing_mandatory_is_a_defect (provided : List String) (d : ModuleDep)
    (hm : d.requirement = Requirement.mandatory) (h : isMissing provided d = true) :
    isDefect provided d = true := by
  simp [isDefect, hm, h]

/-- A provided module is never a defect, whatever its requirement. -/
theorem provided_is_never_a_defect (provided : List String) (d : ModuleDep)
    (h : provided.contains d.name = true) : isDefect provided d = false := by
  simp only [isDefect, isMissing, h, Bool.not_true, Bool.false_and]

/-- Membership survives appending — the one list fact the amplification argument needs. -/
theorem contains_append_left (l e : List String) (x : String) (h : l.contains x = true) :
    (l ++ e).contains x = true := by
  simp only [List.contains_append, h, Bool.true_or]

/-- **Adding modules to a runtime can never make it inadequate.** This is what makes
"add `java.net.http` and `jdk.jfr`" a safe amplification rather than a change needing its
own risk assessment — and equally, it is why *removal* is the direction the checker has to
police. -/
theorem adding_modules_preserves_adequacy (provided extra : List String)
    (deps : List ModuleDep) (h : adequate provided deps = true) :
    adequate (provided ++ extra) deps = true := by
  simp only [adequate, List.all_eq_true] at *
  intro d hd
  have hd0 : isDefect provided d = false := by simpa using h d hd
  simp only [Bool.not_eq_true']
  simp only [isDefect, Bool.and_eq_false_iff] at hd0 ⊢
  rcases hd0 with hm | hr
  · left
    have hc : provided.contains d.name = true := by
      simpa [isMissing, Bool.not_eq_false'] using hm
    have hap := contains_append_left provided extra d.name hc
    simp only [isMissing, hap, Bool.not_true]
  · exact Or.inr hr

/-- Removing a module can turn an adequate runtime inadequate — stated as an existence
proof so the previous theorem cannot be mistaken for "module sets do not matter". -/
theorem removing_a_module_can_break_adequacy :
    ∃ (p : List String) (deps : List ModuleDep),
      adequate p deps = true ∧ adequate [] deps = false :=
  ⟨["java.base"], [⟨"java.base", .mandatory⟩], by decide, by decide⟩

/-! ## Putting the two gates together

A runtime is runtimeUsable for an application when it can load the bytecode **and** provides every
mandatory module. Both gates, not either. -/

/-- Everything a runtime must satisfy. -/
def runtimeUsable (feature : Nat) (provided : List String) (major : Nat) (deps : List ModuleDep) :
    Bool :=
  canLoad feature major && adequate provided deps

/-- **The version gate cannot be bought off with modules.** A runtime below the floor is
unusable no matter how complete its module set — the failure happens at class load, before
any module is consulted. -/
theorem modules_cannot_rescue_an_old_runtime (feature major : Nat) (provided : List String)
    (deps : List ModuleDep) (h : canLoad feature major = false) :
    runtimeUsable feature provided major deps = false := by
  simp [runtimeUsable, h]

/-- **And modules cannot be bought off with a new version.** The symmetric statement; a
JDK 26 runtime missing a mandatory module is still unusable. Both are needed, because a
checker that tested only one would pass exactly half the broken configurations. -/
theorem a_new_runtime_cannot_rescue_missing_modules (feature major : Nat)
    (provided : List String) (deps : List ModuleDep) (h : adequate provided deps = false) :
    runtimeUsable feature provided major deps = false := by
  simp [runtimeUsable, h]

/-- Usability is monotone in the runtime version: upgrading a runtimeUsable runtime keeps it
runtimeUsable, provided the module set is not also cut. This is the formal content of "update the
JDK is safe". -/
theorem upgrade_preserves_usability (f f' major : Nat) (provided extra : List String)
    (deps : List ModuleDep) (hle : f ≤ f') (h : runtimeUsable f provided major deps = true) :
    runtimeUsable f' (provided ++ extra) major deps = true := by
  simp only [runtimeUsable, Bool.and_eq_true] at *
  exact ⟨upgrade_never_breaks_loading f f' major hle h.1,
    adding_modules_preserves_adequacy provided extra deps h.2⟩

/-! ## Choosing among installed runtimes

Same shape as `CtbrecSpec.FfmpegSelection`: prefer the newest that works, never something
that does not, and always have a fallback. -/

/-- An installed runtime. -/
structure Runtime where
  tag : String
  feature : Nat
  provided : List String
  deriving DecidableEq, Repr, Inhabited

/-- Pick the newest runtimeUsable runtime, falling back to the shipped one. -/
def pickRuntime (candidates : List Runtime) (shipped : Runtime) (major : Nat)
    (deps : List ModuleDep) : Runtime :=
  let ok := candidates.filter (fun r => runtimeUsable r.feature r.provided major deps)
  ok.foldl (fun best r => if best.feature < r.feature then r else best) shipped

/-- **The chosen runtime is always runtimeUsable, provided the shipped one is.** The fallback is
what makes this total: a machine with nothing installed still runs. -/
theorem pick_is_usable (candidates : List Runtime) (shipped : Runtime) (major : Nat)
    (deps : List ModuleDep) (hs : runtimeUsable shipped.feature shipped.provided major deps = true) :
    runtimeUsable (pickRuntime candidates shipped major deps).feature
      (pickRuntime candidates shipped major deps).provided major deps = true := by
  simp only [pickRuntime]
  generalize hok : candidates.filter (fun r => runtimeUsable r.feature r.provided major deps) = ok
  have hall : ∀ r ∈ ok, runtimeUsable r.feature r.provided major deps = true := by
    intro r hr
    subst hok
    simpa using (List.mem_filter.mp hr).2
  clear hok
  induction ok generalizing shipped with
  | nil => simpa using hs
  | cons a rest ih =>
    simp only [List.foldl_cons]
    by_cases h : shipped.feature < a.feature
    · simp only [h, if_true]
      exact ih a (hall a (by simp)) (fun r hr => hall r (List.mem_cons_of_mem a hr))
    · simp only [h, if_false]
      exact ih shipped hs (fun r hr => hall r (List.mem_cons_of_mem a hr))

/-- **Never a downgrade.** The chosen runtime is at least as new as the shipped one, so
"update the JDK" cannot silently move backwards — the defect this rule exists to prevent.
It is stated over the feature number rather than over any particular version, so it stays
true after the next upgrade. -/
theorem pick_never_downgrades (candidates : List Runtime) (shipped : Runtime) (major : Nat)
    (deps : List ModuleDep) :
    shipped.feature ≤ (pickRuntime candidates shipped major deps).feature := by
  simp only [pickRuntime]
  generalize candidates.filter (fun r => runtimeUsable r.feature r.provided major deps) = ok
  induction ok generalizing shipped with
  | nil => simp
  | cons a rest ih =>
    simp only [List.foldl_cons]
    by_cases h : shipped.feature < a.feature
    · simp only [h, if_true]
      exact Nat.le_trans (Nat.le_of_lt h) (ih a)
    · simp only [h, if_false]
      exact ih shipped

/-- An unusable candidate is never chosen, however new it is. A JDK 26 that lacks a
mandatory module loses to the shipped 21. -/
theorem unusable_candidates_are_filtered_out (r shipped : Runtime) (major : Nat)
    (deps : List ModuleDep) (h : runtimeUsable r.feature r.provided major deps = false) :
    pickRuntime [r] shipped major deps = shipped := by
  simp [pickRuntime, h]

/-! ## This machine, as data

Values measured on 2026-08 and kept out of the theorems above so that they can be
re-measured without touching a proof. `tools/JdkCheck.java` regenerates every one of them
from the real `jdeps` and the real `java --list-modules`. -/

/-- The app's class-file major version, from `javap -v ctbrec.ui.Launcher`. -/
def appClassMajor : Nat := 65

/-- The runtime ctbrec ships in `ctbrec/jre`, as measured. -/
def shippedJre : Runtime :=
  { tag := "bundled 21.0.8"
    feature := 21
    provided :=
      ["java.base", "java.compiler", "java.datatransfer", "java.desktop", "java.logging",
       "java.management", "java.naming", "java.prefs", "java.scripting",
       "java.security.jgss", "java.security.sasl", "java.sql", "java.transaction.xa",
       "java.xml", "javafx.base", "javafx.controls", "javafx.graphics", "javafx.media",
       "javafx.swing", "jdk.crypto.ec", "jdk.httpserver", "jdk.unsupported.desktop",
       "jdk.unsupported"] }

/-- What `jdeps` reported, with the `requires static` entries marked optional — the
distinction measured from jdeps' own `requires static` lines. -/
def measuredDeps : List ModuleDep :=
  [ ⟨"java.base", .mandatory⟩
  , ⟨"java.compiler", .mandatory⟩
  , ⟨"java.management", .mandatory⟩
  , ⟨"java.naming", .mandatory⟩
  , ⟨"java.scripting", .mandatory⟩
  , ⟨"java.security.jgss", .mandatory⟩
  , ⟨"java.sql", .mandatory⟩
  , ⟨"jdk.httpserver", .mandatory⟩
  , ⟨"jdk.unsupported", .mandatory⟩
  , ⟨"jdk.unsupported.desktop", .mandatory⟩
  , ⟨"java.net.http", .optional⟩    -- jsoup HttpClientExecutor: requires static
  , ⟨"jdk.jfr", .optional⟩ ]        -- javafx JFRInputEvent: requires static

/-- **The shipped runtime is adequate.** The near-miss, settled: the two absent modules are
both optional, so nothing is broken. -/
theorem shipped_jre_is_adequate : adequate shippedJre.provided measuredDeps = true := by
  decide

/-- And it can load the bytecode, so it is runtimeUsable overall. -/
theorem shipped_jre_is_usable :
    runtimeUsable shippedJre.feature shippedJre.provided appClassMajor measuredDeps = true := by
  decide

/-- The two modules that are genuinely absent, named. Not a defect — an opportunity. -/
theorem the_two_absent_modules_are_exactly_these :
    (measuredDeps.filter (fun d => isMissing shippedJre.provided d)).map ModuleDep.name
      = ["java.net.http", "jdk.jfr"] := by decide

/-- …and both are optional, which is precisely why the app has never crashed on them
across a 49 263-line log. -/
theorem both_absent_modules_are_optional :
    (measuredDeps.filter (fun d => isMissing shippedJre.provided d)).all
      (fun d => d.requirement == Requirement.optional) = true := by decide

/-- The amplification, stated as a runtime rather than a promise: the same runtime with
the two optional modules linked in. jsoup then uses HTTP/2 via `java.net.http` instead of
`HttpURLConnection`, and JavaFX can emit flight-recorder events. -/
def amplifiedJre : Runtime :=
  { shippedJre with
    tag := "jlink 21.0.11 + net.http + jfr"
    feature := 21
    provided := shippedJre.provided ++ ["java.net.http", "jdk.jfr"] }

/-- **Nothing is missing from the amplified runtime** — not even the optional entries. -/
theorem amplified_jre_has_everything :
    measuredDeps.all (fun d => !isMissing amplifiedJre.provided d) = true := by decide

/-- It is still runtimeUsable, which follows from the general theorem rather than from a new
`decide` — the point of proving `adding_modules_preserves_adequacy` at all. -/
theorem amplified_jre_is_usable :
    runtimeUsable amplifiedJre.feature amplifiedJre.provided appClassMajor measuredDeps = true := by
  have := upgrade_preserves_usability shippedJre.feature amplifiedJre.feature appClassMajor
    shippedJre.provided ["java.net.http", "jdk.jfr"] measuredDeps (Nat.le_refl _)
    shipped_jre_is_usable
  simpa [amplifiedJre] using this

/-- Temurin 17 is installed on this machine and is smaller. It is still not an option,
and this says why in one line rather than in a comment. -/
theorem temurin17_cannot_run_this_app : canLoad 17 appClassMajor = false := by decide

/-- A JDK 25 runtime carrying the same modules is runtimeUsable — the upgrade target, checked
before it is attempted rather than after. -/
theorem jdk25_would_be_usable :
    runtimeUsable 25 amplifiedJre.provided appClassMajor measuredDeps = true := by decide

/-! ## DNS cache policy — the one runtime knob the log actually asks for

**Measured, and the measurement is what makes this a finding rather than a guess.**
`ctbrec.log` holds 115 `UnknownHostException` events falling in only **16 distinct
minutes** across twelve days: two clusters, 56 events in four minutes on 2026-07-30 and
38 in three minutes on 2026-08-03. Every one of the eleven `ThumbOverviewTab:695
Couldn't update model list` errors is one of them, as are three of the five
`Couldn't start recording process` failures — so recordings were lost to a DNS blip
lasting minutes.

The JVM's own policy object, read through `sun.net.InetAddressCachePolicy`:

  | | default | with `-Dsun.net.inetaddr.stale.ttl=3600` |
  |---|---|---|
  | `get()` (positive) | 30 | 30 |
  | `getNegative()` | 10 | 10 |
  | `getStale()` | **0** | **3600** |

`getStale() = 0` means NEVER: when a fresh lookup fails, an expired-but-known-good
address is discarded rather than reused. Raising it lets a lookup failure fall back on
the last good answer for up to an hour.

**What is proved here is the policy shape, not the outcome.** That the flag moves
`getStale()` from 0 to 3600 is measured. That it *would have saved those particular
recordings* is not, and cannot be without taking DNS down; it is claimed nowhere. -/

/-- The three TTLs the JVM resolves an address under, in seconds. -/
structure DnsPolicy where
  positive : Nat
  negative : Nat
  /-- 0 means NEVER serve a stale entry — the JDK default. -/
  stale : Nat
  deriving DecidableEq, Repr, Inhabited

/-- Measured from `sun.net.InetAddressCachePolicy` on the shipped runtime. -/
def defaultDns : DnsPolicy := { positive := 30, negative := 10, stale := 0 }

/-- Measured with the flag the launcher now passes. -/
def fortifiedDns : DnsPolicy := { positive := 30, negative := 10, stale := 3600 }

/-- A stale answer is reachable only when the entry has expired AND a fresh lookup
failed. This is the guard that keeps the fortification from being "cache forever". -/
def servesStale (p : DnsPolicy) (ageSeconds : Nat) (freshLookupFailed : Bool) : Bool :=
  freshLookupFailed && p.positive < ageSeconds && ageSeconds ≤ p.positive + p.stale

/-- **The default never serves a stale answer**, whatever the age — `stale = 0` collapses
the window to nothing. This is the behaviour the log was produced under. -/
theorem default_never_serves_stale (age : Nat) (failed : Bool) :
    servesStale defaultDns age failed = false := by
  -- `stale = 0` makes the window `30 < age ∧ age ≤ 30`, which is empty. v4.32.2 closed this
  -- with `cases failed <;> simp <;> omega`; v4.33.0-rc1 leaves a goal in the `decide`/`Bool`
  -- encoding that `omega` cannot read ("no usable constraints"). Splitting on the PROPOSITION
  -- keeps the argument independent of whichever normal form the simp set produces, so one
  -- proof serves both toolchains.
  simp only [servesStale, defaultDns]
  by_cases h : 30 < age
  · have h2 : ¬ (age ≤ 30 + 0) := by omega
    simp [h, h2]
  · simp [h]

/-- **A successful lookup never consults the stale window.** Fresh data always wins, so
the fortification cannot serve an outdated address while DNS is healthy — the objection
that would make a large `stale.ttl` dangerous. -/
theorem fresh_success_never_serves_stale (p : DnsPolicy) (age : Nat) :
    servesStale p age false = false := by
  simp [servesStale]

/-- **The stale window is bounded**, so this is not "cache forever". Beyond
`positive + stale` seconds the address is dropped and the failure surfaces. -/
theorem stale_window_is_bounded (p : DnsPolicy) (age : Nat) (failed : Bool)
    (h : p.positive + p.stale < age) : servesStale p age failed = false := by
  simp only [servesStale]
  cases failed <;> simp <;> omega

/-- **The fortification strictly widens what the default covers.** Every case the default
serves, the fortified policy also serves — raising `stale.ttl` can only add resilience,
never remove it. Stated over the age and the failure flag rather than over the two
constants, so it survives a future retune. -/
theorem fortification_only_adds_resilience (age : Nat) (failed : Bool)
    (h : servesStale defaultDns age failed = true) :
    servesStale fortifiedDns age failed = true := by
  simp [default_never_serves_stale age failed] at h

/-- And it is a strict widening, not a no-op: an outage four minutes into a 30-second
entry's life is covered by the fortified policy and not by the default. Four minutes is
the length of the longer outage actually in the log. -/
theorem fortification_covers_the_measured_outage :
    servesStale defaultDns 240 true = false ∧ servesStale fortifiedDns 240 true = true := by
  decide

/-- The knob is the only difference: positive and negative TTLs are untouched, so nothing
about healthy resolution changes. -/
theorem fortification_changes_only_the_stale_knob :
    fortifiedDns.positive = defaultDns.positive ∧
      fortifiedDns.negative = defaultDns.negative ∧ defaultDns.stale < fortifiedDns.stale := by
  decide

#guard servesStale defaultDns 240 true == false
#guard servesStale fortifiedDns 240 true == true
#guard servesStale fortifiedDns 240 false == false      -- healthy DNS: never stale
#guard servesStale fortifiedDns 20 true == false        -- entry not yet expired
#guard servesStale fortifiedDns 3631 true == false      -- past the bound, failure surfaces
#guard adequate shippedJre.provided measuredDeps == true
#guard (measuredDeps.filter (fun d => d.requirement == Requirement.optional)).length == 2
#guard (measuredDeps.filter (fun d => d.requirement == Requirement.mandatory)).length == 10
#guard shippedJre.provided.length == 23
#guard canLoad shippedJre.feature appClassMajor == true

end CtbrecSpec
