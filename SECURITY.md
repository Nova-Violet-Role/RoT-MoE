<!-- SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2 -->
<!-- Copyright 2026 Saimonokuma. -->

# Security Policy

## What this software does to your machine

`ARM_ROUTER.sh` / `ARM_ROUTER.ps1` **edit `~/.claude/settings.json`** — a file
your Claude Code session depends on. That is the whole security surface, and it
is stated first because it is the thing worth auditing before you run anything
here.

The installer's contract, and how each part is verified rather than promised:

| rule | verified by |
|---|---|
| backs up first, prints the restore command | `checker/install-roundtrip.sh` |
| additive merge only — parses, appends, writes back | never a template rewrite |
| preserves **every** key it did not add, deep-compared | control C1 destroys a nested key and is detected |
| validates by **re-reading from disk**, auto-restores on any deviation | control C5: an invalid input is refused, file left untouched |
| idempotent by command string | control C3 plants a duplicate and is detected |
| never `sudo`, never leaves the config dir | — |

It does **not** phone home, download anything, or execute code from the network.
The router reads a JSON payload on stdin and prints one line.

### Where the router runs, stated plainly

Understating this would be the dishonest part. Once armed, the router executes
**on every prompt you submit** (`UserPromptSubmit`) and **before every tool call**
(`PreToolUse`). That is a program running on your machine, with your privileges,
very often. Installing it deserves the scrutiny you would give any shell hook.

`hooks/rot-router.sh` and `hooks/rot-router.ps1` are short and deliberately
readable. **Read them before arming.** That is a reasonable thing to ask of any
hook, this one included.

What it does from that position: reads the JSON payload on stdin, extracts the
`prompt` field to choose a lane, prints one line. It does not read your source
files, your credentials or your history, and it writes nothing outside its own
scratch directories.

### See the change before consenting to it

```sh
bash ARM_ROUTER.sh --dry-run      # or: pwsh -File ARM_ROUTER.ps1 -DryRun
```

Runs the entire merge against a **copy**, prints exactly what would change, and
writes nothing. Not a flag checked at the write site — that is one forgotten
branch away from writing anyway — but a redirected target that cannot reach your
real file. Asserted by `checker/install-roundtrip.sh`, which requires the file to
be byte-identical after a dry run.

## Reporting a vulnerability

Open a **private security advisory** on the repository, or an issue if it is not
sensitive. Please include your OS, shell, `node --version`, and the relevant
lines of your `settings.json` **with any credentials removed**.

## Scope we care most about

1. Anything that makes the installer **damage or leak** `settings.json`.
2. Anything that makes the router **execute** attacker-controlled content. It
   parses JSON and does substring matching; it must never evaluate.
3. Any path where a checker **passes while the property it names is false** — a
   false green is treated here as a defect of the same severity as a crash.
4. **A theorem whose name or doc comment claims more than its statement proves.**
   In a project whose entire value is that its claims are checkable, an
   overclaimed proof *is* a security defect: it launders an assumption into an
   apparent guarantee. Report it as one, and it will be fixed by restating the
   theorem — never by deleting the check that exposed it.

**Response commitment:** acknowledgement within 7 days. This is a non-profit
project maintained by one person, so that is a realistic number rather than an
aspirational one.

## What is out of scope, stated honestly

* The Lean proofs constrain the **model**, not your filesystem. `RotInstall.lean`
  proves the merge is sound; it cannot see byte-order marks, line endings or key
  order. That gap is the checker's job and is documented in `NOTICE.md`.
* Output *quality* of any model using this router is not something this repo
  measures, and no theorem here claims otherwise.
