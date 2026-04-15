# AI quick context — Overload Protocol

Short orientation for assistants working on gameplay or UI (not the portrait/asset pipeline; see `AGENTS.md` for that).

## What it is

- **Stack:** Angular (standalone components, signals), game content mostly **JSON** under `src/app/data/json/` validated by **AJV** schemas in `src/app/data/schemas/`.
- **Genre:** Turn-based squad tactics. Each **operation** is a linear **battle track** (facility, hive, etc.). You field **heroes** vs **enemies**; combat is driven by **d20 zones** (Strike / Build / Overload-style bands) on ability tables.

## Core combat loop

1. **Player phase:** Roll squad dice (`DiceTrayComponent` / `CombatService.rollHero`, `computeRollAllPresets` + tray animation). Enemy tray plans stay hidden until the squad is fully rolled, then revealed.
2. **Targeting:** `TargetingService` — tap heroes to pick locks, ally heals/shields/rfm/revive, split damage, etc. `END TURN` requires every living (non-cowering) hero to have a legal roll + confirmation.
3. **Resolution:** `CombatService.endTurn()` resolves heroes left→right (DoT, abilities, shields, debuffs), then **enemy phase** (`enemyTurn()`), then next player round (fresh rolls, protocol +1).
4. **Win / loss:** `won()` → item draft (if inventory space) → HRS → optional **evolutions** → next battle or run victory overlay. `lost()` → wipe overlay.

## Major services (where logic lives)

| Area | Service / place |
|------|------------------|
| Global state | `GameStateService` — `signal`s: heroes, enemies, phase (`player` \| `enemy` \| `over`), protocol, inventory, tutorial, overlays, etc. |
| Combat rules | `CombatService` — init battle, end turn, enemy turn, damage, win/loss, **Sim Battle** (`runSimBattle`), roll payloads for tray |
| Dice & zones | `DiceService` — d20, effective roll, ability lookup from hero tier tables |
| Targeting & clicks | `TargetingService` — hero/enemy card clicks, auto-target helpers, sim-battle auto-targets |
| Items | `ItemService` — definitions from `items.data.json`, inventory, protocol cost, `pendingItemSelection` + confirm on ally/enemy |
| Meta progression | `EvolutionService` — HRS, evolution picks; wired after wins |
| UX pacing | `AnimationService` — portrait shake/pulse; gated by `GameStateService.animOn()` |
| Teaching | `TutorialService` + `TutorialOverlayComponent` — coach steps, roll presets |

## Player-facing systems

- **Protocol:** Spend on **reroll** / **nudge** (protocol strip); cap in `constants`.
- **Items:** Up to 3 slots; consumables with rarity-based protocol cost; targets `none` / `ally` / `allyDead` / `enemy`.
- **Sim Battle:** Header button; with animations on uses tray delegate; off uses instant rolls + `endTurn({ chainEnemyPhase: true })`.

## Key UI layout (`game.component.html`)

Header → enemy zone → dice tray → hero zone → **protocol strip** (protocol + inventory) → battle log. Overlays: result, help, tutorial, evolution, item draft.

## Conventions for changes

- After editing JSON: `npm run validate-data`.
- Match existing patterns (signals, OnPush); prefer **computed** when template must track multiple signals (see protocol strip inventory rows).
- Do not assume CI/gitignore; see `AGENTS.md` for intentional gaps.
