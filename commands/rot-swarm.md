---
name: rot-swarm
description: Put the whole nine-lens roster on one subject simultaneously, one agent per lens on the Socio's model, and synthesise without flattening the disagreements
argument-hint: [lenses=nova,venom,...] [model=...] <the one subject everyone examines>
---

# `/rot-swarm` — nine points of view, one subject, at once

Put the roster on one problem at the same time. Nine perspectives, one
subject, one synthesis that **keeps the tensions** — a disagreement between
lenses is a finding, not noise. This is the deep form of what the voice
block does per-turn: real agents, real tools, each on the model the Socio
selected.

## Step 1 — read the roster from the contract, never from memory

```sh
LC_ALL=C sed -n 's/.*<!ENTITY LENS\.[0-9]* *"\(.*\)">.*/\1/p' hooks/rot-voice.dtd
```

Rows are `name|element|sigil|charter|tools|bound`.

`LC_ALL=C` is load-bearing. Without it, under any UTF-8 locale, the read
returns **three** rows instead of nine — the regex engine will not cross the
astral sigils — at exit 0, silently. **Count the rows before dispatching:
fewer than nine means the roster read failed.** A swarm that refuses an
unknown name (Step 2) will otherwise refuse six of its own lenses.

## Step 2 — scope the swarm

- `lenses=` narrows the roster (short names, comma-joined). Absent means
  **all nine**.
- An unknown name **refuses the whole swarm** with the roster printed — a
  swarm that silently drops a lens looks complete and is not.
- `model=` overrides the inherited model for every dispatch in this swarm;
  absent, every lens runs on the Socio's selected model.

## Step 3 — fan out, genuinely in parallel

Issue **all the Task calls in a single message** — one call per lens,
`subagent_type` set to that lens's agent — so they run concurrently. Never
one at a time in sequence: that is just `/rot-agent` nine slow times, and it
loses the simultaneity that is the point.

Each lens gets the same subject, framed for its charter, with its **bound
restated in the prompt** (the "may never" line from its roster row). Do not
homogenise the prompts: Carnage is asked to detonate, Anti-Venom to
diagnose, Chroma to map the futures — nine different machines, nine
different instructions.

## Step 4 — synthesise without flattening

- Present each lens's report **inside its declared element**, roster order.
- Then the combined read: name the 2–3 productive tensions between the
  reports, show why each side has merit, and converge on a synthesis that
  **includes** the tensions rather than resolving them into consensus —
  nine voices agreeing is a failure, not a success.
- If a lens's report is missing, say which and why. A synthesis over eight
  reports labelled as nine is a false label.
- Close with the standing rule: the swarm proposes; the convening model
  synthesises; reality judges.
