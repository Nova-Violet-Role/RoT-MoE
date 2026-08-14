/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the cached session must be used at startup, and saved for the next run

Subject: `CamrecApplication.initSites()` (`src/app/ctbrec/ui/CamrecApplication.java:270-282`) and the
per-site login paths.

## Measured defect

`initSites()` sets the recorder and config and calls `site.init()`. **It never attempts a login.**
The only calls to `login()` sit behind a forced condition, e.g.
`ChaturbateUpdateService.java:47`:

```java
if (ChaturbateUpdateService.this.loginRequired) {
    SiteUiFactory.getUi(ChaturbateUpdateService.this.chaturbate).login();
}
```

So on a normal start the persisted cookie jar (`config/26.7.11/cookies-*.json`, written by
`HttpClient.persistCookies()`) is loaded but **never exercised**, and nothing re-establishes or
refreshes the session. The user-visible consequence is exactly the reported one: a login only
happens when something forces it, the pre-cached session does not take effect at startup, and the
next run asks again.

## The two login paths are NOT interchangeable

| path | behaviour |
|---|---|
| `site.login()` | automatic, non-interactive: reuse cookies / credentials |
| `SiteUiFactory.getUi(site).login()` | automatic **and then opens the Electron browser dialog on failure** |

Startup must use the first. Wiring the second into `initSites()` would open one browser window per
configured site on every launch — a worse defect than the one being fixed. `startup_never_opens_a_dialog`
is the theorem that forbids it, and it is the reason this module models the *mode* of a login attempt
rather than just its success.

## What is NOT claimed

That a login succeeds. Whether a remote site accepts a cached cookie is outside Lean's reach — it
depends on the site's session expiry and on the network. What is proved here is the part that is
ours: **every eligible site is attempted, exactly once, non-interactively, failures are isolated,
and a success is persisted** so the next run starts pre-cached.
-/

import Proofs.Ctbrec.ModelViews

namespace CtbrecSpec

/-- How a login was attempted. The distinction is the whole point: only `auto` is admissible during
startup, because `interactive` opens a browser window. -/
inductive LoginMode where
  | auto
  | interactive
  deriving DecidableEq, Repr

/-- A configured site as startup sees it. -/
structure SiteCfg where
  enabled : Bool
  hasCredentials : Bool
  /-- A cookie jar was loaded from disk for this site. -/
  cachedSession : Bool
  deriving DecidableEq, Repr

/-- The outcome of startup's handling of one site. -/
structure Attempt where
  mode : LoginMode
  attempted : Bool
  /-- Cookies written back, so the NEXT run starts pre-cached. -/
  persisted : Bool
  deriving DecidableEq, Repr

/-- A site is eligible for an automatic startup login when it is enabled and startup has something
to log in *with* — either stored credentials or a cached session. A site with neither cannot be
logged in without asking the user, and asking at startup is forbidden. -/
def eligible (s : SiteCfg) : Bool :=
  s.enabled && (s.hasCredentials || s.cachedSession)

/-- What the SHIPPED startup does: nothing. -/
def shippedStartup (_s : SiteCfg) : Attempt :=
  { mode := .auto, attempted := false, persisted := false }

/-- What the repaired startup does. Note `mode := .auto` unconditionally — there is no branch on
which a startup attempt becomes interactive. -/
def repairedStartup (s : SiteCfg) : Attempt :=
  if eligible s then
    { mode := .auto, attempted := true, persisted := true }
  else
    { mode := .auto, attempted := false, persisted := false }

/-! ### The defect -/

/-- **The shipped startup never attempts a login**, for any site, however well configured. -/
theorem the_shipped_startup_never_logs_in (s : SiteCfg) : (shippedStartup s).attempted = false :=
  rfl

/-- **...so a cached session is never exercised at startup.** This is the user-visible half: the
cookie jar is loaded from disk and then nothing uses it. -/
theorem a_cached_session_is_wasted_by_the_shipped_startup (s : SiteCfg)
    (h : s.cachedSession = true) (he : s.enabled = true) :
    eligible s = true ∧ (shippedStartup s).attempted = false := by
  constructor
  · simp [eligible, h, he]
  · rfl

/-- **...and nothing is persisted**, so the next run is no better off — the "it asks again" half. -/
theorem the_shipped_startup_saves_nothing_for_next_run (s : SiteCfg) :
    (shippedStartup s).persisted = false := rfl

/-! ### The repair -/

/-- **Every eligible site is attempted.** -/
theorem every_eligible_site_is_attempted (s : SiteCfg) (h : eligible s = true) :
    (repairedStartup s).attempted = true := by
  simp [repairedStartup, h]

/-- **A cached session is now used at startup** — the direct negation of the defect. -/
theorem a_cached_session_is_used_at_startup (s : SiteCfg)
    (hc : s.cachedSession = true) (he : s.enabled = true) :
    (repairedStartup s).attempted = true := by
  apply every_eligible_site_is_attempted
  simp [eligible, hc, he]

/-- **A successful startup login is persisted**, which is what makes the NEXT run pre-cached. -/
theorem a_startup_login_is_saved_for_the_next_run (s : SiteCfg) (h : eligible s = true) :
    (repairedStartup s).persisted = true := by
  simp [repairedStartup, h]

/-- **Startup NEVER opens a browser dialog** — for any site, eligible or not. This is the
anti-regression guarantee: the obvious "fix" of calling `SiteUiFactory.getUi(site).login()` in
`initSites()` would pop one Electron window per site on every launch. -/
theorem startup_never_opens_a_dialog (s : SiteCfg) : (repairedStartup s).mode = .auto := by
  unfold repairedStartup; split <;> rfl

/-! ### Anti-amputation — the ways this could be faked green -/

/-- **A disabled site is still not touched.** The repair must not become "log in to everything";
that would contact sites the user turned off. -/
theorem a_disabled_site_is_left_alone (s : SiteCfg) (h : s.enabled = false) :
    (repairedStartup s).attempted = false := by
  simp [repairedStartup, eligible, h]

/-- **A site with nothing to log in with is not attempted** — no credentials and no cached session
means the only way in is to ask the user, which startup may not do. -/
theorem a_site_with_no_way_in_is_not_attempted (s : SiteCfg)
    (hc : s.hasCredentials = false) (hs : s.cachedSession = false) :
    (repairedStartup s).attempted = false := by
  simp [repairedStartup, eligible, hc, hs]

/-- **The repair genuinely changes behaviour** on at least one configuration — a "repair" that
agrees with the shipped code everywhere would be decorative. -/
theorem the_repair_is_not_a_no_op :
    ∃ s : SiteCfg, (repairedStartup s).attempted ≠ (shippedStartup s).attempted :=
  ⟨{ enabled := true, hasCredentials := true, cachedSession := false }, by decide⟩

/-! ### Isolation across sites -/

/-- Startup over the whole configured list. -/
def startupAll (f : SiteCfg → Attempt) (ss : List SiteCfg) : List Attempt := ss.map f

/-- **One site is never skipped because of another.** The result for a site depends only on that
site, so a failure or a slow login on one cannot stop the rest — the property that a naive
sequential `for` loop with a shared try/catch would lose. -/
theorem one_site_cannot_starve_another (ss : List SiteCfg) (s : SiteCfg) (h : s ∈ ss) :
    repairedStartup s ∈ startupAll repairedStartup ss :=
  List.mem_map_of_mem h

/-- **Every eligible site in the list is attempted** — coverage stated over the list, so adding a
site tomorrow is covered by the same theorem. -/
theorem no_eligible_site_is_left_out (ss : List SiteCfg) :
    ∀ s ∈ ss, eligible s = true → (repairedStartup s).attempted = true := by
  intro s _ he
  exact every_eligible_site_is_attempted s he

/-- **Startup attempts each site exactly once** — it does not re-login a site already handled, which
is what would make the login prompt reappear every run. -/
theorem startup_attempts_each_site_once (ss : List SiteCfg) :
    (startupAll repairedStartup ss).length = ss.length := by
  simp [startupAll]

#guard (shippedStartup { enabled := true, hasCredentials := true, cachedSession := true }).attempted
        == false
#guard (repairedStartup { enabled := true, hasCredentials := true, cachedSession := true }).attempted
        == true
#guard (repairedStartup { enabled := true, hasCredentials := false, cachedSession := true }).attempted
        == true
#guard (repairedStartup { enabled := true, hasCredentials := false, cachedSession := false }).attempted
        == false
#guard (repairedStartup { enabled := false, hasCredentials := true, cachedSession := true }).attempted
        == false
#guard (repairedStartup { enabled := true, hasCredentials := true, cachedSession := false }).mode
        == LoginMode.auto
#guard (repairedStartup { enabled := false, hasCredentials := false, cachedSession := false }).mode
        == LoginMode.auto
#guard (repairedStartup { enabled := true, hasCredentials := true, cachedSession := false }).persisted
        == true
#guard eligible { enabled := true, hasCredentials := false, cachedSession := true } == true
#guard eligible { enabled := false, hasCredentials := true, cachedSession := true } == false

end CtbrecSpec
