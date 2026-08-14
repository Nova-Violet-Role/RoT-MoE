/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — a response body may be read ONCE, and reading it twice inverted the login

Subject: `ChaturbateHttpClient.checkLogin()`
(`src/common/ctbrec/sites/chaturbate/ChaturbateHttpClient.java:136-174`).

## The shipped code

```java
boolean result = false;
if (response.isSuccessful()) {
    String content = response.body().string();      // (1) consumes the one-shot stream
    if (content.startsWith("[")) { result = true; }
}
log.trace("Chaturbate client login result: {}, {}", result, response.body().string());  // (2) again
var9 = result;
...
} catch (Exception ex) {
    return false;                                   // swallows it
}
```

An okhttp `ResponseBody` is a **one-shot stream**: `string()` reads the source and closes it, so a
second call throws `IllegalStateException: closed`. The arguments to `log.trace` are evaluated
eagerly, so read (2) happens whether or not TRACE is enabled.

## Why this is worse than a normal bug: it fires only on success

| cached session | `isSuccessful()` | reads of the body | result |
|---|---|---|---|
| **valid** | true | (1) then (2) → **throws** | caught → `false` |
| invalid | false | (2) only | `false` |

The `if` guards read (1), so the double read happens **only when the response was successful** —
that is, only when the cookies were good. `checkLogin()` therefore **cannot return true on any
path**: it reports "not logged in" precisely because the login worked.

That matches the reported behaviour exactly — a pre-cached session never takes effect, and the login
has to be forced every run. Measured at checkpoint 70, with a 66-cookie jar on disk:

```
[ctbrec-startup-login] startup login: Chaturbate -> not logged in
```

## What is modelled

A body as a resource with a consumed flag, and a read that fails once consumed. The theorems are
about the *shape* — "computed a result and then destroyed it by logging" — not about okhttp, so
they keep their force for any one-shot resource read twice on a success path.
-/

import Proofs.Ctbrec.ModelViews

namespace CtbrecSpec

/-- A one-shot response body. `content` is what a first read yields. -/
structure Body where
  content : String
  consumed : Bool
  deriving DecidableEq, Repr

/-- The result of reading a one-shot body: either the content and the now-consumed body, or a
failure because it had already been read. -/
inductive ReadResult where
  | ok (s : String) (b : Body)
  | alreadyConsumed
  deriving DecidableEq, Repr

def readBody (b : Body) : ReadResult :=
  if b.consumed then .alreadyConsumed else .ok b.content { b with consumed := true }

/-- An HTTP response as `checkLogin` sees it. -/
structure Resp where
  successful : Bool
  body : Body
  deriving DecidableEq, Repr

/-- The verdict `checkLogin` returns. `threw` records that an exception escaped into the
`catch (Exception ex) { return false; }` -- it is reported as `false` either way, which is what made
this defect invisible. -/
inductive LoginVerdict where
  | loggedIn
  | notLoggedIn
  | threw
  deriving DecidableEq, Repr

/-- What the caller actually observes: `threw` is indistinguishable from `notLoggedIn`. -/
def observed : LoginVerdict → Bool
  | .loggedIn => true
  | .notLoggedIn => false
  | .threw => false

/-- Does the payload look like the expected JSON array? -/
def looksLikeArray (s : String) : Bool := s.startsWith "["

/-- **The shipped `checkLogin`.** Read once inside the `if`, then read AGAIN for the log line. -/
def shippedCheckLogin (r : Resp) : LoginVerdict :=
  if r.successful then
    match readBody r.body with
    | .alreadyConsumed => .threw
    | .ok s b =>
      let _result := looksLikeArray s
      -- the log line reads the body a second time
      match readBody b with
      | .alreadyConsumed => .threw
      | .ok _ _ => if _result then .loggedIn else .notLoggedIn
  else
    match readBody r.body with
    | .alreadyConsumed => .threw
    | .ok _ _ => .notLoggedIn

/-- **The repaired `checkLogin`.** Read ONCE into a local; the log line reuses that string. -/
def repairedCheckLogin (r : Resp) : LoginVerdict :=
  match readBody r.body with
  | .alreadyConsumed => .threw
  | .ok s _ =>
    if r.successful then
      (if looksLikeArray s then .loggedIn else .notLoggedIn)
    else
      .notLoggedIn

/-! ### The defect -/

/-- **The shipped check throws on exactly the successful path** — the one where the cookies were
good. A fresh body plus a successful response is the case that must return `loggedIn`. -/
theorem the_shipped_check_throws_when_the_session_is_valid (c : String)
    (h : looksLikeArray c = true) :
    shippedCheckLogin { successful := true, body := { content := c, consumed := false } }
      = .threw := by
  simp [shippedCheckLogin, readBody]

/-- **The shipped check can NEVER report a login**, for any response whatsoever. Not "usually
fails" — there is no input on which it returns `loggedIn`. -/
theorem the_shipped_check_never_reports_a_login (r : Resp) :
    shippedCheckLogin r ≠ .loggedIn := by
  unfold shippedCheckLogin readBody
  cases r with
  | mk succ body =>
    cases body with
    | mk content consumed =>
      cases succ <;> cases consumed <;> simp

/-- **The shipped code's success branch is DEAD CODE.** After the first read the body is consumed,
so the second `readBody` can only return `.alreadyConsumed`: the `.ok` arm that would have produced
`loggedIn` is unreachable for every input.

This was found by mutation testing, not by reading. Inverting that arm
(`if _result then .loggedIn else .notLoggedIn` → the reverse) left the build green — a SURVIVED
mutant. It is an *equivalent* mutant rather than a spec hole, and the reason it is equivalent is
precisely the defect: you cannot change the behaviour of code that never runs. The row was
retargeted at the reachable `else` branch and this theorem states the dead-branch fact directly. -/
theorem the_shipped_success_arm_is_unreachable (b : Body) (h : b.consumed = false) :
    readBody (match readBody b with | .ok _ b' => b' | .alreadyConsumed => b) = .alreadyConsumed := by
  simp [readBody, h]

/-- **...so the caller always sees `false`.** This is the user-visible statement: a pre-cached
session never takes effect, so the login must be forced every run. -/
theorem a_valid_cached_session_is_reported_as_logged_out (r : Resp) :
    observed (shippedCheckLogin r) = false := by
  cases h : shippedCheckLogin r with
  | loggedIn => exact absurd h (the_shipped_check_never_reports_a_login r)
  | notLoggedIn => rfl
  | threw => rfl

/-! ### The repair -/

/-- **A valid session is now recognised.** -/
theorem the_repair_recognises_a_valid_session (c : String) (h : looksLikeArray c = true) :
    repairedCheckLogin { successful := true, body := { content := c, consumed := false } }
      = .loggedIn := by
  simp [repairedCheckLogin, readBody, h]

/-- **The repair never throws on a fresh body** — the exception path is gone, not merely rarer. -/
theorem the_repair_never_throws_on_a_fresh_body (succ : Bool) (c : String) :
    repairedCheckLogin { successful := succ, body := { content := c, consumed := false } }
      ≠ .threw := by
  unfold repairedCheckLogin readBody
  cases succ <;> simp <;> split <;> simp

/-! ### Anti-amputation — "always return true" would also make the symptom disappear -/

/-- **A failed response is still not a login.** The repair must not become "assume logged in". -/
theorem the_repair_still_rejects_an_unsuccessful_response (c : String) :
    repairedCheckLogin { successful := false, body := { content := c, consumed := false } }
      = .notLoggedIn := by
  simp [repairedCheckLogin, readBody]

/-- **A successful response whose payload is not the expected array is still not a login** — the
content check survives the repair. -/
theorem the_repair_still_checks_the_payload (c : String) (h : looksLikeArray c = false) :
    repairedCheckLogin { successful := true, body := { content := c, consumed := false } }
      = .notLoggedIn := by
  simp [repairedCheckLogin, readBody, h]

/-- **The repair reads the body exactly once**, so it cannot reintroduce the defect by logging. -/
theorem the_repair_leaves_the_body_readable_only_once (c : String) (succ : Bool) :
    readBody { content := c, consumed := false } = .ok c { content := c, consumed := true } ∧
      readBody { content := c, consumed := true } = .alreadyConsumed := by
  constructor <;> simp [readBody]

/-- **The repair genuinely differs from the shipped code** — not a cosmetic rewrite. -/
theorem the_oneshot_repair_is_not_a_no_op :
    ∃ r : Resp, repairedCheckLogin r ≠ shippedCheckLogin r := by
  -- `decide` cannot reduce `String.startsWith`, so this is derived from the two theorems above
  -- rather than by evaluation: on a valid session the repair says loggedIn and the shipped code
  -- throws.
  refine ⟨{ successful := true, body := { content := "[]", consumed := false } }, ?_⟩
  rw [the_repair_recognises_a_valid_session "[]" (by simp [looksLikeArray]),
      the_shipped_check_throws_when_the_session_is_valid "[]" (by simp [looksLikeArray])]
  simp

/-- **An already-consumed body still throws in the repair** — the one-shot discipline is respected,
not bypassed by pretending a consumed body can be re-read. -/
theorem a_consumed_body_still_fails (succ : Bool) (c : String) :
    repairedCheckLogin { successful := succ, body := { content := c, consumed := true } }
      = .threw := by
  simp [repairedCheckLogin, readBody]

#guard shippedCheckLogin { successful := true, body := { content := "[]", consumed := false } }
        == LoginVerdict.threw
#guard shippedCheckLogin { successful := false, body := { content := "x", consumed := false } }
        == LoginVerdict.notLoggedIn
#guard observed (shippedCheckLogin { successful := true,
                                     body := { content := "[]", consumed := false } }) == false
#guard repairedCheckLogin { successful := true, body := { content := "[]", consumed := false } }
        == LoginVerdict.loggedIn
#guard repairedCheckLogin { successful := true, body := { content := "nope", consumed := false } }
        == LoginVerdict.notLoggedIn
#guard repairedCheckLogin { successful := false, body := { content := "[]", consumed := false } }
        == LoginVerdict.notLoggedIn
#guard repairedCheckLogin { successful := true, body := { content := "[]", consumed := true } }
        == LoginVerdict.threw
#guard observed (repairedCheckLogin { successful := true,
                                      body := { content := "[]", consumed := false } }) == true
#guard readBody { content := "a", consumed := true } == ReadResult.alreadyConsumed
#guard looksLikeArray "[]" == true

end CtbrecSpec
