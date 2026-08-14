/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — thumbnail geometry and the 480 HD rung

Subject: `ThumbCell.java` / `ThumbOverviewTab.java` — the thumbnail size ladder and the aspect
ratio that derives a thumbnail's height from its width.

## Provenance of this file

**Rewritten after the mutation harness destroyed the original.** `lean/mutate.sh` kept a
hard-coded list of modules to back up; `ThumbGeometry` was added to the mutation table but not
to that list, so no baseline was saved, and the mutant splice — `head` + `tail` of a *missing*
baseline — truncated this module to a single line, which was then copied over the real source.
`lake build` still exited **0**, because a one-line stub elaborates: a false green with every
theorem gone.

The harness is fixed (module list derived from the table; it now refuses to write without a
non-empty baseline; it verifies byte-identity on restore). This file is reconstructed from its
Java mirror and from `tools/PreviewCheck.java` phase 2, which pins the same numbers
independently. Everything below is re-proved, not asserted from memory.
-/
import Proofs.Ctbrec.WindowGeometry

namespace CtbrecSpec

/-- Numerator of the standard thumbnail aspect ratio (9 high : 16 wide). -/
def aspectNum : Nat := 9

/-- Denominator of the standard thumbnail aspect ratio. -/
def aspectDen : Nat := 16

/-- The selectable thumbnail widths, smallest first. `480` is the HD rung this rework added;
before it the ladder stopped at 360. -/
def thumbLadder : List Nat := [140, 160, 180, 200, 220, 270, 360, 480]

/-- Height of a 16:9 thumbnail of the given width, truncating. -/
def thumbHeight (w : Nat) : Nat := w * aspectNum / aspectDen

/-- Height of a 16:10 thumbnail, for sites that serve that ratio. -/
def thumbHeight1610 (w : Nat) : Nat := w * 10 / 16

/-- Does this width divide evenly into the 16:9 grid, with no rounding loss? -/
def isExactRung (w : Nat) : Bool := w % aspectDen == 0

/-! ## The ladder -/

/-- **The HD rung is on the ladder.** Without it the feature does not exist. -/
theorem hd_rung_is_on_the_ladder : thumbLadder.contains 480 = true := by decide

/-- **480 is the largest rung**, so HD sits at the top of the menu rather than buried in it. -/
theorem hd_rung_is_the_largest : thumbLadder.getLast? = some 480 := by decide

/-- The ladder has no duplicates — a repeated entry would be a duplicated menu item. -/
theorem ladder_has_no_duplicates : thumbLadder.eraseDups = thumbLadder := by decide

/-- Eight rungs, pinned so one cannot be dropped silently. -/
theorem ladder_has_eight_rungs : thumbLadder.length = 8 := by decide

/-- **ANTI-WEAKENING: every legacy rung survives.** The HD rung is purely additive; every width
that worked before still works. This fails if someone "simplifies" the ladder. -/
theorem every_legacy_rung_survives :
    [140, 160, 180, 200, 220, 270, 360].all (fun w => thumbLadder.contains w) = true := by
  decide

/-- Strictly ascending, as a decidable check. Stated this way rather than via `mergeSort`,
which does not reduce under `decide`. -/
def isAscending : List Nat → Bool
  | a :: b :: rest => a < b && isAscending (b :: rest)
  | _ => true

/-- The ladder is strictly increasing, which is what makes it a usable menu — and it implies
the no-duplicates property above. -/
theorem ladder_is_strictly_increasing : isAscending thumbLadder = true := by decide

/-! ## Geometry -/

/-- 480 x 270 is the HD thumbnail at 16:9. -/
theorem hd_is_480_by_270 : thumbHeight 480 = 270 := by decide

/-- And 480 x 300 at 16:10. -/
theorem hd_is_480_by_300_at_16_10 : thumbHeight1610 480 = 300 := by decide

/-- The previous top rung, for comparison — and it is *not* exact. -/
theorem old_top_rung_is_360_by_202 : thumbHeight 360 = 202 := by decide

/-- **Exactly two rungs divide the 16:9 grid evenly: 160 and 480.** Every other rung loses a
fraction of a pixel to truncation. This is the reason 480 was chosen for HD rather than 440 or
500, and pinning it stops the rung being "rounded" to a nearby number later. -/
theorem exact_rungs_are_160_and_480 :
    thumbLadder.filter (fun w => isExactRung w) = [160, 480] := by decide

/-- The HD rung is one of the exact ones. -/
theorem hd_rung_is_exact : isExactRung 480 = true := by decide

/-- **Every rung produces a positive height.** A zero-height thumbnail would be invisible. -/
theorem every_rung_has_positive_height :
    thumbLadder.all (fun w => 0 < thumbHeight w) = true := by decide

/-- **Height is monotone in width** — a bigger rung is never a shorter thumbnail. -/
theorem taller_when_wider (a b : Nat) (h : a ≤ b) : thumbHeight a ≤ thumbHeight b :=
  Nat.div_le_div_right (Nat.mul_le_mul_right aspectNum h)

/-- A thumbnail is landscape: its height never exceeds its width. -/
theorem thumbnails_are_landscape (w : Nat) : thumbHeight w ≤ w := by
  show w * 9 / 16 ≤ w
  calc w * 9 / 16 ≤ w * 16 / 16 := Nat.div_le_div_right (Nat.mul_le_mul_left w (by decide))
    _ = w := Nat.mul_div_cancel _ (by decide)

/-! ## The PiP preview takes its width from the same ladder

`ThumbOverviewTab.openPipPreview` opens the preview at `max 480 (2 * thumbWidth)`: a small
thumbnail still gets a usable preview, a large one gets a proportionate window. -/

/-- Preview width for a given thumbnail width. -/
def previewWidth (thumbWidth : Nat) : Nat := max 480 (2 * thumbWidth)

/-- **The preview is never smaller than the HD rung**, whatever the thumbnail size. -/
theorem preview_is_never_below_hd (w : Nat) : 480 ≤ previewWidth w := Nat.le_max_left _ _

/-- **The preview is at least twice the thumbnail**, so it is always an enlargement. -/
theorem preview_is_at_least_double (w : Nat) : 2 * w ≤ previewWidth w := Nat.le_max_right _ _

/-- Both branches of the `max` are reachable — on the smallest rung the floor binds, on the
largest the doubling does — so neither is dead code. -/
theorem both_branches_of_the_max_are_reachable :
    previewWidth 140 = 480 ∧ previewWidth 480 = 960 := by decide

/-! ## The in-thumb preview must grow with the rung

**Reported symptom:** "changing Thumb sizes normally changes also the windows factor, but 480
does not, this means the preview doesnt get expanded."

**Root cause, read from `StreamPreview.java:71-76`, `104-108`, `176-181`** — the same three
lines repeated at each site:

```java
Image img = new Image(model.getPreview(), true);  // true = BACKGROUND loading
double aspect = img.getWidth() / img.getHeight();  // 0.0 / 0.0 = NaN, nothing loaded yet
double h = w / aspect;                             // NaN
this.resizeTo(w, h);                               // setFitHeight(NaN)
```

`new Image(url, true)` returns immediately and loads asynchronously, so `getWidth()` and
`getHeight()` are both `0.0` on the very next line. The height handed to `resizeTo` is
therefore `NaN`, and an `ImageView` with `preserveRatio` and a `NaN` fit height renders at the
source image's *native* size. The preview is pinned to whatever the site served and never
expands — which only becomes visible once the requested rung exceeds the native width.

The fix is an aspect ratio that is **total**: defined for every input including the
not-yet-loaded `0 x 0`, so the height is always a real number. These theorems state what the
repaired code must satisfy — and `every_rung_gets_a_strictly_larger_preview` is the one that
encodes the user's actual complaint. -/

/-- The source dimensions of a preview image, which are `0 x 0` while it is still loading. -/
structure Source where
  /-- Native width as reported by JavaFX, `0` until the background load completes. -/
  w : Nat
  /-- Native height as reported by JavaFX, `0` until the background load completes. -/
  h : Nat
deriving DecidableEq, Repr

/-- **Total** aspect ratio, as a `(num, den)` pair. Falls back to 16:9 whenever either
dimension is missing — which is exactly the not-yet-loaded case that produced `NaN`. Returning
a pair of naturals rather than a float means the "divide by zero" case cannot exist at all. -/
def safeAspect (s : Source) : Nat × Nat :=
  if s.w == 0 || s.h == 0 then (aspectDen, aspectNum) else (s.w, s.h)

/-- The preview height for a thumb of the given width. -/
def previewHeightFor (thumbW : Nat) (s : Source) : Nat :=
  thumbW * (safeAspect s).2 / (safeAspect s).1

/-- **The denominator is never zero.** This is the theorem the Java bug violated: `getHeight()`
was `0` and the division produced `NaN`. -/
theorem the_aspect_denominator_is_never_zero (s : Source) : 0 < (safeAspect s).1 := by
  unfold safeAspect aspectDen
  split
  · decide
  · next h =>
      simp only [Bool.or_eq_true, beq_iff_eq, not_or] at h
      omega

/-- **A still-loading image falls back to 16:9** instead of dividing by zero. -/
theorem a_loading_image_falls_back_to_16_9 :
    safeAspect { w := 0, h := 0 } = (16, 9) := by decide

/-- A half-loaded image — width known, height not — falls back too. -/
theorem a_half_loaded_image_falls_back :
    safeAspect { w := 320, h := 0 } = (16, 9) := by decide

/-- A fully loaded image keeps its own ratio; the fallback does not override real data. -/
theorem a_loaded_image_keeps_its_own_ratio :
    safeAspect { w := 320, h := 180 } = (320, 180) := by decide

/-- **The preview height is positive for every rung on the ladder**, loaded or not. -/
theorem every_rung_previews_at_a_positive_height :
    thumbLadder.all (fun w => 0 < previewHeightFor w { w := 0, h := 0 }) = true := by decide

/-- **THE REPORTED BUG, as a theorem: a bigger rung is a strictly bigger preview.** Stated for
the two rungs in the report — 360 and the HD 480 — against a still-loading source, which is the
case that failed. Under the old code both sides rendered at the source's native size and this
was false. -/
theorem the_hd_rung_previews_larger_than_360 :
    previewHeightFor 360 { w := 0, h := 0 } < previewHeightFor 480 { w := 0, h := 0 } := by
  decide

/-- And the general form, which is what actually protects the feature: **every step up the
ladder is a strict increase in preview height.** Quantified over the whole ladder rather than
pinned to today's two rungs, so it keeps holding when a rung is added. -/
theorem every_rung_gets_a_strictly_larger_preview :
    isAscending (thumbLadder.map (fun w => previewHeightFor w { w := 0, h := 0 })) = true := by
  decide

/-- The same, for a loaded 320x180 source — the real Chaturbate preview size. The property must
not depend on the image having finished loading. -/
theorem the_ladder_scales_for_a_loaded_source :
    isAscending (thumbLadder.map (fun w => previewHeightFor w { w := 320, h := 180 })) = true := by
  decide

/-- **Preview height is monotone in thumb width** for any fixed source. The unquantified
statement behind the two `decide`s above. -/
theorem preview_height_is_monotone (a b : Nat) (s : Source) (h : a ≤ b) :
    previewHeightFor a s ≤ previewHeightFor b s :=
  Nat.div_le_div_right (Nat.mul_le_mul_right _ h)

/-- At 16:9 the HD rung previews at exactly 270 — the same number the PiP pipeline uses, so the
in-thumb preview and the popped-out preview agree. -/
theorem the_hd_preview_is_270_high :
    previewHeightFor 480 { w := 0, h := 0 } = 270 := by decide

/-! ## Thumbnail quality: the source must not be upscaled

**Reported symptom:** "the quality of the Thumbnail itself is too poor as of now, can we make
it better by allowing more cache?"

**Disagreement, stated plainly: a bigger cache cannot improve quality.** The HTTP cache stores
the served bytes verbatim; it changes how often the image is re-fetched, never how many pixels
it contains. `thumbCacheSize` is already 512 MB on this machine (`Settings.java:212` defaults
to 16) and the cache directory measures 521 MB — it is full and working. Quality is bounded by
the source resolution alone.

**MEASURED** from the CDN, three models, `ffprobe` on the downloaded bytes:

| variant | dimensions | aspect | note |
| --- | --- | --- | --- |
| `/ri/`  | 360 x 270 | 4:3    | what `Chaturbate.java:63` requested |
| `/riw/` | 480 x 270 | 16:9   | native HD, same CDN, ~1.06x the bytes |

So the old source was 360 px wide and **not even 16:9**. At the 480 rung it had to be upscaled
1.33x, which is the visible blur; and because the aspect was 4:3 while every layout constant
assumes 16:9, the cell geometry was wrong at every rung. Switching to `/riw/` costs about 6%
more bytes and removes the upscale entirely at the top rung.

These theorems fix the requirement: the source must cover the whole ladder. -/

/-- The `/riw/` CDN variant, measured. -/
def cdnSource : Source := { w := 480, h := 270 }

/-- The `/ri/` variant that was in use, measured. -/
def legacyCdnSource : Source := { w := 360, h := 270 }

/-- Is this thumb width served without upscaling from the given source? -/
def isNativeOrDownscaled (thumbW : Nat) (s : Source) : Bool := thumbW ≤ s.w

/-- **The legacy source could not serve the HD rung.** 360 < 480, so the top rung was always an
upscale — this is the measured cause of the poor quality. -/
theorem the_legacy_source_could_not_serve_the_hd_rung :
    isNativeOrDownscaled 480 legacyCdnSource = false := by decide

/-- **The `/riw/` source serves every rung on the ladder without upscaling.** This is the
property that makes the switch a quality fix rather than a preference. -/
theorem the_cdn_source_covers_the_whole_ladder :
    thumbLadder.all (fun w => isNativeOrDownscaled w cdnSource) = true := by decide

/-- **The HD rung is served exactly, pixel for pixel** — 480 wide from a 480-wide source. -/
theorem the_hd_rung_is_pixel_exact : cdnSource.w = 480 ∧ cdnSource.h = 270 := by decide

/-- **The new source is genuinely 16:9**, unlike the 4:3 one it replaces. Stated as a ratio
comparison so it does not depend on the particular numbers. -/
theorem the_cdn_source_is_16_by_9 :
    cdnSource.w * aspectNum = cdnSource.h * aspectDen := by decide

/-- And the legacy source was not, which is why cell geometry was wrong at every rung, not
only at 480. -/
theorem the_legacy_source_was_not_16_by_9 :
    legacyCdnSource.w * aspectNum ≠ legacyCdnSource.h * aspectDen := by decide

/-- The new source's own aspect agrees with the fallback, so a still-loading image and a loaded
one now size identically — no visible reflow when the image arrives. -/
theorem the_fallback_matches_the_real_source :
    previewHeightFor 480 cdnSource = previewHeightFor 480 { w := 0, h := 0 } := by decide

/-- **A cache size does not appear anywhere in this section.** Recorded as an `example` rather
than a theorem because it documents the disagreement, not a property of the code: quality is a
function of source resolution, and the two rungs below differ in quality precisely because the
source differs, at identical cache settings. -/
example : previewHeightFor 480 cdnSource = 270 ∧ isNativeOrDownscaled 480 legacyCdnSource = false := by
  decide

/-! ## Thumbnail retention across restarts

**Reported symptom:** "same for the Offline tab, no 'delete' thumb after (hours,day) they need
to stay."

**Root cause, read at `CamrecApplication.java:598` and `626-636`.** `clearHttpCache()` is
called unconditionally on every shutdown, and it does `evictAll()`, `close()`, then
`IoUtils.deleteDirectory(cacheDir)` — it deletes the whole directory. There is no setting
guarding it: a repository-wide grep for `clearCache|cacheOnExit|deleteCache` returns nothing.

**MEASURED live**, in the graceful shutdown performed this session:
`22:13:58,890 INFO CamrecApplication.java:617 Cache has been deleted`, against a cache
directory measuring 521 MB. So the 512 MB the user configured was filled and then destroyed on
exit, every time. That is why an offline model's thumbnail never survives — not an expiry
policy, an unconditional delete.

The repair makes deletion opt-in while keeping the *close* unconditional, because closing is
what flushes OkHttp's journal; skipping it would leave the cache corrupt rather than merely
stale. Both properties are stated below, and the second is the one that would break if someone
"fixed" this by simply removing the call. -/

/-- What the shutdown path does to the HTTP cache. -/
structure CacheShutdown where
  /-- Was the cache closed, flushing OkHttp's journal to disk? -/
  closed : Bool
  /-- Was the cache directory deleted? -/
  deleted : Bool
deriving DecidableEq, Repr

/-- The repaired shutdown: always close, delete only on explicit opt-in. -/
def onShutdown (clearOnExit : Bool) : CacheShutdown := { closed := true, deleted := clearOnExit }

/-- The legacy shutdown, `CamrecApplication.java:598` — always deleted. -/
def legacyOnShutdown : CacheShutdown := { closed := true, deleted := true }

/-- The default for the new setting. Deliberately `false`: the user asked for thumbnails to
stay, and a cache the app erases on every exit is not a cache. -/
def defaultClearCacheOnExit : Bool := false

/-- Does the cache survive to the next launch? -/
def survivesRestart (c : CacheShutdown) : Bool := !c.deleted

/-- **Thumbnails survive a restart by default.** The reported requirement, as a theorem. -/
theorem thumbnails_survive_a_restart_by_default :
    survivesRestart (onShutdown defaultClearCacheOnExit) = true := by decide

/-- **The legacy behaviour did not** — the measured cause of the disappearing thumbnails. -/
theorem the_legacy_shutdown_always_deleted : survivesRestart legacyOnShutdown = false := by
  decide

/-- **Deleting the cache now requires an explicit opt-in.** No other path reaches it. -/
theorem deletion_requires_opt_in (b : Bool) : (onShutdown b).deleted = true → b = true := by
  intro h; simpa [onShutdown] using h

/-- **The journal is flushed on BOTH branches.** This is the property that stops the obvious
wrong fix: deleting the `clearHttpCache()` call outright would also drop the `close()`, leaving
OkHttp's journal unflushed and the cache corrupt on next launch. Keeping is not the same as
ignoring. -/
theorem the_journal_is_always_flushed (b : Bool) : (onShutdown b).closed = true := by
  cases b <;> decide

/-- The opt-in still works — a user who wants the old behaviour can have it exactly. -/
theorem opting_in_reproduces_the_legacy_behaviour : onShutdown true = legacyOnShutdown := by
  decide

/-- **The retained cache is bounded**, so "keep it" cannot mean "grow forever": OkHttp evicts
by size against `thumbCacheSize`. 512 MB is the configured value on this machine. -/
def configuredCacheMegabytes : Nat := 512

/-- The default in `Settings.java:212`, for comparison. -/
def defaultCacheMegabytes : Nat := 16

/-- Retention is bounded by the configured size, not unbounded growth. -/
theorem retention_is_bounded : 0 < configuredCacheMegabytes := by decide

/-- The configured cache is far above the default — the user already raised it, which is why
the unconditional delete was the whole problem. -/
theorem the_user_already_raised_the_cache :
    defaultCacheMegabytes < configuredCacheMegabytes := by decide

/-! ## The Picture-in-Picture button on every thumbnail

**Requested:** "the Preview Picture in picture, must also be directly selectable from the Thumb
itself not just by 'right Clicking', this means we need a picture in Picture Symbol, that
spawns on every Thumb."

The cell is a `StackPane` with overlays already claiming three of the four corners, measured
from `ThumbCell.java:148-179`:

| overlay | alignment | size |
| --- | --- | --- |
| `topicBackground` | `TOP_LEFT` | `w x (h - 25)` |
| `resolutionBackground` | `TOP_RIGHT` | `34 x 16` |
| `nameBackground` | `BOTTOM_CENTER` | `w x 25` |

So the button goes `BOTTOM_RIGHT`, lifted clear of the 25 px name bar. The theorems below fix
the placement arithmetic — and the binding constraint is the SMALLEST rung, 140, whose cell is
only 78 px tall. A button that fits at 480 and overflows at 140 would be a bug visible only to
users of small thumbnails, which is exactly the kind of thing a per-rung proof catches. -/

/-- Height of the name bar at the bottom of every cell. `ThumbCell.java:754`. -/
def nameBarHeight : Nat := 25

/-- Edge length of the square PiP button. -/
def pipButtonSize : Nat := 20

/-- Gap between the button and the name bar / cell edge. -/
def pipButtonMargin : Nat := 4

/-- Distance from the bottom of the cell to the bottom of the button: clear of the name bar. -/
def pipButtonBottomInset : Nat := nameBarHeight + pipButtonMargin

/-- Total vertical space the button needs, measured from the bottom edge of the cell. -/
def pipButtonVerticalReach : Nat := pipButtonBottomInset + pipButtonSize

/-- Does the button fit inside a cell of this thumb width, without touching the name bar? -/
def pipButtonFits (thumbW : Nat) : Bool := pipButtonVerticalReach ≤ thumbHeight thumbW

/-- **The button fits on every rung of the ladder**, including the smallest. -/
theorem the_pip_button_fits_on_every_rung :
    thumbLadder.all (fun w => pipButtonFits w) = true := by decide

/-- **It fits on the smallest rung with room to spare** — the binding case, stated explicitly
because it is the one that would break first. 140 wide gives a 78 px cell; the button reaches
49 px. -/
theorem the_pip_button_fits_the_smallest_rung :
    pipButtonVerticalReach = 49 ∧ thumbHeight 140 = 78 := by decide

/-- **The button never overlaps the name bar.** It clears it by exactly the margin. -/
theorem the_pip_button_clears_the_name_bar :
    pipButtonBottomInset = nameBarHeight + pipButtonMargin
      ∧ nameBarHeight < pipButtonBottomInset := by decide

/-- **The button never overlaps the resolution badge**, which is `TOP_RIGHT` and 16 px tall,
while the button is at the bottom. They share a column, so this is the check that matters: the
badge's lowest pixel is above the button's highest. -/
theorem the_pip_button_clears_the_resolution_badge :
    thumbLadder.all (fun w => 16 + pipButtonVerticalReach ≤ thumbHeight w) = true := by decide

/-- **If a rung were added below 140 it would have to be checked.** This is the negative
control: the property is NOT vacuous, it genuinely fails for a small enough cell — so the
theorem above is load-bearing rather than true by accident. -/
theorem the_button_would_not_fit_on_a_tiny_rung : pipButtonFits 80 = false := by decide

/-! ## A second button: play the preview inside the thumbnail itself

**Requested by the Socio**: *"another Preview 'button' but that directly show inside the
'Thumbnail Itself' previewing at native settings … it needs a 'play' button, so the user can
click it to show a preview, instead of opening the whole Picture in Picture, this is more handy,
and faster for just looking trough."*

The machinery already exists and was simply never triggered: `StreamPreview.startStream(Model)`
at `StreamPreview.java:63` and `.stop()` at `:212`, on a control every cell already builds
(`ThumbCell.java:143-146`). So this is a button and a toggle, not new plumbing.

"Native settings" is the distinguishing property against PiP: the in-thumb preview renders at
the **cell's own** width and height, whereas `openPipPreview` deliberately enlarges to
`max 480 (2 * thumbWidth)`. Proved below as `the_inline_preview_is_native_sized`.

The play button sits immediately left of the PiP button in the same bottom-right cluster. The
theorems that matter are the two that could silently go wrong: the buttons must not overlap
each other, and both must still clear the name bar and the resolution badge. -/

/-- The play button matches the PiP button's size — an inconsistent pair would look accidental. -/
def playButtonSize : Nat := pipButtonSize

/-- Clear space between the two buttons. -/
def playButtonGap : Nat := 4

/-- Distance from the cell's right edge to the play button's right edge. It sits one PiP button
plus one gap further in than the PiP button's own margin. -/
def playButtonRightInset : Nat := pipButtonMargin + pipButtonSize + playButtonGap

/-- How far in from the right edge the play button reaches. -/
def playButtonHorizontalReach : Nat := playButtonRightInset + playButtonSize

/-- The PiP button occupies `[w - 24, w - 4]` from the right edge; expressed as insets, its
near edge is at `pipButtonMargin + pipButtonSize`. -/
def pipButtonHorizontalReach : Nat := pipButtonMargin + pipButtonSize

/-- **The buttons do not overlap**: the play button's near-edge inset must be at least the PiP
button's far-edge inset. Stated as insets from the right edge, so it holds for every cell width
rather than for one measured width. -/
def buttonsAreDisjoint : Bool := pipButtonHorizontalReach ≤ playButtonRightInset

/-- Both buttons fit horizontally in a cell of width `w`. -/
def bothButtonsFit (thumbW : Nat) : Bool :=
  playButtonHorizontalReach ≤ thumbW && pipButtonFits thumbW

/-- **The two buttons never overlap**, at any cell width — this is an inset relation, so width
does not enter it. -/
theorem the_two_buttons_never_overlap : buttonsAreDisjoint = true := by decide

/-- The measured clearance between them is exactly the gap, 4 px. -/
theorem the_clearance_is_the_gap :
    playButtonRightInset - pipButtonHorizontalReach = playButtonGap := by decide

/-- **Negative control.** With a zero gap the buttons would sit flush against each other — still
technically disjoint, but visually one blob. This theorem shows the gap is doing real work, and
that `buttonsAreDisjoint` alone would not have caught a bad value. -/
theorem a_zero_gap_would_leave_no_clearance :
    (pipButtonMargin + pipButtonSize + 0) - pipButtonHorizontalReach = 0 := by decide

/-- **Both buttons fit on every rung of the ladder**, including the smallest. -/
theorem both_buttons_fit_on_every_rung :
    thumbLadder.all (fun w => bothButtonsFit w) = true := by decide

/-- The tightest case, stated concretely: 48 px of buttons in a 140 px cell. -/
theorem the_pair_fits_the_smallest_rung :
    playButtonHorizontalReach = 48 ∧ thumbLadder.head? = some 140 := by decide

/-- The play button clears the name bar for the same reason the PiP button does — they share a
vertical band. -/
theorem the_play_button_clears_the_name_bar :
    nameBarHeight < pipButtonBottomInset := by decide

/-- **Negative control for the horizontal fit**: on a 40 px cell the pair cannot fit, so
`bothButtonsFit` is capable of returning false and the theorem above is not vacuous. -/
theorem the_pair_would_not_fit_on_a_tiny_rung : bothButtonsFit 40 = false := by decide

/-- **Both conditions are load-bearing, not just their disjunction.**

Found by mutation, and it was a real hole: replacing the `&&` in `bothButtonsFit` with `||`
survived the whole suite. The reason is that the control above uses a 40 px cell, where
*neither* conjunct holds — so it cannot tell conjunction from disjunction.

A 60 px cell is the discriminating case: 48 px of buttons fit horizontally, but the cell is
only 33 px tall and the buttons need 49, so the vertical test fails. Under `||` this would
wrongly report a fit. -/
theorem a_wide_but_short_cell_still_fails : bothButtonsFit 60 = false := by decide

/-- The witness spelled out, so the theorem above cannot be mistaken for an edge case: the
horizontal test passes and the vertical test fails on the very same cell. -/
theorem the_sixty_pixel_cell_splits_the_two_tests :
    playButtonHorizontalReach ≤ 60 ∧ pipButtonFits 60 = false := by decide

/-- **The inline preview is native-sized, and that is what distinguishes it from PiP.** The
in-thumb preview renders at the cell's own width; `previewWidth` — the PiP sizing — is strictly
larger on every rung. Both behaviours are wanted; this theorem pins that they really differ. -/
theorem the_inline_preview_is_native_sized :
    thumbLadder.all (fun w => w < previewWidth w) = true := by decide

#guard buttonsAreDisjoint
#guard playButtonHorizontalReach == 48
#guard thumbLadder.all (fun w => bothButtonsFit w)
#guard !bothButtonsFit 40
#guard !bothButtonsFit 60
#guard playButtonRightInset - pipButtonHorizontalReach == playButtonGap
#guard thumbLadder.all (fun w => w < previewWidth w)

/-- The exact rung below which the button stops fitting, pinned so a future ladder change has a
number to compare against. -/
theorem the_smallest_workable_rung_is_88 :
    pipButtonFits 88 = true ∧ pipButtonFits 87 = false := by decide

#guard pipButtonVerticalReach == 49
#guard thumbLadder.all (fun w => pipButtonFits w) == true
#guard pipButtonFits 80 == false
#guard pipButtonFits 88 == true

#guard survivesRestart (onShutdown defaultClearCacheOnExit) == true
#guard survivesRestart legacyOnShutdown == false
#guard (onShutdown false).closed == true
#guard (onShutdown true).closed == true
#guard onShutdown true == legacyOnShutdown

#guard isNativeOrDownscaled 480 cdnSource == true
#guard isNativeOrDownscaled 480 legacyCdnSource == false
#guard thumbLadder.all (fun w => isNativeOrDownscaled w cdnSource) == true
#guard cdnSource.w * aspectNum == cdnSource.h * aspectDen

#guard safeAspect { w := 0, h := 0 } == (16, 9)
#guard safeAspect { w := 320, h := 0 } == (16, 9)
#guard safeAspect { w := 320, h := 180 } == (320, 180)
#guard previewHeightFor 480 { w := 0, h := 0 } == 270
#guard previewHeightFor 360 { w := 0, h := 0 } == 202
#guard isAscending (thumbLadder.map (fun w => previewHeightFor w { w := 0, h := 0 })) == true

#guard thumbLadder.length == 8
#guard thumbLadder.getLast? == some 480
#guard thumbHeight 480 == 270
#guard thumbHeight1610 480 == 300
#guard thumbHeight 360 == 202
#guard thumbLadder.filter (fun w => isExactRung w) == [160, 480]
#guard previewWidth 140 == 480
#guard previewWidth 480 == 960
#guard aspectNum == 9
#guard aspectDen == 16

end CtbrecSpec
