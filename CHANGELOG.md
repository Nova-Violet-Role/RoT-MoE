# Changelog

All notable changes to **RoT MoE** are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) —
with one deliberate twist documented below.

**History lives in [`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md)** — every
release before the current one, unchanged. This file carries the current
release only, so *prior* and *after* stay one screen apart instead of eight
releases apart. `checker/repo-complete.sh` re-measures the counts in the newest
section against the source on every run, which is the reason that section must
not be buried.

---

## [8.0.0] — 2026-08-19

**Major: Animus — the paired observer.** 7.0.0 let a lens speak on the
result; 8.0.0 gives the whole roster a second pair of eyes. Two agents on
one task: a **worker** session solves it, and an **observer** process
watches what the worker actually *does* — its measured event stream, never
its prose — and injects the perspective the worker forgot, mid-run, through
the same channel the voices already use. The eighth organ, and the origin
of its name: self-distillation through hard study.

### Added — the observer: the router applied to its own records

`hooks/animus-observe.sh`, an operator tool (nothing registers it, it
blocks no turn, POSIX-only by design and the DTD says so). It tails the
worker's per-session debug sink at one-second cadence and fires on eight
**measured** triggers, every threshold a declared `ENV` row (`ENV.26–32`),
never a judgment a checker could not replay: AntiVenom on a recurring
result anomaly; Chroma on consecutive actions each costlier than the last,
and once per run when the task text routes PREDICTIVE and the stream never
goes there; Venom on prompt turns with no act between; Soleil on actions
growing longer every time; Eidolon on one lane+stem pair looping; Violet
once per run when the task routes EMPATHIC and the stream never visits the
register; and the Claude lens on a `PreToolUse` whose Post never lands —
the stall named while it is still happening, no timeout waited out.
Budgets are law: one remark per event, three per lens per run — a critic
that repeats is wallpaper, the blind campaign's own verdict. Every remark
appends to two distillates (project `.rot-moe/`, plus a global one in the
state dir; `ENV.33/34` override the paths) together with the measured
next-action delta — the three events before the injection against the
three after, quoted from the sink. The next run loads global first, then
project. `commands/animus.md` is the launch order.

### Added — the worker-side ear, in both router arms

Under `ROTMOE_ANIMUS=1` (`ENV.25`), each `PostToolUse` consumes at most
ONE queued remark FIFO from `animus-queue.<session>` and speaks it inside
the owning lens's **declared element**, tagged `(animus)` so remark and
gauge stanza can never be confused. The queue is cross-process, so both
sides are rename-atomic — the observer never touches an existing queue
file, the consumer takes the whole file before reading a byte — and a
consumed remark can never resurrect. A lens name outside the nine-element
roster is refused AND dropped, so a compromised queue writer can neither
mint a tenth voice nor jam the queue head. Empty queue = not a byte;
`ROTMOE_VOICE=0` silences remarks with the rest of the voice.

### Added — the sentinel's firing is now a record

Until this release a sentinel clause went to the envelope and nowhere
else: whether it ever fired was **unfalsifiable from the log**, the same
defect class the `event` field closed in 6.0.x — and the observer's
recurrence trigger would have had nothing to count. Both arms now write
one `kind:"anomaly"` line (shape and tool, central sink only) when a
clause fires, with the shape derived from the clause text itself so record
and clause cannot name different verdicts.

### Added — the contract around all of it

`checker/voice-contract.sh` **D14**: fifteen rows with negative controls —
consumption, FIFO order, empty-queue silence, the roster refusal and its
drop, the unarmed worker leaving the queue untouched, the off-switch
keeping the queue standing, a writer's half-landed tmp file staying
invisible, the anomaly record and its healthy-result control, the observer
firing on a planted recurrence and staying silent over an empty sink, and
the command file bound to the observer and the arm switch.
`checker/cross-diff.sh` gained an Animus phase: identical planted queues,
per-arm state dirs, envelopes compared byte for byte — refusal and
off-switch included, with a live control proving a genuine difference is
visible. The live paired probe ran the whole loop as two real processes:
two planted blanks, the remark queued within one poll, spoken on the
worker's third event.

### Held open — the Lean debt, named

The queue's take-and-remainder semantics and the trigger predicates are
held by the executable contract and the cross-arm comparison, **not yet by
theorems** — `bench/ungap-7.1.md` N10 carries that debt by name rather
than letting an organ ship pretending it was proved.
