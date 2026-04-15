# Angular to Godot Mapping

This project now has both the legacy Angular prototype and the new Godot shell in one workspace. The goal of this document is to keep the migration honest by mapping the existing Angular systems to their Godot replacements.

## Recommended migration strategy

Port the game in this order:

1. Data first
2. Run state second
3. Battlefield UI shell
4. Dice resolution
5. Combat rules
6. Reward and evolution overlays

That order matches your roadmap and reduces the chance of rebuilding logic twice.

## Angular to Godot system map

| Angular source | Responsibility today | Godot target |
|---|---|---|
| `src/app/services/game-state.service.ts` | Run state, battle phase, overlays, inventory, relics, protocol | `scripts/autoloads/GameState.gd` plus smaller battle managers |
| `src/app/services/combat.service.ts` | Turn flow, damage, healing, deaths, win/loss, post-battle sequence | `scripts/battle/CombatManager.gd` |
| `src/app/services/dice.service.ts` | D20 rolls, effective rolls, ability lookup, hero/enemy brackets | `scripts/battle/DiceManager.gd` |
| `src/app/services/hero-state.service.ts` | Per-hero mutable combat state | Runtime unit model owned by `CombatManager` |
| `src/app/services/enemy-state.service.ts` | Per-enemy mutable combat state | Runtime enemy model owned by `CombatManager` |
| `src/app/services/protocol.service.ts` | Protocol gain and spend rules | `scripts/battle/ProtocolBar.gd` |
| `src/app/services/targeting.service.ts` | Valid targets and auto-targeting | `scripts/battle/TargetingManager.gd` |
| `src/app/services/evolution.service.ts` | XP and branching upgrades | `scripts/battle/EvolutionManager.gd` or a UI controller plus `GameState` data |
| `src/app/services/item.service.ts` | Reward draft and inventory actions | `scripts/ui/RewardScreen.gd` plus item helpers |
| `src/app/components/game/game.component.ts` | Battlefield composition | `scenes/battle/BattleScene.tscn` |
| `src/app/components/hero-zone/*` | Player card presentation | `scenes/battle/PlayerZone.tscn` and `scripts/units/UnitCard.gd` |
| `src/app/components/enemy-zone/*` | Enemy card presentation | `scenes/battle/EnemyZone.tscn` and `scripts/units/EnemyCard.gd` |
| `src/app/components/dice-tray/*` | Dice display and roll interaction | `scenes/shared/DiceTray.tscn` |
| `src/app/components/overlays/*` | Evolution, relic, item, result overlays | Individual Godot popup scenes |
| `src/app/data/json/*` | Source-of-truth content tables | `.tres` resources in `data/` or an import pipeline |

## Important migration observations

### 1. The Angular prototype already contains the real game design

The docs are helpful, but the Angular services are more specific than the design docs. They already define:

- the actual battle loop
- status effect timing
- relic hooks
- gear hooks
- post-battle reward sequencing

That means we should treat Angular as the logic reference and the docs as the architectural target.

### 2. `GameStateService` is currently too large for a direct 1:1 port

In Angular it holds:

- run state
- battle state
- overlay state
- animation flags
- tutorial state
- inventory state

In Godot, that should be split:

- `GameState.gd` for run-persistent data
- scene-local battle managers for temporary combat state
- UI scenes controlling their own visibility where possible

### 3. `CombatService` is the highest-value file to port carefully

`src/app/services/combat.service.ts` is effectively the executable ruleset for the game. When we start gameplay migration, this file should be translated system by system rather than rewritten from memory.

### 4. Data should move out of code before deep gameplay porting

Angular currently mixes content and runtime logic. Godot will be much easier to maintain if unit, enemy, gear, and relic definitions become `Resource` files early.

## Suggested next implementation slice

The best next slice is:

1. Create resource classes for units, enemies, and items
2. Import the first four heroes and one enemy faction into `data/`
3. Build a reusable `UnitCard` scene
4. Build a `BattleScene` that displays four heroes and enemy cards with placeholder values

Once that shell exists, we can start porting `DiceService` and then `CombatService` into Godot without guessing at the UI shape.
