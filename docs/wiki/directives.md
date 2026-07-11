# Directives

> Part of the [Overload Protocol wiki](INDEX.md). See also: [heroes.md](heroes.md), [keywords.md](keywords.md), [protocol-economy.md](protocol-economy.md), [statuses-and-chips.md](statuses-and-chips.md).

## How it works

Directives are tier-3 permanent passives. When an **evolved** unit banks **250 XP** (`GameState.XP_TO_DIRECTIVE`, `scripts/autoloads/GameState.gd:74`), it picks **1 of the 2 directives scoped to its evolution path** (`directives` block per evolution in `data/raw/heroes.data.json`; schema requires exactly 2 per path, `data/schemas/heroes.data.schema.json:147-153`). 16 paths × 2 = **32 directives** — ground-truth count PASSED. A unit with a directive stops accruing XP (`GameState.gd:979`).

The pick runs through `scripts/ui/evolution_screen.gd` (`is_pending_directive_stage()` → `get_pending_directive_choices()` → `apply_pending_directive()`, `GameState.gd:917-946`). At battle build, the chosen directive's `effect` dictionary rides the unit into combat state (`combat_manager.gd:830-836`); every handler checks `_has_directive(state, type)` (`combat_manager.gd:842-851`). One directive per unit — `directive_type` is a single string, so effects never stack on one carrier.

Distinct from **Starting Directives** (boss relics offered at DEPLOY — see [relics.md](relics.md)) and the **Salvage Directive** relic; those are relic-system entities despite the name.

## The 32 directives (verified against handlers, 2026-07-07)

Every handler was read and matches its `desc` text. "Handler" = `scripts/battle/combat_manager.gd` unless noted.

| Path | Directive | Desc (data) | Effect type | Handler | Text vs behavior |
|---|---|---|---|---|---|
| pyro | Flashpoint | Your Burn ticks once immediately on apply. | `burnImmediateTick` | :1371-1374 | MATCH — extra tick on apply, duration untouched (shared hook with Ignition Coil gear) |
| pyro | Slow Roast | Your Burns last +1 turn. | `burnDurationBonus` (1) | :1367-1368 | MATCH |
| arc | Conductor | Your Chains jump one extra target. | `chainExtraJump` | :1480-1481 | MATCH — stacks with Chain Doctrine relic (:1477) |
| arc | Amplifier | Your Chain hits deal 100% damage. | `chainFullDamage` | :1484 | MATCH — replaces the 50% ratio |
| blade | Serrated | Your Pierce attacks also Breach. | `pierceAlsoBreach` | :1216-1217 | MATCH — breach forced when `ignSh` |
| blade | Momentum | Each kill adds +4 to your next ability's damage. | `killNextAbilityDamage` (4) | bank :2152-2155, spend :1206-1211 | MATCH — additive bank (multi-kill turns stack), consumed in one hit |
| ravager | Deep Cuts | +3 damage against Burning targets. | `bonusVsBurning` (3) | :1823-1826 | MATCH — carrier's hits on any burning enemy |
| ravager | Open Veins | Your overload Detonates after its damage. | `overloadDetonateAfter` | :1260-1261 | MATCH — overload zone, single-target branch (Evisceration is single-target); skipped if the ability already detonates |
| bulwark | Rampart | Your shields grant +2. | `ownShieldBonus` (2) | :963-966 | MATCH — all grant branches incl. self |
| bulwark | Bunker Doctrine | Allies holding your shields Spike 3. | `shieldGrantsSpike` (3) | :1156-1161 | MATCH — allies only (granter excluded), spike = max not sum |
| sentinel | Ironclad | While taunting, incoming hits deal -2. | `tauntDamageReduction` (2) | :1796-1797 | MATCH — reduction only while `taunting` |
| sentinel | Counterweight | Your Spike deals +4. | `spikeBonus` (4) | :1064-1065 | MATCH — applied at cast to own-ability spike |
| glacier | Deep Freeze | Your freezes repeat 2 results. | `freezeDurationBonus` (1) | :1107-1108 | MATCH — +1 repeat on top of authored 1 = 2 (all Glacier freezes author 1) |
| glacier | Shatterpoint | +6 damage against frozen-die enemies. | `bonusVsFrozen` (6) | :1827-1830 | MATCH — stacks with Shatter Lance's own `vsFrozenBonus` rider and Cold Logic relic |
| trench | Field Triage | Your heals grant 3 shield. | `healGrantsShield` (3) | :2239-2242 | MATCH — every effective heal cast by the carrier, incl. self-heals |
| trench | Entrench | Start battles with 10 shield. | `battleStartShieldSelf` (10) | :452-454 | MATCH — one-round shield per rule 5 |
| medic (Combat Medic) | Combat Sense | Your single-target hits Mark their primary target. | `damageAppliesMark` | :1276-1277 | MATCH — single-target branch only (never AoE Mark, DECISIONS_RESOLVED #14) |
| medic (Combat Medic) | Field Surgeon | Surge Revive restores 100% HP. | `abilityRevivePctOverride` ("Surge Revive", 100) | :1184-1188 | MATCH — name-keyed override |
| synth | Overcharge Mesh | Squad shields grant +2. | `squadShieldBonus` (2) | :876-880 | MATCH — every hero-side shield grant while a living carrier stands |
| synth | Lazarus Loop | Mass Revival restores 50% HP. | `abilityRevivePctOverride` ("Mass Revival", 50) | :1184-1188 | MATCH |
| overclocked | Deep Cells | Protocol cap +2. | `protocolCapBonus` (2) | `battle_engine.gd:170-175` | MATCH — cap 12 while the carrier lives; reverts on death |
| overclocked | Surge Wiring | Bias Charge grants +2 Protocol. | `abilityProtocolBonus` ("Bias Charge", 2) | :1011-1014 | MATCH — +2 on top of the base +1 (total 3) |
| phantom | Silent Running | Your non-damage abilities re-Cloak you. | `nonDamageRecloak` | :1148-1152 | MATCH — any `damage <= 0` resolution |
| phantom | Ambush Wiring | Your attacks from Cloak deal +5. | `cloakAttackBonus` (5) | :949-951 | MATCH — added at decloak |
| shadow | Ghostblade | Your decloak strike also Executes. | `decloakExecute` | set :953-955, consume :1264-1267 | MATCH — runs the normal execute check (threshold 25%) |
| shadow | Vanish | Below 50% HP: Cloak, once per battle. | `lowHpCloakOnce` (50) | :1904-1912 | MATCH — fires on the damage that drops the carrier below 50% (must survive it); `vanish_used` gates once/battle |
| wraith | Marked for Death | Your single-target hits Mark their primary target. | `damageAppliesMark` | :1276-1277 | MATCH — same handler as Combat Sense |
| wraith | Reaper | Your Executes trigger below 35%. | `executeThresholdPct` (35) | state :834-836, read :1410 | MATCH — default threshold 25% raised to 35% |
| noise | Wall of Static | Your tray-wide roll-downs also Jam (cap 15). | `rfeAllAlsoJam` (cap 15) | :1167-1169 | MATCH — the cap-15 jam is the intentional exception to JAM_CAP 10 (DECISIONS_RESOLVED K4) |
| noise | Feedback | Enemies under your roll-downs take 2 per round. | `rfeDamagePerRound` (2) | set :1173-1176, tick :2528-2533 | MOSTLY — chip fires at round end while ANY rfe stack is live on a tagged enemy, not only the carrier's (see F-heroes-05); fires before stack decay so 1t roll-downs still bite |
| nullwire | Hard Lock | Your single-target roll-downs also Jam. | `rfeAlsoJam` | :1170-1172 | MATCH — JAM_CAP 10 |
| nullwire | Signal Theft | Your roll-downs grant +1 Protocol each. | `rfeGrantsProtocol` (1) | :1177-1181 | MATCH — per application (a tray-wide roll-down would grant per enemy, but Nullwire's kit is single-target only) |

## Why it works that way

- **Path-scoped 1-of-2** keeps the directive a capstone identity choice for the evolution already taken; the schema hard-pins exactly 2 per path.
- **One directive per unit** (single `directive_type` string) keeps the passive layer legible (INVARIANTS #5) and lets handlers be simple equality checks.
- **Name-keyed effects** (`abilityRevivePctOverride`, `abilityProtocolBonus`) bind to ability display names — cheap and data-driven, but it makes ability names load-bearing (see heroes.md Known edge cases).
- **Never-AoE Mark** for Combat Sense / Marked for Death is a Kev ruling (DECISIONS_RESOLVED #14); the descs were rewritten 2026-07-07 to name the primary target.
- **Deep Cells lives in `battle_engine.gd`** because the protocol cap rule was extracted from battle_scene into the shared engine seam (architecture review §1) so the sim prices it identically.

## What it replaced

Directives shipped as pkg6 "tier-3 passives" — there was no predecessor system; before pkg6 the 250-XP stop did not exist. The old ability-audit-era hero kits (see the stale `docs/ABILITY_DESCRIPTIONS_FULL.md`) predate directives entirely. Boss-relic "Starting Directives" reuse the word but are relics (pkg5).

## File locations

- `data/raw/heroes.data.json` — the 32 directive definitions (per-evolution `directives` blocks)
- `data/schemas/heroes.data.schema.json:147-175` — directive shape (`effect.additionalProperties: false`)
- `scripts/battle/combat_manager.gd` — 31 of 32 handlers (see table)
- `scripts/battle/battle_engine.gd:164-176` — Deep Cells (protocol cap)
- `scripts/autoloads/GameState.gd:917-946, 1052-1055` — offer/apply/eligibility
- `scripts/ui/evolution_screen.gd:146-212` — the pick UI
- `scripts/debug/ability_audit.gd:1846-2018` — directive regressions

## Known edge cases

- **Feedback outlives the carrier's own stacks** when another rfe source is live on the same enemy (`combat_manager.gd:2530` checks total rfe, clears only when all stacks expire — `:2548`).
- **Reaper vs execute-carrying overloads**: the threshold is per-attacker state, so only the carrier's executes move to 35%.
- **Momentum bank survives across rounds** until the carrier's next damaging ability; it is not cleared by non-damage zones.
- **Deep Cells cap drop**: if the carrier dies while the pool sits above 10, `max_protocol` reverts to 10 — the pool is clamped on the next gain, not immediately.
- **Ghostblade + Ambush Wiring can't co-exist** (one directive per unit, both Shadow-line-adjacent but on different paths anyway).

## ⚠ Open findings

<!-- AUDIT-LINKS:directives -->
- [A-042](../audit/INTERACTION_AUDIT.md#a-042) - [confusing] Feedback directive ticks on foreign roll-downs
