/-
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-/

/-!
# A mutation that did not land is EVIDENCE ABOUT THE HARNESS, not about the check

Every mutation harness in this repository answers one question: *is this
assertion load-bearing?* It breaks the thing on purpose, re-runs the assertion,
and records whether the assertion noticed.

There are **three** outcomes, and collapsing them into two is how a mutation
suite lies in the reassuring direction.

    KILLED     the patch applied, and the assertion REJECTED the result
               -> the assertion is load-bearing on this mutation
    SURVIVED   the patch applied, and the assertion ACCEPTED the result
               -> the assertion is blind to this mutation
    DISCARDED  the patch never applied
               -> NOTHING WAS TESTED. This says something about the harness
                  and nothing whatever about the assertion.

`DISCARDED` reads like `KILLED` on a summary line and means the opposite of
both. A harness that cannot tell them apart reports "62 mutants, 62 killed"
while testing 61 of them, or none.

## Measured, twice, on 2026-08-01 — both routes into the same false green

**Route 1 — the patch changes nothing.** `checker/verdict-stability.sh` mutated
a `git commit` line that a redesign had deleted. `sed` matched nothing and wrote
the file back byte-identically. The harness compared mutant to original, saw no
difference and reported *did not apply — discarded, not survived*. That is the
correct behaviour and it turned the gate red, which is how the defect surfaced.

**Route 2 — the patch destroys everything.** The replacement control's `sed`
program was malformed. `sed` exited non-zero and wrote an **empty** file. Empty
is *different* from the original, so the "did it change anything" test passed it
through; the assertion then rejected the empty file for lacking every structure
it requires; and the harness printed **PASS** next to a visible
`sed: unterminated 's' command`. A patch that destroyed the file was scored as
evidence that the check works.

Route 1 was already handled. Route 2 was not, and no amount of re-running found
it — it *looked* green. The difference between the two is one line of shell and
one line of reasoning, and this module is the reasoning.

## What is modelled

A mutant is characterised by three observables the shell harness really has:
the patch tool's exit status, whether the output is empty, and whether the
output differs from the original. `classify` maps those to an outcome, and
`accepts` is the assertion under test. Nothing here models *what* the patch did
— it does not need to. The claim is about **when a result may be counted**, and
that is decidable from the three observables alone.

The theorems are deliberately stated over ALL inputs rather than over the two
cases that were measured: a spec that named today's two bugs would be green
today and useless against the third route.
-/

namespace RotMoE

/-- What a single mutation run is allowed to conclude. -/
inductive Outcome where
  /-- The patch applied and the assertion rejected the result. -/
  | killed : Outcome
  /-- The patch applied and the assertion accepted the result. -/
  | survived : Outcome
  /-- The patch never applied. Nothing about the assertion was tested. -/
  | discarded : Outcome
  deriving DecidableEq, Repr

/-- The three observables a shell harness actually has after running its patch
tool: the tool's exit status, whether the produced file is empty, and whether it
differs from the original. -/
structure Run where
  /-- Exit status of the patch tool (`sed`, `perl`, an AST edit). 0 is success. -/
  toolExit : Nat
  /-- Is the produced mutant empty? An empty file is never a legitimate mutant
  of a non-empty source. -/
  empty : Bool
  /-- Does the produced mutant differ from the original? -/
  changed : Bool
  deriving DecidableEq, Repr

/-- A patch LANDED only if the tool succeeded, the result is non-empty, and it
actually differs from the original. All three are required: dropping any one of
them is precisely a defect that shipped. -/
def landed (r : Run) : Bool :=
  r.toolExit == 0 && !r.empty && r.changed

/-- The classification. `accepts` is the verdict of the assertion under test on
the mutated input — `true` means the assertion was happy with the broken file.

The order matters and is the whole point: whether the patch landed is decided
**before** the assertion's opinion is consulted. An assertion's verdict on a
file that was never validly produced carries no information. -/
def classify (r : Run) (accepts : Bool) : Outcome :=
  if landed r then (if accepts then Outcome.survived else Outcome.killed)
  else Outcome.discarded

/-- A mutation may be counted as evidence about the assertion only when it
landed. -/
def counts (o : Outcome) : Bool :=
  o != Outcome.discarded

/-! ## The theorems -/

/-- **The central claim.** If the patch did not land, the outcome is `discarded`
— whatever the assertion said about the wreckage. This is the statement that
route 1 and route 2 both violate, and it is quantified over every `accepts`, so
it cannot be satisfied by a harness that merely happens to be right today. -/
theorem not_landed_discarded (r : Run) (accepts : Bool) (h : landed r = false) :
    classify r accepts = Outcome.discarded := by
  simp [classify, h]

/-- A failing patch tool can never produce a kill. This is route 2 exactly:
`sed` exited 1, and the harness printed a pass. -/
theorem tool_failed_never_killed (r : Run) (accepts : Bool) (h : r.toolExit ≠ 0) :
    classify r accepts ≠ Outcome.killed := by
  have : landed r = false := by
    simp [landed, beq_iff_eq, h]
  simp [classify, this]

/-- An empty mutant can never produce a kill, even when the tool reported
success. `sed` can exit 0 and still write nothing. -/
theorem empty_never_killed (r : Run) (accepts : Bool) (h : r.empty = true) :
    classify r accepts ≠ Outcome.killed := by
  have : landed r = false := by simp [landed, h]
  simp [classify, this]

/-- An unchanged file can never produce a kill. This is route 1: the `sed`
matched nothing, so the "mutant" is the original and the assertion's verdict on
it is a statement about the ORIGINAL, not about any mutation. -/
theorem unchanged_never_killed (r : Run) (accepts : Bool) (h : r.changed = false) :
    classify r accepts ≠ Outcome.killed := by
  have : landed r = false := by simp [landed, h]
  simp [classify, this]

/-- Nothing that failed to land is ever counted. -/
theorem discarded_never_counts (r : Run) (accepts : Bool) (h : landed r = false) :
    counts (classify r accepts) = false := by
  simp [counts, not_landed_discarded r accepts h]

/-- **The converse, and it is what stops this spec being vacuous.** When the
patch really landed, the outcome follows the assertion and is always counted. A
"safe" harness that discarded everything would satisfy every theorem above and
test nothing; this forbids it. -/
theorem landed_counts (r : Run) (accepts : Bool) (h : landed r = true) :
    counts (classify r accepts) = true := by
  cases accepts <;> simp [counts, classify, h]

/-- A landed patch the assertion REJECTS is a kill — the only way to earn one. -/
theorem landed_rejected_killed (r : Run) (h : landed r = true) :
    classify r false = Outcome.killed := by
  simp [classify, h]

/-- A landed patch the assertion ACCEPTS is a survivor, never silently a kill.
This is the direction that keeps a harness honest about its blind spots. -/
theorem landed_accepted_survived (r : Run) (h : landed r = true) :
    classify r true = Outcome.survived := by
  simp [classify, h]

/-- `killed` requires ALL THREE landing conditions. Stated as one theorem
because a harness that checks two of the three is exactly what shipped: the
original `ctl` tested `changed` alone, which is why an empty file passed. -/
theorem killed_implies_all_three (r : Run) (accepts : Bool)
    (h : classify r accepts = Outcome.killed) :
    r.toolExit = 0 ∧ r.empty = false ∧ r.changed = true := by
  by_cases hl : landed r = true
  · have h3 : (r.toolExit == 0) = true ∧ (!r.empty) = true ∧ r.changed = true := by
      simpa [landed, Bool.and_eq_true, and_assoc] using hl
    exact ⟨by simpa using h3.1, by simpa using h3.2.1, h3.2.2⟩
  · rw [classify, if_neg hl] at h
    exact absurd h (by decide)

/-- The three outcomes are genuinely distinct. Without this the whole
distinction could collapse and every theorem above would still elaborate. -/
theorem outcomes_distinct :
    Outcome.killed ≠ Outcome.survived ∧
    Outcome.killed ≠ Outcome.discarded ∧
    Outcome.survived ≠ Outcome.discarded := by
  refine ⟨?_, ?_, ?_⟩ <;> decide

/-! ## Executable witnesses

The theorems are over all `Run`s; these run the definitions on the two failures
actually measured on 2026-08-01, so the model is pinned to the events rather
than floating free of them. `#guard` fails the build if any disagrees. -/

/-- Route 2, measured: `sed` exited 1 and wrote an empty file. The assertion
rejected that empty file (`accepts = false`), and the old harness called it a
kill. The model says `discarded`. -/
def route2 : Run := { toolExit := 1, empty := true, changed := true }
#guard classify route2 false = Outcome.discarded
#guard counts (classify route2 false) = false

/-- Route 1, measured: `sed` succeeded but matched nothing, so the mutant was
byte-identical to the original. -/
def route1 : Run := { toolExit := 0, empty := false, changed := false }
#guard classify route1 false = Outcome.discarded

/-- A real, landed mutation that the assertion caught — the only shape that may
be reported as a kill. -/
def landedKill : Run := { toolExit := 0, empty := false, changed := true }
#guard classify landedKill false = Outcome.killed
#guard counts (classify landedKill false) = true

-- The same landed mutation when the assertion is blind to it.
#guard classify landedKill true = Outcome.survived

-- EXHAUSTIVE: over every combination of the three observables and both
-- assertion verdicts, `killed` occurs only where all three landing conditions
-- hold. A decidable check over the whole finite space, not a sample.
#guard
  (List.range 2).all fun e =>
    [true, false].all fun em =>
      [true, false].all fun ch =>
        [true, false].all fun acc =>
          let r : Run := { toolExit := e, empty := em, changed := ch }
          (classify r acc == Outcome.killed) == (e == 0 && !em && ch && !acc)


/-! ## The CLASSIFIER: which files owe mutation discipline at all

`checker/mutant-discipline.sh` enforces the theorems above against every
mutation harness in the tree. To do that it must first decide **which files are
harnesses**, and it decides that by behaviour rather than from a list — a list
stops covering whatever is added after it is written.

The predicate is a conjunction of two observations about a file:

  * it PATCHES — a text tool (`sed -i`, `perl -0pi`, or `sed`/`awk`/`perl`
    redirected into a file) writes a modified copy;
  * it ADJUDICATES — it reports the outcome of a mutation run.

MEASURED DEFECT, 2026-08-05. The second observation was spelled
`killed|survived|discard|CONTROL`, and `CONTROL` is the word every well-written
checker in this repository uses for its negative control. So the moment
`checker/install-parity.sh` built its control with

    sed '$d' plugin.txt > plugin.short.txt

it was classified as a mutation harness and failed for missing
`discard-reporting` — a discipline with no meaning in a checker that never
produces a mutant. `checker/workflow-lint.sh` fell the same way.

A rule that fails a correct script is a defect in the rule. The repair drops
`CONTROL` from the adjudication test, and this section is why that is a
CLASSIFIER REPAIR rather than a relaxation: `discipline_applies_to_every_kill`
proves that no file which reports a kill can escape, whatever else it says.
Measured alongside: 17 files selected before, 15 after, and the two dropped are
exactly the two named above. -/

/-- What the classifier can observe about a file, one Bool per grep. -/
structure FileEvidence where
  /-- a text tool writes a patched copy (`sed -i`, `perl -0pi`, `… > "file"`) -/
  patches : Bool
  /-- the word `killed` appears -/
  saysKilled : Bool
  /-- the word `survived` appears -/
  saysSurvived : Bool
  /-- the word `discard` appears -/
  saysDiscard : Bool
  /-- the word `CONTROL` appears — true of nearly every checker here -/
  saysControl : Bool
  deriving DecidableEq, Repr

/-- The shipped classifier, after the repair. -/
def isHarness (f : FileEvidence) : Bool :=
  f.patches && (f.saysKilled || f.saysSurvived || f.saysDiscard)

/-- The classifier as it stood before the repair. -/
def isHarnessLoose (f : FileEvidence) : Bool :=
  f.patches && (f.saysKilled || f.saysSurvived || f.saysDiscard || f.saysControl)

/-- THE PROPERTY THAT MAKES THE REPAIR SAFE.

Any file that patches and reports a kill is still selected. This is the
invariant the discipline actually needs — stated over every `FileEvidence`, not
over the 15 files that happen to exist today, so it cannot expire when a
sixteenth harness is added. -/
theorem discipline_applies_to_every_kill (f : FileEvidence)
    (hp : f.patches = true) (hk : f.saysKilled = true) :
    isHarness f = true := by
  simp [isHarness, hp, hk]

/-- The same for a file that reports survivors, and for one that reports
discards. A harness may legitimately report only one of the three. -/
theorem discipline_applies_to_every_survivor (f : FileEvidence)
    (hp : f.patches = true) (hs : f.saysSurvived = true) :
    isHarness f = true := by
  simp [isHarness, hp, hs]

theorem discipline_applies_to_every_discard (f : FileEvidence)
    (hp : f.patches = true) (hd : f.saysDiscard = true) :
    isHarness f = true := by
  simp [isHarness, hd, hp]

/-- THE REPAIR IS A NARROWING, NEVER A WIDENING.

Everything the new classifier selects, the old one selected too. So no file that
was under discipline yesterday escaped it today — the change can only have
removed false positives. -/
theorem repair_only_narrows (f : FileEvidence) (h : isHarness f = true) :
    isHarnessLoose f = true := by
  simp only [isHarness, Bool.and_eq_true] at h
  simp [isHarnessLoose, h.1, h.2]

/-- And it is a STRICT narrowing: the two forms genuinely disagree, on exactly
the shape that was misclassified — a file that patches, carries a control, and
never adjudicates a mutation. Without this the repair could have been a no-op
dressed up as a fix. -/
theorem repair_is_not_vacuous :
    ∃ f : FileEvidence, isHarnessLoose f = true ∧ isHarness f = false := by
  refine ⟨{ patches := true, saysKilled := false, saysSurvived := false,
            saysDiscard := false, saysControl := true }, ?_, ?_⟩ <;> decide

/-- A CONTROL IS NOT AN ADJUDICATION. Stated on its own because it is the whole
content of the defect: carrying a negative control must never, by itself, put a
file under mutation discipline. -/
theorem a_control_alone_is_not_a_harness (p : Bool) :
    isHarness { patches := p, saysKilled := false, saysSurvived := false,
                saysDiscard := false, saysControl := true } = false := by
  cases p <;> decide

/-- Nothing that fails to patch is a harness, however it talks. -/
theorem no_patch_no_discipline (f : FileEvidence) (h : f.patches = false) :
    isHarness f = false := by
  simp [isHarness, h]

/-! ### The two files measured on 2026-08-05 -/

/-- `checker/install-parity.sh`: writes `plugin.short.txt` with `sed`, carries a
negative control, never reports a kill. -/
def installParityEvidence : FileEvidence :=
  { patches := true, saysKilled := false, saysSurvived := false,
    saysDiscard := false, saysControl := true }

/-- A real suite, e.g. `lean/mutate/mutate_rotinstall.sh`. -/
def realSuiteEvidence : FileEvidence :=
  { patches := true, saysKilled := true, saysSurvived := true,
    saysDiscard := true, saysControl := true }

#guard isHarnessLoose installParityEvidence = true
#guard isHarness installParityEvidence = false
#guard isHarness realSuiteEvidence = true
#guard isHarnessLoose realSuiteEvidence = true

-- EXHAUSTIVE over all 32 evidence shapes: the repaired classifier and the loose
-- one differ on exactly those files that patch, carry a control, and adjudicate
-- nothing. Not a sample — the whole space.
#guard
  [true, false].all fun p =>
    [true, false].all fun k =>
      [true, false].all fun s =>
        [true, false].all fun d =>
          [true, false].all fun c =>
            let f : FileEvidence :=
              { patches := p, saysKilled := k, saysSurvived := s,
                saysDiscard := d, saysControl := c }
            (isHarnessLoose f != isHarness f) == (p && c && !k && !s && !d)

/-! ## RESTORE — "a backup exists" is not "a backup can restore"

MEASURED 2026-08-06, by following this repository's own advice.

A `gate-all` run was killed by a wall-clock ceiling while a mutation suite had a
mutant applied. The roll-up refused to proceed and printed its recovery
instruction: *"Restore each file from its backup (`cp <f>.mutbak <f>`), delete
the backups, and re-run."*

Done literally, that left `hooks/prover-remind.sh` and `hooks/prover-remind.ps1`
at **zero bytes** — and the backups were deleted in the same breath, so the only
surviving copy was git's. Three gates went red with every measurement returning
the empty string.

The mistake is not clumsiness, it is a **conflated proposition**. `find` proves
a backup *exists*. Restoring needs it to be *non-empty*, and a suite killed
between creating `<f>.mutbak` and writing content into it satisfies the first
and fails the second. `cp` from an empty source **destroys the target and exits
0** — a destructive operation that reports success, which is the same shape as a
fake green.

This section proves the distinction the shell now implements. -/

/-- A file, as a restore cares about it: how many bytes it carries. -/
structure Artifact where
  bytes : Nat
  deriving DecidableEq, Repr

/-- A backup **exists** if there is a file at the backup path at all. This is
what `find` answers, and it is the weaker of the two questions. -/
def existsOnDisk (_b : Artifact) : Bool := true

/-- A backup **can restore** only if it carries content. -/
def canRestore (b : Artifact) : Bool := b.bytes != 0

/-- Copying `b` over `f`. The result is `b`, whatever `b` was. -/
def restoreByCopy (_f b : Artifact) : Artifact := b

/-- Restoring from version control. Modelled as producing the committed
artifact, which is **independent of `b`** — that is the entire point. -/
def restoreFromGit (committed : Artifact) (_f _b : Artifact) : Artifact :=
  committed

/-- A restore is **safe** when it does not reduce the file to nothing. Written
in pure `Bool` rather than a coerced implication so that it EXECUTES: the
`#guard`s below are the same statement run on the measured sizes. -/
def restoreIsSafe (before after : Artifact) : Bool :=
  (before.bytes == 0) || (after.bytes != 0)

/-- **Existence does not imply restorability.** The two predicates come apart on
the empty backup, which is exactly the artifact a killed suite leaves. If this
were false the shell could keep using `find` alone. -/
theorem existence_is_not_restorability :
    ∃ b : Artifact, existsOnDisk b = true ∧ canRestore b = false :=
  ⟨⟨0⟩, rfl, by decide⟩

/-- **Copying from an empty backup DESTROYS a non-empty file.** The measured
defect, stated over an arbitrary file rather than the two it happened to. -/
theorem empty_backup_restore_is_destructive (f : Artifact) (h : 0 < f.bytes) :
    (restoreByCopy f ⟨0⟩).bytes = 0 ∧ restoreIsSafe f (restoreByCopy f ⟨0⟩) = false := by
  constructor
  · rfl
  · simp [restoreIsSafe, restoreByCopy]; omega

/-- **Copying is safe exactly when the backup passes `canRestore`.** So the size
check is not belt-and-braces: it is precisely the side condition. -/
theorem copy_is_safe_iff_backup_nonempty (f b : Artifact) :
    restoreIsSafe f (restoreByCopy f b) = true ↔ (0 < f.bytes → canRestore b = true) := by
  simp only [restoreIsSafe, restoreByCopy, canRestore, Bool.or_eq_true,
             beq_iff_eq, bne_iff_ne, ne_eq]
  omega

/-- **Git restores whatever was committed, no matter what the backup looks
like.** This is why the advice now leads with `git checkout`: the recovery path
does not depend on an artifact produced by the very kill being recovered from. -/
theorem git_restore_ignores_the_backup (committed f b b' : Artifact) :
    restoreFromGit committed f b = restoreFromGit committed f b' := rfl

/-- **Git restore is total on a non-empty commit** — safe for every file and
every backup, including the empty one. Contrast with
`empty_backup_restore_is_destructive`, which needs no hypothesis to fail. -/
theorem git_restore_is_total (committed : Artifact) (hc : 0 < committed.bytes)
    (f b : Artifact) :
    restoreIsSafe f (restoreFromGit committed f b) = true := by
  simp [restoreIsSafe, restoreFromGit]; omega

/-- **The orderings differ, and that is the whole recommendation.** There is a
state — empty backup, non-empty commit — in which `git` is safe and `cp` is not.
Without this the two advices would be interchangeable and the change to
`gate-all.sh` would be cosmetic. -/
theorem git_strictly_safer_on_the_measured_state :
    ∃ (committed f b : Artifact),
      restoreIsSafe f (restoreFromGit committed f b) = true ∧
      restoreIsSafe f (restoreByCopy f b) = false :=
  ⟨⟨29107⟩, ⟨29107⟩, ⟨0⟩, by decide, by decide⟩

-- The two hooks, at their measured sizes. `cp` from the 0-byte backup erases
-- both; `git checkout` returns them.
#guard (restoreByCopy ⟨29107⟩ ⟨0⟩).bytes == 0        -- prover-remind.sh
#guard (restoreByCopy ⟨23611⟩ ⟨0⟩).bytes == 0        -- prover-remind.ps1
#guard (restoreFromGit ⟨29107⟩ ⟨0⟩ ⟨0⟩).bytes == 29107
#guard !restoreIsSafe ⟨29107⟩ (restoreByCopy ⟨29107⟩ ⟨0⟩)
#guard restoreIsSafe ⟨29107⟩ (restoreFromGit ⟨29107⟩ ⟨0⟩ ⟨0⟩)

-- A NON-empty backup is a fine repair -- the rule is about size, not about
-- backups being untrustworthy in general. Without this the law would be
-- over-strict and someone would relax it wholesale.
#guard restoreIsSafe ⟨29107⟩ (restoreByCopy ⟨29107⟩ ⟨29107⟩)

/-! ## §N A KILL NEEDS EVIDENCE THAT THE VERIFIER RAN

Everything above is about the PATCH: whether the mutant was validly produced.
The defect below is one step later and slipped straight past it, because the
patch landed perfectly.

MEASURED in CI run 31180174433 (2026-08-07), green the whole cycle.
`mutate_rotgauge.sh` wrote its build logs to a hard-coded `/d/tmp/mut` — a
Windows drive path. On the Linux runner:

```
mkdir: cannot create directory '/d': Permission denied
mutate_rotgauge.sh: line 128: /d/tmp/mut/M01.log: No such file or directory
M01  KILLED     exit=1  MODULE DEAD
```

When a redirection target cannot be opened, **bash does not run the command**
and returns 1. The suite read that 1 as "the build went red" and recorded a
kill. All twelve mutants were scored KILLED on a runner where `lake` never ran
once, and the job passed. Twelve fake kills, published as evidence.

So the harness needs a fourth observable, and it is not about the patch: did
the verifier actually produce anything? -/

/-- What the harness observes after running the verifier. -/
structure Verify where
  /-- The status the harness read after invoking the build. -/
  buildExit : Nat
  /-- Did the build produce a log at all? `false` means the process never ran:
  a refused redirection, a missing toolchain, a killed process. -/
  producedLog : Bool
  deriving DecidableEq, Repr

/-- A verdict is attributable only when the verifier left evidence behind. -/
def attributable (v : Verify) : Bool := v.producedLog

/-- The rule the suites now implement: the patch must have landed, the verifier
must have RUN, and only then does its exit status mean anything. -/
def classifyBuild (r : Run) (v : Verify) : Outcome :=
  if !landed r then Outcome.discarded
  else if !attributable v then Outcome.discarded
  else if v.buildExit == 0 then Outcome.survived
  else Outcome.killed

/-- The rule that shipped: read the exit status and believe it. -/
def naiveClassifyBuild (r : Run) (v : Verify) : Outcome :=
  if !landed r then Outcome.discarded
  else if v.buildExit == 0 then Outcome.survived
  else Outcome.killed

/-- The exact CI shape: a patch that landed, a build that never ran, status 1. -/
def ciRun : Run := { toolExit := 0, empty := false, changed := true }
/-- …and the verifier observation that went with it. -/
def ciVerify : Verify := { buildExit := 1, producedLog := false }

/-- **The false kill, reproduced.** The shipped rule calls it a kill; the
repaired rule discards it. This is the twelve-fold defect in one line. -/
theorem naive_rule_manufactures_a_kill :
    naiveClassifyBuild ciRun ciVerify = Outcome.killed
    ∧ classifyBuild ciRun ciVerify = Outcome.discarded := by
  constructor <;> rfl

/-- **The general guarantee**, not merely the one case: if the verifier left no
evidence, no run is ever scored killed — whatever the patch did and whatever
status was read. -/
theorem unattributable_is_never_killed (r : Run) (v : Verify)
    (h : v.producedLog = false) : classifyBuild r v ≠ Outcome.killed := by
  unfold classifyBuild attributable
  by_cases hl : landed r
  · simp [hl, h]
  · simp [hl]

/-- And the converse direction, so the rule is not merely cautious: a kill
carries all three facts with it. A theorem that only forbade kills would be
satisfied by a harness that never kills anything. -/
theorem killed_carries_its_evidence (r : Run) (v : Verify)
    (h : classifyBuild r v = Outcome.killed) :
    landed r = true ∧ v.producedLog = true ∧ v.buildExit ≠ 0 := by
  unfold classifyBuild attributable at h
  by_cases hl : landed r
  · by_cases hp : v.producedLog
    · by_cases he : v.buildExit == 0
      · simp [hl, hp, he] at h
      · refine ⟨hl, hp, ?_⟩
        simpa using he
    · simp [hl, hp] at h
  · simp [hl] at h

/-- Non-vacuity: the repaired rule still kills. A guard that discarded
everything would satisfy the theorem above and prove nothing. -/
theorem a_real_kill_survives_the_new_guard :
    classifyBuild ciRun { buildExit := 1, producedLog := true } = Outcome.killed := by
  rfl

/-- And it still recognises a survivor. -/
theorem a_survivor_is_still_a_survivor :
    classifyBuild ciRun { buildExit := 0, producedLog := true } = Outcome.survived := by
  rfl

/-- Exhaustive over every observable combination the harness can present, with
the exit status bounded. **The two rules agree exactly when the patch did not
land or the verifier left evidence** — and nowhere else.

The first form of this theorem carried a third disjunct, `be.val = 0`, on the
assumption that a zero status was harmless. `decide` refuted it, which is the
whole reason the statement is exhaustive rather than argued: when the patch
landed and no evidence exists, the shipped rule reports **survived** on a build
that never ran, and that verdict is exactly as unfounded as the twelve kills.
Only the kills were noticed because only they were flattering. -/
theorem rules_differ_exactly_on_missing_evidence
    (te be : Fin 4) (emp chg log : Bool) :
    let r : Run := { toolExit := te.val, empty := emp, changed := chg }
    let v : Verify := { buildExit := be.val, producedLog := log }
    (classifyBuild r v = naiveClassifyBuild r v)
      ↔ (landed r = false ∨ log = true) := by
  revert te be emp chg log
  decide

/-- The unfounded SURVIVOR, stated on its own so it cannot be forgotten: with no
evidence and a zero status, the shipped rule declares the theorem robust. -/
theorem naive_rule_also_manufactures_a_survivor :
    naiveClassifyBuild ciRun { buildExit := 0, producedLog := false }
      = Outcome.survived
    ∧ classifyBuild ciRun { buildExit := 0, producedLog := false }
      = Outcome.discarded := by
  constructor <;> rfl

end RotMoE
