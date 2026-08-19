<!--
This file is part of RoT MoE.
SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
Copyright 2026 Saimonokuma.
-->

> Moved from the front page in 7.0.0 — the README keeps the showroom,
> this file keeps the depth, word for word. Back: [README](../README.md).

### 🔬 Are the nine benchmarkable in Lean? Partly — and here is the exact line

This is the question worth asking, so it gets a straight answer instead of an
enthusiastic one. `lean/Proofs/RotLens.lean` (13 theorems) proves the
**structure**; `lean/Proofs/RotAbility.lean` (35 theorems) proves each lens is
**load-bearing** and pins what is *not* provable so it cannot drift into a claim.
Nothing proves the *thinking*.

The strongest single result is `every_lens_is_load_bearing`: for each of the
nine, the ensemble with that lens removed weighs **strictly less** than the full
ensemble. That is nine separate inequalities over ℚ, not one statement about a
list length — a lens whose removal changed nothing would be listed, weighted,
documented, and inert, and this is what rules that out.

The second is `every_ability_effect_holds`. Each of the nine abilities is scored
on its **router-observable effect** — what it does to the weights, the lane, the
divisor — and **all nine are proved**. Each row carries its claim as a
*proposition* (`abilityEffect`) rather than a comment, so `.proved` cannot drift
from what was proved: a row is discharged by a theorem or the module does not
compile. Mutation-tested — filing any ability as `notModelled` or `measured`
kills the module (`lean/mutate/mutate_rotability.sh`).

| Claim about the nine | Status | Instrument |
|---|---|---|
| every lane has exactly one lead lens | **PROVED** | `lead_total` |
| no lens leads two lanes | **PROVED** | `lead_injective` |
| every lens leads some lane — none ornamental | **PROVED** | `lead_surjective` |
| choosing a lead removes nobody from the ensemble | **PROVED** | `lead_does_not_shrink` |
| the roster is exactly nine, no duplicates | **PROVED** | `card_lenses_eq_nine`, `lenses_nodup` |
| no shipped λ is zero (no silently-disabled lens) | **PROVED** | `forgeLam_pos` |
| every μ is inside the documented 0.80–1.35 band | **PROVED** | `forgeMu_in_band` |
| in `FORGE`, 🧭 Claude is strictly heaviest, ⚪ Anti-Venom second | **PROVED** | `claude_leads_forge`, `antivenom_second` |
| the expressive lenses are damped on a proving head | **PROVED** | `expressive_damped_in_forge` |
| **removing ANY one lens strictly changes the ensemble** | **PROVED** ×9 | `every_lens_is_load_bearing` |
| every lens contributes strictly positive weight | **PROVED** | `contribution_pos` |
| no single lens carries half the ensemble | **PROVED** | `no_lens_dominates` |
| the FORGE lead outweighs each of the other eight | **PROVED** | `forge_lead_contributes_most` |
| nine abilities, one per lens, none shared | **PROVED** | `abilityOf_injective`, `one_ability_per_lens` |
| 🧭 Claude's ability is named *Grounded Truth*, and that name is **coined here, not sourced** | **PROVED** | `claudeAbilityIsNamed`, `every_ability_is_named`, `exactly_one_name_is_coined`, `only_claude_name_is_coined` |
| **every one of the nine abilities has a proved router-observable effect** | **PROVED** ×9 | `every_ability_effect_holds`, `every_ability_is_proved`, `evidence_split` (9 proved / 0 unmodelled), `no_ability_is_unmodelled` |
| routing accuracy on a labelled key | **MEASURED** (18/18); all 10 lanes reached in one live 80-turn session | `checker/bench-router.sh`, `checker/ctt-session.sh` |
| **the modifiers `M`, `C`, `T` factor out of the gauge exactly** — `R/s+(M,C,T) = M·C·T·R/s+(1,1,1)` | **PROVED** | `gauge_separates` |
| confidence enters linearly, and `C=0` collapses the gauge whatever the divergence | **PROVED** | `gauge_scales_in_C`, `gauge_zero_of_C_zero` |
| the three modifiers commute — pre-multiplied or applied in the loop is the same engine | **PROVED** | `gauge_modifiers_commute` |
| the reported `R/s+` is **recomputable** from the logged per-lens terms | **MEASURED** 240/240 in an 80-turn live session, 2/2 in-gate | `checker/ctt-session.sh --report`, `bench-router.sh` §5 |
| per-turn cost | **BOUNDED, not quoted** — `msBound = 500`, enforced on the live arm and re-measured every deep run; the figure itself is printed by the gate, never frozen on this page | `bench-router.sh` §2, `checker/dominance.sh` D7 |
| `CREATIVE` really is 🩸 Carnage's lane — every other lens carries strictly less λ **than Carnage does** | **PROVED** ×8 | `carnage_leads_creative` |
| `EMPATHIC` really is 🎷 Violet's lane, by the same standard | **PROVED** ×8 | `violet_leads_empathic` |
| a lane **amplifies** its lead rather than merely naming it (Carnage 0.6 → 2.5, Violet 0.6 → 2.3, Chroma 1.0 → 2.4) | **PROVED** | `creative_amplifies_carnage`, `empathic_amplifies_violet`, `predictive_amplifies_chroma`, `lane_leads_carry_weight` |
| the expressive lenses are damped on a proving head but **never silenced** | **PROVED** | `expressive_damped_not_silenced` |
| nine lenses strictly outweigh **any** single lens | **PROVED** ×9 | `nine_outweigh_any_single` |
| **chaos is *useful*, in the gauge's own units** — the marginal return on divergence is maximal at the median and strictly lower anywhere else | **PROVED** | `marginal_gain_le_quarter`, `marginal_gain_lt_quarter_off_center`, `marginal_gain_max_iff_center` |
| **pure chaos pays strictly less than productive divergence** | **PROVED** | `pure_chaos_pays_less` |
| **conformism pays strictly less too — by the same theorem, not a second rule** | **PROVED** | `conformism_pays_less` |
| the gauge is symmetric about the median: σ(x) + σ(1−x) = 1 | **PROVED** | `sigma_symm_about_center` |
| `PREDICTIVE` really is 🔮 Chroma's lane, by the same standard | **PROVED** ×8 | `chroma_leads_predictive` |
| the three lane tables equal the spec they were transcribed from | **CHECKED** | `checker/profile-bind.sh` (9/9, with controls) |

**"Useful chaos" is not a mood — it is a property of the sigmoid, and it is
proved.** The specification does not merely praise divergence; it states exactly
what the gauge does with it: *"the sigmoid rewards median divergence and damps
both conformism and pure chaos."* That is a claim about a shipped function, so
it is settleable, and for a while this README wrote "no instrument exists" next
to it instead of writing the proof.

σ's derivative is `4·σ·(1−σ)`, so `σ(1−σ)` **is** the marginal return on one
more unit of divergence. Three theorems pin its shape: it never exceeds `1/4`;
it equals `1/4` **only** at the median; and it is strictly smaller everywhere
else. From those, `pure_chaos_pays_less` and `conformism_pays_less` fall out as
the same statement applied at `δ=1` and `δ=0` — one mechanism penalising both
failure modes, not two ad-hoc rules. `sigma_symm_about_center` proves that
symmetry directly: `σ(x) + σ(1−x) = 1`.

So 🩸 Carnage's chaos is useful in the only sense a machine can be held to: the
engine pays for it exactly where the spec says it should, and pays less
everywhere else. Mutation-tested — moving the sigmoid's centre from `1/2` to
`1/3` kills the module with 9 error lines.

The lane-level claims are proved the same way, from the weights shipped in
`engine/rot-lean.md` §4: `CREATIVE` really is Carnage's lane and `EMPATHIC`
really is Violet's, by eight strict inequalities each.

Worth knowing about those two profiles: their tables list **eight** lenses, not
nine — 🧭 Claude is absent, because they come from the eight-symbiote codex while
`FORGE` is the ninth-lens head. That absence is modelled as `Option` rather than
papered over with an invented number, and `creativeLam .claude = none` is a
`#guard`, not a comment.

The last row is the honest floor of this project. The lens abilities
are a **design intent**; what Lean settles is that the machine implementing them
has the shape it claims — and the four mutations that kill those theorems
(dropping a lens from the roster, zeroing a weight, making one lens lead two
lanes, demoting the lead below the floor) confirm they are load-bearing rather
than decorative.

#### The newest four theorems, and why they exist

`RotPath.lean` grew from 8 theorems to 12 on 2026-08-03, and the occasion is
worth recording because it is the pattern this repository is built around: the
reminder hook's module derivation — workspace root plus edited file, out comes
the Lean module to build — shipped with **three separate defects, all silent**.
It returned no verdict at all, which reads as "nothing to check" rather than "I
could not work out what to build". They were found by running the thing end to
end, not by reading it.

| Claim about module derivation | Status | Instrument |
|---|---|---|
| the Windows and POSIX spellings of one edit give the SAME module | **PROVED** | `moduleOf_spelling_invariant` |
| the module never depends on how the workspace directory is named or capitalised | **PROVED** | `moduleOf_root_agnostic` |
| a derived module name never contains a path separator | **PROVED** | `moduleOf_no_slash` |
| a file outside the workspace derives **nothing**, so nothing is built | **PROVED** | `moduleOf_none_of_outside` |
| a path that merely shares a prefix string (`…/Leanx`) is not inside `…/Lean` | **MEASURED** by `decide` | executable `example` |

The second row is the one that would have prevented the worst of the three: the
shipped fallback matched a lowercase `*/lean/*` only, so a workspace at
`<root>/Lean` — the layout the installer now creates — matched nothing. Stated
over **arbitrary** roots rather than over the name `Lean`, so it does not expire
the day someone chooses `Formal` or `Proofs` instead. A theorem naming today's
directory would have been a snapshot, and it would have gone red on a correct
change.

All four survive `#print axioms` with `propext, Classical.choice, Quot.sound`
and nothing else, are re-verified by `leanchecker`, and are load-bearing: three
mutations of the definitions — dropping the trailing separator from the prefix
test, making `dotify` the identity, making `dropLeanExt` keep the extension —
each **killed** the build.

---

