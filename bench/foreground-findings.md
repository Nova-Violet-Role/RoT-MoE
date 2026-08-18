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
| W6 | 11 | A pure ideation/naming ask routed to CONVERGENT nine-lens ELEVATE rather than the CREATIVE lane; Carnage summoned only at its 10% baseline weight. | prompt "this tool needs a real name and a tagline... Give me something with personality" → `RoT MoE :: TIER 1 -> CONVERGENT model [NSIL ELEVATE Nova+Violet+AntiVenom+Venom+Carnage+Chroma+Soleil+Eidolon+Claude] \| R/s+ 0.19` — second data point turn 12: "push weirder — brainstorm" → `FORGE Claude [NSIL BOOST Claude] \| R/s+ 0.73` | a naming/branding prompt with no code-word content |
| W7 | final | The session's live hooks wrote no debug log: `~/.local/state/rot-moe/` holds only stamp files and one voice-summons file; `ROTMOE_DEBUG_LOG` is not part of the installed hook configuration. | `ls ~/.local/state/rot-moe/` → 5 `prover-remind.*.stamp` + `voice-summons.*`, no `.jsonl`; `find / -xdev -name "*.jsonl" -path "*rot*"` → only shipped bench corpora | install via `claude plugin install rot-moe@rot-moe`, run a session, inspect the state dir |
| W8 | final | Router `--route` CLI mode writes no records to `ROTMOE_DEBUG_LOG` (only `--vector` gauge evaluations log), so a CLI-exercised log can never satisfy the auditor's gauge/route pairing rule. | 7 × `rot-router.sh --route "<prompt>"` with the log exported → log grew by 0 lines (exit 0 each); audit of a gauge-only log: `the log has 3 gauge and 0 route records -- a log with neither proves nothing`, exit 1; same prompts via hook-mode stdin JSON → 17 records, audit PASS exit 0 | export `ROTMOE_DEBUG_LOG`, run `--route`, `wc -l` the log |
