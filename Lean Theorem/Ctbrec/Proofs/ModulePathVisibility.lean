/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: why a class that IS in the jar can still be invisible at runtime.

THE DEFECT THIS ENCODES (measured 2026-08-13, and it cost the Socio two days of blank tabs).

ctbrec.exe launches with `--module-path lib -classpath "ctbrec-26.7.11.jar;.;lib\common-26.7.11.jar"`.
`lib/common-26.7.11.jar` already contained `ctbrec/preview/PreviewPipeline*`, so the package
`ctbrec.preview` is OWNED by that automatic module. CP161 added `PreviewVolumeBus`,
`PreviewVolumeState` and `ProcessDiagnostics` to the APP jar only. Result, reproduced three ways
with the app's own JRE:

  -cp app.jar                                     -> class FOUND
  -cp app.jar;.;lib/common.jar                    -> class FOUND
  --module-path lib --add-modules javafx.* + same  -> ClassNotFoundException

and at runtime, on the JavaFX thread, every single thumbnail died:

  NoClassDefFoundError: ctbrec/preview/PreviewVolumeBus
    at ThumbCell.createVolumeButton(ThumbCell.java:1128)
    at ThumbCell.<init>(ThumbCell.java:317)

Models arrived (fetch logged http=200 rooms=91 models=91) and NOTHING rendered. After moving the
three classes into the owning jar: `tab 'Female' rendered: fetched=103 afterFilter=103
cellsInGrid=103`.

THE POINT OF THE MODEL: "the class is in a jar on the classpath" is NOT the property that makes it
loadable. The load-bearing property is "the class is in the jar that owns its package". The theorem
`the_classpath_copy_is_worthless_when_the_package_is_owned` is that distinction, and
`adding_a_class_to_a_module_can_hide_a_classpath_class` is the trap stated as a fact rather than as
folklore.

NOTHING here names a version, a jar filename or a class name: those move. Today's measured shape is
pinned in `#guard`s at the bottom, which are expected to change and which no theorem depends on.
-/

namespace CtbrecSpec.ModulePathVisibility

/-- A package and a class name, both opaque: nothing depends on what they ARE. -/
abbrev Pkg := Nat

structure Cls where
  pkg : Pkg
  name : Nat
  deriving DecidableEq, Repr

/-- A jar is just the set of classes it carries. -/
abbrev Jar := List Cls

/-- A package is OWNED by the module path when any module-path jar defines a class in it. -/
def owns (mp : List Jar) (p : Pkg) : Bool :=
  mp.any (fun j => j.any (fun c => c.pkg == p))

def carries (js : List Jar) (c : Cls) : Bool :=
  js.any (fun j => j.any (fun d => d == c))

/--
Resolution as the JVM performs it for the application loader: when a named module defines the
package, the request goes to that module and the unnamed module (the classpath) is not consulted.
-/
def visible (cp : List Jar) (mp : List Jar) (c : Cls) : Bool :=
  if owns mp c.pkg then carries mp c else carries cp c || carries mp c

/--
THE CP161 DEFECT, as a theorem. Once the package is owned, a copy on the classpath does not help —
which is why "I verified the class is in the app jar" was a true statement and a useless one.
-/
theorem the_classpath_copy_is_worthless_when_the_package_is_owned
    (cp mp : List Jar) (c : Cls) (hown : owns mp c.pkg = true) (hmiss : carries mp c = false) :
    visible cp mp c = false := by
  unfold visible
  rw [if_pos (by simpa using hown)]
  exact hmiss

/-- The repair: putting the class in the owning module makes it visible, whatever the classpath holds. -/
theorem a_class_in_the_owning_module_is_visible
    (cp mp : List Jar) (c : Cls) (hcarry : carries mp c = true) :
    visible cp mp c = true := by
  unfold visible
  cases hown : owns mp c.pkg with
  | true => simpa using hcarry
  | false => simp [hcarry]

/-- Where no module owns the package, the classpath still works — so the model is not overclaiming. -/
theorem an_unowned_package_still_resolves_from_the_classpath
    (cp mp : List Jar) (c : Cls) (hown : owns mp c.pkg = false) (hcp : carries cp c = true) :
    visible cp mp c = true := by
  unfold visible
  rw [if_neg (by simp [hown])]
  simp [hcp]

/--
THE TRAP, stated as a fact. Adding one class to a module-path jar can make a package owned and
thereby HIDE classes that were resolving fine from the classpath. This is how the defect was
introduced without anyone touching the affected classes: `PreviewPipeline` moving into the common
jar is what made `ctbrec.preview` owned.
-/
theorem adding_a_class_to_a_module_can_hide_a_classpath_class :
    ∃ (cp mp : List Jar) (extra c : Cls),
      visible cp mp c = true ∧ visible cp (mp ++ [[extra]]) c = false := by
  refine ⟨[[⟨7, 1⟩]], [], ⟨7, 2⟩, ⟨7, 1⟩, ?_, ?_⟩
  · simp [visible, owns, carries]
  · simp [visible, owns, carries]

/-- Adding classes to the owning module never hides a class that module already carries. -/
theorem adding_to_the_owning_module_never_hides_its_own_class
    (cp mp : List Jar) (extra : Jar) (c : Cls) (hcarry : carries mp c = true) :
    visible cp (mp ++ [extra]) c = true := by
  have h : carries (mp ++ [extra]) c = true := by
    unfold carries at hcarry ⊢
    simp only [List.any_append]
    simp [hcarry]
  exact a_class_in_the_owning_module_is_visible cp (mp ++ [extra]) c h

/-- A package with no classes anywhere is owned by nobody: `owns` cannot be vacuously true. -/
theorem an_empty_module_path_owns_nothing (p : Pkg) : owns [] p = false := by
  simp [owns]

/-! ### The mutation target: the check a build script would naively perform -/

/-- "Is the class in ANY jar?" — the naive check, which passed while the app was broken. -/
def presentAnywhere (cp mp : List Jar) (c : Cls) : Bool :=
  carries cp c || carries mp c

/--
The naive check and the real one DISAGREE exactly on the defect: `presentAnywhere` said yes while
the JVM said no. A checker built on `presentAnywhere` is a green light on a broken app.
-/
theorem the_naive_presence_check_misses_the_defect :
    ∃ (cp mp : List Jar) (c : Cls),
      presentAnywhere cp mp c = true ∧ visible cp mp c = false := by
  refine ⟨[[⟨7, 1⟩]], [[⟨7, 2⟩]], ⟨7, 1⟩, ?_, ?_⟩
  · simp [presentAnywhere, carries]
  · simp [visible, owns, carries]

/-! ## Today's measured shape — `#guard` only, expected to change, depended on by nothing

Model of the three jars as measured: package 0 = `ctbrec.preview`, class 0 = PreviewPipeline,
1 = PreviewVolumeBus, 2 = PreviewVolumeState, 3 = ProcessDiagnostics.
-/

def pkgPreview : Pkg := 0
def pipeline : Cls := ⟨pkgPreview, 0⟩
def volumeBus : Cls := ⟨pkgPreview, 1⟩
def volumeState : Cls := ⟨pkgPreview, 2⟩
def diagnostics : Cls := ⟨pkgPreview, 3⟩

/-- The app jar as CP161 left it. -/
def appJarBefore : Jar := [pipeline, volumeBus, volumeState, diagnostics]

/-- The module-path jar as CP161 left it: it owned the package but lacked three classes. -/
def commonJarBefore : Jar := [pipeline]

/-- After the repair. -/
def commonJarAfter : Jar := [pipeline, volumeBus, volumeState, diagnostics]

-- the defect, executable
#guard visible [appJarBefore] [commonJarBefore] volumeBus == false
#guard visible [appJarBefore] [commonJarBefore] volumeState == false
#guard visible [appJarBefore] [commonJarBefore] diagnostics == false
-- ... while the naive check was perfectly happy, which is why it went unnoticed
#guard presentAnywhere [appJarBefore] [commonJarBefore] volumeBus == true
-- the repair
#guard visible [appJarBefore] [commonJarAfter] volumeBus == true
#guard visible [appJarBefore] [commonJarAfter] volumeState == true
#guard visible [appJarBefore] [commonJarAfter] diagnostics == true
-- the class that always worked, before and after
#guard visible [appJarBefore] [commonJarBefore] pipeline == true
#guard owns [commonJarBefore] pkgPreview == true
#guard owns [] pkgPreview == false

end CtbrecSpec.ModulePathVisibility
