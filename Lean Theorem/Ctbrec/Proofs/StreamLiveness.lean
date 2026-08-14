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
# "The app is running" and "a stream is live" are DIFFERENT propositions

This module exists because I conflated them for eleven authorised app runs, and then wrote two
successive WRONG diagnoses into `tools/live-preview-check.sh` before reading the source.

Measured 2026-08-08, `ChaturbateLlhlsMediaServer.java:28`:

```java
this.server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
```

Port **0** is ephemeral. The media server that answers `master.m3u8` is created **per stream** and
torn down when the stream ends. Consequences, each measured:

* app running, no stream  ->  `Get-NetTCPConnection -OwningProcess <pid>` returns **nothing**
* `webinterface` is NOT the switch -- flipping it to `true` still produced 0 listeners. That flag
  makes the app a *client* of a remote ctbrec-server.

The two wrong diagnoses I shipped were both of the shape *"the app is up, therefore the endpoint
should exist"*. That implication is exactly what `running_does_not_imply_live` refutes.

The payoff is operational: `liveStreamPresent` is a **cheap precondition**. Polling for a listening
socket rules a window out in seconds, where previously each attempt cost a full 10-minute suite run
to reach the same "skipped".
-/

namespace CtbrecSpec.StreamLiveness

/-- What can be observed about the app from outside, without reading its logs. -/
structure Observation where
  /-- A JVM process for the app exists. -/
  appRunning : Bool
  /-- The app's process owns at least one listening TCP socket. -/
  ownsListeningPort : Bool
  /-- `webinterface` in settings.json. Deliberately carried here so the theorems can show it is
  IRRELEVANT to stream liveness rather than leaving that as a comment. -/
  webinterface : Bool
deriving DecidableEq, Repr

/-- The ONLY sound test for "a stream is live": the app owns a listening socket. It must also be
running, since a dead process owns nothing. -/
def liveStreamPresent (o : Observation) : Bool := o.appRunning && o.ownsListeningPort

/-- The check's verdict. `some true` = phase can run, `some false` = app down,
`none` = running but no stream, i.e. SKIP. -/
def verdict (o : Observation) : Option Bool :=
  if !o.appRunning then some false
  else if liveStreamPresent o then some true
  else none

/-! ## The theorems -/

/-- **The error I actually made.** A running app does NOT imply a live stream. Exhibited by the
exact observation measured on runs 3-11: app up, no listening socket. -/
theorem running_does_not_imply_live :
    let o : Observation := { appRunning := true, ownsListeningPort := false, webinterface := false }
    o.appRunning = true ∧ liveStreamPresent o = false := by
  decide

/-- **`webinterface` is irrelevant to stream liveness.** For ANY observation, flipping that flag
leaves the verdict unchanged. This is the claim my CP135 message got backwards, stated over an
arbitrary observation so it cannot be true "by accident of today's settings". -/
theorem webinterface_is_irrelevant (o : Observation) :
    liveStreamPresent { o with webinterface := true }
      = liveStreamPresent { o with webinterface := false } := by
  simp [liveStreamPresent]

/-- The same, lifted to the verdict the phase actually acts on. -/
theorem verdict_ignores_webinterface (o : Observation) :
    verdict { o with webinterface := true } = verdict { o with webinterface := false } := by
  simp [verdict, liveStreamPresent]

/-- **A dead app is never live.** Guards against a check that reads a stale port list. -/
theorem not_running_is_never_live (o : Observation) (h : o.appRunning = false) :
    liveStreamPresent o = false := by
  simp [liveStreamPresent, h]

/-- **The port test is exactly right when the app is up**: no false negatives, no false positives. -/
theorem port_is_the_criterion (o : Observation) (h : o.appRunning = true) :
    liveStreamPresent o = o.ownsListeningPort := by
  simp [liveStreamPresent, h]

/-- **A skip is distinguishable from a failure.** `none` (running, no stream) is a THIRD outcome,
never `some false` (app down). Collapsing them would report a missing broadcast as a broken app --
which is the same conflation this module is named for. -/
theorem skip_is_not_app_down :
    let noStream : Observation := { appRunning := true, ownsListeningPort := false, webinterface := false }
    let appDown  : Observation := { appRunning := false, ownsListeningPort := false, webinterface := false }
    verdict noStream = none ∧ verdict appDown = some false := by
  decide

/-! ## Executable checks -/

private def run3to11 : Observation := { appRunning := true, ownsListeningPort := false, webinterface := false }
private def webifOn  : Observation := { appRunning := true, ownsListeningPort := false, webinterface := true }
private def streaming : Observation := { appRunning := true, ownsListeningPort := true, webinterface := false }

#guard liveStreamPresent run3to11 == false
#guard liveStreamPresent webifOn == false
#guard liveStreamPresent streaming == true
#guard verdict run3to11 == none
#guard verdict streaming == some true
#guard verdict { appRunning := false, ownsListeningPort := false, webinterface := true } == some false
#guard liveStreamPresent run3to11 == liveStreamPresent webifOn
#guard verdict webifOn == none

end CtbrecSpec.StreamLiveness
