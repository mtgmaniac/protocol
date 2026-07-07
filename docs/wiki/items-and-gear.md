# Items & Gear

> Part of the [Overload Protocol wiki](INDEX.md). See also: [Relics](relics.md), [Rewards & Shop](rewards-and-shop.md), [Protocol economy](protocol-economy.md), [Shields & Ward](shields-and-ward.md), [Keywords](keywords.md).

## How it works

Two item classes ride the reward system (see [rewards-and-shop.md](rewards-and-shop.md)):

- **Consumables** (25, `data/raw/items.data.json`) — one-shot battle items. Squad-wide bag, cap **3** (`GameState.MAX_CONSUMABLES`, `scripts/autoloads/GameState.gd:6`; mirrored by `LoadoutMenu.ITEM_SLOTS`, `scripts/ui/loadout_menu.gd:20`). Using one costs **1 Protocol flat** for every rarity (`BattleEngine.item_protocol_cost`, `scripts/battle/battle_engine.gd:287-294`; modifiers: Protocol Override relic → 0 and +1 refund, Supply Drone intercept → 0, Sealed Supplies route modifier → 2). Items can be used before rolling, during targeting, or before ending the turn (`scripts/battle/protocol_actions.gd:798-799`). The effect dispatch shared by the live screen and the sim is `BattleEngine.apply_consumable_effect` (`scripts/battle/battle_engine.gd:365-433`); `gainProtocol` alone resolves in the caller because it owns the pool (`scripts/battle/protocol_actions.gd:941-945`).
- **Gear** (31, `data/raw/gear.data.json`) — permanent passives equipped to ONE unit at reward time (see the equip flow in [rewards-and-shop.md](rewards-and-shop.md)). Loaded per battle by `CombatManager.setup_gear` → `_apply_gear_passive` (`scripts/battle/combat_manager.gd:316-369`) plus a battle-start block (`:447-485`). Mid-run re-equip is REJECTED (DECISIONS_RESOLVED #15) — gear stays where you put it.

### Consumables (25)

| id | Name | Rarity | Target | Effect key | Coded behavior | Handler |
|---|---|---|---|---|---|---|
| `patch_kit` | Patch Kit | common | ally | `heal 5` | heal living ally 5 | `battle_engine.gd:368` |
| `triage_broadcast` | Triage Broadcast | common | none | `healAll 2` | heal all living allies 2 | `battle_engine.gd:372` |
| `scrap_plate` | Scrap Plate | common | ally | `shield 5` | +5 one-round shield stack | `battle_engine.gd:376` |
| `buckler_array` | Buckler Array | common | none | `shieldAll 4` | +4 shield, all living allies | `battle_engine.gd:380` |
| `calibration_chip` | Calibration Chip | common | ally | `rollBuff 1/1t` | +1 roll instance, 1 turn | `battle_engine.gd:387` |
| `momentum_core` | Momentum Core | uncommon | ally | `rollBuff 2/1t` | +2 roll, 1 turn | `battle_engine.gd:387` |
| `harmonic_injector` | Harmonic Injector | rare | ally | `rollBuff 4/2t` | +4 roll, 2 turns | `battle_engine.gd:387` |
| `archive_cascade` | Archive Cascade | legendary | ally | `rollBuff 5/3t` | +5 roll, 3 turns | `battle_engine.gd:387` |
| `defib_spark` | Defib Spark | uncommon | allyDead | `revive 50%` | **UNUSABLE in live play** — see ⚠ F-01 | `battle_engine.gd:392` / cancel `protocol_actions.gd:763` |
| `ghost_veil` | Ghost Veil | uncommon | ally | `cloak` | cloak one ally | `battle_engine.gd:395` |
| `scatter_veil_array` | Scatter Veil Array | rare | none | `cloakAll` | cloak all living allies | `battle_engine.gd:398` |
| `grounding_clip` | Grounding Clip | common | enemy | `enemyRfe 1/2t` | −1 enemy roll, 2t | `battle_engine.gd:401` |
| `corrosion_bomb` | Corrosion Bomb | uncommon | enemy | `enemyRfe 2/2t` | −2 enemy roll, 2t | `battle_engine.gd:401` |
| `entropy_seed` | Entropy Seed | rare | enemy | `enemyRfe 3/3t` | −3 enemy roll, 3t | `battle_engine.gd:401` |
| `shock_charge` | Shock Charge | common | enemy | `enemyDmg 10` | 10 damage, no attacker (no Mark/Cold Logic interaction) | `battle_engine.gd:406` |
| `acid_vial` | Acid Vial | common | enemy | `enemyBurn 3/2t` | 3 burn, 2 turns | `battle_engine.gd:410` |
| `phase_scrambler` | Phase Scrambler | common | enemy | `enemyRerollDie` | reroll one enemy die; fizzles on a frozen die | `battle_engine.gd:415` |
| `cascade_jammer` | Cascade Jammer | rare | none | `enemyRerollAll` | reroll every unfrozen enemy die | `battle_engine.gd:421` |
| `cryo_gel` | Cryo Gel | uncommon | any | `anyDieFreeze 1` | freeze any die, 1 repeat (freeze = repeat) | `battle_engine.gd:424,332` |
| `cryo_web` | Cryo Web | rare | any | `anyDieFreeze 2` | freeze any die, 2 repeats | `battle_engine.gd:424,332` |
| `deep_zero_pin` | Deep Zero Pin | rare | none | `enemyDieFreezeAll 1` | pin every enemy die to its weakest face (1, recharge) and freeze it — each enemy repeats its recharge result (NK-14 redesign, 2026-07-08; was "keep whatever face showed", A-066) | `battle_engine.gd:347` |
| `protocol_cell` | Protocol Cell | common | none | `gainProtocol 2` | +2 Protocol (pool op; Overflow Vent applies) | `protocol_actions.gd:941` |
| `capacitor_dose` | Capacitor Dose | uncommon | none | `gainProtocol 3` | +3 Protocol | `protocol_actions.gd:941` |
| `core_surge` | Core Surge | rare | none | `gainProtocol 4` | +4 Protocol | `protocol_actions.gd:941` |
| `mainline_cache` | Mainline Cache | legendary | none | `gainProtocol 5` | +5 Protocol | `protocol_actions.gd:941` |

### Gear (31)

| id | Name | Rarity | Effect key | Coded behavior | Handler |
|---|---|---|---|---|---|
| `neural_splice` | Neural Splice | uncommon | `rollBonus 2` | permanent +2 roll | `combat_manager.gd:331` |
| `predator_lens` | Predator Lens | legendary | `rollBonus 3` | permanent +3 roll | `combat_manager.gd:331` |
| `combat_plating` | Combat Plating | uncommon | `battleStartShield 6` | +6 shield at battle start | `combat_manager.gd:462` |
| `stim_injector` | Stim Injector | uncommon | `maxHpBonus 6` | +6 max & current HP each battle | `combat_manager.gd:474` |
| `warframe_core` | Warframe Core | legendary | `maxHpBonus 14` | +14 max & current HP | `combat_manager.gd:474` |
| `phase_weave` | Phase Weave | uncommon | `battleStartCloak` | starts each battle cloaked | `combat_manager.gd:465` |
| `kill_switch` | Kill Switch | uncommon | `healOnKill 5` | holder heals 5 when ANY enemy dies (direct kills only) | `combat_manager.gd:2124-2130` |
| `protocol_tap` | Protocol Tap | uncommon | `protocolOnBattleStart 1` | +1 Protocol at battle start (capped) | `battle_engine.gd:81` / `battle_scene.gd:247` |
| `mainline_bus` | Mainline Bus | legendary | `protocolOnBattleStart 3` | +3 Protocol at battle start | `battle_engine.gd:81` |
| `triage_gel` | Triage Gel | uncommon | `healShieldBonus 3` | holder's heals on OTHERS also grant 3 shield | `combat_manager.gd:2233-2237` |
| `counterweight` | Counterweight | uncommon | `dmgReduction 1` | all incoming damage −1 | `combat_manager.gd:1794-1801` |
| `siphon_loop` | Siphon Loop | rare | `lifesteal 20` | heal 20% of HP damage dealt (post-shield, floor) | `combat_manager.gd:1891-1897` |
| `hemophage_nexus` | Hemophage Nexus | legendary | `lifesteal 40` | heal 40% of HP damage dealt | `combat_manager.gd:1891-1897` |
| `spike_driver` | Spike Driver | uncommon | `firstAbilityDmgBonus 3` | +3 on first damaging ability per battle | `combat_manager.gd:1202-1205` |
| `overkill_matrix` | Overkill Matrix | legendary | `firstAbilityDmgBonus 10` | +10 on first damaging ability | `combat_manager.gd:1202-1205` |
| `dead_mans_chip` | Dead Man's Chip | rare | `surviveOnce` | once per battle, survive lethal at 1 HP | `combat_manager.gd:1916-1920` |
| `echo_matrix` | Echo Matrix | rare | `firstAbilityEcho` | first damaging ability re-applies its damage once | `combat_manager.gd:1144-1146` |
| `breach_tip` | Breach Tip | rare | `shieldPierce 5` | attacks bypass up to 5 shield (shields remain) | `combat_manager.gd:1837-1857` |
| `bounty_chip` | Bounty Chip | uncommon | `protocolOnKill 1` | +1 Protocol on holder's kill of a BASIC enemy | `combat_manager.gd:2133-2137` (basic test `:1959`) |
| `band_compressor` | Band Compressor | legendary | `overloadBandCompress` | overload band becomes 19-20 | `dice_manager.gd:43` |
| `wide_aperture` | Wide Aperture | rare | `surgeBandExtend 2` | surge band extends 2 lower | `dice_manager.gd:45` |
| `reverse_gimbal` | Reverse Gimbal | uncommon | `nudgeMaySubtract` | tap Nudge again to flip +3/−3, free (DECISIONS #11) | `battle_engine.gd:231-242` |
| `priming_charge` | Priming Charge | uncommon | `firstNudgeFree` | holder's first Nudge each battle costs 0 | `battle_engine.gd:220-223` |
| `overload_capacitor` | Overload Capacitor | rare | `protocolOnNat20 2` | raw natural 20 → +2 Protocol (forced 20s count) | `battle_scene.gd:1448-1450` |
| `ignition_coil` | Ignition Coil | rare | `burnImmediateTick` | holder's Burns tick once on application | `combat_manager.gd:1371-1374` |
| `payload_fuse` | Payload Fuse | rare | `detonateBonus 50` | holder's Detonate bursts ×1.5 (ceil) | `combat_manager.gd:1437-1438` |
| `targeting_optic` | Targeting Optic | uncommon | `battleStartMark` | battle starts with the FIRST LIVING ENEMY Marked | `combat_manager.gd:479-485` |
| `mirror_plate` | Mirror Plate | rare | `protocolOnDieTamper 2` | +2 Protocol when the holder's die is Jammed/Rewritten/Frozen | `combat_manager.gd:1326-1332` |
| `anchor_frame` | Anchor Frame | rare | `tauntAbove50` | counts as taunting while HP > 50% (explicit taunts win) | `combat_manager.gd:2386-2391` |
| `killswitch_relay` | Killswitch Relay | legendary | `deathDamageAll 12` | on holder death, 12 damage to all enemies | `combat_manager.gd:2165-2170` |
| `sync_antenna` | Sync Antenna | legendary | `syncRollBonus 3` | holder + ally rolling the same raw number both get +3 this round | `battle_scene.gd:1451-1475` |

There is **no common-rarity gear** — round-1 reward rolls (85% common) always offer consumables at the common slot.

## Why it works that way

- Flat item cost 1 landed with the item-roster refactor (commit `a21eaf4`, "squad-wide consumables, gear renames") — the squad bag replaced per-unit inventories and variable costs; the `gainProtocol` items' "(net +N after use cost)" descs bake that flat cost in.
- The consumable dispatch lives in BattleEngine so the sim and live screen share one implementation (sim-D extraction; header comment `battle_engine.gd:358-364`).
- Freeze items use `repeats` and repeat wording since the freeze=repeat ruling (DECISIONS_RESOLVED #1, commit `52e2fa5`).
- One relic + finite gear per unit keeps the loadout legible (INVARIANTS #5); mid-run re-equip explicitly rejected (DECISIONS_RESOLVED #15).
- Gear effect handlers with no data (`burnDmgBonus`, `protocolOnKillAny`, `battleStartCloakRoll`, item `"ward"`) are reserved slots tracked by `scripts/debug/audit_gear_relic_effects.py`. RATIONALE: unconfirmed (whether reserved or leftover).

## What it replaced

- Per-unit item inventories and gear names of the Angular era → squad-wide bag + renamed gear (`a21eaf4`); pkg3.6 enforced once-per-effect cleanup (`0d9ff44`).
- XP consumables were removed entirely — zero remnants confirmed in data and handlers (2026-07-07 audit).
- Freeze items: lockout-era `skips` key → `repeats` (freeze = repeat, `52e2fa5`).
- The old hover tooltip system → long-press InspectPopup (`6861232`); items/relics inspect from the loadout menu (`loadout_menu.gd:250`).

## File locations

- `data/raw/items.data.json` · `data/raw/gear.data.json`
- `scripts/battle/battle_engine.gd` (cost + consumable dispatch + nudge/set rules)
- `scripts/battle/protocol_actions.gd` (item UI flow, gainProtocol pool op, consume)
- `scripts/battle/combat_manager.gd` (gear passives + battle-start gear block + trigger sites)
- `scripts/battle/dice_manager.gd` (band-shaping gear)
- `scripts/battle/battle_scene.gd` (roll-time gear: Overload Capacitor, Sync Antenna)
- `scripts/ui/loadout_menu.gd`, `scripts/ui/item_card.gd`, `scripts/ui/item_type_frame.gd` (in-battle bag UI)
- `scripts/resources/item_data.gd`, `scripts/autoloads/DataManager.gd:465-477` (parsing; `target` → `target_kind`)

## Known edge cases

- **Defib Spark cannot be used** — the `allyDead` targeting branch hard-cancels (`protocol_actions.gd:763-765`); `PHASE_ITEM_PICK_DEAD` exists but is unreachable and returns no legal targets.
- Item damage/burn carries no attacker state: Shock Charge does not consume Marks, doesn't get Cold Logic's +4, and can't trigger Spike.
- Freeze via item (`item_freeze_die`) does NOT trigger Mirror Plate; freeze via ability (`_freeze_die_state`) DOES — even when the freezer is friendly.
- Kill-triggered gear (Kill Switch, Bounty Chip) does not fire for kills caused inside another death's processing (Chain Reaction splash, Killswitch Relay detonation) — the `_chain_reaction_active` guard suppresses nested `_on_unit_killed` hooks.
- Sync Antenna writes a direct `roll_buff` (no stack instance); it lasts exactly this round and is not shown as a timed instance.
- Anchor Frame: with multiple holders above half HP, the first in slot order is the taunter; an explicit Taunt always wins.
- Targeting Optic marks the first living enemy in slot order, not literally "this unit's first target."
- Duplicate gear can be drafted in later battles and stacks additively on the same unit (no uniqueness guard).
- Rarity tier chains: rollBuff ×4, gainProtocol ×4, enemyRfe ×3, anyDieFreeze ×2 (items); five two-tier pairs (gear) — vs the "max 4 two-tier pairs" design rule, pending ruling.

## ⚠ Open findings

<!-- AUDIT-LINKS:items-and-gear -->
- [A-020](../audit/INTERACTION_AUDIT.md#a-020) - [dead] four coded protocol/gear handlers with no data
- [A-064](../audit/INTERACTION_AUDIT.md#a-064) - [needs-Kev] pool tier structure exceeds max-4 pairs
- [A-068](../audit/INTERACTION_AUDIT.md#a-068) - [confusing] item damage carries no attacker (Mark/Cold Logic skip)
- [A-070](../audit/INTERACTION_AUDIT.md#a-070) - [confusing] Triage Gel grants no shield on self-heals

Resolved (2026-07-08 fix pass): [A-041](../audit/INTERACTION_AUDIT.md#a-041), [A-061](../audit/INTERACTION_AUDIT.md#a-061), [A-062](../audit/INTERACTION_AUDIT.md#a-062), [A-065](../audit/INTERACTION_AUDIT.md#a-065), [A-066](../audit/INTERACTION_AUDIT.md#a-066), [A-074](../audit/INTERACTION_AUDIT.md#a-074)
