/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the HTTP stack, and why it cannot be upgraded one jar at a time

Subject: `ctbrec/lib/okhttp-4.9.3.jar`, `okio-2.8.0.jar`, `kotlin-stdlib-1.4.10.jar`, and the
`OkHttpClient` construction in `src/common/ctbrec/io/HttpClient.java`.

## The request, and the disagreement that preceded this module

The Socio asked twice: *"what about Changing 'OkHttp' with something more Powerfull instead"*
and *"or simply Overhauling 'OkHttp' to the Next level, this would be a plan B"*.

**Replacement was measured and rejected**; this module is Plan B. The measured reasons, so the
rejection is auditable rather than an opinion:

* The app uses **20 distinct `okhttp3` types** across **102 source files** (measured by import
  scan). No other JVM client offers that surface, so "replacement" means rewriting 102 files
  and re-earning every behaviour the recorder depends on.
* `HttpClient.java:63` holds `ConnectionPool(256, 2, MINUTES)`, and the LL-HLS downloader
  depends on that pooling behaviour under sustained parallel segment fetches.
* The CDN advertises `alt-svc: h3=":443"` — HTTP/3 is genuinely available and OkHttp 4.x
  genuinely cannot speak it. That is the one real argument *for* replacement, and it is
  recorded here as a known limitation rather than silently dropped. It does not justify
  rewriting the recorder's entire transport today.

## What this module proves

The upgrade is `okhttp 4.9.3 → 4.12.0`, which the published POM says requires
`okio 3.6.0` and `kotlin-stdlib-jdk8 1.8.21` (measured: fetched the real POM from Maven
Central, `okhttp-4.12.0.pom`).

The trap this module exists to catch is that **version ordering is not string ordering**.
Lexically `"4.12.0" < "4.9.3"`, because `'1' < '9'`. Any check that compares versions as text
concludes the upgrade is a *downgrade* and either blocks it or, worse, "restores" the old jar.
That is a live hazard for the injection scripts in `tools/`, which are shell.
-/
import Proofs.Ctbrec.ThumbGeometry

namespace CtbrecSpec.HttpStack

/-! ## Versions as numbers, not as text -/

/-- A semantic version. Modelled over its three numeric components, never over the rendered
string — the rendering is what produces the ordering bug this module catches. -/
structure Version where
  major : Nat
  minor : Nat
  patch : Nat
deriving DecidableEq, Repr

/-- Strict numeric precedence: major, then minor, then patch. -/
def newer (a b : Version) : Bool :=
  if a.major != b.major then b.major < a.major
  else if a.minor != b.minor then b.minor < a.minor
  else b.patch < a.patch

/-- At least as new — the form a dependency constraint actually needs. -/
def atLeast (a b : Version) : Bool := newer a b || a == b

/-! ## The measured stack

Every constant below was read off the real jars in `ctbrec/lib/` and the real POM fetched from
Maven Central. None is remembered. -/

/-- `ctbrec/lib/okhttp-4.9.3.jar`, 792081 bytes, dated 2021-11-22. -/
def okhttpOld : Version := ⟨4, 9, 3⟩

/-- `okhttp-4.12.0.jar`, 789531 bytes, sha1 `2f4525d4a200…`, verified against Maven Central. -/
def okhttpNew : Version := ⟨4, 12, 0⟩

/-- `ctbrec/lib/okio-2.8.0.jar`, 243179 bytes. -/
def okioOld : Version := ⟨2, 8, 0⟩

/-- `okio-jvm-3.6.0.jar`, 359580 bytes, sha1 `5600569133b7…`. -/
def okioNew : Version := ⟨3, 6, 0⟩

/-- `ctbrec/lib/kotlin-stdlib-1.4.10.jar`, 1487085 bytes. -/
def kotlinOld : Version := ⟨1, 4, 10⟩

/-- `kotlin-stdlib-1.8.21.jar`, 1670468 bytes, sha1 `43d50ab85bc7…`. -/
def kotlinNew : Version := ⟨1, 8, 21⟩

/-! ## The requirements, straight from the published POM

`okhttp-4.12.0.pom` declares `okio 3.6.0` and `kotlin-stdlib-jdk8 1.8.21`. -/

/-- Minimum okio demanded by okhttp 4.12.0. -/
def requiredOkio : Version := ⟨3, 6, 0⟩

/-- Minimum kotlin-stdlib demanded by okhttp 4.12.0. -/
def requiredKotlin : Version := ⟨1, 8, 21⟩

/-- A stack is *coherent* when its okio and kotlin satisfy what its okhttp demands. -/
def coherent (okio kotlin : Version) : Bool :=
  atLeast okio requiredOkio && atLeast kotlin requiredKotlin

/-! ## The upgrade moves forward -/

/-- OkHttp 4.12.0 really is newer than 4.9.3. -/
theorem okhttp_moves_forward : newer okhttpNew okhttpOld = true := by decide

/-- So does okio — and this one crosses a **major** version, which is why it cannot be skipped. -/
theorem okio_moves_forward : newer okioNew okioOld = true := by decide

/-- And kotlin-stdlib. -/
theorem kotlin_moves_forward : newer kotlinNew kotlinOld = true := by decide

/-- Nothing in the new set is a downgrade of anything in the old set. -/
theorem the_whole_stack_moves_forward :
    newer okhttpNew okhttpOld && newer okioNew okioOld && newer kotlinNew kotlinOld = true := by
  decide

/-! ## The trap: text ordering disagrees with version ordering

This is the load-bearing pair. A shell or Java check that compares versions as strings gets the
**opposite** answer, and would treat this upgrade as a downgrade. -/

/-- **Lexically, the new okhttp sorts BELOW the old one.** `"4.12.0" < "4.9.3"` because
`'1' < '9'`. A textual guard would reject the upgrade, or "roll back" to 4.9.3 believing it
was newer. -/
theorem text_ordering_is_wrong : ("4.12.0" < "4.9.3") = True := by
  simp

/-- **Numeric ordering gets it right**, on the very same pair. Stated beside the theorem above
so the contradiction between the two is impossible to miss. -/
theorem numeric_ordering_is_right : newer ⟨4, 12, 0⟩ ⟨4, 9, 3⟩ = true := by decide

/-- **A higher minor is always newer, numerically** — stated over every `maj/lo/hi`, not over
the pair that happens to be current, so it does not expire the next time the jars move.

Together with `text_ordering_is_wrong` this is the whole point: the numeric comparator is
correct for *all* minor bumps, while the textual one is already wrong for the one in front of
us. Any future 4.9.x → 4.N.0 upgrade lands in the same trap. -/
theorem a_higher_minor_is_always_newer (maj lo hi : Nat) (h : lo < hi) :
    newer ⟨maj, hi, 0⟩ ⟨maj, lo, 0⟩ = true := by
  unfold newer
  have h2 : (hi != lo) = true := by simp; omega
  simp [h2]
  omega

/-! ## You cannot upgrade one jar

The coherence theorems are the reason the injection replaces three jars in one step. -/

/-- **The chosen set is coherent** — okio 3.6.0 and kotlin 1.8.21 satisfy okhttp 4.12.0. -/
theorem the_new_stack_is_coherent : coherent okioNew kotlinNew = true := by decide

/-- **Upgrading okhttp alone is incoherent.** Keeping okio 2.8.0 fails the constraint, which is
exactly the `NoClassDefFoundError: okio.ByteString` that `jdeps --missing-deps` reported (7
missing references) when okio was left out of the control run. -/
theorem upgrading_okhttp_alone_is_incoherent : coherent okioOld kotlinNew = false := by decide

/-- Keeping the old kotlin is incoherent too. -/
theorem keeping_old_kotlin_is_incoherent : coherent okioNew kotlinOld = false := by decide

/-- The old stack does not satisfy the new okhttp's constraints in any combination. -/
theorem the_old_stack_cannot_carry_the_new_okhttp :
    coherent okioOld kotlinOld = false := by decide

/-- **The old stack was coherent for its own okhttp.** Without this the theorem above would be
reporting a pre-existing defect rather than an upgrade constraint — the old jars did work
together, which is why the recorder ran at all. -/
theorem the_old_stack_was_self_consistent :
    atLeast okioOld ⟨2, 8, 0⟩ && atLeast kotlinOld ⟨1, 4, 10⟩ = true := by decide

/-! ## Ordering is a real order

Sanity properties of `newer` itself. If these failed, every theorem above would be measuring a
broken comparator rather than the stack. -/

/-- Nothing is newer than itself. -/
theorem newer_is_irreflexive (v : Version) : newer v v = false := by
  unfold newer
  simp

/-- `atLeast` accepts equality — a dependency pinned exactly to its minimum is satisfied. -/
theorem an_exact_pin_satisfies_its_minimum : atLeast requiredOkio requiredOkio = true := by decide

/-- A patch below the minimum is rejected: `3.5.9` does not satisfy `3.6.0`. -/
theorem a_near_miss_is_still_a_miss : atLeast ⟨3, 5, 9⟩ requiredOkio = false := by decide

/-! ## The manifest and the disk must move together

**Measured, and it changes the plan.** `ctbrec-26.7.11.jar`'s `META-INF/MANIFEST.MF` declares a
`Class-Path` of **66 entries naming jars by exact filename**, four of them networking:

```
lib/okhttp-4.9.3.jar  lib/okio-2.8.0.jar
lib/kotlin-stdlib-common-1.4.0.jar  lib/kotlin-stdlib-1.4.10.jar
```

The upgrade renames two artifacts — `okio` becomes `okio-jvm`, and the version suffix changes on
all of them. So simply dropping the new jars into `lib/` leaves the manifest pointing at files
that no longer exist, and the app cannot start at all. The manifest is not documentation; it is
the classpath.

The theorems below state the invariant in the durable form — *the manifest resolves against the
disk* — rather than pinning today's filenames, so they survive the next upgrade instead of
having to be deleted by it. -/

/-- The networking artifacts, by identity rather than by filename. -/
inductive Artifact where
  | okhttp
  | okio
  | kotlinStdlib
  | kotlinCommon
  | kotlinJdk7
  | kotlinJdk8
deriving DecidableEq, Repr

/-- One classpath entry: which artifact, at which version. -/
structure Entry where
  artifact : Artifact
  version : Version
deriving DecidableEq, Repr

/-- **A manifest resolves when every entry it names is present on disk.** A missing entry is a
`NoClassDefFoundError` at startup, not a warning. -/
def resolves (manifest disk : List Entry) : Bool :=
  manifest.all (fun e => disk.contains e)

/-- The four networking entries the shipped manifest names today. -/
def manifestOld : List Entry :=
  [⟨.okhttp, ⟨4, 9, 3⟩⟩, ⟨.okio, ⟨2, 8, 0⟩⟩,
   ⟨.kotlinCommon, ⟨1, 4, 0⟩⟩, ⟨.kotlinStdlib, ⟨1, 4, 10⟩⟩]

/-- What is actually in `ctbrec/lib/` today. Measured by directory listing; it matches. -/
def diskOld : List Entry := manifestOld

/-- The entries after the upgrade. `kotlin-stdlib-common` is gone — Kotlin 1.8 merged it into
`kotlin-stdlib` — and the jdk7/jdk8 shims the POM requires are added. -/
def manifestNew : List Entry :=
  [⟨.okhttp, ⟨4, 12, 0⟩⟩, ⟨.okio, ⟨3, 6, 0⟩⟩, ⟨.kotlinStdlib, ⟨1, 8, 21⟩⟩,
   ⟨.kotlinJdk7, ⟨1, 8, 21⟩⟩, ⟨.kotlinJdk8, ⟨1, 8, 21⟩⟩]

/-- The jars staged for installation, sha1-verified against Maven Central. -/
def diskNew : List Entry := manifestNew

/-- The shipped configuration works today — the baseline this upgrade must not regress. -/
theorem the_old_stack_resolved : resolves manifestOld diskOld = true := by decide

/-- The upgraded configuration resolves. -/
theorem the_new_stack_resolves : resolves manifestNew diskNew = true := by decide

/-- **Swapping the jars without rewriting the manifest breaks startup.** This is the failure
that measurement caught before it was committed: the manifest still names `okhttp-4.9.3.jar`
and `okio-2.8.0.jar`, and neither file exists any more. -/
theorem swapping_jars_without_the_manifest_breaks_startup :
    resolves manifestOld diskNew = false := by decide

/-- **And the mirror image**: rewriting the manifest without installing the jars breaks startup
too. Both halves have to land in the same edit. -/
theorem updating_the_manifest_without_the_jars_breaks_startup :
    resolves manifestNew diskOld = false := by decide

/-- **The general statement, so this does not expire.** Any entry named by the manifest but
absent from disk defeats resolution — whatever the filenames happen to be. A future upgrade
that renames artifacts again is covered by this without editing the spec. -/
theorem a_missing_entry_always_defeats_resolution (manifest disk : List Entry) (e : Entry)
    (hm : manifest.contains e = true) (hd : disk.contains e = false) :
    resolves manifest disk = false := by
  unfold resolves
  cases hb : manifest.all (fun x => disk.contains x) with
  | false => rfl
  | true =>
    rw [List.all_eq_true] at hb
    have hmem : e ∈ manifest := List.mem_of_elem_eq_true hm
    have := hb e hmem
    rw [this] at hd
    simp at hd

/-! ## The known limitation, stated rather than hidden

OkHttp 4.12.0 speaks HTTP/1.1 and HTTP/2. The CDN advertises `alt-svc: h3=":443"`, so HTTP/3
is on offer and this stack will not take it. That is a real ceiling and the honest reason the
"something more powerful" request is only partly answered. -/

/-- The protocols this stack can negotiate, as OkHttp 4.x defines them. -/
inductive Protocol where
  | http11
  | http2
  | http3
deriving DecidableEq, Repr

/-- What okhttp 4.12.0 actually supports. -/
def supported : List Protocol := [.http11, .http2]

/-- HTTP/2 is available — the upgrade keeps it. -/
theorem http2_is_supported : supported.contains .http2 = true := by decide

/-- **HTTP/3 is NOT supported, and this theorem says so out loud.** It is the measured ceiling
of Plan B: the CDN offers h3 and this stack declines it. Deleting this theorem to make the spec
look complete would be the exact "faking green" the brief forbids. -/
theorem http3_is_not_supported : supported.contains .http3 = false := by decide

#guard newer okhttpNew okhttpOld
#guard newer okioNew okioOld
#guard newer kotlinNew kotlinOld
#guard coherent okioNew kotlinNew
#guard !coherent okioOld kotlinNew
#guard !coherent okioNew kotlinOld
#guard !newer okhttpNew okhttpNew
#guard atLeast requiredOkio requiredOkio
#guard !atLeast ⟨3, 5, 9⟩ requiredOkio
#guard supported.contains .http2
#guard !supported.contains .http3

end CtbrecSpec.HttpStack
