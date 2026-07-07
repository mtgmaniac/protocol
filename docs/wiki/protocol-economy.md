# Protocol Economy

> Part of the [Overload Protocol wiki](INDEX.md). See also: [dice-and-rolls.md](dice-and-rolls.md), [items-and-gear.md](items-and-gear.md), [relics.md](relics.md), [combat-resolution.md](combat-resolution.md).

## How it works

Protocol (PP) is the battle-only dice-manipulation resource. The pool lives in `BattleState.protocol_points` (`scripts/battle/battle_state.gd:25`); the rules live in `BattleEngine`; the footer shows "PROTOCOL n/m" with amber segment pips (`scripts/battle/battle_scene.gd:1628` `_update_protocol_bar`, `scripts/ui/protocol_pips.gd`).

### Income

- **Start each battle at 0** — plus Overflow relic carryover if held (`battle_scene.gd:230` `take_carried_protocol`).
- **+1 at the END of every resolved turn**, ongoing rounds only (`battle_scene.gd:1130-1139`; rule in `BattleEngine.end_of_round_income`, `scripts/battle/battle_engine.gd:72`). Two authored suppressors:
  - **BLACKOUT** route modifier: no income before round 3 (`battle_engine.gd:73`; `GameState.gd:263`).
  - **Deep Cache income debt** (Vault Door intercept, −5): each owed turn swallows the +1 (`battle_engine.gd:75`; armed via `incomeDebt`, `GameState.gd:597`).
- **Cap 10** (`BattleEngine.MAX_PROTOCOL`, `battle_engine.gd:17`), computed per-gain by `max_protocol` (:164):
  - **Rogue Engineer** intercept replaces the base cap (cap becomes **8**, plus +1 start protocol per battle — `GameState.gd:457,599-601`).
  - **Deep Cells** directive (`protocolCapBonus`): +2 cap while a living carrier stands; only the FIRST living carrier counts (`battle_engine.gd:171-175`).

### Costs (all spends route through BattleEngine)

| Action | Cost | Where | Discounts |
|---|---|---|---|
| Nudge (+3 effective) | **1** | `battle_engine.gd:220-242` | Priming Charge gear: holder's first Nudge each battle free (:221); Reverse Gimbal flip is free (:234) |
| Reroll | **2** | `battle_engine.gd:210` | none |
| Set a die | **3** (`SET_DIE_COST`, :18) | `battle_engine.gd:246-261` | Root Access boss relic: first Set each battle 0 (:247) |
| Item (any rarity) | **1 flat** | `battle_engine.gd:287-294` | Protocol Override relic → 0; Supply Drone intercept (`items_free`) → 0; **Sealed Supplies route modifier → 2** |
| Twin Fates copy | **0**, once per battle | `battle_engine.gd:266` | relic-gated button (`protocol_actions.gd:36`) |

UI affordability checks live in `scripts/battle/protocol_actions.gd` (:230 Reroll needs 2, :244 Nudge needs 1 unless a free Nudge exists, :358 Set, :749 items). Item cost is deducted floor-0 (`protocol_actions.gd:932`).

### Every +Protocol source (verified in code)

| Source | Amount | Trigger | Where |
|---|---|---|---|
| End-of-turn income | +1 | ongoing round resolved | `battle_scene.gd:1138` |
| Gear `protocolOnBattleStart` — Protocol Tap +1 / Mainline Bus +3 | data | battle start | summed `battle_engine.gd:81` `gear_start_protocol`; applied `battle_scene.gd:247`; setup `combat_manager.gd:345` |
| Gear `protocolOnKill` — Bounty Chip | +1 | holder kills a **basic** enemy | `combat_manager.gd:2133-2137` |
| Gear `protocolOnKillAny` | data | holder kills anything | `combat_manager.gd:2139-2140` (handler live; **no current gear uses it** — see ability_audit.gd:3200) |
| Gear `protocolOnNat20` — Overload Capacitor | +2 | raw natural 20 at roll time | `battle_scene.gd:1448-1450` (amount hardcoded — finding) |
| Gear `protocolOnDieTamper` — Mirror Plate | +2 | enemy Jams/Rewrites/Freezes holder's die | `combat_manager.gd:1327-1332`, called from :1321 (rewrite), :1356 (jam), :2027 (freeze) |
| Relic `protocolCarryover` — Overflow | 50% of unspent | battle victory → next battle start | `battle_scene.gd:1171-1175`, `GameState.gd:757-767` |
| Relic `protocolOnItemUse` — Protocol Override | +1 (and items cost 0) | any item use | `protocol_actions.gd:934-936` |
| Relic `protocolOnMarkedKill` — Salvage Directive | +2 | hero kills a target whose Mark was consumed by the killing hit | `combat_manager.gd:2147-2150` |
| Relic `protocolOnShieldBreak` — Salvage Rig (boss relic) | +1 | a hero hit breaks the last of an enemy's shield | `combat_manager.gd:1867-1869` |
| Ability `gainProtocol` (hero bands, e.g. Signal Breaker kit) | data | ability resolves | `combat_manager.gd:1011-1017`; Surge Wiring directive adds +2 on the named ability (:1013) |
| Directive `rfeGrantsProtocol` — Signal Theft | +1 per roll-down applied | hero applies RFE | `combat_manager.gd:1178-1181` |
| Item `gainProtocol` — Protocol Cell +2 / Pack +3 / Array +4 / Core +5 | data | item use | `protocol_actions.gd:941-945`; `data/raw/items.data.json:199-226` |
| Intercepts `protocolNextBattle` (+2/+3, several cards) | data | next battle start | `GameState.gd:577`, applied `battle_engine.gd:125` → `battle_scene.gd:1375-1378` |
| Rogue Engineer `runProtocolPerBattle` | +1 every battle | battle start | `GameState.gd:599-601` → `battle_engine.gd:125` |

Kill/siphon grants made during resolution accumulate in `combat_manager._pending_protocol_grants` / `_pending_protocol_drain` and are drained once per round by `BattleEngine.resolve_step` (`battle_engine.gd:61-62`), then applied by the caller (`battle_scene.gd:1076-1084`).

### Every −Protocol sink

- The four spends above (Nudge/Reroll/Set/Item).
- **Siphon** (enemy-only keyword): on a connecting hit, drain N from the pool, floor 0 (`combat_manager.gd:1599-1603`; applied `battle_scene.gd:1080-1084`).
- **Sealed Supplies** route modifier: +1 on every item (cost 2 total).
- **Deep Cache** debt / **BLACKOUT**: income suppression (not a drain, but lost income).
- Enemies never hold or spend Protocol.

### Overflow

**Overflow Vent** relic (`protocolOverflowDamage`): every point gained past the cap deals **2 damage to a random living enemy** per point (`BattleEngine.gain_protocol`, `battle_engine.gd:182-197`). The random pick routes through `roll_provider.rand_index`, so it is seeded in the sim. Without the relic, overflow is silently lost. Note: battle-start GEAR protocol is clamped with `mini()` instead of `gain_protocol` (`battle_scene.gd:247`), so gear overflow never vents — a recorded inconsistency (see findings).

## Why it works that way

- Costs 1/2/3 form a ladder of certainty: Nudge nudges a boundary, Reroll gambles, Set guarantees — priced accordingly. Item cost 1 flat keeps consumables a tempo decision, not a rarity calculation (TRUTH §Protocol economy).
- Income +1/turn with cap 10 makes hoarding for Set (3) a real 3-turn commitment; siphon and Blackout attack exactly that plan.
- Pending-grant draining once per round keeps mid-resolution protocol from being spent inside the same resolution (the pool is caller-owned; combat_manager stays pool-agnostic).
- Protocol pips are amber (never green — INVARIANTS #7).

## What it replaced

- Footer actions were "Reroll, Nudge, Item"; **Set** was added later (TRUTH doc-adjudications table).
- The spend rules lived inline in the battle_scene god object; extracted to `BattleEngine` (sim A.1 cluster 4, commit `c718d1a`) and the UI to `ProtocolActions` (commit `a51e03b`).
- "Green = protocol" is dead; amber is canon.
- XP consumable items were removed entirely; the consumable pool is 25 items, protocol items among them.

## File locations

- `scripts/battle/battle_engine.gd` — cap, income, gain/overflow, all spend rule cores
- `scripts/battle/battle_state.gd` — the pool + per-battle spend flags
- `scripts/battle/protocol_actions.gd` — footer buttons, pick flows, item loadout + costs
- `scripts/battle/battle_scene.gd` — income application, carryover, bar/pips, battle-start ordering
- `scripts/battle/combat_manager.gd` — pending grants/drain, gear/relic/directive protocol hooks
- `scripts/autoloads/GameState.gd` — carryover storage, intercept/route protocol effects
- `data/raw/gear.data.json`, `relics.data.json`, `items.data.json` — the authored amounts

## Known edge cases

- Battle-start ordering (`battle_scene.gd:230-248`): carryover → relic/gear battle-start effects → route modifier → intercept effects (through `_gain_protocol`, vent CAN fire at battle start) → gear start protocol (mini-clamped, vent can NOT fire).
- Protocol Override beats Sealed Supplies: with the relic, items cost 0 even under the modifier (check order, `battle_engine.gd:288-293`) — and still refund +1, so items are net +1 under any modifier.
- Root Access's free Set is consumed only when actually used (cost 0 path sets `root_access_used`, `battle_engine.gd:256`).
- Priming Charge is per-holder (`free_nudge_used` keyed by hero id), so three holders = three free Nudges.
- A Reverse Gimbal flip costs nothing and does not consume the once-per-die Nudge (it edits the pending nudge's sign).
- Salvage Directive requires `mark_consumed_this_hit` — killing a marked enemy with a hit that did NOT consume the mark (e.g. the mark was consumed earlier that round) grants nothing.
- Overload Capacitor triggers on the raw tray face at roll time — a frozen repeating 20 re-triggers it every repeat round.
- `_apply_item_effect` floors the pool at 0 on cost deduction; siphon drains are floor-0 too — the pool can never go negative.

## ⚠ Open findings

<!-- AUDIT-LINKS:protocol-economy -->
- [A-016](../audit/INTERACTION_AUDIT.md#a-016) - [confusing] Overload Capacitor +2 hardcoded, ignores gear data
- [A-017](../audit/INTERACTION_AUDIT.md#a-017) - [confusing] Overflow Vent 2 dmg/pt hardcoded, ignores relic data
- [A-018](../audit/INTERACTION_AUDIT.md#a-018) - [confusing] battle-start protocol overflow differs by source
- [A-019](../audit/INTERACTION_AUDIT.md#a-019) - [confusing] duplicate MAX_PROTOCOL/SET_DIE_COST constants
- [A-020](../audit/INTERACTION_AUDIT.md#a-020) - [dead] four coded protocol/gear handlers with no data
- [A-057](../audit/INTERACTION_AUDIT.md#a-057) - [needs-Kev] boss reinforcement x on-kill economy stall farm
