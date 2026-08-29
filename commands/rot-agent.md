---
name: rot-agent
description: Dispatch one lens of the RoT MoE roster as a living agent on a subject, and present its report inside its declared element
argument-hint: <lens> [model=...] <subject...>
---

# `/rot-agent` — one lens, summoned by name

Dispatch a single lens of the nine-voice roster on a subject. The lens runs
as a real agent on the model the Socio selected (no lens pins a model), works
with real tools, and reports **inside its declared element** — the one
`hooks/rot-voice.dtd` binds it to.

## Step 1 — read the roster from the contract, never from memory

```sh
LC_ALL=C grep -o '<!ENTITY LENS[^>]*>' "$(dirname "$0")/../hooks/rot-voice.dtd" 2>/dev/null \
  || LC_ALL=C sed -n 's/.*<!ENTITY LENS\.[0-9]* *"\(.*\)">.*/\1/p' hooks/rot-voice.dtd
```

`LC_ALL=C` is load-bearing, not decoration. Under any UTF-8 locale the regex
engine will not cross the astral sigils (`🎷 🕷️ 🩸 🔮 🜏 🧭`) and the read
returns **three** rows — `⚜️ ⚪ ⬜`, the BMP three — at exit 0 with no
diagnostic. **Expect nine rows. Fewer than nine means the read failed, not
that the roster is small**; a partial parse is indistinguishable from a short
contract unless you count.

Each row is `name|element|sigil|charter|tools|bound`. The names are the
agents: `rot-nova`, `rot-violet`, `rot-antivenom`, `rot-venom`,
`rot-carnage`, `rot-chroma`, `rot-soleil`, `rot-eidolon`, `rot-claude`.

## Step 2 — parse the arguments

- The first word is the lens. Accept the short form (`nova`, `violet`,
  `antivenom`, `venom`, `carnage`, `chroma`, `soleil`, `eidolon`, `claude`)
  and map it to its `rot-` agent name.
- An unknown lens is a **refusal, with the roster printed** — do not guess a
  nearest match. A dispatch to a lens that does not exist in the contract is
  exactly what the contract exists to prevent.
- `model=<id>` overrides the inherited model for this one dispatch only.
  Absent, the lens runs on the Socio's selected model — that is the design,
  not a fallback.
- Everything after is the subject.

## Step 3 — dispatch

One Task call, `subagent_type` set to the lens's agent. Frame the subject for
the lens's charter and **restate its bound in the prompt** — the "may never"
line from the roster row — so the bound travels with the work.

## Step 4 — present

Present the lens's report **inside its declared element** (`<rot:nova>…
</rot:nova>`, and so on), and close with the standing rule: a lens's report
is a point of view with measurements, not a verdict about the whole — the
convening model synthesises, and on a proving question the compiler judges.
