/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-
CTBREC-REWORK spec: an unpublished stream is never requested (checklist item N1).

MEASURED 2026-08-13 in ctbrec.log. N1 recorded 82 x "Couldn't start recording process" and said
plainly: *unattributed -- could be the same DNS failure, could be ffmpeg launch. Attribute before
fixing.* The attribution:

    grep -A6 "Couldn't start recording process" ctbrec.log | ... | sort | uniq -c
      78  java.lang.IllegalArgumentException: Expected URL scheme 'http' or 'https' but no scheme
          was found for            <-- note: the URL is EMPTY
       2  java.io.IOException: Fresh Chaturbate master playlist URL unavailable for bunnydollstella
       1  java.io.IOException: Couldn't initialize Chaturbate LL-HLS downloader for CB:kellytesh
       1  ctbrec.io.HttpException: 429

    at okhttp3.Request$Builder.url(Request.kt:184)
    at ChaturbateModel.getMasterPlaylist(ChaturbateModel.java:645)
    at ChaturbateModel.resolveStreamSources(ChaturbateModel.java:696)

So N1 is NEITHER of its two hypotheses. Neither DNS nor ffmpeg: an empty string was passed to a URL
parser 78 times.

ORIGIN: requestStreamInfo encodes "this room publishes no stream" as `url = ""` with
`success = false` (ChaturbateModel.java:545-547) -- offline, private show, or geo-blocked.
`resolveStreamSources` then ignored `success`. `getResolution()` already guarded with exactly this
test (`!getStreamInfo().url.startsWith("http")`, ChaturbateModel.java:637); the request builder never
did. This is not a missing null check bolted onto a symptom -- it is the SAME guard the neighbouring
method already had, applied at the single point where the request is constructed.

NOT PROVED: that any given room is online. That is the site's business. What IS proved: no
unpublished stream ever reaches the URL parser, a published one always does, and the refusal names a
condition instead of a parse error.
-/

namespace Proofs.Ctbrec.StreamUrlGuard

/-- What `requestStreamInfo` produces. `url` is `""` when the room published no `hls_source`. -/
structure StreamInfo where
  url : String
  success : Bool
  deriving DecidableEq, Repr

/-- The test the code uses, and the one `getResolution` already used. -/
def usable (s : StreamInfo) : Bool := s.url.startsWith "http"

/-- What the guard does with an info: request it, or refuse with a named condition. -/
inductive Outcome where
  | requested (url : String)
  | refusedUnpublished
  deriving DecidableEq, Repr

def guard (s : StreamInfo) : Outcome :=
  if usable s then .requested s.url else .refusedUnpublished

/-- How `requestStreamInfo` builds the info from the payload's `hls_source`. -/
def fromPayload (hlsSource : Option String) : StreamInfo :=
  match hlsSource with
  | some u => if u.isEmpty then ⟨"", false⟩ else ⟨u, u.startsWith "http"⟩
  | none => ⟨"", false⟩

/-! ## Law 1 — THE law of N1 -/

/--
An unpublished stream is NEVER requested. This is the 78-error defect stated as a theorem: the empty
string cannot reach the URL parser.
-/
theorem an_unpublished_stream_is_never_requested :
    guard (fromPayload none) = .refusedUnpublished := by
  decide

theorem an_empty_hls_source_is_never_requested :
    guard (fromPayload (some "")) = .refusedUnpublished := by
  decide

/-- Generalised: no info whose url fails the http test is ever requested, whatever the url. -/
theorem nothing_unusable_is_ever_requested (s : StreamInfo) (h : usable s = false) :
    guard s = .refusedUnpublished := by
  simp [guard, h]

/-- The refusal is a NAMED condition, never a parse error: the two outcomes are distinguishable. -/
theorem a_refusal_is_not_a_request (s : StreamInfo) (h : usable s = false) :
    ∀ u, guard s ≠ .requested u := by
  intro u
  simp [guard, h]

/-! ## Law 2 — and the guard does not break the working path

A guard that refuses too much would be worse than the defect: it would stop every recording. This is
the half that keeps the fix from being a regression.
-/

/--
ANY published URL is still requested, unchanged and unaltered.

Stated over an arbitrary `u` rather than over the two literals measured on 2026-08-13. The literal
form was written first and `decide`/`rfl` both refused it — the kernel will not evaluate
`String.startsWith` on a 47-character URL — which turned out to be a gift: a theorem about two
specific URLs would have expired the day the CDN hostname changed, exactly the contingent-constant
defect this spec set forbids elsewhere. The measured URLs stay as `#guard`s at the foot of the file,
where they document the present without being load-bearing.
-/
theorem a_published_stream_is_still_requested (u : String) (h : u.startsWith "http" = true) :
    guard (fromPayload (some u)) = .requested u := by
  have hne : u.isEmpty = false := by
    by_cases he : u.isEmpty
    · rw [String.isEmpty_iff] at he
      subst he
      simp at h
    · simpa using he
  simp [fromPayload, guard, usable, hne, h]

/--
The decision rests on NOTHING but the scheme test — which is what makes it the same guard
`getResolution` already had, and why `http` and `https` are both accepted while a relative path and
`ftp://` are not (`#guard`s below).

(An earlier attempt stated this over `"http://" ++ host` and `"https://" ++ host`. `simp` hit the
maximum recursion depth on `String.startsWith` with a variable tail, and the statement was about
String internals rather than about this guard. This form is the content that matters.)
-/
theorem the_decision_is_exactly_the_scheme_test (s : StreamInfo) :
    (guard s = .requested s.url) ↔ (usable s = true) := by
  constructor
  · intro h
    by_cases hu : usable s = true
    · exact hu
    · have hf : usable s = false := by simpa using hu
      rw [guard, hf] at h
      simp at h
  · intro h
    simp [guard, h]

/-- The url passed on is EXACTLY the one received: the guard does not rewrite it. -/
theorem the_guard_never_alters_the_url (s : StreamInfo) (h : usable s = true) :
    guard s = .requested s.url := by
  simp [guard, h]

/-! ## Law 3 — the guard agrees with `success`, which the caller had ignored -/

/-- Anything the payload marks successful is usable, so the guard never refuses a good stream. -/
theorem success_implies_usable (hls : Option String) (h : (fromPayload hls).success = true) :
    usable (fromPayload hls) = true := by
  cases hls with
  | none => simp [fromPayload] at h
  | some u =>
      by_cases he : u.isEmpty
      · simp [fromPayload, he] at h
      · simpa [fromPayload, he, usable] using h

/-- And the converse for this constructor: usable implies the payload was marked successful. -/
theorem usable_implies_success (hls : Option String) (h : usable (fromPayload hls) = true) :
    (fromPayload hls).success = true := by
  cases hls with
  | none => simp [fromPayload, usable] at h
  | some u =>
      by_cases he : u.isEmpty
      · simp [fromPayload, he, usable] at h
      · simpa [fromPayload, he, usable] using h

/--
Therefore the guard is EXACTLY the `success` flag the caller ignored -- which is why this is a
one-line guard and not a new policy. Had `resolveStreamSources` honoured `success`, the 78 errors
would never have happened.
-/
theorem the_guard_is_exactly_the_ignored_success_flag (hls : Option String) :
    (guard (fromPayload hls) = .refusedUnpublished) ↔ ((fromPayload hls).success = false) := by
  constructor
  · intro h
    by_cases hs : (fromPayload hls).success = true
    · have := success_implies_usable hls hs
      simp [guard, this] at h
    · simpa using hs
  · intro h
    have : usable (fromPayload hls) = false := by
      by_cases hu : usable (fromPayload hls) = true
      · have := usable_implies_success hls hu
        rw [this] at h
        exact absurd h (by simp)
      · simpa using hu
    simp [guard, this]

/-! ## The measured payloads, as `#guard` -/

-- The 78-error case: no hls_source at all.
#guard guard (fromPayload none) == Outcome.refusedUnpublished
#guard guard (fromPayload (some "")) == Outcome.refusedUnpublished
-- A real URL measured by tools/probe/AudioUrlProbe.java.
#guard guard (fromPayload (some "https://edge11-fra.live.mmcdn.com/live-hls/x/chunklist_3.m3u8"))
    == Outcome.requested "https://edge11-fra.live.mmcdn.com/live-hls/x/chunklist_3.m3u8"
-- Junk that is neither: a relative path must NOT be requested.
#guard guard (fromPayload (some "/live-hls/x.m3u8")) == Outcome.refusedUnpublished
#guard guard (fromPayload (some "ftp://x/y")) == Outcome.refusedUnpublished
-- success and usable agree on every one of those.
#guard (fromPayload none).success == false
#guard (fromPayload (some "https://a/b")).success == true

end Proofs.Ctbrec.StreamUrlGuard
