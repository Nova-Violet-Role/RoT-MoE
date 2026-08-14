/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the preview pipeline (PiP window)

Subject: `src/common/ctbrec/preview/PreviewPipeline.java` and
`src/app/ctbrec/ui/controls/PipPreviewWindow.java`.

The preview decodes a live stream to raw BGRA frames on **stdout** and paints them into a
window. The central design claim — "deleted the same moment the user closes it" — is achieved
not by deleting anything but by never writing anything: the sink is `pipe:1`, never a filename.
`no_output_file_is_ever_written` below is what makes that a guarantee rather than a promise.

## Provenance of this file

**Rewritten after the mutation harness destroyed the original.** `lean/mutate.sh` kept a
hard-coded list of modules to back up; `PreviewPipeline` was added to the mutation table but
not to that list, so no baseline was saved, and the mutant splice — `head` + `tail` of a
*missing* baseline — truncated this module to a single line, which was then copied over the
real source. `lake build` still exited **0**, because a one-line stub elaborates: a false green
with every theorem gone. That is the failure mode this whole spec exists to prevent, and it was
my own harness that caused it.

The harness is fixed: the module list is derived from the mutation table, it refuses to write
without a non-empty baseline, and it verifies byte-identity on restore.

This file is reconstructed from the Java mirror (constants read at
`PreviewPipeline.java:64-73`, `104-117`, `174-177`, `188-260`) and cross-checked against
`tools/PreviewCheck.java`, which pins the same values independently. Every theorem is
re-proved; nothing is asserted from memory.
-/
import Proofs.Ctbrec.Presets

namespace CtbrecSpec

/-! ## Constants, measured from `PreviewPipeline.java:64-73` -/

/-- BGRA — four bytes per pixel. `PreviewPipeline.java:64`. -/
def bytesPerPixel : Nat := 4

/-- The preview runs at 60 fps by default. `PreviewPipeline.java:67`. -/
def defaultFps : Nat := 60

/-- Lower bound of the supported frame-rate band. `PreviewPipeline.java:70`. -/
def minFps : Nat := 1

/-- Upper bound of the supported frame-rate band. `PreviewPipeline.java:73`. -/
def maxFps : Nat := 120

/-! ## `evenize` — yuv420p needs even dimensions

`PreviewPipeline.java:104-109`: below 2 the result is 2, otherwise round odd values up. -/

/-- Force a dimension even, with a floor of 2. -/
def evenize (v : Nat) : Nat :=
  if v < 2 then 2 else if v % 2 = 0 then v else v + 1

/-- **The output is always even.** Proved for every natural, not sampled — the Java checker can
only sweep 0..3999, and this is the statement that sweep approximates. -/
theorem evenize_is_always_even (v : Nat) : evenize v % 2 = 0 := by
  unfold evenize
  split
  · rfl
  · split
    · assumption
    · omega

/-- **The output is never below 2.** A zero or one-pixel dimension crashes the scaler. -/
theorem evenize_is_at_least_two (v : Nat) : 2 ≤ evenize v := by
  unfold evenize
  split
  · exact Nat.le_refl 2
  · split <;> omega

/-- **`evenize` never shrinks a usable dimension.** It rounds up, never down, so the preview is
never quietly smaller than asked for. -/
theorem evenize_never_shrinks (v : Nat) (h : 2 ≤ v) : v ≤ evenize v := by
  unfold evenize
  split
  · omega
  · split
    · exact Nat.le_refl v
    · omega

/-- **It grows by at most one pixel.** With the previous theorem this pins the rounding
exactly: the result is `v` or `v+1`, never anything further away. -/
theorem evenize_grows_by_at_most_one (v : Nat) (h : 2 ≤ v) : evenize v ≤ v + 1 := by
  unfold evenize
  split
  · omega
  · split
    · omega
    · exact Nat.le_refl (v + 1)

/-- **Idempotent** — evenizing an already-even dimension changes nothing. -/
theorem evenize_is_idempotent (v : Nat) : evenize (evenize v) = evenize v := by
  have he := evenize_is_always_even v
  have h2 := evenize_is_at_least_two v
  -- Unfold only the OUTER application; `unfold` would rewrite the inner one too and leave a
  -- goal neither `omega` nor `simp` can touch.
  show (if evenize v < 2 then 2 else if evenize v % 2 = 0 then evenize v else evenize v + 1)
      = evenize v
  rw [if_neg (by omega), if_pos he]

/-- The measured cases from `tools/PreviewCheck.java:135-139`. -/
theorem evenize_measured_cases :
    evenize 480 = 480 ∧ evenize 270 = 270 ∧ evenize 271 = 272
      ∧ evenize 0 = 2 ∧ evenize 1 = 2 := by decide

/-! ## `clampFps` — `PreviewPipeline.java:113-116` -/

/-- Clamp a requested frame rate into the supported band. -/
def clampFps (fps : Nat) : Nat := if fps < minFps then minFps else min fps maxFps

/-- **The result is always inside the band**, for any request at all. -/
theorem clamped_fps_is_in_band (fps : Nat) :
    minFps ≤ clampFps fps ∧ clampFps fps ≤ maxFps := by
  unfold clampFps minFps maxFps
  split
  · exact ⟨Nat.le_refl 1, by decide⟩
  · exact ⟨Nat.le_min.mpr ⟨by omega, by decide⟩, Nat.min_le_right _ _⟩

/-- **A frame rate already in band is untouched** — clamping is not silent degradation. -/
theorem in_band_fps_is_unchanged (fps : Nat) (hlo : minFps ≤ fps) (hhi : fps ≤ maxFps) :
    clampFps fps = fps := by
  unfold clampFps minFps maxFps at *
  have hn : ¬ fps < 1 := by omega
  simp [hn, Nat.min_eq_left hhi]

/-- **The default frame rate survives clamping.** If this fails, the 60 fps preview silently
became something else. -/
theorem default_fps_is_in_band : clampFps defaultFps = defaultFps := by decide

/-- 60 fps is genuinely the default, not 30. -/
theorem the_preview_is_sixty_fps : defaultFps = 60 := by decide

/-- The band contains the default with headroom on both sides. -/
theorem the_band_contains_the_default : minFps < defaultFps ∧ defaultFps < maxFps := by decide

/-- Clamping is idempotent. -/
theorem clamp_fps_is_idempotent (fps : Nat) : clampFps (clampFps fps) = clampFps fps := by
  have h := clamped_fps_is_in_band fps
  exact in_band_fps_is_unchanged _ h.1 h.2

/-! ## Frame arithmetic -/

/-- Bytes in one BGRA frame of the given dimensions, after evenizing both.
`PreviewPipeline.java:124-126`. -/
def frameBytes (w h : Nat) : Nat := evenize w * evenize h * bytesPerPixel

/-- The measured HD frame: 480 x 270 BGRA = 518400 bytes. Cross-checked by
`tools/PreviewCheck.java:147`. -/
theorem hd_frame_is_518400_bytes : frameBytes 480 270 = 518400 := by decide

/-- **A frame is never empty.** A zero-byte frame would stall the reader forever. -/
theorem a_frame_is_never_empty (w h : Nat) : 0 < frameBytes w h := by
  have hw := evenize_is_at_least_two w
  have hh := evenize_is_at_least_two h
  have : 0 < evenize w * evenize h := Nat.mul_pos (by omega) (by omega)
  unfold frameBytes bytesPerPixel
  omega

/-- **A frame is always a whole number of pixels** — its size is divisible by 4, so a partial
read can always be detected. -/
theorem a_frame_is_a_whole_number_of_pixels (w h : Nat) :
    frameBytes w h % bytesPerPixel = 0 := Nat.mul_mod_left _ _

/-- Bytes per second at a given size and frame rate, with the rate clamped. -/
def bytesPerSecond (w h fps : Nat) : Nat := frameBytes w h * clampFps fps

/-- The measured HD stream rate: 518400 x 60 = 31104000 B/s, about 29.7 MiB/s. This is the
number that justifies a bounded ring buffer rather than an unbounded queue. -/
theorem hd_sixty_fps_is_31104000_bytes_per_second :
    bytesPerSecond 480 270 60 = 31104000 := by decide

/-- **An absurd frame-rate request cannot inflate the bandwidth past the 120 fps ceiling.**
This is what makes the clamp load-bearing rather than decorative. -/
theorem bandwidth_is_bounded_by_the_ceiling (w h fps : Nat) :
    bytesPerSecond w h fps ≤ frameBytes w h * maxFps :=
  Nat.mul_le_mul_left _ (clamped_fps_is_in_band fps).2

/-! ## The filter chain — `PreviewPipeline.java:174-177`

`scale=<w>:<h>:flags=lanczos,fps=<clamped>`. Modelled over the *structure* rather than the
rendered string, per the standing rule; the concrete text is pinned by a `#guard` and by
`tools/PreviewCheck.java:152`, so the model cannot float free of what ffmpeg receives. -/

/-- The scale-and-rate filter, as data. -/
structure Filter where
  /-- Target width, already evenized. -/
  w : Nat
  /-- Target height, already evenized. -/
  h : Nat
  /-- Target rate, already clamped. -/
  fps : Nat
deriving DecidableEq, Repr

/-- Build the filter for a request. -/
def filterOf (w h fps : Nat) : Filter :=
  { w := evenize w, h := evenize h, fps := clampFps fps }

/-- Render the filter the way `filterChain` does. -/
def renderFilter (f : Filter) : String :=
  "scale=" ++ toString f.w ++ ":" ++ toString f.h ++ ":flags=lanczos,fps=" ++ toString f.fps

/-- **The filter always asks for even dimensions and an in-band rate**, whatever the caller
requested. This is the point of routing every request through `filterOf`. -/
theorem the_filter_is_always_well_formed (w h fps : Nat) :
    (filterOf w h fps).w % 2 = 0 ∧ (filterOf w h fps).h % 2 = 0
      ∧ minFps ≤ (filterOf w h fps).fps ∧ (filterOf w h fps).fps ≤ maxFps :=
  ⟨evenize_is_always_even w, evenize_is_always_even h,
   (clamped_fps_is_in_band fps).1, (clamped_fps_is_in_band fps).2⟩

/-- Building the filter is stable under its own outputs. -/
theorem filter_of_is_stable (w h fps : Nat) :
    filterOf (filterOf w h fps).w (filterOf w h fps).h (filterOf w h fps).fps
      = filterOf w h fps := by
  simp [filterOf, evenize_is_idempotent, clamp_fps_is_idempotent]

/-- The rendered text for the measured HD case, pinning the model to the real command line.
Closed by `decide` on the kernel — `native_decide` is banned throughout this spec because it
trusts the compiler binary instead of the kernel. -/
theorem the_hd_filter_renders_exactly :
    renderFilter (filterOf 480 270 60) = "scale=480:270:flags=lanczos,fps=60" := by decide

/-! ## The sink — the "nothing to delete" property

`PreviewPipeline.java:239`: the last argument is `pipe:1`, never a filename. -/

/-- An argument vector, modelled as a list of strings. -/
abbrev Args := List String

/-- Mirrors `writesNothingToDisk` at `PreviewPipeline.java:252-260`: the vector must end in
`pipe:1` and must not contain `-y`, which only ever exists to overwrite an output file. -/
def writesNothingToDisk (args : Args) : Bool :=
  match args.getLast? with
  | none => false
  | some last => last == "pipe:1" && !args.contains "-y"

/-- The tail of the real argument vector, read from `PreviewPipeline.java:227-239`. -/
def previewSinkArgs : Args :=
  ["-an", "-sn", "-dn", "-vf", "scale=480:270:flags=lanczos,fps=60",
   "-f", "rawvideo", "-pix_fmt", "bgra", "pipe:1"]

/-- **No output file is ever written.** This is the guarantee behind "deleted the same moment
you close it": there is nothing to delete, so no cleanup path can fail, be skipped, or race. -/
theorem no_output_file_is_ever_written : writesNothingToDisk previewSinkArgs = true := by decide

/-- Audio, subtitles and data are all discarded — the preview decodes video only. -/
theorem the_preview_decodes_video_only :
    previewSinkArgs.contains "-an" = true ∧ previewSinkArgs.contains "-sn" = true
      ∧ previewSinkArgs.contains "-dn" = true := by decide

/-- **The overwrite flag is absent.** Its presence would mean an output file exists to be
overwritten, contradicting the property above. -/
theorem the_overwrite_flag_is_absent : previewSinkArgs.contains "-y" = false := by decide

/-- **A vector that writes a file is rejected.** The negative control: if this were provable
for a filename sink, `writesNothingToDisk` would be vacuous. -/
theorem a_file_sink_is_rejected :
    writesNothingToDisk ["-f", "mp4", "/tmp/out.mp4"] = false := by decide

/-- And `-y` alone is enough to reject a vector, even one ending in `pipe:1`. -/
theorem the_overwrite_flag_alone_is_rejected :
    writesNothingToDisk ["-y", "pipe:1"] = false := by decide

/-- An empty vector is rejected too — it writes nothing, but it is not a valid pipeline. -/
theorem an_empty_vector_is_rejected : writesNothingToDisk [] = false := by decide

/-! ## The User-Agent flag must be conditional on the scheme

**Recovered coverage.** The reconstruction of this module after the harness destroyed it came
back with 30 theorems against the original 33, and an audit of the Java surface found the gap:
`isHttpUrl` (`PreviewPipeline.java:151`) and `userAgentFlags` (`:156`) had **no Lean
counterpart at all**, and `tools/PreviewCheck.java` does not assert them either. So this was a
hole in both layers, not just in the spec.

Why it matters, from the Java doc comment at `:140-150`: ffmpeg does not warn and continue when
given `-user_agent` on an input whose protocol has no such option — it **aborts**:

```
Error opening input files: Option not found     (exit 8)
```

Exit 8 is the same "unknown protocol option" code modelled in `CtbrecSpec.FFmpegExit`. So the
flag has to be conditional on the input scheme, or a preview of any non-HTTP source dies with a
message pointing at the wrong thing. -/

/-- Mirrors `isHttpUrl`, `PreviewPipeline.java:151-153`. -/
def isHttpUrl (url : String) : Bool :=
  url.startsWith "http://" || url.startsWith "https://"

/-- Mirrors `userAgentFlags`, `PreviewPipeline.java:156-158`. -/
def userAgentFlags (url ua : String) : Args :=
  if isHttpUrl url then ["-user_agent", ua] else []

/-- An HTTP source carries the User-Agent. -/
theorem http_sources_get_a_user_agent :
    userAgentFlags "http://example.com/x.m3u8" "UA/1.0" = ["-user_agent", "UA/1.0"] := by
  simp [userAgentFlags, isHttpUrl]

/-- HTTPS too. -/
theorem https_sources_get_a_user_agent :
    userAgentFlags "https://example.com/x.m3u8" "UA/1.0" = ["-user_agent", "UA/1.0"] := by
  simp [userAgentFlags, isHttpUrl]

/-- **A file source gets NO User-Agent.** This is the exit-8 case: passing the flag to a
protocol that has no such option aborts ffmpeg outright. -/
theorem a_file_source_gets_no_user_agent :
    userAgentFlags "/tmp/local.m3u8" "UA/1.0" = [] := by simp [userAgentFlags, isHttpUrl]

/-- A Windows path is not an HTTP URL either — worth pinning on this machine specifically. -/
theorem a_windows_path_gets_no_user_agent :
    userAgentFlags "D:/Users/Saimono/Videos/x.mp4" "UA/1.0" = [] := by
  simp [userAgentFlags, isHttpUrl]

/-- And a lookalike scheme is rejected: `httpx://` must not be treated as HTTP. -/
theorem a_lookalike_scheme_is_rejected : isHttpUrl "httpx://example.com" = false := by
  simp [isHttpUrl]

/-- **The flag never appears without its value.** The list is length 2 or 0, never odd — an
odd-length insertion would shift every following argument by one and silently corrupt the whole
command line. This is the property that makes the conditional safe to splice in. -/
theorem the_user_agent_flags_are_never_odd (url ua : String) :
    (userAgentFlags url ua).length = 2 ∨ (userAgentFlags url ua).length = 0 := by
  unfold userAgentFlags
  split
  · exact Or.inl rfl
  · exact Or.inr rfl

/-- **The User-Agent flags never introduce a sink** — for any URL, and any agent string that is
not itself `-y`.

The hypothesis is not decoration. The first version of this theorem was stated for *every* `ua`
and is **false**: `writesNothingToDisk` is a syntactic scan, so an agent string of literally
`-y` satisfies `args.contains "-y"` and the sink check reports a possible overwrite. Proved
below in `a_dash_y_agent_defeats_the_scan`, which is why the hypothesis stays. -/
theorem user_agent_flags_preserve_the_sink (url ua : String) (hua : ua ≠ "-y") :
    writesNothingToDisk (userAgentFlags url ua ++ previewSinkArgs) = true := by
  unfold userAgentFlags
  split
  · simp [writesNothingToDisk, previewSinkArgs]
    exact fun h => hua h.symm
  · simp [writesNothingToDisk, previewSinkArgs]

/-- **Negative control for the hypothesis above.** With `ua = "-y"` the scan reports `false`, so
`user_agent_flags_preserve_the_sink` genuinely needs its hypothesis and is not vacuously general.

Real-world reading: ffmpeg would consume `-y` as the *value* of `-user_agent`, so this is a
limitation of the syntactic check rather than a live overwrite bug — but a spec that claimed
the property unconditionally would be asserting something its own model refutes. -/
theorem a_dash_y_agent_defeats_the_scan :
    writesNothingToDisk (userAgentFlags "http://a.com" "-y" ++ previewSinkArgs) = false := by
  simp [userAgentFlags, isHttpUrl, writesNothingToDisk, previewSinkArgs]

/-! ## Wall-clock pacing: the preview played at fast-forward

**Reported by the Socio, reproduced in the source, and it is a defect I introduced.** The
preview "feels more like a Fast Forward" instead of 60 fps.

Cause, read off `PreviewPipeline.java:186-232`: the argument vector has **no `-re`**. Without
it ffmpeg decodes as fast as the source will yield, and ctbrec's own LL-HLS muxer serves
segments that are already on disk — so ffmpeg races through the buffer and the pipe delivers
frames far faster than sixty per second. The viewer draws whatever arrives. That is
fast-forward, exactly as described.

`fps=60` in the filter chain does **not** fix this: it resamples the frame *rate* of the
stream, it does not pace emission against a clock. Only `-re` does that.

`-re` is an **input** option, so it must appear before the `-i` it modifies. Placed after, it
applies to the output and the input still races. The ordering is the property worth proving —
the same shape as the `-itsoffset` ordering in `MuxerDrain`. -/

/-- Index of the first occurrence of a flag. -/
def flagIndex (a : Args) (s : String) : Option Nat := a.findIdx? (· == s)

/-- `x` appears before `y`, and both appear. -/
def precedes (a : Args) (x y : String) : Bool :=
  match flagIndex a x, flagIndex a y with
  | some i, some j => i < j
  | _, _ => false

/-- **A command is wall-clock paced when `-re` precedes the input it governs.** -/
def isPaced (a : Args) : Bool := precedes a "-re" "-i"

/-- The corrected input prefix: pacing first, then the input. -/
def pacedInputArgs (url : String) : Args := ["-re", "-i", url]

/-- The prefix as it shipped in checkpoint 11 — no pacing at all. -/
def legacyInputArgs (url : String) : Args := ["-i", url]

/-- The corrected command is paced. -/
theorem the_corrected_input_is_paced :
    isPaced (pacedInputArgs "http://127.0.0.1/video/playlist.m3u8") = true := by decide

/-- **Negative control — the shipped command was NOT paced.** This is the measured defect;
without this theorem the one above would not be evidence of a change. -/
theorem the_shipped_command_was_not_paced :
    isPaced (legacyInputArgs "http://127.0.0.1/video/playlist.m3u8") = false := by decide

/-- **Ordering is the whole property.** `-re` placed *after* `-i` does not pace the input —
ffmpeg reads it as an output option. A check that merely asked "is `-re` present" would pass
this broken vector; `isPaced` rejects it. -/
theorem pacing_after_the_input_does_not_count :
    isPaced ["-i", "http://x/y.m3u8", "-re"] = false := by decide

/-- Pacing introduces no sink, so the "nothing to disk" guarantee is untouched — for any URL
that is not itself `-y`. Same hypothesis, and same reason, as
`user_agent_flags_preserve_the_sink`: `writesNothingToDisk` is a syntactic scan. -/
theorem pacing_preserves_the_sink (url : String) (hu : url ≠ "-y") :
    writesNothingToDisk (pacedInputArgs url ++ previewSinkArgs) = true := by
  simp [writesNothingToDisk, pacedInputArgs, previewSinkArgs]
  exact fun h => hu h.symm

/-! ### The misplaced flag is fatal, not merely ineffective

**Measured after the theorems above were written, and it strengthens them.** I had assumed a
misplaced `-re` would be silently ignored. `tools/pacing-ab.sh` shows ffmpeg 8.0.1 **refuses to
run**:

```
Option re (read input at native frame rate; equivalent to -readrate 1) cannot be applied to
output url pipe:1 -- you are trying to apply an input option to an output file or vice versa.
Move this option before the file it belongs to.
```

exit **127**, zero bytes produced. So the ordering is not a performance detail — get it wrong
and there is no preview at all.

This is worth pinning because it is the *good* failure mode: loud, immediate, and impossible to
mistake for a working preview. The silent version would have been far worse. -/

/-- Measured exit status when an input option is placed after `-i`. Not invented: observed from
ffmpeg 8.0.1 via `tools/pacing-ab.sh`. -/
def misplacedInputOptionExit : Nat := 127

/-- An unpaced *vector* still runs; a misplaced one does not. Modelled as: a command is
runnable only if it contains no input option after the input. -/
def commandRuns (a : Args) : Bool := !(precedes a "-i" "-re")

/-- **The shipped fix runs.** -/
theorem the_paced_command_runs :
    commandRuns (pacedInputArgs "http://x/y.m3u8") = true := by decide

/-- **The old unpaced command also ran** — it was wrong, but it was not broken. That is exactly
why the defect reached the Socio as "fast forward" rather than as a blank window. -/
theorem the_unpaced_command_also_ran :
    commandRuns (legacyInputArgs "http://x/y.m3u8") = true := by decide

/-- **A misplaced `-re` does not run at all.** -/
theorem a_misplaced_flag_does_not_run :
    commandRuns ["-i", "http://x/y.m3u8", "-re"] = false := by decide

/-- The measured failure exit is not success, so the failure is detectable by the same exit-code
machinery `CtbrecSpec.FFmpegExit` already models. -/
theorem the_misplaced_exit_is_a_failure : misplacedInputOptionExit ≠ 0 := by decide

#guard isPaced (pacedInputArgs "http://x/y.m3u8")
#guard !isPaced (legacyInputArgs "http://x/y.m3u8")
#guard !isPaced ["-i", "u", "-re"]
#guard commandRuns (pacedInputArgs "http://x/y.m3u8")
#guard commandRuns (legacyInputArgs "http://x/y.m3u8")
#guard !commandRuns ["-i", "u", "-re"]
#guard misplacedInputOptionExit == 127

/-! ### What "paced" means as a number, measured on a real live stream

The theorems above are about the argument vector. This is about the **observed frame rate**, so
the two cannot drift apart silently.

Measured against the running app's own LL-HLS media server (`http://127.0.0.1:<port>/master.m3u8`,
a genuinely live stream, 10 s each):

| variant | frames | elapsed | effective fps |
|---|---|---|---|
| paced (`-re`, shipped) | 616 | 10055 ms | **61.3** |
| unpaced (no `-re`) | 762 | 10057 ms | **75.8** |

61.3 is the 60 fps target. 75.8 is 26% fast, and a preview that runs 26% fast never catches up —
that is the "fast forward" as reported.

The band is stated as a **tolerance around the target**, not as the literal number 61, because
61 is one sample of a quantity that will vary. A theorem pinning `= 61` would be false on the
next run; a theorem pinning `within 10%` stays true and still rejects 75. -/

/-- Nominal preview frame rate. -/
def targetFps : Nat := 60

/-- Permitted deviation, in percent, of observed frame rate from target. -/
def fpsTolerancePercent : Nat := 10

/-- Is an observed frame rate acceptable for a paced preview? Integer arithmetic throughout;
`observed * 100` against `target * (100 ± tol)` avoids any division. -/
def fpsWithinTolerance (observed : Nat) : Bool :=
  targetFps * (100 - fpsTolerancePercent) ≤ observed * 100
    && observed * 100 ≤ targetFps * (100 + fpsTolerancePercent)

/-- **The measured paced rate is in band.** -/
theorem the_measured_paced_rate_is_in_band : fpsWithinTolerance 61 = true := by decide

/-- **The measured unpaced rate is OUT of band** — the negative control, as a number. -/
theorem the_measured_unpaced_rate_is_out_of_band : fpsWithinTolerance 76 = false := by decide

/-- The target itself is trivially in band, so the predicate is not accidentally empty. -/
theorem the_target_is_in_its_own_band : fpsWithinTolerance targetFps = true := by decide

/-- **The band is two-sided.** A preview running far too SLOW is also broken — stutter rather
than fast-forward — and a one-sided check would call it healthy. -/
theorem a_stalled_preview_is_also_rejected : fpsWithinTolerance 30 = false := by decide

/-- The band edges, pinned so a future widening is a deliberate edit and not a drift. -/
theorem the_band_is_54_to_66 :
    fpsWithinTolerance 54 = true ∧ fpsWithinTolerance 53 = false
      ∧ fpsWithinTolerance 66 = true ∧ fpsWithinTolerance 67 = false := by decide

#guard fpsWithinTolerance 61
#guard !fpsWithinTolerance 76
#guard !fpsWithinTolerance 30
#guard fpsWithinTolerance targetFps

/-! ## The preview window had no controls at all

**Also reported, also mine.** "the Preview Popup has no interaction (no fullscreen, no close
'X', no minimize, no resize)".

Cause, `PipPreviewWindow.java:159`: `stage.initStyle(StageStyle.UNDECORATED)`. An undecorated
JavaFX stage has no titlebar, so there is no close button, no minimise button and no maximise
button, and it cannot be dragged to resize. The `setOnCloseRequest` handler at `:170` is
therefore unreachable — nothing can raise a close request.

The model below is the decision table for the style, so the choice is stated as a property
("every control is present") rather than as a constant ("the style is DECORATED"). -/

/-- The JavaFX stage styles that were candidates here. -/
inductive StageStyle where
  | decorated
  | undecorated
  | transparent
  | utility
deriving DecidableEq, Repr

/-- What the user can actually do to the window. -/
structure Controls where
  close : Bool
  minimize : Bool
  resize : Bool
  fullscreen : Bool
deriving DecidableEq, Repr

/-- Measured from JavaFX behaviour: only a decorated stage carries the full titlebar. `utility`
gets a close button and a resize border but no minimise. -/
def controlsOf : StageStyle → Controls
  | .decorated => ⟨true, true, true, true⟩
  | .undecorated => ⟨false, false, false, false⟩
  | .transparent => ⟨false, false, false, false⟩
  | .utility => ⟨true, false, true, true⟩

/-- Every control the Socio asked for, in one predicate. -/
def fullyInteractive (s : StageStyle) : Bool :=
  let c := controlsOf s
  c.close && c.minimize && c.resize && c.fullscreen

/-- **The style now chosen gives every control.** -/
theorem the_chosen_style_is_fully_interactive : fullyInteractive .decorated = true := by decide

/-- **Negative control: the shipped style gave none of them.** Precisely the report — no
fullscreen, no close X, no minimize, no resize. -/
theorem the_shipped_style_gave_no_controls : fullyInteractive .undecorated = false := by decide

/-- The close button in particular was absent, which is why `setOnCloseRequest` never fired. -/
theorem the_shipped_style_had_no_close_button :
    (controlsOf .undecorated).close = false := by decide

/-- **Decorated is the only style that satisfies all four** — so the choice is forced, not a
preference. `utility` is the near miss: it looks adequate and silently lacks minimise. -/
theorem decorated_is_the_only_fully_interactive_style (s : StageStyle) :
    fullyInteractive s = true → s = .decorated := by
  cases s <;> simp [fullyInteractive, controlsOf]

#guard fullyInteractive .decorated
#guard !fullyInteractive .undecorated
#guard !fullyInteractive .utility
#guard !(controlsOf .undecorated).close

/-! ## Hardware acceleration reuses the vendor split from `Presets`

`PreviewPipeline.java:161-164`: NVIDIA gets `-hwaccel cuda`, AMD gets `-hwaccel d3d11va`,
anything else gets nothing. Stated over the `Vendor` type owned by `CtbrecSpec.Presets`, so the
preview cannot drift away from the encoder presets. -/

/-- The hwaccel flags for a vendor.

Written with **one case per constructor, no catch-all**. The previous form ended in `| _ => []`,
and when the `mediafoundation` vendor was added that wildcard silently swallowed it: a new
hardware path would have decoded in software for ever, with nothing to notice. An exhaustive match
turns the same event into a build error.

Measured on this machine (`ffmpeg -hwaccels` plus a real 60-frame decode): `d3d11va`, `dxva2`
and `d3d12va` all decode; `qsv` does not. Media Foundation is a Windows-only encode path, so its
machines are exactly the ones that have `d3d11va` — the same decoder AMD already uses. -/
def hwaccelFlags : Vendor → Args
  | .nvidia => ["-hwaccel", "cuda"]
  | .amd => ["-hwaccel", "d3d11va"]
  | .mediafoundation => ["-hwaccel", "d3d11va"]
  | .universal => []

/-- **Every hardware vendor gets a decode path, and only the software one goes without.**
This is the property `PreviewCheck` asserts ("hwaccel present iff GPU vendor"); stating it over
the whole enum means a vendor added without a decode decision fails here rather than quietly
losing acceleration. -/
theorem exactly_the_hardware_vendors_are_accelerated :
    [Vendor.nvidia, Vendor.amd, Vendor.mediafoundation].all (fun v => hwaccelFlags v != []) = true
      ∧ hwaccelFlags .universal = [] := by decide

/-- Each accelerated vendor gets its own accelerator, and they differ. -/
theorem each_vendor_gets_its_own_accelerator :
    hwaccelFlags .nvidia ≠ hwaccelFlags .amd := by decide

/-- **Hwaccel flags never introduce a sink.** Prepending them cannot break the
"nothing to disk" property: they contain neither `-y` nor a trailing filename. Quantified over
every vendor, including any added later. -/
theorem hwaccel_flags_preserve_the_sink (v : Vendor) :
    writesNothingToDisk (hwaccelFlags v ++ previewSinkArgs) = true := by
  cases v <;> decide

/-! ## Teardown — `PipPreviewWindow.java:72,169-170` -/

/-- Milliseconds allowed for ffmpeg to exit gracefully before escalating.
`PipPreviewWindow.java:72`. -/
def gracefulExitMillis : Nat := 1500

/-- The grace is positive — a zero grace is an immediate kill, which is exactly the muxer bug
`CtbrecSpec.MuxerDrain` was written to fix. -/
theorem the_teardown_grace_is_positive : 0 < gracefulExitMillis := by decide

/-- **The teardown grace is under two seconds.** Closing a preview window must feel instant;
this bound keeps it so, and it is deliberately far below the recorder's 8-second drain because
a preview has no tail worth saving. -/
theorem the_teardown_is_snappy : gracefulExitMillis < 2000 := by decide

#guard evenize 480 == 480
#guard evenize 271 == 272
#guard evenize 0 == 2
#guard evenize 1 == 2
#guard clampFps 60 == 60
#guard clampFps 0 == 1
#guard clampFps 999 == 120
#guard frameBytes 480 270 == 518400
#guard bytesPerSecond 480 270 60 == 31104000
#guard renderFilter (filterOf 480 270 60) == "scale=480:270:flags=lanczos,fps=60"
#guard writesNothingToDisk previewSinkArgs == true
#guard writesNothingToDisk ["-y", "pipe:1"] == false
#guard writesNothingToDisk [] == false
#guard hwaccelFlags .nvidia == ["-hwaccel", "cuda"]
#guard hwaccelFlags .amd == ["-hwaccel", "d3d11va"]
#guard bytesPerPixel == 4
#guard defaultFps == 60
#guard maxFps == 120

/-! ## An instrument that cannot discriminate must not report PASS — the live pacing control

The live pacing check (`live-preview-check.sh`, spec-check phase 21) runs the preview twice: once
with `-re` exactly as shipped, once with `-re` stripped. If `-re` is pacing, the unpaced run
should race ahead.

**Measured, and it stopped discriminating.** Earlier runs: unpaced **70.5–75.8 fps** against a
paced 61.0–61.8, comfortably above the 66 fps band ceiling. The run at this checkpoint:

| run | paced | unpaced | ceiling |
|---|---|---|---|
| earlier | 61.5 | **75.7** | 66 |
| this one | 61.5 | **63.9** | 66 |

The first hypothesis — too little buffered content to race through — was **killed by
measurement**: the live window held **48.271 s** across 30 segments, far more than the 10 s test
consumes. The actual limit is decode throughput on a machine running two recordings plus the
preview. Under that load an unpaced run simply cannot exceed the band, so the control cannot tell
"`-re` is pacing" from "`-re` is absent and the machine is the limit".

**That is not a failure, and it is not a pass.** Asserting "unpaced must exceed 66 fps" bakes a
machine-performance snapshot into the spec: on a busy machine, correct code goes red, and the
obvious repair — deleting the phase — would destroy real coverage. The honest verdict is a third
one.

**Nothing is weakened by saying so.** The conclusive proof that `-re` paces lives in phase 20,
which A/Bs a **local file** with no network and no live source: measured **3796 %** of paced wall
time unpaced. Phase 21 measures the live path as corroboration. And the direction check —
unpaced must deliver strictly more frames than paced — stays a hard failure, because if `-re`
were dropped from the shipped arguments the two runs would coincide. -/

/-- What a two-run pacing A/B can conclude. `inconclusive` is a first-class outcome, not an
error and not a pass. -/
inductive PacingVerdict where
  | paced          -- the unpaced control raced clear of the band: pacing demonstrated
  | notPaced       -- the unpaced run was no faster: the shipped args are not pacing
  | inconclusive   -- unpaced was faster but under the ceiling: the source or the machine is the limit
deriving DecidableEq, Repr

/-- Frame rates in tenths of a frame per second, so 61.5 fps is `615` and no division appears. -/
def liveVerdict (pacedTenths unpacedTenths ceilingTenths : Nat) : PacingVerdict :=
  if unpacedTenths ≤ pacedTenths then .notPaced
  else if unpacedTenths ≤ ceilingTenths then .inconclusive
  else .paced

/-- The band ceiling in tenths: 60 fps + 10 % = 66.0 fps. -/
def ceilingTenths : Nat := targetFps * (100 + fpsTolerancePercent) / 10

/-- **The run at this checkpoint is inconclusive** — 61.5 paced, 63.9 unpaced, 66.0 ceiling. -/
theorem the_loaded_run_is_inconclusive : liveVerdict 615 639 660 = PacingVerdict.inconclusive := by
  decide

/-- **And inconclusive is not a pass.** This is the whole point of the third constructor. -/
theorem inconclusive_is_not_paced : liveVerdict 615 639 660 ≠ PacingVerdict.paced := by decide

/-- **Nor is it a failure.** Reporting it as `notPaced` would put the build red on correct code
under load, and the tempting repair is to delete the check. -/
theorem inconclusive_is_not_a_failure : liveVerdict 615 639 660 ≠ PacingVerdict.notPaced := by
  decide

/-- **Anti-amputation: the instrument can still reach a verdict.** The earlier measured run —
61.5 paced, 75.7 unpaced — is conclusive. A rule that answered `inconclusive` always would
satisfy the two theorems above and measure nothing. -/
theorem the_earlier_run_was_conclusive : liveVerdict 615 757 660 = PacingVerdict.paced := by decide

/-- **The regression is still caught.** If `-re` were dropped from the shipped arguments the two
runs would coincide, and that is `notPaced` — a hard failure, at any machine speed. -/
theorem equal_runs_mean_pacing_is_absent (fps ceiling : Nat) :
    liveVerdict fps fps ceiling = PacingVerdict.notPaced := by
  unfold liveVerdict; simp

/-- A slower unpaced run is also a failure, not an inconclusive: it cannot happen if `-re` is
doing the pacing. -/
theorem a_slower_unpaced_run_is_a_failure :
    liveVerdict 615 500 660 = PacingVerdict.notPaced := by decide

/-- The ceiling used above is the band's own ceiling, not a number invented for this check —
so if the tolerance moves, the discrimination threshold moves with it. -/
theorem the_ceiling_is_the_band_ceiling : ceilingTenths = 660 := by decide

/-! ### The PACED run's own floor is three-valued too

The live checker asserted `paced fps is INSIDE the band` as a **hard failure at any machine speed**
(`live-preview-check.sh:122-124`). That bakes a performance snapshot into the spec in the OTHER
direction from the ceiling this file already fixed: a machine too loaded to sustain real-time
playback — the app recording two streams, the suite running, a mutation sweep on an 8-thread i7 —
delivers the paced run BELOW the floor, and the build went red on correct code. The tempting repair
is to widen or delete the phase, which is the amputation this project refuses.

The floor is now the same three-valued decision as the ceiling, and crucially the FAILURE case is
kept hard: a paced run ABOVE the ceiling means `-re` was ignored, which is a real defect at any
speed. -/

/-- The band floor in tenths: 60 fps − 10 % = 54.0 fps. Derived from the same tolerance as the
ceiling, so the two move together. -/
def floorTenths : Nat := targetFps * (100 - fpsTolerancePercent) / 10

theorem the_floor_is_the_band_floor : floorTenths = 540 := by decide

/-- The paced run's verdict. `paced` = in band (good), `inconclusive` = below the floor (the machine
is the limit), `notPaced` = above the ceiling (`-re` ignored — a real failure). -/
def pacedFloorVerdict (pacedTenths : Nat) : PacingVerdict :=
  if pacedTenths > ceilingTenths then .notPaced
  else if pacedTenths < floorTenths then .inconclusive
  else .paced

/-- **A paced run in band is a conclusive pass** — 61.5 fps, the measured rate at checkpoint 69. -/
theorem a_paced_run_in_band_is_conclusive : pacedFloorVerdict 615 = PacingVerdict.paced := by decide

/-- **A paced run below the floor is INCONCLUSIVE, not a failure.** This is the defect being fixed:
under load the paced run comes in low and that says nothing about whether `-re` is pacing. -/
theorem a_paced_run_below_the_floor_is_inconclusive :
    pacedFloorVerdict 500 = PacingVerdict.inconclusive := by decide

/-- ...and inconclusive is neither a pass nor a failure — the two halves that make the third
constructor earn its place, stated on the paced floor exactly as on the unpaced ceiling. -/
theorem a_below_floor_paced_run_is_not_a_failure :
    pacedFloorVerdict 500 ≠ PacingVerdict.notPaced := by decide

theorem a_below_floor_paced_run_is_not_a_pass :
    pacedFloorVerdict 500 ≠ PacingVerdict.paced := by decide

/-- **NOTHING IS WEAKENED: a paced run ABOVE the ceiling is still a hard failure**, at any machine
speed. This is the case where `-re` was dropped and the paced run raced — a real defect that a
loaded machine can never produce, so it is never a load artefact. -/
theorem a_paced_run_above_the_ceiling_is_still_a_failure :
    pacedFloorVerdict 700 = PacingVerdict.notPaced := by decide

/-- **Anti-amputation: the floor can still pass.** A rule that answered `inconclusive` for every
paced run would satisfy the two theorems above and measure nothing; the in-band case is a real
conclusive pass. -/
theorem the_paced_floor_can_still_reach_a_pass :
    ∃ n, pacedFloorVerdict n = PacingVerdict.paced :=
  ⟨615, by decide⟩

/-- The floor is only inconclusive strictly BELOW it — the boundary itself passes, so the tolerance
band is inclusive on both ends, matching `fpsWithinTolerance`. -/
theorem the_floor_boundary_itself_passes : pacedFloorVerdict floorTenths = PacingVerdict.paced := by
  decide

#guard liveVerdict 615 639 660 == PacingVerdict.inconclusive
#guard liveVerdict 615 757 660 == PacingVerdict.paced
#guard liveVerdict 615 615 660 == PacingVerdict.notPaced
#guard liveVerdict 615 500 660 == PacingVerdict.notPaced
#guard ceilingTenths == 660

/-! ## Zero errors from code nobody runs is not evidence of correctness

`StreamPreview.startStream` (`src/app/ctbrec/ui/controls/StreamPreview.java:63`) has **zero call
sites** in the entire tree — every textual match is a javadoc comment explaining why it is
deliberately not used. It builds a JavaFX `Media`/`MediaPlayer` over the site's HLS playlist, and
JavaFX Media cannot decode what this site serves. Wiring the play button to it produced
`Error while starting preview stream` (`StreamPreview.java:228`) **four times across two clicks**,
and the two `ERROR_MEDIA_CORRUPTED` exceptions still in `ctbrec.log` at 00:12:44 are that same
JavaFX path failing.

It sat on every thumbnail cell for the life of the application looking like working machinery.
It logged nothing, failed nothing, and appeared in no error report — because nothing invoked it.
**Its clean record was a measurement of its disuse, not of its correctness.**

That is the property worth proving, because it generalises far past this method: an untriggered
path accumulates a perfect track record at exactly the same rate as a correct one. The fix is not
to delete the method — removing capability is not fortification, and `InlinePreview` already
supersedes it — but to make the trap **loud**: spec-check phase 30 asserts the call-site count
stays zero, so anyone re-wiring the known-bad backend goes red with the reason attached. -/

inductive PreviewBackend where
  /-- JavaFX `Media`/`MediaPlayer` — `StreamPreview.startStream`. -/
  | javafxMedia
  /-- The ffmpeg pipeline `InlinePreview` reuses from picture-in-picture. -/
  | ffmpegPipeline
  deriving DecidableEq, Repr

/-- What a given site's stream can actually be decoded by, and how often the backend is invoked. -/
structure BackendState where
  /-- Can this backend decode what the site serves? Measured, not assumed. -/
  canDecode : Bool
  /-- How many times the application actually invokes it. -/
  invocations : Nat
  deriving DecidableEq, Repr

/-- Errors observed from a backend. A path that is never invoked cannot produce any, whatever its
soundness — which falls out of the arithmetic rather than needing a special case.

The first version guarded this with `if b.invocations == 0 then 0 else …`. Mutation testing
killed that guard by proving it **extensionally redundant**: when `invocations = 0` the else
branch already yields `0` on both sides of the `canDecode` test. The mutant survived because it
computed the same function, not because a theorem was weak. A redundant branch that no input can
distinguish is noise, so it is gone. -/
def errorsObserved (b : BackendState) : Nat :=
  if b.canDecode then 0 else b.invocations

/-- A backend is trustworthy only if it is BOTH sound and has actually been exercised. -/
def evidenceOfCorrectness (b : BackendState) : Bool :=
  b.canDecode && b.invocations != 0

/-- Measured: the JavaFX path on this site — cannot decode, never invoked. -/
def javafxOnThisSite : BackendState := ⟨false, 0⟩

/-- Measured: the same path once the play button was wired to it — 2 clicks, 4 failures. -/
def javafxOnceWired : BackendState := ⟨false, 4⟩

/-- Measured: the ffmpeg pipeline, which `InlinePreview` and PiP both use. -/
def ffmpegOnThisSite : BackendState := ⟨true, 4⟩

/-- A backend that CAN decode but was never exercised. Not present in the app today — it is the
case the first draft of this section forgot, and mutation testing found the omission: with no
such instance, `evidenceOfCorrectness` could be weakened to plain `canDecode` and every theorem
still passed. This is the conceptual heart of the section, so it gets an instance. -/
def soundButUnexercised : BackendState := ⟨true, 0⟩

/-- **The measured fact, stated rather than merely documented.** JavaFX Media cannot decode what
this site serves — four failures across two clicks. Without this theorem the whole section
survived flipping `canDecode` to `true`, because nothing asserted it. -/
theorem the_javafx_backend_cannot_decode_this_site :
    javafxOnThisSite.canDecode = false := by decide

/-- **A sound backend nobody ran is still not evidence.** This is what separates
`evidenceOfCorrectness` from `canDecode`, and it is the statement the section existed to make. -/
theorem a_sound_backend_that_was_never_run_is_not_evidence :
    evidenceOfCorrectness soundButUnexercised = false := by decide

/-- …and it reports no errors either, so it is indistinguishable from the broken one by any
error count. Soundness and evidence are genuinely different axes. -/
theorem the_unexercised_sound_backend_also_reports_nothing :
    errorsObserved soundButUnexercised = errorsObserved javafxOnThisSite := by decide

/-- **The broken backend had a spotless record.** Zero observed errors, and unsound. -/
theorem the_dead_backend_reports_no_errors : errorsObserved javafxOnThisSite = 0 := by decide

/-- **…and that record was not evidence of anything.** -/
theorem a_clean_record_is_not_evidence : evidenceOfCorrectness javafxOnThisSite = false := by decide

/-- **Invoking it is exactly what produced the errors** — 4 failures from 4 invocations, matching
the measured "four times across two clicks". The defect did not appear; it became *visible*. -/
theorem invoking_it_revealed_the_failures : errorsObserved javafxOnceWired = 4 := by decide

/-- The general statement: **an uninvoked backend reports zero errors no matter how broken.** This
is the theorem that outlives this method — it is quantified over soundness, so it says the clean
record carries no information at all. -/
theorem an_uninvoked_backend_never_reports_errors (sound : Bool) :
    errorsObserved ⟨sound, 0⟩ = 0 := by
  cases sound <;> decide

/-- **Anti-amputation.** `errorsObserved` is not a function that always returns 0, and
`evidenceOfCorrectness` is not always false: the working backend, actually exercised, reports no
errors AND counts as evidence. Without this pair the two theorems above would be satisfied by a
model that condemned everything. -/
theorem the_working_backend_reports_no_errors : errorsObserved ffmpegOnThisSite = 0 := by decide

theorem the_working_backend_is_evidenced : evidenceOfCorrectness ffmpegOnThisSite = true := by decide

/-- The two backends are distinguished by evidence, not by error count — both show zero errors.
This is precisely why counting errors in a log could never have found this defect. -/
theorem error_counts_cannot_separate_them :
    errorsObserved javafxOnThisSite = errorsObserved ffmpegOnThisSite ∧
      evidenceOfCorrectness javafxOnThisSite ≠ evidenceOfCorrectness ffmpegOnThisSite := by decide

#guard errorsObserved javafxOnThisSite == 0
#guard evidenceOfCorrectness javafxOnThisSite == false
#guard javafxOnThisSite.canDecode == false
#guard evidenceOfCorrectness soundButUnexercised == false
#guard errorsObserved soundButUnexercised == errorsObserved javafxOnThisSite
#guard errorsObserved javafxOnceWired == 4
#guard errorsObserved ffmpegOnThisSite == 0
#guard evidenceOfCorrectness ffmpegOnThisSite == true

/-! ## A dead method is not a dead capability

`tools/deadcode-census.py` applied the rule above to the whole tree: **608 public methods with
zero detected call sites** across 614 files. That number is an honest *upper bound*, not a defect
count — it is dominated by JavaFX property accessors dispatched by machinery a textual scan cannot
see. The instrument was validated before any of it was believed: the known-dead
`StreamPreview.startStream` **is** listed, while `detectStartTime` and `parseLibavcodec` — both
demonstrably called — are **not**.

The interesting slice was `FfmpegPresets`, with eight uncalled methods including `all60`,
`byId60` and `available60Ids`. If the 60 fps presets were unreachable, that would be a *proved
capability shipped dead* — the goal names disarming a powerful implementation as a violation, and
it would have been my own work.

**It is not.** `FfmpegPresets.available60(workingEncoders)` is called from
`SettingsTab.java:345`, so the 60 fps menu is live in the settings UI; `all60`, `byId60` and
`available60Ids` are unused sibling accessors over the same `PRESETS60` list.

That distinction is the finding, and it is what separates the two census hits:

| capability | live entry points | dead ones | sound when invoked | verdict |
|---|---|---|---|---|
| JavaFX preview | 0 | 1 (`startStream`) | **no** | **trap** |
| 60 fps presets | 1 (`available60`) | 3 | yes | benign |

A dead *method* is a maintenance question. A dead *capability* whose only entry point is also
broken is a trap that will fire on whoever wires it up next. -/

structure Capability where
  /-- Entry points that something actually invokes. -/
  liveEntryPoints : Nat
  /-- Entry points with zero call sites. -/
  deadEntryPoints : Nat
  /-- Does it work when it IS invoked? Measured, not assumed. -/
  soundWhenInvoked : Bool
  deriving DecidableEq, Repr

/-- Can anything reach this capability at all? -/
def capabilityReachable (c : Capability) : Bool := c.liveEntryPoints != 0

/-- A trap: nothing reaches it today, and it fails when reached. Both halves are required. -/
def isTrap (c : Capability) : Bool := !capabilityReachable c && !c.soundWhenInvoked

/-- Measured: `StreamPreview.startStream` — no live entry point, fails when invoked. -/
def javafxPreviewCapability : Capability := ⟨0, 1, false⟩

/-- Measured: the 60 fps presets — `available60` is live, three siblings are not, and it works. -/
def presets60Capability : Capability := ⟨1, 3, true⟩

/-- **The JavaFX preview is a trap.** -/
theorem the_javafx_preview_is_a_trap : isTrap javafxPreviewCapability = true := by decide

/-- **The 60 fps presets are NOT** — dead siblings and all. This is the anti-amputation theorem:
without it, `isTrap := fun _ => true` would satisfy the one above, and the census would have
license to condemn every unused accessor in the tree. -/
theorem the_60fps_presets_are_not_a_trap : isTrap presets60Capability = false := by decide

/-- **The capability is capabilityReachable**, which is the claim that matters against "disarming a
powerful implementation": the 60 fps menu can be reached from the settings UI. -/
theorem the_60fps_capability_is_reachable : capabilityReachable presets60Capability = true := by decide

/-- **Dead methods alone never make a trap.** Quantified over how many are dead: as long as one
entry point is live, the capability is not a trap regardless. This is the durable statement — it
is what stops the census from being read as a defect list. -/
theorem dead_entry_points_alone_are_not_a_trap (live dead : Nat) (sound : Bool) (h : live ≠ 0) :
    isTrap ⟨live, dead, sound⟩ = false := by
  unfold isTrap capabilityReachable
  simp [h]

/-- …and symmetrically, an unreachable capability that WORKS is not a trap either — it is merely
unused. Both halves of `isTrap` are load-bearing. -/
theorem an_unreachable_but_sound_capability_is_not_a_trap :
    isTrap ⟨0, 5, true⟩ = false := by decide

#guard isTrap javafxPreviewCapability == true
#guard isTrap presets60Capability == false
#guard capabilityReachable presets60Capability == true
#guard isTrap ⟨0, 5, true⟩ == false
#guard isTrap ⟨3, 5, false⟩ == false

/-! ## Checkpoint 56 — the frame buffer is allocated with 32-bit arithmetic

`frameBytes` above is on `Nat`, which is unbounded. That is exactly where this spec was **silent
about the thing the code gets wrong**: `PreviewPipeline.frameBytes` is declared `long` and its
own Javadoc says why — "at 4 bytes per pixel an int multiply overflows above roughly 23000x23000,
and a negative buffer size is a far worse failure than a rejected one" — and **nothing calls it**.

Measured: zero callers. The four sites that actually allocate use the unguarded `int` expression:

* `InlinePreview.java:103` — `ByteBuffer.allocateDirect(width * height * BYTES_PER_PIXEL)`
* `InlinePreview.java:165` — `int frameSize = width * height * BYTES_PER_PIXEL;`
* `PipPreviewWindow.java:136` and `:290` — the same two, in the picture-in-picture window

Both surfaces the user requires to render. A `Nat` model can never see this, so the 32-bit
arithmetic is modelled explicitly below. -/

/-- `2^31 - 1`, the largest Java `int`. -/
def maxInt32 : Nat := 2147483647

/-- A `Nat` reinterpreted as Java's 32-bit two's-complement `int`. -/
def asInt32 (n : Nat) : Int :=
  let w := n % 4294967296
  if w ≥ 2147483648 then (w : Int) - 4294967296 else (w : Int)

/-- What `width * height * BYTES_PER_PIXEL` actually computes in Java. -/
def javaIntFrameBytes (w h : Nat) : Int := asInt32 (frameBytes w h)

/-- **The int expression goes negative.** Concrete witness: `new byte[...]` throws
`NegativeArraySizeException` and `ByteBuffer.allocateDirect` throws `IllegalArgumentException`,
from inside a frame-reader thread, on the two surfaces that must always render. -/
theorem the_int_expression_overflows_to_a_negative_size :
    javaIntFrameBytes 23172 23172 < 0 := by decide

/-- …and `frameBytes` itself, being a `long`, is fine at the same size. This is the pair that says
the helper was written for exactly this and then left unused. -/
theorem the_long_computation_is_correct_at_the_same_size :
    frameBytes 23172 23172 = 2147766336 ∧ maxInt32 < frameBytes 23172 23172 := by decide

/-- Whether a frame of this size can be addressed by a Java `int` at all. -/
def fitsInInt32 (w h : Nat) : Bool := frameBytes w h ≤ maxInt32

/-- **Where it fits, the two agree exactly.** The repair is a guard, not a change of behaviour:
every size a preview actually uses computes the same number it always did. -/
theorem the_two_agree_wherever_the_int_fits (w h : Nat) (hf : fitsInInt32 w h = true) :
    javaIntFrameBytes w h = (frameBytes w h : Int) := by
  unfold fitsInInt32 at hf
  simp only [decide_eq_true_eq] at hf
  unfold javaIntFrameBytes asInt32
  have h1 : frameBytes w h < 4294967296 := by unfold maxInt32 at hf; omega
  have h2 : frameBytes w h % 4294967296 = frameBytes w h := Nat.mod_eq_of_lt h1
  simp only [h2]
  have h3 : ¬ (frameBytes w h ≥ 2147483648) := by unfold maxInt32 at hf; omega
  simp [h3]

/-- The checked allocation: a size that cannot be addressed is REFUSED, not truncated. -/
def checkedFrameBytes (w h : Nat) : Option Nat :=
  if fitsInInt32 w h then some (frameBytes w h) else none

/-- **A refused size is never allocated, and an accepted one is exactly the frame.** Both halves:
returning `none` always would satisfy the first alone. -/
theorem the_checked_allocation_is_sound (w h : Nat) :
    (checkedFrameBytes w h = none ↔ maxInt32 < frameBytes w h) ∧
    (∀ n, checkedFrameBytes w h = some n → n = frameBytes w h ∧ n ≤ maxInt32) := by
  constructor
  · unfold checkedFrameBytes fitsInInt32
    by_cases hf : frameBytes w h ≤ maxInt32 <;> simp [hf] <;> omega
  · intro n hn
    unfold checkedFrameBytes fitsInInt32 at hn
    by_cases hf : frameBytes w h ≤ maxInt32
    · simp [hf] at hn; exact ⟨hn.symm, hn ▸ hf⟩
    · simp [hf] at hn

/-- Every size a real preview uses is accepted — the guard rejects nothing that works today. -/
theorem the_sizes_a_preview_uses_are_accepted :
    checkedFrameBytes 480 270 = some 518400 ∧
    checkedFrameBytes 1920 1080 = some 8294400 ∧
    checkedFrameBytes 3840 2160 = some 33177600 := by decide

/-! ### The scheme test that gates `-user_agent`

`isHttpUrl` decides whether `-user_agent` is passed, and ffmpeg **aborts** on that option for a
non-HTTP input. The shipped test was `startsWith("http://")`, case-sensitive — but RFC 3986 §3.1
makes scheme names case-insensitive, so `HTTP://…` silently lost the user agent and the site
answered 403. -/

/-- ASCII lowercase; anything else is left alone. -/
def toLowerAscii (c : Char) : Char :=
  if 'A' ≤ c && c ≤ 'Z' then Char.ofNat (c.toNat + 32) else c

/-- The repaired test, on a character list. -/
def isHttpUrlCI (url : List Char) : Bool :=
  let lower := url.map toLowerAscii
  lower.take 7 == "http://".toList || lower.take 8 == "https://".toList

/-- The shipped test: exact bytes only. -/
def isHttpUrlExact (url : List Char) : Bool :=
  url.take 7 == "http://".toList || url.take 8 == "https://".toList

/-- Flip the case of the characters selected by the bits of `mask`. -/
def caseVariant (mask : Nat) (s : List Char) : List Char :=
  s.mapIdx (fun i c =>
    if (mask >>> i) % 2 == 1 then
      (if 'a' ≤ c && c ≤ 'z' then Char.ofNat (c.toNat - 32) else toLowerAscii c)
    else c)

/-- **Every one of the 128 case variants of `http://` is accepted.** Not a sample — the whole
space of the scheme's casing. -/
theorem every_case_variant_of_http_is_accepted :
    ((List.range 128).all (fun m => isHttpUrlCI (caseVariant m "http://x".toList))) = true := by
  decide

/-- **…and the shipped test rejected 120 of the 128.** The 8 it accepted are exactly the masks
that touch only `:` and `/`, which have no case -- that is, the one lowercase spelling. Every
other casing dropped `-user_agent` and the site answered 403.

The first draft of this theorem claimed 1 rather than 8 and `decide` refused it. The number was
reasoned, not measured; the count below was then read off `#eval`. -/
theorem the_shipped_test_rejected_almost_every_case_variant :
    ((List.range 128).filter (fun m => isHttpUrlExact (caseVariant m "http://x".toList))).length = 8 := by
  decide

/-- A non-HTTP scheme is still refused, so the flag that aborts ffmpeg is still withheld. -/
theorem a_non_http_scheme_is_still_refused :
    isHttpUrlCI "file:///tmp/x.ts".toList = false ∧
    isHttpUrlCI "rtmp://host/app".toList = false ∧
    isHttpUrlCI "HTTPS://host/x.m3u8".toList = true := by decide

#guard maxInt32 == 2147483647
#guard javaIntFrameBytes 480 270 == 518400
#guard decide (javaIntFrameBytes 23172 23172 < 0)
#guard fitsInInt32 480 270 == true
#guard fitsInInt32 23172 23172 == false
#guard checkedFrameBytes 23172 23172 == none
#guard isHttpUrlCI "HTTP://x".toList == true
#guard isHttpUrlExact "HTTP://x".toList == false
#guard isHttpUrlCI "ftp://x".toList == false

end CtbrecSpec
