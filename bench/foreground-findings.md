<!--
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

# RoT MoE — foreground live test findings

Machine-readable half of the foreground trial. Narrative half:
`bench/foreground-test.md`. Sections fixed in order; facts only.

## CRITICAL

none recorded

## BUGS

none recorded

## WARNINGS

| id | turn | what happened | evidence | repro |
|---|---|---|---|---|
| W1 | setup | Plugin manifest declares version 6.0.1 while the marketplace HEAD commit subject names 6.0.2. | `plugin.json: "version": "6.0.1"` at commit `bf6495e2`, subject `6.0.2 row A (shell half): the audit pairing learns concurrency` | `git -C ~/.claude/plugins/marketplaces/rot-moe log -1 --oneline; grep version .claude-plugin/plugin.json` |
| W2 | 1 | PostToolUse re-injects the identical marker and stanza block PreToolUse just injected, doubling per-call hook context. | PreToolUse:Bash and PostToolUse:Bash both carried `RoT MoE :: TIER 1 -> CONVERGENT model [NSIL ELEVATE Nova+Violet+AntiVenom+Venom+Carnage+Chroma+Soleil+Eidolon+Claude] \| R/s+ 0.19` with byte-identical stanzas | any hooked tool call |
| W3 | 1 | A bare `git init` command drew the full nine-lens ELEVATE stanza block as tool-call context. | marker on `mkdir -p ~/client-project && cd ~/client-project && git init`: `RoT MoE :: TIER 1 -> CONVERGENT model [NSIL ELEVATE Nova+Violet+AntiVenom+Venom+Carnage+Chroma+Soleil+Eidolon+Claude] \| R/s+ 0.19` | any low-content Bash call early in a turn |
| W4 | 1 | Voice gate blocked Stop although all five summoned lens stanzas were present in the final message in prose; only stanzas inside literal `<rot:*>` elements satisfy the gate. | `RoT voice gate (...): summoned lenses have not spoken this turn. Give each its stanza -- inside its element` — issued after a final message containing ⚜️/⚪/🕷️/🔮/🧭 stanzas without element tags; tagged retry passed | speak summoned stanzas without `<rot:*>` tags, then Stop |
| W5 | 4 | Organ-4 prover reminder fired on five hook events in one turn (SessionStart, UserPromptSubmit, PreToolUse:Bash, PostToolUse:Bash, PostToolBatch) of a pure-Python turn, citing proof debt from no work this session performed. | `No proof written for 61 min (last: RotGates). Close a proof with THREE instruments: lake build (...) -> #print axioms (...) -> lake env leanchecker (...). A test SAMPLES; a theorem SETTLES.` | any turn after container recycle in a workspace containing `lean/`, with no Lean work in session |
