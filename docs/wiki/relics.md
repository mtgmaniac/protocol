# Relics

> Part of the [Overload Protocol wiki](INDEX.md). See also: [Items & Gear](items-and-gear.md), [Rewards & Shop](rewards-and-shop.md), [Protocol economy](protocol-economy.md), [Beats & Events](beats-and-events.md), [Shields & Ward](shields-and-ward.md).

## How it works

**35 relics** in `data/raw/relics.data.json`: **30 draftable** + **5 boss relics** (`bossRelic: true`). Relics are run-permanent passives. A run normally holds at most **two**: one from the battle-5 RELIC CACHE draft (2 choices, boss relics excluded — `GameState._roll_relic_choice_ids`, `scripts/autoloads/GameState.gd:1187-1201`) and optionally one boss relic taken as a **Starting Directive** at DEPLOY (unlocked by first operation clears; it never consumes the draft slot — `drafted_relic_count`, `GameState.gd:1152-1156`).

At battle setup `CombatManager.setup_relics` copies each owned relic's effect dict into `_active_relic_effects` (`scripts/battle/combat_manager.gd:288-293`); consumers query `has_relic(effect_type)` / `get_relic_value` (`:296-311`). Out-of-battle consumers (reward filtering, revive pct) query `GameState.has_relic_effect` (`GameState.gd:747-754`).

### Draftable relics (30)

| id | Name | Effect key | Coded behavior | Trigger | Handler |
|---|---|---|---|---|---|
| `ironCurtain` | Iron Curtain | `enemyDmgMult 0.75` | enemy ability damage ×0.75, floor | every enemy hit | `combat_manager.gd:519,1562` |
| `openingGambit` | Opening Salvo | `battleStartHalfHp` | random enemy takes 50% max-HP damage; random hero takes 20% | battle start | `combat_manager.gd:376-388` |
| `bulwarkAura` | Bulwark Aura | `heroShieldPerTurn 3` | all living heroes +3 shield | enemy-phase start | `combat_manager.gd:492-496` |
| `naniteField` | Nanite Field | `heroHealPerTurn 3` | all living heroes heal 3 | enemy-phase start | `combat_manager.gd:499-503` |
| `plagueProtocol` | Plague Protocol | `enemyBurnPermanent 3` | all enemies get a PERMANENT 3-burn stack (never expires; Detonate takes one tick, doesn't consume — DECISIONS #4) | battle start | `combat_manager.gd:411-416` |
| `overcharge` | Overcharge | `heroDmgMult 1.3` | hero ability damage ×1.3, ceil | every hero hit | `combat_manager.gd:515,1205` |
| `signalJam` | Signal Jam | `enemyStartRfe 2` | permanent −2 enemy rolls | battle start | `combat_manager.gd:419-424` |
| `coordinatedStrike` | Coordinated Strike | `heroStartRollBuff 2` | permanent +2 hero rolls | battle start | `combat_manager.gd:427-432` |
| `resonanceCascade` | Resonance Cascade | `burnAmplified 2` | enemy burn ticks +2 (hero burns unaffected) | burn tick | `combat_manager.gd:2442` |
| `gravityWell` | Gravity Well | `auraEnemyDmg 2` | all living enemies take 2 (attacker-less) | enemy-phase start | `combat_manager.gd:506-510` |
| `protocolOverride` | Protocol Override | `protocolOnItemUse` | items cost 0 AND grant +1 Protocol | item use | `battle_engine.gd:288` / `protocol_actions.gd:934-936` |
| `entropyLeak` | Entropy Leak | `enemyHpEscalation b6+ 85%` | enemies spawn at 85% HP from battle 6 | battle start | `combat_manager.gd:435-442` |
| `chainReaction` | Chain Reaction | `chainReaction 4` | other living enemies take 4 when an enemy dies (no cascade; guarded) | enemy death | `combat_manager.gd:2102-2107` |
| `martyrdomProtocol` | Vengeance Protocol | `vengeanceProtocol` | survivors' next roll forced to natural 20, once per battle | hero death | `combat_manager.gd:2094-2099` / `battle_scene.gd:1423-1427` |
| `overloadLoop` | Overload Loop | `critResolveTwice` | hero abilities on a RAW 20 resolve twice | hero nat 20 | `combat_manager.gd:685-687` |
| `curatedCache` | Curated Cache | `rewardsNoCommon` | common rarity excluded from reward rolls (and consumable drops) | reward roll | `GameState.gd:1229,1256` |
| `overflowBuffer` | Overflow Buffer | `protocolCarryover 50` | 50% (floor) of unspent Protocol carried into the next battle | battle victory | `battle_scene.gd:1171-1175` / `GameState.gd:757-767` |
| `fieldCache` | Field Cache | `battleStartConsumable 1` | +1 random consumable at battle start (bag cap 3; never a duplicate of a held item) | battle start | `battle_scene.gd:231-233` / `GameState.gd:770-778` |
| `mercyProtocol` | Mercy Protocol | `reviveNoPenalty` | revives restore 100% HP | revive resolution | `GameState.gd:785-788` |
| `emergencySignal` | Emergency Signal | `lowHpSquadRollBuff 2/2t` | first ally crossing ≤50% HP → squad +2 roll for 2 turns, once per battle | HP threshold | `combat_manager.gd:1899-1902,1942-1956` |
| `aegisField` | Aegis Field | `healGrantsShieldAll 3` | any hero heal that restores HP grants ALL allies +3 shield | any heal | `combat_manager.gd:2243-2249` |
| `standingOrder` | Standing Order | `critBandExtend 1` | every hero's crit band extends 1 down | zone mapping | `dice_manager.gd:47` |
| `staticField` | Static Field | `battleStartJamEnemies` | all enemy dice Jammed (cap 10) on turn 1 | battle start | `combat_manager.gd:391-394` |
| `twinFates` | Twin Fates | `twinFates` | once per battle, copy one hero die's raw result to another, free (frozen dice illegal) | player action | `battle_engine.gd:266-274` / `protocol_actions.gd:404-438` |
| `overflowVent` | Overflow Vent | `protocolOverflowDamage 2` | Protocol gained past the cap deals 2 dmg/point to a random enemy (deterministic RollProvider pick) | protocol overflow | `battle_engine.gd:182-197` |
| `salvageDirective` | Salvage Directive | `protocolOnMarkedKill 2` | +2 Protocol when the killing hit consumed a Mark | marked kill | `combat_manager.gd:2147-2150` |
| `coldLogic` | Cold Logic | `frozenBonusDamage 4` | attacks (with an attacker) vs enemies with frozen dice deal +4 | frozen-target hit | `combat_manager.gd:1815-1818` |
| `chainDoctrine` | Chain Doctrine | `chainExtraJump` | hero Chains jump one extra time | chain resolve | `combat_manager.gd:1477` |
| `scavengerManifest` | Scavenger Manifest | `firstKillDropsConsumable` | first direct kill each battle drops a random consumable | first kill | `combat_manager.gd:2118-2121` |
| `deadMansHand` | Dead Man's Hand | `squadWipeSurvive` | first squad wipe each RUN: everyone survives at 1 HP with forced nat 20s | squad wipe | `combat_manager.gd:1930-1937` |

### Boss relics (5) — excluded from drafts, offered as Starting Directives

| id | Name | Effect key | Coded behavior | Trigger | Handler |
|---|---|---|---|---|---|
| `salvageRig` | Salvage Rig | `protocolOnShieldBreak 1` | +1 Protocol when damage reduces an enemy shield to 0 (Breach destruction does NOT count) | enemy shield break | `combat_manager.gd:1867-1870` |
| `chitinGraft` | Chitin Graft | `heroHealOnOwnKill 3` | the killing hero heals 3 (direct kills) | hero kill | `combat_manager.gd:2142-2145` |
| `resonantChorus` | Resonant Chorus | `turn1RollFloor 8` | turn-1 HERO dice below 8 are lifted to 8 (frozen dice untouched) | turn-1 roll | `battle_scene.gd:1413,1428-1431` |
| `rootAccess` | Root Access | `setCostZeroOncePerBattle` | the first Set each battle costs 0 | Set action | `battle_engine.gd:246-249,254-261` |
| `mantleCore` | Mantle Core | `shieldsPersist` | hero shields persist until broken (the single exception to one-round shields, TRUTH rule 5) | battle start flag | `combat_manager.gd:397-408` |

## Why it works that way

- The one-draft-per-run relic economy (battle 5 cache + optional Starting Directive) keeps relic×relic stacking bounded by design — most relic pairs can only coexist as boss-relic + drafted.
- Overflow Vent damage routes through the RollProvider explicitly for the determinism fence (INVARIANTS #1); protocol grants flow through the pending-grant pool so the cap/vent rule lives once (`battle_engine.gd:182`).
- `shieldsPersist` is the SINGLE named exception to per-side shield expiry (DECISIONS_RESOLVED #2); same flag drives the MANTLE TYRANT standing rule.
- Emergency Signal's `turns: 2` is the 2026-07-06 timer-contract repair (a 1t mid-round buff would expire before shaping a roll — TRUTH rule 10).
- Boss relics landed as data in pkg3.5 (`248ada0`) and became drop/unlock content in pkg5; the battle-5 soft-lock fix (2026-07-06) made the draft key on `drafted_relic_count()` instead of `relics.is_empty()`.
- `martyrdomProtocol`'s id ≠ its display name "Vengeance Protocol": internal ids are frozen (INVARIANTS #11).

## What it replaced

- pkg3.5 "relic repairs + new pool" (`248ada0`) rebuilt the pool and added the boss five; earlier relic sets are gone.
- Vengeance/Dead-Man's forced-20 mechanics ride the same `forced_nat20_pending` flag the freeze=repeat pass hardened (frozen dice skip the override until thawed, keeping the pending flag).
- No relic references dead statuses (cower/venom/decay/counterspell/retaliate) — verified 2026-07-07.

## File locations

- `data/raw/relics.data.json`
- `scripts/battle/combat_manager.gd` (setup + most triggers)
- `scripts/battle/battle_engine.gd` (Protocol Override cost, Overflow Vent, Twin Fates, Root Access)
- `scripts/battle/battle_scene.gd` (carryover, battle-start consumable, Resonant Chorus, forced 20s)
- `scripts/battle/dice_manager.gd` (Standing Order)
- `scripts/autoloads/GameState.gd` (Curated Cache, Mercy Protocol, Field Cache grant, relic cache roll)
- Regressions: `scripts/debug/ability_audit.gd:1261-1441,2951-3385`

## Known edge cases

- Only heroes benefit from Overload Loop, and only on a raw 20 — a Band Compressor 19 in the overload band does not double.
- Chain Reaction splash kills (and Killswitch Relay kills) trigger NO on-kill hooks — the re-entrancy guard at `combat_manager.gd:2087-2090` suppresses everything, not just further cascades.
- Salvage Rig pays only for damage-broken shields; Breach's instant destruction and round-end expiry pay nothing.
- Cold Logic and Mark ignore item damage (no attacker state).
- Protocol Override makes every `gainProtocol` consumable net-positive by its full amount +1 (Mainline Cache: +6), falsifying the "(net +N)" desc text.
- Aegis Field triggers per heal that restores ≥1 HP — Nanite Field's three per-turn heals can fan out 9 squad shield/turn when heroes are damaged.
- Field Cache/Scavenger drops exclude consumable ids already held and (with Curated Cache) commons; the drop can silently fizzle on a full or saturated bag.
- Twin Fates / Set frozen-die protection is enforced in the UI layer only; the engine methods themselves have no guard.
- Opening Salvo picks its two targets with raw `randi()` — the only non-seeded randomness in this pool.

## ⚠ Open findings

<!-- AUDIT-LINKS:relics -->
- [A-035](../audit/INTERACTION_AUDIT.md#a-035) - [confusing] Salvage Rig never fires on breach-destroyed shields
- [A-058](../audit/INTERACTION_AUDIT.md#a-058) - [confusing] battle-start relic effects skip summons/rebuilds
- [A-063](../audit/INTERACTION_AUDIT.md#a-063) - [degenerate] Protocol Override makes gainProtocol items free printers
- [A-067](../audit/INTERACTION_AUDIT.md#a-067) - [confusing] Resonant Chorus floors only hero dice
- [A-069](../audit/INTERACTION_AUDIT.md#a-069) - [confusing] Plague Protocol permanent burn read as normal
- [A-072](../audit/INTERACTION_AUDIT.md#a-072) - [confusing] Overload Loop doubles only raw hero 20s (desc)
- [A-073](../audit/INTERACTION_AUDIT.md#a-073) - [confusing] Salvage Directive misses packet-finished mark-kills
- [A-095](../audit/INTERACTION_AUDIT.md#a-095) - [confusing] GDD 'one relic per run' contradicts Starting Directive
