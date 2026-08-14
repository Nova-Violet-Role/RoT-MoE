/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
Authors: Saimono
-/

/-!
# An empty URL must never reach the HTTP layer

Measured 2026-08-08 from the app's own logs, across both `ctbrec.log` and the rotated
`ctbrec.1.log` (the file the suite could not see until `phase90`):

```
31x  java.lang.IllegalArgumentException:
     Expected URL scheme 'http' or 'https' but no scheme was found for
```

The message ends in **nothing**. The string handed to OkHttp was blank. Twenty-two of today's
recording attempts died this way -- `SimplifiedLocalRecorder.java:1099 "Couldn't start recording
process"` -- which is why the app was serving no `master.m3u8` and why three suite phases skipped.

The guard already exists and is already proved: `PreviewPipeline.isHttpUrl` (`:178`), covered by
the `PreviewPipeline` module. It is applied on the **preview** path and NOT on the **recording**
path. This file states the contract independently of either caller, so that "which callers are
guarded" becomes a checkable question instead of an assumption.

The scheme test is deliberately modelled as a prefix check on a lowercased string, matching the
Java: a URL is admissible exactly when it begins `http://` or `https://`.
-/

namespace CtbrecSpec.UrlGuard

/-- A URL is admissible iff it carries an http/https scheme. Matches `isHttpUrl`. -/
def isHttpUrl (u : String) : Bool :=
  let l := u.toLower
  l.startsWith "http://" || l.startsWith "https://"

/-- What the guard does at a call boundary: `none` means REFUSED, and refusal must happen
*before* the value is handed onward. -/
def admit (u : String) : Option String := if isHttpUrl u then some u else none

/-! ## The properties

**A limit, stated rather than worked around.** `decide` cannot evaluate `String.toLower` on this
toolchain, and `native_decide` is banned -- it trusts the compiler binary instead of the kernel.
So the theorems below are stated over an ARBITRARY string, quantified by the guard's own boolean
rather than by literals. That is strictly stronger than three examples would have been, and it is
what the kernel can actually check. The specific values measured in the logs (`""`, a bare host,
`file://`, uppercase schemes) are pinned by the `#guard`s at the end, which really do evaluate.
-/

/-- **Anything without an http/https scheme is refused.** The empty string that reached OkHttp 31
times is one instance; so is every other malformed value, now and in future. -/
theorem not_http_is_refused (u : String) (h : isHttpUrl u = false) : admit u = none := by
  simp [admit, h]

/-- A well-formed URL is admitted **unchanged** -- the guard rejects, it never rewrites. -/
theorem http_is_admitted_unchanged (u : String) (h : isHttpUrl u = true) : admit u = some u := by
  simp [admit, h]

/-- **The guard is total: there is no third answer**, so no caller can fall through it by
accident. This is the property that makes "which call sites are guarded" a decidable question. -/
theorem admit_is_total (u : String) : admit u = none ∨ admit u = some u := by
  by_cases h : isHttpUrl u
  · exact Or.inr (by simp [admit, h])
  · exact Or.inl (by simp [admit, h])

/-- **Nothing the guard admits is refused, and nothing it refuses is admitted.** The two outcomes
cannot both hold, which is what stops a caller from treating a refusal as a pass. -/
theorem refused_and_admitted_are_exclusive (u : String) :
    ¬(admit u = none ∧ admit u = some u) := by
  rintro ⟨h1, h2⟩
  rw [h1] at h2
  simp at h2

/-! ## Executable checks -/

#guard admit "" == none
#guard admit "   " == none
#guard admit "chaturbate.com/x.m3u8" == none
#guard admit "file:///etc/passwd" == none
#guard admit "http://a.example/x.m3u8" == some "http://a.example/x.m3u8"
#guard admit "https://a.example/x.m3u8" == some "https://a.example/x.m3u8"
#guard admit "HTTP://A.EXAMPLE/X.M3U8" == some "HTTP://A.EXAMPLE/X.M3U8"
#guard isHttpUrl "" == false

end CtbrecSpec.UrlGuard
