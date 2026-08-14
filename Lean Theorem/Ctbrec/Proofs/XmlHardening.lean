/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — what an XML parser is allowed to do on behalf of a remote document

Subject: `src/common/ctbrec/io/XmlParserUtils.java` (the only XML parser construction site in the
tree) and the two JAXB call sites, `recorder/download/dash/DashDownload.java:366` and
`sites/mfc/DashStreamSourceProvider.java:42`.

## The measurement

`tools/XmlHardeningCheck.java` writes a canary file, hands the parser a document whose `DOCTYPE`
names that file by `file:` URI, and reads back the element the entity expands into. Against the
version that shipped, all four surfaces returned the canary: `parse(String)`,
`getStringWithXpath`, `getNodeWithXpath`, `getNodeListWithXpath`.

`tools/XmlGuardMatrix.java` then measured **all sixteen** combinations of the four guards that
matter, on both parser surfaces the application uses. The table below is that measurement, not an
inference from documentation:

| guards set | DOM | SAX |
|---|---|---|
| none | **leaks** | **leaks** |
| `noExpandEntityReferences` only | stopped | **leaks** |
| any of doctype / general / secure | stopped | stopped |

Two facts fall out, and both contradict what this module asserted before the matrix was run:

1. **`secureProcessing` alone closes the channel.** The first version of `stops` listed only
   `disallowDoctype` and `noExternalGeneralEntities`, so the executable control that removed
   exactly those two did **not** reopen the leak — and reported PASS. The control was green
   because the model was wrong, which is the reassuring direction, the dangerous one.
2. **`noExpandEntityReferences` hides the result without closing the channel.** It stops the DOM
   text reaching the caller and does nothing on SAX. A guard that suppresses evidence is not a
   guard, and only the two-surface matrix could tell the difference.

## A claim withdrawn

This module previously called the entity expansion "unbounded". Measured: three levels of a
ten-fold entity yields 10 000 characters **with `secureProcessing` either on or off**, and five
levels is refused — the JDK enforces its own 64 000 entity-expansion limit regardless. So the
honest statement is a thousand-fold amplification *within* the JDK's limit, and the only guard
here that refuses it outright is rejecting the `DOCTYPE`
(`only_rejecting_the_doctype_refuses_the_expansion`).

## What is NOT claimed

`XmlParserUtils` has **no callers** — measured, zero references in `src`. This is not a live
vulnerability and is not reported as one. The two JAXB sites cannot run either, for a second and
independent reason: only `jaxb-api-2.3.1.jar` ships, with no implementation, so
`JAXBContext.newInstance` throws `Implementation of JAXB-API has not been found` (measured,
`tools/XxeProbe.java`). `DashDownload` has zero references, `DashStreamSourceProvider` is never
constructed, and `MyFreeCamsModel:107` always returns the HLS provider.

`serverSideRequest` below is the one row that was **not** executed — pointing an entity at
`http:` was not run against a live listener. It is modelled conservatively: the guards that were
measured to close the file channel are credited, and `noExpandEntityReferences` is not, because
suppressing the result cannot prevent a request. Conservative in the safe direction, and labelled
rather than presented as measured.

## Why the fix is the implication, not the fact

"`XmlParserUtils` has no callers" is exactly the shape of spec this project has been burned by
twice: a **contingent** fact, true today, that a correct future change falsifies. Wiring the DASH
path up is legitimate work, and a spec asserting zero callers would go red on it — inviting
whoever hits that red to delete the check.

So nothing here asserts unreachability. What is stated, and what the checker enforces, is
`safe reachable cfg = ¬reachable ∨ hardened cfg`: the repaired configuration is safe **however it
is wired**, while the shipped one was safe only while nobody called it. The dual obligation is
that the repair must not disarm anything — a DASH manifest carries no `DOCTYPE`, and
`hardening_costs_nothing_on_benign_documents` says such documents are accepted exactly as before.
-/

namespace CtbrecSpec

/-- A JAXP switch, named for the SAFE setting. -/
inductive Guard where
  /-- `disallow-doctype-decl = true` — reject any document carrying a `DOCTYPE`. -/
  | disallowDoctype
  /-- `external-general-entities = false`. -/
  | noExternalGeneralEntities
  /-- `external-parameter-entities = false`. -/
  | noExternalParameterEntities
  /-- `load-external-dtd = false`. -/
  | noLoadExternalDtd
  /-- `FEATURE_SECURE_PROCESSING = true`. Measured to deny external access outright on this JDK,
  which is more than the name suggests. -/
  | secureProcessing
  /-- `setXIncludeAware(false)`. -/
  | noXInclude
  /-- `setExpandEntityReferences(false)` — DOM only. Measured to hide the result rather than
  close the channel. -/
  | noExpandEntityReferences
  deriving DecidableEq, Repr

/-- Every guard the repair sets. -/
def allGuards : List Guard :=
  [.disallowDoctype, .noExternalGeneralEntities, .noExternalParameterEntities,
   .noLoadExternalDtd, .secureProcessing, .noXInclude, .noExpandEntityReferences]

/-- The four the matrix varied; the other three are set as well but were not the question. -/
def measuredGuards : List Guard :=
  [.disallowDoctype, .noExternalGeneralEntities, .secureProcessing, .noExpandEntityReferences]

/-- A parser configuration is the set of guards actually set. -/
structure Config where
  set : List Guard
  deriving DecidableEq, Repr

def on (c : Config) (g : Guard) : Bool := c.set.contains g

/-- The two parser surfaces the application uses. They are guarded differently, which is the
single most important thing the matrix established. -/
inductive ParserSurface where
  /-- `DocumentBuilderFactory` — `parse` and every XPath entry point. -/
  | dom
  /-- `SAXParserFactory` — the reader handed to JAXB by `hardenedSource`. -/
  | sax
  deriving DecidableEq, Repr

def allParserSurfaces : List ParserSurface := [.dom, .sax]

/-- What a hostile document can attempt. -/
inductive Attack where
  /-- `<!ENTITY xxe SYSTEM "file:///…">` — read a local file. Measured on both surfaces. -/
  | readLocalFile
  /-- The same entity pointed at `http:`. NOT executed; modelled conservatively. -/
  | serverSideRequest
  /-- A thousand-fold entity amplification inside the JDK's own limit. Measured. -/
  | entityExpansion
  deriving DecidableEq, Repr

def allAttacks : List Attack := [.readLocalFile, .serverSideRequest, .entityExpansion]

/-- **The measured semantics.** Every disjunct here is a row of `XmlGuardMatrix`, and that tool
fails the build if the JDK stops agreeing with this function on any of the sixteen
configurations. -/
def stopsOn (c : Config) (s : ParserSurface) : Attack → Bool
  | .readLocalFile =>
      on c .disallowDoctype || on c .noExternalGeneralEntities || on c .secureProcessing
        || (s == ParserSurface.dom && on c .noExpandEntityReferences)
  | .serverSideRequest =>
      -- `secureProcessing` is deliberately NOT credited here. It was measured to close the
      -- `file:` fetch on both surfaces, and the same mechanism plausibly covers `http:` -- but
      -- plausibly is not measured, and crediting a guard is a claim that the app is SAFER.
      -- Withholding the credit is the conservative direction: it forces the repair to set a
      -- fetch guard rather than rely on this one. A mutation crediting it dies against
      -- `the_request_channel_is_modelled_conservatively`.
      on c .disallowDoctype || on c .noExternalGeneralEntities
  | .entityExpansion => on c .disallowDoctype

/-- Hardened = every channel closed on every surface. -/
def hardened (c : Config) : Bool :=
  allParserSurfaces.all (fun s => allAttacks.all (stopsOn c s))

/-- The shipped configuration: `DocumentBuilderFactory.newInstance()` with nothing set. -/
def shipped : Config := ⟨[]⟩

/-- The repair: every guard. -/
def repaired : Config := ⟨allGuards⟩

/-- **The model agrees with the measurement on the shipped configuration**: every channel open,
on both surfaces. The probe returned the canary on all four entry points. -/
theorem the_shipped_config_stops_nothing :
    allParserSurfaces.all (fun s => allAttacks.all (fun a => stopsOn shipped s a = false)) := by decide

theorem the_shipped_config_is_not_hardened : hardened shipped = false := by decide

theorem the_repair_is_hardened : hardened repaired = true := by decide

/-- **Suppressing the result is not closing the channel.** With `noExpandEntityReferences` as the
only guard, the DOM surface is stopped and SAX still leaks — measured, row 9 of the matrix. This
is the theorem that would have caught the first version of this module, whose control removed two
guards, left `secureProcessing` and this one in place, and reported PASS. -/
theorem hiding_the_result_is_not_closing_the_channel :
    stopsOn ⟨[.noExpandEntityReferences]⟩ ParserSurface.dom Attack.readLocalFile = true ∧
    stopsOn ⟨[.noExpandEntityReferences]⟩ ParserSurface.sax Attack.readLocalFile = false := by decide

/-- **Three guards each close the file-read channel on their own**, on both surfaces. Any one of
them would have sufficed; the repair sets all of them because losing one to a future edit must
not reopen anything. -/
theorem three_guards_each_close_the_read_alone :
    [Guard.disallowDoctype, Guard.noExternalGeneralEntities, Guard.secureProcessing].all
      (fun g => allParserSurfaces.all (fun s => stopsOn ⟨[g]⟩ s Attack.readLocalFile)) = true := by
  decide

/-- **The file-read channel opens only when all three are gone.** Stated as an iff over every
configuration, so it is the general law and not a statement about the four configurations that
happened to be tried. -/
theorem the_read_reopens_exactly_when_all_three_are_gone (c : Config) :
    stopsOn c ParserSurface.sax Attack.readLocalFile = false ↔
      (on c .disallowDoctype = false ∧ on c .noExternalGeneralEntities = false ∧
       on c .secureProcessing = false) := by
  simp [stopsOn, and_assoc]

/-- **The file-read channel survives losing any single guard.** Quantified over every guard, which
is why the executable control has to strip three at once: a one-line control would report a false
green. -/
theorem the_read_survives_losing_any_single_guard :
    allGuards.all (fun g =>
      allParserSurfaces.all (fun s => stopsOn ⟨allGuards.erase g⟩ s Attack.readLocalFile)) = true := by
  decide

/-- **Only rejecting the `DOCTYPE` refuses the amplification.** Measured: three levels produced
10 000 characters with `secureProcessing` both on and off, so no other guard here touches it.
This is the one place the repair has no depth, and saying so is the point. -/
theorem only_rejecting_the_doctype_refuses_the_expansion (c : Config) (s : ParserSurface) :
    stopsOn c s Attack.entityExpansion = true ↔ on c .disallowDoctype = true := by
  simp [stopsOn]

/-- …so the repair does **not** survive losing that one guard, and the previous version of this
module claimed it did. The claim was false because the model had `secureProcessing` bounding the
expansion; it does not. -/
theorem dropping_the_doctype_rejection_reopens_the_expansion :
    hardened ⟨allGuards.erase Guard.disallowDoctype⟩ = false := by decide

/-- **The request channel is modelled conservatively.** `secureProcessing` closes the measured
`file:` channel but is not credited for `http:`, which was never executed. So a configuration
carrying only that guard counts as NOT stopping the request — the model claims less protection
than the JDK probably gives, which is the direction an unmeasured guess is allowed to err in. -/
theorem the_request_channel_is_modelled_conservatively :
    stopsOn ⟨[.noExternalGeneralEntities]⟩ ParserSurface.sax Attack.serverSideRequest = true ∧
    stopsOn ⟨[.secureProcessing]⟩ ParserSurface.sax Attack.serverSideRequest = false := by decide

/-- **Why checking both surfaces is not what makes `hardened` strong.** A mutation that checked
only the DOM surface SURVIVED the whole suite, and correctly: the expansion channel is closed
only by rejecting the `DOCTYPE`, and that guard closes every other channel on every surface, so
`hardened` is *equal* to its DOM-only form. Recording the equivalence rather than inventing a
theorem to kill an equivalent mutant — a survivor that is genuinely equivalent is information,
not a hole. The surface distinction earns its keep in
`hiding_the_result_is_not_closing_the_channel`, which is about one channel rather than all. -/
theorem the_expansion_channel_dominates (c : Config) :
    hardened c = allAttacks.all (stopsOn c ParserSurface.dom) := by
  cases h : on c Guard.disallowDoctype <;>
    simp [hardened, allParserSurfaces, allAttacks, stopsOn, h]

/-- A document, as far as the guards are concerned. Real DASH manifests are `usesDoctype = false`:
the MPEG-DASH schema has no `DOCTYPE`. -/
structure Doc where
  usesDoctype : Bool
  deriving DecidableEq, Repr

/-- A configuration rejects a document only for carrying a `DOCTYPE`. -/
def parserAccepts (c : Config) (d : Doc) : Bool := !(on c .disallowDoctype && d.usesDoctype)

/-- **Anti-amputation: hardening costs nothing on the documents the app actually parses.**
Without this the repair could satisfy every theorem above by refusing everything. Quantified over
all documents without a `DOCTYPE`, not over the one manifest that was tested. -/
theorem hardening_costs_nothing_on_benign_documents (d : Doc) (h : d.usesDoctype = false) :
    parserAccepts repaired d = parserAccepts shipped d := by
  simp [parserAccepts, h]

/-- …and the parser is not disarmed in general: something is still accepted. -/
theorem the_hardened_parser_still_parses : parserAccepts repaired ⟨false⟩ = true := by decide

/-- **The durable safety law.** A parse surface is safe when it is unreachable *or* hardened. The
whole point of stating it this way is that the left disjunct is contingent and the right is not. -/
def safe (reachable : Bool) (c : Config) : Bool := !reachable || hardened c

/-- **The repair is safe however it is wired.** Whoever connects `XmlParserUtils` to a caller —
legitimate work — inherits the guarantee instead of breaking a spec. -/
theorem the_repair_is_safe_however_it_is_wired (reachable : Bool) :
    safe reachable repaired = true := by
  cases reachable <;> decide

/-- **The shipped configuration was safe only by accident.** One line wiring up a caller turns it
unsafe, and no theorem about today's call graph would have said so. -/
theorem the_shipped_config_is_safe_only_while_unreachable :
    safe false shipped = true ∧ safe true shipped = false := by decide

/-- A subsystem needs a runtime on the classpath as well as a parser configuration. -/
structure Subsystem where
  /-- Reachable from production code. -/
  wired : Bool
  /-- An implementation of the API is on the classpath. -/
  runtime : Bool
  cfg : Config
  deriving DecidableEq, Repr

def subsystemUsable (s : Subsystem) : Bool := s.wired && s.runtime

def subsystemSafe (s : Subsystem) : Bool := safe s.wired s.cfg

/-- DASH as shipped: unreferenced, and with no JAXB implementation to run on. -/
def dashAsShipped : Subsystem := { wired := false, runtime := false, cfg := shipped }

/-- **DASH is blocked twice over.** Naming both matters: repairing either alone leaves it dead, so
a future change that wires it up without shipping a runtime produces a `JAXBException` on a user's
machine rather than a working manifest parse. -/
theorem dash_is_blocked_twice_over :
    subsystemUsable dashAsShipped = false ∧ dashAsShipped.wired = false ∧
      dashAsShipped.runtime = false := by decide

/-- **Wiring it up without a runtime changes nothing.** Quantified over every subsystem, so it
holds for whatever the DASH path becomes. -/
theorem no_runtime_means_not_usable (s : Subsystem) (h : s.runtime = false) :
    subsystemUsable s = false := by
  simp [subsystemUsable, h]

/-- **Wiring it up without hardening is provably unsafe**, which is what makes the checker's
requirement a guarantee rather than a style preference. -/
theorem wiring_dash_with_the_shipped_config_is_unsafe :
    subsystemSafe { dashAsShipped with wired := true } = false := by decide

/-- …and wiring it up with the repair is not. -/
theorem wiring_dash_with_the_repair_is_safe :
    subsystemSafe { dashAsShipped with wired := true, cfg := repaired } = true := by decide

#guard hardened shipped == false
#guard hardened repaired == true
#guard hardened ⟨[Guard.disallowDoctype]⟩ == true
#guard hardened ⟨[Guard.secureProcessing]⟩ == false
#guard stopsOn shipped ParserSurface.dom Attack.readLocalFile == false
#guard stopsOn ⟨[Guard.noExpandEntityReferences]⟩ ParserSurface.dom Attack.readLocalFile == true
#guard stopsOn ⟨[Guard.noExpandEntityReferences]⟩ ParserSurface.sax Attack.readLocalFile == false
#guard stopsOn ⟨[Guard.secureProcessing]⟩ ParserSurface.sax Attack.readLocalFile == true
#guard stopsOn repaired ParserSurface.sax Attack.entityExpansion == true
#guard safe true shipped == false
#guard safe true repaired == true
#guard subsystemUsable dashAsShipped == false
#guard parserAccepts repaired ⟨false⟩ == parserAccepts shipped ⟨false⟩

end CtbrecSpec
