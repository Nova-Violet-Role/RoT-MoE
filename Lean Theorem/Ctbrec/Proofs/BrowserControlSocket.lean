/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the minimal browser's control socket

Subject: `lib/browser/resources/app/main.js:88`, the Electron browser ctbrec drives to log
into sites. It opens a TCP server to receive commands from the Java side:

```js
}).listen(3202);
```

`net.Server.listen(port)` with **no host argument binds to all interfaces**. MEASURED on
this machine — the browser launched headless, then `netstat`:

```
TCP    0.0.0.0:3202    0.0.0.0:0    LISTENING    14684
TCP    [::]:3202       [::]:0       LISTENING    14684
```

## Why this is a real vulnerability, not a lint

The command protocol is `{"execute": "<javascript>"}`; the browser runs the string in the
page it is displaying (`main.js:64`, `webContents.executeJavaScript`). ctbrec drives this
browser to **log into chaturbate.com with the user's credentials**, and it stays logged in
for the session. So while a recording session is active, any host that can reach TCP 3202
on this machine — **any device on the same LAN, a coffee-shop network, a compromised IoT
device** — can send one line and execute arbitrary JavaScript inside an authenticated
session: read cookies, issue `send_tip`, change the password.

The Java client connects to `new Socket("localhost", 3202)` (`ExternalBrowser.java:105`),
so **nothing on the wire needs a non-loopback address**. Binding to `127.0.0.1` closes the
hole with zero functional change — the exposure was gratuitous.

## What is modelled

A bind address, and whether an incoming connection from a given peer is accepted. The
theorem that matters:

> A socket bound to loopback accepts loopback peers and **rejects every remote peer**; a
> socket bound to the wildcard accepts everyone.

`loopback_rejects_remote` is the fix; `wildcard_accepts_remote` is the measured
vulnerability; `fix_preserves_the_local_client` is the anti-regression clause — the Java
client, being loopback, still connects.
-/

namespace CtbrecSpec

/-- A peer's address class, coarse enough to decide reachability. -/
inductive Peer where
  /-- 127.0.0.0/8 or ::1 — same machine. -/
  | loopback
  /-- Any address reachable from another host: LAN, VPN, internet. -/
  | remote
  deriving DecidableEq, Repr, Inhabited

/-- Where the server binds. -/
inductive Bind where
  /-- `listen(port, '127.0.0.1')` — loopback only. -/
  | loopbackOnly
  /-- `listen(port)` with no host — 0.0.0.0 / ::, every interface. -/
  | wildcard
  deriving DecidableEq, Repr, Inhabited

/-- **The reachability rule.** A wildcard bind accepts anyone; a loopback bind accepts only
loopback peers. This is the actual semantics of `net.Server.listen`. -/
def accepts (b : Bind) (p : Peer) : Bool :=
  match b, p with
  | .wildcard, _ => true
  | .loopbackOnly, .loopback => true
  | .loopbackOnly, .remote => false

/-- What `main.js` shipped: `listen(3202)`, no host. -/
def shippedBind : Bind := .wildcard

/-- The fix: `listen(3202, '127.0.0.1')`. -/
def fixedBind : Bind := .loopbackOnly

/-! ## The properties -/

/-- **The measured vulnerability**: the shipped bind accepts a remote peer. This is the
`0.0.0.0:3202 LISTENING` observed with netstat, stated as the thing an attacker needs. -/
theorem shipped_accepts_remote : accepts shippedBind Peer.remote = true := by decide

/-- **The fix**: a loopback bind rejects every remote peer. Stated over the peer so it is
not an accident of one address. -/
theorem loopback_rejects_remote : accepts fixedBind Peer.remote = false := by decide

/-- More generally, the only bind that rejects a remote peer is the loopback one — so the
fix is not merely *a* way to close the hole, it is the characterising property. -/
theorem remote_rejected_iff_loopback_bind (b : Bind) :
    accepts b Peer.remote = false ↔ b = Bind.loopbackOnly := by
  cases b <;> simp [accepts]

/-- **Anti-regression**: the fix does not break the local client. The Java side connects
from `localhost`, i.e. a loopback peer, and a loopback bind still accepts it. Without this
theorem the "fix" could be "bind to nothing", which also rejects remote peers and also
breaks the app. -/
theorem fix_preserves_the_local_client : accepts fixedBind Peer.loopback = true := by decide

/-- The change is strictly a tightening: every peer the fixed bind accepts, the shipped
bind also accepted. Nothing that worked stops working; only remote access is removed. -/
theorem fix_only_removes_access (p : Peer) :
    accepts fixedBind p = true → accepts shippedBind p = true := by
  cases p <;> decide

/-- And it is a real change, not a rename: there is a peer the two binds treat differently,
and it is exactly the remote one. -/
theorem fix_actually_changes_behaviour :
    ∃ p : Peer, accepts shippedBind p ≠ accepts fixedBind p := by
  exact ⟨Peer.remote, by decide⟩

/-- The set of peers a loopback bind serves is exactly `{loopback}` — the tightest bind
that still lets the app work. -/
theorem loopback_serves_exactly_the_local_host (p : Peer) :
    accepts fixedBind p = true ↔ p = Peer.loopback := by
  cases p <;> simp [accepts, fixedBind]

/-! ## Navigation: the browser must always end up loading the page

A second defect in the same file, and this one was **live**, not merely latent
(`main.js`, the `msg.config` branch):

```js
session.setProxy(proxyConfig, () => { ...; mainWindow.loadURL(args.url); });
```

`setProxy` is **Promise-based**; the callback form was removed years ago and the second
argument is ignored. So the callback never ran and `loadURL` was **never reached**.

MEASURED end to end by driving the shipped browser over its own control socket:

| config | result |
|---|---|
| without proxy | `{"url":"https://example.com/","cookies":[]}` — page loaded |
| **with proxy** | **no event at all after 18 s, 0 events** — never navigated |

Every user with a proxy configured had a permanently blank browser and could not log in.
After the fix, the same probe returns `Proxy settings configured` followed by the page-load
event, and the no-proxy path is unchanged.

The property worth proving is not "the promise resolves" — it is that **navigation happens
on every path**, including when `setProxy` rejects. A `.then` without a `.catch` would swap
one hang for a rarer one. -/

/-- Whether the config asked for a proxy, and how `setProxy` answered. -/
inductive ProxyOutcome where
  /-- No proxy in the config: navigate directly. -/
  | noProxy
  /-- `setProxy` resolved. -/
  | resolved
  /-- `setProxy` rejected — a bad proxy string, for instance. -/
  | rejected
  deriving DecidableEq, Repr, Inhabited

/-- Every case the code can face. -/
def allProxyOutcomes : List ProxyOutcome := [.noProxy, .resolved, .rejected]

/-- What the shipped code did: with a proxy configured it waited on a callback that never
fired, so it never navigated. Without a proxy it navigated immediately. -/
def legacyNavigates : ProxyOutcome → Bool
  | .noProxy => true
  | .resolved => false   -- the callback was ignored; loadURL was never called
  | .rejected => false

/-- The fix: `.then` navigates, and `.catch` navigates too rather than hanging. -/
def fixedNavigates : ProxyOutcome → Bool
  | .noProxy => true
  | .resolved => true
  | .rejected => true

/-- **The property that matters: navigation happens on every path.** Not "the promise
resolves" — a `.then` with no `.catch` would still hang whenever `setProxy` rejected, which
is the same defect wearing a different hat. -/
theorem navigation_happens_on_every_path (o : ProxyOutcome) : fixedNavigates o = true := by
  cases o <;> decide

/-- **The measured defect**: with a proxy configured, the shipped code never navigated. -/
theorem legacy_never_navigates_with_a_proxy :
    legacyNavigates ProxyOutcome.resolved = false ∧
      legacyNavigates ProxyOutcome.rejected = false := by decide

/-- **Anti-regression**: the path that already worked still works. If this failed, the fix
would have traded one broken configuration for another. -/
theorem fix_preserves_the_no_proxy_path :
    legacyNavigates ProxyOutcome.noProxy = true ∧
      fixedNavigates ProxyOutcome.noProxy = true := by decide

/-- The fix is strictly an improvement: everything that navigated before still navigates,
and something that did not now does. -/
theorem navigation_fix_is_strictly_stronger :
    (∀ o, legacyNavigates o = true → fixedNavigates o = true) ∧
      ∃ o, legacyNavigates o = false ∧ fixedNavigates o = true := by
  refine ⟨fun o h => by cases o <;> simp_all [legacyNavigates, fixedNavigates], ?_⟩
  exact ⟨ProxyOutcome.resolved, by decide, by decide⟩

/-- Exactly two of the three cases were broken, and they are precisely the proxy ones.
Pins the defect to its cause so a mutation that widens or narrows it is caught. -/
theorem exactly_the_proxy_paths_were_broken :
    (allProxyOutcomes.filter (fun o => !legacyNavigates o)).length = 2 ∧
      (allProxyOutcomes.filter (fun o => !fixedNavigates o)).length = 0 := by decide

#guard (allProxyOutcomes.filter legacyNavigates).length == 1
#guard (allProxyOutcomes.filter fixedNavigates).length == 3

/-! ## Executable checks -/

#guard accepts shippedBind Peer.remote == true      -- the hole
#guard accepts fixedBind Peer.remote == false       -- closed
#guard accepts fixedBind Peer.loopback == true      -- client still works
#guard accepts shippedBind Peer.loopback == true    -- and worked before

/-- The port is unchanged — only the host is added. Recorded so the fix is understood as a
one-argument change, not a protocol change. -/
def controlPort : Nat := 3202

#guard controlPort == 3202

end CtbrecSpec
