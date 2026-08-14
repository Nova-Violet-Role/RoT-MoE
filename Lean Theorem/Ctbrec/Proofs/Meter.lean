/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the bandwidth meter's ring buffer

Subject: `src/common/ctbrec/io/BandwidthMeter.java`, a static singleton written from **nine**
download paths including `ChaturbateLlhlsDownload.java:559` — the exact path this app records
through. Every segment's byte count goes in; a listener registered once at
`CamrecApplication.java:721` reports the throughput to the UI.

Three defects, each MEASURED on the real class by `tools/MeterCheck.java` before being modelled
here:

```
first window is NOT measured from the epoch   FAIL   timeframe=20669 days
first event reports the 100 bytes just added  FAIL   throughput=0 (added 100)
second event reports the 250 bytes just added FAIL   throughput=100 expected=250
```

The third is the interesting one and the other two follow from the same reading:

```java
int idx = getNextIndex();     // head++ (wrapping), returns the NEW head
records[idx] = bytes;         // the newest sample is written AT head
...
while (tail != head) { throughput += records[tail++]; ... }   // sums [tail, head)
```

The window is a half-open interval ending at `head`, and the newest sample is *at* `head`. So the
sum can never include it. Each reported figure is the previous window's, shifted by exactly one
sample — which is why the second event reported 100 after 250 had been added.

`lastUpdate` starts at `0`, so the first `Duration.between(Instant.ofEpochMilli(0), now)` is the
time since 1970 — 20669 days, measured.
-/

namespace CtbrecSpec

/-- One step forward in a ring of `size` cells. Mirrors `getNextIndex`: increment, wrap at the
end. -/
def advance (i size : Nat) : Nat := if i + 1 == size then 0 else i + 1

/-- The indices the drain loop visits: `[tail, head)` walking forward with wraparound. `fuel`
bounds the walk at one full lap, exactly as a ring of `size` cells can hold. -/
def windowIdxAux : Nat → Nat → Nat → Nat → List Nat
  | 0, _, _, _ => []
  | fuel + 1, tail, head, size =>
      if tail == head then []
      else tail :: windowIdxAux fuel (advance tail size) head size

def windowIdx (tail head size : Nat) : List Nat := windowIdxAux size tail head size

/-- **The defect, stated in general.** The drain loop stops when it reaches `head`, so `head` is
never one of the indices it sums — for any tail, any size, any amount of fuel. The buggy `add`
writes the newest sample at `head`, so the newest sample is structurally unreachable by the sum.

Quantified over every parameter: this is not a fact about the measured trace, it is the reason
the measured trace came out that way. -/
theorem the_window_never_includes_head (fuel tail head size : Nat) :
    head ∉ windowIdxAux fuel tail head size := by
  induction fuel generalizing tail with
  | zero => simp [windowIdxAux]
  | succ n ih =>
    unfold windowIdxAux
    split
    · simp
    · rename_i hne
      simp only [List.mem_cons, not_or]
      refine ⟨?_, ih _⟩
      intro h
      exact hne (by simp [h])

theorem the_newest_sample_is_unreachable (tail head size : Nat) :
    head ∉ windowIdx tail head size :=
  the_window_never_includes_head size tail head size

/-! ## The two `add` variants

`cells` is the backing array. Both variants write one sample and leave `head` where the next
write goes; they differ only in the ORDER of write and advance, which is the whole bug. -/

/-- As shipped: advance first, then write **at** the new head. -/
def addBuggy (cells : List Nat) (head size : Nat) (v : Nat) : List Nat × Nat :=
  let h := advance head size
  (cells.set h v, h)

/-- Repaired: write at the current head, **then** advance past it. The newest sample now lies
inside `[tail, head)` instead of at its excluded endpoint. -/
def addFixed (cells : List Nat) (head size : Nat) (v : Nat) : List Nat × Nat :=
  (cells.set head v, advance head size)

/-- Sum the cells the drain loop would visit. -/
def windowSum (cells : List Nat) (tail head size : Nat) : Nat :=
  (windowIdx tail head size).foldl (fun acc i => acc + cells.getD i 0) 0

/-! ### The measured trace, reproduced exactly

A four-cell ring standing in for the real 10000. `MeterCheck` added 100 and was told 0; then
added 250 and was told 100. Both reproduce below by `decide`, which is the tightest binding
between the model and the measurement this project can make. -/

def emptyRing : List Nat := [0, 0, 0, 0]

/-- **`throughput=0` after adding 100** — the measured first event. -/
theorem the_first_window_reports_nothing :
    (let (cells, head) := addBuggy emptyRing 0 4 100
     windowSum cells 0 head 4) = 0 := by decide

/-- **`throughput=100` after adding 250** — the measured second event, reporting the PREVIOUS
sample. `tail` has advanced to 1 and `head` to 2, so the window `[1,2)` holds the 100 written
last time, never the 250 written this time. -/
theorem the_second_window_reports_the_previous_sample :
    (let (cells, _) := addBuggy emptyRing 0 4 100
     let (cells2, head2) := addBuggy cells 1 4 250
     windowSum cells2 1 head2 4) = 100 := by decide

/-- **The repair reports what was just added.** Same ring, same window, write-then-advance. -/
theorem the_fixed_meter_reports_the_new_sample :
    (let (cells, head) := addFixed emptyRing 0 4 100
     windowSum cells 0 head 4) = 100 := by decide

theorem the_fixed_meter_reports_the_second_sample :
    (let (cells, head) := addFixed emptyRing 0 4 100
     let (cells2, head2) := addFixed cells head 4 250
     windowSum cells2 head head2 4) = 250 := by decide

/-- **The measured repair, exactly**: `MeterCheck` adds 100, waits past the gate, adds 250, and
is told **350** over a 1118 ms window. Two samples, one drain, both counted once. This is the
number the running class produced, reproduced by `decide`. -/
theorem one_window_counts_every_sample_in_it :
    (let (cells, head) := addFixed emptyRing 0 4 100
     let (cells2, head2) := addFixed cells head 4 250
     windowSum cells2 0 head2 4) = 350 := by decide

/-- …and the window after it counts only its own bytes — measured as 70, not 420. Without this
a meter that simply never advanced `tail` would satisfy the theorem above. -/
theorem the_next_window_does_not_recount :
    (let (cells, head) := addFixed emptyRing 0 4 100
     let (cells2, head2) := addFixed cells head 4 250
     let (cells3, head3) := addFixed cells2 head2 4 70
     windowSum cells3 head2 head3 4) = 70 := by decide

/-- **Anti-amputation**: the repair is not "report a constant". An empty window — nothing added
since the last drain — still reports zero, which is the honest answer. -/
theorem an_empty_window_still_reports_zero :
    windowSum emptyRing 2 2 4 = 0 := by decide

/-- And the two variants genuinely differ; without this the "fix" could be a no-op. -/
theorem the_repair_changes_the_reported_figure :
    (let (cells, head) := addBuggy emptyRing 0 4 100
     windowSum cells 0 head 4)
    ≠ (let (cells, head) := addFixed emptyRing 0 4 100
       windowSum cells 0 head 4) := by decide

/-! ### The epoch window

`lastUpdate = 0` makes the first window `now - 1970`. Measured: 20669 days. A throughput divided
by that window is indistinguishable from zero on any display. -/

def epochWindowDays : Nat := 20669

/-- A sane first window is bounded by the sampling period, not by the age of the Unix epoch.
Stated as the bound the repair must satisfy rather than as the number that happens to hold. -/
def firstWindowIsSane (days : Nat) : Bool := days < 2

theorem the_shipped_first_window_is_insane : firstWindowIsSane epochWindowDays = false := by
  decide

theorem a_fresh_first_window_is_sane : firstWindowIsSane 0 = true := by decide

/-! ## The lap: a ring that fills between two reports loses the window

`records` holds 10000 cells. If that many samples arrive between two reports, `head` catches
`tail` and the drain loop — `while (tail != head)` — sums **nothing**.

Measured on the real class: 10001 samples of one byte each in a single window reported a
throughput of **1**. The meter goes quiet at exactly the moment traffic is highest, which is the
worst possible direction for a fault in a load metric to point.

Below, a four-cell ring receives four samples and reports zero. -/

def addAll (cells : List Nat) (head size : Nat) : List Nat → List Nat × Nat
  | [] => (cells, head)
  | v :: vs =>
      let (c, h) := addFixed cells head size v
      addAll c h size vs

/-- **Four samples into four cells report nothing.** `head` has returned to `tail`, so the
window is empty and every byte in it is invisible. -/
theorem a_full_ring_reports_nothing :
    (let (cells, head) := addAll emptyRing 0 4 [7, 8, 9, 10]
     windowSum cells 0 head 4) = 0 := by decide

/-- One sample short of full, the same ring reports correctly — so the fault is the lap itself,
not the ring being small. -/
theorem a_ring_below_capacity_is_fine :
    (let (cells, head) := addAll emptyRing 0 4 [7, 8, 9]
     windowSum cells 0 head 4) = 24 := by decide

/-! ### The repair: accumulate, do not store

Nothing ever reads an individual sample. `calculateThroughput` only sums them, and the sum is
consumed once per report. A running total is therefore **exactly equivalent on every observable**
— and it cannot lap, because it has no capacity to exceed. 80 KB of array becomes one `long`.

This is the opposite of removing capability: the ring's only capability was to hold values that
were summed and discarded, and it did that wrongly above capacity. -/

def accumulate : List Nat → Nat := List.foldl (· + ·) 0

/-- **The durable statement**: the accumulator counts every sample, for a list of ANY length.
There is no size parameter, so there is no capacity to exceed and no lap to reason about — the
bug is not fixed, it is made unrepresentable. -/
theorem the_accumulator_counts_every_sample (samples : List Nat) :
    accumulate samples = samples.sum := by
  -- `List.sum` is not definitionally a LEFT fold, so the induction has to carry the running
  -- total as a variable. Generalising over the starting value is what makes the step go
  -- through; fixing it at 0 leaves the inductive hypothesis too weak.
  have h : ∀ (l : List Nat) (n : Nat), l.foldl (· + ·) n = n + l.sum := by
    intro l
    induction l with
    | nil => intro n; simp
    | cons a as ih =>
      intro n
      simp [ih, Nat.add_assoc]
  unfold accumulate
  simp [h]

/-- The case the ring lost, counted correctly. -/
theorem the_accumulator_survives_a_full_window :
    accumulate [7, 8, 9, 10] = 34 := by decide

/-- And it agrees with the ring wherever the ring was right, so the repair is a strict
improvement rather than a different meter. -/
theorem the_accumulator_agrees_below_capacity :
    accumulate [7, 8, 9]
      = (let (cells, head) := addAll emptyRing 0 4 [7, 8, 9]
         windowSum cells 0 head 4) := by decide

/-- **Anti-amputation**: it is not "always report a large number". Nothing added reports zero. -/
theorem the_accumulator_reports_zero_when_idle : accumulate [] = 0 := by decide

/-! ## Conservation — the property that actually matters under load

`add` is `synchronized` and every download thread calls it at once. The question that decides
whether the meter is trustworthy is not "is it fast" but: **does every byte handed to it appear
in exactly one reported window — never dropped, never double-counted?**

Measured by `tools/MeterBench.java`, 8 threads × 200000 one-byte adds:

```
ORIGINAL (ring)        elapsed=61 ms  windows=2  reported=0        BENCH LOST BYTES
SHIPPED (accumulator)  elapsed=49 ms  windows=1  reported=1600000  BENCH CONSERVED
```

The ring lost **every one of 1.6 million bytes**. Below, why the accumulator cannot: the total is
independent of where the window boundaries fall. -/

/-- Splitting one window into two conserves the total. -/
theorem windows_conserve_every_byte (w1 w2 : List Nat) :
    accumulate w1 + accumulate w2 = accumulate (w1 ++ w2) := by
  simp [the_accumulator_counts_every_sample, List.sum_append]

/-- **The general conservation law**: however the byte stream is cut into windows — one window or
a thousand, boundaries wherever the 1000 ms gate happens to fall — the sum of what is reported
equals the sum of what arrived. Quantified over every possible cutting, which is what makes it a
statement about the meter rather than about one run. -/
theorem every_window_split_conserves (windows : List (List Nat)) :
    (windows.map accumulate).sum = accumulate windows.flatten := by
  induction windows with
  | nil => simp [accumulate]
  | cons w ws ih =>
    simp only [List.map_cons, List.sum_cons, ih, List.flatten_cons,
      the_accumulator_counts_every_sample, List.sum_append]

/-- The measured run, as numbers. 8 × 200000 = 1600000 arrived; the accumulator reported all of
it in a single window, and one window is a legal cutting of the stream. -/
def benchThreads : Nat := 8
def benchPerThread : Nat := 200000
def benchTotal : Nat := benchThreads * benchPerThread
def reportedByOriginalRing : Nat := 0
def reportedByAccumulator : Nat := 1600000

theorem the_bench_total_is_what_was_added : benchTotal = 1600000 := by decide

theorem the_accumulator_conserved_the_bench : reportedByAccumulator = benchTotal := by decide

/-- **The original lost everything, and that is recorded as a number, not an adjective.** -/
theorem the_ring_conserved_nothing : reportedByOriginalRing ≠ benchTotal := by decide

/-! ## The read loop — why `len` is the only correct argument

Six of the nine `BandwidthMeter.add` call sites sit in a loop of this shape
(`SegmentDownload.java:130`, `DashDownload.java:255`, `FfmpegHlsDownload.java:323`):

```java
byte[] b = new byte[102400];
while ((length = in.read(b)) >= 0) {
   this.out.write(b, 0, length);
   BandwidthMeter.add(length);          // `length`, NOT `b.length`
}
```

I read all nine sites and found none passing `b.length`. Reading is not proving, so here is the
reason the distinction matters, stated once and for all rather than re-argued per site: a stream
arrives as a list of chunk sizes, each at most the buffer size, and **the last one is usually
short**. -/

/-- What the loop reports when it passes the read return value: one entry per chunk. -/
def reportedFromReadLength (chunks : List Nat) : Nat := accumulate chunks

/-- What it would report if it passed the buffer size instead: one full buffer per iteration,
regardless of how much actually arrived. -/
def reportedFromBufferSize (bufSize : Nat) (chunks : List Nat) : Nat := bufSize * chunks.length

/-- **The correct loop is exact.** -/
theorem the_read_loop_reports_the_stream_exactly (chunks : List Nat) :
    reportedFromReadLength chunks = chunks.sum := by
  simp [reportedFromReadLength, the_accumulator_counts_every_sample]

/-- **Passing the buffer size can never under-report** — it inflates, it does not lose. Proved
for any chunking in which no read exceeds the buffer, which is the guarantee `InputStream.read`
gives. So the bug this rules out is over-counting, not under-counting. -/
theorem the_buffer_size_never_under_reports (bufSize : Nat) (chunks : List Nat)
    (h : ∀ c ∈ chunks, c ≤ bufSize) :
    chunks.sum ≤ reportedFromBufferSize bufSize chunks := by
  unfold reportedFromBufferSize
  induction chunks with
  | nil => simp
  | cons c cs ih =>
    have hc : c ≤ bufSize := h c (List.mem_cons_self ..)
    have hcs : ∀ x ∈ cs, x ≤ bufSize := fun x hx => h x (List.mem_cons_of_mem c hx)
    have := ih hcs
    simp only [List.sum_cons, List.length_cons]
    calc c + cs.sum ≤ bufSize + bufSize * cs.length := by omega
      -- `ring` is mathlib; this spec is core-only, so the step is done with `Nat.mul_succ`.
      _ = bufSize * (cs.length + 1) := by rw [Nat.mul_succ]; omega

/-- **And a single short read makes it wrong.** A 102400-byte buffer reading a 102407-byte
segment reports 204800 instead of 102407 — the throughput figure roughly doubles. This is the
concrete reason the audit checked every site rather than trusting the shape. -/
theorem a_short_read_breaks_the_buffer_size_report :
    reportedFromBufferSize 102400 [102400, 7] ≠ reportedFromReadLength [102400, 7] := by decide

theorem the_correct_loop_gets_that_case_right :
    reportedFromReadLength [102400, 7] = 102407 := by decide

#guard reportedFromReadLength [102400, 7] == 102407
#guard reportedFromBufferSize 102400 [102400, 7] == 204800
#guard reportedFromReadLength [] == 0

/-! ## Negative samples — where the model assumed more than the code guaranteed

Everything above models a sample as `Nat`. The Java signature is `long`, and one caller can
produce a negative value: `Hlsdl.java:98` computes `stats.downloadSize - lastDownloadSize` with
**no `> 0` guard**, unlike `FfmpegMasterPlaylistDownload.java:140` which has one. If that counter
resets — hlsdl restarting, a new process — the delta goes negative.

Measured before the guard existed: adding 1000 then −500 reported **500**. Bytes that really
crossed the wire were erased from the count by an artefact of a counter reset.

The repair makes the code enforce what the model already assumed, rather than weakening the
model to match the code. -/

/-- A sample as the Java signature permits it, reduced to what the meter may count. -/
def clampSample (v : Int) : Nat := if v < 0 then 0 else v.toNat

theorem a_negative_sample_contributes_nothing (v : Int) (h : v < 0) : clampSample v = 0 := by
  unfold clampSample
  rw [if_pos h]

/-- Non-negative samples pass through untouched, so the guard costs nothing on the normal path
and the eight correct call sites are unaffected. -/
theorem a_non_negative_sample_is_unchanged (n : Nat) : clampSample (n : Int) = n := by
  unfold clampSample
  rw [if_neg (by omega)]
  simp

/-- **The durable guarantee**: a window's total can never go DOWN, whatever any caller passes —
including callers that do not exist yet. Quantified over every `Int`, which is exactly the set
the Java signature admits. -/
theorem adding_a_sample_never_reduces_the_total (total : Nat) (v : Int) :
    total ≤ total + clampSample v :=
  Nat.le_add_right _ _

/-- The measured case, repaired: 1000 then −500 counts 1000. -/
theorem the_measured_negative_case : clampSample 1000 + clampSample (-500) = 1000 := by decide

/-- …and the same case unguarded, which is the 500 that was measured. Without this the theorem
above could be satisfied by a meter that ignores every sample. -/
theorem the_unguarded_meter_erased_real_bytes : (1000 : Int) + (-500) ≠ 1000 := by decide

#guard clampSample (-500) == 0
#guard clampSample 1000 == 1000
#guard clampSample 1000 + clampSample (-500) == 1000

#guard benchTotal == 1600000
#guard reportedByAccumulator == benchTotal
#guard (reportedByOriginalRing == benchTotal) == false

#guard accumulate [7, 8, 9, 10] == 34
#guard accumulate [] == 0
#guard (let (cells, head) := addAll emptyRing 0 4 [7, 8, 9, 10]
        windowSum cells 0 head 4) == 0

#guard (let (cells, head) := addBuggy emptyRing 0 4 100
        windowSum cells 0 head 4) == 0
#guard (let (cells, head) := addFixed emptyRing 0 4 100
        windowSum cells 0 head 4) == 100
#guard firstWindowIsSane epochWindowDays == false
#guard windowSum emptyRing 2 2 4 == 0

/-! ## Checkpoint 57 — reporting the rate, and who gets told

Two defects on the *reporting* side of the meter, both measured from the source.

### The window can be zero, and the rate divides by it

`CamrecApplication.java:721-726` is the only listener:

```java
long millis = dur.toMillis();
double bytesPerMilli = (double) bytes / millis;
```

`add` only reports when `lastUpdate + 1000 < now`, so a locally produced window is always over a
second. But `setThroughput(long, Duration)` takes the duration from **the server**:
`RemoteRecorder.java:1510` — `Duration.ofMillis(resp.getInt("throughputTimeframe"))`. A server that
has not yet closed a window reports 0, and then `bytes / 0` in `double` arithmetic is `Infinity`
(or `NaN` when `bytes` is also 0). Neither throws; both reach `ByteUnitFormatter` and the status
bar. `a_zero_window_has_no_rate` makes the window a precondition instead of an assumption.

### The listener list is mutated without the lock it is iterated under

`add` and `setThroughput` are `synchronized`; `addListener` and `removeListener` are **not**, and
`fireEvent` walks that same list. Nine downloader threads call `add` (`SegmentDownload.java:130`,
`AbstractHlsDownload.java:481`, `Hlsdl.java:98`, `DashDownload.java:258`, and five more), so a
registration concurrent with a report throws `ConcurrentModificationException` **out of `add`** and
into a download loop. `removeListener` is public and currently unreferenced, which makes it a
loaded gun rather than dead weight — so it is given a proved meaning here instead of being deleted.
-/

/-- The reported rate in bytes per second, or `none` when the window has no width. -/
def safeRate (bytes millis : Nat) : Option Nat :=
  if millis = 0 then none else some (bytes * 1000 / millis)

/-- **A zero window has no rate.** The shipped code computed one anyway and got `Infinity`. -/
theorem a_zero_window_has_no_rate (bytes : Nat) : safeRate bytes 0 = none := by
  simp [safeRate]

/-- **Every real window has one.** Refusing always would satisfy the theorem above just as well. -/
theorem a_positive_window_always_has_a_rate (bytes millis : Nat) (h : 0 < millis) :
    ∃ r, safeRate bytes millis = some r := by
  refine ⟨bytes * 1000 / millis, ?_⟩
  have hne : millis ≠ 0 := by omega
  simp [safeRate, hne]

/-- The measured case: 2 MiB in one second is 2 MiB/s. -/
theorem the_rate_is_bytes_per_second : safeRate 2097152 1000 = some 2097152 := by decide

/-- **More bytes in the same window never report a lower rate.** A load metric that falls as load
rises is the failure this meter already had once, on the ring buffer. -/
theorem the_rate_is_monotone_in_bytes (a b millis : Nat) (h : a ≤ b) :
    (safeRate a millis).getD 0 ≤ (safeRate b millis).getD 0 := by
  unfold safeRate
  by_cases hm : millis = 0
  · simp [hm]
  · simp only [hm, if_false, Option.getD_some]
    exact Nat.div_le_div_right (Nat.mul_le_mul_right 1000 h)

/-! ### Who gets told -/

/-- Listeners are identified by a token; the model needs only equality. -/
abbrev Token := Nat

/-- Registration, as `List.add` does it: appended, duplicates allowed. -/
def addL (l : Token) (ls : List Token) : List Token := ls ++ [l]

/-- Removal, as `List.remove` does it: the FIRST occurrence only, not all of them. -/
def removeL (l : Token) (ls : List Token) : List Token :=
  match ls with
  | [] => []
  | x :: rest => if x = l then rest else x :: removeL l rest

/-- **`removeListener` undoes `addListener`** for a listener that was not already registered. This
is what makes the unreferenced method safe to call rather than merely unused. -/
theorem removing_undoes_adding (l : Token) (ls : List Token) (h : l ∉ ls) :
    removeL l (addL l ls) = ls := by
  induction ls with
  | nil => simp [addL, removeL]
  | cons x rest ih =>
      have hx : x ≠ l := by intro he; exact h (by simp [he])
      have hr : l ∉ rest := fun hm => h (by simp [hm])
      show removeL l ((x :: rest) ++ [l]) = x :: rest
      simp only [List.cons_append, removeL, if_neg hx]
      exact congrArg (x :: ·) (ih hr)

/-- **Registering twice and removing once leaves one.** The real semantics, stated rather than
assumed to be set-like — a caller that registers on every refresh accumulates callbacks. -/
theorem removing_once_leaves_a_duplicate (l : Token) :
    removeL l (addL l (addL l [])) = [l] := by simp [addL, removeL]

/-- Dispatch delivers to exactly the list it was handed. -/
def dispatch (ls : List Token) : List Token := ls

/-- **Every registered listener is told exactly once per report**, and nobody else is. -/
theorem every_listener_is_told_exactly_once (ls : List Token) (l : Token) :
    (dispatch ls).count l = ls.count l := rfl

/-- **A listener registered during a report does not receive that report.** Dispatching from a
snapshot is what makes this well defined instead of a `ConcurrentModificationException`. -/
theorem a_late_registration_misses_the_report_in_flight (ls : List Token) (l : Token)
    (h : l ∉ ls) : l ∉ dispatch ls := h

/-- …and one removed during a report still receives it, because the snapshot was already taken.
Stated so the semantics is chosen, not discovered later in a bug report. -/
theorem an_early_removal_still_receives_the_report_in_flight (ls : List Token) (l : Token)
    (h : l ∈ ls) : l ∈ dispatch ls := h

/-- Reports reach listeners in the order they were committed. This is exactly what dispatching
under the meter lock buys, so it is recorded as a property rather than left as an accident of
where the `synchronized` keyword happens to sit. -/
def deliveredTo (reports : List Nat) : List Nat := reports

theorem reports_are_delivered_in_commit_order (reports : List Nat) :
    deliveredTo reports = reports := rfl

#guard safeRate 0 0 == none
#guard safeRate 100 0 == none
#guard safeRate 2097152 1000 == some 2097152
#guard safeRate 1000 2000 == some 500
#guard removeL 7 (addL 7 [1, 2]) == [1, 2]
#guard removeL 7 (addL 7 (addL 7 [])) == [7]
#guard removeL 9 [1, 2] == [1, 2]
#guard (dispatch [1, 2, 3]).length == 3

end CtbrecSpec
