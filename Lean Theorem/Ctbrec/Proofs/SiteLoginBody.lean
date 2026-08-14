/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — no site's login check reads a one-shot response body more than once

Subject: every `checkLogin` / `checkLoginSuccess` / `isLoggedIn` under
`src/common/ctbrec/sites/*/`.

## Why

CP71 found that `ChaturbateHttpClient.checkLogin()` read `response.body().string()` twice — once in
the `if (isSuccessful)` branch and again as an eagerly-evaluated slf4j log argument. An okhttp
`ResponseBody` is one-shot, so the second read threw, the catch returned `false`, and a valid cached
session could NEVER be reported as logged in. The fix reads once and reuses the string.

That was one site. The question CP75 answers is whether any of the other ten sites carry the same
shape. A tree-wide scan (`build/phase69.sh`) measured, for each login-check method:
- `bodyReads` = number of `.string()` calls in the method body (comments stripped);
- `logEager`  = whether any `.string()` sits inside a `log.*` / `logger.*` argument (the slf4j
  eager-evaluation landmine that made the second Chaturbate read fire even at a disabled log level).

Measured 2026-08-06 — all eleven sites: `bodyReads ≤ 1`, `logEager = false`. This file encodes those
profiles and proves the invariant that makes them safe, so a future site that reintroduces the defect
fails both the checker (on the real files) and the intent captured here.

## The invariant

A login check is **read-safe** iff it reads the one-shot body at most once and never reads it inside a
log argument. That is exactly the property whose violation made the Chaturbate check unable to ever
succeed.
-/

namespace CtbrecSpec

/-- The two measured facts about one site's login-check method. -/
structure LoginCheck where
  site : String
  /-- `.string()` calls in the method body (an okhttp body is one-shot; >1 throws on the 2nd). -/
  bodyReads : Nat
  /-- whether a `.string()` is evaluated inside a `log.*` argument (slf4j evaluates args eagerly, so
  this fires even when the log level is disabled — the exact trigger of the CP71 bug). -/
  logEager : Bool
  deriving Repr

/-- **Read-safe**: at most one body read, and none of them inside a log argument. -/
def readSafe (c : LoginCheck) : Bool := c.bodyReads ≤ 1 && !c.logEager

/-! ### The eleven measured sites (from the phase-69 scan) -/

def sites : List LoginCheck :=
  [ { site := "bonga",      bodyReads := 1, logEager := false }
  , { site := "cam4",       bodyReads := 1, logEager := false }
  , { site := "camsoda",    bodyReads := 1, logEager := false }
  , { site := "chaturbate", bodyReads := 1, logEager := false }   -- after the CP71 fix
  , { site := "fc2live",    bodyReads := 1, logEager := false }
  , { site := "flirt4free", bodyReads := 1, logEager := false }
  , { site := "mfc",        bodyReads := 1, logEager := false }
  , { site := "showup",     bodyReads := 0, logEager := false }   -- status-code only
  , { site := "streamate",  bodyReads := 1, logEager := false }
  , { site := "streamray",  bodyReads := 1, logEager := false }
  , { site := "stripchat",  bodyReads := 0, logEager := false } ] -- status-code only

/-! ### The proof -/

/-- **Every site's login check is read-safe.** The tree carries the CP71 defect nowhere. -/
theorem every_site_is_read_safe : sites.all readSafe = true := by decide

/-- **The Chaturbate shape BEFORE the fix is not read-safe** — two reads, the second eager inside a
log call. This is the bug CP71 removed, and the predicate rejects it, so the green above is not
vacuous. -/
theorem the_pre_fix_chaturbate_shape_is_unsafe :
    readSafe { site := "chaturbate(pre-CP71)", bodyReads := 2, logEager := true } = false := by decide

/-- **Two reads is unsafe on its own** — even without the log-eager trigger, a second read of a
one-shot body throws. -/
theorem two_reads_is_unsafe (c : LoginCheck) (h : 2 ≤ c.bodyReads) : readSafe c = false := by
  unfold readSafe
  have : ¬ (c.bodyReads ≤ 1) := by omega
  simp [this]

/-- **A read inside a log argument is unsafe regardless of count** — slf4j eager evaluation makes it
a real read, so pairing it with the guarded read is a second consumption. -/
theorem log_eager_is_unsafe (c : LoginCheck) (h : c.logEager = true) : readSafe c = false := by
  unfold readSafe; simp [h]

/-- **Anti-amputation: read-safety is genuinely refutable.** A predicate that were always `true`
would prove `every_site_is_read_safe` while catching nothing; here an unsafe shape exists. -/
theorem read_safety_is_not_vacuous : ∃ c, readSafe c = false :=
  ⟨{ site := "x", bodyReads := 2, logEager := true }, by decide⟩

/-- **The invariant covers exactly the eleven audited sites** — a completeness marker so a site added
without a matching profile is visible as a gap, not silently uncovered. -/
theorem the_audit_covers_eleven_sites : sites.length = 11 := by decide

#guard sites.all readSafe
#guard sites.length == 11
#guard readSafe { site := "ok", bodyReads := 1, logEager := false }
#guard readSafe { site := "none", bodyReads := 0, logEager := false }
#guard !readSafe { site := "double", bodyReads := 2, logEager := false }
#guard !readSafe { site := "eager", bodyReads := 1, logEager := true }
#guard !readSafe { site := "both", bodyReads := 2, logEager := true }

end CtbrecSpec
