# Overload Protocol — Godot Implementation Roadmap
**Engine:** Godot 4.x
**Developer:** Solo (Kev, AI-assisted)
**Goal:** Playable demo in ~6–8 weeks

---

## How to Read This Document

Each phase builds on the last. Do not skip phases — the systems are interdependent.
Every phase ends with a **checkpoint**: a playable or testable milestone you can verify before moving on.

**Godot vocabulary used here:**
- **Node** — an object in your game (a button, a unit card, a timer). Everything is a node.
- **Scene** — a reusable collection of nodes saved as a `.tscn` file (like a prefab or component).
- **Script** — a `.gd` file attached to a node that gives it behaviour.
- **Signal** — a message one node sends that other nodes can listen for (e.g. "I died", "turn ended").
- **Autoload** — a script that runs globally across all scenes (used for game state, data managers).

---

## Phase 0 — Environment Setup
**Duration:** 2–3 days
**Goal:** Godot installed, project created, folder structure ready.

### Tasks
- [ ] Download and install Godot 4 (godotengine.org)
- [ ] Create new project: `overload-protocol-godot`
- [ ] Set up folder structure (see below)
- [ ] Configure for mobile: Project Settings → Display → Window → set landscape orientation
- [ ] Add this GDD and roadmap to the project root as reference docs

### Folder Structure
```
overload-protocol-godot/
├── docs/                  ← Drop GDD.md, ROADMAP.md, CLAUDE.md here
├── scenes/
│   ├── battle/            ← Battle screen, unit cards, enemy cards
│   ├── ui/                ← Menus, HUD elements, reward screens
│   └── shared/            ← Reusable components (dice, status icons)
├── scripts/
│   ├── autoloads/         ← Global managers (GameState, DataManager)
│   ├── battle/            ← Combat logic
│   └── units/             ← Unit behaviour
├── data/
│   ├── units/             ← Unit definitions (.tres or .json)
│   ├── items/             ← Gear, consumables, relics
│   └── operations/        ← Enemy faction data
├── assets/
│   ├── portraits/         ← Unit and enemy portrait art
│   ├── icons/             ← Status effect icons, item icons
│   └── ui/                ← Backgrounds, frames, UI elements
└── CLAUDE.md              ← Instructions for AI assistants (see CLAUDE.md file)
```

### Checkpoint ✓
Godot opens, project runs an empty scene without errors.

---

## Phase 1 — Data Architecture
**Duration:** 3–5 days
**Goal:** All unit, enemy, and item data defined in structured files. No gameplay yet.

### What We're Building
Godot uses **Resources** (`.tres` files) or JSON to store game data. Think of these as your unit metadata — their names, stats, dice ranges, and ability descriptions live here.

### Tasks
- [ ] Create `UnitData` resource class (name, portrait, HP, dice ranges, 5 abilities)
- [ ] Create `EnemyData` resource class (same structure as UnitData)
- [ ] Create `ItemData` resource class (name, type: gear/consumable/relic, effect)
- [ ] Populate data for all 8 player units
- [ ] Populate data for 1 enemy faction (10 enemy variants, 1 boss)
- [ ] Create `DataManager` autoload — loads all data at game start, accessible globally

### Key Script: DataManager (Autoload)
```gdscript
# scripts/autoloads/DataManager.gd
extends Node

var units: Dictionary = {}
var items: Dictionary = {}

func _ready():
    _load_units()
    _load_items()

func _load_units():
    # Load all unit .tres files from data/units/
    pass

func get_unit(id: String) -> Resource:
    return units.get(id)
```

### Checkpoint ✓
You can print any unit's name, HP, and dice ranges from a script. No visual output needed yet.

---

## Phase 2 — Game State & Scene Management
**Duration:** 2–3 days
**Goal:** The game knows what run you're on, who your units are, and can switch between scenes.

### What We're Building
A `GameState` autoload that holds all persistent run data (selected units, gear, relics, which battle you're on).

### Tasks
- [ ] Create `GameState` autoload script
- [ ] Store: selected_units[], current_battle, equipped_gear{}, relics[], consumables[]
- [ ] Create `SceneManager` autoload for clean scene transitions
- [ ] Build placeholder scenes: MainMenu, UnitSelect, BattleScene, RewardScreen
- [ ] Wire up basic navigation: Menu → UnitSelect → BattleScene

### Key Script: GameState (Autoload)
```gdscript
# scripts/autoloads/GameState.gd
extends Node

var selected_units: Array = []
var current_battle: int = 0
var relics: Array = []
var consumables: Array = []

func start_run(unit_ids: Array):
    selected_units = unit_ids
    current_battle = 0

func next_battle():
    current_battle += 1

func is_run_over() -> bool:
    return selected_units.all(func(u): return u.is_dead)
```

### Checkpoint ✓
You can click through: Main Menu → pick 4 units → enter battle scene → see battle scene load.

---

## Phase 3 — Unit Cards (Visual)
**Duration:** 4–5 days
**Goal:** Unit portrait cards visible on the battlefield with real data.

### What We're Building
A `UnitCard` scene that displays a unit's portrait, HP bar, name, current dice result, and status effects. This is the core visual object the player interacts with.

### UnitCard Scene Structure
```
UnitCard (Control node)
├── Portrait (TextureRect)          ← Unit art
├── NameLabel (Label)               ← Unit name
├── HPBar (ProgressBar)             ← Current / max HP
├── DiceResult (Label)              ← Current dice roll number
├── AbilityLabel (Label)            ← What the dice result maps to
├── StatusEffects (HBoxContainer)   ← Icons for frozen, poisoned, etc.
├── GearSlots (HBoxContainer)       ← Equipped gear icons
└── XPBar (ProgressBar)             ← XP progress
```

### Tasks
- [ ] Build UnitCard scene with all nodes above
- [ ] Write `UnitCard.gd` script that takes a `UnitData` resource and populates itself
- [ ] Display 4 unit cards in a row on the player side of the battle scene
- [ ] Display enemy cards mirrored on the opposite side
- [ ] HP bar turns red when below 30%
- [ ] Dead units grey out / show death state

### Checkpoint ✓
Battlefield shows 4 player unit cards and enemy cards with real names, HP bars, and portraits (placeholder art is fine).

---

## Phase 4 — Dice System
**Duration:** 4–5 days
**Goal:** Dice roll and resolve correctly. Unit cards show the right ability for each roll.

### What We're Building
The core mechanical heart of the game. A `DiceManager` that rolls all dice, maps results to abilities, and exposes results to the UI.

### Tasks
- [ ] Create `DiceManager` script
- [ ] Roll D20 for each living unit (player and enemy)
- [ ] Map each roll to the correct ability using that unit's dice ranges
- [ ] Display roll result on each UnitCard
- [ ] Animate dice roll (number cycling before landing — simple tween is fine)
- [ ] Implement dice freeze: frozen units re-use last turn's roll
- [ ] Implement dice modify: abilities that add/subtract from a roll
- [ ] Build Protocol Bar UI element (fills per turn, spend to nudge/reroll/set)

### Key Script: DiceManager
```gdscript
# scripts/battle/DiceManager.gd
extends Node

func roll_all(units: Array) -> Dictionary:
    var results = {}
    for unit in units:
        if unit.is_frozen:
            results[unit.id] = unit.last_roll
        else:
            var roll = randi_range(1, 20)
            results[unit.id] = roll
            unit.last_roll = roll
    return results

func get_ability_for_roll(unit_data: Resource, roll: int) -> Dictionary:
    for range_entry in unit_data.dice_ranges:
        if roll >= range_entry.min and roll <= range_entry.max:
            return range_entry.ability
    return {}
```

### Checkpoint ✓
Press a "Roll" button → all unit cards show a D20 result → ability name appears under each card. Protocol bar is visible and drains when you spend it.

---

## Phase 5 — Combat Resolution
**Duration:** 5–7 days
**Goal:** Abilities actually do things. Damage is dealt, HP changes, battles can be won and lost.

### What We're Building
A `CombatManager` that processes abilities in order: player phase first, then enemy phase. Applies damage, healing, shields, and status effects.

### Turn Flow (Code Perspective)
```
DiceManager.roll_all()
    → CombatManager.player_phase()
        → for each player unit: resolve_ability(unit, target)
    → CombatManager.enemy_phase()
        → for each enemy unit: resolve_ability(unit, target)
    → CombatManager.end_of_turn()
        → tick status effects (poison, etc.)
        → check win/loss condition
    → DiceManager.roll_all()  ← next turn
```

### Tasks
- [ ] Build `CombatManager` script
- [ ] Implement ability types: damage, shield, heal, aoe_damage, aoe_heal
- [ ] Implement targeting: single target, all enemies, all allies
- [ ] Apply damage to HP bars (with shield absorption)
- [ ] Implement status effect application and ticking
- [ ] Show floating damage numbers (simple Label that tweens upward and fades)
- [ ] Check win condition: all enemies dead
- [ ] Check loss condition: all player units dead
- [ ] Handle unit death (remove from dice pool, grey out card)

### Checkpoint ✓
A full battle can be played to completion. Units die, damage numbers float, the battle ends with a win or loss state.

---

## Phase 6 — Reward Screen
**Duration:** 3–4 days
**Goal:** After each battle, player sees 3 reward choices and can pick one.

### Tasks
- [ ] Build `RewardScreen` scene
- [ ] Generate 3 random rewards from item pool (weighted: mostly consumables, some gear)
- [ ] Display each reward as a card with name, icon, and description
- [ ] Handle selection: apply gear to a unit, add consumable to inventory
- [ ] At Battle 5: force a Relic as one of the 3 options
- [ ] Transition back to battle after selection

### Checkpoint ✓
Win a battle → reward screen shows 3 choices → pick one → next battle loads.

---

## Phase 7 — Full Run Loop
**Duration:** 3–4 days
**Goal:** A full 10-battle run is playable from start to finish.

### Tasks
- [ ] Wire battle progression: win battle → reward → next battle
- [ ] Track battle number and display it (Battle 3/10, etc.)
- [ ] Scale enemy difficulty with battle number
- [ ] Build boss battle (Battle 10): tougher enemy with unique ability ranges
- [ ] Win screen: run complete
- [ ] Loss screen: full wipe, option to restart
- [ ] Reset GameState on run end

### Checkpoint ✓
A complete run from unit selection to Battle 10 boss. Win or lose, the game resets cleanly.

---

## Phase 8 — Unit Evolution
**Duration:** 3–4 days
**Goal:** Units gain XP, level up, and evolve with branching choices.

### Tasks
- [ ] Award XP to surviving units after each battle
- [ ] Level-up threshold triggers evolution screen
- [ ] Evolution screen: show 2 branching options with descriptions
- [ ] Apply evolution: modify unit's dice ranges or add passive
- [ ] Evolved unit card shows visual indicator of current evolution path

### Checkpoint ✓
A unit levels up mid-run, player chooses an evolution path, and the unit's abilities change accordingly.

---

## Phase 9 — Polish and Mobile UX
**Duration:** 5–7 days
**Goal:** Feels good to play on a phone. Clean, readable, satisfying.

### Tasks
- [ ] All touch targets minimum 44x44px
- [ ] Dice roll animations feel satisfying (spring tween, sound placeholder)
- [ ] Damage numbers pop and fade
- [ ] Status effect icons clear and readable at mobile scale
- [ ] Ability tooltip on tap (hold a unit card to see full ability chart)
- [ ] Screen transitions (fade between scenes)
- [ ] Basic sound effects (dice roll, hit, heal, death)
- [ ] Dark UI theme consistently applied

### Checkpoint ✓
Hand the phone to someone who hasn't played and they can figure out the basics without explanation.

---

## Phase 10 — Demo Build
**Duration:** 2–3 days
**Goal:** Exportable build you can share with friends.

### Tasks
- [ ] Export to Android APK or iOS TestFlight
- [ ] Or: export to HTML5 for browser play (easier to share)
- [ ] Test on a real device
- [ ] Fix any crashes or major UX issues
- [ ] Share with playtesters

### Checkpoint ✓
Friends can play it. You're proud of it.

---

## Parallel Track — Art & Assets

These happen alongside development, not blocking it:

| Asset | When Needed | Notes |
|---|---|---|
| Unit portraits (8x) | Phase 3 | Placeholder OK to start |
| Enemy portraits | Phase 3 | Placeholder OK |
| Dice face art | Phase 4 | Simple numbers fine for now |
| Status effect icons | Phase 5 | 16x16 or 32x32 |
| Item icons | Phase 6 | One per item type |
| Background art | Phase 9 | Dark space/sci-fi theme |
| UI frames/borders | Phase 9 | Tactical HUD style |

---

## Risk Register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Mobile layout harder than expected | Medium | Build mobile-first from Phase 3, never desktop-first |
| Ability interactions getting complex | High | Build generic ability system in Phase 5, not hardcoded |
| Art bottleneck | Medium | Use AI-generated placeholder art early, replace later |
| Scope creep | High | Stick to this roadmap. Node map, meta-progression = post-demo |
