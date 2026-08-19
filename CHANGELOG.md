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

## [7.0.0] — 2026-08-19

**Major: the working share.** 6.0.2 gave the lenses a dynamic share of the
prompt turn; 7.0.0 extends the share to the work itself. The lenses now
speak on the *result* — the moment a command comes back wrong-shaped, not
a timeout later — and the whole tree was re-studied, re-measured and
compressed around that idea until the un-gap ledger emptied.

### Added — the result sentinel: a lens speaks on the result itself

The Socio's scenario, delivered: a command stalls, returns a blank, or
returns something in between — and a lens notifies the convening model at
the moment the evidence exists, because hooks fire on harness events,
behind the reasoning layer. No timeout is waited out. On `PostToolUse`,
three clauses in precedence order, every guard a **measured** payload
field: a command the harness reports interrupted (the Claude lens — what
follows the cut was never run); a blank result without the harness's own
no-output sanction (Anti-Venom); a Write that stored zero bytes where
content was given (Anti-Venom, guarded on the input side so intentional
empty files stay silent). One clause at most, promoted onto the JSON
envelope with the marker; silence is the healthy state; `ROTMOE_VOICE=0`
silences it with the rest of the voice. The Edit tool's response shape was
not measured, so it is not read — both arms say so in place. The old
"Post is a deduplicated echo" comment gained its measured exception: a
result-aware line is new information, and the design note explains why.

### Added — the payload survey: measure the harness before reading it

The sentinel's fields were not taken from documentation — the docs were
wrong. `ROTMOE_DEBUG_PAYLOAD=1` (ENV.24) surveys each hook payload's
**key names** — never a value — into its own per-session sink. Run live,
it overruled the documented schema on the decisive fields: no exit code
reaches the hook; interruption and sanctioned silence do. The sentinel
ships on what was measured, and the instrument ships with it.

### Added — the goldens: one arm is enough to catch its own drift

Arm-vs-arm agreement cannot kill a single-arm mutation on a machine with
one arm. Two generated goldens close that: per-row hashes of the reminder
corpus, and per-profile gauge records carrying the **full-precision** lens
arrays — added after a planted λ retune provably survived the 2-decimal
human line and died against the record's digits. Both are rewritten only
by a deliberate `--make-golden` act with a banner; a stale golden is a
failure, not a shrug. Two checker mutants flipped from INEXPRESSIBLE to
KILLED on a PowerShell-less box, and the ones that remain machine-bound
are named as such instead of counted green.

### Added — the outcome study, preregistered before any run

`bench/ROT-STUDY-PREREGISTRATION.md`: three arms on matched real tasks,
outcome-blind grading against keys written with the tasks, and the blind
campaign's verdict — "wallpaper with a tax" — standing as the null
hypothesis. The design commits to printing a null as a null.

### Fixed — opting out of the gate no longer opts out of the cleanup

A summons written while the gate was armed survived every `ROTMOE_GATE=0`
turn, so the first Stop after re-arming was blocked for a turn long dead.
Both router arms now clear the summons even when the gate is off, and the
voice contract replays the exact scenario as a sequence probe.

### Fixed — a skip is a skip everywhere

The portability suite's sections this machine cannot run used to vanish
from the verdict. They are counted now, the summary names them, and the
suite exits 3 — the repository's did-not-run code — instead of wearing a
pass. A real failure still outranks a skip.

### Fixed — a reading that misleads is worse than none

`rot env get` read only two of the loader's three files and interpolated
its key into a regex. It now reads the loader's exact file order —
`ROTMOE_ENV` first — and refuses regex-shaped keys with the loader's own
charset, so what `get` prints is what `load` would use.

### Changed — the front page says what the tree measures, in half the lines

A truth pass fixed every stale claim the re-study surfaced: the seventh
organ joined its own table; the contract check count and module counts were
re-measured; the voices section was re-captured live from the shipped
tree, dynamic stanzas and sentinel envelope both quoted with their prompts;
comparison totals this machine cannot measure were replaced by what the
goldens actually hold. Then the compression: the front page dropped from
2,334 lines to 1,216 by moving its depth — the module arguments, the Lean
essay and corpus, the lens benchmark, the tips, the Easter Egg — verbatim
into five `docs/` files, each carrying its licence header and a backlink.
A new **Measured in the field** section puts the two campaigns on the
page: four graphs drawn from the bench records themselves, the
verdict-shaped gauge stated plainly, the 1-vs-52 gate-pressure contrast,
and the outcome question left honestly open. The citation gate's surface
follows the content: README plus exactly the five depth files, history
logs excluded by the same scope law the count binder already states.

### Changed — the charters cite what exists and their examples add up

The stuck-head exception cited a line that holds different text and quoted
a sentence that exists nowhere; three citers now point at the prover's
real Reporting contract. Nova's transcribed gauge bounds name their true
source and state that the router reads per-lane bands. Violet's worked
example adds up — four roles, four deltas, entropy inside her own band —
with the correction disclosed in place. Chroma's template no longer puts
all its probability on the branches it shows. The Claude lens cites the
README by section, because this very release moved the line numbers.
Deliberately untouched: Eidolon's hybrid-table defect disclosure, which is
the charter working, not drifting. The Lean sweep found the same disease
in two proof modules — front-page citations by line number, both now
pointing at the wrong text — fixed the same way, by section; everything
else that sweep surfaced is real, out of scope, and opens
`bench/ungap-7.1.md` so the next release starts where this one measured.
